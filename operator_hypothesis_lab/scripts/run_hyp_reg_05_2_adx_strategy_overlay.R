options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_05_2_adx_strategy_overlay.R"))

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
mean_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
fmt_pct <- function(x, digits = 2L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))

contract <- hreg52_contract()
imom <- imom_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_05_2_adx_overlay_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
if (nrow(registry) != 26L || anyDuplicated(registry$symbol) || sum(registry$strategy_role == "primary_stock") != 24L) hreg52_stop("Frozen registry integrity failed.")
stocks <- registry$symbol[registry$strategy_role == "primary_stock"]

run_id <- env_or("GEN5_HYP_REG_052_RUN_ID", "hyp_reg_05_2_adx_strategy_overlay_20260815")
run_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

state_path <- env_or("GEN5_HYP_REG_052_STATE_LEDGER", file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_05_1_path_trendability_20260815", "hyp_reg_05_1_ledger.csv"))
parent_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "intraday_momentum_poc_series_20260813", "fixed_sma_summaries.csv")
prior_daily_path <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_reg_01_2_strategy_overlay_20260814", "hyp_reg_01_2_reconstructed_daily.rds")
if (!file.exists(state_path)) hreg52_stop("Completed HYP-REG-05.1 state ledger is unavailable.")
if (!file.exists(parent_path)) hreg52_stop("Retained HYP-MOM-06.1 parent summaries are unavailable.")
states <- hreg52_validate_state_ledger(utils::read.csv(state_path, stringsAsFactors = FALSE), contract)
if (!setequal(unique(states$symbol), registry$symbol)) hreg52_stop("State-ledger symbols differ from the frozen registry.")

daily_cache <- file.path(run_dir, "hyp_reg_05_2_reconstructed_daily.rds")
if (file.exists(daily_cache) && !env_bool("GEN5_HYP_REG_052_REBUILD_DAILY", FALSE)) {
  message("HYP-REG-05.2 using retained reconstructed-daily cache.")
  daily <- readRDS(daily_cache)
} else if (file.exists(prior_daily_path) && !env_bool("GEN5_HYP_REG_052_REBUILD_DAILY", FALSE)) {
  message("HYP-REG-05.2 copying the retained HYP-MOM-06.1 daily execution surface.")
  daily <- readRDS(prior_daily_path)
  saveRDS(daily, daily_cache)
} else {
  message("HYP-REG-05.2 reconstructing the parent daily surface from admitted 30-minute SIP bars.")
  cache_dir <- file.path(repo_root, "data_cache", "alpaca_intraday_30min")
  paths <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d.rds", 2017:2023))
  if (!all(file.exists(paths))) hreg52_stop("All 2017-2023 intraday cache years are required.")
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
daily <- daily[daily$session_date < contract$confirmation_start, , drop = FALSE]
if (!setequal(unique(daily$symbol), registry$symbol)) hreg52_stop("Daily symbols differ from the frozen registry.")

coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]
  x <- daily[daily$symbol == reg$symbol & daily$session_date >= contract$analysis_start & daily$session_date <= contract$analysis_end, , drop = FALSE]
  s <- states[states$symbol == reg$symbol & states$session_date >= contract$analysis_start & states$session_date <= contract$analysis_end, , drop = FALSE]
  matched <- match(x$session_date, s$session_date)
  missing_adx <- sum(is.na(matched) | is.na(s$adx_state[matched]))
  data.frame(instance_id = reg$instance_id, symbol = reg$symbol, sector = reg$sector, asset_type = reg$asset_type,
             strategy_role = reg$strategy_role, strategy_sessions = nrow(x), state_sessions = nrow(s),
             missing_state_dates = length(setdiff(x$session_date, s$session_date)), state_only_dates = length(setdiff(s$session_date, x$session_date)),
             missing_adx_states = missing_adx,
             status = if (nrow(x) == 1499L && nrow(s) == 1509L && !length(setdiff(x$session_date, s$session_date)) && length(setdiff(s$session_date, x$session_date)) == 10L && missing_adx == 0L) "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS" else "REVIEW",
             stringsAsFactors = FALSE)
}))
if (any(coverage$status != "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS")) hreg52_stop("Daily/ADX calendar alignment failed.")

scenario_table <- data.frame(scenario = c("PRIMARY", "STRESS"), bps = c(contract$primary_bps, contract$stress_bps), stringsAsFactors = FALSE)
summaries <- list(); trades <- list(); paths_all <- list(); k <- 0L; tk <- 0L; pk <- 0L
aligned_by_symbol <- list()

message("HYP-REG-05.2 replaying parent, entry-only, reactive, and buy-and-hold policies.")
for (symbol in registry$symbol) {
  x <- daily[daily$symbol == symbol, , drop = FALSE]
  x <- x[order(x$session_date), , drop = FALSE]
  frame <- hreg52_align_adx(hreg12_cross_frame(x, contract$fast, contract$slow), states[states$symbol == symbol, , drop = FALSE])
  aligned_by_symbol[[symbol]] <- frame
  reg <- registry[match(symbol, registry$symbol), , drop = FALSE]
  for (year in contract$years) {
    start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start)
    end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end)
    schedules <- lapply(contract$policies, function(p) hreg52_schedule(frame, start, end, p))
    names(schedules) <- contract$policies
    schedules$BUY_HOLD <- imom_buy_hold_schedule(x, start, end)
    block_frame <- frame[frame$session_date >= start & frame$session_date <= end, , drop = FALSE]
    for (policy in names(schedules)) for (si in seq_len(nrow(scenario_table))) {
      scenario <- scenario_table[si, , drop = FALSE]
      replay <- imom_replay(x, start, end, schedules[[policy]], 1, scenario$bps, 0,
                            scenario$scenario, 252L, imom)
      q <- replay$summary
      q$policy <- policy; q$year <- year; q$sector <- reg$sector; q$asset_type <- reg$asset_type; q$strategy_role <- reg$strategy_role
      k <- k + 1L; summaries[[k]] <- q
      if (scenario$scenario == "PRIMARY" && policy %in% contract$policies) {
        t <- hreg52_label_trades(replay$trades, schedules[[policy]], block_frame)
        if (nrow(t)) {
          t$policy <- policy; t$year <- year; t$sector <- reg$sector; t$strategy_role <- reg$strategy_role
          tk <- tk + 1L; trades[[tk]] <- t
        }
        w <- replay$path
        w$sma_fast <- block_frame$sma_fast; w$sma_slow <- block_frame$sma_slow
        w$adx_state <- block_frame$adx_state; w$adx14 <- block_frame$adx14; w$adx_percentile <- block_frame$adx_percentile
        w$blocked_entry <- schedules[[policy]]$blocked_entry; w$state_exit <- schedules[[policy]]$state_exit
        w$exit_reason <- schedules[[policy]]$exit_reason; w$policy <- policy; w$year <- year
        w$sector <- reg$sector; w$strategy_role <- reg$strategy_role
        pk <- pk + 1L; paths_all[[pk]] <- w
      }
    }
  }
}
summaries <- do.call(rbind, summaries); rownames(summaries) <- NULL
trades <- if (length(trades)) do.call(rbind, trades) else data.frame()
paths_all <- do.call(rbind, paths_all); rownames(paths_all) <- NULL

parent <- utils::read.csv(parent_path, stringsAsFactors = FALSE)
parent <- parent[parent$frequency == "DAILY" & parent$policy == "SMA8_14" & parent$scenario == "PRIMARY" & parent$delay_bars == 0 & parent$leverage == 1,
                 c("symbol", "year", "total_return")]
names(parent)[[3L]] <- "parent_total_return"
reproduction <- merge(summaries[summaries$policy == "UNFILTERED" & summaries$scenario == "PRIMARY",
                                  c("symbol", "year", "total_return")], parent, by = c("symbol", "year"), all = TRUE)
reproduction$absolute_difference <- abs(reproduction$total_return - reproduction$parent_total_return)
reproduction$passed <- is.finite(reproduction$absolute_difference) & reproduction$absolute_difference <= contract$reproduction_tolerance
if (!all(reproduction$passed)) hreg52_stop(sprintf("Parent reproduction failed; maximum difference %.12g.", max(reproduction$absolute_difference, na.rm = TRUE)))

message("HYP-REG-05.2 running 200 deterministic circular-state controls for both overlay policies.")
control_cell_path <- file.path(run_dir, "hyp_reg_05_2_control_cells.csv")
if (file.exists(control_cell_path) && !env_bool("GEN5_HYP_REG_052_REBUILD_CONTROLS", FALSE)) {
  message("HYP-REG-05.2 using retained circular-state controls.")
  controls <- utils::read.csv(control_cell_path, stringsAsFactors = FALSE)
} else {
  overlay_policies <- c("ENTRY_HIGH_ONLY", "REACTIVE_HIGH_ONLY")
  controls <- vector("list", length(stocks) * length(contract$years) * contract$placebo_simulations * length(overlay_policies)); ck <- 0L
  for (symbol in stocks) {
    x <- daily[daily$symbol == symbol, , drop = FALSE]; frame <- aligned_by_symbol[[symbol]]
    for (year in contract$years) {
      start <- max(as.Date(sprintf("%d-01-01", year)), contract$analysis_start)
      end <- min(as.Date(sprintf("%d-12-31", year)), contract$analysis_end)
      w <- x[x$session_date >= start & x$session_date <= end, , drop = FALSE]
      for (policy in overlay_policies) for (simulation_id in seq_len(contract$placebo_simulations)) {
        schedule <- hreg52_shifted_schedule(frame, start, end, simulation_id, policy, contract)
        ck <- ck + 1L
        controls[[ck]] <- data.frame(symbol = symbol, year = year, policy = policy, simulation_id = simulation_id,
                                     shift_offset = attr(schedule, "shift_offset"), exposure = mean(schedule$target),
                                     blocked_entries = sum(schedule$blocked_entry), state_exits = sum(schedule$state_exit),
                                     total_return = imom_fast_terminal_from_schedule(w, schedule, 1, contract$primary_bps, 0, imom),
                                     stringsAsFactors = FALSE)
      }
    }
  }
  controls <- do.call(rbind, controls)
  write_csv(controls, control_cell_path)
}

control_panel <- do.call(rbind, lapply(split(controls, interaction(controls$policy, controls$simulation_id, drop = TRUE)), function(x) data.frame(
  policy = x$policy[[1L]], simulation_id = x$simulation_id[[1L]], cells = nrow(x),
  median_return = median_na(x$total_return), median_exposure = median_na(x$exposure),
  positive_fraction = mean(x$total_return > 0), stringsAsFactors = FALSE
)))
control_panel <- control_panel[order(control_panel$policy, control_panel$simulation_id), , drop = FALSE]

primary <- summaries[summaries$strategy_role == "primary_stock" & summaries$scenario == "PRIMARY", , drop = FALSE]
policy_panel <- hreg52_policy_panel(primary)
policy_panel <- policy_panel[match(c("UNFILTERED", "ENTRY_HIGH_ONLY", "REACTIVE_HIGH_ONLY", "BUY_HOLD"), policy_panel$policy), , drop = FALSE]
parent_cells <- primary[primary$policy == "UNFILTERED", , drop = FALSE]
overlay_policies <- c("ENTRY_HIGH_ONLY", "REACTIVE_HIGH_ONLY")

paired_rows <- list(); asset_rows <- list(); year_rows <- list(); placebo_rows <- list(); gate_rows <- list()
for (policy in overlay_policies) {
  overlay_cells <- primary[primary$policy == policy, , drop = FALSE]
  paired <- merge(parent_cells[c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure", "turnover", "trade_count")],
                  overlay_cells[c("symbol", "year", "total_return", "maximum_drawdown", "sharpe", "exposure", "turnover", "trade_count")],
                  by = c("symbol", "year"), suffixes = c("_parent", "_overlay"))
  paired$policy <- policy
  paired$return_excess <- paired$total_return_overlay - paired$total_return_parent
  paired$drawdown_change <- paired$maximum_drawdown_overlay - paired$maximum_drawdown_parent
  paired$sharpe_change <- paired$sharpe_overlay - paired$sharpe_parent
  paired_rows[[policy]] <- paired

  comp <- hreg52_compound_by_asset(primary[primary$policy %in% c("UNFILTERED", policy), , drop = FALSE])
  parent_comp <- comp[comp$policy == "UNFILTERED", c("symbol", "compounded_return")]; names(parent_comp)[[2L]] <- "parent_compounded_return"
  overlay_comp <- comp[comp$policy == policy, c("symbol", "compounded_return")]; names(overlay_comp)[[2L]] <- "overlay_compounded_return"
  asset <- merge(parent_comp, overlay_comp, by = "symbol")
  asset$policy <- policy; asset$compounded_excess <- asset$overlay_compounded_return - asset$parent_compounded_return
  asset_rows[[policy]] <- asset

  year <- do.call(rbind, lapply(split(paired, paired$year), function(x) data.frame(
    policy = policy, year = x$year[[1L]], cells = nrow(x), median_excess = median_na(x$return_excess),
    improvement_fraction = mean(x$return_excess > 0), median_drawdown_change = median_na(x$drawdown_change),
    median_sharpe_change = median_na(x$sharpe_change), stringsAsFactors = FALSE
  )))
  year_rows[[policy]] <- year

  actual_row <- policy_panel[policy_panel$policy == policy, , drop = FALSE]
  controls_policy <- control_panel[control_panel$policy == policy, , drop = FALSE]
  near_ids <- hreg52_exposure_near_ids(controls_policy, actual_row$median_exposure, contract$exposure_near_count)
  controls_policy$exposure_near <- controls_policy$simulation_id %in% near_ids
  near <- controls_policy[controls_policy$exposure_near, , drop = FALSE]
  pct <- hreg52_midrank_percentile(actual_row$median_return, near$median_return)
  excess <- actual_row$median_return - median_na(near$median_return)
  placebo_rows[[policy]] <- data.frame(policy = policy, actual_return = actual_row$median_return,
                                       actual_exposure = actual_row$median_exposure, percentile = pct,
                                       excess_vs_control_median = excess, near_controls = nrow(near), stringsAsFactors = FALSE)
  control_panel$exposure_near[control_panel$policy == policy] <- controls_policy$exposure_near

  parent_row <- policy_panel[policy_panel$policy == "UNFILTERED", , drop = FALSE]
  asset <- asset_rows[[policy]]; year <- year_rows[[policy]]
  gate_rows[[policy]] <- data.frame(
    policy = policy,
    gate = c("G1_INTEGRITY", "G2_PARENT_REPRODUCTION", "G3_PANEL_RETURN", "G4_ASSET_BREADTH", "G5_CALENDAR_BREADTH", "G6_PROTECTION_AND_SHARPE", "G7_ABSOLUTE_VIABILITY", "G8_STATE_SPECIFICITY"),
    observed = c(
      "26/26 complete; 24 stocks; 2024+ absent",
      sprintf("156/156; max difference %.3g", max(reproduction$absolute_difference)),
      sprintf("%s vs %s", fmt_pct(actual_row$median_return), fmt_pct(parent_row$median_return)),
      sprintf("%d/24 improved", sum(asset$compounded_excess > 0)),
      sprintf("%d/6 positive years", sum(year$median_excess > 0)),
      sprintf("drawdown %s; Sharpe %+.3f", fmt_pct(actual_row$median_drawdown - parent_row$median_drawdown), actual_row$median_sharpe - parent_row$median_sharpe),
      fmt_pct(actual_row$median_return),
      sprintf("%.1fth percentile; %s vs controls", 100 * pct, fmt_pct(excess))
    ),
    passed = c(
      all(coverage$status == "COMPLETE_KNOWN_ARCHIVE_EXCLUSIONS") && !any(daily$session_date >= contract$confirmation_start),
      all(reproduction$passed),
      actual_row$median_return > parent_row$median_return,
      sum(asset$compounded_excess > 0) >= 15L,
      sum(year$median_excess > 0) >= 4L,
      actual_row$median_drawdown >= parent_row$median_drawdown && actual_row$median_sharpe >= parent_row$median_sharpe,
      actual_row$median_return > 0,
      is.finite(pct) && pct >= .80 && excess > 0
    ),
    stringsAsFactors = FALSE
  )
}
paired <- do.call(rbind, paired_rows); rownames(paired) <- NULL
asset_summary <- do.call(rbind, asset_rows); rownames(asset_summary) <- NULL
year_summary <- do.call(rbind, year_rows); rownames(year_summary) <- NULL
placebo_readout <- do.call(rbind, placebo_rows); rownames(placebo_readout) <- NULL
gates <- do.call(rbind, gate_rows); rownames(gates) <- NULL

parent_trades <- trades[trades$policy == "UNFILTERED" & trades$strategy_role == "primary_stock", , drop = FALSE]
entry_state_audit <- do.call(rbind, lapply(split(parent_trades, parent_trades$entry_state), function(x) data.frame(
  entry_state = x$entry_state[[1L]], trades = nrow(x), hit_rate = mean(x$net_return > 0),
  mean_trade = mean_na(x$net_return), median_trade = median_na(x$net_return),
  median_holding = median_na(x$holding_bars), stringsAsFactors = FALSE
)))
entry_state_audit <- entry_state_audit[match(c("LOW", "MEDIUM", "HIGH"), entry_state_audit$entry_state), , drop = FALSE]

reactive_trades <- trades[trades$policy == "REACTIVE_HIGH_ONLY" & trades$strategy_role == "primary_stock", , drop = FALSE]
parent_match <- parent_trades[c("symbol", "year", "entry_date", "exit_date", "net_return")]
names(parent_match)[4:5] <- c("parent_exit_date", "parent_net_return")
reactive_audit <- merge(reactive_trades, parent_match, by = c("symbol", "year", "entry_date"), all.x = TRUE)
reactive_audit$exit_delta_vs_parent <- reactive_audit$net_return - reactive_audit$parent_net_return
reactive_exit_summary <- do.call(rbind, lapply(split(reactive_audit, reactive_audit$exit_reason), function(x) data.frame(
  exit_reason = x$exit_reason[[1L]], trades = nrow(x), mean_trade = mean_na(x$net_return), median_trade = median_na(x$net_return),
  mean_delta_vs_parent = mean_na(x$exit_delta_vs_parent), median_delta_vs_parent = median_na(x$exit_delta_vs_parent), stringsAsFactors = FALSE
)))

all_pass <- vapply(overlay_policies, function(policy) all(gates$passed[gates$policy == policy]), logical(1))
status <- if (any(all_pass)) "PASS_TO_CONFIRMATION_DISCUSSION" else "STOP_ADX_STRATEGY_RELATIVE_GATES_FAILED_CONFIRMATION_NOT_RUN"
decision <- data.frame(policy = overlay_policies, gates_passed = vapply(overlay_policies, function(p) sum(gates$passed[gates$policy == p]), integer(1)),
                       gates_total = 8L, all_passed = all_pass, status = ifelse(all_pass, "PASS_TO_CONFIRMATION_DISCUSSION", "STOP_POLICY_GATES_FAILED"), stringsAsFactors = FALSE)

write_csv(registry, file.path(run_dir, "hyp_reg_05_2_registry.csv"))
write_csv(coverage, file.path(run_dir, "hyp_reg_05_2_coverage.csv"))
write_csv(reproduction, file.path(run_dir, "hyp_reg_05_2_parent_reproduction.csv"))
write_csv(summaries, file.path(run_dir, "hyp_reg_05_2_summaries.csv"))
write_csv(trades, file.path(run_dir, "hyp_reg_05_2_trades.csv"))
write_csv(policy_panel, file.path(run_dir, "hyp_reg_05_2_policy_panel.csv"))
write_csv(paired, file.path(run_dir, "hyp_reg_05_2_paired_cells.csv"))
write_csv(asset_summary, file.path(run_dir, "hyp_reg_05_2_asset_summary.csv"))
write_csv(year_summary, file.path(run_dir, "hyp_reg_05_2_year_summary.csv"))
write_csv(entry_state_audit, file.path(run_dir, "hyp_reg_05_2_entry_state_audit.csv"))
write_csv(reactive_audit, file.path(run_dir, "hyp_reg_05_2_reactive_trade_audit.csv"))
write_csv(reactive_exit_summary, file.path(run_dir, "hyp_reg_05_2_reactive_exit_summary.csv"))
write_csv(control_panel, file.path(run_dir, "hyp_reg_05_2_control_panel.csv"))
write_csv(placebo_readout, file.path(run_dir, "hyp_reg_05_2_placebo_readout.csv"))
write_csv(gates, file.path(run_dir, "hyp_reg_05_2_gates.csv"))
write_csv(decision, file.path(run_dir, "hyp_reg_05_2_decision.csv"))
write_csv(data.frame(hypothesis_id = contract$hypothesis_id, status = status, evidence_stage = contract$evidence_stage,
                     as_of_timestamp = contract$as_of_timestamp, analysis_start = contract$analysis_start,
                     analysis_end = contract$analysis_end, confirmation_start = contract$confirmation_start,
                     primary_bps = contract$primary_bps, stress_bps = contract$stress_bps,
                     leverage = 1, confirmation_2024_plus = "SEALED", stringsAsFactors = FALSE),
          file.path(run_dir, "hyp_reg_05_2_run_spec.csv"))

ink <- "#17202A"; blue <- "#3D8DFF"; violet <- "#6C63A8"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#8A949E"; pale <- "#DCEBFA"
png_open <- function(name, width = 1800, height = 1000) grDevices::png(file.path(visual_dir, name), width = width, height = height, res = 160)

plot_primary <- primary[primary$policy %in% c("UNFILTERED", overlay_policies), , drop = FALSE]
plot_primary$policy <- factor(plot_primary$policy, levels = c("UNFILTERED", overlay_policies))
png_open("policy_performance.png")
par(mfrow = c(1, 2), mar = c(7, 5, 4, 1))
boxplot(total_return * 100 ~ policy, data = plot_primary, col = c(gray, blue, violet), border = ink, outline = FALSE,
        ylab = "Annual return (%)", xaxt = "n", main = "Return after 5 bp per side"); axis(1, at = 1:3, labels = c("Parent", "Entry only", "Reactive"), las = 2); abline(h = 0, lty = 2)
boxplot(maximum_drawdown * 100 ~ policy, data = plot_primary, col = c(gray, blue, violet), border = ink, outline = FALSE,
        ylab = "Maximum drawdown (%)", xaxt = "n", main = "Protection bargain"); axis(1, at = 1:3, labels = c("Parent", "Entry only", "Reactive"), las = 2)
dev.off()

png_open("policy_mechanics.png")
par(mfrow = c(2, 2), mar = c(6, 5, 4, 1))
metrics <- list(median_return = "Median annual return (%)", median_sharpe = "Median Sharpe", median_exposure = "Median exposure (%)", median_turnover = "Median turnover")
for (metric in names(metrics)) {
  values <- policy_panel[[metric]][match(c("UNFILTERED", overlay_policies), policy_panel$policy)]
  if (metric %in% c("median_return", "median_exposure")) values <- 100 * values
  barplot(values, names.arg = c("Parent", "Entry", "Reactive"), col = c(gray, blue, violet), border = NA, las = 2,
          ylab = metrics[[metric]], main = metrics[[metric]]); abline(h = 0, col = ink)
}
dev.off()

png_open("asset_breadth.png", 1900, 1250)
par(mfrow = c(1, 2), mar = c(5, 8, 4, 1))
for (policy in overlay_policies) {
  z <- asset_summary[asset_summary$policy == policy, ]; z <- z[order(z$compounded_excess), ]
  barplot(z$compounded_excess * 100, names.arg = z$symbol, horiz = TRUE, las = 1,
          col = ifelse(z$compounded_excess > 0, green, red), border = NA,
          xlab = "Overlay minus parent six-year return (pp)", main = if (policy == "ENTRY_HIGH_ONLY") "Entry-only breadth" else "Reactive breadth")
  abline(v = 0, col = ink, lwd = 1.5)
}
dev.off()

png_open("calendar_breadth.png")
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
for (policy in overlay_policies) {
  z <- year_summary[year_summary$policy == policy, ]
  barplot(z$median_excess * 100, names.arg = z$year, col = ifelse(z$median_excess > 0, green, red), border = NA,
          ylab = "Median excess (pp)", main = if (policy == "ENTRY_HIGH_ONLY") "Entry-only by year" else "Reactive by year")
  abline(h = 0, col = ink)
}
dev.off()

png_open("state_timing_controls.png", 1900, 1250)
par(mfrow = c(2, 2), mar = c(5, 5, 4, 1))
for (policy in overlay_policies) {
  readout <- placebo_readout[placebo_readout$policy == policy, ]
  z <- control_panel[control_panel$policy == policy, ]; near <- z[z$exposure_near, ]
  hist(near$median_return * 100, breaks = 12, col = pale, border = "white", xlab = "Panel median annual return (%)",
       main = paste(if (policy == "ENTRY_HIGH_ONLY") "Entry only" else "Reactive", "exposure-near controls"))
  abline(v = 100 * readout$actual_return, col = if (policy == "ENTRY_HIGH_ONLY") blue else violet, lwd = 3)
  legend("topright", sprintf("Actual %.2f%%\nPercentile %.1f", 100 * readout$actual_return, 100 * readout$percentile), bty = "n")
  plot(z$median_exposure * 100, z$median_return * 100, pch = 19, col = adjustcolor(gray, .45),
       xlab = "Median exposure (%)", ylab = "Median annual return (%)", main = "All 200 shifts")
  points(near$median_exposure * 100, near$median_return * 100, pch = 19, col = adjustcolor(orange, .8))
  points(readout$actual_exposure * 100, readout$actual_return * 100, pch = 23, bg = if (policy == "ENTRY_HIGH_ONLY") blue else violet, cex = 1.7)
}
dev.off()

png_open("entry_state_audit.png")
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
boxplot(net_return * 100 ~ factor(entry_state, levels = c("LOW", "MEDIUM", "HIGH")), data = parent_trades,
        col = c(pale, gray, orange), border = ink, outline = FALSE, xlab = "ADX state at parent entry signal", ylab = "Parent trade return (%)", main = "What HIGH-only selects")
abline(h = 0, lty = 2)
barplot(entry_state_audit$trades, names.arg = entry_state_audit$entry_state, col = c(pale, gray, orange), border = NA,
        ylab = "Parent trades", main = "Opportunity count")
dev.off()

png_open("reactive_exit_audit.png")
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
state_only <- reactive_audit[reactive_audit$exit_reason == "ADX_LEFT_HIGH" & is.finite(reactive_audit$exit_delta_vs_parent), ]
hist(state_only$exit_delta_vs_parent * 100, breaks = 25, col = pale, border = "white", xlab = "Reactive trade minus same parent trade (pp)", main = "Did ADX exits help?"); abline(v = 0, col = ink, lwd = 2)
counts <- table(factor(reactive_audit$exit_reason, levels = c("ADX_LEFT_HIGH", "PARENT_CROSS_DOWN", "YEAR_END_FORCED")))
barplot(counts, col = c(violet, gray, orange), border = NA, las = 2, ylab = "Reactive trades", main = "Exit reasons")
dev.off()

cell_contrast <- paired[paired$policy == "REACTIVE_HIGH_ONLY", ]
best_cell <- cell_contrast[which.max(cell_contrast$return_excess), c("symbol", "year")]
worst_cell <- cell_contrast[which.min(cell_contrast$return_excess), c("symbol", "year")]
protective <- state_only[which.max(state_only$exit_delta_vs_parent), c("symbol", "year")]
false_exit <- state_only[which.min(state_only$exit_delta_vs_parent), c("symbol", "year")]
selected <- rbind(data.frame(best_cell, role = "LARGEST_CELL_IMPROVEMENT"), data.frame(worst_cell, role = "LARGEST_CELL_DEGRADATION"),
                  data.frame(protective, role = "PROTECTIVE_ADX_EXIT"), data.frame(false_exit, role = "FALSE_ADX_EXIT"))
selected <- selected[!duplicated(paste(selected$symbol, selected$year)), , drop = FALSE]
fallback <- cell_contrast[order(abs(cell_contrast$return_excess - median(cell_contrast$return_excess))), c("symbol", "year")]
while (nrow(selected) < 4L) {
  candidate <- fallback[!paste(fallback$symbol, fallback$year) %in% paste(selected$symbol, selected$year), ][1L, ]
  selected <- rbind(selected, data.frame(candidate, role = "ADDITIONAL_CONTRAST"))
}
write_csv(selected, file.path(run_dir, "hyp_reg_05_2_representative_selection.csv"))

png_open("representative_state_routing_tapes.png", 2200, 2200)
layout(matrix(seq_len(8), nrow = 4, byrow = TRUE)); par(mar = c(2.5, 5, 4, 1))
state_cols <- c(LOW = "#D0EDFA", MEDIUM = "#E6E6E6", HIGH = "#F6C48D")
for (i in seq_len(nrow(selected))) {
  pick <- selected[i, ]; p <- paths_all[paths_all$symbol == pick$symbol & paths_all$year == pick$year, , drop = FALSE]
  u <- p[p$policy == "UNFILTERED", ]; r <- p[p$policy == "REACTIVE_HIGH_ONLY", ]
  groups <- cumsum(c(TRUE, r$adx_state[-1L] != head(r$adx_state, -1L)))
  plot(r$session_date, r$close, type = "n", xlab = "", ylab = "Close", main = paste(pick$role, "-", pick$symbol, pick$year))
  usr <- par("usr"); for (g in unique(groups)) { q <- r[groups == g, ]; rect(min(q$session_date), usr[[3L]], max(q$session_date) + 1, usr[[4L]], col = adjustcolor(state_cols[[q$adx_state[[1L]]]], .55), border = NA) }
  lines(r$session_date, r$close, col = ink, lwd = 1.3); lines(r$session_date, r$sma_fast, col = blue); lines(r$session_date, r$sma_slow, col = orange)
  long <- which(r$target); if (length(long)) points(r$session_date[long], rep(usr[[3L]] + .03 * diff(usr[3:4]), length(long)), pch = 15, col = violet, cex = .45)
  exits <- which(r$state_exit); if (length(exits)) points(r$session_date[exits], r$close[exits], pch = 4, col = red, lwd = 2)
  legend("topleft", c("Close", "SMA8", "SMA14", "Reactive long", "ADX exit"), col = c(ink, blue, orange, violet, red), lty = c(1, 1, 1, NA, NA), pch = c(NA, NA, NA, 15, 4), bty = "n", ncol = 2, cex = .7)
  plot(r$session_date, u$equity / imom$initial_wealth - 1, type = "l", col = gray, lwd = 1.5, xlab = "Session", ylab = "Return", main = "Parent versus reactive")
  lines(r$session_date, r$equity / imom$initial_wealth - 1, col = violet, lwd = 2); abline(h = 0, lty = 3)
  legend("topleft", c("Parent", "Reactive"), col = c(gray, violet), lwd = c(1.5, 2), bty = "n", cex = .8)
}
dev.off()

report <- c(
  "# HYP-REG-05.2 ADX Strategy-Relative Overlay", "", paste0("Status: `", status, "`"), "",
  "## Frozen Question", "",
  "Can the causally observed HIGH ADX state improve an unchanged SMA8/SMA14 entry policy, and does exiting when ADX leaves HIGH add value before the next daily decision?", "",
  "## Policy Readout", "",
  "| Policy | Median return | Median drawdown | Median Sharpe | Median exposure | Trades |",
  "|---|---:|---:|---:|---:|---:|",
  vapply(seq_len(nrow(policy_panel)), function(i) sprintf("| %s | %s | %s | %.3f | %s | %d |", policy_panel$policy[[i]], fmt_pct(policy_panel$median_return[[i]]), fmt_pct(policy_panel$median_drawdown[[i]]), policy_panel$median_sharpe[[i]], fmt_pct(policy_panel$median_exposure[[i]]), policy_panel$trades[[i]]), character(1)),
  "", "## Gate Scores", "",
  vapply(seq_len(nrow(decision)), function(i) sprintf("- %s: %d / %d gates; `%s`.", decision$policy[[i]], decision$gates_passed[[i]], decision$gates_total[[i]], decision$status[[i]]), character(1)),
  "", "## Boundary", "",
  "This is reused-window DEVELOPMENT evidence. No alternate state, threshold, policy, asset subset, leverage, ATR/ER combination, or 2024+ confirmation observation was used."
)
writeLines(report, file.path(run_dir, "hyp_reg_05_2_report.md"))
writeLines(status, file.path(run_dir, "STATUS.txt"))

message(status)
print(policy_panel, row.names = FALSE)
print(decision, row.names = FALSE)
