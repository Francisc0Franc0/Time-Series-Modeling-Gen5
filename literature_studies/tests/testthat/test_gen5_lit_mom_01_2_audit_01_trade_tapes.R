source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_2_audit_01_trade_tapes.R"
))

mom012t_asset_fixture <- function() {
  symbols <- c("SHY", sprintf("S%02d", 1:40))
  n <- length(symbols)
  x <- data.frame(
    instance_id = symbols,
    symbol = symbols,
    cohort = c("SHY_TUTORIAL", rep(c("DIVERSIFIED_CORE", "RETAIL_ATTENTION_2020"), length.out = n - 1L)),
    sector = c("Treasury", rep(c("Industrials", "Energy", "Health Care"), length.out = n - 1L)),
    lookback_sessions = c(60L, rep(c(20L, 60L, 125L, 250L), length.out = n - 1L)),
    holding_sessions = c(5L, rep(c(5L, 10L, 25L), length.out = n - 1L)),
    selected_return = seq(-0.35, 0.65, length.out = n),
    selected_maximum_drawdown = seq(-0.75, -0.05, length.out = n),
    selected_trade_count = rep(24L, n),
    selected_long_call_accuracy = seq(0.4, 0.62, length.out = n),
    calendar_participation = seq(0.45, 0.9, length.out = n),
    buy_hold_return = seq(-0.15, 0.9, length.out = n),
    excess_vs_buy_hold = seq(-0.45, 0.30, length.out = n),
    excess_vs_constant_exposure = seq(-0.30, 0.25, length.out = n),
    observed_random_percentile = seq(0.02, 0.98, length.out = n),
    spy_beta = seq(0.15, 1.35, length.out = n),
    annualized_alpha = seq(-0.18, 0.22, length.out = n),
    stringsAsFactors = FALSE
  )
  x[x$symbol == "S05", c("selected_return", "excess_vs_buy_hold", "excess_vs_constant_exposure", "observed_random_percentile")] <- c(0.12, -0.15, -0.10, 0.12)
  x[x$symbol == "S35", c("selected_return", "excess_vs_buy_hold", "excess_vs_constant_exposure", "observed_random_percentile", "annualized_alpha")] <- c(0.35, 0.15, 0.12, 0.92, 0.08)
  x[x$symbol == "S06", c("selected_return", "observed_random_percentile")] <- c(0.10, 0.08)
  x[x$symbol == "S10", c("selected_return", "selected_maximum_drawdown")] <- c(0.18, -0.72)
  x
}

mom012t_environment_fixture <- function(symbols) {
  rows <- lapply(seq_along(symbols), function(i) {
    data.frame(
      symbol = symbols[[i]],
      market_trend = rep(c("POSITIVE", "NON_POSITIVE"), each = 12L),
      trade_return = c(rep(0.001, 12L), rep(0.001 + i / 10000, 12L)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

testthat::test_that("trade-tape contract is frozen", {
  contract <- g5_mom012t_contract()
  testthat::expect_equal(contract$archetype_count, 8L)
  testthat::expect_identical(
    contract$evidence_label,
    "RETROSPECTIVE_DESCRIPTIVE_TRADE_TAPE_REVIEW"
  )
  changed <- contract
  changed$deep_drawdown_quantile <- 0.20
  testthat::expect_error(
    g5_mom012t_validate_contract(changed),
    "contract changed"
  )
})

testthat::test_that("representative selection is deterministic and unique", {
  assets <- mom012t_asset_fixture()
  environment <- mom012t_environment_fixture(assets$symbol[assets$symbol != "SHY"])
  first <- g5_mom012t_select_representatives(assets, environment)
  second <- g5_mom012t_select_representatives(assets, environment)
  testthat::expect_equal(first, second)
  testthat::expect_equal(nrow(first), 8L)
  testthat::expect_equal(length(unique(first$symbol)), 8L)
  testthat::expect_identical(first$archetype_id[[1L]], "SHY_TUTORIAL")
  testthat::expect_setequal(
    first$archetype_id,
    c(
      "SHY_TUTORIAL", "CROSS_SECTIONAL_MEDOID",
      "POSITIVE_BUT_EXPOSURE_DOMINATED", "ATTRIBUTION_SURVIVOR",
      "RANDOM_TIMING_DISAPPOINTMENT", "DEEP_DRAWDOWN_POSITIVE_FINISH",
      "ATTENTION_COHORT_MEDOID", "COUNTERCYCLICAL_TRADE_MIX"
    )
  )
})

testthat::test_that("tape series preserves dates, wealth, drawdown, and trades", {
  dates <- seq.Date(as.Date("2021-01-04"), by = "day", length.out = 30L)
  daily <- data.frame(
    outcome_date = dates,
    asset_open_return = rep(0.001, length(dates)),
    strategy_return = c(rep(0, 5L), rep(0.002, 5L), rep(0, 20L)),
    symbol = "AAA",
    stringsAsFactors = FALSE
  )
  trades <- data.frame(
    symbol = "AAA",
    signal_date = dates[[5L]],
    entry_date = dates[[6L]],
    exit_date = dates[[11L]],
    trade_return = 0.01,
    stringsAsFactors = FALSE
  )
  tape <- g5_mom012t_tape_series(daily, trades, "AAA")
  testthat::expect_equal(nrow(tape$daily), 30L)
  testthat::expect_gt(tail(tape$daily$buy_hold_wealth, 1L), 1)
  testthat::expect_gt(tail(tape$daily$strategy_wealth, 1L), 1)
  testthat::expect_true(all(tape$daily$buy_hold_drawdown <= 0))
  testthat::expect_equal(nrow(tape$trades), 1L)
})
