source(testthat::test_path("..", "..", "R", "hyp_mom_05_1_triple_sma_pullback.R"))

h051_manual_state <- function() {
  dates <- as.Date(c("2020-12-31", "2021-01-04", "2021-01-05", "2021-01-06", "2021-01-07",
                     "2021-01-08", "2021-01-11", "2021-01-12", "2021-01-13"))
  n <- length(dates)
  data.frame(
    symbol = "TEST", session_date = dates, open = rep(100, n), high = rep(101, n), low = rep(99, n),
    close = rep(100, n), volume = rep(1e6, n), sma15 = rep(101, n), sma30 = rep(100, n), sma45 = rep(99, n),
    ordered = c(FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE),
    above_medium = c(FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE),
    order_activation = c(FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE),
    order_loss = c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
    cross_above_medium = c(FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE),
    cross_below_medium = c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
}

h051_replay_fixture <- function() {
  dates <- as.Date(c("2021-01-04", "2021-01-05", "2021-01-06"))
  state <- data.frame(
    symbol = "TEST", session_date = dates, open = c(100, 105, 110), high = c(101, 106, 111),
    low = c(99, 104, 109), close = c(100, 105, 110), volume = 1e6,
    sma15 = 100, sma30 = 99, sma45 = 98, ordered = TRUE, stringsAsFactors = FALSE
  )
  schedule <- data.frame(
    row_index = 1:3, session_date = dates, signal_date = dates - 1,
    policy = "BUY_HOLD", target_long = c(TRUE, TRUE, FALSE),
    transition_reason = c("BUY_HOLD_ENTRY", "HOLD_LONG", "BOUNDARY_EXIT"), stringsAsFactors = FALSE
  )
  list(state = state, schedule = schedule)
}

testthat::test_that("contract freezes the approved discovery lane", {
  contract <- h051_contract()
  testthat::expect_equal(c(contract$fast_sessions, contract$medium_sessions, contract$slow_sessions), c(15L, 30L, 45L))
  testthat::expect_equal(contract$leverages, c(1, 1.8))
  testthat::expect_equal(contract$discovery_end, as.Date("2023-12-29"))
  changed <- contract
  changed$medium_sessions <- 25L
  testthat::expect_error(h051_validate_contract(changed), "Frozen contract changed")
})

testthat::test_that("primary rule ignores order loss, exits below medium, then requires reclaim", {
  schedule <- h051_schedule(h051_manual_state(), "H051")
  testthat::expect_true(schedule$target_long[schedule$session_date == as.Date("2021-01-05")])
  testthat::expect_true(schedule$target_long[schedule$session_date == as.Date("2021-01-07")])
  testthat::expect_equal(schedule$transition_reason[schedule$session_date == as.Date("2021-01-07")], "HOLD_LONG")
  testthat::expect_false(schedule$target_long[schedule$session_date == as.Date("2021-01-08")])
  testthat::expect_equal(schedule$transition_reason[schedule$session_date == as.Date("2021-01-08")], "CROSS_BELOW_MEDIUM")
  testthat::expect_true(schedule$target_long[schedule$session_date == as.Date("2021-01-11")])
  testthat::expect_equal(schedule$transition_reason[schedule$session_date == as.Date("2021-01-11")], "MEDIUM_RECLAIM")
  testthat::expect_false(tail(schedule$target_long, 1L))
})

testthat::test_that("fixed-quantity 1.8x exposure is not daily-reset leverage", {
  f <- h051_replay_fixture()
  result <- h051_replay(f$state, f$schedule, 1.8, 0, 0, "GROSS")
  testthat::expect_equal(tail(result$path$wealth_open, 1L), 1.18, tolerance = 1e-12)
  testthat::expect_equal(result$trades$underlying_return, 0.10, tolerance = 1e-12)
  testthat::expect_equal(result$trades$holding_sessions, 2L)
  testthat::expect_equal(h051_summary(result)$turnover_events, 2L)
})

testthat::test_that("financing and costs reduce leveraged terminal wealth", {
  f <- h051_replay_fixture()
  gross <- h051_replay(f$state, f$schedule, 1.8, 0, 0, "GROSS")
  primary <- h051_replay(f$state, f$schedule, 1.8, 5, 0.06, "PRIMARY")
  testthat::expect_lt(tail(primary$path$wealth_open, 1L), tail(gross$path$wealth_open, 1L))
  testthat::expect_gt(primary$trades$financing_cost, 0)
  testthat::expect_true(is.finite(primary$trades$minimum_equity_ratio))
})

testthat::test_that("circular exposure controls are deterministic", {
  open <- c(100, 101, 99, 102, 104, 103)
  state <- c(TRUE, TRUE, FALSE, TRUE, TRUE, FALSE)
  a <- h051_state_return(open, state, 1, 5, 0.06)
  b <- h051_state_return(open, state, 1, 5, 0.06)
  testthat::expect_equal(a, b)
  testthat::expect_true(is.finite(a))
})

testthat::test_that("confirmation observations fail loudly", {
  n <- 70L
  bars <- data.frame(
    symbol = "TEST", session_date = seq(as.Date("2023-09-01"), by = "day", length.out = n),
    open = 100 + seq_len(n), high = 101 + seq_len(n), low = 99 + seq_len(n), close = 100 + seq_len(n),
    volume = 1e6, stringsAsFactors = FALSE
  )
  bars <- rbind(bars, transform(tail(bars, 1L), session_date = as.Date("2024-01-02")))
  testthat::expect_error(h051_validate_bars(bars), "Confirmation observations")
})
