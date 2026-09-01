# Probe whether NVDA's completed 09:30-10:00 bar is associated with the
# still-tradeable 10:00-16:00 return. This is descriptive research only:
# no threshold search, inferential gate, trading rule, cost, or performance claim.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_direction.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "own_asset_return_geometry_atlas.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_nvda_intraday_opening_response.R"))

contract <- nior_validate_contract()
clock_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_intraday_clock_descriptive_20260831"
)
atlas_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "own_asset_return_geometry_atlas_20260826"
)
run_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_intraday_opening_response_20260831"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

points_path <- file.path(clock_dir, "nvda_intraday_clock_points.csv")
clock_checks_path <- file.path(clock_dir, "source_checks.csv")
daily_bars_path <- file.path(atlas_dir, "atlas_query_bars.csv")
required <- c(points_path, clock_checks_path, daily_bars_path)
if (any(!file.exists(required))) {
  stop("Missing frozen source artifacts: ", paste(required[!file.exists(required)], collapse = ", "), call. = FALSE)
}

points <- utils::read.csv(points_path, stringsAsFactors = FALSE)
clock_checks <- utils::read.csv(clock_checks_path, stringsAsFactors = FALSE)
daily_bars <- utils::read.csv(daily_bars_path, stringsAsFactors = FALSE)
daily_bars <- daily_bars[daily_bars$symbol == contract$symbol, , drop = FALSE]
daily_bars$session_date <- as.Date(daily_bars$session_date)

state_contract <- oarga_contract()
state_contract$analysis_start <- contract$analysis_start
state_contract$analysis_end <- contract$analysis_end
daily_ledger <- oarga_build_ledger(daily_bars, contract$symbol, state_contract)

built <- nior_build_sessions(points, daily_ledger, contract)
sessions <- built$sessions
thresholds <- built$thresholds
paths <- nior_build_paths(points, sessions, contract)
path_summary <- nior_path_summary(paths, contract)

unfiltered_bins <- nior_bin_summary(sessions, contract = contract)
signed_bins <- nior_bin_summary(
  sessions, "signed_er20_state", "SIGNED_ER20_PRIOR_DAY", contract
)
atrp_bins <- nior_bin_summary(
  sessions, "atrp_state", "ATRP_PRIOR_DAY", contract
)
bin_summary <- rbind(unfiltered_bins, signed_bins, atrp_bins)
state_summary <- rbind(
  nior_state_summary(sessions, contract = contract),
  nior_state_summary(sessions, "signed_er20_state", "SIGNED_ER20_PRIOR_DAY", contract),
  nior_state_summary(sessions, "atrp_state", "ATRP_PRIOR_DAY", contract)
)

describe_subset <- function(id, label, keep) {
  sample <- sessions[keep, , drop = FALSE]
  data.frame(
    contrast_id = id,
    label = label,
    observations = nrow(sample),
    mean_remainder_log_return = mean(sample$remainder_log_return),
    median_remainder_log_return = stats::median(sample$remainder_log_return),
    probability_remainder_up = mean(sample$remainder_log_return > 0),
    stringsAsFactors = FALSE
  )
}
candidate_contrasts <- rbind(
  describe_subset(
    "POSITIVE_TAIL_NOT_HIGH_ATR", "Top-20% opening; prior ATR% LOW or MEDIUM",
    sessions$opening_bin == "POSITIVE_TAIL" & sessions$atrp_state %in% c("LOW", "MEDIUM")
  ),
  describe_subset(
    "POSITIVE_TAIL_ALL", "Top-20% opening; any prior ATR% state",
    sessions$opening_bin == "POSITIVE_TAIL"
  ),
  describe_subset(
    "NOT_HIGH_ATR_ALL", "Any opening; prior ATR% LOW or MEDIUM",
    sessions$atrp_state %in% c("LOW", "MEDIUM")
  ),
  describe_subset(
    "POSITIVE_TAIL_HIGH_ATR", "Top-20% opening; prior ATR% HIGH",
    sessions$opening_bin == "POSITIVE_TAIL" & sessions$atrp_state == "HIGH"
  ),
  describe_subset(
    "NEGATIVE_TAIL_HIGH_ATR", "Bottom-20% opening; prior ATR% HIGH",
    sessions$opening_bin == "NEGATIVE_TAIL" & sessions$atrp_state == "HIGH"
  )
)

rth <- points[points$observation_type == "RTH_BAR", , drop = FALSE]
rth$session_date <- as.Date(rth$session_date)
rth$bar_slot <- as.integer(rth$bar_slot)
counts <- table(rth$session_date)
full_dates <- as.Date(names(counts)[counts == 13L])
partial_dates <- as.Date(names(counts)[counts != 13L])

source_checks <- data.frame(
  check_id = c(
    "frozen_clock_source_clean", "exact_symbol", "frozen_window_only",
    "full_session_horizon", "partial_sessions_excluded", "unique_session_rows",
    "state_is_strictly_prior", "signed_state_complete", "atrp_state_complete",
    "sample_wide_tail_thresholds", "path_starts_at_ten", "path_ends_at_remainder",
    "no_confirmation_data"
  ),
  passed = c(
    all(clock_checks$passed %in% c(TRUE, "TRUE")),
    identical(unique(as.character(sessions$symbol)), contract$symbol),
    min(sessions$session_date) == contract$analysis_start &&
      max(sessions$session_date) == contract$analysis_end,
    nrow(sessions) == length(full_dates),
    !any(partial_dates %in% sessions$session_date),
    !anyDuplicated(sessions$session_date),
    all(sessions$state_session < sessions$session_date),
    all(sessions$signed_er20_state %in% contract$signed_er20_states),
    all(sessions$atrp_state %in% contract$atrp_states),
    identical(thresholds$probability, c(0.20, 0.80)),
    all(abs(paths$cumulative_remainder_log_return[paths$path_step == 0L]) < 1e-12),
    isTRUE(all.equal(
      paths$cumulative_remainder_log_return[paths$path_step == 12L],
      sessions$remainder_log_return,
      tolerance = 1e-12, check.attributes = FALSE
    )),
    max(sessions$session_date) < as.Date("2024-01-02")
  ),
  observed = c(
    paste(sum(clock_checks$passed %in% c(TRUE, "TRUE")), nrow(clock_checks), sep = "/"),
    paste(unique(sessions$symbol), collapse = ","),
    paste(min(sessions$session_date), max(sessions$session_date), sep = " to "),
    paste(nrow(sessions), length(full_dates), sep = " / "),
    paste(length(partial_dates), "partial sessions"),
    as.character(sum(duplicated(sessions$session_date))),
    paste(range(as.numeric(sessions$session_date - sessions$state_session)), collapse = " to "),
    paste(table(sessions$signed_er20_state), collapse = ","),
    paste(table(sessions$atrp_state), collapse = ","),
    paste(sprintf("%.4f%%", 100 * thresholds$opening_log_return), collapse = " / "),
    sprintf("max abs %.3g", max(abs(paths$cumulative_remainder_log_return[paths$path_step == 0L]))),
    sprintf("max abs diff %.3g", max(abs(
      paths$cumulative_remainder_log_return[paths$path_step == 12L] - sessions$remainder_log_return
    ))),
    as.character(max(sessions$session_date))
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  stop(
    "NVDA opening-response source checks failed: ",
    paste(source_checks$check_id[!source_checks$passed], collapse = ", "),
    call. = FALSE
  )
}

bin_colors <- c(
  NEGATIVE_TAIL = "#B44738", MIDDLE_60 = "#7A8493", POSITIVE_TAIL = "#14866D"
)
bin_labels <- c(
  NEGATIVE_TAIL = "Bottom 20%", MIDDLE_60 = "Middle 60%", POSITIVE_TAIL = "Top 20%"
)

# 1. Raw causal scatter with fixed sample-wide broad bins.
scatter_path <- file.path(visual_dir, "nvda_opening_bar_vs_remainder_scatter.png")
x <- sessions$opening_log_return_pct
y <- sessions$remainder_log_return_pct
point_color <- unname(bin_colors[as.character(sessions$opening_bin)])
x_pad <- max(diff(range(x)) * 0.04, 0.1)
y_pad <- max(diff(range(y)) * 0.04, 0.1)
grDevices::png(scatter_path, width = 1900, height = 1450, res = 180)
graphics::par(mar = c(8.0, 7.2, 7.2, 2.2), mgp = c(3.8, 1.1, 0), family = "sans", bg = "white")
graphics::plot(
  x, y, type = "n", xlim = range(x) + c(-x_pad, x_pad),
  ylim = range(y) + c(-y_pad, y_pad),
  xlab = "Completed 09:30-10:00 log return (%)",
  ylab = "Still-tradeable 10:00-16:00 log return (%)",
  main = "Does NVDA's opening move carry into the rest of the day?",
  cex.main = 1.5, cex.lab = 1.2, col.main = "#142033", col.lab = "#273548",
  col.axis = "#526070", bty = "n"
)
graphics::mtext(
  sprintf("Every full session | %s through %s | n = %s", contract$analysis_start, contract$analysis_end, nrow(sessions)),
  side = 3, line = 1.0, cex = 0.95, col = "#5C6777"
)
graphics::abline(h = 0, v = 0, col = "#667384", lwd = 1.15)
graphics::abline(v = 100 * thresholds$opening_log_return, col = c("#B44738", "#14866D"), lty = 2, lwd = 1.5)
graphics::points(x, y, pch = 16, cex = 0.62, col = grDevices::adjustcolor(point_color, alpha.f = 0.48))
graphics::legend(
  "topright", legend = unname(bin_labels[contract$bin_labels]),
  col = unname(bin_colors[contract$bin_labels]), pch = 16, bty = "n", cex = 0.86
)
graphics::mtext(
  "Vertical dashed lines are fixed 20th/80th sample quantiles. No fitted line, p-value, or rule is shown.",
  side = 1, line = 6.1, cex = 0.80, col = "#667384"
)
grDevices::dev.off()

# 2. Broad-bin outcome distributions.
distribution_path <- file.path(visual_dir, "nvda_opening_bin_remainder_distributions.png")
groups <- lapply(contract$bin_labels, function(bin) {
  sessions$remainder_log_return_pct[as.character(sessions$opening_bin) == bin]
})
grDevices::png(distribution_path, width = 1900, height = 1250, res = 180)
graphics::par(mar = c(7.2, 7.0, 7.0, 2.2), mgp = c(3.7, 1.05, 0), family = "sans", bg = "white")
graphics::boxplot(
  groups, names = unname(bin_labels[contract$bin_labels]),
  col = grDevices::adjustcolor(unname(bin_colors[contract$bin_labels]), alpha.f = 0.22),
  border = unname(bin_colors[contract$bin_labels]), outline = FALSE,
  ylab = "10:00-16:00 log return (%)",
  main = "Opening tails tilt in the same direction, but overlap heavily",
  cex.main = 1.45, cex.lab = 1.2, col.main = "#142033", col.lab = "#273548",
  ylim = range(y) + c(-0.04, 0.10) * diff(range(y))
)
graphics::abline(h = 0, col = "#667384")
for (i in seq_along(groups)) {
  values <- groups[[i]]
  key <- seq_along(values) * 137L + i * 991L
  jitter <- (((key %% 1009L) / 1009) - 0.5) * 0.36
  graphics::points(
    i + jitter, values, pch = 16, cex = 0.42,
    col = grDevices::adjustcolor(bin_colors[[contract$bin_labels[[i]]]], alpha.f = 0.22)
  )
  graphics::points(i, mean(values), pch = 23, bg = "white", col = "#101828", cex = 1.3)
  row <- unfiltered_bins[unfiltered_bins$opening_bin == contract$bin_labels[[i]], ]
  graphics::text(
    i, max(y) + 0.045 * diff(range(y)),
    labels = sprintf("mean %+.2f%% | up %.1f%%", 100 * row$mean_remainder_log_return, 100 * row$probability_remainder_up),
    cex = 0.78, col = "#344054"
  )
}
graphics::mtext(
  "Boxes show the interquartile range; black diamonds are means; every session remains visible.",
  side = 1, line = 5.3, cex = 0.82, col = "#667384"
)
grDevices::dev.off()

# 3. Median path after 10:00 with interquartile bands.
path_plot <- file.path(visual_dir, "nvda_opening_bin_remainder_paths.png")
grDevices::png(path_plot, width = 1900, height = 1250, res = 180)
graphics::par(mar = c(7.0, 7.0, 7.0, 2.2), mgp = c(3.7, 1.05, 0), family = "sans", bg = "white")
ylim <- 100 * range(c(path_summary$q25_cumulative_log_return, path_summary$q75_cumulative_log_return))
graphics::plot(
  NA, xlim = c(0, 12), ylim = ylim, xlab = "Clock time after the first bar completes",
  ylab = "Cumulative log return from 10:00 (%)",
  main = "Tail medians drift apart gradually after 10:00",
  cex.main = 1.45, cex.lab = 1.2, col.main = "#142033", col.lab = "#273548", bty = "n",
  xaxt = "n"
)
axis_rows <- path_summary[path_summary$opening_bin == contract$bin_labels[[1L]], ]
graphics::axis(1, at = axis_rows$path_step[seq(1, nrow(axis_rows), by = 2)],
               labels = axis_rows$clock_label[seq(1, nrow(axis_rows), by = 2)], cex.axis = 0.88)
graphics::abline(h = 0, col = "#667384")
for (bin in contract$bin_labels) {
  sample <- path_summary[path_summary$opening_bin == bin, ]
  color <- bin_colors[[bin]]
  graphics::polygon(
    c(sample$path_step, rev(sample$path_step)),
    100 * c(sample$q25_cumulative_log_return, rev(sample$q75_cumulative_log_return)),
    col = grDevices::adjustcolor(color, alpha.f = 0.12), border = NA
  )
  graphics::lines(sample$path_step, 100 * sample$median_cumulative_log_return, col = color, lwd = 2.8)
}
graphics::legend(
  "topleft", legend = unname(bin_labels[contract$bin_labels]),
  col = unname(bin_colors[contract$bin_labels]), lwd = 2.8, bty = "n", cex = 0.88
)
graphics::mtext(
  "Lines are median paths; shaded regions are within-bin interquartile ranges. This is not simulated equity.",
  side = 1, line = 5.2, cex = 0.82, col = "#667384"
)
grDevices::dev.off()

# 4. Prior-day state matrices using the same unfiltered opening thresholds.
state_plot <- file.path(visual_dir, "nvda_prior_day_state_opening_response.png")
all_state_bins <- rbind(signed_bins, atrp_bins)
limit <- 100 * max(abs(all_state_bins$mean_remainder_log_return), na.rm = TRUE)
palette <- grDevices::colorRampPalette(c("#B44738", "#F7F8FA", "#14866D"))(201)
draw_matrix <- function(data, state_levels, title) {
  mat <- matrix(NA_real_, nrow = length(state_levels), ncol = length(contract$bin_labels),
                dimnames = list(state_levels, contract$bin_labels))
  nmat <- matrix(0L, nrow = nrow(mat), ncol = ncol(mat), dimnames = dimnames(mat))
  for (i in seq_len(nrow(data))) {
    mat[data$state[[i]], data$opening_bin[[i]]] <- 100 * data$mean_remainder_log_return[[i]]
    nmat[data$state[[i]], data$opening_bin[[i]]] <- data$observations[[i]]
  }
  graphics::image(
    seq_along(contract$bin_labels), seq_along(state_levels), t(mat),
    col = palette, zlim = c(-limit, limit), axes = FALSE,
    xlab = "Opening 09:30-10:00 bin", ylab = "",
    main = title, cex.main = 1.05, cex.lab = 0.9
  )
  graphics::axis(1, at = seq_along(contract$bin_labels),
                 labels = unname(bin_labels[contract$bin_labels]), tick = FALSE, cex.axis = 0.76)
  graphics::axis(2, at = seq_along(state_levels), labels = gsub("_", " ", state_levels),
                 tick = FALSE, las = 1, cex.axis = 0.74)
  for (row in seq_along(state_levels)) for (col in seq_along(contract$bin_labels)) {
    value <- mat[row, col]
    graphics::text(
      col, row, sprintf("%+.2f%%\nn=%d", value, nmat[row, col]),
      cex = 0.72, col = if (abs(value) > 0.58 * limit) "white" else "#273548"
    )
  }
  graphics::box(col = "#CDD3DA")
}
grDevices::png(state_plot, width = 2200, height = 1150, res = 180)
graphics::par(mfrow = c(1, 2), mar = c(6.0, 6.0, 5.6, 1.6), oma = c(0, 0, 4.2, 0), family = "sans", bg = "white")
draw_matrix(signed_bins, contract$signed_er20_states, "Signed ER20 state known before the open")
draw_matrix(atrp_bins, contract$atrp_states, "ATR% state known before the open")
graphics::mtext(
  "Prior-day state changes the response to opening tails",
  side = 3, outer = TRUE, line = 2.1, cex = 1.35, font = 2, col = "#142033"
)
graphics::mtext(
  "Cell value = mean 10:00-16:00 log return | same sample-wide opening bins in every state",
  side = 3, outer = TRUE, line = 0.5, cex = 0.82, col = "#667384"
)
grDevices::dev.off()

run_spec <- data.frame(
  field = c(
    "study_id", "sample_role", "symbol", "source_packet", "analysis_start", "analysis_end",
    "eligible_sessions", "excluded_partial_sessions", "predictor", "outcome",
    "entry_clock_if_later_promoted", "opening_bins", "bin_threshold_source",
    "daily_state_timing", "state_filters", "inferential_statistics", "strategy_or_performance",
    "confirmation_data"
  ),
  value = c(
    contract$study_id, "DESCRIPTIVE_RESEARCH", contract$symbol,
    "nvda_intraday_clock_descriptive_20260831 plus frozen own-asset daily state ledger",
    as.character(contract$analysis_start), as.character(contract$analysis_end),
    as.character(nrow(sessions)), as.character(length(partial_dates)),
    "log(first 30-minute close / 09:30 open)",
    "log(16:00 close / first 30-minute close)", "10:00 America/New_York",
    "bottom 20 percent / middle 60 percent / top 20 percent",
    "single sample-wide 20th and 80th quantiles; no state-specific thresholds",
    "state from the immediately preceding completed daily session",
    "unfiltered; signed ER20 down/sideways/up; ATR% low/medium/high",
    "descriptive correlation and distribution summaries only; no p-values or gates",
    "none", "no post-2023 intraday outcomes read"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(source_checks, file.path(run_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(thresholds, file.path(run_dir, "opening_bin_thresholds.csv"), row.names = FALSE)
utils::write.csv(sessions, file.path(run_dir, "session_ledger.csv"), row.names = FALSE)
utils::write.csv(bin_summary, file.path(run_dir, "opening_bin_summary.csv"), row.names = FALSE)
utils::write.csv(state_summary, file.path(run_dir, "state_summary.csv"), row.names = FALSE)
utils::write.csv(candidate_contrasts, file.path(run_dir, "descriptive_candidate_contrasts.csv"), row.names = FALSE)
utils::write.csv(paths, file.path(run_dir, "intraday_paths.csv"), row.names = FALSE)
utils::write.csv(path_summary, file.path(run_dir, "intraday_path_summary.csv"), row.names = FALSE)

overall <- state_summary[state_summary$condition == "UNFILTERED", ]
negative <- unfiltered_bins[unfiltered_bins$opening_bin == "NEGATIVE_TAIL", ]
middle <- unfiltered_bins[unfiltered_bins$opening_bin == "MIDDLE_60", ]
positive <- unfiltered_bins[unfiltered_bins$opening_bin == "POSITIVE_TAIL", ]
candidate <- candidate_contrasts[candidate_contrasts$contrast_id == "POSITIVE_TAIL_NOT_HIGH_ATR", ]
candidate_high <- candidate_contrasts[candidate_contrasts$contrast_id == "POSITIVE_TAIL_HIGH_ATR", ]
negative_high <- candidate_contrasts[candidate_contrasts$contrast_id == "NEGATIVE_TAIL_HIGH_ATR", ]
report <- c(
  "# NVDA Opening-Bar Versus Remainder-of-Day Response",
  "",
  "This descriptive slice asks whether the completed 09:30-10:00 NVDA return",
  "is associated with the still-tradeable 10:00-16:00 return. It does not fit",
  "a rule, search a threshold, apply costs, or make an edge claim.",
  "",
  "## Frozen construction",
  "",
  sprintf("- Full 13-bar sessions: `%d`", nrow(sessions)),
  sprintf("- Early-close sessions excluded: `%d`", length(partial_dates)),
  sprintf("- Opening tail cutoffs: `%+.3f%%` and `%+.3f%%`", 100 * thresholds$opening_log_return[[1L]], 100 * thresholds$opening_log_return[[2L]]),
  "- State timing: signed ER20 and ATR% are read from the prior completed daily session.",
  "- Every state uses the same unfiltered 20th/80th percentile opening thresholds.",
  "",
  "## Descriptive readout",
  "",
  sprintf("- Unfiltered Pearson correlation: `%+.3f`", overall$pearson_correlation),
  sprintf("- Bottom-20%% opening mean remainder: `%+.3f%%` (up `%.1f%%`)", 100 * negative$mean_remainder_log_return, 100 * negative$probability_remainder_up),
  sprintf("- Middle-60%% opening mean remainder: `%+.3f%%` (up `%.1f%%`)", 100 * middle$mean_remainder_log_return, 100 * middle$probability_remainder_up),
  sprintf("- Top-20%% opening mean remainder: `%+.3f%%` (up `%.1f%%`)", 100 * positive$mean_remainder_log_return, 100 * positive$probability_remainder_up),
  sprintf("- Top-20%% opening with prior ATR%% LOW/MEDIUM: `%+.3f%%` mean, `%.1f%%` up, `n=%d`.", 100 * candidate$mean_remainder_log_return, 100 * candidate$probability_remainder_up, candidate$observations),
  sprintf("- The same top-20%% opening with prior ATR%% HIGH: `%+.3f%%` mean, `%.1f%%` up, `n=%d`.", 100 * candidate_high$mean_remainder_log_return, 100 * candidate_high$probability_remainder_up, candidate_high$observations),
  sprintf("- Bottom-20%% opening with prior ATR%% HIGH: `%+.3f%%` mean, `%.1f%%` up, `n=%d`.", 100 * negative_high$mean_remainder_log_return, 100 * negative_high$probability_remainder_up, negative_high$observations),
  "- The scatter and distributions still overlap heavily. ATR% is a promising descriptive discriminator, not a confirmed edge.",
  "",
  "## Interpretation boundary",
  "",
  "This first pass can reveal whether a directional continuation or fade story is",
  "visually plausible. Any candidate selected after this readout is a new hypothesis",
  "and must receive a separately frozen executable test. These results are not",
  "trade returns and the median path figure is not an equity curve.",
  "",
  "## Artifacts",
  "",
  "- `visuals/nvda_opening_bar_vs_remainder_scatter.png`",
  "- `visuals/nvda_opening_bin_remainder_distributions.png`",
  "- `visuals/nvda_opening_bin_remainder_paths.png`",
  "- `visuals/nvda_prior_day_state_opening_response.png`",
  "- `session_ledger.csv`",
  "- `opening_bin_summary.csv`",
  "- `state_summary.csv`",
  "- `descriptive_candidate_contrasts.csv`",
  "- `intraday_paths.csv`",
  "- `intraday_path_summary.csv`",
  "- `opening_bin_thresholds.csv`",
  "- `source_checks.csv`",
  "- `run_spec.csv`"
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("NVDA opening-response descriptive slice complete")
message("Full sessions: ", nrow(sessions), " | partial sessions excluded: ", length(partial_dates))
message("Pearson r: ", sprintf("%+.3f", overall$pearson_correlation))
message("Report: ", file.path(run_dir, "report.md"))
