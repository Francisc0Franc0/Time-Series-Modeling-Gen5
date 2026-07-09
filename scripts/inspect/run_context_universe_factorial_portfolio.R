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
strategy_grid_preset <- g5_wfa_strategy_grid_preset(env_or("GEN5_CONTEXT_FACTORIAL_STRATEGY_GRID_PRESET", "gen4_daily_default"))
refresh <- parse_bool(env_or("GEN5_CONTEXT_FACTORIAL_REFRESH", "false"), default = FALSE)
skip_child_runs <- parse_bool(env_or("GEN5_CONTEXT_FACTORIAL_SKIP_CHILD_RUNS", "false"), default = FALSE)
medium_grid <- parse_bool(env_or("GEN5_CONTEXT_FACTORIAL_MEDIUM_GRID", "false"), default = FALSE)
state_map_triage <- parse_bool(env_or("GEN5_CONTEXT_FACTORIAL_STATE_MAP_TRIAGE", "false"), default = FALSE)
auto_max15_triage <- parse_bool(env_or("GEN5_CONTEXT_FACTORIAL_AUTO_MAX15_TRIAGE", "false"), default = FALSE)
temporal_context_replication <- parse_bool(env_or("GEN5_CONTEXT_FACTORIAL_TEMPORAL_CONTEXT_REPLICATION", "false"), default = FALSE)

if (is.na(end_date)) g5_stop("GEN5_CONTEXT_FACTORIAL_END_DATE must be a valid date.")
if (!nzchar(as_of_timestamp)) g5_stop("GEN5_CONTEXT_FACTORIAL_AS_OF_TIMESTAMP is required.")
if (is.na(fold_count) || fold_count < 1L) g5_stop("GEN5_CONTEXT_FACTORIAL_FOLD_COUNT must be a positive integer.")
if (sum(c(isTRUE(medium_grid), isTRUE(state_map_triage), isTRUE(auto_max15_triage), isTRUE(temporal_context_replication))) > 1L) {
  g5_stop("Choose only one multi-surface context-factorial preset.")
}
if (is.na(grid_n) || grid_n < 2L) g5_stop("GEN5_CONTEXT_FACTORIAL_GRID_N must be at least 2.")
state_engine <- if (identical(state_engine, "kmeans")) "pca_kmeans" else state_engine
state_engine <- g5_pca_wfa_state_engine(state_engine)
pca_panel_mode <- g5_pca_wfa_panel_mode(pca_panel_mode)
if (identical(state_engine, "quantile_grid") && grid_n > 5L) g5_stop("GEN5_CONTEXT_FACTORIAL_GRID_N is too large for quantile_grid in this inspection wrapper.")
if (state_engine %in% c("pca_kmeans", "pca_kmeans_auto") && grid_n > 25L) g5_stop("GEN5_CONTEXT_FACTORIAL_GRID_N is too large for k-means in this inspection wrapper.")

universe_defs <- g5_context_factorial_universe_definitions(active_symbols)
universe_ids <- parse_character_list("GEN5_CONTEXT_FACTORIAL_UNIVERSE_IDS", paste(universe_defs$universe_id, collapse = ","))
universe_defs <- universe_defs[universe_defs$universe_id %in% universe_ids, , drop = FALSE]
if (!nrow(universe_defs)) g5_stop("GEN5_CONTEXT_FACTORIAL_UNIVERSE_IDS did not match any known context universes.")
surface_defs <- g5_context_factorial_surface_definitions(
  medium_grid = medium_grid,
  pca_panel_mode = pca_panel_mode,
  state_engine = state_engine,
  grid_n = grid_n,
  state_map_triage = state_map_triage,
  auto_max15_triage = auto_max15_triage,
  temporal_context_replication = temporal_context_replication
)
output_dir <- g5_context_factorial_output_dir(
  repo_root = repo_root,
  as_of_timestamp = as_of_timestamp,
  active_symbols = active_symbols,
  fold_count = fold_count,
  universe_count = nrow(universe_defs),
  surface_count = nrow(surface_defs),
  grid_n = grid_n,
  state_engine = state_engine,
  pca_panel_mode = pca_panel_mode,
  end_date = end_date,
  strategy_grid_preset = strategy_grid_preset,
  surface_preset = if (isTRUE(auto_max15_triage)) "automax15" else if (isTRUE(temporal_context_replication)) "temporalctx" else ""
)

purpose <- if (isTRUE(auto_max15_triage)) {
  g5_context_factorial_auto_max15_triage_purpose()
} else if (isTRUE(state_map_triage)) {
  g5_context_factorial_state_map_triage_purpose()
} else if (isTRUE(temporal_context_replication)) {
  g5_context_factorial_temporal_replication_purpose()
} else {
  g5_context_factorial_default_purpose()
}

written <- g5_write_context_factorial_outputs(
  universe_defs = universe_defs,
  surface_defs = surface_defs,
  output_dir = output_dir,
  repo_root = repo_root,
  as_of_timestamp = as_of_timestamp,
  end_date = end_date,
  active_symbols = active_symbols,
  fold_count = fold_count,
  strategy_grid_preset = strategy_grid_preset,
  refresh = refresh,
  skip_child_runs = skip_child_runs,
  purpose = purpose
)

message("Gen5.1 context-universe factorial portfolio inspection")
message("Repository: ", repo_root)
message("Purpose: ", purpose)
message("Active symbols: ", paste(active_symbols, collapse = ", "))
message("Medium grid: ", medium_grid)
message("State-map triage: ", state_map_triage)
message("Auto-k max15 triage: ", auto_max15_triage)
message("Surface count: ", nrow(surface_defs))
message("End date: ", end_date)
message("As of: ", as_of_timestamp)
message("")
message("PCA surfaces:")
print(surface_defs[, c("surface_id", "pca_panel_mode", "state_engine", "state_count"), drop = FALSE], row.names = FALSE)
message("")
message("Portfolio packet index:")
print(written$portfolio_index[, c("universe_id", "surface_id", "run_status", "portfolio_dir", "report_md", "chart_png"), drop = FALSE], row.names = FALSE)
message("")
message("Key outputs:")
message("  Report: ", written$paths$report_md)
message("  Run spec: ", written$paths$run_spec_csv)
message("  Taxonomy: ", written$paths$taxonomy_csv)
message("  Surfaces: ", written$paths$surface_definitions_csv)
message("  Summary: ", written$paths$summary_csv)
message("  Portfolio index: ", written$paths$portfolio_index_csv)
message("  Child artifact index: ", written$paths$child_artifact_index_csv)
message("  Child OOS metrics: ", written$paths$child_metric_summary_csv)
message("  State coverage: ", written$paths$state_coverage_summary_csv)
message("  Selected families: ", written$paths$selected_family_summary_csv)
message("  Auto clusters: ", written$paths$auto_cluster_summary_csv)
message("  Metrics overview: ", written$paths$metrics_overview_png)
message("  Visual audit index: ", written$paths$visual_audit_index_csv)
message("")
message("Wrote context-universe factorial packet: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
