source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_1_interday_momentum_poc.R"
))

mom01_fixture <- function(n = 700L) {
  dates <- seq.Date(as.Date("2015-01-02"), by = "day", length.out = n * 2L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- 80 * exp(seq(0, 0.20, length.out = n))
  data.frame(
    symbol = "SHY",
    session_date = dates,
    open = close * 0.999,
    high = close * 1.001,
    low = close * 0.998,
    close = close,
    volume = 1e6,
    adjusted = TRUE,
    timeframe = "1D",
    stringsAsFactors = FALSE
  )
}

testthat::test_that("frozen contract rejects mechanical changes", {
  changed <- g5_mom01_contract()
  changed$holding_sessions <- 20L
  testthat::expect_error(
    g5_mom01_validate_contract(changed),
    "Frozen LIT-MOM-01.1 contract changed"
  )
})

testthat::test_that("correlation views preserve source and strict spacing", {
  contract <- g5_mom01_contract()
  bars <- mom01_fixture()
  panel <- g5_mom01_signal_panel(bars, contract)
  views <- g5_mom01_correlation_views(
    panel,
    as.Date("2016-01-04"),
    max(bars$session_date),
    contract
  )
  testthat::expect_equal(
    views$summary$step_sessions[
      views$summary$sampling_id == "CHAN_MIN_STEP"
    ],
    25L
  )
  testthat::expect_equal(
    views$summary$step_sessions[
      views$summary$sampling_id == "STRICT_FULL_PAIR_STEP"
    ],
    275L
  )
  chan <- views$pairs$CHAN_MIN_STEP
  testthat::expect_true(all(diff(chan$signal_index) == 25L))
})

testthat::test_that("horizon selection is TRAIN-only, supported, and deterministic", {
  contract <- g5_mom01_contract()
  screen <- data.frame(
    lookback_sessions = c(60L, 250L, 25L),
    holding_sessions = c(10L, 25L, 1L),
    pair_count = c(30L, 30L, 200L),
    return_correlation = c(0.20, 0.25, 0.40),
    naive_pearson_p_value = c(0.04, 0.02, 0.001),
    correlation_t_statistic = c(2.0, 2.5, 6.0),
    direction_accuracy = c(0.55, 0.58, 0.60),
    support_eligible = c(TRUE, TRUE, FALSE),
    source_style_admissible = c(TRUE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  selected <- g5_mom01_select_horizon(screen, contract)
  testthat::expect_equal(selected$lookback_sessions, 250L)
  testthat::expect_equal(selected$holding_sessions, 25L)
  testthat::expect_true(selected$selected_before_oos)
})

testthat::test_that("causal exposure ramps by one twenty-fifth after the close", {
  contract <- g5_mom01_contract()
  bars <- mom01_fixture()
  replay <- g5_mom01_replay_period(
    bars,
    as.Date("2017-01-03"),
    as.Date("2017-03-31"),
    0,
    0,
    contract
  )
  testthat::expect_equal(replay$position[[1L]], 0)
  nonzero <- which(replay$position != 0)
  testthat::expect_true(length(nonzero) > 0)
  testthat::expect_equal(abs(replay$position[[nonzero[[1L]]]]), 1 / 25)
  testthat::expect_true(all(abs(replay$position) <= 1))
})

testthat::test_that("turnover costs reduce returns and final exposure is liquidated", {
  contract <- g5_mom01_contract()
  bars <- mom01_fixture()
  gross <- g5_mom01_replay_period(
    bars,
    as.Date("2017-01-03"),
    as.Date("2017-06-30"),
    0,
    0,
    contract
  )
  net <- g5_mom01_replay_period(
    bars,
    as.Date("2017-01-03"),
    as.Date("2017-06-30"),
    5,
    0,
    contract
  )
  testthat::expect_true(sum(net$net_return) < sum(gross$net_return))
  testthat::expect_true(net$turnover[[nrow(net)]] >= abs(net$position[[nrow(net)]]))
})

testthat::test_that("development remains sealed after a failed TRAIN result", {
  failed <- list(development_authorized = FALSE)
  testthat::expect_error(
    g5_mom01_run_development(mom01_fixture(), failed),
    "DEVELOPMENT is sealed"
  )
})
