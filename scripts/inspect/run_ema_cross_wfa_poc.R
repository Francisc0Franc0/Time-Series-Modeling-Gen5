# Gen5.1 one-fold EMA cross WFA proof of concept.

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
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))

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
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for EMA WFA POC.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbol_env <- Sys.getenv("GEN5_WFA_SYMBOL", unset = "")
if (!nzchar(symbol_env)) {
  g5_stop("GEN5_WFA_SYMBOL is required for EMA WFA POC.")
}
symbol <- g5_standardize_symbol(trimws(strsplit(symbol_env, ",", fixed = TRUE)[[1L]]))
if (length(symbol) != 1L) {
  g5_stop("GEN5_WFA_SYMBOL must contain exactly one symbol.")
}

end_env <- Sys.getenv("GEN5_WFA_END_DATE", unset = "")
if (!nzchar(end_env)) {
  g5_stop("GEN5_WFA_END_DATE is required.")
}
wfa_end_date <- as.Date(end_env)
if (is.na(wfa_end_date)) {
  g5_stop("GEN5_WFA_END_DATE could not be parsed as a date.")
}

start_env <- Sys.getenv("GEN5_WFA_START_DATE", unset = "")
lookback_env <- Sys.getenv("GEN5_WFA_LOOKBACK_DAYS", unset = "1065")
if (nzchar(start_env)) {
  wfa_start_date <- as.Date(start_env)
  if (is.na(wfa_start_date)) {
    g5_stop("GEN5_WFA_START_DATE could not be parsed as a date.")
  }
} else {
  lookback_days <- suppressWarnings(as.integer(lookback_env))
  if (is.na(lookback_days) || lookback_days < 1L) {
    g5_stop("GEN5_WFA_LOOKBACK_DAYS must be a positive integer.")
  }
  wfa_start_date <- wfa_end_date - lookback_days
}
if (wfa_start_date > wfa_end_date) {
  g5_stop("EMA WFA start date cannot be after end date.")
}

train_quarters <- suppressWarnings(as.numeric(Sys.getenv("GEN5_WFA_TRAIN_QUARTERS", unset = "8")))
train_quarters <- g5_ema_cross_wfa_validate_quarters(train_quarters, "GEN5_WFA_TRAIN_QUARTERS")
oos_quarters <- suppressWarnings(as.numeric(Sys.getenv("GEN5_WFA_OOS_QUARTERS", unset = "1")))
oos_quarters <- g5_ema_cross_wfa_validate_quarters(oos_quarters, "GEN5_WFA_OOS_QUARTERS")
fast_periods <- g5_parse_int_list_env(Sys.getenv("GEN5_WFA_FAST_PERIODS", unset = "8,12,20"), "GEN5_WFA_FAST_PERIODS")
slow_periods <- g5_parse_int_list_env(Sys.getenv("GEN5_WFA_SLOW_PERIODS", unset = "30,50,80,120"), "GEN5_WFA_SLOW_PERIODS")
if (!any(outer(fast_periods, slow_periods, FUN = "<"))) {
  g5_stop("EMA WFA grid must include at least one fast_period < slow_period pair.")
}
refresh <- g5_parse_bool_env(Sys.getenv("GEN5_WFA_REFRESH", unset = ""), default = FALSE)

warmup_days <- max(slow_periods) * 4L
query_start_date <- wfa_start_date - warmup_days

message("Gen5 EMA cross one-fold WFA POC")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Symbol: ", symbol)
message("WFA window: ", as.character(wfa_start_date), " to ", as.character(wfa_end_date))
message("Query window with EMA warmup: ", as.character(query_start_date), " to ", as.character(wfa_end_date))
message("As of: ", as.character(as_of_timestamp))
message("Train quarters: ", train_quarters, " (", g5_ema_cross_wfa_quarters_to_days(train_quarters), " days)")
message("OOS quarters: ", oos_quarters, " (", g5_ema_cross_wfa_quarters_to_days(oos_quarters), " days)")
message("Fast periods: ", paste(fast_periods, collapse = ", "))
message("Slow periods: ", paste(slow_periods, collapse = ", "))
message("Leverage: 1x")
message("Refresh: ", refresh)
message("POC only: this is one train/OOS fold, not multi-fold WFA evidence, live advice, or a deployable strategy.")

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start_date,
  end_date = wfa_end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = paste0("ema_cross_wfa_poc_", symbol),
  universe_roles = "research_universe",
  refresh = refresh,
  repo_root = repo_root
)

g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
output_dir <- g5_ema_cross_wfa_output_dir(
  repo_root,
  result$resolved_session$as_of_timestamp,
  symbol,
  wfa_start_date = wfa_start_date,
  wfa_end_date = wfa_end_date
)
written <- g5_write_ema_cross_wfa_outputs(
  result,
  symbol = symbol,
  output_dir = output_dir,
  wfa_start_date = wfa_start_date,
  wfa_end_date = wfa_end_date,
  fast_periods = fast_periods,
  slow_periods = slow_periods,
  train_quarters = train_quarters,
  oos_quarters = oos_quarters
)

fold <- written$fold
selected <- written$train_selected
metrics <- written$oos_metrics
top <- written$train_parameter_performance[
  seq_len(min(10L, nrow(written$train_parameter_performance))),
  c("fast_period", "slow_period", "sharpe", "total_return", "cagr", "max_drawdown", "trade_count", "exposure_fraction"),
  drop = FALSE
]

message("")
message("Resolved fold:")
message("  Train: ", as.character(fold$train_start_date[[1L]]), " to ", as.character(fold$train_end_date[[1L]]), " (", fold$train_session_count[[1L]], " sessions)")
message("  OOS: ", as.character(fold$oos_start_date[[1L]]), " to ", as.character(fold$oos_end_date[[1L]]), " (", fold$oos_session_count[[1L]], " sessions)")
message("  Final train-close signal may execute at first OOS open: yes")
message("")
message("Train-selected parameters:")
message("  Fast EMA: ", selected$fast_period[[1L]])
message("  Slow EMA: ", selected$slow_period[[1L]])
message("  Train Sharpe: ", g5_fmt_num(selected$sharpe[[1L]]))
message("  Train return: ", g5_fmt_pct(selected$total_return[[1L]]))
message("")
message("OOS performance:")
message("  OOS Sharpe: ", g5_fmt_num(metrics$sharpe[[1L]]))
message("  OOS total return: ", g5_fmt_pct(metrics$total_return[[1L]]))
message("  OOS CAGR: ", g5_fmt_pct(metrics$cagr[[1L]]))
message("  OOS max drawdown: ", g5_fmt_pct(metrics$max_drawdown[[1L]]))
message("  OOS time underwater: ", metrics$underwater_session_count[[1L]], " sessions / ", g5_fmt_pct(metrics$underwater_fraction[[1L]]))
message("  OOS trades: ", metrics$trade_count[[1L]])
message("  OOS buy-and-hold return: ", g5_fmt_pct(metrics$buy_hold_total_return[[1L]]))
message("")
message("Top train parameter rows, sorted by Sharpe then return:")
print(top, row.names = FALSE)
message("")
message("Key outputs:")
message("  Train parameter performance CSV: ", written$paths$train_parameter_performance_csv)
message("  OOS strategy chart: ", written$paths$oos_strategy_chart_png)
message("  OOS equity curve: ", written$paths$oos_equity_curve_png)
message("  OOS metrics: ", written$paths$oos_metrics_md)
message("")
message("Data health:")
g5_print_data_health_report(result$health)
message("")
message("Wrote EMA cross WFA POC packet:")
for (nm in names(written$paths)) {
  message("  ", nm, ": ", written$paths[[nm]])
}
