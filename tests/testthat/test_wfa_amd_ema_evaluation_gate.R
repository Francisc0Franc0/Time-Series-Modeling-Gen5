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

g5_test_amd_ema_gate_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_gate_result <- function() {
  g5_wfa_handoff_gate_result(
    gate_status = "PASS",
    manifest_csv = "runs/research_workbench/amd_ema_gate/handoff_manifest.csv",
    as_of_timestamp = "2026-04-03 17:00:00",
    latest_completed_session = as.Date("2026-04-03"),
    health_max_severity = "INFO",
    warn_row_count = 0L,
    review_required = FALSE,
    detail = "handoff passed WFA gate"
  )
}

g5_test_amd_ema_gate_bars <- function() {
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

g5_test_amd_ema_gate_fixture <- function() {
  gate_result <- g5_test_amd_ema_gate_result()
  bars <- g5_test_amd_ema_gate_bars()
  folds <- g5_build_quarterly_fold_geometry(
    gate_result = gate_result,
    train_start_date = as.Date("2025-12-29"),
    first_oos_start_date = as.Date("2026-01-01"),
    final_oos_end_date = as.Date("2026-04-03")
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
    source_health = data.frame(
      severity = "INFO",
      category = "row_count",
      symbol = "",
      detail = "query row count: 16",
      stringsAsFactors = FALSE
    )
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    code_metadata = g5_test_amd_ema_gate_code_metadata()
  )
  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence
  )
  contract <- g5_build_wfa_baseline_evaluation_contract_scaffold(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence,
    baseline_registry = registry
  )
  scaffold <- g5_validate_wfa_minimal_poc_scaffold(g5_build_wfa_minimal_poc_scaffold(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    frozen_fold_evidence = evidence,
    baseline_registry = registry,
    baseline_evaluation_contract = contract
  ))
  list(
    closeout = g5_build_wfa_minimal_poc_closeout_validation(scaffold),
    readiness = g5_build_wfa_baseline_evaluation_contract_readiness_review(contract)
  )
}

test_that("AMD EMA gate opens only the narrow non-live evaluation authorization surface", {
  fixture <- g5_test_amd_ema_gate_fixture()

  gate <- g5_build_wfa_amd_ema_evaluation_gate(
    minimal_poc_closeout = fixture$closeout,
    baseline_readiness_review = fixture$readiness,
    operator_accepts_readiness_evidence = TRUE
  )
  gate <- g5_validate_wfa_amd_ema_evaluation_gate(gate)

  expect_identical(names(gate), g5_wfa_required_amd_ema_evaluation_gate_columns())
  expect_identical(gate$candidate_id[[1L]], "amd_ema_long_cash")
  expect_identical(gate$candidate_symbol[[1L]], "AMD")
  expect_identical(gate$strategy_family[[1L]], "ema_long_cash")
  expect_identical(gate$gate_status[[1L]], "GO_NARROW_RESEARCH_EVALUATION_ONLY")
  expect_identical(
    gate$evaluation_authorization_status[[1L]],
    "authorized_narrow_non_live_non_dashboard_amd_ema_long_cash"
  )
  expect_identical(
    gate$implementation_status[[1L]],
    "gate_open_contract_only_no_strategy_results_computed"
  )
})

test_that("AMD EMA gate preserves no-trade discipline and explicit out-of-scope exclusions", {
  fixture <- g5_test_amd_ema_gate_fixture()

  gate <- g5_validate_wfa_amd_ema_evaluation_gate(g5_build_wfa_amd_ema_evaluation_gate(
    minimal_poc_closeout = fixture$closeout,
    baseline_readiness_review = fixture$readiness,
    operator_accepts_readiness_evidence = TRUE
  ))

  expect_true(grepl("no_trade_cash", gate$included_baseline_family_ids, fixed = TRUE))
  expect_identical(gate$no_trade_baseline_status[[1L]], "required_first_class_comparison_for_every_fold")
  expect_identical(gate$allocation_status[[1L]], "not_authorized_no_allocation_or_weighting")
  expect_identical(gate$leverage_status[[1L]], "not_authorized_no_leverage_analysis_or_value_add")
  expect_identical(gate$live_advice_status[[1L]], "not_authorized_no_live_advice")
  expect_identical(gate$execution_status[[1L]], "not_authorized_no_orders_or_execution")
  expect_identical(gate$dashboard_status[[1L]], "not_authorized_no_dashboard")
  expect_identical(
    gate$broader_strategy_family_status[[1L]],
    "not_authorized_single_amd_ema_candidate_only"
  )
  expect_true(grepl("/runs/", gate$gate_manifest_path, fixed = TRUE))
})

test_that("AMD EMA gate requires explicit operator acceptance and shared readiness lineage", {
  fixture <- g5_test_amd_ema_gate_fixture()

  expect_error(
    g5_build_wfa_amd_ema_evaluation_gate(
      minimal_poc_closeout = fixture$closeout,
      baseline_readiness_review = fixture$readiness
    ),
    "operator acceptance"
  )

  mismatched_readiness <- fixture$readiness
  mismatched_readiness$source_gate_manifest_csv[[1L]] <- "runs/research_workbench/other/handoff_manifest.csv"
  expect_error(
    g5_build_wfa_amd_ema_evaluation_gate(
      minimal_poc_closeout = fixture$closeout,
      baseline_readiness_review = mismatched_readiness,
      operator_accepts_readiness_evidence = TRUE
    ),
    "source handoff lineage"
  )
})

test_that("AMD EMA gate rejects broken closeout, baseline stop states, and leakage attestations", {
  fixture <- g5_test_amd_ema_gate_fixture()

  broken_closeout <- fixture$closeout
  broken_closeout$check_status[[1L]] <- "FAIL"
  expect_error(
    g5_build_wfa_amd_ema_evaluation_gate(
      minimal_poc_closeout = broken_closeout,
      baseline_readiness_review = fixture$readiness,
      operator_accepts_readiness_evidence = TRUE
    ),
    "PASS closeout checks"
  )

  broken_readiness <- fixture$readiness
  broken_readiness$calculation_stop_status[[1L]] <- "returns_implemented"
  expect_error(
    g5_build_wfa_amd_ema_evaluation_gate(
      minimal_poc_closeout = fixture$closeout,
      baseline_readiness_review = broken_readiness,
      operator_accepts_readiness_evidence = TRUE
    ),
    "calculation STOP"
  )

  gate <- g5_build_wfa_amd_ema_evaluation_gate(
    minimal_poc_closeout = fixture$closeout,
    baseline_readiness_review = fixture$readiness,
    operator_accepts_readiness_evidence = TRUE
  )
  gate$leakage_no_oos_parameter_selection[[1L]] <- FALSE
  expect_error(
    g5_validate_wfa_amd_ema_evaluation_gate(gate),
    "leakage attestation"
  )
})
