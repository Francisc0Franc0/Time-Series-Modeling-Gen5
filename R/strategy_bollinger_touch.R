# Gen5.1 Bollinger touch strategy proof helpers.

g5_bollinger_touch_schema_version <- function() {
  "gen5_bollinger_touch_v0.1"
}

g5_bollinger_touch_sd_label <- function(sd_multiplier) {
  gsub("\\.", "p", format(as.numeric(sd_multiplier), trim = TRUE, scientific = FALSE))
}

g5_bollinger_touch_strategy_id <- function(lookback_period, sd_multiplier) {
  lookback_period <- as.integer(lookback_period)
  sd_multiplier <- as.numeric(sd_multiplier)
  if (is.na(lookback_period) || lookback_period < 2L || is.na(sd_multiplier) || sd_multiplier <= 0) {
    g5_stop("Bollinger touch model parameters must be lookback_period >= 2 and sd_multiplier > 0.")
  }
  paste0("bollinger_touch_n", lookback_period, "_sd", g5_bollinger_touch_sd_label(sd_multiplier))
}

g5_bollinger_touch_rolling_mean <- function(x, period) {
  period <- as.integer(period)
  if (is.na(period) || period < 2L) {
    g5_stop("Bollinger rolling period must be an integer >= 2.")
  }
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (length(x) < period) {
    return(out)
  }
  for (i in period:length(x)) {
    out[[i]] <- mean(x[(i - period + 1L):i], na.rm = FALSE)
  }
  out
}

g5_bollinger_touch_rolling_sd <- function(x, period) {
  period <- as.integer(period)
  if (is.na(period) || period < 2L) {
    g5_stop("Bollinger rolling period must be an integer >= 2.")
  }
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (length(x) < period) {
    return(out)
  }
  for (i in period:length(x)) {
    out[[i]] <- stats::sd(x[(i - period + 1L):i], na.rm = FALSE)
  }
  out
}

g5_bollinger_touch_indicators <- function(bars, symbol, lookback_period, sd_multiplier, start_date = NULL, end_date = NULL) {
  bars <- g5_ema_cross_prepare_bars(bars, symbol)
  strategy_id <- g5_bollinger_touch_strategy_id(lookback_period, sd_multiplier)
  lookback_period <- as.integer(lookback_period)
  sd_multiplier <- as.numeric(sd_multiplier)
  mid <- g5_bollinger_touch_rolling_mean(bars$close, lookback_period)
  band_sd <- g5_bollinger_touch_rolling_sd(bars$close, lookback_period)
  bars$strategy_family <- "bollinger_touch"
  bars$strategy_id <- strategy_id
  bars$model_instance_id <- strategy_id
  bars$lookback_period <- lookback_period
  bars$sd_multiplier <- sd_multiplier
  bars$bb_mid <- mid
  bars$bb_upper <- mid + sd_multiplier * band_sd
  bars$bb_lower <- mid - sd_multiplier * band_sd
  bars$entry_signal <- is.finite(bars$bb_lower) & as.numeric(bars$low) <= bars$bb_lower
  bars$exit_signal <- is.finite(bars$bb_upper) & as.numeric(bars$high) >= bars$bb_upper
  bars$signal_state <- ifelse(
    bars$entry_signal,
    "lower_band_touched",
    ifelse(bars$exit_signal, "upper_band_touched", ifelse(is.finite(bars$bb_mid), "inside_bands", "unknown"))
  )
  if (!is.null(start_date)) {
    bars <- bars[as.Date(bars$session_date) >= as.Date(start_date), , drop = FALSE]
  }
  if (!is.null(end_date)) {
    bars <- bars[as.Date(bars$session_date) <= as.Date(end_date), , drop = FALSE]
  }
  rownames(bars) <- NULL
  bars
}

g5_bollinger_touch_trades <- function(
  bars,
  symbol,
  lookback_period,
  sd_multiplier,
  trading_start_date,
  trading_end_date,
  leverage = 1
) {
  leverage <- g5_ema_cross_validate_leverage(leverage)
  strategy_id <- g5_bollinger_touch_strategy_id(lookback_period, sd_multiplier)
  all_bars <- g5_ema_cross_prepare_bars(bars, symbol, end_date = trading_end_date)
  indicators <- g5_bollinger_touch_indicators(all_bars, symbol, lookback_period, sd_multiplier)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  session_dates <- as.Date(all_bars$session_date)
  trading_start_date <- as.Date(trading_start_date)
  trading_end_date <- as.Date(trading_end_date)
  if (any(is.na(c(trading_start_date, trading_end_date))) || trading_start_date > trading_end_date) {
    g5_stop("trading_start_date and trading_end_date must be valid ordered dates.")
  }

  trades <- list()
  trade_no <- 0L
  in_position <- FALSE
  open_trade <- NULL
  latest_idx <- max(which(session_dates <= trading_end_date))
  i <- 1L
  while (i < nrow(all_bars)) {
    signal_date <- session_dates[[i]]
    if (signal_date < trading_start_date || signal_date > trading_end_date) {
      i <- i + 1L
      next
    }
    if (!in_position && isTRUE(indicators$entry_signal[[i]])) {
      entry_execution_idx <- i + 1L
      if (entry_execution_idx > nrow(all_bars)) {
        break
      }
      trade_no <- trade_no + 1L
      open_trade <- list(
        trade_no = trade_no,
        entry_signal_idx = i,
        entry_execution_idx = entry_execution_idx,
        entry_price = as.numeric(all_bars$open[[entry_execution_idx]])
      )
      in_position <- TRUE
      i <- entry_execution_idx
      next
    }

    if (in_position && isTRUE(indicators$exit_signal[[i]])) {
      exit_execution_idx <- i + 1L
      if (exit_execution_idx > nrow(all_bars)) {
        break
      }
      entry_price <- open_trade$entry_price
      exit_price <- as.numeric(all_bars$open[[exit_execution_idx]])
      underlying_realized_return <- (exit_price / entry_price) - 1
      realized_return <- leverage * underlying_realized_return
      trades[[length(trades) + 1L]] <- data.frame(
        schema_version = g5_bollinger_touch_schema_version(),
        trade_id = sprintf("%s_%s_%03d", symbol, strategy_id, open_trade$trade_no),
        symbol = symbol,
        strategy_id = strategy_id,
        lookback_period = as.integer(lookback_period),
        sd_multiplier = as.numeric(sd_multiplier),
        trade_status = "closed",
        entry_signal_date = session_dates[[open_trade$entry_signal_idx]],
        entry_signal_index = open_trade$entry_signal_idx,
        entry_signal_price = as.numeric(all_bars$close[[open_trade$entry_signal_idx]]),
        entry_execution_date = session_dates[[open_trade$entry_execution_idx]],
        entry_execution_index = open_trade$entry_execution_idx,
        entry_execution_price = entry_price,
        exit_signal_date = signal_date,
        exit_signal_index = i,
        exit_signal_price = as.numeric(all_bars$close[[i]]),
        exit_execution_date = session_dates[[exit_execution_idx]],
        exit_execution_index = exit_execution_idx,
        exit_execution_price = exit_price,
        latest_mark_date = session_dates[[latest_idx]],
        latest_mark_price = as.numeric(all_bars$close[[latest_idx]]),
        trace_end_date = session_dates[[exit_execution_idx]],
        trace_end_index = exit_execution_idx,
        trace_end_price = exit_price,
        underlying_realized_return = underlying_realized_return,
        underlying_unrealized_return = NA_real_,
        realized_return = realized_return,
        unrealized_return = NA_real_,
        trace_return = realized_return,
        trade_outcome = if (realized_return > 0) "win" else if (realized_return < 0) "loss" else "flat",
        holding_sessions_completed = exit_execution_idx - open_trade$entry_execution_idx + 1L,
        signal_rule = "lower_bollinger_band_touched_when_flat",
        entry_execution_rule = "next_session_open_after_entry_signal",
        exit_signal_rule = "upper_bollinger_band_touched_when_long",
        exit_execution_rule = "next_session_open_after_exit_signal",
        leverage = leverage,
        capital_fraction = 1,
        stringsAsFactors = FALSE
      )
      in_position <- FALSE
      open_trade <- NULL
      i <- exit_execution_idx
      next
    }
    i <- i + 1L
  }

  if (in_position && !is.null(open_trade)) {
    entry_price <- open_trade$entry_price
    latest_close <- as.numeric(all_bars$close[[latest_idx]])
    underlying_unrealized_return <- (latest_close / entry_price) - 1
    unrealized_return <- leverage * underlying_unrealized_return
    trades[[length(trades) + 1L]] <- data.frame(
      schema_version = g5_bollinger_touch_schema_version(),
      trade_id = sprintf("%s_%s_%03d", symbol, strategy_id, open_trade$trade_no),
      symbol = symbol,
      strategy_id = strategy_id,
      lookback_period = as.integer(lookback_period),
      sd_multiplier = as.numeric(sd_multiplier),
      trade_status = "open",
      entry_signal_date = session_dates[[open_trade$entry_signal_idx]],
      entry_signal_index = open_trade$entry_signal_idx,
      entry_signal_price = as.numeric(all_bars$close[[open_trade$entry_signal_idx]]),
      entry_execution_date = session_dates[[open_trade$entry_execution_idx]],
      entry_execution_index = open_trade$entry_execution_idx,
      entry_execution_price = entry_price,
      exit_signal_date = as.Date(NA),
      exit_signal_index = NA_integer_,
      exit_signal_price = NA_real_,
      exit_execution_date = as.Date(NA),
      exit_execution_index = NA_integer_,
      exit_execution_price = NA_real_,
      latest_mark_date = session_dates[[latest_idx]],
      latest_mark_price = latest_close,
      trace_end_date = session_dates[[latest_idx]],
      trace_end_index = latest_idx,
      trace_end_price = latest_close,
      underlying_realized_return = NA_real_,
      underlying_unrealized_return = underlying_unrealized_return,
      realized_return = NA_real_,
      unrealized_return = unrealized_return,
      trace_return = unrealized_return,
      trade_outcome = if (unrealized_return > 0) "win" else if (unrealized_return < 0) "loss" else "flat",
      holding_sessions_completed = latest_idx - open_trade$entry_execution_idx + 1L,
      signal_rule = "lower_bollinger_band_touched_when_flat",
      entry_execution_rule = "next_session_open_after_entry_signal",
      exit_signal_rule = "upper_bollinger_band_touched_when_long",
      exit_execution_rule = "next_session_open_after_exit_signal",
      leverage = leverage,
      capital_fraction = 1,
      stringsAsFactors = FALSE
    )
  }

  if (length(trades) == 0L) {
    return(data.frame())
  }
  out <- do.call(rbind, trades)
  rownames(out) <- NULL
  out
}

g5_bollinger_touch_metrics <- function(trades, equity_curve, symbol, lookback_period, sd_multiplier, leverage) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  leverage <- g5_ema_cross_validate_leverage(leverage)
  closed <- if (is.data.frame(trades) && nrow(trades) > 0L) trades[trades$trade_status == "closed", , drop = FALSE] else data.frame()
  open_trades <- if (is.data.frame(trades) && nrow(trades) > 0L) trades[trades$trade_status != "closed", , drop = FALSE] else data.frame()
  closed_returns <- if (nrow(closed) > 0L) as.numeric(closed$realized_return) else numeric()
  marked_returns <- if (is.data.frame(trades) && nrow(trades) > 0L) {
    as.numeric(ifelse(trades$trade_status == "closed", trades$realized_return, trades$unrealized_return))
  } else {
    numeric()
  }
  wins <- closed_returns[closed_returns > 0]
  losses <- closed_returns[closed_returns < 0]
  flats <- closed_returns[closed_returns == 0]
  strategy_underwater <- g5_ema_cross_time_underwater_summary(equity_curve$strategy_drawdown)
  buy_hold_underwater <- g5_ema_cross_time_underwater_summary(equity_curve$buy_hold_drawdown)
  start_date <- min(equity_curve$session_date)
  end_date <- max(equity_curve$session_date)
  ending_equity <- tail(equity_curve$strategy_equity, 1L)
  buy_hold_ending_equity <- tail(equity_curve$buy_hold_equity, 1L)
  data.frame(
    schema_version = g5_bollinger_touch_schema_version(),
    symbol = symbol,
    strategy_family = "bollinger_touch",
    strategy_id = g5_bollinger_touch_strategy_id(lookback_period, sd_multiplier),
    model_instance_id = g5_bollinger_touch_strategy_id(lookback_period, sd_multiplier),
    lookback_period = as.integer(lookback_period),
    sd_multiplier = as.numeric(sd_multiplier),
    leverage = leverage,
    trade_count = if (is.data.frame(trades)) nrow(trades) else 0L,
    closed_trade_count = nrow(closed),
    open_trade_count = nrow(open_trades),
    win_count = length(wins),
    loss_count = length(losses),
    flat_count = length(flats),
    win_rate = if (length(closed_returns) == 0L) NA_real_ else length(wins) / length(closed_returns),
    compounded_closed_return = if (length(closed_returns) == 0L) 0 else prod(1 + closed_returns) - 1,
    compounded_marked_return = if (length(marked_returns) == 0L) 0 else prod(1 + marked_returns) - 1,
    ending_equity = ending_equity,
    total_return = ending_equity - 1,
    cagr = g5_ema_cross_cagr(1, ending_equity, start_date, end_date),
    sharpe = g5_ema_cross_sharpe(equity_curve$strategy_equity),
    max_drawdown = min(equity_curve$strategy_drawdown, na.rm = TRUE),
    underwater_session_count = strategy_underwater$count,
    underwater_fraction = strategy_underwater$fraction,
    max_underwater_streak = strategy_underwater$max_streak,
    average_trade_return = if (length(closed_returns) == 0L) NA_real_ else mean(closed_returns),
    median_trade_return = if (length(closed_returns) == 0L) NA_real_ else stats::median(closed_returns),
    best_trade_return = if (length(closed_returns) == 0L) NA_real_ else max(closed_returns),
    worst_trade_return = if (length(closed_returns) == 0L) NA_real_ else min(closed_returns),
    profit_factor = if (length(closed_returns) == 0L || length(losses) == 0L) {
      if (length(wins) == 0L) NA_real_ else Inf
    } else {
      sum(wins) / abs(sum(losses))
    },
    exposure_fraction = mean(equity_curve$in_position, na.rm = TRUE),
    buy_hold_ending_equity = buy_hold_ending_equity,
    buy_hold_total_return = buy_hold_ending_equity - 1,
    buy_hold_cagr = g5_ema_cross_cagr(1, buy_hold_ending_equity, start_date, end_date),
    buy_hold_sharpe = g5_ema_cross_sharpe(equity_curve$buy_hold_equity),
    buy_hold_max_drawdown = min(equity_curve$buy_hold_drawdown, na.rm = TRUE),
    buy_hold_underwater_session_count = buy_hold_underwater$count,
    buy_hold_underwater_fraction = buy_hold_underwater$fraction,
    buy_hold_max_underwater_streak = buy_hold_underwater$max_streak,
    stringsAsFactors = FALSE
  )
}

g5_bollinger_touch_evaluate_grid <- function(
  bars,
  symbol,
  trading_start_date,
  trading_end_date,
  lookback_periods = c(10L, 20L, 30L),
  sd_multipliers = c(1.5, 2, 2.5),
  leverage = 1
) {
  lookback_periods <- sort(unique(as.integer(lookback_periods)))
  sd_multipliers <- sort(unique(as.numeric(sd_multipliers)))
  leverage <- g5_ema_cross_validate_leverage(leverage)
  rows <- list()
  details <- list()
  for (lookback in lookback_periods) {
    for (sd_multiplier in sd_multipliers) {
      if (is.na(lookback) || lookback < 2L || is.na(sd_multiplier) || sd_multiplier <= 0) {
        next
      }
      trades <- g5_bollinger_touch_trades(
        bars,
        symbol = symbol,
        lookback_period = lookback,
        sd_multiplier = sd_multiplier,
        trading_start_date = trading_start_date,
        trading_end_date = trading_end_date,
        leverage = leverage
      )
      equity_curve <- g5_ema_cross_equity_curve(
        trades,
        bars,
        symbol = symbol,
        trading_start_date = trading_start_date,
        trading_end_date = trading_end_date,
        leverage = leverage
      )
      metrics <- g5_bollinger_touch_metrics(trades, equity_curve, symbol, lookback, sd_multiplier, leverage)
      key <- metrics$model_instance_id[[1L]]
      rows[[length(rows) + 1L]] <- metrics
      details[[key]] <- list(trades = trades, equity_curve = equity_curve, metrics = metrics)
    }
  }
  if (length(rows) == 0L) {
    g5_stop("Bollinger touch grid resolved zero valid parameter pairs.")
  }
  grid <- do.call(rbind, rows)
  grid <- grid[order(
    ifelse(is.na(grid$sharpe), -Inf, grid$sharpe),
    ifelse(is.na(grid$total_return), -Inf, grid$total_return),
    decreasing = TRUE
  ), , drop = FALSE]
  rownames(grid) <- NULL
  list(selected = grid[1L, , drop = FALSE], parameter_performance = grid, details = details)
}
