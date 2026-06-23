# Daily market-session resolution helpers.

.g5_as_posix <- function(x, tz) {
  if (inherits(x, "POSIXt")) {
    return(as.POSIXct(format(x, tz = tz, usetz = TRUE), tz = tz))
  }
  as.POSIXct(x, tz = tz)
}

g5_previous_trading_weekday <- function(date, holiday_dates = as.Date(character())) {
  d <- as.Date(date) - 1L
  while (weekdays(d) %in% c("Saturday", "Sunday") || d %in% holiday_dates) {
    d <- d - 1L
  }
  d
}

g5_is_trading_weekday <- function(date, holiday_dates = as.Date(character())) {
  d <- as.Date(date)
  !(weekdays(d) %in% c("Saturday", "Sunday")) && !(d %in% holiday_dates)
}

g5_resolve_latest_completed_session <- function(
  as_of_timestamp,
  timezone = "America/New_York",
  market_close_time = "16:00:00",
  holiday_dates = as.Date(character())
) {
  if (missing(as_of_timestamp) || is.null(as_of_timestamp)) {
    g5_stop("as_of_timestamp is required; do not infer latest sessions implicitly.")
  }

  as_of_local <- .g5_as_posix(as_of_timestamp, timezone)
  as_of_date <- as.Date(as_of_local, tz = timezone)
  close_at <- as.POSIXct(
    paste(as_of_date, market_close_time),
    tz = timezone
  )

  if (!g5_is_trading_weekday(as_of_date, holiday_dates)) {
    resolved <- g5_previous_trading_weekday(as_of_date + 1L, holiday_dates)
    reason <- "as_of_date_not_trading_weekday"
  } else if (as_of_local >= close_at) {
    resolved <- as_of_date
    reason <- "as_of_after_market_close"
  } else {
    resolved <- g5_previous_trading_weekday(as_of_date, holiday_dates)
    reason <- "as_of_before_market_close"
  }

  data.frame(
    as_of_timestamp = as.character(as_of_local),
    timezone = timezone,
    latest_completed_session = as.Date(resolved),
    resolution_reason = reason,
    stringsAsFactors = FALSE
  )
}
