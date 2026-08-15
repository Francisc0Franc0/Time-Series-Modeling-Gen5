source(testthat::test_path("..", "..", "R", "hyp_reg_03_2_breadth_transition.R"))

testthat::test_that("contract freezes one H20 market target", {
  x <- hreg32_contract()
  testthat::expect_equal(x$horizon, 20L)
  testthat::expect_equal(x$sector_assets, 10L)
  testthat::expect_equal(x$registry_assets, 12L)
  testthat::expect_equal(x$simulations, 200L)
})

testthat::test_that("causal helpers have the intended alignment", {
  testthat::expect_equal(hreg32_sma(1:5, 3), c(NA, NA, 2, 3, 4))
  testthat::expect_equal(hreg32_prior_percentile(c(1, 2, 3, 4), 3), c(NA, NA, NA, 1))
  testthat::expect_equal(hreg32_lead(1:5, 2), c(3, 4, 5, NA, NA))
  expected <- rep(NA_real_, 25); expected[1:4] <- log((1:25)[22:25] / (1:25)[2:5])
  testthat::expect_equal(hreg32_forward_open_return(1:25, 20), expected)
})

testthat::test_that("state contrast follows narrowing minus healthy", {
  x <- data.frame(state = rep(c("NARROWING", "HEALTHY"), each = 4), forward_return_h20 = c(-.2, -.1, .1, -.1, .1, .2, .3, -.1))
  x$down_h20 <- x$forward_return_h20 < 0
  out <- hreg32_state_contrast(x)
  testthat::expect_equal(out$narrowing_n, 4)
  testthat::expect_lt(out$return_gap, 0)
  testthat::expect_gt(out$down_rate_gap, 0)
})

testthat::test_that("AUC rewards a correctly ordered downside score", {
  testthat::expect_equal(hreg32_auc(c(.9, .8, .2, .1), c(TRUE, TRUE, FALSE, FALSE)), 1)
  testthat::expect_equal(hreg32_auc(c(.1, .2, .8, .9), c(TRUE, TRUE, FALSE, FALSE)), 0)
})

testthat::test_that("within-year state shifts preserve eligible state counts", {
  x <- data.frame(session_date = seq.Date(as.Date("2020-01-01"), by = "day", length.out = 20), positive_spy_trend = TRUE,
    state = rep(c("HEALTHY", "NARROWING", "MIXED_BREADTH_WEAK", "MIXED_LEADERSHIP_WEAK"), 5))
  shifted <- hreg32_shift_states(x, 1)
  testthat::expect_equal(sort(shifted), sort(x$state))
  testthat::expect_false(identical(shifted, x$state))
})

testthat::test_that("validation rejects confirmation and duplicates", {
  bars <- data.frame(symbol = "SPY", session_date = as.Date(c("2023-12-29", "2024-01-02")), open = 10, high = 11, low = 9, close = 10, volume = 100)
  testthat::expect_error(hreg32_validate_bars(bars), "Confirmation rows")
  testthat::expect_error(hreg32_validate_bars(bars[c(1, 1), ]), "invalid or duplicated")
})
