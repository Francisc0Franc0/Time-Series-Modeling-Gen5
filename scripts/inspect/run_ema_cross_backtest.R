# Gen5.1 EMA cross in-sample backtest proof.

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
source(file.path(repo_root, "R", "strategy_ema_cross.R"))

g5_parse_int_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive integers."))
  }
  raw <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  raw <- raw[nzchar(raw)]
  parsed <- suppressWarnings(as.integer(raw))
  if (length(parsed) == 0L || any(is.na(parsed)) || any(parsed < 1L)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive integers."))
  }
  sort(unique(parsed))
}

g5_fmt_pct <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
}

g5_fmt_num <- function(x) {
  ifelse(is.na(x), "NA", ifelse(is.infinite(x), "Inf", sprintf("%.3f", as.numeric(x))))
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = "")
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for EMA cross backtest.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbol_env <- Sys.getenv("GEN5_EMA_CROSS_SYMBOL", unset = "")
if (!nzchar(symbol_env)) {
  g5_stop("GEN5_EMA_CROSS_SYMBOL is required for EMA cross backtest.")
}
symbol <- g5_standardize_symbol(trimws(strsplit(symbol_env, ",", fixed = TRUE)[[1L]]))
if (length(symbol) != 1L) {
  g5_stop("GEN5_EMA_CROSS_SYMBOL must contain exactly one symbol.")
}

end_env <- Sys.getenv("GEN5_EMA_CROSS_END_DATE", unset = "")
if (!nzchar(end_env)) {
  g5_stop("GEN5_EMA_CROSS_END_DATE is required.")
}
trading_end_date <- as.Date(end_env)
if (is.na(trading_end_date)) {
  g5_stop("GEN5_EMA_CROSS_END_DATE could not be parsed as a date.")
}

start_env <- Sys.getenv("GEN5_EMA_CROSS_START_DATE", unset = "")
window_days_env <- Sys.getenv("GEN5_EMA_CROSS_TRADING_WINDOW_DAYS", unset = "730")
if (nzchar(start_env)) {
  trading_start_date <- as.Date(start_env)
  if (is.na(trading_start_date)) {
    g5_stop("GEN5_EMA_CROSS_START_DATE could not be parsed as a date.")
  }
} else {
  window_days <- suppressWarnings(as.integer(window_days_env))
  if (is.na(window_days) || window_days < 1L) {
    g5_stop("GEN5_EMA_CROSS_TRADING_WINDOW_DAYS must be a positive integer.")
  }
  trading_start_date <- trading_end_date - window_days
}
if (trading_start_date > trading_end_date) {
  g5_stop("EMA cross trading start date cannot be after end date.")
}

fast_periods <- g5_parse_int_list_env(Sys.getenv("GEN5_EMA_CROSS_FAST_PERIODS", unset = "8,12,20"), "GEN5_EMA_CROSS_FAST_PERIODS")
slow_periods <- g5_parse_int_list_env(Sys.getenv("GEN5_EMA_CROSS_SLOW_PERIODS", unset = "30,50,80,120"), "GEN5_EMA_CROSS_SLOW_PERIODS")
if (!any(outer(fast_periods, slow_periods, FUN = "<"))) {
  g5_stop("EMA cross grid must include at least one fast_period < slow_period pair.")
}

leverage <- suppressWarnings(as.numeric(Sys.getenv("GEN5_EMA_CROSS_LEVERAGE", unset = "1")))
leverage <- g5_ema_cross_validate_leverage(leverage)
refresh <- g5_parse_bool_env(Sys.getenv("GEN5_EMA_CROSS_REFRESH", unset = ""), default = FALSE)

warmup_days <- max(slow_periods) * 4L
query_start_date <- trading_start_date - warmup_days

message("Gen5 EMA cross in-sample backtest proof")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Symbol: ", symbol)
message("Trading window: ", as.character(trading_start_date), " to ", as.character(trading_end_date))
message("Query window with EMA warmup: ", as.character(query_start_date), " to ", as.character(trading_end_date))
message("As of: ", as.character(as_of_timestamp))
message("Fast periods: ", paste(fast_periods, collapse = ", "))
message("Slow periods: ", paste(slow_periods, collapse = ", "))
message("Leverage: ", leverage, "x")
message("Refresh: ", refresh)
message("Diagnostic only: this is pure in-sample backtest output, not WFA/OOS evidence, live advice, or a deployable strategy.")

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start_date,
  end_date = trading_end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = paste0("ema_cross_backtest_", symbol),
  universe_roles = "research_universe",
  refresh = refresh,
  repo_root = repo_root
)

g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
output_dir <- g5_ema_cross_output_dir(repo_root, result$resolved_session$as_of_timestamp, symbol, leverage = leverage)
written <- g5_write_ema_cross_outputs(
  result,
  symbol = symbol,
  output_dir = output_dir,
  trading_start_date = trading_start_date,
  trading_end_date = trading_end_date,
  fast_periods = fast_periods,
  slow_periods = slow_periods,
  leverage = leverage
)

selected <- written$selected
metrics <- written$selected_metrics
top <- written$parameter_performance[
  seq_len(min(10L, nrow(written$parameter_performance))),
  c("fast_period", "slow_period", "sharpe", "total_return", "cagr", "max_drawdown", "trade_count", "exposure_fraction"),
  drop = FALSE
]

message("")
message("Selected parameters:")
message("  Fast EMA: ", selected$fast_period[[1L]])
message("  Slow EMA: ", selected$slow_period[[1L]])
message("  Sharpe: ", g5_fmt_num(metrics$sharpe[[1L]]))
message("  Total return: ", g5_fmt_pct(metrics$total_return[[1L]]))
message("  CAGR: ", g5_fmt_pct(metrics$cagr[[1L]]))
message("  Max drawdown: ", g5_fmt_pct(metrics$max_drawdown[[1L]]))
message("  Time underwater: ", metrics$underwater_session_count[[1L]], " sessions / ", g5_fmt_pct(metrics$underwater_fraction[[1L]]))
message("  Trades: ", metrics$trade_count[[1L]])
message("  Buy-and-hold return: ", g5_fmt_pct(metrics$buy_hold_total_return[[1L]]))
message("  Buy-and-hold Sharpe: ", g5_fmt_num(metrics$buy_hold_sharpe[[1L]]))
message("")
message("Top parameter rows, sorted by Sharpe then return:")
print(top, row.names = FALSE)
message("")
message("Key outputs:")
message("  Parameter performance CSV: ", written$paths$parameter_performance_csv)
message("  Selected strategy chart: ", written$paths$selected_strategy_chart_png)
message("  Selected equity curve: ", written$paths$selected_equity_curve_png)
message("  Selected metrics: ", written$paths$selected_metrics_md)
message("")
message("Data health:")
g5_print_data_health_report(result$health)
message("")
message("Wrote EMA cross backtest packet:")
for (nm in names(written$paths)) {
  message("  ", nm, ": ", written$paths[[nm]])
}
