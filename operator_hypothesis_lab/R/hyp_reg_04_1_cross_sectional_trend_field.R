hreg41_stop <- function(message) stop(paste0("[HYP-REG-04.1] ", message), call. = FALSE)

hreg41_contract <- function() {
  list(
    hypothesis_id = "HYP-REG-04.1",
    as_of_timestamp = "2026-08-14 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    trend_fast = 20L,
    trend_slow = 60L,
    volatility_lookback = 63L,
    flow_lookback = 5L,
    horizon = 20L,
    signal_assets = 24L,
    signal_groups = 4L,
    registry_assets = 25L,
    broad_participation = 0.60,
    broad_down_participation = 0.40,
    minimum_agreement = 0.60,
    minimum_state_rows = 100L,
    minimum_offset_rows = 5L,
    minimum_valid_offsets = 15L,
    minimum_stable_offsets = 14L,
    simulations = 200L
  )
}

hreg41_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg41_stop("Lag must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA_real_, length(x)))
  c(rep(NA_real_, n), head(x, -n))
}

hreg41_lead <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg41_stop("Lead must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA_real_, length(x)))
  c(tail(x, -n), rep(NA_real_, n))
}

hreg41_roll_sd <- function(x, n) {
  n <- as.integer(n)
  if (n < 2L) hreg41_stop("Rolling standard-deviation length must be at least two.")
  out <- rep(NA_real_, length(x))
  if (length(x) < n) return(out)
  for (i in seq.int(n, length(x))) {
    window <- x[seq.int(i - n + 1L, i)]
    if (all(is.finite(window))) out[[i]] <- stats::sd(window)
  }
  out
}

hreg41_forward_open_return <- function(open, horizon = 20L) {
  horizon <- as.integer(horizon)
  out <- rep(NA_real_, length(open))
  if (length(open) <= horizon + 1L) return(out)
  idx <- seq_len(length(open) - horizon - 1L)
  out[idx] <- log(open[idx + horizon + 1L] / open[idx + 1L])
  out
}

hreg41_validate_bars <- function(bars, contract = hreg41_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  if (!is.data.frame(bars) || !nrow(bars) || !all(required %in% names(bars))) hreg41_stop("Daily-bar schema is incomplete or empty.")
  x <- bars
  x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg41_stop("Dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg41_stop("Confirmation rows entered the diagnostic.")
  numeric_cols <- c("open", "high", "low", "close", "volume")
  if (any(!is.finite(as.matrix(x[numeric_cols]))) || any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) hreg41_stop("OHLCV values are invalid.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg41_asset_component <- function(bars, symbol, contract = hreg41_contract()) {
  x <- bars[bars$symbol == symbol, c("session_date", "close"), drop = FALSE]
  x <- x[order(x$session_date), , drop = FALSE]
  log_close <- log(x$close)
  daily_return <- c(NA_real_, diff(log_close))
  prior_volatility <- hreg41_lag(hreg41_roll_sd(daily_return, contract$volatility_lookback), 1L)
  return20 <- log_close - hreg41_lag(log_close, contract$trend_fast)
  return60 <- log_close - hreg41_lag(log_close, contract$trend_slow)
  z20 <- return20 / (prior_volatility * sqrt(contract$trend_fast))
  z60 <- return60 / (prior_volatility * sqrt(contract$trend_slow))
  score <- (z20 + z60) / 2
  improvement <- score - hreg41_lag(score, contract$flow_lookback)
  future_return <- hreg41_lead(log_close, contract$horizon) - log_close
  prefix <- paste0("_", symbol)
  out <- data.frame(session_date = x$session_date, score, z20, z60, improvement, future_return, stringsAsFactors = FALSE)
  names(out)[-1L] <- paste0(c("score", "z20", "z60", "improvement", "future_return"), prefix)
  out
}

hreg41_build_ledger <- function(bars, signal_symbols, signal_groups, contract = hreg41_contract()) {
  x <- hreg41_validate_bars(bars, contract)
  if (length(signal_symbols) != contract$signal_assets || !all(c(signal_symbols, "SPY") %in% unique(x$symbol))) hreg41_stop("Signal universe does not match the frozen registry.")
  if (length(signal_groups) != length(signal_symbols) || length(unique(signal_groups)) != contract$signal_groups) hreg41_stop("Economic-group mapping does not match the frozen registry.")
  names(signal_groups) <- signal_symbols
  parts <- lapply(signal_symbols, function(symbol) hreg41_asset_component(x, symbol, contract))
  ledger <- Reduce(function(a, b) merge(a, b, by = "session_date", all = FALSE, sort = TRUE), parts)
  spy <- x[x$symbol == "SPY", c("session_date", "open", "close"), drop = FALSE]
  names(spy)[2:3] <- c("spy_open", "spy_close")
  ledger <- merge(ledger, spy, by = "session_date", all = FALSE, sort = TRUE)

  score_cols <- paste0("score_", signal_symbols)
  z20_cols <- paste0("z20_", signal_symbols)
  z60_cols <- paste0("z60_", signal_symbols)
  improvement_cols <- paste0("improvement_", signal_symbols)
  future_cols <- paste0("future_return_", signal_symbols)
  score <- as.matrix(ledger[score_cols])
  z20 <- as.matrix(ledger[z20_cols])
  z60 <- as.matrix(ledger[z60_cols])
  improvement <- as.matrix(ledger[improvement_cols])
  future_return <- as.matrix(ledger[future_cols])

  complete <- function(v) all(is.finite(v))
  group_names <- unique(signal_groups)
  grouped <- function(matrix, within, across) {
    vapply(seq_len(nrow(matrix)), function(i) {
      if (!complete(matrix[i, ])) return(NA_real_)
      group_values <- vapply(group_names, function(group) within(matrix[i, signal_groups == group]), numeric(1L))
      across(group_values)
    }, numeric(1L))
  }
  ledger$field_inputs <- rowSums(is.finite(score))
  ledger$direction_score <- grouped(score, stats::median, stats::median)
  ledger$participation <- grouped(score, function(v) mean(v > 0), mean)
  agreement_matrix <- (sign(z20) == sign(z60)) * 1
  ledger$agreement <- grouped(agreement_matrix, mean, mean)
  ledger$flow <- grouped(improvement, function(v) mean(v > 0) - mean(v < 0), mean)
  ledger$future_field_return_h20 <- grouped(future_return, stats::median, stats::median)
  ledger$future_field_participation_h20 <- grouped(future_return, function(v) mean(v > 0), mean)
  ledger$future_participation_change_h5 <- hreg41_lead(ledger$participation, contract$flow_lookback) - ledger$participation
  ledger$directional_persistence_h20 <- sign(ledger$direction_score) * ledger$future_field_return_h20
  ledger$spy_return_h20 <- hreg41_forward_open_return(ledger$spy_open, contract$horizon)
  ledger$spy_up_h20 <- ifelse(is.finite(ledger$spy_return_h20), ledger$spy_return_h20 > 0, NA)

  ledger$state <- NA_character_
  positive <- is.finite(ledger$direction_score) & ledger$direction_score >= 0
  negative <- is.finite(ledger$direction_score) & ledger$direction_score < 0
  broad_up <- positive & ledger$participation >= contract$broad_participation & ledger$agreement >= contract$minimum_agreement & ledger$flow >= 0
  broad_down <- negative & ledger$participation <= contract$broad_down_participation & ledger$agreement >= contract$minimum_agreement & ledger$flow < 0
  ledger$state[positive] <- "FRAGILE_UP"
  ledger$state[negative] <- "FRAGILE_DOWN"
  ledger$state[broad_up] <- "BROAD_UP"
  ledger$state[broad_down] <- "BROAD_DOWN"
  ledger$analysis_index <- seq_len(nrow(ledger))
  ledger$offset <- (ledger$analysis_index - 1L) %% contract$horizon
  ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
}

hreg41_auc <- function(score, outcome) {
  keep <- is.finite(score) & !is.na(outcome)
  score <- score[keep]
  outcome <- as.logical(outcome[keep])
  positives <- sum(outcome)
  negatives <- sum(!outcome)
  if (!positives || !negatives) return(NA_real_)
  ranks <- rank(score, ties.method = "average")
  (sum(ranks[outcome]) - positives * (positives + 1) / 2) / (positives * negatives)
}

hreg41_state_summary <- function(ledger) {
  do.call(rbind, lapply(split(ledger, ledger$state), function(x) data.frame(
    state = x$state[[1L]],
    observations = sum(is.finite(x$future_field_return_h20)),
    median_future_field_return = stats::median(x$future_field_return_h20, na.rm = TRUE),
    median_future_participation = stats::median(x$future_field_participation_h20, na.rm = TRUE),
    future_negative_rate = mean(x$future_field_return_h20 < 0, na.rm = TRUE),
    median_spy_return = stats::median(x$spy_return_h20, na.rm = TRUE),
    spy_up_rate = mean(x$spy_up_h20, na.rm = TRUE),
    stringsAsFactors = FALSE
  )))
}

hreg41_contrast <- function(ledger, state_a, state_b, minimum_rows = 1L) {
  a <- ledger[ledger$state == state_a & is.finite(ledger$future_field_return_h20), , drop = FALSE]
  b <- ledger[ledger$state == state_b & is.finite(ledger$future_field_return_h20), , drop = FALSE]
  valid <- nrow(a) >= minimum_rows && nrow(b) >= minimum_rows
  gap <- function(column, fun = stats::median) if (valid) fun(a[[column]], na.rm = TRUE) - fun(b[[column]], na.rm = TRUE) else NA_real_
  data.frame(
    state_a = state_a, state_b = state_b, state_a_n = nrow(a), state_b_n = nrow(b), valid = valid,
    field_return_gap = gap("future_field_return_h20"),
    field_participation_gap = gap("future_field_participation_h20"),
    future_negative_rate_gap = if (valid) mean(a$future_field_return_h20 < 0) - mean(b$future_field_return_h20 < 0) else NA_real_,
    spy_return_gap = gap("spy_return_h20"),
    spy_up_rate_gap = if (valid) mean(a$spy_up_h20, na.rm = TRUE) - mean(b$spy_up_h20, na.rm = TRUE) else NA_real_,
    stringsAsFactors = FALSE
  )
}

hreg41_continuous_summary <- function(ledger) {
  definitions <- list(
    c("direction_score", "future_field_return_h20"),
    c("participation", "future_field_return_h20"),
    c("flow", "future_participation_change_h5"),
    c("agreement", "directional_persistence_h20"),
    c("direction_score", "spy_return_h20")
  )
  out <- do.call(rbind, lapply(definitions, function(definition) {
    feature <- definition[[1L]]
    target <- definition[[2L]]
    keep <- is.finite(ledger[[feature]]) & is.finite(ledger[[target]])
    data.frame(feature = feature, target = target, observations = sum(keep),
      spearman = if (sum(keep) >= 5L) suppressWarnings(stats::cor(ledger[[feature]][keep], ledger[[target]][keep], method = "spearman")) else NA_real_,
      stringsAsFactors = FALSE)
  }))
  rbind(out, data.frame(feature = "direction_score", target = "spy_up_h20_auc", observations = sum(is.finite(ledger$direction_score) & !is.na(ledger$spy_up_h20)), spearman = hreg41_auc(ledger$direction_score, ledger$spy_up_h20), stringsAsFactors = FALSE))
}

hreg41_offset_summary <- function(ledger, contract = hreg41_contract()) {
  do.call(rbind, lapply(0:(contract$horizon - 1L), function(offset) {
    out <- hreg41_contrast(ledger[ledger$offset == offset, , drop = FALSE], "BROAD_UP", "BROAD_DOWN", contract$minimum_offset_rows)
    cbind(data.frame(offset = offset, stringsAsFactors = FALSE), out)
  }))
}

hreg41_period_summary <- function(ledger) {
  periods <- list(`2018-2020` = ledger$session_date < as.Date("2021-01-01"), `2021-2023` = ledger$session_date >= as.Date("2021-01-01"))
  do.call(rbind, lapply(names(periods), function(period) {
    x <- ledger[periods[[period]], , drop = FALSE]
    rbind(
      cbind(data.frame(period = period, contrast = "DIRECTION", stringsAsFactors = FALSE), hreg41_contrast(x, "BROAD_UP", "BROAD_DOWN")),
      cbind(data.frame(period = period, contrast = "POSITIVE_HEALTH", stringsAsFactors = FALSE), hreg41_contrast(x, "BROAD_UP", "FRAGILE_UP"))
    )
  }))
}

hreg41_calendar_summary <- function(ledger) {
  do.call(rbind, lapply(2018:2023, function(year) {
    x <- ledger[as.integer(format(ledger$session_date, "%Y")) == year, , drop = FALSE]
    rbind(
      cbind(data.frame(year = year, contrast = "DIRECTION", stringsAsFactors = FALSE), hreg41_contrast(x, "BROAD_UP", "BROAD_DOWN")),
      cbind(data.frame(year = year, contrast = "POSITIVE_HEALTH", stringsAsFactors = FALSE), hreg41_contrast(x, "BROAD_UP", "FRAGILE_UP"))
    )
  }))
}

hreg41_rotate <- function(x, shift) {
  if (!length(x)) return(x)
  shift <- as.integer(shift %% length(x))
  if (shift == 0L) return(x)
  c(tail(x, shift), head(x, length(x) - shift))
}

hreg41_shift_states <- function(ledger, simulation_id) {
  states <- ledger$state
  groups <- split(seq_len(nrow(ledger)), format(ledger$session_date, "%Y"))
  group_id <- 0L
  for (idx in groups) {
    group_id <- group_id + 1L
    if (length(idx) < 3L) next
    shift <- 1L + ((as.integer(simulation_id) * 37L + group_id * 17L) %% (length(idx) - 1L))
    states[idx] <- hreg41_rotate(states[idx], shift)
  }
  states
}

hreg41_circular_controls <- function(ledger, contract = hreg41_contract()) {
  do.call(rbind, lapply(seq_len(contract$simulations), function(simulation_id) {
    x <- ledger
    x$state <- hreg41_shift_states(ledger, simulation_id)
    direction <- hreg41_contrast(x, "BROAD_UP", "BROAD_DOWN")
    health <- hreg41_contrast(x, "BROAD_UP", "FRAGILE_UP")
    data.frame(
      simulation_id = simulation_id,
      direction_field_return_gap = direction$field_return_gap,
      direction_participation_gap = direction$field_participation_gap,
      health_field_return_gap = health$field_return_gap,
      health_participation_gap = health$field_participation_gap,
      stringsAsFactors = FALSE
    )
  }))
}
