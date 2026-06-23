# Gen5 minimal WFA handoff reader and gate.

.g5_wfa_manifest_required_columns <- c(
  "wrapper",
  "as_of_timestamp",
  "latest_completed_session",
  "resolution_reason",
  "requested_start_date",
  "requested_end_date",
  "fetch_start_date",
  "fetch_end_date",
  "universe_name",
  "universe_roles",
  "requested_symbols",
  "returned_symbols",
  "cache_root",
  "provider",
  "feed",
  "refresh",
  "git_sha",
  "health_max_severity",
  "bars_csv",
  "audit_csv",
  "symbol_coverage_csv",
  "health_csv",
  "refresh_plan_csv"
)

.g5_wfa_health_required_columns <- c("severity", "category", "symbol", "detail")

.g5_wfa_symbol_coverage_required_columns <- c(
  "symbol",
  "requested_start_date",
  "requested_end_date",
  "coverage_end_date",
  "latest_completed_session",
  "observed_first_session",
  "observed_latest_session",
  "row_count",
  "is_empty",
  "empty_status",
  "is_partial_history",
  "partial_history_status",
  "is_stale",
  "stale_status"
)

.g5_wfa_refresh_plan_required_columns <- c(
  "symbol",
  "cache_path",
  "cache_file_exists",
  "cached_row_count",
  "first_cached_session",
  "latest_cached_session",
  "requested_start_date",
  "requested_end_date",
  "needs_fetch",
  "refresh_decision",
  "fetch_start_date",
  "fetch_end_date"
)

.g5_wfa_merge_summary_required_columns <- c(
  "symbol",
  "cache_path",
  "refresh_decision",
  "needs_fetch",
  "returned_bar_count",
  "merged_row_count",
  "first_merged_session",
  "latest_merged_session",
  "no_returned_bars",
  "wrote_cache"
)

g5_wfa_required_manifest_columns <- function() {
  .g5_wfa_manifest_required_columns
}

g5_wfa_handoff_gate_result <- function(
  gate_status,
  manifest_csv,
  as_of_timestamp,
  latest_completed_session,
  health_max_severity,
  warn_row_count,
  review_required,
  detail
) {
  data.frame(
    gate_status = gate_status,
    manifest_csv = normalizePath(manifest_csv, winslash = "/", mustWork = FALSE),
    as_of_timestamp = as.character(as_of_timestamp),
    latest_completed_session = as.Date(latest_completed_session),
    health_max_severity = as.character(health_max_severity),
    warn_row_count = as.integer(warn_row_count),
    review_required = as.logical(review_required),
    detail = as.character(detail),
    stringsAsFactors = FALSE
  )
}

g5_wfa_read_csv_artifact <- function(path, label) {
  if (length(path) != 1L || is.na(path) || !nzchar(as.character(path))) {
    g5_stop(paste(label, "path must be a non-empty manifest-linked path."))
  }
  path <- as.character(path)
  if (!file.exists(path)) {
    g5_stop(paste("Missing required handoff artifact:", label, "-", path))
  }
  tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) {
      g5_stop(paste("Failed to read handoff artifact:", label, "-", path, "-", conditionMessage(e)))
    }
  )
}

g5_wfa_require_columns <- function(x, required, label) {
  if (!is.data.frame(x)) {
    g5_stop(paste(label, "must be a data.frame."))
  }
  missing <- setdiff(required, names(x))
  if (length(missing) > 0L) {
    g5_stop(paste(label, "is missing required columns:", paste(missing, collapse = ", ")))
  }
  invisible(TRUE)
}

g5_wfa_require_one_manifest_row <- function(manifest) {
  g5_wfa_require_columns(manifest, g5_wfa_required_manifest_columns(), "workbench manifest")
  if (nrow(manifest) != 1L) {
    g5_stop("workbench manifest must contain exactly one handoff row.")
  }
  manifest <- manifest[1L, , drop = FALSE]

  if (!nzchar(as.character(manifest$as_of_timestamp[[1L]]))) {
    g5_stop("workbench manifest must include an explicit as_of_timestamp.")
  }
  manifest$latest_completed_session <- as.Date(manifest$latest_completed_session)
  if (is.na(manifest$latest_completed_session[[1L]])) {
    g5_stop("workbench manifest latest_completed_session must be a valid date.")
  }
  if (!identical(as.character(manifest$provider[[1L]]), "alpaca")) {
    g5_stop("WFA handoff gate requires provider == 'alpaca'.")
  }
  if (identical(as.character(manifest$health_max_severity[[1L]]), "ERROR")) {
    g5_stop("WFA handoff gate rejects health_max_severity == 'ERROR'.")
  }
  if (!as.character(manifest$health_max_severity[[1L]]) %in% c("INFO", "WARN")) {
    g5_stop("workbench manifest health_max_severity must be INFO or WARN.")
  }

  manifest
}

g5_wfa_check_artifact_dates <- function(
  manifest,
  bars,
  audit,
  symbol_coverage,
  refresh_plan
) {
  as_of_timestamp <- as.character(manifest$as_of_timestamp[[1L]])
  latest_completed_session <- as.Date(manifest$latest_completed_session[[1L]])

  if (nrow(bars) > 0L) {
    if (any(as.character(bars$as_of_timestamp) != as_of_timestamp, na.rm = TRUE)) {
      g5_stop("bars as_of_timestamp does not match the workbench manifest.")
    }
    if (any(as.Date(bars$latest_completed_session) != latest_completed_session, na.rm = TRUE)) {
      g5_stop("bars latest_completed_session does not match the workbench manifest.")
    }
    if (any(as.Date(bars$session_date) > latest_completed_session, na.rm = TRUE)) {
      g5_stop("bars include rows after manifest latest_completed_session.")
    }
  }

  if (nrow(audit) > 0L) {
    audit_latest <- as.Date(audit$latest_completed_session)
    if (any(audit_latest != latest_completed_session, na.rm = TRUE)) {
      g5_stop("audit latest_completed_session does not match the workbench manifest.")
    }
    if (any(!nzchar(as.character(audit$provider_query_timestamp)))) {
      g5_stop("audit provider_query_timestamp must preserve the manifest as_of_timestamp.")
    }
    if (any(as.character(audit$provider_query_timestamp) != as_of_timestamp, na.rm = TRUE)) {
      g5_stop("audit provider_query_timestamp does not match the workbench manifest as_of_timestamp.")
    }
  }

  if (nrow(symbol_coverage) > 0L) {
    coverage_latest <- as.Date(symbol_coverage$latest_completed_session)
    if (any(coverage_latest != latest_completed_session, na.rm = TRUE)) {
      g5_stop("symbol coverage latest_completed_session does not match the workbench manifest.")
    }
    coverage_end <- as.Date(symbol_coverage$coverage_end_date)
    observed_latest <- as.Date(symbol_coverage$observed_latest_session)
    if (any(coverage_end > latest_completed_session, na.rm = TRUE)) {
      g5_stop("symbol coverage includes coverage_end_date after latest_completed_session.")
    }
    if (any(observed_latest > latest_completed_session, na.rm = TRUE)) {
      g5_stop("symbol coverage includes observed_latest_session after latest_completed_session.")
    }
  }

  if (nrow(refresh_plan) > 0L) {
    requested_end <- as.Date(refresh_plan$requested_end_date)
    fetch_end <- as.Date(refresh_plan$fetch_end_date)
    if (any(requested_end > latest_completed_session, na.rm = TRUE)) {
      g5_stop("refresh plan requested_end_date occurs after latest_completed_session.")
    }
    if (any(fetch_end > latest_completed_session, na.rm = TRUE)) {
      g5_stop("refresh plan fetch_end_date occurs after latest_completed_session.")
    }
  }

  invisible(TRUE)
}

g5_read_wfa_handoff <- function(manifest_csv) {
  manifest <- g5_wfa_read_csv_artifact(manifest_csv, "workbench manifest")
  manifest <- g5_wfa_require_one_manifest_row(manifest)

  bars <- g5_wfa_read_csv_artifact(manifest$bars_csv[[1L]], "canonical bars")
  bars <- g5_validate_bar_data(bars)
  if (!all(as.logical(bars$adjusted))) {
    g5_stop("canonical bars must have adjusted == TRUE.")
  }
  if (!all(as.character(bars$timeframe) == "1D")) {
    g5_stop("canonical bars must have timeframe == '1D'.")
  }
  if (!all(as.character(bars$provider) == "alpaca")) {
    g5_stop("canonical bars must have provider == 'alpaca'.")
  }

  audit <- g5_wfa_read_csv_artifact(manifest$audit_csv[[1L]], "audit")
  g5_wfa_require_columns(audit, g5_required_audit_columns(), "audit")
  if (nrow(audit) == 0L) {
    g5_stop("audit artifact must contain at least one row.")
  }
  if (any(as.integer(audit$duplicate_symbol_session_count) > 0L, na.rm = TRUE)) {
    g5_stop("audit reports duplicate symbol/session_date rows.")
  }

  symbol_coverage <- g5_wfa_read_csv_artifact(manifest$symbol_coverage_csv[[1L]], "symbol coverage")
  g5_wfa_require_columns(symbol_coverage, .g5_wfa_symbol_coverage_required_columns, "symbol coverage")
  if (nrow(symbol_coverage) == 0L) {
    g5_stop("symbol coverage artifact must contain at least one row.")
  }

  health <- g5_wfa_read_csv_artifact(manifest$health_csv[[1L]], "health")
  g5_wfa_require_columns(health, .g5_wfa_health_required_columns, "health")
  if (nrow(health) == 0L) {
    g5_stop("health artifact must contain at least one row.")
  }
  invalid_severities <- setdiff(unique(as.character(health$severity)), c("ERROR", "WARN", "INFO"))
  if (length(invalid_severities) > 0L) {
    g5_stop(paste("health artifact has invalid severity values:", paste(invalid_severities, collapse = ", ")))
  }
  health_max <- g5_health_max_severity(health)
  if (identical(health_max, "ERROR")) {
    g5_stop("WFA handoff gate rejects ERROR health rows.")
  }
  if (!identical(health_max, as.character(manifest$health_max_severity[[1L]]))) {
    g5_stop("manifest health_max_severity does not match the health artifact.")
  }

  refresh_plan <- g5_wfa_read_csv_artifact(manifest$refresh_plan_csv[[1L]], "refresh plan")
  g5_wfa_require_columns(refresh_plan, .g5_wfa_refresh_plan_required_columns, "refresh plan")
  if (nrow(refresh_plan) == 0L) {
    g5_stop("refresh plan artifact must contain at least one row.")
  }

  merge_summary <- data.frame()
  if ("merge_summary_csv" %in% names(manifest) &&
      !is.na(manifest$merge_summary_csv[[1L]]) &&
      nzchar(as.character(manifest$merge_summary_csv[[1L]]))) {
    merge_summary <- g5_wfa_read_csv_artifact(manifest$merge_summary_csv[[1L]], "merge summary")
    g5_wfa_require_columns(merge_summary, .g5_wfa_merge_summary_required_columns, "merge summary")
  }

  g5_wfa_check_artifact_dates(
    manifest = manifest,
    bars = bars,
    audit = audit,
    symbol_coverage = symbol_coverage,
    refresh_plan = refresh_plan
  )

  warn_rows <- health[as.character(health$severity) == "WARN", , drop = FALSE]
  review_required <- nrow(warn_rows) > 0L
  gate_status <- if (review_required) "REVIEW_REQUIRED" else "PASS"
  detail <- if (review_required) {
    paste("WARN health rows require operator review:", nrow(warn_rows))
  } else {
    "handoff passed WFA gate"
  }

  gate_result <- g5_wfa_handoff_gate_result(
    gate_status = gate_status,
    manifest_csv = manifest_csv,
    as_of_timestamp = manifest$as_of_timestamp[[1L]],
    latest_completed_session = manifest$latest_completed_session[[1L]],
    health_max_severity = health_max,
    warn_row_count = nrow(warn_rows),
    review_required = review_required,
    detail = detail
  )

  list(
    manifest = manifest,
    bars = bars,
    audit = audit,
    symbol_coverage = symbol_coverage,
    health = health,
    refresh_plan = refresh_plan,
    merge_summary = merge_summary,
    warn_health_rows = warn_rows,
    gate_result = gate_result
  )
}
