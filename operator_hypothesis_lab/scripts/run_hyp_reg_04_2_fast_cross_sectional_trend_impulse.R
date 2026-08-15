options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_04_2_fast_cross_sectional_trend_impulse.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
percentile <- function(distribution, actual) mean(distribution <= actual, na.rm = TRUE)

contract <- hreg42_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_04_2_fast_cross_sectional_trend_impulse_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
signals <- registry[registry$role == "field_signal", , drop = FALSE]
if (nrow(registry) != contract$registry_assets || nrow(signals) != contract$signal_assets || anyDuplicated(registry$symbol) || !identical(registry$symbol[registry$role == "context_target"], "SPY") || length(unique(signals$group)) != contract$signal_groups) stop("Frozen registry integrity failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_REG_042_RUN_ID", "hyp_reg_04_2_fast_cross_sectional_trend_impulse_20260815")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_REG_042_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = registry$symbol,
  universe_name = "hyp_reg_04_2_fast_cross_sectional_trend_impulse_panel",
  universe_roles = "four_group_fast_market_impulse,spy_secondary_target,diagnostic_only",
  refresh = refresh,
  repo_root = repo_root
)

bars <- hreg42_validate_bars(query$bars, contract)
spy_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]
  x <- bars[bars$symbol == reg$symbol, , drop = FALSE]
  dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start)
  missing <- length(setdiff(spy_dates, dates))
  cbind(reg, data.frame(
    total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates), missing_spy_sessions = missing,
    coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < 130L) "PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else "COMPLETE",
    stringsAsFactors = FALSE
  ))
}))
if (any(coverage$coverage_status != "COMPLETE")) {
  print(coverage[coverage$coverage_status != "COMPLETE", c("symbol", "coverage_status", "prehistory_sessions", "analysis_sessions", "missing_spy_sessions")], row.names = FALSE)
  stop("One or more assets lack complete frozen diagnostic coverage.", call. = FALSE)
}

message("HYP-REG-04.2 building the equal-group fast trend-impulse field.")
ledger <- hreg42_build_ledger(bars, signals$symbol, signals$group, contract)
if (nrow(ledger) != length(spy_dates) || !identical(ledger$session_date, spy_dates) || any(ledger$field_inputs != contract$signal_assets)) stop("Common field calendar is incomplete.", call. = FALSE)
if (any(ledger$session_date >= contract$confirmation_start)) stop("Confirmation rows entered the ledger.", call. = FALSE)

state_summary_h5 <- hreg42_state_summary(ledger, 5L)
state_summary_h10 <- hreg42_state_summary(ledger, 10L)
state_summary_h20 <- hreg42_state_summary(ledger, 20L)
context_summary <- hreg42_context_summary(ledger)
direction_h5 <- hreg42_contrast(ledger, "BROAD_UP_IMPULSE", "BROAD_DOWN_IMPULSE", 5L)
health_h5 <- hreg42_contrast(ledger, "BROAD_UP_IMPULSE", "OTHER_UP", 5L)
direction_h10 <- hreg42_contrast(ledger, "BROAD_UP_IMPULSE", "BROAD_DOWN_IMPULSE", 10L)
direction_h20 <- hreg42_contrast(ledger, "BROAD_UP_IMPULSE", "BROAD_DOWN_IMPULSE", 20L)
continuous_summary <- hreg42_continuous_summary(ledger)
offset_h5 <- hreg42_offset_summary(ledger, 5L, contract)
offset_h10 <- hreg42_offset_summary(ledger, 10L, contract)
period_summary <- hreg42_period_summary(ledger)
calendar_summary <- hreg42_calendar_summary(ledger)

message("HYP-REG-04.2 running 200 within-year circular state-timing controls.")
circular_controls <- hreg42_circular_controls(ledger, contract)
circular_readout <- data.frame(
  contrast = c("DIRECTION", "POSITIVE_IMPULSE"),
  actual_field_return_gap = c(direction_h5$field_return_gap, health_h5$field_return_gap),
  field_return_percentile = c(percentile(circular_controls$direction_field_return_gap, direction_h5$field_return_gap), percentile(circular_controls$health_field_return_gap, health_h5$field_return_gap)),
  actual_participation_gap = c(direction_h5$field_participation_gap, health_h5$field_participation_gap),
  participation_percentile = c(percentile(circular_controls$direction_participation_gap, direction_h5$field_participation_gap), percentile(circular_controls$health_participation_gap, health_h5$field_participation_gap)),
  stringsAsFactors = FALSE
)

get_continuous <- function(feature, target) continuous_summary$spearman[continuous_summary$feature == feature & continuous_summary$target == target][[1L]]
valid_h5_offsets <- sum(offset_h5$valid)
stable_h5_offsets <- sum(offset_h5$valid & offset_h5$field_return_gap > 0 & offset_h5$field_participation_gap > 0, na.rm = TRUE)
valid_h10_offsets <- sum(offset_h10$valid)
stable_h10_offsets <- sum(offset_h10$valid & offset_h10$field_return_gap > 0 & offset_h10$field_participation_gap > 0, na.rm = TRUE)
direction_periods <- period_summary[period_summary$contrast == "DIRECTION", ]
health_periods <- period_summary[period_summary$contrast == "POSITIVE_IMPULSE", ]
direction_years <- calendar_summary[calendar_summary$contrast == "DIRECTION", ]
health_years <- calendar_summary[calendar_summary$contrast == "POSITIVE_IMPULSE", ]
stable_direction_years <- sum(direction_years$field_return_gap > 0 & direction_years$field_participation_gap > 0, na.rm = TRUE)
stable_health_years <- sum(health_years$field_return_gap > 0 & health_years$field_participation_gap > 0, na.rm = TRUE)

gates <- do.call(rbind, list(
  data.frame(gate = "G1_INTEGRITY", threshold = "25/25 complete; 24 inputs; four equal groups; causal next-open targets; 2024+ excluded", observed = paste0(sum(coverage$coverage_status == "COMPLETE"), "/", nrow(coverage), " complete; ", nrow(ledger), " sessions"), passed = all(coverage$coverage_status == "COMPLETE") && all(ledger$field_inputs == contract$signal_assets) && !any(ledger$session_date >= contract$confirmation_start)),
  data.frame(gate = "G2_H5_DIRECTION_SEMANTICS", threshold = "both n>=75; field return gap>=0.50pp; participation gap>=10pp", observed = sprintf("n %d/%d; return %.2fpp; participation %.1fpp", direction_h5$state_a_n, direction_h5$state_b_n, 100 * direction_h5$field_return_gap, 100 * direction_h5$field_participation_gap), passed = direction_h5$state_a_n >= 75L && direction_h5$state_b_n >= 75L && direction_h5$field_return_gap >= .005 && direction_h5$field_participation_gap >= .10),
  data.frame(gate = "G3_H5_POSITIVE_IMPULSE", threshold = "both n>=75; return>=0.20pp; participation>=5pp; negative rate<=-5pp", observed = sprintf("n %d/%d; return %.2fpp; participation %.1fpp; negative %.1fpp", health_h5$state_a_n, health_h5$state_b_n, 100 * health_h5$field_return_gap, 100 * health_h5$field_participation_gap, 100 * health_h5$future_negative_rate_gap), passed = health_h5$state_a_n >= 75L && health_h5$state_b_n >= 75L && health_h5$field_return_gap >= .002 && health_h5$field_participation_gap >= .05 && health_h5$future_negative_rate_gap <= -.05),
  data.frame(gate = "G4_CONTINUOUS_ORDERING", threshold = "rho D5>=.10; P5>=.10; impulse>=.10; alignment persistence>0", observed = sprintf("D5 %.3f; P5 %.3f; impulse %.3f; alignment %.3f", get_continuous("direction5", "future_field_return_h5"), get_continuous("participation5", "future_field_return_h5"), get_continuous("participation_impulse", "future_participation_change_h5"), get_continuous("alignment", "directional_persistence_h5")), passed = get_continuous("direction5", "future_field_return_h5") >= .10 && get_continuous("participation5", "future_field_return_h5") >= .10 && get_continuous("participation_impulse", "future_participation_change_h5") >= .10 && get_continuous("alignment", "directional_persistence_h5") > 0),
  data.frame(gate = "G5_H5_OFFSET_STABILITY", threshold = "5 valid offsets; >=4 jointly positive", observed = paste0(valid_h5_offsets, " valid; ", stable_h5_offsets, " jointly positive"), passed = valid_h5_offsets == 5L && stable_h5_offsets >= 4L),
  data.frame(gate = "G6_H10_DURABILITY", threshold = "return>=0.50pp; participation>=5pp; >=7/10 offsets jointly positive", observed = sprintf("return %.2fpp; participation %.1fpp; %d valid; %d jointly positive", 100 * direction_h10$field_return_gap, 100 * direction_h10$field_participation_gap, valid_h10_offsets, stable_h10_offsets), passed = direction_h10$field_return_gap >= .005 && direction_h10$field_participation_gap >= .05 && valid_h10_offsets == 10L && stable_h10_offsets >= 7L),
  data.frame(gate = "G7_TEMPORAL_TRANSPORT", threshold = "H5 direction and positive-impulse return/participation gaps positive in both halves", observed = paste(sprintf("%s %s %.2fpp/%.1fpp", period_summary$period, period_summary$contrast, 100 * period_summary$field_return_gap, 100 * period_summary$field_participation_gap), collapse = "; "), passed = all(direction_periods$field_return_gap > 0 & direction_periods$field_participation_gap > 0) && all(health_periods$field_return_gap > 0 & health_periods$field_participation_gap > 0)),
  data.frame(gate = "G8_CALENDAR_STABILITY", threshold = "direction>=5/6; positive impulse>=4/6 jointly positive years", observed = paste0(stable_direction_years, "/6 direction; ", stable_health_years, "/6 positive impulse"), passed = stable_direction_years >= 5L && stable_health_years >= 4L),
  data.frame(gate = "G9_CIRCULAR_CONTROL", threshold = "direction>=90th; positive impulse>=80th for return and participation", observed = paste(sprintf("%s %.1fth/%.1fth", circular_readout$contrast, 100 * circular_readout$field_return_percentile, 100 * circular_readout$participation_percentile), collapse = "; "), passed = all(circular_readout$field_return_percentile >= c(.90, .80)) && all(circular_readout$participation_percentile >= c(.90, .80))),
  data.frame(gate = "G10_SECONDARY_SPY_H5", threshold = "SPY gap>=0.30pp; rho>=.10; AUC>=.55; both halves positive", observed = sprintf("gap %.2fpp; rho %.3f; AUC %.3f; halves %s", 100 * direction_h5$spy_return_gap, get_continuous("direction5", "spy_return_h5"), get_continuous("direction5", "spy_up_h5_auc"), paste(round(100 * direction_periods$spy_return_gap, 2), collapse = "/")), passed = direction_h5$spy_return_gap >= .003 && get_continuous("direction5", "spy_return_h5") >= .10 && get_continuous("direction5", "spy_up_h5_auc") >= .55 && all(direction_periods$spy_return_gap > 0))
))
status <- if (all(gates$passed)) "DIAGNOSTIC_COMPLETE_STOP_BEFORE_CONFIRMATION_ATR_JOIN_OR_STRATEGY" else "STOP_FAST_TREND_IMPULSE_GATES_FAILED_NO_CONFIRMATION_ATR_JOIN_OR_STRATEGY"

eligible <- ledger[is.finite(ledger$future_field_return_h5) & is.finite(ledger$direction5) & is.finite(ledger$participation_impulse), , drop = FALSE]
rank_bin <- function(x, bins) pmin(bins, pmax(1L, ceiling(rank(x, ties.method = "first") / length(x) * bins)))
eligible$direction_decile <- rank_bin(eligible$direction5, 10L)
eligible$impulse_quintile <- rank_bin(eligible$participation_impulse, 5L)
direction_deciles <- do.call(rbind, lapply(split(eligible, eligible$direction_decile), function(x) data.frame(
  decile = x$direction_decile[[1L]], observations = nrow(x),
  median_future_field_return_h5 = median_na(x$future_field_return_h5),
  median_future_field_return_h10 = median_na(x$future_field_return_h10),
  median_spy_return_h5 = median_na(x$spy_return_h5), stringsAsFactors = FALSE
)))
impulse_quintiles <- do.call(rbind, lapply(split(eligible, eligible$impulse_quintile), function(x) data.frame(
  quintile = x$impulse_quintile[[1L]], observations = nrow(x),
  mean_future_participation_change_h5 = mean(x$future_participation_change_h5, na.rm = TRUE),
  median_future_field_return_h5 = median_na(x$future_field_return_h5), stringsAsFactors = FALSE
)))

ink <- "#202630"; blue <- "#3D8DFF"; light_blue <- "#6DCBF4"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#B8BCC4"; pale <- "#EDEDED"
state_col <- c(BROAD_UP_IMPULSE = green, OTHER_UP = blue, BROAD_DOWN_IMPULSE = red, OTHER_DOWN = orange)

png(file.path(visual_dir, "fast_field_tape.png"), 1900, 1450, res = 150)
par(mfrow = c(3, 1), mar = c(3.3, 5, 3, 2), oma = c(1, 1, 2, 1))
plot(ledger$session_date, ledger$direction5, type = "l", col = ink, xlab = "", ylab = "Normalized 5-session trend", main = "Fast cross-sectional direction"); abline(h = 0, col = gray)
plot(ledger$session_date, 100 * ledger$participation5, type = "l", col = blue, ylim = c(0, 100), xlab = "", ylab = "Positive participation (%)", main = "Five-session participation"); abline(h = c(40, 60), col = gray, lty = 2)
plot(ledger$session_date, 100 * ledger$participation_impulse, type = "l", col = red, xlab = "Session", ylab = "Five-session change (pp)", main = "Participation impulse"); abline(h = 0, col = gray)
mtext("HYP-REG-04.2 | faster measurement; no ATR join or strategy", outer = TRUE, font = 2)
dev.off()

state_order <- c("BROAD_UP_IMPULSE", "OTHER_UP", "OTHER_DOWN", "BROAD_DOWN_IMPULSE")
ss5 <- state_summary_h5[match(state_order, state_summary_h5$state), ]
ss10 <- state_summary_h10[match(state_order, state_summary_h10$state), ]
png(file.path(visual_dir, "state_h5_h10_outcomes.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 3), mar = c(8, 5, 4, 1))
barplot(100 * ss5$median_future_field_return, names.arg = gsub("_", "\n", ss5$state), col = unname(state_col[ss5$state]), border = NA, cex.names = .62, ylab = "Median future field H5 return (%)", main = "Immediate direction"); abline(h = 0, col = gray)
barplot(100 * ss10$median_future_field_return, names.arg = gsub("_", "\n", ss10$state), col = unname(state_col[ss10$state]), border = NA, cex.names = .62, ylab = "Median future field H10 return (%)", main = "Ten-session durability"); abline(h = 0, col = gray)
barplot(100 * ss5$median_future_participation, names.arg = gsub("_", "\n", ss5$state), col = unname(state_col[ss5$state]), border = NA, cex.names = .62, ylim = c(0, 100), ylab = "Future positive participation (%)", main = "Immediate breadth")
dev.off()

png(file.path(visual_dir, "continuous_ordering.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
matplot(direction_deciles$decile, 100 * cbind(direction_deciles$median_future_field_return_h5, direction_deciles$median_future_field_return_h10), type = "b", pch = c(19, 17), col = c(blue, orange), lwd = 2, xaxt = "n", xlab = "Direction decile", ylab = "Median future field return (%)", main = "Does faster direction order outcomes?"); axis(1, at = c(1, 5, 10)); abline(h = 0, col = gray); legend("topleft", c("H5", "H10"), col = c(blue, orange), pch = c(19, 17), lty = 1, bty = "n")
plot(impulse_quintiles$quintile, 100 * impulse_quintiles$mean_future_participation_change_h5, type = "b", pch = 19, col = red, lwd = 2, xaxt = "n", xlab = "Impulse quintile", ylab = "Mean future H5 participation change (pp)", main = "Does broadening continue?"); axis(1, at = 1:5); abline(h = 0, col = gray)
dev.off()

context_order <- c("UP_CONTINUATION", "UP_REVERSAL", "DOWN_CONTINUATION", "DOWN_REVERSAL")
cs <- context_summary[match(context_order, context_summary$context), ]
context_persistence <- as.numeric(cs$median_directional_persistence_h5)
context_participation <- as.numeric(cs$median_future_participation_h5)
if (!all(is.finite(context_persistence)) || !all(is.finite(context_participation))) stop("Context summary is incomplete.", call. = FALSE)
png(file.path(visual_dir, "context_onset.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
barplot(100 * context_persistence, names.arg = gsub("_", "\n", context_order), col = c(green, light_blue, red, orange), border = NA, cex.names = .68, ylab = "Median sign-aligned H5 return (%)", main = "Continuation versus reversal"); abline(h = 0, col = gray)
plot(seq_along(context_participation), 100 * context_participation, type = "h", lwd = 34, lend = 1, col = c(green, light_blue, red, orange), xaxt = "n", xlim = c(.5, 4.5), ylim = c(0, 100), xlab = "", ylab = "Future positive participation (%)", main = "Future breadth by context"); axis(1, at = seq_along(context_order), labels = gsub("_", "\n", context_order), cex.axis = .68)
dev.off()

png(file.path(visual_dir, "offset_stability.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
barplot(100 * offset_h5$field_return_gap, names.arg = offset_h5$offset, col = ifelse(offset_h5$field_return_gap > 0, green, red), border = NA, xlab = "H5 starting offset", ylab = "UP impulse minus DOWN impulse (pp)", main = "Five-session direction stability"); abline(h = 0, col = ink)
barplot(100 * offset_h10$field_return_gap, names.arg = offset_h10$offset, col = ifelse(offset_h10$field_return_gap > 0, green, red), border = NA, xlab = "H10 starting offset", ylab = "UP impulse minus DOWN impulse (pp)", main = "Ten-session durability stability"); abline(h = 0, col = ink)
dev.off()

png(file.path(visual_dir, "temporal_and_circular.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 1))
barplot(rbind(100 * period_summary$field_return_gap, 100 * period_summary$field_participation_gap), beside = TRUE, names.arg = paste(period_summary$period, ifelse(period_summary$contrast == "DIRECTION", "DIR", "IMP"), sep = "\n"), col = c(blue, orange), border = NA, cex.names = .7, ylab = "Gap (pp)", main = "Temporal-half transport"); abline(h = 0, col = ink); legend("topleft", c("Field return", "Participation"), fill = c(blue, orange), bty = "n")
boxplot(100 * circular_controls$direction_field_return_gap, 100 * circular_controls$health_field_return_gap, names = c("Direction", "Positive impulse"), col = pale, border = gray, ylab = "Circular-control H5 return gap (pp)", main = "Timing falsification"); points(c(1, 2), 100 * c(direction_h5$field_return_gap, health_h5$field_return_gap), pch = 19, col = red, cex = 1.4); legend("topright", "Actual", pch = 19, col = red, bty = "n")
dev.off()

png(file.path(visual_dir, "spy_external_check.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
barplot(100 * ss5$median_spy_return, names.arg = gsub("_", "\n", ss5$state), col = unname(state_col[ss5$state]), border = NA, cex.names = .62, ylab = "Median next-open SPY H5 return (%)", main = "Secondary external direction check"); abline(h = 0, col = gray)
plot(direction_deciles$decile, 100 * direction_deciles$median_spy_return_h5, type = "b", pch = 19, col = ink, lwd = 2, xaxt = "n", xlab = "Fast-direction decile", ylab = "Median next-open SPY H5 return (%)", main = "SPY ordering"); axis(1, at = c(1, 5, 10)); abline(h = 0, col = gray)
dev.off()

run_spec <- data.frame(
  hypothesis_id = contract$hypothesis_id, status = status, as_of_timestamp = contract$as_of_timestamp,
  query_start = contract$query_start, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end,
  field = "equal-group z5 direction, five-session participation and impulse; z20 context only",
  primary_targets = "future cross-sectional H5 direction, participation, participation continuity",
  durability_target = "H10 field direction and participation",
  decay_target = "H20 reported only; cannot rescue or veto",
  secondary_target = "SPY next-open H5/H10 open-to-open direction",
  strategy_outcomes = "PROHIBITED", atr_join = "PROHIBITED", confirmation_2024_plus = "SEALED", refresh = refresh,
  stringsAsFactors = FALSE
)
integrity <- data.frame(
  check = c("complete_registry_coverage", "twenty_four_field_inputs", "four_equal_groups", "common_spy_calendar", "next_open_targets", "confirmation_excluded", "no_strategy_outcomes"),
  passed = c(all(coverage$coverage_status == "COMPLETE"), all(ledger$field_inputs == 24L), length(unique(signals$group)) == 4L, nrow(ledger) == length(spy_dates), identical(ledger$spy_return_h5, hreg42_forward_open_return(ledger$spy_open, 5L)), !any(ledger$session_date >= contract$confirmation_start), !any(c("strategy_return", "pnl", "sharpe", "drawdown", "hit_rate", "atr_state") %in% names(ledger))),
  stringsAsFactors = FALSE
)
files <- list(run_spec = run_spec, integrity = integrity, registry = registry, coverage = coverage, query_health = query$health, ledger = ledger, state_summary_h5 = state_summary_h5, state_summary_h10 = state_summary_h10, state_summary_h20 = state_summary_h20, context_summary = context_summary, direction_h5 = direction_h5, health_h5 = health_h5, direction_h10 = direction_h10, direction_h20 = direction_h20, continuous_summary = continuous_summary, direction_deciles = direction_deciles, impulse_quintiles = impulse_quintiles, offset_h5 = offset_h5, offset_h10 = offset_h10, period_summary = period_summary, calendar_summary = calendar_summary, circular_controls = circular_controls, circular_readout = circular_readout, gates = gates)
for (name in names(files)) write_csv(files[[name]], file.path(output_dir, paste0("hyp_reg_04_2_", name, ".csv")))

report <- c(
  "# HYP-REG-04.2 Fast Cross-Sectional Trend-Impulse Diagnostic", "", paste0("Status: `", status, "`"), "", "## Primary readout", "",
  sprintf("- H5 direction n=%d/%d; field-return gap %.3f pp; participation gap %.3f pp; SPY gap %.3f pp.", direction_h5$state_a_n, direction_h5$state_b_n, 100 * direction_h5$field_return_gap, 100 * direction_h5$field_participation_gap, 100 * direction_h5$spy_return_gap),
  sprintf("- H5 positive impulse n=%d/%d; field-return gap %.3f pp; participation gap %.3f pp; negative-rate gap %.3f pp.", health_h5$state_a_n, health_h5$state_b_n, 100 * health_h5$field_return_gap, 100 * health_h5$field_participation_gap, 100 * health_h5$future_negative_rate_gap),
  sprintf("- Continuous H5: D5 rho %.3f; P5 rho %.3f; impulse rho %.3f; alignment-persistence rho %.3f.", get_continuous("direction5", "future_field_return_h5"), get_continuous("participation5", "future_field_return_h5"), get_continuous("participation_impulse", "future_participation_change_h5"), get_continuous("alignment", "directional_persistence_h5")),
  sprintf("- H10 direction gap %.3f pp; participation gap %.3f pp; H20 decay gap %.3f pp.", 100 * direction_h10$field_return_gap, 100 * direction_h10$field_participation_gap, 100 * direction_h20$field_return_gap),
  sprintf("- Offset stability: H5 %d/%d jointly positive; H10 %d/%d. Gates passed: %d/%d.", stable_h5_offsets, valid_h5_offsets, stable_h10_offsets, valid_h10_offsets, sum(gates$passed), nrow(gates)), "",
  "This is a retrospectively motivated development diagnostic. It does not join ATR%, calculate a strategy, or access confirmation data."
)
writeLines(report, file.path(output_dir, "hyp_reg_04_2_report.md"), useBytes = TRUE)
message("HYP-REG-04.2 complete: ", output_dir)
