# Fixed pre-OOS SPY deployment-universe audit for HYP-MOM-04.1.

du_stop <- function(message) stop(message, call. = FALSE)

du_contract <- function() {
  list(
    audit_id = "DEPLOYMENT-UNIVERSE-DATA-AUDIT-01",
    program_id = "HYP-MOM-04.1",
    accession = "0001752724-20-236128",
    report_date = as.Date("2020-09-30"),
    filing_date = as.Date("2020-11-19"),
    accepted_timestamp = "2020-11-18 20:32:42 America/New_York",
    sec_index_url = "https://www.sec.gov/Archives/edgar/data/884394/000175272420236128/0001752724-20-236128-index.htm",
    sec_primary_document_url = "https://www.sec.gov/Archives/edgar/data/884394/000175272420236128/primary_doc.xml",
    sec_bulk_archive_url = "https://www.sec.gov/files/dera/data/form-n-port-data-sets/2020q4_nport.zip",
    sec_bulk_archive_name = "2020q4_nport.zip",
    wikipedia_revision_id = "980783480",
    wikipedia_revision_timestamp = "2020-09-28T12:34:09Z",
    wikipedia_cutoff_timestamp = "2020-09-30T22:00:00Z",
    query_start = as.Date("2016-01-04"),
    query_end = as.Date("2020-12-31"),
    forbidden_start = as.Date("2021-01-01"),
    as_of_timestamp = "2026-08-07 17:30:00 America/New_York",
    roster_min = 490L,
    roster_max = 510L,
    minimum_identity_completeness = 0.98,
    minimum_jaccard = 0.97,
    minimum_sector_coverage = 0.98,
    minimum_sectors = 10L,
    minimum_provider_representation = 0.95,
    minimum_complete_train_retention = 0.80
  )
}

du_validate_contract <- function(contract = du_contract()) {
  frozen <- du_contract()
  if (!identical(names(contract), names(frozen))) du_stop("Frozen deployment-universe contract fields changed.")
  same <- vapply(names(frozen), function(name) identical(contract[[name]], frozen[[name]]), logical(1))
  if (!all(same)) du_stop(paste("Frozen deployment-universe contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  contract
}

du_normalize_symbol <- function(symbol) {
  gsub("[^A-Z0-9]", "", toupper(trimws(as.character(symbol))))
}

du_normalize_company <- function(company) {
  x <- toupper(trimws(as.character(company)))
  x <- sub("/[A-Z]{2}$", "", x)
  x <- gsub("&", " AND ", x, fixed = TRUE)
  x <- gsub("[^A-Z0-9 ]", " ", x)
  legal_words <- paste(c(
    "THE", "INCORPORATED", "INC", "CORPORATION", "CORP", "COMPANY", "CO",
    "LIMITED", "LTD", "PLC", "GROUP", "HOLDINGS", "HOLDING", "LLC", "LP",
    "NA", "SA", "AG", "NV", "SE"
  ), collapse = "|")
  x <- gsub(paste0("\\b(", legal_words, ")\\b"), " ", x)
  gsub(" ", "", trimws(gsub("[[:space:]]+", " ", x)), fixed = TRUE)
}

du_filter_accession_lines <- function(lines, accession) {
  startsWith(as.character(lines), paste0(as.character(accession), "\t"))
}

du_filter_holding_id_lines <- function(lines, holding_ids) {
  first_field <- sub("\t.*$", "", as.character(lines))
  first_field %in% as.character(holding_ids)
}

du_validate_filing <- function(holdings, identifiers, contract = du_contract()) {
  contract <- du_validate_contract(contract)
  required_h <- c(
    "ACCESSION_NUMBER", "HOLDING_ID", "ISSUER_NAME", "ISSUER_TITLE", "ISSUER_CUSIP",
    "BALANCE", "CURRENCY_VALUE", "PERCENTAGE", "ASSET_CAT", "ISSUER_TYPE"
  )
  required_i <- c("HOLDING_ID", "IDENTIFIER_ISIN", "IDENTIFIER_TICKER")
  if (!all(required_h %in% names(holdings))) du_stop("N-PORT holdings extract has an unexpected schema.")
  if (!all(required_i %in% names(identifiers))) du_stop("N-PORT identifiers extract has an unexpected schema.")
  if (!nrow(holdings) || any(holdings$ACCESSION_NUMBER != contract$accession)) du_stop("N-PORT holdings do not resolve to the frozen accession.")
  if (anyDuplicated(holdings$HOLDING_ID)) du_stop("N-PORT holding IDs are not unique.")
  if (anyDuplicated(identifiers$HOLDING_ID)) du_stop("N-PORT identifier holding IDs are not unique.")
  if (!setequal(holdings$HOLDING_ID, identifiers$HOLDING_ID)) du_stop("Every holding must have exactly one identifier row.")
  equity <- holdings$ASSET_CAT == "EC"
  if (anyNA(equity) || !all(equity)) du_stop("The frozen SPY extract contains a non-equity holding.")
  out <- merge(holdings, identifiers[required_i], by = "HOLDING_ID", all.x = TRUE, sort = FALSE)
  out <- out[match(holdings$HOLDING_ID, out$HOLDING_ID), , drop = FALSE]
  rownames(out) <- NULL
  out
}

du_validate_wikipedia <- function(wikipedia, contract = du_contract()) {
  contract <- du_validate_contract(contract)
  required <- c("symbol", "security", "sector")
  if (!all(required %in% names(wikipedia))) du_stop("Wikipedia roster has an unexpected schema.")
  wikipedia$symbol <- toupper(trimws(wikipedia$symbol))
  wikipedia$security <- trimws(wikipedia$security)
  wikipedia$sector <- trimws(wikipedia$sector)
  if (any(!nzchar(wikipedia$symbol)) || any(!nzchar(wikipedia$security)) || any(!nzchar(wikipedia$sector))) {
    du_stop("Wikipedia roster contains blank required values.")
  }
  if (anyDuplicated(du_normalize_symbol(wikipedia$symbol))) du_stop("Wikipedia roster has duplicate normalized symbols.")
  wikipedia
}

du_reconcile_sources <- function(filing, wikipedia, crosswalk) {
  wikipedia <- du_validate_wikipedia(wikipedia)
  required_crosswalk <- c("filing_issuer_title", "filing_cusip", "wikipedia_symbol", "wikipedia_security", "mapping_basis")
  if (!all(required_crosswalk %in% names(crosswalk))) du_stop("Pinned source crosswalk has an unexpected schema.")
  crosswalk$filing_issuer_title <- trimws(crosswalk$filing_issuer_title)
  crosswalk$filing_cusip <- toupper(trimws(crosswalk$filing_cusip))
  crosswalk$wikipedia_symbol <- toupper(trimws(crosswalk$wikipedia_symbol))
  crosswalk$key <- paste(crosswalk$filing_issuer_title, crosswalk$filing_cusip, sep = "||")
  if (anyDuplicated(crosswalk$key)) du_stop("Pinned source crosswalk contains duplicate filing keys.")
  if (!all(crosswalk$wikipedia_symbol %in% wikipedia$symbol)) du_stop("Pinned source crosswalk points outside the contemporaneous roster.")
  wiki_security <- wikipedia$security[match(crosswalk$wikipedia_symbol, wikipedia$symbol)]
  if (!all(wiki_security == crosswalk$wikipedia_security)) du_stop("Pinned source crosswalk security labels changed.")

  out <- filing
  out$company_key <- du_normalize_company(out$ISSUER_TITLE)
  wikipedia$company_key <- du_normalize_company(wikipedia$security)
  unique_wiki_keys <- names(which(table(wikipedia$company_key) == 1L))
  exact <- out$company_key %in% unique_wiki_keys
  out$source_symbol <- NA_character_
  out$mapping_method <- "UNRESOLVED"
  out$mapping_basis <- NA_character_
  out$source_symbol[exact] <- wikipedia$symbol[match(out$company_key[exact], wikipedia$company_key)]
  out$mapping_method[exact] <- "NORMALIZED_EXACT"
  out$mapping_basis[exact] <- "deterministic_legal_name_normalization"

  filing_key <- paste(trimws(out$ISSUER_TITLE), toupper(trimws(out$ISSUER_CUSIP)), sep = "||")
  cross_at <- match(filing_key, crosswalk$key)
  pinned <- is.na(out$source_symbol) & !is.na(cross_at)
  out$source_symbol[pinned] <- crosswalk$wikipedia_symbol[cross_at[pinned]]
  out$mapping_method[pinned] <- "PINNED_SOURCE_CROSSWALK"
  out$mapping_basis[pinned] <- crosswalk$mapping_basis[cross_at[pinned]]
  out$wikipedia_security <- wikipedia$security[match(out$source_symbol, wikipedia$symbol)]
  out$sector <- wikipedia$sector[match(out$source_symbol, wikipedia$symbol)]
  out$source_identity <- ifelse(
    is.na(out$source_symbol),
    paste0("UNRESOLVED_", out$ISSUER_CUSIP, "_", out$HOLDING_ID),
    du_normalize_symbol(out$source_symbol)
  )
  if (anyDuplicated(out$source_symbol[!is.na(out$source_symbol)])) du_stop("Multiple filing holdings map to one contemporaneous symbol.")
  out
}

du_source_summary <- function(reconciliation, wikipedia) {
  filing_ids <- unique(reconciliation$source_identity)
  wiki_ids <- unique(du_normalize_symbol(wikipedia$symbol))
  mapped <- !is.na(reconciliation$source_symbol)
  sector_mapped <- !is.na(reconciliation$sector) & nzchar(reconciliation$sector)
  data.frame(
    filing_count = nrow(reconciliation),
    wikipedia_count = nrow(wikipedia),
    normalized_exact = sum(reconciliation$mapping_method == "NORMALIZED_EXACT"),
    pinned_crosswalk = sum(reconciliation$mapping_method == "PINNED_SOURCE_CROSSWALK"),
    unresolved = sum(!mapped),
    identity_completeness = mean(mapped),
    intersection_count = length(intersect(filing_ids, wiki_ids)),
    union_count = length(union(filing_ids, wiki_ids)),
    jaccard = length(intersect(filing_ids, wiki_ids)) / length(union(filing_ids, wiki_ids)),
    sector_mapped = sum(sector_mapped),
    sector_coverage = mean(sector_mapped),
    sector_count = length(unique(reconciliation$sector[sector_mapped])),
    stringsAsFactors = FALSE
  )
}

du_provider_candidates <- function(symbol) {
  symbol <- toupper(trimws(as.character(symbol)))
  candidates <- symbol
  if (grepl("/", symbol, fixed = TRUE)) candidates <- c(candidates, sub("/", ".", symbol, fixed = TRUE))
  unique(candidates)
}

du_resolve_provider_symbols <- function(source_symbols, bars) {
  available <- unique(toupper(as.character(bars$symbol)))
  rows <- lapply(sort(unique(toupper(source_symbols))), function(symbol) {
    candidates <- du_provider_candidates(symbol)
    matches <- intersect(candidates, available)
    data.frame(
      source_symbol = symbol,
      candidate_symbols = paste(candidates, collapse = ","),
      matched_symbols = paste(matches, collapse = ","),
      match_count = length(matches),
      resolved_symbol = if (length(matches) == 1L) matches[[1L]] else NA_character_,
      identity_status = if (!length(matches)) "NO_HISTORY" else if (length(matches) == 1L) "UNIQUE" else "AMBIGUOUS",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

du_train_coverage <- function(reconciliation, resolutions, bars, calendar_dates, contract = du_contract()) {
  contract <- du_validate_contract(contract)
  calendar_dates <- sort(unique(as.Date(calendar_dates)))
  if (!length(calendar_dates) || min(calendar_dates) < contract$query_start || max(calendar_dates) > contract$query_end) {
    du_stop("TRAIN calendar is outside the frozen audit boundary.")
  }
  bars$session_date <- as.Date(bars$session_date)
  if (any(bars$session_date >= contract$forbidden_start)) du_stop("A 2021+ bar entered the deployment-universe audit.")
  rows <- lapply(seq_len(nrow(reconciliation)), function(i) {
    row <- reconciliation[i, , drop = FALSE]
    source_symbol <- row$source_symbol[[1L]]
    resolved <- if (!is.na(source_symbol)) resolutions[resolutions$source_symbol == source_symbol, , drop = FALSE] else resolutions[FALSE, , drop = FALSE]
    provider_symbol <- if (nrow(resolved) == 1L) resolved$resolved_symbol[[1L]] else NA_character_
    observed <- if (!is.na(provider_symbol)) unique(bars$session_date[bars$symbol == provider_symbol]) else as.Date(character())
    in_window <- calendar_dates[calendar_dates >= contract$query_start & calendar_dates <= contract$query_end]
    data.frame(
      HOLDING_ID = row$HOLDING_ID,
      ISSUER_TITLE = row$ISSUER_TITLE,
      ISSUER_CUSIP = row$ISSUER_CUSIP,
      source_symbol = source_symbol,
      provider_symbol = provider_symbol,
      mapping_method = row$mapping_method,
      sector = row$sector,
      provider_history = length(observed) > 0L,
      expected_sessions = length(in_window),
      observed_sessions = sum(in_window %in% observed),
      complete_train = length(in_window) > 0L && all(in_window %in% observed),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

du_gate_matrix <- function(source_summary, reconciliation, coverage, provenance_ok, source_timing_ok,
                           boundary_ok, contract = du_contract()) {
  contract <- du_validate_contract(contract)
  no_duplicate_identity <- !anyDuplicated(paste(reconciliation$ISSUER_TITLE, reconciliation$ISSUER_CUSIP, sep = "||"))
  no_ambiguous_provider <- !anyDuplicated(coverage$provider_symbol[!is.na(coverage$provider_symbol)])
  provider_fraction <- mean(coverage$provider_history)
  complete_fraction <- mean(coverage$complete_train)
  data.frame(
    gate_id = c(
      "PROVENANCE", "SOURCE_TIMING", "ROSTER_SIZE", "IDENTITY_COMPLETENESS", "ROSTER_AGREEMENT",
      "SECTOR_COVERAGE", "PROVIDER_REPRESENTATION", "COMPLETE_TRAIN_RETENTION", "BOUNDARY_INTEGRITY"
    ),
    passed = c(
      isTRUE(provenance_ok),
      isTRUE(source_timing_ok),
      source_summary$filing_count >= contract$roster_min && source_summary$filing_count <= contract$roster_max,
      source_summary$identity_completeness >= contract$minimum_identity_completeness && no_duplicate_identity && no_ambiguous_provider,
      source_summary$jaccard >= contract$minimum_jaccard,
      source_summary$sector_coverage >= contract$minimum_sector_coverage && source_summary$sector_count >= contract$minimum_sectors,
      provider_fraction >= contract$minimum_provider_representation,
      complete_fraction >= contract$minimum_complete_train_retention,
      isTRUE(boundary_ok)
    ),
    observed = c(
      as.character(isTRUE(provenance_ok)), as.character(isTRUE(source_timing_ok)), as.character(source_summary$filing_count),
      sprintf("%.4f; duplicate_identity=%s; duplicate_provider=%s", source_summary$identity_completeness, !no_duplicate_identity, !no_ambiguous_provider),
      sprintf("%.4f", source_summary$jaccard),
      sprintf("%.4f; sectors=%d", source_summary$sector_coverage, source_summary$sector_count),
      sprintf("%.4f", provider_fraction), sprintf("%.4f", complete_fraction), as.character(isTRUE(boundary_ok))
    ),
    threshold = c(
      "exact accession/revision and nonblank hashes", "all universe sources public before 2021-01-01", "490-510",
      ">=0.98; no duplicate source identity or provider ambiguity", ">=0.97", ">=0.98 and >=10 sectors",
      ">=0.95", ">=0.80", "no 2021+ observations"
    ),
    stringsAsFactors = FALSE
  )
}
