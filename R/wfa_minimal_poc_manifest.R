# Gen5 minimal WFA POC manifest and review-surface scaffold.

g5_wfa_minimal_poc_schema_version <- function() {
  "g5_wfa_minimal_poc_v0"
}

g5_wfa_required_minimal_poc_manifest_columns <- function() {
  c(
    "schema_version",
    "poc_run_id",
    "source_handoff_reference",
    "source_gate_manifest_csv",
    "handoff_gate_status",
    "handoff_review_required",
    "handoff_review_accepted",
    "as_of_timestamp",
    "latest_completed_session",
    "fold_count",
    "first_fold_id",
    "last_fold_id",
    "first_oos_start_date",
    "last_oos_end_date",
    "fold_geometry_status",
    "train_oos_split_status",
    "frozen_evidence_status",
    "baseline_registry_status",
    "baseline_evaluation_contract_status",
    "fold_stability_placeholder_status",
    "ignored_output_dir",
    "run_manifest_path",
    "review_surface_path",
    "artifact_path_policy",
    "evaluation_authorization_status",
    "oos_result_status",
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

g5_wfa_required_minimal_poc_review_columns <- function() {
  c(
    "schema_version",
    "poc_run_id",
    "review_row_id",
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
    "train_row_count",
    "train_symbol_count",
    "source_warning_count",
    "source_warning_context",
    "no_trade_readiness_status",
    "reserved_baseline_readiness_status",
    "baseline_family_ids",
    "baseline_evaluation_contract_status",
    "fold_stability_placeholder_status",
    "review_status",
    "review_required_reason",
    "artifact_path",
    "artifact_path_policy",
    "evaluation_authorization_status",
    "oos_result_status",
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

g5_wfa_minimal_poc_run_id <- function(as_of_timestamp, first_fold_id, last_fold_id) {
  paste(
    "minimal_wfa_poc",
    g5_wfa_sanitize_id_component(as_of_timestamp, "as_of_timestamp"),
    g5_wfa_sanitize_id_component(first_fold_id, "first_fold_id"),
    g5_wfa_sanitize_id_component(last_fold_id, "last_fold_id"),
    sep = "_"
  )
}

g5_wfa_minimal_poc_artifact_path <- function(
  output_dir,
  poc_run_id,
  artifact_name,
  require_ignored_run_path = TRUE
) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(as.character(output_dir))) {
    g5_stop("minimal WFA POC output_dir must be one non-empty value.")
  }
  path <- file.path(
    as.character(output_dir),
    g5_wfa_sanitize_id_component(poc_run_id, "poc_run_id"),
    artifact_name
  )
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("Minimal WFA POC artifacts must be planned under ignored runs/ paths.")
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_wfa_validate_baseline_inputs_for_minimal_poc <- function(
  baseline_registry,
  baseline_evaluation_contract,
  fold_geometry
) {
  g5_wfa_require_columns(
    baseline_registry,
    g5_wfa_required_baseline_registry_columns(),
    "baseline family registry"
  )
  if (!identical(as.character(baseline_registry$baseline_family_id[[1L]]), "no_trade_cash")) {
    g5_stop("minimal WFA POC scaffold requires no_trade_cash as the first baseline family.")
  }
  if (any(as.character(baseline_registry$baseline_family_status) !=
          "reserved_declarative_only_no_returns_or_performance")) {
    g5_stop("minimal WFA POC scaffold cannot consume result-enabled baseline families.")
  }
  if (any(as.character(baseline_registry$return_computation_status) !=
          "not_implemented_no_return_columns_read_or_created") ||
      any(as.character(baseline_registry$performance_evaluation_status) !=
          "not_implemented_no_benchmark_performance_computed") ||
      any(as.character(baseline_registry$allocation_status) !=
          "not_implemented_no_allocation_or_weighting")) {
    g5_stop("minimal WFA POC scaffold rejects return, performance, or allocation-enabled baselines.")
  }
  if (any(as.integer(baseline_registry$fold_count) != nrow(fold_geometry))) {
    g5_stop("baseline family registry fold_count must match fold_geometry.")
  }

  baseline_evaluation_contract <- g5_validate_wfa_baseline_evaluation_contract_scaffold(
    baseline_evaluation_contract
  )
  if (!identical(as.character(baseline_evaluation_contract$baseline_family_id[[1L]]), "no_trade_cash")) {
    g5_stop("minimal WFA POC scaffold requires no_trade_cash first in the evaluation contract.")
  }
  if (any(as.character(baseline_evaluation_contract$evaluation_authorization_status) !=
          "not_authorized_no_returns_or_performance")) {
    g5_stop("minimal WFA POC scaffold cannot consume authorized baseline evaluation rows.")
  }

  list(
    baseline_registry = baseline_registry,
    baseline_evaluation_contract = baseline_evaluation_contract
  )
}

g5_build_wfa_minimal_poc_scaffold <- function(
  gate_result,
  fold_geometry,
  split_audit,
  frozen_fold_evidence,
  baseline_registry,
  baseline_evaluation_contract,
  output_dir = file.path("runs", "wfa_minimal_poc"),
  accept_review_required = FALSE
) {
  gate_result <- g5_wfa_validate_gate_result_for_geometry(
    gate_result,
    accept_review_required = accept_review_required
  )
  fold_geometry <- g5_wfa_validate_fold_geometry_for_split(fold_geometry, gate_result)
  split_summary <- g5_wfa_validate_split_audit_for_evidence(split_audit, fold_geometry)
  frozen_fold_evidence <- g5_wfa_validate_frozen_evidence_for_baselines(
    frozen_fold_evidence,
    fold_geometry
  )
  baseline_inputs <- g5_wfa_validate_baseline_inputs_for_minimal_poc(
    baseline_registry = baseline_registry,
    baseline_evaluation_contract = baseline_evaluation_contract,
    fold_geometry = fold_geometry
  )
  baseline_registry <- baseline_inputs$baseline_registry
  baseline_evaluation_contract <- baseline_inputs$baseline_evaluation_contract

  review_required <- isTRUE(as.logical(gate_result$review_required[[1L]])) ||
    any(as.logical(fold_geometry$handoff_review_required)) ||
    any(as.logical(frozen_fold_evidence$handoff_review_required)) ||
    any(as.logical(baseline_registry$handoff_review_required)) ||
    any(as.logical(baseline_evaluation_contract$handoff_review_required))
  review_accepted <- if (review_required) {
    isTRUE(accept_review_required) &&
      all(as.logical(fold_geometry$handoff_review_accepted), na.rm = TRUE) &&
      all(as.logical(frozen_fold_evidence$handoff_review_accepted), na.rm = TRUE) &&
      all(as.logical(baseline_registry$handoff_review_accepted), na.rm = TRUE) &&
      all(as.logical(baseline_evaluation_contract$handoff_review_accepted), na.rm = TRUE)
  } else {
    FALSE
  }
  if (review_required && !review_accepted) {
    g5_stop("Minimal WFA POC scaffold requires explicit acceptance for REVIEW_REQUIRED handoffs.")
  }

  first_fold <- fold_geometry[1L, , drop = FALSE]
  last_fold <- fold_geometry[nrow(fold_geometry), , drop = FALSE]
  poc_run_id <- g5_wfa_minimal_poc_run_id(
    as_of_timestamp = gate_result$as_of_timestamp[[1L]],
    first_fold_id = first_fold$fold_id[[1L]],
    last_fold_id = last_fold$fold_id[[1L]]
  )
  run_manifest_path <- g5_wfa_minimal_poc_artifact_path(
    output_dir = output_dir,
    poc_run_id = poc_run_id,
    artifact_name = "minimal_wfa_poc_run_manifest.csv"
  )
  review_surface_path <- g5_wfa_minimal_poc_artifact_path(
    output_dir = output_dir,
    poc_run_id = poc_run_id,
    artifact_name = "minimal_wfa_poc_review_surface.csv"
  )

  baseline_ids <- paste(as.character(baseline_registry$baseline_family_id), collapse = ";")
  baseline_contract_folds <- sort(unique(as.character(baseline_evaluation_contract$fold_id)))
  if (!identical(baseline_contract_folds, sort(as.character(fold_geometry$fold_id)))) {
    g5_stop("baseline evaluation contract must cover the minimal WFA POC fold ids.")
  }

  manifest <- data.frame(
    schema_version = g5_wfa_minimal_poc_schema_version(),
    poc_run_id = poc_run_id,
    source_handoff_reference = as.character(first_fold$source_handoff_reference[[1L]]),
    source_gate_manifest_csv = as.character(gate_result$manifest_csv[[1L]]),
    handoff_gate_status = as.character(gate_result$gate_status[[1L]]),
    handoff_review_required = review_required,
    handoff_review_accepted = review_accepted,
    as_of_timestamp = as.character(gate_result$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(gate_result$latest_completed_session[[1L]]),
    fold_count = as.integer(nrow(fold_geometry)),
    first_fold_id = as.character(first_fold$fold_id[[1L]]),
    last_fold_id = as.character(last_fold$fold_id[[1L]]),
    first_oos_start_date = as.Date(first_fold$oos_start_date[[1L]]),
    last_oos_end_date = as.Date(last_fold$oos_end_date[[1L]]),
    fold_geometry_status = "explicit_quarterly_geometry_recorded",
    train_oos_split_status = "split_audit_recorded_no_outcome_membership",
    frozen_evidence_status = "frozen_no_active_decision_evidence_recorded",
    baseline_registry_status = "no_trade_first_reserved_baselines_recorded",
    baseline_evaluation_contract_status = "contract_scaffold_available_not_evaluated",
    fold_stability_placeholder_status = "not_evaluated_fold_stability_not_authorized",
    ignored_output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
    run_manifest_path = run_manifest_path,
    review_surface_path = review_surface_path,
    artifact_path_policy = "deterministic_ignored_runs_path_schema_only",
    evaluation_authorization_status = "not_authorized_no_oos_evaluation",
    oos_result_status = "not_evaluated_oos_results_not_read",
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

  review_rows <- vector("list", nrow(fold_geometry))
  for (i in seq_len(nrow(fold_geometry))) {
    fold <- fold_geometry[i, , drop = FALSE]
    evidence <- frozen_fold_evidence[i, , drop = FALSE]
    summary <- split_summary[i, , drop = FALSE]
    source_warning_count <- as.integer(evidence$source_warning_count[[1L]])
    review_reason <- character()
    if (review_required || source_warning_count > 0L) {
      review_reason <- c(review_reason, "accepted_source_warning_context_requires_review_visibility")
    }
    review_reason <- c(
      review_reason,
      "fold_stability_placeholder_not_evaluated",
      "oos_evaluation_not_authorized"
    )

    review_rows[[i]] <- data.frame(
      schema_version = g5_wfa_minimal_poc_schema_version(),
      poc_run_id = poc_run_id,
      review_row_id = paste("minimal_wfa_poc_review", as.character(fold$fold_id[[1L]]), sep = "_"),
      fold_id = as.character(fold$fold_id[[1L]]),
      frozen_evidence_id = as.character(evidence$evidence_id[[1L]]),
      source_handoff_reference = as.character(fold$source_handoff_reference[[1L]]),
      source_gate_manifest_csv = as.character(gate_result$manifest_csv[[1L]]),
      handoff_gate_status = as.character(gate_result$gate_status[[1L]]),
      handoff_review_required = review_required,
      handoff_review_accepted = review_accepted,
      as_of_timestamp = as.character(gate_result$as_of_timestamp[[1L]]),
      latest_completed_session = as.Date(gate_result$latest_completed_session[[1L]]),
      oos_start_date = as.Date(fold$oos_start_date[[1L]]),
      oos_end_date = as.Date(fold$oos_end_date[[1L]]),
      train_row_count = as.integer(summary$train_row_count[[1L]]),
      train_symbol_count = as.integer(summary$train_symbol_count[[1L]]),
      source_warning_count = source_warning_count,
      source_warning_context = as.character(evidence$source_warning_context[[1L]]),
      no_trade_readiness_status = "no_trade_cash_reserved_first_no_returns_computed",
      reserved_baseline_readiness_status = "reserved_baseline_families_recorded_no_results",
      baseline_family_ids = baseline_ids,
      baseline_evaluation_contract_status = "contract_scaffold_available_not_evaluated",
      fold_stability_placeholder_status = "not_evaluated_fold_stability_not_authorized",
      review_status = "review_surface_ready_no_evaluation_authorized",
      review_required_reason = paste(unique(review_reason), collapse = ";"),
      artifact_path = g5_wfa_minimal_poc_artifact_path(
        output_dir = output_dir,
        poc_run_id = poc_run_id,
        artifact_name = file.path(
          "fold_review_surfaces",
          paste0(g5_wfa_sanitize_id_component(fold$fold_id[[1L]], "fold_id"), "__review.csv")
        )
      ),
      artifact_path_policy = "deterministic_ignored_runs_path_schema_only",
      evaluation_authorization_status = "not_authorized_no_oos_evaluation",
      oos_result_status = "not_evaluated_oos_results_not_read",
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

  review_surface <- do.call(rbind, review_rows)
  rownames(manifest) <- NULL
  rownames(review_surface) <- NULL

  list(
    run_manifest = manifest[g5_wfa_required_minimal_poc_manifest_columns()],
    review_surface = review_surface[g5_wfa_required_minimal_poc_review_columns()]
  )
}

g5_validate_wfa_minimal_poc_scaffold <- function(scaffold) {
  if (!is.list(scaffold) ||
      is.null(scaffold$run_manifest) ||
      is.null(scaffold$review_surface)) {
    g5_stop("minimal WFA POC scaffold must be a list with run_manifest and review_surface.")
  }
  g5_wfa_require_columns(
    scaffold$run_manifest,
    g5_wfa_required_minimal_poc_manifest_columns(),
    "minimal WFA POC run manifest"
  )
  g5_wfa_require_columns(
    scaffold$review_surface,
    g5_wfa_required_minimal_poc_review_columns(),
    "minimal WFA POC review surface"
  )
  if (nrow(scaffold$run_manifest) != 1L) {
    g5_stop("minimal WFA POC run manifest must contain exactly one row.")
  }
  if (nrow(scaffold$review_surface) == 0L) {
    g5_stop("minimal WFA POC review surface must contain at least one row.")
  }
  if (any(as.character(scaffold$run_manifest$schema_version) !=
          g5_wfa_minimal_poc_schema_version()) ||
      any(as.character(scaffold$review_surface$schema_version) !=
          g5_wfa_minimal_poc_schema_version())) {
    g5_stop("minimal WFA POC scaffold has an unexpected schema_version.")
  }
  if (any(duplicated(as.character(scaffold$review_surface$review_row_id)))) {
    g5_stop("minimal WFA POC review surface review_row_id values must be unique.")
  }
  if (!identical(
    unique(as.character(scaffold$review_surface$poc_run_id)),
    as.character(scaffold$run_manifest$poc_run_id[[1L]])
  )) {
    g5_stop("minimal WFA POC review surface must reference the run manifest poc_run_id.")
  }
  if (as.integer(scaffold$run_manifest$fold_count[[1L]]) != nrow(scaffold$review_surface)) {
    g5_stop("minimal WFA POC run manifest fold_count must match review surface rows.")
  }

  status_cols <- c(
    "return_computation_status",
    "cash_yield_status",
    "benchmark_math_status",
    "performance_metric_status",
    "allocation_status",
    "active_candidate_status"
  )
  expected <- list(
    return_computation_status = "not_implemented_no_return_columns_read_or_created",
    cash_yield_status = "not_implemented_no_cash_yield_assumption",
    benchmark_math_status = "not_implemented_no_benchmark_math",
    performance_metric_status = "not_implemented_no_performance_metrics",
    allocation_status = "not_implemented_no_allocation_or_weighting",
    active_candidate_status = "not_authorized_no_active_candidate_inputs"
  )
  for (col in status_cols) {
    if (any(as.character(scaffold$run_manifest[[col]]) != expected[[col]]) ||
        any(as.character(scaffold$review_surface[[col]]) != expected[[col]])) {
      g5_stop(paste("minimal WFA POC scaffold has unauthorized implementation status in", col))
    }
  }
  if (any(as.character(scaffold$run_manifest$evaluation_authorization_status) !=
          "not_authorized_no_oos_evaluation") ||
      any(as.character(scaffold$review_surface$evaluation_authorization_status) !=
          "not_authorized_no_oos_evaluation")) {
    g5_stop("minimal WFA POC scaffold must not authorize OOS evaluation.")
  }
  if (any(as.character(scaffold$run_manifest$oos_result_status) !=
          "not_evaluated_oos_results_not_read") ||
      any(as.character(scaffold$review_surface$oos_result_status) !=
          "not_evaluated_oos_results_not_read")) {
    g5_stop("minimal WFA POC scaffold must not record evaluated OOS results.")
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
    if (any(!as.logical(scaffold$run_manifest[[col]])) ||
        any(!as.logical(scaffold$review_surface[[col]]))) {
      g5_stop(paste("minimal WFA POC scaffold leakage attestation failed:", col))
    }
  }

  paths <- c(
    scaffold$run_manifest$ignored_output_dir,
    scaffold$run_manifest$run_manifest_path,
    scaffold$run_manifest$review_surface_path,
    scaffold$review_surface$artifact_path
  )
  bad_paths <- !vapply(paths, g5_wfa_path_looks_ignored_run_path, logical(1L))
  if (any(bad_paths)) {
    g5_stop("minimal WFA POC scaffold artifact paths must be under ignored runs/ paths.")
  }

  scaffold
}
