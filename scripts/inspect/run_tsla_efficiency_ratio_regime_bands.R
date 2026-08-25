# Render a descriptive TSLA price chart with causal ER20 path-regime bands.
# This is a visual exploration only: no optimization, performance calculation, or gate.

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
g5_load_local_renviron(repo_root)

cfg <- g5_load_data_layer_config(repo_root)
symbol <- "TSLA"
window_sessions <- 20L
trend_cutoff <- 0.30
query_start <- as.Date("2017-12-01")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
as_of_timestamp <- as.POSIXct("2026-08-24 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(tolower(Sys.getenv("GEN5_TSLA_ER20_REFRESH", unset = "false")), "true")

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_efficiency_ratio_regime_bands_20260824"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create TSLA ER20 output directory.", call. = FALSE)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "tsla_er20_visual_exploration",
  universe_roles = "single_asset_visual_exploration",
  refresh = refresh,
  repo_root = repo_root
)

bars <- query$bars
bars <- bars[bars$symbol == symbol, , drop = FALSE]
bars$session_date <- as.Date(bars$session_date)
bars <- bars[order(bars$session_date), , drop = FALSE]

source_checks <- data.frame(
  check_id = c(
    "exact_symbol", "unique_sessions", "strict_date_order", "positive_finite_close",
    "adjusted_daily_only", "query_start_covered", "analysis_end_covered", "future_rows_absent"
  ),
  passed = c(
    nrow(bars) > 0L && identical(unique(as.character(bars$symbol)), symbol),
    !anyDuplicated(bars$session_date),
    nrow(bars) > 1L && all(diff(bars$session_date) > 0),
    nrow(bars) > 0L && all(is.finite(bars$close) & bars$close > 0),
    nrow(bars) > 0L && all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
    nrow(bars) > 0L && min(bars$session_date) <= query_start,
    nrow(bars) > 0L && max(bars$session_date) >= analysis_end,
    nrow(bars) > 0L && max(bars$session_date) <= analysis_end
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
  failed <- source_checks$check_id[!source_checks$passed]
  stop("TSLA source checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

# ER20 = absolute endpoint displacement divided by the traveled path over
# 20 one-session log-price moves. It is bounded from zero (pure churn) to one
# (every move has the same sign). The value at t uses closes through t only.
log_close <- log(bars$close)
efficiency_ratio <- rep(NA_real_, nrow(bars))
for (i in seq.int(window_sessions + 1L, nrow(bars))) {
  window_log_close <- log_close[seq.int(i - window_sessions, i)]
  displacement <- abs(window_log_close[[window_sessions + 1L]] - window_log_close[[1L]])
  path_length <- sum(abs(diff(window_log_close)))
  efficiency_ratio[[i]] <- if (path_length > 0) displacement / path_length else 0
}

ledger <- data.frame(
  session_date = bars$session_date,
  adjusted_close = bars$close,
  er20 = efficiency_ratio,
  stringsAsFactors = FALSE
)
ledger <- ledger[
  ledger$session_date >= analysis_start & ledger$session_date <= analysis_end,
  , drop = FALSE
]
ledger$path_regime <- ifelse(
  is.na(ledger$er20),
  "INSUFFICIENT_HISTORY",
  ifelse(ledger$er20 >= trend_cutoff, "TRENDING", "SIDEWAYS")
)

metric_checks <- data.frame(
  check_id = c(
    "visible_rows_present", "visible_window_exact", "complete_er20",
    "er20_bounded", "two_path_states_only", "no_post_2023_rows"
  ),
  passed = c(
    nrow(ledger) > 0L,
    nrow(ledger) > 0L && min(ledger$session_date) == analysis_start && max(ledger$session_date) == analysis_end,
    nrow(ledger) > 0L && all(is.finite(ledger$er20)),
    nrow(ledger) > 0L && all(ledger$er20 >= -1e-12 & ledger$er20 <= 1 + 1e-12),
    nrow(ledger) > 0L && all(ledger$path_regime %in% c("TRENDING", "SIDEWAYS")),
    nrow(ledger) > 0L && max(ledger$session_date) <= analysis_end
  ),
  observed = c(
    as.character(nrow(ledger)),
    if (nrow(ledger)) paste(min(ledger$session_date), max(ledger$session_date), sep = " to ") else "no rows",
    as.character(sum(is.finite(ledger$er20))),
    if (any(is.finite(ledger$er20))) paste(range(ledger$er20, na.rm = TRUE), collapse = " to ") else "no values",
    paste(sort(unique(ledger$path_regime)), collapse = ","),
    if (nrow(ledger)) as.character(max(ledger$session_date)) else "no rows"
  ),
  stringsAsFactors = FALSE
)
if (!all(metric_checks$passed)) {
  failed <- metric_checks$check_id[!metric_checks$passed]
  stop("TSLA ER20 construction checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

state_change <- c(TRUE, ledger$path_regime[-1L] != ledger$path_regime[-nrow(ledger)])
span_id <- cumsum(state_change)
span_rows <- split(seq_len(nrow(ledger)), span_id)
regime_spans <- do.call(rbind, lapply(span_rows, function(rows) {
  end_row <- max(rows)
  next_session <- if (end_row < nrow(ledger)) ledger$session_date[[end_row + 1L]] else analysis_end + 1
  data.frame(
    path_regime = ledger$path_regime[[min(rows)]],
    band_start = ledger$session_date[[min(rows)]],
    band_end_exclusive = next_session,
    stringsAsFactors = FALSE
  )
}))
rownames(regime_spans) <- NULL

band_colors <- c(
  TRENDING = grDevices::adjustcolor("#79C98D", alpha.f = 0.34),
  SIDEWAYS = grDevices::adjustcolor("#E99A9A", alpha.f = 0.29)
)
x_min <- analysis_start
x_max <- analysis_end

draw_regime_bands <- function(y_bottom, y_top) {
  for (i in seq_len(nrow(regime_spans))) {
    graphics::rect(
      xleft = as.numeric(regime_spans$band_start[[i]]),
      ybottom = y_bottom,
      xright = as.numeric(regime_spans$band_end_exclusive[[i]]),
      ytop = y_top,
      col = unname(band_colors[regime_spans$path_regime[[i]]]),
      border = NA
    )
  }
}

plot_path <- file.path(visual_dir, "tsla_er20_path_regime_bands.png")
grDevices::png(plot_path, width = 2400, height = 1350, res = 180)
old_par <- graphics::par(
  family = "sans",
  bg = "white",
  fg = "#273548",
  col.axis = "#526070",
  col.lab = "#273548"
)
on.exit({ graphics::par(old_par); grDevices::dev.off() }, add = TRUE)
graphics::layout(matrix(c(1L, 2L), nrow = 2L), heights = c(3.25, 1.0))

graphics::par(mar = c(1.0, 7.0, 7.3, 2.2), mgp = c(3.9, 1.15, 0))
price_ylim <- range(ledger$adjusted_close)
graphics::plot(
  ledger$session_date, ledger$adjusted_close,
  type = "n",
  xlim = c(x_min, x_max),
  ylim = price_ylim,
  log = "y",
  xaxt = "n",
  xlab = "",
  ylab = "TSLA adjusted close (log scale)",
  main = "TSLA path efficiency: trend versus sideways bands",
  cex.main = 1.55,
  cex.lab = 1.18,
  cex.axis = 0.96,
  col.main = "#142033",
  bty = "n",
  las = 1
)
graphics::mtext(
  "20-session log-price efficiency ratio | Green: ER20 >= 0.30 | Red: ER20 < 0.30 | 2018-2023",
  side = 3, line = 1.0, cex = 0.98, col = "#5C6777"
)
draw_regime_bands(price_ylim[[1L]], price_ylim[[2L]])
graphics::grid(nx = NA, ny = NULL, col = grDevices::adjustcolor("#8B96A5", alpha.f = 0.22), lty = 1)
graphics::lines(ledger$session_date, ledger$adjusted_close, col = "#17273B", lwd = 2.15)
graphics::box(bty = "l", col = "#7D8794")
graphics::legend(
  "topleft",
  legend = c("Trending path", "Sideways / choppy path", "TSLA adjusted close"),
  fill = c(unname(band_colors["TRENDING"]), unname(band_colors["SIDEWAYS"]), NA),
  border = c(NA, NA, NA),
  lty = c(NA, NA, 1),
  lwd = c(NA, NA, 2.15),
  col = c(NA, NA, "#17273B"),
  bg = grDevices::adjustcolor("white", alpha.f = 0.88),
  box.col = "#C5CBD3",
  cex = 0.88,
  inset = 0.015
)

graphics::par(mar = c(5.7, 7.0, 1.1, 2.2), mgp = c(3.6, 1.15, 0))
graphics::plot(
  ledger$session_date, ledger$er20,
  type = "n",
  xlim = c(x_min, x_max),
  ylim = c(0, 1),
  xaxt = "n",
  xlab = "Session date",
  ylab = "ER20",
  cex.lab = 1.12,
  cex.axis = 0.94,
  bty = "n",
  las = 1
)
draw_regime_bands(0, 1)
date_ticks <- as.Date(c("2018-01-02", "2020-01-02", "2022-01-03", "2023-12-29"))
graphics::axis(1, at = date_ticks, labels = c("2018", "2020", "2022", "2023"))
graphics::abline(h = trend_cutoff, col = "#526070", lwd = 1.5, lty = 2)
graphics::lines(ledger$session_date, ledger$er20, col = "#223A58", lwd = 1.25)
graphics::box(bty = "l", col = "#7D8794")
graphics::mtext(
  "ER20 uses only closes through day t. The band begins at t and remains until the next session; it measures path shape, not volatility.",
  side = 1, line = 4.25, cex = 0.72, col = "#667384"
)

grDevices::dev.off()
on.exit(NULL, add = FALSE)

run_spec <- data.frame(
  field = c(
    "symbol", "provider", "bars", "metric", "metric_formula", "window_sessions",
    "trend_cutoff", "trending_rule", "sideways_rule", "band_timing", "query_start",
    "analysis_start", "analysis_end", "as_of_timestamp", "refresh",
    "threshold_selection", "model_or_statistic"
  ),
  value = c(
    symbol, "Alpaca SIP", "adjusted daily OHLCV", "log-price Kaufman-style efficiency ratio",
    "abs(log_close_t - log_close_t_minus_20) / sum(abs(one_session_log_price_moves))",
    as.character(window_sessions), as.character(trend_cutoff), "ER20 >= 0.30",
    "ER20 < 0.30", "state known after close t; band begins at t and ends at next session",
    as.character(query_start), as.character(analysis_start), as.character(analysis_end),
    format(as_of_timestamp, "%Y-%m-%d %H:%M:%S %Z"), as.character(refresh),
    "fixed in advance for visual exploration; not optimized on outcomes", "none"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE, na = "")
utils::write.csv(metric_checks, file.path(output_dir, "metric_checks.csv"), row.names = FALSE, na = "")
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE, na = "")
utils::write.csv(ledger, file.path(output_dir, "tsla_er20_daily_ledger.csv"), row.names = FALSE, na = "")
utils::write.csv(regime_spans, file.path(output_dir, "tsla_er20_regime_spans.csv"), row.names = FALSE, na = "")

report_lines <- c(
  "# TSLA ER20 Path-Regime Bands",
  "",
  "This is a visual exploration only. It does not optimize a threshold, fit a model,",
  "calculate strategy performance, or open a trading policy.",
  "",
  paste0("- Symbol: `", symbol, "`"),
  "- Price: Alpaca SIP adjusted daily close, displayed on a log scale",
  paste0("- Visible sessions: `", analysis_start, "` through `", analysis_end, "`"),
  paste0("- Metric: ", window_sessions, "-session log-price Kaufman-style efficiency ratio (`ER20`)"),
  paste0("- Green: `ER20 >= ", sprintf("%.2f", trend_cutoff), "` (trending path)"),
  paste0("- Red: `ER20 < ", sprintf("%.2f", trend_cutoff), "` (sideways or choppy path)"),
  "- Direction: ignored; a smooth decline can be green",
  "- Volatility: not measured by ER20",
  "- Timing: the value at close `t` uses closes through `t`; its band begins at `t`",
  "- Threshold: fixed before rendering and not optimized against an outcome",
  "- Statistical layer: none",
  "",
  "## Artifacts",
  "",
  "- `visuals/tsla_er20_path_regime_bands.png`",
  "- `tsla_er20_daily_ledger.csv`",
  "- `tsla_er20_regime_spans.csv`",
  "- `source_checks.csv`",
  "- `metric_checks.csv`",
  "- `run_spec.csv`"
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("TSLA ER20 path-regime visual exploration complete")
message("Visible sessions: ", nrow(ledger))
message("Chart: ", plot_path)
message("Report: ", file.path(output_dir, "report.md"))
