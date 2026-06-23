`%||%` <- function(x, y) if (is.null(x)) y else x

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

if (!dir.exists(file.path(repo_root, "R"))) {
  repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))

resolved <- g5_resolve_latest_completed_session(
  as.POSIXct("2026-06-22 17:00:00", tz = "America/New_York")
)
stopifnot(as.Date(resolved$latest_completed_session) == as.Date("2026-06-22"))

resolved_before_close <- g5_resolve_latest_completed_session(
  as.POSIXct("2026-06-22 12:00:00", tz = "America/New_York")
)
stopifnot(as.Date(resolved_before_close$latest_completed_session) == as.Date("2026-06-19"))

bars <- data.frame(
  symbol = c("SPY", "SPY", "QQQ"),
  session_date = as.Date(c("2026-06-18", "2026-06-19", "2026-06-19")),
  open = c(100, 101, 200),
  high = c(101, 102, 202),
  low = c(99, 100, 199),
  close = c(100.5, 101.5, 201),
  volume = c(1000, 1100, 1200),
  adjusted = TRUE,
  timeframe = "1D",
  provider = "alpaca",
  as_of_timestamp = "2026-06-22 17:00:00",
  latest_completed_session = as.Date("2026-06-22"),
  fetch_start_date = as.Date("2026-06-18"),
  fetch_end_date = as.Date("2026-06-22"),
  data_version_hash = "demo",
  stringsAsFactors = FALSE
)

validated <- g5_validate_bar_data(bars)
stopifnot(nrow(validated) == 3L)

tmp_cache <- tempfile("g5_cache_")
written <- g5_write_bars_cache(validated, tmp_cache)
stopifnot(nrow(written) == 2L)
read_back <- g5_read_bars_cache(c("SPY", "QQQ"), tmp_cache)
stopifnot(nrow(read_back) == 3L)

audit <- g5_audit_bars(read_back, c("SPY", "QQQ", "TSLA"), as.Date("2026-06-22"))
stopifnot(audit$missing_symbol_count == 1L)
stopifnot(audit$row_count == 3L)
stopifnot(audit$duplicate_symbol_session_count == 0L)
stopifnot(audit$latest_completed_session == as.Date("2026-06-22"))

provider_request <- g5_alpaca_daily_adjusted_request(
  symbols = c("SPY", "QQQ"),
  start_date = as.Date("2026-06-18"),
  end_date = as.Date("2026-06-19"),
  as_of_timestamp = "2026-06-22 17:00:00",
  latest_completed_session = as.Date("2026-06-22")
)

provider_payload <- list(
  SPY = list(
    list(t = "2026-06-18T04:00:00Z", o = 100, h = 101, l = 99, c = 100.5, v = 1000),
    list(t = "2026-06-19T04:00:00Z", o = 101, h = 102, l = 100, c = 101.5, v = 1100)
  ),
  QQQ = list(
    list(t = "2026-06-19T04:00:00Z", o = 200, h = 202, l = 199, c = 201, v = 1200)
  )
)

mapped <- g5_alpaca_map_bars_to_canonical(provider_payload, provider_request)
stopifnot(identical(names(mapped), g5_required_bar_columns()))
stopifnot(nrow(mapped) == 3L)
stopifnot(all(mapped$provider == "alpaca"))
stopifnot(all(mapped$adjusted))
stopifnot(all(mapped$timeframe == "1D"))

message("Gen5 scaffold smoke test passed.")
