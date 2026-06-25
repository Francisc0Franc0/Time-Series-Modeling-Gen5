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
source(test_path("..", "..", "R", "wfa_amd_ema_train_grid_selection.R"))
source(test_path("..", "..", "R", "wfa_amd_ema_parameter_freeze_contract.R"))
source(test_path("..", "..", "R", "wfa_amd_ema_parameter_application_boundary.R"))
source(test_path("..", "..", "R", "wfa_amd_ema_oos_signal_position_application.R"))
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
    as_of_timestamp = "2026-04-06 17:00:00",
    latest_completed_session = as.Date("2026-04-06"),
    health_max_severity = "INFO",
    warn_row_count = 0L,
    review_required = FALSE,
    detail = "handoff passed WFA gate"
  )
}

g5_test_amd_ema_measurement_bars <- function() {
  g5_validate_bar_data(data.frame(
    symbol = c(
      rep("AMD", 10L),
      rep("SPY", 5L),
      rep("QQQ", 2L)
    ),
    session_date = as.Date(c(
      "2025-12-29", "2025-12-30", "2025-12-31",
      "2026-01-02", "2026-02-02", "2026-03-31",
      "2026-04-01", "2026-04-02", "2026-04-03",
      "2026-04-06",
      "2026-01-02", "2026-02-02", "2026-03-31",
      "2026-04-01", "2026-04-03",
      "2025-12-29", "2026-01-02"
    )),
    open = seq(100, 116),
    high = seq(101, 117),
    low = seq(99, 115),
    close = seq(100.5, 116.5),
    volume = seq(1000, 1016),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-04-06 17:00:00",
    latest_completed_session = as.Date("2026-04-06"),
    fetch_start_date = as.Date("2025-12-29"),
    fetch_end_date = as.Date("2026-04-06"),
    data_version_hash = paste0("hash_", seq_len(17L)),
    stringsAsFactors = FALSE
  ))
}

g5_test_amd_ema_measurement_health <- function() {
  data.frame(
    severity = "INFO",
    category = "row_count",
    symbol = "",
    detail = "query row count: 17",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_measurement_parameter_decisions <- function(evaluation_contract, evaluation_readiness, bars) {
  amd_bars <- bars[
    as.character(bars$symbol) == "AMD",
    ,
    drop = FALSE
  ]
  selection <- g5_build_wfa_amd_ema_train_grid_selection(
    evaluation_contract_scaffold = evaluation_contract,
    evaluation_contract_readiness_review = evaluation_readiness,
    bars = amd_bars,
    operator_accepts_readiness_review = TRUE
  )
  selection$selected_parameters
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
      latest_completed_session = as.Date("2026-04-06"),
      requested_start_date = as.Date("2025-12-29"),
      requested_end_date = as.Date("2026-04-06")
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
  train_selection <- g5_build_wfa_amd_ema_train_grid_selection(
    evaluation_contract_scaffold = evaluation_contract,
    evaluation_contract_readiness_review = evaluation_readiness,
    bars = bars[bars$symbol == "AMD", , drop = FALSE],
    operator_accepts_readiness_review = TRUE
  )
  freeze <- g5_build_wfa_amd_ema_parameter_freeze_contract(
    evaluation_contract_scaffold = evaluation_contract,
    evaluation_contract_readiness_review = evaluation_readiness,
    parameter_decisions = train_selection$selected_parameters,
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
    bars = bars,
    train_selection = train_selection,
    freeze = freeze,
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

g5_test_amd_ema_trade_lifecycle_signal_position <- function(signal_position) {
  surface <- signal_position$signal_position_surface
  candidate_index <- which(surface$subject_id == "amd_ema_long_cash")
  transition_states <- c("cash", "long", "long", "cash", "long", "cash")
  transition_signals <- ifelse(transition_states == "long", "long_signal", "cash_signal")
  surface$position_state_for_next_open[candidate_index] <- transition_states
  surface$ema_signal_state[candidate_index] <- transition_signals
  signal_position$signal_position_surface <- surface
  g5_validate_wfa_amd_ema_oos_signal_position_application(signal_position)
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

test_that("AMD EMA OOS session measurement values consume frozen signal/position evidence", {
  fixture <- g5_test_amd_ema_measurement_fixture()
  contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  signal_position <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = fixture$bars,
      operator_accepts_application_readiness_review = TRUE
    )
  )

  session_values <- g5_build_wfa_amd_ema_oos_session_measurement_values(
    oos_measurement_contract = contract,
    signal_position_application = signal_position,
    bars = fixture$bars,
    parameter_application_boundary = fixture$application
  )

  expect_identical(names(session_values), g5_wfa_required_amd_ema_oos_session_measurement_columns())
  expect_equal(nrow(session_values), nrow(signal_position$signal_position_surface))
  expect_identical(
    session_values$application_row_id,
    signal_position$signal_position_surface$source_application_row_id
  )
  expect_identical(
    as.character(session_values$as_of_timestamp),
    as.character(signal_position$signal_position_surface$as_of_timestamp)
  )

  no_trade <- session_values$subject_id == "no_trade_cash"
  expect_true(all(session_values$comparison_order[no_trade] == 1L))
  expect_true(all(session_values$position_state[no_trade] == "no_position"))
  expect_true(all(session_values$asset_session_return_open_to_close[no_trade] == 0))
  expect_true(all(session_values$strategy_session_return[no_trade] == 0))
  expect_true(all(session_values$no_trade_session_return == 0))
  expect_true(all(session_values$cash_no_position_return == 0))

  candidate <- session_values$subject_id == "amd_ema_long_cash"
  candidate_rows <- session_values[candidate, , drop = FALSE]
  amd_bars <- fixture$bars[fixture$bars$symbol == "AMD", , drop = FALSE]
  expected_asset_returns <- setNames(
    as.numeric(amd_bars$close) / as.numeric(amd_bars$open) - 1,
    as.character(as.Date(amd_bars$session_date))
  )
  expected_candidate_returns <- unname(expected_asset_returns[
    as.character(as.Date(candidate_rows$session_date))
  ])
  expect_equal(candidate_rows$asset_session_return_open_to_close, expected_candidate_returns)
  expect_equal(
    candidate_rows$strategy_session_return,
    ifelse(candidate_rows$position_state == "long", expected_candidate_returns, 0)
  )
  expect_true(all(candidate_rows$measurement_status %in% c("measured", "flat_no_position")))

  missing_bar <- fixture$bars[
    !(fixture$bars$symbol == "AMD" & fixture$bars$session_date == as.Date("2026-04-02")),
    ,
    drop = FALSE
  ]
  expect_error(
    g5_build_wfa_amd_ema_oos_session_measurement_values(
      oos_measurement_contract = contract,
      signal_position_application = signal_position,
      bars = missing_bar,
      parameter_application_boundary = fixture$application
    ),
    "missing canonical AMD bars"
  )

  missing_signal <- signal_position
  missing_signal$signal_position_surface <- missing_signal$signal_position_surface[-1L, , drop = FALSE]
  expect_error(
    g5_build_wfa_amd_ema_oos_session_measurement_values(
      oos_measurement_contract = contract,
      signal_position_application = missing_signal,
      bars = fixture$bars,
      parameter_application_boundary = fixture$application
    ),
    "no_trade first"
  )
})

test_that("AMD EMA OOS trade lifecycle scaffold records signal-position transitions only", {
  fixture <- g5_test_amd_ema_measurement_fixture()
  contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  signal_position <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = fixture$bars,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  signal_position <- g5_test_amd_ema_trade_lifecycle_signal_position(signal_position)

  lifecycle <- g5_build_wfa_amd_ema_oos_trade_lifecycle_measurements(
    oos_measurement_contract = contract,
    signal_position_application = signal_position,
    parameter_application_boundary = fixture$application
  )

  expect_identical(names(lifecycle), g5_wfa_required_amd_ema_oos_trade_measurement_columns())
  expect_equal(nrow(lifecycle), 2L)
  expect_identical(
    lifecycle$trade_status,
    c("open_trade_unclosed", "closed_trade_lifecycle")
  )
  expect_identical(lifecycle$position_state, rep("long", 2L))
  expect_identical(
    as.Date(lifecycle$entry_signal_session_date),
    as.Date(c("2026-02-02", "2026-04-02"))
  )
  expect_identical(
    as.Date(lifecycle$entry_execution_session_date),
    as.Date(c("2026-03-31", "2026-04-03"))
  )
  expect_identical(
    as.Date(lifecycle$exit_signal_session_date),
    as.Date(c(NA, "2026-04-03"))
  )
  expect_identical(
    as.Date(lifecycle$exit_execution_session_date),
    as.Date(c(NA, "2026-04-06"))
  )
  expect_identical(as.integer(lifecycle$holding_period_sessions), c(NA_integer_, 1L))
  expect_true(all(is.na(lifecycle$share_quantity)))
  expect_true(all(is.na(lifecycle$trade_pnl)))
  expect_true(all(is.na(lifecycle$trade_return_open_to_open)))

  with_quantity <- lifecycle
  with_quantity$share_quantity[[1L]] <- 1
  expect_error(
    g5_validate_wfa_amd_ema_oos_trade_lifecycle_measurements(
      trade_measurements = with_quantity,
      oos_measurement_contract = contract,
      signal_position_application = signal_position,
      parameter_application_boundary = fixture$application
    ),
    "must not compute share quantity"
  )

  unknown_application <- lifecycle
  unknown_application$application_row_id[[1L]] <- "unknown_application_row"
  expect_error(
    g5_validate_wfa_amd_ema_oos_trade_lifecycle_measurements(
      trade_measurements = unknown_application,
      oos_measurement_contract = contract,
      signal_position_application = signal_position,
      parameter_application_boundary = fixture$application
    ),
    "unknown application_row_id"
  )
})

test_that("AMD EMA OOS measurement stack validator enforces cross-surface lineage and coverage", {
  fixture <- g5_test_amd_ema_measurement_fixture()
  contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    g5_build_wfa_amd_ema_oos_measurement_contract(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  signal_position <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = fixture$bars,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  signal_position <- g5_test_amd_ema_trade_lifecycle_signal_position(signal_position)
  session_values <- g5_build_wfa_amd_ema_oos_session_measurement_values(
    oos_measurement_contract = contract,
    signal_position_application = signal_position,
    bars = fixture$bars,
    parameter_application_boundary = fixture$application
  )
  lifecycle <- g5_build_wfa_amd_ema_oos_trade_lifecycle_measurements(
    oos_measurement_contract = contract,
    signal_position_application = signal_position,
    parameter_application_boundary = fixture$application
  )

  expect_silent(g5_validate_wfa_amd_ema_oos_measurement_stack(
    oos_measurement_contract = contract,
    parameter_application_boundary = fixture$application,
    signal_position_application = signal_position,
    session_measurements = session_values,
    trade_lifecycle_measurements = lifecycle,
    bars = fixture$bars,
    train_grid_selection = fixture$train_selection
  ))

  bad_timestamp <- session_values
  bad_timestamp$as_of_timestamp[[1L]] <- "2026-04-06 16:00:00"
  expect_error(
    g5_validate_wfa_amd_ema_oos_measurement_stack(
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application,
      signal_position_application = signal_position,
      session_measurements = bad_timestamp,
      trade_lifecycle_measurements = lifecycle,
      bars = fixture$bars,
      train_grid_selection = fixture$train_selection
    ),
    "explicit as_of_timestamp"
  )

  missing_session <- session_values[-1L, , drop = FALSE]
  expect_error(
    g5_validate_wfa_amd_ema_oos_measurement_stack(
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application,
      signal_position_application = signal_position,
      session_measurements = missing_session,
      trade_lifecycle_measurements = lifecycle,
      bars = fixture$bars,
      train_grid_selection = fixture$train_selection
    ),
    "exactly the frozen OOS session count"
  )

  noncanonical_bars <- fixture$bars
  noncanonical_bars$provider[noncanonical_bars$symbol == "AMD"] <- "other"
  expect_error(
    g5_validate_wfa_amd_ema_oos_measurement_stack(
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application,
      signal_position_application = signal_position,
      session_measurements = session_values,
      trade_lifecycle_measurements = lifecycle,
      bars = noncanonical_bars,
      train_grid_selection = fixture$train_selection
    ),
    "Alpaca adjusted daily OHLCV"
  )

  bad_pack <- session_values
  candidate_index <- which(bad_pack$subject_id == "amd_ema_long_cash")[[1L]]
  bad_pack$parameter_pack_id[[candidate_index]] <- "manual_fixture_pack"
  expect_error(
    g5_validate_wfa_amd_ema_oos_measurement_stack(
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application,
      signal_position_application = signal_position,
      session_measurements = bad_pack,
      trade_lifecycle_measurements = lifecycle,
      bars = fixture$bars,
      train_grid_selection = fixture$train_selection
    ),
    "selected TRAIN-frozen parameter packs|selected parameter lineage"
  )

  bad_lifecycle <- lifecycle
  bad_lifecycle$parameter_pack_id[[1L]] <- "manual_fixture_pack"
  expect_error(
    g5_validate_wfa_amd_ema_oos_measurement_stack(
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application,
      signal_position_application = signal_position,
      session_measurements = session_values,
      trade_lifecycle_measurements = bad_lifecycle,
      bars = fixture$bars,
      train_grid_selection = fixture$train_selection
    ),
    "selected TRAIN-frozen parameter packs"
  )

  oos_usage_drift <- fixture$train_selection
  oos_usage_drift$selected_parameters$oos_usage_status[[1L]] <- "oos_rows_used_for_selection"
  expect_error(
    g5_validate_wfa_amd_ema_oos_measurement_stack(
      oos_measurement_contract = contract,
      parameter_application_boundary = fixture$application,
      signal_position_application = signal_position,
      session_measurements = session_values,
      trade_lifecycle_measurements = lifecycle,
      bars = fixture$bars,
      train_grid_selection = oos_usage_drift
    ),
    "OOS rows were not read|no OOS selection authority"
  )
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
