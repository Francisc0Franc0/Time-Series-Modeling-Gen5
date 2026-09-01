# Build a focused NVDA daily return-geometry packet from the frozen 2018-2023 atlas.
# This script performs no provider call, no parameter search, and no inferential gate.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "own_asset_return_geometry_atlas_20260826"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_daily_return_microscope_20260831"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

required <- c(
  "atlas_query_bars.csv", "asset_state_grid_cells.csv", "asset_prior_sign_cells.csv"
)
missing <- required[!file.exists(file.path(source_dir, required))]
if (length(missing)) stop("Missing frozen atlas inputs: ", paste(missing, collapse = ", "), call. = FALSE)

symbol <- "NVDA"
horizons <- c(1L, 2L, 3L, 4L, 5L, 10L, 15L, 20L, 25L)
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")

bars <- utils::read.csv(file.path(source_dir, "atlas_query_bars.csv"), stringsAsFactors = FALSE)
grid <- utils::read.csv(file.path(source_dir, "asset_state_grid_cells.csv"), stringsAsFactors = FALSE)
sign_grid <- utils::read.csv(file.path(source_dir, "asset_prior_sign_cells.csv"), stringsAsFactors = FALSE)

bars <- bars[bars$symbol == symbol, , drop = FALSE]
bars$session_date <- as.Date(bars$session_date)
bars <- bars[order(bars$session_date), , drop = FALSE]
grid <- grid[grid$symbol == symbol, , drop = FALSE]
sign_grid <- sign_grid[sign_grid$symbol == symbol, , drop = FALSE]

checks <- data.frame(
  check_id = c(
    "nvda_bars_present", "unique_sessions", "strict_date_order", "positive_close",
    "frozen_window_covered", "no_post_2023_rows_used", "complete_state_surface",
    "complete_prior_sign_surface", "fixed_horizon_vocabulary"
  ),
  passed = c(
    nrow(bars) > 0L,
    !anyDuplicated(bars$session_date),
    nrow(bars) > 1L && all(diff(bars$session_date) > 0),
    all(is.finite(bars$close) & bars$close > 0),
    min(bars$session_date) <= analysis_start && max(bars$session_date) >= analysis_end,
    analysis_end == as.Date("2023-12-29"),
    nrow(grid) == 9L * length(horizons)^2,
    nrow(sign_grid) == 9L * length(horizons)^2,
    setequal(sort(unique(grid$prior_sessions)), horizons) &&
      setequal(sort(unique(grid$forward_sessions)), horizons)
  ),
  observed = c(
    nrow(bars), sum(duplicated(bars$session_date)),
    paste(min(bars$session_date), max(bars$session_date), sep = " to "),
    paste(range(bars$close), collapse = " to "),
    paste(min(bars$session_date), max(bars$session_date), sep = " to "),
    as.character(analysis_end), nrow(grid), nrow(sign_grid),
    paste(sort(unique(grid$prior_sessions)), collapse = ",")
  ),
  stringsAsFactors = FALSE
)
if (!all(checks$passed)) {
  stop("NVDA daily microscope checks failed: ", paste(checks$check_id[!checks$passed], collapse = ", "), call. = FALSE)
}

bars$log_return <- c(NA_real_, diff(log(bars$close)))
idx <- seq.int(3L, nrow(bars))
pairs <- data.frame(
  t_minus_1_session = bars$session_date[idx - 1L],
  t_session = bars$session_date[idx],
  log_return_t_minus_1 = bars$log_return[idx - 1L],
  log_return_t = bars$log_return[idx],
  stringsAsFactors = FALSE
)
pairs <- pairs[
  pairs$t_session >= analysis_start & pairs$t_session <= analysis_end &
    is.finite(pairs$log_return_t_minus_1) & is.finite(pairs$log_return_t),
  , drop = FALSE
]

direction <- function(x) ifelse(x > 0, "UP", ifelse(x < 0, "DOWN", "FLAT"))
pairs$direction_pair <- paste(direction(pairs$log_return_t_minus_1), direction(pairs$log_return_t), sep = "_TO_")
pair_colors <- c(UP_TO_UP = "#1B9E77", DOWN_TO_DOWN = "#D95F5F", DOWN_TO_UP = "#4C78A8", UP_TO_DOWN = "#E69F00")
point_colors <- unname(pair_colors[pairs$direction_pair])
point_colors[is.na(point_colors)] <- "#7A8493"

scatter_path <- file.path(visual_dir, "nvda_t_minus_1_vs_t_daily_log_return_scatter.png")
x <- 100 * pairs$log_return_t_minus_1
y <- 100 * pairs$log_return_t
axis_limit <- max(abs(c(x, y))) * 1.06
grDevices::png(scatter_path, width = 1800, height = 1400, res = 180)
graphics::par(mar = c(8.0, 7.0, 7.2, 2.2), mgp = c(3.6, 1.1, 0), family = "sans", bg = "white")
graphics::plot(
  x, y, type = "n", xlim = c(-axis_limit, axis_limit), ylim = c(-axis_limit, axis_limit), asp = 1,
  xlab = "Prior-day NVDA log return, r[t-1] (%)", ylab = "Next-day NVDA log return, r[t] (%)",
  main = "NVDA daily returns: yesterday versus today", cex.main = 1.55, cex.lab = 1.25,
  cex.axis = 1.0, col.main = "#142033", col.lab = "#273548", col.axis = "#526070", bty = "n"
)
graphics::mtext("Adjusted close-to-close log returns | 2018-01-02 through 2023-12-29", side = 3, line = 1, cex = 1, col = "#5C6777")
usr <- graphics::par("usr")
fills <- grDevices::adjustcolor(c("#4C78A8", "#1B9E77", "#D95F5F", "#E69F00"), alpha.f = 0.055)
graphics::rect(usr[1], 0, 0, usr[4], col = fills[1], border = NA)
graphics::rect(0, 0, usr[2], usr[4], col = fills[2], border = NA)
graphics::rect(usr[1], usr[3], 0, 0, col = fills[3], border = NA)
graphics::rect(0, usr[3], usr[2], 0, col = fills[4], border = NA)
graphics::abline(h = 0, v = 0, col = "#667384", lwd = 1.25)
graphics::points(x, y, pch = 16, cex = 0.66, col = grDevices::adjustcolor(point_colors, alpha.f = 0.62))
graphics::text(usr[1] + .025 * diff(usr[1:2]), usr[4] - .025 * diff(usr[3:4]), "DOWN -> UP", adj = c(0, 1), col = "#315F8E", font = 2)
graphics::text(usr[2] - .025 * diff(usr[1:2]), usr[4] - .025 * diff(usr[3:4]), "UP -> UP", adj = c(1, 1), col = "#117A63", font = 2)
graphics::text(usr[1] + .025 * diff(usr[1:2]), usr[3] + .025 * diff(usr[3:4]), "DOWN -> DOWN", adj = c(0, 0), col = "#B64B4B", font = 2)
graphics::text(usr[2] - .025 * diff(usr[1:2]), usr[3] + .025 * diff(usr[3:4]), "UP -> DOWN", adj = c(1, 0), col = "#B87500", font = 2)
graphics::mtext("Each dot is one pair of consecutive sessions. No fitted line or statistical gate is shown.", side = 1, line = 6.1, cex = .8, col = "#667384")
grDevices::dev.off()

matrix_for <- function(data, state, column) {
  selected <- data[data$state == state, , drop = FALSE]
  out <- matrix(NA_real_, length(horizons), length(horizons), dimnames = list(horizons, horizons))
  for (i in seq_len(nrow(selected))) {
    out[as.character(selected$prior_sessions[i]), as.character(selected$forward_sessions[i])] <- selected[[column]][i]
  }
  out
}

draw_panel_heatmaps <- function(states, labels, output_path, title, subtitle, column = "pearson_correlation", width = 2400, height = 900) {
  values <- lapply(states, function(state) matrix_for(if (column %in% names(grid)) grid else sign_grid, state, column))
  limit <- max(abs(unlist(values)), na.rm = TRUE)
  palette <- grDevices::colorRampPalette(c("#D95F5F", "#F7F8FA", "#3D8DFF"))(201)
  grDevices::png(output_path, width = width, height = height, res = 180)
  graphics::par(mfrow = c(1, length(states)), mar = c(5.2, 4.8, 5.6, 1.2), oma = c(0, 0, 4.2, 0), family = "sans", bg = "white")
  for (panel in seq_along(states)) {
    mat <- values[[panel]]
    graphics::image(seq_along(horizons), seq_along(horizons), t(mat), col = palette, zlim = c(-limit, limit), axes = FALSE,
                    xlab = "Following sessions", ylab = "Prior sessions", main = labels[panel], cex.main = 1.0, cex.lab = .9)
    graphics::axis(1, at = seq_along(horizons), labels = horizons, tick = FALSE, cex.axis = .75)
    graphics::axis(2, at = seq_along(horizons), labels = horizons, tick = FALSE, las = 1, cex.axis = .75)
    for (row in seq_along(horizons)) for (col in seq_along(horizons)) {
      val <- mat[row, col]
      graphics::text(col, row, sprintf("%+.2f", val), cex = .58, col = if (abs(val) > .58 * limit) "white" else "#273548")
    }
    graphics::box(col = "#CDD3DA")
  }
  graphics::mtext(title, side = 3, outer = TRUE, line = 2.1, cex = 1.35, font = 2, col = "#142033")
  graphics::mtext(subtitle, side = 3, outer = TRUE, line = .5, cex = .82, col = "#667384")
  grDevices::dev.off()
}

draw_panel_heatmaps(
  "ALL", "Unfiltered", file.path(visual_dir, "nvda_unfiltered_pearson_heatmap.png"),
  "NVDA cumulative daily return geometry", "Pearson correlation | fixed 9 x 9 horizon grid | 2018-2023", width = 1200, height = 950
)
draw_panel_heatmaps(
  c("RED_SIDEWAYS", "GREEN_TRENDING"), c("ER20 red: sideways", "ER20 green: efficient"),
  file.path(visual_dir, "nvda_er20_state_pearson_heatmaps.png"),
  "Path efficiency changes the NVDA return surface", "State is assigned causally at the anchor session"
)
draw_panel_heatmaps(
  c("LOW", "MEDIUM", "HIGH"), c("ATR% low", "ATR% medium", "ATR% high"),
  file.path(visual_dir, "nvda_atrp_state_pearson_heatmaps.png"),
  "Volatility state changes the NVDA return surface", "Prior-252-session ATR% bins; state is known at the anchor session"
)
draw_panel_heatmaps(
  c("DOWN_TREND", "SIDEWAYS", "UP_TREND"), c("Signed ER20: down", "Signed ER20: sideways", "Signed ER20: up"),
  file.path(visual_dir, "nvda_signed_er20_state_pearson_heatmaps.png"),
  "Direction separates efficient paths", "Signed ER20 combines path efficiency with 20-session direction"
)

draw_sign_triptych <- function(output_path) {
  columns <- c("negative_pearson_correlation", "positive_pearson_correlation", "positive_minus_negative_pearson")
  labels <- c("After negative prior return", "After positive prior return", "Positive minus negative")
  values <- lapply(columns, function(column) matrix_for(sign_grid, "ALL", column))
  limit <- max(abs(unlist(values)), na.rm = TRUE)
  palette <- grDevices::colorRampPalette(c("#D95F5F", "#F7F8FA", "#3D8DFF"))(201)
  grDevices::png(output_path, width = 2400, height = 900, res = 180)
  graphics::par(mfrow = c(1, 3), mar = c(5.2, 4.8, 5.6, 1.2), oma = c(0, 0, 4.2, 0), family = "sans", bg = "white")
  for (panel in seq_along(columns)) {
    mat <- values[[panel]]
    graphics::image(seq_along(horizons), seq_along(horizons), t(mat), col = palette, zlim = c(-limit, limit), axes = FALSE,
                    xlab = "Following sessions", ylab = "Prior sessions", main = labels[panel], cex.main = .95, cex.lab = .9)
    graphics::axis(1, at = seq_along(horizons), labels = horizons, tick = FALSE, cex.axis = .75)
    graphics::axis(2, at = seq_along(horizons), labels = horizons, tick = FALSE, las = 1, cex.axis = .75)
    for (row in seq_along(horizons)) for (col in seq_along(horizons)) {
      val <- mat[row, col]
      graphics::text(col, row, sprintf("%+.2f", val), cex = .56, col = if (abs(val) > .58 * limit) "white" else "#273548")
    }
    graphics::box(col = "#CDD3DA")
  }
  graphics::mtext("Prior-sign asymmetry is a second descriptive lens", side = 3, outer = TRUE, line = 2.1, cex = 1.35, font = 2, col = "#142033")
  graphics::mtext("Same 9 x 9 surface, bifurcated by the sign of the prior cumulative return", side = 3, outer = TRUE, line = .5, cex = .82, col = "#667384")
  grDevices::dev.off()
}
draw_sign_triptych(file.path(visual_dir, "nvda_unfiltered_prior_sign_heatmaps.png"))

one_by_one <- grid[grid$prior_sessions == 1L & grid$forward_sessions == 1L, c("condition", "state", "observations", "pearson_correlation", "mean_forward_return", "probability_forward_up")]
one_by_one <- one_by_one[order(match(one_by_one$state, c("ALL", "RED_SIDEWAYS", "GREEN_TRENDING", "LOW", "MEDIUM", "HIGH", "DOWN_TREND", "SIDEWAYS", "UP_TREND"))), ]

utils::write.csv(checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(pairs, file.path(output_dir, "nvda_consecutive_daily_return_pairs.csv"), row.names = FALSE)
utils::write.csv(grid, file.path(output_dir, "nvda_state_grid_cells.csv"), row.names = FALSE)
utils::write.csv(sign_grid, file.path(output_dir, "nvda_prior_sign_cells.csv"), row.names = FALSE)
utils::write.csv(one_by_one, file.path(output_dir, "nvda_one_by_one_state_summary.csv"), row.names = FALSE)

report <- c(
  "# NVDA Daily Return Microscope",
  "",
  "This packet extracts NVDA from the already-frozen own-asset atlas. It adds no new provider query, horizon search, or inferential gate.",
  "",
  "## Fixed scope",
  "",
  "- Adjusted daily close-to-close log returns.",
  "- Visible study window: 2018-01-02 through 2023-12-29.",
  "- Horizons: 1, 2, 3, 4, 5, 10, 15, 20, and 25 sessions on both axes.",
  "- State vocabulary: unfiltered; ER20 sideways/efficient; prior-252 ATR% low/medium/high; signed ER20 down/sideways/up.",
  "- Prior-sign split: negative branch, positive branch, and positive-minus-negative descriptive contrast.",
  "- No 2024+ confirmation data, strategy return, or multiplicity claim is used here.",
  "",
  "## Adjacent-session descriptive clue",
  "",
  paste0("- Unfiltered 1x1 Pearson correlation: ", sprintf("%+.3f", one_by_one$pearson_correlation[one_by_one$state == "ALL"]), "."),
  paste0("- High-ATR 1x1 Pearson correlation: ", sprintf("%+.3f", one_by_one$pearson_correlation[one_by_one$state == "HIGH"]), "."),
  paste0("- Signed down-trend 1x1 Pearson correlation: ", sprintf("%+.3f", one_by_one$pearson_correlation[one_by_one$state == "DOWN_TREND"]), "."),
  "- These values are descriptive coordinates for visual inspection, not evidence of a tradeable rule.",
  "",
  "## Artifacts",
  "",
  "- `visuals/nvda_t_minus_1_vs_t_daily_log_return_scatter.png`",
  "- `visuals/nvda_unfiltered_pearson_heatmap.png`",
  "- `visuals/nvda_er20_state_pearson_heatmaps.png`",
  "- `visuals/nvda_atrp_state_pearson_heatmaps.png`",
  "- `visuals/nvda_signed_er20_state_pearson_heatmaps.png`",
  "- `visuals/nvda_unfiltered_prior_sign_heatmaps.png`",
  "- `nvda_one_by_one_state_summary.csv`"
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

message("NVDA daily return microscope complete")
message("Output: ", output_dir)
message("Pairs: ", nrow(pairs))
