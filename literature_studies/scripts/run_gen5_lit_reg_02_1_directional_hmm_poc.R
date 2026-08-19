#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "literature_studies/scripts/run_gen5_lit_reg_02_1_directional_hmm_poc.R"
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
setwd(repo_root)

local_library <- normalizePath(file.path(repo_root, ".codex_r_libs"), winslash = "/", mustWork = TRUE)
.libPaths(c(local_library, .libPaths()))

source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_reg_02_1_directional_hmm_poc.R"
))

contract <- g5_reg021_contract()
g5_reg021_require_reference(contract)

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_studies",
  "lit_reg_02_1_directional_hmm_poc_20260819"
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

positive_registry <- g5_reg021_positive_registry()
frontier_registry <- g5_reg021_frontier_registry()
stress_registry <- g5_reg021_stress_registry()

run_spec <- data.frame(
  schema_version = g5_reg021_schema_version(),
  literature_id = contract$literature_id,
  run_date = "2026-08-19",
  reference_package = contract$reference_package,
  reference_version = contract$reference_version,
  horizon = contract$horizon,
  forecast_paths = contract$forecast_paths,
  starts_per_case = nrow(contract$starts),
  positive_cases = nrow(positive_registry),
  frontier_cases = nrow(frontier_registry),
  stress_cases = nrow(stress_registry),
  market_data_read = FALSE,
  semi_synthetic_market_data_read = FALSE,
  confirmation_data_read = FALSE,
  strategy_data_read = FALSE,
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(contract$starts, file.path(output_dir, "multistart_registry.csv"), row.names = FALSE)
utils::write.csv(positive_registry, file.path(output_dir, "stage_a_positive_registry.csv"), row.names = FALSE)
utils::write.csv(frontier_registry, file.path(output_dir, "stage_b_frontier_registry.csv"), row.names = FALSE)
utils::write.csv(stress_registry, file.path(output_dir, "stage_c_stress_registry.csv"), row.names = FALSE)

evaluate_registry <- function(registry, tape_first = FALSE) {
  results <- vector("list", nrow(registry))
  for (index in seq_len(nrow(registry))) {
    message("LIT-REG-02.1 case ", index, "/", nrow(registry), ": ", registry$case_id[[index]])
    results[[index]] <- g5_reg021_evaluate_registry_row(
      registry[index, , drop = FALSE],
      contract,
      save_tape = tape_first && index == 1L
    )
  }
  results
}

positive_results <- evaluate_registry(positive_registry, tape_first = TRUE)
positive_summary <- do.call(rbind, lapply(positive_results, `[[`, "summary"))
positive_forecasts <- do.call(rbind, lapply(positive_results, `[[`, "forecasts"))
positive_diagnostics <- do.call(rbind, lapply(positive_results, `[[`, "diagnostics"))
teaching_tape <- positive_results[[1L]]$tape
checks <- g5_reg021_stage_a_checks(positive_results[[1L]], contract)
stage_a_gates <- g5_reg021_stage_a_gates(positive_summary, checks, contract)

utils::write.csv(positive_summary, file.path(output_dir, "stage_a_case_summary.csv"), row.names = FALSE)
utils::write.csv(positive_forecasts, file.path(output_dir, "stage_a_forecasts.csv"), row.names = FALSE)
utils::write.csv(positive_diagnostics, file.path(output_dir, "stage_a_fit_diagnostics.csv"), row.names = FALSE)
utils::write.csv(teaching_tape, file.path(output_dir, "stage_a_teaching_probability_tape.csv"), row.names = FALSE)
utils::write.csv(stage_a_gates, file.path(output_dir, "stage_a_gates.csv"), row.names = FALSE)
utils::write.csv(
  data.frame(check = names(checks), observed = unlist(checks), stringsAsFactors = FALSE),
  file.path(output_dir, "stage_a_causality_determinism_checks.csv"),
  row.names = FALSE
)

png(file.path(output_dir, "stage_a_teaching_probability_tape.png"), width = 1600, height = 900, res = 140)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(2, 1), mar = c(3.5, 4.5, 3, 1.5))
plot(
  teaching_tape$oos_time, 100 * teaching_tape$ret,
  type = "h", lwd = 1.2,
  col = ifelse(teaching_tape$true_state == 2L, "#1B998B", "#D95D6A"),
  xlab = "OOS session", ylab = "Daily return (%)",
  main = "Known planted state changes the return distribution"
)
abline(h = 0, col = "#222222", lwd = 0.8)
plot(
  teaching_tape$oos_time, teaching_tape$p_more_favorable,
  type = "l", lwd = 2, col = "#2457C5", ylim = c(0, 1),
  xlab = "OOS session", ylab = "Causal P(more favorable)",
  main = "The package fit is translated into a causal probability tape"
)
polygon(
  c(teaching_tape$oos_time, rev(teaching_tape$oos_time)),
  c(ifelse(teaching_tape$true_state == 2L, 1, 0), rep(0, nrow(teaching_tape))),
  col = grDevices::adjustcolor("#1B998B", alpha.f = 0.14), border = NA
)
lines(teaching_tape$oos_time, teaching_tape$p_more_favorable, lwd = 2, col = "#2457C5")
abline(h = 0.5, lty = 2, col = "#666666")
par(old_par)
dev.off()

valid_a <- positive_summary[positive_summary$valid_fit, , drop = FALSE]
png(file.path(output_dir, "stage_a_forecast_scores.png"), width = 1500, height = 850, res = 140)
score_matrix <- rbind(
  Brier = c(B0 = mean(valid_a$brier_b0), B1 = mean(valid_a$brier_b1), H2 = mean(valid_a$brier_h2), Oracle = mean(valid_a$brier_oracle)),
  `Log loss` = c(B0 = mean(valid_a$logloss_b0), B1 = mean(valid_a$logloss_b1), H2 = mean(valid_a$logloss_h2), Oracle = mean(valid_a$logloss_oracle))
)
barplot(
  score_matrix, beside = TRUE,
  col = c("#F2B134", "#2457C5"), border = NA,
  main = "Probability scores distinguish base rate, dynamics, HMM, and oracle",
  ylab = "Lower is better", xlab = "Forecast authority"
)
legend("topright", legend = rownames(score_matrix), fill = c("#F2B134", "#2457C5"), bty = "n")
dev.off()

stage_a_pass <- all(stage_a_gates$passed)
if (!stage_a_pass) {
  verdict <- "STOP_LIT_REG_02_1_DIRECTIONAL_MECHANISM_QUALIFICATION_FAILED"
  writeLines(verdict, file.path(output_dir, "verdict.txt"))
  message("Stage A verdict: ", verdict)
  message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
  quit(status = 0L)
}

frontier_results <- evaluate_registry(frontier_registry)
frontier_summary <- do.call(rbind, lapply(frontier_results, `[[`, "summary"))
frontier_forecasts <- do.call(rbind, lapply(frontier_results, `[[`, "forecasts"))
frontier_diagnostics <- do.call(rbind, lapply(frontier_results, `[[`, "diagnostics"))
frontier_cells <- g5_reg021_frontier_summary(frontier_summary)
utils::write.csv(frontier_summary, file.path(output_dir, "stage_b_case_summary.csv"), row.names = FALSE)
utils::write.csv(frontier_forecasts, file.path(output_dir, "stage_b_forecasts.csv"), row.names = FALSE)
utils::write.csv(frontier_diagnostics, file.path(output_dir, "stage_b_fit_diagnostics.csv"), row.names = FALSE)
utils::write.csv(frontier_cells, file.path(output_dir, "stage_b_detection_frontier.csv"), row.names = FALSE)

draw_frontier <- function(value, title, filename, zlim = NULL) {
  png(file.path(output_dir, filename), width = 1600, height = 900, res = 140)
  old <- par(no.readonly = TRUE)
  par(mfrow = c(2, 2), mar = c(4, 4.5, 3.5, 1.5))
  for (train_length in c(1000L, 2000L)) {
    for (p in c(0.90, 0.97)) {
      part <- frontier_cells[
        frontier_cells$train_length == train_length & frontier_cells$self_transition == p,
        , drop = FALSE
      ]
      part <- part[order(part$drift_bp), ]
      values <- part[[value]]
      colors <- ifelse(values > 0, "#1B998B", "#D95D6A")
      barplot(
        values, names.arg = part$drift_bp, col = colors, border = NA,
        ylim = if (is.null(zlim)) range(c(values, 0), finite = TRUE) else zlim,
        main = paste0("TRAIN ", train_length, " | persistence ", p),
        xlab = "Absolute planted drift (bp/day)", ylab = "HMM improvement"
      )
      abline(h = 0, col = "#222222")
    }
  }
  mtext(title, outer = TRUE, line = -1.5, cex = 1.15, font = 2)
  par(old)
  dev.off()
}
draw_frontier(
  "mean_brier_gain_vs_b1",
  "Detection frontier: Brier improvement over the one-state AR(1)",
  "stage_b_brier_frontier.png"
)

png(file.path(output_dir, "stage_b_state_accuracy_frontier.png"), width = 1500, height = 850, res = 140)
accuracy_cells <- frontier_cells[frontier_cells$drift > 0, , drop = FALSE]
plot(
  10000 * accuracy_cells$drift + ifelse(accuracy_cells$train_length == 2000L, 0.8, -0.8),
  accuracy_cells$median_state_accuracy,
  pch = ifelse(accuracy_cells$self_transition == 0.97, 19, 1),
  col = ifelse(accuracy_cells$train_length == 2000L, "#2457C5", "#D95D6A"),
  cex = 1.5, ylim = c(0.45, 1),
  xlab = "Absolute planted drift (bp/day; slight jitter by TRAIN length)",
  ylab = "Median causal state accuracy",
  main = "State recovery improves with signal, persistence, and history"
)
abline(h = 0.5, lty = 2, col = "#666666")
legend(
  "bottomright",
  legend = c("TRAIN 1,000", "TRAIN 2,000", "p=0.90", "p=0.97"),
  col = c("#D95D6A", "#2457C5", "#222222", "#222222"),
  pch = c(19, 19, 1, 19), bty = "n"
)
dev.off()

stress_results <- evaluate_registry(stress_registry)
stress_summary <- do.call(rbind, lapply(stress_results, `[[`, "summary"))
stress_forecasts <- do.call(rbind, lapply(stress_results, `[[`, "forecasts"))
stress_diagnostics <- do.call(rbind, lapply(stress_results, `[[`, "diagnostics"))
utils::write.csv(stress_summary, file.path(output_dir, "stage_c_case_summary.csv"), row.names = FALSE)
utils::write.csv(stress_forecasts, file.path(output_dir, "stage_c_forecasts.csv"), row.names = FALSE)
utils::write.csv(stress_diagnostics, file.path(output_dir, "stage_c_fit_diagnostics.csv"), row.names = FALSE)

png(file.path(output_dir, "stage_c_financial_noise_stress.png"), width = 1500, height = 850, res = 140)
stress_valid <- stress_summary[stress_summary$valid_fit, , drop = FALSE]
boxplot(
  cbind(
    `HMM - constant` = stress_valid$brier_b0 - stress_valid$brier_h2,
    `HMM - AR(1)` = stress_valid$brier_b1 - stress_valid$brier_h2
  ),
  col = c("#A8DADC", "#F4A261"), border = "#222222",
  ylab = "Brier improvement; positive favors HMM",
  main = "Financial-shaped noise tests robustness to tails and volatility clustering"
)
abline(h = 0, lty = 2, col = "#666666")
dev.off()

verdict <- "PASS_LIT_REG_02_1_DIRECTIONAL_MECHANISM_DETECTION_BOUNDARY_MAPPED"
writeLines(verdict, file.path(output_dir, "verdict.txt"))

frontier_pass <- frontier_cells[frontier_cells$detection_boundary_cell, , drop = FALSE]
report <- c(
  "# LIT-REG-02.1 Directional Markov-Switching Proof-of-Mechanism",
  "",
  paste0("Verdict: `", verdict, "`"),
  "",
  "## Evidence Boundary",
  "",
  "- Package-native synthetic qualification, detection-frontier mapping, and fully synthetic financial-noise stress only.",
  "- No Alpaca query, market bar, market residual, 2024+ observation, strategy, PnL, Sharpe, drawdown, allocation, leverage, or live behavior was read.",
  "- A PASS means the planted mechanism was recovered and its detection boundary was measured; it is not market or alpha promotion.",
  "",
  "## Stage A Gates",
  "",
  "| Gate | Status | Observed |",
  "|---|---|---|",
  paste0("| ", stage_a_gates$gate_id, " | `", stage_a_gates$status, "` | ", stage_a_gates$observed, " |"),
  "",
  "## Stage B Detection Frontier",
  "",
  paste0("- Characterized ", nrow(frontier_summary), " frozen cases across drift, persistence, and TRAIN length."),
  paste0("- Detection-boundary cells meeting the frozen 3-of-4 joint score rule: ", nrow(frontier_pass), "."),
  "- The frontier is descriptive power evidence, not a tuned parameter recommendation.",
  "",
  "## Stage C Financial-Shaped Stress",
  "",
  paste0("- Numerically valid cases: ", sum(stress_summary$valid_fit), "/", nrow(stress_summary), "."),
  sprintf("- Mean HMM Brier improvement versus constant: %.4f; versus AR(1): %.4f.", mean(stress_valid$brier_b0 - stress_valid$brier_h2), mean(stress_valid$brier_b1 - stress_valid$brier_h2)),
  "- Student-t GARCH innovations are fully synthetic. This is not semi-synthetic market evidence.",
  "",
  "## Next Gate",
  "",
  "Discuss whether to open a separately frozen real-residual semi-synthetic bridge or honest market TRAIN/OOS developmental lane. No strategy contact is authorized."
)
writeLines(report, file.path(output_dir, "report.md"))

message("Verdict: ", verdict)
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
