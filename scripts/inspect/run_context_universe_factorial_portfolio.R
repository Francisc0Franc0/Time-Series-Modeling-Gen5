# Gen5.1 context-universe factorial portfolio inspection summary.

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
source(file.path(repo_root, "R", "workbench_chart.R"))
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

parse_character_list <- function(name, default) {
  raw <- unique(trimws(strsplit(env_or(name, default), ",", fixed = TRUE)[[1L]]))
  raw <- raw[nzchar(raw)]
  if (!length(raw)) g5_stop(paste0(name, " must be a comma-separated list."))
  raw
}
parse_bool <- function(value, default = FALSE) {
  value <- tolower(trimws(as.character(value)))
  if (!nzchar(value)) return(default)
  if (value %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (value %in% c("false", "f", "0", "no", "n")) return(FALSE)
  g5_stop(paste0("Invalid boolean value: ", value))
}

active_symbols <- g5_portfolio_poc_symbols(parse_character_list("GEN5_CONTEXT_FACTORIAL_ACTIVE_SYMBOLS", "AMD,NVDA,TSLA,COIN,MSTR"), "GEN5_CONTEXT_FACTORIAL_ACTIVE_SYMBOLS")
end_date <- as.Date(env_or("GEN5_CONTEXT_FACTORIAL_END_DATE", ""))
as_of_timestamp <- env_or("GEN5_CONTEXT_FACTORIAL_AS_OF_TIMESTAMP", env_or("GEN5_AS_OF_TIMESTAMP", ""))
fold_count <- as.integer(env_or("GEN5_CONTEXT_FACTORIAL_FOLD_COUNT", "5"))
grid_n <- as.integer(env_or("GEN5_CONTEXT_FACTORIAL_GRID_N", "3"))
state_engine <- env_or("GEN5_CONTEXT_FACTORIAL_STATE_ENGINE", "quantile_grid")
pca_panel_mode <- env_or("GEN5_CONTEXT_FACTORIAL_PANEL_MODE", "pooled_asset_day")
strategy_grid_preset <- g5_wfa_strategy_grid_preset(env_or("GEN5_CONTEXT_FACTORIAL_STRATEGY_GRID_PRESET", "standard"))
refresh <- parse_bool(env_or("GEN5_CONTEXT_FACTORIAL_REFRESH", "false"), default = FALSE)
skip_child_runs <- parse_bool(env_or("GEN5_CONTEXT_FACTORIAL_SKIP_CHILD_RUNS", "false"), default = FALSE)

if (is.na(end_date)) g5_stop("GEN5_CONTEXT_FACTORIAL_END_DATE must be a valid date.")
if (!nzchar(as_of_timestamp)) g5_stop("GEN5_CONTEXT_FACTORIAL_AS_OF_TIMESTAMP is required.")
if (is.na(fold_count) || fold_count < 1L) g5_stop("GEN5_CONTEXT_FACTORIAL_FOLD_COUNT must be a positive integer.")
if (is.na(grid_n) || grid_n != 3L) g5_stop("GEN5_CONTEXT_FACTORIAL_GRID_N must be 3 for this wrapper.")
if (!identical(state_engine, "quantile_grid")) g5_stop("GEN5_CONTEXT_FACTORIAL_STATE_ENGINE must be quantile_grid for this wrapper.")
if (!identical(pca_panel_mode, "pooled_asset_day")) g5_stop("GEN5_CONTEXT_FACTORIAL_PANEL_MODE must be pooled_asset_day for this wrapper.")

universe_defs <- g5_context_factorial_universe_definitions(active_symbols)
output_dir <- g5_context_factorial_output_dir(
  repo_root = repo_root,
  as_of_timestamp = as_of_timestamp,
  active_symbols = active_symbols,
  fold_count = fold_count,
  universe_count = nrow(universe_defs),
  grid_n = grid_n,
  state_engine = state_engine,
  pca_panel_mode = pca_panel_mode,
  end_date = end_date,
  strategy_grid_preset = strategy_grid_preset
)

written <- g5_write_context_factorial_outputs(
  universe_defs = universe_defs,
  output_dir = output_dir,
  repo_root = repo_root,
  as_of_timestamp = as_of_timestamp,
  end_date = end_date,
  active_symbols = active_symbols,
  fold_count = fold_count,
  grid_n = grid_n,
  state_engine = state_engine,
  pca_panel_mode = pca_panel_mode,
  strategy_grid_preset = strategy_grid_preset,
  refresh = refresh,
  skip_child_runs = skip_child_runs
)

message("Gen5.1 context-universe factorial portfolio inspection")
message("Repository: ", repo_root)
message("Purpose: ", g5_context_factorial_default_purpose())
message("Active symbols: ", paste(active_symbols, collapse = ", "))
message("Panel/state surface: ", pca_panel_mode, " + ", state_engine, " ", grid_n, "x", grid_n)
message("End date: ", end_date)
message("As of: ", as_of_timestamp)
message("")
message("Portfolio packet index:")
print(written$portfolio_index[, c("universe_id", "run_status", "portfolio_dir", "report_md", "chart_png"), drop = FALSE], row.names = FALSE)
message("")
message("Key outputs:")
message("  Report: ", written$paths$report_md)
message("  Run spec: ", written$paths$run_spec_csv)
message("  Taxonomy: ", written$paths$taxonomy_csv)
message("  Summary: ", written$paths$summary_csv)
message("  Portfolio index: ", written$paths$portfolio_index_csv)
message("  Child artifact index: ", written$paths$child_artifact_index_csv)
message("  Metrics overview: ", written$paths$metrics_overview_png)
message("")
message("Wrote context-universe factorial packet: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
