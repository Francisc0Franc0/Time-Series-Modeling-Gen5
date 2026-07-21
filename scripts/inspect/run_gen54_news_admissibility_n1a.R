# Gen5.4 N1A historical-news point-in-time admissibility and density audit.
# No sentiment, outcomes, OHLCV joins, features, or models.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "alpaca_context_provider.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))
source(file.path(repo_root, "R", "gen54_news_admissibility.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
write_csv <- function(x, path) { utils::write.csv(x, path, row.names = FALSE, na = ""); invisible(path) }
safe_fraction <- function(numerator, denominator) if (denominator > 0) numerator / denominator else NA_real_

run_id <- env_or("GEN5_GEN54_NEWS_N1A_RUN_ID", "g54_news_n1a_20260721")
as_of_timestamp <- env_or("GEN5_GEN54_NEWS_N1A_AS_OF", "2026-07-21 17:30:00")
retrieved_at <- env_or("GEN5_GEN54_NEWS_N1A_RETRIEVED_AT", "2026-07-21 17:30:00")
request_pause_seconds <- as.numeric(env_or("GEN5_GEN54_NEWS_N1A_REQUEST_PAUSE", "0.35"))
reuse_raw <- tolower(env_or("GEN5_GEN54_NEWS_N1A_REUSE_RAW", "false")) %in% c("1", "true", "yes")
start_date <- as.Date("2020-01-01")
end_date <- as.Date("2024-12-31")
calendar_end_date <- as.Date("2025-01-10")
signal_cutoff <- "17:30:00"
timezone <- "America/New_York"
repeat_window_hours <- 72
minimum_novel_clusters_per_symbol_year <- 20L
minimum_symbols_per_year <- 20L
maximum_symbol_association_share <- 0.25
maximum_repeat_share <- 0.50
repeat_warn_share <- 0.25
revision_cross_warn_share <- 0.10

registry <- g5_gen54_xs_candidate_registry()
symbols <- registry$symbol
years <- 2020:2024
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id)
raw_dir <- file.path(output_dir, "raw")
visual_dir <- file.path(output_dir, "visuals")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

message("Gen5.4 N1A starting: calendar and five yearly news partitions.")
calendar_raw_path <- file.path(raw_dir, "alpaca_calendar.json")
if (reuse_raw) {
  if (!file.exists(calendar_raw_path)) g5_stop("Raw reuse requested but alpaca_calendar.json is missing.")
  calendar_text <- paste(readLines(calendar_raw_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  calendar_parsed <- jsonlite::fromJSON(calendar_text, simplifyVector = FALSE)
  calendar <- g5_alpaca_map_calendar_payload(calendar_parsed, as_of_timestamp, retrieved_at)
} else {
  calendar_result <- g5_fetch_alpaca_calendar(
    start_date = start_date,
    end_date = calendar_end_date,
    as_of_timestamp = as_of_timestamp,
    retrieved_at = retrieved_at
  )
  calendar <- calendar_result$data
  writeLines(calendar_result$response_text, calendar_raw_path, useBytes = TRUE)
}

yearly_articles <- list()
request_rows <- list()
page_rows <- list()
for (year in years) {
  request <- g5_alpaca_news_request(
    symbols = symbols,
    start_timestamp = sprintf("%d-01-01T00:00:00Z", year),
    end_timestamp = sprintf("%d-12-31T23:59:59Z", year),
    as_of_timestamp = as_of_timestamp,
    include_content = FALSE,
    limit = 50L
  )
  if (reuse_raw) {
    raw_files <- sort(list.files(raw_dir, pattern = paste0("^news_", year, "_page_[0-9]{4}\\.json$"), full.names = TRUE))
    if (!length(raw_files)) g5_stop(paste("Raw reuse requested but no page files exist for", year))
    pages <- vector("list", length(raw_files))
    frames <- vector("list", length(raw_files))
    for (page_number in seq_along(raw_files)) {
      response_text <- paste(readLines(raw_files[[page_number]], warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
      next_token <- parsed$next_page_token
      next_token <- if (is.null(next_token) || !nzchar(as.character(next_token))) "" else as.character(next_token)
      pages[[page_number]] <- list(
        page_number = page_number,
        http_status = 200L,
        page_token_in = if (page_number == 1L) "" else "reused_prior_page_token",
        next_page_token = next_token,
        response_bytes = nchar(response_text, type = "bytes"),
        response_text = response_text
      )
      frames[[page_number]] <- g5_alpaca_map_news_payload(parsed, request, retrieved_at)
    }
    if (nzchar(tail(pages, 1L)[[1L]]$next_page_token)) {
      g5_stop(paste("Raw page chain for", year, "does not end with an exhausted page token."))
    }
    data <- do.call(rbind, frames[vapply(frames, nrow, integer(1L)) > 0L])
    result <- list(data = data, pages = pages)
    message("Rebuilt Alpaca news partition ", year, " from preserved raw pages.")
  } else {
    message("Retrieving Alpaca news partition ", year, ".")
    result <- g5_fetch_alpaca_news(
      request,
      retrieved_at = retrieved_at,
      request_pause_seconds = request_pause_seconds
    )
  }
  request$request_year <- year
  request_rows[[as.character(year)]] <- request
  yearly_articles[[as.character(year)]] <- result$data
  pages <- lapply(result$pages, function(page) {
    raw_name <- sprintf("news_%d_page_%04d.json", year, page$page_number)
    writeLines(page$response_text, file.path(raw_dir, raw_name), useBytes = TRUE)
    data.frame(
      request_year = year,
      page_number = page$page_number,
      http_status = page$http_status,
      page_token_in_present = nzchar(page$page_token_in),
      next_page_token_present = nzchar(page$next_page_token),
      response_bytes = page$response_bytes,
      raw_file = file.path("raw", raw_name),
      stringsAsFactors = FALSE
    )
  })
  page_rows[[as.character(year)]] <- do.call(rbind, pages)
  message("Partition ", year, ": ", nrow(result$data), " articles across ", length(result$pages), " pages.")
}

requests <- do.call(rbind, request_rows)
page_manifest <- do.call(rbind, page_rows)
articles <- do.call(rbind, yearly_articles)
rownames(requests) <- rownames(page_manifest) <- rownames(articles) <- NULL

admissibility <- g5_gen54_news_build_admissibility(
  articles = articles,
  candidate_symbols = symbols,
  session_dates = calendar$session_date,
  cutoff_time = signal_cutoff,
  timezone = timezone,
  repeat_window_hours = repeat_window_hours
)
articles_audit <- admissibility$articles
associations <- admissibility$associations
coverage <- g5_gen54_news_coverage(associations, symbols, calendar$session_date, start_date, end_date)

year_gate <- aggregate(
  coverage$symbol_year$novel_exact_title_count >= minimum_novel_clusters_per_symbol_year,
  list(year = coverage$symbol_year$year),
  sum
)
names(year_gate)[[2L]] <- "symbols_meeting_minimum"
year_gate$required_symbols <- minimum_symbols_per_year
year_gate$pass <- year_gate$symbols_meeting_minimum >= year_gate$required_symbols

symbol_association <- aggregate(associations$article_id, list(symbol = associations$symbol), length)
names(symbol_association)[[2L]] <- "article_association_count"
symbol_association$association_share <- symbol_association$article_association_count / sum(symbol_association$article_association_count)
symbol_association <- merge(registry, symbol_association, by = "symbol", all.x = TRUE, sort = FALSE)
symbol_association$article_association_count[is.na(symbol_association$article_association_count)] <- 0L
symbol_association$association_share[is.na(symbol_association$association_share)] <- 0

duplicate_ids <- sum(duplicated(articles_audit$article_id))
missing_ids <- sum(is.na(articles_audit$article_id) | !nzchar(articles_audit$article_id))
missing_headlines <- sum(is.na(articles_audit$headline) | !nzchar(trimws(articles_audit$headline)))
missing_created <- sum(is.na(articles_audit$created_at) | !nzchar(articles_audit$created_at))
missing_updated <- sum(is.na(articles_audit$updated_at) | !nzchar(articles_audit$updated_at))
negative_update_delays <- sum(articles_audit$update_delay_seconds < 0, na.rm = TRUE)
missing_decision_sessions <- sum(is.na(articles_audit$decision_session))
missing_execution_sessions <- sum(is.na(articles_audit$execution_session))
repeat_share <- safe_fraction(sum(articles_audit$exact_title_repeat), nrow(articles_audit))
revision_cross_share <- safe_fraction(sum(articles_audit$revision_crossed_decision_cycle), nrow(articles_audit))
delay_hours <- articles_audit$update_delay_seconds / 3600
delay_over_24h <- sum(delay_hours > 24)
delay_over_7d <- sum(delay_hours > 24 * 7)
delay_over_30d <- sum(delay_hours > 24 * 30)
delay_over_1y <- sum(delay_hours > 24 * 365)
maximum_observed_symbol_share <- max(symbol_association$association_share)
top_five_symbol_share <- sum(sort(symbol_association$association_share, decreasing = TRUE)[seq_len(5L)])
pagination_exhausted <- all(vapply(split(page_manifest, page_manifest$request_year), function(part) {
  !isTRUE(tail(part$next_page_token_present, 1L))
}, logical(1L)))

gates <- data.frame(
  gate_id = c(
    "all_pages_http_200", "pagination_exhausted", "required_fields_complete",
    "article_ids_unique", "non_negative_update_delay", "session_assignment_complete",
    "yearly_symbol_density", "symbol_concentration", "exact_title_repeat_share"
  ),
  observed = c(
    paste(sort(unique(page_manifest$http_status)), collapse = "|"),
    as.character(pagination_exhausted),
    paste0("id=", missing_ids, ";headline=", missing_headlines, ";created=", missing_created, ";updated=", missing_updated),
    as.character(duplicate_ids),
    as.character(negative_update_delays),
    paste0("decision_missing=", missing_decision_sessions, ";execution_missing=", missing_execution_sessions),
    paste0(min(year_gate$symbols_meeting_minimum), "/24 minimum across years"),
    sprintf("%.4f", maximum_observed_symbol_share),
    sprintf("%.4f", repeat_share)
  ),
  threshold = c(
    "HTTP 200 only", "TRUE", "all missing counts = 0", "0", "0",
    "both missing counts = 0", "at least 20 of 24 symbols each year",
    "maximum <= 0.25", "share <= 0.50"
  ),
  pass = c(
    all(page_manifest$http_status == 200L),
    pagination_exhausted,
    all(c(missing_ids, missing_headlines, missing_created, missing_updated) == 0L),
    duplicate_ids == 0L,
    negative_update_delays == 0L,
    missing_decision_sessions == 0L && missing_execution_sessions == 0L,
    all(year_gate$pass),
    maximum_observed_symbol_share <= maximum_symbol_association_share,
    repeat_share <= maximum_repeat_share
  ),
  stringsAsFactors = FALSE
)

health <- data.frame(
  severity = c(
    ifelse(all(gates$pass), "INFO", "ERROR"),
    ifelse(repeat_share > repeat_warn_share, "WARN", "INFO"),
    ifelse(revision_cross_share > revision_cross_warn_share, "WARN", "INFO"),
    "INFO", "INFO", "INFO", "INFO", "INFO"
  ),
  check_id = c(
    "hard_admission_gates", "exact_title_repeat_rate", "revision_cross_cycle_rate",
    "article_count", "candidate_association_count", "calendar_session_count",
    "long_update_delay_tail", "top_five_symbol_association_share"
  ),
  value = c(
    paste0(sum(gates$pass), "/", nrow(gates), " passed"),
    sprintf("%.4f", repeat_share),
    sprintf("%.4f", revision_cross_share),
    as.character(nrow(articles_audit)),
    as.character(nrow(associations)),
    as.character(sum(calendar$session_date >= start_date & calendar$session_date <= end_date)),
    paste0("gt24h=", delay_over_24h, ";gt7d=", delay_over_7d, ";gt30d=", delay_over_30d, ";gt1y=", delay_over_1y),
    sprintf("%.4f", top_five_symbol_share)
  ),
  stringsAsFactors = FALSE
)

overall_status <- if (!all(gates$pass)) {
  "STOP_N1A_ADMISSION_FAILURE"
} else if (any(health$severity == "WARN")) {
  "REVIEW_REQUIRED_N1A_WARN"
} else {
  "PASS_N1A_ADMISSIBLE_FOR_N1B_DISCUSSION"
}

cluster_sizes <- aggregate(articles_audit$article_id, list(cluster_id = articles_audit$exact_title_cluster_id), length)
names(cluster_sizes)[[2L]] <- "article_count"
cluster_headlines <- articles_audit[!duplicated(articles_audit$exact_title_cluster_id), c("exact_title_cluster_id", "headline", "updated_at"), drop = FALSE]
names(cluster_headlines)[[1L]] <- "cluster_id"
duplicate_clusters <- merge(cluster_sizes, cluster_headlines, by = "cluster_id", all.x = TRUE)
duplicate_clusters <- duplicate_clusters[duplicate_clusters$article_count > 1L, , drop = FALSE]
duplicate_clusters <- duplicate_clusters[order(-duplicate_clusters$article_count, duplicate_clusters$updated_at), , drop = FALSE]
duplicate_cluster_sample <- head(duplicate_clusters, 20L)

run_spec <- data.frame(
  schema_version = "gen54_news_n1a_v0.1",
  wrapper = "scripts/inspect/run_gen54_news_admissibility_n1a.R",
  as_of_timestamp = as_of_timestamp,
  retrieved_at = retrieved_at,
  start_date = as.character(start_date),
  end_date = as.character(end_date),
  timezone = timezone,
  signal_cutoff = signal_cutoff,
  availability_authority = "updated_at",
  repeat_window_hours = repeat_window_hours,
  candidate_count = length(symbols),
  article_count = nrow(articles_audit),
  association_count = nrow(associations),
  sentiment_count = 0L,
  feature_count = 0L,
  outcome_count = 0L,
  ohlcv_join_count = 0L,
  model_fit_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "n1a_run_spec.csv"))
write_csv(registry, file.path(output_dir, "n1a_candidate_registry.csv"))
write_csv(requests, file.path(output_dir, "n1a_news_requests.csv"))
write_csv(page_manifest, file.path(output_dir, "n1a_page_manifest.csv"))
write_csv(calendar, file.path(output_dir, "n1a_market_calendar.csv"))
write_csv(articles_audit, file.path(output_dir, "n1a_article_admissibility.csv"))
write_csv(associations, file.path(output_dir, "n1a_candidate_associations.csv"))
write_csv(coverage$symbol_year, file.path(output_dir, "n1a_symbol_year_coverage.csv"))
write_csv(coverage$symbol_quarter, file.path(output_dir, "n1a_symbol_quarter_coverage.csv"))
write_csv(year_gate, file.path(output_dir, "n1a_year_density_gate.csv"))
write_csv(symbol_association, file.path(output_dir, "n1a_symbol_association_share.csv"))
write_csv(duplicate_cluster_sample, file.path(output_dir, "n1a_duplicate_cluster_sample.csv"))
write_csv(gates, file.path(output_dir, "n1a_admission_gates.csv"))
write_csv(health, file.path(output_dir, "n1a_health.csv"))

coverage_matrix <- xtabs(novel_exact_title_count ~ symbol + year, coverage$symbol_year)
grDevices::png(file.path(visual_dir, "n1a_symbol_year_coverage_heatmap.png"), width = 1500, height = 1100, res = 150)
graphics::par(mar = c(5, 11, 4, 5))
graphics::image(
  x = seq_len(ncol(coverage_matrix)), y = seq_len(nrow(coverage_matrix)),
  z = t(coverage_matrix[nrow(coverage_matrix):1L, , drop = FALSE]),
  axes = FALSE, col = grDevices::hcl.colors(20, "Blues 3"),
  xlab = "Calendar year", ylab = "Candidate",
  main = "Novel exact-title clusters are measured before any market outcome"
)
graphics::axis(1, at = seq_len(ncol(coverage_matrix)), labels = colnames(coverage_matrix))
graphics::axis(2, at = seq_len(nrow(coverage_matrix)), labels = rev(rownames(coverage_matrix)), las = 2)
for (row in seq_len(nrow(coverage_matrix))) for (column in seq_len(ncol(coverage_matrix))) {
  graphics::text(column, nrow(coverage_matrix) - row + 1L, labels = coverage_matrix[row, column], cex = 0.7)
}
grDevices::dev.off()

delay_cap <- as.numeric(stats::quantile(delay_hours, 0.99, na.rm = TRUE, names = FALSE))
grDevices::png(file.path(visual_dir, "n1a_update_delay_distribution.png"), width = 1400, height = 800, res = 150)
graphics::hist(
  pmin(delay_hours, delay_cap), breaks = 50, col = "#2563EB", border = "white",
  xlab = paste0("Update delay in hours (capped at p99 = ", round(delay_cap, 1), ")"),
  main = "Creation time is not treated as archived-text availability"
)
grDevices::dev.off()

event_density <- coverage$symbol_year$event_session_share
grDevices::png(file.path(visual_dir, "n1a_event_session_density.png"), width = 1400, height = 800, res = 150)
graphics::boxplot(
  event_density ~ coverage$symbol_year$year,
  col = "#0F766E", ylab = "Share of sessions with at least one novel event",
  xlab = "Calendar year", main = "Event coverage rises over time and varies sharply by symbol"
)
grDevices::dev.off()

stale_counts <- c(delay_over_24h, delay_over_7d, delay_over_30d, delay_over_1y)
grDevices::png(file.path(visual_dir, "n1a_long_update_delay_tail.png"), width = 1400, height = 800, res = 150)
bars <- graphics::barplot(
  stale_counts,
  names.arg = c("> 24 hours", "> 7 days", "> 30 days", "> 1 year"),
  col = "#B91C1C", ylim = c(0, max(stale_counts) * 1.18),
  ylab = "Archived articles", main = "A small stale-update tail cannot be treated as fresh information arrival"
)
graphics::text(bars, stale_counts, labels = stale_counts, pos = 3)
grDevices::dev.off()

revision_by_year <- aggregate(
  articles_audit$revision_crossed_decision_cycle,
  list(year = as.integer(substr(articles_audit$updated_at, 1L, 4L))),
  mean
)
names(revision_by_year)[[2L]] <- "revision_cross_share"
grDevices::png(file.path(visual_dir, "n1a_revision_crossing_by_year.png"), width = 1400, height = 800, res = 150)
bars <- graphics::barplot(
  revision_by_year$revision_cross_share * 100,
  names.arg = revision_by_year$year, col = "#7C3AED",
  ylim = c(0, max(1, max(revision_by_year$revision_cross_share * 100) * 1.2)),
  ylab = "Articles crossing a decision cycle (%)",
  main = "Final updates are conservatively delayed to their admissible decision"
)
graphics::text(bars, revision_by_year$revision_cross_share * 100, labels = sprintf("%.1f%%", revision_by_year$revision_cross_share * 100), pos = 3)
grDevices::dev.off()

top_clusters <- head(duplicate_clusters, 10L)
grDevices::png(file.path(visual_dir, "n1a_duplicate_cluster_examples.png"), width = 1600, height = 950, res = 150)
if (nrow(top_clusters)) {
  labels <- substr(top_clusters$headline, 1L, 42L)
  graphics::par(mar = c(5, 18, 4, 2))
  bars <- graphics::barplot(
    rev(top_clusters$article_count), names.arg = rev(labels), horiz = TRUE, las = 1,
    cex.names = 0.75,
    col = "#D97706", xlab = "Articles in backward-looking exact-title cluster",
    main = "Repeated titles are clustered instead of counted as independent events"
  )
  graphics::text(rev(top_clusters$article_count), bars, labels = rev(top_clusters$article_count), pos = 4)
} else {
  graphics::plot.new()
  graphics::text(0.5, 0.5, "No repeated exact-title clusters were observed.", cex = 1.4)
}
grDevices::dev.off()

report <- c(
  "# Gen5.4 News Admissibility N1A", "",
  paste0("Status: `", overall_status, "`"), "",
  "## Question", "",
  "Can Alpaca's historical news archive support a conservative point-in-time event panel across the fixed 24-stock Gen5.4 universe before outcomes are inspected?", "",
  "## Retrieval and timing", "",
  paste0("- Retrieved `", nrow(articles_audit), "` articles across `", nrow(page_manifest), "` HTTP pages and `", length(years), "` yearly partitions."),
  paste0("- Created `", nrow(associations), "` requested-symbol association rows across `", sum(calendar$session_date >= start_date & calendar$session_date <= end_date), "` market sessions."),
  paste0("- Exact-title repeat share: `", sprintf("%.2f%%", repeat_share * 100), "`; creation-to-final-update decision-cycle crossing share: `", sprintf("%.2f%%", revision_cross_share * 100), "`."),
  paste0("- Long-update tail: `", delay_over_24h, "` articles exceeded 24 hours, `", delay_over_30d, "` exceeded 30 days, and `", delay_over_1y, "` exceeded one year. These rows are timestamp-safe when delayed to `updated_at`, but they are not automatically valid fresh-information events."),
  "- Archived headline and summary availability is conservatively assigned by `updated_at` to the first 17:30 America/New_York scheduled cutoff at or after the update.", "",
  "## Density", "",
  paste0("- The minimum number of candidates meeting 20 novel clusters in a year was `", min(year_gate$symbols_meeting_minimum), " / 24`."),
  paste0("- Maximum single-symbol association share was `", sprintf("%.2f%%", maximum_observed_symbol_share * 100), "`."), "",
  paste0("- The five most-covered symbols supplied `", sprintf("%.2f%%", top_five_symbol_share * 100), "` of association rows. Raw article counts are therefore not comparable across symbols without a frozen symbol-local normalization."),
  "- `META` had zero novel clusters in 2020 and 12 in 2021 under the current symbol key. N1B must treat this as a symbol-history discontinuity, not as evidence that the company had no news.", "",
  "## Gate readout", "",
  paste0("- Hard gates passed: `", sum(gates$pass), " / ", nrow(gates), "`."),
  if (any(health$severity == "WARN")) paste0("- WARN checks: `", paste(health$check_id[health$severity == "WARN"], collapse = ", "), "`.") else "- WARN checks: `none`.", "",
  "## Boundary", "",
  "Sentiment, embeddings, event taxonomies, features, labels, outcomes, OHLCV joins, correlations, portfolio results, and model fits are all zero. A pass admits only a discussion of one measurement-only N1B hypothesis.", "",
  "The historical REST archive remains a current archive snapshot rather than a documented version replay. Prospective equivalence still requires a future real-time shadow archive with local receipt timestamps."
)
writeLines(report, file.path(output_dir, "n1a_report.md"), useBytes = TRUE)

message("Gen5.4 N1A complete: ", overall_status)
message("Hard gates: ", sum(gates$pass), "/", nrow(gates), "; WARN checks: ", sum(health$severity == "WARN"))
message("Report: ", normalizePath(file.path(output_dir, "n1a_report.md"), winslash = "/"))
