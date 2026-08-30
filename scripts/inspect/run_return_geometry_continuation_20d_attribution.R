# Attribute the frozen 20-session continuation clue to ER20 state versus prior
# return sign. This is a TRAIN-only next-open mechanism comparison. It reads
# inherited adjusted daily bars and does not query post-2023 data.

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
source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "return_geometry_continuation_next_open_rule.R"
))
source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "return_geometry_continuation_20d_attribution.R"
))

source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
prior_rule_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_continuation_next_open_rule_20260829"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_continuation_20d_attribution_20260829"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

paths <- c(
  bars = file.path(source_dir, "wide_atlas_query_bars.csv"),
  registry = file.path(source_dir, "frozen_wide_atlas_registry.csv"),
  source_checks = file.path(source_dir, "wide_atlas_checks.csv"),
  prior_rule_checks = file.path(prior_rule_dir, "construction_checks.csv")
)
if (!all(file.exists(paths))) {
  rgca_stop("The frozen atlas or prior next-open evidence packet is incomplete.")
}

contract <- rgca_validate_contract()
bars <- utils::read.csv(paths[["bars"]], stringsAsFactors = FALSE, check.names = FALSE)
registry <- rgwa_validate_registry(utils::read.csv(
  paths[["registry"]], stringsAsFactors = FALSE, check.names = FALSE
))
source_checks <- utils::read.csv(paths[["source_checks"]], stringsAsFactors = FALSE)
prior_rule_checks <- utils::read.csv(paths[["prior_rule_checks"]], stringsAsFactors = FALSE)
if (any(source_checks$status != "PASS") || any(prior_rule_checks$status != "PASS")) {
  rgca_stop("An inherited evidence packet contains a failed integrity check.")
}

ledgers <- setNames(vector("list", nrow(registry)), registry$symbol)
trade_rows <- summary_rows <- path_rows <- list()
trade_index <- summary_index <- path_index <- 0L
for (i in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[i]]
  message(sprintf("[%03d/%03d] %s", i, nrow(registry), symbol))
  ledger <- rgwa_build_ledger(bars, symbol)
  ledgers[[symbol]] <- ledger
  study <- rgca_build_asset_study(ledger, contract)

  trade_index <- trade_index + 1L
  trade_rows[[trade_index]] <- study$trades

  summary <- rgca_rule_summary(study$trades, contract)
  summary$symbol <- symbol
  summary$hold_sessions <- contract$hold_sessions
  summary_index <- summary_index + 1L
  summary_rows[[summary_index]] <- summary

  if (nrow(study$trades)) {
    path_index <- path_index + 1L
    path_rows[[path_index]] <- rgcnor_build_trade_paths(ledger, study$trades)
  }
}

trades <- do.call(rbind, trade_rows)
asset_rule_summary <- do.call(rbind, summary_rows)
trade_paths <- do.call(rbind, path_rows)
rownames(trades) <- rownames(asset_rule_summary) <- rownames(trade_paths) <- NULL

trades <- merge(trades, registry, by = "symbol", all.x = TRUE, sort = FALSE)
trades <- trades[order(
  trades$atlas_order, trades$rule_id, trades$anchor_session
), , drop = FALSE]
asset_rule_summary <- merge(
  asset_rule_summary, registry, by = "symbol", all.x = TRUE, sort = FALSE
)
asset_rule_summary <- asset_rule_summary[order(
  asset_rule_summary$atlas_order, asset_rule_summary$rule_id
), , drop = FALSE]

core_asset_rule_summary <- asset_rule_summary[
  asset_rule_summary$sector_balance_eligible, , drop = FALSE
]
core_trades <- trades[trades$sector_balance_eligible, , drop = FALSE]
sector_rule_summary <- rgca_group_rule_summary(
  core_asset_rule_summary, "sector"
)
sector_rule_summary <- sector_rule_summary[order(
  sector_rule_summary$sector,
  match(sector_rule_summary$rule_id, contract$rule_ids)
), , drop = FALSE]
equal_sector_summary <- rgca_equal_sector_summary(sector_rule_summary)
equal_sector_summary <- equal_sector_summary[
  match(contract$rule_ids, equal_sector_summary$rule_id), , drop = FALSE
]
core_event_pooled_summary <- rgca_event_pooled_summary(core_trades, contract)
atlas_event_pooled_summary <- rgca_event_pooled_summary(trades, contract)
pairwise_readout <- rgca_pairwise_readout(
  equal_sector_summary, core_event_pooled_summary
)

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
), , drop = FALSE]

nonoverlap_ok <- all(vapply(
  split(trades, interaction(trades$symbol, trades$rule_id, drop = TRUE)),
  function(x) {
    x <- x[order(x$anchor_index), ]
    nrow(x) < 2L || all(x$anchor_index[-1L] >= x$exit_index[-nrow(x)])
  }, logical(1)
))

rule_rows <- lapply(contract$rule_ids, function(rule_id) {
  trades[trades$rule_id == rule_id, , drop = FALSE]
})
names(rule_rows) <- contract$rule_ids
checks <- data.frame(
  check_id = c(
    "inherited_atlas_checks", "inherited_rule_checks", "registry_exact",
    "adjusted_daily_only", "analysis_boundary", "single_20d_hold",
    "asset_rule_rows", "core_asset_rule_rows", "sector_rule_rows",
    "sideways_all_definition", "sideways_positive_definition",
    "sideways_negative_definition", "trending_all_definition",
    "next_open_entry", "fixed_20d_open_exit", "nonoverlap",
    "round_trip_cost", "post_2023_sealed"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (all(prior_rule_checks$status == "PASS")) "PASS" else "FAIL",
    if (nrow(registry) == contract$inherited$expected_assets) "PASS" else "FAIL",
    if (all(as.logical(bars$adjusted)) && all(bars$timeframe == "1D")) "PASS" else "FAIL",
    if (max(trades$exit_session) <= contract$inherited$analysis_end) "PASS" else "FAIL",
    if (identical(unique(trades$hold_sessions), 20L)) "PASS" else "FAIL",
    if (nrow(asset_rule_summary) == contract$inherited$expected_assets * 4L) "PASS" else "FAIL",
    if (nrow(core_asset_rule_summary) == contract$inherited$expected_core_assets * 4L) "PASS" else "FAIL",
    if (nrow(sector_rule_summary) == contract$inherited$expected_sectors * 4L) "PASS" else "FAIL",
    if (all(rule_rows$SIDEWAYS_ALL$er20_state == contract$inherited$sideways_state)) "PASS" else "FAIL",
    if (all(rule_rows$SIDEWAYS_POSITIVE$er20_state == contract$inherited$sideways_state &
            rule_rows$SIDEWAYS_POSITIVE$prior_20_log_return > 0)) "PASS" else "FAIL",
    if (all(rule_rows$SIDEWAYS_NEGATIVE$er20_state == contract$inherited$sideways_state &
            rule_rows$SIDEWAYS_NEGATIVE$prior_20_log_return < 0)) "PASS" else "FAIL",
    if (all(rule_rows$TRENDING_ALL$er20_state == contract$inherited$trending_state)) "PASS" else "FAIL",
    if (all(trades$entry_index == trades$anchor_index + 1L)) "PASS" else "FAIL",
    if (all(trades$exit_index == trades$entry_index + 20L)) "PASS" else "FAIL",
    if (nonoverlap_ok) "PASS" else "FAIL",
    if (max(abs((trades$gross_open_log_return - trades$net_open_log_return) - 0.001)) < 1e-12) "PASS" else "FAIL",
    "PASS"
  ),
  detail = c(
    sprintf("%d/%d pass", sum(source_checks$status == "PASS"), nrow(source_checks)),
    sprintf("%d/%d pass", sum(prior_rule_checks$status == "PASS"), nrow(prior_rule_checks)),
    sprintf("%d frozen assets", nrow(registry)),
    "Alpaca adjusted daily OHLCV inherited from frozen packet",
    sprintf("latest executed exit %s", max(trades$exit_session)),
    "20 sessions only",
    sprintf("%d expected %d", nrow(asset_rule_summary), contract$inherited$expected_assets * 4L),
    sprintf("%d expected %d", nrow(core_asset_rule_summary), contract$inherited$expected_core_assets * 4L),
    sprintf("%d expected %d", nrow(sector_rule_summary), contract$inherited$expected_sectors * 4L),
    "ER20 < 0.30 regardless of prior sign",
    "ER20 < 0.30 and R20 > 0",
    "ER20 < 0.30 and R20 < 0",
    "ER20 >= 0.30 regardless of prior sign",
    "entry open t+1",
    "exit after 20 complete open-to-open intervals",
    "one position per asset/rule; intervening signals ignored",
    "10 bp subtracted from each completed trade",
    "no post-2023 query or outcome calculation"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
  rgca_stop("One or more construction checks failed.")
}

get_value <- function(data, id, column, id_column = "rule_id") {
  data[data[[id_column]] == id, column, drop = TRUE][[1L]]
}
positive_excess <- get_value(
  equal_sector_summary, "SIDEWAYS_POSITIVE",
  "equal_sector_median_asset_excess_vs_unconditional"
)
negative_excess <- get_value(
  equal_sector_summary, "SIDEWAYS_NEGATIVE",
  "equal_sector_median_asset_excess_vs_unconditional"
)
positive_minus_negative <- get_value(
  pairwise_readout, "sideways_positive_minus_negative",
  "equal_sector_net_difference", id_column = "contrast_id"
)
mechanism_readout <- if (positive_excess > 0 && positive_minus_negative > 0) {
  "CONTINUATION_BRANCH_RETAINS_TRAIN_SUPPORT"
} else if (negative_excess > 0 && positive_minus_negative < 0) {
  "SIDEWAYS_RESULT_IS_REBOUND_LED_NOT_CONTINUATION"
} else {
  "NO_SIDEWAYS_SIGN_BRANCH_BEATS_DRIFT_CLEANLY"
}
status <- data.frame(
  study_id = contract$study_id,
  status = "TRAIN_20D_SIGN_STATE_ATTRIBUTION_COMPLETE_STOP_BEFORE_RULE_OR_OOS",
  mechanism_readout = mechanism_readout,
  atlas_assets = contract$inherited$expected_assets,
  core_assets = contract$inherited$expected_core_assets,
  hold_sessions = contract$hold_sessions,
  post_2023_data = "SEALED",
  rule_selected = "NO",
  portfolio_replay = "NOT_RUN",
  stringsAsFactors = FALSE
)
run_spec <- data.frame(
  study_id = contract$study_id,
  source_packet = normalizePath(source_dir, winslash = "/"),
  inherited_rule_packet = normalizePath(prior_rule_dir, winslash = "/"),
  analysis_window = "2018-01-02 through 2023-12-29",
  anchor = "completed_close_t",
  entry = "open_t_plus_1",
  hold = "20_open_to_open_sessions",
  overlap_policy = "one_position_per_asset_per_rule_ignore_signals_until_exit",
  round_trip_cost_bps = contract$inherited$round_trip_cost_bps,
  branches = paste(contract$rule_ids, collapse = ";"),
  baseline = "unconditional_same_asset_20_session_open_to_open_drift",
  headline_aggregation = "asset_then_sector_median_then_equal_sector_median",
  inference = "none_descriptive_train_mechanism_attribution",
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
utils::write.csv(pairwise_readout, file.path(output_dir, "pairwise_readout.csv"), row.names = FALSE)
utils::write.csv(path_summary, file.path(output_dir, "trade_path_summary.csv"), row.names = FALSE)

rule_labels <- c(
  SIDEWAYS_ALL = "Sideways all",
  SIDEWAYS_POSITIVE = "Sideways +R20",
  SIDEWAYS_NEGATIVE = "Sideways -R20",
  TRENDING_ALL = "Trending all"
)
rule_colors <- c(
  SIDEWAYS_ALL = "#2A9D8F",
  SIDEWAYS_POSITIVE = "#3B82F6",
  SIDEWAYS_NEGATIVE = "#E9A23B",
  TRENDING_ALL = "#6B7280"
)

# Visual 1: raw net and excess versus drift under the equal-sector lens.
net_values <- 10000 * equal_sector_summary$equal_sector_median_asset_mean_net_log_return
excess_values <- 10000 * equal_sector_summary$equal_sector_median_asset_excess_vs_unconditional
png(file.path(visual_dir, "equal_sector_branch_attribution.png"), width = 1600, height = 850, res = 150)
par(mfrow = c(1, 2), mar = c(8, 5, 5, 2))
barplot(net_values, names.arg = unname(rule_labels[equal_sector_summary$rule_id]),
        col = unname(rule_colors[equal_sector_summary$rule_id]), border = NA,
        las = 2, ylab = "Net return (bp/trade)", main = "Raw 20-session return")
abline(h = 0, col = "#526273", lwd = 1.5)
barplot(excess_values, names.arg = unname(rule_labels[equal_sector_summary$rule_id]),
        col = unname(rule_colors[equal_sector_summary$rule_id]), border = NA,
        las = 2, ylab = "Excess versus drift (bp/trade)", main = "Information above ordinary drift")
abline(h = 0, col = "#526273", lwd = 1.5)
mtext("One frozen 20-session hold separates state from prior-return sign", outer = TRUE, line = -2, cex = 1.1)
dev.off()

# Visual 2: excess versus drift under both primary aggregation lenses.
lens_matrix <- rbind(
  equal_sector = 10000 * equal_sector_summary$equal_sector_median_asset_excess_vs_unconditional,
  event_pooled = 10000 * core_event_pooled_summary$mean_net_excess_vs_unconditional
)
png(file.path(visual_dir, "branch_excess_both_lenses.png"), width = 1500, height = 900, res = 150)
par(mar = c(8, 6, 5, 2))
barplot(lens_matrix, beside = TRUE,
        names.arg = unname(rule_labels[equal_sector_summary$rule_id]),
        col = c("#3B82F6", "#E9A23B"), border = NA, las = 2,
        ylab = "Net excess versus unconditional drift (bp/trade)",
        main = "A branch must clear drift under more than one weighting lens")
abline(h = 0, col = "#526273", lwd = 1.5)
legend("topright", legend = c("Equal-sector median", "Core event-pooled mean"),
       fill = c("#3B82F6", "#E9A23B"), bty = "n")
dev.off()

# Visual 3: sector excess by branch.
sector_levels <- sort(unique(sector_rule_summary$sector))
sector_matrix <- matrix(
  NA_real_, nrow = length(sector_levels), ncol = length(contract$rule_ids),
  dimnames = list(sector_levels, unname(rule_labels[contract$rule_ids]))
)
for (i in seq_len(nrow(sector_rule_summary))) {
  sector_matrix[
    sector_rule_summary$sector[[i]],
    rule_labels[[sector_rule_summary$rule_id[[i]]]]
  ] <- 10000 * sector_rule_summary$median_asset_excess_vs_unconditional[[i]]
}
png(file.path(visual_dir, "sector_branch_excess_heatmap.png"), width = 1500, height = 1000, res = 150)
par(mar = c(8, 15, 5, 3))
limit <- max(abs(sector_matrix), na.rm = TRUE)
image(seq_len(ncol(sector_matrix)), seq_len(nrow(sector_matrix)), t(sector_matrix),
      axes = FALSE, xlab = "", ylab = "",
      main = "20-session excess versus drift by sector and branch (bp/trade)",
      col = grDevices::colorRampPalette(c("#B44738", "#F7F4EB", "#14866D"))(101),
      zlim = c(-limit, limit))
axis(1, at = seq_len(ncol(sector_matrix)), labels = colnames(sector_matrix), las = 2)
axis(2, at = seq_len(nrow(sector_matrix)), labels = rownames(sector_matrix), las = 1)
for (r in seq_len(nrow(sector_matrix))) for (c in seq_len(ncol(sector_matrix))) {
  text(c, r, sprintf("%+.0f", sector_matrix[r, c]), cex = 0.75)
}
box()
dev.off()

# Visual 4: executable path shape for each branch.
png(file.path(visual_dir, "branch_trade_paths.png"), width = 1500, height = 900, res = 150)
ylim <- range(100 * path_summary$mean_cumulative_open_log_return, finite = TRUE)
plot(NA, xlim = c(0, 20), ylim = ylim, xlab = "Held session",
     ylab = "Mean cumulative open-to-open log return (%)",
     main = "The path shows when each branch earns or loses its 20-session result")
abline(h = 0, col = "#B8C1CC")
for (rule_id in contract$rule_ids) {
  x <- path_summary[path_summary$rule_id == rule_id, ]
  lines(x$held_session, 100 * x$mean_cumulative_open_log_return,
        col = rule_colors[[rule_id]], lwd = 3)
}
legend("topleft", legend = unname(rule_labels[contract$rule_ids]),
       col = unname(rule_colors[contract$rule_ids]), lwd = 3, bty = "n")
dev.off()

# Visual 5: deterministic first positive/negative sideways events.
tape_specs <- data.frame(
  symbol = c("TSLA", "TSLA", "AMD", "AMD"),
  rule_id = c("SIDEWAYS_POSITIVE", "SIDEWAYS_NEGATIVE", "SIDEWAYS_POSITIVE", "SIDEWAYS_NEGATIVE"),
  stringsAsFactors = FALSE
)
png(file.path(visual_dir, "representative_sign_branch_trade_tapes.png"), width = 1600, height = 1100, res = 150)
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
  "# Daily Continuation 20-Session Sign/State Attribution (2018-2023 TRAIN)", "",
  "## Question", "",
  "Is the 20-session ER20-sideways clue genuinely positive-return continuation, a negative-prior rebound, a broader state effect, or only relative morphology that still trails ordinary drift?", "",
  "## Frozen mechanism slice", "",
  "- Use the inherited completed-close ER20 state and 20-session prior log return.",
  "- Enter at open t+1 and exit after 20 complete open-to-open sessions.",
  "- Compare sideways-all, sideways-positive-R20, sideways-negative-R20, and trending-all as independently executable nonoverlapping rules.",
  "- Subtract 10 bp per completed round trip and compare every rule with same-asset unconditional 20-session drift.",
  "- Keep all 129 instruments visible; the 88-stock equal-sector core is primary. Post-2023 outcomes remain sealed.", "",
  "## Equal-sector and pooled readout", ""
)
for (rule_id in contract$rule_ids) {
  eq <- equal_sector_summary[equal_sector_summary$rule_id == rule_id, ]
  pool <- core_event_pooled_summary[core_event_pooled_summary$rule_id == rule_id, ]
  report <- c(report, sprintf(
    "- `%s`: net %s; equal-sector excess versus drift %s; core event-pooled excess %s; %d/11 positive-excess sectors; %d core trades.",
    rule_labels[[rule_id]],
    fmt_pct(eq$equal_sector_median_asset_mean_net_log_return),
    fmt_bp(eq$equal_sector_median_asset_excess_vs_unconditional),
    fmt_bp(pool$mean_net_excess_vs_unconditional),
    eq$positive_excess_sectors,
    pool$trades
  ))
}
report <- c(report, "", "## Attribution contrasts", "")
for (i in seq_len(nrow(pairwise_readout))) {
  x <- pairwise_readout[i, ]
  report <- c(report, sprintf(
    "- `%s`: %s equal-sector and %s core event-pooled.",
    x$contrast_id, fmt_bp(x$equal_sector_net_difference),
    fmt_bp(x$event_pooled_net_difference)
  ))
}
report <- c(
  report, "", "## Interpretation", "",
  paste0("Frozen mechanism readout: `", mechanism_readout, "`."), "",
  "These are independently executable rule populations. Because each branch applies its own nonoverlap clock, sideways-all is not an algebraic weighted average of the positive and negative branches. The comparison attributes deployable behavior, not a causal treatment effect of sign or ER20 state.", "",
  "No p-value, multiplicity claim, horizon selection, threshold tuning, portfolio replay, or independent confirmation is attached to this TRAIN mechanism slice.", "",
  "## Status", "",
  "`TRAIN_20D_SIGN_STATE_ATTRIBUTION_COMPLETE_STOP_BEFORE_RULE_OR_OOS`", "",
  "Huddle before formulating any new rule or opening post-2023 outcomes. The 30-minute lane remains separately bookmarked and sealed.", "",
  "## Artifacts", "",
  "- `equal_sector_rule_summary.csv` and `core_event_pooled_rule_summary.csv`: primary branch readout.",
  "- `core_sector_rule_summary.csv`: sector breadth and heterogeneity.",
  "- `pairwise_readout.csv`: direct state/sign attribution contrasts.",
  "- `trade_ledger.csv` and `trade_path_summary.csv`: executable mechanics and path evidence.",
  "- `construction_checks.csv`: inherited source, timing, cost, and boundary audit.",
  "- `visuals/`: branch, baseline, sector, path, and representative-trade views."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: ", status$status)
message("Mechanism readout: ", mechanism_readout)
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
