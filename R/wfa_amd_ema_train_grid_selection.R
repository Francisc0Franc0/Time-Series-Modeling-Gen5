# Gen5 AMD EMA TRAIN-only grid selection evidence.

g5_wfa_amd_ema_train_grid_selection_schema_version <- function() {
  "g5_wfa_amd_ema_train_grid_selection_v0"
}

g5_wfa_required_amd_ema_train_grid_columns <- function() {
  c(
    "schema_version",
    "grid_id",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "fast_ema_period",
    "slow_ema_period",
    "grid_scope_status"
  )
}

g5_wfa_required_amd_ema_train_grid_selection_manifest_columns <- function() {
  c(
    "schema_version",
    "train_grid_selection_id",
    "source_evaluation_contract_id",
    "source_readiness_review_id",
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
    "declared_grid_row_count",
    "train_measurement_row_count",
    "no_trade_measurement_row_count",
    "candidate_measurement_row_count",
    "selected_parameter_row_count",
    "first_fold_id",
    "last_fold_id",
    "first_oos_start_date",
    "last_oos_end_date",
    "train_grid_manifest_path",
    "train_grid_surface_path",
    "train_measurement_surface_path",
    "selected_parameter_surface_path",
    "artifact_path_policy",
    "declared_grid_status",
    "train_selection_rule",
    "train_measurement_status",
    "no_trade_comparison_status",
    "selected_parameter_status",
    "oos_usage_status",
    "bar_input_status",
    "provider_scope_status",
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
    "performance_claim_status",
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

g5_wfa_required_amd_ema_train_grid_measurement_columns <- function() {
  c(
    "schema_version",
    "train_grid_selection_id",
    "measurement_row_id",
    "fold_id",
    "comparison_order",
    "comparison_role",
    "subject_id",
    "subject_type",
    "candidate_id",
    "candidate_symbol",
    "strategy_family",
    "grid_id",
    "fast_ema_period",
    "slow_ema_period",
    "source_evaluation_contract_id",
    "source_evaluation_review_row_id",
    "source_readiness_review_id",
    "source_handoff_reference",
    "source_gate_manifest_csv",
    "as_of_timestamp",
    "latest_completed_session",
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "train_row_count",
    "oos_row_count_from_contract",
    "train_first_session",
    "train_latest_session",
    "train_long_signal_count",
    "train_cash_signal_count",
    "train_signal_switch_count",
    "selection_criterion_value",
    "selection_rank",
    "selected_parameter_flag",
    "train_selection_rule",
    "bar_input_status",
    "no_trade_comparison_status",
    "selection_authority_status",
    "oos_usage_status",
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
    "performance_claim_status",
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

g5_wfa_required_amd_ema_train_grid_selected_parameter_columns <- function() {
  c(
    "schema_version",
    "train_grid_selection_id",
    "selected_parameter_row_id",
    "fold_id",
    "selected_grid_id",
    "fast_ema_period",
    "slow_ema_period",
    "parameter_source",
    "selection_authority_status",
    "selection_rule",
    "selected_before_oos_start_date",
    "source_measurement_row_id",
    "source_evaluation_contract_id",
    "source_readiness_review_id",
    "as_of_timestamp",
    "latest_completed_session",
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "train_row_count",
    "selection_criterion_value",
    "train_signal_switch_count",
    "oos_usage_status",
    "bar_input_status",
    "leakage_no_oos_parameter_selection"
  )
}

g5_wfa_amd_ema_train_grid_selection_artifact_path <- function(
  output_dir,
  train_grid_selection_id,
  artifact_name,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("AMD EMA TRAIN grid-selection output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    g5_wfa_sanitize_id_component(train_grid_selection_id, "train_grid_selection_id"),
    artifact_name
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("AMD EMA TRAIN grid-selection artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_wfa_declared_amd_ema_train_grid <- function(
  fast_ema_periods = c(2L, 3L),
  slow_ema_periods = c(4L, 5L)
) {
  fast <- sort(unique(suppressWarnings(as.integer(fast_ema_periods))))
  slow <- sort(unique(suppressWarnings(as.integer(slow_ema_periods))))
  if (length(fast) == 0L || length(slow) == 0L || any(is.na(fast)) || any(is.na(slow))) {
    g5_stop("AMD EMA declared TRAIN grid periods must be integer values.")
  }
  rows <- list()
  k <- 0L
  for (f in fast) {
    for (s in slow) {
      if (f < s) {
        k <- k + 1L
        rows[[k]] <- data.frame(
          schema_version = g5_wfa_amd_ema_train_grid_selection_schema_version(),
          grid_id = paste0("amd_ema_fast", f, "_slow", s),
          candidate_id = "amd_ema_long_cash",
          candidate_symbol = "AMD",
          strategy_family = "ema_long_cash",
          fast_ema_period = as.integer(f),
          slow_ema_period = as.integer(s),
          grid_scope_status = "declared_train_only_ema_fast_slow_grid",
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(rows) == 0L) {
    g5_stop("AMD EMA declared TRAIN grid must contain at least one fast < slow pair.")
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  g5_validate_wfa_amd_ema_train_grid(out)
}

g5_validate_wfa_amd_ema_train_grid <- function(grid) {
  g5_wfa_require_columns(
    grid,
    g5_wfa_required_amd_ema_train_grid_columns(),
    "AMD EMA declared TRAIN grid"
  )
  if (nrow(grid) == 0L) {
    g5_stop("AMD EMA declared TRAIN grid must contain at least one row.")
  }
  if (any(as.character(grid$schema_version) !=
          g5_wfa_amd_ema_train_grid_selection_schema_version())) {
    g5_stop("AMD EMA declared TRAIN grid has an unexpected schema_version.")
  }
  if (any(duplicated(as.character(grid$grid_id)))) {
    g5_stop("AMD EMA declared TRAIN grid grid_id values must be unique.")
  }
  expected_values <- c(
    candidate_id = "amd_ema_long_cash",
    candidate_symbol = "AMD",
    strategy_family = "ema_long_cash",
    grid_scope_status = "declared_train_only_ema_fast_slow_grid"
  )
  for (col in names(expected_values)) {
    if (any(as.character(grid[[col]]) != expected_values[[col]])) {
      g5_stop(paste("AMD EMA declared TRAIN grid has invalid", col))
    }
  }
  fast <- suppressWarnings(as.integer(grid$fast_ema_period))
  slow <- suppressWarnings(as.integer(grid$slow_ema_period))
  if (any(is.na(fast)) || any(is.na(slow)) || any(fast < 1L) || any(slow < 2L)) {
    g5_stop("AMD EMA declared TRAIN grid periods must be positive integers.")
  }
  if (any(fast >= slow)) {
    g5_stop("AMD EMA declared TRAIN grid requires fast_ema_period < slow_ema_period.")
  }
  pair_key <- paste(fast, slow, sep = "|")
  if (any(duplicated(pair_key))) {
    g5_stop("AMD EMA declared TRAIN grid fast/slow pairs must be unique.")
  }
  grid$fast_ema_period <- fast
  grid$slow_ema_period <- slow
  rownames(grid) <- NULL
  grid[g5_wfa_required_amd_ema_train_grid_columns()]
}

g5_wfa_reject_amd_ema_train_grid_result_like_extras <- function(x, allowed_columns, label) {
  extra_cols <- setdiff(names(x), allowed_columns)
  if (length(extra_cols) == 0L) {
    return(invisible(TRUE))
  }
  prohibited_patterns <- paste(
    c(
      "oos_return",
      "oos_result",
      "oos_performance",
      "oos_selected",
      "oos_selection",
      "oos_outcome",
      "pnl",
      "profit",
      "loss",
      "sharpe",
      "drawdown",
      "metric",
      "allocation",
      "leverage",
      "live",
      "execution",
      "dashboard",
      "performance_claim"
    ),
    collapse = "|"
  )
  prohibited_cols <- grep(prohibited_patterns, extra_cols, value = TRUE)
  if (length(prohibited_cols) > 0L) {
    g5_stop(paste(
      label,
      "must not include OOS-informed or prohibited result-like columns:",
      paste(prohibited_cols, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

g5_wfa_validate_amd_ema_train_grid_source_review <- function(
  evaluation_contract_scaffold,
  evaluation_contract_readiness_review,
  operator_accepts_readiness_review = FALSE
) {
  if (!isTRUE(operator_accepts_readiness_review)) {
    g5_stop("AMD EMA TRAIN grid selection requires explicit operator acceptance of the evaluation contract readiness review.")
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
    g5_stop("AMD EMA TRAIN grid selection readiness review must reference the evaluation contract_id.")
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
      g5_stop(paste("AMD EMA TRAIN grid selection readiness review has invalid", col))
    }
  }
  list(
    manifest = manifest,
    review_surface = review_surface,
    readiness_review = evaluation_contract_readiness_review
  )
}

g5_wfa_prepare_amd_ema_train_grid_bars <- function(
  bars,
  as_of_timestamp,
  latest_completed_session
) {
  bars <- g5_validate_bar_data(bars, require_adjusted = TRUE)
  g5_wfa_reject_amd_ema_train_grid_result_like_extras(
    bars,
    g5_required_bar_columns(),
    "AMD EMA TRAIN grid-selection bars"
  )
  if (any(as.character(bars$symbol) != "AMD")) {
    g5_stop("AMD EMA TRAIN grid selection requires AMD bars only.")
  }
  if (any(as.character(bars$provider) != "alpaca") ||
      any(as.character(bars$timeframe) != "1D") ||
      any(!as.logical(bars$adjusted))) {
    g5_stop("AMD EMA TRAIN grid selection requires Alpaca adjusted daily OHLCV bars only.")
  }
  if (any(as.character(bars$as_of_timestamp) != as.character(as_of_timestamp))) {
    g5_stop("AMD EMA TRAIN grid-selection bars must carry the frozen as_of_timestamp.")
  }
  if (any(as.Date(bars$latest_completed_session) != as.Date(latest_completed_session))) {
    g5_stop("AMD EMA TRAIN grid-selection bars must carry the frozen latest_completed_session.")
  }
  bars <- bars[order(bars$session_date), , drop = FALSE]
  rownames(bars) <- NULL
  bars
}

g5_wfa_amd_ema_train_grid_selection_rule <- function() {
  paste(
    c(
      "rank_ema_grid_within_each_fold_using_train_long_signal_count_desc",
      "then_train_signal_switch_count_asc",
      "then_slow_ema_period_asc",
      "then_fast_ema_period_asc",
      "no_oos_rows_read_for_selection"
    ),
    collapse = ";"
  )
}

g5_wfa_amd_ema_train_grid_ema_values <- function(close_values, period) {
  close_values <- as.numeric(close_values)
  period <- as.integer(period)
  if (length(close_values) == 0L || any(!is.finite(close_values))) {
    g5_stop("AMD EMA TRAIN grid selection requires finite close values for EMA calculation.")
  }
  if (length(period) != 1L || is.na(period) || period < 1L) {
    g5_stop("AMD EMA TRAIN grid selection EMA period must be one positive integer.")
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

g5_wfa_amd_ema_grid_signal_counts <- function(train_bars, fast_ema_period, slow_ema_period) {
  fast_values <- g5_wfa_amd_ema_train_grid_ema_values(train_bars$close, fast_ema_period)
  slow_values <- g5_wfa_amd_ema_train_grid_ema_values(train_bars$close, slow_ema_period)
  signal <- ifelse(fast_values > slow_values, "long_signal", "cash_signal")
  switches <- if (length(signal) <= 1L) {
    0L
  } else {
    sum(signal[-1L] != signal[-length(signal)])
  }
  list(
    long_signal_count = sum(signal == "long_signal"),
    cash_signal_count = sum(signal == "cash_signal"),
    signal_switch_count = as.integer(switches)
  )
}

g5_build_wfa_amd_ema_train_grid_selection <- function(
  evaluation_contract_scaffold,
  evaluation_contract_readiness_review,
  bars,
  declared_grid = g5_wfa_declared_amd_ema_train_grid(),
  output_dir = file.path("runs", "wfa_amd_ema_train_grid_selection"),
  operator_accepts_readiness_review = FALSE
) {
  source <- g5_wfa_validate_amd_ema_train_grid_source_review(
    evaluation_contract_scaffold = evaluation_contract_scaffold,
    evaluation_contract_readiness_review = evaluation_contract_readiness_review,
    operator_accepts_readiness_review = operator_accepts_readiness_review
  )
  manifest <- source$manifest
  review_surface <- source$review_surface
  readiness_review <- source$readiness_review
  declared_grid <- g5_validate_wfa_amd_ema_train_grid(declared_grid)
  bars <- g5_wfa_prepare_amd_ema_train_grid_bars(
    bars = bars,
    as_of_timestamp = manifest$as_of_timestamp[[1L]],
    latest_completed_session = manifest$latest_completed_session[[1L]]
  )

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
  if (nrow(amd_rows) == 0L || nrow(no_trade_rows) != nrow(amd_rows)) {
    g5_stop("AMD EMA TRAIN grid selection requires paired no-trade and AMD EMA rows.")
  }

  first_amd <- amd_rows[1L, , drop = FALSE]
  last_amd <- amd_rows[nrow(amd_rows), , drop = FALSE]
  train_grid_selection_id <- paste(
    "amd_ema_train_grid_selection",
    g5_wfa_sanitize_id_component(manifest$as_of_timestamp[[1L]], "as_of_timestamp"),
    g5_wfa_sanitize_id_component(first_amd$fold_id[[1L]], "first_fold_id"),
    g5_wfa_sanitize_id_component(last_amd$fold_id[[1L]], "last_fold_id"),
    sep = "_"
  )
  train_grid_manifest_path <- g5_wfa_amd_ema_train_grid_selection_artifact_path(
    output_dir,
    train_grid_selection_id,
    "amd_ema_train_grid_selection_manifest.csv"
  )
  train_grid_surface_path <- g5_wfa_amd_ema_train_grid_selection_artifact_path(
    output_dir,
    train_grid_selection_id,
    "amd_ema_declared_train_grid.csv"
  )
  train_measurement_surface_path <- g5_wfa_amd_ema_train_grid_selection_artifact_path(
    output_dir,
    train_grid_selection_id,
    "amd_ema_train_grid_measurement_surface.csv"
  )
  selected_parameter_surface_path <- g5_wfa_amd_ema_train_grid_selection_artifact_path(
    output_dir,
    train_grid_selection_id,
    "amd_ema_train_selected_parameters.csv"
  )

  measurement_rows <- list()
  selected_rows <- list()
  k <- 0L
  session_dates <- as.Date(bars$session_date)
  selection_rule <- g5_wfa_amd_ema_train_grid_selection_rule()
  for (i in seq_len(nrow(amd_rows))) {
    amd <- amd_rows[i, , drop = FALSE]
    no_trade <- no_trade_rows[i, , drop = FALSE]
    train_start <- as.Date(amd$train_start_date[[1L]])
    train_end <- as.Date(amd$train_end_date[[1L]])
    train_bars <- bars[
      session_dates >= train_start & session_dates <= train_end,
      ,
      drop = FALSE
    ]
    if (nrow(train_bars) != as.integer(amd$amd_train_row_count[[1L]])) {
      g5_stop("AMD EMA TRAIN grid selection canonical bars do not match frozen TRAIN coverage.")
    }
    if (nrow(train_bars) == 0L) {
      g5_stop("AMD EMA TRAIN grid selection requires at least one TRAIN bar per fold.")
    }

    fold_measurements <- vector("list", nrow(declared_grid))
    for (j in seq_len(nrow(declared_grid))) {
      grid_row <- declared_grid[j, , drop = FALSE]
      counts <- g5_wfa_amd_ema_grid_signal_counts(
        train_bars = train_bars,
        fast_ema_period = grid_row$fast_ema_period[[1L]],
        slow_ema_period = grid_row$slow_ema_period[[1L]]
      )
      fold_measurements[[j]] <- data.frame(
        grid_id = as.character(grid_row$grid_id[[1L]]),
        fast_ema_period = as.integer(grid_row$fast_ema_period[[1L]]),
        slow_ema_period = as.integer(grid_row$slow_ema_period[[1L]]),
        train_long_signal_count = as.integer(counts$long_signal_count),
        train_cash_signal_count = as.integer(counts$cash_signal_count),
        train_signal_switch_count = as.integer(counts$signal_switch_count),
        selection_criterion_value = as.integer(counts$long_signal_count),
        stringsAsFactors = FALSE
      )
    }
    fold_measurements <- do.call(rbind, fold_measurements)
    rank_order <- order(
      -as.integer(fold_measurements$selection_criterion_value),
      as.integer(fold_measurements$train_signal_switch_count),
      as.integer(fold_measurements$slow_ema_period),
      as.integer(fold_measurements$fast_ema_period),
      as.character(fold_measurements$grid_id)
    )
    fold_measurements$selection_rank <- NA_integer_
    fold_measurements$selection_rank[rank_order] <- seq_len(nrow(fold_measurements))
    selected <- fold_measurements[fold_measurements$selection_rank == 1L, , drop = FALSE]

    k <- k + 1L
    measurement_rows[[k]] <- data.frame(
      schema_version = g5_wfa_amd_ema_train_grid_selection_schema_version(),
      train_grid_selection_id = train_grid_selection_id,
      measurement_row_id = paste(
        "amd_ema_train_grid_measurement",
        as.character(no_trade$fold_id[[1L]]),
        "no_trade_cash",
        sep = "_"
      ),
      fold_id = as.character(no_trade$fold_id[[1L]]),
      comparison_order = 1L,
      comparison_role = "no_trade_first_class_train_comparison",
      subject_id = "no_trade_cash",
      subject_type = "baseline",
      candidate_id = NA_character_,
      candidate_symbol = NA_character_,
      strategy_family = NA_character_,
      grid_id = "not_applicable_no_trade_has_no_ema_grid",
      fast_ema_period = NA_integer_,
      slow_ema_period = NA_integer_,
      source_evaluation_contract_id = as.character(manifest$contract_id[[1L]]),
      source_evaluation_review_row_id = as.character(no_trade$review_row_id[[1L]]),
      source_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
      source_handoff_reference = as.character(no_trade$source_handoff_reference[[1L]]),
      source_gate_manifest_csv = as.character(no_trade$source_gate_manifest_csv[[1L]]),
      as_of_timestamp = as.character(no_trade$as_of_timestamp[[1L]]),
      latest_completed_session = as.Date(no_trade$latest_completed_session[[1L]]),
      train_start_date = as.Date(no_trade$train_start_date[[1L]]),
      train_end_date = as.Date(no_trade$train_end_date[[1L]]),
      oos_start_date = as.Date(no_trade$oos_start_date[[1L]]),
      oos_end_date = as.Date(no_trade$oos_end_date[[1L]]),
      train_row_count = as.integer(amd$amd_train_row_count[[1L]]),
      oos_row_count_from_contract = as.integer(amd$amd_oos_row_count[[1L]]),
      train_first_session = min(as.Date(train_bars$session_date)),
      train_latest_session = max(as.Date(train_bars$session_date)),
      train_long_signal_count = 0L,
      train_cash_signal_count = as.integer(nrow(train_bars)),
      train_signal_switch_count = 0L,
      selection_criterion_value = 0L,
      selection_rank = NA_integer_,
      selected_parameter_flag = FALSE,
      train_selection_rule = selection_rule,
      bar_input_status = "canonical_alpaca_adjusted_daily_amd_train_rows_only_no_provider_calls",
      no_trade_comparison_status = "no_trade_cash_first_class_train_comparison_row_preserved",
      selection_authority_status = "not_applicable_no_trade_has_no_ema_parameters",
      oos_usage_status = "oos_rows_not_read_for_train_grid_selection",
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
      performance_claim_status = "not_authorized_train_selection_is_not_oos_performance",
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

    for (j in seq_len(nrow(fold_measurements))) {
      fm <- fold_measurements[j, , drop = FALSE]
      is_selected <- as.integer(fm$selection_rank[[1L]]) == 1L
      k <- k + 1L
      measurement_rows[[k]] <- data.frame(
        schema_version = g5_wfa_amd_ema_train_grid_selection_schema_version(),
        train_grid_selection_id = train_grid_selection_id,
        measurement_row_id = paste(
          "amd_ema_train_grid_measurement",
          as.character(amd$fold_id[[1L]]),
          as.character(fm$grid_id[[1L]]),
          sep = "_"
        ),
        fold_id = as.character(amd$fold_id[[1L]]),
        comparison_order = as.integer(j + 1L),
        comparison_role = "amd_ema_train_grid_candidate",
        subject_id = "amd_ema_long_cash",
        subject_type = "active_candidate",
        candidate_id = "amd_ema_long_cash",
        candidate_symbol = "AMD",
        strategy_family = "ema_long_cash",
        grid_id = as.character(fm$grid_id[[1L]]),
        fast_ema_period = as.integer(fm$fast_ema_period[[1L]]),
        slow_ema_period = as.integer(fm$slow_ema_period[[1L]]),
        source_evaluation_contract_id = as.character(manifest$contract_id[[1L]]),
        source_evaluation_review_row_id = as.character(amd$review_row_id[[1L]]),
        source_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
        source_handoff_reference = as.character(amd$source_handoff_reference[[1L]]),
        source_gate_manifest_csv = as.character(amd$source_gate_manifest_csv[[1L]]),
        as_of_timestamp = as.character(amd$as_of_timestamp[[1L]]),
        latest_completed_session = as.Date(amd$latest_completed_session[[1L]]),
        train_start_date = as.Date(amd$train_start_date[[1L]]),
        train_end_date = as.Date(amd$train_end_date[[1L]]),
        oos_start_date = as.Date(amd$oos_start_date[[1L]]),
        oos_end_date = as.Date(amd$oos_end_date[[1L]]),
        train_row_count = as.integer(nrow(train_bars)),
        oos_row_count_from_contract = as.integer(amd$amd_oos_row_count[[1L]]),
        train_first_session = min(as.Date(train_bars$session_date)),
        train_latest_session = max(as.Date(train_bars$session_date)),
        train_long_signal_count = as.integer(fm$train_long_signal_count[[1L]]),
        train_cash_signal_count = as.integer(fm$train_cash_signal_count[[1L]]),
        train_signal_switch_count = as.integer(fm$train_signal_switch_count[[1L]]),
        selection_criterion_value = as.integer(fm$selection_criterion_value[[1L]]),
        selection_rank = as.integer(fm$selection_rank[[1L]]),
        selected_parameter_flag = is_selected,
        train_selection_rule = selection_rule,
        bar_input_status = "canonical_alpaca_adjusted_daily_amd_train_rows_only_no_provider_calls",
        no_trade_comparison_status = "paired_with_no_trade_cash_first_class_train_row",
        selection_authority_status = "train_only_grid_selected_no_oos_outcome_authority",
        oos_usage_status = "oos_rows_not_read_for_train_grid_selection",
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
        performance_claim_status = "not_authorized_train_selection_is_not_oos_performance",
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

    selected_rows[[i]] <- data.frame(
      schema_version = g5_wfa_amd_ema_train_grid_selection_schema_version(),
      train_grid_selection_id = train_grid_selection_id,
      selected_parameter_row_id = paste(
        "amd_ema_train_selected_parameter",
        as.character(amd$fold_id[[1L]]),
        sep = "_"
      ),
      fold_id = as.character(amd$fold_id[[1L]]),
      selected_grid_id = as.character(selected$grid_id[[1L]]),
      fast_ema_period = as.integer(selected$fast_ema_period[[1L]]),
      slow_ema_period = as.integer(selected$slow_ema_period[[1L]]),
      parameter_source = "train_grid_selection_evidence",
      selection_authority_status = "train_only_grid_selected_no_oos_outcome_authority",
      selection_rule = selection_rule,
      selected_before_oos_start_date = as.Date(amd$oos_start_date[[1L]]) - 1L,
      source_measurement_row_id = paste(
        "amd_ema_train_grid_measurement",
        as.character(amd$fold_id[[1L]]),
        as.character(selected$grid_id[[1L]]),
        sep = "_"
      ),
      source_evaluation_contract_id = as.character(manifest$contract_id[[1L]]),
      source_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
      as_of_timestamp = as.character(amd$as_of_timestamp[[1L]]),
      latest_completed_session = as.Date(amd$latest_completed_session[[1L]]),
      train_start_date = as.Date(amd$train_start_date[[1L]]),
      train_end_date = as.Date(amd$train_end_date[[1L]]),
      oos_start_date = as.Date(amd$oos_start_date[[1L]]),
      oos_end_date = as.Date(amd$oos_end_date[[1L]]),
      train_row_count = as.integer(nrow(train_bars)),
      selection_criterion_value = as.integer(selected$selection_criterion_value[[1L]]),
      train_signal_switch_count = as.integer(selected$train_signal_switch_count[[1L]]),
      oos_usage_status = "oos_rows_not_read_for_train_grid_selection",
      bar_input_status = "canonical_alpaca_adjusted_daily_amd_train_rows_only_no_provider_calls",
      leakage_no_oos_parameter_selection = TRUE,
      stringsAsFactors = FALSE
    )
  }

  train_measurement_surface <- do.call(rbind, measurement_rows)
  selected_parameter_surface <- do.call(rbind, selected_rows)
  rownames(train_measurement_surface) <- NULL
  rownames(selected_parameter_surface) <- NULL

  manifest_out <- data.frame(
    schema_version = g5_wfa_amd_ema_train_grid_selection_schema_version(),
    train_grid_selection_id = train_grid_selection_id,
    source_evaluation_contract_id = as.character(manifest$contract_id[[1L]]),
    source_readiness_review_id = as.character(readiness_review$readiness_review_id[[1L]]),
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
    fold_count = as.integer(nrow(amd_rows)),
    declared_grid_row_count = as.integer(nrow(declared_grid)),
    train_measurement_row_count = as.integer(nrow(train_measurement_surface)),
    no_trade_measurement_row_count = as.integer(sum(train_measurement_surface$subject_id == "no_trade_cash")),
    candidate_measurement_row_count = as.integer(sum(train_measurement_surface$subject_id == "amd_ema_long_cash")),
    selected_parameter_row_count = as.integer(nrow(selected_parameter_surface)),
    first_fold_id = as.character(first_amd$fold_id[[1L]]),
    last_fold_id = as.character(last_amd$fold_id[[1L]]),
    first_oos_start_date = as.Date(first_amd$oos_start_date[[1L]]),
    last_oos_end_date = as.Date(last_amd$oos_end_date[[1L]]),
    train_grid_manifest_path = train_grid_manifest_path,
    train_grid_surface_path = train_grid_surface_path,
    train_measurement_surface_path = train_measurement_surface_path,
    selected_parameter_surface_path = selected_parameter_surface_path,
    artifact_path_policy = "deterministic_ignored_runs_path_train_selection_only",
    declared_grid_status = "modest_predeclared_ema_fast_slow_grid",
    train_selection_rule = selection_rule,
    train_measurement_status = "train_only_signal_count_evidence_no_oos_rows_used",
    no_trade_comparison_status = "no_trade_cash_first_class_train_comparison_row_for_every_fold",
    selected_parameter_status = "one_ema_grid_pair_selected_per_fold_before_oos_application",
    oos_usage_status = "oos_rows_not_read_for_train_grid_selection",
    bar_input_status = "canonical_alpaca_adjusted_daily_amd_train_rows_only_no_provider_calls",
    provider_scope_status = "no_provider_calls_input_bars_must_be_alpaca_adjusted_daily_amd_only",
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
    performance_claim_status = "not_authorized_train_selection_is_not_oos_performance",
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
  rownames(manifest_out) <- NULL

  declared_grid$train_grid_selection_id <- train_grid_selection_id
  declared_grid <- declared_grid[
    c("train_grid_selection_id", g5_wfa_required_amd_ema_train_grid_columns())
  ]

  out <- list(
    run_manifest = manifest_out[g5_wfa_required_amd_ema_train_grid_selection_manifest_columns()],
    declared_grid = declared_grid,
    train_measurement_surface = train_measurement_surface[
      g5_wfa_required_amd_ema_train_grid_measurement_columns()
    ],
    selected_parameters = selected_parameter_surface[
      g5_wfa_required_amd_ema_train_grid_selected_parameter_columns()
    ]
  )
  g5_validate_wfa_amd_ema_train_grid_selection(out)
}

g5_validate_wfa_amd_ema_train_grid_selection <- function(train_grid_selection) {
  if (!is.list(train_grid_selection) ||
      is.null(train_grid_selection$run_manifest) ||
      is.null(train_grid_selection$declared_grid) ||
      is.null(train_grid_selection$train_measurement_surface) ||
      is.null(train_grid_selection$selected_parameters)) {
    g5_stop("AMD EMA TRAIN grid selection must be a list with manifest, grid, measurements, and selected parameters.")
  }
  manifest <- train_grid_selection$run_manifest
  grid <- train_grid_selection$declared_grid
  measurements <- train_grid_selection$train_measurement_surface
  selected <- train_grid_selection$selected_parameters
  g5_wfa_require_columns(
    manifest,
    g5_wfa_required_amd_ema_train_grid_selection_manifest_columns(),
    "AMD EMA TRAIN grid-selection manifest"
  )
  g5_wfa_require_columns(
    grid,
    c("train_grid_selection_id", g5_wfa_required_amd_ema_train_grid_columns()),
    "AMD EMA declared TRAIN grid surface"
  )
  g5_wfa_require_columns(
    measurements,
    g5_wfa_required_amd_ema_train_grid_measurement_columns(),
    "AMD EMA TRAIN grid measurement surface"
  )
  g5_wfa_require_columns(
    selected,
    g5_wfa_required_amd_ema_train_grid_selected_parameter_columns(),
    "AMD EMA TRAIN selected parameter surface"
  )
  if (nrow(manifest) != 1L) {
    g5_stop("AMD EMA TRAIN grid-selection manifest must contain exactly one row.")
  }
  expected_schema <- g5_wfa_amd_ema_train_grid_selection_schema_version()
  for (surface in list(manifest, grid, measurements, selected)) {
    if (any(as.character(surface$schema_version) != expected_schema)) {
      g5_stop("AMD EMA TRAIN grid selection has an unexpected schema_version.")
    }
  }
  selection_id <- as.character(manifest$train_grid_selection_id[[1L]])
  if (any(as.character(grid$train_grid_selection_id) != selection_id) ||
      any(as.character(measurements$train_grid_selection_id) != selection_id) ||
      any(as.character(selected$train_grid_selection_id) != selection_id)) {
    g5_stop("AMD EMA TRAIN grid-selection surfaces must reference the manifest id.")
  }
  if (any(duplicated(as.character(measurements$measurement_row_id))) ||
      any(duplicated(as.character(selected$selected_parameter_row_id)))) {
    g5_stop("AMD EMA TRAIN grid-selection row ids must be unique.")
  }
  grid_core <- grid[g5_wfa_required_amd_ema_train_grid_columns()]
  grid_core <- g5_validate_wfa_amd_ema_train_grid(grid_core)
  if (as.integer(manifest$declared_grid_row_count[[1L]]) != nrow(grid_core)) {
    g5_stop("AMD EMA TRAIN grid-selection manifest grid count must match declared grid.")
  }

  fold_ids <- unique(as.character(selected$fold_id))
  if (length(fold_ids) != as.integer(manifest$fold_count[[1L]]) ||
      nrow(selected) != as.integer(manifest$fold_count[[1L]])) {
    g5_stop("AMD EMA TRAIN grid selection must select exactly one EMA pair per fold.")
  }
  if (as.integer(manifest$train_measurement_row_count[[1L]]) != nrow(measurements) ||
      as.integer(manifest$no_trade_measurement_row_count[[1L]]) !=
        sum(as.character(measurements$subject_id) == "no_trade_cash") ||
      as.integer(manifest$candidate_measurement_row_count[[1L]]) !=
        sum(as.character(measurements$subject_id) == "amd_ema_long_cash") ||
      as.integer(manifest$selected_parameter_row_count[[1L]]) != nrow(selected)) {
    g5_stop("AMD EMA TRAIN grid-selection manifest row counts must match surface rows.")
  }
  expected_measurement_rows <- as.integer(manifest$fold_count[[1L]]) *
    (as.integer(manifest$declared_grid_row_count[[1L]]) + 1L)
  if (nrow(measurements) != expected_measurement_rows) {
    g5_stop("AMD EMA TRAIN grid selection requires one no-trade row plus every grid row per fold.")
  }

  grid_ids <- as.character(grid_core$grid_id)
  for (fold_id in fold_ids) {
    fold_rows <- measurements[as.character(measurements$fold_id) == fold_id, , drop = FALSE]
    if (nrow(fold_rows) != nrow(grid_core) + 1L) {
      g5_stop("AMD EMA TRAIN grid selection fold rows must include no-trade plus every grid candidate.")
    }
    if (as.character(fold_rows$subject_id[[1L]]) != "no_trade_cash" ||
        as.integer(fold_rows$comparison_order[[1L]]) != 1L) {
      g5_stop("AMD EMA TRAIN grid selection must preserve no-trade as the first comparison row.")
    }
    candidate_rows <- fold_rows[as.character(fold_rows$subject_id) == "amd_ema_long_cash", , drop = FALSE]
    if (!identical(sort(as.character(candidate_rows$grid_id)), sort(grid_ids))) {
      g5_stop("AMD EMA TRAIN grid selection candidate rows must match the declared grid.")
    }
    if (sum(as.logical(candidate_rows$selected_parameter_flag)) != 1L ||
        !identical(sort(as.integer(candidate_rows$selection_rank)), seq_len(nrow(grid_core)))) {
      g5_stop("AMD EMA TRAIN grid selection requires one rank-1 selected grid row per fold.")
    }
    selected_row <- selected[as.character(selected$fold_id) == fold_id, , drop = FALSE]
    rank_one <- candidate_rows[as.integer(candidate_rows$selection_rank) == 1L, , drop = FALSE]
    if (nrow(selected_row) != 1L || nrow(rank_one) != 1L ||
        !identical(as.character(selected_row$selected_grid_id[[1L]]), as.character(rank_one$grid_id[[1L]])) ||
        as.integer(selected_row$fast_ema_period[[1L]]) != as.integer(rank_one$fast_ema_period[[1L]]) ||
        as.integer(selected_row$slow_ema_period[[1L]]) != as.integer(rank_one$slow_ema_period[[1L]])) {
      g5_stop("AMD EMA TRAIN selected parameters must reference the rank-1 grid measurement row.")
    }
    if (as.Date(selected_row$selected_before_oos_start_date[[1L]]) >=
        as.Date(selected_row$oos_start_date[[1L]])) {
      g5_stop("AMD EMA TRAIN selected parameters must be frozen before OOS starts.")
    }
  }
  if (any(!(as.character(selected$selected_grid_id) %in% grid_ids))) {
    g5_stop("AMD EMA TRAIN selected parameters must come from the declared grid.")
  }
  if (any(as.character(selected$selection_authority_status) !=
          "train_only_grid_selected_no_oos_outcome_authority") ||
      any(!as.logical(selected$leakage_no_oos_parameter_selection))) {
    g5_stop("AMD EMA TRAIN selected parameters must preserve train-only authority.")
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
    broader_strategy_family_status = "not_authorized_single_amd_ema_candidate_only",
    performance_claim_status = "not_authorized_train_selection_is_not_oos_performance"
  )
  for (col in names(expected_status)) {
    if (any(as.character(manifest[[col]]) != expected_status[[col]]) ||
        any(as.character(measurements[[col]]) != expected_status[[col]])) {
      g5_stop(paste("AMD EMA TRAIN grid selection has unauthorized status in", col))
    }
  }
  if (any(as.character(manifest$oos_usage_status) !=
          "oos_rows_not_read_for_train_grid_selection") ||
      any(as.character(measurements$oos_usage_status) !=
          "oos_rows_not_read_for_train_grid_selection") ||
      any(as.character(selected$oos_usage_status) !=
          "oos_rows_not_read_for_train_grid_selection")) {
    g5_stop("AMD EMA TRAIN grid selection must record that OOS rows were not read for selection.")
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
    if (any(!as.logical(manifest[[col]])) || any(!as.logical(measurements[[col]]))) {
      g5_stop(paste("AMD EMA TRAIN grid selection leakage attestation failed:", col))
    }
  }
  paths <- c(
    manifest$train_grid_manifest_path,
    manifest$train_grid_surface_path,
    manifest$train_measurement_surface_path,
    manifest$selected_parameter_surface_path
  )
  bad_paths <- !vapply(paths, g5_wfa_path_looks_ignored_run_path, logical(1L))
  if (any(bad_paths)) {
    g5_stop("AMD EMA TRAIN grid-selection artifact paths must be under ignored runs/ paths.")
  }
  train_grid_selection
}

g5_write_wfa_amd_ema_train_grid_selection_csvs <- function(
  train_grid_selection,
  manifest_path = NULL,
  grid_path = NULL,
  measurement_path = NULL,
  selected_parameter_path = NULL,
  require_ignored_run_path = TRUE
) {
  train_grid_selection <- g5_validate_wfa_amd_ema_train_grid_selection(train_grid_selection)
  manifest <- train_grid_selection$run_manifest
  if (is.null(manifest_path)) {
    manifest_path <- as.character(manifest$train_grid_manifest_path[[1L]])
  }
  if (is.null(grid_path)) {
    grid_path <- as.character(manifest$train_grid_surface_path[[1L]])
  }
  if (is.null(measurement_path)) {
    measurement_path <- as.character(manifest$train_measurement_surface_path[[1L]])
  }
  if (is.null(selected_parameter_path)) {
    selected_parameter_path <- as.character(manifest$selected_parameter_surface_path[[1L]])
  }
  for (path in c(manifest_path, grid_path, measurement_path, selected_parameter_path)) {
    if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
      g5_stop("AMD EMA TRAIN grid-selection output paths must be non-empty.")
    }
    if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
      g5_stop("AMD EMA TRAIN grid-selection CSVs must be written under ignored runs/ paths.")
    }
  }
  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(grid_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(measurement_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(selected_parameter_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(train_grid_selection$run_manifest, manifest_path, row.names = FALSE, na = "")
  utils::write.csv(train_grid_selection$declared_grid, grid_path, row.names = FALSE, na = "")
  utils::write.csv(train_grid_selection$train_measurement_surface, measurement_path, row.names = FALSE, na = "")
  utils::write.csv(train_grid_selection$selected_parameters, selected_parameter_path, row.names = FALSE, na = "")
  invisible(list(
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = FALSE),
    grid_path = normalizePath(grid_path, winslash = "/", mustWork = FALSE),
    measurement_path = normalizePath(measurement_path, winslash = "/", mustWork = FALSE),
    selected_parameter_path = normalizePath(selected_parameter_path, winslash = "/", mustWork = FALSE)
  ))
}
