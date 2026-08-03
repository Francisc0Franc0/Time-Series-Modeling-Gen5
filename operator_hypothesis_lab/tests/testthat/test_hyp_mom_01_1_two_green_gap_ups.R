source(testthat::test_path(
  "..", "..", "R", "hyp_mom_01_1_two_green_gap_ups.R"
))

hyp_mom011_fixture <- function() {
  dates <- as.Date("2021-01-04") + 0:14
  open <- c(100, 101, 103, 104, 104, 106, 107, 107, 109, 110, 111, 110, 112, 111, 113)
  close <- c(100, 102, 104, 103, 105, 107, 106, 108, 110, 111, 110, 112, 111, 113, 114)
  data.frame(
    symbol = "TEST",
    session_date = dates,
    open = open,
    high = pmax(open, close) + 1,
    low = pmin(open, close) - 1,
    close = close,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("contract is immutable", {
  contract <- hyp_mom011_contract()
  testthat::expect_equal(contract$holding_sessions, 5L)
  contract$holding_sessions <- 10L
  testthat::expect_error(
    hyp_mom011_validate_contract(contract),
    "contract changed"
  )
})

testthat::test_that("two completed green gap-ups signal only for next-open entry", {
  candidates <- hyp_mom011_signal_candidates(hyp_mom011_fixture())
  testthat::expect_equal(
    candidates$signal_date,
    as.Date(c("2021-01-06", "2021-01-09", "2021-01-12"))
  )
  testthat::expect_equal(candidates$entry_date, candidates$signal_date + 1)
  testthat::expect_equal(candidates$exit_index - candidates$entry_index, rep(5L, 3L))
  testthat::expect_true(all(candidates$first_gap_return > 0))
  testthat::expect_true(all(candidates$second_gap_return > 0))
})

testthat::test_that("overlapping positions are ignored deterministically", {
  candidates <- hyp_mom011_signal_candidates(hyp_mom011_fixture())
  selected <- hyp_mom011_select_nonoverlap(candidates)
  testthat::expect_equal(selected$executed, c(TRUE, FALSE, TRUE))
  testthat::expect_equal(sum(selected$executed), 2L)
  testthat::expect_equal(
    selected$overlap_disposition,
    c("EXECUTED", "IGNORED_WHILE_INVESTED", "EXECUTED")
  )
})

testthat::test_that("round-trip costs are charged multiplicatively", {
  expected <- 0.9995 * 1.10 * 0.9995 - 1
  testthat::expect_equal(hyp_mom011_apply_cost(0.10, 5), expected)
  testthat::expect_lt(hyp_mom011_apply_cost(0, 5), 0)
})

testthat::test_that("replay exits before any same-day re-entry", {
  bars <- hyp_mom011_fixture()
  candidates <- hyp_mom011_select_nonoverlap(
    hyp_mom011_signal_candidates(bars)
  )
  path <- hyp_mom011_replay(bars, candidates, 5)
  testthat::expect_true(any(path$in_position))
  testthat::expect_true(all(is.finite(path$strategy_wealth_close)))
  testthat::expect_equal(tail(path$strategy_wealth_close, 1), tail(path$strategy_wealth_open, 1))
})

testthat::test_that("matched random schedules are reproducible and non-overlapping", {
  set.seed(42)
  first <- hyp_mom011_random_schedule(1:100, 10L, 5L)
  set.seed(42)
  second <- hyp_mom011_random_schedule(1:100, 10L, 5L)
  testthat::expect_equal(first, second)
  testthat::expect_true(all(diff(first) >= 5L))
})

testthat::test_that("confirmation observations fail loudly", {
  bars <- hyp_mom011_fixture()
  bars$session_date[[nrow(bars)]] <- as.Date("2024-01-02")
  testthat::expect_error(
    hyp_mom011_validate_bars(bars),
    "Confirmation observations"
  )
})

testthat::test_that("registry validator enforces size and sector breadth", {
  registry <- data.frame(
    instance_id = sprintf("H%02d", 1:22),
    symbol = sprintf("S%02d", 1:22),
    sector = rep(sprintf("Sector%02d", 1:11), each = 2),
    role = "test",
    source_registry = "fixture",
    stringsAsFactors = FALSE
  )
  testthat::expect_invisible(hyp_mom011_validate_registry(registry))
  testthat::expect_error(
    hyp_mom011_validate_registry(registry[-1L, ]),
    "22 stocks"
  )
})
