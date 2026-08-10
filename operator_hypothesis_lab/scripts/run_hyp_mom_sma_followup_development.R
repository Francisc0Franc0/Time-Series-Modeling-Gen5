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
window <- hmsf_window("DEVELOPMENT", contract)
variants <- c("COMPOSITE_022", "REENTRY_REPAIR_023", "FRESH_021", "PULLBACK_RECLAIM_031")
candidates <- data.frame(candidate = c("REENTRY_REPAIR_023", "PULLBACK_RECLAIM_031"),
                         parent = c("COMPOSITE_022", "FRESH_021"), stringsAsFactors = FALSE)

original <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_01_1_discovery_registry.csv"))
wide <- utils::read.csv(file.path(repo_root, "literature_studies", "registries", "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"))
registry <- rbind(
  data.frame(instance_id = original$instance_id, symbol = original$symbol, cohort = "ORIGINAL_22",
             sector = original$sector, source_registry = original$source_registry),
  data.frame(instance_id = wide$instance_id, symbol = wide$symbol, cohort = wide$cohort,
             sector = wide$sector, source_registry = wide$source_id)
)
if (nrow(registry) != 122L || anyDuplicated(registry$symbol)) stop("Frozen registry failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_MOM_DEVELOPMENT_RUN_ID", "hyp_mom_sma_followup_development_2016_2020_20260810")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = as.Date("2014-01-02"), end_date = window[[2L]],
  as_of_timestamp = contract$as_of_timestamp, symbols = unique(c(registry$symbol, "SPY")),
  universe_name = "hyp_mom_sma_followup_development_2016_2020",
  universe_roles = "frozen_combined_122,spy_calendar",
  refresh = env_bool("GEN5_HYP_MOM_DEVELOPMENT_REFRESH", FALSE), repo_root = repo_root
)
bars_all <- query$bars
bars_all$session_date <- as.Date(bars_all$session_date)
if (any(bars_all$session_date > window[[2L]]) || any(bars_all$session_date >= contract$confirmation_start)) stop("Later-stage bars entered development.", call. = FALSE)
if (anyDuplicated(bars_all[c("symbol", "session_date")])) stop("Duplicate queried bars.", call. = FALSE)
spy_dates <- sort(unique(bars_all$session_date[bars_all$symbol == "SPY" & bars_all$session_date >= window[[1L]] & bars_all$session_date <= window[[2L]]]))
if (!length(spy_dates)) stop("SPY development calendar unavailable.", call. = FALSE)

coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]
  x <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]
  observed <- x$session_date[x$session_date >= window[[1L]] & x$session_date <= window[[2L]]]
  invalid <- if (!nrow(x)) 0L else sum(!is.finite(x$open) | !is.finite(x$high) | !is.finite(x$low) |
    !is.finite(x$close) | !is.finite(x$volume) | x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)
  missing <- length(setdiff(spy_dates, observed)); prehistory <- sum(x$session_date < window[[1L]])
  in_window <- x[x$session_date >= window[[1L]] & x$session_date <= window[[2L]], , drop = FALSE]
  enough_warmup <- nrow(in_window) >= contract$prehistory_sessions + 2L
  analysis_start_date <- if (enough_warmup) in_window$session_date[[contract$prehistory_sessions + 1L]] else as.Date(NA)
  status <- if (!nrow(x)) "NO_HISTORY" else if (invalid) "INVALID_OHLCV" else if (missing) "WINDOW_INCOMPLETE" else if (!enough_warmup) "WARMUP_INCOMPLETE" else "ELIGIBLE_WITH_IN_WINDOW_WARMUP"
  cbind(reg, data.frame(observed_rows = nrow(x), missing_sessions = missing, prehistory_sessions = prehistory,
                        analysis_start_date = analysis_start_date, invalid_rows = invalid, coverage_status = status,
                        analysis_eligible = status == "ELIGIBLE_WITH_IN_WINDOW_WARMUP"))
}))
write_csv(coverage, file.path(output_dir, "coverage_preflight.csv"))
if (!is.null(query$health)) write_csv(query$health, file.path(output_dir, "query_health_preflight.csv"))
message("Development coverage preflight: ", paste(names(table(coverage$coverage_status)), as.integer(table(coverage$coverage_status)), collapse = "; "))
eligible <- registry[registry$symbol %in% coverage$symbol[coverage$analysis_eligible], , drop = FALSE]
if (!nrow(eligible)) stop("No eligible development assets.", call. = FALSE)

add_identity <- function(x, reg) {
  if (!nrow(x)) return(cbind(reg[FALSE, c("instance_id", "symbol", "cohort", "sector")], x[, setdiff(names(x), "symbol"), drop = FALSE]))
  cbind(reg[rep(1L, nrow(x)), c("instance_id", "symbol", "cohort", "sector"), drop = FALSE],
        x[, setdiff(names(x), "symbol"), drop = FALSE])
}

summaries <- trades <- paths <- controls <- list()
message("SMA follow-up development starting: ", nrow(eligible), " eligible assets x ", length(variants), " policies.")
for (i in seq_len(nrow(eligible))) {
  reg <- eligible[i, , drop = FALSE]
  message(sprintf("[%03d/%03d] %s", i, nrow(eligible), reg$symbol))
  bars <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]
  asset_start <- as.Date(coverage$analysis_start_date[match(reg$symbol, coverage$symbol)])
  for (variant in variants) {
    analysis <- hmsf_analyze_asset(bars, variant, asset_start, window[[2L]], seed_offset = i * 100L + match(variant, variants), contract = contract)
    key <- paste(reg$symbol, variant, sep = "|")
    summaries[[key]] <- add_identity(analysis$summary, reg)
    trades[[key]] <- add_identity(analysis$trades, reg)
    paths[[key]] <- add_identity(analysis$path, reg)
    controls[[key]] <- add_identity(analysis$random, reg)
  }
}
asset_summary <- do.call(rbind, summaries)
trades <- do.call(rbind, trades)
paths <- do.call(rbind, paths)
controls <- do.call(rbind, controls)

panel_summary <- do.call(rbind, lapply(variants, function(variant) {
  x <- asset_summary[asset_summary$variant == variant, , drop = FALSE]
  data.frame(variant = variant, assets = nrow(x), trades = sum(x$trade_count),
             median_primary_return = median_na(x$primary_return), median_stress_return = median_na(x$stress_return),
             positive_assets = sum(x$primary_return > 0), positive_fraction = mean(x$primary_return > 0),
             median_exposure = median_na(x$exposure_fraction), median_sharpe = median_na(x$primary_sharpe),
             median_maximum_drawdown = median_na(x$maximum_drawdown), median_trade_count = median_na(x$trade_count),
             median_excess_vs_random = median_na(x$excess_vs_random_median),
             median_random_percentile = median_na(x$observed_random_percentile),
             beat_buy_hold = sum(x$excess_vs_buy_hold > 0), drawdown_better_than_buy_hold = sum(x$drawdown_improvement > 0))
}))

annual_asset <- do.call(rbind, lapply(split(paths, interaction(paths$symbol, paths$variant)), function(z) {
  z <- z[order(z$session_date), ]
  z$interval_return <- c(0, z$strategy_wealth_open[-1L] / head(z$strategy_wealth_open, -1L) - 1)
  do.call(rbind, lapply(sort(unique(format(z$session_date, "%Y"))), function(year) {
    y <- z[format(z$session_date, "%Y") == year, ]
    data.frame(symbol = z$symbol[[1L]], variant = z$variant[[1L]], year = as.integer(year),
               annual_return = prod(1 + y$interval_return) - 1)
  }))
}))
annual_summary <- do.call(rbind, lapply(split(annual_asset, interaction(annual_asset$variant, annual_asset$year)), function(z) {
  data.frame(variant = z$variant[[1L]], year = z$year[[1L]], assets = nrow(z),
             equal_asset_mean_return = mean(z$annual_return), equal_asset_median_return = stats::median(z$annual_return),
             positive_assets = sum(z$annual_return > 0), positive_fraction = mean(z$annual_return > 0))
}))
annual_summary <- annual_summary[order(annual_summary$variant, annual_summary$year), ]

candidate_detail <- list(); gate_rows <- list()
for (i in seq_len(nrow(candidates))) {
  candidate <- candidates$candidate[[i]]; parent <- candidates$parent[[i]]
  csum <- asset_summary[asset_summary$variant == candidate, ]; psum <- asset_summary[asset_summary$variant == parent, ]
  paired <- merge(csum, psum, by = c("instance_id", "symbol", "cohort", "sector"), suffixes = c("_candidate", "_parent"))
  paired$return_delta <- paired$primary_return_candidate - paired$primary_return_parent
  paired$drawdown_delta <- paired$maximum_drawdown_candidate - paired$maximum_drawdown_parent
  candidate_detail[[candidate]] <- paired
  positive_contribution <- aggregate(pmax(paired$primary_return_candidate, 0), list(sector = paired$sector), sum)
  names(positive_contribution)[[2L]] <- "positive_contribution"
  sector_max_share <- if (sum(positive_contribution$positive_contribution) > 0) max(positive_contribution$positive_contribution) / sum(positive_contribution$positive_contribution) else 1
  candidate_panel <- panel_summary[panel_summary$variant == candidate, ]
  positive_years <- sum(annual_summary$variant == candidate & annual_summary$equal_asset_mean_return > 0)
  gates <- data.frame(
    candidate = candidate,
    gate = c("INTEGRITY", "PRIMARY_AND_STRESS_POSITIVE", "MATCHED_CONTROL_EXCESS_POSITIVE", "CONTROL_PERCENTILE_60",
             "POSITIVE_ASSET_BREADTH_55", "PARENT_IMPROVEMENT_BREADTH_55", "THREE_POSITIVE_YEARS",
             "TRADE_SUPPORT_AND_SECTOR_BREADTH", "DRAWDOWN_NOT_WORSE_2PP"),
    passed = c(
      TRUE,
      candidate_panel$median_primary_return > 0 && candidate_panel$median_stress_return > 0,
      candidate_panel$median_excess_vs_random > 0,
      candidate_panel$median_random_percentile >= .60,
      candidate_panel$positive_fraction >= .55,
      mean(paired$return_delta > 0) >= .55,
      positive_years >= 3L,
      candidate_panel$median_trade_count >= 3 && sector_max_share <= .35,
      median_na(paired$drawdown_delta) >= -.02
    ),
    observed = c(
      "all causal and date checks evaluated after run",
      sprintf("primary=%.4f stress=%.4f", candidate_panel$median_primary_return, candidate_panel$median_stress_return),
      sprintf("median excess=%.4f", candidate_panel$median_excess_vs_random),
      sprintf("median percentile=%.3f", candidate_panel$median_random_percentile),
      sprintf("positive fraction=%.3f", candidate_panel$positive_fraction),
      sprintf("improved fraction=%.3f", mean(paired$return_delta > 0)),
      sprintf("positive years=%d", positive_years),
      sprintf("median trades=%.1f sector max share=%.3f", candidate_panel$median_trade_count, sector_max_share),
      sprintf("median DD delta=%.4f", median_na(paired$drawdown_delta))
    ), stringsAsFactors = FALSE
  )
  gate_rows[[candidate]] <- gates
}
candidate_comparison <- do.call(rbind, lapply(names(candidate_detail), function(candidate) {
  x <- candidate_detail[[candidate]]
  data.frame(candidate = candidate, parent = candidates$parent[candidates$candidate == candidate], assets = nrow(x),
             median_return_delta = median_na(x$return_delta), improved_assets = sum(x$return_delta > 0),
             improved_fraction = mean(x$return_delta > 0), median_drawdown_delta = median_na(x$drawdown_delta),
             drawdown_improved_assets = sum(x$drawdown_delta > 0), median_exposure_delta = median_na(x$exposure_fraction_candidate - x$exposure_fraction_parent),
             median_trade_delta = median_na(x$trade_count_candidate - x$trade_count_parent))
}))
development_gates <- do.call(rbind, gate_rows)
gate_pass <- aggregate(passed ~ candidate, development_gates, all)
passing <- gate_pass$candidate[gate_pass$passed]
nomination <- data.frame(status = "NO_DEVELOPMENT_NOMINEE", nominee = "", reason = "No candidate cleared every frozen gate.", stringsAsFactors = FALSE)
if (length(passing)) {
  rank_table <- panel_summary[match(passing, panel_summary$variant), ]
  ordered <- order(-rank_table$median_excess_vs_random, -rank_table$positive_fraction, -rank_table$median_maximum_drawdown, rank_table$variant)
  nominee <- rank_table$variant[ordered][[1L]]
  nomination <- data.frame(status = "DEVELOPMENT_NOMINEE_FOR_CONTEXT_ATLAS", nominee = nominee,
                           reason = "Cleared all frozen gates; ranked by matched-control excess, breadth, then drawdown.")
}

relevant <- do.call(rbind, candidate_detail)
nearest_symbol <- function(values, target, symbols) symbols[order(abs(values - target), symbols)][[1L]]
tape_manifest <- do.call(rbind, lapply(names(candidate_detail), function(candidate) {
  x <- candidate_detail[[candidate]]
  roles <- c("MEDIAN_RETURN_CHANGE", "LARGEST_IMPROVEMENT", "LARGEST_DETERIORATION")
  symbols <- c(nearest_symbol(x$return_delta, stats::median(x$return_delta), x$symbol),
               x$symbol[order(-x$return_delta, x$symbol)][[1L]], x$symbol[order(x$return_delta, x$symbol)][[1L]])
  data.frame(candidate = candidate, parent = candidates$parent[candidates$candidate == candidate], tape_role = roles, symbol = symbols)
}))
tape_manifest <- merge(tape_manifest, relevant[, c("symbol", "variant_candidate", "return_delta", "drawdown_delta")],
                       by.x = c("symbol", "candidate"), by.y = c("symbol", "variant_candidate"), all.x = TRUE, sort = FALSE)
tape_manifest$visual_file <- file.path("visuals", paste0("development_tape_", seq_len(nrow(tape_manifest)), "_", tolower(tape_manifest$symbol), ".png"))

ink <- "#202630"; blue <- "#2C6CB0"; green <- "#2E8B57"; red <- "#C83E3A"; gray <- "#A7B0BE"; purple <- "#7654C4"; orange <- "#D98524"
colors <- c(COMPOSITE_022 = purple, REENTRY_REPAIR_023 = green, FRESH_021 = gray, PULLBACK_RECLAIM_031 = blue)

png(file.path(visual_dir, "development_coverage.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(5, 16, 4, 2))
coverage_plot <- sort(table(ifelse(coverage$analysis_eligible, "Eligible (220-session warm-up)", "Window incomplete")))
barplot(coverage_plot, horiz = TRUE, las = 1, col = ifelse(names(coverage_plot) == "Eligible (220-session warm-up)", green, red),
        main = "Coverage status", xlab = "Assets")
barplot(sort(table(eligible$sector)), horiz = TRUE, las = 1, col = blue, main = "Eligible assets by sector", xlab = "Assets")
dev.off()

png(file.path(visual_dir, "development_candidate_tradeoff.png"), 1800, 900, res = 150)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 2))
barplot(100 * panel_summary$median_primary_return, names.arg = panel_summary$variant, las = 2, col = colors[panel_summary$variant],
        ylab = "Median compounded return (%)", main = "Development return")
abline(h = 0, lty = 2)
plot(100 * panel_summary$median_exposure, 100 * panel_summary$median_maximum_drawdown, pch = 19, cex = 2,
     col = colors[panel_summary$variant], xlab = "Median exposure (%)", ylab = "Median maximum drawdown (%)", main = "Return protection bargain")
text(100 * panel_summary$median_exposure, 100 * panel_summary$median_maximum_drawdown, labels = panel_summary$variant, pos = 3, cex = .8)
dev.off()

png(file.path(visual_dir, "development_gate_matrix.png"), 1800, 900, res = 150)
par(mar = c(10, 13, 4, 2))
gate_matrix <- xtabs(as.integer(development_gates$passed) ~ candidate + gate, development_gates)
image(seq_len(ncol(gate_matrix)), seq_len(nrow(gate_matrix)), t(gate_matrix), col = c(red, green), axes = FALSE,
      xlab = "", ylab = "", main = "Frozen development gates")
axis(1, at = seq_len(ncol(gate_matrix)), labels = colnames(gate_matrix), las = 2, cex.axis = .72)
axis(2, at = seq_len(nrow(gate_matrix)), labels = rownames(gate_matrix), las = 1, cex.axis = .85)
text(rep(seq_len(ncol(gate_matrix)), each = nrow(gate_matrix)), rep(seq_len(nrow(gate_matrix)), times = ncol(gate_matrix)),
     labels = ifelse(as.vector(t(t(gate_matrix))) == 1, "PASS", "FAIL"), cex = .8)
dev.off()

plot_tape <- function(candidate, parent, symbol, role, file) {
  cpath <- paths[paths$symbol == symbol & paths$variant == candidate, ]; ppath <- paths[paths$symbol == symbol & paths$variant == parent, ]
  csum <- asset_summary[asset_summary$symbol == symbol & asset_summary$variant == candidate, ]; psum <- asset_summary[asset_summary$symbol == symbol & asset_summary$variant == parent, ]
  png(file, 1800, 1200, res = 150)
  par(mfrow = c(3, 1), mar = c(2, 5, 3, 2), oma = c(3, 0, 3, 0))
  plot(cpath$session_date, cpath$close, type = "l", col = ink, xlab = "", ylab = "Adjusted close", main = paste(candidate, role, symbol, sep = " | "))
  lines(cpath$session_date, cpath$sma200, col = blue, lwd = 2); lines(cpath$session_date, cpath$sma50, col = orange, lwd = 2)
  mtext("Black: close | Blue: SMA200 | Orange: SMA50", side = 3, line = .15, adj = 0, cex = .82)
  plot(cpath$session_date, as.integer(ppath$in_position_after_open), type = "s", ylim = c(-.05, 1.05), col = gray, lwd = 2, xlab = "", ylab = "Long state", yaxt = "n")
  axis(2, at = c(0, 1), labels = c("Cash", "Long"), las = 1); lines(cpath$session_date, as.integer(cpath$in_position_after_open), type = "s", col = green, lwd = 2)
  mtext(paste("Gray:", parent, "| Green:", candidate), side = 3, line = .15, adj = 0, cex = .82)
  plot(cpath$session_date, ppath$strategy_wealth_open, type = "l", col = gray, lwd = 2, xlab = "Session", ylab = "Wealth from 1",
       main = sprintf("candidate %.1f%% | parent %.1f%% | delta %.1f pp", 100 * csum$primary_return, 100 * psum$primary_return, 100 * (csum$primary_return - psum$primary_return)))
  lines(cpath$session_date, cpath$strategy_wealth_open, col = green, lwd = 2); lines(cpath$session_date, cpath$buy_hold_wealth_open, col = ink, lwd = 1)
  legend("topleft", c(parent, candidate, "Buy-and-hold"), col = c(gray, green, ink), lty = 1, lwd = c(2, 2, 1), bty = "n", horiz = TRUE)
  mtext("Historical development is distinct but survivor-biased; 2024-2025 remains unqueried unless nominated", outer = TRUE, side = 1, line = 1)
  dev.off()
}
for (i in seq_len(nrow(tape_manifest))) plot_tape(tape_manifest$candidate[[i]], tape_manifest$parent[[i]], tape_manifest$symbol[[i]], tape_manifest$tape_role[[i]], file.path(output_dir, tape_manifest$visual_file[[i]]))

integrity <- data.frame(
  check = c("registered_122", "no_later_stage_dates", "all_paths_start_cash", "all_entries_next_open",
            "costs_nonbeneficial", "variant_asset_sets_match", "candidate_parent_sets_match"),
  passed = c(
    nrow(registry) == 122L,
    !any(paths$session_date > window[[2L]]) && !any(paths$session_date >= contract$confirmation_start),
    all(vapply(split(paths, interaction(paths$symbol, paths$variant)), function(z) !z$in_position_after_open[[1L]], logical(1))),
    !nrow(trades) || all(trades$entry_date > as.Date(paths$signal_date[match(trades$trade_id, paths$trade_id)]), na.rm = TRUE),
    !nrow(trades) || all(trades$primary_trade_return <= trades$gross_trade_return),
    length(unique(table(asset_summary$variant))) == 1L,
    all(vapply(candidate_detail, function(x) nrow(x) == nrow(eligible), logical(1)))
  ), stringsAsFactors = FALSE
)
development_gates$passed[development_gates$gate == "INTEGRITY"] <- all(integrity$passed)
gate_pass <- aggregate(passed ~ candidate, development_gates, all)
passing <- gate_pass$candidate[gate_pass$passed]
nomination <- data.frame(status = "NO_DEVELOPMENT_NOMINEE", nominee = "", reason = "No candidate cleared every frozen gate.", stringsAsFactors = FALSE)
if (length(passing)) {
  rank_table <- panel_summary[match(passing, panel_summary$variant), ]
  ordered <- order(-rank_table$median_excess_vs_random, -rank_table$positive_fraction, -rank_table$median_maximum_drawdown, rank_table$variant)
  nominee <- rank_table$variant[ordered][[1L]]
  nomination <- data.frame(status = "DEVELOPMENT_NOMINEE_FOR_CONTEXT_ATLAS", nominee = nominee,
                           reason = "Cleared all frozen gates; ranked by matched-control excess, breadth, then drawdown.")
}
if (!all(integrity$passed)) stop(paste("Development integrity failed:", paste(integrity$check[!integrity$passed], collapse = ", ")), call. = FALSE)

run_spec <- data.frame(
  field = c("program_id", "stage", "as_of_timestamp", "window", "registered_assets", "eligible_assets", "variants",
            "primary_cost_bps", "stress_cost_bps", "confirmation_boundary", "nomination_status", "nominee"),
  value = c(contract$program_id, "HISTORICAL_DEVELOPMENT_DISTINCT_SURVIVOR_BIASED", contract$as_of_timestamp,
            paste(window, collapse = " to "), nrow(registry), nrow(eligible), paste(variants, collapse = ","),
            contract$primary_cost_bps, contract$stress_cost_bps, as.character(contract$confirmation_start),
            nomination$status, nomination$nominee)
)
write_csv(run_spec, file.path(output_dir, "run_spec.csv")); write_csv(registry, file.path(output_dir, "frozen_registry.csv"))
write_csv(coverage, file.path(output_dir, "coverage.csv")); write_csv(asset_summary, file.path(output_dir, "asset_variant_summary.csv"))
write_csv(panel_summary, file.path(output_dir, "variant_panel_summary.csv")); write_csv(candidate_comparison, file.path(output_dir, "candidate_parent_comparison.csv"))
write_csv(development_gates, file.path(output_dir, "development_gates.csv")); write_csv(nomination, file.path(output_dir, "nomination.csv"))
write_csv(annual_asset, file.path(output_dir, "annual_asset_returns.csv")); write_csv(annual_summary, file.path(output_dir, "annual_summary.csv"))
write_csv(trades, file.path(output_dir, "trades.csv")); saveRDS(paths, file.path(output_dir, "paths.rds"), compress = "xz")
saveRDS(controls, file.path(output_dir, "random_controls.rds"), compress = "xz"); write_csv(tape_manifest, file.path(output_dir, "representative_tape_manifest.csv"))
write_csv(integrity, file.path(output_dir, "integrity_checks.csv"))
report <- c("# HYP-MOM SMA Follow-Up Development", "", sprintf("- Eligible assets: %d / 122", nrow(eligible)),
            sprintf("- Nomination: %s %s", nomination$status, nomination$nominee), "", "## Policy summary",
            paste(capture.output(print(panel_summary, row.names = FALSE)), collapse = "\n"), "", "## Candidate gates",
            paste(capture.output(print(development_gates, row.names = FALSE)), collapse = "\n"), "",
            "This period is distinct historical development, not forward confirmation. Confirmation remains sealed unless one candidate clears every gate.")
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)
message("SMA follow-up development complete: ", normalizePath(output_dir, winslash = "/", mustWork = TRUE))
