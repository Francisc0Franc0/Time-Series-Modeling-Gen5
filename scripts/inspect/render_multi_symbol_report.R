# Gen5.1 multi-symbol data inspection report.

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

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = "")
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for multi-symbol report.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbols_env <- Sys.getenv("GEN5_MULTI_REPORT_SYMBOLS", unset = "")
if (!nzchar(symbols_env)) {
  g5_stop("GEN5_MULTI_REPORT_SYMBOLS is required for multi-symbol report.")
}
symbols <- unique(g5_standardize_symbol(trimws(strsplit(symbols_env, ",", fixed = TRUE)[[1L]])))
if (length(symbols) == 0L) {
  g5_stop("GEN5_MULTI_REPORT_SYMBOLS resolved zero symbols.")
}

start_env <- Sys.getenv("GEN5_MULTI_REPORT_START_DATE", unset = "")
end_env <- Sys.getenv("GEN5_MULTI_REPORT_END_DATE", unset = "")
lookback_env <- Sys.getenv("GEN5_MULTI_REPORT_LOOKBACK_DAYS", unset = "")
if (!nzchar(end_env)) {
  g5_stop("GEN5_MULTI_REPORT_END_DATE is required.")
}
end_date <- as.Date(end_env)
if (is.na(end_date)) {
  g5_stop("GEN5_MULTI_REPORT_END_DATE could not be parsed as a date.")
}
if (nzchar(start_env)) {
  start_date <- as.Date(start_env)
  if (is.na(start_date)) {
    g5_stop("GEN5_MULTI_REPORT_START_DATE could not be parsed as a date.")
  }
} else if (nzchar(lookback_env)) {
  lookback_days <- suppressWarnings(as.integer(lookback_env))
  if (is.na(lookback_days) || lookback_days < 1L) {
    g5_stop("GEN5_MULTI_REPORT_LOOKBACK_DAYS must be a positive integer when supplied.")
  }
  start_date <- end_date - lookback_days
} else {
  g5_stop("Provide GEN5_MULTI_REPORT_START_DATE or GEN5_MULTI_REPORT_LOOKBACK_DAYS.")
}

refresh <- g5_parse_bool_env(Sys.getenv("GEN5_MULTI_REPORT_REFRESH", unset = ""), default = FALSE)

message("Gen5 multi-symbol data report")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Symbols: ", paste(symbols, collapse = ", "))
message("Requested: ", as.character(start_date), " to ", as.character(end_date))
message("As of: ", as.character(as_of_timestamp))
message("Refresh: ", refresh)

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = start_date,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbols,
  universe_name = paste0("multi_symbol_report_", paste(symbols, collapse = "_")),
  universe_roles = "research_universe",
  refresh = refresh,
  repo_root = repo_root
)

output_dir <- g5_multi_symbol_report_output_dir(repo_root, result$resolved_session$as_of_timestamp, symbols)
written <- g5_write_multi_symbol_report_outputs(result, symbols = symbols, output_dir = output_dir)

message("")
message("Summary:")
message("  Latest completed session: ", as.character(written$summary$latest_completed_session[[1L]]))
message("  Charted symbols: ", paste(written$chart_symbols, collapse = ", "))
message("  Health max severity: ", written$summary$health_max_severity[[1L]])
message("  Multi-panel chart: ", written$paths$multi_panel_png)
message("  Summary: ", written$paths$summary_md)
message("")
message("Per-symbol rows:")
for (i in seq_len(nrow(written$summary))) {
  row <- written$summary[i, , drop = FALSE]
  message(
    "  ",
    row$symbol,
    ": rows=",
    row$row_count,
    " observed=",
    as.character(row$observed_start_date),
    " to ",
    as.character(row$observed_end_date),
    " health=",
    row$health_max_severity
  )
}
message("")
message("Data health:")
g5_print_data_health_report(result$health)
message("")
message("Wrote multi-symbol report packet:")
for (nm in names(written$paths)) {
  message("  ", nm, ": ", written$paths[[nm]])
}
