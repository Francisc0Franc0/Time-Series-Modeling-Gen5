# Gen5.1 diagnostic green-day hold strategy.

g5_green_day_hold_schema_version <- function() {
  "gen5_green_day_hold_v0.1"
}

g5_green_day_hold_strategy_id <- function(hold_sessions) {
  hold_sessions <- as.integer(hold_sessions)
  if (is.na(hold_sessions) || hold_sessions < 1L) {
    g5_stop("hold_sessions must be a positive integer.")
  }
  paste0("green_day_hold_next_open_", hold_sessions, "d")
}

g5_green_day_hold_validate_leverage <- function(leverage) {
  leverage <- as.numeric(leverage)
  if (length(leverage) != 1L || is.na(leverage) || !is.finite(leverage) || leverage <= 0) {
    g5_stop("leverage must be a positive finite number.")
  }
  leverage
}

g5_green_day_hold_leverage_label <- function(leverage) {
  leverage <- g5_green_day_hold_validate_leverage(leverage)
  label <- sub("\\.?0+$", "", format(leverage, trim = TRUE, scientific = FALSE))
  paste0("lev", gsub("[^0-9A-Za-z]+", "_", label), "x")
}

g5_green_day_hold_artifact_prefix <- function(as_of_timestamp, symbol, hold_sessions, leverage = 1) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  paste("green_day_hold", symbol, paste0(hold_sessions, "sessions"), g5_green_day_hold_leverage_label(leverage), stamp, sep = "_")
}

g5_green_day_hold_output_dir <- function(repo_root, as_of_timestamp, symbol, hold_sessions, leverage = 1) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "strategy_demos",
    g5_green_day_hold_artifact_prefix(as_of_timestamp, symbol, hold_sessions, leverage = leverage)
  )
}

g5_green_day_hold_prepare_bars <- function(bars, symbol) {
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("Green-day hold strategy requires exactly one symbol.")
  }
  bars <- g5_validate_bar_data(bars)
  bars <- bars[bars$symbol == symbol, , drop = FALSE]
  if (nrow(bars) < 2L) {
    g5_stop("Green-day hold strategy requires at least two canonical bars.")
  }
  bars <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  rownames(bars) <- NULL
  bars
}

g5_green_day_hold_trades <- function(bars, symbol, hold_sessions = 10L, leverage = 1) {
  hold_sessions <- as.integer(hold_sessions)
  if (is.na(hold_sessions) || hold_sessions < 1L) {
    g5_stop("hold_sessions must be a positive integer.")
  }
  leverage <- g5_green_day_hold_validate_leverage(leverage)
  strategy_id <- g5_green_day_hold_strategy_id(hold_sessions)
  bars <- g5_green_day_hold_prepare_bars(bars, symbol)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  n <- nrow(bars)
  latest_idx <- n

  trades <- list()
  trade_no <- 0L
  i <- 1L
  while (i < n) {
    is_green <- as.numeric(bars$close[[i]]) > as.numeric(bars$open[[i]])
    if (!is_green) {
      i <- i + 1L
      next
    }

    entry_signal_idx <- i
    entry_execution_idx <- i + 1L
    if (entry_execution_idx > n) {
      break
    }

    exit_signal_idx <- entry_execution_idx + hold_sessions - 1L
    exit_execution_idx <- exit_signal_idx + 1L
    has_exit_signal <- exit_signal_idx <= n
    is_closed <- exit_execution_idx <= n
    trade_status <- if (is_closed) {
      "closed"
    } else if (has_exit_signal) {
      "open_exit_signal_pending_next_open"
    } else {
      "open_holding_period_incomplete"
    }

    entry_price <- as.numeric(bars$open[[entry_execution_idx]])
    exit_price <- if (is_closed) as.numeric(bars$open[[exit_execution_idx]]) else NA_real_
    latest_close <- as.numeric(bars$close[[latest_idx]])
    underlying_realized_return <- if (is_closed) (exit_price / entry_price) - 1 else NA_real_
    underlying_unrealized_return <- if (!is_closed) (latest_close / entry_price) - 1 else NA_real_
    realized_return <- if (is_closed) leverage * underlying_realized_return else NA_real_
    unrealized_return <- if (!is_closed) leverage * underlying_unrealized_return else NA_real_
    trace_end_idx <- if (is_closed) exit_execution_idx else latest_idx
    trace_end_price <- if (is_closed) exit_price else latest_close
    trade_return_for_trace <- if (is_closed) realized_return else unrealized_return

    trade_no <- trade_no + 1L
    trades[[trade_no]] <- data.frame(
      schema_version = g5_green_day_hold_schema_version(),
      trade_id = sprintf("%s_green_day_hold_%03d", symbol, trade_no),
      symbol = symbol,
      strategy_id = strategy_id,
      hold_sessions = hold_sessions,
      trade_status = trade_status,
      entry_signal_date = as.Date(bars$session_date[[entry_signal_idx]]),
      entry_signal_index = entry_signal_idx,
      entry_signal_price = as.numeric(bars$close[[entry_signal_idx]]),
      entry_execution_date = as.Date(bars$session_date[[entry_execution_idx]]),
      entry_execution_index = entry_execution_idx,
      entry_execution_price = entry_price,
      exit_signal_date = if (has_exit_signal) as.Date(bars$session_date[[exit_signal_idx]]) else as.Date(NA),
      exit_signal_index = if (has_exit_signal) exit_signal_idx else NA_integer_,
      exit_signal_price = if (has_exit_signal) as.numeric(bars$close[[exit_signal_idx]]) else NA_real_,
      exit_execution_date = if (is_closed) as.Date(bars$session_date[[exit_execution_idx]]) else as.Date(NA),
      exit_execution_index = if (is_closed) exit_execution_idx else NA_integer_,
      exit_execution_price = exit_price,
      latest_mark_date = as.Date(bars$session_date[[latest_idx]]),
      latest_mark_price = latest_close,
      trace_end_date = as.Date(bars$session_date[[trace_end_idx]]),
      trace_end_index = trace_end_idx,
      trace_end_price = trace_end_price,
      underlying_realized_return = underlying_realized_return,
      underlying_unrealized_return = underlying_unrealized_return,
      realized_return = realized_return,
      unrealized_return = unrealized_return,
      trace_return = trade_return_for_trace,
      trade_outcome = if (is.na(trade_return_for_trace)) "unknown" else if (trade_return_for_trace > 0) "win" else if (trade_return_for_trace < 0) "loss" else "flat",
      holding_sessions_completed = if (is_closed) hold_sessions else max(0L, latest_idx - entry_execution_idx + 1L),
      signal_rule = "close_gt_open_when_flat",
      entry_execution_rule = "next_session_open_after_entry_signal",
      exit_signal_rule = "close_after_hold_sessions_elapsed",
      exit_execution_rule = "next_session_open_after_exit_signal",
      leverage = leverage,
      capital_fraction = 1,
      stringsAsFactors = FALSE
    )

    if (is_closed) {
      i <- exit_execution_idx
    } else {
      break
    }
  }

  if (length(trades) == 0L) {
    return(data.frame())
  }
  out <- do.call(rbind, trades)
  rownames(out) <- NULL
  out
}

g5_green_day_hold_chart_events <- function(trades) {
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

g5_time_underwater_summary <- function(drawdown) {
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

g5_path_cagr <- function(start_equity, end_equity, start_date, end_date) {
  start_equity <- as.numeric(start_equity)
  end_equity <- as.numeric(end_equity)
  elapsed_days <- as.numeric(as.Date(end_date) - as.Date(start_date))
  if (!is.finite(start_equity) || !is.finite(end_equity) || start_equity <= 0 || end_equity <= 0 || elapsed_days <= 0) {
    return(NA_real_)
  }
  (end_equity / start_equity)^(365.25 / elapsed_days) - 1
}

g5_green_day_hold_equity_curve <- function(trades, bars, symbol, leverage = NULL) {
  bars <- g5_green_day_hold_prepare_bars(bars, symbol)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  leverage <- if (!is.null(leverage)) {
    g5_green_day_hold_validate_leverage(leverage)
  } else if (is.data.frame(trades) && nrow(trades) > 0L && "leverage" %in% names(trades)) {
    g5_green_day_hold_validate_leverage(trades$leverage[[1L]])
  } else {
    1
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
      entry_idx <- as.integer(tr$entry_execution_index[[1L]])
      end_idx <- as.integer(tr$trace_end_index[[1L]])
      if (is.na(entry_idx) || is.na(end_idx) || entry_idx > n) {
        next
      }
      end_idx <- min(end_idx, n)
      if (entry_idx > next_cash_start) {
        strategy_equity[next_cash_start:(entry_idx - 1L)] <- current_equity
      }
      idx <- seq(entry_idx, end_idx)
      entry_price <- as.numeric(tr$entry_execution_price[[1L]])
      close_marks <- as.numeric(bars$close[idx])
      trade_returns <- leverage * ((close_marks / entry_price) - 1)
      if (!is.na(tr$exit_execution_index[[1L]])) {
        exit_idx <- as.integer(tr$exit_execution_index[[1L]])
        if (exit_idx %in% idx) {
          trade_returns[idx == exit_idx] <- as.numeric(tr$realized_return[[1L]])
        }
      }
      strategy_equity[idx] <- current_equity * (1 + trade_returns)
      trade_id[idx] <- tr$trade_id[[1L]]
      in_position[idx] <- idx < as.integer(tr$exit_execution_index[[1L]]) | is.na(tr$exit_execution_index[[1L]])
      current_equity <- strategy_equity[[end_idx]]
      next_cash_start <- end_idx + 1L
    }
  }
  if (next_cash_start <= n) {
    strategy_equity[next_cash_start:n] <- current_equity
  }

  close <- as.numeric(bars$close)
  buy_hold_equity <- close / close[[1L]]
  strategy_peak <- cummax(strategy_equity)
  buy_hold_peak <- cummax(buy_hold_equity)
  data.frame(
    schema_version = g5_green_day_hold_schema_version(),
    symbol = symbol,
    session_date = as.Date(bars$session_date),
    close = close,
    strategy_equity = strategy_equity,
    strategy_drawdown = strategy_equity / strategy_peak - 1,
    buy_hold_equity = buy_hold_equity,
    buy_hold_drawdown = buy_hold_equity / buy_hold_peak - 1,
    in_position = in_position,
    trade_id = trade_id,
    leverage = leverage,
    stringsAsFactors = FALSE
  )
}

g5_green_day_hold_metrics <- function(trades, bars, symbol, equity_curve = NULL) {
  bars <- g5_green_day_hold_prepare_bars(bars, symbol)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  hold_sessions <- if (is.data.frame(trades) && nrow(trades) > 0L && "hold_sessions" %in% names(trades)) {
    as.integer(trades$hold_sessions[[1L]])
  } else {
    10L
  }
  leverage <- if (is.data.frame(trades) && nrow(trades) > 0L && "leverage" %in% names(trades)) {
    g5_green_day_hold_validate_leverage(trades$leverage[[1L]])
  } else if (!is.null(equity_curve) && is.data.frame(equity_curve) && nrow(equity_curve) > 0L && "leverage" %in% names(equity_curve)) {
    g5_green_day_hold_validate_leverage(equity_curve$leverage[[1L]])
  } else {
    1
  }
  strategy_id <- g5_green_day_hold_strategy_id(hold_sessions)
  if (is.null(equity_curve)) {
    equity_curve <- g5_green_day_hold_equity_curve(trades, bars, symbol = symbol, leverage = leverage)
  }
  strategy_underwater <- g5_time_underwater_summary(equity_curve$strategy_drawdown)
  buy_hold_underwater <- g5_time_underwater_summary(equity_curve$buy_hold_drawdown)
  start_date <- min(equity_curve$session_date)
  end_date <- max(equity_curve$session_date)
  strategy_end_equity <- tail(equity_curve$strategy_equity, 1L)
  buy_hold_end_equity <- tail(equity_curve$buy_hold_equity, 1L)
  if (!is.data.frame(trades) || nrow(trades) == 0L) {
    return(data.frame(
      schema_version = g5_green_day_hold_schema_version(),
      symbol = symbol,
      strategy_id = strategy_id,
      leverage = leverage,
      trade_count = 0L,
      closed_trade_count = 0L,
      open_trade_count = 0L,
      win_count = 0L,
      loss_count = 0L,
      flat_count = 0L,
      win_rate = NA_real_,
      compounded_closed_return = 0,
      compounded_marked_return = 0,
      average_trade_return = NA_real_,
      median_trade_return = NA_real_,
      best_trade_return = NA_real_,
      worst_trade_return = NA_real_,
      average_win_return = NA_real_,
      average_loss_return = NA_real_,
      gross_profit_return = 0,
      gross_loss_return = 0,
      profit_factor = NA_real_,
      expectancy_return = NA_real_,
      average_holding_sessions = NA_real_,
      exposure_fraction = 0,
      max_closed_trade_drawdown = 0,
      ending_equity = strategy_end_equity,
      total_return = strategy_end_equity - 1,
      cagr = g5_path_cagr(1, strategy_end_equity, start_date, end_date),
      max_drawdown = min(equity_curve$strategy_drawdown, na.rm = TRUE),
      underwater_session_count = strategy_underwater$count,
      underwater_fraction = strategy_underwater$fraction,
      max_underwater_streak = strategy_underwater$max_streak,
      buy_hold_ending_equity = buy_hold_end_equity,
      buy_hold_total_return = buy_hold_end_equity - 1,
      buy_hold_cagr = g5_path_cagr(1, buy_hold_end_equity, start_date, end_date),
      buy_hold_max_drawdown = min(equity_curve$buy_hold_drawdown, na.rm = TRUE),
      buy_hold_underwater_session_count = buy_hold_underwater$count,
      buy_hold_underwater_fraction = buy_hold_underwater$fraction,
      buy_hold_max_underwater_streak = buy_hold_underwater$max_streak,
      stringsAsFactors = FALSE
    ))
  }

  closed <- trades[trades$trade_status == "closed", , drop = FALSE]
  open_trades <- trades[trades$trade_status != "closed", , drop = FALSE]
  closed_returns <- as.numeric(closed$realized_return)
  marked_returns <- ifelse(trades$trade_status == "closed", trades$realized_return, trades$unrealized_return)
  marked_returns <- as.numeric(marked_returns)
  wins <- closed_returns[closed_returns > 0]
  losses <- closed_returns[closed_returns < 0]
  flats <- closed_returns[closed_returns == 0]
  equity <- if (length(closed_returns) == 0L) 1 else cumprod(1 + closed_returns)
  equity_peak <- cummax(c(1, equity))
  equity_path <- c(1, equity)
  drawdowns <- equity_path / equity_peak - 1
  exposure_sessions <- sum(as.integer(trades$holding_sessions_completed), na.rm = TRUE)

  data.frame(
    schema_version = g5_green_day_hold_schema_version(),
    symbol = symbol,
    strategy_id = strategy_id,
    leverage = leverage,
    trade_count = nrow(trades),
    closed_trade_count = nrow(closed),
    open_trade_count = nrow(open_trades),
    win_count = length(wins),
    loss_count = length(losses),
    flat_count = length(flats),
    win_rate = if (length(closed_returns) == 0L) NA_real_ else length(wins) / length(closed_returns),
    compounded_closed_return = if (length(closed_returns) == 0L) 0 else prod(1 + closed_returns) - 1,
    compounded_marked_return = if (length(marked_returns) == 0L) 0 else prod(1 + marked_returns) - 1,
    average_trade_return = if (length(closed_returns) == 0L) NA_real_ else mean(closed_returns),
    median_trade_return = if (length(closed_returns) == 0L) NA_real_ else stats::median(closed_returns),
    best_trade_return = if (length(closed_returns) == 0L) NA_real_ else max(closed_returns),
    worst_trade_return = if (length(closed_returns) == 0L) NA_real_ else min(closed_returns),
    average_win_return = if (length(wins) == 0L) NA_real_ else mean(wins),
    average_loss_return = if (length(losses) == 0L) NA_real_ else mean(losses),
    gross_profit_return = if (length(wins) == 0L) 0 else sum(wins),
    gross_loss_return = if (length(losses) == 0L) 0 else sum(losses),
    profit_factor = if (length(closed_returns) == 0L) {
      NA_real_
    } else if (length(losses) == 0L) {
      if (length(wins) == 0L) NA_real_ else Inf
    } else {
      sum(wins) / abs(sum(losses))
    },
    expectancy_return = if (length(closed_returns) == 0L) NA_real_ else mean(closed_returns),
    average_holding_sessions = mean(as.integer(trades$holding_sessions_completed), na.rm = TRUE),
    exposure_fraction = exposure_sessions / nrow(bars),
    max_closed_trade_drawdown = min(drawdowns, na.rm = TRUE),
    ending_equity = strategy_end_equity,
    total_return = strategy_end_equity - 1,
    cagr = g5_path_cagr(1, strategy_end_equity, start_date, end_date),
    max_drawdown = min(equity_curve$strategy_drawdown, na.rm = TRUE),
    underwater_session_count = strategy_underwater$count,
    underwater_fraction = strategy_underwater$fraction,
    max_underwater_streak = strategy_underwater$max_streak,
    buy_hold_ending_equity = buy_hold_end_equity,
    buy_hold_total_return = buy_hold_end_equity - 1,
    buy_hold_cagr = g5_path_cagr(1, buy_hold_end_equity, start_date, end_date),
    buy_hold_max_drawdown = min(equity_curve$buy_hold_drawdown, na.rm = TRUE),
    buy_hold_underwater_session_count = buy_hold_underwater$count,
    buy_hold_underwater_fraction = buy_hold_underwater$fraction,
    buy_hold_max_underwater_streak = buy_hold_underwater$max_streak,
    stringsAsFactors = FALSE
  )
}

g5_green_day_hold_metrics_markdown <- function(metrics, path) {
  if (!is.data.frame(metrics) || nrow(metrics) != 1L) {
    g5_stop("metrics must be a one-row data.frame.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  num <- function(x) ifelse(is.na(x), "NA", ifelse(is.infinite(x), "Inf", sprintf("%.3f", as.numeric(x))))
  lines <- c(
    paste0("# Green-Day Hold Strategy Metrics: ", metrics$symbol[[1L]]),
    "",
    paste0("- Leverage: `", num(metrics$leverage[[1L]]), "x`"),
    paste0("- Trades: `", metrics$trade_count[[1L]], "`"),
    paste0("- Closed trades: `", metrics$closed_trade_count[[1L]], "`"),
    paste0("- Open trades: `", metrics$open_trade_count[[1L]], "`"),
    paste0("- Win rate: `", pct(metrics$win_rate[[1L]]), "`"),
    paste0("- Compounded closed return: `", pct(metrics$compounded_closed_return[[1L]]), "`"),
    paste0("- Compounded marked return: `", pct(metrics$compounded_marked_return[[1L]]), "`"),
    paste0("- CAGR: `", pct(metrics$cagr[[1L]]), "`"),
    paste0("- Max drawdown: `", pct(metrics$max_drawdown[[1L]]), "`"),
    paste0("- Time underwater: `", metrics$underwater_session_count[[1L]], " sessions / ", pct(metrics$underwater_fraction[[1L]]), "`"),
    paste0("- Max underwater streak: `", metrics$max_underwater_streak[[1L]], " sessions`"),
    paste0("- Average trade return: `", pct(metrics$average_trade_return[[1L]]), "`"),
    paste0("- Best trade return: `", pct(metrics$best_trade_return[[1L]]), "`"),
    paste0("- Worst trade return: `", pct(metrics$worst_trade_return[[1L]]), "`"),
    paste0("- Profit factor: `", num(metrics$profit_factor[[1L]]), "`"),
    paste0("- Exposure fraction: `", pct(metrics$exposure_fraction[[1L]]), "`"),
    paste0("- Max closed-trade drawdown: `", pct(metrics$max_closed_trade_drawdown[[1L]]), "`"),
    paste0("- Buy-and-hold return: `", pct(metrics$buy_hold_total_return[[1L]]), "`"),
    paste0("- Buy-and-hold CAGR: `", pct(metrics$buy_hold_cagr[[1L]]), "`"),
    paste0("- Buy-and-hold max drawdown: `", pct(metrics$buy_hold_max_drawdown[[1L]]), "`"),
    paste0("- Buy-and-hold time underwater: `", metrics$buy_hold_underwater_session_count[[1L]], " sessions / ", pct(metrics$buy_hold_underwater_fraction[[1L]]), "`"),
    "",
    "Diagnostic only: this is not a performance claim or deployable strategy."
  )
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_green_day_hold_equity_curve_png <- function(
  equity_curve,
  symbol,
  path,
  width = 1400L,
  height = 720L,
  title = NULL
) {
  if (!is.data.frame(equity_curve) || nrow(equity_curve) == 0L) {
    g5_stop("equity_curve must be a non-empty data.frame.")
  }
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  aesthetic <- g5_chart_aesthetic()
  if (is.null(title)) {
    title <- paste(symbol, "Green-Day Hold Equity Curve")
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
  graphics::par(
    mar = c(7.5, 5.2, 4, 2),
    bg = aesthetic$background,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text,
    fg = aesthetic$axis
  )
  graphics::plot(
    x = c(0.5, length(x) + 0.5),
    y = y_limits,
    type = "n",
    xaxt = "n",
    xlab = "Session date",
    ylab = "Equity, starting at 1.0",
    main = title,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text,
    fg = aesthetic$axis
  )
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
      if (segment_end < length(x) && !isTRUE(underwater[[segment_end + 1L]])) {
        segment_end <- segment_end + 1L
      }
      graphics::segments(
        x0 = x[[segment_start]],
        y0 = peak_level,
        x1 = x[[segment_end]],
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

  tick_count <- min(8L, length(x))
  tick_positions <- unique(round(seq(1L, length(x), length.out = tick_count)))
  g5_axis_date_labels_45(
    positions = tick_positions,
    labels = as.character(session_dates[tick_positions]),
    color = aesthetic$axis
  )
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

g5_write_green_day_hold_outputs <- function(result, symbol, output_dir, hold_sessions = 10L, leverage = 1) {
  if (!is.list(result)) {
    g5_stop("result must be a workbench query result list.")
  }
  if (!nzchar(output_dir)) {
    g5_stop("output_dir must be non-empty.")
  }
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("Green-day hold output writing requires exactly one symbol.")
  }
  hold_sessions <- as.integer(hold_sessions)
  if (is.na(hold_sessions) || hold_sessions < 1L) {
    g5_stop("hold_sessions must be a positive integer.")
  }
  leverage <- g5_green_day_hold_validate_leverage(leverage)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  prefix <- g5_green_day_hold_artifact_prefix(result$resolved_session$as_of_timestamp, symbol, hold_sessions, leverage = leverage)
  written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
  trades <- g5_green_day_hold_trades(result$bars, symbol = symbol, hold_sessions = hold_sessions, leverage = leverage)
  events <- g5_green_day_hold_chart_events(trades)
  equity_curve <- g5_green_day_hold_equity_curve(trades, result$bars, symbol = symbol, leverage = leverage)
  metrics <- g5_green_day_hold_metrics(trades, result$bars, symbol = symbol, equity_curve = equity_curve)

  paths <- c(
    written$paths,
    list(
      trades_csv = file.path(output_dir, paste0(prefix, "_trades.csv")),
      chart_events_csv = file.path(output_dir, paste0(prefix, "_chart_events.csv")),
      equity_curve_csv = file.path(output_dir, paste0(prefix, "_equity_curve.csv")),
      metrics_csv = file.path(output_dir, paste0(prefix, "_metrics.csv")),
      metrics_md = file.path(output_dir, paste0(prefix, "_metrics.md")),
      strategy_chart_png = file.path(output_dir, paste0(prefix, "_strategy_chart.png")),
      equity_curve_png = file.path(output_dir, paste0(prefix, "_equity_curve.png"))
    )
  )

  utils::write.csv(trades, paths$trades_csv, row.names = FALSE)
  utils::write.csv(events, paths$chart_events_csv, row.names = FALSE)
  utils::write.csv(equity_curve, paths$equity_curve_csv, row.names = FALSE)
  utils::write.csv(metrics, paths$metrics_csv, row.names = FALSE)
  g5_green_day_hold_metrics_markdown(metrics, paths$metrics_md)
  g5_write_green_day_hold_chart_png(
    result$bars,
    symbol = symbol,
    trades = trades,
    path = paths$strategy_chart_png,
    start_date = result$date_range$fetch_start_date,
    end_date = result$date_range$fetch_end_date,
    title = paste(symbol, "Green-Day Hold Diagnostic")
  )
  g5_write_green_day_hold_equity_curve_png(
    equity_curve,
    symbol = symbol,
    path = paths$equity_curve_png,
    title = paste(symbol, "Green-Day Hold Equity Curve")
  )

  paths <- lapply(paths, normalizePath, winslash = "/", mustWork = FALSE)
  list(
    paths = paths,
    trades = trades,
    chart_events = events,
    equity_curve = equity_curve,
    metrics = metrics,
    manifest = written$manifest
  )
}

g5_plot_green_day_hold_overlays <- function(trades, aesthetic = g5_chart_aesthetic()) {
  if (!is.data.frame(trades) || nrow(trades) == 0L) {
    return(invisible(FALSE))
  }
  line_cols <- ifelse(
    trades$trade_outcome == "win",
    aesthetic$trade_win_line,
    ifelse(trades$trade_outcome == "loss", aesthetic$trade_loss_line, aesthetic$flat_candle)
  )
  graphics::segments(
    x0 = trades$entry_execution_index,
    y0 = trades$entry_execution_price,
    x1 = trades$trace_end_index,
    y1 = trades$trace_end_price,
    col = line_cols,
    lty = aesthetic$trade_line_lty,
    lwd = 1.5
  )

  graphics::points(
    trades$entry_signal_index,
    trades$entry_signal_price,
    pch = aesthetic$entry_signal_pch,
    col = aesthetic$entry_signal_color,
    bg = aesthetic$panel_background,
    cex = 1.2,
    lwd = 1.6
  )
  graphics::points(
    trades$entry_execution_index,
    trades$entry_execution_price,
    pch = aesthetic$native_entry_pch,
    col = aesthetic$native_entry_color,
    bg = aesthetic$native_entry_color,
    cex = 1.15
  )

  exit_signal_rows <- trades[!is.na(trades$exit_signal_index), , drop = FALSE]
  if (nrow(exit_signal_rows) > 0L) {
    graphics::points(
      exit_signal_rows$exit_signal_index,
      exit_signal_rows$exit_signal_price,
      pch = aesthetic$exit_signal_pch,
      col = aesthetic$exit_signal_color,
      bg = aesthetic$panel_background,
      cex = 1.2,
      lwd = 1.6
    )
  }

  closed_rows <- trades[!is.na(trades$exit_execution_index), , drop = FALSE]
  if (nrow(closed_rows) > 0L) {
    graphics::points(
      closed_rows$exit_execution_index,
      closed_rows$exit_execution_price,
      pch = aesthetic$native_exit_pch,
      col = aesthetic$native_exit_color,
      bg = aesthetic$native_exit_color,
      cex = 1.15
    )
  }

  graphics::legend(
    "topleft",
    legend = c("entry signal", "entry execution", "exit signal", "exit execution", "win link", "loss link"),
    pch = c(aesthetic$entry_signal_pch, aesthetic$native_entry_pch, aesthetic$exit_signal_pch, aesthetic$native_exit_pch, NA, NA),
    lty = c(NA, NA, NA, NA, aesthetic$trade_line_lty, aesthetic$trade_line_lty),
    col = c(
      aesthetic$entry_signal_color,
      aesthetic$native_entry_color,
      aesthetic$exit_signal_color,
      aesthetic$native_exit_color,
      aesthetic$trade_win_line,
      aesthetic$trade_loss_line
    ),
    pt.bg = c(aesthetic$panel_background, aesthetic$native_entry_color, aesthetic$panel_background, aesthetic$native_exit_color, NA, NA),
    bty = "n",
    text.col = aesthetic$text,
    cex = 0.8
  )

  invisible(TRUE)
}

g5_write_green_day_hold_chart_png <- function(
  bars,
  symbol,
  trades,
  path,
  start_date = NULL,
  end_date = NULL,
  width = 1400L,
  height = 820L,
  title = NULL
) {
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  symbol <- g5_standardize_symbol(symbol)
  prepared <- g5_prepare_candlestick_bars(
    bars,
    symbol = symbol,
    start_date = start_date,
    end_date = end_date
  )
  aesthetic <- g5_chart_aesthetic()
  if (is.null(title)) {
    title <- paste(symbol, "Green-Day Hold Diagnostic")
  }

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(
    mar = c(7.5, 5.2, 4, 2),
    bg = aesthetic$background,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text,
    fg = aesthetic$axis
  )
  g5_draw_candlestick_panel(
    prepared,
    symbol = symbol,
    title = title,
    show_legend = FALSE,
    aesthetic = aesthetic
  )
  g5_plot_green_day_hold_overlays(trades, aesthetic = aesthetic)

  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
