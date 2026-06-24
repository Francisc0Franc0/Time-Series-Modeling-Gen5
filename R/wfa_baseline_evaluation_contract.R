# Gen5 minimal WFA no-trade and reserved baseline evaluation contract scaffold.

g5_wfa_baseline_evaluation_contract_schema_version <- function() {
  "g5_wfa_baseline_evaluation_contract_v0"
}

g5_wfa_required_baseline_evaluation_contract_columns <- function() {
  c(
    "schema_version",
    "contract_id",
    "baseline_family_id",
    "baseline_family_status",
    "fold_id",
    "frozen_evidence_id",
    "source_handoff_reference",
    "source_gate_manifest_csv",
    "handoff_gate_status",
    "handoff_review_required",
    "handoff_review_accepted",
    "as_of_timestamp",
    "latest_completed_session",
    "oos_start_date",
    "oos_end_date",
    "artifact_path",
    "artifact_path_policy",
    "application_status",
    "evaluation_authorization_status",
    "review_status",
    "review_required_reason",
    "cash_no_position_assumption_status",
    "proxy_symbol_review_status",
    "fold_coverage_review_status",
    "source_warning_review_status",
    "return_computation_status",
    "cash_yield_status",
    "benchmark_math_status",
    "performance_metric_status",
    "allocation_status",
    "active_candidate_status",
    "leakage_no_provider_calls",
    "leakage_no_credentials",
    "leakage_no_unmanifested_cache",
    "leakage_no_latest_session_inference",
    "leakage_no_oos_outcome_authority",
    "leakage_no_oos_fitting",
    "leakage_no_active_candidate_inputs",
    "leakage_no_return_or_metric_computation"
  )
}

g5_wfa_sanitize_id_component <- function(x, label) {
  if (length(x) != 1L || is.na(x) || !nzchar(as.character(x))) {
    g5_stop(paste(label, "must be one non-empty value."))
  }
  out <- gsub("[^A-Za-z0-9_]+", "_", as.character(x))
  out <- gsub("_+", "_", out)
  out <- gsub("^_|_$", "", out)
  if (!nzchar(out)) {
    g5_stop(paste(label, "does not contain a usable identifier component."))
  }
  out
}

g5_wfa_baseline_evaluation_artifact_path <- function(
  output_dir,
  fold_id,
  baseline_family_id,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("baseline evaluation output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    "oos_application_evaluation_audit_placeholders",
    paste0(
      g5_wfa_sanitize_id_component(fold_id, "fold_id"),
      "__",
      g5_wfa_sanitize_id_component(baseline_family_id, "baseline_family_id"),
      "__contract.csv"
    )
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("Baseline evaluation contract artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_wfa_validate_baseline_registry_for_evaluation_contract <- function(
  baseline_registry,
  fold_geometry
) {
  g5_wfa_require_columns(
    baseline_registry,
    g5_wfa_required_baseline_registry_columns(),
    "baseline family registry"
  )
  if (nrow(baseline_registry) == 0L) {
    g5_stop("baseline family registry must contain at least no_trade.")
  }
  if (any(duplicated(as.character(baseline_registry$baseline_family_id)))) {
    g5_stop("baseline family registry baseline_family_id values must be unique.")
  }
  if (!identical(as.character(baseline_registry$baseline_family_id[[1L]]), "no_trade_cash")) {
    g5_stop("baseline evaluation contract scaffold must keep no_trade_cash first.")
  }
  if (any(as.character(baseline_registry$return_computation_status) !=
          "not_implemented_no_return_columns_read_or_created")) {
    g5_stop("baseline evaluation contract scaffold cannot consume return-enabled baseline registry rows.")
  }
  if (any(as.character(baseline_registry$performance_evaluation_status) !=
          "not_implemented_no_benchmark_performance_computed")) {
    g5_stop("baseline evaluation contract scaffold cannot consume performance-enabled baseline registry rows.")
  }
  if (any(as.character(baseline_registry$allocation_status) !=
          "not_implemented_no_allocation_or_weighting")) {
    g5_stop("baseline evaluation contract scaffold cannot consume allocation-enabled baseline registry rows.")
  }
  if (any(!as.logical(baseline_registry$uses_same_fold_calendar)) ||
      any(!as.logical(baseline_registry$uses_same_health_gate)) ||
      any(!as.logical(baseline_registry$uses_same_train_oos_audit)) ||
      any(!as.logical(baseline_registry$uses_frozen_fold_evidence))) {
    g5_stop("baseline evaluation contract scaffold requires shared WFA audit discipline.")
  }
  if (any(as.integer(baseline_registry$fold_count) != nrow(fold_geometry))) {
    g5_stop("baseline family registry fold_count must match fold_geometry.")
  }
  baseline_registry
}

g5_wfa_baseline_contract_review_reason <- function(
  baseline_family_id,
  handoff_review_required,
  source_warning_count
) {
  reasons <- character()
  if (isTRUE(handoff_review_required) || source_warning_count > 0L) {
    reasons <- c(reasons, "accepted_source_warning_context_requires_review_visibility")
  }
  if (identical(baseline_family_id, "no_trade_cash")) {
    reasons <- c(reasons, "cash_no_position_return_assumption_not_defined_in_contract_scaffold")
  }
  if (identical(baseline_family_id, "broad_market_buy_hold")) {
    reasons <- c(reasons, "broad_market_proxy_presence_not_evaluated_in_contract_scaffold")
  }
  if (identical(baseline_family_id, "fixed_equal_weight_basket_buy_hold")) {
    reasons <- c(reasons, "fixed_basket_members_not_selected_or_weighted_in_contract_scaffold")
  }
  if (identical(baseline_family_id, "active_curation_no_timing")) {
    reasons <- c(reasons, "curation_rules_not_authorized_in_contract_scaffold")
  }
  if (length(reasons) == 0L) {
    return("")
  }
  paste(reasons, collapse = ";")
}

g5_build_wfa_baseline_evaluation_contract_scaffold <- function(
  gate_result,
  fold_geometry,
  frozen_fold_evidence,
  baseline_registry,
  included_baseline_family_ids = NULL,
  output_dir = file.path("runs", "wfa_baseline_evaluation_contract"),
  accept_review_required = FALSE
) {
  gate_result <- g5_wfa_validate_gate_result_for_geometry(
    gate_result,
    accept_review_required = accept_review_required
  )
  fold_geometry <- g5_wfa_validate_fold_geometry_for_split(fold_geometry, gate_result)
  frozen_fold_evidence <- g5_wfa_validate_frozen_evidence_for_baselines(
    frozen_fold_evidence,
    fold_geometry
  )
  baseline_registry <- g5_wfa_validate_baseline_registry_for_evaluation_contract(
    baseline_registry,
    fold_geometry
  )

  available_ids <- as.character(baseline_registry$baseline_family_id)
  if (is.null(included_baseline_family_ids)) {
    included_baseline_family_ids <- available_ids
  } else {
    included_baseline_family_ids <- as.character(included_baseline_family_ids)
  }
  if (length(included_baseline_family_ids) == 0L ||
      any(is.na(included_baseline_family_ids)) ||
      any(!nzchar(included_baseline_family_ids))) {
    g5_stop("included_baseline_family_ids must include no_trade_cash.")
  }
  if (!identical(included_baseline_family_ids[[1L]], "no_trade_cash")) {
    g5_stop("baseline evaluation contract scaffold must start with no_trade_cash.")
  }
  unknown <- setdiff(included_baseline_family_ids, available_ids)
  if (length(unknown) > 0L) {
    g5_stop(paste("included baseline families are not reserved:", paste(unknown, collapse = ", ")))
  }
  included_registry <- baseline_registry[
    match(included_baseline_family_ids, available_ids),
    ,
    drop = FALSE
  ]

  review_required <- isTRUE(as.logical(gate_result$review_required[[1L]])) ||
    any(as.logical(fold_geometry$handoff_review_required)) ||
    any(as.logical(frozen_fold_evidence$handoff_review_required)) ||
    any(as.logical(included_registry$handoff_review_required))
  review_accepted <- if (review_required) {
    isTRUE(accept_review_required) &&
      all(as.logical(fold_geometry$handoff_review_accepted), na.rm = TRUE) &&
      all(as.logical(frozen_fold_evidence$handoff_review_accepted), na.rm = TRUE) &&
      all(as.logical(included_registry$handoff_review_accepted), na.rm = TRUE)
  } else {
    FALSE
  }
  if (review_required && !review_accepted) {
    g5_stop("Baseline evaluation contract scaffold requires explicit acceptance for REVIEW_REQUIRED handoffs.")
  }

  rows <- vector("list", nrow(fold_geometry) * nrow(included_registry))
  k <- 0L
  for (family_i in seq_len(nrow(included_registry))) {
    family <- included_registry[family_i, , drop = FALSE]
    family_id <- as.character(family$baseline_family_id[[1L]])
    for (fold_i in seq_len(nrow(fold_geometry))) {
      fold <- fold_geometry[fold_i, , drop = FALSE]
      evidence <- frozen_fold_evidence[fold_i, , drop = FALSE]
      source_warning_count <- as.integer(evidence$source_warning_count[[1L]])
      review_reason <- g5_wfa_baseline_contract_review_reason(
        baseline_family_id = family_id,
        handoff_review_required = review_required,
        source_warning_count = source_warning_count
      )
      k <- k + 1L
      rows[[k]] <- data.frame(
        schema_version = g5_wfa_baseline_evaluation_contract_schema_version(),
        contract_id = paste(
          "baseline_eval_contract",
          family_id,
          as.character(fold$fold_id[[1L]]),
          sep = "_"
        ),
        baseline_family_id = family_id,
        baseline_family_status = as.character(family$baseline_family_status[[1L]]),
        fold_id = as.character(fold$fold_id[[1L]]),
        frozen_evidence_id = as.character(evidence$evidence_id[[1L]]),
        source_handoff_reference = as.character(fold$source_handoff_reference[[1L]]),
        source_gate_manifest_csv = as.character(evidence$source_gate_manifest_csv[[1L]]),
        handoff_gate_status = as.character(gate_result$gate_status[[1L]]),
        handoff_review_required = review_required,
        handoff_review_accepted = review_accepted,
        as_of_timestamp = as.character(gate_result$as_of_timestamp[[1L]]),
        latest_completed_session = as.Date(gate_result$latest_completed_session[[1L]]),
        oos_start_date = as.Date(fold$oos_start_date[[1L]]),
        oos_end_date = as.Date(fold$oos_end_date[[1L]]),
        artifact_path = g5_wfa_baseline_evaluation_artifact_path(
          output_dir = output_dir,
          fold_id = fold$fold_id[[1L]],
          baseline_family_id = family_id
        ),
        artifact_path_policy = "deterministic_ignored_runs_path_contract_only",
        application_status = "not_applied_contract_scaffold_only",
        evaluation_authorization_status = "not_authorized_no_returns_or_performance",
        review_status = if (nzchar(review_reason)) {
          "review_required_before_any_evaluation"
        } else {
          "schema_ready_no_evaluation_authorized"
        },
        review_required_reason = review_reason,
        cash_no_position_assumption_status = if (identical(family_id, "no_trade_cash")) {
          "not_defined_no_cash_yield_or_return_assumption"
        } else {
          "not_applicable"
        },
        proxy_symbol_review_status = if (identical(family_id, "broad_market_buy_hold")) {
          "not_checked_contract_scaffold_only"
        } else {
          "not_applicable"
        },
        fold_coverage_review_status = "fold_presence_recorded_no_returns_or_metrics_checked",
        source_warning_review_status = if (review_required || source_warning_count > 0L) {
          "accepted_warning_context_preserved_for_review"
        } else {
          "no_source_warning_context_recorded"
        },
        return_computation_status = "not_implemented_no_return_columns_read_or_created",
        cash_yield_status = "not_implemented_no_cash_yield_assumption",
        benchmark_math_status = "not_implemented_no_benchmark_math",
        performance_metric_status = "not_implemented_no_performance_metrics",
        allocation_status = "not_implemented_no_allocation_or_weighting",
        active_candidate_status = "not_authorized_no_active_candidate_inputs",
        leakage_no_provider_calls = TRUE,
        leakage_no_credentials = TRUE,
        leakage_no_unmanifested_cache = TRUE,
        leakage_no_latest_session_inference = TRUE,
        leakage_no_oos_outcome_authority = TRUE,
        leakage_no_oos_fitting = TRUE,
        leakage_no_active_candidate_inputs = TRUE,
        leakage_no_return_or_metric_computation = TRUE,
        stringsAsFactors = FALSE
      )
    }
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[g5_wfa_required_baseline_evaluation_contract_columns()]
}

g5_validate_wfa_baseline_evaluation_contract_scaffold <- function(contract_scaffold) {
  g5_wfa_require_columns(
    contract_scaffold,
    g5_wfa_required_baseline_evaluation_contract_columns(),
    "baseline evaluation contract scaffold"
  )
  if (nrow(contract_scaffold) == 0L) {
    g5_stop("baseline evaluation contract scaffold must contain at least one row.")
  }
  if (any(duplicated(as.character(contract_scaffold$contract_id)))) {
    g5_stop("baseline evaluation contract scaffold contract_id values must be unique.")
  }
  if (!identical(as.character(contract_scaffold$baseline_family_id[[1L]]), "no_trade_cash")) {
    g5_stop("baseline evaluation contract scaffold must keep no_trade_cash first.")
  }
  if (any(as.character(contract_scaffold$schema_version) !=
          g5_wfa_baseline_evaluation_contract_schema_version())) {
    g5_stop("baseline evaluation contract scaffold has an unexpected schema_version.")
  }
  if (any(as.character(contract_scaffold$return_computation_status) !=
          "not_implemented_no_return_columns_read_or_created") ||
      any(as.character(contract_scaffold$cash_yield_status) !=
          "not_implemented_no_cash_yield_assumption") ||
      any(as.character(contract_scaffold$benchmark_math_status) !=
          "not_implemented_no_benchmark_math") ||
      any(as.character(contract_scaffold$performance_metric_status) !=
          "not_implemented_no_performance_metrics") ||
      any(as.character(contract_scaffold$allocation_status) !=
          "not_implemented_no_allocation_or_weighting")) {
    g5_stop("baseline evaluation contract scaffold must not contain return, cash yield, metric, benchmark, or allocation implementation status.")
  }
  leakage_cols <- c(
    "leakage_no_provider_calls",
    "leakage_no_credentials",
    "leakage_no_unmanifested_cache",
    "leakage_no_latest_session_inference",
    "leakage_no_oos_outcome_authority",
    "leakage_no_oos_fitting",
    "leakage_no_active_candidate_inputs",
    "leakage_no_return_or_metric_computation"
  )
  for (col in leakage_cols) {
    if (any(!as.logical(contract_scaffold[[col]]))) {
      g5_stop(paste("baseline evaluation contract scaffold leakage attestation failed:", col))
    }
  }
  bad_paths <- !vapply(
    contract_scaffold$artifact_path,
    g5_wfa_path_looks_ignored_run_path,
    logical(1L)
  )
  if (any(bad_paths)) {
    g5_stop("baseline evaluation contract scaffold artifact_path values must be under ignored runs/ paths.")
  }
  contract_scaffold
}
