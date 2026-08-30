# Test whether inefficient sideways movement adds discrimination beyond a
# generic negative-prior rebound. TRAIN only; post-2023 outcomes remain sealed.

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_direction.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "own_asset_return_geometry_atlas.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "return_geometry_wide_atlas.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "return_geometry_continuation_next_open_rule.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "return_geometry_continuation_20d_attribution.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "return_geometry_sideways_loss_rebound.R"))

source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
attribution_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_continuation_20d_attribution_20260829"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_sideways_loss_rebound_baseline_20260829"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

paths <- c(
  bars = file.path(source_dir, "wide_atlas_query_bars.csv"),
  registry = file.path(source_dir, "frozen_wide_atlas_registry.csv"),
  source_checks = file.path(source_dir, "wide_atlas_checks.csv"),
  attribution_checks = file.path(attribution_dir, "construction_checks.csv")
)
if (!all(file.exists(paths))) {
  rgsr_stop("The frozen atlas or sign-attribution packet is incomplete.")
}

contract <- rgsr_validate_contract()
bars <- utils::read.csv(paths[["bars"]], stringsAsFactors = FALSE, check.names = FALSE)
registry <- rgwa_validate_registry(utils::read.csv(
  paths[["registry"]], stringsAsFactors = FALSE, check.names = FALSE
))
source_checks <- utils::read.csv(paths[["source_checks"]], stringsAsFactors = FALSE)
attribution_checks <- utils::read.csv(paths[["attribution_checks"]], stringsAsFactors = FALSE)
if (any(source_checks$status != "PASS") || any(attribution_checks$status != "PASS")) {
  rgsr_stop("An inherited evidence packet contains a failed integrity check.")
}

ledgers <- setNames(vector("list", nrow(registry)), registry$symbol)
trade_rows <- summary_rows <- path_rows <- list()
for (i in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[i]]
  message(sprintf("[%03d/%03d] %s", i, nrow(registry), symbol))
  ledger <- rgwa_build_ledger(bars, symbol)
  ledgers[[symbol]] <- ledger
  study <- rgsr_build_asset_study(ledger, contract)
  trade_rows[[i]] <- study$trades
  summary <- rgsr_rule_summary(study$trades, contract)
  summary$symbol <- symbol
  summary$hold_sessions <- contract$hold_sessions
  summary_rows[[i]] <- summary
  if (nrow(study$trades)) {
    path_rows[[length(path_rows) + 1L]] <- rgcnor_build_trade_paths(ledger, study$trades)
  }
}

trades <- do.call(rbind, trade_rows)
asset_rule_summary <- do.call(rbind, summary_rows)
trade_paths <- do.call(rbind, path_rows)
rownames(trades) <- rownames(asset_rule_summary) <- rownames(trade_paths) <- NULL

trades <- merge(trades, registry, by = "symbol", all.x = TRUE, sort = FALSE)
trades <- trades[order(trades$atlas_order, trades$rule_id, trades$anchor_session), ]
asset_rule_summary <- merge(
  asset_rule_summary, registry, by = "symbol", all.x = TRUE, sort = FALSE
)
asset_rule_summary <- asset_rule_summary[order(
  asset_rule_summary$atlas_order, asset_rule_summary$rule_id
), ]

core_asset_rule_summary <- asset_rule_summary[
  asset_rule_summary$sector_balance_eligible, , drop = FALSE
]
core_trades <- trades[trades$sector_balance_eligible, , drop = FALSE]
sector_rule_summary <- rgca_group_rule_summary(core_asset_rule_summary, "sector")
sector_rule_summary <- sector_rule_summary[order(
  sector_rule_summary$sector,
  match(sector_rule_summary$rule_id, contract$rule_ids)
), ]
equal_sector_summary <- rgca_equal_sector_summary(sector_rule_summary)
equal_sector_summary <- equal_sector_summary[
  match(contract$rule_ids, equal_sector_summary$rule_id), , drop = FALSE
]
core_event_pooled_summary <- rgsr_event_pooled_summary(core_trades, contract)
atlas_event_pooled_summary <- rgsr_event_pooled_summary(trades, contract)
direct_readout <- rgsr_direct_readout(
  equal_sector_summary, core_event_pooled_summary
)
calendar_summary <- rgsr_calendar_summary(core_trades)

trade_paths <- merge(
  trade_paths,
  registry[c("symbol", "sector_balance_eligible", "atlas_order")],
  by = "symbol", all.x = TRUE, sort = FALSE
)
core_trade_paths <- trade_paths[trade_paths$sector_balance_eligible, , drop = FALSE]
path_keys <- interaction(
  core_trade_paths[c("rule_id", "held_session")], drop = TRUE, lex.order = TRUE
)
path_groups <- split(core_trade_paths, path_keys)
path_summary <- do.call(rbind, lapply(path_groups, function(x) data.frame(
  rule_id = x$rule_id[[1L]],
  held_session = x$held_session[[1L]],
  observations = nrow(x),
  mean_cumulative_open_log_return = mean(x$cumulative_open_log_return),
  median_cumulative_open_log_return = stats::median(x$cumulative_open_log_return),
  stringsAsFactors = FALSE
)))
rownames(path_summary) <- NULL
path_summary <- path_summary[order(
  match(path_summary$rule_id, contract$rule_ids), path_summary$held_session
), ]

nonoverlap_ok <- all(vapply(
  split(trades, interaction(trades$symbol, trades$rule_id, drop = TRUE)),
  function(x) {
    x <- x[order(x$anchor_index), ]
    nrow(x) < 2L || all(x$anchor_index[-1L] >= x$exit_index[-nrow(x)])
  }, logical(1)
))
rule_rows <- setNames(lapply(contract$rule_ids, function(rule_id) {
  trades[trades$rule_id == rule_id, , drop = FALSE]
}), contract$rule_ids)

checks <- data.frame(
  check_id = c(
    "inherited_atlas_checks", "inherited_attribution_checks", "registry_exact",
    "adjusted_daily_only", "analysis_boundary", "single_20d_hold",
    "asset_rule_rows", "core_asset_rule_rows", "sector_rule_rows",
    "primary_definition", "negative_all_definition", "trending_negative_definition",
    "sideways_all_definition", "state_partition", "next_open_entry",
    "fixed_20d_open_exit", "nonoverlap", "round_trip_cost",
    "calendar_boundary", "post_2023_sealed"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (all(attribution_checks$status == "PASS")) "PASS" else "FAIL",
    if (nrow(registry) == contract$inherited$inherited$expected_assets) "PASS" else "FAIL",
    if (all(as.logical(bars$adjusted)) && all(bars$timeframe == "1D")) "PASS" else "FAIL",
    if (max(trades$exit_session) <= contract$inherited$inherited$analysis_end) "PASS" else "FAIL",
    if (identical(unique(trades$hold_sessions), 20L)) "PASS" else "FAIL",
    if (nrow(asset_rule_summary) == contract$inherited$inherited$expected_assets * 4L) "PASS" else "FAIL",
    if (nrow(core_asset_rule_summary) == contract$inherited$inherited$expected_core_assets * 4L) "PASS" else "FAIL",
    if (nrow(sector_rule_summary) == contract$inherited$inherited$expected_sectors * 4L) "PASS" else "FAIL",
    if (all(rule_rows$SIDEWAYS_NEGATIVE$prior_20_log_return < 0 &
            rule_rows$SIDEWAYS_NEGATIVE$er20_state == contract$inherited$inherited$sideways_state)) "PASS" else "FAIL",
    if (all(rule_rows$NEGATIVE_ALL$prior_20_log_return < 0)) "PASS" else "FAIL",
    if (all(rule_rows$TRENDING_NEGATIVE$prior_20_log_return < 0 &
            rule_rows$TRENDING_NEGATIVE$er20_state == contract$inherited$inherited$trending_state)) "PASS" else "FAIL",
    if (all(rule_rows$SIDEWAYS_ALL$er20_state == contract$inherited$inherited$sideways_state)) "PASS" else "FAIL",
    if (all(rule_rows$SIDEWAYS_NEGATIVE$er20 < 0.30) &&
        all(rule_rows$TRENDING_NEGATIVE$er20 >= 0.30)) "PASS" else "FAIL",
    if (all(trades$entry_index == trades$anchor_index + 1L)) "PASS" else "FAIL",
    if (all(trades$exit_index == trades$entry_index + 20L)) "PASS" else "FAIL",
    if (nonoverlap_ok) "PASS" else "FAIL",
    if (max(abs((trades$gross_open_log_return - trades$net_open_log_return) - 0.001)) < 1e-12) "PASS" else "FAIL",
    if (all(calendar_summary$entry_year >= 2018L & calendar_summary$entry_year <= 2023L)) "PASS" else "FAIL",
    "PASS"
  ),
  detail = c(
    sprintf("%d/%d pass", sum(source_checks$status == "PASS"), nrow(source_checks)),
    sprintf("%d/%d pass", sum(attribution_checks$status == "PASS"), nrow(attribution_checks)),
    sprintf("%d frozen assets", nrow(registry)),
    "Alpaca adjusted daily OHLCV inherited from frozen packet",
    sprintf("latest executed exit %s", max(trades$exit_session)),
    "20 sessions only",
    sprintf("%d rows", nrow(asset_rule_summary)),
    sprintf("%d core rows", nrow(core_asset_rule_summary)),
    sprintf("%d sector rows", nrow(sector_rule_summary)),
    "R20 < 0 and ER20 < 0.30",
    "R20 < 0 regardless of ER20 state",
    "R20 < 0 and ER20 >= 0.30",
    "ER20 < 0.30 regardless of prior sign",
    "negative events split at the inherited ER20 0.30 cutoff",
    "entry open t+1", "exit after 20 complete open-to-open intervals",
    "one position per asset/rule; intervening signals ignored",
    "10 bp subtracted from every completed trade",
    "calendar summaries remain within 2018-2023 TRAIN",
    "no post-2023 query or outcome calculation"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
  rgsr_stop("One or more construction checks failed.")
}

value <- function(data, id, column, id_column = "rule_id") {
  data[data[[id_column]] == id, column, drop = TRUE][[1L]]
}
primary_equal_excess <- value(
  equal_sector_summary, "SIDEWAYS_NEGATIVE",
  "equal_sector_median_asset_excess_vs_unconditional"
)
primary_pooled_excess <- value(
  core_event_pooled_summary, "SIDEWAYS_NEGATIVE",
  "mean_net_excess_vs_unconditional"
)
lift_equal <- value(
  direct_readout, "sideways_negative_minus_negative_all",
  "equal_sector_net_difference", "contrast_id"
)
lift_pooled <- value(
  direct_readout, "sideways_negative_minus_negative_all",
  "event_pooled_net_difference", "contrast_id"
)
mechanism_readout <- if (
  primary_equal_excess > 0 && primary_pooled_excess > 0 &&
  lift_equal > 0 && lift_pooled > 0
) {
  "SIDEWAYS_GATE_ADDS_VALUE_OVER_NEGATIVE_ONLY_IN_TRAIN"
} else if (primary_equal_excess > 0 && primary_pooled_excess > 0) {
  "NEGATIVE_PRIOR_DRIVES_RESULT_SIDEWAYS_GATE_NOT_INCREMENTAL"
} else {
  "SIDEWAYS_LOSS_REBOUND_DOES_NOT_CLEAR_DRIFT_UNDER_BOTH_LENSES"
}
status <- data.frame(
  study_id = contract$study_id,
  status = "TRAIN_SIDEWAYS_LOSS_REBOUND_BASELINE_COMPLETE_STOP_BEFORE_RULE_OR_OOS",
  mechanism_readout = mechanism_readout,
  atlas_assets = contract$inherited$inherited$expected_assets,
  core_assets = contract$inherited$inherited$expected_core_assets,
  hold_sessions = contract$hold_sessions,
  post_2023_data = "SEALED",
  rule_selected = "NO",
  stringsAsFactors = FALSE
)
run_spec <- data.frame(
  study_id = contract$study_id,
  source_packet = normalizePath(source_dir, winslash = "/"),
  inherited_attribution_packet = normalizePath(attribution_dir, winslash = "/"),
  analysis_window = "2018-01-02 through 2023-12-29",
  anchor = "completed_close_t",
  entry = "open_t_plus_1",
  hold = "20_open_to_open_sessions",
  overlap_policy = "one_position_per_asset_per_rule_ignore_signals_until_exit",
  round_trip_cost_bps = contract$inherited$inherited$round_trip_cost_bps,
  primary = contract$primary_rule_id,
  controls = paste(setdiff(contract$rule_ids, contract$primary_rule_id), collapse = ";"),
  baseline = "unconditional_same_asset_20_session_open_to_open_drift",
  headline_aggregation = "asset_then_sector_median_then_equal_sector_median",
  inference = "none_descriptive_train_matched_control_mechanism_test",
  post_2023_status = "sealed",
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(status, file.path(output_dir, "status.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(trades, file.path(output_dir, "trade_ledger.csv"), row.names = FALSE)
utils::write.csv(asset_rule_summary, file.path(output_dir, "asset_rule_summary.csv"), row.names = FALSE)
utils::write.csv(sector_rule_summary, file.path(output_dir, "core_sector_rule_summary.csv"), row.names = FALSE)
utils::write.csv(equal_sector_summary, file.path(output_dir, "equal_sector_rule_summary.csv"), row.names = FALSE)
utils::write.csv(core_event_pooled_summary, file.path(output_dir, "core_event_pooled_rule_summary.csv"), row.names = FALSE)
utils::write.csv(atlas_event_pooled_summary, file.path(output_dir, "atlas_event_pooled_rule_summary.csv"), row.names = FALSE)
utils::write.csv(direct_readout, file.path(output_dir, "primary_vs_control_readout.csv"), row.names = FALSE)
utils::write.csv(calendar_summary, file.path(output_dir, "core_calendar_rule_summary.csv"), row.names = FALSE)
utils::write.csv(path_summary, file.path(output_dir, "trade_path_summary.csv"), row.names = FALSE)

rule_labels <- c(
  SIDEWAYS_NEGATIVE = "Sideways -R20",
  NEGATIVE_ALL = "Negative R20",
  TRENDING_NEGATIVE = "Trending -R20",
  SIDEWAYS_ALL = "Sideways all"
)
rule_colors <- c(
  SIDEWAYS_NEGATIVE = "#E9A23B", NEGATIVE_ALL = "#3B82F6",
  TRENDING_NEGATIVE = "#6B7280", SIDEWAYS_ALL = "#2A9D8F"
)

# Visual 1: matched controls against drift under both primary lenses.
lens_matrix <- rbind(
  equal_sector = 10000 * equal_sector_summary$equal_sector_median_asset_excess_vs_unconditional,
  event_pooled = 10000 * core_event_pooled_summary$mean_net_excess_vs_unconditional
)
png(file.path(visual_dir, "matched_control_excess_both_lenses.png"), width = 1500, height = 900, res = 150)
par(mar = c(8, 6, 5, 2))
barplot(lens_matrix, beside = TRUE,
        names.arg = unname(rule_labels[equal_sector_summary$rule_id]),
        col = c("#3B82F6", "#E9A23B"), border = NA, las = 2,
        ylab = "Net excess versus unconditional drift (bp/trade)",
        main = "Does the sideways-loss branch clear drift and its component controls?")
abline(h = 0, col = "#526273", lwd = 1.5)
legend("topright", legend = c("Equal-sector median", "Core event-pooled mean"),
       fill = c("#3B82F6", "#E9A23B"), bty = "n")
dev.off()

# Visual 2: incremental lift of the primary over each control.
lift_matrix <- rbind(
  equal_sector = 10000 * direct_readout$equal_sector_net_difference,
  event_pooled = 10000 * direct_readout$event_pooled_net_difference
)
control_labels <- c("Negative R20", "Trending -R20", "Sideways all")
png(file.path(visual_dir, "primary_lift_vs_controls.png"), width = 1450, height = 850, res = 150)
par(mar = c(7, 6, 5, 2))
barplot(lift_matrix, beside = TRUE, names.arg = control_labels,
        col = c("#3B82F6", "#E9A23B"), border = NA,
        ylab = "Sideways -R20 minus control (bp/trade)",
        main = "Incremental discrimination requires beating negative-only")
abline(h = 0, col = "#526273", lwd = 1.5)
legend("topright", legend = c("Equal-sector median", "Core event-pooled mean"),
       fill = c("#3B82F6", "#E9A23B"), bty = "n")
dev.off()

# Visual 3: sector breadth for primary and controls.
sector_levels <- sort(unique(sector_rule_summary$sector))
sector_matrix <- matrix(
  NA_real_, nrow = length(sector_levels), ncol = length(contract$rule_ids),
  dimnames = list(sector_levels, unname(rule_labels[contract$rule_ids]))
)
for (i in seq_len(nrow(sector_rule_summary))) {
  sector_matrix[sector_rule_summary$sector[[i]],
                rule_labels[[sector_rule_summary$rule_id[[i]]]]] <-
    10000 * sector_rule_summary$median_asset_excess_vs_unconditional[[i]]
}
png(file.path(visual_dir, "sector_matched_control_heatmap.png"), width = 1500, height = 1000, res = 150)
par(mar = c(8, 15, 5, 3))
limit <- max(abs(sector_matrix), na.rm = TRUE)
image(seq_len(ncol(sector_matrix)), seq_len(nrow(sector_matrix)), t(sector_matrix),
      axes = FALSE, xlab = "", ylab = "",
      main = "20-session excess versus drift by sector and rule (bp/trade)",
      col = grDevices::colorRampPalette(c("#B44738", "#F7F4EB", "#14866D"))(101),
      zlim = c(-limit, limit))
axis(1, at = seq_len(ncol(sector_matrix)), labels = colnames(sector_matrix), las = 2)
axis(2, at = seq_len(nrow(sector_matrix)), labels = rownames(sector_matrix), las = 1)
for (r in seq_len(nrow(sector_matrix))) for (c in seq_len(ncol(sector_matrix))) {
  text(c, r, sprintf("%+.0f", sector_matrix[r, c]), cex = 0.75)
}
box(); dev.off()

# Visual 4: calendar stability for the primary and negative-only control.
calendar_rules <- c("SIDEWAYS_NEGATIVE", "NEGATIVE_ALL")
years <- sort(unique(calendar_summary$entry_year))
calendar_matrix <- sapply(calendar_rules, function(rule_id) {
  x <- calendar_summary[calendar_summary$rule_id == rule_id, ]
  10000 * x$mean_net_excess_vs_unconditional[match(years, x$entry_year)]
})
colnames(calendar_matrix) <- unname(rule_labels[calendar_rules])
png(file.path(visual_dir, "calendar_primary_vs_negative_only.png"), width = 1450, height = 850, res = 150)
par(mar = c(6, 6, 5, 2))
barplot(t(calendar_matrix), beside = TRUE, names.arg = years,
        col = c("#E9A23B", "#3B82F6"), border = NA,
        ylab = "Core event-pooled excess versus drift (bp/trade)",
        main = "Calendar context: primary versus negative-only")
abline(h = 0, col = "#526273", lwd = 1.5)
legend("topright", legend = colnames(calendar_matrix),
       fill = c("#E9A23B", "#3B82F6"), bty = "n")
dev.off()

# Visual 5: path shape for all four deployable branches.
png(file.path(visual_dir, "matched_control_trade_paths.png"), width = 1500, height = 900, res = 150)
ylim <- range(100 * path_summary$mean_cumulative_open_log_return, finite = TRUE)
plot(NA, xlim = c(0, 20), ylim = ylim, xlab = "Held session",
     ylab = "Mean cumulative open-to-open log return (%)",
     main = "Path shape distinguishes the primary from its component controls")
abline(h = 0, col = "#B8C1CC")
for (rule_id in contract$rule_ids) {
  x <- path_summary[path_summary$rule_id == rule_id, ]
  lines(x$held_session, 100 * x$mean_cumulative_open_log_return,
        col = rule_colors[[rule_id]], lwd = 3)
}
legend("topleft", legend = unname(rule_labels[contract$rule_ids]),
       col = unname(rule_colors[contract$rule_ids]), lwd = 3, bty = "n")
dev.off()

# Visual 6: deterministic first primary and trending-negative events.
tape_specs <- data.frame(
  symbol = c("TSLA", "TSLA", "AMD", "AMD"),
  rule_id = c("SIDEWAYS_NEGATIVE", "TRENDING_NEGATIVE",
              "SIDEWAYS_NEGATIVE", "TRENDING_NEGATIVE"),
  stringsAsFactors = FALSE
)
png(file.path(visual_dir, "representative_rebound_trade_tapes.png"), width = 1600, height = 1100, res = 150)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
for (i in seq_len(nrow(tape_specs))) {
  symbol <- tape_specs$symbol[[i]]
  rule_id <- tape_specs$rule_id[[i]]
  x <- trades[trades$symbol == symbol & trades$rule_id == rule_id, , drop = FALSE]
  ledger <- ledgers[[symbol]]
  if (!nrow(x)) {
    plot.new(); title(main = paste(symbol, rule_labels[[rule_id]], "— no event")); next
  }
  trade <- x[1L, , drop = FALSE]
  lo <- max(1L, trade$anchor_index - 30L)
  hi <- min(nrow(ledger), trade$exit_index + 10L)
  segment <- ledger[lo:hi, ]
  plot(segment$session_date, segment$close, type = "l", lwd = 2, col = "#24364B",
       xlab = "Session", ylab = "Adjusted close",
       main = sprintf("%s %s: %+.1f%% net", symbol, rule_labels[[rule_id]],
                      100 * (exp(trade$net_open_log_return) - 1)))
  abline(v = as.numeric(trade$anchor_session), col = "#E9A23B", lwd = 2)
  abline(v = as.numeric(trade$entry_session), col = "#2A9D8F", lwd = 2)
  abline(v = as.numeric(trade$exit_session), col = "#3B82F6", lwd = 2)
}
dev.off()

fmt_pct <- function(x) sprintf("%+.2f%%", 100 * x)
fmt_bp <- function(x) sprintf("%+.1f bp", 10000 * x)
report <- c(
  "# Sideways Loss Rebound Matched-Control Baseline (2018-2023 TRAIN)", "",
  "## Question", "",
  "Does a negative prior 20-session return inside causal ER20-sideways movement contain incremental rebound information beyond negative R20 alone, trending negative R20, sideways state alone, and unconditional drift?", "",
  "## Frozen slice", "",
  "- Primary: R20 < 0 and ER20 < 0.30 at completed close t.",
  "- Controls: negative R20 regardless of state; negative R20 with ER20 >= 0.30; sideways state regardless of sign; unconditional same-asset 20-session drift.",
  "- Enter at open t+1; exit after 20 held sessions; ignore overlapping signals within each rule; subtract 10 bp.",
  "- Keep all 129 instruments visible and the 88-stock equal-sector core primary. Post-2023 remains sealed.", "",
  "## Primary and matched controls", ""
)
for (rule_id in contract$rule_ids) {
  eq <- equal_sector_summary[equal_sector_summary$rule_id == rule_id, ]
  pool <- core_event_pooled_summary[core_event_pooled_summary$rule_id == rule_id, ]
  report <- c(report, sprintf(
    "- `%s`: net %s; equal-sector excess %s; core event-pooled excess %s; %d/11 positive-excess sectors; %d core trades.",
    rule_labels[[rule_id]],
    fmt_pct(eq$equal_sector_median_asset_mean_net_log_return),
    fmt_bp(eq$equal_sector_median_asset_excess_vs_unconditional),
    fmt_bp(pool$mean_net_excess_vs_unconditional),
    eq$positive_excess_sectors, pool$trades
  ))
}
report <- c(report, "", "## Incremental discrimination", "")
for (i in seq_len(nrow(direct_readout))) {
  x <- direct_readout[i, ]
  report <- c(report, sprintf(
    "- `%s`: %s equal-sector and %s core event-pooled.",
    x$contrast_id, fmt_bp(x$equal_sector_net_difference),
    fmt_bp(x$event_pooled_net_difference)
  ))
}
primary_calendar <- calendar_summary[
  calendar_summary$rule_id == contract$primary_rule_id, , drop = FALSE
]
report <- c(
  report, "", "## Calendar context", "",
  sprintf("- Primary positive-excess TRAIN years: %d/%d.",
          sum(primary_calendar$mean_net_excess_vs_unconditional > 0),
          nrow(primary_calendar)),
  "- Calendar rows are descriptive stability context, not a new gate or permission to select favorable years.", "",
  "## Interpretation", "",
  paste0("Frozen mechanism readout: `", mechanism_readout, "`."), "",
  "Each rule uses its own executable nonoverlap clock. Contrasts therefore compare deployable rule populations; they are not an algebraic decomposition or causal treatment effect of ER20 state.", "",
  "## Status", "",
  "`TRAIN_SIDEWAYS_LOSS_REBOUND_BASELINE_COMPLETE_STOP_BEFORE_RULE_OR_OOS`", "",
  "Huddle before choosing a candidate rule identity, adding severity, changing the 20-session horizon, or opening post-2023 outcomes.", "",
  "## Artifacts", "",
  "- `equal_sector_rule_summary.csv` and `core_event_pooled_rule_summary.csv`: primary and controls.",
  "- `primary_vs_control_readout.csv`: direct incremental comparisons.",
  "- `core_sector_rule_summary.csv` and `core_calendar_rule_summary.csv`: breadth and temporal context.",
  "- `trade_ledger.csv`, `trade_path_summary.csv`, and `visuals/`: mechanics and operator-facing evidence.",
  "- `construction_checks.csv`: timing, cost, state, universe, and boundary audit."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: ", status$status)
message("Mechanism readout: ", mechanism_readout)
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
