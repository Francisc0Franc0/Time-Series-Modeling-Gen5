options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_04_1_cross_sectional_trend_field.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
percentile <- function(distribution, actual) mean(distribution <= actual, na.rm = TRUE)

contract <- hreg41_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_04_1_cross_sectional_trend_field_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
signals <- registry[registry$role == "field_signal", , drop = FALSE]
if (nrow(registry) != contract$registry_assets || nrow(signals) != contract$signal_assets || anyDuplicated(registry$symbol) || !identical(registry$symbol[registry$role == "context_target"], "SPY") || length(unique(signals$group)) != contract$signal_groups) stop("Frozen registry integrity failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_REG_041_RUN_ID", "hyp_reg_04_1_cross_sectional_trend_field_20260814")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_REG_041_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = registry$symbol,
  universe_name = "hyp_reg_04_1_cross_sectional_trend_field_panel",
  universe_roles = "four_group_market_field,spy_secondary_target,diagnostic_only",
  refresh = refresh,
  repo_root = repo_root
)

bars <- hreg41_validate_bars(query$bars, contract)
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

message("HYP-REG-04.1 building the equal-group cross-sectional trend field.")
ledger <- hreg41_build_ledger(bars, signals$symbol, signals$group, contract)
if (nrow(ledger) != length(spy_dates) || !identical(ledger$session_date, spy_dates) || any(ledger$field_inputs != contract$signal_assets)) stop("Common field calendar is incomplete.", call. = FALSE)
if (any(ledger$session_date >= contract$confirmation_start)) stop("Confirmation rows entered the ledger.", call. = FALSE)

state_summary <- hreg41_state_summary(ledger)
direction_contrast <- hreg41_contrast(ledger, "BROAD_UP", "BROAD_DOWN")
health_contrast <- hreg41_contrast(ledger, "BROAD_UP", "FRAGILE_UP")
continuous_summary <- hreg41_continuous_summary(ledger)
offset_summary <- hreg41_offset_summary(ledger, contract)
period_summary <- hreg41_period_summary(ledger)
calendar_summary <- hreg41_calendar_summary(ledger)

message("HYP-REG-04.1 running 200 within-year circular state-timing controls.")
circular_controls <- hreg41_circular_controls(ledger, contract)
circular_readout <- data.frame(
  contrast = c("DIRECTION", "POSITIVE_HEALTH"),
  actual_field_return_gap = c(direction_contrast$field_return_gap, health_contrast$field_return_gap),
  field_return_percentile = c(percentile(circular_controls$direction_field_return_gap, direction_contrast$field_return_gap), percentile(circular_controls$health_field_return_gap, health_contrast$field_return_gap)),
  actual_participation_gap = c(direction_contrast$field_participation_gap, health_contrast$field_participation_gap),
  participation_percentile = c(percentile(circular_controls$direction_participation_gap, direction_contrast$field_participation_gap), percentile(circular_controls$health_participation_gap, health_contrast$field_participation_gap)),
  stringsAsFactors = FALSE
)

get_continuous <- function(feature, target) continuous_summary$spearman[continuous_summary$feature == feature & continuous_summary$target == target][[1L]]
valid_offsets <- sum(offset_summary$valid)
stable_offsets <- sum(offset_summary$valid & offset_summary$field_return_gap > 0 & offset_summary$field_participation_gap > 0, na.rm = TRUE)
direction_periods <- period_summary[period_summary$contrast == "DIRECTION", ]
health_periods <- period_summary[period_summary$contrast == "POSITIVE_HEALTH", ]
direction_years <- calendar_summary[calendar_summary$contrast == "DIRECTION", ]
health_years <- calendar_summary[calendar_summary$contrast == "POSITIVE_HEALTH", ]
stable_direction_years <- sum(direction_years$field_return_gap > 0 & direction_years$field_participation_gap > 0, na.rm = TRUE)
stable_health_years <- sum(health_years$field_return_gap > 0 & health_years$field_participation_gap > 0, na.rm = TRUE)

gates <- do.call(rbind, list(
  data.frame(gate = "G1_INTEGRITY", threshold = "25/25 complete; 24 inputs; equal four-group aggregation; next-open SPY target; 2024+ excluded", observed = paste0(sum(coverage$coverage_status == "COMPLETE"), "/", nrow(coverage), " complete; ", nrow(ledger), " sessions"), passed = all(coverage$coverage_status == "COMPLETE") && all(ledger$field_inputs == contract$signal_assets) && !any(ledger$session_date >= contract$confirmation_start)),
  data.frame(gate = "G2_DIRECTION_SEMANTICS", threshold = "both n>=100; field return gap>=2pp; participation gap>=20pp", observed = sprintf("n %d/%d; return %.2fpp; participation %.1fpp", direction_contrast$state_a_n, direction_contrast$state_b_n, 100 * direction_contrast$field_return_gap, 100 * direction_contrast$field_participation_gap), passed = direction_contrast$state_a_n >= 100L && direction_contrast$state_b_n >= 100L && direction_contrast$field_return_gap >= .02 && direction_contrast$field_participation_gap >= .20),
  data.frame(gate = "G3_POSITIVE_HEALTH_SEMANTICS", threshold = "both n>=100; return>=0.5pp; participation>=10pp; negative rate<=-10pp", observed = sprintf("n %d/%d; return %.2fpp; participation %.1fpp; negative %.1fpp", health_contrast$state_a_n, health_contrast$state_b_n, 100 * health_contrast$field_return_gap, 100 * health_contrast$field_participation_gap, 100 * health_contrast$future_negative_rate_gap), passed = health_contrast$state_a_n >= 100L && health_contrast$state_b_n >= 100L && health_contrast$field_return_gap >= .005 && health_contrast$field_participation_gap >= .10 && health_contrast$future_negative_rate_gap <= -.10),
  data.frame(gate = "G4_CONTINUOUS_ORDERING", threshold = "rho direction>=.15; participation>=.10; flow>=.10; agreement persistence>0", observed = sprintf("direction %.3f; participation %.3f; flow %.3f; agreement %.3f", get_continuous("direction_score", "future_field_return_h20"), get_continuous("participation", "future_field_return_h20"), get_continuous("flow", "future_participation_change_h5"), get_continuous("agreement", "directional_persistence_h20")), passed = get_continuous("direction_score", "future_field_return_h20") >= .15 && get_continuous("participation", "future_field_return_h20") >= .10 && get_continuous("flow", "future_participation_change_h5") >= .10 && get_continuous("agreement", "directional_persistence_h20") > 0),
  data.frame(gate = "G5_OFFSET_STABILITY", threshold = ">=15 valid offsets; >=14 positive return and participation gaps", observed = paste0(valid_offsets, " valid; ", stable_offsets, " jointly positive"), passed = valid_offsets >= contract$minimum_valid_offsets && stable_offsets >= contract$minimum_stable_offsets),
  data.frame(gate = "G6_TEMPORAL_TRANSPORT", threshold = "direction and positive-health return/participation gaps positive in both halves", observed = paste(sprintf("%s %s %.2fpp/%.1fpp", period_summary$period, period_summary$contrast, 100 * period_summary$field_return_gap, 100 * period_summary$field_participation_gap), collapse = "; "), passed = all(direction_periods$field_return_gap > 0 & direction_periods$field_participation_gap > 0) && all(health_periods$field_return_gap > 0 & health_periods$field_participation_gap > 0)),
  data.frame(gate = "G7_CALENDAR_STABILITY", threshold = "direction >=5/6; positive health >=4/6 jointly positive years", observed = paste0(stable_direction_years, "/6 direction; ", stable_health_years, "/6 health"), passed = stable_direction_years >= 5L && stable_health_years >= 4L),
  data.frame(gate = "G8_CIRCULAR_CONTROL", threshold = "direction >=90th; positive health >=80th for return and participation", observed = paste(sprintf("%s %.1fth/%.1fth", circular_readout$contrast, 100 * circular_readout$field_return_percentile, 100 * circular_readout$participation_percentile), collapse = "; "), passed = all(circular_readout$field_return_percentile >= c(.90, .80)) && all(circular_readout$participation_percentile >= c(.90, .80))),
  data.frame(gate = "G9_SECONDARY_SPY_DIRECTION", threshold = "SPY gap>=1pp; rho>=.10; AUC>=.55; both halves positive", observed = sprintf("gap %.2fpp; rho %.3f; AUC %.3f; halves %s", 100 * direction_contrast$spy_return_gap, get_continuous("direction_score", "spy_return_h20"), get_continuous("direction_score", "spy_up_h20_auc"), paste(round(100 * direction_periods$spy_return_gap, 2), collapse = "/")), passed = direction_contrast$spy_return_gap >= .01 && get_continuous("direction_score", "spy_return_h20") >= .10 && get_continuous("direction_score", "spy_up_h20_auc") >= .55 && all(direction_periods$spy_return_gap > 0))
))
status <- if (all(gates$passed)) "DIAGNOSTIC_COMPLETE_STOP_BEFORE_ATR_JOIN_OR_STRATEGY" else "STOP_TREND_FIELD_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY"

# Descriptive deciles for purposeful visuals.
eligible <- ledger[is.finite(ledger$future_field_return_h20) & is.finite(ledger$direction_score) & is.finite(ledger$flow), , drop = FALSE]
eligible$direction_decile <- as.integer(cut(eligible$direction_score, breaks = stats::quantile(eligible$direction_score, probs = seq(0, 1, .1), na.rm = TRUE), include.lowest = TRUE, labels = FALSE))
eligible$flow_bin <- as.integer(cut(eligible$flow + seq_along(eligible$flow) * .Machine$double.eps, breaks = stats::quantile(eligible$flow + seq_along(eligible$flow) * .Machine$double.eps, probs = seq(0, 1, .2), na.rm = TRUE), include.lowest = TRUE, labels = FALSE))
direction_deciles <- do.call(rbind, lapply(split(eligible, eligible$direction_decile), function(x) data.frame(decile = x$direction_decile[[1L]], observations = nrow(x), median_future_field_return = median_na(x$future_field_return_h20), median_spy_return = median_na(x$spy_return_h20), stringsAsFactors = FALSE)))
flow_bins <- do.call(rbind, lapply(split(eligible, eligible$flow_bin), function(x) data.frame(bin = x$flow_bin[[1L]], observations = nrow(x), mean_future_participation_change_h5 = mean(x$future_participation_change_h5, na.rm = TRUE), stringsAsFactors = FALSE)))

ink <- "#202630"; blue <- "#3D8DFF"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#B8BCC4"; pale <- "#EDEDED"
state_col <- c(BROAD_UP = green, FRAGILE_UP = blue, BROAD_DOWN = red, FRAGILE_DOWN = orange)

png(file.path(visual_dir, "trend_field_tape.png"), 1900, 1650, res = 150)
par(mfrow = c(4, 1), mar = c(3.3, 5, 3, 2), oma = c(1, 1, 2, 1))
plot(ledger$session_date, ledger$direction_score, type = "l", col = ink, xlab = "", ylab = "Median normalized trend", main = "Cross-sectional direction"); abline(h = 0, col = gray)
plot(ledger$session_date, 100 * ledger$participation, type = "l", col = blue, ylim = c(0, 100), xlab = "", ylab = "Participation (%)", main = "Equal-group participation"); abline(h = c(40, 60), col = gray, lty = 2)
plot(ledger$session_date, 100 * ledger$agreement, type = "l", col = orange, ylim = c(0, 100), xlab = "", ylab = "Agreement (%)", main = "20/60-session sign agreement"); abline(h = 60, col = gray, lty = 2)
plot(ledger$session_date, ledger$flow, type = "l", col = red, xlab = "Session", ylab = "Improving minus weakening", main = "Five-session trend flow"); abline(h = 0, col = gray)
mtext("HYP-REG-04.1 | four independent field measurements; no fitted composite", outer = TRUE, font = 2)
dev.off()

png(file.path(visual_dir, "state_outcomes.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 1))
ss <- state_summary[match(c("BROAD_UP", "FRAGILE_UP", "FRAGILE_DOWN", "BROAD_DOWN"), state_summary$state), ]
barplot(100 * ss$median_future_field_return, names.arg = gsub("_", "\n", ss$state), col = unname(state_col[ss$state]), border = NA, las = 1, cex.names = .75, ylab = "Median future field H20 return (%)", main = "Does the state preserve direction?"); abline(h = 0, col = gray)
barplot(100 * ss$median_future_participation, names.arg = gsub("_", "\n", ss$state), col = unname(state_col[ss$state]), border = NA, las = 1, cex.names = .75, ylim = c(0, 100), ylab = "Future positive participation (%)", main = "Future cross-sectional participation")
dev.off()

png(file.path(visual_dir, "continuous_ordering.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(direction_deciles$decile, 100 * direction_deciles$median_future_field_return, type = "b", pch = 19, col = blue, lwd = 2, xaxt = "n", xlab = "Direction decile", ylab = "Median future field H20 return (%)", main = "Direction ordering"); axis(1, at = c(1, 5, 10)); abline(h = 0, col = gray)
plot(flow_bins$bin, 100 * flow_bins$mean_future_participation_change_h5, type = "b", pch = 19, col = red, lwd = 2, xaxt = "n", xlab = "Flow quintile", ylab = "Mean future H5 participation change (pp)", main = "Does improving flow persist?"); axis(1, at = c(1, 3, 5)); abline(h = 0, col = gray)
dev.off()

png(file.path(visual_dir, "offset_stability.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
barplot(100 * offset_summary$field_return_gap, names.arg = offset_summary$offset, col = ifelse(offset_summary$field_return_gap > 0, green, red), border = NA, xlab = "H20 starting offset", ylab = "BROAD UP minus BROAD DOWN (pp)", main = "Non-overlapping field-return stability"); abline(h = 0, col = ink)
barplot(100 * offset_summary$field_participation_gap, names.arg = offset_summary$offset, col = ifelse(offset_summary$field_participation_gap > 0, green, red), border = NA, xlab = "H20 starting offset", ylab = "Participation gap (pp)", main = "Non-overlapping participation stability"); abline(h = 0, col = ink)
dev.off()

png(file.path(visual_dir, "temporal_and_circular.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 1))
barplot(rbind(100 * period_summary$field_return_gap, 100 * period_summary$field_participation_gap), beside = TRUE, names.arg = paste(period_summary$period, ifelse(period_summary$contrast == "DIRECTION", "DIR", "HEALTH"), sep = "\n"), col = c(blue, orange), border = NA, cex.names = .7, ylab = "Gap (pp)", main = "Temporal-half transport"); abline(h = 0, col = ink); legend("topleft", c("Field return", "Participation"), fill = c(blue, orange), bty = "n")
boxplot(100 * circular_controls$direction_field_return_gap, 100 * circular_controls$health_field_return_gap, names = c("Direction", "Positive health"), col = pale, border = gray, ylab = "Circular-control field-return gap (pp)", main = "Timing falsification"); points(c(1, 2), 100 * c(direction_contrast$field_return_gap, health_contrast$field_return_gap), pch = 19, col = red, cex = 1.4); legend("topright", "Actual", pch = 19, col = red, bty = "n")
dev.off()

png(file.path(visual_dir, "spy_external_check.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 1))
barplot(100 * ss$median_spy_return, names.arg = gsub("_", "\n", ss$state), col = unname(state_col[ss$state]), border = NA, las = 1, cex.names = .75, ylab = "Median next-open SPY H20 return (%)", main = "Secondary external direction check"); abline(h = 0, col = gray)
plot(direction_deciles$decile, 100 * direction_deciles$median_spy_return, type = "b", pch = 19, col = ink, lwd = 2, xaxt = "n", xlab = "Direction-score decile", ylab = "Median next-open SPY H20 return (%)", main = "SPY ordering"); axis(1, at = seq(1, 9, 2)); abline(h = 0, col = gray)
dev.off()

run_spec <- data.frame(
  hypothesis_id = contract$hypothesis_id, status = status, as_of_timestamp = contract$as_of_timestamp,
  query_start = contract$query_start, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end,
  field = "equal-group direction, participation, 20/60 agreement, five-session flow",
  primary_targets = "future cross-sectional field return, participation, flow semantics",
  secondary_target = "SPY next-open H20 open-to-open direction",
  eventual_architecture = "market field x per-asset ATR% x unchanged asset signal; NOT OPEN",
  strategy_outcomes = "PROHIBITED", atr_join = "PROHIBITED", confirmation_2024_plus = "SEALED", refresh = refresh,
  stringsAsFactors = FALSE
)
integrity <- data.frame(
  check = c("complete_registry_coverage", "twenty_four_field_inputs", "four_equal_groups", "common_spy_calendar", "next_open_spy_target", "confirmation_excluded", "no_strategy_outcomes"),
  passed = c(all(coverage$coverage_status == "COMPLETE"), all(ledger$field_inputs == 24L), length(unique(signals$group)) == 4L, nrow(ledger) == length(spy_dates), identical(ledger$spy_return_h20, hreg41_forward_open_return(ledger$spy_open, 20L)), !any(ledger$session_date >= contract$confirmation_start), !any(c("strategy_return", "pnl", "sharpe", "drawdown", "hit_rate", "atr_state") %in% names(ledger))),
  stringsAsFactors = FALSE
)
files <- list(run_spec = run_spec, integrity = integrity, registry = registry, coverage = coverage, query_health = query$health, ledger = ledger, state_summary = state_summary, direction_contrast = direction_contrast, health_contrast = health_contrast, continuous_summary = continuous_summary, direction_deciles = direction_deciles, flow_bins = flow_bins, offset_summary = offset_summary, period_summary = period_summary, calendar_summary = calendar_summary, circular_controls = circular_controls, circular_readout = circular_readout, gates = gates)
for (name in names(files)) write_csv(files[[name]], file.path(output_dir, paste0("hyp_reg_04_1_", name, ".csv")))

report <- c(
  "# HYP-REG-04.1 Cross-Sectional Trend-Field Diagnostic", "", paste0("Status: `", status, "`"), "", "## Primary readout", "",
  sprintf("- Direction contrast n=%d/%d; field-return gap %.3f pp; future-participation gap %.3f pp.", direction_contrast$state_a_n, direction_contrast$state_b_n, 100 * direction_contrast$field_return_gap, 100 * direction_contrast$field_participation_gap),
  sprintf("- Positive-health contrast n=%d/%d; field-return gap %.3f pp; participation gap %.3f pp; future-negative-rate gap %.3f pp.", health_contrast$state_a_n, health_contrast$state_b_n, 100 * health_contrast$field_return_gap, 100 * health_contrast$field_participation_gap, 100 * health_contrast$future_negative_rate_gap),
  sprintf("- Continuous direction rho %.3f; participation rho %.3f; flow rho %.3f; agreement-persistence rho %.3f.", get_continuous("direction_score", "future_field_return_h20"), get_continuous("participation", "future_field_return_h20"), get_continuous("flow", "future_participation_change_h5"), get_continuous("agreement", "directional_persistence_h20")),
  sprintf("- Secondary SPY: return gap %.3f pp; rho %.3f; UP AUC %.3f.", 100 * direction_contrast$spy_return_gap, get_continuous("direction_score", "spy_return_h20"), get_continuous("direction_score", "spy_up_h20_auc")),
  sprintf("- Offset stability: %d valid; %d/20 jointly positive. Gates passed: %d/%d.", valid_offsets, stable_offsets, sum(gates$passed), nrow(gates)), "",
  "This is a causal market-context diagnostic. It does not join ATR%, trade TSLA/AMD, calculate a strategy, or grant routing authority."
)
writeLines(report, file.path(output_dir, "hyp_reg_04_1_report.md"), useBytes = TRUE)
message("HYP-REG-04.1 complete: ", output_dir)
