options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_09_1_robust_slope_fit_poc.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_11_1_causal_change_point_poc.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
fmt_pct <- function(x, digits = 2L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))

contract <- hreg111_contract(); imom <- imom_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_11_1_causal_change_point_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
if (nrow(registry) != 26L || anyDuplicated(registry$symbol) || sum(registry$strategy_role == "primary_stock") != 24L) hreg111_stop("Frozen registry integrity failed.")
stocks <- registry$symbol[registry$strategy_role == "primary_stock"]
run_id <- env_or("GEN5_HYP_REG_111_RUN_ID", "hyp_reg_11_1_causal_change_point_20260816")
run_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(run_dir, "visuals"); dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

message("HYP-REG-11.1 calibrating the detector without market outcomes.")
calibration <- hreg111_calibrate_threshold(contract); threshold <- calibration$threshold
shift_trials <- hreg111_shift_calibration(threshold, contract); shift_summary <- hreg111_shift_summary(shift_trials)
null_rates <- calibration$rates

cfg <- g5_load_data_layer_config(repo_root); refresh <- env_bool("GEN5_HYP_REG_111_REFRESH", FALSE)
message("HYP-REG-11.1 loading the frozen daily measurement surface.")
query <- g5_workbench_query_adjusted_daily_bars(cfg = cfg, start_date = contract$query_start, end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = registry$symbol, universe_name = "hyp_reg_11_1_causal_change_point_panel",
  universe_roles = "causal_positive_cusum,development_reused_window", refresh = refresh, repo_root = repo_root)
bars <- hreg91_assert_bars(query$bars, contract)
reference_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars[bars$symbol == reg$symbol, , drop = FALSE]; dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start); missing <- length(setdiff(reference_dates, dates))
  cbind(reg, data.frame(total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates), missing_reference_sessions = missing,
    coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < contract$minimum_prehistory) "PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else "COMPLETE", stringsAsFactors = FALSE))
}))
if (any(coverage$coverage_status != "COMPLETE")) { print(coverage[coverage$coverage_status != "COMPLETE", ], row.names = FALSE); hreg111_stop("One or more assets lack frozen measurement coverage.") }

ledger_cache <- file.path(run_dir, "hyp_reg_11_1_ledger.csv")
if (file.exists(ledger_cache) && !env_bool("GEN5_HYP_REG_111_REBUILD_MEASUREMENT", FALSE)) {
  ledger <- utils::read.csv(ledger_cache, stringsAsFactors = FALSE); ledger$session_date <- as.Date(ledger$session_date); ledger$positive_alarm <- as.logical(ledger$positive_alarm); ledger$recent_positive_onset_eligible <- as.logical(ledger$recent_positive_onset_eligible)
} else ledger <- hreg111_build_ledger(bars, threshold, contract)
analysis <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
if (any(analysis$session_date >= contract$confirmation_start) || length(unique(analysis$symbol)) != 26L) hreg111_stop("Measurement boundary integrity failed.")

cross_frames <- lapply(split(bars, bars$symbol), function(x) hreg12_cross_frame(x, contract$fast, contract$slow))
state_diagnostics <- hreg111_state_diagnostics(ledger, cross_frames, contract)
primary_diag <- state_diagnostics[state_diagnostics$symbol %in% stocks, , drop = FALSE]
causality <- hreg111_causality_audit(threshold, contract)
scale_rows <- lapply(split(bars, bars$symbol), function(x) {
  a <- hreg111_build_asset_ledger(x, threshold, contract); scaled <- x; scaled$open <- scaled$open * 7; scaled$high <- scaled$high * 7; scaled$low <- scaled$low * 7; scaled$close <- scaled$close * 7
  b <- hreg111_build_asset_ledger(scaled, threshold, contract); keep <- is.finite(a$trailing_standardized_return) & is.finite(b$trailing_standardized_return)
  data.frame(symbol = x$symbol[[1L]], maximum_z_difference = max(abs(a$trailing_standardized_return[keep] - b$trailing_standardized_return[keep])), alarm_match = identical(a$positive_alarm, b$positive_alarm), stringsAsFactors = FALSE)
})
scale_audit <- do.call(rbind, scale_rows)

semantic_violations <- sum((analysis$positive_alarm & (!analysis$recent_positive_onset_eligible | analysis$days_since_positive_alarm != 0)) |
  (analysis$recent_positive_onset_eligible & (is.na(analysis$days_since_positive_alarm) | analysis$days_since_positive_alarm < 0 | analysis$days_since_positive_alarm >= contract$eligibility_sessions)), na.rm = TRUE)
spacing_violations <- sum(vapply(split(analysis, analysis$symbol), function(z) { a <- which(z$positive_alarm); if (length(a) < 2L) 0L else sum(diff(a) < contract$refractory_sessions) }, integer(1)))
get_shift <- function(kind) shift_summary[shift_summary$process == kind, , drop = FALSE]
strong <- get_shift("POSITIVE_SHIFT_030"); negative <- get_shift("NEGATIVE_SHIFT_030"); jump <- get_shift("SINGLE_POSITIVE_JUMP")
usable_alarm_assets <- sum(primary_diag$alarms >= 3L); usable_cross_assets <- sum(primary_diag$eligible_crosses >= 1L); median_occupancy <- stats::median(primary_diag$eligible_fraction)

stage_a_gates <- data.frame(
  gate = c("A1_DATA_AND_BOUNDARY", "A2_NULL_FALSE_ALARM_CALIBRATION", "A3_POSITIVE_SHIFT_DETECTION", "A4_DIRECTION_AND_JUMP_FALSIFICATION", "A5_CAUSAL_AND_SCALE_INVARIANCE", "A6_EVENT_WINDOW_SEMANTICS", "A7_REAL_PANEL_USABILITY"),
  threshold = c(">=120 prehistory; complete 26-asset analysis; 2024+ absent", "each 504-session null family <=20%; smallest qualifying grid threshold", "+0.30 shift: >=70% detected within 60 sessions; median delay <=40", "-0.30 shift and isolated +5 sigma jump each <=20% detected within 60", "append invariant; price scale max difference <=1e-12; alarm sequence exact", "alarms begin exact 10-session non-extending windows; spacing >=10", ">=18/24 stocks with >=3 alarms and >=1 eligible cross; median occupancy 1%-25%"),
  observed = c(
    sprintf("%d/26 complete; min %d prehistory; max date %s", sum(coverage$coverage_status == "COMPLETE"), min(coverage$prehistory_sessions), max(analysis$session_date)),
    sprintf("h=%.2f; worst null %.1f%%", threshold, 100 * max(null_rates$false_alarm_probability)),
    sprintf("%.1f%% within 60; median delay %.1f", 100 * strong$detection_probability_60, strong$median_detection_delay),
    sprintf("negative %.1f%%; jump %.1f%%", 100 * negative$detection_probability_60, 100 * jump$detection_probability_60),
    sprintf("append %d/%d; max scale difference %.3g; alarms exact %s", sum(causality$passed), nrow(causality), max(scale_audit$maximum_z_difference), all(scale_audit$alarm_match)),
    sprintf("%d semantic; %d spacing violations", semantic_violations, spacing_violations),
    sprintf("%d/24 alarm-usable; %d/24 cross-usable; median occupancy %.1f%%", usable_alarm_assets, usable_cross_assets, 100 * median_occupancy)
  ),
  passed = c(
    all(coverage$coverage_status == "COMPLETE") && !any(analysis$session_date >= contract$confirmation_start),
    all(null_rates$false_alarm_probability <= contract$false_alarm_budget) && identical(threshold, min(contract$threshold_grid[contract$threshold_grid >= threshold])),
    strong$detection_probability_60 >= .70 && strong$median_detection_delay <= 40,
    negative$detection_probability_60 <= .20 && jump$detection_probability_60 <= .20,
    all(causality$passed) && max(scale_audit$maximum_z_difference) <= 1e-12 && all(scale_audit$alarm_match),
    semantic_violations == 0L && spacing_violations == 0L,
    usable_alarm_assets >= 18L && usable_cross_assets >= 18L && median_occupancy >= .01 && median_occupancy <= .25
  ), stringsAsFactors = FALSE
)
stage_a_passed <- all(stage_a_gates$passed)

write_csv(registry, file.path(run_dir, "hyp_reg_11_1_registry.csv")); write_csv(coverage, file.path(run_dir, "hyp_reg_11_1_coverage.csv")); write_csv(ledger, ledger_cache)
write_csv(calibration$maxima, file.path(run_dir, "hyp_reg_11_1_null_maxima.csv")); write_csv(null_rates, file.path(run_dir, "hyp_reg_11_1_null_rates.csv")); write_csv(shift_trials, file.path(run_dir, "hyp_reg_11_1_shift_trials.csv")); write_csv(shift_summary, file.path(run_dir, "hyp_reg_11_1_shift_summary.csv"))
write_csv(state_diagnostics, file.path(run_dir, "hyp_reg_11_1_state_diagnostics.csv")); write_csv(causality, file.path(run_dir, "hyp_reg_11_1_causality_audit.csv")); write_csv(scale_audit, file.path(run_dir, "hyp_reg_11_1_scale_invariance.csv")); write_csv(stage_a_gates, file.path(run_dir, "hyp_reg_11_1_stage_a_gates.csv"))

ink <- "#17202A"; blue <- "#3D8DFF"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#8A949E"; pale <- "#DCEBFA"; purple <- "#8666B8"
png_open <- function(name, width = 1800, height = 1000) grDevices::png(file.path(visual_dir, name), width = width, height = height, res = 160)

png_open("synthetic_calibration.png", 2100, 1100); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
barplot(100 * null_rates$false_alarm_probability, names.arg = gsub("_NULL", "", null_rates$process), col = c(blue, purple, orange), border = NA, las = 2, ylim = c(0, max(25, 110 * max(null_rates$false_alarm_probability))), ylab = "Alarm probability over 504 sessions (%)", main = sprintf("Null calibration selected h = %.2f", threshold)); abline(h = 20, lty = 2, col = red)
ord <- c("NEGATIVE_SHIFT_030", "SINGLE_POSITIVE_JUMP", "POSITIVE_SHIFT_015", "POSITIVE_SHIFT_030"); ss <- shift_summary[match(ord, shift_summary$process), ]; barplot(100 * ss$detection_probability_60, names.arg = c("−0.30 shift", "+5σ jump", "+0.15 shift", "+0.30 shift"), col = c(red, gray, pale, green), border = NA, las = 2, ylim = c(0, 100), ylab = "Alarm within 60 sessions (%)", main = "Detection power and falsification"); abline(h = 70, lty = 2, col = green); abline(h = 20, lty = 3, col = red); dev.off()

png_open("real_alarm_usability.png", 2000, 1100); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
barplot(primary_diag$alarms, names.arg = primary_diag$symbol, col = blue, border = NA, las = 2, ylab = "Positive alarms, 2018–2023", main = "Event count across primary stocks"); abline(h = 3, lty = 2, col = red)
barplot(100 * primary_diag$eligible_fraction, names.arg = primary_diag$symbol, col = green, border = NA, las = 2, ylab = "Sessions eligible (%)", main = "Fixed 10-session post-alarm occupancy"); abline(h = c(1, 25), lty = 2, col = red); dev.off()

png_open("representative_measurement_tapes.png", 2200, 2100); layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
for (symbol in c("AMD", "TSLA", "TXN", "SPY")) {
  z <- analysis[analysis$symbol == symbol, , drop = FALSE]
  plot(z$session_date, z$close, type = "n", xlab = "", ylab = "Adjusted close", main = paste(symbol, "price and positive-onset windows")); usr <- par("usr")
  runs <- rle(z$recent_positive_onset_eligible); ends <- cumsum(runs$lengths); starts <- c(1L, head(ends, -1L) + 1L)
  for (j in which(runs$values)) rect(z$session_date[starts[[j]]], usr[[3L]], z$session_date[ends[[j]]] + 1, usr[[4L]], col = adjustcolor("#A7D7B8", .55), border = NA)
  lines(z$session_date, z$close, col = ink, lwd = 1.3); points(z$session_date[z$positive_alarm], z$close[z$positive_alarm], pch = 24, bg = red, col = red, cex = .8)
  plot(z$session_date, z$cusum_score, type = "l", col = blue, lwd = 1.2, xlab = "Session", ylab = "CUSUM score", main = "Accumulated positive evidence"); abline(h = threshold, col = red, lty = 2); points(z$session_date[z$positive_alarm], rep(threshold, sum(z$positive_alarm)), pch = 24, bg = red, col = red, cex = .8)
}
dev.off()

stage_a_status <- if (stage_a_passed) "PASS_STAGE_A_CONSTRUCTION" else "STOP_CAUSAL_CHANGE_POINT_STAGE_A_FAILED_STRATEGY_NOT_RUN"
run_spec <- data.frame(hypothesis_id = contract$hypothesis_id, status = stage_a_status, evidence_stage = contract$evidence_stage, as_of_timestamp = contract$as_of_timestamp,
  analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, confirmation_start = contract$confirmation_start, volatility_window = contract$volatility_window,
  clip_z = contract$clip_z, target_shift = contract$target_shift, reference_k = contract$reference_k, calibrated_threshold = threshold, false_alarm_budget = contract$false_alarm_budget,
  refractory_sessions = contract$refractory_sessions, eligibility_sessions = contract$eligibility_sessions, confirmation_2024_plus = "SEALED", stringsAsFactors = FALSE)
write_csv(run_spec, file.path(run_dir, "hyp_reg_11_1_run_spec.csv"))

if (!stage_a_passed) {
  report <- c("# HYP-REG-11.1 Causal Positive Change-Point", "", paste0("Status: `", stage_a_status, "`"), "", "## Frozen Question", "", "Can a causally calibrated positive CUSUM onset event improve fresh next-open entries in the unchanged daily SMA8/SMA14 parent?", "", "## Synthetic Calibration", "", sprintf("The frozen null budget selected h = %.2f. The worst 504-session null alarm probability was %.1f%%.", threshold, 100 * max(null_rates$false_alarm_probability)), sprintf("A sustained +0.30 standardized mean shift was detected within 60 sessions on %.1f%% of paths, with %.1f-session median delay among timely detections. The frozen gate required at least 70%% and delay no greater than 40.", 100 * strong$detection_probability_60, strong$median_detection_delay), "", "## Decision", "", sprintf("Stage A passed %d/%d gates. Strategy outcomes were not accessed. The detector is too insensitive at its frozen false-alarm budget to justify using its events as an SMA entry gate.", sum(stage_a_gates$passed), nrow(stage_a_gates)), "", "## Boundary", "", "This is reused-window development evidence. No real strategy performance, ATR join, threshold rescue, or 2024+ confirmation was accessed.")
  writeLines(report, file.path(run_dir, "hyp_reg_11_1_report.md")); writeLines(stage_a_status, file.path(run_dir, "STATUS.txt")); message(stage_a_status); print(stage_a_gates, row.names = FALSE); quit(save = "no", status = 0L)
}

message("HYP-REG-11.1 Stage A passed; entering the frozen SMA8/14 strategy-relative replay.")
prior_daily_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_01_2_strategy_overlay_20260814", "hyp_reg_01_2_reconstructed_daily.rds")
parent_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "intraday_momentum_poc_series_20260813", "fixed_sma_summaries.csv")
if (!file.exists(prior_daily_path) || !file.exists(parent_path)) hreg111_stop("Retained daily parent evidence is unavailable.")
daily <- readRDS(prior_daily_path); daily$session_date <- as.Date(daily$session_date); daily <- daily[daily$session_date < contract$confirmation_start & daily$symbol %in% registry$symbol, , drop = FALSE]
states <- hreg111_validate_ledger(ledger, contract)
scenario_table <- data.frame(scenario = c("PRIMARY", "STRESS"), bps = c(contract$primary_bps, contract$stress_bps))
summaries <- list(); trades <- list(); aligned_by_symbol <- list(); k <- 0L; tk <- 0L
for (symbol in registry$symbol) {
  x <- daily[daily$symbol == symbol, , drop = FALSE]; x <- x[order(x$session_date), , drop = FALSE]
  frame <- hreg111_align(hreg12_cross_frame(x, contract$fast, contract$slow), states[states$symbol == symbol, , drop = FALSE]); aligned_by_symbol[[symbol]] <- frame; reg <- registry[match(symbol, registry$symbol), , drop = FALSE]
  for (year in contract$years) {
    start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start); end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end)
    schedules <- lapply(contract$policies, function(p) hreg111_schedule(frame, start, end, p)); names(schedules) <- contract$policies
    schedules$BUY_HOLD <- imom_buy_hold_schedule(x, start, end); schedules$CASH <- schedules$UNFILTERED; schedules$CASH$target <- FALSE; schedules$CASH$entry_signal <- FALSE; schedules$CASH$exit_signal <- FALSE
    block_frame <- frame[frame$session_date >= start & frame$session_date <= end, , drop = FALSE]
    for (policy in names(schedules)) for (si in seq_len(nrow(scenario_table))) {
      scenario <- scenario_table[si, , drop = FALSE]; replay <- imom_replay(x, start, end, schedules[[policy]], 1, scenario$bps, 0, scenario$scenario, 252L, imom)
      q <- replay$summary; q$policy <- policy; q$year <- year; q$sector <- reg$sector; q$asset_type <- reg$asset_type; q$strategy_role <- reg$strategy_role; k <- k + 1L; summaries[[k]] <- q
      if (scenario$scenario == "PRIMARY" && policy %in% contract$policies) { t <- hreg111_label_trades(replay$trades, block_frame); if (nrow(t)) { t$policy <- policy; t$year <- year; tk <- tk + 1L; trades[[tk]] <- t } }
    }
  }
}
summaries <- do.call(rbind, summaries); trades <- if (length(trades)) do.call(rbind, trades) else data.frame()
primary <- summaries[summaries$strategy_role == "primary_stock" & summaries$scenario == "PRIMARY", , drop = FALSE]
policy_panel <- hreg111_policy_panel(primary); paired <- merge(primary[primary$policy == "UNFILTERED", c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure")], primary[primary$policy == "ENTRY_RECENT_POSITIVE_ONSET_ONLY", c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure")], by = c("symbol", "year"), suffixes = c("_parent", "_overlay")); paired$return_excess <- paired$total_return_overlay - paired$total_return_parent
asset_compound <- hreg111_compound_by_asset(primary[primary$policy %in% contract$policies, ]); asset_wide <- merge(asset_compound[asset_compound$policy == "UNFILTERED", c("symbol", "compounded_return")], asset_compound[asset_compound$policy == "ENTRY_RECENT_POSITIVE_ONSET_ONLY", c("symbol", "compounded_return")], by = "symbol", suffixes = c("_parent", "_overlay")); asset_wide$compounded_excess <- asset_wide$compounded_return_overlay - asset_wide$compounded_return_parent
year_summary <- aggregate(return_excess ~ year, paired, stats::median); names(year_summary)[[2L]] <- "median_excess"
reproduction <- data.frame(symbol = character(), year = integer(), absolute_difference = numeric(), passed = logical())
retained_parent <- utils::read.csv(parent_path, stringsAsFactors = FALSE); retained_parent <- retained_parent[retained_parent$timeframe == "DAILY" & retained_parent$policy == "SMA_8_14" & retained_parent$scenario == "PRIMARY" & retained_parent$leverage == 1 & retained_parent$symbol %in% registry$symbol & retained_parent$year %in% contract$years, ]
ours_parent <- primary[primary$policy == "UNFILTERED", c("symbol", "year", "total_return")]; reproduction <- merge(ours_parent, retained_parent[c("symbol", "year", "total_return")], by = c("symbol", "year"), suffixes = c("_ours", "_retained")); reproduction$absolute_difference <- abs(reproduction$total_return_ours - reproduction$total_return_retained); reproduction$passed <- reproduction$absolute_difference <= contract$reproduction_tolerance

control_cache <- file.path(run_dir, "hyp_reg_11_1_controls.csv")
controls <- list(); ck <- 0L
for (simulation_id in seq_len(contract$placebo_simulations)) for (symbol in stocks) {
  x <- daily[daily$symbol == symbol, , drop = FALSE]; frame <- aligned_by_symbol[[symbol]]
  for (year in contract$years) { start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start); end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end); schedule <- hreg111_shifted_schedule(frame, start, end, simulation_id, contract); replay <- imom_replay(x, start, end, schedule, 1, contract$primary_bps, 0, "PRIMARY", 252L, imom); q <- replay$summary; q$simulation_id <- simulation_id; ck <- ck + 1L; controls[[ck]] <- q }
}
controls <- do.call(rbind, controls); control_panel <- aggregate(cbind(total_return, maximum_drawdown, sharpe, exposure) ~ simulation_id, controls, stats::median); names(control_panel)[2:5] <- c("median_return", "median_drawdown", "median_sharpe", "median_exposure")
parent_row <- policy_panel[policy_panel$policy == "UNFILTERED", ]; actual <- policy_panel[policy_panel$policy == "ENTRY_RECENT_POSITIVE_ONSET_ONLY", ]
near_ids <- hreg111_exposure_near_ids(control_panel, actual$median_exposure, contract$exposure_near_count); near <- control_panel[control_panel$simulation_id %in% near_ids, ]; timing_percentile <- hreg111_midrank_percentile(actual$median_return, near$median_return); timing_excess <- actual$median_return - stats::median(near$median_return)
strategy_gates <- data.frame(gate = c("G1_CAUSAL_DATA", "G2_PARENT_REPRODUCTION", "G3_CONSTRUCTION", "G4_RETURN_ABOVE_PARENT", "G5_ASSET_BREADTH", "G6_YEAR_BREADTH", "G7_DRAWDOWN_AND_SHARPE", "G8_POSITIVE_RETURN", "G9_TIMING_CONTROLS"),
  passed = c(!any(daily$session_date >= contract$confirmation_start), all(reproduction$passed), all(stage_a_gates$passed), actual$median_return > parent_row$median_return, sum(asset_wide$compounded_excess > 0) >= 15L, sum(year_summary$median_excess > 0) >= 4L, actual$median_drawdown >= parent_row$median_drawdown && actual$median_sharpe >= parent_row$median_sharpe, actual$median_return > 0, timing_percentile >= .80 && timing_excess > 0), stringsAsFactors = FALSE)
status <- if (all(strategy_gates$passed)) "PASS_TO_CONFIRMATION_DISCUSSION" else "STOP_CAUSAL_CHANGE_POINT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN"
write_csv(summaries, file.path(run_dir, "hyp_reg_11_1_summaries.csv")); write_csv(trades, file.path(run_dir, "hyp_reg_11_1_trades.csv")); write_csv(policy_panel, file.path(run_dir, "hyp_reg_11_1_policy_panel.csv")); write_csv(paired, file.path(run_dir, "hyp_reg_11_1_paired_cells.csv")); write_csv(asset_wide, file.path(run_dir, "hyp_reg_11_1_asset_summary.csv")); write_csv(year_summary, file.path(run_dir, "hyp_reg_11_1_year_summary.csv")); write_csv(reproduction, file.path(run_dir, "hyp_reg_11_1_parent_reproduction.csv")); write_csv(controls, control_cache); write_csv(control_panel, file.path(run_dir, "hyp_reg_11_1_control_panel.csv")); write_csv(strategy_gates, file.path(run_dir, "hyp_reg_11_1_strategy_gates.csv"))
writeLines(c("# HYP-REG-11.1 Causal Positive Change-Point", "", paste0("Status: `", status, "`"), "", sprintf("Stage A passed. The entry overlay passed %d/%d strategy gates; parent median return %s, overlay %s, timing percentile %.1f.", sum(strategy_gates$passed), nrow(strategy_gates), fmt_pct(parent_row$median_return), fmt_pct(actual$median_return), 100 * timing_percentile)), file.path(run_dir, "hyp_reg_11_1_report.md")); writeLines(status, file.path(run_dir, "STATUS.txt")); message(status); print(stage_a_gates, row.names = FALSE); print(strategy_gates, row.names = FALSE)
