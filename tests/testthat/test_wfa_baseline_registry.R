source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))
source(test_path("..", "..", "R", "wfa_fold_geometry.R"))
source(test_path("..", "..", "R", "wfa_train_oos_split_audit.R"))
source(test_path("..", "..", "R", "wfa_frozen_fold_evidence.R"))
source(test_path("..", "..", "R", "wfa_baseline_registry.R"))

g5_test_baseline_code_metadata <- function() {
  data.frame(
    code_git_sha = "abc1234",
    code_git_branch = "codex/test-branch",
    code_metadata_status = "git_metadata_recorded",
    stringsAsFactors = FALSE
  )
}

g5_test_baseline_gate_result <- function(
  gate_status = "PASS",
  review_required = FALSE
) {
  g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = "runs/research_workbench/demo/handoff_manifest.csv",
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

g5_test_baseline_bars <- function() {
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

g5_test_baseline_coverage <- function(bars) {
  g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = c("SPY", "QQQ", "NVDA", "EMPTY"),
    latest_completed_session = as.Date("2026-04-03"),
    requested_start_date = as.Date("2025-12-29"),
    requested_end_date = as.Date("2026-04-03")
  )
}

g5_test_baseline_health <- function() {
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

g5_test_baseline_fixture <- function(
  gate_result = g5_test_baseline_gate_result(),
  accept_review_required = FALSE
) {
  bars <- g5_test_baseline_bars()
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
    source_symbol_coverage = g5_test_baseline_coverage(bars),
    source_health = g5_test_baseline_health(),
    accept_review_required = accept_review_required
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = audit,
    accept_review_required = accept_review_required,
    code_metadata = g5_test_baseline_code_metadata()
  )
  list(folds = folds, audit = audit, evidence = evidence)
}

test_that("baseline registry reserves declarative family definitions only", {
  gate_result <- g5_test_baseline_gate_result()
  fixture <- g5_test_baseline_fixture(gate_result)

  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    frozen_fold_evidence = fixture$evidence
  )

  expect_identical(names(registry), g5_wfa_required_baseline_registry_columns())
  expect_identical(
    registry$baseline_family_id,
    c(
      "no_trade_cash",
      "broad_market_buy_hold",
      "per_asset_buy_hold",
      "fixed_equal_weight_basket_buy_hold",
      "active_curation_no_timing"
    )
  )
  expect_setequal(
    registry$diagnostic_group,
    c("core", "asset_level", "basket", "curation")
  )
  expect_true(all(registry$baseline_family_status == "reserved_declarative_only_no_returns_or_performance"))
  expect_true(all(registry$return_computation_status == "not_implemented_no_return_columns_read_or_created"))
  expect_true(all(registry$performance_evaluation_status == "not_implemented_no_benchmark_performance_computed"))
  expect_true(all(registry$allocation_status == "not_implemented_no_allocation_or_weighting"))
  expect_true(all(grepl("no_oos_selection", registry$asset_selection_status, fixed = TRUE)))
  expect_true(all(registry$uses_same_fold_calendar))
  expect_true(all(registry$requires_accepted_handoff_gate))
  expect_true(all(registry$uses_same_health_gate))
  expect_true(all(registry$uses_same_train_oos_audit))
  expect_true(all(registry$uses_frozen_fold_evidence))
  expect_equal(unique(registry$fold_count), nrow(fixture$folds))
  expect_identical(unique(registry$first_fold_id), "fold_0001")
  expect_identical(unique(registry$last_fold_id), "fold_0002")
  expect_false(any(registry$handoff_review_required))
  expect_false(any(registry$handoff_review_accepted))
})

test_that("baseline registry requires review acceptance and frozen no-active evidence", {
  review_gate <- g5_test_baseline_gate_result(
    gate_status = "REVIEW_REQUIRED",
    review_required = TRUE
  )
  fixture <- g5_test_baseline_fixture(
    gate_result = review_gate,
    accept_review_required = TRUE
  )

  expect_error(
    g5_build_wfa_baseline_family_registry(
      gate_result = review_gate,
      fold_geometry = fixture$folds,
      frozen_fold_evidence = fixture$evidence
    ),
    "accept_review_required"
  )

  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = review_gate,
    fold_geometry = fixture$folds,
    frozen_fold_evidence = fixture$evidence,
    accept_review_required = TRUE
  )
  expect_true(all(registry$handoff_review_required))
  expect_true(all(registry$handoff_review_accepted))

  tainted_evidence <- fixture$evidence
  tainted_evidence$oos_performance_evaluated[[1L]] <- TRUE
  expect_error(
    g5_build_wfa_baseline_family_registry(
      gate_result = review_gate,
      fold_geometry = fixture$folds,
      frozen_fold_evidence = tainted_evidence,
      accept_review_required = TRUE
    ),
    "OOS performance"
  )
})

test_that("baseline registry writer defaults to ignored run paths", {
  gate_result <- g5_test_baseline_gate_result()
  fixture <- g5_test_baseline_fixture(gate_result)
  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = gate_result,
    fold_geometry = fixture$folds,
    frozen_fold_evidence = fixture$evidence
  )

  temp_csv <- tempfile("baseline_registry_", fileext = ".csv")
  expect_error(
    g5_write_wfa_baseline_family_registry_csv(registry, temp_csv),
    "ignored runs"
  )

  run_csv <- file.path("runs", "wfa_foundation_test", "baseline_family_registry.csv")
  written <- g5_write_wfa_baseline_family_registry_csv(registry, run_csv)
  expect_true(file.exists(written))
  read_back <- utils::read.csv(written, stringsAsFactors = FALSE, check.names = FALSE)
  expect_identical(names(read_back), names(registry))
})
