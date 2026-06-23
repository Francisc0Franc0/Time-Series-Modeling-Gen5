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
    availability_warnings = "operator_supplied_warning",
    cache_refresh_plan = data.frame(
      symbol = c("SPY", "QQQ", "TSLA"),
      needs_fetch = c(FALSE, TRUE, TRUE),
      refresh_decision = c("fully_cached", "stale_cache", "cold_cache"),
      fetch_start_date = as.Date(c(NA, "2026-06-20", "2026-06-18")),
      fetch_end_date = as.Date(c(NA, "2026-06-22", "2026-06-22")),
      stringsAsFactors = FALSE
    ),
    cache_refresh_result = data.frame(
      symbol = c("SPY", "QQQ", "TSLA"),
      returned_bar_count = c(0L, 1L, 0L),
      merged_row_count = c(3L, 2L, 0L),
      no_returned_bars = c(FALSE, FALSE, TRUE),
      stringsAsFactors = FALSE
    )
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
  expect_equal(audit$refresh_fetch_symbol_count, 2L)
  expect_identical(audit$refresh_fetch_symbols, "QQQ,TSLA")
  expect_equal(audit$refresh_skip_symbol_count, 1L)
  expect_identical(audit$refresh_skip_symbols, "SPY")
  expect_match(audit$refresh_decisions_by_symbol, "SPY=fully_cached", fixed = TRUE)
  expect_match(audit$refresh_fetch_ranges_by_symbol, "QQQ=2026-06-20:2026-06-22", fixed = TRUE)
  expect_equal(audit$no_returned_bar_symbol_count, 1L)
  expect_identical(audit$no_returned_bar_symbols, "TSLA")
  expect_match(audit$returned_bar_counts_by_symbol, "QQQ=1", fixed = TRUE)
  expect_match(audit$merged_row_counts_by_symbol, "SPY=3", fixed = TRUE)
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
  expect_match(audit$availability_warnings, "no_returned_bars=TSLA", fixed = TRUE)

  artifact <- g5_audit_artifact(audit)
  expect_identical(names(artifact), g5_required_audit_columns())

  audit_csv <- tempfile("g5_audit_", fileext = ".csv")
  audit_csv_2 <- tempfile("g5_audit_", fileext = ".csv")
  g5_write_audit_artifact_csv(audit, audit_csv)
  g5_write_audit_artifact_csv(audit, audit_csv_2)
  audit_read <- utils::read.csv(audit_csv, stringsAsFactors = FALSE)
  expect_identical(names(audit_read), g5_required_audit_columns())
  expect_false("X" %in% names(audit_read))
  expect_identical(readLines(audit_csv), readLines(audit_csv_2))

  expect_error(
    g5_audit_artifact(audit[setdiff(names(audit), "provider_query_timestamp")]),
    "missing required columns: provider_query_timestamp"
  )
})

test_that("audit symbol summaries follow requested-symbol order", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "data_audit.R"))

  bars <- data.frame(
    symbol = c("SPY", "QQQ", "SPY", "IWM"),
    session_date = as.Date(c("2026-06-22", "2026-06-18", "2026-06-18", "2026-06-18")),
    open = c(100, 200, 99, 300),
    high = c(101, 201, 100, 301),
    low = c(99, 199, 98, 299),
    close = c(100.5, 200.5, 99.5, 300.5),
    volume = c(1000, 1200, 900, 1300),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = paste0("h", seq_len(4L)),
    stringsAsFactors = FALSE
  )

  audit <- g5_audit_bars(
    bars = bars,
    requested_symbols = c("QQQ", "SPY", "IWM", "EMPTY"),
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22")
  )

  expect_identical(audit$present_symbols, "QQQ,SPY,IWM")
  expect_identical(audit$row_counts_by_symbol, "QQQ=1;SPY=2;IWM=1")
  expect_identical(audit$stale_symbols, "QQQ,IWM")
  expect_identical(audit$partial_history_symbols, "QQQ,IWM")
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

test_that("symbol coverage artifact reports per-symbol availability statuses", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "data_audit.R"))

  bars <- data.frame(
    symbol = c("SPY", "SPY", "SPY", "QQQ", "QQQ", "IWM", "IWM"),
    session_date = as.Date(c(
      "2026-06-18", "2026-06-19", "2026-06-22",
      "2026-06-19", "2026-06-22",
      "2026-06-18", "2026-06-19"
    )),
    open = c(99, 100, 101, 200, 201, 300, 301),
    high = c(100, 101, 102, 202, 203, 302, 303),
    low = c(98, 99, 100, 199, 200, 299, 300),
    close = c(99.5, 100.5, 101.5, 201, 202, 301, 302),
    volume = c(900, 1000, 1100, 1400, 1500, 1600, 1700),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = paste0("h", seq_len(7L)),
    stringsAsFactors = FALSE
  )

  coverage <- g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = c("SPY", "QQQ", "IWM", "EMPTY"),
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-23"),
    cache_refresh_plan = data.frame(
      symbol = c("SPY", "QQQ", "IWM", "EMPTY"),
      cache_file_exists = c(TRUE, TRUE, TRUE, FALSE),
      needs_fetch = c(FALSE, TRUE, TRUE, TRUE),
      refresh_decision = c("fully_cached", "partial_history", "stale_cache", "cold_cache"),
      stringsAsFactors = FALSE
    ),
    cache_refresh_result = data.frame(
      symbol = c("SPY", "QQQ", "IWM", "EMPTY"),
      returned_bar_count = c(0L, 1L, 0L, 0L),
      merged_row_count = c(3L, 2L, 2L, 0L),
      no_returned_bars = c(FALSE, FALSE, TRUE, TRUE),
      wrote_cache = c(TRUE, TRUE, TRUE, FALSE),
      stringsAsFactors = FALSE
    )
  )

  expect_identical(coverage$symbol, c("SPY", "QQQ", "IWM", "EMPTY"))
  expect_identical(as.Date(coverage$coverage_end_date), rep(as.Date("2026-06-22"), 4L))
  expect_equal(coverage$row_count, c(3L, 2L, 2L, 0L))
  expect_identical(coverage$empty_status, c("has_rows", "has_rows", "has_rows", "empty"))
  expect_identical(
    coverage$partial_history_status,
    c("covers_requested_range", "partial_history", "partial_history", "empty")
  )
  expect_identical(coverage$stale_status, c("current", "current", "stale", "empty"))
  expect_identical(coverage$refresh_decision, c("fully_cached", "partial_history", "stale_cache", "cold_cache"))
  expect_equal(coverage$merged_row_count, c(3L, 2L, 2L, 0L))

  coverage_csv <- tempfile("g5_symbol_coverage_", fileext = ".csv")
  coverage_csv_2 <- tempfile("g5_symbol_coverage_", fileext = ".csv")
  g5_write_symbol_coverage_artifact_csv(coverage, coverage_csv)
  g5_write_symbol_coverage_artifact_csv(coverage, coverage_csv_2)
  coverage_read <- utils::read.csv(coverage_csv, stringsAsFactors = FALSE)
  expect_identical(names(coverage_read), names(coverage))
  expect_false("X" %in% names(coverage_read))
  expect_identical(readLines(coverage_csv), readLines(coverage_csv_2))

  expect_error(
    g5_write_symbol_coverage_artifact_csv(
      coverage[setdiff(names(coverage), "partial_history_status")],
      tempfile("g5_bad_symbol_coverage_", fileext = ".csv")
    ),
    "missing required columns: partial_history_status"
  )
})
