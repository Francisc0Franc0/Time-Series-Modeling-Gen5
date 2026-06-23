source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))

g5_test_wfa_bars <- function() {
  data.frame(
    symbol = c("AMD", "NVDA"),
    session_date = as.Date(c("2026-06-19", "2026-06-22")),
    open = c(50, 100),
    high = c(51, 102),
    low = c(49, 99),
    close = c(50.5, 101.5),
    volume = c(900, 1200),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = c("h1", "h2"),
    stringsAsFactors = FALSE
  )
}

g5_test_write_wfa_handoff <- function(
  bars = g5_test_wfa_bars(),
  health = NULL,
  manifest_updates = list(),
  audit_updates = list(),
  coverage_updates = list(),
  refresh_plan_updates = list(),
  include_merge_summary = FALSE
) {
  output_dir <- tempfile("g5_wfa_handoff_")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  audit <- g5_audit_bars(
    bars = bars,
    requested_symbols = c("AMD", "NVDA"),
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    provider_query_timestamp = "2026-06-22 17:00:00"
  )
  for (nm in names(audit_updates)) {
    audit[[nm]] <- audit_updates[[nm]]
  }

  coverage <- g5_symbol_coverage_artifact(
    bars = if (nrow(bars) == 0L) g5_empty_bar_data() else bars,
    requested_symbols = c("AMD", "NVDA"),
    latest_completed_session = as.Date("2026-06-22"),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22")
  )
  for (nm in names(coverage_updates)) {
    coverage[[nm]] <- coverage_updates[[nm]]
  }

  if (is.null(health)) {
    health <- data.frame(
      severity = "INFO",
      category = "row_count",
      symbol = "",
      detail = "query row count: 2",
      stringsAsFactors = FALSE
    )
  }

  refresh_plan <- data.frame(
    symbol = c("AMD", "NVDA"),
    cache_path = file.path(output_dir, c("AMD.rds", "NVDA.rds")),
    cache_file_exists = TRUE,
    cached_row_count = c(1L, 1L),
    first_cached_session = as.Date(c("2026-06-19", "2026-06-22")),
    latest_cached_session = as.Date(c("2026-06-19", "2026-06-22")),
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    needs_fetch = FALSE,
    refresh_decision = "fully_cached",
    fetch_start_date = as.Date(NA_character_),
    fetch_end_date = as.Date(NA_character_),
    stringsAsFactors = FALSE
  )
  for (nm in names(refresh_plan_updates)) {
    refresh_plan[[nm]] <- refresh_plan_updates[[nm]]
  }

  paths <- list(
    bars_csv = file.path(output_dir, "handoff_bars.csv"),
    audit_csv = file.path(output_dir, "handoff_audit.csv"),
    symbol_coverage_csv = file.path(output_dir, "handoff_symbol_coverage.csv"),
    health_csv = file.path(output_dir, "handoff_health.csv"),
    refresh_plan_csv = file.path(output_dir, "handoff_refresh_plan.csv"),
    manifest_csv = file.path(output_dir, "handoff_manifest.csv")
  )

  utils::write.csv(bars, paths$bars_csv, row.names = FALSE)
  utils::write.csv(audit, paths$audit_csv, row.names = FALSE)
  utils::write.csv(coverage, paths$symbol_coverage_csv, row.names = FALSE)
  utils::write.csv(health, paths$health_csv, row.names = FALSE)
  utils::write.csv(refresh_plan, paths$refresh_plan_csv, row.names = FALSE)

  manifest <- data.frame(
    wrapper = "g5_workbench_query_adjusted_daily_bars",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    resolution_reason = "after_close_same_day",
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    universe_name = "demo",
    universe_roles = "research_universe",
    requested_symbols = "AMD,NVDA",
    returned_symbols = "AMD,NVDA",
    cache_root = output_dir,
    provider = "alpaca",
    feed = "iex",
    refresh = FALSE,
    git_sha = "testsha",
    health_max_severity = g5_health_max_severity(health),
    bars_csv = normalizePath(paths$bars_csv, winslash = "/", mustWork = FALSE),
    audit_csv = normalizePath(paths$audit_csv, winslash = "/", mustWork = FALSE),
    symbol_coverage_csv = normalizePath(paths$symbol_coverage_csv, winslash = "/", mustWork = FALSE),
    health_csv = normalizePath(paths$health_csv, winslash = "/", mustWork = FALSE),
    refresh_plan_csv = normalizePath(paths$refresh_plan_csv, winslash = "/", mustWork = FALSE),
    stringsAsFactors = FALSE
  )

  if (isTRUE(include_merge_summary)) {
    paths$merge_summary_csv <- file.path(output_dir, "handoff_merge_summary.csv")
    merge_summary <- data.frame(
      symbol = c("AMD", "NVDA"),
      cache_path = file.path(output_dir, c("AMD.rds", "NVDA.rds")),
      refresh_decision = "fully_cached",
      needs_fetch = FALSE,
      returned_bar_count = 0L,
      merged_row_count = c(1L, 1L),
      first_merged_session = as.Date(c("2026-06-19", "2026-06-22")),
      latest_merged_session = as.Date(c("2026-06-19", "2026-06-22")),
      no_returned_bars = FALSE,
      wrote_cache = TRUE,
      stringsAsFactors = FALSE
    )
    utils::write.csv(merge_summary, paths$merge_summary_csv, row.names = FALSE)
    manifest$merge_summary_csv <- normalizePath(paths$merge_summary_csv, winslash = "/", mustWork = FALSE)
  }

  for (nm in names(manifest_updates)) {
    manifest[[nm]] <- manifest_updates[[nm]]
  }
  utils::write.csv(manifest, paths$manifest_csv, row.names = FALSE)

  list(output_dir = output_dir, paths = paths, manifest = manifest)
}

test_that("WFA handoff gate reads a complete manifest-linked handoff", {
  handoff <- g5_test_write_wfa_handoff(include_merge_summary = TRUE)

  result <- g5_read_wfa_handoff(handoff$paths$manifest_csv)

  expect_identical(result$gate_result$gate_status, "PASS")
  expect_false(result$gate_result$review_required)
  expect_equal(nrow(result$bars), 2L)
  expect_equal(nrow(result$merge_summary), 2L)
})

test_that("WFA handoff gate surfaces WARN health as review-required evidence", {
  health <- data.frame(
    severity = c("WARN", "INFO"),
    category = c("partial_history", "row_count"),
    symbol = c("AMD", ""),
    detail = c("observed bars do not cover the bounded requested range", "query row count: 2"),
    stringsAsFactors = FALSE
  )
  handoff <- g5_test_write_wfa_handoff(health = health)

  result <- g5_read_wfa_handoff(handoff$paths$manifest_csv)

  expect_identical(result$gate_result$gate_status, "REVIEW_REQUIRED")
  expect_true(result$gate_result$review_required)
  expect_equal(nrow(result$warn_health_rows), 1L)
  expect_identical(result$warn_health_rows$category, "partial_history")
})

test_that("WFA handoff gate fails loudly on missing artifacts and health errors", {
  missing_handoff <- g5_test_write_wfa_handoff()
  unlink(missing_handoff$paths$health_csv)
  expect_error(
    g5_read_wfa_handoff(missing_handoff$paths$manifest_csv),
    "Missing required handoff artifact"
  )

  error_health <- data.frame(
    severity = "ERROR",
    category = "future_rows",
    symbol = "",
    detail = "rows after latest_completed_session: 1",
    stringsAsFactors = FALSE
  )
  error_handoff <- g5_test_write_wfa_handoff(health = error_health)
  expect_error(
    g5_read_wfa_handoff(error_handoff$paths$manifest_csv),
    "health_max_severity == 'ERROR'|ERROR health rows"
  )
})

test_that("WFA handoff gate enforces canonical Alpaca adjusted daily bars", {
  provider_bars <- g5_test_wfa_bars()
  provider_bars$provider <- "other"
  provider_handoff <- g5_test_write_wfa_handoff(
    bars = provider_bars,
    manifest_updates = list(provider = "alpaca")
  )
  expect_error(
    g5_read_wfa_handoff(provider_handoff$paths$manifest_csv),
    "provider == 'alpaca'"
  )

  missing_col_handoff <- g5_test_write_wfa_handoff()
  bad_bars <- g5_test_wfa_bars()
  bad_bars$data_version_hash <- NULL
  utils::write.csv(bad_bars, missing_col_handoff$paths$bars_csv, row.names = FALSE)
  expect_error(
    g5_read_wfa_handoff(missing_col_handoff$paths$manifest_csv),
    "missing required columns"
  )
})

test_that("WFA handoff gate rejects duplicate and future bar rows", {
  duplicate_handoff <- g5_test_write_wfa_handoff(
    audit_updates = list(duplicate_symbol_session_count = 1L)
  )
  duplicate_bars <- rbind(g5_test_wfa_bars(), g5_test_wfa_bars()[1L, , drop = FALSE])
  utils::write.csv(duplicate_bars, duplicate_handoff$paths$bars_csv, row.names = FALSE)
  expect_error(
    g5_read_wfa_handoff(duplicate_handoff$paths$manifest_csv),
    "Duplicate symbol/session_date|duplicate symbol/session_date"
  )

  future_handoff <- g5_test_write_wfa_handoff()
  future_bars <- g5_test_wfa_bars()
  future_bars$session_date[[2L]] <- as.Date("2026-06-23")
  utils::write.csv(future_bars, future_handoff$paths$bars_csv, row.names = FALSE)
  expect_error(
    g5_read_wfa_handoff(future_handoff$paths$manifest_csv),
    "rows after latest_completed_session"
  )
})

test_that("WFA handoff gate checks as-of and latest-session consistency", {
  bars_asof_handoff <- g5_test_write_wfa_handoff()
  mismatched_bars <- g5_test_wfa_bars()
  mismatched_bars$as_of_timestamp[[1L]] <- "2026-06-22 18:00:00"
  utils::write.csv(mismatched_bars, bars_asof_handoff$paths$bars_csv, row.names = FALSE)
  expect_error(
    g5_read_wfa_handoff(bars_asof_handoff$paths$manifest_csv),
    "bars as_of_timestamp"
  )

  audit_asof_handoff <- g5_test_write_wfa_handoff(
    audit_updates = list(provider_query_timestamp = "2026-06-22 18:00:00")
  )
  expect_error(
    g5_read_wfa_handoff(audit_asof_handoff$paths$manifest_csv),
    "audit provider_query_timestamp"
  )

  coverage_latest_handoff <- g5_test_write_wfa_handoff(
    coverage_updates = list(latest_completed_session = as.Date("2026-06-19"))
  )
  expect_error(
    g5_read_wfa_handoff(coverage_latest_handoff$paths$manifest_csv),
    "symbol coverage latest_completed_session"
  )
})
