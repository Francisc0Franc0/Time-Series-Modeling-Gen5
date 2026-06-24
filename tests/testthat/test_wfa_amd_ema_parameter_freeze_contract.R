source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))
source(test_path("..", "..", "R", "wfa_fold_geometry.R"))
source(test_path("..", "..", "R", "wfa_train_oos_split_audit.R"))
source(test_path("..", "..", "R", "wfa_frozen_fold_evidence.R"))
source(test_path("..", "..", "R", "wfa_baseline_registry.R"))
source(test_path("..", "..", "R", "wfa_baseline_evaluation_contract.R"))
source(test_path("..", "..", "R", "wfa_minimal_poc_manifest.R"))
source(test_path("..", "..", "R", "wfa_amd_ema_evaluation_gate.R"))
source(test_path("..", "..", "R", "wfa_amd_ema_evaluation_contract.R"))
source(test_path("..", "..", "R", "wfa_amd_ema_parameter_freeze_contract.R"))

g5_test_amd_ema_freeze_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_freeze_gate_result <- function(
  gate_status = "PASS",
  review_required = FALSE
) {
  g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = "runs/research_workbench/amd_ema_parameter_freeze/handoff_manifest.csv",
    as_of_timestamp = "2026-04-03 17:00:00",
    latest_completed_session = as.Date("2026-04-03"),
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

g5_test_amd_ema_freeze_bars <- function() {
  g5_validate_bar_data(data.frame(
    symbol = c(
      rep("AMD", 9L),
      rep("SPY", 5L),
      rep("QQQ", 2L)
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

g5_test_amd_ema_freeze_health <- function(include_warn = FALSE) {
  if (!isTRUE(include_warn)) {
    return(data.frame(
      severity = "INFO",
      category = "row_count",
      symbol = "",
      detail = "query row count: 16",
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    severity = c("WARN", "INFO"),
    category = c("partial_history", "row_count"),
    symbol = c("AMD", ""),
    detail = c(
      "AMD has partial history in source handoff",
      "query row count: 16"
    ),
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_freeze_fixture <- function(
  gate_result = g5_test_amd_ema_freeze_gate_result(),
  accept_review_required = FALSE,
  source_health = g5_test_amd_ema_freeze_health()
) {
  bars <- g5_test_amd_ema_freeze_bars()
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
    source_symbol_coverage = g5_symbol_coverage_artifact(
      bars = bars,
      requested_symbols = c("AMD", "SPY", "QQQ"),
      latest_completed_session = as.Date("2026-04-03"),
      requested_start_date = as.Date("2025-12-29"),
      requested_end_date = as.Date("2026-04-03")
    ),
    source_health = source_health,
    accept_review_required = accept_review_required
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    accept_review_required = accept_review_required,
    code_metadata = g5_test_amd_ema_freeze_code_metadata()
  )
  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence,
    accept_review_required = accept_review_required
  )
  baseline_contract <- g5_build_wfa_baseline_evaluation_contract_scaffold(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence,
    baseline_registry = registry,
    accept_review_required = accept_review_required
  )
  minimal_poc <- g5_validate_wfa_minimal_poc_scaffold(g5_build_wfa_minimal_poc_scaffold(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    frozen_fold_evidence = evidence,
    baseline_registry = registry,
    baseline_evaluation_contract = baseline_contract,
    accept_review_required = accept_review_required
  ))
  closeout <- g5_build_wfa_minimal_poc_closeout_validation(minimal_poc)
  baseline_readiness <- g5_build_wfa_baseline_evaluation_contract_readiness_review(baseline_contract)
  amd_gate <- g5_build_wfa_amd_ema_evaluation_gate(
    minimal_poc_closeout = closeout,
    baseline_readiness_review = baseline_readiness,
    operator_accepts_readiness_evidence = TRUE
  )
  eval_contract <- g5_build_wfa_amd_ema_evaluation_contract_scaffold(
    amd_ema_gate = amd_gate,
    fold_geometry = folds,
    split_audit = audit,
    frozen_fold_evidence = evidence,
    baseline_evaluation_contract = baseline_contract,
    accept_review_required = accept_review_required
  )
  eval_readiness <- g5_build_wfa_amd_ema_evaluation_contract_readiness_review(eval_contract)
  list(
    evaluation_contract = eval_contract,
    evaluation_readiness = eval_readiness
  )
}

g5_test_amd_ema_freeze_parameter_decisions <- function(evaluation_contract) {
  amd_rows <- evaluation_contract$review_surface[
    evaluation_contract$review_surface$subject_id == "amd_ema_long_cash",
    ,
    drop = FALSE
  ]
  data.frame(
    fold_id = as.character(amd_rows$fold_id),
    fast_ema_period = rep(10L, nrow(amd_rows)),
    slow_ema_period = rep(30L, nrow(amd_rows)),
    parameter_source = rep("operator_accepted_train_only_amd_ema_review", nrow(amd_rows)),
    selection_authority_status = rep(
      "train_only_operator_accepted_no_oos_outcome_authority",
      nrow(amd_rows)
    ),
    stringsAsFactors = FALSE
  )
}

test_that("AMD EMA parameter freeze consumes accepted evaluation readiness and freezes train-only periods", {
  fixture <- g5_test_amd_ema_freeze_fixture()
  parameter_decisions <- g5_test_amd_ema_freeze_parameter_decisions(fixture$evaluation_contract)

  freeze <- g5_build_wfa_amd_ema_parameter_freeze_contract(
    evaluation_contract_scaffold = fixture$evaluation_contract,
    evaluation_contract_readiness_review = fixture$evaluation_readiness,
    parameter_decisions = parameter_decisions,
    operator_accepts_readiness_review = TRUE
  )
  freeze <- g5_validate_wfa_amd_ema_parameter_freeze_contract(freeze)

  expect_identical(names(freeze$run_manifest), g5_wfa_required_amd_ema_parameter_freeze_manifest_columns())
  expect_identical(names(freeze$freeze_surface), g5_wfa_required_amd_ema_parameter_freeze_surface_columns())
  expect_identical(
    freeze$run_manifest$source_readiness_acceptance_status[[1L]],
    "operator_accepted_amd_ema_evaluation_contract_readiness_review"
  )
  expect_identical(
    freeze$run_manifest$parameter_freeze_status[[1L]],
    "train_only_parameter_decisions_frozen_before_oos_measurement"
  )
  expect_true(all(freeze$freeze_surface$result_status == "not_evaluated_no_oos_results_recorded"))
  expect_true(all(freeze$freeze_surface$return_computation_status ==
    "not_implemented_no_return_columns_read_or_created"))
})

test_that("AMD EMA parameter freeze preserves no-trade as first-class comparison", {
  fixture <- g5_test_amd_ema_freeze_fixture()
  freeze <- g5_validate_wfa_amd_ema_parameter_freeze_contract(
    g5_build_wfa_amd_ema_parameter_freeze_contract(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      parameter_decisions = g5_test_amd_ema_freeze_parameter_decisions(fixture$evaluation_contract),
      operator_accepts_readiness_review = TRUE
    )
  )

  for (fold_id in unique(freeze$freeze_surface$fold_id)) {
    rows <- freeze$freeze_surface[freeze$freeze_surface$fold_id == fold_id, , drop = FALSE]
    expect_identical(rows$comparison_order, c(1L, 2L))
    expect_identical(rows$subject_id, c("no_trade_cash", "amd_ema_long_cash"))
    expect_identical(rows$comparison_role[[1L]], "no_trade_first_class_comparison")
    expect_identical(rows$comparison_role[[2L]], "amd_ema_train_only_parameter_freeze")
    expect_true(is.na(rows$fast_ema_period[[1L]]))
    expect_false(is.na(rows$fast_ema_period[[2L]]))
  }
  expect_equal(freeze$run_manifest$no_trade_row_count[[1L]], freeze$run_manifest$fold_count[[1L]])
  expect_equal(freeze$run_manifest$candidate_row_count[[1L]], freeze$run_manifest$fold_count[[1L]])
  expect_equal(freeze$run_manifest$parameter_row_count[[1L]], freeze$run_manifest$fold_count[[1L]])
})

test_that("AMD EMA parameter freeze requires explicit readiness acceptance and train-only authority", {
  fixture <- g5_test_amd_ema_freeze_fixture()
  parameter_decisions <- g5_test_amd_ema_freeze_parameter_decisions(fixture$evaluation_contract)

  expect_error(
    g5_build_wfa_amd_ema_parameter_freeze_contract(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      parameter_decisions = parameter_decisions
    ),
    "explicit operator acceptance"
  )

  oos_tainted <- parameter_decisions
  oos_tainted$oos_return <- 0
  expect_error(
    g5_build_wfa_amd_ema_parameter_freeze_contract(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      parameter_decisions = oos_tainted,
      operator_accepts_readiness_review = TRUE
    ),
    "result-like columns"
  )

  bad_authority <- parameter_decisions
  bad_authority$selection_authority_status[[1L]] <- "oos_selected"
  expect_error(
    g5_build_wfa_amd_ema_parameter_freeze_contract(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      parameter_decisions = bad_authority,
      operator_accepts_readiness_review = TRUE
    ),
    "train-only selection authority"
  )
})

test_that("AMD EMA parameter freeze rejects invalid periods, mismatched readiness, and non-ignored outputs", {
  fixture <- g5_test_amd_ema_freeze_fixture()
  parameter_decisions <- g5_test_amd_ema_freeze_parameter_decisions(fixture$evaluation_contract)

  bad_periods <- parameter_decisions
  bad_periods$fast_ema_period[[1L]] <- 50L
  expect_error(
    g5_build_wfa_amd_ema_parameter_freeze_contract(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      parameter_decisions = bad_periods,
      operator_accepts_readiness_review = TRUE
    ),
    "fast_ema_period"
  )

  mismatched_readiness <- fixture$evaluation_readiness
  mismatched_readiness$contract_id[[1L]] <- "other_contract"
  expect_error(
    g5_build_wfa_amd_ema_parameter_freeze_contract(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = mismatched_readiness,
      parameter_decisions = parameter_decisions,
      operator_accepts_readiness_review = TRUE
    ),
    "evaluation contract_id"
  )

  expect_error(
    g5_build_wfa_amd_ema_parameter_freeze_contract(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      parameter_decisions = parameter_decisions,
      output_dir = "docs/amd_ema_parameter_freeze",
      operator_accepts_readiness_review = TRUE
    ),
    "ignored runs"
  )
})

test_that("AMD EMA parameter freeze readiness and writers remain review-only", {
  fixture <- g5_test_amd_ema_freeze_fixture()
  output_dir <- file.path(tempdir(), "runs", "amd_ema_parameter_freeze_writer")
  freeze <- g5_validate_wfa_amd_ema_parameter_freeze_contract(
    g5_build_wfa_amd_ema_parameter_freeze_contract(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      parameter_decisions = g5_test_amd_ema_freeze_parameter_decisions(fixture$evaluation_contract),
      output_dir = output_dir,
      operator_accepts_readiness_review = TRUE
    )
  )
  readiness <- g5_build_wfa_amd_ema_parameter_freeze_readiness_review(freeze)
  readiness <- g5_validate_wfa_amd_ema_parameter_freeze_readiness_review(readiness)

  expect_identical(names(readiness), g5_wfa_required_amd_ema_parameter_freeze_readiness_columns())
  expect_identical(readiness$readiness_status[[1L]], "ready_for_operator_review_no_results_computed")
  expect_equal(readiness$parameter_row_count[[1L]], readiness$fold_count[[1L]])
  expect_identical(
    readiness$calculation_stop_status[[1L]],
    "ema_returns_cash_yield_trade_accounting_metrics_all_not_computed"
  )

  written <- g5_write_wfa_amd_ema_parameter_freeze_contract_csvs(freeze)
  readiness_path <- g5_write_wfa_amd_ema_parameter_freeze_readiness_csv(
    readiness,
    file.path(output_dir, "readiness", "amd_ema_parameter_freeze_readiness.csv")
  )

  expect_true(file.exists(written$manifest_path))
  expect_true(file.exists(written$freeze_surface_path))
  expect_true(file.exists(readiness_path))
  manifest_csv <- utils::read.csv(written$manifest_path, stringsAsFactors = FALSE)
  surface_csv <- utils::read.csv(written$freeze_surface_path, stringsAsFactors = FALSE)
  readiness_csv <- utils::read.csv(readiness_path, stringsAsFactors = FALSE)
  expect_identical(names(manifest_csv), g5_wfa_required_amd_ema_parameter_freeze_manifest_columns())
  expect_identical(names(surface_csv), g5_wfa_required_amd_ema_parameter_freeze_surface_columns())
  expect_identical(names(readiness_csv), g5_wfa_required_amd_ema_parameter_freeze_readiness_columns())

  expect_error(
    g5_write_wfa_amd_ema_parameter_freeze_contract_csvs(
      freeze,
      manifest_path = file.path(tempdir(), "not_runs", "manifest.csv")
    ),
    "ignored runs"
  )
  expect_error(
    g5_write_wfa_amd_ema_parameter_freeze_readiness_csv(
      readiness,
      file.path(tempdir(), "not_runs", "readiness.csv")
    ),
    "ignored runs"
  )
})
