g5_cboe_vix_history_url <- function() {
  "https://cdn.cboe.com/api/global/us_indices/daily_prices/VIX_History.csv"
}

g5_cboe_parse_vix_history <- function(
    response_text,
    start_date,
    end_date,
    as_of_timestamp,
    source_url = g5_cboe_vix_history_url()) {
  if (missing(as_of_timestamp) || is.null(as_of_timestamp) || !nzchar(as.character(as_of_timestamp[[1L]]))) {
    stop("as_of_timestamp is required for Cboe VIX history.", call. = FALSE)
  }
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  as_of_date <- as.Date(substr(as.character(as_of_timestamp[[1L]]), 1L, 10L))
  if (any(is.na(c(start_date, end_date, as_of_date))) || start_date > end_date) {
    stop("Cboe VIX dates must be valid and ordered.", call. = FALSE)
  }
  if (end_date > as_of_date) {
    stop("Cboe VIX end_date cannot be after as_of_timestamp.", call. = FALSE)
  }
  if (!is.character(response_text) || length(response_text) != 1L || !nzchar(response_text)) {
    stop("Cboe VIX response must be non-empty text.", call. = FALSE)
  }

  parsed <- tryCatch(
    utils::read.csv(text = response_text, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) stop(paste("Could not parse Cboe VIX CSV:", conditionMessage(e)), call. = FALSE)
  )
  required <- c("DATE", "OPEN", "HIGH", "LOW", "CLOSE")
  if (!identical(names(parsed), required)) {
    stop("Cboe VIX CSV schema changed; expected DATE,OPEN,HIGH,LOW,CLOSE.", call. = FALSE)
  }
  dates <- as.Date(parsed$DATE, format = "%m/%d/%Y")
  values <- lapply(parsed[required[-1L]], function(x) suppressWarnings(as.numeric(x)))
  if (any(is.na(dates)) || any(!is.finite(unlist(values, use.names = FALSE)))) {
    stop("Cboe VIX CSV contains invalid dates or non-finite index values.", call. = FALSE)
  }
  if (anyDuplicated(dates)) {
    stop("Cboe VIX CSV contains duplicate dates.", call. = FALSE)
  }
  if (is.unsorted(dates, strictly = TRUE)) {
    stop("Cboe VIX CSV dates must be strictly increasing.", call. = FALSE)
  }
  if (any(unlist(values, use.names = FALSE) <= 0)) {
    stop("Cboe VIX index values must be positive.", call. = FALSE)
  }

  out <- data.frame(
    observation_date = dates,
    open = values$OPEN,
    high = values$HIGH,
    low = values$LOW,
    close = values$CLOSE,
    provider = "cboe",
    series_id = "VIX",
    source_url = source_url,
    as_of_timestamp = as.character(as_of_timestamp[[1L]]),
    stringsAsFactors = FALSE
  )
  out <- out[out$observation_date >= start_date & out$observation_date <= end_date, , drop = FALSE]
  rownames(out) <- NULL
  if (!nrow(out)) stop("Cboe VIX history has no rows in the requested range.", call. = FALSE)
  out
}

g5_cboe_fetch_vix_history <- function(
    start_date,
    end_date,
    as_of_timestamp,
    source_url = g5_cboe_vix_history_url(),
    http_get = httr::GET) {
  response <- http_get(source_url)
  status <- httr::status_code(response)
  response_text <- httr::content(response, as = "text", encoding = "UTF-8")
  if (status < 200L || status >= 300L) {
    stop(paste0("Cboe VIX request failed with HTTP ", status, "."), call. = FALSE)
  }
  data <- g5_cboe_parse_vix_history(
    response_text,
    start_date = start_date,
    end_date = end_date,
    as_of_timestamp = as_of_timestamp,
    source_url = source_url
  )
  list(data = data, response_text = response_text, http_status = status, source_url = source_url)
}
