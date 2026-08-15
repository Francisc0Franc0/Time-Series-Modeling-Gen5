options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
mean_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
pct <- function(x, digits = 1L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))

contract <- hreg_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_reg_01_1_atr_percent_registry.csv")
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
if (nrow(registry) != 26L || anyDuplicated(registry$symbol)) stop("Frozen 26-asset registry integrity failed.", call. = FALSE)
source_registry <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "gen5_intraday_momentum_poc_registry.csv"), stringsAsFactors = FALSE)
if (!setequal(registry$symbol, source_registry$symbol)) stop("Regime registry differs from the frozen intraday panel.", call. = FALSE)

run_id <- env_or("GEN5_HYP_REG_011_RUN_ID", "hyp_reg_01_1_atr_percent_20260814")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_REG_011_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$analysis_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = registry$symbol,
  universe_name = "hyp_reg_01_1_atr_percent_panel",
  universe_roles = "frozen_intraday_26,volatility_diagnostic_only",
  refresh = refresh,
  repo_root = repo_root
)
bars <- hreg_assert_bars(query$bars)
if (any(bars$session_date >= contract$confirmation_start)) stop("Confirmation-period bars entered HYP-REG-01.1.", call. = FALSE)

spy_dates <- sort(unique(bars$session_date[bars$symbol == "SPY" & bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end]))
if (!length(spy_dates)) stop("SPY analysis calendar is unavailable.", call. = FALSE)
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]
  x <- bars[bars$symbol == reg$symbol, , drop = FALSE]
  analysis_dates <- x$session_date[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end]
  prehistory <- sum(x$session_date < contract$analysis_start)
  invalid <- if (!nrow(x)) 0L else sum(!is.finite(x$open) | !is.finite(x$high) | !is.finite(x$low) | !is.finite(x$close) | x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0)
  missing <- length(setdiff(spy_dates, analysis_dates))
  status <- if (!nrow(x)) "NO_HISTORY" else if (invalid > 0L) "INVALID_OHLC" else if (prehistory < 270L) "PRIMARY_PREHISTORY_SHORT" else if (missing > 0L) "ANALYSIS_GAPS" else if (prehistory < 520L) "COMPLETE_PRIMARY_SENSITIVITY_WARMUP" else "COMPLETE"
  cbind(reg, data.frame(total_rows = nrow(x), prehistory_sessions = prehistory, analysis_sessions = length(analysis_dates), missing_spy_sessions = missing, invalid_ohlc_rows = invalid, coverage_status = status, stringsAsFactors = FALSE))
}))
if (any(coverage$coverage_status %in% c("NO_HISTORY", "INVALID_OHLC", "PRIMARY_PREHISTORY_SHORT"))) {
  stop("One or more assets lack valid prehistory for the frozen diagnostic.", call. = FALSE)
}
if (any(coverage$missing_spy_sessions > 0L)) message("Transparency note: some assets have analysis-calendar gaps; no rows are imputed.")

message("HYP-REG-01.1 building causal state ledgers for 26 assets.")
ledgers <- vector("list", nrow(registry))
for (i in seq_len(nrow(registry))) {
  reg <- registry[i, , drop = FALSE]
  message(sprintf("[%02d/%02d] %s", i, nrow(registry), reg$symbol))
  x <- hreg_build_asset_ledger(bars[bars$symbol == reg$symbol, , drop = FALSE], contract)
  x$instance_id <- reg$instance_id
  x$sector <- reg$sector
  x$asset_type <- reg$asset_type
  x$panel_role <- reg$panel_role
  ledgers[[i]] <- x
}
ledger_all <- do.call(rbind, ledgers)
rownames(ledger_all) <- NULL
ledger <- ledger_all[ledger_all$session_date >= contract$analysis_start & ledger_all$session_date <= contract$analysis_end, , drop = FALSE]

asset_predictive <- hreg_asset_predictive_summary(ledger_all, contract)
state_predictive <- hreg_state_prediction_summary(ledger_all, contract)
state_diag <- hreg_state_diagnostics(ledger_all, contract)
sensitivity <- hreg_sensitivity_summary(ledger_all, contract)

panel_predictive <- do.call(rbind, lapply(split(asset_predictive, interaction(asset_predictive$horizon, asset_predictive$sample, asset_predictive$model, drop = TRUE)), function(x) {
  data.frame(horizon = x$horizon[[1L]], sample = x$sample[[1L]], model = x$model[[1L]], assets = nrow(x),
             median_spearman = median_na(x$spearman), mean_spearman = mean_na(x$spearman),
             positive_asset_fraction = mean(x$spearman > 0, na.rm = TRUE),
             q25_spearman = as.numeric(stats::quantile(x$spearman, .25, na.rm = TRUE)),
             q75_spearman = as.numeric(stats::quantile(x$spearman, .75, na.rm = TRUE)), stringsAsFactors = FALSE)
}))
panel_predictive <- panel_predictive[order(panel_predictive$sample, panel_predictive$horizon, panel_predictive$model), , drop = FALSE]

panel_state <- do.call(rbind, lapply(split(state_predictive, interaction(state_predictive$horizon, state_predictive$sample, drop = TRUE)), function(x) {
  data.frame(horizon = x$horizon[[1L]], sample = x$sample[[1L]], assets = nrow(x),
             median_low_ntr = median_na(x$low_median), median_medium_ntr = median_na(x$medium_median), median_high_ntr = median_na(x$high_median),
             median_medium_low_ratio = median_na(x$medium_low_ratio), median_high_low_ratio = median_na(x$high_low_ratio),
             monotonic_asset_fraction = mean(x$monotonic_ordering, na.rm = TRUE), high_above_low_asset_fraction = mean(x$high_above_low, na.rm = TRUE),
             stringsAsFactors = FALSE)
}))
panel_state <- panel_state[order(panel_state$sample, panel_state$horizon), , drop = FALSE]

panel_occupancy <- data.frame(
  assets = nrow(state_diag$occupancy),
  median_low_fraction = median_na(state_diag$occupancy$low_fraction),
  median_medium_fraction = median_na(state_diag$occupancy$medium_fraction),
  median_high_fraction = median_na(state_diag$occupancy$high_fraction),
  median_switches_per_year = median_na(state_diag$switching$switches_per_year),
  median_reversal_fraction = median_na(state_diag$switching$reversal_fraction),
  median_run_sessions = median_na(state_diag$runs$sessions), stringsAsFactors = FALSE
)

sensitivity_panel <- do.call(rbind, lapply(split(sensitivity, sensitivity$specification), function(x) {
  data.frame(specification = x$specification[[1L]], assets = nrow(x), median_state_agreement = median_na(x$state_agreement),
             minimum_state_agreement = min(x$state_agreement, na.rm = TRUE), stringsAsFactors = FALSE)
}))

ink <- "#202630"; blue <- "#3D8DFF"; cyan <- "#6DCBF4"; gray <- "#B8BCC4"; pale <- "#EDEDED"; low_color <- "#D0EDFA"; medium_color <- "#D9D9D9"; high_color <- "#F2A65A"
state_colors <- c(LOW = low_color, MEDIUM = medium_color, HIGH = high_color)

shade_states <- function(dates, states) {
  keep <- !is.na(states)
  dates <- dates[keep]; states <- states[keep]
  if (!length(dates)) return(invisible(NULL))
  groups <- cumsum(c(TRUE, states[-1L] != head(states, -1L)))
  usr <- par("usr")
  for (g in unique(groups)) {
    z <- dates[groups == g]
    rect(min(z), usr[[3L]], max(z) + 1, usr[[4L]], col = grDevices::adjustcolor(state_colors[[states[groups == g][[1L]]]], .42), border = NA)
  }
}

representatives <- c("SPY", "AMD", "TSLA")
png(file.path(visual_dir, "representative_state_tapes.png"), 1900, 1500, res = 150)
par(mfrow = c(3, 2), mar = c(3.5, 5, 3.2, 1.5), oma = c(1, 1, 2, 1))
for (symbol in representatives) {
  x <- ledger[ledger$symbol == symbol, , drop = FALSE]
  plot(x$session_date, x$close, type = "n", xlab = "", ylab = "Adjusted close", main = paste0(symbol, " | price under causal volatility states"))
  shade_states(x$session_date, x$regime_state); lines(x$session_date, x$close, col = ink, lwd = 1.2); box()
  plot(x$session_date, 100 * x$atr_percentile, type = "l", col = blue, lwd = 1.3, ylim = c(0, 100), xlab = "Session", ylab = "ATR% percentile", main = paste0(symbol, " | percentile and switch thresholds"))
  abline(h = c(30, 40, 60, 70), col = c(low_color, gray, gray, high_color), lty = c(1, 2, 2, 1), lwd = 1.4)
}
mtext("HYP-REG-01.1 | state labels are known only after each close", outer = TRUE, cex = 1.15, font = 2)
dev.off()

state_plot <- panel_state[panel_state$sample == "NON_OVERLAPPING", , drop = FALSE]
png(file.path(visual_dir, "forward_range_ordering.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 3), mar = c(5, 5, 4, 1))
for (h in contract$horizons) {
  x <- state_plot[state_plot$horizon == h, , drop = FALSE]
  values <- c(LOW = x$median_low_ntr, MEDIUM = x$median_medium_ntr, HIGH = x$median_high_ntr)
  barplot(100 * values, col = state_colors[names(values)], border = NA, ylab = "Median future normalized range (%)", main = paste0(h, "-session horizon"), ylim = c(0, max(100 * values, na.rm = TRUE) * 1.18))
  text(seq_along(values), 100 * values, labels = sprintf("%.3f", 100 * values), pos = 3, cex = .85)
}
dev.off()

benchmark_plot <- panel_predictive[panel_predictive$sample == "NON_OVERLAPPING", , drop = FALSE]
model_order <- c("ATR_PERCENTILE", "EWMA_VOL_PERCENTILE", "CURRENT_NTR_PERCENTILE")
model_labels <- c(ATR_PERCENTILE = "ATR% percentile", EWMA_VOL_PERCENTILE = "EWMA percentile", CURRENT_NTR_PERCENTILE = "Current-range percentile")
model_colors <- c(ATR_PERCENTILE = blue, EWMA_VOL_PERCENTILE = high_color, CURRENT_NTR_PERCENTILE = gray)
png(file.path(visual_dir, "predictive_benchmark_comparison.png"), 1800, 1050, res = 150)
par(mar = c(5, 6, 4, 2))
plot(range(contract$horizons), range(benchmark_plot$median_spearman, na.rm = TRUE), type = "n", xaxt = "n", xlab = "Forward horizon (sessions)", ylab = "Median per-asset Spearman correlation", main = "Directionless volatility forecast | non-overlapping observations")
axis(1, at = contract$horizons)
abline(h = 0, col = pale)
for (model in model_order) {
  x <- benchmark_plot[benchmark_plot$model == model, ]; x <- x[order(x$horizon), ]
  lines(x$horizon, x$median_spearman, type = "b", pch = 19, lwd = 2.2, col = model_colors[[model]])
}
legend("topright", model_labels[model_order], col = model_colors[model_order], lty = 1, pch = 19, lwd = 2, bty = "n")
dev.off()

portability <- state_predictive[state_predictive$sample == "NON_OVERLAPPING", c("symbol", "horizon", "high_low_ratio")]
ratio_matrix <- matrix(NA_real_, nrow = length(registry$symbol), ncol = length(contract$horizons), dimnames = list(registry$symbol, paste0("H", contract$horizons)))
for (i in seq_len(nrow(portability))) ratio_matrix[portability$symbol[[i]], paste0("H", portability$horizon[[i]])] <- portability$high_low_ratio[[i]]
png(file.path(visual_dir, "cross_asset_high_low_range_ratio.png"), 1500, 1500, res = 150)
par(mar = c(5, 8, 4, 7))
z <- pmin(pmax(ratio_matrix, .8), 2.0)
image(seq_len(ncol(z)), seq_len(nrow(z)), t(z[nrow(z):1, , drop = FALSE]), col = grDevices::colorRampPalette(c("#D0EDFA", "#FFFFFF", "#F2A65A"))(80), zlim = c(.8, 2), axes = FALSE, xlab = "Forward horizon", ylab = "", main = "High-state / low-state future range ratio")
axis(1, at = seq_len(ncol(z)), labels = colnames(z)); axis(2, at = seq_len(nrow(z)), labels = rev(rownames(z)), las = 1, cex.axis = .75)
for (i in seq_len(nrow(z))) for (j in seq_len(ncol(z))) text(j, nrow(z) - i + 1, sprintf("%.2f", z[i, j]), cex = .62)
dev.off()

png(file.path(visual_dir, "state_dynamics.png"), 1800, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 2))
occ <- t(as.matrix(state_diag$occupancy[c("low_fraction", "medium_fraction", "high_fraction")]))
colnames(occ) <- state_diag$occupancy$symbol
barplot(occ, col = state_colors, border = NA, las = 2, cex.names = .7, ylab = "Fraction of labeled sessions", main = "State occupancy by asset")
transition_matrix <- xtabs(probability ~ from_state + to_state, data = state_diag$transition)
image(seq_len(3), seq_len(3), t(transition_matrix[3:1, , drop = FALSE]), col = grDevices::colorRampPalette(c("white", blue))(80), zlim = c(0, 1), axes = FALSE, xlab = "Next state", ylab = "Current state", main = "One-session transition probabilities")
axis(1, at = 1:3, labels = colnames(transition_matrix)); axis(2, at = 1:3, labels = rev(rownames(transition_matrix)), las = 1)
for (i in 1:3) for (j in 1:3) text(j, 4 - i, sprintf("%.1f%%", 100 * transition_matrix[i, j]), cex = 1)
dev.off()

png(file.path(visual_dir, "sensitivity_state_agreement.png"), 1600, 950, res = 150)
par(mar = c(8, 6, 4, 2))
sens <- sensitivity_panel[order(sensitivity_panel$median_state_agreement), ]
barplot(100 * sens$median_state_agreement, names.arg = sens$specification, col = blue, border = NA, las = 2, ylab = "Median state agreement with ATR14 / P252 (%)", main = "Nearby mechanics are diagnostics, not winner candidates", ylim = c(0, 100))
abline(h = 80, col = gray, lty = 2)
dev.off()

integrity <- data.frame(
  check = c("registered_26", "unique_symbols", "source_panel_match", "explicit_as_of", "confirmation_excluded", "score_bounds", "three_state_vocabulary", "nonoverlap_h1", "no_strategy_outcomes", "all_assets_retained"),
  passed = c(
    nrow(registry) == 26L,
    !anyDuplicated(registry$symbol),
    setequal(registry$symbol, source_registry$symbol),
    nzchar(contract$as_of_timestamp),
    !any(ledger$session_date >= contract$confirmation_start),
    all(ledger$atr_percentile[is.finite(ledger$atr_percentile)] >= 0 & ledger$atr_percentile[is.finite(ledger$atr_percentile)] <= 1),
    all(stats::na.omit(unique(ledger$regime_state)) %in% c("LOW", "MEDIUM", "HIGH")),
    all(ledger$nonoverlap_h1[is.finite(ledger$future_mean_ntr_h1) & is.finite(ledger$atr_percentile)]),
    !any(c("strategy_return", "pnl", "sharpe", "drawdown", "hit_rate") %in% names(ledger)),
    length(unique(ledger$symbol)) == 26L
  ), stringsAsFactors = FALSE
)
if (!all(integrity$passed)) stop("Integrity failed: ", paste(integrity$check[!integrity$passed], collapse = ", "), call. = FALSE)

run_spec <- data.frame(
  hypothesis_id = contract$hypothesis_id,
  status = "DIAGNOSTIC_COMPLETE_STOP_BEFORE_STRATEGY_OVERLAY",
  as_of_timestamp = contract$as_of_timestamp,
  query_start = contract$query_start,
  analysis_start = contract$analysis_start,
  analysis_end = contract$analysis_end,
  assets = nrow(registry),
  primary_measure = "Wilder ATR14 percent of close",
  percentile_rule = "midrank versus preceding 252 observations excluding current",
  states = "LOW<30; MEDIUM; HIGH>70 with 30/40 and 60/70 hysteresis",
  prediction_targets = "future mean normalized true range at h=1,5,20",
  inference = "deterministic non-overlapping observations by asset/horizon",
  strategy_outcomes = "PROHIBITED",
  confirmation_2024_plus = "SEALED",
  refresh = refresh,
  stringsAsFactors = FALSE
)

files <- list(
  run_spec = run_spec,
  integrity = integrity,
  registry = registry,
  coverage = coverage,
  query_health = query$health,
  daily_state_ledger = ledger,
  asset_predictive_summary = asset_predictive,
  panel_predictive_summary = panel_predictive,
  asset_state_prediction = state_predictive,
  panel_state_prediction = panel_state,
  state_occupancy = state_diag$occupancy,
  state_switching = state_diag$switching,
  state_runs = state_diag$runs,
  state_transitions = state_diag$transition,
  panel_state_dynamics = panel_occupancy,
  sensitivity_asset = sensitivity,
  sensitivity_panel = sensitivity_panel
)
for (name in names(files)) write_csv(files[[name]], file.path(output_dir, paste0("hyp_reg_01_1_", name, ".csv")))

primary_nonoverlap <- panel_predictive[panel_predictive$sample == "NON_OVERLAPPING" & panel_predictive$model == "ATR_PERCENTILE", ]
state_nonoverlap <- panel_state[panel_state$sample == "NON_OVERLAPPING", ]
report <- c(
  "# HYP-REG-01.1 ATR-Percent Volatility-Regime Diagnostic",
  "",
  "Status: `DIAGNOSTIC_COMPLETE_STOP_BEFORE_STRATEGY_OVERLAY`",
  "",
  sprintf("- Registered / analyzed assets: %d / %d", nrow(registry), length(unique(ledger$symbol))),
  sprintf("- Median state occupancy: low %s, medium %s, high %s", pct(panel_occupancy$median_low_fraction), pct(panel_occupancy$median_medium_fraction), pct(panel_occupancy$median_high_fraction)),
  sprintf("- Median switches per year / one-session reversal share: %.1f / %s", panel_occupancy$median_switches_per_year, pct(panel_occupancy$median_reversal_fraction)),
  "",
  "## Non-overlapping predictive readout",
  "",
  paste(sprintf("- H=%d: ATR%% median Spearman %.3f; positive assets %s; high/low range ratio %.2fx; high above low in %s of assets.",
                primary_nonoverlap$horizon, primary_nonoverlap$median_spearman, pct(primary_nonoverlap$positive_asset_fraction),
                state_nonoverlap$median_high_low_ratio[match(primary_nonoverlap$horizon, state_nonoverlap$horizon)],
                pct(state_nonoverlap$high_above_low_asset_fraction[match(primary_nonoverlap$horizon, state_nonoverlap$horizon)]))),
  "",
  "This packet validates only causal volatility-state measurement and directionless range prediction. It contains no strategy performance and grants no strategy-routing, confirmation, leverage, portfolio, advice, or live authority."
)
writeLines(report, file.path(output_dir, "hyp_reg_01_1_report.md"), useBytes = TRUE)
message("HYP-REG-01.1 complete: ", output_dir)
