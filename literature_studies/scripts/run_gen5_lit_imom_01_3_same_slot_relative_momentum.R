# Run the frozen LIT-IMOM-01.3 same-slot relative-momentum comparison.

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
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_01_4_multi_market_predictor_atlas.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_01_5_path_quality_forecast_comparison.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_imom_01_3_same_slot_relative_momentum.R"))
options(warn = 1)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create LIT-IMOM-01.3 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

write_optional <- function(x, path, status) {
  if (nrow(x)) write_csv(x, path) else write_csv(data.frame(status = status), path)
}

contract_table <- function(contract) data.frame(
  field = names(contract),
  value = vapply(contract, function(value) paste(value, collapse = ","), character(1)),
  stringsAsFactors = FALSE
)

load_cached_bars <- function(repo_root, contract) {
  years <- 2017:2023
  paths <- file.path(
    repo_root, "data_cache", "alpaca_intraday_30min",
    sprintf("intraday_30min_sip_all_%d.rds", years)
  )
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop(paste("Missing frozen cache files:", paste(missing, collapse = ", ")), call. = FALSE)
  out <- do.call(rbind, lapply(paths, readRDS))
  out[out$session_date >= contract$query_start & out$session_date <= contract$query_end, , drop = FALSE]
}

model_colors <- c(M0_CLOCK = "#94A3B8", M1_DAY = "#2B6CB0", M2_SAME = "#0F766E")

plot_model_losses <- function(metrics, path) {
  x <- metrics[metrics$model_id %in% names(model_colors), , drop = FALSE]
  groups <- split(x$development_scaled_loss, factor(x$model_id, levels = names(model_colors)))
  png(path, width = 1500, height = 1000, res = 150)
  old <- par(mar = c(7, 6, 5, 2)); on.exit({ par(old); dev.off() }, add = TRUE)
  boxplot(groups, col = unname(model_colors), border = "#334155", las = 2,
    ylab = "DEVELOPMENT standardized squared loss", xlab = "",
    main = "Same-slot forecast authority comparison")
  grid(nx = NA, ny = NULL, col = "#E2E8F0")
}

plot_asset_contrasts <- function(decisions, path) {
  color <- ifelse(decisions$candidate_fdr, "#2563EB", "#94A3B8")
  pch <- ifelse(decisions$is_same_slot_candidate, 19, 1)
  png(path, width = 1500, height = 1000, res = 150)
  old <- par(mar = c(6, 6, 5, 2)); on.exit({ par(old); dev.off() }, add = TRUE)
  plot(decisions$s21_mean, decisions$u_mean, col = color, pch = pch,
    xlab = "S21: same slot over prior-day control",
    ylab = "U: same slot over best wrong clock",
    main = "Asset-level incremental forecast evidence")
  abline(h = 0, v = 0, col = "#CBD5E1")
  text(decisions$s21_mean, decisions$u_mean, labels = decisions$symbol, pos = 3, cex = 0.65, col = color)
}

plot_panel_intervals <- function(panel_contrasts, path) {
  x <- panel_contrasts[match(c("G10", "S21", "S20", "U"), panel_contrasts$contrast_id), ]
  values <- x$observed_mean_differential
  png(path, width = 1500, height = 1000, res = 150)
  old <- par(mar = c(7, 7, 5, 2)); on.exit({ par(old); dev.off() }, add = TRUE)
  plot(seq_along(values), values, pch = 19, col = "#0F766E", xaxt = "n",
    ylim = range(c(x$ci_lower_90, x$ci_upper_90, 0)),
    xlab = "", ylab = "Mean standardized loss improvement",
    main = "Equal-weight 22-stock panel: 90% bootstrap intervals")
  arrows(seq_along(values), x$ci_lower_90, seq_along(values), x$ci_upper_90,
    angle = 90, code = 3, length = 0.08, col = "#0F766E", lwd = 2)
  axis(1, at = seq_along(values), labels = c("Prior day / clock", "Same / prior day", "Same / clock", "Same / best placebo"), las = 2)
  abline(h = 0, col = "#B42318", lty = 2)
}

plot_wrong_clock <- function(panel_session_losses, path) {
  placebo <- vapply(1:12, function(k) mean(panel_session_losses[[sprintf("W%02d", k)]]), numeric(1))
  same <- mean(panel_session_losses$S21)
  png(path, width = 1500, height = 1000, res = 150)
  old <- par(mar = c(6, 6, 5, 2)); on.exit({ par(old); dev.off() }, add = TRUE)
  plot(1:12, placebo, type = "h", lwd = 7, col = "#94A3B8",
    xlab = "Circular source-slot displacement", ylab = "Improvement over prior-day control",
    main = "Wrong-clock falsification surface", xaxt = "n")
  axis(1, at = 1:12)
  abline(h = same, col = "#0F766E", lwd = 3)
  abline(h = 0, col = "#CBD5E1")
  legend("topright", legend = c("Same slot", "Wrong-clock offsets"),
    col = c("#0F766E", "#94A3B8"), lwd = c(3, 7), bty = "n")
}

plot_coefficients <- function(summary, path) {
  x <- summary[order(summary$same_slot_coefficient), , drop = FALSE]
  color <- ifelse(x$candidate_fdr, "#2563EB", "#94A3B8")
  png(path, width = 1700, height = 1000, res = 150)
  old <- par(mar = c(8, 6, 5, 2)); on.exit({ par(old); dev.off() }, add = TRUE)
  barplot(x$same_slot_coefficient, names.arg = x$symbol, las = 2, col = color, border = NA,
    ylab = "TRAIN same-slot coefficient", main = "Frozen pooled coefficient by asset")
  abline(h = 0, col = "#334155")
}

plot_slot_breadth <- function(slot_diagnostics, path) {
  x <- slot_diagnostics[slot_diagnostics$candidate_fdr, , drop = FALSE]
  z <- aggregate(same_slot_improvement_over_day ~ target_slot, data = x, FUN = median)
  png(path, width = 1500, height = 1000, res = 150)
  old <- par(mar = c(6, 6, 5, 2)); on.exit({ par(old); dev.off() }, add = TRUE)
  plot(z$target_slot, z$same_slot_improvement_over_day, type = "b", pch = 19,
    col = "#2563EB", lwd = 2, xaxt = "n", xlab = "Target slot",
    ylab = "Median S21 improvement across 22 stocks",
    main = "Descriptive slot breadth (no slot selection)")
  axis(1, at = 1:13, labels = 1:13)
  abline(h = 0, col = "#B42318", lty = 2)
}

write_report <- function(result, paths, path) {
  candidate <- result$decisions[result$decisions$candidate_fdr, , drop = FALSE]
  panel <- result$panel_contrasts
  panel_lines <- vapply(c("G10", "S21", "S20", "U"), function(id) {
    x <- panel[panel$contrast_id == id, , drop = FALSE]
    sprintf("- `%s`: mean `%.6f`, 90%% interval `[%.6f, %.6f]`, one-sided p `%.6f`.",
      id, x$observed_mean_differential, x$ci_lower_90, x$ci_upper_90, x$centered_null_upper_p)
  }, character(1))
  strongest <- candidate[order(candidate$u_mean, decreasing = TRUE), , drop = FALSE]
  strongest_lines <- vapply(seq_len(min(5L, nrow(strongest))), function(i) {
    sprintf("- `%s`: S21 `%.6f`, U `%.6f`, q(S21) `%.6f`, q(U) `%.6f`, coefficient `%.4f`.",
      strongest$symbol[[i]], strongest$s21_mean[[i]], strongest$u_mean[[i]],
      strongest$s21_q[[i]], strongest$u_q[[i]], strongest$same_slot_coefficient[[i]])
  }, character(1))
  model_medians <- aggregate(development_scaled_loss ~ model_id,
    data = result$metrics[result$metrics$model_id %in% result$contract$primary_model_ids, ], FUN = median)
  model_lines <- vapply(seq_len(nrow(model_medians)), function(i) {
    sprintf("- `%s`: median standardized loss `%.6f`.", model_medians$model_id[[i]], model_medians$development_scaled_loss[[i]])
  }, character(1))
  report <- c(
    "# LIT-IMOM-01.3 Same-Slot Relative Momentum", "",
    paste0("Status: `", result$overall_status, "`"), "",
    "## Frozen question", "",
    "Does one session's slot-normalized stock-minus-SPY return forecast the same slot next session beyond clock effects, prior full-session relative momentum, and every wrong-clock alignment?", "",
    "## Validity", "",
    sprintf("- `%d / 26` registry rows passed mechanical panel checks; SPY was benchmark-only.", sum(result$ledger$mechanically_eligible)),
    sprintf("- `%d` TRAIN and `%d` DEVELOPMENT consecutive full-session targets were admitted.",
      unique(result$ledger$train_target_sessions), unique(result$ledger$development_target_sessions)),
    "- All comparisons used the identical 13-slot observations. Early closes and archive exclusions were not bridged or imputed.",
    "- 2024+ was not loaded. No strategy or performance outcome was computed.", "",
    "## Primary model losses", "", model_lines, "",
    "## Equal-weight candidate-panel inference", "", panel_lines, "",
    sprintf("Broad-panel clue: `%s`.", result$broad_panel_clue), "",
    "## Asset gates", "",
    sprintf("- Same-slot candidates: `%d / 22`.", sum(candidate$is_same_slot_candidate)),
    sprintf("- General-day clues: `%d / 22`.", sum(candidate$general_day_clue)),
    sprintf("- Positive S21 / S20 / U rows: `%d / %d / %d` of 22.",
      sum(candidate$s21_mean > 0), sum(candidate$s20_mean > 0), sum(candidate$u_mean > 0)), "",
    "Strongest U rows, reported diagnostically:", "", strongest_lines, "",
    "## Interpretation boundary", "",
    if (result$broad_panel_clue || nrow(result$candidates)) {
      "The frozen DEVELOPMENT test contains a bounded same-slot clue. It does not authorize confirmation, slot selection, or a trading rule."
    } else {
      "The same-slot narrative did not survive the frozen general-day, wrong-clock, dependence, breadth, and multiplicity controls. Do not select a favorable slot, offset, or asset."
    }, "",
    "## Evidence files", "",
    paste0("- Decisions: `", basename(paths$decisions), "`."),
    paste0("- Panel inference: `", basename(paths$panel_contrasts), "`."),
    paste0("- Asset inference: `", basename(paths$contrasts), "`."),
    paste0("- Wrong-clock surface: `", basename(paths$placebo), "`."),
    "- Visual evidence: `visuals/`.", "",
    "No thresholds, positions, hedges, trades, costs, turnover, P&L, Sharpe, drawdown, allocation, leverage, advice, execution, or live behavior were computed."
  )
  writeLines(report, path, useBytes = TRUE)
}

contract <- g5_imom013_contract()
registry_path <- file.path(repo_root, contract$registry_relative_path)
registry_hash <- g5_mom014_file_sha256(registry_path)
if (!identical(registry_hash, contract$registry_sha256)) stop("Frozen registry checksum changed.", call. = FALSE)
registry <- g5_imom013_validate_registry(read.csv(registry_path, stringsAsFactors = FALSE), contract)
bars_raw <- load_cached_bars(repo_root, contract)
bars <- g5_imom013_prepare_bars(bars_raw, registry, contract)
calendar <- g5_imom013_session_calendar(bars, registry, contract)
ledger <- g5_imom013_coverage_ledger(bars, registry, calendar, contract)

preflight_only <- env_bool("GEN5_LIT_IMOM_01_3_PREFLIGHT_ONLY", FALSE)
default_run_id <- if (preflight_only) {
  "lit_imom_01_3_same_slot_relative_momentum_preflight_20260821"
} else {
  "lit_imom_01_3_same_slot_relative_momentum_20260821"
}
run_id <- env_or("GEN5_LIT_IMOM_01_3_RUN_ID", default_run_id)
output_dir <- file.path(repo_root, "runs", "research_workbench", "literature_grounded", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(output_dir); ensure_dir(visual_dir)

health <- data.frame(
  check = c("registry_sha256", "all_26_mechanically_eligible", "confirmation_absent",
    "archive_exclusions_not_bridged", "minimum_train_sessions", "minimum_development_sessions"),
  status = c(
    if (identical(registry_hash, contract$registry_sha256)) "PASS" else "ERROR",
    if (all(ledger$mechanically_eligible)) "PASS" else "ERROR",
    if (max(bars$session_date) < contract$confirmation_start) "PASS" else "ERROR",
    if (!any(calendar$consecutive_pair_eligible & calendar$archive_excluded)) "PASS" else "ERROR",
    if (all(ledger$train_target_sessions >= contract$minimum_target_sessions)) "PASS" else "ERROR",
    if (all(ledger$development_target_sessions >= contract$minimum_target_sessions)) "PASS" else "ERROR"
  ),
  detail = c(registry_hash, paste(sum(ledger$mechanically_eligible), "of 26"),
    paste("maximum session", max(bars$session_date)),
    paste(length(contract$archive_exclusion_dates), "frozen exclusions"),
    paste(unique(ledger$train_target_sessions), "target sessions"),
    paste(unique(ledger$development_target_sessions), "target sessions")),
  stringsAsFactors = FALSE
)
write_csv(contract_table(contract), file.path(output_dir, "imom013_frozen_contract.csv"))
write_csv(registry, file.path(output_dir, "imom013_frozen_registry.csv"))
write_csv(calendar, file.path(output_dir, "imom013_session_calendar.csv"))
write_csv(ledger, file.path(output_dir, "imom013_coverage_and_eligibility.csv"))
write_csv(health, file.path(output_dir, "imom013_data_health.csv"))
if (any(health$status == "ERROR")) stop("LIT-IMOM-01.3 preflight failed.", call. = FALSE)
if (preflight_only) {
  message("LIT-IMOM-01.3 preflight complete; forecast outcomes were not computed.")
  message("Output: ", output_dir)
  quit(save = "no", status = 0L)
}

result <- g5_imom013_run_comparison(bars_raw, registry, contract)
run_spec <- data.frame(
  schema_version = g5_imom013_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_imom_01_3_same_slot_relative_momentum.R",
  run_id = run_id, design_as_of_timestamp = contract$design_as_of_timestamp,
  cache_as_of_timestamp = contract$cache_as_of_timestamp, registry_sha256 = registry_hash,
  registry_assets = nrow(registry), fitted_assets = sum(!registry$benchmark_only),
  candidate_assets = sum(registry$candidate_fdr), train_start = contract$train_start,
  train_end = contract$train_end, development_start = contract$development_start,
  development_end = contract$development_end, confirmation_opened = result$confirmation_opened,
  strategy_surface_opened = FALSE, performance_surface_opened = FALSE,
  overall_status = result$overall_status, stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "imom013_run_spec.csv"),
  metrics = file.path(output_dir, "imom013_model_metrics.csv"),
  coefficients = file.path(output_dir, "imom013_coefficients.csv"),
  moments = file.path(output_dir, "imom013_train_moments.csv"),
  anchor_losses = file.path(output_dir, "imom013_development_slot_losses.csv"),
  session_losses = file.path(output_dir, "imom013_development_session_losses.csv"),
  contrasts = file.path(output_dir, "imom013_asset_contrasts.csv"),
  decisions = file.path(output_dir, "imom013_asset_decisions.csv"),
  candidates = file.path(output_dir, "imom013_candidates.csv"),
  general = file.path(output_dir, "imom013_general_day_clues.csv"),
  panel_losses = file.path(output_dir, "imom013_panel_session_losses.csv"),
  panel_contrasts = file.path(output_dir, "imom013_panel_contrasts.csv"),
  placebo = file.path(output_dir, "imom013_wrong_clock_surface.csv"),
  slot = file.path(output_dir, "imom013_slot_diagnostics.csv"),
  report = file.path(output_dir, "imom013_report.md")
)
write_csv(run_spec, paths$run_spec); write_csv(result$metrics, paths$metrics)
write_csv(result$coefficients, paths$coefficients); write_csv(result$feature_moments, paths$moments)
write_csv(result$anchor_losses, paths$anchor_losses); write_csv(result$session_losses, paths$session_losses)
write_csv(result$contrasts, paths$contrasts); write_csv(result$decisions, paths$decisions)
write_optional(result$candidates, paths$candidates, "NO_SAME_SLOT_CANDIDATES")
write_optional(result$general_day_clues, paths$general, "NO_GENERAL_DAY_CLUES")
write_csv(result$panel_session_losses, paths$panel_losses)
write_csv(result$panel_contrasts, paths$panel_contrasts)
write_csv(result$placebo_summary, paths$placebo); write_csv(result$slot_diagnostics, paths$slot)

plot_model_losses(result$metrics, file.path(visual_dir, "imom013_model_loss_comparison.png"))
plot_asset_contrasts(result$decisions, file.path(visual_dir, "imom013_asset_contrasts.png"))
plot_panel_intervals(result$panel_contrasts, file.path(visual_dir, "imom013_panel_intervals.png"))
plot_wrong_clock(result$panel_session_losses, file.path(visual_dir, "imom013_wrong_clock_surface.png"))
plot_coefficients(result$coefficient_summary, file.path(visual_dir, "imom013_same_slot_coefficients.png"))
plot_slot_breadth(result$slot_diagnostics, file.path(visual_dir, "imom013_slot_breadth.png"))
write_report(result, paths, paths$report)

message("LIT-IMOM-01.3 complete: ", result$overall_status)
message("Mechanically eligible registry rows: ", sum(result$ledger$mechanically_eligible), " / 26")
message("Broad panel clue: ", result$broad_panel_clue)
message("Asset candidates: ", nrow(result$candidates), " / 22")
message("General-day clues: ", nrow(result$general_day_clues), " / 22")
message("Confirmation opened: ", result$confirmation_opened)
message("Output: ", output_dir)
