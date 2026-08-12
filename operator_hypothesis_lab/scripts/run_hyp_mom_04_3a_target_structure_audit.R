options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_2_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_3a_engine.R"))

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}
aggregate_mean <- function(data, value, groups) {
  stats::aggregate(data[[value]], data[groups], mean, na.rm = TRUE)
}

contract <- h043a_validate_contract()
source_dir <- env_or(
  "GEN5_HYP_MOM_043A_SOURCE_DIR",
  file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", contract$source_run_id)
)
source_dir <- normalizePath(source_dir, winslash = "/", mustWork = TRUE)
run_id <- env_or("GEN5_HYP_MOM_043A_RUN_ID", "hyp_mom_04_3a_target_structure_audit_20260811")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

source_status <- trimws(readLines(file.path(source_dir, "status.txt"), warn = FALSE)[[1L]])
source_integrity <- utils::read.csv(file.path(source_dir, "hyp_mom_04_2_integrity.csv"), stringsAsFactors = FALSE)
source_panel <- utils::read.csv(file.path(source_dir, "hyp_mom_04_2_feature_panel.csv"), stringsAsFactors = FALSE)

message("Running frozen HYP-MOM-04.3A target audit from retained TRAIN evidence...")
audit <- h043a_run_audit(source_panel, source_status, source_integrity, contract)
status <- "TARGET_AUDIT_COMPLETE_SELECTION_NOT_FROZEN"

target_dictionary <- h043a_target_dictionary()
baseline_dictionary <- h043a_baseline_dictionary()
target_long <- h043a_target_long(audit$panel)

scale_summary <- do.call(rbind, lapply(contract$target_ids, function(target) {
  x <- audit$scale[audit$scale$target_id == target, , drop = FALSE]
  data.frame(
    target_id = target,
    mean_quarter_sd = mean(x$sd), mean_quarter_iqr = mean(x$iqr),
    mean_p90_minus_p10 = mean(x$p90_minus_p10), mean_positive_fraction = mean(x$positive_fraction),
    mean_top_1pct_absolute_mass_share = mean(x$top_1pct_absolute_mass_share),
    mean_winsorized_to_raw_sd = mean(x$winsorized_to_raw_sd), stringsAsFactors = FALSE
  )
}))

agreement_groups <- paste(audit$agreement$target_a, audit$agreement$target_b, sep = "__")
agreement_summary <- do.call(rbind, lapply(split(audit$agreement, agreement_groups), function(x) {
  data.frame(
    target_a = x$target_a[[1L]], target_b = x$target_b[[1L]],
    mean_rank_correlation = mean(x$rank_correlation), min_rank_correlation = min(x$rank_correlation),
    mean_top_quartile_jaccard = mean(x$top_quartile_jaccard),
    mean_sign_agreement = mean(x$sign_agreement), stringsAsFactors = FALSE
  )
}))

decomposition_summary <- data.frame(
  mean_sector_r2 = mean(audit$decomposition$sector_r2),
  mean_beta_r2 = mean(audit$decomposition$beta_r2),
  mean_sector_beta_r2 = mean(audit$decomposition$sector_beta_r2),
  mean_incremental_beta_after_sector_r2 = mean(audit$decomposition$incremental_beta_after_sector_r2),
  max_sector_beta_r2 = max(audit$decomposition$sector_beta_r2),
  max_sector_beta_quarter = audit$decomposition$signal_quarter[which.max(audit$decomposition$sector_beta_r2)],
  stringsAsFactors = FALSE
)

concentration_summary <- do.call(rbind, lapply(contract$target_ids, function(target) {
  x <- audit$concentration[audit$concentration$target_id == target, , drop = FALSE]
  data.frame(
    target_id = target, mean_max_sector_share = mean(x$max_sector_share),
    max_max_sector_share = max(x$max_sector_share), mean_sector_hhi = mean(x$sector_hhi),
    stringsAsFactors = FALSE
  )
}))

run_spec <- data.frame(
  program_id = contract$program_id, run_id = run_id, source_program_id = contract$source_program_id,
  source_run_id = contract$source_run_id, source_status = source_status,
  eligible_identities = length(unique(audit$panel$symbol)), panel_rows = nrow(audit$panel),
  train_quarters = length(unique(audit$panel$signal_quarter)), target_count = length(contract$target_ids),
  feature_count = length(contract$feature_names), provider_calls = 0L,
  forbidden_start = as.character(contract$forbidden_start), created_without_oos_access = TRUE,
  status = status, stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "hyp_mom_04_3a_run_spec.csv"))
write_csv(audit$integrity, file.path(output_dir, "hyp_mom_04_3a_integrity.csv"))
write_csv(target_dictionary, file.path(output_dir, "hyp_mom_04_3a_target_dictionary.csv"))
write_csv(baseline_dictionary, file.path(output_dir, "hyp_mom_04_3a_baseline_dictionary.csv"))
write_csv(target_long, file.path(output_dir, "hyp_mom_04_3a_target_panel_long.csv"))
write_csv(audit$scale, file.path(output_dir, "hyp_mom_04_3a_target_scale_by_quarter.csv"))
write_csv(scale_summary, file.path(output_dir, "hyp_mom_04_3a_target_scale_summary.csv"))
write_csv(audit$agreement, file.path(output_dir, "hyp_mom_04_3a_target_agreement_by_quarter.csv"))
write_csv(agreement_summary, file.path(output_dir, "hyp_mom_04_3a_target_agreement_summary.csv"))
write_csv(audit$decomposition, file.path(output_dir, "hyp_mom_04_3a_return_decomposition_by_quarter.csv"))
write_csv(decomposition_summary, file.path(output_dir, "hyp_mom_04_3a_return_decomposition_summary.csv"))
write_csv(audit$concentration, file.path(output_dir, "hyp_mom_04_3a_sector_concentration_by_quarter.csv"))
write_csv(concentration_summary, file.path(output_dir, "hyp_mom_04_3a_sector_concentration_summary.csv"))
write_csv(audit$baseline_ic, file.path(output_dir, "hyp_mom_04_3a_baseline_ic_by_quarter.csv"))
write_csv(audit$baseline_summary, file.path(output_dir, "hyp_mom_04_3a_baseline_ic_summary.csv"))
write_csv(audit$feature_ic, file.path(output_dir, "hyp_mom_04_3a_feature_ic_by_quarter.csv"))
write_csv(audit$feature_summary, file.path(output_dir, "hyp_mom_04_3a_feature_ic_summary.csv"))
writeLines(status, file.path(output_dir, "status.txt"))
saveRDS(list(contract = contract, status = status, created_without_oos_access = TRUE),
        file.path(output_dir, "hyp_mom_04_3a_audit_authority.rds"))

navy <- "#142B4A"; blue <- "#167D9A"; cyan <- "#6DCBF4"; green <- "#2AA876"
red <- "#D1495B"; orange <- "#F28E2B"; gray <- "#67717E"; pale <- "#D9EEF3"; purple <- "#7A5195"
target_colors <- c(UNIVERSE_RELATIVE = blue, SECTOR_RELATIVE = green, SECTOR_BETA_RESIDUAL = purple)

png(file.path(visual_dir, "target_scale_by_quarter.png"), 2100, 1300, res = 170)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 1))
for (metric in c("sd", "top_1pct_absolute_mass_share")) {
  matrix_values <- sapply(contract$target_ids, function(target) {
    audit$scale[audit$scale$target_id == target, metric]
  })
  matplot(seq_len(nrow(matrix_values)), matrix_values, type = "b", pch = 19, lty = 1, lwd = 2,
          xaxt = "n", col = target_colors[colnames(matrix_values)], xlab = "Signal quarter",
          ylab = if (metric == "sd") "Cross-sectional standard deviation" else "Top 1% share of absolute target mass",
          main = if (metric == "sd") "Target dispersion changes through time" else "A few names can dominate target magnitude")
  axis(1, seq_len(nrow(matrix_values)), contract$train_signal_quarters, las = 2, cex.axis = 0.75)
  legend("topleft", legend = names(target_colors), col = target_colors, lty = 1, pch = 19, bty = "n", cex = 0.72)
}
dev.off()

png(file.path(visual_dir, "return_decomposition.png"), 2000, 1250, res = 170)
par(mar = c(7, 5, 4, 2))
matplot(seq_len(nrow(audit$decomposition)), audit$decomposition[c("sector_r2", "beta_r2", "sector_beta_r2")],
        type = "b", pch = 19, lty = 1, lwd = 2, xaxt = "n", col = c(green, orange, navy),
        xlab = "Signal quarter", ylab = "Cross-sectional R-squared",
        main = "Sector and prior beta explain a time-varying share of next-quarter returns")
axis(1, seq_len(nrow(audit$decomposition)), audit$decomposition$signal_quarter, las = 2)
legend("topleft", legend = c("Sector only", "Beta only", "Sector + beta"), col = c(green, orange, navy),
       lty = 1, pch = 19, bty = "n")
dev.off()

pair_labels <- paste(audit$agreement$target_a, audit$agreement$target_b, sep = " vs ")
pair_ids <- unique(pair_labels)
png(file.path(visual_dir, "target_agreement.png"), 2150, 1300, res = 170)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 1))
for (metric in c("rank_correlation", "top_quartile_jaccard")) {
  matrix_values <- sapply(pair_ids, function(pair) audit$agreement[pair_labels == pair, metric])
  matplot(seq_len(nrow(matrix_values)), matrix_values, type = "b", pch = 19, lty = 1, lwd = 2,
          xaxt = "n", col = c(blue, green, purple), ylim = c(0, 1), xlab = "Signal quarter",
          ylab = if (metric == "rank_correlation") "Spearman rank agreement" else "Top-quartile Jaccard overlap",
          main = if (metric == "rank_correlation") "Target rankings are similar—but not identical" else "The selected winner set changes materially")
  axis(1, seq_len(nrow(matrix_values)), contract$train_signal_quarters, las = 2, cex.axis = 0.75)
  legend("bottomleft", legend = gsub("_", " ", pair_ids), col = c(blue, green, purple), lty = 1, pch = 19, bty = "n", cex = 0.63)
}
dev.off()

png(file.path(visual_dir, "sector_concentration.png"), 2000, 1250, res = 170)
par(mar = c(7, 5, 4, 2))
concentration_matrix <- sapply(contract$target_ids, function(target) {
  audit$concentration[audit$concentration$target_id == target, "max_sector_share"]
})
matplot(seq_len(nrow(concentration_matrix)), concentration_matrix, type = "b", pch = 19, lty = 1, lwd = 2,
        xaxt = "n", col = target_colors[colnames(concentration_matrix)], ylim = c(0, max(concentration_matrix) * 1.08),
        xlab = "Signal quarter", ylab = "Largest sector share of realized top quartile",
        main = "Sector-relative targets mechanically reduce winner-set sector concentration")
axis(1, seq_len(nrow(concentration_matrix)), contract$train_signal_quarters, las = 2)
legend("topleft", legend = names(target_colors), col = target_colors, lty = 1, pch = 19, bty = "n")
dev.off()

baseline_matrix <- xtabs(mean_rank_ic ~ item + target_id, audit$baseline_summary)
png(file.path(visual_dir, "baseline_target_map.png"), 2100, 1250, res = 170)
par(mar = c(10, 15, 4, 3))
image(seq_len(ncol(baseline_matrix)), seq_len(nrow(baseline_matrix)), t(baseline_matrix[nrow(baseline_matrix):1, , drop = FALSE]),
      col = colorRampPalette(c(red, "white", green))(101), zlim = c(-0.12, 0.12), axes = FALSE,
      xlab = "Target", ylab = "", main = "Simple baseline relationships depend on the target definition")
axis(1, seq_len(ncol(baseline_matrix)), gsub("_", "\n", colnames(baseline_matrix)), cex.axis = 0.72)
axis(2, seq_len(nrow(baseline_matrix)), rev(gsub("_", " ", rownames(baseline_matrix))), las = 2, cex.axis = 0.78)
for (r in seq_len(nrow(baseline_matrix))) for (c in seq_len(ncol(baseline_matrix))) {
  text(c, nrow(baseline_matrix) - r + 1, sprintf("%+.03f", baseline_matrix[r, c]), cex = 0.9)
}
box(); dev.off()

feature_summary_wide <- reshape(audit$feature_summary[c("item", "target_id", "mean_rank_ic")],
                                idvar = "item", timevar = "target_id", direction = "wide")
names(feature_summary_wide) <- sub("mean_rank_ic\\.", "", names(feature_summary_wide))
png(file.path(visual_dir, "feature_target_shift.png"), 2100, 1300, res = 170)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
for (challenger in c("SECTOR_RELATIVE", "SECTOR_BETA_RESIDUAL")) {
  x <- feature_summary_wide$UNIVERSE_RELATIVE; y <- feature_summary_wide[[challenger]]
  plot(x, y, pch = 19, col = blue, xlim = range(c(x, y)), ylim = range(c(x, y)),
       xlab = "Mean IC vs universe-relative target", ylab = paste("Mean IC vs", gsub("_", " ", tolower(challenger))),
       main = paste("Changing the target reorders feature evidence"))
  abline(0, 1, col = gray, lty = 2); abline(h = 0, v = 0, col = pale)
  delta <- abs(y - x); labels <- order(delta, decreasing = TRUE)[seq_len(min(6L, length(delta)))]
  text(x[labels], y[labels], feature_summary_wide$item[labels], pos = 4, cex = 0.72)
}
dev.off()

png(file.path(visual_dir, "feature_ic_by_target.png"), 2400, 1900, res = 170)
par(mfrow = c(1, 3), mar = c(7, 10, 4, 2))
for (target in contract$target_ids) {
  z <- xtabs(rank_ic ~ feature + signal_quarter, audit$feature_ic[audit$feature_ic$target_id == target, ])
  z_clip <- z; z_clip[] <- pmax(-0.25, pmin(0.25, z))
  image(seq_len(ncol(z_clip)), seq_len(nrow(z_clip)), t(z_clip[nrow(z_clip):1, , drop = FALSE]),
        col = colorRampPalette(c(red, "white", green))(101), zlim = c(-0.25, 0.25), axes = FALSE,
        xlab = "Quarter", ylab = "", main = gsub("_", " ", target))
  axis(1, seq_len(ncol(z_clip)), colnames(z_clip), las = 2, cex.axis = 0.55)
  axis(2, seq_len(nrow(z_clip)), rev(rownames(z_clip)), las = 2, cex.axis = 0.48)
  box()
}
dev.off()

png(file.path(visual_dir, "target_scatter_comparison.png"), 2100, 1300, res = 170)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
reference <- audit$panel$target_universe_relative
for (column in c("target_sector_relative", "target_sector_beta_residual")) {
  challenger <- audit$panel[[column]]
  xlim <- stats::quantile(reference, c(0.01, 0.99)); ylim <- stats::quantile(challenger, c(0.01, 0.99))
  keep <- reference >= xlim[[1L]] & reference <= xlim[[2L]] & challenger >= ylim[[1L]] & challenger <= ylim[[2L]]
  plot(100 * reference[keep], 100 * challenger[keep], pch = 16, cex = 0.28,
       col = grDevices::adjustcolor(blue, alpha.f = 0.16),
       xlab = "Universe-relative target (pp)", ylab = paste(gsub("target_", "", gsub("_", " ", column)), "(pp)"),
       main = "The same stock-quarter can move materially")
  abline(0, 1, col = orange, lwd = 2); abline(h = 0, v = 0, col = gray, lty = 3)
}
dev.off()

mean_agreement <- agreement_summary[order(agreement_summary$mean_rank_correlation), ][1L, ]
mean_scale <- scale_summary[match(contract$target_ids, scale_summary$target_id), ]
feature_shift <- max(abs(feature_summary_wide$UNIVERSE_RELATIVE - feature_summary_wide$SECTOR_RELATIVE))
report <- c(
  "# HYP-MOM-04.3A Target Structure Audit", "",
  paste0("Status: `", status, "`"), "",
  "## Scope", "",
  paste0("The audit reused ", nrow(audit$panel), " retained stock-quarter rows from ",
         length(unique(audit$panel$symbol)), " identities across 15 TRAIN quarters. No provider call was made and no 2021+ observation was accessed."), "",
  "## Target terminology", "",
  "The H04.2 reference target was eligible-universe-relative, not literally SPY-relative. Subtracting a quarter-level SPY return would preserve cross-sectional ranks but change numerical excess-return levels.", "",
  "## Return decomposition", "",
  paste0("Sector alone explained an average ", sprintf("%.1f%%", 100 * decomposition_summary$mean_sector_r2),
         " of same-quarter cross-sectional next-quarter return variation. Prior beta alone explained ",
         sprintf("%.1f%%", 100 * decomposition_summary$mean_beta_r2), ", and sector plus beta explained ",
         sprintf("%.1f%%", 100 * decomposition_summary$mean_sector_beta_r2), "."),
  paste0("The largest sector-plus-beta share was ", sprintf("%.1f%%", 100 * decomposition_summary$max_sector_beta_r2),
         " in ", decomposition_summary$max_sector_beta_quarter, "."), "",
  "## Target agreement", "",
  paste0("The least-aligned pair was ", mean_agreement$target_a, " versus ", mean_agreement$target_b,
         ": mean rank correlation ", sprintf("%.3f", mean_agreement$mean_rank_correlation),
         " and mean realized top-quartile Jaccard overlap ", sprintf("%.3f", mean_agreement$mean_top_quartile_jaccard), "."),
  paste0("The largest change in a feature's 15-quarter mean IC when moving from the reference to sector-relative target was ",
         sprintf("%.3f", feature_shift), "."), "",
  "## Interpretation boundary", "",
  "This audit describes what each target removes and how feature evidence changes. It does not select a target, feature basket, model, or portfolio. The next decision belongs to the operator under a new frozen contract."
)
writeLines(report, file.path(output_dir, "REPORT.md"))

cat("Status:", status, "\n")
cat("Output:", normalizePath(output_dir, winslash = "/", mustWork = TRUE), "\n")
print(decomposition_summary)
print(agreement_summary)
print(concentration_summary)
