# Gen5 minimal WFA TRAIN/OOS split verifier and availability audit.

g5_wfa_required_fold_geometry_columns <- function() {
  c(
    "fold_id",
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "source_handoff_reference",
    "handoff_gate_status",
    "handoff_review_required",
    "handoff_review_accepted",
    "as_of_timestamp",
    "latest_completed_session",
    "geometry_search_policy"
  )
}

g5_wfa_required_split_summary_columns <- function() {
  c(
    "fold_id",
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "train_row_count",
    "oos_row_count",
    "train_first_session",
    "train_latest_session",
    "oos_first_session",
    "oos_latest_session",
    "train_symbol_count",
    "oos_symbol_count",
    "train_oos_disjoint",
    "oos_after_train",
    "oos_bounded_by_latest_completed_session",
    "latest_completed_session",
    "split_membership_rule",
    "outcome_columns_used_for_membership"
  )
}

g5_wfa_required_fold_symbol_availability_columns <- function() {
  c(
    "fold_id",
    "symbol",
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "train_row_count",
    "oos_row_count",
    "train_first_session",
    "train_latest_session",
    "oos_first_session",
    "oos_latest_session",
    "train_availability_status",
    "oos_availability_status",
    "fold_availability_status",
    "source_row_count",
    "source_observed_first_session",
    "source_observed_latest_session",
    "source_empty_status",
    "source_partial_history_status",
    "source_stale_status",
    "source_symbol_health_max_severity",
    "source_symbol_warning_context",
    "source_handoff_warning_context",
    "availability_rule"
  )
}

g5_wfa_validate_fold_geometry_for_split <- function(fold_geometry, gate_result) {
  if (!is.data.frame(fold_geometry)) {
    g5_stop("fold_geometry must be the explicit quarterly fold geometry data.frame.")
  }
  missing_cols <- setdiff(g5_wfa_required_fold_geometry_columns(), names(fold_geometry))
  if (length(missing_cols) > 0L) {
    g5_stop(paste(
      "fold_geometry is missing required columns:",
      paste(missing_cols, collapse = ", ")
    ))
  }
  if (nrow(fold_geometry) == 0L) {
    g5_stop("fold_geometry must contain at least one fold.")
  }
  if (any(is.na(fold_geometry$fold_id) | !nzchar(as.character(fold_geometry$fold_id)))) {
    g5_stop("fold_geometry fold_id values must be non-empty.")
  }
  if (any(duplicated(as.character(fold_geometry$fold_id)))) {
    g5_stop("fold_geometry fold_id values must be unique.")
  }

  date_cols <- c(
    "train_start_date",
    "train_end_date",
    "oos_start_date",
    "oos_end_date",
    "latest_completed_session"
  )
  for (col in date_cols) {
    fold_geometry[[col]] <- as.Date(fold_geometry[[col]])
    if (any(is.na(fold_geometry[[col]]))) {
      g5_stop(paste("fold_geometry has missing or invalid dates in", col))
    }
  }

  if (any(fold_geometry$train_start_date > fold_geometry$train_end_date)) {
    g5_stop("Every fold must have train_start_date <= train_end_date.")
  }
  if (any(fold_geometry$train_end_date >= fold_geometry$oos_start_date)) {
    g5_stop("TRAIN rows must end before OOS rows start.")
  }
  if (any(fold_geometry$oos_start_date > fold_geometry$oos_end_date)) {
    g5_stop("Every fold must have oos_start_date <= oos_end_date.")
  }
  if (any(fold_geometry$oos_end_date > fold_geometry$latest_completed_session)) {
    g5_stop("OOS rows must be bounded by latest_completed_session.")
  }

  gate_latest <- as.Date(gate_result$latest_completed_session[[1L]])
  if (any(fold_geometry$latest_completed_session != gate_latest)) {
    g5_stop("fold_geometry latest_completed_session must match the accepted handoff gate result.")
  }
  if (any(as.character(fold_geometry$as_of_timestamp) != as.character(gate_result$as_of_timestamp[[1L]]))) {
    g5_stop("fold_geometry as_of_timestamp must match the accepted handoff gate result.")
  }
  if (any(!as.character(fold_geometry$handoff_gate_status) %in% c("PASS", "REVIEW_REQUIRED"))) {
    g5_stop("fold_geometry must reference an accepted PASS or REVIEW_REQUIRED handoff gate status.")
  }
  review_rows <- isTRUE(as.logical(gate_result$review_required[[1L]])) |
    as.logical(fold_geometry$handoff_review_required)
  if (any(review_rows, na.rm = TRUE) &&
      !all(as.logical(fold_geometry$handoff_review_accepted), na.rm = TRUE)) {
    g5_stop("REVIEW_REQUIRED fold geometry must record explicit handoff_review_accepted evidence.")
  }
  if (any(as.character(fold_geometry$geometry_search_policy) !=
          "none_single_explicit_quarterly_geometry")) {
    g5_stop("TRAIN/OOS split audit requires the explicit single quarterly fold geometry.")
  }

  rownames(fold_geometry) <- NULL
  fold_geometry
}

g5_wfa_validate_source_symbol_coverage <- function(source_symbol_coverage, bars) {
  g5_wfa_require_columns(
    source_symbol_coverage,
    .g5_wfa_symbol_coverage_required_columns,
    "source symbol coverage"
  )
  if (nrow(source_symbol_coverage) == 0L) {
    g5_stop("source symbol coverage must contain at least one row.")
  }
  source_symbol_coverage$symbol <- g5_standardize_symbol(source_symbol_coverage$symbol)
  if (any(duplicated(source_symbol_coverage$symbol))) {
    g5_stop("source symbol coverage must contain one row per symbol.")
  }

  date_cols <- c(
    "requested_start_date",
    "requested_end_date",
    "coverage_end_date",
    "latest_completed_session",
    "observed_first_session",
    "observed_latest_session"
  )
  for (col in date_cols) {
    source_symbol_coverage[[col]] <- as.Date(source_symbol_coverage[[col]])
  }

  bar_symbols <- sort(unique(g5_standardize_symbol(bars$symbol)))
  missing_context <- setdiff(bar_symbols, source_symbol_coverage$symbol)
  if (length(missing_context) > 0L) {
    g5_stop(paste(
      "source symbol coverage is missing handoff bar symbols:",
      paste(missing_context, collapse = ", ")
    ))
  }

  source_symbol_coverage
}

g5_wfa_validate_source_health <- function(source_health) {
  if (is.null(source_health)) {
    return(data.frame(
      severity = character(),
      category = character(),
      symbol = character(),
      detail = character(),
      stringsAsFactors = FALSE
    ))
  }
  g5_wfa_require_columns(source_health, .g5_wfa_health_required_columns, "source health")
  invalid <- setdiff(unique(as.character(source_health$severity)), c("ERROR", "WARN", "INFO"))
  if (length(invalid) > 0L) {
    g5_stop(paste("source health has invalid severity values:", paste(invalid, collapse = ", ")))
  }
  if (any(as.character(source_health$severity) == "ERROR")) {
    g5_stop("TRAIN/OOS split audit rejects source handoffs with ERROR health rows.")
  }
  source_health$symbol <- ifelse(
    is.na(source_health$symbol),
    "",
    trimws(as.character(source_health$symbol))
  )
  has_symbol <- nzchar(source_health$symbol)
  source_health$symbol[has_symbol] <- g5_standardize_symbol(source_health$symbol[has_symbol])
  source_health
}

g5_wfa_date_or_na <- function(x, fn) {
  if (length(x) == 0L) {
    return(as.Date(NA_character_))
  }
  fn(as.Date(x))
}

g5_wfa_row_key <- function(x) {
  if (nrow(x) == 0L) {
    return(character())
  }
  paste(
    as.character(x$fold_id),
    as.character(x$symbol),
    as.character(as.Date(x$session_date)),
    sep = "|"
  )
}

g5_wfa_add_split_metadata <- function(rows, fold, split_role) {
  rows$fold_id <- as.character(fold$fold_id[[1L]])
  rows$split_role <- split_role
  rows$fold_train_start_date <- as.Date(fold$train_start_date[[1L]])
  rows$fold_train_end_date <- as.Date(fold$train_end_date[[1L]])
  rows$fold_oos_start_date <- as.Date(fold$oos_start_date[[1L]])
  rows$fold_oos_end_date <- as.Date(fold$oos_end_date[[1L]])
  rows$split_membership_rule <- "fold_dates_only_no_outcome_columns_read"
  rows
}

g5_wfa_empty_split_rows <- function(bars) {
  out <- bars[0L, , drop = FALSE]
  out$fold_id <- character()
  out$split_role <- character()
  out$fold_train_start_date <- as.Date(character())
  out$fold_train_end_date <- as.Date(character())
  out$fold_oos_start_date <- as.Date(character())
  out$fold_oos_end_date <- as.Date(character())
  out$split_membership_rule <- character()
  out
}

g5_wfa_health_max_for_rows <- function(rows) {
  if (!is.data.frame(rows) || nrow(rows) == 0L) {
    return("INFO")
  }
  g5_health_max_severity(rows)
}

g5_wfa_health_context <- function(rows) {
  if (!is.data.frame(rows) || nrow(rows) == 0L) {
    return("")
  }
  warn_rows <- rows[as.character(rows$severity) == "WARN", , drop = FALSE]
  if (nrow(warn_rows) == 0L) {
    return("")
  }
  paste(
    paste(warn_rows$category, warn_rows$detail, sep = ":"),
    collapse = ";"
  )
}

g5_wfa_window_status <- function(row_count, first_session, latest_session, start_date, end_date, role) {
  if (row_count == 0L) {
    return(paste0(tolower(role), "_no_rows"))
  }
  if (!is.na(first_session) && !is.na(latest_session) &&
      first_session <= start_date && latest_session >= end_date) {
    return(paste0(tolower(role), "_covers_window_edges"))
  }
  paste0(tolower(role), "_partial_window_edges")
}

g5_wfa_fold_symbol_availability <- function(
  bars,
  fold_geometry,
  source_symbol_coverage,
  source_health
) {
  symbols <- source_symbol_coverage$symbol
  rows <- vector("list", nrow(fold_geometry) * length(symbols))
  k <- 0L
  global_health <- source_health[!nzchar(as.character(source_health$symbol)), , drop = FALSE]

  for (i in seq_len(nrow(fold_geometry))) {
    fold <- fold_geometry[i, , drop = FALSE]
    for (symbol in symbols) {
      k <- k + 1L
      symbol_bars <- bars[g5_standardize_symbol(bars$symbol) == symbol, , drop = FALSE]
      train_rows <- symbol_bars[
        as.Date(symbol_bars$session_date) >= fold$train_start_date[[1L]] &
          as.Date(symbol_bars$session_date) <= fold$train_end_date[[1L]],
        ,
        drop = FALSE
      ]
      oos_rows <- symbol_bars[
        as.Date(symbol_bars$session_date) >= fold$oos_start_date[[1L]] &
          as.Date(symbol_bars$session_date) <= fold$oos_end_date[[1L]],
        ,
        drop = FALSE
      ]
      coverage <- source_symbol_coverage[
        source_symbol_coverage$symbol == symbol,
        ,
        drop = FALSE
      ]
      symbol_health <- source_health[
        as.character(source_health$symbol) == symbol,
        ,
        drop = FALSE
      ]

      train_first <- g5_wfa_date_or_na(train_rows$session_date, min)
      train_latest <- g5_wfa_date_or_na(train_rows$session_date, max)
      oos_first <- g5_wfa_date_or_na(oos_rows$session_date, min)
      oos_latest <- g5_wfa_date_or_na(oos_rows$session_date, max)
      train_status <- g5_wfa_window_status(
        nrow(train_rows),
        train_first,
        train_latest,
        fold$train_start_date[[1L]],
        fold$train_end_date[[1L]],
        "TRAIN"
      )
      oos_status <- g5_wfa_window_status(
        nrow(oos_rows),
        oos_first,
        oos_latest,
        fold$oos_start_date[[1L]],
        fold$oos_end_date[[1L]],
        "OOS"
      )
      fold_status <- if (nrow(train_rows) == 0L && nrow(oos_rows) == 0L) {
        "no_fold_rows_recorded"
      } else if (nrow(train_rows) == 0L) {
        "oos_rows_without_train_rows_recorded"
      } else if (nrow(oos_rows) == 0L) {
        "train_rows_without_oos_rows_recorded"
      } else {
        "train_and_oos_rows_recorded"
      }

      rows[[k]] <- data.frame(
        fold_id = as.character(fold$fold_id[[1L]]),
        symbol = symbol,
        train_start_date = fold$train_start_date[[1L]],
        train_end_date = fold$train_end_date[[1L]],
        oos_start_date = fold$oos_start_date[[1L]],
        oos_end_date = fold$oos_end_date[[1L]],
        train_row_count = nrow(train_rows),
        oos_row_count = nrow(oos_rows),
        train_first_session = train_first,
        train_latest_session = train_latest,
        oos_first_session = oos_first,
        oos_latest_session = oos_latest,
        train_availability_status = train_status,
        oos_availability_status = oos_status,
        fold_availability_status = fold_status,
        source_row_count = as.integer(coverage$row_count[[1L]]),
        source_observed_first_session = coverage$observed_first_session[[1L]],
        source_observed_latest_session = coverage$observed_latest_session[[1L]],
        source_empty_status = as.character(coverage$empty_status[[1L]]),
        source_partial_history_status = as.character(coverage$partial_history_status[[1L]]),
        source_stale_status = as.character(coverage$stale_status[[1L]]),
        source_symbol_health_max_severity = g5_wfa_health_max_for_rows(symbol_health),
        source_symbol_warning_context = g5_wfa_health_context(symbol_health),
        source_handoff_warning_context = g5_wfa_health_context(global_health),
        availability_rule = "fold_dates_and_source_handoff_health_only_no_oos_performance_filter",
        stringsAsFactors = FALSE
      )
    }
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[g5_wfa_required_fold_symbol_availability_columns()]
}

g5_build_wfa_train_oos_split_audit <- function(
  gate_result,
  bars,
  fold_geometry,
  source_symbol_coverage,
  source_health = NULL,
  accept_review_required = FALSE
) {
  gate_result <- g5_wfa_validate_gate_result_for_geometry(
    gate_result,
    accept_review_required = accept_review_required
  )
  fold_geometry <- g5_wfa_validate_fold_geometry_for_split(fold_geometry, gate_result)
  bars <- g5_validate_bar_data(bars)
  if (!all(as.logical(bars$adjusted))) {
    g5_stop("canonical handoff bars must have adjusted == TRUE.")
  }
  if (!all(as.character(bars$timeframe) == "1D")) {
    g5_stop("canonical handoff bars must have timeframe == '1D'.")
  }
  if (!all(as.character(bars$provider) == "alpaca")) {
    g5_stop("canonical handoff bars must have provider == 'alpaca'.")
  }
  if (any(as.character(bars$as_of_timestamp) != as.character(gate_result$as_of_timestamp[[1L]]))) {
    g5_stop("canonical handoff bars as_of_timestamp must match the accepted gate result.")
  }
  if (any(as.Date(bars$latest_completed_session) !=
          as.Date(gate_result$latest_completed_session[[1L]]))) {
    g5_stop("canonical handoff bars latest_completed_session must match the accepted gate result.")
  }

  source_symbol_coverage <- g5_wfa_validate_source_symbol_coverage(source_symbol_coverage, bars)
  source_health <- g5_wfa_validate_source_health(source_health)

  train_parts <- vector("list", nrow(fold_geometry))
  oos_parts <- vector("list", nrow(fold_geometry))
  summary_rows <- vector("list", nrow(fold_geometry))

  for (i in seq_len(nrow(fold_geometry))) {
    fold <- fold_geometry[i, , drop = FALSE]
    train_rows <- bars[
      as.Date(bars$session_date) >= fold$train_start_date[[1L]] &
        as.Date(bars$session_date) <= fold$train_end_date[[1L]],
      ,
      drop = FALSE
    ]
    oos_rows <- bars[
      as.Date(bars$session_date) >= fold$oos_start_date[[1L]] &
        as.Date(bars$session_date) <= fold$oos_end_date[[1L]],
      ,
      drop = FALSE
    ]

    train_rows <- g5_wfa_add_split_metadata(train_rows, fold, "TRAIN")
    oos_rows <- g5_wfa_add_split_metadata(oos_rows, fold, "OOS")

    train_keys <- g5_wfa_row_key(train_rows)
    oos_keys <- g5_wfa_row_key(oos_rows)
    train_oos_disjoint <- length(intersect(train_keys, oos_keys)) == 0L
    train_latest <- g5_wfa_date_or_na(train_rows$session_date, max)
    oos_first <- g5_wfa_date_or_na(oos_rows$session_date, min)
    oos_latest <- g5_wfa_date_or_na(oos_rows$session_date, max)
    oos_after_train <- if (nrow(train_rows) == 0L || nrow(oos_rows) == 0L) {
      TRUE
    } else {
      oos_first > train_latest
    }
    oos_bounded <- nrow(oos_rows) == 0L ||
      all(as.Date(oos_rows$session_date) <= as.Date(fold$latest_completed_session[[1L]]))

    if (!train_oos_disjoint) {
      g5_stop(paste("TRAIN and OOS rows overlap for fold", fold$fold_id[[1L]]))
    }
    if (!oos_after_train) {
      g5_stop(paste("OOS rows must occur strictly after TRAIN rows for fold", fold$fold_id[[1L]]))
    }
    if (!oos_bounded) {
      g5_stop(paste("OOS rows exceed latest_completed_session for fold", fold$fold_id[[1L]]))
    }

    train_parts[[i]] <- train_rows
    oos_parts[[i]] <- oos_rows
    summary_rows[[i]] <- data.frame(
      fold_id = as.character(fold$fold_id[[1L]]),
      train_start_date = fold$train_start_date[[1L]],
      train_end_date = fold$train_end_date[[1L]],
      oos_start_date = fold$oos_start_date[[1L]],
      oos_end_date = fold$oos_end_date[[1L]],
      train_row_count = nrow(train_rows),
      oos_row_count = nrow(oos_rows),
      train_first_session = g5_wfa_date_or_na(train_rows$session_date, min),
      train_latest_session = train_latest,
      oos_first_session = oos_first,
      oos_latest_session = oos_latest,
      train_symbol_count = length(unique(as.character(train_rows$symbol))),
      oos_symbol_count = length(unique(as.character(oos_rows$symbol))),
      train_oos_disjoint = train_oos_disjoint,
      oos_after_train = oos_after_train,
      oos_bounded_by_latest_completed_session = oos_bounded,
      latest_completed_session = as.Date(fold$latest_completed_session[[1L]]),
      split_membership_rule = "fold_dates_only_no_outcome_columns_read",
      outcome_columns_used_for_membership = FALSE,
      stringsAsFactors = FALSE
    )
  }

  train_rows <- if (length(train_parts) == 0L) {
    g5_wfa_empty_split_rows(bars)
  } else {
    do.call(rbind, train_parts)
  }
  oos_rows <- if (length(oos_parts) == 0L) {
    g5_wfa_empty_split_rows(bars)
  } else {
    do.call(rbind, oos_parts)
  }
  split_summary <- do.call(rbind, summary_rows)
  rownames(train_rows) <- NULL
  rownames(oos_rows) <- NULL
  rownames(split_summary) <- NULL

  symbol_availability <- g5_wfa_fold_symbol_availability(
    bars = bars,
    fold_geometry = fold_geometry,
    source_symbol_coverage = source_symbol_coverage,
    source_health = source_health
  )

  list(
    train_rows = train_rows,
    oos_rows = oos_rows,
    split_summary = split_summary[g5_wfa_required_split_summary_columns()],
    symbol_availability = symbol_availability,
    source_warn_health_rows = source_health[
      as.character(source_health$severity) == "WARN",
      ,
      drop = FALSE
    ],
    leakage_attestation = data.frame(
      provider_calls_used = FALSE,
      latest_session_inferred = FALSE,
      membership_decided_from_oos_outcomes = FALSE,
      split_membership_rule = "fold_dates_only_no_outcome_columns_read",
      stringsAsFactors = FALSE
    )
  )
}
