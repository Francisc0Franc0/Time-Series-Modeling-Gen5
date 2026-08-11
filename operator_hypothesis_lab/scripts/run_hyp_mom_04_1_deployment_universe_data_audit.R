options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_deployment_universe_audit.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract <- du_validate_contract()
run_id <- env_or("GEN5_H04_DEPLOYMENT_AUDIT_RUN_ID", "hyp_mom_04_1_deployment_universe_data_audit_20260811")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
source_dir <- file.path(output_dir, "sources")
visual_dir <- file.path(output_dir, "visuals")
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

input_dir <- normalizePath(
  env_or("GEN5_H04_DEPLOYMENT_SOURCE_DIR", file.path(repo_root, ".cache", "hyp_mom_04_1_deployment_universe")),
  winslash = "/", mustWork = TRUE
)
input_paths <- c(
  bulk_archive = file.path(input_dir, contract$sec_bulk_archive_name),
  submission = file.path(input_dir, "spy_submission.tsv"),
  fund_info = file.path(input_dir, "spy_fund_reported_info.tsv"),
  holdings = file.path(input_dir, "spy_fund_reported_holding.tsv"),
  identifiers = file.path(input_dir, "spy_identifiers.tsv"),
  wikipedia_roster = file.path(input_dir, "wikipedia_sp500_2020_09_30.csv"),
  wikipedia_revision = file.path(input_dir, "wikipedia_revision_ledger.txt"),
  source_crosswalk = file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_04_1_spy_2020_09_source_crosswalk.csv")
)
missing_inputs <- names(input_paths)[!file.exists(input_paths)]
if (length(missing_inputs)) du_stop(paste("Missing deployment-universe source inputs:", paste(missing_inputs, collapse = ", ")))

submission <- utils::read.delim(input_paths[["submission"]], check.names = FALSE, stringsAsFactors = FALSE)
if (nrow(submission) != 1L || submission$ACCESSION_NUMBER[[1L]] != contract$accession) du_stop("Submission extract does not contain exactly the frozen accession.")
if (as.Date(submission$REPORT_DATE[[1L]], format = "%d-%b-%Y") != contract$report_date) du_stop("Submission report date changed.")
holdings <- utils::read.delim(input_paths[["holdings"]], check.names = FALSE, stringsAsFactors = FALSE)
identifiers <- utils::read.delim(input_paths[["identifiers"]], check.names = FALSE, stringsAsFactors = FALSE)
filing <- du_validate_filing(holdings, identifiers, contract)
wikipedia <- utils::read.csv(input_paths[["wikipedia_roster"]], stringsAsFactors = FALSE)
crosswalk <- utils::read.csv(input_paths[["source_crosswalk"]], stringsAsFactors = FALSE)
reconciliation <- du_reconcile_sources(filing, wikipedia, crosswalk)
source_summary <- du_source_summary(reconciliation, wikipedia)

copied_names <- names(input_paths)[names(input_paths) != "bulk_archive"]
copied_paths <- file.path(source_dir, basename(input_paths[copied_names]))
for (i in seq_along(copied_names)) {
  if (!file.exists(copied_paths[[i]]) && !file.copy(input_paths[[copied_names[[i]]]], copied_paths[[i]], overwrite = FALSE)) {
    du_stop(paste("Could not retain source extract", copied_names[[i]]))
  }
}
ledger_paths <- c(input_paths[["bulk_archive"]], copied_paths)
source_ledger <- data.frame(
  role = c("SEC_Q4_BULK_ARCHIVE", toupper(copied_names)),
  source_url = c(
    contract$sec_bulk_archive_url,
    contract$sec_index_url,
    contract$sec_index_url,
    contract$sec_primary_document_url,
    contract$sec_primary_document_url,
    paste0("https://en.wikipedia.org/w/index.php?oldid=", contract$wikipedia_revision_id),
    "Wikipedia API revision-resolution ledger",
    "repository-pinned contemporaneous source crosswalk"
  ),
  local_path = normalizePath(ledger_paths, winslash = "/", mustWork = TRUE),
  hash_algorithm = "MD5",
  source_hash = unname(tools::md5sum(ledger_paths)),
  stringsAsFactors = FALSE
)
if (any(!nzchar(source_ledger$source_hash))) du_stop("A source hash is blank.")

revision_lines <- readLines(input_paths[["wikipedia_revision"]], warn = FALSE)
revision_ok <- length(revision_lines) >= 2L && identical(revision_lines[[1L]], contract$wikipedia_revision_id) &&
  identical(revision_lines[[2L]], contract$wikipedia_revision_timestamp)
source_timing_ok <- contract$filing_date < contract$forbidden_start &&
  as.POSIXct(contract$wikipedia_revision_timestamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") <=
    as.POSIXct(contract$wikipedia_cutoff_timestamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
provenance_ok <- revision_ok && all(nzchar(source_ledger$source_hash)) && submission$ACCESSION_NUMBER[[1L]] == contract$accession

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_H04_DEPLOYMENT_AUDIT_REFRESH", TRUE)
calendar_query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = contract$query_start, end_date = contract$query_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = "SPY",
  universe_name = "hyp_mom_04_1_deployment_universe_calendar", universe_roles = "spy_bounded_calendar",
  refresh = refresh, repo_root = repo_root
)
spy_bars <- h04_validate_bars(calendar_query$bars, contract$query_end)
calendar_dates <- sort(unique(spy_bars$session_date[spy_bars$symbol == "SPY"]))
if (!length(calendar_dates) || max(calendar_dates) > contract$query_end) du_stop("Bounded SPY TRAIN calendar could not be constructed.")

source_symbols <- sort(unique(reconciliation$source_symbol[!is.na(reconciliation$source_symbol)]))
provider_symbols <- sort(unique(c(source_symbols, "SPY")))
chunk_size <- as.integer(env_or("GEN5_H04_DEPLOYMENT_AUDIT_CHUNK_SIZE", "20"))
if (!is.finite(chunk_size) || chunk_size < 1L) du_stop("Chunk size must be a positive integer.")
chunk_id <- ceiling(seq_along(provider_symbols) / chunk_size)
bar_chunks <- vector("list", max(chunk_id))
health_chunks <- vector("list", max(chunk_id))
for (chunk in seq_len(max(chunk_id))) {
  symbols <- provider_symbols[chunk_id == chunk]
  query <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg, start_date = contract$query_start, end_date = contract$query_end,
    as_of_timestamp = contract$as_of_timestamp, symbols = symbols,
    universe_name = paste0("hyp_mom_04_1_deployment_audit_chunk_", sprintf("%02d", chunk)),
    universe_roles = "fixed_pre_oos_spy_cohort,spy_calendar", refresh = refresh, repo_root = repo_root
  )
  bar_chunks[[chunk]] <- query$bars
  health <- query$health
  health$audit_chunk <- chunk
  health_chunks[[chunk]] <- health
  message("Deployment-universe provider chunk ", chunk, "/", max(chunk_id), " complete (", length(symbols), " symbols).")
}
bars <- h04_validate_bars(do.call(rbind, bar_chunks), contract$query_end)
bars_query_health <- do.call(rbind, health_chunks)
boundary_ok <- !any(bars$session_date >= contract$forbidden_start) && max(bars$session_date) <= contract$query_end
resolutions <- du_resolve_provider_symbols(source_symbols, bars)
coverage <- du_train_coverage(reconciliation, resolutions, bars, calendar_dates, contract)
gates <- du_gate_matrix(source_summary, reconciliation, coverage, provenance_ok, source_timing_ok, boundary_ok, contract)
status <- if (all(gates$passed)) "DEPLOYMENT_UNIVERSE_DATA_AUDIT_PASS_TRAIN_AUTHORIZED" else "STOP_DEPLOYMENT_UNIVERSE_DATA_GATES_FAILED_TRAIN_NOT_RUN"

coverage_summary <- data.frame(
  filed_holdings = nrow(coverage),
  provider_history = sum(coverage$provider_history),
  provider_history_fraction = mean(coverage$provider_history),
  complete_train = sum(coverage$complete_train),
  complete_train_fraction = mean(coverage$complete_train),
  expected_train_sessions = length(calendar_dates),
  train_start = min(calendar_dates),
  train_end = max(calendar_dates),
  stringsAsFactors = FALSE
)
sector_summary <- aggregate(
  list(filed_holdings = reconciliation$HOLDING_ID),
  list(sector = ifelse(is.na(reconciliation$sector), "UNRESOLVED", reconciliation$sector)),
  length
)
sector_summary <- sector_summary[order(-sector_summary$filed_holdings, sector_summary$sector), , drop = FALSE]

write_csv(source_ledger, file.path(output_dir, "source_ledger.csv"))
write_csv(reconciliation, file.path(output_dir, "filing_identity_sector_reconciliation.csv"))
write_csv(source_summary, file.path(output_dir, "source_reconciliation_summary.csv"))
write_csv(sector_summary, file.path(output_dir, "sector_summary.csv"))
write_csv(resolutions, file.path(output_dir, "provider_symbol_resolution.csv"))
write_csv(coverage, file.path(output_dir, "train_coverage_ledger.csv"))
write_csv(coverage_summary, file.path(output_dir, "train_coverage_summary.csv"))
write_csv(gates, file.path(output_dir, "universe_gate_matrix.csv"))
write_csv(bars_query_health, file.path(output_dir, "bars_query_health.csv"))
writeLines(status, file.path(output_dir, "status.txt"))

png(file.path(visual_dir, "source_reconciliation.png"), width = 1600, height = 900, res = 150)
par(mar = c(6, 5, 4, 2) + 0.1)
values <- c(
  `Normalized exact` = source_summary$normalized_exact,
  `Pinned source crosswalk` = source_summary$pinned_crosswalk,
  `Unresolved (retained)` = source_summary$unresolved
)
cols <- c("#2D6A4F", "#40916C", "#D00000")
bars_at <- barplot(values, col = cols, border = NA, ylab = "Filed SPY holdings", main = "September 2020 SPY source reconciliation")
text(bars_at, values, labels = values, pos = 3, cex = 1.1)
mtext(sprintf("%d of %d identities resolved without a later roster | Jaccard %.3f", sum(!is.na(reconciliation$source_symbol)), nrow(reconciliation), source_summary$jaccard), side = 1, line = 4.5, cex = 1.05)
dev.off()

png(file.path(visual_dir, "provider_train_coverage.png"), width = 1600, height = 900, res = 150)
par(mar = c(6, 5, 4, 2) + 0.1)
fractions <- c(`Any provider history` = mean(coverage$provider_history), `Exact 2016-2020 TRAIN` = mean(coverage$complete_train))
coverage_at <- barplot(fractions, ylim = c(0, 1), col = c("#457B9D", "#1D3557"), border = NA, ylab = "Fraction of all 505 filed holdings", main = "Causal provider and TRAIN coverage gates")
abline(h = c(contract$minimum_provider_representation, contract$minimum_complete_train_retention), lty = 2, col = c("#457B9D", "#1D3557"), lwd = 2)
text(coverage_at, fractions, labels = sprintf("%.1f%%", 100 * fractions), pos = 3, cex = 1.1)
mtext("Dashed lines show the frozen 95% provider-history and 80% exact-TRAIN thresholds", side = 1, line = 4.5, cex = 1.05)
dev.off()

failed <- gates$gate_id[!gates$passed]
report <- c(
  "# HYP-MOM-04.1 Deployment-Universe Data Audit",
  "",
  paste0("Status: `", status, "`"),
  "",
  "## Causal question",
  "",
  "Can the unchanged Ridge experiment be trained on a fixed SPY holdings cohort that was public before 2021, without claiming historical S&P membership?",
  "",
  "## Source readout",
  "",
  sprintf("- Filing holdings: %d equity rows from SEC accession `%s`.", nrow(reconciliation), contract$accession),
  sprintf("- Identity resolution: %d normalized exact + %d pinned contemporaneous aliases/classes; %d unresolved and retained.", source_summary$normalized_exact, source_summary$pinned_crosswalk, source_summary$unresolved),
  sprintf("- Roster agreement: Jaccard %.4f against Wikipedia revision `%s`.", source_summary$jaccard, contract$wikipedia_revision_id),
  sprintf("- Sector coverage: %.2f%% across %d sectors.", 100 * source_summary$sector_coverage, source_summary$sector_count),
  "",
  "## Provider/TRAIN readout",
  "",
  sprintf("- Some adjusted-bar history through 2020-12-31: %d/%d (%.2f%%).", sum(coverage$provider_history), nrow(coverage), 100 * mean(coverage$provider_history)),
  sprintf("- Exact SPY-session coverage for 2016-01-04 through 2020-12-31: %d/%d (%.2f%%).", sum(coverage$complete_train), nrow(coverage), 100 * mean(coverage$complete_train)),
  sprintf("- 2021+ observations queried: no (boundary status `%s`).", boundary_ok),
  "",
  "## Decision",
  "",
  if (length(failed)) paste0("STOP. Failed gates: `", paste(failed, collapse = "`, `"), "`. The Ridge TRAIN was not run.") else "All universe gates passed. The unchanged Ridge TRAIN is authorized; no 2021+ data has yet been queried.",
  "",
  "## Key artifacts",
  "",
  "- `universe_gate_matrix.csv`",
  "- `filing_identity_sector_reconciliation.csv`",
  "- `train_coverage_ledger.csv`",
  "- `visuals/source_reconciliation.png`",
  "- `visuals/provider_train_coverage.png`"
)
writeLines(report, file.path(output_dir, "REPORT.md"))

cat(status, "\n")
cat("Output:", normalizePath(output_dir, winslash = "/", mustWork = TRUE), "\n")
cat("Source reconciliation:", source_summary$normalized_exact, "exact +", source_summary$pinned_crosswalk, "pinned;", source_summary$unresolved, "unresolved.\n")
cat("Provider history:", sum(coverage$provider_history), "/", nrow(coverage), "\n")
cat("Exact TRAIN:", sum(coverage$complete_train), "/", nrow(coverage), "\n")
cat("Failed gates:", if (length(failed)) paste(failed, collapse = ", ") else "none", "\n")
