repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_02_2_sma200_entry_sma50_exit.R"))

hyp_mom022_business_dates <- function() {
  dates <- seq(as.Date("2019-01-02"), as.Date("2023-12-29"), by = "day")
  dates[as.POSIXlt(dates)$wday %in% 1:5]
}

hyp_mom022_bars <- function(close, symbol = "TEST") {
  dates <- hyp_mom022_business_dates()
  stopifnot(length(close) == length(dates))
  data.frame(
    symbol = symbol, session_date = dates, open = close,
    high = close * 1.002, low = close * 0.998, close = close,
    volume = 1e6 + seq_along(dates), stringsAsFactors = FALSE
  )
}

hyp_mom022_lockout_fixture <- function(symbol = "LOCKOUT") {
  dates <- hyp_mom022_business_dates()
  close <- rep(100, length(dates))
  discovery <- which(dates >= as.Date("2021-01-04"))
  close[discovery[[1L]] - 1L] <- 99
  close[discovery[[1L]]] <- 105
  close[discovery[2:81]] <- 130
  close[discovery[[82L]]] <- 120
  close[discovery[83:length(discovery)]] <- 140
  hyp_mom022_bars(close, symbol)
}

hyp_mom022_skipped_fixture <- function(symbol = "SKIPPED") {
  dates <- hyp_mom022_business_dates()
  close <- rep(100, length(dates))
  discovery <- which(dates >= as.Date("2021-01-04"))
  close[(discovery[[1L]] - 61L):(discovery[[1L]] - 2L)] <- 130
  close[discovery[[1L]] - 1L] <- 105
  close[discovery[[1L]]] <- 115
  close[discovery[2:length(discovery)]] <- 140
  hyp_mom022_bars(close, symbol)
}

testthat::test_that("contract freezes asymmetric entry, exit, and re-entry mechanics", {
  contract <- hyp_mom022_contract()
  testthat::expect_equal(contract$entry_sma_sessions, 200L)
  testthat::expect_equal(contract$exit_sma_sessions, 50L)
  testthat::expect_identical(contract$entry_confirmation, "SIGNAL_CLOSE_ABOVE_SMA50")
  testthat::expect_identical(contract$reentry_rule, "NEW_QUALIFIED_SMA200_CROSS_REQUIRED")
  contract$exit_sma_sessions <- 60L
  testthat::expect_error(hyp_mom022_validate_contract(contract), "contract changed")
})

testthat::test_that("qualified SMA200 cross enters next open and SMA50 failure exits next open", {
  bars <- hyp_mom022_lockout_fixture()
  state <- hyp_mom022_state(bars)
  replay <- hyp_mom022_replay(bars, 5)
  testthat::expect_equal(nrow(replay$trades), 1L)
  trade <- replay$trades[1L, ]
  entry_i <- match(trade$entry_date, state$session_date)
  exit_i <- match(trade$exit_date, state$session_date)
  testthat::expect_true(state$cross_above_sma200[[entry_i - 1L]])
  testthat::expect_true(state$above_sma50[[entry_i - 1L]])
  testthat::expect_false(state$above_sma50[[exit_i - 1L]])
  testthat::expect_identical(trade$entry_reason, "QUALIFIED_CROSS_ABOVE_SMA200")
  testthat::expect_identical(trade$exit_reason, "BELOW_SMA50")
})

testthat::test_that("SMA50 recovery does not re-enter without a new SMA200 cross", {
  replay <- hyp_mom022_replay(hyp_mom022_lockout_fixture(), 5)
  exit_date <- replay$trades$exit_date[[1L]]
  after_exit <- replay$path$session_date >= exit_date
  testthat::expect_true(any(replay$path$strict_reentry_lockout[after_exit]))
  testthat::expect_false(any(replay$path$in_position_after_open[after_exit]))
  testthat::expect_equal(nrow(replay$trades), 1L)
})

testthat::test_that("SMA200 cross below SMA50 is recorded and skipped", {
  replay <- hyp_mom022_replay(hyp_mom022_skipped_fixture(), 5)
  testthat::expect_equal(nrow(replay$trades), 0L)
  testthat::expect_true(any(replay$path$skipped_entry_from_prior_close))
  testthat::expect_true(any(replay$path$signal_type == "SKIPPED_CROSS_ABOVE_SMA200_BELOW_SMA50"))
  testthat::expect_false(any(replay$path$in_position_after_open))
})

testthat::test_that("analysis preserves zero participation and deterministic controls", {
  zero <- hyp_mom022_analyze_asset(hyp_mom022_skipped_fixture())
  testthat::expect_equal(zero$summary$trade_count, 0L)
  testthat::expect_equal(zero$summary$primary_return, 0)
  testthat::expect_equal(zero$summary$maximum_drawdown, 0)
  testthat::expect_true(is.na(zero$summary$observed_random_percentile))

  bars <- hyp_mom022_lockout_fixture()
  replay <- hyp_mom022_replay(bars, 5)
  state <- head(replay$path$asymmetric_long_state, -1L)
  a <- hyp_mom022_random_controls(bars, state, 5, seed_offset = 7L)
  b <- hyp_mom022_random_controls(bars, state, 5, seed_offset = 7L)
  testthat::expect_equal(a, b)
  testthat::expect_length(a, hyp_mom022_contract()$random_simulations)
})

testthat::test_that("costs, compounding, and discovery boundary remain causal", {
  bars <- hyp_mom022_lockout_fixture()
  primary <- hyp_mom022_replay(bars, 5)
  stress <- hyp_mom022_replay(bars, 10)
  testthat::expect_lt(tail(stress$path$strategy_wealth_open, 1L), tail(primary$path$strategy_wealth_open, 1L))
  testthat::expect_true(all(primary$trades$net_trade_return < primary$trades$gross_trade_return))
  testthat::expect_identical(primary$path$signal_type[[1L]], "PRE_WINDOW_STATE_IGNORED")
  testthat::expect_false(primary$path$in_position_after_open[[1L]])
  bars <- rbind(bars, transform(tail(bars, 1L), session_date = as.Date("2024-01-02")))
  testthat::expect_error(hyp_mom022_replay(bars, 5), "Confirmation observations")
})
