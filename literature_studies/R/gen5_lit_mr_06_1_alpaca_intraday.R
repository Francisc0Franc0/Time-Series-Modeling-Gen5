# Literature-only Alpaca helper for the frozen LIT-MR-06.1 09:32 entry proxy.

g5_mr06_alpaca_require_runtime <- function() {
  missing <- c(
    if (!requireNamespace("httr", quietly = TRUE)) "httr",
    if (!requireNamespace("jsonlite", quietly = TRUE)) "jsonlite"
  )
  if (length(missing)) {
    g5_mr06_stop(paste(
      "Alpaca intraday retrieval requires:",
      paste(missing, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

g5_mr06_alpaca_et_to_utc <- function(session_date, clock_time) {
  value <- as.POSIXct(
    paste(as.Date(session_date), clock_time),
    tz = "America/New_York"
  )
  if (is.na(value)) g5_mr06_stop("Could not resolve ET request timestamp.")
  format(value, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
}

g5_mr06_alpaca_response_message <- function(response_text) {
  parsed <- tryCatch(
    jsonlite::fromJSON(response_text, simplifyVector = TRUE),
    error = function(e) NULL
  )
  if (is.list(parsed) && !is.null(parsed$message)) {
    return(as.character(parsed$message))
  }
  substr(response_text, 1L, 500L)
}

g5_mr06_alpaca_symbol_map <- function(symbols, session_date) {
  research_symbol <- sort(unique(toupper(trimws(as.character(symbols)))))
  provider_symbol <- research_symbol
  meta_alias_end <- as.Date("2022-06-08")
  if (as.Date(session_date) <= meta_alias_end) {
    provider_symbol[research_symbol == "META"] <- "FB"
  }
  data.frame(
    research_symbol = research_symbol,
    provider_symbol = provider_symbol,
    stringsAsFactors = FALSE
  )
}

g5_mr06_alpaca_fetch_entry_date <- function(
  symbols,
  session_date,
  contract,
  config,
  adjustment_asof = contract$train_end
) {
  symbol_map <- g5_mr06_alpaca_symbol_map(symbols, session_date)
  if (!nrow(symbol_map)) {
    return(data.frame(
      symbol = character(),
      session_date = as.Date(character()),
      entry_timestamp_et = character(),
      entry_open = numeric(),
      provider = character(),
      provider_symbol = character(),
      feed = character(),
      timeframe = character(),
      adjustment = character(),
      as_of_timestamp = character(),
      stringsAsFactors = FALSE
    ))
  }
  g5_mr06_alpaca_require_runtime()
  base_url <- sub("/+$", "", config$base_url)
  endpoint <- paste0(base_url, "/v2/stocks/bars")
  query <- list(
    symbols = paste(unique(symbol_map$provider_symbol), collapse = ","),
    timeframe = "1Min",
    adjustment = "all",
    start = g5_mr06_alpaca_et_to_utc(session_date, "09:31:55"),
    end = g5_mr06_alpaca_et_to_utc(session_date, "09:33:05"),
    asof = format(as.Date(adjustment_asof), "%Y-%m-%d"),
    feed = config$feed,
    sort = "asc",
    limit = 10000L
  )
  response <- httr::GET(
    endpoint,
    httr::add_headers(
      `APCA-API-KEY-ID` = config$key_id,
      `APCA-API-SECRET-KEY` = config$secret_key
    ),
    query = query
  )
  response_text <- httr::content(response, as = "text", encoding = "UTF-8")
  if (httr::http_error(response)) {
    g5_mr06_stop(paste(
      "Alpaca 09:32 bars request failed with HTTP",
      httr::status_code(response), "-",
      g5_mr06_alpaca_response_message(response_text),
      "for", as.Date(session_date)
    ))
  }
  parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
  bars <- parsed$bars
  if (is.null(bars) || !is.list(bars)) {
    g5_mr06_stop("Alpaca intraday response did not include a bars object.")
  }
  output <- list()
  for (i in seq_len(nrow(symbol_map))) {
    research_symbol <- symbol_map$research_symbol[[i]]
    provider_symbol <- symbol_map$provider_symbol[[i]]
    symbol_bars <- bars[[provider_symbol]]
    if (is.null(symbol_bars) || !length(symbol_bars)) next
    for (bar in symbol_bars) {
      timestamp_utc <- as.POSIXct(
        substr(as.character(bar$t), 1L, 19L), tz = "UTC",
        format = "%Y-%m-%dT%H:%M:%S"
      )
      clock_et <- format(
        timestamp_utc, tz = "America/New_York", format = "%H:%M:%S"
      )
      if (!identical(clock_et, contract$entry_time_et)) next
      output[[length(output) + 1L]] <- data.frame(
        symbol = research_symbol,
        session_date = as.Date(session_date),
        entry_timestamp_et = paste(
          as.Date(session_date), contract$entry_time_et
        ),
        entry_open = as.numeric(bar$o),
        provider = "alpaca",
        provider_symbol = provider_symbol,
        feed = config$feed,
        timeframe = "1Min",
        adjustment = "all",
        as_of_timestamp = contract$as_of_timestamp,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(output)) {
    return(data.frame(
      symbol = character(),
      session_date = as.Date(character()),
      entry_timestamp_et = character(),
      entry_open = numeric(),
      provider = character(),
      provider_symbol = character(),
      feed = character(),
      timeframe = character(),
      adjustment = character(),
      as_of_timestamp = character(),
      stringsAsFactors = FALSE
    ))
  }
  rows <- do.call(rbind, output)
  rows[!duplicated(rows[c("symbol", "session_date")]), , drop = FALSE]
}

g5_mr06_alpaca_fetch_entries <- function(
  manifest,
  contract,
  config,
  adjustment_asof = contract$train_end,
  progress_every = 25L
) {
  required <- c("symbol", "session_date")
  if (!is.data.frame(manifest) || !all(required %in% names(manifest))) {
    g5_mr06_stop("Entry manifest requires symbol and session_date.")
  }
  if (!nrow(manifest)) {
    return(g5_mr06_alpaca_fetch_entry_date(
      character(), contract$train_start, contract, config
    ))
  }
  dates <- sort(unique(as.Date(manifest$session_date)))
  rows <- vector("list", length(dates))
  for (i in seq_along(dates)) {
    date <- dates[[i]]
    symbols <- manifest$symbol[as.Date(manifest$session_date) == date]
    rows[[i]] <- g5_mr06_alpaca_fetch_entry_date(
      symbols, date, contract, config, adjustment_asof
    )
    if (i %% as.integer(progress_every) == 0L || i == length(dates)) {
      message(
        "LIT-MR-06.1 entry retrieval: ", i, "/", length(dates),
        " candidate sessions"
      )
    }
  }
  output <- do.call(rbind, rows)
  output[order(output$session_date, output$symbol), , drop = FALSE]
}
