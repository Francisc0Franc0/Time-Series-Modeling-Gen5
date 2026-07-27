source(testthat::test_path("..", "..", "R", "data_contract.R"))
source(testthat::test_path("..", "..", "R", "gen5_t1_multi_asset_trend_poc.R"))

g5_test_t1_contract <- function() {
  contract <- g5_t1_contract()
  contract$query_start <- as.Date("2019-01-01")
  contract$decision_start <- as.Date("2020-01-01")
  contract$development_end <- as.Date("2020-12-31")
  contract$confirmation_start <- as.Date("2021-01-01")
  contract$confirmation_end <- as.Date("2021-12-31")
  contract$shadow_start <- as.Date("2022-01-01")
  contract$decision_end <- as.Date("2022-06-30")
  contract$query_end <- as.Date("2022-07-01")
  contract$as_of_timestamp <- "2022-07-05 17:30:00"
  contract
}

g5_test_t1_bars <- function(contract = g5_test_t1_contract()) {
  dates <- seq(contract$query_start, contract$query_end, by = "day")
  weekday <- as.POSIXlt(dates)$wday
  dates <- dates[weekday %in% 1:5]
  symbols <- g5_t1_required_symbols(contract)
  frames <- lapply(seq_along(symbols), function(symbol_i) {
    symbol <- symbols[[symbol_i]]
    daily_rate <- if (symbol == contract$cash_proxy) {
      0.00005
    } else if (symbol == "IWM") {
      -0.00010
    } else {
      0.00020 + symbol_i * 0.000002
    }
    close <- 100 * exp(daily_rate * seq_along(dates))
    open <- close * (1 - 0.0001)
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
      provider = "alpaca",
      as_of_timestamp = contract$as_of_timestamp,
      latest_completed_session = contract$query_end,
      fetch_start_date = contract$query_start,
      fetch_end_date = contract$query_end,
      data_version_hash = paste0("test_", symbol),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, frames)
}

testthat::test_that("T1 freezes the approved universe and signal settings", {
  contract <- g5_t1_contract()
  testthat::expect_equal(length(contract$risk_assets), 14L)
  testthat::expect_equal(contract$cash_proxy, "BIL")
  testthat::expect_equal(contract$primary_lookback_months, 12L)
  testthat::expect_equal(contract$diagnostic_lookbacks, c(9L, 15L))
  testthat::expect_equal(contract$primary_cost_bps, 5)
  testthat::expect_equal(contract$stress_cost_bps, 10)
})

testthat::test_that("T1 month-end decisions execute only at the following open", {
  contract <- g5_test_t1_contract()
  bars <- g5_test_t1_bars(contract)
  schedule <- g5_t1_month_end_schedule(bars, contract)
  january <- schedule[schedule$month_id == "2020-01", , drop = FALSE]
  testthat::expect_equal(january$decision_date, as.Date("2020-01-31"))
  testthat::expect_equal(january$execution_date, as.Date("2020-02-03"))
  testthat::expect_true(january$execution_date > january$decision_date)
})

testthat::test_that("T1 uses exactly twelve prior month-ends and asset-minus-BIL trend", {
  contract <- g5_test_t1_contract()
  bars <- g5_test_t1_bars(contract)
  panel <- g5_t1_build_observation_panel(bars, 12L, contract)
  spy <- panel[
    panel$symbol == "SPY" &
      panel$decision_date == as.Date("2020-01-31"),
    ,
    drop = FALSE
  ]
  testthat::expect_equal(spy$prior_month_end_date, as.Date("2019-01-31"))
  testthat::expect_equal(
    spy$trend_excess_log_return,
    spy$asset_trend_log_return - spy$cash_trend_log_return
  )
  testthat::expect_equal(spy$signal, "ON")
  iwm <- panel[
    panel$symbol == "IWM" &
      panel$decision_date == as.Date("2020-01-31"),
    ,
    drop = FALSE
  ]
  testthat::expect_equal(iwm$signal, "OFF")
})

testthat::test_that("T1 and exposure-matched controls use frozen long-only weights", {
  contract <- g5_test_t1_contract()
  part <- data.frame(
    symbol = contract$risk_assets,
    signal = c(rep("ON", 7L), rep("OFF", 7L)),
    stringsAsFactors = FALSE
  )
  t1 <- g5_t1_weight_row(part, "t1_trend", contract)
  control <- g5_t1_weight_row(part, "exposure_matched_equal_weight", contract)
  testthat::expect_equal(sum(t1), 1)
  testthat::expect_equal(t1[[contract$cash_proxy]], 0.5)
  testthat::expect_equal(unique(t1[contract$risk_assets][t1[contract$risk_assets] > 0]), 1 / 14)
  testthat::expect_equal(sum(control[contract$risk_assets]), 0.5)
  testthat::expect_equal(unique(control[contract$risk_assets]), 0.5 / 14)
  testthat::expect_equal(control[[contract$cash_proxy]], 0.5)
})

testthat::test_that("T1 charges the frozen one-way cost on traded notional", {
  contract <- g5_test_t1_contract()
  bars <- g5_test_t1_bars(contract)
  panel <- g5_t1_build_observation_panel(bars, 12L, contract)
  replay <- g5_t1_portfolio_replay(panel, 5, contract)$replay
  first <- replay[replay$strategy_id == "t1_trend", , drop = FALSE][1L, , drop = FALSE]
  testthat::expect_equal(first$gross_traded_notional, 1, tolerance = 1e-12)
  testthat::expect_equal(first$implementation_cost, 5 / 10000, tolerance = 1e-12)
  testthat::expect_equal(
    first$net_return,
    (1 - 5 / 10000) * (1 + first$gross_return) - 1,
    tolerance = 1e-12
  )
})

testthat::test_that("T1 integrity audit rejects same-close execution", {
  contract <- g5_test_t1_contract()
  bars <- g5_test_t1_bars(contract)
  panel <- g5_t1_build_observation_panel(bars, 12L, contract)
  panel$execution_date[[1L]] <- panel$decision_date[[1L]]
  audit <- g5_t1_integrity_audit(bars, panel, contract, "PASS")
  testthat::expect_equal(
    audit$status[audit$check_id == "next_open_execution"],
    "FAIL"
  )
})

testthat::test_that("T1 session coverage accepts non-session calendar boundaries only when every reference session exists", {
  contract <- g5_test_t1_contract()
  bars <- g5_test_t1_bars(contract)
  coverage <- g5_t1_session_coverage_audit(bars, contract)
  testthat::expect_true(all(coverage$status == "PASS"))
  missing_date <- coverage$reference_first_session[[1L]]
  broken <- bars[!(
    bars$symbol == "BIL" &
      bars$session_date == missing_date
  ), , drop = FALSE]
  broken_coverage <- g5_t1_session_coverage_audit(broken, contract)
  testthat::expect_equal(
    broken_coverage$status[broken_coverage$symbol == "BIL"],
    "FAIL"
  )
})
