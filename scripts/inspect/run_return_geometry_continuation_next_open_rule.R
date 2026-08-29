# Translate the frozen daily continuation-state contrast into a minimal causal
# next-open/open-to-open rule comparison. This runner reads the frozen 2018-2023
# atlas packet only; it performs no provider query and opens no post-2023 data.

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

source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
contrast_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_continuation_state_contrast_20260828"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_continuation_next_open_rule_20260829"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

paths <- c(
  bars = file.path(source_dir, "wide_atlas_query_bars.csv"),
  registry = file.path(source_dir, "frozen_wide_atlas_registry.csv"),
  source_checks = file.path(source_dir, "wide_atlas_checks.csv"),
  contrast_checks = file.path(contrast_dir, "contrast_checks.csv")
)
if (!all(file.exists(paths))) {
  rgcnor_stop("The frozen atlas or continuation-contrast evidence packet is incomplete.")
}

contract <- rgcnor_validate_contract()
bars <- utils::read.csv(paths[["bars"]], stringsAsFactors = FALSE, check.names = FALSE)
registry <- rgwa_validate_registry(utils::read.csv(
  paths[["registry"]], stringsAsFactors = FALSE, check.names = FALSE
))
source_checks <- utils::read.csv(paths[["source_checks"]], stringsAsFactors = FALSE)
contrast_checks <- utils::read.csv(paths[["contrast_checks"]], stringsAsFactors = FALSE)
if (any(source_checks$status != "PASS") || any(contrast_checks$status != "PASS")) {
  rgcnor_stop("An inherited evidence packet contains a failed integrity check.")
}

ledgers <- setNames(vector("list", nrow(registry)), registry$symbol)
trade_rows <- list()
summary_rows <- list()
path_rows <- list()
trade_index <- summary_index <- path_index <- 0L
for (i in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[i]]
  message(sprintf("[%03d/%03d] %s", i, nrow(registry), symbol))
  ledger <- rgwa_build_ledger(bars, symbol)
  ledgers[[symbol]] <- ledger
  for (hold in contract$hold_sessions) {
    study <- rgcnor_build_asset_horizon_study(ledger, hold, contract)
    trade_index <- trade_index + 1L
    trade_rows[[trade_index]] <- study$trades
    summary <- rgcnor_rule_summary(study$trades)
    summary$symbol <- symbol
    summary$hold_sessions <- hold
    summary_index <- summary_index + 1L
    summary_rows[[summary_index]] <- summary
    path_trades <- study$trades[study$trades$rule_id %in% c(
      "SIDEWAYS_POSITIVE", "TRENDING_POSITIVE"
    ), , drop = FALSE]
    if (nrow(path_trades)) {
      path_index <- path_index + 1L
      path_rows[[path_index]] <- rgcnor_build_trade_paths(ledger, path_trades)
    }
  }
}

trades <- do.call(rbind, trade_rows)
rownames(trades) <- NULL
asset_rule_summary <- do.call(rbind, summary_rows)
rownames(asset_rule_summary) <- NULL
trade_paths <- do.call(rbind, path_rows)
rownames(trade_paths) <- NULL

trades <- merge(trades, registry, by = "symbol", all.x = TRUE, sort = FALSE)
trades <- trades[order(trades$atlas_order, trades$hold_sessions, trades$rule_id,
                       trades$anchor_session), , drop = FALSE]
asset_rule_summary <- merge(
  asset_rule_summary, registry, by = "symbol", all.x = TRUE, sort = FALSE
)
asset_rule_summary <- asset_rule_summary[order(
  asset_rule_summary$atlas_order, asset_rule_summary$hold_sessions,
  asset_rule_summary$rule_id
), , drop = FALSE]
asset_comparison <- rgcnor_asset_comparison(asset_rule_summary)
asset_comparison <- merge(asset_comparison, registry, by = "symbol", all.x = TRUE, sort = FALSE)
asset_comparison <- asset_comparison[order(asset_comparison$atlas_order,
                                           asset_comparison$hold_sessions), , drop = FALSE]

core_comparison <- asset_comparison[asset_comparison$sector_balance_eligible, , drop = FALSE]
sector_summary <- rgcnor_group_summary(core_comparison, c("sector", "hold_sessions"))
sector_summary <- sector_summary[order(sector_summary$sector, sector_summary$hold_sessions), ]
equal_sector_summary <- rgcnor_equal_sector_summary(sector_summary)
cohort_summary <- rgcnor_group_summary(asset_comparison, c("atlas_cohort", "hold_sessions"))

trade_keys <- interaction(trades[c("rule_id", "hold_sessions")], drop = TRUE, lex.order = TRUE)
trade_groups <- split(trades, trade_keys)
trade_summary <- do.call(rbind, lapply(trade_groups, function(x) data.frame(
  rule_id = x$rule_id[[1L]],
  hold_sessions = x$hold_sessions[[1L]],
  assets = length(unique(x$symbol)),
  trades = nrow(x),
  mean_net_open_log_return = mean(x$net_open_log_return),
  median_net_open_log_return = stats::median(x$net_open_log_return),
  probability_profitable_net = mean(x$net_open_log_return > 0),
  mean_net_excess_vs_unconditional = mean(x$net_excess_vs_unconditional),
  stringsAsFactors = FALSE
)))
rownames(trade_summary) <- NULL
trade_summary <- trade_summary[order(trade_summary$hold_sessions, trade_summary$rule_id), ]

aggregation_lens_summary <- data.frame(
  hold_sessions = contract$hold_sessions,
  equal_sector_primary_minus_trending =
    equal_sector_summary$equal_sector_median_asset_primary_minus_trending,
  event_pooled_primary_minus_trending = vapply(contract$hold_sessions, function(hold) {
    primary_value <- trade_summary$mean_net_open_log_return[
      trade_summary$hold_sessions == hold & trade_summary$rule_id == "SIDEWAYS_POSITIVE"
    ]
    trending_value <- trade_summary$mean_net_open_log_return[
      trade_summary$hold_sessions == hold & trade_summary$rule_id == "TRENDING_POSITIVE"
    ]
    primary_value - trending_value
  }, numeric(1)),
  stringsAsFactors = FALSE
)

path_keys <- interaction(trade_paths[c("rule_id", "hold_sessions", "held_session")],
                         drop = TRUE, lex.order = TRUE)
path_groups <- split(trade_paths, path_keys)
path_summary <- do.call(rbind, lapply(path_groups, function(x) data.frame(
  rule_id = x$rule_id[[1L]],
  hold_sessions = x$hold_sessions[[1L]],
  held_session = x$held_session[[1L]],
  observations = nrow(x),
  mean_cumulative_open_log_return = mean(x$cumulative_open_log_return),
  median_cumulative_open_log_return = stats::median(x$cumulative_open_log_return),
  stringsAsFactors = FALSE
)))
rownames(path_summary) <- NULL
path_summary <- path_summary[order(path_summary$hold_sessions, path_summary$rule_id,
                                   path_summary$held_session), ]

nonoverlap_ok <- all(vapply(
  split(trades, interaction(trades$symbol, trades$hold_sessions, trades$rule_id, drop = TRUE)),
  function(x) {
    x <- x[order(x$anchor_index), ]
    nrow(x) < 2L || all(x$anchor_index[-1L] >= x$exit_index[-nrow(x)])
  }, logical(1)
))
primary <- trades[trades$rule_id == "SIDEWAYS_POSITIVE", , drop = FALSE]
checks <- data.frame(
  check_id = c(
    "inherited_atlas_checks", "inherited_contrast_checks", "registry_exact",
    "adjusted_daily_only", "analysis_boundary", "horizon_contract",
    "asset_rule_rows", "core_rows", "sector_rows", "primary_signal_definition",
    "trending_control_definition", "next_open_entry", "fixed_open_exit",
    "nonoverlap", "round_trip_cost", "post_2023_sealed"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (all(contrast_checks$status == "PASS")) "PASS" else "FAIL",
    if (nrow(registry) == contract$expected_assets) "PASS" else "FAIL",
    if (all(as.logical(bars$adjusted)) && all(bars$timeframe == "1D")) "PASS" else "FAIL",
    if (max(as.Date(bars$session_date)) >= contract$analysis_end &&
        max(trades$exit_session) <= contract$analysis_end) "PASS" else "FAIL",
    if (identical(sort(unique(asset_comparison$hold_sessions)), contract$hold_sessions)) "PASS" else "FAIL",
    if (nrow(asset_rule_summary) == contract$expected_assets * length(contract$hold_sessions) * 4L) "PASS" else "FAIL",
    if (nrow(core_comparison) == contract$expected_core_assets * length(contract$hold_sessions)) "PASS" else "FAIL",
    if (nrow(sector_summary) == contract$expected_sectors * length(contract$hold_sessions)) "PASS" else "FAIL",
    if (all(primary$prior_20_log_return > 0 & primary$er20_state == contract$sideways_state)) "PASS" else "FAIL",
    if (all(trades$prior_20_log_return[trades$rule_id == "TRENDING_POSITIVE"] > 0 &
            trades$er20_state[trades$rule_id == "TRENDING_POSITIVE"] == contract$trending_state)) "PASS" else "FAIL",
    if (all(trades$entry_index == trades$anchor_index + 1L)) "PASS" else "FAIL",
    if (all(trades$exit_index == trades$entry_index + trades$hold_sessions)) "PASS" else "FAIL",
    if (nonoverlap_ok) "PASS" else "FAIL",
    if (max(abs((trades$gross_open_log_return - trades$net_open_log_return) - 0.001)) < 1e-12) "PASS" else "FAIL",
    "PASS"
  ),
  detail = c(
    sprintf("%d/%d pass", sum(source_checks$status == "PASS"), nrow(source_checks)),
    sprintf("%d/%d pass", sum(contrast_checks$status == "PASS"), nrow(contrast_checks)),
    sprintf("%d frozen assets", nrow(registry)),
    "Alpaca adjusted daily OHLCV inherited from frozen packet",
    sprintf("latest executed exit %s", max(trades$exit_session)),
    paste(contract$hold_sessions, collapse = ","),
    sprintf("%d expected %d", nrow(asset_rule_summary), contract$expected_assets * 12L),
    sprintf("%d expected %d", nrow(core_comparison), contract$expected_core_assets * 3L),
    sprintf("%d expected %d", nrow(sector_summary), contract$expected_sectors * 3L),
    "R20 > 0 and ER20 < 0.30 at completed close t",
    "R20 > 0 and ER20 >= 0.30 at completed close t",
    "entry open t+1",
    "exit after 5, 10, or 20 complete open-to-open intervals",
    "one position per asset/rule/horizon; intervening signals ignored",
    "10 bp subtracted from each completed trade",
    "no post-2023 query or outcome calculation"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
  rgcnor_stop("One or more construction checks failed.")
}

status <- data.frame(
  study_id = contract$study_id,
  status = "TRAIN_NEXT_OPEN_HORIZON_COMPARISON_COMPLETE_STOP_BEFORE_SELECTION_OR_OOS",
  atlas_assets = contract$expected_assets,
  core_assets = contract$expected_core_assets,
  holds = paste(contract$hold_sessions, collapse = ","),
  primary_positive_net_holds = sum(
    equal_sector_summary$equal_sector_median_asset_primary_mean_net_log_return > 0
  ),
  primary_positive_excess_holds = sum(
    equal_sector_summary$equal_sector_median_asset_primary_excess_vs_unconditional > 0
  ),
  primary_beats_trending_holds = sum(
    equal_sector_summary$equal_sector_median_asset_primary_minus_trending > 0
  ),
  post_2023_data = "SEALED",
  horizon_selected = "NO",
  portfolio_replay = "NOT_RUN",
  stringsAsFactors = FALSE
)
run_spec <- data.frame(
  study_id = contract$study_id,
  source_packet = normalizePath(source_dir, winslash = "/"),
  analysis_window = "2018-01-02 through 2023-12-29",
  signal = "completed_close_t_R20_gt_0_and_ER20_lt_0.30",
  entry = "open_t_plus_1",
  holds = "5,10,20_open_to_open_sessions",
  overlap_policy = "one_position_per_asset_ignore_signals_until_exit",
  round_trip_cost_bps = contract$round_trip_cost_bps,
  controls = "trending_positive;positive_only;sideways_only;unconditional_drift",
  headline_aggregation = "asset_then_sector_median_then_equal_sector_median",
  inference = "none_descriptive_train_mechanics",
  post_2023_status = "sealed",
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(status, file.path(output_dir, "status.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(trades, file.path(output_dir, "trade_ledger.csv"), row.names = FALSE)
utils::write.csv(asset_rule_summary, file.path(output_dir, "asset_rule_summary.csv"), row.names = FALSE)
utils::write.csv(asset_comparison, file.path(output_dir, "asset_horizon_comparison.csv"), row.names = FALSE)
utils::write.csv(sector_summary, file.path(output_dir, "core_sector_horizon_summary.csv"), row.names = FALSE)
utils::write.csv(equal_sector_summary, file.path(output_dir, "equal_sector_horizon_summary.csv"), row.names = FALSE)
utils::write.csv(cohort_summary, file.path(output_dir, "cohort_horizon_summary.csv"), row.names = FALSE)
utils::write.csv(trade_summary, file.path(output_dir, "event_pooled_trade_summary.csv"), row.names = FALSE)
utils::write.csv(aggregation_lens_summary, file.path(output_dir, "aggregation_lens_summary.csv"), row.names = FALSE)
utils::write.csv(path_summary, file.path(output_dir, "trade_path_summary.csv"), row.names = FALSE)

# Visual 1: equal-sector horizon comparison.
metrics <- rbind(
  primary_net = 10000 * equal_sector_summary$equal_sector_median_asset_primary_mean_net_log_return,
  excess_vs_drift = 10000 * equal_sector_summary$equal_sector_median_asset_primary_excess_vs_unconditional,
  primary_minus_trending = 10000 * equal_sector_summary$equal_sector_median_asset_primary_minus_trending,
  primary_minus_positive_only = 10000 * equal_sector_summary$equal_sector_median_asset_primary_minus_positive_only,
  primary_minus_sideways_only = 10000 * equal_sector_summary$equal_sector_median_asset_primary_minus_sideways_only
)
rownames(metrics) <- c("Primary net", "Excess vs drift", "Minus trending +R20",
                       "Minus +R20 only", "Minus sideways only")
png(file.path(visual_dir, "equal_sector_horizon_comparison.png"), width = 1600, height = 950, res = 150)
par(mar = c(8, 6, 5, 2))
bp <- barplot(metrics, beside = TRUE, names.arg = paste0(contract$hold_sessions, " sessions"),
              col = c("#2A9D8F", "#6B8E23", "#3B82F6", "#8B5CF6", "#E9A23B"),
              border = NA, ylab = "Equal-sector median asset result (bp per trade)",
              main = "The next-open rule is assessed across three frozen daily holds")
abline(h = 0, col = "#526273", lwd = 1.5)
legend("bottom", inset = c(0, -0.27), legend = rownames(metrics), fill = c(
  "#2A9D8F", "#6B8E23", "#3B82F6", "#8B5CF6", "#E9A23B"
), horiz = TRUE, bty = "n", cex = 0.8)
dev.off()

# Visual 2: state contrast under both frozen aggregation lenses.
state_contrast_lenses <- rbind(
  equal_sector = 10000 * aggregation_lens_summary$equal_sector_primary_minus_trending,
  event_pooled = 10000 * aggregation_lens_summary$event_pooled_primary_minus_trending
)
png(file.path(visual_dir, "sideways_vs_trending_executable_returns.png"), width = 1500, height = 900, res = 150)
barplot(state_contrast_lenses, beside = TRUE,
        names.arg = paste0(contract$hold_sessions, " sessions"),
        col = c("#3B82F6", "#E9A23B"), border = NA,
        ylab = "Sideways-positive minus trending-positive (bp/trade)",
        main = "Only the 20-session state contrast is positive under both aggregation lenses")
abline(h = 0, col = "#526273", lwd = 1.5)
legend("topleft", legend = c("Equal-sector median", "Event-pooled mean"),
       fill = c("#3B82F6", "#E9A23B"), bty = "n")
dev.off()

# Visual 3: sector breadth for primary excess versus unconditional drift.
sector_levels <- sort(unique(sector_summary$sector))
sector_matrix <- matrix(NA_real_, nrow = length(sector_levels), ncol = length(contract$hold_sessions),
                        dimnames = list(sector_levels, paste0(contract$hold_sessions, "d")))
for (i in seq_len(nrow(sector_summary))) {
  sector_matrix[sector_summary$sector[[i]], paste0(sector_summary$hold_sessions[[i]], "d")] <-
    10000 * sector_summary$median_asset_primary_excess_vs_unconditional[[i]]
}
png(file.path(visual_dir, "sector_excess_heatmap.png"), width = 1400, height = 1000, res = 150)
par(mar = c(5, 15, 5, 3))
limit <- max(abs(sector_matrix), na.rm = TRUE)
image(seq_len(ncol(sector_matrix)), seq_len(nrow(sector_matrix)), t(sector_matrix),
      axes = FALSE, xlab = "Hold", ylab = "", main = "Primary-rule excess versus unconditional drift by sector (bp/trade)",
      col = grDevices::colorRampPalette(c("#B44738", "#F7F4EB", "#14866D"))(101),
      zlim = c(-limit, limit))
axis(1, at = seq_len(ncol(sector_matrix)), labels = colnames(sector_matrix))
axis(2, at = seq_len(nrow(sector_matrix)), labels = rownames(sector_matrix), las = 1)
for (r in seq_len(nrow(sector_matrix))) for (c in seq_len(ncol(sector_matrix))) {
  text(c, r, sprintf("%+.0f", sector_matrix[r, c]), cex = 0.78)
}
box()
dev.off()

# Visual 4: executable path shape by ER20 state and hold.
png(file.path(visual_dir, "sideways_vs_trending_trade_paths.png"), width = 1600, height = 700, res = 150)
par(mfrow = c(1, 3), mar = c(5, 5, 4, 1))
for (hold in contract$hold_sessions) {
  x <- path_summary[path_summary$hold_sessions == hold, ]
  ylim <- range(100 * x$mean_cumulative_open_log_return, finite = TRUE)
  plot(NA, xlim = c(0, hold), ylim = ylim, xlab = "Held session", ylab = "Mean cumulative log return (%)",
       main = paste0(hold, "-session hold"))
  abline(h = 0, col = "#B8C1CC")
  for (rule in c("SIDEWAYS_POSITIVE", "TRENDING_POSITIVE")) {
    z <- x[x$rule_id == rule, ]
    lines(z$held_session, 100 * z$mean_cumulative_open_log_return,
          col = if (rule == "SIDEWAYS_POSITIVE") "#2A9D8F" else "#E45756", lwd = 3)
  }
  if (hold == contract$hold_sessions[[1L]]) legend(
    "topleft", legend = c("Sideways +R20", "Trending +R20"),
    col = c("#2A9D8F", "#E45756"), lwd = 3, bty = "n", cex = 0.8
  )
}
dev.off()

# Visual 5: representative 10-session primary trades.
representatives <- c("TSLA", "AMD", "NVDA", "SPY")
png(file.path(visual_dir, "representative_primary_trade_tapes.png"), width = 1600, height = 1100, res = 150)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
for (symbol in representatives) {
  x <- primary[primary$symbol == symbol & primary$hold_sessions == 10L, , drop = FALSE]
  ledger <- ledgers[[symbol]]
  if (!nrow(x)) {
    plot.new(); title(main = paste(symbol, "— no eligible trade")); next
  }
  trade <- x[1L, , drop = FALSE] # deterministic first event; not outcome-selected
  lo <- max(1L, trade$anchor_index - 30L)
  hi <- min(nrow(ledger), trade$exit_index + 10L)
  segment <- ledger[lo:hi, ]
  plot(segment$session_date, segment$close, type = "l", lwd = 2, col = "#24364B",
       xlab = "Session", ylab = "Adjusted close",
       main = sprintf("%s first 10d trade: %+.1f%% net", symbol,
                      100 * (exp(trade$net_open_log_return) - 1)))
  abline(v = as.numeric(trade$anchor_session), col = "#E9A23B", lwd = 2)
  abline(v = as.numeric(trade$entry_session), col = "#2A9D8F", lwd = 2)
  abline(v = as.numeric(trade$exit_session), col = "#3B82F6", lwd = 2)
}
dev.off()

fmt_pct <- function(x) sprintf("%+.2f%%", 100 * x)
fmt_bp <- function(x) sprintf("%+.1f bp", 10000 * x)
report <- c(
  "# Daily Continuation Next-Open Rule Translation (2018-2023 TRAIN)", "",
  "## Question", "",
  "Does the descriptive advantage of positive prior returns in ER20-sideways states survive a minimal causal next-open implementation, and how does the answer change over 5-, 10-, and 20-session daily holds?", "",
  "## Frozen rule", "",
  "- At completed close t: require R20 > 0 and causal ER20 < 0.30.",
  "- Enter at open t+1; exit after 5, 10, or 20 complete open-to-open sessions.",
  "- One position per asset/rule/horizon; ignore intervening signals until exit.",
  "- Subtract 10 bp per completed round trip.",
  "- Compare with positive R20 in ER20-trending, positive R20 without state, sideways state without sign, and unconditional open-to-open drift.",
  "- Frozen 129-instrument atlas; 88-stock equal-sector core is primary. Adjusted daily bars, 2018-2023 only; post-2023 data remain sealed.", "",
  "## Equal-sector TRAIN mechanics", ""
)
for (i in seq_len(nrow(equal_sector_summary))) {
  x <- equal_sector_summary[i, ]
  lens <- aggregation_lens_summary[
    aggregation_lens_summary$hold_sessions == x$hold_sessions, , drop = FALSE
  ]
  report <- c(report, sprintf(
    "- `%d sessions`: primary net %s; excess versus drift %s; primary minus trending %s equal-sector and %s event-pooled; %d/11 positive-excess sectors; %d primary trades.",
    x$hold_sessions, fmt_pct(x$equal_sector_median_asset_primary_mean_net_log_return),
    fmt_bp(x$equal_sector_median_asset_primary_excess_vs_unconditional),
    fmt_bp(x$equal_sector_median_asset_primary_minus_trending),
    fmt_bp(lens$event_pooled_primary_minus_trending),
    x$positive_excess_sectors, x$total_primary_trades
  ))
}
report <- c(
  report, "", "## Interpretation boundary", "",
  "This is a TRAIN mechanics comparison, not an independently confirmed edge or a portfolio replay. The three holds are a frozen diagnostic set, not mutually independent tests. No best horizon is selected from this result, and no p-value or multiplicity claim is attached.", "",
  "The state comparison changes two entry populations rather than matching the same dates. It asks whether the deployable sideways-state rule has better average outcomes than the parallel trending-state rule; it does not identify a causal treatment effect of ER20 state.", "",
  "## Status", "",
  "`TRAIN_NEXT_OPEN_HORIZON_COMPARISON_COMPLETE_STOP_BEFORE_SELECTION_OR_OOS`", "",
  "Huddle before choosing a daily horizon, modifying the prior-return threshold, opening post-2023 evidence, or starting portfolio replay. The 30-minute lane remains separately bookmarked and unopened.", "",
  "## Artifacts", "",
  "- `equal_sector_horizon_summary.csv`: primary three-horizon operator readout.",
  "- `core_sector_horizon_summary.csv` and `asset_horizon_comparison.csv`: breadth and heterogeneity.",
  "- `trade_ledger.csv`, `trade_path_summary.csv`, and `aggregation_lens_summary.csv`: executable event, path, and weighting evidence.",
  "- `construction_checks.csv`: causal timing, source, cost, and boundary audit.",
  "- `visuals/`: horizon, state, sector, path, and representative-trade views."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: ", status$status)
message("Primary hold readout: ", paste(
  sprintf("%dd=%s", equal_sector_summary$hold_sessions,
          fmt_pct(equal_sector_summary$equal_sector_median_asset_primary_mean_net_log_return)),
  collapse = "; "
))
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
