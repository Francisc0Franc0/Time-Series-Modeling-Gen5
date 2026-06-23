# Operator-facing Gen5 data-layer validation.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))

g5_load_local_renviron(repo_root)
validation_dir <- file.path(repo_root, "runs", "validation")
dir.create(validation_dir, recursive = TRUE, showWarnings = FALSE)

results <- data.frame(
  check = character(),
  status = character(),
  detail = character(),
  stringsAsFactors = FALSE
)

record_result <- function(check, status, detail = "") {
  results <<- rbind(
    results,
    data.frame(check = check, status = status, detail = detail, stringsAsFactors = FALSE)
  )
  message(sprintf("%-5s %s%s", status, check, if (nzchar(detail)) paste0(" - ", detail) else ""))
}

pass_fail <- function(check, expr, detail = "") {
  expr_sub <- substitute(expr)
  out <- tryCatch(
    {
      value <- eval(expr_sub, parent.frame())
      if (isTRUE(value)) {
        record_result(check, "PASS", detail)
        TRUE
      } else {
        record_result(check, "FAIL", "condition returned false")
        FALSE
      }
    },
    error = function(e) {
      record_result(check, "FAIL", conditionMessage(e))
      FALSE
    }
  )
  invisible(out)
}

skip_check <- function(check, detail) {
  record_result(check, "SKIP", detail)
}

message("Gen5 data-layer validation")
message("Script: ", normalizePath(file.path(repo_root, "scripts", "validate", "validate_data_layer.R"), winslash = "/", mustWork = FALSE))
message("Run: Rscript scripts/validate/validate_data_layer.R")
message("Output directory: ", normalizePath(validation_dir, winslash = "/", mustWork = FALSE))

cfg <- NULL
resolved <- NULL
date_range <- NULL
request <- NULL
bars <- NULL
cache_read <- NULL
audit <- NULL
empty_audit <- NULL

pass_fail("config loads from example plus optional local override", {
  cfg <<- g5_load_data_layer_config(repo_root)
  is.list(cfg) && identical(cfg$provider, "alpaca") && identical(cfg$timeframe, "1D") && isTRUE(cfg$adjusted)
}, paste("sources:", paste(basename(cfg$config_source_files), collapse = ",")))

pass_fail("latest completed session uses explicit as_of_timestamp", {
  resolved <<- g5_resolve_latest_completed_session(
    as_of_timestamp = as.POSIXct("2026-06-22 17:00:00", tz = cfg$calendar$timezone),
    timezone = cfg$calendar$timezone,
    market_close_time = cfg$calendar$market_close_time
  )
  identical(as.Date(resolved$latest_completed_session), as.Date("2026-06-22")) &&
    identical(as.character(resolved$as_of_timestamp), "2026-06-22 17:00:00")
})

validation_symbols <- c("SPY", "QQQ", "TSLA", "EMPTY")
pass_fail("requested date range is explicit and bounded by latest completed session", {
  date_range <<- g5_alpaca_resolve_daily_date_range(
    start_date = as.Date("2026-06-18"),
    end_date = as.Date("2026-06-23"),
    latest_completed_session = resolved$latest_completed_session
  )
  identical(as.Date(date_range$requested_start_date), as.Date("2026-06-18")) &&
    identical(as.Date(date_range$requested_end_date), as.Date("2026-06-23")) &&
    identical(as.Date(date_range$fetch_end_date), as.Date("2026-06-22")) &&
    date_range$date_range_warning_count == 1L
}, "requested end after latest is recorded and clipped for the provider request")

pass_fail("Alpaca adjusted daily request is explicit and bounded", {
  request <<- g5_alpaca_daily_adjusted_request(
    symbols = validation_symbols,
    start_date = date_range$fetch_start_date,
    end_date = date_range$fetch_end_date,
    as_of_timestamp = resolved$as_of_timestamp,
    latest_completed_session = resolved$latest_completed_session,
    feed = cfg$feed
  )
  all(request$provider == "alpaca") &&
    all(request$timeframe == "1D") &&
    all(request$adjustment == "all") &&
    all(request$end_date <= request$latest_completed_session)
})

pass_fail("Alpaca request rejects unbounded future end dates", {
  inherits(
    try(
      g5_alpaca_daily_adjusted_request(
        symbols = "SPY",
        start_date = as.Date("2026-06-18"),
        end_date = as.Date("2026-06-23"),
        as_of_timestamp = resolved$as_of_timestamp,
        latest_completed_session = resolved$latest_completed_session,
        feed = cfg$feed
      ),
      silent = TRUE
    ),
    "try-error"
  )
})

provider_payload <- list(
  SPY = list(
    list(t = "2026-06-18T04:00:00Z", o = 100, h = 101, l = 99, c = 100.5, v = 1000),
    list(t = "2026-06-19T04:00:00Z", o = 101, h = 102, l = 100, c = 101.5, v = 1100),
    list(t = "2026-06-22T04:00:00Z", o = 102, h = 103, l = 101, c = 102.5, v = 1200)
  ),
  QQQ = list(
    list(t = "2026-06-19T04:00:00Z", o = 201, h = 203, l = 200, c = 202, v = 1500)
  ),
  EMPTY = list()
)

pass_fail("canonical bars are adjusted daily OHLCV only", {
  bars <<- g5_alpaca_map_bars_to_canonical(provider_payload, request)
  nrow(bars) == 4L &&
    all(bars$adjusted) &&
    all(bars$timeframe == "1D") &&
    all(bars$provider == "alpaca") &&
    all(bars$session_date <= bars$latest_completed_session)
})

validation_cache <- file.path(validation_dir, "cache_smoke")
pass_fail("cache write/read reports hits and missing symbols", {
  written <- g5_write_bars_cache(bars, cache_root = validation_cache)
  cache_read <<- g5_read_bars_cache(
    validation_symbols,
    cache_root = validation_cache,
    require_all = FALSE,
    return_metadata = TRUE
  )
  nrow(written) == 2L &&
    identical(sort(cache_read$cache_hit_symbols), c("QQQ", "SPY")) &&
    identical(sort(cache_read$cache_missing_symbols), c("EMPTY", "TSLA")) &&
    nrow(cache_read$bars) == 4L
})

pass_fail("audit reports availability, requested versus observed range, cache, and query timestamp", {
  audit <<- g5_audit_bars(
    bars = cache_read$bars,
    requested_symbols = validation_symbols,
    latest_completed_session = resolved$latest_completed_session,
    requested_start_date = date_range$requested_start_date,
    requested_end_date = date_range$requested_end_date,
    provider_query_timestamp = resolved$as_of_timestamp,
    cache_hits = cache_read$cache_hit_symbols,
    cache_misses = cache_read$cache_missing_symbols,
    availability_warnings = date_range$date_range_warnings
  )
  audit$requested_symbol_count == 4L &&
    audit$missing_symbol_count == 2L &&
    identical(audit$missing_symbols, "TSLA,EMPTY") &&
    audit$stale_symbol_count == 1L &&
    identical(audit$stale_symbols, "QQQ") &&
    audit$row_count == 4L &&
    audit$cache_hit_symbol_count == 2L &&
    audit$cache_miss_symbol_count == 2L &&
    identical(audit$provider_query_timestamp, resolved$as_of_timestamp) &&
    identical(as.Date(audit$requested_start_date), as.Date("2026-06-18")) &&
    identical(as.Date(audit$requested_end_date), as.Date("2026-06-23")) &&
    identical(as.Date(audit$observed_start_date), as.Date("2026-06-18")) &&
    identical(as.Date(audit$observed_end_date), as.Date("2026-06-22")) &&
    identical(audit$empty_symbol_count, 2L) &&
    identical(audit$empty_symbols, "TSLA,EMPTY") &&
    identical(audit$partial_history_symbol_count, 1L) &&
    identical(audit$partial_history_symbols, "QQQ") &&
    audit$availability_warning_count >= 3L
})

pass_fail("empty provider payload is reported as auditable availability failure", {
  empty_bars <- g5_alpaca_map_bars_to_canonical(list(), request)
  empty_audit <<- g5_audit_bars(
    bars = empty_bars,
    requested_symbols = validation_symbols,
    latest_completed_session = resolved$latest_completed_session,
    requested_start_date = date_range$requested_start_date,
    requested_end_date = date_range$requested_end_date,
    provider_query_timestamp = resolved$as_of_timestamp
  )
  nrow(empty_bars) == 0L &&
    empty_audit$empty_symbol_count == length(validation_symbols) &&
    identical(empty_audit$empty_symbols, paste(validation_symbols, collapse = ",")) &&
    empty_audit$availability_warning_count >= 2L &&
    grepl("empty_provider_payload_for_requested_range", empty_audit$availability_warnings, fixed = TRUE)
})

pass_fail("duplicate symbol/session rows are detected", {
  duplicated_bars <- rbind(bars, bars[1L, , drop = FALSE])
  duplicate_audit <- g5_audit_bars(
    bars = duplicated_bars,
    requested_symbols = validation_symbols,
    latest_completed_session = resolved$latest_completed_session
  )
  duplicate_audit$duplicate_symbol_session_count == 1L &&
    inherits(try(g5_validate_bar_data(duplicated_bars), silent = TRUE), "try-error")
})

audit_path <- file.path(validation_dir, "data_layer_validation_audit.csv")
results_path <- file.path(validation_dir, "data_layer_validation_results.csv")
utils::write.csv(audit, audit_path, row.names = FALSE)
utils::write.csv(results, results_path, row.names = FALSE)

pass_fail("validation outputs are written under runs/validation", {
  file.exists(audit_path) && file.exists(results_path)
}, paste("audit:", normalizePath(audit_path, winslash = "/", mustWork = FALSE)))

alpaca_cfg <- g5_alpaca_config_from_env()
missing_runtime <- c(
  if (!requireNamespace("httr", quietly = TRUE)) "httr",
  if (!requireNamespace("jsonlite", quietly = TRUE)) "jsonlite"
)
if (isTRUE(alpaca_cfg$has_credentials) && length(missing_runtime) == 0L) {
  skip_check("live Alpaca fetch smoke", "credentials/runtime detected; run Rscript scripts/run_data_refresh.R for network smoke")
} else {
  reasons <- c(
    if (!isTRUE(alpaca_cfg$has_credentials)) "missing Alpaca credentials",
    if (length(missing_runtime) > 0L) paste("missing packages:", paste(missing_runtime, collapse = ","))
  )
  skip_check("live Alpaca fetch smoke", paste(reasons, collapse = "; "))
}

utils::write.csv(results, results_path, row.names = FALSE)

failed <- results$status == "FAIL"
if (any(failed)) {
  message("Validation failed. Results: ", normalizePath(results_path, winslash = "/", mustWork = FALSE))
  quit(status = 1L, save = "no")
}

message("Validation passed. Results: ", normalizePath(results_path, winslash = "/", mustWork = FALSE))
