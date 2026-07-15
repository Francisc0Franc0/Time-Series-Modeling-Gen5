repo_root <- normalizePath(".", winslash = "/")
wfa_root <- file.path(repo_root, "runs", "research_workbench", "wfa_pocs")
out <- file.path(repo_root, "runs", "research_workbench", "meta_label_candidate_atlas", "ms_p0_candidate_atlas_2020_2024")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

family_codes <- c(et = "ema_trend", ec = "ema_cross", bt = "bollinger_touch", bm = "bollinger_mid_reversion", rs = "rsi_mr", zr = "zret_mr", br = "breakout", pb = "pullback_in_uptrend")
families <- unname(family_codes)
years <- 2020:2024

empty_catalog <- function() data.frame(
  family = character(), oos_window = integer(), root = character(), state_map_dir = character(),
  asset_summary_csv = character(), available = logical(), stringsAsFactors = FALSE
)
catalog <- empty_catalog()

add_row <- function(family, year, root, state_dir) {
  summary <- list.files(root, "_asset_summary\\.csv$", recursive = FALSE, full.names = TRUE)
  data.frame(
    family = family, oos_window = year, root = normalizePath(root, winslash = "/", mustWork = FALSE),
    state_map_dir = normalizePath(state_dir, winslash = "/", mustWork = FALSE),
    asset_summary_csv = if (length(summary)) normalizePath(summary[[1L]], winslash = "/") else NA_character_,
    available = dir.exists(state_dir) && length(summary) > 0L,
    stringsAsFactors = FALSE
  )
}

roots <- list.dirs(wfa_root, recursive = FALSE, full.names = TRUE)
for (root in roots) {
  tag <- regmatches(basename(root), regexec("^m2([a-z]{2})([0-9]{2})$", basename(root)))[[1L]]
  if (length(tag) != 3L || !tag[[2L]] %in% names(family_codes)) next
  year <- 2000L + as.integer(tag[[3L]])
  expected <- paste0("m2", tag[[2L]], tag[[3L]])
  if (!identical(basename(root), expected)) next
  catalog <- rbind(catalog, add_row(family_codes[[tag[[2L]]]], year, root, file.path(root, "ms_p0_candidate_state_map")))
}
catalog <- catalog[order(match(catalog$family, families), catalog$oos_window), ]
write.csv(catalog, file.path(out, "ms_p0_candidate_atlas_run_catalog.csv"), row.names = FALSE)

available <- catalog[catalog$available, , drop = FALSE]
if (!nrow(available)) stop("No completed MS-P0 candidate state-map packets found.", call. = FALSE)

state_daily <- list(); asset_rows <- list(); paths <- list()
for (i in seq_len(nrow(available))) {
  row <- available[i, ]
  daily_path <- file.path(row$state_map_dir, "ms_p0_oos_state_daily.csv")
  daily <- read.csv(daily_path, stringsAsFactors = FALSE)
  daily$family <- row$family; daily$oos_window <- row$oos_window
  state_daily[[length(state_daily) + 1L]] <- daily

  asset <- read.csv(row$asset_summary_csv, stringsAsFactors = FALSE)
  asset$family <- row$family; asset$oos_window <- row$oos_window
  asset$total_return_excess <- asset$total_return - asset$buy_hold_total_return
  asset_rows[[length(asset_rows) + 1L]] <- asset
  paths[[length(paths) + 1L]] <- asset[, c("family", "oos_window", "symbol", "strategy_chart_png", "equity_curve_png")]
}
state_daily <- do.call(rbind, state_daily)
asset_rows <- do.call(rbind, asset_rows)
paths <- do.call(rbind, paths)
write.csv(state_daily, file.path(out, "ms_p0_candidate_atlas_state_daily.csv"), row.names = FALSE)
write.csv(asset_rows, file.path(out, "ms_p0_candidate_atlas_asset_summary.csv"), row.names = FALSE)
write.csv(paths, file.path(out, "ms_p0_candidate_atlas_trade_tape_index.csv"), row.names = FALSE)

state_key <- interaction(state_daily$family, state_daily$oos_window, state_daily$state_id, drop = TRUE)
state_summary <- aggregate(
  state_daily[, c("daily_excess", "daily_return", "buy_hold_daily_return", "in_position")],
  list(key = state_key), mean, na.rm = TRUE
)
counts <- aggregate(state_daily$daily_excess, list(key = state_key), function(x) sum(is.finite(x)))
labels <- do.call(rbind, strsplit(as.character(state_summary$key), "\\."))
state_summary$family <- labels[, 1L]
state_summary$oos_window <- as.integer(labels[, 2L])
state_summary$state_id <- labels[, 3L]
state_summary$n_days <- counts$x[match(state_summary$key, counts$key)]
names(state_summary)[2:5] <- c("mean_daily_excess", "mean_strategy_return", "mean_hold_return", "mean_exposure")
state_summary$key <- NULL
state_summary <- state_summary[, c("family", "oos_window", "state_id", "n_days", "mean_daily_excess", "mean_strategy_return", "mean_hold_return", "mean_exposure")]
write.csv(state_summary, file.path(out, "ms_p0_candidate_atlas_state_summary.csv"), row.names = FALSE)

window_summary <- aggregate(
  asset_rows[, c("total_return", "buy_hold_total_return", "total_return_excess", "sharpe", "buy_hold_sharpe", "trade_count", "max_drawdown")],
  list(family = asset_rows$family, oos_window = asset_rows$oos_window), mean, na.rm = TRUE
)
names(window_summary)[3:ncol(window_summary)] <- paste0("mean_", names(window_summary)[3:ncol(window_summary)])
write.csv(window_summary, file.path(out, "ms_p0_candidate_atlas_window_summary.csv"), row.names = FALSE)

family_summary <- aggregate(
  window_summary[, c("mean_total_return", "mean_buy_hold_total_return", "mean_total_return_excess", "mean_sharpe", "mean_buy_hold_sharpe", "mean_trade_count", "mean_max_drawdown")],
  list(family = window_summary$family), mean, na.rm = TRUE
)
family_summary <- family_summary[match(families, family_summary$family), ]
write.csv(family_summary, file.path(out, "ms_p0_candidate_atlas_family_summary.csv"), row.names = FALSE)

family_state <- aggregate(
  state_daily[, c("daily_excess", "in_position")],
  list(family = state_daily$family, state_id = state_daily$state_id), mean, na.rm = TRUE
)
names(family_state)[3:4] <- c("mean_daily_excess", "mean_exposure")
family_state <- family_state[order(match(family_state$family, families), family_state$state_id), ]
write.csv(family_state, file.path(out, "ms_p0_candidate_atlas_family_state_summary.csv"), row.names = FALSE)

heatmap_matrix <- function(df, value, title, file, digits = 4L, palette = c("#B91C1C", "#FFFFFF", "#15803D")) {
  matrix <- matrix(NA_real_, nrow = length(families), ncol = 4L, dimnames = list(families, c("trend_confirmed__vol_elevated", "trend_confirmed__vol_quiet", "trend_weak__vol_elevated", "trend_weak__vol_quiet")))
  for (i in seq_len(nrow(df))) matrix[df$family[[i]], df$state_id[[i]]] <- df[[value]][[i]]
  lim <- max(abs(matrix), na.rm = TRUE); lim <- ifelse(is.finite(lim) && lim > 0, lim, 1)
  cols <- colorRampPalette(palette)(101L)
  z <- matrix(pmax(1L, pmin(101L, round((matrix + lim) / (2 * lim) * 100) + 1L)), nrow = nrow(matrix), ncol = ncol(matrix), dimnames = dimnames(matrix))
  png(file, width = 3000, height = 1800, res = 220)
  par(mar = c(10, 13, 5, 2))
  state_labels <- c("Trend+ / vol high", "Trend+ / vol quiet", "Trend weak / vol high", "Trend weak / vol quiet")
  image(seq_len(ncol(matrix)), seq_len(nrow(matrix)), t(z[nrow(matrix):1L, , drop = FALSE]), col = cols, axes = FALSE, xlab = "", ylab = "", main = title)
  axis(1, at = seq_len(ncol(matrix)), labels = state_labels, las = 2, cex.axis = 0.86)
  axis(2, at = seq_len(nrow(matrix)), labels = rev(rownames(matrix)), las = 2, cex.axis = 1.0)
  for (r in seq_len(nrow(matrix))) for (c in seq_len(ncol(matrix))) text(c, nrow(matrix) - r + 1L, labels = ifelse(is.finite(matrix[r, c]), formatC(matrix[r, c], digits = digits, format = "f"), "NA"), cex = 0.95)
  dev.off()
}

heatmap_matrix(family_state, "mean_daily_excess", "MS-P0: raw strategy minus hold by TRAIN-frozen state", file.path(out, "ms_p0_family_state_excess_heatmap.png"), digits = 5L)
heatmap_matrix(family_state, "mean_exposure", "MS-P0: raw long exposure by TRAIN-frozen state", file.path(out, "ms_p0_family_state_exposure_heatmap.png"), digits = 3L, palette = c("#EFF6FF", "#BFDBFE", "#1D4ED8"))

png(file.path(out, "ms_p0_family_window_total_return_excess.png"), width = 3000, height = 1800, res = 220)
mat <- matrix(NA_real_, nrow = length(families), ncol = length(years), dimnames = list(families, as.character(years)))
for (i in seq_len(nrow(window_summary))) mat[window_summary$family[[i]], as.character(window_summary$oos_window[[i]])] <- window_summary$mean_total_return_excess[[i]]
lim <- max(abs(mat), na.rm = TRUE); cols <- colorRampPalette(c("#B91C1C", "#FFFFFF", "#15803D"))(101L); z <- matrix(pmax(1L, pmin(101L, round((mat + lim) / (2 * lim) * 100) + 1L)), nrow = nrow(mat), ncol = ncol(mat), dimnames = dimnames(mat))
par(mar = c(7, 13, 5, 2)); image(seq_len(ncol(mat)), seq_len(nrow(mat)), t(z[nrow(mat):1L, , drop = FALSE]), col = cols, axes = FALSE, xlab = "", ylab = "", main = "MS-P0: mean strategy minus hold total return by annual window")
axis(1, at = seq_len(ncol(mat)), labels = colnames(mat), cex.axis = 1.1); axis(2, at = seq_len(nrow(mat)), labels = rev(rownames(mat)), las = 2, cex.axis = 1.0)
for (r in seq_len(nrow(mat))) for (c in seq_len(ncol(mat))) text(c, nrow(mat) - r + 1L, labels = ifelse(is.finite(mat[r, c]), sprintf("%+.1f%%", 100 * mat[r, c]), "NA"), cex = 1.0)
dev.off()

readme <- c(
  "# MS-P0 Candidate Atlas", "",
  "Raw, independently selected candidate-family diagnostics. Each named window uses eight quarters of TRAIN and four fixed 91-day OOS folds; state thresholds are fold-local TRAIN medians.",
  "", "This packet is an inspection surface only. It does not fit a meta-label, select a live policy, or establish allocation evidence.",
  "", paste0("Completed packets: ", nrow(available), " of ", length(families) * length(years), ".")
)
writeLines(readme, file.path(out, "ms_p0_candidate_atlas_report.md"))
message("MS-P0 candidate atlas: ", normalizePath(out, winslash = "/"))
