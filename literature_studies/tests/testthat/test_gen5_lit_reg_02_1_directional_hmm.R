source(testthat::test_path(
  "..", "..", "R", "gen5_lit_reg_02_1_directional_hmm_poc.R"
))

reg021_fast_contract <- function() {
  contract <- g5_reg021_contract()
  contract$starts <- contract$starts[1:2, , drop = FALSE]
  contract$forecast_paths <- 300L
  contract
}

testthat::test_that("LIT-REG-02.1 freezes a direction-first synthetic boundary", {
  contract <- g5_reg021_contract()
  testthat::expect_equal(contract$literature_id, "LIT-REG-02.1")
  testthat::expect_equal(contract$reference_package, "hmmTMB")
  testthat::expect_equal(contract$reference_version, "1.1.2")
  testthat::expect_equal(contract$horizon, 20L)
  testthat::expect_equal(nrow(g5_reg021_positive_registry()), 10L)
  testthat::expect_equal(nrow(g5_reg021_frontier_registry()), 64L)
  testthat::expect_equal(nrow(g5_reg021_stress_registry()), 10L)
  testthat::expect_true(all(g5_reg021_positive_registry()$financial_noise == FALSE))
})

testthat::test_that("approved hmmTMB reference is available at the frozen version", {
  testthat::expect_silent(g5_reg021_require_reference())
})

testthat::test_that("directional causal filtering is append invariant", {
  transition <- matrix(c(0.96, 0.04, 0.04, 0.96), 2L, byrow = TRUE)
  simulated <- g5_reg021_simulate_msar(
    400L, c(-0.003, 0.003), c(0.1, 0.1), c(0.012, 0.012), transition, 71999L
  )
  returns <- simulated$ret[-1L]
  lags <- simulated$ret[-400L]
  delta <- g5_reg021_stationary(transition)
  prefix <- g5_reg021_forward(
    returns[1:300], lags[1:300], transition, c(-0.003, 0.003),
    c(0.1, 0.1), c(0.012, 0.012), delta
  )
  full <- g5_reg021_forward(
    returns, lags, transition, c(-0.003, 0.003),
    c(0.1, 0.1), c(0.012, 0.012), delta
  )
  testthat::expect_equal(prefix$filtered, full$filtered[1:300, ], tolerance = 1e-12)
  testthat::expect_equal(rowSums(full$filtered), rep(1, 399L), tolerance = 1e-12)
})

testthat::test_that("package-native multistart recovers a clear directional process", {
  contract <- reg021_fast_contract()
  transition <- matrix(c(0.97, 0.03, 0.03, 0.97), 2L, byrow = TRUE)
  simulated <- g5_reg021_simulate_msar(
    900L, c(-0.003, 0.003), c(0.1, 0.1), c(0.012, 0.012), transition, 72000L
  )
  fitted <- g5_reg021_fit_multistart(simulated$ret, contract)
  testthat::expect_false(is.null(fitted$selected))
  testthat::expect_lt(fitted$selected$directional_score[[1L]], fitted$selected$directional_score[[2L]])
  testthat::expect_equal(unname(rowSums(fitted$selected$transition)), c(1, 1), tolerance = 1e-10)
  testthat::expect_lte(fitted$selected$crosscheck_difference_per_observation, 1e-8)
  testthat::expect_equal(sum(fitted$diagnostics$selected), 1L)
})

testthat::test_that("horizon probabilities and proper scores are finite", {
  probability <- g5_reg021_horizon_probability(
    last_return = 0,
    filtered_probability = c(0.1, 0.9),
    transition = matrix(c(0.97, 0.03, 0.03, 0.97), 2L, byrow = TRUE),
    alpha = c(-0.003, 0.003),
    phi = c(0.1, 0.1),
    sigma = c(0.012, 0.012),
    horizon = 20L,
    paths = 1000L,
    seed = 72100L
  )
  testthat::expect_gte(probability, 0)
  testthat::expect_lte(probability, 1)
  testthat::expect_gt(probability, 0.5)
  score <- g5_reg021_score_probability(c(0.1, 0.8), c(0, 1))
  testthat::expect_true(all(is.finite(unlist(score))))
  testthat::expect_lt(score$brier, 0.05)
})
