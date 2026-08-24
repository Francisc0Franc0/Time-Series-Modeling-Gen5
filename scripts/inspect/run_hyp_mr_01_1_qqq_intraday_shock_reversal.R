# Run frozen HYP-MR-01.1 TRAIN, then DEVELOPMENT only after a complete TRAIN pass.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "scripts/inspect/run_hyp_mr_01_1_qqq_intraday_shock_reversal.R"
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mr_01_1_qqq_intraday_shock_reversal.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create HYP-MR-01.1 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract_table <- function(contract) {
  data.frame(
    field = names(contract),
    value = vapply(contract, function(x) paste(x, collapse = ","), character(1)),
    stringsAsFactors = FALSE
  )
}

health_severity <- function(health) {
  if (!nrow(health)) return("PASS")
  rank <- c(PASS = 1L, INFO = 1L, WARN = 2L, ERROR = 3L)
  values <- unname(rank[as.character(health$severity)])
  if (all(is.na(values))) return("UNKNOWN")
  names(rank)[which(rank == max(values, na.rm = TRUE))[[1L]]]
}

query_zone <- function(cfg, contract, end_date, universe_name, refresh) {
  g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = contract$query_start,
    end_date = end_date,
    as_of_timestamp = contract$as_of_timestamp,
    symbols = contract$symbol,
    universe_name = universe_name,
    universe_roles = "target",
    refresh = refresh,
    repo_root = repo_root
  )
}

coverage_table <- function(bars, contract, requested_end) {
  dates <- sort(unique(as.Date(bars$session_date[as.character(bars$symbol) == contract$symbol])))
  data.frame(
    symbol = contract$symbol,
    first_session = if (length(dates)) min(dates) else as.Date(NA),
    last_session = if (length(dates)) max(dates) else as.Date(NA),
    row_count = length(dates),
    duplicate_sessions = sum(duplicated(dates)),
    query_start_covered = length(dates) && min(dates) <= contract$query_start,
    requested_end_covered = length(dates) && max(dates) >= as.Date(requested_end),
    stringsAsFactors = FALSE
  )
}

source_audit <- function(coverage, bars, contract, requested_end) {
  numeric_fields <- c("open", "high", "low", "close", "volume")
  data.frame(
    check_id = c("exact_qqq", "adjusted_daily_only", "query_start_covered", "requested_end_covered", "positive_finite_ohlcv", "requested_boundary_respected", "post_2025_excluded"),
    passed = c(
      identical(unique(as.character(bars$symbol)), contract$symbol),
      all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
      coverage$query_start_covered[[1L]],
      coverage$requested_end_covered[[1L]],
      all(is.finite(as.matrix(bars[numeric_fields]))) && all(as.matrix(bars[numeric_fields]) > 0),
      max(as.Date(bars$session_date)) <= as.Date(requested_end),
      max(as.Date(bars$session_date)) < as.Date("2026-01-01")
    ),
    observed = c(
      paste(unique(as.character(bars$symbol)), collapse = ","),
      paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
      as.character(coverage$first_session[[1L]]),
      as.character(coverage$last_session[[1L]]),
      paste(range(as.matrix(bars[numeric_fields])), collapse = " to "),
      as.character(max(as.Date(bars$session_date))),
      as.character(max(as.Date(bars$session_date)))
    ),
    stringsAsFactors = FALSE
  )
}

plot_relation <- function(panel, statistics, deciles, path) {
  grDevices::png(path, width = 1600, height = 950, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(
    panel$x, 10000 * panel$y, pch = 16, cex = 0.55,
    col = grDevices::adjustcolor("#147D8C", alpha.f = 0.28),
    xlab = "Completed QQQ intraday move / prior ATR%",
    ylab = "Next-session open-to-close return (bp)",
    main = "HYP-MR-01.1 TRAIN relationship"
  )
  graphics::abline(h = 0, col = "#94A3B8")
  graphics::abline(
    a = 10000 * statistics$alpha[[1L]], b = 10000 * statistics$beta[[1L]],
    col = "#E97132", lwd = 3
  )
  graphics::lines(deciles$mean_x, 10000 * deciles$mean_target, col = "#172033", lwd = 3, type = "b", pch = 19)
  graphics::legend(
    "topright", c("Full-TRAIN OLS", "Predictor-decile means"),
    col = c("#E97132", "#172033"), lwd = 3, pch = c(NA, 19), bty = "n"
  )
}

plot_folds <- function(folds, path) {
  grDevices::png(path, width = 1400, height = 850, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  values <- 1e8 * folds$mse_improvement
  graphics::barplot(
    values, names.arg = folds$fold_year,
    col = ifelse(values > 0, "#147D8C", "#E97132"),
    ylab = "DRIFT MSE - REVERSAL MSE (x 1e8)",
    xlab = "One-year-ahead TRAIN fold",
    main = "Expanding-fold forecast improvement"
  )
  graphics::abline(h = 0, col = "#64748B", lwd = 2)
}

plot_shift <- function(distribution, decision, path) {
  grDevices::png(path, width = 1500, height = 900, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::hist(
    1e8 * distribution$oof_mse_improvement, breaks = 35,
    col = "#D7E3F4", border = "white",
    xlab = "Circular-shift OOF MSE improvement (x 1e8)",
    main = "Complete timing falsification control"
  )
  graphics::abline(v = 1e8 * decision$shift_p90[[1L]], col = "#B7791F", lwd = 3, lty = 2)
  graphics::abline(v = 1e8 * decision$observed_oof_mse_improvement[[1L]], col = "#166534", lwd = 3)
  graphics::legend("topright", c("Observed", "Shift-null p90"), col = c("#166534", "#B7791F"), lwd = 3, lty = c(1, 2), bty = "n")
}

plot_events <- function(panel, path) {
  candidates <- order(abs(panel$x), decreasing = TRUE)
  selected <- integer()
  for (i in candidates) {
    if (!length(selected) || all(abs(i - selected) >= 60L)) selected <- c(selected, i)
    if (length(selected) == 6L) break
  }
  grDevices::png(path, width = 1800, height = 1050, res = 150)
  old <- graphics::par(mfrow = c(2, 3), mar = c(5, 4, 4, 1))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  for (i in selected) {
    values <- 10000 * c(panel$current_intraday_return[[i]], panel$y[[i]])
    graphics::barplot(
      values, names.arg = c("signal day", "next day"),
      col = c("#147D8C", "#E97132"), ylab = "Open-to-close return (bp)",
      main = paste0(panel$anchor_date[[i]], " | x=", sprintf("%.2f", panel$x[[i]]))
    )
    graphics::abline(h = 0, col = "#64748B")
  }
}

plot_development_transport <- function(train, development, path) {
  grDevices::png(path, width = 1800, height = 850, res = 150)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  dev <- development$predictions
  graphics::plot(
    dev$x, 10000 * dev$y, pch = 16, cex = 0.55,
    col = grDevices::adjustcolor("#147D8C", alpha.f = 0.28),
    xlab = "Frozen normalized intraday move",
    ylab = "Next-session return (bp)",
    main = "DEVELOPMENT relationship"
  )
  graphics::abline(h = 0, col = "#94A3B8")
  graphics::abline(
    a = 10000 * development$metrics$frozen_alpha[[1L]],
    b = 10000 * development$metrics$frozen_beta[[1L]],
    col = "#E97132", lwd = 3
  )
  labels <- c(paste0("T", train$folds$fold_year), paste0("D", development$year_metrics$target_year))
  values <- 1e8 * c(train$folds$mse_improvement, development$year_metrics$mse_improvement)
  graphics::barplot(
    values, names.arg = labels,
    col = ifelse(values > 0, "#147D8C", "#E97132"),
    ylab = "DRIFT MSE - REVERSAL MSE (x 1e8)",
    main = "Frozen loss transport by year"
  )
  graphics::abline(h = 0, col = "#64748B", lwd = 2)
}

write_report <- function(train, development, coverage, source_checks, run_spec, paths) {
  stats <- train$statistics[1L, ]
  decision <- train$decision[1L, ]
  influence <- train$influence[1L, ]
  lines <- c(
    "# HYP-MR-01.1 QQQ Intraday-Shock Reversal Results", "",
    paste0("Status: `", run_spec$overall_status[[1L]], "`"), "",
    "## Question", "",
    "Does a completed QQQ open-to-close move, normalized by strictly prior ATR%, predict an opposite-signed next-session open-to-close return?", "",
    "## Frozen design", "",
    "- One asset: `QQQ`.",
    "- One predictor: completed intraday log return divided by prior-only ATR20%.",
    "- One target: next-session open-to-close log return.",
    "- One model: univariate OLS; one benchmark: intercept-only drift.",
    "- Three expanding one-year-ahead TRAIN folds; complete circular-shift timing null.", "",
    "## Source and construction", "",
    paste0("- Source gates: `", sum(source_checks$passed), " / ", nrow(source_checks), "` pass."),
    paste0("- Cached coverage: `", coverage$first_session[[1L]], "` through `", coverage$last_session[[1L]], "` (`", coverage$row_count[[1L]], "` sessions)."),
    paste0("- Valid TRAIN anchors: `", stats$anchor_count, "`."),
    paste0("- Data-health maximum severity: `", run_spec$train_health_max_severity[[1L]], "`; requested-window impact: `", run_spec$train_health_window_impact[[1L]], "`."), "",
    "## TRAIN readout", "",
    paste0("- Full-TRAIN beta: `", sprintf("%.8f", stats$beta), "`; Spearman: `", sprintf("%.6f", stats$spearman), "`."),
    paste0("- Pooled expanding-fold MSE improvement: `", sprintf("%.12g", decision$observed_oof_mse_improvement), "`; positive folds: `", decision$positive_fold_count, " / 3`."),
    paste0("- Complete shift-null p90: `", sprintf("%.12g", decision$shift_p90), "`; empirical upper-tail probability: `", sprintf("%.6f", decision$empirical_upper_tail_probability), "`."),
    paste0("- Removing the largest 1% by absolute predictor left beta `", sprintf("%.8f", influence$influence_excluded_beta), "` across `", influence$retained_rows, "` rows."),
    paste0("- TRAIN gates: `", sum(train$gates$passed), " / ", nrow(train$gates), "` pass; decision: `", decision$status, "`."), ""
  )
  if (is.null(development)) {
    lines <- c(lines, "## DEVELOPMENT boundary", "", "DEVELOPMENT was not queried or calculated because at least one frozen TRAIN gate failed.", "")
  } else {
    metrics <- development$metrics[1L, ]
    lines <- c(
      lines, "## DEVELOPMENT readout", "",
      paste0("- Rows: `", metrics$row_count, "`; Spearman: `", sprintf("%.6f", metrics$development_spearman), "`."),
      paste0("- Frozen loss improvement: `", sprintf("%.12g", metrics$mse_improvement), "`; bootstrap P(improvement > 0): `", sprintf("%.6f", development$bootstrap$probability_positive[[1L]]), "`."),
      paste0("- Gates: `", sum(development$gates$passed), " / ", nrow(development$gates), "` pass; decision: `", development$overall_status, "`."), ""
    )
  }
  lines <- c(
    lines, "## Interpretation", "",
    if (is.null(development)) {
      "The registered univariate reversal model did not clear its complete TRAIN gate. No DEVELOPMENT or confirmation evidence was consumed."
    } else if (all(development$gates$passed)) {
      "The frozen TRAIN model transported to DEVELOPMENT and now requires operator review before confirmation access."
    } else {
      "The frozen model failed at least one DEVELOPMENT gate. Stop without changing the feature, horizon, or model family."
    }, "",
    "This is forecast evidence only. No strategy or performance calculation was made.", "",
    "## Artifacts", "",
    paste0("- Relationship: `", basename(paths$relation_png), "`"),
    paste0("- Expanding folds: `", basename(paths$folds_png), "`"),
    paste0("- Timing control: `", basename(paths$shift_png), "`"),
    paste0("- Representative shocks: `", basename(paths$events_png), "`"),
    if (!is.null(development)) paste0("- DEVELOPMENT transport: `", basename(paths$development_png), "`") else NULL
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("HYP-MR-01.1 frozen TRAIN stage starting.")
contract <- g5_hmr011_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_HYP_MR_01_1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_HYP_MR_01_1_REFRESH", FALSE)
run_id <- env_or("GEN5_HYP_MR_01_1_RUN_ID", "hyp_mr_01_1_qqq_intraday_shock_reversal_20260822")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

train_query <- query_zone(cfg, contract, contract$train_end, "hyp_mr_01_1_train", refresh)
train_coverage <- coverage_table(train_query$bars, contract, contract$train_end)
source_checks <- source_audit(train_coverage, train_query$bars, contract, contract$train_end)
if (!all(source_checks$passed)) stop("HYP-MR-01.1 source feasibility audit failed.", call. = FALSE)
train <- g5_hmr011_run_train(train_query$bars, contract)

development <- NULL
development_query <- NULL
if (isTRUE(train$decision$passed[[1L]])) {
  message("TRAIN passed. HYP-MR-01.1 DEVELOPMENT query is now permitted.")
  development_query <- query_zone(cfg, contract, contract$development_end, "hyp_mr_01_1_development", refresh)
  development_bars <- development_query$bars
  train_bars <- development_bars[as.Date(development_bars$session_date) <= contract$train_end, , drop = FALSE]
  development <- g5_hmr011_run_development(train_bars, development_bars, contract)
}

overall_status <- if (is.null(development)) train$overall_status else development$overall_status
paths <- list(
  run_spec = file.path(output_dir, "hmr011_run_spec.csv"),
  contract = file.path(output_dir, "hmr011_frozen_contract.csv"),
  source = file.path(output_dir, "hmr011_source_audit.csv"),
  coverage = file.path(output_dir, "hmr011_train_coverage.csv"),
  integrity = file.path(output_dir, "hmr011_train_integrity.csv"),
  construction = file.path(output_dir, "hmr011_train_construction.csv"),
  statistics = file.path(output_dir, "hmr011_train_statistics.csv"),
  predictions = file.path(output_dir, "hmr011_train_expanding_predictions.csv"),
  folds = file.path(output_dir, "hmr011_train_fold_metrics.csv"),
  shift = file.path(output_dir, "hmr011_train_shift_null.csv"),
  influence = file.path(output_dir, "hmr011_train_influence_audit.csv"),
  deciles = file.path(output_dir, "hmr011_train_deciles.csv"),
  gates = file.path(output_dir, "hmr011_train_gates.csv"),
  decision = file.path(output_dir, "hmr011_train_decision.csv"),
  development_metrics = file.path(output_dir, "hmr011_development_metrics.csv"),
  development_years = file.path(output_dir, "hmr011_development_year_metrics.csv"),
  development_bootstrap = file.path(output_dir, "hmr011_development_bootstrap.csv"),
  development_gates = file.path(output_dir, "hmr011_development_gates.csv"),
  relation_png = file.path(visual_dir, "hmr011_train_relationship.png"),
  folds_png = file.path(visual_dir, "hmr011_train_fold_improvement.png"),
  shift_png = file.path(visual_dir, "hmr011_train_timing_control.png"),
  events_png = file.path(visual_dir, "hmr011_train_representative_shocks.png"),
  development_png = file.path(visual_dir, "hmr011_development_transport.png"),
  report = file.path(output_dir, "hmr011_report.md")
)

run_spec <- data.frame(
  schema_version = g5_hmr011_schema_version(),
  wrapper = "scripts/inspect/run_hyp_mr_01_1_qqq_intraday_shock_reversal.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  train_health_max_severity = health_severity(train_query$health),
  train_health_window_impact = "NONE_REQUESTED_RANGE_FULLY_COVERED",
  train_anchor_count = nrow(train$panel_bundle$panel),
  train_passed = train$decision$passed[[1L]],
  development_opened = !is.null(development),
  confirmation_opened = FALSE,
  strategy_outcomes_computed = FALSE,
  overall_status = overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$contract)
write_csv(source_checks, paths$source)
write_csv(train_coverage, paths$coverage)
write_csv(train$panel_bundle$integrity, paths$integrity)
write_csv(train$panel_bundle$construction_checks, paths$construction)
write_csv(train$statistics, paths$statistics)
write_csv(train$predictions, paths$predictions)
write_csv(train$folds, paths$folds)
write_csv(train$shift_distribution, paths$shift)
write_csv(train$influence, paths$influence)
write_csv(train$deciles, paths$deciles)
write_csv(train$gates, paths$gates)
write_csv(train$decision, paths$decision)
plot_relation(train$panel_bundle$panel, train$statistics, train$deciles, paths$relation_png)
plot_folds(train$folds, paths$folds_png)
plot_shift(train$shift_distribution, train$decision, paths$shift_png)
plot_events(train$panel_bundle$panel, paths$events_png)

if (is.null(development)) {
  writeLines("DEVELOPMENT was not queried or calculated because at least one frozen TRAIN gate failed.", file.path(output_dir, "DEVELOPMENT_NOT_READ.txt"))
} else {
  write_csv(development$metrics, paths$development_metrics)
  write_csv(development$year_metrics, paths$development_years)
  write_csv(development$bootstrap, paths$development_bootstrap)
  write_csv(development$gates, paths$development_gates)
  plot_development_transport(train, development, paths$development_png)
}
writeLines("2024-2025 confirmation was not queried or calculated in this slice.", file.path(output_dir, "CONFIRMATION_NOT_READ.txt"))
writeLines(overall_status, file.path(output_dir, "STATUS.txt"))
write_report(train, development, train_coverage, source_checks, run_spec, paths)
invisible(g5_write_workbench_query_artifacts(train_query, output_dir, "hmr011_train_query"))
if (!is.null(development_query)) invisible(g5_write_workbench_query_artifacts(development_query, output_dir, "hmr011_development_query"))

message("HYP-MR-01.1 complete: ", overall_status)
message("TRAIN data health: ", run_spec$train_health_max_severity)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report, winslash = "/", mustWork = FALSE))
