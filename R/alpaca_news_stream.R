# Alpaca real-time news transport and reconciliation helpers for Gen5.4 N1L.
#
# This module is retrieval-only. It does not compute news features, market
# outcomes, sentiment, risk estimates, allocation, or live advice.

g5_news_live_symbols <- function() {
  c(
    "AAPL", "AMD", "AMZN", "AVGO", "BAC", "CAT", "COST", "CVX", "FB",
    "GS", "JNJ", "JPM", "KO", "META", "MSFT", "MSTR", "MU", "NFLX",
    "NVDA", "PEP", "QCOM", "TSLA", "UNH", "WMT", "XOM"
  )
}
.g5_news_live_timestamp <- function(value = Sys.time()) {
  value <- as.POSIXct(value, tz = "UTC")
  if (length(value) != 1L || is.na(value)) g5_stop("A valid UTC receipt timestamp is required.")
  paste0(format(value, "%Y-%m-%dT%H:%M:%OS3", tz = "UTC"), "Z")
}

.g5_news_bind_rows <- function(rows, empty) {
  if (!length(rows)) return(empty())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_news_empty_stream_frames <- function() {
  data.frame(
    connection_id = character(),
    frame_sequence = integer(),
    received_at = character(),
    raw_text = character(),
    parse_ok = logical(),
    message_count = integer(),
    parse_error = character(),
    stringsAsFactors = FALSE
  )
}

g5_news_empty_stream_messages <- function() {
  data.frame(
    connection_id = character(),
    frame_sequence = integer(),
    message_index = integer(),
    received_at = character(),
    message_type = character(),
    status_message = character(),
    article_id = character(),
    headline = character(),
    summary = character(),
    source = character(),
    symbols = character(),
    created_at = character(),
    updated_at = character(),
    url = character(),
    stringsAsFactors = FALSE
  )
}

g5_news_empty_lifecycle <- function() {
  data.frame(
    connection_id = character(),
    event_sequence = integer(),
    observed_at = character(),
    event = character(),
    detail = character(),
    stringsAsFactors = FALSE
  )
}

.g5_news_scalar <- function(x, default = "") {
  if (is.null(x) || !length(x) || is.na(x[[1L]])) default else as.character(x[[1L]])
}

g5_parse_alpaca_news_stream_frame <- function(raw_text, connection_id, frame_sequence, received_at) {
  if (length(raw_text) != 1L || !nzchar(as.character(raw_text))) g5_stop("raw_text must be one nonempty frame.")
  if (length(connection_id) != 1L || !nzchar(as.character(connection_id))) g5_stop("connection_id is required.")
  frame_sequence <- as.integer(frame_sequence)
  if (is.na(frame_sequence) || frame_sequence < 1L) g5_stop("frame_sequence must be positive.")
  .g5_alpaca_context_time(received_at, "received_at")

  parsed <- jsonlite::fromJSON(as.character(raw_text), simplifyVector = FALSE)
  if (!is.list(parsed)) g5_stop("Alpaca stream frame must decode to an object or array.")
  is_single_object <- length(parsed) > 0L && !is.null(names(parsed)) && any(nzchar(names(parsed)))
  messages <- if (is_single_object) list(parsed) else parsed
  if (!length(messages)) return(g5_news_empty_stream_messages())

  rows <- lapply(seq_along(messages), function(i) {
    message <- messages[[i]]
    if (!is.list(message)) g5_stop("Alpaca stream array entries must be objects.")
    symbols <- message$symbols
    symbols <- if (is.null(symbols)) character() else sort(unique(toupper(as.character(unlist(symbols, use.names = FALSE)))))
    data.frame(
      connection_id = as.character(connection_id),
      frame_sequence = frame_sequence,
      message_index = as.integer(i),
      received_at = as.character(received_at),
      message_type = .g5_news_scalar(message$T),
      status_message = .g5_news_scalar(message$msg),
      article_id = .g5_news_scalar(message$id),
      headline = .g5_news_scalar(message$headline),
      summary = .g5_news_scalar(message$summary),
      source = .g5_news_scalar(message$source),
      symbols = paste(symbols, collapse = "|"),
      created_at = .g5_news_scalar(message$created_at),
      updated_at = .g5_news_scalar(message$updated_at),
      url = .g5_news_scalar(message$url),
      stringsAsFactors = FALSE
    )
  })
  .g5_news_bind_rows(rows, g5_news_empty_stream_messages)
}

g5_collect_alpaca_news_stream <- function(
  connection_id,
  symbols = g5_news_live_symbols(),
  duration_seconds = 30,
  config = g5_alpaca_config_from_env(),
  stream_url = Sys.getenv(
    "ALPACA_NEWS_STREAM_URL",
    unset = "wss://stream.data.alpaca.markets/v1beta1/news"
  )
) {
  if (!requireNamespace("websocket", quietly = TRUE) || !requireNamespace("later", quietly = TRUE)) {
    g5_stop("N1L requires the approved websocket and later packages.")
  }
  g5_alpaca_preflight_live_fetch(config)
  if (length(connection_id) != 1L || !nzchar(as.character(connection_id))) g5_stop("connection_id is required.")
  symbols <- unique(g5_standardize_symbol(symbols))
  if (!length(symbols)) g5_stop("At least one stream symbol is required.")
  duration_seconds <- as.numeric(duration_seconds)
  if (!is.finite(duration_seconds) || duration_seconds < 5 || duration_seconds > 300) {
    g5_stop("duration_seconds must be between 5 and 300.")
  }

  state <- new.env(parent = emptyenv())
  state$frame_rows <- list()
  state$message_rows <- list()
  state$lifecycle_rows <- list()
  state$frame_sequence <- 0L
  state$event_sequence <- 0L
  state$subscription_sent <- FALSE

  add_lifecycle <- function(event, detail = "") {
    state$event_sequence <- state$event_sequence + 1L
    state$lifecycle_rows[[length(state$lifecycle_rows) + 1L]] <- data.frame(
      connection_id = as.character(connection_id),
      event_sequence = state$event_sequence,
      observed_at = .g5_news_live_timestamp(),
      event = as.character(event),
      detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }

  headers <- c(
    `APCA-API-KEY-ID` = config$key_id,
    `APCA-API-SECRET-KEY` = config$secret_key
  )
  ws <- websocket::WebSocket$new(
    stream_url,
    headers = headers,
    autoConnect = FALSE,
    accessLogChannels = "none",
    errorLogChannels = "none"
  )
  add_lifecycle("constructed", stream_url)

  ws$onOpen(function(event) add_lifecycle("open"))
  ws$onError(function(event) add_lifecycle("error", .g5_news_scalar(event$message)))
  ws$onClose(function(event) {
    add_lifecycle("close", paste0("code=", .g5_news_scalar(event$code), ";reason=", .g5_news_scalar(event$reason)))
  })
  ws$onMessage(function(event) {
    state$frame_sequence <- state$frame_sequence + 1L
    received_at <- .g5_news_live_timestamp()
    raw_text <- if (is.raw(event$data)) rawToChar(event$data) else as.character(event$data)
    parsed <- tryCatch(
      g5_parse_alpaca_news_stream_frame(raw_text, connection_id, state$frame_sequence, received_at),
      error = function(e) e
    )
    parse_ok <- !inherits(parsed, "error")
    state$frame_rows[[length(state$frame_rows) + 1L]] <- data.frame(
      connection_id = as.character(connection_id),
      frame_sequence = state$frame_sequence,
      received_at = received_at,
      raw_text = raw_text,
      parse_ok = parse_ok,
      message_count = if (parse_ok) nrow(parsed) else 0L,
      parse_error = if (parse_ok) "" else conditionMessage(parsed),
      stringsAsFactors = FALSE
    )
    if (!parse_ok) {
      add_lifecycle("parse_error", conditionMessage(parsed))
      return(invisible(NULL))
    }
    if (nrow(parsed)) state$message_rows[[length(state$message_rows) + 1L]] <- parsed
    if (any(parsed$message_type == "success" & parsed$status_message == "connected")) {
      add_lifecycle("server_connected")
    }
    if (any(parsed$message_type == "success" & parsed$status_message == "authenticated")) {
      add_lifecycle("authenticated")
      if (!isTRUE(state$subscription_sent)) {
        subscription <- jsonlite::toJSON(
          list(action = "subscribe", news = as.list(symbols)),
          auto_unbox = TRUE
        )
        ws$send(subscription)
        state$subscription_sent <- TRUE
        add_lifecycle("subscription_sent", paste(symbols, collapse = ","))
      }
    }
    if (any(parsed$message_type == "subscription")) add_lifecycle("subscription_acknowledged")
    invisible(NULL)
  })

  started_at <- .g5_news_live_timestamp()
  ws$connect()
  add_lifecycle("connect_requested")
  deadline <- Sys.time() + duration_seconds
  while (Sys.time() < deadline) later::run_now(timeoutSecs = 0.25)
  add_lifecycle("close_requested")
  try(ws$close(), silent = TRUE)
  close_deadline <- Sys.time() + 2
  while (Sys.time() < close_deadline) later::run_now(timeoutSecs = 0.1)

  list(
    connection_id = as.character(connection_id),
    started_at = started_at,
    ended_at = .g5_news_live_timestamp(),
    requested_symbols = symbols,
    frames = .g5_news_bind_rows(state$frame_rows, g5_news_empty_stream_frames),
    messages = .g5_news_bind_rows(state$message_rows, g5_news_empty_stream_messages),
    lifecycle = .g5_news_bind_rows(state$lifecycle_rows, g5_news_empty_lifecycle)
  )
}

g5_reconcile_alpaca_news <- function(stream_messages, rest_articles) {
  required_stream <- names(g5_news_empty_stream_messages())
  required_rest <- names(g5_alpaca_empty_news())
  if (!is.data.frame(stream_messages) || !all(required_stream %in% names(stream_messages))) {
    g5_stop("stream_messages does not satisfy the N1L stream schema.")
  }
  if (!is.data.frame(rest_articles) || !all(required_rest %in% names(rest_articles))) {
    g5_stop("rest_articles does not satisfy the Alpaca news schema.")
  }
  stream_news <- stream_messages[stream_messages$message_type == "n", , drop = FALSE]
  if (nrow(stream_news)) {
    stream_news <- stream_news[order(stream_news$article_id, stream_news$received_at, stream_news$frame_sequence), , drop = FALSE]
    conflict_key <- paste(stream_news$article_id, stream_news$updated_at, sep = "\r")
    conflict_value <- paste(stream_news$headline, stream_news$symbols, sep = "\r")
    conflict_ids <- unique(stream_news$article_id[ave(conflict_value, conflict_key, FUN = function(x) length(unique(x))) > 1L])
    stream_latest <- stream_news[!duplicated(stream_news$article_id, fromLast = TRUE), , drop = FALSE]
    stream_first <- tapply(stream_news$received_at, stream_news$article_id, min)
    stream_last <- tapply(stream_news$received_at, stream_news$article_id, max)
  } else {
    conflict_ids <- character()
    stream_latest <- stream_news
    stream_first <- character()
    stream_last <- character()
  }

  rest_latest <- rest_articles
  if (nrow(rest_latest)) {
    rest_latest <- rest_latest[order(rest_latest$article_id, rest_latest$updated_at), , drop = FALSE]
    rest_latest <- rest_latest[!duplicated(rest_latest$article_id, fromLast = TRUE), , drop = FALSE]
  }
  ids <- sort(unique(c(stream_latest$article_id, rest_latest$article_id)))
  if (!length(ids)) {
    table <- data.frame(
      article_id = character(), in_stream = logical(), in_rest = logical(),
      stream_first_received_at = character(), stream_last_received_at = character(),
      stream_updated_at = character(), rest_updated_at = character(),
      headline_match = logical(), symbols_match = logical(), reconciliation_status = character(),
      stringsAsFactors = FALSE
    )
    return(list(table = table, conflicting_stream_ids = conflict_ids))
  }

  rows <- lapply(ids, function(id) {
    s <- stream_latest[stream_latest$article_id == id, , drop = FALSE]
    r <- rest_latest[rest_latest$article_id == id, , drop = FALSE]
    in_stream <- nrow(s) == 1L
    in_rest <- nrow(r) == 1L
    headline_match <- in_stream && in_rest && identical(s$headline[[1L]], r$headline[[1L]])
    symbols_match <- in_stream && in_rest && identical(s$symbols[[1L]], r$symbols[[1L]])
    status <- if (in_stream && in_rest && headline_match && symbols_match) {
      "matched"
    } else if (in_stream && in_rest) {
      "present_both_metadata_differs"
    } else if (in_stream) {
      "stream_only"
    } else {
      "rest_only"
    }
    data.frame(
      article_id = id,
      in_stream = in_stream,
      in_rest = in_rest,
      stream_first_received_at = if (in_stream) unname(stream_first[[id]]) else "",
      stream_last_received_at = if (in_stream) unname(stream_last[[id]]) else "",
      stream_updated_at = if (in_stream) s$updated_at[[1L]] else "",
      rest_updated_at = if (in_rest) r$updated_at[[1L]] else "",
      headline_match = headline_match,
      symbols_match = symbols_match,
      reconciliation_status = status,
      stringsAsFactors = FALSE
    )
  })
  list(
    table = .g5_news_bind_rows(rows, function() data.frame()),
    conflicting_stream_ids = conflict_ids
  )
}
