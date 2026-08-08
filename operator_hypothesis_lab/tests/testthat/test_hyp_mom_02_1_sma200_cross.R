source(testthat::test_path("..", "..", "R", "hyp_mom_02_1_sma200_cross.R"))

hyp_mom021_fixture <- function(symbol = "TEST") {
  dates <- seq(as.Date("2019-01-02"), as.Date("2023-12-29"), by = "day")
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5]
  k <- seq_along(dates)
  close <- 100 + 0.015 * k + 12 * sin(k / 34)
  open <- c(close[[1L]], head(close, -1L) * (1 + 0.001 * sin(k[-1L] / 7)))
  data.frame(
    symbol = symbol, session_date = dates, open = open,
    high = pmax(open, close) * 1.005, low = pmin(open, close) * 0.995,
    close = close, volume = 1e6 + k, stringsAsFactors = FALSE
  )
}

testthat::test_that("contract fixes the 200-session causal rule", {
  contract <- hyp_mom021_contract()
  testthat::expect_equal(contract$sma_sessions, 200L)
  testthat::expect_equal(contract$discovery_end, as.Date("2023-12-29"))
  contract$sma_sessions <- 150L
  testthat::expect_error(hyp_mom021_validate_contract(contract), "contract changed")
})

testthat::test_that("SMA state and crosses use completed closes", {
  state <- hyp_mom021_state(hyp_mom021_fixture())
  testthat::expect_true(all(is.na(state$sma200[1:199])))
  testthat::expect_true(is.finite(state$sma200[[200L]]))
  testthat::expect_true(any(state$cross_above))
  testthat::expect_true(any(state$cross_below))
  testthat::expect_true(all(state$close[state$cross_above] > state$sma200[state$cross_above]))
})

testthat::test_that("cross signals execute at the following open", {
  bars <- hyp_mom021_fixture()
  state <- hyp_mom021_state(bars)
  replay <- hyp_mom021_replay(bars, 5)
  signal_dates <- state$session_date[state$cross_above & state$session_date >= as.Date("2021-01-01")]
  signal_dates <- signal_dates[signal_dates < as.Date("2023-12-29")]
  entries <- replay$trades$entry_date[replay$trades$entry_reason == "CROSS_ABOVE"]
  testthat::expect_true(length(entries) > 0)
  for (entry in entries) {
    i <- match(as.Date(entry, origin = "1970-01-01"), state$session_date)
    testthat::expect_true(state$cross_above[[i - 1L]])
  }
})

testthat::test_that("finite-window replay charges costs and records boundaries", {
  replay <- hyp_mom021_replay(hyp_mom021_fixture(), 5)
  testthat::expect_true(all(is.finite(replay$path$strategy_wealth_open)))
  testthat::expect_true(all(replay$trades$net_trade_return < replay$trades$gross_trade_return))
  testthat::expect_true(all(replay$trades$holding_sessions > 0))
  testthat::expect_true(all(replay$trades$exit_reason %in% c("CROSS_BELOW", "BOUNDARY_EXIT")))
})

testthat::test_that("circular timing controls are deterministic and matched in count", {
  bars <- hyp_mom021_fixture()
  replay <- hyp_mom021_replay(bars, 5)
  a <- hyp_mom021_random_controls(bars, replay$path$target_from_prior_close, 5, seed_offset = 7L)
  b <- hyp_mom021_random_controls(bars, replay$path$target_from_prior_close, 5, seed_offset = 7L)
  testthat::expect_equal(a, b)
  testthat::expect_length(a, hyp_mom021_contract()$random_simulations)
  testthat::expect_true(all(is.finite(a)))
})

testthat::test_that("asset analysis reports return, risk, exposure, and controls", {
  result <- hyp_mom021_analyze_asset(hyp_mom021_fixture(), seed_offset = 3L)
  fields <- c("primary_return", "stress_return", "buy_hold_primary_return",
              "excess_vs_buy_hold", "maximum_drawdown", "drawdown_improvement",
              "exposure_fraction", "observed_random_percentile")
  testthat::expect_true(all(fields %in% names(result$summary)))
  testthat::expect_true(result$summary$exposure_fraction > 0)
  testthat::expect_true(result$summary$exposure_fraction < 1)
  testthat::expect_true(result$summary$observed_random_percentile >= 0)
  testthat::expect_true(result$summary$observed_random_percentile <= 1)
})

testthat::test_that("confirmation observations fail loudly", {
  bars <- hyp_mom021_fixture()
  bars <- rbind(bars, transform(tail(bars, 1L), session_date = as.Date("2024-01-02")))
  testthat::expect_error(hyp_mom021_validate_bars(bars), "Confirmation observations")
})
