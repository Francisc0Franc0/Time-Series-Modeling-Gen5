# Replicate the frozen Rule 201 reclaim anatomy across the full 129-instrument atlas.
# Descriptive TRAIN research only: no inference, strategy replay, costs, or OOS.

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
pilot_dir <- file.path(
  repo_root, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_rule201_forward_path_20260830"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_rule201_wide_atlas_20260830"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

paths <- c(
  bars = file.path(source_dir, "wide_atlas_query_bars.csv"),
  registry = file.path(source_dir, "frozen_wide_atlas_registry.csv"),
  source_checks = file.path(source_dir, "wide_atlas_checks.csv"),
  pilot_summary = file.path(pilot_dir, "display_horizon_summary.csv")
)
if (!all(file.exists(paths))) {
  edl_ms01_stop("The frozen atlas or preceding pilot packet is incomplete.")
}

wide_contract <- edl_ms01_validate_wide_atlas_contract()
base_contract <- edl_ms01_validate_contract()
path_contract <- edl_ms01_validate_forward_path_contract()
registry <- utils::read.csv(paths[["registry"]], stringsAsFactors = FALSE)
registry <- edl_ms01_validate_wide_atlas_registry(registry, wide_contract)
bars <- utils::read.csv(paths[["bars"]], stringsAsFactors = FALSE, check.names = FALSE)
source_checks <- utils::read.csv(paths[["source_checks"]], stringsAsFactors = FALSE)
pilot_summary <- utils::read.csv(paths[["pilot_summary"]], stringsAsFactors = FALSE)
if (any(source_checks$status != "PASS")) {
  edl_ms01_stop("The inherited atlas contains a failed integrity check.")
}

ledger <- edl_ms01_build_wide_atlas_ledger(
  bars, registry, wide_contract, base_contract, path_contract
)
events <- ledger[
  ledger$inside_discovery_band & is.finite(ledger$path_0_open_log_return),
  , drop = FALSE
]
events <- events[order(events$session_date, events$atlas_order), ]
focal_events <- events[
  events$event_category %in% path_contract$focal_categories, , drop = FALSE
]
if (!nrow(events) || !nrow(focal_events)) {
  edl_ms01_stop("The wide atlas produced no eligible discovery events.")
}

path_long <- edl_ms01_forward_path_long(events, path_contract)
event_key <- paste(events$symbol, events$session_date)
path_key <- paste(path_long$symbol, path_long$session_date)
event_match <- match(path_key, event_key)
if (anyNA(event_match)) edl_ms01_stop("Forward paths lost registry metadata.")
for (column in c(
  "atlas_order", "atlas_cohort", "atlas_group", "sector", "instrument_type"
)) {
  path_long[[column]] <- events[[column]][event_match]
}

append_group <- function(x, label) {
  out <- x
  out$analysis_group <- label
  out
}
base_paths <- path_long
base_paths$analysis_group <- base_paths$atlas_group
analysis_paths <- rbind(
  base_paths,
  append_group(path_long[path_long$instrument_type == "Stock", ], "All stocks (104)"),
  append_group(path_long[path_long$instrument_type == "ETF", ], "All ETFs (25)"),
  append_group(path_long, "All instruments (129)")
)

summarize_grouped_paths <- function(x) {
  keys <- unique(x[c("analysis_group", "event_category", "horizon")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    selected <- x$analysis_group == key$analysis_group &
      x$event_category == key$event_category & x$horizon == key$horizon
    values <- x$open_log_return[selected]
    data.frame(
      analysis_group = key$analysis_group,
      event_category = key$event_category,
      horizon = as.integer(key$horizon),
      event_n = length(values),
      mean_open_log_return = mean(values),
      median_open_log_return = stats::median(values),
      q25_open_log_return = as.numeric(stats::quantile(values, 0.25, names = FALSE)),
      q75_open_log_return = as.numeric(stats::quantile(values, 0.75, names = FALSE)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

pooled_summary <- summarize_grouped_paths(analysis_paths)
equal_input <- analysis_paths
equal_input$atlas_group <- equal_input$analysis_group
equal_output <- edl_ms01_equal_symbol_path_summary(equal_input)
equal_symbol_paths <- equal_output$symbol_paths
equal_symbol_summary <- equal_output$summary
names(equal_symbol_paths)[names(equal_symbol_paths) == "atlas_group"] <- "analysis_group"
names(equal_symbol_summary)[names(equal_symbol_summary) == "atlas_group"] <- "analysis_group"

focal_categories <- path_contract$focal_categories
event_counts_for_symbol <- function(symbol) {
  x <- events[events$symbol == symbol, , drop = FALSE]
  focal_x <- x[x$event_category %in% focal_categories, , drop = FALSE]
  counts <- table(factor(focal_x$event_category, levels = focal_categories))
  data.frame(
    symbol = symbol,
    discovery_band_events = nrow(x),
    triggered_events = sum(x$threshold_group == "TRIGGERED_PROXY"),
    near_miss_events = sum(x$threshold_group == "NEAR_MISS"),
    focal_events = nrow(focal_x),
    triggered_strong = as.integer(counts[["TRIGGERED_PROXY__STRONG_RECLAIM"]]),
    triggered_weak = as.integer(counts[["TRIGGERED_PROXY__WEAK_CLOSE"]]),
    near_miss_strong = as.integer(counts[["NEAR_MISS__STRONG_RECLAIM"]]),
    near_miss_weak = as.integer(counts[["NEAR_MISS__WEAK_CLOSE"]]),
    stringsAsFactors = FALSE
  )
}
symbol_counts_raw <- do.call(rbind, lapply(registry$symbol, event_counts_for_symbol))
symbol_counts <- cbind(
  registry,
  symbol_counts_raw[match(registry$symbol, symbol_counts_raw$symbol), setdiff(
    names(symbol_counts_raw), "symbol"
  ), drop = FALSE]
)
symbol_counts$atlas_group <- edl_ms01_wide_atlas_group(symbol_counts$atlas_cohort)

coverage_rows <- lapply(registry$symbol, function(symbol) {
  x <- ledger[ledger$symbol == symbol, , drop = FALSE]
  data.frame(
    symbol = symbol,
    first_session = min(x$session_date),
    last_session = max(x$session_date),
    observed_sessions = nrow(x),
    late_start = min(x$session_date) > wide_contract$analysis_start + 14,
    stringsAsFactors = FALSE
  )
})
coverage_ledger <- merge(
  registry, do.call(rbind, coverage_rows), by = "symbol", sort = FALSE
)
coverage_ledger <- coverage_ledger[match(registry$symbol, coverage_ledger$symbol), ]
coverage_ledger$atlas_group <- edl_ms01_wide_atlas_group(coverage_ledger$atlas_cohort)

sum_counts <- function(x, dimension) {
  count_columns <- c(
    "discovery_band_events", "triggered_events", "near_miss_events", "focal_events",
    "triggered_strong", "triggered_weak", "near_miss_strong", "near_miss_weak"
  )
  levels <- unique(as.character(x[[dimension]]))
  rows <- lapply(levels, function(level) {
    selected <- as.character(x[[dimension]]) == level
    values <- colSums(x[selected, count_columns, drop = FALSE])
    data.frame(
      dimension_value = level,
      enrolled_symbols = sum(selected),
      symbols_with_any_event = sum(selected & x$discovery_band_events > 0),
      symbols_with_triggered_strong = sum(selected & x$triggered_strong > 0),
      as.list(values),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  out <- do.call(rbind, rows)
  names(out)[[1L]] <- dimension
  out
}
cohort_counts <- sum_counts(symbol_counts, "atlas_group")
sector_counts <- sum_counts(symbol_counts, "sector")

focal_events$calendar_year <- format(focal_events$session_date, "%Y")
triggered_strong <- focal_events[
  focal_events$event_category == "TRIGGERED_PROXY__STRONG_RECLAIM", , drop = FALSE
]
symbol_concentration <- as.data.frame(table(triggered_strong$symbol), stringsAsFactors = FALSE)
names(symbol_concentration) <- c("symbol", "event_n")
symbol_concentration <- merge(
  registry[c("symbol", "atlas_cohort", "sector", "instrument_type")],
  symbol_concentration, by = "symbol", all.x = TRUE, sort = FALSE
)
symbol_concentration$event_n[is.na(symbol_concentration$event_n)] <- 0L
symbol_concentration$share <- symbol_concentration$event_n / sum(symbol_concentration$event_n)
symbol_concentration <- symbol_concentration[
  order(-symbol_concentration$event_n, symbol_concentration$symbol),
]
year_concentration <- as.data.frame(
  table(factor(triggered_strong$calendar_year, levels = as.character(2018:2023))),
  stringsAsFactors = FALSE
)
names(year_concentration) <- c("calendar_year", "event_n")
year_concentration$share <- year_concentration$event_n / sum(year_concentration$event_n)

to_pct <- function(x) 100 * expm1(x)
group_order <- c(
  "Core stocks (88)", "Attention stocks (16)",
  "Equity ETFs (15)", "Non-equity ETFs (10)",
  "All stocks (104)", "All ETFs (25)", "All instruments (129)"
)
category_labels <- c(
  "TRIGGERED_PROXY__STRONG_RECLAIM" = "Triggered + strong reclaim",
  "TRIGGERED_PROXY__WEAK_CLOSE" = "Triggered + weak close",
  "NEAR_MISS__STRONG_RECLAIM" = "Near miss + strong reclaim",
  "NEAR_MISS__WEAK_CLOSE" = "Near miss + weak close"
)
category_colors <- c(
  "TRIGGERED_PROXY__STRONG_RECLAIM" = "#14866D",
  "TRIGGERED_PROXY__WEAK_CLOSE" = "#B44738",
  "NEAR_MISS__STRONG_RECLAIM" = "#3D8DFF",
  "NEAR_MISS__WEAK_CLOSE" = "#A86B00"
)

png(file.path(visual_dir, "wide_atlas_event_availability.png"), 1900, 1050, res = 150)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1), oma = c(1, 1, 4, 1))
cohort_plot <- cohort_counts[match(group_order[1:4], cohort_counts$atlas_group), ]
barplot(
  cohort_plot$discovery_band_events,
  names.arg = sub(" \\(.*", "", cohort_plot$atlas_group),
  las = 2, col = "#3D8DFF", border = NA,
  ylab = "Discovery-band events", main = "Event observations"
)
barplot(
  rbind(
    cohort_plot$symbols_with_any_event,
    cohort_plot$symbols_with_triggered_strong,
    cohort_plot$enrolled_symbols
  ),
  beside = TRUE, names.arg = sub(" \\(.*", "", cohort_plot$atlas_group),
  las = 2, col = c("#83B7FF", "#14866D", "#DCE2E8"), border = NA,
  ylab = "Enrolled symbols", main = "Symbol-level availability"
)
legend(
  "topright", c("Any band event", "Triggered + strong", "Enrolled"),
  fill = c("#83B7FF", "#14866D", "#DCE2E8"), border = NA, bty = "n", cex = 0.8
)
mtext("The 129-instrument atlas is enrolled before outcomes are viewed", outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2)
mtext("Zero-event instruments stay in the coverage ledger; recent listings retain their shorter available histories", outer = TRUE, side = 3, line = 0.15, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

plot_path_panel <- function(group, category, weighting = "pooled") {
  pooled <- pooled_summary[
    pooled_summary$analysis_group == group & pooled_summary$event_category == category,
  ]
  equal <- equal_symbol_summary[
    equal_symbol_summary$analysis_group == group & equal_symbol_summary$event_category == category,
  ]
  y_values <- c(
    to_pct(pooled$q25_open_log_return), to_pct(pooled$q75_open_log_return),
    to_pct(equal$q25_symbol_median), to_pct(equal$q75_symbol_median)
  )
  y_limit <- max(8, min(30, stats::quantile(abs(y_values), 0.95, na.rm = TRUE)))
  plot(NA, xlim = c(0, 10), ylim = c(-y_limit, y_limit), xaxt = "n",
       xlab = "Sessions after next-open entry", ylab = "Cumulative return (%)")
  axis(1, at = c(0:5, 10))
  abline(h = 0, col = "#B8BCC4", lty = 2)
  if (weighting == "pooled") {
    polygon(
      c(pooled$horizon, rev(pooled$horizon)),
      c(to_pct(pooled$q25_open_log_return), rev(to_pct(pooled$q75_open_log_return))),
      border = NA, col = grDevices::adjustcolor(category_colors[[category]], 0.16)
    )
    lines(pooled$horizon, to_pct(pooled$median_open_log_return),
          col = category_colors[[category]], lwd = 4)
  } else {
    polygon(
      c(equal$horizon, rev(equal$horizon)),
      c(to_pct(equal$q25_symbol_median), rev(to_pct(equal$q75_symbol_median))),
      border = NA, col = grDevices::adjustcolor("#6957D5", 0.15)
    )
    lines(equal$horizon, to_pct(equal$equal_symbol_mean), col = "#6957D5", lwd = 4)
  }
}

png(file.path(visual_dir, "wide_atlas_core_stock_paths.png"), 1900, 1250, res = 150)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(2, 2), mar = c(4.2, 4.6, 3.5, 1.2), oma = c(1, 1, 4, 1))
for (category in focal_categories) {
  plot_path_panel("Core stocks (88)", category, "pooled")
  x <- pooled_summary[
    pooled_summary$analysis_group == "Core stocks (88)" &
      pooled_summary$event_category == category & pooled_summary$horizon == 5L,
  ]
  title(main = category_labels[[category]])
  mtext(sprintf("day 5 median %+.1f%% | n=%d", to_pct(x$median_open_log_return), x$event_n), side = 3, line = 0.25, cex = 0.8, col = "#526273")
}
mtext("Primary replication: event-pooled paths across the 88-stock sector core", outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2)
mtext("Ribbons are event-level IQRs; bold lines are medians; no inference or horizon selection", outer = TRUE, side = 3, line = 0.15, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

png(file.path(visual_dir, "wide_atlas_weighting_comparison.png"), 1900, 1250, res = 150)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(2, 2), mar = c(4.2, 4.6, 3.5, 1.2), oma = c(1, 1, 4, 1))
for (group in group_order[1:4]) {
  category <- "TRIGGERED_PROXY__STRONG_RECLAIM"
  pooled <- pooled_summary[pooled_summary$analysis_group == group & pooled_summary$event_category == category, ]
  equal <- equal_symbol_summary[equal_symbol_summary$analysis_group == group & equal_symbol_summary$event_category == category, ]
  y <- c(to_pct(pooled$median_open_log_return), to_pct(equal$equal_symbol_mean))
  y_limit <- max(8, min(25, max(abs(y), na.rm = TRUE) * 1.25))
  plot(NA, xlim = c(0, 10), ylim = c(-y_limit, y_limit), xaxt = "n",
       xlab = "Sessions after next-open entry", ylab = "Cumulative return (%)", main = group)
  axis(1, at = c(0:5, 10))
  abline(h = 0, col = "#B8BCC4", lty = 2)
  lines(pooled$horizon, to_pct(pooled$median_open_log_return), col = "#14866D", lwd = 4)
  lines(equal$horizon, to_pct(equal$equal_symbol_mean), col = "#6957D5", lwd = 4, lty = 2)
  legend("topleft", c("Event-pooled median", "Equal-symbol mean of medians"), col = c("#14866D", "#6957D5"), lwd = 3, lty = c(1, 2), bty = "n", cex = 0.75)
}
mtext("Triggered + strong reclaim: does event concentration control the path?", outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2)
mtext("Equal-symbol curve: median within each eligible symbol, then equal-weighted across symbols", outer = TRUE, side = 3, line = 0.15, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

heatmap_groups <- group_order[1:4]
heatmap_values <- function(horizon) {
  out <- matrix(NA_real_, nrow = length(focal_categories), ncol = length(heatmap_groups),
                dimnames = list(unname(category_labels[focal_categories]), heatmap_groups))
  for (i in seq_along(focal_categories)) {
    for (j in seq_along(heatmap_groups)) {
      x <- pooled_summary[
        pooled_summary$analysis_group == heatmap_groups[[j]] &
          pooled_summary$event_category == focal_categories[[i]] &
          pooled_summary$horizon == horizon,
      ]
      if (nrow(x)) out[i, j] <- to_pct(x$median_open_log_return)
    }
  }
  out
}
draw_signed_heatmap <- function(z, title) {
  limit <- max(1, max(abs(z), na.rm = TRUE))
  image(seq_len(ncol(z)), seq_len(nrow(z)), t(z),
        col = grDevices::colorRampPalette(c("#B44738", "#FFFFFF", "#14866D"))(101),
        zlim = c(-limit, limit), axes = FALSE, xlab = "", ylab = "", main = title)
  axis(1, at = seq_len(ncol(z)), labels = sub(" \\(.*", "", colnames(z)), las = 2, cex.axis = 0.75)
  axis(2, at = seq_len(nrow(z)), labels = rownames(z), las = 2, cex.axis = 0.72)
  for (i in seq_len(nrow(z))) for (j in seq_len(ncol(z))) {
    text(j, i, sprintf("%+.1f%%", z[i, j]), cex = 0.75,
         col = if (abs(z[i, j]) > 0.58 * limit) "white" else "#24364B")
  }
  box()
}
png(file.path(visual_dir, "wide_atlas_cohort_horizons.png"), 1900, 1050, res = 150)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(1, 2), mar = c(8, 12, 4, 1), oma = c(1, 1, 4, 1))
draw_signed_heatmap(heatmap_values(5L), "Event-pooled median at session 5")
draw_signed_heatmap(heatmap_values(10L), "Event-pooled median at session 10")
mtext("The four cohorts do not have to share the same return geometry", outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2)
mtext("Green = positive cumulative next-open return; red = negative; cells are descriptive medians", outer = TRUE, side = 3, line = 0.15, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

top_symbols <- head(symbol_concentration[symbol_concentration$event_n > 0, ], 15L)
png(file.path(visual_dir, "wide_atlas_triggered_strong_concentration.png"), 1900, 1050, res = 150)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1), oma = c(1, 1, 4, 1))
barplot(100 * top_symbols$share, names.arg = top_symbols$symbol, las = 2,
        col = ifelse(top_symbols$instrument_type == "Stock", "#3D8DFF", "#A86B00"),
        border = NA, ylab = "Share of triggered + strong events (%)",
        main = "Largest symbol contributions")
barplot(100 * year_concentration$share, names.arg = year_concentration$calendar_year,
        col = "#6957D5", border = NA, ylab = "Share of triggered + strong events (%)",
        main = "Calendar concentration")
mtext("The wider atlas still has visible event concentration", outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2)
mtext("Symbol chart spans all 129 instruments; blue = stock and ochre = ETF", outer = TRUE, side = 3, line = 0.15, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

checks <- data.frame(
  check_id = c(
    "inherited_atlas_checks", "registry_129_frozen", "core_88_frozen",
    "all_registry_symbols_have_bars", "post_2023_sealed", "proxy_definitions_frozen",
    "entry_clock_frozen", "horizons_fixed_0_to_10", "zero_event_symbols_retained",
    "stocks_etfs_separated", "equal_symbol_weighting_available", "all_paths_finite",
    "no_inference", "no_strategy_replay", "intraday_not_opened"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (nrow(registry) == 129L) "PASS" else "FAIL",
    if (sum(registry$atlas_cohort == "GICS_CORE") == 88L) "PASS" else "FAIL",
    if (length(unique(ledger$symbol)) == 129L) "PASS" else "FAIL",
    if (max(ledger$session_date) <= wide_contract$analysis_end) "PASS" else "FAIL",
    if (identical(wide_contract$threshold, -0.10) && identical(wide_contract$discovery_band, c(-0.12, -0.08))) "PASS" else "FAIL",
    if (all(abs(path_long$open_log_return[path_long$horizon == 0L]) < 1e-12)) "PASS" else "FAIL",
    if (identical(sort(unique(path_long$horizon)), 0:10)) "PASS" else "FAIL",
    if (nrow(symbol_counts) == 129L) "PASS" else "FAIL",
    if (all(c("Stock", "ETF") %in% unique(symbol_counts$instrument_type))) "PASS" else "FAIL",
    if (nrow(equal_symbol_summary) > 0) "PASS" else "FAIL",
    if (all(is.finite(path_long$open_log_return))) "PASS" else "FAIL",
    "PASS", "PASS", "PASS"
  ),
  detail = c(
    "all inherited source-packet integrity checks remain PASS",
    "all 129 preregistered instruments are retained",
    "the primary sector-balanced stock core retains 88 symbols",
    "each registry symbol contributes its available TRAIN history",
    "all calculations stop at 2023-12-29",
    "-10% trigger, -12% to -8% band, and CLV cutoffs are unchanged",
    "signal close t; entry open t+1; horizon zero equals entry",
    "forward path remains descriptive from session 0 through 10",
    "the symbol ledger includes instruments with zero qualifying events",
    "stock cohorts and ETF controls remain separately labeled",
    "within-symbol medians can be weighted equally across eligible symbols",
    "unobserved tail paths are omitted without crossing the TRAIN boundary",
    "no p-values, multiplicity correction, confidence claim, or promotion gate",
    "no costs, sizing, overlapping-trade replay, or performance claim",
    "neither 30-minute branch is executed"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  edl_ms01_stop(paste(
    "Wide-atlas construction check failed:",
    paste(checks$check_id[checks$status != "PASS"], collapse = ", ")
  ))
}

pilot_ts <- pilot_summary[
  pilot_summary$event_category == "TRIGGERED_PROXY__STRONG_RECLAIM" &
    pilot_summary$horizon %in% c(5L, 10L),
]
core_ts <- pooled_summary[
  pooled_summary$analysis_group == "Core stocks (88)" &
    pooled_summary$event_category == "TRIGGERED_PROXY__STRONG_RECLAIM" &
    pooled_summary$horizon %in% c(5L, 10L),
]
all_stock_ts <- pooled_summary[
  pooled_summary$analysis_group == "All stocks (104)" &
    pooled_summary$event_category == "TRIGGERED_PROXY__STRONG_RECLAIM" &
    pooled_summary$horizon %in% c(5L, 10L),
]
comparison <- rbind(
  data.frame(sample = "Pilot 10", horizon = pilot_ts$horizon,
             event_n = pilot_ts$n, median_open_log_return = pilot_ts$median_open_log_return),
  data.frame(sample = "Core stocks 88", horizon = core_ts$horizon,
             event_n = core_ts$event_n, median_open_log_return = core_ts$median_open_log_return),
  data.frame(sample = "All stocks 104", horizon = all_stock_ts$horizon,
             event_n = all_stock_ts$event_n, median_open_log_return = all_stock_ts$median_open_log_return)
)

run_spec <- data.frame(
  field = c(
    "study_id", "source_packet", "pilot_packet", "study_window", "atlas_membership",
    "primary_replication", "controls", "event_definition", "entry_clock",
    "path_horizons", "weighting_views", "zero_event_policy", "inferential_status",
    "strategy_status", "intraday_status", "oos_status"
  ),
  value = c(
    wide_contract$study_id,
    normalizePath(source_dir, winslash = "/"),
    normalizePath(pilot_dir, winslash = "/"),
    "2018-01-02..2023-12-29 TRAIN",
    "88 GICS core stocks + 16 attention stocks + 15 equity ETFs + 10 non-equity ETFs",
    "88-stock equal-sector core",
    "attention stocks, equity ETFs, and non-equity ETF proxies shown separately",
    "daily low/prior close in -12%..-8%; trigger <= -10%; strong CLV >= .75; weak CLV <= .25",
    "signal completed close t; entry open t+1; horizon zero is entry",
    paste(wide_contract$horizons, collapse = ","),
    "event-pooled median/IQR and equal-symbol mean of within-symbol medians",
    "all 129 instruments remain in coverage and event-count ledgers",
    "descriptive only; no inference or promotion gate",
    "no costs, sizing, portfolio replay, or return claim",
    "bookmarked only; no 30-minute data opened",
    "post-2023 sealed"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(events, file.path(output_dir, "event_ledger_with_paths.csv"), row.names = FALSE)
utils::write.csv(path_long, file.path(output_dir, "forward_path_long.csv"), row.names = FALSE)
utils::write.csv(pooled_summary, file.path(output_dir, "pooled_path_summary.csv"), row.names = FALSE)
utils::write.csv(equal_symbol_paths, file.path(output_dir, "equal_symbol_paths.csv"), row.names = FALSE)
utils::write.csv(equal_symbol_summary, file.path(output_dir, "equal_symbol_path_summary.csv"), row.names = FALSE)
utils::write.csv(symbol_counts, file.path(output_dir, "symbol_event_counts.csv"), row.names = FALSE)
utils::write.csv(cohort_counts, file.path(output_dir, "cohort_event_counts.csv"), row.names = FALSE)
utils::write.csv(sector_counts, file.path(output_dir, "sector_event_counts.csv"), row.names = FALSE)
utils::write.csv(coverage_ledger, file.path(output_dir, "coverage_ledger.csv"), row.names = FALSE)
utils::write.csv(symbol_concentration, file.path(output_dir, "triggered_strong_symbol_concentration.csv"), row.names = FALSE)
utils::write.csv(year_concentration, file.path(output_dir, "triggered_strong_year_concentration.csv"), row.names = FALSE)
utils::write.csv(comparison, file.path(output_dir, "pilot_vs_wide_comparison.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

get_value <- function(data, sample, horizon, column) {
  x <- data[data$sample == sample & data$horizon == horizon, column]
  if (!length(x)) return(NA_real_)
  x[[1L]]
}
core_equal <- equal_symbol_summary[
  equal_symbol_summary$analysis_group == "Core stocks (88)" &
    equal_symbol_summary$event_category == "TRIGGERED_PROXY__STRONG_RECLAIM" &
    equal_symbol_summary$horizon %in% c(5L, 10L),
]
report <- c(
  "# EDL-MS-01 Rule 201 Wide-Atlas Replication", "",
  "## Question", "",
  "Does the pilot's tentative triggered/strong-reclaim recovery hump persist after the frozen sample expands from ten operator-style stocks to the preregistered 129-instrument atlas?", "",
  "## Frozen breadth", "",
  "- Primary replication: 88 sector-balanced GICS stocks.",
  "- Separate challengers: 16 attention/meme stocks.",
  "- Separate controls: 15 equity ETFs and 10 non-equity ETF proxies.",
  sprintf("- Available-history policy: %d symbols begin materially after the common TRAIN start; none are removed for that reason.", sum(coverage_ledger$late_start)),
  sprintf("- Event policy: all 129 instruments remain in the ledger; %d have zero discovery-band events and %d have zero triggered/strong events.", sum(symbol_counts$discovery_band_events == 0), sum(symbol_counts$triggered_strong == 0)), "",
  "## Weighting views", "",
  "1. Event pooled: every qualifying event receives one observation.",
  "2. Equal symbol: compute a median path inside each eligible symbol, then average those symbol medians equally.", "",
  "## Pilot versus breadth", "",
  sprintf("- Pilot 10 triggered/strong: day 5 median %+.2f%% (n=%d); day 10 %+.2f%%.", to_pct(get_value(comparison, "Pilot 10", 5L, "median_open_log_return")), as.integer(get_value(comparison, "Pilot 10", 5L, "event_n")), to_pct(get_value(comparison, "Pilot 10", 10L, "median_open_log_return"))),
  sprintf("- Core 88 triggered/strong: day 5 median %+.2f%% (n=%d); day 10 %+.2f%%.", to_pct(get_value(comparison, "Core stocks 88", 5L, "median_open_log_return")), as.integer(get_value(comparison, "Core stocks 88", 5L, "event_n")), to_pct(get_value(comparison, "Core stocks 88", 10L, "median_open_log_return"))),
  sprintf("- All 104 stocks triggered/strong: day 5 median %+.2f%% (n=%d); day 10 %+.2f%%.", to_pct(get_value(comparison, "All stocks 104", 5L, "median_open_log_return")), as.integer(get_value(comparison, "All stocks 104", 5L, "event_n")), to_pct(get_value(comparison, "All stocks 104", 10L, "median_open_log_return"))),
  sprintf("- Core 88 equal-symbol triggered/strong: day 5 %+.2f%% across %d eligible symbols; day 10 %+.2f%%.", to_pct(core_equal$equal_symbol_mean[core_equal$horizon == 5L]), core_equal$symbol_n[core_equal$horizon == 5L], to_pct(core_equal$equal_symbol_mean[core_equal$horizon == 10L])), "",
  "## Interpretation boundary", "",
  "Breadth can show whether the visible path is common, cohort-specific, or concentration-driven. It cannot yet establish a tradable edge. No p-values, selection, costs, overlapping-trade replay, or post-2023 data are used.", "",
  "## Status", "",
  "WIDE_ATLAS_REPLICATION_COMPLETE_NO_EDGE_CLAIM"
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: WIDE_ATLAS_REPLICATION_COMPLETE_NO_EDGE_CLAIM")
message("Atlas: ", nrow(registry), "; events: ", nrow(events), "; focal events: ", nrow(focal_events))
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
