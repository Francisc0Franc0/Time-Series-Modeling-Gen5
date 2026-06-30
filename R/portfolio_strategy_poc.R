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

g5_context_factorial_schema_version <- function() {
  "gen5_context_universe_factorial_portfolio_v0.1"
}

g5_context_factorial_default_purpose <- function() {
  paste(
    "This first test asks whether, for the same five active names and the same PCA/state machinery,",
    "regime labels look more useful and stable when they are built from the active names themselves,",
    "from active names plus market-risk context, or from external market-risk context only."
  )
}

g5_context_factorial_state_map_triage_purpose <- function() {
  paste(
    "This narrow state-map triage asks whether active-plus-risk behavioral-pool PCA looks more useful",
    "when states are assigned by a 3x3 quantile grid, fixed k-means with k=9, or TRAIN-only auto k-means",
    "selecting k from 2..9 by the Calinski-Harabasz criterion."
  )
}

g5_context_factorial_auto_max15_triage_purpose <- function() {
  paste(
    "This wide auto-k state-map triage asks whether active-plus-risk behavioral-pool PCA looks more useful",
    "when states are assigned by a 3x3 quantile grid, fixed k-means with k=9, or TRAIN-only auto k-means",
    "selecting k from 2..15 by the Calinski-Harabasz criterion.",
    "It is a visual and accounting inspection slice only, not accepted allocation evidence."
  )
}

g5_context_factorial_universe_definitions <- function(active_symbols = c("AMD", "NVDA", "TSLA", "COIN", "MSTR")) {
  active_symbols <- g5_portfolio_poc_symbols(active_symbols, "active_symbols")
  make_row <- function(universe_id, universe_label, symbols, diversity_class, similarity_class, rationale) {
    symbols <- unique(g5_standardize_symbol(symbols))
    overlap <- intersect(symbols, active_symbols)
    data.frame(
      schema_version = g5_context_factorial_schema_version(),
      universe_id = universe_id,
      universe_label = universe_label,
      symbols = paste(symbols, collapse = ","),
      symbol_count = length(symbols),
      active_overlap_count = length(overlap),
      active_overlap_symbols = paste(overlap, collapse = ","),
      diversity_class = diversity_class,
      similarity_class = similarity_class,
      rationale = rationale,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, list(
    make_row(
      "active_self_context",
      "Active self context",
      active_symbols,
      "low_to_medium",
      "maximum_active_overlap",
      "Uses the same symbols as the Research Candidate / Tradeable / Active Allocation Set."
    ),
    make_row(
      "active_plus_risk_context",
      "Active plus market-risk context",
      c(active_symbols, "SPY", "QQQ", "IWM", "SMH", "TLT", "GLD", "VXX"),
      "high",
      "active_overlap_plus_external_risk",
      "Keeps the active symbols in context and adds broad equity, growth, small-cap, semiconductor, duration, gold, and volatility-proxy lenses."
    ),
    make_row(
      "ex_active_market_risk_context",
      "External market-risk context",
      c("SPY", "QQQ", "IWM", "SMH", "TLT", "GLD", "VXX"),
      "high",
      "no_direct_active_overlap",
      "Fits regime context from external market/risk symbols while the active symbols remain research candidates and tradeable accounting inputs."
    )
  ))
}

g5_context_factorial_surface_definitions <- function(medium_grid = FALSE, pca_panel_mode = "pooled_asset_day", state_engine = "quantile_grid", grid_n = 3L, state_map_triage = FALSE, auto_max15_triage = FALSE) {
  if (isTRUE(state_map_triage) && isTRUE(auto_max15_triage)) {
    g5_stop("Choose either state_map_triage or auto_max15_triage, not both.")
  }
  if (isTRUE(state_map_triage)) {
    return(data.frame(
      surface_id = c(
        "behavioral_pool_quantile_grid_3x3",
        "behavioral_pool_kmeans_k9",
        "behavioral_pool_kmeans_auto_max9"
      ),
      pca_panel_mode = rep("pooled_asset_day", 3L),
      state_engine = c("quantile_grid", "pca_kmeans", "pca_kmeans_auto"),
      grid_n = c(3L, 9L, 9L),
      state_count = c("3x3", "k9", "kauto9"),
      stringsAsFactors = FALSE
    ))
  }
  if (isTRUE(auto_max15_triage)) {
    return(data.frame(
      surface_id = c(
        "behavioral_pool_quantile_grid_3x3",
        "behavioral_pool_kmeans_k9",
        "behavioral_pool_kmeans_auto_max15"
      ),
      pca_panel_mode = rep("pooled_asset_day", 3L),
      state_engine = c("quantile_grid", "pca_kmeans", "pca_kmeans_auto"),
      grid_n = c(3L, 9L, 15L),
      state_count = c("3x3", "k9", "kauto15"),
      stringsAsFactors = FALSE
    ))
  }
  if (isTRUE(medium_grid)) {
    return(data.frame(
      surface_id = c(
        "contextual_snapshot_quantile_grid",
        "contextual_snapshot_kmeans",
        "behavioral_pool_quantile_grid",
        "behavioral_pool_kmeans"
      ),
      pca_panel_mode = c("date_aligned_context", "date_aligned_context", "pooled_asset_day", "pooled_asset_day"),
      state_engine = c("quantile_grid", "pca_kmeans", "quantile_grid", "pca_kmeans"),
      grid_n = c(3L, 9L, 3L, 9L),
      state_count = c("3x3", "k9", "3x3", "k9"),
      stringsAsFactors = FALSE
    ))
  }
  pca_panel_mode <- g5_pca_wfa_panel_mode(pca_panel_mode)
  state_engine <- g5_pca_wfa_state_engine(if (identical(state_engine, "kmeans")) "pca_kmeans" else as.character(state_engine))
  data.frame(
    surface_id = "single_surface",
    pca_panel_mode = pca_panel_mode,
    state_engine = state_engine,
    grid_n = as.integer(grid_n),
    state_count = g5_pca_wfa_engine_label(state_engine, grid_n),
    stringsAsFactors = FALSE
  )
}

g5_context_factorial_prefix <- function(as_of_timestamp, active_symbols, fold_count, universe_count, surface_count, grid_n, state_engine, pca_panel_mode, end_date, strategy_grid_preset = "standard", surface_preset = "") {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  end_label <- gsub("[^0-9A-Za-z]+", "", as.character(as.Date(end_date)))
  active_label <- paste0("A", length(g5_standardize_symbol(active_symbols)))
  panel_label <- if (identical(g5_pca_wfa_panel_label(pca_panel_mode), "pooled")) "pool" else "align"
  engine_label <- g5_pca_wfa_engine_label(state_engine, grid_n)
  grid_label <- g5_pca_wfa_strategy_grid_label(strategy_grid_preset)
  preset_label <- gsub("[^0-9A-Za-z]+", "", as.character(surface_preset))
  surface_label <- if (as.integer(surface_count) > 1L) {
    if (nzchar(preset_label)) paste0(as.integer(surface_count), "s_", preset_label) else paste0(as.integer(surface_count), "s")
  } else {
    paste(panel_label, engine_label, sep = "_")
  }
  parts <- c("ctxfac", active_label, paste0(fold_count, "f"), paste0(universe_count, "u"), surface_label)
  if (nzchar(grid_label)) parts <- c(parts, grid_label)
  paste(c(parts, end_label, stamp), collapse = "_")
}

g5_context_factorial_output_dir <- function(repo_root, as_of_timestamp, active_symbols, fold_count, universe_count, surface_count = 1L, grid_n = 3L, state_engine = "quantile_grid", pca_panel_mode = "pooled_asset_day", end_date, strategy_grid_preset = "standard", surface_preset = "") {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "context_universe_factorials",
    g5_context_factorial_prefix(as_of_timestamp, active_symbols, fold_count, universe_count, surface_count, grid_n, state_engine, pca_panel_mode, end_date, strategy_grid_preset, surface_preset)
  )
}

g5_portfolio_poc_packet_dir <- function(repo_root, as_of_timestamp, active_symbols, fold_count, grid_n, state_engine, pca_panel_mode, regime_context_symbols, end_date, strategy_grid_preset = "standard") {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  end_label <- gsub("[^0-9A-Za-z]+", "", as.character(as.Date(end_date)))
  panel_label <- g5_pca_wfa_panel_label(pca_panel_mode)
  engine_label <- g5_pca_wfa_engine_label(state_engine, grid_n)
  grid_label <- g5_pca_wfa_strategy_grid_label(strategy_grid_preset)
  packet_name <- paste(c(
    "portfolio_poc",
    paste(g5_standardize_symbol(active_symbols), collapse = "-"),
    paste0(as.integer(fold_count), "f"),
    engine_label,
    paste0(panel_label, length(unique(g5_standardize_symbol(regime_context_symbols))), "ctx"),
    if (nzchar(grid_label)) grid_label else NULL,
    end_label,
    stamp
  ), collapse = "_")
  file.path(repo_root, "runs", "research_workbench", "portfolio_strategy_pocs", packet_name)
}

g5_context_factorial_portfolio_paths <- function(portfolio_dir) {
  list(
    report_md = file.path(portfolio_dir, "portfolio_poc_report.md"),
    metrics_csv = file.path(portfolio_dir, "portfolio_poc_metrics.csv"),
    baseline_metrics_csv = file.path(portfolio_dir, "portfolio_poc_baseline_metrics.csv"),
    symbol_summary_csv = file.path(portfolio_dir, "portfolio_poc_symbol_summary.csv"),
    child_artifact_index_csv = file.path(portfolio_dir, "portfolio_poc_child_artifact_index.csv"),
    chart_png = file.path(portfolio_dir, "portfolio_poc_equity_curves.png")
  )
}

g5_read_csv_if_exists <- function(path) {
  if (!file.exists(path)) return(data.frame())
  utils::read.csv(path, stringsAsFactors = FALSE)
}

g5_context_factorial_portfolio_index <- function(universe_defs, surface_defs, repo_root, as_of_timestamp, active_symbols, fold_count, end_date, strategy_grid_preset = "standard") {
  rows <- list()
  for (s in seq_len(nrow(surface_defs))) {
    for (i in seq_len(nrow(universe_defs))) {
      symbols <- g5_standardize_symbol(strsplit(universe_defs$symbols[[i]], ",", fixed = TRUE)[[1L]])
      portfolio_dir <- g5_portfolio_poc_packet_dir(repo_root, as_of_timestamp, active_symbols, fold_count, surface_defs$grid_n[[s]], surface_defs$state_engine[[s]], surface_defs$pca_panel_mode[[s]], symbols, end_date, strategy_grid_preset)
      paths <- g5_context_factorial_portfolio_paths(portfolio_dir)
      rows[[length(rows) + 1L]] <- data.frame(
        schema_version = g5_context_factorial_schema_version(),
        universe_id = universe_defs$universe_id[[i]],
        universe_label = universe_defs$universe_label[[i]],
        surface_id = surface_defs$surface_id[[s]],
        pca_panel_mode = surface_defs$pca_panel_mode[[s]],
        state_engine = surface_defs$state_engine[[s]],
        state_count = surface_defs$state_count[[s]],
        grid_n = surface_defs$grid_n[[s]],
        regime_context_symbols = paste(symbols, collapse = ","),
        symbol_count = length(symbols),
        active_overlap_count = universe_defs$active_overlap_count[[i]],
        diversity_class = universe_defs$diversity_class[[i]],
        similarity_class = universe_defs$similarity_class[[i]],
        portfolio_dir = normalizePath(portfolio_dir, winslash = "/", mustWork = FALSE),
        run_status = if (file.exists(paths$metrics_csv) && file.exists(paths$report_md)) "ok" else "missing_outputs",
        report_md = normalizePath(paths$report_md, winslash = "/", mustWork = FALSE),
        metrics_csv = normalizePath(paths$metrics_csv, winslash = "/", mustWork = FALSE),
        baseline_metrics_csv = normalizePath(paths$baseline_metrics_csv, winslash = "/", mustWork = FALSE),
        symbol_summary_csv = normalizePath(paths$symbol_summary_csv, winslash = "/", mustWork = FALSE),
        child_artifact_index_csv = normalizePath(paths$child_artifact_index_csv, winslash = "/", mustWork = FALSE),
        chart_png = normalizePath(paths$chart_png, winslash = "/", mustWork = FALSE),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

g5_context_factorial_summary <- function(portfolio_index) {
  rows <- list()
  for (i in seq_len(nrow(portfolio_index))) {
    metrics <- g5_read_csv_if_exists(portfolio_index$metrics_csv[[i]])
    symbol_summary <- g5_read_csv_if_exists(portfolio_index$symbol_summary_csv[[i]])
    if (!nrow(metrics)) {
      rows[[length(rows) + 1L]] <- data.frame(
        universe_id = portfolio_index$universe_id[[i]],
        universe_label = portfolio_index$universe_label[[i]],
        surface_id = portfolio_index$surface_id[[i]],
        pca_panel_mode = portfolio_index$pca_panel_mode[[i]],
        state_engine = portfolio_index$state_engine[[i]],
        state_count = portfolio_index$state_count[[i]],
        run_status = portfolio_index$run_status[[i]],
        ending_equity = NA_real_,
        total_return = NA_real_,
        cagr = NA_real_,
        sharpe = NA_real_,
        max_drawdown = NA_real_,
        session_count = NA_integer_,
        total_entry_fills = NA_integer_,
        total_skipped_entries = NA_integer_,
        total_cash_capped_entries = NA_integer_,
        stringsAsFactors = FALSE
      )
      next
    }
    rows[[length(rows) + 1L]] <- data.frame(
      universe_id = portfolio_index$universe_id[[i]],
      universe_label = portfolio_index$universe_label[[i]],
      surface_id = portfolio_index$surface_id[[i]],
      pca_panel_mode = portfolio_index$pca_panel_mode[[i]],
      state_engine = portfolio_index$state_engine[[i]],
      state_count = portfolio_index$state_count[[i]],
      run_status = portfolio_index$run_status[[i]],
      ending_equity = as.numeric(metrics$ending_equity[[1L]]),
      total_return = as.numeric(metrics$total_return[[1L]]),
      cagr = as.numeric(metrics$cagr[[1L]]),
      sharpe = as.numeric(metrics$sharpe[[1L]]),
      max_drawdown = as.numeric(metrics$max_drawdown[[1L]]),
      session_count = as.integer(metrics$session_count[[1L]]),
      total_entry_fills = if (nrow(symbol_summary)) sum(as.integer(symbol_summary$entry_fills), na.rm = TRUE) else NA_integer_,
      total_skipped_entries = if (nrow(symbol_summary)) sum(as.integer(symbol_summary$skipped_entries), na.rm = TRUE) else NA_integer_,
      total_cash_capped_entries = if (nrow(symbol_summary)) sum(as.integer(symbol_summary$cash_capped_entries), na.rm = TRUE) else NA_integer_,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

g5_context_factorial_child_artifact_index <- function(portfolio_index) {
  rows <- list()
  for (i in seq_len(nrow(portfolio_index))) {
    child <- g5_read_csv_if_exists(portfolio_index$child_artifact_index_csv[[i]])
    if (!nrow(child)) next
    child$universe_id <- portfolio_index$universe_id[[i]]
    child$universe_label <- portfolio_index$universe_label[[i]]
    child$surface_id <- portfolio_index$surface_id[[i]]
    child$pca_panel_mode <- portfolio_index$pca_panel_mode[[i]]
    child$state_engine <- portfolio_index$state_engine[[i]]
    child$state_count <- portfolio_index$state_count[[i]]
    child$regime_context_symbols <- portfolio_index$regime_context_symbols[[i]]
    rows[[length(rows) + 1L]] <- child
  }
  if (!length(rows)) {
    return(data.frame())
  }
  out <- do.call(rbind, rows)
  front <- c("universe_id", "universe_label", "surface_id", "pca_panel_mode", "state_engine", "state_count", "regime_context_symbols")
  out[, c(front, setdiff(names(out), front)), drop = FALSE]
}

g5_context_factorial_child_metric_summary <- function(child_index) {
  if (!is.data.frame(child_index) || !nrow(child_index)) return(data.frame())
  if (!all(c("oos_metrics_csv", "symbol") %in% names(child_index))) return(data.frame())
  rows <- list()
  for (i in seq_len(nrow(child_index))) {
    metrics <- g5_read_csv_if_exists(child_index$oos_metrics_csv[[i]])
    if (!nrow(metrics)) next
    metric_cols <- intersect(c("total_return", "sharpe", "max_drawdown", "trade_count", "closed_trade_count", "buy_hold_total_return"), names(metrics))
    if (!length(metric_cols)) next
    rows[[length(rows) + 1L]] <- cbind(
      child_index[i, c("universe_id", "surface_id", "pca_panel_mode", "state_engine", "state_count", "symbol"), drop = FALSE],
      metrics[1L, metric_cols, drop = FALSE]
    )
  }
  if (!length(rows)) data.frame() else do.call(rbind, rows)
}

g5_context_factorial_state_coverage_summary <- function(child_index) {
  if (!is.data.frame(child_index) || !nrow(child_index)) return(data.frame())
  if (!all(c("run_dir", "symbol") %in% names(child_index))) return(data.frame())
  rows <- list()
  for (i in seq_len(nrow(child_index))) {
    coverage_path <- file.path(child_index$run_dir[[i]], "pcawfa_state_coverage.csv")
    coverage <- g5_read_csv_if_exists(coverage_path)
    if (!nrow(coverage) || !all(c("split", "row_count") %in% names(coverage))) next
    oos <- coverage[coverage$split == "OOS", , drop = FALSE]
    train <- coverage[coverage$split == "TRAIN", , drop = FALSE]
    oos_rows <- as.numeric(oos$row_count)
    train_rows <- as.numeric(train$row_count)
    rows[[length(rows) + 1L]] <- data.frame(
      universe_id = child_index$universe_id[[i]],
      surface_id = child_index$surface_id[[i]],
      pca_panel_mode = child_index$pca_panel_mode[[i]],
      state_engine = child_index$state_engine[[i]],
      state_count = child_index$state_count[[i]],
      symbol = child_index$symbol[[i]],
      train_states_with_rows = sum(train_rows > 0, na.rm = TRUE),
      oos_states_with_rows = sum(oos_rows > 0, na.rm = TRUE),
      oos_rows = sum(oos_rows, na.rm = TRUE),
      min_oos_state_rows = if (length(oos_rows)) min(oos_rows, na.rm = TRUE) else NA_real_,
      max_oos_state_rows = if (length(oos_rows)) max(oos_rows, na.rm = TRUE) else NA_real_,
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) data.frame() else do.call(rbind, rows)
}

g5_context_factorial_selected_family_summary <- function(child_index) {
  if (!is.data.frame(child_index) || !nrow(child_index)) return(data.frame())
  if (!all(c("run_dir", "symbol") %in% names(child_index))) return(data.frame())
  rows <- list()
  for (i in seq_len(nrow(child_index))) {
    selected_path <- file.path(child_index$run_dir[[i]], "pcawfa_selected_states.csv")
    selected <- g5_read_csv_if_exists(selected_path)
    if (!nrow(selected) || !"strategy_family" %in% names(selected)) next
    tab <- sort(table(selected$strategy_family), decreasing = TRUE)
    rows[[length(rows) + 1L]] <- data.frame(
      universe_id = child_index$universe_id[[i]],
      surface_id = child_index$surface_id[[i]],
      pca_panel_mode = child_index$pca_panel_mode[[i]],
      state_engine = child_index$state_engine[[i]],
      state_count = child_index$state_count[[i]],
      symbol = child_index$symbol[[i]],
      selected_families = paste(paste(names(tab), as.integer(tab), sep = "="), collapse = ";"),
      no_trade_state_selections = if ("no_trade" %in% names(tab)) as.integer(tab[["no_trade"]]) else 0L,
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) data.frame() else do.call(rbind, rows)
}

g5_context_factorial_auto_cluster_summary <- function(child_index) {
  empty <- data.frame(
    universe_id = character(),
    surface_id = character(),
    symbol = character(),
    fold_id = character(),
    fold_no = integer(),
    cluster_count_mode = character(),
    auto_min_clusters = integer(),
    auto_max_clusters = integer(),
    selected_cluster_count = integer(),
    selection_criterion = character(),
    stringsAsFactors = FALSE
  )
  if (!is.data.frame(child_index) || !nrow(child_index)) return(empty)
  required <- c("universe_id", "surface_id", "state_engine", "symbol", "run_dir")
  if (!all(required %in% names(child_index))) return(empty)
  auto_rows <- child_index[child_index$state_engine == "pca_kmeans_auto", , drop = FALSE]
  if (!nrow(auto_rows)) return(empty)
  rows <- list()
  for (i in seq_len(nrow(auto_rows))) {
    contract_path <- file.path(auto_rows$run_dir[[i]], "pcawfa_pca_model_contract.csv")
    contract <- g5_read_csv_if_exists(contract_path)
    if (!nrow(contract) || !all(c("record_type", "key", "value", "fold_id", "fold_no") %in% names(contract))) next
    meta <- contract[contract$record_type == "meta" & nzchar(contract$key), , drop = FALSE]
    if (!nrow(meta)) next
    for (fold_id in unique(meta$fold_id)) {
      fold_meta <- meta[meta$fold_id == fold_id, , drop = FALSE]
      value_for <- function(key) {
        value <- fold_meta$value[fold_meta$key == key]
        if (length(value)) value[[1L]] else NA_character_
      }
      rows[[length(rows) + 1L]] <- data.frame(
        universe_id = auto_rows$universe_id[[i]],
        surface_id = auto_rows$surface_id[[i]],
        symbol = auto_rows$symbol[[i]],
        fold_id = fold_id,
        fold_no = suppressWarnings(as.integer(fold_meta$fold_no[[1L]])),
        cluster_count_mode = value_for("cluster_count_mode"),
        auto_min_clusters = suppressWarnings(as.integer(value_for("auto_min_clusters"))),
        auto_max_clusters = suppressWarnings(as.integer(value_for("auto_max_clusters"))),
        selected_cluster_count = suppressWarnings(as.integer(value_for("cluster_count"))),
        selection_criterion = value_for("auto_selection_criterion"),
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) empty else do.call(rbind, rows)
}

g5_context_factorial_write_metrics_overview <- function(summary, path, width = 3000L, height = 1800L, res = 180L) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = as.integer(res))
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mfrow = c(2L, 2L), mar = c(7, 4.8, 3, 1.2), oma = c(0, 0, 3, 0))
  cols <- grDevices::hcl.colors(max(3L, nrow(summary)), palette = "Dark 3")
  labels <- if ("surface_id" %in% names(summary) && length(unique(summary$surface_id)) > 1L) paste(summary$universe_id, summary$surface_id, sep = "\n") else summary$universe_id
  draw_bar <- function(values, title, ylab, pct = FALSE) {
    v <- as.numeric(values)
    names(v) <- labels
    plot_vals <- if (pct) 100 * v else v
    graphics::barplot(plot_vals, col = cols[seq_along(plot_vals)], las = 2, cex.names = if (length(plot_vals) > 6L) 0.45 else 0.72, main = title, ylab = ylab)
    graphics::grid(nx = NA, ny = NULL, col = "#E6E8EB")
  }
  draw_bar(summary$total_return, "Portfolio Total Return", "Percent", pct = TRUE)
  draw_bar(summary$max_drawdown, "Portfolio Max Drawdown", "Percent", pct = TRUE)
  draw_bar(summary$sharpe, "Portfolio Sharpe", "Sharpe", pct = FALSE)
  draw_bar(summary$total_entry_fills, "Entry Fills", "Count", pct = FALSE)
  graphics::mtext("Context Universe Factorial Portfolio Overview", side = 3, outer = TRUE, line = 1, font = 2)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_context_factorial_visual_item_label <- function(child_row) {
  paste(child_row$symbol[[1L]], child_row$state_count[[1L]], sep = " / ")
}

g5_context_factorial_child_visual_items <- function(child_rows) {
  items <- vector("list", nrow(child_rows))
  for (i in seq_len(nrow(child_rows))) {
    paths <- g5_pca_wfa_comparison_artifact_paths(child_rows$run_dir[[i]])
    items[[i]] <- list(
      universe_id = child_rows$universe_id[[i]],
      panel_mode = child_rows$pca_panel_mode[[i]],
      state_map = paste(child_rows$symbol[[i]], child_rows$state_count[[i]], sep = " / "),
      state_count = child_rows$state_count[[i]],
      run_dir = child_rows$run_dir[[i]],
      folds = g5_pca_wfa_read_csv_if_exists(paths$fold_spec_csv),
      scores = g5_pca_wfa_read_csv_if_exists(paths$pca_scores_csv),
      trades = g5_pca_wfa_read_csv_if_exists(paths$oos_trades_csv),
      equity = g5_pca_wfa_read_csv_if_exists(paths$oos_equity_csv),
      metrics = g5_pca_wfa_read_csv_if_exists(paths$oos_metrics_csv)
    )
  }
  items
}

g5_context_factorial_write_visual_sheet <- function(items, path, chart_type = c("pca_scatter", "strategy"), title = NULL, columns = 2L, width = 2600L, height = 1600L, res = 180L) {
  chart_type <- match.arg(chart_type)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  aesthetic <- g5_chart_aesthetic()
  columns <- max(1L, as.integer(columns))
  rows <- max(1L, ceiling(length(items) / columns))
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = as.integer(res))
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mfrow = c(rows, columns), mar = c(5.8, 4.1, 3.1, 1.4), oma = c(0, 0, 3.0, 0), bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  for (item in items) {
    if (identical(chart_type, "pca_scatter")) {
      g5_pca_wfa_draw_comparison_scatter_panel(item)
    } else {
      g5_pca_wfa_draw_comparison_strategy_panel(item)
    }
  }
  blanks <- rows * columns - length(items)
  if (blanks > 0L) {
    for (i in seq_len(blanks)) graphics::plot.new()
  }
  default_title <- if (identical(chart_type, "pca_scatter")) "PCA State-Space Visual Audit" else "Stitched OOS State-Band Visual Audit"
  graphics::mtext(if (is.null(title)) default_title else title, side = 3, outer = TRUE, line = 1, col = aesthetic$text, font = 2)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_context_factorial_write_state_map_visuals <- function(child_index, output_dir) {
  empty_index <- data.frame(
    chart_group = character(),
    chart_type = character(),
    symbol = character(),
    page_no = integer(),
    path = character(),
    stringsAsFactors = FALSE
  )
  if (!is.data.frame(child_index) || !nrow(child_index)) return(empty_index)
  required <- c("surface_id", "symbol", "run_dir", "pca_panel_mode", "state_count", "universe_id")
  if (!all(required %in% names(child_index))) return(empty_index)
  visual_dir <- file.path(output_dir, "state_visuals")
  dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
  rows <- list()
  add_row <- function(chart_group, chart_type, symbol, page_no, path) {
    rows[[length(rows) + 1L]] <<- data.frame(
      chart_group = chart_group,
      chart_type = chart_type,
      symbol = symbol,
      page_no = as.integer(page_no),
      path = normalizePath(path, winslash = "/", mustWork = FALSE),
      stringsAsFactors = FALSE
    )
  }
  fixed_ids <- c("behavioral_pool_quantile_grid_3x3", "behavioral_pool_kmeans_k9")
  auto_max15_triage_ids <- c("behavioral_pool_quantile_grid_3x3", "behavioral_pool_kmeans_k9", "behavioral_pool_kmeans_auto_max15")
  auto_ids <- c("behavioral_pool_kmeans_auto_max9", "behavioral_pool_kmeans_auto_max15")
  symbols <- sort(unique(as.character(child_index$symbol)))
  for (symbol in symbols) {
    fixed_rows <- child_index[child_index$symbol == symbol & child_index$surface_id %in% fixed_ids, , drop = FALSE]
    fixed_rows <- fixed_rows[match(fixed_ids, fixed_rows$surface_id), , drop = FALSE]
    fixed_rows <- fixed_rows[!is.na(fixed_rows$surface_id), , drop = FALSE]
    if (nrow(fixed_rows)) {
      fixed_items <- g5_context_factorial_child_visual_items(fixed_rows)
      scatter_path <- file.path(visual_dir, paste0("pair_", symbol, "_scatter.png"))
      strategy_path <- file.path(visual_dir, paste0("pair_", symbol, "_states.png"))
      g5_context_factorial_write_visual_sheet(fixed_items, scatter_path, chart_type = "pca_scatter", title = paste(symbol, "3x3 Quantile vs Fixed k9 PCA State Space"), columns = 2L)
      g5_context_factorial_write_visual_sheet(fixed_items, strategy_path, chart_type = "strategy", title = paste(symbol, "3x3 Quantile vs Fixed k9 Stitched OOS States"), columns = 2L)
      add_row("quantile_vs_fixed_k9", "pca_scatter", symbol, 1L, scatter_path)
      add_row("quantile_vs_fixed_k9", "stitched_oos_states", symbol, 1L, strategy_path)
    }
    auto_max15_triage_rows <- child_index[child_index$symbol == symbol & child_index$surface_id %in% auto_max15_triage_ids, , drop = FALSE]
    auto_max15_triage_rows <- auto_max15_triage_rows[match(auto_max15_triage_ids, auto_max15_triage_rows$surface_id), , drop = FALSE]
    auto_max15_triage_rows <- auto_max15_triage_rows[!is.na(auto_max15_triage_rows$surface_id), , drop = FALSE]
    if (nrow(auto_max15_triage_rows) == length(auto_max15_triage_ids)) {
      auto_max15_triage_items <- g5_context_factorial_child_visual_items(auto_max15_triage_rows)
      scatter_path <- file.path(visual_dir, paste0("amax15_", symbol, "_scatter.png"))
      strategy_path <- file.path(visual_dir, paste0("amax15_", symbol, "_states.png"))
      g5_context_factorial_write_visual_sheet(auto_max15_triage_items, scatter_path, chart_type = "pca_scatter", title = paste(symbol, "3x3 Quantile vs Fixed k9 vs Auto k15 PCA State Space"), columns = 3L, width = 3600L, height = 1500L)
      g5_context_factorial_write_visual_sheet(auto_max15_triage_items, strategy_path, chart_type = "strategy", title = paste(symbol, "3x3 Quantile vs Fixed k9 vs Auto k15 Stitched OOS States"), columns = 3L, width = 3600L, height = 1500L)
      add_row("auto_max15_triage", "pca_scatter", symbol, 1L, scatter_path)
      add_row("auto_max15_triage", "stitched_oos_states", symbol, 1L, strategy_path)
    }
  }
  auto_rows <- child_index[child_index$surface_id %in% auto_ids, , drop = FALSE]
  if (nrow(auto_rows)) {
    auto_rows <- auto_rows[order(auto_rows$surface_id, auto_rows$symbol), , drop = FALSE]
    pages <- split(auto_rows, ceiling(seq_len(nrow(auto_rows)) / 6L))
    for (page_no in seq_along(pages)) {
      page <- pages[[page_no]]
      items <- g5_context_factorial_child_visual_items(page)
      scatter_path <- file.path(visual_dir, paste0("auto_scatter_", sprintf("%02d", page_no), ".png"))
      strategy_path <- file.path(visual_dir, paste0("auto_states_", sprintf("%02d", page_no), ".png"))
      g5_context_factorial_write_visual_sheet(items, scatter_path, chart_type = "pca_scatter", title = "Auto k-Means PCA State Space by Symbol", columns = 3L, width = 3000L, height = 1800L)
      g5_context_factorial_write_visual_sheet(items, strategy_path, chart_type = "strategy", title = "Auto k-Means Stitched OOS States by Symbol", columns = 3L, width = 3000L, height = 1800L)
      add_row("auto_kmeans", "pca_scatter", "ALL", page_no, scatter_path)
      add_row("auto_kmeans", "stitched_oos_states", "ALL", page_no, strategy_path)
    }
  }
  if (!length(rows)) empty_index else do.call(rbind, rows)
}

g5_context_factorial_markdown_report <- function(paths, universe_defs, surface_defs, portfolio_index, summary, run_spec, child_metric_summary, state_coverage_summary, selected_family_summary, auto_cluster_summary, visual_audit_index, purpose, path) {
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  num <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", as.numeric(x)))
  dol <- function(x) ifelse(is.na(x), "NA", sprintf("$%.2f", as.numeric(x)))
  summary_table <- summary
  summary_table$ending_equity <- dol(summary_table$ending_equity)
  summary_table$total_return <- pct(summary_table$total_return)
  summary_table$cagr <- pct(summary_table$cagr)
  summary_table$max_drawdown <- pct(summary_table$max_drawdown)
  summary_table$sharpe <- num(summary_table$sharpe)
  lines <- c(
    "# Gen5.1 Context-Universe Factorial Portfolio Inspection",
    "",
    "Research/inspection only: this packet coordinates existing PCA-routed WFA child packets and the existing portfolio accounting surface. It is not accepted allocation evidence, live advice, execution logic, or a deployment gate.",
    "",
    "## Purpose",
    "",
    purpose,
    "",
    "## Run Context",
    "",
    paste0("- Research Candidate Universe: `", run_spec$research_candidate_symbols[[1L]], "`"),
    paste0("- Tradeable Universe: `", run_spec$tradeable_symbols[[1L]], "`"),
    paste0("- Active Allocation Set: `", run_spec$active_allocation_symbols[[1L]], "`"),
    paste0("- Surface count: `", run_spec$surface_count[[1L]], "`"),
    paste0("- Fold count: `", run_spec$fold_count[[1L]], "`"),
    paste0("- End date: `", run_spec$end_date[[1L]], "`"),
    paste0("- As-of timestamp: `", run_spec$as_of_timestamp[[1L]], "`"),
    paste0("- Strategy grid preset: `", run_spec$strategy_grid_preset[[1L]], "`"),
    "- Ownership policy: `entry_state_owns_trade_until_exit`.",
    "- Portfolio accounting policy: `dynamic_equal_slot_cash_capped`; no leverage, no optimizer, no live advice.",
    "",
    "## Context Universes",
    "",
    g5_pca_wfa_comparison_table_lines(universe_defs[, c("universe_id", "symbols", "active_overlap_count", "diversity_class", "similarity_class", "rationale"), drop = FALSE], c("universe_id", "symbols", "active_overlap_count", "diversity_class", "similarity_class", "rationale")),
    "",
    "## PCA Surfaces",
    "",
    g5_pca_wfa_comparison_table_lines(surface_defs[, c("surface_id", "pca_panel_mode", "state_engine", "state_count"), drop = FALSE], c("surface_id", "pca_panel_mode", "state_engine", "state_count")),
    "",
    "## Portfolio Accounting Summary",
    "",
    g5_pca_wfa_comparison_table_lines(summary_table, c("universe_id", "surface_id", "run_status", "ending_equity", "total_return", "cagr", "sharpe", "max_drawdown", "total_entry_fills", "total_skipped_entries", "total_cash_capped_entries")),
    "",
    "## Child Summaries",
    "",
    paste0("- Child OOS metrics: `", paths$child_metric_summary_csv, "`"),
    paste0("- Child state coverage: `", paths$state_coverage_summary_csv, "`"),
    paste0("- Selected-family summary: `", paths$selected_family_summary_csv, "`"),
    paste0("- Auto cluster summary: `", paths$auto_cluster_summary_csv, "`"),
    paste0("- Child metric rows: `", nrow(child_metric_summary), "`"),
    paste0("- State coverage rows: `", nrow(state_coverage_summary), "`"),
    paste0("- Selected-family rows: `", nrow(selected_family_summary), "`"),
    paste0("- Auto cluster rows: `", nrow(auto_cluster_summary), "`"),
    g5_pca_wfa_comparison_table_lines(auto_cluster_summary, c("surface_id", "symbol", "fold_id", "auto_min_clusters", "auto_max_clusters", "selected_cluster_count", "selection_criterion")),
    "",
    "## Visual Audit",
    "",
    paste0("- Visual audit index: `", paths$visual_audit_index_csv, "`"),
    g5_pca_wfa_comparison_table_lines(visual_audit_index, c("chart_group", "chart_type", "symbol", "page_no", "path")),
    "",
    "## Portfolio Packet Index",
    "",
    g5_pca_wfa_comparison_table_lines(portfolio_index[, c("universe_id", "surface_id", "run_status", "report_md", "chart_png", "metrics_csv", "child_artifact_index_csv"), drop = FALSE], c("universe_id", "surface_id", "run_status", "report_md", "chart_png", "metrics_csv", "child_artifact_index_csv")),
    "",
    "## Top-Level Outputs",
    "",
    paste0("- Run spec: `", paths$run_spec_csv, "`"),
    paste0("- Taxonomy: `", paths$taxonomy_csv, "`"),
    paste0("- Summary CSV: `", paths$summary_csv, "`"),
    paste0("- Portfolio packet index: `", paths$portfolio_index_csv, "`"),
    paste0("- Child artifact index: `", paths$child_artifact_index_csv, "`"),
    paste0("- Child OOS metrics: `", paths$child_metric_summary_csv, "`"),
    paste0("- Child state coverage: `", paths$state_coverage_summary_csv, "`"),
    paste0("- Selected-family summary: `", paths$selected_family_summary_csv, "`"),
    paste0("- Auto cluster summary: `", paths$auto_cluster_summary_csv, "`"),
    paste0("- Metrics overview chart: `", paths$metrics_overview_png, "`"),
    paste0("- Visual audit index: `", paths$visual_audit_index_csv, "`"),
    "",
    "## Leakage And Multiple-Comparison Guardrails",
    "",
    "- Context universes are declared before the run and are not selected from OOS outcomes.",
    "- PCA/state models fit inside each fold using TRAIN-side context rows only.",
    "- When the target symbol is not in the declared behavioral-pool context, target rows are scored for routing but excluded from PCA/state fitting.",
    "- Strategy selection remains TRAIN-only by fold/state, with `no_trade` as a first-class competitor.",
    "- Portfolio accounting consumes frozen child OOS trades and does not optimize allocations.",
    "- Compare all cells as inspection evidence only; do not choose a context universe, state map, or allocation policy from this packet without a later operator research gate.",
    "",
    "## STOP Decisions",
    "",
    "- Operator acceptance is required before using these outputs to choose a Regime Context Universe.",
    "- Operator acceptance is required before treating portfolio accounting output as research evidence or deployment evidence.",
    "- Any expansion to new strategy families, state maps, allocation methods, leverage, live advice, or execution remains out of scope."
  )
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_write_context_factorial_outputs <- function(universe_defs, surface_defs, output_dir, repo_root, as_of_timestamp, end_date, active_symbols, fold_count, strategy_grid_preset = "standard", refresh = FALSE, skip_child_runs = FALSE, purpose = g5_context_factorial_default_purpose()) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  active_symbols <- g5_portfolio_poc_symbols(active_symbols, "active_symbols")
  run_spec <- data.frame(
    schema_version = g5_context_factorial_schema_version(),
    run_id = basename(output_dir),
    as_of_timestamp = as.character(as_of_timestamp),
    end_date = as.character(as.Date(end_date)),
    refresh = as.logical(refresh),
    skip_child_runs = as.logical(skip_child_runs),
    research_candidate_symbols = paste(active_symbols, collapse = ","),
    tradeable_symbols = paste(active_symbols, collapse = ","),
    active_allocation_symbols = paste(active_symbols, collapse = ","),
    baseline_symbols = "SPY",
    surface_count = nrow(surface_defs),
    surface_ids = paste(surface_defs$surface_id, collapse = ","),
    fold_count = as.integer(fold_count),
    strategy_grid_preset = strategy_grid_preset,
    sizing_policy = "dynamic_equal_slot_cash_capped",
    purpose = purpose,
    stringsAsFactors = FALSE
  )
  portfolio_index <- g5_context_factorial_portfolio_index(universe_defs, surface_defs, repo_root, as_of_timestamp, active_symbols, fold_count, end_date, strategy_grid_preset)
  summary <- g5_context_factorial_summary(portfolio_index)
  child_index <- g5_context_factorial_child_artifact_index(portfolio_index)
  child_metric_summary <- g5_context_factorial_child_metric_summary(child_index)
  state_coverage_summary <- g5_context_factorial_state_coverage_summary(child_index)
  selected_family_summary <- g5_context_factorial_selected_family_summary(child_index)
  auto_cluster_summary <- g5_context_factorial_auto_cluster_summary(child_index)
  paths <- list(
    report_md = file.path(output_dir, "context_universe_factorial_report.md"),
    run_spec_csv = file.path(output_dir, "context_universe_factorial_run_spec.csv"),
    taxonomy_csv = file.path(output_dir, "context_universe_taxonomy.csv"),
    surface_definitions_csv = file.path(output_dir, "context_universe_factorial_surfaces.csv"),
    summary_csv = file.path(output_dir, "context_universe_factorial_summary.csv"),
    portfolio_index_csv = file.path(output_dir, "context_universe_factorial_portfolio_index.csv"),
    child_artifact_index_csv = file.path(output_dir, "context_universe_factorial_child_artifact_index.csv"),
    child_metric_summary_csv = file.path(output_dir, "context_universe_factorial_child_oos_metrics.csv"),
    state_coverage_summary_csv = file.path(output_dir, "context_universe_factorial_state_coverage.csv"),
    selected_family_summary_csv = file.path(output_dir, "context_universe_factorial_selected_families.csv"),
    auto_cluster_summary_csv = file.path(output_dir, "context_universe_factorial_auto_clusters.csv"),
    metrics_overview_png = file.path(output_dir, "context_universe_factorial_metrics_overview.png"),
    visual_audit_index_csv = file.path(output_dir, "context_universe_factorial_visual_audit_index.csv")
  )
  visual_audit_index <- g5_context_factorial_write_state_map_visuals(child_index, output_dir)
  utils::write.csv(run_spec, paths$run_spec_csv, row.names = FALSE)
  utils::write.csv(universe_defs, paths$taxonomy_csv, row.names = FALSE)
  utils::write.csv(surface_defs, paths$surface_definitions_csv, row.names = FALSE)
  utils::write.csv(summary, paths$summary_csv, row.names = FALSE)
  utils::write.csv(portfolio_index, paths$portfolio_index_csv, row.names = FALSE)
  utils::write.csv(child_index, paths$child_artifact_index_csv, row.names = FALSE)
  utils::write.csv(child_metric_summary, paths$child_metric_summary_csv, row.names = FALSE)
  utils::write.csv(state_coverage_summary, paths$state_coverage_summary_csv, row.names = FALSE)
  utils::write.csv(selected_family_summary, paths$selected_family_summary_csv, row.names = FALSE)
  utils::write.csv(auto_cluster_summary, paths$auto_cluster_summary_csv, row.names = FALSE)
  utils::write.csv(visual_audit_index, paths$visual_audit_index_csv, row.names = FALSE)
  paths$metrics_overview_png <- g5_context_factorial_write_metrics_overview(summary, paths$metrics_overview_png)
  paths$report_md <- g5_context_factorial_markdown_report(paths, universe_defs, surface_defs, portfolio_index, summary, run_spec, child_metric_summary, state_coverage_summary, selected_family_summary, auto_cluster_summary, visual_audit_index, purpose, paths$report_md)
  list(paths = paths, run_spec = run_spec, universe_definitions = universe_defs, surface_definitions = surface_defs, portfolio_index = portfolio_index, summary = summary, child_artifact_index = child_index, child_metric_summary = child_metric_summary, state_coverage_summary = state_coverage_summary, selected_family_summary = selected_family_summary, auto_cluster_summary = auto_cluster_summary, visual_audit_index = visual_audit_index)
}
