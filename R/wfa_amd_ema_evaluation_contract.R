# Gen5 AMD EMA long/cash narrow evaluation contract scaffold.

g5_wfa_amd_ema_evaluation_contract_schema_version <- function() {
  "g5_wfa_amd_ema_evaluation_contract_v0"
}

g5_wfa_required_amd_ema_contract_manifest_columns <- function() {
  c(
    "schema_version",
    "contract_id",
    "source_gate_id",
    "source_gate_status",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "strategy_direction",
    "operation_mode",
    "source_poc_run_id",
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
    "first_fold_id",
    "last_fold_id",
    "first_oos_start_date",
    "last_oos_end_date",
    "contract_manifest_path",
    "review_surface_path",
    "artifact_path_policy",
    "no_trade_comparison_status",
    "candidate_contract_status",
    "train_only_fit_contract_status",
    "ema_parameter_contract_status",
    "oos_application_contract_status",
    "baseline_contract_status",
    "evaluation_authorization_status",
    "result_status",
    "return_computation_status",
    "cash_yield_status",
    "trade_accounting_status",
    "performance_metric_status",
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
    "leakage_no_return_or_metric_computation",
    "leakage_no_allocation_or_live_use"
  )
}

g5_wfa_required_amd_ema_contract_review_columns <- function() {
  c(
    "schema_version",
    "contract_id",
    "review_row_id",
    "fold_id",
    "comparison_order",
    "comparison_role",
    "subject_id",
    "subject_type",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "baseline_family_id",
    "frozen_evidence_id",
    "source_handoff_reference",
    "source_gate_manifest_csv",
    "handoff_gate_status",
    "handoff_review_required",
    "handoff_review_accepted",
    "as_of_timestamp",
    "latest_completed_session",
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "amd_train_row_count",
    "amd_oos_row_count",
    "amd_train_availability_status",
    "amd_oos_availability_status",
    "amd_fold_availability_status",
    "artifact_path",
    "artifact_path_policy",
    "application_status",
    "evaluation_result_status",
    "ema_signal_status",
    "ema_parameter_status",
    "train_fit_status",
    "oos_application_rule_status",
    "cash_no_position_assumption_status",
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
    "review_status",
    "review_required_reason",
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

g5_wfa_amd_ema_contract_artifact_path <- function(
  output_dir,
  contract_id,
  artifact_name,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("AMD EMA evaluation contract output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    g5_wfa_sanitize_id_component(contract_id, "contract_id"),
    artifact_name
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA evaluation contract artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_wfa_validate_amd_ema_contract_fold_geometry <- function(fold_geometry, amd_ema_gate) {
  g5_wfa_require_columns(
    fold_geometry,
    g5_wfa_required_fold_geometry_columns(),
    "AMD EMA evaluation contract fold geometry"
  )
  if (nrow(fold_geometry) == 0L) {
    g5_stop("AMD EMA evaluation contract requires at least one fold.")
  }
  if (any(duplicated(as.character(fold_geometry$fold_id)))) {
    g5_stop("AMD EMA evaluation contract fold_id values must be unique.")
  }
  date_cols <- c(
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "latest_completed_session"
  )
  for (col in date_cols) {
    fold_geometry[[col]] <- as.Date(fold_geometry[[col]])
    if (any(is.na(fold_geometry[[col]]))) {
      g5_stop(paste("AMD EMA evaluation contract fold geometry has invalid dates in", col))
    }
  }
  if (any(fold_geometry$train_end_date >= fold_geometry$oos_start_date)) {
    g5_stop("AMD EMA evaluation contract requires TRAIN to end before OOS.")
  }
  if (any(fold_geometry$oos_end_date > as.Date(amd_ema_gate$latest_completed_session[[1L]]))) {
    g5_stop("AMD EMA evaluation contract OOS windows must be bounded by latest_completed_session.")
  }
  if (any(as.character(fold_geometry$source_handoff_reference) !=
          as.character(amd_ema_gate$source_handoff_reference[[1L]]))) {
    g5_stop("AMD EMA evaluation contract fold geometry must preserve source_handoff_reference lineage.")
  }
  if (any(as.character(fold_geometry$as_of_timestamp) !=
          as.character(amd_ema_gate$as_of_timestamp[[1L]]))) {
    g5_stop("AMD EMA evaluation contract fold geometry must match gate as_of_timestamp.")
  }
  if (any(as.Date(fold_geometry$latest_completed_session) !=
          as.Date(amd_ema_gate$latest_completed_session[[1L]]))) {
    g5_stop("AMD EMA evaluation contract fold geometry must match gate latest_completed_session.")
  }
  if (any(as.character(fold_geometry$geometry_search_policy) !=
          "none_single_explicit_quarterly_geometry")) {
    g5_stop("AMD EMA evaluation contract requires the explicit single quarterly fold geometry.")
  }
  rownames(fold_geometry) <- NULL
  fold_geometry
}

g5_wfa_validate_amd_ema_contract_split_audit <- function(split_audit, fold_geometry) {
  split_summary <- g5_wfa_validate_split_audit_for_evidence(split_audit, fold_geometry)
  if (is.null(split_audit$symbol_availability)) {
    g5_stop("AMD EMA evaluation contract requires fold-local symbol availability evidence.")
  }
  g5_wfa_require_columns(
    split_audit$symbol_availability,
    g5_wfa_required_fold_symbol_availability_columns(),
    "AMD EMA evaluation contract symbol availability"
  )
  amd_availability <- split_audit$symbol_availability[
    as.character(split_audit$symbol_availability$symbol) == "AMD",
    ,
    drop = FALSE
  ]
  if (nrow(amd_availability) != nrow(fold_geometry)) {
    g5_stop("AMD EMA evaluation contract requires one AMD availability row per fold.")
  }
  if (!identical(as.character(amd_availability$fold_id), as.character(fold_geometry$fold_id))) {
    g5_stop("AMD EMA evaluation contract AMD availability fold order must match fold geometry.")
  }
  if (any(as.integer(amd_availability$train_row_count) < 0L) ||
      any(as.integer(amd_availability$oos_row_count) < 0L)) {
    g5_stop("AMD EMA evaluation contract AMD availability row counts must be non-negative.")
  }
  list(
    split_summary = split_summary,
    amd_availability = amd_availability
  )
}

g5_wfa_validate_amd_ema_contract_frozen_evidence <- function(frozen_fold_evidence, fold_geometry, amd_ema_gate) {
  frozen_fold_evidence <- g5_wfa_validate_frozen_evidence_for_baselines(
    frozen_fold_evidence,
    fold_geometry
  )
  if (any(as.character(frozen_fold_evidence$source_gate_manifest_csv) !=
          as.character(amd_ema_gate$source_gate_manifest_csv[[1L]]))) {
    g5_stop("AMD EMA evaluation contract frozen evidence must preserve source gate manifest lineage.")
  }
  if (any(as.character(frozen_fold_evidence$source_handoff_reference) !=
          as.character(amd_ema_gate$source_handoff_reference[[1L]]))) {
    g5_stop("AMD EMA evaluation contract frozen evidence must preserve source handoff lineage.")
  }
  frozen_fold_evidence
}

g5_wfa_validate_amd_ema_contract_baseline_contract <- function(
  baseline_evaluation_contract,
  fold_geometry,
  amd_ema_gate
) {
  baseline_evaluation_contract <- g5_validate_wfa_baseline_evaluation_contract_scaffold(
    baseline_evaluation_contract
  )
  no_trade <- baseline_evaluation_contract[
    as.character(baseline_evaluation_contract$baseline_family_id) == "no_trade_cash",
    ,
    drop = FALSE
  ]
  if (nrow(no_trade) != nrow(fold_geometry)) {
    g5_stop("AMD EMA evaluation contract requires one no_trade_cash baseline contract row per fold.")
  }
  if (!identical(as.character(no_trade$fold_id), as.character(fold_geometry$fold_id))) {
    g5_stop("AMD EMA evaluation contract no_trade_cash fold order must match fold geometry.")
  }
  if (any(as.character(no_trade$source_gate_manifest_csv) !=
          as.character(amd_ema_gate$source_gate_manifest_csv[[1L]]))) {
    g5_stop("AMD EMA evaluation contract no_trade_cash rows must preserve source gate manifest lineage.")
  }
  if (any(as.character(no_trade$evaluation_authorization_status) !=
          "not_authorized_no_returns_or_performance")) {
    g5_stop("AMD EMA evaluation contract cannot consume result-enabled no_trade baseline rows.")
  }
  baseline_evaluation_contract
}

g5_wfa_amd_ema_contract_review_reason <- function(
  comparison_role,
  review_required,
  source_warning_count,
  amd_train_row_count,
  amd_oos_row_count,
  amd_fold_availability_status
) {
  reasons <- character()
  if (isTRUE(review_required) || source_warning_count > 0L) {
    reasons <- c(reasons, "accepted_source_warning_context_requires_review_visibility")
  }
  if (identical(comparison_role, "no_trade_first_class_comparison")) {
    reasons <- c(reasons, "cash_no_position_return_assumption_not_defined_in_contract")
  }
  if (identical(comparison_role, "amd_ema_candidate_contract")) {
    if (amd_train_row_count == 0L) {
      reasons <- c(reasons, "amd_train_rows_unavailable_for_future_train_only_fit")
    }
    if (amd_oos_row_count == 0L) {
      reasons <- c(reasons, "amd_oos_rows_unavailable_for_future_application")
    }
    if (!identical(amd_fold_availability_status, "train_and_oos_rows_recorded")) {
      reasons <- c(reasons, "amd_fold_availability_requires_review")
    }
  }
  if (length(reasons) == 0L) {
    return("")
  }
  paste(unique(reasons), collapse = ";")
}

g5_build_wfa_amd_ema_evaluation_contract_scaffold <- function(
  amd_ema_gate,
  fold_geometry,
  split_audit,
  frozen_fold_evidence,
  baseline_evaluation_contract,
  output_dir = file.path("runs", "wfa_amd_ema_evaluation_contract"),
  accept_review_required = FALSE
) {
  amd_ema_gate <- g5_validate_wfa_amd_ema_evaluation_gate(amd_ema_gate)
  fold_geometry <- g5_wfa_validate_amd_ema_contract_fold_geometry(fold_geometry, amd_ema_gate)
  split_inputs <- g5_wfa_validate_amd_ema_contract_split_audit(split_audit, fold_geometry)
  amd_availability <- split_inputs$amd_availability
  frozen_fold_evidence <- g5_wfa_validate_amd_ema_contract_frozen_evidence(
    frozen_fold_evidence,
    fold_geometry,
    amd_ema_gate
  )
  baseline_evaluation_contract <- g5_wfa_validate_amd_ema_contract_baseline_contract(
    baseline_evaluation_contract,
    fold_geometry,
    amd_ema_gate
  )

  review_required <- isTRUE(as.logical(amd_ema_gate$handoff_review_required[[1L]])) ||
    any(as.logical(fold_geometry$handoff_review_required)) ||
    any(as.logical(frozen_fold_evidence$handoff_review_required)) ||
    any(as.logical(baseline_evaluation_contract$handoff_review_required))
  review_accepted <- if (review_required) {
    isTRUE(accept_review_required) &&
      isTRUE(as.logical(amd_ema_gate$handoff_review_accepted[[1L]])) &&
      all(as.logical(fold_geometry$handoff_review_accepted), na.rm = TRUE) &&
      all(as.logical(frozen_fold_evidence$handoff_review_accepted), na.rm = TRUE) &&
      all(as.logical(baseline_evaluation_contract$handoff_review_accepted), na.rm = TRUE)
  } else {
    FALSE
  }
  if (review_required && !review_accepted) {
    g5_stop("AMD EMA evaluation contract requires explicit acceptance for REVIEW_REQUIRED handoffs.")
  }

  first_fold <- fold_geometry[1L, , drop = FALSE]
  last_fold <- fold_geometry[nrow(fold_geometry), , drop = FALSE]
  contract_id <- paste(
    "amd_ema_eval_contract",
    g5_wfa_sanitize_id_component(amd_ema_gate$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(first_fold$fold_id[[1L]], "first_fold_id"),
    g5_wfa_sanitize_id_component(last_fold$fold_id[[1L]], "last_fold_id"),
    sep = "_"
  )

  manifest_path <- g5_wfa_amd_ema_contract_artifact_path(
    output_dir = output_dir,
    contract_id = contract_id,
    artifact_name = "amd_ema_evaluation_contract_manifest.csv"
  )
  review_surface_path <- g5_wfa_amd_ema_contract_artifact_path(
    output_dir = output_dir,
    contract_id = contract_id,
    artifact_name = "amd_ema_evaluation_contract_review_surface.csv"
  )

  review_rows <- vector("list", nrow(fold_geometry) * 2L)
  k <- 0L
  for (i in seq_len(nrow(fold_geometry))) {
    fold <- fold_geometry[i, , drop = FALSE]
    evidence <- frozen_fold_evidence[i, , drop = FALSE]
    availability <- amd_availability[i, , drop = FALSE]
    source_warning_count <- as.integer(evidence$source_warning_count[[1L]])
    for (role in c("no_trade_first_class_comparison", "amd_ema_candidate_contract")) {
      k <- k + 1L
      is_no_trade <- identical(role, "no_trade_first_class_comparison")
      subject_id <- if (is_no_trade) "no_trade_cash" else "amd_ema_long_cash"
      review_reason <- g5_wfa_amd_ema_contract_review_reason(
        comparison_role = role,
        review_required = review_required,
        source_warning_count = source_warning_count,
        amd_train_row_count = as.integer(availability$train_row_count[[1L]]),
        amd_oos_row_count = as.integer(availability$oos_row_count[[1L]]),
        amd_fold_availability_status = as.character(availability$fold_availability_status[[1L]])
      )

      review_rows[[k]] <- data.frame(
        schema_version = g5_wfa_amd_ema_evaluation_contract_schema_version(),
        contract_id = contract_id,
        review_row_id = paste(
          "amd_ema_eval_contract",
          as.character(fold$fold_id[[1L]]),
          subject_id,
          sep = "_"
        ),
        fold_id = as.character(fold$fold_id[[1L]]),
        comparison_order = if (is_no_trade) 1L else 2L,
        comparison_role = role,
        subject_id = subject_id,
        subject_type = if (is_no_trade) "baseline" else "active_candidate",
        candidate_id = if (is_no_trade) NA_character_ else "amd_ema_long_cash",
        candidate_symbol = if (is_no_trade) NA_character_ else "AMD",
        strategy_family = if (is_no_trade) NA_character_ else "ema_long_cash",
        baseline_family_id = if (is_no_trade) "no_trade_cash" else NA_character_,
        frozen_evidence_id = as.character(evidence$evidence_id[[1L]]),
        source_handoff_reference = as.character(fold$source_handoff_reference[[1L]]),
        source_gate_manifest_csv = as.character(amd_ema_gate$source_gate_manifest_csv[[1L]]),
        handoff_gate_status = as.character(amd_ema_gate$handoff_gate_status[[1L]]),
        handoff_review_required = review_required,
        handoff_review_accepted = review_accepted,
        as_of_timestamp = as.character(amd_ema_gate$as_of_timestamp[[1L]]),
        latest_completed_session = as.Date(amd_ema_gate$latest_completed_session[[1L]]),
        train_start_date = as.Date(fold$train_start_date[[1L]]),
        train_end_date = as.Date(fold$train_end_date[[1L]]),
        oos_start_date = as.Date(fold$oos_start_date[[1L]]),
        oos_end_date = as.Date(fold$oos_end_date[[1L]]),
        amd_train_row_count = as.integer(availability$train_row_count[[1L]]),
        amd_oos_row_count = as.integer(availability$oos_row_count[[1L]]),
        amd_train_availability_status = as.character(availability$train_availability_status[[1L]]),
        amd_oos_availability_status = as.character(availability$oos_availability_status[[1L]]),
        amd_fold_availability_status = as.character(availability$fold_availability_status[[1L]]),
        artifact_path = g5_wfa_amd_ema_contract_artifact_path(
          output_dir = output_dir,
          contract_id = contract_id,
          artifact_name = file.path(
            "fold_contract_surfaces",
            paste0(
              g5_wfa_sanitize_id_component(fold$fold_id[[1L]], "fold_id"),
              "__",
              g5_wfa_sanitize_id_component(subject_id, "subject_id"),
              "__contract.csv"
            )
          )
        ),
        artifact_path_policy = "deterministic_ignored_runs_path_contract_only",
        application_status = if (is_no_trade) {
          "not_applied_first_class_comparison_contract_only"
        } else {
          "not_applied_amd_ema_contract_only"
        },
        evaluation_result_status = "not_evaluated_no_oos_results_recorded",
        ema_signal_status = if (is_no_trade) {
          "not_applicable"
        } else {
          "not_computed_contract_surface_only"
        },
        ema_parameter_status = if (is_no_trade) {
          "not_applicable"
        } else {
          "not_selected_no_train_fit_in_this_contract"
        },
        train_fit_status = if (is_no_trade) {
          "not_applicable"
        } else {
          "not_fit_contract_surface_only"
        },
        oos_application_rule_status = "not_applied_contract_only_requires_frozen_decision_before_measurement",
        cash_no_position_assumption_status = if (is_no_trade) {
          "not_defined_no_cash_yield_or_return_assumption"
        } else {
          "not_applicable"
        },
        return_computation_status = "not_implemented_no_return_columns_read_or_created",
        cash_yield_status = "not_implemented_no_cash_yield_assumption",
        trade_accounting_status = "not_implemented_no_trade_accounting",
        benchmark_math_status = "not_implemented_no_benchmark_math",
        performance_metric_status = "not_implemented_no_performance_metrics",
        allocation_status = "not_authorized_no_allocation_or_weighting",
        leverage_status = "not_authorized_no_leverage_analysis_or_value_add",
        live_advice_status = "not_authorized_no_live_advice",
        execution_status = "not_authorized_no_orders_or_execution",
        dashboard_status = "not_authorized_no_dashboard",
        broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only",
        review_status = if (nzchar(review_reason)) {
          "review_required_before_any_evaluation"
        } else {
          "contract_ready_no_results_computed"
        },
        review_required_reason = review_reason,
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
    }
  }

  review_surface <- do.call(rbind, review_rows)
  rownames(review_surface) <- NULL

  manifest <- data.frame(
    schema_version = g5_wfa_amd_ema_evaluation_contract_schema_version(),
    contract_id = contract_id,
    source_gate_id = as.character(amd_ema_gate$gate_id[[1L]]),
    source_gate_status = as.character(amd_ema_gate$gate_status[[1L]]),
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
    strategy_direction = "long_or_cash_only",
    operation_mode = "research_only_non_live_non_dashboard",
    source_poc_run_id = as.character(amd_ema_gate$source_poc_run_id[[1L]]),
    source_handoff_reference = as.character(amd_ema_gate$source_handoff_reference[[1L]]),
    source_gate_manifest_csv = as.character(amd_ema_gate$source_gate_manifest_csv[[1L]]),
    handoff_gate_status = as.character(amd_ema_gate$handoff_gate_status[[1L]]),
    handoff_review_required = review_required,
    handoff_review_accepted = review_accepted,
    as_of_timestamp = as.character(amd_ema_gate$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(amd_ema_gate$latest_completed_session[[1L]]),
    fold_count = as.integer(nrow(fold_geometry)),
    comparison_row_count = as.integer(nrow(review_surface)),
    no_trade_row_count = as.integer(sum(review_surface$subject_id == "no_trade_cash")),
    candidate_row_count = as.integer(sum(review_surface$subject_id == "amd_ema_long_cash")),
    first_fold_id = as.character(first_fold$fold_id[[1L]]),
    last_fold_id = as.character(last_fold$fold_id[[1L]]),
    first_oos_start_date = as.Date(first_fold$oos_start_date[[1L]]),
    last_oos_end_date = as.Date(last_fold$oos_end_date[[1L]]),
    contract_manifest_path = manifest_path,
    review_surface_path = review_surface_path,
    artifact_path_policy = "deterministic_ignored_runs_path_contract_only",
    no_trade_comparison_status = "no_trade_cash_first_class_row_for_every_fold",
    candidate_contract_status = "amd_ema_long_cash_contract_row_for_every_fold",
    train_only_fit_contract_status = "future_ema_fit_must_use_train_rows_only",
    ema_parameter_contract_status = "no_ema_parameters_selected_or_fit_in_contract",
    oos_application_contract_status = "future_application_requires_frozen_decision_before_oos_measurement",
    baseline_contract_status = "consumed_no_trade_baseline_contract_rows_no_results",
    evaluation_authorization_status = "authorized_contract_surface_only_no_results_computed",
    result_status = "not_evaluated_no_oos_results_recorded",
    return_computation_status = "not_implemented_no_return_columns_read_or_created",
    cash_yield_status = "not_implemented_no_cash_yield_assumption",
    trade_accounting_status = "not_implemented_no_trade_accounting",
    performance_metric_status = "not_implemented_no_performance_metrics",
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
    leakage_no_return_or_metric_computation = TRUE,
    leakage_no_allocation_or_live_use = TRUE,
    stringsAsFactors = FALSE
  )
  rownames(manifest) <- NULL

  list(
    run_manifest = manifest[g5_wfa_required_amd_ema_contract_manifest_columns()],
    review_surface = review_surface[g5_wfa_required_amd_ema_contract_review_columns()]
  )
}

g5_validate_wfa_amd_ema_evaluation_contract_scaffold <- function(contract_scaffold) {
  if (!is.list(contract_scaffold) ||
      is.null(contract_scaffold$run_manifest) ||
      is.null(contract_scaffold$review_surface)) {
    g5_stop("AMD EMA evaluation contract scaffold must be a list with run_manifest and review_surface.")
  }
  manifest <- contract_scaffold$run_manifest
  review_surface <- contract_scaffold$review_surface
  g5_wfa_require_columns(
    manifest,
    g5_wfa_required_amd_ema_contract_manifest_columns(),
    "AMD EMA evaluation contract manifest"
  )
  g5_wfa_require_columns(
    review_surface,
    g5_wfa_required_amd_ema_contract_review_columns(),
    "AMD EMA evaluation contract review surface"
  )
  if (nrow(manifest) != 1L) {
    g5_stop("AMD EMA evaluation contract manifest must contain exactly one row.")
  }
  if (nrow(review_surface) == 0L) {
    g5_stop("AMD EMA evaluation contract review surface must contain at least one row.")
  }
  if (any(as.character(manifest$schema_version) !=
          g5_wfa_amd_ema_evaluation_contract_schema_version()) ||
      any(as.character(review_surface$schema_version) !=
          g5_wfa_amd_ema_evaluation_contract_schema_version())) {
    g5_stop("AMD EMA evaluation contract scaffold has an unexpected schema_version.")
  }
  if (any(duplicated(as.character(review_surface$review_row_id)))) {
    g5_stop("AMD EMA evaluation contract review_row_id values must be unique.")
  }
  if (any(as.character(review_surface$contract_id) != as.character(manifest$contract_id[[1L]]))) {
    g5_stop("AMD EMA evaluation contract review rows must reference the manifest contract_id.")
  }
  if (as.integer(manifest$fold_count[[1L]]) * 2L != nrow(review_surface)) {
    g5_stop("AMD EMA evaluation contract requires exactly two comparison rows per fold.")
  }
  fold_ids <- unique(as.character(review_surface$fold_id))
  for (fold_id in fold_ids) {
    fold_rows <- review_surface[as.character(review_surface$fold_id) == fold_id, , drop = FALSE]
    if (!identical(as.integer(fold_rows$comparison_order), c(1L, 2L))) {
      g5_stop("AMD EMA evaluation contract requires no_trade first and AMD EMA second for every fold.")
    }
    if (!identical(as.character(fold_rows$subject_id), c("no_trade_cash", "amd_ema_long_cash"))) {
      g5_stop("AMD EMA evaluation contract requires no_trade_cash and amd_ema_long_cash rows for every fold.")
    }
  }
  if (as.integer(manifest$no_trade_row_count[[1L]]) != length(fold_ids) ||
      as.integer(manifest$candidate_row_count[[1L]]) != length(fold_ids)) {
    g5_stop("AMD EMA evaluation contract manifest row counts must match fold comparison rows.")
  }
  if (any(as.character(review_surface$evaluation_result_status) !=
          "not_evaluated_no_oos_results_recorded") ||
      any(as.character(manifest$result_status) !=
          "not_evaluated_no_oos_results_recorded")) {
    g5_stop("AMD EMA evaluation contract must not record evaluated OOS results.")
  }
  status_expected <- c(
    return_computation_status = "not_implemented_no_return_columns_read_or_created",
    cash_yield_status = "not_implemented_no_cash_yield_assumption",
    trade_accounting_status = "not_implemented_no_trade_accounting",
    performance_metric_status = "not_implemented_no_performance_metrics",
    allocation_status = "not_authorized_no_allocation_or_weighting",
    leverage_status = "not_authorized_no_leverage_analysis_or_value_add",
    live_advice_status = "not_authorized_no_live_advice",
    execution_status = "not_authorized_no_orders_or_execution",
    dashboard_status = "not_authorized_no_dashboard",
    broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only"
  )
  for (col in names(status_expected)) {
    if (any(as.character(manifest[[col]]) != status_expected[[col]]) ||
        any(as.character(review_surface[[col]]) != status_expected[[col]])) {
      g5_stop(paste("AMD EMA evaluation contract has unauthorized implementation status in", col))
    }
  }
  if (any(as.character(review_surface$ema_signal_status[review_surface$subject_id == "amd_ema_long_cash"]) !=
          "not_computed_contract_surface_only")) {
    g5_stop("AMD EMA evaluation contract must not compute AMD EMA signals.")
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
    if (any(!as.logical(manifest[[col]])) || any(!as.logical(review_surface[[col]]))) {
      g5_stop(paste("AMD EMA evaluation contract leakage attestation failed:", col))
    }
  }
  paths <- c(
    manifest$contract_manifest_path,
    manifest$review_surface_path,
    review_surface$artifact_path
  )
  bad_paths <- !vapply(paths, g5_wfa_path_looks_ignored_run_path, logical(1L))
  if (any(bad_paths)) {
    g5_stop("AMD EMA evaluation contract artifact paths must be under ignored runs/ paths.")
  }
  contract_scaffold
}
