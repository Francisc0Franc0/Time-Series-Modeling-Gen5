options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_03_2_breadth_transition.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)

contract <- hreg32_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_03_2_breadth_transition_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
sector_symbols <- registry$symbol[registry$role == "sector_signal"]
if (nrow(registry) != contract$registry_assets || length(sector_symbols) != contract$sector_assets || anyDuplicated(registry$symbol) || !setequal(registry$symbol, c(sector_symbols, "RSP", "SPY"))) stop("Frozen registry integrity failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_REG_032_RUN_ID", "hyp_reg_03_2_breadth_transition_20260814")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_REG_032_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = contract$query_start, end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = registry$symbol,
  universe_name = "hyp_reg_03_2_breadth_transition_panel",
  universe_roles = "ten_sector_breadth,rsp_spy_leadership,spy_h20_target,diagnostic_only",
  refresh = refresh, repo_root = repo_root
)
bars <- hreg32_validate_bars(query$bars, contract)
spy_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars[bars$symbol == reg$symbol, , drop = FALSE]
  dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start); missing <- length(setdiff(spy_dates, dates))
  cbind(reg, data.frame(total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates), missing_spy_sessions = missing,
    coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < 312L) "PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else "COMPLETE", stringsAsFactors = FALSE))
}))
if (any(coverage$coverage_status != "COMPLETE")) {
  print(coverage[coverage$coverage_status != "COMPLETE", c("symbol", "coverage_status", "prehistory_sessions", "analysis_sessions", "missing_spy_sessions")], row.names = FALSE)
  stop("One or more assets lack complete frozen diagnostic coverage.", call. = FALSE)
}

message("HYP-REG-03.2 building the frozen breadth-transition ledger.")
ledger <- hreg32_build_ledger(bars, sector_symbols, contract)
if (nrow(ledger) != length(spy_dates) || !identical(ledger$session_date, spy_dates) || any(ledger$sector_inputs != contract$sector_assets)) stop("Common signal calendar is incomplete.", call. = FALSE)
if (any(ledger$session_date >= contract$confirmation_start)) stop("Confirmation rows entered the ledger.", call. = FALSE)

state_summary <- hreg32_state_summary(ledger)
primary_contrast <- hreg32_state_contrast(ledger)
continuous_summary <- hreg32_continuous_summary(ledger)
offset_summary <- hreg32_offset_summary(ledger, contract)
period_summary <- hreg32_period_summary(ledger)
calendar_summary <- hreg32_calendar_summary(ledger)
semantic_summary <- hreg32_semantic_summary(ledger)

message("HYP-REG-03.2 running 200 within-year circular state-timing controls.")
circular_controls <- hreg32_circular_controls(ledger, contract)
circular_readout <- data.frame(
  actual_return_gap = primary_contrast$return_gap,
  control_return_gap_median = median_na(circular_controls$return_gap),
  control_return_gap_q10 = as.numeric(stats::quantile(circular_controls$return_gap, .10, na.rm = TRUE)),
  actual_return_gap_percentile = mean(circular_controls$return_gap <= primary_contrast$return_gap, na.rm = TRUE),
  actual_down_rate_gap = primary_contrast$down_rate_gap,
  control_down_rate_gap_median = median_na(circular_controls$down_rate_gap),
  control_down_rate_gap_q90 = as.numeric(stats::quantile(circular_controls$down_rate_gap, .90, na.rm = TRUE)),
  actual_down_rate_gap_percentile = mean(circular_controls$down_rate_gap <= primary_contrast$down_rate_gap, na.rm = TRUE), stringsAsFactors = FALSE)

eligible <- ledger[ledger$positive_spy_trend & is.finite(ledger$forward_return_h20) & is.finite(ledger$narrowing_risk_score), ]
eligible$risk_decile <- pmin(10L, pmax(1L, ceiling(10 * eligible$narrowing_risk_score)))
risk_deciles <- do.call(rbind, lapply(split(eligible, eligible$risk_decile), function(x) data.frame(
  risk_decile = x$risk_decile[[1L]], observations = nrow(x), median_return = median_na(x$forward_return_h20), down_rate = mean(x$down_h20), stringsAsFactors = FALSE)))
eligible$dispersion_decile <- pmin(10L, pmax(1L, ceiling(10 * eligible$dispersion_percentile)))
dispersion_deciles <- do.call(rbind, lapply(split(eligible, eligible$dispersion_decile), function(x) data.frame(
  dispersion_decile = x$dispersion_decile[[1L]], observations = nrow(x), median_return = median_na(x$forward_return_h20), down_rate = mean(x$down_h20), stringsAsFactors = FALSE)))

feature <- function(name, column) continuous_summary[continuous_summary$feature == name, column][[1L]]
valid_offsets <- sum(offset_summary$valid)
stable_offsets <- sum(offset_summary$valid & offset_summary$return_gap < 0 & offset_summary$down_rate_gap > 0, na.rm = TRUE)
stable_years <- sum(calendar_summary$return_gap < 0 & calendar_summary$down_rate_gap > 0, na.rm = TRUE)
period_pass <- all(period_summary$return_gap < 0 & period_summary$down_rate_gap > 0)
semantic_pass <- all(semantic_summary$future_breadth_gap < 0 & semantic_summary$future_leadership_gap < 0)

gates <- do.call(rbind, list(
  data.frame(gate = "G1_INTEGRITY", threshold = "12/12 complete; 10 sector inputs; next-open H20; 2024+ excluded", observed = paste0(sum(coverage$coverage_status == "COMPLETE"), "/", nrow(coverage), " complete; ", nrow(ledger), " sessions"), passed = all(coverage$coverage_status == "COMPLETE") && all(ledger$sector_inputs == 10L) && !any(ledger$session_date >= contract$confirmation_start)),
  data.frame(gate = "G2_PRIMARY_STATE_EFFECT", threshold = "both n>=100; return gap<=-0.75pp; DOWN gap>=+10pp", observed = sprintf("n %d/%d; return %.2fpp; DOWN %.1fpp", primary_contrast$narrowing_n, primary_contrast$healthy_n, 100 * primary_contrast$return_gap, 100 * primary_contrast$down_rate_gap), passed = primary_contrast$narrowing_n >= contract$minimum_state_rows && primary_contrast$healthy_n >= contract$minimum_state_rows && primary_contrast$return_gap <= contract$maximum_return_gap && primary_contrast$down_rate_gap >= contract$minimum_down_gap),
  data.frame(gate = "G3_CONTINUOUS_ORDERING", threshold = "rho(D)>0; rho(G)>0; rho(N)<0; DOWN AUC(N)>=0.55", observed = sprintf("D %.3f; G %.3f; N %.3f; AUC %.3f", feature("breadth_change20", "spearman_return"), feature("leadership_change20", "spearman_return"), feature("narrowing_risk_score", "spearman_return"), feature("narrowing_risk_score", "down_auc")), passed = feature("breadth_change20", "spearman_return") > 0 && feature("leadership_change20", "spearman_return") > 0 && feature("narrowing_risk_score", "spearman_return") < 0 && feature("narrowing_risk_score", "down_auc") >= contract$minimum_auc),
  data.frame(gate = "G4_OFFSET_STABILITY", threshold = ">=15 valid offsets; >=14 jointly directional", observed = paste0(valid_offsets, " valid; ", stable_offsets, " jointly directional"), passed = valid_offsets >= contract$minimum_valid_offsets && stable_offsets >= contract$minimum_stable_offsets),
  data.frame(gate = "G5_TEMPORAL_TRANSPORT", threshold = "negative return and positive DOWN gap in both halves", observed = paste(sprintf("%s %.2fpp/%.1fpp", period_summary$period, 100 * period_summary$return_gap, 100 * period_summary$down_rate_gap), collapse = "; "), passed = period_pass),
  data.frame(gate = "G6_CALENDAR_STABILITY", threshold = ">=4/6 years jointly directional", observed = paste0(stable_years, "/6 years"), passed = stable_years >= contract$minimum_stable_years),
  data.frame(gate = "G7_CIRCULAR_CONTROL", threshold = "return gap <=10th and DOWN gap >=90th percentile", observed = sprintf("return %.1fth; DOWN %.1fth", 100 * circular_readout$actual_return_gap_percentile, 100 * circular_readout$actual_down_rate_gap_percentile), passed = circular_readout$actual_return_gap_percentile <= .10 && circular_readout$actual_down_rate_gap_percentile >= .90),
  data.frame(gate = "G8_STATE_SEMANTICS", threshold = "future breadth and leadership gaps <0 overall and both halves", observed = paste(sprintf("%s B %.3f%% G %.3f%%", semantic_summary$period, 100 * semantic_summary$future_breadth_gap, 100 * semantic_summary$future_leadership_gap), collapse = "; "), passed = semantic_pass)
))
status <- if (all(gates$passed)) "DIAGNOSTIC_COMPLETE_STOP_BEFORE_ATR_OR_STRATEGY" else "STOP_BREADTH_TRANSITION_GATES_FAILED_NO_JOINT_FILTER"

# Purposeful operator visuals.
ink <- "#202630"; blue <- "#3D8DFF"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#B8BCC4"; pale <- "#EDEDED"
png(file.path(visual_dir, "breadth_transition_tape.png"), 1900, 1900, res = 150)
par(mfrow = c(5, 1), mar = c(3.2, 5, 3, 2), oma = c(1, 1, 2, 1))
plot(ledger$session_date, ledger$spy_close, type = "l", col = ink, lwd = 1.1, xlab = "", ylab = "SPY close", main = "Headline SPY trend")
lines(ledger$session_date, ledger$spy_sma20, col = blue); lines(ledger$session_date, ledger$spy_sma60, col = orange); legend("topleft", c("SPY", "SMA20", "SMA60"), col = c(ink, blue, orange), lty = 1, bty = "n")
plot(ledger$session_date, 100 * ledger$breadth_level, type = "l", col = blue, xlab = "", ylab = "Median depth (%)", main = "Sector breadth level"); abline(h = 0, col = gray)
plot(ledger$session_date, 100 * ledger$breadth_change20, type = "l", col = red, xlab = "", ylab = "20d change (pp)", main = "Breadth transition D(t)"); abline(h = 0, col = gray)
plot(ledger$session_date, 100 * ledger$leadership_change20, type = "l", col = orange, xlab = "", ylab = "20d relative (%)", main = "Equal-weight leadership G(t) | RSP minus SPY"); abline(h = 0, col = gray)
state_col <- c(HEALTHY = green, NARROWING = red, MIXED_BREADTH_WEAK = orange, MIXED_LEADERSHIP_WEAK = blue, PRICE_TREND_NOT_POSITIVE = gray)
plot(ledger$session_date, ledger$narrowing_risk_score, type = "l", col = ink, xlab = "Session", ylab = "Prior-relative risk", main = "Unfitted narrowing-risk score"); points(ledger$session_date[ledger$state == "NARROWING"], ledger$narrowing_risk_score[ledger$state == "NARROWING"], pch = 16, cex = .25, col = red)
mtext("HYP-REG-03.2 | after-close signals; H20 target begins next open", outer = TRUE, font = 2)
dev.off()

png(file.path(visual_dir, "state_outcomes.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 1))
ss <- state_summary[state_summary$state != "PRICE_TREND_NOT_POSITIVE", ]; cols <- unname(state_col[ss$state])
state_labels <- c(HEALTHY = "HEALTHY", MIXED_BREADTH_WEAK = "BREADTH\nWEAK", MIXED_LEADERSHIP_WEAK = "LEADERSHIP\nWEAK", NARROWING = "NARROWING")
barplot(100 * ss$median_return, names.arg = unname(state_labels[ss$state]), col = cols, border = NA, las = 1, cex.names = .78, ylab = "Median SPY H20 return (%)", main = "Outcome by frozen positive-trend state"); abline(h = 0, col = gray)
barplot(100 * ss$down_rate, names.arg = unname(state_labels[ss$state]), col = cols, border = NA, las = 1, cex.names = .78, ylim = c(0, 100), ylab = "H20 DOWN rate (%)", main = "Downside probability by state")
dev.off()

png(file.path(visual_dir, "continuous_and_dispersion.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
plot(risk_deciles$risk_decile, 100 * risk_deciles$median_return, type = "b", pch = 19, col = red, lwd = 2, xaxt = "n", xlab = "Narrowing-risk decile", ylab = "Median SPY H20 return (%)", main = "Continuous risk ordering"); axis(1, at = seq(1, 9, 2)); abline(h = 0, col = gray)
plot(dispersion_deciles$dispersion_decile, 100 * dispersion_deciles$median_return, type = "b", pch = 19, col = blue, lwd = 2, xaxt = "n", xlab = "Sector-dispersion decile", ylab = "Median SPY H20 return (%)", main = "Dispersion remains diagnostic-only"); axis(1, at = seq(1, 9, 2)); abline(h = 0, col = gray)
dev.off()

png(file.path(visual_dir, "offset_stability.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
barplot(100 * offset_summary$return_gap, names.arg = offset_summary$offset, col = ifelse(offset_summary$return_gap < 0, green, red), border = NA, xlab = "H20 starting offset", ylab = "NARROWING minus HEALTHY return (pp)", main = "Non-overlapping offset stability"); abline(h = 0, col = ink)
barplot(100 * offset_summary$down_rate_gap, names.arg = offset_summary$offset, col = ifelse(offset_summary$down_rate_gap > 0, green, red), border = NA, xlab = "H20 starting offset", ylab = "DOWN-rate gap (pp)", main = "Downside-warning stability"); abline(h = 0, col = ink)
dev.off()

png(file.path(visual_dir, "temporal_and_semantic_stability.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 1))
barplot(rbind(100 * period_summary$return_gap, 100 * period_summary$down_rate_gap), beside = TRUE, names.arg = period_summary$period, col = c(blue, red), border = NA, cex.names = .8, ylab = "Gap", main = "Temporal-half transport"); abline(h = 0, col = ink); legend("topright", c("Return gap (pp)", "DOWN-rate gap (pp)"), fill = c(blue, red), bty = "n")
barplot(rbind(100 * semantic_summary$future_breadth_gap, 100 * semantic_summary$future_leadership_gap), beside = TRUE, names.arg = semantic_summary$period, col = c(blue, orange), border = NA, cex.names = .72, ylab = "NARROWING minus HEALTHY (pp)", main = "Does the state name its future semantics?"); abline(h = 0, col = ink); legend("topright", c("Future breadth", "Future RSP/SPY"), fill = c(blue, orange), bty = "n")
dev.off()

png(file.path(visual_dir, "calendar_and_circular_controls.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
plot(calendar_summary$year, 100 * calendar_summary$return_gap, type = "b", pch = 19, col = blue, ylim = range(100 * c(calendar_summary$return_gap, calendar_summary$down_rate_gap), na.rm = TRUE), xlab = "Calendar year", ylab = "Gap (pp)", main = "Calendar stability"); lines(calendar_summary$year, 100 * calendar_summary$down_rate_gap, type = "b", pch = 19, col = red); abline(h = 0, col = gray); legend("topleft", c("Return gap", "DOWN-rate gap"), col = c(blue, red), lty = 1, pch = 19, bty = "n")
boxplot(100 * circular_controls$return_gap, 100 * circular_controls$down_rate_gap, names = c("Return gap", "DOWN-rate gap"), col = pale, border = gray, ylab = "Control gap (pp)", main = "Circular state-timing controls"); points(c(1, 2), 100 * c(primary_contrast$return_gap, primary_contrast$down_rate_gap), pch = 19, col = red, cex = 1.4); abline(h = 0, col = gray); legend("topright", "Actual", pch = 19, col = red, bty = "n")
dev.off()

run_spec <- data.frame(hypothesis_id = contract$hypothesis_id, status = status, as_of_timestamp = contract$as_of_timestamp, query_start = contract$query_start, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, target = "SPY next-open H20 open-to-open direction conditional on positive close-time trend", primary_states = "NARROWING versus HEALTHY", signals = "ten-sector breadth change plus RSP/SPY leadership change", dispersion = "continuous diagnostic only", strategy_outcomes = "PROHIBITED", confirmation_2024_plus = "SEALED", refresh = refresh, stringsAsFactors = FALSE)
integrity <- data.frame(check = c("complete_registry_coverage", "ten_sector_inputs", "common_spy_calendar", "next_open_target", "confirmation_excluded", "no_strategy_outcomes"), passed = c(all(coverage$coverage_status == "COMPLETE"), all(ledger$sector_inputs == 10L), nrow(ledger) == length(spy_dates), identical(ledger$forward_return_h20, hreg32_forward_open_return(ledger$spy_open, 20L)), !any(ledger$session_date >= contract$confirmation_start), !any(c("strategy_return", "pnl", "sharpe", "drawdown", "hit_rate") %in% names(ledger))), stringsAsFactors = FALSE)
files <- list(run_spec = run_spec, integrity = integrity, registry = registry, coverage = coverage, query_health = query$health, ledger = ledger, state_summary = state_summary, primary_contrast = primary_contrast, continuous_summary = continuous_summary, risk_deciles = risk_deciles, dispersion_deciles = dispersion_deciles, offset_summary = offset_summary, period_summary = period_summary, calendar_summary = calendar_summary, semantic_summary = semantic_summary, circular_controls = circular_controls, circular_readout = circular_readout, gates = gates)
for (name in names(files)) write_csv(files[[name]], file.path(output_dir, paste0("hyp_reg_03_2_", name, ".csv")))
report <- c("# HYP-REG-03.2 Breadth-Transition and Leadership-Divergence Diagnostic", "", paste0("Status: `", status, "`"), "", "## Primary readout", "",
  sprintf("- NARROWING n=%d versus HEALTHY n=%d; median H20 return gap %.3f pp; DOWN-rate gap %.3f pp.", primary_contrast$narrowing_n, primary_contrast$healthy_n, 100 * primary_contrast$return_gap, 100 * primary_contrast$down_rate_gap),
  sprintf("- Continuous score: Spearman %.3f; DOWN AUC %.3f.", feature("narrowing_risk_score", "spearman_return"), feature("narrowing_risk_score", "down_auc")),
  sprintf("- Offset stability: %d valid; %d/20 jointly directional. Calendar stability: %d/6 years.", valid_offsets, stable_offsets, stable_years),
  sprintf("- Circular controls: return-gap percentile %.1f; DOWN-gap percentile %.1f.", 100 * circular_readout$actual_return_gap_percentile, 100 * circular_readout$actual_down_rate_gap_percentile),
  paste0("- Gates passed: ", sum(gates$passed), "/", nrow(gates), "."), "",
  "This is a causal market-sensor diagnostic, not a trading strategy. It contains no strategy P&L, costs, allocation, leverage, advice, or live authority.")
writeLines(report, file.path(output_dir, "hyp_reg_03_2_report.md"), useBytes = TRUE)
message("HYP-REG-03.2 complete: ", output_dir)
