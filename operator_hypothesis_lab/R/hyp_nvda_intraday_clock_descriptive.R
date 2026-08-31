nic_stop <- function(message) {
  stop(paste0("[NVDA INTRADAY CLOCK] ", message), call. = FALSE)
}

nic_slot_labels <- function() {
  starts <- seq(
    as.POSIXct("2000-01-03 09:30:00", tz = "America/New_York"),
    as.POSIXct("2000-01-03 15:30:00", tz = "America/New_York"),
    by = "30 min"
  )
  ends <- starts + 30 * 60
  data.frame(
    bar_slot = 1:13,
    clock_order = 1:13,
    bar_time_et = format(starts, "%H:%M:%S"),
    clock_label = paste(format(starts, "%H:%M"), format(ends, "%H:%M"), sep = "-") ,
    stringsAsFactors = FALSE
  )
}

nic_validate_bars <- function(bars, symbol = "NVDA") {
  required <- c(
    "symbol", "timestamp_utc", "session_date", "bar_time_et", "bar_slot",
    "open", "high", "low", "close", "volume", "feed", "timeframe",
    "adjustment", "as_of_timestamp"
  )
  if (!is.data.frame(bars) || !all(required %in% names(bars))) {
    nic_stop("Bar schema is incomplete.")
  }
  if (!nrow(bars) || !identical(unique(as.character(bars$symbol)), symbol)) {
    nic_stop(paste("Bars must contain exactly", symbol, "and at least one row."))
  }
  if (anyDuplicated(bars[c("symbol", "timestamp_utc")])) {
    nic_stop("Duplicate symbol/timestamp rows detected.")
  }
  numeric_ok <- is.finite(bars$open) & bars$open > 0 &
    is.finite(bars$high) & bars$high > 0 &
    is.finite(bars$low) & bars$low > 0 &
    is.finite(bars$close) & bars$close > 0 &
    is.finite(bars$volume) & bars$volume >= 0
  ohlc_ok <- bars$high >= pmax(bars$open, bars$close, bars$low) &
    bars$low <= pmin(bars$open, bars$close, bars$high)
  if (!all(numeric_ok) || !all(ohlc_ok)) nic_stop("Invalid OHLCV values detected.")
  if (!all(bars$bar_slot %in% 1:13)) nic_stop("Bars fall outside the regular-session slot grid.")
  if (!all(bars$feed == "sip") || !all(bars$timeframe == "30Min") ||
      !all(bars$adjustment == "all")) {
    nic_stop("Feed, timeframe, or adjustment differs from the frozen contract.")
  }
  invisible(TRUE)
}

nic_build_clock_points <- function(bars, analysis_start, analysis_end,
                                   symbol = "NVDA",
                                   unavailable_session_dates = as.Date(character())) {
  nic_validate_bars(bars, symbol)
  analysis_start <- as.Date(analysis_start)
  analysis_end <- as.Date(analysis_end)
  unavailable_session_dates <- as.Date(unavailable_session_dates)
  if (any(is.na(c(analysis_start, analysis_end))) || analysis_start > analysis_end) {
    nic_stop("Analysis dates are invalid.")
  }

  x <- bars[order(bars$timestamp_utc), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  if (min(x$session_date) >= analysis_start) {
    nic_stop("At least one pre-analysis session is required for the first overnight gap.")
  }
  if (max(x$session_date) < analysis_end) nic_stop("Analysis end is not covered.")

  slot_map <- nic_slot_labels()
  bar_points <- x[x$session_date >= analysis_start & x$session_date <= analysis_end, , drop = FALSE]
  bar_points <- merge(
    bar_points, slot_map,
    by = c("bar_slot", "bar_time_et"), all.x = TRUE, sort = FALSE
  )
  if (any(is.na(bar_points$clock_order))) nic_stop("Could not map one or more bar slots.")
  bar_points$observation_type <- "RTH_BAR"
  bar_points$log_return <- log(bar_points$close / bar_points$open)
  bar_points$prior_session <- as.Date(NA)
  bar_points$gap_has_complete_prior <- NA

  sessions <- split(seq_len(nrow(x)), x$session_date)
  session_dates <- as.Date(names(sessions))
  session_dates <- sort(session_dates)
  gap_rows <- vector("list", length(session_dates))
  z <- 0L
  for (i in seq_along(session_dates)) {
    current_date <- session_dates[[i]]
    if (current_date < analysis_start || current_date > analysis_end || i == 1L) next
    prior_date <- session_dates[[i - 1L]]
    skipped_unavailable <- any(
      unavailable_session_dates > prior_date & unavailable_session_dates < current_date
    )
    current <- x[x$session_date == current_date, , drop = FALSE]
    prior <- x[x$session_date == prior_date, , drop = FALSE]
    current <- current[order(current$bar_slot), , drop = FALSE]
    prior <- prior[order(prior$bar_slot), , drop = FALSE]
    z <- z + 1L
    gap_rows[[z]] <- data.frame(
      bar_slot = 0L,
      bar_time_et = "OVERNIGHT",
      symbol = symbol,
      timestamp_utc = current$timestamp_utc[[1L]],
      session_date = current_date,
      open = current$open[[1L]],
      high = NA_real_, low = NA_real_, close = prior$close[[nrow(prior)]],
      volume = NA_real_, feed = current$feed[[1L]], timeframe = "overnight",
      adjustment = current$adjustment[[1L]],
      as_of_timestamp = current$as_of_timestamp[[1L]],
      clock_order = 0L,
      clock_label = "Prior close-open gap",
      observation_type = "OVERNIGHT_GAP",
      log_return = if (skipped_unavailable) NA_real_ else
        log(current$open[[1L]] / prior$close[[nrow(prior)]]),
      prior_session = prior_date,
      gap_has_complete_prior = !skipped_unavailable,
      stringsAsFactors = FALSE
    )
  }
  gap_points <- if (z) do.call(rbind, gap_rows[seq_len(z)]) else bar_points[0, , drop = FALSE]
  if (nrow(gap_points)) gap_points <- gap_points[is.finite(gap_points$log_return), , drop = FALSE]

  keep <- c(
    "symbol", "timestamp_utc", "session_date", "prior_session", "clock_order",
    "clock_label", "bar_slot", "bar_time_et", "observation_type", "log_return",
    "gap_has_complete_prior", "open", "close", "feed", "timeframe", "adjustment",
    "as_of_timestamp"
  )
  points <- rbind(bar_points[keep], gap_points[keep])
  points$log_return_pct <- 100 * points$log_return
  points <- points[order(points$clock_order, points$session_date), , drop = FALSE]
  rownames(points) <- NULL
  if (!nrow(points) || any(!is.finite(points$log_return))) nic_stop("Clock-point construction failed.")
  points
}

nic_clock_summary <- function(points) {
  required <- c("clock_order", "clock_label", "observation_type", "log_return")
  if (!is.data.frame(points) || !all(required %in% names(points)) || !nrow(points)) {
    nic_stop("Clock points are unavailable for summary.")
  }
  groups <- split(seq_len(nrow(points)), points$clock_order)
  rows <- lapply(groups, function(index) {
    x <- points[index, , drop = FALSE]
    data.frame(
      clock_order = x$clock_order[[1L]],
      clock_label = x$clock_label[[1L]],
      observation_type = x$observation_type[[1L]],
      observations = nrow(x),
      mean_log_return = mean(x$log_return),
      median_log_return = stats::median(x$log_return),
      q25_log_return = unname(stats::quantile(x$log_return, 0.25, type = 8)),
      q75_log_return = unname(stats::quantile(x$log_return, 0.75, type = 8)),
      minimum_log_return = min(x$log_return),
      maximum_log_return = max(x$log_return),
      positive_fraction = mean(x$log_return > 0),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$clock_order), , drop = FALSE]
}
