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
source(test_path("..", "..", "R", "wfa_amd_ema_parameter_application_boundary.R"))

g5_test_amd_ema_application_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_application_gate_result <- function(
  gate_status = "PASS",
  review_required = FALSE
) {
  g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = "runs/research_workbench/amd_ema_application/handoff_manifest.csv",
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

g5_test_amd_ema_application_bars <- function() {
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

g5_test_amd_ema_application_health <- function() {
  data.frame(
    severity = "INFO",
    category = "row_count",
    symbol = "",
    detail = "query row count: 16",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_application_parameter_decisions <- function(evaluation_contract) {
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

g5_test_amd_ema_application_fixture <- function(output_dir = NULL) {
  gate_result <- g5_test_amd_ema_application_gate_result()
  bars <- g5_test_amd_ema_application_bars()
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
    source_health = g5_test_amd_ema_application_health()
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    code_metadata = g5_test_amd_ema_application_code_metadata()
  )
  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence
  )
  baseline_contract <- g5_build_wfa_baseline_evaluation_contract_scaffold(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence,
    baseline_registry = registry
  )
  minimal_poc <- g5_validate_wfa_minimal_poc_scaffold(g5_build_wfa_minimal_poc_scaffold(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    frozen_fold_evidence = evidence,
    baseline_registry = registry,
    baseline_evaluation_contract = baseline_contract
  ))
  closeout <- g5_build_wfa_minimal_poc_closeout_validation(minimal_poc)
  baseline_readiness <- g5_build_wfa_baseline_evaluation_contract_readiness_review(baseline_contract)
  amd_gate <- g5_build_wfa_amd_ema_evaluation_gate(
    minimal_poc_closeout = closeout,
    baseline_readiness_review = baseline_readiness,
    operator_accepts_readiness_evidence = TRUE
  )
  evaluation_contract <- g5_build_wfa_amd_ema_evaluation_contract_scaffold(
    amd_ema_gate = amd_gate,
    fold_geometry = folds,
    split_audit = audit,
    frozen_fold_evidence = evidence,
    baseline_evaluation_contract = baseline_contract
  )
  evaluation_readiness <- g5_build_wfa_amd_ema_evaluation_contract_readiness_review(
    evaluation_contract
  )
  freeze_args <- list(
    evaluation_contract_scaffold = evaluation_contract,
    evaluation_contract_readiness_review = evaluation_readiness,
    parameter_decisions = g5_test_amd_ema_application_parameter_decisions(evaluation_contract),
    operator_accepts_readiness_review = TRUE
  )
  if (!is.null(output_dir)) {
    freeze_args$output_dir <- output_dir
  }
  freeze <- do.call(g5_build_wfa_amd_ema_parameter_freeze_contract, freeze_args)
  freeze_readiness <- g5_build_wfa_amd_ema_parameter_freeze_readiness_review(freeze)
  list(
    folds = folds,
    freeze = freeze,
    freeze_readiness = freeze_readiness
  )
}

test_that("AMD EMA parameter application boundary consumes accepted freeze readiness and preserves lineage", {
  fixture <- g5_test_amd_ema_application_fixture()

  boundary <- g5_build_wfa_amd_ema_parameter_application_boundary(
    parameter_freeze_contract = fixture$freeze,
    parameter_freeze_readiness_review = fixture$freeze_readiness,
    operator_accepts_freeze_readiness_review = TRUE
  )
  boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(boundary)

  expect_identical(
    names(boundary$run_manifest),
    g5_wfa_required_amd_ema_parameter_application_manifest_columns()
  )
  expect_identical(
    names(boundary$application_surface),
    g5_wfa_required_amd_ema_parameter_application_surface_columns()
  )
  expect_identical(
    boundary$run_manifest$source_freeze_contract_id[[1L]],
    fixture$freeze$run_manifest$freeze_contract_id[[1L]]
  )
  expect_identical(
    boundary$run_manifest$source_freeze_readiness_review_id[[1L]],
    fixture$freeze_readiness$readiness_review_id[[1L]]
  )
  expect_identical(
    boundary$run_manifest$source_freeze_acceptance_status[[1L]],
    "operator_accepted_amd_ema_parameter_freeze_readiness_review"
  )
  expect_identical(
    boundary$run_manifest$oos_application_boundary_status[[1L]],
    "frozen_parameters_bound_to_oos_windows_no_signals_or_results"
  )
  expect_identical(
    boundary$run_manifest$oos_measurement_status[[1L]],
    "not_authorized_no_oos_measurement_fields"
  )
})

test_that("AMD EMA parameter application boundary preserves no-trade first and frozen periods", {
  fixture <- g5_test_amd_ema_application_fixture()
  boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
    g5_build_wfa_amd_ema_parameter_application_boundary(
      parameter_freeze_contract = fixture$freeze,
      parameter_freeze_readiness_review = fixture$freeze_readiness,
      operator_accepts_freeze_readiness_review = TRUE
    )
  )

  for (fold_id in unique(boundary$application_surface$fold_id)) {
    rows <- boundary$application_surface[
      boundary$application_surface$fold_id == fold_id,
      ,
      drop = FALSE
    ]
    expect_identical(rows$comparison_order, c(1L, 2L))
    expect_identical(rows$subject_id, c("no_trade_cash", "amd_ema_long_cash"))
    expect_identical(rows$comparison_role[[1L]], "no_trade_first_class_oos_window_boundary")
    expect_identical(rows$comparison_role[[2L]], "amd_ema_frozen_parameter_oos_application_boundary")
    expect_true(is.na(rows$fast_ema_period[[1L]]))
    expect_identical(rows$fast_ema_period[[2L]], 10L)
    expect_identical(rows$slow_ema_period[[2L]], 30L)
    expect_true(grepl("fast10_slow30", rows$frozen_parameter_id[[2L]], fixed = TRUE))
  }
  expect_equal(boundary$run_manifest$no_trade_row_count[[1L]], nrow(fixture$folds))
  expect_equal(boundary$run_manifest$candidate_row_count[[1L]], nrow(fixture$folds))
  expect_equal(boundary$run_manifest$parameter_row_count[[1L]], nrow(fixture$folds))
})

test_that("AMD EMA parameter application boundary preserves STOP states and leakage attestations", {
  fixture <- g5_test_amd_ema_application_fixture()
  boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
    g5_build_wfa_amd_ema_parameter_application_boundary(
      parameter_freeze_contract = fixture$freeze,
      parameter_freeze_readiness_review = fixture$freeze_readiness,
      operator_accepts_freeze_readiness_review = TRUE
    )
  )

  expect_true(all(boundary$application_surface$result_status ==
    "not_evaluated_no_oos_results_recorded"))
  expect_true(all(boundary$application_surface$return_computation_status ==
    "not_implemented_no_return_columns_read_or_created"))
  expect_true(all(boundary$application_surface$cash_yield_status ==
    "not_implemented_no_cash_yield_assumption"))
  expect_true(all(boundary$application_surface$trade_accounting_status ==
    "not_implemented_no_trade_accounting"))
  expect_true(all(boundary$application_surface$benchmark_math_status ==
    "not_implemented_no_benchmark_math"))
  expect_true(all(boundary$application_surface$performance_metric_status ==
    "not_implemented_no_performance_metrics"))
  expect_true(all(boundary$application_surface$allocation_status ==
    "not_authorized_no_allocation_or_weighting"))
  expect_true(all(boundary$application_surface$leverage_status ==
    "not_authorized_no_leverage_analysis_or_value_add"))
  expect_true(all(boundary$application_surface$live_advice_status ==
    "not_authorized_no_live_advice"))
  expect_true(all(boundary$application_surface$execution_status ==
    "not_authorized_no_orders_or_execution"))
  expect_true(all(boundary$application_surface$dashboard_status ==
    "not_authorized_no_dashboard"))
  expect_true(all(boundary$application_surface$broader_strategy_family_status ==
    "not_authorized_single_amd_ema_candidate_only"))
  expect_true(all(boundary$application_surface$leakage_no_provider_calls))
  expect_true(all(boundary$application_surface$leakage_no_credentials))
  expect_true(all(boundary$application_surface$leakage_no_unmanifested_cache))
  expect_true(all(boundary$application_surface$leakage_no_latest_session_inference))
  expect_true(all(boundary$application_surface$leakage_no_oos_outcome_authority))
  expect_true(all(boundary$application_surface$leakage_no_oos_fitting))
  expect_true(all(boundary$application_surface$leakage_no_oos_parameter_selection))
  expect_true(all(boundary$application_surface$leakage_no_return_or_metric_computation))
  expect_true(all(boundary$application_surface$leakage_no_allocation_or_live_use))
})

test_that("AMD EMA parameter application boundary rejects unaccepted, OOS-informed, or result-like inputs", {
  fixture <- g5_test_amd_ema_application_fixture()

  expect_error(
    g5_build_wfa_amd_ema_parameter_application_boundary(
      parameter_freeze_contract = fixture$freeze,
      parameter_freeze_readiness_review = fixture$freeze_readiness
    ),
    "explicit operator acceptance"
  )

  oos_tainted <- fixture$freeze
  oos_tainted$freeze_surface$oos_return <- 0
  expect_error(
    g5_build_wfa_amd_ema_parameter_application_boundary(
      parameter_freeze_contract = oos_tainted,
      parameter_freeze_readiness_review = fixture$freeze_readiness,
      operator_accepts_freeze_readiness_review = TRUE
    ),
    "OOS-informed or result-like columns"
  )

  ranked_from_oos <- fixture$freeze
  ranked_from_oos$run_manifest$parameter_rank_from_oos <- 1L
  expect_error(
    g5_build_wfa_amd_ema_parameter_application_boundary(
      parameter_freeze_contract = ranked_from_oos,
      parameter_freeze_readiness_review = fixture$freeze_readiness,
      operator_accepts_freeze_readiness_review = TRUE
    ),
    "OOS-informed or result-like columns"
  )
})

test_that("AMD EMA parameter application boundary rejects computed signals, measurements, and non-ignored outputs", {
  fixture <- g5_test_amd_ema_application_fixture()

  expect_error(
    g5_build_wfa_amd_ema_parameter_application_boundary(
      parameter_freeze_contract = fixture$freeze,
      parameter_freeze_readiness_review = fixture$freeze_readiness,
      output_dir = "docs/amd_ema_application_boundary",
      operator_accepts_freeze_readiness_review = TRUE
    ),
    "ignored runs"
  )

  boundary <- g5_build_wfa_amd_ema_parameter_application_boundary(
    parameter_freeze_contract = fixture$freeze,
    parameter_freeze_readiness_review = fixture$freeze_readiness,
    operator_accepts_freeze_readiness_review = TRUE
  )

  computed_signal <- boundary
  computed_signal$application_surface$ema_signal_status[
    computed_signal$application_surface$subject_id == "amd_ema_long_cash"
  ] <- "computed"
  expect_error(
    g5_validate_wfa_amd_ema_parameter_application_boundary(computed_signal),
    "must not compute AMD EMA signals"
  )

  measured <- boundary
  measured$application_surface$oos_measurement_status[[1L]] <- "authorized_returns"
  expect_error(
    g5_validate_wfa_amd_ema_parameter_application_boundary(measured),
    "oos_measurement_status"
  )

  result_like <- boundary
  result_like$application_surface$signal_value <- 1
  expect_error(
    g5_validate_wfa_amd_ema_parameter_application_boundary(result_like),
    "OOS-informed or result-like columns"
  )
})

test_that("AMD EMA parameter application readiness and writers remain boundary-only", {
  output_dir <- file.path(tempdir(), "runs", "amd_ema_application_boundary_writer")
  fixture <- g5_test_amd_ema_application_fixture(output_dir = output_dir)
  boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
    g5_build_wfa_amd_ema_parameter_application_boundary(
      parameter_freeze_contract = fixture$freeze,
      parameter_freeze_readiness_review = fixture$freeze_readiness,
      output_dir = output_dir,
      operator_accepts_freeze_readiness_review = TRUE
    )
  )
  readiness <- g5_build_wfa_amd_ema_parameter_application_readiness_review(boundary)
  readiness <- g5_validate_wfa_amd_ema_parameter_application_readiness_review(readiness)

  expect_identical(
    names(readiness),
    g5_wfa_required_amd_ema_parameter_application_readiness_columns()
  )
  expect_identical(readiness$readiness_status[[1L]], "ready_for_operator_review_no_results_computed")
  expect_identical(
    readiness$application_boundary_status[[1L]],
    "frozen_parameters_bound_to_oos_windows_no_signals_or_results"
  )
  expect_identical(
    readiness$calculation_stop_status[[1L]],
    "ema_signals_returns_cash_yield_trade_accounting_benchmark_math_metrics_all_not_computed"
  )

  written <- g5_write_wfa_amd_ema_parameter_application_boundary_csvs(boundary)
  readiness_path <- g5_write_wfa_amd_ema_parameter_application_readiness_csv(
    readiness,
    file.path(output_dir, "readiness", "amd_ema_parameter_application_readiness.csv")
  )

  expect_true(file.exists(written$manifest_path))
  expect_true(file.exists(written$application_surface_path))
  expect_true(file.exists(readiness_path))
  manifest_csv <- utils::read.csv(written$manifest_path, stringsAsFactors = FALSE)
  surface_csv <- utils::read.csv(written$application_surface_path, stringsAsFactors = FALSE)
  readiness_csv <- utils::read.csv(readiness_path, stringsAsFactors = FALSE)
  expect_identical(names(manifest_csv), g5_wfa_required_amd_ema_parameter_application_manifest_columns())
  expect_identical(names(surface_csv), g5_wfa_required_amd_ema_parameter_application_surface_columns())
  expect_identical(names(readiness_csv), g5_wfa_required_amd_ema_parameter_application_readiness_columns())

  expect_error(
    g5_write_wfa_amd_ema_parameter_application_boundary_csvs(
      boundary,
      manifest_path = file.path(tempdir(), "not_runs", "manifest.csv")
    ),
    "ignored runs"
  )
  expect_error(
    g5_write_wfa_amd_ema_parameter_application_readiness_csv(
      readiness,
      file.path(tempdir(), "not_runs", "readiness.csv")
    ),
    "ignored runs"
  )
})
