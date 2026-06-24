# Gen5 AMD EMA long/cash narrow research evaluation gate.

g5_wfa_amd_ema_evaluation_gate_schema_version <- function() {
  "g5_wfa_amd_ema_evaluation_gate_v0"
}

g5_wfa_required_amd_ema_evaluation_gate_columns <- function() {
  c(
    "schema_version",
    "gate_id",
    "gate_status",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "strategy_direction",
    "evaluation_slice_scope",
    "operation_mode",
    "source_poc_run_id",
    "minimal_poc_closeout_status",
    "minimal_poc_closeout_check_count",
    "readiness_review_id",
    "baseline_readiness_status",
    "included_baseline_family_ids",
    "source_handoff_reference",
    "source_gate_manifest_csv",
    "handoff_gate_status",
    "handoff_review_required",
    "handoff_review_accepted",
    "as_of_timestamp",
    "latest_completed_session",
    "fold_count",
    "accepted_readiness_evidence_status",
    "operator_gate_scope_status",
    "allowed_input_artifacts",
    "prohibited_input_artifacts",
    "train_only_fit_rule_status",
    "ema_parameter_rule_status",
    "oos_application_rule_status",
    "no_trade_baseline_status",
    "reserved_baseline_scope_status",
    "gate_manifest_path",
    "output_artifact_policy",
    "evaluation_authorization_status",
    "implementation_status",
    "return_computation_scope_status",
    "cash_yield_scope_status",
    "trade_accounting_scope_status",
    "performance_metric_scope_status",
    "allocation_status",
    "leverage_status",
    "live_advice_status",
    "execution_status",
    "dashboard_status",
    "broader_strategy_family_status",
    "provider_scope_status",
    "leakage_no_provider_calls",
    "leakage_no_credentials",
    "leakage_no_unmanifested_cache",
    "leakage_no_latest_session_inference",
    "leakage_no_oos_outcome_authority",
    "leakage_no_oos_fitting",
    "leakage_no_oos_parameter_selection",
    "leakage_no_allocation_or_live_use"
  )
}

g5_wfa_validate_amd_ema_readiness_evidence <- function(
  minimal_poc_closeout,
  baseline_readiness_review,
  operator_accepts_readiness_evidence = FALSE
) {
  if (!isTRUE(operator_accepts_readiness_evidence)) {
    g5_stop("AMD EMA evaluation gate requires explicit operator acceptance of readiness evidence.")
  }

  g5_wfa_require_columns(
    minimal_poc_closeout,
    g5_wfa_required_minimal_poc_closeout_columns(),
    "minimal WFA POC closeout validation"
  )
  if (nrow(minimal_poc_closeout) == 0L) {
    g5_stop("minimal WFA POC closeout validation must contain at least one check row.")
  }
  if (any(duplicated(as.character(minimal_poc_closeout$check_id)))) {
    g5_stop("minimal WFA POC closeout validation check_id values must be unique.")
  }
  if (length(unique(as.character(minimal_poc_closeout$poc_run_id))) != 1L ||
      !nzchar(as.character(minimal_poc_closeout$poc_run_id[[1L]]))) {
    g5_stop("minimal WFA POC closeout validation must reference one poc_run_id.")
  }
  if (any(as.character(minimal_poc_closeout$check_status) != "PASS")) {
    g5_stop("AMD EMA evaluation gate requires PASS closeout checks.")
  }
  if (any(as.character(minimal_poc_closeout$review_status) !=
          "closeout_ready_no_evaluation_authorized")) {
    g5_stop("AMD EMA evaluation gate requires accepted closeout readiness evidence.")
  }

  required_checks <- c(
    "accepted_handoff_lineage",
    "explicit_quarterly_fold_geometry",
    "train_oos_split_evidence",
    "frozen_no_active_decision_evidence",
    "baseline_readiness",
    "stop_states_preserved",
    "leakage_attestations"
  )
  missing_checks <- setdiff(required_checks, as.character(minimal_poc_closeout$check_id))
  if (length(missing_checks) > 0L) {
    g5_stop(paste(
      "AMD EMA evaluation gate is missing required closeout checks:",
      paste(missing_checks, collapse = ", ")
    ))
  }
  closeout_evidence <- stats::setNames(
    as.character(minimal_poc_closeout$evidence_value),
    as.character(minimal_poc_closeout$check_id)
  )
  if (!grepl(
    "not_authorized_no_oos_evaluation",
    closeout_evidence[["stop_states_preserved"]],
    fixed = TRUE
  )) {
    g5_stop("AMD EMA evaluation gate requires prior STOP-state closeout evidence.")
  }
  if (!grepl(
    "leakage_no_provider_calls",
    closeout_evidence[["leakage_attestations"]],
    fixed = TRUE
  )) {
    g5_stop("AMD EMA evaluation gate requires prior leakage attestation closeout evidence.")
  }

  baseline_readiness_review <- g5_validate_wfa_baseline_evaluation_contract_readiness_review(
    baseline_readiness_review
  )
  if (!identical(
    as.character(baseline_readiness_review$readiness_status[[1L]]),
    "ready_for_operator_review_no_evaluation_computed"
  )) {
    g5_stop("AMD EMA evaluation gate requires baseline readiness review evidence.")
  }
  if (!grepl(
    "no_trade_cash",
    as.character(baseline_readiness_review$included_baseline_family_ids[[1L]]),
    fixed = TRUE
  )) {
    g5_stop("AMD EMA evaluation gate requires no_trade_cash baseline readiness.")
  }
  if (!identical(
    as.character(baseline_readiness_review$calculation_stop_status[[1L]]),
    "returns_cash_yield_benchmark_math_metrics_all_not_implemented"
  )) {
    g5_stop("AMD EMA evaluation gate requires calculation STOP readiness evidence.")
  }
  if (!identical(
    as.character(baseline_readiness_review$leakage_attestation_status[[1L]]),
    "all_contract_leakage_attestations_true"
  )) {
    g5_stop("AMD EMA evaluation gate requires clean baseline readiness leakage attestations.")
  }

  closeout_handoff <- normalizePath(
    closeout_evidence[["accepted_handoff_lineage"]],
    winslash = "/",
    mustWork = FALSE
  )
  readiness_handoff <- normalizePath(
    as.character(baseline_readiness_review$source_gate_manifest_csv[[1L]]),
    winslash = "/",
    mustWork = FALSE
  )
  if (!identical(closeout_handoff, readiness_handoff)) {
    g5_stop("AMD EMA evaluation gate requires closeout and baseline readiness to share source handoff lineage.")
  }

  list(
    minimal_poc_closeout = minimal_poc_closeout,
    baseline_readiness_review = baseline_readiness_review,
    closeout_evidence = closeout_evidence
  )
}

g5_wfa_amd_ema_evaluation_gate_path <- function(
  output_dir,
  gate_id,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("AMD EMA evaluation gate output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    g5_wfa_sanitize_id_component(gate_id, "gate_id"),
    "amd_ema_evaluation_gate_manifest.csv"
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA evaluation gate artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_build_wfa_amd_ema_evaluation_gate <- function(
  minimal_poc_closeout,
  baseline_readiness_review,
  output_dir = file.path("runs", "wfa_amd_ema_evaluation_gate"),
  operator_accepts_readiness_evidence = FALSE
) {
  evidence <- g5_wfa_validate_amd_ema_readiness_evidence(
    minimal_poc_closeout = minimal_poc_closeout,
    baseline_readiness_review = baseline_readiness_review,
    operator_accepts_readiness_evidence = operator_accepts_readiness_evidence
  )
  minimal_poc_closeout <- evidence$minimal_poc_closeout
  baseline_readiness_review <- evidence$baseline_readiness_review

  gate_id <- paste(
    "amd_ema_eval_gate",
    g5_wfa_sanitize_id_component(baseline_readiness_review$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(baseline_readiness_review$readiness_review_id[[1L]], "readiness_review_id"),
    sep = "_"
  )

  out <- data.frame(
    schema_version = g5_wfa_amd_ema_evaluation_gate_schema_version(),
    gate_id = gate_id,
    gate_status = "GO_NARROW_RESEARCH_EVALUATION_ONLY",
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
    strategy_direction = "long_or_cash_only",
    evaluation_slice_scope = "single_symbol_amd_ema_long_cash_only",
    operation_mode = "research_only_non_live_non_dashboard",
    source_poc_run_id = as.character(minimal_poc_closeout$poc_run_id[[1L]]),
    minimal_poc_closeout_status = "accepted_pass_closeout_ready_no_prior_evaluation",
    minimal_poc_closeout_check_count = as.integer(nrow(minimal_poc_closeout)),
    readiness_review_id = as.character(baseline_readiness_review$readiness_review_id[[1L]]),
    baseline_readiness_status = as.character(baseline_readiness_review$readiness_status[[1L]]),
    included_baseline_family_ids = as.character(baseline_readiness_review$included_baseline_family_ids[[1L]]),
    source_handoff_reference = as.character(baseline_readiness_review$source_handoff_reference[[1L]]),
    source_gate_manifest_csv = as.character(baseline_readiness_review$source_gate_manifest_csv[[1L]]),
    handoff_gate_status = as.character(baseline_readiness_review$handoff_gate_status[[1L]]),
    handoff_review_required = as.logical(baseline_readiness_review$handoff_review_required[[1L]]),
    handoff_review_accepted = as.logical(baseline_readiness_review$handoff_review_accepted[[1L]]),
    as_of_timestamp = as.character(baseline_readiness_review$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(baseline_readiness_review$latest_completed_session[[1L]]),
    fold_count = as.integer(baseline_readiness_review$fold_count[[1L]]),
    accepted_readiness_evidence_status = "operator_prompt_accepts_minimal_poc_closeout_and_baseline_readiness",
    operator_gate_scope_status = "explicit_prompt_opened_amd_ema_only_with_live_dashboard_allocation_execution_exclusions",
    allowed_input_artifacts = paste(
      c(
        "accepted_workbench_handoff_manifest",
        "explicit_fold_geometry",
        "train_oos_split_audit",
        "frozen_fold_evidence",
        "minimal_poc_closeout_validation",
        "baseline_evaluation_contract_readiness_review"
      ),
      collapse = ";"
    ),
    prohibited_input_artifacts = paste(
      c(
        "provider_api",
        "credentials",
        "unmanifested_cache",
        "independent_latest_session_authority",
        "oos_outcome_parameter_selection",
        "live_advice_inputs",
        "dashboard_inputs",
        "allocation_or_leverage_inputs"
      ),
      collapse = ";"
    ),
    train_only_fit_rule_status = "authorized_for_future_train_only_ema_parameter_freeze_no_oos_fit",
    ema_parameter_rule_status = "authorized_for_single_amd_ema_family_no_broader_strategy_search",
    oos_application_rule_status = "authorized_only_after_fold_decision_is_frozen_before_oos_measurement",
    no_trade_baseline_status = "required_first_class_comparison_for_every_fold",
    reserved_baseline_scope_status = "reserved_baseline_readiness_may_be_referenced_no_new_family_authorized",
    gate_manifest_path = g5_wfa_amd_ema_evaluation_gate_path(
      output_dir = output_dir,
      gate_id = gate_id
    ),
    output_artifact_policy = "generated_outputs_must_remain_under_ignored_runs_paths",
    evaluation_authorization_status = "authorized_narrow_non_live_non_dashboard_amd_ema_long_cash",
    implementation_status = "gate_open_contract_only_no_strategy_results_computed",
    return_computation_scope_status = "authorized_for_future_oos_measurement_contract_only_not_computed_here",
    cash_yield_scope_status = "authorized_for_future_no_trade_assumption_contract_only_not_computed_here",
    trade_accounting_scope_status = "authorized_for_future_long_or_cash_audit_contract_only_not_computed_here",
    performance_metric_scope_status = "authorized_for_future_predeclared_oos_metrics_contract_only_not_computed_here",
    allocation_status = "not_authorized_no_allocation_or_weighting",
    leverage_status = "not_authorized_no_leverage_analysis_or_value_add",
    live_advice_status = "not_authorized_no_live_advice",
    execution_status = "not_authorized_no_orders_or_execution",
    dashboard_status = "not_authorized_no_dashboard",
    broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only",
    provider_scope_status = "no_provider_calls_handoff_only_alpaca_adjusted_daily_lineage",
    leakage_no_provider_calls = TRUE,
    leakage_no_credentials = TRUE,
    leakage_no_unmanifested_cache = TRUE,
    leakage_no_latest_session_inference = TRUE,
    leakage_no_oos_outcome_authority = TRUE,
    leakage_no_oos_fitting = TRUE,
    leakage_no_oos_parameter_selection = TRUE,
    leakage_no_allocation_or_live_use = TRUE,
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out[g5_wfa_required_amd_ema_evaluation_gate_columns()]
}

g5_validate_wfa_amd_ema_evaluation_gate <- function(gate) {
  g5_wfa_require_columns(
    gate,
    g5_wfa_required_amd_ema_evaluation_gate_columns(),
    "AMD EMA evaluation gate"
  )
  if (nrow(gate) != 1L) {
    g5_stop("AMD EMA evaluation gate must contain exactly one row.")
  }
  if (!identical(
    as.character(gate$schema_version[[1L]]),
    g5_wfa_amd_ema_evaluation_gate_schema_version()
  )) {
    g5_stop("AMD EMA evaluation gate has an unexpected schema_version.")
  }
  expected_values <- c(
    gate_status = "GO_NARROW_RESEARCH_EVALUATION_ONLY",
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
    strategy_direction = "long_or_cash_only",
    operation_mode = "research_only_non_live_non_dashboard",
    evaluation_authorization_status = "authorized_narrow_non_live_non_dashboard_amd_ema_long_cash",
    implementation_status = "gate_open_contract_only_no_strategy_results_computed",
    allocation_status = "not_authorized_no_allocation_or_weighting",
    leverage_status = "not_authorized_no_leverage_analysis_or_value_add",
    live_advice_status = "not_authorized_no_live_advice",
    execution_status = "not_authorized_no_orders_or_execution",
    dashboard_status = "not_authorized_no_dashboard",
    broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only"
  )
  for (col in names(expected_values)) {
    if (!identical(as.character(gate[[col]][[1L]]), expected_values[[col]])) {
      g5_stop(paste("AMD EMA evaluation gate has invalid", col))
    }
  }
  if (!grepl("no_trade_cash", as.character(gate$included_baseline_family_ids[[1L]]), fixed = TRUE)) {
    g5_stop("AMD EMA evaluation gate must preserve no_trade_cash baseline readiness.")
  }
  if (as.integer(gate$fold_count[[1L]]) <= 0L) {
    g5_stop("AMD EMA evaluation gate must reference at least one fold.")
  }
  if (!g5_wfa_path_looks_ignored_run_path(gate$gate_manifest_path[[1L]])) {
    g5_stop("AMD EMA evaluation gate manifest path must be under ignored runs/ paths.")
  }

  leakage_cols <- c(
    "leakage_no_provider_calls",
    "leakage_no_credentials",
    "leakage_no_unmanifested_cache",
    "leakage_no_latest_session_inference",
    "leakage_no_oos_outcome_authority",
    "leakage_no_oos_fitting",
    "leakage_no_oos_parameter_selection",
    "leakage_no_allocation_or_live_use"
  )
  for (col in leakage_cols) {
    if (!isTRUE(as.logical(gate[[col]][[1L]]))) {
      g5_stop(paste("AMD EMA evaluation gate leakage attestation failed:", col))
    }
  }
  gate
}
