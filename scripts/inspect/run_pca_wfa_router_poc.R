# Gen5.1 PCA-routed WFA proof of concept.

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
fmt_pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
fmt_num <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", as.numeric(x)))

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

symbol <- g5_standardize_symbol(env_or("GEN5_PCA_WFA_SYMBOL", "AMD"))[[1L]]
end_date <- as.Date(env_or("GEN5_PCA_WFA_END_DATE", ""))
as_of_timestamp <- env_or("GEN5_PCA_WFA_AS_OF_TIMESTAMP", env_or("GEN5_AS_OF_TIMESTAMP", ""))
if (is.na(end_date)) g5_stop("GEN5_PCA_WFA_END_DATE must be a valid date.")
if (!nzchar(as_of_timestamp)) g5_stop("GEN5_PCA_WFA_AS_OF_TIMESTAMP is required.")

train_quarters <- as.numeric(env_or("GEN5_PCA_WFA_TRAIN_QUARTERS", "8"))
oos_quarters <- as.numeric(env_or("GEN5_PCA_WFA_OOS_QUARTERS", "1"))
fold_count <- as.integer(env_or("GEN5_PCA_WFA_FOLD_COUNT", "1"))
grid_n <- as.integer(env_or("GEN5_PCA_WFA_GRID_N", "3"))
state_engine <- env_or("GEN5_PCA_WFA_STATE_ENGINE", "quantile_grid")
kmeans_nstart <- as.integer(env_or("GEN5_PCA_WFA_KMEANS_NSTART", "30"))
min_train_state_rows <- as.integer(env_or("GEN5_PCA_WFA_MIN_TRAIN_STATE_ROWS", "20"))
warmup_days <- as.integer(env_or("GEN5_PCA_WFA_WARMUP_DAYS", "340"))
refresh <- g5_parse_bool_env(env_or("GEN5_PCA_WFA_REFRESH", "false"), default = FALSE)
if (is.na(fold_count) || fold_count < 1L) g5_stop("GEN5_PCA_WFA_FOLD_COUNT must be a positive integer.")
if (!state_engine %in% c("quantile_grid", "pca_kmeans")) g5_stop("GEN5_PCA_WFA_STATE_ENGINE must be quantile_grid or pca_kmeans.")
if (is.na(kmeans_nstart) || kmeans_nstart < 1L) g5_stop("GEN5_PCA_WFA_KMEANS_NSTART must be a positive integer.")

fast_periods <- parse_int_list("GEN5_PCA_WFA_FAST_PERIODS", "8,12")
slow_periods <- parse_int_list("GEN5_PCA_WFA_SLOW_PERIODS", "30,50")
bb_lookback_periods <- parse_int_list("GEN5_PCA_WFA_BB_LOOKBACK_PERIODS", "10,20")
bb_sd_multipliers <- parse_num_list("GEN5_PCA_WFA_BB_SD_MULTIPLIERS", "1.5,2")
candidate_families <- g5_wfa_candidate_families(parse_character_list("GEN5_PCA_WFA_CANDIDATE_FAMILIES", "ema_cross,bollinger_touch,no_trade"))
candidate_families <- unique(c(candidate_families, "no_trade"))

train_days <- g5_ema_cross_wfa_quarters_to_days(train_quarters)
oos_days <- g5_ema_cross_wfa_quarters_to_days(oos_quarters)
wfa_start_date <- end_date - train_days - (fold_count * oos_days) - 2L
query_start_date <- wfa_start_date - warmup_days

message("Gen5 PCA-routed WFA POC")
message("Repository: ", repo_root)
message("Symbol: ", symbol)
message("WFA window: ", wfa_start_date, " to ", end_date)
message("Query window with PCA/indicator warmup: ", query_start_date, " to ", end_date)
message("As of: ", as_of_timestamp)
message("Train quarters: ", train_quarters)
message("OOS quarters: ", oos_quarters)
message("Fold count: ", fold_count)
message("State engine: ", state_engine)
message(if (identical(state_engine, "pca_kmeans")) paste0("PCA k-means clusters: ", grid_n) else paste0("PCA grid: ", grid_n, "x", grid_n))
message("Candidate families: ", paste(candidate_families, collapse = ", "))
message("Ownership policy: entry_state_owns_trade_until_exit")
message("Refresh: ", refresh)
message("POC only: PCA states route strategy-spec entries in OOS; not final research evidence or live advice.")

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start_date,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = paste0("pca_wfa_router_poc_", symbol),
  universe_roles = "research_universe",
  refresh = refresh,
  repo_root = repo_root
)
g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)

pca_wfa <- g5_pca_wfa_run_multi(
  result$bars,
  symbol = symbol,
  wfa_start_date = wfa_start_date,
  wfa_end_date = end_date,
  fast_periods = fast_periods,
  slow_periods = slow_periods,
  bb_lookback_periods = bb_lookback_periods,
  bb_sd_multipliers = bb_sd_multipliers,
  candidate_families = candidate_families,
  train_quarters = train_quarters,
  oos_quarters = oos_quarters,
  fold_count = fold_count,
  grid_n = grid_n,
  state_engine = state_engine,
  kmeans_nstart = kmeans_nstart,
  min_train_state_rows = min_train_state_rows
)

output_dir <- g5_pca_wfa_output_dir(repo_root, result$resolved_session$as_of_timestamp, symbol, fold_count, grid_n, min(pca_wfa$folds$train_start_date), end_date, candidate_families, state_engine)
prefix <- "pcawfa"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
written_query <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
written <- g5_write_pca_wfa_outputs(pca_wfa, output_dir, prefix, symbol, result$resolved_session$as_of_timestamp)

metric <- pca_wfa$oos_metrics[1L, , drop = FALSE]
message("")
message("Folds:")
print(pca_wfa$folds[, c("fold_id", "train_start_date", "train_end_date", "oos_start_date", "oos_end_date", "oos_session_count")], row.names = FALSE)
message("")
message("Selected state specs:")
print(pca_wfa$selected_states[, c("fold_id", "state_id", "strategy_family", "strategy_spec_id", "train_state_row_count", "train_state_trade_count", "sharpe", "total_return", "selection_reason")], row.names = FALSE)
message("")
message("OOS performance:")
message("  Return: ", fmt_pct(metric$total_return[[1L]]))
message("  Sharpe: ", fmt_num(metric$sharpe[[1L]]))
message("  Max drawdown: ", fmt_pct(metric$max_drawdown[[1L]]))
message("  Trades: ", metric$trade_count[[1L]])
message("  Buy-and-hold return: ", fmt_pct(metric$buy_hold_total_return[[1L]]))
message("")
message("Key outputs:")
message("  Report: ", written$paths$report_md)
message("  Selected states: ", written$paths$selected_states_csv)
message("  Train state performance: ", written$paths$train_state_performance_csv)
message("  OOS trades: ", written$paths$oos_trades_csv)
message("  State strategy chart: ", written$paths$state_strategy_chart_png)
message("  Equity curve: ", written$paths$equity_chart_png)
message("")
message("Data health:")
g5_print_data_health_report(result$health)
message("")
message("Wrote PCA-routed WFA packet:")
for (nm in names(c(written_query$paths, written$paths))) {
  message("  ", nm, ": ", c(written_query$paths, written$paths)[[nm]])
}
