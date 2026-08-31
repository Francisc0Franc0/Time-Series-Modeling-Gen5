# Decompose the frozen Rule 201 discovery events into next-open forward paths.
# This is descriptive anatomy only: no inference, costs, rule selection, or OOS.

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
source(file.path(
  repo_root, "edge_discovery_lab", "R", "edl_ms_01_rule201_reclaim.R"
))

source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
prior_packet <- file.path(
  repo_root, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_rule201_reclaim_discovery_20260830"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_rule201_forward_path_20260830"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

paths <- c(
  bars = file.path(source_dir, "wide_atlas_query_bars.csv"),
  source_checks = file.path(source_dir, "wide_atlas_checks.csv"),
  prior_events = file.path(prior_packet, "event_ledger.csv")
)
if (!all(file.exists(paths))) {
  edl_ms01_stop("The frozen source packet or preceding discovery ledger is incomplete.")
}

contract <- edl_ms01_validate_contract()
path_contract <- edl_ms01_validate_forward_path_contract()
bars_all <- utils::read.csv(paths[["bars"]], stringsAsFactors = FALSE, check.names = FALSE)
source_checks <- utils::read.csv(paths[["source_checks"]], stringsAsFactors = FALSE)
prior_events <- utils::read.csv(paths[["prior_events"]], stringsAsFactors = FALSE)
if (any(source_checks$status != "PASS")) {
  edl_ms01_stop("The inherited atlas contains a failed integrity check.")
}

bars_all$session_date <- as.Date(bars_all$session_date)
bars <- bars_all[
  bars_all$symbol %in% contract$symbols &
    bars_all$session_date >= contract$analysis_start &
    bars_all$session_date <= contract$analysis_end,
  , drop = FALSE
]
bars <- bars[order(match(bars$symbol, contract$symbols), bars$session_date), ]
if (!nrow(bars)) edl_ms01_stop("No bars remained after the frozen filters.")

ledger <- edl_ms01_build_ledger(bars, contract)
ledger <- edl_ms01_add_forward_paths(ledger, path_contract)
ledger <- ledger[order(match(ledger$symbol, contract$symbols), ledger$session_date), ]
events <- ledger[
  ledger$inside_discovery_band &
    is.finite(ledger$path_0_open_log_return),
  , drop = FALSE
]
events <- events[order(events$session_date, events$symbol), ]
if (nrow(events) != nrow(prior_events)) {
  edl_ms01_stop("The frozen event count no longer matches the preceding discovery packet.")
}
prior_key <- paste(prior_events$symbol, as.Date(prior_events$session_date))
current_key <- paste(events$symbol, events$session_date)
if (!identical(sort(prior_key), sort(current_key))) {
  edl_ms01_stop("The event identity set changed relative to the preceding packet.")
}

path_long <- edl_ms01_forward_path_long(events, path_contract)
path_long$event_id <- paste(path_long$symbol, path_long$session_date, sep = "__")
path_summary <- edl_ms01_summarize_forward_paths(path_long, path_contract)
display_summary <- path_summary[
  path_summary$horizon %in% path_contract$display_horizons, , drop = FALSE
]

focal_events <- events[
  events$event_category %in% path_contract$focal_categories, , drop = FALSE
]
focal_events$calendar_year <- format(focal_events$session_date, "%Y")

count_share_table <- function(x, dimension, levels) {
  counts <- as.data.frame.matrix(table(
    factor(x[[dimension]], levels = levels),
    factor(x$event_category, levels = path_contract$focal_categories)
  ))
  counts[[dimension]] <- levels
  counts <- counts[, c(dimension, path_contract$focal_categories), drop = FALSE]
  for (category in path_contract$focal_categories) {
    total <- sum(counts[[category]])
    counts[[paste0(category, "__share")]] <- if (total > 0) counts[[category]] / total else NA_real_
  }
  counts
}

symbol_concentration <- count_share_table(
  focal_events, "symbol", contract$symbols
)
year_levels <- as.character(2018:2023)
year_concentration <- count_share_table(
  focal_events, "calendar_year", year_levels
)

group_labels <- c(
  "TRIGGERED_PROXY__STRONG_RECLAIM" = "Triggered + strong reclaim",
  "TRIGGERED_PROXY__WEAK_CLOSE" = "Triggered + weak close",
  "NEAR_MISS__STRONG_RECLAIM" = "Near miss + strong reclaim",
  "NEAR_MISS__WEAK_CLOSE" = "Near miss + weak close"
)
group_colors <- c(
  "TRIGGERED_PROXY__STRONG_RECLAIM" = "#14866D",
  "TRIGGERED_PROXY__WEAK_CLOSE" = "#B44738",
  "NEAR_MISS__STRONG_RECLAIM" = "#3D8DFF",
  "NEAR_MISS__WEAK_CLOSE" = "#A86B00"
)

checks <- data.frame(
  check_id = c(
    "inherited_atlas_checks",
    "event_count_frozen",
    "event_identity_frozen",
    "post_2023_sealed",
    "next_open_anchor_zero",
    "horizons_fixed_0_to_10",
    "four_focal_categories_fixed",
    "all_focal_categories_present",
    "observed_paths_finite",
    "symbol_concentration_complete",
    "calendar_concentration_complete",
    "no_inference",
    "intraday_branches_not_executed"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (nrow(events) == 646L) "PASS" else "FAIL",
    if (identical(sort(prior_key), sort(current_key))) "PASS" else "FAIL",
    if (max(events$session_date) <= contract$analysis_end) "PASS" else "FAIL",
    if (all(abs(path_long$open_log_return[path_long$horizon == 0L]) < 1e-12)) "PASS" else "FAIL",
    if (identical(sort(unique(path_long$horizon)), 0:10)) "PASS" else "FAIL",
    if (identical(path_contract$focal_categories, names(group_labels))) "PASS" else "FAIL",
    if (all(path_contract$focal_categories %in% unique(path_long$event_category))) "PASS" else "FAIL",
    if (all(is.finite(path_long$open_log_return))) "PASS" else "FAIL",
    if (identical(symbol_concentration$symbol, contract$symbols)) "PASS" else "FAIL",
    if (identical(year_concentration$calendar_year, year_levels)) "PASS" else "FAIL",
    "PASS",
    "PASS"
  ),
  detail = c(
    "all inherited wide-atlas integrity checks remain PASS",
    sprintf("%d discovery-band events retained", nrow(events)),
    "symbol/session event keys match the preceding packet",
    "latest inspected event remains inside 2018-2023 TRAIN",
    "horizon zero equals the next-open entry price",
    "descriptive event-time paths use sessions 0 through 10",
    "trigger/near-miss crossed with strong/weak close",
    "each focal category has at least one eligible event",
    "unobserved tail horizons are omitted without crossing the TRAIN boundary",
    "all ten frozen symbols are represented in the concentration table",
    "calendar table covers every frozen study year",
    "no p-values, confidence claims, BH correction, costs, or portfolio replay",
    "both intraday ideas are bookmarked only; no 30-minute data are opened"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  edl_ms01_stop(paste(
    "Forward-path construction check failed:",
    paste(checks$check_id[checks$status != "PASS"], collapse = ", ")
  ))
}

run_spec <- data.frame(
  field = c(
    "study_id", "source_packet", "prior_packet", "symbols", "study_window",
    "event_band", "entry_clock", "path_horizons", "focal_categories",
    "concentration_dimensions", "inferential_status", "intraday_status",
    "oos_status"
  ),
  value = c(
    path_contract$study_id,
    normalizePath(source_dir, winslash = "/"),
    normalizePath(prior_packet, winslash = "/"),
    paste(contract$symbols, collapse = ","),
    paste(contract$analysis_start, contract$analysis_end, sep = ".."),
    "-12% through -8% adjusted daily-low return",
    "signal completed close t; entry open t+1; horizon 0 is entry",
    paste(path_contract$horizons, collapse = ","),
    paste(path_contract$focal_categories, collapse = ","),
    "symbol and calendar year event shares",
    "descriptive only; no inference or promotion gate",
    "two branches bookmarked; neither executed",
    "post-2023 remains sealed"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(events, file.path(output_dir, "event_ledger_with_paths.csv"), row.names = FALSE)
utils::write.csv(path_long, file.path(output_dir, "forward_path_long.csv"), row.names = FALSE)
utils::write.csv(path_summary, file.path(output_dir, "forward_path_summary.csv"), row.names = FALSE)
utils::write.csv(display_summary, file.path(output_dir, "display_horizon_summary.csv"), row.names = FALSE)
utils::write.csv(symbol_concentration, file.path(output_dir, "symbol_concentration.csv"), row.names = FALSE)
utils::write.csv(year_concentration, file.path(output_dir, "calendar_concentration.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

to_pct <- function(x) 100 * expm1(x)

png(
  file.path(visual_dir, "rule201_forward_path_anatomy.png"),
  width = 1900, height = 1250, res = 150
)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(2, 2), mar = c(4.1, 4.5, 3.4, 1.2), oma = c(1.5, 1.5, 4, 1))
for (category in path_contract$focal_categories) {
  x <- path_long[path_long$event_category == category, , drop = FALSE]
  summary_x <- path_summary[path_summary$event_category == category, , drop = FALSE]
  y_all <- to_pct(x$open_log_return)
  y_limit <- max(12, min(35, stats::quantile(abs(y_all), 0.96, na.rm = TRUE)))
  plot(
    NA, xlim = c(0, 10), ylim = c(-y_limit, y_limit),
    xlab = "Sessions after next-open entry",
    ylab = "Cumulative open-to-open return (%)",
    main = group_labels[[category]], xaxt = "n"
  )
  axis(1, at = c(0:5, 10))
  abline(h = 0, col = "#B8BCC4", lty = 2)
  abline(v = 5, col = "#D4D8DE", lty = 3)
  event_paths <- split(x, x$event_id)
  for (event_path in event_paths) {
    event_path <- event_path[order(event_path$horizon), ]
    lines(
      event_path$horizon, to_pct(event_path$open_log_return),
      col = grDevices::adjustcolor(group_colors[[category]], 0.12),
      lwd = 0.7
    )
  }
  polygon(
    c(summary_x$horizon, rev(summary_x$horizon)),
    c(to_pct(summary_x$q25_open_log_return), rev(to_pct(summary_x$q75_open_log_return))),
    border = NA,
    col = grDevices::adjustcolor(group_colors[[category]], 0.16)
  )
  lines(
    summary_x$horizon, to_pct(summary_x$median_open_log_return),
    col = group_colors[[category]], lwd = 4
  )
  points(
    summary_x$horizon, to_pct(summary_x$median_open_log_return),
    col = group_colors[[category]], pch = 16, cex = 0.65
  )
  mtext(
    sprintf(
      "n=%d | median day 5 %+.1f%% | day 10 %+.1f%%",
      summary_x$n[summary_x$horizon == 0][[1L]],
      to_pct(summary_x$median_open_log_return[summary_x$horizon == 5])[[1L]],
      to_pct(summary_x$median_open_log_return[summary_x$horizon == 10])[[1L]]
    ),
    side = 3, line = 0.25, cex = 0.8, col = "#526273"
  )
}
mtext(
  "Rule 201 candidate forward-path anatomy",
  outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2
)
mtext(
  "Faint lines = individual events | ribbon = interquartile range | bold line = median | descriptive only",
  outer = TRUE, side = 3, line = 0.2, cex = 0.9, col = "#526273"
)
mtext(
  "Panel y-ranges clip extreme individual paths for legibility; summaries use full observations",
  outer = TRUE, side = 1, line = 0.15, cex = 0.72, col = "#6B7280"
)
par(old_par)
dev.off()

draw_share_heatmap <- function(table_data, row_levels, title) {
  share_columns <- paste0(path_contract$focal_categories, "__share")
  z <- t(as.matrix(table_data[, share_columns, drop = FALSE]))
  image(
    x = seq_along(row_levels),
    y = seq_along(path_contract$focal_categories),
    z = t(z),
    col = grDevices::colorRampPalette(c("#FFFFFF", "#D0EDFA", "#3D8DFF", "#24364B"))(100),
    axes = FALSE, xlab = "", ylab = "", main = title, zlim = c(0, max(z, na.rm = TRUE))
  )
  axis(1, at = seq_along(row_levels), labels = row_levels, las = 2, cex.axis = 0.75)
  axis(
    2, at = seq_along(path_contract$focal_categories),
    labels = unname(group_labels[path_contract$focal_categories]),
    las = 2, cex.axis = 0.72
  )
  for (i in seq_along(row_levels)) {
    for (j in seq_along(path_contract$focal_categories)) {
      value <- z[j, i]
      text(i, j, sprintf("%.0f%%", 100 * value), cex = 0.62,
           col = if (value >= 0.22) "white" else "#24364B")
    }
  }
  box()
}

png(
  file.path(visual_dir, "rule201_forward_path_concentration.png"),
  width = 1900, height = 1000, res = 150
)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(1, 2), mar = c(7.5, 11.5, 3.8, 1.2), oma = c(1, 1, 4, 1))
draw_share_heatmap(
  symbol_concentration, contract$symbols,
  "Share of each category by symbol"
)
draw_share_heatmap(
  year_concentration, year_levels,
  "Share of each category by calendar year"
)
mtext(
  "Concentration audit for the four focal path groups",
  outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2
)
mtext(
  "Each row sums to 100%; cells show where that category's events came from",
  outer = TRUE, side = 3, line = 0.2, cex = 0.9, col = "#526273"
)
par(old_par)
dev.off()

day5 <- display_summary[display_summary$horizon == 5L, ]
day10 <- display_summary[display_summary$horizon == 10L, ]
triggered_strong <- focal_events[
  focal_events$event_category == "TRIGGERED_PROXY__STRONG_RECLAIM", , drop = FALSE
]
triggered_strong_symbol_counts <- sort(table(triggered_strong$symbol), decreasing = TRUE)
triggered_strong_year_counts <- sort(table(triggered_strong$calendar_year), decreasing = TRUE)
top_symbol_share <- sum(head(triggered_strong_symbol_counts, 2L)) / nrow(triggered_strong)
top_year_share <- sum(head(triggered_strong_year_counts, 2L)) / nrow(triggered_strong)
readout_lines <- vapply(path_contract$focal_categories, function(category) {
  d5 <- day5[day5$event_category == category, ]
  d10 <- day10[day10$event_category == category, ]
  sprintf(
    "- %s: n=%d; median day 5 %+.2f%%; median day 10 %+.2f%%.",
    category, d5$n, to_pct(d5$median_open_log_return),
    to_pct(d10$median_open_log_return)
  )
}, character(1))

report <- c(
  "# EDL-MS-01 Rule 201 Forward-Path Anatomy", "",
  "## Question", "",
  "Across the already frozen 646 discovery-band events, what does the next-open path look like through five sessions, with ten sessions retained only as context?", "",
  "## Preserved groups", "",
  paste0("- ", path_contract$focal_categories), "",
  "Middle-close events remain in the frozen event ledger and concentration denominator checks, but are not promoted into the four focal mechanism panels.", "",
  "## Readout", "",
  readout_lines, "",
  "The individual paths, interquartile ribbons, and medians are descriptive. They do not establish significance, a trading rule, or a preferred holding period.", "",
  "## Concentration", "",
  sprintf(
    "AMC and CVNA supply %.0f%% of the 24 triggered/strong-reclaim events; the two largest calendar years supply %.0f%%. The symbol and calendar-year heatmaps expose this concentration without fitting a filter.",
    100 * top_symbol_share, 100 * top_year_share
  ), "",
  "## Bookmarked intraday branches", "",
  "1. Completed-event entry timing: after the daily -10% event is known, inspect whether a later intraday entry clock improves the trade geometry.", "",
  "2. Live breach/reclaim signal: after the threshold is crossed intraday, define a causal recovery condition from completed bars and enter only afterward.", "",
  "Neither branch is executed here. Both require a separately approved 30-minute data slice and explicit no-look-ahead timing.", "",
  "## Status", "",
  "FORWARD_PATH_ANATOMY_COMPLETE_NO_EDGE_CLAIM"
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: FORWARD_PATH_ANATOMY_COMPLETE_NO_EDGE_CLAIM")
message("Events: ", nrow(events), "; focal events: ", nrow(focal_events))
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
