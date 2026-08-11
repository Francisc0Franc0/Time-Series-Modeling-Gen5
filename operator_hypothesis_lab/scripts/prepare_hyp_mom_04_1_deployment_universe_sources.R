options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_deployment_universe_audit.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_sp500_pit_audit.R"))

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

stream_zip_entry <- function(zip_path, entry_name, output_path, keep) {
  input <- unz(zip_path, entry_name, open = "rt", encoding = "UTF-8")
  output <- file(output_path, open = "wt", encoding = "UTF-8")
  on.exit(close(input), add = TRUE)
  on.exit(close(output), add = TRUE)
  header <- readLines(input, n = 1L, warn = FALSE)
  if (length(header) != 1L) du_stop(paste("Archive entry is empty:", entry_name))
  writeLines(header, output, useBytes = TRUE)
  retained <- 0L
  repeat {
    lines <- readLines(input, n = 50000L, warn = FALSE)
    if (!length(lines)) break
    selected <- keep(lines)
    if (length(selected) != length(lines) || anyNA(selected)) du_stop(paste("Invalid source filter for", entry_name))
    if (any(selected)) {
      writeLines(lines[selected], output, useBytes = TRUE)
      retained <- retained + sum(selected)
    }
  }
  retained
}

contract <- du_validate_contract()
source_dir <- env_or(
  "GEN5_H04_DEPLOYMENT_SOURCE_DIR",
  file.path(repo_root, ".cache", "hyp_mom_04_1_deployment_universe")
)
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
archive_path <- file.path(source_dir, contract$sec_bulk_archive_name)
if (!file.exists(archive_path)) {
  options(HTTPUserAgent = "Gen5 HYP-MOM-04.1 research source preparation (contact via repository)")
  utils::download.file(contract$sec_bulk_archive_url, archive_path, mode = "wb", quiet = FALSE)
}

outputs <- c(
  submission = file.path(source_dir, "spy_submission.tsv"),
  fund_info = file.path(source_dir, "spy_fund_reported_info.tsv"),
  holdings = file.path(source_dir, "spy_fund_reported_holding.tsv"),
  identifiers = file.path(source_dir, "spy_identifiers.tsv")
)
entries <- c(submission = "SUBMISSION.tsv", fund_info = "FUND_REPORTED_INFO.tsv", holdings = "FUND_REPORTED_HOLDING.tsv")
for (name in names(entries)) {
  if (!file.exists(outputs[[name]])) {
    retained <- stream_zip_entry(
      archive_path, entries[[name]], outputs[[name]],
      function(lines) du_filter_accession_lines(lines, contract$accession)
    )
    message(entries[[name]], ": retained ", retained, " rows.")
  }
}

holdings <- utils::read.delim(outputs[["holdings"]], check.names = FALSE, stringsAsFactors = FALSE)
if (!file.exists(outputs[["identifiers"]])) {
  retained <- stream_zip_entry(
    archive_path, "IDENTIFIERS.tsv", outputs[["identifiers"]],
    function(lines) du_filter_holding_id_lines(lines, holdings$HOLDING_ID)
  )
  message("IDENTIFIERS.tsv: retained ", retained, " rows.")
}

identifiers <- utils::read.delim(outputs[["identifiers"]], check.names = FALSE, stringsAsFactors = FALSE)
filing <- du_validate_filing(holdings, identifiers, contract)
if (nrow(filing) < contract$roster_min || nrow(filing) > contract$roster_max) {
  du_stop("Prepared filing roster is outside the frozen size range.")
}

wiki_path <- file.path(source_dir, "wikipedia_sp500_2020_09_30.csv")
revision_path <- file.path(source_dir, "wikipedia_revision_ledger.txt")
if (!file.exists(wiki_path) || !file.exists(revision_path)) {
  wiki <- spit_fetch_wikipedia_revision(contract$report_date)
  utils::write.csv(wiki$roster, wiki_path, row.names = FALSE)
  writeLines(c(wiki$revision_id, wiki$revision_timestamp, wiki$query_url, wiki$parse_url), revision_path)
}

cat("Prepared", nrow(filing), "filing equities in", normalizePath(source_dir, winslash = "/", mustWork = TRUE), "\n")
