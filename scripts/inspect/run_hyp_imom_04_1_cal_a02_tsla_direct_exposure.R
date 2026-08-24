options(stringsAsFactors = FALSE)

repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- file.path(repo, ".codex_r_libs")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))

source(file.path(repo, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo, "operator_hypothesis_lab", "R",
  "gen5_hyp_imom_04_1_cal_a02_tsla_direct_exposure.R"))

contract <- him042_contract()
him042_validate_contract(contract)
run_dir <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab",
  "hyp_imom_04_1_cal_a02_tsla_direct_exposure_20260823")
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cache_dir <- file.path(repo, "data_cache", "alpaca_intraday_30min")
load_year <- function(year) {
  base_path <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d.rds", year))
  smh_path <- file.path(cache_dir, sprintf("intraday_30min_sip_smh_%d.rds", year))
  if (!file.exists(base_path) || !file.exists(smh_path)) {
    him042_stop(paste("Frozen TSLA/QQQ/SPY/SMH cache is incomplete for", year))
  }
  base <- readRDS(base_path)
  smh <- readRDS(smh_path)
  rbind(base[base$symbol %in% c("TSLA", "QQQ", "SPY"), , drop = FALSE], smh)
}

bars <- do.call(rbind, lapply(2017:2023, load_year))
bars <- bars[!duplicated(bars[c("symbol", "timestamp_utc")]), , drop = FALSE]
bars <- bars[order(bars$symbol, bars$timestamp_utc), , drop = FALSE]
bars <- imom30_apply_rth_calendar(bars)
bars <- imom30_apply_archive_exclusions(bars)
bars$session_date <- as.Date(bars$session_date)
bars <- bars[bars$session_date >= contract$prehistory_start &
               bars$session_date <= contract$development_end, , drop = FALSE]

bar_count_long <- aggregate(bar_slot ~ session_date + symbol, bars, length)
bar_count_matrix <- xtabs(bar_slot ~ session_date + symbol, bar_count_long)
count_mismatch <- apply(bar_count_matrix, 1L, function(x) length(unique(as.numeric(x))) != 1L)
mismatch_dates <- as.Date(rownames(bar_count_matrix)[count_mismatch])
prehistory_exclusions <- data.frame(
  session_date = mismatch_dates,
  reason = "UNEQUAL_CROSS_SYMBOL_INTRADAY_BAR_COUNT",
  calibration_window = mismatch_dates >= contract$development_start,
  stringsAsFactors = FALSE)
write.csv(prehistory_exclusions, file.path(run_dir, "him042_prehistory_session_exclusions.csv"),
          row.names = FALSE)
if (nrow(prehistory_exclusions) && any(prehistory_exclusions$calibration_window)) {
  him042_stop("Unequal cross-symbol bar counts reach the 2018-2023 calibration window.")
}
if (length(mismatch_dates)) bars <- bars[!bars$session_date %in% mismatch_dates, , drop = FALSE]

coverage <- do.call(rbind, lapply(2017:2023, function(year) {
  x <- bars[as.integer(format(bars$session_date, "%Y")) == year, , drop = FALSE]
  counts <- table(x$symbol)
  sessions <- lapply(contract$symbols, function(symbol) sort(unique(x$session_date[x$symbol == symbol])))
  data.frame(
    year = year, first_session = min(sessions[[1L]]), last_session = max(sessions[[1L]]),
    session_count = length(sessions[[1L]]),
    tsla_bars = unname(counts[["TSLA"]]), qqq_bars = unname(counts[["QQQ"]]),
    spy_bars = unname(counts[["SPY"]]), smh_bars = unname(counts[["SMH"]]),
    exact_calendars = all(vapply(sessions[-1L], identical, logical(1L), sessions[[1L]])),
    exact_bar_counts = length(unique(unname(counts[contract$symbols]))) == 1L,
    stringsAsFactors = FALSE)
}))

source_checks <- data.frame(
  check = c("four_symbols_only", "no_confirmation_bars", "unique_symbol_timestamps",
            "exact_session_calendars", "exact_bar_counts", "archive_gaps_excluded",
            "completed_slot_grid", "prehistory_only_count_exclusions"),
  passed = c(
    identical(sort(unique(bars$symbol)), sort(contract$symbols)),
    all(bars$session_date < contract$confirmation_start),
    !anyDuplicated(bars[c("symbol", "timestamp_utc")]),
    all(coverage$exact_calendars), all(coverage$exact_bar_counts),
    !any(bars$session_date %in% imom30_archive_gap_dates()),
    all(bars$bar_slot %in% 1:13),
    !nrow(prehistory_exclusions) || all(!prehistory_exclusions$calibration_window)),
  stringsAsFactors = FALSE)
write.csv(coverage, file.path(run_dir, "him042_source_coverage.csv"), row.names = FALSE)
write.csv(source_checks, file.path(run_dir, "him042_source_checks.csv"), row.names = FALSE)
if (!all(source_checks$passed)) him042_stop("Source-integrity gate failed.")

synthetic <- him042_synthetic_suite(contract)
write.csv(synthetic, file.path(run_dir, "him042_synthetic_recovery.csv"), row.names = FALSE)
if (!all(synthetic$gate_pass)) him042_stop("Planted model recovery failed.")

panel <- him042_build_session_panel(bars, contract)
write.csv(panel, file.path(run_dir, "him042_session_feature_ledger.csv"), row.names = FALSE)
feature_support <- data.frame(
  year = 2018:2023,
  sessions = vapply(2018:2023, function(year) sum(as.integer(format(panel$session_date, "%Y")) == year), integer(1L)),
  complete_sessions = vapply(2018:2023, function(year) sum(as.integer(format(panel$session_date, "%Y")) == year & panel$feature_complete), integer(1L)),
  stringsAsFactors = FALSE)
feature_support$complete_fraction <- feature_support$complete_sessions / feature_support$sessions
write.csv(feature_support, file.path(run_dir, "him042_feature_support.csv"), row.names = FALSE)
feature_correlations <- stats::cor(panel[panel$feature_complete, him042_feature_names()],
                                   method = "spearman", use = "complete.obs")
write.csv(cbind(feature = rownames(feature_correlations), as.data.frame(feature_correlations)),
          file.path(run_dir, "him042_feature_spearman_correlations.csv"), row.names = FALSE)

oof <- him042_oof_predictions(panel, contract)
predictions <- oof$predictions
metrics <- him042_prediction_metrics(predictions)
write.csv(predictions, file.path(run_dir, "him042_oof_predictions.csv"), row.names = FALSE)
write.csv(metrics, file.path(run_dir, "him042_model_metrics.csv"), row.names = FALSE)
write.csv(oof$coefficients, file.path(run_dir, "him042_ridge_coefficient_ledger.csv"), row.names = FALSE)
write.csv(oof$trees, file.path(run_dir, "him042_tree_structure_ledger.csv"), row.names = FALSE)
write.csv(oof$folds, file.path(run_dir, "him042_fold_audit.csv"), row.names = FALSE)
if (!all(oof$folds$embargo_pass)) him042_stop("OOF target embargo failed.")

primary <- predictions[predictions$model_id == "R1_RIDGE", , drop = FALSE]
tree_predictions <- predictions[predictions$model_id == "T1_DEPTH2", , drop = FALSE]
panel_index <- match(primary$row_id, panel$row_id)
primary$asset_trend_200 <- panel$asset_trend_200[panel_index]
primary$tsla_close_at_decision <- panel$tsla_close[panel_index]
tree_position <- tree_predictions$permit[match(primary$row_id, tree_predictions$row_id)]
hand_position <- primary$asset_trend_200 >= 0
oracle_position <- primary$actual_log_return > him042_roundtrip_log_buffer(contract$primary_bps)

policy_runs <- list(
  him042_policy_replay(primary, primary$permit, 0, "R1_GROSS"),
  him042_policy_replay(primary, primary$permit, contract$primary_bps, "R1_PRIMARY"),
  him042_policy_replay(primary, primary$permit, contract$stress_bps, "R1_STRESS"),
  him042_policy_replay(primary, tree_position, contract$primary_bps, "T1_PRIMARY"),
  him042_policy_replay(primary, rep(1L, nrow(primary)), contract$primary_bps, "ALWAYS_LONG_PRIMARY"),
  him042_policy_replay(primary, hand_position, contract$primary_bps, "HAND_TREND_PRIMARY"),
  him042_policy_replay(primary, rep(0L, nrow(primary)), contract$primary_bps, "CASH"),
  him042_policy_replay(primary, oracle_position, contract$primary_bps, "ORACLE_PRIMARY"))
policy_summary <- do.call(rbind, lapply(policy_runs, `[[`, "summary"))
policy_curves <- do.call(rbind, lapply(policy_runs, `[[`, "curve"))
policy_quarters <- do.call(rbind, lapply(policy_runs, `[[`, "quarterly"))
write.csv(policy_summary, file.path(run_dir, "him042_policy_summary.csv"), row.names = FALSE)
write.csv(policy_curves, file.path(run_dir, "him042_policy_equity_curves.csv"), row.names = FALSE)
write.csv(policy_quarters, file.path(run_dir, "him042_policy_quarterly_returns.csv"), row.names = FALSE)

oracle_summary <- policy_summary[policy_summary$policy == "ORACLE_PRIMARY", , drop = FALSE]
always_summary <- policy_summary[policy_summary$policy == "ALWAYS_LONG_PRIMARY", , drop = FALSE]
oracle_accounting <- data.frame(
  check = c("oracle_positive", "oracle_exceeds_always_long", "oracle_zero_downside_capture",
            "oracle_nontrivial_exposure"),
  passed = c(oracle_summary$total_return > 0,
             oracle_summary$total_return > always_summary$total_return,
             oracle_summary$downside_capture == 0,
             oracle_summary$exposure > 0 & oracle_summary$exposure < 1),
  stringsAsFactors = FALSE)
write.csv(oracle_accounting, file.path(run_dir, "him042_oracle_accounting.csv"), row.names = FALSE)
if (!all(oracle_accounting$passed)) him042_stop("Oracle policy-accounting control failed.")

eligible_index <- which(panel$feature_complete)
set.seed(contract$random_seed + 1000L)
shift_offsets <- sample(seq_len(length(eligible_index) - 1L), contract$simulations, replace = FALSE)
shift_path <- file.path(run_dir, "him042_familywise_target_shift_controls.csv")
shift_controls <- if (file.exists(shift_path)) read.csv(shift_path) else data.frame()
completed_simulations <- if (nrow(shift_controls)) shift_controls$simulation else integer()
for (simulation in seq_len(contract$simulations)) {
  if (simulation %in% completed_simulations) next
  shifted <- panel
  shifted$forward_log_return[eligible_index] <- him042_circular_shift(
    panel$forward_log_return[eligible_index], shift_offsets[[simulation]])
  shifted$forward_simple_return[eligible_index] <- exp(shifted$forward_log_return[eligible_index]) - 1
  shifted_oof <- him042_oof_predictions(shifted, contract)
  shifted_metrics <- him042_prediction_metrics(shifted_oof$predictions)
  row <- data.frame(
    simulation = simulation, shift_sessions = shift_offsets[[simulation]],
    best_model = shifted_metrics$model_id[[which.max(shifted_metrics$mse_improvement)]],
    maximum_mse_improvement = max(shifted_metrics$mse_improvement),
    ridge_mse_improvement = shifted_metrics$mse_improvement[shifted_metrics$model_id == "R1_RIDGE"],
    tree_mse_improvement = shifted_metrics$mse_improvement[shifted_metrics$model_id == "T1_DEPTH2"],
    stringsAsFactors = FALSE)
  shift_controls <- rbind(shift_controls, row)
  shift_controls <- shift_controls[order(shift_controls$simulation), , drop = FALSE]
  if (simulation %% 10L == 0L || simulation == contract$simulations) {
    write.csv(shift_controls, shift_path, row.names = FALSE)
    message(sprintf("familywise shift control %d/%d", simulation, contract$simulations))
  }
}
write.csv(shift_controls, shift_path, row.names = FALSE)

random_path <- file.path(run_dir, "him042_matched_permission_controls.csv")
matched_controls <- if (file.exists(random_path)) read.csv(random_path) else data.frame()
completed_random <- if (nrow(matched_controls)) matched_controls$simulation else integer()
for (simulation in seq_len(contract$simulations)) {
  if (simulation %in% completed_random) next
  shifted_permission <- him042_matched_permission(primary, simulation, contract$random_seed + 2000L)
  replay <- him042_policy_replay(primary, shifted_permission, contract$primary_bps,
                                 paste0("MATCHED_", simulation))$summary
  row <- data.frame(
    simulation = simulation, total_return = replay$total_return,
    maximum_drawdown = replay$maximum_drawdown, exposure = replay$exposure,
    upside_capture = replay$upside_capture, downside_capture = replay$downside_capture,
    positive_quarters = replay$positive_quarters, stringsAsFactors = FALSE)
  matched_controls <- rbind(matched_controls, row)
  matched_controls <- matched_controls[order(matched_controls$simulation), , drop = FALSE]
}
write.csv(matched_controls, random_path, row.names = FALSE)

ridge_metric <- metrics[metrics$model_id == "R1_RIDGE", , drop = FALSE]
ridge_summary <- policy_summary[policy_summary$policy == "R1_PRIMARY", , drop = FALSE]
shift_p90 <- as.numeric(stats::quantile(shift_controls$maximum_mse_improvement, .90,
                                        names = FALSE, type = 8))
shift_percentile <- mean(shift_controls$maximum_mse_improvement < ridge_metric$mse_improvement)
matched_p90 <- as.numeric(stats::quantile(matched_controls$total_return, .90,
                                          names = FALSE, type = 8))
matched_percentile <- mean(matched_controls$total_return < ridge_summary$total_return)
positive_controls_pass <- all(synthetic$gate_pass) && all(oracle_accounting$passed)

gates <- data.frame(
  gate = c("source_and_embargo_integrity", "planted_models_and_oracle",
           "positive_ridge_mse_improvement", "familywise_target_shift_p90",
           "positive_and_always_long_beating_return", "shallower_than_always_long_drawdown",
           "minimum_upside_capture", "maximum_downside_capture", "bounded_exposure",
           "minimum_positive_quarters", "matched_permission_p90"),
  passed = c(
    all(source_checks$passed) && all(oof$folds$embargo_pass), positive_controls_pass,
    ridge_metric$mse_improvement > 0,
    ridge_metric$mse_improvement > shift_p90,
    ridge_summary$total_return > 0 && ridge_summary$total_return > always_summary$total_return,
    ridge_summary$maximum_drawdown > always_summary$maximum_drawdown,
    ridge_summary$upside_capture >= contract$minimum_upside_capture,
    ridge_summary$downside_capture <= contract$maximum_downside_capture,
    ridge_summary$exposure >= contract$minimum_exposure && ridge_summary$exposure <= contract$maximum_exposure,
    ridge_summary$positive_quarters >= contract$minimum_positive_quarters,
    ridge_summary$total_return > matched_p90),
  observed = c(
    "all source and fold checks",
    sprintf("plants %d/%d; oracle %d/%d", sum(synthetic$gate_pass), nrow(synthetic),
            sum(oracle_accounting$passed), nrow(oracle_accounting)),
    sprintf("%.8f", ridge_metric$mse_improvement),
    sprintf("%.3f percentile; p90 %.8f", shift_percentile, shift_p90),
    sprintf("R1 %.4f; always-long %.4f", ridge_summary$total_return, always_summary$total_return),
    sprintf("R1 %.4f; always-long %.4f", ridge_summary$maximum_drawdown, always_summary$maximum_drawdown),
    sprintf("%.3f", ridge_summary$upside_capture), sprintf("%.3f", ridge_summary$downside_capture),
    sprintf("%.3f", ridge_summary$exposure),
    sprintf("%d/%d", ridge_summary$positive_quarters, ridge_summary$quarter_count),
    sprintf("%.3f percentile; p90 %.4f", matched_percentile, matched_p90)),
  stringsAsFactors = FALSE)
write.csv(gates, file.path(run_dir, "him042_calibration_gates.csv"), row.names = FALSE)

status <- if (all(gates$passed)) {
  "CALIBRATION_PATTERN_PRESENT_FRESH_TRANSPORT_STILL_CLOSED"
} else {
  "STOP_CAL_A02_DIRECT_EXPOSURE_GATES_FAILED_CONFIRMATION_NOT_READ"
}

attempt <- data.frame(
  hypothesis_id = contract$hypothesis_id, attempt_id = contract$attempt_id,
  date = "2026-08-23", models = "R1_RIDGE;T1_DEPTH2",
  feature_count = length(him042_feature_names()), interaction_count = length(him042_interaction_names()),
  selected_primary = "R1_RIDGE", status = status,
  outcome_zone = "OUTCOME_AWARE_REUSED_CALIBRATION", confirmation_read = FALSE,
  stringsAsFactors = FALSE)
write.csv(attempt, file.path(run_dir, "him042_attempt_ledger.csv"), row.names = FALSE)

run_spec <- data.frame(
  field = c("hypothesis_id", "attempt_id", "as_of_timestamp", "provider", "feed", "symbols",
            "timeframe", "decision_clock", "target", "calibration_window", "oof_window",
            "confirmation_start", "maximum_source_session", "features", "interactions",
            "models", "threshold", "costs", "controls", "confirmation_read"),
  value = c(contract$hypothesis_id, contract$attempt_id, contract$as_of_timestamp,
            "Alpaca", "SIP adjusted archive", paste(contract$symbols, collapse = ";"), "30Min-derived session",
            "completed session t; position at next open", "next-open to following-open TSLA log return",
            "2018-01-02 through 2023-12-29", "2021Q1 through 2023Q4", "2024-01-02",
            as.character(max(bars$session_date)), paste(him042_feature_names(), collapse = ";"),
            paste(him042_interaction_names(), collapse = ";"), "R1_RIDGE primary;T1_DEPTH2 secondary",
            sprintf("predicted log return > %.8f", him042_roundtrip_log_buffer(contract$primary_bps)),
            "0;10;20 bp/side", "2 plants;oracle;200 familywise target shifts;200 matched permission shifts",
            "FALSE"), stringsAsFactors = FALSE)
write.csv(run_spec, file.path(run_dir, "him042_run_spec.csv"), row.names = FALSE)

# Human-facing visuals -------------------------------------------------------
colors <- c(R1_PRIMARY = "#E87900", T1_PRIMARY = "#C2410C",
            ALWAYS_LONG_PRIMARY = "#64748B", HAND_TREND_PRIMARY = "#0F766E")
plot_policies <- names(colors)
curves <- policy_curves[policy_curves$policy %in% plot_policies, , drop = FALSE]
png(file.path(visual_dir, "him042_direct_exposure_equity_curves.png"), width = 1600, height = 900, res = 150)
par(mar = c(4.5, 4.5, 3.5, 1))
plot(range(curves$entry_session), range(curves$wealth), type = "n", xlab = "Executable session",
     ylab = "Wealth multiple", main = "CAL-A02 direct-exposure replay - 2021-2023")
for (policy in plot_policies) {
  x <- curves[curves$policy == policy, ]
  lines(x$entry_session, x$wealth, col = colors[[policy]], lwd = if (policy == "R1_PRIMARY") 2.5 else 1.5,
        lty = 1)
}
legend("topleft", legend = c("R1 ridge", "T1 depth-two", "Always long", "Hand trend"),
       col = colors[plot_policies], lwd = c(2.5, 1.5, 1.5, 1.5), lty = 1, bty = "n")
dev.off()

capture_policies <- policy_summary[policy_summary$policy %in% c("R1_PRIMARY", "T1_PRIMARY",
  "ALWAYS_LONG_PRIMARY", "HAND_TREND_PRIMARY", "ORACLE_PRIMARY"), ]
png(file.path(visual_dir, "him042_capture_map.png"), width = 1400, height = 900, res = 150)
par(mar = c(5, 5, 3.5, 2))
plot(capture_policies$downside_capture, capture_policies$upside_capture,
     pch = 19, cex = 1.6, col = c("#E87900", "#C2410C", "#64748B", "#0F766E", "#2563EB"),
     xlim = c(0, 1.05), ylim = c(0, 1.05), xlab = "Downside capture",
     ylab = "Upside capture", main = "Desired region is upper-left")
abline(v = contract$maximum_downside_capture, h = contract$minimum_upside_capture,
       col = "#DC2626", lty = 2)
capture_labels <- c(R1_PRIMARY = "R1", T1_PRIMARY = "T1",
                    ALWAYS_LONG_PRIMARY = "Always long",
                    HAND_TREND_PRIMARY = "Hand trend", ORACLE_PRIMARY = "Oracle")
capture_position <- ifelse(capture_policies$policy == "ALWAYS_LONG_PRIMARY", 2, 4)
text(capture_policies$downside_capture, capture_policies$upside_capture,
     labels = capture_labels[capture_policies$policy], pos = capture_position, cex = .8)
dev.off()

png(file.path(visual_dir, "him042_falsification_controls.png"), width = 1600, height = 760, res = 150)
par(mfrow = c(1, 2), mar = c(5, 4.5, 3.5, 1))
hist(shift_controls$maximum_mse_improvement, breaks = 25, col = "#DDD6FE", border = "white",
     main = "Familywise target shifts", xlab = "Best MSE improvement across R1 and T1")
abline(v = ridge_metric$mse_improvement, col = "#E87900", lwd = 2)
abline(v = shift_p90, col = "#DC2626", lwd = 1.5, lty = 2)
hist(matched_controls$total_return, breaks = 25, col = "#BFDBFE", border = "white",
     main = "Matched permission timing", xlab = "Primary-cost total return")
abline(v = ridge_summary$total_return, col = "#E87900", lwd = 2)
abline(v = matched_p90, col = "#DC2626", lwd = 1.5, lty = 2)
dev.off()

coefficient_plot <- oof$coefficients[oof$coefficients$feature != "(Intercept)", ]
feature_order <- rev(unique(coefficient_plot$feature))
fold_order <- unique(coefficient_plot$fold)
coefficient_matrix <- matrix(NA_real_, nrow = length(feature_order), ncol = length(fold_order),
                             dimnames = list(feature_order, fold_order))
for (i in seq_len(nrow(coefficient_plot))) {
  coefficient_matrix[coefficient_plot$feature[[i]], coefficient_plot$fold[[i]]] <-
    coefficient_plot$coefficient_standardized[[i]]
}
png(file.path(visual_dir, "him042_ridge_coefficient_stability.png"), width = 1700, height = 1050, res = 150)
par(mar = c(6, 12, 3.5, 2))
limit <- max(abs(coefficient_matrix), na.rm = TRUE)
image(seq_len(ncol(coefficient_matrix)), seq_len(nrow(coefficient_matrix)), t(coefficient_matrix),
      axes = FALSE, col = colorRampPalette(c("#2563EB", "white", "#E87900"))(101),
      zlim = c(-limit, limit), xlab = "", ylab = "", main = "R1 standardized coefficients by OOF fold")
axis(1, at = seq_len(ncol(coefficient_matrix)), labels = colnames(coefficient_matrix), las = 2, cex.axis = .8)
axis(2, at = seq_len(nrow(coefficient_matrix)), labels = rownames(coefficient_matrix), las = 2, cex.axis = .75)
box(); dev.off()

primary_curve <- policy_runs[[2L]]$curve
primary_curve$fold <- primary$fold[match(primary_curve$row_id, primary$row_id)]
window <- 50L
rolling_move <- rep(NA_real_, nrow(primary_curve))
rolling_chop <- rep(NA_real_, nrow(primary_curve))
if (nrow(primary_curve) >= window) {
  for (i in window:nrow(primary_curve)) {
    w <- primary_curve$tsla_interval_return[(i - window + 1L):i]
    rolling_move[[i]] <- prod(1 + w) - 1
    rolling_chop[[i]] <- sum(abs(diff(sign(w))))
  }
}
candidate <- which(is.finite(rolling_move))
ends <- unique(c(candidate[[which.max(rolling_move[candidate])]],
                 candidate[[which.min(rolling_move[candidate])]],
                 candidate[[which.min(abs(rolling_move[candidate]))]],
                 candidate[[which.max(rolling_chop[candidate])]]))
labels <- c("strong_rise", "sharp_decline", "sideways", "whipsaw")[seq_along(ends)]
tape_rows <- list()
png(file.path(visual_dir, "him042_representative_exposure_tapes.png"), width = 1600, height = 1200, res = 150)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 4))
for (j in seq_along(ends)) {
  index <- (ends[[j]] - window + 1L):ends[[j]]
  x <- primary_curve[index, ]
  normalized_price <- cumprod(c(1, head(1 + x$tsla_interval_return, -1L)))
  plot(x$entry_session, normalized_price, type = "l", col = "#111827", lwd = 1.5,
       xlab = "", ylab = "Normalized TSLA open", main = labels[[j]])
  long_index <- which(x$position == 1L)
  if (length(long_index)) points(x$entry_session[long_index], normalized_price[long_index],
                                 pch = 15, cex = .55, col = "#E87900")
  mtext(sprintf("R1 long %.0f%% | TSLA move %+.1f%%", 100 * mean(x$position),
                100 * (prod(1 + x$tsla_interval_return) - 1)), side = 3, line = .2, cex = .75)
  tape_rows[[j]] <- data.frame(tape = labels[[j]], x, normalized_tsla = normalized_price,
                               stringsAsFactors = FALSE)
}
dev.off()
representative_tapes <- do.call(rbind, tape_rows)
write.csv(representative_tapes, file.path(run_dir, "him042_representative_exposure_tapes.csv"), row.names = FALSE)

report <- c(
  "# HYP-IMOM-04.1 CAL-A02 TSLA Direct-Exposure Run Report", "",
  paste0("Status: `", status, "`"), "", "## Boundary and controls", "",
  sprintf("The packet used %d complete causal sessions and scored %d OOF sessions across twelve expanding quarters. The latest source session was `%s`; 2024+ was not read.",
          sum(panel$feature_complete), nrow(primary), max(bars$session_date)), "",
  sprintf("Both planted model controls passed, and all %d oracle-accounting checks passed.", nrow(oracle_accounting)), "",
  "## Predictive readout", "",
  sprintf("R1 OOF MSE improvement versus fold drift was `%.8f`; correlation was `%.4f`; the familywise target-shift percentile was `%.1f%%` and p90 was `%.8f`.",
          ridge_metric$mse_improvement, ridge_metric$correlation, 100 * shift_percentile, shift_p90), "",
  sprintf("R1 permitted `%.1f%%` of sessions. Mean permitted TSLA interval return was `%+.3f%%` versus `%+.3f%%` when rejected.",
          100 * ridge_metric$permission_fraction, 100 * ridge_metric$permitted_mean_return,
          100 * ridge_metric$rejected_mean_return), "",
  "## Executable policy", "",
  sprintf("At 10 bp/side, R1 returned `%+.2f%%` with maximum drawdown `%+.2f%%`, exposure `%.1f%%`, upside capture `%.1f%%`, downside capture `%.1f%%`, and %d/%d positive quarters.",
          100 * ridge_summary$total_return, 100 * ridge_summary$maximum_drawdown,
          100 * ridge_summary$exposure, 100 * ridge_summary$upside_capture,
          100 * ridge_summary$downside_capture, ridge_summary$positive_quarters,
          ridge_summary$quarter_count), "",
  sprintf("Always-long returned `%+.2f%%` with maximum drawdown `%+.2f%%`. R1 ranked at the `%.1f%%` percentile of matched permission timing; matched p90 was `%+.2f%%`.",
          100 * always_summary$total_return, 100 * always_summary$maximum_drawdown,
          100 * matched_percentile, 100 * matched_p90), "",
  "## Gate decision", "",
  sprintf("CAL-A02 passed %d/%d frozen gates. Fresh 2024+ transport remains closed.", sum(gates$passed), nrow(gates)), "",
  if (all(gates$passed))
    "Record a calibration pattern and request a separate operator decision before any fresh transport."
  else
    "Record a CAL-A02 STOP. Do not change the frozen target, features, models, thresholds, or gates; any new outcome-aware attempt is CAL-A03.",
  "", "## Evidence", "",
  "- `him042_run_spec.csv`", "- `him042_session_feature_ledger.csv`",
  "- `him042_oof_predictions.csv`", "- `him042_model_metrics.csv`",
  "- `him042_policy_summary.csv`", "- `him042_calibration_gates.csv`",
  "- `visuals/him042_direct_exposure_equity_curves.png`",
  "- `visuals/him042_capture_map.png`", "- `visuals/him042_representative_exposure_tapes.png`")
writeLines(report, file.path(run_dir, "him042_report.md"))
writeLines(status, file.path(run_dir, "STATUS.txt"))
writeLines("CONFIRMATION_NOT_READ", file.path(run_dir, "CONFIRMATION_NOT_READ.txt"))

message(status)
message(sprintf("R1 MSE improvement %.8f; familywise percentile %.1f%%",
                ridge_metric$mse_improvement, 100 * shift_percentile))
message(sprintf("R1 primary return %+.2f%%; always-long %+.2f%%; upside/downside capture %.1f%%/%.1f%%",
                100 * ridge_summary$total_return, 100 * always_summary$total_return,
                100 * ridge_summary$upside_capture, 100 * ridge_summary$downside_capture))
message(sprintf("Artifacts: %s", normalizePath(run_dir, winslash = "/", mustWork = TRUE)))
