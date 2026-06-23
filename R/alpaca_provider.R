# Alpaca provider boundary.

.g5_alpaca_value_from_object_or_env <- function(object_name, env_names, default = "") {
  if (exists(object_name, envir = globalenv(), inherits = FALSE)) {
    value <- get(object_name, envir = globalenv(), inherits = FALSE)
    value <- as.character(value[1L])
    if (!is.na(value) && nzchar(value)) {
      return(value)
    }
  }

  for (env_name in env_names) {
    value <- Sys.getenv(env_name, unset = "")
    if (nzchar(value)) {
      return(value)
    }
  }

  default
}

g5_alpaca_config_from_env <- function() {
  key_id <- .g5_alpaca_value_from_object_or_env("ALPACA_KEY", c("ALPACA_KEY", "ALPACA_KEY_ID"))
  secret_key <- .g5_alpaca_value_from_object_or_env("ALPACA_SECRET", c("ALPACA_SECRET", "ALPACA_SECRET_KEY"))
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

g5_alpaca_missing_credential_fields <- function(config = g5_alpaca_config_from_env()) {
  missing_fields <- character()
  key_id <- if (is.null(config$key_id) || length(config$key_id) == 0L) "" else as.character(config$key_id[[1L]])
  secret_key <- if (is.null(config$secret_key) || length(config$secret_key) == 0L) "" else as.character(config$secret_key[[1L]])
  if (is.na(key_id) || !nzchar(key_id)) {
    missing_fields <- c(missing_fields, "key id (set ALPACA_KEY or ALPACA_KEY_ID)")
  }
  if (is.na(secret_key) || !nzchar(secret_key)) {
    missing_fields <- c(missing_fields, "secret key (set ALPACA_SECRET or ALPACA_SECRET_KEY)")
  }
  missing_fields
}

g5_alpaca_require_credentials <- function(config = g5_alpaca_config_from_env()) {
  missing_fields <- g5_alpaca_missing_credential_fields(config)
  if (length(missing_fields) > 0L) {
    g5_stop(paste(
      "Alpaca credentials are not configured for live data refresh. Missing",
      paste(missing_fields, collapse = " and "),
      "in repo-local .Renviron or the process environment."
    ))
  }
  invisible(TRUE)
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

g5_alpaca_resolve_daily_date_range <- function(
  start_date,
  end_date,
  latest_completed_session
) {
  start_date <- as.Date(start_date)
  requested_end_date <- as.Date(end_date)
  latest_completed_session <- as.Date(latest_completed_session)
  if (any(is.na(c(start_date, requested_end_date, latest_completed_session)))) {
    g5_stop("start_date, end_date, and latest_completed_session must be valid dates.")
  }
  if (start_date > requested_end_date) {
    g5_stop("start_date must be on or before end_date.")
  }

  fetch_end_date <- requested_end_date
  warnings <- character()
  if (requested_end_date > latest_completed_session) {
    fetch_end_date <- latest_completed_session
    warnings <- c(
      warnings,
      paste(
        "requested_end_date_after_latest_completed_session",
        paste0("requested_end_date=", requested_end_date),
        paste0("latest_completed_session=", latest_completed_session),
        paste0("fetch_end_date=", fetch_end_date),
        sep = ":"
      )
    )
  }
  if (start_date > fetch_end_date) {
    g5_stop("start_date is after the bounded fetch_end_date.")
  }

  data.frame(
    requested_start_date = start_date,
    requested_end_date = requested_end_date,
    fetch_start_date = start_date,
    fetch_end_date = fetch_end_date,
    latest_completed_session = latest_completed_session,
    date_range_warning_count = length(warnings),
    date_range_warnings = paste(warnings, collapse = ";"),
    stringsAsFactors = FALSE
  )
}

g5_alpaca_missing_runtime_packages <- function(require_namespace = requireNamespace) {
  c(
    if (!require_namespace("httr", quietly = TRUE)) "httr",
    if (!require_namespace("jsonlite", quietly = TRUE)) "jsonlite"
  )
}

g5_alpaca_require_runtime <- function() {
  missing_pkgs <- g5_alpaca_missing_runtime_packages()
  if (length(missing_pkgs) > 0L) {
    g5_stop(paste(
      "Alpaca fetching requires R package(s):",
      paste(missing_pkgs, collapse = ", "),
      "Install them before running the live data-refresh smoke path.",
      "Current .libPaths():",
      paste(.libPaths(), collapse = "; ")
    ))
  }
  invisible(TRUE)
}

g5_alpaca_preflight_live_fetch <- function(config = g5_alpaca_config_from_env()) {
  g5_alpaca_require_credentials(config)
  g5_alpaca_require_runtime()
  invisible(TRUE)
}

g5_alpaca_empty_bars <- function() {
  g5_empty_bar_data()
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
  g5_alpaca_preflight_live_fetch(config)

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
