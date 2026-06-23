# Gen5 v0.1 research workbench small-basket query path.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = FALSE)
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

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = "")
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for research workbench queries.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

start_env <- Sys.getenv("GEN5_WORKBENCH_START_DATE", unset = "")
end_env <- Sys.getenv("GEN5_WORKBENCH_END_DATE", unset = "")
if (!nzchar(start_env) || !nzchar(end_env)) {
  g5_stop("GEN5_WORKBENCH_START_DATE and GEN5_WORKBENCH_END_DATE are required.")
}
start_date <- as.Date(start_env)
end_date <- as.Date(end_env)
if (any(is.na(c(start_date, end_date)))) {
  g5_stop("GEN5_WORKBENCH_START_DATE or GEN5_WORKBENCH_END_DATE could not be parsed as a date.")
}

symbols_env <- Sys.getenv("GEN5_WORKBENCH_SYMBOLS", unset = "")
symbols <- if (nzchar(symbols_env)) {
  g5_standardize_symbol(strsplit(symbols_env, ",", fixed = TRUE)[[1L]])
} else {
  NULL
}
universe_name <- Sys.getenv("GEN5_WORKBENCH_UNIVERSE", unset = "gen5_v0_1_poc_growth")
roles_env <- Sys.getenv("GEN5_WORKBENCH_ROLES", unset = "research_universe")
universe_roles <- trimws(strsplit(roles_env, ",", fixed = TRUE)[[1L]])
refresh <- g5_parse_bool_env(Sys.getenv("GEN5_WORKBENCH_REFRESH", unset = ""), default = FALSE)

message("Gen5 research workbench query")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Refresh enabled: ", refresh)
message("Universe: ", universe_name, " roles=", paste(universe_roles, collapse = ","))
if (!is.null(symbols)) {
  message("Explicit symbols: ", paste(symbols, collapse = ","))
}

registry <- g5_load_universe_registry(file.path(repo_root, "config", "universe_registry.csv"))
result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = start_date,
  end_date = end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbols,
  universe_registry = registry,
  universe_name = universe_name,
  universe_roles = universe_roles,
  refresh = refresh,
  repo_root = repo_root
)

output_dir <- file.path(repo_root, "runs", "research_workbench")
prefix <- g5_workbench_artifact_prefix(result$resolved_session$as_of_timestamp, universe_name)
written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)

message("Resolved session:")
print(result$resolved_session)
message("Date range:")
print(result$date_range)
message("Manifest:")
print(written$manifest)
message("Data health:")
g5_print_data_health_report(result$health)

message("Wrote workbench artifacts:")
for (nm in names(written$paths)) {
  message("  ", nm, ": ", written$paths[[nm]])
}
