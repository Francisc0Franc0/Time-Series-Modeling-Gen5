source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_poc.R"))
source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_ohlcv_extension.R"))

testthat::test_that("one-step residuals do not use future returns", {
  n <- 220L
  market <- sin(seq_len(n) / 13) / 100
  peer <- cos(seq_len(n) / 17) / 100
  asset <- 0.2 * market + 0.4 * peer + sin(seq_len(n) / 7) / 1000
  first <- g5_gen54_one_step_residuals(asset, market, peer, estimation_window = 126L)
  changed <- asset
  changed[200:220] <- changed[200:220] + 1
  second <- g5_gen54_one_step_residuals(changed, market, peer, estimation_window = 126L)
  testthat::expect_equal(first[127:199], second[127:199])
  testthat::expect_true(all(is.na(first[1:126])))
})

testthat::test_that("signed efficiency distinguishes persistent and choppy paths", {
  persistent <- g5_gen54_signed_efficiency(rep(0.01, 25), 20L)
  choppy <- g5_gen54_signed_efficiency(rep(c(0.01, -0.01), 13)[1:25], 20L)
  testthat::expect_equal(persistent[[25]], 1)
  testthat::expect_lt(abs(choppy[[25]]), 0.1)
})

testthat::test_that("X1b redundancy gate is frozen at 0.70", {
  dates <- as.Date("2020-01-01") + 0:9
  symbols <- paste0("S", 1:20)
  panel <- expand.grid(feature_date = dates, symbol = symbols, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  panel$cross_section_eligible <- TRUE
  base <- rep(seq(0, 1, length.out = 20), 10)
  panel$group_relative_20_rank <- base
  panel$residual_momentum_60_rank <- base
  panel$residual_reversal_5_rank <- rep(rev(seq(0, 1, length.out = 20)), 10)
  panel$signed_efficiency_20_rank <- rep(c(seq(0, 1, length.out = 10), seq(0, 1, length.out = 10)), 10)
  panel$intraday_minus_overnight_20_rank <- rep(seq(0, 1, length.out = 20)[c(1:10, 20:11)], 10)
  audit <- g5_gen54_x1b_redundancy_audit(panel)
  testthat::expect_identical(audit$summary$redundancy_cap, rep(0.70, 4L))
  testthat::expect_identical(audit$summary$redundancy_status[audit$summary$feature_name == "residual_momentum_60"], "STOP_REDUNDANT")
})

testthat::test_that("C0 thresholds are estimated from TRAIN only", {
  dates <- as.Date("2018-01-01") + 0:1095
  context <- data.frame(feature_date = dates, label_end_date = dates + 5L, equal_weight_universe_forward_return_h5 = 0.01, stringsAsFactors = FALSE)
  for (feature in g5_gen54_c0_feature_names()) context[[feature]] <- seq_along(dates)
  fold <- data.frame(fold_no = 1L, fold_id = "2020Q1", window_id = "2020Y", train_start_date = as.Date("2018-01-01"), train_end_date = as.Date("2019-12-31"), oos_start_date = as.Date("2020-01-01"), oos_end_date = as.Date("2020-03-31"))
  first <- g5_gen54_c0_fold_audit(context, fold)
  context[context$feature_date >= fold$oos_start_date, g5_gen54_c0_feature_names()] <- 1e9
  second <- g5_gen54_c0_fold_audit(context, fold)
  testthat::expect_equal(first$train_threshold, second$train_threshold)
})
