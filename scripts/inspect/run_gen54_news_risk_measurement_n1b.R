# Gen5.4 N1B issuer-relative news intensity versus future path volatility.
# Measurement only: no sentiment, direction, policy, allocation, PnL, or model.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
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
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes")
write_csv <- function(x, path) { utils::write.csv(x, path, row.names = FALSE, na = ""); invisible(path) }
ensure_dir <- function(path) { dir.create(path, recursive = TRUE, showWarnings = FALSE); invisible(path) }
quarter_id <- function(x) paste0(format(as.Date(x), "%Y"), "Q", (as.integer(format(as.Date(x), "%m")) - 1L) %/% 3L + 1L)

run_id <- env_or("GEN5_GEN54_NEWS_N1B_RUN_ID", "g54_news_n1b_20260721")
as_of_timestamp <- env_or("GEN5_GEN54_NEWS_N1B_AS_OF", "2026-07-21 17:30:00")
retrieved_at <- env_or("GEN5_GEN54_NEWS_N1B_RETRIEVED_AT", as_of_timestamp)
refresh_bars <- env_bool("GEN5_GEN54_NEWS_N1B_REFRESH_BARS", FALSE)
reuse_fb_raw <- env_bool("GEN5_GEN54_NEWS_N1B_REUSE_FB_RAW", FALSE)
request_pause_seconds <- as.numeric(env_or("GEN5_GEN54_NEWS_N1B_REQUEST_PAUSE", "0.25"))
n1a_run_id <- env_or("GEN5_GEN54_NEWS_N1B_N1A_RUN_ID", "g54_news_n1a_20260721")
start_date <- as.Date("2020-01-01")
end_date <- as.Date("2024-12-31")
bar_start <- as.Date("2019-12-20")
fb_valid_to <- as.Date("2022-06-08")
meta_valid_from <- as.Date("2022-06-09")

output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id)
raw_dir <- file.path(output_dir, "raw")
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(raw_dir)
ensure_dir(visual_dir)
n1a_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", n1a_run_id)
required_n1a <- file.path(n1a_dir, c("n1a_article_admissibility.csv", "n1a_market_calendar.csv", "n1a_run_spec.csv"))
if (!all(file.exists(required_n1a))) g5_stop("The accepted N1A packet is incomplete; N1B cannot proceed.")

message("Gen5.4 N1B starting from accepted N1A archive evidence.")
n1a_articles_enriched <- utils::read.csv(required_n1a[[1L]], stringsAsFactors = FALSE, check.names = FALSE)
calendar <- utils::read.csv(required_n1a[[2L]], stringsAsFactors = FALSE, check.names = FALSE)
n1a_spec <- utils::read.csv(required_n1a[[3L]], stringsAsFactors = FALSE, check.names = FALSE)
if (!identical(n1a_spec$overall_status[[1L]], "PASS_N1A_ADMISSIBLE_FOR_N1B_DISCUSSION")) {
  g5_stop("N1A authority status is not PASS_N1A_ADMISSIBLE_FOR_N1B_DISCUSSION.")
}
calendar$session_date <- as.Date(calendar$session_date)
canonical_news_columns <- names(g5_alpaca_empty_news())
if (!all(canonical_news_columns %in% names(n1a_articles_enriched))) g5_stop("N1A article table lacks canonical Alpaca news columns.")
n1a_articles <- n1a_articles_enriched[, canonical_news_columns, drop = FALSE]

fb_request <- g5_alpaca_news_request(
  symbols = "FB",
  start_timestamp = "2020-01-01T00:00:00Z",
  end_timestamp = "2022-06-08T23:59:59Z",
  as_of_timestamp = as_of_timestamp,
  include_content = FALSE,
  limit = 50L
)
if (reuse_fb_raw) {
  raw_files <- sort(list.files(raw_dir, pattern = "^fb_news_page_[0-9]{4}\\.json$", full.names = TRUE))
  if (!length(raw_files)) g5_stop("FB raw reuse requested but no preserved FB pages exist.")
  fb_pages <- vector("list", length(raw_files))
  fb_frames <- vector("list", length(raw_files))
  for (i in seq_along(raw_files)) {
    response_text <- paste(readLines(raw_files[[i]], warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
    next_token <- parsed$next_page_token
    next_token <- if (is.null(next_token) || !nzchar(as.character(next_token))) "" else as.character(next_token)
    fb_pages[[i]] <- list(
      page_number = i, http_status = 200L,
      page_token_in = if (i == 1L) "" else "reused_prior_page_token",
      next_page_token = next_token,
      response_bytes = nchar(response_text, type = "bytes"), response_text = response_text
    )
    fb_frames[[i]] <- g5_alpaca_map_news_payload(parsed, fb_request, retrieved_at)
  }
  if (nzchar(tail(fb_pages, 1L)[[1L]]$next_page_token)) g5_stop("Preserved FB page chain is not exhausted.")
  keep_frames <- fb_frames[vapply(fb_frames, nrow, integer(1L)) > 0L]
  fb_articles <- if (length(keep_frames)) do.call(rbind, keep_frames) else g5_alpaca_empty_news()
  fb_result <- list(data = fb_articles, pages = fb_pages)
  message("Rebuilt FB archive lane from preserved raw pages.")
} else {
  message("Retrieving the frozen historical FB news lane.")
  fb_result <- g5_fetch_alpaca_news(fb_request, retrieved_at = retrieved_at, request_pause_seconds = request_pause_seconds)
  for (page in fb_result$pages) {
    writeLines(page$response_text, file.path(raw_dir, sprintf("fb_news_page_%04d.json", page$page_number)), useBytes = TRUE)
  }
}
fb_page_manifest <- do.call(rbind, lapply(fb_result$pages, function(page) data.frame(
  page_number = page$page_number,
  http_status = page$http_status,
  next_page_token_present = nzchar(page$next_page_token),
  response_bytes = page$response_bytes,
  raw_file = file.path("raw", sprintf("fb_news_page_%04d.json", page$page_number)),
  stringsAsFactors = FALSE
)))
if (!nrow(fb_result$data)) g5_stop("The historical FB news lane returned no articles.")

combined_articles <- g5_gen54_n1b_combine_articles(n1a_articles, fb_result$data)
issuer_registry <- g5_gen54_n1b_issuer_registry()
news <- g5_gen54_n1b_build_news_panel(
  combined_articles,
  calendar$session_date,
  issuer_registry = issuer_registry,
  start_date = start_date,
  end_date = end_date
)
message("Issuer/session news panel built: ", nrow(news$panel), " rows.")

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
message("Querying validity-aligned adjusted bars.")
base_query <- query_group(base_symbols, bar_start, end_date, "gen54_n1b_base_issuers_v0_1", "issuer_risk_measurement")
fb_query <- query_group("FB", bar_start, fb_valid_to, "gen54_n1b_fb_v0_1", "issuer_risk_measurement_historical_symbol")
meta_query <- query_group("META", meta_valid_from, end_date, "gen54_n1b_meta_v0_1", "issuer_risk_measurement_current_symbol")

tag_health <- function(x, query_id) { x$query_id <- query_id; x }
query_health <- rbind(
  tag_health(base_query$health, "base_23"),
  tag_health(fb_query$health, "fb_valid_window"),
  tag_health(meta_query$health, "meta_valid_window")
)
bars <- rbind(base_query$bars, fb_query$bars, meta_query$bars)
if (!nrow(bars)) g5_stop("N1B adjusted-bar queries returned no rows.")
issuer_bars <- g5_gen54_n1b_unify_bars(bars, issuer_registry)
bar_validation <- g5_gen54_n1b_validate_bar_coverage(
  issuer_bars,
  expected_issuers = unique(issuer_registry$issuer_id),
  expected_start = bar_start,
  expected_end = end_date
)
bar_coverage <- bar_validation$coverage
panel <- g5_gen54_n1b_attach_h5_path_volatility(news$panel, issuer_bars, calendar$session_date)
folds <- g5_gen54_xs_build_folds(2022:2024)
result <- g5_gen54_n1b_evaluate(panel, folds, minimum_train_rows = 400L, minimum_nonzero_train_cycles = 20L, high_percentile = 0.80)
leakage <- g5_gen54_n1b_leakage_audit(result, news$associations, n1l_passed = TRUE)
verdict <- g5_gen54_n1b_verdict(result$fold_summary, required_positive_folds = 8L)

adverse_categories <- c("empty_symbol", "missing_symbol", "refresh_needed", "partial_history")
adverse_query_health <- query_health$query_id %in% c("base_23", "fb_valid_window", "meta_valid_window") &
  query_health$category %in% adverse_categories
historical_stale_warnings <- sum(query_health$category == "stale_symbol")
query_health_ok <- !any(adverse_query_health) && bar_validation$passed
data_and_leakage_ok <- query_health_ok && all(leakage$status == "PASS")
overall_status <- if (!data_and_leakage_ok) {
  "STOP_N1B_DATA_OR_LEAKAGE_FAILURE"
} else if (verdict$passed) {
  "PASS_N1B_TO_REPRESENTATION_DISCUSSION"
} else {
  "STOP_N1B_ASSOCIATION_NOT_STABLE"
}

event_coverage <- news$admissible_associations
if (nrow(event_coverage)) {
  event_coverage$quarter <- quarter_id(event_coverage$decision_session)
  event_coverage <- aggregate(
    event_coverage$exact_title_cluster_id,
    list(issuer_id = event_coverage$issuer_id, quarter = event_coverage$quarter),
    function(x) length(unique(x))
  )
  names(event_coverage)[[3L]] <- "novel_cluster_count"
} else {
  event_coverage <- data.frame(
    issuer_id = character(),
    quarter = character(),
    novel_cluster_count = integer(),
    stringsAsFactors = FALSE
  )
}
coverage_grid <- expand.grid(issuer_id = unique(issuer_registry$issuer_id), quarter = paste0(rep(2020:2024, each = 4), "Q", 1:4), stringsAsFactors = FALSE)
event_coverage <- merge(coverage_grid, event_coverage, by = c("issuer_id", "quarter"), all.x = TRUE, sort = TRUE)
event_coverage$novel_cluster_count[is.na(event_coverage$novel_cluster_count)] <- 0L

calibration_rows <- list()
calibration_index <- 1L
for (i in seq_len(nrow(folds))) {
  fold <- folds[i, , drop = FALSE]
  for (issuer in unique(panel$issuer_id)) {
    train <- panel[panel$issuer_id == issuer & panel$decision_session >= fold$train_start_date & panel$decision_session <= fold$train_end_date &
      !is.na(panel$outcome_end_session) & panel$outcome_end_session <= fold$train_end_date & is.finite(panel$future_path_volatility_h5), , drop = FALSE]
    if (!nrow(train)) next
    quantiles <- stats::quantile(train$news_log1p, probs = c(0.5, 0.8, 0.9), names = FALSE, type = 1)
    calibration_rows[[calibration_index]] <- data.frame(
      fold_id = fold$fold_id,
      issuer_id = issuer,
      train_rows = nrow(train),
      train_zero_share = mean(train$novel_cluster_count == 0),
      train_log_count_p50 = quantiles[[1L]],
      train_log_count_p80 = quantiles[[2L]],
      train_log_count_p90 = quantiles[[3L]],
      train_count_p80 = expm1(quantiles[[2L]]),
      stringsAsFactors = FALSE
    )
    calibration_index <- calibration_index + 1L
  }
}
calibration <- do.call(rbind, calibration_rows)

oos <- result$oos
high_rows <- oos[oos$high_news_intensity & is.finite(oos$relative_future_path_volatility_h5), , drop = FALSE]
high_concentration <- if (nrow(high_rows)) {
  x <- aggregate(rep(1L, nrow(high_rows)), list(issuer_id = high_rows$issuer_id), sum)
  names(x)[[2L]] <- "high_intensity_observations"
  x$share <- x$high_intensity_observations / sum(x$high_intensity_observations)
  x[order(-x$high_intensity_observations, x$issuer_id), , drop = FALSE]
} else data.frame(issuer_id = character(), high_intensity_observations = integer(), share = numeric(), stringsAsFactors = FALSE)

representative_issuers <- head(high_concentration$issuer_id, 4L)
representative_tape <- oos[oos$issuer_id %in% representative_issuers & is.finite(oos$relative_future_path_volatility_h5), c(
  "fold_id", "issuer_id", "decision_session", "execution_session", "outcome_end_session",
  "novel_cluster_count", "news_intensity_percentile", "high_news_intensity",
  "future_path_volatility_h5", "relative_future_path_volatility_h5"
), drop = FALSE]

health <- data.frame(
  severity = c(if (query_health_ok) "INFO" else "ERROR", "INFO", if (all(result$train_support$support_ok)) "INFO" else "ERROR", "INFO", "INFO", "INFO"),
  check_id = c("adjusted_bar_query_health", "bounded_historical_staleness", "issuer_fold_train_support", "fb_archive_articles", "admissible_novel_associations", "credential_artifact_count"),
  value = c(as.character(sum(adverse_query_health)), as.character(historical_stale_warnings), as.character(sum(!result$train_support$support_ok)), as.character(nrow(fb_result$data)), as.character(nrow(news$admissible_associations)), "0"),
  detail = c(
    "material WARN count after rerun plus explicit 2019-12-20 through 2024-12-31 issuer coverage",
    "stale-versus-2026 WARNs are expected for deliberately bounded historical queries and do not affect the requested window",
    "issuer-fold rows failing 400 complete rows or 20 nonzero TRAIN cycles",
    "historical FB lane added before issuer mapping",
    "24-hour staleness and 72-hour repeat rules applied",
    "credentials are never written to N1B artifacts"
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = "gen54_news_risk_measurement_n1b_v0.1",
  wrapper = "scripts/inspect/run_gen54_news_risk_measurement_n1b.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  n1a_run_id = n1a_run_id,
  archive_start = start_date,
  archive_end = end_date,
  train_quarters = 8L,
  oos_folds = 12L,
  high_percentile = 0.80,
  maximum_update_delay_hours = 24,
  repeat_window_hours = 72,
  minimum_train_rows = 400L,
  minimum_nonzero_train_cycles = 20L,
  sentiment_count = 0L,
  directional_target_count = 0L,
  model_fit_count = 0L,
  exposure_policy_count = 0L,
  allocation_count = 0L,
  portfolio_metric_count = 0L,
  live_advice_change_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

write_fold_stability <- function(path) {
  png(path, width = 1500, height = 900, res = 150)
  par(mfrow = c(2, 1), mar = c(4, 5, 3, 2))
  colors <- ifelse(result$fold_summary$spearman_correlation > 0, "#0F766E", "#B91C1C")
  barplot(result$fold_summary$spearman_correlation, names.arg = result$fold_summary$fold_id, col = colors, ylab = "Spearman correlation", main = "News intensity must order relative h5 path volatility across quarters")
  abline(h = 0, col = "#475569")
  colors <- ifelse(result$fold_summary$high_minus_other_relative_volatility > 0, "#2563EB", "#D97706")
  barplot(result$fold_summary$high_minus_other_relative_volatility, names.arg = result$fold_summary$fold_id, col = colors, ylab = "High minus other relative volatility", main = "High-intensity cycles should have wider future paths")
  abline(h = 0, col = "#475569")
  dev.off()
}

write_coverage_heatmap <- function(path) {
  issuers <- unique(issuer_registry$issuer_id)
  quarters <- paste0(rep(2020:2024, each = 4), "Q", 1:4)
  values <- matrix(0, nrow = length(issuers), ncol = length(quarters), dimnames = list(issuers, quarters))
  for (i in seq_len(nrow(event_coverage))) values[event_coverage$issuer_id[[i]], event_coverage$quarter[[i]]] <- event_coverage$novel_cluster_count[[i]]
  png(path, width = 1800, height = 1100, res = 150)
  par(mar = c(8, 13, 4, 7))
  image(seq_along(quarters), seq_along(issuers), t(values), col = hcl.colors(100, "Blues 3"), axes = FALSE, xlab = "", ylab = "", main = "Novel-news coverage is uneven but measured issuer by issuer")
  axis(1, at = seq_along(quarters), labels = quarters, las = 2)
  axis(2, at = seq_along(issuers), labels = issuers, las = 1)
  box()
  dev.off()
}

write_calibration <- function(path) {
  selected <- intersect(c("AAPL", "CAT", "KO", "TSLA"), unique(calibration$issuer_id))
  x <- calibration[calibration$fold_id == "2024Q4" & calibration$issuer_id %in% selected, , drop = FALSE]
  x <- x[match(selected, x$issuer_id), , drop = FALSE]
  png(path, width = 1500, height = 950, res = 150)
  par(mfrow = c(2, 1), mar = c(3, 8, 3, 2), oma = c(5, 0, 3, 0))
  zero_percent <- 100 * x$train_zero_share
  zero_bars <- barplot(zero_percent, names.arg = rep("", nrow(x)), col = "#64748B", ylab = "Zero-news TRAIN cycles (%)", ylim = c(0, max(10, 1.18 * max(zero_percent))))
  text(zero_bars, zero_percent, labels = sprintf("%.1f%%", zero_percent), pos = 3, cex = 0.85)
  count_bars <- barplot(x$train_count_p80, names.arg = x$issuer_id, col = "#2563EB", ylab = "Novel clusters at TRAIN p80", ylim = c(0, 1.18 * max(x$train_count_p80)))
  text(count_bars, x$train_count_p80, labels = sprintf("%d", round(x$train_count_p80)), pos = 3, cex = 0.85)
  mtext("Frozen 2024Q4 calibration is issuer-local, not one pooled raw-count rule", outer = TRUE, side = 3, line = 1, cex = 1.25, font = 2)
  dev.off()
}

write_event_tapes <- function(path) {
  png(path, width = 1800, height = 1100, res = 150)
  par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  if (!length(representative_issuers)) {
    plot.new()
    text(0.5, 0.5, "No high-intensity OOS observations", cex = 1.2)
  }
  for (issuer in representative_issuers) {
    part <- representative_tape[representative_tape$issuer_id == issuer, , drop = FALSE]
    plot(part$decision_session, part$relative_future_path_volatility_h5, type = "l", col = "#475569", lwd = 1, xlab = "Decision session", ylab = "Relative h5 path volatility", main = issuer)
    high <- part$high_news_intensity
    points(part$decision_session[high], part$relative_future_path_volatility_h5[high], pch = 19, col = "#D97706", cex = 0.8 + part$news_intensity_percentile[high])
    abline(h = 1, lty = 2, col = "#94A3B8")
  }
  dev.off()
}

write_concentration <- function(path) {
  png(path, width = 1500, height = 850, res = 150)
  par(mar = c(9, 6, 4, 2))
  if (nrow(high_concentration)) {
    barplot(high_concentration$share, names.arg = high_concentration$issuer_id, las = 2, col = "#0F766E", ylab = "Share of high-intensity OOS observations", main = "High-intensity evidence concentration remains visible")
  } else {
    plot.new()
    text(0.5, 0.5, "No high-intensity OOS observations", cex = 1.2)
  }
  dev.off()
}

write_fold_stability(file.path(visual_dir, "n1b_fold_stability.png"))
write_coverage_heatmap(file.path(visual_dir, "n1b_issuer_quarter_coverage.png"))
write_calibration(file.path(visual_dir, "n1b_train_calibration_examples.png"))
write_event_tapes(file.path(visual_dir, "n1b_representative_event_tapes.png"))
write_concentration(file.path(visual_dir, "n1b_high_intensity_concentration.png"))

write_csv(run_spec, file.path(output_dir, "n1b_run_spec.csv"))
write_csv(folds, file.path(output_dir, "n1b_fold_manifest.csv"))
write_csv(issuer_registry, file.path(output_dir, "n1b_issuer_registry.csv"))
write_csv(fb_request, file.path(output_dir, "n1b_fb_news_request.csv"))
write_csv(fb_page_manifest, file.path(output_dir, "n1b_fb_page_manifest.csv"))
write_csv(query_health, file.path(output_dir, "n1b_bar_query_health.csv"))
write_csv(bar_coverage, file.path(output_dir, "n1b_issuer_bar_coverage.csv"))
write_csv(health, file.path(output_dir, "n1b_health.csv"))
write_csv(leakage, file.path(output_dir, "n1b_leakage_audit.csv"))
write_csv(result$train_support, file.path(output_dir, "n1b_train_support.csv"))
write_csv(event_coverage, file.path(output_dir, "n1b_issuer_quarter_event_coverage.csv"))
write_csv(calibration, file.path(output_dir, "n1b_train_calibration.csv"))
write_csv(result$fold_summary, file.path(output_dir, "n1b_fold_summary.csv"))
write_csv(verdict$gates, file.path(output_dir, "n1b_success_gates.csv"))
write_csv(high_concentration, file.path(output_dir, "n1b_high_intensity_concentration.csv"))
write_csv(representative_tape, file.path(output_dir, "n1b_representative_event_tape.csv"))
write_csv(oos, file.path(output_dir, "n1b_oos_measurements.csv"))

report <- c(
  "# Gen5.4 News Risk Measurement N1B", "",
  paste0("Status: `", overall_status, "`"), "",
  "## Question", "",
  "Does unusually high issuer-local novel-news activity order unusually high five-session realized path volatility beginning at the next executable open?", "",
  "## Readout", "",
  paste0("- Mean fold-level Spearman correlation: `", sprintf("%.4f", verdict$mean_fold_spearman), "`."),
  paste0("- Positive-correlation folds: `", verdict$positive_correlation_folds, " / 12`; required `8 / 12`."),
  paste0("- Positive high-versus-other folds: `", verdict$positive_separation_folds, " / 12`; required `8 / 12`."),
  paste0("- High-intensity OOS observations: `", nrow(high_rows), "`; issuer-fold TRAIN support failures: `", sum(!result$train_support$support_ok), "`."), "",
  "## Interpretation", "",
  if (overall_status == "PASS_N1B_TO_REPRESENTATION_DISCUSSION") {
    "All three frozen association gates passed. This opens a separate news-representation discussion; it does not establish a usable exposure policy."
  } else if (overall_status == "STOP_N1B_ASSOCIATION_NOT_STABLE") {
    "At least one frozen stability gate failed. Stop before sentiment, representation expansion, model fitting, or policy design; do not tune the inspected horizon or percentile boundary."
  } else {
    "A data-health, TRAIN-support, or leakage gate failed. The association result is not admissible evidence."
  }, "",
  "## Timing and identity", "",
  "- Historical archive availability uses `updated_at`; updates delayed more than 24 hours and backward-looking exact-title repeats are excluded.",
  "- FB and META are one issuer. Historical provider symbols remain in provenance and are accepted only in their frozen validity windows.",
  "- Every OOS percentile and volatility scale is frozen from the preceding eight-quarter issuer-local TRAIN window.", "",
  "- Adjusted bars explicitly cover every issuer from 2019-12-20 through 2024-12-31; provider staleness versus 2026 is informational for this bounded historical query.", "",
  "## Hard boundary", "",
  "Sentiment, embeddings, direction, horizon search, threshold search, exposure, allocation, portfolio metrics, models, and live-advice changes are all zero.", "",
  "## Visuals", "",
  "- `visuals/n1b_fold_stability.png`",
  "- `visuals/n1b_issuer_quarter_coverage.png`",
  "- `visuals/n1b_train_calibration_examples.png`",
  "- `visuals/n1b_representative_event_tapes.png`",
  "- `visuals/n1b_high_intensity_concentration.png`"
)
writeLines(report, file.path(output_dir, "n1b_report.md"), useBytes = TRUE)

message("Gen5.4 N1B complete: ", overall_status)
message("Mean fold Spearman: ", sprintf("%.4f", verdict$mean_fold_spearman))
message("Positive correlation folds: ", verdict$positive_correlation_folds, "/12")
message("Positive separation folds: ", verdict$positive_separation_folds, "/12")
message("Report: ", normalizePath(file.path(output_dir, "n1b_report.md"), winslash = "/"))
