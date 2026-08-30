edl_ms01_stop <- function(message) {
  stop(paste0("[EDL-MS-01] ", message), call. = FALSE)
}

edl_ms01_contract <- function() {
  list(
    study_id = "EDL_MS_01_RULE201_RECLAIM_DISCOVERY_01",
    symbols = c(
      "TSLA", "AMD", "NVDA",
      "GME", "AMC", "CVNA", "PLTR", "COIN", "SOFI", "RIVN"
    ),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    threshold = -0.10,
    discovery_band = c(-0.12, -0.08),
    strong_reclaim = 0.75,
    weak_close = 0.25,
    forward_sessions = c(1L, 3L, 5L)
  )
}

edl_ms01_validate_contract <- function(contract = edl_ms01_contract()) {
  expected <- c(
    "TSLA", "AMD", "NVDA",
    "GME", "AMC", "CVNA", "PLTR", "COIN", "SOFI", "RIVN"
  )
  if (!identical(contract$symbols, expected)) {
    edl_ms01_stop("The frozen discovery basket changed.")
  }
  if (!identical(contract$threshold, -0.10) ||
      !identical(contract$discovery_band, c(-0.12, -0.08))) {
    edl_ms01_stop("The fixed Rule 201 proxy threshold or discovery band changed.")
  }
  if (!identical(contract$forward_sessions, c(1L, 3L, 5L))) {
    edl_ms01_stop("The descriptive forward horizons changed.")
  }
  contract
}

edl_ms01_prior_median <- function(x, window = 20L) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (length(x) <= window) return(out)
  for (i in seq.int(window + 1L, length(x))) {
    prior <- x[seq.int(i - window, i - 1L)]
    out[[i]] <- if (all(is.finite(prior))) stats::median(prior) else NA_real_
  }
  out
}

edl_ms01_lead <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) edl_ms01_stop("Lead length must be non-negative.")
  if (n == 0L) return(x)
  c(x[seq.int(n + 1L, length(x))], rep(NA, n))
}

edl_ms01_build_symbol_ledger <- function(bars, contract = edl_ms01_contract()) {
  contract <- edl_ms01_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    edl_ms01_stop(paste("Missing required columns:", paste(missing, collapse = ", ")))
  }
  symbols <- unique(as.character(bars$symbol))
  if (length(symbols) != 1L) edl_ms01_stop("Build one symbol ledger at a time.")
  out <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  out$session_date <- as.Date(out$session_date)
  if (anyDuplicated(out$session_date)) edl_ms01_stop("Duplicate sessions detected.")
  numeric_columns <- c("open", "high", "low", "close", "volume")
  if (any(!vapply(out[numeric_columns], function(x) all(is.finite(x)), logical(1)))) {
    edl_ms01_stop("Non-finite OHLCV values detected.")
  }
  if (any(out$high < pmax(out$open, out$close, out$low)) ||
      any(out$low > pmin(out$open, out$close, out$high))) {
    edl_ms01_stop("Invalid OHLC ordering detected.")
  }

  out$row_index <- seq_len(nrow(out))
  out$prior_close <- c(NA_real_, head(out$close, -1L))
  out$minimum_intraday_return <- out$low / out$prior_close - 1
  daily_range <- out$high - out$low
  out$close_location_value <- ifelse(
    daily_range > 0, (out$close - out$low) / daily_range, NA_real_
  )
  out$dollar_volume <- out$close * out$volume
  out$prior_20_median_dollar_volume <- edl_ms01_prior_median(out$dollar_volume, 20L)
  out$abnormal_dollar_volume <-
    out$dollar_volume / out$prior_20_median_dollar_volume
  out$rule201_proxy_trigger <- is.finite(out$minimum_intraday_return) &
    out$minimum_intraday_return <= contract$threshold
  out$inside_discovery_band <- is.finite(out$minimum_intraday_return) &
    out$minimum_intraday_return >= contract$discovery_band[[1L]] &
    out$minimum_intraday_return <= contract$discovery_band[[2L]]
  out$threshold_group <- ifelse(
    out$rule201_proxy_trigger, "TRIGGERED_PROXY", "NEAR_MISS"
  )
  out$reclaim_group <- ifelse(
    out$close_location_value >= contract$strong_reclaim, "STRONG_RECLAIM",
    ifelse(out$close_location_value <= contract$weak_close, "WEAK_CLOSE", "MIDDLE_CLOSE")
  )
  out$event_category <- paste(out$threshold_group, out$reclaim_group, sep = "__")

  out$entry_session <- edl_ms01_lead(out$session_date, 1L)
  out$entry_open <- edl_ms01_lead(out$open, 1L)
  for (h in contract$forward_sessions) {
    exit_open <- edl_ms01_lead(out$open, h + 1L)
    exit_session <- edl_ms01_lead(out$session_date, h + 1L)
    out[[paste0("exit_", h, "_session")]] <- exit_session
    out[[paste0("forward_", h, "_open_log_return")]] <- log(exit_open / out$entry_open)
  }
  out
}

edl_ms01_build_ledger <- function(bars, contract = edl_ms01_contract()) {
  contract <- edl_ms01_validate_contract(contract)
  rows <- lapply(contract$symbols, function(symbol) {
    x <- bars[as.character(bars$symbol) == symbol, , drop = FALSE]
    if (!nrow(x)) edl_ms01_stop(paste("Missing frozen symbol", symbol))
    edl_ms01_build_symbol_ledger(x, contract)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

edl_ms01_select_event_tapes <- function(events) {
  targets <- c(
    "TRIGGERED_PROXY__STRONG_RECLAIM",
    "TRIGGERED_PROXY__WEAK_CLOSE",
    "NEAR_MISS__STRONG_RECLAIM",
    "NEAR_MISS__WEAK_CLOSE"
  )
  selected <- lapply(targets, function(target) {
    x <- events[
      events$event_category == target &
        is.finite(events$forward_5_open_log_return), , drop = FALSE
    ]
    x <- x[order(x$session_date, x$symbol), , drop = FALSE]
    if (!nrow(x)) edl_ms01_stop(paste("No event available for", target))
    x[1L, , drop = FALSE]
  })
  out <- do.call(rbind, selected)
  rownames(out) <- NULL
  out$tape_order <- seq_len(nrow(out))
  out
}
