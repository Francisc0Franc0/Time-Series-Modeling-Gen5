test_that("symbol data proof writes a tidy ignored output packet", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "cache_store.R"))
  source(test_path("..", "..", "R", "data_audit.R"))
  source(test_path("..", "..", "R", "workbench_query.R"))
  source(test_path("..", "..", "R", "workbench_chart.R"))
  source(test_path("..", "..", "R", "workbench_data_proof.R"))

  bars <- data.frame(
    symbol = c("AMD", "AMD", "AMD"),
    session_date = as.Date(c("2026-06-18", "2026-06-19", "2026-06-22")),
    open = c(100, 102, 101),
    high = c(103, 104, 102),
    low = c(99, 100, 98),
    close = c(102, 101, 99),
    volume = c(1000, 1100, 1200),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = paste0("h", seq_len(3L)),
    stringsAsFactors = FALSE
  )
  date_range <- list(
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22")
  )
  audit <- g5_audit_bars(
    bars = bars,
    requested_symbols = "AMD",
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    provider_query_timestamp = "2026-06-22 17:00:00"
  )
  coverage <- g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = "AMD",
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22")
  )
  health <- g5_data_health_report(
    bars = bars,
    audit = audit,
    symbol_coverage = coverage,
    date_range = date_range,
    refresh_plan = data.frame()
  )
  refresh_plan <- data.frame(
    symbol = "AMD",
    cache_path = file.path(tempdir(), "AMD.rds"),
    cache_file_exists = TRUE,
    cached_row_count = 3L,
    first_cached_session = as.Date("2026-06-18"),
    latest_cached_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    needs_fetch = FALSE,
    refresh_decision = "fully_cached",
    fetch_start_date = as.Date(NA),
    fetch_end_date = as.Date(NA),
    stringsAsFactors = FALSE
  )
  result <- list(
    bars = bars,
    manifest = data.frame(refresh = FALSE, stringsAsFactors = FALSE),
    audit = audit,
    symbol_coverage = coverage,
    health = health,
    refresh_plan = refresh_plan,
    merge_summary = data.frame(),
    date_range = date_range,
    resolved_session = list(
      as_of_timestamp = as.POSIXct("2026-06-22 17:00:00", tz = "America/New_York"),
      latest_completed_session = as.Date("2026-06-22"),
      resolution_reason = "after_market_close"
    )
  )

  output_dir <- file.path(tempdir(), "runs", "research_workbench", "data_proofs", "demo")
  written <- g5_write_symbol_data_proof_outputs(result, symbol = "AMD", output_dir = output_dir)

  expect_true(file.exists(written$paths$candlestick_png))
  expect_true(file.exists(written$paths$summary_csv))
  expect_true(file.exists(written$paths$summary_md))
  expect_true(file.exists(written$paths$bars_csv))
  expect_equal(written$summary$symbol, "AMD")
  expect_equal(written$summary$row_count, 3L)
  expect_equal(as.Date(written$summary$observed_start_date), as.Date("2026-06-18"))
  expect_equal(as.Date(written$summary$observed_end_date), as.Date("2026-06-22"))
  expect_true(grepl("/runs/research_workbench/data_proofs/", normalizePath(output_dir, winslash = "/", mustWork = FALSE), fixed = TRUE))
})

test_that("multi-symbol report writes combined chart and summary rows", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "cache_store.R"))
  source(test_path("..", "..", "R", "data_audit.R"))
  source(test_path("..", "..", "R", "workbench_query.R"))
  source(test_path("..", "..", "R", "workbench_chart.R"))
  source(test_path("..", "..", "R", "workbench_data_proof.R"))

  bars <- data.frame(
    symbol = c("NVDA", "NVDA", "AMD", "AMD"),
    session_date = as.Date(c("2026-06-18", "2026-06-19", "2026-06-18", "2026-06-19")),
    open = c(100, 102, 50, 51),
    high = c(103, 104, 52, 53),
    low = c(99, 100, 49, 50),
    close = c(102, 101, 51, 52),
    volume = c(1000, 1100, 900, 950),
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
  date_range <- list(
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22")
  )
  audit <- g5_audit_bars(
    bars = bars,
    requested_symbols = c("NVDA", "AMD"),
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    provider_query_timestamp = "2026-06-22 17:00:00"
  )
  coverage <- g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = c("NVDA", "AMD"),
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22")
  )
  health <- g5_data_health_report(
    bars = bars,
    audit = audit,
    symbol_coverage = coverage,
    date_range = date_range,
    refresh_plan = data.frame()
  )
  refresh_plan <- data.frame(
    symbol = c("NVDA", "AMD"),
    cache_path = file.path(tempdir(), c("NVDA.rds", "AMD.rds")),
    cache_file_exists = TRUE,
    cached_row_count = c(2L, 2L),
    first_cached_session = as.Date(c("2026-06-18", "2026-06-18")),
    latest_cached_session = as.Date(c("2026-06-19", "2026-06-19")),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    needs_fetch = FALSE,
    refresh_decision = "fully_cached",
    fetch_start_date = as.Date(NA),
    fetch_end_date = as.Date(NA),
    stringsAsFactors = FALSE
  )
  result <- list(
    bars = bars,
    manifest = data.frame(refresh = FALSE, stringsAsFactors = FALSE),
    audit = audit,
    symbol_coverage = coverage,
    health = health,
    refresh_plan = refresh_plan,
    merge_summary = data.frame(),
    date_range = date_range,
    resolved_session = list(
      as_of_timestamp = as.POSIXct("2026-06-22 17:00:00", tz = "America/New_York"),
      latest_completed_session = as.Date("2026-06-22"),
      resolution_reason = "after_market_close"
    )
  )

  output_dir <- file.path(tempdir(), "runs", "research_workbench", "multi_symbol_reports", "demo")
  written <- g5_write_multi_symbol_report_outputs(
    result,
    symbols = c("NVDA", "AMD"),
    output_dir = output_dir
  )

  expect_true(file.exists(written$paths$multi_panel_png))
  expect_true(file.exists(written$paths$summary_csv))
  expect_true(file.exists(written$paths$summary_md))
  expect_equal(nrow(written$summary), 2L)
  expect_setequal(written$chart_symbols, c("AMD", "NVDA"))
  expect_true(all(written$summary$row_count == 2L))
})

test_that("data proof emits friendly error when requested symbol has no chartable bars", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "workbench_data_proof.R"))

  result <- list(bars = g5_empty_bar_data())
  expect_error(
    g5_require_chartable_symbol(result, symbol = "AMD", refresh = FALSE),
    "Run again with -Refresh"
  )
})

test_that("symbol data proof helpers create deterministic prefixes", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "workbench_data_proof.R"))

  expect_identical(
    g5_data_proof_artifact_prefix("2026-06-22 17:00:00", "amd"),
    "data_proof_AMD_2026_06_22_17_00_00"
  )
  out <- g5_data_proof_output_dir("repo", "2026-06-22 17:00:00", "AMD")
  expect_true(grepl("runs", out, fixed = TRUE))
  expect_true(grepl("data_proofs", out, fixed = TRUE))
})
