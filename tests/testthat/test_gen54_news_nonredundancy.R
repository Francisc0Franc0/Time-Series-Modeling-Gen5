source(testthat::test_path("..", "..", "R", "data_contract.R"))
source(testthat::test_path("..", "..", "R", "alpaca_provider.R"))
source(testthat::test_path("..", "..", "R", "alpaca_context_provider.R"))
source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_poc.R"))
source(testthat::test_path("..", "..", "R", "gen54_news_admissibility.R"))
source(testthat::test_path("..", "..", "R", "gen54_news_risk_measurement.R"))
source(testthat::test_path("..", "..", "R", "gen54_news_nonredundancy.R"))

testthat::test_that("N1C controls use backward h5 path and exclude current dollar volume from baseline", {
  sessions <- as.Date("2024-01-01") + 0:64
  bars <- data.frame(
    issuer_id = "AAPL",
    session_date = sessions,
    open = rep(100, length(sessions)),
    close = 100 + seq_along(sessions),
    volume = 1000 + 10 * seq_along(sessions),
    stringsAsFactors = FALSE
  )
  controls <- g5_gen54_n1c_control_series(bars, sessions)
  row <- controls[controls$decision_session == sessions[[61L]], ]
  expected_returns <- c(
    log(bars$close[[57L]] / bars$open[[57L]]),
    diff(log(bars$close[57:61]))
  )
  expected_dollar_volume <- bars$close * bars$volume
  testthat::expect_equal(
    row$prior_path_volatility_h5,
    sqrt(sum(expected_returns^2))
  )
  testthat::expect_equal(
    row$dollar_volume_surprise_1_60,
    log(expected_dollar_volume[[61L]] / stats::median(expected_dollar_volume[1:60]))
  )
  testthat::expect_identical(row$prior_path_end_session, sessions[[61L]])
  testthat::expect_identical(row$dollar_volume_baseline_end_session, sessions[[60L]])
})

testthat::test_that("two-control partial Spearman removes explained rank association", {
  set.seed(5401)
  z1 <- seq_len(400)
  z2 <- rep(seq_len(20), 20)
  x <- z1 + 2 * z2 + stats::rnorm(400, 0, 8)
  y <- z1 + 2 * z2 + stats::rnorm(400, 0, 8)
  direct <- stats::cor(x, y, method = "spearman")
  partial <- g5_gen54_n1c_partial_spearman(x, y, cbind(z1, z2))
  testthat::expect_gt(direct, 0.95)
  testthat::expect_lt(abs(partial), 0.2)
})

testthat::test_that("N1C verdict requires mean, fold stability, and integrity", {
  folds <- data.frame(
    partial_spearman_correlation = c(rep(0.1, 8), rep(-0.05, 4))
  )
  passed <- g5_gen54_n1c_verdict(folds, integrity_passed = TRUE)
  testthat::expect_true(passed$passed)
  testthat::expect_false(g5_gen54_n1c_verdict(folds, integrity_passed = FALSE)$passed)
  folds$partial_spearman_correlation[[1L]] <- -1
  testthat::expect_false(g5_gen54_n1c_verdict(folds, integrity_passed = TRUE)$passed)
})

testthat::test_that("N1C issuer bars preserve volume and point-in-time META identity", {
  bars <- data.frame(
    symbol = c("FB", "FB", "META", "META"),
    session_date = as.Date(c("2022-06-08", "2022-06-09", "2022-06-08", "2022-06-09")),
    open = c(1, 2, 3, 4),
    close = c(1.1, 2.1, 3.1, 4.1),
    volume = c(10, 20, 30, 40),
    stringsAsFactors = FALSE
  )
  unified <- g5_gen54_n1c_unify_bars(bars)
  meta <- unified[unified$issuer_id == "META_PLATFORMS", ]
  testthat::expect_identical(meta$provider_symbol, c("FB", "META"))
  testthat::expect_identical(meta$volume, c(10, 40))
})
