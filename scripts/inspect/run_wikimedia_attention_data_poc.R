# ADL-WIKI-01.1: collect, audit, and visualize daily GameStop Wikipedia views.
# This script does not join prices, calculate returns, or test predictability.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "alternative_data_lab", "R", "wikimedia_pageviews.R"))

contract <- adw_contract()
contract <- adw_validate_contract(contract)
run_dir <- file.path(
  repo_root, "runs", "research_workbench", "alternative_data_lab",
  "wikimedia_attention_gamestop_20260901"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

raw_path <- file.path(run_dir, "wikimedia_raw_response.json")
refresh <- identical(tolower(Sys.getenv("GEN5_WIKIMEDIA_REFRESH", "false")), "true")
if (file.exists(raw_path) && !refresh) {
  raw_json <- paste(readLines(raw_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  payload <- jsonlite::fromJSON(raw_json, simplifyVector = FALSE)
  retrieval_status <- "CACHE_HIT"
  retrieved_at_utc <- as.character(file.info(raw_path)$mtime)
} else {
  fetched <- adw_fetch_payload(contract)
  raw_json <- fetched$raw_json
  payload <- fetched$payload
  retrieved_at_utc <- fetched$retrieved_at_utc
  writeLines(raw_json, raw_path, useBytes = TRUE)
  retrieval_status <- "FETCHED"
}

observations <- adw_parse_payload(payload, contract)
daily <- adw_complete_calendar(observations, contract)
daily$trailing_28d_median <- adw_trailing_median(daily$views, 28L)
missing <- daily[!daily$observed_from_api, c("date", "missing_reason"), drop = FALSE]

run_spec <- data.frame(
  field = c(
    "hypothesis_id", "authority", "provider", "request_project", "response_project", "article", "access",
    "agent", "granularity", "start_date", "end_date", "as_of_timestamp",
    "request_url", "retrieval_status", "retrieved_at_utc", "price_join",
    "predictive_test"
  ),
  value = c(
    contract$hypothesis_id, contract$authority, "Wikimedia Analytics API",
    contract$project, contract$response_project, contract$article, contract$access, contract$agent,
    contract$granularity, as.character(contract$start_date),
    as.character(contract$end_date), contract$as_of_timestamp,
    adw_request_url(contract), retrieval_status, retrieved_at_utc, "NONE", "NONE"
  ),
  stringsAsFactors = FALSE
)

expected_days <- length(seq(contract$start_date, contract$end_date, by = "day"))
health <- data.frame(
  check_id = c(
    "raw_response_preserved", "request_dimensions_reproduced", "date_range_bounded",
    "unique_daily_rows", "nonnegative_views", "complete_calendar_emitted",
    "missing_days_not_zero_filled", "no_price_or_return_join"
  ),
  status = c(
    file.exists(raw_path),
    all(observations$project == contract$response_project & observations$article == contract$article &
          observations$access == contract$access & observations$agent == contract$agent),
    min(observations$date) >= contract$start_date && max(observations$date) <= contract$end_date,
    !anyDuplicated(observations$date),
    all(is.finite(observations$views) & observations$views >= 0),
    nrow(daily) == expected_days,
    all(is.na(daily$views[!daily$observed_from_api])),
    TRUE
  ),
  detail = c(
    raw_path,
    paste(contract$response_project, contract$article, contract$access, contract$agent, sep = " | "),
    paste(min(observations$date), max(observations$date), sep = " through "),
    paste(nrow(observations), "API observations"),
    paste("range", min(observations$views), "to", max(observations$views)),
    paste(nrow(daily), "calendar days"),
    paste(nrow(missing), "unresolved omitted dates"),
    "collection and handling only"
  ),
  stringsAsFactors = FALSE
)
if (!all(health$status)) {
  failed <- paste(health$check_id[!health$status], collapse = ", ")
  adw_stop(paste("Wikimedia collection checks failed:", failed))
}

top_days <- observations[order(-observations$views, observations$date), c("date", "views")]
top_days <- head(top_days, 20L)
top_days$rank <- seq_len(nrow(top_days))
top_days <- top_days[c("rank", "date", "views")]

write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE, na = "")
write.csv(health, file.path(run_dir, "data_health.csv"), row.names = FALSE, na = "")
write.csv(daily, file.path(run_dir, "daily_pageviews.csv"), row.names = FALSE, na = "")
write.csv(missing, file.path(run_dir, "missing_dates.csv"), row.names = FALSE, na = "")
write.csv(top_days, file.path(run_dir, "top_attention_days.csv"), row.names = FALSE, na = "")

chart_path <- file.path(visual_dir, "gamestop_wikipedia_pageviews_2019_2023.png")
png(chart_path, width = 1900, height = 1000, res = 170)
par(mar = c(5, 5, 4.5, 2), bg = "#FAFAF7", fg = "#24313A", col.axis = "#52616B",
    col.lab = "#24313A", family = "sans")
plot(
  daily$date, daily$views,
  type = "h", log = "y", lend = 1, col = grDevices::adjustcolor("#456990", alpha.f = 0.30),
  xlab = "Date", ylab = "Daily user-classified page views (log scale)",
  main = "GameStop Wikipedia attention, 2019-2023",
  sub = "Raw daily observations plus a trailing 28-day median; no price data or outcome test",
  yaxt = "n"
)
axis(2, at = c(100, 500, 2000, 10000, 50000, 200000),
     labels = c("100", "500", "2k", "10k", "50k", "200k"), las = 1)
grid(col = "#D9DEDF", lty = 1)
lines(daily$date, daily$trailing_28d_median, col = "#C8553D", lwd = 2.5)
peak <- observations[which.max(observations$views), , drop = FALSE]
points(peak$date, peak$views, pch = 21, bg = "#F3B61F", col = "#24313A", cex = 1.5)
text(
  peak$date, peak$views,
  labels = paste0(format(peak$date, "%Y-%m-%d"), "\n", format(peak$views, big.mark = ","), " views"),
  pos = 4, offset = 0.7, cex = 0.82, col = "#24313A"
)
legend(
  "topright", legend = c("Daily views", "Trailing 28-day median", "Maximum day"),
  col = c("#456990", "#C8553D", "#24313A"), lwd = c(3, 3, NA),
  pch = c(NA, NA, 21), pt.bg = c(NA, NA, "#F3B61F"), bty = "n"
)
dev.off()

median_views <- stats::median(observations$views)
peak_multiple <- peak$views / median_views
report <- c(
  "# ADL-WIKI-01.1 — GameStop Wikipedia Attention Collection POC",
  "",
  "## Question",
  "",
  "Can Gen5 collect, preserve, map, audit, and visualize a simple alternative-data source before opening any predictive question?",
  "",
  "## Frozen collection contract",
  "",
  paste0("- Page: `", contract$article, "` on `", contract$project, "`."),
  paste0("- Range: `", contract$start_date, "` through `", contract$end_date, "`."),
  paste0("- Dimensions: `", contract$access, "`, agent `", contract$agent, "`, `", contract$granularity, "`."),
  paste0("- Explicit as-of timestamp: `", contract$as_of_timestamp, "`."),
  "- Price joins, returns, prediction, costs, performance, and trading rules: `NONE`.",
  "",
  "## Collection readout",
  "",
  paste0("- API observations: `", format(nrow(observations), big.mark = ","), "` of `", format(expected_days, big.mark = ","), "` calendar days."),
  paste0("- Unresolved omitted dates: `", nrow(missing), "`; these remain missing rather than being converted to zero."),
  paste0("- Median daily views: `", format(round(median_views), big.mark = ","), "`."),
  paste0("- Maximum: `", format(peak$views, big.mark = ","), "` on `", peak$date, "`, approximately `", formatC(peak_multiple, digits = 1, format = "f"), "x` the sample median."),
  "",
  "The conspicuous 2021 attention shock is the intended positive-control sanity check. It shows that the pipeline captures a real public-attention episode; it does not show that the observations predicted returns or were available before the associated information reached the market.",
  "",
  paste0("![GameStop Wikipedia page views](", file.path("visuals", basename(chart_path)), ")"),
  "",
  "## Limitations preserved",
  "",
  "- Page views measure attention, not sentiment, purchasing behavior, company fundamentals, or investor identity.",
  "- Wikimedia does not aggregate redirects into the requested article's count, so title and redirect mapping are part of the data contract.",
  "- Omitted dates can mean zero or data not loaded; they are not silently imputed.",
  "- Daily observations are loaded after the measured day and can experience additional latency.",
  "- A famous historical spike is useful for plumbing validation but cannot be selected later as evidence of predictive power.",
  "",
  "## Decision",
  "",
  "`COLLECTION_POC_COMPLETE_NO_PREDICTIVE_CLAIM`",
  "",
  "The alternative-data plumbing is usable for the next operator decision. Stop before joining market outcomes or choosing an attention threshold, transformation, horizon, company basket, or trading rule."
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("ADL-WIKI-01.1 complete")
message("Status: COLLECTION_POC_COMPLETE_NO_PREDICTIVE_CLAIM")
message("Observations: ", nrow(observations), "/", expected_days)
message("Peak: ", peak$date, " | ", format(peak$views, big.mark = ","), " views")
message("Report: ", file.path(run_dir, "report.md"))
message("Chart: ", chart_path)
