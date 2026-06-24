source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))
source(test_path("..", "..", "R", "wfa_fold_geometry.R"))
source(test_path("..", "..", "R", "wfa_train_oos_split_audit.R"))
source(test_path("..", "..", "R", "wfa_frozen_fold_evidence.R"))
source(test_path("..", "..", "R", "wfa_baseline_registry.R"))
source(test_path("..", "..", "R", "wfa_baseline_evaluation_contract.R"))
source(test_path("..", "..", "R", "wfa_minimal_poc_manifest.R"))

g5_test_minimal_poc_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_minimal_poc_gate_result <- function(
  gate_status = "PASS",
  review_required = FALSE
) {
  g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = "runs/research_workbench/minimal_poc/handoff_manifest.csv",
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

g5_test_minimal_poc_bars <- function() {
  g5_validate_bar_data(data.frame(
    symbol = c(
      rep("SPY", 9L),
      rep("QQQ", 5L),
      rep("NVDA", 2L)
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

g5_test_minimal_poc_coverage <- function(bars) {
  g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = c("SPY", "QQQ", "NVDA", "EMPTY"),
    latest_completed_session = as.Date("2026-04-03"),
    requested_start_date = as.Date("2025-12-29"),
    requested_end_date = as.Date("2026-04-03")
  )
}

g5_test_minimal_poc_health <- function(include_warn = TRUE) {
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
    category = c("empty_symbol", "row_count"),
    symbol = c("EMPTY", ""),
    detail = c(
      "EMPTY has no rows in source handoff",
      "query row count: 16"
    ),
    stringsAsFactors = FALSE
  )
}

g5_test_minimal_poc_fixture <- function(
  gate_result = g5_test_minimal_poc_gate_result(),
  accept_review_required = FALSE,
  source_health = g5_test_minimal_poc_health(include_warn = TRUE)
) {
  bars <- g5_test_minimal_poc_bars()
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
    source_symbol_coverage = g5_test_minimal_poc_coverage(bars),
    source_health = source_health,
    accept_review_required = accept_review_required
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    accept_review_required = accept_review_required,
    code_metadata = g5_test_minimal_poc_code_metadata()
  )
  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence,
    accept_review_required = accept_review_required
  )
  contract <- g5_build_wfa_baseline_evaluation_contract_scaffold(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence,
    baseline_registry = registry,
    accept_review_required = accept_review_required
  )
  list(
    folds = folds,
    audit = audit,
    evidence = evidence,
    registry = registry,
    contract = contract
  )
}

test_that("minimal WFA POC scaffold records manifest and review rows without evaluation", {
  gate_result <- g5_test_minimal_poc_gate_result()
  fixture <- g5_test_minimal_poc_fixture(gate_result)

  scaffold <- g5_build_wfa_minimal_poc_scaffold(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_registry = fixture$registry,
    baseline_evaluation_contract = fixture$contract
  )
  scaffold <- g5_validate_wfa_minimal_poc_scaffold(scaffold)

  expect_identical(names(scaffold$run_manifest), g5_wfa_required_minimal_poc_manifest_columns())
  expect_identical(names(scaffold$review_surface), g5_wfa_required_minimal_poc_review_columns())
  expect_equal(nrow(scaffold$run_manifest), 1L)
  expect_equal(nrow(scaffold$review_surface), nrow(fixture$folds))
  expect_true(grepl("minimal_wfa_poc", scaffold$run_manifest$poc_run_id, fixed = TRUE))
  expect_true(all(scaffold$review_surface$poc_run_id == scaffold$run_manifest$poc_run_id[[1L]]))
  expect_true(all(grepl("/runs/", scaffold$run_manifest$run_manifest_path, fixed = TRUE)))
  expect_true(all(grepl("/runs/", scaffold$run_manifest$review_surface_path, fixed = TRUE)))
  expect_true(all(grepl("/runs/", scaffold$review_surface$artifact_path, fixed = TRUE)))

  expect_identical(
    scaffold$run_manifest$fold_geometry_status[[1L]],
    "explicit_quarterly_geometry_recorded"
  )
  expect_identical(
    scaffold$run_manifest$train_oos_split_status[[1L]],
    "split_audit_recorded_no_outcome_membership"
  )
  expect_identical(
    scaffold$run_manifest$frozen_evidence_status[[1L]],
    "frozen_no_active_decision_evidence_recorded"
  )
  expect_identical(
    scaffold$run_manifest$baseline_registry_status[[1L]],
    "no_trade_first_reserved_baselines_recorded"
  )
  expect_true(all(scaffold$review_surface$no_trade_readiness_status ==
    "no_trade_cash_reserved_first_no_returns_computed"))
  expect_true(all(grepl(
    "no_trade_cash",
    scaffold$review_surface$baseline_family_ids,
    fixed = TRUE
  )))
  expect_true(all(grepl(
    "broad_market_buy_hold",
    scaffold$review_surface$baseline_family_ids,
    fixed = TRUE
  )))
})

test_that("minimal WFA POC scaffold keeps STOP statuses and leakage attestations explicit", {
  gate_result <- g5_test_minimal_poc_gate_result()
  fixture <- g5_test_minimal_poc_fixture(gate_result)

  scaffold <- g5_validate_wfa_minimal_poc_scaffold(g5_build_wfa_minimal_poc_scaffold(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_registry = fixture$registry,
    baseline_evaluation_contract = fixture$contract
  ))

  expect_identical(
    scaffold$run_manifest$evaluation_authorization_status[[1L]],
    "not_authorized_no_oos_evaluation"
  )
  expect_true(all(scaffold$review_surface$evaluation_authorization_status ==
    "not_authorized_no_oos_evaluation"))
  expect_true(all(scaffold$review_surface$oos_result_status ==
    "not_evaluated_oos_results_not_read"))
  expect_true(all(scaffold$review_surface$return_computation_status ==
    "not_implemented_no_return_columns_read_or_created"))
  expect_true(all(scaffold$review_surface$cash_yield_status ==
    "not_implemented_no_cash_yield_assumption"))
  expect_true(all(scaffold$review_surface$benchmark_math_status ==
    "not_implemented_no_benchmark_math"))
  expect_true(all(scaffold$review_surface$performance_metric_status ==
    "not_implemented_no_performance_metrics"))
  expect_true(all(scaffold$review_surface$allocation_status ==
    "not_implemented_no_allocation_or_weighting"))
  expect_true(all(scaffold$review_surface$active_candidate_status ==
    "not_authorized_no_active_candidate_inputs"))
  expect_true(all(scaffold$review_surface$leakage_no_provider_calls))
  expect_true(all(scaffold$review_surface$leakage_no_credentials))
  expect_true(all(scaffold$review_surface$leakage_no_unmanifested_cache))
  expect_true(all(scaffold$review_surface$leakage_no_latest_session_inference))
  expect_true(all(scaffold$review_surface$leakage_no_oos_outcome_authority))
  expect_true(all(scaffold$review_surface$leakage_no_oos_fitting))
  expect_true(all(scaffold$review_surface$leakage_no_active_candidate_inputs))
  expect_true(all(scaffold$review_surface$leakage_no_return_or_metric_computation))
})

test_that("minimal WFA POC scaffold requires review acceptance and ignored output paths", {
  review_gate <- g5_test_minimal_poc_gate_result(
    gate_status = "REVIEW_REQUIRED",
    review_required = TRUE
  )
  fixture <- g5_test_minimal_poc_fixture(
    gate_result = review_gate,
    accept_review_required = TRUE
  )

  expect_error(
    g5_build_wfa_minimal_poc_scaffold(
      gate_result = review_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_registry = fixture$registry,
      baseline_evaluation_contract = fixture$contract
    ),
    "accept_review_required"
  )

  scaffold <- g5_build_wfa_minimal_poc_scaffold(
    gate_result = review_gate,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_registry = fixture$registry,
    baseline_evaluation_contract = fixture$contract,
    accept_review_required = TRUE
  )
  expect_true(all(scaffold$review_surface$handoff_review_required))
  expect_true(all(scaffold$review_surface$handoff_review_accepted))
  expect_true(all(grepl(
    "accepted_source_warning_context",
    scaffold$review_surface$review_required_reason,
    fixed = TRUE
  )))

  clean_gate <- g5_test_minimal_poc_gate_result()
  clean_fixture <- g5_test_minimal_poc_fixture(clean_gate)
  expect_error(
    g5_build_wfa_minimal_poc_scaffold(
      gate_result = clean_gate,
      fold_geometry = clean_fixture$folds,
      split_audit = clean_fixture$audit,
      frozen_fold_evidence = clean_fixture$evidence,
      baseline_registry = clean_fixture$registry,
      baseline_evaluation_contract = clean_fixture$contract,
      output_dir = "docs/wfa_minimal_poc"
    ),
    "ignored runs"
  )
})

test_that("minimal WFA POC scaffold rejects evaluation-enabled upstream inputs", {
  gate_result <- g5_test_minimal_poc_gate_result()
  fixture <- g5_test_minimal_poc_fixture(gate_result)

  tainted_contract <- fixture$contract
  tainted_contract$evaluation_authorization_status[[1L]] <- "authorized"
  expect_error(
    g5_build_wfa_minimal_poc_scaffold(
      gate_result = gate_result,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_registry = fixture$registry,
      baseline_evaluation_contract = tainted_contract
    ),
    "authorize OOS evaluation|authorized baseline evaluation"
  )

  tainted_registry <- fixture$registry
  tainted_registry$return_computation_status[[1L]] <- "implemented"
  expect_error(
    g5_build_wfa_minimal_poc_scaffold(
      gate_result = gate_result,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_registry = tainted_registry,
      baseline_evaluation_contract = fixture$contract
    ),
    "return, performance, or allocation-enabled"
  )
})

test_that("minimal WFA POC closeout validation proves lineage, STOP states, and leakage", {
  gate_result <- g5_test_minimal_poc_gate_result()
  fixture <- g5_test_minimal_poc_fixture(gate_result)
  scaffold <- g5_validate_wfa_minimal_poc_scaffold(g5_build_wfa_minimal_poc_scaffold(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_registry = fixture$registry,
    baseline_evaluation_contract = fixture$contract
  ))

  closeout <- g5_build_wfa_minimal_poc_closeout_validation(scaffold)

  expect_identical(names(closeout), g5_wfa_required_minimal_poc_closeout_columns())
  expect_equal(nrow(closeout), 9L)
  expect_true(all(closeout$schema_version == g5_wfa_minimal_poc_schema_version()))
  expect_true(all(closeout$poc_run_id == scaffold$run_manifest$poc_run_id[[1L]]))
  expect_true(all(closeout$check_status == "PASS"))
  expect_true(all(closeout$review_status == "closeout_ready_no_evaluation_authorized"))
  expect_setequal(
    closeout$check_id,
    c(
      "accepted_handoff_lineage",
      "explicit_quarterly_fold_geometry",
      "train_oos_split_evidence",
      "frozen_no_active_decision_evidence",
      "baseline_readiness",
      "fold_stability_placeholder",
      "ignored_run_paths",
      "stop_states_preserved",
      "leakage_attestations"
    )
  )
  expect_true(any(grepl(
    "not_authorized_no_oos_evaluation",
    closeout$evidence_value,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "leakage_no_provider_calls",
    closeout$evidence_value,
    fixed = TRUE
  )))
})

test_that("minimal WFA POC closeout validation rejects broken lineage and STOP states", {
  gate_result <- g5_test_minimal_poc_gate_result()
  fixture <- g5_test_minimal_poc_fixture(gate_result)
  scaffold <- g5_validate_wfa_minimal_poc_scaffold(g5_build_wfa_minimal_poc_scaffold(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_registry = fixture$registry,
    baseline_evaluation_contract = fixture$contract
  ))

  broken_lineage <- scaffold
  broken_lineage$review_surface$source_gate_manifest_csv[[1L]] <- "runs/other/handoff.csv"
  expect_error(
    g5_build_wfa_minimal_poc_closeout_validation(broken_lineage),
    "source gate manifest lineage"
  )

  broken_stop <- scaffold
  broken_stop$review_surface$oos_result_status[[1L]] <- "evaluated"
  expect_error(
    g5_build_wfa_minimal_poc_closeout_validation(broken_stop),
    "evaluated OOS results|OOS evaluation|STOP status"
  )

  broken_leakage <- scaffold
  broken_leakage$review_surface$leakage_no_provider_calls[[1L]] <- FALSE
  expect_error(
    g5_build_wfa_minimal_poc_closeout_validation(broken_leakage),
    "leakage attestation"
  )
})
