source(testthat::test_path("..", "..", "R", "hyp_nvda_intraday_opening_rule.R"))

nio_fixture_sessions <- function(n = 270L) {
  dates <- seq(as.Date("2018-01-02"), by = "day", length.out = n * 2L)
  dates <- dates[!weekdays(dates) %in% c("Saturday", "Sunday")][seq_len(n)]
  opening <- seq(-0.02, 0.02, length.out = n)
  remainder <- 0.15 * opening
  first_open <- rep(100, n)
  ten <- first_open * exp(opening)
  close <- ten * exp(remainder)
  data.frame(
    symbol = "NVDA",
    session_date = dates,
    state_session = c(as.Date("2017-12-29"), head(dates, -1L)),
    atrp_state = rep(c("LOW", "MEDIUM", "HIGH"), length.out = n),
    first_bar_open = first_open,
    ten_am_price = ten,
    session_close = close,
    opening_log_return = opening,
    remainder_log_return = remainder,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("the frozen rule contract fixes timing, history, state, and cost", {
  contract <- nio_validate_contract()
  testthat::expect_equal(contract$rolling_sessions, 252L)
  testthat::expect_equal(contract$opening_quantile_probability, 0.80)
  testthat::expect_equal(contract$candidate_atrp_states, c("LOW", "MEDIUM"))
  testthat::expect_equal(c(contract$entry_clock, contract$exit_clock), c("10:00", "16:00"))
  testthat::expect_equal(contract$round_trip_cost_bps, 10)
})

testthat::test_that("each threshold uses exactly the prior 252 full sessions", {
  sessions <- nio_fixture_sessions()
  candidates <- nio_build_candidates(sessions)
  expected <- unname(stats::quantile(
    sessions$opening_log_return[1:252], 0.80, type = 8, names = FALSE
  ))
  testthat::expect_equal(nrow(candidates), nrow(sessions) - 252L)
  testthat::expect_equal(candidates$rolling_opening_q80[[1L]], expected)
  testthat::expect_equal(candidates$threshold_window_end[[1L]], sessions$session_date[[252L]])
  testthat::expect_true(all(candidates$threshold_window_end < candidates$session_date))
})

testthat::test_that("candidate and control signals use the same causal threshold", {
  sessions <- nio_fixture_sessions()
  sessions$atrp_state[[253L]] <- "LOW"
  candidates <- nio_build_candidates(sessions)
  first <- candidates[1L, ]
  testthat::expect_true(first$opening_tail_signal)
  testthat::expect_true(first$low_med_atr_signal)
  testthat::expect_true(first$candidate_signal)
  testthat::expect_false(first$opening_tail_high_atr_signal)
  testthat::expect_true(first$unconditional_signal)
})

testthat::test_that("10 bps is deducted once from each same-day trade", {
  candidates <- nio_build_candidates(nio_fixture_sessions())
  testthat::expect_equal(
    candidates$net_trade_log_return,
    candidates$gross_trade_log_return - 0.001,
    tolerance = 1e-12
  )
})

testthat::test_that("rule summaries preserve the primary rule and four controls", {
  study <- nio_build_study(nio_fixture_sessions(400L))
  testthat::expect_equal(study$rule_summary$rule_id, nio_contract()$rule_ids)
  testthat::expect_equal(sum(study$rule_summary$primary_rule), 1L)
  testthat::expect_equal(nrow(study$gate$checks), 5L)
})

testthat::test_that("non-causal state timing and inconsistent prices fail loudly", {
  sessions <- nio_fixture_sessions()
  sessions$state_session[[260L]] <- sessions$session_date[[260L]]
  testthat::expect_error(nio_build_candidates(sessions), "causal contract")
  sessions <- nio_fixture_sessions()
  sessions$session_close[[260L]] <- sessions$session_close[[260L]] * 1.1
  testthat::expect_error(nio_build_candidates(sessions), "causal contract")
})
