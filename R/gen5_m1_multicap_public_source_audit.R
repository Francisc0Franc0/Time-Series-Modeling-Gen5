# Outcome-blind helpers for the Gen5 M1-SR1 public-source feasibility audit.

m1sr1_stop <- function(message) stop(message, call. = FALSE)

m1sr1_public_source_contract <- function() {
  data.frame(
    fund_ticker = c("IWL", "IWR", "IWM"),
    cap_sleeve = c("large", "mid", "small"),
    series_name = c(
      "iShares Russell Top 200 ETF",
      "iShares Russell Mid-Cap ETF",
      "iShares Russell 2000 ETF"
    ),
    series_id = c("S000026553", "S000004338", "S000004344"),
    accession_number = c(
      "0001752724-20-247698",
      "0001752724-20-247719",
      "0001752724-20-247680"
    ),
    report_date = as.Date(rep("2020-09-30", 3L)),
    filing_date = as.Date(rep("2020-11-25", 3L)),
    current_holdings_url = c(
      "https://www.ishares.com/us/products/239721/ishares-russell-top-200-etf/latest-holdings.csv",
      "https://www.ishares.com/us/products/239718/ishares-russell-mid-cap-etf/latest-holdings.csv",
      "https://www.ishares.com/us/products/239710/ishares-russell-2000-etf/latest-holdings.csv"
    ),
    stringsAsFactors = FALSE
  )
}

m1sr1_validate_contract <- function(contract = m1sr1_public_source_contract()) {
  frozen <- m1sr1_public_source_contract()
  if (!identical(names(contract), names(frozen)) || nrow(contract) != nrow(frozen)) {
    m1sr1_stop("The frozen M1-SR1 public-source contract shape changed.")
  }
  same <- vapply(names(frozen), function(name) identical(contract[[name]], frozen[[name]]), logical(1L))
  if (!all(same)) {
    m1sr1_stop(paste("The frozen M1-SR1 public-source contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  }
  contract
}

m1sr1_filter_accession_lines <- function(lines, accessions) {
  first_field <- sub("\t.*$", "", as.character(lines))
  first_field %in% as.character(accessions)
}

m1sr1_filter_holding_id_lines <- function(lines, holding_ids) {
  first_field <- sub("\t.*$", "", as.character(lines))
  first_field %in% as.character(holding_ids)
}

m1sr1_valid_cusip <- function(x) {
  x <- toupper(trimws(as.character(x)))
  !is.na(x) & grepl("^[A-Z0-9]{9}$", x) & x != "000000000"
}

m1sr1_valid_isin <- function(x) {
  x <- toupper(trimws(as.character(x)))
  !is.na(x) & grepl("^[A-Z0-9]{12}$", x) & x != "000000000000"
}

m1sr1_security_key <- function(cusip, isin) {
  cusip <- toupper(trimws(as.character(cusip)))
  isin <- toupper(trimws(as.character(isin)))
  out <- rep(NA_character_, length(cusip))
  use_cusip <- m1sr1_valid_cusip(cusip)
  use_isin <- !use_cusip & m1sr1_valid_isin(isin)
  out[use_cusip] <- paste0("CUSIP:", cusip[use_cusip])
  out[use_isin] <- paste0("ISIN:", isin[use_isin])
  out
}

m1sr1_stream_zip_entry <- function(zip_path, entry_name, output_path, keep) {
  if (!file.exists(zip_path)) m1sr1_stop(paste("Missing source archive:", zip_path))
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  input <- unz(zip_path, entry_name, open = "rt", encoding = "UTF-8")
  output <- file(output_path, open = "wt", encoding = "UTF-8")
  on.exit(close(input), add = TRUE)
  on.exit(close(output), add = TRUE)
  header <- readLines(input, n = 1L, warn = FALSE)
  if (length(header) != 1L) m1sr1_stop(paste("Archive entry is empty:", entry_name))
  writeLines(header, output, useBytes = TRUE)
  retained <- 0L
  repeat {
    lines <- readLines(input, n = 50000L, warn = FALSE)
    if (!length(lines)) break
    selected <- keep(lines)
    if (length(selected) != length(lines) || anyNA(selected)) {
      m1sr1_stop(paste("Invalid source filter for", entry_name))
    }
    if (any(selected)) {
      writeLines(lines[selected], output, useBytes = TRUE)
      retained <- retained + sum(selected)
    }
  }
  retained
}

m1sr1_read_ishares_holdings <- function(path) {
  if (!file.exists(path)) m1sr1_stop(paste("Missing iShares holdings file:", path))
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (length(lines)) lines[[1L]] <- sub("^\ufeff", "", lines[[1L]])
  header_at <- grep("^Ticker,Name,Sector,Asset Class", lines)
  if (length(header_at) != 1L) m1sr1_stop("The iShares holdings CSV has an unexpected header.")
  metadata <- lines[seq_len(header_at - 1L)]
  as_of_line <- grep("^Fund Holdings as of,", metadata, value = TRUE)
  if (length(as_of_line) != 1L) m1sr1_stop("The iShares holdings CSV is missing its as-of date.")
  as_of_text <- sub("^Fund Holdings as of,", "", as_of_line)
  as_of_text <- gsub('"', "", as_of_text, fixed = TRUE)
  holdings <- utils::read.csv(
    text = paste(lines[header_at:length(lines)], collapse = "\n"),
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = c("", "-", "NA")
  )
  required <- c("Ticker", "Name", "Sector", "Asset Class")
  if (!all(required %in% names(holdings))) m1sr1_stop("The iShares holdings CSV is missing required fields.")
  list(
    fund_name = trimws(metadata[[1L]]),
    holdings_as_of = as.Date(as_of_text, format = "%b %d, %Y"),
    holdings = holdings
  )
}

m1sr1_validate_nport_extract <- function(submissions, fund_info, holdings, identifiers,
                                         contract = m1sr1_public_source_contract()) {
  contract <- m1sr1_validate_contract(contract)
  required_submission <- c("ACCESSION_NUMBER", "FILING_DATE", "SUB_TYPE", "REPORT_DATE")
  required_fund <- c("ACCESSION_NUMBER", "SERIES_NAME", "SERIES_ID")
  required_holding <- c(
    "ACCESSION_NUMBER", "HOLDING_ID", "ISSUER_NAME", "ISSUER_LEI", "ISSUER_TITLE",
    "ISSUER_CUSIP", "ASSET_CAT", "ISSUER_TYPE", "INVESTMENT_COUNTRY"
  )
  required_identifier <- c("HOLDING_ID", "IDENTIFIER_ISIN", "IDENTIFIER_TICKER")
  checks <- list(
    submissions = all(required_submission %in% names(submissions)),
    fund_info = all(required_fund %in% names(fund_info)),
    holdings = all(required_holding %in% names(holdings)),
    identifiers = all(required_identifier %in% names(identifiers))
  )
  if (!all(unlist(checks))) m1sr1_stop("The N-PORT extract has an unexpected schema.")
  if (anyDuplicated(holdings$HOLDING_ID)) m1sr1_stop("N-PORT holding IDs are not unique.")
  if (anyDuplicated(identifiers$HOLDING_ID)) m1sr1_stop("N-PORT identifier holding IDs are not unique.")

  fund_rows <- merge(
    contract,
    fund_info,
    by.x = c("accession_number", "series_name", "series_id"),
    by.y = c("ACCESSION_NUMBER", "SERIES_NAME", "SERIES_ID"),
    all.x = TRUE,
    sort = FALSE
  )
  if (nrow(fund_rows) != nrow(contract) || anyNA(fund_rows$fund_ticker)) {
    m1sr1_stop("The three frozen iShares series did not resolve exactly.")
  }
  submission_rows <- submissions[submissions$ACCESSION_NUMBER %in% contract$accession_number, , drop = FALSE]
  if (nrow(submission_rows) != nrow(contract)) m1sr1_stop("The three frozen submissions did not resolve exactly.")
  expected_reports <- contract$report_date[match(submission_rows$ACCESSION_NUMBER, contract$accession_number)]
  observed_reports <- as.Date(submission_rows$REPORT_DATE, format = "%d-%b-%Y")
  if (anyNA(observed_reports) || !all(observed_reports == expected_reports)) {
    m1sr1_stop("A frozen N-PORT report date changed.")
  }
  if (!all(submission_rows$SUB_TYPE %in% c("NPORT-P", "NPORT-P/A"))) m1sr1_stop("Unexpected N-PORT submission type.")

  merged <- merge(holdings, identifiers[, required_identifier, drop = FALSE], by = "HOLDING_ID", all.x = TRUE, sort = FALSE)
  merged <- merged[match(holdings$HOLDING_ID, merged$HOLDING_ID), , drop = FALSE]
  merged$fund_ticker <- contract$fund_ticker[match(merged$ACCESSION_NUMBER, contract$accession_number)]
  merged$cap_sleeve <- contract$cap_sleeve[match(merged$ACCESSION_NUMBER, contract$accession_number)]
  if (anyNA(merged$fund_ticker)) m1sr1_stop("A retained holding falls outside the frozen fund accessions.")
  merged
}

m1sr1_nport_summary <- function(nport) {
  rows <- lapply(split(nport, nport$fund_ticker), function(x) {
    equity <- x$ASSET_CAT == "EC" & x$ISSUER_TYPE == "CORP"
    retained <- x[equity, , drop = FALSE]
    valid_cusip <- m1sr1_valid_cusip(retained$ISSUER_CUSIP)
    valid_isin <- m1sr1_valid_isin(retained$IDENTIFIER_ISIN)
    security_key <- m1sr1_security_key(retained$ISSUER_CUSIP, retained$IDENTIFIER_ISIN)
    data.frame(
      fund_ticker = x$fund_ticker[[1L]],
      cap_sleeve = x$cap_sleeve[[1L]],
      reported_holdings = nrow(x),
      retained_common_equity = nrow(retained),
      valid_cusip_coverage = if (nrow(retained)) mean(valid_cusip) else 0,
      placeholder_cusip_count = if (nrow(retained)) sum(!valid_cusip) else 0L,
      security_identifier_coverage = if (nrow(retained)) mean(!is.na(security_key)) else 0,
      unresolved_security_identifier = if (nrow(retained)) sum(is.na(security_key)) else 0L,
      issuer_lei_coverage = if (nrow(retained)) mean(!is.na(retained$ISSUER_LEI) & nzchar(trimws(retained$ISSUER_LEI))) else 0,
      isin_coverage = if (nrow(retained)) mean(valid_isin) else 0,
      ticker_coverage = if (nrow(retained)) mean(!is.na(retained$IDENTIFIER_TICKER) & nzchar(trimws(retained$IDENTIFIER_TICKER))) else 0,
      duplicate_security_identifier = sum(duplicated(security_key[!is.na(security_key)])),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

m1sr1_overlap_summary <- function(nport) {
  equity <- nport[nport$ASSET_CAT == "EC" & nport$ISSUER_TYPE == "CORP", , drop = FALSE]
  funds <- sort(unique(equity$fund_ticker))
  pairs <- utils::combn(funds, 2L, simplify = FALSE)
  do.call(rbind, lapply(pairs, function(pair) {
    security_key <- m1sr1_security_key(equity$ISSUER_CUSIP, equity$IDENTIFIER_ISIN)
    left <- unique(security_key[equity$fund_ticker == pair[[1L]] & !is.na(security_key)])
    right <- unique(security_key[equity$fund_ticker == pair[[2L]] & !is.na(security_key)])
    data.frame(
      left_fund = pair[[1L]],
      right_fund = pair[[2L]],
      security_identifier_overlap = length(intersect(left, right)),
      stringsAsFactors = FALSE
    )
  }))
}

m1sr1_current_summary <- function(parsed, fund_ticker, cap_sleeve) {
  x <- parsed$holdings
  equity <- x$`Asset Class` == "Equity"
  retained <- x[equity, , drop = FALSE]
  data.frame(
    fund_ticker = fund_ticker,
    cap_sleeve = cap_sleeve,
    holdings_as_of = parsed$holdings_as_of,
    reported_rows = nrow(x),
    retained_equity_rows = nrow(retained),
    ticker_coverage = if (nrow(retained)) mean(!is.na(retained$Ticker) & nzchar(trimws(retained$Ticker))) else 0,
    sector_coverage = if (nrow(retained)) mean(!is.na(retained$Sector) & nzchar(trimws(retained$Sector))) else 0,
    sector_count = length(unique(retained$Sector[!is.na(retained$Sector) & nzchar(trimws(retained$Sector))])),
    stringsAsFactors = FALSE
  )
}

m1sr1_gate_matrix <- function(nport_summary, overlap_summary, current_summary, provenance_ok) {
  historical_identity_ok <- all(nport_summary$security_identifier_coverage == 1) &&
    all(nport_summary$duplicate_security_identifier == 0)
  issuer_identity_ok <- all(nport_summary$issuer_lei_coverage == 1)
  current_sector_ok <- all(current_summary$sector_coverage >= 0.98) && all(current_summary$sector_count >= 10L)
  no_overlap <- all(overlap_summary$security_identifier_overlap == 0L)
  data.frame(
    gate_id = c(
      "P1_PROVENANCE", "P2_FUND_RESOLUTION", "P3_SECURITY_IDENTITY", "P4_ISSUER_IDENTITY",
      "P5_CAP_SLEEVE_SEPARATION", "P6_CURRENT_SECTOR_SCHEMA", "P7_HISTORICAL_SECTOR_AUTHORITY",
      "P8_LONGITUDINAL_PANEL", "P9_OUTCOME_BOUNDARY"
    ),
    passed = c(
      isTRUE(provenance_ok), TRUE, historical_identity_ok, issuer_identity_ok,
      no_overlap, current_sector_ok, FALSE, FALSE, TRUE
    ),
    observed = c(
      as.character(isTRUE(provenance_ok)),
      "3 / 3 exact SEC series and accessions",
      sprintf("minimum combined CUSIP/ISIN coverage %.4f; unresolved %d; duplicates %d", min(nport_summary$security_identifier_coverage), sum(nport_summary$unresolved_security_identifier), sum(nport_summary$duplicate_security_identifier)),
      sprintf("minimum LEI coverage %.4f", min(nport_summary$issuer_lei_coverage)),
      sprintf("maximum pairwise stable-ID overlap %d", max(overlap_summary$security_identifier_overlap)),
      sprintf("minimum current sector coverage %.4f; minimum sectors %d", min(current_summary$sector_coverage), min(current_summary$sector_count)),
      "N-PORT has no sector field; current iShares labels cannot be backfilled",
      "one historical quarter sampled; full 2019+ quarterly panel not acquired",
      "momentum, returns, ranks, PnL, Sharpe, and drawdown fields absent"
    ),
    requirement = c(
      "exact URLs/files, retrieval timestamps, hashes, explicit as-of",
      "3 / 3 exact fund series",
      "100% retained security IDs; no duplicates",
      "100% retained stable issuer IDs",
      "no cross-sleeve security overlap",
      ">=98% contemporaneous labels and >=10 sectors",
      "effective-dated historical investment-peer taxonomy",
      "representative quarterly coverage across proposed window",
      "no outcome calculation"
    ),
    stringsAsFactors = FALSE
  )
}
