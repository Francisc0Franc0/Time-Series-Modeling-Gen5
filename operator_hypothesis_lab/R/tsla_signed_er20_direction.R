tsder_stop <- function(message) {
  stop(paste0("[TSLA-SIGNED-ER20] ", message), call. = FALSE)
}
tsder_contract <- function() {
  list(
    symbol = "TSLA",
    window_sessions = 20L,
    direction_cutoff = 0.30,
    query_start = as.Date("2017-12-01"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    states = c("UP_TREND", "SIDEWAYS", "DOWN_TREND")
  )
}

tsder_signed_efficiency_ratio <- function(log_close, window_sessions = 20L) {
  window_sessions <- as.integer(window_sessions)
  if (window_sessions < 2L) tsder_stop("Window must contain at least two one-session moves.")
  log_close <- as.numeric(log_close)
  if (any(!is.finite(log_close))) tsder_stop("Log closes must be finite.")
  output <- rep(NA_real_, length(log_close))
  if (length(log_close) <= window_sessions) return(output)

  for (i in seq.int(window_sessions + 1L, length(log_close))) {
    window <- log_close[seq.int(i - window_sessions, i)]
    displacement <- window[[window_sessions + 1L]] - window[[1L]]
    path_length <- sum(abs(diff(window)))
    output[[i]] <- if (path_length > 0) displacement / path_length else 0
  }
  output
}

tsder_classify_direction <- function(score, cutoff = 0.30) {
  cutoff <- as.numeric(cutoff)
  if (length(cutoff) != 1L || !is.finite(cutoff) || cutoff <= 0 || cutoff >= 1) {
    tsder_stop("Direction cutoff must be one finite number strictly between zero and one.")
  }
  ifelse(
    is.na(score),
    NA_character_,
    ifelse(score >= cutoff, "UP_TREND", ifelse(score <= -cutoff, "DOWN_TREND", "SIDEWAYS"))
  )
}

tsder_state_spans <- function(session_date, direction_state) {
  session_date <- as.Date(session_date)
  direction_state <- as.character(direction_state)
  keep <- !is.na(session_date) & !is.na(direction_state)
  session_date <- session_date[keep]
  direction_state <- direction_state[keep]
  if (!length(session_date)) return(data.frame())
  if (anyDuplicated(session_date) || any(diff(session_date) <= 0)) {
    tsder_stop("State-span dates must be unique and strictly increasing.")
  }

  change <- c(TRUE, direction_state[-1L] != direction_state[-length(direction_state)])
  groups <- split(seq_along(session_date), cumsum(change))
  rows <- lapply(groups, function(index) {
    data.frame(
      direction_state = direction_state[[min(index)]],
      band_start = session_date[[min(index)]],
      band_end = session_date[[max(index)]],
      sessions = length(index),
      stringsAsFactors = FALSE
    )
  })
  output <- do.call(rbind, rows)
  rownames(output) <- NULL
  output
}

tsder_state_occupancy <- function(direction_state, states = tsder_contract()$states) {
  direction_state <- as.character(direction_state)
  direction_state <- direction_state[!is.na(direction_state)]
  counts <- table(factor(direction_state, levels = states))
  data.frame(
    direction_state = states,
    sessions = as.integer(counts),
    fraction = if (length(direction_state)) as.integer(counts) / length(direction_state) else NA_real_,
    stringsAsFactors = FALSE
  )
}

tsder_duration_summary <- function(spans, states = tsder_contract()$states) {
  rows <- lapply(states, function(state) {
    durations <- spans$sessions[spans$direction_state == state]
    data.frame(
      direction_state = state,
      spans = length(durations),
      median_sessions = if (length(durations)) stats::median(durations) else NA_real_,
      p90_sessions = if (length(durations)) unname(stats::quantile(durations, 0.90, names = FALSE, type = 1L)) else NA_real_,
      longest_sessions = if (length(durations)) max(durations) else NA_real_,
      one_session_spans = sum(durations == 1L),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

tsder_transition_tables <- function(direction_state, states = tsder_contract()$states) {
  direction_state <- as.character(direction_state)
  direction_state <- direction_state[!is.na(direction_state)]
  if (length(direction_state) < 2L) tsder_stop("At least two classified sessions are required for transitions.")
  from <- factor(head(direction_state, -1L), levels = states)
  to <- factor(tail(direction_state, -1L), levels = states)
  counts <- as.data.frame.matrix(table(from, to))
  counts <- data.frame(from_state = rownames(counts), counts, row.names = NULL, check.names = FALSE)
  probability_matrix <- prop.table(table(from, to), margin = 1L)
  probabilities <- as.data.frame.matrix(probability_matrix)
  probabilities <- data.frame(from_state = rownames(probabilities), probabilities, row.names = NULL, check.names = FALSE)
  list(counts = counts, probabilities = probabilities)
}

tsder_quality_summary <- function(direction_state, spans) {
  direction_state <- as.character(direction_state)
  direction_state <- direction_state[!is.na(direction_state)]
  changes <- if (length(direction_state) >= 2L) direction_state[-1L] != direction_state[-length(direction_state)] else logical()
  isolated <- spans$sessions == 1L
  direct_reversal <- if (length(direction_state) >= 2L) {
    pairs <- paste(head(direction_state, -1L), tail(direction_state, -1L), sep = "->")
    sum(pairs %in% c("UP_TREND->DOWN_TREND", "DOWN_TREND->UP_TREND"))
  } else 0L
  data.frame(
    classified_sessions = length(direction_state),
    state_changes = sum(changes),
    daily_transition_rate = if (length(changes)) mean(changes) else NA_real_,
    total_spans = nrow(spans),
    one_session_spans = sum(isolated),
    one_session_span_fraction = if (nrow(spans)) mean(isolated) else NA_real_,
    direct_up_down_reversals = direct_reversal,
    stringsAsFactors = FALSE
  )
}
