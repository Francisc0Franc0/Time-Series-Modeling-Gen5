# Gen5 AMD EMA OOS signal/position application evidence.

g5_wfa_amd_ema_oos_signal_position_schema_version <- function() {
  "g5_wfa_amd_ema_oos_signal_position_application_v0"
}

g5_wfa_required_amd_ema_oos_signal_position_manifest_columns <- function() {
  c(
    "schema_version",
    "signal_position_application_id",
    "source_application_boundary_id",
    "source_application_readiness_review_id",
    "source_application_acceptance_status",
    "source_freeze_contract_id",
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
    "signal_position_row_count",
    "no_trade_signal_row_count",
    "candidate_signal_row_count",
    "first_fold_id",
    "last_fold_id",
    "first_oos_start_date",
    "last_oos_end_date",
    "signal_position_manifest_path",
    "signal_position_surface_path",
    "artifact_path_policy",
    "bar_input_status",
    "no_trade_comparison_status",
    "frozen_application_evidence_status",
    "ema_signal_status",
    "position_evidence_status",
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

g5_wfa_required_amd_ema_oos_signal_position_surface_columns <- function() {
  c(
    "schema_version",
    "signal_position_application_id",
    "signal_position_row_id",
    "source_application_boundary_id",
    "source_application_row_id",
    "source_freeze_contract_id",
    "source_freeze_row_id",
    "as_of_timestamp",
    "latest_completed_session",
    "fold_id",
    "comparison_order",
    "subject_id",
    "subject_type",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "frozen_parameter_id",
    "parameter_source",
    "fast_ema_period",
    "slow_ema_period",
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "session_date",
    "signal_generated_after_close_date",
    "next_open_session_date",
    "next_open_session_date_status",
    "close_price",
    "fast_ema_value",
    "slow_ema_value",
    "ema_signal_state",
    "position_state_for_next_open",
    "bar_data_version_hash",
    "bar_input_status",
    "no_trade_comparison_status",
    "frozen_application_evidence_status",
    "ema_signal_status",
    "position_evidence_status",
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
    "performance_claim_status",
    "artifact_path",
    "artifact_path_policy",
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

g5_wfa_amd_ema_oos_signal_position_artifact_path <- function(
  output_dir,
  signal_position_application_id,
  artifact_name,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("AMD EMA OOS signal/position output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    g5_wfa_sanitize_id_component(signal_position_application_id, "signal_position_application_id"),
    artifact_name
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA OOS signal/position artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_wfa_reject_amd_ema_oos_signal_position_result_like_extras <- function(x, allowed_columns, label) {
  extra_cols <- setdiff(names(x), allowed_columns)
  if (length(extra_cols) == 0L) {
    return(invisible(TRUE))
  }
  prohibited_patterns <- paste(
    c(
      "return",
      "pnl",
      "profit",
      "loss",
      "sharpe",
      "drawdown",
      "metric",
      "benchmark",
      "allocation",
      "leverage",
      "score",
      "rank",
      "performance"
    ),
    collapse = "|"
  )
  prohibited_cols <- grep(prohibited_patterns, extra_cols, value = TRUE)
  if (length(prohibited_cols) > 0L) {
    g5_stop(paste(
      label,
      "must not include return, PnL, metric, allocation, leverage, or performance columns:",
      paste(prohibited_cols, collapse = ", ")
    ))
  }
  if (length(extra_cols) > 0L) {
    g5_stop(paste(label, "has unauthorized columns:", paste(extra_cols, collapse = ", ")))
  }
  invisible(TRUE)
}

g5_wfa_amd_ema_ema_values <- function(close_values, period) {
  close_values <- as.numeric(close_values)
  period <- as.integer(period)
  if (length(close_values) == 0L || any(!is.finite(close_values))) {
    g5_stop("AMD EMA OOS signal/position requires finite close values for EMA calculation.")
  }
  if (length(period) != 1L || is.na(period) || period < 1L) {
    g5_stop("AMD EMA OOS signal/position EMA period must be one positive integer.")
  }
  alpha <- 2 / (period + 1)
  out <- numeric(length(close_values))
  out[[1L]] <- close_values[[1L]]
  if (length(close_values) > 1L) {
    for (i in 2:length(close_values)) {
      out[[i]] <- alpha * close_values[[i]] + (1 - alpha) * out[[i - 1L]]
    }
  }
  out
}

g5_wfa_validate_amd_ema_oos_signal_position_source_review <- function(
  parameter_application_boundary,
  parameter_application_readiness_review,
  operator_accepts_application_readiness_review = FALSE
) {
  if (!isTRUE(operator_accepts_application_readiness_review)) {
    g5_stop("AMD EMA OOS signal/position application requires explicit operator acceptance of application readiness.")
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
    g5_stop("AMD EMA OOS signal/position readiness review must reference the application_boundary_id.")
  }
  if (as.integer(readiness_review$fold_count[[1L]]) != as.integer(manifest$fold_count[[1L]]) ||
      as.integer(readiness_review$comparison_row_count[[1L]]) != nrow(application_surface)) {
    g5_stop("AMD EMA OOS signal/position readiness review counts must match application evidence.")
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
      g5_stop(paste("AMD EMA OOS signal/position readiness review has invalid", col))
    }
  }
  list(
    manifest = manifest,
    application_surface = application_surface,
    readiness_review = readiness_review
  )
}

g5_wfa_prepare_amd_ema_oos_signal_position_bars <- function(
  bars,
  as_of_timestamp,
  latest_completed_session
) {
  bars <- g5_validate_bar_data(bars, require_adjusted = TRUE)
  bars <- bars[as.character(bars$symbol) == "AMD", , drop = FALSE]
  if (nrow(bars) == 0L) {
    g5_stop("AMD EMA OOS signal/position application requires canonical AMD bars.")
  }
  if (any(as.character(bars$provider) != "alpaca") ||
      any(as.character(bars$timeframe) != "1D") ||
      any(!as.logical(bars$adjusted))) {
    g5_stop("AMD EMA OOS signal/position application requires Alpaca adjusted daily OHLCV bars only.")
  }
  if (any(as.character(bars$as_of_timestamp) != as.character(as_of_timestamp))) {
    g5_stop("AMD EMA OOS signal/position bars must carry the frozen as_of_timestamp.")
  }
  if (any(as.Date(bars$latest_completed_session) != as.Date(latest_completed_session))) {
    g5_stop("AMD EMA OOS signal/position bars must carry the frozen latest_completed_session.")
  }
  bars <- bars[order(bars$session_date), , drop = FALSE]
  rownames(bars) <- NULL
  bars
}

g5_build_wfa_amd_ema_oos_signal_position_application <- function(
  parameter_application_boundary,
  parameter_application_readiness_review,
  bars,
  output_dir = file.path("runs", "wfa_amd_ema_oos_signal_position_application"),
  operator_accepts_application_readiness_review = FALSE
) {
  source <- g5_wfa_validate_amd_ema_oos_signal_position_source_review(
    parameter_application_boundary = parameter_application_boundary,
    parameter_application_readiness_review = parameter_application_readiness_review,
    operator_accepts_application_readiness_review = operator_accepts_application_readiness_review
  )
  manifest <- source$manifest
  application_surface <- source$application_surface
  readiness_review <- source$readiness_review
  bars <- g5_wfa_prepare_amd_ema_oos_signal_position_bars(
    bars = bars,
    as_of_timestamp = manifest$as_of_timestamp[[1L]],
    latest_completed_session = manifest$latest_completed_session[[1L]]
  )

  first_row <- application_surface[1L, , drop = FALSE]
  last_row <- application_surface[nrow(application_surface), , drop = FALSE]
  signal_position_application_id <- paste(
    "amd_ema_oos_signal_position",
    g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(manifest$first_fold_id[[1L]], "first_fold_id"),
    g5_wfa_sanitize_id_component(manifest$last_fold_id[[1L]], "last_fold_id"),
    sep = "_"
  )
  signal_position_manifest_path <- g5_wfa_amd_ema_oos_signal_position_artifact_path(
    output_dir = output_dir,
    signal_position_application_id = signal_position_application_id,
    artifact_name = "amd_ema_oos_signal_position_manifest.csv"
  )
  signal_position_surface_path <- g5_wfa_amd_ema_oos_signal_position_artifact_path(
    output_dir = output_dir,
    signal_position_application_id = signal_position_application_id,
    artifact_name = "amd_ema_oos_signal_position_surface.csv"
  )

  rows <- list()
  k <- 0L
  session_dates <- as.Date(bars$session_date)
  for (i in seq_len(nrow(application_surface))) {
    app_row <- application_surface[i, , drop = FALSE]
    is_no_trade <- identical(as.character(app_row$subject_id[[1L]]), "no_trade_cash")
    train_start <- as.Date(app_row$train_start_date[[1L]])
    oos_start <- as.Date(app_row$oos_start_date[[1L]])
    oos_end <- as.Date(app_row$oos_end_date[[1L]])
    calculation_bars <- bars[
      session_dates >= train_start & session_dates <= oos_end,
      ,
      drop = FALSE
    ]
    oos_bars <- calculation_bars[
      as.Date(calculation_bars$session_date) >= oos_start &
        as.Date(calculation_bars$session_date) <= oos_end,
      ,
      drop = FALSE
    ]
    expected_oos_rows <- as.integer(app_row$amd_oos_row_count[[1L]])
    if (nrow(oos_bars) != expected_oos_rows) {
      g5_stop("AMD EMA OOS signal/position application is missing frozen application rows.")
    }
    if (nrow(oos_bars) == 0L) {
      g5_stop("AMD EMA OOS signal/position application requires at least one OOS bar per application row.")
    }

    fast_values <- rep(NA_real_, nrow(calculation_bars))
    slow_values <- rep(NA_real_, nrow(calculation_bars))
    if (!is_no_trade) {
      fast_values <- g5_wfa_amd_ema_ema_values(calculation_bars$close, app_row$fast_ema_period[[1L]])
      slow_values <- g5_wfa_amd_ema_ema_values(calculation_bars$close, app_row$slow_ema_period[[1L]])
    }
    calculation_bars$fast_ema_value <- fast_values
    calculation_bars$slow_ema_value <- slow_values
    oos_calc <- calculation_bars[
      as.Date(calculation_bars$session_date) >= oos_start &
        as.Date(calculation_bars$session_date) <= oos_end,
      ,
      drop = FALSE
    ]

    for (j in seq_len(nrow(oos_calc))) {
      session_date <- as.Date(oos_calc$session_date[[j]])
      next_index <- which(session_dates > session_date)
      if (length(next_index) == 0L) {
        g5_stop("AMD EMA OOS signal/position application has ambiguous execution dates: missing next open session.")
      }
      next_open_session_date <- session_dates[min(next_index)]
      if (is.na(next_open_session_date) ||
          next_open_session_date > as.Date(manifest$latest_completed_session[[1L]])) {
        g5_stop("AMD EMA OOS signal/position application has ambiguous execution dates.")
      }
      ema_signal_state <- if (is_no_trade) {
        "no_trade_cash"
      } else if (oos_calc$fast_ema_value[[j]] > oos_calc$slow_ema_value[[j]]) {
        "long_signal"
      } else {
        "cash_signal"
      }
      position_state <- if (is_no_trade) {
        "no_position"
      } else if (identical(ema_signal_state, "long_signal")) {
        "long"
      } else {
        "cash"
      }
      k <- k + 1L
      rows[[k]] <- data.frame(
        schema_version = g5_wfa_amd_ema_oos_signal_position_schema_version(),
        signal_position_application_id = signal_position_application_id,
        signal_position_row_id = paste(
          "amd_ema_oos_signal_position",
          as.character(app_row$fold_id[[1L]]),
          as.character(app_row$subject_id[[1L]]),
          format(session_date, "%Y%m%d"),
          sep = "_"
        ),
        source_application_boundary_id = as.character(app_row$application_boundary_id[[1L]]),
        source_application_row_id = as.character(app_row$application_row_id[[1L]]),
        source_freeze_contract_id = as.character(app_row$source_freeze_contract_id[[1L]]),
        source_freeze_row_id = as.character(app_row$source_freeze_row_id[[1L]]),
        as_of_timestamp = as.character(app_row$as_of_timestamp[[1L]]),
        latest_completed_session = as.Date(app_row$latest_completed_session[[1L]]),
        fold_id = as.character(app_row$fold_id[[1L]]),
        comparison_order = as.integer(app_row$comparison_order[[1L]]),
        subject_id = as.character(app_row$subject_id[[1L]]),
        subject_type = as.character(app_row$subject_type[[1L]]),
        candidate_id = if (is_no_trade) NA_character_ else as.character(app_row$candidate_id[[1L]]),
        candidate_symbol = if (is_no_trade) NA_character_ else as.character(app_row$candidate_symbol[[1L]]),
        strategy_family = if (is_no_trade) NA_character_ else as.character(app_row$strategy_family[[1L]]),
        frozen_parameter_id = as.character(app_row$frozen_parameter_id[[1L]]),
        parameter_source = as.character(app_row$parameter_source[[1L]]),
        fast_ema_period = if (is_no_trade) NA_integer_ else as.integer(app_row$fast_ema_period[[1L]]),
        slow_ema_period = if (is_no_trade) NA_integer_ else as.integer(app_row$slow_ema_period[[1L]]),
        train_start_date = train_start,
        train_end_date = as.Date(app_row$train_end_date[[1L]]),
        oos_start_date = oos_start,
        oos_end_date = oos_end,
        session_date = session_date,
        signal_generated_after_close_date = session_date,
        next_open_session_date = next_open_session_date,
        next_open_session_date_status = "unique_next_canonical_amd_session",
        close_price = as.numeric(oos_calc$close[[j]]),
        fast_ema_value = if (is_no_trade) NA_real_ else as.numeric(oos_calc$fast_ema_value[[j]]),
        slow_ema_value = if (is_no_trade) NA_real_ else as.numeric(oos_calc$slow_ema_value[[j]]),
        ema_signal_state = ema_signal_state,
        position_state_for_next_open = position_state,
        bar_data_version_hash = as.character(oos_calc$data_version_hash[[j]]),
        bar_input_status = "canonical_alpaca_adjusted_daily_ohlcv_supplied_no_provider_calls",
        no_trade_comparison_status = if (is_no_trade) {
          "no_trade_cash_first_class_signal_position_row"
        } else {
          "paired_with_no_trade_cash_first_class_rows"
        },
        frozen_application_evidence_status = "consumes_frozen_application_row_no_parameter_reselection",
        ema_signal_status = if (is_no_trade) {
          "not_applicable_no_trade_cash"
        } else {
          "computed_from_frozen_ema_parameters_on_canonical_bars"
        },
        position_evidence_status = "next_open_position_state_evidence_only_no_order_or_fill",
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
        performance_claim_status = "not_authorized_signal_position_evidence_is_not_performance",
        artifact_path = g5_wfa_amd_ema_oos_signal_position_artifact_path(
          output_dir = output_dir,
          signal_position_application_id = signal_position_application_id,
          artifact_name = file.path(
            "fold_signal_position_surfaces",
            paste0(
              g5_wfa_sanitize_id_component(app_row$fold_id[[1L]], "fold_id"),
              "__",
              g5_wfa_sanitize_id_component(app_row$subject_id[[1L]], "subject_id"),
              "__",
              format(session_date, "%Y%m%d"),
              "__signal_position.csv"
            )
          )
        ),
        artifact_path_policy = "deterministic_ignored_runs_path_signal_position_only",
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

  signal_position_surface <- do.call(rbind, rows)
  rownames(signal_position_surface) <- NULL
  signal_position_manifest <- data.frame(
    schema_version = g5_wfa_amd_ema_oos_signal_position_schema_version(),
    signal_position_application_id = signal_position_application_id,
    source_application_boundary_id = as.character(manifest$application_boundary_id[[1L]]),
    source_application_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
    source_application_acceptance_status = "operator_accepted_amd_ema_parameter_application_readiness_review",
    source_freeze_contract_id = as.character(manifest$source_freeze_contract_id[[1L]]),
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
    comparison_row_count = as.integer(manifest$comparison_row_count[[1L]]),
    no_trade_row_count = as.integer(manifest$no_trade_row_count[[1L]]),
    candidate_row_count = as.integer(manifest$candidate_row_count[[1L]]),
    signal_position_row_count = as.integer(nrow(signal_position_surface)),
    no_trade_signal_row_count = as.integer(sum(signal_position_surface$subject_id == "no_trade_cash")),
    candidate_signal_row_count = as.integer(sum(signal_position_surface$subject_id == "amd_ema_long_cash")),
    first_fold_id = as.character(manifest$first_fold_id[[1L]]),
    last_fold_id = as.character(manifest$last_fold_id[[1L]]),
    first_oos_start_date = as.Date(first_row$oos_start_date[[1L]]),
    last_oos_end_date = as.Date(last_row$oos_end_date[[1L]]),
    signal_position_manifest_path = signal_position_manifest_path,
    signal_position_surface_path = signal_position_surface_path,
    artifact_path_policy = "deterministic_ignored_runs_path_signal_position_only",
    bar_input_status = "canonical_alpaca_adjusted_daily_ohlcv_supplied_no_provider_calls",
    no_trade_comparison_status = "no_trade_cash_first_class_signal_position_rows_for_every_oos_session",
    frozen_application_evidence_status = "consumes_accepted_application_boundary_no_parameter_authority_recomputed",
    ema_signal_status = "computed_from_already_frozen_ema_parameters_no_returns",
    position_evidence_status = "next_open_position_state_evidence_only_no_order_or_fill",
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
    performance_claim_status = "not_authorized_signal_position_evidence_is_not_performance",
    provider_scope_status = "no_provider_calls_input_bars_must_be_alpaca_adjusted_daily",
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
  rownames(signal_position_manifest) <- NULL

  list(
    run_manifest = signal_position_manifest[
      g5_wfa_required_amd_ema_oos_signal_position_manifest_columns()
    ],
    signal_position_surface = signal_position_surface[
      g5_wfa_required_amd_ema_oos_signal_position_surface_columns()
    ]
  )
}

g5_validate_wfa_amd_ema_oos_signal_position_application <- function(signal_position_application) {
  if (!is.list(signal_position_application) ||
      is.null(signal_position_application$run_manifest) ||
      is.null(signal_position_application$signal_position_surface)) {
    g5_stop("AMD EMA OOS signal/position application must be a list with run_manifest and signal_position_surface.")
  }
  manifest <- signal_position_application$run_manifest
  surface <- signal_position_application$signal_position_surface
  g5_wfa_require_columns(
    manifest,
    g5_wfa_required_amd_ema_oos_signal_position_manifest_columns(),
    "AMD EMA OOS signal/position manifest"
  )
  g5_wfa_require_columns(
    surface,
    g5_wfa_required_amd_ema_oos_signal_position_surface_columns(),
    "AMD EMA OOS signal/position surface"
  )
  g5_wfa_reject_amd_ema_oos_signal_position_result_like_extras(
    manifest,
    g5_wfa_required_amd_ema_oos_signal_position_manifest_columns(),
    "AMD EMA OOS signal/position manifest"
  )
  g5_wfa_reject_amd_ema_oos_signal_position_result_like_extras(
    surface,
    g5_wfa_required_amd_ema_oos_signal_position_surface_columns(),
    "AMD EMA OOS signal/position surface"
  )
  if (nrow(manifest) != 1L || nrow(surface) == 0L) {
    g5_stop("AMD EMA OOS signal/position application requires one manifest row and at least one surface row.")
  }
  if (any(as.character(manifest$schema_version) !=
          g5_wfa_amd_ema_oos_signal_position_schema_version()) ||
      any(as.character(surface$schema_version) !=
          g5_wfa_amd_ema_oos_signal_position_schema_version())) {
    g5_stop("AMD EMA OOS signal/position application has an unexpected schema_version.")
  }
  if (any(duplicated(as.character(surface$signal_position_row_id)))) {
    g5_stop("AMD EMA OOS signal/position row ids must be unique.")
  }
  if (any(as.character(surface$signal_position_application_id) !=
          as.character(manifest$signal_position_application_id[[1L]]))) {
    g5_stop("AMD EMA OOS signal/position rows must reference the manifest id.")
  }
  surface$session_date <- as.Date(surface$session_date)
  surface$signal_generated_after_close_date <- as.Date(surface$signal_generated_after_close_date)
  surface$next_open_session_date <- as.Date(surface$next_open_session_date)
  if (any(is.na(surface$session_date)) ||
      any(is.na(surface$signal_generated_after_close_date)) ||
      any(is.na(surface$next_open_session_date))) {
    g5_stop("AMD EMA OOS signal/position surface has invalid dates.")
  }
  if (any(surface$signal_generated_after_close_date != surface$session_date) ||
      any(surface$next_open_session_date <= surface$session_date) ||
      any(surface$next_open_session_date > as.Date(surface$latest_completed_session))) {
    g5_stop("AMD EMA OOS signal/position surface has ambiguous execution dates.")
  }
  if (any(as.character(surface$next_open_session_date_status) != "unique_next_canonical_amd_session")) {
    g5_stop("AMD EMA OOS signal/position surface requires unique next-session date status.")
  }
  no_trade <- as.character(surface$subject_id) == "no_trade_cash"
  candidate <- as.character(surface$subject_id) == "amd_ema_long_cash"
  if (!any(no_trade) || !any(candidate)) {
    g5_stop("AMD EMA OOS signal/position application must preserve no-trade and AMD candidate rows.")
  }
  if (any(as.character(surface$ema_signal_state[no_trade]) != "no_trade_cash") ||
      any(as.character(surface$position_state_for_next_open[no_trade]) != "no_position") ||
      any(!is.na(surface$fast_ema_period[no_trade])) ||
      any(!is.na(surface$slow_ema_period[no_trade])) ||
      any(!is.na(surface$fast_ema_value[no_trade])) ||
      any(!is.na(surface$slow_ema_value[no_trade]))) {
    g5_stop("AMD EMA OOS signal/position no-trade rows must remain no-position and carry no EMA values.")
  }
  if (any(!(as.character(surface$ema_signal_state[candidate]) %in% c("long_signal", "cash_signal"))) ||
      any(!(as.character(surface$position_state_for_next_open[candidate]) %in% c("long", "cash"))) ||
      any(!is.finite(as.numeric(surface$fast_ema_value[candidate]))) ||
      any(!is.finite(as.numeric(surface$slow_ema_value[candidate])))) {
    g5_stop("AMD EMA OOS signal/position candidate rows must carry valid signal and EMA evidence.")
  }
  keys <- unique(paste(surface$fold_id, surface$session_date))
  for (key in keys) {
    rows <- surface[paste(surface$fold_id, surface$session_date) == key, , drop = FALSE]
    if (!identical(as.integer(rows$comparison_order), c(1L, 2L)) ||
        !identical(as.character(rows$subject_id), c("no_trade_cash", "amd_ema_long_cash"))) {
      g5_stop("AMD EMA OOS signal/position requires no_trade first and AMD EMA second for every OOS session.")
    }
  }
  if (as.integer(manifest$signal_position_row_count[[1L]]) != nrow(surface) ||
      as.integer(manifest$no_trade_signal_row_count[[1L]]) != sum(no_trade) ||
      as.integer(manifest$candidate_signal_row_count[[1L]]) != sum(candidate) ||
      sum(no_trade) != sum(candidate)) {
    g5_stop("AMD EMA OOS signal/position manifest row counts must match surface rows.")
  }
  expected_status <- c(
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
    performance_claim_status = "not_authorized_signal_position_evidence_is_not_performance"
  )
  for (col in names(expected_status)) {
    if (any(as.character(manifest[[col]]) != expected_status[[col]]) ||
        any(as.character(surface[[col]]) != expected_status[[col]])) {
      g5_stop(paste("AMD EMA OOS signal/position application has unauthorized implementation status in", col))
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
    if (any(!as.logical(manifest[[col]])) || any(!as.logical(surface[[col]]))) {
      g5_stop(paste("AMD EMA OOS signal/position application leakage attestation failed:", col))
    }
  }
  paths <- c(
    manifest$signal_position_manifest_path,
    manifest$signal_position_surface_path,
    surface$artifact_path
  )
  bad_paths <- !vapply(paths, g5_wfa_path_looks_ignored_run_path, logical(1L))
  if (any(bad_paths)) {
    g5_stop("AMD EMA OOS signal/position artifact paths must be under ignored runs/ paths.")
  }
  signal_position_application
}

g5_wfa_required_amd_ema_oos_signal_position_readiness_columns <- function() {
  c(
    "schema_version",
    "readiness_review_id",
    "readiness_status",
    "signal_position_application_id",
    "source_application_boundary_id",
    "source_application_readiness_review_id",
    "source_application_acceptance_status",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "as_of_timestamp",
    "latest_completed_session",
    "fold_count",
    "signal_position_row_count",
    "no_trade_signal_row_count",
    "candidate_signal_row_count",
    "no_trade_comparison_status",
    "frozen_application_evidence_status",
    "ema_signal_status",
    "position_evidence_status",
    "calculation_stop_status",
    "out_of_scope_status",
    "leakage_attestation_status",
    "review_status",
    "review_required_reason"
  )
}

g5_build_wfa_amd_ema_oos_signal_position_readiness_review <- function(signal_position_application) {
  signal_position_application <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    signal_position_application
  )
  manifest <- signal_position_application$run_manifest
  data.frame(
    schema_version = g5_wfa_amd_ema_oos_signal_position_schema_version(),
    readiness_review_id = paste(
      "amd_ema_oos_signal_position_readiness",
      g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
      g5_wfa_sanitize_id_component(manifest$first_fold_id[[1L]], "first_fold_id"),
      g5_wfa_sanitize_id_component(manifest$last_fold_id[[1L]], "last_fold_id"),
      sep = "_"
    ),
    readiness_status = "ready_for_operator_review_signal_position_evidence_no_results",
    signal_position_application_id = as.character(manifest$signal_position_application_id[[1L]]),
    source_application_boundary_id = as.character(manifest$source_application_boundary_id[[1L]]),
    source_application_readiness_review_id = as.character(manifest$source_application_readiness_review_id[[1L]]),
    source_application_acceptance_status = as.character(manifest$source_application_acceptance_status[[1L]]),
    candidate_id = as.character(manifest$candidate_id[[1L]]),
    candidate_symbol = as.character(manifest$candidate_symbol[[1L]]),
    strategy_family = as.character(manifest$strategy_family[[1L]]),
    as_of_timestamp = as.character(manifest$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(manifest$latest_completed_session[[1L]]),
    fold_count = as.integer(manifest$fold_count[[1L]]),
    signal_position_row_count = as.integer(manifest$signal_position_row_count[[1L]]),
    no_trade_signal_row_count = as.integer(manifest$no_trade_signal_row_count[[1L]]),
    candidate_signal_row_count = as.integer(manifest$candidate_signal_row_count[[1L]]),
    no_trade_comparison_status = as.character(manifest$no_trade_comparison_status[[1L]]),
    frozen_application_evidence_status = as.character(manifest$frozen_application_evidence_status[[1L]]),
    ema_signal_status = as.character(manifest$ema_signal_status[[1L]]),
    position_evidence_status = as.character(manifest$position_evidence_status[[1L]]),
    calculation_stop_status = "returns_cash_yield_trade_accounting_benchmark_math_metrics_all_not_computed",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_performance_claims_not_authorized",
    leakage_attestation_status = "all_signal_position_leakage_attestations_true",
    review_status = "operator_review_ready_signal_position_evidence_no_results",
    review_required_reason = paste(
      c(
        "accepted_application_boundary_readiness_review_consumed",
        "frozen_ema_parameters_applied_to_oos_sessions",
        "signal_position_evidence_contains_no_returns_or_performance"
      ),
      collapse = ";"
    ),
    stringsAsFactors = FALSE
  )[g5_wfa_required_amd_ema_oos_signal_position_readiness_columns()]
}

g5_validate_wfa_amd_ema_oos_signal_position_readiness_review <- function(readiness_review) {
  g5_wfa_require_columns(
    readiness_review,
    g5_wfa_required_amd_ema_oos_signal_position_readiness_columns(),
    "AMD EMA OOS signal/position readiness review"
  )
  if (nrow(readiness_review) != 1L) {
    g5_stop("AMD EMA OOS signal/position readiness review must contain exactly one row.")
  }
  expected_values <- c(
    readiness_status = "ready_for_operator_review_signal_position_evidence_no_results",
    source_application_acceptance_status = "operator_accepted_amd_ema_parameter_application_readiness_review",
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
    no_trade_comparison_status = "no_trade_cash_first_class_signal_position_rows_for_every_oos_session",
    frozen_application_evidence_status = "consumes_accepted_application_boundary_no_parameter_authority_recomputed",
    ema_signal_status = "computed_from_already_frozen_ema_parameters_no_returns",
    position_evidence_status = "next_open_position_state_evidence_only_no_order_or_fill",
    calculation_stop_status = "returns_cash_yield_trade_accounting_benchmark_math_metrics_all_not_computed",
    out_of_scope_status = "allocation_leverage_live_advice_execution_dashboards_broader_families_performance_claims_not_authorized",
    leakage_attestation_status = "all_signal_position_leakage_attestations_true",
    review_status = "operator_review_ready_signal_position_evidence_no_results"
  )
  for (col in names(expected_values)) {
    if (!identical(as.character(readiness_review[[col]][[1L]]), expected_values[[col]])) {
      g5_stop(paste("AMD EMA OOS signal/position readiness review has invalid", col))
    }
  }
  if (as.integer(readiness_review$fold_count[[1L]]) <= 0L ||
      as.integer(readiness_review$no_trade_signal_row_count[[1L]]) !=
        as.integer(readiness_review$candidate_signal_row_count[[1L]]) ||
      as.integer(readiness_review$signal_position_row_count[[1L]]) !=
        as.integer(readiness_review$no_trade_signal_row_count[[1L]]) +
          as.integer(readiness_review$candidate_signal_row_count[[1L]])) {
    g5_stop("AMD EMA OOS signal/position readiness row counts must preserve no-trade and candidate rows.")
  }
  readiness_review
}

g5_write_wfa_amd_ema_oos_signal_position_application_csvs <- function(
  signal_position_application,
  manifest_path = NULL,
  signal_position_surface_path = NULL,
  require_ignored_run_path = TRUE
) {
  signal_position_application <- g5_validate_wfa_amd_ema_oos_signal_position_application(
    signal_position_application
  )
  manifest <- signal_position_application$run_manifest
  surface <- signal_position_application$signal_position_surface
  if (is.null(manifest_path)) {
    manifest_path <- as.character(manifest$signal_position_manifest_path[[1L]])
  }
  if (is.null(signal_position_surface_path)) {
    signal_position_surface_path <- as.character(manifest$signal_position_surface_path[[1L]])
  }
  for (path in c(manifest_path, signal_position_surface_path)) {
    if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
      g5_stop("AMD EMA OOS signal/position output paths must be non-empty.")
    }
    if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
      g5_stop("AMD EMA OOS signal/position CSVs must be written under ignored runs/ paths.")
    }
  }
  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(signal_position_surface_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
  utils::write.csv(surface, signal_position_surface_path, row.names = FALSE, na = "")
  invisible(list(
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = FALSE),
    signal_position_surface_path = normalizePath(signal_position_surface_path, winslash = "/", mustWork = FALSE)
  ))
}

g5_write_wfa_amd_ema_oos_signal_position_readiness_csv <- function(
  readiness_review,
  path,
  require_ignored_run_path = TRUE
) {
  readiness_review <- g5_validate_wfa_amd_ema_oos_signal_position_readiness_review(readiness_review)
  if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
    g5_stop("AMD EMA OOS signal/position readiness output path must be one non-empty value.")
  }
  path <- as.character(path)
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA OOS signal/position readiness CSV must be written under ignored runs/ paths.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(readiness_review, path, row.names = FALSE, na = "")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
