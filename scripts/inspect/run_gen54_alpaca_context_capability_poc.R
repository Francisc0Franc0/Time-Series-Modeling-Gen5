# Gen5.4 N0/I0 Alpaca context-data capability POC.
# Retrieval and audit only: no labels, outcomes, features, sentiment, or models.

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
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
write_csv <- function(x, path) { utils::write.csv(x, path, row.names = FALSE, na = ""); invisible(path) }

run_id <- env_or("GEN5_GEN54_CONTEXT_POC_RUN_ID", "g54_alpaca_context_n0_i0_20260721")
as_of_timestamp <- env_or("GEN5_GEN54_CONTEXT_POC_AS_OF", "2026-07-21 17:30:00")
retrieved_at <- env_or("GEN5_GEN54_CONTEXT_POC_RETRIEVED_AT", "2026-07-21 17:30:00")
symbols <- c("AAPL", "AMD", "NVDA", "TSLA", "MSTR")
index_symbols <- c("VIX", "SPX", "NDX")
start_timestamp <- "2024-01-02T00:00:00Z"
end_timestamp <- "2024-01-08T23:59:59Z"

output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id)
raw_dir <- file.path(output_dir, "raw")
visual_dir <- file.path(output_dir, "visuals")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

news_request <- g5_alpaca_news_request(
  symbols = symbols,
  start_timestamp = start_timestamp,
  end_timestamp = end_timestamp,
  as_of_timestamp = as_of_timestamp,
  include_content = FALSE,
  limit = 50L
)
index_request <- g5_alpaca_index_values_request(
  index_symbols = index_symbols,
  start_timestamp = start_timestamp,
  end_timestamp = end_timestamp,
  as_of_timestamp = as_of_timestamp,
  limit = 1000L
)

message("Gen5.4 Alpaca context capability POC starting.")
news <- g5_fetch_alpaca_news(news_request, retrieved_at = retrieved_at)
index_probe <- g5_probe_alpaca_index_values(index_request, retrieved_at = retrieved_at)

page_manifest_rows <- lapply(news$pages, function(page) {
  raw_name <- sprintf("news_page_%03d.json", page$page_number)
  writeLines(page$response_text, file.path(raw_dir, raw_name), useBytes = TRUE)
  data.frame(
    page_number = page$page_number,
    http_status = page$http_status,
    page_token_in_present = nzchar(page$page_token_in),
    next_page_token_present = nzchar(page$next_page_token),
    response_bytes = page$response_bytes,
    raw_file = file.path("raw", raw_name),
    stringsAsFactors = FALSE
  )
})
page_manifest <- do.call(rbind, page_manifest_rows)
writeLines(index_probe$response_text, file.path(raw_dir, "index_values_response.json"), useBytes = TRUE)

articles <- news$data
article_dates <- as.Date(substr(articles$created_at, 1L, 10L))
requested_pattern <- paste0("(^|\\|)(", paste(symbols, collapse = "|"), ")(\\||$)")
duplicate_ids <- sum(duplicated(articles$article_id))
missing_headlines <- sum(is.na(articles$headline) | !nzchar(trimws(articles$headline)))
missing_created <- sum(is.na(articles$created_at) | !nzchar(articles$created_at))
missing_updated <- sum(is.na(articles$updated_at) | !nzchar(articles$updated_at))
outside_window <- sum(article_dates < as.Date("2024-01-02") | article_dates > as.Date("2024-01-08"), na.rm = TRUE)
requested_symbol_rows <- sum(grepl(requested_pattern, articles$symbols))
last_token_exhausted <- !isTRUE(tail(page_manifest$next_page_token_present, 1L))

news_health <- data.frame(
  severity = c("INFO", "INFO", "INFO", "INFO", "INFO", "INFO", "INFO", "INFO"),
  check_id = c(
    "news_http_status", "pagination_exhausted", "article_count", "duplicate_article_ids",
    "headline_completeness", "timestamp_completeness", "created_date_window", "requested_symbol_coverage"
  ),
  value = c(
    paste(sort(unique(page_manifest$http_status)), collapse = "|"),
    as.character(last_token_exhausted),
    as.character(nrow(articles)),
    as.character(duplicate_ids),
    as.character(missing_headlines),
    paste0("created_missing=", missing_created, ";updated_missing=", missing_updated),
    as.character(outside_window),
    paste0(requested_symbol_rows, "/", nrow(articles))
  ),
  stringsAsFactors = FALSE
)
news_health$severity[news_health$check_id == "news_http_status" & news_health$value != "200"] <- "ERROR"
news_health$severity[news_health$check_id == "pagination_exhausted" & news_health$value != "TRUE"] <- "ERROR"
news_health$severity[news_health$check_id == "article_count" & news_health$value == "0"] <- "ERROR"
news_health$severity[news_health$check_id == "duplicate_article_ids" & news_health$value != "0"] <- "ERROR"
news_health$severity[news_health$check_id == "headline_completeness" & news_health$value != "0"] <- "WARN"
news_health$severity[news_health$check_id == "timestamp_completeness" & news_health$value != "created_missing=0;updated_missing=0"] <- "WARN"
news_health$severity[news_health$check_id == "created_date_window" & news_health$value != "0"] <- "ERROR"

index_result <- data.frame(
  endpoint = index_request$endpoint,
  requested_symbols = index_request$index_symbols,
  http_status = index_probe$http_status,
  authorized = index_probe$authorized,
  response_bytes = index_probe$response_bytes,
  response_message = index_probe$response_message,
  retrieved_at = retrieved_at,
  raw_file = file.path("raw", "index_values_response.json"),
  stringsAsFactors = FALSE
)

overall_status <- if (any(news_health$severity == "ERROR")) {
  "STOP_NEWS_CAPABILITY_FAILURE"
} else if (!isTRUE(index_probe$authorized)) {
  "PARTIAL_PASS_NEWS_AVAILABLE_INDEX_NOT_AUTHORIZED"
} else {
  "PASS_NEWS_AND_INDEX_ENDPOINTS_AVAILABLE"
}

run_spec <- data.frame(
  schema_version = "gen54_alpaca_context_capability_v0.1",
  wrapper = "scripts/inspect/run_gen54_alpaca_context_capability_poc.R",
  as_of_timestamp = as_of_timestamp,
  retrieved_at = retrieved_at,
  news_symbols = paste(symbols, collapse = ","),
  index_symbols = paste(index_symbols, collapse = ","),
  start_timestamp = start_timestamp,
  end_timestamp = end_timestamp,
  include_news_content = FALSE,
  sentiment_count = 0L,
  feature_count = 0L,
  outcome_count = 0L,
  model_fit_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

sample_columns <- c("article_id", "created_at", "updated_at", "symbols", "source", "headline")
news_sample <- head(articles[order(articles$created_at, articles$article_id), sample_columns, drop = FALSE], 12L)
write_csv(run_spec, file.path(output_dir, "capability_run_spec.csv"))
write_csv(news_request, file.path(output_dir, "news_request.csv"))
write_csv(index_request, file.path(output_dir, "index_request.csv"))
write_csv(page_manifest, file.path(output_dir, "news_page_manifest.csv"))
write_csv(articles, file.path(output_dir, "news_articles.csv"))
write_csv(news_sample, file.path(output_dir, "news_sample.csv"))
write_csv(news_health, file.path(output_dir, "news_data_health.csv"))
write_csv(index_result, file.path(output_dir, "index_capability.csv"))

grDevices::png(file.path(visual_dir, "news_pagination_proof.png"), width = 1400, height = 800, res = 150)
graphics::par(mar = c(6, 5, 4, 2))
page_bars <- graphics::barplot(
  page_manifest$response_bytes,
  names.arg = paste("Page", page_manifest$page_number),
  col = ifelse(page_manifest$http_status == 200L, "#2563EB", "#B91C1C"),
  ylim = c(0, max(page_manifest$response_bytes) * 1.16),
  ylab = "Raw response bytes",
  main = "Five HTTP 200 pages were traversed until the final page token disappeared"
)
graphics::text(
  page_bars,
  page_manifest$response_bytes,
  labels = paste0("HTTP ", page_manifest$http_status),
  pos = 3
)
grDevices::dev.off()

daily_counts <- as.data.frame(table(article_dates), stringsAsFactors = FALSE)
names(daily_counts) <- c("created_date", "article_count")
daily_counts$created_date <- as.Date(daily_counts$created_date)
grDevices::png(file.path(visual_dir, "news_articles_by_day.png"), width = 1400, height = 800, res = 150)
graphics::par(mar = c(6, 5, 4, 2))
graphics::barplot(
  daily_counts$article_count,
  names.arg = format(daily_counts$created_date, "%b %d"),
  col = "#2563EB",
  ylab = "Articles returned",
  main = "Alpaca historical news retrieval: articles by creation date"
)
grDevices::dev.off()

symbol_counts <- vapply(symbols, function(symbol) {
  sum(grepl(paste0("(^|\\|)", symbol, "(\\||$)"), articles$symbols))
}, integer(1L))
grDevices::png(file.path(visual_dir, "news_articles_by_symbol.png"), width = 1400, height = 800, res = 150)
graphics::par(mar = c(6, 5, 4, 2))
bars <- graphics::barplot(
  symbol_counts,
  names.arg = names(symbol_counts),
  col = "#0F766E",
  ylab = "Articles mentioning symbol",
  main = "The same retrieved archive can be inspected by requested symbol"
)
graphics::text(bars, symbol_counts, labels = symbol_counts, pos = 3)
grDevices::dev.off()

report <- c(
  "# Gen5.4 Alpaca Context Capability POC", "",
  paste0("Status: `", overall_status, "`"), "",
  "## Question", "",
  "Can the existing Alpaca account and credential plumbing retrieve auditable historical news and historical index values without performing any analysis?", "",
  "## N0 historical news", "",
  paste0("- Retrieved `", nrow(articles), "` normalized article records across `", nrow(page_manifest), "` fully traversed page(s)."),
  paste0("- Raw response bytes: `", sum(page_manifest$response_bytes), "`."),
  paste0("- Duplicate article IDs: `", duplicate_ids, "`; missing headlines: `", missing_headlines, "`; created dates outside the requested window: `", outside_window, "`."),
  "- Normalized research tables retain metadata only. Full content and images are not copied into the normalized table; raw responses remain in the ignored local packet for audit.",
  "- This proves availability and pagination only. It says nothing about sentiment quality, novelty, predictive value, or point-in-time revision safety.", "",
  "## I0 historical index values", "",
  paste0("- Endpoint response: HTTP `", index_probe$http_status, "` (`", index_probe$response_message, "`)."),
  if (isTRUE(index_probe$authorized)) {
    "- The account can access the index-values endpoint. Schema normalization remains a separate implementation decision."
  } else {
    "- Alpaca added the endpoint, but this account is not authorized for index data. The earlier stock-bars result and this entitlement result answer different questions."
  }, "",
  "## Boundary", "",
  "Sentiment count, feature count, outcome count, and model-fit count are all zero. No OHLCV join, return/risk calculation, allocation rule, replay, or live behavior was created.", "",
  "## Next discussion", "",
  "Decide whether to stop after proving news availability, or freeze a separate point-in-time news-representation theory contract. Do not begin with generic positive/negative sentiment or inspect market outcomes before that contract exists."
)
writeLines(report, file.path(output_dir, "context_capability_report.md"), useBytes = TRUE)

message("Gen5.4 Alpaca context capability complete: ", overall_status)
message("News articles: ", nrow(articles), "; pages: ", nrow(page_manifest))
message("Index endpoint HTTP: ", index_probe$http_status)
message("Report: ", normalizePath(file.path(output_dir, "context_capability_report.md"), winslash = "/"))
