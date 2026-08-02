# Frozen attribution helpers for LIT-MOM-01.2 / AUDIT_01.

g5_mom012a_stop <- function(message) stop(message, call. = FALSE)

g5_mom012a_contract <- function() {
  list(
    audit_id = "LIT-MOM-01.2 / AUDIT_01_EXPOSURE_AND_SELECTION",
    parent_id = "LIT-MOM-01.2",
    evidence_label = "RETROSPECTIVE_ATTRIBUTION_AUDIT",
    as_of_timestamp = "2026-07-30 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    retrospective_start = as.Date("2021-01-04"),
    retrospective_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    primary_cost_bps = 5,
    fixed_lookbacks = c(250L, 60L),
    fixed_holdings = c(25L, 5L),
    random_schedule_count = 1000L,
    random_seed = 61201L,
    cluster_bootstrap_count = 5000L,
    cluster_bootstrap_seed = 61202L,
    market_trend_sessions = 60L,
    volatility_sessions = 20L,
    environment_minimum_trades = 100L,
    environment_minimum_assets = 20L,
    breadth_threshold = 0.55
  )
}

g5_mom012a_validate_contract <- function(contract = g5_mom012a_contract()) {
  frozen <- g5_mom012a_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom012a_stop("Frozen AUDIT_01 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom012a_stop(paste(
      "Frozen AUDIT_01 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom012a_sector_etfs <- function() {
  c(
    "Communication Services" = "XLC",
    "Consumer Discretionary" = "XLY",
    "Consumer Staples" = "XLP",
    "Energy" = "XLE",
    "Financials" = "XLF",
    "Health Care" = "XLV",
    "Industrials" = "XLI",
    "Information Technology" = "XLK",
    "Materials" = "XLB",
    "Real Estate" = "XLRE",
    "Utilities" = "XLU"
  )
}

g5_mom012a_validate_bars <- function(bars) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_mom012a_stop(paste("Audit bars missing columns:", paste(missing, collapse = ", ")))
  }
  x <- bars
  x$session_date <- as.Date(x$session_date)
  numeric_cols <- c("open", "high", "low", "close", "volume")
  x[numeric_cols] <- lapply(x[numeric_cols], as.numeric)
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  if (anyDuplicated(x[c("symbol", "session_date")])) {
    g5_mom012a_stop("Audit bars contain duplicate symbol/session rows.")
  }
  if (any(!is.finite(as.matrix(x[c("open", "high", "low", "close")]))) ||
      any(as.matrix(x[c("open", "high", "low", "close")]) <= 0)) {
    g5_mom012a_stop("Audit bars contain invalid OHLC values.")
  }
  x
}

g5_mom012a_schedule_from_entries <- function(bars, entry_indices, holding_sessions) {
  x <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  h <- as.integer(holding_sessions)
  entry_indices <- sort(as.integer(entry_indices))
  if (!length(entry_indices) || h < 1L) {
    g5_mom012a_stop("Audit schedule requires entries and a positive holding period.")
  }
  exit_indices <- entry_indices + h
  if (any(entry_indices < 2L) || any(exit_indices > nrow(x))) {
    g5_mom012a_stop("Audit schedule indices exceed available bars.")
  }
  if (length(entry_indices) > 1L && any(entry_indices[-1L] < head(exit_indices, -1L))) {
    g5_mom012a_stop("Audit schedule overlaps.")
  }
  signal_indices <- entry_indices - 1L
  data.frame(
    trade_id = seq_along(entry_indices),
    signal_index = signal_indices,
    entry_index = entry_indices,
    exit_index = exit_indices,
    signal_date = as.Date(x$session_date[signal_indices]),
    entry_date = as.Date(x$session_date[entry_indices]),
    exit_date = as.Date(x$session_date[exit_indices]),
    direction = 1L,
    direction_label = "LONG",
    past_lookback_return = NA_real_,
    entry_open = x$open[entry_indices],
    exit_open = x$open[exit_indices],
    underlying_holding_return = x$open[exit_indices] / x$open[entry_indices] - 1,
    direction_correct = x$open[exit_indices] > x$open[entry_indices],
    stringsAsFactors = FALSE
  )
}

g5_mom012a_buy_hold_schedule <- function(bars, period_start, period_end) {
  x <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  dates <- as.Date(x$session_date)
  entry <- which(dates >= as.Date(period_start))[1L]
  exit <- tail(which(dates <= as.Date(period_end)), 1L)
  if (is.na(entry) || is.na(exit) || entry < 2L || exit <= entry) {
    g5_mom012a_stop("Buy-and-hold window is incomplete.")
  }
  g5_mom012a_schedule_from_entries(x, entry, exit - entry)
}

g5_mom012a_always_long_schedule <- function(
  bars,
  period_start,
  period_end,
  holding_sessions
) {
  x <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  dates <- as.Date(x$session_date)
  first_entry <- which(dates >= as.Date(period_start))[1L]
  final_index <- tail(which(dates <= as.Date(period_end)), 1L)
  h <- as.integer(holding_sessions)
  entries <- seq.int(first_entry, final_index - h, by = h)
  g5_mom012a_schedule_from_entries(x, entries, h)
}

g5_mom012a_replay_schedule <- function(bars, schedule, cost_bps = 5) {
  if (!exists("g5_mom012_replay_regime", mode = "function")) {
    g5_mom012a_stop("Source the LIT-MOM-01.2 module before the audit module.")
  }
  symbols <- unique(as.character(bars$symbol))
  if (length(symbols) != 1L) {
    g5_mom012a_stop("Schedule replay requires exactly one symbol.")
  }
  replay_contract <- if (identical(symbols, "SHY")) {
    g5_mom012_contract()
  } else {
    g5_mom012_replication_contract(symbols)
  }
  g5_mom012_replay_regime(
    bars = bars,
    schedule = schedule,
    cost_bps = cost_bps,
    borrow_bps_annual = 0,
    regime_id = "PRIMARY",
    contract = replay_contract
  )
}

g5_mom012a_path_metrics <- function(returns) {
  returns <- as.numeric(returns)
  returns <- returns[is.finite(returns)]
  if (!length(returns)) {
    return(c(cumulative_return = NA_real_, maximum_drawdown = NA_real_))
  }
  wealth <- cumprod(1 + returns)
  peak <- cummax(c(1, wealth))[-1L]
  c(
    cumulative_return = tail(wealth, 1L) - 1,
    maximum_drawdown = min(wealth / peak - 1)
  )
}

g5_mom012a_complete_daily_path <- function(bars, replay, period_start, period_end) {
  x <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  dates <- as.Date(x$session_date)
  interval_i <- which(dates[-1L] >= as.Date(period_start) & dates[-1L] <= as.Date(period_end)) + 1L
  out <- data.frame(
    outcome_date = dates[interval_i],
    asset_open_return = x$open[interval_i] / x$open[interval_i - 1L] - 1,
    strategy_return = 0,
    stringsAsFactors = FALSE
  )
  primary <- replay[replay$regime_id == "PRIMARY", c("outcome_date", "net_return"), drop = FALSE]
  primary$outcome_date <- as.Date(primary$outcome_date)
  matched <- match(out$outcome_date, primary$outcome_date)
  has <- !is.na(matched)
  out$strategy_return[has] <- primary$net_return[matched[has]]
  out
}

g5_mom012a_constant_exposure <- function(daily_path, exposure, cost_bps = 5) {
  exposure <- max(0, min(1, as.numeric(exposure)))
  returns <- exposure * daily_path$asset_open_return
  metrics <- g5_mom012a_path_metrics(returns)
  cost_drag <- 2 * exposure * as.numeric(cost_bps) / 10000
  metrics[["cumulative_return"]] <-
    (1 + metrics[["cumulative_return"]]) * (1 - cost_drag) - 1
  metrics
}

g5_mom012a_regression <- function(daily_path, spy_returns) {
  spy_returns$outcome_date <- as.Date(spy_returns$outcome_date)
  joined <- merge(daily_path, spy_returns, by = "outcome_date", all = FALSE)
  joined <- joined[is.finite(joined$strategy_return) & is.finite(joined$spy_return), , drop = FALSE]
  if (nrow(joined) < 60L || stats::sd(joined$spy_return) == 0) {
    return(data.frame(
      spy_beta = NA_real_, annualized_alpha = NA_real_, regression_r_squared = NA_real_
    ))
  }
  fit <- stats::lm(strategy_return ~ spy_return, data = joined)
  data.frame(
    spy_beta = unname(stats::coef(fit)[["spy_return"]]),
    annualized_alpha = unname(stats::coef(fit)[["(Intercept)"]]) * 252,
    regression_r_squared = summary(fit)$r.squared
  )
}

g5_mom012a_random_entry_indices <- function(candidates, trade_count, holding_sessions) {
  candidates <- as.integer(candidates)
  k <- as.integer(trade_count)
  h <- as.integer(holding_sessions)
  origin <- min(candidates)
  phase <- (candidates - origin) %% h
  pools <- split(candidates, phase)
  pools <- pools[vapply(pools, length, integer(1)) >= k]
  if (!length(pools)) {
    g5_mom012a_stop("Unable to draw a matched non-overlapping random schedule.")
  }
  pool <- pools[[sample(seq_along(pools), 1L)]]
  sort(sample(pool, k, replace = FALSE))
}

g5_mom012a_schedule_return <- function(bars, entry_indices, holding_sessions, cost_bps) {
  x <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  h <- as.integer(holding_sessions)
  c_rate <- as.numeric(cost_bps) / 10000
  multipliers <- x$open[entry_indices + h] / x$open[entry_indices]
  multipliers <- multipliers * (1 - c_rate) / (1 + c_rate)
  prod(multipliers) - 1
}

g5_mom012a_random_timing <- function(
  bars,
  period_start,
  period_end,
  holding_sessions,
  trade_count,
  observed_return,
  simulations = 1000L,
  seed = 61201L,
  cost_bps = 5
) {
  x <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  dates <- as.Date(x$session_date)
  h <- as.integer(holding_sessions)
  candidates <- which(
    dates >= as.Date(period_start) &
      seq_along(dates) + h <= nrow(x) &
      dates[pmin(seq_along(dates) + h, nrow(x))] <= as.Date(period_end)
  )
  if (length(candidates) < trade_count) {
    g5_mom012a_stop("Insufficient candidate entries for matched timing audit.")
  }
  origin <- min(candidates)
  phases <- (candidates - origin) %% h
  pools <- split(candidates, phases)
  pools <- pools[vapply(pools, length, integer(1)) >= as.integer(trade_count)]
  if (!length(pools)) {
    g5_mom012a_stop("Unable to construct matched random phase pools.")
  }
  cost_rate <- as.numeric(cost_bps) / 10000
  set.seed(as.integer(seed))
  draws <- vapply(seq_len(as.integer(simulations)), function(i) {
    pool <- pools[[sample(seq_along(pools), 1L)]]
    entries <- sample(pool, as.integer(trade_count), replace = FALSE)
    multipliers <- x$open[entries + h] / x$open[entries]
    multipliers <- multipliers * (1 - cost_rate) / (1 + cost_rate)
    prod(multipliers) - 1
  }, numeric(1))
  data.frame(
    random_simulation_count = length(draws),
    random_median_return = stats::median(draws),
    random_q10_return = unname(stats::quantile(draws, 0.10)),
    random_q90_return = unname(stats::quantile(draws, 0.90)),
    observed_random_percentile = mean(draws <= observed_return),
    random_one_sided_p_value = (1 + sum(draws >= observed_return)) / (length(draws) + 1),
    stringsAsFactors = FALSE
  )
}

g5_mom012a_lag_return <- function(values, sessions) {
  n <- length(values)
  k <- as.integer(sessions)
  out <- rep(NA_real_, n)
  if (n > k) out[(k + 1L):n] <- values[(k + 1L):n] / values[1L:(n - k)] - 1
  out
}

g5_mom012a_rolling_volatility <- function(close, sessions) {
  returns <- c(NA_real_, close[-1L] / head(close, -1L) - 1)
  n <- length(close)
  k <- as.integer(sessions)
  out <- rep(NA_real_, n)
  if (n >= k + 1L) {
    for (i in (k + 1L):n) {
      out[[i]] <- stats::sd(returns[(i - k + 1L):i], na.rm = TRUE) * sqrt(252)
    }
  }
  out
}

g5_mom012a_feature_panel <- function(bars, trend_sessions = 60L, vol_sessions = 20L) {
  x <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  data.frame(
    signal_date = as.Date(x$session_date),
    trailing_return = g5_mom012a_lag_return(x$close, trend_sessions),
    realized_volatility = g5_mom012a_rolling_volatility(x$close, vol_sessions),
    stringsAsFactors = FALSE
  )
}

g5_mom012a_environment_summary <- function(trades) {
  required <- c("symbol", "trade_return", "market_trend", "market_volatility",
                "sector_trend", "relative_strength")
  missing <- setdiff(required, names(trades))
  if (length(missing)) g5_mom012a_stop("Environment trade table is incomplete.")
  definitions <- list(
    MARKET_TREND = "market_trend",
    MARKET_VOLATILITY = "market_volatility",
    SECTOR_TREND = "sector_trend",
    RELATIVE_STRENGTH = "relative_strength",
    MARKET_TREND_X_VOLATILITY = c("market_trend", "market_volatility")
  )
  rows <- list()
  row_i <- 1L
  for (descriptor in names(definitions)) {
    cols <- definitions[[descriptor]]
    complete <- stats::complete.cases(trades[cols])
    state <- rep(NA_character_, nrow(trades))
    state[complete] <- do.call(paste, c(trades[complete, cols, drop = FALSE], sep = " / "))
    for (value in sort(unique(state[!is.na(state)]))) {
      x <- trades[state == value & !is.na(state), , drop = FALSE]
      rows[[row_i]] <- data.frame(
        descriptor = descriptor,
        state = value,
        trade_count = nrow(x),
        asset_count = length(unique(x$symbol)),
        mean_primary_trade_return = mean(x$trade_return),
        hit_rate = mean(x$trade_return > 0),
        compounded_trade_return = prod(1 + x$trade_return) - 1,
        stringsAsFactors = FALSE
      )
      row_i <- row_i + 1L
    }
  }
  do.call(rbind, rows)
}

g5_mom012a_cluster_bootstrap <- function(
  data,
  value_column,
  cluster_column = "sector",
  simulations = 5000L,
  seed = 61202L
) {
  x <- data[is.finite(data[[value_column]]) & !is.na(data[[cluster_column]]), , drop = FALSE]
  clusters <- unique(x[[cluster_column]])
  if (length(clusters) < 2L) g5_mom012a_stop("Cluster bootstrap requires two clusters.")
  set.seed(as.integer(seed))
  draws <- vapply(seq_len(as.integer(simulations)), function(i) {
    sampled <- sample(clusters, length(clusters), replace = TRUE)
    values <- unlist(lapply(sampled, function(cluster) {
      x[[value_column]][x[[cluster_column]] == cluster]
    }), use.names = FALSE)
    stats::median(values, na.rm = TRUE)
  }, numeric(1))
  data.frame(
    metric = value_column,
    estimate = stats::median(x[[value_column]], na.rm = TRUE),
    lower_90 = unname(stats::quantile(draws, 0.05)),
    upper_90 = unname(stats::quantile(draws, 0.95)),
    cluster_count = length(clusters),
    simulation_count = length(draws),
    stringsAsFactors = FALSE
  )
}

g5_mom012a_scorecard <- function(asset_summary, clustered_constant_lower, integrity_pass) {
  threshold <- g5_mom012a_contract()$breadth_threshold
  alpha_positive <- mean(asset_summary$annualized_alpha > 0, na.rm = TRUE)
  rows <- data.frame(
    diagnostic_id = c(
      "INTEGRITY", "MEDIAN_EXCESS_BUY_HOLD", "BREADTH_BEAT_BUY_HOLD",
      "MEDIAN_EXCESS_CONSTANT_EXPOSURE", "MEDIAN_EXCESS_ALWAYS_BLOCK",
      "BREADTH_BEAT_RANDOM_MEDIAN", "MEDIAN_RANDOM_PERCENTILE",
      "MEDIAN_SELECTED_BEATS_FIXED_250_25", "MEDIAN_SELECTED_BEATS_FIXED_60_5",
      "CLUSTER_LOWER_EXCESS_CONSTANT", "POSITIVE_SPY_ALPHA"
    ),
    passed = c(
      isTRUE(integrity_pass),
      stats::median(asset_summary$excess_vs_buy_hold, na.rm = TRUE) > 0,
      mean(asset_summary$excess_vs_buy_hold > 0, na.rm = TRUE) >= threshold,
      stats::median(asset_summary$excess_vs_constant_exposure, na.rm = TRUE) > 0,
      stats::median(asset_summary$excess_vs_always_long_block, na.rm = TRUE) > 0,
      mean(asset_summary$selected_return > asset_summary$random_median_return, na.rm = TRUE) >= threshold,
      stats::median(asset_summary$observed_random_percentile, na.rm = TRUE) > 0.50,
      stats::median(asset_summary$selected_minus_fixed_250_25, na.rm = TRUE) > 0,
      stats::median(asset_summary$selected_minus_fixed_60_5, na.rm = TRUE) > 0,
      is.finite(clustered_constant_lower) && clustered_constant_lower > 0,
      stats::median(asset_summary$annualized_alpha, na.rm = TRUE) > 0 && alpha_positive >= threshold
    ),
    stringsAsFactors = FALSE
  )
  rows
}
