source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_multifold.R"))

g5_test_wfa_multi_bars <- function(symbol = "AMD", close) {
  dates <- as.Date("2026-01-01") + seq_along(close) - 1L
  g5_test_wfa_multi_bars_for_dates(symbol = symbol, dates = dates, close = close)
}

g5_test_wfa_multi_bars_for_dates <- function(symbol = "AMD", dates, close) {
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

g5_test_multi_quarters_for_days <- function(days) {
  as.numeric(days) / (365.25 / 4)
}

test_that("multi-fold EMA WFA resolves rolling non-overlapping OOS folds", {
  bars <- g5_test_wfa_multi_bars(close = seq(10, 40, length.out = 35))

  folds <- g5_ema_cross_wfa_resolve_folds(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 3L
  )

  expect_equal(nrow(folds), 3L)
  expect_equal(folds$fold_id, c("fold_001", "fold_002", "fold_003"))
  expect_equal(folds$train_start_date, as.Date(c("2026-01-01", "2026-01-06", "2026-01-11")))
  expect_equal(folds$train_end_date, as.Date(c("2026-01-10", "2026-01-15", "2026-01-20")))
  expect_equal(folds$oos_start_date, as.Date(c("2026-01-11", "2026-01-16", "2026-01-21")))
  expect_equal(folds$oos_end_date, as.Date(c("2026-01-15", "2026-01-20", "2026-01-25")))
  expect_true(all(folds$oos_start_date[-1L] > folds$oos_end_date[-nrow(folds)]))
})

test_that("multi-fold EMA WFA rolls OOS folds by available sessions without overlap gaps", {
  dates <- as.Date("2026-01-01") + 0:60
  dates <- dates[!weekdays(dates) %in% c("Saturday", "Sunday")]
  bars <- g5_test_wfa_multi_bars_for_dates(close = seq(10, 60, length.out = length(dates)), dates = dates)

  folds <- g5_ema_cross_wfa_resolve_folds(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(10),
    fold_count = 3L
  )

  for (i in 2:nrow(folds)) {
    expected_start <- min(dates[dates > folds$oos_end_date[[i - 1L]]])
    expect_equal(folds$oos_start_date[[i]], expected_start)
    expect_gt(folds$oos_start_date[[i]], folds$oos_end_date[[i - 1L]])
  }
})

test_that("multi-fold EMA WFA fails loudly when three folds cannot fit", {
  bars <- g5_test_wfa_multi_bars(close = seq(10, 25, length.out = 16))

  expect_error(
    g5_ema_cross_wfa_resolve_folds(
      bars,
      symbol = "AMD",
      wfa_start_date = min(bars$session_date),
      wfa_end_date = max(bars$session_date),
      train_quarters = g5_test_multi_quarters_for_days(10),
      oos_quarters = g5_test_multi_quarters_for_days(5),
      fold_count = 3L
    ),
    "Insufficient data"
  )
})

test_that("multi-fold EMA WFA selects a model instance per fold and stitches OOS equity", {
  close <- c(
    10, 9, 8, 8, 9, 11, 13, 14, 13, 12,
    10, 8, 7, 8, 9, 10, 12, 14, 13, 11,
    10, 9, 11, 13, 15, 14, 13, 12, 14, 16,
    18, 17, 16, 18, 20
  )
  bars <- g5_test_wfa_multi_bars(close = close)

  wfa <- g5_ema_cross_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 2L,
    slow_periods = 4L,
    candidate_families = "ema_cross",
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 3L
  )

  expect_equal(nrow(wfa$folds), 3L)
  expect_equal(nrow(wfa$selected_models), 3L)
  expect_true(all(wfa$selected_models$strategy_family == "ema_cross"))
  expect_true(all(wfa$selected_models$model_instance_id == "ema_cross_fast2_slow4"))
  expect_equal(min(wfa$stitched_equity_curve$session_date), min(wfa$folds$oos_start_date))
  expect_equal(max(wfa$stitched_equity_curve$session_date), max(wfa$folds$oos_end_date))
  expect_equal(nrow(wfa$fold_oos_summary), 3L)
  expect_equal(wfa$model_stability$selected_fold_count[[1L]], 3L)
  expect_true("carried_across_fold_boundary" %in% names(wfa$stitched_trades) || nrow(wfa$stitched_trades) == 0L)
})

test_that("multi-fold WFA can evaluate EMA cross and Bollinger touch candidates together", {
  close <- c(
    10, 10, 10, 9, 7, 8, 11, 13, 15, 13,
    11, 9, 7, 8, 10, 12, 15, 14, 12, 10,
    8, 7, 9, 12, 14, 16, 13, 11, 9, 8,
    10, 13, 15, 14, 12, 10, 8, 9, 12, 15,
    17, 15, 13, 11, 10
  )
  bars <- g5_test_wfa_multi_bars(close = close)

  wfa <- g5_ema_cross_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 2L,
    slow_periods = 4L,
    bb_lookback_periods = c(3L, 4L),
    bb_sd_multipliers = c(1, 1.5),
    candidate_families = c("ema_cross", "bollinger_touch"),
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 3L
  )

  expect_equal(nrow(wfa$selected_models), 3L)
  expect_true(all(c("ema_cross", "bollinger_touch") %in% unique(wfa$train_parameter_performance$strategy_family)))
  expect_true(all(wfa$selected_models$strategy_family %in% c("ema_cross", "bollinger_touch")))
  expect_true(all(c("lookback_period", "sd_multiplier") %in% names(wfa$selected_models)))
})

test_that("multi-fold chart background spans cover plotted folds without side gaps", {
  folds <- data.frame(
    fold_id = c("fold_001", "fold_002", "fold_003"),
    fold_no = 1:3,
    oos_start_date = as.Date(c("2026-01-02", "2026-01-05", "2026-01-08")),
    oos_end_date = as.Date(c("2026-01-04", "2026-01-07", "2026-01-10")),
    stringsAsFactors = FALSE
  )
  session_dates <- as.Date("2026-01-01") + 0:8
  fold_ids <- c(rep("fold_001", 3L), rep("fold_002", 3L), rep("fold_003", 3L))

  spans <- g5_ema_cross_wfa_fold_background_spans(session_dates, folds, fold_ids = fold_ids)

  expect_equal(spans$fold_id, folds$fold_id)
  expect_equal(spans$xleft, c(0.5, 3.5, 6.5))
  expect_equal(spans$xright, c(3.5, 6.5, 9.5))
  expect_equal(spans$fill, c("#FFFFFF", "#F2F3F5", "#FFFFFF"))
})

test_that("multi-fold WFA stitched charts render fold-shaded PNGs", {
  close <- c(
    10, 9, 8, 8, 9, 11, 13, 14, 13, 12,
    10, 8, 7, 8, 9, 10, 12, 14, 13, 11,
    10, 9, 11, 13, 15, 14, 13, 12, 14, 16,
    18, 17, 16, 18, 20
  )
  bars <- g5_test_wfa_multi_bars(close = close)
  wfa <- g5_ema_cross_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 2L,
    slow_periods = 4L,
    candidate_families = "ema_cross",
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 3L
  )
  strategy_path <- tempfile("g5_wfa_multi_strategy_", fileext = ".png")
  equity_path <- tempfile("g5_wfa_multi_equity_", fileext = ".png")

  written_strategy <- g5_write_ema_cross_wfa_stitched_strategy_chart_png(wfa$stitched_indicators, wfa$stitched_trades, wfa$folds, "AMD", strategy_path)
  written_equity <- g5_write_ema_cross_wfa_stitched_equity_curve_png(wfa$stitched_equity_curve, wfa$folds, "AMD", equity_path)

  expect_true(file.exists(written_strategy))
  expect_true(file.exists(written_equity))
  expect_gt(file.info(written_strategy)$size, 0)
  expect_gt(file.info(written_equity)$size, 0)
  expect_identical(as.integer(readBin(written_strategy, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_equity, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})
