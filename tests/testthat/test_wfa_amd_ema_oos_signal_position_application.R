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
source(test_path("..", "..", "R", "wfa_amd_ema_oos_signal_position_application.R"))

g5_test_amd_ema_signal_position_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_signal_position_gate_result <- function() {
  g5_wfa_handoff_gate_result(
    gate_status = "PASS",
    manifest_csv = "runs/research_workbench/amd_ema_signal_position/handoff_manifest.csv",
    as_of_timestamp = "2026-04-06 17:00:00",
    latest_completed_session = as.Date("2026-04-06"),
    health_max_severity = "INFO",
    warn_row_count = 0L,
    review_required = FALSE,
    detail = "handoff passed WFA gate"
  )
}

g5_test_amd_ema_signal_position_bars <- function() {
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
  spy_dates <- as.Date(c("2026-01-02", "2026-02-02", "2026-03-31", "2026-04-01", "2026-04-03"))
  spy <- data.frame(
    symbol = "SPY",
    session_date = spy_dates,
    open = seq(200, 204),
    high = seq(201, 205),
    low = seq(199, 203),
    close = seq(200.5, 204.5),
    volume = seq(2000, 2004),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-04-06 17:00:00",
    latest_completed_session = as.Date("2026-04-06"),
    fetch_start_date = as.Date("2025-12-29"),
    fetch_end_date = as.Date("2026-04-06"),
    data_version_hash = paste0("spy_hash_", seq_along(spy_dates)),
    stringsAsFactors = FALSE
  )
  qqq_dates <- as.Date(c("2025-12-29", "2026-01-02", "2026-04-06"))
  qqq <- data.frame(
    symbol = "QQQ",
    session_date = qqq_dates,
    open = seq(300, 302),
    high = seq(301, 303),
    low = seq(299, 301),
    close = seq(300.5, 302.5),
    volume = seq(3000, 3002),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-04-06 17:00:00",
    latest_completed_session = as.Date("2026-04-06"),
    fetch_start_date = as.Date("2025-12-29"),
    fetch_end_date = as.Date("2026-04-06"),
    data_version_hash = paste0("qqq_hash_", seq_along(qqq_dates)),
    stringsAsFactors = FALSE
  )
  g5_validate_bar_data(rbind(amd, spy, qqq))
}

g5_test_amd_ema_signal_position_health <- function() {
  data.frame(
    severity = "INFO",
    category = "row_count",
    symbol = "",
    detail = "query row count: 18",
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_signal_position_parameter_decisions <- function(evaluation_contract) {
  amd_rows <- evaluation_contract$review_surface[
    evaluation_contract$review_surface$subject_id == "amd_ema_long_cash",
    ,
    drop = FALSE
  ]
  data.frame(
    fold_id = as.character(amd_rows$fold_id),
    fast_ema_period = rep(2L, nrow(amd_rows)),
    slow_ema_period = rep(3L, nrow(amd_rows)),
    parameter_source = rep("operator_accepted_train_only_amd_ema_review", nrow(amd_rows)),
    selection_authority_status = rep(
      "train_only_operator_accepted_no_oos_outcome_authority",
      nrow(amd_rows)
    ),
    stringsAsFactors = FALSE
  )
}

g5_test_amd_ema_signal_position_fixture <- function(output_dir = NULL) {
  gate_result <- g5_test_amd_ema_signal_position_gate_result()
  bars <- g5_test_amd_ema_signal_position_bars()
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
    source_health = g5_test_amd_ema_signal_position_health()
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    code_metadata = g5_test_amd_ema_signal_position_code_metadata()
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
    parameter_decisions = g5_test_amd_ema_signal_position_parameter_decisions(evaluation_contract),
    operator_accepts_readiness_review = TRUE
  )
  freeze_readiness <- g5_build_wfa_amd_ema_parameter_freeze_readiness_review(freeze)
  application_args <- list(
    parameter_freeze_contract = freeze,
    parameter_freeze_readiness_review = freeze_readiness,
    operator_accepts_freeze_readiness_review = TRUE
  )
  if (!is.null(output_dir)) {
    application_args$output_dir <- output_dir
  }
  application <- do.call(g5_build_wfa_amd_ema_parameter_application_boundary, application_args)
  application_readiness <- g5_build_wfa_amd_ema_parameter_application_readiness_review(application)
  list(
    bars = bars,
    application = application,
    application_readiness = application_readiness
  )
}

test_that("AMD EMA OOS signal/position application emits session evidence from frozen parameters", {
  fixture <- g5_test_amd_ema_signal_position_fixture()

  signal_position <- g5_build_wfa_amd_ema_oos_signal_position_application(
    parameter_application_boundary = fixture$application,
    parameter_application_readiness_review = fixture$application_readiness,
    bars = fixture$bars,
    operator_accepts_application_readiness_review = TRUE
  )
  signal_position <- g5_validate_wfa_amd_ema_oos_signal_position_application(signal_position)

  expect_identical(
    names(signal_position$run_manifest),
    g5_wfa_required_amd_ema_oos_signal_position_manifest_columns()
  )
  expect_identical(
    names(signal_position$signal_position_surface),
    g5_wfa_required_amd_ema_oos_signal_position_surface_columns()
  )
  expect_identical(
    signal_position$run_manifest$source_application_boundary_id[[1L]],
    fixture$application$run_manifest$application_boundary_id[[1L]]
  )
  expect_identical(
    signal_position$run_manifest$ema_signal_status[[1L]],
    "computed_from_already_frozen_ema_parameters_no_returns"
  )
  expect_equal(
    signal_position$run_manifest$candidate_signal_row_count[[1L]],
    sum(fixture$application$application_surface$amd_oos_row_count[
      fixture$application$application_surface$subject_id == "amd_ema_long_cash"
    ])
  )
})

test_that("AMD EMA OOS signal/position preserves no-trade first and next-session chronology", {
  fixture <- g5_test_amd_ema_signal_position_fixture()
  signal_position <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = fixture$bars,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  surface <- signal_position$signal_position_surface

  for (key in unique(paste(surface$fold_id, surface$session_date))) {
    rows <- surface[paste(surface$fold_id, surface$session_date) == key, , drop = FALSE]
    expect_identical(rows$comparison_order, c(1L, 2L))
    expect_identical(rows$subject_id, c("no_trade_cash", "amd_ema_long_cash"))
    expect_equal(rows$session_date[[1L]], rows$signal_generated_after_close_date[[1L]])
    expect_gt(as.Date(rows$next_open_session_date[[1L]]), as.Date(rows$session_date[[1L]]))
  }
  no_trade <- surface[surface$subject_id == "no_trade_cash", , drop = FALSE]
  candidate <- surface[surface$subject_id == "amd_ema_long_cash", , drop = FALSE]
  expect_true(all(no_trade$ema_signal_state == "no_trade_cash"))
  expect_true(all(no_trade$position_state_for_next_open == "no_position"))
  expect_true(all(is.na(no_trade$fast_ema_value)))
  expect_true(all(candidate$ema_signal_state %in% c("long_signal", "cash_signal")))
  expect_true(all(candidate$position_state_for_next_open %in% c("long", "cash")))
  expect_true(all(is.finite(candidate$fast_ema_value)))
  expect_true(all(is.finite(candidate$slow_ema_value)))

  final_session <- surface[
    surface$subject_id == "amd_ema_long_cash" &
      surface$session_date == as.Date("2026-04-03"),
    ,
    drop = FALSE
  ]
  expect_identical(as.Date(final_session$next_open_session_date[[1L]]), as.Date("2026-04-06"))
})

test_that("AMD EMA OOS signal/position rejects missing rows, duplicate bars, and ambiguous next sessions", {
  fixture <- g5_test_amd_ema_signal_position_fixture()

  expect_error(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = fixture$bars
    ),
    "explicit operator acceptance"
  )

  missing_oos <- fixture$bars[
    !(fixture$bars$symbol == "AMD" & fixture$bars$session_date == as.Date("2026-04-02")),
    ,
    drop = FALSE
  ]
  expect_error(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = missing_oos,
      operator_accepts_application_readiness_review = TRUE
    ),
    "missing frozen application rows"
  )

  duplicate_bars <- rbind(fixture$bars, fixture$bars[fixture$bars$symbol == "AMD", , drop = FALSE][1L, ])
  expect_error(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = duplicate_bars,
      operator_accepts_application_readiness_review = TRUE
    ),
    "Duplicate symbol/session_date"
  )

  missing_next_session <- fixture$bars[
    !(fixture$bars$symbol == "AMD" & fixture$bars$session_date == as.Date("2026-04-06")),
    ,
    drop = FALSE
  ]
  expect_error(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = missing_next_session,
      operator_accepts_application_readiness_review = TRUE
    ),
    "ambiguous execution dates"
  )

  wrong_timestamp <- fixture$bars
  wrong_timestamp$as_of_timestamp[wrong_timestamp$symbol == "AMD"] <- "2026-04-06 16:00:00"
  expect_error(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = wrong_timestamp,
      operator_accepts_application_readiness_review = TRUE
    ),
    "frozen as_of_timestamp"
  )
})

test_that("AMD EMA OOS signal/position rejects result-like mutation and non-ignored outputs", {
  fixture <- g5_test_amd_ema_signal_position_fixture()

  expect_error(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = fixture$bars,
      output_dir = "docs/amd_ema_signal_position",
      operator_accepts_application_readiness_review = TRUE
    ),
    "ignored runs"
  )

  signal_position <- g5_build_wfa_amd_ema_oos_signal_position_application(
    parameter_application_boundary = fixture$application,
    parameter_application_readiness_review = fixture$application_readiness,
    bars = fixture$bars,
    operator_accepts_application_readiness_review = TRUE
  )
  result_like <- signal_position
  result_like$signal_position_surface$strategy_session_return <- 0
  expect_error(
    g5_validate_wfa_amd_ema_oos_signal_position_application(result_like),
    "return, PnL, metric"
  )

  unauthorized <- signal_position
  unauthorized$signal_position_surface$execution_status[[1L]] <- "filled"
  expect_error(
    g5_validate_wfa_amd_ema_oos_signal_position_application(unauthorized),
    "execution_status"
  )
})

test_that("AMD EMA OOS signal/position readiness and writers remain result-free", {
  output_dir <- file.path(tempdir(), "runs", "amd_ema_signal_position_writer")
  fixture <- g5_test_amd_ema_signal_position_fixture(output_dir = output_dir)
  signal_position <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    g5_build_wfa_amd_ema_oos_signal_position_application(
      parameter_application_boundary = fixture$application,
      parameter_application_readiness_review = fixture$application_readiness,
      bars = fixture$bars,
      output_dir = output_dir,
      operator_accepts_application_readiness_review = TRUE
    )
  )
  readiness <- g5_build_wfa_amd_ema_oos_signal_position_readiness_review(signal_position)
  readiness <- g5_validate_wfa_amd_ema_oos_signal_position_readiness_review(readiness)

  expect_identical(
    names(readiness),
    g5_wfa_required_amd_ema_oos_signal_position_readiness_columns()
  )
  expect_identical(
    readiness$calculation_stop_status[[1L]],
    "returns_cash_yield_trade_accounting_benchmark_math_metrics_all_not_computed"
  )
  expect_identical(
    readiness$out_of_scope_status[[1L]],
    "allocation_leverage_live_advice_execution_dashboards_broader_families_performance_claims_not_authorized"
  )

  written <- g5_write_wfa_amd_ema_oos_signal_position_application_csvs(signal_position)
  readiness_path <- g5_write_wfa_amd_ema_oos_signal_position_readiness_csv(
    readiness,
    file.path(output_dir, "readiness", "amd_ema_oos_signal_position_readiness.csv")
  )

  expect_true(file.exists(written$manifest_path))
  expect_true(file.exists(written$signal_position_surface_path))
  expect_true(file.exists(readiness_path))
  manifest_csv <- utils::read.csv(written$manifest_path, stringsAsFactors = FALSE)
  surface_csv <- utils::read.csv(written$signal_position_surface_path, stringsAsFactors = FALSE)
  readiness_csv <- utils::read.csv(readiness_path, stringsAsFactors = FALSE)
  expect_identical(names(manifest_csv), g5_wfa_required_amd_ema_oos_signal_position_manifest_columns())
  expect_identical(names(surface_csv), g5_wfa_required_amd_ema_oos_signal_position_surface_columns())
  expect_identical(names(readiness_csv), g5_wfa_required_amd_ema_oos_signal_position_readiness_columns())

  expect_error(
    g5_write_wfa_amd_ema_oos_signal_position_application_csvs(
      signal_position,
      manifest_path = file.path(tempdir(), "not_runs", "manifest.csv")
    ),
    "ignored runs"
  )
  expect_error(
    g5_write_wfa_amd_ema_oos_signal_position_readiness_csv(
      readiness,
      file.path(tempdir(), "not_runs", "readiness.csv")
    ),
    "ignored runs"
  )
})
