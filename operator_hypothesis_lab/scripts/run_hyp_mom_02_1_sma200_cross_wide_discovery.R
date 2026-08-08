options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_02_1_sma200_cross.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
add_identity <- function(x, reg) {
  if (is.null(x) || !nrow(x)) return(x)
  identity <- reg[rep(1L, nrow(x)), c("instance_id", "symbol", "cohort", "sector", "source_registry"), drop = FALSE]
  cbind(identity, x[, setdiff(names(x), "symbol"), drop = FALSE])
}
percent <- function(x, digits = 1L) paste0(formatC(100 * x, digits = digits, format = "f"), "%")

contract <- hyp_mom021_validate_contract()
original_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_01_1_discovery_registry.csv")
wide_path <- file.path(repo_root, "literature_studies", "registries", "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv")
original <- utils::read.csv(original_path, stringsAsFactors = FALSE)
wide <- utils::read.csv(wide_path, stringsAsFactors = FALSE)
original_registry <- data.frame(
  instance_id = original$instance_id, symbol = original$symbol, cohort = "ORIGINAL_22",
  sector = original$sector, source_registry = original$source_registry, stringsAsFactors = FALSE
)
wide_registry <- data.frame(
  instance_id = wide$instance_id, symbol = wide$symbol, cohort = wide$cohort,
  sector = wide$sector, source_registry = wide$source_id, stringsAsFactors = FALSE
)
registry <- rbind(original_registry, wide_registry)
if (nrow(registry) != 122L || anyDuplicated(registry$symbol) || length(unique(registry$sector)) != 11L) {
  stop("Frozen combined registry integrity failed.", call. = FALSE)
}

run_id <- env_or("GEN5_HYP_MOM_021_RUN_ID", "hyp_mom_02_1_sma200_cross_wide_discovery_20260808")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_MOM_021_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = as.Date("2019-01-02"), end_date = contract$discovery_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = c(registry$symbol, "SPY"),
  universe_name = "hyp_mom_02_1_sma200_cross_wide_discovery",
  universe_roles = "frozen_combined_122,spy_calendar",
  refresh = refresh, repo_root = repo_root
)
bars_all <- query$bars
bars_all$session_date <- as.Date(bars_all$session_date)
if (any(bars_all$session_date >= contract$confirmation_start)) stop("Confirmation bars entered discovery.", call. = FALSE)
if (anyDuplicated(bars_all[c("symbol", "session_date")])) stop("Duplicate queried bars.", call. = FALSE)
spy_dates <- sort(unique(bars_all$session_date[bars_all$symbol == "SPY" & bars_all$session_date >= contract$discovery_start & bars_all$session_date <= contract$discovery_end]))
if (!length(spy_dates)) stop("SPY discovery calendar unavailable.", call. = FALSE)

coverage_rows <- lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]
  x <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]
  x <- x[order(x$session_date), , drop = FALSE]
  invalid <- if (!nrow(x)) 0L else sum(
    !is.finite(x$open) | !is.finite(x$high) | !is.finite(x$low) | !is.finite(x$close) |
      !is.finite(x$volume) | x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0
  )
  observed <- x$session_date[x$session_date >= contract$discovery_start & x$session_date <= contract$discovery_end]
  missing <- length(setdiff(spy_dates, observed))
  prehistory <- sum(x$session_date < contract$discovery_start)
  status <- if (!nrow(x)) "NO_HISTORY" else if (invalid > 0L) "INVALID_OHLCV" else if (missing > 0L) "DISCOVERY_INCOMPLETE" else if (prehistory < contract$prehistory_sessions) "PREHISTORY_INCOMPLETE" else "ELIGIBLE"
  cbind(reg, data.frame(observed_rows = nrow(x), discovery_missing_sessions = missing,
                        prehistory_sessions = prehistory, invalid_ohlcv_rows = invalid,
                        coverage_status = status, analysis_eligible = status == "ELIGIBLE"))
})
coverage <- do.call(rbind, coverage_rows)
eligible <- registry[registry$symbol %in% coverage$symbol[coverage$analysis_eligible], , drop = FALSE]
if (!nrow(eligible)) stop("No registered asset passed coverage.", call. = FALSE)

summary_rows <- trade_rows <- path_rows <- random_rows <- list()
message("HYP-MOM-02.1 starting: ", nrow(eligible), " eligible assets.")
for (i in seq_len(nrow(eligible))) {
  reg <- eligible[i, , drop = FALSE]
  message(sprintf("[%03d/%03d] %s", i, nrow(eligible), reg$symbol))
  bars <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]
  analysis <- hyp_mom021_analyze_asset(bars, contract, seed_offset = i * 1000L)
  summary_rows[[i]] <- add_identity(analysis$summary, reg)
  trade_rows[[i]] <- add_identity(analysis$trades, reg)
  path_rows[[i]] <- add_identity(analysis$path, reg)
  random_rows[[i]] <- add_identity(analysis$random, reg)
}
asset_summary <- do.call(rbind, summary_rows)
trades <- do.call(rbind, trade_rows)
paths <- do.call(rbind, path_rows)
random_controls <- do.call(rbind, random_rows)
rownames(asset_summary) <- rownames(trades) <- rownames(paths) <- rownames(random_controls) <- NULL

panel_summary <- function(x, label) data.frame(
  panel = label, asset_count = nrow(x), trade_count = sum(x$trade_count),
  median_primary_return = stats::median(x$primary_return),
  mean_primary_return = mean(x$primary_return),
  positive_primary_assets = sum(x$primary_return > 0),
  stress_positive_assets = sum(x$stress_return > 0),
  median_buy_hold_return = stats::median(x$buy_hold_primary_return),
  median_excess_vs_buy_hold = stats::median(x$excess_vs_buy_hold),
  assets_beating_buy_hold = sum(x$excess_vs_buy_hold > 0),
  median_exposure_fraction = stats::median(x$exposure_fraction),
  median_primary_sharpe = stats::median(x$primary_sharpe, na.rm = TRUE),
  median_maximum_drawdown = stats::median(x$maximum_drawdown),
  median_buy_hold_maximum_drawdown = stats::median(x$buy_hold_maximum_drawdown),
  median_drawdown_improvement = stats::median(x$drawdown_improvement),
  median_random_percentile = stats::median(x$observed_random_percentile),
  assets_above_random_50 = sum(x$observed_random_percentile > 0.5),
  assets_above_random_80 = sum(x$observed_random_percentile > 0.8),
  median_trade_count = stats::median(x$trade_count),
  median_holding_sessions = stats::median(x$median_holding_sessions),
  median_whipsaw_fraction = stats::median(x$whipsaw_20_fraction),
  stringsAsFactors = FALSE
)
panels <- rbind(
  panel_summary(asset_summary, "COMBINED"),
  panel_summary(asset_summary[asset_summary$cohort == "ORIGINAL_22", ], "ORIGINAL_22"),
  panel_summary(asset_summary[asset_summary$cohort == "DIVERSIFIED_CORE", ], "DIVERSIFIED_CORE"),
  panel_summary(asset_summary[asset_summary$cohort == "RETAIL_ATTENTION_2020", ], "RETAIL_ATTENTION_2020")
)
sector_summary <- do.call(rbind, lapply(sort(unique(asset_summary$sector)), function(s) panel_summary(asset_summary[asset_summary$sector == s, ], s)))

nearest_symbol <- function(values, target, symbols) symbols[order(abs(values - target), symbols)][[1L]]
manifest <- data.frame(
  tape_role = c("MEDIAN_EXCESS", "HIGHEST_EXCESS", "LOWEST_EXCESS", "BEST_DRAWDOWN_IMPROVEMENT", "HIGHEST_TRADE_COUNT", "LONGEST_MEDIAN_HOLD"),
  symbol = c(
    nearest_symbol(asset_summary$excess_vs_buy_hold, stats::median(asset_summary$excess_vs_buy_hold), asset_summary$symbol),
    asset_summary$symbol[order(-asset_summary$excess_vs_buy_hold, asset_summary$symbol)][[1L]],
    asset_summary$symbol[order(asset_summary$excess_vs_buy_hold, asset_summary$symbol)][[1L]],
    asset_summary$symbol[order(-asset_summary$drawdown_improvement, asset_summary$symbol)][[1L]],
    asset_summary$symbol[order(-asset_summary$trade_count, asset_summary$symbol)][[1L]],
    asset_summary$symbol[order(-asset_summary$median_holding_sessions, asset_summary$symbol)][[1L]]
  ), stringsAsFactors = FALSE
)
manifest <- merge(manifest, asset_summary, by = "symbol", all.x = TRUE, sort = FALSE)
manifest <- manifest[match(c("MEDIAN_EXCESS", "HIGHEST_EXCESS", "LOWEST_EXCESS", "BEST_DRAWDOWN_IMPROVEMENT", "HIGHEST_TRADE_COUNT", "LONGEST_MEDIAN_HOLD"), manifest$tape_role), ]
manifest$visual_file <- rep(NA_character_, nrow(manifest))

ink <- "#202630"; blue <- "#2C6CB0"; green <- "#2E8B57"; red <- "#C83E3A"; gray <- "#D8DEE7"; purple <- "#7654C4"
png(file.path(visual_dir, "coverage_and_composition.png"), 1800, 1000, res = 150)
par(mfrow = c(1, 3), mar = c(7, 5, 4, 1))
barplot(table(coverage$coverage_status), las = 2, col = ifelse(names(table(coverage$coverage_status)) == "ELIGIBLE", green, red), main = "Frozen 122-name coverage", ylab = "Assets")
cohort_tab <- table(coverage$cohort, coverage$analysis_eligible)
barplot(t(cohort_tab), beside = FALSE, col = c(red, green), las = 2, main = "Eligibility by source cohort", ylab = "Assets", legend.text = c("Not eligible", "Eligible"), args.legend = list(bty = "n", cex = .8))
sec <- sort(table(eligible$sector))
barplot(sec, horiz = TRUE, las = 1, col = blue, main = "Eligible assets by sector", xlab = "Assets")
dev.off()

png(file.path(visual_dir, "strategy_vs_buy_hold.png"), 1800, 1000, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
lims <- range(c(asset_summary$primary_return, asset_summary$buy_hold_primary_return))
plot(asset_summary$buy_hold_primary_return, asset_summary$primary_return, pch = 19, col = ifelse(asset_summary$excess_vs_buy_hold > 0, green, red), xlab = "Buy-and-hold return", ylab = "SMA200 strategy return", main = "Return consequence by asset", xlim = lims, ylim = lims)
abline(0, 1, lty = 2); abline(h = 0, v = 0, col = gray)
legend("topleft", c("Beat ownership", "Lagged ownership"), pch = 19, col = c(green, red), bty = "n")
plot(asset_summary$buy_hold_maximum_drawdown, asset_summary$maximum_drawdown, pch = 19, col = ifelse(asset_summary$drawdown_improvement > 0, blue, red), xlab = "Buy-and-hold maximum drawdown", ylab = "SMA200 maximum drawdown", main = "Drawdown consequence by asset")
abline(0, 1, lty = 2); abline(h = 0, v = 0, col = gray)
legend("topleft", c("Reduced drawdown", "Worse drawdown"), pch = 19, col = c(blue, red), bty = "n")
dev.off()

png(file.path(visual_dir, "return_drawdown_tradeoff.png"), 1800, 1000, res = 150)
par(mar = c(5, 5, 4, 2))
plot(asset_summary$excess_vs_buy_hold, asset_summary$drawdown_improvement, pch = 19,
     col = ifelse(asset_summary$excess_vs_buy_hold > 0 & asset_summary$drawdown_improvement > 0, green, blue),
     cex = 0.9 + 1.4 * asset_summary$exposure_fraction,
     xlab = "Excess return versus buy-and-hold", ylab = "Maximum-drawdown improvement", main = "Return versus protection: every dot is one asset")
abline(h = 0, v = 0, lty = 2, col = gray)
legend("bottomright", c("Improved both", "Tradeoff / worse"), pch = 19, col = c(green, blue), bty = "n")
dev.off()

png(file.path(visual_dir, "timing_controls_and_exposure.png"), 1800, 1000, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
hist(asset_summary$observed_random_percentile, breaks = seq(0, 1, .1), col = blue, border = "white", xlab = "Percentile vs circular state shifts", main = "Matched timing control")
abline(v = .5, lty = 2)
plot(asset_summary$exposure_fraction, asset_summary$excess_vs_buy_hold, pch = 19, col = ifelse(asset_summary$excess_vs_buy_hold > 0, green, red), xlab = "Fraction of sessions invested", ylab = "Excess return vs buy-and-hold", main = "Return tradeoff versus time in market")
abline(h = 0, lty = 2)
dev.off()

png(file.path(visual_dir, "trade_mechanics_distribution.png"), 1800, 1000, res = 150)
par(mfrow = c(1, 3), mar = c(5, 5, 4, 1))
hist(asset_summary$trade_count, col = blue, border = "white", main = "Round trips per asset", xlab = "Trade count")
hist(asset_summary$median_holding_sessions, col = green, border = "white", main = "Median holding duration", xlab = "Sessions")
hist(asset_summary$whipsaw_20_fraction, col = purple, border = "white", main = "Short-hold diagnostic", xlab = "Fraction <= 20 sessions")
dev.off()

o <- order(sector_summary$median_excess_vs_buy_hold)
png(file.path(visual_dir, "sector_descriptive_outcomes.png"), 1800, 1000, res = 150)
par(mfrow = c(1, 2), mar = c(5, 11, 4, 1))
barplot(sector_summary$median_excess_vs_buy_hold[o], names.arg = sector_summary$panel[o], horiz = TRUE, las = 1, col = ifelse(sector_summary$median_excess_vs_buy_hold[o] > 0, green, red), main = "Median excess return", xlab = "Return difference")
barplot(sector_summary$median_drawdown_improvement[o], names.arg = sector_summary$panel[o], horiz = TRUE, las = 1, col = blue, main = "Median drawdown improvement", xlab = "Drawdown difference")
dev.off()

plot_tape <- function(symbol, role, file) {
  p <- paths[paths$symbol == symbol, , drop = FALSE]
  s <- asset_summary[asset_summary$symbol == symbol, , drop = FALSE]
  png(file, 1800, 1100, res = 150)
  layout(matrix(c(1, 2), 2, 1), heights = c(1.25, 1))
  par(mar = c(2, 6, 4, 2))
  plot(p$session_date, p$close, type = "l", col = ink, lwd = 1.4, xlab = "", ylab = "Adjusted close", main = paste(role, "|", symbol, "| price and long/cash state"))
  lines(p$session_date, p$sma200, col = blue, lwd = 2)
  usr <- par("usr"); long <- which(p$target_from_prior_close)
  if (length(long)) segments(p$session_date[long], usr[[3L]], p$session_date[long], usr[[3L]] + .035 * diff(usr[3:4]), col = adjustcolor(green, .35), lwd = 3)
  legend("topleft", c("Close", "SMA200", "Long state"), col = c(ink, blue, green), lty = c(1, 1, 1), lwd = c(1.4, 2, 3), bty = "n")
  par(mar = c(6, 6, 3, 2))
  plot(p$session_date, p$strategy_wealth_open, type = "l", col = green, lwd = 2.2, xlab = "Session", ylab = "Wealth from 1.0", main = sprintf("Strategy %.1f%% | buy-hold %.1f%% | excess %.1f pp | max DD %.1f%%", 100*s$primary_return, 100*s$buy_hold_primary_return, 100*s$excess_vs_buy_hold, 100*s$maximum_drawdown))
  lines(p$session_date, p$buy_hold_wealth_open, col = ink, lwd = 1.5)
  legend("topleft", c("SMA200 long/cash", "Buy-and-hold"), col = c(green, ink), lty = 1, lwd = c(2.2, 1.5), bty = "n")
  dev.off()
}
for (i in seq_len(nrow(manifest))) {
  file <- file.path(visual_dir, sprintf("sma200_tape_%02d_%s_%s.png", i, tolower(manifest$tape_role[[i]]), tolower(manifest$symbol[[i]])))
  plot_tape(manifest$symbol[[i]], manifest$tape_role[[i]], file)
  manifest$visual_file[[i]] <- basename(file)
}

integrity <- data.frame(
  check = c("registered_122", "unique_symbols", "eleven_sectors", "explicit_as_of", "confirmation_excluded", "eligible_have_full_calendar", "eligible_have_prehistory", "no_replacements", "primary_cost_5bp", "stress_cost_10bp"),
  passed = c(nrow(registry) == 122L, !anyDuplicated(registry$symbol), length(unique(registry$sector)) == 11L,
             nzchar(contract$as_of_timestamp), !any(bars_all$session_date >= contract$confirmation_start),
             all(coverage$discovery_missing_sessions[coverage$analysis_eligible] == 0L),
             all(coverage$prehistory_sessions[coverage$analysis_eligible] >= contract$prehistory_sessions),
             nrow(eligible) == sum(coverage$analysis_eligible), contract$primary_cost_bps == 5, contract$stress_cost_bps == 10)
)
if (!all(integrity$passed)) stop("HYP-MOM-02.1 integrity check failed.", call. = FALSE)

run_spec <- data.frame(
  hypothesis_id = contract$hypothesis_id, status = "WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY",
  evidence_stage = contract$evidence_stage, as_of_timestamp = contract$as_of_timestamp,
  discovery_start = contract$discovery_start, discovery_end = contract$discovery_end,
  registered_assets = nrow(registry), eligible_assets = nrow(eligible),
  trade_count = nrow(trades), refresh = refresh, stringsAsFactors = FALSE
)
write_csv(run_spec, file.path(output_dir, "hyp_mom_02_1_run_spec.csv"))
write_csv(integrity, file.path(output_dir, "hyp_mom_02_1_integrity.csv"))
write_csv(registry, file.path(output_dir, "hyp_mom_02_1_registry.csv"))
write_csv(coverage, file.path(output_dir, "hyp_mom_02_1_coverage.csv"))
write_csv(query$health, file.path(output_dir, "hyp_mom_02_1_query_health.csv"))
write_csv(asset_summary, file.path(output_dir, "hyp_mom_02_1_asset_summary.csv"))
write_csv(trades, file.path(output_dir, "hyp_mom_02_1_trades.csv"))
write_csv(paths, file.path(output_dir, "hyp_mom_02_1_daily_paths.csv"))
write_csv(random_controls, file.path(output_dir, "hyp_mom_02_1_random_controls.csv"))
write_csv(panels, file.path(output_dir, "hyp_mom_02_1_panel_summary.csv"))
write_csv(sector_summary, file.path(output_dir, "hyp_mom_02_1_sector_summary.csv"))
write_csv(manifest, file.path(output_dir, "hyp_mom_02_1_tape_manifest.csv"))

combined <- panels[panels$panel == "COMBINED", ]
report <- c(
  "# HYP-MOM-02.1 SMA200 Cross Wide Discovery",
  "",
  "Status: `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`",
  "",
  sprintf("- Registered / eligible assets: %d / %d", nrow(registry), nrow(eligible)),
  sprintf("- Completed trades: %d", nrow(trades)),
  sprintf("- Median primary return: %s", percent(combined$median_primary_return)),
  sprintf("- Median buy-and-hold return: %s", percent(combined$median_buy_hold_return)),
  sprintf("- Assets beating buy-and-hold: %d / %d", combined$assets_beating_buy_hold, combined$asset_count),
  sprintf("- Median maximum drawdown: %s versus %s buy-and-hold", percent(combined$median_maximum_drawdown), percent(combined$median_buy_hold_maximum_drawdown)),
  sprintf("- Median exposure: %s", percent(combined$median_exposure_fraction)),
  sprintf("- Median matched-shift percentile: %s", percent(combined$median_random_percentile)),
  "",
  "This reused-window wide discovery describes the return/drawdown/whipsaw tradeoff. It does not authorize parameter changes, asset selection, a portfolio, or live behavior."
)
writeLines(report, file.path(output_dir, "hyp_mom_02_1_report.md"), useBytes = TRUE)
message("HYP-MOM-02.1 complete: ", output_dir)
