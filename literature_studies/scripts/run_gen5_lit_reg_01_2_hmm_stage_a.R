#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "literature_studies/scripts/run_gen5_lit_reg_01_2_hmm_stage_a.R"
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
setwd(repo_root)

local_library <- normalizePath(file.path(repo_root, ".codex_r_libs"), winslash = "/", mustWork = TRUE)
.libPaths(c(local_library, .libPaths()))

source(file.path(repo_root, "literature_studies", "R", "gen5_lit_reg_01_1_hmm_engine.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_reg_01_2_hmm_volatility_poc.R"))

contract <- g5_reg012_contract()
g5_reg012_require_reference(contract)
registry <- g5_reg012_synthetic_registry()

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_studies",
  "lit_reg_01_2_hmm_stage_a_20260819"
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

run_spec <- data.frame(
  schema_version = g5_reg012_schema_version(),
  literature_id = contract$literature_id,
  stage = "A_REFERENCE_ENGINE_SYNTHETIC",
  run_date = "2026-08-19",
  reference_package = contract$reference_package,
  reference_version = contract$reference_version,
  fixture_count = nrow(registry),
  starts_per_fixture = length(contract$hmm_seeds),
  market_data_read = FALSE,
  confirmation_data_read = FALSE,
  strategy_data_read = FALSE,
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(registry, file.path(output_dir, "synthetic_fixture_registry.csv"), row.names = FALSE)

worker_count <- max(1L, min(8L, parallel::detectCores(logical = FALSE) - 1L, nrow(registry)))
message("LIT-REG-01.2 Stage A: ", nrow(registry), " fixtures on ", worker_count, " workers")

evaluate_index <- function(index) {
  evaluated <- g5_reg012_evaluate_fixture(registry[index, , drop = FALSE], contract)
  list(summary = evaluated$summary, diagnostics = evaluated$diagnostics)
}

if (worker_count > 1L) {
  cluster <- parallel::makePSOCKcluster(worker_count)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  parallel::clusterExport(
    cluster,
    c("repo_root", "local_library", "registry", "contract"),
    envir = environment()
  )
  parallel::clusterEvalQ(cluster, {
    .libPaths(c(local_library, .libPaths()))
    source(file.path(repo_root, "literature_studies", "R", "gen5_lit_reg_01_1_hmm_engine.R"))
    source(file.path(repo_root, "literature_studies", "R", "gen5_lit_reg_01_2_hmm_volatility_poc.R"))
    NULL
  })
  results <- parallel::parLapply(cluster, seq_len(nrow(registry)), function(index) {
    evaluated <- g5_reg012_evaluate_fixture(registry[index, , drop = FALSE], contract)
    list(summary = evaluated$summary, diagnostics = evaluated$diagnostics)
  })
  parallel::stopCluster(cluster)
  on.exit(NULL, add = FALSE)
} else {
  results <- lapply(seq_len(nrow(registry)), evaluate_index)
}

summary <- do.call(rbind, lapply(results, `[[`, "summary"))
diagnostics <- do.call(rbind, lapply(results, `[[`, "diagnostics"))
short_check <- g5_reg012_short_likelihood_check()
causal_check <- g5_reg012_replay_and_causality_checks(contract)
gates <- g5_reg012_stage_a_gates(summary, short_check, causal_check, contract)

utils::write.csv(summary, file.path(output_dir, "synthetic_case_summary.csv"), row.names = FALSE)
utils::write.csv(diagnostics, file.path(output_dir, "reference_fit_diagnostics.csv"), row.names = FALSE)
utils::write.csv(short_check, file.path(output_dir, "reference_likelihood_crosscheck.csv"), row.names = FALSE)
utils::write.csv(
  data.frame(
    check = c("replay", "append_filtered", "smoothing_revision"),
    observed = c(
      causal_check$replay_maximum_difference,
      causal_check$append_filtered_maximum_difference,
      causal_check$smoothing_revision_maximum
    ),
    stringsAsFactors = FALSE
  ),
  file.path(output_dir, "determinism_causality_checks.csv"),
  row.names = FALSE
)
utils::write.csv(gates, file.path(output_dir, "stage_a_gates.csv"), row.names = FALSE)

status_table <- as.data.frame(table(summary$fixture_class, summary$status), stringsAsFactors = FALSE)
names(status_table) <- c("fixture_class", "status", "count")
utils::write.csv(status_table, file.path(output_dir, "status_by_fixture_class.csv"), row.names = FALSE)

png(file.path(output_dir, "stage_a_status_by_fixture.png"), width = 1400, height = 850, res = 130)
status_matrix <- xtabs(count ~ fixture_class + status, status_table)
barplot(
  t(status_matrix), beside = FALSE,
  col = c("#49A5FF", "#111111", "#C7C7C7")[seq_len(ncol(status_matrix))],
  border = NA, ylim = c(0, 20),
  main = "LIT-REG-01.2 Stage A: explicit promotion, abstention, and failure",
  xlab = "Frozen synthetic fixture class", ylab = "Cases"
)
legend("topright", legend = colnames(status_matrix), fill = c("#49A5FF", "#111111", "#C7C7C7")[seq_len(ncol(status_matrix))], bty = "n", cex = 0.8)
dev.off()

strong <- summary[summary$fixture_class == "strong", , drop = FALSE]
png(file.path(output_dir, "stage_a_strong_recovery.png"), width = 1400, height = 850, res = 130)
plot(
  strong$filtered_accuracy, strong$maximum_transition_error,
  pch = 19, col = "#1473E6", cex = 1.2,
  xlim = c(0.8, 1), ylim = c(0, max(0.12, strong$maximum_transition_error, na.rm = TRUE)),
  xlab = "Causal filtered-state accuracy", ylab = "Maximum transition-probability error",
  main = "Strong-state recovery must be accurate in both labels and persistence"
)
abline(v = 0.90, h = 0.10, lty = 2, col = "#666666")
dev.off()

png(file.path(output_dir, "stage_a_uncertainty.png"), width = 1400, height = 850, res = 130)
classes <- c("strong", "weak", "null")
boxplot(
  posterior_entropy ~ factor(fixture_class, levels = classes), data = summary,
  col = c("#DCEEFF", "#A7D4FF", "#E8E8E8"), border = "#222222",
  xlab = "Frozen synthetic fixture class", ylab = "Mean causal posterior entropy",
  main = "Ambiguous evidence should increase uncertainty or trigger abstention"
)
dev.off()

all_pass <- all(gates$passed)
verdict <- if (all_pass) {
  "STAGE_A_PASS_LIT_REG_01_2_SPY_GATE_OPEN"
} else {
  "STOP_LIT_REG_01_2_REFERENCE_OR_SYNTHETIC_GATES_FAILED_MARKET_DATA_NOT_READ"
}
writeLines(verdict, file.path(output_dir, "verdict.txt"))

report <- c(
  "# LIT-REG-01.2 HMM Volatility-State Stage A",
  "",
  paste0("Verdict: `", verdict, "`"),
  "",
  "## Boundary",
  "",
  "- Frozen reference, engine, and synthetic qualification only.",
  "- No Alpaca query or adjusted daily bar was read.",
  "- No 2024+ observation, strategy, return direction, or performance metric was read.",
  "",
  "## Gates",
  "",
  "| Gate | Status | Observed |",
  "|---|---|---|",
  paste0("| ", gates$gate_id, " | `", gates$status, "` | ", gates$observed, " |"),
  "",
  "The gate is conjunctive. A failed gate stops before market data."
)
writeLines(report, file.path(output_dir, "stage_a_report.md"))

message("Stage A verdict: ", verdict)
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
