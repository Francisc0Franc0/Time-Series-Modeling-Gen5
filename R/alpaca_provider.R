# Alpaca provider boundary.
# Network fetching is intentionally not implemented in the first scaffold.

g5_alpaca_config_from_env <- function() {
  key_id <- Sys.getenv("ALPACA_KEY_ID", unset = "")
  secret_key <- Sys.getenv("ALPACA_SECRET_KEY", unset = "")
  base_url <- Sys.getenv("ALPACA_DATA_BASE_URL", unset = "https://data.alpaca.markets")

  list(
    key_id = key_id,
    secret_key = secret_key,
    base_url = base_url,
    has_credentials = nzchar(key_id) && nzchar(secret_key)
  )
}

g5_alpaca_daily_adjusted_request <- function(symbols, start_date, end_date, as_of_timestamp) {
  symbols <- g5_standardize_symbol(symbols)
  if (missing(as_of_timestamp) || is.null(as_of_timestamp)) {
    g5_stop("as_of_timestamp is required for Alpaca requests.")
  }

  data.frame(
    provider = "alpaca",
    symbol = symbols,
    timeframe = "1D",
    adjustment = "all",
    start_date = as.Date(start_date),
    end_date = as.Date(end_date),
    as_of_timestamp = as.character(as_of_timestamp),
    stringsAsFactors = FALSE
  )
}

g5_fetch_alpaca_daily_adjusted_bars <- function(request, config = g5_alpaca_config_from_env()) {
  if (!is.data.frame(request)) {
    g5_stop("request must be produced by g5_alpaca_daily_adjusted_request().")
  }
  if (!isTRUE(config$has_credentials)) {
    g5_stop("Alpaca credentials are not configured in environment variables.")
  }

  g5_stop("Alpaca network fetching is not implemented in this scaffold. Implement after the data contract tests are accepted.")
}
