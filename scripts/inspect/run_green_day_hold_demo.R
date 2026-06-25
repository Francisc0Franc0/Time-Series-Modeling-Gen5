# Gen5.1 green-day hold diagnostic strategy demo.

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
source(file.path(repo_root, "R", "strategy_green_day_hold.R"))

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = "")
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for green-day hold demo.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbol_env <- Sys.getenv("GEN5_GREEN_DAY_HOLD_SYMBOL", unset = "")
if (!nzchar(symbol_env)) {
  g5_stop("GEN5_GREEN_DAY_HOLD_SYMBOL is required for green-day hold demo.")
}
symbol <- g5_standardize_symbol(trimws(strsplit(symbol_env, ",", fixed = TRUE)[[1L]]))
if (length(symbol) != 1L) {
  g5_stop("GEN5_GREEN_DAY_HOLD_SYMBOL must contain exactly one symbol.")
}

hold_env <- Sys.getenv("GEN5_GREEN_DAY_HOLD_SESSIONS", unset = "10")
hold_sessions <- suppressWarnings(as.integer(hold_env))
if (is.na(hold_sessions) || hold_sessions < 1L) {
  g5_stop("GEN5_GREEN_DAY_HOLD_SESSIONS must be a positive integer.")
}

start_env <- Sys.getenv("GEN5_GREEN_DAY_HOLD_START_DATE", unset = "")
end_env <- Sys.getenv("GEN5_GREEN_DAY_HOLD_END_DATE", unset = "")
lookback_env <- Sys.getenv("GEN5_GREEN_DAY_HOLD_LOOKBACK_DAYS", unset = "")
if (!nzchar(end_env)) {
  g5_stop("GEN5_GREEN_DAY_HOLD_END_DATE is required.")
}
end_date <- as.Date(end_env)
if (is.na(end_date)) {
  g5_stop("GEN5_GREEN_DAY_HOLD_END_DATE could not be parsed as a date.")
}
if (nzchar(start_env)) {
  start_date <- as.Date(start_env)
  if (is.na(start_date)) {
    g5_stop("GEN5_GREEN_DAY_HOLD_START_DATE could not be parsed as a date.")
  }
} else if (nzchar(lookback_env)) {
  lookback_days <- suppressWarnings(as.integer(lookback_env))
  if (is.na(lookback_days) || lookback_days < 1L) {
    g5_stop("GEN5_GREEN_DAY_HOLD_LOOKBACK_DAYS must be a positive integer when supplied.")
  }
  start_date <- end_date - lookback_days
} else {
  g5_stop("Provide GEN5_GREEN_DAY_HOLD_START_DATE or GEN5_GREEN_DAY_HOLD_LOOKBACK_DAYS.")
}

refresh <- g5_parse_bool_env(Sys.getenv("GEN5_GREEN_DAY_HOLD_REFRESH", unset = ""), default = FALSE)

message("Gen5 green-day hold diagnostic strategy demo")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Symbol: ", symbol)
message("Requested: ", as.character(start_date), " to ", as.character(end_date))
message("As of: ", as.character(as_of_timestamp))
message("Hold sessions: ", hold_sessions)
message("Refresh: ", refresh)
message("Diagnostic only: this is not WFA evidence, live advice, or a deployable strategy.")

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = start_date,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = paste0("green_day_hold_demo_", symbol),
  universe_roles = "research_universe",
  refresh = refresh,
  repo_root = repo_root
)

g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
output_dir <- g5_green_day_hold_output_dir(repo_root, result$resolved_session$as_of_timestamp, symbol, hold_sessions)
written <- g5_write_green_day_hold_outputs(result, symbol = symbol, output_dir = output_dir, hold_sessions = hold_sessions)

metrics <- written$metrics
pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))

message("")
message("Summary:")
message("  Latest completed session: ", as.character(result$resolved_session$latest_completed_session))
message("  Rows: ", nrow(g5_green_day_hold_prepare_bars(result$bars, symbol)))
message("  Trades: ", metrics$trade_count[[1L]])
message("  Closed trades: ", metrics$closed_trade_count[[1L]])
message("  Open trades: ", metrics$open_trade_count[[1L]])
message("  Win rate: ", pct(metrics$win_rate[[1L]]))
message("  Compounded closed return: ", pct(metrics$compounded_closed_return[[1L]]))
message("  Compounded marked return: ", pct(metrics$compounded_marked_return[[1L]]))
message("  Strategy chart: ", written$paths$strategy_chart_png)
message("  Metrics: ", written$paths$metrics_md)
message("")
message("Data health:")
g5_print_data_health_report(result$health)
message("")
message("Wrote green-day hold demo packet:")
for (nm in names(written$paths)) {
  message("  ", nm, ": ", written$paths[[nm]])
}
