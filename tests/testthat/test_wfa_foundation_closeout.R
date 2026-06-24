source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "data_audit.R"))
source(test_path("..", "..", "R", "wfa_handoff_gate.R"))
source(test_path("..", "..", "R", "wfa_fold_geometry.R"))
source(test_path("..", "..", "R", "wfa_train_oos_split_audit.R"))
source(test_path("..", "..", "R", "wfa_frozen_fold_evidence.R"))
source(test_path("..", "..", "R", "wfa_baseline_registry.R"))

g5_test_closeout_gate_result <- function() {
  g5_wfa_handoff_gate_result(
    gate_status = "PASS",
    manifest_csv = "runs/research_workbench/closeout/handoff_manifest.csv",
    as_of_timestamp = "2026-06-30 17:00:00",
    latest_completed_session = as.Date("2026-06-30"),
    health_max_severity = "INFO",
    warn_row_count = 0L,
    review_required = FALSE,
    detail = "handoff passed WFA gate"
  )
}

g5_test_closeout_bars <- function() {
  sessions <- as.Date(c(
    "2025-10-01", "2025-12-31",
    "2026-01-02", "2026-03-31",
    "2026-04-01", "2026-06-30"
  ))
  rows <- expand.grid(
    symbol = c("SPY", "QQQ"),
    session_date = sessions,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows <- rows[order(rows$symbol, rows$session_date), , drop = FALSE]
  rownames(rows) <- NULL
  row_count <- nrow(rows)

  g5_validate_bar_data(data.frame(
    symbol = rows$symbol,
    session_date = rows$session_date,
    open = seq(100, 100 + row_count - 1L),
    high = seq(101, 101 + row_count - 1L),
    low = seq(99, 99 + row_count - 1L),
    close = seq(100.5, 100.5 + row_count - 1L),
    volume = seq(1000, 1000 + row_count - 1L),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-30 17:00:00",
    latest_completed_session = as.Date("2026-06-30"),
    fetch_start_date = as.Date("2025-10-01"),
    fetch_end_date = as.Date("2026-06-30"),
    data_version_hash = paste0("closeout_hash_", seq_len(row_count)),
    stringsAsFactors = FALSE
  ))
}

test_that("minimal WFA foundation closeout scaffolds align with the contract", {
  gate_result <- g5_test_closeout_gate_result()
  bars <- g5_test_closeout_bars()
  health <- data.frame(
    severity = "INFO",
    category = "row_count",
    symbol = "",
    detail = paste("query row count:", nrow(bars)),
    stringsAsFactors = FALSE
  )
  coverage <- g5_symbol_coverage_artifact(
    bars = bars,
    requested_symbols = c("SPY", "QQQ"),
    latest_completed_session = as.Date("2026-06-30"),
    requested_start_date = as.Date("2025-10-01"),
    requested_end_date = as.Date("2026-06-30")
  )

  folds <- g5_build_quarterly_fold_geometry(
    gate_result = gate_result,
    train_start_date = as.Date("2025-10-01"),
    first_oos_start_date = as.Date("2026-01-01"),
    final_oos_end_date = as.Date("2026-06-30")
  )
  split_audit <- g5_build_wfa_train_oos_split_audit(
    gate_result = gate_result,
    bars = bars,
    fold_geometry = folds,
    source_symbol_coverage = coverage,
    source_health = health
  )
  evidence <- g5_build_wfa_frozen_fold_evidence(
    gate_result = gate_result,
    fold_geometry = folds,
    split_audit = split_audit,
    code_metadata = data.frame(
      code_git_sha = "closeout",
      code_git_branch = "codex/gen5-wfa-foundation-closeout",
      code_metadata_status = "test_metadata",
      stringsAsFactors = FALSE
    )
  )
  registry <- g5_build_wfa_baseline_family_registry(
    gate_result = gate_result,
    fold_geometry = folds,
    frozen_fold_evidence = evidence
  )

  expect_identical(gate_result$gate_status, "PASS")
  expect_false(gate_result$review_required)

  expect_identical(unique(folds$decision_cadence), "quarterly")
  expect_identical(
    unique(folds$geometry_search_policy),
    "none_single_explicit_quarterly_geometry"
  )
  expect_true(all(folds$train_end_date < folds$oos_start_date))
  expect_true(all(folds$oos_end_date <= folds$latest_completed_session))

  expect_true(all(split_audit$split_summary$train_oos_disjoint))
  expect_true(all(split_audit$split_summary$oos_after_train))
  expect_true(all(split_audit$split_summary$oos_bounded_by_latest_completed_session))
  expect_false(any(split_audit$split_summary$outcome_columns_used_for_membership))
  expect_false(split_audit$leakage_attestation$provider_calls_used)
  expect_false(split_audit$leakage_attestation$latest_session_inferred)
  expect_false(split_audit$leakage_attestation$membership_decided_from_oos_outcomes)

  expect_identical(evidence$evidence_status, rep("FROZEN_NO_ACTIVE_DECISION", nrow(folds)))
  expect_true(all(evidence$leakage_no_provider_calls))
  expect_true(all(evidence$leakage_no_latest_session_inference))
  expect_true(all(evidence$leakage_no_oos_membership_decisions))
  expect_true(all(evidence$leakage_no_oos_fitting))
  expect_false(any(evidence$oos_performance_evaluated))
  expect_true(all(is.na(evidence$active_candidate_id)))
  expect_identical(
    unique(evidence$feature_model_fit_status),
    "not_fit_no_feature_model_authorized"
  )
  expect_identical(
    unique(evidence$strategy_selector_fit_status),
    "not_fit_no_strategy_selector_authorized"
  )

  expect_setequal(
    registry$baseline_family_id,
    c(
      "no_trade_cash",
      "broad_market_buy_hold",
      "per_asset_buy_hold",
      "fixed_equal_weight_basket_buy_hold",
      "active_curation_no_timing"
    )
  )
  expect_true(all(registry$uses_same_fold_calendar))
  expect_true(all(registry$requires_accepted_handoff_gate))
  expect_true(all(registry$uses_same_health_gate))
  expect_true(all(registry$uses_same_train_oos_audit))
  expect_true(all(registry$uses_frozen_fold_evidence))
  expect_true(all(registry$return_computation_status == "not_implemented_no_return_columns_read_or_created"))
  expect_true(all(registry$performance_evaluation_status == "not_implemented_no_benchmark_performance_computed"))
  expect_true(all(registry$allocation_status == "not_implemented_no_allocation_or_weighting"))
  expect_true(all(grepl("no_execution_no_live_advice_no_oos_asset_selection", registry$out_of_scope_guardrail, fixed = TRUE)))

  expect_identical(unique(folds$source_handoff_reference), gate_result$manifest_csv)
  expect_identical(unique(evidence$source_handoff_reference), gate_result$manifest_csv)
  expect_identical(unique(registry$source_handoff_reference), gate_result$manifest_csv)
})

test_that("minimal WFA foundation closeout keeps generated artifacts ignored and validation non-network", {
  repo_root <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)
  gitignore_lines <- readLines(file.path(repo_root, ".gitignore"), warn = FALSE)
  expect_true("runs/" %in% gitignore_lines)
  expect_true("artifacts/" %in% gitignore_lines)
  expect_true("logs/" %in% gitignore_lines)
  expect_true("data_cache/" %in% gitignore_lines)
  expect_true(g5_wfa_path_looks_ignored_run_path(file.path("runs", "wfa_foundation_closeout", "evidence.csv")))
  expect_false(g5_wfa_path_looks_ignored_run_path(file.path("docs", "evidence.csv")))

  runner <- paste(
    readLines(file.path(repo_root, "scripts", "test", "run_tests.R"), warn = FALSE),
    collapse = "\n"
  )
  ps_runner <- paste(
    readLines(file.path(repo_root, "scripts", "test", "run_tests.ps1"), warn = FALSE),
    collapse = "\n"
  )
  combined_runner <- paste(runner, ps_runner, sep = "\n")

  expect_true(grepl('"tests", "testthat"', runner, fixed = TRUE))
  expect_true(grepl("validate_data_layer.R", runner, fixed = TRUE))
  expect_false(grepl("run_data_refresh.R", combined_runner, fixed = TRUE))
  expect_false(grepl("preflight_alpaca_credentials.R", combined_runner, fixed = TRUE))
  expect_false(grepl("query_research_data.R", combined_runner, fixed = TRUE))
  expect_false(grepl("ALPACA_", combined_runner, fixed = TRUE))
})
