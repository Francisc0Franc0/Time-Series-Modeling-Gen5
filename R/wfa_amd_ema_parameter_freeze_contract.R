# Gen5 AMD EMA train-only parameter freeze contract.

g5_wfa_amd_ema_parameter_freeze_contract_schema_version <- function() {
  "g5_wfa_amd_ema_parameter_freeze_contract_v0"
}

g5_wfa_required_amd_ema_parameter_decision_columns <- function() {
  c(
    "fold_id",
    "fast_ema_period",
    "slow_ema_period",
    "parameter_source",
    "selection_authority_status"
  )
}

g5_wfa_required_amd_ema_parameter_freeze_manifest_columns <- function() {
  c(
    "schema_version",
    "freeze_contract_id",
    "source_evaluation_contract_id",
    "source_readiness_review_id",
    "source_readiness_status",
    "source_readiness_review_status",
    "source_readiness_acceptance_status",
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
    "parameter_row_count",
    "first_fold_id",
    "last_fold_id",
    "first_oos_start_date",
    "last_oos_end_date",
    "freeze_manifest_path",
    "freeze_surface_path",
    "artifact_path_policy",
    "no_trade_comparison_status",
    "parameter_freeze_status",
    "ema_parameter_scope_status",
    "train_authority_status",
    "oos_application_status",
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

g5_wfa_required_amd_ema_parameter_freeze_surface_columns <- function() {
  c(
    "schema_version",
    "freeze_contract_id",
    "freeze_row_id",
    "fold_id",
    "comparison_order",
    "comparison_role",
    "subject_id",
    "subject_type",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "source_evaluation_contract_id",
    "source_evaluation_review_row_id",
    "source_readiness_review_id",
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
    "fast_ema_period",
    "slow_ema_period",
    "parameter_source",
    "selection_authority_status",
    "parameter_freeze_status",
    "ema_rule_contract_status",
    "train_fit_status",
    "oos_application_status",
    "no_trade_comparison_status",
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
    "artifact_path",
    "artifact_path_policy",
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

g5_wfa_amd_ema_parameter_freeze_artifact_path <- function(
  output_dir,
  freeze_contract_id,
  artifact_name,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("AMD EMA parameter freeze output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    g5_wfa_sanitize_id_component(freeze_contract_id, "freeze_contract_id"),
    artifact_name
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA parameter freeze artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_wfa_amd_ema_allowed_parameter_selection_authority_statuses <- function() {
  c(
    "train_only_operator_accepted_no_oos_outcome_authority",
    "train_only_grid_selected_no_oos_outcome_authority"
  )
}

g5_wfa_amd_ema_freeze_train_authority_status <- function(parameter_decisions) {
  statuses <- unique(as.character(parameter_decisions$selection_authority_status))
  if (length(statuses) == 1L &&
      identical(statuses[[1L]], "train_only_grid_selected_no_oos_outcome_authority")) {
    return("parameter_values_selected_from_declared_train_grid_no_oos_outcome_authority")
  }
  "parameter_values_supplied_as_train_only_review_decisions_no_oos_outcome_authority"
}

g5_wfa_validate_amd_ema_parameter_decisions <- function(parameter_decisions, fold_ids) {
  g5_wfa_require_columns(
    parameter_decisions,
    g5_wfa_required_amd_ema_parameter_decision_columns(),
    "AMD EMA train-only parameter decisions"
  )
  prohibited_name_patterns <- paste(
    c(
      "return",
      "performance",
      "metric",
      "trade",
      "allocation",
      "leverage",
      "live",
      "execution",
      "dashboard",
      "oos_outcome",
      "pnl",
      "sharpe",
      "drawdown"
    ),
    collapse = "|"
  )
  prohibited_cols <- grep(prohibited_name_patterns, names(parameter_decisions), value = TRUE)
  if (length(prohibited_cols) > 0L) {
    g5_stop(paste(
      "AMD EMA parameter freeze decisions must not include result-like columns:",
      paste(prohibited_cols, collapse = ", ")
    ))
  }
  if (nrow(parameter_decisions) != length(fold_ids)) {
    g5_stop("AMD EMA parameter freeze requires exactly one parameter decision per fold.")
  }
  if (any(duplicated(as.character(parameter_decisions$fold_id)))) {
    g5_stop("AMD EMA parameter freeze fold_id values must be unique.")
  }
  if (!identical(as.character(parameter_decisions$fold_id), as.character(fold_ids))) {
    g5_stop("AMD EMA parameter freeze decisions must match evaluation fold order.")
  }
  fast <- suppressWarnings(as.integer(parameter_decisions$fast_ema_period))
  slow <- suppressWarnings(as.integer(parameter_decisions$slow_ema_period))
  if (any(is.na(fast)) || any(is.na(slow)) || any(fast < 1L) || any(slow < 2L)) {
    g5_stop("AMD EMA parameter freeze periods must be positive integer values.")
  }
  if (any(fast >= slow)) {
    g5_stop("AMD EMA parameter freeze requires fast_ema_period to be less than slow_ema_period.")
  }
  allowed_authority <- g5_wfa_amd_ema_allowed_parameter_selection_authority_statuses()
  if (any(!(as.character(parameter_decisions$selection_authority_status) %in% allowed_authority))) {
    g5_stop("AMD EMA parameter freeze decisions must declare train-only selection authority.")
  }
  if (any(is.na(parameter_decisions$parameter_source)) ||
      any(!nzchar(as.character(parameter_decisions$parameter_source)))) {
    g5_stop("AMD EMA parameter freeze decisions require a non-empty parameter_source.")
  }
  parameter_decisions$fast_ema_period <- fast
  parameter_decisions$slow_ema_period <- slow
  rownames(parameter_decisions) <- NULL
  parameter_decisions
}

g5_wfa_validate_amd_ema_freeze_source_review <- function(
  evaluation_contract_scaffold,
  evaluation_contract_readiness_review,
  operator_accepts_readiness_review = FALSE
) {
  if (!isTRUE(operator_accepts_readiness_review)) {
    g5_stop("AMD EMA parameter freeze requires explicit operator acceptance of the evaluation contract readiness review.")
  }
  evaluation_contract_scaffold <- g5_validate_wfa_amd_ema_evaluation_contract_scaffold(
    evaluation_contract_scaffold
  )
  evaluation_contract_readiness_review <- g5_validate_wfa_amd_ema_evaluation_contract_readiness_review(
    evaluation_contract_readiness_review
  )
  manifest <- evaluation_contract_scaffold$run_manifest
  review_surface <- evaluation_contract_scaffold$review_surface

  if (!identical(
    as.character(evaluation_contract_readiness_review$contract_id[[1L]]),
    as.character(manifest$contract_id[[1L]])
  )) {
    g5_stop("AMD EMA parameter freeze readiness review must reference the evaluation contract_id.")
  }
  if (as.integer(evaluation_contract_readiness_review$fold_count[[1L]]) !=
      as.integer(manifest$fold_count[[1L]]) ||
      as.integer(evaluation_contract_readiness_review$comparison_row_count[[1L]]) !=
        nrow(review_surface)) {
    g5_stop("AMD EMA parameter freeze readiness review counts must match the evaluation contract.")
  }
  expected_stop_values <- c(
    calculation_stop_status = "ema_returns_cash_yield_trade_accounting_metrics_all_not_computed",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_not_authorized",
    leakage_attestation_status = "all_contract_leakage_attestations_true"
  )
  for (col in names(expected_stop_values)) {
    if (!identical(
      as.character(evaluation_contract_readiness_review[[col]][[1L]]),
      expected_stop_values[[col]]
    )) {
      g5_stop(paste("AMD EMA parameter freeze readiness review has invalid", col))
    }
  }
  list(
    manifest = manifest,
    review_surface = review_surface,
    readiness_review = evaluation_contract_readiness_review
  )
}

g5_build_wfa_amd_ema_parameter_freeze_contract <- function(
  evaluation_contract_scaffold,
  evaluation_contract_readiness_review,
  parameter_decisions,
  output_dir = file.path("runs", "wfa_amd_ema_parameter_freeze_contract"),
  operator_accepts_readiness_review = FALSE
) {
  source <- g5_wfa_validate_amd_ema_freeze_source_review(
    evaluation_contract_scaffold = evaluation_contract_scaffold,
    evaluation_contract_readiness_review = evaluation_contract_readiness_review,
    operator_accepts_readiness_review = operator_accepts_readiness_review
  )
  manifest <- source$manifest
  review_surface <- source$review_surface
  readiness_review <- source$readiness_review

  amd_rows <- review_surface[
    as.character(review_surface$subject_id) == "amd_ema_long_cash",
    ,
    drop = FALSE
  ]
  no_trade_rows <- review_surface[
    as.character(review_surface$subject_id) == "no_trade_cash",
    ,
    drop = FALSE
  ]
  parameter_decisions <- g5_wfa_validate_amd_ema_parameter_decisions(
    parameter_decisions,
    fold_ids = amd_rows$fold_id
  )
  train_authority_status <- g5_wfa_amd_ema_freeze_train_authority_status(parameter_decisions)

  first_amd <- amd_rows[1L, , drop = FALSE]
  last_amd <- amd_rows[nrow(amd_rows), , drop = FALSE]
  freeze_contract_id <- paste(
    "amd_ema_param_freeze",
    g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(first_amd$fold_id[[1L]], "first_fold_id"),
    g5_wfa_sanitize_id_component(last_amd$fold_id[[1L]], "last_fold_id"),
    sep = "_"
  )
  freeze_manifest_path <- g5_wfa_amd_ema_parameter_freeze_artifact_path(
    output_dir = output_dir,
    freeze_contract_id = freeze_contract_id,
    artifact_name = "amd_ema_parameter_freeze_manifest.csv"
  )
  freeze_surface_path <- g5_wfa_amd_ema_parameter_freeze_artifact_path(
    output_dir = output_dir,
    freeze_contract_id = freeze_contract_id,
    artifact_name = "amd_ema_parameter_freeze_surface.csv"
  )

  rows <- vector("list", nrow(amd_rows) * 2L)
  k <- 0L
  for (i in seq_len(nrow(amd_rows))) {
    no_trade <- no_trade_rows[i, , drop = FALSE]
    amd <- amd_rows[i, , drop = FALSE]
    decision <- parameter_decisions[i, , drop = FALSE]
    for (role in c("no_trade_first_class_comparison", "amd_ema_train_only_parameter_freeze")) {
      k <- k + 1L
      is_no_trade <- identical(role, "no_trade_first_class_comparison")
      source_row <- if (is_no_trade) no_trade else amd
      subject_id <- if (is_no_trade) "no_trade_cash" else "amd_ema_long_cash"
      rows[[k]] <- data.frame(
        schema_version = g5_wfa_amd_ema_parameter_freeze_contract_schema_version(),
        freeze_contract_id = freeze_contract_id,
        freeze_row_id = paste(
          "amd_ema_param_freeze",
          as.character(source_row$fold_id[[1L]]),
          subject_id,
          sep = "_"
        ),
        fold_id = as.character(source_row$fold_id[[1L]]),
        comparison_order = if (is_no_trade) 1L else 2L,
        comparison_role = role,
        subject_id = subject_id,
        subject_type = if (is_no_trade) "baseline" else "active_candidate",
        candidate_id = if (is_no_trade) NA_character_ else "amd_ema_long_cash",
        candidate_symbol = if (is_no_trade) NA_character_ else "AMD",
        strategy_family = if (is_no_trade) NA_character_ else "ema_long_cash",
        source_evaluation_contract_id = as.character(manifest$contract_id[[1L]]),
        source_evaluation_review_row_id = as.character(source_row$review_row_id[[1L]]),
        source_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
        source_handoff_reference = as.character(source_row$source_handoff_reference[[1L]]),
        source_gate_manifest_csv = as.character(source_row$source_gate_manifest_csv[[1L]]),
        handoff_gate_status = as.character(source_row$handoff_gate_status[[1L]]),
        handoff_review_required = as.logical(source_row$handoff_review_required[[1L]]),
        handoff_review_accepted = as.logical(source_row$handoff_review_accepted[[1L]]),
        as_of_timestamp = as.character(source_row$as_of_timestamp[[1L]]),
        latest_completed_session = as.Date(source_row$latest_completed_session[[1L]]),
        train_start_date = as.Date(source_row$train_start_date[[1L]]),
        train_end_date = as.Date(source_row$train_end_date[[1L]]),
        oos_start_date = as.Date(source_row$oos_start_date[[1L]]),
        oos_end_date = as.Date(source_row$oos_end_date[[1L]]),
        amd_train_row_count = as.integer(source_row$amd_train_row_count[[1L]]),
        amd_oos_row_count = as.integer(source_row$amd_oos_row_count[[1L]]),
        fast_ema_period = if (is_no_trade) NA_integer_ else as.integer(decision$fast_ema_period[[1L]]),
        slow_ema_period = if (is_no_trade) NA_integer_ else as.integer(decision$slow_ema_period[[1L]]),
        parameter_source = if (is_no_trade) "not_applicable" else as.character(decision$parameter_source[[1L]]),
        selection_authority_status = if (is_no_trade) {
          "not_applicable_no_trade_has_no_ema_parameters"
        } else {
          as.character(decision$selection_authority_status[[1L]])
        },
        parameter_freeze_status = if (is_no_trade) {
          "not_applicable_no_trade_first_class_comparison"
        } else {
          "frozen_train_only_before_oos_measurement"
        },
        ema_rule_contract_status = if (is_no_trade) {
          "not_applicable"
        } else {
          "rule_declared_only_long_when_fast_ema_above_slow_ema_else_cash_no_signal_computed"
        },
        train_fit_status = if (is_no_trade) {
          "not_applicable"
        } else {
          "not_fit_in_contract_parameter_values_supplied_as_train_only_decision"
        },
        oos_application_status = "not_applied_frozen_decision_contract_only",
        no_trade_comparison_status = if (is_no_trade) {
          "no_trade_cash_first_class_comparison_row_preserved"
        } else {
          "paired_with_no_trade_cash_first_class_row"
        },
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
        artifact_path = g5_wfa_amd_ema_parameter_freeze_artifact_path(
          output_dir = output_dir,
          freeze_contract_id = freeze_contract_id,
          artifact_name = file.path(
            "fold_parameter_freeze_surfaces",
            paste0(
              g5_wfa_sanitize_id_component(source_row$fold_id[[1L]], "fold_id"),
              "__",
              g5_wfa_sanitize_id_component(subject_id, "subject_id"),
              "__parameter_freeze.csv"
            )
          )
        ),
        artifact_path_policy = "deterministic_ignored_runs_path_contract_only",
        review_status = "operator_accepted_source_readiness_no_results_computed",
        review_required_reason = as.character(readiness_review$review_required_reason[[1L]]),
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

  freeze_surface <- do.call(rbind, rows)
  rownames(freeze_surface) <- NULL

  freeze_manifest <- data.frame(
    schema_version = g5_wfa_amd_ema_parameter_freeze_contract_schema_version(),
    freeze_contract_id = freeze_contract_id,
    source_evaluation_contract_id = as.character(manifest$contract_id[[1L]]),
    source_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
    source_readiness_status = as.character(readiness_review$readiness_status[[1L]]),
    source_readiness_review_status = as.character(readiness_review$review_status[[1L]]),
    source_readiness_acceptance_status = "operator_accepted_amd_ema_evaluation_contract_readiness_review",
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
    strategy_direction = "long_or_cash_only",
    operation_mode = "research_only_non_live_non_dashboard",
    source_handoff_reference = as.character(manifest$source_handoff_reference[[1L]]),
    source_gate_manifest_csv = as.character(manifest$source_gate_manifest_csv[[1L]]),
    handoff_gate_status = as.character(manifest$handoff_gate_status[[1L]]),
    handoff_review_required = as.logical(manifest$handoff_review_required[[1L]]),
    handoff_review_accepted = as.logical(manifest$handoff_review_accepted[[1L]]),
    as_of_timestamp = as.character(manifest$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(manifest$latest_completed_session[[1L]]),
    fold_count = as.integer(manifest$fold_count[[1L]]),
    comparison_row_count = as.integer(nrow(freeze_surface)),
    no_trade_row_count = as.integer(sum(freeze_surface$subject_id == "no_trade_cash")),
    candidate_row_count = as.integer(sum(freeze_surface$subject_id == "amd_ema_long_cash")),
    parameter_row_count = as.integer(nrow(parameter_decisions)),
    first_fold_id = as.character(first_amd$fold_id[[1L]]),
    last_fold_id = as.character(last_amd$fold_id[[1L]]),
    first_oos_start_date = as.Date(first_amd$oos_start_date[[1L]]),
    last_oos_end_date = as.Date(last_amd$oos_end_date[[1L]]),
    freeze_manifest_path = freeze_manifest_path,
    freeze_surface_path = freeze_surface_path,
    artifact_path_policy = "deterministic_ignored_runs_path_contract_only",
    no_trade_comparison_status = "no_trade_cash_first_class_row_for_every_fold",
    parameter_freeze_status = "train_only_parameter_decisions_frozen_before_oos_measurement",
    ema_parameter_scope_status = "single_amd_ema_fast_slow_windows_only",
    train_authority_status = train_authority_status,
    oos_application_status = "not_applied_frozen_decision_contract_only",
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
  rownames(freeze_manifest) <- NULL

  list(
    run_manifest = freeze_manifest[g5_wfa_required_amd_ema_parameter_freeze_manifest_columns()],
    freeze_surface = freeze_surface[g5_wfa_required_amd_ema_parameter_freeze_surface_columns()]
  )
}

g5_validate_wfa_amd_ema_parameter_freeze_contract <- function(parameter_freeze_contract) {
  if (!is.list(parameter_freeze_contract) ||
      is.null(parameter_freeze_contract$run_manifest) ||
      is.null(parameter_freeze_contract$freeze_surface)) {
    g5_stop("AMD EMA parameter freeze contract must be a list with run_manifest and freeze_surface.")
  }
  manifest <- parameter_freeze_contract$run_manifest
  freeze_surface <- parameter_freeze_contract$freeze_surface
  g5_wfa_require_columns(
    manifest,
    g5_wfa_required_amd_ema_parameter_freeze_manifest_columns(),
    "AMD EMA parameter freeze manifest"
  )
  g5_wfa_require_columns(
    freeze_surface,
    g5_wfa_required_amd_ema_parameter_freeze_surface_columns(),
    "AMD EMA parameter freeze surface"
  )
  if (nrow(manifest) != 1L) {
    g5_stop("AMD EMA parameter freeze manifest must contain exactly one row.")
  }
  if (nrow(freeze_surface) == 0L) {
    g5_stop("AMD EMA parameter freeze surface must contain at least one row.")
  }
  if (any(as.character(manifest$schema_version) !=
          g5_wfa_amd_ema_parameter_freeze_contract_schema_version()) ||
      any(as.character(freeze_surface$schema_version) !=
          g5_wfa_amd_ema_parameter_freeze_contract_schema_version())) {
    g5_stop("AMD EMA parameter freeze contract has an unexpected schema_version.")
  }
  if (any(duplicated(as.character(freeze_surface$freeze_row_id)))) {
    g5_stop("AMD EMA parameter freeze row ids must be unique.")
  }
  if (any(as.character(freeze_surface$freeze_contract_id) !=
          as.character(manifest$freeze_contract_id[[1L]]))) {
    g5_stop("AMD EMA parameter freeze rows must reference the manifest freeze_contract_id.")
  }
  if (as.integer(manifest$fold_count[[1L]]) * 2L != nrow(freeze_surface)) {
    g5_stop("AMD EMA parameter freeze requires exactly two comparison rows per fold.")
  }
  fold_ids <- unique(as.character(freeze_surface$fold_id))
  for (fold_id in fold_ids) {
    fold_rows <- freeze_surface[as.character(freeze_surface$fold_id) == fold_id, , drop = FALSE]
    if (!identical(as.integer(fold_rows$comparison_order), c(1L, 2L))) {
      g5_stop("AMD EMA parameter freeze requires no_trade first and AMD EMA second for every fold.")
    }
    if (!identical(as.character(fold_rows$subject_id), c("no_trade_cash", "amd_ema_long_cash"))) {
      g5_stop("AMD EMA parameter freeze requires no_trade_cash and amd_ema_long_cash rows for every fold.")
    }
  }
  if (as.integer(manifest$no_trade_row_count[[1L]]) != length(fold_ids) ||
      as.integer(manifest$candidate_row_count[[1L]]) != length(fold_ids) ||
      as.integer(manifest$parameter_row_count[[1L]]) != length(fold_ids)) {
    g5_stop("AMD EMA parameter freeze manifest row counts must match fold rows.")
  }
  amd_rows <- freeze_surface[freeze_surface$subject_id == "amd_ema_long_cash", , drop = FALSE]
  no_trade_rows <- freeze_surface[freeze_surface$subject_id == "no_trade_cash", , drop = FALSE]
  if (any(is.na(amd_rows$fast_ema_period)) ||
      any(is.na(amd_rows$slow_ema_period)) ||
      any(as.integer(amd_rows$fast_ema_period) >= as.integer(amd_rows$slow_ema_period))) {
    g5_stop("AMD EMA parameter freeze candidate rows must contain valid fast/slow EMA periods.")
  }
  if (any(!is.na(no_trade_rows$fast_ema_period)) ||
      any(!is.na(no_trade_rows$slow_ema_period))) {
    g5_stop("AMD EMA parameter freeze no_trade rows must not contain EMA periods.")
  }
  expected_status <- c(
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
    broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only"
  )
  for (col in names(expected_status)) {
    if (any(as.character(manifest[[col]]) != expected_status[[col]]) ||
        any(as.character(freeze_surface[[col]]) != expected_status[[col]])) {
      g5_stop(paste("AMD EMA parameter freeze has unauthorized implementation status in", col))
    }
  }
  if (any(!(as.character(amd_rows$selection_authority_status) %in%
            g5_wfa_amd_ema_allowed_parameter_selection_authority_statuses()))) {
    g5_stop("AMD EMA parameter freeze candidate rows must preserve train-only authority.")
  }
  if (any(as.character(amd_rows$parameter_freeze_status) !=
          "frozen_train_only_before_oos_measurement")) {
    g5_stop("AMD EMA parameter freeze candidate rows must be frozen before OOS measurement.")
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
    if (any(!as.logical(manifest[[col]])) || any(!as.logical(freeze_surface[[col]]))) {
      g5_stop(paste("AMD EMA parameter freeze leakage attestation failed:", col))
    }
  }
  paths <- c(
    manifest$freeze_manifest_path,
    manifest$freeze_surface_path,
    freeze_surface$artifact_path
  )
  bad_paths <- !vapply(paths, g5_wfa_path_looks_ignored_run_path, logical(1L))
  if (any(bad_paths)) {
    g5_stop("AMD EMA parameter freeze artifact paths must be under ignored runs/ paths.")
  }
  parameter_freeze_contract
}

g5_wfa_required_amd_ema_parameter_freeze_readiness_columns <- function() {
  c(
    "schema_version",
    "readiness_review_id",
    "readiness_status",
    "freeze_contract_id",
    "source_evaluation_contract_id",
    "source_readiness_review_id",
    "source_readiness_acceptance_status",
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
    "parameter_row_count",
    "no_trade_comparison_status",
    "parameter_freeze_status",
    "train_authority_status",
    "calculation_stop_status",
    "out_of_scope_status",
    "leakage_attestation_status",
    "review_status",
    "review_required_reason"
  )
}

g5_build_wfa_amd_ema_parameter_freeze_readiness_review <- function(parameter_freeze_contract) {
  parameter_freeze_contract <- g5_validate_wfa_amd_ema_parameter_freeze_contract(
    parameter_freeze_contract
  )
  manifest <- parameter_freeze_contract$run_manifest
  data.frame(
    schema_version = g5_wfa_amd_ema_parameter_freeze_contract_schema_version(),
    readiness_review_id = paste(
      "amd_ema_param_freeze_readiness",
      g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
      g5_wfa_sanitize_id_component(manifest$first_fold_id[[1L]], "first_fold_id"),
      g5_wfa_sanitize_id_component(manifest$last_fold_id[[1L]], "last_fold_id"),
      sep = "_"
    ),
    readiness_status = "ready_for_operator_review_no_results_computed",
    freeze_contract_id = as.character(manifest$freeze_contract_id[[1L]]),
    source_evaluation_contract_id = as.character(manifest$source_evaluation_contract_id[[1L]]),
    source_readiness_review_id = as.character(manifest$source_readiness_review_id[[1L]]),
    source_readiness_acceptance_status = as.character(manifest$source_readiness_acceptance_status[[1L]]),
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
    parameter_row_count = as.integer(manifest$parameter_row_count[[1L]]),
    no_trade_comparison_status = as.character(manifest$no_trade_comparison_status[[1L]]),
    parameter_freeze_status = as.character(manifest$parameter_freeze_status[[1L]]),
    train_authority_status = as.character(manifest$train_authority_status[[1L]]),
    calculation_stop_status = "ema_returns_cash_yield_trade_accounting_metrics_all_not_computed",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_not_authorized",
    leakage_attestation_status = "all_contract_leakage_attestations_true",
    review_status = "operator_review_ready_frozen_parameters_no_results_computed",
    review_required_reason = paste(
      c(
        "accepted_source_evaluation_readiness_review_consumed",
        "no_trade_cash_remains_first_class_comparison",
        "oos_application_and_measurement_not_performed"
      ),
      collapse = ";"
    ),
    stringsAsFactors = FALSE
  )[g5_wfa_required_amd_ema_parameter_freeze_readiness_columns()]
}

g5_validate_wfa_amd_ema_parameter_freeze_readiness_review <- function(readiness_review) {
  g5_wfa_require_columns(
    readiness_review,
    g5_wfa_required_amd_ema_parameter_freeze_readiness_columns(),
    "AMD EMA parameter freeze readiness review"
  )
  if (nrow(readiness_review) != 1L) {
    g5_stop("AMD EMA parameter freeze readiness review must contain exactly one row.")
  }
  expected_values <- c(
    readiness_status = "ready_for_operator_review_no_results_computed",
    source_readiness_acceptance_status = "operator_accepted_amd_ema_evaluation_contract_readiness_review",
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
    no_trade_comparison_status = "no_trade_cash_first_class_row_for_every_fold",
    parameter_freeze_status = "train_only_parameter_decisions_frozen_before_oos_measurement",
    calculation_stop_status = "ema_returns_cash_yield_trade_accounting_metrics_all_not_computed",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_not_authorized",
    leakage_attestation_status = "all_contract_leakage_attestations_true"
  )
  for (col in names(expected_values)) {
    if (!identical(as.character(readiness_review[[col]][[1L]]), expected_values[[col]])) {
      g5_stop(paste("AMD EMA parameter freeze readiness review has invalid", col))
    }
  }
  if (as.integer(readiness_review$fold_count[[1L]]) <= 0L ||
      as.integer(readiness_review$no_trade_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]]) ||
      as.integer(readiness_review$candidate_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]]) ||
      as.integer(readiness_review$parameter_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]])) {
    g5_stop("AMD EMA parameter freeze readiness review row counts must match fold_count.")
  }
  allowed_train_authority_status <- c(
    "parameter_values_supplied_as_train_only_review_decisions_no_oos_outcome_authority",
    "parameter_values_selected_from_declared_train_grid_no_oos_outcome_authority"
  )
  if (!(as.character(readiness_review$train_authority_status[[1L]]) %in%
        allowed_train_authority_status)) {
    g5_stop("AMD EMA parameter freeze readiness review has invalid train_authority_status")
  }
  readiness_review
}

g5_write_wfa_amd_ema_parameter_freeze_contract_csvs <- function(
  parameter_freeze_contract,
  manifest_path = NULL,
  freeze_surface_path = NULL,
  require_ignored_run_path = TRUE
) {
  parameter_freeze_contract <- g5_validate_wfa_amd_ema_parameter_freeze_contract(
    parameter_freeze_contract
  )
  manifest <- parameter_freeze_contract$run_manifest
  freeze_surface <- parameter_freeze_contract$freeze_surface
  if (is.null(manifest_path)) {
    manifest_path <- as.character(manifest$freeze_manifest_path[[1L]])
  }
  if (is.null(freeze_surface_path)) {
    freeze_surface_path <- as.character(manifest$freeze_surface_path[[1L]])
  }
  for (path in c(manifest_path, freeze_surface_path)) {
    if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
      g5_stop("AMD EMA parameter freeze output paths must be non-empty.")
    }
    if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
      g5_stop("AMD EMA parameter freeze CSVs must be written under ignored runs/ paths.")
    }
  }
  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(freeze_surface_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
  utils::write.csv(freeze_surface, freeze_surface_path, row.names = FALSE, na = "")
  invisible(list(
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = FALSE),
    freeze_surface_path = normalizePath(freeze_surface_path, winslash = "/", mustWork = FALSE)
  ))
}

g5_write_wfa_amd_ema_parameter_freeze_readiness_csv <- function(
  readiness_review,
  path,
  require_ignored_run_path = TRUE
) {
  readiness_review <- g5_validate_wfa_amd_ema_parameter_freeze_readiness_review(readiness_review)
  if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
    g5_stop("AMD EMA parameter freeze readiness output path must be one non-empty value.")
  }
  path <- as.character(path)
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA parameter freeze readiness CSV must be written under ignored runs/ paths.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(readiness_review, path, row.names = FALSE, na = "")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
