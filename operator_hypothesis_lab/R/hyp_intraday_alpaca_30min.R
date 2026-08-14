imom30_stop <- function(message) stop(paste0("[IMOM30] ", message), call. = FALSE)

imom30_et_to_utc <- function(date, clock) {
  x <- as.POSIXct(paste(as.Date(date), clock), tz = "America/New_York")
  if (is.na(x)) imom30_stop("Could not resolve ET timestamp.")
  format(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
}

imom30_request <- function(symbols, start_date, end_date, as_of_timestamp,
                           feed = "sip", adjustment = "all") {
  symbols <- sort(unique(toupper(trimws(as.character(symbols)))))
  start_date <- as.Date(start_date); end_date <- as.Date(end_date)
  if (!length(symbols) || any(!grepl("^[A-Z][A-Z0-9.]{0,9}$", symbols))) imom30_stop("Invalid symbols.")
  if (any(is.na(c(start_date, end_date))) || start_date > end_date) imom30_stop("Invalid request dates.")
  if (missing(as_of_timestamp) || !nzchar(as.character(as_of_timestamp[[1L]]))) imom30_stop("as_of_timestamp is required.")
  if (!identical(feed, "sip") || !identical(adjustment, "all")) imom30_stop("Frozen feed/adjustment changed.")
  data.frame(symbol = symbols, start_date = start_date, end_date = end_date,
             timeframe = "30Min", feed = feed, adjustment = adjustment,
             as_of_timestamp = as.character(as_of_timestamp[[1L]]), stringsAsFactors = FALSE)
}

imom30_feed_comparison_request <- function(symbols, start_date, end_date,
                                           as_of_timestamp, feed) {
  feed <- tolower(trimws(as.character(feed[[1L]])))
  if (!feed %in% c("sip", "iex")) imom30_stop("Comparison feed must be SIP or IEX.")
  request <- imom30_request(symbols, start_date, end_date, as_of_timestamp)
  request$feed <- feed
  request
}

imom30_slots <- function() format(seq(
  as.POSIXct("2000-01-03 09:30:00", tz = "America/New_York"),
  as.POSIXct("2000-01-03 15:30:00", tz = "America/New_York"), by = "30 min"
), "%H:%M:%S")

imom30_early_close_dates <- function() as.Date(c(
  "2018-07-03", "2018-11-23", "2018-12-24",
  "2019-07-03", "2019-11-29", "2019-12-24",
  "2020-11-27", "2020-12-24", "2021-11-26",
  "2022-11-25", "2023-07-03", "2023-11-24"
))

imom30_archive_gap_dates <- function() as.Date(c(
  "2018-05-02", "2018-05-03", "2018-08-07", "2019-08-12", "2019-10-09",
  "2021-04-19", "2021-10-25", "2022-01-24", "2022-01-26", "2022-03-08"
))

imom30_apply_rth_calendar <- function(bars) {
  if (!is.data.frame(bars) || !all(c("session_date", "bar_slot") %in% names(bars))) {
    imom30_stop("RTH calendar filtering requires session_date and bar_slot.")
  }
  date <- as.Date(bars$session_date)
  early <- date %in% imom30_early_close_dates()
  keep <- (!early & bars$bar_slot %in% 1:13) | (early & bars$bar_slot %in% 1:7)
  bars[keep, , drop=FALSE]
}

imom30_apply_archive_exclusions <- function(bars) {
  if (!is.data.frame(bars) || !"session_date" %in% names(bars)) {
    imom30_stop("Archive exclusions require session_date.")
  }
  bars[!as.Date(bars$session_date) %in% imom30_archive_gap_dates(), , drop=FALSE]
}

imom30_empty_bars <- function() data.frame(
  symbol = character(), timestamp_utc = as.POSIXct(character(), tz = "UTC"),
  timestamp_et = character(), session_date = as.Date(character()), bar_time_et = character(),
  bar_slot = integer(), open = numeric(), high = numeric(), low = numeric(), close = numeric(),
  volume = numeric(), trade_count = numeric(), vwap = numeric(), provider = character(),
  feed = character(), timeframe = character(), adjustment = character(),
  as_of_timestamp = character(), stringsAsFactors = FALSE
)

imom30_bar_value <- function(bar, name) {
  value <- bar[[name]]
  if (is.null(value)) NA else value
}

imom30_map_bars <- function(parsed_bars, request) {
  if (!is.list(parsed_bars) || !is.data.frame(request) || !nrow(request)) imom30_stop("Invalid map inputs.")
  slots <- imom30_slots(); rows <- list(); z <- 1L
  for (sym in request$symbol) {
    bars <- parsed_bars[[sym]]
    if (is.null(bars) || !length(bars)) next
    for (bar in bars) {
      ts_text <- substr(as.character(imom30_bar_value(bar, "t")), 1L, 19L)
      ts_utc <- as.POSIXct(ts_text, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      if (is.na(ts_utc)) imom30_stop("Invalid provider timestamp.")
      date_et <- as.Date(format(ts_utc, tz = "America/New_York", format = "%Y-%m-%d"))
      time_et <- format(ts_utc, tz = "America/New_York", format = "%H:%M:%S")
      slot <- match(time_et, slots)
      if (is.na(slot)) next
      rows[[z]] <- data.frame(
        symbol = sym, timestamp_utc = ts_utc,
        timestamp_et = paste(date_et, time_et), session_date = date_et,
        bar_time_et = time_et, bar_slot = as.integer(slot),
        open = as.numeric(imom30_bar_value(bar, "o")), high = as.numeric(imom30_bar_value(bar, "h")),
        low = as.numeric(imom30_bar_value(bar, "l")), close = as.numeric(imom30_bar_value(bar, "c")),
        volume = as.numeric(imom30_bar_value(bar, "v")), trade_count = as.numeric(imom30_bar_value(bar, "n")),
        vwap = as.numeric(imom30_bar_value(bar, "vw")), provider = "alpaca",
        feed = request$feed[[1L]], timeframe = "30Min", adjustment = request$adjustment[[1L]],
        as_of_timestamp = request$as_of_timestamp[[1L]], stringsAsFactors = FALSE
      ); z <- z + 1L
    }
  }
  if (!length(rows)) return(imom30_empty_bars())
  out <- do.call(rbind, rows)
  out[order(out$symbol, out$timestamp_utc), , drop = FALSE]
}

imom30_response_message <- function(text) {
  parsed <- tryCatch(jsonlite::fromJSON(text, simplifyVector = TRUE), error = function(e) NULL)
  if (is.list(parsed) && !is.null(parsed$message)) as.character(parsed$message) else substr(text, 1L, 500L)
}

imom30_fetch <- function(request, config) {
  if (!is.data.frame(request) || !nrow(request) || !all(request$timeframe == "30Min")) imom30_stop("Request must come from imom30_request().")
  if (length(unique(request$feed)) != 1L || !unique(request$feed) %in% c("sip", "iex")) imom30_stop("Request feed must be a single SIP or IEX value.")
  if (!isTRUE(config$has_credentials)) imom30_stop("Alpaca credentials are unavailable.")
  if (!requireNamespace("httr", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) imom30_stop("httr and jsonlite are required.")
  endpoint <- paste0(sub("/+$", "", config$base_url), "/v2/stocks/bars")
  query <- list(
    symbols = paste(request$symbol, collapse = ","), timeframe = "30Min",
    adjustment = "all", feed = unique(request$feed), sort = "asc", limit = 10000L,
    start = imom30_et_to_utc(request$start_date[[1L]], "00:00:00"),
    end = imom30_et_to_utc(request$end_date[[1L]] + 1, "00:00:00"),
    asof = format(request$end_date[[1L]], "%Y-%m-%d")
  )
  all_bars <- list(); token <- NULL; pages <- 0L
  repeat {
    page_query <- query
    if (!is.null(token) && nzchar(token)) page_query$page_token <- token
    response <- httr::GET(endpoint, httr::add_headers(
      `APCA-API-KEY-ID` = config$key_id, `APCA-API-SECRET-KEY` = config$secret_key
    ), query = page_query)
    text <- httr::content(response, as = "text", encoding = "UTF-8")
    if (httr::http_error(response)) imom30_stop(paste("HTTP", httr::status_code(response), imom30_response_message(text)))
    parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
    if (is.null(parsed$bars) || !is.list(parsed$bars)) imom30_stop("Response omitted bars.")
    for (sym in names(parsed$bars)) all_bars[[sym]] <- c(all_bars[[sym]], parsed$bars[[sym]])
    pages <- pages + 1L; token <- parsed$next_page_token
    if (is.null(token) || !nzchar(token)) break
  }
  out <- imom30_map_bars(all_bars, request)
  attr(out, "page_count") <- pages
  out
}

imom30_audit <- function(bars, registry, development_start, development_end, minimum_prehistory = 520L) {
  required <- c("symbol","timestamp_utc","session_date","bar_time_et","bar_slot","open","high","low","close","volume")
  if (!is.data.frame(bars) || !all(required %in% names(bars))) imom30_stop("Bar schema is incomplete.")
  if (!is.data.frame(registry) || !all(c("symbol","asset_type") %in% names(registry))) imom30_stop("Registry schema is incomplete.")
  x <- bars[order(bars$symbol, bars$timestamp_utc), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  spy <- x[x$symbol == "SPY" & x$session_date >= as.Date(development_start) & x$session_date <= as.Date(development_end), , drop = FALSE]
  if (!nrow(spy) || anyDuplicated(spy$timestamp_utc)) imom30_stop("SPY reference calendar is unavailable or duplicated.")
  reference <- as.numeric(spy$timestamp_utc)
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    sym <- registry$symbol[[i]]; y <- x[x$symbol == sym, , drop = FALSE]
    dev <- y[y$session_date >= as.Date(development_start) & y$session_date <= as.Date(development_end), , drop = FALSE]
    pre <- y[y$session_date < as.Date(development_start), , drop = FALSE]
    finite <- nrow(y) > 0L && all(is.finite(y$open) & y$open > 0 & is.finite(y$high) & y$high > 0 &
      is.finite(y$low) & y$low > 0 & is.finite(y$close) & y$close > 0 & is.finite(y$volume) & y$volume >= 0)
    ohlc <- nrow(y) > 0L && all(y$high >= pmax(y$open,y$close,y$low) & y$low <= pmin(y$open,y$close,y$high))
    exact <- identical(as.numeric(dev$timestamp_utc), reference)
    status <- if (!nrow(dev)) "NO_DEVELOPMENT_BARS" else if (anyDuplicated(y$timestamp_utc)) "DUPLICATE_TIMESTAMPS" else if (!finite || !ohlc) "INVALID_OHLCV" else if (nrow(pre) < minimum_prehistory) "PREHISTORY_SHORT" else if (!exact) "CALENDAR_MISMATCH" else "ELIGIBLE"
    data.frame(symbol=sym, asset_type=registry$asset_type[[i]], total_bars=nrow(y), prehistory_bars=nrow(pre),
      development_bars=nrow(dev), missing_reference_bars=sum(!reference %in% as.numeric(dev$timestamp_utc)),
      extra_bars=sum(!as.numeric(dev$timestamp_utc) %in% reference), coverage_status=status,
      analysis_eligible=status == "ELIGIBLE", stringsAsFactors = FALSE)
  })
  coverage <- do.call(rbind, rows)
  counts <- table(spy$session_date)
  sessions <- data.frame(session_date=as.Date(names(counts)), bar_count=as.integer(counts),
    session_type=ifelse(as.integer(counts)==13L,"NORMAL",ifelse(as.integer(counts)==7L,"EARLY_CLOSE","IRREGULAR")), stringsAsFactors=FALSE)
  list(coverage=coverage, sessions=sessions,
       integrity=data.frame(check=c("no_confirmation","spy_session_counts","rth_slot_grid"), passed=c(
         all(x$session_date < as.Date("2024-01-02")), all(sessions$session_type != "IRREGULAR"),
         all(x$bar_slot %in% 1:13)), stringsAsFactors=FALSE))
}
