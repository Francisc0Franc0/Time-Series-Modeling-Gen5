# Gen5.1 portfolio strategy accounting proof of concept.

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
source(file.path(repo_root, "R", "regime_pca_poc.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "portfolio_strategy_poc.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
parse_num_list <- function(name, default) {
  raw <- trimws(strsplit(env_or(name, default), ",", fixed = TRUE)[[1L]])
  raw <- raw[nzchar(raw)]
  out <- suppressWarnings(as.numeric(raw))
  if (!length(out) || any(is.na(out))) g5_stop(paste0(name, " must be a comma-separated numeric list."))
  out
}
parse_int_list <- function(name, default) {
  out <- as.integer(round(parse_num_list(name, default)))
  if (any(is.na(out)) || any(out < 1L)) g5_stop(paste0(name, " must be a comma-separated positive integer list."))
  sort(unique(out))
}
parse_character_list <- function(name, default) {
  raw <- unique(trimws(strsplit(env_or(name, default), ",", fixed = TRUE)[[1L]]))
  raw <- raw[nzchar(raw)]
  if (!length(raw)) g5_stop(paste0(name, " must be a comma-separated list."))
  raw
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

active_symbols <- g5_portfolio_poc_symbols(parse_character_list("GEN5_PORTFOLIO_POC_ACTIVE_SYMBOLS", "AMD,NVDA,TSLA,COIN,MSTR"), "GEN5_PORTFOLIO_POC_ACTIVE_SYMBOLS")
regime_context_symbols <- g5_portfolio_poc_symbols(parse_character_list("GEN5_PORTFOLIO_POC_REGIME_CONTEXT_SYMBOLS", "AMD,NVDA,TSLA,COIN,MSTR,SMH,QQQ,SPY,IWM,TLT,GLD,VXX"), "GEN5_PORTFOLIO_POC_REGIME_CONTEXT_SYMBOLS")
baseline_symbol <- g5_standardize_symbol(env_or("GEN5_PORTFOLIO_POC_BASELINE_SYMBOL", "SPY"))[[1L]]
query_symbols <- unique(c(regime_context_symbols, active_symbols, baseline_symbol))

end_date <- as.Date(env_or("GEN5_PORTFOLIO_POC_END_DATE", ""))
as_of_timestamp <- env_or("GEN5_PORTFOLIO_POC_AS_OF_TIMESTAMP", env_or("GEN5_AS_OF_TIMESTAMP", ""))
if (is.na(end_date)) g5_stop("GEN5_PORTFOLIO_POC_END_DATE must be a valid date.")
if (!nzchar(as_of_timestamp)) g5_stop("GEN5_PORTFOLIO_POC_AS_OF_TIMESTAMP is required.")

train_quarters <- as.numeric(env_or("GEN5_PORTFOLIO_POC_TRAIN_QUARTERS", "8"))
oos_quarters <- as.numeric(env_or("GEN5_PORTFOLIO_POC_OOS_QUARTERS", "1"))
fold_count <- as.integer(env_or("GEN5_PORTFOLIO_POC_FOLD_COUNT", "5"))
grid_n <- as.integer(env_or("GEN5_PORTFOLIO_POC_GRID_N", "3"))
state_engine <- env_or("GEN5_PORTFOLIO_POC_STATE_ENGINE", "quantile_grid")
pca_panel_mode <- env_or("GEN5_PORTFOLIO_POC_PANEL_MODE", "pooled_asset_day")
kmeans_nstart <- as.integer(env_or("GEN5_PORTFOLIO_POC_KMEANS_NSTART", "30"))
min_train_state_rows <- as.integer(env_or("GEN5_PORTFOLIO_POC_MIN_TRAIN_STATE_ROWS", "20"))
warmup_days <- as.integer(env_or("GEN5_PORTFOLIO_POC_WARMUP_DAYS", "340"))
initial_capital <- as.numeric(env_or("GEN5_PORTFOLIO_POC_INITIAL_CAPITAL", "100000"))
slot_count <- as.integer(env_or("GEN5_PORTFOLIO_POC_SLOT_COUNT", as.character(length(active_symbols))))
refresh <- g5_parse_bool_env(env_or("GEN5_PORTFOLIO_POC_REFRESH", "false"), default = FALSE)
skip_child_runs <- g5_parse_bool_env(env_or("GEN5_PORTFOLIO_POC_SKIP_CHILD_RUNS", "false"), default = FALSE)

if (is.na(fold_count) || fold_count < 1L) g5_stop("GEN5_PORTFOLIO_POC_FOLD_COUNT must be a positive integer.")
state_engine <- g5_pca_wfa_state_engine(state_engine)
if (!pca_panel_mode %in% c("date_aligned_context", "pooled_asset_day")) g5_stop("GEN5_PORTFOLIO_POC_PANEL_MODE must be date_aligned_context or pooled_asset_day.")
if (is.na(kmeans_nstart) || kmeans_nstart < 1L) g5_stop("GEN5_PORTFOLIO_POC_KMEANS_NSTART must be a positive integer.")
if (is.na(slot_count) || slot_count < length(active_symbols)) g5_stop("GEN5_PORTFOLIO_POC_SLOT_COUNT must be at least the number of active symbols.")

fast_periods <- parse_int_list("GEN5_PORTFOLIO_POC_FAST_PERIODS", "8,12")
slow_periods <- parse_int_list("GEN5_PORTFOLIO_POC_SLOW_PERIODS", "30,50")
bb_lookback_periods <- parse_int_list("GEN5_PORTFOLIO_POC_BB_LOOKBACK_PERIODS", "10,20")
bb_sd_multipliers <- parse_num_list("GEN5_PORTFOLIO_POC_BB_SD_MULTIPLIERS", "1.5,2")
strategy_grid_preset <- g5_wfa_strategy_grid_preset(env_or("GEN5_PORTFOLIO_POC_STRATEGY_GRID_PRESET", "standard"))
candidate_families <- g5_wfa_candidate_families(parse_character_list("GEN5_PORTFOLIO_POC_CANDIDATE_FAMILIES", "ema_cross,ema_trend,bollinger_touch,bollinger_mid_reversion,rsi_mr,zret_mr,breakout,pullback_in_uptrend,vol_expansion_breakout,donchian_breakout_vol_expand,no_trade"))
candidate_families <- unique(c(candidate_families, "no_trade"))

train_days <- g5_ema_cross_wfa_quarters_to_days(train_quarters)
oos_days <- g5_ema_cross_wfa_quarters_to_days(oos_quarters)
wfa_start_date <- end_date - train_days - (fold_count * oos_days) - 2L
query_start_date <- wfa_start_date - warmup_days

message("Gen5 Portfolio Strategy Accounting POC")
message("Repository: ", repo_root)
message("Regime Context Universe: ", paste(regime_context_symbols, collapse = ", "))
message("Research Candidate Universe: ", paste(active_symbols, collapse = ", "))
message("Tradeable Universe: ", paste(active_symbols, collapse = ", "))
message("Active Allocation Set: ", paste(active_symbols, collapse = ", "))
message("Passive baseline symbol: ", baseline_symbol)
message("WFA window: ", wfa_start_date, " to ", end_date)
message("Query window with PCA/indicator warmup: ", query_start_date, " to ", end_date)
message("As of: ", as_of_timestamp)
message("Panel mode: ", pca_panel_mode)
message("State engine: ", state_engine)
message("Grid/cluster count: ", grid_n)
message("Fold count: ", fold_count)
message("Initial capital: ", initial_capital)
message("Slot count: ", slot_count)
message("Sizing policy: dynamic_equal_slot_cash_capped")
message("Strategy grid preset: ", strategy_grid_preset)
message("Refresh: ", refresh)
message("Skip child runs: ", skip_child_runs)
message("POC only: portfolio accounting over simulated stitched OOS artifacts; not live advice or final allocation evidence.")

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start_date,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = query_symbols,
  universe_name = paste0("portfolio_strategy_poc_ctx_", paste(regime_context_symbols, collapse = "_")),
  universe_roles = "regime_context_universe,portfolio_baseline_reference",
  refresh = refresh,
  repo_root = repo_root
)
for (symbol in active_symbols) {
  g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
}
g5_require_chartable_symbol(result, symbol = baseline_symbol, refresh = refresh)

read_child_csv <- function(path, label) {
  if (!file.exists(path)) {
    g5_stop(paste0("Missing ", label, ": ", path))
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

trades_by_symbol <- list()
equity_by_symbol <- list()
child_index <- list()

for (symbol in active_symbols) {
  message("")
  if (skip_child_runs) {
    message("Reading existing child PCA-routed WFA packet for ", symbol, " ...")
    child_output_dir <- g5_pca_wfa_find_output_dir(
      repo_root = repo_root,
      as_of_timestamp = result$resolved_session$as_of_timestamp,
      symbol = symbol,
      fold_count = fold_count,
      grid_n = grid_n,
      wfa_end_date = end_date,
      candidate_families = candidate_families,
      state_engine = state_engine,
      regime_context_symbols = regime_context_symbols,
      pca_panel_mode = pca_panel_mode,
      fallback_wfa_start_date = wfa_start_date,
      strategy_grid_preset = strategy_grid_preset
    )
    child_paths <- list(
      report_md = file.path(child_output_dir, "pcawfa_report.md"),
      oos_trades_csv = file.path(child_output_dir, "pcawfa_oos_trades.csv"),
      oos_equity_csv = file.path(child_output_dir, "pcawfa_oos_equity.csv"),
      oos_metrics_csv = file.path(child_output_dir, "pcawfa_oos_metrics.csv"),
      data_manifest_csv = file.path(child_output_dir, "pcawfa_manifest.csv")
    )
    trades_by_symbol[[symbol]] <- read_child_csv(child_paths$oos_trades_csv, paste(symbol, "OOS trades"))
    equity_by_symbol[[symbol]] <- read_child_csv(child_paths$oos_equity_csv, paste(symbol, "OOS equity"))
  } else {
    message("Running child PCA-routed WFA for ", symbol, " ...")
    pca_wfa <- g5_pca_wfa_run_multi(
      result$bars,
      symbol = symbol,
      wfa_start_date = wfa_start_date,
      wfa_end_date = end_date,
      fast_periods = fast_periods,
      slow_periods = slow_periods,
      bb_lookback_periods = bb_lookback_periods,
      bb_sd_multipliers = bb_sd_multipliers,
      strategy_grid_preset = strategy_grid_preset,
      candidate_families = candidate_families,
      train_quarters = train_quarters,
      oos_quarters = oos_quarters,
      fold_count = fold_count,
      grid_n = grid_n,
      state_engine = state_engine,
      kmeans_nstart = kmeans_nstart,
      regime_context_symbols = regime_context_symbols,
      pca_panel_mode = pca_panel_mode,
      min_train_state_rows = min_train_state_rows
    )

    child_output_dir <- g5_pca_wfa_output_dir(
      repo_root,
      result$resolved_session$as_of_timestamp,
      symbol,
      fold_count,
      grid_n,
      min(pca_wfa$folds$train_start_date),
      end_date,
      candidate_families,
      state_engine,
      regime_context_symbols,
      pca_panel_mode,
      strategy_grid_preset
    )
    dir.create(child_output_dir, recursive = TRUE, showWarnings = FALSE)
    written_query <- g5_write_workbench_query_artifacts(result, output_dir = child_output_dir, prefix = "pcawfa")
    written <- g5_write_pca_wfa_outputs(pca_wfa, child_output_dir, "pcawfa", symbol, result$resolved_session$as_of_timestamp)

    trades_by_symbol[[symbol]] <- pca_wfa$oos_trades
    equity_by_symbol[[symbol]] <- pca_wfa$oos_equity_curve
    child_paths <- list(
      report_md = written$paths$report_md,
      oos_trades_csv = written$paths$oos_trades_csv,
      oos_equity_csv = written$paths$oos_equity_csv,
      oos_metrics_csv = written$paths$oos_metrics_csv,
      data_manifest_csv = written_query$paths$manifest_csv
    )
  }
  child_index[[length(child_index) + 1L]] <- data.frame(
    schema_version = g5_portfolio_poc_schema_version(),
    symbol = symbol,
    run_dir = normalizePath(child_output_dir, winslash = "/", mustWork = FALSE),
    report_md = normalizePath(child_paths$report_md, winslash = "/", mustWork = FALSE),
    oos_trades_csv = normalizePath(child_paths$oos_trades_csv, winslash = "/", mustWork = FALSE),
    oos_equity_csv = normalizePath(child_paths$oos_equity_csv, winslash = "/", mustWork = FALSE),
    oos_metrics_csv = normalizePath(child_paths$oos_metrics_csv, winslash = "/", mustWork = FALSE),
    data_manifest_csv = normalizePath(child_paths$data_manifest_csv, winslash = "/", mustWork = FALSE),
    run_status = "ok",
    stringsAsFactors = FALSE
  )
}

accounting <- g5_portfolio_poc_build_accounting(
  trades_by_symbol = trades_by_symbol,
  equity_by_symbol = equity_by_symbol,
  active_symbols = active_symbols,
  initial_capital = initial_capital,
  slot_count = slot_count
)
accounting$baselines <- g5_portfolio_poc_build_baselines(
  bars = result$bars,
  dates = accounting$equity$session_date,
  active_symbols = active_symbols,
  initial_capital = initial_capital,
  baseline_symbol = baseline_symbol
)
child_artifact_index <- do.call(rbind, child_index)

stamp <- gsub("[^0-9A-Za-z]+", "", as.character(result$resolved_session$as_of_timestamp))
end_label <- gsub("[^0-9A-Za-z]+", "", as.character(end_date))
panel_label <- g5_pca_wfa_panel_label(pca_panel_mode)
engine_label <- g5_pca_wfa_engine_label(state_engine, grid_n)
grid_label <- g5_pca_wfa_strategy_grid_label(strategy_grid_preset)
packet_name <- paste(c(
  "portfolio_poc",
  paste(active_symbols, collapse = "-"),
  paste0(fold_count, "f"),
  engine_label,
  paste0(panel_label, length(regime_context_symbols), "ctx"),
  if (nzchar(grid_label)) grid_label else NULL,
  end_label,
  stamp
), collapse = "_")
output_dir <- file.path(repo_root, "runs", "research_workbench", "portfolio_strategy_pocs", packet_name)
settings <- list(
  regime_context_symbols = regime_context_symbols,
  active_symbols = active_symbols,
  initial_capital = initial_capital,
  slot_count = slot_count,
  pca_panel_mode = pca_panel_mode,
  state_engine = state_engine,
  grid_n = grid_n,
  fold_count = fold_count,
  end_date = end_date,
  as_of_timestamp = result$resolved_session$as_of_timestamp,
  strategy_grid_preset = strategy_grid_preset,
  baseline_symbol = baseline_symbol
)
written <- g5_portfolio_poc_write_outputs(accounting, child_artifact_index, output_dir, settings)

message("")
message("Portfolio POC metrics:")
print(written$metrics, row.names = FALSE)
message("")
message("Passive baseline metrics:")
print(written$baseline_metrics, row.names = FALSE)
message("")
message("Symbol summary:")
print(accounting$symbol_summary, row.names = FALSE)
message("")
message("Key outputs:")
message("  Report: ", written$paths$report_md)
message("  Chart: ", written$paths$chart_png)
message("  Equity: ", written$paths$portfolio_equity_csv)
message("  Events: ", written$paths$portfolio_events_csv)
message("")
message("Data health:")
g5_print_data_health_report(result$health)
