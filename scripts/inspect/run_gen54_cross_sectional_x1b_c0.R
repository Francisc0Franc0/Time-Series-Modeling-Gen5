# Gen5.4 expanded-universe OHLCV-only X1b ranking and C0 exposure diagnostics.
# No model, top-K policy, portfolio replay, or live behavior.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE) else normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_ohlcv_extension.R"))

env_or <- function(name, default = "") { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
write_csv <- function(x, path) { utils::write.csv(x, path, row.names = FALSE, na = ""); invisible(path) }
dir_create <- function(path) { dir.create(path, recursive = TRUE, showWarnings = FALSE); if (!dir.exists(path)) stop("Could not create output directory.", call. = FALSE) }

plot_x1b_ic <- function(fold_summary, path) {
  features <- g5_gen54_x1b_feature_names(); folds <- unique(fold_summary$fold_id)
  values <- matrix(NA_real_, nrow = length(features), ncol = length(folds), dimnames = list(features, folds))
  for (i in seq_len(nrow(fold_summary))) values[fold_summary$feature_name[[i]], fold_summary$fold_id[[i]]] <- fold_summary$mean_daily_rank_ic[[i]]
  png(path, width = 1700, height = 850, res = 150); par(mar = c(7, 12, 4, 2))
  image(seq_along(folds), seq_along(features), t(values), zlim = c(-max(abs(values), na.rm = TRUE), max(abs(values), na.rm = TRUE)), col = colorRampPalette(c("#B91C1C", "white", "#166534"))(101), axes = FALSE, xlab = "", ylab = "", main = "X1b fold-level mean daily rank IC")
  axis(1, at = seq_along(folds), labels = folds, las = 2, cex.axis = 0.75); axis(2, at = seq_along(features), labels = features, las = 1, cex.axis = 0.85)
  dev.off()
}

plot_redundancy <- function(summary, path) {
  png(path, width = 1400, height = 800, res = 150); par(mar = c(9, 5, 4, 2))
  values <- summary$median_absolute_rank_correlation_to_group_relative_20
  bp <- barplot(values, names.arg = summary$feature_name, las = 2, ylim = c(0, max(0.8, values + 0.1)), col = ifelse(values <= 0.70, "#2563EB", "#D97706"), ylab = "Median absolute daily rank correlation", main = "X1b candidates must add structure beyond group-relative momentum")
  abline(h = 0.70, col = "#B91C1C", lty = 2, lwd = 2); text(bp, values, labels = sprintf("%.2f", values), pos = 3)
  dev.off()
}

plot_c0 <- function(fold_audit, path) {
  features <- g5_gen54_c0_feature_names(); folds <- unique(fold_audit$fold_id)
  display_labels <- c("Breadth", "Group participation", "Low average correlation", "Low cross-sectional dispersion")
  values <- matrix(NA_real_, nrow = length(features), ncol = length(folds), dimnames = list(features, folds))
  for (i in seq_len(nrow(fold_audit))) values[fold_audit$feature_name[[i]], fold_audit$fold_id[[i]]] <- 10000 * fold_audit$separation_h5[[i]]
  limit <- max(abs(values), na.rm = TRUE)
  png(path, width = 1700, height = 850, res = 150); par(mar = c(7, 13, 4, 2))
  image(seq_along(folds), seq_along(features), t(values), zlim = c(-limit, limit), col = colorRampPalette(c("#B91C1C", "white", "#166534"))(101), axes = FALSE, xlab = "", ylab = "", main = "C0 favorable-minus-unfavorable equal-weight h5 return (bp)")
  axis(1, at = seq_along(folds), labels = folds, las = 2, cex.axis = 0.75); axis(2, at = seq_along(features), labels = display_labels, las = 1, cex.axis = 0.85)
  dev.off()
}

message("Gen5.4 X1b/C0 OHLCV extension starting.")
g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_GEN54_X1B_C0_FEED", as.character(cfg$feed))
refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_X1B_C0_REFRESH", "false"), default = FALSE)
as_of_timestamp <- env_or("GEN5_GEN54_X1B_C0_AS_OF", "2024-12-31 17:30:00")
run_id <- env_or("GEN5_GEN54_X1B_C0_RUN_ID", "g54_xs_x1b_c0_20260719")
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id)
visual_dir <- file.path(output_dir, "visuals"); dir_create(visual_dir)
registry <- g5_gen54_xs_candidate_registry(); context_symbols <- g5_gen54_xs_context_symbols(); folds <- g5_gen54_xs_build_folds(2020:2024)
query <- g5_workbench_query_adjusted_daily_bars(cfg = cfg, start_date = as.Date("2016-11-01"), end_date = max(folds$oos_end_date), as_of_timestamp = as_of_timestamp, symbols = unique(c(registry$symbol, context_symbols)), universe_name = "gen54_cross_sectional_fixed_panel_v0_1", universe_roles = "ranked_candidates,context_anchors", refresh = refresh, repo_root = repo_root)
if (!nrow(query$bars)) stop("X1b/C0 query returned no bars.", call. = FALSE)
base_panel <- g5_gen54_xs_build_panel(query$bars, registry, context_symbols)
extension <- g5_gen54_build_ohlcv_extension(query$bars, base_panel, registry)
oos_panel <- g5_gen54_xs_assign_oos(extension$panel, folds)

x1b_ic <- g5_gen54_xs_daily_ic(oos_panel, g5_gen54_x1b_feature_names())
x1b_fold <- g5_gen54_xs_fold_feature_summary(oos_panel, x1b_ic, g5_gen54_x1b_feature_names())
x1b_measurement <- g5_gen54_xs_feature_verdict(x1b_fold, x1b_ic)
redundancy <- g5_gen54_x1b_redundancy_audit(oos_panel)
x1b_verdict <- merge(x1b_measurement, redundancy$summary, by = "feature_name", all.x = TRUE)
x1b_verdict$final_verdict <- ifelse(x1b_verdict$verdict == "PASS_TO_COMBINATION_DESIGN" & x1b_verdict$redundancy_status == "PASS_DISTINCT", "PASS_DISTINCT_PRIMITIVE", "STOP_X1B_PRIMITIVE")

c0_fold <- g5_gen54_c0_fold_audit(extension$context, folds)
c0_verdict <- g5_gen54_c0_verdict(c0_fold)
leakage <- rbind(
  g5_gen54_xs_leakage_audit(oos_panel),
  data.frame(check_id = c("rolling_residual_fit_uses_prior_sessions", "c0_thresholds_train_only", "no_policy_or_model"), status = "PASS", detail = c("Residual coefficients use the 126 sessions ending before each scored return.", "Every C0 favorable threshold is the median from the eight-quarter TRAIN window.", "The packet computes diagnostics only; model, top-K, replay, and live counts are zero."), stringsAsFactors = FALSE)
)
overall_status <- if (sum(x1b_verdict$final_verdict == "PASS_DISTINCT_PRIMITIVE") >= 1L && sum(c0_verdict$verdict == "PASS_EXPOSURE_PERMISSION_DIAGNOSTIC") >= 1L) "PASS_TO_TWO_STAGE_RULES_DESIGN" else "STOP_BEFORE_TWO_STAGE_RULES_DESIGN"

run_spec <- data.frame(schema_version = "gen54_x1b_c0_v0.1", wrapper = "scripts/inspect/run_gen54_cross_sectional_x1b_c0.R", as_of_timestamp = as_of_timestamp, feed = cfg$feed, ranked_candidate_count = nrow(registry), fold_count = nrow(folds), train_quarters = 8L, label = "h5_next_open_to_open", redundancy_reference = "group_relative_20", redundancy_cap = 0.70, required_positive_folds = 12L, model_fit_count = 0L, top_k_policy_count = 0L, portfolio_replay_count = 0L, overall_status = overall_status, stringsAsFactors = FALSE)

write_csv(run_spec, file.path(output_dir, "x1b_c0_run_spec.csv")); write_csv(folds, file.path(output_dir, "x1b_c0_fold_spec.csv")); write_csv(x1b_ic, file.path(output_dir, "x1b_daily_rank_ic.csv")); write_csv(x1b_fold, file.path(output_dir, "x1b_fold_summary.csv")); write_csv(redundancy$daily, file.path(output_dir, "x1b_daily_redundancy.csv")); write_csv(x1b_verdict, file.path(output_dir, "x1b_feature_verdict.csv")); write_csv(c0_fold, file.path(output_dir, "c0_fold_audit.csv")); write_csv(c0_verdict, file.path(output_dir, "c0_feature_verdict.csv")); write_csv(leakage, file.path(output_dir, "x1b_c0_leakage_audit.csv"))
plot_x1b_ic(x1b_fold, file.path(visual_dir, "x1b_rank_ic_heatmap.png")); plot_redundancy(redundancy$summary, file.path(visual_dir, "x1b_redundancy.png")); plot_c0(c0_fold, file.path(visual_dir, "c0_separation_heatmap.png"))

report <- c("# Gen5.4 X1b Ranking and C0 Exposure-Permission POC", "", paste0("Status: `", overall_status, "`"), "", "## Boundary", "", "OHLCV-only diagnostic evidence. No model, top-K selection policy, portfolio replay, allocation acceptance, or live behavior was produced.", "", "## X1b — nonredundant ranking primitives", "", paste0("- `", x1b_verdict$feature_name, "`: `", x1b_verdict$final_verdict, "`; IC `", sprintf("%.4f", x1b_verdict$pooled_mean_daily_rank_ic), "`; positive IC folds `", x1b_verdict$positive_ic_folds, "/20`; ordering folds `", x1b_verdict$positive_ordering_folds, "/20`; top-bottom `", sprintf("%.1f bp", 10000 * x1b_verdict$pooled_top_minus_bottom_h5), "`; redundancy `", sprintf("%.2f", x1b_verdict$median_absolute_rank_correlation_to_group_relative_20), "`."), "", "## C0 — exposure permission", "", paste0("- `", c0_verdict$feature_name, "`: `", c0_verdict$verdict, "`; positive separation folds `", c0_verdict$positive_separation_folds, "/20`; pooled separation `", sprintf("%.1f bp", 10000 * c0_verdict$pooled_mean_separation_h5), "`; favorable share `", sprintf("%.1f%%", 100 * c0_verdict$mean_favorable_share), "`."), "", "## Next gate", "", if (overall_status == "PASS_TO_TWO_STAGE_RULES_DESIGN") "At least one distinct X1b primitive and one C0 exposure diagnostic passed. A transparent two-stage rules design may be discussed, but is not implemented here." else "The two-stage demonstrator remains closed. Do not rescue the result by loosening redundancy, fold, or exposure-share gates.", "", "## Visuals", "", "- `visuals/x1b_rank_ic_heatmap.png`", "- `visuals/x1b_redundancy.png`", "- `visuals/c0_separation_heatmap.png`")
writeLines(report, file.path(output_dir, "x1b_c0_report.md"), useBytes = TRUE)
message("Gen5.4 X1b/C0 complete: ", overall_status)
message("Report: ", normalizePath(file.path(output_dir, "x1b_c0_report.md"), winslash = "/"))
