options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_03_1_cross_sectional_breadth.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)

contract <- hreg31_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_03_1_cross_sectional_breadth_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
signal_registry <- registry[registry$role == "signal_estimator", , drop = FALSE]
target_registry <- registry[registry$role == "target", , drop = FALSE]
parent_targets <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_02_1_trend_direction_registry.csv"), stringsAsFactors = FALSE)
if (nrow(signal_registry) != contract$signal_assets || nrow(target_registry) != contract$target_assets || anyDuplicated(registry$symbol) || !setequal(target_registry$symbol, parent_targets$symbol)) stop("Frozen registry integrity failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_REG_031_RUN_ID", "hyp_reg_03_1_cross_sectional_breadth_20260814")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_REG_031_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = contract$query_start, end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = registry$symbol,
  universe_name = "hyp_reg_03_1_cross_sectional_breadth_panel",
  universe_roles = "ten_sector_signal,unchanged_26_targets,direction_diagnostic_only",
  refresh = refresh, repo_root = repo_root
)
bars <- hreg31_validate_bars(query$bars, contract)
spy_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars[bars$symbol == reg$symbol, , drop = FALSE]
  dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start); missing <- length(setdiff(spy_dates, dates))
  required_pre <- if (reg$role == "signal_estimator") 292L else 65L
  cbind(reg, data.frame(total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates), missing_spy_sessions = missing,
    coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < required_pre) "PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else "COMPLETE", stringsAsFactors = FALSE))
}))
if (any(coverage$coverage_status != "COMPLETE")) stop("One or more assets lack complete frozen diagnostic coverage.", call. = FALSE)

message("HYP-REG-03.1 building the ten-sector cross-sectional breadth signal.")
signal_all <- hreg31_build_signal(bars[bars$symbol %in% signal_registry$symbol, ], signal_registry$symbol, contract)
signal <- signal_all[signal_all$session_date >= contract$analysis_start & signal_all$session_date <= contract$analysis_end, , drop = FALSE]
if (nrow(signal) != length(spy_dates) || any(signal$sector_inputs != contract$signal_assets) || !identical(signal$session_date, spy_dates)) stop("The common sector signal calendar is incomplete.", call. = FALSE)

message("HYP-REG-03.1 joining the common breadth signal to 26 causal target ledgers.")
ledgers <- vector("list", nrow(target_registry))
for (i in seq_len(nrow(target_registry))) {
  reg <- target_registry[i, , drop = FALSE]; message(sprintf("[%02d/%02d] %s", i, nrow(target_registry), reg$symbol))
  x <- hreg31_build_target_ledger(bars[bars$symbol == reg$symbol, ], signal, contract)
  x$instance_id <- reg$instance_id; x$sector <- reg$sector; x$asset_type <- reg$asset_type; x$panel_role <- reg$panel_role
  ledgers[[i]] <- x
}
ledger <- do.call(rbind, ledgers); rownames(ledger) <- NULL
if (anyNA(ledger$breadth_score) || any(ledger$sector_inputs != contract$signal_assets)) stop("Target ledgers contain incomplete breadth rows.", call. = FALSE)

asset_summary <- hreg31_asset_summary(ledger, contract)
panel_summary <- do.call(rbind, lapply(split(asset_summary, asset_summary$horizon), function(x) data.frame(
  horizon = x$horizon[[1L]], assets = nrow(x), median_observations = median_na(x$observations), median_spearman = median_na(x$spearman),
  positive_assets = sum(x$spearman > 0, na.rm = TRUE), positive_asset_fraction = mean(x$spearman > 0, na.rm = TRUE),
  median_accuracy = median_na(x$accuracy), median_up_recall = median_na(x$up_recall), median_down_recall = median_na(x$down_recall),
  median_balanced_accuracy = median_na(x$balanced_accuracy), median_predicted_up_fraction = median_na(x$predicted_up_fraction),
  median_q5_q1_spread = median_na(x$q5_q1_spread), positive_q5_q1_assets = sum(x$q5_q1_spread > 0, na.rm = TRUE), stringsAsFactors = FALSE)))
panel_summary <- panel_summary[order(panel_summary$horizon), ]

calendar_asset <- hreg31_calendar_summary(ledger, contract)
calendar_panel <- do.call(rbind, lapply(split(calendar_asset, interaction(calendar_asset$year, calendar_asset$horizon, drop = TRUE)), function(x) data.frame(
  year = x$year[[1L]], horizon = x$horizon[[1L]], assets = sum(is.finite(x$spearman)), median_spearman = median_na(x$spearman),
  positive_asset_fraction = mean(x$spearman > 0, na.rm = TRUE), stringsAsFactors = FALSE)))
calendar_panel <- calendar_panel[order(calendar_panel$horizon, calendar_panel$year), ]

hidden <- hreg31_hidden_deterioration(ledger, contract)
message("HYP-REG-03.1 running 200 within-calendar-year circular breadth controls.")
placebo <- hreg31_placebo_summary(ledger, signal, contract)
placebo_readout <- do.call(rbind, lapply(c(20L, 63L), function(h) {
  actual <- panel_summary$median_spearman[panel_summary$horizon == h]; controls <- placebo$panel_median_spearman[placebo$horizon == h]
  data.frame(horizon = h, actual_median_spearman = actual, control_median = median_na(controls), control_q90 = as.numeric(stats::quantile(controls, .90, na.rm = TRUE)), actual_percentile = mean(controls <= actual, na.rm = TRUE), stringsAsFactors = FALSE)
}))

positive_years <- vapply(c(20L, 63L), function(h) sum(calendar_panel$horizon == h & calendar_panel$median_spearman > 0), integer(1)); names(positive_years) <- paste0("H", c(20, 63))
hidden_all <- hidden[hidden$year == "ALL", ]; hidden_year <- hidden[hidden$year != "ALL", ]
hidden_negative_years <- vapply(c(20L, 63L), function(h) sum(hidden_year$horizon == h & hidden_year$decay_minus_improve < 0, na.rm = TRUE), integer(1)); names(hidden_negative_years) <- paste0("H", c(20, 63))
gates <- do.call(rbind, list(
  data.frame(gate = "G1_INTEGRITY", threshold = "complete coverage; 10 sector inputs; 26 targets; no confirmation rows", observed = paste0("complete assets ", sum(coverage$coverage_status == "COMPLETE"), "/", nrow(coverage), "; signal dates ", nrow(signal), "; targets ", length(unique(ledger$symbol))), passed = all(coverage$coverage_status == "COMPLETE") && nrow(signal) == length(spy_dates) && all(signal$sector_inputs == 10L) && length(unique(ledger$symbol)) == 26L && !any(ledger$session_date >= contract$confirmation_start)),
  data.frame(gate = "G2_PANEL_ASSOCIATION", threshold = ">0 all horizons and >=0.05 at H20/H63", observed = paste(sprintf("H%d %.3f", panel_summary$horizon, panel_summary$median_spearman), collapse = "; "), passed = all(panel_summary$median_spearman > 0) && all(panel_summary$median_spearman[panel_summary$horizon %in% c(20, 63)] >= contract$minimum_long_spearman)),
  data.frame(gate = "G3_TARGET_BREADTH", threshold = ">=18/26 positive targets at H20/H63", observed = paste(sprintf("H%d %d", panel_summary$horizon[panel_summary$horizon %in% c(20, 63)], panel_summary$positive_assets[panel_summary$horizon %in% c(20, 63)]), collapse = "; "), passed = all(panel_summary$positive_assets[panel_summary$horizon %in% c(20, 63)] >= contract$breadth_assets)),
  data.frame(gate = "G4_DIRECTIONAL_BALANCE", threshold = "median BA >=0.52 and both recalls >0.50 at H20/H63", observed = paste(sprintf("H%d BA %.3f UP %.3f DOWN %.3f", panel_summary$horizon[panel_summary$horizon %in% c(20, 63)], panel_summary$median_balanced_accuracy[panel_summary$horizon %in% c(20, 63)], panel_summary$median_up_recall[panel_summary$horizon %in% c(20, 63)], panel_summary$median_down_recall[panel_summary$horizon %in% c(20, 63)]), collapse = "; "), passed = all(panel_summary$median_balanced_accuracy[panel_summary$horizon %in% c(20, 63)] >= contract$minimum_balanced_accuracy) && all(panel_summary$median_up_recall[panel_summary$horizon %in% c(20, 63)] > .50) && all(panel_summary$median_down_recall[panel_summary$horizon %in% c(20, 63)] > .50)),
  data.frame(gate = "G5_QUINTILE_ORDERING", threshold = "positive panel spread all horizons and >=18/26 targets H20/H63", observed = paste(sprintf("H%d %.4f (%d targets)", panel_summary$horizon, panel_summary$median_q5_q1_spread, panel_summary$positive_q5_q1_assets), collapse = "; "), passed = all(panel_summary$median_q5_q1_spread > 0) && all(panel_summary$positive_q5_q1_assets[panel_summary$horizon %in% c(20, 63)] >= contract$breadth_assets)),
  data.frame(gate = "G6_CALENDAR_STABILITY", threshold = ">=4/6 positive panel years H20/H63", observed = paste(names(positive_years), positive_years, collapse = "; "), passed = all(positive_years >= contract$minimum_positive_years)),
  data.frame(gate = "G7_CIRCULAR_CONTROL", threshold = ">=90th control percentile H20/H63", observed = paste(sprintf("H%d %.1f%%", placebo_readout$horizon, 100 * placebo_readout$actual_percentile), collapse = "; "), passed = all(placebo_readout$actual_percentile >= contract$minimum_placebo_percentile)),
  data.frame(gate = "G8_HIDDEN_DETERIORATION", threshold = "decay gap <0 overall and in >=4/6 years H20/H63", observed = paste(sprintf("H%d gap %.4f (%d years)", hidden_all$horizon, hidden_all$decay_minus_improve, hidden_negative_years[paste0("H", hidden_all$horizon)]), collapse = "; "), passed = all(hidden_all$decay_minus_improve < 0) && all(hidden_negative_years >= contract$minimum_positive_years))
))
status <- if (all(gates$passed)) "DIAGNOSTIC_COMPLETE_STOP_BEFORE_JOINT_FILTER" else "STOP_CROSS_SECTIONAL_BREADTH_GATES_FAILED_NO_JOINT_FILTER"

# Descriptive comparison with the already-frozen HYP-REG-02.1 score.
parent_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_02_1_trend_direction_20260814", "hyp_reg_02_panel_summary.csv")
parent_comparison <- data.frame()
if (file.exists(parent_path)) {
  parent <- utils::read.csv(parent_path, stringsAsFactors = FALSE); parent <- parent[parent$model == "TREND_SMA20_60", ]
  parent_comparison <- merge(panel_summary[c("horizon", "median_spearman", "median_balanced_accuracy", "median_up_recall", "median_down_recall")], parent[c("horizon", "median_spearman", "median_balanced_accuracy", "median_up_recall", "median_down_recall")], by = "horizon", suffixes = c("_cross_sectional", "_single_asset"))
}

ink <- "#202630"; blue <- "#3D8DFF"; orange <- "#F2A65A"; red <- "#D95F59"; gray <- "#B8BCC4"; pale <- "#EDEDED"
spy <- ledger[ledger$symbol == "SPY", ]
png(file.path(visual_dir, "spy_breadth_tape.png"), 1900, 1800, res = 150)
par(mfrow = c(4, 1), mar = c(3.5, 5, 3.2, 2), oma = c(1, 1, 2, 1))
plot(spy$session_date, spy$close, type = "l", col = ink, lwd = 1.1, xlab = "", ylab = "SPY adjusted close", main = "Headline price can rise while sector participation weakens")
lines(spy$session_date, spy$target_sma20, col = blue, lwd = 1.2); lines(spy$session_date, spy$target_sma60, col = orange, lwd = 1.2); legend("topleft", c("SPY", "SMA20", "SMA60"), col = c(ink, blue, orange), lty = 1, bty = "n")
plot(signal$session_date, 100 * signal$breadth_score, type = "l", col = blue, lwd = 1.4, xlab = "", ylab = "Median depth (%)", main = "Cross-sectional breadth strength | median log(close / SMA20)"); abline(h = 0, col = ink)
plot(signal$session_date, 100 * signal$participation_fraction, type = "l", col = ink, lwd = 1.2, ylim = c(0, 100), xlab = "", ylab = "Sector participation (%)", main = "Literal diffusion companion | fraction of 10 sectors above SMA20"); abline(h = 50, col = gray, lty = 2)
plot(signal$session_date, 100 * signal$breadth_impulse20, type = "l", col = red, lwd = 1.1, xlab = "Session", ylab = "20-session change (pp)", main = "Breadth impulse | current median depth minus its 20-session lag"); abline(h = 0, col = gray, lty = 2)
mtext("HYP-REG-03.1 | all signal values known after close; targets begin next open", outer = TRUE, font = 2)
dev.off()

depth_cols <- paste0("depth_", signal_registry$symbol)
month_key <- format(signal$session_date, "%Y-%m")
monthly <- signal[!duplicated(month_key), ]
depth_matrix <- t(as.matrix(monthly[depth_cols])); rownames(depth_matrix) <- signal_registry$symbol
png(file.path(visual_dir, "sector_depth_heatmap.png"), 1900, 900, res = 150)
par(mar = c(6, 6, 4, 2)); lim <- max(abs(depth_matrix), na.rm = TRUE)
image(seq_len(ncol(depth_matrix)), seq_len(nrow(depth_matrix)), t(depth_matrix[nrow(depth_matrix):1, ]), col = grDevices::colorRampPalette(c(red, "white", blue))(100), zlim = c(-lim, lim), axes = FALSE, xlab = "Month", ylab = "", main = "Sector participation broadens and narrows beneath the index")
axis(2, at = seq_len(nrow(depth_matrix)), labels = rev(rownames(depth_matrix)), las = 1); ticks <- seq(1, ncol(depth_matrix), by = 6); axis(1, at = ticks, labels = format(monthly$session_date[ticks], "%Y-%m"), las = 2, cex.axis = .75)
dev.off()

heat <- matrix(NA_real_, nrow = nrow(target_registry), ncol = length(contract$horizons), dimnames = list(target_registry$symbol, paste0("H", contract$horizons)))
for (i in seq_len(nrow(asset_summary))) heat[asset_summary$symbol[[i]], paste0("H", asset_summary$horizon[[i]])] <- asset_summary$spearman[[i]]
png(file.path(visual_dir, "target_spearman_heatmap.png"), 1450, 1500, res = 150)
par(mar = c(5, 8, 4, 7)); limh <- max(abs(heat), na.rm = TRUE)
image(seq_len(ncol(heat)), seq_len(nrow(heat)), t(heat[nrow(heat):1, ]), col = grDevices::colorRampPalette(c(red, "white", blue))(100), zlim = c(-limh, limh), axes = FALSE, xlab = "Forward horizon", ylab = "", main = "Common sector breadth vs each target | non-overlapping samples")
axis(1, at = seq_len(ncol(heat)), labels = colnames(heat)); axis(2, at = seq_len(nrow(heat)), labels = rev(rownames(heat)), las = 1, cex.axis = .75)
for (i in seq_len(nrow(heat))) for (j in seq_len(ncol(heat))) text(j, nrow(heat) - i + 1, sprintf("%.2f", heat[i, j]), cex = .6)
dev.off()

png(file.path(visual_dir, "panel_metrics_and_parent_comparison.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
if (nrow(parent_comparison)) {
  mat <- rbind(`Cross-sectional breadth` = parent_comparison$median_spearman_cross_sectional, `Single-asset 20/60` = parent_comparison$median_spearman_single_asset)
  barplot(mat, beside = TRUE, names.arg = paste0("H", parent_comparison$horizon), col = c(blue, gray), border = NA, ylab = "Median per-target Spearman", main = "New breadth score vs rejected parent"); abline(h = 0, col = ink); legend("topleft", rownames(mat), fill = c(blue, gray), bty = "n", cex = .8)
} else plot.new()
recall <- rbind(`Balanced accuracy` = panel_summary$median_balanced_accuracy, `Up recall` = panel_summary$median_up_recall, `Down recall` = panel_summary$median_down_recall)
barplot(recall, beside = TRUE, names.arg = paste0("H", panel_summary$horizon), col = c(ink, blue, red), border = NA, ylim = c(0, 1), ylab = "Panel median", main = "Direction classification"); abline(h = .5, col = gray, lty = 2); legend("topleft", rownames(recall), fill = c(ink, blue, red), bty = "n", cex = .8)
dev.off()

png(file.path(visual_dir, "hidden_deterioration.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
vals <- rbind(`Breadth decaying` = hidden_all$decay_median, `Stable / improving` = hidden_all$improve_median)
barplot(100 * vals, beside = TRUE, names.arg = paste0("H", hidden_all$horizon), col = c(red, blue), border = NA, ylab = "SPY median forward return (%)", main = "Inside positive SPY trend"); abline(h = 0, col = ink); legend("topleft", rownames(vals), fill = c(red, blue), bty = "n")
hy <- hidden_year
yrmat <- sapply(c(20L, 63L), function(h) hy$decay_minus_improve[hy$horizon == h])
rownames(yrmat) <- 2018:2023; colnames(yrmat) <- c("H20", "H63")
matplot(2018:2023, 100 * yrmat, type = "b", pch = 19, lty = 1, col = c(blue, orange), xlab = "Calendar year", ylab = "Decay minus improving return (pp)", main = "Calendar stability of deterioration gap"); abline(h = 0, col = gray); legend("bottomleft", colnames(yrmat), col = c(blue, orange), lty = 1, pch = 19, bty = "n")
dev.off()

png(file.path(visual_dir, "calendar_and_placebo.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1)); cr <- range(c(calendar_panel$median_spearman[is.finite(calendar_panel$median_spearman)], 0)); if (diff(cr) == 0) cr <- c(-.01, .01)
for (h in c(20L, 63L)) { x <- calendar_panel[calendar_panel$horizon == h, ]; col <- if (h == 20) blue else orange; if (h == 20) plot(x$year, x$median_spearman, type = "b", pch = 19, col = col, lwd = 2, ylim = cr, xlab = "Calendar year", ylab = "Median per-target Spearman", main = "Calendar stability") else lines(x$year, x$median_spearman, type = "b", pch = 19, col = col, lwd = 2) }; abline(h = 0, col = gray); legend("bottomleft", c("H20", "H63"), col = c(blue, orange), lty = 1, pch = 19, bty = "n")
pr <- range(c(placebo$panel_median_spearman, placebo_readout$actual_median_spearman), na.rm = TRUE); boxplot(panel_median_spearman ~ factor(horizon), data = placebo, col = pale, border = gray, ylim = pr, xlab = "Forward horizon", ylab = "Panel median Spearman", main = "Circular timing controls vs actual"); points(match(placebo_readout$horizon, sort(unique(placebo$horizon))), placebo_readout$actual_median_spearman, pch = 19, col = red, cex = 1.4); abline(h = 0, col = gray, lty = 2); legend("topright", "Actual", pch = 19, col = red, bty = "n")
dev.off()

run_spec <- data.frame(hypothesis_id = contract$hypothesis_id, status = status, as_of_timestamp = contract$as_of_timestamp, query_start = contract$query_start, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, signal_assets = nrow(signal_registry), target_assets = nrow(target_registry), primary_score = "median across ten sectors of log(close/SMA20)", participation_companion = "fraction of ten sectors at or above SMA20", impulse = "breadth_score minus lag20 breadth_score", targets = "next-open H5/H20/H63 open-to-open returns", inference = "horizon-spaced non-overlap; 200 common within-year circular shifts", strategy_outcomes = "PROHIBITED", confirmation_2024_plus = "SEALED", refresh = refresh, stringsAsFactors = FALSE)
integrity <- data.frame(check = c("complete_registry_coverage", "ten_signal_assets", "unchanged_26_targets", "complete_common_calendar", "ten_inputs_each_date", "confirmation_excluded", "no_strategy_outcomes"), passed = c(all(coverage$coverage_status == "COMPLETE"), nrow(signal_registry) == 10L, setequal(target_registry$symbol, parent_targets$symbol), nrow(signal) == length(spy_dates), all(signal$sector_inputs == 10L), !any(ledger$session_date >= contract$confirmation_start), !any(c("strategy_return", "pnl", "sharpe", "drawdown", "hit_rate") %in% names(ledger))), stringsAsFactors = FALSE)
files <- list(run_spec = run_spec, integrity = integrity, registry = registry, coverage = coverage, query_health = query$health, daily_signal = signal, target_ledger = ledger, asset_summary = asset_summary, panel_summary = panel_summary, calendar_asset = calendar_asset, calendar_panel = calendar_panel, hidden_deterioration = hidden, circular_controls = placebo, circular_readout = placebo_readout, parent_comparison = parent_comparison, gates = gates)
for (name in names(files)) write_csv(files[[name]], file.path(output_dir, paste0("hyp_reg_03_", name, ".csv")))
report <- c("# HYP-REG-03.1 Cross-Sectional Sector-Breadth Trend Diagnostic", "", paste0("Status: `", status, "`"), "", "## Primary readout", "",
  paste(sprintf("- H=%d: median Spearman %.3f; positive targets %d/26; balanced accuracy %.3f; up/down recall %.3f/%.3f; Q5-Q1 %.3f%%.", panel_summary$horizon, panel_summary$median_spearman, panel_summary$positive_assets, panel_summary$median_balanced_accuracy, panel_summary$median_up_recall, panel_summary$median_down_recall, 100 * panel_summary$median_q5_q1_spread)), "",
  paste(sprintf("- Hidden deterioration H=%d: decaying breadth median %.3f%% versus stable/improving %.3f%%; gap %.3f pp; negative in %d/6 years.", hidden_all$horizon, 100 * hidden_all$decay_median, 100 * hidden_all$improve_median, 100 * hidden_all$decay_minus_improve, hidden_negative_years[paste0("H", hidden_all$horizon)])), "",
  paste0("- Gates passed: ", sum(gates$passed), "/", nrow(gates), "."), "",
  "This sector-diffusion proxy is a causal sensor diagnostic, not exact constituent breadth and not a trading strategy. It contains no strategy P&L, costs, allocation, leverage, advice, or live authority.")
writeLines(report, file.path(output_dir, "hyp_reg_03_report.md"), useBytes = TRUE)
message("HYP-REG-03.1 complete: ", output_dir)
