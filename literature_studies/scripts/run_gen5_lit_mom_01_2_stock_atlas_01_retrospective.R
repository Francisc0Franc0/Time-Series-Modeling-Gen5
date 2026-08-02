options(stringsAsFactors = FALSE)

source(file.path(
  "literature_studies", "R",
  "gen5_lit_mom_01_1_interday_momentum_poc.R"
))
source(file.path(
  "literature_studies", "R",
  "gen5_lit_mom_01_2_single_position_poc.R"
))

contract <- g5_mom012_contract()
source_packet <- file.path(
  "runs", "research_workbench", "literature_grounded",
  "lit_mom_01_1_stock_atlas_01_20260731"
)
source_bars_path <- file.path(
  source_packet, "stock_atlas_01_workbench_query_bars.csv"
)
registry_path <- file.path(
  "literature_studies", "registries",
  "gen5_lit_mom_01_1_stock_atlas_01_registry.csv"
)
output_dir <- file.path(
  "runs", "research_workbench", "literature_grounded",
  "lit_mom_01_2_stock_atlas_01_retrospective_20260802"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

add_identity <- function(x, row) {
  if (is.null(x) || !nrow(x)) return(x)
  cbind(
    data.frame(
      instance_id = row$instance_id,
      symbol = row$symbol,
      sector = row$sector,
      stringsAsFactors = FALSE
    ),
    x
  )
}

metric_value <- function(metrics, regime, field) {
  metrics[metrics$regime_id == regime, field][[1L]]
}

safe_range <- function(x, fallback = c(-1, 1)) {
  x <- x[is.finite(x)]
  if (!length(x)) return(fallback)
  r <- range(x)
  if (diff(r) == 0) r <- r + c(-1, 1) * max(abs(r[[1L]]) * 0.05, 0.01)
  r
}

registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
bars_all <- utils::read.csv(source_bars_path, stringsAsFactors = FALSE)
bars_all$session_date <- as.Date(bars_all$session_date)
bars_all <- bars_all[
  bars_all$symbol %in% registry$symbol &
    bars_all$session_date <= contract$retrospective_end,
  ,
  drop = FALSE
]

if (!identical(sort(unique(bars_all$symbol)), sort(registry$symbol))) {
  stop("Frozen atlas bar symbols do not match the registry.", call. = FALSE)
}
if (any(bars_all$session_date >= contract$confirmation_start)) {
  stop("Confirmation bars entered the retrospective atlas.", call. = FALSE)
}

horizon_rows <- list()
selected_rows <- list()
inference_rows <- list()
phase_rows <- list()
train_metric_rows <- list()
retro_metric_rows <- list()
train_direction_rows <- list()
retro_direction_rows <- list()
retro_year_rows <- list()
trade_rows <- list()
replay_rows <- list()
integrity_rows <- list()
summary_rows <- list()

message("LIT-MOM-01.2 stock atlas starting: ", nrow(registry), " assets.")

for (i in seq_len(nrow(registry))) {
  reg <- registry[i, , drop = FALSE]
  symbol <- reg$symbol[[1L]]
  message(sprintf("[%02d/%02d] %s", i, nrow(registry), symbol))
  asset_contract <- g5_mom012_replication_contract(symbol)
  parent_contract <- g5_mom012_parent_contract(asset_contract)
  bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  bars <- bars[order(bars$session_date), , drop = FALSE]

  screen <- g5_mom01_horizon_screen(
    bars,
    contract$train_start,
    contract$train_end,
    parent_contract
  )
  selected <- g5_mom012_select_horizon(screen, asset_contract)
  train <- g5_mom012_analyze_period(
    bars,
    contract$train_start,
    contract$train_end,
    "TRAIN",
    selected$lookback_sessions,
    selected$holding_sessions,
    asset_contract
  )
  retro <- g5_mom012_analyze_period(
    bars,
    contract$retrospective_start,
    contract$retrospective_end,
    "RETROSPECTIVE_2021_2023",
    selected$lookback_sessions,
    selected$holding_sessions,
    asset_contract
  )
  integrity <- g5_mom012_integrity_audit(
    bars,
    selected,
    train,
    retro,
    asset_contract
  )

  horizon_rows[[i]] <- add_identity(screen, reg)
  selected_rows[[i]] <- add_identity(selected, reg)
  inference_rows[[length(inference_rows) + 1L]] <- add_identity(
    transform(train$inference$summary, period_id = "TRAIN"), reg
  )
  inference_rows[[length(inference_rows) + 1L]] <- add_identity(
    transform(retro$inference$summary, period_id = "RETROSPECTIVE_2021_2023"), reg
  )
  phase_rows[[i]] <- add_identity(train$inference$step_l_phase_offsets, reg)
  train_metric_rows[[i]] <- add_identity(train$metrics, reg)
  retro_metric_rows[[i]] <- add_identity(retro$metrics, reg)
  train_direction_rows[[i]] <- add_identity(train$direction_audit, reg)
  retro_direction_rows[[i]] <- add_identity(retro$direction_audit, reg)
  retro_year_rows[[i]] <- add_identity(retro$calendar_years, reg)
  trade_rows[[i]] <- add_identity(retro$trade_results, reg)
  replay_rows[[i]] <- add_identity(retro$replay, reg)
  integrity_rows[[i]] <- add_identity(integrity, reg)

  train_primary <- metric_value(train$metrics, "PRIMARY", "cumulative_return")
  retro_gross <- metric_value(retro$metrics, "GROSS", "cumulative_return")
  retro_primary <- metric_value(retro$metrics, "PRIMARY", "cumulative_return")
  retro_stress <- metric_value(retro$metrics, "STRESS", "cumulative_return")
  retro_primary_sharpe <- metric_value(retro$metrics, "PRIMARY", "naive_sharpe")
  retro_primary_dd <- metric_value(retro$metrics, "PRIMARY", "maximum_drawdown")
  retro_primary_trades <- metric_value(retro$metrics, "PRIMARY", "trade_count")
  retro_primary_inference <- retro$inference$summary[
    retro$inference$summary$sampling_id == "CHAN_MIN_STEP",
    ,
    drop = FALSE
  ]
  long <- retro$direction_audit[retro$direction_audit$direction == "LONG", , drop = FALSE]
  short <- retro$direction_audit[retro$direction_audit$direction == "SHORT", , drop = FALSE]
  summary_rows[[i]] <- data.frame(
    instance_id = reg$instance_id,
    symbol = symbol,
    sector = reg$sector,
    lookback_sessions = selected$lookback_sessions,
    holding_sessions = selected$holding_sessions,
    train_pair_count = selected$pair_count,
    train_return_correlation = selected$return_correlation,
    train_naive_p_value = selected$naive_pearson_p_value,
    train_direction_accuracy = selected$direction_accuracy,
    train_primary_return = train_primary,
    retrospective_pair_count = retro_primary_inference$pair_count,
    retrospective_return_correlation = retro_primary_inference$return_correlation,
    retrospective_direction_accuracy = retro_primary_inference$direction_accuracy,
    retrospective_gross_return = retro_gross,
    retrospective_primary_return = retro_primary,
    retrospective_stress_return = retro_stress,
    retrospective_primary_sharpe = retro_primary_sharpe,
    retrospective_primary_maximum_drawdown = retro_primary_dd,
    retrospective_trade_count = retro_primary_trades,
    retrospective_long_accuracy = long$direction_accuracy,
    retrospective_short_accuracy = short$direction_accuracy,
    integrity_passed = all(integrity$passed),
    evidence_label = contract$evidence_label,
    stringsAsFactors = FALSE
  )
}

horizon_screen <- do.call(rbind, horizon_rows)
selected <- do.call(rbind, selected_rows)
inference <- do.call(rbind, inference_rows)
phase_offsets <- do.call(rbind, phase_rows)
train_metrics <- do.call(rbind, train_metric_rows)
retro_metrics <- do.call(rbind, retro_metric_rows)
train_direction <- do.call(rbind, train_direction_rows)
retro_direction <- do.call(rbind, retro_direction_rows)
retro_years <- do.call(rbind, retro_year_rows)
trades <- do.call(rbind, trade_rows)
replay <- do.call(rbind, replay_rows)
integrity <- do.call(rbind, integrity_rows)
summary <- do.call(rbind, summary_rows)

batch <- data.frame(
  literature_id = "LIT-MOM-01.2",
  instance_id = "STOCK_ATLAS_01_RETROSPECTIVE",
  evidence_label = contract$evidence_label,
  asset_count = nrow(summary),
  horizon_cells_per_asset = length(contract$horizon_grid)^2,
  total_train_horizon_cells = nrow(horizon_screen),
  assets_positive_gross = sum(summary$retrospective_gross_return > 0),
  assets_positive_primary = sum(summary$retrospective_primary_return > 0),
  assets_positive_stress = sum(summary$retrospective_stress_return > 0),
  median_primary_return = stats::median(summary$retrospective_primary_return),
  mean_primary_return = mean(summary$retrospective_primary_return),
  worst_primary_drawdown = min(summary$retrospective_primary_maximum_drawdown),
  integrity_passed = all(summary$integrity_passed),
  confirmation_excluded = max(bars_all$session_date) < contract$confirmation_start,
  overall_status = "RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_01",
  stringsAsFactors = FALSE
)

write_csv(registry, file.path(output_dir, "stock_atlas_01_registry.csv"))
write_csv(batch, file.path(output_dir, "stock_atlas_01_batch_summary.csv"))
write_csv(horizon_screen, file.path(output_dir, "stock_atlas_01_train_horizon_screen.csv"))
write_csv(selected, file.path(output_dir, "stock_atlas_01_selected_horizons.csv"))
write_csv(inference, file.path(output_dir, "stock_atlas_01_selected_inference_views.csv"))
write_csv(phase_offsets, file.path(output_dir, "stock_atlas_01_train_step_l_phase_offsets.csv"))
write_csv(train_metrics, file.path(output_dir, "stock_atlas_01_train_metrics.csv"))
write_csv(retro_metrics, file.path(output_dir, "stock_atlas_01_retrospective_metrics.csv"))
write_csv(train_direction, file.path(output_dir, "stock_atlas_01_train_direction_audit.csv"))
write_csv(retro_direction, file.path(output_dir, "stock_atlas_01_retrospective_direction_audit.csv"))
write_csv(retro_years, file.path(output_dir, "stock_atlas_01_retrospective_calendar_years.csv"))
write_csv(trades, file.path(output_dir, "stock_atlas_01_retrospective_trades.csv"))
write_csv(replay, file.path(output_dir, "stock_atlas_01_retrospective_bar_replay.csv"))
write_csv(integrity, file.path(output_dir, "stock_atlas_01_integrity_audit.csv"))
write_csv(summary, file.path(output_dir, "stock_atlas_01_summary.csv"))

# Selected horizons by asset.
png(file.path(visual_dir, "stock_atlas_01_selected_horizons.png"), 1800, 1100, res = 150)
par(mar = c(5, 8, 4, 2), mfrow = c(1, 2))
y <- rev(seq_len(nrow(summary)))
grid <- contract$horizon_grid
plot(match(summary$lookback_sessions, grid), y, pch = 19, col = "#3B82F6",
     xaxt = "n", yaxt = "n", xlab = "Selected lookback L", ylab = "",
     main = "Every stock searches all 49 TRAIN cells", xlim = c(0.5, 7.5))
axis(1, seq_along(grid), grid)
axis(2, y, summary$symbol, las = 1, cex.axis = 0.8)
abline(v = seq_along(grid), col = "#E5E7EB", lty = 3)
plot(match(summary$holding_sessions, grid), y, pch = 19, col = "#8B5CF6",
     xaxt = "n", yaxt = "n", xlab = "Selected holding H", ylab = "",
     main = "Only the per-stock winner advances", xlim = c(0.5, 7.5))
axis(1, seq_along(grid), grid)
axis(2, y, summary$symbol, las = 1, cex.axis = 0.8)
abline(v = seq_along(grid), col = "#E5E7EB", lty = 3)
dev.off()

# Return landscape.
ord <- order(summary$retrospective_primary_return)
s <- summary[ord, , drop = FALSE]
png(file.path(visual_dir, "stock_atlas_01_return_landscape.png"), 1900, 1150, res = 150)
par(mar = c(5, 8, 5, 2))
ylim <- range(c(s$retrospective_stress_return, s$retrospective_gross_return, 0)) * 100
bp <- barplot(100 * s$retrospective_primary_return, names.arg = s$symbol,
              horiz = TRUE, las = 1,
              col = ifelse(s$retrospective_primary_return > 0, "#197447", "#B42318"),
              border = NA, xlim = ylim,
              main = "Known-window breadth: each asset uses its own TRAIN-selected L/H",
              xlab = "2021-2023 cumulative return (%)")
points(100 * s$retrospective_gross_return, bp, pch = 21, bg = "white", col = "#111827", cex = 1.1)
points(100 * s$retrospective_stress_return, bp, pch = 4, col = "#F59E0B", cex = 1.1, lwd = 1.5)
abline(v = 0, col = "#111827")
legend("bottomright", c("Primary (signed bar)", "Gross", "Stress"),
       pch = c(15, 21, 4), col = c("#64748B", "#111827", "#F59E0B"),
       pt.bg = c("#64748B", "white", NA), bty = "n", horiz = TRUE)
dev.off()

# TRAIN-to-retrospective continuity.
png(file.path(visual_dir, "stock_atlas_01_train_to_retrospective.png"), 1900, 900, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
rx <- safe_range(summary$train_return_correlation)
ry <- safe_range(summary$retrospective_return_correlation)
plot(summary$train_return_correlation, summary$retrospective_return_correlation,
     pch = 19, col = "#3B82F6", xlim = rx, ylim = ry,
     xlab = "TRAIN selected-row correlation", ylab = "Retrospective correlation",
     main = "Did the selected relationship persist?")
abline(h = 0, v = 0, col = "#64748B", lty = 2)
text(summary$train_return_correlation, summary$retrospective_return_correlation,
     labels = summary$symbol, pos = 3, cex = 0.65)
rx <- safe_range(summary$train_primary_return * 100)
ry <- safe_range(summary$retrospective_primary_return * 100)
plot(100 * summary$train_primary_return, 100 * summary$retrospective_primary_return,
     pch = 19, col = ifelse(summary$retrospective_primary_return > 0, "#197447", "#B42318"),
     xlim = rx, ylim = ry, xlab = "TRAIN primary return (%)",
     ylab = "Retrospective primary return (%)",
     main = "Did net compounding persist?")
abline(h = 0, v = 0, col = "#64748B", lty = 2)
text(100 * summary$train_primary_return, 100 * summary$retrospective_primary_return,
     labels = summary$symbol, pos = 3, cex = 0.65)
dev.off()

# Direction audit.
png(file.path(visual_dir, "stock_atlas_01_direction_audit.png"), 1900, 1050, res = 150)
par(mar = c(5, 8, 4, 2))
ord <- order(rowMeans(cbind(summary$retrospective_long_accuracy, summary$retrospective_short_accuracy), na.rm = TRUE))
s <- summary[ord, , drop = FALSE]
y <- seq_len(nrow(s))
plot(s$retrospective_long_accuracy * 100, y, pch = 19, col = "#197447",
     xlim = c(0, 100), ylim = c(0.5, nrow(s) + 0.5), yaxt = "n",
     xlab = "Direction accuracy (%)", ylab = "",
     main = "Long and short calls are audited separately")
points(s$retrospective_short_accuracy * 100, y, pch = 17, col = "#B42318")
segments(s$retrospective_long_accuracy * 100, y,
         s$retrospective_short_accuracy * 100, y, col = "#CBD5E1")
axis(2, y, s$symbol, las = 1, cex.axis = 0.8)
abline(v = 50, col = "#111827", lty = 2)
legend("bottomright", c("Long", "Short"), pch = c(19, 17),
       col = c("#197447", "#B42318"), bty = "n")
dev.off()

# Primary equity small multiples.
primary_replay <- replay[replay$regime_id == "PRIMARY", , drop = FALSE]
png(file.path(visual_dir, "stock_atlas_01_primary_equity_paths.png"), 2000, 2100, res = 150)
par(mfrow = c(6, 4), mar = c(2.2, 2.5, 2.4, 1))
for (symbol in registry$symbol) {
  x <- primary_replay[primary_replay$symbol == symbol, , drop = FALSE]
  plot(x$outcome_date, x$wealth, type = "l", col = "#3B82F6", lwd = 1.5,
       xlab = "", ylab = "", xaxt = "n",
       main = sprintf("%s  %+.1f%%", symbol, 100 * (tail(x$wealth, 1) - 1)),
       cex.main = 0.9)
  axis.Date(1, at = as.Date(c("2021-01-04", "2022-01-03", "2023-01-03")),
            labels = c("21", "22", "23"), cex.axis = 0.7)
  abline(h = 1, col = "#94A3B8", lty = 2)
}
plot.new()
plot.new()
dev.off()

report_lines <- c(
  "# LIT-MOM-01.2 Stock Atlas 01 Retrospective",
  "",
  paste0("Status: `", batch$overall_status, "`"),
  "",
  "## Boundary",
  "",
  "Every stock independently searches all 49 TRAIN L/H cells. Only its frozen",
  "winner is replayed in the already inspected 2021-2023 window. This is",
  "retrospective breadth learning, not fresh OOS confirmation.",
  "",
  "## Breadth readout",
  "",
  sprintf("- Assets: `%d`.", batch$asset_count),
  sprintf("- TRAIN horizon cells evaluated: `%d`.", batch$total_train_horizon_cells),
  sprintf("- Positive gross / primary / stress: `%d / %d / %d`.",
          batch$assets_positive_gross, batch$assets_positive_primary,
          batch$assets_positive_stress),
  sprintf("- Median primary return: `%.2f%%`.", 100 * batch$median_primary_return),
  sprintf("- Mean primary return: `%.2f%%`.", 100 * batch$mean_primary_return),
  sprintf("- Worst primary drawdown: `%.2f%%`.", 100 * batch$worst_primary_drawdown),
  "",
  "## Interpretation",
  "",
  "Report every asset. Do not select the best retrospective name, form a",
  "portfolio, remove shorts, or query 2024+ confirmation.",
  "",
  "## Packet",
  "",
  paste0("`", output_dir, "`")
)
writeLines(report_lines, file.path(output_dir, "stock_atlas_01_report.md"))

message("LIT-MOM-01.2 stock atlas complete.")
message("Packet: ", output_dir)
