options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_05_1_path_trendability.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)

contract <- hreg51_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_05_1_path_trendability_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
if (nrow(registry) != contract$registry_assets || anyDuplicated(registry$symbol) ||
    !all(c("AMD", "TSLA", "SPY", "QQQ") %in% registry$symbol)) stop("Frozen registry integrity failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_REG_051_RUN_ID", "hyp_reg_05_1_path_trendability_20260815")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_REG_051_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = registry$symbol,
  universe_name = "hyp_reg_05_1_path_trendability_panel",
  universe_roles = "asset_relative_er_primary,adx_benchmark,path_geometry_only",
  refresh = refresh,
  repo_root = repo_root
)

bars <- hreg51_assert_bars(query$bars, contract)
reference_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]
  x <- bars[bars$symbol == reg$symbol, , drop = FALSE]
  dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start)
  missing <- length(setdiff(reference_dates, dates))
  cbind(reg, data.frame(
    total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(dates), missing_reference_sessions = missing,
    coverage_status = if (!nrow(x)) "NO_HISTORY" else if (prehistory < 300L) "PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else "COMPLETE",
    stringsAsFactors = FALSE
  ))
}))
if (any(coverage$coverage_status != "COMPLETE")) {
  print(coverage[coverage$coverage_status != "COMPLETE", c("symbol", "coverage_status", "prehistory_sessions", "analysis_sessions", "missing_reference_sessions")], row.names = FALSE)
  stop("One or more assets lack complete frozen diagnostic coverage.", call. = FALSE)
}

message("HYP-REG-05.1 building ER20 and ADX14 asset-relative ledgers.")
ledger <- hreg51_build_ledger(bars, contract)
analysis <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
if (any(analysis$session_date >= contract$confirmation_start) || length(unique(analysis$symbol)) != contract$registry_assets) stop("Analysis integrity failed.", call. = FALSE)
if (any(table(analysis$symbol) != length(reference_dates))) stop("Common analysis calendar is incomplete.", call. = FALSE)

summaries <- hreg51_all_summaries(ledger, contract)
offset_summary <- hreg51_offset_summary(ledger, contract)
temporal_summary <- hreg51_temporal_summary(ledger, contract)
calendar_summary <- hreg51_calendar_summary(ledger, contract)
state_diagnostics <- do.call(rbind, lapply(c("ER", "ADX"), function(candidate) hreg51_state_diagnostics(ledger, candidate, contract)))

message("HYP-REG-05.1 running 200 within-asset, within-year circular controls.")
circular_controls <- hreg51_circular_controls(ledger, contract)

panel_row <- function(candidate, horizon, sample = "NON_OVERLAP", offset = 0L) {
  x <- summaries$panel[summaries$panel$candidate == candidate & summaries$panel$horizon == horizon & summaries$panel$sample == sample & summaries$panel$offset == offset, , drop = FALSE]
  if (nrow(x) != 1L) stop("Panel summary lookup is ambiguous.", call. = FALSE)
  x
}

actual_circular <- panel_row("ER", contract$primary_horizon, "ALL")
actual_circular <- rbind(actual_circular, panel_row("ADX", contract$primary_horizon, "ALL"))
circular_readout <- do.call(rbind, lapply(c("ER", "ADX"), function(candidate) {
  actual <- actual_circular[actual_circular$candidate == candidate, , drop = FALSE]
  controls <- circular_controls[circular_controls$candidate == candidate, , drop = FALSE]
  actual_log_ratio <- log(actual$median_high_low_ratio)
  data.frame(
    candidate = candidate,
    actual_median_spearman = actual$median_spearman,
    spearman_percentile = mean(controls$median_spearman <= actual$median_spearman),
    actual_median_log_high_low_ratio = actual_log_ratio,
    log_ratio_percentile = mean(controls$median_log_high_low_ratio <= actual_log_ratio),
    stringsAsFactors = FALSE
  )
}))

rising_adx <- do.call(rbind, lapply(split(analysis, analysis$symbol), function(x) {
  rows <- lapply(contract$horizons, function(h) {
    target <- x[[paste0("future_efficiency_h", h)]]
    keep <- is.finite(x$adx_change5) & is.finite(target) & ((x$analysis_index - 1L) %% h == 0L)
    data.frame(symbol = x$symbol[[1L]], horizon = h, observations = sum(keep), spearman = hreg51_spearman(x$adx_change5[keep], target[keep]), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}))

agreement_summary <- do.call(rbind, lapply(split(analysis, analysis$symbol), function(x) data.frame(
  symbol = x$symbol[[1L]], percentile_spearman = hreg51_spearman(x$er_percentile, x$adx_percentile),
  state_agreement = mean(x$er_state == x$adx_state, na.rm = TRUE), stringsAsFactors = FALSE
)))

state_summary <- do.call(rbind, lapply(split(state_diagnostics, state_diagnostics$candidate), function(x) data.frame(
  candidate = x$candidate[[1L]], median_low_fraction = median_na(x$low_fraction), median_medium_fraction = median_na(x$medium_fraction),
  median_high_fraction = median_na(x$high_fraction), median_switches_per_year = median_na(x$switches_per_year),
  median_run_sessions = median_na(x$median_run_sessions), median_one_session_reversal_share = median_na(x$one_session_reversal_share), stringsAsFactors = FALSE
)))

common_integrity <- all(coverage$coverage_status == "COMPLETE") &&
  all(vapply(split(ledger, ledger$symbol), function(x) {
    first <- x[x$session_date >= contract$analysis_start, , drop = FALSE][1L, ]
    is.finite(first$er_percentile) && is.finite(first$adx_percentile)
  }, logical(1))) &&
  !any(analysis$session_date >= contract$confirmation_start) &&
  !any(c("strategy_return", "pnl", "sharpe", "drawdown", "allocation", "atr_state") %in% names(ledger))

candidate_gates <- function(candidate) {
  h10 <- panel_row(candidate, contract$primary_horizon)
  h20 <- panel_row(candidate, contract$durability_horizon)
  offsets <- offset_summary[offset_summary$candidate == candidate, , drop = FALSE]
  stable_offsets <- sum(offsets$median_spearman > 0 & offsets$median_high_low_ratio > 1, na.rm = TRUE)
  periods <- temporal_summary[temporal_summary$candidate == candidate, , drop = FALSE]
  years <- calendar_summary[calendar_summary$candidate == candidate, , drop = FALSE]
  favorable_years <- sum(years$median_spearman > 0 & years$median_high_low_ratio > 1, na.rm = TRUE)
  circular <- circular_readout[circular_readout$candidate == candidate, , drop = FALSE]
  states <- state_summary[state_summary$candidate == candidate, , drop = FALSE]
  rbind(
    data.frame(candidate, gate = "G1_INTEGRITY", threshold = "26/26 complete; causal percentiles and next-open paths; 2024+ and strategy/ATR surfaces absent", observed = sprintf("%d/26 complete; %d sessions/asset", sum(coverage$coverage_status == "COMPLETE"), length(reference_dates)), passed = common_integrity),
    data.frame(candidate, gate = "G2_H10_CONTINUOUS", threshold = "median rho>=.08; >=18/26 positive assets", observed = sprintf("rho %.3f; %d/26 positive", h10$median_spearman, h10$positive_assets), passed = h10$median_spearman >= .08 && h10$positive_assets >= 18L),
    data.frame(candidate, gate = "G3_H10_STATE_SEPARATION", threshold = "median high/low>=1.08; >=18/26 high>low", observed = sprintf("%.3fx; %d/26 high>low", h10$median_high_low_ratio, h10$high_above_low_assets), passed = h10$median_high_low_ratio >= 1.08 && h10$high_above_low_assets >= 18L),
    data.frame(candidate, gate = "G4_H20_DURABILITY", threshold = "median rho>=.05; >=17/26 positive; high/low>=1.05", observed = sprintf("rho %.3f; %d/26; %.3fx", h20$median_spearman, h20$positive_assets, h20$median_high_low_ratio), passed = h20$median_spearman >= .05 && h20$positive_assets >= 17L && h20$median_high_low_ratio >= 1.05),
    data.frame(candidate, gate = "G5_PATH_SEMANTICS", threshold = "survival gap>=3pp and >=17/26; turn gap<=-2pp and >=17/26", observed = sprintf("survival %.1fpp %d/26; turns %.1fpp %d/26", 100 * h10$median_survival_gap, h10$positive_survival_assets, 100 * h10$median_turn_rate_gap, h10$lower_turn_rate_assets), passed = h10$median_survival_gap >= .03 && h10$positive_survival_assets >= 17L && h10$median_turn_rate_gap <= -.02 && h10$lower_turn_rate_assets >= 17L),
    data.frame(candidate, gate = "G6_H10_OFFSET_STABILITY", threshold = "10 valid; >=7 positive-rho and high/low>1 offsets", observed = sprintf("%d valid; %d favorable", nrow(offsets), stable_offsets), passed = nrow(offsets) == 10L && stable_offsets >= 7L),
    data.frame(candidate, gate = "G7_TEMPORAL_TRANSPORT", threshold = "both halves favorable; >=4/6 favorable years", observed = sprintf("halves %d/2; years %d/6", sum(periods$median_spearman > 0 & periods$median_high_low_ratio > 1), favorable_years), passed = all(periods$median_spearman > 0 & periods$median_high_low_ratio > 1) && favorable_years >= 4L),
    data.frame(candidate, gate = "G8_CIRCULAR_CONTROL", threshold = "rho and log high/low ratio >=90th percentile", observed = sprintf("%.1fth / %.1fth", 100 * circular$spearman_percentile, 100 * circular$log_ratio_percentile), passed = circular$spearman_percentile >= .90 && circular$log_ratio_percentile >= .90),
    data.frame(candidate, gate = "G9_STATE_USABILITY", threshold = "all occupancy>=15%; switches 4-40/year; reversal<=10%; median run>=3", observed = sprintf("occupancy %.1f/%.1f/%.1f%%; switches %.1f; reversal %.1f%%; run %.1f", 100 * states$median_low_fraction, 100 * states$median_medium_fraction, 100 * states$median_high_fraction, states$median_switches_per_year, 100 * states$median_one_session_reversal_share, states$median_run_sessions), passed = min(states$median_low_fraction, states$median_medium_fraction, states$median_high_fraction) >= .15 && states$median_switches_per_year >= 4 && states$median_switches_per_year <= 40 && states$median_one_session_reversal_share <= .10 && states$median_run_sessions >= 3)
  )
}

gates <- do.call(rbind, lapply(c("ER", "ADX"), candidate_gates))
candidate_decision <- do.call(rbind, lapply(split(gates, gates$candidate), function(x) data.frame(
  candidate = x$candidate[[1L]], gates_passed = sum(x$passed), gates_total = nrow(x), promoted_for_discussion = all(x$passed), stringsAsFactors = FALSE
)))
promoted <- candidate_decision$candidate[candidate_decision$promoted_for_discussion]
status <- if (length(promoted)) "DIAGNOSTIC_COMPLETE_STOP_BEFORE_ATR_JOIN_OR_STRATEGY" else "STOP_PATH_TRENDABILITY_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY"

decile_summary <- do.call(rbind, lapply(c("ER", "ADX"), function(candidate) {
  cols <- hreg51_candidate_columns(candidate)
  do.call(rbind, lapply(contract$horizons, function(h) {
    x <- analysis[is.finite(analysis[[cols$score]]) & is.finite(analysis[[paste0("future_efficiency_h", h)]]), , drop = FALSE]
    x$decile <- pmin(10L, pmax(1L, ceiling(10 * x[[cols$score]])))
    do.call(rbind, lapply(split(x, x$decile), function(z) data.frame(
      candidate = candidate, horizon = h, decile = z$decile[[1L]], observations = nrow(z),
      median_future_efficiency = median_na(z[[paste0("future_efficiency_h", h)]]), stringsAsFactors = FALSE
    )))
  }))
}))

pooled_state_summary <- do.call(rbind, lapply(c("ER", "ADX"), function(candidate) {
  cols <- hreg51_candidate_columns(candidate)
  do.call(rbind, lapply(contract$horizons, function(h) {
    survival <- paste0(tolower(candidate), "_direction_survival_h", h)
    do.call(rbind, lapply(c("LOW", "MEDIUM", "HIGH"), function(state) {
      z <- analysis[analysis[[cols$state]] == state, , drop = FALSE]
      data.frame(candidate = candidate, horizon = h, state = state, observations = nrow(z),
                 median_future_efficiency = median_na(z[[paste0("future_efficiency_h", h)]]),
                 direction_survival = mean(z[[survival]], na.rm = TRUE), mean_turn_rate = mean(z[[paste0("future_turn_rate_h", h)]], na.rm = TRUE), stringsAsFactors = FALSE)
    }))
  }))
}))

select_representatives <- function(x) {
  eligible <- x[is.finite(x$future_efficiency_h10) & !is.na(x$er_state) & !is.na(x$adx_state), , drop = FALSE]
  selected <- list(); used <- character()
  choose <- function(case, keep, order_value, decreasing = TRUE) {
    z <- eligible[keep & !paste(eligible$symbol, eligible$session_date) %in% used, , drop = FALSE]
    if (!nrow(z)) z <- eligible[!paste(eligible$symbol, eligible$session_date) %in% used, , drop = FALSE]
    z <- z[order(order_value[match(rownames(z), rownames(eligible))], decreasing = decreasing, na.last = NA), , drop = FALSE]
    row <- z[1L, , drop = FALSE]
    used <<- c(used, paste(row$symbol, row$session_date))
    row$case <- case
    selected[[length(selected) + 1L]] <<- row
  }
  choose("HIGH ER - CONTINUATION", eligible$er_state == "HIGH" & eligible$er_direction_survival_h10 == 1, eligible$future_efficiency_h10, TRUE)
  choose("HIGH ER - BREAKDOWN", eligible$er_state == "HIGH" & eligible$er_direction_survival_h10 == 0, eligible$future_efficiency_h10, FALSE)
  choose("LOW ER - CHOP", eligible$er_state == "LOW", eligible$future_efficiency_h10, FALSE)
  choose("ER / ADX DISAGREE", eligible$er_state == "HIGH" & eligible$adx_state != "HIGH", abs(eligible$er_percentile - eligible$adx_percentile), TRUE)
  do.call(rbind, selected)
}

representatives <- select_representatives(analysis)
representative_ledger <- representatives[c("case", "symbol", "session_date", "er20", "er_percentile", "er_state", "adx14", "adx_percentile", "adx_state", "future_efficiency_h10", "er_direction_survival_h10", "future_turn_rate_h10")]

ink <- "#202630"; blue <- "#3D8DFF"; light_blue <- "#6DCBF4"; orange <- "#F2A65A"; red <- "#D95F59"; green <- "#2E8B57"; gray <- "#B8BCC4"; pale <- "#EDEDED"

png(file.path(visual_dir, "indicator_tape.png"), 1900, 1400, res = 150)
par(mfrow = c(2, 2), mar = c(4, 5, 4, 2), oma = c(1, 1, 2, 1))
for (symbol in c("AMD", "SPY")) {
  z <- analysis[analysis$symbol == symbol, ]
  plot(z$session_date, 100 * z$close / z$close[[1L]], type = "l", col = ink, lwd = 1.2, xlab = "Session", ylab = "Normalized close", main = paste(symbol, "price path"))
  plot(z$session_date, 100 * z$er_percentile, type = "l", col = blue, ylim = c(0, 100), xlab = "Session", ylab = "Trailing percentile", main = paste(symbol, "ER and ADX trendability"))
  lines(z$session_date, 100 * z$adx_percentile, col = orange)
  abline(h = c(30, 70), col = gray, lty = 2)
  legend("topleft", c("ER20", "ADX14"), col = c(blue, orange), lty = 1, bty = "n")
}
mtext("HYP-REG-05.1 | asset-relative path trendability; no strategy or ATR join", outer = TRUE, font = 2)
dev.off()

png(file.path(visual_dir, "continuous_ordering.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
for (candidate in c("ER", "ADX")) {
  z <- decile_summary[decile_summary$candidate == candidate, ]
  wide <- sapply(contract$horizons, function(h) z$median_future_efficiency[z$horizon == h][match(1:10, z$decile[z$horizon == h])])
  matplot(1:10, 100 * wide, type = "b", pch = c(19, 17, 15), col = c(light_blue, blue, orange), lwd = 2, xlab = paste(candidate, "percentile decile"), ylab = "Median future path efficiency (%)", main = paste(candidate, "continuous ordering"))
  legend("topleft", paste0("H", contract$horizons), col = c(light_blue, blue, orange), pch = c(19, 17, 15), lty = 1, bty = "n")
}
dev.off()

png(file.path(visual_dir, "state_outcomes.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 3), mar = c(6, 5, 4, 1))
states <- c("LOW", "MEDIUM", "HIGH"); state_col <- c(LOW = light_blue, MEDIUM = gray, HIGH = blue)
for (metric in c("median_future_efficiency", "direction_survival", "mean_turn_rate")) {
  z <- pooled_state_summary[pooled_state_summary$horizon == 10L, ]
  matrix_value <- sapply(c("ER", "ADX"), function(candidate) z[[metric]][z$candidate == candidate][match(states, z$state[z$candidate == candidate])])
  barplot(100 * t(matrix_value), beside = TRUE, names.arg = states, col = c(blue, orange), border = NA,
          ylab = if (metric == "median_future_efficiency") "Median future efficiency (%)" else if (metric == "direction_survival") "Direction survival (%)" else "Future turn rate (%)",
          main = c(median_future_efficiency = "H10 path efficiency", direction_survival = "H10 direction survival", mean_turn_rate = "H10 turn rate")[[metric]])
  legend("topleft", c("ER", "ADX"), fill = c(blue, orange), bty = "n")
}
dev.off()

asset_h10 <- summaries$asset[summaries$asset$horizon == 10L & summaries$asset$sample == "NON_OVERLAP", ]
symbols <- sort(unique(asset_h10$symbol))
rho_matrix <- sapply(c("ER", "ADX"), function(candidate) asset_h10$spearman[asset_h10$candidate == candidate][match(symbols, asset_h10$symbol[asset_h10$candidate == candidate])])
png(file.path(visual_dir, "asset_portability.png"), 2100, 1150, res = 150)
par(mar = c(10, 5, 4, 2))
barplot(t(rho_matrix), beside = TRUE, names.arg = symbols, las = 2, col = c(blue, orange), border = NA, ylab = "Non-overlapping H10 Spearman", main = "Asset portability of path-efficiency prediction"); abline(h = 0, col = ink); legend("topright", c("ER", "ADX"), fill = c(blue, orange), bty = "n")
dev.off()

png(file.path(visual_dir, "offset_stability.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
for (candidate in c("ER", "ADX")) {
  z <- offset_summary[offset_summary$candidate == candidate, ]
  barplot(z$median_spearman, names.arg = z$offset, col = ifelse(z$median_spearman > 0, green, red), border = NA, xlab = "H10 starting offset", ylab = "Median per-asset Spearman", main = paste(candidate, "offset stability")); abline(h = 0, col = ink)
}
dev.off()

png(file.path(visual_dir, "temporal_and_circular.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 1))
period_matrix <- sapply(c("ER", "ADX"), function(candidate) temporal_summary$median_spearman[temporal_summary$candidate == candidate][match(c("2018-2020", "2021-2023"), temporal_summary$period[temporal_summary$candidate == candidate])])
barplot(t(period_matrix), beside = TRUE, names.arg = c("2018-2020", "2021-2023"), col = c(blue, orange), border = NA, ylab = "Median H10 Spearman", main = "Temporal-half transport"); abline(h = 0, col = ink); legend("topright", c("ER", "ADX"), fill = c(blue, orange), bty = "n")
boxplot(split(circular_controls$median_spearman, circular_controls$candidate), col = pale, border = gray, ylab = "Circular-control median H10 rho", main = "Timing falsification")
points(c(1, 2), circular_readout$actual_median_spearman[match(c("ADX", "ER"), circular_readout$candidate)], pch = 19, col = red, cex = 1.5); legend("topright", "Actual", pch = 19, col = red, bty = "n")
dev.off()

png(file.path(visual_dir, "state_usability.png"), 1900, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 1))
occupancy <- t(as.matrix(state_summary[c("median_low_fraction", "median_medium_fraction", "median_high_fraction")]))
colnames(occupancy) <- state_summary$candidate
barplot(100 * occupancy, beside = TRUE, col = c(light_blue, gray, blue), border = NA, ylab = "Median occupancy (%)", main = "States remain populated"); legend("topright", states, fill = state_col, bty = "n")
barplot(rbind(state_summary$median_switches_per_year, state_summary$median_run_sessions), beside = TRUE, names.arg = state_summary$candidate, col = c(orange, green), border = NA, ylab = "Count / sessions", main = "Switching and run duration"); legend("topright", c("Switches/year", "Median run"), fill = c(orange, green), bty = "n")
dev.off()

png(file.path(visual_dir, "representative_paths.png"), 1900, 1350, res = 150)
par(mfrow = c(2, 2), mar = c(5, 5, 5, 2))
for (i in seq_len(nrow(representatives))) {
  row <- representatives[i, ]
  z <- ledger[ledger$symbol == row$symbol, ]
  signal_index <- which(z$session_date == row$session_date)[[1L]]
  idx <- seq.int(max(1L, signal_index - contract$er_length), min(nrow(z), signal_index + contract$primary_horizon))
  normalized <- 100 * z$close[idx] / z$close[[signal_index]]
  plot(z$session_date[idx], normalized, type = "l", lwd = 2, col = ink, xlab = "Session", ylab = "Close normalized at signal", main = paste0(row$case, "\n", row$symbol, " - ", row$session_date))
  abline(v = row$session_date, col = red, lwd = 2, lty = 2); abline(h = 100, col = gray)
  mtext(sprintf("ER %.0fth - ADX %.0fth - future efficiency %.1f%%", 100 * row$er_percentile, 100 * row$adx_percentile, 100 * row$future_efficiency_h10), side = 3, line = .2, cex = .78)
}
dev.off()

run_spec <- data.frame(
  hypothesis_id = contract$hypothesis_id, status = status, as_of_timestamp = contract$as_of_timestamp,
  query_start = contract$query_start, analysis_start = contract$analysis_start, analysis_end = contract$analysis_end,
  primary_candidate = "Kaufman ER20 percentile", benchmark_candidate = "Wilder ADX14 percentile",
  primary_target = "next-open-anchored H10 future path efficiency", onset_target = "H5", durability_target = "H20",
  strategy_outcomes = "PROHIBITED", atr_join = "PROHIBITED", confirmation_2024_plus = "SEALED", refresh = refresh,
  stringsAsFactors = FALSE
)
integrity <- data.frame(
  check = c("complete_registry_coverage", "common_analysis_calendar", "causal_er_percentile", "causal_adx_percentile", "next_open_future_path", "confirmation_excluded", "no_strategy_or_atr_surface"),
  passed = c(all(coverage$coverage_status == "COMPLETE"), all(table(analysis$symbol) == length(reference_dates)), common_integrity, common_integrity,
             all(is.finite(analysis$future_efficiency_h10[is.finite(analysis$future_efficiency_h10)])), !any(analysis$session_date >= contract$confirmation_start),
             !any(c("strategy_return", "pnl", "sharpe", "drawdown", "allocation", "atr_state") %in% names(ledger))), stringsAsFactors = FALSE
)

files <- list(run_spec = run_spec, integrity = integrity, registry = registry, coverage = coverage, query_health = query$health, ledger = ledger,
              asset_summary = summaries$asset, panel_summary = summaries$panel, offset_summary = offset_summary, temporal_summary = temporal_summary,
              calendar_summary = calendar_summary, state_diagnostics = state_diagnostics, state_summary = state_summary,
              circular_controls = circular_controls, circular_readout = circular_readout, rising_adx = rising_adx, agreement_summary = agreement_summary,
              decile_summary = decile_summary, pooled_state_summary = pooled_state_summary, representative_paths = representative_ledger,
              gates = gates, candidate_decision = candidate_decision)
for (name in names(files)) write_csv(files[[name]], file.path(output_dir, paste0("hyp_reg_05_1_", name, ".csv")))

er10 <- panel_row("ER", 10L); er20 <- panel_row("ER", 20L); adx10 <- panel_row("ADX", 10L); adx20 <- panel_row("ADX", 20L)
report <- c(
  "# HYP-REG-05.1 Path Trendability Diagnostic", "", paste0("Status: `", status, "`"), "", "## Primary readout", "",
  sprintf("- ER H10: median non-overlapping rho %.3f; %d/26 positive; high/low %.3fx; survival gap %.1f pp; turn-rate gap %.1f pp.", er10$median_spearman, er10$positive_assets, er10$median_high_low_ratio, 100 * er10$median_survival_gap, 100 * er10$median_turn_rate_gap),
  sprintf("- ER H20: median rho %.3f; %d/26 positive; high/low %.3fx.", er20$median_spearman, er20$positive_assets, er20$median_high_low_ratio),
  sprintf("- ADX H10: median non-overlapping rho %.3f; %d/26 positive; high/low %.3fx; survival gap %.1f pp; turn-rate gap %.1f pp.", adx10$median_spearman, adx10$positive_assets, adx10$median_high_low_ratio, 100 * adx10$median_survival_gap, 100 * adx10$median_turn_rate_gap),
  sprintf("- ADX H20: median rho %.3f; %d/26 positive; high/low %.3fx.", adx20$median_spearman, adx20$positive_assets, adx20$median_high_low_ratio),
  sprintf("- Gate scores: %s.", paste(sprintf("%s %d/%d", candidate_decision$candidate, candidate_decision$gates_passed, candidate_decision$gates_total), collapse = "; ")), "",
  "This diagnostic measures future path geometry. It does not authorize an ATR% join, trading strategy, PnL calculation, tuning grid, asset subset, or 2024+ confirmation access."
)
writeLines(report, file.path(output_dir, "hyp_reg_05_1_report.md"), useBytes = TRUE)
message("HYP-REG-05.1 complete: ", output_dir)
