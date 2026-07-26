# Alpaca research-only historical options provider boundary.
#
# This module does not alter the canonical adjusted-daily OHLCV contract. It
# retrieves immutable option-contract definitions and historical option bars
# for an explicitly bounded, non-live proof of concept.

.g5_alpaca_options_time <- function(value, field_name) {
  if (missing(value) || is.null(value) || length(value) != 1L || !nzchar(as.character(value))) {
    g5_stop(paste0(field_name, " is required."))
  }
  parsed <- as.POSIXct(
    as.character(value),
    tz = "UTC",
    tryFormats = c(
      "%Y-%m-%dT%H:%M:%OSZ",
      "%Y-%m-%dT%H:%M:%S%z",
      "%Y-%m-%d %H:%M:%S",
      "%Y-%m-%d"
    )
  )
  if (is.na(parsed)) g5_stop(paste0(field_name, " must be a valid explicit timestamp."))
  parsed
}

.g5_alpaca_options_validate_window <- function(start_timestamp, end_timestamp, as_of_timestamp) {
  start <- .g5_alpaca_options_time(start_timestamp, "start_timestamp")
  end <- .g5_alpaca_options_time(end_timestamp, "end_timestamp")
  as_of <- .g5_alpaca_options_time(as_of_timestamp, "as_of_timestamp")
  if (start > end) g5_stop("start_timestamp must be on or before end_timestamp.")
  if (end > as_of) g5_stop("end_timestamp cannot be after as_of_timestamp.")
  invisible(TRUE)
}

.g5_alpaca_options_headers <- function(config) {
  httr::add_headers(
    `APCA-API-KEY-ID` = config$key_id,
    `APCA-API-SECRET-KEY` = config$secret_key
  )
}

.g5_alpaca_option_value <- function(object, name, default = NA_character_) {
  value <- object[[name]]
  if (is.null(value) || !length(value)) default else value
}

g5_alpaca_option_contracts_request <- function(
  underlying_symbols,
  expiration_date_gte,
  expiration_date_lte,
  as_of_timestamp,
  status = "inactive",
  limit = 1000L
) {
  underlying_symbols <- g5_standardize_symbol(underlying_symbols)
  if (!length(underlying_symbols)) g5_stop("At least one underlying symbol is required.")
  expiration_date_gte <- as.Date(expiration_date_gte)
  expiration_date_lte <- as.Date(expiration_date_lte)
  if (any(is.na(c(expiration_date_gte, expiration_date_lte))) ||
      expiration_date_gte > expiration_date_lte) {
    g5_stop("Option expiration dates must be valid and ordered.")
  }
  .g5_alpaca_options_time(as_of_timestamp, "as_of_timestamp")
  status <- match.arg(as.character(status), c("active", "inactive"))
  limit <- as.integer(limit)
  if (is.na(limit) || limit < 1L || limit > 10000L) {
    g5_stop("Option contract page limit must be between 1 and 10000.")
  }
  data.frame(
    provider = "alpaca",
    endpoint = "/v2/options/contracts",
    underlying_symbols = paste(underlying_symbols, collapse = ","),
    expiration_date_gte = as.character(expiration_date_gte),
    expiration_date_lte = as.character(expiration_date_lte),
    as_of_timestamp = as.character(as_of_timestamp),
    status = status,
    limit = limit,
    stringsAsFactors = FALSE
  )
}

g5_alpaca_empty_option_contracts <- function() {
  data.frame(
    option_symbol = character(),
    underlying_symbol = character(),
    expiration_date = as.Date(character()),
    strike_price = numeric(),
    option_type = character(),
    exercise_style = character(),
    contract_size = numeric(),
    status_at_retrieval = character(),
    provider = character(),
    as_of_timestamp = character(),
    retrieved_at = character(),
    stringsAsFactors = FALSE
  )
}

g5_alpaca_map_option_contracts_payload <- function(parsed, request, retrieved_at) {
  if (!is.list(parsed)) g5_stop("Parsed Alpaca option-contract payload must be a list.")
  if (!is.data.frame(request) || nrow(request) != 1L) {
    g5_stop("Option-contract request must contain exactly one row.")
  }
  .g5_alpaca_options_time(retrieved_at, "retrieved_at")
  contracts <- parsed$option_contracts
  if (is.null(contracts) || !length(contracts)) return(g5_alpaca_empty_option_contracts())
  rows <- lapply(contracts, function(contract) {
    expiration_date <- as.Date(as.character(.g5_alpaca_option_value(contract, "expiration_date")))
    strike_price <- suppressWarnings(as.numeric(.g5_alpaca_option_value(contract, "strike_price")))
    if (is.na(expiration_date) || !is.finite(strike_price)) {
      g5_stop("Alpaca option-contract response contains an invalid expiry or strike.")
    }
    data.frame(
      option_symbol = as.character(.g5_alpaca_option_value(contract, "symbol")),
      underlying_symbol = toupper(as.character(.g5_alpaca_option_value(contract, "underlying_symbol"))),
      expiration_date = expiration_date,
      strike_price = strike_price,
      option_type = tolower(as.character(.g5_alpaca_option_value(contract, "type"))),
      exercise_style = tolower(as.character(.g5_alpaca_option_value(contract, "style"))),
      contract_size = suppressWarnings(as.numeric(.g5_alpaca_option_value(contract, "size"))),
      status_at_retrieval = tolower(as.character(.g5_alpaca_option_value(contract, "status"))),
      provider = "alpaca",
      as_of_timestamp = request$as_of_timestamp[[1L]],
      retrieved_at = as.character(retrieved_at),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$underlying_symbol, out$expiration_date, out$strike_price, out$option_type), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_fetch_alpaca_option_contracts <- function(
  request,
  retrieved_at,
  config = g5_alpaca_config_from_env(),
  trading_base_url = Sys.getenv("ALPACA_TRADING_BASE_URL", unset = "https://api.alpaca.markets"),
  request_pause_seconds = 0
) {
  if (!is.data.frame(request) || nrow(request) != 1L ||
      request$endpoint[[1L]] != "/v2/options/contracts") {
    g5_stop("request must be produced by g5_alpaca_option_contracts_request().")
  }
  g5_alpaca_preflight_live_fetch(config)
  .g5_alpaca_options_time(retrieved_at, "retrieved_at")
  endpoint <- paste0(sub("/+$", "", trading_base_url), request$endpoint[[1L]])
  base_query <- list(
    underlying_symbols = request$underlying_symbols[[1L]],
    status = request$status[[1L]],
    expiration_date_gte = request$expiration_date_gte[[1L]],
    expiration_date_lte = request$expiration_date_lte[[1L]],
    limit = request$limit[[1L]]
  )
  page_token <- NULL
  seen_tokens <- character()
  pages <- list()
  frames <- list()
  repeat {
    query <- base_query
    if (!is.null(page_token) && nzchar(page_token)) query$page_token <- page_token
    response <- httr::GET(
      endpoint,
      .g5_alpaca_options_headers(config),
      query = query,
      httr::timeout(30)
    )
    response_text <- httr::content(response, as = "text", encoding = "UTF-8")
    status <- httr::status_code(response)
    if (httr::http_error(response)) {
      g5_stop(paste(
        "Alpaca option-contract request failed with HTTP",
        status, "-", g5_alpaca_response_message(response_text)
      ))
    }
    parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
    frames[[length(frames) + 1L]] <- g5_alpaca_map_option_contracts_payload(
      parsed, request, retrieved_at
    )
    next_token <- parsed$next_page_token
    next_token <- if (is.null(next_token) || !nzchar(as.character(next_token))) {
      ""
    } else {
      as.character(next_token)
    }
    pages[[length(pages) + 1L]] <- data.frame(
      page_number = length(pages) + 1L,
      http_status = status,
      rows = nrow(frames[[length(frames)]]),
      response_bytes = nchar(response_text, type = "bytes"),
      stringsAsFactors = FALSE
    )
    if (!nzchar(next_token)) break
    if (next_token %in% seen_tokens) g5_stop("Alpaca option-contract pagination repeated a page token.")
    seen_tokens <- c(seen_tokens, next_token)
    page_token <- next_token
    if (request_pause_seconds > 0) Sys.sleep(request_pause_seconds)
  }
  data <- if (!length(frames) || all(vapply(frames, nrow, integer(1L)) == 0L)) {
    g5_alpaca_empty_option_contracts()
  } else {
    do.call(rbind, frames[vapply(frames, nrow, integer(1L)) > 0L])
  }
  rownames(data) <- NULL
  list(
    data = data,
    pages = do.call(rbind, pages),
    endpoint = endpoint
  )
}

g5_alpaca_option_bars_request <- function(
  option_symbols,
  start_timestamp,
  end_timestamp,
  as_of_timestamp,
  timeframe = "15Min",
  feed = "account_default",
  limit = 10000L
) {
  option_symbols <- unique(toupper(trimws(as.character(option_symbols))))
  option_symbols <- option_symbols[!is.na(option_symbols) & nzchar(option_symbols)]
  if (!length(option_symbols)) g5_stop("At least one option symbol is required.")
  if (length(option_symbols) > 100L) g5_stop("At most 100 option symbols may be requested at once.")
  .g5_alpaca_options_validate_window(start_timestamp, end_timestamp, as_of_timestamp)
  timeframe <- as.character(timeframe[[1L]])
  if (!grepl("^([1-5]?[0-9])Min$|^[1-9][0-9]*Hour$|^1Day$", timeframe)) {
    g5_stop("Unsupported option-bar timeframe.")
  }
  feed <- match.arg(
    tolower(as.character(feed[[1L]])),
    c("account_default", "opra", "indicative")
  )
  limit <- as.integer(limit)
  if (is.na(limit) || limit < 1L || limit > 10000L) {
    g5_stop("Option bar page limit must be between 1 and 10000.")
  }
  data.frame(
    provider = "alpaca",
    endpoint = "/v1beta1/options/bars",
    symbols = paste(option_symbols, collapse = ","),
    start_timestamp = as.character(start_timestamp),
    end_timestamp = as.character(end_timestamp),
    as_of_timestamp = as.character(as_of_timestamp),
    timeframe = timeframe,
    feed = feed,
    limit = limit,
    sort = "asc",
    stringsAsFactors = FALSE
  )
}

g5_alpaca_empty_option_bars <- function() {
  data.frame(
    option_symbol = character(),
    bar_timestamp = character(),
    open = numeric(),
    high = numeric(),
    low = numeric(),
    close = numeric(),
    volume = numeric(),
    trade_count = numeric(),
    vwap = numeric(),
    provider = character(),
    feed = character(),
    as_of_timestamp = character(),
    retrieved_at = character(),
    stringsAsFactors = FALSE
  )
}

g5_alpaca_map_option_bars_payload <- function(parsed, request, retrieved_at) {
  if (!is.list(parsed)) g5_stop("Parsed Alpaca option-bars payload must be a list.")
  if (!is.data.frame(request) || nrow(request) != 1L) {
    g5_stop("Option-bars request must contain exactly one row.")
  }
  .g5_alpaca_options_time(retrieved_at, "retrieved_at")
  bars_by_symbol <- parsed$bars
  if (is.null(bars_by_symbol) || !length(bars_by_symbol)) return(g5_alpaca_empty_option_bars())
  rows <- list()
  idx <- 1L
  for (symbol in names(bars_by_symbol)) {
    symbol_bars <- bars_by_symbol[[symbol]]
    if (is.null(symbol_bars) || !length(symbol_bars)) next
    for (bar in symbol_bars) {
      rows[[idx]] <- data.frame(
        option_symbol = toupper(symbol),
        bar_timestamp = as.character(.g5_alpaca_option_value(bar, "t")),
        open = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "o"))),
        high = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "h"))),
        low = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "l"))),
        close = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "c"))),
        volume = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "v"))),
        trade_count = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "n"))),
        vwap = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "vw"))),
        provider = "alpaca",
        feed = request$feed[[1L]],
        as_of_timestamp = request$as_of_timestamp[[1L]],
        retrieved_at = as.character(retrieved_at),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  if (!length(rows)) return(g5_alpaca_empty_option_bars())
  out <- do.call(rbind, rows)
  out <- out[order(out$bar_timestamp, out$option_symbol), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_fetch_alpaca_option_bars <- function(
  request,
  retrieved_at,
  config = g5_alpaca_config_from_env(),
  request_pause_seconds = 0
) {
  if (!is.data.frame(request) || nrow(request) != 1L ||
      request$endpoint[[1L]] != "/v1beta1/options/bars") {
    g5_stop("request must be produced by g5_alpaca_option_bars_request().")
  }
  g5_alpaca_preflight_live_fetch(config)
  .g5_alpaca_options_time(retrieved_at, "retrieved_at")
  endpoint <- paste0(sub("/+$", "", config$base_url), request$endpoint[[1L]])
  base_query <- list(
    symbols = request$symbols[[1L]],
    timeframe = request$timeframe[[1L]],
    start = request$start_timestamp[[1L]],
    end = request$end_timestamp[[1L]],
    limit = request$limit[[1L]],
    sort = request$sort[[1L]]
  )
  page_token <- NULL
  seen_tokens <- character()
  pages <- list()
  frames <- list()
  repeat {
    query <- base_query
    if (!is.null(page_token) && nzchar(page_token)) query$page_token <- page_token
    response <- httr::GET(
      endpoint,
      .g5_alpaca_options_headers(config),
      query = query,
      httr::timeout(30)
    )
    response_text <- httr::content(response, as = "text", encoding = "UTF-8")
    status <- httr::status_code(response)
    if (httr::http_error(response)) {
      g5_stop(paste(
        "Alpaca option-bars request failed with HTTP",
        status, "-", g5_alpaca_response_message(response_text)
      ))
    }
    parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
    frames[[length(frames) + 1L]] <- g5_alpaca_map_option_bars_payload(
      parsed, request, retrieved_at
    )
    next_token <- parsed$next_page_token
    next_token <- if (is.null(next_token) || !nzchar(as.character(next_token))) {
      ""
    } else {
      as.character(next_token)
    }
    pages[[length(pages) + 1L]] <- data.frame(
      page_number = length(pages) + 1L,
      http_status = status,
      rows = nrow(frames[[length(frames)]]),
      response_bytes = nchar(response_text, type = "bytes"),
      stringsAsFactors = FALSE
    )
    if (!nzchar(next_token)) break
    if (next_token %in% seen_tokens) g5_stop("Alpaca option-bar pagination repeated a page token.")
    seen_tokens <- c(seen_tokens, next_token)
    page_token <- next_token
    if (request_pause_seconds > 0) Sys.sleep(request_pause_seconds)
  }
  data <- if (!length(frames) || all(vapply(frames, nrow, integer(1L)) == 0L)) {
    g5_alpaca_empty_option_bars()
  } else {
    do.call(rbind, frames[vapply(frames, nrow, integer(1L)) > 0L])
  }
  rownames(data) <- NULL
  list(
    data = data,
    pages = do.call(rbind, pages),
    endpoint = endpoint
  )
}

g5_probe_alpaca_option_feed_entitlement <- function(
  option_symbol,
  config = g5_alpaca_config_from_env()
) {
  option_symbol <- unique(toupper(trimws(as.character(option_symbol))))
  option_symbol <- option_symbol[!is.na(option_symbol) & nzchar(option_symbol)]
  if (length(option_symbol) != 1L) g5_stop("Exactly one option symbol is required.")
  g5_alpaca_preflight_live_fetch(config)
  endpoint <- paste0(
    sub("/+$", "", config$base_url),
    "/v1beta1/options/snapshots"
  )
  probe_one <- function(feed) {
    response <- httr::GET(
      endpoint,
      .g5_alpaca_options_headers(config),
      query = list(symbols = option_symbol, feed = feed, limit = 1L),
      httr::timeout(30)
    )
    response_text <- httr::content(response, as = "text", encoding = "UTF-8")
    data.frame(
      feed = feed,
      http_status = httr::status_code(response),
      authorized = !httr::http_error(response),
      response_message = if (httr::http_error(response)) {
        g5_alpaca_response_message(response_text)
      } else {
        "OK"
      },
      stringsAsFactors = FALSE
    )
  }
  probes <- do.call(rbind, lapply(c("opra", "indicative"), probe_one))
  resolved_feed <- if (isTRUE(probes$authorized[probes$feed == "opra"])) {
    "opra"
  } else if (isTRUE(probes$authorized[probes$feed == "indicative"])) {
    "indicative"
  } else {
    "unavailable"
  }
  list(
    resolved_feed = resolved_feed,
    probes = probes,
    endpoint = endpoint,
    resolution_rule = paste(
      "Historical option bars use the account-default feed because the endpoint",
      "does not accept a feed parameter. Feed identity is inferred from the",
      "current account entitlement probe against the feed-selectable snapshot endpoint."
    )
  )
}

g5_alpaca_option_underlying_bars_request <- function(
  symbols,
  start_timestamp,
  end_timestamp,
  as_of_timestamp,
  timeframe = "15Min",
  feed = "sip",
  limit = 10000L
) {
  symbols <- g5_standardize_symbol(symbols)
  if (!length(symbols)) g5_stop("At least one option underlying is required.")
  if (length(symbols) > 100L) g5_stop("At most 100 option underlyings may be requested at once.")
  .g5_alpaca_options_validate_window(start_timestamp, end_timestamp, as_of_timestamp)
  timeframe <- as.character(timeframe[[1L]])
  if (!grepl("^([1-5]?[0-9])Min$|^[1-9][0-9]*Hour$|^1Day$", timeframe)) {
    g5_stop("Unsupported option-underlying bar timeframe.")
  }
  feed <- match.arg(tolower(as.character(feed[[1L]])), c("sip", "iex"))
  limit <- as.integer(limit)
  if (is.na(limit) || limit < 1L || limit > 10000L) {
    g5_stop("Option-underlying bar page limit must be between 1 and 10000.")
  }
  data.frame(
    provider = "alpaca",
    endpoint = "/v2/stocks/bars",
    symbols = paste(symbols, collapse = ","),
    start_timestamp = as.character(start_timestamp),
    end_timestamp = as.character(end_timestamp),
    as_of_timestamp = as.character(as_of_timestamp),
    timeframe = timeframe,
    feed = feed,
    adjustment = "raw",
    limit = limit,
    sort = "asc",
    stringsAsFactors = FALSE
  )
}

g5_alpaca_empty_option_underlying_bars <- function() {
  data.frame(
    symbol = character(),
    bar_timestamp = character(),
    open = numeric(),
    high = numeric(),
    low = numeric(),
    close = numeric(),
    volume = numeric(),
    trade_count = numeric(),
    vwap = numeric(),
    provider = character(),
    feed = character(),
    adjustment = character(),
    as_of_timestamp = character(),
    retrieved_at = character(),
    stringsAsFactors = FALSE
  )
}

g5_alpaca_map_option_underlying_bars_payload <- function(parsed, request, retrieved_at) {
  if (!is.list(parsed)) g5_stop("Parsed Alpaca option-underlying payload must be a list.")
  if (!is.data.frame(request) || nrow(request) != 1L) {
    g5_stop("Option-underlying request must contain exactly one row.")
  }
  .g5_alpaca_options_time(retrieved_at, "retrieved_at")
  bars_by_symbol <- parsed$bars
  if (is.null(bars_by_symbol) || !length(bars_by_symbol)) {
    return(g5_alpaca_empty_option_underlying_bars())
  }
  rows <- list()
  idx <- 1L
  for (symbol in names(bars_by_symbol)) {
    symbol_bars <- bars_by_symbol[[symbol]]
    if (is.null(symbol_bars) || !length(symbol_bars)) next
    for (bar in symbol_bars) {
      rows[[idx]] <- data.frame(
        symbol = toupper(symbol),
        bar_timestamp = as.character(.g5_alpaca_option_value(bar, "t")),
        open = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "o"))),
        high = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "h"))),
        low = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "l"))),
        close = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "c"))),
        volume = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "v"))),
        trade_count = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "n"))),
        vwap = suppressWarnings(as.numeric(.g5_alpaca_option_value(bar, "vw"))),
        provider = "alpaca",
        feed = request$feed[[1L]],
        adjustment = request$adjustment[[1L]],
        as_of_timestamp = request$as_of_timestamp[[1L]],
        retrieved_at = as.character(retrieved_at),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  if (!length(rows)) return(g5_alpaca_empty_option_underlying_bars())
  out <- do.call(rbind, rows)
  out <- out[order(out$bar_timestamp, out$symbol), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_fetch_alpaca_option_underlying_bars <- function(
  request,
  retrieved_at,
  config = g5_alpaca_config_from_env(),
  request_pause_seconds = 0
) {
  if (!is.data.frame(request) || nrow(request) != 1L ||
      request$endpoint[[1L]] != "/v2/stocks/bars") {
    g5_stop("request must be produced by g5_alpaca_option_underlying_bars_request().")
  }
  g5_alpaca_preflight_live_fetch(config)
  .g5_alpaca_options_time(retrieved_at, "retrieved_at")
  endpoint <- paste0(sub("/+$", "", config$base_url), request$endpoint[[1L]])
  base_query <- list(
    symbols = request$symbols[[1L]],
    timeframe = request$timeframe[[1L]],
    start = request$start_timestamp[[1L]],
    end = request$end_timestamp[[1L]],
    limit = request$limit[[1L]],
    sort = request$sort[[1L]],
    feed = request$feed[[1L]],
    adjustment = request$adjustment[[1L]]
  )
  page_token <- NULL
  seen_tokens <- character()
  pages <- list()
  frames <- list()
  repeat {
    query <- base_query
    if (!is.null(page_token) && nzchar(page_token)) query$page_token <- page_token
    response <- httr::GET(
      endpoint,
      .g5_alpaca_options_headers(config),
      query = query,
      httr::timeout(30)
    )
    response_text <- httr::content(response, as = "text", encoding = "UTF-8")
    status <- httr::status_code(response)
    if (httr::http_error(response)) {
      g5_stop(paste(
        "Alpaca option-underlying request failed with HTTP",
        status, "-", g5_alpaca_response_message(response_text)
      ))
    }
    parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
    frames[[length(frames) + 1L]] <- g5_alpaca_map_option_underlying_bars_payload(
      parsed, request, retrieved_at
    )
    next_token <- parsed$next_page_token
    next_token <- if (is.null(next_token) || !nzchar(as.character(next_token))) {
      ""
    } else {
      as.character(next_token)
    }
    pages[[length(pages) + 1L]] <- data.frame(
      page_number = length(pages) + 1L,
      http_status = status,
      rows = nrow(frames[[length(frames)]]),
      response_bytes = nchar(response_text, type = "bytes"),
      stringsAsFactors = FALSE
    )
    if (!nzchar(next_token)) break
    if (next_token %in% seen_tokens) {
      g5_stop("Alpaca option-underlying pagination repeated a page token.")
    }
    seen_tokens <- c(seen_tokens, next_token)
    page_token <- next_token
    if (request_pause_seconds > 0) Sys.sleep(request_pause_seconds)
  }
  data <- if (!length(frames) || all(vapply(frames, nrow, integer(1L)) == 0L)) {
    g5_alpaca_empty_option_underlying_bars()
  } else {
    do.call(rbind, frames[vapply(frames, nrow, integer(1L)) > 0L])
  }
  rownames(data) <- NULL
  list(data = data, pages = do.call(rbind, pages), endpoint = endpoint)
}
