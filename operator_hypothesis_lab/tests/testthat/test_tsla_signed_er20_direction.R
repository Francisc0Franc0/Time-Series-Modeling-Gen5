source(testthat::test_path("..", "..", "R", "tsla_signed_er20_direction.R"))

testthat::test_that("contract freezes the descriptive TSLA surface", {
  contract <- tsder_contract()
  testthat::expect_equal(contract$window_sessions, 20L)
  testthat::expect_equal(contract$direction_cutoff, 0.30)
  testthat::expect_equal(contract$analysis_start, as.Date("2018-01-02"))
  testthat::expect_equal(contract$analysis_end, as.Date("2023-12-29"))
})
testthat::test_that("signed efficiency ratio preserves direction and penalizes churn", {
  up <- tsder_signed_efficiency_ratio(log(1:6), 5L)
  down <- tsder_signed_efficiency_ratio(log(6:1), 5L)
  choppy <- tsder_signed_efficiency_ratio(c(0, 1, 0, 1, 0, 0), 5L)
  testthat::expect_equal(tail(up, 1), 1)
  testthat::expect_equal(tail(down, 1), -1)
  testthat::expect_equal(tail(choppy, 1), 0)
})

testthat::test_that("classification has symmetric fixed boundaries", {
  observed <- tsder_classify_direction(c(NA, -0.31, -0.30, -0.29, 0, 0.29, 0.30, 0.31))
  expected <- c(NA, "DOWN_TREND", "DOWN_TREND", "SIDEWAYS", "SIDEWAYS", "SIDEWAYS", "UP_TREND", "UP_TREND")
  testthat::expect_equal(observed, expected)
  testthat::expect_error(tsder_classify_direction(0, 0), "strictly between")
})

testthat::test_that("the score is causal under appended future observations", {
  history <- log(seq(100, 150, length.out = 60))
  original <- tsder_signed_efficiency_ratio(history, 20L)
  extended <- tsder_signed_efficiency_ratio(c(history, log(200)), 20L)
  testthat::expect_equal(extended[seq_along(original)], original)
})

testthat::test_that("spans, occupancy, durations, and transitions are deterministic", {
  dates <- as.Date("2020-01-01") + 0:6
  states <- c("UP_TREND", "UP_TREND", "SIDEWAYS", "DOWN_TREND", "DOWN_TREND", "SIDEWAYS", "UP_TREND")
  spans <- tsder_state_spans(dates, states)
  testthat::expect_equal(spans$sessions, c(2L, 1L, 2L, 1L, 1L))
  occupancy <- tsder_state_occupancy(states)
  testthat::expect_equal(occupancy$sessions, c(3L, 2L, 2L))
  durations <- tsder_duration_summary(spans)
  testthat::expect_equal(durations$spans, c(2L, 2L, 1L))
  transitions <- tsder_transition_tables(states)
  testthat::expect_equal(sum(as.matrix(transitions$counts[-1L])), length(states) - 1L)
  quality <- tsder_quality_summary(states, spans)
  testthat::expect_equal(quality$state_changes, 4L)
  testthat::expect_equal(quality$direct_up_down_reversals, 0L)
})
