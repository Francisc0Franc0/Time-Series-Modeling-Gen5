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

g5_green_day_hold_artifact_prefix <- function(as_of_timestamp, symbol, hold_sessions) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  paste("green_day_hold", symbol, paste0(hold_sessions, "sessions"), stamp, sep = "_")
}

g5_green_day_hold_output_dir <- function(repo_root, as_of_timestamp, symbol, hold_sessions) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "strategy_demos",
    g5_green_day_hold_artifact_prefix(as_of_timestamp, symbol, hold_sessions)
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

g5_green_day_hold_trades <- function(bars, symbol, hold_sessions = 10L) {
  hold_sessions <- as.integer(hold_sessions)
  if (is.na(hold_sessions) || hold_sessions < 1L) {
    g5_stop("hold_sessions must be a positive integer.")
  }
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
    realized_return <- if (is_closed) (exit_price / entry_price) - 1 else NA_real_
    unrealized_return <- if (!is_closed) (latest_close / entry_price) - 1 else NA_real_
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
      realized_return = realized_return,
      unrealized_return = unrealized_return,
      trace_return = trade_return_for_trace,
      trade_outcome = if (is.na(trade_return_for_trace)) "unknown" else if (trade_return_for_trace > 0) "win" else if (trade_return_for_trace < 0) "loss" else "flat",
      holding_sessions_completed = if (is_closed) hold_sessions else max(0L, latest_idx - entry_execution_idx + 1L),
      signal_rule = "close_gt_open_when_flat",
      entry_execution_rule = "next_session_open_after_entry_signal",
      exit_signal_rule = "close_after_hold_sessions_elapsed",
      exit_execution_rule = "next_session_open_after_exit_signal",
      leverage = 1,
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

g5_green_day_hold_metrics <- function(trades, bars, symbol) {
  bars <- g5_green_day_hold_prepare_bars(bars, symbol)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  hold_sessions <- if (is.data.frame(trades) && nrow(trades) > 0L && "hold_sessions" %in% names(trades)) {
    as.integer(trades$hold_sessions[[1L]])
  } else {
    10L
  }
  strategy_id <- g5_green_day_hold_strategy_id(hold_sessions)
  if (!is.data.frame(trades) || nrow(trades) == 0L) {
    return(data.frame(
      schema_version = g5_green_day_hold_schema_version(),
      symbol = symbol,
      strategy_id = strategy_id,
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
    stringsAsFactors = FALSE
  )
}

g5_green_day_hold_metrics_markdown <- function(metrics, path) {
  if (!is.data.frame(metrics) || nrow(metrics) != 1L) {
    g5_stop("metrics must be a one-row data.frame.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  lines <- c(
    paste0("# Green-Day Hold Strategy Metrics: ", metrics$symbol[[1L]]),
    "",
    paste0("- Trades: `", metrics$trade_count[[1L]], "`"),
    paste0("- Closed trades: `", metrics$closed_trade_count[[1L]], "`"),
    paste0("- Open trades: `", metrics$open_trade_count[[1L]], "`"),
    paste0("- Win rate: `", pct(metrics$win_rate[[1L]]), "`"),
    paste0("- Compounded closed return: `", pct(metrics$compounded_closed_return[[1L]]), "`"),
    paste0("- Compounded marked return: `", pct(metrics$compounded_marked_return[[1L]]), "`"),
    paste0("- Average trade return: `", pct(metrics$average_trade_return[[1L]]), "`"),
    paste0("- Best trade return: `", pct(metrics$best_trade_return[[1L]]), "`"),
    paste0("- Worst trade return: `", pct(metrics$worst_trade_return[[1L]]), "`"),
    paste0("- Profit factor: `", ifelse(is.na(metrics$profit_factor[[1L]]), "NA", sprintf("%.3f", metrics$profit_factor[[1L]])), "`"),
    paste0("- Exposure fraction: `", pct(metrics$exposure_fraction[[1L]]), "`"),
    paste0("- Max closed-trade drawdown: `", pct(metrics$max_closed_trade_drawdown[[1L]]), "`"),
    "",
    "Diagnostic only: this is not a performance claim or deployable strategy."
  )
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_green_day_hold_outputs <- function(result, symbol, output_dir, hold_sessions = 10L) {
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
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  prefix <- g5_green_day_hold_artifact_prefix(result$resolved_session$as_of_timestamp, symbol, hold_sessions)
  written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
  trades <- g5_green_day_hold_trades(result$bars, symbol = symbol, hold_sessions = hold_sessions)
  events <- g5_green_day_hold_chart_events(trades)
  metrics <- g5_green_day_hold_metrics(trades, result$bars, symbol = symbol)

  paths <- c(
    written$paths,
    list(
      trades_csv = file.path(output_dir, paste0(prefix, "_trades.csv")),
      chart_events_csv = file.path(output_dir, paste0(prefix, "_chart_events.csv")),
      metrics_csv = file.path(output_dir, paste0(prefix, "_metrics.csv")),
      metrics_md = file.path(output_dir, paste0(prefix, "_metrics.md")),
      strategy_chart_png = file.path(output_dir, paste0(prefix, "_strategy_chart.png"))
    )
  )

  utils::write.csv(trades, paths$trades_csv, row.names = FALSE)
  utils::write.csv(events, paths$chart_events_csv, row.names = FALSE)
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

  paths <- lapply(paths, normalizePath, winslash = "/", mustWork = FALSE)
  list(
    paths = paths,
    trades = trades,
    chart_events = events,
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
