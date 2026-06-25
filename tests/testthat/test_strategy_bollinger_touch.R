source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))

g5_test_bollinger_bars <- function(close) {
  dates <- as.Date("2026-01-01") + seq_along(close) - 1L
  data.frame(
    symbol = "AMD",
    session_date = dates,
    open = close,
    high = close + 0.5,
    low = close - 0.5,
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

test_that("Bollinger touch indicators expose lower and upper band touch signals", {
  bars <- g5_test_bollinger_bars(c(10, 10, 10, 10, 6, 8, 10, 12, 15, 13, 11, 9))

  ind <- g5_bollinger_touch_indicators(bars, "AMD", lookback_period = 3L, sd_multiplier = 1)

  expect_true(any(ind$entry_signal, na.rm = TRUE))
  expect_true(any(ind$exit_signal, na.rm = TRUE))
  expect_true(all(c("bb_mid", "bb_upper", "bb_lower") %in% names(ind)))
  expect_equal(ind$model_instance_id[[1L]], "bollinger_touch_n3_sd1")
})

test_that("Bollinger touch grid evaluates model instances with shared metrics", {
  bars <- g5_test_bollinger_bars(c(10, 10, 10, 10, 6, 8, 10, 12, 15, 13, 11, 9, 7, 8, 11, 14))

  evaluation <- g5_bollinger_touch_evaluate_grid(
    bars,
    symbol = "AMD",
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date),
    lookback_periods = c(3L, 4L),
    sd_multipliers = c(1, 1.5)
  )

  expect_equal(nrow(evaluation$parameter_performance), 4L)
  expect_true(all(evaluation$parameter_performance$strategy_family == "bollinger_touch"))
  expect_true("sharpe" %in% names(evaluation$selected))
  expect_true(grepl("^bollinger_touch_", evaluation$selected$model_instance_id[[1L]]))
})
