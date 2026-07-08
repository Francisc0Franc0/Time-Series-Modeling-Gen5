repo_root <- normalizePath(file.path(getwd()), winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "R", "data_contract.R"))

audit_theme <- function() {
  list(
    background = "#FAF7F0",
    panel_background = "#FFFFFF",
    text = "#172033",
    muted_text = "#5F6673",
    axis = "#8A8F99",
    trade_win_line = "#1B9E77",
    trade_loss_line = "#D95F5F"
  )
}

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) default else value
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) g5_stop(paste0("Missing required audit input: ", path))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

parse_date <- function(x) {
  as.Date(sub("T.*$", "", as.character(x)))
}

num <- function(x) suppressWarnings(as.numeric(x))

pct_label <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.1f%%", 100 * x))
}

pp_label <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%+.1f pp", 100 * x))
}

compound_return <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(0)
  prod(1 + x) - 1
}

family_from_gen5_spec <- function(spec) {
  spec <- as.character(spec)
  out <- rep(NA_character_, length(spec))
  out[grepl("bollinger|bb_touch", spec)] <- "bb_touch"
  out[grepl("ema_cross", spec)] <- "ema_cross"
  out[grepl("ema_trend", spec)] <- "ema_trend"
  out[grepl("pullback", spec)] <- "pullback"
  out[grepl("rsi", spec)] <- "rsi"
  out[grepl("zret", spec)] <- "zret"
  out[grepl("breakout|volatility", spec)] <- "breakout"
  out[grepl("no_trade", spec)] <- "no_trade"
  out[is.na(out)] <- "other"
  out
}

normalize_lane <- function(x) {
  x <- as.character(x)
  x[x == "asset_state_direct_spec"] <- "Gen5.2 direct"
  x[x == "pooled_family_asset_variant"] <- "Gen5.2 pooled"
  x
}

calibration_dir <- normalizePath(env_or(
  "GEN5_GEN4_AUDIT_CALIBRATION_DIR",
  file.path(repo_root, "runs", "research_workbench", "gen4_equivalence", "gen4_equivalence_gen52calfull162024q420260707")
), winslash = "/", mustWork = TRUE)

gen4_root <- normalizePath(env_or(
  "GEN5_GEN4_AUDIT_GEN4_ROOT",
  "C:/Users/Franc/OneDrive/Documents/Francis/Peltata Project/Time-Series-Modeling/Experiments/FM-002-024-R3_med_16_bins"
), winslash = "/", mustWork = TRUE)

phase40_dir <- file.path(gen4_root, "Phase40_WFA_Quarterly_Validation")
out_dir <- file.path(calibration_dir, "trade_tape_audit")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

start_date <- as.Date(env_or("GEN5_GEN4_AUDIT_START_DATE", "2024-10-01"))
end_date <- as.Date(env_or("GEN5_GEN4_AUDIT_END_DATE", "2024-12-31"))
target_cluster <- env_or("GEN5_GEN4_AUDIT_CLUSTER_ID", "3")

cluster_map <- read_csv_safe(file.path(gen4_root, "asset_cluster_map.csv"))
run_spec <- read_csv_safe(file.path(calibration_dir, "gen4_equivalence_run_spec.csv"))
run_symbols <- trimws(strsplit(as.character(run_spec$symbols[[1L]]), ",", fixed = TRUE)[[1L]])
cluster_symbols <- intersect(as.character(cluster_map$asset[as.character(cluster_map$cluster_id) == target_cluster]), run_symbols)

replay <- read_csv_safe(file.path(calibration_dir, "gen4_equivalence_replay_oos.csv"))
replay$session_date <- as.Date(replay$session_date)
replay <- replay[replay$session_date >= start_date & replay$session_date <= end_date, , drop = FALSE]
replay <- replay[as.character(replay$symbol) %in% cluster_symbols, , drop = FALSE]
replay$lane <- normalize_lane(replay$selection_policy)
replay$is_long <- as.character(replay$model_position_after_replay) == "LONG"

gen5_trades <- read_csv_safe(file.path(calibration_dir, "gen4_equivalence_trades.csv"))
gen5_trades$entry_date <- as.Date(gen5_trades$entry_execution_date)
gen5_trades$exit_date <- as.Date(ifelse(is.na(gen5_trades$trace_end_date) | !nzchar(as.character(gen5_trades$trace_end_date)), as.character(gen5_trades$exit_execution_date), as.character(gen5_trades$trace_end_date)))
gen5_trades <- gen5_trades[gen5_trades$entry_date >= start_date & gen5_trades$entry_date <= end_date, , drop = FALSE]
gen5_trades <- gen5_trades[as.character(gen5_trades$symbol) %in% cluster_symbols, , drop = FALSE]
gen5_trades$lane <- normalize_lane(gen5_trades$selection_policy)
gen5_trades$ret <- num(gen5_trades$trace_end_price) / num(gen5_trades$entry_execution_price) - 1
gen5_trades$bars_held <- as.integer(gen5_trades$exit_date - gen5_trades$entry_date) + 1L
gen5_trades$family <- family_from_gen5_spec(gen5_trades$strategy_spec_id)

gen4_trades <- read_csv_safe(file.path(phase40_dir, "phase40_picked_trade_tape.csv"))
gen4_trades$entry_date <- parse_date(gen4_trades$entry_time)
gen4_trades$exit_date <- parse_date(gen4_trades$exit_time)
gen4_trades <- gen4_trades[gen4_trades$entry_date >= start_date & gen4_trades$entry_date <= end_date, , drop = FALSE]
gen4_trades <- gen4_trades[as.character(gen4_trades$asset) %in% cluster_symbols, , drop = FALSE]
gen4_trades$symbol <- as.character(gen4_trades$asset)
gen4_trades$lane <- "Gen4 artifact"
gen4_trades$ret <- num(gen4_trades$trade_ret)
gen4_trades$bars_held <- as.integer(num(gen4_trades$bars_held))
gen4_trades$family <- as.character(gen4_trades$family)

gen4_equity <- read_csv_safe(file.path(phase40_dir, "phase40_live_asset_oos_equity.csv"))
gen4_equity$session_date <- parse_date(gen4_equity$datetime)
gen4_equity <- gen4_equity[gen4_equity$session_date >= start_date & gen4_equity$session_date <= end_date, , drop = FALSE]
gen4_equity <- gen4_equity[as.character(gen4_equity$asset) %in% cluster_symbols, , drop = FALSE]

trading_days <- sort(unique(replay$session_date))
day_count <- length(trading_days)

gen5_symbol <- do.call(rbind, lapply(split(replay, paste(replay$lane, replay$symbol, sep = "::")), function(x) {
  x <- x[order(x$session_date), , drop = FALSE]
  close <- num(x$close)
  daily_ret <- c(0, close[-1] / close[-length(close)] - 1)
  pos_lag <- c(FALSE, head(as.logical(x$is_long), -1L))
  data.frame(
    lane = as.character(x$lane[[1L]]),
    symbol = as.character(x$symbol[[1L]]),
    exposure = mean(as.logical(x$is_long), na.rm = TRUE),
    strategy_return = compound_return(ifelse(pos_lag, daily_ret, 0)),
    hold_return = if (length(close) > 1L) tail(close, 1L) / close[[1L]] - 1 else NA_real_,
    trade_count = sum(as.character(x$execution_status) == "ENTER_EXECUTED_AT_OPEN", na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

gen4_symbol <- do.call(rbind, lapply(cluster_symbols, function(symbol) {
  x <- gen4_trades[as.character(gen4_trades$symbol) == symbol, , drop = FALSE]
  eq <- gen4_equity[as.character(gen4_equity$asset) == symbol, , drop = FALSE]
  eq <- eq[order(eq$session_date), , drop = FALSE]
  data.frame(
    lane = "Gen4 artifact",
    symbol = symbol,
    exposure = sum(num(x$bars_held), na.rm = TRUE) / day_count,
    strategy_return = if (nrow(eq)) tail(num(eq$eq_oos_stitched), 1L) / num(eq$eq_oos_stitched[[1L]]) - 1 else compound_return(num(x$ret)),
    hold_return = if (nrow(eq)) tail(num(eq$eq_benchmark_stitched), 1L) / num(eq$eq_benchmark_stitched[[1L]]) - 1 else NA_real_,
    trade_count = nrow(x),
    stringsAsFactors = FALSE
  )
}))

symbol_summary <- rbind(gen4_symbol, gen5_symbol)
symbol_summary$alpha_vs_hold <- symbol_summary$strategy_return - symbol_summary$hold_return

trade_summary <- do.call(rbind, lapply(split(rbind(
  gen4_trades[, c("lane", "symbol", "entry_date", "exit_date", "ret", "bars_held", "family"), drop = FALSE],
  gen5_trades[, c("lane", "symbol", "entry_date", "exit_date", "ret", "bars_held", "family"), drop = FALSE]
), paste(rbind(
  gen4_trades[, c("lane", "symbol"), drop = FALSE],
  gen5_trades[, c("lane", "symbol"), drop = FALSE]
)$lane, rbind(
  gen4_trades[, c("lane", "symbol"), drop = FALSE],
  gen5_trades[, c("lane", "symbol"), drop = FALSE]
)$symbol, sep = "::")), function(x) {
  data.frame(
    lane = as.character(x$lane[[1L]]),
    symbol = as.character(x$symbol[[1L]]),
    trade_count = nrow(x),
    win_count = sum(num(x$ret) > 0, na.rm = TRUE),
    loss_count = sum(num(x$ret) <= 0, na.rm = TRUE),
    mean_trade_return = mean(num(x$ret), na.rm = TRUE),
    median_bars_held = stats::median(num(x$bars_held), na.rm = TRUE),
    compound_trade_return = compound_return(num(x$ret)),
    stringsAsFactors = FALSE
  )
}))

lane_summary <- do.call(rbind, lapply(split(symbol_summary, symbol_summary$lane), function(x) {
  t <- rbind(
    gen4_trades[, c("lane", "symbol", "entry_date", "exit_date", "ret", "bars_held", "family"), drop = FALSE],
    gen5_trades[, c("lane", "symbol", "entry_date", "exit_date", "ret", "bars_held", "family"), drop = FALSE]
  )
  t <- t[as.character(t$lane) == as.character(x$lane[[1L]]), , drop = FALSE]
  data.frame(
    lane = as.character(x$lane[[1L]]),
    symbols = paste(sort(unique(as.character(x$symbol))), collapse = ","),
    mean_exposure = mean(num(x$exposure), na.rm = TRUE),
    mean_symbol_strategy_return = mean(num(x$strategy_return), na.rm = TRUE),
    mean_symbol_hold_return = mean(num(x$hold_return), na.rm = TRUE),
    mean_alpha_vs_hold = mean(num(x$alpha_vs_hold), na.rm = TRUE),
    total_trades = nrow(t),
    wins = sum(num(t$ret) > 0, na.rm = TRUE),
    losses = sum(num(t$ret) <= 0, na.rm = TRUE),
    median_bars_held = stats::median(num(t$bars_held), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

all_trades <- rbind(
  gen4_trades[, c("lane", "symbol", "entry_date", "exit_date", "ret", "bars_held", "family"), drop = FALSE],
  gen5_trades[, c("lane", "symbol", "entry_date", "exit_date", "ret", "bars_held", "family"), drop = FALSE]
)

family_counts <- as.data.frame(table(lane = all_trades$lane, family = all_trades$family), stringsAsFactors = FALSE)
family_counts <- family_counts[family_counts$Freq > 0, , drop = FALSE]
names(family_counts)[names(family_counts) == "Freq"] <- "trade_count"

write.csv(symbol_summary, file.path(out_dir, "cluster3_symbol_participation_summary.csv"), row.names = FALSE)
write.csv(trade_summary, file.path(out_dir, "cluster3_trade_summary.csv"), row.names = FALSE)
write.csv(lane_summary, file.path(out_dir, "cluster3_lane_summary.csv"), row.names = FALSE)
write.csv(all_trades, file.path(out_dir, "cluster3_combined_trade_tape.csv"), row.names = FALSE)
write.csv(family_counts, file.path(out_dir, "cluster3_family_counts.csv"), row.names = FALSE)

aesthetic <- audit_theme()
lanes <- c("Gen4 artifact", "Gen5.2 direct", "Gen5.2 pooled")
lane_cols <- c("Gen4 artifact" = "#111111", "Gen5.2 direct" = "#2E86AB", "Gen5.2 pooled" = "#9B5DE5")
symbols <- sort(unique(as.character(symbol_summary$symbol)))

png_file <- function(path, width = 2200L, height = 1350L, res = 190L) {
  grDevices::png(path, width = width, height = height, res = res)
  par(bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text)
}

png_file(file.path(out_dir, "cluster3_exposure_heatmap.png"))
oldpar <- par(no.readonly = TRUE)
par(mar = c(7, 9, 4, 2))
plot(NA, xlim = c(0.5, length(lanes) + 0.5), ylim = c(0.5, length(symbols) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Cluster 3 Exposure By Lane", col.main = aesthetic$text)
rect(0.5, 0.5, length(lanes) + 0.5, length(symbols) + 0.5, col = aesthetic$panel_background, border = NA)
for (i in seq_len(nrow(symbol_summary))) {
  x <- match(as.character(symbol_summary$lane[[i]]), lanes)
  y <- match(as.character(symbol_summary$symbol[[i]]), symbols)
  val <- num(symbol_summary$exposure[[i]])
  fill <- grDevices::colorRampPalette(c("#F5F7FA", "#2E86AB"))(101L)[max(1L, min(101L, round(100 * val) + 1L))]
  rect(x - 0.48, y - 0.48, x + 0.48, y + 0.48, col = fill, border = "white")
  text(x, y, paste0(round(100 * val), "%\n", symbol_summary$trade_count[[i]], " tr"), cex = 0.72, col = "#111111")
}
axis(1, at = seq_along(lanes), labels = lanes, las = 2)
axis(2, at = seq_along(symbols), labels = symbols, las = 1)
mtext("Cell labels: exposure percent and number of entries", side = 3, line = 0.2, cex = 0.8, col = aesthetic$muted_text)
par(oldpar)
dev.off()

png_file(file.path(out_dir, "cluster3_symbol_participation.png"), width = 2200L, height = 1700L)
oldpar <- par(no.readonly = TRUE)
par(mfrow = c(3, 1), mar = c(5, 6, 3, 2))
for (lane in lanes) {
  x <- symbol_summary[as.character(symbol_summary$lane) == lane, , drop = FALSE]
  x <- x[order(x$symbol), , drop = FALSE]
  if (!nrow(x)) next
  mat <- rbind(num(x$strategy_return), num(x$hold_return))
  colnames(mat) <- x$symbol
  ylim <- range(mat, finite = TRUE)
  ylim <- c(min(ylim[[1L]], 0), max(ylim[[2L]], 0))
  bp <- barplot(mat, beside = TRUE, col = c(lane_cols[[lane]], "#B8BCC4"), border = NA, ylim = ylim, main = paste(lane, "symbol return vs hold"), ylab = "Return", las = 2, cex.names = 0.8)
  abline(h = 0, col = aesthetic$axis)
  legend("topleft", legend = c("strategy", "hold"), fill = c(lane_cols[[lane]], "#B8BCC4"), bty = "n", cex = 0.8)
}
par(oldpar)
dev.off()

png_file(file.path(out_dir, "cluster3_family_mix.png"), width = 2200L, height = 1100L)
oldpar <- par(no.readonly = TRUE)
par(mar = c(8, 6, 4, 2))
families <- sort(unique(as.character(family_counts$family)))
mat <- matrix(0, nrow = length(families), ncol = length(lanes), dimnames = list(families, lanes))
for (i in seq_len(nrow(family_counts))) {
  mat[as.character(family_counts$family[[i]]), as.character(family_counts$lane[[i]])] <- num(family_counts$trade_count[[i]])
}
barplot(mat, beside = FALSE, col = grDevices::hcl.colors(nrow(mat), "Set 3"), border = NA, las = 2, ylab = "Trade count", main = "Cluster 3 Trade Family Mix")
legend("topleft", legend = rownames(mat), fill = grDevices::hcl.colors(nrow(mat), "Set 3"), bty = "n", cex = 0.75, ncol = 2)
par(oldpar)
dev.off()

png_file(file.path(out_dir, "cluster3_trade_tape.png"), width = 2400L, height = 1600L)
oldpar <- par(no.readonly = TRUE)
par(mfrow = c(3, 1), mar = c(4, 7, 3, 2))
for (lane in lanes) {
  x <- all_trades[as.character(all_trades$lane) == lane, , drop = FALSE]
  x <- x[order(x$symbol, x$entry_date), , drop = FALSE]
  y_symbols <- sort(unique(as.character(x$symbol)))
  plot(NA, xlim = c(start_date, end_date), ylim = c(0.5, length(y_symbols) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = paste(lane, "trade tape"), col.main = aesthetic$text)
  rect(start_date, 0.5, end_date, length(y_symbols) + 0.5, col = aesthetic$panel_background, border = NA)
  axis.Date(1, at = seq(start_date, end_date, by = "2 weeks"), format = "%b %d", las = 2)
  axis(2, at = seq_along(y_symbols), labels = y_symbols, las = 1)
  abline(v = seq(start_date, end_date, by = "1 month"), col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.18), lty = 3)
  if (nrow(x)) {
    for (i in seq_len(nrow(x))) {
      y <- match(as.character(x$symbol[[i]]), y_symbols)
      col <- if (num(x$ret[[i]]) > 0) aesthetic$trade_win_line else aesthetic$trade_loss_line
      segments(as.Date(x$entry_date[[i]]), y, as.Date(x$exit_date[[i]]), y, col = col, lwd = 4)
      points(as.Date(x$entry_date[[i]]), y, pch = 16, col = col, cex = 0.8)
      points(as.Date(x$exit_date[[i]]), y, pch = 4, col = col, cex = 0.8)
    }
  }
}
par(oldpar)
dev.off()

report <- c(
  "# Gen5.2 vs Gen4 Trade-Tape Audit",
  "",
  "## Purpose",
  "",
  "This audit inspects the 2024Q4 high-beta cluster gap after the Gen5.2 calibration replay normalized Gen4 and Gen5.2 to the same comparison window. It asks whether the remaining difference appears to come from exposure, trade count, family mix, or per-symbol participation.",
  "",
  "## Scope",
  "",
  paste0("- Window: `", start_date, "` to `", end_date, "`."),
  paste0("- Target Gen4 cluster: `cluster_", target_cluster, "`."),
  paste0("- Cluster symbols available in this calibration: `", paste(symbols, collapse = ","), "`."),
  "- Lanes: Gen4 artifact, Gen5.2 direct-spec, Gen5.2 pooled-family.",
  "- Evidence role: inspection only; this does not approve allocation or live behavior.",
  "",
  "## Lane Summary",
  "",
  "| lane | mean exposure | mean symbol return | mean hold return | mean alpha vs hold | trades | wins | losses | median bars held |",
  "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
  apply(lane_summary[match(lanes, lane_summary$lane), , drop = FALSE], 1, function(row) {
    paste0(
      "| ", row[["lane"]], " | ",
      pct_label(as.numeric(row[["mean_exposure"]])), " | ",
      pct_label(as.numeric(row[["mean_symbol_strategy_return"]])), " | ",
      pct_label(as.numeric(row[["mean_symbol_hold_return"]])), " | ",
      pp_label(as.numeric(row[["mean_alpha_vs_hold"]])), " | ",
      row[["total_trades"]], " | ",
      row[["wins"]], " | ",
      row[["losses"]], " | ",
      sprintf("%.1f", as.numeric(row[["median_bars_held"]])), " |"
    )
  }),
  "",
  "## Visual Outputs",
  "",
  paste0("- Exposure heatmap: `", file.path(out_dir, "cluster3_exposure_heatmap.png"), "`."),
  paste0("- Symbol participation: `", file.path(out_dir, "cluster3_symbol_participation.png"), "`."),
  paste0("- Family mix: `", file.path(out_dir, "cluster3_family_mix.png"), "`."),
  paste0("- Trade tape: `", file.path(out_dir, "cluster3_trade_tape.png"), "`.")
)

writeLines(report, file.path(out_dir, "cluster3_trade_tape_audit_report.md"))

message("Gen5.2 Gen4 trade-tape audit complete")
message("Output: ", out_dir)
