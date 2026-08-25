# Render a descriptive TSLA t-1 versus t daily log-return scatterplot.
# This is a visual exploration only: no model, fit, or statistical gate.

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
query_start <- as.Date("2017-12-01")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
as_of_timestamp <- as.POSIXct("2026-08-24 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(tolower(Sys.getenv("GEN5_TSLA_SCATTER_REFRESH", unset = "false")), "true")

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_lagged_daily_return_scatter_20260824"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create TSLA scatter output directory.", call. = FALSE)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "tsla_lagged_daily_return_visual_exploration",
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

bars$log_return <- c(NA_real_, diff(log(bars$close)))
indices <- seq.int(3L, nrow(bars))
pairs <- data.frame(
  t_minus_1_session = bars$session_date[indices - 1L],
  t_session = bars$session_date[indices],
  log_return_t_minus_1 = bars$log_return[indices - 1L],
  log_return_t = bars$log_return[indices],
  stringsAsFactors = FALSE
)
pairs <- pairs[
  pairs$t_session >= analysis_start & pairs$t_session <= analysis_end &
    is.finite(pairs$log_return_t_minus_1) & is.finite(pairs$log_return_t),
  , drop = FALSE
]
if (!nrow(pairs)) stop("No complete consecutive-return pairs were constructed.", call. = FALSE)
if (any(pairs$t_minus_1_session >= pairs$t_session)) {
  stop("Consecutive-return pair dates are not strictly ordered.", call. = FALSE)
}

direction <- function(x) ifelse(x > 0, "UP", ifelse(x < 0, "DOWN", "FLAT"))
pairs$direction_t_minus_1 <- direction(pairs$log_return_t_minus_1)
pairs$direction_t <- direction(pairs$log_return_t)
pairs$direction_pair <- paste(pairs$direction_t_minus_1, pairs$direction_t, sep = "_TO_")

pair_colors <- c(
  UP_TO_UP = "#1B9E77",
  DOWN_TO_DOWN = "#D95F5F",
  DOWN_TO_UP = "#4C78A8",
  UP_TO_DOWN = "#E69F00"
)
point_colors <- unname(pair_colors[pairs$direction_pair])
point_colors[is.na(point_colors)] <- "#7A8493"

x <- 100 * pairs$log_return_t_minus_1
y <- 100 * pairs$log_return_t
axis_limit <- max(abs(c(x, y))) * 1.06
plot_path <- file.path(visual_dir, "tsla_t_minus_1_vs_t_daily_log_return_scatter.png")

grDevices::png(plot_path, width = 1800, height = 1400, res = 180)
old_par <- graphics::par(
  mar = c(8.0, 7.0, 7.2, 2.2),
  mgp = c(3.6, 1.1, 0),
  family = "sans",
  bg = "white"
)
on.exit({ graphics::par(old_par); grDevices::dev.off() }, add = TRUE)

graphics::plot(
  x, y,
  type = "n",
  xlim = c(-axis_limit, axis_limit),
  ylim = c(-axis_limit, axis_limit),
  asp = 1,
  xlab = "Prior-day TSLA log return, r[t-1] (%)",
  ylab = "Next-day TSLA log return, r[t] (%)",
  main = "TSLA daily returns: yesterday versus today",
  cex.main = 1.55,
  cex.lab = 1.25,
  cex.axis = 1.0,
  col.main = "#142033",
  col.lab = "#273548",
  col.axis = "#526070",
  bty = "n"
)
graphics::mtext(
  "Adjusted close-to-close log returns | 2018-01-02 through 2023-12-29",
  side = 3, line = 1.0, cex = 1.0, col = "#5C6777"
)

quadrant_fill <- grDevices::adjustcolor(
  c("#4C78A8", "#1B9E77", "#D95F5F", "#E69F00"), alpha.f = 0.055
)
usr <- graphics::par("usr")
graphics::rect(usr[[1L]], 0, 0, usr[[4L]], col = quadrant_fill[[1L]], border = NA)
graphics::rect(0, 0, usr[[2L]], usr[[4L]], col = quadrant_fill[[2L]], border = NA)
graphics::rect(usr[[1L]], usr[[3L]], 0, 0, col = quadrant_fill[[3L]], border = NA)
graphics::rect(0, usr[[3L]], usr[[2L]], 0, col = quadrant_fill[[4L]], border = NA)
graphics::abline(h = 0, v = 0, col = "#667384", lwd = 1.25)
graphics::points(x, y, pch = 16, cex = 0.66, col = grDevices::adjustcolor(point_colors, alpha.f = 0.62))

x_left <- usr[[1L]] + 0.025 * diff(usr[1:2])
x_right <- usr[[2L]] - 0.025 * diff(usr[1:2])
y_top <- usr[[4L]] - 0.025 * diff(usr[3:4])
y_bottom <- usr[[3L]] + 0.025 * diff(usr[3:4])
graphics::text(x_left, y_top, "DOWN -> UP", adj = c(0, 1), col = "#315F8E", font = 2, cex = 1.0)
graphics::text(x_right, y_top, "UP -> UP", adj = c(1, 1), col = "#117A63", font = 2, cex = 1.0)
graphics::text(x_left, y_bottom, "DOWN -> DOWN", adj = c(0, 0), col = "#B64B4B", font = 2, cex = 1.0)
graphics::text(x_right, y_bottom, "UP -> DOWN", adj = c(1, 0), col = "#B87500", font = 2, cex = 1.0)
graphics::mtext(
  "Each dot is a pair of consecutive sessions. Zero lines show direction combinations; no fitted line or statistic is shown.",
  side = 1, line = 6.1, cex = 0.80, col = "#667384"
)
grDevices::dev.off()
on.exit(NULL, add = FALSE)

run_spec <- data.frame(
  field = c(
    "symbol", "provider", "bars", "return_definition", "x_axis", "y_axis",
    "query_start", "analysis_start", "analysis_end", "as_of_timestamp",
    "refresh", "model_or_statistic"
  ),
  value = c(
    symbol, "Alpaca SIP", "adjusted daily OHLCV",
    "log(adjusted_close_t / adjusted_close_t_minus_1)",
    "log_return_t_minus_1", "log_return_t", as.character(query_start),
    as.character(analysis_start), as.character(analysis_end),
    format(as_of_timestamp, "%Y-%m-%d %H:%M:%S %Z"), as.character(refresh), "none"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE, na = "")
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE, na = "")
utils::write.csv(pairs, file.path(output_dir, "tsla_consecutive_daily_return_pairs.csv"), row.names = FALSE, na = "")

report_lines <- c(
  "# TSLA t-1 Versus t Daily Log-Return Scatter",
  "",
  "This is a visual exploration only. It does not fit a line, calculate a correlation,",
  "test a direction rule, search a horizon, or open a trading policy.",
  "",
  paste0("- Symbol: `", symbol, "`"),
  "- Return: adjusted close-to-close log return",
  paste0("- Visible target sessions: `", analysis_start, "` through `", analysis_end, "`"),
  paste0("- Consecutive-session pairs: `", nrow(pairs), "`"),
  "- X-axis: prior session log return",
  "- Y-axis: current session log return",
  "- Point color and quadrant labels: direction combination only",
  "- Statistical layer: none",
  "",
  "## Artifacts",
  "",
  "- `visuals/tsla_t_minus_1_vs_t_daily_log_return_scatter.png`",
  "- `tsla_consecutive_daily_return_pairs.csv`",
  "- `source_checks.csv`",
  "- `run_spec.csv`"
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("TSLA lagged-return visual exploration complete")
message("Pairs: ", nrow(pairs))
message("Chart: ", plot_path)
message("Report: ", file.path(output_dir, "report.md"))
