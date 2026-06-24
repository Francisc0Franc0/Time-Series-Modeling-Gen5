# Gen5 AMD EMA minimal OOS measurement contract.

g5_wfa_amd_ema_oos_measurement_contract_schema_version <- function() {
  "g5_wfa_amd_ema_oos_measurement_contract_v0"
}

g5_wfa_amd_ema_oos_measurement_allowed_return_fields <- function() {
  c(
    "asset_session_return_open_to_close",
    "strategy_session_return",
    "no_trade_session_return",
    "cash_no_position_return",
    "trade_return_open_to_open"
  )
}

g5_wfa_amd_ema_oos_measurement_allowed_cash_no_position_fields <- function() {
  c(
    "measurement_status",
    "position_state",
    "no_trade_session_return",
    "cash_no_position_return"
  )
}

g5_wfa_amd_ema_oos_measurement_allowed_trade_accounting_fields <- function() {
  c(
    "trade_id",
    "trade_status",
    "position_state",
    "entry_signal_session_date",
    "entry_execution_session_date",
    "exit_signal_session_date",
    "exit_execution_session_date",
    "share_quantity",
    "trade_pnl",
    "holding_period_sessions"
  )
}

g5_wfa_amd_ema_oos_measurement_allowed_metric_fields <- function() {
  c(
    "sharpe_ratio",
    "trade_return_open_to_open",
    "max_drawdown"
  )
}

g5_wfa_required_amd_ema_oos_measurement_manifest_columns <- function() {
  c(
    "schema_version",
    "measurement_contract_id",
    "source_application_boundary_id",
    "source_application_readiness_review_id",
    "source_application_readiness_status",
    "source_application_review_status",
    "source_application_acceptance_status",
    "source_application_artifact_hash",
    "source_freeze_contract_id",
    "source_freeze_readiness_review_id",
    "source_evaluation_contract_id",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "strategy_direction",
    "operation_mode",
    "source_handoff_reference",
    "source_gate_manifest_csv",
    "handoff_gate_status",
    "handoff_review_required",
    "handoff_review_accepted",
    "as_of_timestamp",
    "latest_completed_session",
    "fold_count",
    "comparison_row_count",
    "no_trade_row_count",
    "candidate_row_count",
    "field_count",
    "first_fold_id",
    "last_fold_id",
    "first_oos_start_date",
    "last_oos_end_date",
    "measurement_manifest_path",
    "measurement_field_registry_path",
    "session_measurement_contract_path",
    "trade_measurement_contract_path",
    "fold_summary_contract_path",
    "global_summary_contract_path",
    "artifact_path_policy",
    "allowed_return_fields",
    "allowed_cash_no_position_fields",
    "allowed_trade_accounting_fields",
    "allowed_metric_fields",
    "session_return_rule",
    "trade_return_rule",
    "cash_no_position_return_rule",
    "missing_application_evidence_rule",
    "no_trade_comparison_status",
    "frozen_application_evidence_status",
    "measurement_contract_status",
    "session_measurement_status",
    "trade_measurement_status",
    "fold_summary_status",
    "global_summary_status",
    "ema_signal_status",
    "return_computation_status",
    "cash_yield_status",
    "trade_accounting_status",
    "benchmark_math_status",
    "performance_metric_status",
    "allocation_status",
    "leverage_status",
    "live_advice_status",
    "execution_status",
    "dashboard_status",
    "broader_strategy_family_status",
    "performance_claim_status",
    "provider_scope_status",
    "leakage_no_provider_calls",
    "leakage_no_credentials",
    "leakage_no_unmanifested_cache",
    "leakage_no_latest_session_inference",
    "leakage_no_oos_outcome_authority",
    "leakage_no_oos_fitting",
    "leakage_no_oos_parameter_selection",
    "leakage_no_return_or_metric_computation",
    "leakage_no_allocation_or_live_use"
  )
}

g5_wfa_required_amd_ema_oos_measurement_field_registry_columns <- function() {
  c(
    "schema_version",
    "measurement_contract_id",
    "field_registry_row_id",
    "measurement_surface",
    "field_name",
    "field_category",
    "value_rule",
    "source_authority",
    "no_trade_rule",
    "validation_rule",
    "implementation_status",
    "out_of_scope_status"
  )
}

g5_wfa_required_amd_ema_oos_session_measurement_columns <- function() {
  c(
    "schema_version",
    "measurement_contract_id",
    "measurement_run_id",
    "application_run_id",
    "application_row_id",
    "application_artifact_hash",
    "parameter_pack_id",
    "as_of_timestamp",
    "oos_fold_id",
    "comparison_order",
    "subject_id",
    "symbol",
    "strategy_id",
    "session_date",
    "measurement_status",
    "position_state",
    "trade_id",
    "asset_session_return_open_to_close",
    "strategy_session_return",
    "no_trade_session_return",
    "cash_no_position_return"
  )
}

g5_wfa_required_amd_ema_oos_trade_measurement_columns <- function() {
  c(
    "schema_version",
    "measurement_contract_id",
    "measurement_run_id",
    "application_run_id",
    "application_row_id",
    "application_artifact_hash",
    "parameter_pack_id",
    "as_of_timestamp",
    "oos_fold_id",
    "comparison_order",
    "subject_id",
    "symbol",
    "strategy_id",
    "trade_id",
    "trade_status",
    "position_state",
    "entry_signal_session_date",
    "entry_execution_session_date",
    "exit_signal_session_date",
    "exit_execution_session_date",
    "share_quantity",
    "trade_pnl",
    "holding_period_sessions",
    "trade_return_open_to_open"
  )
}

g5_wfa_required_amd_ema_oos_fold_summary_columns <- function() {
  c(
    "schema_version",
    "measurement_contract_id",
    "measurement_run_id",
    "application_run_id",
    "application_row_id",
    "application_artifact_hash",
    "parameter_pack_id",
    "as_of_timestamp",
    "oos_fold_id",
    "comparison_order",
    "subject_id",
    "symbol",
    "strategy_id",
    "summary_scope",
    "summary_start_date",
    "summary_end_date",
    "sharpe_ratio",
    "max_drawdown"
  )
}

g5_wfa_required_amd_ema_oos_global_summary_columns <- function() {
  c(
    "schema_version",
    "measurement_contract_id",
    "measurement_run_id",
    "application_run_id",
    "application_artifact_hash",
    "parameter_pack_id",
    "as_of_timestamp",
    "subject_id",
    "symbol",
    "strategy_id",
    "summary_scope",
    "summary_start_date",
    "summary_end_date",
    "sharpe_ratio",
    "max_drawdown"
  )
}

g5_wfa_amd_ema_oos_measurement_artifact_path <- function(
  output_dir,
  measurement_contract_id,
  artifact_name,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("AMD EMA OOS measurement contract output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    g5_wfa_sanitize_id_component(measurement_contract_id, "measurement_contract_id"),
    artifact_name
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA OOS measurement contract artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_wfa_amd_ema_oos_measurement_field_category <- function(field_name) {
  if (field_name %in% c(
    "asset_session_return_open_to_close",
    "strategy_session_return",
    "no_trade_session_return",
    "cash_no_position_return",
    "trade_return_open_to_open"
  )) {
    return("return")
  }
  if (field_name %in% c(
    "measurement_status",
    "position_state",
    "trade_id",
    "trade_status",
    "entry_signal_session_date",
    "entry_execution_session_date",
    "exit_signal_session_date",
    "exit_execution_session_date",
    "share_quantity",
    "trade_pnl",
    "holding_period_sessions"
  )) {
    return("trade_accounting")
  }
  if (field_name %in% c("sharpe_ratio", "max_drawdown")) {
    return("metric")
  }
  if (field_name %in% c(
    "schema_version",
    "measurement_contract_id",
    "measurement_run_id",
    "application_run_id",
    "application_row_id",
    "application_artifact_hash",
    "parameter_pack_id",
    "as_of_timestamp",
    "oos_fold_id",
    "comparison_order",
    "subject_id",
    "symbol",
    "strategy_id"
  )) {
    return("identity")
  }
  "contract"
}

g5_wfa_amd_ema_oos_measurement_value_rule <- function(field_name) {
  switch(
    field_name,
    asset_session_return_open_to_close = "daily_adjusted_session_open_to_close_return",
    strategy_session_return = "position_gated_open_to_close_session_return_zero_when_flat",
    no_trade_session_return = "always_zero_no_trade_cash_no_yield",
    cash_no_position_return = "always_zero_cash_or_no_position_no_yield",
    trade_return_open_to_open = "entry_next_open_to_exit_next_open_round_trip_return",
    measurement_status = "measured_flat_no_position_or_open_trade_unclosed_only",
    position_state = "long_cash_or_no_position_only",
    entry_signal_session_date = "close_session_that_generated_entry_signal",
    entry_execution_session_date = "next_session_open_after_entry_signal",
    exit_signal_session_date = "close_session_that_generated_exit_signal",
    exit_execution_session_date = "next_session_open_after_exit_signal",
    sharpe_ratio = "summary_metric_from_authorized_oos_strategy_session_returns",
    max_drawdown = "summary_metric_from_authorized_oos_strategy_session_return_path",
    "metadata_or_identifier_value"
  )
}

g5_wfa_amd_ema_oos_measurement_no_trade_rule <- function(field_name) {
  if (field_name %in% c(
    "asset_session_return_open_to_close",
    "strategy_session_return",
    "no_trade_session_return",
    "cash_no_position_return"
  )) {
    return("no_trade_and_flat_rows_must_record_zero_return")
  }
  if (field_name %in% c("position_state", "measurement_status")) {
    return("no_trade_rows_must_remain_explicit_cash_or_no_position")
  }
  if (field_name %in% c("trade_id", "trade_status", "trade_pnl", "trade_return_open_to_open")) {
    return("no_trade_has_no_completed_trade_rows")
  }
  "preserve_no_trade_as_first_class_comparison_where_applicable"
}

g5_wfa_amd_ema_oos_measurement_validation_rule <- function(field_name) {
  if (field_name %in% c("application_run_id", "application_row_id", "application_artifact_hash")) {
    return("must_reference_frozen_application_evidence_missing_rows_are_errors")
  }
  if (field_name %in% c("asset_session_return_open_to_close", "strategy_session_return")) {
    return("session_return_fields_are_open_to_close_only")
  }
  if (field_name %in% c("trade_return_open_to_open")) {
    return("trade_return_fields_are_open_to_open_only")
  }
  if (field_name %in% c("sharpe_ratio", "max_drawdown")) {
    return("metric_field_allowed_without_expanding_to_performance_claims")
  }
  "required_by_contract_schema"
}

g5_wfa_amd_ema_oos_measurement_surface_fields <- function() {
  list(
    oos_session_measurement = g5_wfa_required_amd_ema_oos_session_measurement_columns(),
    oos_trade_measurement = g5_wfa_required_amd_ema_oos_trade_measurement_columns(),
    oos_fold_summary = g5_wfa_required_amd_ema_oos_fold_summary_columns(),
    oos_global_summary = g5_wfa_required_amd_ema_oos_global_summary_columns()
  )
}

g5_wfa_amd_ema_oos_measurement_field_registry <- function(measurement_contract_id) {
  surfaces <- g5_wfa_amd_ema_oos_measurement_surface_fields()
  rows <- list()
  k <- 0L
  for (surface in names(surfaces)) {
    for (field_name in surfaces[[surface]]) {
      k <- k + 1L
      rows[[k]] <- data.frame(
        schema_version = g5_wfa_amd_ema_oos_measurement_contract_schema_version(),
        measurement_contract_id = as.character(measurement_contract_id),
        field_registry_row_id = paste(
          "amd_ema_oos_measurement_field",
          surface,
          field_name,
          sep = "_"
        ),
        measurement_surface = surface,
        field_name = field_name,
        field_category = g5_wfa_amd_ema_oos_measurement_field_category(field_name),
        value_rule = g5_wfa_amd_ema_oos_measurement_value_rule(field_name),
        source_authority = "frozen_application_evidence_and_authorized_measurement_output_only",
        no_trade_rule = g5_wfa_amd_ema_oos_measurement_no_trade_rule(field_name),
        validation_rule = g5_wfa_amd_ema_oos_measurement_validation_rule(field_name),
        implementation_status = "authorized_contract_field_no_value_computed",
        out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_performance_claims_not_authorized",
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[g5_wfa_required_amd_ema_oos_measurement_field_registry_columns()]
}

g5_wfa_amd_ema_oos_measurement_application_artifact_hash <- function(
  application_manifest,
  application_surface
) {
  g5_make_data_version_hash(
    application_manifest$application_boundary_id[[1L]],
    application_manifest$source_freeze_contract_id[[1L]],
    application_manifest$source_evaluation_contract_id[[1L]],
    application_manifest$as_of_timestamp[[1L]],
    paste(application_surface$application_row_id, collapse = ","),
    paste(application_surface$frozen_parameter_id, collapse = ","),
    paste(application_surface$oos_start_date, application_surface$oos_end_date, collapse = ",")
  )
}

g5_wfa_validate_amd_ema_oos_measurement_source_review <- function(
  parameter_application_boundary,
  parameter_application_readiness_review,
  operator_accepts_application_readiness_review = FALSE
) {
  if (!isTRUE(operator_accepts_application_readiness_review)) {
    g5_stop("AMD EMA OOS measurement contract requires explicit operator acceptance of the application boundary readiness review.")
  }
  parameter_application_boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
    parameter_application_boundary
  )
  parameter_application_readiness_review <- g5_validate_wfa_amd_ema_parameter_application_readiness_review(
    parameter_application_readiness_review
  )
  manifest <- parameter_application_boundary$run_manifest
  application_surface <- parameter_application_boundary$application_surface
  readiness_review <- parameter_application_readiness_review

  if (!identical(
    as.character(readiness_review$application_boundary_id[[1L]]),
    as.character(manifest$application_boundary_id[[1L]])
  )) {
    g5_stop("AMD EMA OOS measurement readiness review must reference the application_boundary_id.")
  }
  if (as.integer(readiness_review$fold_count[[1L]]) !=
      as.integer(manifest$fold_count[[1L]]) ||
      as.integer(readiness_review$comparison_row_count[[1L]]) !=
        nrow(application_surface)) {
    g5_stop("AMD EMA OOS measurement readiness review counts must match the application boundary.")
  }
  expected_values <- c(
    readiness_status = "ready_for_operator_review_no_results_computed",
    source_freeze_acceptance_status = "operator_accepted_amd_ema_parameter_freeze_readiness_review",
    no_trade_comparison_status = "no_trade_cash_first_class_row_for_every_fold",
    frozen_parameter_status = "train_only_parameters_preserved_from_freeze_contract",
    application_boundary_status = "frozen_parameters_bound_to_oos_windows_no_signals_or_results",
    oos_measurement_status = "not_authorized_no_oos_measurement_fields",
    calculation_stop_status = "ema_signals_returns_cash_yield_trade_accounting_benchmark_math_metrics_all_not_computed",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_not_authorized",
    leakage_attestation_status = "all_boundary_leakage_attestations_true",
    review_status = "operator_review_ready_application_boundary_no_results_computed"
  )
  for (col in names(expected_values)) {
    if (!identical(as.character(readiness_review[[col]][[1L]]), expected_values[[col]])) {
      g5_stop(paste("AMD EMA OOS measurement application readiness review has invalid", col))
    }
  }
  list(
    manifest = manifest,
    application_surface = application_surface,
    readiness_review = readiness_review
  )
}

g5_build_wfa_amd_ema_oos_measurement_contract <- function(
  parameter_application_boundary,
  parameter_application_readiness_review,
  output_dir = file.path("runs", "wfa_amd_ema_oos_measurement_contract"),
  operator_accepts_application_readiness_review = FALSE
) {
  source <- g5_wfa_validate_amd_ema_oos_measurement_source_review(
    parameter_application_boundary = parameter_application_boundary,
    parameter_application_readiness_review = parameter_application_readiness_review,
    operator_accepts_application_readiness_review = operator_accepts_application_readiness_review
  )
  manifest <- source$manifest
  application_surface <- source$application_surface
  readiness_review <- source$readiness_review

  first_row <- application_surface[1L, , drop = FALSE]
  last_row <- application_surface[nrow(application_surface), , drop = FALSE]
  measurement_contract_id <- paste(
    "amd_ema_oos_measurement_contract",
    g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(manifest$first_fold_id[[1L]], "first_fold_id"),
    g5_wfa_sanitize_id_component(manifest$last_fold_id[[1L]], "last_fold_id"),
    sep = "_"
  )
  field_registry <- g5_wfa_amd_ema_oos_measurement_field_registry(measurement_contract_id)
  application_artifact_hash <- g5_wfa_amd_ema_oos_measurement_application_artifact_hash(
    manifest,
    application_surface
  )

  measurement_manifest_path <- g5_wfa_amd_ema_oos_measurement_artifact_path(
    output_dir = output_dir,
    measurement_contract_id = measurement_contract_id,
    artifact_name = "amd_ema_oos_measurement_contract_manifest.csv"
  )
  measurement_field_registry_path <- g5_wfa_amd_ema_oos_measurement_artifact_path(
    output_dir = output_dir,
    measurement_contract_id = measurement_contract_id,
    artifact_name = "amd_ema_oos_measurement_field_registry.csv"
  )
  session_measurement_contract_path <- g5_wfa_amd_ema_oos_measurement_artifact_path(
    output_dir = output_dir,
    measurement_contract_id = measurement_contract_id,
    artifact_name = "future_oos_session_measurement_schema.csv"
  )
  trade_measurement_contract_path <- g5_wfa_amd_ema_oos_measurement_artifact_path(
    output_dir = output_dir,
    measurement_contract_id = measurement_contract_id,
    artifact_name = "future_oos_trade_measurement_schema.csv"
  )
  fold_summary_contract_path <- g5_wfa_amd_ema_oos_measurement_artifact_path(
    output_dir = output_dir,
    measurement_contract_id = measurement_contract_id,
    artifact_name = "future_oos_fold_summary_schema.csv"
  )
  global_summary_contract_path <- g5_wfa_amd_ema_oos_measurement_artifact_path(
    output_dir = output_dir,
    measurement_contract_id = measurement_contract_id,
    artifact_name = "future_oos_global_summary_schema.csv"
  )

  measurement_manifest <- data.frame(
    schema_version = g5_wfa_amd_ema_oos_measurement_contract_schema_version(),
    measurement_contract_id = measurement_contract_id,
    source_application_boundary_id = as.character(manifest$application_boundary_id[[1L]]),
    source_application_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
    source_application_readiness_status = as.character(readiness_review$readiness_status[[1L]]),
    source_application_review_status = as.character(readiness_review$review_status[[1L]]),
    source_application_acceptance_status = "operator_accepted_amd_ema_parameter_application_readiness_review",
    source_application_artifact_hash = application_artifact_hash,
    source_freeze_contract_id = as.character(manifest$source_freeze_contract_id[[1L]]),
    source_freeze_readiness_review_id = as.character(manifest$source_freeze_readiness_review_id[[1L]]),
    source_evaluation_contract_id = as.character(manifest$source_evaluation_contract_id[[1L]]),
    candidate_id = as.character(manifest$candidate_id[[1L]]),
    candidate_symbol = as.character(manifest$candidate_symbol[[1L]]),
    strategy_family = as.character(manifest$strategy_family[[1L]]),
    strategy_direction = as.character(manifest$strategy_direction[[1L]]),
    operation_mode = "research_only_non_live_non_dashboard",
    source_handoff_reference = as.character(manifest$source_handoff_reference[[1L]]),
    source_gate_manifest_csv = as.character(manifest$source_gate_manifest_csv[[1L]]),
    handoff_gate_status = as.character(manifest$handoff_gate_status[[1L]]),
    handoff_review_required = as.logical(manifest$handoff_review_required[[1L]]),
    handoff_review_accepted = as.logical(manifest$handoff_review_accepted[[1L]]),
    as_of_timestamp = as.character(manifest$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(manifest$latest_completed_session[[1L]]),
    fold_count = as.integer(manifest$fold_count[[1L]]),
    comparison_row_count = as.integer(manifest$comparison_row_count[[1L]]),
    no_trade_row_count = as.integer(manifest$no_trade_row_count[[1L]]),
    candidate_row_count = as.integer(manifest$candidate_row_count[[1L]]),
    field_count = as.integer(nrow(field_registry)),
    first_fold_id = as.character(manifest$first_fold_id[[1L]]),
    last_fold_id = as.character(manifest$last_fold_id[[1L]]),
    first_oos_start_date = as.Date(first_row$oos_start_date[[1L]]),
    last_oos_end_date = as.Date(last_row$oos_end_date[[1L]]),
    measurement_manifest_path = measurement_manifest_path,
    measurement_field_registry_path = measurement_field_registry_path,
    session_measurement_contract_path = session_measurement_contract_path,
    trade_measurement_contract_path = trade_measurement_contract_path,
    fold_summary_contract_path = fold_summary_contract_path,
    global_summary_contract_path = global_summary_contract_path,
    artifact_path_policy = "deterministic_ignored_runs_path_contract_only",
    allowed_return_fields = paste(g5_wfa_amd_ema_oos_measurement_allowed_return_fields(), collapse = ";"),
    allowed_cash_no_position_fields = paste(
      g5_wfa_amd_ema_oos_measurement_allowed_cash_no_position_fields(),
      collapse = ";"
    ),
    allowed_trade_accounting_fields = paste(
      g5_wfa_amd_ema_oos_measurement_allowed_trade_accounting_fields(),
      collapse = ";"
    ),
    allowed_metric_fields = paste(g5_wfa_amd_ema_oos_measurement_allowed_metric_fields(), collapse = ";"),
    session_return_rule = "one_trading_session_open_to_close_return_no_lookahead",
    trade_return_rule = "round_trip_entry_next_open_to_exit_next_open_return_no_lookahead",
    cash_no_position_return_rule = "flat_no_position_and_no_trade_cash_return_zero_no_cash_yield",
    missing_application_evidence_rule = "missing_frozen_application_session_rows_are_errors_not_flat_periods",
    no_trade_comparison_status = "no_trade_cash_first_class_zero_return_comparison_preserved",
    frozen_application_evidence_status = "consumes_accepted_application_boundary_no_parameter_or_signal_authority_recomputed",
    measurement_contract_status = "authorized_field_contract_only_no_values_computed",
    session_measurement_status = "authorized_schema_only_session_open_to_close_returns_no_values_computed",
    trade_measurement_status = "authorized_schema_only_trade_open_to_open_returns_no_values_computed",
    fold_summary_status = "authorized_schema_only_sharpe_and_max_drawdown_no_values_computed",
    global_summary_status = "authorized_schema_only_sharpe_and_max_drawdown_no_values_computed",
    ema_signal_status = "not_computed_in_contract_frozen_application_evidence_required",
    return_computation_status = "authorized_fields_only_session_open_to_close_trade_open_to_open_not_computed",
    cash_yield_status = "authorized_zero_cash_no_position_return_no_yield",
    trade_accounting_status = "authorized_fields_only_position_dates_shares_pnl_holding_period_not_computed",
    benchmark_math_status = "not_authorized_except_no_trade_zero_return",
    performance_metric_status = "authorized_fields_only_sharpe_trade_return_max_drawdown_not_computed",
    allocation_status = "not_authorized_no_allocation_or_weighting",
    leverage_status = "not_authorized_no_leverage_analysis_or_value_add",
    live_advice_status = "not_authorized_no_live_advice",
    execution_status = "not_authorized_no_orders_or_execution",
    dashboard_status = "not_authorized_no_dashboard",
    broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only",
    performance_claim_status = "not_authorized_metrics_are_contract_fields_not_claims",
    provider_scope_status = "no_provider_calls_handoff_only_alpaca_adjusted_daily_lineage",
    leakage_no_provider_calls = TRUE,
    leakage_no_credentials = TRUE,
    leakage_no_unmanifested_cache = TRUE,
    leakage_no_latest_session_inference = TRUE,
    leakage_no_oos_outcome_authority = TRUE,
    leakage_no_oos_fitting = TRUE,
    leakage_no_oos_parameter_selection = TRUE,
    leakage_no_return_or_metric_computation = TRUE,
    leakage_no_allocation_or_live_use = TRUE,
    stringsAsFactors = FALSE
  )
  rownames(measurement_manifest) <- NULL

  list(
    run_manifest = measurement_manifest[g5_wfa_required_amd_ema_oos_measurement_manifest_columns()],
    field_registry = field_registry[g5_wfa_required_amd_ema_oos_measurement_field_registry_columns()]
  )
}

g5_validate_wfa_amd_ema_oos_measurement_contract <- function(oos_measurement_contract) {
  if (!is.list(oos_measurement_contract) ||
      is.null(oos_measurement_contract$run_manifest) ||
      is.null(oos_measurement_contract$field_registry)) {
    g5_stop("AMD EMA OOS measurement contract must be a list with run_manifest and field_registry.")
  }
  manifest <- oos_measurement_contract$run_manifest
  field_registry <- oos_measurement_contract$field_registry
  g5_wfa_require_columns(
    manifest,
    g5_wfa_required_amd_ema_oos_measurement_manifest_columns(),
    "AMD EMA OOS measurement manifest"
  )
  g5_wfa_require_columns(
    field_registry,
    g5_wfa_required_amd_ema_oos_measurement_field_registry_columns(),
    "AMD EMA OOS measurement field registry"
  )
  if (nrow(manifest) != 1L) {
    g5_stop("AMD EMA OOS measurement manifest must contain exactly one row.")
  }
  if (nrow(field_registry) == 0L) {
    g5_stop("AMD EMA OOS measurement field registry must contain at least one row.")
  }
  if (any(as.character(manifest$schema_version) !=
          g5_wfa_amd_ema_oos_measurement_contract_schema_version()) ||
      any(as.character(field_registry$schema_version) !=
          g5_wfa_amd_ema_oos_measurement_contract_schema_version())) {
    g5_stop("AMD EMA OOS measurement contract has an unexpected schema_version.")
  }
  if (any(as.character(field_registry$measurement_contract_id) !=
          as.character(manifest$measurement_contract_id[[1L]]))) {
    g5_stop("AMD EMA OOS measurement field rows must reference the manifest measurement_contract_id.")
  }
  expected_registry <- g5_wfa_amd_ema_oos_measurement_field_registry(
    manifest$measurement_contract_id[[1L]]
  )
  expected_keys <- paste(expected_registry$measurement_surface, expected_registry$field_name)
  observed_keys <- paste(field_registry$measurement_surface, field_registry$field_name)
  if (!identical(observed_keys, expected_keys) ||
      !identical(as.character(field_registry$field_category), as.character(expected_registry$field_category))) {
    g5_stop("AMD EMA OOS measurement field registry does not match the authorized fields.")
  }
  if (any(duplicated(as.character(field_registry$field_registry_row_id)))) {
    g5_stop("AMD EMA OOS measurement field registry row ids must be unique.")
  }
  if (as.integer(manifest$fold_count[[1L]]) <= 0L ||
      as.integer(manifest$no_trade_row_count[[1L]]) != as.integer(manifest$fold_count[[1L]]) ||
      as.integer(manifest$candidate_row_count[[1L]]) != as.integer(manifest$fold_count[[1L]]) ||
      as.integer(manifest$comparison_row_count[[1L]]) != as.integer(manifest$fold_count[[1L]]) * 2L) {
    g5_stop("AMD EMA OOS measurement manifest row counts must preserve no-trade and candidate rows per fold.")
  }
  if (as.integer(manifest$field_count[[1L]]) != nrow(field_registry)) {
    g5_stop("AMD EMA OOS measurement manifest field_count must match the field registry.")
  }
  expected_lists <- c(
    allowed_return_fields = paste(g5_wfa_amd_ema_oos_measurement_allowed_return_fields(), collapse = ";"),
    allowed_cash_no_position_fields = paste(
      g5_wfa_amd_ema_oos_measurement_allowed_cash_no_position_fields(),
      collapse = ";"
    ),
    allowed_trade_accounting_fields = paste(
      g5_wfa_amd_ema_oos_measurement_allowed_trade_accounting_fields(),
      collapse = ";"
    ),
    allowed_metric_fields = paste(g5_wfa_amd_ema_oos_measurement_allowed_metric_fields(), collapse = ";")
  )
  for (col in names(expected_lists)) {
    if (!identical(as.character(manifest[[col]][[1L]]), expected_lists[[col]])) {
      g5_stop(paste("AMD EMA OOS measurement contract has invalid", col))
    }
  }
  expected_status <- c(
    source_application_acceptance_status = "operator_accepted_amd_ema_parameter_application_readiness_review",
    session_return_rule = "one_trading_session_open_to_close_return_no_lookahead",
    trade_return_rule = "round_trip_entry_next_open_to_exit_next_open_return_no_lookahead",
    cash_no_position_return_rule = "flat_no_position_and_no_trade_cash_return_zero_no_cash_yield",
    missing_application_evidence_rule = "missing_frozen_application_session_rows_are_errors_not_flat_periods",
    no_trade_comparison_status = "no_trade_cash_first_class_zero_return_comparison_preserved",
    frozen_application_evidence_status = "consumes_accepted_application_boundary_no_parameter_or_signal_authority_recomputed",
    measurement_contract_status = "authorized_field_contract_only_no_values_computed",
    allocation_status = "not_authorized_no_allocation_or_weighting",
    leverage_status = "not_authorized_no_leverage_analysis_or_value_add",
    live_advice_status = "not_authorized_no_live_advice",
    execution_status = "not_authorized_no_orders_or_execution",
    dashboard_status = "not_authorized_no_dashboard",
    broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only",
    performance_claim_status = "not_authorized_metrics_are_contract_fields_not_claims"
  )
  for (col in names(expected_status)) {
    if (!identical(as.character(manifest[[col]][[1L]]), expected_status[[col]])) {
      g5_stop(paste("AMD EMA OOS measurement contract has invalid", col))
    }
  }
  leakage_cols <- c(
    "leakage_no_provider_calls",
    "leakage_no_credentials",
    "leakage_no_unmanifested_cache",
    "leakage_no_latest_session_inference",
    "leakage_no_oos_outcome_authority",
    "leakage_no_oos_fitting",
    "leakage_no_oos_parameter_selection",
    "leakage_no_return_or_metric_computation",
    "leakage_no_allocation_or_live_use"
  )
  for (col in leakage_cols) {
    if (any(!as.logical(manifest[[col]]))) {
      g5_stop(paste("AMD EMA OOS measurement contract leakage attestation failed:", col))
    }
  }
  paths <- c(
    manifest$measurement_manifest_path,
    manifest$measurement_field_registry_path,
    manifest$session_measurement_contract_path,
    manifest$trade_measurement_contract_path,
    manifest$fold_summary_contract_path,
    manifest$global_summary_contract_path
  )
  bad_paths <- !vapply(paths, g5_wfa_path_looks_ignored_run_path, logical(1L))
  if (any(bad_paths)) {
    g5_stop("AMD EMA OOS measurement contract artifact paths must be under ignored runs/ paths.")
  }
  oos_measurement_contract
}

g5_wfa_required_amd_ema_oos_measurement_readiness_columns <- function() {
  c(
    "schema_version",
    "readiness_review_id",
    "readiness_status",
    "measurement_contract_id",
    "source_application_boundary_id",
    "source_application_readiness_review_id",
    "source_application_acceptance_status",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "source_handoff_reference",
    "source_gate_manifest_csv",
    "handoff_gate_status",
    "handoff_review_required",
    "handoff_review_accepted",
    "as_of_timestamp",
    "latest_completed_session",
    "fold_count",
    "comparison_row_count",
    "no_trade_row_count",
    "candidate_row_count",
    "field_count",
    "no_trade_comparison_status",
    "frozen_application_evidence_status",
    "measurement_contract_status",
    "return_rule_status",
    "trade_accounting_rule_status",
    "metric_scope_status",
    "out_of_scope_status",
    "leakage_attestation_status",
    "review_status",
    "review_required_reason"
  )
}

g5_build_wfa_amd_ema_oos_measurement_readiness_review <- function(oos_measurement_contract) {
  oos_measurement_contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    oos_measurement_contract
  )
  manifest <- oos_measurement_contract$run_manifest
  data.frame(
    schema_version = g5_wfa_amd_ema_oos_measurement_contract_schema_version(),
    readiness_review_id = paste(
      "amd_ema_oos_measurement_readiness",
      g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
      g5_wfa_sanitize_id_component(manifest$first_fold_id[[1L]], "first_fold_id"),
      g5_wfa_sanitize_id_component(manifest$last_fold_id[[1L]], "last_fold_id"),
      sep = "_"
    ),
    readiness_status = "ready_for_operator_review_measurement_fields_authorized_no_values_computed",
    measurement_contract_id = as.character(manifest$measurement_contract_id[[1L]]),
    source_application_boundary_id = as.character(manifest$source_application_boundary_id[[1L]]),
    source_application_readiness_review_id = as.character(manifest$source_application_readiness_review_id[[1L]]),
    source_application_acceptance_status = as.character(manifest$source_application_acceptance_status[[1L]]),
    candidate_id = as.character(manifest$candidate_id[[1L]]),
    candidate_symbol = as.character(manifest$candidate_symbol[[1L]]),
    strategy_family = as.character(manifest$strategy_family[[1L]]),
    source_handoff_reference = as.character(manifest$source_handoff_reference[[1L]]),
    source_gate_manifest_csv = as.character(manifest$source_gate_manifest_csv[[1L]]),
    handoff_gate_status = as.character(manifest$handoff_gate_status[[1L]]),
    handoff_review_required = as.logical(manifest$handoff_review_required[[1L]]),
    handoff_review_accepted = as.logical(manifest$handoff_review_accepted[[1L]]),
    as_of_timestamp = as.character(manifest$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(manifest$latest_completed_session[[1L]]),
    fold_count = as.integer(manifest$fold_count[[1L]]),
    comparison_row_count = as.integer(manifest$comparison_row_count[[1L]]),
    no_trade_row_count = as.integer(manifest$no_trade_row_count[[1L]]),
    candidate_row_count = as.integer(manifest$candidate_row_count[[1L]]),
    field_count = as.integer(manifest$field_count[[1L]]),
    no_trade_comparison_status = as.character(manifest$no_trade_comparison_status[[1L]]),
    frozen_application_evidence_status = as.character(manifest$frozen_application_evidence_status[[1L]]),
    measurement_contract_status = as.character(manifest$measurement_contract_status[[1L]]),
    return_rule_status = "session_open_to_close_and_trade_open_to_open_authorized",
    trade_accounting_rule_status = "position_state_entry_exit_dates_shares_pnl_holding_period_authorized",
    metric_scope_status = "sharpe_trade_return_max_drawdown_only",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_performance_claims_not_authorized",
    leakage_attestation_status = "all_contract_leakage_attestations_true",
    review_status = "operator_review_ready_measurement_contract_no_values_computed",
    review_required_reason = paste(
      c(
        "accepted_application_boundary_readiness_review_consumed",
        "authorized_fields_named_by_operator",
        "future_measurement_must_reference_frozen_application_rows"
      ),
      collapse = ";"
    ),
    stringsAsFactors = FALSE
  )[g5_wfa_required_amd_ema_oos_measurement_readiness_columns()]
}

g5_validate_wfa_amd_ema_oos_measurement_readiness_review <- function(readiness_review) {
  g5_wfa_require_columns(
    readiness_review,
    g5_wfa_required_amd_ema_oos_measurement_readiness_columns(),
    "AMD EMA OOS measurement readiness review"
  )
  if (nrow(readiness_review) != 1L) {
    g5_stop("AMD EMA OOS measurement readiness review must contain exactly one row.")
  }
  expected_values <- c(
    readiness_status = "ready_for_operator_review_measurement_fields_authorized_no_values_computed",
    source_application_acceptance_status = "operator_accepted_amd_ema_parameter_application_readiness_review",
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
    no_trade_comparison_status = "no_trade_cash_first_class_zero_return_comparison_preserved",
    frozen_application_evidence_status = "consumes_accepted_application_boundary_no_parameter_or_signal_authority_recomputed",
    measurement_contract_status = "authorized_field_contract_only_no_values_computed",
    return_rule_status = "session_open_to_close_and_trade_open_to_open_authorized",
    trade_accounting_rule_status = "position_state_entry_exit_dates_shares_pnl_holding_period_authorized",
    metric_scope_status = "sharpe_trade_return_max_drawdown_only",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_performance_claims_not_authorized",
    leakage_attestation_status = "all_contract_leakage_attestations_true",
    review_status = "operator_review_ready_measurement_contract_no_values_computed"
  )
  for (col in names(expected_values)) {
    if (!identical(as.character(readiness_review[[col]][[1L]]), expected_values[[col]])) {
      g5_stop(paste("AMD EMA OOS measurement readiness review has invalid", col))
    }
  }
  if (as.integer(readiness_review$fold_count[[1L]]) <= 0L ||
      as.integer(readiness_review$no_trade_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]]) ||
      as.integer(readiness_review$candidate_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]]) ||
      as.integer(readiness_review$comparison_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]]) * 2L) {
    g5_stop("AMD EMA OOS measurement readiness review row counts must match fold_count.")
  }
  readiness_review
}

g5_wfa_reject_amd_ema_oos_measurement_extra_columns <- function(x, required, label) {
  missing_cols <- setdiff(required, names(x))
  if (length(missing_cols) > 0L) {
    g5_stop(paste(label, "missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  extra_cols <- setdiff(names(x), required)
  if (length(extra_cols) > 0L) {
    g5_stop(paste(label, "has unauthorized columns:", paste(extra_cols, collapse = ", ")))
  }
  if (!identical(names(x), required)) {
    g5_stop(paste(label, "columns must match the authorized order."))
  }
  invisible(TRUE)
}

g5_validate_wfa_amd_ema_oos_session_measurements <- function(
  session_measurements,
  oos_measurement_contract,
  parameter_application_boundary = NULL
) {
  if (!is.data.frame(session_measurements)) {
    g5_stop("AMD EMA OOS session measurements must be a data.frame.")
  }
  oos_measurement_contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    oos_measurement_contract
  )
  required <- g5_wfa_required_amd_ema_oos_session_measurement_columns()
  g5_wfa_reject_amd_ema_oos_measurement_extra_columns(
    session_measurements,
    required,
    "AMD EMA OOS session measurements"
  )
  manifest <- oos_measurement_contract$run_manifest
  if (any(as.character(session_measurements$schema_version) !=
          g5_wfa_amd_ema_oos_measurement_contract_schema_version())) {
    g5_stop("AMD EMA OOS session measurements have an unexpected schema_version.")
  }
  if (any(as.character(session_measurements$measurement_contract_id) !=
          as.character(manifest$measurement_contract_id[[1L]]))) {
    g5_stop("AMD EMA OOS session measurements must reference the measurement_contract_id.")
  }
  allowed_status <- c("measured", "flat_no_position", "open_trade_unclosed")
  if (any(!(as.character(session_measurements$measurement_status) %in% allowed_status))) {
    g5_stop("AMD EMA OOS session measurements have invalid measurement_status values.")
  }
  allowed_position <- c("long", "cash", "no_position")
  if (any(!(as.character(session_measurements$position_state) %in% allowed_position))) {
    g5_stop("AMD EMA OOS session measurements have invalid position_state values.")
  }
  return_cols <- c(
    "asset_session_return_open_to_close",
    "strategy_session_return",
    "no_trade_session_return",
    "cash_no_position_return"
  )
  for (col in return_cols) {
    values <- suppressWarnings(as.numeric(session_measurements[[col]]))
    if (any(!is.finite(values))) {
      g5_stop(paste("AMD EMA OOS session measurements have non-finite values in", col))
    }
    session_measurements[[col]] <- values
  }
  no_trade <- as.character(session_measurements$subject_id) == "no_trade_cash"
  if (any(no_trade)) {
    no_trade_returns <- as.matrix(session_measurements[no_trade, return_cols, drop = FALSE])
    if (any(abs(no_trade_returns) > .Machine$double.eps)) {
      g5_stop("AMD EMA OOS session no-trade rows must carry zero returns.")
    }
    if (any(!(as.character(session_measurements$position_state[no_trade]) %in% c("cash", "no_position")))) {
      g5_stop("AMD EMA OOS session no-trade rows must remain cash or no_position.")
    }
  }
  flat <- as.character(session_measurements$measurement_status) == "flat_no_position"
  if (any(flat)) {
    flat_returns <- as.matrix(session_measurements[flat, c(
      "strategy_session_return",
      "cash_no_position_return"
    ), drop = FALSE])
    if (any(abs(flat_returns) > .Machine$double.eps)) {
      g5_stop("AMD EMA OOS session flat rows must carry zero strategy and cash/no-position returns.")
    }
  }
  session_measurements$session_date <- as.Date(session_measurements$session_date)
  if (any(is.na(session_measurements$session_date))) {
    g5_stop("AMD EMA OOS session measurements have invalid session_date values.")
  }
  if (!is.null(parameter_application_boundary)) {
    parameter_application_boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
      parameter_application_boundary
    )
    application_surface <- parameter_application_boundary$application_surface
    expected_rows <- setNames(
      as.integer(application_surface$amd_oos_row_count),
      as.character(application_surface$application_row_id)
    )
    observed_ids <- as.character(session_measurements$application_row_id)
    unknown_ids <- setdiff(unique(observed_ids), names(expected_rows))
    if (length(unknown_ids) > 0L) {
      g5_stop(paste(
        "AMD EMA OOS session measurements reference unknown application_row_id values:",
        paste(unknown_ids, collapse = ", ")
      ))
    }
    observed_counts <- table(factor(observed_ids, levels = names(expected_rows)))
    if (any(as.integer(observed_counts) != expected_rows)) {
      g5_stop("AMD EMA OOS session measurements must contain exactly the frozen OOS session count for every application row.")
    }
    for (i in seq_len(nrow(application_surface))) {
      app_row <- application_surface[i, , drop = FALSE]
      rows <- session_measurements[
        as.character(session_measurements$application_row_id) ==
          as.character(app_row$application_row_id[[1L]]),
        ,
        drop = FALSE
      ]
      if (nrow(rows) == 0L) {
        g5_stop("AMD EMA OOS session measurements are missing frozen application evidence rows.")
      }
      if (any(rows$session_date < as.Date(app_row$oos_start_date[[1L]]) |
              rows$session_date > as.Date(app_row$oos_end_date[[1L]]))) {
        g5_stop("AMD EMA OOS session measurements have dates outside the frozen OOS window.")
      }
      if (any(as.character(rows$application_run_id) !=
              as.character(app_row$application_boundary_id[[1L]]))) {
        g5_stop("AMD EMA OOS session measurements must preserve application_run_id lineage.")
      }
    }
  }
  session_measurements
}

g5_wfa_prepare_amd_ema_oos_measurement_bars <- function(
  bars,
  as_of_timestamp,
  latest_completed_session
) {
  bars <- g5_validate_bar_data(bars, require_adjusted = TRUE)
  bars <- bars[as.character(bars$symbol) == "AMD", , drop = FALSE]
  if (nrow(bars) == 0L) {
    g5_stop("AMD EMA OOS session measurement values require canonical AMD bars.")
  }
  if (any(as.character(bars$provider) != "alpaca") ||
      any(as.character(bars$timeframe) != "1D") ||
      any(!as.logical(bars$adjusted))) {
    g5_stop("AMD EMA OOS session measurement values require Alpaca adjusted daily OHLCV bars only.")
  }
  if (any(as.character(bars$as_of_timestamp) != as.character(as_of_timestamp))) {
    g5_stop("AMD EMA OOS session measurement bars must carry the frozen as_of_timestamp.")
  }
  if (any(as.Date(bars$latest_completed_session) != as.Date(latest_completed_session))) {
    g5_stop("AMD EMA OOS session measurement bars must carry the frozen latest_completed_session.")
  }
  bars <- bars[order(bars$session_date), , drop = FALSE]
  rownames(bars) <- NULL
  bars
}

g5_build_wfa_amd_ema_oos_session_measurement_values <- function(
  oos_measurement_contract,
  signal_position_application,
  bars,
  parameter_application_boundary = NULL
) {
  oos_measurement_contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    oos_measurement_contract
  )
  signal_position_application <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    signal_position_application
  )
  manifest <- oos_measurement_contract$run_manifest
  signal_manifest <- signal_position_application$run_manifest
  signal_surface <- signal_position_application$signal_position_surface

  if (!identical(
    as.character(signal_manifest$source_application_boundary_id[[1L]]),
    as.character(manifest$source_application_boundary_id[[1L]])
  )) {
    g5_stop("AMD EMA OOS session measurement values must consume the frozen signal/position evidence for the measurement contract application boundary.")
  }
  if (!identical(
    as.character(signal_manifest$as_of_timestamp[[1L]]),
    as.character(manifest$as_of_timestamp[[1L]])
  ) ||
      !identical(
        as.Date(signal_manifest$latest_completed_session[[1L]]),
        as.Date(manifest$latest_completed_session[[1L]])
      )) {
    g5_stop("AMD EMA OOS session measurement values must preserve explicit as_of_timestamp and latest_completed_session lineage.")
  }

  bars <- g5_wfa_prepare_amd_ema_oos_measurement_bars(
    bars = bars,
    as_of_timestamp = manifest$as_of_timestamp[[1L]],
    latest_completed_session = manifest$latest_completed_session[[1L]]
  )
  bar_keys <- paste(as.character(bars$symbol), as.Date(bars$session_date))
  bar_lookup <- seq_len(nrow(bars))
  names(bar_lookup) <- bar_keys

  measurement_run_id <- paste(
    "amd_ema_oos_session_measurement",
    g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(signal_manifest$signal_position_application_id[[1L]], "signal_position_application_id"),
    sep = "_"
  )

  rows <- vector("list", nrow(signal_surface))
  for (i in seq_len(nrow(signal_surface))) {
    signal_row <- signal_surface[i, , drop = FALSE]
    is_no_trade <- identical(as.character(signal_row$subject_id[[1L]]), "no_trade_cash")
    key <- paste("AMD", as.Date(signal_row$session_date[[1L]]))
    if (!(key %in% names(bar_lookup))) {
      g5_stop("AMD EMA OOS session measurement values are missing canonical AMD bars for frozen signal/position rows.")
    }
    bar_index <- unname(bar_lookup[[key]])
    bar_row <- bars[bar_index, , drop = FALSE]
    asset_return <- if (is_no_trade) {
      0
    } else {
      (as.numeric(bar_row$close[[1L]]) / as.numeric(bar_row$open[[1L]])) - 1
    }
    position_state <- if (is_no_trade) {
      "no_position"
    } else {
      as.character(signal_row$position_state_for_next_open[[1L]])
    }
    measurement_status <- if (identical(position_state, "long")) {
      "measured"
    } else {
      "flat_no_position"
    }
    strategy_return <- if (identical(position_state, "long")) {
      asset_return
    } else {
      0
    }

    rows[[i]] <- data.frame(
      schema_version = g5_wfa_amd_ema_oos_measurement_contract_schema_version(),
      measurement_contract_id = as.character(manifest$measurement_contract_id[[1L]]),
      measurement_run_id = measurement_run_id,
      application_run_id = as.character(signal_row$source_application_boundary_id[[1L]]),
      application_row_id = as.character(signal_row$source_application_row_id[[1L]]),
      application_artifact_hash = as.character(manifest$source_application_artifact_hash[[1L]]),
      parameter_pack_id = as.character(signal_row$frozen_parameter_id[[1L]]),
      as_of_timestamp = as.character(signal_row$as_of_timestamp[[1L]]),
      oos_fold_id = as.character(signal_row$fold_id[[1L]]),
      comparison_order = as.integer(signal_row$comparison_order[[1L]]),
      subject_id = as.character(signal_row$subject_id[[1L]]),
      symbol = if (is_no_trade) NA_character_ else "AMD",
      strategy_id = if (is_no_trade) "no_trade_cash" else "ema_long_cash",
      session_date = as.Date(signal_row$session_date[[1L]]),
      measurement_status = measurement_status,
      position_state = position_state,
      trade_id = NA_character_,
      asset_session_return_open_to_close = asset_return,
      strategy_session_return = strategy_return,
      no_trade_session_return = 0,
      cash_no_position_return = 0,
      stringsAsFactors = FALSE
    )
  }

  session_measurements <- do.call(rbind, rows)
  rownames(session_measurements) <- NULL
  session_measurements <- session_measurements[
    g5_wfa_required_amd_ema_oos_session_measurement_columns()
  ]
  g5_validate_wfa_amd_ema_oos_session_measurements(
    session_measurements = session_measurements,
    oos_measurement_contract = oos_measurement_contract,
    parameter_application_boundary = parameter_application_boundary
  )
}

g5_empty_wfa_amd_ema_oos_trade_lifecycle_measurements <- function() {
  data.frame(
    schema_version = character(),
    measurement_contract_id = character(),
    measurement_run_id = character(),
    application_run_id = character(),
    application_row_id = character(),
    application_artifact_hash = character(),
    parameter_pack_id = character(),
    as_of_timestamp = character(),
    oos_fold_id = character(),
    comparison_order = integer(),
    subject_id = character(),
    symbol = character(),
    strategy_id = character(),
    trade_id = character(),
    trade_status = character(),
    position_state = character(),
    entry_signal_session_date = as.Date(character()),
    entry_execution_session_date = as.Date(character()),
    exit_signal_session_date = as.Date(character()),
    exit_execution_session_date = as.Date(character()),
    share_quantity = numeric(),
    trade_pnl = numeric(),
    holding_period_sessions = integer(),
    trade_return_open_to_open = numeric(),
    stringsAsFactors = FALSE
  )[g5_wfa_required_amd_ema_oos_trade_measurement_columns()]
}

g5_wfa_amd_ema_oos_holding_sessions <- function(candidate_rows, entry_execution_date, exit_execution_date) {
  if (is.na(entry_execution_date) || is.na(exit_execution_date)) {
    return(NA_integer_)
  }
  session_dates <- as.Date(candidate_rows$session_date)
  as.integer(sum(session_dates >= as.Date(entry_execution_date) &
    session_dates < as.Date(exit_execution_date)))
}

g5_build_wfa_amd_ema_oos_trade_lifecycle_measurements <- function(
  oos_measurement_contract,
  signal_position_application,
  parameter_application_boundary = NULL
) {
  oos_measurement_contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    oos_measurement_contract
  )
  signal_position_application <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    signal_position_application
  )
  manifest <- oos_measurement_contract$run_manifest
  signal_manifest <- signal_position_application$run_manifest
  signal_surface <- signal_position_application$signal_position_surface

  if (!identical(
    as.character(signal_manifest$source_application_boundary_id[[1L]]),
    as.character(manifest$source_application_boundary_id[[1L]])
  )) {
    g5_stop("AMD EMA OOS trade lifecycle measurements must consume the frozen signal/position evidence for the measurement contract application boundary.")
  }
  if (!identical(
    as.character(signal_manifest$as_of_timestamp[[1L]]),
    as.character(manifest$as_of_timestamp[[1L]])
  ) ||
      !identical(
        as.Date(signal_manifest$latest_completed_session[[1L]]),
        as.Date(manifest$latest_completed_session[[1L]])
      )) {
    g5_stop("AMD EMA OOS trade lifecycle measurements must preserve explicit as_of_timestamp and latest_completed_session lineage.")
  }

  measurement_run_id <- paste(
    "amd_ema_oos_trade_lifecycle",
    g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(signal_manifest$signal_position_application_id[[1L]], "signal_position_application_id"),
    sep = "_"
  )

  candidate_surface <- signal_surface[
    as.character(signal_surface$subject_id) == "amd_ema_long_cash",
    ,
    drop = FALSE
  ]
  if (nrow(candidate_surface) == 0L) {
    g5_stop("AMD EMA OOS trade lifecycle measurements require candidate signal/position rows.")
  }
  rows <- list()
  k <- 0L
  for (fold_id in unique(as.character(candidate_surface$fold_id))) {
    fold_rows <- candidate_surface[
      as.character(candidate_surface$fold_id) == fold_id,
      ,
      drop = FALSE
    ]
    fold_rows <- fold_rows[order(as.Date(fold_rows$session_date)), , drop = FALSE]
    previous_state <- "cash"
    open_trade <- NULL
    trade_index <- 0L
    for (i in seq_len(nrow(fold_rows))) {
      signal_row <- fold_rows[i, , drop = FALSE]
      position_state <- as.character(signal_row$position_state_for_next_open[[1L]])
      if (identical(position_state, "long") && !identical(previous_state, "long")) {
        trade_index <- trade_index + 1L
        open_trade <- list(
          trade_id = paste(
            "amd_ema_oos_trade",
            g5_wfa_sanitize_id_component(fold_id, "fold_id"),
            sprintf("%04d", trade_index),
            sep = "_"
          ),
          entry_signal_session_date = as.Date(signal_row$signal_generated_after_close_date[[1L]]),
          entry_execution_session_date = as.Date(signal_row$next_open_session_date[[1L]]),
          source_row = signal_row
        )
      } else if (!identical(position_state, "long") && identical(previous_state, "long")) {
        if (is.null(open_trade)) {
          g5_stop("AMD EMA OOS trade lifecycle measurements found an exit transition without an open trade.")
        }
        k <- k + 1L
        source_row <- open_trade$source_row
        exit_signal_date <- as.Date(signal_row$signal_generated_after_close_date[[1L]])
        exit_execution_date <- as.Date(signal_row$next_open_session_date[[1L]])
        rows[[k]] <- data.frame(
          schema_version = g5_wfa_amd_ema_oos_measurement_contract_schema_version(),
          measurement_contract_id = as.character(manifest$measurement_contract_id[[1L]]),
          measurement_run_id = measurement_run_id,
          application_run_id = as.character(source_row$source_application_boundary_id[[1L]]),
          application_row_id = as.character(source_row$source_application_row_id[[1L]]),
          application_artifact_hash = as.character(manifest$source_application_artifact_hash[[1L]]),
          parameter_pack_id = as.character(source_row$frozen_parameter_id[[1L]]),
          as_of_timestamp = as.character(source_row$as_of_timestamp[[1L]]),
          oos_fold_id = as.character(source_row$fold_id[[1L]]),
          comparison_order = as.integer(source_row$comparison_order[[1L]]),
          subject_id = "amd_ema_long_cash",
          symbol = "AMD",
          strategy_id = "ema_long_cash",
          trade_id = open_trade$trade_id,
          trade_status = "closed_trade_lifecycle",
          position_state = "long",
          entry_signal_session_date = open_trade$entry_signal_session_date,
          entry_execution_session_date = open_trade$entry_execution_session_date,
          exit_signal_session_date = exit_signal_date,
          exit_execution_session_date = exit_execution_date,
          share_quantity = NA_real_,
          trade_pnl = NA_real_,
          holding_period_sessions = g5_wfa_amd_ema_oos_holding_sessions(
            candidate_rows = fold_rows,
            entry_execution_date = open_trade$entry_execution_session_date,
            exit_execution_date = exit_execution_date
          ),
          trade_return_open_to_open = NA_real_,
          stringsAsFactors = FALSE
        )
        open_trade <- NULL
      }
      previous_state <- position_state
    }
    if (!is.null(open_trade)) {
      k <- k + 1L
      source_row <- open_trade$source_row
      rows[[k]] <- data.frame(
        schema_version = g5_wfa_amd_ema_oos_measurement_contract_schema_version(),
        measurement_contract_id = as.character(manifest$measurement_contract_id[[1L]]),
        measurement_run_id = measurement_run_id,
        application_run_id = as.character(source_row$source_application_boundary_id[[1L]]),
        application_row_id = as.character(source_row$source_application_row_id[[1L]]),
        application_artifact_hash = as.character(manifest$source_application_artifact_hash[[1L]]),
        parameter_pack_id = as.character(source_row$frozen_parameter_id[[1L]]),
        as_of_timestamp = as.character(source_row$as_of_timestamp[[1L]]),
        oos_fold_id = as.character(source_row$fold_id[[1L]]),
        comparison_order = as.integer(source_row$comparison_order[[1L]]),
        subject_id = "amd_ema_long_cash",
        symbol = "AMD",
        strategy_id = "ema_long_cash",
        trade_id = open_trade$trade_id,
        trade_status = "open_trade_unclosed",
        position_state = "long",
        entry_signal_session_date = open_trade$entry_signal_session_date,
        entry_execution_session_date = open_trade$entry_execution_session_date,
        exit_signal_session_date = as.Date(NA),
        exit_execution_session_date = as.Date(NA),
        share_quantity = NA_real_,
        trade_pnl = NA_real_,
        holding_period_sessions = NA_integer_,
        trade_return_open_to_open = NA_real_,
        stringsAsFactors = FALSE
      )
    }
  }

  trade_measurements <- if (length(rows) == 0L) {
    g5_empty_wfa_amd_ema_oos_trade_lifecycle_measurements()
  } else {
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    out[g5_wfa_required_amd_ema_oos_trade_measurement_columns()]
  }
  g5_validate_wfa_amd_ema_oos_trade_lifecycle_measurements(
    trade_measurements = trade_measurements,
    oos_measurement_contract = oos_measurement_contract,
    signal_position_application = signal_position_application,
    parameter_application_boundary = parameter_application_boundary
  )
}

g5_validate_wfa_amd_ema_oos_trade_lifecycle_measurements <- function(
  trade_measurements,
  oos_measurement_contract,
  signal_position_application = NULL,
  parameter_application_boundary = NULL
) {
  if (!is.data.frame(trade_measurements)) {
    g5_stop("AMD EMA OOS trade lifecycle measurements must be a data.frame.")
  }
  oos_measurement_contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    oos_measurement_contract
  )
  required <- g5_wfa_required_amd_ema_oos_trade_measurement_columns()
  g5_wfa_reject_amd_ema_oos_measurement_extra_columns(
    trade_measurements,
    required,
    "AMD EMA OOS trade lifecycle measurements"
  )
  manifest <- oos_measurement_contract$run_manifest
  if (nrow(trade_measurements) == 0L) {
    return(trade_measurements)
  }
  if (any(as.character(trade_measurements$schema_version) !=
          g5_wfa_amd_ema_oos_measurement_contract_schema_version())) {
    g5_stop("AMD EMA OOS trade lifecycle measurements have an unexpected schema_version.")
  }
  if (any(as.character(trade_measurements$measurement_contract_id) !=
          as.character(manifest$measurement_contract_id[[1L]]))) {
    g5_stop("AMD EMA OOS trade lifecycle measurements must reference the measurement_contract_id.")
  }
  if (any(duplicated(as.character(trade_measurements$trade_id)))) {
    g5_stop("AMD EMA OOS trade lifecycle measurement trade_id values must be unique.")
  }
  allowed_status <- c("closed_trade_lifecycle", "open_trade_unclosed")
  if (any(!(as.character(trade_measurements$trade_status) %in% allowed_status))) {
    g5_stop("AMD EMA OOS trade lifecycle measurements have invalid trade_status values.")
  }
  if (any(as.character(trade_measurements$subject_id) != "amd_ema_long_cash") ||
      any(as.character(trade_measurements$symbol) != "AMD") ||
      any(as.character(trade_measurements$strategy_id) != "ema_long_cash") ||
      any(as.character(trade_measurements$position_state) != "long")) {
    g5_stop("AMD EMA OOS trade lifecycle measurements must contain AMD EMA candidate lifecycle rows only.")
  }
  if (any(!is.na(trade_measurements$share_quantity)) ||
      any(!is.na(trade_measurements$trade_pnl)) ||
      any(!is.na(trade_measurements$trade_return_open_to_open))) {
    g5_stop("AMD EMA OOS trade lifecycle measurements must not compute share quantity, trade PnL, or trade return.")
  }

  date_cols <- c(
    "entry_signal_session_date",
    "entry_execution_session_date",
    "exit_signal_session_date",
    "exit_execution_session_date"
  )
  for (col in date_cols) {
    trade_measurements[[col]] <- as.Date(trade_measurements[[col]])
  }
  if (any(is.na(trade_measurements$entry_signal_session_date)) ||
      any(is.na(trade_measurements$entry_execution_session_date)) ||
      any(trade_measurements$entry_execution_session_date <=
        trade_measurements$entry_signal_session_date)) {
    g5_stop("AMD EMA OOS trade lifecycle measurements have ambiguous entry execution dates.")
  }
  closed <- as.character(trade_measurements$trade_status) == "closed_trade_lifecycle"
  open <- as.character(trade_measurements$trade_status) == "open_trade_unclosed"
  if (any(is.na(trade_measurements$exit_signal_session_date[closed])) ||
      any(is.na(trade_measurements$exit_execution_session_date[closed])) ||
      any(trade_measurements$exit_signal_session_date[closed] <
        trade_measurements$entry_signal_session_date[closed]) ||
      any(trade_measurements$exit_execution_session_date[closed] <=
        trade_measurements$exit_signal_session_date[closed])) {
    g5_stop("AMD EMA OOS trade lifecycle measurements have ambiguous exit execution dates.")
  }
  if (any(!is.na(trade_measurements$exit_signal_session_date[open])) ||
      any(!is.na(trade_measurements$exit_execution_session_date[open]))) {
    g5_stop("AMD EMA OOS open trade lifecycle rows must not record exit dates.")
  }
  holding <- suppressWarnings(as.integer(trade_measurements$holding_period_sessions))
  if (any(is.na(holding[closed])) || any(holding[closed] < 0L)) {
    g5_stop("AMD EMA OOS closed trade lifecycle rows require deterministic non-negative holding_period_sessions.")
  }
  if (any(!is.na(holding[open]))) {
    g5_stop("AMD EMA OOS open trade lifecycle rows must leave holding_period_sessions uncomputed.")
  }
  trade_measurements$holding_period_sessions <- holding

  if (!is.null(signal_position_application)) {
    signal_position_application <- g5_validate_wfa_amd_ema_oos_signal_position_application(
      signal_position_application
    )
    signal_manifest <- signal_position_application$run_manifest
    if (!identical(
      as.character(signal_manifest$source_application_boundary_id[[1L]]),
      as.character(manifest$source_application_boundary_id[[1L]])
    )) {
      g5_stop("AMD EMA OOS trade lifecycle measurements must preserve frozen signal/position application lineage.")
    }
    candidate_ids <- unique(as.character(
      signal_position_application$signal_position_surface$source_application_row_id[
        signal_position_application$signal_position_surface$subject_id == "amd_ema_long_cash"
      ]
    ))
    unknown_ids <- setdiff(as.character(trade_measurements$application_row_id), candidate_ids)
    if (length(unknown_ids) > 0L) {
      g5_stop(paste(
        "AMD EMA OOS trade lifecycle measurements reference unknown application_row_id values:",
        paste(unknown_ids, collapse = ", ")
      ))
    }
  }
  if (!is.null(parameter_application_boundary)) {
    parameter_application_boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
      parameter_application_boundary
    )
    candidate_ids <- as.character(parameter_application_boundary$application_surface$application_row_id[
      parameter_application_boundary$application_surface$subject_id == "amd_ema_long_cash"
    ])
    unknown_ids <- setdiff(as.character(trade_measurements$application_row_id), candidate_ids)
    if (length(unknown_ids) > 0L) {
      g5_stop(paste(
        "AMD EMA OOS trade lifecycle measurements reference unknown application_row_id values:",
        paste(unknown_ids, collapse = ", ")
      ))
    }
  }
  trade_measurements
}

g5_wfa_amd_ema_oos_surface_key <- function(application_row_id, session_date, comparison_order, subject_id) {
  paste(
    as.character(application_row_id),
    format(as.Date(session_date), "%Y-%m-%d"),
    as.integer(comparison_order),
    as.character(subject_id),
    sep = "|"
  )
}

g5_validate_wfa_amd_ema_oos_measurement_stack <- function(
  oos_measurement_contract,
  parameter_application_boundary,
  signal_position_application,
  session_measurements,
  trade_lifecycle_measurements = NULL,
  bars
) {
  oos_measurement_contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    oos_measurement_contract
  )
  parameter_application_boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
    parameter_application_boundary
  )
  signal_position_application <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    signal_position_application
  )
  session_measurements <- g5_validate_wfa_amd_ema_oos_session_measurements(
    session_measurements = session_measurements,
    oos_measurement_contract = oos_measurement_contract,
    parameter_application_boundary = parameter_application_boundary
  )
  if (!is.null(trade_lifecycle_measurements)) {
    trade_lifecycle_measurements <- g5_validate_wfa_amd_ema_oos_trade_lifecycle_measurements(
      trade_measurements = trade_lifecycle_measurements,
      oos_measurement_contract = oos_measurement_contract,
      signal_position_application = signal_position_application,
      parameter_application_boundary = parameter_application_boundary
    )
  }

  manifest <- oos_measurement_contract$run_manifest
  application_manifest <- parameter_application_boundary$run_manifest
  application_surface <- parameter_application_boundary$application_surface
  signal_manifest <- signal_position_application$run_manifest
  signal_surface <- signal_position_application$signal_position_surface
  bars <- g5_wfa_prepare_amd_ema_oos_measurement_bars(
    bars = bars,
    as_of_timestamp = manifest$as_of_timestamp[[1L]],
    latest_completed_session = manifest$latest_completed_session[[1L]]
  )

  if (!identical(
    as.character(manifest$source_application_boundary_id[[1L]]),
    as.character(application_manifest$application_boundary_id[[1L]])
  ) ||
      !identical(
        as.character(signal_manifest$source_application_boundary_id[[1L]]),
        as.character(application_manifest$application_boundary_id[[1L]])
      )) {
    g5_stop("AMD EMA OOS measurement stack must preserve frozen application boundary lineage.")
  }
  expected_as_of <- as.character(manifest$as_of_timestamp[[1L]])
  expected_latest <- as.Date(manifest$latest_completed_session[[1L]])
  as_of_values <- c(
    as.character(application_manifest$as_of_timestamp),
    as.character(application_surface$as_of_timestamp),
    as.character(signal_manifest$as_of_timestamp),
    as.character(signal_surface$as_of_timestamp),
    as.character(session_measurements$as_of_timestamp)
  )
  latest_values <- c(
    as.Date(application_manifest$latest_completed_session),
    as.Date(application_surface$latest_completed_session),
    as.Date(signal_manifest$latest_completed_session),
    as.Date(signal_surface$latest_completed_session)
  )
  if (!is.null(trade_lifecycle_measurements) && nrow(trade_lifecycle_measurements) > 0L) {
    as_of_values <- c(as_of_values, as.character(trade_lifecycle_measurements$as_of_timestamp))
  }
  if (any(as_of_values != expected_as_of) || any(latest_values != expected_latest)) {
    g5_stop("AMD EMA OOS measurement stack must preserve explicit as_of_timestamp and latest_completed_session across surfaces.")
  }

  expected_parts <- list()
  k <- 0L
  amd_session_dates <- as.Date(bars$session_date)
  for (i in seq_len(nrow(application_surface))) {
    app_row <- application_surface[i, , drop = FALSE]
    oos_dates <- amd_session_dates[
      amd_session_dates >= as.Date(app_row$oos_start_date[[1L]]) &
        amd_session_dates <= as.Date(app_row$oos_end_date[[1L]])
    ]
    if (length(oos_dates) != as.integer(app_row$amd_oos_row_count[[1L]])) {
      g5_stop("AMD EMA OOS measurement stack canonical bars do not match frozen OOS coverage.")
    }
    for (session_date in oos_dates) {
      k <- k + 1L
      expected_parts[[k]] <- data.frame(
        application_row_id = as.character(app_row$application_row_id[[1L]]),
        session_date = as.Date(session_date),
        comparison_order = as.integer(app_row$comparison_order[[1L]]),
        subject_id = as.character(app_row$subject_id[[1L]]),
        stringsAsFactors = FALSE
      )
    }
  }
  expected_rows <- do.call(rbind, expected_parts)
  expected_keys <- g5_wfa_amd_ema_oos_surface_key(
    expected_rows$application_row_id,
    expected_rows$session_date,
    expected_rows$comparison_order,
    expected_rows$subject_id
  )
  signal_keys <- g5_wfa_amd_ema_oos_surface_key(
    signal_surface$source_application_row_id,
    signal_surface$session_date,
    signal_surface$comparison_order,
    signal_surface$subject_id
  )
  session_keys <- g5_wfa_amd_ema_oos_surface_key(
    session_measurements$application_row_id,
    session_measurements$session_date,
    session_measurements$comparison_order,
    session_measurements$subject_id
  )
  if (!identical(signal_keys, expected_keys) || !identical(session_keys, expected_keys)) {
    g5_stop("AMD EMA OOS measurement stack must preserve exact frozen OOS coverage across application, signal/position, and session measurement rows.")
  }

  for (key in unique(paste(expected_rows$session_date, expected_rows$application_row_id))) {
    rows <- expected_rows[paste(expected_rows$session_date, expected_rows$application_row_id) == key, , drop = FALSE]
    if (nrow(rows) != 1L) {
      g5_stop("AMD EMA OOS measurement stack has duplicate expected application/session rows.")
    }
  }
  for (key in unique(paste(signal_surface$fold_id, signal_surface$session_date))) {
    signal_rows <- signal_surface[paste(signal_surface$fold_id, signal_surface$session_date) == key, , drop = FALSE]
    session_rows <- session_measurements[paste(session_measurements$oos_fold_id, session_measurements$session_date) == key, , drop = FALSE]
    if (!identical(as.integer(signal_rows$comparison_order), c(1L, 2L)) ||
        !identical(as.character(signal_rows$subject_id), c("no_trade_cash", "amd_ema_long_cash")) ||
        !identical(as.integer(session_rows$comparison_order), c(1L, 2L)) ||
        !identical(as.character(session_rows$subject_id), c("no_trade_cash", "amd_ema_long_cash"))) {
      g5_stop("AMD EMA OOS measurement stack must preserve no-trade-first comparison discipline for every OOS session.")
    }
  }
  if (any(as.character(session_measurements$application_artifact_hash) !=
          as.character(manifest$source_application_artifact_hash[[1L]]))) {
    g5_stop("AMD EMA OOS measurement stack must preserve source application artifact hash lineage.")
  }
  if (!is.null(trade_lifecycle_measurements) && nrow(trade_lifecycle_measurements) > 0L) {
    if (any(as.character(trade_lifecycle_measurements$application_artifact_hash) !=
            as.character(manifest$source_application_artifact_hash[[1L]]))) {
      g5_stop("AMD EMA OOS measurement stack trade lifecycle rows must preserve source application artifact hash lineage.")
    }
    candidate_application_ids <- unique(as.character(
      application_surface$application_row_id[application_surface$subject_id == "amd_ema_long_cash"]
    ))
    if (length(setdiff(as.character(trade_lifecycle_measurements$application_row_id), candidate_application_ids)) > 0L) {
      g5_stop("AMD EMA OOS measurement stack trade lifecycle rows must reference known AMD EMA application rows.")
    }
  }

  invisible(list(
    oos_measurement_contract = oos_measurement_contract,
    parameter_application_boundary = parameter_application_boundary,
    signal_position_application = signal_position_application,
    session_measurements = session_measurements,
    trade_lifecycle_measurements = trade_lifecycle_measurements
  ))
}

g5_write_wfa_amd_ema_oos_measurement_contract_csvs <- function(
  oos_measurement_contract,
  manifest_path = NULL,
  field_registry_path = NULL,
  require_ignored_run_path = TRUE
) {
  oos_measurement_contract <- g5_validate_wfa_amd_ema_oos_measurement_contract(
    oos_measurement_contract
  )
  manifest <- oos_measurement_contract$run_manifest
  field_registry <- oos_measurement_contract$field_registry
  if (is.null(manifest_path)) {
    manifest_path <- as.character(manifest$measurement_manifest_path[[1L]])
  }
  if (is.null(field_registry_path)) {
    field_registry_path <- as.character(manifest$measurement_field_registry_path[[1L]])
  }
  for (path in c(manifest_path, field_registry_path)) {
    if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
      g5_stop("AMD EMA OOS measurement contract output paths must be non-empty.")
    }
    if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
      g5_stop("AMD EMA OOS measurement contract CSVs must be written under ignored runs/ paths.")
    }
  }
  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(field_registry_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
  utils::write.csv(field_registry, field_registry_path, row.names = FALSE, na = "")
  invisible(list(
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = FALSE),
    field_registry_path = normalizePath(field_registry_path, winslash = "/", mustWork = FALSE)
  ))
}

g5_write_wfa_amd_ema_oos_measurement_readiness_csv <- function(
  readiness_review,
  path,
  require_ignored_run_path = TRUE
) {
  readiness_review <- g5_validate_wfa_amd_ema_oos_measurement_readiness_review(readiness_review)
  if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
    g5_stop("AMD EMA OOS measurement readiness output path must be one non-empty value.")
  }
  path <- as.character(path)
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA OOS measurement readiness CSV must be written under ignored runs/ paths.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(readiness_review, path, row.names = FALSE, na = "")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
