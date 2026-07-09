# Gen5.1 multi-signal WFA proof of concept.

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
source(file.path(repo_root, "R", "strategy_bollinger_touch.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))

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

g5_parse_num_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive numbers."))
  }
  raw <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  raw <- raw[nzchar(raw)]
  parsed <- suppressWarnings(as.numeric(raw))
  if (length(parsed) == 0L || any(is.na(parsed)) || any(parsed <= 0)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive numbers."))
  }
  sort(unique(parsed))
}

g5_parse_character_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list."))
  }
  raw <- unique(trimws(strsplit(value, ",", fixed = TRUE)[[1L]]))
  raw <- raw[nzchar(raw)]
  if (length(raw) == 0L) {
    g5_stop(paste0(label, " must be a comma-separated list."))
  }
  raw
}

g5_fmt_pct <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
}

g5_fmt_num <- function(x) {
  ifelse(is.na(x), "NA", ifelse(is.infinite(x), "Inf", sprintf("%.3f", as.numeric(x))))
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_WFA_MULTI_AS_OF_TIMESTAMP", unset = Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = ""))
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for multi-signal WFA.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbol_env <- Sys.getenv("GEN5_WFA_MULTI_SYMBOL", unset = "")
if (!nzchar(symbol_env)) {
  g5_stop("GEN5_WFA_MULTI_SYMBOL is required for multi-signal WFA.")
}
symbol <- g5_standardize_symbol(trimws(strsplit(symbol_env, ",", fixed = TRUE)[[1L]]))
if (length(symbol) != 1L) {
  g5_stop("GEN5_WFA_MULTI_SYMBOL must contain exactly one symbol.")
}

end_env <- Sys.getenv("GEN5_WFA_MULTI_END_DATE", unset = "")
if (!nzchar(end_env)) {
  g5_stop("GEN5_WFA_MULTI_END_DATE is required.")
}
wfa_end_date <- as.Date(end_env)
if (is.na(wfa_end_date)) {
  g5_stop("GEN5_WFA_MULTI_END_DATE could not be parsed as a date.")
}

train_quarters <- g5_ema_cross_wfa_validate_quarters(
  suppressWarnings(as.numeric(Sys.getenv("GEN5_WFA_MULTI_TRAIN_QUARTERS", unset = "8"))),
  "GEN5_WFA_MULTI_TRAIN_QUARTERS"
)
oos_quarters <- g5_ema_cross_wfa_validate_quarters(
  suppressWarnings(as.numeric(Sys.getenv("GEN5_WFA_MULTI_OOS_QUARTERS", unset = "1"))),
  "GEN5_WFA_MULTI_OOS_QUARTERS"
)
fold_count <- suppressWarnings(as.integer(Sys.getenv("GEN5_WFA_MULTI_FOLD_COUNT", unset = "3")))
if (is.na(fold_count) || fold_count < 1L) {
  g5_stop("GEN5_WFA_MULTI_FOLD_COUNT must be a positive integer.")
}

start_env <- Sys.getenv("GEN5_WFA_MULTI_START_DATE", unset = "")
lookback_env <- Sys.getenv("GEN5_WFA_MULTI_LOOKBACK_DAYS", unset = "")
if (nzchar(start_env)) {
  wfa_start_date <- as.Date(start_env)
  if (is.na(wfa_start_date)) {
    g5_stop("GEN5_WFA_MULTI_START_DATE could not be parsed as a date.")
  }
} else if (nzchar(lookback_env)) {
  lookback_days <- suppressWarnings(as.integer(lookback_env))
  if (is.na(lookback_days) || lookback_days < 1L) {
    g5_stop("GEN5_WFA_MULTI_LOOKBACK_DAYS must be a positive integer when supplied.")
  }
  wfa_start_date <- wfa_end_date - lookback_days
} else {
  wfa_start_date <- wfa_end_date - (g5_ema_cross_wfa_quarters_to_days(train_quarters) + fold_count * g5_ema_cross_wfa_quarters_to_days(oos_quarters) + 2L)
}
if (wfa_start_date > wfa_end_date) {
  g5_stop("Multi-signal WFA start date cannot be after end date.")
}

fast_periods <- g5_parse_int_list_env(Sys.getenv("GEN5_WFA_MULTI_FAST_PERIODS", unset = "8,12,20"), "GEN5_WFA_MULTI_FAST_PERIODS")
slow_periods <- g5_parse_int_list_env(Sys.getenv("GEN5_WFA_MULTI_SLOW_PERIODS", unset = "30,50,80,120"), "GEN5_WFA_MULTI_SLOW_PERIODS")
if (!any(outer(fast_periods, slow_periods, FUN = "<"))) {
  g5_stop("Multi-signal WFA EMA grid must include at least one fast_period < slow_period pair.")
}
bb_lookback_periods <- g5_parse_int_list_env(Sys.getenv("GEN5_WFA_MULTI_BB_LOOKBACK_PERIODS", unset = "10,20,30"), "GEN5_WFA_MULTI_BB_LOOKBACK_PERIODS")
bb_sd_multipliers <- g5_parse_num_list_env(Sys.getenv("GEN5_WFA_MULTI_BB_SD_MULTIPLIERS", unset = "1.5,2,2.5"), "GEN5_WFA_MULTI_BB_SD_MULTIPLIERS")
candidate_families <- g5_wfa_candidate_families(g5_parse_character_list_env(Sys.getenv("GEN5_WFA_MULTI_CANDIDATE_FAMILIES", unset = "ema_cross,bollinger_touch"), "GEN5_WFA_MULTI_CANDIDATE_FAMILIES"))
max_hold_sessions <- g5_parse_int_list_env(Sys.getenv("GEN5_WFA_MULTI_MAX_HOLD_SESSIONS", unset = "10,20,40"), "GEN5_WFA_MULTI_MAX_HOLD_SESSIONS")
stop_loss_pcts <- g5_parse_num_list_env(Sys.getenv("GEN5_WFA_MULTI_STOP_LOSS_PCTS", unset = "0.10"), "GEN5_WFA_MULTI_STOP_LOSS_PCTS")
take_profit_pcts <- g5_parse_num_list_env(Sys.getenv("GEN5_WFA_MULTI_TAKE_PROFIT_PCTS", unset = "0.25"), "GEN5_WFA_MULTI_TAKE_PROFIT_PCTS")
refresh <- g5_parse_bool_env(Sys.getenv("GEN5_WFA_MULTI_REFRESH", unset = ""), default = FALSE)

warmup_days <- max(c(slow_periods, bb_lookback_periods)) * 4L
query_start_date <- wfa_start_date - warmup_days

message("Gen5 multi-signal three-fold WFA POC")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Symbol: ", symbol)
message("WFA window: ", as.character(wfa_start_date), " to ", as.character(wfa_end_date))
message("Query window with indicator warmup: ", as.character(query_start_date), " to ", as.character(wfa_end_date))
message("As of: ", as.character(as_of_timestamp))
message("Train quarters: ", train_quarters, " (", g5_ema_cross_wfa_quarters_to_days(train_quarters), " days)")
message("OOS quarters: ", oos_quarters, " (", g5_ema_cross_wfa_quarters_to_days(oos_quarters), " days)")
message("Fold count: ", fold_count)
message("Candidate families: ", paste(candidate_families, collapse = ", "))
message("Fast periods: ", paste(fast_periods, collapse = ", "))
message("Slow periods: ", paste(slow_periods, collapse = ", "))
message("Bollinger lookback periods: ", paste(bb_lookback_periods, collapse = ", "))
message("Bollinger SD multipliers: ", paste(bb_sd_multipliers, collapse = ", "))
message("Exit stack max-hold sessions: ", paste(max_hold_sessions, collapse = ", "))
message("Exit stack stop-loss pcts: ", paste(stop_loss_pcts, collapse = ", "))
message("Exit stack take-profit pcts: ", paste(take_profit_pcts, collapse = ", "))
message("Leverage: 1x")
message("Refresh: ", refresh)
message("POC only: stitched OOS across rolling folds with close-based exit stacks, not final research evidence, live advice, or a deployable strategy.")

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start_date,
  end_date = wfa_end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = paste0("multi_signal_wfa_poc_", symbol),
  universe_roles = "research_universe",
  refresh = refresh,
  repo_root = repo_root
)

g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
output_dir <- g5_ema_cross_wfa_multi_output_dir(repo_root, result$resolved_session$as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count, candidate_families)
written <- g5_write_ema_cross_wfa_multi_outputs(
  result,
  symbol = symbol,
  output_dir = output_dir,
  wfa_start_date = wfa_start_date,
  wfa_end_date = wfa_end_date,
  fast_periods = fast_periods,
  slow_periods = slow_periods,
  bb_lookback_periods = bb_lookback_periods,
  bb_sd_multipliers = bb_sd_multipliers,
  candidate_families = candidate_families,
  max_hold_sessions = max_hold_sessions,
  stop_loss_pcts = stop_loss_pcts,
  take_profit_pcts = take_profit_pcts,
  train_quarters = train_quarters,
  oos_quarters = oos_quarters,
  fold_count = fold_count
)

metrics <- written$stitched_metrics
message("")
message("Resolved folds:")
print(written$folds[, c("fold_id", "train_start_date", "train_end_date", "oos_start_date", "oos_end_date", "oos_session_count")], row.names = FALSE)
cat("\nFold-selected model instances:\n")
print(written$selected_models[, c("fold_id", "strategy_family", "model_instance_id", "exit_stack_id", "strategy_spec_id", "train_sharpe", "train_total_return")], row.names = FALSE)
message("")
message("Stitched OOS performance:")
message("  Return: ", g5_fmt_pct(metrics$total_return[[1L]]))
message("  Sharpe: ", g5_fmt_num(metrics$sharpe[[1L]]))
message("  Max drawdown: ", g5_fmt_pct(metrics$max_drawdown[[1L]]))
message("  Trades: ", metrics$trade_count[[1L]])
message("  Carried trades: ", metrics$carried_trade_count[[1L]])
message("  Native exits: ", metrics$native_exit_count[[1L]])
message("  Exit-stack exits: ", metrics$exit_stack_exit_count[[1L]])
message("  Buy-and-hold return: ", g5_fmt_pct(metrics$buy_hold_total_return[[1L]]))
message("")
message("Strategy spec stability:")
print(written$model_stability[, c("strategy_spec_id", "selected_fold_count", "selected_fold_fraction", "selected_folds")], row.names = FALSE)
message("")
message("Key outputs:")
message("  Fold spec CSV: ", written$paths$fold_spec_csv)
message("  Selected models CSV: ", written$paths$selected_models_csv)
message("  Exit stacks CSV: ", written$paths$exit_stacks_csv)
message("  Stitched strategy chart: ", written$paths$stitched_strategy_chart_png)
message("  Stitched equity curve: ", written$paths$stitched_equity_curve_png)
message("  Stitched metrics: ", written$paths$stitched_metrics_md)
message("")
message("Data health:")
g5_print_data_health_report(result$health)
message("")
message("Wrote multi-signal WFA packet:")
for (nm in names(written$paths)) {
  message("  ", nm, ": ", written$paths[[nm]])
}
