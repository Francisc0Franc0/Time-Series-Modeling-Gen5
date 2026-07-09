# Gen5.1 two-window context-factorial state-map comparison.

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

comparison_id <- env_or("GEN5_CONTEXT_WINDOW_COMPARISON_ID", "ctxfac_two_window_state_map_20260331_20260624")
output_dir <- g5_context_factorial_window_comparison_output_dir(repo_root, comparison_id)

written <- g5_write_context_factorial_window_comparison(
  repo_root = repo_root,
  output_dir = output_dir,
  source_packets = g5_context_factorial_window_sources(repo_root)
)

message("Gen5.1 two-window state-map comparison")
message("Repository: ", repo_root)
message("Comparison id: ", comparison_id)
message("Research/inspection only; read existing packets and did not rerun WFA.")
message("")
message("Source packets:")
print(written$run_spec[, c("window_label", "packet_role", "packet_dir"), drop = FALSE], row.names = FALSE)
message("")
message("Merged summary:")
print(written$summary[, c("window_label", "comparison_surface_id", "surface_label", "total_return", "sharpe", "max_drawdown", "total_entry_fills"), drop = FALSE], row.names = FALSE)
message("")
message("Key outputs:")
message("  Report: ", written$paths$report_md)
message("  Run spec: ", written$paths$run_spec_csv)
message("  Merged summary: ", written$paths$merged_summary_csv)
message("  Auto clusters: ", written$paths$auto_clusters_csv)
message("  Fold diagnostics: ", written$paths$fold_diagnostics_csv)
message("  Diagnostic summary: ", written$paths$diagnostic_summary_csv)
message("  Visual index: ", written$paths$visual_index_csv)
message("  Metrics chart: ", written$paths$metrics_chart_png)
message("  Auto-k chart: ", written$paths$auto_cluster_chart_png)
message("  Fragmentation chart: ", written$paths$fragmentation_chart_png)
message("")
message("Wrote two-window comparison packet: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
