# Gen5.4 N1A point-in-time news-admissibility helpers.

g5_gen54_news_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message) else stop(message, call. = FALSE)
}

g5_gen54_news_parse_timestamp <- function(x, field_name) {
  values <- as.character(x)
  parsed <- as.POSIXct(values, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  if (any(is.na(parsed))) {
    bad <- unique(values[is.na(parsed)])
    g5_gen54_news_stop(paste0(field_name, " contains invalid RFC-3339 UTC timestamp(s): ", paste(head(bad, 3L), collapse = ", ")))
  }
  parsed
}

g5_gen54_news_normalize_headline <- function(x) {
  values <- trimws(tolower(as.character(x)))
  ascii <- iconv(values, from = "UTF-8", to = "ASCII//TRANSLIT")
  ascii[is.na(ascii)] <- values[is.na(ascii)]
  ascii <- gsub("[^a-z0-9]+", " ", ascii)
  trimws(gsub("[[:space:]]+", " ", ascii))
}

g5_gen54_news_assign_sessions <- function(
  timestamps,
  session_dates,
  cutoff_time = "17:30:00",
  timezone = "America/New_York"
) {
  parsed <- if (inherits(timestamps, "POSIXt")) timestamps else g5_gen54_news_parse_timestamp(timestamps, "timestamps")
  sessions <- sort(unique(as.Date(session_dates)))
  if (!length(sessions) || any(is.na(sessions))) g5_gen54_news_stop("session_dates must contain valid market sessions.")
  if (!grepl("^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$", cutoff_time)) {
    g5_gen54_news_stop("cutoff_time must use HH:MM:SS.")
  }

  local_date <- as.Date(format(parsed, tz = timezone, format = "%Y-%m-%d"))
  local_clock <- format(parsed, tz = timezone, format = "%H:%M:%S")
  before_cutoff <- local_clock <= cutoff_time
  session_number <- as.numeric(sessions)
  local_number <- as.numeric(local_date)
  same_session_index <- match(local_number, session_number)
  next_session_index <- findInterval(local_number, session_number) + 1L
  decision_index <- ifelse(!is.na(same_session_index) & before_cutoff, same_session_index, next_session_index)
  decision_index[decision_index < 1L | decision_index > length(sessions)] <- NA_integer_
  decision <- as.Date(rep(NA_real_, length(parsed)), origin = "1970-01-01")
  decision[!is.na(decision_index)] <- sessions[decision_index[!is.na(decision_index)]]
  execution_index <- decision_index + 1L
  execution_index[is.na(decision_index) | execution_index > length(sessions)] <- NA_integer_
  execution <- as.Date(rep(NA_real_, length(parsed)), origin = "1970-01-01")
  execution[!is.na(execution_index)] <- sessions[execution_index[!is.na(execution_index)]]

  data.frame(
    local_calendar_date = local_date,
    at_or_before_cutoff = before_cutoff,
    decision_session = decision,
    execution_session = execution,
    stringsAsFactors = FALSE
  )
}

g5_gen54_news_cluster_exact_titles <- function(articles, repeat_window_hours = 72) {
  required <- c("article_id", "headline", "updated_at")
  missing <- setdiff(required, names(articles))
  if (length(missing)) g5_gen54_news_stop(paste("articles missing required columns:", paste(missing, collapse = ", ")))
  repeat_window_hours <- as.numeric(repeat_window_hours)
  if (!is.finite(repeat_window_hours) || repeat_window_hours <= 0) {
    g5_gen54_news_stop("repeat_window_hours must be positive.")
  }

  out <- articles
  out$normalized_headline <- g5_gen54_news_normalize_headline(out$headline)
  updated <- g5_gen54_news_parse_timestamp(out$updated_at, "updated_at")
  out$exact_title_cluster_id <- NA_character_
  out$exact_title_repeat <- FALSE
  out$prior_exact_title_gap_hours <- NA_real_

  ordered_rows <- order(out$normalized_headline, updated, out$article_id)
  previous_headline <- NA_character_
  previous_time <- as.POSIXct(NA, tz = "UTC")
  cluster_anchor <- NA_character_
  for (row in ordered_rows) {
    same_headline <- !is.na(previous_headline) && identical(out$normalized_headline[[row]], previous_headline)
    gap <- if (same_headline) as.numeric(difftime(updated[row], previous_time, units = "hours")) else Inf
    if (!same_headline || !is.finite(gap) || gap > repeat_window_hours) {
      cluster_anchor <- out$article_id[[row]]
    } else {
      out$exact_title_repeat[[row]] <- TRUE
      out$prior_exact_title_gap_hours[[row]] <- gap
    }
    out$exact_title_cluster_id[[row]] <- paste0("title_", cluster_anchor)
    previous_headline <- out$normalized_headline[[row]]
    previous_time <- updated[row]
  }
  out
}

g5_gen54_news_build_admissibility <- function(
  articles,
  candidate_symbols,
  session_dates,
  cutoff_time = "17:30:00",
  timezone = "America/New_York",
  repeat_window_hours = 72
) {
  required <- c("article_id", "headline", "symbols", "created_at", "updated_at")
  missing <- setdiff(required, names(articles))
  if (length(missing)) g5_gen54_news_stop(paste("articles missing required columns:", paste(missing, collapse = ", ")))
  candidate_symbols <- sort(unique(toupper(trimws(as.character(candidate_symbols)))))
  candidate_symbols <- candidate_symbols[nzchar(candidate_symbols)]
  if (!length(candidate_symbols)) g5_gen54_news_stop("candidate_symbols cannot be empty.")

  out <- g5_gen54_news_cluster_exact_titles(articles, repeat_window_hours)
  created <- g5_gen54_news_parse_timestamp(out$created_at, "created_at")
  updated <- g5_gen54_news_parse_timestamp(out$updated_at, "updated_at")
  out$update_delay_seconds <- as.numeric(difftime(updated, created, units = "secs"))
  created_sessions <- g5_gen54_news_assign_sessions(created, session_dates, cutoff_time, timezone)
  updated_sessions <- g5_gen54_news_assign_sessions(updated, session_dates, cutoff_time, timezone)
  out$created_decision_session <- created_sessions$decision_session
  out$decision_session <- updated_sessions$decision_session
  out$execution_session <- updated_sessions$execution_session
  out$updated_local_date <- updated_sessions$local_calendar_date
  out$updated_at_or_before_cutoff <- updated_sessions$at_or_before_cutoff
  out$revision_crossed_decision_cycle <- !is.na(out$created_decision_session) &
    !is.na(out$decision_session) & out$created_decision_session != out$decision_session

  tag_lists <- strsplit(as.character(out$symbols), "|", fixed = TRUE)
  tag_lists <- lapply(tag_lists, function(tagged) intersect(candidate_symbols, toupper(unique(tagged[nzchar(tagged)]))))
  association_count <- lengths(tag_lists)
  article_rows <- rep.int(seq_len(nrow(out)), association_count)
  association_symbols <- unlist(tag_lists, use.names = FALSE)
  associations <- if (length(article_rows)) data.frame(
    article_id = out$article_id[article_rows],
    symbol = association_symbols,
    decision_session = out$decision_session[article_rows],
    execution_session = out$execution_session[article_rows],
    exact_title_cluster_id = out$exact_title_cluster_id[article_rows],
    exact_title_repeat = out$exact_title_repeat[article_rows],
    revision_crossed_decision_cycle = out$revision_crossed_decision_cycle[article_rows],
    stringsAsFactors = FALSE
  ) else data.frame(
    article_id = character(), symbol = character(), decision_session = as.Date(character()),
    execution_session = as.Date(character()), exact_title_cluster_id = character(),
    exact_title_repeat = logical(), revision_crossed_decision_cycle = logical(), stringsAsFactors = FALSE
  )
  rownames(associations) <- NULL
  list(articles = out, associations = associations)
}

g5_gen54_news_coverage <- function(associations, candidate_symbols, session_dates, start_date, end_date) {
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  sessions <- sort(unique(as.Date(session_dates)))
  sessions <- sessions[sessions >= start_date & sessions <= end_date]
  symbols <- sort(unique(toupper(as.character(candidate_symbols))))
  grid <- expand.grid(symbol = symbols, decision_session = sessions, stringsAsFactors = FALSE)
  grid$decision_session <- as.Date(grid$decision_session, origin = "1970-01-01")
  usable <- associations[!is.na(associations$decision_session) &
    associations$decision_session >= start_date & associations$decision_session <= end_date, , drop = FALSE]
  if (nrow(usable)) {
    raw <- aggregate(usable$article_id, list(symbol = usable$symbol, decision_session = usable$decision_session), length)
    names(raw)[[3L]] <- "article_association_count"
    novel <- aggregate(!usable$exact_title_repeat, list(symbol = usable$symbol, decision_session = usable$decision_session), sum)
    names(novel)[[3L]] <- "novel_exact_title_count"
    grid <- merge(grid, raw, by = c("symbol", "decision_session"), all.x = TRUE, sort = TRUE)
    grid <- merge(grid, novel, by = c("symbol", "decision_session"), all.x = TRUE, sort = TRUE)
  } else {
    grid$article_association_count <- 0L
    grid$novel_exact_title_count <- 0L
  }
  grid$article_association_count[is.na(grid$article_association_count)] <- 0L
  grid$novel_exact_title_count[is.na(grid$novel_exact_title_count)] <- 0L
  grid$year <- as.integer(format(grid$decision_session, "%Y"))
  grid$quarter <- paste0(grid$year, "Q", (as.integer(format(grid$decision_session, "%m")) - 1L) %/% 3L + 1L)

  summarize <- function(keys) {
    raw <- aggregate(grid$article_association_count, grid[keys], sum)
    names(raw)[[length(keys) + 1L]] <- "article_association_count"
    novel <- aggregate(grid$novel_exact_title_count, grid[keys], sum)
    names(novel)[[length(keys) + 1L]] <- "novel_exact_title_count"
    event_sessions <- aggregate(grid$novel_exact_title_count > 0, grid[keys], sum)
    names(event_sessions)[[length(keys) + 1L]] <- "event_session_count"
    total_sessions <- aggregate(grid$decision_session, grid[keys], length)
    names(total_sessions)[[length(keys) + 1L]] <- "session_count"
    out <- Reduce(function(x, y) merge(x, y, by = keys, all = TRUE), list(raw, novel, event_sessions, total_sessions))
    out$event_session_share <- out$event_session_count / out$session_count
    out
  }

  list(
    symbol_sessions = grid,
    symbol_year = summarize(c("symbol", "year")),
    symbol_quarter = summarize(c("symbol", "quarter"))
  )
}
