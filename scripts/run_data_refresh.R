# Gen5 Alpaca adjusted daily data-refresh smoke path.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "cache_store.R"))

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

timezone <- cfg$calendar$timezone
as_of_env <- Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = "")
as_of_timestamp <- if (nzchar(as_of_env)) {
  as.POSIXct(as_of_env, tz = timezone)
} else {
  Sys.time()
}
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

resolved <- g5_resolve_latest_completed_session(
  as_of_timestamp = as_of_timestamp,
  timezone = timezone,
  market_close_time = cfg$calendar$market_close_time
)
print(resolved)

symbols <- cfg$symbols
start_env <- Sys.getenv("GEN5_FETCH_START_DATE", unset = "")
start_date <- if (nzchar(start_env)) {
  as.Date(start_env)
} else {
  as.Date(resolved$latest_completed_session) - 120L
}
if (is.na(start_date)) {
  g5_stop("GEN5_FETCH_START_DATE could not be parsed as a date.")
}
end_env <- Sys.getenv("GEN5_FETCH_END_DATE", unset = "")
requested_end_date <- if (nzchar(end_env)) {
  as.Date(end_env)
} else {
  as.Date(resolved$latest_completed_session)
}
if (is.na(requested_end_date)) {
  g5_stop("GEN5_FETCH_END_DATE could not be parsed as a date.")
}

date_range <- g5_alpaca_resolve_daily_date_range(
  start_date = start_date,
  end_date = requested_end_date,
  latest_completed_session = resolved$latest_completed_session
)
print(date_range)

request <- g5_alpaca_daily_adjusted_request(
  symbols = symbols,
  start_date = date_range$fetch_start_date,
  end_date = date_range$fetch_end_date,
  as_of_timestamp = resolved$as_of_timestamp,
  latest_completed_session = resolved$latest_completed_session,
  feed = cfg$feed
)
print(request)

artifact_dir <- file.path(repo_root, "runs", "data_refresh")
dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)
artifact_date <- format(as.Date(resolved$latest_completed_session), "%Y%m%d")
refresh_plan_path <- file.path(
  artifact_dir,
  paste0("alpaca_daily_refresh_plan_", artifact_date, ".csv")
)
merge_summary_path <- file.path(
  artifact_dir,
  paste0("alpaca_daily_merge_summary_", artifact_date, ".csv")
)
symbol_coverage_path <- file.path(
  artifact_dir,
  paste0("alpaca_daily_symbol_coverage_", artifact_date, ".csv")
)

cache_root <- cfg$cache$root
cache_root <- g5_require_writable_cache_root(cache_root)
message("Using cache root: ", cache_root)
refresh <- g5_plan_incremental_cache_refresh(
  symbols = symbols,
  cache_root = cache_root,
  requested_start_date = date_range$fetch_start_date,
  requested_end_date = date_range$fetch_end_date,
  latest_completed_session = resolved$latest_completed_session
)
message("Incremental cache refresh plan:")
print(refresh$plan)
g5_write_refresh_plan_artifact_csv(refresh$plan, refresh_plan_path)
message("Wrote refresh plan artifact: ", refresh_plan_path)

fetch_frames <- list()
fetch_rows <- refresh$plan[refresh$plan$needs_fetch, , drop = FALSE]
if (nrow(fetch_rows) == 0L) {
  bars <- g5_empty_bar_data()
  message("Requested range is already fully cached; no Alpaca fetch required.")
} else {
  alpaca_cfg <- g5_alpaca_config_from_env()
  g5_alpaca_preflight_live_fetch(alpaca_cfg)
  message(
    "Alpaca live fetch preflight passed for feed=",
    cfg$feed,
    "; requested fetch symbols=",
    paste(fetch_rows$symbol, collapse = ",")
  )
  for (i in seq_len(nrow(fetch_rows))) {
    symbol_request <- g5_alpaca_daily_adjusted_request(
      symbols = fetch_rows$symbol[[i]],
      start_date = fetch_rows$fetch_start_date[[i]],
      end_date = fetch_rows$fetch_end_date[[i]],
      as_of_timestamp = resolved$as_of_timestamp,
      latest_completed_session = resolved$latest_completed_session,
      feed = cfg$feed
    )
    symbol_bars <- g5_fetch_alpaca_daily_adjusted_bars(symbol_request, config = alpaca_cfg)
    fetch_frames[[fetch_rows$symbol[[i]]]] <- symbol_bars
    message("Fetched canonical rows for ", fetch_rows$symbol[[i]], ": ", nrow(symbol_bars))
  }
  bars <- if (length(fetch_frames) == 0L) {
    g5_empty_bar_data()
  } else {
    g5_validate_bar_data(do.call(rbind, fetch_frames))
  }
}
message("Fetched canonical rows: ", nrow(bars))

written <- g5_write_incremental_bars_cache(
  fetched_bars = bars,
  cache_root = cache_root,
  refresh_plan = refresh$plan
)
message("Incremental cache merge/write summary:")
print(written$summary)
g5_write_cache_merge_summary_artifact_csv(written$summary, merge_summary_path)
message("Wrote merge summary artifact: ", merge_summary_path)

cache_read <- g5_read_bars_cache(
  symbols,
  cache_root = cache_root,
  require_all = FALSE,
  return_metadata = TRUE
)
read_back <- cache_read$bars
message("Read cache rows: ", nrow(read_back))
if (length(cache_read$cache_missing_symbols) > 0L) {
  message("Missing cache symbols: ", paste(cache_read$cache_missing_symbols, collapse = ", "))
}

audit <- g5_audit_bars(
  bars = read_back,
  requested_symbols = symbols,
  latest_completed_session = resolved$latest_completed_session,
  requested_start_date = date_range$requested_start_date,
  requested_end_date = date_range$requested_end_date,
  provider_query_timestamp = resolved$as_of_timestamp,
  cache_hits = cache_read$cache_hit_symbols,
  cache_misses = cache_read$cache_missing_symbols,
  availability_warnings = date_range$date_range_warnings,
  cache_refresh_plan = refresh$plan,
  cache_refresh_result = written$summary
)
print(audit)

audit_path <- file.path(
  artifact_dir,
  paste0("alpaca_daily_audit_", format(as.Date(resolved$latest_completed_session), "%Y%m%d"), ".csv")
)
g5_write_audit_artifact_csv(audit, audit_path)
message("Wrote audit: ", audit_path)

symbol_coverage <- g5_symbol_coverage_artifact(
  bars = read_back,
  requested_symbols = symbols,
  latest_completed_session = resolved$latest_completed_session,
  requested_start_date = date_range$requested_start_date,
  requested_end_date = date_range$requested_end_date,
  cache_refresh_plan = refresh$plan,
  cache_refresh_result = written$summary
)
g5_write_symbol_coverage_artifact_csv(symbol_coverage, symbol_coverage_path)
message("Wrote symbol coverage artifact: ", symbol_coverage_path)
