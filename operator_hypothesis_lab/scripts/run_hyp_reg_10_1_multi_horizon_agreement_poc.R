options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_09_1_robust_slope_fit_poc.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_10_1_multi_horizon_agreement_poc.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
mean_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
fmt_pct <- function(x, digits = 2L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))

contract <- hreg101_contract(); imom <- imom_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_10_1_multi_horizon_agreement_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
if (nrow(registry) != 26L || anyDuplicated(registry$symbol) || sum(registry$strategy_role == "primary_stock") != 24L) hreg101_stop("Frozen registry integrity failed.")
stocks <- registry$symbol[registry$strategy_role == "primary_stock"]

run_id <- env_or("GEN5_HYP_REG_101_RUN_ID", "hyp_reg_10_1_multi_horizon_agreement_20260816")
run_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(run_dir, "visuals"); dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root); refresh <- env_bool("GEN5_HYP_REG_101_REFRESH", FALSE)
message("HYP-REG-10.1 loading the frozen daily measurement surface.")
query <- g5_workbench_query_adjusted_daily_bars(cfg = cfg, start_date = contract$query_start, end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = registry$symbol, universe_name = "hyp_reg_10_1_multi_horizon_agreement_panel",
  universe_roles = "20_60_120_direction_agreement,development_reused_window", refresh = refresh, repo_root = repo_root)
bars <- hreg91_assert_bars(query$bars, contract)
reference_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars[bars$symbol == reg$symbol, , drop = FALSE]; dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start); missing <- length(setdiff(reference_dates, dates))
  cbind(reg, data.frame(total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates), missing_reference_sessions = missing,
    coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < contract$minimum_prehistory) "PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else "COMPLETE", stringsAsFactors = FALSE))
}))
if (any(coverage$coverage_status != "COMPLETE")) { print(coverage[coverage$coverage_status != "COMPLETE", ], row.names = FALSE); hreg101_stop("One or more assets lack frozen measurement coverage.") }

ledger_cache <- file.path(run_dir, "hyp_reg_10_1_ledger.csv")
if (file.exists(ledger_cache) && !env_bool("GEN5_HYP_REG_101_REBUILD_MEASUREMENT", FALSE)) {
  message("HYP-REG-10.1 using the retained agreement ledger.")
  ledger <- utils::read.csv(ledger_cache, stringsAsFactors = FALSE); ledger$session_date <- as.Date(ledger$session_date); ledger$full_up_eligible <- as.logical(ledger$full_up_eligible)
  for (column in c("agreement_state", "transition_event")) { ledger[[column]] <- trimws(as.character(ledger[[column]])); ledger[[column]][ledger[[column]] == ""] <- NA_character_ }
} else {
  message("HYP-REG-10.1 building fixed 20/60/120-session normalized direction measurements.")
  ledger <- hreg101_build_ledger(bars, contract)
}
analysis <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
if (any(analysis$session_date >= contract$confirmation_start) || length(unique(analysis$symbol)) != 26L) hreg101_stop("Measurement boundary integrity failed.")
state_diagnostics <- hreg101_state_diagnostics(ledger, contract)

message("HYP-REG-10.1 calibrating five seeded synthetic path families.")
synthetic <- hreg101_synthetic_calibration(contract); synthetic_summary <- hreg101_synthetic_summary(synthetic)
scale_audit <- hreg101_scale_invariance_audit(contract); causality <- hreg101_causality_audit(contract)
syn <- function(kind) synthetic_summary[synthetic_summary$process == kind, , drop = FALSE]
clean_up <- syn("CLEAN_UP"); clean_down <- syn("CLEAN_DOWN"); opp_up <- syn("SHORT_OPPOSES_UP"); opp_down <- syn("SHORT_OPPOSES_DOWN")
primary_diag <- state_diagnostics[state_diagnostics$symbol %in% stocks, , drop = FALSE]
usable_states <- sum(primary_diag$full_up_fraction >= .10 & primary_diag$full_down_fraction >= .05)
usable_eligibility <- sum(primary_diag$eligible_fraction >= .10)
semantic_violations <- sum(
  (analysis$agreement_state == "FULL_UP" & !(analysis$sign20 > 0 & analysis$sign60 > 0 & analysis$sign120 > 0)) |
    (analysis$agreement_state == "FULL_DOWN" & !(analysis$sign20 < 0 & analysis$sign60 < 0 & analysis$sign120 < 0)) |
    (analysis$agreement_state == "SHORT_OPPOSES_UP" & !(analysis$sign20 < 0 & analysis$sign60 > 0 & analysis$sign120 > 0)) |
    (analysis$agreement_state == "SHORT_OPPOSES_DOWN" & !(analysis$sign20 > 0 & analysis$sign60 < 0 & analysis$sign120 < 0)), na.rm = TRUE)
join_up_rows <- analysis[analysis$transition_event == "SHORT_JOINS_UP", , drop = FALSE]
join_down_rows <- analysis[analysis$transition_event == "SHORT_JOINS_DOWN", , drop = FALSE]
join_semantics <- nrow(join_up_rows) > 0L && nrow(join_down_rows) > 0L && all(join_up_rows$agreement_state == "FULL_UP") && all(join_down_rows$agreement_state == "FULL_DOWN")

stage_a_gates <- data.frame(
  gate = c("A1_DATA_AND_BOUNDARY", "A2_CLEAN_DIRECTION_CALIBRATION", "A3_OPPOSITION_AND_JOIN_SEMANTICS", "A4_PRICE_SCALE_INVARIANCE", "A5_CAUSAL_APPEND_INVARIANCE", "A6_STATE_SEMANTICS", "A7_STATE_AND_POLICY_USABILITY"),
  threshold = c(">=120 prehistory; complete 26-asset analysis; 2024+ absent", "clean up/down intended states each >=95%", "synthetic short-opposition states each >=95%; real join-up and join-down events exist", "all normalized returns invariant within 1e-12", "all prior rolling values exactly unchanged after future append", "five-state sign rules exact; FULL_UP eligibility exact", ">=20/24 stocks have >=10% FULL_UP and >=5% FULL_DOWN; >=20/24 have >=10% eligible sessions"),
  observed = c(
    sprintf("%d/26 complete; min %d prehistory; first finite state %s", sum(coverage$coverage_status == "COMPLETE"), min(coverage$prehistory_sessions), min(analysis$session_date[!is.na(analysis$agreement_state)])),
    sprintf("clean up %.1f%% FULL_UP; clean down %.1f%% FULL_DOWN", 100 * clean_up$target_state_fraction, 100 * clean_down$target_state_fraction),
    sprintf("opposes up %.1f%%; opposes down %.1f%%; joins %d up/%d down", 100 * opp_up$target_state_fraction, 100 * opp_down$target_state_fraction, nrow(join_up_rows), nrow(join_down_rows)),
    sprintf("max difference %.3g", max(scale_audit$absolute_difference)), sprintf("max difference %.3g", max(causality$maximum_append_difference)),
    sprintf("%d semantic violations; FULL_UP mismatch %d", semantic_violations, sum((analysis$full_up_eligible %in% TRUE) != (analysis$agreement_state == "FULL_UP"), na.rm = TRUE)),
    sprintf("%d/24 state-usable; %d/24 eligibility-usable; median eligible %.1f%%", usable_states, usable_eligibility, 100 * median(primary_diag$eligible_fraction))
  ),
  passed = c(
    all(coverage$coverage_status == "COMPLETE") && !any(analysis$session_date >= contract$confirmation_start),
    clean_up$target_state_fraction >= .95 && clean_down$target_state_fraction >= .95,
    opp_up$target_state_fraction >= .95 && opp_down$target_state_fraction >= .95 && join_semantics,
    max(scale_audit$absolute_difference) <= 1e-12, all(causality$passed), semantic_violations == 0L && all((analysis$full_up_eligible %in% TRUE) == (analysis$agreement_state == "FULL_UP"), na.rm = TRUE),
    usable_states >= 20L && usable_eligibility >= 20L
  ), stringsAsFactors = FALSE
)
stage_a_passed <- all(stage_a_gates$passed)

write_csv(registry, file.path(run_dir, "hyp_reg_10_1_registry.csv")); write_csv(coverage, file.path(run_dir, "hyp_reg_10_1_coverage.csv")); write_csv(ledger, ledger_cache)
write_csv(state_diagnostics, file.path(run_dir, "hyp_reg_10_1_state_diagnostics.csv")); write_csv(synthetic_summary, file.path(run_dir, "hyp_reg_10_1_synthetic_summary.csv"))
write_csv(scale_audit, file.path(run_dir, "hyp_reg_10_1_scale_invariance.csv")); write_csv(causality, file.path(run_dir, "hyp_reg_10_1_causality_audit.csv")); write_csv(stage_a_gates, file.path(run_dir, "hyp_reg_10_1_stage_a_gates.csv"))

ink <- "#17202A"; blue <- "#3D8DFF"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#8A949E"; pale <- "#DCEBFA"; purple <- "#8666B8"
png_open <- function(name, width = 1800, height = 1000) grDevices::png(file.path(visual_dir, name), width = width, height = height, res = 160)

png_open("synthetic_calibration.png", 2000, 1100); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
order_syn <- c("CLEAN_DOWN", "SHORT_OPPOSES_DOWN", "RANDOM_WALK", "SHORT_OPPOSES_UP", "CLEAN_UP")
zmat <- rbind(synthetic_summary$median_z20, synthetic_summary$median_z60, synthetic_summary$median_z120)[, match(order_syn, synthetic_summary$process)]
barplot(zmat, beside = TRUE, names.arg = c("Clean down", "Short opposes down", "Random walk", "Short opposes up", "Clean up"), col = c(blue, orange, purple), border = NA, las = 2, ylab = "Median normalized displacement", main = "Three frozen horizons", legend.text = c("20", "60", "120"), args.legend = list(x = "topleft", bty = "n")); abline(h = 0, lty = 2)
fractions <- synthetic_summary$target_state_fraction[match(order_syn, synthetic_summary$process)]; fractions[is.na(fractions)] <- synthetic_summary$full_agreement_fraction[match("RANDOM_WALK", synthetic_summary$process)]
barplot(100 * fractions, names.arg = c("Clean down", "Short opposes down", "RW full agree", "Short opposes up", "Clean up"), col = c(red, orange, gray, blue, green), border = NA, las = 2, ylim = c(0, 105), ylab = "Paths (%)", main = "Intended-state recovery"); abline(h = 95, lty = 2)
dev.off()

png_open("state_usability.png", 2000, 1100); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
occupancy <- rbind(primary_diag$full_down_fraction, primary_diag$short_opposes_down_fraction, primary_diag$mixed_fraction, primary_diag$short_opposes_up_fraction, primary_diag$full_up_fraction)
barplot(100 * occupancy, names.arg = primary_diag$symbol, col = c(red, orange, gray, pale, green), border = NA, las = 2, ylab = "Analysis sessions (%)", main = "Agreement-state occupancy", legend.text = c("FULL_DOWN", "SHORT_OPPOSES_DOWN", "MIXED", "SHORT_OPPOSES_UP", "FULL_UP"), args.legend = list(x = "topright", bty = "n", cex = .7))
barplot(100 * primary_diag$eligible_fraction, names.arg = primary_diag$symbol, col = green, border = NA, las = 2, ylab = "Analysis sessions (%)", main = "FULL_UP fresh-entry eligibility"); abline(h = 10, lty = 2)
dev.off()

png_open("horizon_agreement.png"); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
barplot(100 * primary_diag$sign20_60_agreement, names.arg = primary_diag$symbol, col = blue, border = NA, las = 2, ylim = c(0,100), ylab = "Sessions (%)", main = "20/60 sign agreement")
barplot(100 * primary_diag$sign60_120_agreement, names.arg = primary_diag$symbol, col = purple, border = NA, las = 2, ylim = c(0,100), ylab = "Sessions (%)", main = "60/120 sign agreement"); dev.off()

state_cols <- c(FULL_DOWN = "#F3A6A2", SHORT_OPPOSES_DOWN = "#F8D9B4", MIXED = "#E6E6E6", SHORT_OPPOSES_UP = "#D7E7FA", FULL_UP = "#A7D7B8")
png_open("representative_measurement_tapes.png", 2200, 2100); layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
for (symbol in c("AMD", "TSLA", "TXN", "SPY")) {
  z <- analysis[analysis$symbol == symbol & !is.na(analysis$agreement_state), , drop = FALSE]; groups <- cumsum(c(TRUE, z$agreement_state[-1L] != head(z$agreement_state, -1L)))
  plot(z$session_date, z$close, type = "n", xlab = "", ylab = "Adjusted close", main = paste(symbol, "price and agreement state")); usr <- par("usr")
  for (g in unique(groups)) { q <- z[groups == g, ]; rect(min(q$session_date), usr[[3L]], max(q$session_date) + 1, usr[[4L]], col = adjustcolor(state_cols[[q$agreement_state[[1L]]]], .55), border = NA) }
  lines(z$session_date, z$close, col = ink, lwd = 1.3)
  plot(z$session_date, z$normalized_return20, type = "l", col = blue, lwd = 1, xlab = "Session", ylab = "Normalized displacement", main = "20/60/120 directional evidence"); lines(z$session_date, z$normalized_return60, col = orange); lines(z$session_date, z$normalized_return120, col = purple); abline(h = 0, lty = 2); legend("topleft", c("20", "60", "120"), col = c(blue, orange, purple), lwd = 1, bty = "n", ncol = 3, cex = .8)
}
dev.off()

stage_a_status <- if (stage_a_passed) "PASS_STAGE_A_CONSTRUCTION" else "STOP_MULTI_HORIZON_AGREEMENT_STAGE_A_FAILED_STAGE_B_NOT_RUN"
if (!stage_a_passed) {
  write_csv(data.frame(hypothesis_id = contract$hypothesis_id, status = stage_a_status, evidence_stage = contract$evidence_stage, as_of_timestamp = contract$as_of_timestamp, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, confirmation_start = contract$confirmation_start, horizons = paste(contract$horizons, collapse = "/"), confirmation_2024_plus = "SEALED"), file.path(run_dir, "hyp_reg_10_1_run_spec.csv"))
  writeLines(c("# HYP-REG-10.1 Multi-Horizon Direction Agreement", "", paste0("Status: `", stage_a_status, "`"), "", "Stage A did not pass its frozen construction gates. Strategy outcomes were not accessed."), file.path(run_dir, "hyp_reg_10_1_report.md"))
  writeLines(stage_a_status, file.path(run_dir, "STATUS.txt")); message(stage_a_status); print(stage_a_gates, row.names = FALSE); quit(save = "no", status = 0L)
}

message("HYP-REG-10.1 Stage A passed; entering the frozen SMA8/14 strategy-relative replay.")
prior_daily_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_01_2_strategy_overlay_20260814", "hyp_reg_01_2_reconstructed_daily.rds")
parent_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "intraday_momentum_poc_series_20260813", "fixed_sma_summaries.csv")
if (!file.exists(prior_daily_path) || !file.exists(parent_path)) hreg101_stop("Retained daily parent evidence is unavailable.")
daily <- readRDS(prior_daily_path); daily$session_date <- as.Date(daily$session_date); daily <- daily[daily$session_date < contract$confirmation_start & daily$symbol %in% registry$symbol, , drop = FALSE]
states <- hreg101_validate_ledger(ledger, contract)
strategy_coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- daily[daily$symbol == reg$symbol & daily$session_date >= contract$analysis_start & daily$session_date <= contract$analysis_end, , drop = FALSE]
  s <- states[states$symbol == reg$symbol & states$session_date >= contract$analysis_start & states$session_date <= contract$analysis_end, , drop = FALSE]; idx <- match(x$session_date, s$session_date); missing_state <- sum(is.na(idx) | is.na(s$agreement_state[idx]))
  data.frame(instance_id = reg$instance_id, symbol = reg$symbol, strategy_sessions = nrow(x), state_sessions = nrow(s), missing_state_dates = length(setdiff(x$session_date, s$session_date)), state_only_dates = length(setdiff(s$session_date, x$session_date)), missing_states = missing_state,
    status = if (nrow(x) == 1499L && nrow(s) == 1509L && !length(setdiff(x$session_date, s$session_date)) && length(setdiff(s$session_date, x$session_date)) == 10L && missing_state == 0L) "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS" else "REVIEW")
}))
if (any(strategy_coverage$status != "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS")) hreg101_stop("Daily/agreement calendar alignment failed.")

scenario_table <- data.frame(scenario = c("PRIMARY", "STRESS"), bps = c(contract$primary_bps, contract$stress_bps))
summaries <- list(); trades <- list(); paths_all <- list(); aligned_by_symbol <- list(); k <- 0L; tk <- 0L; pk <- 0L
for (symbol in registry$symbol) {
  x <- daily[daily$symbol == symbol, , drop = FALSE]; x <- x[order(x$session_date), , drop = FALSE]
  frame <- hreg101_align(hreg12_cross_frame(x, contract$fast, contract$slow), states[states$symbol == symbol, , drop = FALSE]); aligned_by_symbol[[symbol]] <- frame
  reg <- registry[match(symbol, registry$symbol), , drop = FALSE]
  for (year in contract$years) {
    start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start); end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end)
    schedules <- lapply(contract$policies, function(p) hreg101_schedule(frame, start, end, p)); names(schedules) <- contract$policies
    schedules$BUY_HOLD <- imom_buy_hold_schedule(x, start, end); schedules$CASH <- schedules$UNFILTERED; schedules$CASH$target <- FALSE; schedules$CASH$entry_signal <- FALSE; schedules$CASH$exit_signal <- FALSE
    block_frame <- frame[frame$session_date >= start & frame$session_date <= end, , drop = FALSE]
    for (policy in names(schedules)) for (si in seq_len(nrow(scenario_table))) {
      scenario <- scenario_table[si, , drop = FALSE]; replay <- imom_replay(x, start, end, schedules[[policy]], 1, scenario$bps, 0, scenario$scenario, 252L, imom)
      q <- replay$summary; q$policy <- policy; q$year <- year; q$sector <- reg$sector; q$asset_type <- reg$asset_type; q$strategy_role <- reg$strategy_role; k <- k + 1L; summaries[[k]] <- q
      if (scenario$scenario == "PRIMARY" && policy %in% contract$policies) {
        t <- hreg101_label_trades(replay$trades, block_frame); if (nrow(t)) { t$policy <- policy; t$year <- year; t$sector <- reg$sector; t$strategy_role <- reg$strategy_role; tk <- tk + 1L; trades[[tk]] <- t }
        w <- replay$path; for (column in c("sma_fast", "sma_slow", "agreement_state", "normalized_return20", "normalized_return60", "normalized_return120", "full_up_eligible")) w[[column]] <- block_frame[[column]]; w$blocked_entry <- schedules[[policy]]$blocked_entry; w$policy <- policy; w$year <- year; w$sector <- reg$sector; w$strategy_role <- reg$strategy_role; pk <- pk + 1L; paths_all[[pk]] <- w
      }
    }
  }
}
summaries <- do.call(rbind, summaries); trades <- do.call(rbind, trades); paths_all <- do.call(rbind, paths_all)

parent <- utils::read.csv(parent_path, stringsAsFactors = FALSE); parent <- parent[parent$frequency == "DAILY" & parent$policy == "SMA8_14" & parent$scenario == "PRIMARY" & parent$delay_bars == 0 & parent$leverage == 1, c("symbol", "year", "total_return")]; names(parent)[[3L]] <- "parent_total_return"
reproduction <- merge(summaries[summaries$policy == "UNFILTERED" & summaries$scenario == "PRIMARY", c("symbol", "year", "total_return")], parent, by = c("symbol", "year"), all = TRUE)
reproduction$absolute_difference <- abs(reproduction$total_return - reproduction$parent_total_return); reproduction$passed <- is.finite(reproduction$absolute_difference) & reproduction$absolute_difference <= contract$reproduction_tolerance
if (!all(reproduction$passed)) hreg101_stop(sprintf("Parent reproduction failed; maximum difference %.12g.", max(reproduction$absolute_difference, na.rm = TRUE)))

message("HYP-REG-10.1 running 200 deterministic within-asset/year circular eligibility controls.")
control_cache <- file.path(run_dir, "hyp_reg_10_1_control_cells.csv")
if (file.exists(control_cache) && !env_bool("GEN5_HYP_REG_101_REBUILD_CONTROLS", FALSE)) { message("HYP-REG-10.1 using retained controls."); controls <- utils::read.csv(control_cache, stringsAsFactors = FALSE) } else {
  controls <- vector("list", length(stocks) * length(contract$years) * contract$placebo_simulations); ck <- 0L
  for (symbol in stocks) { x <- daily[daily$symbol == symbol, , drop = FALSE]; frame <- aligned_by_symbol[[symbol]]
    for (year in contract$years) { start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start); end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end); w <- x[x$session_date >= start & x$session_date <= end, , drop = FALSE]
      for (simulation_id in seq_len(contract$placebo_simulations)) { schedule <- hreg101_shifted_schedule(frame, start, end, simulation_id, contract); ck <- ck + 1L
        controls[[ck]] <- data.frame(symbol = symbol, year = year, simulation_id = simulation_id, shift_offset = attr(schedule, "shift_offset"), exposure = mean(schedule$target), blocked_entries = sum(schedule$blocked_entry), total_return = imom_fast_terminal_from_schedule(w, schedule, 1, contract$primary_bps, 0, imom)) }
    }
  }
  controls <- do.call(rbind, controls); write_csv(controls, control_cache)
}
control_panel <- do.call(rbind, lapply(split(controls, controls$simulation_id), function(x) data.frame(simulation_id = x$simulation_id[[1L]], cells = nrow(x), median_return = median_na(x$total_return), median_exposure = median_na(x$exposure), positive_fraction = mean(x$total_return > 0))))

primary <- summaries[summaries$strategy_role == "primary_stock" & summaries$scenario == "PRIMARY", , drop = FALSE]
policy_panel <- hreg101_policy_panel(primary); policy_panel <- policy_panel[match(c("UNFILTERED", "ENTRY_FULL_UP_ONLY", "BUY_HOLD", "CASH"), policy_panel$policy), , drop = FALSE]
parent_cells <- primary[primary$policy == "UNFILTERED", , drop = FALSE]; overlay_cells <- primary[primary$policy == "ENTRY_FULL_UP_ONLY", , drop = FALSE]
paired <- merge(parent_cells[c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure", "turnover", "trade_count")], overlay_cells[c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure", "turnover", "trade_count")], by = c("symbol", "year"), suffixes = c("_parent", "_overlay"))
paired$return_excess <- paired$total_return_overlay - paired$total_return_parent; paired$drawdown_change <- paired$maximum_drawdown_overlay - paired$maximum_drawdown_parent; paired$sharpe_change <- paired$sharpe_overlay - paired$sharpe_parent
comp <- hreg101_compound_by_asset(primary[primary$policy %in% contract$policies, , drop = FALSE]); pcomp <- comp[comp$policy == "UNFILTERED", c("symbol", "compounded_return")]; names(pcomp)[[2L]] <- "parent_compounded_return"; ocomp <- comp[comp$policy == "ENTRY_FULL_UP_ONLY", c("symbol", "compounded_return")]; names(ocomp)[[2L]] <- "overlay_compounded_return"
asset_summary <- merge(pcomp, ocomp, by = "symbol"); asset_summary$compounded_excess <- asset_summary$overlay_compounded_return - asset_summary$parent_compounded_return
year_summary <- do.call(rbind, lapply(split(paired, paired$year), function(x) data.frame(year = x$year[[1L]], cells = nrow(x), median_excess = median_na(x$return_excess), improvement_fraction = mean(x$return_excess > 0), median_drawdown_change = median_na(x$drawdown_change), median_sharpe_change = median_na(x$sharpe_change))))
actual <- policy_panel[policy_panel$policy == "ENTRY_FULL_UP_ONLY", , drop = FALSE]; parent_row <- policy_panel[policy_panel$policy == "UNFILTERED", , drop = FALSE]
near_ids <- hreg101_exposure_near_ids(control_panel, actual$median_exposure, contract$exposure_near_count); control_panel$exposure_near <- control_panel$simulation_id %in% near_ids; near <- control_panel[control_panel$exposure_near, , drop = FALSE]
timing_percentile <- hreg101_midrank_percentile(actual$median_return, near$median_return); timing_excess <- actual$median_return - median_na(near$median_return)
placebo_readout <- data.frame(policy = "ENTRY_FULL_UP_ONLY", actual_return = actual$median_return, actual_exposure = actual$median_exposure, percentile = timing_percentile, excess_vs_control_median = timing_excess, near_controls = nrow(near))

strategy_gates <- data.frame(
  gate = c("G1_CAUSAL_DATA_AND_CALENDAR", "G2_PARENT_REPRODUCTION", "G3_CONSTRUCTION_AND_SEMANTICS", "G4_PANEL_RETURN", "G5_ASSET_BREADTH", "G6_CALENDAR_BREADTH", "G7_PROTECTION_AND_SHARPE", "G8_ABSOLUTE_VIABILITY", "G9_TIMING_SPECIFICITY"),
  threshold = c("26/26 aligned; 24 primary stocks; 2024+ absent", "156/156 annual cells exact", "all frozen Stage A gates pass", "overlay median annual return > parent", ">=15/24 stocks improve over six years", ">=4/6 years have positive median excess", "median maximum drawdown no worse and median Sharpe no lower", "positive absolute median annual return", ">=80th percentile and above median of 40 exposure-nearest controls"),
  observed = c(sprintf("%d/26 complete; max date %s", sum(strategy_coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS"), max(daily$session_date)), sprintf("%d/%d; max difference %.3g", sum(reproduction$passed), nrow(reproduction), max(reproduction$absolute_difference)), sprintf("%d/%d Stage A gates", sum(stage_a_gates$passed), nrow(stage_a_gates)), sprintf("%s vs %s", fmt_pct(actual$median_return), fmt_pct(parent_row$median_return)), sprintf("%d/24 improved", sum(asset_summary$compounded_excess > 0)), sprintf("%d/6 positive years", sum(year_summary$median_excess > 0)), sprintf("drawdown %s; Sharpe %+.3f", fmt_pct(actual$median_drawdown - parent_row$median_drawdown), actual$median_sharpe - parent_row$median_sharpe), fmt_pct(actual$median_return), sprintf("%.1fth percentile; %s vs controls", 100 * timing_percentile, fmt_pct(timing_excess))),
  passed = c(all(strategy_coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS") && !any(daily$session_date >= contract$confirmation_start), all(reproduction$passed), all(stage_a_gates$passed), actual$median_return > parent_row$median_return, sum(asset_summary$compounded_excess > 0) >= 15L, sum(year_summary$median_excess > 0) >= 4L, actual$median_drawdown >= parent_row$median_drawdown && actual$median_sharpe >= parent_row$median_sharpe, actual$median_return > 0, is.finite(timing_percentile) && timing_percentile >= .80 && timing_excess > 0), stringsAsFactors = FALSE)
all_passed <- all(strategy_gates$passed); status <- if (all_passed) "PASS_TO_CONFIRMATION_DISCUSSION" else "STOP_MULTI_HORIZON_AGREEMENT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN"
decision <- data.frame(policy = "ENTRY_FULL_UP_ONLY", gates_passed = sum(strategy_gates$passed), gates_total = nrow(strategy_gates), all_passed = all_passed, status = status)

parent_trades <- trades[trades$policy == "UNFILTERED" & trades$strategy_role == "primary_stock", , drop = FALSE]
parent_trades$entry_group <- ifelse(parent_trades$entry_state == "FULL_UP", "FULL_UP", ifelse(parent_trades$entry_state == "SHORT_OPPOSES_UP", "UP_CONTEXT_SHORT_OPPOSES", "OTHER"))
entry_state_audit <- do.call(rbind, lapply(split(parent_trades, parent_trades$entry_group), function(x) data.frame(entry_group = x$entry_group[[1L]], trades = nrow(x), hit_rate = mean(x$net_return > 0), mean_trade = mean_na(x$net_return), median_trade = median_na(x$net_return), median_holding = median_na(x$holding_bars), median_z20 = median_na(x$entry_z20), median_z60 = median_na(x$entry_z60), median_z120 = median_na(x$entry_z120))))

write_csv(strategy_coverage, file.path(run_dir, "hyp_reg_10_1_strategy_coverage.csv")); write_csv(reproduction, file.path(run_dir, "hyp_reg_10_1_parent_reproduction.csv")); write_csv(summaries, file.path(run_dir, "hyp_reg_10_1_summaries.csv")); write_csv(trades, file.path(run_dir, "hyp_reg_10_1_trades.csv")); write_csv(policy_panel, file.path(run_dir, "hyp_reg_10_1_policy_panel.csv"))
write_csv(paired, file.path(run_dir, "hyp_reg_10_1_paired_cells.csv")); write_csv(asset_summary, file.path(run_dir, "hyp_reg_10_1_asset_summary.csv")); write_csv(year_summary, file.path(run_dir, "hyp_reg_10_1_year_summary.csv")); write_csv(entry_state_audit, file.path(run_dir, "hyp_reg_10_1_entry_state_audit.csv")); write_csv(controls, control_cache); write_csv(control_panel, file.path(run_dir, "hyp_reg_10_1_control_panel.csv")); write_csv(placebo_readout, file.path(run_dir, "hyp_reg_10_1_placebo_readout.csv")); write_csv(strategy_gates, file.path(run_dir, "hyp_reg_10_1_strategy_gates.csv")); write_csv(decision, file.path(run_dir, "hyp_reg_10_1_decision.csv"))
write_csv(data.frame(hypothesis_id = contract$hypothesis_id, status = status, evidence_stage = contract$evidence_stage, as_of_timestamp = contract$as_of_timestamp, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, confirmation_start = contract$confirmation_start, horizons = paste(contract$horizons, collapse = "/"), primary_bps = contract$primary_bps, stress_bps = contract$stress_bps, leverage = 1, confirmation_2024_plus = "SEALED"), file.path(run_dir, "hyp_reg_10_1_run_spec.csv"))

plot_primary <- primary[primary$policy %in% c("UNFILTERED", "ENTRY_FULL_UP_ONLY", "BUY_HOLD"), , drop = FALSE]; plot_primary$policy <- factor(plot_primary$policy, levels = c("UNFILTERED", "ENTRY_FULL_UP_ONLY", "BUY_HOLD"))
png_open("policy_performance.png"); par(mfrow = c(1, 2), mar = c(7, 5, 4, 1)); boxplot(total_return * 100 ~ policy, data = plot_primary, col = c(gray, green, orange), border = ink, outline = FALSE, xlab = "", ylab = "Annual return (%)", xaxt = "n", main = "Return after 5 bp per side"); axis(1, at = 1:3, labels = c("Parent", "FULL_UP entry", "Buy & hold"), las = 2); abline(h = 0, lty = 2); boxplot(maximum_drawdown * 100 ~ policy, data = plot_primary, col = c(gray, green, orange), border = ink, outline = FALSE, xlab = "", ylab = "Maximum drawdown (%)", xaxt = "n", main = "Protection bargain"); axis(1, at = 1:3, labels = c("Parent", "FULL_UP entry", "Buy & hold"), las = 2); dev.off()

png_open("policy_mechanics.png"); par(mfrow = c(2, 2), mar = c(6, 5, 4, 1)); for (metric in c("median_return", "median_sharpe", "median_exposure", "median_turnover")) { values <- policy_panel[[metric]][match(c("UNFILTERED", "ENTRY_FULL_UP_ONLY"), policy_panel$policy)]; if (metric %in% c("median_return", "median_exposure")) values <- 100 * values; barplot(values, names.arg = c("Parent", "FULL_UP"), col = c(gray, green), border = NA, ylab = gsub("_", " ", metric), main = gsub("_", " ", metric)); abline(h = 0, col = ink) }; dev.off()

png_open("asset_breadth.png", 1600, 1200); z <- asset_summary[order(asset_summary$compounded_excess), ]; barplot(z$compounded_excess * 100, names.arg = z$symbol, horiz = TRUE, las = 1, col = ifelse(z$compounded_excess > 0, green, red), border = NA, xlab = "FULL_UP overlay minus parent six-year return (pp)", main = "Transport across 24 stocks"); abline(v = 0, col = ink, lwd = 1.5); dev.off()

png_open("calendar_and_controls.png"); par(mfrow = c(1, 2), mar = c(5, 5, 4, 1)); barplot(year_summary$median_excess * 100, names.arg = year_summary$year, col = ifelse(year_summary$median_excess > 0, green, red), border = NA, ylab = "Median excess (pp)", main = "Calendar breadth"); abline(h = 0, col = ink); hist(near$median_return * 100, breaks = 12, col = pale, border = "white", xlab = "Panel median annual return (%)", main = "Exposure-nearest timing controls"); abline(v = 100 * actual$median_return, col = green, lwd = 3); legend("topright", sprintf("Actual %.2f%%\nPercentile %.1f", 100 * actual$median_return, 100 * timing_percentile), bty = "n"); dev.off()

png_open("entry_state_audit.png"); par(mfrow = c(1, 2), mar = c(7, 5, 4, 1)); groups_entry <- c("OTHER", "UP_CONTEXT_SHORT_OPPOSES", "FULL_UP"); boxplot(net_return * 100 ~ factor(entry_group, levels = groups_entry), data = parent_trades, col = c(gray, pale, green), border = ink, outline = FALSE, xlab = "Agreement state at parent entry", ylab = "Parent trade return (%)", main = "What the hard gate selects", las = 2); abline(h = 0, lty = 2); audit_plot <- entry_state_audit[match(groups_entry, entry_state_audit$entry_group), , drop = FALSE]; barplot(audit_plot$trades, names.arg = audit_plot$entry_group, col = c(gray, pale, green), border = NA, ylab = "Parent trades", main = "Opportunity count", las = 2); dev.off()

best <- paired[which.max(paired$return_excess), c("symbol", "year")]; worst <- paired[which.min(paired$return_excess), c("symbol", "year")]; ordered_near <- paired[order(abs(paired$return_excess - median(paired$return_excess))), c("symbol", "year")]; canonical <- paired[paired$symbol == "AMD", c("symbol", "year")][1L, , drop = FALSE]
selected <- unique(rbind(data.frame(best, role = "LARGEST_IMPROVEMENT"), data.frame(worst, role = "LARGEST_DEGRADATION"), data.frame(ordered_near[1L, ], role = "NEAR_MEDIAN"), data.frame(canonical, role = "CANONICAL_AMD"))); write_csv(selected, file.path(run_dir, "hyp_reg_10_1_representative_selection.csv"))
png_open("representative_strategy_tapes.png", 2200, 2200); layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
for (i in seq_len(nrow(selected))) { pick <- selected[i, ]; u <- paths_all[paths_all$symbol == pick$symbol & paths_all$year == pick$year & paths_all$policy == "UNFILTERED", , drop = FALSE]; o <- paths_all[paths_all$symbol == pick$symbol & paths_all$year == pick$year & paths_all$policy == "ENTRY_FULL_UP_ONLY", , drop = FALSE]; display_state <- o$agreement_state; display_state[is.na(display_state)] <- "MIXED"; groups_run <- cumsum(c(TRUE, display_state[-1L] != head(display_state, -1L)))
  plot(o$session_date, o$close, type = "n", xlab = "", ylab = "Close", main = paste(pick$role, "-", pick$symbol, pick$year)); usr <- par("usr"); for (g in unique(groups_run)) { q <- o[groups_run == g, ]; state <- display_state[which(groups_run == g)[[1L]]]; rect(min(q$session_date), usr[[3L]], max(q$session_date) + 1, usr[[4L]], col = adjustcolor(state_cols[[state]], .55), border = NA) }; lines(o$session_date, o$close, col = ink, lwd = 1.3); lines(o$session_date, o$sma_fast, col = blue); lines(o$session_date, o$sma_slow, col = orange); long <- which(o$target); if (length(long)) points(o$session_date[long], rep(usr[[3L]] + .03 * diff(usr[3:4]), length(long)), pch = 15, col = green, cex = .45)
  plot(o$session_date, u$equity / contract$initial_wealth - 1, type = "l", col = gray, lwd = 1.5, xlab = "Session", ylab = "Return", main = "Parent versus FULL_UP entry gate"); lines(o$session_date, o$equity / contract$initial_wealth - 1, col = green, lwd = 2); abline(h = 0, lty = 3); legend("topleft", c("Parent", "FULL_UP"), col = c(gray, green), lwd = c(1.5, 2), bty = "n", cex = .8)
}
dev.off()

report <- c("# HYP-REG-10.1 Multi-Horizon Direction Agreement", "", paste0("Status: `", status, "`"), "", "## Frozen Question", "", "Can full agreement across 20-, 60-, and 120-session volatility-normalized price displacement improve fresh next-open entries in the unchanged daily SMA8/SMA14 parent?", "", "## Construction", "", "Each horizon measures log-price displacement divided by its own realized log-return volatility times the square root of the horizon. Only the signs classify the five frozen states; no horizon or threshold was searched.", "", "## Stage A", "", sprintf("%d/%d construction gates passed before strategy access. Median real-panel FULL_UP occupancy was %.1f%%; 20/60 and 60/120 sign agreement were %.1f%% and %.1f%%.", sum(stage_a_gates$passed), nrow(stage_a_gates), 100 * median(primary_diag$full_up_fraction), 100 * median(primary_diag$sign20_60_agreement), 100 * median(primary_diag$sign60_120_agreement)), "", "## Strategy Readout", "", sprintf("The FULL_UP fresh-entry overlay passed %d/%d strategy gates. Parent median annual return was %s; overlay was %s; timing-control percentile was %.1f.", sum(strategy_gates$passed), nrow(strategy_gates), fmt_pct(parent_row$median_return), fmt_pct(actual$median_return), 100 * timing_percentile), "", "## Boundary", "", "This is reused-window DEVELOPMENT evidence. The frozen 20/60/120 construction was not tuned after outcomes, the ATR lane was not joined, and 2024+ confirmation remained sealed.")
writeLines(report, file.path(run_dir, "hyp_reg_10_1_report.md")); writeLines(status, file.path(run_dir, "STATUS.txt")); message(status); print(stage_a_gates, row.names = FALSE); print(strategy_gates, row.names = FALSE)
