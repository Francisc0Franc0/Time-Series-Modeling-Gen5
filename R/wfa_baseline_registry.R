# Gen5 minimal WFA baseline-family registry scaffold.

g5_wfa_required_baseline_registry_columns <- function() {
  c(
    "baseline_family_id",
    "research_question_group",
    "diagnostic_group",
    "baseline_family_label",
    "baseline_family_purpose",
    "baseline_family_status",
    "entry_exit_timing_status",
    "asset_selection_status",
    "allocation_status",
    "return_computation_status",
    "performance_evaluation_status",
    "uses_same_fold_calendar",
    "requires_accepted_handoff_gate",
    "uses_same_health_gate",
    "uses_same_train_oos_audit",
    "uses_frozen_fold_evidence",
    "source_handoff_reference",
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
    "fold_calendar_policy",
    "audit_rule",
    "out_of_scope_guardrail"
  )
}

g5_wfa_baseline_family_definitions <- function() {
  data.frame(
    baseline_family_id = c(
      "no_trade_cash",
      "broad_market_buy_hold",
      "per_asset_buy_hold",
      "fixed_equal_weight_basket_buy_hold",
      "active_curation_no_timing"
    ),
    research_question_group = c(
      "core_no_position_reference",
      "core_market_reference",
      "asset_level_passive_reference",
      "basket_construction_reference",
      "curation_reference"
    ),
    diagnostic_group = c(
      "core",
      "core",
      "asset_level",
      "basket",
      "curation"
    ),
    baseline_family_label = c(
      "No trade / cash",
      "Broad-market buy-and-hold",
      "Per-asset buy-and-hold",
      "Fixed equal-weight basket buy-and-hold",
      "Active curation with passive holding"
    ),
    baseline_family_purpose = c(
      "Reserve cash/no-position as a first-class competitor.",
      "Reserve SPY/QQQ-style passive market references when present in the handoff universe.",
      "Reserve one passive hold comparison per source handoff asset.",
      "Reserve a predeclared equal-weight basket comparison without timing rules.",
      "Reserve active basket or universe curation without additional entry/exit timing."
    ),
    entry_exit_timing_status = c(
      "no_entry_no_exit_cash_position_reserved",
      "buy_and_hold_no_additional_timing_reserved",
      "buy_and_hold_no_additional_timing_reserved",
      "buy_and_hold_no_additional_timing_reserved",
      "curation_only_no_additional_entry_exit_timing_reserved"
    ),
    asset_selection_status = c(
      "no_asset_selection_cash_reserved_no_oos_selection",
      "broad_market_symbols_must_be_predeclared_or_handoff_present_no_oos_selection",
      "per_handoff_asset_reserved_no_oos_selection",
      "fixed_basket_members_must_be_predeclared_no_oos_selection",
      "curation_rules_must_be_predeclared_no_oos_selection"
    ),
    allocation_status = "not_implemented_no_allocation_or_weighting",
    stringsAsFactors = FALSE
  )
}

g5_wfa_validate_frozen_evidence_for_baselines <- function(frozen_fold_evidence, fold_geometry) {
  g5_wfa_require_columns(
    frozen_fold_evidence,
    g5_wfa_required_frozen_evidence_columns(),
    "frozen fold evidence"
  )
  if (nrow(frozen_fold_evidence) != nrow(fold_geometry)) {
    g5_stop("frozen fold evidence must contain one row per fold.")
  }
  if (!identical(as.character(frozen_fold_evidence$fold_id), as.character(fold_geometry$fold_id))) {
    g5_stop("frozen fold evidence fold_id order must match fold_geometry.")
  }
  if (any(as.character(frozen_fold_evidence$evidence_status) != "FROZEN_NO_ACTIVE_DECISION")) {
    g5_stop("Baseline registry scaffolding requires frozen no-active-decision fold evidence.")
  }
  if (any(as.logical(frozen_fold_evidence$oos_performance_evaluated))) {
    g5_stop("Baseline registry scaffolding cannot consume evidence with OOS performance evaluated.")
  }
  if (any(!as.logical(frozen_fold_evidence$leakage_no_provider_calls)) ||
      any(!as.logical(frozen_fold_evidence$leakage_no_latest_session_inference)) ||
      any(!as.logical(frozen_fold_evidence$leakage_no_oos_fitting))) {
    g5_stop("Baseline registry scaffolding requires clean frozen evidence leakage attestations.")
  }
  if (any(!is.na(frozen_fold_evidence$active_candidate_id) &
          nzchar(as.character(frozen_fold_evidence$active_candidate_id)))) {
    g5_stop("Baseline registry scaffolding must not consume active candidate decisions.")
  }
  frozen_fold_evidence
}

g5_build_wfa_baseline_family_registry <- function(
  gate_result,
  fold_geometry,
  frozen_fold_evidence,
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

  review_required <- isTRUE(as.logical(gate_result$review_required[[1L]])) ||
    any(as.logical(fold_geometry$handoff_review_required)) ||
    any(as.logical(frozen_fold_evidence$handoff_review_required))
  review_accepted <- if (review_required) {
    isTRUE(accept_review_required) &&
      all(as.logical(fold_geometry$handoff_review_accepted), na.rm = TRUE) &&
      all(as.logical(frozen_fold_evidence$handoff_review_accepted), na.rm = TRUE)
  } else {
    FALSE
  }
  if (review_required && !review_accepted) {
    g5_stop("Baseline registry scaffolding requires explicit acceptance for REVIEW_REQUIRED handoffs.")
  }

  definitions <- g5_wfa_baseline_family_definitions()
  fold_count <- nrow(fold_geometry)
  first_fold <- fold_geometry[1L, , drop = FALSE]
  last_fold <- fold_geometry[fold_count, , drop = FALSE]
  source_handoff_reference <- unique(as.character(fold_geometry$source_handoff_reference))
  if (length(source_handoff_reference) != 1L || !nzchar(source_handoff_reference[[1L]])) {
    g5_stop("Baseline registry scaffolding requires one source_handoff_reference.")
  }

  out <- data.frame(
    baseline_family_id = definitions$baseline_family_id,
    research_question_group = definitions$research_question_group,
    diagnostic_group = definitions$diagnostic_group,
    baseline_family_label = definitions$baseline_family_label,
    baseline_family_purpose = definitions$baseline_family_purpose,
    baseline_family_status = "reserved_declarative_only_no_returns_or_performance",
    entry_exit_timing_status = definitions$entry_exit_timing_status,
    asset_selection_status = definitions$asset_selection_status,
    allocation_status = definitions$allocation_status,
    return_computation_status = "not_implemented_no_return_columns_read_or_created",
    performance_evaluation_status = "not_implemented_no_benchmark_performance_computed",
    uses_same_fold_calendar = TRUE,
    requires_accepted_handoff_gate = TRUE,
    uses_same_health_gate = TRUE,
    uses_same_train_oos_audit = TRUE,
    uses_frozen_fold_evidence = TRUE,
    source_handoff_reference = source_handoff_reference[[1L]],
    handoff_gate_status = as.character(gate_result$gate_status[[1L]]),
    handoff_review_required = review_required,
    handoff_review_accepted = review_accepted,
    as_of_timestamp = as.character(gate_result$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(gate_result$latest_completed_session[[1L]]),
    fold_count = as.integer(fold_count),
    first_fold_id = as.character(first_fold$fold_id[[1L]]),
    last_fold_id = as.character(last_fold$fold_id[[1L]]),
    first_oos_start_date = as.Date(first_fold$oos_start_date[[1L]]),
    last_oos_end_date = as.Date(last_fold$oos_end_date[[1L]]),
    fold_calendar_policy = "same_explicit_quarterly_fold_geometry_as_active_candidates",
    audit_rule = "same_handoff_health_train_oos_split_and_frozen_evidence_discipline",
    out_of_scope_guardrail = paste(
      "declarative_only_no_returns_no_performance_no_allocation",
      "no_execution_no_live_advice_no_oos_asset_selection"
    ),
    stringsAsFactors = FALSE
  )

  rownames(out) <- NULL
  out[g5_wfa_required_baseline_registry_columns()]
}

g5_write_wfa_baseline_family_registry_csv <- function(
  baseline_registry,
  path,
  require_ignored_run_path = TRUE
) {
  g5_wfa_require_columns(
    baseline_registry,
    g5_wfa_required_baseline_registry_columns(),
    "baseline family registry"
  )
  if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
    g5_stop("baseline registry output path must be one non-empty value.")
  }
  path <- as.character(path)
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("Baseline registry artifacts must be written under ignored runs/ paths.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(baseline_registry, path, row.names = FALSE, na = "")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
