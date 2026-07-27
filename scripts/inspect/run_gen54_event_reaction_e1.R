# Gen5.4 E1 event-conditioned continuation development diagnostic.
# Measurement only: no model, portfolio replay, PnL, allocation, or live change.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(
    file.path(dirname(script_path), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

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
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))
source(file.path(repo_root, "R", "gen54_news_admissibility.R"))
source(file.path(repo_root, "R", "gen54_news_risk_measurement.R"))
source(file.path(repo_root, "R", "gen54_event_reaction_e1.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in%
    c("1", "true", "yes")
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}
ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create output directory.", call. = FALSE)
}
read_required_csv <- function(path) {
  if (!file.exists(path)) {
    stop(paste("Required authority artifact is missing:", path), call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
as_date_columns <- function(x, columns) {
  for (column in intersect(columns, names(x))) x[[column]] <- as.Date(x[[column]])
  x
}

plot_funnel <- function(funnel, path) {
  png(path, width = 1600, height = 900, res = 150)
  par(mar = c(11, 7, 4, 2))
  bars <- barplot(
    funnel$count,
    names.arg = funnel$stage,
    col = c("#64748B", "#3D8DFF", "#6DCBF4", "#0F766E", "#166534", "#15803D", "#14532D"),
    las = 2,
    ylab = "Observations",
    cex.names = 0.78,
    main = "Every timing and support filter is visible"
  )
  text(bars, funnel$count, labels = funnel$count, pos = 3, cex = 0.78)
  dev.off()
}

plot_fold_readout <- function(fold_summary, path) {
  png(path, width = 1700, height = 1000, res = 150)
  par(mfrow = c(2, 1), mar = c(5, 6, 4, 2))
  values <- rbind(
    10000 * fold_summary$mean_signal_continuation_excess_h5,
    10000 * fold_summary$mean_control_continuation_excess_h5
  )
  bars <- barplot(
    values,
    beside = TRUE,
    names.arg = fold_summary$fold_id,
    col = c("#3D8DFF", "#94A3B8"),
    ylab = "Mean h5 excess continuation (bp)",
    main = "Development continuation is compared with the same price pattern"
  )
  abline(h = 0, col = "#0F172A")
  legend("topright", legend = c("information shock", "zero-news control"),
    fill = c("#3D8DFF", "#94A3B8"), bty = "n")
  differences <- 10000 * fold_summary$mean_matched_difference_h5
  bars2 <- barplot(
    differences,
    names.arg = fold_summary$fold_id,
    col = ifelse(differences >= 0, "#166534", "#B91C1C"),
    ylab = "Signal minus control (bp)",
    main = "Matched differences are descriptive, not promotion gates"
  )
  abline(h = 0, col = "#0F172A")
  text(bars2, differences, labels = sprintf("%.0f", differences),
    pos = ifelse(differences >= 0, 3, 1), cex = 0.72)
  dev.off()
}

plot_match_quality <- function(matches, path) {
  x <- matches[matches$matched, , drop = FALSE]
  png(path, width = 1700, height = 800, res = 150)
  par(mfrow = c(1, 2), mar = c(6, 6, 4, 2))
  plot(
    10000 * x$signal_overnight_excess,
    10000 * x$control_overnight_excess,
    pch = 19, col = "#3D8DFF88",
    xlab = "Signal overnight excess (bp)",
    ylab = "Matched control overnight excess (bp)",
    main = "Overnight reaction match"
  )
  abline(0, 1, col = "#0F172A", lty = 2)
  plot(
    10000 * x$signal_intraday_excess,
    10000 * x$control_intraday_excess,
    pch = 19, col = "#0F766E88",
    xlab = "Signal intraday excess (bp)",
    ylab = "Matched control intraday excess (bp)",
    main = "Intraday confirmation match"
  )
  abline(0, 1, col = "#0F172A", lty = 2)
  dev.off()
}

plot_match_support <- function(diagnostic, path) {
  counts <- table(factor(
    diagnostic$match_disposition,
    levels = c("matched", "no_same_issuer_zero_news_control", "outside_caliper")
  ))
  labels <- c("matched", "no same-issuer\nzero-news control", "outside\n0.50z caliper")
  png(path, width = 1500, height = 850, res = 150)
  par(mar = c(7, 7, 4, 2))
  bars <- barplot(
    counts,
    names.arg = labels,
    col = c("#166534", "#B91C1C", "#D97706"),
    ylab = "Retained signals",
    main = "The frozen zero-news control is too sparse"
  )
  text(bars, counts, labels = counts, pos = 3, cex = 0.85)
  dev.off()
}

plot_difference_distribution <- function(matches, path) {
  x <- matches[matches$matched, , drop = FALSE]
  values <- 10000 * x$matched_difference_h5
  png(path, width = 1500, height = 850, res = 150)
  par(mar = c(6, 7, 4, 2))
  hist(
    values,
    breaks = "FD",
    col = "#6DCBF4",
    border = "white",
    xlab = "Signal minus matched-control h5 excess continuation (bp)",
    ylab = "Matched observations",
    main = "The development effect is heterogeneous"
  )
  abline(v = 0, col = "#0F172A", lwd = 2)
  abline(v = mean(values), col = "#B91C1C", lwd = 2, lty = 2)
  legend("topright", legend = c("zero", "development mean"),
    col = c("#0F172A", "#B91C1C"), lty = c(1, 2), lwd = 2, bty = "n")
  dev.off()
}

representative_rows <- function(matches) {
  matched <- matches[matches$matched, , drop = FALSE]
  pieces <- lapply(unique(matched$fold_id), function(fold_id) {
    part <- matched[matched$fold_id == fold_id, , drop = FALSE]
    if (!nrow(part)) return(NULL)
    target <- c(
      stats::median(part$signal_overnight_excess),
      stats::median(part$signal_intraday_excess)
    )
    distance <- sqrt(
      (part$signal_overnight_excess - target[[1L]])^2 +
        (part$signal_intraday_excess - target[[2L]])^2
    )
    part[order(distance, part$signal_decision_session)[[1L]], , drop = FALSE]
  })
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  out
}

plot_representative_tapes <- function(representatives, cycles, path) {
  png(path, width = 2400, height = 1500, res = 150)
  par(mfrow = c(2, 3), mar = c(6, 5, 4, 2))
  for (i in seq_len(nrow(representatives))) {
    row <- representatives[i, , drop = FALSE]
    cycle <- cycles[
      cycles$issuer_id == row$issuer_id &
        cycles$decision_session == row$signal_decision_session,
      ,
      drop = FALSE
    ]
    values <- 10000 * c(
      row$signal_overnight_excess,
      row$signal_intraday_excess,
      row$signal_continuation_excess_h5,
      row$control_continuation_excess_h5
    )
    labels <- c("overnight", "intraday", "signal h5", "control h5")
    bars <- barplot(
      values,
      names.arg = labels,
      col = c("#3D8DFF", "#0F766E", "#166534", "#94A3B8"),
      las = 2,
      ylab = "SPY-relative return (bp)",
      main = paste0(
        row$fold_id, " | ", row$issuer_id, " | ",
        row$signal_decision_session, "\n",
        if (nrow(cycle)) cycle$novel_cluster_count else NA_integer_,
        " novel clusters"
      )
    )
    abline(h = 0, col = "#0F172A")
    text(bars, values, labels = sprintf("%.0f", values),
      pos = ifelse(values >= 0, 3, 1), cex = 0.72)
  }
  dev.off()
}

plot_gates <- function(audit, path) {
  labels <- c(
    "E0 integrity", "N1D authority", "Counts reproduced", "Bar coverage",
    "News TRAIN only", "Reaction timing", "Entry timing", "OOS outcome",
    "Frozen signal", "Overlap embargo", "Frozen controls", "Reaction TRAIN",
    "Signal support", "Match support", "No forbidden surface"
  )
  png(path, width = 1700, height = 1100, res = 150)
  par(mar = c(4, 12, 4, 2))
  y <- rev(seq_len(nrow(audit)))
  plot(c(0, 1), c(0.5, nrow(audit) + 0.5), type = "n", axes = FALSE,
    xlab = "", ylab = "", main = "Frozen E1 integrity and support gates")
  axis(2, at = y, labels = labels, las = 1)
  points(rep(0.5, nrow(audit)), y, pch = 19, cex = 3,
    col = ifelse(audit$status == "PASS", "#166534", "#B91C1C"))
  text(rep(0.5, nrow(audit)), y, labels = audit$status,
    col = "white", font = 2, cex = 0.62)
  dev.off()
}

message("Gen5.4 E1 event-reaction development diagnostic starting.")
run_id <- env_or("GEN5_GEN54_E1_RUN_ID", "g54_event_e1_20260727")
e0_run_id <- env_or("GEN5_GEN54_E1_E0_RUN_ID", "g54_event_e0_20260726")
n1d_run_id <- env_or("GEN5_GEN54_E1_N1D_RUN_ID", "g54_news_n1d_20260725")
refresh_bars <- env_bool("GEN5_GEN54_E1_REFRESH_BARS", FALSE)
as_of_timestamp <- env_or("GEN5_GEN54_E1_AS_OF_TIMESTAMP", "2026-07-25 17:30:00")
prospective_start <- as.Date(env_or("GEN5_GEN54_E1_SHADOW_START", "2026-07-27"))

base_dir <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine"
)
output_dir <- file.path(base_dir, run_id)
visual_dir <- file.path(output_dir, "visuals")
e0_dir <- file.path(base_dir, e0_run_id)
n1d_dir <- file.path(base_dir, n1d_run_id)
ensure_dir(visual_dir)

e0_spec <- read_required_csv(file.path(e0_dir, "e0_run_spec.csv"))
e0_audit <- read_required_csv(file.path(e0_dir, "e0_integrity_audit.csv"))
cycles <- read_required_csv(file.path(e0_dir, "e0_information_cycles.csv"))
n1d_spec <- read_required_csv(file.path(n1d_dir, "n1d_run_spec.csv"))
n1d_audit <- read_required_csv(file.path(n1d_dir, "n1d_leakage_audit.csv"))
n1d_oos <- read_required_csv(file.path(n1d_dir, "n1d_oos_measurements.csv"))
calendar <- read_required_csv(file.path(n1d_dir, "n1d_market_calendar.csv"))

cycles <- as_date_columns(cycles, c("decision_session", "execution_session"))
n1d_oos <- as_date_columns(
  n1d_oos,
  c(
    "decision_session", "execution_session", "train_start_date",
    "train_end_date", "oos_start_date", "oos_end_date",
    "normalizer_max_decision_session"
  )
)
calendar$session_date <- as.Date(calendar$session_date)

expected_folds <- c("2025Q1", "2025Q2", "2025Q3", "2025Q4", "2026Q1", "2026Q2")
n1d_oos <- n1d_oos[n1d_oos$fold_id %in% expected_folds, , drop = FALSE]
n1d_oos <- n1d_oos[
  order(n1d_oos$decision_session, n1d_oos$issuer_id),
  ,
  drop = FALSE
]
if (!"baseline_news_intensity_percentile" %in% names(n1d_oos)) {
  stop("N1D baseline equal-count percentile authority is missing.", call. = FALSE)
}

cycle_key <- paste(cycles$issuer_id, cycles$decision_session, sep = "\r")
oos_positive <- n1d_oos[n1d_oos$novel_cluster_count > 0, , drop = FALSE]
oos_key <- paste(oos_positive$issuer_id, oos_positive$decision_session, sep = "\r")
counts_reproduced <- !anyDuplicated(cycle_key) &&
  !anyDuplicated(oos_key) &&
  all(oos_key %in% cycle_key) &&
  all(
    cycles$novel_cluster_count[
      match(oos_key, cycle_key)
    ] == oos_positive$novel_cluster_count
  )
e0_passed <- identical(
  e0_spec$overall_status[[1L]],
  "PASS_E0_INFORMATION_CYCLES_READY_FOR_FEATURE_THEORY"
) && all(e0_audit$status == "PASS")
n1d_passed <- all(n1d_audit$status == "PASS")

issuer_registry <- g5_gen54_n1b_issuer_registry()
symbols <- sort(unique(c(
  setdiff(issuer_registry$provider_symbol, "FB"),
  "SPY"
)))
cfg <- g5_load_data_layer_config(repo_root)
message("Loading bounded adjusted OHLCV from the existing Alpaca cache.")
bar_query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = as.Date("2023-01-03"),
  end_date = as.Date("2026-06-30"),
  as_of_timestamp = as_of_timestamp,
  symbols = symbols,
  universe_name = "gen54_e1_event_reaction_v0_1",
  universe_roles = "issuer_reaction_development,market_adjustment",
  refresh = refresh_bars,
  repo_root = repo_root
)
if (!nrow(bar_query$bars)) stop("E1 adjusted-bar query returned no rows.", call. = FALSE)
issuer_bars <- g5_gen54_n1b_unify_bars(
  bar_query$bars[bar_query$bars$symbol != "SPY", , drop = FALSE],
  issuer_registry
)
spy_bars <- bar_query$bars[
  bar_query$bars$symbol == "SPY",
  c("session_date", "open", "close"),
  drop = FALSE
]
spy_bars$session_date <- as.Date(spy_bars$session_date)
issuer_coverage <- g5_gen54_n1b_validate_bar_coverage(
  issuer_bars,
  expected_issuers = sort(unique(issuer_registry$issuer_id)),
  expected_start = as.Date("2023-01-03"),
  expected_end = as.Date("2026-06-30")
)
spy_coverage_passed <- nrow(spy_bars) > 0L &&
  min(spy_bars$session_date) <= as.Date("2023-01-03") &&
  max(spy_bars$session_date) >= as.Date("2026-06-30")
adverse_health <- bar_query$health$category %in%
  c("empty_symbol", "missing_symbol", "refresh_needed", "partial_history")
bar_coverage_passed <- issuer_coverage$passed &&
  spy_coverage_passed &&
  !any(adverse_health)

folds <- g5_gen54_xs_build_folds(2025:2026)
folds <- folds[folds$fold_id %in% expected_folds, , drop = FALSE]
folds <- folds[match(expected_folds, folds$fold_id), , drop = FALSE]
panel <- g5_gen54_e1_attach_price_measurements(
  n1d_oos,
  issuer_bars,
  spy_bars,
  calendar$session_date,
  outcome_horizon = 5L
)
reaction_history <- g5_gen54_e1_reaction_history(
  issuer_bars,
  spy_bars,
  calendar$session_date
)
scaled <- g5_gen54_e1_attach_train_reaction_scales(
  panel,
  reaction_history,
  folds,
  minimum_train_rows = 100L
)
panel <- g5_gen54_e1_classify(scaled$panel, high_percentile = 0.80)
panel <- g5_gen54_e1_apply_overlap_embargo(panel)
matches <- g5_gen54_e1_match_controls(panel, caliper = 0.50)
fold_summary <- g5_gen54_e1_fold_summary(matches, expected_folds)
retained_for_diagnostic <- panel[panel$overlap_retained, , drop = FALSE]
match_support_rows <- lapply(seq_len(nrow(retained_for_diagnostic)), function(i) {
  signal <- retained_for_diagnostic[i, , drop = FALSE]
  candidates <- panel[
    panel$control_candidate &
      panel$issuer_id == signal$issuer_id &
      panel$fold_id == signal$fold_id,
    ,
    drop = FALSE
  ]
  overnight_difference <- abs(
    candidates$overnight_reaction_z - signal$overnight_reaction_z
  )
  intraday_difference <- abs(
    candidates$intraday_reaction_z - signal$intraday_reaction_z
  )
  in_caliper <- is.finite(overnight_difference) &
    is.finite(intraday_difference) &
    overnight_difference <= 0.50 &
    intraday_difference <= 0.50
  signal_id <- paste0(
    "e1_", signal$issuer_id, "_",
    format(signal$decision_session, "%Y%m%d")
  )
  matched_row <- matches[matches$signal_id == signal_id, , drop = FALSE]
  disposition <- if (nrow(matched_row) && matched_row$matched[[1L]]) {
    "matched"
  } else if (!nrow(candidates)) {
    "no_same_issuer_zero_news_control"
  } else {
    "outside_caliper"
  }
  data.frame(
    signal_id = signal_id,
    fold_id = signal$fold_id,
    issuer_id = signal$issuer_id,
    signal_decision_session = signal$decision_session,
    same_issuer_fold_control_candidates = nrow(candidates),
    in_caliper_control_candidates = sum(in_caliper),
    match_disposition = disposition,
    stringsAsFactors = FALSE
  )
})
match_support_diagnostic <- do.call(rbind, match_support_rows)

audit <- g5_gen54_e1_integrity_audit(
  panel = panel,
  matches = matches,
  scales = scaled$scales,
  e0_passed = e0_passed,
  n1d_passed = n1d_passed,
  counts_reproduced = counts_reproduced,
  bar_coverage_passed = bar_coverage_passed,
  forbidden_surface_count = 0L
)
overall_status <- if (all(audit$status == "PASS")) {
  "PASS_E1_DEVELOPMENT_MECHANICS_READY_FOR_PROSPECTIVE_SHADOW"
} else {
  "STOP_E1_DEVELOPMENT_MECHANICS"
}

matched <- matches[matches$matched, , drop = FALSE]
retained <- panel[panel$overlap_retained, , drop = FALSE]
funnel <- data.frame(
  stage = c(
    "OOS issuer-days", "TRAIN-p80 news", "positive overnight",
    "positive intraday", "raw signals", "non-overlap signals", "matched signals"
  ),
  count = c(
    nrow(panel),
    sum(panel$unusual_information_cycle),
    sum(panel$unusual_information_cycle & panel$positive_overnight_reaction),
    sum(
      panel$unusual_information_cycle &
        panel$positive_overnight_reaction &
        panel$positive_intraday_confirmation
    ),
    sum(panel$raw_signal),
    nrow(retained),
    nrow(matched)
  ),
  stringsAsFactors = FALSE
)
control_reuse <- if (nrow(matched)) {
  reuse <- aggregate(
    matched$signal_id,
    list(
      issuer_id = matched$issuer_id,
      control_decision_session = matched$control_decision_session
    ),
    length
  )
  names(reuse)[[3L]] <- "match_use_count"
  reuse
} else {
  data.frame(
    issuer_id = character(),
    control_decision_session = as.Date(character()),
    match_use_count = integer(),
    stringsAsFactors = FALSE
  )
}
representatives <- representative_rows(matches)

shadow_spec <- data.frame(
  schema_version = "gen54_event_reaction_shadow_v0.1",
  freeze_decision_date = as.Date("2026-07-27"),
  first_eligible_decision_session = prospective_start,
  historical_availability_authority = "provider_updated_at",
  prospective_availability_authority = "local_receipt_timestamp",
  unusual_cycle_rule = "issuer_local_frozen_equal_count_percentile_ge_0.80",
  initial_reaction = "issuer_minus_SPY_close_to_next_open_log_return_gt_0",
  confirmation = "issuer_minus_SPY_next_open_to_close_log_return_gt_0",
  earliest_entry = "following_session_open_after_confirmation_close",
  outcome = "five_session_entry_open_to_open_minus_SPY",
  overlap_rule = "suppress_entry_before_prior_issuer_endpoint",
  live_advice_change_count = 0L,
  stringsAsFactors = FALSE
)
shadow_status <- data.frame(
  as_of_timestamp = "2026-07-27 17:30:00 America/New_York",
  status = "READY_NO_MATURED_PROSPECTIVE_SIGNALS",
  observed_signal_count = 0L,
  matured_signal_count = 0L,
  detail = "The schema and frozen rules are ready; no prospective outcome is inferred at freeze.",
  stringsAsFactors = FALSE
)
health <- data.frame(
  severity = c(
    if (bar_coverage_passed) "INFO" else "ERROR",
    if (counts_reproduced) "INFO" else "ERROR",
    if (all(scaled$scales$support_ok)) "INFO" else "ERROR",
    if (all(audit$status == "PASS")) "INFO" else "ERROR",
    "INFO",
    "INFO"
  ),
  check_id = c(
    "adjusted_bar_coverage", "e0_n1d_count_reproduction",
    "train_reaction_scale_support", "e1_integrity_and_support",
    "historical_evidence_role", "prospective_shadow"
  ),
  value = c(
    as.character(sum(adverse_health)),
    as.character(counts_reproduced),
    as.character(sum(!scaled$scales$support_ok)),
    as.character(sum(audit$status != "PASS")),
    "development_only",
    shadow_status$status[[1L]]
  ),
  detail = c(
    "Material cache-health issues plus explicit issuer and SPY bounded coverage.",
    "Positive-cycle equal counts must agree across accepted E0 and N1D authority.",
    "Every issuer-fold needs at least 100 complete TRAIN reactions and positive MADs.",
    "All frozen leakage, timing, support, matching, and boundary gates.",
    "2025Q1-2026Q2 has prior news-representation exposure and cannot promote E1.",
    "Prospective accumulation begins after the freeze; an empty initial shadow is expected."
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = "gen54_event_reaction_e1_v0.1",
  wrapper = "scripts/inspect/run_gen54_event_reaction_e1.R",
  contract = "docs/GEN5_4_EVENT_REACTION_E1_CONTRACT.md",
  run_id = run_id,
  source_e0_run_id = e0_run_id,
  source_n1d_run_id = n1d_run_id,
  as_of_timestamp = as_of_timestamp,
  development_start = as.Date("2025-01-01"),
  development_end = as.Date("2026-06-30"),
  prospective_shadow_start = prospective_start,
  fold_count = length(expected_folds),
  train_quarters = 8L,
  high_news_percentile = 0.80,
  control_caliper_robust_z = 0.50,
  outcome_horizon_sessions = 5L,
  retained_signal_count = nrow(retained),
  matched_signal_count = nrow(matched),
  sentiment_count = 0L,
  model_fit_count = 0L,
  threshold_search_count = 0L,
  portfolio_metric_count = 0L,
  live_advice_change_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "e1_run_spec.csv"))
write_csv(health, file.path(output_dir, "e1_health.csv"))
write_csv(audit, file.path(output_dir, "e1_integrity_audit.csv"))
write_csv(funnel, file.path(output_dir, "e1_signal_funnel.csv"))
write_csv(panel, file.path(output_dir, "e1_development_panel.csv"))
write_csv(scaled$scales, file.path(output_dir, "e1_train_reaction_scales.csv"))
write_csv(matches, file.path(output_dir, "e1_matched_controls.csv"))
write_csv(
  match_support_diagnostic,
  file.path(output_dir, "e1_match_support_diagnostic.csv")
)
write_csv(fold_summary, file.path(output_dir, "e1_fold_summary.csv"))
write_csv(control_reuse, file.path(output_dir, "e1_control_reuse.csv"))
write_csv(representatives, file.path(output_dir, "e1_representative_tape.csv"))
write_csv(bar_query$health, file.path(output_dir, "e1_bar_query_health.csv"))
write_csv(issuer_coverage$coverage, file.path(output_dir, "e1_issuer_bar_coverage.csv"))
write_csv(shadow_spec, file.path(output_dir, "e1_prospective_shadow_spec.csv"))
write_csv(shadow_status, file.path(output_dir, "e1_prospective_shadow_status.csv"))

plot_funnel(funnel, file.path(visual_dir, "e1_signal_funnel.png"))
plot_match_support(
  match_support_diagnostic,
  file.path(visual_dir, "e1_match_support.png")
)
plot_fold_readout(fold_summary, file.path(visual_dir, "e1_fold_readout.png"))
if (nrow(matched)) {
  plot_match_quality(matches, file.path(visual_dir, "e1_match_quality.png"))
  plot_difference_distribution(
    matches,
    file.path(visual_dir, "e1_matched_difference_distribution.png")
  )
  plot_representative_tapes(
    representatives,
    cycles,
    file.path(visual_dir, "e1_representative_event_reaction_tapes.png")
  )
}
plot_gates(audit, file.path(visual_dir, "e1_gate_summary.png"))

overall_mean_signal <- if (nrow(matched)) {
  mean(matched$signal_continuation_excess_h5)
} else {
  NA_real_
}
overall_mean_control <- if (nrow(matched)) {
  mean(matched$control_continuation_excess_h5)
} else {
  NA_real_
}
overall_mean_difference <- if (nrow(matched)) {
  mean(matched$matched_difference_h5)
} else {
  NA_real_
}
report <- c(
  "# Gen5.4 E1 Event-Reaction Development Readout",
  "",
  paste0("Status: `", overall_status, "`"),
  "",
  "## Question",
  "",
  "Does an unusual issuer information cycle followed by positive SPY-adjusted overnight reaction and positive next-session intraday confirmation show additional five-session continuation after the signal becomes executable?",
  "",
  "## Development readout",
  "",
  paste0("- Retained non-overlapping signals: `", nrow(retained), "`."),
  paste0("- Matched signals: `", nrow(matched), "` (`",
    sprintf("%.1f%%", if (nrow(retained)) 100 * nrow(matched) / nrow(retained) else 0),
    "`)."),
  paste0("- Issuer coverage: `", length(unique(retained$issuer_id)), " / 24`."),
  paste0("- Quarter coverage: `", length(unique(retained$fold_id)), " / 6`."),
  paste0("- Mean signal h5 SPY-relative continuation: `",
    sprintf("%.1f bp", 10000 * overall_mean_signal), "`."),
  paste0("- Mean zero-news matched-control continuation: `",
    sprintf("%.1f bp", 10000 * overall_mean_control), "`."),
  paste0("- Mean matched difference: `",
    sprintf("%.1f bp", 10000 * overall_mean_difference), "`."),
  paste0(
    "- Match-support dispositions: `",
    sum(match_support_diagnostic$match_disposition == "matched"), "` matched; `",
    sum(match_support_diagnostic$match_disposition ==
      "no_same_issuer_zero_news_control"),
    "` had no same-issuer zero-news control; `",
    sum(match_support_diagnostic$match_disposition == "outside_caliper"),
    "` had controls only outside the frozen caliper."
  ),
  "",
  "## Interpretation boundary",
  "",
  "The 2025Q1-2026Q2 readout is development evidence because this news archive has already informed earlier representation research. Its sign or magnitude cannot promote the hypothesis. E1 passes only if construction, timing, overlap, matching, and support mechanics are ready for prospective shadow accumulation.",
  "",
  "## Prospective shadow",
  "",
  paste0("- Freeze begins: `", prospective_start, "`."),
  "- Status: `READY_NO_MATURED_PROSPECTIVE_SIGNALS`.",
  "- Local news receipt time remains prospective availability authority.",
  "- No live-advice behavior changes.",
  "",
  "## Limitation",
  "",
  "- Historical news remains Benzinga-only.",
  "- The matched control reduces, but cannot eliminate, confounding from issuer state, volatility, and broader information not represented by admitted news.",
  "",
  "## Visuals",
  "",
  "- `visuals/e1_signal_funnel.png`",
  "- `visuals/e1_match_support.png`",
  "- `visuals/e1_fold_readout.png`",
  "- `visuals/e1_match_quality.png`",
  "- `visuals/e1_matched_difference_distribution.png`",
  "- `visuals/e1_representative_event_reaction_tapes.png`",
  "- `visuals/e1_gate_summary.png`"
)
writeLines(report, file.path(output_dir, "e1_report.md"), useBytes = TRUE)

message("Gen5.4 E1 complete: ", overall_status)
message("Report: ", normalizePath(file.path(output_dir, "e1_report.md"), winslash = "/"))
