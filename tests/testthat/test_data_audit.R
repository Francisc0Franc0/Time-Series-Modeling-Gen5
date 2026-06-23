test_that("audit reports missing, stale, duplicate, cache, and provider timestamp fields", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "data_audit.R"))

  bars <- data.frame(
    symbol = c("SPY", "SPY", "SPY", "QQQ", "QQQ"),
    session_date = as.Date(c("2026-06-18", "2026-06-22", "2026-06-22", "2026-06-18", "2026-06-19")),
    open = c(99, 100, 100, 200, 201),
    high = c(100, 101, 101, 202, 203),
    low = c(98, 99, 99, 199, 200),
    close = c(99.5, 100.5, 100.5, 201, 202),
    volume = c(900, 1000, 1000, 1400, 1500),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = c("z", "a", "a", "b", "c"),
    stringsAsFactors = FALSE
  )

  audit <- g5_audit_bars(
    bars = bars,
    requested_symbols = c("SPY", "QQQ", "TSLA"),
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    provider_query_timestamp = "2026-06-22 17:00:00",
    cache_hits = c("SPY", "QQQ"),
    cache_misses = "TSLA",
    availability_warnings = "operator_supplied_warning"
  )

  expect_equal(audit$requested_symbol_count, 3L)
  expect_equal(audit$missing_symbol_count, 1L)
  expect_identical(audit$missing_symbols, "TSLA")
  expect_equal(audit$stale_symbol_count, 1L)
  expect_identical(audit$stale_symbols, "QQQ")
  expect_equal(audit$duplicate_symbol_session_count, 1L)
  expect_equal(audit$row_count, 5L)
  expect_equal(audit$cache_hit_symbol_count, 2L)
  expect_equal(audit$cache_miss_symbol_count, 1L)
  expect_identical(audit$provider_query_timestamp, "2026-06-22 17:00:00")
  expect_identical(audit$first_available_session_by_symbol, "SPY=2026-06-18;QQQ=2026-06-18;TSLA=NA")
  expect_identical(audit$latest_available_session_by_symbol, "SPY=2026-06-22;QQQ=2026-06-19;TSLA=NA")
  expect_identical(as.Date(audit$requested_start_date), as.Date("2026-06-18"))
  expect_identical(as.Date(audit$requested_end_date), as.Date("2026-06-22"))
  expect_identical(as.Date(audit$observed_start_date), as.Date("2026-06-18"))
  expect_identical(as.Date(audit$observed_end_date), as.Date("2026-06-22"))
  expect_equal(audit$empty_symbol_count, 1L)
  expect_identical(audit$empty_symbols, "TSLA")
  expect_equal(audit$partial_history_symbol_count, 1L)
  expect_identical(audit$partial_history_symbols, "QQQ")
  expect_true(audit$availability_warning_count >= 3L)
  expect_match(audit$availability_warnings, "operator_supplied_warning")
  expect_match(audit$availability_warnings, "empty_symbols=TSLA", fixed = TRUE)
  expect_match(audit$availability_warnings, "partial_history_symbols=QQQ", fixed = TRUE)
})

test_that("audit reports all requested symbols when provider payload is empty", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "data_audit.R"))

  audit <- g5_audit_bars(
    bars = g5_empty_bar_data(),
    requested_symbols = c("SPY", "QQQ"),
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    provider_query_timestamp = "2026-06-22 17:00:00"
  )

  expect_equal(audit$row_count, 0L)
  expect_equal(audit$present_symbol_count, 0L)
  expect_equal(audit$empty_symbol_count, 2L)
  expect_identical(audit$empty_symbols, "SPY,QQQ")
  expect_equal(audit$partial_history_symbol_count, 0L)
  expect_true(is.na(audit$observed_start_date))
  expect_true(is.na(audit$observed_end_date))
  expect_match(audit$availability_warnings, "empty_symbols=SPY,QQQ", fixed = TRUE)
  expect_match(audit$availability_warnings, "empty_provider_payload_for_requested_range", fixed = TRUE)
})
