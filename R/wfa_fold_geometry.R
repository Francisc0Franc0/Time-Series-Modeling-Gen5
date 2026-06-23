# Gen5 minimal WFA quarterly fold geometry builder.

g5_wfa_required_gate_result_columns <- function() {
  c(
    "gate_status",
    "manifest_csv",
    "as_of_timestamp",
    "latest_completed_session",
    "health_max_severity",
    "warn_row_count",
    "review_required",
    "detail"
  )
}

g5_wfa_as_date_scalar <- function(x, label) {
  if (length(x) != 1L || is.na(x)) {
    g5_stop(paste(label, "must be one explicit date."))
  }
  value <- as.Date(x)
  if (is.na(value)) {
    g5_stop(paste(label, "must be a valid date."))
  }
  value
}

g5_wfa_quarter_number <- function(date) {
  month <- as.integer(format(as.Date(date), "%m"))
  ((month - 1L) %/% 3L) + 1L
}

g5_wfa_is_quarter_start <- function(date) {
  date <- as.Date(date)
  as.integer(format(date, "%d")) == 1L &&
    as.integer(format(date, "%m")) %in% c(1L, 4L, 7L, 10L)
}

g5_wfa_quarter_start_index <- function(date) {
  date <- as.Date(date)
  year <- as.integer(format(date, "%Y"))
  (year * 4L) + g5_wfa_quarter_number(date)
}

g5_wfa_quarter_start_from_index <- function(index) {
  year <- (index - 1L) %/% 4L
  quarter <- ((index - 1L) %% 4L) + 1L
  month <- c(1L, 4L, 7L, 10L)[quarter]
  as.Date(sprintf("%04d-%02d-01", year, month))
}

g5_wfa_quarter_end_from_start <- function(quarter_start) {
  next_start <- g5_wfa_quarter_start_from_index(
    g5_wfa_quarter_start_index(quarter_start) + 1L
  )
  next_start - 1L
}

g5_wfa_validate_gate_result_for_geometry <- function(
  gate_result,
  accept_review_required = FALSE
) {
  if (!is.data.frame(gate_result)) {
    g5_stop("gate_result must be the WFA handoff gate result data.frame.")
  }
  missing_cols <- setdiff(g5_wfa_required_gate_result_columns(), names(gate_result))
  if (length(missing_cols) > 0L) {
    g5_stop(paste(
      "WFA handoff gate result is missing required columns:",
      paste(missing_cols, collapse = ", ")
    ))
  }
  if (nrow(gate_result) != 1L) {
    g5_stop("WFA handoff gate result must contain exactly one row.")
  }

  gate_status <- as.character(gate_result$gate_status[[1L]])
  if (!gate_status %in% c("PASS", "REVIEW_REQUIRED")) {
    g5_stop("Quarterly fold geometry requires an accepted PASS or REVIEW_REQUIRED handoff gate result.")
  }
  review_required <- isTRUE(as.logical(gate_result$review_required[[1L]]))
  if (review_required && !isTRUE(accept_review_required)) {
    g5_stop("REVIEW_REQUIRED handoff gate result needs explicit accept_review_required = TRUE.")
  }
  if (!nzchar(as.character(gate_result$as_of_timestamp[[1L]]))) {
    g5_stop("WFA handoff gate result must carry an explicit as_of_timestamp.")
  }
  gate_result$latest_completed_session <- g5_wfa_as_date_scalar(
    gate_result$latest_completed_session[[1L]],
    "latest_completed_session"
  )
  gate_result
}

g5_build_quarterly_fold_geometry <- function(
  gate_result,
  train_start_date,
  first_oos_start_date,
  final_oos_end_date,
  gap_days = 0L,
  accept_review_required = FALSE,
  source_handoff_reference = NULL
) {
  gate_result <- g5_wfa_validate_gate_result_for_geometry(
    gate_result,
    accept_review_required = accept_review_required
  )

  train_start_date <- g5_wfa_as_date_scalar(train_start_date, "train_start_date")
  first_oos_start_date <- g5_wfa_as_date_scalar(first_oos_start_date, "first_oos_start_date")
  final_oos_end_date <- g5_wfa_as_date_scalar(final_oos_end_date, "final_oos_end_date")
  latest_completed_session <- g5_wfa_as_date_scalar(
    gate_result$latest_completed_session[[1L]],
    "latest_completed_session"
  )

  if (!g5_wfa_is_quarter_start(first_oos_start_date)) {
    g5_stop("first_oos_start_date must be the first day of a calendar quarter.")
  }
  if (final_oos_end_date < first_oos_start_date) {
    g5_stop("final_oos_end_date must be on or after first_oos_start_date.")
  }
  if (final_oos_end_date > latest_completed_session) {
    g5_stop("final_oos_end_date must be bounded by latest_completed_session.")
  }

  gap_days <- as.integer(gap_days)
  if (length(gap_days) != 1L || is.na(gap_days) || gap_days < 0L) {
    g5_stop("gap_days must be one non-negative integer.")
  }

  first_train_end <- first_oos_start_date - gap_days - 1L
  if (train_start_date > first_train_end) {
    g5_stop("train_start_date must allow a valid TRAIN window before the first OOS window.")
  }

  if (is.null(source_handoff_reference)) {
    source_handoff_reference <- as.character(gate_result$manifest_csv[[1L]])
  }
  if (length(source_handoff_reference) != 1L ||
      is.na(source_handoff_reference) ||
      !nzchar(as.character(source_handoff_reference))) {
    g5_stop("source_handoff_reference must be one non-empty value.")
  }
  source_handoff_reference <- as.character(source_handoff_reference)

  start_index <- g5_wfa_quarter_start_index(first_oos_start_date)
  final_index <- g5_wfa_quarter_start_index(final_oos_end_date)
  quarter_indices <- seq.int(start_index, final_index)
  oos_start_dates <- as.Date(vapply(
    quarter_indices,
    g5_wfa_quarter_start_from_index,
    FUN.VALUE = as.Date("1970-01-01")
  ), origin = "1970-01-01")
  oos_end_dates <- pmin(
    as.Date(vapply(
      oos_start_dates,
      g5_wfa_quarter_end_from_start,
      FUN.VALUE = as.Date("1970-01-01")
    ), origin = "1970-01-01"),
    final_oos_end_date
  )

  train_end_dates <- oos_start_dates - gap_days - 1L
  invalid_train <- train_start_date > train_end_dates
  if (any(invalid_train)) {
    g5_stop("Every fold must have train_start_date <= train_end_date.")
  }
  if (any(train_end_dates >= oos_start_dates)) {
    g5_stop("TRAIN windows must end before OOS windows start.")
  }
  if (any(oos_end_dates < oos_start_dates)) {
    g5_stop("Every fold must have oos_start_date <= oos_end_date.")
  }
  if (any(oos_end_dates > latest_completed_session)) {
    g5_stop("OOS windows must be bounded by latest_completed_session.")
  }

  gap_start_dates <- rep(as.Date(NA_character_), length(oos_start_dates))
  gap_end_dates <- rep(as.Date(NA_character_), length(oos_start_dates))
  if (gap_days > 0L) {
    gap_start_dates <- train_end_dates + 1L
    gap_end_dates <- oos_start_dates - 1L
  }
  gap_policy <- if (gap_days == 0L) {
    "no_gap_train_ends_day_before_oos"
  } else {
    paste0("intentional_", gap_days, "_calendar_day_gap_between_train_and_oos")
  }

  data.frame(
    fold_id = sprintf("fold_%04d", seq_along(oos_start_dates)),
    train_start_date = train_start_date,
    train_end_date = train_end_dates,
    oos_start_date = oos_start_dates,
    oos_end_date = oos_end_dates,
    decision_cadence = "quarterly",
    decision_pack_valid_from = oos_start_dates,
    decision_pack_valid_through = oos_end_dates,
    train_window_rule = paste0("expanding_from_", format(train_start_date, "%Y-%m-%d")),
    oos_window_rule = "calendar_quarter_capped_by_explicit_final_oos_end_date",
    intentional_gap_days = gap_days,
    gap_policy = gap_policy,
    gap_start_date = gap_start_dates,
    gap_end_date = gap_end_dates,
    source_handoff_reference = source_handoff_reference,
    handoff_gate_status = as.character(gate_result$gate_status[[1L]]),
    handoff_review_required = as.logical(gate_result$review_required[[1L]]),
    handoff_review_accepted = isTRUE(as.logical(gate_result$review_required[[1L]])) &&
      isTRUE(accept_review_required),
    as_of_timestamp = as.character(gate_result$as_of_timestamp[[1L]]),
    latest_completed_session = latest_completed_session,
    geometry_search_policy = "none_single_explicit_quarterly_geometry",
    stringsAsFactors = FALSE
  )
}
