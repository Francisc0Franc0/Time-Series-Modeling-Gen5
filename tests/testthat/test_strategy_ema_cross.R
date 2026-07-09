source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))

g5_test_ema_bars <- function(symbol = "AMD", close = c(10, 9, 8, 8, 9, 11, 13, 14, 13, 12, 10, 8, 7, 8, 9, 10)) {
  dates <- as.Date("2026-01-01") + seq_along(close) - 1L
  data.frame(
    symbol = symbol,
    session_date = dates,
    open = close + 0.1,
    high = close + 1,
    low = close - 1,
    close = close,
    volume = seq_along(close) * 1000,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-24 17:30:00",
    latest_completed_session = max(dates),
    fetch_start_date = min(dates),
    fetch_end_date = max(dates),
    data_version_hash = paste0("h", seq_along(close)),
    stringsAsFactors = FALSE
  )
}

test_that("EMA helper seeds with an SMA and then applies recursive EMA", {
  expect_equal(g5_ema_cross_ema(1:5, 3L), c(NA_real_, NA_real_, 2, 3, 4))
  expect_true(all(is.na(g5_ema_cross_ema(1:2, 3L))))
  expect_error(g5_ema_cross_ema(1:5, 0L), "positive integer")
})

test_that("EMA cross strategy uses close signals and next-open executions", {
  bars <- g5_test_ema_bars()

  trades <- g5_ema_cross_trades(
    bars,
    symbol = "AMD",
    fast_period = 2L,
    slow_period = 4L,
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date)
  )

  expect_equal(nrow(trades), 1L)
  expect_identical(trades$trade_status[[1L]], "closed")
  expect_equal(trades$entry_signal_date[[1L]], as.Date("2026-01-06"))
  expect_equal(trades$entry_execution_date[[1L]], as.Date("2026-01-07"))
  expect_equal(trades$entry_execution_price[[1L]], 13.1)
  expect_equal(trades$exit_signal_date[[1L]], as.Date("2026-01-11"))
  expect_equal(trades$exit_execution_date[[1L]], as.Date("2026-01-12"))
  expect_equal(trades$exit_execution_price[[1L]], 8.1)
  expect_equal(trades$realized_return[[1L]], (8.1 / 13.1) - 1)
  expect_identical(trades$entry_execution_rule[[1L]], "next_session_open_after_entry_signal")
  expect_identical(trades$exit_execution_rule[[1L]], "next_session_open_after_exit_signal")
})

test_that("open EMA trades trace to latest close", {
  bars <- g5_test_ema_bars(close = c(10, 9, 8, 8, 9, 11, 13, 14))

  trades <- g5_ema_cross_trades(
    bars,
    symbol = "AMD",
    fast_period = 2L,
    slow_period = 4L,
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date)
  )

  expect_equal(nrow(trades), 1L)
  expect_identical(trades$trade_status[[1L]], "open")
  expect_equal(trades$entry_signal_date[[1L]], as.Date("2026-01-06"))
  expect_equal(trades$entry_execution_date[[1L]], as.Date("2026-01-07"))
  expect_true(is.na(trades$exit_execution_date[[1L]]))
  expect_equal(trades$trace_end_date[[1L]], max(bars$session_date))
  expect_equal(trades$trace_end_price[[1L]], 14)
  expect_equal(trades$unrealized_return[[1L]], (14 / 13.1) - 1)
})

test_that("chart event rows distinguish EMA signals from executions", {
  bars <- g5_test_ema_bars()
  trades <- g5_ema_cross_trades(
    bars,
    symbol = "AMD",
    fast_period = 2L,
    slow_period = 4L,
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date)
  )

  events <- g5_ema_cross_chart_events(trades)

  expect_identical(
    events$event_type,
    c("entry_signal", "entry_execution", "exit_signal", "exit_execution")
  )
  expect_equal(events$event_date, as.Date(c("2026-01-06", "2026-01-07", "2026-01-11", "2026-01-12")))
  expect_equal(events$event_price, c(11, 13.1, 10, 8.1))
})

test_that("EMA equity curve marks positions, cash, and buy-and-hold baseline", {
  bars <- g5_test_ema_bars()
  trades <- g5_ema_cross_trades(
    bars,
    symbol = "AMD",
    fast_period = 2L,
    slow_period = 4L,
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date)
  )

  curve <- g5_ema_cross_equity_curve(
    trades,
    bars,
    symbol = "AMD",
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date)
  )

  expect_equal(curve$strategy_equity[1:6], rep(1, 6))
  expect_equal(curve$strategy_equity[[7L]], 1 + ((13 / 13.1) - 1))
  expect_equal(curve$strategy_equity[[12L]], 1 + ((8.1 / 13.1) - 1))
  expect_equal(curve$strategy_equity[13:16], rep(curve$strategy_equity[[12L]], 4L))
  expect_equal(curve$buy_hold_equity[[16L]], 10 / 10)
  expect_equal(curve$in_position[1:16], c(rep(FALSE, 6), rep(TRUE, 5), rep(FALSE, 5)))
})

test_that("EMA leverage scales trade returns and equity path exposure", {
  bars <- g5_test_ema_bars()

  trades_1x <- g5_ema_cross_trades(bars, "AMD", 2L, 4L, min(bars$session_date), max(bars$session_date), leverage = 1)
  trades_18x <- g5_ema_cross_trades(bars, "AMD", 2L, 4L, min(bars$session_date), max(bars$session_date), leverage = 1.8)
  curve_1x <- g5_ema_cross_equity_curve(trades_1x, bars, "AMD", min(bars$session_date), max(bars$session_date))
  curve_18x <- g5_ema_cross_equity_curve(trades_18x, bars, "AMD", min(bars$session_date), max(bars$session_date))

  expect_equal(trades_18x$underlying_realized_return[[1L]], (8.1 / 13.1) - 1)
  expect_equal(trades_18x$realized_return[[1L]], 1.8 * ((8.1 / 13.1) - 1))
  expect_equal(curve_18x$strategy_equity[[12L]], 1 + 1.8 * ((8.1 / 13.1) - 1))
  expect_lt(curve_18x$strategy_equity[[12L]], curve_1x$strategy_equity[[12L]])
})

test_that("EMA parameter grid is sortable and selects the highest Sharpe row", {
  bars <- g5_test_ema_bars()

  evaluation <- g5_ema_cross_evaluate_grid(
    bars,
    symbol = "AMD",
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date),
    fast_periods = c(2L, 3L),
    slow_periods = c(4L, 5L),
    leverage = 1
  )

  expect_true(nrow(evaluation$parameter_performance) >= 1L)
  expect_true(all(evaluation$parameter_performance$fast_period < evaluation$parameter_performance$slow_period))
  sorted_sharpe <- ifelse(is.na(evaluation$parameter_performance$sharpe), -Inf, evaluation$parameter_performance$sharpe)
  expect_true(all(sorted_sharpe[-length(sorted_sharpe)] >= sorted_sharpe[-1L]))
  expect_identical(evaluation$selected$strategy_id[[1L]], evaluation$parameter_performance$strategy_id[[1L]])
})

test_that("EMA cross charts render PNG outputs", {
  bars <- g5_test_ema_bars()
  trades <- g5_ema_cross_trades(bars, "AMD", 2L, 4L, min(bars$session_date), max(bars$session_date))
  curve <- g5_ema_cross_equity_curve(trades, bars, "AMD", min(bars$session_date), max(bars$session_date))
  strategy_path <- tempfile("g5_ema_cross_strategy_", fileext = ".png")
  equity_path <- tempfile("g5_ema_cross_equity_", fileext = ".png")

  written_strategy <- g5_write_ema_cross_chart_png(
    bars,
    symbol = "AMD",
    trades = trades,
    fast_period = 2L,
    slow_period = 4L,
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date),
    path = strategy_path
  )
  written_equity <- g5_write_ema_cross_equity_curve_png(curve, symbol = "AMD", path = equity_path)

  expect_true(file.exists(written_strategy))
  expect_true(file.exists(written_equity))
  expect_gt(file.info(written_strategy)$size, 0)
  expect_gt(file.info(written_equity)$size, 0)
  expect_identical(as.integer(readBin(written_strategy, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_equity, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})
