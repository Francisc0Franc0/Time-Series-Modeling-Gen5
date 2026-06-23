# Data-quality audit helpers.

g5_audit_bars <- function(
  bars,
  requested_symbols,
  latest_completed_session,
  requested_start_date = NULL,
  requested_end_date = NULL,
  provider_query_timestamp = NA_character_,
  cache_hits = character(),
  cache_misses = character(),
  availability_warnings = character(),
  cache_refresh_plan = NULL,
  cache_refresh_result = NULL
) {
  if (!is.data.frame(bars)) {
    g5_stop("bars must be a data.frame.")
  }

  requested_symbols <- g5_standardize_symbol(requested_symbols)
  cache_hits <- if (length(cache_hits) == 0L) character() else g5_standardize_symbol(cache_hits)
  cache_misses <- if (length(cache_misses) == 0L) character() else g5_standardize_symbol(cache_misses)
  present_symbols <- if ("symbol" %in% names(bars)) unique(g5_standardize_symbol(bars$symbol)) else character()
  missing_symbols <- setdiff(requested_symbols, present_symbols)
  empty_symbols <- missing_symbols
  latest_completed_session <- as.Date(latest_completed_session)

  if (is.null(requested_start_date) && "fetch_start_date" %in% names(bars) && nrow(bars) > 0L) {
    requested_start_date <- min(as.Date(bars$fetch_start_date), na.rm = TRUE)
  }
  if (is.null(requested_end_date) && "fetch_end_date" %in% names(bars) && nrow(bars) > 0L) {
    requested_end_date <- max(as.Date(bars$fetch_end_date), na.rm = TRUE)
  }
  requested_start_date <- if (is.null(requested_start_date)) {
    as.Date(NA_character_)
  } else {
    as.Date(requested_start_date)[1L]
  }
  requested_end_date <- if (is.null(requested_end_date)) {
    as.Date(NA_character_)
  } else {
    as.Date(requested_end_date)[1L]
  }
  if (is.na(requested_start_date) && nrow(bars) > 0L) {
    requested_start_date <- min(as.Date(bars$fetch_start_date), na.rm = TRUE)
  }
  if (is.na(requested_end_date) && nrow(bars) > 0L) {
    requested_end_date <- max(as.Date(bars$fetch_end_date), na.rm = TRUE)
  }

  duplicate_count <- NA_integer_
  if (all(c("symbol", "session_date") %in% names(bars))) {
    key <- paste(g5_standardize_symbol(bars$symbol), as.Date(bars$session_date))
    duplicate_count <- sum(duplicated(key))
  }

  first_by_symbol <- if (all(c("symbol", "session_date") %in% names(bars)) && nrow(bars) > 0L) {
    aggregate(as.Date(bars$session_date), list(symbol = g5_standardize_symbol(bars$symbol)), min)
  } else {
    data.frame(symbol = character(), x = as.Date(character()))
  }
  names(first_by_symbol) <- c("symbol", "first_available_session")

  latest_by_symbol <- if (all(c("symbol", "session_date") %in% names(bars)) && nrow(bars) > 0L) {
    aggregate(as.Date(bars$session_date), list(symbol = g5_standardize_symbol(bars$symbol)), max)
  } else {
    data.frame(symbol = character(), x = as.Date(character()))
  }
  names(latest_by_symbol) <- c("symbol", "latest_cached_session")

  stale_symbols <- latest_by_symbol$symbol[latest_by_symbol$latest_cached_session < latest_completed_session]

  availability <- merge(first_by_symbol, latest_by_symbol, by = "symbol", all = TRUE)
  expected_end_date <- if (is.na(requested_end_date)) {
    latest_completed_session
  } else {
    min(requested_end_date, latest_completed_session)
  }
  partial_history_symbols <- character()
  if (nrow(availability) > 0L && !is.na(requested_start_date) && !is.na(expected_end_date)) {
    partial_rows <- availability$first_available_session > requested_start_date |
      availability$latest_cached_session < expected_end_date
    partial_history_symbols <- availability$symbol[partial_rows]
  }

  observed_start_date <- if (nrow(first_by_symbol) > 0L) {
    min(first_by_symbol$first_available_session)
  } else {
    as.Date(NA_character_)
  }
  observed_end_date <- if (nrow(latest_by_symbol) > 0L) {
    max(latest_by_symbol$latest_cached_session)
  } else {
    as.Date(NA_character_)
  }

  symbol_date_summary <- function(symbols, summary_frame, date_col) {
    if (length(symbols) == 0L) {
      return("")
    }
    values <- rep(NA_character_, length(symbols))
    names(values) <- symbols
    if (nrow(summary_frame) > 0L) {
      idx <- match(summary_frame$symbol, symbols)
      values[idx[!is.na(idx)]] <- as.character(summary_frame[[date_col]][!is.na(idx)])
    }
    paste(paste(names(values), ifelse(is.na(values), "NA", values), sep = "="), collapse = ";")
  }

  symbol_text_summary <- function(symbols, summary_frame, value_col) {
    if (length(symbols) == 0L) {
      return("")
    }
    values <- rep(NA_character_, length(symbols))
    names(values) <- symbols
    if (is.data.frame(summary_frame) && nrow(summary_frame) > 0L && value_col %in% names(summary_frame)) {
      idx <- match(g5_standardize_symbol(summary_frame$symbol), symbols)
      values[idx[!is.na(idx)]] <- as.character(summary_frame[[value_col]][!is.na(idx)])
    }
    paste(paste(names(values), ifelse(is.na(values), "NA", values), sep = "="), collapse = ";")
  }

  cache_refresh_plan <- if (is.null(cache_refresh_plan)) {
    data.frame()
  } else {
    cache_refresh_plan
  }
  cache_refresh_result <- if (is.null(cache_refresh_result)) {
    data.frame()
  } else {
    cache_refresh_result
  }
  if (is.data.frame(cache_refresh_plan) && nrow(cache_refresh_plan) > 0L && "symbol" %in% names(cache_refresh_plan)) {
    cache_refresh_plan$symbol <- g5_standardize_symbol(cache_refresh_plan$symbol)
  }
  if (is.data.frame(cache_refresh_result) && nrow(cache_refresh_result) > 0L && "symbol" %in% names(cache_refresh_result)) {
    cache_refresh_result$symbol <- g5_standardize_symbol(cache_refresh_result$symbol)
  }

  planned_fetch_symbols <- character()
  skipped_fetch_symbols <- character()
  refresh_decisions_by_symbol <- ""
  refresh_fetch_ranges_by_symbol <- ""
  if (is.data.frame(cache_refresh_plan) && nrow(cache_refresh_plan) > 0L) {
    needs_fetch <- if ("needs_fetch" %in% names(cache_refresh_plan)) {
      as.logical(cache_refresh_plan$needs_fetch)
    } else {
      rep(FALSE, nrow(cache_refresh_plan))
    }
    planned_fetch_symbols <- cache_refresh_plan$symbol[needs_fetch]
    skipped_fetch_symbols <- cache_refresh_plan$symbol[!needs_fetch]
    refresh_decisions_by_symbol <- symbol_text_summary(requested_symbols, cache_refresh_plan, "refresh_decision")

    range_values <- rep(NA_character_, nrow(cache_refresh_plan))
    if (all(c("fetch_start_date", "fetch_end_date") %in% names(cache_refresh_plan))) {
      has_range <- !is.na(as.Date(cache_refresh_plan$fetch_start_date)) &
        !is.na(as.Date(cache_refresh_plan$fetch_end_date))
      range_values[has_range] <- paste(
        as.character(as.Date(cache_refresh_plan$fetch_start_date[has_range])),
        as.character(as.Date(cache_refresh_plan$fetch_end_date[has_range])),
        sep = ":"
      )
    }
    plan_ranges <- data.frame(
      symbol = cache_refresh_plan$symbol,
      fetch_range = range_values,
      stringsAsFactors = FALSE
    )
    refresh_fetch_ranges_by_symbol <- symbol_text_summary(requested_symbols, plan_ranges, "fetch_range")
  }

  no_returned_bar_symbols <- character()
  returned_bar_counts_by_symbol <- ""
  merged_row_counts_by_symbol <- ""
  if (is.data.frame(cache_refresh_result) && nrow(cache_refresh_result) > 0L) {
    if ("no_returned_bars" %in% names(cache_refresh_result)) {
      no_returned_bar_symbols <- cache_refresh_result$symbol[as.logical(cache_refresh_result$no_returned_bars)]
    }
    returned_bar_counts_by_symbol <- symbol_text_summary(requested_symbols, cache_refresh_result, "returned_bar_count")
    merged_row_counts_by_symbol <- symbol_text_summary(requested_symbols, cache_refresh_result, "merged_row_count")
  }

  row_counts <- if ("symbol" %in% names(bars) && nrow(bars) > 0L) {
    counts <- table(g5_standardize_symbol(bars$symbol))
    paste(paste(names(counts), as.integer(counts), sep = "="), collapse = ";")
  } else {
    ""
  }

  latest_sessions <- if (nrow(latest_by_symbol) > 0L) {
    paste(
      paste(latest_by_symbol$symbol, as.character(latest_by_symbol$latest_cached_session), sep = "="),
      collapse = ";"
    )
  } else {
    ""
  }

  automatic_warnings <- character()
  if (length(empty_symbols) > 0L) {
    automatic_warnings <- c(automatic_warnings, paste0("empty_symbols=", paste(empty_symbols, collapse = ",")))
  }
  if (length(partial_history_symbols) > 0L) {
    automatic_warnings <- c(
      automatic_warnings,
      paste0("partial_history_symbols=", paste(partial_history_symbols, collapse = ","))
    )
  }
  if (length(empty_symbols) == length(requested_symbols)) {
    automatic_warnings <- c(automatic_warnings, "empty_provider_payload_for_requested_range")
  }
  if (length(no_returned_bar_symbols) > 0L) {
    automatic_warnings <- c(
      automatic_warnings,
      paste0("no_returned_bars=", paste(no_returned_bar_symbols, collapse = ","))
    )
  }
  availability_warnings <- c(as.character(availability_warnings), automatic_warnings)
  availability_warnings <- availability_warnings[!is.na(availability_warnings) & nzchar(availability_warnings)]

  data.frame(
    requested_symbols = paste(requested_symbols, collapse = ","),
    requested_symbol_count = length(requested_symbols),
    present_symbol_count = length(present_symbols),
    present_symbols = paste(present_symbols, collapse = ","),
    missing_symbol_count = length(missing_symbols),
    missing_symbols = paste(missing_symbols, collapse = ","),
    row_count = nrow(bars),
    row_counts_by_symbol = row_counts,
    duplicate_symbol_session_count = duplicate_count,
    latest_completed_session = latest_completed_session,
    first_available_session_by_symbol = symbol_date_summary(
      requested_symbols,
      first_by_symbol,
      "first_available_session"
    ),
    latest_available_session_by_symbol = symbol_date_summary(
      requested_symbols,
      latest_by_symbol,
      "latest_cached_session"
    ),
    requested_start_date = requested_start_date,
    requested_end_date = requested_end_date,
    observed_start_date = observed_start_date,
    observed_end_date = observed_end_date,
    empty_symbol_count = length(empty_symbols),
    empty_symbols = paste(empty_symbols, collapse = ","),
    partial_history_symbol_count = length(partial_history_symbols),
    partial_history_symbols = paste(partial_history_symbols, collapse = ","),
    availability_warning_count = length(availability_warnings),
    availability_warnings = paste(availability_warnings, collapse = ";"),
    latest_cached_session_by_symbol = latest_sessions,
    stale_symbol_count = length(stale_symbols),
    stale_symbols = paste(stale_symbols, collapse = ","),
    cache_hit_symbol_count = length(intersect(requested_symbols, cache_hits)),
    cache_hit_symbols = paste(intersect(requested_symbols, cache_hits), collapse = ","),
    cache_miss_symbol_count = length(intersect(requested_symbols, cache_misses)),
    cache_miss_symbols = paste(intersect(requested_symbols, cache_misses), collapse = ","),
    refresh_fetch_symbol_count = length(intersect(requested_symbols, planned_fetch_symbols)),
    refresh_fetch_symbols = paste(intersect(requested_symbols, planned_fetch_symbols), collapse = ","),
    refresh_skip_symbol_count = length(intersect(requested_symbols, skipped_fetch_symbols)),
    refresh_skip_symbols = paste(intersect(requested_symbols, skipped_fetch_symbols), collapse = ","),
    refresh_decisions_by_symbol = refresh_decisions_by_symbol,
    refresh_fetch_ranges_by_symbol = refresh_fetch_ranges_by_symbol,
    no_returned_bar_symbol_count = length(intersect(requested_symbols, no_returned_bar_symbols)),
    no_returned_bar_symbols = paste(intersect(requested_symbols, no_returned_bar_symbols), collapse = ","),
    returned_bar_counts_by_symbol = returned_bar_counts_by_symbol,
    merged_row_counts_by_symbol = merged_row_counts_by_symbol,
    provider_query_timestamp = as.character(provider_query_timestamp),
    stringsAsFactors = FALSE
  )
}
