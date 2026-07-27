# Gen5.4 E0 point-in-time issuer information-cycle construction.
# No price, outcome, sentiment, model, policy, portfolio, PnL, or live behavior.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}
source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "alpaca_context_provider.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))
source(file.path(repo_root, "R", "gen54_news_admissibility.R"))
source(file.path(repo_root, "R", "gen54_news_risk_measurement.R"))
source(file.path(repo_root, "R", "gen54_event_construction_e0.R"))

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}
ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create output directory.", call. = FALSE)
}
truncate_text <- function(x, width = 62L) {
  value <- gsub("[[:space:]]+", " ", trimws(as.character(x)))
  ifelse(nchar(value) <= width, value, paste0(substr(value, 1L, width - 3L), "..."))
}

plot_coverage <- function(coverage, path) {
  issuers <- sort(unique(coverage$issuer_id))
  quarters <- unique(coverage$quarter)
  values <- matrix(
    0,
    nrow = length(issuers),
    ncol = length(quarters),
    dimnames = list(issuers, quarters)
  )
  for (i in seq_len(nrow(coverage))) {
    values[coverage$issuer_id[[i]], coverage$quarter[[i]]] <-
      coverage$information_cycle_count[[i]]
  }
  png(path, width = 1700, height = 1300, res = 150)
  par(mar = c(7, 7, 4, 8))
  image(
    seq_along(quarters), seq_along(issuers), t(values),
    col = colorRampPalette(c("#EFF6FF", "#3D8DFF", "#0F3B78"))(100),
    axes = FALSE, xlab = "", ylab = "",
    main = "Every issuer-quarter must support observable information cycles"
  )
  axis(1, at = seq_along(quarters), labels = quarters)
  axis(2, at = seq_along(issuers), labels = issuers, las = 1, cex.axis = 0.7)
  for (i in seq_along(quarters)) {
    for (j in seq_along(issuers)) {
      text(i, j, values[j, i], cex = 0.48, col = if (values[j, i] > 45) "white" else "black")
    }
  }
  dev.off()
}

plot_cycle_intensity <- function(cycles, path) {
  counts <- table(pmin(cycles$novel_cluster_count, 20L))
  labels <- names(counts)
  labels[labels == "20"] <- "20+"
  png(path, width = 1500, height = 850, res = 150)
  par(mar = c(6, 6, 4, 2))
  bp <- barplot(
    counts, names.arg = labels, col = "#3D8DFF",
    xlab = "Admissible novel clusters in one issuer information cycle",
    ylab = "Information-cycle count",
    main = "Most cycles are small; a long tail contains dense information arrival"
  )
  text(bp, counts, labels = counts, pos = 3, cex = 0.7)
  dev.off()
}

plot_timing <- function(events, path) {
  ages <- events$age_hours_at_decision
  breaks <- c(0, 1, 3, 6, 12, 24, 48, 72, 120, Inf)
  labels <- c("<=1", "1-3", "3-6", "6-12", "12-24", "24-48", "48-72", "72-120", ">120")
  bins <- cut(ages, breaks = breaks, labels = labels, include.lowest = TRUE, right = TRUE)
  counts <- table(bins)
  png(path, width = 1500, height = 850, res = 150)
  par(mar = c(7, 8, 4, 2))
  bp <- barplot(
    counts, col = "#0F766E", las = 2,
    ylab = "Associations",
    main = "Age at the scheduled decision is measured - not assumed"
  )
  text(bp, counts, labels = counts, pos = 3, cex = 0.72)
  dev.off()
}

plot_exclusions <- function(exclusions, path) {
  png(path, width = 1500, height = 850, res = 150)
  par(mar = c(11, 8, 4, 2))
  values <- exclusions$count
  bp <- barplot(
    values,
    names.arg = exclusions$category,
    col = c("#64748B", "#D97706", "#B91C1C", "#B91C1C", "#166534"),
    las = 2, ylab = "Associations", cex.names = 0.8,
    main = "The admission funnel is explicit and auditable"
  )
  text(bp, values, labels = values, pos = 3, cex = 0.8)
  dev.off()
}

plot_tapes <- function(tape, cycles, path) {
  quarters <- unique(tape$quarter)
  png(path, width = 2400, height = 1500, res = 150)
  par(mfrow = c(2, 3), mar = c(2, 2, 4, 2))
  for (quarter in quarters) {
    part <- tape[tape$quarter == quarter, , drop = FALSE]
    cycle <- cycles[cycles$information_cycle_id == part$information_cycle_id[[1L]], , drop = FALSE]
    plot(
      c(0, 1), c(0, 1), type = "n", axes = FALSE, xlab = "", ylab = "",
      main = paste0(
        quarter, " | ", cycle$issuer_id[[1L]], " | ",
        cycle$decision_session[[1L]], " | ", cycle$novel_cluster_count[[1L]], " clusters"
      )
    )
    y <- seq(0.82, 0.18, length.out = nrow(part))
    text(
      0.02, y,
      labels = paste0(
        sprintf("%5.1fh | ", part$age_hours_at_decision),
        truncate_text(part$headline, 62L)
      ),
      adj = c(0, 0.5), cex = 0.72, col = "#0F172A"
    )
    segments(0.02, y - 0.07, 0.98, y - 0.07, col = "#CBD5E1")
    text(
      0.02, 0.04, "Hours known at decision | Benzinga headline snippet",
      adj = c(0, 0.5), cex = 0.62, col = "#64748B"
    )
  }
  dev.off()
}

plot_gates <- function(audit, path) {
  labels <- c(
    "Source integrity", "Raw page chains", "Authority reproduced",
    "Availability timing", "Next-session mapping", "No stale updates",
    "No title repeats", "Unique cycle IDs", "Positive cycle counts",
    "24 x 6 coverage", "Minimum support", "No predictive surface"
  )
  png(path, width = 1600, height = 1000, res = 150)
  par(mar = c(4, 12, 4, 2))
  y <- rev(seq_len(nrow(audit)))
  plot(c(0, 1), c(0.5, nrow(audit) + 0.5), type = "n", axes = FALSE,
    xlab = "", ylab = "", main = "Frozen E0 construction gates")
  axis(2, at = y, labels = labels, las = 1)
  points(rep(0.5, nrow(audit)), y, pch = 19, cex = 3,
    col = ifelse(audit$status == "PASS", "#166534", "#B91C1C"))
  text(rep(0.5, nrow(audit)), y, labels = audit$status,
    col = "white", font = 2, cex = 0.62)
  dev.off()
}

message("Gen5.4 E0 information-cycle construction starting.")
run_id <- env_or("GEN5_GEN54_E0_RUN_ID", "g54_event_e0_20260726")
n1a_run_id <- env_or("GEN5_GEN54_E0_N1A_RUN_ID", "g54_news_n1a_20260721")
n1d_run_id <- env_or("GEN5_GEN54_E0_N1D_RUN_ID", "g54_news_n1d_20260725")
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)
n1a_dir <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", n1a_run_id
)
n1d_dir <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", n1d_run_id
)

required_files <- c(
  file.path(n1a_dir, "n1a_article_admissibility.csv"),
  file.path(n1d_dir, "n1d_run_spec.csv"),
  file.path(n1d_dir, "n1d_leakage_audit.csv"),
  file.path(n1d_dir, "n1d_page_manifest.csv"),
  file.path(n1d_dir, "n1d_market_calendar.csv"),
  file.path(n1d_dir, "n1d_confirmation_event_weights.csv")
)
if (!all(file.exists(required_files))) {
  g5_gen54_e0_stop("Accepted N1A/N1D input authority is incomplete.")
}

n1d_spec <- utils::read.csv(required_files[[2L]], stringsAsFactors = FALSE, check.names = FALSE)
n1d_leakage <- utils::read.csv(required_files[[3L]], stringsAsFactors = FALSE, check.names = FALSE)
page_manifest <- utils::read.csv(required_files[[4L]], stringsAsFactors = FALSE, check.names = FALSE)
calendar <- utils::read.csv(required_files[[5L]], stringsAsFactors = FALSE, check.names = FALSE)
authority <- utils::read.csv(
  required_files[[6L]],
  stringsAsFactors = FALSE,
  check.names = FALSE,
  colClasses = c(article_id = "character")
)
calendar$session_date <- as.Date(calendar$session_date)
source_leakage_passed <- nrow(n1d_leakage) > 0L && all(n1d_leakage$status == "PASS")

partitions <- data.frame(
  partition_id = c("2025", "2026H1"),
  start_timestamp = c("2025-01-01T00:00:00Z", "2026-01-01T00:00:00Z"),
  end_timestamp = c("2025-12-31T23:59:59Z", "2026-06-30T23:59:59Z"),
  stringsAsFactors = FALSE
)
registry <- g5_gen54_xs_candidate_registry()
partition_articles <- list()
for (i in seq_len(nrow(partitions))) {
  partition <- partitions[i, , drop = FALSE]
  request <- g5_alpaca_news_request(
    symbols = registry$symbol,
    start_timestamp = partition$start_timestamp[[1L]],
    end_timestamp = partition$end_timestamp[[1L]],
    as_of_timestamp = n1d_spec$as_of_timestamp[[1L]],
    include_content = FALSE,
    limit = 50L
  )
  raw_files <- sort(list.files(
    file.path(n1d_dir, "raw"),
    pattern = paste0("^news_", partition$partition_id[[1L]], "_page_[0-9]{4}\\.json$"),
    full.names = TRUE
  ))
  if (!length(raw_files)) {
    g5_gen54_e0_stop(paste("No preserved pages for", partition$partition_id[[1L]]))
  }
  frames <- lapply(raw_files, function(raw_file) {
    response_text <- paste(
      readLines(raw_file, warn = FALSE, encoding = "UTF-8"),
      collapse = "\n"
    )
    parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
    g5_alpaca_map_news_payload(
      parsed,
      request,
      retrieved_at = n1d_spec$as_of_timestamp[[1L]]
    )
  })
  frames <- frames[vapply(frames, nrow, integer(1L)) > 0L]
  partition_articles[[partition$partition_id[[1L]]]] <- do.call(rbind, frames)
}
current_articles <- do.call(rbind, partition_articles)
current_articles <- current_articles[order(current_articles$article_id, current_articles$updated_at), , drop = FALSE]
current_articles <- current_articles[!duplicated(current_articles$article_id), , drop = FALSE]

canonical_columns <- names(g5_alpaca_empty_news())
n1a_enriched <- utils::read.csv(
  required_files[[1L]],
  stringsAsFactors = FALSE,
  check.names = FALSE,
  colClasses = c(article_id = "character")
)
if (!all(canonical_columns %in% names(n1a_enriched))) {
  g5_gen54_e0_stop("N1A authority lacks canonical Alpaca news columns.")
}
combined_articles <- g5_gen54_n1b_combine_articles(
  n1a_enriched[, canonical_columns, drop = FALSE],
  current_articles[, canonical_columns, drop = FALSE]
)
news <- g5_gen54_n1b_build_news_panel(
  combined_articles,
  calendar$session_date,
  issuer_registry = g5_gen54_n1b_issuer_registry(),
  start_date = as.Date("2025-01-01"),
  end_date = as.Date("2026-06-30")
)
events <- g5_gen54_e0_enrich_admissible_associations(news)
cycles <- g5_gen54_e0_build_cycles(events)
coverage <- g5_gen54_e0_coverage(cycles, unique(g5_gen54_n1b_issuer_registry()$issuer_id))
sources <- g5_gen54_e0_source_summary(events)
tape <- g5_gen54_e0_representative_tape(events, cycles)

authority_keys <- sort(unique(paste(
  as.character(authority$article_id),
  authority$issuer_id,
  authority$decision_session,
  authority$exact_title_cluster_id,
  sep = "\r"
)))
rebuilt_keys <- g5_gen54_e0_authority_keys(events)
authority_reproduced <- identical(authority_keys, rebuilt_keys)
terminal <- aggregate(
  page_manifest$page_number,
  list(partition_id = page_manifest$partition_id),
  max
)
names(terminal)[[2L]] <- "last_page"
terminal <- merge(
  terminal,
  page_manifest[, c("partition_id", "page_number", "next_page_token_present")],
  by.x = c("partition_id", "last_page"),
  by.y = c("partition_id", "page_number"),
  all.x = TRUE
)
raw_pages_ok <- all(page_manifest$http_status == 200L) &&
  nrow(terminal) == nrow(partitions) &&
  all(!terminal$next_page_token_present)

audit <- g5_gen54_e0_integrity_audit(
  events,
  cycles,
  coverage,
  source_leakage_passed = source_leakage_passed,
  authority_reproduced = authority_reproduced,
  raw_pages_ok = raw_pages_ok,
  minimum_cycles_per_issuer_quarter = 5L
)
overall_status <- if (all(audit$status == "PASS")) {
  "PASS_E0_INFORMATION_CYCLES_READY_FOR_FEATURE_THEORY"
} else {
  "STOP_E0_EVENT_CONSTRUCTION"
}

associations <- news$associations
article_row <- match(associations$article_id, news$articles$article_id)
associations$update_delay_seconds <- news$articles$update_delay_seconds[article_row]
registry_row <- match(associations$symbol, g5_gen54_n1b_issuer_registry()$provider_symbol)
associations$symbol_valid_on_decision <- !is.na(registry_row) &
  !is.na(associations$decision_session) &
  associations$decision_session >= g5_gen54_n1b_issuer_registry()$valid_from[registry_row] &
  associations$decision_session <= g5_gen54_n1b_issuer_registry()$valid_to[registry_row]
exclusions <- data.frame(
  category = c(
    "Candidate associations", "Exact-title repeats", "Stale updates",
    "Invalid/outside cycles", "Admitted novel associations"
  ),
  count = c(
    nrow(associations),
    sum(associations$exact_title_repeat, na.rm = TRUE),
    sum(associations$update_delay_seconds > 24 * 3600, na.rm = TRUE),
    sum(
      !associations$symbol_valid_on_decision |
        is.na(associations$decision_session) |
        associations$decision_session < as.Date("2025-01-01") |
        associations$decision_session > as.Date("2026-06-30"),
      na.rm = TRUE
    ),
    nrow(events)
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = "gen54_event_construction_e0_v0.1",
  wrapper = "scripts/inspect/run_gen54_event_construction_e0.R",
  contract = "docs/GEN5_4_EVENT_CONSTRUCTION_E0_CONTRACT.md",
  run_id = run_id,
  source_n1a_run_id = n1a_run_id,
  source_n1d_run_id = n1d_run_id,
  as_of_timestamp = n1d_spec$as_of_timestamp[[1L]],
  archive_start = as.Date("2025-01-01"),
  archive_end = as.Date("2026-06-30"),
  issuer_count = length(unique(events$issuer_id)),
  quarter_count = length(unique(cycles$quarter)),
  raw_article_count = nrow(current_articles),
  admitted_association_count = nrow(events),
  information_cycle_count = nrow(cycles),
  minimum_issuer_quarter_cycle_count = min(coverage$information_cycle_count),
  maximum_cycle_cluster_count = max(cycles$novel_cluster_count),
  price_feature_count = 0L,
  outcome_join_count = 0L,
  sentiment_count = 0L,
  model_fit_count = 0L,
  portfolio_metric_count = 0L,
  live_advice_change_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)
health <- data.frame(
  check_id = c(
    "source_n1d_integrity", "raw_page_chain", "authority_reproduction",
    "issuer_quarter_support"
  ),
  status = c(
    if (source_leakage_passed) "PASS" else "FAIL",
    if (raw_pages_ok) "PASS" else "FAIL",
    if (authority_reproduced) "PASS" else "FAIL",
    if (all(coverage$information_cycle_count >= 5L)) "PASS" else "FAIL"
  ),
  detail = c(
    paste0(sum(n1d_leakage$status == "PASS"), " / ", nrow(n1d_leakage), " accepted N1D checks pass."),
    paste0(nrow(page_manifest), " preserved pages across two terminating partitions."),
    paste0(length(rebuilt_keys), " rebuilt association keys versus ", length(authority_keys), " admitted keys."),
    paste0("Minimum issuer-quarter information-cycle count: ", min(coverage$information_cycle_count), ".")
  ),
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "e0_run_spec.csv"))
write_csv(health, file.path(output_dir, "e0_health.csv"))
write_csv(page_manifest, file.path(output_dir, "e0_source_page_manifest.csv"))
write_csv(audit, file.path(output_dir, "e0_integrity_audit.csv"))
write_csv(events, file.path(output_dir, "e0_article_issuer_tape.csv"))
write_csv(cycles, file.path(output_dir, "e0_information_cycles.csv"))
write_csv(coverage, file.path(output_dir, "e0_issuer_quarter_coverage.csv"))
write_csv(sources, file.path(output_dir, "e0_source_summary.csv"))
write_csv(exclusions, file.path(output_dir, "e0_admission_funnel.csv"))
write_csv(tape, file.path(output_dir, "e0_representative_cycle_tape.csv"))

plot_coverage(coverage, file.path(visual_dir, "e0_issuer_quarter_coverage.png"))
plot_cycle_intensity(cycles, file.path(visual_dir, "e0_cycle_intensity.png"))
plot_timing(events, file.path(visual_dir, "e0_article_age_at_decision.png"))
plot_exclusions(exclusions, file.path(visual_dir, "e0_admission_funnel.png"))
plot_tapes(tape, cycles, file.path(visual_dir, "e0_representative_cycle_tapes.png"))
plot_gates(audit, file.path(visual_dir, "e0_gate_summary.png"))

report <- c(
  "# Gen5.4 E0 Issuer Information-Cycle Construction",
  "",
  paste0("Status: `", overall_status, "`"),
  "",
  "## Question",
  "",
  "Can the accepted Alpaca news archive deterministically produce point-in-time issuer information cycles before any price or outcome join?",
  "",
  "## Readout",
  "",
  paste0("- Raw 2025-2026H1 Alpaca articles: `", nrow(current_articles), "`."),
  paste0("- Admitted article-issuer associations: `", nrow(events), "`."),
  paste0("- Issuer information cycles: `", nrow(cycles), "`."),
  paste0("- Issuer coverage: `", length(unique(events$issuer_id)), " / 24`."),
  paste0("- Quarter coverage: `", length(unique(cycles$quarter)), " / 6`."),
  paste0("- Minimum issuer-quarter cycle count: `", min(coverage$information_cycle_count), "`; required `5`."),
  paste0("- Maximum novel clusters in one cycle: `", max(cycles$novel_cluster_count), "`."),
  paste0("- Rebuilt association authority: `", if (authority_reproduced) "exact match" else "mismatch", "`."),
  "",
  "## Interpretation",
  "",
  if (overall_status == "PASS_E0_INFORMATION_CYCLES_READY_FOR_FEATURE_THEORY") {
    "The point-in-time information-cycle tape is reproducible and operationally supported. Open only a theory session for one minimal initial-reaction measurement and prospective confirmation design."
  } else {
    "At least one construction gate failed. Stop before any price-response or outcome join."
  },
  "",
  "## Limitation",
  "",
  "- Every historical article in this Alpaca sample is sourced from Benzinga. E0 therefore demonstrates timestamped construction and coverage, not source diversity or cross-provider robustness.",
  "",
  "## Hard boundary",
  "",
  "E0 contains no price, volume, future return, sentiment, model, policy, exposure, allocation, costs, PnL, or live-advice behavior.",
  "",
  "## Visuals",
  "",
  "- `visuals/e0_issuer_quarter_coverage.png`",
  "- `visuals/e0_cycle_intensity.png`",
  "- `visuals/e0_article_age_at_decision.png`",
  "- `visuals/e0_admission_funnel.png`",
  "- `visuals/e0_representative_cycle_tapes.png`",
  "- `visuals/e0_gate_summary.png`"
)
writeLines(report, file.path(output_dir, "e0_report.md"), useBytes = TRUE)
message("Gen5.4 E0 complete: ", overall_status)
message("Report: ", normalizePath(file.path(output_dir, "e0_report.md"), winslash = "/"))
