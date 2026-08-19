# Run the committed synthetic/engine gate for LIT-REG-01.1.

options(stringsAsFactors = FALSE)

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "literature_studies", "R", "gen5_lit_reg_01_1_hmm_engine.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_reg_01_1_hmm_poc.R"))

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

run_id <- env_or("GEN5_LIT_REG_011_STAGE_A_RUN_ID", "lit_reg_01_1_hmm_stage_a_20260819")
run_dir <- file.path(repo_root, "runs", "research_workbench", "literature_studies", run_id)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create LIT-REG-01.1 Stage A output directory.", call. = FALSE)

workers <- as.integer(env_or("GEN5_LIT_REG_011_STAGE_A_WORKERS", "4"))
if (!is.finite(workers) || workers < 1L) stop("Stage A worker count must be a positive integer.", call. = FALSE)
case_map <- lapply
cluster <- NULL
if (workers > 1L) {
  cluster <- parallel::makePSOCKcluster(workers)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  engine_path <- file.path(repo_root, "literature_studies", "R", "gen5_lit_reg_01_1_hmm_engine.R")
  poc_path <- file.path(repo_root, "literature_studies", "R", "gen5_lit_reg_01_1_hmm_poc.R")
  parallel::clusterExport(cluster, c("engine_path", "poc_path"), envir = environment())
  parallel::clusterEvalQ(cluster, {
    source(engine_path)
    source(poc_path)
    NULL
  })
  case_map <- function(x, fun) parallel::parLapply(cluster, x, fun)
}

message("LIT-REG-01.1 Stage A: running frozen engine and synthetic gates with ", workers, " worker(s).")
result <- g5_reg011_stage_a(case_map = case_map)
write_csv(result$gates, file.path(run_dir, "stage_a_gates.csv"))
write_csv(result$simulations, file.path(run_dir, "synthetic_recovery.csv"))
write_csv(result$replay_diagnostics, file.path(run_dir, "deterministic_replay_diagnostics.csv"))

fixtures <- result$fixtures
fixture_ledger <- rbind(
  data.frame(
    fixture = "STRONG", seed = fixtures$strong_seeds,
    sequence_length = fixtures$sequence_length,
    transition_11 = fixtures$strong$transition[1, 1],
    transition_22 = fixtures$strong$transition[2, 2],
    range_mean_1 = fixtures$strong$means[1, 2],
    range_mean_2 = fixtures$strong$means[2, 2],
    stringsAsFactors = FALSE
  ),
  data.frame(
    fixture = "WEAK", seed = fixtures$weak_seeds,
    sequence_length = fixtures$sequence_length,
    transition_11 = fixtures$weak$transition[1, 1],
    transition_22 = fixtures$weak$transition[2, 2],
    range_mean_1 = fixtures$weak$means[1, 2],
    range_mean_2 = fixtures$weak$means[2, 2],
    stringsAsFactors = FALSE
  )
)
write_csv(fixture_ledger, file.path(run_dir, "synthetic_fixture_ledger.csv"))

run_spec <- data.frame(
  field = c(
    "literature_id", "schema_version", "fixture_version", "run_id", "run_date",
    "sequence_length", "strong_seed_range", "weak_seed_range", "worker_count", "stage_a_verdict"
  ),
  value = c(
    result$contract$literature_id,
    g5_reg011_schema_version(),
    result$fixtures$fixture_version,
    run_id,
    "2026-08-19",
    as.character(result$fixtures$sequence_length),
    paste(range(result$fixtures$strong_seeds), collapse = ":"),
    paste(range(result$fixtures$weak_seeds), collapse = ":"),
    as.character(workers),
    result$verdict
  ),
  stringsAsFactors = FALSE
)
write_csv(run_spec, file.path(run_dir, "run_spec.csv"))

png(file.path(visual_dir, "synthetic_classification_and_uncertainty.png"), width = 1800, height = 900, res = 150)
old <- par(mfrow = c(1, 2), mar = c(6, 6, 4, 2))
strong <- result$simulations[result$simulations$fixture == "STRONG", ]
weak <- result$simulations[result$simulations$fixture == "WEAK", ]
boxplot(
  100 * strong$accuracy,
  names = "Strong separation",
  ylab = "Filtered state accuracy (%)",
  main = "Known strong states are recovered causally",
  col = "#6DCBF4", border = "#0F172A", ylim = c(0, 100)
)
abline(h = c(85, 90), col = c("#F59E0B", "#177245"), lty = 2)
boxplot(
  list(Strong = strong$maximum_posterior_confidence, Weak = weak$maximum_posterior_confidence),
  ylab = "Mean maximum filtered probability",
  main = "Weak evidence produces less confidence",
  col = c("#3D8DFF", "#EDEDED"), border = "#0F172A", ylim = c(0.45, 1)
)
par(old)
dev.off()

png(file.path(visual_dir, "synthetic_transition_recovery.png"), width = 1500, height = 900, res = 150)
old <- par(mar = c(6, 6, 4, 2))
hist(
  strong$maximum_transition_error,
  breaks = 14, col = "#6DCBF4", border = "white",
  xlab = "Maximum absolute transition-probability error",
  main = "Transition recovery across 50 strong simulations"
)
abline(v = c(.03, .08), col = c("#177245", "#F59E0B"), lty = 2, lwd = 2)
par(old)
dev.off()

report <- c(
  "# LIT-REG-01.1 Stage A Engine and Synthetic Evidence",
  "",
  paste0("Status: `", result$verdict, "`"),
  "",
  "The real SPY comparison was not read by this runner. Stage A is a dependency-free",
  "mathematical and synthetic recovery gate that must pass first.",
  "",
  "## Gate Readout",
  "",
  "| Gate | Requirement | Observed | Status |",
  "|---|---|---|---|",
  vapply(seq_len(nrow(result$gates)), function(i) {
    row <- result$gates[i, ]
    paste0("| ", row$gate, " — ", row$gate_name, " | ", row$threshold, " | ", row$observed, " | `", row$status, "` |")
  }, character(1)),
  "",
  "## Boundary",
  "",
  "- Fixture parameters, seeds, and assertions are committed source artifacts.",
  "- No Alpaca query, SPY observation, 2024+ observation, strategy, or performance metric is used.",
  "- A failure records the frozen Stage A STOP and leaves the real-data runner closed."
)
writeLines(report, file.path(run_dir, "stage_a_report.md"), useBytes = TRUE)

manifest <- data.frame(
  artifact = c(
    "run_spec", "gates", "synthetic_recovery", "fixture_ledger", "replay_diagnostics",
    "classification_visual", "transition_visual", "report"
  ),
  path = c(
    "run_spec.csv", "stage_a_gates.csv", "synthetic_recovery.csv",
    "synthetic_fixture_ledger.csv", "deterministic_replay_diagnostics.csv",
    "visuals/synthetic_classification_and_uncertainty.png",
    "visuals/synthetic_transition_recovery.png", "stage_a_report.md"
  ),
  stringsAsFactors = FALSE
)
write_csv(manifest, file.path(run_dir, "manifest.csv"))
saveRDS(result, file.path(run_dir, "stage_a_result.rds"))

message("LIT-REG-01.1 Stage A verdict: ", result$verdict)
message("Artifacts: ", normalizePath(run_dir, winslash = "/", mustWork = TRUE))
if (!result$passed) quit(save = "no", status = 2L)
