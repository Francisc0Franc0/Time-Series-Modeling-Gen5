source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_poc.R"))
source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_risk_audit.R"))

testthat::test_that("observed basket returns use eligibility frozen two sessions earlier", {
  returns <- matrix(rep(1:6, each = 3), nrow = 6, byrow = TRUE)
  eligibility <- matrix(FALSE, nrow = 6, ncol = 3)
  eligibility[1, 1:2] <- TRUE
  eligibility[2, 2:3] <- TRUE
  out <- g5_gen54_c1_observed_basket_returns(returns, eligibility, minimum_cross_section = 2L)
  testthat::expect_true(all(is.na(out[1:2])))
  testthat::expect_equal(out[[3]], mean(returns[3, 1:2]))
  testthat::expect_equal(out[[4]], mean(returns[4, 2:3]))
})

testthat::test_that("forward realized volatility starts after the next execution open", {
  returns <- seq(0.001, 0.030, length.out = 30)
  out <- g5_gen54_c1_forward_realized_vol(returns, 5L)
  testthat::expect_equal(out[[10]], stats::sd(returns[12:16]) * sqrt(252))
  changed <- returns
  changed[1:11] <- 10
  testthat::expect_equal(out[[10]], g5_gen54_c1_forward_realized_vol(changed, 5L)[[10]])
})

testthat::test_that("C1 thresholds are estimated from TRAIN only", {
  dates <- as.Date("2018-01-01") + 0:1095
  context <- data.frame(feature_date = dates, stringsAsFactors = FALSE)
  for (feature in g5_gen54_c1_feature_names()) context[[feature]] <- seq_along(dates)
  for (horizon in g5_gen54_c1_horizons()) {
    context[[paste0("forward_realized_volatility_h", horizon)]] <- seq_along(dates) / 1000
    context[[paste0("label_end_date_h", horizon)]] <- dates + horizon + 1L
  }
  fold <- data.frame(fold_no = 1L, fold_id = "2020Q1", window_id = "2020Y", train_start_date = as.Date("2018-01-01"), train_end_date = as.Date("2019-12-31"), oos_start_date = as.Date("2020-01-01"), oos_end_date = as.Date("2020-03-31"))
  first <- g5_gen54_c1_fold_audit(context, fold)
  context[context$feature_date >= fold$oos_start_date, g5_gen54_c1_feature_names()] <- 1e9
  second <- g5_gen54_c1_fold_audit(context, fold)
  testthat::expect_equal(first$train_threshold, second$train_threshold)
})

testthat::test_that("C1 promotion requires both frozen horizons", {
  rows <- expand.grid(
    fold_id = paste0("F", 1:20),
    feature_name = g5_gen54_c1_feature_names(),
    horizon = g5_gen54_c1_horizons(),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$train_threshold <- 0.5
  rows$oos_dates <- 40L
  rows$high_state_share <- 0.5
  rows$rank_correlation <- 0.2
  rows$high_state_mean_realized_volatility <- 0.3
  rows$low_state_mean_realized_volatility <- 0.2
  rows$separation_realized_volatility <- 0.1
  rows$rank_correlation[rows$feature_name == "spy_drawdown_126" & rows$horizon == 20L] <- -0.2
  rows$separation_realized_volatility[rows$feature_name == "spy_drawdown_126" & rows$horizon == 20L] <- -0.1
  verdict <- g5_gen54_c1_verdict(rows)
  testthat::expect_identical(verdict$feature_summary$final_verdict[verdict$feature_summary$feature_name == "basket_realized_volatility_20"], "PASS_TO_RISK_SCALER_DESIGN")
  testthat::expect_identical(verdict$feature_summary$final_verdict[verdict$feature_summary$feature_name == "spy_drawdown_126"], "STOP_C1_RISK_PRIMITIVE")
})
