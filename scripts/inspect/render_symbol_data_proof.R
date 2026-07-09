# Gen5.1 one-symbol data proof packet.

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
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "workbench_data_proof.R"))

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = "")
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for symbol data proof.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbol_env <- Sys.getenv("GEN5_DATA_PROOF_SYMBOL", unset = Sys.getenv("GEN5_CHART_SYMBOL", unset = ""))
if (!nzchar(symbol_env)) {
  g5_stop("GEN5_DATA_PROOF_SYMBOL is required for symbol data proof.")
}
symbol <- g5_standardize_symbol(trimws(strsplit(symbol_env, ",", fixed = TRUE)[[1L]]))
if (length(symbol) != 1L) {
  g5_stop("GEN5_DATA_PROOF_SYMBOL must contain exactly one symbol.")
}

start_env <- Sys.getenv("GEN5_DATA_PROOF_START_DATE", unset = Sys.getenv("GEN5_CHART_START_DATE", unset = ""))
end_env <- Sys.getenv("GEN5_DATA_PROOF_END_DATE", unset = Sys.getenv("GEN5_CHART_END_DATE", unset = ""))
lookback_env <- Sys.getenv("GEN5_DATA_PROOF_LOOKBACK_DAYS", unset = "")
if (!nzchar(end_env)) {
  g5_stop("GEN5_DATA_PROOF_END_DATE is required.")
}
end_date <- as.Date(end_env)
if (is.na(end_date)) {
  g5_stop("GEN5_DATA_PROOF_END_DATE could not be parsed as a date.")
}
if (nzchar(start_env)) {
  start_date <- as.Date(start_env)
  if (is.na(start_date)) {
    g5_stop("GEN5_DATA_PROOF_START_DATE could not be parsed as a date.")
  }
} else if (nzchar(lookback_env)) {
  lookback_days <- suppressWarnings(as.integer(lookback_env))
  if (is.na(lookback_days) || lookback_days < 1L) {
    g5_stop("GEN5_DATA_PROOF_LOOKBACK_DAYS must be a positive integer when supplied.")
  }
  start_date <- end_date - lookback_days
} else {
  g5_stop("Provide GEN5_DATA_PROOF_START_DATE or GEN5_DATA_PROOF_LOOKBACK_DAYS.")
}

refresh <- g5_parse_bool_env(Sys.getenv("GEN5_DATA_PROOF_REFRESH", unset = ""), default = FALSE)

message("Gen5 symbol data proof")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Symbol: ", symbol)
message("Requested: ", as.character(start_date), " to ", as.character(end_date))
message("As of: ", as.character(as_of_timestamp))
message("Refresh: ", refresh)

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = start_date,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = paste0("single_symbol_data_proof_", symbol),
  universe_roles = "research_universe",
  refresh = refresh,
  repo_root = repo_root
)

g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
output_dir <- g5_data_proof_output_dir(repo_root, result$resolved_session$as_of_timestamp, symbol)
written <- g5_write_symbol_data_proof_outputs(result, symbol = symbol, output_dir = output_dir)

message("")
message("Summary:")
summary <- written$summary
message("  Latest completed session: ", as.character(summary$latest_completed_session[[1L]]))
message("  Rows: ", summary$row_count[[1L]])
message(
  "  Observed: ",
  as.character(summary$observed_start_date[[1L]]),
  " to ",
  as.character(summary$observed_end_date[[1L]])
)
message("  Health max severity: ", summary$health_max_severity[[1L]])
message("  Chart: ", summary$candlestick_png[[1L]])
message("  Summary: ", written$paths$summary_md)
message("")
message("Data health:")
g5_print_data_health_report(result$health)
message("")
message("Wrote data proof packet:")
for (nm in names(written$paths)) {
  message("  ", nm, ": ", written$paths[[nm]])
}
