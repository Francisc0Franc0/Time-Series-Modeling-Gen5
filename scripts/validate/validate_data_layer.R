# Operator-facing Gen5 data-layer validation.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
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

validation_symbols <- c("SPY", "QQQ", "IWM", "DIA", "TSLA", "EMPTY")
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
  QQQ = list(
    list(t = "2026-06-18T04:00:00Z", o = 200, h = 201, l = 199, c = 200.5, v = 1400)
  ),
  IWM = list(
    list(t = "2026-06-22T04:00:00Z", o = 302, h = 303, l = 301, c = 302.5, v = 1600)
  ),
  TSLA = list(
    list(t = "2026-06-18T04:00:00Z", o = 400, h = 410, l = 390, c = 405, v = 2000),
    list(t = "2026-06-22T04:00:00Z", o = 406, h = 416, l = 396, c = 411, v = 2200)
  ),
  EMPTY = list()
)

pass_fail("provider payload maps to canonical adjusted daily OHLCV only", {
  bars <<- g5_alpaca_map_bars_to_canonical(provider_payload, request)
  nrow(bars) == 4L &&
    all(bars$adjusted) &&
    all(bars$timeframe == "1D") &&
    all(bars$provider == "alpaca") &&
    all(bars$session_date <= bars$latest_completed_session)
})

validation_cache <- file.path(validation_dir, "cache_smoke")
if (dir.exists(validation_cache)) {
  unlink(validation_cache, recursive = TRUE, force = TRUE)
}
existing_cache_bars <- data.frame(
  symbol = c("SPY", "SPY", "SPY", "QQQ", "QQQ", "IWM", "IWM", "DIA"),
  session_date = as.Date(c(
    "2026-06-18", "2026-06-19", "2026-06-22",
    "2026-06-19", "2026-06-22",
    "2026-06-18", "2026-06-19",
    "2026-06-19"
  )),
  open = c(100, 101, 102, 201, 202, 300, 301, 500),
  high = c(101, 102, 103, 202, 203, 301, 302, 501),
  low = c(99, 100, 101, 200, 201, 299, 300, 499),
  close = c(100.5, 101.5, 102.5, 201.5, 202.5, 300.5, 301.5, 500.5),
  volume = c(1000, 1100, 1200, 1500, 1550, 1600, 1650, 1700),
  adjusted = TRUE,
  timeframe = "1D",
  provider = "alpaca",
  as_of_timestamp = resolved$as_of_timestamp,
  latest_completed_session = as.Date(resolved$latest_completed_session),
  fetch_start_date = as.Date("2026-06-18"),
  fetch_end_date = as.Date("2026-06-22"),
  data_version_hash = "pending",
  stringsAsFactors = FALSE
)
existing_cache_bars$data_version_hash <- mapply(
  g5_make_data_version_hash,
  existing_cache_bars$provider,
  existing_cache_bars$symbol,
  existing_cache_bars$session_date,
  existing_cache_bars$open,
  existing_cache_bars$high,
  existing_cache_bars$low,
  existing_cache_bars$close,
  existing_cache_bars$volume,
  existing_cache_bars$adjusted,
  existing_cache_bars$timeframe,
  existing_cache_bars$as_of_timestamp,
  existing_cache_bars$latest_completed_session,
  existing_cache_bars$fetch_start_date,
  existing_cache_bars$fetch_end_date,
  USE.NAMES = FALSE
)

refresh <- NULL
incremental_write <- NULL
pass_fail("incremental cache plan makes refresh decisions explicit", {
  g5_write_bars_cache(existing_cache_bars, cache_root = validation_cache)
  refresh <<- g5_plan_incremental_cache_refresh(
    validation_symbols,
    cache_root = validation_cache,
    requested_start_date = date_range$fetch_start_date,
    requested_end_date = date_range$fetch_end_date,
    latest_completed_session = resolved$latest_completed_session
  )
  decisions <- setNames(refresh$plan$refresh_decision, refresh$plan$symbol)
  identical(decisions[["SPY"]], "fully_cached") &&
    identical(decisions[["QQQ"]], "partial_history") &&
    identical(decisions[["IWM"]], "stale_cache") &&
    identical(decisions[["DIA"]], "partial_history_stale") &&
    identical(decisions[["TSLA"]], "cold_cache") &&
    identical(decisions[["EMPTY"]], "cold_cache") &&
    identical(refresh$plan$needs_fetch, c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE))
})

pass_fail("incremental cache merge is deterministic and reports no returned bars", {
  incremental_write <<- g5_write_incremental_bars_cache(
    fetched_bars = bars,
    cache_root = validation_cache,
    refresh_plan = refresh$plan
  )
  cache_read <<- g5_read_bars_cache(
    validation_symbols,
    cache_root = validation_cache,
    require_all = FALSE,
    return_metadata = TRUE
  )
  nrow(incremental_write$bars) == 12L &&
    nrow(cache_read$bars) == 12L &&
    identical(sort(cache_read$cache_hit_symbols), c("DIA", "IWM", "QQQ", "SPY", "TSLA")) &&
    identical(cache_read$cache_missing_symbols, "EMPTY") &&
    identical(
      paste(cache_read$bars$symbol, cache_read$bars$session_date, sep = ":"),
      sort(paste(cache_read$bars$symbol, cache_read$bars$session_date, sep = ":"))
    ) &&
    identical(
      sort(incremental_write$summary$symbol[incremental_write$summary$no_returned_bars]),
      c("DIA", "EMPTY")
    )
})

pass_fail("audit reports availability, cache refresh decisions, and query timestamp", {
  audit <<- g5_audit_bars(
    bars = cache_read$bars,
    requested_symbols = validation_symbols,
    latest_completed_session = resolved$latest_completed_session,
    requested_start_date = date_range$requested_start_date,
    requested_end_date = date_range$requested_end_date,
    provider_query_timestamp = resolved$as_of_timestamp,
    cache_hits = cache_read$cache_hit_symbols,
    cache_misses = cache_read$cache_missing_symbols,
    availability_warnings = date_range$date_range_warnings,
    cache_refresh_plan = refresh$plan,
    cache_refresh_result = incremental_write$summary
  )
  audit$requested_symbol_count == 6L &&
    audit$missing_symbol_count == 1L &&
    identical(audit$missing_symbols, "EMPTY") &&
    audit$stale_symbol_count == 1L &&
    identical(audit$stale_symbols, "DIA") &&
    audit$row_count == 12L &&
    audit$cache_hit_symbol_count == 5L &&
    audit$cache_miss_symbol_count == 1L &&
    audit$refresh_fetch_symbol_count == 5L &&
    identical(audit$refresh_fetch_symbols, "QQQ,IWM,DIA,TSLA,EMPTY") &&
    audit$refresh_skip_symbol_count == 1L &&
    identical(audit$refresh_skip_symbols, "SPY") &&
    grepl("SPY=fully_cached", audit$refresh_decisions_by_symbol, fixed = TRUE) &&
    grepl("IWM=stale_cache", audit$refresh_decisions_by_symbol, fixed = TRUE) &&
    identical(audit$no_returned_bar_symbol_count, 2L) &&
    identical(audit$no_returned_bar_symbols, "DIA,EMPTY") &&
    identical(audit$provider_query_timestamp, resolved$as_of_timestamp) &&
    identical(as.Date(audit$requested_start_date), as.Date("2026-06-18")) &&
    identical(as.Date(audit$requested_end_date), as.Date("2026-06-23")) &&
    identical(as.Date(audit$observed_start_date), as.Date("2026-06-18")) &&
    identical(as.Date(audit$observed_end_date), as.Date("2026-06-22")) &&
    identical(audit$empty_symbol_count, 1L) &&
    identical(audit$empty_symbols, "EMPTY") &&
    identical(audit$partial_history_symbol_count, 1L) &&
    identical(audit$partial_history_symbols, "DIA") &&
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
refresh_plan_path <- file.path(validation_dir, "data_layer_validation_refresh_plan.csv")
merge_summary_path <- file.path(validation_dir, "data_layer_validation_merge_summary.csv")
symbol_coverage_path <- file.path(validation_dir, "data_layer_validation_symbol_coverage.csv")
symbol_coverage_chart_path <- file.path(validation_dir, "data_layer_validation_symbol_coverage.png")
g5_write_audit_artifact_csv(audit, audit_path)
utils::write.csv(results, results_path, row.names = FALSE)

pass_fail("validation outputs are written under runs/validation", {
  file.exists(audit_path) && file.exists(results_path)
}, paste("audit:", normalizePath(audit_path, winslash = "/", mustWork = FALSE)))

pass_fail("audit artifact CSV is written with required columns", {
  audit_read <- utils::read.csv(audit_path, stringsAsFactors = FALSE)
  identical(names(audit_read), g5_required_audit_columns()) &&
    !("X" %in% names(audit_read)) &&
    identical(audit_read$requested_symbols, paste(validation_symbols, collapse = ","))
}, paste("audit:", normalizePath(audit_path, winslash = "/", mustWork = FALSE)))

pass_fail("refresh artifact CSVs are written under runs/validation", {
  g5_write_refresh_plan_artifact_csv(refresh$plan, refresh_plan_path)
  g5_write_cache_merge_summary_artifact_csv(incremental_write$summary, merge_summary_path)
  plan_read <- utils::read.csv(refresh_plan_path, stringsAsFactors = FALSE)
  merge_read <- utils::read.csv(merge_summary_path, stringsAsFactors = FALSE)
  identical(
    names(plan_read),
    c(
      "symbol",
      "cache_path",
      "cache_file_exists",
      "cached_row_count",
      "first_cached_session",
      "latest_cached_session",
      "requested_start_date",
      "requested_end_date",
      "needs_fetch",
      "refresh_decision",
      "fetch_start_date",
      "fetch_end_date"
    )
  ) &&
    identical(
      names(merge_read),
      c(
        "symbol",
        "cache_path",
        "refresh_decision",
        "needs_fetch",
        "returned_bar_count",
        "merged_row_count",
        "first_merged_session",
        "latest_merged_session",
        "no_returned_bars",
        "wrote_cache"
      )
    ) &&
    identical(plan_read$symbol, sort(plan_read$symbol)) &&
    identical(merge_read$symbol, sort(merge_read$symbol))
}, paste("plan:", normalizePath(refresh_plan_path, winslash = "/", mustWork = FALSE)))

pass_fail("symbol coverage inspection artifacts are written under runs/validation", {
  symbol_coverage <- g5_symbol_coverage_artifact(
    bars = cache_read$bars,
    requested_symbols = validation_symbols,
    latest_completed_session = resolved$latest_completed_session,
    requested_start_date = date_range$requested_start_date,
    requested_end_date = date_range$requested_end_date,
    cache_refresh_plan = refresh$plan,
    cache_refresh_result = incremental_write$summary
  )
  g5_write_symbol_coverage_artifact_csv(symbol_coverage, symbol_coverage_path)
  g5_write_symbol_coverage_chart(symbol_coverage, symbol_coverage_chart_path)
  coverage_read <- utils::read.csv(symbol_coverage_path, stringsAsFactors = FALSE)
  dia <- coverage_read[coverage_read$symbol == "DIA", , drop = FALSE]
  empty <- coverage_read[coverage_read$symbol == "EMPTY", , drop = FALSE]
  spy <- coverage_read[coverage_read$symbol == "SPY", , drop = FALSE]
  all(c(
    "symbol",
    "requested_start_date",
    "requested_end_date",
    "observed_first_session",
    "observed_latest_session",
    "row_count",
    "empty_status",
    "partial_history_status",
    "stale_status"
  ) %in% names(coverage_read)) &&
    nrow(coverage_read) == length(validation_symbols) &&
    identical(coverage_read$symbol, validation_symbols) &&
    identical(spy$partial_history_status, "covers_requested_range") &&
    identical(dia$partial_history_status, "partial_history") &&
    identical(dia$stale_status, "stale") &&
    identical(empty$empty_status, "empty") &&
    identical(empty$partial_history_status, "empty") &&
    file.exists(symbol_coverage_chart_path)
}, paste("coverage:", normalizePath(symbol_coverage_path, winslash = "/", mustWork = FALSE)))

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
