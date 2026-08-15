options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_02_1_trend_direction.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
pct <- function(x, digits = 1L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))

contract <- hreg21_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_02_1_trend_direction_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
source_registry <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_01_1_atr_percent_registry.csv"), stringsAsFactors = FALSE)
if (nrow(registry) != contract$minimum_assets || anyDuplicated(registry$symbol) || !setequal(registry$symbol, source_registry$symbol)) stop("Frozen registry integrity failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_REG_021_RUN_ID", "hyp_reg_02_1_trend_direction_20260814")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_REG_021_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = contract$query_start, end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = registry$symbol,
  universe_name = "hyp_reg_02_1_trend_direction_panel",
  universe_roles = "frozen_regime_26,direction_diagnostic_only", refresh = refresh, repo_root = repo_root
)
bars <- hreg21_validate_bars(query$bars, contract)

spy_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars[bars$symbol == reg$symbol, , drop = FALSE]
  dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start)
  cbind(reg, data.frame(total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates),
                        missing_spy_sessions = length(setdiff(spy_dates, dates)),
                        coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < 312L) "PREHISTORY_SHORT" else if (length(setdiff(spy_dates, dates))) "ANALYSIS_GAPS" else "COMPLETE",
                        stringsAsFactors = FALSE))
}))
if (any(coverage$coverage_status %in% c("NO_HISTORY", "PREHISTORY_SHORT"))) stop("One or more assets lack frozen diagnostic coverage.", call. = FALSE)

message("HYP-REG-02.1 building causal trend ledgers for 26 assets.")
ledgers <- vector("list", nrow(registry))
for (i in seq_len(nrow(registry))) {
  reg <- registry[i, , drop = FALSE]
  message(sprintf("[%02d/%02d] %s", i, nrow(registry), reg$symbol))
  x <- hreg21_build_asset_ledger(bars[bars$symbol == reg$symbol, , drop = FALSE], contract)
  x$instance_id <- reg$instance_id; x$sector <- reg$sector; x$asset_type <- reg$asset_type; x$panel_role <- reg$panel_role
  ledgers[[i]] <- x
}
ledger_all <- do.call(rbind, ledgers); rownames(ledger_all) <- NULL
ledger <- ledger_all[ledger_all$session_date >= contract$analysis_start & ledger_all$session_date <= contract$analysis_end, , drop = FALSE]

asset_summary <- hreg21_asset_summary(ledger_all, contract)
panel_summary <- do.call(rbind, lapply(split(asset_summary, interaction(asset_summary$horizon, asset_summary$model, drop = TRUE)), function(x) {
  data.frame(horizon = x$horizon[[1L]], model = x$model[[1L]], assets = nrow(x),
             median_observations = median_na(x$observations), median_spearman = median_na(x$spearman),
             positive_assets = sum(x$spearman > 0, na.rm = TRUE), positive_asset_fraction = mean(x$spearman > 0, na.rm = TRUE),
             median_accuracy = median_na(x$accuracy), median_up_recall = median_na(x$up_recall),
             median_down_recall = median_na(x$down_recall), median_balanced_accuracy = median_na(x$balanced_accuracy),
             median_predicted_up_fraction = median_na(x$predicted_up_fraction),
             median_q5_q1_spread = median_na(x$q5_q1_spread), positive_q5_q1_assets = sum(x$q5_q1_spread > 0, na.rm = TRUE),
             stringsAsFactors = FALSE)
}))
panel_summary <- panel_summary[order(panel_summary$model, panel_summary$horizon), , drop = FALSE]

calendar_asset <- hreg21_calendar_summary(ledger_all, contract)
calendar_panel <- do.call(rbind, lapply(split(calendar_asset, interaction(calendar_asset$year, calendar_asset$horizon, drop = TRUE)), function(x) {
  data.frame(year = x$year[[1L]], horizon = x$horizon[[1L]], assets = sum(is.finite(x$spearman)),
             median_spearman = median_na(x$spearman), positive_asset_fraction = mean(x$spearman > 0, na.rm = TRUE), stringsAsFactors = FALSE)
}))
calendar_panel <- calendar_panel[order(calendar_panel$horizon, calendar_panel$year), , drop = FALSE]

message("HYP-REG-02.1 running 200 deterministic within-asset/year circular controls.")
placebo <- hreg21_placebo_summary(ledger_all, contract)
primary <- panel_summary[panel_summary$model == "TREND_SMA20_60", , drop = FALSE]
placebo_readout <- do.call(rbind, lapply(c(20L, 63L), function(h) {
  actual <- primary$median_spearman[primary$horizon == h]
  controls <- placebo$panel_median_spearman[placebo$horizon == h]
  data.frame(horizon = h, actual_median_spearman = actual, control_median = median_na(controls),
             control_q90 = as.numeric(stats::quantile(controls, .90, na.rm = TRUE)), actual_percentile = mean(controls <= actual, na.rm = TRUE), stringsAsFactors = FALSE)
}))

positive_years <- vapply(c(20L, 63L), function(h) sum(calendar_panel$horizon == h & calendar_panel$median_spearman > 0), integer(1))
names(positive_years) <- paste0("H", c(20, 63))
gate_rows <- list(
  data.frame(gate = "G1_INTEGRITY", threshold = "26 assets; no confirmation data; exact accepted ATR ledger parity", observed = paste0(length(unique(ledger$symbol)), " assets"), passed = length(unique(ledger$symbol)) == 26L && !any(ledger$session_date >= contract$confirmation_start)),
  data.frame(gate = "G2_PANEL_SPEARMAN", threshold = ">0 all horizons and >=0.05 at H20/H63", observed = paste(sprintf("H%d %.3f", primary$horizon, primary$median_spearman), collapse = "; "), passed = all(primary$median_spearman > 0) && all(primary$median_spearman[primary$horizon %in% c(20, 63)] >= contract$minimum_long_spearman)),
  data.frame(gate = "G3_ASSET_BREADTH", threshold = ">=18/26 positive assets at H20/H63", observed = paste(sprintf("H%d %d", primary$horizon[primary$horizon %in% c(20, 63)], primary$positive_assets[primary$horizon %in% c(20, 63)]), collapse = "; "), passed = all(primary$positive_assets[primary$horizon %in% c(20, 63)] >= contract$breadth_assets)),
  data.frame(gate = "G4_DIRECTIONAL_BALANCE", threshold = "median balanced accuracy >=0.52; both recalls >0.50 at H20/H63", observed = paste(sprintf("H%d BA %.3f UP %.3f DOWN %.3f", primary$horizon[primary$horizon %in% c(20, 63)], primary$median_balanced_accuracy[primary$horizon %in% c(20, 63)], primary$median_up_recall[primary$horizon %in% c(20, 63)], primary$median_down_recall[primary$horizon %in% c(20, 63)]), collapse = "; "), passed = all(primary$median_balanced_accuracy[primary$horizon %in% c(20, 63)] >= contract$minimum_balanced_accuracy) && all(primary$median_up_recall[primary$horizon %in% c(20, 63)] > .50) && all(primary$median_down_recall[primary$horizon %in% c(20, 63)] > .50)),
  data.frame(gate = "G5_QUINTILE_ORDERING", threshold = "positive panel spread all horizons and >=18/26 positive assets H20/H63", observed = paste(sprintf("H%d %.4f (%d assets)", primary$horizon, primary$median_q5_q1_spread, primary$positive_q5_q1_assets), collapse = "; "), passed = all(primary$median_q5_q1_spread > 0) && all(primary$positive_q5_q1_assets[primary$horizon %in% c(20, 63)] >= contract$breadth_assets)),
  data.frame(gate = "G6_CALENDAR_STABILITY", threshold = ">=4/6 positive panel years at H20/H63", observed = paste(names(positive_years), positive_years, collapse = "; "), passed = all(positive_years >= contract$minimum_positive_years)),
  data.frame(gate = "G7_CIRCULAR_CONTROL", threshold = ">=90th control percentile at H20/H63", observed = paste(sprintf("H%d %.1f%%", placebo_readout$horizon, 100 * placebo_readout$actual_percentile), collapse = "; "), passed = all(placebo_readout$actual_percentile >= contract$minimum_placebo_percentile))
)
gates <- do.call(rbind, gate_rows)

# Exact reuse of the accepted HYP-REG-01.1 volatility states is mandatory for the conditional audit.
accepted_state_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_01_1_atr_percent_20260814", "hyp_reg_01_1_daily_state_ledger.csv")
if (!file.exists(accepted_state_path)) stop("Accepted HYP-REG-01.1 state ledger is missing.", call. = FALSE)
accepted <- utils::read.csv(accepted_state_path, stringsAsFactors = FALSE)
accepted$session_date <- as.Date(accepted$session_date)
accepted <- accepted[accepted$session_date >= contract$analysis_start & accepted$session_date <= contract$analysis_end, c("symbol", "session_date", "open", "close", "atr_percent", "atr_percentile", "regime_state")]
joined <- merge(ledger, accepted, by = c("symbol", "session_date"), all.x = TRUE, suffixes = c("", "_accepted"), sort = FALSE)
parity <- nrow(joined) == nrow(ledger) && !anyNA(joined$regime_state) && max(abs(joined$open - joined$open_accepted), na.rm = TRUE) < 1e-10 && max(abs(joined$close - joined$close_accepted), na.rm = TRUE) < 1e-10
gates$passed[gates$gate == "G1_INTEGRITY"] <- gates$passed[gates$gate == "G1_INTEGRITY"] && parity
gates$observed[gates$gate == "G1_INTEGRITY"] <- paste0(gates$observed[gates$gate == "G1_INTEGRITY"], "; ATR parity ", parity)

standalone_passed <- all(gates$passed)
joint_status <- if (standalone_passed) "RUN" else "NOT_RUN"
joint_map <- data.frame(); joint_within <- data.frame(); joint_correlation <- data.frame(); joint_gates <- data.frame()
if (standalone_passed) {
  message("HYP-REG-02.1 passed all gates; running conditional HYP-REG-02.2 complementarity audit.")
  joined$atr_percent <- joined$atr_percent_accepted; joined$atr_percentile <- joined$atr_percentile_accepted
  joint_correlation <- do.call(rbind, lapply(split(joined, joined$symbol), function(x) data.frame(symbol = x$symbol[[1L]], observations = sum(is.finite(x$trend_score) & is.finite(x$atr_percentile)), spearman = suppressWarnings(stats::cor(x$trend_score, x$atr_percentile, method = "spearman", use = "complete.obs")))))
  joint_map <- hreg21_joint_state_summary(joined, contract)
  joint_within <- hreg21_joint_within_state(joined, contract)
  median_abs_corr <- median_na(abs(joint_correlation$spearman))
  within_ok <- all(joint_within$median_spearman[joint_within$horizon == 20] > 0) && sum(joint_within$median_spearman[joint_within$horizon == 63] > 0) >= 2L
  direction_gaps <- do.call(rbind, lapply(split(joint_map, interaction(joint_map$horizon, joint_map$regime_state, drop = TRUE)), function(x) data.frame(horizon = x$horizon[[1L]], state = x$regime_state[[1L]], gap = x$median_return[x$trend_sign == "UP"] - x$median_return[x$trend_sign == "DOWN"])))
  range_gaps <- do.call(rbind, lapply(split(joint_map, interaction(joint_map$horizon, joint_map$trend_sign, drop = TRUE)), function(x) data.frame(horizon = x$horizon[[1L]], sign = x$trend_sign[[1L]], gap = x$median_abs_return[x$regime_state == "HIGH"] - x$median_abs_return[x$regime_state == "LOW"])))
  joint_gates <- data.frame(
    gate = c("J1_SENSOR_CORRELATION", "J2_WITHIN_ATR_DIRECTION", "J3_DIRECTION_GAP_EVERY_STATE", "J4_RANGE_GAP_BOTH_SIGNS"),
    threshold = c("median absolute trend/ATR correlation <0.35", "positive within every H20 state and >=2/3 H63 states", "UP-DOWN median return >0 for every state at H20/H63", "HIGH-LOW median absolute return >0 for both signs at H20/H63"),
    observed = c(sprintf("%.3f", median_abs_corr), paste(sprintf("H%d/%s %.3f", joint_within$horizon, joint_within$regime_state, joint_within$median_spearman), collapse = "; "), paste(sprintf("H%d/%s %.4f", direction_gaps$horizon, direction_gaps$state, direction_gaps$gap), collapse = "; "), paste(sprintf("H%d/%s %.4f", range_gaps$horizon, range_gaps$sign, range_gaps$gap), collapse = "; ")),
    passed = c(median_abs_corr < contract$maximum_joint_abs_correlation, within_ok, all(direction_gaps$gap > 0), all(range_gaps$gap > 0)), stringsAsFactors = FALSE
  )
  joint_status <- if (all(joint_gates$passed)) "COMPLEMENTARY_AXES" else "STOP_JOINT_DIAGNOSTIC_NO_COMPLEMENTARITY"
}

ink <- "#202630"; blue <- "#3D8DFF"; orange <- "#F2A65A"; gray <- "#B8BCC4"; pale <- "#EDEDED"; red <- "#D95F59"
representatives <- c("SPY", "AMD", "TSLA")
png(file.path(visual_dir, "representative_trend_tapes.png"), 1900, 1500, res = 150)
par(mfrow = c(3, 2), mar = c(3.5, 5, 3.2, 1.5), oma = c(1, 1, 2, 1))
for (symbol in representatives) {
  x <- ledger[ledger$symbol == symbol, ]
  plot(x$session_date, x$close, type = "l", col = ink, lwd = 1, xlab = "", ylab = "Adjusted close", main = paste0(symbol, " | close and causal moving averages"))
  lines(x$session_date, x$sma20, col = blue, lwd = 1.2); lines(x$session_date, x$sma60, col = orange, lwd = 1.2); legend("topleft", c("Close", "SMA20", "SMA60"), col = c(ink, blue, orange), lty = 1, bty = "n", cex = .75)
  plot(x$session_date, 100 * x$trend_score, type = "h", col = ifelse(x$trend_score >= 0, blue, red), xlab = "Session", ylab = "100 x log(SMA20/SMA60)", main = paste0(symbol, " | signed trend score")); abline(h = 0, col = ink)
}
mtext("HYP-REG-02.1 | score is known after each close; targets begin next open", outer = TRUE, font = 2)
dev.off()

primary_assets <- asset_summary[asset_summary$model == "TREND_SMA20_60", ]
heat <- matrix(NA_real_, nrow = nrow(registry), ncol = length(contract$horizons), dimnames = list(registry$symbol, paste0("H", contract$horizons)))
for (i in seq_len(nrow(primary_assets))) heat[primary_assets$symbol[[i]], paste0("H", primary_assets$horizon[[i]])] <- primary_assets$spearman[[i]]
png(file.path(visual_dir, "asset_spearman_heatmap.png"), 1450, 1500, res = 150)
par(mar = c(5, 8, 4, 7)); lim <- max(abs(heat), na.rm = TRUE)
image(seq_len(ncol(heat)), seq_len(nrow(heat)), t(heat[nrow(heat):1, , drop = FALSE]), col = grDevices::colorRampPalette(c(red, "white", blue))(100), zlim = c(-lim, lim), axes = FALSE, xlab = "Forward horizon", ylab = "", main = "Per-asset direction evidence | non-overlapping samples")
axis(1, at = seq_len(ncol(heat)), labels = colnames(heat)); axis(2, at = seq_len(nrow(heat)), labels = rev(rownames(heat)), las = 1, cex.axis = .75)
for (i in seq_len(nrow(heat))) for (j in seq_len(ncol(heat))) text(j, nrow(heat) - i + 1, sprintf("%.2f", heat[i, j]), cex = .6)
dev.off()

png(file.path(visual_dir, "panel_direction_metrics.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
mat <- rbind(Spearman = primary$median_spearman, `Q5-Q1 spread` = primary$median_q5_q1_spread)
barplot(mat, beside = TRUE, names.arg = paste0("H", primary$horizon), col = c(blue, orange), border = NA, ylab = "Panel median", main = "Continuous score ordering"); abline(h = 0, col = ink); legend("topleft", rownames(mat), fill = c(blue, orange), bty = "n")
recalls <- rbind(`Balanced accuracy` = primary$median_balanced_accuracy, `Up recall` = primary$median_up_recall, `Down recall` = primary$median_down_recall)
barplot(recalls, beside = TRUE, names.arg = paste0("H", primary$horizon), col = c(ink, blue, red), border = NA, ylim = c(0, 1), ylab = "Panel median", main = "Signed classification is audited both ways"); abline(h = .5, col = gray, lty = 2); legend("topleft", rownames(recalls), fill = c(ink, blue, red), bty = "n", cex = .8)
dev.off()

png(file.path(visual_dir, "calendar_and_placebo.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
calendar_range <- range(c(calendar_panel$median_spearman[is.finite(calendar_panel$median_spearman)], 0))
if (diff(calendar_range) == 0) calendar_range <- c(-0.01, 0.01)
for (h in c(20L, 63L)) { x <- calendar_panel[calendar_panel$horizon == h, ]; linespec <- if (h == 20L) blue else orange; if (h == 20L) plot(x$year, x$median_spearman, type = "b", pch = 19, col = linespec, lwd = 2, ylim = calendar_range, xlab = "Calendar year", ylab = "Median per-asset Spearman", main = "Calendar stability") else lines(x$year, x$median_spearman, type = "b", pch = 19, col = linespec, lwd = 2) }; abline(h = 0, col = gray); legend("bottomleft", c("H20", "H63"), col = c(blue, orange), lty = 1, pch = 19, bty = "n")
placebo_range <- range(c(placebo$panel_median_spearman, placebo_readout$actual_median_spearman), na.rm = TRUE)
boxplot(panel_median_spearman ~ factor(horizon), data = placebo, col = pale, border = gray, ylim = placebo_range, xlab = "Forward horizon", ylab = "Panel median Spearman", main = "Circular timing controls vs actual"); points(match(placebo_readout$horizon, sort(unique(placebo$horizon))), placebo_readout$actual_median_spearman, pch = 19, col = red, cex = 1.4); abline(h = 0, col = gray, lty = 2); legend("topright", "Actual", pch = 19, col = red, bty = "n")
dev.off()

if (standalone_passed) {
  png(file.path(visual_dir, "joint_trend_atr_map.png"), 1800, 1050, res = 150)
  par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
  boxplot(joint_correlation$spearman, col = pale, border = gray, ylab = "Per-asset Spearman", main = "Trend score vs ATR% percentile"); abline(h = c(-.35, .35), col = red, lty = 2)
  h20 <- joint_map[joint_map$horizon == 20, ]; z <- matrix(h20$median_return, nrow = 2, byrow = FALSE, dimnames = list(c("DOWN", "UP"), c("LOW", "MEDIUM", "HIGH"))); lim2 <- max(abs(z), na.rm = TRUE); image(1:3, 1:2, t(z), col = grDevices::colorRampPalette(c(red, "white", blue))(100), zlim = c(-lim2, lim2), axes = FALSE, xlab = "ATR% state", ylab = "Trend sign", main = "H20 median forward return | 2 x 3 map"); axis(1, 1:3, colnames(z)); axis(2, 1:2, rownames(z), las = 1); for (i in 1:2) for (j in 1:3) text(j, i, sprintf("%.2f%%", 100 * z[i, j]), cex = .9)
  dev.off()
}

status <- if (!standalone_passed) "STOP_TREND_DIRECTION_GATES_FAILED_JOINT_NOT_RUN" else joint_status
integrity <- data.frame(check = c("registered_26", "source_registry_match", "confirmation_excluded", "accepted_atr_ledger_parity", "no_strategy_outcomes"), passed = c(nrow(registry) == 26L, setequal(registry$symbol, source_registry$symbol), !any(ledger$session_date >= contract$confirmation_start), parity, !any(c("strategy_return", "pnl", "sharpe", "drawdown", "hit_rate") %in% names(ledger))), stringsAsFactors = FALSE)
run_spec <- data.frame(hypothesis_id = contract$hypothesis_id, joint_hypothesis_id = contract$joint_hypothesis_id, status = status, as_of_timestamp = contract$as_of_timestamp, query_start = contract$query_start, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, assets = nrow(registry), primary_score = "log(SMA20/SMA60)", comparators = "log(close/SMA60); log(close/close[-63])", targets = "next-open to H-session exit open at H=5,20,63", inference = "deterministic horizon-spaced non-overlap; 200 within-asset/year circular controls", strategy_outcomes = "PROHIBITED", confirmation_2024_plus = "SEALED", refresh = refresh, stringsAsFactors = FALSE)

files <- list(run_spec = run_spec, integrity = integrity, registry = registry, coverage = coverage, query_health = query$health, daily_trend_ledger = ledger, asset_summary = asset_summary, panel_summary = panel_summary, calendar_asset = calendar_asset, calendar_panel = calendar_panel, circular_controls = placebo, circular_readout = placebo_readout, gates = gates)
if (standalone_passed) files <- c(files, list(joint_state_map = joint_map, joint_within_state = joint_within, joint_sensor_correlation = joint_correlation, joint_gates = joint_gates))
for (name in names(files)) write_csv(files[[name]], file.path(output_dir, paste0("hyp_reg_02_", name, ".csv")))

report <- c(
  "# HYP-REG-02 Trend-Direction Diagnostic", "", paste0("Status: `", status, "`"), "",
  "## Standalone sensor readout", "",
  paste(sprintf("- H=%d: median Spearman %.3f; positive assets %d/26; balanced accuracy %.3f; up/down recall %.3f/%.3f; Q5-Q1 %.3f%%.", primary$horizon, primary$median_spearman, primary$positive_assets, primary$median_balanced_accuracy, primary$median_up_recall, primary$median_down_recall, 100 * primary$median_q5_q1_spread)), "",
  paste0("- Standalone gates passed: ", sum(gates$passed), "/", nrow(gates), "."),
  paste0("- Conditional ATR% complementarity audit: ", if (standalone_passed) joint_status else "not run by contract"), "",
  "The trend score is a causal diagnostic, not a trading strategy. Forward returns appear only as direction labels used to test the sensor. This packet contains no entry, exit, cost, capital, leverage, allocation, Sharpe, drawdown, portfolio, advice, or live authority."
)
writeLines(report, file.path(output_dir, "hyp_reg_02_report.md"), useBytes = TRUE)
message("HYP-REG-02 complete: ", output_dir)
