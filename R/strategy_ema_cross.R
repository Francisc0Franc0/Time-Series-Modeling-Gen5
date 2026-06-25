# Gen5.1 diagnostic EMA cross backtest.

g5_ema_cross_schema_version <- function() {
  "gen5_ema_cross_v0.1"
}

g5_ema_cross_validate_leverage <- function(leverage) {
  leverage <- as.numeric(leverage)
  if (length(leverage) != 1L || is.na(leverage) || !is.finite(leverage) || leverage <= 0) {
    g5_stop("leverage must be a positive finite number.")
  }
  leverage
}

g5_ema_cross_leverage_label <- function(leverage) {
  leverage <- g5_ema_cross_validate_leverage(leverage)
  label <- sub("\\.?0+$", "", format(leverage, trim = TRUE, scientific = FALSE))
  paste0("lev", gsub("[^0-9A-Za-z]+", "_", label), "x")
}

g5_ema_cross_strategy_id <- function(fast_period, slow_period) {
  fast_period <- as.integer(fast_period)
  slow_period <- as.integer(slow_period)
  if (is.na(fast_period) || is.na(slow_period) || fast_period < 1L || slow_period < 2L || fast_period >= slow_period) {
    g5_stop("EMA cross requires positive periods with fast_period < slow_period.")
  }
  paste0("ema_cross_fast", fast_period, "_slow", slow_period)
}

g5_ema_cross_artifact_prefix <- function(as_of_timestamp, symbol, leverage = 1) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  paste("ema_cross", symbol, g5_ema_cross_leverage_label(leverage), stamp, sep = "_")
}

g5_ema_cross_output_dir <- function(repo_root, as_of_timestamp, symbol, leverage = 1) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "strategy_demos",
    g5_ema_cross_artifact_prefix(as_of_timestamp, symbol, leverage = leverage)
  )
}

g5_ema_cross_prepare_bars <- function(bars, symbol, start_date = NULL, end_date = NULL) {
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("EMA cross strategy requires exactly one symbol.")
  }
  bars <- g5_validate_bar_data(bars)
  bars <- bars[bars$symbol == symbol, , drop = FALSE]
  if (!is.null(start_date)) {
    bars <- bars[as.Date(bars$session_date) >= as.Date(start_date), , drop = FALSE]
  }
  if (!is.null(end_date)) {
    bars <- bars[as.Date(bars$session_date) <= as.Date(end_date), , drop = FALSE]
  }
  if (nrow(bars) < 3L) {
    g5_stop("EMA cross strategy requires at least three canonical bars.")
  }
  bars <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  rownames(bars) <- NULL
  bars
}

g5_ema_cross_ema <- function(x, period) {
  period <- as.integer(period)
  if (is.na(period) || period < 1L) {
    g5_stop("EMA period must be a positive integer.")
  }
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (length(x) < period) {
    return(out)
  }
  seed_idx <- period
  out[[seed_idx]] <- mean(x[seq_len(period)], na.rm = FALSE)
  alpha <- 2 / (period + 1)
  if (length(x) > seed_idx) {
    for (i in (seed_idx + 1L):length(x)) {
      out[[i]] <- alpha * x[[i]] + (1 - alpha) * out[[i - 1L]]
    }
  }
  out
}

g5_ema_cross_indicators <- function(bars, symbol, fast_period, slow_period, start_date = NULL, end_date = NULL) {
  bars <- g5_ema_cross_prepare_bars(bars, symbol)
  strategy_id <- g5_ema_cross_strategy_id(fast_period, slow_period)
  fast_period <- as.integer(fast_period)
  slow_period <- as.integer(slow_period)
  bars$fast_period <- fast_period
  bars$slow_period <- slow_period
  bars$strategy_id <- strategy_id
  bars$fast_ema <- g5_ema_cross_ema(bars$close, fast_period)
  bars$slow_ema <- g5_ema_cross_ema(bars$close, slow_period)
  bars$signal_state <- ifelse(
    is.finite(bars$fast_ema) & is.finite(bars$slow_ema) & bars$fast_ema > bars$slow_ema,
    "fast_above",
    ifelse(is.finite(bars$fast_ema) & is.finite(bars$slow_ema) & bars$fast_ema < bars$slow_ema, "fast_below", "unknown")
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

g5_ema_cross_trades <- function(
  bars,
  symbol,
  fast_period,
  slow_period,
  trading_start_date,
  trading_end_date,
  leverage = 1
) {
  leverage <- g5_ema_cross_validate_leverage(leverage)
  strategy_id <- g5_ema_cross_strategy_id(fast_period, slow_period)
  all_bars <- g5_ema_cross_prepare_bars(bars, symbol, end_date = trading_end_date)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  fast <- g5_ema_cross_ema(all_bars$close, fast_period)
  slow <- g5_ema_cross_ema(all_bars$close, slow_period)
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
  i <- 2L
  while (i < nrow(all_bars)) {
    signal_date <- session_dates[[i]]
    if (signal_date < trading_start_date || signal_date > trading_end_date) {
      i <- i + 1L
      next
    }
    has_cross_inputs <- all(is.finite(c(fast[[i - 1L]], slow[[i - 1L]], fast[[i]], slow[[i]])))
    if (!has_cross_inputs) {
      i <- i + 1L
      next
    }
    cross_above <- fast[[i - 1L]] <= slow[[i - 1L]] && fast[[i]] > slow[[i]]
    cross_below <- fast[[i - 1L]] >= slow[[i - 1L]] && fast[[i]] < slow[[i]]

    if (!in_position && cross_above) {
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

    if (in_position && cross_below) {
      exit_execution_idx <- i + 1L
      if (exit_execution_idx > nrow(all_bars)) {
        break
      }
      entry_price <- open_trade$entry_price
      exit_price <- as.numeric(all_bars$open[[exit_execution_idx]])
      underlying_realized_return <- (exit_price / entry_price) - 1
      realized_return <- leverage * underlying_realized_return
      trades[[length(trades) + 1L]] <- data.frame(
        schema_version = g5_ema_cross_schema_version(),
        trade_id = sprintf("%s_%s_%03d", symbol, strategy_id, open_trade$trade_no),
        symbol = symbol,
        strategy_id = strategy_id,
        fast_period = as.integer(fast_period),
        slow_period = as.integer(slow_period),
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
        signal_rule = "fast_ema_cross_above_slow_when_flat",
        entry_execution_rule = "next_session_open_after_entry_signal",
        exit_signal_rule = "fast_ema_cross_below_slow_when_long",
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
      schema_version = g5_ema_cross_schema_version(),
      trade_id = sprintf("%s_%s_%03d", symbol, strategy_id, open_trade$trade_no),
      symbol = symbol,
      strategy_id = strategy_id,
      fast_period = as.integer(fast_period),
      slow_period = as.integer(slow_period),
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
      signal_rule = "fast_ema_cross_above_slow_when_flat",
      entry_execution_rule = "next_session_open_after_entry_signal",
      exit_signal_rule = "fast_ema_cross_below_slow_when_long",
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

g5_ema_cross_chart_events <- function(trades) {
  if (!is.data.frame(trades) || nrow(trades) == 0L) {
    return(data.frame())
  }
  rows <- list()
  for (i in seq_len(nrow(trades))) {
    tr <- trades[i, , drop = FALSE]
    rows[[length(rows) + 1L]] <- data.frame(
      trade_id = tr$trade_id,
      symbol = tr$symbol,
      event_type = "entry_signal",
      event_date = tr$entry_signal_date,
      event_index = tr$entry_signal_index,
      event_price = tr$entry_signal_price,
      stringsAsFactors = FALSE
    )
    rows[[length(rows) + 1L]] <- data.frame(
      trade_id = tr$trade_id,
      symbol = tr$symbol,
      event_type = "entry_execution",
      event_date = tr$entry_execution_date,
      event_index = tr$entry_execution_index,
      event_price = tr$entry_execution_price,
      stringsAsFactors = FALSE
    )
    if (!is.na(tr$exit_signal_index)) {
      rows[[length(rows) + 1L]] <- data.frame(
        trade_id = tr$trade_id,
        symbol = tr$symbol,
        event_type = "exit_signal",
        event_date = tr$exit_signal_date,
        event_index = tr$exit_signal_index,
        event_price = tr$exit_signal_price,
        stringsAsFactors = FALSE
      )
    }
    if (!is.na(tr$exit_execution_index)) {
      rows[[length(rows) + 1L]] <- data.frame(
        trade_id = tr$trade_id,
        symbol = tr$symbol,
        event_type = "exit_execution",
        event_date = tr$exit_execution_date,
        event_index = tr$exit_execution_index,
        event_price = tr$exit_execution_price,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_ema_cross_time_underwater_summary <- function(drawdown) {
  drawdown <- as.numeric(drawdown)
  is_underwater <- !is.na(drawdown) & drawdown < 0
  if (length(is_underwater) == 0L) {
    return(list(count = 0L, fraction = 0, max_streak = 0L))
  }
  runs <- rle(is_underwater)
  underwater_lengths <- runs$lengths[runs$values]
  list(
    count = sum(is_underwater),
    fraction = sum(is_underwater) / length(is_underwater),
    max_streak = if (length(underwater_lengths) == 0L) 0L else max(underwater_lengths)
  )
}

g5_ema_cross_cagr <- function(start_equity, end_equity, start_date, end_date) {
  elapsed_days <- as.numeric(as.Date(end_date) - as.Date(start_date))
  if (!is.finite(start_equity) || !is.finite(end_equity) || start_equity <= 0 || end_equity <= 0 || elapsed_days <= 0) {
    return(NA_real_)
  }
  (end_equity / start_equity)^(365.25 / elapsed_days) - 1
}

g5_ema_cross_sharpe <- function(equity) {
  equity <- as.numeric(equity)
  if (length(equity) < 2L) {
    return(NA_real_)
  }
  returns <- equity[-1L] / equity[-length(equity)] - 1
  returns <- returns[is.finite(returns)]
  if (length(returns) < 2L || stats::sd(returns) == 0) {
    return(NA_real_)
  }
  sqrt(252) * mean(returns) / stats::sd(returns)
}

g5_ema_cross_equity_curve <- function(trades, bars, symbol, trading_start_date, trading_end_date, leverage = NULL) {
  bars <- g5_ema_cross_prepare_bars(bars, symbol, start_date = trading_start_date, end_date = trading_end_date)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  leverage <- if (!is.null(leverage)) {
    g5_ema_cross_validate_leverage(leverage)
  } else if (is.data.frame(trades) && nrow(trades) > 0L && "leverage" %in% names(trades)) {
    g5_ema_cross_validate_leverage(trades$leverage[[1L]])
  } else {
    1
  }
  convert_idx <- function(idx) {
    match(as.Date(idx), as.Date(bars$session_date))
  }

  n <- nrow(bars)
  strategy_equity <- rep(1, n)
  trade_id <- rep(NA_character_, n)
  in_position <- rep(FALSE, n)
  current_equity <- 1
  next_cash_start <- 1L
  if (is.data.frame(trades) && nrow(trades) > 0L) {
    for (i in seq_len(nrow(trades))) {
      tr <- trades[i, , drop = FALSE]
      entry_idx <- convert_idx(tr$entry_execution_date[[1L]])
      end_date <- if (!is.na(tr$exit_execution_date[[1L]])) tr$exit_execution_date[[1L]] else tr$trace_end_date[[1L]]
      end_idx <- convert_idx(end_date)
      if (is.na(entry_idx) || is.na(end_idx)) {
        next
      }
      if (entry_idx > next_cash_start) {
        strategy_equity[next_cash_start:(entry_idx - 1L)] <- current_equity
      }
      idx <- seq(entry_idx, end_idx)
      entry_price <- as.numeric(tr$entry_execution_price[[1L]])
      close_marks <- as.numeric(bars$close[idx])
      trade_returns <- leverage * ((close_marks / entry_price) - 1)
      if (!is.na(tr$exit_execution_date[[1L]]) && !is.na(tr$realized_return[[1L]])) {
        trade_returns[idx == end_idx] <- as.numeric(tr$realized_return[[1L]])
      }
      strategy_equity[idx] <- current_equity * (1 + trade_returns)
      trade_id[idx] <- tr$trade_id[[1L]]
      in_position[idx] <- idx < end_idx | is.na(tr$exit_execution_date[[1L]])
      current_equity <- strategy_equity[[end_idx]]
      next_cash_start <- end_idx + 1L
    }
  }
  if (next_cash_start <= n) {
    strategy_equity[next_cash_start:n] <- current_equity
  }

  close <- as.numeric(bars$close)
  buy_hold_equity <- close / close[[1L]]
  data.frame(
    schema_version = g5_ema_cross_schema_version(),
    symbol = symbol,
    session_date = as.Date(bars$session_date),
    close = close,
    strategy_equity = strategy_equity,
    strategy_drawdown = strategy_equity / cummax(strategy_equity) - 1,
    buy_hold_equity = buy_hold_equity,
    buy_hold_drawdown = buy_hold_equity / cummax(buy_hold_equity) - 1,
    daily_return = c(NA_real_, strategy_equity[-1L] / strategy_equity[-length(strategy_equity)] - 1),
    in_position = in_position,
    trade_id = trade_id,
    leverage = leverage,
    stringsAsFactors = FALSE
  )
}

g5_ema_cross_metrics <- function(trades, equity_curve, symbol, fast_period, slow_period, leverage) {
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
    schema_version = g5_ema_cross_schema_version(),
    symbol = symbol,
    strategy_id = g5_ema_cross_strategy_id(fast_period, slow_period),
    fast_period = as.integer(fast_period),
    slow_period = as.integer(slow_period),
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

g5_ema_cross_evaluate_grid <- function(
  bars,
  symbol,
  trading_start_date,
  trading_end_date,
  fast_periods = c(8L, 12L, 20L),
  slow_periods = c(30L, 50L, 80L, 120L),
  leverage = 1
) {
  fast_periods <- sort(unique(as.integer(fast_periods)))
  slow_periods <- sort(unique(as.integer(slow_periods)))
  leverage <- g5_ema_cross_validate_leverage(leverage)
  rows <- list()
  details <- list()
  for (fast in fast_periods) {
    for (slow in slow_periods) {
      if (is.na(fast) || is.na(slow) || fast >= slow) {
        next
      }
      trades <- g5_ema_cross_trades(
        bars,
        symbol = symbol,
        fast_period = fast,
        slow_period = slow,
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
      metrics <- g5_ema_cross_metrics(trades, equity_curve, symbol, fast, slow, leverage)
      key <- metrics$strategy_id[[1L]]
      rows[[length(rows) + 1L]] <- metrics
      details[[key]] <- list(trades = trades, equity_curve = equity_curve, metrics = metrics)
    }
  }
  if (length(rows) == 0L) {
    g5_stop("EMA grid resolved zero valid fast/slow parameter pairs.")
  }
  grid <- do.call(rbind, rows)
  grid <- grid[order(
    ifelse(is.na(grid$sharpe), -Inf, grid$sharpe),
    ifelse(is.na(grid$total_return), -Inf, grid$total_return),
    decreasing = TRUE
  ), , drop = FALSE]
  rownames(grid) <- NULL
  selected <- grid[1L, , drop = FALSE]
  list(
    parameter_performance = grid,
    selected = selected,
    selected_detail = details[[selected$strategy_id[[1L]]]]
  )
}

g5_ema_cross_metrics_markdown <- function(metrics, path) {
  if (!is.data.frame(metrics) || nrow(metrics) != 1L) {
    g5_stop("metrics must be a one-row data.frame.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  num <- function(x) ifelse(is.na(x), "NA", ifelse(is.infinite(x), "Inf", sprintf("%.3f", as.numeric(x))))
  lines <- c(
    paste0("# EMA Cross Backtest Metrics: ", metrics$symbol[[1L]]),
    "",
    paste0("- Selected parameters: `fast=", metrics$fast_period[[1L]], ", slow=", metrics$slow_period[[1L]], "`"),
    paste0("- Leverage: `", num(metrics$leverage[[1L]]), "x`"),
    paste0("- Sharpe: `", num(metrics$sharpe[[1L]]), "`"),
    paste0("- Total return: `", pct(metrics$total_return[[1L]]), "`"),
    paste0("- CAGR: `", pct(metrics$cagr[[1L]]), "`"),
    paste0("- Max drawdown: `", pct(metrics$max_drawdown[[1L]]), "`"),
    paste0("- Time underwater: `", metrics$underwater_session_count[[1L]], " sessions / ", pct(metrics$underwater_fraction[[1L]]), "`"),
    paste0("- Trades: `", metrics$trade_count[[1L]], "`"),
    paste0("- Closed trades: `", metrics$closed_trade_count[[1L]], "`"),
    paste0("- Open trades: `", metrics$open_trade_count[[1L]], "`"),
    paste0("- Win rate: `", pct(metrics$win_rate[[1L]]), "`"),
    paste0("- Profit factor: `", num(metrics$profit_factor[[1L]]), "`"),
    paste0("- Buy-and-hold return: `", pct(metrics$buy_hold_total_return[[1L]]), "`"),
    paste0("- Buy-and-hold Sharpe: `", num(metrics$buy_hold_sharpe[[1L]]), "`"),
    "",
    "Diagnostic in-sample backtest only: this is not WFA/OOS evidence or a deployable strategy."
  )
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_plot_ema_cross_overlays <- function(trades, indicators, aesthetic = g5_chart_aesthetic()) {
  x <- seq_len(nrow(indicators))
  graphics::lines(x, indicators$fast_ema, col = aesthetic$native_entry_color, lwd = 1.4)
  graphics::lines(x, indicators$slow_ema, col = aesthetic$non_native_exit_color, lwd = 1.4)
  if (is.data.frame(trades) && nrow(trades) > 0L) {
    line_cols <- ifelse(
      trades$trade_outcome == "win",
      aesthetic$trade_win_line,
      ifelse(trades$trade_outcome == "loss", aesthetic$trade_loss_line, aesthetic$flat_candle)
    )
    graphics::segments(
      x0 = match(trades$entry_execution_date, indicators$session_date),
      y0 = trades$entry_execution_price,
      x1 = match(trades$trace_end_date, indicators$session_date),
      y1 = trades$trace_end_price,
      col = line_cols,
      lty = aesthetic$trade_line_lty,
      lwd = 1.2
    )
    graphics::points(match(trades$entry_signal_date, indicators$session_date), trades$entry_signal_price, pch = aesthetic$entry_signal_pch, col = aesthetic$entry_signal_color, bg = aesthetic$panel_background, cex = 1.1, lwd = 1.4)
    graphics::points(match(trades$entry_execution_date, indicators$session_date), trades$entry_execution_price, pch = aesthetic$native_entry_pch, col = aesthetic$native_entry_color, bg = aesthetic$native_entry_color, cex = 1.05)
    exit_signal_rows <- trades[!is.na(trades$exit_signal_date), , drop = FALSE]
    if (nrow(exit_signal_rows) > 0L) {
      graphics::points(match(exit_signal_rows$exit_signal_date, indicators$session_date), exit_signal_rows$exit_signal_price, pch = aesthetic$exit_signal_pch, col = aesthetic$exit_signal_color, bg = aesthetic$panel_background, cex = 1.1, lwd = 1.4)
    }
    closed_rows <- trades[!is.na(trades$exit_execution_date), , drop = FALSE]
    if (nrow(closed_rows) > 0L) {
      graphics::points(match(closed_rows$exit_execution_date, indicators$session_date), closed_rows$exit_execution_price, pch = aesthetic$native_exit_pch, col = aesthetic$native_exit_color, bg = aesthetic$native_exit_color, cex = 1.05)
    }
  }
  graphics::legend(
    "topleft",
    legend = c("fast EMA", "slow EMA", "entry signal", "entry execution", "exit signal", "exit execution"),
    lty = c(1, 1, NA, NA, NA, NA),
    pch = c(NA, NA, aesthetic$entry_signal_pch, aesthetic$native_entry_pch, aesthetic$exit_signal_pch, aesthetic$native_exit_pch),
    col = c(aesthetic$native_entry_color, aesthetic$non_native_exit_color, aesthetic$entry_signal_color, aesthetic$native_entry_color, aesthetic$exit_signal_color, aesthetic$native_exit_color),
    pt.bg = c(NA, NA, aesthetic$panel_background, aesthetic$native_entry_color, aesthetic$panel_background, aesthetic$native_exit_color),
    bty = "n",
    text.col = aesthetic$text,
    cex = 0.78
  )
  invisible(TRUE)
}

g5_write_ema_cross_chart_png <- function(bars, symbol, trades, fast_period, slow_period, trading_start_date, trading_end_date, path, width = 1400L, height = 820L, title = NULL) {
  indicators <- g5_ema_cross_indicators(
    bars,
    symbol = symbol,
    fast_period = fast_period,
    slow_period = slow_period,
    start_date = trading_start_date,
    end_date = trading_end_date
  )
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  aesthetic <- g5_chart_aesthetic()
  if (is.null(title)) {
    title <- paste(symbol, "EMA Cross Backtest")
  }
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(7.5, 5.2, 4, 2), bg = aesthetic$background, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  g5_draw_candlestick_panel(
    indicators,
    symbol = symbol,
    title = title,
    show_legend = FALSE,
    aesthetic = aesthetic
  )
  g5_plot_ema_cross_overlays(trades, indicators, aesthetic = aesthetic)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_ema_cross_equity_curve_png <- function(equity_curve, symbol, path, width = 1400L, height = 720L, title = NULL) {
  if (!is.data.frame(equity_curve) || nrow(equity_curve) == 0L) {
    g5_stop("equity_curve must be a non-empty data.frame.")
  }
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  aesthetic <- g5_chart_aesthetic()
  if (is.null(title)) {
    title <- paste(symbol, "EMA Cross Equity Curve")
  }
  x <- seq_len(nrow(equity_curve))
  strategy_peak <- cummax(as.numeric(equity_curve$strategy_equity))
  y <- range(c(equity_curve$strategy_equity, strategy_peak, equity_curve$buy_hold_equity), finite = TRUE)
  padding <- diff(y) * 0.08
  if (!is.finite(padding) || padding <= 0) {
    padding <- max(abs(y), 1) * 0.03
  }
  y_limits <- y + c(-padding, padding)
  session_dates <- as.Date(equity_curve$session_date)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(7.5, 5.2, 4, 2), bg = aesthetic$background, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::plot(x = c(0.5, length(x) + 0.5), y = y_limits, type = "n", xaxt = "n", xlab = "Session date", ylab = "Equity, starting at 1.0", main = title, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  underwater <- equity_curve$strategy_equity < strategy_peak
  if (any(underwater, na.rm = TRUE)) {
    runs <- rle(underwater)
    run_ends <- cumsum(runs$lengths)
    run_starts <- run_ends - runs$lengths + 1L
    for (i in seq_along(runs$values)) {
      if (!isTRUE(runs$values[[i]])) {
        next
      }
      idx <- seq(run_starts[[i]], run_ends[[i]])
      peak_level <- strategy_peak[[idx[[1L]]]]
      segment_start <- max(1L, idx[[1L]] - 1L)
      segment_end <- idx[[length(idx)]]
      segment_end_x <- x[[segment_end]]
      if (segment_end < length(x) && !isTRUE(underwater[[segment_end + 1L]])) {
        y0 <- as.numeric(equity_curve$strategy_equity[[segment_end]])
        y1 <- as.numeric(equity_curve$strategy_equity[[segment_end + 1L]])
        if (is.finite(y0) && is.finite(y1) && y1 != y0) {
          crossing_fraction <- (peak_level - y0) / (y1 - y0)
          crossing_fraction <- max(0, min(1, crossing_fraction))
          segment_end_x <- x[[segment_end]] + crossing_fraction * (x[[segment_end + 1L]] - x[[segment_end]])
        } else {
          segment_end_x <- x[[segment_end + 1L]]
        }
      }
      graphics::segments(
        x0 = x[[segment_start]],
        y0 = peak_level,
        x1 = segment_end_x,
        y1 = peak_level,
        col = grDevices::adjustcolor(aesthetic$down_candle, alpha.f = 0.42),
        lwd = 2.4,
        lend = "round"
      )
    }
  }
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  graphics::abline(h = 1, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.35), lty = 3)
  graphics::lines(x, equity_curve$buy_hold_equity, col = "#000000", lwd = 1.8)
  graphics::lines(x, equity_curve$strategy_equity, col = aesthetic$trade_win_line, lwd = 2.2)
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(8L, length(x)))))
  g5_axis_date_labels_45(tick_positions, as.character(session_dates[tick_positions]), color = aesthetic$axis)
  graphics::legend(
    "topleft",
    legend = c("strategy", "buy and hold", "drawdown shelf"),
    lty = c(1, 1, 1),
    lwd = c(2.2, 1.8, 2.4),
    col = c(aesthetic$trade_win_line, "#000000", grDevices::adjustcolor(aesthetic$down_candle, alpha.f = 0.42)),
    bty = "n",
    text.col = aesthetic$text,
    cex = 0.9
  )
  graphics::mtext(
    paste(
      "Rows:",
      nrow(equity_curve),
      "|",
      as.character(min(session_dates)),
      "to",
      as.character(max(session_dates)),
      "| leverage:",
      paste0(unique(equity_curve$leverage)[[1L]], "x")
    ),
    side = 3,
    line = 0.3,
    cex = 0.85,
    col = aesthetic$text
  )
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_ema_cross_outputs <- function(
  result,
  symbol,
  output_dir,
  trading_start_date,
  trading_end_date,
  fast_periods,
  slow_periods,
  leverage = 1
) {
  symbol <- g5_standardize_symbol(symbol)
  leverage <- g5_ema_cross_validate_leverage(leverage)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  prefix <- g5_ema_cross_artifact_prefix(result$resolved_session$as_of_timestamp, symbol, leverage = leverage)
  written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
  evaluation <- g5_ema_cross_evaluate_grid(
    result$bars,
    symbol = symbol,
    trading_start_date = trading_start_date,
    trading_end_date = trading_end_date,
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    leverage = leverage
  )
  selected <- evaluation$selected
  selected_trades <- evaluation$selected_detail$trades
  selected_events <- g5_ema_cross_chart_events(selected_trades)
  selected_equity <- evaluation$selected_detail$equity_curve
  selected_metrics <- evaluation$selected_detail$metrics
  selected_indicators <- g5_ema_cross_indicators(
    result$bars,
    symbol = symbol,
    fast_period = selected$fast_period[[1L]],
    slow_period = selected$slow_period[[1L]],
    start_date = trading_start_date,
    end_date = trading_end_date
  )

  paths <- c(
    written$paths,
    list(
      parameter_performance_csv = file.path(output_dir, paste0(prefix, "_parameter_performance.csv")),
      selected_indicators_csv = file.path(output_dir, paste0(prefix, "_selected_indicators.csv")),
      selected_trades_csv = file.path(output_dir, paste0(prefix, "_selected_trades.csv")),
      selected_chart_events_csv = file.path(output_dir, paste0(prefix, "_selected_chart_events.csv")),
      selected_equity_curve_csv = file.path(output_dir, paste0(prefix, "_selected_equity_curve.csv")),
      selected_metrics_csv = file.path(output_dir, paste0(prefix, "_selected_metrics.csv")),
      selected_metrics_md = file.path(output_dir, paste0(prefix, "_selected_metrics.md")),
      selected_strategy_chart_png = file.path(output_dir, paste0(prefix, "_selected_strategy_chart.png")),
      selected_equity_curve_png = file.path(output_dir, paste0(prefix, "_selected_equity_curve.png"))
    )
  )
  utils::write.csv(evaluation$parameter_performance, paths$parameter_performance_csv, row.names = FALSE)
  utils::write.csv(selected_indicators, paths$selected_indicators_csv, row.names = FALSE)
  utils::write.csv(selected_trades, paths$selected_trades_csv, row.names = FALSE)
  utils::write.csv(selected_events, paths$selected_chart_events_csv, row.names = FALSE)
  utils::write.csv(selected_equity, paths$selected_equity_curve_csv, row.names = FALSE)
  utils::write.csv(selected_metrics, paths$selected_metrics_csv, row.names = FALSE)
  g5_ema_cross_metrics_markdown(selected_metrics, paths$selected_metrics_md)
  g5_write_ema_cross_chart_png(
    result$bars,
    symbol = symbol,
    trades = selected_trades,
    fast_period = selected$fast_period[[1L]],
    slow_period = selected$slow_period[[1L]],
    trading_start_date = trading_start_date,
    trading_end_date = trading_end_date,
    path = paths$selected_strategy_chart_png
  )
  g5_write_ema_cross_equity_curve_png(
    selected_equity,
    symbol = symbol,
    path = paths$selected_equity_curve_png,
    title = paste(symbol, "EMA Cross Equity Curve")
  )
  paths <- lapply(paths, normalizePath, winslash = "/", mustWork = FALSE)
  list(
    paths = paths,
    parameter_performance = evaluation$parameter_performance,
    selected = selected,
    selected_trades = selected_trades,
    selected_events = selected_events,
    selected_indicators = selected_indicators,
    selected_equity_curve = selected_equity,
    selected_metrics = selected_metrics,
    manifest = written$manifest
  )
}
