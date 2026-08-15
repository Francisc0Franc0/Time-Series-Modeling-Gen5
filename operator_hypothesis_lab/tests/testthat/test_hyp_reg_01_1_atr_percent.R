source(testthat::test_path("..", "..", "R", "hyp_reg_01_1_atr_percent.R"))

hreg_fixture <- function(n = 620L, symbol = "AAA") {
  close <- 100 + seq_len(n) * 0.05 + sin(seq_len(n) / 15)
  data.frame(
    symbol = symbol,
    session_date = as.Date("2015-01-02") + seq_len(n) - 1L,
    open = close - 0.1,
    high = close + 1,
    low = close - 1,
    close = close,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("true range and Wilder ATR use only current and prior bars", {
  close <- rep(100, 20)
  tr <- hreg_true_range(rep(101, 20), rep(99, 20), close)
  atr <- hreg_wilder_atr(tr, 14L)
  testthat::expect_true(is.na(tr[[1L]]))
  testthat::expect_equal(tr[-1L], rep(2, 19))
  testthat::expect_equal(atr[[15L]], 2)
  testthat::expect_equal(atr[[20L]], 2)
})

testthat::test_that("rolling percentile excludes the current observation", {
  score <- hreg_rolling_percentile(1:6, 3L)
  testthat::expect_true(all(is.na(score[1:3])))
  testthat::expect_equal(score[4:6], rep(1, 3))
  tied <- hreg_rolling_percentile(c(1, 1, 1, 1), 3L)
  testthat::expect_equal(tied[[4L]], 0.5)
})

testthat::test_that("hysteresis suppresses boundary chatter and permits shock jumps", {
  score <- c(.20, .35, .41, .65, .71, .65, .59, .20, .75)
  state <- hreg_hysteretic_state(score)
  testthat::expect_equal(state, c("LOW", "LOW", "MEDIUM", "MEDIUM", "HIGH", "HIGH", "MEDIUM", "LOW", "HIGH"))
})

testthat::test_that("forward target begins after the state date", {
  x <- 1:8
  testthat::expect_equal(hreg_forward_mean(x, 1L)[1:4], 2:5)
  testthat::expect_equal(hreg_forward_mean(x, 3L)[[1L]], mean(2:4))
  testthat::expect_true(all(is.na(tail(hreg_forward_mean(x, 3L), 3))))
})

testthat::test_that("non-overlapping sampling advances by the target horizon", {
  eligible <- c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE)
  testthat::expect_equal(which(hreg_nonoverlap_flag(eligible, 3L)), c(2L, 5L, 8L))
  testthat::expect_equal(which(hreg_nonoverlap_flag(eligible, 1L)), 2:8)
})

testthat::test_that("asset ledger seals confirmation and creates directionless targets", {
  contract <- hreg_contract()
  bars <- hreg_fixture(620L)
  ledger <- hreg_build_asset_ledger(bars, contract)
  testthat::expect_equal(nrow(ledger), nrow(bars))
  testthat::expect_true(any(is.finite(ledger$atr_percentile)))
  testthat::expect_true(any(is.finite(ledger$future_mean_ntr_h20)))
  testthat::expect_true(all(stats::na.omit(unique(ledger$regime_state)) %in% c("LOW", "MEDIUM", "HIGH")))
  testthat::expect_false(any(c("pnl", "strategy_return", "sharpe", "drawdown") %in% names(ledger)))
})

testthat::test_that("engine has explicit dates and no implicit current session", {
  contract <- hreg_contract()
  testthat::expect_equal(contract$analysis_end, as.Date("2023-12-29"))
  testthat::expect_equal(contract$confirmation_start, as.Date("2024-01-02"))
  code <- paste(readLines(testthat::test_path("..", "..", "R", "hyp_reg_01_1_atr_percent.R")), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
