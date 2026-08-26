# Render a descriptive TSLA price chart with causal signed-ER20 direction states.
# This slice evaluates state behavior only: no outcome optimization, return-grid
# conditioning, strategy performance, or predictive gate.

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
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_direction.R"))
g5_load_local_renviron(repo_root)

cfg <- g5_load_data_layer_config(repo_root)
contract <- tsder_contract()
as_of_timestamp <- as.POSIXct("2026-08-26 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(tolower(Sys.getenv("GEN5_TSLA_SIGNED_ER20_REFRESH", unset = "false")), "true")
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_signed_er20_trend_direction_20260826"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) tsder_stop("Could not create the output directory.")

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = contract$symbol,
  universe_name = "tsla_signed_er20_direction_visual_exploration",
  universe_roles = "single_asset_visual_exploration",
  refresh = refresh,
  repo_root = repo_root
)

bars <- query$bars
bars <- bars[bars$symbol == contract$symbol, , drop = FALSE]
bars$session_date <- as.Date(bars$session_date)
bars <- bars[order(bars$session_date), , drop = FALSE]

source_checks <- data.frame(
  check_id = c(
    "exact_symbol", "unique_sessions", "strict_date_order", "positive_finite_close",
    "adjusted_daily_only", "query_start_covered", "analysis_end_covered", "future_rows_absent"
  ),
  passed = c(
    nrow(bars) > 0L && identical(unique(as.character(bars$symbol)), contract$symbol),
    !anyDuplicated(bars$session_date),
    nrow(bars) > 1L && all(diff(bars$session_date) > 0),
    nrow(bars) > 0L && all(is.finite(bars$close) & bars$close > 0),
    nrow(bars) > 0L && all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
    nrow(bars) > 0L && min(bars$session_date) <= contract$query_start,
    nrow(bars) > 0L && max(bars$session_date) >= contract$analysis_end,
    nrow(bars) > 0L && max(bars$session_date) <= contract$analysis_end
  ),
  observed = c(
    paste(unique(as.character(bars$symbol)), collapse = ","),
    as.character(sum(duplicated(bars$session_date))),
    if (nrow(bars)) paste(min(bars$session_date), max(bars$session_date), sep = " to ") else "no rows",
    if (nrow(bars)) paste(range(bars$close), collapse = " to ") else "no rows",
    paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
    if (nrow(bars)) as.character(min(bars$session_date)) else "no rows",
    if (nrow(bars)) as.character(max(bars$session_date)) else "no rows",
    if (nrow(bars)) as.character(max(bars$session_date)) else "no rows"
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  tsder_stop(paste("Source checks failed:", paste(source_checks$check_id[!source_checks$passed], collapse = ", ")))
}

signed_er20 <- tsder_signed_efficiency_ratio(log(bars$close), contract$window_sessions)
ledger <- data.frame(
  session_date = bars$session_date,
  adjusted_close = bars$close,
  signed_er20 = signed_er20,
  er20 = abs(signed_er20),
  direction_state = tsder_classify_direction(signed_er20, contract$direction_cutoff),
  stringsAsFactors = FALSE
)
ledger <- ledger[
  ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end,
  , drop = FALSE
]

trailing_return20 <- rep(NA_real_, nrow(bars))
for (i in seq.int(contract$window_sessions + 1L, nrow(bars))) {
  trailing_return20[[i]] <- log(bars$close[[i]] / bars$close[[i - contract$window_sessions]])
}
trailing_return20 <- trailing_return20[
  bars$session_date >= contract$analysis_start & bars$session_date <= contract$analysis_end
]

metric_checks <- data.frame(
  check_id = c(
    "visible_window_exact", "complete_signed_er20", "score_bounded", "absolute_matches_er20",
    "score_sign_matches_displacement", "all_three_states_present", "no_post_2023_rows"
  ),
  passed = c(
    nrow(ledger) > 0L && min(ledger$session_date) == contract$analysis_start && max(ledger$session_date) == contract$analysis_end,
    nrow(ledger) > 0L && all(is.finite(ledger$signed_er20)),
    nrow(ledger) > 0L && all(ledger$signed_er20 >= -1 - 1e-12 & ledger$signed_er20 <= 1 + 1e-12),
    nrow(ledger) > 0L && all(abs(abs(ledger$signed_er20) - ledger$er20) < 1e-12),
    nrow(ledger) > 0L && all(sign(ledger$signed_er20) == sign(trailing_return20)),
    identical(sort(unique(ledger$direction_state)), sort(contract$states)),
    nrow(ledger) > 0L && max(ledger$session_date) <= contract$analysis_end
  ),
  observed = c(
    if (nrow(ledger)) paste(min(ledger$session_date), max(ledger$session_date), sep = " to ") else "no rows",
    as.character(sum(is.finite(ledger$signed_er20))),
    if (nrow(ledger)) paste(round(range(ledger$signed_er20), 6), collapse = " to ") else "no rows",
    if (nrow(ledger)) as.character(max(abs(abs(ledger$signed_er20) - ledger$er20))) else "no rows",
    as.character(sum(sign(ledger$signed_er20) != sign(trailing_return20))),
    paste(sort(unique(ledger$direction_state)), collapse = ","),
    if (nrow(ledger)) as.character(max(ledger$session_date)) else "no rows"
  ),
  stringsAsFactors = FALSE
)
if (!all(metric_checks$passed)) {
  tsder_stop(paste("Metric checks failed:", paste(metric_checks$check_id[!metric_checks$passed], collapse = ", ")))
}

spans <- tsder_state_spans(ledger$session_date, ledger$direction_state)
spans$band_end_exclusive <- c(spans$band_start[-1L], contract$analysis_end + 1L)
occupancy <- tsder_state_occupancy(ledger$direction_state, contract$states)
durations <- tsder_duration_summary(spans, contract$states)
transitions <- tsder_transition_tables(ledger$direction_state, contract$states)
quality <- tsder_quality_summary(ledger$direction_state, spans)

state_colors <- c(
  UP_TREND = grDevices::adjustcolor("#59B977", alpha.f = 0.32),
  SIDEWAYS = grDevices::adjustcolor("#AAB3BF", alpha.f = 0.25),
  DOWN_TREND = grDevices::adjustcolor("#E36A6A", alpha.f = 0.29)
)

draw_direction_bands <- function(y_bottom, y_top) {
  for (i in seq_len(nrow(spans))) {
    graphics::rect(
      xleft = as.numeric(spans$band_start[[i]]),
      ybottom = y_bottom,
      xright = as.numeric(spans$band_end_exclusive[[i]]),
      ytop = y_top,
      col = unname(state_colors[spans$direction_state[[i]]]),
      border = NA
    )
  }
}

plot_path <- file.path(visual_dir, "tsla_signed_er20_direction_bands.png")
grDevices::png(plot_path, width = 2400, height = 1350, res = 180)
old_par <- graphics::par(
  family = "sans", bg = "white", fg = "#273548",
  col.axis = "#526070", col.lab = "#273548"
)
on.exit({ graphics::par(old_par); grDevices::dev.off() }, add = TRUE)
graphics::layout(matrix(c(1L, 2L), nrow = 2L), heights = c(3.25, 1.0))

graphics::par(mar = c(1.0, 7.0, 7.3, 2.2), mgp = c(3.9, 1.15, 0))
price_ylim <- range(ledger$adjusted_close)
graphics::plot(
  ledger$session_date, ledger$adjusted_close,
  type = "n", xlim = c(contract$analysis_start, contract$analysis_end),
  ylim = price_ylim, log = "y", xaxt = "n", xlab = "",
  ylab = "TSLA adjusted close (log scale)",
  main = "TSLA signed path efficiency: up, sideways, and down states",
  cex.main = 1.55, cex.lab = 1.18, cex.axis = 0.96,
  col.main = "#142033", bty = "n", las = 1
)
graphics::mtext(
  "Signed ER20 | Green: >= +0.30 | Gray: between -0.30 and +0.30 | Red: <= -0.30 | 2018-2023",
  side = 3, line = 1.0, cex = 0.98, col = "#5C6777"
)
draw_direction_bands(price_ylim[[1L]], price_ylim[[2L]])
graphics::grid(nx = NA, ny = NULL, col = grDevices::adjustcolor("#8B96A5", alpha.f = 0.22), lty = 1)
graphics::lines(ledger$session_date, ledger$adjusted_close, col = "#17273B", lwd = 2.15)
graphics::box(bty = "l", col = "#7D8794")
graphics::legend(
  "topleft",
  legend = c("Up-trending path", "Sideways / inefficient path", "Down-trending path", "TSLA adjusted close"),
  fill = c(unname(state_colors["UP_TREND"]), unname(state_colors["SIDEWAYS"]), unname(state_colors["DOWN_TREND"]), NA),
  border = NA, lty = c(NA, NA, NA, 1), lwd = c(NA, NA, NA, 2.15),
  col = c(NA, NA, NA, "#17273B"),
  bg = grDevices::adjustcolor("white", alpha.f = 0.88), box.col = "#C5CBD3", cex = 0.84, inset = 0.015
)

graphics::par(mar = c(5.7, 7.0, 1.1, 2.2), mgp = c(3.6, 1.15, 0))
graphics::plot(
  ledger$session_date, ledger$signed_er20,
  type = "n", xlim = c(contract$analysis_start, contract$analysis_end),
  ylim = c(-1, 1), xaxt = "n", xlab = "Session date", ylab = "SER20",
  cex.lab = 1.12, cex.axis = 0.94, bty = "n", las = 1
)
draw_direction_bands(-1, 1)
date_ticks <- as.Date(c("2018-01-02", "2020-01-02", "2022-01-03", "2023-12-29"))
graphics::axis(1, at = date_ticks, labels = c("2018", "2020", "2022", "2023"))
graphics::abline(h = c(-contract$direction_cutoff, 0, contract$direction_cutoff),
                 col = c("#A85D5D", "#7B8794", "#43865A"), lwd = c(1.4, 1.0, 1.4), lty = c(2, 3, 2))
graphics::lines(ledger$session_date, ledger$signed_er20, col = "#223A58", lwd = 1.25)
graphics::box(bty = "l", col = "#7D8794")
graphics::mtext(
  "The score at close t uses only the preceding 20 one-session log moves. Sign gives direction; magnitude gives path efficiency.",
  side = 1, line = 4.25, cex = 0.72, col = "#667384"
)
grDevices::dev.off()
on.exit(NULL, add = FALSE)

run_spec <- data.frame(
  field = c(
    "symbol", "provider", "bars", "metric", "metric_formula", "window_sessions",
    "direction_cutoff", "up_rule", "sideways_rule", "down_rule", "band_timing",
    "query_start", "analysis_start", "analysis_end", "as_of_timestamp", "refresh",
    "parameter_selection", "predictive_or_performance_layer"
  ),
  value = c(
    contract$symbol, "Alpaca SIP", "adjusted daily OHLCV", "signed log-price efficiency ratio",
    "(log_close_t - log_close_t_minus_20) / sum(abs(one_session_log_price_moves))",
    as.character(contract$window_sessions), as.character(contract$direction_cutoff),
    "signed_ER20 >= +0.30", "-0.30 < signed_ER20 < +0.30", "signed_ER20 <= -0.30",
    "state known after close t; band begins at t and ends at next session",
    as.character(contract$query_start), as.character(contract$analysis_start), as.character(contract$analysis_end),
    format(as_of_timestamp, "%Y-%m-%d %H:%M:%S %Z"), as.character(refresh),
    "same 20-session window and 0.30 magnitude cutoff as accepted ER20 visual; no search",
    "none"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE, na = "")
utils::write.csv(metric_checks, file.path(output_dir, "metric_checks.csv"), row.names = FALSE, na = "")
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE, na = "")
utils::write.csv(ledger, file.path(output_dir, "signed_er20_daily_ledger.csv"), row.names = FALSE, na = "")
utils::write.csv(spans, file.path(output_dir, "direction_state_spans.csv"), row.names = FALSE, na = "")
utils::write.csv(occupancy, file.path(output_dir, "state_occupancy.csv"), row.names = FALSE, na = "")
utils::write.csv(durations, file.path(output_dir, "state_duration_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(transitions$counts, file.path(output_dir, "state_transition_counts.csv"), row.names = FALSE, na = "")
utils::write.csv(transitions$probabilities, file.path(output_dir, "state_transition_probabilities.csv"), row.names = FALSE, na = "")
utils::write.csv(quality, file.path(output_dir, "state_quality_summary.csv"), row.names = FALSE, na = "")

report_lines <- c(
  "# TSLA Signed-ER20 Trend Direction POC",
  "",
  "This is a descriptive state-quality inspection only. It does not condition the return grid, optimize a parameter, calculate strategy performance, or open a predictive gate.",
  "",
  paste0("- Symbol: `", contract$symbol, "`"),
  paste0("- Visible sessions: `", contract$analysis_start, "` through `", contract$analysis_end, "`"),
  "- Score: `(log_close[t] - log_close[t-20]) / sum(abs(one-session log moves))`.",
  paste0("- Up: `signed ER20 >= +", sprintf("%.2f", contract$direction_cutoff), "`."),
  paste0("- Sideways: `-", sprintf("%.2f", contract$direction_cutoff), " < signed ER20 < +", sprintf("%.2f", contract$direction_cutoff), "`."),
  paste0("- Down: `signed ER20 <= -", sprintf("%.2f", contract$direction_cutoff), "`."),
  "- Timing: the state at close `t` uses closes through `t` only.",
  "- Relationship to ER20: `abs(signed ER20) = ER20`; this is a directional completion of ER20, not an independent filter.",
  "",
  "## State-quality readout",
  "",
  paste0("- Classified sessions: `", quality$classified_sessions, "`."),
  paste0("- Daily state-transition rate: `", sprintf("%.1f%%", 100 * quality$daily_transition_rate), "`."),
  paste0("- Contiguous spans: `", quality$total_spans, "`; one-session spans: `", quality$one_session_spans, "` (`", sprintf("%.1f%%", 100 * quality$one_session_span_fraction), "`)."),
  paste0("- Direct up-to-down or down-to-up transitions: `", quality$direct_up_down_reversals, "`."),
  "",
  "## Artifacts",
  "",
  "- `visuals/tsla_signed_er20_direction_bands.png`",
  "- `signed_er20_daily_ledger.csv`",
  "- `direction_state_spans.csv`",
  "- `state_occupancy.csv`",
  "- `state_duration_summary.csv`",
  "- `state_transition_counts.csv`",
  "- `state_transition_probabilities.csv`",
  "- `state_quality_summary.csv`",
  "- `source_checks.csv`",
  "- `metric_checks.csv`",
  "- `run_spec.csv`"
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("TSLA signed-ER20 trend-direction POC complete")
message("Visible sessions: ", nrow(ledger))
message("Chart: ", plot_path)
message("Report: ", file.path(output_dir, "report.md"))
