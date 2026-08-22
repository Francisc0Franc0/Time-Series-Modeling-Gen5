# Run the frozen LIT-MOM-01.5 path-quality forecast comparison.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_4_multi_market_predictor_atlas.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_5_path_quality_forecast_comparison.R"
))
g5_load_local_renviron(repo_root)
options(warn = 1)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in%
    c("1", "true", "yes", "y")
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create LIT-MOM-01.5 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

write_optional <- function(x, path, status = "NO_ROWS") {
  if (nrow(x)) write_csv(x, path) else write_csv(data.frame(status = status), path)
}

contract_table <- function(contract) {
  data.frame(
    field = names(contract),
    value = vapply(contract, function(value) paste(value, collapse = ","), character(1)),
    stringsAsFactors = FALSE
  )
}

health_maximum <- function(health) {
  if (!nrow(health)) return("PASS")
  rank <- c(PASS = 1L, INFO = 1L, WARN = 2L, ERROR = 3L)
  observed <- rank[as.character(health$severity)]
  names(rank)[which.max(rank == max(observed, na.rm = TRUE))]
}

stratum_colors <- c(
  PLAIN_ETF = "#2B6CB0",
  ENGINEERED_ETF = "#D97706",
  STOCK_CHALLENGER = "#6B46C1"
)

model_colors <- c(
  B0_DRIFT = "#94A3B8",
  B1_RAW = "#2B6CB0",
  Q2_PATH = "#0F766E"
)

asset_model_summary <- function(anchor_losses) {
  keys <- unique(anchor_losses[, c(
    "analysis_id", "symbol", "category", "analysis_stratum", "is_spy_reference"
  ), drop = FALSE])
  do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    x <- anchor_losses[anchor_losses$analysis_id == keys$analysis_id[[i]], , drop = FALSE]
    cbind(
      keys[i, , drop = FALSE],
      data.frame(
        model_id = c("B0_DRIFT", "B1_RAW", "Q2_PATH"),
        mean_scaled_loss = c(mean(x$B0_DRIFT), mean(x$B1_RAW), mean(x$Q2_PATH)),
        stringsAsFactors = FALSE
      )
    )
  }))
}

plot_model_losses <- function(summary, path) {
  png(path, width = 1700, height = 950, res = 150)
  old <- par(mar = c(7, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  groups <- split(summary$mean_scaled_loss, factor(summary$model_id, levels = names(model_colors)))
  boxplot(
    groups, col = unname(model_colors), border = "#334155",
    log = "y",
    ylab = "Asset mean DEVELOPMENT scaled squared loss (log scale)",
    xlab = "TRAIN-fitted forecast authority",
    main = "Drift versus raw return versus path quality across all 24 cells",
    las = 1
  )
  for (i in seq_along(groups)) {
    points(
      jitter(rep(i, length(groups[[i]])), amount = 0.08), groups[[i]],
      pch = 19, cex = 0.35,
      col = grDevices::adjustcolor("#0F172A", alpha.f = 0.25)
    )
  }
}

plot_incremental_skill <- function(decisions, path) {
  decisions <- decisions[decisions$comparison_complete, , drop = FALSE]
  png(path, width = 2400, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(7, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  colors <- unname(stratum_colors[decisions$analysis_stratum])
  pch <- ifelse(decisions$is_path_quality_candidate, 19, 1)
  draw_panel <- function(main, xlim = NULL, ylim = NULL, label_outliers = FALSE) {
    plot(
      decisions$d21_mean, decisions$d20_mean,
      pch = pch, col = colors,
      cex = ifelse(decisions$is_path_quality_candidate, 1.5, 1),
      xlab = "D21: path-quality improvement over raw",
      ylab = "D20: path-quality improvement over drift",
      main = main, xlim = xlim, ylim = ylim
    )
    abline(h = 0, v = 0, col = "#CBD5E1")
    if (label_outliers) {
      score <- abs(decisions$d21_mean) + abs(decisions$d20_mean)
      label <- which(score > 10)
      text(decisions$d21_mean[label], decisions$d20_mean[label],
           labels = decisions$symbol[label], pos = 3, cex = 0.75)
    }
  }
  draw_panel("Full atlas; extreme extrapolation retained", label_outliers = TRUE)
  xlim <- unname(stats::quantile(decisions$d21_mean, c(0.025, 0.975), type = 7))
  ylim <- unname(stats::quantile(decisions$d20_mean, c(0.025, 0.975), type = 7))
  draw_panel("Central 95% of assets", xlim = xlim, ylim = ylim)
  legend("bottomleft", legend = names(stratum_colors), col = stratum_colors, pch = 19, bty = "n")
}

plot_primary_fdr <- function(contrasts, path, q) {
  x <- contrasts[contrasts$contrast_id == "D21" & !contrasts$is_spy_reference, , drop = FALSE]
  x <- x[order(x$analysis_stratum, x$bh_q_value), , drop = FALSE]
  values <- -log10(pmax(x$bh_q_value, 1e-8))
  png(path, width = 2050, height = 1050, res = 150)
  old <- par(mar = c(10, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  barplot(
    values, names.arg = x$symbol, las = 2, cex.names = 0.5,
    col = unname(stratum_colors[x$analysis_stratum]), border = NA,
    ylab = "-log10(within-stratum BH q)",
    main = "Primary Q2_PATH improvement over B1_RAW after asset multiplicity",
    ylim = c(0, max(-log10(q) * 1.08, values * 1.08))
  )
  abline(h = -log10(q), col = "#B42318", lwd = 2, lty = 2)
  legend(
    "topright", legend = c(names(stratum_colors), paste0("q = ", q)),
    col = c(stratum_colors, "#B42318"),
    pch = c(rep(15, length(stratum_colors)), NA),
    lty = c(rep(NA, length(stratum_colors)), 2), bty = "n"
  )
}

plot_mechanism <- function(summary, path) {
  png(path, width = 1750, height = 1000, res = 150)
  old <- par(mar = c(7, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  colors <- unname(stratum_colors[summary$analysis_stratum])
  plot(
    summary$median_gamma, summary$median_delta,
    pch = 19, col = grDevices::adjustcolor(colors, alpha.f = 0.65),
    xlab = "Median coherent-positive coefficient (gamma)",
    ylab = "Median shock-positive coefficient (delta)",
    main = "TRAIN mechanism direction across 24 standardized fits"
  )
  abline(h = 0, v = 0, col = "#CBD5E1")
  usr <- par("usr")
  rect(max(0, usr[[1L]]), usr[[3L]], usr[[2L]], min(0, usr[[4L]]),
       col = grDevices::adjustcolor("#16A34A", alpha.f = 0.06), border = NA)
  points(summary$median_gamma, summary$median_delta,
         pch = 19, col = grDevices::adjustcolor(colors, alpha.f = 0.65))
  legend("topright", legend = names(stratum_colors), col = stratum_colors, pch = 19, bty = "n")
}

plot_category_breadth <- function(summary, path) {
  x <- summary[order(summary$analysis_stratum, summary$category), , drop = FALSE]
  values <- 100 * x$positive_d21 / pmax(1, x$tested_non_spy_assets)
  png(path, width = 1900, height = 1050, res = 150)
  old <- par(mar = c(12, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  bars <- barplot(
    values, names.arg = x$category, las = 2, cex.names = 0.68,
    col = unname(stratum_colors[x$analysis_stratum]), border = NA,
    ylab = "Assets with positive path-over-raw loss improvement (%)",
    main = "Uncontrolled directional breadth by economic category",
    ylim = c(0, max(100, values + 10))
  )
  text(bars, values, labels = paste0(x$path_quality_candidates, " FDR"), pos = 3, cex = 0.72)
  legend("topright", legend = names(stratum_colors), col = stratum_colors, pch = 15, bty = "n")
}

write_report <- function(result, run_spec, model_summary, paths, path) {
  non_spy <- result$decisions[
    !result$decisions$is_spy_reference & result$decisions$comparison_complete,
    , drop = FALSE
  ]
  contrast_lines <- unlist(lapply(result$contract$contrast_ids, function(contrast) {
    x <- result$contrasts[
      result$contrasts$contrast_id == contrast & !result$contrasts$is_spy_reference,
      , drop = FALSE
    ]
    paste0(
      "- `", contrast, "`: positive assets `",
      sum(x$observed_mean_differential > 0), " / ", nrow(x),
      "`; minimum raw p `", sprintf("%.6f", min(x$centered_null_upper_p)),
      "`; minimum BH q `", sprintf("%.6f", min(x$bh_q_value)), "`."
    )
  }))
  stratum_lines <- unlist(lapply(unique(non_spy$analysis_stratum), function(stratum) {
    x <- non_spy[non_spy$analysis_stratum == stratum, , drop = FALSE]
    paste0(
      "- `", stratum, "`: tested `", nrow(x), "`, positive D21 `",
      sum(x$d21_mean > 0), "`, raw clues `", sum(x$raw_beats_drift_clue),
      "`, path-quality candidates `", sum(x$is_path_quality_candidate), "`."
    )
  }))
  candidate_lines <- if (nrow(result$candidates)) {
    apply(result$candidates, 1L, function(row) paste0(
      "- `", row[["symbol"]], "`: D21 `", sprintf("%.5f", as.numeric(row[["d21_mean"]])),
      "` (q `", sprintf("%.5f", as.numeric(row[["d21_q"]])), "`), D20 `",
      sprintf("%.5f", as.numeric(row[["d20_mean"]])), "` (q `",
      sprintf("%.5f", as.numeric(row[["d20_q"]])), "`)."
    ))
  } else {
    "- No non-SPY asset passed the complete incremental path-quality gate."
  }
  model_lines <- unlist(lapply(names(model_colors), function(model) {
    x <- model_summary[model_summary$model_id == model, , drop = FALSE]
    paste0("- `", model, "`: median asset scaled loss `",
           sprintf("%.5f", stats::median(x$mean_scaled_loss)), "`.")
  }))
  best_models <- do.call(rbind, lapply(split(model_summary, model_summary$analysis_id), function(x) {
    x[which.min(x$mean_scaled_loss), c("analysis_id", "model_id"), drop = FALSE]
  }))
  best_lines <- unlist(lapply(names(model_colors), function(model) {
    paste0("- `", model, "` had the lowest asset-average loss for `",
           sum(best_models$model_id == model), " / ", nrow(best_models), "` eligible assets.")
  }))
  ineligible <- result$ledger[
    result$ledger$mechanically_eligible & !result$ledger$analysis_eligible,
    , drop = FALSE
  ]
  ineligible_lines <- if (nrow(ineligible)) {
    apply(ineligible, 1L, function(row) paste0(
      "- `", row[["symbol"]], "`: `", row[["eligibility_reason"]],
      "`; partial cells discarded `", row[["cells_completed_before_invalid"]], "`."
    ))
  } else {
    "- No mechanically eligible asset failed the analytical model gate."
  }
  artifact_lines <- paste0(
    "- `", names(paths), "`: `",
    normalizePath(unlist(paths), winslash = "/", mustWork = FALSE), "`"
  )
  lines <- c(
    "# LIT-MOM-01.5 Path-Quality Forecast Comparison Report",
    "",
    paste0("**Status:** `", result$overall_status, "`"),
    "",
    "## Question",
    "",
    "Does causal positive-move coherence and shock concentration improve future-return forecasts beyond constant drift and raw trailing return?",
    "",
    "## Frozen boundary",
    "",
    "- All 92 checksum-frozen assets; SPY remains reference-only.",
    "- TRAIN 2017-2020; DEVELOPMENT 2021-2023.",
    "- Six lookbacks by four targets; all 24 cells equally weighted and none selected.",
    "- 2024-2025 was not queried or inspected.",
    "- No thresholds, positions, trades, costs, P&L, portfolio, allocation, or live behavior were computed.",
    "",
    "## Data and implementation validity",
    "",
    paste0("- Registry SHA-256: `", run_spec$registry_sha256, "`."),
    paste0("- Mechanically eligible: `", run_spec$mechanically_eligible_assets, " / 92`."),
    paste0("- Analysis eligible: `", run_spec$analysis_eligible_assets, " / 92`."),
    paste0("- Complete fitted cells retained: `", run_spec$complete_model_cells,
           " / ", 24L * run_spec$analysis_eligible_assets, "` across eligible assets."),
    paste0("- Partial cells discarded under the frozen all-cells gate: `",
           run_spec$partial_cells_discarded, "`; analytically ineligible assets: `",
           run_spec$analytically_ineligible_assets, "`."),
    ineligible_lines,
    paste0("- Workbench health maximum: `", run_spec$data_health_max_severity,
           "`; authoritative refresh flag: `", run_spec$refresh, "`."),
    "- The requested 2016-2023 range was complete before any forecast outcome was interpreted.",
    "",
    "## Model loss readout",
    "",
    model_lines,
    best_lines,
    paste0("- Mechanism-aligned TRAIN coefficient medians: `",
           sum(result$coefficient_summary$mechanism_aligned), " / ",
           nrow(result$coefficient_summary), "` eligible assets."),
    "",
    "## Paired DEVELOPMENT contrasts",
    "",
    contrast_lines,
    "",
    "## Stratum breadth",
    "",
    stratum_lines,
    "",
    "## Controlled candidates",
    "",
    candidate_lines,
    "",
    "## Interpretation",
    "",
    if (nrow(result$candidates)) {
      "The listed rows are bounded DEVELOPMENT forecast candidates, not confirmed effects or trading strategies. Only a later explicit operator gate may consume 2024-2025."
    } else {
      "The path-quality extension did not improve forecasts strongly and broadly enough to survive the frozen drift, raw-return, serial-dependence, mechanism, and asset-multiplicity controls. Preserve confirmation and stop without selecting a favorable cell or asset."
    },
    "",
    "## Artifacts",
    "",
    artifact_lines
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("LIT-MOM-01.5 frozen path-quality forecast comparison starting.")
contract <- g5_mom015_contract()
mom014_contract <- g5_mom014_contract()
registry <- g5_mom014_read_registry(repo_root, mom014_contract)
registry <- g5_mom015_validate_registry(registry, contract)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_01_5_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_01_5_REFRESH", FALSE)
preflight_only <- env_bool("GEN5_LIT_MOM_01_5_PREFLIGHT_ONLY", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_01_5_RUN_ID",
  "lit_mom_01_5_path_quality_forecast_comparison_20260821"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$query_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = registry$symbol,
  universe_name = "lit_mom_01_5_checksum_frozen_92_asset_path_quality_comparison",
  universe_roles = paste(registry$analysis_stratum, collapse = ","),
  refresh = refresh,
  repo_root = repo_root
)
bars <- g5_mom015_validate_bars(query$bars, registry, contract)
preflight_ledger <- g5_mom014_coverage_ledger(bars, registry, mom014_contract)
invisible(g5_write_workbench_query_artifacts(
  query, output_dir, "mom015_workbench_query"
))
write_csv(registry, file.path(output_dir, "mom015_frozen_registry.csv"))
write_csv(preflight_ledger, file.path(output_dir, "mom015_preflight_coverage.csv"))
write_csv(
  data.frame(
    registry_sha256 = attr(g5_mom014_read_registry(repo_root, mom014_contract), "sha256"),
    expected_registry_sha256 = contract$registry_sha256,
    passed = identical(
      attr(g5_mom014_read_registry(repo_root, mom014_contract), "sha256"),
      contract$registry_sha256
    ),
    stringsAsFactors = FALSE
  ),
  file.path(output_dir, "mom015_registry_checksum.csv")
)
if (sum(preflight_ledger$mechanically_eligible) != contract$registry_count) {
  stop(
    paste0(
      "LIT-MOM-01.5 requested-range coverage incomplete: ",
      sum(preflight_ledger$mechanically_eligible), " / ", contract$registry_count,
      ". Refresh the bounded range before outcome interpretation."
    ),
    call. = FALSE
  )
}
if (preflight_only) {
  message("LIT-MOM-01.5 preflight complete; forecast outcomes were not computed.")
  message("Coverage-complete assets: 92 / 92")
  message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
  quit(save = "no", status = 0L)
}

result <- g5_mom015_run_comparison(bars, registry, contract)
model_summary <- asset_model_summary(result$anchor_losses)
health_max <- health_maximum(query$health)
registry_hash <- attr(g5_mom014_read_registry(repo_root, mom014_contract), "sha256")
run_spec <- data.frame(
  schema_version = g5_mom015_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_01_5_path_quality_forecast_comparison.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  registry_sha256 = registry_hash,
  registry_assets = nrow(registry),
  mechanically_eligible_assets = sum(result$ledger$mechanically_eligible),
  analysis_eligible_assets = sum(result$ledger$analysis_eligible),
  complete_model_cells = sum(result$ledger$valid_cell_count),
  partial_cells_discarded = sum(
    result$ledger$cells_completed_before_invalid[!result$ledger$analysis_eligible]
  ),
  analytically_ineligible_assets = sum(
    result$ledger$mechanically_eligible & !result$ledger$analysis_eligible
  ),
  raw_beats_drift_clues = nrow(result$raw_clues),
  path_quality_candidates = nrow(result$candidates),
  confirmation_opened = result$confirmation_opened,
  strategy_outcomes_computed = FALSE,
  overall_status = result$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "mom015_run_spec.csv"),
  frozen_contract = file.path(output_dir, "mom015_frozen_contract.csv"),
  registry_checksum = file.path(output_dir, "mom015_registry_checksum.csv"),
  frozen_registry = file.path(output_dir, "mom015_frozen_registry.csv"),
  coverage = file.path(output_dir, "mom015_coverage_and_eligibility.csv"),
  feature_moments = file.path(output_dir, "mom015_train_feature_moments.csv"),
  coefficients = file.path(output_dir, "mom015_train_coefficients.csv"),
  cell_metrics = file.path(output_dir, "mom015_development_cell_metrics.csv"),
  anchor_losses = file.path(output_dir, "mom015_development_anchor_losses.csv"),
  model_summary = file.path(output_dir, "mom015_asset_model_summary.csv"),
  contrasts = file.path(output_dir, "mom015_development_contrasts.csv"),
  coefficient_summary = file.path(output_dir, "mom015_coefficient_summary.csv"),
  decisions = file.path(output_dir, "mom015_asset_decisions.csv"),
  candidates = file.path(output_dir, "mom015_path_quality_candidates.csv"),
  raw_clues = file.path(output_dir, "mom015_raw_beats_drift_clues.csv"),
  categories = file.path(output_dir, "mom015_category_summary.csv"),
  model_loss_png = file.path(visual_dir, "mom015_model_loss_comparison.png"),
  skill_png = file.path(visual_dir, "mom015_incremental_skill.png"),
  fdr_png = file.path(visual_dir, "mom015_primary_fdr.png"),
  mechanism_png = file.path(visual_dir, "mom015_mechanism_coefficients.png"),
  category_png = file.path(visual_dir, "mom015_category_breadth.png"),
  report = file.path(output_dir, "mom015_report.md")
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$frozen_contract)
write_csv(result$ledger, paths$coverage)
write_csv(result$feature_moments, paths$feature_moments)
write_csv(result$coefficients, paths$coefficients)
write_csv(result$cell_metrics, paths$cell_metrics)
write_csv(result$anchor_losses, paths$anchor_losses)
write_csv(model_summary, paths$model_summary)
write_csv(result$contrasts, paths$contrasts)
write_csv(result$coefficient_summary, paths$coefficient_summary)
write_csv(result$decisions, paths$decisions)
write_optional(result$candidates, paths$candidates, "NO_PATH_QUALITY_CANDIDATES")
write_optional(result$raw_clues, paths$raw_clues, "NO_RAW_BEATS_DRIFT_CLUES")
write_csv(result$category_summary, paths$categories)

plot_model_losses(model_summary, paths$model_loss_png)
plot_incremental_skill(result$decisions, paths$skill_png)
plot_primary_fdr(result$contrasts, paths$fdr_png, contract$fdr_q)
plot_mechanism(result$coefficient_summary, paths$mechanism_png)
plot_category_breadth(result$category_summary, paths$category_png)
write_report(result, run_spec, model_summary, paths, paths$report)

message("LIT-MOM-01.5 complete: ", result$overall_status)
message("Data health: ", health_max)
message("Eligible assets: ", sum(result$ledger$analysis_eligible), " / 92")
message(
  "Complete model cells retained: ", sum(result$ledger$valid_cell_count),
  " / ", 24L * sum(result$ledger$analysis_eligible), " across eligible assets"
)
message("Raw beats drift clues: ", nrow(result$raw_clues))
message("Path-quality candidates: ", nrow(result$candidates))
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report, winslash = "/", mustWork = FALSE))
