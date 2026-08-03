source(testthat::test_path(
  "..", "..", "R", "hyp_mom_01_1_two_green_gap_ups.R"
))
source(testthat::test_path(
  "..", "..", "R", "hyp_mom_01_1_diagnostic_atlas.R"
))

hyp_mom011_da_fixture <- function(symbol = "TEST") {
  n <- 500L
  dates <- as.Date("2020-01-01") + 0:(n - 1L)
  close <- 100 * exp(cumsum(rep(0.0005, n)))
  open <- c(close[[1L]], head(close, -1L) * 0.999)
  high <- pmax(open, close) * 1.002
  low <- pmin(open, close) * 0.998
  signal_index <- 400L
  open[[signal_index - 1L]] <- close[[signal_index - 2L]] * 1.01
  close[[signal_index - 1L]] <- open[[signal_index - 1L]] * 1.015
  open[[signal_index]] <- close[[signal_index - 1L]] * 1.008
  close[[signal_index]] <- open[[signal_index]] * 1.012
  for (i in (signal_index + 1L):n) {
    open[[i]] <- close[[i - 1L]] * 0.999
    close[[i]] <- open[[i]] * 1.001
  }
  high <- pmax(open, close) * 1.002
  low <- pmin(open, close) * 0.998
  data.frame(
    symbol = symbol,
    session_date = dates,
    open = open,
    high = high,
    low = low,
    close = close,
    volume = 1000000 + seq_len(n),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("diagnostic atlas contract is immutable", {
  contract <- hyp_mom011_da_contract()
  testthat::expect_equal(contract$slow_anchor_sessions, 200L)
  contract$slow_anchor_sessions <- 100L
  testthat::expect_error(
    hyp_mom011_da_validate_contract(contract),
    "contract changed"
  )
})

testthat::test_that("features are scaled only with information available before each candle", {
  bars <- hyp_mom011_da_fixture()
  spy <- hyp_mom011_da_fixture("SPY")
  context <- hyp_mom011_da_spy_context(spy)
  features <- hyp_mom011_da_asset_features(bars, context)
  testthat::expect_equal(nrow(features), 1L)
  s <- features$signal_index[[1L]]
  log_returns <- c(NA_real_, diff(log(bars$close)))
  expected_sigma1 <- stats::sd(log_returns[(s - 21L):(s - 2L)])
  expected_sigma2 <- stats::sd(log_returns[(s - 20L):(s - 1L)])
  testthat::expect_equal(features$lagged_sigma_first, expected_sigma1)
  testthat::expect_equal(features$lagged_sigma_second, expected_sigma2)
  testthat::expect_gt(features$gap_strength_z, 0)
  testthat::expect_gt(features$body_strength_z, 0)
  testthat::expect_equal(features$qualifying_streak, 2L)
  testthat::expect_true(features$entry_date > features$signal_date)
})

testthat::test_that("rank terciles preserve every observation", {
  groups <- hyp_mom011_da_rank_tercile(1:9)
  counts <- table(factor(groups, levels = c("LOW", "MID", "HIGH")))
  testthat::expect_equal(as.integer(counts), rep(3L, 3L))
  testthat::expect_equal(groups, rep(c("LOW", "MID", "HIGH"), each = 3L))
})

testthat::test_that("asset contrasts give each paired asset one difference", {
  data <- data.frame(
    symbol = c(rep("A", 12), rep("B", 4)),
    group = c(rep("HIGH", 10), rep("LOW", 2), rep(c("HIGH", "LOW"), each = 2)),
    primary_trade_return = c(rep(0.02, 10), rep(0.01, 2), rep(-0.01, 2), rep(0.01, 2)),
    stringsAsFactors = FALSE
  )
  result <- hyp_mom011_da_asset_contrast(
    data, "TEST", "group", "HIGH", "LOW", bootstrap_draws = 100L, seed = 1L
  )
  testthat::expect_equal(result$paired_asset_count, 2L)
  testthat::expect_equal(result$mean_asset_contrast, -0.005)
  testthat::expect_equal(result$fraction_asset_contrasts_positive, 0.5)
})

testthat::test_that("checkpoint rows measure return remaining after the checkpoint", {
  trades <- data.frame(
    trade_id = "T1",
    symbol = "TEST",
    sector = "Fixture",
    primary_trade_return = 0.05,
    path_return_1 = -0.02,
    path_return_2 = 0.01,
    path_return_3 = 0.03,
    path_return_4 = 0.04,
    path_return_5 = 0.051,
    remaining_return_1 = 0.07,
    remaining_return_2 = 0.04,
    remaining_return_3 = 0.02,
    remaining_return_4 = 0.01,
    stringsAsFactors = FALSE
  )
  rows <- hyp_mom011_da_checkpoint_rows(trades)
  testthat::expect_equal(nrow(rows), 4L)
  testthat::expect_equal(rows$checkpoint_state, c("NONPOSITIVE", rep("POSITIVE", 3L)))
  testthat::expect_equal(rows$remaining_return, c(0.07, 0.04, 0.02, 0.01))
})
