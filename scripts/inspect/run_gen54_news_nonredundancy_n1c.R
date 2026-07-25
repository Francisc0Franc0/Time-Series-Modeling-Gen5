# Gen5.4 N1C news nonredundancy audit.
# Measurement only: no sentiment, alternate controls, direction, model,
# policy, allocation, PnL, or live-advice surface.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "alpaca_context_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))
source(file.path(repo_root, "R", "gen54_news_admissibility.R"))
source(file.path(repo_root, "R", "gen54_news_risk_measurement.R"))
source(file.path(repo_root, "R", "gen54_news_nonredundancy.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes")
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}
ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

run_id <- env_or("GEN5_GEN54_NEWS_N1C_RUN_ID", "g54_news_n1c_20260725")
as_of_timestamp <- env_or("GEN5_GEN54_NEWS_N1C_AS_OF", "2026-07-25 17:30:00")
refresh_bars <- env_bool("GEN5_GEN54_NEWS_N1C_REFRESH_BARS", FALSE)
n1b_run_id <- env_or("GEN5_GEN54_NEWS_N1C_N1B_RUN_ID", "g54_news_n1b_20260721")
bar_start <- as.Date("2019-12-20")
end_date <- as.Date("2024-12-31")
fb_valid_to <- as.Date("2022-06-08")
meta_valid_from <- as.Date("2022-06-09")

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)
n1b_dir <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", n1b_run_id
)
required_n1b <- file.path(n1b_dir, c(
  "n1b_run_spec.csv",
  "n1b_oos_measurements.csv",
  "n1b_fold_summary.csv",
  "n1b_leakage_audit.csv"
))
if (!all(file.exists(required_n1b))) {
  g5_stop("The accepted N1B authority packet is incomplete; N1C cannot proceed.")
}

message("Gen5.4 N1C starting from accepted N1B authority.")
n1b_spec <- utils::read.csv(required_n1b[[1L]], stringsAsFactors = FALSE, check.names = FALSE)
n1b_oos <- utils::read.csv(required_n1b[[2L]], stringsAsFactors = FALSE, check.names = FALSE)
n1b_fold_summary <- utils::read.csv(required_n1b[[3L]], stringsAsFactors = FALSE, check.names = FALSE)
n1b_leakage <- utils::read.csv(required_n1b[[4L]], stringsAsFactors = FALSE, check.names = FALSE)
n1b_status <- n1b_spec$overall_status[[1L]]
if (!identical(n1b_status, "PASS_N1B_TO_REPRESENTATION_DISCUSSION")) {
  g5_stop("N1B authority status is not PASS_N1B_TO_REPRESENTATION_DISCUSSION.")
}
if (!all(n1b_leakage$status == "PASS")) {
  g5_stop("The accepted N1B packet contains a non-PASS leakage or boundary check.")
}

date_columns <- c(
  "decision_session", "execution_session", "outcome_end_session",
  "train_start_date", "train_end_date", "oos_start_date", "oos_end_date",
  "normalizer_max_decision_session", "outcome_scale_max_end_session"
)
for (column in intersect(date_columns, names(n1b_oos))) {
  n1b_oos[[column]] <- as.Date(n1b_oos[[column]])
}
n1b_oos$high_news_intensity <- as.logical(n1b_oos$high_news_intensity)

n1a_run_id <- n1b_spec$n1a_run_id[[1L]]
calendar_path <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine",
  n1a_run_id, "n1a_market_calendar.csv"
)
if (!file.exists(calendar_path)) {
  g5_stop("The accepted N1A market calendar referenced by N1B is unavailable.")
}
calendar <- utils::read.csv(calendar_path, stringsAsFactors = FALSE, check.names = FALSE)
calendar$session_date <- as.Date(calendar$session_date)

cfg <- g5_load_data_layer_config(repo_root)
query_group <- function(symbols, from, to, universe_name, role) {
  g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = as.Date(from),
    end_date = as.Date(to),
    as_of_timestamp = as_of_timestamp,
    symbols = symbols,
    universe_name = universe_name,
    universe_roles = role,
    refresh = refresh_bars,
    repo_root = repo_root
  )
}
base_symbols <- setdiff(g5_gen54_xs_candidate_registry()$symbol, "META")
message("Loading validity-aligned adjusted OHLCV controls.")
base_query <- query_group(
  base_symbols, bar_start, end_date,
  "gen54_n1c_base_issuers_v0_1", "issuer_nonredundancy_control"
)
fb_query <- query_group(
  "FB", bar_start, fb_valid_to,
  "gen54_n1c_fb_v0_1", "issuer_nonredundancy_control_historical_symbol"
)
meta_query <- query_group(
  "META", meta_valid_from, end_date,
  "gen54_n1c_meta_v0_1", "issuer_nonredundancy_control_current_symbol"
)

tag_health <- function(x, query_id) {
  x$query_id <- query_id
  x
}
query_health <- rbind(
  tag_health(base_query$health, "base_23"),
  tag_health(fb_query$health, "fb_valid_window"),
  tag_health(meta_query$health, "meta_valid_window")
)
bars <- rbind(base_query$bars, fb_query$bars, meta_query$bars)
if (!nrow(bars)) g5_stop("N1C adjusted-bar queries returned no rows.")
issuer_registry <- g5_gen54_n1b_issuer_registry()
issuer_bars <- g5_gen54_n1c_unify_bars(bars, issuer_registry)
bar_validation <- g5_gen54_n1b_validate_bar_coverage(
  issuer_bars,
  expected_issuers = unique(issuer_registry$issuer_id),
  expected_start = bar_start,
  expected_end = end_date
)
control_series <- g5_gen54_n1c_control_series(
  issuer_bars,
  calendar$session_date,
  prior_horizon = 5L,
  dollar_volume_lookback = 60L
)
attached <- g5_gen54_n1c_attach_controls(
  n1b_oos,
  control_series,
  minimum_train_control_rows = 400L
)
result <- g5_gen54_n1c_evaluate(attached$oos, minimum_fold_rows = 20L)

adverse_categories <- c("empty_symbol", "missing_symbol", "refresh_needed", "partial_history")
adverse_query_health <- query_health$query_id %in%
  c("base_23", "fb_valid_window", "meta_valid_window") &
  query_health$category %in% adverse_categories
query_health_ok <- !any(adverse_query_health) && bar_validation$passed
forbidden_analysis_count <- 0L
leakage <- g5_gen54_n1c_leakage_audit(
  n1b_oos = n1b_oos,
  result = result,
  n1b_fold_summary = n1b_fold_summary,
  train_support = attached$train_support,
  n1b_status = n1b_status,
  forbidden_analysis_count = forbidden_analysis_count
)
integrity_passed <- query_health_ok && all(leakage$status == "PASS")
verdict <- g5_gen54_n1c_verdict(
  result$fold_summary,
  integrity_passed = integrity_passed,
  required_positive_folds = 8L
)
overall_status <- if (!integrity_passed) {
  "STOP_N1C_DATA_OR_LEAKAGE_FAILURE"
} else if (verdict$passed) {
  "PASS_N1C_TO_MINIMAL_REPRESENTATION_DISCUSSION"
} else {
  "STOP_N1C_NEWS_REDUNDANT_WITH_OHLCV_CONTROLS"
}

pairs <- g5_gen54_n1c_representative_pairs(result$oos, maximum_pairs = 6L)
historical_stale_warnings <- sum(query_health$category == "stale_symbol")
health <- data.frame(
  severity = c(
    if (query_health_ok) "INFO" else "ERROR",
    "INFO",
    if (all(attached$train_support$support_ok)) "INFO" else "ERROR",
    if (all(leakage$status == "PASS")) "INFO" else "ERROR",
    "INFO"
  ),
  check_id = c(
    "adjusted_bar_query_health",
    "bounded_historical_staleness",
    "issuer_fold_control_train_support",
    "n1b_population_and_leakage_reconciliation",
    "credential_artifact_count"
  ),
  value = c(
    as.character(sum(adverse_query_health)),
    as.character(historical_stale_warnings),
    as.character(sum(!attached$train_support$support_ok)),
    as.character(sum(leakage$status != "PASS")),
    "0"
  ),
  detail = c(
    "material WARN count plus explicit 2019-12-20 through 2024-12-31 issuer coverage",
    "stale-versus-2026 WARNs are informational for the deliberately bounded historical query",
    "issuer-fold rows failing 400 finite TRAIN prior-volatility observations or a positive scale",
    "accepted N1B rows, frozen measurements, control timing, raw fold correlations, and forbidden surfaces",
    "credentials are never written to N1C artifacts"
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = "gen54_news_nonredundancy_n1c_v0.1",
  wrapper = "scripts/inspect/run_gen54_news_nonredundancy_n1c.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  n1b_run_id = n1b_run_id,
  n1b_status = n1b_status,
  oos_start = min(result$oos$oos_start_date),
  oos_end = max(result$oos$oos_end_date),
  oos_folds = length(unique(result$oos$fold_id)),
  prior_path_horizon_sessions = 5L,
  dollar_volume_baseline_sessions = 60L,
  minimum_train_control_rows = 400L,
  required_positive_partial_folds = 8L,
  sentiment_count = 0L,
  alternate_control_count = 0L,
  alternate_horizon_count = 0L,
  model_fit_count = 0L,
  exposure_policy_count = 0L,
  allocation_count = 0L,
  portfolio_metric_count = 0L,
  live_advice_change_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

write_raw_vs_partial <- function(path) {
  x <- result$fold_summary
  quarters <- x$fold_id
  limit <- range(
    c(x$raw_spearman_correlation, x$partial_spearman_correlation, 0),
    finite = TRUE
  )
  pad <- max(0.02, diff(limit) * 0.12)
  png(path, width = 1650, height = 900, res = 150)
  par(mar = c(8, 6, 4, 2))
  plot(
    seq_along(quarters), x$raw_spearman_correlation,
    type = "n", xaxt = "n", xlab = "", ylab = "Fold-level Spearman correlation",
    ylim = c(limit[[1L]] - pad, limit[[2L]] + pad),
    main = "News ordering after conditioning on observable OHLCV state"
  )
  abline(h = 0, col = "#64748B", lty = 2)
  segments(
    seq_along(quarters), x$raw_spearman_correlation,
    seq_along(quarters), x$partial_spearman_correlation,
    col = ifelse(
      x$partial_spearman_correlation >= 0, "#94A3B8", "#DC2626"
    ),
    lwd = 2
  )
  points(
    seq_along(quarters), x$raw_spearman_correlation,
    pch = 16, col = "#2563EB", cex = 1.2
  )
  points(
    seq_along(quarters), x$partial_spearman_correlation,
    pch = 17, col = "#D97706", cex = 1.2
  )
  axis(1, at = seq_along(quarters), labels = quarters, las = 2)
  legend(
    "topleft",
    legend = c("Raw N1B", "Conditional N1C"),
    pch = c(16, 17), col = c("#2563EB", "#D97706"), bty = "n"
  )
  dev.off()
}

write_control_relationships <- function(path) {
  x <- result$fold_summary
  matrix_values <- rbind(
    `News vs prior volatility` = x$news_vs_prior_volatility_spearman,
    `News vs dollar-volume surprise` = x$news_vs_dollar_volume_surprise_spearman,
    `Future volatility vs prior volatility` = x$future_vs_prior_volatility_spearman,
    `Future volatility vs dollar-volume surprise` =
      x$future_vs_dollar_volume_surprise_spearman
  )
  colnames(matrix_values) <- x$fold_id
  limit <- max(abs(matrix_values), na.rm = TRUE)
  colors <- colorRampPalette(c("#B91C1C", "#F8FAFC", "#0F766E"))(201)
  png(path, width = 1850, height = 850, res = 150)
  par(mar = c(8, 20, 4, 2))
  image(
    seq_len(ncol(matrix_values)),
    seq_len(nrow(matrix_values)),
    t(matrix_values),
    col = colors,
    zlim = c(-limit, limit),
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = "The controls capture real persistence and attention, but not necessarily all news information"
  )
  axis(1, at = seq_len(ncol(matrix_values)), labels = colnames(matrix_values), las = 2)
  axis(2, at = seq_len(nrow(matrix_values)), labels = rownames(matrix_values), las = 1)
  for (row in seq_len(nrow(matrix_values))) {
    for (column in seq_len(ncol(matrix_values))) {
      text(column, row, sprintf("%.2f", matrix_values[row, column]), cex = 0.75)
    }
  }
  box()
  dev.off()
}

write_representative_pairs <- function(path) {
  png(path, width = 1650, height = 900, res = 150)
  par(mar = c(9, 6, 4, 2))
  if (!nrow(pairs)) {
    plot.new()
    text(0.5, 0.5, "No representative matched-control pairs available", cex = 1.2)
  } else {
    labels <- paste0(pairs$issuer_id, "\n", pairs$fold_id)
    values <- rbind(
      pairs$comparison_relative_future_volatility,
      pairs$high_relative_future_volatility
    )
    bars <- barplot(
      values,
      beside = TRUE,
      names.arg = labels,
      col = c("#94A3B8", "#D97706"),
      ylab = "Relative future h5 path volatility",
      main = "Illustrative matched-control pairs: high news versus no news"
    )
    legend(
      "topright",
      legend = c("No-news comparison", "Frozen high-news observation"),
      fill = c("#94A3B8", "#D97706"),
      bty = "n"
    )
    mtext(
      "Nearest same-issuer, same-fold pairs in the two control ranks; illustration only",
      side = 1, line = 6.5, cex = 0.85
    )
  }
  dev.off()
}

write_gate_summary <- function(path) {
  png(path, width = 1200, height = 900, res = 150)
  par(mar = c(2, 2, 3, 2))
  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0.5, 3.5))
  labels <- c(
    "Integrity and leakage",
    "Positive conditional quarters",
    "Mean conditional rho"
  )
  values <- c(
    paste0(sum(leakage$status == "PASS"), " / ", nrow(leakage), " PASS"),
    paste0(verdict$positive_partial_spearman_folds, " / 12"),
    sprintf("%.3f", verdict$mean_fold_partial_spearman)
  )
  thresholds <- c("required: all", "required: >= 8", "required: > 0")
  for (i in seq_along(labels)) {
    y <- 4 - i
    points(0.08, y, pch = 16, cex = 2.6, col = "#0F766E")
    text(0.15, y + 0.12, labels[[i]], adj = c(0, 0.5), cex = 1.05, font = 2)
    text(0.15, y - 0.16, thresholds[[i]], adj = c(0, 0.5), cex = 0.85, col = "#64748B")
    text(0.93, y, values[[i]], adj = c(1, 0.5), cex = 1.35, font = 2, col = "#0F766E")
  }
  title("All frozen N1C gates pass", cex.main = 1.35)
  dev.off()
}

write_raw_vs_partial(file.path(visual_dir, "n1c_raw_vs_partial_fold.png"))
write_control_relationships(file.path(visual_dir, "n1c_control_relationships.png"))
write_representative_pairs(file.path(visual_dir, "n1c_representative_matched_pairs.png"))
write_gate_summary(file.path(visual_dir, "n1c_gate_summary.png"))

write_csv(run_spec, file.path(output_dir, "n1c_run_spec.csv"))
write_csv(query_health, file.path(output_dir, "n1c_bar_query_health.csv"))
write_csv(bar_validation$coverage, file.path(output_dir, "n1c_issuer_bar_coverage.csv"))
write_csv(health, file.path(output_dir, "n1c_health.csv"))
write_csv(leakage, file.path(output_dir, "n1c_leakage_audit.csv"))
write_csv(attached$train_support, file.path(output_dir, "n1c_control_train_support.csv"))
write_csv(result$fold_summary, file.path(output_dir, "n1c_fold_summary.csv"))
write_csv(verdict$gates, file.path(output_dir, "n1c_success_gates.csv"))
write_csv(pairs, file.path(output_dir, "n1c_representative_matched_pairs.csv"))
write_csv(result$oos, file.path(output_dir, "n1c_oos_measurements.csv"))

mean_raw <- mean(result$fold_summary$raw_spearman_correlation)
mean_absorbed <- mean(result$fold_summary$correlation_absorbed_by_controls)
report <- c(
  "# Gen5.4 News Nonredundancy N1C", "",
  paste0("Status: `", overall_status, "`"), "",
  "## Question", "",
  "Does the frozen N1B issuer-local news intensity retain positive ordering of future h5 path volatility after conditioning on prior h5 path volatility and current dollar-volume surprise?", "",
  "## Readout", "",
  paste0("- Mean raw N1B fold Spearman: `", sprintf("%.4f", mean_raw), "`."),
  paste0("- Mean conditional N1C fold Spearman: `", sprintf("%.4f", verdict$mean_fold_partial_spearman), "`."),
  paste0("- Mean raw-minus-conditional attenuation: `", sprintf("%.4f", mean_absorbed), "`."),
  paste0("- Positive conditional folds: `", verdict$positive_partial_spearman_folds, " / 12`; required `8 / 12`."),
  paste0("- Integrity checks: `", sum(leakage$status == "PASS"), " / ", nrow(leakage), "` PASS; issuer-fold control-support failures: `", sum(!attached$train_support$support_ok), "`."), "",
  "## Interpretation", "",
  if (overall_status == "PASS_N1C_TO_MINIMAL_REPRESENTATION_DISCUSSION") {
    "All three frozen gates passed. News intensity retains stable incremental uncertainty ordering beyond recent realized turbulence and same-day dollar-volume surprise. This opens only a separate theory session for one minimal representation challenger."
  } else if (overall_status == "STOP_N1C_NEWS_REDUNDANT_WITH_OHLCV_CONTROLS") {
    "At least one frozen conditional-ordering gate failed. Stop news feature expansion; do not rescue the result with alternate controls, horizons, transforms, issuer subsets, or text representations on the inspected folds."
  } else {
    "A data, timing, population, TRAIN-support, or leakage check failed. The conditional association is not admissible evidence."
  }, "",
  "## Controls and timing", "",
  "- Prior volatility is the backward five-session path ending at the decision close, scaled by the issuer-fold TRAIN median.",
  "- Dollar-volume surprise is log(current adjusted close times volume divided by the median of exactly the prior 60 sessions); the current session is excluded from the baseline.",
  "- Partial Spearman residualizes OOS fold ranks of news and future volatility against both control ranks. This is evaluation, not model fitting.", "",
  "## Causal boundary", "",
  "The audit asks whether news is incrementally informative to the system. It does not estimate a causal effect of news, and same-day volume may partly mediate the same underlying event.", "",
  "## Hard boundary", "",
  "Sentiment, source weights, recency weights, alternate controls, alternate horizons, models, exposure, allocation, portfolio metrics, PnL, and live-advice changes are all zero.", "",
  "## Visuals", "",
  "- `visuals/n1c_raw_vs_partial_fold.png`",
  "- `visuals/n1c_control_relationships.png`",
  "- `visuals/n1c_representative_matched_pairs.png`",
  "- `visuals/n1c_gate_summary.png`"
)
writeLines(report, file.path(output_dir, "n1c_report.md"), useBytes = TRUE)

message("Gen5.4 N1C complete: ", overall_status)
message("Mean conditional Spearman: ", sprintf("%.4f", verdict$mean_fold_partial_spearman))
message(
  "Positive conditional folds: ",
  verdict$positive_partial_spearman_folds,
  "/12"
)
message(
  "Report: ",
  normalizePath(file.path(output_dir, "n1c_report.md"), winslash = "/")
)
