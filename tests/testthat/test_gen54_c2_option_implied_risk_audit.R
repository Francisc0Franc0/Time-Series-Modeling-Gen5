source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_poc.R"))
source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_risk_audit.R"))
source(testthat::test_path("..", "..", "R", "gen54_c2_option_implied_risk_audit.R"))

testthat::test_that("partial Spearman removes a relationship explained by drawdown", {
  set.seed(54)
  z <- 1:200
  x <- z + stats::rnorm(200, 0, 4)
  y <- z + stats::rnorm(200, 0, 4)
  direct <- stats::cor(x, y, method = "spearman")
  partial <- g5_gen54_c2_partial_spearman(x, y, z)
  testthat::expect_gt(direct, 0.95)
  testthat::expect_lt(abs(partial), 0.2)
})

testthat::test_that("VIX joins by same feature date without filling gaps", {
  context <- data.frame(
    feature_date = as.Date("2024-01-02") + 0:2,
    spy_drawdown_126 = 0.1,
    forward_realized_volatility_h5 = 0.2,
    forward_realized_volatility_h20 = 0.2,
    label_end_date_h5 = as.Date("2024-01-08") + 0:2,
    label_end_date_h20 = as.Date("2024-01-23") + 0:2
  )
  vix <- data.frame(observation_date = context$feature_date[c(1, 3)], close = c(14, 18))
  joined <- g5_gen54_c2_join_vix(context, vix)
  testthat::expect_equal(joined$vix_30d_close[c(1, 3)], c(0.14, 0.18))
  testthat::expect_true(is.na(joined$vix_30d_close[[2L]]))
})

testthat::test_that("C2 promotion requires direct and incremental evidence at both horizons", {
  audit <- expand.grid(
    fold_id = paste0("F", 1:20),
    horizon = g5_gen54_c1_horizons(),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  audit$train_vix_median <- 0.2
  audit$oos_dates <- 40L
  audit$high_state_share <- 0.5
  audit$rank_correlation <- 0.2
  audit$partial_rank_correlation_controlling_spy_drawdown <- 0.1
  audit$high_state_mean_realized_volatility <- 0.3
  audit$low_state_mean_realized_volatility <- 0.2
  audit$separation_realized_volatility <- 0.1
  passed <- g5_gen54_c2_verdict(audit)
  testthat::expect_identical(passed$overall_status, "PASS_TO_RISK_POLICY_THEORY_SESSION")
  audit$partial_rank_correlation_controlling_spy_drawdown[audit$horizon == 20L] <- -0.1
  stopped <- g5_gen54_c2_verdict(audit)
  testthat::expect_identical(stopped$overall_status, "REDUNDANT_WITH_PRICE_STRESS")
})

testthat::test_that("C2 distinguishes continuous ordering from unstable median states", {
  audit <- expand.grid(
    fold_id = paste0("F", 1:20),
    horizon = g5_gen54_c1_horizons(),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  audit$train_vix_median <- 0.2
  audit$oos_dates <- 40L
  audit$high_state_share <- 0.5
  audit$rank_correlation <- 0.2
  audit$partial_rank_correlation_controlling_spy_drawdown <- 0.1
  audit$high_state_mean_realized_volatility <- 0.3
  audit$low_state_mean_realized_volatility <- 0.2
  audit$separation_realized_volatility <- 0.1
  audit$separation_realized_volatility[audit$fold_id %in% paste0("F", 1:9)] <- -0.01
  verdict <- g5_gen54_c2_verdict(audit)
  testthat::expect_true(all(verdict$horizon_summary$correlation_verdict == "PASS_CONTINUOUS_RISK_ORDERING"))
  testthat::expect_true(all(verdict$horizon_summary$separation_verdict == "STOP_MEDIAN_STATE_SEPARATION"))
  testthat::expect_identical(verdict$overall_status, "STOP_THRESHOLD_INSTABILITY")
})
