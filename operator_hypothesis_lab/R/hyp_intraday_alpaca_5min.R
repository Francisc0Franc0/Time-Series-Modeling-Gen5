imom5_stop <- function(message) stop(paste0("[IMOM5] ", message), call. = FALSE)

imom5_et_to_utc <- function(date, clock) {
  x <- as.POSIXct(paste(as.Date(date), clock), tz = "America/New_York")
  if (is.na(x)) imom5_stop("Could not resolve ET timestamp.")
  format(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
}

imom5_request <- function(symbols, start_date, end_date, as_of_timestamp,
                          feed = "sip", adjustment = "all") {
  symbols <- sort(unique(toupper(trimws(as.character(symbols)))))
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  if (!length(symbols) || any(!grepl("^[A-Z][A-Z0-9.]{0,9}$", symbols))) {
    imom5_stop("Invalid symbols.")
  }
  if (any(is.na(c(start_date, end_date))) || start_date > end_date) {
    imom5_stop("Invalid request dates.")
  }
  if (missing(as_of_timestamp) || !nzchar(as.character(as_of_timestamp[[1L]]))) {
    imom5_stop("as_of_timestamp is required.")
  }
  if (!identical(feed, "sip") || !identical(adjustment, "all")) {
    imom5_stop("Frozen feed/adjustment changed.")
  }
  data.frame(
    symbol = symbols, start_date = start_date, end_date = end_date,
    timeframe = "5Min", feed = feed, adjustment = adjustment,
    as_of_timestamp = as.character(as_of_timestamp[[1L]]),
    stringsAsFactors = FALSE
  )
}

imom5_slots <- function() format(seq(
  as.POSIXct("2000-01-03 09:30:00", tz = "America/New_York"),
  as.POSIXct("2000-01-03 15:55:00", tz = "America/New_York"),
  by = "5 min"
), "%H:%M:%S")

imom5_empty_bars <- function() data.frame(
  symbol = character(), timestamp_utc = as.POSIXct(character(), tz = "UTC"),
  timestamp_et = character(), session_date = as.Date(character()),
  bar_time_et = character(), bar_slot = integer(), open = numeric(),
  high = numeric(), low = numeric(), close = numeric(), volume = numeric(),
  trade_count = numeric(), vwap = numeric(), provider = character(),
  feed = character(), timeframe = character(), adjustment = character(),
  as_of_timestamp = character(), stringsAsFactors = FALSE
)

imom5_bar_value <- function(bar, name) {
  value <- bar[[name]]
  if (is.null(value)) NA else value
}

imom5_map_bars <- function(parsed_bars, request) {
  if (!is.list(parsed_bars) || !is.data.frame(request) || !nrow(request)) {
    imom5_stop("Invalid map inputs.")
  }
  slots <- imom5_slots()
  rows <- list()
  z <- 1L
  for (sym in request$symbol) {
    bars <- parsed_bars[[sym]]
    if (is.null(bars) || !length(bars)) next
    for (bar in bars) {
      ts_text <- substr(as.character(imom5_bar_value(bar, "t")), 1L, 19L)
      ts_utc <- as.POSIXct(ts_text, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      if (is.na(ts_utc)) imom5_stop("Invalid provider timestamp.")
      date_et <- as.Date(format(ts_utc, tz = "America/New_York", format = "%Y-%m-%d"))
      time_et <- format(ts_utc, tz = "America/New_York", format = "%H:%M:%S")
      slot <- match(time_et, slots)
      if (is.na(slot)) next
      rows[[z]] <- data.frame(
        symbol = sym, timestamp_utc = ts_utc,
        timestamp_et = paste(date_et, time_et), session_date = date_et,
        bar_time_et = time_et, bar_slot = as.integer(slot),
        open = as.numeric(imom5_bar_value(bar, "o")),
        high = as.numeric(imom5_bar_value(bar, "h")),
        low = as.numeric(imom5_bar_value(bar, "l")),
        close = as.numeric(imom5_bar_value(bar, "c")),
        volume = as.numeric(imom5_bar_value(bar, "v")),
        trade_count = as.numeric(imom5_bar_value(bar, "n")),
        vwap = as.numeric(imom5_bar_value(bar, "vw")),
        provider = "alpaca", feed = request$feed[[1L]], timeframe = "5Min",
        adjustment = request$adjustment[[1L]],
        as_of_timestamp = request$as_of_timestamp[[1L]], stringsAsFactors = FALSE
      )
      z <- z + 1L
    }
  }
  if (!length(rows)) return(imom5_empty_bars())
  out <- do.call(rbind, rows)
  out[order(out$symbol, out$timestamp_utc), , drop = FALSE]
}

imom5_response_message <- function(text) {
  parsed <- tryCatch(jsonlite::fromJSON(text, simplifyVector = TRUE), error = function(e) NULL)
  if (is.list(parsed) && !is.null(parsed$message)) {
    as.character(parsed$message)
  } else {
    substr(text, 1L, 500L)
  }
}

imom5_fetch <- function(request, config) {
  if (!is.data.frame(request) || !nrow(request) || !all(request$timeframe == "5Min")) {
    imom5_stop("Request must come from imom5_request().")
  }
  if (length(unique(request$feed)) != 1L || !identical(unique(request$feed), "sip")) {
    imom5_stop("Request feed must be SIP.")
  }
  if (!isTRUE(config$has_credentials)) imom5_stop("Alpaca credentials are unavailable.")
  if (!requireNamespace("httr", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) {
    imom5_stop("httr and jsonlite are required.")
  }
  endpoint <- paste0(sub("/+$", "", config$base_url), "/v2/stocks/bars")
  query <- list(
    symbols = paste(request$symbol, collapse = ","), timeframe = "5Min",
    adjustment = "all", feed = "sip", sort = "asc", limit = 10000L,
    start = imom5_et_to_utc(request$start_date[[1L]], "00:00:00"),
    end = imom5_et_to_utc(request$end_date[[1L]] + 1, "00:00:00"),
    asof = format(request$end_date[[1L]], "%Y-%m-%d")
  )
  all_bars <- list()
  token <- NULL
  seen_tokens <- character()
  pages <- 0L
  repeat {
    page_query <- query
    if (!is.null(token) && nzchar(token)) page_query$page_token <- token
    response <- httr::GET(
      endpoint,
      httr::add_headers(
        `APCA-API-KEY-ID` = config$key_id,
        `APCA-API-SECRET-KEY` = config$secret_key
      ),
      httr::timeout(60),
      query = page_query
    )
    text <- httr::content(response, as = "text", encoding = "UTF-8")
    if (httr::http_error(response)) {
      imom5_stop(paste("HTTP", httr::status_code(response), imom5_response_message(text)))
    }
    parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
    if (is.null(parsed$bars) || !is.list(parsed$bars)) imom5_stop("Response omitted bars.")
    for (sym in names(parsed$bars)) {
      all_bars[[sym]] <- c(all_bars[[sym]], parsed$bars[[sym]])
    }
    pages <- pages + 1L
    token <- parsed$next_page_token
    if (is.null(token) || !nzchar(token)) break
    if (token %in% seen_tokens) imom5_stop("Provider repeated a pagination token.")
    seen_tokens <- c(seen_tokens, token)
    if (pages >= 200L) imom5_stop("Pagination exceeded the frozen safety limit.")
  }
  out <- imom5_map_bars(all_bars, request)
  attr(out, "page_count") <- pages
  out
}
