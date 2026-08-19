source(testthat::test_path("..", "..", "R", "gen5_lit_reg_01_1_hmm_engine.R"))
source(testthat::test_path("..", "..", "R", "gen5_lit_reg_01_1_hmm_poc.R"))

reg011_test_bars <- function() {
  dates <- seq(as.Date("2016-01-01"), by = "day", length.out = 15L)
  dates <- dates[!as.POSIXlt(dates)$wday %in% c(0L, 6L)]
  close <- 100 * exp(cumsum(c(0, rep(0.01, length(dates) - 1L))))
  data.frame(
    symbol = "SPY",
    session_date = dates,
    open = close * 0.998,
    high = close * 1.01,
    low = close * 0.99,
    close = close,
    volume = 1e6,
    adjusted = TRUE,
    timeframe = "1D",
    stringsAsFactors = FALSE
  )
}

testthat::test_that("LIT-REG-01.1 contract and synthetic fixtures are frozen", {
  contract <- g5_reg011_contract()
  fixtures <- g5_reg011_synthetic_fixtures()
  testthat::expect_equal(contract$literature_id, "LIT-REG-01.1")
  testthat::expect_equal(contract$symbol, "SPY")
  testthat::expect_equal(contract$analysis_end, as.Date("2023-12-29"))
  testthat::expect_equal(contract$confirmation_start, as.Date("2024-01-02"))
  testthat::expect_equal(contract$b1_h2_seeds, 61001:61020)
  testthat::expect_equal(contract$h3_seeds, 63001:63020)
  testthat::expect_equal(fixtures$fixture_version, "LIT_REG_01_1_SYNTHETIC_V1")
  testthat::expect_equal(fixtures$strong_seeds, 61101:61150)
  testthat::expect_equal(fixtures$weak_seeds, 61301:61350)
  changed <- contract
  changed$eigen_floor <- 1e-3
  testthat::expect_error(g5_reg011_validate_contract(changed), "Frozen LIT-REG-01.1 contract changed")
})

testthat::test_that("forward likelihood matches brute-force enumeration", {
  fixtures <- g5_reg011_synthetic_fixtures()
  simulated <- g5_hmm_simulate(
    7L, fixtures$strong$transition, fixtures$strong$means,
    fixtures$strong$covariances, 60001L
  )
  initial <- g5_hmm_stationary(fixtures$strong$transition)
  forward <- g5_hmm_forward_backward(
    simulated$observations, initial, fixtures$strong$transition,
    fixtures$strong$means, fixtures$strong$covariances
  )
  brute <- g5_hmm_bruteforce_loglikelihood(
    simulated$observations, initial, fixtures$strong$transition,
    fixtures$strong$means, fixtures$strong$covariances
  )
  testthat::expect_equal(forward$log_likelihood, brute, tolerance = 1e-10)
  testthat::expect_equal(rowSums(forward$filtered), rep(1, 7L), tolerance = 1e-12)
  testthat::expect_equal(rowSums(forward$smoothed), rep(1, 7L), tolerance = 1e-12)
})

testthat::test_that("causal filtering is append invariant while smoothing is retrospective", {
  fixtures <- g5_reg011_synthetic_fixtures()
  simulated <- g5_hmm_simulate(
    300L, fixtures$weak$transition, fixtures$weak$means,
    fixtures$weak$covariances, 60002L
  )
  initial <- g5_hmm_stationary(fixtures$weak$transition)
  prefix <- g5_hmm_forward_backward(
    simulated$observations[1:200, ], initial, fixtures$weak$transition,
    fixtures$weak$means, fixtures$weak$covariances
  )
  full <- g5_hmm_forward_backward(
    simulated$observations, initial, fixtures$weak$transition,
    fixtures$weak$means, fixtures$weak$covariances
  )
  testthat::expect_equal(prefix$filtered, full$filtered[1:200, ], tolerance = 1e-12)
  testthat::expect_gt(max(abs(prefix$smoothed - full$smoothed[1:200, ])), 1e-8)
})

testthat::test_that("deterministic fit orders states by expected log range", {
  fixtures <- g5_reg011_synthetic_fixtures()
  simulated <- g5_hmm_simulate(
    500L, fixtures$strong$transition, fixtures$strong$means,
    fixtures$strong$covariances, 60003L
  )
  fit_a <- g5_hmm_fit_hmm_once(simulated$observations, 2L, 70003L, 0.90)
  fit_b <- g5_hmm_fit_hmm_once(simulated$observations, 2L, 70003L, 0.90)
  testthat::expect_true(fit_a$converged)
  testthat::expect_equal(fit_a$log_likelihood, fit_b$log_likelihood, tolerance = 1e-12)
  ordered <- g5_hmm_order_fit(fit_a)
  testthat::expect_lt(ordered$means[1L, 2L], ordered$means[2L, 2L])
  testthat::expect_equal(rowSums(ordered$transition), c(1, 1), tolerance = 1e-12)
  testthat::expect_gte(min(g5_hmm_covariance_eigenvalues(ordered$covariances)), 1e-4 - 1e-12)
})

testthat::test_that("static and causal OOS scores remain finite", {
  fixtures <- g5_reg011_synthetic_fixtures()
  simulated <- g5_hmm_simulate(
    600L, fixtures$strong$transition, fixtures$strong$means,
    fixtures$strong$covariances, 60004L
  )
  train <- simulated$observations[1:500, ]
  oos <- simulated$observations[501:600, ]
  b0 <- g5_hmm_fit_b0(train)
  b1 <- g5_hmm_order_fit(g5_hmm_fit_gmm_once(train, 2L, 70004L))
  h2 <- g5_hmm_order_fit(g5_hmm_fit_hmm_once(train, 2L, 70004L, 0.90))
  scored <- g5_hmm_score_oos(oos, h2, tail(h2$filtered, 1L))
  testthat::expect_true(all(is.finite(g5_hmm_score_static(oos, b0))))
  testthat::expect_true(all(is.finite(g5_hmm_score_static(oos, b1))))
  testthat::expect_true(all(is.finite(scored$log_score)))
  testthat::expect_equal(rowSums(scored$prior), rep(1, 100L), tolerance = 1e-12)
  testthat::expect_equal(rowSums(scored$filtered), rep(1, 100L), tolerance = 1e-12)
})

testthat::test_that("bar validation rejects confirmation data and feature construction is causal", {
  contract <- g5_reg011_contract()
  dates <- seq(contract$query_start, contract$analysis_end, by = "day")
  dates <- dates[!as.POSIXlt(dates)$wday %in% c(0L, 6L)]
  close <- 100 * exp(cumsum(rep(0.0002, length(dates))))
  bars <- data.frame(
    symbol = "SPY", session_date = dates, open = close * 0.999,
    high = close * 1.01, low = close * 0.99, close = close,
    volume = 1e6, adjusted = TRUE, timeframe = "1D",
    stringsAsFactors = FALSE
  )
  checked <- g5_reg011_validate_bars(bars, contract)
  testthat::expect_true(all(checked$checks$passed))
  prefix <- g5_reg011_feature_frame(bars[1:1000, ], contract)
  # A partial frozen range must fail the exact boundary check without reading future rows.
  boundary <- prefix$checks[prefix$checks$check_id == "exact_requested_boundary", ]
  testthat::expect_false(boundary$passed)
  full <- g5_reg011_feature_frame(bars, contract)
  testthat::expect_equal(
    prefix$frame$log_return,
    full$frame$log_return[1:1000],
    tolerance = 0
  )
  testthat::expect_equal(
    prefix$frame$log_normalized_true_range,
    full$frame$log_normalized_true_range[1:1000],
    tolerance = 0
  )
})

testthat::test_that("covariance flooring and probability clamps enforce invariants", {
  sigma <- matrix(c(1, 1.01, 1.01, 1), 2L, 2L)
  floored <- g5_hmm_floor_covariance(sigma, 1e-4)
  testthat::expect_gte(min(eigen(floored, symmetric = TRUE)$values), 1e-4 - 1e-12)
  probability <- g5_hmm_normalize(c(0, 1))
  testthat::expect_equal(sum(probability), 1, tolerance = 1e-12)
  testthat::expect_true(all(probability > 0 & probability < 1))
})
