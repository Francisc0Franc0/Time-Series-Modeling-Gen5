# Run the frozen LIT-IMOM-01.2 30-minute path-quality forecast comparison.

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
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_4_multi_market_predictor_atlas.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_5_path_quality_forecast_comparison.R"
))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_imom_01_2_30min_path_quality_forecast_comparison.R"
))
options(warn = 1)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create LIT-IMOM-01.2 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

write_optional <- function(x, path, status) {
  if (nrow(x)) write_csv(x, path) else write_csv(data.frame(status = status), path)
}

contract_table <- function(contract) data.frame(
  field = names(contract),
  value = vapply(contract, function(value) paste(value, collapse = ","), character(1)),
  stringsAsFactors = FALSE
)

load_cached_bars <- function(repo_root, contract) {
  years <- 2017:2023
  paths <- file.path(
    repo_root, "data_cache", "alpaca_intraday_30min",
    sprintf("intraday_30min_sip_all_%d.rds", years)
  )
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop(paste("Missing frozen cache files:", paste(missing, collapse = ", ")), call. = FALSE)
  out <- do.call(rbind, lapply(paths, readRDS))
  out[out$session_date >= contract$query_start & out$session_date <= contract$query_end, , drop = FALSE]
}

asset_model_summary <- function(session_losses, contract) {
  keys <- unique(session_losses[, c(
    "analysis_id", "symbol", "sector", "analysis_stratum", "candidate_fdr"
  ), drop = FALSE])
  do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    x <- session_losses[session_losses$analysis_id == keys$analysis_id[[i]], , drop = FALSE]
    cbind(
      keys[i, , drop = FALSE],
      data.frame(
        model_id = contract$model_ids,
        mean_scaled_loss = vapply(contract$model_ids, function(model) mean(x[[model]]), numeric(1)),
        stringsAsFactors = FALSE
      )
    )
  }))
}

model_colors <- c(
  B0_DRIFT = "#94A3B8", B1_RAW = "#2B6CB0", Q2_PATH = "#0F766E",
  C0_CLOCK = "#D6A84B", C1_CLOCK_RAW = "#C05621", C2_CLOCK_PATH = "#7C3AED"
)

plot_model_losses <- function(summary, path, contract) {
  png(path, width = 2200, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(8, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  for (models in list(contract$model_ids[1:3], contract$model_ids[4:6])) {
    groups <- split(summary$mean_scaled_loss, factor(summary$model_id, levels = models))
    boxplot(
      groups, col = unname(model_colors[models]), border = "#334155", log = "y",
      ylab = "Mean DEVELOPMENT scaled loss (log)", xlab = "TRAIN-fitted authority",
      main = if (models[[1L]] == "B0_DRIFT") "Exact drop-in chain" else "Clock-aware chain",
      las = 2
    )
    for (i in seq_along(groups)) points(
      jitter(rep(i, length(groups[[i]])), amount = 0.08), groups[[i]],
      pch = 19, cex = 0.55, col = grDevices::adjustcolor("#0F172A", alpha.f = 0.35)
    )
  }
}

plot_incremental_skill <- function(decisions, path) {
  x <- decisions[decisions$comparison_complete, , drop = FALSE]
  png(path, width = 2200, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(7, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  color <- ifelse(x$candidate_fdr, "#2563EB", "#94A3B8")
  pch <- ifelse(x$is_clock_controlled_path_candidate, 19, 1)
  plot(x$d21_mean, x$d20_mean, pch = pch, col = color,
       xlab = "D21: path improvement over raw", ylab = "D20: path improvement over drift",
       main = "Exact bar-domain chain")
  abline(h = 0, v = 0, col = "#CBD5E1")
  text(x$d21_mean[!x$candidate_fdr], x$d20_mean[!x$candidate_fdr],
       labels = x$symbol[!x$candidate_fdr], pos = 3, cex = 0.65, col = "#64748B")
  plot(x$k21_mean, x$k20_mean, pch = pch, col = color,
       xlab = "K21: clock-path improvement over clock-raw",
       ylab = "K20: clock-path improvement over clock baseline",
       main = "Clock-aware falsification chain")
  abline(h = 0, v = 0, col = "#CBD5E1")
  text(x$k21_mean[!x$candidate_fdr], x$k20_mean[!x$candidate_fdr],
       labels = x$symbol[!x$candidate_fdr], pos = 3, cex = 0.65, col = "#64748B")
  legend("bottomleft", legend = c("22 candidate stocks", "remembered/reference"),
         col = c("#2563EB", "#94A3B8"), pch = 19, bty = "n")
}

plot_primary_fdr <- function(contrasts, path, q) {
  x <- contrasts[contrasts$candidate_fdr & contrasts$contrast_id %in% c("K21", "K20"), , drop = FALSE]
  png(path, width = 2200, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(8, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  for (id in c("K21", "K20")) {
    z <- x[x$contrast_id == id, , drop = FALSE]
    z <- z[order(z$bh_q_value), , drop = FALSE]
    values <- -log10(pmax(z$bh_q_value, 1e-8))
    barplot(
      values, names.arg = z$symbol, las = 2, cex.names = 0.65,
      col = "#6B46C1", border = NA, ylab = "-log10(BH q)",
      main = if (id == "K21") "Clock-path over clock-raw" else "Clock-path over clock baseline",
      ylim = c(0, max(-log10(q) * 1.08, values * 1.08))
    )
    abline(h = -log10(q), col = "#B42318", lwd = 2, lty = 2)
  }
}

plot_mechanism <- function(summary, path) {
  png(path, width = 1700, height = 1000, res = 150)
  old <- par(mar = c(7, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  color <- ifelse(summary$candidate_fdr, "#2563EB", "#94A3B8")
  plot(
    summary$median_clock_gamma, summary$median_clock_delta,
    pch = 19, col = color,
    xlab = "Median clock-path coherent-positive coefficient",
    ylab = "Median clock-path shock-positive coefficient",
    main = "TRAIN mechanism direction across 24 clock-aware fits"
  )
  abline(h = 0, v = 0, col = "#CBD5E1")
  text(summary$median_clock_gamma[!summary$candidate_fdr],
       summary$median_clock_delta[!summary$candidate_fdr],
       labels = summary$symbol[!summary$candidate_fdr], pos = 3, cex = 0.7)
}

plot_slot_diagnostics <- function(slot_diagnostics, path) {
  x <- aggregate(
    mean_scaled_loss ~ anchor_slot + target_crosses_session + model_id,
    data = slot_diagnostics, FUN = mean
  )
  raw <- x[x$model_id == "C1_CLOCK_RAW", c("anchor_slot", "target_crosses_session", "mean_scaled_loss")]
  path_loss <- x[x$model_id == "C2_CLOCK_PATH", c("anchor_slot", "target_crosses_session", "mean_scaled_loss")]
  names(raw)[3L] <- "raw_loss"; names(path_loss)[3L] <- "path_loss"
  z <- merge(raw, path_loss, by = c("anchor_slot", "target_crosses_session"), all = FALSE)
  z$improvement <- z$raw_loss - z$path_loss
  png(path, width = 1800, height = 1000, res = 150)
  old <- par(mar = c(7, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  ylim <- range(c(0, z$improvement), finite = TRUE)
  plot(1:13, rep(NA_real_, 13), type = "n", ylim = ylim,
       xlab = "Signal bar slot (1 = 09:30 ET, 13 = 15:30 ET)",
       ylab = "Mean K21 scaled-loss improvement",
       main = "Predeclared clock and session-boundary diagnostic")
  for (crosses in c(FALSE, TRUE)) {
    y <- z[z$target_crosses_session == crosses, , drop = FALSE]
    lines(y$anchor_slot, y$improvement, type = "b", pch = 19,
          col = if (crosses) "#D97706" else "#2563EB", lwd = 2)
  }
  abline(h = 0, col = "#CBD5E1")
  legend("bottomleft", legend = c("target stays in session", "target crosses session"),
         col = c("#2563EB", "#D97706"), lty = 1, pch = 19, bty = "n")
}

write_report <- function(result, run_spec, model_summary, paths, path) {
  candidate_contrasts <- result$contrasts[result$contrasts$candidate_fdr, , drop = FALSE]
  contrast_lines <- unlist(lapply(result$contract$contrast_ids, function(id) {
    x <- candidate_contrasts[candidate_contrasts$contrast_id == id, , drop = FALSE]
    paste0(
      "- `", id, "`: positive `", sum(x$observed_mean_differential > 0), " / ", nrow(x),
      "`; minimum p `", sprintf("%.6f", min(x$centered_null_upper_p)),
      "`; minimum BH q `", sprintf("%.6f", min(x$bh_q_value)), "`."
    )
  }))
  model_lines <- unlist(lapply(result$contract$model_ids, function(model) {
    x <- model_summary[model_summary$model_id == model, , drop = FALSE]
    paste0("- `", model, "`: median asset scaled loss `",
           sprintf("%.5f", stats::median(x$mean_scaled_loss)), "`.")
  }))
  best_lines <- unlist(lapply(list(
    exact = result$contract$model_ids[1:3], clock = result$contract$model_ids[4:6]
  ), function(models) {
    x <- model_summary[model_summary$model_id %in% models, , drop = FALSE]
    best <- do.call(rbind, lapply(split(x, x$analysis_id), function(y) y[which.min(y$mean_scaled_loss), ]))
    paste0("- `", models, "`: lowest-loss assets `",
           vapply(models, function(model) sum(best$model_id == model), integer(1)), " / ", nrow(best), "`.")
  }))
  candidates <- if (nrow(result$candidates)) {
    apply(result$candidates, 1L, function(row) paste0(
      "- `", row[["symbol"]], "`: K21 `", sprintf("%.5f", as.numeric(row[["k21_mean"]])),
      "`, K20 `", sprintf("%.5f", as.numeric(row[["k20_mean"]])), "`."
    ))
  } else "- No stock passed the complete clock-controlled path-quality gate."
  invalid <- result$ledger[result$ledger$mechanically_eligible & !result$ledger$analysis_eligible, , drop = FALSE]
  invalid_lines <- if (nrow(invalid)) apply(invalid, 1L, function(row) paste0(
    "- `", row[["symbol"]], "`: `", row[["eligibility_reason"]], "`."
  )) else "- No mechanically eligible instrument failed the analytical gate."
  lines <- c(
    "# LIT-IMOM-01.2 30-Minute Path-Quality Forecast Report", "",
    paste0("**Status:** `", result$overall_status, "`"), "",
    "## Frozen question", "",
    "Does positive-path coherence and shock concentration improve future-return forecasts in 30-minute bar units after raw return, drift, and TRAIN-fitted clock seasonality?", "",
    "## Boundary", "",
    "- Adjusted Alpaca SIP 30-minute bars; regular session only.",
    "- Frozen 26-instrument registry: 22 candidate stocks and four diagnostic-only rows.",
    "- TRAIN 2018-2020; DEVELOPMENT 2021-2023; all 24 numeric bar cells equally weighted.",
    "- Whole-session loss averages and expected 20-session stationary blocks.",
    "- 2024+ was not loaded. No strategy or performance outcome was computed.", "",
    "## Validity", "",
    paste0("- Mechanically eligible: `", run_spec$mechanically_eligible_assets, " / 26`."),
    paste0("- Analytically eligible: `", run_spec$analysis_eligible_assets, " / 26`."),
    paste0("- Complete cells: `", run_spec$complete_model_cells, " / ", 24L * run_spec$analysis_eligible_assets, "`."),
    invalid_lines, "",
    "## Model loss", "", model_lines, best_lines, "",
    "## Candidate-stock contrasts", "", contrast_lines, "",
    "## Mechanism", "",
    paste0("- Clock-aware coefficient medians aligned with Q positive / S negative for `",
           sum(result$coefficient_summary$clock_mechanism_aligned), " / ",
           nrow(result$coefficient_summary), "` eligible instruments."), "",
    "## Controlled candidates", "", candidates, "",
    "## Interpretation boundary", "",
    if (nrow(result$candidates)) {
      "Candidates are bounded DEVELOPMENT forecast discoveries only. They do not authorize horizon selection, trading, or confirmation."
    } else {
      "The bar-domain path extension did not survive the frozen exact, clock, dependence, mechanism, and multiplicity gates. Preserve confirmation and do not select favorable slots, horizons, or assets."
    }, "",
    "## Artifacts", "",
    paste0("- `", names(paths), "`: `", normalizePath(unlist(paths), winslash = "/", mustWork = FALSE), "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("LIT-IMOM-01.2 frozen 30-minute comparison starting.")
contract <- g5_imom012_contract()
registry_path <- file.path(repo_root, contract$registry_relative_path)
registry_hash <- g5_mom014_file_sha256(registry_path)
if (!identical(registry_hash, contract$registry_sha256)) stop("Frozen registry checksum changed.", call. = FALSE)
registry <- read.csv(registry_path, stringsAsFactors = FALSE)
registry <- g5_imom012_validate_registry(registry, contract)
bars_raw <- load_cached_bars(repo_root, contract)
bars <- g5_imom012_prepare_bars(bars_raw, registry, contract)
ledger <- g5_imom012_coverage_ledger(bars, registry, contract)

run_id <- env_or(
  "GEN5_LIT_IMOM_01_2_RUN_ID",
  "lit_imom_01_2_30min_path_quality_forecast_comparison_20260821"
)
preflight_only <- env_bool("GEN5_LIT_IMOM_01_2_PREFLIGHT_ONLY", FALSE)
output_dir <- file.path(repo_root, "runs", "research_workbench", "literature_grounded", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)
write_csv(registry, file.path(output_dir, "imom012_frozen_registry.csv"))
write_csv(ledger, file.path(output_dir, "imom012_preflight_coverage.csv"))
write_csv(data.frame(
  check = c("registry_sha256", "all_26_mechanically_eligible", "confirmation_absent", "archive_exclusions_applied"),
  status = c(
    if (identical(registry_hash, contract$registry_sha256)) "PASS" else "ERROR",
    if (sum(ledger$mechanically_eligible) == 26L) "PASS" else "ERROR",
    if (all(bars$session_date < contract$confirmation_start)) "PASS" else "ERROR",
    if (!any(bars$session_date %in% contract$archive_exclusion_dates)) "PASS" else "ERROR"
  ),
  detail = c(
    registry_hash,
    paste(sum(ledger$mechanically_eligible), "of 26"),
    paste("maximum session", max(bars$session_date)),
    paste(length(contract$archive_exclusion_dates), "dates excluded globally")
  ), stringsAsFactors = FALSE
), file.path(output_dir, "imom012_data_health.csv"))
if (sum(ledger$mechanically_eligible) != 26L) {
  stop("LIT-IMOM-01.2 coverage is incomplete; outcomes remain unread.", call. = FALSE)
}
if (preflight_only) {
  message("LIT-IMOM-01.2 preflight complete; forecast outcomes were not computed.")
  message("Mechanically eligible: 26 / 26")
  message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
  quit(save = "no", status = 0L)
}

result <- g5_imom012_run_comparison(bars_raw, registry, contract)
model_summary <- asset_model_summary(result$session_losses, contract)
run_spec <- data.frame(
  schema_version = g5_imom012_schema_version(), wrapper = basename(script_path), run_id = run_id,
  design_as_of_timestamp = contract$design_as_of_timestamp,
  cache_as_of_timestamp = contract$cache_as_of_timestamp,
  registry_sha256 = registry_hash, registry_assets = nrow(registry), candidate_assets = sum(registry$candidate_fdr),
  mechanically_eligible_assets = sum(result$ledger$mechanically_eligible),
  analysis_eligible_assets = sum(result$ledger$analysis_eligible),
  complete_model_cells = sum(result$ledger$valid_cell_count),
  path_candidates = nrow(result$candidates), raw_clues = nrow(result$raw_clues),
  confirmation_opened = result$confirmation_opened, strategy_outcomes_computed = FALSE,
  overall_status = result$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE), stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "imom012_run_spec.csv"),
  frozen_contract = file.path(output_dir, "imom012_frozen_contract.csv"),
  registry = file.path(output_dir, "imom012_frozen_registry.csv"),
  health = file.path(output_dir, "imom012_data_health.csv"),
  coverage = file.path(output_dir, "imom012_coverage_and_eligibility.csv"),
  moments = file.path(output_dir, "imom012_train_feature_moments.csv"),
  coefficients = file.path(output_dir, "imom012_train_coefficients.csv"),
  cell_metrics = file.path(output_dir, "imom012_development_cell_metrics.csv"),
  anchor_losses = file.path(output_dir, "imom012_development_anchor_losses.csv"),
  session_losses = file.path(output_dir, "imom012_development_session_losses.csv"),
  model_summary = file.path(output_dir, "imom012_asset_model_summary.csv"),
  contrasts = file.path(output_dir, "imom012_development_contrasts.csv"),
  coefficient_summary = file.path(output_dir, "imom012_coefficient_summary.csv"),
  decisions = file.path(output_dir, "imom012_asset_decisions.csv"),
  candidates = file.path(output_dir, "imom012_path_candidates.csv"),
  raw_clues = file.path(output_dir, "imom012_raw_clues.csv"),
  role_summary = file.path(output_dir, "imom012_role_summary.csv"),
  slot_diagnostics = file.path(output_dir, "imom012_slot_diagnostics.csv"),
  model_loss_png = file.path(visual_dir, "imom012_model_loss_comparison.png"),
  skill_png = file.path(visual_dir, "imom012_incremental_skill.png"),
  fdr_png = file.path(visual_dir, "imom012_primary_fdr.png"),
  mechanism_png = file.path(visual_dir, "imom012_mechanism_coefficients.png"),
  slot_png = file.path(visual_dir, "imom012_slot_diagnostic.png"),
  report = file.path(output_dir, "imom012_report.md")
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$frozen_contract)
write_csv(result$ledger, paths$coverage)
write_csv(result$feature_moments, paths$moments)
write_csv(result$coefficients, paths$coefficients)
write_csv(result$cell_metrics, paths$cell_metrics)
write_csv(result$anchor_losses, paths$anchor_losses)
write_csv(result$session_losses, paths$session_losses)
write_csv(model_summary, paths$model_summary)
write_csv(result$contrasts, paths$contrasts)
write_csv(result$coefficient_summary, paths$coefficient_summary)
write_csv(result$decisions, paths$decisions)
write_optional(result$candidates, paths$candidates, "NO_CLOCK_CONTROLLED_PATH_CANDIDATES")
write_optional(result$raw_clues, paths$raw_clues, "NO_CLOCK_CONTROLLED_RAW_CLUES")
write_csv(result$role_summary, paths$role_summary)
write_csv(result$slot_diagnostics, paths$slot_diagnostics)
plot_model_losses(model_summary, paths$model_loss_png, contract)
plot_incremental_skill(result$decisions, paths$skill_png)
plot_primary_fdr(result$contrasts, paths$fdr_png, contract$fdr_q)
plot_mechanism(result$coefficient_summary, paths$mechanism_png)
plot_slot_diagnostics(result$slot_diagnostics, paths$slot_png)
write_report(result, run_spec, model_summary, paths, paths$report)

message("LIT-IMOM-01.2 complete: ", result$overall_status)
message("Eligible assets: ", sum(result$ledger$analysis_eligible), " / 26")
message("Complete retained cells: ", sum(result$ledger$valid_cell_count))
message("Raw clues: ", nrow(result$raw_clues))
message("Path candidates: ", nrow(result$candidates))
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report, winslash = "/", mustWork = FALSE))
