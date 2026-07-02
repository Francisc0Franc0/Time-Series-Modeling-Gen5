# Run a temporary Gen5.1 live-advice bridge daily packet.

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
source(file.path(repo_root, "R", "strategy_ema_cross.R"))
source(file.path(repo_root, "R", "strategy_bollinger_touch.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_poc.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

parse_args <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--[^=]+=", arg)) next
    key <- sub("^--", "", sub("=.*$", "", arg))
    value <- sub("^[^=]+=", "", arg)
    out[[gsub("-", "_", key)]] <- value
  }
  out
}

arg <- parse_args(commandArgs(trailingOnly = TRUE))
arg_or_env <- function(arg_name, env_name, default = "") {
  value <- arg[[arg_name]]
  if (!is.null(value) && nzchar(value)) value else env_or(env_name, default)
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_timestamp <- arg_or_env("as_of", "GEN5_BRIDGE_DAILY_AS_OF_TIMESTAMP", env_or("GEN5_AS_OF_TIMESTAMP", ""))
if (!nzchar(as_of_timestamp)) {
  g5_stop("An explicit --as-of= timestamp or GEN5_BRIDGE_DAILY_AS_OF_TIMESTAMP is required.")
}
as_of_date <- as.Date(substr(as_of_timestamp, 1L, 10L))
if (is.na(as_of_date)) {
  g5_stop("--as-of must begin with a valid YYYY-MM-DD date.")
}
quarter_id <- toupper(arg_or_env("quarter", "GEN5_BRIDGE_QUARTER_ID", g5_bridge_quarter_id(as_of_date)))
refresh <- g5_parse_bool_env(arg_or_env("refresh", "GEN5_BRIDGE_REFRESH", "true"), default = TRUE)
warmup_days <- as.integer(arg_or_env("warmup_days", "GEN5_BRIDGE_WARMUP_DAYS", "420"))
if (is.na(warmup_days) || warmup_days < 60L) g5_stop("warmup_days must be an integer >= 60.")

authority_dir <- arg_or_env("authority_dir", "GEN5_BRIDGE_AUTHORITY_DIR", g5_bridge_authority_dir(repo_root, quarter_id))
authority <- g5_bridge_read_authority(authority_dir)
contract <- authority$contract[1L, , drop = FALSE]
symbols <- g5_standardize_symbol(strsplit(contract$symbols[[1L]], ",", fixed = TRUE)[[1L]])
default_feed <- if ("market_data_feed" %in% names(contract) && nzchar(as.character(contract$market_data_feed[[1L]]))) as.character(contract$market_data_feed[[1L]]) else as.character(cfg$feed)
feed <- arg_or_env("feed", "GEN5_BRIDGE_FEED", default_feed)
if (nzchar(feed)) cfg$feed <- feed
if (!identical(contract$quarter_id[[1L]], quarter_id)) {
  g5_stop("Requested quarter does not match frozen authority contract.")
}
if (as_of_date > as.Date(contract$live_end_date[[1L]])) {
  g5_stop("Frozen bridge authority is expired for this as-of date.")
}
query_start_date <- as.Date(contract$train_start_date[[1L]]) - warmup_days
query_end_date <- as_of_date
output_dir <- g5_bridge_daily_dir(repo_root, quarter_id, as_of_timestamp)

message("Gen5.1 live-advice bridge daily runner")
message("Repository: ", repo_root)
message("Quarter: ", quarter_id)
message("Authority: ", authority_dir)
message("Symbols: ", paste(symbols, collapse = ", "))
message("As of: ", as_of_timestamp)
message("Feed: ", cfg$feed)
message("Query: ", query_start_date, " through ", query_end_date)
message("Refresh: ", refresh)
message("Output: ", output_dir)

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start_date,
  end_date = query_end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = symbols,
  universe_name = paste0("live_bridge_daily_", quarter_id),
  universe_roles = "bridge_context_universe",
  refresh = refresh,
  repo_root = repo_root
)
for (symbol in symbols) {
  g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
}

daily <- g5_bridge_run_daily_from_bars(
  result$bars,
  authority = authority,
  as_of_timestamp = result$resolved_session$as_of_timestamp
)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
query_paths <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = "bridge_daily_query")
paths <- g5_bridge_write_daily_outputs(daily, output_dir)

message("")
message("Bridge book summary:")
print(daily$book_summary, row.names = FALSE)
message("")
message("Pending actions:")
if (is.data.frame(daily$pending_actions) && nrow(daily$pending_actions)) {
  print(daily$pending_actions, row.names = FALSE)
} else {
  message("  None")
}
message("")
message("Daily artifacts written:")
print(as.data.frame(paths), row.names = FALSE)
message("")
message("Query artifacts written:")
print(as.data.frame(query_paths), row.names = FALSE)
