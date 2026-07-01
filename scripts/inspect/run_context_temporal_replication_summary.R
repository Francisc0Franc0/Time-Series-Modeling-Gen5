# Gen5.1 temporal context-universe replication summary.

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

summary_id <- env_or("GEN5_CONTEXT_TEMPORAL_SUMMARY_ID", "ctxfac_temporal_context_replication_20241231_20260623")
output_dir <- g5_context_factorial_temporal_summary_output_dir(repo_root, summary_id)

written <- g5_write_context_factorial_temporal_summary(
  repo_root = repo_root,
  output_dir = output_dir,
  source_packets = g5_context_factorial_temporal_sources(repo_root)
)

message("Gen5.1 temporal context-universe replication summary")
message("Repository: ", repo_root)
message("Summary id: ", summary_id)
message("Research/inspection only; read existing packets and did not rerun WFA.")
message("")
message("Source packets:")
print(written$run_spec[, c("window_label", "packet_dir"), drop = FALSE], row.names = FALSE)
message("")
message("Rank summary:")
print(written$ranks[, c("universe_id", "surface_id", "window_count", "mean_total_return", "median_total_return", "min_total_return", "mean_sharpe", "worst_max_drawdown", "mean_return_rank", "return_rank_1_count", "negative_return_count"), drop = FALSE], row.names = FALSE)
message("")
message("Key outputs:")
message("  Report: ", written$paths$report_md)
message("  Run spec: ", written$paths$run_spec_csv)
message("  Merged summary: ", written$paths$merged_summary_csv)
message("  Rank summary: ", written$paths$rank_summary_csv)
message("  Visual index: ", written$paths$visual_index_csv)
message("  Metrics chart: ", written$paths$metrics_chart_png)
message("")
message("Wrote temporal replication summary packet: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
