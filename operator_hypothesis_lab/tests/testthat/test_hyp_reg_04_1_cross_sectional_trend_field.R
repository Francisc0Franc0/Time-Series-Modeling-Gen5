source(testthat::test_path("..", "..", "R", "hyp_reg_04_1_cross_sectional_trend_field.R"))

testthat::test_that("contract freezes four field dimensions and one external target", {
  x <- hreg41_contract()
  testthat::expect_equal(x$signal_assets, 24L)
  testthat::expect_equal(x$signal_groups, 4L)
  testthat::expect_equal(x$registry_assets, 25L)
  testthat::expect_equal(x$trend_fast, 20L)
  testthat::expect_equal(x$trend_slow, 60L)
  testthat::expect_equal(x$horizon, 20L)
})

testthat::test_that("causal helpers preserve alignment", {
  testthat::expect_equal(hreg41_lag(1:5, 2), c(NA, NA, 1, 2, 3))
  testthat::expect_equal(hreg41_lead(1:5, 2), c(3, 4, 5, NA, NA))
  testthat::expect_equal(hreg41_roll_sd(1:5, 3), c(NA, NA, 1, 1, 1))
  expected <- rep(NA_real_, 25)
  expected[1:4] <- log((1:25)[22:25] / (1:25)[2:5])
  testthat::expect_equal(hreg41_forward_open_return(1:25, 20), expected)
})

testthat::test_that("state contrasts follow state A minus state B", {
  x <- data.frame(
    state = rep(c("BROAD_UP", "BROAD_DOWN"), each = 4),
    future_field_return_h20 = c(.2, .1, .3, .1, -.2, -.1, .1, -.1),
    future_field_participation_h20 = c(.8, .7, .9, .6, .2, .3, .6, .4),
    spy_return_h20 = c(.1, .2, .2, .1, -.1, -.2, .1, -.1),
    spy_up_h20 = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE)
  )
  out <- hreg41_contrast(x, "BROAD_UP", "BROAD_DOWN")
  testthat::expect_equal(out$state_a_n, 4)
  testthat::expect_gt(out$field_return_gap, 0)
  testthat::expect_gt(out$field_participation_gap, 0)
  testthat::expect_gt(out$spy_return_gap, 0)
})

testthat::test_that("AUC rewards a correctly ordered positive-direction score", {
  testthat::expect_equal(hreg41_auc(c(.9, .8, .2, .1), c(TRUE, TRUE, FALSE, FALSE)), 1)
  testthat::expect_equal(hreg41_auc(c(.1, .2, .8, .9), c(TRUE, TRUE, FALSE, FALSE)), 0)
})

testthat::test_that("within-year circular shifts preserve state counts", {
  x <- data.frame(session_date = seq.Date(as.Date("2020-01-01"), by = "day", length.out = 20), state = rep(c("BROAD_UP", "FRAGILE_UP", "BROAD_DOWN", "FRAGILE_DOWN"), 5))
  shifted <- hreg41_shift_states(x, 1)
  testthat::expect_equal(sort(shifted), sort(x$state))
  testthat::expect_false(identical(shifted, x$state))
})

testthat::test_that("field construction preserves an unambiguously positive multi-asset trend", {
  dates <- seq.Date(as.Date("2019-01-01"), by = "day", length.out = 300)
  symbols <- sprintf("S%02d", 1:24)
  groups <- rep(c("G1", "G2", "G3", "G4"), each = 6)
  daily_return <- 0.002 + 0.0015 * sin(seq_along(dates) / 4) + 0.0005 * cos(seq_along(dates) / 11)
  close <- 100 * exp(cumsum(daily_return))
  make_bars <- function(symbol) data.frame(symbol = symbol, session_date = dates, open = close, high = close * 1.01, low = close * .99, close = close, volume = 1000)
  bars <- do.call(rbind, c(lapply(symbols, make_bars), list(make_bars("SPY"))))
  ledger <- hreg41_build_ledger(bars, symbols, groups)
  last <- tail(ledger[is.finite(ledger$direction_score) & is.finite(ledger$future_field_return_h20), ], 1)
  testthat::expect_gt(last$direction_score, 0)
  testthat::expect_equal(last$participation, 1)
  testthat::expect_equal(last$agreement, 1)
  testthat::expect_gt(last$future_field_return_h20, 0)
})

testthat::test_that("validation rejects confirmation and duplicate bars", {
  bars <- data.frame(symbol = "SPY", session_date = as.Date(c("2023-12-29", "2024-01-02")), open = 10, high = 11, low = 9, close = 10, volume = 100)
  testthat::expect_error(hreg41_validate_bars(bars), "Confirmation rows")
  testthat::expect_error(hreg41_validate_bars(bars[c(1, 1), ]), "invalid or duplicated")
})
