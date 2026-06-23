source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))
source(test_path("..", "..", "R", "wfa_fold_geometry.R"))

g5_test_wfa_gate_result <- function(
  gate_status = "PASS",
  review_required = FALSE,
  latest_completed_session = as.Date("2026-06-22")
) {
  g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = "runs/research_workbench/demo/handoff_manifest.csv",
    as_of_timestamp = "2026-06-22 17:00:00",
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

test_that("quarterly fold geometry builds explicit expanding TRAIN and quarterly OOS records", {
  folds <- g5_build_quarterly_fold_geometry(
    gate_result = g5_test_wfa_gate_result(),
    train_start_date = as.Date("2025-01-01"),
    first_oos_start_date = as.Date("2026-01-01"),
    final_oos_end_date = as.Date("2026-06-22")
  )

  expect_equal(nrow(folds), 2L)
  expect_identical(folds$fold_id, c("fold_0001", "fold_0002"))
  expect_equal(folds$train_start_date, as.Date(c("2025-01-01", "2025-01-01")))
  expect_equal(folds$train_end_date, as.Date(c("2025-12-31", "2026-03-31")))
  expect_equal(folds$oos_start_date, as.Date(c("2026-01-01", "2026-04-01")))
  expect_equal(folds$oos_end_date, as.Date(c("2026-03-31", "2026-06-22")))
  expect_identical(unique(folds$decision_cadence), "quarterly")
  expect_equal(folds$decision_pack_valid_from, folds$oos_start_date)
  expect_equal(folds$decision_pack_valid_through, folds$oos_end_date)
  expect_identical(unique(folds$gap_policy), "no_gap_train_ends_day_before_oos")
  expect_true(all(folds$train_end_date < folds$oos_start_date))
  expect_true(all(folds$oos_end_date <= folds$latest_completed_session))
  expect_identical(
    unique(folds$geometry_search_policy),
    "none_single_explicit_quarterly_geometry"
  )
  expect_identical(
    unique(folds$source_handoff_reference),
    normalizePath("runs/research_workbench/demo/handoff_manifest.csv", winslash = "/", mustWork = FALSE)
  )
})

test_that("quarterly fold geometry records intentional TRAIN/OOS gap policy", {
  folds <- g5_build_quarterly_fold_geometry(
    gate_result = g5_test_wfa_gate_result(),
    train_start_date = as.Date("2025-01-01"),
    first_oos_start_date = as.Date("2026-04-01"),
    final_oos_end_date = as.Date("2026-06-22"),
    gap_days = 2L,
    source_handoff_reference = "accepted_handoff_001"
  )

  expect_equal(nrow(folds), 1L)
  expect_equal(folds$train_end_date, as.Date("2026-03-29"))
  expect_equal(folds$gap_start_date, as.Date("2026-03-30"))
  expect_equal(folds$gap_end_date, as.Date("2026-03-31"))
  expect_identical(folds$gap_policy, "intentional_2_calendar_day_gap_between_train_and_oos")
  expect_identical(folds$source_handoff_reference, "accepted_handoff_001")
})

test_that("quarterly fold geometry requires explicit acceptance for review-required handoffs", {
  gate_result <- g5_test_wfa_gate_result(
    gate_status = "REVIEW_REQUIRED",
    review_required = TRUE
  )

  expect_error(
    g5_build_quarterly_fold_geometry(
      gate_result = gate_result,
      train_start_date = as.Date("2025-01-01"),
      first_oos_start_date = as.Date("2026-01-01"),
      final_oos_end_date = as.Date("2026-03-31")
    ),
    "accept_review_required"
  )

  folds <- g5_build_quarterly_fold_geometry(
    gate_result = gate_result,
    train_start_date = as.Date("2025-01-01"),
    first_oos_start_date = as.Date("2026-01-01"),
    final_oos_end_date = as.Date("2026-03-31"),
    accept_review_required = TRUE
  )

  expect_identical(folds$handoff_gate_status, "REVIEW_REQUIRED")
  expect_true(folds$handoff_review_required)
  expect_true(folds$handoff_review_accepted)
})

test_that("quarterly fold geometry fails on ambiguous or invalid date windows", {
  gate_result <- g5_test_wfa_gate_result()

  expect_error(
    g5_build_quarterly_fold_geometry(
      gate_result = gate_result,
      train_start_date = as.Date("2025-01-01"),
      first_oos_start_date = as.Date("2026-02-01"),
      final_oos_end_date = as.Date("2026-06-22")
    ),
    "first day of a calendar quarter"
  )

  expect_error(
    g5_build_quarterly_fold_geometry(
      gate_result = gate_result,
      train_start_date = as.Date("2025-01-01"),
      first_oos_start_date = as.Date("2026-04-01"),
      final_oos_end_date = as.Date("2026-06-23")
    ),
    "bounded by latest_completed_session"
  )

  expect_error(
    g5_build_quarterly_fold_geometry(
      gate_result = gate_result,
      train_start_date = as.Date("2026-01-01"),
      first_oos_start_date = as.Date("2026-01-01"),
      final_oos_end_date = as.Date("2026-03-31")
    ),
    "valid TRAIN window"
  )

  bad_gate <- g5_test_wfa_gate_result(gate_status = "FAIL")
  expect_error(
    g5_build_quarterly_fold_geometry(
      gate_result = bad_gate,
      train_start_date = as.Date("2025-01-01"),
      first_oos_start_date = as.Date("2026-01-01"),
      final_oos_end_date = as.Date("2026-03-31")
    ),
    "accepted PASS or REVIEW_REQUIRED"
  )
})
