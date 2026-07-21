# Alpaca research-only context-data provider boundary.
#
# This module does not alter the canonical adjusted-daily OHLCV contract. It
# supports capability inspection for historical news and index values only.

.g5_alpaca_context_time <- function(value, field_name) {
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

.g5_alpaca_context_validate_window <- function(start_timestamp, end_timestamp, as_of_timestamp) {
  start <- .g5_alpaca_context_time(start_timestamp, "start_timestamp")
  end <- .g5_alpaca_context_time(end_timestamp, "end_timestamp")
  as_of <- .g5_alpaca_context_time(as_of_timestamp, "as_of_timestamp")
  if (start > end) g5_stop("start_timestamp must be on or before end_timestamp.")
  if (end > as_of) g5_stop("end_timestamp cannot be after as_of_timestamp.")
  invisible(TRUE)
}

g5_alpaca_news_request <- function(
  symbols,
  start_timestamp,
  end_timestamp,
  as_of_timestamp,
  include_content = FALSE,
  limit = 50L
) {
  symbols <- g5_standardize_symbol(symbols)
  if (!length(symbols)) g5_stop("At least one news symbol is required.")
  .g5_alpaca_context_validate_window(start_timestamp, end_timestamp, as_of_timestamp)
  limit <- as.integer(limit)
  if (is.na(limit) || limit < 1L || limit > 50L) g5_stop("News page limit must be between 1 and 50.")
  data.frame(
    provider = "alpaca",
    endpoint = "/v1beta1/news",
    symbols = paste(symbols, collapse = ","),
    start_timestamp = as.character(start_timestamp),
    end_timestamp = as.character(end_timestamp),
    as_of_timestamp = as.character(as_of_timestamp),
    include_content = isTRUE(include_content),
    sort = "asc",
    limit = limit,
    stringsAsFactors = FALSE
  )
}

g5_alpaca_index_values_request <- function(
  index_symbols,
  start_timestamp,
  end_timestamp,
  as_of_timestamp,
  limit = 1000L
) {
  index_symbols <- unique(toupper(trimws(as.character(index_symbols))))
  index_symbols <- index_symbols[!is.na(index_symbols) & nzchar(index_symbols)]
  if (!length(index_symbols)) g5_stop("At least one index symbol is required.")
  .g5_alpaca_context_validate_window(start_timestamp, end_timestamp, as_of_timestamp)
  limit <- as.integer(limit)
  if (is.na(limit) || limit < 1L) g5_stop("Index page limit must be positive.")
  data.frame(
    provider = "alpaca",
    endpoint = "/v1beta1/indices/values",
    index_symbols = paste(index_symbols, collapse = ","),
    start_timestamp = as.character(start_timestamp),
    end_timestamp = as.character(end_timestamp),
    as_of_timestamp = as.character(as_of_timestamp),
    limit = limit,
    stringsAsFactors = FALSE
  )
}

g5_alpaca_empty_news <- function() {
  data.frame(
    article_id = character(),
    headline = character(),
    summary = character(),
    author = character(),
    source = character(),
    symbols = character(),
    created_at = character(),
    updated_at = character(),
    url = character(),
    content_present = logical(),
    provider = character(),
    request_start_timestamp = character(),
    request_end_timestamp = character(),
    as_of_timestamp = character(),
    retrieved_at = character(),
    stringsAsFactors = FALSE
  )
}

.g5_alpaca_article_value <- function(article, name, default = NA_character_) {
  value <- article[[name]]
  if (is.null(value) || !length(value)) default else value
}

g5_alpaca_map_news_payload <- function(parsed, request, retrieved_at) {
  if (!is.list(parsed)) g5_stop("Parsed Alpaca news payload must be a list.")
  if (!is.data.frame(request) || nrow(request) != 1L) g5_stop("News request must contain exactly one row.")
  .g5_alpaca_context_time(retrieved_at, "retrieved_at")
  articles <- parsed$news
  if (is.null(articles) || !length(articles)) return(g5_alpaca_empty_news())
  rows <- lapply(articles, function(article) {
    article_symbols <- .g5_alpaca_article_value(article, "symbols", character())
    article_symbols <- sort(unique(toupper(as.character(unlist(article_symbols, use.names = FALSE)))))
    content <- .g5_alpaca_article_value(article, "content", "")
    data.frame(
      article_id = as.character(.g5_alpaca_article_value(article, "id")),
      headline = as.character(.g5_alpaca_article_value(article, "headline")),
      summary = as.character(.g5_alpaca_article_value(article, "summary")),
      author = as.character(.g5_alpaca_article_value(article, "author")),
      source = as.character(.g5_alpaca_article_value(article, "source")),
      symbols = paste(article_symbols, collapse = "|"),
      created_at = as.character(.g5_alpaca_article_value(article, "created_at")),
      updated_at = as.character(.g5_alpaca_article_value(article, "updated_at")),
      url = as.character(.g5_alpaca_article_value(article, "url")),
      content_present = !is.na(content) && nzchar(as.character(content)),
      provider = "alpaca",
      request_start_timestamp = request$start_timestamp[[1L]],
      request_end_timestamp = request$end_timestamp[[1L]],
      as_of_timestamp = request$as_of_timestamp[[1L]],
      retrieved_at = as.character(retrieved_at),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.g5_alpaca_context_headers <- function(config) {
  httr::add_headers(
    `APCA-API-KEY-ID` = config$key_id,
    `APCA-API-SECRET-KEY` = config$secret_key
  )
}

g5_fetch_alpaca_news <- function(
  request,
  retrieved_at,
  config = g5_alpaca_config_from_env(),
  request_pause_seconds = 0
) {
  if (!is.data.frame(request) || nrow(request) != 1L || request$endpoint[[1L]] != "/v1beta1/news") {
    g5_stop("request must be produced by g5_alpaca_news_request().")
  }
  g5_alpaca_preflight_live_fetch(config)
  .g5_alpaca_context_time(retrieved_at, "retrieved_at")
  request_pause_seconds <- as.numeric(request_pause_seconds)
  if (!is.finite(request_pause_seconds) || request_pause_seconds < 0) {
    g5_stop("request_pause_seconds must be a finite non-negative number.")
  }
  endpoint <- paste0(sub("/+$", "", config$base_url), request$endpoint[[1L]])
  base_query <- list(
    symbols = request$symbols[[1L]],
    start = request$start_timestamp[[1L]],
    end = request$end_timestamp[[1L]],
    sort = request$sort[[1L]],
    limit = request$limit[[1L]],
    include_content = if (isTRUE(request$include_content[[1L]])) "true" else "false"
  )
  page_token <- NULL
  seen_tokens <- character()
  pages <- list()
  frames <- list()
  page_number <- 0L
  repeat {
    page_number <- page_number + 1L
    query <- base_query
    if (!is.null(page_token) && nzchar(page_token)) query$page_token <- page_token
    response <- httr::GET(endpoint, .g5_alpaca_context_headers(config), query = query)
    response_text <- httr::content(response, as = "text", encoding = "UTF-8")
    status <- httr::status_code(response)
    if (httr::http_error(response)) {
      g5_stop(paste("Alpaca news request failed with HTTP", status, "-", g5_alpaca_response_message(response_text)))
    }
    parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
    if (is.null(parsed$news) || !is.list(parsed$news)) g5_stop("Alpaca news response did not include a news list.")
    next_token <- parsed$next_page_token
    next_token <- if (is.null(next_token) || !nzchar(as.character(next_token))) "" else as.character(next_token)
    pages[[page_number]] <- list(
      page_number = page_number,
      http_status = status,
      page_token_in = if (is.null(page_token)) "" else page_token,
      next_page_token = next_token,
      response_bytes = nchar(response_text, type = "bytes"),
      response_text = response_text
    )
    frames[[page_number]] <- g5_alpaca_map_news_payload(parsed, request, retrieved_at)
    if (!nzchar(next_token)) break
    if (next_token %in% seen_tokens) g5_stop("Alpaca news pagination repeated a page token.")
    seen_tokens <- c(seen_tokens, next_token)
    page_token <- next_token
    if (request_pause_seconds > 0) Sys.sleep(request_pause_seconds)
  }
  data <- if (!length(frames) || all(vapply(frames, nrow, integer(1L)) == 0L)) {
    g5_alpaca_empty_news()
  } else {
    do.call(rbind, frames[vapply(frames, nrow, integer(1L)) > 0L])
  }
  rownames(data) <- NULL
  list(data = data, pages = pages, endpoint = endpoint)
}

g5_alpaca_map_calendar_payload <- function(parsed, as_of_timestamp, retrieved_at) {
  if (!is.list(parsed)) g5_stop("Parsed Alpaca calendar payload must be a list.")
  .g5_alpaca_context_time(as_of_timestamp, "as_of_timestamp")
  .g5_alpaca_context_time(retrieved_at, "retrieved_at")
  if (!length(parsed)) {
    return(data.frame(
      session_date = as.Date(character()),
      market_open = character(),
      market_close = character(),
      as_of_timestamp = character(),
      retrieved_at = character(),
      stringsAsFactors = FALSE
    ))
  }
  rows <- lapply(parsed, function(session) {
    date <- as.Date(as.character(.g5_alpaca_article_value(session, "date")))
    if (is.na(date)) g5_stop("Alpaca calendar row has an invalid date.")
    data.frame(
      session_date = date,
      market_open = as.character(.g5_alpaca_article_value(session, "open")),
      market_close = as.character(.g5_alpaca_article_value(session, "close")),
      as_of_timestamp = as.character(as_of_timestamp),
      retrieved_at = as.character(retrieved_at),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$session_date), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_fetch_alpaca_calendar <- function(
  start_date,
  end_date,
  as_of_timestamp,
  retrieved_at,
  config = g5_alpaca_config_from_env(),
  trading_base_url = Sys.getenv("ALPACA_TRADING_BASE_URL", unset = "https://api.alpaca.markets")
) {
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  if (any(is.na(c(start_date, end_date))) || start_date > end_date) {
    g5_stop("Calendar start_date and end_date must be valid and ordered.")
  }
  .g5_alpaca_context_validate_window(
    paste0(start_date, "T00:00:00Z"),
    paste0(end_date, "T23:59:59Z"),
    as_of_timestamp
  )
  .g5_alpaca_context_time(retrieved_at, "retrieved_at")
  g5_alpaca_preflight_live_fetch(config)
  endpoint <- paste0(sub("/+$", "", trading_base_url), "/v2/calendar")
  response <- httr::GET(
    endpoint,
    .g5_alpaca_context_headers(config),
    query = list(start = as.character(start_date), end = as.character(end_date))
  )
  response_text <- httr::content(response, as = "text", encoding = "UTF-8")
  status <- httr::status_code(response)
  if (httr::http_error(response)) {
    g5_stop(paste("Alpaca calendar request failed with HTTP", status, "-", g5_alpaca_response_message(response_text)))
  }
  parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
  list(
    data = g5_alpaca_map_calendar_payload(parsed, as_of_timestamp, retrieved_at),
    endpoint = endpoint,
    http_status = status,
    response_bytes = nchar(response_text, type = "bytes"),
    response_text = response_text
  )
}

g5_probe_alpaca_index_values <- function(request, retrieved_at, config = g5_alpaca_config_from_env()) {
  if (!is.data.frame(request) || nrow(request) != 1L || request$endpoint[[1L]] != "/v1beta1/indices/values") {
    g5_stop("request must be produced by g5_alpaca_index_values_request().")
  }
  g5_alpaca_preflight_live_fetch(config)
  .g5_alpaca_context_time(retrieved_at, "retrieved_at")
  endpoint <- paste0(sub("/+$", "", config$base_url), request$endpoint[[1L]])
  response <- httr::GET(
    endpoint,
    .g5_alpaca_context_headers(config),
    query = list(
      index_symbols = request$index_symbols[[1L]],
      start = request$start_timestamp[[1L]],
      end = request$end_timestamp[[1L]],
      limit = request$limit[[1L]]
    )
  )
  response_text <- httr::content(response, as = "text", encoding = "UTF-8")
  parsed <- tryCatch(jsonlite::fromJSON(response_text, simplifyVector = FALSE), error = function(e) NULL)
  list(
    endpoint = endpoint,
    http_status = httr::status_code(response),
    authorized = !httr::http_error(response),
    response_bytes = nchar(response_text, type = "bytes"),
    response_message = if (httr::http_error(response)) g5_alpaca_response_message(response_text) else "OK",
    response_text = response_text,
    parsed = parsed,
    retrieved_at = as.character(retrieved_at)
  )
}
