# Gen5.4 conditional-exposure primitive POC.
#
# Builds the frozen five-feature common panel and semiconductor challenger,
# then performs TRAIN-binned OOS ordering and cost-proxy diagnostics. It fits no
# model, selects no threshold, and changes no live-facing behavior.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

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
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "gen54_conditional_exposure_poc.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) g5_stop(paste0("Could not create output directory: ", path))
  invisible(path)
}

write_ordering_plot <- function(fold_separation, path) {
  directional <- g5_gen54_ce_directional_features()
  x <- fold_separation[fold_separation$feature_name %in% directional, , drop = FALSE]
  grDevices::png(path, width = 3000L, height = 1800L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(3, 2), mar = c(7, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (feature in directional) {
    part <- x[x$feature_name == feature, , drop = FALSE]
    part <- part[order(part$fold_no), , drop = FALSE]
    if (!nrow(part)) {
      graphics::plot.new()
      graphics::title(feature)
      next
    }
    cols <- ifelse(part$target_return_separation > 0, "#2563EB", "#DC2626")
    graphics::barplot(
      10000 * part$target_return_separation,
      names.arg = part$fold_id,
      las = 2,
      col = cols,
      border = NA,
      ylab = "High-minus-low target return (bp)",
      main = feature
    )
    graphics::abline(h = 0, col = "#111827", lwd = 1.2)
  }
  graphics::plot.new()
  graphics::legend(
    "center",
    legend = c("Positive separation", "Negative separation"),
    fill = c("#2563EB", "#DC2626"),
    border = NA,
    bty = "n",
    cex = 1.2
  )
}

write_cost_plot <- function(proxy_cost, path) {
  x <- proxy_cost[proxy_cost$cost_bps_one_way %in% c(10, 20), , drop = FALSE]
  if (!nrow(x)) return(invisible(FALSE))
  aggregate_rows <- aggregate(
    x$cumulative_selection_excess,
    list(feature_name = x$feature_name, cost_bps_one_way = x$cost_bps_one_way),
    sum,
    na.rm = TRUE
  )
  names(aggregate_rows)[[3L]] <- "selection_excess_sum"
  features <- unique(aggregate_rows$feature_name)
  mat <- matrix(NA_real_, nrow = length(features), ncol = 2L,
                dimnames = list(features, c("10 bp", "20 bp")))
  for (i in seq_len(nrow(aggregate_rows))) {
    col <- if (aggregate_rows$cost_bps_one_way[[i]] == 10) 1L else 2L
    mat[aggregate_rows$feature_name[[i]], col] <- aggregate_rows$selection_excess_sum[[i]]
  }
  display_names <- c(
    target_leadership_20 = "Target leadership",
    opportunity_breadth_20 = "Opportunity breadth",
    spy_trend_20 = "SPY trend",
    participation_dollar_volume_5_60 = "Dollar-volume participation",
    semiconductor_confirmation_20 = "SMH confirmation"
  )
  rownames(mat) <- unname(display_names[rownames(mat)])
  grDevices::png(path, width = 2600L, height = 1500L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(6, 11, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c("#2563EB", "#7C3AED")
  graphics::barplot(
    t(mat),
    beside = TRUE,
    horiz = TRUE,
    col = cols,
    border = NA,
    las = 1,
    xlab = "Sum of quarterly selection-excess returns",
    main = "Top-two-quintile diagnostic proxy after one-way turnover costs"
  )
  graphics::abline(v = 0, col = "#111827", lwd = 1.2)
  graphics::legend("topright", inset = c(0.08, 0.02), legend = colnames(mat), fill = cols, border = NA, bty = "n")
}

write_report <- function(path, run_spec, audit, promotion, artifact_index) {
  status_lines <- paste0(
    "- `", promotion$feature_name, "`: `", promotion$promotion_status,
    "` (positive separation `", promotion$positive_separation_folds, "/",
    promotion$assessed_fold_count, "`; positive ordering `",
    promotion$positive_ordering_folds, "/", promotion$assessed_fold_count, "`)."
  )
  cost_lines <- paste0(
    "- `", promotion$feature_name, "`: 10 bp selection-excess sum `",
    round(promotion$base_10bps_selection_excess_sum, 4),
    "`; 20 bp stress sum `", round(promotion$stress_20bps_selection_excess_sum, 4), "`."
  )
  core_pass <- all(promotion$promotion_status[
    promotion$feature_name %in% c("target_leadership_20", "opportunity_breadth_20")
  ] == "PASS")
  overall_status <- if (core_pass) "PASS_FOR_OPERATOR_MODEL_GATE" else "STOP"
  lines <- c(
    "# Gen5.4 Conditional-Exposure Primitive POC",
    "",
    "## Purpose",
    "",
    "This packet tests whether the frozen primitive information roles show leakage-safe OOS ordering before any model is fit. TRAIN-defined quintiles are diagnostic bins, not selected trading thresholds.",
    "",
    "## Frozen Scope",
    "",
    paste0("- Research basket: `", run_spec$live_symbols[[1L]], "`."),
    "- Basket selection is knowingly retrospective; findings cannot support prospective asset-discovery claims.",
    paste0("- OOS folds: `", run_spec$oos_folds[[1L]], "`; each uses the preceding eight quarters as TRAIN."),
    "- Outcome: target open t+1 to open t+2 simple return; basket outcome is a separate portfolio-context evaluation.",
    "- Common panel: five primitives. SMH confirmation is a semiconductor-only challenger.",
    "- No model fit, probability threshold selection, allocation change, or live-advice change.",
    "",
    "## Leakage Audit",
    "",
    paste0("- `", audit$check_id, "`: `", audit$status, "` — ", audit$detail),
    "",
    "## Predeclared Promotion Readout",
    "",
    status_lines,
    "",
    paste0("- Overall frozen mechanism gate: `", overall_status, "`."),
    "",
    "A feature-level PASS is permission to include that primitive in a later small model comparison, not evidence of alpha or live readiness. The central continuation mechanism should not advance unless both target leadership and opportunity-set breadth pass their frozen gates.",
    "",
    "## Cost Proxy Boundary",
    "",
    "The cost surface activates a sleeve only when a primitive is in its top two TRAIN-defined quintiles. This is a fixed diagnostic exposure proxy used to make turnover visible; it is not a promoted policy.",
    "",
    cost_lines,
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_index$artifact_id, "`: `", artifact_index$path, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN54_CE_P0_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed
refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_CE_P0_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_CE_P0_STAMP", "20260719cep0"))
as_of_timestamp <- env_or("GEN5_GEN54_CE_P0_AS_OF", "2024-12-31 17:30:00")
years <- 2020:2024
live_symbols <- g5_gen54_ce_live_symbols()
query_symbols <- unique(c(live_symbols, "SPY", "SMH"))
folds <- g5_gen54_ce_build_folds(years)
query_start <- min(folds$train_start_date) - 420L
query_end <- max(folds$oos_end_date)

output_dir <- ensure_dir(file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine",
  paste0("g54_conditional_exposure_p0_", stamp)
))
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = query_symbols,
  universe_name = "gen54_conditional_exposure_p0",
  universe_roles = "retrospective_research_basket,market_context,sector_challenger",
  refresh = refresh,
  repo_root = repo_root
)
query_artifacts <- g5_write_workbench_query_artifacts(query, file.path(output_dir, "query"), "ce_p0_query")
health_severity <- g5_health_max_severity(query$health)
message("Data health: ", health_severity)
if (identical(health_severity, "ERROR")) g5_stop("Conditional-exposure POC data health contains ERROR rows.")

feature_outcomes <- g5_gen54_ce_build_feature_outcomes(query$bars, live_symbols = live_symbols)
fold_rows <- g5_gen54_ce_assign_fold_rows(feature_outcomes, folds)
audit <- g5_gen54_ce_leakage_audit(fold_rows, folds)
if (any(audit$status == "FAIL")) {
  g5_stop(paste0("Conditional-exposure leakage audit failed: ", paste(audit$check_id[audit$status == "FAIL"], collapse = ", ")))
}
binned_oos <- g5_gen54_ce_build_binned_oos(fold_rows)
bin_summary <- g5_gen54_ce_bin_summary(binned_oos)
fold_separation <- g5_gen54_ce_fold_separation(bin_summary)
proxy_cost <- g5_gen54_ce_proxy_cost_summary(binned_oos)
concentration <- g5_gen54_ce_symbol_year_concentration(binned_oos)
market_states <- g5_gen54_ce_market_state_summary(fold_rows)
promotion <- g5_gen54_ce_promotion_summary(fold_separation, proxy_cost, concentration)

paths <- list(
  run_spec_csv = file.path(output_dir, "ce_p0_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ce_p0_fold_spec.csv"),
  feature_taxonomy_csv = file.path(output_dir, "ce_p0_feature_taxonomy.csv"),
  feature_outcome_sample_csv = file.path(output_dir, "ce_p0_feature_outcome_sample.csv"),
  leakage_audit_csv = file.path(output_dir, "ce_p0_leakage_audit.csv"),
  binned_oos_csv = file.path(output_dir, "ce_p0_binned_oos.csv"),
  bin_summary_csv = file.path(output_dir, "ce_p0_bin_summary.csv"),
  fold_separation_csv = file.path(output_dir, "ce_p0_fold_separation.csv"),
  proxy_cost_csv = file.path(output_dir, "ce_p0_proxy_cost_summary.csv"),
  concentration_csv = file.path(output_dir, "ce_p0_symbol_year_concentration.csv"),
  market_state_csv = file.path(output_dir, "ce_p0_market_state_summary.csv"),
  promotion_csv = file.path(output_dir, "ce_p0_promotion_summary.csv"),
  report_md = file.path(output_dir, "ce_p0_report.md"),
  artifact_index_csv = file.path(output_dir, "ce_p0_artifact_index.csv"),
  ordering_png = file.path(visual_dir, "ce_p0_fold_ordering.png"),
  cost_png = file.path(visual_dir, "ce_p0_cost_proxy.png")
)

run_spec <- data.frame(
  schema_version = "gen54_conditional_exposure_primitive_poc_v0.1",
  wrapper = "scripts/inspect/run_gen54_conditional_exposure_primitive_poc.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  query_symbols = paste(query_symbols, collapse = ","),
  oos_folds = paste(folds$fold_id, collapse = ","),
  train_quarters = 8L,
  feature_horizon_sessions = 20L,
  participation_recent_sessions = 5L,
  participation_prior_baseline_sessions = 60L,
  outcome = "target_open_t1_to_open_t2_simple_return",
  diagnostic_bins = "TRAIN empirical quintiles",
  cost_bps_one_way = "0,10,20",
  active_proxy = "TRAIN percentile >= 0.60",
  health_max_severity = health_severity,
  feature_outcome_rows = nrow(feature_outcomes),
  oos_binned_rows = nrow(binned_oos),
  model_fit_count = 0L,
  live_behavior_changed = FALSE,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

taxonomy <- data.frame(
  feature_name = c(g5_gen54_ce_common_features(), "semiconductor_confirmation_20"),
  lane = c(rep("common_panel", 5L), "semiconductor_challenger"),
  expected_direction = c("positive", "positive", "positive", "interaction_only", "positive", "positive"),
  role = c("target_leadership", "opportunity_set_breadth", "broad_market_trend", "broad_market_volatility", "participation_liquidity", "sector_confirmation"),
  stringsAsFactors = FALSE
)

sample_columns <- c(
  "symbol", "feature_date", "execution_date", "label_end_date",
  g5_gen54_ce_common_features(), "semiconductor_confirmation_20",
  "target_open_to_open_return", "basket_open_to_open_return",
  "target_favorable", "basket_favorable", "complete_common"
)
sample_rows <- feature_outcomes[feature_outcomes$complete_common, sample_columns, drop = FALSE]
sample_rows <- sample_rows[seq_len(min(500L, nrow(sample_rows))), , drop = FALSE]

write_ordering_plot(fold_separation, paths$ordering_png)
write_cost_plot(proxy_cost, paths$cost_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 12L), "markdown", "csv", "png", "png"),
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(taxonomy, paths$feature_taxonomy_csv)
g5_wfa_write_csv(sample_rows, paths$feature_outcome_sample_csv)
g5_wfa_write_csv(audit, paths$leakage_audit_csv)
g5_wfa_write_csv(binned_oos, paths$binned_oos_csv)
g5_wfa_write_csv(bin_summary, paths$bin_summary_csv)
g5_wfa_write_csv(fold_separation, paths$fold_separation_csv)
g5_wfa_write_csv(proxy_cost, paths$proxy_cost_csv)
g5_wfa_write_csv(concentration, paths$concentration_csv)
g5_wfa_write_csv(market_states, paths$market_state_csv)
g5_wfa_write_csv(promotion, paths$promotion_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_report(paths$report_md, run_spec, audit, promotion, artifact_index)

message("Gen5.4 conditional-exposure primitive POC complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("Promotion: ", paste(promotion$feature_name, promotion$promotion_status, sep = "=", collapse = "; "))
