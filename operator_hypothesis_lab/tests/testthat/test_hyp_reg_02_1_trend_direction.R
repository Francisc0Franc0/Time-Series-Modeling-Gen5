source(testthat::test_path("..", "..", "R", "hyp_reg_02_1_trend_direction.R"))

testthat::test_that("contract freezes the development boundary and horizons", {
  contract <- hreg21_contract()
  testthat::expect_equal(contract$analysis_start, as.Date("2018-01-02"))
  testthat::expect_equal(contract$analysis_end, as.Date("2023-12-29"))
  testthat::expect_equal(contract$confirmation_start, as.Date("2024-01-02"))
  testthat::expect_equal(contract$horizons, c(5L, 20L, 63L))
})

testthat::test_that("SMA and percentile calculations are causal", {
  testthat::expect_equal(hreg21_sma(1:5, 3), c(NA, NA, 2, 3, 4))
  percentile <- hreg21_prior_percentile(c(1, 2, 3, 4), 3)
  testthat::expect_equal(percentile, c(NA, NA, NA, 1))
})

testthat::test_that("forward target begins at next open", {
  opens <- 1:10
  expected <- rep(NA_real_, 10)
  expected[1:7] <- log(opens[4:10] / opens[2:8])
  testthat::expect_equal(hreg21_forward_open_return(opens, 2), expected)
})

testthat::test_that("direction metrics retain both class recalls", {
  metrics <- hreg21_direction_metrics(c(1, 1, -1, -1), c(1, -1, -1, 1))
  testthat::expect_equal(unname(metrics[c("accuracy", "up_recall", "down_recall", "balanced_accuracy")]), rep(0.5, 4))
})

testthat::test_that("quintile spread is ordered from low to high", {
  spread <- hreg21_quintile_spread(c(0.1, 0.2, 0.9, 1), c(-0.2, -0.1, 0.1, 0.3))
  testthat::expect_equal(spread[["q1_n"]], 2)
  testthat::expect_equal(spread[["q5_n"]], 2)
  testthat::expect_equal(spread[["q5_q1_spread"]], 0.35)
})

testthat::test_that("ledger rejects confirmation data and duplicates", {
  bars <- data.frame(
    symbol = "TEST", session_date = as.Date(c("2023-12-29", "2024-01-02")),
    open = c(10, 11), high = c(11, 12), low = c(9, 10), close = c(10, 11), volume = c(100, 100)
  )
  testthat::expect_error(hreg21_validate_bars(bars), "Confirmation rows")
  duplicate <- bars[c(1, 1), ]
  testthat::expect_error(hreg21_validate_bars(duplicate), "invalid or duplicated")
})

testthat::test_that("asset ledger fixes target timing and non-overlap", {
  dates <- seq.Date(as.Date("2016-01-04"), by = "day", length.out = 1000)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5]
  n <- length(dates)
  bars <- data.frame(
    symbol = "TEST", session_date = dates,
    open = seq(100, 200, length.out = n), high = seq(101, 201, length.out = n),
    low = seq(99, 199, length.out = n), close = seq(100, 200, length.out = n), volume = rep(1000, n)
  )
  ledger <- hreg21_build_asset_ledger(bars)
  row <- which(ledger$session_date >= as.Date("2018-01-02"))[1]
  testthat::expect_equal(ledger$forward_return_h5[row], log(ledger$open[row + 6] / ledger$open[row + 1]))
  testthat::expect_true(ledger$nonoverlap_h5[row])
  testthat::expect_false(any(ledger$nonoverlap_h5[(row + 1):(row + 4)]))
})

testthat::test_that("deterministic shifts preserve each asset-year multiset", {
  ledger <- data.frame(
    symbol = rep(c("A", "B"), each = 8),
    session_date = rep(seq.Date(as.Date("2020-01-01"), by = "day", length.out = 8), 2),
    trend_score = 1:16
  )
  shifted <- hreg21_shift_scores(ledger, 1)
  groups <- split(seq_len(nrow(ledger)), interaction(ledger$symbol, format(ledger$session_date, "%Y"), drop = TRUE))
  for (idx in groups) testthat::expect_equal(sort(shifted[idx]), sort(ledger$trend_score[idx]))
  testthat::expect_false(identical(shifted, ledger$trend_score))
})

testthat::test_that("joint summaries preserve the fixed two by three design", {
  n <- 120
  ledger <- data.frame(
    symbol = rep(c("A", "B"), each = n / 2),
    trend_score = rep(seq(-1, 1, length.out = n / 2), 2),
    trend_sign = rep(rep(c("DOWN", "UP"), each = n / 4), 2),
    regime_state = rep(c("LOW", "MEDIUM", "HIGH"), length.out = n),
    atr_percentile = seq(0, 1, length.out = n),
    forward_return_h20 = seq(-0.1, 0.1, length.out = n),
    forward_return_h63 = seq(-0.2, 0.2, length.out = n),
    nonoverlap_h20 = rep(TRUE, n), nonoverlap_h63 = rep(TRUE, n)
  )
  testthat::expect_equal(nrow(hreg21_joint_state_summary(ledger)), 12)
  testthat::expect_equal(nrow(hreg21_joint_within_state(ledger)), 6)
})
