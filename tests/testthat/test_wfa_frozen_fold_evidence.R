source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))
source(test_path("..", "..", "R", "wfa_fold_geometry.R"))
source(test_path("..", "..", "R", "wfa_train_oos_split_audit.R"))
source(test_path("..", "..", "R", "wfa_frozen_fold_evidence.R"))

g5_test_evidence_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_evidence_gate_result <- function(
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

g5_test_evidence_bars <- function() {
  g5_validate_bar_data(data.frame(
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
  ))
}

g5_test_evidence_coverage <- function(bars) {
  g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = c("SPY", "QQQ", "STALE", "EMPTY"),
    latest_completed_session = as.Date("2026-04-03"),
    requested_start_date = as.Date("2025-12-29"),
    requested_end_date = as.Date("2026-04-03")
  )
}

g5_test_evidence_health <- function() {
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

g5_test_evidence_split_audit <- function(
  gate_result = g5_test_evidence_gate_result(),
  accept_review_required = FALSE
) {
  bars <- g5_test_evidence_bars()
  folds <- g5_build_quarterly_fold_geometry(
    gate_result = gate_result,
    train_start_date = as.Date("2025-12-29"),
    first_oos_start_date = as.Date("2026-01-01"),
    final_oos_end_date = as.Date("2026-04-03"),
    accept_review_required = accept_review_required
  )
  audit <- g5_build_wfa_train_oos_split_audit(
    gate_result = gate_result,
    bars = bars,
    fold_geometry = folds,
    source_symbol_coverage = g5_test_evidence_coverage(bars),
    source_health = g5_test_evidence_health(),
    accept_review_required = accept_review_required
  )
  list(folds = folds, audit = audit)
}

test_that("frozen fold evidence records source fold and no active decision", {
  gate_result <- g5_test_evidence_gate_result()
  fixture <- g5_test_evidence_split_audit(gate_result)

  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    code_metadata = g5_test_evidence_code_metadata()
  )

  expect_equal(nrow(evidence), 2L)
  expect_identical(names(evidence), g5_wfa_required_frozen_evidence_columns())
  expect_identical(evidence$evidence_status, rep("FROZEN_NO_ACTIVE_DECISION", 2L))
  expect_identical(evidence$fold_id, fixture$folds$fold_id)
  expect_identical(evidence$source_handoff_reference, fixture$folds$source_handoff_reference)
  expect_identical(evidence$handoff_gate_status, rep("PASS", 2L))
  expect_false(any(evidence$handoff_review_required))
  expect_false(any(evidence$handoff_review_accepted))
  expect_identical(evidence$train_row_count, fixture$audit$split_summary$train_row_count)
  expect_true(all(evidence$train_rows_available))
  expect_true(all(evidence$source_warning_count == 3L))
  expect_true(all(grepl("operator accepted source warning context", evidence$source_warning_context, fixed = TRUE)))
  expect_true(all(evidence$leakage_no_provider_calls))
  expect_true(all(evidence$leakage_no_latest_session_inference))
  expect_true(all(evidence$leakage_no_oos_membership_decisions))
  expect_true(all(evidence$leakage_no_oos_fitting))
  expect_false(any(evidence$oos_performance_evaluated))
  expect_true(all(is.na(evidence$active_candidate_id)))
  expect_identical(
    unique(evidence$strategy_decision_status),
    "no_active_strategy_decision_yet"
  )
})

test_that("frozen fold evidence requires explicit review acceptance", {
  review_gate <- g5_test_evidence_gate_result(
    gate_status = "REVIEW_REQUIRED",
    review_required = TRUE
  )
  fixture <- g5_test_evidence_split_audit(
    gate_result = review_gate,
    accept_review_required = TRUE
  )

  expect_error(
    g5_build_wfa_frozen_fold_evidence(
      gate_result = review_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      code_metadata = g5_test_evidence_code_metadata()
    ),
    "accept_review_required"
  )

  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = review_gate,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    accept_review_required = TRUE,
    code_metadata = g5_test_evidence_code_metadata()
  )

  expect_true(all(evidence$handoff_review_required))
  expect_true(all(evidence$handoff_review_accepted))
  expect_identical(evidence$handoff_gate_status, rep("REVIEW_REQUIRED", 2L))
})

test_that("frozen fold evidence rejects leakage-tainted split audit", {
  gate_result <- g5_test_evidence_gate_result()
  fixture <- g5_test_evidence_split_audit(gate_result)
  fixture$audit$leakage_attestation$latest_session_inferred <- TRUE

  expect_error(
    g5_build_wfa_frozen_fold_evidence(
      gate_result = gate_result,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      code_metadata = g5_test_evidence_code_metadata()
    ),
    "inferred latest sessions"
  )
})

test_that("frozen fold evidence writer defaults to ignored run paths", {
  gate_result <- g5_test_evidence_gate_result()
  fixture <- g5_test_evidence_split_audit(gate_result)
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    code_metadata = g5_test_evidence_code_metadata()
  )

  temp_csv <- tempfile("frozen_evidence_", fileext = ".csv")
  expect_error(
    g5_write_wfa_frozen_fold_evidence_csv(evidence, temp_csv),
    "ignored runs"
  )

  run_csv <- file.path("runs", "wfa_foundation_test", "frozen_fold_evidence.csv")
  written <- g5_write_wfa_frozen_fold_evidence_csv(evidence, run_csv)
  expect_true(file.exists(written))
  read_back <- utils::read.csv(written, stringsAsFactors = FALSE, check.names = FALSE)
  expect_identical(names(read_back), names(evidence))
})
