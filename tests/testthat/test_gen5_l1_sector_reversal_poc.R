source(testthat::test_path("..", "..", "R", "data_contract.R"))
source(testthat::test_path("..", "..", "R", "gen5_l1_sector_reversal_poc.R"))

g5_test_l1_contract <- function() {
  contract <- g5_l1_contract()
  contract$periods <- data.frame(
    evaluation_period = c("TRAIN", "DEVELOPMENT", "CONFIRMATION"),
    start_date = as.Date(c("2019-01-01", "2020-01-01", "2021-01-01")),
    end_date = as.Date(c("2019-12-31", "2020-12-31", "2022-12-30")),
    stringsAsFactors = FALSE
  )
  contract$query_start <- as.Date("2019-01-01")
  contract$query_end <- as.Date("2022-12-30")
  contract$as_of_timestamp <- "2022-12-30 17:30:00"
  contract
}

g5_test_l1_bars <- function(contract = g5_test_l1_contract()) {
  dates <- seq(contract$query_start, contract$query_end, by = "day")
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5]
  symbols <- g5_l1_required_symbols(contract)
  frames <- lapply(seq_along(symbols), function(symbol_i) {
    symbol <- symbols[[symbol_i]]
    daily_rate <- if (symbol == contract$benchmark) {
      0.00015
    } else {
      0.00005 + symbol_i * 0.00002
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

testthat::test_that("L1 freezes the approved universe, timing, weights, and costs", {
  contract <- g5_l1_contract()
  testthat::expect_equal(
    contract$universe$symbol,
    c("XLB", "XLE", "XLF", "XLI", "XLK", "XLP", "XLU", "XLV", "XLY")
  )
  testthat::expect_equal(contract$lookback_sessions, 5L)
  testthat::expect_equal(contract$holding_sessions, 5L)
  testthat::expect_equal(contract$long_count, 2L)
  testthat::expect_equal(contract$short_count, 2L)
  testthat::expect_equal(contract$long_gross, 0.50)
  testthat::expect_equal(contract$short_gross, 0.50)
  testthat::expect_equal(contract$primary_cost_bps, 5)
  testthat::expect_equal(contract$stress_cost_bps, 10)
})
testthat::test_that("L1 schedules next-open entries and nonoverlapping five-session outcomes", {
  contract <- g5_test_l1_contract()
  bars <- g5_test_l1_bars(contract)
  schedule <- g5_l1_schedule(bars, contract, "TRAIN")
  first <- schedule[1L, , drop = FALSE]
  testthat::expect_true(first$signal_window_start_date < first$decision_date)
  testthat::expect_true(first$decision_date < first$execution_date)
  sessions <- g5_l1_reference_sessions(bars, contract)
  testthat::expect_equal(
    match(first$exit_date, sessions) - match(first$execution_date, sessions),
    5L
  )
  testthat::expect_true(all(
    schedule$execution_date[-1L] >= schedule$exit_date[-nrow(schedule)]
  ))
})

testthat::test_that("L1 ranks recent losers long and recent winners short", {
  contract <- g5_test_l1_contract()
  bars <- g5_test_l1_bars(contract)
  panel <- g5_l1_build_panel(bars, contract, "TRAIN")
  first <- panel[panel$cohort_id == unique(panel$cohort_id)[[1L]], , drop = FALSE]
  testthat::expect_equal(first$symbol[first$position == "LONG"], c("XLB", "XLE"))
  testthat::expect_equal(first$symbol[first$position == "SHORT"], c("XLV", "XLY"))
  testthat::expect_equal(sum(first$weight[first$weight > 0]), 0.50)
  testthat::expect_equal(sum(first$weight[first$weight < 0]), -0.50)
  testthat::expect_equal(sum(abs(first$weight)), 1)
  testthat::expect_equal(sum(first$weight), 0)
})

testthat::test_that("L1 charges round-trip cost and short borrow stress explicitly", {
  contract <- g5_test_l1_contract()
  bars <- g5_test_l1_bars(contract)
  panel <- g5_l1_build_panel(bars, contract, "TRAIN")
  primary <- g5_l1_cohort_summary(
    panel, contract$primary_cost_bps,
    contract$primary_borrow_bps_annual, contract
  )
  stress <- g5_l1_cohort_summary(
    panel, contract$stress_cost_bps,
    contract$stress_borrow_bps_annual, contract
  )
  testthat::expect_equal(unique(primary$transaction_cost), 10 / 10000)
  testthat::expect_equal(unique(primary$borrow_cost), 0)
  testthat::expect_equal(unique(stress$transaction_cost), 20 / 10000)
  testthat::expect_equal(
    unique(stress$borrow_cost),
    100 / 10000 * 0.50 * 5 / 252
  )
  testthat::expect_equal(
    primary$net_portfolio_return,
    primary$gross_portfolio_return -
      primary$transaction_cost -
      primary$borrow_cost
  )
})

testthat::test_that("L1 keeps absolute direction separate from relative spread prediction", {
  contract <- g5_test_l1_contract()
  bars <- g5_test_l1_bars(contract)
  panel <- g5_l1_build_panel(bars, contract, "TRAIN")
  direction <- g5_l1_directional_scorecard(
    panel, contract$primary_cost_bps, contract
  )
  testthat::expect_equal(
    direction$scorecard$coverage,
    4 / 9,
    tolerance = 1e-12
  )
  testthat::expect_equal(
    direction$scorecard$raw_direction_accuracy,
    0.50,
    tolerance = 1e-12
  )
  testthat::expect_equal(
    sum(direction$confusion$count),
    nrow(panel) * 4 / 9
  )
})

testthat::test_that("L1 structurally stops before later outcomes when TRAIN mechanism fails", {
  contract <- g5_test_l1_contract()
  bars <- g5_test_l1_bars(contract)
  analysis <- g5_l1_run_analysis(bars, contract, "PASS")
  testthat::expect_false(analysis$l1a_pass)
  testthat::expect_false(analysis$l1b_run)
  testthat::expect_identical(
    analysis$overall_status,
    "STOP_L1A_SECTOR_REVERSAL_MECHANISM"
  )
  testthat::expect_null(analysis$full_panel)
  testthat::expect_null(analysis$confirmation_metrics)
  testthat::expect_true(all(
    analysis$gates$status[grepl("^L1B_", analysis$gates$gate_id)] == "NOT_RUN"
  ))
})

testthat::test_that("L1 TRAIN evidence is invariant to post-TRAIN price changes", {
  contract <- g5_test_l1_contract()
  bars <- g5_test_l1_bars(contract)
  altered <- bars
  later <- altered$session_date > contract$periods$end_date[
    contract$periods$evaluation_period == "TRAIN"
  ]
  altered$open[later] <- altered$open[later] * 3
  altered$close[later] <- altered$close[later] * 3
  original_panel <- g5_l1_build_panel(bars, contract, "TRAIN")
  altered_panel <- g5_l1_build_panel(altered, contract, "TRAIN")
  testthat::expect_equal(original_panel$signal_return, altered_panel$signal_return)
  testthat::expect_equal(original_panel$future_return, altered_panel$future_return)
})

testthat::test_that("L1 session audit detects a missing frozen reference session", {
  contract <- g5_test_l1_contract()
  bars <- g5_test_l1_bars(contract)
  coverage <- g5_l1_session_coverage_audit(bars, contract)
  testthat::expect_true(all(coverage$status == "PASS"))
  missing_date <- coverage$reference_first_session[[1L]]
  broken <- bars[!(
    bars$symbol == "SPY" &
      bars$session_date == missing_date
  ), , drop = FALSE]
  broken_coverage <- g5_l1_session_coverage_audit(broken, contract)
  testthat::expect_equal(
    broken_coverage$status[broken_coverage$symbol == "SPY"],
    "FAIL"
  )
})

testthat::test_that("L1 analytical module does not infer runtime date", {
  path <- testthat::test_path("..", "..", "R", "gen5_l1_sector_reversal_poc.R")
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
