# Gen5 Alpaca adjusted daily data-refresh smoke path.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

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

request <- g5_alpaca_daily_adjusted_request(
  symbols = symbols,
  start_date = start_date,
  end_date = resolved$latest_completed_session,
  as_of_timestamp = resolved$as_of_timestamp,
  latest_completed_session = resolved$latest_completed_session,
  feed = cfg$feed
)
print(request)

bars <- g5_fetch_alpaca_daily_adjusted_bars(request)
message("Fetched canonical rows: ", nrow(bars))

cache_root <- cfg$cache$root
written <- g5_write_bars_cache(bars, cache_root = cache_root)
message("Wrote cache files:")
print(written)

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
  provider_query_timestamp = resolved$as_of_timestamp,
  cache_hits = cache_read$cache_hit_symbols,
  cache_misses = cache_read$cache_missing_symbols
)
print(audit)

audit_dir <- file.path(repo_root, "runs", "data_refresh")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
audit_path <- file.path(
  audit_dir,
  paste0("alpaca_daily_audit_", format(as.Date(resolved$latest_completed_session), "%Y%m%d"), ".csv")
)
utils::write.csv(audit, audit_path, row.names = FALSE)
message("Wrote audit: ", audit_path)
