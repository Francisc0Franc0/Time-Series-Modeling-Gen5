nlcp_stop <- function(message) stop(paste0("[NVDA LETF CLOSE] ", message), call. = FALSE)

nlcp_contract <- function() list(
  study_id = "HYP-NVDA-LETF-CLOSE-01.1",
  sample_role = "DESCRIPTIVE_MECHANISM_POC",
  symbols = c("NVDA", "NVDL"),
  leverage_factor = 1.5,
  analysis_start = as.Date("2023-01-03"),
  analysis_end = as.Date("2023-12-29"),
  confirmation_start = as.Date("2024-01-02"),
  as_of_timestamp = "2026-08-31 17:30:00 America/New_York",
  clocks = data.frame(
    clock = c("12:00", "14:00", "15:30"),
    anchor_bar = c("11:55:00", "13:55:00", "15:25:00"),
    local_open_bar = c("11:00:00", "13:00:00", "14:30:00"),
    outcome_end_bar = c("12:25:00", "14:25:00", "15:55:00"),
    stringsAsFactors = FALSE
  )
)

nlcp_validate_bars <- function(bars, contract = nlcp_contract()) {
  required <- c(
    "symbol", "timestamp_utc", "session_date", "bar_time_et", "bar_slot",
    "open", "high", "low", "close", "volume", "provider", "feed",
    "timeframe", "adjustment", "as_of_timestamp"
  )
  if (!is.data.frame(bars) || !all(required %in% names(bars)) || !nrow(bars)) {
    nlcp_stop("Bar schema is incomplete.")
  }
  if (!setequal(unique(as.character(bars$symbol)), contract$symbols)) {
    nlcp_stop("The exact NVDA/NVDL symbol pair is required.")
  }
  if (anyDuplicated(bars[c("symbol", "timestamp_utc")])) {
    nlcp_stop("Duplicate symbol/timestamp rows detected.")
  }
  finite <- is.finite(bars$open) & bars$open > 0 & is.finite(bars$high) & bars$high > 0 &
    is.finite(bars$low) & bars$low > 0 & is.finite(bars$close) & bars$close > 0 &
    is.finite(bars$volume) & bars$volume >= 0
  ohlc <- bars$high >= pmax(bars$open, bars$close, bars$low) &
    bars$low <= pmin(bars$open, bars$close, bars$high)
  if (!all(finite) || !all(ohlc)) nlcp_stop("Invalid OHLCV values detected.")
  if (!all(bars$provider == "alpaca") || !all(bars$feed == "sip") ||
      !all(bars$timeframe == "5Min") || !all(bars$adjustment == "all")) {
    nlcp_stop("Provider, feed, timeframe, or adjustment changed.")
  }
  if (max(as.Date(bars$session_date)) >= contract$confirmation_start) {
    nlcp_stop("The untouched 2024+ boundary was crossed.")
  }
  invisible(TRUE)
}

nlcp_exact_bar <- function(x, clock, field) {
  hit <- which(x$bar_time_et == clock)
  if (length(hit) != 1L) return(NA_real_)
  as.numeric(x[[field]][hit])
}

nlcp_previous_close_map <- function(bars, symbol) {
  x <- bars[bars$symbol == symbol, , drop = FALSE]
  x <- x[order(x$session_date, x$timestamp_utc), , drop = FALSE]
  groups <- split(seq_len(nrow(x)), as.Date(x$session_date))
  dates <- sort(as.Date(names(groups)))
  if (length(dates) < 2L) return(data.frame())
  rows <- lapply(seq.int(2L, length(dates)), function(i) {
    prior <- x[groups[[as.character(dates[[i - 1L]])]], , drop = FALSE]
    data.frame(
      session_date = dates[[i]], prior_session = dates[[i - 1L]],
      prior_close = tail(prior$close, 1L), stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

nlcp_build_clock_panel <- function(bars, contract = nlcp_contract()) {
  nlcp_validate_bars(bars, contract)
  x <- bars[order(bars$symbol, bars$timestamp_utc), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  prior_maps <- lapply(contract$symbols, function(sym) nlcp_previous_close_map(x, sym))
  names(prior_maps) <- contract$symbols
  dates <- sort(unique(x$session_date))
  dates <- dates[dates >= contract$analysis_start & dates <= contract$analysis_end]
  rows <- list()
  z <- 1L
  for (date in dates) {
    date <- as.Date(date, origin = "1970-01-01")
    symbol_rows <- lapply(contract$symbols, function(sym) {
      x[x$symbol == sym & x$session_date == date, , drop = FALSE]
    })
    names(symbol_rows) <- contract$symbols
    prior <- lapply(contract$symbols, function(sym) {
      y <- prior_maps[[sym]]
      y[y$session_date == date, , drop = FALSE]
    })
    names(prior) <- contract$symbols
    if (any(vapply(symbol_rows, nrow, integer(1L)) == 0L) ||
        any(vapply(prior, nrow, integer(1L)) != 1L)) next
    for (j in seq_len(nrow(contract$clocks))) {
      clock <- contract$clocks[j, , drop = FALSE]
      values <- list()
      complete <- TRUE
      for (sym in contract$symbols) {
        y <- symbol_rows[[sym]]
        values[[sym]] <- c(
          anchor = nlcp_exact_bar(y, clock$anchor_bar, "close"),
          local_open = nlcp_exact_bar(y, clock$local_open_bar, "open"),
          outcome_end = nlcp_exact_bar(y, clock$outcome_end_bar, "close"),
          prior_close = prior[[sym]]$prior_close[[1L]]
        )
        complete <- complete && all(is.finite(values[[sym]]) & values[[sym]] > 0)
      }
      if (!complete) next
      nvda_daily <- log(values$NVDA[["anchor"]] / values$NVDA[["prior_close"]])
      nvdl_daily <- log(values$NVDL[["anchor"]] / values$NVDL[["prior_close"]])
      nvda_future <- log(values$NVDA[["outcome_end"]] / values$NVDA[["anchor"]])
      nvdl_future <- log(values$NVDL[["outcome_end"]] / values$NVDL[["anchor"]])
      rows[[z]] <- data.frame(
        session_date = date, prior_session = prior$NVDA$prior_session[[1L]],
        clock = clock$clock, anchor_bar = clock$anchor_bar,
        outcome_end_bar = clock$outcome_end_bar,
        nvda_daily_to_anchor = nvda_daily,
        nvda_local_60m = log(values$NVDA[["anchor"]] / values$NVDA[["local_open"]]),
        nvda_future_30m = nvda_future,
        nvdl_daily_to_anchor = nvdl_daily,
        nvdl_future_30m = nvdl_future,
        tracking_residual_to_anchor = nvdl_daily - contract$leverage_factor * nvda_daily,
        tracking_residual_future_change = nvdl_future - contract$leverage_factor * nvda_future,
        stringsAsFactors = FALSE
      )
      z <- z + 1L
    }
  }
  if (!length(rows)) nlcp_stop("No synchronized clock observations were constructed.")
  out <- do.call(rbind, rows)
  out$session_date <- as.Date(out$session_date, origin = "1970-01-01")
  out$prior_session <- as.Date(out$prior_session, origin = "1970-01-01")
  out <- out[order(match(out$clock, contract$clocks$clock), out$session_date), , drop = FALSE]
  rownames(out) <- NULL
  out
}

nlcp_safe_cor <- function(x, y, method = "pearson") {
  if (length(x) < 3L || stats::sd(x) == 0 || stats::sd(y) == 0) return(NA_real_)
  unname(stats::cor(x, y, method = method))
}

nlcp_clock_summary <- function(panel, contract = nlcp_contract()) {
  groups <- split(seq_len(nrow(panel)), factor(panel$clock, levels = contract$clocks$clock))
  rows <- lapply(names(groups), function(clock) {
    x <- panel[groups[[clock]], , drop = FALSE]
    q20 <- unname(stats::quantile(x$nvda_daily_to_anchor, 0.20, type = 8))
    q80 <- unname(stats::quantile(x$nvda_daily_to_anchor, 0.80, type = 8))
    model <- stats::lm(nvda_future_30m ~ nvda_daily_to_anchor, data = x)
    data.frame(
      clock = clock, observations = nrow(x),
      daily_move_pearson = nlcp_safe_cor(x$nvda_daily_to_anchor, x$nvda_future_30m),
      daily_move_spearman = nlcp_safe_cor(x$nvda_daily_to_anchor, x$nvda_future_30m, "spearman"),
      daily_move_slope = unname(stats::coef(model)[[2L]]),
      local_60m_pearson = nlcp_safe_cor(x$nvda_local_60m, x$nvda_future_30m),
      same_direction_fraction = mean(sign(x$nvda_daily_to_anchor) == sign(x$nvda_future_30m)),
      bottom_quintile_future_mean = mean(x$nvda_future_30m[x$nvda_daily_to_anchor <= q20]),
      top_quintile_future_mean = mean(x$nvda_future_30m[x$nvda_daily_to_anchor >= q80]),
      top_minus_bottom_future_mean =
        mean(x$nvda_future_30m[x$nvda_daily_to_anchor >= q80]) -
        mean(x$nvda_future_30m[x$nvda_daily_to_anchor <= q20]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

nlcp_tracking_summary <- function(panel, contract = nlcp_contract()) {
  groups <- split(seq_len(nrow(panel)), factor(panel$clock, levels = contract$clocks$clock))
  rows <- lapply(names(groups), function(clock) {
    x <- panel[groups[[clock]], , drop = FALSE]
    model <- stats::lm(tracking_residual_future_change ~ tracking_residual_to_anchor, data = x)
    data.frame(
      clock = clock, observations = nrow(x),
      residual_correlation = nlcp_safe_cor(
        x$tracking_residual_to_anchor, x$tracking_residual_future_change
      ),
      residual_slope = unname(stats::coef(model)[[2L]]),
      mean_absolute_residual_to_anchor = mean(abs(x$tracking_residual_to_anchor)),
      mean_absolute_future_residual_change = mean(abs(x$tracking_residual_future_change)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
