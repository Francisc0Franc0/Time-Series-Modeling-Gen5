# Read-only Alpaca historical-options capability probe.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE) else normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "alpaca_options_provider.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

g5_load_local_renviron(repo_root)
as_of_timestamp <- env_or("GEN5_GEN54_OPTIONS_AS_OF", "2026-07-26 17:30:00")
retrieved_at <- env_or("GEN5_GEN54_OPTIONS_RETRIEVED_AT", "2026-07-26 17:30:00")
underlying <- env_or("GEN5_GEN54_OPTIONS_PROBE_UNDERLYING", "SPY")
expiration <- as.Date(env_or("GEN5_GEN54_OPTIONS_PROBE_EXPIRATION", "2026-06-19"))
contract_status <- env_or("GEN5_GEN54_OPTIONS_PROBE_STATUS", "inactive")
request <- g5_alpaca_option_contracts_request(
  underlying_symbols = underlying,
  expiration_date_gte = expiration,
  expiration_date_lte = expiration,
  as_of_timestamp = as_of_timestamp,
  status = contract_status,
  limit = 100L
)
contracts <- g5_fetch_alpaca_option_contracts(request, retrieved_at = retrieved_at)
message("contracts_http=PASS rows=", nrow(contracts$data), " pages=", nrow(contracts$pages))
if (!nrow(contracts$data)) {
  message("option_bars=SKIP reason=no_contracts")
  quit(status = 2L)
}

probe_symbols <- head(contracts$data$option_symbol, 100L)
entitlement <- g5_probe_alpaca_option_feed_entitlement(probe_symbols[[1L]])
message(
  "feed_entitlement=", entitlement$resolved_feed,
  " opra_http=", entitlement$probes$http_status[entitlement$probes$feed == "opra"],
  " indicative_http=", entitlement$probes$http_status[entitlement$probes$feed == "indicative"]
)
if (identical(entitlement$resolved_feed, "unavailable")) {
  message("option_bars=SKIP reason=no_option_feed_entitlement")
  quit(status = 3L)
}
bar_date <- as.Date(env_or(
  "GEN5_GEN54_OPTIONS_PROBE_BAR_DATE",
  as.character(min(expiration - 1L, as.Date(substr(as_of_timestamp, 1L, 10L)) - 1L))
))
bar_request <- g5_alpaca_option_bars_request(
  option_symbols = probe_symbols,
  start_timestamp = paste0(bar_date, "T13:30:00Z"),
  end_timestamp = paste0(bar_date, "T20:00:00Z"),
  as_of_timestamp = as_of_timestamp,
  timeframe = "15Min",
  feed = entitlement$resolved_feed
)
bars <- g5_fetch_alpaca_option_bars(bar_request, retrieved_at = retrieved_at)
message(
  "option_bars_http=PASS feed=", entitlement$resolved_feed,
  " rows=", nrow(bars$data),
  " pages=", nrow(bars$pages),
  " requested_symbols=", length(probe_symbols),
  " returned_symbols=", length(unique(bars$data$option_symbol))
)
message("secrets=not_printed")
