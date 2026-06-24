source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))
source(test_path("..", "..", "R", "wfa_fold_geometry.R"))
source(test_path("..", "..", "R", "wfa_train_oos_split_audit.R"))
source(test_path("..", "..", "R", "wfa_frozen_fold_evidence.R"))
source(test_path("..", "..", "R", "wfa_baseline_registry.R"))
source(test_path("..", "..", "R", "wfa_baseline_evaluation_contract.R"))

g5_test_baseline_contract_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_baseline_contract_gate_result <- function(
  gate_status = "PASS",
  review_required = FALSE
) {
  g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = "runs/research_workbench/baseline_contract/handoff_manifest.csv",
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

g5_test_baseline_contract_bars <- function() {
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

g5_test_baseline_contract_coverage <- function(bars) {
  g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = c("SPY", "QQQ", "NVDA", "EMPTY"),
    latest_completed_session = as.Date("2026-04-03"),
    requested_start_date = as.Date("2025-12-29"),
    requested_end_date = as.Date("2026-04-03")
  )
}

g5_test_baseline_contract_health <- function(include_warn = TRUE) {
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

g5_test_baseline_contract_fixture <- function(
  gate_result = g5_test_baseline_contract_gate_result(),
  accept_review_required = FALSE,
  source_health = g5_test_baseline_contract_health(include_warn = TRUE)
) {
  bars <- g5_test_baseline_contract_bars()
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
    source_symbol_coverage = g5_test_baseline_contract_coverage(bars),
    source_health = source_health,
    accept_review_required = accept_review_required
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    accept_review_required = accept_review_required,
    code_metadata = g5_test_baseline_contract_code_metadata()
  )
  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence,
    accept_review_required = accept_review_required
  )
  list(
    folds = folds,
    audit = audit,
    evidence = evidence,
    registry = registry
  )
}

test_that("baseline evaluation contract scaffold records schema and deterministic placeholders only", {
  gate_result <- g5_test_baseline_contract_gate_result()
  fixture <- g5_test_baseline_contract_fixture(gate_result)

  scaffold <- g5_build_wfa_baseline_evaluation_contract_scaffold(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    frozen_fold_evidence = fixture$evidence,
    baseline_registry = fixture$registry
  )
  scaffold <- g5_validate_wfa_baseline_evaluation_contract_scaffold(scaffold)

  expect_identical(names(scaffold), g5_wfa_required_baseline_evaluation_contract_columns())
  expect_equal(nrow(scaffold), nrow(fixture$folds) * nrow(fixture$registry))
  expect_identical(scaffold$baseline_family_id[[1L]], "no_trade_cash")
  expect_true(all(scaffold$schema_version == g5_wfa_baseline_evaluation_contract_schema_version()))
  expect_false(any(duplicated(scaffold$contract_id)))
  expect_true(all(scaffold$baseline_family_inclusion_status == "all_reserved_families_included_contract_scaffold_only"))
  expect_true(all(scaffold$excluded_reserved_baseline_family_ids == ""))
  expect_true(all(scaffold$excluded_reserved_baseline_review_status == "no_reserved_baseline_family_exclusions_recorded"))
  expect_true(all(grepl("/runs/", scaffold$artifact_path, fixed = TRUE)))
  expect_true(all(grepl("__contract.csv", scaffold$artifact_path, fixed = TRUE)))
  expect_true(all(scaffold$application_status == "not_applied_contract_scaffold_only"))
  expect_true(all(scaffold$evaluation_authorization_status == "not_authorized_no_returns_or_performance"))
  expect_true(all(scaffold$return_computation_status == "not_implemented_no_return_columns_read_or_created"))
  expect_true(all(scaffold$cash_yield_status == "not_implemented_no_cash_yield_assumption"))
  expect_true(all(scaffold$benchmark_math_status == "not_implemented_no_benchmark_math"))
  expect_true(all(scaffold$performance_metric_status == "not_implemented_no_performance_metrics"))
  expect_true(all(scaffold$allocation_status == "not_implemented_no_allocation_or_weighting"))
  expect_true(all(scaffold$active_candidate_status == "not_authorized_no_active_candidate_inputs"))
  expect_true(all(scaffold$leakage_no_provider_calls))
  expect_true(all(scaffold$leakage_no_credentials))
  expect_true(all(scaffold$leakage_no_unmanifested_cache))
  expect_true(all(scaffold$leakage_no_latest_session_inference))
  expect_true(all(scaffold$leakage_no_oos_outcome_authority))
  expect_true(all(scaffold$leakage_no_oos_fitting))
  expect_true(all(scaffold$leakage_no_active_candidate_inputs))
  expect_true(all(scaffold$leakage_no_return_or_metric_computation))
})

test_that("baseline evaluation contract can be limited to no-trade first", {
  gate_result <- g5_test_baseline_contract_gate_result()
  fixture <- g5_test_baseline_contract_fixture(gate_result)

  scaffold <- g5_build_wfa_baseline_evaluation_contract_scaffold(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    frozen_fold_evidence = fixture$evidence,
    baseline_registry = fixture$registry,
    included_baseline_family_ids = "no_trade_cash"
  )

  expect_equal(nrow(scaffold), nrow(fixture$folds))
  expect_true(all(scaffold$baseline_family_id == "no_trade_cash"))
  expect_true(all(scaffold$baseline_family_inclusion_status == "included_in_current_contract_scaffold_with_reserved_family_exclusions"))
  expect_true(all(grepl("broad_market_buy_hold", scaffold$excluded_reserved_baseline_family_ids, fixed = TRUE)))
  expect_true(all(grepl("per_asset_buy_hold", scaffold$excluded_reserved_baseline_family_ids, fixed = TRUE)))
  expect_true(all(scaffold$excluded_reserved_baseline_review_status == "reserved_families_excluded_not_yet_authorized_for_this_slice"))
  expect_true(all(scaffold$cash_no_position_assumption_status == "not_defined_no_cash_yield_or_return_assumption"))
  expect_true(all(grepl("cash_no_position_return_assumption_not_defined", scaffold$review_required_reason)))
  expect_true(all(grepl("reserved_baseline_families_excluded", scaffold$review_required_reason)))

  expect_error(
    g5_build_wfa_baseline_evaluation_contract_scaffold(
      gate_result = gate_result,
      fold_geometry = fixture$folds,
      frozen_fold_evidence = fixture$evidence,
      baseline_registry = fixture$registry,
      included_baseline_family_ids = c("broad_market_buy_hold", "no_trade_cash")
    ),
    "start with no_trade_cash"
  )
  expect_error(
    g5_build_wfa_baseline_evaluation_contract_scaffold(
      gate_result = gate_result,
      fold_geometry = fixture$folds,
      frozen_fold_evidence = fixture$evidence,
      baseline_registry = fixture$registry,
      included_baseline_family_ids = c("no_trade_cash", "no_trade_cash")
    ),
    "must be unique"
  )
})

test_that("baseline evaluation contract requires review acceptance and rejects tainted evidence", {
  review_gate <- g5_test_baseline_contract_gate_result(
    gate_status = "REVIEW_REQUIRED",
    review_required = TRUE
  )
  fixture <- g5_test_baseline_contract_fixture(
    gate_result = review_gate,
    accept_review_required = TRUE
  )

  expect_error(
    g5_build_wfa_baseline_evaluation_contract_scaffold(
      gate_result = review_gate,
      fold_geometry = fixture$folds,
      frozen_fold_evidence = fixture$evidence,
      baseline_registry = fixture$registry
    ),
    "accept_review_required"
  )

  scaffold <- g5_build_wfa_baseline_evaluation_contract_scaffold(
    gate_result = review_gate,
    fold_geometry = fixture$folds,
    frozen_fold_evidence = fixture$evidence,
    baseline_registry = fixture$registry,
    accept_review_required = TRUE
  )
  expect_true(all(scaffold$handoff_review_required))
  expect_true(all(scaffold$handoff_review_accepted))
  expect_true(all(scaffold$review_status == "review_required_before_any_evaluation"))
  expect_true(all(grepl("accepted_source_warning_context", scaffold$review_required_reason)))

  tainted_evidence <- fixture$evidence
  tainted_evidence$oos_performance_evaluated[[1L]] <- TRUE
  expect_error(
    g5_build_wfa_baseline_evaluation_contract_scaffold(
      gate_result = review_gate,
      fold_geometry = fixture$folds,
      frozen_fold_evidence = tainted_evidence,
      baseline_registry = fixture$registry,
      accept_review_required = TRUE
    ),
    "OOS performance"
  )
})

test_that("baseline evaluation contract rejects non-ignored output paths and implementation statuses", {
  gate_result <- g5_test_baseline_contract_gate_result()
  fixture <- g5_test_baseline_contract_fixture(gate_result)

  expect_error(
    g5_build_wfa_baseline_evaluation_contract_scaffold(
      gate_result = gate_result,
      fold_geometry = fixture$folds,
      frozen_fold_evidence = fixture$evidence,
      baseline_registry = fixture$registry,
      output_dir = "docs/baseline_eval_contract"
    ),
    "ignored runs"
  )

  registry <- fixture$registry
  registry$return_computation_status[[1L]] <- "implemented"
  expect_error(
    g5_build_wfa_baseline_evaluation_contract_scaffold(
      gate_result = gate_result,
      fold_geometry = fixture$folds,
      frozen_fold_evidence = fixture$evidence,
      baseline_registry = registry
    ),
    "return-enabled"
  )
})
