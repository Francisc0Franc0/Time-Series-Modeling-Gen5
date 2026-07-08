repo_root <- normalizePath(file.path(getwd()), winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "selection_policy_screen.R"))

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

first_value <- function(x, default = NA) {
  if (!length(x)) return(default)
  value <- x[[1L]]
  if (is.null(value) || length(value) == 0L) default else value
}

row_value <- function(row, name, default = NA) {
  if (!is.data.frame(row) || !nrow(row) || !name %in% names(row)) return(default)
  first_value(row[[name]], default = default)
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

focus_symbols <- intersect(c("SOFI", "PLTR"), run_symbols)
train_perf <- read_csv_safe(file.path(calibration_dir, "auth", "2024Q4", "bridge_train_state_performance.csv"))
direct_authority <- g5_selection_policy_direct_asset_state_spec(train_perf, min_train_state_rows = 20L)
pooled_authority <- g5_selection_policy_pooled_family_asset_variant(train_perf, min_train_state_rows = 20L)
authority_rows <- rbind(
  direct_authority[, names(direct_authority), drop = FALSE],
  pooled_authority[, names(direct_authority), drop = FALSE]
)
authority_rows$lane <- normalize_lane(authority_rows$selection_policy)
authority_focus <- authority_rows[
  as.character(authority_rows$symbol) %in% focus_symbols,
  ,
  drop = FALSE
]

state_path_summary <- do.call(rbind, lapply(split(
  replay[as.character(replay$symbol) %in% focus_symbols, , drop = FALSE],
  paste(replay$lane[as.character(replay$symbol) %in% focus_symbols], replay$symbol[as.character(replay$symbol) %in% focus_symbols], replay$state_id[as.character(replay$symbol) %in% focus_symbols], sep = "::")
), function(x) {
  data.frame(
    lane = as.character(x$lane[[1L]]),
    symbol = as.character(x$symbol[[1L]]),
    state_id = as.character(x$state_id[[1L]]),
    oos_days = nrow(x),
    oos_long_days = sum(as.logical(x$is_long), na.rm = TRUE),
    oos_entry_count = sum(as.character(x$execution_status) == "ENTER_EXECUTED_AT_OPEN", na.rm = TRUE),
    first_oos_date = min(x$session_date, na.rm = TRUE),
    last_oos_date = max(x$session_date, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

if (!is.data.frame(state_path_summary) || !nrow(state_path_summary)) {
  state_path_summary <- data.frame(
    lane = character(),
    symbol = character(),
    state_id = character(),
    oos_days = integer(),
    oos_long_days = integer(),
    oos_entry_count = integer(),
    first_oos_date = as.Date(character()),
    last_oos_date = as.Date(character()),
    stringsAsFactors = FALSE
  )
}

authority_keys <- unique(rbind(
  authority_focus[, c("lane", "symbol", "state_id"), drop = FALSE],
  state_path_summary[, c("lane", "symbol", "state_id"), drop = FALSE]
))
authority_ledger <- do.call(rbind, lapply(seq_len(nrow(authority_keys)), function(i) {
  key <- authority_keys[i, , drop = FALSE]
  symbol <- as.character(key$symbol[[1L]])
  state_id <- as.character(key$state_id[[1L]])
  lane <- as.character(key$lane[[1L]])
  selected <- authority_focus[
    as.character(authority_focus$lane) == lane &
      as.character(authority_focus$symbol) == symbol &
      as.character(authority_focus$state_id) == state_id,
    ,
    drop = FALSE
  ]
  selected <- if (nrow(selected)) selected[1L, , drop = FALSE] else selected
  state_rows <- train_perf[
    as.character(train_perf$symbol) == symbol &
      as.character(train_perf$state_id) == state_id,
    ,
    drop = FALSE
  ]
  eligible <- g5_wfa_gen52_eligible_rows(state_rows, min_train_state_rows = 20L, min_train_trades = 5L)
  no_trade_rows <- state_rows[as.character(state_rows$strategy_family) %in% g5_wfa_gen52_no_trade_families(), , drop = FALSE]
  no_trade_pick <- if (nrow(no_trade_rows)) g5_wfa_gen52_rank_rows(no_trade_rows)[1L, , drop = FALSE] else no_trade_rows
  active_eligible <- eligible[!as.character(eligible$strategy_family) %in% g5_wfa_gen52_no_trade_families(), , drop = FALSE]
  best_active <- if (nrow(active_eligible)) g5_wfa_gen52_rank_rows(active_eligible)[1L, , drop = FALSE] else active_eligible
  path <- state_path_summary[
    as.character(state_path_summary$lane) == lane &
      as.character(state_path_summary$symbol) == symbol &
      as.character(state_path_summary$state_id) == state_id,
    ,
    drop = FALSE
  ]
  data.frame(
    lane = lane,
    symbol = symbol,
    state_id = state_id,
    selected_family = as.character(row_value(selected, "strategy_family", "")),
    selected_spec_id = as.character(row_value(selected, "strategy_spec_id", "")),
    selected_reason = as.character(row_value(selected, "selection_reason", "")),
    pooled_selected_family = as.character(row_value(selected, "pooled_selected_family", "")),
    train_state_row_count = as.numeric(row_value(selected, "train_state_row_count", NA_real_)),
    train_state_trade_count = as.numeric(row_value(selected, "train_state_trade_count", NA_real_)),
    selected_total_return = as.numeric(row_value(selected, "total_return", NA_real_)),
    selected_sharpe = as.numeric(row_value(selected, "sharpe", NA_real_)),
    active_eligible_count = nrow(active_eligible),
    best_active_family = as.character(row_value(best_active, "strategy_family", "")),
    best_active_spec_id = as.character(row_value(best_active, "strategy_spec_id", "")),
    best_active_trade_count = as.numeric(row_value(best_active, "train_state_trade_count", row_value(best_active, "trade_count", NA_real_))),
    best_active_total_return = as.numeric(row_value(best_active, "total_return", NA_real_)),
    best_active_sharpe = as.numeric(row_value(best_active, "sharpe", NA_real_)),
    no_trade_total_return = as.numeric(row_value(no_trade_pick, "total_return", NA_real_)),
    no_trade_sharpe = as.numeric(row_value(no_trade_pick, "sharpe", NA_real_)),
    oos_days = as.integer(row_value(path, "oos_days", 0L)),
    oos_long_days = as.integer(row_value(path, "oos_long_days", 0L)),
    oos_entry_count = as.integer(row_value(path, "oos_entry_count", 0L)),
    stringsAsFactors = FALSE
  )
}))

gen4_params <- read_csv_safe(file.path(phase40_dir, "phase40_picked_params_by_fold_asset.csv"))
gen4_params_focus <- gen4_params[
  as.character(gen4_params$fold_id) == "17" &
    as.character(gen4_params$asset) %in% focus_symbols,
  ,
  drop = FALSE
]
gen4_trades_focus <- gen4_trades[as.character(gen4_trades$symbol) %in% focus_symbols, , drop = FALSE]

write.csv(symbol_summary, file.path(out_dir, "cluster3_symbol_participation_summary.csv"), row.names = FALSE)
write.csv(trade_summary, file.path(out_dir, "cluster3_trade_summary.csv"), row.names = FALSE)
write.csv(lane_summary, file.path(out_dir, "cluster3_lane_summary.csv"), row.names = FALSE)
write.csv(all_trades, file.path(out_dir, "cluster3_combined_trade_tape.csv"), row.names = FALSE)
write.csv(family_counts, file.path(out_dir, "cluster3_family_counts.csv"), row.names = FALSE)
write.csv(authority_ledger, file.path(out_dir, "sofi_pltr_authority_ledger.csv"), row.names = FALSE)
write.csv(state_path_summary, file.path(out_dir, "sofi_pltr_state_path_summary.csv"), row.names = FALSE)
write.csv(gen4_params_focus, file.path(out_dir, "sofi_pltr_gen4_picked_params.csv"), row.names = FALSE)
write.csv(gen4_trades_focus, file.path(out_dir, "sofi_pltr_gen4_trade_tape.csv"), row.names = FALSE)

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

authority_focus_plot <- authority_ledger[as.character(authority_ledger$symbol) %in% focus_symbols, , drop = FALSE]
authority_focus_plot <- authority_focus_plot[order(authority_focus_plot$symbol, authority_focus_plot$state_id, authority_focus_plot$lane), , drop = FALSE]
png_file(file.path(out_dir, "sofi_pltr_authority_heatmap.png"), width = 2400L, height = 1500L)
oldpar <- par(no.readonly = TRUE)
par(mar = c(8, 13, 4, 2))
heat_rows <- paste(authority_focus_plot$symbol, authority_focus_plot$state_id, sep = " / ")
heat_rows <- unique(heat_rows)
plot(NA, xlim = c(0.5, length(lanes) + 0.5), ylim = c(0.5, length(heat_rows) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "SOFI / PLTR Gen5.2 Authority And OOS Occupancy", col.main = aesthetic$text)
rect(0.5, 0.5, length(lanes) + 0.5, length(heat_rows) + 0.5, col = aesthetic$panel_background, border = NA)
family_palette <- c(
  no_trade = "#D0D5DD",
  no_trade_exit_immediate = "#B8BCC4",
  ema_cross = "#2E86AB",
  ema_trend = "#5DADE2",
  pullback_in_uptrend = "#1B9E77",
  bollinger_touch = "#F4A261",
  rsi_mr = "#9B5DE5",
  zret_mr = "#FF6B35",
  volatility_breakout = "#E76F51",
  other = "#8A8F99"
)
for (i in seq_len(nrow(authority_focus_plot))) {
  row_label <- paste(authority_focus_plot$symbol[[i]], authority_focus_plot$state_id[[i]], sep = " / ")
  x <- match(as.character(authority_focus_plot$lane[[i]]), lanes)
  y <- match(row_label, heat_rows)
  fam <- as.character(authority_focus_plot$selected_family[[i]])
  fill <- family_palette[[fam]]
  if (is.null(fill) || is.na(fill)) fill <- family_palette[["other"]]
  rect(x - 0.48, y - 0.48, x + 0.48, y + 0.48, col = fill, border = "white")
  label <- paste0(
    fam,
    "\nOOS ", authority_focus_plot$oos_days[[i]], "d / long ", authority_focus_plot$oos_long_days[[i]], "d",
    "\nact elig ", authority_focus_plot$active_eligible_count[[i]]
  )
  text(x, y, label, cex = 0.58, col = "#111111")
}
axis(1, at = seq_along(lanes), labels = lanes, las = 2)
axis(2, at = seq_along(heat_rows), labels = heat_rows, las = 1, cex.axis = 0.82)
mtext("Cells show selected Gen5.2 authority, OOS state occupancy, long days, and active eligible candidate count.", side = 3, line = 0.2, cex = 0.8, col = aesthetic$muted_text)
par(oldpar)
dev.off()

oos_authority_plot <- authority_focus_plot[authority_focus_plot$oos_days > 0, , drop = FALSE]
oos_authority_plot <- oos_authority_plot[order(oos_authority_plot$symbol, oos_authority_plot$state_id, oos_authority_plot$lane), , drop = FALSE]
png_file(file.path(out_dir, "sofi_pltr_oos_authority_heatmap.png"), width = 2200L, height = 1200L)
oldpar <- par(no.readonly = TRUE)
par(mar = c(8, 9, 4, 2))
oos_heat_rows <- paste(oos_authority_plot$symbol, oos_authority_plot$state_id, sep = " / ")
oos_heat_rows <- unique(oos_heat_rows)
plot(NA, xlim = c(0.5, length(lanes) - 0.5), ylim = c(0.5, length(oos_heat_rows) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "OOS-Visited SOFI / PLTR Authority", col.main = aesthetic$text)
rect(0.5, 0.5, length(lanes) - 0.5, length(oos_heat_rows) + 0.5, col = aesthetic$panel_background, border = NA)
plot_lanes <- c("Gen5.2 direct", "Gen5.2 pooled")
for (i in seq_len(nrow(oos_authority_plot))) {
  row_label <- paste(oos_authority_plot$symbol[[i]], oos_authority_plot$state_id[[i]], sep = " / ")
  x <- match(as.character(oos_authority_plot$lane[[i]]), plot_lanes)
  y <- match(row_label, oos_heat_rows)
  fam <- as.character(oos_authority_plot$selected_family[[i]])
  fill <- family_palette[[fam]]
  if (is.null(fill) || is.na(fill)) fill <- family_palette[["other"]]
  rect(x - 0.48, y - 0.48, x + 0.48, y + 0.48, col = fill, border = "white")
  label <- paste0(
    fam,
    "\n", oos_authority_plot$oos_days[[i]], " OOS days; ",
    oos_authority_plot$oos_long_days[[i]], " long",
    "\nactive eligible: ", oos_authority_plot$active_eligible_count[[i]]
  )
  text(x, y, label, cex = 0.78, col = "#111111")
}
axis(1, at = seq_along(plot_lanes), labels = plot_lanes, las = 2)
axis(2, at = seq_along(oos_heat_rows), labels = oos_heat_rows, las = 1)
mtext("Only states visited by SOFI/PLTR in 2024Q4 OOS are shown.", side = 3, line = 0.2, cex = 0.85, col = aesthetic$muted_text)
par(oldpar)
dev.off()

png_file(file.path(out_dir, "sofi_pltr_no_trade_diagnostic.png"), width = 2400L, height = 1300L)
oldpar <- par(no.readonly = TRUE)
par(mar = c(9, 7, 4, 2))
diag_rows <- authority_focus_plot[authority_focus_plot$oos_days > 0, , drop = FALSE]
diag_rows <- diag_rows[order(diag_rows$symbol, diag_rows$state_id, diag_rows$lane), , drop = FALSE]
labels <- paste(diag_rows$symbol, diag_rows$state_id, sub("Gen5.2 ", "", diag_rows$lane), sep = "\n")
mat <- rbind(
  best_active = num(diag_rows$best_active_sharpe),
  no_trade = num(diag_rows$no_trade_sharpe)
)
mat[!is.finite(mat)] <- NA_real_
ylim <- range(mat, finite = TRUE)
if (!all(is.finite(ylim))) ylim <- c(-1, 1)
ylim <- c(min(ylim[[1L]], 0) - 0.05, max(ylim[[2L]], 0) + 0.05)
bp <- barplot(mat, beside = TRUE, col = c("#2E86AB", "#D0D5DD"), border = NA, names.arg = labels, las = 2, ylab = "TRAIN Sharpe score", main = "Best Active Candidate Versus No-Trade Score For OOS-Visited States", ylim = ylim, cex.names = 0.65)
abline(h = 0, col = aesthetic$axis)
legend("topleft", legend = c("best active eligible", "no_trade"), fill = c("#2E86AB", "#D0D5DD"), bty = "n", cex = 0.85)
text(colMeans(bp), pmax(mat[1, ], mat[2, ], na.rm = TRUE) + 0.04, labels = paste0("selected: ", diag_rows$selected_family), srt = 90, adj = 0, cex = 0.58, col = aesthetic$muted_text)
par(oldpar)
dev.off()

png_file(file.path(out_dir, "sofi_pltr_state_position_timeline.png"), width = 2400L, height = 1500L)
oldpar <- par(no.readonly = TRUE)
par(mfrow = c(2, 2), mar = c(5, 5, 3, 1))
timeline_rows <- replay[as.character(replay$symbol) %in% focus_symbols, , drop = FALSE]
for (symbol in focus_symbols) {
  for (lane in c("Gen5.2 direct", "Gen5.2 pooled")) {
    x <- timeline_rows[as.character(timeline_rows$symbol) == symbol & as.character(timeline_rows$lane) == lane, , drop = FALSE]
    x <- x[order(x$session_date), , drop = FALSE]
    states_here <- sort(unique(as.character(x$state_id)))
    y <- match(as.character(x$state_id), states_here)
    plot(NA, xlim = c(start_date, end_date), ylim = c(0.5, length(states_here) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = paste(symbol, lane), col.main = aesthetic$text)
    rect(start_date, 0.5, end_date, length(states_here) + 0.5, col = aesthetic$panel_background, border = NA)
    axis.Date(1, at = seq(start_date, end_date, by = "2 weeks"), format = "%b %d", las = 2)
    axis(2, at = seq_along(states_here), labels = states_here, las = 1)
    abline(v = seq(start_date, end_date, by = "1 month"), col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.18), lty = 3)
    if (nrow(x)) {
      cols <- ifelse(as.logical(x$is_long), "#1B9E77", "#B8BCC4")
      points(x$session_date, y, pch = 15, col = cols, cex = 1.2)
      lines(x$session_date, y, col = grDevices::adjustcolor("#111111", alpha.f = 0.28), lwd = 1)
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
  paste0("- Trade tape: `", file.path(out_dir, "cluster3_trade_tape.png"), "`."),
  "",
  "## SOFI / PLTR Authority Audit",
  "",
  "The focused authority audit separates selected Gen5.2 authority, OOS state occupancy, and realized replay position. This matters because a flat OOS path can mean either a no-trade state, an active model that did not signal, or state occupancy that missed the active states.",
  "",
  paste0("- Gen5.2 authority ledger: `", file.path(out_dir, "sofi_pltr_authority_ledger.csv"), "`."),
  paste0("- Gen5.2 state path summary: `", file.path(out_dir, "sofi_pltr_state_path_summary.csv"), "`."),
  paste0("- Gen4 picked params: `", file.path(out_dir, "sofi_pltr_gen4_picked_params.csv"), "`."),
  paste0("- Gen4 SOFI/PLTR trade tape: `", file.path(out_dir, "sofi_pltr_gen4_trade_tape.csv"), "`."),
  paste0("- Authority heatmap: `", file.path(out_dir, "sofi_pltr_authority_heatmap.png"), "`."),
  paste0("- OOS authority heatmap: `", file.path(out_dir, "sofi_pltr_oos_authority_heatmap.png"), "`."),
  paste0("- No-trade diagnostic: `", file.path(out_dir, "sofi_pltr_no_trade_diagnostic.png"), "`."),
  paste0("- State/position timeline: `", file.path(out_dir, "sofi_pltr_state_position_timeline.png"), "`."),
  "",
  "Key readout: Gen4 selected `ema_cross_f1_s10` for SOFI in fold 17 and generated three Q4 trades, including one large October-to-December winner. Gen5.2 SOFI stayed flat in both lanes across OOS-visited states, so the gap is not a live-basket mismatch. It is a selected-authority / signal-timing divergence inside the same basket and quarter."
)

writeLines(report, file.path(out_dir, "cluster3_trade_tape_audit_report.md"))

message("Gen5.2 Gen4 trade-tape audit complete")
message("Output: ", out_dir)
