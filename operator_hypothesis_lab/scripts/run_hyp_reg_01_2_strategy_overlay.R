options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
mean_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
fmt_pct <- function(x, digits = 2L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))

contract <- hreg12_contract()
imom <- imom_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_01_2_overlay_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
if (nrow(registry) != 26L || anyDuplicated(registry$symbol) || sum(registry$strategy_role == "primary_stock") != 24L) hreg12_stop("Frozen registry integrity failed.")
stocks <- registry$symbol[registry$strategy_role == "primary_stock"]

run_id <- env_or("GEN5_HYP_REG_012_RUN_ID", "hyp_reg_01_2_strategy_overlay_20260814")
run_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

state_path <- env_or("GEN5_HYP_REG_012_STATE_LEDGER", file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_01_1_atr_percent_20260814", "hyp_reg_01_1_daily_state_ledger.csv"))
parent_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "intraday_momentum_poc_series_20260813", "fixed_sma_summaries.csv")
if (!file.exists(state_path)) hreg12_stop("Accepted HYP-REG-01.1 state ledger is unavailable.")
if (!file.exists(parent_path)) hreg12_stop("Retained HYP-MOM-06.1 parent summaries are unavailable.")
states <- hreg12_validate_state_ledger(utils::read.csv(state_path, stringsAsFactors = FALSE), contract)
if (!setequal(unique(states$symbol), registry$symbol)) hreg12_stop("State-ledger symbols differ from the frozen registry.")

daily_cache <- file.path(run_dir, "hyp_reg_01_2_reconstructed_daily.rds")
if (file.exists(daily_cache) && !env_bool("GEN5_HYP_REG_012_REBUILD_DAILY", FALSE)) {
  message("HYP-REG-01.2 using retained reconstructed-daily cache.")
  daily <- readRDS(daily_cache)
} else {
  message("HYP-REG-01.2 reconstructing the parent daily surface from admitted 30-minute SIP bars.")
  cache_dir <- file.path(repo_root, "data_cache", "alpaca_intraday_30min")
  paths <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d.rds", 2017:2023))
  if (!all(file.exists(paths))) hreg12_stop("All 2017-2023 intraday cache years are required.")
  bars <- do.call(rbind, lapply(paths, readRDS))
  bars <- bars[bars$symbol %in% registry$symbol, , drop = FALSE]
  bars <- bars[!duplicated(bars[c("symbol", "timestamp_utc")]), , drop = FALSE]
  bars <- bars[order(bars$symbol, bars$timestamp_utc), , drop = FALSE]
  bars <- imom30_apply_archive_exclusions(imom30_apply_rth_calendar(bars))
  daily <- imom_aggregate_daily(bars)
  saveRDS(daily, daily_cache)
  rm(bars); invisible(gc())
}
daily$session_date <- as.Date(daily$session_date)
if (any(daily$session_date >= contract$confirmation_start)) daily <- daily[daily$session_date < contract$confirmation_start, , drop = FALSE]
if (!setequal(unique(daily$symbol), registry$symbol)) hreg12_stop("Reconstructed daily symbols differ from the frozen registry.")

coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]
  x <- daily[daily$symbol == reg$symbol & daily$session_date >= contract$analysis_start & daily$session_date <= contract$analysis_end, , drop = FALSE]
  s <- states[states$symbol == reg$symbol & states$session_date >= contract$analysis_start & states$session_date <= contract$analysis_end, , drop = FALSE]
  data.frame(instance_id = reg$instance_id, symbol = reg$symbol, sector = reg$sector, asset_type = reg$asset_type,
             strategy_role = reg$strategy_role, strategy_sessions = nrow(x), state_sessions = nrow(s),
             missing_state_dates = length(setdiff(x$session_date, s$session_date)), missing_strategy_dates = length(setdiff(s$session_date, x$session_date)),
             status = if (nrow(x) == 1499L && nrow(s) == 1509L && !length(setdiff(x$session_date, s$session_date)) && length(setdiff(s$session_date, x$session_date)) == 10L) "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS" else "REVIEW", stringsAsFactors = FALSE)
}))
if (any(coverage$status != "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS")) hreg12_stop("Daily/state calendar alignment failed.")

scenario_table <- data.frame(scenario = c("PRIMARY", "STRESS"), bps = c(contract$primary_bps, contract$stress_bps), financing = c(contract$primary_financing, contract$stress_financing))
summaries <- list(); trades <- list(); path_rows <- list(); k <- 0L; tk <- 0L; pk <- 0L
aligned_by_symbol <- list()

message("HYP-REG-01.2 replaying unfiltered, ATR_LOW_OFF, and buy-and-hold policies.")
for (symbol in registry$symbol) {
  x <- daily[daily$symbol == symbol, , drop = FALSE]
  x <- x[order(x$session_date), , drop = FALSE]
  frame <- hreg12_align_states(hreg12_cross_frame(x, contract$fast, contract$slow), states[states$symbol == symbol, , drop = FALSE])
  aligned_by_symbol[[symbol]] <- frame
  reg <- registry[match(symbol, registry$symbol), , drop = FALSE]
  for (year in contract$years) {
    start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start)
    end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end)
    unfiltered <- hreg12_schedule(frame, start, end, gate_low = FALSE)
    overlay <- hreg12_schedule(frame, start, end, gate_low = TRUE)
    buy_hold <- imom_buy_hold_schedule(x, start, end)
    schedules <- list(UNFILTERED = unfiltered, ATR_LOW_OFF = overlay, BUY_HOLD = buy_hold)
    for (policy in names(schedules)) for (leverage in contract$leverages) for (si in seq_len(nrow(scenario_table))) {
      scenario <- scenario_table[si, , drop = FALSE]
      replay <- imom_replay(x, start, end, schedules[[policy]], leverage, scenario$bps, scenario$financing,
                            scenario$scenario, 252L, imom)
      q <- replay$summary
      q$policy <- policy; q$year <- year; q$sector <- reg$sector; q$asset_type <- reg$asset_type; q$strategy_role <- reg$strategy_role
      k <- k + 1L; summaries[[k]] <- q
      if (scenario$scenario == "PRIMARY" && leverage == 1 && policy %in% c("UNFILTERED", "ATR_LOW_OFF")) {
        t <- replay$trades
        if (nrow(t)) {
          t <- hreg12_label_parent_trades(t, frame)
          t$policy <- policy; t$year <- year; t$sector <- reg$sector; t$strategy_role <- reg$strategy_role
          tk <- tk + 1L; trades[[tk]] <- t
        }
        w <- replay$path
        block_frame <- frame[frame$session_date >= start & frame$session_date <= end, , drop = FALSE]
        w$sma_fast <- block_frame$sma_fast; w$sma_slow <- block_frame$sma_slow; w$regime_state <- block_frame$regime_state
        w$policy <- policy; w$year <- year; w$sector <- reg$sector; w$strategy_role <- reg$strategy_role
        pk <- pk + 1L; path_rows[[pk]] <- w
      }
    }
  }
}
summaries <- do.call(rbind, summaries); rownames(summaries) <- NULL
trades <- if (length(trades)) do.call(rbind, trades) else data.frame()
paths_all <- do.call(rbind, path_rows); rownames(paths_all) <- NULL

parent <- utils::read.csv(parent_path, stringsAsFactors = FALSE)
parent <- parent[parent$frequency == "DAILY" & parent$policy == "SMA8_14" & parent$scenario == "PRIMARY" & parent$delay_bars == 0 & parent$leverage == 1,
                 c("symbol", "year", "total_return")]
names(parent)[[3L]] <- "parent_total_return"
reproduction <- merge(summaries[summaries$policy == "UNFILTERED" & summaries$scenario == "PRIMARY" & summaries$leverage == 1,
                                  c("symbol", "year", "total_return")], parent, by = c("symbol", "year"), all = TRUE)
reproduction$absolute_difference <- abs(reproduction$total_return - reproduction$parent_total_return)
reproduction$passed <- is.finite(reproduction$absolute_difference) & reproduction$absolute_difference <= contract$reproduction_tolerance
if (!all(reproduction$passed)) hreg12_stop(sprintf("Parent reproduction failed; maximum difference %.12g.", max(reproduction$absolute_difference, na.rm = TRUE)))

message("HYP-REG-01.2 running 200 deterministic circular-state controls on the 24-stock primary panel.")
control_cell_path <- file.path(run_dir, "hyp_reg_01_2_placebo_cells.csv")
if (file.exists(control_cell_path) && !env_bool("GEN5_HYP_REG_012_REBUILD_CONTROLS", FALSE)) {
  message("HYP-REG-01.2 using retained circular-state controls.")
  controls <- utils::read.csv(control_cell_path, stringsAsFactors = FALSE)
} else {
  controls <- vector("list", length(stocks) * length(contract$years) * contract$placebo_simulations); ck <- 0L
  for (symbol in stocks) {
    x <- daily[daily$symbol == symbol, , drop = FALSE]; frame <- aligned_by_symbol[[symbol]]
    for (year in contract$years) {
      start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start)
      end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end)
      w <- x[x$session_date >= start & x$session_date <= end, , drop = FALSE]
      for (simulation_id in seq_len(contract$placebo_simulations)) {
        schedule <- hreg12_shifted_schedule(frame, start, end, simulation_id, contract)
        ck <- ck + 1L
        controls[[ck]] <- data.frame(symbol = symbol, year = year, simulation_id = simulation_id,
                                     shift_offset = attr(schedule, "shift_offset"), exposure = mean(schedule$target),
                                     blocked_entries = sum(schedule$blocked_entry),
                                     total_return = imom_fast_terminal_from_schedule(w, schedule, 1, contract$primary_bps, contract$primary_financing, imom),
                                     stringsAsFactors = FALSE)
      }
    }
  }
  controls <- do.call(rbind, controls)
  write_csv(controls, control_cell_path)
}
control_panel <- do.call(rbind, lapply(split(controls, controls$simulation_id), function(x) data.frame(
  simulation_id = x$simulation_id[[1L]], cells = nrow(x), median_return = median_na(x$total_return),
  median_exposure = median_na(x$exposure), positive_fraction = mean(x$total_return > 0), stringsAsFactors = FALSE
)))
control_panel <- control_panel[order(control_panel$simulation_id), , drop = FALSE]

primary <- summaries[summaries$strategy_role == "primary_stock" & summaries$scenario == "PRIMARY" & summaries$leverage == 1, , drop = FALSE]
actual_overlay <- primary[primary$policy == "ATR_LOW_OFF", , drop = FALSE]
actual_unfiltered <- primary[primary$policy == "UNFILTERED", , drop = FALSE]
actual_exposure <- median_na(actual_overlay$exposure)
near_ids <- hreg12_exposure_near_ids(control_panel, actual_exposure, contract$exposure_near_count)
control_panel$exposure_near <- control_panel$simulation_id %in% near_ids
near_controls <- control_panel[control_panel$exposure_near, , drop = FALSE]
actual_return <- median_na(actual_overlay$total_return)
actual_placebo_percentile <- hreg12_midrank_percentile(actual_return, near_controls$median_return)
actual_placebo_excess <- actual_return - median_na(near_controls$median_return)

policy_panel <- do.call(rbind, lapply(split(primary, primary$policy), function(x) data.frame(
  policy = x$policy[[1L]], cells = nrow(x), median_return = median_na(x$total_return), positive_fraction = mean(x$total_return > 0),
  median_sharpe = median_na(x$sharpe), median_drawdown = median_na(x$maximum_drawdown), median_exposure = median_na(x$exposure),
  total_trades = sum(x$trade_count), median_hit_rate = median_na(x$hit_rate), median_trade = median_na(x$median_trade),
  median_holding_bars = median_na(x$median_holding_bars), stringsAsFactors = FALSE)
))
policy_panel <- policy_panel[match(c("UNFILTERED", "ATR_LOW_OFF", "BUY_HOLD"), policy_panel$policy), , drop = FALSE]

paired <- merge(actual_overlay[, c("symbol", "year", "total_return", "sharpe", "maximum_drawdown", "exposure", "trade_count")],
                actual_unfiltered[, c("symbol", "year", "total_return", "sharpe", "maximum_drawdown", "exposure", "trade_count")],
                by = c("symbol", "year"), suffixes = c("_overlay", "_unfiltered"))
paired$return_excess <- paired$total_return_overlay - paired$total_return_unfiltered
paired$drawdown_improvement <- paired$maximum_drawdown_overlay - paired$maximum_drawdown_unfiltered
paired$exposure_change <- paired$exposure_overlay - paired$exposure_unfiltered

year_summary <- do.call(rbind, lapply(split(paired, paired$year), function(x) data.frame(
  year = x$year[[1L]], stocks = nrow(x), median_overlay_return = median_na(x$total_return_overlay),
  median_unfiltered_return = median_na(x$total_return_unfiltered), median_excess = median_na(x$return_excess),
  improvement_fraction = mean(x$return_excess > 0), median_drawdown_improvement = median_na(x$drawdown_improvement), stringsAsFactors = FALSE)
))

asset_compound <- do.call(rbind, lapply(split(paired, paired$symbol), function(x) data.frame(
  symbol = x$symbol[[1L]], overlay_compounded_return = prod(1 + x$total_return_overlay) - 1,
  unfiltered_compounded_return = prod(1 + x$total_return_unfiltered) - 1,
  compounded_excess = prod(1 + x$total_return_overlay) - prod(1 + x$total_return_unfiltered),
  positive_years = sum(x$return_excess > 0), stringsAsFactors = FALSE)
))
asset_compound <- merge(asset_compound, registry[, c("symbol", "sector")], by = "symbol", all.x = TRUE)

parent_trades <- trades[trades$policy == "UNFILTERED", , drop = FALSE]
trade_audit <- do.call(rbind, lapply(split(parent_trades, interaction(parent_trades$entry_state, parent_trades$gate_disposition, drop = TRUE)), function(x) data.frame(
  entry_state = x$entry_state[[1L]], disposition = x$gate_disposition[[1L]], trades = nrow(x), hit_rate = mean(x$net_return > 0),
  mean_trade = mean_na(x$net_return), median_trade = median_na(x$net_return), q10_trade = as.numeric(stats::quantile(x$net_return, .10)),
  q90_trade = as.numeric(stats::quantile(x$net_return, .90)), median_holding = median_na(x$holding_bars), stringsAsFactors = FALSE)
))

overlay_entries <- trades[trades$policy == "ATR_LOW_OFF", c("symbol", "year", "entry_date")]
retained_entries <- parent_trades[parent_trades$gate_disposition == "RETAINED", c("symbol", "year", "entry_date")]
entry_set_match <- identical(sort(paste(overlay_entries$symbol, overlay_entries$year, overlay_entries$entry_date)),
                             sort(paste(retained_entries$symbol, retained_entries$year, retained_entries$entry_date)))

unfiltered_panel <- policy_panel[policy_panel$policy == "UNFILTERED", , drop = FALSE]
overlay_panel <- policy_panel[policy_panel$policy == "ATR_LOW_OFF", , drop = FALSE]
gates <- data.frame(
  gate = c("integrity", "parent_reproduction", "panel_return", "asset_breadth", "calendar_breadth", "protection_and_risk_adjustment", "absolute_viability", "regime_specificity"),
  passed = c(
    nrow(coverage) == 26L && all(coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS") && nrow(paired) == 144L && entry_set_match,
    nrow(reproduction) == 156L && all(reproduction$passed),
    overlay_panel$median_return > unfiltered_panel$median_return,
    sum(asset_compound$compounded_excess > 0) >= 15L,
    sum(year_summary$median_excess > 0) >= 4L,
    overlay_panel$median_drawdown >= unfiltered_panel$median_drawdown && overlay_panel$median_sharpe >= unfiltered_panel$median_sharpe,
    overlay_panel$median_return > 0,
    actual_placebo_percentile >= .80 && actual_placebo_excess > 0
  ),
  detail = c(
    sprintf("coverage=%d/26; primary_cells=%d/144; retained_entry_match=%s", sum(coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS"), nrow(paired), entry_set_match),
    sprintf("rows=%d/156; max_abs_diff=%.3g", nrow(reproduction), max(reproduction$absolute_difference)),
    sprintf("overlay=%s; unfiltered=%s; delta=%s", fmt_pct(overlay_panel$median_return), fmt_pct(unfiltered_panel$median_return), fmt_pct(overlay_panel$median_return - unfiltered_panel$median_return)),
    sprintf("improved_assets=%d/24", sum(asset_compound$compounded_excess > 0)),
    sprintf("positive_years=%d/6", sum(year_summary$median_excess > 0)),
    sprintf("drawdown_delta=%s; sharpe_delta=%.3f", fmt_pct(overlay_panel$median_drawdown - unfiltered_panel$median_drawdown), overlay_panel$median_sharpe - unfiltered_panel$median_sharpe),
    sprintf("overlay_median=%s", fmt_pct(overlay_panel$median_return)),
    sprintf("matched_percentile=%.1f%%; excess_vs_matched=%s", 100 * actual_placebo_percentile, fmt_pct(actual_placebo_excess))
  ), stringsAsFactors = FALSE
)
status <- if (all(gates$passed)) "PASS_TO_CONFIRMATION_DISCUSSION" else "STOP_DEVELOPMENT_OVERLAY_GATES_FAILED_CONFIRMATION_NOT_RUN"

secondary_source <- summaries[summaries$strategy_role == "primary_stock", , drop = FALSE]
secondary <- do.call(rbind, lapply(split(secondary_source, interaction(secondary_source$policy, secondary_source$leverage, secondary_source$scenario, drop = TRUE)), function(x) data.frame(
  policy = x$policy[[1L]], leverage = x$leverage[[1L]], scenario = x$scenario[[1L]], cells = nrow(x),
  median_return = median_na(x$total_return), median_sharpe = median_na(x$sharpe), median_drawdown = median_na(x$maximum_drawdown),
  median_exposure = median_na(x$exposure), maintenance_breaches = sum(x$maintenance_breach), stringsAsFactors = FALSE)
))

write_csv(registry, file.path(run_dir, "hyp_reg_01_2_registry.csv"))
write_csv(coverage, file.path(run_dir, "hyp_reg_01_2_coverage.csv"))
write_csv(reproduction, file.path(run_dir, "hyp_reg_01_2_parent_reproduction.csv"))
write_csv(summaries, file.path(run_dir, "hyp_reg_01_2_asset_year_summaries.csv"))
write_csv(trades, file.path(run_dir, "hyp_reg_01_2_trades.csv"))
write_csv(paired, file.path(run_dir, "hyp_reg_01_2_paired_primary.csv"))
write_csv(policy_panel, file.path(run_dir, "hyp_reg_01_2_policy_panel.csv"))
write_csv(year_summary, file.path(run_dir, "hyp_reg_01_2_year_summary.csv"))
write_csv(asset_compound, file.path(run_dir, "hyp_reg_01_2_asset_compound.csv"))
write_csv(trade_audit, file.path(run_dir, "hyp_reg_01_2_trade_audit.csv"))
write_csv(controls, file.path(run_dir, "hyp_reg_01_2_placebo_cells.csv"))
write_csv(control_panel, file.path(run_dir, "hyp_reg_01_2_placebo_panel.csv"))
write_csv(secondary, file.path(run_dir, "hyp_reg_01_2_secondary_summary.csv"))
write_csv(gates, file.path(run_dir, "hyp_reg_01_2_gates.csv"))
write_csv(data.frame(hypothesis_id = contract$hypothesis_id, status = status, evidence_stage = contract$evidence_stage,
                     as_of_timestamp = contract$as_of_timestamp, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end,
                     confirmation_start = contract$confirmation_start, primary_policy = "ATR_LOW_OFF", primary_assets = length(stocks),
                     placebo_simulations = contract$placebo_simulations, exposure_near_controls = contract$exposure_near_count,
                     strategy_authority = "DEVELOPMENT_ONLY", confirmation_2024_plus = "SEALED", stringsAsFactors = FALSE),
          file.path(run_dir, "hyp_reg_01_2_run_spec.csv"))

ink <- "#202630"; blue <- "#3D8DFF"; cyan <- "#6DCBF4"; orange <- "#F2A65A"; green <- "#2F8F5B"; red <- "#C8403A"; gray <- "#B8BCC4"; pale <- "#EDEDED"
png_open <- function(name, width = 1800, height = 1100) grDevices::png(file.path(visual_dir, name), width = width, height = height, res = 150)

png_open("policy_return_drawdown.png")
par(mfrow = c(1, 2), mar = c(6, 5, 4, 1))
boxplot(total_return * 100 ~ factor(policy, levels = c("BUY_HOLD", "UNFILTERED", "ATR_LOW_OFF")), data = primary,
        col = c(pale, gray, blue), border = ink, ylab = "Annual return (%)", xlab = "", main = "Same assets and years")
abline(h = 0, lty = 2, col = red)
boxplot(maximum_drawdown * 100 ~ factor(policy, levels = c("BUY_HOLD", "UNFILTERED", "ATR_LOW_OFF")), data = primary,
        col = c(pale, gray, blue), border = ink, ylab = "Maximum drawdown (%)", xlab = "", main = "Protection is part of the bargain")
dev.off()

png_open("asset_compounded_excess.png", 1800, 1300)
z <- asset_compound[order(asset_compound$compounded_excess), ]; cols <- ifelse(z$compounded_excess >= 0, green, red)
par(mar = c(5, 10, 4, 2)); barplot(z$compounded_excess * 100, names.arg = z$symbol, horiz = TRUE, las = 1, col = cols, border = NA,
                                  xlab = "Overlay minus unfiltered six-year compounded return (percentage points)", main = "Cross-asset breadth")
abline(v = 0, col = ink, lwd = 1.5)
dev.off()

png_open("calendar_breadth.png")
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
barplot(year_summary$median_excess * 100, names.arg = year_summary$year, col = ifelse(year_summary$median_excess >= 0, green, red), border = NA,
        ylab = "Median overlay excess (percentage points)", main = "Did the improvement repeat by year?"); abline(h = 0, col = ink)
barplot(year_summary$improvement_fraction * 100, names.arg = year_summary$year, col = blue, border = NA, ylim = c(0, 100),
        ylab = "Stocks improved (%)", main = "Breadth inside each year"); abline(h = 50, lty = 2, col = gray)
dev.off()

png_open("regime_alignment_placebo.png")
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
hist(near_controls$median_return * 100, breaks = 12, col = pale, border = "white", xlab = "Panel median annual return (%)", main = "40 exposure-nearest shifted-state controls")
abline(v = actual_return * 100, col = blue, lwd = 3); legend("topright", sprintf("Actual: %.2f%%\nPercentile: %.1f%%", 100 * actual_return, 100 * actual_placebo_percentile), col = blue, lwd = 3, bty = "n")
plot(control_panel$median_exposure * 100, control_panel$median_return * 100, pch = 19, col = adjustcolor(gray, .55),
     xlab = "Panel median exposure (%)", ylab = "Panel median annual return (%)", main = "All 200 circular-state controls")
points(near_controls$median_exposure * 100, near_controls$median_return * 100, pch = 19, col = adjustcolor(orange, .75))
points(actual_exposure * 100, actual_return * 100, pch = 23, bg = blue, col = blue, cex = 1.7)
legend("bottomright", c("All controls", "Exposure-near", "Actual"), pch = c(19, 19, 23), col = c(gray, orange, blue), pt.bg = c(gray, orange, blue), bty = "n")
dev.off()

png_open("removed_retained_trade_audit.png")
par(mfrow = c(1, 2), mar = c(6, 5, 4, 1))
parent_trades$display <- ifelse(parent_trades$gate_disposition == "REMOVED_BY_GATE", "Removed: LOW", "Retained: MED/HIGH")
boxplot(net_return * 100 ~ display, data = parent_trades, col = c(orange, blue), border = ink, outline = FALSE,
        ylab = "Parent trade return (%)", xlab = "", main = "What the gate removed versus retained")
abline(h = 0, lty = 2, col = gray)
counts <- table(factor(parent_trades$entry_state, levels = c("LOW", "MEDIUM", "HIGH")))
barplot(counts, col = c("#D0EDFA", gray, orange), border = NA, ylab = "Parent trades", main = "Entry opportunities by ATR state")
dev.off()

sec_plot <- secondary[secondary$scenario == "PRIMARY" & secondary$policy %in% c("UNFILTERED", "ATR_LOW_OFF"), ]
png_open("leverage_secondary_view.png")
par(mfrow = c(1, 2), mar = c(6, 5, 4, 1))
mat <- xtabs(median_return * 100 ~ leverage + policy, data = sec_plot)
mat <- mat[, c("UNFILTERED", "ATR_LOW_OFF"), drop = FALSE]
barplot(t(mat), beside = TRUE, col = c(gray, blue), border = NA, names.arg = rownames(mat), xlab = "Leverage", ylab = "Median annual return (%)", main = "Leverage amplifies; it does not select")
legend("topleft", c("Unfiltered", "ATR LOW off"), fill = c(gray, blue), bty = "n")
mat_dd <- xtabs(median_drawdown * 100 ~ leverage + policy, data = sec_plot)
mat_dd <- mat_dd[, c("UNFILTERED", "ATR_LOW_OFF"), drop = FALSE]
barplot(t(mat_dd), beside = TRUE, col = c(gray, blue), border = NA, names.arg = rownames(mat_dd), xlab = "Leverage", ylab = "Median maximum drawdown (%)", main = "Risk remains visible at 1.8x")
dev.off()

cell_rank <- paired[order(paired$return_excess), ]
choose_middle <- function(symbol) {
  x <- cell_rank[cell_rank$symbol == symbol, , drop = FALSE]
  x[which.min(abs(x$return_excess - median(x$return_excess))), c("symbol", "year"), drop = FALSE]
}
selected <- rbind(transform(choose_middle("AMD"), role = "AMD_CANONICAL"), transform(choose_middle("TSLA"), role = "TSLA_CANONICAL"),
                  transform(tail(cell_rank, 1L)[, c("symbol", "year")], role = "LARGEST_IMPROVEMENT"),
                  transform(head(cell_rank, 1L)[, c("symbol", "year")], role = "LARGEST_DEGRADATION"))
selected <- selected[!duplicated(paste(selected$symbol, selected$year)), , drop = FALSE]
while (nrow(selected) < 4L) {
  available <- cell_rank[!paste(cell_rank$symbol, cell_rank$year) %in% paste(selected$symbol, selected$year), , drop = FALSE]
  candidate <- available[1L, , drop = FALSE]
  selected <- rbind(selected, data.frame(symbol = candidate$symbol, year = candidate$year, role = "ADDITIONAL_CONTRAST"))
}
write_csv(selected, file.path(run_dir, "hyp_reg_01_2_representative_selection.csv"))

png_open("representative_overlay_tapes.png", 2100, 2200)
layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
state_cols <- c(LOW = "#D0EDFA", MEDIUM = "#E6E6E6", HIGH = "#F6C48D")
for (i in seq_len(nrow(selected))) {
  pick <- selected[i, ]; p <- paths_all[paths_all$symbol == pick$symbol & paths_all$year == pick$year, , drop = FALSE]
  u <- p[p$policy == "UNFILTERED", ]; o <- p[p$policy == "ATR_LOW_OFF", ]
  groups <- cumsum(c(TRUE, o$regime_state[-1L] != head(o$regime_state, -1L)))
  plot(o$session_date, o$close, type = "n", xlab = "", ylab = "Adjusted close", main = paste(pick$role, "|", pick$symbol, pick$year))
  usr <- par("usr"); for (g in unique(groups)) { q <- o[groups == g, ]; rect(min(q$session_date), usr[[3L]], max(q$session_date) + 1, usr[[4L]], col = adjustcolor(state_cols[[q$regime_state[[1L]]]], .55), border = NA) }
  lines(o$session_date, o$close, col = ink, lwd = 1.3); lines(o$session_date, o$sma_fast, col = cyan); lines(o$session_date, o$sma_slow, col = orange)
  long <- which(o$target); if (length(long)) points(o$session_date[long], rep(usr[[3L]] + .03 * diff(usr[3:4]), length(long)), pch = 15, col = blue, cex = .45)
  legend("topleft", c("Close", "SMA8", "SMA14", "Overlay long"), col = c(ink, cyan, orange, blue), lty = c(1, 1, 1, NA), pch = c(NA, NA, NA, 15), bty = "n", ncol = 2, cex = .75)
  plot(o$session_date, u$equity / imom$initial_wealth - 1, type = "l", col = gray, lwd = 1.5, xlab = "Session", ylab = "Return", main = "Same signals; only LOW entries differ")
  lines(o$session_date, o$equity / imom$initial_wealth - 1, col = blue, lwd = 2); abline(h = 0, lty = 3)
  legend("topleft", c("Unfiltered", "ATR LOW off"), col = c(gray, blue), lwd = c(1.5, 2), bty = "n", cex = .8)
}
dev.off()

report <- c(
  "# HYP-REG-01.2 ATR% Permission Overlay",
  "",
  paste0("Status: `", status, "`"),
  "",
  "## Frozen Question",
  "",
  "Suppress only fresh SMA8/SMA14 entries whose signal-close ATR state is LOW; preserve MEDIUM/HIGH entries, fresh-cross semantics, and every exit.",
  "",
  "## Primary Readout",
  "",
  sprintf("- Stock asset-year cells: %d.", nrow(paired)),
  sprintf("- Unfiltered median annual return: %s.", fmt_pct(unfiltered_panel$median_return)),
  sprintf("- ATR_LOW_OFF median annual return: %s (%s excess).", fmt_pct(overlay_panel$median_return), fmt_pct(overlay_panel$median_return - unfiltered_panel$median_return)),
  sprintf("- Improved six-year compounded return: %d / 24 stocks.", sum(asset_compound$compounded_excess > 0)),
  sprintf("- Positive median excess years: %d / 6.", sum(year_summary$median_excess > 0)),
  sprintf("- Median drawdown change: %s; median Sharpe change: %.3f.", fmt_pct(overlay_panel$median_drawdown - unfiltered_panel$median_drawdown), overlay_panel$median_sharpe - unfiltered_panel$median_sharpe),
  sprintf("- Actual exposure: %s; exposure-near placebo percentile: %.1f%%; excess versus their median: %s.", fmt_pct(actual_exposure), 100 * actual_placebo_percentile, fmt_pct(actual_placebo_excess)),
  "",
  "## Gate Table",
  "",
  "| Gate | Passed | Detail |",
  "|---|---:|---|",
  vapply(seq_len(nrow(gates)), function(i) sprintf("| %s | %s | %s |", gates$gate[[i]], if (gates$passed[[i]]) "YES" else "NO", gates$detail[[i]]), character(1)),
  "",
  "## Boundary",
  "",
  "This is reused-window DEVELOPMENT evidence. The 1.8x view is secondary. No 2024+ row was accessed, no alternate state combination was tried, and no confirmation or live authority is granted."
)
writeLines(report, file.path(run_dir, "hyp_reg_01_2_report.md"))
writeLines(status, file.path(run_dir, "STATUS.txt"))

message(status)
print(policy_panel, row.names = FALSE)
print(gates, row.names = FALSE)
