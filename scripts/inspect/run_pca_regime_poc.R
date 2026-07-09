# Gen5.1 PCA regime diagnostic proof of concept.

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
source(file.path(repo_root, "R", "regime_pca_poc.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
parse_num <- function(name, default) {
  value <- suppressWarnings(as.numeric(env_or(name, as.character(default))))
  if (!is.finite(value)) g5_stop(paste0(name, " must be numeric."))
  value
}
parse_int <- function(name, default) {
  value <- as.integer(round(parse_num(name, default)))
  if (is.na(value)) g5_stop(paste0(name, " must be an integer."))
  value
}

symbol <- env_or("GEN5_PCA_REGIME_SYMBOL", "AMD")
end_date <- as.Date(env_or("GEN5_PCA_REGIME_END_DATE", ""))
as_of_timestamp <- env_or("GEN5_PCA_REGIME_AS_OF_TIMESTAMP", "")
train_quarters <- parse_num("GEN5_PCA_REGIME_TRAIN_QUARTERS", 8)
oos_quarters <- parse_num("GEN5_PCA_REGIME_OOS_QUARTERS", 1)
grid_n <- parse_int("GEN5_PCA_REGIME_GRID_N", 3)
warmup_days <- parse_int("GEN5_PCA_REGIME_WARMUP_DAYS", 320)
refresh <- g5_parse_bool_env(env_or("GEN5_PCA_REGIME_REFRESH", "false"), default = FALSE)

if (is.na(end_date)) {
  g5_stop("GEN5_PCA_REGIME_END_DATE must be a valid date.")
}
if (!nzchar(as_of_timestamp)) {
  g5_stop("GEN5_PCA_REGIME_AS_OF_TIMESTAMP is required.")
}
if (train_quarters <= 0 || oos_quarters <= 0) {
  g5_stop("TRAIN and OOS quarters must be positive.")
}

train_days <- as.integer(round(train_quarters * 365.25 / 4))
oos_days <- as.integer(round(oos_quarters * 365.25 / 4))
oos_start_date <- end_date - oos_days + 1L
train_end_date <- oos_start_date - 1L
train_start_date <- train_end_date - train_days + 1L
query_start_date <- train_start_date - warmup_days

message("Gen5 PCA 3x3 regime POC")
message("Repository: ", repo_root)
message("Symbol: ", symbol)
message("Query window with feature warmup: ", query_start_date, " to ", end_date)
message("TRAIN window: ", train_start_date, " to ", train_end_date)
message("OOS window: ", oos_start_date, " to ", end_date)
message("Grid: ", grid_n, "x", grid_n)
message("As of: ", as_of_timestamp)
message("Refresh: ", refresh)
message("Diagnostic only: states are not yet allowed to route WFA strategy selection.")

cfg <- g5_load_data_layer_config(repo_root)
result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start_date,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  refresh = refresh,
  repo_root = repo_root
)

features <- g5_pca_regime_feature_table(result$bars, symbol, end_date = end_date)
pca <- g5_pca_regime_fit(
  features,
  train_start_date = train_start_date,
  train_end_date = train_end_date,
  oos_start_date = oos_start_date,
  oos_end_date = end_date,
  grid_n = grid_n
)

prefix <- g5_pca_regime_artifact_prefix(result$resolved_session$as_of_timestamp, symbol, grid_n, train_start_date, end_date)
output_dir <- g5_pca_regime_output_dir(repo_root, result$resolved_session$as_of_timestamp, symbol, grid_n, train_start_date, end_date)
written_query <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
written <- g5_write_pca_regime_outputs(pca, output_dir = output_dir, prefix = prefix, symbol = symbol, as_of_timestamp = result$resolved_session$as_of_timestamp)

message("")
message("PCA diagnostics:")
print(written$result$diagnostics, row.names = FALSE)
message("")
message("State coverage:")
print(written$result$state_coverage[written$result$state_coverage$row_count > 0L, , drop = FALSE], row.names = FALSE)
message("")
message("Key outputs:")
message("  PCA scatter: ", written$paths$pca_scatter_png)
message("  Price/state chart: ", written$paths$price_state_png)
message("  Report: ", written$paths$report_md)
message("  Scores CSV: ", written$paths$scores_csv)
message("  Model contract CSV: ", written$paths$model_contract_csv)
message("")
message("Data health:")
for (i in seq_len(nrow(result$health))) {
  row <- result$health[i, , drop = FALSE]
  symbol_text <- if ("symbol" %in% names(row) && !is.na(row$symbol[[1L]]) && nzchar(row$symbol[[1L]])) paste0(" [", row$symbol[[1L]], "]") else ""
  message(row$severity[[1L]], " ", row$code[[1L]], symbol_text, " - ", row$message[[1L]])
}
message("")
message("Wrote PCA regime packet:")
for (nm in names(c(written_query$paths, written$paths))) {
  message("  ", nm, ": ", c(written_query$paths, written$paths)[[nm]])
}
