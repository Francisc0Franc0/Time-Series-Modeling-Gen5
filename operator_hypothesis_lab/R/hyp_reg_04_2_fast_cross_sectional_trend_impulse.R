hreg42_stop <- function(message) stop(paste0("[HYP-REG-04.2] ", message), call. = FALSE)

hreg42_contract <- function() {
  list(
    hypothesis_id = "HYP-REG-04.2",
    as_of_timestamp = "2026-08-14 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    fast_horizon = 5L,
    context_horizon = 20L,
    volatility_lookback = 63L,
    impulse_lookback = 5L,
    durability_horizon = 10L,
    decay_horizon = 20L,
    signal_assets = 24L,
    signal_groups = 4L,
    registry_assets = 25L,
    broad_participation = 0.60,
    broad_down_participation = 0.40,
    minimum_state_rows = 75L,
    minimum_offset_rows = 10L,
    simulations = 200L
  )
}

hreg42_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg42_stop("Lag must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA_real_, length(x)))
  c(rep(NA_real_, n), head(x, -n))
}

hreg42_lead <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg42_stop("Lead must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA_real_, length(x)))
  c(tail(x, -n), rep(NA_real_, n))
}

hreg42_roll_sd <- function(x, n) {
  n <- as.integer(n)
  if (n < 2L) hreg42_stop("Rolling standard-deviation length must be at least two.")
  out <- rep(NA_real_, length(x))
  if (length(x) < n) return(out)
  for (i in seq.int(n, length(x))) {
    window <- x[seq.int(i - n + 1L, i)]
    if (all(is.finite(window))) out[[i]] <- stats::sd(window)
  }
  out
}

hreg42_forward_open_return <- function(open, horizon) {
  horizon <- as.integer(horizon)
  if (horizon < 1L) hreg42_stop("Forward-open horizon must be positive.")
  out <- rep(NA_real_, length(open))
  if (length(open) <= horizon + 1L) return(out)
  idx <- seq_len(length(open) - horizon - 1L)
  out[idx] <- log(open[idx + horizon + 1L] / open[idx + 1L])
  out
}

hreg42_validate_bars <- function(bars, contract = hreg42_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  if (!is.data.frame(bars) || !nrow(bars) || !all(required %in% names(bars))) hreg42_stop("Daily-bar schema is incomplete or empty.")
  x <- bars
  x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg42_stop("Dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg42_stop("Confirmation rows entered the diagnostic.")
  numeric_cols <- c("open", "high", "low", "close", "volume")
  if (any(!is.finite(as.matrix(x[numeric_cols]))) || any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) hreg42_stop("OHLCV values are invalid.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg42_asset_component <- function(bars, symbol, contract = hreg42_contract()) {
  x <- bars[bars$symbol == symbol, c("session_date", "close"), drop = FALSE]
  x <- x[order(x$session_date), , drop = FALSE]
  log_close <- log(x$close)
  daily_return <- c(NA_real_, diff(log_close))
  prior_volatility <- hreg42_lag(hreg42_roll_sd(daily_return, contract$volatility_lookback), 1L)
  return5 <- log_close - hreg42_lag(log_close, contract$fast_horizon)
  return20 <- log_close - hreg42_lag(log_close, contract$context_horizon)
  z5 <- return5 / (prior_volatility * sqrt(contract$fast_horizon))
  z20 <- return20 / (prior_volatility * sqrt(contract$context_horizon))
  future_return_h5 <- hreg42_lead(log_close, contract$fast_horizon) - log_close
  future_return_h10 <- hreg42_lead(log_close, contract$durability_horizon) - log_close
  future_return_h20 <- hreg42_lead(log_close, contract$decay_horizon) - log_close
  prefix <- paste0("_", symbol)
  out <- data.frame(session_date = x$session_date, z5, z20, future_return_h5, future_return_h10, future_return_h20, stringsAsFactors = FALSE)
  names(out)[-1L] <- paste0(c("z5", "z20", "future_return_h5", "future_return_h10", "future_return_h20"), prefix)
  out
}

hreg42_classify_state <- function(direction5, participation5, participation_impulse, contract = hreg42_contract()) {
  state <- rep(NA_character_, length(direction5))
  positive <- is.finite(direction5) & direction5 >= 0
  negative <- is.finite(direction5) & direction5 < 0
  state[positive] <- "OTHER_UP"
  state[negative] <- "OTHER_DOWN"
  broad_up <- positive & is.finite(participation5) & participation5 >= contract$broad_participation & is.finite(participation_impulse) & participation_impulse > 0
  broad_down <- negative & is.finite(participation5) & participation5 <= contract$broad_down_participation & is.finite(participation_impulse) & participation_impulse < 0
  state[broad_up] <- "BROAD_UP_IMPULSE"
  state[broad_down] <- "BROAD_DOWN_IMPULSE"
  state
}

hreg42_classify_context <- function(direction5, direction20) {
  out <- rep(NA_character_, length(direction5))
  valid <- is.finite(direction5) & is.finite(direction20)
  out[valid & direction5 >= 0 & direction20 >= 0] <- "UP_CONTINUATION"
  out[valid & direction5 >= 0 & direction20 < 0] <- "UP_REVERSAL"
  out[valid & direction5 < 0 & direction20 < 0] <- "DOWN_CONTINUATION"
  out[valid & direction5 < 0 & direction20 >= 0] <- "DOWN_REVERSAL"
  out
}

hreg42_build_ledger <- function(bars, signal_symbols, signal_groups, contract = hreg42_contract()) {
  x <- hreg42_validate_bars(bars, contract)
  if (length(signal_symbols) != contract$signal_assets || !all(c(signal_symbols, "SPY") %in% unique(x$symbol))) hreg42_stop("Signal universe does not match the frozen registry.")
  if (length(signal_groups) != length(signal_symbols) || length(unique(signal_groups)) != contract$signal_groups) hreg42_stop("Economic-group mapping does not match the frozen registry.")
  names(signal_groups) <- signal_symbols
  parts <- lapply(signal_symbols, function(symbol) hreg42_asset_component(x, symbol, contract))
  ledger <- Reduce(function(a, b) merge(a, b, by = "session_date", all = FALSE, sort = TRUE), parts)
  spy <- x[x$symbol == "SPY", c("session_date", "open", "close"), drop = FALSE]
  names(spy)[2:3] <- c("spy_open", "spy_close")
  ledger <- merge(ledger, spy, by = "session_date", all = FALSE, sort = TRUE)

  z5 <- as.matrix(ledger[paste0("z5_", signal_symbols)])
  z20 <- as.matrix(ledger[paste0("z20_", signal_symbols)])
  future5 <- as.matrix(ledger[paste0("future_return_h5_", signal_symbols)])
  future10 <- as.matrix(ledger[paste0("future_return_h10_", signal_symbols)])
  future20 <- as.matrix(ledger[paste0("future_return_h20_", signal_symbols)])
  group_names <- unique(signal_groups)
  grouped <- function(matrix, within, across) {
    vapply(seq_len(nrow(matrix)), function(i) {
      if (!all(is.finite(matrix[i, ]))) return(NA_real_)
      group_values <- vapply(group_names, function(group) within(matrix[i, signal_groups == group]), numeric(1L))
      across(group_values)
    }, numeric(1L))
  }

  ledger$field_inputs <- rowSums(is.finite(z5) & is.finite(z20))
  ledger$direction5 <- grouped(z5, stats::median, stats::median)
  ledger$participation5 <- grouped(z5, function(v) mean(v > 0), mean)
  ledger$participation_impulse <- ledger$participation5 - hreg42_lag(ledger$participation5, contract$impulse_lookback)
  ledger$direction20 <- grouped(z20, stats::median, stats::median)
  ledger$alignment <- ifelse(is.finite(ledger$direction5) & is.finite(ledger$direction20), as.numeric(sign(ledger$direction5) == sign(ledger$direction20)), NA_real_)

  for (horizon in c(5L, 10L, 20L)) {
    matrix <- switch(as.character(horizon), `5` = future5, `10` = future10, `20` = future20)
    ledger[[paste0("future_field_return_h", horizon)]] <- grouped(matrix, stats::median, stats::median)
    ledger[[paste0("future_field_participation_h", horizon)]] <- grouped(matrix, function(v) mean(v > 0), mean)
    ledger[[paste0("directional_persistence_h", horizon)]] <- sign(ledger$direction5) * ledger[[paste0("future_field_return_h", horizon)]]
  }
  ledger$future_participation_change_h5 <- hreg42_lead(ledger$participation5, contract$fast_horizon) - ledger$participation5
  ledger$spy_return_h5 <- hreg42_forward_open_return(ledger$spy_open, contract$fast_horizon)
  ledger$spy_return_h10 <- hreg42_forward_open_return(ledger$spy_open, contract$durability_horizon)
  ledger$spy_up_h5 <- ifelse(is.finite(ledger$spy_return_h5), ledger$spy_return_h5 > 0, NA)
  ledger$state <- hreg42_classify_state(ledger$direction5, ledger$participation5, ledger$participation_impulse, contract)
  ledger$context <- hreg42_classify_context(ledger$direction5, ledger$direction20)
  ledger$analysis_index <- seq_len(nrow(ledger))
  ledger$offset_h5 <- (ledger$analysis_index - 1L) %% contract$fast_horizon
  ledger$offset_h10 <- (ledger$analysis_index - 1L) %% contract$durability_horizon
  ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
}

hreg42_auc <- function(score, outcome) {
  keep <- is.finite(score) & !is.na(outcome)
  score <- score[keep]
  outcome <- as.logical(outcome[keep])
  positives <- sum(outcome)
  negatives <- sum(!outcome)
  if (!positives || !negatives) return(NA_real_)
  ranks <- rank(score, ties.method = "average")
  (sum(ranks[outcome]) - positives * (positives + 1) / 2) / (positives * negatives)
}

hreg42_state_summary <- function(ledger, horizon = 5L) {
  return_col <- paste0("future_field_return_h", horizon)
  participation_col <- paste0("future_field_participation_h", horizon)
  spy_col <- paste0("spy_return_h", horizon)
  do.call(rbind, lapply(split(ledger, ledger$state), function(x) data.frame(
    horizon = horizon,
    state = x$state[[1L]],
    observations = sum(is.finite(x[[return_col]])),
    median_future_field_return = stats::median(x[[return_col]], na.rm = TRUE),
    median_future_participation = stats::median(x[[participation_col]], na.rm = TRUE),
    future_negative_rate = mean(x[[return_col]] < 0, na.rm = TRUE),
    median_spy_return = if (spy_col %in% names(x)) stats::median(x[[spy_col]], na.rm = TRUE) else NA_real_,
    stringsAsFactors = FALSE
  )))
}

hreg42_context_summary <- function(ledger) {
  do.call(rbind, lapply(split(ledger, ledger$context), function(x) data.frame(
    context = x$context[[1L]],
    observations = sum(is.finite(x$future_field_return_h5)),
    median_future_field_return_h5 = stats::median(x$future_field_return_h5, na.rm = TRUE),
    median_future_participation_h5 = stats::median(x$future_field_participation_h5, na.rm = TRUE),
    median_directional_persistence_h5 = stats::median(x$directional_persistence_h5, na.rm = TRUE),
    median_future_field_return_h10 = stats::median(x$future_field_return_h10, na.rm = TRUE),
    stringsAsFactors = FALSE
  )))
}

hreg42_contrast <- function(ledger, state_a, state_b, horizon = 5L, minimum_rows = 1L) {
  return_col <- paste0("future_field_return_h", horizon)
  participation_col <- paste0("future_field_participation_h", horizon)
  spy_col <- paste0("spy_return_h", horizon)
  a <- ledger[ledger$state == state_a & is.finite(ledger[[return_col]]), , drop = FALSE]
  b <- ledger[ledger$state == state_b & is.finite(ledger[[return_col]]), , drop = FALSE]
  valid <- nrow(a) >= minimum_rows && nrow(b) >= minimum_rows
  gap <- function(column, fun = stats::median) if (valid && column %in% names(a)) fun(a[[column]], na.rm = TRUE) - fun(b[[column]], na.rm = TRUE) else NA_real_
  data.frame(
    horizon = horizon, state_a = state_a, state_b = state_b, state_a_n = nrow(a), state_b_n = nrow(b), valid = valid,
    field_return_gap = gap(return_col),
    field_participation_gap = gap(participation_col),
    future_negative_rate_gap = if (valid) mean(a[[return_col]] < 0) - mean(b[[return_col]] < 0) else NA_real_,
    spy_return_gap = gap(spy_col),
    stringsAsFactors = FALSE
  )
}

hreg42_continuous_summary <- function(ledger) {
  definitions <- list(
    c("direction5", "future_field_return_h5"),
    c("participation5", "future_field_return_h5"),
    c("participation_impulse", "future_participation_change_h5"),
    c("alignment", "directional_persistence_h5"),
    c("direction5", "future_field_return_h10"),
    c("direction5", "future_field_return_h20"),
    c("direction5", "spy_return_h5"),
    c("direction5", "spy_return_h10")
  )
  out <- do.call(rbind, lapply(definitions, function(definition) {
    feature <- definition[[1L]]
    target <- definition[[2L]]
    keep <- is.finite(ledger[[feature]]) & is.finite(ledger[[target]])
    data.frame(
      feature = feature,
      target = target,
      observations = sum(keep),
      spearman = if (sum(keep) >= 5L) suppressWarnings(stats::cor(ledger[[feature]][keep], ledger[[target]][keep], method = "spearman")) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  rbind(out, data.frame(
    feature = "direction5",
    target = "spy_up_h5_auc",
    observations = sum(is.finite(ledger$direction5) & !is.na(ledger$spy_up_h5)),
    spearman = hreg42_auc(ledger$direction5, ledger$spy_up_h5),
    stringsAsFactors = FALSE
  ))
}

hreg42_offset_summary <- function(ledger, horizon, contract = hreg42_contract()) {
  horizon <- as.integer(horizon)
  offset_col <- paste0("offset_h", horizon)
  if (!offset_col %in% names(ledger)) hreg42_stop("Requested offset horizon is not available.")
  do.call(rbind, lapply(0:(horizon - 1L), function(offset) {
    out <- hreg42_contrast(
      ledger[ledger[[offset_col]] == offset, , drop = FALSE],
      "BROAD_UP_IMPULSE", "BROAD_DOWN_IMPULSE", horizon,
      contract$minimum_offset_rows
    )
    cbind(data.frame(offset = offset, stringsAsFactors = FALSE), out)
  }))
}

hreg42_period_summary <- function(ledger) {
  periods <- list(`2018-2020` = ledger$session_date < as.Date("2021-01-01"), `2021-2023` = ledger$session_date >= as.Date("2021-01-01"))
  do.call(rbind, lapply(names(periods), function(period) {
    x <- ledger[periods[[period]], , drop = FALSE]
    rbind(
      cbind(data.frame(period = period, contrast = "DIRECTION", stringsAsFactors = FALSE), hreg42_contrast(x, "BROAD_UP_IMPULSE", "BROAD_DOWN_IMPULSE", 5L)),
      cbind(data.frame(period = period, contrast = "POSITIVE_IMPULSE", stringsAsFactors = FALSE), hreg42_contrast(x, "BROAD_UP_IMPULSE", "OTHER_UP", 5L))
    )
  }))
}

hreg42_calendar_summary <- function(ledger) {
  do.call(rbind, lapply(2018:2023, function(year) {
    x <- ledger[as.integer(format(ledger$session_date, "%Y")) == year, , drop = FALSE]
    rbind(
      cbind(data.frame(year = year, contrast = "DIRECTION", stringsAsFactors = FALSE), hreg42_contrast(x, "BROAD_UP_IMPULSE", "BROAD_DOWN_IMPULSE", 5L)),
      cbind(data.frame(year = year, contrast = "POSITIVE_IMPULSE", stringsAsFactors = FALSE), hreg42_contrast(x, "BROAD_UP_IMPULSE", "OTHER_UP", 5L))
    )
  }))
}

hreg42_rotate <- function(x, shift) {
  if (!length(x)) return(x)
  shift <- as.integer(shift %% length(x))
  if (shift == 0L) return(x)
  c(tail(x, shift), head(x, length(x) - shift))
}

hreg42_shift_states <- function(ledger, simulation_id) {
  states <- ledger$state
  groups <- split(seq_len(nrow(ledger)), format(ledger$session_date, "%Y"))
  group_id <- 0L
  for (idx in groups) {
    group_id <- group_id + 1L
    if (length(idx) < 3L) next
    shift <- 1L + ((as.integer(simulation_id) * 37L + group_id * 17L) %% (length(idx) - 1L))
    states[idx] <- hreg42_rotate(states[idx], shift)
  }
  states
}

hreg42_circular_controls <- function(ledger, contract = hreg42_contract()) {
  do.call(rbind, lapply(seq_len(contract$simulations), function(simulation_id) {
    x <- ledger
    x$state <- hreg42_shift_states(ledger, simulation_id)
    direction <- hreg42_contrast(x, "BROAD_UP_IMPULSE", "BROAD_DOWN_IMPULSE", 5L)
    health <- hreg42_contrast(x, "BROAD_UP_IMPULSE", "OTHER_UP", 5L)
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
