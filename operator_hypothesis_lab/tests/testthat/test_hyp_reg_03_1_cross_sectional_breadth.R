source(testthat::test_path("..", "..", "R", "hyp_reg_03_1_cross_sectional_breadth.R"))

testthat::test_that("contract freezes the breadth design", {
  x <- hreg31_contract()
  testthat::expect_equal(x$moving_average, 20L)
  testthat::expect_equal(x$impulse_lookback, 20L)
  testthat::expect_equal(x$signal_assets, 10L)
  testthat::expect_equal(x$target_assets, 26L)
})

testthat::test_that("causal primitives use only trailing observations", {
  testthat::expect_equal(hreg31_sma(1:5, 3), c(NA, NA, 2, 3, 4))
  testthat::expect_equal(hreg31_prior_percentile(c(1, 2, 3, 4), 3), c(NA, NA, NA, 1))
  expected <- rep(NA_real_, 10); expected[1:7] <- log((1:10)[4:10] / (1:10)[2:8])
  testthat::expect_equal(hreg31_forward_open_return(1:10, 2), expected)
})

testthat::test_that("signal uses the median depth and literal participation", {
  symbols <- paste0("S", 1:10)
  dates <- seq.Date(as.Date("2016-01-04"), by = "day", length.out = 100)
  bars <- do.call(rbind, lapply(seq_along(symbols), function(i) {
    close <- seq(100, 120 + i, length.out = length(dates))
    data.frame(symbol = symbols[[i]], session_date = dates, open = close, high = close + 1, low = close - 1, close = close, volume = 1000)
  }))
  signal <- hreg31_build_signal(bars, symbols)
  last <- nrow(signal); depth_cols <- paste0("depth_", symbols)
  testthat::expect_equal(signal$breadth_score[last], stats::median(as.numeric(signal[last, depth_cols])))
  testthat::expect_equal(signal$participation_fraction[last], 1)
  testthat::expect_equal(signal$sector_inputs[last], 10)
})

testthat::test_that("validation rejects duplicates and confirmation data", {
  bars <- data.frame(symbol = "A", session_date = as.Date(c("2023-12-29", "2024-01-02")), open = 10, high = 11, low = 9, close = 10, volume = 100)
  testthat::expect_error(hreg31_validate_bars(bars), "Confirmation rows")
  testthat::expect_error(hreg31_validate_bars(bars[c(1, 1), ]), "invalid or duplicated")
})

testthat::test_that("direction metrics audit both classes", {
  m <- hreg31_direction_metrics(c(1, 1, -1, -1), c(1, -1, -1, 1))
  testthat::expect_equal(unname(m[c("up_recall", "down_recall", "balanced_accuracy")]), rep(.5, 3))
})

testthat::test_that("circular shifts preserve each year's values", {
  signal <- data.frame(session_date = seq.Date(as.Date("2020-01-01"), by = "day", length.out = 12), breadth_score = 1:12)
  shifted <- hreg31_shift_signal(signal, 1)
  testthat::expect_equal(sort(shifted), signal$breadth_score)
  testthat::expect_false(identical(shifted, signal$breadth_score))
})

testthat::test_that("hidden deterioration keeps only positive SPY trend", {
  n <- 200
  ledger <- data.frame(symbol = "SPY", session_date = seq.Date(as.Date("2018-01-02"), by = "day", length.out = n),
    target_trend_score = rep(c(1, -1), each = n / 2), breadth_impulse20 = rep(c(-1, 1), length.out = n),
    forward_return_h20 = rep(c(-.1, .1), length.out = n), forward_return_h63 = rep(c(-.2, .2), length.out = n),
    nonoverlap_h20 = rep(TRUE, n), nonoverlap_h63 = rep(TRUE, n))
  out <- hreg31_hidden_deterioration(ledger)
  testthat::expect_equal(nrow(out), 14)
  testthat::expect_true(all(out$decay_n[out$year == "ALL"] > 0))
})
