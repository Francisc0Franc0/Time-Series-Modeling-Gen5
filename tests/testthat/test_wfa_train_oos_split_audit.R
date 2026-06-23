source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))
source(test_path("..", "..", "R", "wfa_fold_geometry.R"))
source(test_path("..", "..", "R", "wfa_train_oos_split_audit.R"))

g5_test_split_gate_result <- function(
  gate_status = "PASS",
  review_required = FALSE,
  latest_completed_session = as.Date("2026-04-03")
) {
  g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = "runs/research_workbench/demo/handoff_manifest.csv",
    as_of_timestamp = "2026-04-03 17:00:00",
    latest_completed_session = latest_completed_session,
    health_max_severity = if (isTRUE(review_required)) "WARN" else "INFO",
    warn_row_count = if (isTRUE(review_required)) 1L else 0L,
    review_required = review_required,
    detail = if (isTRUE(review_required)) {
      "WARN health rows require operator review: 1"
    } else {
      "handoff passed WFA gate"
    }
  )
}

g5_test_split_bars <- function(extra_outcome = FALSE) {
  rows <- data.frame(
    symbol = c(
      rep("SPY", 9L),
      rep("QQQ", 5L),
      rep("STALE", 2L)
    ),
    session_date = as.Date(c(
      "2025-12-29", "2025-12-30", "2025-12-31",
      "2026-01-02", "2026-02-02", "2026-03-31",
      "2026-04-01", "2026-04-02", "2026-04-03",
      "2026-01-02", "2026-02-02", "2026-03-31",
      "2026-04-01", "2026-04-03",
      "2025-12-29", "2026-01-02"
    )),
    open = seq(100, 115),
    high = seq(101, 116),
    low = seq(99, 114),
    close = seq(100.5, 115.5),
    volume = seq(1000, 1015),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-04-03 17:00:00",
    latest_completed_session = as.Date("2026-04-03"),
    fetch_start_date = as.Date("2025-12-29"),
    fetch_end_date = as.Date("2026-04-03"),
    data_version_hash = paste0("hash_", seq_len(16L)),
    stringsAsFactors = FALSE
  )
  if (isTRUE(extra_outcome)) {
    rows$fake_oos_return_that_must_not_drive_membership <- rev(seq_len(nrow(rows)))
  }
  g5_validate_bar_data(rows)
}

g5_test_split_coverage <- function(bars) {
  g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = c("SPY", "QQQ", "STALE", "EMPTY"),
    latest_completed_session = as.Date("2026-04-03"),
    requested_start_date = as.Date("2025-12-29"),
    requested_end_date = as.Date("2026-04-03")
  )
}

g5_test_split_health <- function() {
  data.frame(
    severity = c("WARN", "WARN", "INFO", "WARN"),
    category = c("partial_history", "empty_symbol", "row_count", "source_handoff_warning"),
    symbol = c("STALE", "EMPTY", "", ""),
    detail = c(
      "STALE observed bars do not cover requested range",
      "EMPTY has no rows in source handoff",
      "query row count: 16",
      "operator accepted source warning context"
    ),
    stringsAsFactors = FALSE
  )
}

g5_test_split_folds <- function(gate_result = g5_test_split_gate_result(), accept_review_required = FALSE) {
  g5_build_quarterly_fold_geometry(
    gate_result = gate_result,
    train_start_date = as.Date("2025-12-29"),
    first_oos_start_date = as.Date("2026-01-01"),
    final_oos_end_date = as.Date("2026-04-03"),
    accept_review_required = accept_review_required
  )
}

test_that("TRAIN/OOS split audit partitions rows by fold dates only", {
  gate_result <- g5_test_split_gate_result()
  bars <- g5_test_split_bars()
  folds <- g5_test_split_folds(gate_result)
  audit <- g5_build_wfa_train_oos_split_audit(
    gate_result = gate_result,
    bars = bars,
    fold_geometry = folds,
    source_symbol_coverage = g5_test_split_coverage(bars),
    source_health = g5_test_split_health()
  )

  expect_equal(nrow(audit$split_summary), 2L)
  expect_true(all(audit$split_summary$train_oos_disjoint))
  expect_true(all(audit$split_summary$oos_after_train))
  expect_true(all(audit$split_summary$oos_bounded_by_latest_completed_session))
  expect_false(any(audit$split_summary$outcome_columns_used_for_membership))
  expect_identical(
    unique(audit$train_rows$split_membership_rule),
    "fold_dates_only_no_outcome_columns_read"
  )
  expect_true(all(audit$oos_rows$session_date <= as.Date("2026-04-03")))

  fold1_train <- audit$train_rows[audit$train_rows$fold_id == "fold_0001", , drop = FALSE]
  fold1_oos <- audit$oos_rows[audit$oos_rows$fold_id == "fold_0001", , drop = FALSE]
  expect_true(all(fold1_train$session_date <= as.Date("2025-12-31")))
  expect_true(all(fold1_oos$session_date >= as.Date("2026-01-01")))
  expect_equal(nrow(fold1_train), 4L)
  expect_equal(nrow(fold1_oos), 7L)

  expect_false(audit$leakage_attestation$provider_calls_used)
  expect_false(audit$leakage_attestation$latest_session_inferred)
  expect_false(audit$leakage_attestation$membership_decided_from_oos_outcomes)
})

test_that("fold-local availability preserves missing partial stale and warning context", {
  gate_result <- g5_test_split_gate_result()
  bars <- g5_test_split_bars()
  audit <- g5_build_wfa_train_oos_split_audit(
    gate_result = gate_result,
    bars = bars,
    fold_geometry = g5_test_split_folds(gate_result),
    source_symbol_coverage = g5_test_split_coverage(bars),
    source_health = g5_test_split_health()
  )

  availability <- audit$symbol_availability
  expect_equal(nrow(availability), 8L)
  expect_setequal(unique(availability$symbol), c("SPY", "QQQ", "STALE", "EMPTY"))

  empty_rows <- availability[availability$symbol == "EMPTY", , drop = FALSE]
  expect_true(all(empty_rows$source_empty_status == "empty"))
  expect_true(all(empty_rows$fold_availability_status == "no_fold_rows_recorded"))
  expect_true(all(grepl("EMPTY has no rows", empty_rows$source_symbol_warning_context, fixed = TRUE)))

  stale_rows <- availability[availability$symbol == "STALE", , drop = FALSE]
  expect_true(all(stale_rows$source_partial_history_status == "partial_history"))
  expect_true(all(stale_rows$source_stale_status == "stale"))
  expect_true(all(grepl("STALE observed bars", stale_rows$source_symbol_warning_context, fixed = TRUE)))

  expect_true(all(grepl(
    "operator accepted source warning context",
    availability$source_handoff_warning_context,
    fixed = TRUE
  )))
  expect_identical(
    unique(availability$availability_rule),
    "fold_dates_and_source_handoff_health_only_no_oos_performance_filter"
  )
  expect_equal(nrow(audit$source_warn_health_rows), 3L)
})

test_that("fake OOS outcome-like columns do not affect fold membership", {
  gate_result <- g5_test_split_gate_result()
  bars <- g5_test_split_bars()
  bars_with_outcome <- g5_test_split_bars(extra_outcome = TRUE)
  folds <- g5_test_split_folds(gate_result)
  coverage <- g5_test_split_coverage(bars)
  health <- g5_test_split_health()

  base_audit <- g5_build_wfa_train_oos_split_audit(
    gate_result = gate_result,
    bars = bars,
    fold_geometry = folds,
    source_symbol_coverage = coverage,
    source_health = health
  )
  outcome_audit <- g5_build_wfa_train_oos_split_audit(
    gate_result = gate_result,
    bars = bars_with_outcome,
    fold_geometry = folds,
    source_symbol_coverage = coverage,
    source_health = health
  )

  base_train_keys <- paste(base_audit$train_rows$fold_id, base_audit$train_rows$symbol, base_audit$train_rows$session_date)
  outcome_train_keys <- paste(
    outcome_audit$train_rows$fold_id,
    outcome_audit$train_rows$symbol,
    outcome_audit$train_rows$session_date
  )
  base_oos_keys <- paste(base_audit$oos_rows$fold_id, base_audit$oos_rows$symbol, base_audit$oos_rows$session_date)
  outcome_oos_keys <- paste(
    outcome_audit$oos_rows$fold_id,
    outcome_audit$oos_rows$symbol,
    outcome_audit$oos_rows$session_date
  )

  expect_identical(base_train_keys, outcome_train_keys)
  expect_identical(base_oos_keys, outcome_oos_keys)
  expect_identical(base_audit$split_summary$train_row_count, outcome_audit$split_summary$train_row_count)
  expect_identical(base_audit$split_summary$oos_row_count, outcome_audit$split_summary$oos_row_count)
})

test_that("TRAIN/OOS split audit rejects unaccepted review gates and invalid fold bounds", {
  review_gate <- g5_test_split_gate_result(
    gate_status = "REVIEW_REQUIRED",
    review_required = TRUE
  )
  bars <- g5_test_split_bars()
  accepted_review_folds <- g5_test_split_folds(
    gate_result = review_gate,
    accept_review_required = TRUE
  )

  expect_error(
    g5_build_wfa_train_oos_split_audit(
      gate_result = review_gate,
      bars = bars,
      fold_geometry = accepted_review_folds,
      source_symbol_coverage = g5_test_split_coverage(bars),
      source_health = g5_test_split_health()
    ),
    "accept_review_required"
  )

  bad_folds <- g5_test_split_folds(g5_test_split_gate_result())
  bad_folds$oos_end_date[[1L]] <- as.Date("2026-04-04")
  expect_error(
    g5_build_wfa_train_oos_split_audit(
      gate_result = g5_test_split_gate_result(),
      bars = bars,
      fold_geometry = bad_folds,
      source_symbol_coverage = g5_test_split_coverage(bars),
      source_health = g5_test_split_health()
    ),
    "bounded by latest_completed_session"
  )
})
