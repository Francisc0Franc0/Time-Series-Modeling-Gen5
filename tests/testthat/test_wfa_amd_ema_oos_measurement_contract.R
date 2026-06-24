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
source(test_path("..", "..", "R", "wfa_amd_ema_oos_measurement_contract.R"))

g5_test_amd_ema_measurement_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_measurement_gate_result <- function() {
  g5_wfa_handoff_gate_result(
    gate_status = "PASS",
    manifest_csv = "runs/research_workbench/amd_ema_measurement/handoff_manifest.csv",
    as_of_timestamp = "2026-04-03 17:00:00",
    latest_completed_session = as.Date("2026-04-03"),
    health_max_severity = "INFO",
    warn_row_count = 0L,
    review_required = FALSE,
    detail = "handoff passed WFA gate"
  )
}

g5_test_amd_ema_measurement_bars <- function() {
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

g5_test_amd_ema_measurement_health <- function() {
  data.frame(
    severity = "INFO",
    category = "row_count",
    symbol = "",
    detail = "query row count: 16",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_measurement_parameter_decisions <- function(evaluation_contract) {
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

g5_test_amd_ema_measurement_fixture <- function() {
  gate_result <- g5_test_amd_ema_measurement_gate_result()
  bars <- g5_test_amd_ema_measurement_bars()
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
    source_health = g5_test_amd_ema_measurement_health()
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    code_metadata = g5_test_amd_ema_measurement_code_metadata()
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
  freeze <- g5_build_wfa_amd_ema_parameter_freeze_contract(
    evaluation_contract_scaffold = evaluation_contract,
    evaluation_contract_readiness_review = evaluation_readiness,
    parameter_decisions = g5_test_amd_ema_measurement_parameter_decisions(evaluation_contract),
    operator_accepts_readiness_review = TRUE
  )
  freeze_readiness <- g5_build_wfa_amd_ema_parameter_freeze_readiness_review(freeze)
  application <- g5_build_wfa_amd_ema_parameter_application_boundary(
    parameter_freeze_contract = freeze,
    parameter_freeze_readiness_review = freeze_readiness,
    operator_accepts_freeze_readiness_review = TRUE
  )
  application_readiness <- g5_build_wfa_amd_ema_parameter_application_readiness_review(application)
  list(
    application = application,
    application_readiness = application_readiness
  )
}

g5_test_amd_ema_session_measurements <- function(contract, application) {
  manifest <- contract$run_manifest
  application_surface <- application$application_surface
  rows <- list()
  k <- 0L
  for (i in seq_len(nrow(application_surface))) {
    app_row <- application_surface[i, , drop = FALSE]
    count <- as.integer(app_row$amd_oos_row_count[[1L]])
    dates <- seq.Date(as.Date(app_row$oos_start_date[[1L]]), by = "day", length.out = count)
    is_no_trade <- identical(as.character(app_row$subject_id[[1L]]), "no_trade_cash")
    for (j in seq_len(count)) {
      k <- k + 1L
      rows[[k]] <- data.frame(
        schema_version = g5_wfa_amd_ema_oos_measurement_contract_schema_version(),
        measurement_contract_id = as.character(manifest$measurement_contract_id[[1L]]),
        measurement_run_id = paste(as.character(manifest$measurement_contract_id[[1L]]), "fixture", sep = "_"),
        application_run_id = as.character(app_row$application_boundary_id[[1L]]),
        application_row_id = as.character(app_row$application_row_id[[1L]]),
        application_artifact_hash = as.character(manifest$source_application_artifact_hash[[1L]]),
        parameter_pack_id = as.character(app_row$frozen_parameter_id[[1L]]),
        as_of_timestamp = as.character(app_row$as_of_timestamp[[1L]]),
        oos_fold_id = as.character(app_row$fold_id[[1L]]),
        comparison_order = as.integer(app_row$comparison_order[[1L]]),
        subject_id = as.character(app_row$subject_id[[1L]]),
        symbol = if (is_no_trade) NA_character_ else as.character(app_row$candidate_symbol[[1L]]),
        strategy_id = if (is_no_trade) "no_trade_cash" else as.character(app_row$strategy_family[[1L]]),
        session_date = dates[[j]],
        measurement_status = if (is_no_trade) "flat_no_position" else "measured",
        position_state = if (is_no_trade) "no_position" else "long",
        trade_id = if (is_no_trade) NA_character_ else paste("fixture_trade", app_row$fold_id[[1L]], sep = "_"),
        asset_session_return_open_to_close = if (is_no_trade) 0 else 0.01,
        strategy_session_return = if (is_no_trade) 0 else 0.01,
        no_trade_session_return = 0,
        cash_no_position_return = 0,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[g5_wfa_required_amd_ema_oos_session_measurement_columns()]
}

test_that("AMD EMA OOS measurement contract consumes accepted application readiness and registers fields", {
  fixture <- g5_test_amd_ema_measurement_fixture()

  contract <- g5_build_wfa_amd_ema_oos_measurement_contract(
    parameter_application_boundary = fixture$application,
    parameter_application_readiness_review = fixture$application_readiness,
    operator_accepts_application_readiness_review = TRUE
  )
  contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(contract)

  expect_identical(
    names(contract$run_manifest),
    g5_wfa_required_amd_ema_oos_measurement_manifest_columns()
  )
  expect_identical(
    names(contract$field_registry),
    g5_wfa_required_amd_ema_oos_measurement_field_registry_columns()
  )
  expect_identical(
    contract$run_manifest$source_application_boundary_id[[1L]],
    fixture$application$run_manifest$application_boundary_id[[1L]]
  )
  expect_identical(
    contract$run_manifest$allowed_return_fields[[1L]],
    paste(g5_wfa_amd_ema_oos_measurement_allowed_return_fields(), collapse = ";")
  )
  expect_identical(
    contract$run_manifest$trade_return_rule[[1L]],
    "round_trip_entry_next_open_to_exit_next_open_return_no_lookahead"
  )
  expect_identical(
    contract$run_manifest$cash_no_position_return_rule[[1L]],
    "flat_no_position_and_no_trade_cash_return_zero_no_cash_yield"
  )
  expect_identical(
    contract$run_manifest$allowed_metric_fields[[1L]],
    "sharpe_ratio;trade_return_open_to_open;max_drawdown"
  )
})

test_that("AMD EMA OOS measurement contract preserves no-trade and rejects unaccepted sources", {
  fixture <- g5_test_amd_ema_measurement_fixture()

  expect_error(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness
    ),
    "explicit operator acceptance"
  )

  mismatched <- fixture$application_readiness
  mismatched$application_boundary_id[[1L]] <- "other_application_boundary"
  expect_error(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = mismatched,
      operator_accepts_application_readiness_review = TRUE
    ),
    "application_boundary_id"
  )

  expect_error(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      output_dir = "docs/amd_ema_oos_measurement",
      operator_accepts_application_readiness_review = TRUE
    ),
    "ignored runs"
  )

  contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  expect_equal(contract$run_manifest$no_trade_row_count[[1L]], contract$run_manifest$fold_count[[1L]])
  expect_true(all(
    contract$field_registry$out_of_scope_status ==
      "allocation_leverage_live_advice_execution_dashboards_broader_families_performance_claims_not_authorized"
  ))
  expect_true(any(
    contract$field_registry$validation_rule ==
      "must_reference_frozen_application_evidence_missing_rows_are_errors"
  ))
})

test_that("AMD EMA OOS session measurement validator is strict about frozen coverage", {
  fixture <- g5_test_amd_ema_measurement_fixture()
  contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  session_rows <- g5_test_amd_ema_session_measurements(contract, fixture$application)

  validated <- g5_validate_wfa_amd_ema_oos_session_measurements(
    session_measurements = session_rows,
    oos_measurement_contract = contract,
    parameter_application_boundary = fixture$application
  )
  expect_equal(nrow(validated), sum(fixture$application$application_surface$amd_oos_row_count))

  missing_row <- session_rows[-1L, , drop = FALSE]
  expect_error(
    g5_validate_wfa_amd_ema_oos_session_measurements(
      session_measurements = missing_row,
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application
    ),
    "exactly the frozen OOS session count"
  )

  unauthorized <- session_rows
  unauthorized$cagr <- 0
  expect_error(
    g5_validate_wfa_amd_ema_oos_session_measurements(
      session_measurements = unauthorized,
      oos_measurement_contract = contract
    ),
    "unauthorized columns"
  )

  nonzero_no_trade <- session_rows
  first_no_trade <- which(nonzero_no_trade$subject_id == "no_trade_cash")[[1L]]
  nonzero_no_trade$strategy_session_return[[first_no_trade]] <- 0.01
  expect_error(
    g5_validate_wfa_amd_ema_oos_session_measurements(
      session_measurements = nonzero_no_trade,
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application
    ),
    "no-trade rows must carry zero returns"
  )

  unknown_application <- session_rows
  unknown_application$application_row_id[[1L]] <- "unknown_application_row"
  expect_error(
    g5_validate_wfa_amd_ema_oos_session_measurements(
      session_measurements = unknown_application,
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application
    ),
    "unknown application_row_id"
  )
})

test_that("AMD EMA OOS measurement readiness and writers remain contract-only", {
  fixture <- g5_test_amd_ema_measurement_fixture()
  output_dir <- file.path(tempdir(), "runs", "amd_ema_oos_measurement_writer")
  contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      output_dir = output_dir,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  readiness <- g5_build_wfa_amd_ema_oos_measurement_readiness_review(contract)
  readiness <- g5_validate_wfa_amd_ema_oos_measurement_readiness_review(readiness)

  expect_identical(
    names(readiness),
    g5_wfa_required_amd_ema_oos_measurement_readiness_columns()
  )
  expect_identical(
    readiness$return_rule_status[[1L]],
    "session_open_to_close_and_trade_open_to_open_authorized"
  )
  expect_identical(readiness$metric_scope_status[[1L]], "sharpe_trade_return_max_drawdown_only")

  written <- g5_write_wfa_amd_ema_oos_measurement_contract_csvs(contract)
  readiness_path <- g5_write_wfa_amd_ema_oos_measurement_readiness_csv(
    readiness,
    file.path(output_dir, "readiness", "amd_ema_oos_measurement_readiness.csv")
  )

  expect_true(file.exists(written$manifest_path))
  expect_true(file.exists(written$field_registry_path))
  expect_true(file.exists(readiness_path))
  manifest_csv <- utils::read.csv(written$manifest_path, stringsAsFactors = FALSE)
  registry_csv <- utils::read.csv(written$field_registry_path, stringsAsFactors = FALSE)
  readiness_csv <- utils::read.csv(readiness_path, stringsAsFactors = FALSE)
  expect_identical(names(manifest_csv), g5_wfa_required_amd_ema_oos_measurement_manifest_columns())
  expect_identical(names(registry_csv), g5_wfa_required_amd_ema_oos_measurement_field_registry_columns())
  expect_identical(names(readiness_csv), g5_wfa_required_amd_ema_oos_measurement_readiness_columns())

  expect_error(
    g5_write_wfa_amd_ema_oos_measurement_contract_csvs(
      contract,
      manifest_path = file.path(tempdir(), "not_runs", "manifest.csv")
    ),
    "ignored runs"
  )
  expect_error(
    g5_write_wfa_amd_ema_oos_measurement_readiness_csv(
      readiness,
      file.path(tempdir(), "not_runs", "readiness.csv")
    ),
    "ignored runs"
  )
})
