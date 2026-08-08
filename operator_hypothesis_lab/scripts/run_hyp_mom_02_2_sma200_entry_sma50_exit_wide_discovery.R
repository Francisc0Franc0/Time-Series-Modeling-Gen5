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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_02_2_sma200_entry_sma50_exit.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
add_identity <- function(x, reg) {
  if (!nrow(x)) {
    identity <- reg[FALSE, c("instance_id", "symbol", "cohort", "sector", "source_registry"), drop = FALSE]
    return(cbind(identity, x[, setdiff(names(x), "symbol"), drop = FALSE]))
  }
  identity <- reg[rep(1L, nrow(x)), c("instance_id", "symbol", "cohort", "sector", "source_registry"), drop = FALSE]
  cbind(identity, x[, setdiff(names(x), "symbol"), drop = FALSE])
}

contract_021 <- hyp_mom021_validate_contract()
contract_022 <- hyp_mom022_validate_contract()
if (!identical(contract_021$discovery_start, contract_022$discovery_start) ||
    !identical(contract_021$discovery_end, contract_022$discovery_end)) {
  stop("02.1 and 02.2 discovery windows differ.", call. = FALSE)
}

original <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_01_1_discovery_registry.csv"), stringsAsFactors = FALSE)
wide <- utils::read.csv(file.path(repo_root, "literature_studies", "registries", "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"), stringsAsFactors = FALSE)
registry <- rbind(
  data.frame(instance_id = original$instance_id, symbol = original$symbol, cohort = "ORIGINAL_22",
             sector = original$sector, source_registry = original$source_registry, stringsAsFactors = FALSE),
  data.frame(instance_id = wide$instance_id, symbol = wide$symbol, cohort = wide$cohort,
             sector = wide$sector, source_registry = wide$source_id, stringsAsFactors = FALSE)
)
if (nrow(registry) != 122L || anyDuplicated(registry$symbol) || length(unique(registry$sector)) != 11L) {
  stop("Frozen combined registry integrity failed.", call. = FALSE)
}

run_id <- env_or("GEN5_HYP_MOM_022_RUN_ID", "hyp_mom_02_2_sma200_entry_sma50_exit_wide_discovery_20260809")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = as.Date("2019-01-02"), end_date = contract_022$discovery_end,
  as_of_timestamp = contract_022$as_of_timestamp,
  symbols = c(registry$symbol, "SPY"),
  universe_name = "hyp_mom_02_2_sma200_entry_sma50_exit_wide_discovery",
  universe_roles = "frozen_combined_122,spy_calendar",
  refresh = env_bool("GEN5_HYP_MOM_022_REFRESH", FALSE), repo_root = repo_root
)
bars_all <- query$bars
bars_all$session_date <- as.Date(bars_all$session_date)
if (any(bars_all$session_date >= contract_022$confirmation_start)) stop("Confirmation bars entered discovery.", call. = FALSE)
if (anyDuplicated(bars_all[c("symbol", "session_date")])) stop("Duplicate queried bars.", call. = FALSE)
spy_dates <- sort(unique(bars_all$session_date[bars_all$symbol == "SPY" &
  bars_all$session_date >= contract_022$discovery_start & bars_all$session_date <= contract_022$discovery_end]))
if (!length(spy_dates)) stop("SPY discovery calendar unavailable.", call. = FALSE)

coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]
  x <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]
  x <- x[order(x$session_date), , drop = FALSE]
  invalid <- if (!nrow(x)) 0L else sum(!is.finite(x$open) | !is.finite(x$high) | !is.finite(x$low) |
    !is.finite(x$close) | !is.finite(x$volume) | x$open <= 0 | x$high <= 0 | x$low <= 0 |
    x$close <= 0 | x$volume < 0)
  observed <- x$session_date[x$session_date >= contract_022$discovery_start & x$session_date <= contract_022$discovery_end]
  missing <- length(setdiff(spy_dates, observed))
  prehistory <- sum(x$session_date < contract_022$discovery_start)
  status <- if (!nrow(x)) "NO_HISTORY" else if (invalid > 0L) "INVALID_OHLCV" else if (missing > 0L) {
    "DISCOVERY_INCOMPLETE"
  } else if (prehistory < contract_022$prehistory_sessions) "PREHISTORY_INCOMPLETE" else "ELIGIBLE"
  cbind(reg, data.frame(observed_rows = nrow(x), discovery_missing_sessions = missing,
                        prehistory_sessions = prehistory, invalid_ohlcv_rows = invalid,
                        coverage_status = status, analysis_eligible = status == "ELIGIBLE"))
}))
eligible <- registry[registry$symbol %in% coverage$symbol[coverage$analysis_eligible], , drop = FALSE]
if (!nrow(eligible)) stop("No registered asset passed coverage.", call. = FALSE)

summary_021 <- summary_022 <- trades_021 <- trades_022 <- paths_021 <- paths_022 <- controls_022 <- list()
exit_pairs <- list()
message("HYP-MOM-02.2 starting: ", nrow(eligible), " eligible assets.")
for (i in seq_len(nrow(eligible))) {
  reg <- eligible[i, , drop = FALSE]
  message(sprintf("[%03d/%03d] %s", i, nrow(eligible), reg$symbol))
  bars <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]
  a021 <- hyp_mom021_analyze_asset(bars, contract_021, seed_offset = i * 1000L)
  a022 <- hyp_mom022_analyze_asset(bars, contract_022, seed_offset = i * 1000L)
  summary_021[[i]] <- add_identity(a021$summary, reg)
  summary_022[[i]] <- add_identity(a022$summary, reg)
  trades_021[[i]] <- add_identity(a021$trades, reg)
  trades_022[[i]] <- add_identity(a022$trades, reg)
  paths_021[[i]] <- add_identity(a021$path, reg)
  paths_022[[i]] <- add_identity(a022$path, reg)
  controls_022[[i]] <- add_identity(a022$random, reg)

  if (nrow(a021$trades) && nrow(a022$trades)) {
    paired <- merge(
      a022$trades[, c("symbol", "entry_date", "exit_date", "entry_open", "exit_open", "holding_sessions", "net_trade_return")],
      a021$trades[, c("symbol", "entry_date", "exit_date", "entry_open", "exit_open", "holding_sessions", "net_trade_return")],
      by = c("symbol", "entry_date"), suffixes = c("_022", "_021"), sort = FALSE
    )
    if (nrow(paired)) {
      dates <- a022$path$session_date
      paired$exit_sessions_earlier <- match(paired$exit_date_021, dates) - match(paired$exit_date_022, dates)
      paired$exit_timing <- ifelse(paired$exit_sessions_earlier > 0, "EARLIER",
                                   ifelse(paired$exit_sessions_earlier < 0, "LATER", "SAME_SESSION"))
      paired$return_after_early_022_exit_until_021_exit <- ifelse(
        paired$exit_timing == "EARLIER", paired$exit_open_021 / paired$exit_open_022 - 1, NA_real_
      )
      paired$early_exit_consequence <- ifelse(
        paired$exit_timing != "EARLIER", "NOT_EARLIER",
        ifelse(paired$return_after_early_022_exit_until_021_exit < 0, "SAVED_DOWNSIDE",
               ifelse(paired$return_after_early_022_exit_until_021_exit > 0, "FOREGONE_UPSIDE", "UNCHANGED"))
      )
      exit_pairs[[length(exit_pairs) + 1L]] <- add_identity(paired, reg)
    }
  }
}

asset_021 <- do.call(rbind, summary_021)
asset_022 <- do.call(rbind, summary_022)
trades_021 <- do.call(rbind, trades_021)
trades_022 <- do.call(rbind, trades_022)
paths_021 <- do.call(rbind, paths_021)
paths_022 <- do.call(rbind, paths_022)
controls_022 <- do.call(rbind, controls_022)
exit_pairs <- if (length(exit_pairs)) do.call(rbind, exit_pairs) else data.frame()

comparison <- merge(
  asset_022, asset_021[, c("symbol", "primary_return", "stress_return", "exposure_fraction", "trade_count",
                           "primary_sharpe", "maximum_drawdown", "median_holding_sessions", "buy_hold_primary_return")],
  by = "symbol", suffixes = c("_022", "_021"), sort = FALSE
)
comparison$return_delta_vs_021 <- comparison$primary_return_022 - comparison$primary_return_021
comparison$drawdown_delta_vs_021 <- comparison$maximum_drawdown_022 - comparison$maximum_drawdown_021
comparison$exposure_delta_vs_021 <- comparison$exposure_fraction_022 - comparison$exposure_fraction_021
comparison$trade_count_delta_vs_021 <- comparison$trade_count_022 - comparison$trade_count_021
comparison$sharpe_delta_vs_021 <- comparison$primary_sharpe_022 - comparison$primary_sharpe_021
comparison$beats_021 <- comparison$return_delta_vs_021 > 0
comparison$improves_drawdown_vs_021 <- comparison$drawdown_delta_vs_021 > 0

panel_summary <- function(x, label) data.frame(
  panel = label, asset_count = nrow(x), trade_count_022 = sum(x$trade_count_022),
  median_return_022 = stats::median(x$primary_return_022),
  median_return_021 = stats::median(x$primary_return_021),
  median_buy_hold_return = stats::median(x$buy_hold_primary_return_022),
  median_return_delta_vs_021 = stats::median(x$return_delta_vs_021),
  assets_beating_021 = sum(x$beats_021),
  median_drawdown_022 = stats::median(x$maximum_drawdown_022),
  median_drawdown_021 = stats::median(x$maximum_drawdown_021),
  median_drawdown_delta_vs_021 = stats::median(x$drawdown_delta_vs_021),
  assets_improving_drawdown_vs_021 = sum(x$improves_drawdown_vs_021),
  median_exposure_022 = stats::median(x$exposure_fraction_022),
  median_exposure_021 = stats::median(x$exposure_fraction_021),
  median_trade_count_022 = stats::median(x$trade_count_022),
  median_holding_022 = median_na(x$median_holding_sessions_022),
  median_lockout_sessions = stats::median(x$lockout_sessions),
  total_skipped_entries = sum(x$skipped_entry_count), stringsAsFactors = FALSE
)
panels <- rbind(
  panel_summary(comparison, "COMBINED"),
  panel_summary(comparison[comparison$cohort == "ORIGINAL_22", ], "ORIGINAL_22"),
  panel_summary(comparison[comparison$cohort == "DIVERSIFIED_CORE", ], "DIVERSIFIED_CORE"),
  panel_summary(comparison[comparison$cohort == "RETAIL_ATTENTION_2020", ], "RETAIL_ATTENTION_2020")
)
sector_summary <- do.call(rbind, lapply(sort(unique(comparison$sector)), function(s) panel_summary(comparison[comparison$sector == s, ], s)))

nearest_symbol <- function(values, target, symbols) symbols[order(abs(values - target), symbols)][[1L]]
manifest <- data.frame(
  tape_role = c("MEDIAN_RETURN_CHANGE", "LARGEST_RETURN_IMPROVEMENT", "LARGEST_RETURN_DETERIORATION",
                "LARGEST_DRAWDOWN_IMPROVEMENT", "LARGEST_EXPOSURE_REDUCTION", "MOST_LOCKOUT_SESSIONS"),
  symbol = c(
    nearest_symbol(comparison$return_delta_vs_021, stats::median(comparison$return_delta_vs_021), comparison$symbol),
    comparison$symbol[order(-comparison$return_delta_vs_021, comparison$symbol)][[1L]],
    comparison$symbol[order(comparison$return_delta_vs_021, comparison$symbol)][[1L]],
    comparison$symbol[order(-comparison$drawdown_delta_vs_021, comparison$symbol)][[1L]],
    comparison$symbol[order(comparison$exposure_delta_vs_021, comparison$symbol)][[1L]],
    comparison$symbol[order(-comparison$lockout_sessions, comparison$symbol)][[1L]]
  ), stringsAsFactors = FALSE
)
manifest <- merge(manifest, comparison, by = "symbol", all.x = TRUE, sort = FALSE)
manifest <- manifest[match(c("MEDIAN_RETURN_CHANGE", "LARGEST_RETURN_IMPROVEMENT", "LARGEST_RETURN_DETERIORATION",
                             "LARGEST_DRAWDOWN_IMPROVEMENT", "LARGEST_EXPOSURE_REDUCTION", "MOST_LOCKOUT_SESSIONS"), manifest$tape_role), ]
manifest$visual_file <- file.path("visuals", paste0("paired_tape_", seq_len(nrow(manifest)), "_", tolower(manifest$symbol), ".png"))

ink <- "#202630"; blue <- "#2C6CB0"; green <- "#2E8B57"; red <- "#C83E3A"; gray <- "#A7B0BE"; purple <- "#7654C4"; orange <- "#D98524"
png(file.path(visual_dir, "coverage_and_composition.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(5, 16, 4, 1))
coverage_table <- sort(table(coverage$coverage_status))
barplot(coverage_table, horiz = TRUE, las = 1, col = ifelse(names(coverage_table) == "ELIGIBLE", green, red), main = "Frozen 122-name coverage", xlab = "Assets")
barplot(sort(table(eligible$sector)), horiz = TRUE, las = 1, col = blue, main = "Eligible assets by sector", xlab = "Assets")
dev.off()

png(file.path(visual_dir, "variant_return_drawdown_comparison.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(comparison$return_delta_vs_021, comparison$drawdown_delta_vs_021, pch = 19,
     col = ifelse(comparison$return_delta_vs_021 > 0 & comparison$drawdown_delta_vs_021 > 0, green,
                  ifelse(comparison$return_delta_vs_021 < 0 & comparison$drawdown_delta_vs_021 < 0, red, blue)),
     xlab = "02.2 return minus cross-only 02.1", ylab = "02.2 max-DD improvement versus 02.1",
     main = "Composite rule changes return and protection")
abline(h = 0, v = 0, lty = 2, col = gray)
hist(comparison$exposure_delta_vs_021, col = purple, border = "white",
     main = "Change in time invested", xlab = "02.2 exposure minus 02.1")
abline(v = 0, lty = 2, col = gray)
dev.off()

png(file.path(visual_dir, "trade_mechanics_and_lockout.png"), 1800, 900, res = 150)
par(mfrow = c(1, 3), mar = c(5, 5, 4, 1))
hist(comparison$trade_count_022, col = blue, border = "white", main = "02.2 round trips", xlab = "Trades per asset")
hist(stats::na.omit(comparison$median_holding_sessions_022), col = green, border = "white", main = "Holding duration", xlab = "Median sessions")
hist(comparison$lockout_sessions, col = orange, border = "white", main = "Strict re-entry lockout", xlab = "Sessions per asset")
dev.off()

if (nrow(exit_pairs)) {
  early_pairs <- exit_pairs[exit_pairs$exit_timing == "EARLIER", , drop = FALSE]
  png(file.path(visual_dir, "matched_exit_consequences.png"), 1800, 900, res = 150)
  par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  hist(exit_pairs$exit_sessions_earlier, col = blue, border = "white", main = "SMA50 was not always the earlier exit", xlab = "Sessions: positive means 02.2 exited earlier")
  hist(early_pairs$return_after_early_022_exit_until_021_exit,
       col = ifelse(stats::median(early_pairs$return_after_early_022_exit_until_021_exit) >= 0, red, green), border = "white",
       main = "Only genuinely earlier exits", xlab = "Return from 02.2 exit open to later 02.1 exit open")
  abline(v = 0, lty = 2, col = gray)
  dev.off()
}

png(file.path(visual_dir, "timing_control_and_ownership.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
hist(stats::na.omit(asset_022$observed_random_percentile), breaks = seq(0, 1, .1), col = blue, border = "white",
     main = "Exposure-matched circular shifts", xlab = "Observed schedule percentile")
abline(v = .5, lty = 2, col = gray)
plot(asset_022$exposure_fraction, asset_022$excess_vs_buy_hold, pch = 19,
     col = ifelse(asset_022$excess_vs_buy_hold > 0, green, red),
     xlab = "Fraction of sessions invested", ylab = "Excess return versus buy-and-hold",
     main = "Low exposure did not erase opportunity cost")
abline(h = 0, lty = 2, col = gray)
dev.off()

png(file.path(visual_dir, "cohort_variant_comparison.png"), 1800, 900, res = 150)
par(mar = c(5, 8, 4, 2))
cohort_panels <- panels[panels$panel != "COMBINED", ]
values <- rbind(cohort_panels$median_return_021, cohort_panels$median_return_022, cohort_panels$median_buy_hold_return)
barplot(values, beside = TRUE, names.arg = cohort_panels$panel, col = c(gray, blue, ink), las = 1,
        main = "Median return by frozen source cohort", ylab = "Compounded return",
        legend.text = c("02.1 fresh SMA200", "02.2 SMA50 exit", "Buy-and-hold"), args.legend = list(bty = "n", cex = .85))
abline(h = 0, lty = 2)
dev.off()

plot_tape <- function(symbol, role, file) {
  p21 <- paths_021[paths_021$symbol == symbol, , drop = FALSE]
  p22 <- paths_022[paths_022$symbol == symbol, , drop = FALSE]
  s <- comparison[comparison$symbol == symbol, , drop = FALSE]
  png(file, 1800, 1200, res = 150)
  par(mfrow = c(3, 1), mar = c(2, 5, 3, 2), oma = c(3, 0, 3, 0))
  plot(p22$session_date, p22$close, type = "l", col = ink, xlab = "", ylab = "Adjusted close", main = paste(role, symbol, sep = " | "))
  lines(p22$session_date, p22$sma200, col = blue, lwd = 2)
  lines(p22$session_date, p22$sma50, col = orange, lwd = 2)
  mtext("Black: close   |   Blue: SMA200   |   Orange: SMA50", side = 3, line = 0.15, adj = 0, cex = .82)
  plot(p22$session_date, as.integer(p21$cross_triggered_long_state), type = "s", ylim = c(-.05, 1.05), col = gray, lwd = 2, xlab = "", ylab = "Long state", yaxt = "n")
  axis(2, at = c(0, 1), labels = c("Cash", "Long"), las = 1)
  lines(p22$session_date, as.integer(p22$asymmetric_long_state), type = "s", col = green, lwd = 2)
  rug(p22$session_date[p22$strict_reentry_lockout], col = orange)
  mtext("Gray: 02.1 state   |   Green: 02.2 state   |   Orange ticks: strict lockout", side = 3, line = 0.15, adj = 0, cex = .82)
  plot(p22$session_date, p21$strategy_wealth_open, type = "l", col = gray, lwd = 2, xlab = "Session", ylab = "Wealth from 1", main = sprintf("02.2 %.1f%% | 02.1 %.1f%% | delta %.1f pp | DD delta %.1f pp", 100 * s$primary_return_022, 100 * s$primary_return_021, 100 * s$return_delta_vs_021, 100 * s$drawdown_delta_vs_021))
  lines(p22$session_date, p22$strategy_wealth_open, col = green, lwd = 2)
  lines(p22$session_date, p22$buy_hold_wealth_open, col = ink, lwd = 1)
  legend("topleft", c("02.1", "02.2", "Buy-and-hold"), col = c(gray, green, ink), lty = 1, lwd = c(2, 2, 1), bty = "n", horiz = TRUE)
  mtext("Strict 02.2 requires a new qualified SMA200 cross after every SMA50 exit", outer = TRUE, side = 1, line = 1)
  dev.off()
}
for (i in seq_len(nrow(manifest))) {
  plot_tape(manifest$symbol[[i]], manifest$tape_role[[i]], file.path(output_dir, manifest$visual_file[[i]]))
}

integrity <- data.frame(
  check = c("registered_122", "eligible_identity_match", "no_confirmation_observations", "all_paths_start_cash",
            "all_022_entries_qualified", "lockout_never_invested", "buy_hold_paths_match", "primary_cost_not_above_gross"),
  passed = c(
    nrow(registry) == 122L,
    setequal(asset_021$symbol, asset_022$symbol),
    !any(paths_022$session_date >= contract_022$confirmation_start),
    all(vapply(split(paths_022, paths_022$symbol), function(z) !z$in_position_after_open[[1L]], logical(1))),
    !nrow(trades_022) || all(trades_022$entry_reason == "QUALIFIED_CROSS_ABOVE_SMA200"),
    !any(paths_022$strict_reentry_lockout & paths_022$in_position_after_open),
    isTRUE(all.equal(comparison$buy_hold_primary_return_022, comparison$buy_hold_primary_return_021)),
    !nrow(trades_022) || all(trades_022$net_trade_return <= trades_022$gross_trade_return)
  ), stringsAsFactors = FALSE
)
if (!all(integrity$passed)) stop("HYP-MOM-02.2 integrity checks failed.", call. = FALSE)

exit_summary <- if (nrow(exit_pairs)) data.frame(
  matched_entry_exits = nrow(exit_pairs),
  earlier_exit_count = sum(exit_pairs$exit_sessions_earlier > 0),
  same_session_exit_count = sum(exit_pairs$exit_sessions_earlier == 0),
  later_exit_count = sum(exit_pairs$exit_sessions_earlier < 0),
  median_sessions_earlier_when_earlier = stats::median(exit_pairs$exit_sessions_earlier[exit_pairs$exit_sessions_earlier > 0]),
  saved_downside_count_among_earlier = sum(exit_pairs$early_exit_consequence == "SAVED_DOWNSIDE"),
  foregone_upside_count_among_earlier = sum(exit_pairs$early_exit_consequence == "FOREGONE_UPSIDE"),
  median_return_after_genuinely_early_exit = stats::median(exit_pairs$return_after_early_022_exit_until_021_exit, na.rm = TRUE),
  stringsAsFactors = FALSE
) else data.frame()

run_spec <- data.frame(
  field = c("hypothesis_id", "stage", "as_of_timestamp", "discovery_window", "entry_rule", "exit_rule",
            "reentry_rule", "primary_cost_bps", "stress_cost_bps", "registered_assets", "eligible_assets",
            "primary_comparator", "confirmation_start", "authority"),
  value = c(contract_022$hypothesis_id, contract_022$evidence_stage, contract_022$as_of_timestamp,
            paste(contract_022$discovery_start, contract_022$discovery_end, sep = " to "),
            "fresh SMA200 cross and signal close above SMA50; next-open entry",
            "first completed close at/below SMA50 while long; next-open exit",
            contract_022$reentry_rule, contract_022$primary_cost_bps, contract_022$stress_cost_bps,
            nrow(registry), nrow(eligible), "HYP-MOM-02.1 CROSS_TRIGGERED_ONLY_NO_WARM_START",
            contract_022$confirmation_start, "NO_PROMOTION_NO_PORTFOLIO_NO_LIVE_AUTHORITY"),
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "run_spec.csv"))
write_csv(coverage, file.path(output_dir, "coverage.csv"))
write_csv(asset_021, file.path(output_dir, "asset_summary_021_cross_only.csv"))
write_csv(asset_022, file.path(output_dir, "asset_summary_022.csv"))
write_csv(comparison, file.path(output_dir, "asset_variant_comparison.csv"))
write_csv(panels, file.path(output_dir, "panel_summary.csv"))
write_csv(sector_summary, file.path(output_dir, "sector_summary.csv"))
write_csv(trades_021, file.path(output_dir, "trades_021_cross_only.csv"))
write_csv(trades_022, file.path(output_dir, "trades_022.csv"))
write_csv(paths_021, file.path(output_dir, "paths_021_cross_only.csv"))
write_csv(paths_022, file.path(output_dir, "paths_022.csv"))
write_csv(controls_022, file.path(output_dir, "random_controls_022.csv"))
write_csv(exit_pairs, file.path(output_dir, "matched_entry_exit_audit.csv"))
write_csv(exit_summary, file.path(output_dir, "matched_entry_exit_summary.csv"))
write_csv(manifest, file.path(output_dir, "representative_tape_manifest.csv"))
write_csv(integrity, file.path(output_dir, "integrity_checks.csv"))

combined <- panels[panels$panel == "COMBINED", ]
report <- c(
  "# HYP-MOM-02.2 Wide Discovery Report", "",
  "Status: `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`", "",
  sprintf("- Eligible assets: %d / %d", nrow(eligible), nrow(registry)),
  sprintf("- 02.2 round trips: %d", combined$trade_count_022),
  sprintf("- Median return: 02.2 %.2f%%; cross-only 02.1 %.2f%%; buy-and-hold %.2f%%", 100 * combined$median_return_022, 100 * combined$median_return_021, 100 * combined$median_buy_hold_return),
  sprintf("- Median return change versus 02.1: %.2f percentage points; assets improved: %d / %d", 100 * combined$median_return_delta_vs_021, combined$assets_beating_021, combined$asset_count),
  sprintf("- Median max-drawdown change versus 02.1: %.2f percentage points; assets improved: %d / %d", 100 * combined$median_drawdown_delta_vs_021, combined$assets_improving_drawdown_vs_021, combined$asset_count),
  sprintf("- Median exposure: 02.2 %.2f%%; 02.1 %.2f%%", 100 * combined$median_exposure_022, 100 * combined$median_exposure_021),
  sprintf("- Skipped SMA200 entries below SMA50: %d; median strict-lockout sessions per asset: %.1f", combined$total_skipped_entries, combined$median_lockout_sessions),
  if (nrow(exit_summary)) sprintf("- Matched entries: %d; 02.2 exited earlier %d, same session %d, later %d", exit_summary$matched_entry_exits, exit_summary$earlier_exit_count, exit_summary$same_session_exit_count, exit_summary$later_exit_count) else "- No matched exits.",
  if (nrow(exit_summary)) sprintf("- Among genuinely earlier exits: saved downside %d; foregone upside %d", exit_summary$saved_downside_count_among_earlier, exit_summary$foregone_upside_count_among_earlier) else "",
  "", "This is reused-window discovery evidence only. It does not authorize parameter tuning, portfolio construction, confirmation-data inspection, or live behavior."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)
message("HYP-MOM-02.2 complete: ", normalizePath(output_dir, winslash = "/", mustWork = TRUE))
