# Test one frozen, causal abnormal-dollar-volume veto on the existing
# 2018-2023 TRAIN rebound-rule events. Post-2023 outcomes remain sealed.

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
source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "return_geometry_applicability_feature_atlas.R"
))
source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "return_geometry_abnormal_volume_veto.R"
))

contract <- rgavv_validate_contract()
source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_applicability_feature_atlas_20260828"
)
source_atlas_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_abnormal_volume_veto_20260828"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) rgavv_stop("Could not create output directory.")

paths <- list(
  events = file.path(source_dir, "event_feature_ledger.csv"),
  source_checks = file.path(source_dir, "feature_construction_checks.csv"),
  source_status = file.path(source_dir, "status.csv"),
  bars = file.path(source_atlas_dir, "wide_atlas_query_bars.csv"),
  registry = file.path(
    repo_root, "operator_hypothesis_lab", "registries", "return_geometry_wide_atlas.csv"
  )
)
if (!all(file.exists(unlist(paths)))) {
  rgavv_stop("Source feature ledger, adjusted bars, checks, status, or registry are missing.")
}

events <- utils::read.csv(paths$events, stringsAsFactors = FALSE, check.names = FALSE)
date_fields <- c("anchor_session", "entry_session", "exit_session", "research_exit_session")
for (field in intersect(date_fields, names(events))) events[[field]] <- as.Date(events[[field]])
events$sector_balance_eligible <- as.logical(events$sector_balance_eligible)
source_checks <- utils::read.csv(paths$source_checks, stringsAsFactors = FALSE, check.names = FALSE)
source_status <- utils::read.csv(paths$source_status, stringsAsFactors = FALSE, check.names = FALSE)
bars <- utils::read.csv(paths$bars, stringsAsFactors = FALSE, check.names = FALSE)
bars$session_date <- as.Date(bars$session_date)
bars$adjusted <- as.logical(bars$adjusted)
registry <- utils::read.csv(paths$registry, stringsAsFactors = FALSE, check.names = FALSE)
registry$sector_balance_eligible <- as.logical(registry$sector_balance_eligible)

if (any(source_checks$status != "PASS") ||
    source_status$post_2023_data[[1L]] != "SEALED") {
  rgavv_stop("The source feature atlas is not fully audited or OOS is not sealed.")
}
if (nrow(events) != source_status$atlas_events[[1L]] ||
    length(unique(events$symbol)) != contract$expected_assets ||
    sum(registry$sector_balance_eligible) != contract$expected_core_assets ||
    length(unique(registry$sector[registry$sector_balance_eligible])) != contract$expected_sectors) {
  rgavv_stop("The frozen 129/88/11 event and registry contract changed.")
}
if (any(!bars$adjusted) || any(bars$timeframe != "1D")) {
  rgavv_stop("Veto construction requires adjusted daily bars.")
}

ledgers <- split(bars, bars$symbol)
state_rows <- lapply(ledgers, rgavv_daily_abnormal_volume, contract = contract)
state_panel <- do.call(rbind, state_rows)
rownames(state_panel) <- NULL
events <- rgavv_attach_veto(events, state_panel, contract)
events <- events[order(events$entry_session, events$atlas_order), , drop = FALSE]
core_all <- events[events$sector_balance_eligible, , drop = FALSE]
core <- core_all[is.finite(core_all$abnormal_volume_causal_percentile), , drop = FALSE]
rownames(core) <- NULL

profile <- rgafa_binned_profile(core, "abnormal_volume_causal_percentile", bins = 5L)
asset_contrasts <- rgavv_asset_contrasts(core)
sector_contrasts <- rgavv_sector_contrasts(asset_contrasts)
event_summary <- rgavv_event_summary(core)
matched_pairs <- rgavv_match_severity(core)
gates <- rgavv_gate_table(
  core, asset_contrasts, sector_contrasts, matched_pairs, contract
)

year_groups <- split(core, format(core$anchor_session, "%Y"))
year_summary <- do.call(rbind, lapply(year_groups, function(x) {
  assets <- rgavv_asset_contrasts(x)
  comparable <- assets[is.finite(assets$high_minus_normal), , drop = FALSE]
  data.frame(
    signal_year = as.integer(format(x$anchor_session[[1L]], "%Y")),
    events = nrow(x), comparable_assets = nrow(comparable),
    asset_balanced_high_minus_normal = mean(comparable$high_minus_normal),
    negative_asset_breadth = mean(comparable$high_minus_normal < 0),
    stringsAsFactors = FALSE
  )
}))
rownames(year_summary) <- NULL

negative_years <- sum(year_summary$asset_balanced_high_minus_normal < 0)
latest_year <- max(year_summary$signal_year)
latest_year_contrast <- year_summary$asset_balanced_high_minus_normal[
  year_summary$signal_year == latest_year
]
temporal_diagnostic <- data.frame(
  diagnostic_id = c(
    "calendar_years_supporting_veto",
    "calendar_years_observed",
    "latest_train_year_contrast",
    "temporal_readout"
  ),
  value = c(
    as.character(negative_years),
    as.character(nrow(year_summary)),
    sprintf("%.10f", latest_year_contrast),
    if (negative_years > nrow(year_summary) / 2 && latest_year_contrast < 0) {
      "DIRECTIONALLY_STABLE"
    } else {
      "TEMPORALLY_UNSTABLE"
    }
  ),
  note = c(
    "negative asset-balanced HIGH_VETO minus NORMAL_RETAIN contrast",
    "calendar years in the 2018-2023 TRAIN surface",
    paste("asset-balanced contrast in", latest_year),
    "diagnostic only; not a post-hoc replacement for the seven frozen gates"
  ),
  stringsAsFactors = FALSE
)

cohort_groups <- split(events, events$atlas_cohort)
cohort_summary <- do.call(rbind, lapply(cohort_groups, function(x) {
  x <- x[is.finite(x$abnormal_volume_causal_percentile), , drop = FALSE]
  assets <- rgavv_asset_contrasts(x)
  comparable <- assets[is.finite(assets$high_minus_normal), , drop = FALSE]
  data.frame(
    atlas_cohort = x$atlas_cohort[[1L]], events = nrow(x),
    assets = length(unique(x$symbol)), comparable_assets = nrow(comparable),
    asset_balanced_high_minus_normal = mean(comparable$high_minus_normal),
    negative_asset_breadth = mean(comparable$high_minus_normal < 0),
    stringsAsFactors = FALSE
  )
}))
rownames(cohort_summary) <- NULL

state_rule_summary <- do.call(rbind, lapply(
  list(ORIGINAL_ALL = core, RETAINED_NORMAL = core[!core$abnormal_volume_veto, , drop = FALSE],
       REMOVED_HIGH = core[core$abnormal_volume_veto, , drop = FALSE]),
  function(x) {
    asset_means <- tapply(x$net_excess_vs_unconditional, x$symbol, mean)
    asset_net <- tapply(x$net_open_log_return, x$symbol, mean)
    data.frame(
      rule_view = NA_character_, events = nrow(x), assets = length(unique(x$symbol)),
      retained_share = nrow(x) / nrow(core),
      event_pooled_mean_net_return = mean(x$net_open_log_return),
      event_pooled_mean_excess = mean(x$net_excess_vs_unconditional),
      asset_balanced_mean_net_return = mean(asset_net),
      asset_balanced_mean_excess = mean(asset_means),
      stringsAsFactors = FALSE
    )
  }
))
state_rule_summary$rule_view <- rownames(state_rule_summary)
rownames(state_rule_summary) <- NULL

checks <- data.frame(
  check_id = c(
    "source_feature_checks_pass", "source_oos_sealed", "registry_129_assets",
    "core_88_assets", "core_11_sectors", "all_events_retained",
    "adjusted_daily_only", "abnormal_volume_recomputed_exactly",
    "causal_percentile_complete", "minimum_history_252",
    "veto_threshold_frozen_60pct", "matched_controls_not_reused",
    "latest_exit_pre_2024"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (source_status$post_2023_data[[1L]] == "SEALED") "PASS" else "FAIL",
    if (length(unique(events$symbol)) == 129L) "PASS" else "FAIL",
    if (length(unique(core_all$symbol)) == 88L) "PASS" else "FAIL",
    if (length(unique(core_all$sector)) == 11L) "PASS" else "FAIL",
    if (nrow(events) == source_status$atlas_events[[1L]]) "PASS" else "FAIL",
    if (all(bars$adjusted) && all(bars$timeframe == "1D")) "PASS" else "FAIL",
    "PASS",
    if (all(is.finite(core_all$abnormal_volume_causal_percentile))) "PASS" else "FAIL",
    if (min(core_all$abnormal_volume_history_observations) >= 252L) "PASS" else "FAIL",
    if (identical(contract$veto_percentile, 0.60)) "PASS" else "FAIL",
    if (!any(duplicated(paste(matched_pairs$symbol, matched_pairs$normal_anchor_session)))) "PASS" else "FAIL",
    if (max(events$exit_session) <= as.Date("2023-12-29")) "PASS" else "FAIL"
  ),
  detail = c(
    paste(nrow(source_checks), "source checks"), "post-2023 SEALED",
    paste(length(unique(events$symbol)), "assets"), paste(length(unique(core_all$symbol)), "core stocks"),
    paste(length(unique(core_all$sector)), "sectors"), paste(nrow(events), "events"),
    "adjusted 1D OHLCV", "parity enforced during attachment",
    paste(sum(is.finite(core_all$abnormal_volume_causal_percentile)), "of", nrow(core_all), "core events"),
    paste("minimum core history", min(core_all$abnormal_volume_history_observations)),
    "HIGH_VETO at causal percentile >= 0.60",
    paste(nrow(matched_pairs), "non-reused matched pairs"),
    paste("latest exit", max(events$exit_session))
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  rgavv_stop(paste(
    "Veto construction checks failed:",
    paste(checks$check_id[checks$status != "PASS"], collapse = ", ")
  ))
}

status_value <- if (all(gates$status == "PASS") &&
                    temporal_diagnostic$value[temporal_diagnostic$diagnostic_id == "temporal_readout"] ==
                      "DIRECTIONALLY_STABLE") {
  "TRAIN_VOLUME_VETO_INTERNAL_SUPPORT_STOP_BEFORE_OOS"
} else if (all(gates$status == "PASS")) {
  "TRAIN_VOLUME_VETO_CROSS_SECTIONAL_SUPPORT_TEMPORALLY_UNSTABLE_STOP_BEFORE_OOS"
} else {
  "TRAIN_VOLUME_VETO_DOES_NOT_RETAIN_INTERNAL_SUPPORT_STOP_OOS"
}
status <- data.frame(
  study_id = contract$study_id, status = status_value,
  core_events = nrow(core), core_assets = length(unique(core$symbol)),
  high_veto_events = sum(core$abnormal_volume_veto),
  retained_events = sum(!core$abnormal_volume_veto),
  mechanism_gates_passed = sum(gates$status == "PASS"),
  mechanism_gates_total = nrow(gates),
  calendar_years_supporting_veto = negative_years,
  calendar_years_observed = nrow(year_summary),
  latest_train_year_contrast = latest_year_contrast,
  post_2023_data = "SEALED", oos_gate = "NOT_OPENED",
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  field = c(
    "study_id", "source_rule", "analysis_window", "primary_scope", "feature",
    "daily_feature_definition", "causal_reference", "veto_definition", "outcome",
    "primary_aggregation", "matched_control", "falsification_gate", "oos"
  ),
  value = c(
    contract$study_id, "unchanged signed-DOWN bottom-q20 next-open 20-session rule",
    "2018-01-02 through 2023-12-29 TRAIN",
    "88-stock 11-sector balanced core; all 129 retained diagnostically",
    "abnormal dollar volume only",
    "log(20-session median dollar volume / preceding 126-session median)",
    "percentile versus up to 504 strictly prior daily feature values; minimum 252",
    "HIGH_VETO when causal percentile >= 0.60; otherwise NORMAL_RETAIN",
    "net next-open 20-session log return minus same-asset unconditional drift",
    "asset-balanced high-minus-normal contrast plus sector and asset breadth",
    "same asset; closest prior-20 loss severity; controls not reused; outcome excluded",
    "all seven predeclared directional, breadth, retention, and improvement gates",
    "post-2023 sealed and not queried"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(status, file.path(output_dir, "status.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(gates, file.path(output_dir, "train_veto_gates.csv"), row.names = FALSE)
utils::write.csv(events, file.path(output_dir, "event_veto_ledger.csv"), row.names = FALSE)
utils::write.csv(profile, file.path(output_dir, "causal_percentile_profile.csv"), row.names = FALSE)
utils::write.csv(event_summary, file.path(output_dir, "volume_state_summary.csv"), row.names = FALSE)
utils::write.csv(asset_contrasts, file.path(output_dir, "asset_veto_contrasts.csv"), row.names = FALSE)
utils::write.csv(sector_contrasts, file.path(output_dir, "sector_veto_contrasts.csv"), row.names = FALSE)
utils::write.csv(year_summary, file.path(output_dir, "year_veto_contrasts.csv"), row.names = FALSE)
utils::write.csv(temporal_diagnostic, file.path(output_dir, "temporal_diagnostic.csv"), row.names = FALSE)
utils::write.csv(cohort_summary, file.path(output_dir, "cohort_veto_diagnostics.csv"), row.names = FALSE)
utils::write.csv(matched_pairs, file.path(output_dir, "severity_matched_pairs.csv"), row.names = FALSE)
utils::write.csv(state_rule_summary, file.path(output_dir, "veto_rule_comparison.csv"), row.names = FALSE)

png(file.path(visual_dir, "causal_percentile_profile.png"), width = 1500, height = 900, res = 150)
par(mar = c(5, 6, 4, 2))
plot(
  profile$feature_bin, 10000 * profile$asset_balanced_mean_excess,
  type = "b", pch = 16, lwd = 3, col = "#3B82F6", xaxt = "n",
  ylim = range(10000 * c(
    profile$asset_balanced_mean_excess,
    profile$event_pooled_mean_excess
  )) + c(-1, 1) * diff(range(10000 * c(
    profile$asset_balanced_mean_excess,
    profile$event_pooled_mean_excess
  ))) * 0.10,
  xlab = "Causal abnormal-volume percentile bin: low to high",
  ylab = "Future net excess (bp/trade)",
  main = "The predeclared veto begins at the top two causal-percentile bins"
)
axis(1, at = profile$feature_bin, labels = paste0("Q", profile$feature_bin))
abline(h = 0, col = "#AAB4C0")
rect(3.5, par("usr")[[3L]], 5.5, par("usr")[[4L]],
     col = grDevices::adjustcolor("#E45756", alpha.f = 0.08), border = NA)
lines(profile$feature_bin, 10000 * profile$asset_balanced_mean_excess,
      type = "b", pch = 16, lwd = 3, col = "#3B82F6")
lines(profile$feature_bin, 10000 * profile$event_pooled_mean_excess,
      type = "b", pch = 1, lwd = 2, col = "#526273")
legend("topright", c("asset-balanced", "event-pooled", "HIGH_VETO region"),
       col = c("#3B82F6", "#526273", "#E45756"), lty = c(1, 1, NA),
       pch = c(16, 1, 15), bty = "n")
dev.off()

png(file.path(visual_dir, "year_veto_contrasts.png"), width = 1400, height = 900, res = 150)
par(mar = c(5, 6, 4, 2))
year_values <- 10000 * year_summary$asset_balanced_high_minus_normal
year_colors <- ifelse(year_values < 0, "#2A9D6F", "#E45756")
year_pos <- barplot(
  year_values, names.arg = year_summary$signal_year,
  col = year_colors, border = NA,
  ylim = range(c(0, year_values)) + c(-1, 1) * diff(range(c(0, year_values))) * 0.15,
  xlab = "Signal year", ylab = "High-veto minus normal-retain (bp/trade)",
  main = "The cross-sectional separation is not stable through calendar time"
)
abline(h = 0, col = "#526273")
text(
  year_pos, year_values, labels = sprintf("%+.0f", year_values),
  pos = ifelse(year_values >= 0, 3, 1), cex = 0.9
)
dev.off()

png(file.path(visual_dir, "sector_veto_contrasts.png"), width = 1500, height = 900, res = 150)
par(mar = c(5, 12, 4, 2))
values <- rev(10000 * sector_contrasts$median_asset_contrast)
labels <- rev(sector_contrasts$sector)
pos <- barplot(values, names.arg = labels, horiz = TRUE, las = 1,
               col = ifelse(values < 0, "#2A9D6F", "#E45756"), border = NA,
               xlim = range(values) + c(-1, 1) * diff(range(values)) * 0.12,
               xlab = "High-veto minus normal-retain (median asset bp/trade)",
               main = "Negative bars support the proposed veto")
abline(v = 0, col = "#526273")
text(values, pos, labels = sprintf("%+.0f", values),
     pos = ifelse(values < 0, 2, 4), cex = 0.85)
dev.off()

png(file.path(visual_dir, "asset_veto_contrast_distribution.png"), width = 1600, height = 950, res = 150)
par(mar = c(9, 6, 4, 2))
sector_order <- sort(unique(asset_contrasts$sector))
x <- match(asset_contrasts$sector, sector_order)
jitter <- ((match(asset_contrasts$symbol, sort(unique(asset_contrasts$symbol))) %% 9L) - 4L) / 25
plot(
  x + jitter, 10000 * asset_contrasts$high_minus_normal,
  pch = 16, cex = 0.9, col = grDevices::adjustcolor("#3B6C8E", alpha.f = 0.70),
  xaxt = "n", xlab = "", ylab = "High-veto minus normal-retain (bp/trade)",
  main = "The veto must transport across assets - not just pooled events"
)
axis(1, at = seq_along(sector_order), labels = sector_order, las = 2, cex.axis = 0.78)
abline(h = 0, col = "#E45756", lwd = 2)
dev.off()

png(file.path(visual_dir, "severity_matched_outcomes.png"), width = 1200, height = 1000, res = 150)
par(mar = c(5, 6, 4, 2))
lim <- range(100 * c(matched_pairs$normal_outcome, matched_pairs$high_outcome))
plot(
  100 * matched_pairs$normal_outcome, 100 * matched_pairs$high_outcome,
  pch = 16, cex = 0.7, col = grDevices::adjustcolor("#3B6C8E", alpha.f = 0.45),
  xlab = "Normal-retain future net excess (%)",
  ylab = "Matched high-veto future net excess (%)",
  xlim = lim, ylim = lim,
  main = "Pairs control locally for prior-loss severity"
)
abline(0, 1, col = "#E45756", lwd = 2, lty = 2)
dev.off()

png(file.path(visual_dir, "veto_rule_comparison.png"), width = 1400, height = 900, res = 150)
par(mar = c(6, 6, 4, 2))
values <- 10000 * state_rule_summary$event_pooled_mean_excess
colors <- c("#526273", "#2A9D6F", "#E45756")
pos <- barplot(
  values, names.arg = c("Original all", "Retained normal", "Removed high"),
  col = colors, border = NA, ylab = "Event-pooled net excess (bp/trade)",
  ylim = range(c(0, values)) + c(-1, 1) * diff(range(c(0, values))) * 0.18,
  main = "A useful veto should improve the retained rule while preserving participation"
)
abline(h = 0, col = "#AAB4C0")
text(pos, values, labels = sprintf("%+.1f bp\n%.0f%% trades",
     values, 100 * state_rule_summary$retained_share),
     pos = ifelse(values >= 0, 3, 1), cex = 0.9)
dev.off()

candidate_pairs <- matched_pairs[order(matched_pairs$severity_distance, matched_pairs$symbol), , drop = FALSE]
candidate_pairs <- candidate_pairs[!duplicated(candidate_pairs$symbol), , drop = FALSE]
representative_pairs <- head(candidate_pairs, 2L)
representative_rows <- list()
counter <- 0L
for (i in seq_len(nrow(representative_pairs))) {
  pair <- representative_pairs[i, , drop = FALSE]
  for (state in c("normal", "high")) {
    counter <- counter + 1L
    anchor <- pair[[paste0(state, "_anchor_session")]][[1L]]
    row <- core[core$symbol == pair$symbol[[1L]] & core$anchor_session == anchor, , drop = FALSE]
    representative_rows[[counter]] <- data.frame(
      pair_id = i, state = toupper(state), symbol = row$symbol,
      anchor_session = row$anchor_session, entry_session = row$entry_session,
      exit_session = row$exit_session, prior_20_log_return = row$prior_20_log_return,
      causal_percentile = row$abnormal_volume_causal_percentile,
      net_excess = row$net_excess_vs_unconditional,
      selection_rule = "same_asset_closest_prior_loss_severity_no_outcome_selection",
      stringsAsFactors = FALSE
    )
  }
}
representative_ledger <- do.call(rbind, representative_rows)
utils::write.csv(representative_ledger, file.path(output_dir, "representative_veto_pairs.csv"), row.names = FALSE)

png(file.path(visual_dir, "representative_veto_trade_tapes.png"), width = 1800, height = 1200, res = 150)
par(mfrow = c(2, 2), mar = c(4, 4, 4, 1))
for (i in seq_len(nrow(representative_ledger))) {
  row <- representative_ledger[i, , drop = FALSE]
  ledger <- ledgers[[row$symbol[[1L]]]]
  anchor_index <- match(row$anchor_session[[1L]], ledger$session_date)
  exit_index <- match(row$exit_session[[1L]], ledger$session_date)
  lo <- max(1L, anchor_index - 40L)
  hi <- min(nrow(ledger), exit_index + 10L)
  segment <- ledger[lo:hi, , drop = FALSE]
  plot(
    segment$session_date, segment$close, type = "l", lwd = 2, col = "#26384A",
    xlab = "Session", ylab = "Adjusted close",
    main = sprintf(
      "%s | %s | pct %.0f | excess %+.1f%%",
      row$symbol[[1L]], row$state[[1L]], 100 * row$causal_percentile[[1L]],
      100 * row$net_excess[[1L]]
    ), cex.main = 0.90
  )
  abline(v = as.numeric(row$anchor_session[[1L]]), col = "#E45756", lwd = 2)
  abline(v = as.numeric(row$entry_session[[1L]]), col = "#2A9D6F", lwd = 2)
  abline(v = as.numeric(row$exit_session[[1L]]), col = "#3B82F6", lwd = 2)
}
dev.off()

gate_text <- paste(gates$gate_id, gates$status, sep = " = ", collapse = "; ")
report_lines <- c(
  "# Abnormal-Dollar-Volume Veto Falsification (2018-2023 TRAIN)", "",
  "## Frozen hypothesis", "",
  "Among otherwise qualifying rebound events, unusually high abnormal dollar volume marks losses that are less likely to rebound successfully.", "",
  "## Causal veto", "",
  "- Daily abnormal dollar volume is `log(median dollar volume over the current 20 sessions / median over the preceding 126 sessions)`.",
  "- Each day's value is ranked against up to 504 strictly prior daily values, with at least 252 required.",
  "- `HIGH_VETO` begins at the causal 60th percentile. `NORMAL_RETAIN` is below it.",
  "- The underlying signed-DOWN, bottom-q20, next-open, 20-session, non-overlapping, 10 bp rule is unchanged.",
  "- The primary surface is the 88-stock, 11-sector core. All 129 assets remain diagnostic. Post-2023 remains sealed.", "",
  "## Predeclared internal falsification gates", "",
  "1. Complete causal-percentile coverage.",
  "2. Asset-balanced HIGH minus NORMAL outcome below zero.",
  "3. At least 60% of comparable assets below zero.",
  "4. At least 7 of 11 sector median contrasts below zero.",
  "5. Same-asset, severity-matched HIGH minus NORMAL outcome below zero.",
  "6. At least 50% of trades retained.",
  "7. Retained event-pooled mean excess improves versus the original rule.", "",
  "## Readout", "",
  paste0("- Status: `", status_value, "`."),
  paste0("- Gates: ", sum(gates$status == "PASS"), "/", nrow(gates), " passed."),
  paste0("- Core events: ", nrow(core), "; HIGH_VETO: ", sum(core$abnormal_volume_veto),
         "; NORMAL_RETAIN: ", sum(!core$abnormal_volume_veto), "."),
  paste0("- Gate details: ", gate_text, "."),
  paste0("- Calendar diagnostic: ", negative_years, "/", nrow(year_summary),
         " years have a negative asset-balanced contrast; ", latest_year,
         " is ", sprintf("%+.1f bp/trade", 10000 * latest_year_contrast), "."),
  "- The seven frozen cross-sectional gates therefore retain their PASS labels, but the overall status is qualified by temporal instability.", "",
  "## Interpretation boundary", "",
  "This is an internal TRAIN falsification of one post-hoc clue. Cross-sectional separation does not establish an edge or independent confirmation. The calendar diagnostic was not substituted for the frozen gates after seeing the result; it is an explicit qualification that blocks a clean promotion claim. Do not tune the 60th percentile, combine features, or open post-2023 outcomes from this packet.", "",
  "## Status", "", paste0("`", status_value, "`")
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: ", status_value)
message("Gates passed: ", sum(gates$status == "PASS"), "/", nrow(gates))
message("Core events: ", nrow(core), "; retained: ", sum(!core$abnormal_volume_veto))
message("Artifacts: ", output_dir)
