repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mr_01_1_qqq_intraday_shock_reversal.R"))

hmr011_fixture_bars <- function(end_date = as.Date("2020-12-31")) {
  dates <- seq.Date(as.Date("2016-01-04"), end_date, by = "day")
  i <- seq_along(dates)
  open <- 100 * exp(0.00025 * i + 0.008 * sin(i / 19))
  intraday <- 0.007 * sin(i / 11) + 0.003 * cos(i / 5)
  close <- open * exp(intraday)
  data.frame(
    symbol = "QQQ", session_date = dates, open = open,
    high = pmax(open, close) * 1.004, low = pmin(open, close) * 0.996,
    close = close, volume = 4e7 * exp(0.1 * sin(i / 23)),
    adjusted = TRUE, timeframe = "1D", stringsAsFactors = FALSE
  )
}

hmr011_signal_panel <- function(beta = -0.8, seed = 1101L) {
  set.seed(seed)
  dates <- seq.Date(as.Date("2017-01-03"), as.Date("2020-12-31"), by = "day")
  x <- stats::rnorm(length(dates))
  data.frame(
    anchor_date = dates - 1L,
    target_date = dates,
    x = x,
    y = beta * x + stats::rnorm(length(x), sd = 0.25),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("HYP-MR-01.1 freezes one regressor, one target, and sealed evidence", {
  contract <- g5_hmr011_contract()
  testthat::expect_identical(contract$hypothesis_id, "HYP-MR-01.1")
  testthat::expect_identical(contract$symbol, "QQQ")
  testthat::expect_identical(contract$atr_sessions, 20L)
  testthat::expect_identical(contract$fold_years, 2018:2020)
  testthat::expect_true(contract$development_end < contract$confirmation_start)
  changed <- contract
  changed$atr_sessions <- 10L
  testthat::expect_error(g5_hmr011_validate_contract(changed), "Frozen HYP-MR-01.1 contract changed")
})

testthat::test_that("prior ATR excludes the current session", {
  high <- c(rep(11, 22), 50)
  low <- c(rep(9, 22), 1)
  close <- rep(10, 23)
  atr <- g5_hmr011_prior_atr(high, low, close, 20L)
  testthat::expect_equal(atr$prior_atr[[22L]], 2)
  testthat::expect_equal(atr$prior_atr[[23L]], 2)
})

testthat::test_that("zone construction uses the completed session and exact next session", {
  contract <- g5_hmr011_contract()
  bundle <- g5_hmr011_zone_panel(
    hmr011_fixture_bars(), contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  i <- bundle$anchor_index[[1L]]
  expected_atr <- mean(bundle$bars$true_range[(i - 20L):(i - 1L)]) / bundle$bars$close[[i - 1L]]
  testthat::expect_equal(bundle$panel$x[[1L]], log(bundle$bars$close[[i]] / bundle$bars$open[[i]]) / expected_atr)
  testthat::expect_equal(bundle$panel$y[[1L]], log(bundle$bars$close[[i + 1L]] / bundle$bars$open[[i + 1L]]))
  testthat::expect_identical(bundle$panel$target_date[[1L]], bundle$bars$session_date[[i + 1L]])
  testthat::expect_true(all(bundle$construction_checks$passed))
})

testthat::test_that("bar validation rejects invalid OHLC and sealed dates", {
  contract <- g5_hmr011_contract()
  bars <- hmr011_fixture_bars()
  invalid <- bars
  invalid$open[[100L]] <- 0
  testthat::expect_error(g5_hmr011_validate_bars(invalid, contract$train_end), "positive_finite_ohlcv")
  extra <- bars[nrow(bars), ]
  extra$session_date <- as.Date("2026-01-02")
  testthat::expect_error(g5_hmr011_validate_bars(rbind(bars, extra), contract$confirmation_end), "maximum_date_seal")
})

testthat::test_that("strong synthetic reversal passes expanding and timing gates", {
  contract <- g5_hmr011_contract()
  result <- g5_hmr011_run_train_panel(hmr011_signal_panel(-0.8), contract)
  testthat::expect_true(result$statistics$beta[[1L]] < 0)
  testthat::expect_true(all(result$folds$mse_improvement > 0))
  testthat::expect_true(result$decision$timing_specificity_passed[[1L]])
  testthat::expect_true(result$decision$passed[[1L]])
  testthat::expect_identical(result$overall_status, "TRAIN_PASS_HYP_MR_01_1_DEVELOPMENT_AUTHORIZED")
})

testthat::test_that("continuation-shaped evidence cannot pass reversal gates", {
  result <- g5_hmr011_run_train_panel(hmr011_signal_panel(0.8, 2202L), g5_hmr011_contract())
  testthat::expect_true(result$statistics$beta[[1L]] > 0)
  testthat::expect_false(result$gates$passed[result$gates$gate_id == "negative_full_train_beta"])
  testthat::expect_false(result$decision$passed[[1L]])
})

testthat::test_that("influence audit and development bootstrap are deterministic", {
  panel <- hmr011_signal_panel(-0.5, 3303L)
  first <- g5_hmr011_influence_audit(panel, g5_hmr011_contract())
  second <- g5_hmr011_influence_audit(panel, g5_hmr011_contract())
  testthat::expect_identical(first, second)
  testthat::expect_true(first$excluded_rows > 0)
  improvement <- 0.02 + 0.01 * sin(seq_len(500L) / 13)
  b1 <- g5_hmr011_development_bootstrap(improvement, g5_hmr011_contract(), 200L)
  b2 <- g5_hmr011_development_bootstrap(improvement, g5_hmr011_contract(), 200L)
  testthat::expect_identical(b1, b2)
  testthat::expect_equal(b1$probability_positive, 1)
})

testthat::test_that("strategy and performance surfaces remain absent", {
  function_text <- paste(deparse(body(g5_hmr011_run_development)), collapse = " ")
  testthat::expect_false(grepl("sharpe|drawdown|pnl|wealth|position|turnover", function_text, ignore.case = TRUE))
})
