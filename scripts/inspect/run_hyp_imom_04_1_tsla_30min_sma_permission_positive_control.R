options(stringsAsFactors = FALSE)

repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- file.path(repo, ".codex_r_libs")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))

source(file.path(repo, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo, "operator_hypothesis_lab", "R",
  "gen5_hyp_imom_04_1_tsla_30min_sma_permission_positive_control.R"))

contract <- him041_contract()
registry <- him041_variant_registry()
run_dir <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab",
  "hyp_imom_04_1_tsla_30min_sma_permission_positive_control_20260823")
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cache_dir <- file.path(repo, "data_cache", "alpaca_intraday_30min")
cache_paths <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d.rds", 2017:2023))
if (!all(file.exists(cache_paths))) him041_stop("Frozen 2017-2023 SIP cache is incomplete.")
bars <- do.call(rbind, lapply(cache_paths, readRDS))
bars <- bars[bars$symbol %in% c("TSLA", "QQQ"), , drop = FALSE]
bars <- bars[!duplicated(bars[c("symbol", "timestamp_utc")]), , drop = FALSE]
bars <- bars[order(bars$symbol, bars$timestamp_utc), , drop = FALSE]
bars <- imom30_apply_rth_calendar(bars)
bars <- imom30_apply_archive_exclusions(bars)
bars$session_date <- as.Date(bars$session_date)

tsla_bars <- bars[bars$symbol == "TSLA", , drop = FALSE]
qqq_bars <- bars[bars$symbol == "QQQ", , drop = FALSE]
development_tsla <- tsla_bars[tsla_bars$session_date >= contract$development_start &
  tsla_bars$session_date <= contract$development_end, , drop = FALSE]
development_qqq <- qqq_bars[qqq_bars$session_date >= contract$development_start &
  qqq_bars$session_date <= contract$development_end, , drop = FALSE]

integrity <- data.frame(
  check = c("no_confirmation_bars", "unique_tsla_timestamps", "unique_qqq_timestamps",
    "common_tsla_qqq_calendar", "archive_gaps_excluded", "completed_bar_slot_grid"),
  passed = c(
    all(bars$session_date < contract$confirmation_start),
    !anyDuplicated(tsla_bars$timestamp_utc),
    !anyDuplicated(qqq_bars$timestamp_utc),
    identical(as.numeric(development_tsla$timestamp_utc), as.numeric(development_qqq$timestamp_utc)),
    !any(bars$session_date %in% imom30_archive_gap_dates()),
    all(bars$bar_slot %in% 1:13)),
  stringsAsFactors = FALSE)
write.csv(integrity, file.path(run_dir, "him041_data_integrity.csv"), row.names = FALSE)
if (!all(integrity$passed)) him041_stop("Source-integrity gate failed.")

synthetic <- him041_synthetic_suite(contract, registry)
write.csv(synthetic, file.path(run_dir, "him041_synthetic_recovery.csv"), row.names = FALSE)
if (!all(synthetic$gate_pass)) him041_stop("Synthetic positive-control gate failed.")

daily <- imom_aggregate_daily(bars)
daily_state <- him041_daily_state(
  daily[daily$symbol == "TSLA", , drop = FALSE],
  daily[daily$symbol == "QQQ", , drop = FALSE], contract)
feature_panel <- him041_build_feature_panel(tsla_bars, daily_state, contract)
events <- him041_eligible_events(him041_extract_parent_events(feature_panel, contract))
write.csv(events, file.path(run_dir, "him041_tsla_parent_event_ledger.csv"), row.names = FALSE)

feature_support <- do.call(rbind, lapply(split(events, events$year), function(x) data.frame(
  year = x$year[[1L]], parent_events = nrow(x), complete_feature_events = sum(x$feature_complete),
  complete_fraction = mean(x$feature_complete), first_complete_signal = if (any(x$feature_complete))
    as.character(min(x$signal_date[x$feature_complete])) else NA_character_, stringsAsFactors = FALSE)))
write.csv(feature_support, file.path(run_dir, "him041_feature_support.csv"), row.names = FALSE)

eligible_features <- events[events$feature_complete, him041_feature_names(), drop = FALSE]
feature_correlations <- stats::cor(eligible_features, use = "complete.obs", method = "spearman")
write.csv(cbind(feature = rownames(feature_correlations), as.data.frame(feature_correlations)),
  file.path(run_dir, "him041_feature_spearman_correlations.csv"), row.names = FALSE)

parent_trade_path <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab",
  "intraday_momentum_poc_series_20260813", "fixed_sma_trades.csv")
if (!file.exists(parent_trade_path)) him041_stop("Parent reproduction authority is missing.")
parent_trades <- read.csv(parent_trade_path)
parent_trades <- parent_trades[parent_trades$symbol == "TSLA" & parent_trades$frequency == "M30" &
  parent_trades$leverage == 1 & parent_trades$year %in% 2018:2023, , drop = FALSE]
parent_trades$entry_key <- as.character(parent_trades$entry_timestamp)
events$entry_key <- as.character(events$entry_timestamp)
reproduction <- merge(events[c("event_id", "entry_key", "primary_return")],
  parent_trades[c("entry_key", "net_return")], by = "entry_key", all = TRUE)
parent_audit <- data.frame(
  check = c("trade_count", "entry_identity", "net_return"),
  passed = c(nrow(events) == nrow(parent_trades), all(!is.na(reproduction$event_id)) &&
      all(!is.na(reproduction$net_return)),
    nrow(reproduction) == nrow(events) && max(abs(reproduction$primary_return - reproduction$net_return),
      na.rm = TRUE) < 1e-10),
  observed = c(nrow(events), sum(complete.cases(reproduction[c("event_id", "net_return")])),
    max(abs(reproduction$primary_return - reproduction$net_return), na.rm = TRUE)),
  stringsAsFactors = FALSE)
write.csv(parent_audit, file.path(run_dir, "him041_parent_reproduction_audit.csv"), row.names = FALSE)
if (!all(parent_audit$passed)) him041_stop("Parent reproduction gate failed.")

oof <- him041_oof_predictions(events, contract, registry)
predictions <- oof$predictions
thresholds <- oof$thresholds
metrics <- him041_prediction_metrics(predictions, contract)
write.csv(predictions, file.path(run_dir, "him041_oof_predictions.csv"), row.names = FALSE)
write.csv(thresholds, file.path(run_dir, "him041_threshold_ledger.csv"), row.names = FALSE)
write.csv(metrics, file.path(run_dir, "him041_model_metrics.csv"), row.names = FALSE)
winner_id <- metrics$variant_id[[1L]]
winner_metric <- metrics[metrics$variant_id == winner_id, , drop = FALSE]

set.seed(contract$random_seed + 1000L)
session_count <- length(unique(feature_panel$session_date))
shift_offsets <- sample(seq_len(session_count - 1L), contract$simulations, replace = FALSE)
shift_control_path <- file.path(run_dir, "him041_familywise_session_shift_controls.csv")
if (file.exists(shift_control_path) && nrow(read.csv(shift_control_path)) == contract$simulations) {
  shift_controls <- read.csv(shift_control_path)
} else {
  shift_rows <- list()
  for (simulation in seq_along(shift_offsets)) {
    shifted <- him041_shift_event_features(events, feature_panel, shift_offsets[[simulation]])
    shifted$eligibility_reason <- ifelse(shifted$feature_complete, "ELIGIBLE", "SHIFTED_SLOT_UNAVAILABLE")
    shifted_oof <- him041_oof_predictions(shifted, contract, registry)
    shifted_metrics <- him041_prediction_metrics(shifted_oof$predictions, contract)
    best <- shifted_metrics[1L, , drop = FALSE]
    best_predictions <- shifted_oof$predictions[
      shifted_oof$predictions$variant_id == best$variant_id, , drop = FALSE]
    shift_rows[[simulation]] <- data.frame(
      simulation = simulation, shift_sessions = shift_offsets[[simulation]],
      scored_events = nrow(best_predictions), best_variant = best$variant_id,
      maximum_brier_improvement = best$brier_improvement,
      best_policy_total_return = him041_compound_return(
        best_predictions$primary_return[best_predictions$permit]), stringsAsFactors = FALSE)
  }
  shift_controls <- do.call(rbind, shift_rows)
  write.csv(shift_controls, shift_control_path, row.names = FALSE)
}

winner_predictions <- predictions[predictions$variant_id == winner_id, , drop = FALSE]
winner_predictions <- merge(winner_predictions,
  events[c("event_id", him041_feature_names(), "bars_remaining_in_session", "signal_panel_row_id",
           "entry_timestamp", "exit_timestamp", "holding_bars")], by = "event_id", all.x = TRUE,
  sort = FALSE)
winner_predictions <- winner_predictions[order(winner_predictions$signal_timestamp), , drop = FALSE]

set.seed(contract$random_seed + 2000L)
random_rows <- vector("list", contract$simulations)
for (simulation in seq_len(contract$simulations)) {
  random <- winner_predictions
  random$permit <- FALSE
  for (fold in unique(random$fold)) {
    idx <- which(random$fold == fold)
    keep <- sum(winner_predictions$permit[idx])
    if (keep > 0L) random$permit[sample(idx, keep, replace = FALSE)] <- TRUE
  }
  random_rows[[simulation]] <- data.frame(simulation = simulation,
    total_return = him041_compound_return(random$primary_return[random$permit]),
    mean_trade = if (any(random$permit)) mean(random$primary_return[random$permit]) else NA_real_,
    stringsAsFactors = FALSE)
}
random_controls <- do.call(rbind, random_rows)
write.csv(random_controls, file.path(run_dir, "him041_matched_random_permission_controls.csv"), row.names = FALSE)

calibration_events <- events[events$feature_complete & events$signal_date >= contract$calibration_start &
  events$signal_date <= contract$development_end, , drop = FALSE]
winner_permission <- setNames(winner_predictions$permit, winner_predictions$event_id)
parent_permission <- setNames(rep(TRUE, nrow(calibration_events)), calibration_events$event_id)
hand_permission <- setNames(calibration_events$asset_trend >= 0, calibration_events$event_id)

winner_primary <- him041_replay_permissions(feature_panel, calibration_events, winner_permission,
  contract$primary_bps, "SELECTED_PRIMARY", contract)
winner_gross <- him041_replay_permissions(feature_panel, calibration_events, winner_permission,
  0, "SELECTED_GROSS", contract)
winner_stress <- him041_replay_permissions(feature_panel, calibration_events, winner_permission,
  contract$stress_bps, "SELECTED_STRESS", contract)
parent_primary <- him041_replay_permissions(feature_panel, calibration_events, parent_permission,
  contract$primary_bps, "PARENT_PRIMARY", contract)
hand_primary <- him041_replay_permissions(feature_panel, calibration_events, hand_permission,
  contract$primary_bps, "HAND_TREND_GE_ZERO", contract)
delay_summary <- him041_policy_summary(winner_predictions, "delay1_return")
delay_policy <- data.frame(policy = "SELECTED_DELAY1",
  total_return = delay_summary$total_return, maximum_drawdown = delay_summary$trade_close_drawdown,
  exposure = NA_real_, mean_annual_turnover = NA_real_, trade_count = delay_summary$trade_count,
  hit_rate = delay_summary$hit_rate, mean_trade = delay_summary$mean_trade,
  median_trade = delay_summary$median_trade, median_holding_bars = NA_real_, stringsAsFactors = FALSE)
no_trade <- data.frame(policy = "NO_TRADE", total_return = 0, maximum_drawdown = 0,
  exposure = 0, mean_annual_turnover = 0, trade_count = 0, hit_rate = NA_real_,
  mean_trade = NA_real_, median_trade = NA_real_, median_holding_bars = NA_real_)
policy_summary <- rbind(winner_primary$summary, winner_gross$summary, winner_stress$summary,
  parent_primary$summary, hand_primary$summary, delay_policy, no_trade)
write.csv(policy_summary, file.path(run_dir, "him041_policy_summary.csv"), row.names = FALSE)

actual_total <- winner_primary$summary$total_return
random_p90 <- as.numeric(stats::quantile(random_controls$total_return, .90, names = FALSE, type = 8))
random_percentile <- mean(random_controls$total_return < actual_total)
shift_brier_p90 <- as.numeric(stats::quantile(shift_controls$maximum_brier_improvement, .90,
  names = FALSE, type = 8))
shift_brier_percentile <- mean(shift_controls$maximum_brier_improvement < winner_metric$brier_improvement)

gate_table <- data.frame(
  gate = c("source_and_parent_integrity", "synthetic_recovery", "positive_brier_improvement",
    "permitted_return_separation", "positive_and_parent_improving_policy",
    "matched_random_p90", "familywise_shift_p90", "minimum_participation"),
  passed = c(all(integrity$passed) && all(parent_audit$passed), all(synthetic$gate_pass),
    winner_metric$brier_improvement > 0,
    winner_metric$permitted_mean_return > winner_metric$rejected_mean_return &&
      winner_metric$permitted_mean_return > winner_metric$parent_mean_return,
    actual_total > 0 && actual_total > parent_primary$summary$total_return,
    actual_total > random_p90,
    winner_metric$brier_improvement > shift_brier_p90,
    winner_metric$permitted_fraction >= contract$min_participation),
  observed = c("all checks", "9/9", sprintf("%.6f", winner_metric$brier_improvement),
    sprintf("%.5f vs %.5f vs %.5f", winner_metric$permitted_mean_return,
      winner_metric$rejected_mean_return, winner_metric$parent_mean_return),
    sprintf("%.4f vs parent %.4f", actual_total, parent_primary$summary$total_return),
    sprintf("%.3f percentile; p90 %.4f", random_percentile, random_p90),
    sprintf("%.3f percentile; p90 %.6f", shift_brier_percentile, shift_brier_p90),
    sprintf("%.3f", winner_metric$permitted_fraction)), stringsAsFactors = FALSE)
write.csv(gate_table, file.path(run_dir, "him041_calibration_gates.csv"), row.names = FALSE)

status <- if (all(gate_table$passed)) {
  "POSITIVE_CONTROL_CALIBRATION_WORKED_FRESH_CONFIRMATION_NOT_READ"
} else {
  "STOP_CALIBRATION_GATES_FAILED_FRESH_CONFIRMATION_NOT_READ"
}

attempt_ledger <- data.frame(
  attempt_id = contract$attempt_id, date = "2026-08-23", candidate_count = nrow(registry),
  candidate_ids = paste(registry$variant_id, collapse = ";"), selected_variant = winner_id,
  status = status, outcome_zone = "OUTCOME_AWARE_REUSED_CALIBRATION",
  confirmation_read = FALSE, stringsAsFactors = FALSE)
write.csv(attempt_ledger, file.path(run_dir, "him041_attempt_ledger.csv"), row.names = FALSE)

run_spec <- data.frame(
  field = c("hypothesis_id", "attempt_id", "as_of_timestamp", "source", "symbols",
    "timeframe", "calibration_window", "confirmation_start", "maximum_source_session",
    "parent", "costs", "candidate_family", "matched_controls", "confirmation_read"),
  value = c("HYP-IMOM-04.1", contract$attempt_id, contract$as_of_timestamp,
    "Alpaca SIP adjusted archive cache", "TSLA;QQQ", "30Min",
    "2018-01-02 through 2023-12-29; OOF 2021Q1-2023Q4", "2024-01-02",
    as.character(max(bars$session_date)), "unchanged HYP-IMOM-01.1 SMA8/SMA14",
    "0;10;20 bp/side", paste(registry$variant_id, collapse = ";"),
    "200 matched random; 200 familywise whole-session shifts", "FALSE"),
  stringsAsFactors = FALSE)
write.csv(run_spec, file.path(run_dir, "him041_run_spec.csv"), row.names = FALSE)

png(file.path(visual_dir, "him041_feature_atlas.png"), width = 1500, height = 850, res = 150)
old_par <- par(mfrow = c(1, 2), mar = c(5, 8, 3, 1))
ordered <- metrics[order(metrics$brier_improvement), , drop = FALSE]
colors <- ifelse(ordered$variant_id == winner_id, "#D97706", "#2563EB")
barplot(ordered$brier_improvement, names.arg = ordered$variant_id, las = 1, col = colors,
  border = NA, horiz = TRUE, xlab = "OOF Brier improvement vs intercept",
  main = "Predictive separation")
abline(v = 0, col = "#374151")
return_delta <- ordered$permitted_mean_return - ordered$rejected_mean_return
barplot(return_delta, names.arg = ordered$variant_id, las = 1, col = colors,
  border = NA, horiz = TRUE, xlab = "Permitted minus rejected mean net return",
  main = "Economic separation")
abline(v = 0, col = "#374151")
par(old_par)
dev.off()

png(file.path(visual_dir, "him041_falsification_controls.png"), width = 1500, height = 750, res = 150)
old_par <- par(mfrow = c(1, 2), mar = c(5, 5, 3, 1))
hist(random_controls$total_return, breaks = 25, col = "#BFDBFE", border = "white",
  main = "Matched random permissions", xlab = "2021-2023 primary-cost total return")
abline(v = actual_total, col = "#D97706", lwd = 3)
abline(v = random_p90, col = "#991B1B", lwd = 2, lty = 2)
hist(shift_controls$maximum_brier_improvement, breaks = 25, col = "#DDD6FE", border = "white",
  main = "Familywise session shifts", xlab = "Best Brier improvement across nine variants")
abline(v = winner_metric$brier_improvement, col = "#D97706", lwd = 3)
abline(v = shift_brier_p90, col = "#991B1B", lwd = 2, lty = 2)
par(old_par)
dev.off()

equity_data <- merge(
  winner_primary$path[c("timestamp_utc", "equity")],
  parent_primary$path[c("timestamp_utc", "equity")], by = "timestamp_utc", suffixes = c("_winner", "_parent"))
equity_data <- merge(equity_data, hand_primary$path[c("timestamp_utc", "equity")], by = "timestamp_utc")
names(equity_data)[names(equity_data) == "equity"] <- "equity_hand"
write.csv(equity_data, file.path(run_dir, "him041_policy_equity_curves.csv"), row.names = FALSE)
png(file.path(visual_dir, "him041_policy_equity_curves.png"), width = 1500, height = 750, res = 150)
matplot(equity_data$timestamp_utc,
  equity_data[c("equity_winner", "equity_parent", "equity_hand")] / contract$initial_wealth - 1,
  type = "l", lwd = c(3, 2, 2), lty = c(1, 1, 2), col = c("#D97706", "#6B7280", "#2563EB"),
  xlab = "", ylab = "Cumulative return", main = "Outcome-aware TSLA calibration replay")
abline(h = 0, col = "#D1D5DB")
legend("topleft", legend = c(paste("Selected", winner_id), "Unfiltered parent", "Hand trend >= 0"),
  col = c("#D97706", "#6B7280", "#2563EB"), lwd = c(3, 2, 2), lty = c(1, 1, 2), bty = "n")
dev.off()

pick_event <- function(condition, decreasing = TRUE) {
  candidate <- winner_predictions[condition & !is.na(winner_predictions$primary_return), , drop = FALSE]
  if (!nrow(candidate)) return(NULL)
  candidate <- candidate[order(candidate$primary_return, decreasing = decreasing), , drop = FALSE]
  candidate[1L, , drop = FALSE]
}
selections <- list(
  permitted_winner = pick_event(winner_predictions$permit & winner_predictions$primary_return > 0, TRUE),
  permitted_loser = pick_event(winner_predictions$permit & winner_predictions$primary_return <= 0, FALSE),
  rejected_winner = pick_event(!winner_predictions$permit & winner_predictions$primary_return > 0, TRUE),
  rejected_loser = pick_event(!winner_predictions$permit & winner_predictions$primary_return <= 0, FALSE),
  permitted_overnight = pick_event(winner_predictions$permit & winner_predictions$overnight, TRUE),
  high_whipsaw = pick_event(winner_predictions$whipsaw_count >=
      stats::quantile(winner_predictions$whipsaw_count, .90, na.rm = TRUE), FALSE))
selections <- selections[!vapply(selections, is.null, logical(1))]
if (length(selections)) {
  selection_table <- do.call(rbind, Map(function(x, label) { x$panel_label <- label; x },
    selections, names(selections)))
  selection_table <- selection_table[!duplicated(selection_table$event_id), , drop = FALSE]
  write.csv(selection_table, file.path(run_dir, "him041_representative_trade_tapes.csv"), row.names = FALSE)
  png(file.path(visual_dir, "him041_representative_trade_tapes.png"), width = 1600,
    height = 350 * ceiling(nrow(selection_table) / 2), res = 150)
  old_par <- par(mfrow = c(ceiling(nrow(selection_table) / 2), 2), mar = c(3, 4, 3, 1))
  for (i in seq_len(nrow(selection_table))) {
    row <- selection_table[i, ]
    center <- row$signal_panel_row_id
    idx <- seq(max(1L, center - 26L), min(nrow(feature_panel), center + 39L))
    panel <- feature_panel[idx, , drop = FALSE]
    plot(seq_along(idx), panel$close, type = "l", col = "#111827", lwd = 2,
      xlab = "30-minute bars around signal", ylab = "Adjusted price",
      main = sprintf("%s | %s | net %.2f%%", row$panel_label, row$signal_date,
        100 * row$primary_return))
    lines(seq_along(idx), panel$fast, col = "#D97706", lwd = 1.5)
    lines(seq_along(idx), panel$slow, col = "#2563EB", lwd = 1.5)
    abline(v = which(idx == center), col = "#991B1B", lty = 2, lwd = 2)
  }
  par(old_par)
  dev.off()
}

report <- c(
  "# HYP-IMOM-04.1 TSLA 30-Minute SMA Permission Positive Control",
  "", paste0("Status: `", status, "`"), "",
  "Outcome zone: `OUTCOME_AWARE_REUSED_CALIBRATION`", "",
  "Fresh confirmation: `NOT_READ`", "",
  "## Question", "",
  "Can six causal state and entry-quality features, plus three frozen AND gates, identify fresh TSLA 30-minute SMA8/SMA14 crossovers whose expected move survives explicit costs?",
  "", "## Integrity and synthetic control", "",
  sprintf("All %d source/parent checks passed. All %d planted feature and interaction cases were recovered before TSLA labels were scored.",
    nrow(integrity) + nrow(parent_audit), nrow(synthetic)), "",
  "## Feature support", "",
  sprintf("The parent ledger contains %d events; %d are common-feature eligible. Eligibility begins on %s because the lagged ATR14/252 percentile is the longest causal history requirement.",
    nrow(events), sum(events$feature_complete), min(events$signal_date[events$feature_complete])), "",
  "## Calibration readout", "",
  sprintf("The selected variant was `%s`. OOF Brier improvement versus the fold-specific intercept was %.6f. It permitted %.1f%% of scored events; permitted mean net trade return was %.3f%% versus %.3f%% for rejected events and %.3f%% for the parent event set.",
    winner_id, winner_metric$brier_improvement, 100 * winner_metric$permitted_fraction,
    100 * winner_metric$permitted_mean_return, 100 * winner_metric$rejected_mean_return,
    100 * winner_metric$parent_mean_return), "",
  sprintf("At primary costs the selected replay returned %.2f%% versus %.2f%% for the unfiltered parent. Its matched-random timing percentile was %.1f%%; the observed Brier improvement ranked at %.1f%% of familywise whole-session shifts.",
    100 * actual_total, 100 * parent_primary$summary$total_return, 100 * random_percentile,
    100 * shift_brier_percentile), "",
  "## Gate decision", "",
  sprintf("The retrospective calibration passed %d/%d frozen gates.", sum(gate_table$passed), nrow(gate_table)), "",
  if (all(gate_table$passed))
    "Record a worked positive-control calibration example. This is pedagogical reused-outcome evidence, not an independently discovered edge. Stop before 2024+ transport."
  else
    "Record a calibration STOP. Do not alter the feature atlas inside CAL-A01 and do not open 2024+ transport.",
  "", "## Evidence files", "",
  "- `him041_run_spec.csv`", "- `him041_synthetic_recovery.csv`",
  "- `him041_tsla_parent_event_ledger.csv`", "- `him041_model_metrics.csv`",
  "- `him041_threshold_ledger.csv`", "- `him041_policy_summary.csv`",
  "- `him041_calibration_gates.csv`", "- `him041_familywise_session_shift_controls.csv`",
  "- `him041_matched_random_permission_controls.csv`", "- `visuals/`"
)
writeLines(report, file.path(run_dir, "him041_report.md"))
writeLines(c(status, "FRESH_CONFIRMATION_NOT_READ"), file.path(run_dir, "STATUS.txt"))

message(status)
message(sprintf("selected=%s brier_improvement=%.6f permitted=%.1f%%", winner_id,
  winner_metric$brier_improvement, 100 * winner_metric$permitted_fraction))
message(sprintf("policy=%.2f%% parent=%.2f%% random_pct=%.1f%% shift_pct=%.1f%%", 100 * actual_total,
  100 * parent_primary$summary$total_return, 100 * random_percentile, 100 * shift_brier_percentile))
message(sprintf("artifacts=%s", run_dir))
