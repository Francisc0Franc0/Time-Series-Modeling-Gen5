# Gen5.4 research-only SEC fundamentals F0 feasibility audit.
# No outcomes, predictive features, model fitting, or live-facing behavior.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "sec_edgar_provider.R"))

run_id <- Sys.getenv("GEN5_GEN54_SEC_F0_RUN_ID", unset = "g54_sec_f0_20260719")
as_of_text <- Sys.getenv("GEN5_GEN54_SEC_F0_AS_OF", unset = "2024-12-31 17:30:00")
as_of_ny <- as.POSIXct(as_of_text, tz = "America/New_York")
if (is.na(as_of_ny)) stop("GEN5_GEN54_SEC_F0_AS_OF must be an explicit timestamp.", call. = FALSE)
as_of_utc <- as.POSIXct(format(as_of_ny, tz = "UTC", usetz = TRUE), tz = "UTC")

output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id)
raw_dir <- file.path(output_dir, "raw")
visual_dir <- file.path(output_dir, "visuals")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

registry <- data.frame(
  symbol = c("AAPL", "AMD", "JPM", "WMT", "MSTR"),
  cik = c("0000320193", "0000002488", "0000019617", "0000104169", "0001050446"),
  audit_role = c("non_calendar_platform", "semiconductor", "financial", "non_calendar_retail", "special_situation"),
  stringsAsFactors = FALSE
)

concept_map <- data.frame(
  concept_family = c(
    "revenue", "revenue", "revenue", "operating_income", "net_income",
    "net_income", "operating_cash_flow", "assets", "liabilities", "diluted_shares"
  ),
  concept = c(
    "RevenueFromContractWithCustomerExcludingAssessedTax", "Revenues", "SalesRevenueNet",
    "OperatingIncomeLoss", "NetIncomeLoss", "ProfitLoss",
    "NetCashProvidedByUsedInOperatingActivities", "Assets", "Liabilities",
    "WeightedAverageNumberOfDilutedSharesOutstanding"
  ),
  stringsAsFactors = FALSE
)

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

stop_with_access_report <- function(message_text) {
  status <- "BLOCKED_EXTERNAL_SEC_ACCESS"
  write_csv(
    data.frame(
      as_of_timestamp = as_of_text,
      model_fit_count = 0L,
      outcome_calculation_count = 0L,
      status = status,
      stringsAsFactors = FALSE
    ),
    file.path(output_dir, "sec_f0_run_spec.csv")
  )
  writeLines(c(
    "# Gen5.4 SEC Fundamentals F0 Feasibility Audit", "",
    paste0("Status: `", status, "`"), "",
    "## Boundary", "",
    "No filing or fundamental data was accepted into research authority. No outcomes, predictive features, IC, portfolio returns, or models were computed.", "",
    "## External blocker", "",
    paste0("- SEC request failure: `", gsub("`", "'", message_text, fixed = TRUE), "`."),
    "- The request used a contact-bearing user agent and a conservative request rate.",
    "- A direct command-line header check also returned Akamai HTTP 403 from this environment.", "",
    "## STOP", "",
    "Do not substitute an unofficial mirror or a current-snapshot fundamentals vendor. Retry from a compliant network path or obtain SEC bulk files through an operator-controlled download, then rerun this frozen audit."
  ), file.path(output_dir, "sec_f0_report.md"), useBytes = TRUE)
  stop(paste0(status, ": ", message_text), call. = FALSE)
}

normalize_submission <- function(x, symbol, cik) {
  x <- g5_sec_submission_frame(x)
  if (!nrow(x)) return(x)
  required <- c("accessionNumber", "filingDate", "reportDate", "acceptanceDateTime", "act", "form", "fileNumber", "filmNumber", "items", "size", "isXBRL", "isInlineXBRL", "primaryDocument", "primaryDocDescription")
  for (name in setdiff(required, names(x))) x[[name]] <- NA
  x$symbol <- symbol
  x$cik <- cik
  x$acceptance_timestamp_utc <- g5_sec_parse_acceptance(x$acceptanceDateTime)
  x
}

raw_manifest <- list()
filing_rows <- list()
fact_rows <- list()
manifest_index <- filing_index <- fact_index <- 0L
user_agent <- g5_sec_default_user_agent()

message("Gen5.4 SEC fundamentals F0 starting.")
for (i in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[i]]
  cik <- registry$cik[[i]]
  message("Fetching SEC sample: ", symbol)

  submissions_path <- file.path(raw_dir, paste0(symbol, "_submissions.json"))
  companyfacts_path <- file.path(raw_dir, paste0(symbol, "_companyfacts.json"))
  urls <- c(g5_sec_url("submissions", cik), g5_sec_url("companyfacts", cik))
  paths <- c(submissions_path, companyfacts_path)
  for (j in seq_along(urls)) {
    tryCatch(
      g5_sec_fetch_json(urls[[j]], paths[[j]], user_agent),
      error = function(e) stop_with_access_report(conditionMessage(e))
    )
    manifest_index <- manifest_index + 1L
    raw_manifest[[manifest_index]] <- data.frame(
      symbol = symbol, cik = cik, request_url = urls[[j]], local_file = normalizePath(paths[[j]], winslash = "/"),
      retrieved_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
      bytes = file.info(paths[[j]])$size, md5 = unname(tools::md5sum(paths[[j]])), stringsAsFactors = FALSE
    )
    Sys.sleep(0.15)
  }

  submissions <- g5_sec_read_json(submissions_path, simplify = TRUE)
  recent <- normalize_submission(submissions$filings$recent, symbol, cik)
  all_submissions <- list(recent)
  history_files <- submissions$filings$files
  if (is.data.frame(history_files) && nrow(history_files)) {
    for (file_name in history_files$name) {
      history_path <- file.path(raw_dir, paste0(symbol, "_", file_name))
      history_url <- g5_sec_url("submissions_file", file_name = file_name)
      tryCatch(
        g5_sec_fetch_json(history_url, history_path, user_agent),
        error = function(e) stop_with_access_report(conditionMessage(e))
      )
      manifest_index <- manifest_index + 1L
      raw_manifest[[manifest_index]] <- data.frame(
        symbol = symbol, cik = cik, request_url = history_url, local_file = normalizePath(history_path, winslash = "/"),
        retrieved_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
        bytes = file.info(history_path)$size, md5 = unname(tools::md5sum(history_path)), stringsAsFactors = FALSE
      )
      history <- g5_sec_read_json(history_path, simplify = TRUE)
      all_submissions[[length(all_submissions) + 1L]] <- normalize_submission(history, symbol, cik)
      Sys.sleep(0.15)
    }
  }
  symbol_filings <- do.call(rbind, all_submissions)
  symbol_filings <- symbol_filings[
    symbol_filings$form %in% c("10-Q", "10-K", "10-Q/A", "10-K/A") &
      !is.na(symbol_filings$acceptance_timestamp_utc) &
      symbol_filings$acceptance_timestamp_utc <= as_of_utc &
      as.Date(symbol_filings$filingDate) >= as.Date("2018-01-01"), , drop = FALSE
  ]
  filing_index <- filing_index + 1L
  filing_rows[[filing_index]] <- symbol_filings

  companyfacts <- g5_sec_read_json(companyfacts_path, simplify = FALSE)
  symbol_facts <- g5_sec_companyfacts_long(companyfacts, symbol, cik)
  if (nrow(symbol_facts)) {
    symbol_facts <- merge(symbol_facts, concept_map, by = "concept", all.x = FALSE, all.y = FALSE)
    symbol_facts <- symbol_facts[symbol_facts$accn %in% symbol_filings$accessionNumber, , drop = FALSE]
    fact_index <- fact_index + 1L
    fact_rows[[fact_index]] <- symbol_facts
  }
}

filings <- do.call(rbind, filing_rows)
facts <- if (length(fact_rows)) do.call(rbind, fact_rows) else data.frame()
manifest <- do.call(rbind, raw_manifest)
filings$is_amendment <- grepl("/A$", filings$form)
filings$filing_year <- format(as.Date(filings$filingDate), "%Y")

coverage_rows <- lapply(registry$symbol, function(symbol) {
  sf <- filings[filings$symbol == symbol & !filings$is_amendment, , drop = FALSE]
  lapply(unique(concept_map$concept_family), function(family) {
    accessions <- if (nrow(facts)) unique(facts$accn[facts$symbol == symbol & facts$concept_family == family]) else character()
    data.frame(
      symbol = symbol, concept_family = family, eligible_filings = nrow(sf),
      covered_filings = sum(sf$accessionNumber %in% accessions),
      coverage_ratio = if (nrow(sf)) mean(sf$accessionNumber %in% accessions) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
})
coverage <- do.call(rbind, unlist(coverage_rows, recursive = FALSE))

duplicates <- if (nrow(facts)) {
  key <- paste(facts$symbol, facts$accn, facts$concept_family, facts$end, facts$unit, sep = "|")
  counts <- table(key)
  data.frame(key = names(counts[counts > 1L]), duplicate_rows = as.integer(counts[counts > 1L]), stringsAsFactors = FALSE)
} else data.frame(key = character(), duplicate_rows = integer())

sample_summary <- do.call(rbind, lapply(registry$symbol, function(symbol) {
  sf <- filings[filings$symbol == symbol, , drop = FALSE]
  sc <- coverage[coverage$symbol == symbol, , drop = FALSE]
  data.frame(
    symbol = symbol,
    filing_count = nrow(sf),
    exact_acceptance_ratio = if (nrow(sf)) mean(!is.na(sf$acceptance_timestamp_utc)) else 0,
    concept_families_at_75pct = sum(sc$coverage_ratio >= 0.75, na.rm = TRUE),
    amendments = sum(sf$is_amendment),
    sample_status = if (nrow(sf) >= 20L && sum(sc$coverage_ratio >= 0.75, na.rm = TRUE) >= 3L) "PASS" else "REVIEW_REQUIRED",
    stringsAsFactors = FALSE
  )
}))

timestamp_pass <- nrow(filings) > 0L && all(!is.na(filings$acceptance_timestamp_utc))
sample_pass_count <- sum(sample_summary$sample_status == "PASS")
overall_status <- if (!timestamp_pass) "STOP_TIMESTAMP_RECONSTRUCTION" else if (sample_pass_count >= 4L) "PASS_TO_FULL_PANEL_INGESTION_DESIGN" else "REVIEW_REQUIRED_CONCEPT_COVERAGE"

write_csv(registry, file.path(output_dir, "sec_f0_symbol_cik_registry.csv"))
write_csv(manifest, file.path(output_dir, "sec_f0_raw_manifest.csv"))
write_csv(filings, file.path(output_dir, "sec_f0_filing_manifest.csv"))
write_csv(coverage, file.path(output_dir, "sec_f0_concept_coverage.csv"))
write_csv(duplicates, file.path(output_dir, "sec_f0_duplicate_fact_audit.csv"))
write_csv(sample_summary, file.path(output_dir, "sec_f0_sample_summary.csv"))
write_csv(data.frame(as_of_timestamp = as_of_text, model_fit_count = 0L, outcome_calculation_count = 0L, status = overall_status), file.path(output_dir, "sec_f0_run_spec.csv"))

png(file.path(visual_dir, "sec_f0_filing_timeline.png"), width = 1500, height = 850, res = 150)
par(mar = c(5, 7, 3, 2))
symbol_y <- match(filings$symbol, rev(registry$symbol))
plot(as.Date(filings$filingDate), symbol_y, pch = ifelse(filings$form %in% c("10-K", "10-K/A"), 17, 16),
     col = ifelse(filings$is_amendment, "#D97706", "#2563EB"), yaxt = "n", ylab = "", xlab = "SEC filing date",
     main = "F0 filing timeline — acceptance metadata audited before any feature use")
axis(2, at = seq_along(registry$symbol), labels = rev(registry$symbol), las = 1)
grid(nx = NA, ny = NULL, col = "#E5E7EB")
legend("bottomright", legend = c("10-Q", "10-K", "amendment"), pch = c(16, 17, 16), col = c("#2563EB", "#2563EB", "#D97706"), bty = "n")
dev.off()

families <- unique(concept_map$concept_family)
matrix_values <- matrix(NA_real_, nrow = length(registry$symbol), ncol = length(families), dimnames = list(registry$symbol, families))
for (i in seq_len(nrow(coverage))) matrix_values[coverage$symbol[[i]], coverage$concept_family[[i]]] <- coverage$coverage_ratio[[i]]
png(file.path(visual_dir, "sec_f0_concept_coverage_heatmap.png"), width = 1500, height = 900, res = 150)
par(mar = c(9, 7, 3, 2))
image(seq_len(ncol(matrix_values)), seq_len(nrow(matrix_values)), t(matrix_values), zlim = c(0, 1),
      col = colorRampPalette(c("#FEE2E2", "#FEF3C7", "#DCFCE7", "#166534"))(100), axes = FALSE,
      xlab = "", ylab = "", main = "Candidate concept coverage across as-known 10-Q / 10-K filings")
axis(1, at = seq_len(ncol(matrix_values)), labels = colnames(matrix_values), las = 2)
axis(2, at = seq_len(nrow(matrix_values)), labels = rownames(matrix_values), las = 1)
for (x in seq_len(ncol(matrix_values))) for (y in seq_len(nrow(matrix_values))) {
  value <- matrix_values[y, x]
  text(x, y, if (is.na(value)) "NA" else sprintf("%.0f%%", 100 * value), cex = 0.8)
}
dev.off()

report <- c(
  "# Gen5.4 SEC Fundamentals F0 Feasibility Audit", "",
  paste0("Status: `", overall_status, "`"), "",
  "## Boundary", "",
  "This packet audits filing timestamps, provenance, amendments, and candidate concept coverage only. It computes no outcomes, predictive features, IC, portfolio returns, or models.", "",
  "## Sample readout", "",
  paste0("- Explicit research as-of: `", as_of_text, " America/New_York`."),
  paste0("- Sample companies passing the frozen coverage gate: `", sample_pass_count, " / 5`."),
  paste0("- Filing rows: `", nrow(filings), "`; candidate fact rows: `", nrow(facts), "`; duplicate fact keys exposed: `", nrow(duplicates), "`."),
  paste0("- Exact acceptance timestamps: `", if (timestamp_pass) "PASS" else "FAIL", "`."), "",
  "## Company statuses", "",
  unlist(lapply(seq_len(nrow(sample_summary)), function(i) paste0("- `", sample_summary$symbol[[i]], "`: `", sample_summary$sample_status[[i]], "`; filings `", sample_summary$filing_count[[i]], "`; concept families >=75% `", sample_summary$concept_families_at_75pct[[i]], "`; amendments `", sample_summary$amendments[[i]], "`."))), "",
  "## Next gate", "",
  if (identical(overall_status, "PASS_TO_FULL_PANEL_INGESTION_DESIGN")) "The sample supports designing, but not yet implementing, a full-panel point-in-time ingestion contract." else "Stop or revise the data contract before any full-panel ingestion or predictive measurement.", "",
  "## Human-facing visuals", "",
  "- `visuals/sec_f0_filing_timeline.png`", "- `visuals/sec_f0_concept_coverage_heatmap.png`"
)
writeLines(report, file.path(output_dir, "sec_f0_report.md"), useBytes = TRUE)
message("Gen5.4 SEC fundamentals F0 complete: ", overall_status)
message("Report: ", normalizePath(file.path(output_dir, "sec_f0_report.md"), winslash = "/"))
