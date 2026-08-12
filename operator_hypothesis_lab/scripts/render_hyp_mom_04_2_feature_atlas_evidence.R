options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_2_engine.R"))

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
run_dir <- env_or(
  "GEN5_HYP_MOM_042_RENDER_RUN_DIR",
  file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
            "hyp_mom_04_2_feature_atlas_train_20260811")
)
run_dir <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

read_run_csv <- function(name) utils::read.csv(file.path(run_dir, name), stringsAsFactors = FALSE)
run_spec <- read_run_csv("hyp_mom_04_2_run_spec.csv")
panel <- read_run_csv("hyp_mom_04_2_feature_panel.csv")
scorecard <- read_run_csv("hyp_mom_04_2_feature_scorecard.csv")
quarterly <- read_run_csv("hyp_mom_04_2_feature_quarterly_ic.csv")
deciles <- read_run_csv("hyp_mom_04_2_feature_decile_curves.csv")
redundancy_long <- read_run_csv("hyp_mom_04_2_feature_redundancy.csv")
redundancy_pairs <- read_run_csv("hyp_mom_04_2_redundancy_pairs.csv")
inner_summary <- read_run_csv("hyp_mom_04_2_inner_summary.csv")
selections <- read_run_csv("hyp_mom_04_2_outer_selections.csv")
outer <- read_run_csv("hyp_mom_04_2_outer_metrics.csv")
original <- read_run_csv("hyp_mom_04_2_original_challenger_metrics.csv")
permutation <- read_run_csv("hyp_mom_04_2_full_search_permutation.csv")
gates <- read_run_csv("hyp_mom_04_2_train_gates.csv")
status <- trimws(readLines(file.path(run_dir, "status.txt"), warn = FALSE)[[1L]])
contract <- h042_contract()

blue <- "#167D9A"; navy <- "#142B4A"; green <- "#2AA876"; red <- "#D1495B"
orange <- "#F28E2B"; pale <- "#D9EEF3"; gray <- "#67717E"; purple <- "#7A5195"

png(file.path(visual_dir, "feature_scorecard.png"), 2200, 1400, res = 170)
par(mfrow = c(1, 2), mar = c(10, 5, 4, 1))
score <- scorecard[order(scorecard$mean_rank_ic), ]
barplot(score$mean_rank_ic, names.arg = score$feature, las = 2,
        col = ifelse(score$mean_rank_ic > 0, green, red), border = NA,
        ylab = "Mean quarterly Spearman IC", main = "Feature direction across 15 TRAIN quarters")
abline(h = 0, col = gray)
score2 <- scorecard[order(scorecard$positive_ic_fraction), ]
barplot(score2$positive_ic_fraction, names.arg = score2$feature, las = 2,
        col = ifelse(score2$positive_ic_fraction >= 0.6, green, orange), border = NA,
        ylab = "Fraction of quarters with positive IC", main = "Feature sign stability")
abline(h = 0.6, lty = 2, col = navy)
dev.off()

ic_matrix <- xtabs(rank_ic ~ feature + signal_quarter, quarterly)
z <- ic_matrix
z[] <- pmax(-0.25, pmin(0.25, ic_matrix))
png(file.path(visual_dir, "feature_quarterly_ic_heatmap.png"), 2200, 1700, res = 170)
par(mar = c(7, 13, 4, 2))
image(seq_len(ncol(z)), seq_len(nrow(z)), t(z[nrow(z):1, , drop = FALSE]),
      col = colorRampPalette(c(red, "white", green))(101), axes = FALSE,
      xlab = "Signal quarter", ylab = "", main = "Quarter-aware feature IC: stability matters more than pooled fit")
axis(1, seq_len(ncol(z)), colnames(z), las = 2, cex.axis = 0.8)
axis(2, seq_len(nrow(z)), rev(rownames(z)), las = 2, cex.axis = 0.65)
box(); dev.off()

features <- contract$feature_names
corr <- matrix(NA_real_, nrow = length(features), ncol = length(features), dimnames = list(features, features))
for (i in seq_len(nrow(redundancy_long))) {
  corr[redundancy_long$feature_a[[i]], redundancy_long$feature_b[[i]]] <- redundancy_long$rank_correlation[[i]]
}
png(file.path(visual_dir, "feature_redundancy_heatmap.png"), 1900, 1800, res = 170)
par(mar = c(12, 12, 4, 2))
image(seq_len(ncol(corr)), seq_len(nrow(corr)), t(corr[nrow(corr):1, , drop = FALSE]),
      col = colorRampPalette(c(navy, "white", orange))(101), zlim = c(-1, 1), axes = FALSE,
      xlab = "", ylab = "", main = "Feature redundancy: rank correlation across TRAIN")
axis(1, seq_len(ncol(corr)), colnames(corr), las = 2, cex.axis = 0.55)
axis(2, seq_len(nrow(corr)), rev(rownames(corr)), las = 2, cex.axis = 0.55)
box(); dev.off()

top12 <- head(scorecard$feature[order(-scorecard$mean_rank_ic)], 12L)
pooled_deciles <- aggregate(mean_relative_return ~ feature + decile, deciles, mean)
png(file.path(visual_dir, "top_feature_decile_curves.png"), 2200, 1500, res = 170)
par(mfrow = c(3, 4), mar = c(4, 4, 3, 1))
for (feature in top12) {
  x <- pooled_deciles[pooled_deciles$feature == feature, ]
  plot(x$decile, 100 * x$mean_relative_return, type = "b", pch = 19, lwd = 2,
       col = blue, xlab = "Feature decile", ylab = "Mean relative return (pp)", main = feature)
  abline(h = 0, col = gray, lty = 3)
}
dev.off()

png(file.path(visual_dir, "nested_outer_validation.png"), 2100, 1300, res = 170)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
plot(seq_len(nrow(outer)), outer$rank_ic, type = "b", pch = 19, xaxt = "n", lwd = 2,
     col = ifelse(outer$rank_ic > 0, green, red), xlab = "", ylab = "Spearman IC",
     main = "Nested outer validation")
axis(1, seq_len(nrow(outer)), outer$signal_quarter, las = 2, cex.axis = 0.8); mtext("Outer validation quarter", side = 1, line = 6)
abline(h = 0, col = gray)
plot(seq_len(nrow(outer)), 100 * outer$q4_excess, type = "b", pch = 19, xaxt = "n", lwd = 2,
     col = ifelse(outer$q4_excess > 0, green, red), xlab = "", ylab = "Top-quartile excess (pp)",
     main = "Selected top-quartile behavior")
axis(1, seq_len(nrow(outer)), outer$signal_quarter, las = 2, cex.axis = 0.8); mtext("Outer validation quarter", side = 1, line = 6)
abline(h = 0, col = gray)
dev.off()

best_inner <- do.call(rbind, lapply(split(inner_summary, interaction(inner_summary$outer_fold, inner_summary$candidate)), function(x) {
  x[which.max(x$mean_rank_ic), , drop = FALSE]
}))
png(file.path(visual_dir, "predefined_basket_competition.png"), 2100, 1300, res = 170)
par(mfrow = c(1, 2), mar = c(9, 5, 4, 1))
for (fold in 1:2) {
  x <- best_inner[best_inner$outer_fold == fold, ]
  x <- x[order(x$mean_rank_ic), ]
  barplot(x$mean_rank_ic, names.arg = sub("^(RIDGE_|FIXED_)", "", x$candidate), las = 2,
          col = ifelse(x$mean_rank_ic > 0, green, red), border = NA,
          ylab = "Best inner mean IC", main = paste("Fold", fold, "rehearsal"))
  abline(h = 0, col = gray)
}
dev.off()

png(file.path(visual_dir, "full_search_permutation.png"), 1900, 1200, res = 170)
hist(permutation$mean_outer_rank_ic, breaks = 25, col = pale, border = "white",
     xlab = "Mean outer IC after full basket search", main = "Full-search permutation null")
abline(v = unique(permutation$observed_mean_outer_rank_ic), col = purple, lwd = 4)
legend("topright", legend = c(
  paste0("Observed = ", formatC(unique(permutation$observed_mean_outer_rank_ic), digits = 3, format = "f")),
  paste0("Search-adjusted p = ", formatC(unique(permutation$search_adjusted_p_value), digits = 3, format = "f"))
), lwd = c(4, NA), col = c(purple, NA), bty = "n")
dev.off()

feature_chunks <- split(contract$feature_names, ceiling(seq_along(contract$feature_names) / 6))
for (sheet in seq_along(feature_chunks)) {
  sheet_features <- feature_chunks[[sheet]]
  png(file.path(visual_dir, sprintf("scatter_atlas_%02d.png", sheet)), 2400, 1600, res = 170)
  par(mfrow = c(2, 3), mar = c(5, 5, 4, 1))
  for (feature in sheet_features) {
    x <- panel[[feature]]; y <- 100 * panel$target_relative_return
    limits <- stats::quantile(x, c(0.01, 0.99), na.rm = TRUE)
    y_limits <- stats::quantile(y, c(0.01, 0.99), na.rm = TRUE)
    keep <- x >= limits[[1L]] & x <= limits[[2L]] & y >= y_limits[[1L]] & y <= y_limits[[2L]]
    plot(x[keep], y[keep], pch = 16, cex = 0.22, col = grDevices::adjustcolor(blue, alpha.f = 0.14),
         xlab = feature, ylab = "Next-quarter relative return (pp)", main = feature)
    d <- h042_decile(x)
    dx <- tapply(x, d, stats::median); dy <- 100 * tapply(panel$target_relative_return, d, mean)
    lines(dx, dy, col = orange, lwd = 3); points(dx, dy, col = orange, pch = 19, cex = 0.8)
    abline(h = 0, col = gray, lty = 3)
  }
  if (length(sheet_features) < 6L) for (unused in seq_len(6L - length(sheet_features))) plot.new()
  dev.off()
}

plot_spotlight <- function(feature, title) {
  x <- panel[[feature]]; y <- 100 * panel$target_relative_return
  x_limits <- stats::quantile(x, c(0.01, 0.99), na.rm = TRUE)
  y_limits <- stats::quantile(y, c(0.01, 0.99), na.rm = TRUE)
  keep <- x >= x_limits[[1L]] & x <= x_limits[[2L]] & y >= y_limits[[1L]] & y <= y_limits[[2L]]
  plot(x[keep], y[keep], pch = 16, cex = 0.35, col = grDevices::adjustcolor(blue, alpha.f = 0.16),
       xlab = feature, ylab = "Next-quarter relative return (pp)", main = title)
  d <- h042_decile(x)
  dx <- tapply(x, d, stats::median); dy <- 100 * tapply(panel$target_relative_return, d, mean)
  lines(dx, dy, col = orange, lwd = 4); points(dx, dy, col = orange, pch = 19, cex = 0.9)
  abline(h = 0, col = gray, lty = 3)
}
png(file.path(visual_dir, "scatter_spotlight_risk.png"), 2100, 1100, res = 170)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
plot_spotlight("beta126", "Beta looked attractive in pooled TRAIN")
plot_spotlight("rv126", "Realized volatility showed a similar pooled slope")
dev.off()

png(file.path(visual_dir, "scatter_spotlight_momentum.png"), 2100, 1100, res = 170)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
plot_spotlight("momentum12_1", "12-to-1 momentum: nearly flat")
plot_spotlight("ret126", "Six-month return: weak, non-monotonic")
dev.off()

top_features <- head(scorecard[order(-scorecard$mean_rank_ic),
                               c("feature", "mean_rank_ic", "positive_ic_fraction")], 8L)
selection_text <- paste(paste0("outer ", selections$outer_fold, ": ", selections$candidate,
                               ifelse(is.na(selections$lambda), "", paste0(" (lambda ", selections$lambda, ")"))),
                        collapse = "; ")
failed <- gates$gate_id[!gates$passed]
all_inner_negative <- all(best_inner$mean_rank_ic < 0)
report <- c(
  "# HYP-MOM-04.2 Feature Atlas TRAIN Report", "",
  paste0("Status: `", status, "`"), "",
  "## Scope", "",
  paste0("The packet contains ", run_spec$panel_rows, " stock-quarter rows from ", run_spec$eligible_identities,
         " coverage-eligible identities across 15 TRAIN quarters. The independent temporal evidence remains 15 quarters."),
  "No observation dated 2021 or later was queried.", "",
  "## Feature atlas", "",
  paste0("Thirty-three causal OHLCV features were examined. The strongest pooled mean quarterly IC values were: ",
         paste(paste0(top_features$feature, " (", formatC(top_features$mean_rank_ic, digits = 3, format = "f"), ")"), collapse = ", "), "."),
  paste0("There were ", nrow(redundancy_pairs), " feature pairs with absolute rank correlation at or above ",
         contract$redundancy_threshold, ". Scatter displays clip both axes to their 1st-99th percentiles for readability; all statistics use every finite observation. Scatter and decile plots are descriptive rather than promotion evidence."), "",
  "## Nested basket readout", "",
  paste0("Selections: ", selection_text, "."),
  if (all_inner_negative) "Every predefined basket's best inner-validation mean IC was negative in both outer rehearsals." else "At least one predefined basket had positive inner-validation mean IC.",
  paste0("Mean outer IC: ", formatC(mean(outer$rank_ic), digits = 4, format = "f"),
         "; positive quarters: ", sum(outer$rank_ic > 0), " / 6."),
  paste0("Mean outer top-quartile excess: ", formatC(100 * mean(outer$q4_excess), digits = 2, format = "f"),
         " pp; positive quarters: ", sum(outer$q4_excess > 0), " / 6."),
  paste0("Frozen original-six challenger mean outer IC: ", formatC(mean(original$rank_ic), digits = 4, format = "f"), "."),
  paste0("Full-search permutation p-value: ", formatC(unique(permutation$search_adjusted_p_value), digits = 3, format = "f"), "."), "",
  "## Decision", "",
  paste0("Failed gates: ", paste(failed, collapse = ", "), "."),
  "Record STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN. The atlas is useful for feature education, but no feature basket earned access to reserved OOS evidence."
)
writeLines(report, file.path(run_dir, "REPORT.md"))
cat("Rendered HYP-MOM-04.2 evidence from retained TRAIN outputs:\n", run_dir, "\n")
