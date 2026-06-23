# Gen5 minimal WFA frozen fold-decision evidence scaffold.

g5_wfa_required_frozen_evidence_columns <- function() {
  c(
    "evidence_id",
    "evidence_status",
    "fold_id",
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "decision_pack_valid_from",
    "decision_pack_valid_through",
    "source_handoff_reference",
    "source_gate_manifest_csv",
    "handoff_gate_status",
    "handoff_gate_detail",
    "handoff_review_required",
    "handoff_review_accepted",
    "as_of_timestamp",
    "latest_completed_session",
    "train_row_count",
    "train_symbol_count",
    "train_rows_available",
    "source_warning_count",
    "source_warning_context",
    "leakage_no_provider_calls",
    "leakage_no_latest_session_inference",
    "leakage_no_oos_membership_decisions",
    "leakage_no_oos_fitting",
    "oos_performance_evaluated",
    "active_candidate_id",
    "feature_model_fit_status",
    "strategy_selector_fit_status",
    "strategy_decision_status",
    "baseline_decision_status",
    "code_git_sha",
    "code_git_branch",
    "code_metadata_status"
  )
}

g5_wfa_required_split_leakage_columns <- function() {
  c(
    "provider_calls_used",
    "latest_session_inferred",
    "membership_decided_from_oos_outcomes"
  )
}

g5_wfa_collect_local_code_metadata <- function(repo_root = ".") {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = FALSE)
  git_dir <- file.path(repo_root, ".git")
  if (!dir.exists(git_dir)) {
    return(data.frame(
      code_git_sha = NA_character_,
      code_git_branch = NA_character_,
      code_metadata_status = "git_metadata_unavailable",
      stringsAsFactors = FALSE
    ))
  }

  git_value <- function(args) {
    value <- tryCatch(
      system2("git", args = args, stdout = TRUE, stderr = FALSE),
      error = function(e) character()
    )
    value <- trimws(value)
    value <- value[nzchar(value)]
    if (length(value) == 0L) {
      return(NA_character_)
    }
    value[[1L]]
  }

  sha <- git_value(c("-C", repo_root, "rev-parse", "--short", "HEAD"))
  branch <- git_value(c("-C", repo_root, "rev-parse", "--abbrev-ref", "HEAD"))
  status <- if (is.na(sha) && is.na(branch)) {
    "git_metadata_unavailable"
  } else {
    "git_metadata_recorded"
  }

  data.frame(
    code_git_sha = sha,
    code_git_branch = branch,
    code_metadata_status = status,
    stringsAsFactors = FALSE
  )
}

g5_wfa_normalize_code_metadata <- function(code_metadata = NULL, repo_root = ".") {
  if (is.null(code_metadata)) {
    return(g5_wfa_collect_local_code_metadata(repo_root = repo_root))
  }
  if (!is.data.frame(code_metadata)) {
    g5_stop("code_metadata must be a data.frame when supplied.")
  }
  required <- c("code_git_sha", "code_git_branch", "code_metadata_status")
  missing <- setdiff(required, names(code_metadata))
  if (length(missing) > 0L) {
    g5_stop(paste("code_metadata is missing required columns:", paste(missing, collapse = ", ")))
  }
  if (nrow(code_metadata) != 1L) {
    g5_stop("code_metadata must contain exactly one row.")
  }
  code_metadata[1L, required, drop = FALSE]
}

g5_wfa_warning_context <- function(warn_rows) {
  if (is.null(warn_rows) || nrow(warn_rows) == 0L) {
    return("")
  }
  g5_wfa_require_columns(warn_rows, .g5_wfa_health_required_columns, "source warning rows")
  if (any(as.character(warn_rows$severity) == "ERROR")) {
    g5_stop("Frozen fold evidence rejects ERROR source warning context.")
  }
  warn_rows <- warn_rows[as.character(warn_rows$severity) == "WARN", , drop = FALSE]
  if (nrow(warn_rows) == 0L) {
    return("")
  }
  symbols <- ifelse(
    is.na(warn_rows$symbol) | !nzchar(as.character(warn_rows$symbol)),
    "handoff",
    as.character(warn_rows$symbol)
  )
  paste(
    paste(as.character(warn_rows$category), symbols, as.character(warn_rows$detail), sep = ":"),
    collapse = ";"
  )
}

g5_wfa_validate_split_audit_for_evidence <- function(split_audit, fold_geometry) {
  if (!is.list(split_audit)) {
    g5_stop("split_audit must be the TRAIN/OOS split audit list.")
  }
  for (name in c("split_summary", "leakage_attestation")) {
    if (is.null(split_audit[[name]])) {
      g5_stop(paste("split_audit is missing", name))
    }
  }
  g5_wfa_require_columns(
    split_audit$split_summary,
    g5_wfa_required_split_summary_columns(),
    "split audit summary"
  )
  g5_wfa_require_columns(
    split_audit$leakage_attestation,
    g5_wfa_required_split_leakage_columns(),
    "split audit leakage attestation"
  )
  if (nrow(split_audit$leakage_attestation) != 1L) {
    g5_stop("split audit leakage attestation must contain exactly one row.")
  }
  if (isTRUE(as.logical(split_audit$leakage_attestation$provider_calls_used[[1L]]))) {
    g5_stop("Frozen fold evidence cannot consume split audits that used provider calls.")
  }
  if (isTRUE(as.logical(split_audit$leakage_attestation$latest_session_inferred[[1L]]))) {
    g5_stop("Frozen fold evidence cannot consume split audits that inferred latest sessions.")
  }
  if (isTRUE(as.logical(split_audit$leakage_attestation$membership_decided_from_oos_outcomes[[1L]]))) {
    g5_stop("Frozen fold evidence cannot consume OOS-informed split membership.")
  }

  summary <- split_audit$split_summary
  if (nrow(summary) != nrow(fold_geometry)) {
    g5_stop("split audit summary must contain one row per fold.")
  }
  if (!identical(as.character(summary$fold_id), as.character(fold_geometry$fold_id))) {
    g5_stop("split audit summary fold_id order must match fold_geometry.")
  }
  if (any(!as.logical(summary$train_oos_disjoint))) {
    g5_stop("Frozen fold evidence requires disjoint TRAIN/OOS split summaries.")
  }
  if (any(!as.logical(summary$oos_after_train))) {
    g5_stop("Frozen fold evidence requires OOS rows after TRAIN rows.")
  }
  if (any(!as.logical(summary$oos_bounded_by_latest_completed_session))) {
    g5_stop("Frozen fold evidence requires OOS bounds within latest_completed_session.")
  }
  if (any(as.logical(summary$outcome_columns_used_for_membership))) {
    g5_stop("Frozen fold evidence rejects outcome-column split membership.")
  }

  summary
}

g5_build_wfa_frozen_fold_evidence <- function(
  gate_result,
  fold_geometry,
  split_audit,
  accept_review_required = FALSE,
  code_metadata = NULL,
  repo_root = "."
) {
  gate_result <- g5_wfa_validate_gate_result_for_geometry(
    gate_result,
    accept_review_required = accept_review_required
  )
  fold_geometry <- g5_wfa_validate_fold_geometry_for_split(fold_geometry, gate_result)
  split_summary <- g5_wfa_validate_split_audit_for_evidence(split_audit, fold_geometry)
  code_metadata <- g5_wfa_normalize_code_metadata(code_metadata, repo_root = repo_root)

  review_required <- isTRUE(as.logical(gate_result$review_required[[1L]])) ||
    any(as.logical(fold_geometry$handoff_review_required))
  review_accepted <- if (review_required) {
    isTRUE(accept_review_required) &&
      all(as.logical(fold_geometry$handoff_review_accepted), na.rm = TRUE)
  } else {
    FALSE
  }
  if (review_required && !review_accepted) {
    g5_stop("Frozen fold evidence requires explicit acceptance for REVIEW_REQUIRED source warnings.")
  }

  warn_rows <- split_audit$source_warn_health_rows
  if (is.null(warn_rows)) {
    warn_rows <- data.frame(
      severity = character(),
      category = character(),
      symbol = character(),
      detail = character(),
      stringsAsFactors = FALSE
    )
  }
  warning_context <- g5_wfa_warning_context(warn_rows)
  warning_count <- if (nrow(warn_rows) == 0L) {
    0L
  } else {
    sum(as.character(warn_rows$severity) == "WARN")
  }

  out <- data.frame(
    evidence_id = paste0("frozen_evidence_", as.character(fold_geometry$fold_id)),
    evidence_status = "FROZEN_NO_ACTIVE_DECISION",
    fold_id = as.character(fold_geometry$fold_id),
    train_start_date = as.Date(fold_geometry$train_start_date),
    train_end_date = as.Date(fold_geometry$train_end_date),
    oos_start_date = as.Date(fold_geometry$oos_start_date),
    oos_end_date = as.Date(fold_geometry$oos_end_date),
    decision_pack_valid_from = as.Date(fold_geometry$decision_pack_valid_from),
    decision_pack_valid_through = as.Date(fold_geometry$decision_pack_valid_through),
    source_handoff_reference = as.character(fold_geometry$source_handoff_reference),
    source_gate_manifest_csv = as.character(gate_result$manifest_csv[[1L]]),
    handoff_gate_status = as.character(gate_result$gate_status[[1L]]),
    handoff_gate_detail = as.character(gate_result$detail[[1L]]),
    handoff_review_required = review_required,
    handoff_review_accepted = review_accepted,
    as_of_timestamp = as.character(gate_result$as_of_timestamp[[1L]]),
    latest_completed_session = as.Date(gate_result$latest_completed_session[[1L]]),
    train_row_count = as.integer(split_summary$train_row_count),
    train_symbol_count = as.integer(split_summary$train_symbol_count),
    train_rows_available = as.integer(split_summary$train_row_count) > 0L,
    source_warning_count = as.integer(warning_count),
    source_warning_context = warning_context,
    leakage_no_provider_calls = TRUE,
    leakage_no_latest_session_inference = TRUE,
    leakage_no_oos_membership_decisions = TRUE,
    leakage_no_oos_fitting = TRUE,
    oos_performance_evaluated = FALSE,
    active_candidate_id = NA_character_,
    feature_model_fit_status = "not_fit_no_feature_model_authorized",
    strategy_selector_fit_status = "not_fit_no_strategy_selector_authorized",
    strategy_decision_status = "no_active_strategy_decision_yet",
    baseline_decision_status = "not_registered_in_task_26",
    code_git_sha = as.character(code_metadata$code_git_sha[[1L]]),
    code_git_branch = as.character(code_metadata$code_git_branch[[1L]]),
    code_metadata_status = as.character(code_metadata$code_metadata_status[[1L]]),
    stringsAsFactors = FALSE
  )

  rownames(out) <- NULL
  out[g5_wfa_required_frozen_evidence_columns()]
}

g5_wfa_path_looks_ignored_run_path <- function(path) {
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  grepl("/runs/", normalized, fixed = TRUE) ||
    grepl("^runs/", normalized) ||
    grepl("^runs\\\\", path)
}

g5_write_wfa_frozen_fold_evidence_csv <- function(
  frozen_evidence,
  path,
  require_ignored_run_path = TRUE
) {
  g5_wfa_require_columns(
    frozen_evidence,
    g5_wfa_required_frozen_evidence_columns(),
    "frozen fold evidence"
  )
  if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
    g5_stop("frozen evidence output path must be one non-empty value.")
  }
  path <- as.character(path)
  if (isTRUE(require_ignored_run_path) && !g5_wfa_path_looks_ignored_run_path(path)) {
    g5_stop("Frozen fold evidence artifacts must be written under ignored runs/ paths.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(frozen_evidence, path, row.names = FALSE, na = "")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
