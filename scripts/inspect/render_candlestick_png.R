# Gen5 v0.1 static candlestick inspection path.

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

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = "")
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for candlestick inspection.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbol_env <- Sys.getenv("GEN5_CHART_SYMBOL", unset = "")
if (!nzchar(symbol_env)) {
  g5_stop("GEN5_CHART_SYMBOL is required for candlestick inspection.")
}
symbol <- g5_standardize_symbol(trimws(strsplit(symbol_env, ",", fixed = TRUE)[[1L]]))
if (length(symbol) != 1L) {
  g5_stop("GEN5_CHART_SYMBOL must contain exactly one symbol.")
}

start_env <- Sys.getenv("GEN5_CHART_START_DATE", unset = Sys.getenv("GEN5_WORKBENCH_START_DATE", unset = ""))
end_env <- Sys.getenv("GEN5_CHART_END_DATE", unset = Sys.getenv("GEN5_WORKBENCH_END_DATE", unset = ""))
if (!nzchar(start_env) || !nzchar(end_env)) {
  g5_stop("GEN5_CHART_START_DATE and GEN5_CHART_END_DATE are required.")
}
start_date <- as.Date(start_env)
end_date <- as.Date(end_env)
if (any(is.na(c(start_date, end_date)))) {
  g5_stop("GEN5_CHART_START_DATE or GEN5_CHART_END_DATE could not be parsed as a date.")
}

refresh <- g5_parse_bool_env(Sys.getenv("GEN5_CHART_REFRESH", unset = ""), default = FALSE)

message("Gen5 static candlestick inspection")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Refresh enabled: ", refresh)
message("Symbol: ", symbol)

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = start_date,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "single_symbol_candlestick",
  universe_roles = "research_universe",
  refresh = refresh,
  repo_root = repo_root
)

output_dir <- file.path(repo_root, "runs", "research_workbench")
prefix <- g5_candlestick_artifact_prefix(result$resolved_session$as_of_timestamp, symbol)
written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
png_path <- file.path(output_dir, paste0(prefix, "_candlestick.png"))
g5_write_static_candlestick_png(
  result$bars,
  symbol = symbol,
  path = png_path,
  start_date = result$date_range$fetch_start_date,
  end_date = result$date_range$fetch_end_date
)

message("Resolved session:")
print(result$resolved_session)
message("Date range:")
print(result$date_range)
message("Data health:")
g5_print_data_health_report(result$health)

message("Wrote candlestick PNG:")
message("  candlestick_png: ", normalizePath(png_path, winslash = "/", mustWork = FALSE))
message("Wrote companion query artifacts:")
for (nm in names(written$paths)) {
  message("  ", nm, ": ", written$paths[[nm]])
}
