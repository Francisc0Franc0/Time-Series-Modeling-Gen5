# Run the frozen LIT-MOM-01.3 SPY predictor horizon surface.

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
  if (!dir.exists(path)) stop("Could not create LIT-MOM-01.3 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract_table <- function(contract) {
  data.frame(
    field = names(contract),
    value = vapply(contract, function(value) paste(value, collapse = ","), character(1)),
    stringsAsFactors = FALSE
  )
}

coverage_audit <- function(bars, contract) {
  dates <- sort(unique(as.Date(bars$session_date[bars$symbol == contract$symbol])))
  data.frame(
    check_id = c(
      "query_start_covered", "sandbox_end_covered", "confirmation_excluded",
      "single_symbol", "nonempty_history"
    ),
    passed = c(
      length(dates) > 0L && min(dates) <= contract$query_start,
      length(dates) > 0L && max(dates) >= contract$sandbox_end,
      length(dates) > 0L && max(dates) < contract$confirmation_start,
      identical(unique(as.character(bars$symbol)), contract$symbol),
      length(dates) > contract$common_lookback_sessions + contract$common_target_sessions
    ),
    observed = c(
      if (length(dates)) as.character(min(dates)) else "none",
      if (length(dates)) as.character(max(dates)) else "none",
      if (length(dates)) as.character(max(dates)) else "none",
      paste(unique(as.character(bars$symbol)), collapse = ","),
      as.character(length(dates))
    ),
    stringsAsFactors = FALSE
  )
}

empty_nominee <- function() {
  data.frame(
    nominee_status = "NO_NOMINEE_SURFACE_GATE_FAILED",
    confirmation_opened = FALSE,
    stringsAsFactors = FALSE
  )
}

write_optional <- function(x, path, empty_status) {
  if (nrow(x)) {
    write_csv(x, path)
  } else {
    write_csv(data.frame(status = empty_status, stringsAsFactors = FALSE), path)
  }
}

plot_surface <- function(surface, path, contract) {
  png(path, width = 1900, height = 900, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(6, 6, 5, 2))
  on.exit({
    par(old)
    dev.off()
  }, add = TRUE)
  metrics <- list(
    correlation = list(title = "Predictor/target correlation", digits = 3L),
    beta = list(title = "OLS slope: future on past", digits = 3L)
  )
  for (metric in names(metrics)) {
    matrix_values <- matrix(
      NA_real_, nrow = length(contract$lookback_grid),
      ncol = length(contract$target_grid)
    )
    for (row_i in seq_len(nrow(surface))) {
      l_i <- match(surface$lookback_sessions[[row_i]], contract$lookback_grid)
      h_i <- match(surface$target_sessions[[row_i]], contract$target_grid)
      matrix_values[l_i, h_i] <- surface[[metric]][[row_i]]
    }
    colors <- grDevices::colorRampPalette(c("#B42318", "#F8FAFC", "#177245"))(101)
    limit <- max(abs(matrix_values), na.rm = TRUE)
    image(
      x = seq_along(contract$target_grid),
      y = seq_along(contract$lookback_grid),
      z = t(matrix_values),
      col = colors, zlim = c(-limit, limit), axes = FALSE,
      xlab = "Future open-to-open target H (sessions)",
      ylab = "Past close-to-close lookback L (sessions)",
      main = metrics[[metric]]$title
    )
    axis(1, at = seq_along(contract$target_grid), labels = contract$target_grid)
    axis(2, at = seq_along(contract$lookback_grid), labels = contract$lookback_grid)
    box()
    for (l_i in seq_along(contract$lookback_grid)) {
      for (h_i in seq_along(contract$target_grid)) {
        text(h_i, l_i, sprintf("%.3f", matrix_values[l_i, h_i]), cex = 0.82)
      }
    }
  }
}

plot_shift_control <- function(distribution, decision, path) {
  png(path, width = 1500, height = 900, res = 150)
  old <- par(mar = c(6, 7, 5, 2))
  on.exit({
    par(old)
    dev.off()
  }, add = TRUE)
  hist(
    distribution$maximum_correlation, breaks = "FD",
    col = "#CBD5E1", border = "white",
    xlab = "Maximum correlation anywhere on the 28-cell shifted surface",
    main = paste0("Global horizon-search control: ", decision$status),
    ylab = "Circular shifts"
  )
  abline(v = decision$null_percentile_threshold, col = "#F59E0B", lwd = 3, lty = 2)
  abline(v = decision$observed_maximum_correlation, col = "#3D8DFF", lwd = 3)
  legend(
    "topright",
    legend = c(
      paste0("Observed max = ", sprintf("%.3f", decision$observed_maximum_correlation)),
      paste0("Shift p90 = ", sprintf("%.3f", decision$null_percentile_threshold))
    ),
    col = c("#3D8DFF", "#F59E0B"), lty = c(1, 2), lwd = 3, bty = "n"
  )
}

plot_cell <- function(pairs, quintiles, cell_id, path) {
  png(path, width = 1800, height = 850, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(6, 7, 5, 2))
  on.exit({
    par(old)
    dev.off()
  }, add = TRUE)
  plot(
    100 * pairs$predictor_log_return,
    100 * pairs$target_log_return,
    pch = 19, cex = 0.7,
    col = grDevices::adjustcolor("#3D8DFF", alpha.f = 0.45),
    xlab = "Past adjusted close-to-close log return (%)",
    ylab = "Future adjusted open-to-open log return (%)",
    main = paste0(cell_id, ": direct predictor pairs")
  )
  abline(h = 0, v = 0, col = "#CBD5E1")
  abline(stats::lm(target_log_return ~ predictor_log_return, data = pairs), col = "#0F172A", lwd = 2)
  values <- 100 * quintiles$mean_target_log_return
  bars <- barplot(
    values, names.arg = quintiles$quintile,
    col = "#3D8DFF", border = NA,
    xlab = "Past-return quintile", ylab = "Mean future log return (%)",
    main = paste0(cell_id, ": monotonicity view")
  )
  abline(h = 0, col = "#0F172A")
  text(bars, values, sprintf("%.2f", values), pos = ifelse(values >= 0, 3, 1), cex = 0.85)
}

plot_no_nominee <- function(status, path) {
  png(path, width = 1500, height = 650, res = 150)
  on.exit(dev.off(), add = TRUE)
  plot.new()
  text(0.5, 0.60, "No horizon nominee", cex = 2, font = 2, col = "#B42318")
  text(0.5, 0.40, status, cex = 1.05)
}

write_report <- function(result, coverage, run_spec, artifact_paths, path) {
  decision <- result$decision[1L, , drop = FALSE]
  canonical <- result$canonical[1L, , drop = FALSE]
  nominee_lines <- if (nrow(result$nominee)) {
    nominee <- result$nominee[1L, , drop = FALSE]
    c(
      paste0("- Nominee: `", nominee$cell_id, "`."),
      paste0("- Nominee correlation: `", sprintf("%.6f", nominee$correlation), "`."),
      paste0("- Nominee beta: `", sprintf("%.6f", nominee$beta), "`."),
      paste0(
        "- Nominee stationary-bootstrap 90% beta interval: `[",
        sprintf("%.6f", nominee$beta_ci_lower_90), ", ",
        sprintf("%.6f", nominee$beta_ci_upper_90), "]`."
      ),
      "- The nominee is frozen, but 2024-2025 confirmation remains closed."
    )
  } else {
    c(
      "- No horizon was nominated because the global surface gate failed.",
      "- The result stops here; 2024-2025 confirmation remains closed."
    )
  }
  artifact_lines <- paste0(
    "- `", names(artifact_paths), "`: `",
    normalizePath(unlist(artifact_paths), winslash = "/", mustWork = FALSE), "`"
  )
  lines <- c(
    "# LIT-MOM-01.3 SPY Horizon-Surface Predictor Report",
    "",
    paste0("**Status:** `", result$overall_status, "`"),
    "",
    "## Question",
    "",
    "Does past SPY close-to-close return predict a later SPY open-to-open return anywhere on the frozen 7 x 4 horizon surface, after controlling for the horizon search?",
    "",
    "## Frozen boundary",
    "",
    paste0("- Sandbox anchors: `", result$contract$sandbox_start, "` through target exits no later than `", result$contract$sandbox_end, "`."),
    paste0("- Common anchors: `", nrow(result$panel$x), "`; all cells share the 250-session warm-up and 60-session future availability rule."),
    "- 2024-2025 confirmation data were not queried or inspected.",
    "- This packet contains predictor evidence only: no positions, trades, costs, P&L, Sharpe, drawdown, allocation, or live behavior.",
    "",
    "## Search-adjusted decision",
    "",
    paste0("- Global gate: **", decision$status, "**."),
    paste0("- Observed maximum cell correlation: `", sprintf("%.6f", decision$observed_maximum_correlation), "`."),
    paste0("- Joint circular-shift p90 maximum: `", sprintf("%.6f", decision$null_percentile_threshold), "`."),
    paste0("- Empirical upper-tail p-value: `", sprintf("%.6f", decision$empirical_upper_p_value), "` from `", decision$null_shift_count, "` admissible shifts."),
    "",
    "## Nomination result",
    "",
    nominee_lines,
    "",
    "## Canonical Chan 250/25 reference cell",
    "",
    paste0("- Correlation: `", sprintf("%.6f", canonical$correlation), "`."),
    paste0("- Beta: `", sprintf("%.6f", canonical$beta), "`."),
    paste0(
      "- Stationary-bootstrap 90% beta interval: `[",
      sprintf("%.6f", canonical$beta_ci_lower_90), ", ",
      sprintf("%.6f", canonical$beta_ci_upper_90), "]`."
    ),
    "",
    "## Data authority",
    "",
    paste0("- As-of timestamp: `", run_spec$as_of_timestamp, "`."),
    paste0("- Feed: `", run_spec$feed, "`; adjusted daily bars."),
    paste0("- Coverage checks: `", sum(coverage$passed), " / ", nrow(coverage), "` pass."),
    "",
    "## Artifacts",
    "",
    artifact_lines
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("LIT-MOM-01.3 frozen SPY horizon-surface sandbox starting.")
contract <- g5_mom013_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_01_3_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_01_3_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_01_3_RUN_ID",
  "lit_mom_01_3_spy_horizon_surface_20260821"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$sandbox_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = contract$symbol,
  universe_name = "lit_mom_01_3_spy_predictor_sandbox",
  universe_roles = "single_asset_predictor_target_sandbox",
  refresh = refresh,
  repo_root = repo_root
)
coverage <- coverage_audit(query$bars, contract)
if (!all(coverage$passed)) {
  stop("LIT-MOM-01.3 sandbox coverage audit failed.", call. = FALSE)
}
result <- g5_mom013_run_sandbox(query$bars, contract)

artifact_paths <- list(
  run_spec = file.path(output_dir, "mom013_run_spec.csv"),
  frozen_contract = file.path(output_dir, "mom013_frozen_contract.csv"),
  coverage = file.path(output_dir, "mom013_coverage_audit.csv"),
  integrity = file.path(output_dir, "mom013_integrity_audit.csv"),
  common_panel = file.path(output_dir, "mom013_common_anchor_panel.csv"),
  surface = file.path(output_dir, "mom013_surface_summary.csv"),
  shift_distribution = file.path(output_dir, "mom013_circular_shift_maxima.csv"),
  decision = file.path(output_dir, "mom013_surface_decision.csv"),
  nominee = file.path(output_dir, "mom013_nominee.csv"),
  canonical = file.path(output_dir, "mom013_canonical_250_25.csv"),
  nominee_pairs = file.path(output_dir, "mom013_nominee_pairs.csv"),
  nominee_quintiles = file.path(output_dir, "mom013_nominee_quintiles.csv"),
  nominee_sign = file.path(output_dir, "mom013_nominee_sign_confusion.csv"),
  nominee_years = file.path(output_dir, "mom013_nominee_years.csv"),
  nominee_phases = file.path(output_dir, "mom013_nominee_phase_offsets.csv"),
  nominee_neighbors = file.path(output_dir, "mom013_nominee_neighbors.csv"),
  surface_png = file.path(visual_dir, "mom013_surface_heatmaps.png"),
  shift_png = file.path(visual_dir, "mom013_search_adjusted_control.png"),
  canonical_png = file.path(visual_dir, "mom013_canonical_250_25.png"),
  nominee_png = file.path(visual_dir, "mom013_nominee_diagnostic.png"),
  report = file.path(output_dir, "mom013_report.md")
)

health <- query$health
health_max <- if (!nrow(health)) "PASS" else {
  rank <- c(PASS = 1L, INFO = 1L, WARN = 2L, ERROR = 3L)
  observed <- rank[as.character(health$severity)]
  names(rank)[which.max(rank == max(observed, na.rm = TRUE))]
}
run_spec <- data.frame(
  schema_version = g5_mom013_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_01_3_spy_horizon_surface.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  symbol = contract$symbol,
  sandbox_start = contract$sandbox_start,
  sandbox_end = contract$sandbox_end,
  common_anchor_count = nrow(result$panel$x),
  surface_cell_count = nrow(result$surface),
  confirmation_opened = result$confirmation_opened,
  strategy_outcomes_computed = FALSE,
  overall_status = result$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
common_panel <- data.frame(
  anchor_date = result$panel$anchor_date,
  entry_date = result$panel$entry_date,
  maximum_exit_date = result$panel$maximum_exit_date,
  result$panel$x,
  result$panel$y,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

write_csv(run_spec, artifact_paths$run_spec)
write_csv(contract_table(contract), artifact_paths$frozen_contract)
write_csv(coverage, artifact_paths$coverage)
write_csv(result$panel$integrity, artifact_paths$integrity)
write_csv(common_panel, artifact_paths$common_panel)
write_csv(result$surface, artifact_paths$surface)
write_csv(result$shift_distribution, artifact_paths$shift_distribution)
write_csv(result$decision, artifact_paths$decision)
write_csv(if (nrow(result$nominee)) result$nominee else empty_nominee(), artifact_paths$nominee)
write_csv(result$canonical, artifact_paths$canonical)
write_optional(result$nominee_pairs, artifact_paths$nominee_pairs, "NO_NOMINEE")
write_optional(result$nominee_quintiles, artifact_paths$nominee_quintiles, "NO_NOMINEE")
write_optional(result$nominee_sign_confusion, artifact_paths$nominee_sign, "NO_NOMINEE")
write_optional(result$nominee_years, artifact_paths$nominee_years, "NO_NOMINEE")
write_optional(result$nominee_phase_offsets, artifact_paths$nominee_phases, "NO_NOMINEE")
write_optional(result$nominee_neighbors, artifact_paths$nominee_neighbors, "NO_NOMINEE")

plot_surface(result$surface, artifact_paths$surface_png, contract)
plot_shift_control(result$shift_distribution, result$decision, artifact_paths$shift_png)
canonical_pairs <- g5_mom013_cell_pairs(
  result$panel, contract$canonical_lookback, contract$canonical_target, contract
)
plot_cell(
  canonical_pairs, g5_mom013_quintiles(canonical_pairs),
  "L250_H25", artifact_paths$canonical_png
)
if (nrow(result$nominee)) {
  plot_cell(
    result$nominee_pairs, result$nominee_quintiles,
    result$nominee$cell_id[[1L]], artifact_paths$nominee_png
  )
} else {
  plot_no_nominee(result$overall_status, artifact_paths$nominee_png)
}

write_report(result, coverage, run_spec, artifact_paths, artifact_paths$report)
invisible(g5_write_workbench_query_artifacts(
  query, output_dir, "mom013_workbench_query"
))

message("LIT-MOM-01.3 complete: ", result$overall_status)
message("Data health: ", health_max)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report, winslash = "/", mustWork = FALSE))
