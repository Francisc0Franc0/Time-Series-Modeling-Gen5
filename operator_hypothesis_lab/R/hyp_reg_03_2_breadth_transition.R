hreg32_stop <- function(message) stop(paste0("[HYP-REG-03.2] ", message), call. = FALSE)

hreg32_contract <- function() {
  list(
    hypothesis_id = "HYP-REG-03.2",
    as_of_timestamp = "2026-08-14 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    moving_average = 20L,
    trend_slow = 60L,
    transition_lookback = 20L,
    percentile_lookback = 252L,
    horizon = 20L,
    sector_assets = 10L,
    registry_assets = 12L,
    simulations = 200L,
    minimum_state_rows = 100L,
    minimum_offset_state_rows = 5L,
    minimum_valid_offsets = 15L,
    minimum_stable_offsets = 14L,
    minimum_stable_years = 4L,
    maximum_return_gap = -0.0075,
    minimum_down_gap = 0.10,
    minimum_auc = 0.55
  )
}

hreg32_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg32_stop("Lag must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA_real_, length(x)))
  c(rep(NA_real_, n), head(x, -n))
}

hreg32_lead <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg32_stop("Lead must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA_real_, length(x)))
  c(tail(x, -n), rep(NA_real_, n))
}

hreg32_sma <- function(x, n) {
  n <- as.integer(n)
  if (n < 1L) hreg32_stop("SMA length must be positive.")
  as.numeric(stats::filter(as.numeric(x), rep(1 / n, n), sides = 1L))
}

hreg32_prior_percentile <- function(x, lookback = 252L) {
  out <- rep(NA_real_, length(x)); lookback <- as.integer(lookback)
  if (length(x) <= lookback) return(out)
  for (i in seq.int(lookback + 1L, length(x))) {
    history <- x[seq.int(i - lookback, i - 1L)]
    if (is.finite(x[[i]]) && all(is.finite(history))) out[[i]] <- mean(history <= x[[i]])
  }
  out
}

hreg32_forward_open_return <- function(open, horizon = 20L) {
  n <- length(open); horizon <- as.integer(horizon); out <- rep(NA_real_, n)
  if (n <= horizon + 1L) return(out)
  idx <- seq_len(n - horizon - 1L)
  out[idx] <- log(open[idx + horizon + 1L] / open[idx + 1L])
  out
}

hreg32_validate_bars <- function(bars, contract = hreg32_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  if (!is.data.frame(bars) || !nrow(bars) || !all(required %in% names(bars))) hreg32_stop("Daily-bar schema is incomplete or empty.")
  x <- bars; x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg32_stop("Dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg32_stop("Confirmation rows entered the diagnostic.")
  numeric_cols <- c("open", "high", "low", "close", "volume")
  if (any(!is.finite(as.matrix(x[numeric_cols]))) || any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) hreg32_stop("OHLCV values are invalid.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg32_build_ledger <- function(bars, sector_symbols, contract = hreg32_contract()) {
  x <- hreg32_validate_bars(bars, contract)
  if (length(sector_symbols) != contract$sector_assets || !all(c(sector_symbols, "RSP", "SPY") %in% unique(x$symbol))) hreg32_stop("Signal universe does not match the frozen registry.")
  sector_parts <- lapply(sector_symbols, function(symbol) {
    z <- x[x$symbol == symbol, c("session_date", "close"), drop = FALSE]
    z[[paste0("depth_", symbol)]] <- log(z$close / hreg32_sma(z$close, contract$moving_average))
    z[c("session_date", paste0("depth_", symbol))]
  })
  ledger <- Reduce(function(a, b) merge(a, b, by = "session_date", all = FALSE, sort = TRUE), sector_parts)
  rsp <- x[x$symbol == "RSP", c("session_date", "close"), drop = FALSE]; names(rsp)[[2L]] <- "rsp_close"
  spy <- x[x$symbol == "SPY", c("session_date", "open", "close"), drop = FALSE]; names(spy)[2:3] <- c("spy_open", "spy_close")
  ledger <- merge(merge(ledger, rsp, by = "session_date", all = FALSE, sort = TRUE), spy, by = "session_date", all = FALSE, sort = TRUE)
  depth_cols <- paste0("depth_", sector_symbols); depth <- as.matrix(ledger[depth_cols])
  ledger$sector_inputs <- rowSums(is.finite(depth))
  ledger$breadth_level <- apply(depth, 1L, function(v) if (all(is.finite(v))) stats::median(v) else NA_real_)
  ledger$participation <- apply(depth, 1L, function(v) if (all(is.finite(v))) mean(v >= 0) else NA_real_)
  ledger$dispersion_iqr <- apply(depth, 1L, function(v) if (all(is.finite(v))) as.numeric(stats::quantile(v, .75) - stats::quantile(v, .25)) else NA_real_)
  ledger$breadth_change20 <- ledger$breadth_level - hreg32_lag(ledger$breadth_level, contract$transition_lookback)
  ledger$leadership_log_ratio <- log(ledger$rsp_close / ledger$spy_close)
  ledger$leadership_change20 <- ledger$leadership_log_ratio - hreg32_lag(ledger$leadership_log_ratio, contract$transition_lookback)
  ledger$spy_sma20 <- hreg32_sma(ledger$spy_close, contract$moving_average)
  ledger$spy_sma60 <- hreg32_sma(ledger$spy_close, contract$trend_slow)
  ledger$spy_trend_score <- log(ledger$spy_sma20 / ledger$spy_sma60)
  ledger$positive_spy_trend <- is.finite(ledger$spy_trend_score) & ledger$spy_trend_score >= 0
  ledger$breadth_change_percentile <- hreg32_prior_percentile(ledger$breadth_change20, contract$percentile_lookback)
  ledger$leadership_change_percentile <- hreg32_prior_percentile(ledger$leadership_change20, contract$percentile_lookback)
  ledger$dispersion_percentile <- hreg32_prior_percentile(ledger$dispersion_iqr, contract$percentile_lookback)
  ledger$narrowing_risk_score <- 1 - (ledger$breadth_change_percentile + ledger$leadership_change_percentile) / 2
  ledger$state <- "PRICE_TREND_NOT_POSITIVE"
  pos <- ledger$positive_spy_trend
  ledger$state[pos & ledger$breadth_change20 >= 0 & ledger$leadership_change20 >= 0] <- "HEALTHY"
  ledger$state[pos & ledger$breadth_change20 < 0 & ledger$leadership_change20 < 0] <- "NARROWING"
  ledger$state[pos & ledger$breadth_change20 < 0 & ledger$leadership_change20 >= 0] <- "MIXED_BREADTH_WEAK"
  ledger$state[pos & ledger$breadth_change20 >= 0 & ledger$leadership_change20 < 0] <- "MIXED_LEADERSHIP_WEAK"
  ledger$forward_return_h20 <- hreg32_forward_open_return(ledger$spy_open, contract$horizon)
  ledger$down_h20 <- ifelse(is.finite(ledger$forward_return_h20), ledger$forward_return_h20 < 0, NA)
  ledger$future_breadth_change_h20 <- hreg32_lead(ledger$breadth_level, contract$horizon) - ledger$breadth_level
  ledger$future_leadership_change_h20 <- hreg32_lead(ledger$leadership_log_ratio, contract$horizon) - ledger$leadership_log_ratio
  ledger$analysis_index <- seq_len(nrow(ledger))
  ledger$offset <- (ledger$analysis_index - 1L) %% contract$horizon
  ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
}

hreg32_state_summary <- function(ledger) {
  rows <- lapply(split(ledger, ledger$state), function(x) data.frame(
    state = x$state[[1L]], observations = sum(is.finite(x$forward_return_h20)),
    down_observations = sum(x$down_h20 %in% TRUE, na.rm = TRUE),
    down_rate = mean(x$down_h20, na.rm = TRUE),
    median_return = stats::median(x$forward_return_h20, na.rm = TRUE),
    mean_return = mean(x$forward_return_h20, na.rm = TRUE), stringsAsFactors = FALSE))
  do.call(rbind, rows)
}

hreg32_state_contrast <- function(ledger, minimum_rows = 1L) {
  n <- ledger[ledger$state == "NARROWING" & is.finite(ledger$forward_return_h20), ]
  h <- ledger[ledger$state == "HEALTHY" & is.finite(ledger$forward_return_h20), ]
  valid <- nrow(n) >= minimum_rows && nrow(h) >= minimum_rows
  data.frame(narrowing_n = nrow(n), healthy_n = nrow(h),
    narrowing_median_return = if (nrow(n)) stats::median(n$forward_return_h20) else NA_real_,
    healthy_median_return = if (nrow(h)) stats::median(h$forward_return_h20) else NA_real_,
    return_gap = if (valid) stats::median(n$forward_return_h20) - stats::median(h$forward_return_h20) else NA_real_,
    narrowing_down_rate = if (nrow(n)) mean(n$down_h20) else NA_real_,
    healthy_down_rate = if (nrow(h)) mean(h$down_h20) else NA_real_,
    down_rate_gap = if (valid) mean(n$down_h20) - mean(h$down_h20) else NA_real_, valid = valid, stringsAsFactors = FALSE)
}

hreg32_auc <- function(score, outcome) {
  keep <- is.finite(score) & !is.na(outcome); score <- score[keep]; outcome <- as.logical(outcome[keep])
  n1 <- sum(outcome); n0 <- sum(!outcome)
  if (!n1 || !n0) return(NA_real_)
  ranks <- rank(score, ties.method = "average")
  (sum(ranks[outcome]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

hreg32_continuous_summary <- function(ledger) {
  x <- ledger[ledger$positive_spy_trend & is.finite(ledger$forward_return_h20), ]
  features <- c("breadth_level", "breadth_change20", "leadership_change20", "narrowing_risk_score", "dispersion_iqr")
  out <- do.call(rbind, lapply(features, function(feature) {
    keep <- is.finite(x[[feature]])
    data.frame(feature = feature, observations = sum(keep),
      spearman_return = if (sum(keep) >= 5L) suppressWarnings(stats::cor(x[[feature]][keep], x$forward_return_h20[keep], method = "spearman")) else NA_real_,
      down_auc = if (feature == "narrowing_risk_score") hreg32_auc(x[[feature]], x$down_h20) else NA_real_, stringsAsFactors = FALSE)
  }))
  out
}

hreg32_offset_summary <- function(ledger, contract = hreg32_contract()) {
  do.call(rbind, lapply(0:(contract$horizon - 1L), function(offset) {
    out <- hreg32_state_contrast(ledger[ledger$offset == offset, ], contract$minimum_offset_state_rows)
    cbind(data.frame(offset = offset, stringsAsFactors = FALSE), out)
  }))
}

hreg32_period_summary <- function(ledger) {
  periods <- list(`2018-2020` = ledger$session_date < as.Date("2021-01-01"), `2021-2023` = ledger$session_date >= as.Date("2021-01-01"))
  do.call(rbind, lapply(names(periods), function(name) cbind(data.frame(period = name, stringsAsFactors = FALSE), hreg32_state_contrast(ledger[periods[[name]], ]))))
}

hreg32_calendar_summary <- function(ledger) {
  years <- 2018:2023
  do.call(rbind, lapply(years, function(year) {
    x <- ledger[as.integer(format(ledger$session_date, "%Y")) == year, ]
    cbind(data.frame(year = year, stringsAsFactors = FALSE), hreg32_state_contrast(x))
  }))
}

hreg32_semantic_summary <- function(ledger) {
  periods <- c("ALL", "2018-2020", "2021-2023")
  do.call(rbind, lapply(periods, function(period) {
    x <- if (period == "ALL") ledger else if (period == "2018-2020") ledger[ledger$session_date < as.Date("2021-01-01"), ] else ledger[ledger$session_date >= as.Date("2021-01-01"), ]
    n <- x[x$state == "NARROWING", ]; h <- x[x$state == "HEALTHY", ]
    data.frame(period = period, narrowing_n = nrow(n), healthy_n = nrow(h),
      future_breadth_narrowing = stats::median(n$future_breadth_change_h20, na.rm = TRUE),
      future_breadth_healthy = stats::median(h$future_breadth_change_h20, na.rm = TRUE),
      future_breadth_gap = stats::median(n$future_breadth_change_h20, na.rm = TRUE) - stats::median(h$future_breadth_change_h20, na.rm = TRUE),
      future_leadership_narrowing = stats::median(n$future_leadership_change_h20, na.rm = TRUE),
      future_leadership_healthy = stats::median(h$future_leadership_change_h20, na.rm = TRUE),
      future_leadership_gap = stats::median(n$future_leadership_change_h20, na.rm = TRUE) - stats::median(h$future_leadership_change_h20, na.rm = TRUE), stringsAsFactors = FALSE)
  }))
}

hreg32_rotate <- function(x, shift) {
  n <- length(x); if (!n) return(x); shift <- as.integer(shift %% n)
  if (shift == 0L) return(x)
  c(tail(x, shift), head(x, n - shift))
}

hreg32_shift_states <- function(ledger, simulation_id) {
  states <- ledger$state; eligible <- ledger$positive_spy_trend
  groups <- split(which(eligible), format(ledger$session_date[eligible], "%Y")); group_id <- 0L
  for (idx in groups) {
    group_id <- group_id + 1L
    if (length(idx) < 3L) next
    shift <- 1L + ((as.integer(simulation_id) * 37L + group_id * 17L) %% (length(idx) - 1L))
    states[idx] <- hreg32_rotate(states[idx], shift)
  }
  states
}

hreg32_circular_controls <- function(ledger, contract = hreg32_contract()) {
  do.call(rbind, lapply(seq_len(contract$simulations), function(simulation_id) {
    x <- ledger; x$state <- hreg32_shift_states(ledger, simulation_id)
    cbind(data.frame(simulation_id = simulation_id, stringsAsFactors = FALSE), hreg32_state_contrast(x))
  }))
}
