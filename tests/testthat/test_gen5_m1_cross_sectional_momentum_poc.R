source(testthat::test_path("..", "..", "R", "data_contract.R"))
source(testthat::test_path("..", "..", "R", "gen5_m1_cross_sectional_momentum_poc.R"))

g5_test_m1_contract <- function() {
  contract <- g5_m1_contract()
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

g5_test_m1_bars <- function(contract = g5_test_m1_contract()) {
  dates <- seq(contract$query_start, contract$query_end, by = "day")
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5]
  symbols <- g5_m1_required_symbols(contract)
  do.call(rbind, lapply(seq_along(symbols), function(symbol_i) {
    symbol <- symbols[[symbol_i]]
    daily_rate <- if (symbol == contract$cash_proxy) 0.00003 else 0.00005 + symbol_i * 0.000004
    close <- 100 * exp(daily_rate * seq_along(dates))
    open <- close * (1 - 0.0002)
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
  }))
}

testthat::test_that("M1 freezes the approved universe and mechanism", {
  contract <- g5_m1_contract()
  testthat::expect_equal(nrow(contract$universe), 24L)
  testthat::expect_equal(
    as.integer(table(contract$universe$economic_group)[c(
      "us_sector", "developed_country", "emerging_country"
    )]),
    c(9L, 7L, 8L)
  )
  testthat::expect_equal(contract$cash_proxy, "BIL")
  testthat::expect_equal(contract$primary_lookback_months, 12L)
  testthat::expect_equal(contract$diagnostic_lookbacks, c(6L, 18L))
  testthat::expect_equal(contract$random_policy_count, 2000L)
  testthat::expect_equal(contract$random_seed, 5401L)
})

testthat::test_that("M1 month-end decisions use t-minus-12 through t-minus-1 and next-open execution", {
  contract <- g5_test_m1_contract()
  bars <- g5_test_m1_bars(contract)
  panel <- g5_m1_build_panel(bars, 12L, contract)
  row <- panel[
    panel$symbol == "XLB" & panel$decision_date == as.Date("2020-01-31"),
    ,
    drop = FALSE
  ]
  testthat::expect_equal(row$prior_lookback_date, as.Date("2019-01-31"))
  testthat::expect_equal(row$prior_skip_date, as.Date("2019-12-31"))
  testthat::expect_equal(row$execution_date, as.Date("2020-02-03"))
  testthat::expect_true(row$execution_date > row$decision_date)
})

testthat::test_that("M1 ranks eligible ETFs deterministically and enforces breadth", {
  contract <- g5_test_m1_contract()
  bars <- g5_test_m1_bars(contract)
  panel <- g5_m1_build_panel(bars, 12L, contract)
  part <- panel[panel$decision_date == as.Date("2020-01-31"), , drop = FALSE]
  testthat::expect_true(all(part$eligible))
  testthat::expect_true(all(part$month_admissible))
  testthat::expect_equal(unique(part$k_count), 6L)
  testthat::expect_equal(sum(part$top_k), 6L)
  testthat::expect_equal(
    part$symbol[part$portfolio_rank == 1L],
    tail(contract$universe$symbol, 1L)
  )

  broken <- bars[!(
    bars$symbol %in% contract$universe$symbol[1:7] &
      bars$session_date >= as.Date("2019-12-01") &
      bars$session_date <= as.Date("2020-01-31")
  ), , drop = FALSE]
  broken_panel <- g5_m1_build_panel(broken, 12L, contract)
  broken_part <- broken_panel[
    broken_panel$decision_date == as.Date("2020-01-31"),
    ,
    drop = FALSE
  ]
  testthat::expect_false(any(broken_part$month_admissible))
  testthat::expect_true(all(is.na(broken_part$portfolio_rank)))
})

testthat::test_that("M1 randomized concentration control is deterministic", {
  contract <- g5_test_m1_contract()
  panel <- g5_m1_build_panel(g5_test_m1_bars(contract), 12L, contract)
  first <- g5_m1_random_control(panel, policy_count = 20L, seed = 5401L, evaluation_period = "development_2017_2021")
  second <- g5_m1_random_control(panel, policy_count = 20L, seed = 5401L, evaluation_period = "development_2017_2021")
  testthat::expect_equal(first$distribution, second$distribution)
  testthat::expect_equal(first$detail, second$detail)
})

testthat::test_that("M1 charges one-way costs on gross traded notional", {
  contract <- g5_test_m1_contract()
  bars <- g5_test_m1_bars(contract)
  panel <- g5_m1_build_panel(bars, 12L, contract)
  replay <- g5_m1_portfolio_replay(panel, bars, 5, contract)$replay
  first <- replay[replay$strategy_id == "m1_top_quartile", , drop = FALSE][1L, , drop = FALSE]
  testthat::expect_equal(first$gross_traded_notional, 1, tolerance = 1e-12)
  testthat::expect_equal(first$implementation_cost, 5 / 10000, tolerance = 1e-12)
  testthat::expect_equal(
    first$net_return,
    (1 - 5 / 10000) * (1 + first$gross_return) - 1,
    tolerance = 1e-12
  )
})

testthat::test_that("M1 integrity rejects same-close execution and incomplete coverage", {
  contract <- g5_test_m1_contract()
  bars <- g5_test_m1_bars(contract)
  panel <- g5_m1_build_panel(bars, 12L, contract)
  eligible_i <- which(panel$eligible)[[1L]]
  panel$execution_date[[eligible_i]] <- panel$decision_date[[eligible_i]]
  audit <- g5_m1_integrity_audit(bars, panel, contract, "PASS")
  testthat::expect_equal(audit$status[audit$check_id == "next_open_execution"], "FAIL")

  first_date <- min(bars$session_date)
  broken <- bars[!(bars$symbol == "BIL" & bars$session_date == first_date), , drop = FALSE]
  coverage <- g5_m1_session_coverage_audit(broken, contract)
  testthat::expect_equal(coverage$status[coverage$symbol == "BIL"], "FAIL")
})

testthat::test_that("M1B gates can be represented as structurally not run", {
  gates <- g5_m1_not_run_gates()
  testthat::expect_equal(nrow(gates), 4L)
  testthat::expect_true(all(gates$status == "NOT_RUN"))
})
