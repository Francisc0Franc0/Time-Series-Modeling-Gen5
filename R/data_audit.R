# Data-quality audit helpers.

g5_audit_bars <- function(
  bars,
  requested_symbols,
  latest_completed_session,
  provider_query_timestamp = NA_character_,
  cache_hits = character()
) {
  if (!is.data.frame(bars)) {
    g5_stop("bars must be a data.frame.")
  }

  requested_symbols <- g5_standardize_symbol(requested_symbols)
  cache_hits <- if (length(cache_hits) == 0L) character() else g5_standardize_symbol(cache_hits)
  present_symbols <- if ("symbol" %in% names(bars)) unique(g5_standardize_symbol(bars$symbol)) else character()
  missing_symbols <- setdiff(requested_symbols, present_symbols)

  duplicate_count <- NA_integer_
  if (all(c("symbol", "session_date") %in% names(bars))) {
    key <- paste(g5_standardize_symbol(bars$symbol), as.Date(bars$session_date))
    duplicate_count <- sum(duplicated(key))
  }

  latest_by_symbol <- if (all(c("symbol", "session_date") %in% names(bars)) && nrow(bars) > 0L) {
    aggregate(as.Date(bars$session_date), list(symbol = g5_standardize_symbol(bars$symbol)), max)
  } else {
    data.frame(symbol = character(), x = as.Date(character()))
  }
  names(latest_by_symbol) <- c("symbol", "latest_cached_session")

  stale_symbols <- latest_by_symbol$symbol[latest_by_symbol$latest_cached_session < as.Date(latest_completed_session)]

  data.frame(
    requested_symbols = paste(requested_symbols, collapse = ","),
    requested_symbol_count = length(requested_symbols),
    present_symbol_count = length(present_symbols),
    missing_symbol_count = length(missing_symbols),
    missing_symbols = paste(missing_symbols, collapse = ","),
    row_count = nrow(bars),
    duplicate_symbol_session_count = duplicate_count,
    latest_completed_session = as.Date(latest_completed_session),
    stale_symbol_count = length(stale_symbols),
    stale_symbols = paste(stale_symbols, collapse = ","),
    cache_hit_symbol_count = length(intersect(requested_symbols, cache_hits)),
    cache_hit_symbols = paste(intersect(requested_symbols, cache_hits), collapse = ","),
    provider_query_timestamp = as.character(provider_query_timestamp),
    stringsAsFactors = FALSE
  )
}
