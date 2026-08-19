source(testthat::test_path("..", "..", "R", "gen5_lit_reg_01_1_hmm_engine.R"))
source(testthat::test_path("..", "..", "R", "gen5_lit_reg_01_2_hmm_volatility_poc.R"))

reg012_fast_contract <- function() {
  contract <- g5_reg012_contract()
  contract$gmm_seeds <- contract$gmm_seeds[1:4]
  contract$hmm_seeds <- contract$hmm_seeds[1:4]
  contract$self_transitions <- c(0.80, 0.90, 0.95, 0.98)
  contract
}

testthat::test_that("LIT-REG-01.2 contract freezes volatility-only scope", {
  contract <- g5_reg012_contract()
  registry <- g5_reg012_synthetic_registry()
  testthat::expect_equal(contract$literature_id, "LIT-REG-01.2")
  testthat::expect_equal(contract$development_symbol, "SPY")
  testthat::expect_equal(contract$replication_symbols, c("QQQ", "IWM", "EFA", "TLT"))
  testthat::expect_equal(contract$reference_package, "HiddenMarkov")
  testthat::expect_equal(contract$reference_version, "1.8.14")
  testthat::expect_equal(contract$hmm_seeds, 62201:62212)
  testthat::expect_equal(contract$confirmation_start, as.Date("2024-01-02"))
  testthat::expect_equal(nrow(registry), 60L)
  testthat::expect_equal(as.integer(table(registry$fixture_class)), c(20L, 20L, 20L))
})

testthat::test_that("approved reference package and Gen5 likelihood agree", {
  testthat::expect_silent(g5_reg012_require_reference())
  check <- g5_reg012_short_likelihood_check()
  testthat::expect_lte(check$difference, 1e-10)
})

testthat::test_that("univariate causal forward recursion is append invariant", {
  parameters <- g5_reg012_simulation_parameters("strong")
  simulated <- g5_hmm_simulate(
    250L,
    parameters$transition,
    matrix(parameters$means, ncol = 1L),
    lapply(parameters$sds^2, matrix, nrow = 1L, ncol = 1L),
    62001L
  )
  delta <- g5_hmm_stationary(parameters$transition)
  prefix <- g5_reg012_forward(
    simulated$observations[1:200, 1L], delta, parameters$transition,
    parameters$means, parameters$sds
  )
  full <- g5_reg012_forward(
    simulated$observations[, 1L], delta, parameters$transition,
    parameters$means, parameters$sds
  )
  testthat::expect_equal(prefix$filtered, full$filtered[1:200, ], tolerance = 1e-12)
  testthat::expect_equal(rowSums(full$filtered), rep(1, 250L), tolerance = 1e-12)
})

testthat::test_that("reference multistart returns ordered deterministic strong-state fits", {
  contract <- reg012_fast_contract()
  row <- g5_reg012_synthetic_registry()[1L, , drop = FALSE]
  row$observation_count <- 600L
  simulated <- g5_reg012_simulate_fixture(row)
  first <- g5_reg012_fit_reference_multistart(simulated$observations, contract)
  second <- g5_reg012_fit_reference_multistart(simulated$observations, contract)
  testthat::expect_false(is.null(first$selected))
  testthat::expect_equal(first$selected$means, second$selected$means, tolerance = 1e-10)
  testthat::expect_equal(first$selected$transition, second$selected$transition, tolerance = 1e-10)
  testthat::expect_lt(first$selected$means[[1L]], first$selected$means[[2L]])
  testthat::expect_lte(first$selected$crosscheck_difference_per_observation, 1e-8)
  testthat::expect_equal(rowSums(first$selected$filtered), rep(1, 600L), tolerance = 1e-12)
})

testthat::test_that("strong fixture can earn a valid two-state classification", {
  contract <- reg012_fast_contract()
  row <- g5_reg012_synthetic_registry()[2L, , drop = FALSE]
  row$observation_count <- 800L
  evaluated <- g5_reg012_evaluate_fixture(row, contract)
  testthat::expect_equal(evaluated$summary$status, "VALID_TWO_STATE_MODEL")
  testthat::expect_gte(evaluated$summary$filtered_accuracy, 0.85)
  testthat::expect_lte(evaluated$summary$maximum_transition_error, 0.10)
})

testthat::test_that("AR1 baseline uses only observed lag and finite innovations", {
  set.seed(62002L)
  x <- numeric(500L)
  for (index in 2:500) x[[index]] <- 0.2 + 0.7 * x[[index - 1L]] + stats::rnorm(1L, sd = 0.4)
  fit <- g5_reg012_fit_ar1(x)
  testthat::expect_equal(fit$model_id, "B2_AR1")
  testthat::expect_equal(fit$phi, 0.7, tolerance = 0.08)
  testthat::expect_true(is.finite(fit$log_likelihood))
  testthat::expect_gt(fit$sigma, 0)
})

testthat::test_that("identification failures abstain while crosscheck failures are numerical", {
  x <- stats::rnorm(100L)
  selected <- list(
    means = c(-0.1, 0.1), sds = c(1, 1), occupancy = c(0.5, 0.5),
    transition = matrix(c(0.6, 0.4, 0.4, 0.6), 2L, byrow = TRUE),
    log_likelihood = -140, crosscheck_difference_per_observation = 0
  )
  reference <- list(selected = selected)
  gmm <- list(selected = list(log_likelihood = -139))
  b0 <- list(log_likelihood = -141)
  abstain <- g5_reg012_identify(x, reference, gmm, b0)
  testthat::expect_equal(abstain$status, "TWO_STATES_NOT_IDENTIFIABLE_USE_BASELINE")
  reference$selected$crosscheck_difference_per_observation <- 1e-4
  failure <- g5_reg012_identify(x, reference, gmm, b0)
  testthat::expect_equal(failure$status, "NUMERICAL_FAILURE")
})
