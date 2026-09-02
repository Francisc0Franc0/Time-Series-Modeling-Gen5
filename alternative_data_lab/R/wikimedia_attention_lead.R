# Causal alignment helpers for the first Wikimedia attention lead test.

adwl_stop <- function(message) stop(message, call. = FALSE)

adwl_contract <- function() {
  list(
    hypothesis_id = "ADL-WIKI-02.1",
    parent_id = "ADL-WIKI-01.1",
    authority = "DESCRIPTIVE_LEADING_SIGNAL_POC_ONLY",
    symbol = "GME",
    article = "GameStop",
    attention_start = as.Date("2019-01-01"),
    attention_end = as.Date("2023-12-31"),
    market_end = as.Date("2023-12-29"),
    trailing_calendar_days = 28L,
    publication_buffer_hours = 48L,
    primary_forward_sessions = 1L,
    as_of_timestamp = "2026-09-01T00:00:00Z"
  )
}

adwl_validate_contract <- function(contract = adwl_contract()) {
  required <- c(
    "hypothesis_id", "parent_id", "authority", "symbol", "article",
    "attention_start", "attention_end", "market_end", "trailing_calendar_days",
    "publication_buffer_hours", "primary_forward_sessions", "as_of_timestamp"
  )
  if (!all(required %in% names(contract))) adwl_stop("Lead contract is missing required fields.")
  if (!identical(contract$authority, "DESCRIPTIVE_LEADING_SIGNAL_POC_ONLY")) {
    adwl_stop("Lead contract authority changed unexpectedly.")
  }
  if (!identical(as.integer(contract$trailing_calendar_days), 28L) ||
      !identical(as.integer(contract$publication_buffer_hours), 48L) ||
      !identical(as.integer(contract$primary_forward_sessions), 1L)) {
    adwl_stop("The first lead slice must preserve 28 days, 48 hours, and one session.")
  }
  if (contract$publication_buffer_hours %% 24L != 0L) {
    adwl_stop("This daily POC requires a whole-day publication buffer.")
  }
  dates <- as.Date(c(contract$attention_start, contract$attention_end, contract$market_end))
  if (anyNA(dates) || dates[[1L]] > dates[[2L]]) {
    adwl_stop("Lead contract has invalid date boundaries.")
  }
  as_of <- as.POSIXct(contract$as_of_timestamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.na(as_of) || max(dates) > as.Date(as_of, tz = "UTC")) {
    adwl_stop("Lead contract is not bounded by its explicit as_of_timestamp.")
  }
  contract$attention_start <- dates[[1L]]
  contract$attention_end <- dates[[2L]]
  contract$market_end <- dates[[3L]]
  contract$trailing_calendar_days <- as.integer(contract$trailing_calendar_days)
  contract$publication_buffer_hours <- as.integer(contract$publication_buffer_hours)
  contract$primary_forward_sessions <- as.integer(contract$primary_forward_sessions)
  contract
}

adwl_attention_features <- function(daily, contract = adwl_contract()) {
  contract <- adwl_validate_contract(contract)
  required <- c("date", "views", "observed_from_api")
  if (!all(required %in% names(daily))) adwl_stop("Attention ledger lacks required columns.")
  x <- daily[order(as.Date(daily$date)), required, drop = FALSE]
  x$date <- as.Date(x$date)
  x$views <- as.numeric(x$views)
  x$observed_from_api <- as.logical(x$observed_from_api)
  if (anyDuplicated(x$date) || anyNA(x$date)) adwl_stop("Attention ledger has duplicate or invalid dates.")
  if (min(x$date) > contract$attention_start || max(x$date) < contract$attention_end) {
    adwl_stop("Attention ledger does not cover the frozen interval.")
  }
  x <- x[x$date >= contract$attention_start & x$date <= contract$attention_end, , drop = FALSE]
  n <- nrow(x)
  prior_median <- rep(NA_real_, n)
  prior_count <- integer(n)
  for (i in seq_len(n)) {
    prior_dates <- x$date >= x$date[[i]] - contract$trailing_calendar_days & x$date < x$date[[i]]
    eligible <- prior_dates & x$observed_from_api & is.finite(x$views) & x$views > 0
    prior_count[[i]] <- sum(eligible)
    if (prior_count[[i]] == contract$trailing_calendar_days) {
      prior_median[[i]] <- stats::median(x$views[eligible])
    }
  }
  x$prior_28d_median <- prior_median
  x$prior_observation_count <- prior_count
  x$attention_log_ratio <- ifelse(
    x$observed_from_api & is.finite(x$views) & x$views > 0 & is.finite(prior_median) & prior_median > 0,
    log(x$views / prior_median),
    NA_real_
  )
  buffer_days <- as.integer(contract$publication_buffer_hours / 24L)
  # A UTC measurement day d ends at d+1 00:00 UTC. The additional frozen
  # buffer is applied after that endpoint.
  x$safe_available_date <- x$date + 1L + buffer_days
  x
}

adwl_validate_bars <- function(bars, contract = adwl_contract()) {
  contract <- adwl_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe", "provider")
  if (!all(required %in% names(bars))) adwl_stop("GME bars lack required columns.")
  x <- bars[bars$symbol == contract$symbol, required, drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  x <- x[order(x$session_date), , drop = FALSE]
  if (!nrow(x) || anyDuplicated(x$session_date) || anyNA(x$session_date)) {
    adwl_stop("GME bar dates are missing or duplicated.")
  }
  if (!all(x$adjusted) || !all(x$timeframe == "1D") || !all(x$provider == "alpaca")) {
    adwl_stop("GME bars do not reproduce adjusted Alpaca daily authority.")
  }
  if (any(!is.finite(x$open) | x$open <= 0 | !is.finite(x$close) | x$close <= 0)) {
    adwl_stop("GME bars contain invalid prices.")
  }
  x[x$session_date <= contract$market_end, , drop = FALSE]
}

adwl_reaction_panel <- function(features, bars, contract = adwl_contract()) {
  contract <- adwl_validate_contract(contract)
  x <- adwl_validate_bars(bars, contract)
  x$completed_close_return <- c(NA_real_, diff(log(x$close)))
  f <- features[is.finite(features$attention_log_ratio), c(
    "date", "views", "prior_28d_median", "attention_log_ratio", "safe_available_date"
  )]
  names(f)[names(f) == "date"] <- "attention_date"
  out <- merge(
    f, x[c("session_date", "completed_close_return")],
    by.x = "attention_date", by.y = "session_date", all = FALSE, sort = TRUE
  )
  out
}

adwl_forward_panel <- function(features, bars, contract = adwl_contract()) {
  contract <- adwl_validate_contract(contract)
  x <- adwl_validate_bars(bars, contract)
  if (nrow(x) < 2L) adwl_stop("At least two GME sessions are required.")
  f <- features[is.finite(features$attention_log_ratio), c(
    "date", "views", "prior_28d_median", "attention_log_ratio", "safe_available_date"
  )]
  f <- f[order(f$safe_available_date, f$date), , drop = FALSE]
  session_rows <- seq_len(nrow(x) - contract$primary_forward_sessions)
  entry_dates <- x$session_date[session_rows]
  match_index <- findInterval(as.numeric(entry_dates), as.numeric(f$safe_available_date))
  keep <- match_index > 0L
  session_rows <- session_rows[keep]
  match_index <- match_index[keep]
  exit_rows <- session_rows + contract$primary_forward_sessions
  out <- data.frame(
    entry_session = x$session_date[session_rows],
    exit_session = x$session_date[exit_rows],
    source_attention_date = f$date[match_index],
    safe_available_date = f$safe_available_date[match_index],
    views = f$views[match_index],
    prior_28d_median = f$prior_28d_median[match_index],
    attention_log_ratio = f$attention_log_ratio[match_index],
    entry_open = x$open[session_rows],
    exit_open = x$open[exit_rows],
    future_open_log_return = log(x$open[exit_rows] / x$open[session_rows]),
    stringsAsFactors = FALSE
  )
  if (any(out$safe_available_date > out$entry_session)) {
    adwl_stop("Attention signal was joined before its safe availability date.")
  }
  if (any(out$source_attention_date >= out$entry_session)) {
    adwl_stop("Attention source day was not strictly prior to the entry session.")
  }
  out
}

adwl_relationship_summary <- function(x, y, relationship) {
  keep <- is.finite(x) & is.finite(y)
  x <- x[keep]
  y <- y[keep]
  if (length(x) < 3L || stats::sd(x) == 0 || stats::sd(y) == 0) {
    return(data.frame(
      relationship = relationship, observations = length(x), pearson = NA_real_,
      spearman = NA_real_, slope = NA_real_, r_squared = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  fit <- stats::lm(y ~ x)
  data.frame(
    relationship = relationship,
    observations = length(x),
    pearson = stats::cor(x, y, method = "pearson"),
    spearman = stats::cor(x, y, method = "spearman"),
    slope = unname(stats::coef(fit)[[2L]]),
    r_squared = summary(fit)$r.squared,
    stringsAsFactors = FALSE
  )
}
