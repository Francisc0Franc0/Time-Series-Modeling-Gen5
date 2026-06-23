# Alpaca provider boundary.

g5_alpaca_config_from_env <- function() {
  key_id <- Sys.getenv("ALPACA_KEY_ID", unset = "")
  if (!nzchar(key_id)) {
    key_id <- Sys.getenv("ALPACA_KEY", unset = "")
  }
  secret_key <- Sys.getenv("ALPACA_SECRET_KEY", unset = "")
  if (!nzchar(secret_key)) {
    secret_key <- Sys.getenv("ALPACA_SECRET", unset = "")
  }
  base_url <- Sys.getenv("ALPACA_DATA_BASE_URL", unset = "https://data.alpaca.markets")
  feed <- Sys.getenv("ALPACA_DATA_FEED", unset = "iex")

  list(
    key_id = key_id,
    secret_key = secret_key,
    base_url = base_url,
    feed = feed,
    has_credentials = nzchar(key_id) && nzchar(secret_key)
  )
}

g5_alpaca_daily_adjusted_request <- function(
  symbols,
  start_date,
  end_date,
  as_of_timestamp,
  latest_completed_session = end_date,
  feed = Sys.getenv("ALPACA_DATA_FEED", unset = "iex")
) {
  symbols <- g5_standardize_symbol(symbols)
  if (missing(as_of_timestamp) || is.null(as_of_timestamp)) {
    g5_stop("as_of_timestamp is required for Alpaca requests.")
  }

  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  latest_completed_session <- as.Date(latest_completed_session)
  if (any(is.na(c(start_date, end_date, latest_completed_session)))) {
    g5_stop("start_date, end_date, and latest_completed_session must be valid dates.")
  }
  if (start_date > end_date) {
    g5_stop("start_date must be on or before end_date.")
  }
  if (end_date > latest_completed_session) {
    g5_stop("end_date cannot be after latest_completed_session.")
  }
  if (!nzchar(feed)) {
    g5_stop("Alpaca data feed must be non-empty.")
  }

  data.frame(
    provider = "alpaca",
    symbol = symbols,
    timeframe = "1D",
    adjustment = "all",
    feed = feed,
    start_date = start_date,
    end_date = end_date,
    as_of_timestamp = as.character(as_of_timestamp),
    latest_completed_session = latest_completed_session,
    stringsAsFactors = FALSE
  )
}

g5_alpaca_require_runtime <- function() {
  missing_pkgs <- c(
    if (!requireNamespace("httr", quietly = TRUE)) "httr",
    if (!requireNamespace("jsonlite", quietly = TRUE)) "jsonlite"
  )
  if (length(missing_pkgs) > 0L) {
    g5_stop(paste(
      "Alpaca fetching requires R package(s):",
      paste(missing_pkgs, collapse = ", "),
      "Install them before running the live data-refresh smoke path."
    ))
  }
  invisible(TRUE)
}

g5_alpaca_empty_bars <- function() {
  data.frame(
    symbol = character(),
    session_date = as.Date(character()),
    open = numeric(),
    high = numeric(),
    low = numeric(),
    close = numeric(),
    volume = numeric(),
    adjusted = logical(),
    timeframe = character(),
    provider = character(),
    as_of_timestamp = character(),
    latest_completed_session = as.Date(character()),
    fetch_start_date = as.Date(character()),
    fetch_end_date = as.Date(character()),
    data_version_hash = character(),
    stringsAsFactors = FALSE
  )
}

g5_alpaca_bar_value <- function(bar, name) {
  value <- bar[[name]]
  if (is.null(value)) NA else value
}

g5_alpaca_map_bars_to_canonical <- function(parsed_bars, request) {
  if (!is.list(parsed_bars)) {
    g5_stop("parsed_bars must be a list keyed by symbol.")
  }
  if (!is.data.frame(request) || nrow(request) == 0L) {
    g5_stop("request must be a non-empty Alpaca daily adjusted request.")
  }

  request_symbols <- g5_standardize_symbol(request$symbol)
  frames <- list()

  for (sym in request_symbols) {
    symbol_bars <- parsed_bars[[sym]]
    if (is.null(symbol_bars) || length(symbol_bars) == 0L) {
      next
    }

    rows <- lapply(symbol_bars, function(bar) {
      timestamp <- as.character(g5_alpaca_bar_value(bar, "t"))
      data.frame(
        symbol = sym,
        session_date = as.Date(substr(timestamp, 1L, 10L)),
        open = as.numeric(g5_alpaca_bar_value(bar, "o")),
        high = as.numeric(g5_alpaca_bar_value(bar, "h")),
        low = as.numeric(g5_alpaca_bar_value(bar, "l")),
        close = as.numeric(g5_alpaca_bar_value(bar, "c")),
        volume = as.numeric(g5_alpaca_bar_value(bar, "v")),
        adjusted = TRUE,
        timeframe = "1D",
        provider = "alpaca",
        as_of_timestamp = request$as_of_timestamp[1L],
        latest_completed_session = as.Date(request$latest_completed_session[1L]),
        fetch_start_date = as.Date(request$start_date[1L]),
        fetch_end_date = as.Date(request$end_date[1L]),
        data_version_hash = NA_character_,
        stringsAsFactors = FALSE
      )
    })
    frames[[sym]] <- do.call(rbind, rows)
  }

  bars <- if (length(frames) == 0L) {
    g5_alpaca_empty_bars()
  } else {
    do.call(rbind, frames)
  }

  if (nrow(bars) > 0L) {
    bars$data_version_hash <- mapply(
      g5_make_data_version_hash,
      bars$provider,
      bars$symbol,
      bars$session_date,
      bars$open,
      bars$high,
      bars$low,
      bars$close,
      bars$volume,
      bars$adjusted,
      bars$timeframe,
      bars$as_of_timestamp,
      bars$latest_completed_session,
      bars$fetch_start_date,
      bars$fetch_end_date,
      USE.NAMES = FALSE
    )
  }

  g5_validate_bar_data(bars)
}

g5_alpaca_response_message <- function(response_text) {
  parsed <- tryCatch(
    jsonlite::fromJSON(response_text, simplifyVector = TRUE),
    error = function(e) NULL
  )
  if (is.list(parsed) && !is.null(parsed$message)) {
    return(as.character(parsed$message))
  }
  substr(response_text, 1L, 500L)
}

g5_fetch_alpaca_daily_adjusted_bars <- function(request, config = g5_alpaca_config_from_env()) {
  if (!is.data.frame(request)) {
    g5_stop("request must be produced by g5_alpaca_daily_adjusted_request().")
  }
  if (nrow(request) == 0L) {
    g5_stop("request must include at least one symbol.")
  }
  if (!all(request$provider == "alpaca")) {
    g5_stop("request provider must be alpaca.")
  }
  if (!all(request$timeframe == "1D")) {
    g5_stop("Alpaca request timeframe must be 1D.")
  }
  if (!all(request$adjustment == "all")) {
    g5_stop("Gen5 v0 Alpaca requests must use adjustment == 'all'.")
  }
  if (!isTRUE(config$has_credentials)) {
    g5_stop("Alpaca credentials are not configured. Set ALPACA_KEY_ID/ALPACA_SECRET_KEY or ALPACA_KEY/ALPACA_SECRET in .Renviron or the environment.")
  }
  g5_alpaca_require_runtime()

  symbols <- paste(g5_standardize_symbol(request$symbol), collapse = ",")
  base_url <- sub("/+$", "", config$base_url)
  endpoint <- paste0(base_url, "/v2/stocks/bars")
  feed <- if ("feed" %in% names(request)) request$feed[1L] else config$feed
  if (!nzchar(feed)) {
    feed <- config$feed
  }

  query <- list(
    symbols = symbols,
    timeframe = "1D",
    adjustment = "all",
    start = format(as.Date(request$start_date[1L]), "%Y-%m-%d"),
    end = format(as.Date(request$end_date[1L]), "%Y-%m-%d"),
    asof = format(as.Date(request$latest_completed_session[1L]), "%Y-%m-%d"),
    feed = feed,
    sort = "asc",
    limit = 10000L
  )

  all_bars <- list()
  page_token <- NULL
  repeat {
    page_query <- query
    if (!is.null(page_token) && nzchar(page_token)) {
      page_query$page_token <- page_token
    }

    response <- httr::GET(
      endpoint,
      httr::add_headers(
        `APCA-API-KEY-ID` = config$key_id,
        `APCA-API-SECRET-KEY` = config$secret_key
      ),
      query = page_query
    )
    response_text <- httr::content(response, as = "text", encoding = "UTF-8")
    if (httr::http_error(response)) {
      g5_stop(paste(
        "Alpaca bars request failed with HTTP",
        httr::status_code(response),
        "-",
        g5_alpaca_response_message(response_text)
      ))
    }

    parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
    if (is.null(parsed$bars) || !is.list(parsed$bars)) {
      g5_stop("Alpaca response did not include a bars object.")
    }

    for (sym in names(parsed$bars)) {
      all_bars[[sym]] <- c(all_bars[[sym]], parsed$bars[[sym]])
    }

    page_token <- parsed$next_page_token
    if (is.null(page_token) || !nzchar(page_token)) {
      break
    }
  }

  g5_alpaca_map_bars_to_canonical(all_bars, request)
}
