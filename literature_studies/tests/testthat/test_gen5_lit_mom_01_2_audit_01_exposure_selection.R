source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_1_interday_momentum_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_2_single_position_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_2_audit_01_exposure_selection.R"
))

mom012a_fixture <- function(symbol = "AAA", n = 900L, phase = 0) {
  dates <- seq.Date(as.Date("2015-01-02"), by = "day", length.out = n * 2L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  index <- seq_len(n)
  close <- 80 * exp(0.0003 * index + 0.03 * sin(index / 18 + phase))
  open <- close * (1 + 0.001 * cos(index / 9 + phase))
  data.frame(
    symbol = symbol,
    session_date = dates,
    open = open,
    high = pmax(open, close) * 1.001,
    low = pmin(open, close) * 0.999,
    close = close,
    volume = 1e6,
    adjusted = TRUE,
    timeframe = "1D",
    stringsAsFactors = FALSE
  )
}

testthat::test_that("AUDIT_01 contract and sector references are frozen", {
  contract <- g5_mom012a_contract()
  testthat::expect_identical(
    contract$evidence_label,
    "RETROSPECTIVE_ATTRIBUTION_AUDIT"
  )
  testthat::expect_equal(contract$random_schedule_count, 1000L)
  testthat::expect_equal(length(g5_mom012a_sector_etfs()), 11L)
  changed <- contract
  changed$primary_cost_bps <- 0
  testthat::expect_error(
    g5_mom012a_validate_contract(changed),
    "contract changed"
  )
})

testthat::test_that("buy-hold and always-long schedules are causal and nonoverlapping", {
  bars <- mom012a_fixture()
  start <- bars$session_date[[300L]]
  end <- bars$session_date[[800L]]
  buy_hold <- g5_mom012a_buy_hold_schedule(bars, start, end)
  blocks <- g5_mom012a_always_long_schedule(bars, start, end, 25L)
  testthat::expect_equal(nrow(buy_hold), 1L)
  testthat::expect_true(all(blocks$direction == 1L))
  testthat::expect_true(all(blocks$entry_index[-1L] >= head(blocks$exit_index, -1L)))
  testthat::expect_true(all(blocks$signal_date < blocks$entry_date))
})

testthat::test_that("complete daily paths retain cash intervals", {
  bars <- mom012a_fixture()
  start <- bars$session_date[[300L]]
  end <- bars$session_date[[800L]]
  schedule <- g5_mom012a_schedule_from_entries(bars, c(320L, 400L), 25L)
  replayed <- g5_mom012a_replay_schedule(bars, schedule, 5)
  daily <- g5_mom012a_complete_daily_path(
    bars, replayed$replay, start, end
  )
  testthat::expect_gt(sum(daily$strategy_return == 0), 300L)
  testthat::expect_equal(sum(daily$strategy_return != 0), 50L)
  constant <- g5_mom012a_constant_exposure(daily, 0.25, 5)
  testthat::expect_true(all(is.finite(constant)))
})

testthat::test_that("matched timing draws are deterministic and nontrivial", {
  bars <- mom012a_fixture()
  start <- bars$session_date[[300L]]
  end <- bars$session_date[[800L]]
  observed <- 0.10
  a <- g5_mom012a_random_timing(
    bars, start, end, 25L, 8L, observed,
    simulations = 50L, seed = 123L
  )
  b <- g5_mom012a_random_timing(
    bars, start, end, 25L, 8L, observed,
    simulations = 50L, seed = 123L
  )
  testthat::expect_equal(a, b)
  testthat::expect_gte(a$observed_random_percentile, 0)
  testthat::expect_lte(a$observed_random_percentile, 1)
  testthat::expect_gt(a$random_q90_return, a$random_q10_return)
})

testthat::test_that("regression and environment features use causal histories", {
  asset <- mom012a_fixture("AAA")
  spy <- mom012a_fixture("SPY", phase = 0.4)
  start <- asset$session_date[[300L]]
  end <- asset$session_date[[800L]]
  schedule <- g5_mom012a_schedule_from_entries(asset, c(320L, 400L), 25L)
  replayed <- g5_mom012a_replay_schedule(asset, schedule, 5)
  daily <- g5_mom012a_complete_daily_path(asset, replayed$replay, start, end)
  spy_return <- data.frame(
    outcome_date = spy$session_date[-1L],
    spy_return = spy$open[-1L] / head(spy$open, -1L) - 1
  )
  regression <- g5_mom012a_regression(daily, spy_return)
  features <- g5_mom012a_feature_panel(spy)
  testthat::expect_true(all(is.finite(unlist(regression))))
  testthat::expect_true(all(is.na(features$trailing_return[1:60])))
  testthat::expect_true(is.finite(features$realized_volatility[[100L]]))
})

testthat::test_that("environment summary and sector bootstrap preserve support", {
  trades <- data.frame(
    symbol = rep(c("A", "B", "C", "D"), each = 30),
    trade_return = rep(c(0.01, -0.005), 60),
    market_trend = rep(c("POSITIVE", "NON_POSITIVE"), 60),
    market_volatility = rep(c("LOW", "HIGH"), each = 60),
    sector_trend = rep(c("POSITIVE", "NON_POSITIVE"), each = 30, times = 2),
    relative_strength = rep(c("POSITIVE", "NON_POSITIVE"), 60),
    stringsAsFactors = FALSE
  )
  summary <- g5_mom012a_environment_summary(trades)
  testthat::expect_true(all(summary$trade_count > 0))
  testthat::expect_true("MARKET_TREND_X_VOLATILITY" %in% summary$descriptor)

  assets <- data.frame(
    sector = rep(c("S1", "S2", "S3"), each = 4),
    excess = seq(-0.05, 0.06, length.out = 12)
  )
  boot <- g5_mom012a_cluster_bootstrap(
    assets, "excess", simulations = 100L, seed = 12L
  )
  testthat::expect_equal(boot$cluster_count, 3L)
  testthat::expect_lte(boot$lower_90, boot$upper_90)
})

testthat::test_that("audit scorecard reports all eleven diagnostics", {
  assets <- data.frame(
    selected_return = rep(0.20, 10),
    excess_vs_buy_hold = rep(0.05, 10),
    excess_vs_constant_exposure = rep(0.04, 10),
    excess_vs_always_long_block = rep(0.03, 10),
    random_median_return = rep(0.10, 10),
    observed_random_percentile = rep(0.70, 10),
    selected_minus_fixed_250_25 = rep(0.02, 10),
    selected_minus_fixed_60_5 = rep(0.01, 10),
    annualized_alpha = rep(0.03, 10)
  )
  score <- g5_mom012a_scorecard(assets, 0.01, TRUE)
  testthat::expect_equal(nrow(score), 11L)
  testthat::expect_true(all(score$passed))
})
