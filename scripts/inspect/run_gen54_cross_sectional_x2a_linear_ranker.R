# Gen5.4 X2a two-feature pooled linear ranker confirmation.
# Ranking diagnostics only: no portfolio, exposure, allocation, PnL, or live behavior.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
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
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_ohlcv_extension.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_x2a_linear_ranker.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}
dir_create <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create output directory.", call. = FALSE)
}

plot_fold_ic <- function(fold_summary, path) {
  folds <- unique(fold_summary$fold_id)
  methods <- g5_gen54_x2a_method_names()
  display <- c("Group momentum", "Intraday − overnight", "Fixed 50/50", "Linear model")
  colors <- c("#64748B", "#D97706", "#2563EB", "#0F766E")
  values <- sapply(methods, function(method) {
    part <- fold_summary[fold_summary$method == method, , drop = FALSE]
    part$mean_daily_rank_ic[match(folds, part$fold_id)]
  })
  png(path, width = 1800, height = 950, res = 150)
  par(mar = c(6, 6, 4, 2))
  matplot(seq_along(folds), values, type = "b", pch = 19, lty = 1, lwd = 2.5,
    col = colors, xaxt = "n", xlab = "", ylab = "Quarterly mean daily Spearman IC",
    main = "Does the two-feature model improve ranking consistently?")
  axis(1, at = seq_along(folds), labels = folds)
  abline(h = 0, col = "#94A3B8", lty = 2)
  legend("topleft", legend = display, col = colors, pch = 19, lty = 1, lwd = 2.5,
    bty = "n", ncol = 2)
  dev.off()
}

plot_top_bottom <- function(fold_summary, path) {
  folds <- unique(fold_summary$fold_id)
  methods <- g5_gen54_x2a_method_names()
  values <- sapply(methods, function(method) {
    part <- fold_summary[fold_summary$method == method, , drop = FALSE]
    10000 * part$top_minus_bottom_h5[match(folds, part$fold_id)]
  })
  limit <- max(abs(values), na.rm = TRUE)
  png(path, width = 1800, height = 900, res = 150)
  par(mar = c(7, 10, 4, 2))
  image(
    seq_along(folds), seq_along(methods), values,
    zlim = c(-limit, limit),
    col = colorRampPalette(c("#B91C1C", "white", "#166534"))(101),
    axes = FALSE, xlab = "", ylab = "",
    main = "Top-quintile minus bottom-quintile relative h5 outcome (bp)"
  )
  axis(1, at = seq_along(folds), labels = folds)
  axis(2, at = seq_along(methods),
    labels = c("Group momentum", "Intraday − overnight", "Fixed 50/50", "Linear model"),
    las = 1)
  for (i in seq_along(folds)) {
    for (j in seq_along(methods)) {
      text(i, j, sprintf("%.1f", values[i, j]), cex = 0.85)
    }
  }
  dev.off()
}

plot_coefficients <- function(coefficients, path) {
  slopes <- coefficients[coefficients$term != "(Intercept)", , drop = FALSE]
  folds <- unique(slopes$fold_id)
  terms <- c("group_relative_20_rank", "intraday_minus_overnight_20_rank")
  values <- sapply(terms, function(term) {
    part <- slopes[slopes$term == term, , drop = FALSE]
    part$estimate[match(folds, part$fold_id)]
  })
  png(path, width = 1600, height = 850, res = 150)
  par(mar = c(6, 6, 4, 2))
  matplot(seq_along(folds), values, type = "b", pch = c(19, 17), lty = 1,
    lwd = 2.5, col = c("#2563EB", "#D97706"), xaxt = "n", xlab = "",
    ylab = "OLS coefficient", main = "TRAIN-only coefficient stability")
  axis(1, at = seq_along(folds), labels = folds)
  abline(h = 0, col = "#94A3B8", lty = 2)
  legend("topleft", legend = c("Group-relative momentum", "Intraday − overnight"),
    col = c("#2563EB", "#D97706"), pch = c(19, 17), lty = 1, lwd = 2.5, bty = "n")
  dev.off()
}

plot_concentration <- function(fold_summary, path) {
  model <- fold_summary[fold_summary$method == "pooled_linear_ranker", , drop = FALSE]
  values <- rbind(
    "Economic group" = 100 * model$top_selection_max_group_share,
    "Individual symbol" = 100 * model$top_selection_max_symbol_share
  )
  png(path, width = 1600, height = 850, res = 150)
  par(mar = c(6, 6, 4, 2))
  bp <- barplot(values, beside = TRUE, names.arg = model$fold_id,
    col = c("#0F766E", "#64748B"), ylim = c(0, max(55, values + 5)),
    ylab = "Maximum top-quintile share (%)",
    main = "The model must not win by concentrating in one group or symbol")
  abline(h = 50, col = "#B91C1C", lty = 2, lwd = 2)
  abline(h = 25, col = "#D97706", lty = 2, lwd = 2)
  legend("topright", legend = rownames(values), fill = c("#0F766E", "#64748B"), bty = "n")
  text(bp, values, labels = sprintf("%.1f", values), pos = 3, cex = 0.8)
  dev.off()
}

plot_gate_summary <- function(gates, path) {
  labels <- c(
    "Integrity", "Mean IC > 0", "IC + in ≥4Q", "Top−bottom > 0",
    "Ordering + in ≥4Q", "IC lift ≥0.005", "Lift + in ≥4Q",
    "Group ≤50%", "Symbol ≤25%"
  )
  png(path, width = 1600, height = 950, res = 150)
  par(mar = c(5, 12, 4, 2))
  y <- rev(seq_len(nrow(gates)))
  plot(c(0, 1), c(0.5, nrow(gates) + 0.5), type = "n", axes = FALSE,
    xlab = "", ylab = "", main = "Frozen X2a promotion gates")
  axis(2, at = y, labels = labels, las = 1)
  points(rep(0.5, nrow(gates)), y, pch = 19, cex = 3,
    col = ifelse(gates$status == "PASS", "#166534", "#B91C1C"))
  text(rep(0.5, nrow(gates)), y,
    labels = ifelse(gates$status == "PASS", "PASS", "FAIL"),
    col = "white", font = 2, cex = 0.65)
  dev.off()
}

plot_ranking_tapes <- function(tapes, path) {
  folds <- unique(tapes$fold_id)
  png(path, width = 1900, height = 1200, res = 150)
  par(mfrow = c(2, 3), mar = c(6, 4, 4, 1))
  for (fold in folds) {
    part <- tapes[tapes$fold_id == fold, , drop = FALSE]
    colors <- ifelse(part$relative_forward_return_h5 >= 0, "#166534", "#B91C1C")
    values <- 10000 * part$relative_forward_return_h5
    value_range <- range(c(0, values), na.rm = TRUE)
    padding <- max(25, 0.16 * diff(value_range))
    bp <- barplot(values,
      names.arg = part$symbol, col = colors, las = 2,
      ylim = c(value_range[[1L]] - padding, value_range[[2L]] + padding),
      ylab = "Relative h5 outcome (bp)",
      main = paste0(fold, " • ", unique(part$feature_date)))
    abline(h = 0, col = "#64748B")
    text(bp, values,
      labels = paste0("#", part$rank_position), pos = ifelse(part$relative_forward_return_h5 >= 0, 3, 1),
      cex = 0.8)
  }
  dev.off()
}

message("Gen5.4 X2a linear ranker confirmation starting.")
g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_GEN54_X2A_FEED", as.character(cfg$feed))
refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_X2A_REFRESH", "false"), default = FALSE)
as_of_timestamp <- env_or("GEN5_GEN54_X2A_AS_OF", "2026-06-30 17:30:00")
run_id <- env_or("GEN5_GEN54_X2A_RUN_ID", "g54_xs_x2a_20260726")
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id
)
visual_dir <- file.path(output_dir, "visuals")
dir_create(visual_dir)

registry <- g5_gen54_xs_candidate_registry()
context_symbols <- g5_gen54_xs_context_symbols()
folds <- g5_gen54_x2a_build_folds()
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = as.Date("2022-06-01"),
  end_date = max(folds$oos_end_date),
  as_of_timestamp = as_of_timestamp,
  symbols = unique(c(registry$symbol, context_symbols)),
  universe_name = "gen54_cross_sectional_fixed_panel_v0_1",
  universe_roles = "ranked_candidates,context_anchors",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) stop("X2a query returned no bars.", call. = FALSE)
base_panel <- g5_gen54_xs_build_panel(query$bars, registry, context_symbols)
panel <- g5_gen54_build_ohlcv_extension(query$bars, base_panel, registry)$panel
fold_result <- g5_gen54_x2a_run_folds(panel, folds)
leakage <- g5_gen54_x2a_leakage_audit(panel, folds, fold_result$coefficients)
daily_ic <- g5_gen54_x2a_daily_ic(fold_result$scored)
fold_summary <- g5_gen54_x2a_fold_summary(fold_result$scored, daily_ic)
method_summary <- g5_gen54_x2a_method_summary(fold_summary, daily_ic)
gate <- g5_gen54_x2a_gate_audit(method_summary, fold_summary, leakage)
tapes <- g5_gen54_x2a_representative_tapes(fold_result$scored)

run_spec <- data.frame(
  schema_version = "gen54_x2a_v0.1",
  wrapper = "scripts/inspect/run_gen54_cross_sectional_x2a_linear_ranker.R",
  contract = "docs/GEN5_4_CROSS_SECTIONAL_X2A_LINEAR_RANKER_CONTRACT.md",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  ranked_candidate_count = nrow(registry),
  context_symbol_count = length(context_symbols),
  fold_count = nrow(folds),
  train_quarters = 8L,
  label = "relative_h5_next_open_to_open",
  predictive_input_count = 2L,
  model_family = "pooled_ordinary_least_squares",
  model_fit_count = nrow(folds),
  top_k_policy_count = 0L,
  portfolio_replay_count = 0L,
  exposure_policy_count = 0L,
  live_behavior_change_count = 0L,
  best_nonmodel_method = gate$best_nonmodel_method,
  mean_ic_lift = gate$mean_ic_lift,
  overall_status = gate$overall_status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "x2a_run_spec.csv"))
write_csv(folds, file.path(output_dir, "x2a_fold_spec.csv"))
write_csv(query$health, file.path(output_dir, "x2a_data_health.csv"))
write_csv(leakage, file.path(output_dir, "x2a_leakage_audit.csv"))
write_csv(fold_result$coefficients, file.path(output_dir, "x2a_fold_coefficients.csv"))
write_csv(daily_ic, file.path(output_dir, "x2a_daily_rank_ic.csv"))
write_csv(fold_summary, file.path(output_dir, "x2a_fold_summary.csv"))
write_csv(method_summary, file.path(output_dir, "x2a_method_summary.csv"))
write_csv(gate$improvement, file.path(output_dir, "x2a_fold_ic_improvement.csv"))
write_csv(gate$gates, file.path(output_dir, "x2a_gate_audit.csv"))
write_csv(tapes, file.path(output_dir, "x2a_representative_ranking_tapes.csv"))

plot_fold_ic(fold_summary, file.path(visual_dir, "x2a_fold_rank_ic.png"))
plot_top_bottom(fold_summary, file.path(visual_dir, "x2a_top_bottom_heatmap.png"))
plot_coefficients(fold_result$coefficients, file.path(visual_dir, "x2a_coefficients.png"))
plot_concentration(fold_summary, file.path(visual_dir, "x2a_concentration.png"))
plot_gate_summary(gate$gates, file.path(visual_dir, "x2a_gate_summary.png"))
plot_ranking_tapes(tapes, file.path(visual_dir, "x2a_representative_ranking_tapes.png"))

model <- method_summary[method_summary$method == "pooled_linear_ranker", , drop = FALSE]
report <- c(
  "# Gen5.4 X2a Two-Feature Linear Ranker Confirmation",
  "",
  paste0("Status: `", gate$overall_status, "`"),
  "",
  "## Boundary",
  "",
  "This packet evaluates relative ranking only. It does not compute strategy PnL, exposure, Sharpe, drawdown, turnover costs, allocation, leverage, or live advice.",
  "",
  "## Readout",
  "",
  paste0("- Linear-model mean daily OOS IC: `", sprintf("%.4f", model$mean_oos_daily_rank_ic), "`."),
  paste0("- Positive quarterly IC: `", model$positive_ic_quarters, " / 6`."),
  paste0("- Overall top-minus-bottom relative h5 outcome: `", sprintf("%.1f bp", 10000 * model$overall_top_minus_bottom_h5), "`."),
  paste0("- Positive quarterly top-bottom ordering: `", model$positive_ordering_quarters, " / 6`."),
  paste0("- Best frozen non-model comparator: `", gate$best_nonmodel_method, "`."),
  paste0("- Mean IC lift over that comparator: `", sprintf("%.4f", gate$mean_ic_lift), "`."),
  paste0("- Maximum model top-quintile group share: `", sprintf("%.1f%%", 100 * model$maximum_top_selection_group_share), "`."),
  paste0("- Maximum model top-quintile symbol share: `", sprintf("%.1f%%", 100 * model$maximum_top_selection_symbol_share), "`."),
  "",
  "## Decision",
  "",
  if (gate$overall_status == "PASS_X2A_TO_TOP5_POLICY_THEORY") {
    "All frozen X2a gates passed. A separate top-five portfolio-proof theory session may be opened; no portfolio semantics are authorized here."
  } else if (gate$overall_status == "RETAIN_FIXED_COMPOSITE_CLOSE_ML_COMPLEXITY") {
    "The transparent fixed composite retained useful ranking structure, but the trained model did not earn its complexity. Close the ML-combination lane."
  } else {
    "The two-feature combination did not clear the frozen confirmation gates. Stop the multivariate ranking lane; do not rescue it by tuning weights, interactions, or nearby models on these outcomes."
  },
  "",
  "## Visuals",
  "",
  "- `visuals/x2a_fold_rank_ic.png`",
  "- `visuals/x2a_top_bottom_heatmap.png`",
  "- `visuals/x2a_coefficients.png`",
  "- `visuals/x2a_concentration.png`",
  "- `visuals/x2a_gate_summary.png`",
  "- `visuals/x2a_representative_ranking_tapes.png`"
)
writeLines(report, file.path(output_dir, "x2a_report.md"), useBytes = TRUE)

message("Gen5.4 X2a complete: ", gate$overall_status)
message("Report: ", normalizePath(file.path(output_dir, "x2a_report.md"), winslash = "/"))
