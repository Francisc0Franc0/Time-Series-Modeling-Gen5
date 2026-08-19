args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  file.path("literature_studies", "scripts", "run_gen5_lit_reg_02_2_directional_forecast_poc.R")
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/")
setwd(repo_root)

local_library <- normalizePath(".codex_r_libs", winslash = "/", mustWork = FALSE)
if (dir.exists(local_library)) .libPaths(c(local_library, .libPaths()))

source(file.path(
  "literature_studies", "R", "gen5_lit_reg_02_1_directional_hmm_poc.R"
))
source(file.path(
  "literature_studies", "R", "gen5_lit_reg_02_2_directional_forecast_poc.R"
))

contract <- g5_reg022_contract()
g5_reg021_require_reference(contract)

run_id <- "lit_reg_02_2_directional_forecast_frontier_20260819"
run_dir <- file.path(
  "runs", "research_workbench", "literature_studies", run_id
)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

write_table <- function(value, name) {
  utils::write.csv(value, file.path(run_dir, name), row.names = FALSE, na = "")
}

combine_component <- function(results, component) {
  values <- lapply(results, `[[`, component)
  values <- values[!vapply(values, is.null, logical(1L))]
  if (!length(values)) return(NULL)
  all_columns <- unique(unlist(lapply(values, names), use.names = FALSE))
  values <- lapply(values, function(value) {
    missing <- setdiff(all_columns, names(value))
    for (column in missing) value[[column]] <- NA
    value[, all_columns, drop = FALSE]
  })
  do.call(rbind, values)
}

run_spec <- data.frame(
  schema_version = g5_reg022_schema_version(),
  literature_id = contract$literature_id,
  run_id = run_id,
  run_date = "2026-08-19",
  reference_package = contract$reference_package,
  reference_version = contract$reference_version,
  horizon = contract$horizon,
  forecast_paths = contract$forecast_paths,
  ridge_lambda = contract$ridge_lambda,
  stage_a_cases = contract$positive_case_count,
  market_data_read = FALSE,
  semi_synthetic_market_data_read = FALSE,
  strategy_data_read = FALSE,
  confirmation_data_read = FALSE,
  stringsAsFactors = FALSE
)
write_table(run_spec, "run_spec.csv")

positive_registry <- g5_reg022_positive_registry()
frontier_registry <- g5_reg022_frontier_registry()
stress_registry <- g5_reg022_stress_registry()
write_table(positive_registry, "stage_a_fresh_confirmation_registry.csv")
write_table(frontier_registry, "stage_b_unread_frontier_registry.csv")
write_table(stress_registry, "stage_c_unread_stress_registry.csv")

plot_score_comparison <- function(summary, path, subtitle) {
  scores <- rbind(
    B0 = c(mean(summary$brier_b0), mean(summary$logloss_b0)),
    B1 = c(mean(summary$brier_b1), mean(summary$logloss_b1)),
    B2 = c(mean(summary$brier_b2), mean(summary$logloss_b2)),
    H2 = c(mean(summary$brier_h2), mean(summary$logloss_h2)),
    Oracle = c(mean(summary$brier_oracle, na.rm = TRUE), mean(summary$logloss_oracle, na.rm = TRUE))
  )
  grDevices::png(path, width = 1500, height = 850, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(5, 5, 5, 1))
  graphics::barplot(
    t(scores), beside = TRUE, col = c("#D0EDFA", "#3D8DFF"),
    names.arg = rownames(scores), ylab = "Loss (lower is better)",
    main = "Proper probability scores compare forecasts, not state colors",
    sub = subtitle, border = NA
  )
  graphics::legend(
    "topright", legend = c("Brier", "Log loss"),
    fill = c("#D0EDFA", "#3D8DFF"), bty = "n"
  )
}

plot_calibration <- function(forecasts, path) {
  probability_columns <- c(B0 = "p_b0", B1 = "p_b1", B2 = "p_b2", H2 = "p_h2")
  bins <- seq(0, 1, by = 0.10)
  grDevices::png(path, width = 1300, height = 950, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(
    c(0, 1), c(0, 1), type = "n", xlab = "Mean forecast probability",
    ylab = "Observed positive-return frequency", asp = 1,
    main = "Fresh confirmation calibration",
    xlim = c(0, 1), ylim = c(0, 1)
  )
  graphics::abline(0, 1, col = "#B8BCC4", lty = 2L, lwd = 2L)
  colors <- c(B0 = "#7A7F87", B1 = "#B8BCC4", B2 = "#6DCBF4", H2 = "#3D8DFF")
  symbols <- c(B0 = 15L, B1 = 16L, B2 = 17L, H2 = 19L)
  for (name in names(probability_columns)) {
    probability <- forecasts[[probability_columns[[name]]]]
    group <- cut(probability, bins, include.lowest = TRUE)
    x <- tapply(probability, group, mean)
    y <- tapply(forecasts$outcome, group, mean)
    keep <- is.finite(x) & is.finite(y)
    graphics::lines(x[keep], y[keep], col = colors[[name]], lwd = 2L)
    graphics::points(x[keep], y[keep], col = colors[[name]], pch = symbols[[name]], cex = 1.2)
  }
  graphics::legend(
    "topleft", legend = names(probability_columns), col = colors,
    pch = symbols, lwd = 2L, bty = "n"
  )
}

plot_probability_tape <- function(tape, path) {
  colors <- ifelse(tape$true_state == 2L, "#1E9E91", "#E86A78")
  grDevices::png(path, width = 1600, height = 1000, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 1), mar = c(4, 5, 4, 1))
  graphics::plot(
    tape$oos_time, 100 * tape$ret, type = "h", col = colors,
    xlab = "", ylab = "Daily return (%)",
    main = "Known planted state changes the return distribution"
  )
  graphics::abline(h = 0, col = "#B8BCC4")
  graphics::plot(
    tape$oos_time, tape$p_more_favorable, type = "l", col = "#3D8DFF",
    lwd = 1.5, ylim = c(0, 1), xlab = "OOS session",
    ylab = "Causal P(more favorable)",
    main = "The latent-state probability remains soft and causal"
  )
  graphics::abline(h = 0.5, col = "#B8BCC4", lty = 2L)
}

plot_state_skill <- function(summary, path) {
  best_baseline <- pmin(summary$brier_b0, summary$brier_b1, summary$brier_b2)
  gain <- best_baseline - summary$brier_h2
  grDevices::png(path, width = 1200, height = 850, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(
    summary$filtered_accuracy, gain, pch = 19L, col = "#3D8DFF",
    xlab = "Hard-state accuracy (diagnostic)",
    ylab = "Brier gain versus best baseline",
    main = "State decoding and forecast skill are related but distinct"
  )
  graphics::abline(h = 0, col = "#E05D6F", lty = 2L, lwd = 2L)
  graphics::abline(v = 0.85, col = "#B8BCC4", lty = 3L)
}

plot_frontier <- function(frontier, path) {
  train_values <- sort(unique(frontier$train_length))
  drift_values <- sort(unique(frontier$drift_bp))
  persistence_values <- sort(unique(frontier$self_transition))
  limits <- max(abs(frontier$mean_brier_gain_vs_best), na.rm = TRUE)
  if (!is.finite(limits) || limits == 0) limits <- 0.01
  palette <- grDevices::colorRampPalette(c("#E86A78", "#FFFFFF", "#3D8DFF"))(101)
  grDevices::png(path, width = 1600, height = 800, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(1, length(train_values)), mar = c(5, 5, 5, 2))
  for (train_length in train_values) {
    part <- frontier[frontier$train_length == train_length, ]
    z <- matrix(NA_real_, nrow = length(persistence_values), ncol = length(drift_values))
    detected <- matrix(FALSE, nrow = nrow(z), ncol = ncol(z))
    for (row in seq_len(nrow(part))) {
      y <- match(part$self_transition[[row]], persistence_values)
      x <- match(part$drift_bp[[row]], drift_values)
      z[y, x] <- part$mean_brier_gain_vs_best[[row]]
      detected[y, x] <- part$detection_boundary_cell[[row]]
    }
    graphics::image(
      x = seq_along(drift_values), y = seq_along(persistence_values), z = t(z),
      col = palette, zlim = c(-limits, limits), axes = FALSE,
      xlab = "Absolute state drift (bp/day)", ylab = "Self-transition",
      main = paste0("TRAIN = ", train_length)
    )
    graphics::axis(1, at = seq_along(drift_values), labels = drift_values)
    graphics::axis(2, at = seq_along(persistence_values), labels = persistence_values)
    points <- which(detected, arr.ind = TRUE)
    if (nrow(points)) graphics::points(points[, 2L], points[, 1L], pch = 8L, cex = 2, lwd = 2)
    graphics::box()
  }
  graphics::mtext(
    "Blue = H2 lower Brier than best baseline; star = frozen detection cell",
    side = 1, outer = TRUE, line = -1.5, cex = 0.9
  )
}

cat("Running LIT-REG-02.2 Stage A fresh forecast confirmation...\n")
stage_a_results <- lapply(seq_len(nrow(positive_registry)), function(index) {
  cat(sprintf("  Stage A %02d/%02d\n", index, nrow(positive_registry)))
  g5_reg022_evaluate_registry_row(
    positive_registry[index, , drop = FALSE],
    contract,
    save_tape = index == 1L
  )
})
stage_a_summary <- combine_component(stage_a_results, "summary")
stage_a_forecasts <- combine_component(stage_a_results, "forecasts")
stage_a_diagnostics <- combine_component(stage_a_results, "diagnostics")
stage_a_tape <- stage_a_results[[1L]]$tape
stage_a_b2_diagnostics <- do.call(rbind, lapply(stage_a_results, function(result) {
  data.frame(
    case_id = result$summary$case_id,
    valid = isTRUE(result$b2_fit$valid),
    convergence = if (is.null(result$b2_fit)) NA_integer_ else result$b2_fit$convergence,
    objective = if (is.null(result$b2_fit)) NA_real_ else result$b2_fit$objective,
    lambda = contract$ridge_lambda,
    stringsAsFactors = FALSE
  )
}))
checks <- g5_reg022_stage_a_checks(
  stage_a_results[[1L]],
  positive_registry[1L, , drop = FALSE],
  contract
)
gate_result <- g5_reg022_stage_a_gates(
  stage_a_summary, stage_a_forecasts, checks, positive_registry, contract
)

write_table(stage_a_summary, "stage_a_case_summary.csv")
write_table(stage_a_forecasts, "stage_a_forecasts.csv")
write_table(stage_a_diagnostics, "stage_a_hmm_multistart_diagnostics.csv")
write_table(stage_a_b2_diagnostics, "stage_a_b2_diagnostics.csv")
write_table(stage_a_tape, "stage_a_representative_probability_tape.csv")
write_table(gate_result$gates, "stage_a_gates.csv")
write_table(gate_result$calibration, "stage_a_calibration.csv")
write_table(gate_result$skill, "stage_a_skill_details.csv")
write_table(data.frame(check = names(checks), value = unlist(checks)), "stage_a_causality_replay_checks.csv")

plot_score_comparison(
  stage_a_summary,
  file.path(run_dir, "stage_a_forecast_scores.png"),
  "24 fresh planted cases; lower is better"
)
plot_calibration(stage_a_forecasts, file.path(run_dir, "stage_a_calibration.png"))
plot_probability_tape(stage_a_tape, file.path(run_dir, "stage_a_probability_tape.png"))
plot_state_skill(stage_a_summary, file.path(run_dir, "stage_a_state_vs_skill.png"))

stage_a_pass <- all(gate_result$gates$passed)
if (!stage_a_pass) {
  verdict <- "STOP_LIT_REG_02_2_FRESH_FORECAST_CONFIRMATION_FAILED"
  writeLines(verdict, file.path(run_dir, "verdict.txt"))
  writeLines(c(
    "# LIT-REG-02.2 Run Report",
    "",
    paste0("Verdict: `", verdict, "`"),
    "",
    "Stage A was conjunctive. At least one fresh forecast-confirmation gate failed, so the still-unread frontier and stress registries were not executed.",
    "",
    "No market, residual, strategy, PnL, allocation, leverage, or live data were read."
  ), file.path(run_dir, "report.md"))
  cat(verdict, "\n")
  quit(save = "no", status = 0L)
}

cat("Running LIT-REG-02.2 Stage B still-unread frontier...\n")
stage_b_results <- lapply(seq_len(nrow(frontier_registry)), function(index) {
  cat(sprintf("  Stage B %02d/%02d\n", index, nrow(frontier_registry)))
  g5_reg022_evaluate_registry_row(frontier_registry[index, , drop = FALSE], contract)
})
stage_b_summary <- combine_component(stage_b_results, "summary")
stage_b_forecasts <- combine_component(stage_b_results, "forecasts")
stage_b_diagnostics <- combine_component(stage_b_results, "diagnostics")
frontier_summary <- g5_reg022_frontier_summary(stage_b_summary)
write_table(stage_b_summary, "stage_b_case_summary.csv")
write_table(stage_b_forecasts, "stage_b_forecasts.csv")
write_table(stage_b_diagnostics, "stage_b_hmm_multistart_diagnostics.csv")
write_table(frontier_summary, "stage_b_frontier_summary.csv")
plot_frontier(frontier_summary, file.path(run_dir, "stage_b_forecast_frontier.png"))

cat("Running LIT-REG-02.2 Stage C financial-shaped stress...\n")
stage_c_results <- lapply(seq_len(nrow(stress_registry)), function(index) {
  cat(sprintf("  Stage C %02d/%02d\n", index, nrow(stress_registry)))
  g5_reg022_evaluate_registry_row(stress_registry[index, , drop = FALSE], contract)
})
stage_c_summary <- combine_component(stage_c_results, "summary")
stage_c_forecasts <- combine_component(stage_c_results, "forecasts")
stage_c_diagnostics <- combine_component(stage_c_results, "diagnostics")
write_table(stage_c_summary, "stage_c_case_summary.csv")
write_table(stage_c_forecasts, "stage_c_forecasts.csv")
write_table(stage_c_diagnostics, "stage_c_hmm_multistart_diagnostics.csv")
plot_score_comparison(
  stage_c_summary,
  file.path(run_dir, "stage_c_stress_scores.png"),
  "Student-t GARCH innovations; Gaussian H2 deliberately misspecified"
)

verdict <- "COMPLETE_LIT_REG_02_2_SYNTHETIC_FORECAST_FRONTIER_MAPPED_MARKET_NOT_OPENED"
writeLines(verdict, file.path(run_dir, "verdict.txt"))
detectable <- frontier_summary[frontier_summary$detection_boundary_cell, , drop = FALSE]
null_false <- sum(
  frontier_summary$drift == 0 & frontier_summary$detection_boundary_cell,
  na.rm = TRUE
)
writeLines(c(
  "# LIT-REG-02.2 Run Report",
  "",
  paste0("Verdict: `", verdict, "`"),
  "",
  sprintf("Stage A passed %d/%d frozen gates.", sum(gate_result$gates$passed), nrow(gate_result$gates)),
  sprintf("Stage B marked %d/%d cells forecast-detectable; null false detections: %d.", nrow(detectable), nrow(frontier_summary), null_false),
  "Stage C completed as descriptive misspecification stress with no promotion gate.",
  "",
  "No market, residual, strategy, PnL, allocation, leverage, or live data were read."
), file.path(run_dir, "report.md"))
cat(verdict, "\n")
cat("Evidence packet:", normalizePath(run_dir, winslash = "/"), "\n")
