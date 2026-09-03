# Run the source-faithful LIT-MOM-03.1 signal and allocation mechanics packet.

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
  "gen5_lit_mom_03_1_dual_momentum_mechanics.R"
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
  if (!dir.exists(path)) stop("Could not create LIT-MOM-03.1 output directory.", call. = FALSE)
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

health_maximum <- function(health) {
  if (!nrow(health)) return("PASS")
  severity <- toupper(as.character(health$severity))
  rank <- c(PASS = 1L, INFO = 1L, WARN = 2L, ERROR = 3L)
  observed <- unname(rank[severity])
  observed[is.na(observed)] <- 3L
  names(rank)[which(rank == max(observed))[1L]]
}

weight_long <- function(allocations, contract) {
  weight_columns <- c(paste0("weight_", contract$universe), "cash_weight")
  labels <- c(contract$universe, contract$cash_symbol)
  do.call(rbind, lapply(seq_along(weight_columns), function(index) {
    data.frame(
      decision_date = allocations$decision_date,
      sleeve = labels[[index]],
      weight = allocations[[weight_columns[[index]]]],
      stringsAsFactors = FALSE
    )
  }))
}

plot_allocation_timeline <- function(allocations, contract, path) {
  weights <- t(as.matrix(allocations[, c(paste0("weight_", contract$universe), "cash_weight"), drop = FALSE]))
  colors <- c(
    "#5B8FF9", "#61DDAA", "#65789B", "#F6BD16", "#E8684A",
    "#6DC8EC", "#9270CA", "#FF9D4D", "#269A99", "#D7DCE5"
  )
  png(path, width = 1800, height = 980, res = 150)
  old <- par(mar = c(5, 5, 5, 10), xpd = TRUE)
  on.exit({ par(old); dev.off() }, add = TRUE)
  area_x <- as.numeric(allocations$decision_date)
  cumulative <- apply(weights, 2L, cumsum)
  plot(
    allocations$decision_date, rep(0, nrow(allocations)), type = "n",
    ylim = c(0, 1), xlab = "Weekly decision date", ylab = "Target weight",
    main = "LIT-MOM-03.1 weekly allocation tape (mechanics only)", xaxt = "n"
  )
  lower <- rep(0, nrow(allocations))
  for (index in seq_len(nrow(weights))) {
    upper <- cumulative[index, ]
    polygon(c(area_x, rev(area_x)), c(lower, rev(upper)), col = colors[[index]], border = NA)
    lower <- upper
  }
  axis.Date(1, at = seq(min(allocations$decision_date), max(allocations$decision_date), by = "2 years"), format = "%Y")
  legend(
    "topright", inset = c(-0.18, 0), legend = c(contract$universe, contract$cash_symbol),
    fill = colors, border = NA, bty = "n", cex = 0.85
  )
  mtext("Weights are derived from the Wednesday close and designated for the next common-session open.", side = 3, line = 0.6, cex = 0.82)
}

plot_representatives <- function(representatives, contract, path) {
  matrix_values <- t(as.matrix(representatives[, c(paste0("weight_", contract$universe), "cash_weight"), drop = FALSE]))
  rownames(matrix_values) <- c(contract$universe, contract$cash_symbol)
  colors <- c(
    "#5B8FF9", "#61DDAA", "#65789B", "#F6BD16", "#E8684A",
    "#6DC8EC", "#9270CA", "#FF9D4D", "#269A99", "#D7DCE5"
  )
  png(path, width = 1800, height = 980, res = 150)
  old <- par(mar = c(8, 5, 5, 18), xpd = TRUE)
  on.exit({ par(old); dev.off() }, add = TRUE)
  mids <- barplot(
    matrix_values, beside = FALSE, col = colors, border = NA, ylim = c(0, 1),
    names.arg = format(representatives$decision_date, "%Y-%m-%d"), las = 2,
    ylab = "Target weight", main = "Fixed historical allocation snapshots"
  )
  abline(h = seq(0, 1, by = 1 / 6), col = "#FFFFFF88", lwd = 0.8)
  legend(
    "topright", inset = c(-0.30, 0), legend = rownames(matrix_values),
    fill = colors, border = NA, bty = "n", cex = 0.78, ncol = 2
  )
  mtext("Each colored block is an exact one-sixth slot; duplicate sleeve selections stack to one-third.", side = 3, line = 0.6, cex = 0.82)
}

write_report <- function(run_spec, result, paths) {
  latest <- result$allocations[nrow(result$allocations), , drop = FALSE]
  lines <- c(
    "# LIT-MOM-03.1 dual-momentum mechanics reproduction",
    "",
    "## Question",
    "",
    "Can the source-described nine-ETF dual-momentum rule be translated into a deterministic, auditable weekly signal and allocation tape before any outcome test is opened?",
    "",
    "## Readout",
    "",
    paste0("- Status: `", run_spec$overall_status, "`."),
    paste0("- Data health maximum: `", run_spec$data_health_max_severity, "`."),
    paste0("- Weekly decisions: `", run_spec$decision_weeks, "`, from `", run_spec$first_decision_date, "` through `", run_spec$last_decision_date, "`."),
    "- The exact rule mechanics were reproduced on the clean 2016-2026 Alpaca window. The publisher's 2008-2026 span remains unreproduced because this account returned no pre-2016 bars; it is an explicit coverage STOP, not silently truncated evidence.",
    paste0("- Holiday fallbacks: `", run_spec$holiday_fallback_weeks, "` weeks used the last complete common session in the same Monday-Wednesday window."),
    paste0("- Latest 10-week sleeve: `", latest$selected_10w, "`; latest 25-week sleeve: `", latest$selected_25w, "`; cash: `", sprintf("%.1f%%", 100 * latest$cash_weight), "`."),
    "- Every failed positive-momentum slot remains cash. An ETF selected by both sleeves receives two one-sixth slots.",
    "- No outcome returns, P&L, Sharpe, drawdown, wealth curve, or promotion decision were computed in this slice.",
    "",
    "## Frozen implementation choices",
    "",
    "- Inputs: Alpaca adjusted daily OHLCV, using adjusted close for ranking.",
    "- Weekly decision: Wednesday close; a holiday or missing common session falls back only within Monday-Wednesday.",
    "- Ranking: 10-week and 25-week simple rate of change, descending; alphabetical symbol order breaks exact ties.",
    "- Construction: top three per sleeve, each sleeve 50%, each slot one-sixth, and only positive-ROC selections are funded.",
    "- Execution translation: target weights are designated for the next complete common-session open.",
    "",
    "## Operator surfaces",
    "",
    paste0("- Weekly scores: `", basename(paths$scores), "`."),
    paste0("- Weekly allocation tape: `", basename(paths$allocations), "`."),
    paste0("- Fixed snapshots: `", basename(paths$representatives), "`."),
    paste0("- Integrity ledger: `", basename(paths$integrity), "`."),
    paste0("- Visuals: `", basename(paths$timeline_png), "` and `", basename(paths$representatives_png), "`."),
    "",
    "## STOP / next gate",
    "",
    "The source mechanics are reproducible on the admitted local window. This is not evidence that the strategy is profitable, and the publisher's full historical span remains blocked. The next gate, if opened by the operator, is a causal 2016-2026 replay with explicit execution timing, costs, and long-only comparator baselines."
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("LIT-MOM-03.1 dual-momentum mechanics reproduction starting.")
contract <- g5_mom031_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_03_1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_03_1_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_03_1_RUN_ID",
  "lit_mom_03_1_dual_momentum_mechanics_20260902"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$signal_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = contract$universe,
  universe_name = "lit_mom_03_1_source_nine_etf_universe",
  universe_roles = "source_replication_assets",
  refresh = refresh,
  repo_root = repo_root
)
query_paths <- invisible(g5_write_workbench_query_artifacts(
  query, output_dir, "mom031_workbench_query"
))
health_max <- health_maximum(query$health)
if (health_max %in% c("WARN", "ERROR")) {
  stop(paste(
    "LIT-MOM-03.1 data admission stopped at", health_max,
    "because the requested coverage is not clean; inspect mom031_workbench_query_data_health.csv."
  ), call. = FALSE)
}

result <- g5_mom031_run(query$bars, contract)
allocation_long <- weight_long(result$allocations, contract)
summary <- data.frame(
  measure = c(
    "decision_weeks", "holiday_fallback_weeks", "all_cash_weeks",
    "fully_invested_weeks", "weeks_with_sleeve_overlap", "mean_cash_weight",
    "minimum_cash_weight", "maximum_cash_weight"
  ),
  value = c(
    nrow(result$allocations),
    sum(result$allocations$used_holiday_fallback),
    sum(abs(result$allocations$cash_weight - 1) < 1e-12),
    sum(result$allocations$cash_weight < 1e-12),
    sum(result$allocations$sleeve_overlap > 0),
    mean(result$allocations$cash_weight),
    min(result$allocations$cash_weight),
    max(result$allocations$cash_weight)
  ),
  stringsAsFactors = FALSE
)
run_spec <- data.frame(
  schema_version = g5_mom031_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_03_1_dual_momentum_mechanics.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  decision_weeks = nrow(result$allocations),
  first_decision_date = min(result$allocations$decision_date),
  last_decision_date = max(result$allocations$decision_date),
  holiday_fallback_weeks = sum(result$allocations$used_holiday_fallback),
  performance_surface_opened = contract$performance_opened,
  outcome_metrics_computed = FALSE,
  overall_status = "MECHANICS_REPRODUCTION_PASS_LOCAL_WINDOW_PUBLISHED_WINDOW_BLOCKED",
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "mom031_run_spec.csv"),
  contract = file.path(output_dir, "mom031_frozen_contract.csv"),
  bar_integrity = file.path(output_dir, "mom031_bar_integrity.csv"),
  integrity = file.path(output_dir, "mom031_mechanics_integrity.csv"),
  anchors = file.path(output_dir, "mom031_weekly_anchors.csv"),
  scores = file.path(output_dir, "mom031_weekly_scores.csv"),
  allocations = file.path(output_dir, "mom031_weekly_allocation_tape.csv"),
  allocation_long = file.path(output_dir, "mom031_allocation_long.csv"),
  representatives = file.path(output_dir, "mom031_representative_allocations.csv"),
  summary = file.path(output_dir, "mom031_mechanics_summary.csv"),
  timeline_png = file.path(visual_dir, "mom031_allocation_timeline.png"),
  representatives_png = file.path(visual_dir, "mom031_representative_allocations.png"),
  report = file.path(output_dir, "mom031_report.md")
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$contract)
write_csv(result$panel$integrity, paths$bar_integrity)
write_csv(result$integrity, paths$integrity)
write_csv(result$anchors, paths$anchors)
write_csv(result$scores, paths$scores)
write_csv(result$allocations, paths$allocations)
write_csv(allocation_long, paths$allocation_long)
write_csv(result$representatives, paths$representatives)
write_csv(summary, paths$summary)
plot_allocation_timeline(result$allocations, contract, paths$timeline_png)
plot_representatives(result$representatives, contract, paths$representatives_png)
write_report(run_spec, result, paths)

message("LIT-MOM-03.1 mechanics reproduction complete.")
message("Status: ", run_spec$overall_status)
message("Data health: ", health_max)
message("Decision weeks: ", nrow(result$allocations))
message("Performance surface opened: FALSE")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
