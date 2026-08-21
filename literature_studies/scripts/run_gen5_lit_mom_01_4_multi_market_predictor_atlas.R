# Run the frozen LIT-MOM-01.4 multi-market predictor atlas.

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
  "gen5_lit_mom_01_3_spy_horizon_surface.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_4_multi_market_predictor_atlas.R"
))
g5_load_local_renviron(repo_root)

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
  if (!dir.exists(path)) stop("Could not create LIT-MOM-01.4 output directory.", call. = FALSE)
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

spy_reproduction <- function(bars) {
  contract <- g5_mom013_contract()
  spy <- bars[bars$symbol == "SPY", , drop = FALSE]
  panel <- g5_mom013_common_panel(spy, contract)
  surface <- g5_mom013_surface(panel, contract)
  shift <- g5_mom013_shift_control(panel, surface, contract)
  canonical <- surface[surface$is_canonical_250_25, , drop = FALSE]
  data.frame(
    check_id = c("observed_surface_maximum", "shift_p90", "canonical_correlation"),
    expected = c(0.0162395999992757, 0.177057560913791, -0.118644065923134),
    observed = c(
      shift$decision$observed_maximum_correlation,
      shift$decision$null_percentile_threshold,
      canonical$correlation
    ),
    stringsAsFactors = FALSE
  ) |>
    transform(
      absolute_difference = abs(observed - expected),
      passed = abs(observed - expected) <= 1e-12,
      status = ifelse(abs(observed - expected) <= 1e-12, "PASS", "FAIL")
    )
}

stratum_colors <- c(
  PLAIN_ETF = "#3D8DFF",
  ENGINEERED_ETF = "#F59E0B",
  STOCK_CHALLENGER = "#8B5CF6"
)

plot_transport <- function(development, path) {
  png(path, width = 1800, height = 950, res = 150)
  old <- par(mar = c(7, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  colors <- unname(stratum_colors[development$analysis_stratum])
  pch <- ifelse(development$is_development_candidate, 19, 1)
  plot(
    development$train_correlation,
    development$correlation,
    pch = pch, cex = ifelse(development$is_development_candidate, 1.5, 1),
    col = colors,
    xlab = "TRAIN-selected cell correlation (2017-2020)",
    ylab = "Same fixed-cell DEVELOPMENT correlation (2021-2023)",
    main = "Independent horizon transport across the frozen atlas"
  )
  abline(h = 0, v = 0, col = "#CBD5E1")
  abline(0, 1, lty = 2, col = "#64748B")
  if (any(development$is_development_candidate)) {
    x <- development[development$is_development_candidate, , drop = FALSE]
    text(x$train_correlation, x$correlation, labels = x$symbol, pos = 3, cex = 0.75)
  }
  legend(
    "topleft", legend = names(stratum_colors), col = stratum_colors,
    pch = 19, bty = "n"
  )
}

plot_fdr <- function(development, path, q) {
  x <- development[!development$is_spy_reference, , drop = FALSE]
  x <- x[order(x$analysis_stratum, x$bh_q_value), , drop = FALSE]
  png(path, width = 2000, height = 1050, res = 150)
  old <- par(mar = c(10, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  values <- -log10(pmax(x$bh_q_value, 1e-6))
  bars <- barplot(
    values, names.arg = x$symbol, las = 2, cex.names = 0.52,
    col = unname(stratum_colors[x$analysis_stratum]), border = NA,
    ylab = "-log10(within-stratum BH q)",
    main = "Fixed-cell DEVELOPMENT evidence after asset multiplicity control"
  )
  abline(h = -log10(q), col = "#B42318", lwd = 2, lty = 2)
  legend(
    "topright",
    legend = c(names(stratum_colors), paste0("q = ", q)),
    col = c(stratum_colors, "#B42318"),
    pch = c(rep(15, length(stratum_colors)), NA),
    lty = c(rep(NA, length(stratum_colors)), 2), bty = "n"
  )
  invisible(bars)
}

plot_horizons <- function(nominees, path) {
  png(path, width = 1750, height = 950, res = 150)
  old <- par(mar = c(7, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  size <- 1 + 6 * nominees$correlation / max(nominees$correlation)
  plot(
    nominees$target_sessions,
    nominees$lookback_sessions,
    log = "xy", pch = 19, cex = size,
    col = grDevices::adjustcolor(
      unname(stratum_colors[nominees$analysis_stratum]), alpha.f = 0.55
    ),
    xlab = "Selected future target H (sessions, log scale)",
    ylab = "Selected past lookback L (sessions, log scale)",
    main = "TRAIN horizon selections; point size is TRAIN correlation",
    xaxt = "n", yaxt = "n"
  )
  axis(1, at = sort(unique(nominees$target_sessions)))
  axis(2, at = sort(unique(nominees$lookback_sessions)))
  grid(col = "#E2E8F0")
  legend("topright", legend = names(stratum_colors), col = stratum_colors, pch = 19, bty = "n")
}

plot_categories <- function(summary, path) {
  x <- summary[order(summary$analysis_stratum, summary$category), , drop = FALSE]
  png(path, width = 1900, height = 1050, res = 150)
  old <- par(mar = c(12, 7, 5, 2))
  on.exit({ par(old); dev.off() }, add = TRUE)
  values <- 100 * x$positive_development_rho / pmax(1, x$train_nominees)
  bars <- barplot(
    values, names.arg = x$category, las = 2, cex.names = 0.7,
    col = unname(stratum_colors[x$analysis_stratum]), border = NA,
    ylab = "Fixed TRAIN nominees with positive DEVELOPMENT rho (%)",
    main = "Transport breadth by predeclared economic category",
    ylim = c(0, max(100, values + 10))
  )
  text(bars, values, labels = paste0(x$fdr_candidates, " FDR"), pos = 3, cex = 0.72)
  legend("topright", legend = names(stratum_colors), col = stratum_colors, pch = 15, bty = "n")
}

plot_candidates <- function(result, path) {
  panel_rows <- max(1L, ceiling(nrow(result$candidates) / 2))
  png(path, width = 1900, height = max(950, 600 * panel_rows), res = 150)
  on.exit(dev.off(), add = TRUE)
  if (!nrow(result$candidates)) {
    plot.new()
    text(0.5, 0.60, "No FDR-controlled DEVELOPMENT candidates", cex = 1.8, font = 2, col = "#B42318")
    text(0.5, 0.42, result$overall_status, cex = 0.9)
    return(invisible(NULL))
  }
  old <- par(mfrow = c(ceiling(nrow(result$candidates) / 2), 2), mar = c(5, 5, 4, 2))
  on.exit(par(old), add = TRUE)
  for (i in seq_len(nrow(result$candidates))) {
    candidate <- result$candidates[i, , drop = FALSE]
    pairs <- result$candidate_pairs[result$candidate_pairs$analysis_id == candidate$analysis_id, , drop = FALSE]
    plot(
      100 * pairs$predictor_log_return, 100 * pairs$target_log_return,
      pch = 19, cex = 0.6,
      col = grDevices::adjustcolor(stratum_colors[[candidate$analysis_stratum]], alpha.f = 0.4),
      xlab = "Past log return (%)", ylab = "Future log return (%)",
      main = paste0(candidate$symbol, " ", candidate$cell_id, " | q=", sprintf("%.3f", candidate$bh_q_value))
    )
    abline(h = 0, v = 0, col = "#CBD5E1")
    abline(stats::lm(target_log_return ~ predictor_log_return, data = pairs), col = "#0F172A", lwd = 2)
  }
}

write_report <- function(result, run_spec, spy_checks, paths, path) {
  development <- result$development
  candidate_lines <- if (nrow(result$candidates)) {
    apply(result$candidates, 1L, function(row) {
      paste0(
        "- `", row[["symbol"]], "` (`", row[["analysis_stratum"]],
        "`, `", row[["cell_id"]], "`): TRAIN rho `",
        sprintf("%.4f", as.numeric(row[["train_correlation"]])),
        "`, DEVELOPMENT rho `", sprintf("%.4f", as.numeric(row[["correlation"]])),
        "`, beta `", sprintf("%.4f", as.numeric(row[["beta"]])),
        "`, BH q `", sprintf("%.4f", as.numeric(row[["bh_q_value"]])), "`."
      )
    })
  } else {
    "- No non-SPY asset passed the frozen within-stratum BH transport gate."
  }
  stratum_lines <- unlist(lapply(unique(result$registry$analysis_stratum), function(stratum) {
    registry_n <- sum(result$registry$analysis_stratum == stratum)
    eligible_n <- sum(result$ledger$analysis_stratum == stratum & result$ledger$analysis_eligible)
    dev <- development[development$analysis_stratum == stratum & !development$is_spy_reference, , drop = FALSE]
    paste0(
      "- `", stratum, "`: registry `", registry_n, "`, eligible `", eligible_n,
      "`, fixed-cell tests `", nrow(dev), "`, positive rho `",
      sum(dev$correlation > 0, na.rm = TRUE), "`, FDR candidates `",
      sum(dev$is_development_candidate, na.rm = TRUE), "`."
    )
  }))
  artifact_lines <- paste0(
    "- `", names(paths), "`: `",
    normalizePath(unlist(paths), winslash = "/", mustWork = FALSE), "`"
  )
  lines <- c(
    "# LIT-MOM-01.4 Multi-Market Predictor Atlas Report",
    "",
    paste0("**Status:** `", result$overall_status, "`"),
    "",
    "## Question",
    "",
    "Does an independently selected own-return horizon transport across diverse currently tradable market exposures after within-stratum false-discovery control?",
    "",
    "## Frozen boundary",
    "",
    "- Registry: all 92 checksum-frozen rows; no substitutions or remembered-winner filtering.",
    "- TRAIN: 2017-2020 horizon discovery only.",
    "- DEVELOPMENT: 2021-2023 fixed-cell inference only.",
    "- SPY is a reproduction reference and cannot become a candidate.",
    "- 2024-2025 confirmation was not queried or inspected.",
    "- No positions, costs, P&L, Sharpe, drawdown, portfolio, allocation, or live behavior were computed.",
    "",
    "## Data and implementation validity",
    "",
    paste0("- Registry SHA-256: `", attr(result$registry, "sha256"), "`."),
    paste0("- Mechanically eligible: `", sum(result$ledger$mechanically_eligible), " / 92`."),
    paste0("- Analysis eligible after common-anchor checks: `", sum(result$ledger$analysis_eligible), " / 92`."),
    paste0("- SPY reproduction checks: `", sum(spy_checks$passed), " / ", nrow(spy_checks), "` pass."),
    paste0("- Workbench health maximum: `", run_spec$data_health_max_severity, "`; requested-range refresh attempted: `", run_spec$refresh, "`."),
    "",
    "## Stratum readout",
    "",
    stratum_lines,
    "",
    "## FDR-controlled DEVELOPMENT candidates",
    "",
    candidate_lines,
    "",
    "## Interpretation",
    "",
    if (nrow(result$candidates)) {
      "The listed assets are bounded discovery/transport candidates, not confirmed effects or trading strategies. Freeze their identities and cells; only a later explicit operator gate may consume 2024-2025 confirmation."
    } else {
      "No asset transported strongly enough to survive the frozen within-stratum false-discovery control. Preserve confirmation and stop this atlas without choosing a visually attractive failure."
    },
    "",
    "## Artifacts",
    "",
    artifact_lines
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("LIT-MOM-01.4 frozen multi-market predictor atlas starting.")
contract <- g5_mom014_contract()
registry <- g5_mom014_read_registry(repo_root, contract)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_01_4_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_01_4_REFRESH", FALSE)
preflight_only <- env_bool("GEN5_LIT_MOM_01_4_PREFLIGHT_ONLY", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_01_4_RUN_ID",
  "lit_mom_01_4_multi_market_predictor_atlas_20260821"
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
  universe_name = "lit_mom_01_4_checksum_frozen_92_asset_atlas",
  universe_roles = paste(registry$analysis_stratum, collapse = ","),
  refresh = refresh,
  repo_root = repo_root
)
bars <- g5_mom014_validate_bars(query$bars, registry, contract)
preflight_ledger <- g5_mom014_coverage_ledger(bars, registry, contract)
workbench_paths <- invisible(g5_write_workbench_query_artifacts(
  query, output_dir, "mom014_workbench_query"
))
write_csv(registry, file.path(output_dir, "mom014_frozen_registry.csv"))
write_csv(preflight_ledger, file.path(output_dir, "mom014_preflight_coverage.csv"))
write_csv(
  data.frame(
    registry_sha256 = attr(registry, "sha256"),
    expected_registry_sha256 = contract$registry_sha256,
    passed = identical(attr(registry, "sha256"), contract$registry_sha256),
    stringsAsFactors = FALSE
  ),
  file.path(output_dir, "mom014_registry_checksum.csv")
)
if (preflight_only) {
  message("LIT-MOM-01.4 preflight complete; predictor outcomes were not computed.")
  message("Coverage-complete assets: ", sum(preflight_ledger$mechanically_eligible), " / 92")
  message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
  quit(save = "no", status = 0L)
}

result <- g5_mom014_run_atlas(bars, registry, contract)
spy_checks <- spy_reproduction(bars)
if (!all(spy_checks$passed)) {
  stop("LIT-MOM-01.4 SPY reproduction failed.", call. = FALSE)
}
health_max <- health_maximum(query$health)
run_spec <- data.frame(
  schema_version = g5_mom014_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_01_4_multi_market_predictor_atlas.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  registry_assets = nrow(registry),
  mechanically_eligible_assets = sum(result$ledger$mechanically_eligible),
  analysis_eligible_assets = sum(result$ledger$analysis_eligible),
  train_nominees = nrow(result$train_nominees),
  development_fixed_cell_tests = nrow(result$development),
  fdr_candidates = nrow(result$candidates),
  confirmation_opened = result$confirmation_opened,
  strategy_outcomes_computed = FALSE,
  overall_status = result$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "mom014_run_spec.csv"),
  frozen_contract = file.path(output_dir, "mom014_frozen_contract.csv"),
  registry_checksum = file.path(output_dir, "mom014_registry_checksum.csv"),
  frozen_registry = file.path(output_dir, "mom014_frozen_registry.csv"),
  coverage = file.path(output_dir, "mom014_coverage_and_eligibility.csv"),
  spy_reproduction = file.path(output_dir, "mom014_spy_reproduction.csv"),
  train_surface = file.path(output_dir, "mom014_train_surface.csv"),
  train_nominees = file.path(output_dir, "mom014_train_nominees.csv"),
  development = file.path(output_dir, "mom014_development_fixed_cells.csv"),
  shifts = file.path(output_dir, "mom014_development_shift_distributions.csv"),
  candidates = file.path(output_dir, "mom014_fdr_candidates.csv"),
  categories = file.path(output_dir, "mom014_category_summary.csv"),
  candidate_pairs = file.path(output_dir, "mom014_candidate_pairs.csv"),
  candidate_quintiles = file.path(output_dir, "mom014_candidate_quintiles.csv"),
  candidate_years = file.path(output_dir, "mom014_candidate_years.csv"),
  candidate_phases = file.path(output_dir, "mom014_candidate_phases.csv"),
  candidate_neighbors = file.path(output_dir, "mom014_candidate_neighbors.csv"),
  horizons_png = file.path(visual_dir, "mom014_train_horizon_selections.png"),
  transport_png = file.path(visual_dir, "mom014_train_development_transport.png"),
  fdr_png = file.path(visual_dir, "mom014_development_fdr.png"),
  categories_png = file.path(visual_dir, "mom014_category_transport.png"),
  candidates_png = file.path(visual_dir, "mom014_candidate_diagnostics.png"),
  report = file.path(output_dir, "mom014_report.md")
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$frozen_contract)
write_csv(result$ledger, paths$coverage)
write_csv(spy_checks, paths$spy_reproduction)
write_csv(result$train_surface, paths$train_surface)
write_csv(result$train_nominees, paths$train_nominees)
write_csv(result$development, paths$development)
write_csv(result$shift_distributions, paths$shifts)
write_optional(result$candidates, paths$candidates, "NO_FDR_CANDIDATES")
write_csv(result$category_summary, paths$categories)
write_optional(result$candidate_pairs, paths$candidate_pairs, "NO_FDR_CANDIDATES")
write_optional(result$candidate_quintiles, paths$candidate_quintiles, "NO_FDR_CANDIDATES")
write_optional(result$candidate_years, paths$candidate_years, "NO_FDR_CANDIDATES")
write_optional(result$candidate_phases, paths$candidate_phases, "NO_FDR_CANDIDATES")
write_optional(result$candidate_neighbors, paths$candidate_neighbors, "NO_FDR_CANDIDATES")

plot_horizons(result$train_nominees, paths$horizons_png)
plot_transport(result$development, paths$transport_png)
plot_fdr(result$development, paths$fdr_png, contract$fdr_q)
plot_categories(result$category_summary, paths$categories_png)
plot_candidates(result, paths$candidates_png)
write_report(result, run_spec, spy_checks, paths, paths$report)

message("LIT-MOM-01.4 complete: ", result$overall_status)
message("Data health: ", health_max)
message("Eligible assets: ", sum(result$ledger$analysis_eligible), " / 92")
message("FDR candidates: ", nrow(result$candidates))
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report, winslash = "/", mustWork = FALSE))
