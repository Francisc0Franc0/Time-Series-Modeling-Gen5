options(stringsAsFactors = FALSE)

packet <- file.path(
  "runs", "research_workbench", "literature_grounded",
  "lit_mom_01_2_stock_atlas_01_retrospective_20260802"
)
visual_dir <- file.path(packet, "visuals")
summary <- utils::read.csv(
  file.path(packet, "stock_atlas_01_summary.csv"),
  stringsAsFactors = FALSE
)
contract_grid <- c(1L, 5L, 10L, 25L, 60L, 120L, 250L)

safe_range <- function(x, fallback = c(-1, 1)) {
  x <- x[is.finite(x)]
  if (!length(x)) return(fallback)
  r <- range(x)
  if (diff(r) == 0) r <- r + c(-1, 1) * max(abs(r[[1L]]) * 0.05, 0.01)
  r
}

png(
  file.path(visual_dir, "stock_atlas_01_selection_and_continuity.png"),
  1900, 1500, res = 150
)
par(mfrow = c(2, 2), mar = c(4.5, 6, 3.5, 1.5))
y <- rev(seq_len(nrow(summary)))
plot(
  match(summary$lookback_sessions, contract_grid), y,
  pch = 19, col = "#3B82F6", xaxt = "n", yaxt = "n",
  xlab = "Selected lookback L", ylab = "",
  main = "Every stock searches all 49 TRAIN cells", xlim = c(0.5, 7.5)
)
axis(1, seq_along(contract_grid), contract_grid)
axis(2, y, summary$symbol, las = 1, cex.axis = 0.72)
abline(v = seq_along(contract_grid), col = "#E5E7EB", lty = 3)
plot(
  match(summary$holding_sessions, contract_grid), y,
  pch = 19, col = "#8B5CF6", xaxt = "n", yaxt = "n",
  xlab = "Selected holding H", ylab = "",
  main = "Only the per-stock winner advances", xlim = c(0.5, 7.5)
)
axis(1, seq_along(contract_grid), contract_grid)
axis(2, y, summary$symbol, las = 1, cex.axis = 0.72)
abline(v = seq_along(contract_grid), col = "#E5E7EB", lty = 3)
plot(
  summary$train_return_correlation,
  summary$retrospective_return_correlation,
  pch = 19, col = "#3B82F6",
  xlim = safe_range(summary$train_return_correlation),
  ylim = safe_range(summary$retrospective_return_correlation),
  xlab = "TRAIN selected-row correlation",
  ylab = "Retrospective correlation",
  main = "Did the selected relationship persist?"
)
abline(h = 0, v = 0, col = "#64748B", lty = 2)
text(
  summary$train_return_correlation,
  summary$retrospective_return_correlation,
  labels = summary$symbol, pos = 3, cex = 0.55
)
plot(
  100 * summary$train_primary_return,
  100 * summary$retrospective_primary_return,
  pch = 19,
  col = ifelse(summary$retrospective_primary_return > 0, "#197447", "#B42318"),
  xlim = safe_range(100 * summary$train_primary_return),
  ylim = safe_range(100 * summary$retrospective_primary_return),
  xlab = "TRAIN primary return (%)",
  ylab = "Retrospective primary return (%)",
  main = "Did net compounding persist?"
)
abline(h = 0, v = 0, col = "#64748B", lty = 2)
text(
  100 * summary$train_primary_return,
  100 * summary$retrospective_primary_return,
  labels = summary$symbol, pos = 3, cex = 0.55
)
dev.off()

png(
  file.path(visual_dir, "stock_atlas_01_return_and_direction.png"),
  2000, 1050, res = 150
)
par(mfrow = c(1, 2), mar = c(5, 6, 4, 1.5))
ord <- order(summary$retrospective_primary_return)
s <- summary[ord, , drop = FALSE]
xr <- range(c(s$retrospective_stress_return, s$retrospective_gross_return, 0)) * 100
bp <- barplot(
  100 * s$retrospective_primary_return,
  names.arg = s$symbol,
  horiz = TRUE,
  las = 1,
  cex.names = 0.7,
  col = ifelse(s$retrospective_primary_return > 0, "#197447", "#B42318"),
  border = NA,
  xlim = xr,
  main = "Only 5 of 22 were primary-positive",
  xlab = "2021-2023 cumulative return (%)"
)
points(
  100 * s$retrospective_gross_return, bp,
  pch = 21, bg = "white", col = "#111827", cex = 0.9
)
points(
  100 * s$retrospective_stress_return, bp,
  pch = 4, col = "#F59E0B", cex = 0.9, lwd = 1.3
)
abline(v = 0, col = "#111827")
legend(
  "bottomright",
  c("Primary", "Gross", "Stress"),
  pch = c(15, 21, 4),
  col = c("#64748B", "#111827", "#F59E0B"),
  pt.bg = c("#64748B", "white", NA),
  bty = "n", cex = 0.75
)
ord <- order(rowMeans(cbind(
  summary$retrospective_long_accuracy,
  summary$retrospective_short_accuracy
), na.rm = TRUE))
s <- summary[ord, , drop = FALSE]
y <- seq_len(nrow(s))
plot(
  100 * s$retrospective_long_accuracy, y,
  pch = 19, col = "#197447", xlim = c(0, 100),
  ylim = c(0.5, nrow(s) + 0.5), yaxt = "n",
  xlab = "Direction accuracy (%)", ylab = "",
  main = "Long and short calls diverged"
)
points(100 * s$retrospective_short_accuracy, y, pch = 17, col = "#B42318")
segments(
  100 * s$retrospective_long_accuracy, y,
  100 * s$retrospective_short_accuracy, y,
  col = "#CBD5E1"
)
axis(2, y, s$symbol, las = 1, cex.axis = 0.7)
abline(v = 50, col = "#111827", lty = 2)
legend(
  "bottomright", c("Long", "Short"), pch = c(19, 17),
  col = c("#197447", "#B42318"), bty = "n", cex = 0.8
)
dev.off()
