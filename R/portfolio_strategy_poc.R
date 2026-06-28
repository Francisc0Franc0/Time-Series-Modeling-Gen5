# Gen5.1 portfolio strategy POC helpers.

g5_portfolio_poc_schema_version <- function() {
  "gen5_portfolio_strategy_poc_v0.1"
}

g5_portfolio_poc_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) {
    g5_stop(message)
  }
  stop(message, call. = FALSE)
}

g5_portfolio_poc_symbols <- function(symbols, field_name = "symbols") {
  out <- unique(g5_standardize_symbol(symbols))
  if (!length(out)) {
    g5_portfolio_poc_stop(paste0(field_name, " must contain at least one symbol."))
  }
  out
}

g5_portfolio_poc_trade_table <- function(x, symbol) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  if (!is.data.frame(x) || !nrow(x)) {
    return(data.frame())
  }
  required <- c(
    "trade_id", "symbol", "entry_execution_date", "entry_execution_price",
    "exit_execution_date", "exit_execution_price", "trade_status"
  )
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    g5_portfolio_poc_stop(paste0("Trade table for ", symbol, " is missing columns: ", paste(missing, collapse = ", ")))
  }
  x$symbol <- g5_standardize_symbol(x$symbol)
  x <- x[x$symbol == symbol, , drop = FALSE]
  if (!nrow(x)) {
    return(data.frame())
  }
  x$entry_execution_date <- as.Date(x$entry_execution_date)
  x$exit_execution_date <- as.Date(x$exit_execution_date)
  x$entry_execution_price <- as.numeric(x$entry_execution_price)
  x$exit_execution_price <- as.numeric(x$exit_execution_price)
  x[order(x$entry_execution_date, x$trade_id), , drop = FALSE]
}

g5_portfolio_poc_equity_table <- function(x, symbol) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  if (!is.data.frame(x) || !nrow(x)) {
    g5_portfolio_poc_stop(paste0("Equity table for ", symbol, " is empty."))
  }
  required <- c("symbol", "session_date", "close", "strategy_equity")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    g5_portfolio_poc_stop(paste0("Equity table for ", symbol, " is missing columns: ", paste(missing, collapse = ", ")))
  }
  x$symbol <- g5_standardize_symbol(x$symbol)
  x <- x[x$symbol == symbol, , drop = FALSE]
  if (!nrow(x)) {
    g5_portfolio_poc_stop(paste0("Equity table has no rows for ", symbol, "."))
  }
  x$session_date <- as.Date(x$session_date)
  x$close <- as.numeric(x$close)
  x$strategy_equity <- as.numeric(x$strategy_equity)
  x[order(x$session_date), , drop = FALSE]
}

g5_portfolio_poc_as_list_by_symbol <- function(items, symbols, field_name) {
  symbols <- g5_portfolio_poc_symbols(symbols)
  if (!is.list(items) || is.null(names(items))) {
    g5_portfolio_poc_stop(paste0(field_name, " must be a named list keyed by symbol."))
  }
  missing <- setdiff(symbols, g5_standardize_symbol(names(items)))
  if (length(missing)) {
    g5_portfolio_poc_stop(paste0(field_name, " is missing symbols: ", paste(missing, collapse = ", ")))
  }
  out <- vector("list", length(symbols))
  names(out) <- symbols
  item_names <- g5_standardize_symbol(names(items))
  for (symbol in symbols) {
    out[[symbol]] <- items[[which(item_names == symbol)[[1L]]]]
  }
  out
}

g5_portfolio_poc_bars_table <- function(bars) {
  if (!is.data.frame(bars) || !nrow(bars)) {
    g5_portfolio_poc_stop("baseline bars must be a non-empty data frame.")
  }
  required <- c("symbol", "session_date", "close")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_portfolio_poc_stop(paste0("baseline bars are missing columns: ", paste(missing, collapse = ", ")))
  }
  bars$symbol <- g5_standardize_symbol(bars$symbol)
  bars$session_date <- as.Date(bars$session_date)
  bars$close <- as.numeric(bars$close)
  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

g5_portfolio_poc_close_series <- function(bars, symbol, dates) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  bars <- bars[bars$symbol == symbol, , drop = FALSE]
  if (!nrow(bars)) {
    g5_portfolio_poc_stop(paste0("No baseline bars found for ", symbol, "."))
  }
  values <- as.numeric(bars$close)
  names(values) <- as.character(as.Date(bars$session_date))
  out <- rep(NA_real_, length(dates))
  last_value <- NA_real_
  for (i in seq_along(dates)) {
    key <- as.character(as.Date(dates[[i]], origin = "1970-01-01"))
    value <- unname(values[key])
    if (length(value) && is.finite(value)) {
      last_value <- as.numeric(value)
    }
    out[[i]] <- last_value
  }
  if (!is.finite(out[[1L]])) {
    g5_portfolio_poc_stop(paste0("Baseline ", symbol, " is missing a close on the first portfolio session."))
  }
  out
}

g5_portfolio_poc_build_baselines <- function(bars, dates, active_symbols, initial_capital = 100000, baseline_symbol = "SPY") {
  active_symbols <- g5_portfolio_poc_symbols(active_symbols, "active_symbols")
  baseline_symbol <- g5_standardize_symbol(baseline_symbol)[[1L]]
  bars <- g5_portfolio_poc_bars_table(bars)
  dates <- as.Date(dates)
  if (!length(dates)) {
    g5_portfolio_poc_stop("dates must contain at least one session.")
  }
  spy_close <- g5_portfolio_poc_close_series(bars, baseline_symbol, dates)
  spy_equity <- initial_capital * spy_close / spy_close[[1L]]

  active_curves <- lapply(active_symbols, function(symbol) {
    close <- g5_portfolio_poc_close_series(bars, symbol, dates)
    (initial_capital / length(active_symbols)) * close / close[[1L]]
  })
  active_equal_buy_hold <- Reduce(`+`, active_curves)
  out <- data.frame(
    schema_version = g5_portfolio_poc_schema_version(),
    session_date = dates,
    baseline_symbol = baseline_symbol,
    spy_buy_hold_equity = spy_equity,
    active_equal_buy_hold_equity = active_equal_buy_hold,
    spy_buy_hold_return = spy_equity / initial_capital - 1,
    active_equal_buy_hold_return = active_equal_buy_hold / initial_capital - 1,
    stringsAsFactors = FALSE
  )
  out$spy_buy_hold_drawdown <- out$spy_buy_hold_equity / cummax(out$spy_buy_hold_equity) - 1
  out$active_equal_buy_hold_drawdown <- out$active_equal_buy_hold_equity / cummax(out$active_equal_buy_hold_equity) - 1
  out
}

g5_portfolio_poc_build_accounting <- function(trades_by_symbol, equity_by_symbol, active_symbols, initial_capital = 100000, slot_count = length(active_symbols)) {
  active_symbols <- g5_portfolio_poc_symbols(active_symbols, "active_symbols")
  if (!is.numeric(initial_capital) || length(initial_capital) != 1L || !is.finite(initial_capital) || initial_capital <= 0) {
    g5_portfolio_poc_stop("initial_capital must be one positive finite number.")
  }
  if (!is.numeric(slot_count) || length(slot_count) != 1L || is.na(slot_count) || slot_count < 1L) {
    g5_portfolio_poc_stop("slot_count must be a positive number.")
  }
  slot_count <- as.integer(slot_count)
  if (slot_count < length(active_symbols)) {
    g5_portfolio_poc_stop("slot_count must be at least the number of active symbols for this POC.")
  }

  trades_by_symbol <- g5_portfolio_poc_as_list_by_symbol(trades_by_symbol, active_symbols, "trades_by_symbol")
  equity_by_symbol <- g5_portfolio_poc_as_list_by_symbol(equity_by_symbol, active_symbols, "equity_by_symbol")
  trades_by_symbol <- setNames(lapply(active_symbols, function(s) g5_portfolio_poc_trade_table(trades_by_symbol[[s]], s)), active_symbols)
  equity_by_symbol <- setNames(lapply(active_symbols, function(s) g5_portfolio_poc_equity_table(equity_by_symbol[[s]], s)), active_symbols)

  all_dates <- sort(unique(as.Date(unlist(lapply(equity_by_symbol, function(x) x$session_date)))))
  if (!length(all_dates)) {
    g5_portfolio_poc_stop("No session dates found across equity tables.")
  }
  close_by_symbol <- lapply(equity_by_symbol, function(x) {
    values <- as.numeric(x$close)
    names(values) <- as.character(as.Date(x$session_date))
    values
  })

  cash <- as.numeric(initial_capital)
  quantity <- setNames(rep(0, length(active_symbols)), active_symbols)
  entry_price <- setNames(rep(NA_real_, length(active_symbols)), active_symbols)
  active_trade_id <- setNames(rep(NA_character_, length(active_symbols)), active_symbols)
  last_mark <- setNames(rep(NA_real_, length(active_symbols)), active_symbols)
  events <- list()
  equity_rows <- list()

  add_event <- function(...) {
    events[[length(events) + 1L]] <<- data.frame(..., stringsAsFactors = FALSE)
  }
  marked_open_value <- function() {
    sum(ifelse(quantity > 0 & is.finite(last_mark), quantity * last_mark, 0), na.rm = TRUE)
  }
  portfolio_equity_before_entry <- function() {
    cash + marked_open_value()
  }

  for (date_i in seq_along(all_dates)) {
    session_date <- as.Date(all_dates[[date_i]], origin = "1970-01-01")
    date_key <- as.character(session_date)
    for (symbol in active_symbols) {
      px <- unname(close_by_symbol[[symbol]][date_key])
      if (length(px) && is.finite(px)) {
        last_mark[[symbol]] <- as.numeric(px)
      }
    }

    for (symbol in active_symbols) {
      tr <- trades_by_symbol[[symbol]]
      if (!nrow(tr) || quantity[[symbol]] <= 0) next
      exits <- tr[!is.na(tr$exit_execution_date) & tr$exit_execution_date == session_date & tr$trade_id == active_trade_id[[symbol]], , drop = FALSE]
      if (!nrow(exits)) next
      exit_px <- as.numeric(exits$exit_execution_price[[1L]])
      if (!is.finite(exit_px) || exit_px <= 0) next
      exit_value <- quantity[[symbol]] * exit_px
      realized_pnl <- quantity[[symbol]] * (exit_px - entry_price[[symbol]])
      cash <- cash + exit_value
      add_event(
        schema_version = g5_portfolio_poc_schema_version(),
        session_date = session_date,
        event_type = "exit",
        symbol = symbol,
        trade_id = active_trade_id[[symbol]],
        target_notional = NA_real_,
        actual_notional = exit_value,
        cash_after_event = cash,
        portfolio_equity_reference = portfolio_equity_before_entry(),
        price = exit_px,
        quantity = quantity[[symbol]],
        event_status = "filled",
        note = paste0("Realized PnL ", sprintf("%.2f", realized_pnl))
      )
      quantity[[symbol]] <- 0
      entry_price[[symbol]] <- NA_real_
      active_trade_id[[symbol]] <- NA_character_
    }

    for (symbol in active_symbols) {
      tr <- trades_by_symbol[[symbol]]
      if (!nrow(tr)) next
      entries <- tr[!is.na(tr$entry_execution_date) & tr$entry_execution_date == session_date, , drop = FALSE]
      if (!nrow(entries)) next
      for (i in seq_len(nrow(entries))) {
        entry <- entries[i, , drop = FALSE]
        entry_px <- as.numeric(entry$entry_execution_price[[1L]])
        equity_reference <- portfolio_equity_before_entry()
        target <- equity_reference / slot_count
        if (quantity[[symbol]] > 0) {
          add_event(
            schema_version = g5_portfolio_poc_schema_version(),
            session_date = session_date,
            event_type = "entry",
            symbol = symbol,
            trade_id = as.character(entry$trade_id[[1L]]),
            target_notional = target,
            actual_notional = 0,
            cash_after_event = cash,
            portfolio_equity_reference = equity_reference,
            price = entry_px,
            quantity = 0,
            event_status = "skipped_existing_position",
            note = "One active position per symbol max."
          )
          next
        }
        if (!is.finite(entry_px) || entry_px <= 0) {
          add_event(
            schema_version = g5_portfolio_poc_schema_version(),
            session_date = session_date,
            event_type = "entry",
            symbol = symbol,
            trade_id = as.character(entry$trade_id[[1L]]),
            target_notional = target,
            actual_notional = 0,
            cash_after_event = cash,
            portfolio_equity_reference = equity_reference,
            price = entry_px,
            quantity = 0,
            event_status = "skipped_bad_price",
            note = "Entry execution price is missing or non-positive."
          )
          next
        }
        actual <- min(target, cash)
        status <- if (actual <= 0) "skipped_no_cash" else if (actual < target) "filled_cash_capped" else "filled"
        qty <- if (actual > 0) actual / entry_px else 0
        cash <- cash - actual
        if (actual > 0) {
          quantity[[symbol]] <- qty
          entry_price[[symbol]] <- entry_px
          active_trade_id[[symbol]] <- as.character(entry$trade_id[[1L]])
        }
        add_event(
          schema_version = g5_portfolio_poc_schema_version(),
          session_date = session_date,
          event_type = "entry",
          symbol = symbol,
          trade_id = as.character(entry$trade_id[[1L]]),
          target_notional = target,
          actual_notional = actual,
          cash_after_event = cash,
          portfolio_equity_reference = equity_reference,
          price = entry_px,
          quantity = qty,
          event_status = status,
          note = "Dynamic equal-slot entry: current portfolio equity / slot_count, cash-capped."
        )
      }
    }

    symbol_values <- setNames(rep(0, length(active_symbols)), active_symbols)
    for (symbol in active_symbols) {
      if (quantity[[symbol]] > 0 && is.finite(last_mark[[symbol]])) {
        symbol_values[[symbol]] <- quantity[[symbol]] * last_mark[[symbol]]
      }
    }
    portfolio_equity <- cash + sum(symbol_values)
    row <- data.frame(
      schema_version = g5_portfolio_poc_schema_version(),
      session_date = session_date,
      cash = cash,
      open_position_count = sum(quantity > 0),
      invested_value = sum(symbol_values),
      portfolio_equity = portfolio_equity,
      portfolio_return = portfolio_equity / initial_capital - 1,
      portfolio_drawdown = NA_real_,
      stringsAsFactors = FALSE
    )
    for (symbol in active_symbols) {
      row[[paste0(symbol, "_position_value")]] <- symbol_values[[symbol]]
      row[[paste0(symbol, "_quantity")]] <- quantity[[symbol]]
    }
    equity_rows[[length(equity_rows) + 1L]] <- row
  }

  equity <- do.call(rbind, equity_rows)
  equity$portfolio_drawdown <- equity$portfolio_equity / cummax(equity$portfolio_equity) - 1
  events <- if (length(events)) do.call(rbind, events) else data.frame()

  standalone <- do.call(rbind, lapply(active_symbols, function(symbol) {
    curve <- equity_by_symbol[[symbol]]
    data.frame(
      schema_version = g5_portfolio_poc_schema_version(),
      symbol = symbol,
      session_date = as.Date(curve$session_date),
      standalone_slot_equity = (initial_capital / slot_count) * as.numeric(curve$strategy_equity),
      standalone_strategy_equity = as.numeric(curve$strategy_equity),
      close = as.numeric(curve$close),
      stringsAsFactors = FALSE
    )
  }))

  summary <- do.call(rbind, lapply(active_symbols, function(symbol) {
    ev <- if (nrow(events)) events[events$symbol == symbol, , drop = FALSE] else data.frame()
    fills <- if (nrow(ev)) ev[ev$event_type == "entry" & ev$event_status %in% c("filled", "filled_cash_capped"), , drop = FALSE] else data.frame()
    data.frame(
      schema_version = g5_portfolio_poc_schema_version(),
      symbol = symbol,
      entry_fills = nrow(fills),
      cash_capped_entries = if (nrow(ev)) sum(ev$event_status == "filled_cash_capped") else 0L,
      skipped_entries = if (nrow(ev)) sum(grepl("^skipped", ev$event_status)) else 0L,
      total_entry_notional = if (nrow(fills)) sum(as.numeric(fills$actual_notional), na.rm = TRUE) else 0,
      final_position_value = tail(equity[[paste0(symbol, "_position_value")]], 1L),
      stringsAsFactors = FALSE
    )
  }))

  list(
    equity = equity,
    events = events,
    standalone_symbol_equity = standalone,
    symbol_summary = summary,
    baselines = data.frame()
  )
}

g5_portfolio_poc_metrics <- function(portfolio_equity, initial_capital = 100000) {
  if (!is.data.frame(portfolio_equity) || !nrow(portfolio_equity)) {
    g5_portfolio_poc_stop("portfolio_equity must be a non-empty data frame.")
  }
  ending_equity <- tail(as.numeric(portfolio_equity$portfolio_equity), 1L)
  data.frame(
    schema_version = g5_portfolio_poc_schema_version(),
    initial_capital = initial_capital,
    ending_equity = ending_equity,
    total_return = ending_equity / initial_capital - 1,
    cagr = g5_ema_cross_cagr(initial_capital, ending_equity, min(portfolio_equity$session_date), max(portfolio_equity$session_date)),
    sharpe = g5_ema_cross_sharpe(as.numeric(portfolio_equity$portfolio_equity)),
    max_drawdown = min(as.numeric(portfolio_equity$portfolio_drawdown), na.rm = TRUE),
    session_count = nrow(portfolio_equity),
    stringsAsFactors = FALSE
  )
}

g5_portfolio_poc_baseline_metrics <- function(baselines, initial_capital = 100000) {
  if (!is.data.frame(baselines) || !nrow(baselines)) {
    return(data.frame())
  }
  data.frame(
    schema_version = g5_portfolio_poc_schema_version(),
    baseline_id = c("spy_buy_hold", "active_equal_buy_hold"),
    ending_equity = c(tail(baselines$spy_buy_hold_equity, 1L), tail(baselines$active_equal_buy_hold_equity, 1L)),
    total_return = c(tail(baselines$spy_buy_hold_equity, 1L), tail(baselines$active_equal_buy_hold_equity, 1L)) / initial_capital - 1,
    cagr = c(
      g5_ema_cross_cagr(initial_capital, tail(baselines$spy_buy_hold_equity, 1L), min(baselines$session_date), max(baselines$session_date)),
      g5_ema_cross_cagr(initial_capital, tail(baselines$active_equal_buy_hold_equity, 1L), min(baselines$session_date), max(baselines$session_date))
    ),
    sharpe = c(
      g5_ema_cross_sharpe(as.numeric(baselines$spy_buy_hold_equity)),
      g5_ema_cross_sharpe(as.numeric(baselines$active_equal_buy_hold_equity))
    ),
    max_drawdown = c(
      min(as.numeric(baselines$spy_buy_hold_drawdown), na.rm = TRUE),
      min(as.numeric(baselines$active_equal_buy_hold_drawdown), na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
  )
}

g5_portfolio_poc_write_png <- function(accounting, path, active_symbols, width = 1700L, height = 1100L) {
  active_symbols <- g5_portfolio_poc_symbols(active_symbols, "active_symbols")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  png(filename = path, width = width, height = height, res = 140)
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)

  equity <- accounting$equity
  standalone <- accounting$standalone_symbol_equity
  baselines <- accounting$baselines
  x <- seq_len(nrow(equity))
  graphics::layout(matrix(c(1, 2), nrow = 2L), heights = c(0.58, 0.42))
  graphics::par(mar = c(4.5, 4.7, 3.2, 1.5))

  y <- range(c(equity$portfolio_equity, baselines$spy_buy_hold_equity, baselines$active_equal_buy_hold_equity), finite = TRUE)
  graphics::plot(x, equity$portfolio_equity, type = "l", col = "#2364AA", lwd = 2.2, xaxt = "n", xlab = "", ylab = "Portfolio equity ($)", ylim = y, main = "Active Portfolio vs Passive Baselines")
  graphics::grid(col = "#E6E8EB")
  if (is.data.frame(baselines) && nrow(baselines)) {
    graphics::lines(x, baselines$spy_buy_hold_equity, col = "#111111", lwd = 1.7, lty = 2)
    graphics::lines(x, baselines$active_equal_buy_hold_equity, col = "#D95F02", lwd = 1.8, lty = 3)
  }
  ticks <- unique(round(seq(1, nrow(equity), length.out = min(7L, nrow(equity)))))
  graphics::axis(1, at = ticks, labels = as.character(as.Date(equity$session_date)[ticks]), las = 2, cex.axis = 0.72)
  graphics::legend(
    "topleft",
    legend = c("Active portfolio", "SPY buy-and-hold", "Equal active-set buy-and-hold"),
    col = c("#2364AA", "#111111", "#D95F02"),
    lwd = c(2.2, 1.7, 1.8),
    lty = c(1, 2, 3),
    bty = "n",
    cex = 0.82
  )

  graphics::par(mar = c(4.5, 4.7, 3.0, 1.5))
  y2 <- range(standalone$standalone_slot_equity, finite = TRUE)
  graphics::plot(NA, xlim = range(x), ylim = y2, xaxt = "n", xlab = "", ylab = "Standalone $/slot", main = "Per-Symbol Standalone Reference Curves")
  graphics::grid(col = "#E6E8EB")
  cols <- c("#2364AA", "#D95F02", "#1B9E77", "#7570B3", "#E7298A", "#666666")
  for (i in seq_along(active_symbols)) {
    symbol <- active_symbols[[i]]
    curve <- standalone[standalone$symbol == symbol, , drop = FALSE]
    idx <- match(as.Date(curve$session_date), as.Date(equity$session_date))
    graphics::lines(idx, curve$standalone_slot_equity, col = cols[[((i - 1L) %% length(cols)) + 1L]], lwd = 1.7)
  }
  graphics::axis(1, at = ticks, labels = as.character(as.Date(equity$session_date)[ticks]), las = 2, cex.axis = 0.72)
  graphics::legend("topleft", legend = active_symbols, col = cols[seq_along(active_symbols)], lwd = 1.7, bty = "n", ncol = min(3L, length(active_symbols)), cex = 0.8)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_portfolio_poc_write_report <- function(paths, settings, metrics, baseline_metrics, symbol_summary) {
  fmt_pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  fmt_dol <- function(x) ifelse(is.na(x), "NA", sprintf("$%.2f", as.numeric(x)))
  lines <- c(
    "# Gen5 Portfolio Strategy Accounting POC",
    "",
    "POC only: this packet tests portfolio accounting over stitched OOS PCA-routed WFA artifacts. It is not final allocation research, live advice, execution logic, or leverage automation.",
    "",
    "## Run Context",
    "",
    paste0("- Regime Context Universe: `", paste(settings$regime_context_symbols, collapse = ", "), "`"),
    paste0("- Research Candidate Universe: `", paste(settings$active_symbols, collapse = ", "), "`"),
    paste0("- Tradeable Universe: `", paste(settings$active_symbols, collapse = ", "), "`"),
    paste0("- Active Allocation Set: `", paste(settings$active_symbols, collapse = ", "), "`"),
    paste0("- Panel mode: `", settings$pca_panel_mode, "`"),
    paste0("- State engine: `", settings$state_engine, "`"),
    paste0("- State count/grid: `", settings$grid_n, "`"),
    paste0("- Fold count: `", settings$fold_count, "`"),
    paste0("- End date: `", settings$end_date, "`"),
    paste0("- As-of timestamp: `", settings$as_of_timestamp, "`"),
    paste0("- Strategy grid preset: `", settings$strategy_grid_preset, "`"),
    paste0("- Initial capital: `", fmt_dol(metrics$initial_capital[[1L]]), "`"),
    paste0("- Slot count: `", settings$slot_count, "`"),
    "- Sizing policy: `dynamic_equal_slot_cash_capped`.",
    "- Ownership policy: `entry_state_owns_trade_until_exit`.",
    paste0("- Passive baseline symbol: `", settings$baseline_symbol, "`"),
    "",
    "## Accounting Rule",
    "",
    "On each session, exits execute first and return cash to the shared account. New entries then target current portfolio equity divided by the slot count. If the target is larger than available cash, the POC takes a smaller cash-capped position. Open positions are not resized by scheduled rebalance.",
    "",
    "Per-symbol curves in this report are standalone active-strategy reference curves scaled to one slot. The portfolio curve is the authoritative accounting POC output. Passive baselines are inspection references only.",
    "",
    "## Portfolio Metrics",
    "",
    paste0("- Ending equity: `", fmt_dol(metrics$ending_equity[[1L]]), "`"),
    paste0("- Total return: `", fmt_pct(metrics$total_return[[1L]]), "`"),
    paste0("- CAGR: `", fmt_pct(metrics$cagr[[1L]]), "`"),
    paste0("- Sharpe: `", ifelse(is.na(metrics$sharpe[[1L]]), "NA", sprintf("%.3f", metrics$sharpe[[1L]])), "`"),
    paste0("- Max drawdown: `", fmt_pct(metrics$max_drawdown[[1L]]), "`"),
    "",
    "## Passive Baselines",
    "",
    paste(
      c("| baseline | ending_equity | total_return | CAGR | Sharpe | max_drawdown |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
        apply(baseline_metrics, 1L, function(row) {
          paste0("| ", row[["baseline_id"]], " | ", fmt_dol(row[["ending_equity"]]), " | ", fmt_pct(row[["total_return"]]), " | ", fmt_pct(row[["cagr"]]), " | ", ifelse(is.na(as.numeric(row[["sharpe"]])), "NA", sprintf("%.3f", as.numeric(row[["sharpe"]]))), " | ", fmt_pct(row[["max_drawdown"]]), " |")
        })),
      collapse = "\n"
    ),
    "",
    "## Symbol Summary",
    "",
    paste(
      c("| symbol | entry_fills | cash_capped_entries | skipped_entries | total_entry_notional | final_position_value |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
        apply(symbol_summary, 1L, function(row) {
          paste0("| ", row[["symbol"]], " | ", row[["entry_fills"]], " | ", row[["cash_capped_entries"]], " | ", row[["skipped_entries"]], " | ", fmt_dol(row[["total_entry_notional"]]), " | ", fmt_dol(row[["final_position_value"]]), " |")
        })),
      collapse = "\n"
    ),
    "",
    "## Outputs",
    "",
    paste0("- Portfolio chart: `", paths$chart_png, "`"),
    paste0("- Portfolio equity: `", paths$portfolio_equity_csv, "`"),
    paste0("- Portfolio events: `", paths$portfolio_events_csv, "`"),
    paste0("- Passive baselines: `", paths$baseline_equity_csv, "`"),
    paste0("- Passive baseline metrics: `", paths$baseline_metrics_csv, "`"),
    paste0("- Standalone symbol equity: `", paths$standalone_symbol_equity_csv, "`"),
    paste0("- Symbol summary: `", paths$symbol_summary_csv, "`"),
    paste0("- Child artifact index: `", paths$child_artifact_index_csv, "`"),
    "",
    "## STOP Guardrails",
    "",
    "- This POC does not decide which assets belong in the live portfolio.",
    "- This POC does not approve any strategy family, state map, context universe, or allocation policy.",
    "- This POC does not create live-facing advice or execution instructions.",
    "- Any move from accounting POC to research evidence requires an operator decision."
  )
  writeLines(lines, paths$report_md, useBytes = TRUE)
  normalizePath(paths$report_md, winslash = "/", mustWork = FALSE)
}

g5_portfolio_poc_write_outputs <- function(accounting, child_artifact_index, output_dir, settings) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- list(
    portfolio_equity_csv = file.path(output_dir, "portfolio_poc_equity.csv"),
    portfolio_events_csv = file.path(output_dir, "portfolio_poc_events.csv"),
    baseline_equity_csv = file.path(output_dir, "portfolio_poc_baselines.csv"),
    standalone_symbol_equity_csv = file.path(output_dir, "portfolio_poc_standalone_symbol_equity.csv"),
    symbol_summary_csv = file.path(output_dir, "portfolio_poc_symbol_summary.csv"),
    child_artifact_index_csv = file.path(output_dir, "portfolio_poc_child_artifact_index.csv"),
    metrics_csv = file.path(output_dir, "portfolio_poc_metrics.csv"),
    baseline_metrics_csv = file.path(output_dir, "portfolio_poc_baseline_metrics.csv"),
    chart_png = file.path(output_dir, "portfolio_poc_equity_curves.png"),
    report_md = file.path(output_dir, "portfolio_poc_report.md")
  )
  metrics <- g5_portfolio_poc_metrics(accounting$equity, settings$initial_capital)
  baseline_metrics <- g5_portfolio_poc_baseline_metrics(accounting$baselines, settings$initial_capital)
  utils::write.csv(accounting$equity, paths$portfolio_equity_csv, row.names = FALSE)
  utils::write.csv(accounting$events, paths$portfolio_events_csv, row.names = FALSE)
  utils::write.csv(accounting$baselines, paths$baseline_equity_csv, row.names = FALSE)
  utils::write.csv(accounting$standalone_symbol_equity, paths$standalone_symbol_equity_csv, row.names = FALSE)
  utils::write.csv(accounting$symbol_summary, paths$symbol_summary_csv, row.names = FALSE)
  utils::write.csv(child_artifact_index, paths$child_artifact_index_csv, row.names = FALSE)
  utils::write.csv(metrics, paths$metrics_csv, row.names = FALSE)
  utils::write.csv(baseline_metrics, paths$baseline_metrics_csv, row.names = FALSE)
  paths$chart_png <- g5_portfolio_poc_write_png(accounting, paths$chart_png, settings$active_symbols)
  paths$report_md <- g5_portfolio_poc_write_report(paths, settings, metrics, baseline_metrics, accounting$symbol_summary)
  list(paths = paths, metrics = metrics, baseline_metrics = baseline_metrics)
}
