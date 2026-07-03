# Gen5.1 PCA router comparison report.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
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

parse_character_list <- function(name, default) {
  raw <- unique(trimws(strsplit(env_or(name, default), ",", fixed = TRUE)[[1L]]))
  raw <- raw[nzchar(raw)]
  if (!length(raw)) g5_stop(paste0(name, " must be a comma-separated list."))
  raw
}

fmt_pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
fmt_num <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", as.numeric(x)))

symbol <- g5_standardize_symbol(env_or("GEN5_PCA_COMPARISON_SYMBOL", "AMD"))[[1L]]
regime_context_symbols <- unique(c(symbol, g5_standardize_symbol(parse_character_list("GEN5_PCA_COMPARISON_REGIME_CONTEXT_SYMBOLS", "AMD,NVDA,TSLA"))))
end_date <- as.Date(env_or("GEN5_PCA_COMPARISON_END_DATE", ""))
as_of_timestamp <- env_or("GEN5_PCA_COMPARISON_AS_OF_TIMESTAMP", env_or("GEN5_AS_OF_TIMESTAMP", ""))
if (is.na(end_date)) g5_stop("GEN5_PCA_COMPARISON_END_DATE must be a valid date.")
if (!nzchar(as_of_timestamp)) g5_stop("GEN5_PCA_COMPARISON_AS_OF_TIMESTAMP is required.")

train_quarters <- as.numeric(env_or("GEN5_PCA_COMPARISON_TRAIN_QUARTERS", "8"))
oos_quarters <- as.numeric(env_or("GEN5_PCA_COMPARISON_OOS_QUARTERS", "1"))
fold_count <- as.integer(env_or("GEN5_PCA_COMPARISON_FOLD_COUNT", "5"))
quantile_state_count <- as.integer(env_or("GEN5_PCA_COMPARISON_QUANTILE_STATE_COUNT", "3"))
kmeans_state_count <- as.integer(env_or("GEN5_PCA_COMPARISON_KMEANS_STATE_COUNT", "9"))
if (is.na(train_quarters) || train_quarters <= 0) g5_stop("GEN5_PCA_COMPARISON_TRAIN_QUARTERS must be positive.")
if (is.na(oos_quarters) || oos_quarters <= 0) g5_stop("GEN5_PCA_COMPARISON_OOS_QUARTERS must be positive.")
if (is.na(fold_count) || fold_count < 1L) g5_stop("GEN5_PCA_COMPARISON_FOLD_COUNT must be a positive integer.")
if (is.na(quantile_state_count) || quantile_state_count < 2L || quantile_state_count > 5L) g5_stop("GEN5_PCA_COMPARISON_QUANTILE_STATE_COUNT must be between 2 and 5.")
if (is.na(kmeans_state_count) || kmeans_state_count < 2L || kmeans_state_count > 25L) g5_stop("GEN5_PCA_COMPARISON_KMEANS_STATE_COUNT must be between 2 and 25.")

candidate_families <- g5_wfa_candidate_families(parse_character_list("GEN5_PCA_COMPARISON_CANDIDATE_FAMILIES", "ema_cross,ema_trend,bollinger_touch,bollinger_mid_reversion,rsi_mr,zret_mr,breakout,pullback_in_uptrend,vol_expansion_breakout,donchian_breakout_vol_expand,no_trade"))
candidate_families <- unique(c(candidate_families, "no_trade"))
strategy_grid_preset <- g5_wfa_strategy_grid_preset(env_or("GEN5_PCA_COMPARISON_STRATEGY_GRID_PRESET", "gen4_daily_default"))

train_days <- g5_ema_cross_wfa_quarters_to_days(train_quarters)
oos_days <- g5_ema_cross_wfa_quarters_to_days(oos_quarters)
wfa_start_date <- end_date - train_days - (fold_count * oos_days) - 2L

panel_modes <- c("contextual_snapshot", "behavioral_pool")
state_maps <- c("quantile_grid", "kmeans")
rows <- list()
for (panel_mode in panel_modes) {
  internal_panel_mode <- if (identical(panel_mode, "behavioral_pool")) "pooled_asset_day" else "date_aligned_context"
  for (state_map in state_maps) {
    state_engine <- if (identical(state_map, "kmeans")) "pca_kmeans" else "quantile_grid"
    state_count <- if (identical(state_map, "kmeans")) kmeans_state_count else quantile_state_count
    run_dir <- g5_pca_wfa_find_output_dir(
      repo_root = repo_root,
      as_of_timestamp = as_of_timestamp,
      symbol = symbol,
      fold_count = fold_count,
      grid_n = state_count,
      wfa_end_date = end_date,
      candidate_families = candidate_families,
      state_engine = state_engine,
      regime_context_symbols = regime_context_symbols,
      pca_panel_mode = internal_panel_mode,
      fallback_wfa_start_date = wfa_start_date,
      strategy_grid_preset = strategy_grid_preset
    )
    rows[[length(rows) + 1L]] <- data.frame(
      panel_mode = panel_mode,
      state_map = state_map,
      internal_panel_mode = internal_panel_mode,
      state_engine = state_engine,
      state_count = state_count,
      run_dir = normalizePath(run_dir, winslash = "/", mustWork = FALSE),
      stringsAsFactors = FALSE
    )
  }
}
run_index <- do.call(rbind, rows)

output_dir <- g5_pca_wfa_comparison_output_dir(repo_root, as_of_timestamp, symbol, fold_count, regime_context_symbols, end_date, strategy_grid_preset)
settings <- list(
  symbol = symbol,
  regime_context_symbols = regime_context_symbols,
  fold_count = fold_count,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  strategy_grid_preset = strategy_grid_preset
)
written <- g5_write_pca_wfa_comparison_outputs(
  run_index = run_index,
  output_dir = output_dir,
  settings = settings
)

message("Gen5 PCA router comparison report")
message("Repository: ", repo_root)
message("Symbol: ", symbol)
message("Regime Context Universe: ", paste(regime_context_symbols, collapse = ", "))
message("Fold count: ", fold_count)
message("End date: ", end_date)
message("As of: ", as_of_timestamp)
message("Strategy grid preset: ", strategy_grid_preset)
message("")
message("Comparison summary:")
print(written$summary[, c("panel_mode", "state_map", "state_count", "run_status", "total_return", "sharpe", "max_drawdown", "trade_count", "oos_covered_states", "selected_families")], row.names = FALSE)
message("")
message("Key outputs:")
message("  Report: ", written$paths$report_md)
message("  Summary CSV: ", written$paths$summary_csv)
message("  Selected family counts: ", written$paths$selected_family_counts_csv)
message("  Path index: ", written$paths$path_index_csv)
message("  Equity 2x2: ", written$paths$equity_contact_sheet_png)
message("  Stitched OOS 2x2: ", written$paths$strategy_contact_sheet_png)
message("  PCA scatter 2x2: ", written$paths$pca_scatter_contact_sheet_png)
message("")
message("Wrote PCA router comparison packet: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
