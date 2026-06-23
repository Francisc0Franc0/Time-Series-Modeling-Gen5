# Gen5 data-refresh entry point scaffold.
# This script intentionally stops before network calls until the provider implementation is added.

source(file.path("R", "data_contract.R"))
source(file.path("R", "calendar.R"))
source(file.path("R", "alpaca_provider.R"))
source(file.path("R", "data_audit.R"))
source(file.path("R", "cache_store.R"))

as_of_timestamp <- Sys.time()
resolved <- g5_resolve_latest_completed_session(as_of_timestamp)
print(resolved)

symbols <- c("SPY", "QQQ", "TSLA", "NVDA")
request <- g5_alpaca_daily_adjusted_request(
  symbols = symbols,
  start_date = as.Date("2020-01-01"),
  end_date = resolved$latest_completed_session,
  as_of_timestamp = as_of_timestamp
)
print(request)

message("Provider fetch is intentionally not implemented yet.")
