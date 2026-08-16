hreg51_stop <- function(message) stop(paste0("[HYP-REG-05.1] ", message), call. = FALSE)

hreg51_contract <- function() {
  list(
    hypothesis_id = "HYP-REG-05.1",
    as_of_timestamp = "2026-08-14 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    er_length = 20L,
    adx_length = 14L,
    adx_change_length = 5L,
    percentile_lookback = 252L,
    low_enter = 0.30,
    low_exit = 0.40,
    high_exit = 0.60,
    high_enter = 0.70,
    horizons = c(5L, 10L, 20L),
    primary_horizon = 10L,
    durability_horizon = 20L,
    registry_assets = 26L,
    simulations = 200L,
    simulation_seed = 5101L
  )
}

hreg51_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg51_stop("Lag must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA, length(x)))
  c(rep(NA, n), head(x, -n))
}

hreg51_assert_bars <- function(bars, contract = hreg51_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  if (!is.data.frame(bars) || !nrow(bars) || !all(required %in% names(bars))) {
    hreg51_stop("Daily-bar schema is incomplete or empty.")
  }
  x <- bars
  x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) {
    hreg51_stop("Dates are invalid or duplicated.")
  }
  if (any(x$session_date >= contract$confirmation_start)) hreg51_stop("Confirmation rows entered the diagnostic.")
  numeric_cols <- c("open", "high", "low", "close", "volume")
  if (any(!is.finite(as.matrix(x[numeric_cols]))) ||
      any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) {
    hreg51_stop("OHLCV values are invalid.")
  }
  if (any(x$high < pmax(x$open, x$close, x$low)) || any(x$low > pmin(x$open, x$close, x$high))) {
    hreg51_stop("OHLC price ordering is invalid.")
  }
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg51_efficiency_ratio <- function(close, length = 20L) {
  length <- as.integer(length)
  if (length < 2L) hreg51_stop("Efficiency-ratio length must be at least two.")
  if (!is.numeric(close) || any(close <= 0, na.rm = TRUE)) hreg51_stop("Close must be positive numeric values.")
  log_close <- log(close)
  steps <- c(NA_real_, abs(diff(log_close)))
  out <- rep(NA_real_, length(close))
  if (length(close) <= length) return(out)
  for (i in seq.int(length + 1L, length(close))) {
    path <- steps[seq.int(i - length + 1L, i)]
    denominator <- sum(path)
    if (all(is.finite(path)) && denominator > 0) {
      out[[i]] <- abs(log_close[[i]] - log_close[[i - length]]) / denominator
    }
  }
  pmin(1, pmax(0, out))
}

hreg51_true_range <- function(high, low, close) {
  previous_close <- hreg51_lag(close)
  out <- pmax(high - low, abs(high - previous_close), abs(low - previous_close), na.rm = TRUE)
  out[!is.finite(previous_close)] <- NA_real_
  out
}

hreg51_directional_movement <- function(high, low) {
  up <- high - hreg51_lag(high)
  down <- hreg51_lag(low) - low
  plus <- ifelse(is.finite(up) & up > down & up > 0, up, 0)
  minus <- ifelse(is.finite(down) & down > up & down > 0, down, 0)
  plus[!is.finite(up) | !is.finite(down)] <- NA_real_
  minus[!is.finite(up) | !is.finite(down)] <- NA_real_
  list(plus = plus, minus = minus)
}

hreg51_wilder_sum <- function(x, length) {
  length <- as.integer(length)
  out <- rep(NA_real_, length(x))
  finite <- which(is.finite(x))
  if (length(finite) < length) return(out)
  initial_position <- finite[[length]]
  if (!all(diff(finite[seq_len(length)]) == 1L)) hreg51_stop("Wilder initialization requires consecutive values.")
  out[[initial_position]] <- sum(x[finite[seq_len(length)]])
  if (initial_position < length(x)) {
    for (i in seq.int(initial_position + 1L, length(x))) {
      if (is.finite(x[[i]]) && is.finite(out[[i - 1L]])) out[[i]] <- out[[i - 1L]] - out[[i - 1L]] / length + x[[i]]
    }
  }
  out
}

hreg51_wilder_average <- function(x, length) {
  length <- as.integer(length)
  out <- rep(NA_real_, length(x))
  finite <- which(is.finite(x))
  if (length(finite) < length) return(out)
  initial_position <- finite[[length]]
  if (!all(diff(finite[seq_len(length)]) == 1L)) hreg51_stop("Wilder initialization requires consecutive values.")
  out[[initial_position]] <- mean(x[finite[seq_len(length)]])
  if (initial_position < length(x)) {
    for (i in seq.int(initial_position + 1L, length(x))) {
      if (is.finite(x[[i]]) && is.finite(out[[i - 1L]])) out[[i]] <- ((length - 1) * out[[i - 1L]] + x[[i]]) / length
    }
  }
  out
}

hreg51_adx <- function(high, low, close, length = 14L) {
  length <- as.integer(length)
  if (length < 2L) hreg51_stop("ADX length must be at least two.")
  tr <- hreg51_true_range(high, low, close)
  dm <- hreg51_directional_movement(high, low)
  tr_sum <- hreg51_wilder_sum(tr, length)
  plus_sum <- hreg51_wilder_sum(dm$plus, length)
  minus_sum <- hreg51_wilder_sum(dm$minus, length)
  plus_di <- ifelse(is.finite(tr_sum) & tr_sum > 0, 100 * plus_sum / tr_sum, NA_real_)
  minus_di <- ifelse(is.finite(tr_sum) & tr_sum > 0, 100 * minus_sum / tr_sum, NA_real_)
  denominator <- plus_di + minus_di
  dx <- ifelse(is.finite(denominator) & denominator > 0, 100 * abs(plus_di - minus_di) / denominator, NA_real_)
  adx <- hreg51_wilder_average(dx, length)
  direction <- sign(plus_di - minus_di)
  direction[!is.finite(plus_di) | !is.finite(minus_di)] <- NA_real_
  list(adx = adx, plus_di = plus_di, minus_di = minus_di, dx = dx, direction = direction, true_range = tr)
}

hreg51_rolling_percentile <- function(x, lookback = 252L) {
  lookback <- as.integer(lookback)
  if (lookback < 2L) hreg51_stop("Percentile lookback must be at least two.")
  out <- rep(NA_real_, length(x))
  if (length(x) <= lookback) return(out)
  for (i in seq.int(lookback + 1L, length(x))) {
    history <- x[seq.int(i - lookback, i - 1L)]
    if (is.finite(x[[i]]) && all(is.finite(history))) {
      out[[i]] <- (sum(history < x[[i]]) + 0.5 * sum(history == x[[i]])) / lookback
    }
  }
  out
}

hreg51_hysteretic_state <- function(score, low_enter = .30, low_exit = .40,
                                     high_exit = .60, high_enter = .70) {
  out <- rep(NA_character_, length(score))
  current <- NA_character_
  for (i in seq_along(score)) {
    value <- score[[i]]
    if (!is.finite(value)) next
    if (is.na(current)) {
      current <- if (value < low_enter) "LOW" else if (value > high_enter) "HIGH" else "MEDIUM"
    } else if (identical(current, "LOW")) {
      if (value > high_enter) current <- "HIGH" else if (value > low_exit) current <- "MEDIUM"
    } else if (identical(current, "HIGH")) {
      if (value < low_enter) current <- "LOW" else if (value < high_exit) current <- "MEDIUM"
    } else {
      if (value < low_enter) current <- "LOW" else if (value > high_enter) current <- "HIGH"
    }
    out[[i]] <- current
  }
  out
}

hreg51_future_path_metrics <- function(open, close, horizon) {
  horizon <- as.integer(horizon)
  if (horizon < 2L) hreg51_stop("Future path horizon must be at least two.")
  n <- length(close)
  efficiency <- net_move <- turn_rate <- rep(NA_real_, n)
  if (n <= horizon) return(data.frame(efficiency, net_move, turn_rate))
  for (i in seq_len(n - horizon)) {
    future_close <- close[seq.int(i + 1L, i + horizon)]
    anchor <- open[[i + 1L]]
    steps <- c(log(future_close[[1L]] / anchor), diff(log(future_close)))
    denominator <- sum(abs(steps))
    net <- log(future_close[[horizon]] / anchor)
    if (all(is.finite(steps)) && denominator > 0) {
      efficiency[[i]] <- min(1, abs(net) / denominator)
      net_move[[i]] <- net
      signs <- sign(steps)
      turn_rate[[i]] <- if (length(signs) > 1L) sum(signs[-1L] != head(signs, -1L)) / (length(signs) - 1L) else 0
    }
  }
  data.frame(efficiency, net_move, turn_rate)
}

hreg51_build_asset_ledger <- function(bars, contract = hreg51_contract()) {
  bars <- hreg51_assert_bars(bars, contract)
  if (length(unique(bars$symbol)) != 1L) hreg51_stop("Asset ledger requires exactly one symbol.")
  x <- bars[order(bars$session_date), , drop = FALSE]
  er <- hreg51_efficiency_ratio(x$close, contract$er_length)
  er_direction <- sign(log(x$close) - hreg51_lag(log(x$close), contract$er_length))
  adx_object <- hreg51_adx(x$high, x$low, x$close, contract$adx_length)
  er_percentile <- hreg51_rolling_percentile(er, contract$percentile_lookback)
  adx_percentile <- hreg51_rolling_percentile(adx_object$adx, contract$percentile_lookback)
  out <- data.frame(
    symbol = x$symbol,
    session_date = x$session_date,
    open = x$open,
    high = x$high,
    low = x$low,
    close = x$close,
    er20 = er,
    er_percentile = er_percentile,
    er_state = hreg51_hysteretic_state(er_percentile, contract$low_enter, contract$low_exit, contract$high_exit, contract$high_enter),
    er_direction = er_direction,
    adx14 = adx_object$adx,
    plus_di14 = adx_object$plus_di,
    minus_di14 = adx_object$minus_di,
    adx_percentile = adx_percentile,
    adx_state = hreg51_hysteretic_state(adx_percentile, contract$low_enter, contract$low_exit, contract$high_exit, contract$high_enter),
    adx_direction = adx_object$direction,
    adx_change5 = adx_object$adx - hreg51_lag(adx_object$adx, contract$adx_change_length),
    stringsAsFactors = FALSE
  )
  analysis_rows <- out$session_date >= contract$analysis_start & out$session_date <= contract$analysis_end
  out$analysis_index <- NA_integer_
  out$analysis_index[analysis_rows] <- seq_len(sum(analysis_rows))
  for (h in contract$horizons) {
    path <- hreg51_future_path_metrics(x$open, x$close, h)
    out[[paste0("future_efficiency_h", h)]] <- path$efficiency
    out[[paste0("future_net_move_h", h)]] <- path$net_move
    out[[paste0("future_turn_rate_h", h)]] <- path$turn_rate
    out[[paste0("er_direction_survival_h", h)]] <- ifelse(is.finite(path$net_move) & is.finite(er_direction) & er_direction != 0, as.numeric(sign(path$net_move) == er_direction), NA_real_)
    out[[paste0("adx_direction_survival_h", h)]] <- ifelse(is.finite(path$net_move) & is.finite(adx_object$direction) & adx_object$direction != 0, as.numeric(sign(path$net_move) == adx_object$direction), NA_real_)
  }
  out
}

hreg51_build_ledger <- function(bars, contract = hreg51_contract()) {
  bars <- hreg51_assert_bars(bars, contract)
  ledgers <- lapply(split(bars, bars$symbol), hreg51_build_asset_ledger, contract = contract)
  out <- do.call(rbind, ledgers)
  rownames(out) <- NULL
  out[order(out$symbol, out$session_date), , drop = FALSE]
}

hreg51_candidate_columns <- function(candidate) {
  candidate <- toupper(candidate)
  if (candidate == "ER") return(list(score = "er_percentile", state = "er_state", direction = "er_direction"))
  if (candidate == "ADX") return(list(score = "adx_percentile", state = "adx_state", direction = "adx_direction"))
  hreg51_stop("Candidate must be ER or ADX.")
}

hreg51_spearman <- function(x, y) {
  keep <- is.finite(x) & is.finite(y)
  if (sum(keep) < 8L || length(unique(x[keep])) < 2L || length(unique(y[keep])) < 2L) return(NA_real_)
  suppressWarnings(stats::cor(x[keep], y[keep], method = "spearman"))
}

hreg51_asset_summary <- function(ledger, candidate, horizon, sample = "ALL", offset = 0L,
                                  start_date = NULL, end_date = NULL) {
  cols <- hreg51_candidate_columns(candidate)
  h <- as.integer(horizon)
  x <- ledger[ledger$session_date >= hreg51_contract()$analysis_start & ledger$session_date <= hreg51_contract()$analysis_end, , drop = FALSE]
  if (!is.null(start_date)) x <- x[x$session_date >= as.Date(start_date), , drop = FALSE]
  if (!is.null(end_date)) x <- x[x$session_date <= as.Date(end_date), , drop = FALSE]
  target <- paste0("future_efficiency_h", h)
  survival <- paste0(tolower(candidate), "_direction_survival_h", h)
  turn_rate <- paste0("future_turn_rate_h", h)
  rows <- lapply(split(x, x$symbol), function(z) {
    symbol <- z$symbol[[1L]]
    keep <- is.finite(z[[cols$score]]) & is.finite(z[[target]]) & !is.na(z[[cols$state]])
    if (toupper(sample) == "NON_OVERLAP") keep <- keep & ((z$analysis_index - 1L - as.integer(offset)) %% h == 0L)
    z <- z[keep, , drop = FALSE]
    state_metric <- function(state, column, fun = stats::median) {
      values <- z[[column]][z[[cols$state]] == state]
      values <- values[is.finite(values)]
      if (length(values)) fun(values) else NA_real_
    }
    low_eff <- state_metric("LOW", target)
    medium_eff <- state_metric("MEDIUM", target)
    high_eff <- state_metric("HIGH", target)
    data.frame(
      candidate = toupper(candidate), symbol = symbol,
      horizon = h, sample = toupper(sample), offset = as.integer(offset), observations = nrow(z),
      spearman = if (nrow(z)) hreg51_spearman(z[[cols$score]], z[[target]]) else NA_real_,
      low_n = sum(z[[cols$state]] == "LOW"), medium_n = sum(z[[cols$state]] == "MEDIUM"), high_n = sum(z[[cols$state]] == "HIGH"),
      low_efficiency = low_eff, medium_efficiency = medium_eff, high_efficiency = high_eff,
      high_low_ratio = high_eff / low_eff,
      monotonic = isTRUE(high_eff > medium_eff && medium_eff > low_eff),
      high_survival = state_metric("HIGH", survival, mean), low_survival = state_metric("LOW", survival, mean),
      survival_gap = state_metric("HIGH", survival, mean) - state_metric("LOW", survival, mean),
      high_turn_rate = state_metric("HIGH", turn_rate, mean), low_turn_rate = state_metric("LOW", turn_rate, mean),
      turn_rate_gap = state_metric("HIGH", turn_rate, mean) - state_metric("LOW", turn_rate, mean),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

hreg51_panel_summary <- function(asset_summary) {
  groups <- split(asset_summary, interaction(asset_summary$candidate, asset_summary$horizon, asset_summary$sample, asset_summary$offset, drop = TRUE))
  do.call(rbind, lapply(groups, function(x) data.frame(
    candidate = x$candidate[[1L]], horizon = x$horizon[[1L]], sample = x$sample[[1L]], offset = x$offset[[1L]],
    assets = nrow(x), median_spearman = stats::median(x$spearman, na.rm = TRUE), positive_assets = sum(x$spearman > 0, na.rm = TRUE),
    median_high_low_ratio = stats::median(x$high_low_ratio, na.rm = TRUE), high_above_low_assets = sum(x$high_low_ratio > 1, na.rm = TRUE),
    monotonic_assets = sum(x$monotonic, na.rm = TRUE), median_survival_gap = stats::median(x$survival_gap, na.rm = TRUE),
    positive_survival_assets = sum(x$survival_gap > 0, na.rm = TRUE), median_turn_rate_gap = stats::median(x$turn_rate_gap, na.rm = TRUE),
    lower_turn_rate_assets = sum(x$turn_rate_gap < 0, na.rm = TRUE), stringsAsFactors = FALSE
  )))
}

hreg51_all_summaries <- function(ledger, contract = hreg51_contract()) {
  rows <- list(); k <- 0L
  for (candidate in c("ER", "ADX")) for (h in contract$horizons) for (sample in c("ALL", "NON_OVERLAP")) {
    k <- k + 1L
    rows[[k]] <- hreg51_asset_summary(ledger, candidate, h, sample, 0L)
  }
  asset <- do.call(rbind, rows)
  list(asset = asset, panel = hreg51_panel_summary(asset))
}

hreg51_offset_summary <- function(ledger, contract = hreg51_contract()) {
  h <- contract$primary_horizon
  rows <- list(); k <- 0L
  for (candidate in c("ER", "ADX")) for (offset in 0:(h - 1L)) {
    k <- k + 1L
    rows[[k]] <- hreg51_panel_summary(hreg51_asset_summary(ledger, candidate, h, "NON_OVERLAP", offset))
  }
  do.call(rbind, rows)
}

hreg51_temporal_summary <- function(ledger, contract = hreg51_contract()) {
  periods <- data.frame(period = c("2018-2020", "2021-2023"), start = as.Date(c("2018-01-02", "2021-01-04")), end = as.Date(c("2020-12-31", "2023-12-29")))
  rows <- list(); k <- 0L
  for (candidate in c("ER", "ADX")) for (i in seq_len(nrow(periods))) {
    k <- k + 1L
    y <- hreg51_panel_summary(hreg51_asset_summary(ledger, candidate, contract$primary_horizon, "ALL", 0L, periods$start[[i]], periods$end[[i]]))
    y$period <- periods$period[[i]]
    rows[[k]] <- y
  }
  do.call(rbind, rows)
}

hreg51_calendar_summary <- function(ledger, contract = hreg51_contract()) {
  rows <- list(); k <- 0L
  for (candidate in c("ER", "ADX")) for (year in 2018:2023) {
    k <- k + 1L
    y <- hreg51_panel_summary(hreg51_asset_summary(ledger, candidate, contract$primary_horizon, "ALL", 0L, as.Date(paste0(year, "-01-01")), as.Date(paste0(year, "-12-31"))))
    y$year <- year
    rows[[k]] <- y
  }
  do.call(rbind, rows)
}

hreg51_state_diagnostics <- function(ledger, candidate, contract = hreg51_contract()) {
  cols <- hreg51_candidate_columns(candidate)
  x <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end & !is.na(ledger[[cols$state]]), , drop = FALSE]
  rows <- lapply(split(x, x$symbol), function(z) {
    states <- z[[cols$state]]
    groups <- cumsum(c(TRUE, states[-1L] != head(states, -1L)))
    runs <- do.call(rbind, lapply(split(seq_along(states), groups), function(idx) data.frame(state = states[idx[[1L]]], sessions = length(idx))))
    switches <- max(0L, nrow(runs) - 1L)
    reversals <- 0L
    if (nrow(runs) >= 3L) for (i in 2:(nrow(runs) - 1L)) if (runs$sessions[[i]] == 1L && runs$state[[i - 1L]] == runs$state[[i + 1L]]) reversals <- reversals + 1L
    years <- as.numeric(max(z$session_date) - min(z$session_date)) / 365.25
    counts <- table(factor(states, levels = c("LOW", "MEDIUM", "HIGH")))
    data.frame(
      candidate = toupper(candidate), symbol = z$symbol[[1L]],
      low_fraction = counts[["LOW"]] / length(states), medium_fraction = counts[["MEDIUM"]] / length(states), high_fraction = counts[["HIGH"]] / length(states),
      switches_per_year = switches / years, median_run_sessions = stats::median(runs$sessions),
      one_session_reversal_share = if (switches > 0L) reversals / switches else 0, stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

hreg51_circular_controls <- function(ledger, contract = hreg51_contract()) {
  set.seed(contract$simulation_seed)
  base <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
  base$year <- as.integer(format(base$session_date, "%Y"))
  rows <- list(); k <- 0L
  rotate <- function(v, shift) c(tail(v, -shift), head(v, shift))
  for (simulation in seq_len(contract$simulations)) {
    for (candidate in c("ER", "ADX")) {
      cols <- hreg51_candidate_columns(candidate)
      x <- base
      for (idx in split(seq_len(nrow(x)), interaction(x$symbol, x$year, drop = TRUE))) {
        if (length(idx) > 1L) {
          shift <- sample.int(length(idx) - 1L, 1L)
          x[[cols$score]][idx] <- rotate(x[[cols$score]][idx], shift)
          x[[cols$state]][idx] <- rotate(x[[cols$state]][idx], shift)
          x[[cols$direction]][idx] <- rotate(x[[cols$direction]][idx], shift)
        }
      }
      survival_name <- paste0(tolower(candidate), "_direction_survival_h", contract$primary_horizon)
      x[[survival_name]] <- ifelse(is.finite(x[[paste0("future_net_move_h", contract$primary_horizon)]]) & is.finite(x[[cols$direction]]) & x[[cols$direction]] != 0,
                                   as.numeric(sign(x[[paste0("future_net_move_h", contract$primary_horizon)]]) == x[[cols$direction]]), NA_real_)
      summary <- hreg51_panel_summary(hreg51_asset_summary(x, candidate, contract$primary_horizon, "ALL"))
      k <- k + 1L
      rows[[k]] <- data.frame(simulation = simulation, candidate = candidate, median_spearman = summary$median_spearman,
                              median_log_high_low_ratio = log(summary$median_high_low_ratio), stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}
