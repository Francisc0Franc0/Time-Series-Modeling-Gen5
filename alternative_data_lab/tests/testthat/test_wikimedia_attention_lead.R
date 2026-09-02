library(testthat)

source(testthat::test_path("..", "..", "R", "wikimedia_attention_lead.R"))

lead_test_daily <- function() {
  dates <- seq(as.Date("2020-01-01"), by = "day", length.out = 40L)
  data.frame(
    date = dates,
    views = c(rep(100, 39L), 1000),
    observed_from_api = TRUE,
    stringsAsFactors = FALSE
  )
}

lead_test_contract <- function() {
  x <- adwl_contract()
  x$attention_start <- as.Date("2020-01-01")
  x$attention_end <- as.Date("2020-02-09")
  x$market_end <- as.Date("2020-02-14")
  x
}

lead_test_bars <- function() {
  dates <- as.Date(c("2020-02-10", "2020-02-11", "2020-02-12", "2020-02-13", "2020-02-14"))
  data.frame(
    symbol = "GME", session_date = dates, open = c(10, 11, 12, 13, 14),
    close = c(10.5, 11.5, 12.5, 13.5, 14.5), adjusted = TRUE,
    timeframe = "1D", provider = "alpaca", stringsAsFactors = FALSE
  )
}

test_that("the first directional lead contract remains narrow", {
  contract <- adwl_validate_contract(adwl_contract())
  expect_identical(contract$trailing_calendar_days, 28L)
  expect_identical(contract$publication_buffer_hours, 48L)
  expect_identical(contract$primary_forward_sessions, 1L)
  expect_identical(contract$authority, "DESCRIPTIVE_LEADING_SIGNAL_POC_ONLY")
})

test_that("attention surprise excludes the current day from its baseline", {
  features <- adwl_attention_features(lead_test_daily(), lead_test_contract())
  expect_equal(features$prior_28d_median[[40L]], 100)
  expect_equal(features$attention_log_ratio[[40L]], log(10))
  expect_equal(features$prior_observation_count[[40L]], 28L)
})

test_that("safe availability is 48 hours after the UTC day endpoint", {
  features <- adwl_attention_features(lead_test_daily(), lead_test_contract())
  expect_equal(features$safe_available_date[[40L]], as.Date("2020-02-12"))
})

test_that("as-of join never uses attention before safe availability", {
  features <- adwl_attention_features(lead_test_daily(), lead_test_contract())
  panel <- adwl_forward_panel(features, lead_test_bars(), lead_test_contract())
  row <- panel[panel$entry_session == as.Date("2020-02-12"), , drop = FALSE]
  expect_equal(nrow(row), 1L)
  expect_equal(row$source_attention_date, as.Date("2020-02-09"))
  expect_equal(row$safe_available_date, as.Date("2020-02-12"))
  expect_equal(row$future_open_log_return, log(13 / 12))
  expect_true(all(panel$safe_available_date <= panel$entry_session))
})

test_that("relationship summary reports the frozen descriptive measures", {
  out <- adwl_relationship_summary(1:5, c(1, 2, 3, 4, 6), "fixture")
  expect_equal(out$observations, 5L)
  expect_gt(out$pearson, 0.95)
  expect_equal(out$spearman, 1)
  expect_gt(out$slope, 1)
  expect_gt(out$r_squared, 0.9)
})
