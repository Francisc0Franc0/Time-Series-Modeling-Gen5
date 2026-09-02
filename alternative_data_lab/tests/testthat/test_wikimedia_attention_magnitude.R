library(testthat)

source(testthat::test_path("..", "..", "R", "wikimedia_attention_lead.R"))
source(testthat::test_path("..", "..", "R", "wikimedia_attention_magnitude.R"))

magnitude_test_contract <- function() {
  x <- adwm_contract()
  x$attention_start <- as.Date("2020-01-01")
  x$attention_end <- as.Date("2020-02-09")
  x$market_end <- as.Date("2020-02-14")
  x
}

magnitude_test_daily <- function() {
  data.frame(
    date = seq(as.Date("2020-01-01"), by = "day", length.out = 40L),
    views = c(rep(100, 39L), 1000), observed_from_api = TRUE,
    stringsAsFactors = FALSE
  )
}

magnitude_test_bars <- function() {
  data.frame(
    symbol = "GME",
    session_date = as.Date(c("2020-02-10", "2020-02-11", "2020-02-12", "2020-02-13", "2020-02-14")),
    open = c(10, 11, 12, 10, 14), close = c(10.5, 11.5, 11, 13.5, 14.5),
    high = c(11, 12, 13, 14, 15), low = c(9, 10, 10, 9, 13),
    adjusted = TRUE, timeframe = "1D", provider = "alpaca",
    stringsAsFactors = FALSE
  )
}

test_that("the magnitude contract preserves the causal clock and outcomes", {
  contract <- adwm_validate_contract(adwm_contract())
  expect_identical(contract$hypothesis_id, "ADL-WIKI-03.1")
  expect_identical(contract$parent_id, "ADL-WIKI-02.1")
  expect_identical(contract$publication_buffer_hours, 48L)
  expect_identical(contract$primary_forward_sessions, 1L)
  expect_identical(contract$descriptive_attention_bins, 10L)
})

test_that("magnitude outcomes are absolute return and entry-session range", {
  contract <- magnitude_test_contract()
  features <- adwm_attention_features(magnitude_test_daily(), contract)
  panel <- adwm_forward_panel(features, magnitude_test_bars(), contract)
  row <- panel[panel$entry_session == as.Date("2020-02-12"), , drop = FALSE]
  expect_equal(nrow(row), 1L)
  expect_equal(row$source_attention_date, as.Date("2020-02-09"))
  expect_equal(row$future_open_log_return, log(10 / 12))
  expect_equal(row$future_abs_open_log_return, abs(log(10 / 12)))
  expect_equal(row$entry_session_log_range, log(13 / 10))
  expect_true(row$safe_available_date <= row$entry_session)
})

test_that("descriptive bins preserve all observations and ordered attention", {
  panel <- data.frame(
    attention_log_ratio = seq(-1, 1, length.out = 20),
    future_abs_open_log_return = seq(0.01, 0.20, length.out = 20),
    entry_session_log_range = seq(0.02, 0.40, length.out = 20)
  )
  bins <- adwm_attention_bin_summary(panel, bins = 10L)
  expect_equal(nrow(bins), 10L)
  expect_equal(sum(bins$observations), 20L)
  expect_true(all(diff(bins$median_attention_log_ratio) > 0))
  expect_true(all(diff(bins$median_abs_open_log_return) > 0))
  expect_true(all(diff(bins$median_entry_session_log_range) > 0))
})

test_that("readout requires concordant positive rank relationships", {
  good <- data.frame(
    relationship = c("causal_attention_to_absolute_open_return", "causal_attention_to_entry_session_range"),
    spearman = c(0.08, 0.12), stringsAsFactors = FALSE
  )
  expect_identical(adwm_readout_status(good), "DESCRIPTIVE_MAGNITUDE_CLUE_REQUIRES_FRESH_CONFIRMATION")
  good$spearman[[2L]] <- 0.01
  expect_identical(adwm_readout_status(good), "STOP_NO_OBVIOUS_ONE_SESSION_MAGNITUDE_LEAD")
})
