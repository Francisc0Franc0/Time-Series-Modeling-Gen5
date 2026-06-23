# Data-quality audit helpers.

.g5_required_audit_columns <- c(
  "requested_symbols",
  "requested_symbol_count",
  "present_symbol_count",
  "present_symbols",
  "missing_symbol_count",
  "missing_symbols",
  "row_count",
  "row_counts_by_symbol",
  "duplicate_symbol_session_count",
  "latest_completed_session",
  "first_available_session_by_symbol",
  "latest_available_session_by_symbol",
  "requested_start_date",
  "requested_end_date",
  "observed_start_date",
  "observed_end_date",
  "empty_symbol_count",
  "empty_symbols",
  "partial_history_symbol_count",
  "partial_history_symbols",
  "availability_warning_count",
  "availability_warnings",
  "latest_cached_session_by_symbol",
  "stale_symbol_count",
  "stale_symbols",
  "cache_hit_symbol_count",
  "cache_hit_symbols",
  "cache_miss_symbol_count",
  "cache_miss_symbols",
  "refresh_fetch_symbol_count",
  "refresh_fetch_symbols",
  "refresh_skip_symbol_count",
  "refresh_skip_symbols",
  "refresh_decisions_by_symbol",
  "refresh_fetch_ranges_by_symbol",
  "no_returned_bar_symbol_count",
  "no_returned_bar_symbols",
  "returned_bar_counts_by_symbol",
  "merged_row_counts_by_symbol",
  "provider_query_timestamp"
)

g5_required_audit_columns <- function() {
  .g5_required_audit_columns
}

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
  observed_symbols <- if ("symbol" %in% names(bars)) unique(g5_standardize_symbol(bars$symbol)) else character()
  present_symbols <- c(
    intersect(requested_symbols, observed_symbols),
    sort(setdiff(observed_symbols, requested_symbols))
  )
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
  stale_symbols <- c(
    intersect(requested_symbols, stale_symbols),
    sort(setdiff(stale_symbols, requested_symbols))
  )

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
    partial_history_symbols <- c(
      intersect(requested_symbols, partial_history_symbols),
      sort(setdiff(partial_history_symbols, requested_symbols))
    )
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
  if (is.data.frame(cache_refresh_plan) && nrow(cache_refresh_plan) > 0L && "symbol" %in% names(cache_refresh_plan)) {
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
  if (is.data.frame(cache_refresh_result) && nrow(cache_refresh_result) > 0L && "symbol" %in% names(cache_refresh_result)) {
    if ("no_returned_bars" %in% names(cache_refresh_result)) {
      no_returned_bar_symbols <- cache_refresh_result$symbol[as.logical(cache_refresh_result$no_returned_bars)]
    }
    returned_bar_counts_by_symbol <- symbol_text_summary(requested_symbols, cache_refresh_result, "returned_bar_count")
    merged_row_counts_by_symbol <- symbol_text_summary(requested_symbols, cache_refresh_result, "merged_row_count")
  }

  row_counts <- if ("symbol" %in% names(bars) && nrow(bars) > 0L) {
    counts <- table(g5_standardize_symbol(bars$symbol))
    count_symbols <- c(
      intersect(requested_symbols, names(counts)),
      sort(setdiff(names(counts), requested_symbols))
    )
    paste(paste(count_symbols, as.integer(counts[count_symbols]), sep = "="), collapse = ";")
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

g5_audit_artifact <- function(audit) {
  if (!is.data.frame(audit) || nrow(audit) == 0L) {
    g5_stop("audit must be a non-empty data.frame.")
  }
  required <- g5_required_audit_columns()
  missing <- setdiff(required, names(audit))
  if (length(missing) > 0L) {
    g5_stop(paste("audit is missing required columns:", paste(missing, collapse = ", ")))
  }

  out <- audit[required]
  rownames(out) <- NULL
  out
}

g5_write_audit_artifact_csv <- function(audit, path) {
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  artifact <- g5_audit_artifact(audit)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(artifact, path, row.names = FALSE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_symbol_coverage_artifact <- function(
  bars,
  requested_symbols,
  latest_completed_session,
  requested_start_date = NULL,
  requested_end_date = NULL,
  cache_refresh_plan = NULL,
  cache_refresh_result = NULL
) {
  if (!is.data.frame(bars)) {
    g5_stop("bars must be a data.frame.")
  }

  requested_symbols <- g5_standardize_symbol(requested_symbols)
  latest_completed_session <- as.Date(latest_completed_session)
  if (is.na(latest_completed_session)) {
    g5_stop("latest_completed_session must be a valid date.")
  }

  if (nrow(bars) > 0L) {
    bars <- g5_validate_bar_data(bars)
  }

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
  if (!is.na(requested_start_date) && !is.na(requested_end_date) && requested_start_date > requested_end_date) {
    g5_stop("requested_start_date must be on or before requested_end_date.")
  }

  coverage_end_date <- if (is.na(requested_end_date)) {
    latest_completed_session
  } else {
    min(requested_end_date, latest_completed_session)
  }

  if (nrow(bars) > 0L && !all(c("symbol", "session_date") %in% names(bars))) {
    g5_stop("bars must include symbol and session_date columns.")
  }

  row_counts <- integer(length(requested_symbols))
  names(row_counts) <- requested_symbols
  first_sessions <- rep(as.Date(NA_character_), length(requested_symbols))
  latest_sessions <- rep(as.Date(NA_character_), length(requested_symbols))

  if (nrow(bars) > 0L) {
    bars$symbol <- g5_standardize_symbol(bars$symbol)
    bars$session_date <- as.Date(bars$session_date)
    counts <- table(bars$symbol)
    matched_counts <- counts[requested_symbols]
    row_counts <- as.integer(ifelse(is.na(matched_counts), 0L, matched_counts))
    names(row_counts) <- requested_symbols

    first_by_symbol <- aggregate(
      bars$session_date,
      list(symbol = bars$symbol),
      min
    )
    names(first_by_symbol) <- c("symbol", "observed_first_session")
    latest_by_symbol <- aggregate(
      bars$session_date,
      list(symbol = bars$symbol),
      max
    )
    names(latest_by_symbol) <- c("symbol", "observed_latest_session")

    first_idx <- match(requested_symbols, first_by_symbol$symbol)
    latest_idx <- match(requested_symbols, latest_by_symbol$symbol)
    first_sessions <- as.Date(first_by_symbol$observed_first_session[first_idx])
    latest_sessions <- as.Date(latest_by_symbol$observed_latest_session[latest_idx])
  }

  is_empty <- row_counts == 0L
  can_evaluate_partial <- !is.na(requested_start_date) && !is.na(coverage_end_date)
  is_partial_history <- rep(FALSE, length(requested_symbols))
  if (can_evaluate_partial) {
    is_partial_history <- !is_empty & (
      first_sessions > requested_start_date |
        latest_sessions < coverage_end_date
    )
  }
  is_stale <- !is_empty & latest_sessions < latest_completed_session

  partial_history_status <- if (!can_evaluate_partial) {
    rep("not_evaluated", length(requested_symbols))
  } else ifelse(
    is_empty,
    "empty",
    ifelse(is_partial_history, "partial_history", "covers_requested_range")
  )
  stale_status <- ifelse(is_empty, "empty", ifelse(is_stale, "stale", "current"))

  out <- data.frame(
    symbol = requested_symbols,
    requested_start_date = requested_start_date,
    requested_end_date = requested_end_date,
    coverage_end_date = coverage_end_date,
    latest_completed_session = latest_completed_session,
    observed_first_session = first_sessions,
    observed_latest_session = latest_sessions,
    row_count = as.integer(row_counts),
    is_empty = as.logical(is_empty),
    empty_status = ifelse(is_empty, "empty", "has_rows"),
    is_partial_history = as.logical(is_partial_history),
    partial_history_status = partial_history_status,
    is_stale = as.logical(is_stale),
    stale_status = stale_status,
    stringsAsFactors = FALSE
  )

  if (is.data.frame(cache_refresh_plan) && nrow(cache_refresh_plan) > 0L) {
    plan_cols <- intersect(
      c("symbol", "cache_file_exists", "needs_fetch", "refresh_decision"),
      names(cache_refresh_plan)
    )
    plan <- cache_refresh_plan[plan_cols]
    plan$symbol <- g5_standardize_symbol(plan$symbol)
    out <- merge(out, plan, by = "symbol", all.x = TRUE, sort = FALSE)
  }

  if (is.data.frame(cache_refresh_result) && nrow(cache_refresh_result) > 0L) {
    result_cols <- intersect(
      c("symbol", "returned_bar_count", "merged_row_count", "no_returned_bars", "wrote_cache"),
      names(cache_refresh_result)
    )
    result <- cache_refresh_result[result_cols]
    result$symbol <- g5_standardize_symbol(result$symbol)
    out <- merge(out, result, by = "symbol", all.x = TRUE, sort = FALSE)
  }

  out <- out[match(requested_symbols, out$symbol), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_write_symbol_coverage_artifact_csv <- function(symbol_coverage, path) {
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  if (!is.data.frame(symbol_coverage) || nrow(symbol_coverage) == 0L) {
    g5_stop("symbol_coverage must be a non-empty data.frame.")
  }
  required <- c(
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
  missing <- setdiff(required, names(symbol_coverage))
  if (length(missing) > 0L) {
    g5_stop(paste("symbol_coverage is missing required columns:", paste(missing, collapse = ", ")))
  }

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(symbol_coverage, path, row.names = FALSE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_symbol_coverage_chart <- function(symbol_coverage, path) {
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  if (!is.data.frame(symbol_coverage) || nrow(symbol_coverage) == 0L) {
    g5_stop("symbol_coverage must be a non-empty data.frame.")
  }

  required <- c(
    "symbol",
    "requested_start_date",
    "coverage_end_date",
    "observed_first_session",
    "observed_latest_session",
    "is_empty",
    "is_partial_history",
    "is_stale"
  )
  missing <- setdiff(required, names(symbol_coverage))
  if (length(missing) > 0L) {
    g5_stop(paste("symbol_coverage is missing required columns:", paste(missing, collapse = ", ")))
  }

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  width <- 1000L
  height <- max(360L, 120L + 34L * nrow(symbol_coverage))
  grDevices::png(filename = path, width = width, height = height)
  on.exit(grDevices::dev.off(), add = TRUE)

  symbols <- rev(symbol_coverage$symbol)
  y <- seq_along(symbols)
  plot_dates <- as.Date(c(
    symbol_coverage$requested_start_date,
    symbol_coverage$coverage_end_date,
    symbol_coverage$observed_first_session,
    symbol_coverage$observed_latest_session
  ))
  xlim <- range(plot_dates, na.rm = TRUE)
  if (!all(is.finite(as.numeric(xlim)))) {
    xlim <- as.Date(c("1970-01-01", "1970-01-02"))
  }
  if (xlim[[1L]] == xlim[[2L]]) {
    xlim <- xlim + c(-1L, 1L)
  }

  graphics::par(mar = c(5, 8, 4, 2))
  graphics::plot(
    x = xlim,
    y = c(1L, length(symbols)),
    type = "n",
    yaxt = "n",
    xlab = "Session date",
    ylab = "",
    main = "Gen5 Data-Layer Cache Coverage By Symbol"
  )
  graphics::axis(2, at = y, labels = symbols, las = 1)
  graphics::grid(nx = NA, ny = NULL, col = "gray90")

  requested_start <- unique(as.Date(symbol_coverage$requested_start_date))
  coverage_end <- unique(as.Date(symbol_coverage$coverage_end_date))
  requested_start <- requested_start[!is.na(requested_start)]
  coverage_end <- coverage_end[!is.na(coverage_end)]
  if (length(requested_start) > 0L && length(coverage_end) > 0L) {
    graphics::segments(
      x0 = requested_start[[1L]],
      x1 = coverage_end[[1L]],
      y0 = y,
      y1 = y,
      col = "gray80",
      lwd = 8,
      lend = "butt"
    )
  }

  chart_rows <- symbol_coverage[match(symbols, symbol_coverage$symbol), , drop = FALSE]
  colors <- ifelse(
    chart_rows$is_empty,
    "gray55",
    ifelse(chart_rows$is_partial_history, "#7570B3", ifelse(chart_rows$is_stale, "#D95F02", "#1B9E77"))
  )
  has_rows <- !chart_rows$is_empty &
    !is.na(as.Date(chart_rows$observed_first_session)) &
    !is.na(as.Date(chart_rows$observed_latest_session))
  if (any(has_rows)) {
    graphics::segments(
      x0 = as.Date(chart_rows$observed_first_session[has_rows]),
      x1 = as.Date(chart_rows$observed_latest_session[has_rows]),
      y0 = y[has_rows],
      y1 = y[has_rows],
      col = colors[has_rows],
      lwd = 4,
      lend = "butt"
    )
    single_day_rows <- has_rows &
      as.Date(chart_rows$observed_first_session) == as.Date(chart_rows$observed_latest_session)
    if (any(single_day_rows)) {
      graphics::points(
        x = as.Date(chart_rows$observed_first_session[single_day_rows]),
        y = y[single_day_rows],
        pch = 16,
        col = colors[single_day_rows],
        cex = 1.2
      )
    }
  }
  if (any(!has_rows)) {
    graphics::points(
      x = rep(xlim[[1L]], sum(!has_rows)),
      y = y[!has_rows],
      pch = 4,
      col = colors[!has_rows],
      lwd = 2
    )
  }
  graphics::legend(
    "bottomright",
    legend = c("requested range", "covers range", "partial history", "stale", "empty"),
    col = c("gray80", "#1B9E77", "#7570B3", "#D95F02", "gray55"),
    lwd = c(8, 4, 4, 4, NA),
    pch = c(NA, NA, NA, NA, 4),
    bty = "n"
  )

  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
