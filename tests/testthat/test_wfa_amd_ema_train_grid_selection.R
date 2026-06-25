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

g5_test_amd_ema_train_grid_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_train_grid_gate_result <- function() {
  g5_wfa_handoff_gate_result(
    gate_status = "PASS",
    manifest_csv = "runs/research_workbench/amd_ema_train_grid/handoff_manifest.csv",
    as_of_timestamp = "2026-04-06 17:00:00",
    latest_completed_session = as.Date("2026-04-06"),
    health_max_severity = "INFO",
    warn_row_count = 0L,
    review_required = FALSE,
    detail = "handoff passed WFA gate"
  )
}

g5_test_amd_ema_train_grid_bars <- function(include_context = FALSE) {
  session_dates <- as.Date(c(
    "2025-12-29", "2025-12-30", "2025-12-31",
    "2026-01-02", "2026-02-02", "2026-03-31",
    "2026-04-01", "2026-04-02", "2026-04-03",
    "2026-04-06"
  ))
  amd <- data.frame(
    symbol = "AMD",
    session_date = session_dates,
    open = seq(100, 109),
    high = seq(101, 110),
    low = seq(99, 108),
    close = c(100, 102, 101, 103, 99, 98, 104, 106, 105, 107),
    volume = seq(1000, 1009),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-04-06 17:00:00",
    latest_completed_session = as.Date("2026-04-06"),
    fetch_start_date = as.Date("2025-12-29"),
    fetch_end_date = as.Date("2026-04-06"),
    data_version_hash = paste0("amd_hash_", seq_along(session_dates)),
    stringsAsFactors = FALSE
  )
  if (!isTRUE(include_context)) {
    return(g5_validate_bar_data(amd))
  }
  spy <- data.frame(
    symbol = "SPY",
    session_date = as.Date(c("2026-01-02", "2026-04-03")),
    open = c(200, 201),
    high = c(201, 202),
    low = c(199, 200),
    close = c(200.5, 201.5),
    volume = c(2000, 2001),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-04-06 17:00:00",
    latest_completed_session = as.Date("2026-04-06"),
    fetch_start_date = as.Date("2025-12-29"),
    fetch_end_date = as.Date("2026-04-06"),
    data_version_hash = c("spy_hash_1", "spy_hash_2"),
    stringsAsFactors = FALSE
  )
  g5_validate_bar_data(rbind(amd, spy))
}

g5_test_amd_ema_train_grid_health <- function() {
  data.frame(
    severity = "INFO",
    category = "row_count",
    symbol = "",
    detail = "query row count: 10",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_train_grid_fixture <- function() {
  gate_result <- g5_test_amd_ema_train_grid_gate_result()
  bars <- g5_test_amd_ema_train_grid_bars()
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
      requested_symbols = "AMD",
      latest_completed_session = as.Date("2026-04-06"),
      requested_start_date = as.Date("2025-12-29"),
      requested_end_date = as.Date("2026-04-06")
    ),
    source_health = g5_test_amd_ema_train_grid_health()
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    code_metadata = g5_test_amd_ema_train_grid_code_metadata()
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
  list(
    bars = bars,
    folds = folds,
    evaluation_contract = evaluation_contract,
    evaluation_readiness = evaluation_readiness
  )
}

test_that("AMD EMA declared TRAIN grid is modest, deterministic, and valid", {
  grid <- g5_wfa_declared_amd_ema_train_grid()

  expect_identical(names(grid), g5_wfa_required_amd_ema_train_grid_columns())
  expect_equal(nrow(grid), 4L)
  expect_true(all(grid$fast_ema_period < grid$slow_ema_period))
  expect_identical(
    grid$grid_scope_status,
    rep("declared_train_only_ema_fast_slow_grid", nrow(grid))
  )

  bad_grid <- grid
  bad_grid$fast_ema_period[[1L]] <- bad_grid$slow_ema_period[[1L]]
  expect_error(
    g5_validate_wfa_amd_ema_train_grid(bad_grid),
    "fast_ema_period < slow_ema_period"
  )
})

test_that("AMD EMA TRAIN grid selection emits selected parameters from TRAIN evidence only", {
  fixture <- g5_test_amd_ema_train_grid_fixture()

  selection <- g5_build_wfa_amd_ema_train_grid_selection(
    evaluation_contract_scaffold = fixture$evaluation_contract,
    evaluation_contract_readiness_review = fixture$evaluation_readiness,
    bars = fixture$bars,
    operator_accepts_readiness_review = TRUE
  )
  selection <- g5_validate_wfa_amd_ema_train_grid_selection(selection)

  expect_identical(
    names(selection$run_manifest),
    g5_wfa_required_amd_ema_train_grid_selection_manifest_columns()
  )
  expect_identical(
    names(selection$train_measurement_surface),
    g5_wfa_required_amd_ema_train_grid_measurement_columns()
  )
  expect_identical(
    names(selection$selected_parameters),
    g5_wfa_required_amd_ema_train_grid_selected_parameter_columns()
  )
  expect_equal(selection$run_manifest$declared_grid_row_count[[1L]], 4L)
  expect_equal(
    selection$run_manifest$train_measurement_row_count[[1L]],
    nrow(fixture$folds) * 5L
  )
  expect_equal(nrow(selection$selected_parameters), nrow(fixture$folds))
  expect_true(all(selection$selected_parameters$selected_grid_id %in% selection$declared_grid$grid_id))
  expect_true(all(selection$selected_parameters$selection_authority_status ==
    "train_only_grid_selected_no_oos_outcome_authority"))
  expect_true(all(selection$selected_parameters$oos_usage_status ==
    "oos_rows_not_read_for_train_grid_selection"))

  for (fold_id in unique(selection$train_measurement_surface$fold_id)) {
    rows <- selection$train_measurement_surface[
      selection$train_measurement_surface$fold_id == fold_id,
      ,
      drop = FALSE
    ]
    expect_identical(rows$subject_id[[1L]], "no_trade_cash")
    expect_identical(rows$comparison_order[[1L]], 1L)
    expect_equal(sum(rows$selected_parameter_flag), 1L)
    expect_true(all(rows$result_status == "not_evaluated_no_oos_results_recorded"))
    expect_true(all(rows$return_computation_status ==
      "not_implemented_no_return_columns_read_or_created"))
  }
})

test_that("AMD EMA TRAIN grid selection is invariant to OOS price mutations", {
  fixture <- g5_test_amd_ema_train_grid_fixture()
  selection <- g5_build_wfa_amd_ema_train_grid_selection(
    evaluation_contract_scaffold = fixture$evaluation_contract,
    evaluation_contract_readiness_review = fixture$evaluation_readiness,
    bars = fixture$bars,
    operator_accepts_readiness_review = TRUE
  )

  mutated_oos <- fixture$bars
  mutated_oos$close[mutated_oos$session_date >= as.Date("2026-01-02")] <- 999
  mutated_oos$data_version_hash <- paste0(mutated_oos$data_version_hash, "_mutated")
  mutated_selection <- g5_build_wfa_amd_ema_train_grid_selection(
    evaluation_contract_scaffold = fixture$evaluation_contract,
    evaluation_contract_readiness_review = fixture$evaluation_readiness,
    bars = mutated_oos,
    operator_accepts_readiness_review = TRUE
  )

  expect_identical(
    selection$selected_parameters[c("fold_id", "selected_grid_id", "fast_ema_period", "slow_ema_period")],
    mutated_selection$selected_parameters[c("fold_id", "selected_grid_id", "fast_ema_period", "slow_ema_period")]
  )
})

test_that("AMD EMA TRAIN grid selection rejects unaccepted, noncanonical, or OOS-tainted inputs", {
  fixture <- g5_test_amd_ema_train_grid_fixture()

  expect_error(
    g5_build_wfa_amd_ema_train_grid_selection(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      bars = fixture$bars
    ),
    "explicit operator acceptance"
  )

  expect_error(
    g5_build_wfa_amd_ema_train_grid_selection(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      bars = g5_test_amd_ema_train_grid_bars(include_context = TRUE),
      operator_accepts_readiness_review = TRUE
    ),
    "AMD bars only"
  )

  wrong_timestamp <- fixture$bars
  wrong_timestamp$as_of_timestamp[[1L]] <- "2026-04-06 16:00:00"
  expect_error(
    g5_build_wfa_amd_ema_train_grid_selection(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      bars = wrong_timestamp,
      operator_accepts_readiness_review = TRUE
    ),
    "frozen as_of_timestamp"
  )

  oos_tainted <- fixture$bars
  oos_tainted$oos_return <- 0
  expect_error(
    g5_build_wfa_amd_ema_train_grid_selection(
      evaluation_contract_scaffold = fixture$evaluation_contract,
      evaluation_contract_readiness_review = fixture$evaluation_readiness,
      bars = oos_tainted,
      operator_accepts_readiness_review = TRUE
    ),
    "OOS-informed"
  )
})

test_that("AMD EMA TRAIN grid selection writers use ignored run paths", {
  fixture <- g5_test_amd_ema_train_grid_fixture()
  output_dir <- file.path(tempdir(), "runs", "amd_ema_train_grid_writer")
  selection <- g5_build_wfa_amd_ema_train_grid_selection(
    evaluation_contract_scaffold = fixture$evaluation_contract,
    evaluation_contract_readiness_review = fixture$evaluation_readiness,
    bars = fixture$bars,
    output_dir = output_dir,
    operator_accepts_readiness_review = TRUE
  )
  written <- g5_write_wfa_amd_ema_train_grid_selection_csvs(selection)

  expect_true(file.exists(written$manifest_path))
  expect_true(file.exists(written$grid_path))
  expect_true(file.exists(written$measurement_path))
  expect_true(file.exists(written$selected_parameter_path))
  expect_identical(
    names(utils::read.csv(written$manifest_path, stringsAsFactors = FALSE)),
    g5_wfa_required_amd_ema_train_grid_selection_manifest_columns()
  )

  expect_error(
    g5_write_wfa_amd_ema_train_grid_selection_csvs(
      selection,
      manifest_path = file.path(tempdir(), "not_runs", "manifest.csv")
    ),
    "ignored runs"
  )
})
