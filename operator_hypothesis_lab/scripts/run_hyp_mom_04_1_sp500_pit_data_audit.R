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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_sp500_pit_audit.R"))
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

contract <- spit_validate_contract()
run_id <- env_or("GEN5_SP500_PIT_AUDIT_RUN_ID", "hyp_mom_04_1_sp500_pit_data_audit_20260810")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
source_dir <- file.path(output_dir, "sources")
visual_dir <- file.path(output_dir, "visuals")
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

raw_base <- paste0("https://raw.githubusercontent.com/fja05680/sp500/", contract$primary_commit, "/")
source_specs <- data.frame(
  role = c("PRIMARY_INTERVALS", "PRIMARY_SNAPSHOTS", "PINNED_CURRENT_ROSTER"),
  filename = c(contract$primary_interval_file, contract$primary_snapshot_file, contract$primary_current_file),
  url = c(
    paste0(raw_base, contract$primary_interval_file),
    paste0(raw_base, utils::URLencode(contract$primary_snapshot_file, reserved = TRUE)),
    paste0(raw_base, contract$primary_current_file)
  ), stringsAsFactors = FALSE
)
local_source_override <- env_or("GEN5_SP500_PIT_SOURCE_DIR", file.path(repo_root, "tmp", "sp500_pit_source"))
for (i in seq_len(nrow(source_specs))) {
  destination <- file.path(source_dir, source_specs$filename[[i]])
  local_candidate <- file.path(local_source_override, source_specs$filename[[i]])
  if (!file.exists(destination)) {
    if (file.exists(local_candidate)) {
      if (!file.copy(local_candidate, destination, overwrite = FALSE)) spit_stop(paste("Could not copy pinned source", local_candidate))
    } else {
      utils::download.file(source_specs$url[[i]], destination, mode = "wb", quiet = TRUE)
    }
  }
}
source_specs$local_path <- normalizePath(file.path(source_dir, source_specs$filename), winslash = "/", mustWork = TRUE)
source_specs$hash_algorithm <- "MD5"
source_specs$source_hash <- unname(tools::md5sum(source_specs$local_path))
source_specs$pinned_commit <- contract$primary_commit

intervals <- spit_read_intervals(file.path(source_dir, contract$primary_interval_file))
snapshots <- utils::read.csv(file.path(source_dir, contract$primary_snapshot_file), stringsAsFactors = FALSE)
current_roster <- utils::read.csv(file.path(source_dir, contract$primary_current_file), stringsAsFactors = FALSE)
if (!"Symbol" %in% names(current_roster)) spit_stop("Pinned current roster has an unexpected schema.")

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_SP500_PIT_AUDIT_REFRESH", TRUE)
calendar_query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = contract$query_start, end_date = contract$query_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = "SPY",
  universe_name = "hyp_mom_04_1_sp500_pit_calendar", universe_roles = "spy_bounded_calendar",
  refresh = refresh, repo_root = repo_root
)
spy_bars <- h04_validate_bars(calendar_query$bars, contract$query_end)
if (!nrow(spy_bars) || any(spy_bars$symbol != "SPY")) spit_stop("Bounded SPY calendar could not be constructed.")
calendar_dates <- spy_bars$session_date
schedule <- spit_schedule(calendar_dates, contract$signal_quarters)
if (max(schedule$exit_date) > contract$query_end) spit_stop("Audit schedule exceeded the frozen 2020 boundary.")

membership_rows <- list()
snapshot_rows <- list()
wikipedia_rows <- list()
revision_rows <- list()
comparison_rows <- list()
sector_rows <- list()

for (i in seq_len(nrow(schedule))) {
  s <- schedule[i, , drop = FALSE]
  primary <- spit_members_at(intervals, s$signal_date)
  primary$signal_quarter <- s$signal_quarter
  primary$signal_date <- s$signal_date
  membership_rows[[i]] <- primary

  snapshot <- spit_snapshot_at(snapshots, s$signal_date)
  snapshot$signal_quarter <- s$signal_quarter
  snapshot_rows[[i]] <- snapshot

  cache_path <- file.path(source_dir, paste0("wikipedia_", s$signal_quarter, "_revision.rds"))
  if (file.exists(cache_path)) {
    wiki <- readRDS(cache_path)
  } else {
    wiki <- spit_fetch_wikipedia_revision(s$signal_date, contract)
    saveRDS(wiki, cache_path)
    Sys.sleep(2)
  }
  roster <- wiki$roster
  roster$signal_quarter <- s$signal_quarter
  roster$signal_date <- s$signal_date
  roster$revision_id <- wiki$revision_id
  roster$revision_timestamp <- wiki$revision_timestamp
  wikipedia_rows[[i]] <- roster

  cutoff <- as.POSIXct(paste0(s$signal_date, " ", contract$wikipedia_cutoff_utc), tz = "UTC")
  observed <- as.POSIXct(wiki$revision_timestamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  revision_rows[[i]] <- data.frame(
    signal_quarter = s$signal_quarter, signal_date = s$signal_date,
    cutoff_utc = format(cutoff, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    revision_id = wiki$revision_id, revision_timestamp = wiki$revision_timestamp,
    cutoff_passed = !is.na(observed) && observed <= cutoff,
    query_url = wiki$query_url, parse_url = wiki$parse_url, stringsAsFactors = FALSE
  )

  comparison <- spit_roster_comparison(primary, roster)
  primary_snapshot <- unique(spit_normalize_symbol(primary$ticker))
  historical_snapshot <- unique(spit_normalize_symbol(snapshot$ticker))
  comparison$signal_quarter <- s$signal_quarter
  comparison$signal_date <- s$signal_date
  comparison$snapshot_date <- unique(snapshot$snapshot_date)
  comparison$primary_snapshot_jaccard <- length(intersect(primary_snapshot, historical_snapshot)) / length(union(primary_snapshot, historical_snapshot))
  comparison_rows[[i]] <- comparison

  sector <- spit_sector_join(primary, roster)
  sector$signal_quarter <- s$signal_quarter
  sector$signal_date <- s$signal_date
  sector_rows[[i]] <- sector
}

memberships <- do.call(rbind, membership_rows)
historical_snapshots <- do.call(rbind, snapshot_rows)
wikipedia_rosters <- do.call(rbind, wikipedia_rows)
revision_ledger <- do.call(rbind, revision_rows)
roster_summary <- do.call(rbind, comparison_rows)
sector_ledger <- do.call(rbind, sector_rows)
roster_summary <- roster_summary[c("signal_quarter", "signal_date", "primary_count", "wikipedia_count", "intersection_count", "union_count", "jaccard", "snapshot_date", "primary_snapshot_jaccard", "primary_only", "wikipedia_only")]
sector_summary <- do.call(rbind, lapply(split(sector_ledger, sector_ledger$signal_quarter), function(x) {
  data.frame(signal_quarter = unique(x$signal_quarter), primary_count = nrow(x),
             sector_mapped = sum(!is.na(x$sector) & nzchar(x$sector)),
             sector_coverage = mean(!is.na(x$sector) & nzchar(x$sector)),
             sector_count = length(unique(x$sector[!is.na(x$sector) & nzchar(x$sector)])), stringsAsFactors = FALSE)
}))
sector_summary <- sector_summary[match(contract$signal_quarters, sector_summary$signal_quarter), , drop = FALSE]

source_symbols <- sort(unique(memberships$ticker))
provider_symbols <- sort(unique(c(unlist(lapply(source_symbols, spit_provider_candidates)), "SPY")))
chunk_size <- as.integer(env_or("GEN5_SP500_PIT_AUDIT_CHUNK_SIZE", "20"))
if (!is.finite(chunk_size) || chunk_size < 1L) spit_stop("GEN5_SP500_PIT_AUDIT_CHUNK_SIZE must be a positive integer.")
chunk_id <- ceiling(seq_along(provider_symbols) / chunk_size)
bar_chunks <- vector("list", max(chunk_id))
health_chunks <- vector("list", max(chunk_id))
for (chunk in seq_len(max(chunk_id))) {
  chunk_symbols <- provider_symbols[chunk_id == chunk]
  chunk_query <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg, start_date = contract$query_start, end_date = contract$query_end,
    as_of_timestamp = contract$as_of_timestamp, symbols = chunk_symbols,
    universe_name = paste0("hyp_mom_04_1_sp500_pit_audit_chunk_", sprintf("%02d", chunk)),
    universe_roles = "point_in_time_members,spy_calendar",
    refresh = refresh, repo_root = repo_root
  )
  bar_chunks[[chunk]] <- chunk_query$bars
  health <- chunk_query$health
  health$audit_chunk <- chunk
  health_chunks[[chunk]] <- health
  message("SP500 PIT provider chunk ", chunk, "/", max(chunk_id), " complete (", length(chunk_symbols), " symbols).")
}
bars <- h04_validate_bars(do.call(rbind, bar_chunks), contract$query_end)
bars_query_health <- do.call(rbind, health_chunks)
if (any(bars$session_date >= contract$forbidden_start)) spit_stop("A 2021+ bar entered the point-in-time audit.")

resolutions <- spit_resolve_provider_symbols(source_symbols, bars)
member_coverage <- spit_member_quarter_coverage(memberships, schedule, calendar_dates, bars, resolutions, contract$feature_sessions)
coverage_summary <- do.call(rbind, lapply(split(member_coverage, member_coverage$signal_quarter), function(x) {
  s <- schedule[schedule$signal_quarter == unique(x$signal_quarter), , drop = FALSE]
  data.frame(
    signal_quarter = unique(x$signal_quarter), signal_date = s$signal_date,
    entry_date = s$entry_date, exit_date = s$exit_date,
    primary_count = nrow(x), uniquely_resolved = sum(!is.na(x$resolved_symbol)),
    feature_complete = sum(x$feature_complete), entry_present = sum(x$entry_present), exit_present = sum(x$exit_present),
    ordinary_complete = sum(x$ordinary_complete), ordinary_coverage = mean(x$ordinary_complete),
    terminal_events = sum(x$terminal_event), terminal_returns_defensible = sum(x$terminal_event & x$terminal_return_defensible),
    stringsAsFactors = FALSE
  )
}))
coverage_summary <- coverage_summary[match(contract$signal_quarters, coverage_summary$signal_quarter), , drop = FALSE]

current_symbols <- unique(spit_normalize_symbol(current_roster$Symbol))
removed_symbols <- source_symbols[!spit_normalize_symbol(source_symbols) %in% current_symbols]
removed_resolutions <- resolutions[resolutions$source_symbol %in% removed_symbols, , drop = FALSE]
removed_history <- data.frame(
  source_symbol = removed_symbols,
  has_alpaca_history = removed_symbols %in% removed_resolutions$source_symbol[removed_resolutions$match_count == 1L],
  resolved_symbol = removed_resolutions$resolved_symbol[match(removed_symbols, removed_resolutions$source_symbol)],
  stringsAsFactors = FALSE
)
removed_summary <- data.frame(
  removed_identity_count = nrow(removed_history),
  removed_with_history = sum(removed_history$has_alpaca_history),
  history_fraction = if (nrow(removed_history)) mean(removed_history$has_alpaca_history) else NA_real_,
  stringsAsFactors = FALSE
)

terminal_ledger <- member_coverage[member_coverage$terminal_event, , drop = FALSE]
gates <- spit_gate_matrix(roster_summary, sector_summary, resolutions, coverage_summary, removed_summary,
                          revision_ledger, source_specs, contract)
status <- if (all(gates$passed)) "SP500_PIT_DATA_AUDIT_PASS_REPLICATION_MAY_BE_FROZEN" else "STOP_SP500_PIT_DATA_GATES_FAILED_REPLICATION_NOT_RUN"

blue <- "#2B6CB0"; green <- "#2F855A"; red <- "#C53030"; gray <- "#718096"; pale <- "#EDF2F7"; dark <- "#1A202C"
png(file.path(visual_dir, "sp500_pit_gate_matrix.png"), 1800, 1100, res = 150)
par(mar = c(5, 16, 4, 3))
gate_y <- rev(seq_len(nrow(gates)))
gate_labels <- c("PROVENANCE", "ROSTER SIZE", "ROSTER AGREEMENT", "SECTOR COVERAGE", "IDENTITY RESOLUTION",
                 "FEATURE + TARGET COVERAGE", "REMOVED-NAME HISTORY", "TERMINAL OUTCOMES", "BOUNDARY INTEGRITY")
plot(as.integer(gates$passed), gate_y, xlim = c(-0.1, 1.1), ylim = c(0.5, nrow(gates) + 0.5),
     xaxt = "n", yaxt = "n", xlab = "", ylab = "", pch = 19, cex = 2.4,
     col = ifelse(gates$passed, green, red), main = "Six passes do not override three hard failures")
axis(1, at = c(0, 1), labels = c("FAIL", "PASS"))
axis(2, at = gate_y, labels = gate_labels, las = 1, tick = FALSE)
abline(v = c(0, 1), lty = 3, col = gray)
dev.off()

png(file.path(visual_dir, "sp500_pit_roster_sector_agreement.png"), 1900, 1150, res = 150)
par(mfrow = c(2, 1), mar = c(4, 5, 4, 2))
plot(roster_summary$jaccard, type = "b", pch = 19, col = blue,
     ylim = range(c(roster_summary$jaccard, contract$minimum_jaccard)), xaxt = "n",
     xlab = "", ylab = "Jaccard", main = "Primary vs contemporaneous roster")
axis(1, seq_len(nrow(roster_summary)), roster_summary$signal_quarter, las = 2, cex.axis = 0.75)
abline(h = contract$minimum_jaccard, lty = 2, col = red)
plot(100 * sector_summary$sector_coverage, type = "b", pch = 19, col = blue,
     ylim = range(c(100 * sector_summary$sector_coverage, 100 * contract$minimum_sector_coverage)), xaxt = "n",
     xlab = "Signal quarter", ylab = "Coverage (%)", main = "Contemporaneous sector mapping")
axis(1, seq_len(nrow(sector_summary)), sector_summary$signal_quarter, las = 2, cex.axis = 0.75)
abline(h = 100 * contract$minimum_sector_coverage, lty = 2, col = red)
dev.off()

png(file.path(visual_dir, "sp500_pit_quarter_coverage.png"), 2100, 1350, res = 150)
par(mfrow = c(2, 2), mar = c(7, 5, 4, 2))
plot(roster_summary$jaccard, type = "b", pch = 19, col = blue, ylim = range(c(roster_summary$jaccard, contract$minimum_jaccard)),
     xaxt = "n", xlab = "Signal quarter", ylab = "Jaccard", main = "Primary vs contemporaneous Wikipedia")
axis(1, seq_len(nrow(roster_summary)), roster_summary$signal_quarter, las = 2, cex.axis = 0.75); abline(h = contract$minimum_jaccard, lty = 2, col = red)
plot(100 * sector_summary$sector_coverage, type = "b", pch = 19, col = blue, ylim = range(c(100 * sector_summary$sector_coverage, 100 * contract$minimum_sector_coverage)),
     xaxt = "n", xlab = "Signal quarter", ylab = "Coverage (%)", main = "Contemporaneous sector coverage")
axis(1, seq_len(nrow(sector_summary)), sector_summary$signal_quarter, las = 2, cex.axis = 0.75); abline(h = 100 * contract$minimum_sector_coverage, lty = 2, col = red)
plot(100 * coverage_summary$ordinary_coverage, type = "b", pch = 19, col = blue, ylim = range(c(100 * coverage_summary$ordinary_coverage, 100 * contract$minimum_complete_coverage)),
     xaxt = "n", xlab = "Signal quarter", ylab = "Coverage (%)", main = "Feature + ordinary target coverage")
axis(1, seq_len(nrow(coverage_summary)), coverage_summary$signal_quarter, las = 2, cex.axis = 0.75); abline(h = 100 * contract$minimum_complete_coverage, lty = 2, col = red)
unresolved_terminal <- coverage_summary$terminal_events - coverage_summary$terminal_returns_defensible
barplot(unresolved_terminal, names.arg = coverage_summary$signal_quarter, las = 2, col = ifelse(unresolved_terminal > 0, red, pale),
        ylab = "Member-quarter outcomes", main = "Unresolved target-quarter exits")
dev.off()

png(file.path(visual_dir, "sp500_pit_survivorship_diagnostic.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
barplot(c(removed_summary$removed_with_history, removed_summary$removed_identity_count - removed_summary$removed_with_history),
        names.arg = c("Has Alpaca history", "No Alpaca history"), col = c(green, red), ylab = "Removed identities",
        main = "Provider representation of non-current names")
barplot(c(sum(member_coverage$terminal_event & member_coverage$terminal_return_defensible),
          sum(member_coverage$terminal_event & !member_coverage$terminal_return_defensible)),
        names.arg = c("Defensible terminal return", "Unresolved terminal return"), col = c(green, red), ylab = "Member-quarter events",
        main = "Target-quarter exits after index departure")
dev.off()

write_csv(source_specs, file.path(output_dir, "sp500_pit_source_ledger.csv"))
write_csv(schedule, file.path(output_dir, "sp500_pit_schedule.csv"))
write_csv(revision_ledger, file.path(output_dir, "sp500_pit_wikipedia_revision_ledger.csv"))
write_csv(memberships, file.path(output_dir, "sp500_pit_primary_memberships.csv"))
write_csv(historical_snapshots, file.path(output_dir, "sp500_pit_primary_historical_snapshots.csv"))
write_csv(wikipedia_rosters, file.path(output_dir, "sp500_pit_wikipedia_rosters.csv"))
write_csv(roster_summary, file.path(output_dir, "sp500_pit_roster_summary.csv"))
write_csv(sector_ledger, file.path(output_dir, "sp500_pit_sector_ledger.csv"))
write_csv(sector_summary, file.path(output_dir, "sp500_pit_sector_summary.csv"))
write_csv(resolutions, file.path(output_dir, "sp500_pit_symbol_resolution.csv"))
write_csv(member_coverage, file.path(output_dir, "sp500_pit_member_quarter_coverage.csv"))
write_csv(coverage_summary, file.path(output_dir, "sp500_pit_coverage_summary.csv"))
write_csv(removed_history, file.path(output_dir, "sp500_pit_removed_security_history.csv"))
write_csv(removed_summary, file.path(output_dir, "sp500_pit_removed_security_summary.csv"))
write_csv(terminal_ledger, file.path(output_dir, "sp500_pit_terminal_event_ledger.csv"))
write_csv(gates, file.path(output_dir, "sp500_pit_gate_matrix.csv"))
write_csv(calendar_query$health, file.path(output_dir, "sp500_pit_calendar_query_health.csv"))
write_csv(bars_query_health, file.path(output_dir, "sp500_pit_bars_query_health.csv"))

run_spec <- data.frame(
  audit_id = contract$audit_id, program_id = contract$program_id, status = status,
  as_of_timestamp = contract$as_of_timestamp, query_start = contract$query_start, query_end = contract$query_end,
  signal_quarters = length(contract$signal_quarters), unique_primary_identities = length(source_symbols),
  member_quarter_rows = nrow(member_coverage), all_gates_pass = all(gates$passed),
  strategy_replication_run = FALSE, refresh = refresh, stringsAsFactors = FALSE
)
write_csv(run_spec, file.path(output_dir, "sp500_pit_run_spec.csv"))

failed <- gates$gate_id[!gates$passed]
report <- c(
  "# HYP-MOM-04.1 point-in-time S&P 500 data audit", "",
  paste0("Status: `", status, "`."), "",
  "This packet audits whether the unchanged Ridge experiment can be repeated without using today's surviving S&P 500 constituents. It does not fit a model or inspect any 2021+ outcome.", "",
  paste0("Primary source commit: `", contract$primary_commit, "`; signal quarters: 2017Q1-2020Q3; last permissible bar: 2020-12-31."), "",
  paste0("Unique point-in-time identities: ", length(source_symbols), "; member-quarter rows: ", nrow(member_coverage), "."), "",
  paste0("Worst primary/Wikipedia roster Jaccard: ", formatC(min(roster_summary$jaccard), digits = 4, format = "f"),
         "; worst contemporaneous sector coverage: ", formatC(100 * min(sector_summary$sector_coverage), digits = 2, format = "f"), "%."), "",
  paste0("Worst complete ordinary bar coverage: ", formatC(100 * min(coverage_summary$ordinary_coverage), digits = 2, format = "f"),
         "%; removed identities with Alpaca history: ", removed_summary$removed_with_history, "/", removed_summary$removed_identity_count, "."), "",
  paste0("Target-quarter terminal events: ", nrow(terminal_ledger), "; defensible terminal returns under the frozen Alpaca-only rule: ", sum(terminal_ledger$terminal_return_defensible), "."), "",
  if (length(failed)) paste0("Failed hard gates: `", paste(failed, collapse = "`, `"), "`.") else "All hard gates passed; the strategy replication may now be separately frozen.", "",
  "The strategy replication flag is FALSE in this packet. No Ridge fit, lambda selection, quartile score, or OOS result was produced."
)
writeLines(report, file.path(output_dir, "sp500_pit_data_audit_report.md"))

print(run_spec)
print(gates)
message("SP500 PIT data audit complete: ", output_dir)
