# Deterministic Wikimedia page-view collection for alternative-data POCs.

adw_stop <- function(message) stop(message, call. = FALSE)

adw_contract <- function() {
  list(
    hypothesis_id = "ADL-WIKI-01.1",
    authority = "COLLECTION_AND_HANDLING_POC_ONLY",
    project = "en.wikipedia.org",
    response_project = "en.wikipedia",
    article = "GameStop",
    access = "all-access",
    agent = "user",
    granularity = "daily",
    start_date = as.Date("2019-01-01"),
    end_date = as.Date("2023-12-31"),
    as_of_timestamp = "2026-09-01T00:00:00Z",
    endpoint = "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article",
    user_agent = paste0(
      "Gen5-Alternative-Data-Lab/0.1 ",
      "(github.com/Francisc0Franc0/Time-Series-Modeling-Gen5)"
    )
  )
}

adw_validate_contract <- function(contract = adw_contract()) {
  required <- c(
    "hypothesis_id", "authority", "project", "response_project", "article", "access", "agent",
    "granularity", "start_date", "end_date", "as_of_timestamp", "endpoint",
    "user_agent"
  )
  if (!all(required %in% names(contract))) {
    adw_stop("Wikimedia contract is missing required fields.")
  }
  if (!identical(contract$authority, "COLLECTION_AND_HANDLING_POC_ONLY")) {
    adw_stop("Wikimedia contract authority changed unexpectedly.")
  }
  if (!identical(contract$granularity, "daily")) {
    adw_stop("The first Wikimedia POC must remain daily.")
  }
  start_date <- as.Date(contract$start_date)
  end_date <- as.Date(contract$end_date)
  if (is.na(start_date) || is.na(end_date) || start_date > end_date) {
    adw_stop("Wikimedia contract has an invalid date range.")
  }
  as_of <- as.POSIXct(
    contract$as_of_timestamp,
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  if (is.na(as_of) || end_date > as.Date(as_of, tz = "UTC")) {
    adw_stop("Wikimedia request is not bounded by its explicit as_of_timestamp.")
  }
  if (!nzchar(contract$article) || !nzchar(contract$user_agent)) {
    adw_stop("Wikimedia article and user agent must be explicit.")
  }
  contract$start_date <- start_date
  contract$end_date <- end_date
  contract
}

adw_request_url <- function(contract = adw_contract()) {
  contract <- adw_validate_contract(contract)
  article <- utils::URLencode(contract$article, reserved = TRUE)
  paste(
    contract$endpoint,
    contract$project,
    contract$access,
    contract$agent,
    article,
    contract$granularity,
    format(contract$start_date, "%Y%m%d"),
    format(contract$end_date, "%Y%m%d"),
    sep = "/"
  )
}

adw_fetch_payload <- function(contract = adw_contract(), attempts = 4L) {
  contract <- adw_validate_contract(contract)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    adw_stop("jsonlite is required for Wikimedia collection.")
  }
  attempts <- as.integer(attempts)
  if (is.na(attempts) || attempts < 1L) adw_stop("attempts must be positive.")
  request_url <- adw_request_url(contract)
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    raw_json <- tryCatch({
      con <- base::url(
        request_url,
        open = "rb",
        headers = c(
          "User-Agent" = contract$user_agent,
          "Accept" = "application/json"
        )
      )
      on.exit(close(con), add = TRUE)
      paste(readLines(con, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    }, error = function(e) {
      last_error <<- e
      NULL
    })
    if (!is.null(raw_json) && nzchar(raw_json)) {
      payload <- tryCatch(
        jsonlite::fromJSON(raw_json, simplifyVector = FALSE),
        error = function(e) adw_stop(paste("Wikimedia JSON parse failed:", conditionMessage(e)))
      )
      return(list(
        request_url = request_url,
        raw_json = raw_json,
        payload = payload,
        retrieved_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ))
    }
    if (attempt < attempts) Sys.sleep(attempt)
  }
  adw_stop(paste(
    "Wikimedia request failed after", attempts, "attempts:",
    if (is.null(last_error)) "empty response" else conditionMessage(last_error)
  ))
}

adw_parse_payload <- function(payload, contract = adw_contract()) {
  contract <- adw_validate_contract(contract)
  items <- payload$items
  if (is.null(items) || !length(items)) adw_stop("Wikimedia payload contains no items.")
  if (is.data.frame(items)) {
    rows <- lapply(seq_len(nrow(items)), function(i) as.list(items[i, , drop = FALSE]))
  } else {
    rows <- items
  }
  required <- c("project", "article", "granularity", "timestamp", "access", "agent", "views")
  parsed <- lapply(rows, function(item) {
    if (!all(required %in% names(item))) adw_stop("Wikimedia item has an unexpected schema.")
    timestamp <- as.character(item$timestamp[[1L]])
    if (!grepl("^[0-9]{10}$", timestamp)) adw_stop("Wikimedia daily timestamp is malformed.")
    data.frame(
      project = as.character(item$project[[1L]]),
      article = as.character(item$article[[1L]]),
      granularity = as.character(item$granularity[[1L]]),
      timestamp_utc = timestamp,
      date = as.Date(substr(timestamp, 1L, 8L), format = "%Y%m%d"),
      access = as.character(item$access[[1L]]),
      agent = as.character(item$agent[[1L]]),
      views = as.numeric(item$views[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, parsed)
  out <- out[order(out$date), , drop = FALSE]
  rownames(out) <- NULL
  if (anyNA(out$date) || anyNA(out$views) || any(out$views < 0)) {
    adw_stop("Wikimedia payload contains invalid dates or view counts.")
  }
  if (anyDuplicated(out$date)) adw_stop("Wikimedia payload contains duplicate daily rows.")
  if (any(out$date < contract$start_date | out$date > contract$end_date)) {
    adw_stop("Wikimedia payload escaped the frozen date range.")
  }
  if (!all(out$project == contract$response_project) || !all(out$article == contract$article) ||
      !all(out$granularity == contract$granularity) || !all(out$access == contract$access) ||
      !all(out$agent == contract$agent)) {
    adw_stop("Wikimedia payload does not reproduce the frozen request dimensions.")
  }
  out
}

adw_complete_calendar <- function(observations, contract = adw_contract()) {
  contract <- adw_validate_contract(contract)
  calendar <- data.frame(
    date = seq(contract$start_date, contract$end_date, by = "day"),
    stringsAsFactors = FALSE
  )
  values <- observations[c("date", "views")]
  values$observed_from_api <- TRUE
  out <- merge(calendar, values, by = "date", all.x = TRUE, sort = TRUE)
  out$observed_from_api[is.na(out$observed_from_api)] <- FALSE
  out$missing_reason <- ifelse(
    out$observed_from_api,
    NA_character_,
    "API_OMITTED_ZERO_OR_NOT_LOADED_UNRESOLVED"
  )
  out
}

adw_trailing_median <- function(values, window = 28L) {
  window <- as.integer(window)
  if (is.na(window) || window < 1L) adw_stop("Trailing-median window must be positive.")
  vapply(seq_along(values), function(i) {
    x <- values[seq.int(max(1L, i - window + 1L), i)]
    if (!any(is.finite(x))) return(NA_real_)
    stats::median(x, na.rm = TRUE)
  }, numeric(1L))
}
