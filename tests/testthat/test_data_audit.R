test_that("audit reports missing, stale, duplicate, cache, and provider timestamp fields", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "data_audit.R"))

  bars <- data.frame(
    symbol = c("SPY", "SPY", "QQQ", "QQQ"),
    session_date = as.Date(c("2026-06-22", "2026-06-22", "2026-06-18", "2026-06-19")),
    open = c(100, 100, 200, 201),
    high = c(101, 101, 202, 203),
    low = c(99, 99, 199, 200),
    close = c(100.5, 100.5, 201, 202),
    volume = c(1000, 1000, 1400, 1500),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = c("a", "a", "b", "c"),
    stringsAsFactors = FALSE
  )

  audit <- g5_audit_bars(
    bars = bars,
    requested_symbols = c("SPY", "QQQ", "TSLA"),
    latest_completed_session = as.Date("2026-06-22"),
    provider_query_timestamp = "2026-06-22 17:00:00",
    cache_hits = c("SPY", "QQQ"),
    cache_misses = "TSLA"
  )

  expect_equal(audit$requested_symbol_count, 3L)
  expect_equal(audit$missing_symbol_count, 1L)
  expect_identical(audit$missing_symbols, "TSLA")
  expect_equal(audit$stale_symbol_count, 1L)
  expect_identical(audit$stale_symbols, "QQQ")
  expect_equal(audit$duplicate_symbol_session_count, 1L)
  expect_equal(audit$row_count, 4L)
  expect_equal(audit$cache_hit_symbol_count, 2L)
  expect_equal(audit$cache_miss_symbol_count, 1L)
  expect_identical(audit$provider_query_timestamp, "2026-06-22 17:00:00")
})
