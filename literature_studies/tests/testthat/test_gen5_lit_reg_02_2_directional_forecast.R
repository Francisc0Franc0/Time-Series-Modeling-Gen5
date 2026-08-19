source(testthat::test_path(
  "..", "..", "R", "gen5_lit_reg_02_1_directional_hmm_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_reg_02_2_directional_forecast_poc.R"
))

testthat::test_that("02.2 contract is forecast-first and disjoint", {
  contract <- g5_reg022_contract()
  testthat::expect_identical(contract$literature_id, "LIT-REG-02.2")
  testthat::expect_identical(contract$positive_seeds, 75001:75024)
  testthat::expect_false(any(contract$positive_seeds %in% 72001:74010))
  testthat::expect_equal(contract$ridge_lambda, 1)
  testthat::expect_equal(contract$horizon, 20L)
  testthat::expect_equal(contract$minimum_case_wins, 15L)
})

testthat::test_that("ridge features use only information through the origin", {
  returns <- seq(-0.02, 0.03, length.out = 80)
  original <- g5_reg022_feature_values(returns, 40L)
  changed_future <- returns
  changed_future[41:80] <- 100
  testthat::expect_equal(
    original,
    g5_reg022_feature_values(changed_future, 40L),
    tolerance = 0
  )
  changed_present <- returns
  changed_present[[40L]] <- 1
  testthat::expect_false(isTRUE(all.equal(
    original,
    g5_reg022_feature_values(changed_present, 40L)
  )))
})

testthat::test_that("ridge training origins and targets are non-overlapping", {
  set.seed(101)
  design <- g5_reg022_training_design(stats::rnorm(240), 20L)
  testthat::expect_true(all(diff(design$origins) == 20L))
  testthat::expect_true(all(design$origins + 20L <= 240L))
  testthat::expect_equal(nrow(design$features), length(design$outcome))
  testthat::expect_equal(colnames(design$features), c("ret_1", "ret_5", "ret_20", "vol_20"))
})

testthat::test_that("fixed ridge challenger is deterministic", {
  set.seed(202)
  returns <- 0.0004 + stats::rnorm(600, sd = 0.012)
  first <- g5_reg022_fit_ridge(returns)
  second <- g5_reg022_fit_ridge(returns)
  testthat::expect_true(first$valid)
  testthat::expect_true(second$valid)
  testthat::expect_equal(first$coefficients, second$coefficients, tolerance = 0)
  features <- g5_reg022_feature_values(returns, 600L)
  testthat::expect_equal(
    g5_reg022_predict_ridge(first, features),
    g5_reg022_predict_ridge(second, features),
    tolerance = 0
  )
})

testthat::test_that("frontier and stress registries preserve unread seeds", {
  frontier <- g5_reg022_frontier_registry()
  stress <- g5_reg022_stress_registry()
  testthat::expect_equal(nrow(frontier), 64L)
  testthat::expect_identical(frontier$seed, 73001:73064)
  testthat::expect_equal(nrow(stress), 10L)
  testthat::expect_identical(stress$seed, 74001:74010)
  testthat::expect_equal(sort(unique(frontier$drift)), c(0, 0.0005, 0.0015, 0.003))
})

testthat::test_that("paired upper bound and calibration are finite", {
  candidate <- c(0.20, 0.21, 0.19, 0.22, 0.18)
  baseline <- candidate + 0.03
  testthat::expect_lt(g5_reg022_paired_upper(candidate, baseline), 0)
  forecasts <- data.frame(
    outcome = rep(c(0L, 1L), 20),
    p_h2 = rep(c(0.30, 0.70), 20)
  )
  calibration <- g5_reg022_calibration(forecasts)
  testthat::expect_true(all(is.finite(unlist(calibration[c(
    "intercept", "slope", "sharpness", "observations"
  )]))))
  testthat::expect_gt(calibration$slope, 0)
})

testthat::test_that("frontier detection requires wins against all baselines", {
  summary <- data.frame(
    train_length = rep(1000L, 4),
    self_transition = rep(0.97, 4),
    drift = rep(0.003, 4),
    valid_fit = TRUE,
    b2_valid = TRUE,
    brier_h2 = rep(0.20, 4),
    brier_b0 = rep(0.24, 4),
    brier_b1 = rep(0.23, 4),
    brier_b2 = rep(0.22, 4),
    logloss_h2 = rep(0.60, 4),
    logloss_b0 = rep(0.68, 4),
    logloss_b1 = rep(0.66, 4),
    logloss_b2 = rep(0.64, 4),
    filtered_accuracy = rep(0.75, 4)
  )
  detected <- g5_reg022_frontier_summary(summary)
  testthat::expect_true(detected$detection_boundary_cell)
  summary$brier_b2[[1L]] <- 0.19
  summary$brier_b2[[2L]] <- 0.19
  not_detected <- g5_reg022_frontier_summary(summary)
  testthat::expect_false(not_detected$detection_boundary_cell)
})
