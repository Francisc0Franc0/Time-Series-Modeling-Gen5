# Descriptive 2023-only NVDA / NVDL close-pressure microscope.
# This slice freezes three causal observation clocks, uses exact completed
# five-minute bars, and does not read NVDA 2024+ or test a trading rule.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_5min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_nvda_letf_close_pressure.R"))
g5_load_local_renviron(repo_root)

contract <- nlcp_contract()
query_start <- as.Date("2022-12-13")
refresh <- identical(tolower(Sys.getenv("GEN5_NVDA_LETF_REFRESH", "false")), "true")
cache_dir <- file.path(repo_root, "data_cache", "alpaca_intraday_5min")
run_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_letf_close_pressure_20260901"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

config <- g5_alpaca_config_from_env()
g5_alpaca_require_credentials(config)
config$feed <- "sip"
month_starts <- seq(as.Date("2022-12-01"), as.Date("2023-12-01"), by = "month")
month_bars <- vector("list", length(month_starts))
month_status <- character(length(month_starts))
for (i in seq_along(month_starts)) {
  month_start <- max(query_start, month_starts[[i]])
  next_month <- if (i < length(month_starts)) month_starts[[i + 1L]] else as.Date("2024-01-01")
  month_end <- min(contract$analysis_end, next_month - 1)
  cache_path <- file.path(cache_dir, sprintf(
    "intraday_5min_sip_nvda_nvdl_%s.rds", format(month_starts[[i]], "%Y%m")
  ))
  month_status[[i]] <- "CACHE_HIT"
  if (!file.exists(cache_path) || refresh) {
    request <- imom5_request(
      contract$symbols, month_start, month_end, contract$as_of_timestamp
    )
    month_bars[[i]] <- imom5_fetch(request, config)
    saveRDS(month_bars[[i]], cache_path)
    month_status[[i]] <- "FETCHED"
  } else {
    month_bars[[i]] <- readRDS(cache_path)
  }
  message(format(month_starts[[i]], "%Y-%m"), ": ", month_status[[i]],
          " rows=", nrow(month_bars[[i]]))
}
bars <- do.call(rbind, month_bars)
cache_status <- if (all(month_status == "CACHE_HIT")) "CACHE_HIT" else "FETCHED"
bars <- bars[!duplicated(bars[c("symbol", "timestamp_utc")]), , drop = FALSE]
bars <- bars[order(bars$symbol, bars$timestamp_utc), , drop = FALSE]
bars$session_date <- as.Date(bars$session_date)
bars <- bars[bars$session_date >= query_start & bars$session_date <= contract$analysis_end, , drop = FALSE]

panel <- nlcp_build_clock_panel(bars, contract)
clock_summary <- nlcp_clock_summary(panel, contract)
tracking_summary <- nlcp_tracking_summary(panel, contract)

required_anchors <- unique(c(
  contract$clocks$anchor_bar, contract$clocks$local_open_bar,
  contract$clocks$outcome_end_bar
))
health <- do.call(rbind, lapply(contract$symbols, function(sym) {
  x <- bars[bars$symbol == sym, , drop = FALSE]
  in_sample <- x[x$session_date >= contract$analysis_start, , drop = FALSE]
  data.frame(
    symbol = sym, cache_status = cache_status, rows = nrow(x),
    sessions = length(unique(x$session_date)),
    first_session = min(x$session_date), last_session = max(x$session_date),
    exact_anchor_rows = sum(in_sample$bar_time_et %in% required_anchors),
    expected_anchor_opportunities = length(unique(in_sample$session_date)) * length(required_anchors),
    stringsAsFactors = FALSE
  )
}))

residual_reproduces <- max(abs(
  panel$tracking_residual_to_anchor -
    (panel$nvdl_daily_to_anchor - contract$leverage_factor * panel$nvda_daily_to_anchor)
)) < 1e-12 && max(abs(
  panel$tracking_residual_future_change -
    (panel$nvdl_future_30m - contract$leverage_factor * panel$nvda_future_30m)
)) < 1e-12
construction_checks <- data.frame(
  check_id = c(
    "exact_symbol_pair", "unique_symbol_timestamps", "frozen_source_contract",
    "no_2024_bars", "analysis_stops_in_2023", "three_predeclared_clocks",
    "exact_anchor_only", "outcome_is_next_30_minutes", "residual_formula_reproduces",
    "unique_clock_sessions", "no_strategy_or_cost_layer"
  ),
  passed = c(
    setequal(unique(bars$symbol), contract$symbols),
    !anyDuplicated(bars[c("symbol", "timestamp_utc")]),
    all(bars$provider == "alpaca" & bars$feed == "sip" &
          bars$timeframe == "5Min" & bars$adjustment == "all"),
    max(bars$session_date) < contract$confirmation_start,
    max(panel$session_date) <= contract$analysis_end,
    identical(unique(panel$clock), contract$clocks$clock),
    all(panel$anchor_bar %in% contract$clocks$anchor_bar) &&
      all(panel$outcome_end_bar %in% contract$clocks$outcome_end_bar),
    all(c("12:25:00", "14:25:00", "15:55:00") == contract$clocks$outcome_end_bar),
    residual_reproduces,
    !anyDuplicated(panel[c("session_date", "clock")]),
    TRUE
  ),
  observed = c(
    paste(sort(unique(bars$symbol)), collapse = ","),
    as.character(sum(duplicated(bars[c("symbol", "timestamp_utc")]))),
    paste(unique(paste(bars$provider, bars$feed, bars$timeframe, bars$adjustment, sep = "/")), collapse = ","),
    as.character(max(bars$session_date)), as.character(max(panel$session_date)),
    paste(unique(panel$clock), collapse = ","),
    paste(nrow(panel), "synchronized clock rows"),
    paste(contract$clocks$outcome_end_bar, collapse = ","),
    paste("max abs diff", format(0, scientific = TRUE)),
    as.character(sum(duplicated(panel[c("session_date", "clock")]))),
    "descriptive correlations and paths only"
  ),
  stringsAsFactors = FALSE
)
if (!all(construction_checks$passed)) {
  stop(
    "NVDA/NVDL close-pressure construction checks failed: ",
    paste(construction_checks$check_id[!construction_checks$passed], collapse = ", "),
    call. = FALSE
  )
}

clock_colors <- c("12:00" = "#3D7EBB", "14:00" = "#D08A24", "15:30" = "#14866D")

# 1. The same daily-move signal at three clocks.
scatter_path <- file.path(visual_dir, "nvda_clock_continuation_scatter.png")
grDevices::png(scatter_path, width = 2400, height = 1050, res = 180)
graphics::par(mfrow = c(1, 3), mar = c(6.2, 6.0, 6.0, 1.5), oma = c(1.3, 0, 3.2, 0), family = "sans", bg = "white")
for (clock in contract$clocks$clock) {
  x <- panel[panel$clock == clock, , drop = FALSE]
  graphics::plot(
    100 * x$nvda_daily_to_anchor, 100 * x$nvda_future_30m,
    pch = 16, cex = 0.70, col = grDevices::adjustcolor(clock_colors[[clock]], alpha.f = 0.42),
    xlab = paste("Prior close to", clock, "log return (%)"),
    ylab = "Next 30-minute log return (%)", bty = "n",
    main = paste(clock, "observation"), col.main = "#142033", col.lab = "#344054"
  )
  graphics::abline(h = 0, v = 0, col = "#C5CBD3")
  graphics::abline(stats::lm(nvda_future_30m ~ nvda_daily_to_anchor, data = x),
                   col = clock_colors[[clock]], lwd = 2.2)
  s <- clock_summary[clock_summary$clock == clock, ]
  graphics::mtext(
    sprintf("Pearson r = %+.3f | top-bottom = %+.3f%%", s$daily_move_pearson, 100 * s$top_minus_bottom_future_mean),
    side = 3, line = 0.5, cex = 0.82, col = "#5D6878"
  )
}
graphics::mtext("Does a large NVDA day continue specifically into the closing 30 minutes?", side = 3, outer = TRUE, line = 1.0, cex = 1.45, col = "#142033")
graphics::mtext("Each dot is one synchronized 2023 session; lines are descriptive least-squares fits.", side = 1, outer = TRUE, line = 0.2, cex = 0.80, col = "#667384")
grDevices::dev.off()

# 2. Match the close to earlier clocks and a local 60-minute control.
comparison_path <- file.path(visual_dir, "nvda_clock_comparison.png")
comparison <- rbind(clock_summary$daily_move_pearson, clock_summary$local_60m_pearson)
rownames(comparison) <- c("Prior close to clock", "Immediately prior 60 min")
grDevices::png(comparison_path, width = 1900, height = 1150, res = 180)
graphics::par(mar = c(7.0, 7.0, 7.2, 2.0), family = "sans", bg = "white")
bp <- graphics::barplot(
  comparison, beside = TRUE, names.arg = clock_summary$clock,
  col = c("#3D7EBB", "#A9B3C0"), border = NA,
  ylim = range(c(-0.15, 0.15, comparison)) * 1.18,
  xlab = "Observation clock", ylab = "Pearson correlation with next 30 minutes",
  main = "A close effect should differ from matched earlier clocks",
  col.main = "#142033", col.lab = "#344054", cex.main = 1.42
)
graphics::abline(h = 0, col = "#667384")
graphics::legend("topleft", legend = rownames(comparison), fill = c("#3D7EBB", "#A9B3C0"), border = NA, bty = "n")
for (j in seq_len(ncol(comparison))) {
  for (i in seq_len(nrow(comparison))) {
    graphics::text(bp[i, j], comparison[i, j], sprintf("%+.3f", comparison[i, j]),
                   pos = if (comparison[i, j] >= 0) 3 else 1, cex = 0.82, col = "#344054")
  }
}
graphics::mtext("The second bar uses only the immediately preceding 60 minutes; it is a clock-control, not the rebalance signal.", side = 1, line = 5.4, cex = 0.78, col = "#667384")
grDevices::dev.off()

# 3. Distinguish fund-price convergence from pressure on NVDA itself.
residual_path <- file.path(visual_dir, "nvdl_tracking_residual_scatter.png")
grDevices::png(residual_path, width = 2400, height = 1050, res = 180)
graphics::par(mfrow = c(1, 3), mar = c(6.2, 6.0, 6.0, 1.5), oma = c(1.3, 0, 3.2, 0), family = "sans", bg = "white")
for (clock in contract$clocks$clock) {
  x <- panel[panel$clock == clock, , drop = FALSE]
  graphics::plot(
    100 * x$tracking_residual_to_anchor, 100 * x$tracking_residual_future_change,
    pch = 16, cex = 0.70, col = grDevices::adjustcolor(clock_colors[[clock]], alpha.f = 0.42),
    xlab = "NVDL minus 1.5x NVDA residual to clock (%)",
    ylab = "Residual change in next 30 min (%)", bty = "n",
    main = paste(clock, "observation"), col.main = "#142033", col.lab = "#344054"
  )
  graphics::abline(h = 0, v = 0, col = "#C5CBD3")
  graphics::abline(stats::lm(tracking_residual_future_change ~ tracking_residual_to_anchor, data = x),
                   col = clock_colors[[clock]], lwd = 2.2)
  s <- tracking_summary[tracking_summary$clock == clock, ]
  graphics::mtext(sprintf("r = %+.3f | slope = %+.3f", s$residual_correlation, s$residual_slope),
                  side = 3, line = 0.5, cex = 0.82, col = "#5D6878")
}
graphics::mtext("NVDL tracking-error correction is not the same as NVDL pushing NVDA", side = 3, outer = TRUE, line = 1.0, cex = 1.45, col = "#142033")
graphics::mtext("Negative slopes mean the ETF price residual tends to converge; that can occur without any NVDA close pressure.", side = 1, outer = TRUE, line = 0.2, cex = 0.80, col = "#667384")
grDevices::dev.off()

# 4. Six extreme sessions keep the path-level behavior visible.
close_panel <- panel[panel$clock == "15:30", , drop = FALSE]
ordered <- close_panel[order(close_panel$nvda_daily_to_anchor), , drop = FALSE]
selected <- rbind(head(ordered, 3L), tail(ordered, 3L))
selected$group <- rep(c("Large negative day", "Large positive day"), each = 3L)
prior_map <- nlcp_previous_close_map(bars, "NVDA")
path_path <- file.path(visual_dir, "nvda_extreme_close_paths.png")
grDevices::png(path_path, width = 2200, height = 1450, res = 180)
graphics::par(mfrow = c(2, 3), mar = c(4.4, 5.0, 4.8, 1.2), oma = c(1.2, 0, 3.4, 0), family = "sans", bg = "white")
for (i in seq_len(nrow(selected))) {
  date <- selected$session_date[[i]]
  x <- bars[bars$symbol == "NVDA" & bars$session_date == date, , drop = FALSE]
  x <- x[order(x$bar_slot), , drop = FALSE]
  prior_close <- prior_map$prior_close[prior_map$session_date == date][[1L]]
  minute <- x$bar_slot * 5
  cumulative <- 100 * log(x$close / prior_close)
  color <- if (selected$group[[i]] == "Large positive day") "#14866D" else "#B44738"
  graphics::plot(
    minute, cumulative, type = "l", lwd = 2.4, col = color, bty = "n",
    xlim = c(0, 390), xlab = "Minutes after 09:30", ylab = "Return from prior close (%)",
    main = paste(selected$group[[i]], date), col.main = "#142033", col.lab = "#344054"
  )
  graphics::abline(h = 0, col = "#C5CBD3")
  graphics::abline(v = 360, lty = 2, col = "#344054")
  graphics::points(360, 100 * selected$nvda_daily_to_anchor[[i]], pch = 21, bg = "white", col = color, cex = 1.0)
}
graphics::mtext("Representative extremes: what happened after the 15:30 observation?", side = 3, outer = TRUE, line = 1.0, cex = 1.45, col = "#142033")
graphics::mtext("Dashed line is the 15:30 decision clock; sessions are the three most negative and positive synchronized observations, not a backtest.", side = 1, outer = TRUE, line = 0.1, cex = 0.78, col = "#667384")
grDevices::dev.off()

close_row <- clock_summary[clock_summary$clock == "15:30", , drop = FALSE]
earlier <- clock_summary[clock_summary$clock != "15:30", , drop = FALSE]
close_specific <- close_row$daily_move_pearson > 0.05 &&
  close_row$daily_move_pearson > max(earlier$daily_move_pearson) + 0.05 &&
  close_row$top_minus_bottom_future_mean > 0
close_residual <- tracking_summary[tracking_summary$clock == "15:30", , drop = FALSE]
residual_convergence <- close_residual$residual_correlation < 0 && close_residual$residual_slope < 0

run_spec <- data.frame(
  field = c(
    "study_id", "sample_role", "symbols", "provider", "feed", "timeframe",
    "adjustment", "query_start", "analysis_start", "analysis_end",
    "confirmation_start", "as_of_timestamp", "observation_clocks",
    "mechanism_signal", "local_control", "outcome", "point_in_time_leverage", "tracking_residual",
    "session_admission", "inference", "strategy_or_performance", "fund_size_data"
  ),
  value = c(
    contract$study_id, contract$sample_role, paste(contract$symbols, collapse = ";"),
    "Alpaca", "sip", "5Min", "all", as.character(query_start),
    as.character(contract$analysis_start), as.character(contract$analysis_end),
    as.character(contract$confirmation_start), contract$as_of_timestamp,
    paste(contract$clocks$clock, collapse = ";"),
    "log(price at completed anchor / prior regular-session close)",
    "log(anchor close / open exactly 60 minutes earlier)",
    "log(price 30 minutes after anchor / anchor close)", "1.5x throughout 2023",
    "NVDL log return minus 1.5 times NVDA log return",
    "exact bars required for both symbols at each clock; no carry-forward",
    "descriptive correlations and slopes only", "none", "not opened"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(health, file.path(run_dir, "data_health.csv"), row.names = FALSE)
utils::write.csv(construction_checks, file.path(run_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(panel, file.path(run_dir, "synchronized_clock_panel.csv"), row.names = FALSE)
utils::write.csv(clock_summary, file.path(run_dir, "clock_summary.csv"), row.names = FALSE)
utils::write.csv(tracking_summary, file.path(run_dir, "tracking_residual_summary.csv"), row.names = FALSE)

report <- c(
  "# NVDA / NVDL Daily-Rebalance Close-Pressure Microscope",
  "",
  "This 2023-only descriptive slice asks whether a scheduled market structure",
  "leaves a clock-specific footprint. NVDL targeted 1.5x NVDA's daily return",
  "throughout 2023 and rebalanced daily. A large NVDA move could therefore imply same-direction",
  "exposure adjustment near the close—but fund flows can offset that demand.",
  "",
  "## Frozen construction",
  "",
  "- Exact adjusted SIP five-minute bars for NVDA and NVDL.",
  "- Observation clocks: 12:00, 14:00, and 15:30 ET.",
  "- Mechanism signal: prior regular-session close to the completed anchor bar.",
  "- Outcome: the following 30 minutes; no carry-forward for missing NVDL bars.",
  "- Local control: the immediately preceding 60-minute NVDA return.",
  "- Point-in-time objective: 1.5x in 2023; NVDL changed to 2x in January 2024.",
  "- Tracking residual: NVDL return minus 1.5x NVDA return, measured on the same clocks.",
  "- No AUM, shares-outstanding reconstruction, costs, rule, or 2024+ NVDA data.",
  "",
  "## Readout",
  "",
  sprintf("- Synchronized observations at 15:30: `%d`.", close_row$observations),
  sprintf("- NVDA prior-close-to-15:30 versus final-30-minute correlation: `%+.3f`.", close_row$daily_move_pearson),
  sprintf("- Same relationship at 12:00 / 14:00: `%+.3f` / `%+.3f`.", earlier$daily_move_pearson[[1L]], earlier$daily_move_pearson[[2L]]),
  sprintf("- 15:30 top-minus-bottom quintile final-30-minute mean: `%+.3f%%`.", 100 * close_row$top_minus_bottom_future_mean),
  sprintf("- 15:30 NVDL residual-correction correlation / slope: `%+.3f` / `%+.3f`.", close_residual$residual_correlation, close_residual$residual_slope),
  sprintf("- Descriptive close-specific continuation clue: `%s`.", if (close_specific) "PRESENT" else "NOT PRESENT"),
  sprintf("- Descriptive NVDL residual convergence: `%s`.", if (residual_convergence) "PRESENT" else "NOT PRESENT"),
  "",
  "## Interpretation boundary",
  "",
  "A close-specific NVDA relationship would only justify reconstructing point-in-time",
  "fund size and predicted rebalance demand next. NVDL residual convergence by itself",
  "is an ETF-pricing result, not evidence that the fund pushed NVDA. This slice is",
  "descriptive and makes no edge or execution claim.",
  "",
  "## External basis",
  "",
  "- SEC 2023 NVDL series record (1.5x): https://www.sec.gov/Archives/edgar/data/1689873/000149315223032890/0001493152-23-032890-index.html",
  "- SEC January 2024 revised prospectus (2x; previously 1.5x): https://www.sec.gov/Archives/edgar/data/1689873/000149315224003271/form497.htm",
  "- Federal Reserve, Are Concerns About Leveraged ETFs Overblown?: https://www.federalreserve.gov/econres/feds/are-concerns-about-leveraged-etfs-overblown.htm",
  "- Alpaca historical stock bars API: https://docs.alpaca.markets/us/reference/stockbarsingle-1",
  "",
  "## Artifacts",
  "",
  "- `visuals/nvda_clock_continuation_scatter.png`",
  "- `visuals/nvda_clock_comparison.png`",
  "- `visuals/nvdl_tracking_residual_scatter.png`",
  "- `visuals/nvda_extreme_close_paths.png`",
  "- `synchronized_clock_panel.csv`",
  "- `clock_summary.csv`",
  "- `tracking_residual_summary.csv`"
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("NVDA/NVDL close-pressure microscope complete")
message("15:30 synchronized observations: ", close_row$observations)
message("15:30 continuation r: ", sprintf("%+.3f", close_row$daily_move_pearson))
message("15:30 residual correction r: ", sprintf("%+.3f", close_residual$residual_correlation))
message("Report: ", file.path(run_dir, "report.md"))
