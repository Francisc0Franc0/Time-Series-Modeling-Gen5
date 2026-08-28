# Translate the frozen signed-down return geometry into one causal, executable
# next-open event rule on the already inspected 2018-2023 TRAIN surface.
# Post-2023 outcomes remain sealed.

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "return_geometry_wide_atlas.R"))
source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "return_geometry_next_open_rule_translation.R"
))

contract <- rgnor_validate_contract()
source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_next_open_rule_translation_20260828"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) rgnor_stop("Could not create the output directory.")

paths <- list(
  bars = file.path(source_dir, "wide_atlas_query_bars.csv"),
  coverage = file.path(source_dir, "coverage_ledger.csv"),
  source_checks = file.path(source_dir, "wide_atlas_checks.csv"),
  registry = file.path(
    repo_root, "operator_hypothesis_lab", "registries", "return_geometry_wide_atlas.csv"
  )
)
if (!all(file.exists(unlist(paths)))) {
  rgnor_stop("The frozen wide-atlas bars, coverage, checks, or registry are unavailable.")
}

wide_contract <- rgwa_contract()
registry <- rgwa_validate_registry(utils::read.csv(
  paths$registry, stringsAsFactors = FALSE, check.names = FALSE
), wide_contract)
bars <- utils::read.csv(paths$bars, stringsAsFactors = FALSE, check.names = FALSE)
bars$session_date <- as.Date(bars$session_date)
bars$adjusted <- as.logical(bars$adjusted)
coverage <- utils::read.csv(paths$coverage, stringsAsFactors = FALSE, check.names = FALSE)
coverage$full_frozen_history <- as.logical(coverage$full_frozen_history)
source_checks <- utils::read.csv(paths$source_checks, stringsAsFactors = FALSE, check.names = FALSE)
if (any(source_checks$status != "PASS")) {
  rgnor_stop("The source wide-atlas packet does not have a complete PASS audit.")
}

primary_rows <- vector("list", nrow(registry))
state_rows <- vector("list", nrow(registry))
path_rows <- vector("list", nrow(registry))
asset_rows <- vector("list", nrow(registry))
candidate_rows <- vector("list", nrow(registry))
ledgers <- vector("list", nrow(registry))
names(ledgers) <- registry$symbol

for (i in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[i]]
  message(sprintf("[%03d/%03d] %s", i, nrow(registry), symbol))
  ledger <- rgwa_build_ledger(bars, symbol, wide_contract)
  ledgers[[symbol]] <- ledger
  study <- rgnor_build_asset_study(ledger, contract)
  primary_rows[[i]] <- study$primary
  state_rows[[i]] <- study$state_only
  path_rows[[i]] <- rgnor_build_trade_paths(ledger, study$primary, contract)
  summary <- rgnor_asset_summary(study$primary, study$state_only)
  summary$symbol <- symbol
  summary$candidate_anchors <- nrow(study$candidates)
  summary$state_signal_anchors <- sum(study$candidates$state_signal)
  summary$primary_signal_anchors <- sum(study$candidates$primary_signal)
  asset_rows[[i]] <- summary
  signal_history <- study$candidates$negative_history_observations[
    study$candidates$primary_signal
  ]
  candidate_rows[[i]] <- data.frame(
    symbol = symbol,
    candidate_anchors = nrow(study$candidates),
    state_signal_anchors = sum(study$candidates$state_signal),
    primary_signal_anchors = sum(study$candidates$primary_signal),
    minimum_negative_history = if (length(signal_history)) min(signal_history) else NA_integer_,
    stringsAsFactors = FALSE
  )
}

bind_nonempty <- function(rows) {
  rows <- rows[vapply(rows, nrow, integer(1L)) > 0L]
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

primary_trades <- bind_nonempty(primary_rows)
state_only_trades <- bind_nonempty(state_rows)
trade_paths <- bind_nonempty(path_rows)
asset_summary <- do.call(rbind, asset_rows)
rownames(asset_summary) <- NULL
candidate_summary <- do.call(rbind, candidate_rows)
rownames(candidate_summary) <- NULL

registry_fields <- c(
  "symbol", "atlas_order", "atlas_cohort", "sector", "instrument_type",
  "sector_balance_eligible", "selection_role"
)
attach_registry <- function(x) {
  merge(x, registry[registry_fields], by = "symbol", all.x = TRUE, sort = FALSE)
}
primary_trades <- attach_registry(primary_trades)
state_only_trades <- attach_registry(state_only_trades)
trade_paths <- attach_registry(trade_paths)
asset_summary <- attach_registry(asset_summary)
candidate_summary <- attach_registry(candidate_summary)

primary_trades <- primary_trades[order(primary_trades$entry_session, primary_trades$atlas_order), , drop = FALSE]
state_only_trades <- state_only_trades[order(state_only_trades$entry_session, state_only_trades$atlas_order), , drop = FALSE]
asset_summary <- asset_summary[order(asset_summary$atlas_order), , drop = FALSE]

core_assets <- asset_summary[asset_summary$sector_balance_eligible, , drop = FALSE]
sector_summary <- rgnor_summarize_assets(core_assets, "sector")
sector_summary <- sector_summary[order(sector_summary$sector), , drop = FALSE]
equal_sector_summary <- rgnor_equal_sector_summary(sector_summary)
cohort_summary <- rgnor_summarize_assets(asset_summary, "atlas_cohort")
cohort_summary <- cohort_summary[order(cohort_summary$atlas_cohort), , drop = FALSE]
train_disposition <- rgnor_classify_train(
  equal_sector_summary, sector_summary, asset_summary, contract
)

summarize_trades <- function(x) {
  data.frame(
    trades = nrow(x),
    assets = length(unique(x$symbol)),
    mean_gross_open_log_return = mean(x$gross_open_log_return),
    mean_net_open_log_return = mean(x$net_open_log_return),
    median_net_open_log_return = stats::median(x$net_open_log_return),
    probability_profitable_net = mean(x$net_open_log_return > 0),
    mean_research_close_log_return = mean(x$research_close_log_return),
    mean_translation_difference = mean(x$translation_difference),
    mean_net_excess_vs_unconditional = mean(x$net_excess_vs_unconditional),
    stringsAsFactors = FALSE
  )
}

trade_groups <- split(primary_trades, primary_trades$atlas_cohort)
trade_summary <- do.call(rbind, lapply(trade_groups, summarize_trades))
trade_summary$atlas_cohort <- rownames(trade_summary)
rownames(trade_summary) <- NULL
core_trade_summary <- summarize_trades(
  primary_trades[primary_trades$sector_balance_eligible, , drop = FALSE]
)
core_trade_summary$atlas_cohort <- "GICS_CORE_EVENT_POOLED"
trade_summary <- rbind(trade_summary, core_trade_summary)

core_trades <- primary_trades[primary_trades$sector_balance_eligible, , drop = FALSE]
core_trades$entry_year <- format(core_trades$entry_session, "%Y")
year_groups <- split(core_trades, core_trades$entry_year)
year_summary <- do.call(rbind, lapply(year_groups, function(x) {
  data.frame(
    year = x$entry_year[[1L]], trades = nrow(x), assets = length(unique(x$symbol)),
    mean_net_open_log_return = mean(x$net_open_log_return),
    median_net_open_log_return = stats::median(x$net_open_log_return),
    mean_net_excess_vs_unconditional = mean(x$net_excess_vs_unconditional),
    probability_profitable_net = mean(x$net_open_log_return > 0),
    stringsAsFactors = FALSE
  )
}))
rownames(year_summary) <- NULL

path_groups <- split(trade_paths, interaction(
  trade_paths$atlas_cohort, trade_paths$held_session, drop = TRUE, lex.order = TRUE
))
path_summary <- do.call(rbind, lapply(path_groups, function(x) {
  data.frame(
    atlas_cohort = x$atlas_cohort[[1L]], held_session = x$held_session[[1L]],
    trades = nrow(x), mean_cumulative_open_log_return = mean(x$cumulative_open_log_return),
    median_cumulative_open_log_return = stats::median(x$cumulative_open_log_return),
    q25_cumulative_open_log_return = as.numeric(stats::quantile(x$cumulative_open_log_return, .25)),
    q75_cumulative_open_log_return = as.numeric(stats::quantile(x$cumulative_open_log_return, .75)),
    stringsAsFactors = FALSE
  )
}))
rownames(path_summary) <- NULL
path_summary <- path_summary[order(path_summary$atlas_cohort, path_summary$held_session), , drop = FALSE]

no_overlap <- all(vapply(split(primary_trades, primary_trades$symbol), function(x) {
  x <- x[order(x$anchor_index), , drop = FALSE]
  nrow(x) < 2L || all(x$anchor_index[-1L] >= x$exit_index[-nrow(x)])
}, logical(1L)))
core_coverage <- coverage[coverage$atlas_cohort == "GICS_CORE", , drop = FALSE]
checks <- data.frame(
  check_id = c(
    "source_packet_pass", "registry_exact", "core_full_history",
    "all_assets_processed", "negative_history_causal_minimum",
    "primary_state_exact", "primary_severity_exact", "entry_next_open",
    "exit_after_20_held_sessions", "one_position_per_asset",
    "state_only_superset_policy", "adjusted_daily_only",
    "no_post_2023_exits", "post_2023_sealed"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (nrow(registry) == contract$expected_assets) "PASS" else "FAIL",
    if (nrow(core_coverage) == contract$expected_core_assets && all(core_coverage$full_frozen_history)) "PASS" else "FAIL",
    if (nrow(asset_summary) == contract$expected_assets) "PASS" else "FAIL",
    if (all(primary_trades$negative_history_observations >= contract$minimum_prior_negative_observations)) "PASS" else "FAIL",
    if (all(primary_trades$signed_er20_state == contract$state)) "PASS" else "FAIL",
    if (all(primary_trades$prior_20_log_return <= primary_trades$negative_return_q20)) "PASS" else "FAIL",
    if (all(primary_trades$entry_index == primary_trades$anchor_index + 1L)) "PASS" else "FAIL",
    if (all(primary_trades$exit_index == primary_trades$entry_index + contract$hold_sessions)) "PASS" else "FAIL",
    if (no_overlap) "PASS" else "FAIL",
    if (all(asset_summary$state_only_trades >= asset_summary$trades)) "PASS" else "FAIL",
    if (all(bars$adjusted) && all(bars$timeframe == "1D")) "PASS" else "FAIL",
    if (max(primary_trades$exit_session) <= contract$analysis_end) "PASS" else "FAIL",
    "PASS"
  ),
  detail = c(
    paste(nrow(source_checks), "source checks"),
    paste(nrow(registry), "frozen assets"),
    paste(nrow(core_coverage), "full-history sector-balanced stocks"),
    paste(nrow(asset_summary), "asset summaries"),
    paste("minimum prior negative observations =", min(primary_trades$negative_history_observations)),
    contract$state,
    "prior R20 <= causal q20 of prior negative R20 observations",
    "signal close t -> entry open t+1",
    "entry open t+1 -> exit open t+21",
    "new signals ignored until the existing trade exits",
    "state-only uses the same timing and nonoverlap policy",
    "Alpaca adjusted daily OHLCV",
    as.character(max(primary_trades$exit_session)),
    "OOS outcomes were not queried or calculated"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  utils::write.csv(checks, file.path(output_dir, "rule_translation_checks.csv"), row.names = FALSE)
  rgnor_stop("One or more rule-translation construction checks failed.")
}

status <- data.frame(
  study_id = contract$study_id,
  status = train_disposition$status,
  atlas_assets = nrow(asset_summary),
  active_assets = sum(asset_summary$trades > 0L),
  core_assets = nrow(core_assets),
  active_core_assets = sum(core_assets$trades > 0L),
  primary_trades = nrow(primary_trades),
  positive_excess_sectors = sum(sector_summary$median_asset_mean_net_excess > 0, na.rm = TRUE),
  post_2023_data = "SEALED",
  temporal_confirmation = "NOT_OPENED",
  portfolio_replay = "NOT_RUN",
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  study_id = contract$study_id,
  universe = "frozen_129_atlas_88_stock_equal_sector_primary",
  analysis_window = "2018-01-02_through_2023-12-29",
  signal_timing = "completed_close_t",
  state_rule = "signed_er20_lte_negative_0.30",
  severity_rule = "R20_lte_causal_q20_of_prior_negative_R20",
  minimum_prior_negative_observations = contract$minimum_prior_negative_observations,
  execution = "enter_open_t_plus_1_exit_open_t_plus_21",
  hold_sessions = contract$hold_sessions,
  overlap_policy = "one_position_per_asset_ignore_signals_until_exit",
  round_trip_cost_bps = contract$round_trip_cost_bps,
  headline_aggregation = "asset_then_sector_then_equal_sector",
  comparator = "state_only_same_timing_plus_same_asset_unconditional_open_return",
  post_2023_data = "SEALED",
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(status, file.path(output_dir, "status.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "rule_translation_checks.csv"), row.names = FALSE)
utils::write.csv(train_disposition$checks, file.path(output_dir, "train_mechanics_gates.csv"), row.names = FALSE)
utils::write.csv(candidate_summary, file.path(output_dir, "candidate_coverage.csv"), row.names = FALSE)
utils::write.csv(primary_trades, file.path(output_dir, "primary_trade_ledger.csv"), row.names = FALSE)
utils::write.csv(state_only_trades, file.path(output_dir, "state_only_trade_ledger.csv"), row.names = FALSE)
utils::write.csv(asset_summary, file.path(output_dir, "asset_summary.csv"), row.names = FALSE)
utils::write.csv(sector_summary, file.path(output_dir, "core_sector_summary.csv"), row.names = FALSE)
utils::write.csv(equal_sector_summary, file.path(output_dir, "equal_sector_summary.csv"), row.names = FALSE)
utils::write.csv(cohort_summary, file.path(output_dir, "cohort_summary.csv"), row.names = FALSE)
utils::write.csv(trade_summary, file.path(output_dir, "trade_summary.csv"), row.names = FALSE)
utils::write.csv(year_summary, file.path(output_dir, "core_year_summary.csv"), row.names = FALSE)
utils::write.csv(path_summary, file.path(output_dir, "trade_path_summary.csv"), row.names = FALSE)

png(file.path(visual_dir, "close_to_open_translation.png"), width = 1400, height = 900, res = 140)
plot(
  core_trades$research_close_log_return * 100,
  core_trades$gross_open_log_return * 100,
  pch = 16, cex = 0.65, col = grDevices::adjustcolor("#66788A", alpha.f = 0.45),
  xlab = "Research return: close t to close t+20 (%)",
  ylab = "Executable return: open t+1 to open t+21 (%)",
  main = "Close-to-close geometry versus next-open execution"
)
abline(0, 1, col = "#AAB4C0", lty = 2, lwd = 2)
abline(stats::lm(gross_open_log_return ~ research_close_log_return, data = core_trades),
       col = "#3B82F6", lwd = 2)
legend(
  "topleft",
  legend = c(
    sprintf("Core trades: %d", nrow(core_trades)),
    sprintf("Mean close return: %.2f%%", 100 * mean(core_trades$research_close_log_return)),
    sprintf("Mean open return: %.2f%%", 100 * mean(core_trades$gross_open_log_return))
  ),
  bty = "n", text.col = "#24364B"
)
dev.off()

cohort_colors <- c(
  GICS_CORE = "#3B82F6", ATTENTION_SUPPLEMENT = "#E45756",
  EQUITY_ETF_CONTROL = "#2A9D8F", NON_EQUITY_CONTROL = "#8B5CF6"
)
png(file.path(visual_dir, "mean_trade_path_by_cohort.png"), width = 1400, height = 900, res = 140)
par(mar = c(5, 5, 9, 2), xpd = NA)
plot(
  NA, xlim = c(0, contract$hold_sessions),
  ylim = range(path_summary$mean_cumulative_open_log_return * 100, finite = TRUE),
  xlab = "Held session after next-open entry", ylab = "Mean cumulative open-to-open log return (%)",
  main = ""
)
mtext("Average executable path after the frozen signal", side = 3, line = 6,
      font = 2, cex = 1.35)
abline(h = 0, col = "#B8C1CC")
for (cohort in names(cohort_colors)) {
  x <- path_summary[path_summary$atlas_cohort == cohort, , drop = FALSE]
  lines(x$held_session, x$mean_cumulative_open_log_return * 100,
        col = cohort_colors[[cohort]], lwd = 3)
}
legend(
  "top", inset = c(0, -0.12), legend = names(cohort_colors),
  col = cohort_colors, lwd = 3, bty = "n", horiz = TRUE, cex = 0.8
)
dev.off()

aggregation_lenses <- data.frame(
  lens = c(
    "Equal-sector\nmedian asset", "Core median\nasset",
    "Core event-\npooled"
  ),
  net_excess = c(
    equal_sector_summary$median_asset_mean_net_excess[[1L]],
    stats::median(core_assets$mean_net_excess_vs_unconditional),
    mean(core_trades$net_excess_vs_unconditional)
  ),
  stringsAsFactors = FALSE
)
png(file.path(visual_dir, "core_aggregation_lenses.png"), width = 1400, height = 900, res = 140)
lens_bp <- aggregation_lenses$net_excess * 10000
lens_positions <- barplot(
  lens_bp, names.arg = aggregation_lenses$lens,
  col = ifelse(lens_bp > 0, "#2A9D6F", "#E45756"), border = NA,
  ylim = c(min(-35, 1.25 * min(lens_bp)), max(25, 1.25 * max(lens_bp))),
  ylab = "Net excess versus unconditional 20-session drift (bp/trade)",
  main = "The conclusion depends on whether assets or events receive equal weight"
)
abline(h = 0, col = "#526273", lwd = 1.5)
text(
  lens_positions, lens_bp, labels = sprintf("%+.1f bp", lens_bp),
  pos = ifelse(lens_bp >= 0, 3, 1), cex = 1.0
)
dev.off()

sector_order <- order(sector_summary$median_asset_mean_net_excess)
sector_plot <- sector_summary[sector_order, , drop = FALSE]
sector_bp <- sector_plot$median_asset_mean_net_excess * 10000
png(file.path(visual_dir, "core_sector_net_excess.png"), width = 1500, height = 900, res = 140)
par(mar = c(5, 13, 4, 2))
barplot(
  sector_bp, names.arg = sector_plot$sector, horiz = TRUE, las = 1,
  col = ifelse(sector_bp > 0, "#2A9D6F", "#E45756"), border = NA,
  xlab = "Median asset mean net excess versus unconditional 20-session drift (bp/trade)",
  main = "The executable rule's breadth across the 11-sector core"
)
abline(v = 0, col = "#526273", lwd = 1.5)
dev.off()

active_core_summary <- core_assets[core_assets$trades > 0L, , drop = FALSE]
png(file.path(visual_dir, "core_asset_excess_distribution.png"), width = 1500, height = 900, res = 140)
par(mar = c(5, 13, 4, 2))
boxplot(
  10000 * mean_net_excess_vs_unconditional ~ sector,
  data = active_core_summary, horizontal = TRUE, las = 1,
  col = "#E8F1FA", border = "#3B82F6", outline = TRUE,
  xlab = "Asset mean net excess versus unconditional drift (bp/trade)", ylab = "",
  main = "Sector medians can conceal substantial asset-level heterogeneity"
)
abline(v = 0, col = "#526273", lwd = 1.5)
dev.off()

png(file.path(visual_dir, "core_yearly_net_return.png"), width = 1400, height = 900, res = 140)
year_values <- year_summary$mean_net_open_log_return * 100
year_limits <- range(c(0, year_values), finite = TRUE)
year_pad <- 0.18 * diff(year_limits)
bp <- barplot(
  year_values, names.arg = year_summary$year,
  col = ifelse(year_values > 0, "#2A9D6F", "#E45756"), border = NA,
  ylim = c(year_limits[[1L]] - year_pad, year_limits[[2L]] + year_pad),
  ylab = "Mean net open-to-open log return per trade (%)",
  main = "TRAIN calendar slices reveal whether one episode dominates"
)
abline(h = 0, col = "#526273", lwd = 1.5)
text(bp, year_values, labels = sprintf("%.2f%%\n%d trades", year_values, year_summary$trades),
     pos = ifelse(year_values >= 0, 3, 1), cex = 0.85)
dev.off()

representatives <- c("TSLA", "AMD", "GOOGL", "SPY")
png(file.path(visual_dir, "representative_trade_tapes.png"), width = 1600, height = 1100, res = 140)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
for (symbol in representatives) {
  trades <- primary_trades[primary_trades$symbol == symbol, , drop = FALSE]
  ledger <- ledgers[[symbol]]
  if (!nrow(trades)) {
    plot.new(); title(main = paste(symbol, "— no eligible primary trade")); next
  }
  trade <- trades[1L, ]
  lo <- max(1L, trade$anchor_index - 40L)
  hi <- min(nrow(ledger), trade$exit_index + 10L)
  segment <- ledger[lo:hi, , drop = FALSE]
  plot(segment$session_date, segment$close, type = "l", lwd = 2, col = "#24364B",
       xlab = "Session", ylab = "Adjusted close",
       main = sprintf("%s first eligible trade: %.1f%% net", symbol,
                      100 * (exp(trade$net_open_log_return) - 1)))
  abline(v = as.numeric(trade$anchor_session), col = "#E45756", lwd = 2)
  abline(v = as.numeric(trade$entry_session), col = "#2A9D6F", lwd = 2)
  abline(v = as.numeric(trade$exit_session), col = "#3B82F6", lwd = 2)
}
dev.off()

headline <- equal_sector_summary[1L, ]
report_lines <- c(
  "# Next-Open Rule Translation (2018-2023 TRAIN)", "",
  "## Question", "",
  "Does the descriptive signed-down loss-rebound geometry survive translation into a causal next-open, fixed-hold event rule?", "",
  "## Frozen rule", "",
  "- Frozen 129-instrument atlas; 88-stock equal-sector core is primary and all other cohorts remain visible.",
  "- At completed close t: signed ER20 DOWN and R20 at or below the causal 20th percentile of that asset's previously observed negative R20 values.",
  "- At least 100 prior negative R20 observations are required.",
  "- Enter at open t+1, exit at open t+21, one position per asset, ignore intervening signals, 10 bp round-trip cost.",
  "- Adjusted daily bars, 2018-2023 TRAIN only. Post-2023 outcomes remain sealed.", "",
  "## Headline TRAIN mechanics", "",
  sprintf("- Primary trades: `%d` across `%d/129` active assets; core trades: `%d` across `%d/88` active core assets.",
          nrow(primary_trades), sum(asset_summary$trades > 0), nrow(core_trades), sum(core_assets$trades > 0)),
  sprintf("- Equal-sector median asset mean net return: `%+.2f%%` per trade.",
          100 * headline$median_asset_mean_net_log_return),
  sprintf("- Equal-sector median asset mean net excess versus unconditional 20-session drift: `%+.2f%%` per trade.",
          100 * headline$median_asset_mean_net_excess),
  sprintf("- Equal-sector median asset difference versus the signed-down state-only rule: `%+.2f%%` per trade; state-only trades: `%d`.",
          100 * headline$median_asset_mean_net_difference_vs_state_only,
          nrow(state_only_trades)),
  sprintf("- Positive-excess sectors: `%d/11`.",
          sum(sector_summary$median_asset_mean_net_excess > 0, na.rm = TRUE)),
  sprintf("- Event-pooled core mean research close return: `%+.2f%%`; executable gross open return: `%+.2f%%`; translation difference: `%+.2f%%`.",
          100 * mean(core_trades$research_close_log_return),
          100 * mean(core_trades$gross_open_log_return),
          100 * mean(core_trades$translation_difference)),
  sprintf("- Event-pooled core mean net excess versus unconditional drift: `%+.2f%%` per trade; the asset-balanced and event-pooled lenses disagree.",
          100 * mean(core_trades$net_excess_vs_unconditional)), "",
  "## Disposition", "",
  paste0("`", train_disposition$status, "`"), "",
  "This is a TRAIN mechanics result, not temporal confirmation or a portfolio backtest. The next decision is whether to freeze an OOS gate before opening post-2023 outcomes.", "",
  "## Evidence surface", "",
  "- `primary_trade_ledger.csv`: causal signals and next-open trades.",
  "- `asset_summary.csv`, `core_sector_summary.csv`, and `cohort_summary.csv`: breadth and heterogeneity.",
  "- `train_mechanics_gates.csv` and `rule_translation_checks.csv`: frozen disposition and construction audit.",
  "- `visuals/`: translation, average paths, sector/asset breadth, calendar slices, and representative tapes.", "",
  "## STOP", "",
  "Do not tune the percentile, state cutoff, hold, overlap policy, costs, or universe after this readout. Do not query post-2023 outcomes until an OOS contract is explicitly frozen."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: ", train_disposition$status)
message("Primary trades: ", nrow(primary_trades), "; active assets: ", sum(asset_summary$trades > 0L))
message("Active core assets: ", sum(core_assets$trades > 0L), "; positive excess sectors: ",
        sum(sector_summary$median_asset_mean_net_excess > 0, na.rm = TRUE))
message("Artifacts: ", output_dir)
