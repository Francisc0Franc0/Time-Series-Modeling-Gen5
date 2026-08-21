# Gen5 M1-SR1 public-source feasibility audit.
# Outcome blind: no momentum, future return, rank, portfolio, or risk metrics.

options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1L]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "R", "gen5_m1_multicap_public_source_audit.R"))

env_required <- function(name) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) m1sr1_stop(paste(name, "is required."))
  value
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

as_of_timestamp <- env_required("GEN5_M1_SR1_AS_OF_TIMESTAMP")
as_of_value <- as.POSIXct(as_of_timestamp, tz = "America/New_York")
if (is.na(as_of_value)) m1sr1_stop("GEN5_M1_SR1_AS_OF_TIMESTAMP must be an explicit timestamp.")
run_id <- env_required("GEN5_M1_SR1_RUN_ID")
contract <- m1sr1_validate_contract()

source_archive <- Sys.getenv(
  "GEN5_M1_SR1_NPORT_ARCHIVE",
  unset = file.path(repo_root, ".cache", "hyp_mom_04_1_deployment_universe", "2020q4_nport.zip")
)
ishares_cache <- Sys.getenv(
  "GEN5_M1_SR1_ISHARES_CACHE",
  unset = file.path(repo_root, ".cache", "gen5_m1_multicap_public_source")
)
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen5_m1_sr1_public_source_feasibility", run_id)
raw_dir <- file.path(output_dir, "raw_extracts")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(source_archive)) m1sr1_stop("The official 2020 Q4 N-PORT archive is missing.")
acquisition_manifest_path <- file.path(ishares_cache, "acquisition_manifest.csv")
if (!file.exists(acquisition_manifest_path)) m1sr1_stop("Run the current iShares source preparation script first.")
acquisition_manifest <- utils::read.csv(
  acquisition_manifest_path,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8-BOM"
)
if (!all(contract$fund_ticker %in% acquisition_manifest$fund_ticker)) m1sr1_stop("The iShares acquisition manifest is incomplete.")
if (!all(acquisition_manifest$explicit_as_of_timestamp == as_of_timestamp)) {
  m1sr1_stop("The iShares acquisition manifest does not match the explicit audit as-of timestamp.")
}

outputs <- c(
  submissions = file.path(raw_dir, "target_submissions.tsv"),
  fund_info = file.path(raw_dir, "target_fund_reported_info.tsv"),
  holdings = file.path(raw_dir, "target_fund_reported_holding.tsv"),
  identifiers = file.path(raw_dir, "target_identifiers.tsv")
)

message("Extracting three frozen 2020 N-PORT fund snapshots.")
if (!file.exists(outputs[["submissions"]])) {
  m1sr1_stream_zip_entry(
    source_archive, "SUBMISSION.tsv", outputs[["submissions"]],
    function(lines) m1sr1_filter_accession_lines(lines, contract$accession_number)
  )
}
if (!file.exists(outputs[["fund_info"]])) {
  m1sr1_stream_zip_entry(
    source_archive, "FUND_REPORTED_INFO.tsv", outputs[["fund_info"]],
    function(lines) m1sr1_filter_accession_lines(lines, contract$accession_number)
  )
}
if (!file.exists(outputs[["holdings"]])) {
  m1sr1_stream_zip_entry(
    source_archive, "FUND_REPORTED_HOLDING.tsv", outputs[["holdings"]],
    function(lines) m1sr1_filter_accession_lines(lines, contract$accession_number)
  )
}

holdings <- utils::read.delim(outputs[["holdings"]], check.names = FALSE, stringsAsFactors = FALSE)
if (!file.exists(outputs[["identifiers"]])) {
  m1sr1_stream_zip_entry(
    source_archive, "IDENTIFIERS.tsv", outputs[["identifiers"]],
    function(lines) m1sr1_filter_holding_id_lines(lines, holdings$HOLDING_ID)
  )
}

submissions <- utils::read.delim(outputs[["submissions"]], check.names = FALSE, stringsAsFactors = FALSE)
fund_info <- utils::read.delim(outputs[["fund_info"]], check.names = FALSE, stringsAsFactors = FALSE)
identifiers <- utils::read.delim(outputs[["identifiers"]], check.names = FALSE, stringsAsFactors = FALSE)
nport <- m1sr1_validate_nport_extract(submissions, fund_info, holdings, identifiers, contract)
nport_summary <- m1sr1_nport_summary(nport)
overlap_summary <- m1sr1_overlap_summary(nport)
retained_equity <- nport[nport$ASSET_CAT == "EC" & nport$ISSUER_TYPE == "CORP", , drop = FALSE]
retained_equity$security_identifier <- m1sr1_security_key(
  retained_equity$ISSUER_CUSIP,
  retained_equity$IDENTIFIER_ISIN
)
unresolved_identity <- retained_equity[
  is.na(retained_equity$security_identifier),
  c(
    "fund_ticker", "cap_sleeve", "HOLDING_ID", "ISSUER_NAME", "ISSUER_TITLE",
    "ISSUER_LEI", "ISSUER_CUSIP", "IDENTIFIER_ISIN", "IDENTIFIER_TICKER",
    "ASSET_CAT", "ISSUER_TYPE", "INVESTMENT_COUNTRY"
  ),
  drop = FALSE
]

current_rows <- lapply(seq_len(nrow(contract)), function(i) {
  ticker <- contract$fund_ticker[[i]]
  parsed <- m1sr1_read_ishares_holdings(file.path(ishares_cache, paste0(tolower(ticker), "_latest_holdings.csv")))
  m1sr1_current_summary(parsed, ticker, contract$cap_sleeve[[i]])
})
current_summary <- do.call(rbind, current_rows)

archive_hash <- unname(tools::md5sum(source_archive))
extract_manifest <- data.frame(
  artifact_role = c("sec_nport_bulk_archive", rep("sec_nport_target_extract", length(outputs))),
  source_url = c(
    "https://www.sec.gov/files/dera/data/form-n-port-data-sets/2020q4_nport.zip",
    rep("derived from exact accession rows in official SEC bulk archive", length(outputs))
  ),
  local_file = normalizePath(c(source_archive, unname(outputs)), winslash = "/", mustWork = TRUE),
  explicit_as_of_timestamp = as_of_timestamp,
  bytes = file.info(c(source_archive, unname(outputs)))$size,
  md5 = c(archive_hash, unname(tools::md5sum(unname(outputs)))),
  stringsAsFactors = FALSE
)
provenance_ok <- all(nzchar(extract_manifest$md5)) &&
  all(nzchar(acquisition_manifest$sha256)) &&
  all(nzchar(acquisition_manifest$retrieved_at_utc))
gates <- m1sr1_gate_matrix(nport_summary, overlap_summary, current_summary, provenance_ok)
overall_status <- if (all(gates$passed)) {
  "PASS_PUBLIC_SOURCE_AUTHORITY"
} else {
  "STOP_PUBLIC_SOURCE_PARTIAL_IDENTITY_SECTOR_AND_PANEL_GATES_FAILED"
}

run_spec <- data.frame(
  run_id = run_id,
  explicit_as_of_timestamp = as_of_timestamp,
  historical_snapshot = "2020-09-30",
  historical_source = "SEC Form N-PORT 2020 Q4 bulk archive",
  current_source = "official iShares downloadable holdings CSV",
  market_price_source = "not queried",
  momentum_calculation_count = 0L,
  outcome_calculation_count = 0L,
  portfolio_calculation_count = 0L,
  status = overall_status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "m1_sr1_public_source_run_spec.csv"))
write_csv(extract_manifest, file.path(output_dir, "m1_sr1_public_source_manifest.csv"))
write_csv(acquisition_manifest, file.path(output_dir, "m1_sr1_ishares_acquisition_manifest.csv"))
write_csv(contract, file.path(output_dir, "m1_sr1_fund_contract.csv"))
write_csv(nport_summary, file.path(output_dir, "m1_sr1_historical_holdings_summary.csv"))
write_csv(overlap_summary, file.path(output_dir, "m1_sr1_historical_overlap_summary.csv"))
write_csv(unresolved_identity, file.path(output_dir, "m1_sr1_unresolved_identity_ledger.csv"))
write_csv(current_summary, file.path(output_dir, "m1_sr1_current_sector_summary.csv"))
write_csv(gates, file.path(output_dir, "m1_sr1_public_source_health.csv"))

report <- c(
  "# Gen5 M1-SR1 Public-Source Feasibility Audit", "",
  paste0("Status: `", overall_status, "`"), "",
  "## Boundary", "",
  "This packet tests free public membership, identifier, capitalization-sleeve, and classification sources only. It calculates no momentum, future return, rank correlation, PnL, Sharpe, drawdown, portfolio, or live advice.", "",
  "## What worked", "",
  "- The official SEC 2020 Q4 N-PORT archive resolves exact September 30, 2020 filings for IWL, IWR, and IWM.",
  paste0("- Retained common-equity counts: ", paste(paste0(nport_summary$fund_ticker, " `", nport_summary$retained_common_equity, "`"), collapse = "; "), "."),
  paste0("- Minimum retained combined CUSIP/ISIN coverage: `", sprintf("%.2f%%", 100 * min(nport_summary$security_identifier_coverage)), "`; maximum pairwise stable-ID cross-sleeve overlap: `", max(overlap_summary$security_identifier_overlap), "`."),
  paste0("- Minimum stable issuer LEI coverage: `", sprintf("%.2f%%", 100 * min(nport_summary$issuer_lei_coverage)), "`."),
  paste0("- Current official iShares files expose at least `", min(current_summary$sector_count), "` named sectors with minimum equity-row sector coverage `", sprintf("%.2f%%", 100 * min(current_summary$sector_coverage)), "`."), "",
  "## What did not pass", "",
  paste0("- Combined CUSIP/ISIN identity coverage bottoms at `", sprintf("%.2f%%", 100 * min(nport_summary$security_identifier_coverage)), "`; unresolved retained security rows: `", sum(nport_summary$unresolved_security_identifier), "`."),
  "- Historical N-PORT holdings contain security identifiers and sleeve membership but no investment-sector field. Current iShares sector labels cannot be backfilled into 2020.",
  "- Only one representative historical quarter is locally available. The full 2019+ quarterly three-fund panel has not been acquired and audited.",
  "- Direct command-line SEC access returned HTTP 403; the in-app browser reached the official dataset page, but the additional classification archive did not complete within the bounded audit attempt.", "",
  "## Decision", "",
  "Preserve `STOP_PUBLIC_SOURCE_PARTIAL_IDENTITY_SECTOR_AND_PANEL_GATES_FAILED`. The free route is credible for capitalization sleeves and nearly complete historical security membership, but it is not yet a complete identity or point-in-time sector authority. Do not substitute current sectors, calculate momentum, or inspect returns.", "",
  "## Artifacts", "",
  "- `m1_sr1_public_source_run_spec.csv`",
  "- `m1_sr1_public_source_manifest.csv`",
  "- `m1_sr1_historical_holdings_summary.csv`",
  "- `m1_sr1_historical_overlap_summary.csv`",
  "- `m1_sr1_unresolved_identity_ledger.csv`",
  "- `m1_sr1_current_sector_summary.csv`",
  "- `m1_sr1_public_source_health.csv`"
)
writeLines(report, file.path(output_dir, "m1_sr1_public_source_report.md"), useBytes = TRUE)

message("M1-SR1 public-source feasibility audit complete: ", overall_status)
message("Report: ", normalizePath(file.path(output_dir, "m1_sr1_public_source_report.md"), winslash = "/", mustWork = TRUE))
