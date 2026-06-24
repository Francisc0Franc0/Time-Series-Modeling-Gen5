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

g5_test_amd_ema_contract_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_contract_gate_result <- function(
  gate_status = "PASS",
  review_required = FALSE
) {
  g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = "runs/research_workbench/amd_ema_contract/handoff_manifest.csv",
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

g5_test_amd_ema_contract_bars <- function() {
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

g5_test_amd_ema_contract_health <- function(include_warn = FALSE) {
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

g5_test_amd_ema_contract_fixture <- function(
  gate_result = g5_test_amd_ema_contract_gate_result(),
  accept_review_required = FALSE,
  source_health = g5_test_amd_ema_contract_health()
) {
  bars <- g5_test_amd_ema_contract_bars()
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
    code_metadata = g5_test_amd_ema_contract_code_metadata()
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
  readiness <- g5_build_wfa_baseline_evaluation_contract_readiness_review(baseline_contract)
  amd_gate <- g5_build_wfa_amd_ema_evaluation_gate(
    minimal_poc_closeout = closeout,
    baseline_readiness_review = readiness,
    operator_accepts_readiness_evidence = TRUE
  )
  list(
    folds = folds,
    audit = audit,
    evidence = evidence,
    baseline_contract = baseline_contract,
    amd_gate = amd_gate
  )
}

test_that("AMD EMA evaluation contract records non-live surfaces only", {
  fixture <- g5_test_amd_ema_contract_fixture()

  scaffold <- g5_build_wfa_amd_ema_evaluation_contract_scaffold(
    amd_ema_gate = fixture$amd_gate,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_evaluation_contract = fixture$baseline_contract
  )
  scaffold <- g5_validate_wfa_amd_ema_evaluation_contract_scaffold(scaffold)

  expect_identical(names(scaffold$run_manifest), g5_wfa_required_amd_ema_contract_manifest_columns())
  expect_identical(names(scaffold$review_surface), g5_wfa_required_amd_ema_contract_review_columns())
  expect_equal(scaffold$run_manifest$fold_count[[1L]], nrow(fixture$folds))
  expect_equal(nrow(scaffold$review_surface), nrow(fixture$folds) * 2L)
  expect_identical(
    scaffold$run_manifest$evaluation_authorization_status[[1L]],
    "authorized_contract_surface_only_no_results_computed"
  )
  expect_identical(scaffold$run_manifest$result_status[[1L]], "not_evaluated_no_oos_results_recorded")
  expect_true(all(scaffold$review_surface$return_computation_status ==
    "not_implemented_no_return_columns_read_or_created"))
  expect_true(all(scaffold$review_surface$performance_metric_status ==
    "not_implemented_no_performance_metrics"))
  expect_true(all(scaffold$review_surface$trade_accounting_status ==
    "not_implemented_no_trade_accounting"))
})

test_that("AMD EMA evaluation contract keeps no-trade first-class for every fold", {
  fixture <- g5_test_amd_ema_contract_fixture()

  scaffold <- g5_validate_wfa_amd_ema_evaluation_contract_scaffold(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_evaluation_contract = fixture$baseline_contract
    )
  )

  for (fold_id in unique(scaffold$review_surface$fold_id)) {
    rows <- scaffold$review_surface[scaffold$review_surface$fold_id == fold_id, , drop = FALSE]
    expect_identical(rows$comparison_order, c(1L, 2L))
    expect_identical(rows$subject_id, c("no_trade_cash", "amd_ema_long_cash"))
    expect_identical(rows$comparison_role[[1L]], "no_trade_first_class_comparison")
    expect_identical(rows$comparison_role[[2L]], "amd_ema_candidate_contract")
  }
  expect_equal(scaffold$run_manifest$no_trade_row_count[[1L]], nrow(fixture$folds))
  expect_equal(scaffold$run_manifest$candidate_row_count[[1L]], nrow(fixture$folds))
  expect_true(all(grepl("/runs/", scaffold$review_surface$artifact_path, fixed = TRUE)))
})

test_that("AMD EMA evaluation contract preserves out-of-scope exclusions and leakage attestations", {
  fixture <- g5_test_amd_ema_contract_fixture()

  scaffold <- g5_validate_wfa_amd_ema_evaluation_contract_scaffold(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_evaluation_contract = fixture$baseline_contract
    )
  )

  expect_true(all(scaffold$review_surface$allocation_status ==
    "not_authorized_no_allocation_or_weighting"))
  expect_true(all(scaffold$review_surface$leverage_status ==
    "not_authorized_no_leverage_analysis_or_value_add"))
  expect_true(all(scaffold$review_surface$live_advice_status ==
    "not_authorized_no_live_advice"))
  expect_true(all(scaffold$review_surface$execution_status ==
    "not_authorized_no_orders_or_execution"))
  expect_true(all(scaffold$review_surface$dashboard_status ==
    "not_authorized_no_dashboard"))
  expect_true(all(scaffold$review_surface$broader_strategy_family_status ==
    "not_authorized_single_amd_ema_candidate_only"))
  expect_true(all(scaffold$review_surface$leakage_no_provider_calls))
  expect_true(all(scaffold$review_surface$leakage_no_latest_session_inference))
  expect_true(all(scaffold$review_surface$leakage_no_oos_fitting))
  expect_true(all(scaffold$review_surface$leakage_no_oos_parameter_selection))
  expect_true(all(scaffold$review_surface$leakage_no_return_or_metric_computation))
  expect_true(all(scaffold$review_surface$leakage_no_allocation_or_live_use))
})

test_that("AMD EMA evaluation contract requires accepted warning context when present", {
  review_gate <- g5_test_amd_ema_contract_gate_result(
    gate_status = "REVIEW_REQUIRED",
    review_required = TRUE
  )
  fixture <- g5_test_amd_ema_contract_fixture(
    gate_result = review_gate,
    accept_review_required = TRUE,
    source_health = g5_test_amd_ema_contract_health(include_warn = TRUE)
  )

  expect_error(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_evaluation_contract = fixture$baseline_contract
    ),
    "explicit acceptance"
  )

  scaffold <- g5_build_wfa_amd_ema_evaluation_contract_scaffold(
    amd_ema_gate = fixture$amd_gate,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_evaluation_contract = fixture$baseline_contract,
    accept_review_required = TRUE
  )

  expect_true(all(scaffold$review_surface$handoff_review_required))
  expect_true(all(scaffold$review_surface$handoff_review_accepted))
  expect_true(any(grepl(
    "accepted_source_warning_context",
    scaffold$review_surface$review_required_reason,
    fixed = TRUE
  )))
})

test_that("AMD EMA evaluation contract rejects missing AMD availability and result-like inputs", {
  fixture <- g5_test_amd_ema_contract_fixture()

  missing_amd <- fixture$audit
  missing_amd$symbol_availability <- missing_amd$symbol_availability[
    missing_amd$symbol_availability$symbol != "AMD",
    ,
    drop = FALSE
  ]
  expect_error(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = missing_amd,
      frozen_fold_evidence = fixture$evidence,
      baseline_evaluation_contract = fixture$baseline_contract
    ),
    "AMD availability"
  )

  tainted_evidence <- fixture$evidence
  tainted_evidence$oos_performance_evaluated[[1L]] <- TRUE
  expect_error(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = tainted_evidence,
      baseline_evaluation_contract = fixture$baseline_contract
    ),
    "OOS performance"
  )

  tainted_baseline <- fixture$baseline_contract
  tainted_baseline$evaluation_authorization_status[[1L]] <- "authorized_returns"
  expect_error(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_evaluation_contract = tainted_baseline
    ),
    "result-enabled|not contain applied baseline|return"
  )
})

test_that("AMD EMA evaluation contract rejects non-ignored artifact paths and computed signals", {
  fixture <- g5_test_amd_ema_contract_fixture()

  expect_error(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_evaluation_contract = fixture$baseline_contract,
      output_dir = "docs/amd_ema_evaluation_contract"
    ),
    "ignored runs"
  )

  scaffold <- g5_build_wfa_amd_ema_evaluation_contract_scaffold(
    amd_ema_gate = fixture$amd_gate,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_evaluation_contract = fixture$baseline_contract
  )
  scaffold$review_surface$ema_signal_status[scaffold$review_surface$subject_id == "amd_ema_long_cash"] <- "computed"

  expect_error(
    g5_validate_wfa_amd_ema_evaluation_contract_scaffold(scaffold),
    "compute AMD EMA signals"
  )
})

test_that("AMD EMA evaluation contract readiness review summarizes STOP states", {
  fixture <- g5_test_amd_ema_contract_fixture()
  scaffold <- g5_validate_wfa_amd_ema_evaluation_contract_scaffold(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_evaluation_contract = fixture$baseline_contract
    )
  )

  readiness <- g5_build_wfa_amd_ema_evaluation_contract_readiness_review(scaffold)
  readiness <- g5_validate_wfa_amd_ema_evaluation_contract_readiness_review(readiness)

  expect_identical(names(readiness), g5_wfa_required_amd_ema_contract_readiness_columns())
  expect_identical(
    readiness$readiness_status[[1L]],
    "ready_for_operator_review_no_results_computed"
  )
  expect_equal(readiness$fold_count[[1L]], nrow(fixture$folds))
  expect_equal(readiness$comparison_row_count[[1L]], nrow(scaffold$review_surface))
  expect_equal(readiness$no_trade_row_count[[1L]], nrow(fixture$folds))
  expect_equal(readiness$candidate_row_count[[1L]], nrow(fixture$folds))
  expect_identical(
    readiness$no_trade_comparison_status[[1L]],
    "no_trade_cash_first_class_row_for_every_fold"
  )
  expect_identical(
    readiness$candidate_contract_status[[1L]],
    "amd_ema_long_cash_contract_row_for_every_fold"
  )
  expect_identical(
    readiness$artifact_path_policy_status[[1L]],
    "all_artifacts_planned_under_ignored_runs_paths"
  )
  expect_identical(
    readiness$calculation_stop_status[[1L]],
    "ema_returns_cash_yield_trade_accounting_metrics_all_not_computed"
  )
  expect_identical(
    readiness$out_of_scope_status[[1L]],
    "allocation_leverage_live_advice_execution_dashboards_broader_families_not_authorized"
  )
  expect_identical(
    readiness$leakage_attestation_status[[1L]],
    "all_contract_leakage_attestations_true"
  )
})

test_that("AMD EMA evaluation contract readiness preserves review-required reasons", {
  fixture <- g5_test_amd_ema_contract_fixture()
  scaffold <- g5_build_wfa_amd_ema_evaluation_contract_scaffold(
    amd_ema_gate = fixture$amd_gate,
    fold_geometry = fixture$folds,
    split_audit = fixture$audit,
    frozen_fold_evidence = fixture$evidence,
    baseline_evaluation_contract = fixture$baseline_contract
  )
  readiness <- g5_build_wfa_amd_ema_evaluation_contract_readiness_review(scaffold)

  expect_identical(readiness$review_status[[1L]], "review_required_before_any_evaluation")
  expect_true(grepl(
    "cash_no_position_return_assumption_not_defined",
    readiness$review_required_reason,
    fixed = TRUE
  ))

  broken <- readiness
  broken$leakage_attestation_status[[1L]] <- "not_clean"
  expect_error(
    g5_validate_wfa_amd_ema_evaluation_contract_readiness_review(broken),
    "leakage_attestation_status"
  )

  bad_counts <- readiness
  bad_counts$no_trade_row_count[[1L]] <- 0L
  expect_error(
    g5_validate_wfa_amd_ema_evaluation_contract_readiness_review(bad_counts),
    "row counts"
  )
})

test_that("AMD EMA evaluation contract writers emit CSVs only under ignored runs paths", {
  fixture <- g5_test_amd_ema_contract_fixture()
  output_dir <- file.path(tempdir(), "runs", "amd_ema_evaluation_contract_writer")
  scaffold <- g5_validate_wfa_amd_ema_evaluation_contract_scaffold(
    g5_build_wfa_amd_ema_evaluation_contract_scaffold(
      amd_ema_gate = fixture$amd_gate,
      fold_geometry = fixture$folds,
      split_audit = fixture$audit,
      frozen_fold_evidence = fixture$evidence,
      baseline_evaluation_contract = fixture$baseline_contract,
      output_dir = output_dir
    )
  )
  readiness <- g5_build_wfa_amd_ema_evaluation_contract_readiness_review(scaffold)

  written <- g5_write_wfa_amd_ema_evaluation_contract_scaffold_csvs(scaffold)
  readiness_path <- g5_write_wfa_amd_ema_evaluation_contract_readiness_csv(
    readiness,
    file.path(output_dir, "readiness", "amd_ema_evaluation_contract_readiness.csv")
  )

  expect_true(file.exists(written$manifest_path))
  expect_true(file.exists(written$review_surface_path))
  expect_true(file.exists(readiness_path))
  manifest_csv <- utils::read.csv(written$manifest_path, stringsAsFactors = FALSE)
  review_csv <- utils::read.csv(written$review_surface_path, stringsAsFactors = FALSE)
  readiness_csv <- utils::read.csv(readiness_path, stringsAsFactors = FALSE)
  expect_identical(names(manifest_csv), g5_wfa_required_amd_ema_contract_manifest_columns())
  expect_identical(names(review_csv), g5_wfa_required_amd_ema_contract_review_columns())
  expect_identical(names(readiness_csv), g5_wfa_required_amd_ema_contract_readiness_columns())
  expect_equal(nrow(review_csv), nrow(scaffold$review_surface))

  expect_error(
    g5_write_wfa_amd_ema_evaluation_contract_scaffold_csvs(
      scaffold,
      manifest_path = file.path(tempdir(), "not_runs", "manifest.csv")
    ),
    "ignored runs"
  )
  expect_error(
    g5_write_wfa_amd_ema_evaluation_contract_readiness_csv(
      readiness,
      file.path(tempdir(), "not_runs", "readiness.csv")
    ),
    "ignored runs"
  )
})
