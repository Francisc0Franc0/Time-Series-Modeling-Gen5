source(testthat::test_path("..", "..", "R", "hyp_nvda_intraday_opening_response.R"))

nior_fixture <- function(opening = c(-0.04, -0.02, 0, 0.02, 0.04),
                         remainder = c(0.03, -0.01, 0.01, 0.02, -0.03)) {
  dates <- as.Date(c("2018-01-02", "2018-01-03", "2018-01-04", "2018-01-05", "2018-01-08"))
  rows <- lapply(seq_along(dates), function(i) {
    first_open <- 100
    first_close <- first_open * exp(opening[[i]])
    closes <- first_close * exp(seq(0, remainder[[i]], length.out = 13L))
    opens <- c(first_open, head(closes, -1L))
    data.frame(
      symbol = "NVDA", session_date = dates[[i]], bar_slot = 1:13,
      bar_time_et = format(
        seq(as.POSIXct("2000-01-03 09:30:00", tz = "America/New_York"), by = "30 min", length.out = 13L),
        "%H:%M:%S"
      ),
      observation_type = "RTH_BAR", log_return = log(closes / opens),
      open = opens, close = closes, feed = "sip", timeframe = "30Min",
      adjustment = "all", stringsAsFactors = FALSE
    )
  })
  points <- do.call(rbind, rows)
  daily_dates <- c(as.Date("2017-12-29"), dates, as.Date("2023-12-29"))
  daily <- data.frame(
    symbol = "NVDA", session_date = daily_dates,
    signed_er20_state = c("DOWN_TREND", "UP_TREND", "SIDEWAYS", "DOWN_TREND", "UP_TREND", "SIDEWAYS", "UP_TREND"),
    atrp_state = c("LOW", "HIGH", "MEDIUM", "LOW", "HIGH", "MEDIUM", "LOW"),
    stringsAsFactors = FALSE
  )
  list(points = points, daily = daily, opening = opening, remainder = remainder)
}

testthat::test_that("the frozen contract fixes the causal clock and broad bins", {
  contract <- nior_validate_contract()
  testthat::expect_equal(contract$opening_slot, 1L)
  testthat::expect_equal(contract$required_slots, 1:13)
  testthat::expect_equal(
    c(contract$lower_tail_probability, contract$upper_tail_probability),
    c(0.20, 0.80)
  )
})

testthat::test_that("session construction uses the first bar and the later close", {
  f <- nior_fixture()
  result <- nior_build_sessions(f$points, f$daily)
  testthat::expect_equal(result$sessions$opening_log_return, f$opening, tolerance = 1e-12)
  testthat::expect_equal(result$sessions$remainder_log_return, f$remainder, tolerance = 1e-12)
  testthat::expect_true(all(result$sessions$state_session < result$sessions$session_date))
  testthat::expect_equal(result$sessions$signed_er20_state[[1L]], "DOWN_TREND")
})

testthat::test_that("partial sessions are excluded rather than changing the horizon", {
  f <- nior_fixture()
  partial_date <- max(f$points$session_date)
  f$points <- f$points[!(f$points$session_date == partial_date & f$points$bar_slot > 7L), ]
  result <- nior_build_sessions(f$points, f$daily)
  testthat::expect_equal(nrow(result$sessions), 4L)
  testthat::expect_false(partial_date %in% result$sessions$session_date)
})

testthat::test_that("sample-wide tails are assigned without a threshold search", {
  f <- nior_fixture()
  thresholds <- nior_opening_thresholds(f$opening)
  bins <- nior_assign_opening_bin(f$opening, thresholds)
  testthat::expect_equal(as.character(bins), c(
    "NEGATIVE_TAIL", "MIDDLE_60", "MIDDLE_60", "MIDDLE_60", "POSITIVE_TAIL"
  ))
})

testthat::test_that("bin and state summaries retain the fixed vocabulary", {
  f <- nior_fixture()
  sessions <- data.frame(
    opening_bin = factor(c("NEGATIVE_TAIL", "MIDDLE_60", "MIDDLE_60", "MIDDLE_60", "POSITIVE_TAIL"),
                         levels = nior_contract()$bin_labels, ordered = TRUE),
    opening_log_return = f$opening,
    remainder_log_return = f$remainder,
    signed_er20_state = c("DOWN_TREND", "UP_TREND", "SIDEWAYS", "DOWN_TREND", "UP_TREND"),
    atrp_state = c("LOW", "HIGH", "MEDIUM", "LOW", "HIGH"),
    stringsAsFactors = FALSE
  )
  unfiltered <- nior_bin_summary(sessions)
  signed <- nior_bin_summary(sessions, "signed_er20_state", "SIGNED_ER20")
  state <- nior_state_summary(sessions)
  testthat::expect_equal(unfiltered$opening_bin, nior_contract()$bin_labels)
  testthat::expect_equal(nrow(signed), 9L)
  testthat::expect_equal(state$observations, 5L)
})

testthat::test_that("paths start at 10:00 and end at the session remainder return", {
  f <- nior_fixture()
  thresholds <- nior_opening_thresholds(f$opening)
  sessions <- data.frame(
    session_date = sort(unique(f$points$session_date)),
    state_session = c(as.Date("2017-12-29"), head(sort(unique(f$points$session_date)), -1L)),
    opening_bin = nior_assign_opening_bin(f$opening, thresholds),
    signed_er20_state = c("DOWN_TREND", "UP_TREND", "SIDEWAYS", "DOWN_TREND", "UP_TREND"),
    atrp_state = c("LOW", "HIGH", "MEDIUM", "LOW", "HIGH"),
    stringsAsFactors = FALSE
  )
  paths <- nior_build_paths(f$points, sessions)
  starts <- paths[paths$path_step == 0L, ]
  ends <- paths[paths$path_step == 12L, ]
  testthat::expect_true(all(starts$clock_label == "10:00"))
  testthat::expect_true(all(abs(starts$cumulative_remainder_log_return) < 1e-12))
  testthat::expect_equal(ends$cumulative_remainder_log_return, f$remainder, tolerance = 1e-12)
})

testthat::test_that("wrong source contracts are rejected loudly", {
  f <- nior_fixture()
  f$points$feed[[1L]] <- "iex"
  testthat::expect_error(nior_validate_points(f$points), "frozen adjusted SIP")
})
