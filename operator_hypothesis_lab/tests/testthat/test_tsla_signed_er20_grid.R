source(testthat::test_path("..", "..", "R", "tsla_signed_er20_grid.R"))

testthat::test_that("HAC lag covers overlap and is bounded by the sample", {
  testthat::expect_equal(tsseg_hac_lag(100L, 5L, 10L), 14L)
  testthat::expect_equal(tsseg_hac_lag(10L, 20L, 20L), 9L)
})

testthat::test_that("BH adjustment preserves non-estimable cells", {
  observed <- tsseg_adjust_bh(c(0.01, NA, 0.20))
  testthat::expect_equal(observed[c(1L, 3L)], stats::p.adjust(c(0.01, 0.20), "BH"))
  testthat::expect_true(is.na(observed[[2L]]))
})

testthat::test_that("state measurements recover a simple positive relationship", {
  surface <- data.frame(
    direction_state = rep("UP_TREND", 40L),
    prior_cumulative_log_return = seq(-0.2, 0.2, length.out = 40L),
    forward_cumulative_log_return = seq(-0.1, 0.1, length.out = 40L)
  )
  observed <- tsseg_measure_state(surface, "UP_TREND", 1L, 1L)
  testthat::expect_equal(observed$estimation_status, "ESTIMATED")
  testthat::expect_equal(observed$pearson_correlation, 1, tolerance = 1e-12)
  testthat::expect_equal(observed$ols_slope, 0.5, tolerance = 1e-12)
})

testthat::test_that("sign asymmetry reports deterministic sparse branches", {
  surface <- data.frame(
    direction_state = rep("UP_TREND", 60L),
    prior_cumulative_log_return = seq(0.01, 0.60, length.out = 60L),
    forward_cumulative_log_return = seq(-0.1, 0.1, length.out = 60L)
  )
  observed <- tsseg_measure_sign_asymmetry(surface, "UP_TREND", 20L, 1L)
  testthat::expect_equal(observed$negative_observations, 0L)
  testthat::expect_equal(
    observed$estimation_status,
    "STRUCTURALLY_OR_EMPIRICALLY_SPARSE_BRANCH"
  )
  testthat::expect_true(is.na(observed$slope_interaction_hac_p_value))
})

testthat::test_that("state comparison estimates a slope interaction", {
  x <- rep(seq(-0.2, 0.2, length.out = 40L), 2L)
  state <- rep(c("SIDEWAYS", "UP_TREND"), each = 40L)
  y <- ifelse(state == "SIDEWAYS", 0.2 * x, 0.8 * x)
  surface <- data.frame(
    direction_state = state,
    prior_cumulative_log_return = x,
    forward_cumulative_log_return = y
  )
  observed <- tsseg_compare_states(surface, "SIDEWAYS", "UP_TREND", 1L, 1L)
  testthat::expect_equal(observed$estimation_status, "ESTIMATED")
  testthat::expect_equal(observed$contrast_minus_reference_ols_slope, 0.6, tolerance = 1e-10)
})
