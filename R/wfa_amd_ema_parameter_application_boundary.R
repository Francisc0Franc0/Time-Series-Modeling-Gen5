# Gen5 AMD EMA frozen-parameter OOS application boundary.

g5_wfa_amd_ema_parameter_application_boundary_schema_version <- function() {
  "g5_wfa_amd_ema_parameter_application_boundary_v0"
}

g5_wfa_required_amd_ema_parameter_application_manifest_columns <- function() {
  c(
    "schema_version",
    "application_boundary_id",
    "source_freeze_contract_id",
    "source_freeze_readiness_review_id",
    "source_freeze_readiness_status",
    "source_freeze_review_status",
    "source_freeze_acceptance_status",
    "source_evaluation_contract_id",
    "source_evaluation_readiness_review_id",
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
    "application_manifest_path",
    "application_surface_path",
    "artifact_path_policy",
    "no_trade_comparison_status",
    "frozen_parameter_status",
    "oos_application_boundary_status",
    "oos_measurement_status",
    "result_status",
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

g5_wfa_required_amd_ema_parameter_application_surface_columns <- function() {
  c(
    "schema_version",
    "application_boundary_id",
    "application_row_id",
    "fold_id",
    "comparison_order",
    "comparison_role",
    "subject_id",
    "subject_type",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "source_freeze_contract_id",
    "source_freeze_row_id",
    "source_freeze_readiness_review_id",
    "source_evaluation_contract_id",
    "source_evaluation_review_row_id",
    "source_evaluation_readiness_review_id",
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
    "frozen_parameter_id",
    "parameter_source",
    "selection_authority_status",
    "parameter_freeze_status",
    "oos_application_boundary_status",
    "ema_rule_application_status",
    "ema_signal_status",
    "no_trade_comparison_status",
    "oos_measurement_status",
    "result_status",
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

g5_wfa_amd_ema_parameter_application_artifact_path <- function(
  output_dir,
  application_boundary_id,
  artifact_name,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("AMD EMA parameter application boundary output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    g5_wfa_sanitize_id_component(application_boundary_id, "application_boundary_id"),
    artifact_name
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA parameter application boundary artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_wfa_reject_amd_ema_application_result_like_extras <- function(x, allowed_columns, label) {
  extra_cols <- setdiff(names(x), allowed_columns)
  if (length(extra_cols) == 0L) {
    return(invisible(TRUE))
  }
  prohibited_patterns <- paste(
    c(
      "oos_return",
      "oos_result",
      "oos_performance",
      "oos_signal",
      "oos_selected",
      "oos_selection",
      "return_value",
      "strategy_return",
      "cash_yield_value",
      "trade_count",
      "trade_value",
      "position",
      "pnl",
      "profit",
      "loss",
      "sharpe",
      "drawdown",
      "metric_value",
      "benchmark_return",
      "allocation_weight",
      "leverage_ratio",
      "signal_value",
      "ema_signal_value",
      "rank",
      "score"
    ),
    collapse = "|"
  )
  prohibited_cols <- grep(prohibited_patterns, extra_cols, value = TRUE)
  if (length(prohibited_cols) > 0L) {
    g5_stop(paste(
      label,
      "must not include OOS-informed or result-like columns:",
      paste(prohibited_cols, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

g5_wfa_validate_amd_ema_application_source_review <- function(
  parameter_freeze_contract,
  parameter_freeze_readiness_review,
  operator_accepts_freeze_readiness_review = FALSE
) {
  if (!isTRUE(operator_accepts_freeze_readiness_review)) {
    g5_stop("AMD EMA parameter application boundary requires explicit operator acceptance of the parameter-freeze readiness review.")
  }
  g5_wfa_reject_amd_ema_application_result_like_extras(
    parameter_freeze_contract$run_manifest,
    g5_wfa_required_amd_ema_parameter_freeze_manifest_columns(),
    "AMD EMA parameter application boundary source freeze manifest"
  )
  g5_wfa_reject_amd_ema_application_result_like_extras(
    parameter_freeze_contract$freeze_surface,
    g5_wfa_required_amd_ema_parameter_freeze_surface_columns(),
    "AMD EMA parameter application boundary source freeze surface"
  )
  g5_wfa_reject_amd_ema_application_result_like_extras(
    parameter_freeze_readiness_review,
    g5_wfa_required_amd_ema_parameter_freeze_readiness_columns(),
    "AMD EMA parameter application boundary source readiness review"
  )

  parameter_freeze_contract <- g5_validate_wfa_amd_ema_parameter_freeze_contract(
    parameter_freeze_contract
  )
  parameter_freeze_readiness_review <- g5_validate_wfa_amd_ema_parameter_freeze_readiness_review(
    parameter_freeze_readiness_review
  )
  manifest <- parameter_freeze_contract$run_manifest
  freeze_surface <- parameter_freeze_contract$freeze_surface

  if (!identical(
    as.character(parameter_freeze_readiness_review$freeze_contract_id[[1L]]),
    as.character(manifest$freeze_contract_id[[1L]])
  )) {
    g5_stop("AMD EMA parameter application boundary readiness review must reference the freeze_contract_id.")
  }
  if (as.integer(parameter_freeze_readiness_review$fold_count[[1L]]) !=
      as.integer(manifest$fold_count[[1L]]) ||
      as.integer(parameter_freeze_readiness_review$comparison_row_count[[1L]]) !=
        nrow(freeze_surface)) {
    g5_stop("AMD EMA parameter application boundary readiness review counts must match the freeze contract.")
  }
  expected_values <- c(
    readiness_status = "ready_for_operator_review_no_results_computed",
    review_status = "operator_review_ready_frozen_parameters_no_results_computed",
    parameter_freeze_status = "train_only_parameter_decisions_frozen_before_oos_measurement",
    calculation_stop_status = "ema_returns_cash_yield_trade_accounting_metrics_all_not_computed",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_not_authorized",
    leakage_attestation_status = "all_contract_leakage_attestations_true"
  )
  for (col in names(expected_values)) {
    if (!identical(
      as.character(parameter_freeze_readiness_review[[col]][[1L]]),
      expected_values[[col]]
    )) {
      g5_stop(paste("AMD EMA parameter application boundary readiness review has invalid", col))
    }
  }
  allowed_train_authority_status <- c(
    "parameter_values_supplied_as_train_only_review_decisions_no_oos_outcome_authority",
    "parameter_values_selected_from_declared_train_grid_no_oos_outcome_authority"
  )
  if (!(as.character(parameter_freeze_readiness_review$train_authority_status[[1L]]) %in%
        allowed_train_authority_status)) {
    g5_stop("AMD EMA parameter application boundary readiness review has invalid train_authority_status")
  }
  list(
    manifest = manifest,
    freeze_surface = freeze_surface,
    readiness_review = parameter_freeze_readiness_review
  )
}

g5_wfa_amd_ema_frozen_parameter_id <- function(fold_id, fast_ema_period, slow_ema_period) {
  paste(
    "frozen_amd_ema",
    g5_wfa_sanitize_id_component(fold_id, "fold_id"),
    paste0("fast", as.integer(fast_ema_period)),
    paste0("slow", as.integer(slow_ema_period)),
    sep = "_"
  )
}

g5_build_wfa_amd_ema_parameter_application_boundary <- function(
  parameter_freeze_contract,
  parameter_freeze_readiness_review,
  output_dir = file.path("runs", "wfa_amd_ema_parameter_application_boundary"),
  operator_accepts_freeze_readiness_review = FALSE
) {
  source <- g5_wfa_validate_amd_ema_application_source_review(
    parameter_freeze_contract = parameter_freeze_contract,
    parameter_freeze_readiness_review = parameter_freeze_readiness_review,
    operator_accepts_freeze_readiness_review = operator_accepts_freeze_readiness_review
  )
  manifest <- source$manifest
  freeze_surface <- source$freeze_surface
  readiness_review <- source$readiness_review

  first_row <- freeze_surface[1L, , drop = FALSE]
  last_row <- freeze_surface[nrow(freeze_surface), , drop = FALSE]
  application_boundary_id <- paste(
    "amd_ema_param_application",
    g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(manifest$first_fold_id[[1L]], "first_fold_id"),
    g5_wfa_sanitize_id_component(manifest$last_fold_id[[1L]], "last_fold_id"),
    sep = "_"
  )
  application_manifest_path <- g5_wfa_amd_ema_parameter_application_artifact_path(
    output_dir = output_dir,
    application_boundary_id = application_boundary_id,
    artifact_name = "amd_ema_parameter_application_manifest.csv"
  )
  application_surface_path <- g5_wfa_amd_ema_parameter_application_artifact_path(
    output_dir = output_dir,
    application_boundary_id = application_boundary_id,
    artifact_name = "amd_ema_parameter_application_surface.csv"
  )

  rows <- vector("list", nrow(freeze_surface))
  for (i in seq_len(nrow(freeze_surface))) {
    freeze_row <- freeze_surface[i, , drop = FALSE]
    is_no_trade <- identical(as.character(freeze_row$subject_id[[1L]]), "no_trade_cash")
    rows[[i]] <- data.frame(
      schema_version = g5_wfa_amd_ema_parameter_application_boundary_schema_version(),
      application_boundary_id = application_boundary_id,
      application_row_id = paste(
        "amd_ema_param_application",
        as.character(freeze_row$fold_id[[1L]]),
        as.character(freeze_row$subject_id[[1L]]),
        sep = "_"
      ),
      fold_id = as.character(freeze_row$fold_id[[1L]]),
      comparison_order = as.integer(freeze_row$comparison_order[[1L]]),
      comparison_role = if (is_no_trade) {
        "no_trade_first_class_oos_window_boundary"
      } else {
        "amd_ema_frozen_parameter_oos_application_boundary"
      },
      subject_id = as.character(freeze_row$subject_id[[1L]]),
      subject_type = as.character(freeze_row$subject_type[[1L]]),
      candidate_id = if (is_no_trade) NA_character_ else "amd_ema_long_cash",
      candidate_symbol = if (is_no_trade) NA_character_ else "AMD",
      strategy_family = if (is_no_trade) NA_character_ else "ema_long_cash",
      source_freeze_contract_id = as.character(manifest$freeze_contract_id[[1L]]),
      source_freeze_row_id = as.character(freeze_row$freeze_row_id[[1L]]),
      source_freeze_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
      source_evaluation_contract_id = as.character(freeze_row$source_evaluation_contract_id[[1L]]),
      source_evaluation_review_row_id = as.character(freeze_row$source_evaluation_review_row_id[[1L]]),
      source_evaluation_readiness_review_id = as.character(manifest$source_readiness_review_id[[1L]]),
      source_handoff_reference = as.character(freeze_row$source_handoff_reference[[1L]]),
      source_gate_manifest_csv = as.character(freeze_row$source_gate_manifest_csv[[1L]]),
      handoff_gate_status = as.character(freeze_row$handoff_gate_status[[1L]]),
      handoff_review_required = as.logical(freeze_row$handoff_review_required[[1L]]),
      handoff_review_accepted = as.logical(freeze_row$handoff_review_accepted[[1L]]),
      as_of_timestamp = as.character(freeze_row$as_of_timestamp[[1L]]),
      latest_completed_session = as.Date(freeze_row$latest_completed_session[[1L]]),
      train_start_date = as.Date(freeze_row$train_start_date[[1L]]),
      train_end_date = as.Date(freeze_row$train_end_date[[1L]]),
      oos_start_date = as.Date(freeze_row$oos_start_date[[1L]]),
      oos_end_date = as.Date(freeze_row$oos_end_date[[1L]]),
      amd_train_row_count = as.integer(freeze_row$amd_train_row_count[[1L]]),
      amd_oos_row_count = as.integer(freeze_row$amd_oos_row_count[[1L]]),
      fast_ema_period = if (is_no_trade) NA_integer_ else as.integer(freeze_row$fast_ema_period[[1L]]),
      slow_ema_period = if (is_no_trade) NA_integer_ else as.integer(freeze_row$slow_ema_period[[1L]]),
      frozen_parameter_id = if (is_no_trade) {
        "not_applicable_no_trade_has_no_ema_parameters"
      } else {
        g5_wfa_amd_ema_frozen_parameter_id(
          fold_id = freeze_row$fold_id[[1L]],
          fast_ema_period = freeze_row$fast_ema_period[[1L]],
          slow_ema_period = freeze_row$slow_ema_period[[1L]]
        )
      },
      parameter_source = as.character(freeze_row$parameter_source[[1L]]),
      selection_authority_status = as.character(freeze_row$selection_authority_status[[1L]]),
      parameter_freeze_status = as.character(freeze_row$parameter_freeze_status[[1L]]),
      oos_application_boundary_status = if (is_no_trade) {
        "no_trade_cash_oos_window_preserved_no_cash_yield_or_results"
      } else {
        "frozen_train_only_parameters_bound_to_oos_window_no_signals_or_results"
      },
      ema_rule_application_status = if (is_no_trade) {
        "not_applicable"
      } else {
        "future_rule_application_only_long_when_fast_ema_above_slow_ema_else_cash"
      },
      ema_signal_status = if (is_no_trade) {
        "not_applicable"
      } else {
        "not_computed_application_boundary_only"
      },
      no_trade_comparison_status = if (is_no_trade) {
        "no_trade_cash_first_class_comparison_row_preserved"
      } else {
        "paired_with_no_trade_cash_first_class_row"
      },
      oos_measurement_status = "not_authorized_no_oos_measurement_fields",
      result_status = "not_evaluated_no_oos_results_recorded",
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
      artifact_path = g5_wfa_amd_ema_parameter_application_artifact_path(
        output_dir = output_dir,
        application_boundary_id = application_boundary_id,
        artifact_name = file.path(
          "fold_application_boundaries",
          paste0(
            g5_wfa_sanitize_id_component(freeze_row$fold_id[[1L]], "fold_id"),
            "__",
            g5_wfa_sanitize_id_component(freeze_row$subject_id[[1L]], "subject_id"),
            "__application_boundary.csv"
          )
        )
      ),
      artifact_path_policy = "deterministic_ignored_runs_path_boundary_only",
      review_status = "operator_accepted_freeze_readiness_no_results_computed",
      review_required_reason = paste(
        c(
          "accepted_parameter_freeze_readiness_review_consumed",
          "frozen_parameters_bound_to_oos_window_only",
          "oos_measurement_not_authorized"
        ),
        collapse = ";"
      ),
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

  application_surface <- do.call(rbind, rows)
  rownames(application_surface) <- NULL

  application_manifest <- data.frame(
    schema_version = g5_wfa_amd_ema_parameter_application_boundary_schema_version(),
    application_boundary_id = application_boundary_id,
    source_freeze_contract_id = as.character(manifest$freeze_contract_id[[1L]]),
    source_freeze_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
    source_freeze_readiness_status = as.character(readiness_review$readiness_status[[1L]]),
    source_freeze_review_status = as.character(readiness_review$review_status[[1L]]),
    source_freeze_acceptance_status = "operator_accepted_amd_ema_parameter_freeze_readiness_review",
    source_evaluation_contract_id = as.character(manifest$source_evaluation_contract_id[[1L]]),
    source_evaluation_readiness_review_id = as.character(manifest$source_readiness_review_id[[1L]]),
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
    comparison_row_count = as.integer(nrow(application_surface)),
    no_trade_row_count = as.integer(sum(application_surface$subject_id == "no_trade_cash")),
    candidate_row_count = as.integer(sum(application_surface$subject_id == "amd_ema_long_cash")),
    parameter_row_count = as.integer(manifest$parameter_row_count[[1L]]),
    first_fold_id = as.character(manifest$first_fold_id[[1L]]),
    last_fold_id = as.character(manifest$last_fold_id[[1L]]),
    first_oos_start_date = as.Date(first_row$oos_start_date[[1L]]),
    last_oos_end_date = as.Date(last_row$oos_end_date[[1L]]),
    application_manifest_path = application_manifest_path,
    application_surface_path = application_surface_path,
    artifact_path_policy = "deterministic_ignored_runs_path_boundary_only",
    no_trade_comparison_status = "no_trade_cash_first_class_row_for_every_fold",
    frozen_parameter_status = "train_only_parameters_preserved_from_freeze_contract",
    oos_application_boundary_status = "frozen_parameters_bound_to_oos_windows_no_signals_or_results",
    oos_measurement_status = "not_authorized_no_oos_measurement_fields",
    result_status = "not_evaluated_no_oos_results_recorded",
    ema_signal_status = "not_computed_application_boundary_only",
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
  rownames(application_manifest) <- NULL

  list(
    run_manifest = application_manifest[g5_wfa_required_amd_ema_parameter_application_manifest_columns()],
    application_surface = application_surface[g5_wfa_required_amd_ema_parameter_application_surface_columns()]
  )
}

g5_validate_wfa_amd_ema_parameter_application_boundary <- function(parameter_application_boundary) {
  if (!is.list(parameter_application_boundary) ||
      is.null(parameter_application_boundary$run_manifest) ||
      is.null(parameter_application_boundary$application_surface)) {
    g5_stop("AMD EMA parameter application boundary must be a list with run_manifest and application_surface.")
  }
  manifest <- parameter_application_boundary$run_manifest
  application_surface <- parameter_application_boundary$application_surface
  g5_wfa_require_columns(
    manifest,
    g5_wfa_required_amd_ema_parameter_application_manifest_columns(),
    "AMD EMA parameter application manifest"
  )
  g5_wfa_require_columns(
    application_surface,
    g5_wfa_required_amd_ema_parameter_application_surface_columns(),
    "AMD EMA parameter application surface"
  )
  g5_wfa_reject_amd_ema_application_result_like_extras(
    manifest,
    g5_wfa_required_amd_ema_parameter_application_manifest_columns(),
    "AMD EMA parameter application manifest"
  )
  g5_wfa_reject_amd_ema_application_result_like_extras(
    application_surface,
    g5_wfa_required_amd_ema_parameter_application_surface_columns(),
    "AMD EMA parameter application surface"
  )
  if (nrow(manifest) != 1L) {
    g5_stop("AMD EMA parameter application manifest must contain exactly one row.")
  }
  if (nrow(application_surface) == 0L) {
    g5_stop("AMD EMA parameter application surface must contain at least one row.")
  }
  if (any(as.character(manifest$schema_version) !=
          g5_wfa_amd_ema_parameter_application_boundary_schema_version()) ||
      any(as.character(application_surface$schema_version) !=
          g5_wfa_amd_ema_parameter_application_boundary_schema_version())) {
    g5_stop("AMD EMA parameter application boundary has an unexpected schema_version.")
  }
  if (any(duplicated(as.character(application_surface$application_row_id)))) {
    g5_stop("AMD EMA parameter application row ids must be unique.")
  }
  if (any(as.character(application_surface$application_boundary_id) !=
          as.character(manifest$application_boundary_id[[1L]]))) {
    g5_stop("AMD EMA parameter application rows must reference the manifest application_boundary_id.")
  }
  if (as.integer(manifest$fold_count[[1L]]) * 2L != nrow(application_surface)) {
    g5_stop("AMD EMA parameter application boundary requires exactly two comparison rows per fold.")
  }
  fold_ids <- unique(as.character(application_surface$fold_id))
  for (fold_id in fold_ids) {
    fold_rows <- application_surface[as.character(application_surface$fold_id) == fold_id, , drop = FALSE]
    if (!identical(as.integer(fold_rows$comparison_order), c(1L, 2L))) {
      g5_stop("AMD EMA parameter application boundary requires no_trade first and AMD EMA second for every fold.")
    }
    if (!identical(as.character(fold_rows$subject_id), c("no_trade_cash", "amd_ema_long_cash"))) {
      g5_stop("AMD EMA parameter application boundary requires no_trade_cash and amd_ema_long_cash rows for every fold.")
    }
  }
  if (as.integer(manifest$no_trade_row_count[[1L]]) != length(fold_ids) ||
      as.integer(manifest$candidate_row_count[[1L]]) != length(fold_ids) ||
      as.integer(manifest$parameter_row_count[[1L]]) != length(fold_ids)) {
    g5_stop("AMD EMA parameter application manifest row counts must match fold rows.")
  }
  amd_rows <- application_surface[application_surface$subject_id == "amd_ema_long_cash", , drop = FALSE]
  no_trade_rows <- application_surface[application_surface$subject_id == "no_trade_cash", , drop = FALSE]
  if (any(is.na(amd_rows$fast_ema_period)) ||
      any(is.na(amd_rows$slow_ema_period)) ||
      any(as.integer(amd_rows$fast_ema_period) >= as.integer(amd_rows$slow_ema_period))) {
    g5_stop("AMD EMA parameter application candidate rows must preserve valid frozen fast/slow EMA periods.")
  }
  if (any(!is.na(no_trade_rows$fast_ema_period)) ||
      any(!is.na(no_trade_rows$slow_ema_period))) {
    g5_stop("AMD EMA parameter application no_trade rows must not contain EMA periods.")
  }
  if (any(!(as.character(amd_rows$selection_authority_status) %in%
            g5_wfa_amd_ema_allowed_parameter_selection_authority_statuses()))) {
    g5_stop("AMD EMA parameter application candidate rows must preserve train-only authority.")
  }
  if (any(as.character(amd_rows$parameter_freeze_status) !=
          "frozen_train_only_before_oos_measurement")) {
    g5_stop("AMD EMA parameter application candidate rows must preserve frozen parameter status.")
  }
  if (any(as.character(amd_rows$ema_signal_status) !=
          "not_computed_application_boundary_only")) {
    g5_stop("AMD EMA parameter application boundary must not compute AMD EMA signals.")
  }
  expected_status <- c(
    oos_measurement_status = "not_authorized_no_oos_measurement_fields",
    result_status = "not_evaluated_no_oos_results_recorded",
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
    broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only"
  )
  for (col in names(expected_status)) {
    if (any(as.character(manifest[[col]]) != expected_status[[col]]) ||
        any(as.character(application_surface[[col]]) != expected_status[[col]])) {
      g5_stop(paste("AMD EMA parameter application boundary has unauthorized implementation status in", col))
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
    if (any(!as.logical(manifest[[col]])) || any(!as.logical(application_surface[[col]]))) {
      g5_stop(paste("AMD EMA parameter application boundary leakage attestation failed:", col))
    }
  }
  paths <- c(
    manifest$application_manifest_path,
    manifest$application_surface_path,
    application_surface$artifact_path
  )
  bad_paths <- !vapply(paths, g5_wfa_path_looks_ignored_run_path, logical(1L))
  if (any(bad_paths)) {
    g5_stop("AMD EMA parameter application boundary artifact paths must be under ignored runs/ paths.")
  }
  parameter_application_boundary
}

g5_wfa_required_amd_ema_parameter_application_readiness_columns <- function() {
  c(
    "schema_version",
    "readiness_review_id",
    "readiness_status",
    "application_boundary_id",
    "source_freeze_contract_id",
    "source_freeze_readiness_review_id",
    "source_freeze_acceptance_status",
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
    "frozen_parameter_status",
    "application_boundary_status",
    "oos_measurement_status",
    "calculation_stop_status",
    "out_of_scope_status",
    "leakage_attestation_status",
    "review_status",
    "review_required_reason"
  )
}

g5_build_wfa_amd_ema_parameter_application_readiness_review <- function(parameter_application_boundary) {
  parameter_application_boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
    parameter_application_boundary
  )
  manifest <- parameter_application_boundary$run_manifest
  data.frame(
    schema_version = g5_wfa_amd_ema_parameter_application_boundary_schema_version(),
    readiness_review_id = paste(
      "amd_ema_param_application_readiness",
      g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
      g5_wfa_sanitize_id_component(manifest$first_fold_id[[1L]], "first_fold_id"),
      g5_wfa_sanitize_id_component(manifest$last_fold_id[[1L]], "last_fold_id"),
      sep = "_"
    ),
    readiness_status = "ready_for_operator_review_no_results_computed",
    application_boundary_id = as.character(manifest$application_boundary_id[[1L]]),
    source_freeze_contract_id = as.character(manifest$source_freeze_contract_id[[1L]]),
    source_freeze_readiness_review_id = as.character(manifest$source_freeze_readiness_review_id[[1L]]),
    source_freeze_acceptance_status = as.character(manifest$source_freeze_acceptance_status[[1L]]),
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
    frozen_parameter_status = as.character(manifest$frozen_parameter_status[[1L]]),
    application_boundary_status = as.character(manifest$oos_application_boundary_status[[1L]]),
    oos_measurement_status = as.character(manifest$oos_measurement_status[[1L]]),
    calculation_stop_status = "ema_signals_returns_cash_yield_trade_accounting_benchmark_math_metrics_all_not_computed",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_not_authorized",
    leakage_attestation_status = "all_boundary_leakage_attestations_true",
    review_status = "operator_review_ready_application_boundary_no_results_computed",
    review_required_reason = paste(
      c(
        "accepted_parameter_freeze_readiness_review_consumed",
        "frozen_parameters_preserved_for_future_oos_application",
        "task49_measurement_requires_separate_authorization"
      ),
      collapse = ";"
    ),
    stringsAsFactors = FALSE
  )[g5_wfa_required_amd_ema_parameter_application_readiness_columns()]
}

g5_validate_wfa_amd_ema_parameter_application_readiness_review <- function(readiness_review) {
  g5_wfa_require_columns(
    readiness_review,
    g5_wfa_required_amd_ema_parameter_application_readiness_columns(),
    "AMD EMA parameter application readiness review"
  )
  g5_wfa_reject_amd_ema_application_result_like_extras(
    readiness_review,
    g5_wfa_required_amd_ema_parameter_application_readiness_columns(),
    "AMD EMA parameter application readiness review"
  )
  if (nrow(readiness_review) != 1L) {
    g5_stop("AMD EMA parameter application readiness review must contain exactly one row.")
  }
  expected_values <- c(
    readiness_status = "ready_for_operator_review_no_results_computed",
    source_freeze_acceptance_status = "operator_accepted_amd_ema_parameter_freeze_readiness_review",
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
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
      g5_stop(paste("AMD EMA parameter application readiness review has invalid", col))
    }
  }
  if (as.integer(readiness_review$fold_count[[1L]]) <= 0L ||
      as.integer(readiness_review$no_trade_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]]) ||
      as.integer(readiness_review$candidate_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]]) ||
      as.integer(readiness_review$parameter_row_count[[1L]]) !=
        as.integer(readiness_review$fold_count[[1L]])) {
    g5_stop("AMD EMA parameter application readiness review row counts must match fold_count.")
  }
  readiness_review
}

g5_write_wfa_amd_ema_parameter_application_boundary_csvs <- function(
  parameter_application_boundary,
  manifest_path = NULL,
  application_surface_path = NULL,
  require_ignored_run_path = TRUE
) {
  parameter_application_boundary <- g5_validate_wfa_amd_ema_parameter_application_boundary(
    parameter_application_boundary
  )
  manifest <- parameter_application_boundary$run_manifest
  application_surface <- parameter_application_boundary$application_surface
  if (is.null(manifest_path)) {
    manifest_path <- as.character(manifest$application_manifest_path[[1L]])
  }
  if (is.null(application_surface_path)) {
    application_surface_path <- as.character(manifest$application_surface_path[[1L]])
  }
  for (path in c(manifest_path, application_surface_path)) {
    if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
      g5_stop("AMD EMA parameter application boundary output paths must be non-empty.")
    }
    if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
      g5_stop("AMD EMA parameter application boundary CSVs must be written under ignored runs/ paths.")
    }
  }
  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(application_surface_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
  utils::write.csv(application_surface, application_surface_path, row.names = FALSE, na = "")
  invisible(list(
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = FALSE),
    application_surface_path = normalizePath(application_surface_path, winslash = "/", mustWork = FALSE)
  ))
}

g5_write_wfa_amd_ema_parameter_application_readiness_csv <- function(
  readiness_review,
  path,
  require_ignored_run_path = TRUE
) {
  readiness_review <- g5_validate_wfa_amd_ema_parameter_application_readiness_review(readiness_review)
  if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
    g5_stop("AMD EMA parameter application readiness output path must be one non-empty value.")
  }
  path <- as.character(path)
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA parameter application readiness CSV must be written under ignored runs/ paths.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(readiness_review, path, row.names = FALSE, na = "")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
