# Gen5.1 PCA context-universe comparison summary.

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

symbol <- g5_standardize_symbol(env_or("GEN5_PCA_UNIVERSE_COMPARISON_SYMBOL", "AMD"))[[1L]]
end_date <- as.Date(env_or("GEN5_PCA_UNIVERSE_COMPARISON_END_DATE", ""))
as_of_timestamp <- env_or("GEN5_PCA_UNIVERSE_COMPARISON_AS_OF_TIMESTAMP", env_or("GEN5_AS_OF_TIMESTAMP", ""))
fold_count <- as.integer(env_or("GEN5_PCA_UNIVERSE_COMPARISON_FOLD_COUNT", "5"))
universe_ids <- parse_character_list(
  "GEN5_PCA_UNIVERSE_COMPARISON_UNIVERSE_IDS",
  "baseline_context,similar_high_beta_tech_semis,diverse_market_risk_context"
)

if (is.na(end_date)) g5_stop("GEN5_PCA_UNIVERSE_COMPARISON_END_DATE must be a valid date.")
if (!nzchar(as_of_timestamp)) g5_stop("GEN5_PCA_UNIVERSE_COMPARISON_AS_OF_TIMESTAMP is required.")
if (is.na(fold_count) || fold_count < 1L) g5_stop("GEN5_PCA_UNIVERSE_COMPARISON_FOLD_COUNT must be a positive integer.")

all_defs <- g5_pca_wfa_context_universe_definitions(symbol)
missing_universes <- setdiff(universe_ids, all_defs$universe_id)
if (length(missing_universes)) {
  g5_stop(paste0("Unknown PCA context universe id(s): ", paste(missing_universes, collapse = ", ")))
}
universe_defs <- all_defs[match(universe_ids, all_defs$universe_id), , drop = FALSE]
rownames(universe_defs) <- NULL

output_dir <- g5_pca_wfa_universe_comparison_output_dir(repo_root, as_of_timestamp, symbol, fold_count, nrow(universe_defs), end_date)
written <- g5_write_pca_wfa_universe_comparison_outputs(
  universe_defs = universe_defs,
  output_dir = output_dir,
  repo_root = repo_root,
  as_of_timestamp = as_of_timestamp,
  symbol = symbol,
  fold_count = fold_count,
  wfa_end_date = end_date
)

message("Gen5 PCA context-universe comparison")
message("Repository: ", repo_root)
message("Symbol: ", symbol)
message("Fold count: ", fold_count)
message("End date: ", end_date)
message("As of: ", as_of_timestamp)
message("")
message("Universe index:")
print(written$universe_index[, c("universe_id", "symbol_count", "run_status", "report_md", "equity_contact_sheet_png", "strategy_contact_sheet_png", "pca_scatter_contact_sheet_png")], row.names = FALSE)
message("")
message("Key outputs:")
message("  Report: ", written$paths$report_md)
message("  Universe definitions: ", written$paths$universe_definitions_csv)
message("  Universe index: ", written$paths$universe_index_csv)
message("  Summary CSV: ", written$paths$summary_csv)
message("  Overview graphics index: ", written$paths$overview_graphics_csv)
message("  Metrics overview: ", written$paths$metrics_overview_png)
for (i in seq_len(nrow(written$overview_graphics))) {
  if (!identical(written$overview_graphics$graphic_id[[i]], "metrics_overview")) {
    message("  ", written$overview_graphics$graphic_id[[i]], ": ", written$overview_graphics$path[[i]])
  }
}
message("")
message("Wrote PCA context-universe comparison packet: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
