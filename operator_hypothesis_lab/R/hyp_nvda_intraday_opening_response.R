nior_stop <- function(message) {
  stop(paste0("[NVDA INTRADAY OPENING RESPONSE] ", message), call. = FALSE)
}

nior_contract <- function() {
  list(
    study_id = "HYP-NVDA-OPENING-RESPONSE-01.1",
    symbol = "NVDA",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    opening_slot = 1L,
    required_slots = 1:13,
    lower_tail_probability = 0.20,
    upper_tail_probability = 0.80,
    bin_labels = c("NEGATIVE_TAIL", "MIDDLE_60", "POSITIVE_TAIL"),
    signed_er20_states = c("DOWN_TREND", "SIDEWAYS", "UP_TREND"),
    atrp_states = c("LOW", "MEDIUM", "HIGH")
  )
}

nior_validate_contract <- function(contract = nior_contract()) {
  if (!identical(contract$symbol, "NVDA") ||
      !identical(contract$analysis_start, as.Date("2018-01-02")) ||
      !identical(contract$analysis_end, as.Date("2023-12-29")) ||
      !identical(contract$opening_slot, 1L) ||
      !identical(contract$required_slots, 1:13) ||
      !identical(contract$lower_tail_probability, 0.20) ||
      !identical(contract$upper_tail_probability, 0.80)) {
    nior_stop("The frozen study contract changed.")
  }
  contract
}

nior_validate_points <- function(points, contract = nior_contract()) {
  required <- c(
    "symbol", "session_date", "bar_slot", "bar_time_et", "observation_type",
    "log_return", "open", "close", "feed", "timeframe", "adjustment"
  )
  if (!is.data.frame(points) || !all(required %in% names(points)) || !nrow(points)) {
    nior_stop("The frozen intraday clock points are unavailable or incomplete.")
  }
  x <- points[points$observation_type == "RTH_BAR", required, drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  x$bar_slot <- as.integer(x$bar_slot)
  numeric_fields <- c("log_return", "open", "close")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  if (!nrow(x) || !identical(unique(as.character(x$symbol)), contract$symbol) ||
      anyDuplicated(x[c("session_date", "bar_slot")]) ||
      any(!is.finite(as.matrix(x[numeric_fields]))) ||
      any(x$open <= 0 | x$close <= 0) ||
      !all(x$feed == "sip") || !all(x$timeframe == "30Min") ||
      !all(x$adjustment == "all")) {
    nior_stop("Intraday points violate the frozen adjusted SIP 30-minute contract.")
  }
  x <- x[x$session_date >= contract$analysis_start &
           x$session_date <= contract$analysis_end, , drop = FALSE]
  x[order(x$session_date, x$bar_slot), , drop = FALSE]
}

nior_validate_daily_ledger <- function(daily_ledger, contract = nior_contract()) {
  required <- c("symbol", "session_date", "signed_er20_state", "atrp_state")
  if (!is.data.frame(daily_ledger) || !all(required %in% names(daily_ledger)) ||
      !nrow(daily_ledger)) {
    nior_stop("Daily state ledger is unavailable or incomplete.")
  }
  x <- daily_ledger[as.character(daily_ledger$symbol) == contract$symbol, required, drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  x <- x[order(x$session_date), , drop = FALSE]
  if (!nrow(x) || anyDuplicated(x$session_date) || any(diff(x$session_date) <= 0) ||
      min(x$session_date) >= contract$analysis_start || max(x$session_date) < contract$analysis_end) {
    nior_stop("Daily state ledger does not cover the frozen window with prehistory.")
  }
  x
}

nior_opening_thresholds <- function(opening_log_return, contract = nior_contract()) {
  if (!length(opening_log_return) || any(!is.finite(opening_log_return))) {
    nior_stop("Opening returns are unavailable for threshold construction.")
  }
  q <- stats::quantile(
    opening_log_return,
    probs = c(contract$lower_tail_probability, contract$upper_tail_probability),
    names = FALSE, type = 8
  )
  data.frame(
    threshold = c("LOWER_20_PERCENT", "UPPER_20_PERCENT"),
    probability = c(contract$lower_tail_probability, contract$upper_tail_probability),
    opening_log_return = as.numeric(q),
    stringsAsFactors = FALSE
  )
}

nior_assign_opening_bin <- function(opening_log_return, thresholds,
                                    contract = nior_contract()) {
  lower <- thresholds$opening_log_return[thresholds$threshold == "LOWER_20_PERCENT"]
  upper <- thresholds$opening_log_return[thresholds$threshold == "UPPER_20_PERCENT"]
  if (length(lower) != 1L || length(upper) != 1L || lower >= upper) {
    nior_stop("Opening-return thresholds are invalid.")
  }
  factor(
    ifelse(
      opening_log_return <= lower, "NEGATIVE_TAIL",
      ifelse(opening_log_return >= upper, "POSITIVE_TAIL", "MIDDLE_60")
    ),
    levels = contract$bin_labels, ordered = TRUE
  )
}

nior_build_sessions <- function(points, daily_ledger, contract = nior_contract()) {
  contract <- nior_validate_contract(contract)
  x <- nior_validate_points(points, contract)
  daily <- nior_validate_daily_ledger(daily_ledger, contract)
  groups <- split(seq_len(nrow(x)), x$session_date)
  rows <- lapply(groups, function(index) {
    day <- x[index, , drop = FALSE]
    day <- day[order(day$bar_slot), , drop = FALSE]
    if (!identical(day$bar_slot, contract$required_slots)) return(NULL)
    opening <- day[day$bar_slot == contract$opening_slot, , drop = FALSE]
    data.frame(
      symbol = contract$symbol,
      session_date = day$session_date[[1L]],
      first_bar_open = opening$open[[1L]],
      ten_am_price = opening$close[[1L]],
      session_close = day$close[[nrow(day)]],
      opening_log_return = log(opening$close[[1L]] / opening$open[[1L]]),
      remainder_log_return = log(day$close[[nrow(day)]] / opening$close[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  sessions <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
  rownames(sessions) <- NULL
  if (!nrow(sessions)) nior_stop("No full 13-bar sessions remain.")

  current_index <- match(sessions$session_date, daily$session_date)
  if (any(is.na(current_index)) || any(current_index <= 1L)) {
    nior_stop("One or more intraday sessions cannot be matched to a prior daily state.")
  }
  prior_index <- current_index - 1L
  sessions$state_session <- daily$session_date[prior_index]
  sessions$signed_er20_state <- daily$signed_er20_state[prior_index]
  sessions$atrp_state <- daily$atrp_state[prior_index]
  if (any(sessions$state_session >= sessions$session_date) ||
      any(!sessions$signed_er20_state %in% contract$signed_er20_states) ||
      any(!sessions$atrp_state %in% contract$atrp_states)) {
    nior_stop("Prior-day state assignment is missing, non-causal, or outside the frozen vocabulary.")
  }

  thresholds <- nior_opening_thresholds(sessions$opening_log_return, contract)
  sessions$opening_bin <- nior_assign_opening_bin(
    sessions$opening_log_return, thresholds, contract
  )
  sessions$opening_log_return_pct <- 100 * sessions$opening_log_return
  sessions$remainder_log_return_pct <- 100 * sessions$remainder_log_return
  sessions <- sessions[order(sessions$session_date), , drop = FALSE]
  list(sessions = sessions, thresholds = thresholds)
}

nior_bin_summary <- function(sessions, state_column = NULL,
                             condition = "UNFILTERED",
                             contract = nior_contract()) {
  required <- c("opening_bin", "opening_log_return", "remainder_log_return")
  if (!is.data.frame(sessions) || !all(required %in% names(sessions)) || !nrow(sessions)) {
    nior_stop("Session ledger is unavailable for bin summary.")
  }
  state_levels <- if (is.null(state_column)) {
    "ALL"
  } else if (identical(state_column, "signed_er20_state")) {
    contract$signed_er20_states
  } else if (identical(state_column, "atrp_state")) {
    contract$atrp_states
  } else {
    nior_stop("Unknown state column requested.")
  }
  rows <- list()
  z <- 0L
  for (state in state_levels) for (bin in contract$bin_labels) {
    keep <- sessions$opening_bin == bin
    if (!is.null(state_column)) keep <- keep & sessions[[state_column]] == state
    sample <- sessions[keep, , drop = FALSE]
    z <- z + 1L
    rows[[z]] <- data.frame(
      condition = condition,
      state = state,
      opening_bin = bin,
      observations = nrow(sample),
      mean_opening_log_return = if (nrow(sample)) mean(sample$opening_log_return) else NA_real_,
      median_opening_log_return = if (nrow(sample)) stats::median(sample$opening_log_return) else NA_real_,
      mean_remainder_log_return = if (nrow(sample)) mean(sample$remainder_log_return) else NA_real_,
      median_remainder_log_return = if (nrow(sample)) stats::median(sample$remainder_log_return) else NA_real_,
      probability_remainder_up = if (nrow(sample)) mean(sample$remainder_log_return > 0) else NA_real_,
      same_direction_fraction = if (nrow(sample))
        mean(sign(sample$opening_log_return) == sign(sample$remainder_log_return)) else NA_real_,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

nior_state_summary <- function(sessions, state_column = NULL,
                               condition = "UNFILTERED",
                               contract = nior_contract()) {
  state_levels <- if (is.null(state_column)) {
    "ALL"
  } else if (identical(state_column, "signed_er20_state")) {
    contract$signed_er20_states
  } else if (identical(state_column, "atrp_state")) {
    contract$atrp_states
  } else {
    nior_stop("Unknown state column requested.")
  }
  rows <- lapply(state_levels, function(state) {
    sample <- if (is.null(state_column)) sessions else
      sessions[sessions[[state_column]] == state, , drop = FALSE]
    estimable <- nrow(sample) >= 3L && stats::sd(sample$opening_log_return) > 0 &&
      stats::sd(sample$remainder_log_return) > 0
    data.frame(
      condition = condition,
      state = state,
      observations = nrow(sample),
      pearson_correlation = if (estimable)
        stats::cor(sample$opening_log_return, sample$remainder_log_return) else NA_real_,
      spearman_correlation = if (estimable)
        suppressWarnings(stats::cor(sample$opening_log_return, sample$remainder_log_return, method = "spearman")) else NA_real_,
      mean_remainder_log_return = if (nrow(sample)) mean(sample$remainder_log_return) else NA_real_,
      median_remainder_log_return = if (nrow(sample)) stats::median(sample$remainder_log_return) else NA_real_,
      probability_remainder_up = if (nrow(sample)) mean(sample$remainder_log_return > 0) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

nior_build_paths <- function(points, sessions, contract = nior_contract()) {
  x <- nior_validate_points(points, contract)
  x <- x[x$session_date %in% sessions$session_date, , drop = FALSE]
  groups <- split(seq_len(nrow(x)), x$session_date)
  rows <- lapply(groups, function(index) {
    day <- x[index, , drop = FALSE]
    day <- day[order(day$bar_slot), , drop = FALSE]
    if (!identical(day$bar_slot, contract$required_slots)) return(NULL)
    session_row <- sessions[sessions$session_date == day$session_date[[1L]], , drop = FALSE]
    base_price <- day$close[day$bar_slot == contract$opening_slot]
    bar_starts <- as.POSIXct(
      paste("2000-01-03", day$bar_time_et), tz = "America/New_York"
    )
    data.frame(
      symbol = contract$symbol,
      session_date = day$session_date,
      state_session = session_row$state_session[[1L]],
      opening_bin = as.character(session_row$opening_bin[[1L]]),
      signed_er20_state = session_row$signed_er20_state[[1L]],
      atrp_state = session_row$atrp_state[[1L]],
      path_step = 0:12,
      clock_label = format(bar_starts + 30 * 60, "%H:%M"),
      cumulative_remainder_log_return = log(day$close / base_price),
      stringsAsFactors = FALSE
    )
  })
  paths <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
  paths$cumulative_remainder_log_return_pct <- 100 * paths$cumulative_remainder_log_return
  rownames(paths) <- NULL
  paths
}

nior_path_summary <- function(paths, contract = nior_contract()) {
  groups <- split(seq_len(nrow(paths)), interaction(paths$opening_bin, paths$path_step, drop = TRUE))
  rows <- lapply(groups, function(index) {
    sample <- paths[index, , drop = FALSE]
    x <- sample$cumulative_remainder_log_return
    data.frame(
      opening_bin = sample$opening_bin[[1L]],
      path_step = sample$path_step[[1L]],
      clock_label = sample$clock_label[[1L]],
      observations = nrow(sample),
      mean_cumulative_log_return = mean(x),
      median_cumulative_log_return = stats::median(x),
      q25_cumulative_log_return = unname(stats::quantile(x, 0.25, type = 8)),
      q75_cumulative_log_return = unname(stats::quantile(x, 0.75, type = 8)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$opening_bin <- factor(out$opening_bin, levels = contract$bin_labels, ordered = TRUE)
  out <- out[order(out$opening_bin, out$path_step), , drop = FALSE]
  out$opening_bin <- as.character(out$opening_bin)
  rownames(out) <- NULL
  out
}
