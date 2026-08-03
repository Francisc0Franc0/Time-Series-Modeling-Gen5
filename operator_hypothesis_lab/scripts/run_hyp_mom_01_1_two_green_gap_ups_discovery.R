options(stringsAsFactors = FALSE)

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "hyp_mom_01_1_two_green_gap_ups.R"
))

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
}

percent <- function(x, digits = 1L) {
  ifelse(
    is.finite(as.numeric(x)),
    paste0(formatC(100 * as.numeric(x), digits = digits, format = "f"), "%"),
    "NA"
  )
}

contract <- hyp_mom011_validate_contract(hyp_mom011_contract())
registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries",
  "hyp_mom_01_1_discovery_registry.csv"
)
source_bars_path <- Sys.getenv(
  "GEN5_HYP_MOM_01_1_SOURCE_BARS",
  unset = file.path(
    repo_root, "runs", "research_workbench", "literature_grounded",
    "lit_mom_01_1_stock_atlas_01_20260731",
    "stock_atlas_01_workbench_query_bars.csv"
  )
)
run_id <- Sys.getenv(
  "GEN5_HYP_MOM_01_1_RUN_ID",
  unset = "hyp_mom_01_1_two_green_gap_ups_discovery_20260803"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
hyp_mom011_validate_registry(registry)
if (!file.exists(source_bars_path)) stop("Discovery source bars are missing.", call. = FALSE)
bars_all <- utils::read.csv(source_bars_path, stringsAsFactors = FALSE)
bars_all$session_date <- as.Date(bars_all$session_date)

source_checks <- data.frame(
  check_id = c(
    "REGISTRY_22_STOCKS", "REGISTRY_ELEVEN_SECTORS", "SOURCE_SYMBOL_COVERAGE",
    "ALPACA_ADJUSTED_DAILY", "EXPLICIT_AS_OF_TIMESTAMP", "DISCOVERY_END_BOUND",
    "CONFIRMATION_EXCLUDED", "NO_DUPLICATE_BARS"
  ),
  passed = c(
    nrow(registry) == 22L,
    length(unique(registry$sector)) == 11L,
    all(c(registry$symbol, "SPY") %in% unique(bars_all$symbol)),
    all(bars_all$provider == "alpaca" & bars_all$adjusted %in% c(TRUE, "TRUE") & bars_all$timeframe == "1D"),
    all(nzchar(bars_all$as_of_timestamp)),
    max(bars_all$session_date) <= contract$discovery_end,
    all(bars_all$session_date < contract$confirmation_start),
    !anyDuplicated(bars_all[c("symbol", "session_date")])
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  stop(paste(
    "Discovery source integrity failed:",
    paste(source_checks$check_id[!source_checks$passed], collapse = ", ")
  ), call. = FALSE)
}

bars_all <- hyp_mom011_validate_bars(
  bars_all[bars_all$symbol %in% c(registry$symbol, "SPY"), , drop = FALSE],
  contract
)

candidate_rows <- trade_rows <- path_rows <- random_rows <- summary_rows <- list()
message("HYP-MOM-01.1 discovery starting: ", nrow(registry), " assets.")
for (i in seq_len(nrow(registry))) {
  reg <- registry[i, , drop = FALSE]
  symbol <- reg$symbol[[1L]]
  message(sprintf("[%02d/%02d] %s", i, nrow(registry), symbol))
  bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  analysis <- hyp_mom011_analyze_asset(bars, contract, seed_offset = i * 1000L)
  identity <- data.frame(
    instance_id = reg$instance_id,
    symbol = symbol,
    sector = reg$sector,
    stringsAsFactors = FALSE
  )
  add_identity <- function(x) {
    if (!nrow(x)) return(x)
    cbind(identity[rep(1L, nrow(x)), , drop = FALSE], x[, setdiff(names(x), "symbol"), drop = FALSE])
  }
  candidate_rows[[i]] <- add_identity(analysis$candidates)
  trade_rows[[i]] <- add_identity(analysis$trades)
  path_rows[[i]] <- add_identity(analysis$daily_path)
  random_rows[[i]] <- add_identity(analysis$random_returns)
  summary_rows[[i]] <- cbind(identity, analysis$summary[, setdiff(names(analysis$summary), "symbol"), drop = FALSE])
}

candidates <- do.call(rbind, candidate_rows)
trades <- do.call(rbind, trade_rows)
daily_paths <- do.call(rbind, path_rows)
random_controls <- do.call(rbind, random_rows)
asset_summary <- do.call(rbind, summary_rows)
rownames(candidates) <- rownames(trades) <- rownames(daily_paths) <-
  rownames(random_controls) <- rownames(asset_summary) <- NULL

trades$exit_year <- format(as.Date(trades$exit_date), "%Y")
yearly <- do.call(rbind, lapply(split(trades, trades$exit_year), function(x) {
  data.frame(
    year = unique(x$exit_year),
    trade_count = nrow(x),
    asset_count = length(unique(x$symbol)),
    mean_primary_trade_return = mean(x$primary_trade_return),
    median_primary_trade_return = stats::median(x$primary_trade_return),
    primary_hit_rate = mean(x$primary_trade_return > 0),
    stringsAsFactors = FALSE
  )
}))

pooled <- data.frame(
  hypothesis_id = contract$hypothesis_id,
  evidence_stage = contract$evidence_stage,
  asset_count = nrow(asset_summary),
  total_signal_count = sum(asset_summary$signal_count),
  executed_trade_count = nrow(trades),
  ignored_overlap_signal_count = sum(asset_summary$ignored_overlap_signal_count),
  mean_asset_primary_return = mean(asset_summary$primary_compounded_return),
  median_asset_primary_return = stats::median(asset_summary$primary_compounded_return),
  assets_positive_primary = sum(asset_summary$primary_compounded_return > 0),
  mean_primary_trade_return = mean(trades$primary_trade_return),
  median_primary_trade_return = stats::median(trades$primary_trade_return),
  primary_hit_rate = mean(trades$primary_trade_return > 0),
  mean_unconditional_h_return = mean(asset_summary$unconditional_h_mean_return),
  median_random_percentile = stats::median(asset_summary$observed_random_percentile),
  assets_random_percentile_above_80 = sum(asset_summary$observed_random_percentile >= 0.80),
  assets_beating_buy_hold = sum(asset_summary$excess_vs_buy_hold > 0),
  worst_asset_maximum_drawdown = min(asset_summary$maximum_drawdown),
  integrity_passed = all(source_checks$passed),
  confirmation_excluded = max(bars_all$session_date) < contract$confirmation_start,
  status = "DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY",
  stringsAsFactors = FALSE
)

robust_distance <- function(data, metrics) {
  x <- data[metrics]
  x[] <- lapply(x, as.numeric)
  center <- vapply(x, stats::median, numeric(1), na.rm = TRUE)
  scale <- vapply(x, stats::mad, numeric(1), na.rm = TRUE, constant = 1)
  scale[!is.finite(scale) | scale == 0] <- 1
  z <- sweep(as.matrix(x), 2, center, "-")
  z <- sweep(z, 2, scale, "/")
  rowSums(z^2)
}

pick_unique <- function(data, order_index, used) {
  eligible <- order_index[!data$symbol[order_index] %in% used]
  if (!length(eligible)) stop("No unique tape candidate remains.", call. = FALSE)
  data[eligible[[1L]], , drop = FALSE]
}

asset_tapes <- list()
used <- character()
medoid_order <- order(
  robust_distance(asset_summary, c(
    "primary_compounded_return", "excess_vs_buy_hold",
    "observed_random_percentile", "maximum_drawdown", "executed_trade_count"
  )), asset_summary$symbol
)
row <- pick_unique(asset_summary, medoid_order, used)
row$archetype <- "CROSS_SECTIONAL_MEDOID"; asset_tapes[[1L]] <- row; used <- c(used, row$symbol)
row <- pick_unique(asset_summary, order(-asset_summary$primary_compounded_return, asset_summary$symbol), used)
row$archetype <- "HIGHEST_PRIMARY_RETURN"; asset_tapes[[2L]] <- row; used <- c(used, row$symbol)
row <- pick_unique(asset_summary, order(asset_summary$primary_compounded_return, asset_summary$symbol), used)
row$archetype <- "LOWEST_PRIMARY_RETURN"; asset_tapes[[3L]] <- row; used <- c(used, row$symbol)
row <- pick_unique(asset_summary, order(-asset_summary$observed_random_percentile, asset_summary$symbol), used)
row$archetype <- "HIGHEST_RANDOM_PERCENTILE"; asset_tapes[[4L]] <- row; used <- c(used, row$symbol)
row <- pick_unique(asset_summary, order(-asset_summary$executed_trade_count, asset_summary$symbol), used)
row$archetype <- "HIGHEST_TRADE_COUNT"; asset_tapes[[5L]] <- row
asset_tape_manifest <- do.call(rbind, asset_tapes)
asset_tape_manifest$archetype_order <- seq_len(nrow(asset_tape_manifest))

trade_tapes <- list()
used_trades <- character()
pick_trade <- function(archetype, order_index) {
  eligible <- order_index[!trades$trade_id[order_index] %in% used_trades]
  row <- trades[eligible[[1L]], , drop = FALSE]
  row$archetype <- archetype
  used_trades <<- c(used_trades, row$trade_id)
  row
}
trade_tapes[[1L]] <- pick_trade("BEST_PRIMARY_TRADE", order(-trades$primary_trade_return, trades$trade_id))
trade_tapes[[2L]] <- pick_trade("WORST_PRIMARY_TRADE", order(trades$primary_trade_return, trades$trade_id))
median_return <- stats::median(trades$primary_trade_return)
trade_tapes[[3L]] <- pick_trade("POOLED_MEDIAN_TRADE", order(abs(trades$primary_trade_return - median_return), trades$trade_id))
reversal_score <- trades$maximum_favorable_excursion - trades$gross_trade_return
trade_tapes[[4L]] <- pick_trade("LARGEST_PEAK_TO_EXIT_GIVEBACK", order(-reversal_score, trades$trade_id))
recovery_score <- trades$gross_trade_return - trades$maximum_adverse_excursion
trade_tapes[[5L]] <- pick_trade("LARGEST_TROUGH_TO_EXIT_RECOVERY", order(-recovery_score, trades$trade_id))
trade_tape_manifest <- do.call(rbind, trade_tapes)
trade_tape_manifest$archetype_order <- seq_len(nrow(trade_tape_manifest))

# Asset comparison.
png(file.path(visual_dir, "asset_return_and_random_control.png"), 1800, 1200, res = 150)
par(mfrow = c(1, 2), mar = c(5, 8, 4, 2))
ordered <- asset_summary[order(asset_summary$primary_compounded_return), ]
y <- seq_len(nrow(ordered))
limits <- range(100 * c(ordered$primary_compounded_return, ordered$buy_hold_primary_return), finite = TRUE)
plot(100 * ordered$buy_hold_primary_return, y, pch = 1, col = "#718096", xlim = limits,
     yaxt = "n", ylab = "", xlab = "2021-2023 return (%)",
     main = "Signal path versus buy-and-hold")
points(100 * ordered$primary_compounded_return, y, pch = 19, col = "#2B6CB0")
segments(100 * ordered$buy_hold_primary_return, y, 100 * ordered$primary_compounded_return, y, col = "#CBD5E0")
axis(2, y, ordered$symbol, las = 1, tick = FALSE)
abline(v = 0, lty = 2, col = "#4A5568")
legend("bottomright", c("HYP-MOM-01.1", "Buy-and-hold"), pch = c(19, 1), col = c("#2B6CB0", "#718096"), bty = "n")
plot(100 * ordered$observed_random_percentile, y, pch = 19,
     col = ifelse(ordered$observed_random_percentile >= 0.8, "#2F855A", "#C53030"),
     xlim = c(0, 100), yaxt = "n", ylab = "", xlab = "Matched-random percentile (%)",
     main = "Timing versus 1,000 matched calendars")
axis(2, y, ordered$symbol, las = 1, tick = FALSE)
abline(v = c(50, 80), lty = c(2, 3), col = c("#718096", "#2F855A"))
mtext("DISCOVERY_REUSED_WINDOW | descriptive, not validation", outer = TRUE, side = 3, line = -1.5, cex = 0.9, col = "#718096")
dev.off()

# Trade distribution and gap-size relationship.
png(file.path(visual_dir, "trade_distribution_and_gap_relationship.png"), 1800, 1200, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
hist(100 * trades$primary_trade_return, breaks = "FD", col = "#BEE3F8", border = "white",
     xlab = "Primary-cost trade return (%)", main = "Executed five-session outcomes")
abline(v = 0, lty = 2, col = "#C53030")
abline(v = 100 * mean(trades$primary_trade_return), lwd = 2, col = "#2B6CB0")
gap_sum <- 100 * (trades$first_gap_return + trades$second_gap_return)
plot(gap_sum, 100 * trades$primary_trade_return, pch = 19,
     col = grDevices::adjustcolor("#2B6CB0", 0.55),
     xlab = "Sum of two opening gaps (%)", ylab = "Primary-cost trade return (%)",
     main = "Larger gaps are descriptive, not a filter")
abline(h = 0, lty = 2, col = "#C53030")
fit <- stats::lm(primary_trade_return ~ I(first_gap_return + second_gap_return), data = trades)
abline(fit, col = "#2F855A", lwd = 2)
dev.off()

# Calendar-year readout.
png(file.path(visual_dir, "calendar_year_trade_behavior.png"), 1600, 1050, res = 150)
par(mar = c(5, 5, 4, 5))
barplot(100 * yearly$mean_primary_trade_return, names.arg = yearly$year,
        col = ifelse(yearly$mean_primary_trade_return >= 0, "#2F855A", "#C53030"),
        ylab = "Mean primary trade return (%)", xlab = "Exit year",
        main = "The discovery rule must be read across market years")
abline(h = 0, col = "#1A202C")
par(new = TRUE)
plot(seq_along(yearly$year), 100 * yearly$primary_hit_rate, type = "b", pch = 19,
     axes = FALSE, xlab = "", ylab = "", col = "#2B6CB0", ylim = c(0, 100))
axis(4, col.axis = "#2B6CB0")
mtext("Hit rate (%)", side = 4, line = 3, col = "#2B6CB0")
dev.off()

plot_asset_tape <- function(row, file_path) {
  symbol <- row$symbol[[1L]]
  path <- daily_paths[daily_paths$symbol == symbol, , drop = FALSE]
  asset_trades <- trades[trades$symbol == symbol, , drop = FALSE]
  bars <- bars_all[
    bars_all$symbol == symbol & bars_all$session_date >= contract$discovery_start &
      bars_all$session_date <= contract$discovery_end,
    , drop = FALSE
  ]
  bh <- bars$close / bars$open[[1L]]
  png(file_path, 1800, 1000, res = 150)
  layout(matrix(1:2, ncol = 1), heights = c(3, 2))
  par(oma = c(1, 0.5, 4.5, 0.5), mar = c(1.5, 5, 2, 2))
  yrange <- range(c(path$strategy_wealth_close, bh), finite = TRUE)
  plot(path$session_date, bh, type = "l", col = "#718096", lwd = 2,
       ylim = yrange, xaxt = "n", xlab = "", ylab = "Normalized wealth",
       main = "Strategy path, holding blocks, and asset ownership")
  rect(as.numeric(asset_trades$entry_date), par("usr")[[3L]], as.numeric(asset_trades$exit_date),
       par("usr")[[4L]], col = grDevices::adjustcolor(ifelse(asset_trades$primary_trade_return > 0, "#2F855A", "#C53030"), 0.07), border = NA)
  lines(path$session_date, bh, col = "#718096", lwd = 2)
  lines(path$session_date, path$strategy_wealth_close, col = "#2B6CB0", lwd = 3)
  legend("topleft", c("HYP-MOM-01.1", "Buy-and-hold"), col = c("#2B6CB0", "#718096"), lwd = c(3, 2), bty = "n")
  par(mar = c(4.5, 5, 2, 2))
  values <- 100 * asset_trades$primary_trade_return
  plot(asset_trades$exit_date, values, type = "h", lwd = 2,
       col = ifelse(values > 0, "#2F855A", "#C53030"),
       xlab = "Exit date", ylab = "Trade return (%)", main = "Executed trade outcomes")
  points(asset_trades$exit_date, values, pch = 19,
         col = ifelse(values > 0, "#2F855A", "#C53030"))
  abline(h = 0, col = "#1A202C")
  title_text <- paste(row$archetype, "|", symbol, "|", row$sector)
  metric_text <- paste0(
    "trades ", row$executed_trade_count, " | strategy ", percent(row$primary_compounded_return),
    " | buy-hold ", percent(row$buy_hold_primary_return), " | random pct ",
    percent(row$observed_random_percentile, 0L), " | MDD ", percent(row$maximum_drawdown)
  )
  mtext(title_text, outer = TRUE, side = 3, line = 2.7, font = 2, cex = 1.3)
  mtext(metric_text, outer = TRUE, side = 3, line = 1.1, cex = 0.85)
  dev.off()
}

asset_tape_paths <- character(nrow(asset_tape_manifest))
for (i in seq_len(nrow(asset_tape_manifest))) {
  row <- asset_tape_manifest[i, , drop = FALSE]
  file_path <- file.path(visual_dir, sprintf(
    "asset_tape_%02d_%s_%s.png", i, tolower(row$archetype), tolower(row$symbol)
  ))
  plot_asset_tape(row, file_path)
  asset_tape_paths[[i]] <- normalizePath(file_path, winslash = "/", mustWork = FALSE)
}
asset_tape_manifest$visual_path <- asset_tape_paths

plot_trade_tape <- function(row, file_path) {
  symbol <- row$symbol[[1L]]
  bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  entry_pos <- match(as.Date(row$entry_date), bars$session_date)
  exit_pos <- match(as.Date(row$exit_date), bars$session_date)
  lo <- max(1L, entry_pos - 10L)
  hi <- min(nrow(bars), exit_pos + 5L)
  x <- bars[lo:hi, , drop = FALSE]
  idx <- seq_len(nrow(x))
  png(file_path, 1800, 900, res = 150)
  par(mar = c(7, 5, 5, 2))
  plot(idx, x$close, type = "n", xaxt = "n", xlab = "", ylab = "Adjusted price",
       main = paste(row$archetype, "|", row$trade_id, "| five-session causal trade"))
  abline(v = match(as.Date(c(row$first_pattern_date, row$signal_date)), x$session_date),
         col = "#90CDF4", lwd = 10)
  rect(match(as.Date(row$entry_date), x$session_date), par("usr")[[3L]],
       match(as.Date(row$exit_date), x$session_date), par("usr")[[4L]],
       col = grDevices::adjustcolor(ifelse(row$primary_trade_return > 0, "#2F855A", "#C53030"), 0.08), border = NA)
  segments(idx, x$low, idx, x$high, col = "#4A5568")
  candle_col <- ifelse(x$close >= x$open, "#2F855A", "#C53030")
  segments(idx, x$open, idx, x$close, col = candle_col, lwd = 6)
  points(match(as.Date(row$entry_date), x$session_date), row$entry_open, pch = 24, bg = "#2B6CB0", cex = 1.5)
  points(match(as.Date(row$exit_date), x$session_date), row$exit_open, pch = 25, bg = "#805AD5", cex = 1.5)
  axis(1, idx, format(x$session_date, "%Y-%m-%d"), las = 2, cex.axis = 0.75)
  legend("topleft", c("Pattern sessions", "Entry open", "Exit open"),
         pch = c(15, 24, 25), pt.bg = c("#90CDF4", "#2B6CB0", "#805AD5"),
         col = c("#90CDF4", "#2B6CB0", "#805AD5"), bty = "n")
  mtext(paste0(
    "primary ", percent(row$primary_trade_return), " | MFE ",
    percent(row$maximum_favorable_excursion), " | MAE ",
    percent(row$maximum_adverse_excursion), " | first-session ",
    percent(row$first_session_return)
  ), side = 3, line = 0.5, cex = 0.9, col = "#4A5568")
  dev.off()
}

trade_tape_paths <- character(nrow(trade_tape_manifest))
for (i in seq_len(nrow(trade_tape_manifest))) {
  row <- trade_tape_manifest[i, , drop = FALSE]
  file_path <- file.path(visual_dir, sprintf(
    "trade_tape_%02d_%s_%s.png", i, tolower(row$archetype), tolower(row$symbol)
  ))
  plot_trade_tape(row, file_path)
  trade_tape_paths[[i]] <- normalizePath(file_path, winslash = "/", mustWork = FALSE)
}
trade_tape_manifest$visual_path <- trade_tape_paths

run_spec <- data.frame(
  hypothesis_id = contract$hypothesis_id,
  descriptive_name = contract$descriptive_name,
  evidence_stage = contract$evidence_stage,
  as_of_timestamp = contract$as_of_timestamp,
  discovery_start = as.character(contract$discovery_start),
  discovery_end = as.character(contract$discovery_end),
  confirmation_start = as.character(contract$confirmation_start),
  holding_sessions = contract$holding_sessions,
  primary_cost_bps = contract$primary_cost_bps,
  stress_cost_bps = contract$stress_cost_bps,
  random_simulations = contract$random_simulations,
  source_bars_path = normalizePath(source_bars_path, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "hyp_mom_01_1_run_spec.csv"))
write_csv(source_checks, file.path(output_dir, "hyp_mom_01_1_integrity.csv"))
write_csv(registry, file.path(output_dir, "hyp_mom_01_1_registry.csv"))
write_csv(pooled, file.path(output_dir, "hyp_mom_01_1_pooled_summary.csv"))
write_csv(asset_summary, file.path(output_dir, "hyp_mom_01_1_asset_summary.csv"))
write_csv(yearly, file.path(output_dir, "hyp_mom_01_1_calendar_years.csv"))
write_csv(candidates, file.path(output_dir, "hyp_mom_01_1_signal_candidates.csv"))
write_csv(trades, file.path(output_dir, "hyp_mom_01_1_executed_trades.csv"))
write_csv(daily_paths, file.path(output_dir, "hyp_mom_01_1_daily_paths.csv"))
write_csv(random_controls, file.path(output_dir, "hyp_mom_01_1_random_controls.csv"))
write_csv(asset_tape_manifest, file.path(output_dir, "hyp_mom_01_1_asset_tape_manifest.csv"))
write_csv(trade_tape_manifest, file.path(output_dir, "hyp_mom_01_1_trade_tape_manifest.csv"))

report <- c(
  "# HYP-MOM-01.1 Two Consecutive Green Gap-Ups Discovery",
  "",
  "Status: `DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`.",
  "",
  paste0("Evidence stage: `", contract$evidence_stage, "`."),
  "",
  "## Frozen mechanics",
  "",
  "Two consecutive sessions must each gap above the prior close and finish green. The second candle is observed after close; entry is next open and exit is five open-to-open intervals later. Positions are long-only, fully compounded, and non-overlapping within each asset.",
  "",
  "## Descriptive readout",
  "",
  paste0("- Assets: ", pooled$asset_count, "."),
  paste0("- Signals / executed / ignored overlap: ", pooled$total_signal_count, " / ", pooled$executed_trade_count, " / ", pooled$ignored_overlap_signal_count, "."),
  paste0("- Positive primary-cost asset paths: ", pooled$assets_positive_primary, " / ", pooled$asset_count, "."),
  paste0("- Median asset primary return: ", percent(pooled$median_asset_primary_return), "."),
  paste0("- Mean primary trade return: ", percent(pooled$mean_primary_trade_return), "; hit rate: ", percent(pooled$primary_hit_rate), "."),
  paste0("- Assets beating buy-and-hold: ", pooled$assets_beating_buy_hold, " / ", pooled$asset_count, "."),
  paste0("- Median matched-random percentile: ", percent(pooled$median_random_percentile, 0L), "."),
  paste0("- Worst asset maximum drawdown: ", percent(pooled$worst_asset_maximum_drawdown), "."),
  "",
  "## Boundary",
  "",
  "This is a reused-window discovery exercise. It can generate questions about exits, gap magnitude, trend context, or failure behavior, but it cannot nominate a filter, asset, portfolio, or validated strategy. Confirmation from 2024 onward remains excluded."
)
writeLines(report, file.path(output_dir, "hyp_mom_01_1_report.md"), useBytes = TRUE)

message("HYP-MOM-01.1 discovery complete: ", normalizePath(output_dir, winslash = "/"))
print(pooled)
