source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))

g5_test_wfa_bars <- function(symbol = "AMD", close) {
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

g5_test_quarters_for_days <- function(days) {
  as.numeric(days) / (365.25 / 4)
}

test_that("one-fold EMA WFA fails loudly when the data window is too short", {
  bars <- g5_test_wfa_bars(close = rep(10, 12))

  expect_error(
    g5_ema_cross_wfa_resolve_one_fold(
      bars,
      symbol = "AMD",
      wfa_start_date = min(bars$session_date),
      wfa_end_date = max(bars$session_date),
      train_quarters = g5_test_quarters_for_days(10),
      oos_quarters = g5_test_quarters_for_days(5)
    ),
    "Insufficient data for one EMA WFA fold"
  )
})

test_that("one-fold EMA WFA resolves the earliest possible train and OOS windows", {
  bars <- g5_test_wfa_bars(close = seq(10, 30, length.out = 20))

  fold <- g5_ema_cross_wfa_resolve_one_fold(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    train_quarters = g5_test_quarters_for_days(10),
    oos_quarters = g5_test_quarters_for_days(5)
  )

  expect_equal(nrow(fold), 1L)
  expect_equal(fold$fold_id[[1L]], "fold_001")
  expect_equal(fold$train_start_date[[1L]], as.Date("2026-01-01"))
  expect_equal(fold$train_end_date[[1L]], as.Date("2026-01-11"))
  expect_equal(fold$oos_start_date[[1L]], as.Date("2026-01-12"))
  expect_equal(fold$oos_end_date[[1L]], as.Date("2026-01-17"))
  expect_equal(fold$train_session_count[[1L]], 11L)
  expect_equal(fold$oos_session_count[[1L]], 6L)
  expect_identical(fold$fold_policy[[1L]], "earliest_possible_single_fold")
})

test_that("one-fold EMA WFA allows a final train-close signal to execute at first OOS open", {
  bars <- g5_test_wfa_bars(close = c(10, 9, 8, 8, 8, 8, 8, 8, 8, 8, 12, 13, 14, 13, 12, 11, 10))

  wfa <- g5_ema_cross_wfa_run_one_fold(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 2L,
    slow_periods = 4L,
    train_quarters = g5_test_quarters_for_days(10),
    oos_quarters = g5_test_quarters_for_days(5)
  )

  expect_equal(wfa$train_selected$fast_period[[1L]], 2L)
  expect_equal(wfa$train_selected$slow_period[[1L]], 4L)
  expect_equal(nrow(wfa$oos_trades), 1L)
  expect_equal(wfa$oos_trades$entry_signal_date[[1L]], wfa$fold$train_end_date[[1L]])
  expect_equal(wfa$oos_trades$entry_execution_date[[1L]], wfa$fold$oos_start_date[[1L]])
  expect_equal(wfa$oos_trades$exit_execution_date[[1L]], wfa$fold$oos_end_date[[1L]])
  expect_equal(min(wfa$oos_equity_curve$session_date), wfa$fold$oos_start_date[[1L]])
  expect_equal(max(wfa$oos_equity_curve$session_date), wfa$fold$oos_end_date[[1L]])
  expect_true(wfa$oos_equity_curve$in_position[[1L]])
})

test_that("one-fold EMA WFA output charts render PNGs for the OOS slice", {
  bars <- g5_test_wfa_bars(close = c(10, 9, 8, 8, 8, 8, 8, 8, 8, 8, 12, 13, 14, 13, 12, 11, 10))
  wfa <- g5_ema_cross_wfa_run_one_fold(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 2L,
    slow_periods = 4L,
    train_quarters = g5_test_quarters_for_days(10),
    oos_quarters = g5_test_quarters_for_days(5)
  )
  strategy_path <- tempfile("g5_wfa_oos_strategy_", fileext = ".png")
  equity_path <- tempfile("g5_wfa_oos_equity_", fileext = ".png")

  written_strategy <- g5_write_ema_cross_chart_png(
    bars,
    symbol = "AMD",
    trades = wfa$oos_trades,
    fast_period = wfa$train_selected$fast_period[[1L]],
    slow_period = wfa$train_selected$slow_period[[1L]],
    trading_start_date = wfa$fold$train_end_date[[1L]],
    trading_end_date = wfa$fold$oos_end_date[[1L]],
    path = strategy_path
  )
  written_equity <- g5_write_ema_cross_equity_curve_png(wfa$oos_equity_curve, symbol = "AMD", path = equity_path)

  expect_true(file.exists(written_strategy))
  expect_true(file.exists(written_equity))
  expect_gt(file.info(written_strategy)$size, 0)
  expect_gt(file.info(written_equity)$size, 0)
  expect_identical(as.integer(readBin(written_strategy, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_equity, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})
