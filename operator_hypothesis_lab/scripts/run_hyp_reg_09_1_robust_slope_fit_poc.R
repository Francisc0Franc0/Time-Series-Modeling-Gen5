options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_09_1_robust_slope_fit_poc.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
mean_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
fmt_pct <- function(x, digits = 2L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))

contract <- hreg91_contract(); imom <- imom_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_09_1_robust_slope_fit_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
if (nrow(registry) != 26L || anyDuplicated(registry$symbol) || sum(registry$strategy_role == "primary_stock") != 24L) hreg91_stop("Frozen registry integrity failed.")
stocks <- registry$symbol[registry$strategy_role == "primary_stock"]

run_id <- env_or("GEN5_HYP_REG_091_RUN_ID", "hyp_reg_09_1_robust_slope_fit_20260816")
run_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(run_dir, "visuals"); dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root); refresh <- env_bool("GEN5_HYP_REG_091_REFRESH", FALSE)
message("HYP-REG-09.1 loading the frozen daily measurement surface.")
query <- g5_workbench_query_adjusted_daily_bars(cfg = cfg, start_date = contract$query_start, end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = registry$symbol, universe_name = "hyp_reg_09_1_robust_slope_fit_panel",
  universe_roles = "theil_sen_60_primary,theil_sen_120_durability,development_reused_window", refresh = refresh, repo_root = repo_root)
bars <- hreg91_assert_bars(query$bars, contract)
reference_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars[bars$symbol == reg$symbol, , drop = FALSE]; dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start); missing <- length(setdiff(reference_dates, dates))
  cbind(reg, data.frame(total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates), missing_reference_sessions = missing,
    coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < contract$minimum_prehistory) "PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else "COMPLETE", stringsAsFactors = FALSE))
}))
if (any(coverage$coverage_status != "COMPLETE")) { print(coverage[coverage$coverage_status != "COMPLETE", ], row.names = FALSE); hreg91_stop("One or more assets lack frozen measurement coverage.") }

ledger_cache <- file.path(run_dir, "hyp_reg_09_1_ledger.csv")
if (file.exists(ledger_cache) && !env_bool("GEN5_HYP_REG_091_REBUILD_MEASUREMENT", FALSE)) {
  message("HYP-REG-09.1 using the retained robust-slope ledger.")
  ledger <- utils::read.csv(ledger_cache, stringsAsFactors = FALSE); ledger$session_date <- as.Date(ledger$session_date)
  ledger$quality_state60 <- trimws(as.character(ledger$quality_state60)); ledger$quality_state60[ledger$quality_state60 == ""] <- NA_character_; ledger$orderly_up_eligible <- as.logical(ledger$orderly_up_eligible)
} else {
  message("HYP-REG-09.1 building rolling 60/120-session robust slope and fit measurements.")
  ledger <- hreg91_build_ledger(bars, contract)
}
analysis <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
if (any(analysis$session_date >= contract$confirmation_start) || length(unique(analysis$symbol)) != 26L) hreg91_stop("Measurement boundary integrity failed.")
state_diagnostics <- hreg91_state_diagnostics(ledger, contract)

synthetic_cache <- file.path(run_dir, "hyp_reg_09_1_synthetic_summary.csv")
if (file.exists(synthetic_cache) && !env_bool("GEN5_HYP_REG_091_REBUILD_MEASUREMENT", FALSE)) {
  message("HYP-REG-09.1 using retained seeded synthetic calibration."); synthetic_summary <- utils::read.csv(synthetic_cache, stringsAsFactors = FALSE)
} else {
  message("HYP-REG-09.1 calibrating five seeded synthetic path families."); synthetic_summary <- hreg91_synthetic_summary(hreg91_synthetic_calibration(contract))
}
scale_audit <- hreg91_scale_invariance_audit(contract); causality <- hreg91_causality_audit(contract)
syn <- function(kind) synthetic_summary[synthetic_summary$process == kind, , drop = FALSE]
clean_up <- syn("CLEAN_UP"); clean_down <- syn("CLEAN_DOWN"); noisy_up <- syn("NOISY_UP"); random_walk <- syn("RANDOM_WALK"); reversal <- syn("REVERSAL")
primary_diag <- state_diagnostics[state_diagnostics$symbol %in% stocks, , drop = FALSE]
usable_states <- sum(primary_diag$low_fraction >= .05 & primary_diag$high_fraction >= .05); usable_eligibility <- sum(primary_diag$eligible_fraction >= .03)
state_semantics <- all(analysis$quality_percentile60[analysis$quality_state60 == "HIGH_QUALITY"] >= contract$high_exit, na.rm = TRUE) &&
  all(analysis$quality_percentile60[analysis$quality_state60 == "LOW_QUALITY"] <= contract$low_exit, na.rm = TRUE) &&
  all(analysis$normalized_strength60[analysis$orderly_up_eligible %in% TRUE] > 0, na.rm = TRUE) && all(analysis$quality_state60[analysis$orderly_up_eligible %in% TRUE] == "HIGH_QUALITY", na.rm = TRUE)
stage_a_gates <- data.frame(
  gate = c("A1_DATA_AND_BOUNDARY", "A2_DIRECTION_CALIBRATION", "A3_PATH_QUALITY_ORDERING", "A4_VOLATILITY_SCALE_INVARIANCE", "A5_CAUSAL_APPEND_INVARIANCE", "A6_STATE_SEMANTICS", "A7_STATE_AND_POLICY_USABILITY"),
  threshold = c(">=372 prehistory; complete 26-asset analysis; 2024+ absent", "clean-up positive >=95%; clean-down positive <=5%",
    "clean paths quality >=.98 and exceed noisy-up by >=.15, random walk by >=.25, reversal by >=.75", "normalized strength and quality invariant within 1e-10",
    "all previously calculated rolling values exactly unchanged after future append", "HIGH remains >=60th; LOW remains <=40th; eligible means positive slope and HIGH",
    ">=20/24 stocks have >=5% HIGH and LOW; >=20/24 have >=3% eligible sessions"),
  observed = c(
    sprintf("%d/26 complete; min %d prehistory; first finite state %s", sum(coverage$coverage_status == "COMPLETE"), min(coverage$prehistory_sessions), min(analysis$session_date[!is.na(analysis$quality_state60)])),
    sprintf("clean-up %.1f%% positive; clean-down %.1f%% positive", 100 * clean_up$positive_slope_fraction, 100 * clean_down$positive_slope_fraction),
    sprintf("quality up %.3f / down %.3f / noisy %.3f / RW %.3f / reversal %.3f", clean_up$median_path_quality, clean_down$median_path_quality, noisy_up$median_path_quality, random_walk$median_path_quality, reversal$median_path_quality),
    sprintf("max difference %.3g", max(scale_audit$absolute_difference)), sprintf("max difference %.3g", max(causality$maximum_append_difference)),
    sprintf("semantic violations %d", sum(analysis$orderly_up_eligible %in% TRUE & (analysis$normalized_strength60 <= 0 | analysis$quality_state60 != "HIGH_QUALITY"), na.rm = TRUE)),
    sprintf("%d/24 state-usable; %d/24 eligibility-usable; median eligible %.1f%%", usable_states, usable_eligibility, 100 * median(primary_diag$eligible_fraction))
  ),
  passed = c(
    all(coverage$coverage_status == "COMPLETE") && !any(analysis$session_date >= contract$confirmation_start),
    clean_up$positive_slope_fraction >= .95 && clean_down$positive_slope_fraction <= .05,
    min(clean_up$median_path_quality, clean_down$median_path_quality) >= .98 && clean_up$median_path_quality - noisy_up$median_path_quality >= .15 && clean_up$median_path_quality - random_walk$median_path_quality >= .25 && clean_up$median_path_quality - reversal$median_path_quality >= .75,
    max(scale_audit$absolute_difference) <= 1e-10, all(causality$passed), state_semantics, usable_states >= 20L && usable_eligibility >= 20L
  ), stringsAsFactors = FALSE
)
stage_a_passed <- all(stage_a_gates$passed)

write_csv(registry, file.path(run_dir, "hyp_reg_09_1_registry.csv")); write_csv(coverage, file.path(run_dir, "hyp_reg_09_1_coverage.csv")); write_csv(ledger, ledger_cache)
write_csv(state_diagnostics, file.path(run_dir, "hyp_reg_09_1_state_diagnostics.csv")); write_csv(synthetic_summary, synthetic_cache)
write_csv(scale_audit, file.path(run_dir, "hyp_reg_09_1_scale_invariance.csv")); write_csv(causality, file.path(run_dir, "hyp_reg_09_1_causality_audit.csv")); write_csv(stage_a_gates, file.path(run_dir, "hyp_reg_09_1_stage_a_gates.csv"))

ink <- "#17202A"; blue <- "#3D8DFF"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#8A949E"; pale <- "#DCEBFA"
png_open <- function(name, width = 1800, height = 1000) grDevices::png(file.path(visual_dir, name), width = width, height = height, res = 160)

png_open("synthetic_calibration.png")
par(mfrow = c(1, 2), mar = c(7, 5, 4, 1)); ordered <- c("CLEAN_DOWN", "RANDOM_WALK", "NOISY_UP", "CLEAN_UP", "REVERSAL")
vals <- synthetic_summary$median_normalized_strength[match(ordered, synthetic_summary$process)]
barplot(vals, names.arg = c("Clean down", "Random walk", "Noisy up", "Clean up", "Reversal"), col = c(red, gray, pale, green, orange), border = NA, las = 2, ylab = "Median normalized strength", main = "Direction and strength"); abline(h = 0, lty = 2)
quality <- synthetic_summary$median_path_quality[match(ordered, synthetic_summary$process)]
barplot(quality, names.arg = c("Clean down", "Random walk", "Noisy up", "Clean up", "Reversal"), col = c(red, gray, pale, green, orange), border = NA, las = 2, ylim = c(0, 1), ylab = "Median |Spearman(time, log price)|", main = "Path quality")
dev.off()

png_open("state_usability.png")
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1)); occupancy <- rbind(primary_diag$low_fraction, primary_diag$medium_fraction, primary_diag$high_fraction)
barplot(100 * occupancy, names.arg = primary_diag$symbol, col = c(pale, gray, orange), border = NA, las = 2, ylab = "Analysis sessions (%)", main = "Quality-state occupancy", legend.text = c("LOW", "MEDIUM", "HIGH"), args.legend = list(x = "topright", bty = "n"))
barplot(100 * primary_diag$eligible_fraction, names.arg = primary_diag$symbol, col = blue, border = NA, las = 2, ylab = "Analysis sessions (%)", main = "Positive-slope HIGH-quality eligibility")
dev.off()

png_open("durability.png")
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1)); barplot(100 * primary_diag$sign_agreement_60_120, names.arg = primary_diag$symbol, col = blue, border = NA, las = 2, ylab = "Agreement (%)", main = "60/120 direction agreement")
barplot(primary_diag$quality_correlation_60_120, names.arg = primary_diag$symbol, col = ifelse(primary_diag$quality_correlation_60_120 >= 0, green, red), border = NA, las = 2, ylab = "Spearman correlation", main = "60/120 quality association"); abline(h = 0, lty = 2)
dev.off()

png_open("representative_measurement_tapes.png", 2200, 2100); layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
state_cols <- c(LOW_QUALITY = "#D0EDFA", MEDIUM_QUALITY = "#E6E6E6", HIGH_QUALITY = "#F6C48D")
for (symbol in c("AMD", "TSLA", "TXN", "SPY")) {
  z <- analysis[analysis$symbol == symbol & !is.na(analysis$quality_state60), , drop = FALSE]; groups <- cumsum(c(TRUE, z$quality_state60[-1L] != head(z$quality_state60, -1L)))
  plot(z$session_date, z$close, type = "n", xlab = "", ylab = "Adjusted close", main = paste(symbol, "price and quality state")); usr <- par("usr")
  for (g in unique(groups)) { q <- z[groups == g, ]; rect(min(q$session_date), usr[[3L]], max(q$session_date) + 1, usr[[4L]], col = adjustcolor(state_cols[[q$quality_state60[[1L]]]], .55), border = NA) }
  lines(z$session_date, z$close, col = ink, lwd = 1.3)
  plot(z$session_date, z$normalized_strength60, type = "l", col = blue, lwd = 1.1, xlab = "Session", ylab = "Normalized strength", main = "60-session direction and strength"); abline(h = 0, lty = 2); par(new = TRUE); plot(z$session_date, z$path_quality60, type = "l", col = orange, axes = FALSE, xlab = "", ylab = "", ylim = c(0, 1)); axis(4); mtext("Path quality", side = 4, line = 3)
}
dev.off()

stage_a_status <- if (stage_a_passed) "PASS_STAGE_A_CONSTRUCTION" else "STOP_ROBUST_SLOPE_FIT_STAGE_A_FAILED_STAGE_B_NOT_RUN"
if (!stage_a_passed) {
  write_csv(data.frame(hypothesis_id = contract$hypothesis_id, status = stage_a_status, evidence_stage = contract$evidence_stage, as_of_timestamp = contract$as_of_timestamp,
    analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, confirmation_start = contract$confirmation_start, primary_window = contract$primary_window,
    durability_window = contract$durability_window, percentile_lookback = contract$percentile_lookback, confirmation_2024_plus = "SEALED", stringsAsFactors = FALSE), file.path(run_dir, "hyp_reg_09_1_run_spec.csv"))
  writeLines(c("# HYP-REG-09.1 Robust Slope and Fit", "", paste0("Status: `", stage_a_status, "`"), "", "Stage A did not pass its frozen construction gates. Strategy outcomes were not accessed."), file.path(run_dir, "hyp_reg_09_1_report.md"))
  writeLines(stage_a_status, file.path(run_dir, "STATUS.txt")); message(stage_a_status); print(stage_a_gates, row.names = FALSE); quit(save = "no", status = 0L)
}

message("HYP-REG-09.1 Stage A passed; entering the frozen SMA8/14 strategy-relative replay.")
prior_daily_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_01_2_strategy_overlay_20260814", "hyp_reg_01_2_reconstructed_daily.rds")
parent_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "intraday_momentum_poc_series_20260813", "fixed_sma_summaries.csv")
if (!file.exists(prior_daily_path) || !file.exists(parent_path)) hreg91_stop("Retained daily parent evidence is unavailable.")
daily <- readRDS(prior_daily_path); daily$session_date <- as.Date(daily$session_date); daily <- daily[daily$session_date < contract$confirmation_start & daily$symbol %in% registry$symbol, , drop = FALSE]
states <- hreg91_validate_state_ledger(ledger, contract)
strategy_coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- daily[daily$symbol == reg$symbol & daily$session_date >= contract$analysis_start & daily$session_date <= contract$analysis_end, , drop = FALSE]
  s <- states[states$symbol == reg$symbol & states$session_date >= contract$analysis_start & states$session_date <= contract$analysis_end, , drop = FALSE]; idx <- match(x$session_date, s$session_date)
  missing_state <- sum(is.na(idx) | is.na(s$quality_state60[idx])); missing_dates <- x$session_date[is.na(idx) | is.na(s$quality_state60[idx])]
  data.frame(instance_id = reg$instance_id, symbol = reg$symbol, strategy_sessions = nrow(x), state_sessions = nrow(s), missing_state_dates = length(setdiff(x$session_date, s$session_date)), state_only_dates = length(setdiff(s$session_date, x$session_date)), missing_states = missing_state,
    status = if (nrow(x) == 1499L && nrow(s) == 1509L && !length(setdiff(x$session_date, s$session_date)) && length(setdiff(s$session_date, x$session_date)) == 10L && missing_state == 0L && !length(missing_dates)) "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS" else "REVIEW", stringsAsFactors = FALSE)
}))
if (any(strategy_coverage$status != "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS")) hreg91_stop("Daily/slope-fit calendar alignment failed.")

scenario_table <- data.frame(scenario = c("PRIMARY", "STRESS"), bps = c(contract$primary_bps, contract$stress_bps), stringsAsFactors = FALSE)
summaries <- list(); trades <- list(); paths_all <- list(); aligned_by_symbol <- list(); k <- 0L; tk <- 0L; pk <- 0L
for (symbol in registry$symbol) {
  x <- daily[daily$symbol == symbol, , drop = FALSE]; x <- x[order(x$session_date), , drop = FALSE]
  frame <- hreg91_align(hreg12_cross_frame(x, contract$fast, contract$slow), states[states$symbol == symbol, , drop = FALSE]); aligned_by_symbol[[symbol]] <- frame
  reg <- registry[match(symbol, registry$symbol), , drop = FALSE]
  for (year in contract$years) {
    start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start); end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end)
    schedules <- lapply(contract$policies, function(p) hreg91_schedule(frame, start, end, p)); names(schedules) <- contract$policies
    schedules$BUY_HOLD <- imom_buy_hold_schedule(x, start, end); schedules$CASH <- schedules$UNFILTERED; schedules$CASH$target <- FALSE; schedules$CASH$entry_signal <- FALSE; schedules$CASH$exit_signal <- FALSE
    block_frame <- frame[frame$session_date >= start & frame$session_date <= end, , drop = FALSE]
    for (policy in names(schedules)) for (si in seq_len(nrow(scenario_table))) {
      scenario <- scenario_table[si, , drop = FALSE]; replay <- imom_replay(x, start, end, schedules[[policy]], 1, scenario$bps, 0, scenario$scenario, 252L, imom)
      q <- replay$summary; q$policy <- policy; q$year <- year; q$sector <- reg$sector; q$asset_type <- reg$asset_type; q$strategy_role <- reg$strategy_role; k <- k + 1L; summaries[[k]] <- q
      if (scenario$scenario == "PRIMARY" && policy %in% contract$policies) {
        t <- hreg91_label_trades(replay$trades, block_frame); if (nrow(t)) { t$policy <- policy; t$year <- year; t$sector <- reg$sector; t$strategy_role <- reg$strategy_role; tk <- tk + 1L; trades[[tk]] <- t }
        w <- replay$path; w$sma_fast <- block_frame$sma_fast; w$sma_slow <- block_frame$sma_slow; w$quality_state60 <- block_frame$quality_state60; w$normalized_strength60 <- block_frame$normalized_strength60; w$path_quality60 <- block_frame$path_quality60; w$orderly_up_eligible <- block_frame$orderly_up_eligible; w$blocked_entry <- schedules[[policy]]$blocked_entry
        w$policy <- policy; w$year <- year; w$sector <- reg$sector; w$strategy_role <- reg$strategy_role; pk <- pk + 1L; paths_all[[pk]] <- w
      }
    }
  }
}
summaries <- do.call(rbind, summaries); trades <- do.call(rbind, trades); paths_all <- do.call(rbind, paths_all)

parent <- utils::read.csv(parent_path, stringsAsFactors = FALSE); parent <- parent[parent$frequency == "DAILY" & parent$policy == "SMA8_14" & parent$scenario == "PRIMARY" & parent$delay_bars == 0 & parent$leverage == 1, c("symbol", "year", "total_return")]; names(parent)[[3L]] <- "parent_total_return"
reproduction <- merge(summaries[summaries$policy == "UNFILTERED" & summaries$scenario == "PRIMARY", c("symbol", "year", "total_return")], parent, by = c("symbol", "year"), all = TRUE)
reproduction$absolute_difference <- abs(reproduction$total_return - reproduction$parent_total_return); reproduction$passed <- is.finite(reproduction$absolute_difference) & reproduction$absolute_difference <= contract$reproduction_tolerance
if (!all(reproduction$passed)) hreg91_stop(sprintf("Parent reproduction failed; maximum difference %.12g.", max(reproduction$absolute_difference, na.rm = TRUE)))

message("HYP-REG-09.1 running 200 deterministic within-asset/year circular eligibility controls.")
control_cache <- file.path(run_dir, "hyp_reg_09_1_control_cells.csv")
if (file.exists(control_cache) && !env_bool("GEN5_HYP_REG_091_REBUILD_CONTROLS", FALSE)) { message("HYP-REG-09.1 using retained controls."); controls <- utils::read.csv(control_cache, stringsAsFactors = FALSE) } else {
  controls <- vector("list", length(stocks) * length(contract$years) * contract$placebo_simulations); ck <- 0L
  for (symbol in stocks) { x <- daily[daily$symbol == symbol, , drop = FALSE]; frame <- aligned_by_symbol[[symbol]]
    for (year in contract$years) { start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start); end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end); w <- x[x$session_date >= start & x$session_date <= end, , drop = FALSE]
      for (simulation_id in seq_len(contract$placebo_simulations)) { schedule <- hreg91_shifted_schedule(frame, start, end, simulation_id, contract); ck <- ck + 1L
        controls[[ck]] <- data.frame(symbol = symbol, year = year, simulation_id = simulation_id, shift_offset = attr(schedule, "shift_offset"), exposure = mean(schedule$target), blocked_entries = sum(schedule$blocked_entry), total_return = imom_fast_terminal_from_schedule(w, schedule, 1, contract$primary_bps, 0, imom), stringsAsFactors = FALSE) }
    }
  }
  controls <- do.call(rbind, controls); write_csv(controls, control_cache)
}
control_panel <- do.call(rbind, lapply(split(controls, controls$simulation_id), function(x) data.frame(simulation_id = x$simulation_id[[1L]], cells = nrow(x), median_return = median_na(x$total_return), median_exposure = median_na(x$exposure), positive_fraction = mean(x$total_return > 0), stringsAsFactors = FALSE)))

primary <- summaries[summaries$strategy_role == "primary_stock" & summaries$scenario == "PRIMARY", , drop = FALSE]
policy_panel <- hreg91_policy_panel(primary); policy_panel <- policy_panel[match(c("UNFILTERED", "ENTRY_ORDERLY_UP_ONLY", "BUY_HOLD", "CASH"), policy_panel$policy), , drop = FALSE]
parent_cells <- primary[primary$policy == "UNFILTERED", , drop = FALSE]; overlay_cells <- primary[primary$policy == "ENTRY_ORDERLY_UP_ONLY", , drop = FALSE]
paired <- merge(parent_cells[c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure", "turnover", "trade_count")], overlay_cells[c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure", "turnover", "trade_count")], by = c("symbol", "year"), suffixes = c("_parent", "_overlay"))
paired$return_excess <- paired$total_return_overlay - paired$total_return_parent; paired$drawdown_change <- paired$maximum_drawdown_overlay - paired$maximum_drawdown_parent; paired$sharpe_change <- paired$sharpe_overlay - paired$sharpe_parent
comp <- hreg91_compound_by_asset(primary[primary$policy %in% contract$policies, , drop = FALSE]); pcomp <- comp[comp$policy == "UNFILTERED", c("symbol", "compounded_return")]; names(pcomp)[[2L]] <- "parent_compounded_return"; ocomp <- comp[comp$policy == "ENTRY_ORDERLY_UP_ONLY", c("symbol", "compounded_return")]; names(ocomp)[[2L]] <- "overlay_compounded_return"
asset_summary <- merge(pcomp, ocomp, by = "symbol"); asset_summary$compounded_excess <- asset_summary$overlay_compounded_return - asset_summary$parent_compounded_return
year_summary <- do.call(rbind, lapply(split(paired, paired$year), function(x) data.frame(year = x$year[[1L]], cells = nrow(x), median_excess = median_na(x$return_excess), improvement_fraction = mean(x$return_excess > 0), median_drawdown_change = median_na(x$drawdown_change), median_sharpe_change = median_na(x$sharpe_change), stringsAsFactors = FALSE)))
actual <- policy_panel[policy_panel$policy == "ENTRY_ORDERLY_UP_ONLY", , drop = FALSE]; parent_row <- policy_panel[policy_panel$policy == "UNFILTERED", , drop = FALSE]
near_ids <- hreg91_exposure_near_ids(control_panel, actual$median_exposure, contract$exposure_near_count); control_panel$exposure_near <- control_panel$simulation_id %in% near_ids; near <- control_panel[control_panel$exposure_near, , drop = FALSE]
timing_percentile <- hreg91_midrank_percentile(actual$median_return, near$median_return); timing_excess <- actual$median_return - median_na(near$median_return)
placebo_readout <- data.frame(policy = "ENTRY_ORDERLY_UP_ONLY", actual_return = actual$median_return, actual_exposure = actual$median_exposure, percentile = timing_percentile, excess_vs_control_median = timing_excess, near_controls = nrow(near), stringsAsFactors = FALSE)

strategy_gates <- data.frame(
  gate = c("G1_CAUSAL_DATA_AND_CALENDAR", "G2_PARENT_REPRODUCTION", "G3_CONSTRUCTION_AND_SEMANTICS", "G4_PANEL_RETURN", "G5_ASSET_BREADTH", "G6_CALENDAR_BREADTH", "G7_PROTECTION_AND_SHARPE", "G8_ABSOLUTE_VIABILITY", "G9_TIMING_SPECIFICITY"),
  threshold = c("26/26 aligned; 24 primary stocks; 2024+ absent", "156/156 annual cells exact", "all frozen Stage A gates pass", "overlay median annual return > parent", ">=15/24 stocks improve over six years", ">=4/6 years have positive median excess", "median maximum drawdown no worse and median Sharpe no lower", "positive absolute median annual return", ">=80th percentile and above median of 40 exposure-nearest controls"),
  observed = c(sprintf("%d/26 complete; max date %s", sum(strategy_coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS"), max(daily$session_date)), sprintf("%d/%d; max difference %.3g", sum(reproduction$passed), nrow(reproduction), max(reproduction$absolute_difference)),
    sprintf("%d/%d Stage A gates", sum(stage_a_gates$passed), nrow(stage_a_gates)), sprintf("%s vs %s", fmt_pct(actual$median_return), fmt_pct(parent_row$median_return)), sprintf("%d/24 improved", sum(asset_summary$compounded_excess > 0)),
    sprintf("%d/6 positive years", sum(year_summary$median_excess > 0)), sprintf("drawdown %s; Sharpe %+.3f", fmt_pct(actual$median_drawdown - parent_row$median_drawdown), actual$median_sharpe - parent_row$median_sharpe), fmt_pct(actual$median_return), sprintf("%.1fth percentile; %s vs controls", 100 * timing_percentile, fmt_pct(timing_excess))),
  passed = c(all(strategy_coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS") && !any(daily$session_date >= contract$confirmation_start), all(reproduction$passed), all(stage_a_gates$passed), actual$median_return > parent_row$median_return,
    sum(asset_summary$compounded_excess > 0) >= 15L, sum(year_summary$median_excess > 0) >= 4L, actual$median_drawdown >= parent_row$median_drawdown && actual$median_sharpe >= parent_row$median_sharpe, actual$median_return > 0,
    is.finite(timing_percentile) && timing_percentile >= .80 && timing_excess > 0), stringsAsFactors = FALSE)
all_passed <- all(strategy_gates$passed); status <- if (all_passed) "PASS_TO_CONFIRMATION_DISCUSSION" else "STOP_ROBUST_SLOPE_FIT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN"
decision <- data.frame(policy = "ENTRY_ORDERLY_UP_ONLY", gates_passed = sum(strategy_gates$passed), gates_total = nrow(strategy_gates), all_passed = all_passed, status = status, stringsAsFactors = FALSE)

parent_trades <- trades[trades$policy == "UNFILTERED" & trades$strategy_role == "primary_stock", , drop = FALSE]
parent_trades$entry_group <- ifelse(parent_trades$entry_eligible %in% TRUE, "ORDERLY_UP", ifelse(parent_trades$entry_strength > 0, "OTHER_UP", "NON_UP"))
entry_state_audit <- do.call(rbind, lapply(split(parent_trades, parent_trades$entry_group), function(x) data.frame(entry_group = x$entry_group[[1L]], trades = nrow(x), hit_rate = mean(x$net_return > 0), mean_trade = mean_na(x$net_return), median_trade = median_na(x$net_return), median_holding = median_na(x$holding_bars), median_entry_strength = median_na(x$entry_strength), median_entry_quality = median_na(x$entry_quality), stringsAsFactors = FALSE)))
entry_state_audit <- entry_state_audit[match(c("NON_UP", "OTHER_UP", "ORDERLY_UP"), entry_state_audit$entry_group), , drop = FALSE]

write_csv(strategy_coverage, file.path(run_dir, "hyp_reg_09_1_strategy_coverage.csv")); write_csv(reproduction, file.path(run_dir, "hyp_reg_09_1_parent_reproduction.csv")); write_csv(summaries, file.path(run_dir, "hyp_reg_09_1_summaries.csv")); write_csv(trades, file.path(run_dir, "hyp_reg_09_1_trades.csv")); write_csv(policy_panel, file.path(run_dir, "hyp_reg_09_1_policy_panel.csv"))
write_csv(paired, file.path(run_dir, "hyp_reg_09_1_paired_cells.csv")); write_csv(asset_summary, file.path(run_dir, "hyp_reg_09_1_asset_summary.csv")); write_csv(year_summary, file.path(run_dir, "hyp_reg_09_1_year_summary.csv")); write_csv(entry_state_audit, file.path(run_dir, "hyp_reg_09_1_entry_state_audit.csv")); write_csv(controls, control_cache); write_csv(control_panel, file.path(run_dir, "hyp_reg_09_1_control_panel.csv"))
write_csv(placebo_readout, file.path(run_dir, "hyp_reg_09_1_placebo_readout.csv")); write_csv(strategy_gates, file.path(run_dir, "hyp_reg_09_1_strategy_gates.csv")); write_csv(decision, file.path(run_dir, "hyp_reg_09_1_decision.csv"))
write_csv(data.frame(hypothesis_id = contract$hypothesis_id, status = status, evidence_stage = contract$evidence_stage, as_of_timestamp = contract$as_of_timestamp, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, confirmation_start = contract$confirmation_start,
  primary_window = contract$primary_window, durability_window = contract$durability_window, percentile_lookback = contract$percentile_lookback, primary_bps = contract$primary_bps, stress_bps = contract$stress_bps, leverage = 1, confirmation_2024_plus = "SEALED", stringsAsFactors = FALSE), file.path(run_dir, "hyp_reg_09_1_run_spec.csv"))

plot_primary <- primary[primary$policy %in% c("UNFILTERED", "ENTRY_ORDERLY_UP_ONLY", "BUY_HOLD"), , drop = FALSE]; plot_primary$policy <- factor(plot_primary$policy, levels = c("UNFILTERED", "ENTRY_ORDERLY_UP_ONLY", "BUY_HOLD"))
png_open("policy_performance.png"); par(mfrow = c(1, 2), mar = c(7, 5, 4, 1))
boxplot(total_return * 100 ~ policy, data = plot_primary, col = c(gray, blue, orange), border = ink, outline = FALSE, xlab = "", ylab = "Annual return (%)", xaxt = "n", main = "Return after 5 bp per side"); axis(1, at = 1:3, labels = c("Parent", "Orderly-up entry", "Buy & hold"), las = 2); abline(h = 0, lty = 2)
boxplot(maximum_drawdown * 100 ~ policy, data = plot_primary, col = c(gray, blue, orange), border = ink, outline = FALSE, xlab = "", ylab = "Maximum drawdown (%)", xaxt = "n", main = "Protection bargain"); axis(1, at = 1:3, labels = c("Parent", "Orderly-up entry", "Buy & hold"), las = 2); dev.off()

png_open("policy_mechanics.png"); par(mfrow = c(2, 2), mar = c(6, 5, 4, 1))
for (metric in c("median_return", "median_sharpe", "median_exposure", "median_turnover")) { values <- policy_panel[[metric]][match(c("UNFILTERED", "ENTRY_ORDERLY_UP_ONLY"), policy_panel$policy)]; if (metric %in% c("median_return", "median_exposure")) values <- 100 * values
  barplot(values, names.arg = c("Parent", "Orderly-up"), col = c(gray, blue), border = NA, ylab = gsub("_", " ", metric), main = gsub("_", " ", metric)); abline(h = 0, col = ink) }
dev.off()

png_open("asset_breadth.png", 1600, 1200); z <- asset_summary[order(asset_summary$compounded_excess), ]
barplot(z$compounded_excess * 100, names.arg = z$symbol, horiz = TRUE, las = 1, col = ifelse(z$compounded_excess > 0, green, red), border = NA, xlab = "Orderly-up overlay minus parent six-year return (pp)", main = "Transport across 24 stocks"); abline(v = 0, col = ink, lwd = 1.5); dev.off()

png_open("calendar_and_controls.png"); par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
barplot(year_summary$median_excess * 100, names.arg = year_summary$year, col = ifelse(year_summary$median_excess > 0, green, red), border = NA, ylab = "Median excess (pp)", main = "Calendar breadth"); abline(h = 0, col = ink)
hist(near$median_return * 100, breaks = 12, col = pale, border = "white", xlab = "Panel median annual return (%)", main = "Exposure-nearest timing controls"); abline(v = 100 * actual$median_return, col = blue, lwd = 3); legend("topright", sprintf("Actual %.2f%%\nPercentile %.1f", 100 * actual$median_return, 100 * timing_percentile), bty = "n"); dev.off()

png_open("entry_state_audit.png"); par(mfrow = c(1, 2), mar = c(6, 5, 4, 1)); groups <- c("NON_UP", "OTHER_UP", "ORDERLY_UP")
boxplot(net_return * 100 ~ factor(entry_group, levels = groups), data = parent_trades, col = c(pale, gray, orange), border = ink, outline = FALSE, xlab = "60-session state at parent entry", ylab = "Parent trade return (%)", main = "What the hard gate selects", las = 2); abline(h = 0, lty = 2)
barplot(entry_state_audit$trades, names.arg = entry_state_audit$entry_group, col = c(pale, gray, orange), border = NA, ylab = "Parent trades", main = "Opportunity count", las = 2); dev.off()

best <- paired[which.max(paired$return_excess), c("symbol", "year")]; worst <- paired[which.min(paired$return_excess), c("symbol", "year")]; ordered_near <- paired[order(abs(paired$return_excess - median(paired$return_excess))), c("symbol", "year")]; canonical <- paired[paired$symbol == "AMD", c("symbol", "year")][1L, , drop = FALSE]
selected <- unique(rbind(data.frame(best, role = "LARGEST_IMPROVEMENT"), data.frame(worst, role = "LARGEST_DEGRADATION"), data.frame(ordered_near[1L, ], role = "NEAR_MEDIAN"), data.frame(canonical, role = "CANONICAL_AMD"))); write_csv(selected, file.path(run_dir, "hyp_reg_09_1_representative_selection.csv"))
png_open("representative_strategy_tapes.png", 2200, 2200); layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
for (i in seq_len(nrow(selected))) { pick <- selected[i, ]; u <- paths_all[paths_all$symbol == pick$symbol & paths_all$year == pick$year & paths_all$policy == "UNFILTERED", , drop = FALSE]; o <- paths_all[paths_all$symbol == pick$symbol & paths_all$year == pick$year & paths_all$policy == "ENTRY_ORDERLY_UP_ONLY", , drop = FALSE]
  display_state <- o$quality_state60; display_state[is.na(display_state)] <- "MEDIUM_QUALITY"; groups_run <- cumsum(c(TRUE, display_state[-1L] != head(display_state, -1L)))
  plot(o$session_date, o$close, type = "n", xlab = "", ylab = "Close", main = paste(pick$role, "-", pick$symbol, pick$year)); usr <- par("usr")
  for (g in unique(groups_run)) { q <- o[groups_run == g, ]; state <- display_state[which(groups_run == g)[[1L]]]; rect(min(q$session_date), usr[[3L]], max(q$session_date) + 1, usr[[4L]], col = adjustcolor(state_cols[[state]], .55), border = NA) }
  lines(o$session_date, o$close, col = ink, lwd = 1.3); lines(o$session_date, o$sma_fast, col = blue); lines(o$session_date, o$sma_slow, col = orange); long <- which(o$target); if (length(long)) points(o$session_date[long], rep(usr[[3L]] + .03 * diff(usr[3:4]), length(long)), pch = 15, col = blue, cex = .45)
  plot(o$session_date, u$equity / contract$initial_wealth - 1, type = "l", col = gray, lwd = 1.5, xlab = "Session", ylab = "Return", main = "Parent versus orderly-up entry gate"); lines(o$session_date, o$equity / contract$initial_wealth - 1, col = blue, lwd = 2); abline(h = 0, lty = 3); legend("topleft", c("Parent", "Orderly-up"), col = c(gray, blue), lwd = c(1.5, 2), bty = "n", cex = .8)
}
dev.off()

report <- c("# HYP-REG-09.1 Volatility-Normalized Robust Slope and Fit", "", paste0("Status: `", status, "`"), "", "## Frozen Question", "", "Can positive Theil-Sen slope plus unusually high path quality improve fresh next-open entries in the unchanged daily SMA8/SMA14 parent?", "",
  "## Construction", "", sprintf("Primary metrics use %d completed closes; %d sessions are durability-only. Slope is normalized by realized log-return volatility and quality is absolute Spearman correlation between time and log price. Current quality is ranked against the prior %d completed values.", contract$primary_window, contract$durability_window, contract$percentile_lookback), "",
  "## Stage A", "", sprintf("%d/%d construction gates passed before strategy access. Median real-panel 60/120 direction agreement was %.1f%% and median quality association was %.3f.", sum(stage_a_gates$passed), nrow(stage_a_gates), 100 * median(primary_diag$sign_agreement_60_120), median(primary_diag$quality_correlation_60_120)), "",
  "## Strategy Readout", "", sprintf("The positive-slope HIGH-quality entry overlay passed %d/%d strategy gates. Parent median annual return was %s; overlay was %s; timing-control percentile was %.1f.", sum(strategy_gates$passed), nrow(strategy_gates), fmt_pct(parent_row$median_return), fmt_pct(actual$median_return), 100 * timing_percentile), "",
  "## Boundary", "", "This is reused-window DEVELOPMENT evidence. The 120-session view could not rescue the 60-session primary, no parameter was searched after outcomes, and 2024+ confirmation remained sealed.")
writeLines(report, file.path(run_dir, "hyp_reg_09_1_report.md")); writeLines(status, file.path(run_dir, "STATUS.txt")); message(status); print(stage_a_gates, row.names = FALSE); print(strategy_gates, row.names = FALSE)
