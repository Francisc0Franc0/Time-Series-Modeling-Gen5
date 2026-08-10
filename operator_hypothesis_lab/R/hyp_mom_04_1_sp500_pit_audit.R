# Point-in-time S&P 500 data-feasibility audit for HYP-MOM-04.1.

spit_stop <- function(message) stop(message, call. = FALSE)

spit_contract <- function() {
  list(
    audit_id = "SP500-PIT-DATA-AUDIT-01",
    program_id = "HYP-MOM-04.1",
    as_of_timestamp = "2026-08-07 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    query_end = as.Date("2020-12-31"),
    forbidden_start = as.Date("2021-01-01"),
    signal_quarters = paste0(rep(2017:2020, each = 4), "Q", rep(1:4, 4))[1:15],
    feature_sessions = 253L,
    primary_commit = "c31ac3cc56f28cf9a02b4e694eff7ceab596a0ff",
    primary_repository = "https://github.com/fja05680/sp500",
    primary_interval_file = "sp500_ticker_start_end.csv",
    primary_snapshot_file = "S&P 500 Historical Components & Changes (Updated).csv",
    primary_current_file = "sp500.csv",
    wikipedia_page = "List of S&P 500 companies",
    wikipedia_cutoff_utc = "22:00:00",
    roster_min = 490L,
    roster_max = 510L,
    minimum_jaccard = 0.97,
    minimum_sector_coverage = 0.98,
    minimum_sectors = 10L,
    minimum_complete_coverage = 0.95,
    minimum_removed_history = 0.95
  )
}

spit_validate_contract <- function(contract = spit_contract()) {
  frozen <- spit_contract()
  if (!identical(names(contract), names(frozen))) spit_stop("Frozen SP500-PIT-DATA-AUDIT-01 contract fields changed.")
  same <- vapply(names(frozen), function(name) identical(contract[[name]], frozen[[name]]), logical(1))
  if (!all(same)) spit_stop(paste("Frozen SP500-PIT-DATA-AUDIT-01 contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  contract
}

spit_normalize_symbol <- function(symbol) {
  x <- toupper(trimws(as.character(symbol)))
  gsub("[^A-Z0-9]", "", x)
}

spit_provider_candidates <- function(symbol) {
  symbol <- toupper(trimws(as.character(symbol)))
  candidates <- symbol
  # Alpaca accepts the historical dot spelling (for example BF.B) and rejects
  # the slash spelling with HTTP 400. A slash-origin source is therefore also
  # checked under its deterministic dot spelling; a valid dot source is not
  # converted into a known-invalid provider request.
  if (grepl("/", symbol, fixed = TRUE)) candidates <- c(candidates, sub("/", ".", symbol, fixed = TRUE))
  unique(candidates)
}

spit_read_intervals <- function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"))
  required <- c("ticker", "start_date", "end_date")
  if (!all(required %in% names(x))) spit_stop("Primary interval ledger has an unexpected schema.")
  x <- x[required]
  x$ticker <- toupper(trimws(x$ticker))
  x$start_date <- as.Date(x$start_date)
  x$end_date <- as.Date(x$end_date)
  if (any(!nzchar(x$ticker)) || anyNA(x$start_date)) spit_stop("Primary interval ledger contains blank tickers or invalid start dates.")
  if (any(!is.na(x$end_date) & x$end_date <= x$start_date)) spit_stop("Primary interval ledger contains non-positive membership intervals.")
  x
}

spit_members_at <- function(intervals, signal_date) {
  signal_date <- as.Date(signal_date)
  x <- intervals[intervals$start_date <= signal_date & (is.na(intervals$end_date) | intervals$end_date > signal_date), , drop = FALSE]
  if (anyDuplicated(x$ticker)) spit_stop(paste("Primary ledger has multiple active intervals on", signal_date))
  x[order(x$ticker), , drop = FALSE]
}

spit_snapshot_at <- function(snapshots, signal_date) {
  signal_date <- as.Date(signal_date)
  snapshots$date <- as.Date(snapshots$date)
  available <- which(snapshots$date <= signal_date)
  if (!length(available)) spit_stop(paste("Historical snapshot ledger has no observation at or before", signal_date))
  row <- snapshots[available[[which.max(snapshots$date[available])]], , drop = FALSE]
  symbols <- strsplit(as.character(row$tickers[[1L]]), ",", fixed = TRUE)[[1L]]
  data.frame(snapshot_date = row$date[[1L]], ticker = sort(unique(toupper(trimws(symbols)))), stringsAsFactors = FALSE)
}

spit_decode_html <- function(x) {
  x <- gsub("<script[^>]*>.*?</script>|<style[^>]*>.*?</style>|<sup[^>]*>.*?</sup>", "", x, perl = TRUE, ignore.case = TRUE)
  x <- gsub("<br\\s*/?>", " ", x, perl = TRUE, ignore.case = TRUE)
  x <- gsub("<[^>]+>", "", x, perl = TRUE)
  replacements <- c("&amp;" = "&", "&nbsp;" = " ", "&#160;" = " ", "&ndash;" = "-", "&mdash;" = "-", "&quot;" = "\"", "&#39;" = "'", "&apos;" = "'")
  for (entity in names(replacements)) x <- gsub(entity, replacements[[entity]], x, fixed = TRUE)
  x <- gsub("&#91;[0-9]+&#93;", "", x, perl = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}

spit_parse_wikipedia_table <- function(html) {
  tables <- regmatches(html, gregexpr("(?is)<table[^>]*>.*?</table>", html, perl = TRUE))[[1L]]
  if (!length(tables)) spit_stop("Wikipedia revision contained no table.")
  table_headers <- lapply(tables, function(table) {
    raw <- regmatches(table, gregexpr("(?is)<th[^>]*>.*?</th>", table, perl = TRUE))[[1L]]
    if (!length(raw)) character() else vapply(raw, spit_decode_html, character(1))
  })
  wanted_at <- which(vapply(table_headers, function(header) {
    any(header == "GICS Sector") && any(tolower(header) %in% c("symbol", "ticker", "ticker symbol"))
  }, logical(1)))[1L]
  if (is.na(wanted_at)) spit_stop("Wikipedia revision contained no recognizable constituent/sector table.")
  wanted <- tables[[wanted_at]]
  rows <- regmatches(wanted, gregexpr("(?is)<tr[^>]*>.*?</tr>", wanted, perl = TRUE))[[1L]]
  cells <- lapply(rows, function(row) {
    raw <- regmatches(row, gregexpr("(?is)<t[dh][^>]*>.*?</t[dh]>", row, perl = TRUE))[[1L]]
    vapply(raw, spit_decode_html, character(1))
  })
  cells <- Filter(length, cells)
  header_at <- which(vapply(cells, function(row) any(grepl("GICS Sector", row, fixed = TRUE)), logical(1)))[1L]
  if (is.na(header_at)) spit_stop("Wikipedia table header could not be resolved.")
  header <- cells[[header_at]]
  symbol_col <- which(tolower(header) %in% c("symbol", "ticker", "ticker symbol"))[1L]
  sector_col <- which(grepl("GICS Sector", header, fixed = TRUE))[1L]
  security_col <- which(tolower(header) %in% c("security", "company"))[1L]
  if (anyNA(c(symbol_col, sector_col))) spit_stop("Wikipedia table lacks required symbol or GICS sector columns.")
  data_rows <- cells[seq.int(header_at + 1L, length(cells))]
  parsed <- lapply(data_rows, function(row) {
    if (length(row) < max(symbol_col, sector_col)) return(NULL)
    symbol <- toupper(trimws(row[[symbol_col]]))
    sector <- trimws(row[[sector_col]])
    if (!nzchar(symbol) || !nzchar(sector)) return(NULL)
    data.frame(symbol = symbol, sector = sector,
               security = if (!is.na(security_col) && length(row) >= security_col) row[[security_col]] else NA_character_,
               stringsAsFactors = FALSE)
  })
  parsed <- Filter(Negate(is.null), parsed)
  if (!length(parsed)) spit_stop("Wikipedia table yielded no constituents.")
  out <- do.call(rbind, parsed)
  out$normalized_symbol <- spit_normalize_symbol(out$symbol)
  out <- out[!duplicated(out$normalized_symbol), , drop = FALSE]
  rownames(out) <- NULL
  out
}

spit_wikipedia_revision_url <- function(signal_date, contract = spit_contract()) {
  contract <- spit_validate_contract(contract)
  cutoff <- paste0(as.Date(signal_date), "T", contract$wikipedia_cutoff_utc, "Z")
  paste0("https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&prop=revisions&titles=",
         utils::URLencode(contract$wikipedia_page, reserved = TRUE),
         "&rvprop=ids%7Ctimestamp&rvlimit=1&rvdir=older&rvstart=", utils::URLencode(cutoff, reserved = TRUE))
}

spit_fetch_json <- function(url, attempts = 5L) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) spit_stop("jsonlite is required for the Wikipedia point-in-time audit.")
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    result <- tryCatch({
      con <- base::url(url, open = "rb", headers = c("User-Agent" = "Gen5-PIT-Audit/1.0 (research; contact via repository)"))
      on.exit(close(con), add = TRUE)
      jsonlite::fromJSON(con, simplifyVector = TRUE)
    }, error = function(e) {
      last_error <<- e
      NULL
    })
    if (!is.null(result)) return(result)
    if (attempt < attempts) Sys.sleep(3 * attempt)
  }
  spit_stop(paste("Wikipedia API request failed after", attempts, "attempts:", conditionMessage(last_error)))
}

spit_fetch_wikipedia_revision <- function(signal_date, contract = spit_contract()) {
  contract <- spit_validate_contract(contract)
  query_url <- spit_wikipedia_revision_url(signal_date, contract)
  query <- spit_fetch_json(query_url)
  page <- query$query$pages
  if (is.null(page$revisions) || !nrow(page$revisions[[1L]])) spit_stop(paste("No Wikipedia revision resolved for", signal_date))
  revision <- page$revisions[[1L]][1L, , drop = FALSE]
  revision_id <- as.character(revision$revid[[1L]])
  revision_timestamp <- as.character(revision$timestamp[[1L]])
  cutoff <- as.POSIXct(paste0(as.Date(signal_date), " ", contract$wikipedia_cutoff_utc), tz = "UTC")
  observed <- as.POSIXct(revision_timestamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.na(observed) || observed > cutoff) spit_stop("Wikipedia revision exceeded the frozen point-in-time cutoff.")
  Sys.sleep(1)
  parse_url <- paste0("https://en.wikipedia.org/w/api.php?action=parse&format=json&formatversion=2&oldid=", revision_id, "&prop=text")
  parsed <- spit_fetch_json(parse_url)
  roster <- spit_parse_wikipedia_table(parsed$parse$text)
  list(roster = roster, revision_id = revision_id, revision_timestamp = revision_timestamp,
       query_url = query_url, parse_url = parse_url)
}

spit_roster_comparison <- function(primary, wikipedia) {
  p <- unique(spit_normalize_symbol(primary$ticker))
  w <- unique(spit_normalize_symbol(wikipedia$symbol))
  data.frame(primary_count = length(p), wikipedia_count = length(w), intersection_count = length(intersect(p, w)),
             union_count = length(union(p, w)), jaccard = length(intersect(p, w)) / length(union(p, w)),
             primary_only = paste(sort(setdiff(p, w)), collapse = ","),
             wikipedia_only = paste(sort(setdiff(w, p)), collapse = ","), stringsAsFactors = FALSE)
}

spit_sector_join <- function(primary, wikipedia) {
  x <- primary
  x$normalized_symbol <- spit_normalize_symbol(x$ticker)
  w <- wikipedia[c("normalized_symbol", "symbol", "sector", "security")]
  names(w)[names(w) == "symbol"] <- "wikipedia_symbol"
  merge(x, w, by = "normalized_symbol", all.x = TRUE, sort = FALSE)
}

spit_schedule <- function(calendar_dates, signal_quarters) {
  if (!exists("h04_schedule", mode = "function")) spit_stop("h04_schedule must be loaded before the PIT audit schedule is built.")
  h04_schedule(calendar_dates, signal_quarters)
}

spit_resolve_provider_symbols <- function(source_symbols, bars) {
  available <- unique(toupper(as.character(bars$symbol)))
  rows <- lapply(sort(unique(toupper(source_symbols))), function(symbol) {
    candidates <- spit_provider_candidates(symbol)
    matches <- intersect(candidates, available)
    data.frame(source_symbol = symbol, candidate_symbols = paste(candidates, collapse = ","),
               matched_symbols = paste(matches, collapse = ","), match_count = length(matches),
               resolved_symbol = if (length(matches) == 1L) matches[[1L]] else NA_character_,
               identity_status = if (!length(matches)) "NO_HISTORY" else if (length(matches) == 1L) "UNIQUE" else "AMBIGUOUS",
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

spit_member_quarter_coverage <- function(memberships, schedule, calendar_dates, bars, resolutions, feature_sessions = 253L) {
  calendar_dates <- sort(unique(as.Date(calendar_dates)))
  bars$session_date <- as.Date(bars$session_date)
  rows <- lapply(seq_len(nrow(memberships)), function(i) {
    member <- memberships[i, , drop = FALSE]
    s <- schedule[schedule$signal_quarter == member$signal_quarter, , drop = FALSE]
    resolved <- resolutions[resolutions$source_symbol == member$ticker, , drop = FALSE]
    symbol <- if (nrow(resolved) == 1L) resolved$resolved_symbol[[1L]] else NA_character_
    index <- match(s$signal_date, calendar_dates)
    feature_dates <- if (!is.na(index) && index >= feature_sessions) calendar_dates[(index - feature_sessions + 1L):index] else as.Date(character())
    observed <- if (!is.na(symbol)) bars$session_date[bars$symbol == symbol] else as.Date(character())
    feature_complete <- length(feature_dates) == feature_sessions && all(feature_dates %in% observed)
    entry_present <- s$entry_date %in% observed
    exit_present <- s$exit_date %in% observed
    terminal_event <- !is.na(member$end_date) && member$end_date > s$signal_date && member$end_date <= s$exit_date
    data.frame(signal_quarter = member$signal_quarter, ticker = member$ticker, start_date = member$start_date,
               end_date = member$end_date, resolved_symbol = symbol,
               feature_expected_sessions = length(feature_dates), feature_observed_sessions = sum(feature_dates %in% observed),
               feature_complete = feature_complete, entry_present = entry_present, exit_present = exit_present,
               ordinary_complete = feature_complete && entry_present && exit_present,
               terminal_event = terminal_event,
               terminal_return_defensible = !terminal_event || (entry_present && exit_present),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

spit_gate_matrix <- function(roster_summary, sector_summary, resolutions, coverage, removed_summary,
                             revision_ledger, source_ledger, contract = spit_contract()) {
  contract <- spit_validate_contract(contract)
  gates <- data.frame(
    gate_id = c("PROVENANCE", "ROSTER_SIZE", "ROSTER_AGREEMENT", "SECTOR_COVERAGE", "IDENTITY_RESOLUTION",
                "FEATURE_TARGET_COVERAGE", "REMOVED_SECURITY_REPRESENTATION", "TERMINAL_EVENT_COMPLETENESS", "BOUNDARY_INTEGRITY"),
    passed = c(
      nrow(source_ledger) >= 3L && all(nzchar(source_ledger$source_hash)) && all(revision_ledger$cutoff_passed),
      all(roster_summary$primary_count >= contract$roster_min & roster_summary$primary_count <= contract$roster_max),
      all(roster_summary$jaccard >= contract$minimum_jaccard),
      all(sector_summary$sector_coverage >= contract$minimum_sector_coverage & sector_summary$sector_count >= contract$minimum_sectors),
      !any(resolutions$match_count > 1L),
      all(coverage$ordinary_coverage >= contract$minimum_complete_coverage),
      is.finite(removed_summary$history_fraction[[1L]]) && removed_summary$history_fraction[[1L]] >= contract$minimum_removed_history,
      all(coverage$terminal_events == coverage$terminal_returns_defensible),
      all(revision_ledger$cutoff_passed) && all(as.Date(coverage$exit_date) <= contract$query_end)
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  gates
}
