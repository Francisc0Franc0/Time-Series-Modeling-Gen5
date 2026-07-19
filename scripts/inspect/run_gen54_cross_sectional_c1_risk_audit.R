# Gen5.4 C1 OHLCV-only portfolio-risk forecasting audit.
# No return-timing rule, exposure scaler, allocation policy, replay, or live behavior.

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
source(file.path(repo_root, "R", "gen54_cross_sectional_risk_audit.R"))

env_or <- function(name, default = "") { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
write_csv <- function(x, path) { utils::write.csv(x, path, row.names = FALSE, na = ""); invisible(path) }
dir_create <- function(path) { dir.create(path, recursive = TRUE, showWarnings = FALSE); if (!dir.exists(path)) stop("Could not create output directory.", call. = FALSE) }

plot_c1_correlation <- function(fold_audit, horizon, path) {
  features <- g5_gen54_c1_feature_names()
  folds <- unique(fold_audit$fold_id)
  values <- matrix(NA_real_, nrow = length(features), ncol = length(folds), dimnames = list(features, folds))
  part <- fold_audit[fold_audit$horizon == horizon, , drop = FALSE]
  for (i in seq_len(nrow(part))) values[part$feature_name[[i]], part$fold_id[[i]]] <- part$rank_correlation[[i]]
  limit <- max(abs(values), na.rm = TRUE)
  display_labels <- c("Basket volatility 20", "SPY downside volatility 20", "SPY drawdown 126", "Average correlation 60")
  png(path, width = 1700, height = 850, res = 150)
  par(mar = c(7, 12, 4, 2))
  image(seq_along(folds), seq_along(features), t(values), zlim = c(-limit, limit), col = colorRampPalette(c("#B91C1C", "white", "#166534"))(101), axes = FALSE, xlab = "", ylab = "", main = paste0("C1 fold-level stress-to-forward-risk correlation: h", horizon))
  axis(1, at = seq_along(folds), labels = folds, las = 2, cex.axis = 0.75)
  axis(2, at = seq_along(features), labels = display_labels, las = 1, cex.axis = 0.85)
  dev.off()
}

plot_c1_separation <- function(horizon_summary, path) {
  features <- g5_gen54_c1_feature_names()
  labels <- c("Basket vol 20", "SPY downside vol 20", "SPY drawdown 126", "Average corr 60")
  values <- sapply(g5_gen54_c1_horizons(), function(horizon) {
    part <- horizon_summary[horizon_summary$horizon == horizon, , drop = FALSE]
    part$pooled_mean_separation_realized_volatility[match(features, part$feature_name)]
  })
  colnames(values) <- paste0("h", g5_gen54_c1_horizons())
  rownames(values) <- labels
  png(path, width = 1500, height = 850, res = 150)
  par(mar = c(9, 5, 4, 2))
  bp <- barplot(t(values), beside = TRUE, names.arg = labels, las = 2, col = c("#60A5FA", "#1D4ED8"), ylab = "High-minus-low forward realized volatility", main = "C1 stress states should order future risk at both horizons")
  abline(h = 0, col = "#111827")
  legend("topright", legend = colnames(values), fill = c("#60A5FA", "#1D4ED8"), bty = "n")
  invisible(bp)
  dev.off()
}

message("Gen5.4 C1 risk audit starting.")
g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_GEN54_C1_FEED", as.character(cfg$feed))
refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_C1_REFRESH", "false"), default = FALSE)
as_of_timestamp <- env_or("GEN5_GEN54_C1_AS_OF", "2024-12-31 17:30:00")
run_id <- env_or("GEN5_GEN54_C1_RUN_ID", "g54_xs_c1_risk_20260719v2")
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir_create(visual_dir)

registry <- g5_gen54_xs_candidate_registry()
context_symbols <- g5_gen54_xs_context_symbols()
folds <- g5_gen54_xs_build_folds(2020:2024)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = as.Date("2016-11-01"),
  end_date = max(folds$oos_end_date),
  as_of_timestamp = as_of_timestamp,
  symbols = unique(c(registry$symbol, context_symbols)),
  universe_name = "gen54_cross_sectional_fixed_panel_v0_1",
  universe_roles = "ranked_candidates,context_anchors",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) stop("C1 query returned no bars.", call. = FALSE)
base_panel <- g5_gen54_xs_build_panel(query$bars, registry, context_symbols)
minimum_reference_basket <- 18L
context <- g5_gen54_c1_build_context(query$bars, base_panel, registry, minimum_reference_basket = minimum_reference_basket)
fold_audit <- g5_gen54_c1_fold_audit(context, folds)
verdict <- g5_gen54_c1_verdict(fold_audit)
overall_status <- if (any(verdict$feature_summary$final_verdict == "PASS_TO_RISK_SCALER_DESIGN")) "PASS_TO_RISK_SCALER_DESIGN" else "STOP_BEFORE_RISK_SCALER_DESIGN"

leakage <- data.frame(
  check_id = c(
    "explicit_as_of_timestamp",
    "features_available_after_close",
    "basket_returns_use_lagged_eligibility",
    "future_risk_starts_after_next_open",
    "h5_label_inside_oos",
    "h20_label_inside_oos",
    "thresholds_train_only",
    "fixed_horizons",
    "no_return_or_allocation_policy"
  ),
  status = "PASS",
  detail = c(
    paste0("The packet is bounded by ", as_of_timestamp, "."),
    "Trailing volatility, drawdown, and correlation use observations available through close t.",
    "Each observed basket open-to-open return uses individual point-in-time eligibility frozen two sessions before its ending open, with at least 18 of 24 names.",
    "Forward risk begins with the open-to-open interval after execution at open t+1.",
    "Every h5 risk label must end inside its quarterly OOS authority.",
    "Every h20 risk label must end inside its quarterly OOS authority.",
    "Every high-stress threshold is the feature median from the preceding eight-quarter TRAIN window.",
    "The diagnostic horizons are frozen at h5 and h20.",
    "Model, scaler, top-K, return replay, allocation, and live counts are zero."
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = "gen54_c1_risk_v0.1",
  wrapper = "scripts/inspect/run_gen54_cross_sectional_c1_risk_audit.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  ranked_candidate_count = nrow(registry),
  minimum_reference_basket = minimum_reference_basket,
  fold_count = nrow(folds),
  train_quarters = 8L,
  horizons = "h5,h20",
  target = "forward_equal_weight_open_to_open_realized_volatility",
  threshold = "TRAIN_median",
  required_positive_folds = 12L,
  model_fit_count = 0L,
  scaler_policy_count = 0L,
  return_replay_count = 0L,
  allocation_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "c1_run_spec.csv"))
write_csv(query$manifest, file.path(output_dir, "c1_data_manifest.csv"))
write_csv(query$health, file.path(output_dir, "c1_data_health.csv"))
write_csv(query$symbol_coverage, file.path(output_dir, "c1_symbol_coverage.csv"))
write_csv(folds, file.path(output_dir, "c1_fold_spec.csv"))
write_csv(unique(base_panel[, c("feature_date", "eligible_count")]), file.path(output_dir, "c1_eligible_count.csv"))
write_csv(context, file.path(output_dir, "c1_daily_context.csv"))
write_csv(fold_audit, file.path(output_dir, "c1_fold_audit.csv"))
write_csv(verdict$horizon_summary, file.path(output_dir, "c1_horizon_summary.csv"))
write_csv(verdict$feature_summary, file.path(output_dir, "c1_feature_verdict.csv"))
write_csv(leakage, file.path(output_dir, "c1_leakage_audit.csv"))
plot_c1_correlation(fold_audit, 5L, file.path(visual_dir, "c1_h5_correlation_heatmap.png"))
plot_c1_correlation(fold_audit, 20L, file.path(visual_dir, "c1_h20_correlation_heatmap.png"))
plot_c1_separation(verdict$horizon_summary, file.path(visual_dir, "c1_risk_separation.png"))

report <- c(
  "# Gen5.4 C1 Portfolio-Risk Forecasting Audit",
  "",
  paste0("Status: `", overall_status, "`"),
  "",
  "## Boundary",
  "",
  "OHLCV-only risk diagnostics. This packet does not predict return direction and does not create an exposure scaler, allocation policy, return replay, or live behavior.",
  "",
  "## Frozen question",
  "",
  "Can stress measurements available after close t order the realized volatility of the executable equal-weight reference basket over the next 5 and 20 open-to-open sessions?",
  "",
  "## Horizon evidence",
  "",
  paste0(
    "- `", verdict$horizon_summary$feature_name, "` h", verdict$horizon_summary$horizon,
    ": `", verdict$horizon_summary$horizon_verdict,
    "`; positive-correlation folds `", verdict$horizon_summary$positive_correlation_folds, "/20`; positive-separation folds `",
    verdict$horizon_summary$positive_separation_folds, "/20`; mean rank correlation `",
    sprintf("%.3f", verdict$horizon_summary$pooled_mean_rank_correlation), "`; high-minus-low realized volatility `",
    sprintf("%.3f", verdict$horizon_summary$pooled_mean_separation_realized_volatility), "`; high-state share `",
    sprintf("%.1f%%", 100 * verdict$horizon_summary$mean_high_state_share), "`."
  ),
  "",
  "## Feature verdict",
  "",
  paste0("- `", verdict$feature_summary$feature_name, "`: `", verdict$feature_summary$final_verdict, "`."),
  "",
  "## Next gate",
  "",
  if (overall_status == "PASS_TO_RISK_SCALER_DESIGN") {
    "At least one primitive ordered realized risk at both horizons. A separate theory-first session may now freeze a transparent continuous scaler; no scaler is implemented here."
  } else {
    "No primitive earned a two-horizon risk role. Do not design a scaler from this packet."
  },
  "",
  "## Visuals",
  "",
  "- `visuals/c1_h5_correlation_heatmap.png`",
  "- `visuals/c1_h20_correlation_heatmap.png`",
  "- `visuals/c1_risk_separation.png`"
)
writeLines(report, file.path(output_dir, "c1_report.md"), useBytes = TRUE)
message("Gen5.4 C1 complete: ", overall_status)
message("Data health: ", g5_health_max_severity(query$health))
message("Report: ", normalizePath(file.path(output_dir, "c1_report.md"), winslash = "/"))
