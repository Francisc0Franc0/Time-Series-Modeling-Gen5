# Build the first learning-first Edge Discovery Lab packet. This is a visual
# discovery slice only: no inferential statistics, rule selection, or OOS.

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
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_rule201_reclaim_discovery_20260830"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

paths <- c(
  bars = file.path(source_dir, "wide_atlas_query_bars.csv"),
  registry = file.path(source_dir, "frozen_wide_atlas_registry.csv"),
  source_checks = file.path(source_dir, "wide_atlas_checks.csv")
)
if (!all(file.exists(paths))) {
  edl_ms01_stop("The frozen daily atlas packet is incomplete.")
}

contract <- edl_ms01_validate_contract()
bars_all <- utils::read.csv(paths[["bars"]], stringsAsFactors = FALSE, check.names = FALSE)
registry <- utils::read.csv(paths[["registry"]], stringsAsFactors = FALSE)
source_checks <- utils::read.csv(paths[["source_checks"]], stringsAsFactors = FALSE)
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

basket <- registry[match(contract$symbols, registry$symbol), , drop = FALSE]
if (any(is.na(basket$symbol))) edl_ms01_stop("A frozen symbol is absent from the registry.")
basket$discovery_role <- c(
  "operator_anchor", "operator_anchor", "operator_anchor",
  rep("attention_challenger", 7L)
)
basket$first_observed_session <- as.Date(vapply(
  contract$symbols,
  function(symbol) as.character(min(bars$session_date[bars$symbol == symbol])),
  character(1)
))
basket$last_observed_session <- as.Date(vapply(
  contract$symbols,
  function(symbol) as.character(max(bars$session_date[bars$symbol == symbol])),
  character(1)
))
basket$observed_sessions <- vapply(
  contract$symbols, function(symbol) sum(bars$symbol == symbol), integer(1)
)

ledger <- edl_ms01_build_ledger(bars, contract)
ledger <- ledger[order(match(ledger$symbol, contract$symbols), ledger$session_date), ]
events <- ledger[
  ledger$inside_discovery_band &
    is.finite(ledger$forward_1_open_log_return),
  , drop = FALSE
]
events <- events[order(events$session_date, events$symbol), ]
selected_tapes <- edl_ms01_select_event_tapes(events)

count_table <- as.data.frame.matrix(table(events$symbol, events$event_category))
count_table$symbol <- rownames(count_table)
rownames(count_table) <- NULL
count_table <- count_table[, c("symbol", setdiff(names(count_table), "symbol")), drop = FALSE]

event_segments <- do.call(rbind, lapply(seq_len(nrow(selected_tapes)), function(i) {
  event <- selected_tapes[i, , drop = FALSE]
  x <- ledger[ledger$symbol == event$symbol, , drop = FALSE]
  center <- match(event$session_date, x$session_date)
  lo <- max(1L, center - 15L)
  hi <- min(nrow(x), center + 6L)
  segment <- x[lo:hi, , drop = FALSE]
  segment$tape_order <- event$tape_order
  segment$event_session <- event$session_date
  segment$selected_category <- event$event_category
  segment
}))
rownames(event_segments) <- NULL

strict_prior_volume_ok <- all(vapply(split(ledger, ledger$symbol), function(x) {
  if (nrow(x) < 21L) return(FALSE)
  expected <- x$dollar_volume[[21L]] / stats::median(x$dollar_volume[1:20])
  all(is.na(x$abnormal_dollar_volume[1:20])) &&
    isTRUE(all.equal(x$abnormal_dollar_volume[[21L]], expected))
}, logical(1)))

checks <- data.frame(
  check_id = c(
    "inherited_atlas_checks", "exact_discovery_basket", "adjusted_daily_only",
    "train_boundary", "proxy_threshold_fixed", "near_miss_side_fixed",
    "discovery_band_fixed", "close_location_bounded", "strict_prior_volume",
    "next_open_clock", "finite_outcomes_stay_in_train", "tape_categories_complete",
    "tapes_first_chronological", "official_status_not_claimed", "no_inference"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (identical(unique(as.character(basket$symbol)), contract$symbols)) "PASS" else "FAIL",
    if (all(as.logical(bars$adjusted)) && all(bars$timeframe == "1D")) "PASS" else "FAIL",
    if (min(ledger$session_date) >= contract$analysis_start &&
        max(ledger$session_date) <= contract$analysis_end) "PASS" else "FAIL",
    if (all(events$rule201_proxy_trigger ==
            (events$minimum_intraday_return <= contract$threshold))) "PASS" else "FAIL",
    if (all(events$threshold_group[!events$rule201_proxy_trigger] == "NEAR_MISS")) "PASS" else "FAIL",
    if (all(events$minimum_intraday_return >= contract$discovery_band[[1L]] &
            events$minimum_intraday_return <= contract$discovery_band[[2L]])) "PASS" else "FAIL",
    if (all(events$close_location_value >= 0 & events$close_location_value <= 1)) "PASS" else "FAIL",
    if (strict_prior_volume_ok) "PASS" else "FAIL",
    if (all(events$entry_session > events$session_date)) "PASS" else "FAIL",
    if (all(events$exit_1_session[is.finite(events$forward_1_open_log_return)] <=
            contract$analysis_end)) "PASS" else "FAIL",
    if (identical(selected_tapes$event_category, c(
      "TRIGGERED_PROXY__STRONG_RECLAIM", "TRIGGERED_PROXY__WEAK_CLOSE",
      "NEAR_MISS__STRONG_RECLAIM", "NEAR_MISS__WEAK_CLOSE"
    ))) "PASS" else "FAIL",
    if (all(vapply(seq_len(nrow(selected_tapes)), function(i) {
      target <- selected_tapes$event_category[[i]]
      min(events$session_date[events$event_category == target &
        is.finite(events$forward_5_open_log_return)]) == selected_tapes$session_date[[i]]
    }, logical(1)))) "PASS" else "FAIL",
    "PASS", "PASS"
  ),
  detail = c(
    sprintf("%d/%d inherited checks pass", sum(source_checks$status == "PASS"), nrow(source_checks)),
    paste(contract$symbols, collapse = ","),
    "Alpaca adjusted daily OHLCV inherited from the frozen atlas",
    "2018-01-02 through 2023-12-29 only",
    "daily low / prior adjusted close - 1 <= -10% proxy",
    "events above -10% remain near misses",
    "visual neighborhood fixed at -12% through -8%",
    "(close-low)/(high-low)",
    "20-session median excludes the current session",
    "signal at completed close; entry at next open",
    "no finite displayed outcome exits after 2023-12-29",
    "triggered/near-miss crossed with strong/weak close",
    "first chronological eligible event per category; outcomes ignored",
    "daily-low proxy is not labeled exact exchange Rule 201 status",
    "counts and visuals only; no hypothesis tests or performance claim"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
  edl_ms01_stop("One or more construction checks failed.")
}

run_spec <- data.frame(
  study_id = contract$study_id,
  status = "DISCOVERY_SLICE_COMPLETE_NO_EDGE_CLAIM",
  source_packet = normalizePath(source_dir, winslash = "/"),
  analysis_window = "2018-01-02 through 2023-12-29",
  basket = paste(contract$symbols, collapse = ";"),
  threshold = "minimum adjusted daily low return <= -10% proxy",
  visual_band = "-12% through -8%",
  reclaim_measure = "close location value within daily range",
  volume_measure = "current dollar volume / strictly prior 20-session median",
  forward_clock = "signal completed close t; enter open t+1; descriptive 1/3/5-session exits",
  inference = "none_visual_learning_slice",
  exact_rule201_status = "not_yet_joined_official_exchange_files",
  post_2023_status = "sealed",
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(basket, file.path(output_dir, "discovery_basket.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(events, file.path(output_dir, "event_ledger.csv"), row.names = FALSE)
utils::write.csv(count_table, file.path(output_dir, "event_counts.csv"), row.names = FALSE)
utils::write.csv(selected_tapes, file.path(output_dir, "selected_event_tapes.csv"), row.names = FALSE)
utils::write.csv(event_segments, file.path(output_dir, "selected_event_tape_segments.csv"), row.names = FALSE)

# Scatterplot: fixed regulatory threshold, next-session outcome, reclaim color,
# and abnormal-volume size. The visual y-axis is clipped transparently; the CSV
# preserves every full outcome.
y_raw <- 100 * expm1(events$forward_1_open_log_return)
y_limit <- 25
y_plot <- pmax(-y_limit, pmin(y_limit, y_raw))
clv_index <- pmax(1L, pmin(101L, 1L + floor(100 * events$close_location_value)))
palette <- grDevices::colorRampPalette(c("#B44738", "#EDEDED", "#14866D"))(101)
point_fill <- grDevices::adjustcolor(palette[clv_index], alpha.f = 0.72)
volume_ratio <- pmax(0.5, pmin(4, events$abnormal_dollar_volume))
point_size <- 0.7 + 0.55 * sqrt(volume_ratio)

png(file.path(visual_dir, "rule201_threshold_scatter.png"), width = 1800, height = 1050, res = 150)
par(mar = c(6, 7, 6, 3), family = "sans")
plot(
  100 * events$minimum_intraday_return, y_plot,
  type = "n", xlim = c(-12, -8), ylim = c(-y_limit, y_limit),
  xlab = "Worst intraday return from prior close (%)",
  ylab = "Following-session next-open return (%)",
  main = "Does crossing the fixed -10% boundary interact with same-day reclaim?",
  sub = "Color = close location (red weak -> green strong) | size = abnormal dollar volume | y clipped at +/-25%"
)
abline(h = 0, col = "#B8BCC4", lwd = 1.5)
abline(v = -10, col = "#3D8DFF", lwd = 3, lty = 2)
points(
  100 * events$minimum_intraday_return, y_plot,
  pch = 21, bg = point_fill, col = grDevices::adjustcolor("#24364B", 0.45),
  cex = point_size, lwd = 0.7
)
upper <- y_raw > y_limit
lower <- y_raw < -y_limit
if (any(upper)) points(100 * events$minimum_intraday_return[upper], rep(y_limit, sum(upper)), pch = 24, bg = point_fill[upper], cex = point_size[upper])
if (any(lower)) points(100 * events$minimum_intraday_return[lower], rep(-y_limit, sum(lower)), pch = 25, bg = point_fill[lower], cex = point_size[lower])
for (i in seq_len(nrow(selected_tapes))) {
  event_index <- which(events$symbol == selected_tapes$symbol[[i]] &
    events$session_date == selected_tapes$session_date[[i]])[[1L]]
  text(
    100 * events$minimum_intraday_return[[event_index]], y_plot[[event_index]],
    labels = paste0(selected_tapes$symbol[[i]], " ", format(selected_tapes$session_date[[i]], "%Y-%m-%d")),
    pos = if (i %% 2L) 3 else 1, cex = 0.72, col = "#24364B"
  )
}
legend(
  "topleft",
  legend = c("Weak close", "Middle close", "Strong reclaim", "Rule 201 proxy"),
  pt.bg = c(palette[[1L]], palette[[51L]], palette[[101L]], NA),
  col = c("#24364B", "#24364B", "#24364B", "#3D8DFF"),
  pch = c(21, 21, 21, NA), lty = c(NA, NA, NA, 2), lwd = c(NA, NA, NA, 3),
  pt.cex = 1.3, bty = "n", cex = 0.85
)
mtext(sprintf("%d discovery-band events across %d frozen symbols", nrow(events), length(contract$symbols)), side = 3, line = 0.7, adj = 1, cex = 0.85, col = "#526273")
dev.off()

draw_candles <- function(segment, event) {
  x <- seq_len(nrow(segment))
  event_x <- which(segment$session_date == event$session_date)[[1L]]
  y_range <- range(c(segment$low, segment$high, event$prior_close, event$prior_close * 0.90), finite = TRUE)
  plot(x, segment$close, type = "n", xaxt = "n", xlab = "Session", ylab = "Adjusted price", ylim = y_range)
  rect(event_x - 0.5, y_range[[1L]], event_x + 0.5, y_range[[2L]], col = grDevices::adjustcolor("#D0EDFA", 0.45), border = NA)
  abline(h = event$prior_close, col = "#526273", lty = 3)
  abline(h = event$prior_close * 0.90, col = "#B44738", lty = 2, lwd = 1.5)
  up <- segment$close >= segment$open
  candle_color <- ifelse(up, "#14866D", "#B44738")
  segments(x, segment$low, x, segment$high, col = candle_color, lwd = 1.2)
  rect(
    x - 0.27, pmin(segment$open, segment$close),
    x + 0.27, pmax(segment$open, segment$close),
    col = grDevices::adjustcolor(candle_color, 0.80), border = candle_color
  )
  axis_at <- unique(c(1L, seq(5L, nrow(segment), by = 5L), nrow(segment)))
  axis(1, at = axis_at, labels = format(segment$session_date[axis_at], "%m-%d"), las = 2, cex.axis = 0.75)
  points(event_x + 1L, segment$open[[min(event_x + 1L, nrow(segment))]], pch = 23, bg = "#3D8DFF", col = "#1E4F9A", cex = 1.3)
  title(main = sprintf("%s | %s", event$symbol, gsub("_", " ", event$event_category)), cex.main = 0.95)
  mtext(sprintf(
    "%s | low %+.1f%% | close location %.0f%% | next session %+.1f%%",
    event$session_date, 100 * event$minimum_intraday_return,
    100 * event$close_location_value, 100 * expm1(event$forward_1_open_log_return)
  ), side = 3, line = 0.1, cex = 0.72, col = "#526273")
}

png(file.path(visual_dir, "rule201_deterministic_event_tapes.png"), width = 1900, height = 1250, res = 150)
par(mfrow = c(2, 2), mar = c(5, 5, 4, 2), oma = c(0, 0, 3, 0), family = "sans")
for (i in seq_len(nrow(selected_tapes))) {
  event <- selected_tapes[i, , drop = FALSE]
  segment <- event_segments[event_segments$tape_order == event$tape_order, , drop = FALSE]
  draw_candles(segment, event)
}
mtext("First chronological eligible event in each category - not outcome-selected", outer = TRUE, cex = 1.25, font = 2)
dev.off()

category_counts <- sort(table(events$event_category), decreasing = TRUE)
selected_lines <- vapply(seq_len(nrow(selected_tapes)), function(i) sprintf(
  "- \`%s\`: %s on %s; next-session return %+.1f%%.",
  selected_tapes$event_category[[i]], selected_tapes$symbol[[i]],
  selected_tapes$session_date[[i]], 100 * expm1(selected_tapes$forward_1_open_log_return[[i]])
), character(1))
report <- c(
  "# EDL-MS-01 Rule 201 Reclaim - First Discovery Slice", "",
  "## Purpose", "",
  "Inspect the fixed -10% Rule 201 neighborhood visually before asking whether a formal effect exists.", "",
  "## Frozen surface", "",
  sprintf("- %d symbols: %s.", length(contract$symbols), paste(contract$symbols, collapse = ", ")),
  "- 2018-2023 TRAIN only; post-2023 outcomes are sealed.",
  "- Adjusted daily-low proxy, not official exchange trigger authority.",
  "- Discovery band: -12% through -8%; next-session outcome begins at the next open.",
  "- No significance tests, aggregate return claims, optimized thresholds, or portfolio simulation.", "",
  "## Event inventory", "",
  sprintf("- %d discovery-band events.", nrow(events)),
  sprintf("- %d proxy-triggered and %d near-miss events.", sum(events$rule201_proxy_trigger), sum(!events$rule201_proxy_trigger)),
  paste0("- Category counts: ", paste(names(category_counts), as.integer(category_counts), sep = "=", collapse = "; "), "."), "",
  "## Deterministic tapes", "", selected_lines, "",
  "## Operator readout", "",
  "The scatterplot and tapes are the evidence surface. The current slice does not calculate whether the threshold, reclaim strength, or their interaction is predictive. Huddle before adding exact exchange status, inference, a wider atlas, costs, or an executable rule.", "",
  "## Status", "",
  "\`DISCOVERY_SLICE_COMPLETE_NO_EDGE_CLAIM\`"
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: DISCOVERY_SLICE_COMPLETE_NO_EDGE_CLAIM")
message("Events: ", nrow(events), " (", sum(events$rule201_proxy_trigger), " proxy-triggered; ", sum(!events$rule201_proxy_trigger), " near miss)")
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
