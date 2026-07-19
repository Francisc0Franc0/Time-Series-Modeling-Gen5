# Gen5.4 leadership x participation confirmation.
#
# Confirms a predeclared four-state interaction over 2025Q1-2026Q2. This script
# fits no model and selects no feature, horizon, threshold, or policy from OOS.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

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

state_ids <- c(
  A = "A_high_leadership__high_participation",
  B = "B_high_leadership__low_participation",
  C = "C_low_leadership__high_participation",
  D = "D_low_leadership__low_participation"
)
state_labels <- c(
  A_high_leadership__high_participation = "A  High leadership / high participation",
  B_high_leadership__low_participation = "B  High leadership / low participation",
  C_low_leadership__high_participation = "C  Low leadership / high participation",
  D_low_leadership__low_participation = "D  Low leadership / low participation"
)
state_colors <- c(
  A_high_leadership__high_participation = "#2563EB",
  B_high_leadership__low_participation = "#7C3AED",
  C_low_leadership__high_participation = "#F97316",
  D_low_leadership__low_participation = "#9CA3AF"
)

write_state_matrix <- function(state_summary, path) {
  pooled <- state_summary[state_summary$scope == "pooled", , drop = FALSE]
  value <- function(state, column) {
    x <- pooled[pooled$confirmation_state == state, column, drop = TRUE]
    if (length(x)) as.numeric(x[[1L]]) else NA_real_
  }
  count <- function(state) {
    x <- pooled$row_count[pooled$confirmation_state == state]
    if (length(x)) as.integer(x[[1L]]) else 0L
  }
  grDevices::png(path, width = 2400L, height = 1700L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(5, 6, 6, 3))
  graphics::plot(c(0, 2), c(0, 2), type = "n", axes = FALSE, xlab = "", ylab = "",
                 main = "The joint hypothesis requires State A to beat both B and C")
  cells <- data.frame(
    state = c(state_ids[["D"]], state_ids[["C"]], state_ids[["B"]], state_ids[["A"]]),
    x = c(0, 1, 0, 1), y = c(0, 0, 1, 1), stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(cells))) {
    state <- cells$state[[i]]
    x <- cells$x[[i]]; y <- cells$y[[i]]
    graphics::rect(x + 0.04, y + 0.04, x + 0.96, y + 0.96,
                   col = state_colors[[state]], border = "white", lwd = 4)
    graphics::text(x + 0.5, y + 0.68, substr(state, 1, 1), cex = 2.1, font = 2, col = "white")
    graphics::text(x + 0.5, y + 0.46, sprintf("Mean h1: %+.1f bp", 10000 * value(state, "mean_target_return")),
                   cex = 1.25, font = 2, col = "white")
    graphics::text(x + 0.5, y + 0.25, sprintf("Favorable: %.1f%%  |  n=%d",
      100 * value(state, "target_favorable_rate"), count(state)), cex = 1.0, col = "white")
  }
  graphics::mtext("Participation low", side = 1, at = 0.5, line = 1.5, cex = 1.15)
  graphics::mtext("Participation high", side = 1, at = 1.5, line = 1.5, cex = 1.15)
  graphics::mtext("Leadership low", side = 2, at = 0.5, line = 2.5, cex = 1.15)
  graphics::mtext("Leadership high", side = 2, at = 1.5, line = 2.5, cex = 1.15)
}

write_fold_contrasts <- function(contrasts, path) {
  mat <- rbind(
    `A minus B` = 10000 * contrasts$state_a_minus_b_return,
    `A minus C` = 10000 * contrasts$state_a_minus_c_return
  )
  grDevices::png(path, width = 2600L, height = 1500L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(7, 5, 4, 2))
  graphics::barplot(mat, beside = TRUE, names.arg = contrasts$fold_id, las = 2,
                    col = c("#2563EB", "#F97316"), border = NA,
                    ylab = "State-A return advantage (bp)",
                    main = "State A must beat both single-condition states in the same quarter")
  graphics::abline(h = 0, col = "#111827", lwd = 1.2)
  graphics::legend("topright", legend = rownames(mat), fill = c("#2563EB", "#F97316"), border = NA, bty = "n")
}

write_state_tapes <- function(states, path, live_symbols) {
  grDevices::png(path, width = 3000L, height = 2300L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(3, 2), mar = c(4, 5, 3, 2))
  for (symbol in live_symbols) {
    part <- states[states$symbol == symbol, , drop = FALSE]
    part <- part[order(part$feature_date), , drop = FALSE]
    proxy_close <- cumprod(c(100, 1 + head(part$target_open_to_open_return, -1L)))
    cols <- unname(state_colors[part$confirmation_state])
    graphics::plot(part$feature_date, proxy_close, type = "l", lwd = 1.5, col = "#111827",
                   xlab = "", ylab = "Indexed open path", main = symbol)
    graphics::points(part$feature_date, proxy_close, pch = 16, cex = 0.55, col = cols)
  }
  graphics::plot.new()
  graphics::legend("center", legend = unname(state_labels), fill = unname(state_colors),
                   border = NA, bty = "n", cex = 1.0, title = "Daily frozen state")
}

write_cost_chart <- function(cost_summary, path) {
  aggregate_rows <- aggregate(
    cost_summary$cumulative_selection_excess,
    list(cost_bps_one_way = cost_summary$cost_bps_one_way),
    sum, na.rm = TRUE
  )
  names(aggregate_rows)[[2L]] <- "selection_excess_sum"
  grDevices::png(path, width = 2200L, height = 1300L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(5, 5, 4, 2))
  cols <- ifelse(aggregate_rows$selection_excess_sum >= 0, "#2563EB", "#DC2626")
  graphics::barplot(aggregate_rows$selection_excess_sum,
                    names.arg = paste0(aggregate_rows$cost_bps_one_way, " bp"),
                    col = cols, border = NA, ylab = "Sum of quarterly selection-excess returns",
                    main = "State-A exposure must survive turnover costs")
  graphics::abline(h = 0, col = "#111827", lwd = 1.2)
}

write_verdict_chart <- function(promotion, path) {
  checks <- c(
    `Correct A ordering in >= 4/6 folds` = promotion$correct_state_a_ordering_folds >= promotion$required_correct_folds,
    `Pooled A return exceeds B` = promotion$pooled_state_a_minus_b_return > 0,
    `Pooled A return exceeds C` = promotion$pooled_state_a_minus_c_return > 0,
    `Positive selection excess at 10 bp` = promotion$base_10bps_selection_excess_sum > 0,
    `No reversal at 20 bp` = promotion$stress_20bps_selection_excess_sum >= 0,
    `No symbol contributes more than 50%` = promotion$max_symbol_absolute_contribution_share <= 0.50
  )
  grDevices::png(path, width = 2400L, height = 1500L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(2, 2, 4, 2))
  graphics::plot(c(0, 1), c(0, length(checks) + 1), type = "n", axes = FALSE, xlab = "", ylab = "",
                 main = paste("Confirmation verdict:", promotion$confirmation_status))
  for (i in seq_along(checks)) {
    y <- length(checks) - i + 1
    color <- if (checks[[i]]) "#16A34A" else "#DC2626"
    graphics::rect(0.05, y - 0.35, 0.12, y + 0.35, col = color, border = NA)
    graphics::text(0.10, y, if (checks[[i]]) "PASS" else "STOP", col = "white", font = 2, cex = 0.75)
    graphics::text(0.16, y, names(checks)[[i]], adj = 0, cex = 1.15, font = 2)
  }
}

write_report <- function(path, run_spec, audit, promotion, contrasts, artifact_index) {
  lines <- c(
    "# Gen5.4 Leadership x Participation Confirmation",
    "",
    "## Question",
    "",
    "Does 20-session cross-sectional leadership persist when it is accompanied by abnormal target-specific dollar-volume participation?",
    "",
    "## Frozen Design",
    "",
    paste0("- Confirmation folds: `", run_spec$confirmation_folds[[1L]], "`."),
    "- Each fold uses the preceding eight quarters as TRAIN.",
    "- High leadership and high participation are fixed at the pooled TRAIN 60th percentile.",
    "- State A must beat both State B and State C; beating only the low/low state is insufficient.",
    "- Outcome remains open t+1 to open t+2 simple return.",
    "- No model fit, threshold search, feature selection, allocation change, or live behavior change.",
    "",
    "## Leakage And Scope Audit",
    "",
    paste0("- `", audit$check_id, "`: `", audit$status, "` — ", audit$detail),
    "",
    "## Result",
    "",
    paste0("- Confirmation status: `", promotion$confirmation_status, "`."),
    paste0("- Correct State-A ordering: `", promotion$correct_state_a_ordering_folds, "/", promotion$confirmation_fold_count, "` folds; required `", promotion$required_correct_folds, "`."),
    paste0("- Pooled A minus B: `", round(10000 * promotion$pooled_state_a_minus_b_return, 1), " bp`."),
    paste0("- Pooled A minus C: `", round(10000 * promotion$pooled_state_a_minus_c_return, 1), " bp`."),
    paste0("- 10 bp selection-excess sum: `", round(promotion$base_10bps_selection_excess_sum, 4), "`."),
    paste0("- 20 bp stress selection-excess sum: `", round(promotion$stress_20bps_selection_excess_sum, 4), "`."),
    paste0("- Maximum symbol contribution share: `", round(100 * promotion$max_symbol_absolute_contribution_share, 1), "%`."),
    "",
    "## Fold Contrasts",
    "",
    paste0("- `", contrasts$fold_id, "`: A-B `", round(10000 * contrasts$state_a_minus_b_return, 1), " bp`; A-C `", round(10000 * contrasts$state_a_minus_c_return, 1), " bp`; ordering `", ifelse(contrasts$correct_state_a_ordering, "PASS", "STOP"), "`."),
    "",
    "## Human-Facing Evidence",
    "",
    "The state matrix explains the joint test, fold contrasts show stability, state tapes show when each condition occurred, the cost chart exposes turnover burden, and the verdict chart identifies exactly why the gate passed or stopped.",
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_index$artifact_id, "`: `", artifact_index$path, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN54_LP_C0_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed
refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_LP_C0_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_LP_C0_STAMP", "20260719lpc0"))
as_of_timestamp <- env_or("GEN5_GEN54_LP_C0_AS_OF", "2026-06-30 17:30:00")
confirmation_fold_ids <- c("2025Q1", "2025Q2", "2025Q3", "2025Q4", "2026Q1", "2026Q2")
live_symbols <- g5_gen54_ce_live_symbols()
query_symbols <- unique(c(live_symbols, "SPY", "SMH"))
all_folds <- g5_gen54_ce_build_folds(2025:2026)
folds <- all_folds[all_folds$fold_id %in% confirmation_fold_ids, , drop = FALSE]
# Explicit Monday boundary preserves more than the required warm-up while
# avoiding a false partial-history WARN caused by requesting Sunday 2021-11-07.
query_start <- as.Date("2021-11-08")
query_end <- max(folds$oos_end_date)
output_dir <- ensure_dir(file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_leadership_participation_c0_", stamp)))
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = query_start, end_date = query_end,
  as_of_timestamp = as_of_timestamp, symbols = query_symbols,
  universe_name = "gen54_leadership_participation_c0",
  universe_roles = "retrospective_research_basket,market_context",
  refresh = refresh, repo_root = repo_root
)
query_artifacts <- g5_write_workbench_query_artifacts(query, file.path(output_dir, "query"), "lp_c0_query")
health_severity <- g5_health_max_severity(query$health)
message("Data health: ", health_severity)
if (identical(health_severity, "ERROR")) g5_stop("Leadership-participation confirmation data health contains ERROR rows.")

feature_outcomes <- g5_gen54_ce_build_feature_outcomes(query$bars, live_symbols = live_symbols)
fold_rows <- g5_gen54_ce_assign_fold_rows(feature_outcomes, folds)
confirmation <- g5_gen54_lp_confirmation_states(fold_rows, confirmation_fold_ids)
states <- confirmation$states
thresholds <- confirmation$thresholds
state_summary <- g5_gen54_lp_state_summary(states)
contrasts <- g5_gen54_lp_fold_contrasts(state_summary)
cost_summary <- g5_gen54_lp_cost_summary(states)
concentration <- g5_gen54_lp_concentration(states)
promotion <- g5_gen54_lp_promotion_summary(state_summary, contrasts, cost_summary, concentration)

audit <- data.frame(
  check_id = c("frozen_confirmation_folds", "feature_precedes_execution", "execution_precedes_label_end", "train_thresholds_only", "complete_four_state_assignment", "model_fit_count_zero"),
  status = c(
    if (identical(as.character(thresholds$fold_id), confirmation_fold_ids)) "PASS" else "FAIL",
    if (nrow(states) && all(as.Date(states$feature_date) < as.Date(states$execution_date))) "PASS" else "FAIL",
    if (nrow(states) && all(as.Date(states$execution_date) < as.Date(states$label_end_date))) "PASS" else "FAIL",
    if (nrow(thresholds) == 6L && all(is.finite(thresholds$leadership_train_p60)) && all(is.finite(thresholds$participation_train_p60))) "PASS" else "FAIL",
    if (nrow(states) && all(states$confirmation_state %in% unname(state_ids))) "PASS" else "FAIL",
    "PASS"
  ),
  detail = c(
    "Only 2025Q1 through 2026Q2 are confirmation authorities.",
    "All inputs end at close t before next-open execution.",
    "The h1 outcome ends at the following open.",
    "Each p60 threshold is estimated from the preceding eight TRAIN quarters and frozen OOS.",
    "Every eligible OOS row maps to exactly one predeclared state.",
    "The confirmation packet fits no model."
  ), stringsAsFactors = FALSE
)
if (any(audit$status == "FAIL")) g5_stop(paste0("Confirmation audit failed: ", paste(audit$check_id[audit$status == "FAIL"], collapse = ", ")))

paths <- list(
  run_spec_csv = file.path(output_dir, "lp_c0_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "lp_c0_fold_spec.csv"),
  threshold_csv = file.path(output_dir, "lp_c0_train_thresholds.csv"),
  state_rows_csv = file.path(output_dir, "lp_c0_oos_states.csv"),
  state_summary_csv = file.path(output_dir, "lp_c0_state_summary.csv"),
  fold_contrast_csv = file.path(output_dir, "lp_c0_fold_contrasts.csv"),
  cost_summary_csv = file.path(output_dir, "lp_c0_cost_summary.csv"),
  concentration_csv = file.path(output_dir, "lp_c0_concentration.csv"),
  promotion_csv = file.path(output_dir, "lp_c0_promotion_summary.csv"),
  audit_csv = file.path(output_dir, "lp_c0_audit.csv"),
  report_md = file.path(output_dir, "lp_c0_report.md"),
  artifact_index_csv = file.path(output_dir, "lp_c0_artifact_index.csv"),
  state_matrix_png = file.path(visual_dir, "lp_c0_state_matrix.png"),
  fold_contrasts_png = file.path(visual_dir, "lp_c0_fold_contrasts.png"),
  state_tapes_png = file.path(visual_dir, "lp_c0_state_tapes.png"),
  cost_png = file.path(visual_dir, "lp_c0_cost_robustness.png"),
  verdict_png = file.path(visual_dir, "lp_c0_verdict.png")
)

run_spec <- data.frame(
  schema_version = "gen54_leadership_participation_confirmation_v0.1",
  wrapper = "scripts/inspect/run_gen54_leadership_participation_confirmation.R",
  as_of_timestamp = as_of_timestamp, feed = cfg$feed, refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  confirmation_folds = paste(confirmation_fold_ids, collapse = ","),
  train_quarters = 8L, threshold_percentile = 0.60,
  outcome = "target_open_t1_to_open_t2_simple_return",
  cost_bps_one_way = "0,10,20", health_max_severity = health_severity,
  confirmation_status = promotion$confirmation_status,
  model_fit_count = 0L, live_behavior_changed = FALSE,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_state_matrix(state_summary, paths$state_matrix_png)
write_fold_contrasts(contrasts, paths$fold_contrasts_png)
write_state_tapes(states, paths$state_tapes_png, live_symbols)
write_cost_chart(cost_summary, paths$cost_png)
write_verdict_chart(promotion, paths$verdict_png)

artifact_index <- data.frame(
  artifact_id = names(paths), path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 10L), "markdown", "csv", rep("png", 5L)), stringsAsFactors = FALSE
)
g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(thresholds, paths$threshold_csv)
g5_wfa_write_csv(states, paths$state_rows_csv)
g5_wfa_write_csv(state_summary, paths$state_summary_csv)
g5_wfa_write_csv(contrasts, paths$fold_contrast_csv)
g5_wfa_write_csv(cost_summary, paths$cost_summary_csv)
g5_wfa_write_csv(concentration, paths$concentration_csv)
g5_wfa_write_csv(promotion, paths$promotion_csv)
g5_wfa_write_csv(audit, paths$audit_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_report(paths$report_md, run_spec, audit, promotion, contrasts, artifact_index)

message("Gen5.4 leadership x participation confirmation complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("Confirmation: ", promotion$confirmation_status)
