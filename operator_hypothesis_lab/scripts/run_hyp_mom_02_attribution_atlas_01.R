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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_sma_followup_engine.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (length(x) && !all(is.na(x))) stats::median(x, na.rm = TRUE) else NA_real_
mean_na <- function(x) if (length(x) && !all(is.na(x))) mean(x, na.rm = TRUE) else NA_real_

contract <- hmsf_validate_contract()
window <- hmsf_window("ATTRIBUTION", contract)
variants <- c("FRESH_021", "ENTRY_CONFIRMATION", "EXIT_LOCKOUT", "COMPOSITE_022", "REENTRY_REPAIR_023")
sector_etf <- c(
  "Information Technology" = "XLK", "Financials" = "XLF", "Health Care" = "XLV",
  "Energy" = "XLE", "Consumer Staples" = "XLP", "Consumer Discretionary" = "XLY",
  "Industrials" = "XLI", "Utilities" = "XLU", "Materials" = "XLB",
  "Real Estate" = "XLRE", "Communication Services" = "XLC"
)

original <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_01_1_discovery_registry.csv"))
wide <- utils::read.csv(file.path(repo_root, "literature_studies", "registries", "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"))
registry <- rbind(
  data.frame(instance_id = original$instance_id, symbol = original$symbol, cohort = "ORIGINAL_22",
             sector = original$sector, source_registry = original$source_registry),
  data.frame(instance_id = wide$instance_id, symbol = wide$symbol, cohort = wide$cohort,
             sector = wide$sector, source_registry = wide$source_id)
)
registry$sector_etf <- unname(sector_etf[registry$sector])
if (nrow(registry) != 122L || anyDuplicated(registry$symbol) || anyNA(registry$sector_etf)) stop("Frozen registry or sector map failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_MOM_ATTRIBUTION_RUN_ID", "hyp_mom_02_attribution_atlas_01_20260810")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = as.Date("2019-01-02"), end_date = window[[2L]],
  as_of_timestamp = contract$as_of_timestamp,
  symbols = unique(c(registry$symbol, "SPY", registry$sector_etf)),
  universe_name = "hyp_mom_02_attribution_atlas_01",
  universe_roles = "frozen_combined_122,spy_calendar,sector_context",
  refresh = env_bool("GEN5_HYP_MOM_ATTRIBUTION_REFRESH", FALSE), repo_root = repo_root
)
bars_all <- query$bars
bars_all$session_date <- as.Date(bars_all$session_date)
if (any(bars_all$session_date > window[[2L]]) || any(bars_all$session_date >= contract$sealed_start)) stop("Unauthorized dates entered attribution.", call. = FALSE)
if (anyDuplicated(bars_all[c("symbol", "session_date")])) stop("Duplicate queried bars.", call. = FALSE)

spy_dates <- sort(unique(bars_all$session_date[bars_all$symbol == "SPY" & bars_all$session_date >= window[[1L]] & bars_all$session_date <= window[[2L]]]))
if (!length(spy_dates)) stop("SPY attribution calendar unavailable.", call. = FALSE)

coverage_one <- function(symbol, role) {
  x <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  x <- x[order(x$session_date), , drop = FALSE]
  observed <- x$session_date[x$session_date >= window[[1L]] & x$session_date <= window[[2L]]]
  invalid <- if (!nrow(x)) 0L else sum(!is.finite(x$open) | !is.finite(x$high) | !is.finite(x$low) |
    !is.finite(x$close) | !is.finite(x$volume) | x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)
  missing <- length(setdiff(spy_dates, observed))
  prehistory <- sum(x$session_date < window[[1L]])
  status <- if (!nrow(x)) "NO_HISTORY" else if (invalid) "INVALID_OHLCV" else if (missing) "WINDOW_INCOMPLETE" else if (prehistory < contract$prehistory_sessions) "PREHISTORY_INCOMPLETE" else "ELIGIBLE"
  data.frame(symbol = symbol, role = role, observed_rows = nrow(x), missing_sessions = missing,
             prehistory_sessions = prehistory, invalid_rows = invalid, coverage_status = status,
             analysis_eligible = status == "ELIGIBLE")
}
asset_coverage <- do.call(rbind, lapply(registry$symbol, coverage_one, role = "ASSET"))
context_symbols <- unique(c("SPY", registry$sector_etf))
context_coverage <- do.call(rbind, lapply(context_symbols, coverage_one, role = "CONTEXT"))
if (!all(context_coverage$analysis_eligible)) {
  stop(paste("Context coverage incomplete; rerun with GEN5_HYP_MOM_ATTRIBUTION_REFRESH=true:",
             paste(context_coverage$symbol[!context_coverage$analysis_eligible], collapse = ", ")), call. = FALSE)
}
eligible_registry <- registry[registry$symbol %in% asset_coverage$symbol[asset_coverage$analysis_eligible], , drop = FALSE]
if (!nrow(eligible_registry)) stop("No eligible registered assets.", call. = FALSE)

add_identity <- function(x, reg) {
  if (!nrow(x)) return(cbind(reg[FALSE, c("instance_id", "symbol", "cohort", "sector", "sector_etf")], x[, setdiff(names(x), "symbol"), drop = FALSE]))
  identity <- reg[rep(1L, nrow(x)), c("instance_id", "symbol", "cohort", "sector", "sector_etf"), drop = FALSE]
  cbind(identity, x[, setdiff(names(x), "symbol"), drop = FALSE])
}

summaries <- trades <- paths <- controls <- events <- list()
message("Attribution Atlas 01 starting: ", nrow(eligible_registry), " eligible assets x ", length(variants), " policies.")
for (i in seq_len(nrow(eligible_registry))) {
  reg <- eligible_registry[i, , drop = FALSE]
  message(sprintf("[%03d/%03d] %s", i, nrow(eligible_registry), reg$symbol))
  asset_bars <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]
  for (variant in variants) {
    analysis <- hmsf_analyze_asset(asset_bars, variant, window[[1L]], window[[2L]], seed_offset = i * 100L + match(variant, variants), contract = contract)
    key <- paste(reg$symbol, variant, sep = "|")
    summaries[[key]] <- add_identity(analysis$summary, reg)
    trades[[key]] <- add_identity(analysis$trades, reg)
    paths[[key]] <- add_identity(analysis$path, reg)
    controls[[key]] <- add_identity(analysis$random, reg)
  }
  events[[reg$symbol]] <- add_identity(hmsf_event_study(
    asset_bars,
    bars_all[bars_all$symbol == "SPY", , drop = FALSE],
    bars_all[bars_all$symbol == reg$sector_etf, , drop = FALSE],
    window[[1L]], window[[2L]], reg$sector_etf, contract
  ), reg)
}

asset_summary <- do.call(rbind, summaries)
trades <- do.call(rbind, trades)
paths <- do.call(rbind, paths)
controls <- do.call(rbind, controls)
event_study <- do.call(rbind, events)

panel_summary <- do.call(rbind, lapply(variants, function(variant) {
  x <- asset_summary[asset_summary$variant == variant, , drop = FALSE]
  data.frame(
    variant = variant, assets = nrow(x), trades = sum(x$trade_count),
    median_primary_return = median_na(x$primary_return), median_stress_return = median_na(x$stress_return),
    positive_assets = sum(x$primary_return > 0), positive_fraction = mean(x$primary_return > 0),
    median_exposure = median_na(x$exposure_fraction), median_sharpe = median_na(x$primary_sharpe),
    median_maximum_drawdown = median_na(x$maximum_drawdown), median_trade_count = median_na(x$trade_count),
    median_trade_return = median_na(x$median_primary_trade_return), mean_trade_return = mean_na(x$mean_primary_trade_return),
    median_hit_rate = median_na(x$primary_hit_rate), median_payoff_ratio = median_na(x$payoff_ratio),
    median_excess_vs_random = median_na(x$excess_vs_random_median),
    median_random_percentile = median_na(x$observed_random_percentile),
    beat_buy_hold = sum(x$excess_vs_buy_hold > 0), drawdown_better_than_buy_hold = sum(x$drawdown_improvement > 0),
    stringsAsFactors = FALSE
  )
}))

comparisons_spec <- data.frame(
  comparison = c("ENTRY_CONFIRMATION_EFFECT_SLOW_EXIT", "EXIT_LOCKOUT_EFFECT_UNFILTERED_ENTRY",
                 "ENTRY_CONFIRMATION_EFFECT_FAST_EXIT", "FAST_EXIT_LOCKOUT_EFFECT_CONFIRMED_ENTRY",
                 "REENTRY_REPAIR_EFFECT"),
  challenger = c("ENTRY_CONFIRMATION", "EXIT_LOCKOUT", "COMPOSITE_022", "COMPOSITE_022", "REENTRY_REPAIR_023"),
  parent = c("FRESH_021", "FRESH_021", "EXIT_LOCKOUT", "ENTRY_CONFIRMATION", "COMPOSITE_022")
)
pairwise <- do.call(rbind, lapply(seq_len(nrow(comparisons_spec)), function(i) {
  spec <- comparisons_spec[i, ]
  challenger <- asset_summary[asset_summary$variant == spec$challenger, ]
  parent <- asset_summary[asset_summary$variant == spec$parent, ]
  x <- merge(challenger, parent, by = c("instance_id", "symbol", "cohort", "sector", "sector_etf"), suffixes = c("_challenger", "_parent"))
  data.frame(
    comparison = spec$comparison, challenger = spec$challenger, parent = spec$parent,
    assets = nrow(x), median_return_delta = median_na(x$primary_return_challenger - x$primary_return_parent),
    return_improved_assets = sum(x$primary_return_challenger > x$primary_return_parent),
    median_stress_delta = median_na(x$stress_return_challenger - x$stress_return_parent),
    median_drawdown_delta = median_na(x$maximum_drawdown_challenger - x$maximum_drawdown_parent),
    drawdown_improved_assets = sum(x$maximum_drawdown_challenger > x$maximum_drawdown_parent),
    median_exposure_delta = median_na(x$exposure_fraction_challenger - x$exposure_fraction_parent),
    median_trade_count_delta = median_na(x$trade_count_challenger - x$trade_count_parent),
    median_random_excess_delta = median_na(x$excess_vs_random_median_challenger - x$excess_vs_random_median_parent),
    median_random_percentile_delta = median_na(x$observed_random_percentile_challenger - x$observed_random_percentile_parent),
    stringsAsFactors = FALSE
  )
}))

event_summary <- do.call(rbind, lapply(sort(unique(event_study$horizon)), function(horizon) {
  do.call(rbind, lapply(c(FALSE, TRUE), function(nonoverlap_only) {
    x <- event_study[event_study$horizon == horizon & (!nonoverlap_only | event_study$nonoverlap), , drop = FALSE]
    data.frame(
      horizon = horizon, sample = if (nonoverlap_only) "NONOVERLAP" else "ALL_EVENTS", events = nrow(x), assets = length(unique(x$symbol)),
      mean_return = mean_na(x$asset_return), median_return = median_na(x$asset_return), hit_rate = mean_na(x$direction_positive),
      mean_spy_relative = mean_na(x$spy_relative_return), median_spy_relative = median_na(x$spy_relative_return),
      mean_sector_relative = mean_na(x$sector_relative_return), median_sector_relative = median_na(x$sector_relative_return),
      mean_mfe = mean_na(x$maximum_favorable_excursion), mean_mae = mean_na(x$maximum_adverse_excursion), stringsAsFactors = FALSE
    )
  }))
}))

event_condition_summary <- do.call(rbind, lapply(sort(unique(event_study$horizon)), function(horizon) {
  x <- event_study[event_study$horizon == horizon, , drop = FALSE]
  conditions <- list(ALL = rep(TRUE, nrow(x)), ABOVE_SMA50 = x$above50_at_signal,
                     RISING_SMA200 = x$sma200_rising20_at_signal,
                     ABOVE50_AND_RISING200 = x$above50_at_signal & x$sma200_rising20_at_signal)
  do.call(rbind, lapply(names(conditions), function(label) {
    z <- x[conditions[[label]], , drop = FALSE]
    data.frame(horizon = horizon, condition = label, events = nrow(z), assets = length(unique(z$symbol)),
               mean_return = mean_na(z$asset_return), median_return = median_na(z$asset_return), hit_rate = mean_na(z$direction_positive),
               mean_spy_relative = mean_na(z$spy_relative_return), mean_sector_relative = mean_na(z$sector_relative_return),
               mean_mfe = mean_na(z$maximum_favorable_excursion), mean_mae = mean_na(z$maximum_adverse_excursion))
  }))
}))

reentry <- merge(
  asset_summary[asset_summary$variant == "REENTRY_REPAIR_023", ],
  asset_summary[asset_summary$variant == "COMPOSITE_022", ],
  by = c("instance_id", "symbol", "cohort", "sector", "sector_etf"), suffixes = c("_023", "_022")
)
reentry$return_delta <- reentry$primary_return_023 - reentry$primary_return_022
reentry$drawdown_delta <- reentry$maximum_drawdown_023 - reentry$maximum_drawdown_022
reentry$exposure_delta <- reentry$exposure_fraction_023 - reentry$exposure_fraction_022

nearest_symbol <- function(values, target, symbols) symbols[order(abs(values - target), symbols)][[1L]]
tape_manifest <- data.frame(
  tape_role = c("MEDIAN_REENTRY_CHANGE", "LARGEST_REENTRY_IMPROVEMENT", "LARGEST_REENTRY_DETERIORATION",
                "LARGEST_DRAWDOWN_IMPROVEMENT", "LARGEST_EXPOSURE_INCREASE", "MOST_023_TRADES"),
  symbol = c(
    nearest_symbol(reentry$return_delta, stats::median(reentry$return_delta), reentry$symbol),
    reentry$symbol[order(-reentry$return_delta, reentry$symbol)][[1L]],
    reentry$symbol[order(reentry$return_delta, reentry$symbol)][[1L]],
    reentry$symbol[order(-reentry$drawdown_delta, reentry$symbol)][[1L]],
    reentry$symbol[order(-reentry$exposure_delta, reentry$symbol)][[1L]],
    reentry$symbol[order(-reentry$trade_count_023, reentry$symbol)][[1L]]
  ), stringsAsFactors = FALSE
)
tape_manifest <- merge(tape_manifest, reentry, by = "symbol", all.x = TRUE, sort = FALSE)
tape_manifest <- tape_manifest[match(c("MEDIAN_REENTRY_CHANGE", "LARGEST_REENTRY_IMPROVEMENT", "LARGEST_REENTRY_DETERIORATION",
                                       "LARGEST_DRAWDOWN_IMPROVEMENT", "LARGEST_EXPOSURE_INCREASE", "MOST_023_TRADES"), tape_manifest$tape_role), ]
tape_manifest$visual_file <- file.path("visuals", paste0("attribution_tape_", seq_len(nrow(tape_manifest)), "_", tolower(tape_manifest$symbol), ".png"))

ink <- "#202630"; blue <- "#2C6CB0"; green <- "#2E8B57"; red <- "#C83E3A"; gray <- "#A7B0BE"; purple <- "#7654C4"; orange <- "#D98524"
variant_colors <- c(FRESH_021 = gray, ENTRY_CONFIRMATION = blue, EXIT_LOCKOUT = orange,
                    COMPOSITE_022 = purple, REENTRY_REPAIR_023 = green)

png(file.path(visual_dir, "coverage_and_policy_map.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(5, 15, 4, 2))
barplot(sort(table(asset_coverage$coverage_status)), horiz = TRUE, las = 1,
        col = ifelse(names(sort(table(asset_coverage$coverage_status))) == "ELIGIBLE", green, red),
        main = "Frozen 122-name attribution coverage", xlab = "Assets")
mechanic <- c("Fresh 200", "+50 entry", "50 exit + lockout", "Composite", "50 reclaim re-entry")
plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 6)); title("One change at a time")
for (i in seq_along(mechanic)) text(.05, 6 - i, paste(i, mechanic[[i]]), adj = 0, cex = 1.25, col = unname(variant_colors[[i]]))
dev.off()

png(file.path(visual_dir, "variant_return_protection_tradeoff.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
barplot(100 * panel_summary$median_primary_return, names.arg = panel_summary$variant, las = 2,
        col = variant_colors[panel_summary$variant], ylab = "Median compounded return (%)", main = "Return by policy")
abline(h = 0, lty = 2)
plot(100 * panel_summary$median_exposure, 100 * panel_summary$median_maximum_drawdown,
     pch = 19, cex = 2, col = variant_colors[panel_summary$variant], xlab = "Median exposure (%)",
     ylab = "Median maximum drawdown (%)", main = "Exposure and protection")
text(100 * panel_summary$median_exposure, 100 * panel_summary$median_maximum_drawdown,
     labels = panel_summary$variant, pos = 3, cex = .8)
dev.off()

png(file.path(visual_dir, "mechanical_attribution_deltas.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(10, 5, 4, 2))
barplot(100 * pairwise$median_return_delta, names.arg = pairwise$comparison, las = 2,
        col = ifelse(pairwise$median_return_delta > 0, green, red), ylab = "Median asset return delta (pp)", main = "What changed returns?")
abline(h = 0, lty = 2)
barplot(100 * pairwise$median_drawdown_delta, names.arg = pairwise$comparison, las = 2,
        col = ifelse(pairwise$median_drawdown_delta > 0, green, red), ylab = "Median max-DD change (pp)", main = "What changed drawdown?")
abline(h = 0, lty = 2)
dev.off()

png(file.path(visual_dir, "event_horizon_surface.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
all_events <- event_summary[event_summary$sample == "ALL_EVENTS", ]
matplot(all_events$horizon, 100 * cbind(all_events$mean_return, all_events$mean_spy_relative, all_events$mean_sector_relative),
        type = "b", pch = 19, lty = 1, col = c(ink, blue, orange), xlab = "Forward sessions", ylab = "Mean return (%)",
        main = "Fresh SMA200 cross forward returns")
abline(h = 0, lty = 2); legend("topleft", c("Absolute", "vs SPY", "vs sector"), col = c(ink, blue, orange), lty = 1, pch = 19, bty = "n")
non <- event_summary[event_summary$sample == "NONOVERLAP", ]
matplot(non$horizon, 100 * cbind(non$mean_return, non$mean_spy_relative, non$mean_sector_relative),
        type = "b", pch = 19, lty = 1, col = c(ink, blue, orange), xlab = "Forward sessions", ylab = "Mean return (%)",
        main = "Non-overlapping sensitivity")
abline(h = 0, lty = 2); legend("topleft", c("Absolute", "vs SPY", "vs sector"), col = c(ink, blue, orange), lty = 1, pch = 19, bty = "n")
dev.off()

png(file.path(visual_dir, "event_condition_surface.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 2))
twenty <- event_condition_summary[event_condition_summary$horizon == 20L, ]
barplot(100 * rbind(twenty$mean_return, twenty$mean_spy_relative, twenty$mean_sector_relative), beside = TRUE,
        names.arg = twenty$condition, las = 2, col = c(ink, blue, orange), ylab = "Mean 20-session return (%)",
        main = "Cross context and forward return", legend.text = c("Absolute", "vs SPY", "vs sector"), args.legend = list(bty = "n", cex = .8))
abline(h = 0, lty = 2)
plot(event_study$distance200_atr[event_study$horizon == 20L], 100 * event_study$sector_relative_return[event_study$horizon == 20L],
     pch = 19, col = rgb(44/255, 108/255, 176/255, .35), xlab = "Distance above SMA200 / ATR20",
     ylab = "20-session sector-relative return (%)", main = "Cross strength is continuous")
abline(h = 0, lty = 2)
dev.off()

plot_tape <- function(symbol, role, file) {
  z <- paths[paths$symbol == symbol, , drop = FALSE]
  by_variant <- split(z, z$variant)
  price <- by_variant[["FRESH_021"]]
  png(file, 1800, 1200, res = 150)
  par(mfrow = c(3, 1), mar = c(2, 5, 3, 2), oma = c(3, 0, 3, 0))
  plot(price$session_date, price$close, type = "l", col = ink, xlab = "", ylab = "Adjusted close", main = paste(role, symbol, sep = " | "))
  lines(price$session_date, price$sma200, col = blue, lwd = 2); lines(price$session_date, price$sma50, col = orange, lwd = 2)
  mtext("Black: close | Blue: SMA200 | Orange: SMA50", side = 3, line = .15, adj = 0, cex = .82)
  plot(price$session_date, rep(NA_real_, nrow(price)), ylim = c(.5, 5.5), type = "n", xlab = "", ylab = "Policy state", yaxt = "n")
  axis(2, at = 1:5, labels = variants, las = 1, cex.axis = .7)
  for (j in seq_along(variants)) {
    p <- by_variant[[variants[[j]]]]
    lines(p$session_date, j + .35 * (as.integer(p$in_position_after_open) - .5), type = "s", col = variant_colors[[variants[[j]]]], lwd = 2)
  }
  plot(price$session_date, price$buy_hold_wealth_open, type = "l", col = ink, lwd = 1, xlab = "Session", ylab = "Wealth from 1", main = "Five causal policies on the same path")
  for (variant in variants) {
    p <- by_variant[[variant]]
    lines(p$session_date, p$strategy_wealth_open, col = variant_colors[[variant]], lwd = 2)
  }
  legend("topleft", c(variants, "Buy-and-hold"), col = c(variant_colors[variants], ink), lty = 1, lwd = c(rep(2, 5), 1), bty = "n", horiz = TRUE, cex = .72)
  mtext("Attribution view only: no policy is selected from this reused window", outer = TRUE, side = 1, line = 1)
  dev.off()
}
for (i in seq_len(nrow(tape_manifest))) plot_tape(tape_manifest$symbol[[i]], tape_manifest$tape_role[[i]], file.path(output_dir, tape_manifest$visual_file[[i]]))

integrity <- data.frame(
  check = c("registered_122", "no_unauthorized_dates", "context_complete", "all_paths_start_cash",
            "all_entries_next_open", "costs_nonbeneficial", "variant_asset_sets_match", "event_entries_after_signal"),
  passed = c(
    nrow(registry) == 122L,
    !any(paths$session_date > window[[2L]]) && !any(paths$session_date >= contract$sealed_start),
    all(context_coverage$analysis_eligible),
    all(vapply(split(paths, interaction(paths$symbol, paths$variant)), function(z) !z$in_position_after_open[[1L]], logical(1))),
    !nrow(trades) || all(trades$entry_date > as.Date(paths$signal_date[match(trades$trade_id, paths$trade_id)]), na.rm = TRUE),
    !nrow(trades) || all(trades$primary_trade_return <= trades$gross_trade_return),
    length(unique(table(asset_summary$variant))) == 1L,
    !nrow(event_study) || all(event_study$entry_date > event_study$signal_date)
  ), stringsAsFactors = FALSE
)
if (!all(integrity$passed)) stop(paste("Attribution integrity failed:", paste(integrity$check[!integrity$passed], collapse = ", ")), call. = FALSE)

run_spec <- data.frame(
  field = c("program_id", "lane", "stage", "as_of_timestamp", "window", "registered_assets", "eligible_assets",
            "variants", "event_horizons", "primary_cost_bps", "stress_cost_bps", "sealed_boundary"),
  value = c(contract$program_id, "HYP-MOM-02 / ATTRIBUTION_ATLAS_01", "DISCOVERY_REUSED_WINDOW_NO_PROMOTION",
            contract$as_of_timestamp, paste(window, collapse = " to "), nrow(registry), nrow(eligible_registry),
            paste(variants, collapse = ","), paste(contract$event_horizons, collapse = ","),
            contract$primary_cost_bps, contract$stress_cost_bps, as.character(contract$sealed_start))
)

write_csv(run_spec, file.path(output_dir, "run_spec.csv"))
write_csv(registry, file.path(output_dir, "frozen_registry.csv"))
write_csv(asset_coverage, file.path(output_dir, "asset_coverage.csv"))
write_csv(context_coverage, file.path(output_dir, "context_coverage.csv"))
write_csv(asset_summary, file.path(output_dir, "asset_variant_summary.csv"))
write_csv(panel_summary, file.path(output_dir, "variant_panel_summary.csv"))
write_csv(pairwise, file.path(output_dir, "mechanical_attribution_summary.csv"))
write_csv(trades, file.path(output_dir, "trades.csv"))
saveRDS(paths, file.path(output_dir, "paths.rds"), compress = "xz")
saveRDS(controls, file.path(output_dir, "random_controls.rds"), compress = "xz")
write_csv(event_study, file.path(output_dir, "event_study.csv"))
write_csv(event_summary, file.path(output_dir, "event_summary.csv"))
write_csv(event_condition_summary, file.path(output_dir, "event_condition_summary.csv"))
write_csv(tape_manifest, file.path(output_dir, "representative_tape_manifest.csv"))
write_csv(integrity, file.path(output_dir, "integrity_checks.csv"))

report <- c(
  "# HYP-MOM-02 Attribution Atlas 01", "",
  paste0("- Eligible assets: ", nrow(eligible_registry), " / 122"),
  paste0("- Policies: ", paste(variants, collapse = ", ")), "",
  "## Policy medians", paste(capture.output(print(panel_summary, row.names = FALSE)), collapse = "\n"), "",
  "## Mechanical attribution", paste(capture.output(print(pairwise, row.names = FALSE)), collapse = "\n"), "",
  "## Fixed-horizon cross events", paste(capture.output(print(event_summary, row.names = FALSE)), collapse = "\n"), "",
  "This packet reuses inspected 2021-2023 evidence. It can explain mechanics but cannot nominate a strategy."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)
message("Attribution Atlas 01 complete: ", normalizePath(output_dir, winslash = "/", mustWork = TRUE))
