# Render a descriptive NVDA overnight-gap and 30-minute return clock.
# This slice displays every eligible observation and does not fit a model,
# test a trading rule, search a window, or read post-2023 bars.

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
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_nvda_intraday_clock_descriptive.R"))
g5_load_local_renviron(repo_root)

symbol <- "NVDA"
query_start <- as.Date("2017-12-01")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
confirmation_start <- as.Date("2024-01-02")
as_of_timestamp <- "2026-08-31 17:30:00 America/New_York"
refresh <- identical(tolower(Sys.getenv("GEN5_NVDA_CLOCK_REFRESH", "false")), "true")
cache_dir <- file.path(repo_root, "data_cache", "alpaca_intraday_30min")
run_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_intraday_clock_descriptive_20260831"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

config <- g5_alpaca_config_from_env()
g5_alpaca_require_credentials(config)
config$feed <- "sip"

year_rows <- vector("list", 7L)
health <- vector("list", 7L)
for (year in 2017:2023) {
  index <- year - 2016L
  start <- max(query_start, as.Date(sprintf("%d-01-01", year)))
  end <- min(analysis_end, as.Date(sprintf("%d-12-31", year)))
  cache_path <- file.path(cache_dir, sprintf("intraday_30min_sip_nvda_%d.rds", year))
  status <- "CACHE_HIT"
  if (!file.exists(cache_path) || refresh) {
    request <- imom30_request(symbol, start, end, as_of_timestamp)
    year_rows[[index]] <- imom30_fetch(request, config)
    saveRDS(year_rows[[index]], cache_path)
    status <- "FETCHED"
  } else {
    year_rows[[index]] <- readRDS(cache_path)
  }
  x <- year_rows[[index]]
  health[[index]] <- data.frame(
    year = year, status = status, rows = nrow(x),
    first_session = if (nrow(x)) as.character(min(as.Date(x$session_date))) else NA_character_,
    last_session = if (nrow(x)) as.character(max(as.Date(x$session_date))) else NA_character_,
    stringsAsFactors = FALSE
  )
  message(year, ": ", status, " rows=", nrow(x))
}

bars_raw <- do.call(rbind, year_rows)
bars_raw <- bars_raw[!duplicated(bars_raw[c("symbol", "timestamp_utc")]), , drop = FALSE]
bars_raw <- bars_raw[order(bars_raw$timestamp_utc), , drop = FALSE]
bars <- imom30_apply_rth_calendar(bars_raw)
bars <- imom30_apply_archive_exclusions(bars)
bars$session_date <- as.Date(bars$session_date)
bars <- bars[bars$session_date >= query_start & bars$session_date <= analysis_end, , drop = FALSE]

points <- nic_build_clock_points(
  bars = bars,
  analysis_start = analysis_start,
  analysis_end = analysis_end,
  symbol = symbol,
  unavailable_session_dates = imom30_archive_gap_dates()
)
summary <- nic_clock_summary(points)

analysis_bars <- bars[bars$session_date >= analysis_start & bars$session_date <= analysis_end, , drop = FALSE]
normal_counts <- table(analysis_bars$session_date)
source_checks <- data.frame(
  check_id = c(
    "exact_symbol", "unique_timestamps", "positive_finite_ohlcv", "frozen_source_contract",
    "prehistory_available", "analysis_window_exact", "no_confirmation_bars",
    "regular_session_slots_only", "archive_gap_sessions_absent", "all_fourteen_clock_bins",
    "every_analysis_bar_represented", "gap_contamination_removed"
  ),
  passed = c(
    identical(unique(as.character(bars$symbol)), symbol),
    !anyDuplicated(bars[c("symbol", "timestamp_utc")]),
    all(is.finite(bars$open) & bars$open > 0 & is.finite(bars$close) & bars$close > 0 &
          is.finite(bars$high) & bars$high > 0 & is.finite(bars$low) & bars$low > 0 &
          is.finite(bars$volume) & bars$volume >= 0),
    all(bars$feed == "sip") && all(bars$timeframe == "30Min") && all(bars$adjustment == "all"),
    min(bars$session_date) < analysis_start,
    min(points$session_date) == analysis_start && max(points$session_date) == analysis_end,
    max(bars$session_date) < confirmation_start,
    all(bars$bar_slot %in% 1:13),
    !any(bars$session_date %in% imom30_archive_gap_dates()),
    identical(sort(unique(points$clock_order)), 0:13),
    sum(points$observation_type == "RTH_BAR") == nrow(analysis_bars),
    !any(points$observation_type == "OVERNIGHT_GAP" &
           !points$gap_has_complete_prior, na.rm = TRUE)
  ),
  observed = c(
    paste(unique(as.character(bars$symbol)), collapse = ","),
    as.character(sum(duplicated(bars[c("symbol", "timestamp_utc")]))),
    paste(range(c(bars$low, bars$high)), collapse = " to "),
    paste(unique(paste(bars$feed, bars$timeframe, bars$adjustment, sep = "/")), collapse = ","),
    as.character(min(bars$session_date)),
    paste(min(points$session_date), max(points$session_date), sep = " to "),
    as.character(max(bars$session_date)),
    paste(range(bars$bar_slot), collapse = " to "),
    as.character(sum(bars$session_date %in% imom30_archive_gap_dates())),
    paste(sort(unique(points$clock_order)), collapse = ","),
    paste(sum(points$observation_type == "RTH_BAR"), nrow(analysis_bars), sep = " / "),
    as.character(sum(points$observation_type == "OVERNIGHT_GAP" &
                       !points$gap_has_complete_prior, na.rm = TRUE))
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  stop("NVDA clock source checks failed: ",
       paste(source_checks$check_id[!source_checks$passed], collapse = ", "), call. = FALSE)
}

# Deterministic horizontal jitter keeps individual sessions visible without
# changing their x-bin or return value.
point_key <- as.numeric(points$session_date) * 131 + points$clock_order * 977
points$plot_x <- points$clock_order + (((point_key %% 1009) / 1009) - 0.5) * 0.56
points$plot_color <- ifelse(points$observation_type == "OVERNIGHT_GAP", "#D97706", "#2563A8")
plot_path <- file.path(visual_dir, "nvda_overnight_and_30min_return_clock.png")

grDevices::png(plot_path, width = 2200, height = 1350, res = 180)
old_par <- graphics::par(
  mar = c(10.0, 7.2, 7.4, 2.4), mgp = c(3.8, 1.05, 0), family = "sans", bg = "white"
)
on.exit({ graphics::par(old_par); grDevices::dev.off() }, add = TRUE)
y <- points$log_return_pct
y_padding <- max(diff(range(y)) * 0.04, 0.2)
graphics::plot(
  points$plot_x, y, type = "n", xlim = c(-0.55, 13.55),
  ylim = range(y) + c(-y_padding, y_padding), axes = FALSE,
  xlab = "", ylab = "Log return (%)",
  main = "NVDA's intraday return clock",
  cex.main = 1.65, cex.lab = 1.25, col.main = "#142033", col.lab = "#273548"
)
graphics::mtext(
  "Every adjusted observation | 2018-01-02 through 2023-12-29 | overnight gap appears first",
  side = 3, line = 1.0, cex = 1.0, col = "#5C6777"
)
graphics::axis(2, las = 1, col.axis = "#526070", cex.axis = 0.92)
x_labels <- c("Gap", sub("-.*", "", nic_slot_labels()$clock_label))
graphics::axis(1, at = 0:13, labels = x_labels, las = 2, col.axis = "#526070", cex.axis = 0.86)
graphics::abline(h = 0, col = "#667384", lwd = 1.2)
graphics::abline(v = 0.5, col = "#C5CBD3", lwd = 1.0)
graphics::points(
  points$plot_x, y, pch = 16, cex = 0.42,
  col = grDevices::adjustcolor(points$plot_color, alpha.f = 0.20)
)
median_pct <- 100 * summary$median_log_return
graphics::segments(summary$clock_order - 0.22, median_pct,
                   summary$clock_order + 0.22, median_pct,
                   col = "#101828", lwd = 3.0)
graphics::mtext(
  "Bar labels are start times in New York. Each dot is one session observation; dark ticks are medians. No outliers are removed.",
  side = 1, line = 7.9, cex = 0.82, col = "#667384"
)
graphics::legend(
  "topright", legend = c("Prior close to first open", "30-minute open to close"),
  col = c("#D97706", "#2563A8"), pch = 16, pt.cex = 0.9,
  bty = "n", text.col = "#344054", cex = 0.88
)
grDevices::dev.off()
on.exit(NULL, add = FALSE)

run_spec <- data.frame(
  field = c(
    "study_id", "symbol", "provider", "feed", "timeframe", "adjustment",
    "bar_scope", "query_start", "analysis_start", "analysis_end",
    "confirmation_start", "as_of_timestamp", "rth_return_definition",
    "overnight_gap_definition", "display", "outlier_handling", "inferential_statistics",
    "strategy_or_performance"
  ),
  value = c(
    "HYP-NVDA-CLOCK-01.1", symbol, "Alpaca", "sip", "30Min", "all",
    "regular_session_only", as.character(query_start), as.character(analysis_start),
    as.character(analysis_end), as.character(confirmation_start), as_of_timestamp,
    "log(adjusted_bar_close / adjusted_bar_open)",
    "log(first_adjusted_open / prior_adjusted_regular_session_close)",
    "all observations with deterministic horizontal jitter and median ticks",
    "none", "none", "none"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(do.call(rbind, health), file.path(run_dir, "nvda_cache_health.csv"), row.names = FALSE)
utils::write.csv(source_checks, file.path(run_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(points, file.path(run_dir, "nvda_intraday_clock_points.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(run_dir, "nvda_intraday_clock_summary.csv"), row.names = FALSE)

report <- c(
  "# NVDA Overnight and 30-Minute Return Clock",
  "",
  "This is a basic descriptive microscope. It shows the unconditional historical",
  "distribution at each point on NVDA's regular-session clock and does not test",
  "a model, rule, filter, horizon, cost, or performance claim.",
  "",
  paste0("- Research window: `", analysis_start, "` through `", analysis_end, "`"),
  "- Overnight gap: prior regular-session close to current first regular-session open",
  "- Bar return: each adjusted 30-minute bar open to its own close",
  paste0("- Regular-session bar observations: `", sum(points$observation_type == "RTH_BAR"), "`"),
  paste0("- Valid overnight observations: `", sum(points$observation_type == "OVERNIGHT_GAP"), "`"),
  paste0("- Sessions represented: `", length(unique(points$session_date)), "`"),
  "- Visual treatment: every point, deterministic x-jitter, no winsorization, median ticks",
  "- Statistical layer: descriptive summaries only; no inference",
  "- Confirmation boundary: 2024+ remains unread",
  "",
  "## Reading boundary",
  "",
  "The plot can reveal distribution shape, time-of-day concentration, asymmetry,",
  "and unusual tails worth asking about next. It cannot establish predictability or",
  "a tradable one-asset edge. Any candidate pattern must be converted into a causal",
  "rule and tested on a later untouched period.",
  "",
  "## Artifacts",
  "",
  "- `visuals/nvda_overnight_and_30min_return_clock.png`",
  "- `nvda_intraday_clock_points.csv`",
  "- `nvda_intraday_clock_summary.csv`",
  "- `source_checks.csv`",
  "- `run_spec.csv`",
  "- `nvda_cache_health.csv`"
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("NVDA intraday clock descriptive slice complete")
message("Points: ", nrow(points), " | sessions: ", length(unique(points$session_date)))
message("Chart: ", plot_path)
message("Report: ", file.path(run_dir, "report.md"))
