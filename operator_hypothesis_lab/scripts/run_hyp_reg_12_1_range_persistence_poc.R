options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_09_1_robust_slope_fit_poc.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_12_1_range_persistence_poc.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
mean_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
fmt_pct <- function(x, digits = 2L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))

contract <- hreg121_contract(); imom <- imom_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_12_1_range_persistence_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
if (nrow(registry) != 26L || anyDuplicated(registry$symbol) || sum(registry$strategy_role == "primary_stock") != 24L) hreg121_stop("Frozen registry integrity failed.")
stocks <- registry$symbol[registry$strategy_role == "primary_stock"]

run_id <- env_or("GEN5_HYP_REG_121_RUN_ID", "hyp_reg_12_1_range_persistence_20260817")
run_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(run_dir, "visuals"); dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root); refresh <- env_bool("GEN5_HYP_REG_121_REFRESH", FALSE)
message("HYP-REG-12.1 loading the frozen daily measurement surface.")
query <- g5_workbench_query_adjusted_daily_bars(cfg = cfg, start_date = contract$query_start, end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = registry$symbol, universe_name = "hyp_reg_12_1_range_persistence_panel",
  universe_roles = "range_position,breakout_persistence,development_reused_window", refresh = refresh, repo_root = repo_root)
bars <- hreg91_assert_bars(query$bars, contract)
reference_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars[bars$symbol == reg$symbol, , drop = FALSE]; dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start); missing <- length(setdiff(reference_dates, dates))
  cbind(reg, data.frame(total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates), missing_reference_sessions = missing,
    coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < contract$minimum_prehistory) "PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else "COMPLETE", stringsAsFactors = FALSE))
}))
if (any(coverage$coverage_status != "COMPLETE")) { print(coverage[coverage$coverage_status != "COMPLETE", ], row.names = FALSE); hreg121_stop("One or more assets lack frozen measurement coverage.") }

ledger_cache <- file.path(run_dir, "hyp_reg_12_1_ledger.csv")
if (file.exists(ledger_cache) && !env_bool("GEN5_HYP_REG_121_REBUILD_MEASUREMENT", FALSE)) {
  message("HYP-REG-12.1 using the retained range-persistence ledger.")
  ledger <- utils::read.csv(ledger_cache, stringsAsFactors = FALSE); ledger$session_date <- as.Date(ledger$session_date)
  for (column in c("upper_now", "lower_now", "upper_persistent", "lower_persistent", "new_breakout", "breakout_event_active", "above_breakout_boundary")) ledger[[column]] <- as.logical(ledger[[column]])
  ledger$range_state[ledger$range_state == ""] <- NA_character_
} else {
  message("HYP-REG-12.1 building the fixed 63-session range and 3-of-5 persistence state.")
  ledger <- hreg121_build_ledger(bars, contract)
}
analysis <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
if (any(analysis$session_date >= contract$confirmation_start) || length(unique(analysis$symbol)) != 26L) hreg121_stop("Measurement boundary integrity failed.")
cross_frames <- lapply(split(bars, bars$symbol), function(x) hreg12_cross_frame(x, contract$fast, contract$slow))
state_diagnostics <- hreg121_state_diagnostics(ledger, cross_frames, contract)
event_outcomes <- do.call(rbind, lapply(split(ledger, ledger$symbol), hreg121_event_outcomes, contract = contract))

message("HYP-REG-12.1 running seeded synthetic construction and falsification paths.")
synthetic <- hreg121_synthetic_calibration(contract); synthetic_summary <- hreg121_synthetic_summary(synthetic)
causality <- hreg121_causality_audit(contract)
set.seed(contract$synthetic_seed + 2L); scale_close <- exp(cumsum(stats::rnorm(500L, .0003, .012))); scale_dates <- seq(as.Date("2010-01-01"), by = "day", length.out = length(scale_close))
scale_bars <- data.frame(symbol = "TEST", session_date = scale_dates, timestamp_utc = as.POSIXct(scale_dates, tz = "UTC"), open = scale_close, high = scale_close, low = scale_close, close = scale_close, volume = 1)
scale_a <- hreg121_build_asset_ledger(scale_bars, contract); scale_bars[, c("open", "high", "low", "close")] <- scale_bars[, c("open", "high", "low", "close")] * 7; scale_b <- hreg121_build_asset_ledger(scale_bars, contract)
scale_difference <- max(abs(scale_a$range_position - scale_b$range_position), na.rm = TRUE); scale_state_match <- identical(scale_a$range_state, scale_b$range_state)

syn <- function(kind) synthetic_summary[synthetic_summary$process == kind, , drop = FALSE]
up <- syn("CLEAN_UP"); down <- syn("CLEAN_DOWN"); hold <- syn("BREAKOUT_HOLD"); fail <- syn("BREAKOUT_FAIL")
primary_diag <- state_diagnostics[state_diagnostics$symbol %in% stocks, , drop = FALSE]
usable_occupancy <- sum(primary_diag$upper_persistent_fraction >= .10 & primary_diag$upper_persistent_fraction <= .60)
usable_crosses <- sum(primary_diag$eligible_crosses >= 3L)
state_violations <- sum(
  (analysis$upper_persistent & !(analysis$range_position >= contract$upper_threshold & analysis$upper_count5 >= contract$persistence_required)) |
    (analysis$lower_persistent & !(analysis$range_position <= contract$lower_threshold & analysis$lower_count5 >= contract$persistence_required)) |
    (analysis$range_state == "UPPER_PERSISTENT" & !analysis$upper_persistent) |
    (analysis$range_state == "LOWER_PERSISTENT" & !analysis$lower_persistent), na.rm = TRUE)
event_violations <- 0L
active <- analysis[analysis$breakout_event_active, , drop = FALSE]
if (nrow(active)) {
  event_violations <- event_violations + sum(active$breakout_age < 0L | active$breakout_age >= contract$event_sessions, na.rm = TRUE)
  event_groups <- split(active, paste(active$symbol, active$breakout_event_id))
  event_violations <- event_violations + sum(vapply(event_groups, function(z) length(unique(z$breakout_boundary)) != 1L || nrow(z) > contract$event_sessions || !identical(z$breakout_age, seq.int(min(z$breakout_age), max(z$breakout_age))), logical(1)))
}

stage_a_gates <- data.frame(
  gate = c("A1_DATA_AND_BOUNDARY", "A2_CLEAN_TREND_CALIBRATION", "A3_BREAKOUT_HOLD_FAIL_SEMANTICS", "A4_PRICE_SCALE_INVARIANCE", "A5_CAUSAL_APPEND_INVARIANCE", "A6_STATE_AND_EVENT_SEMANTICS", "A7_STATE_AND_POLICY_USABILITY"),
  threshold = c(">=120 prehistory; complete 26-asset analysis; 2024+ absent", "clean up/down terminal intended state each >=90%", "hold terminal-above and fail rapid-failure each >=90%", "range position invariant within 1e-12 and states identical", "all prior values exactly unchanged after future append", "zero state/event violations; fixed ten-session non-extending event boundary", ">=20/24 stocks at 10%-60% upper occupancy; >=18/24 have >=3 eligible fresh crosses"),
  observed = c(
    sprintf("%d/26 complete; min %d prehistory; max date %s", sum(coverage$coverage_status == "COMPLETE"), min(coverage$prehistory_sessions), max(analysis$session_date)),
    sprintf("clean up %.1f%% upper; clean down %.1f%% lower", 100 * up$upper_terminal_fraction, 100 * down$lower_terminal_fraction),
    sprintf("hold terminal-above %.1f%%; fail rapid-failure %.1f%%", 100 * hold$terminal_above_fraction, 100 * fail$rapid_failure_fraction),
    sprintf("max difference %.3g; states identical %s", scale_difference, scale_state_match), sprintf("%d/%d columns exact", sum(causality$passed), nrow(causality)),
    sprintf("%d state and %d event violations", state_violations, event_violations),
    sprintf("%d/24 occupancy-usable; %d/24 cross-usable; median occupancy %.1f%%", usable_occupancy, usable_crosses, 100 * median(primary_diag$upper_persistent_fraction))
  ),
  passed = c(
    all(coverage$coverage_status == "COMPLETE") && !any(analysis$session_date >= contract$confirmation_start),
    up$upper_terminal_fraction >= .90 && down$lower_terminal_fraction >= .90,
    hold$terminal_above_fraction >= .90 && fail$rapid_failure_fraction >= .90,
    scale_difference <= 1e-12 && scale_state_match, all(causality$passed), state_violations == 0L && event_violations == 0L,
    usable_occupancy >= 20L && usable_crosses >= 18L
  ), stringsAsFactors = FALSE)
stage_a_passed <- all(stage_a_gates$passed)

write_csv(registry, file.path(run_dir, "hyp_reg_12_1_registry.csv")); write_csv(coverage, file.path(run_dir, "hyp_reg_12_1_coverage.csv")); write_csv(ledger, ledger_cache)
write_csv(state_diagnostics, file.path(run_dir, "hyp_reg_12_1_state_diagnostics.csv")); write_csv(event_outcomes, file.path(run_dir, "hyp_reg_12_1_breakout_outcomes.csv"))
write_csv(synthetic_summary, file.path(run_dir, "hyp_reg_12_1_synthetic_summary.csv")); write_csv(causality, file.path(run_dir, "hyp_reg_12_1_causality_audit.csv")); write_csv(stage_a_gates, file.path(run_dir, "hyp_reg_12_1_stage_a_gates.csv"))

ink <- "#17202A"; blue <- "#3D8DFF"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#8A949E"; pale <- "#DCEBFA"; purple <- "#8666B8"
png_open <- function(name, width = 1800, height = 1000) grDevices::png(file.path(visual_dir, name), width = width, height = height, res = 160)

png_open("synthetic_calibration.png", 2000, 1100); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
ss <- synthetic_summary[match(c("CLEAN_DOWN", "RANDOM_WALK", "CLEAN_UP"), synthetic_summary$process), ]; barplot(rbind(100 * ss$median_lower_fraction, 100 * ss$median_upper_fraction), beside = TRUE, names.arg = c("Clean down", "Random walk", "Clean up"), col = c(red, green), border = NA, las = 2, ylab = "Persistent-state occupancy (%)", main = "Synthetic trend ordering", legend.text = c("LOWER", "UPPER"), args.legend = list(x = "top", bty = "n"))
hf <- synthetic_summary[match(c("BREAKOUT_HOLD", "BREAKOUT_FAIL"), synthetic_summary$process), ]; barplot(rbind(100 * hf$terminal_above_fraction, 100 * hf$rapid_failure_fraction), beside = TRUE, names.arg = c("Breakout hold", "Breakout fail"), col = c(green, red), border = NA, ylim = c(0,100), ylab = "Paths (%)", main = "Fixed-boundary event semantics", legend.text = c("Terminal above", "Rapid failure"), args.legend = list(x = "top", bty = "n")); dev.off()

png_open("state_usability.png", 2000, 1100); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
barplot(100 * primary_diag$upper_persistent_fraction, names.arg = primary_diag$symbol, col = green, border = NA, las = 2, ylab = "Analysis sessions (%)", main = "UPPER_PERSISTENT occupancy"); abline(h = c(10,60), lty = 2, col = red)
barplot(primary_diag$eligible_crosses, names.arg = primary_diag$symbol, col = blue, border = NA, las = 2, ylab = "Fresh SMA8/14 crosses", main = "Entry-contact opportunities"); abline(h = 3, lty = 2, col = red); dev.off()

png_open("breakout_behavior.png"); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1)); by_symbol <- do.call(rbind, lapply(split(event_outcomes[event_outcomes$symbol %in% stocks, ], event_outcomes$symbol[event_outcomes$symbol %in% stocks]), function(z) data.frame(symbol = z$symbol[[1L]], events = nrow(z), rapid_failure = mean(z$rapid_failure), terminal_above = mean(z$terminal_above))))
barplot(100 * by_symbol$rapid_failure, names.arg = by_symbol$symbol, col = red, border = NA, las = 2, ylab = "Events (%)", main = "Rapid breakout failure")
barplot(100 * by_symbol$terminal_above, names.arg = by_symbol$symbol, col = green, border = NA, las = 2, ylab = "Events (%)", main = "Still above boundary at day 10"); dev.off()

state_cols <- c(LOWER_PERSISTENT = "#F3A6A2", OTHER = "#E6E6E6", UPPER_PERSISTENT = "#A7D7B8")
png_open("representative_measurement_tapes.png", 2200, 2100); layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
for (symbol in c("AMD", "TSLA", "TXN", "SPY")) {
  z <- analysis[analysis$symbol == symbol & !is.na(analysis$range_state), , drop = FALSE]; groups <- cumsum(c(TRUE, z$range_state[-1L] != head(z$range_state, -1L)))
  plot(z$session_date, z$close, type = "n", xlab = "", ylab = "Adjusted close", main = paste(symbol, "price and range state")); usr <- par("usr")
  for (g in unique(groups)) { q <- z[groups == g, ]; rect(min(q$session_date), usr[[3L]], max(q$session_date) + 1, usr[[4L]], col = adjustcolor(state_cols[[q$range_state[[1L]]]], .55), border = NA) }
  lines(z$session_date, z$close, col = ink, lwd = 1.3); points(z$session_date[z$new_breakout], z$close[z$new_breakout], pch = 24, bg = blue, col = blue, cex = .6)
  plot(z$session_date, z$range_position, type = "l", col = blue, lwd = 1.1, xlab = "Session", ylab = "Range position", main = "63-session location and persistence"); abline(h = c(0, .25, .75, 1), col = c(gray, red, green, gray), lty = c(3,2,2,3)); points(z$session_date[z$upper_persistent], z$range_position[z$upper_persistent], pch = 16, col = green, cex = .35)
}
dev.off()

stage_a_status <- if (stage_a_passed) "PASS_STAGE_A_CONSTRUCTION" else "STOP_RANGE_PERSISTENCE_STAGE_A_FAILED_STRATEGY_NOT_RUN"
run_spec <- data.frame(hypothesis_id = contract$hypothesis_id, status = stage_a_status, evidence_stage = contract$evidence_stage, as_of_timestamp = contract$as_of_timestamp,
  analysis_start = contract$analysis_start, analysis_end = contract$analysis_end, confirmation_start = contract$confirmation_start, range_window = contract$range_window,
  upper_threshold = contract$upper_threshold, persistence_rule = sprintf("%d_of_%d", contract$persistence_required, contract$persistence_window), event_sessions = contract$event_sessions,
  confirmation_2024_plus = "SEALED", stringsAsFactors = FALSE)
write_csv(run_spec, file.path(run_dir, "hyp_reg_12_1_run_spec.csv"))

if (!stage_a_passed) {
  report <- c("# HYP-REG-12.1 Causal Upper-Range Persistence", "", paste0("Status: `", stage_a_status, "`"), "", "## Frozen Question", "", "Can sustained upper-range residence improve fresh next-open entries in the unchanged daily SMA8/SMA14 parent?", "", "## Stage A", "", sprintf("Stage A passed %d/%d gates. Strategy outcomes were not accessed.", sum(stage_a_gates$passed), nrow(stage_a_gates)), "", "## Boundary", "", "This is reused-window development evidence. No parameter rescue, direct breakout strategy, ATR join, or 2024+ confirmation was accessed.")
  writeLines(report, file.path(run_dir, "hyp_reg_12_1_report.md")); writeLines(stage_a_status, file.path(run_dir, "STATUS.txt")); message(stage_a_status); print(stage_a_gates, row.names = FALSE); quit(save = "no", status = 0L)
}

message("HYP-REG-12.1 Stage A passed; entering the frozen SMA8/14 strategy-relative replay.")
prior_daily_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_01_2_strategy_overlay_20260814", "hyp_reg_01_2_reconstructed_daily.rds")
parent_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "intraday_momentum_poc_series_20260813", "fixed_sma_summaries.csv")
if (!file.exists(prior_daily_path) || !file.exists(parent_path)) hreg121_stop("Retained daily parent evidence is unavailable.")
daily <- readRDS(prior_daily_path); daily$session_date <- as.Date(daily$session_date); daily <- daily[daily$session_date < contract$confirmation_start & daily$symbol %in% registry$symbol, , drop = FALSE]
states <- hreg121_validate_ledger(ledger, contract)
strategy_coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- daily[daily$symbol == reg$symbol & daily$session_date >= contract$analysis_start & daily$session_date <= contract$analysis_end, , drop = FALSE]
  s <- states[states$symbol == reg$symbol & states$session_date >= contract$analysis_start & states$session_date <= contract$analysis_end, , drop = FALSE]; idx <- match(x$session_date, s$session_date); missing_state <- sum(is.na(idx) | is.na(s$range_state[idx]))
  data.frame(instance_id = reg$instance_id, symbol = reg$symbol, strategy_sessions = nrow(x), state_sessions = nrow(s), missing_state_dates = length(setdiff(x$session_date, s$session_date)), state_only_dates = length(setdiff(s$session_date, x$session_date)), missing_states = missing_state,
    status = if (nrow(x) == 1499L && nrow(s) == 1509L && !length(setdiff(x$session_date, s$session_date)) && length(setdiff(s$session_date, x$session_date)) == 10L && missing_state == 0L) "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS" else "REVIEW")
}))
if (any(strategy_coverage$status != "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS")) hreg121_stop("Daily/range-state calendar alignment failed.")

scenario_table <- data.frame(scenario = c("PRIMARY", "STRESS"), bps = c(contract$primary_bps, contract$stress_bps))
summaries <- list(); trades <- list(); paths_all <- list(); aligned_by_symbol <- list(); k <- 0L; tk <- 0L; pk <- 0L
for (symbol in registry$symbol) {
  x <- daily[daily$symbol == symbol, , drop = FALSE]; x <- x[order(x$session_date), , drop = FALSE]
  frame <- hreg121_align(hreg12_cross_frame(x, contract$fast, contract$slow), states[states$symbol == symbol, , drop = FALSE]); aligned_by_symbol[[symbol]] <- frame; reg <- registry[match(symbol, registry$symbol), , drop = FALSE]
  for (year in contract$years) {
    start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start); end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end)
    schedules <- lapply(contract$policies, function(p) hreg121_schedule(frame, start, end, p)); names(schedules) <- contract$policies
    schedules$BUY_HOLD <- imom_buy_hold_schedule(x, start, end); schedules$CASH <- schedules$UNFILTERED; schedules$CASH$target <- FALSE; schedules$CASH$entry_signal <- FALSE; schedules$CASH$exit_signal <- FALSE
    block_frame <- frame[frame$session_date >= start & frame$session_date <= end, , drop = FALSE]
    for (policy in names(schedules)) for (si in seq_len(nrow(scenario_table))) {
      scenario <- scenario_table[si, , drop = FALSE]; replay <- imom_replay(x, start, end, schedules[[policy]], 1, scenario$bps, 0, scenario$scenario, 252L, imom)
      q <- replay$summary; q$policy <- policy; q$year <- year; q$sector <- reg$sector; q$asset_type <- reg$asset_type; q$strategy_role <- reg$strategy_role; k <- k + 1L; summaries[[k]] <- q
      if (scenario$scenario == "PRIMARY" && policy %in% contract$policies) {
        t <- hreg121_label_trades(replay$trades, block_frame); if (nrow(t)) { t$policy <- policy; t$year <- year; t$sector <- reg$sector; t$strategy_role <- reg$strategy_role; tk <- tk + 1L; trades[[tk]] <- t }
        w <- replay$path; for (column in c("sma_fast", "sma_slow", "range_state", "range_position", "upper_count5", "upper_persistent")) w[[column]] <- block_frame[[column]]; w$blocked_entry <- schedules[[policy]]$blocked_entry; w$policy <- policy; w$year <- year; w$sector <- reg$sector; w$strategy_role <- reg$strategy_role; pk <- pk + 1L; paths_all[[pk]] <- w
      }
    }
  }
}
summaries <- do.call(rbind, summaries); trades <- do.call(rbind, trades); paths_all <- do.call(rbind, paths_all)

parent <- utils::read.csv(parent_path, stringsAsFactors = FALSE); parent <- parent[parent$frequency == "DAILY" & parent$policy == "SMA8_14" & parent$scenario == "PRIMARY" & parent$delay_bars == 0 & parent$leverage == 1, c("symbol", "year", "total_return")]; names(parent)[[3L]] <- "parent_total_return"
reproduction <- merge(summaries[summaries$policy == "UNFILTERED" & summaries$scenario == "PRIMARY", c("symbol", "year", "total_return")], parent, by = c("symbol", "year"), all = TRUE)
reproduction$absolute_difference <- abs(reproduction$total_return - reproduction$parent_total_return); reproduction$passed <- is.finite(reproduction$absolute_difference) & reproduction$absolute_difference <= contract$reproduction_tolerance
if (!all(reproduction$passed)) hreg121_stop(sprintf("Parent reproduction failed; maximum difference %.12g.", max(reproduction$absolute_difference, na.rm = TRUE)))

message("HYP-REG-12.1 running 200 deterministic within-asset/year circular eligibility controls.")
control_cache <- file.path(run_dir, "hyp_reg_12_1_control_cells.csv")
if (file.exists(control_cache) && !env_bool("GEN5_HYP_REG_121_REBUILD_CONTROLS", FALSE)) { controls <- utils::read.csv(control_cache, stringsAsFactors = FALSE) } else {
  controls <- vector("list", length(stocks) * length(contract$years) * contract$placebo_simulations); ck <- 0L
  for (symbol in stocks) { x <- daily[daily$symbol == symbol, , drop = FALSE]; frame <- aligned_by_symbol[[symbol]]
    for (year in contract$years) { start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start); end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end); w <- x[x$session_date >= start & x$session_date <= end, , drop = FALSE]
      for (simulation_id in seq_len(contract$placebo_simulations)) { schedule <- hreg121_shifted_schedule(frame, start, end, simulation_id, contract); ck <- ck + 1L
        controls[[ck]] <- data.frame(symbol = symbol, year = year, simulation_id = simulation_id, shift_offset = attr(schedule, "shift_offset"), exposure = mean(schedule$target), blocked_entries = sum(schedule$blocked_entry), total_return = imom_fast_terminal_from_schedule(w, schedule, 1, contract$primary_bps, 0, imom)) }
    }
  }
  controls <- do.call(rbind, controls); write_csv(controls, control_cache)
}
control_panel <- do.call(rbind, lapply(split(controls, controls$simulation_id), function(x) data.frame(simulation_id = x$simulation_id[[1L]], cells = nrow(x), median_return = median_na(x$total_return), median_exposure = median_na(x$exposure), positive_fraction = mean(x$total_return > 0))))

primary <- summaries[summaries$strategy_role == "primary_stock" & summaries$scenario == "PRIMARY", , drop = FALSE]
policy_panel <- hreg121_policy_panel(primary); policy_panel <- policy_panel[match(c("UNFILTERED", "ENTRY_UPPER_PERSISTENT_ONLY", "BUY_HOLD", "CASH"), policy_panel$policy), , drop = FALSE]
parent_cells <- primary[primary$policy == "UNFILTERED", , drop = FALSE]; overlay_cells <- primary[primary$policy == "ENTRY_UPPER_PERSISTENT_ONLY", , drop = FALSE]
paired <- merge(parent_cells[c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure", "turnover", "trade_count")], overlay_cells[c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure", "turnover", "trade_count")], by = c("symbol", "year"), suffixes = c("_parent", "_overlay"))
paired$return_excess <- paired$total_return_overlay - paired$total_return_parent; paired$drawdown_change <- paired$maximum_drawdown_overlay - paired$maximum_drawdown_parent; paired$sharpe_change <- paired$sharpe_overlay - paired$sharpe_parent
comp <- hreg121_compound_by_asset(primary[primary$policy %in% contract$policies, , drop = FALSE]); pcomp <- comp[comp$policy == "UNFILTERED", c("symbol", "compounded_return")]; names(pcomp)[[2L]] <- "parent_compounded_return"; ocomp <- comp[comp$policy == "ENTRY_UPPER_PERSISTENT_ONLY", c("symbol", "compounded_return")]; names(ocomp)[[2L]] <- "overlay_compounded_return"
asset_summary <- merge(pcomp, ocomp, by = "symbol"); asset_summary$compounded_excess <- asset_summary$overlay_compounded_return - asset_summary$parent_compounded_return
year_summary <- do.call(rbind, lapply(split(paired, paired$year), function(x) data.frame(year = x$year[[1L]], cells = nrow(x), median_excess = median_na(x$return_excess), improvement_fraction = mean(x$return_excess > 0), median_drawdown_change = median_na(x$drawdown_change), median_sharpe_change = median_na(x$sharpe_change))))
actual <- policy_panel[policy_panel$policy == "ENTRY_UPPER_PERSISTENT_ONLY", , drop = FALSE]; parent_row <- policy_panel[policy_panel$policy == "UNFILTERED", , drop = FALSE]
near_ids <- hreg121_exposure_near_ids(control_panel, actual$median_exposure, contract$exposure_near_count); control_panel$exposure_near <- control_panel$simulation_id %in% near_ids; near <- control_panel[control_panel$exposure_near, , drop = FALSE]
timing_percentile <- hreg121_midrank_percentile(actual$median_return, near$median_return); timing_excess <- actual$median_return - median_na(near$median_return)
placebo_readout <- data.frame(policy = "ENTRY_UPPER_PERSISTENT_ONLY", actual_return = actual$median_return, actual_exposure = actual$median_exposure, percentile = timing_percentile, excess_vs_control_median = timing_excess, near_controls = nrow(near))

strategy_gates <- data.frame(
  gate = c("G1_CAUSAL_DATA_AND_CALENDAR", "G2_PARENT_REPRODUCTION", "G3_CONSTRUCTION_AND_SEMANTICS", "G4_PANEL_RETURN", "G5_ASSET_BREADTH", "G6_CALENDAR_BREADTH", "G7_PROTECTION_AND_SHARPE", "G8_ABSOLUTE_VIABILITY", "G9_TIMING_SPECIFICITY"),
  threshold = c("26/26 aligned; 24 primary stocks; 2024+ absent", "156/156 annual cells exact", "all frozen Stage A gates pass", "overlay median annual return > parent", ">=15/24 stocks improve over six years", ">=4/6 years have positive median excess", "median maximum drawdown no worse and median Sharpe no lower", "positive absolute median annual return", ">=80th percentile and above median of 40 exposure-nearest controls"),
  observed = c(sprintf("%d/26 complete; max date %s", sum(strategy_coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS"), max(daily$session_date)), sprintf("%d/%d; max difference %.3g", sum(reproduction$passed), nrow(reproduction), max(reproduction$absolute_difference)), sprintf("%d/%d Stage A gates", sum(stage_a_gates$passed), nrow(stage_a_gates)), sprintf("%s vs %s", fmt_pct(actual$median_return), fmt_pct(parent_row$median_return)), sprintf("%d/24 improved", sum(asset_summary$compounded_excess > 0)), sprintf("%d/6 positive years", sum(year_summary$median_excess > 0)), sprintf("drawdown %s; Sharpe %+.3f", fmt_pct(actual$median_drawdown - parent_row$median_drawdown), actual$median_sharpe - parent_row$median_sharpe), fmt_pct(actual$median_return), sprintf("%.1fth percentile; %s vs controls", 100 * timing_percentile, fmt_pct(timing_excess))),
  passed = c(all(strategy_coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS") && !any(daily$session_date >= contract$confirmation_start), all(reproduction$passed), all(stage_a_gates$passed), actual$median_return > parent_row$median_return, sum(asset_summary$compounded_excess > 0) >= 15L, sum(year_summary$median_excess > 0) >= 4L, actual$median_drawdown >= parent_row$median_drawdown && actual$median_sharpe >= parent_row$median_sharpe, actual$median_return > 0, is.finite(timing_percentile) && timing_percentile >= .80 && timing_excess > 0), stringsAsFactors = FALSE)
all_passed <- all(strategy_gates$passed); status <- if (all_passed) "PASS_TO_CONFIRMATION_DISCUSSION" else "STOP_RANGE_PERSISTENCE_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN"
decision <- data.frame(policy = "ENTRY_UPPER_PERSISTENT_ONLY", gates_passed = sum(strategy_gates$passed), gates_total = nrow(strategy_gates), all_passed = all_passed, status = status)

parent_trades <- trades[trades$policy == "UNFILTERED" & trades$strategy_role == "primary_stock", , drop = FALSE]
parent_trades$entry_group <- ifelse(parent_trades$entry_range_state == "UPPER_PERSISTENT", "UPPER_PERSISTENT", ifelse(parent_trades$entry_range_position >= contract$upper_threshold, "UPPER_NOT_PERSISTENT", "OTHER"))
entry_state_audit <- do.call(rbind, lapply(split(parent_trades, parent_trades$entry_group), function(x) data.frame(entry_group = x$entry_group[[1L]], trades = nrow(x), hit_rate = mean(x$net_return > 0), mean_trade = mean_na(x$net_return), median_trade = median_na(x$net_return), median_holding = median_na(x$holding_bars), median_range_position = median_na(x$entry_range_position))))

write_csv(strategy_coverage, file.path(run_dir, "hyp_reg_12_1_strategy_coverage.csv")); write_csv(reproduction, file.path(run_dir, "hyp_reg_12_1_parent_reproduction.csv")); write_csv(summaries, file.path(run_dir, "hyp_reg_12_1_summaries.csv")); write_csv(trades, file.path(run_dir, "hyp_reg_12_1_trades.csv")); write_csv(policy_panel, file.path(run_dir, "hyp_reg_12_1_policy_panel.csv"))
write_csv(paired, file.path(run_dir, "hyp_reg_12_1_paired_cells.csv")); write_csv(asset_summary, file.path(run_dir, "hyp_reg_12_1_asset_summary.csv")); write_csv(year_summary, file.path(run_dir, "hyp_reg_12_1_year_summary.csv")); write_csv(entry_state_audit, file.path(run_dir, "hyp_reg_12_1_entry_state_audit.csv")); write_csv(controls, control_cache); write_csv(control_panel, file.path(run_dir, "hyp_reg_12_1_control_panel.csv")); write_csv(placebo_readout, file.path(run_dir, "hyp_reg_12_1_placebo_readout.csv")); write_csv(strategy_gates, file.path(run_dir, "hyp_reg_12_1_strategy_gates.csv")); write_csv(decision, file.path(run_dir, "hyp_reg_12_1_decision.csv"))
run_spec$status <- status; run_spec$primary_bps <- contract$primary_bps; run_spec$stress_bps <- contract$stress_bps; run_spec$leverage <- 1; write_csv(run_spec, file.path(run_dir, "hyp_reg_12_1_run_spec.csv"))

plot_primary <- primary[primary$policy %in% c("UNFILTERED", "ENTRY_UPPER_PERSISTENT_ONLY", "BUY_HOLD"), , drop = FALSE]; plot_primary$policy <- factor(plot_primary$policy, levels = c("UNFILTERED", "ENTRY_UPPER_PERSISTENT_ONLY", "BUY_HOLD"))
png_open("policy_performance.png"); par(mfrow = c(1, 2), mar = c(7, 5, 4, 1)); boxplot(total_return * 100 ~ policy, data = plot_primary, col = c(gray, green, orange), border = ink, outline = FALSE, xlab = "", ylab = "Annual return (%)", xaxt = "n", main = "Return after 5 bp per side"); axis(1, at = 1:3, labels = c("Parent", "Upper persistent", "Buy & hold"), las = 2); abline(h = 0, lty = 2); boxplot(maximum_drawdown * 100 ~ policy, data = plot_primary, col = c(gray, green, orange), border = ink, outline = FALSE, xlab = "", ylab = "Maximum drawdown (%)", xaxt = "n", main = "Protection bargain"); axis(1, at = 1:3, labels = c("Parent", "Upper persistent", "Buy & hold"), las = 2); dev.off()

png_open("asset_breadth.png", 1600, 1200); z <- asset_summary[order(asset_summary$compounded_excess), ]; barplot(z$compounded_excess * 100, names.arg = z$symbol, horiz = TRUE, las = 1, col = ifelse(z$compounded_excess > 0, green, red), border = NA, xlab = "Upper-persistence overlay minus parent six-year return (pp)", main = "Transport across 24 stocks"); abline(v = 0, col = ink, lwd = 1.5); dev.off()

png_open("calendar_and_controls.png"); par(mfrow = c(1, 2), mar = c(5, 5, 4, 1)); barplot(year_summary$median_excess * 100, names.arg = year_summary$year, col = ifelse(year_summary$median_excess > 0, green, red), border = NA, ylab = "Median excess (pp)", main = "Calendar breadth"); abline(h = 0, col = ink); hist(near$median_return * 100, breaks = 12, col = pale, border = "white", xlab = "Panel median annual return (%)", main = "Exposure-nearest timing controls"); abline(v = 100 * actual$median_return, col = green, lwd = 3); legend("topright", sprintf("Actual %.2f%%\nPercentile %.1f", 100 * actual$median_return, 100 * timing_percentile), bty = "n"); dev.off()

png_open("entry_state_audit.png"); par(mfrow = c(1, 2), mar = c(7, 5, 4, 1)); groups_entry <- c("OTHER", "UPPER_NOT_PERSISTENT", "UPPER_PERSISTENT"); short_groups <- c("Other", "Upper only", "Persistent"); parent_trades$entry_group_short <- short_groups[match(parent_trades$entry_group, groups_entry)]; boxplot(net_return * 100 ~ factor(entry_group_short, levels = short_groups), data = parent_trades, col = c(gray, pale, green), border = ink, outline = FALSE, xlab = "Range state at parent entry", ylab = "Parent trade return (%)", main = "What persistence selects", las = 2); abline(h = 0, lty = 2); audit_plot <- entry_state_audit[match(groups_entry, entry_state_audit$entry_group), , drop = FALSE]; barplot(audit_plot$trades, names.arg = short_groups, col = c(gray, pale, green), border = NA, ylab = "Parent trades", main = "Opportunity count", las = 2); dev.off()

best <- paired[which.max(paired$return_excess), c("symbol", "year")]; worst <- paired[which.min(paired$return_excess), c("symbol", "year")]; ordered_near <- paired[order(abs(paired$return_excess - median(paired$return_excess))), c("symbol", "year")]; canonical <- paired[paired$symbol == "AMD", c("symbol", "year")][1L, , drop = FALSE]
selected <- unique(rbind(data.frame(best, role = "LARGEST_IMPROVEMENT"), data.frame(worst, role = "LARGEST_DEGRADATION"), data.frame(ordered_near[1L, ], role = "NEAR_MEDIAN"), data.frame(canonical, role = "CANONICAL_AMD"))); write_csv(selected, file.path(run_dir, "hyp_reg_12_1_representative_selection.csv"))
png_open("representative_strategy_tapes.png", 2200, 2200); layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
for (i in seq_len(nrow(selected))) { pick <- selected[i, ]; u <- paths_all[paths_all$symbol == pick$symbol & paths_all$year == pick$year & paths_all$policy == "UNFILTERED", , drop = FALSE]; o <- paths_all[paths_all$symbol == pick$symbol & paths_all$year == pick$year & paths_all$policy == "ENTRY_UPPER_PERSISTENT_ONLY", , drop = FALSE]; display_state <- o$range_state; display_state[is.na(display_state)] <- "OTHER"; groups_run <- cumsum(c(TRUE, display_state[-1L] != head(display_state, -1L)))
  plot(o$session_date, o$close, type = "n", xlab = "", ylab = "Close", main = paste(pick$role, "-", pick$symbol, pick$year)); usr <- par("usr"); for (g in unique(groups_run)) { q <- o[groups_run == g, ]; state <- display_state[which(groups_run == g)[[1L]]]; rect(min(q$session_date), usr[[3L]], max(q$session_date) + 1, usr[[4L]], col = adjustcolor(state_cols[[state]], .55), border = NA) }; lines(o$session_date, o$close, col = ink, lwd = 1.3); lines(o$session_date, o$sma_fast, col = blue); lines(o$session_date, o$sma_slow, col = orange); long <- which(o$target); if (length(long)) points(o$session_date[long], rep(usr[[3L]] + .03 * diff(usr[3:4]), length(long)), pch = 15, col = green, cex = .45)
  plot(o$session_date, u$equity / contract$initial_wealth - 1, type = "l", col = gray, lwd = 1.5, xlab = "Session", ylab = "Return", main = "Parent versus upper-persistence gate"); lines(o$session_date, o$equity / contract$initial_wealth - 1, col = green, lwd = 2); abline(h = 0, lty = 3); legend("topleft", c("Parent", "Upper persistent"), col = c(gray, green), lwd = c(1.5, 2), bty = "n", cex = .8)
}
dev.off()

report <- c("# HYP-REG-12.1 Causal Upper-Range Persistence", "", paste0("Status: `", status, "`"), "", "## Frozen Question", "", "Can sustained upper-range residence improve fresh next-open entries in the unchanged daily SMA8/SMA14 parent?", "", "## Construction", "", "The state uses the current close's uncapped location in the preceding 63-session close range. UPPER_PERSISTENT requires the current location to be at least 0.75 and at least three of the latest five causal observations to meet that threshold. A separate ten-session fixed-boundary event ledger describes breakout hold and failure behavior.", "", "## Stage A", "", sprintf("%d/%d construction gates passed before strategy access. Median UPPER_PERSISTENT occupancy was %.1f%% and %d/24 stocks had at least three eligible fresh parent crosses.", sum(stage_a_gates$passed), nrow(stage_a_gates), 100 * median(primary_diag$upper_persistent_fraction), usable_crosses), "", "## Strategy Readout", "", sprintf("The upper-persistence fresh-entry overlay passed %d/%d strategy gates. Parent median annual return was %s; overlay was %s; timing-control percentile was %.1f.", sum(strategy_gates$passed), nrow(strategy_gates), fmt_pct(parent_row$median_return), fmt_pct(actual$median_return), 100 * timing_percentile), "", "## Boundary", "", "This is reused-window DEVELOPMENT evidence. No threshold or range length was tuned, no direct breakout strategy or ATR join was opened, and 2024+ confirmation remained sealed.")
writeLines(report, file.path(run_dir, "hyp_reg_12_1_report.md")); writeLines(status, file.path(run_dir, "STATUS.txt")); message(status); print(stage_a_gates, row.names = FALSE); print(strategy_gates, row.names = FALSE)
