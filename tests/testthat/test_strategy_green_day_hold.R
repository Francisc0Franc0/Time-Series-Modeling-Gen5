source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_green_day_hold.R"))

g5_test_strategy_bars <- function(symbol = "AMD", dates, open, high, low, close) {
  data.frame(
    symbol = symbol,
    session_date = as.Date(dates),
    open = open,
    high = high,
    low = low,
    close = close,
    volume = seq_along(open) * 1000,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-24 17:30:00",
    latest_completed_session = max(as.Date(dates)),
    fetch_start_date = min(as.Date(dates)),
    fetch_end_date = max(as.Date(dates)),
    data_version_hash = paste0("h", seq_along(open)),
    stringsAsFactors = FALSE
  )
}

test_that("green-day hold strategy uses close signals and next-open executions", {
  bars <- g5_test_strategy_bars(
    dates = c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04", "2026-06-05"),
    open = c(10, 11, 12, 13, 14),
    high = c(11.5, 11.5, 13.5, 13.5, 14.5),
    low = c(9.5, 9.5, 11.5, 12.5, 13.5),
    close = c(11, 10, 13, 12.5, 14.2)
  )

  trades <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 2L)

  expect_equal(nrow(trades), 1L)
  expect_identical(trades$trade_status[[1L]], "closed")
  expect_equal(trades$entry_signal_date[[1L]], as.Date("2026-06-01"))
  expect_equal(trades$entry_execution_date[[1L]], as.Date("2026-06-02"))
  expect_equal(trades$entry_execution_price[[1L]], 11)
  expect_equal(trades$exit_signal_date[[1L]], as.Date("2026-06-03"))
  expect_equal(trades$exit_execution_date[[1L]], as.Date("2026-06-04"))
  expect_equal(trades$exit_execution_price[[1L]], 13)
  expect_equal(trades$realized_return[[1L]], (13 / 11) - 1)
  expect_identical(trades$entry_execution_rule[[1L]], "next_session_open_after_entry_signal")
  expect_identical(trades$exit_execution_rule[[1L]], "next_session_open_after_exit_signal")
})

test_that("open trades trace from entry execution to latest close", {
  bars <- g5_test_strategy_bars(
    dates = c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04"),
    open = c(10, 11, 12, 13),
    high = c(11.5, 12, 13, 14.5),
    low = c(9.5, 10.5, 11.5, 12.5),
    close = c(11, 11.5, 12.5, 14)
  )

  trades <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 3L)

  expect_equal(nrow(trades), 1L)
  expect_identical(trades$trade_status[[1L]], "open_exit_signal_pending_next_open")
  expect_equal(trades$entry_execution_index[[1L]], 2L)
  expect_equal(trades$exit_signal_index[[1L]], 4L)
  expect_true(is.na(trades$exit_execution_index[[1L]]))
  expect_equal(trades$trace_end_index[[1L]], 4L)
  expect_equal(trades$trace_end_price[[1L]], 14)
  expect_equal(trades$unrealized_return[[1L]], (14 / 11) - 1)
})

test_that("chart event rows distinguish signals from executions", {
  bars <- g5_test_strategy_bars(
    dates = c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04"),
    open = c(10, 11, 12, 13),
    high = c(11.5, 11.5, 13.5, 13.5),
    low = c(9.5, 9.5, 11.5, 12.5),
    close = c(11, 10, 13, 12.5)
  )

  trades <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 2L)
  events <- g5_green_day_hold_chart_events(trades)

  expect_identical(
    events$event_type,
    c("entry_signal", "entry_execution", "exit_signal", "exit_execution")
  )
  expect_equal(events$event_date, as.Date(c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04")))
  expect_equal(events$event_price, c(11, 11, 13, 13))
})

test_that("strategy metrics summarize closed and marked trade accounting", {
  bars <- g5_test_strategy_bars(
    dates = c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04"),
    open = c(10, 11, 12, 13),
    high = c(11.5, 11.5, 13.5, 13.5),
    low = c(9.5, 9.5, 11.5, 12.5),
    close = c(11, 10, 13, 12.5)
  )
  trades <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 2L)

  metrics <- g5_green_day_hold_metrics(trades, bars, symbol = "AMD")

  expect_equal(metrics$trade_count[[1L]], 1L)
  expect_equal(metrics$closed_trade_count[[1L]], 1L)
  expect_equal(metrics$open_trade_count[[1L]], 0L)
  expect_equal(metrics$win_count[[1L]], 1L)
  expect_equal(metrics$win_rate[[1L]], 1)
  expect_equal(metrics$compounded_closed_return[[1L]], (13 / 11) - 1)
  expect_equal(metrics$compounded_marked_return[[1L]], (13 / 11) - 1)
  expect_equal(metrics$average_holding_sessions[[1L]], 2)
  expect_equal(metrics$exposure_fraction[[1L]], 0.5)
  expect_equal(metrics$ending_equity[[1L]], 13 / 11)
  expect_equal(metrics$total_return[[1L]], (13 / 11) - 1)
  expect_true(is.finite(metrics$cagr[[1L]]))
  expect_equal(metrics$max_drawdown[[1L]], (10 / 11) - 1)
  expect_equal(metrics$underwater_session_count[[1L]], 1L)
  expect_equal(metrics$underwater_fraction[[1L]], 0.25)
  expect_equal(metrics$buy_hold_total_return[[1L]], (12.5 / 11) - 1)
})

test_that("strategy equity curve marks daily closes and buy-and-hold baseline", {
  bars <- g5_test_strategy_bars(
    dates = c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04"),
    open = c(10, 11, 12, 13),
    high = c(11.5, 11.5, 13.5, 13.5),
    low = c(9.5, 9.5, 11.5, 12.5),
    close = c(11, 10, 13, 12.5)
  )
  trades <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 2L)

  curve <- g5_green_day_hold_equity_curve(trades, bars, symbol = "AMD")

  expect_equal(curve$strategy_equity, c(1, 10 / 11, 13 / 11, 13 / 11))
  expect_equal(curve$buy_hold_equity, c(1, 10 / 11, 13 / 11, 12.5 / 11))
  expect_equal(curve$strategy_drawdown, c(0, (10 / 11) - 1, 0, 0))
  expect_equal(curve$in_position, c(FALSE, TRUE, TRUE, FALSE))
})

test_that("1.8 leverage exaggerates trade returns and equity drawdowns", {
  bars <- g5_test_strategy_bars(
    dates = c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04"),
    open = c(10, 11, 12, 13),
    high = c(11.5, 11.5, 13.5, 13.5),
    low = c(9.5, 9.5, 11.5, 12.5),
    close = c(11, 10, 13, 12.5)
  )

  trades_1x <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 2L, leverage = 1)
  trades_18x <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 2L, leverage = 1.8)
  curve_1x <- g5_green_day_hold_equity_curve(trades_1x, bars, symbol = "AMD")
  curve_18x <- g5_green_day_hold_equity_curve(trades_18x, bars, symbol = "AMD")
  metrics_18x <- g5_green_day_hold_metrics(trades_18x, bars, symbol = "AMD", equity_curve = curve_18x)

  expect_equal(trades_18x$underlying_realized_return[[1L]], (13 / 11) - 1)
  expect_equal(trades_18x$realized_return[[1L]], 1.8 * ((13 / 11) - 1))
  expect_equal(curve_18x$strategy_equity, c(1, 1 + 1.8 * ((10 / 11) - 1), 1 + 1.8 * ((13 / 11) - 1), 1 + 1.8 * ((13 / 11) - 1)))
  expect_lt(metrics_18x$max_drawdown[[1L]], min(curve_1x$strategy_drawdown))
  expect_gt(metrics_18x$total_return[[1L]], tail(curve_1x$strategy_equity, 1L) - 1)
})

test_that("green-day hold strategy chart renders a PNG with signal and execution markers", {
  bars <- g5_test_strategy_bars(
    dates = c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04", "2026-06-05"),
    open = c(10, 11, 12, 13, 14),
    high = c(11.5, 11.5, 13.5, 13.5, 14.5),
    low = c(9.5, 9.5, 11.5, 12.5, 13.5),
    close = c(11, 10, 13, 12.5, 14.2)
  )
  trades <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 2L)
  png_path <- tempfile("g5_green_day_hold_", fileext = ".png")

  written <- g5_write_green_day_hold_chart_png(bars, symbol = "AMD", trades = trades, path = png_path)

  expect_true(file.exists(written))
  expect_gt(file.info(written)$size, 0)
  signature <- readBin(written, what = "raw", n = 8L)
  expect_identical(as.integer(signature), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})

test_that("green-day hold equity curve chart renders a PNG with underwater shading", {
  bars <- g5_test_strategy_bars(
    dates = c("2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04"),
    open = c(10, 11, 12, 13),
    high = c(11.5, 11.5, 13.5, 13.5),
    low = c(9.5, 9.5, 11.5, 12.5),
    close = c(11, 10, 13, 12.5)
  )
  trades <- g5_green_day_hold_trades(bars, symbol = "AMD", hold_sessions = 2L)
  curve <- g5_green_day_hold_equity_curve(trades, bars, symbol = "AMD")
  png_path <- tempfile("g5_green_day_hold_equity_", fileext = ".png")

  written <- g5_write_green_day_hold_equity_curve_png(curve, symbol = "AMD", path = png_path)

  expect_true(file.exists(written))
  expect_gt(file.info(written)$size, 0)
  signature <- readBin(written, what = "raw", n = 8L)
  expect_identical(as.integer(signature), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})

test_that("chart aesthetic exposes stable signal and execution markers", {
  aesthetic <- g5_chart_aesthetic()

  expect_identical(aesthetic$entry_signal_color, "#00B4D8")
  expect_identical(aesthetic$entry_signal_pch, 21L)
  expect_identical(aesthetic$exit_signal_color, "#FF9F1C")
  expect_identical(aesthetic$exit_signal_pch, 22L)
  expect_identical(aesthetic$native_entry_pch, 24L)
  expect_identical(aesthetic$native_exit_pch, 25L)
})
