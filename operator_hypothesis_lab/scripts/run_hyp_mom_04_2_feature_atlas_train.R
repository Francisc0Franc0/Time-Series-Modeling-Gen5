options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_2_engine.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract <- h042_validate_contract()
run_id <- env_or("GEN5_HYP_MOM_042_TRAIN_RUN_ID", "hyp_mom_04_2_feature_atlas_train_20260811")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

audit_dir <- env_or(
  "GEN5_HYP_MOM_042_AUDIT_DIR",
  file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
            "hyp_mom_04_1_deployment_universe_data_audit_20260811")
)
audit_dir <- normalizePath(audit_dir, winslash = "/", mustWork = TRUE)
audit_status <- trimws(readLines(file.path(audit_dir, "status.txt"), warn = FALSE)[[1L]])
audit_gates <- utils::read.csv(file.path(audit_dir, "universe_gate_matrix.csv"), stringsAsFactors = FALSE)
if (audit_status != "DEPLOYMENT_UNIVERSE_DATA_AUDIT_PASS_TRAIN_AUTHORIZED" || !all(audit_gates$passed)) {
  stop("HYP-MOM-04.2 requires the passing frozen deployment-universe audit.", call. = FALSE)
}
audit_coverage <- utils::read.csv(file.path(audit_dir, "train_coverage_ledger.csv"), stringsAsFactors = FALSE)
audit_coverage <- audit_coverage[audit_coverage$complete_train, , drop = FALSE]
registry <- data.frame(
  instance_id = paste0("SPY_202009_", audit_coverage$source_symbol),
  symbol = audit_coverage$provider_symbol,
  sector = audit_coverage$sector,
  cohort = "SPY_2020_09_DEPLOYMENT",
  stringsAsFactors = FALSE
)
registry <- h04_validate_registry(registry, expected_count = NULL)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_MOM_042_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$train_query_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = c(registry$symbol, "SPY"),
  universe_name = "hyp_mom_04_2_feature_atlas_train",
  universe_roles = "fixed_pre_oos_spy_cohort,spy_calendar,feature_atlas_train_only",
  refresh = refresh,
  repo_root = repo_root
)
old_contract <- h04_contract()
bars_all <- h04_validate_bars(query$bars, contract$train_query_end, old_contract)
spy <- bars_all[bars_all$symbol == "SPY", , drop = FALSE]
calendar_dates <- spy$session_date
coverage <- h04_coverage(
  bars_all[bars_all$symbol != "SPY", , drop = FALSE], registry, calendar_dates,
  contract$train_query_end, old_contract, expected_registry_count = NULL
)
eligible_registry <- registry[registry$symbol %in% coverage$symbol[coverage$analysis_eligible], , drop = FALSE]
if (nrow(eligible_registry) < contract$minimum_assets) {
  stop("Too few deployment-universe identities passed the frozen exact-session rule.", call. = FALSE)
}

panel <- h042_build_panel(
  bars = bars_all[bars_all$symbol %in% eligible_registry$symbol, , drop = FALSE],
  market_bars = spy,
  registry = eligible_registry,
  calendar_dates = calendar_dates,
  contract = contract
)

quarter_counts <- as.data.frame(table(panel$signal_quarter), stringsAsFactors = FALSE)
names(quarter_counts) <- c("signal_quarter", "asset_count")
integrity <- data.frame(
  check_id = c(
    "FROZEN_DEPLOYMENT_AUDIT_PASS", "ALPACA_ADJUSTED_DAILY", "EXPLICIT_AS_OF_TIMESTAMP",
    "TRAIN_QUERY_BOUNDARY", "NO_DUPLICATE_BARS", "SPY_CALENDAR_AVAILABLE",
    "ALL_15_TRAIN_QUARTERS", "AT_LEAST_400_IDENTITIES", "MINIMUM_ASSETS_PER_QUARTER",
    "FEATURES_FINITE", "SIGNAL_PRECEDES_ENTRY", "ENTRY_PRECEDES_EXIT",
    "RELATIVE_TARGET_CENTERED", "NO_OOS_OBSERVATIONS"
  ),
  passed = c(
    all(audit_gates$passed),
    all(bars_all$provider == "alpaca" & bars_all$adjusted %in% c(TRUE, "TRUE") & bars_all$timeframe == "1D"),
    all(nzchar(as.character(bars_all$as_of_timestamp))),
    max(bars_all$session_date) <= contract$train_query_end,
    !anyDuplicated(bars_all[c("symbol", "session_date")]),
    nrow(spy) > 0L,
    identical(unique(panel$signal_quarter), contract$train_signal_quarters),
    length(unique(panel$symbol)) >= contract$minimum_assets,
    min(table(panel$signal_quarter)) >= contract$minimum_assets_per_quarter,
    all(is.finite(as.matrix(panel[c(contract$feature_names, "target_return", "target_relative_return")]))),
    all(panel$signal_date < panel$entry_date),
    all(panel$entry_date < panel$exit_date),
    max(abs(tapply(panel$target_relative_return, panel$signal_quarter, mean))) < 1e-12,
    !any(bars_all$session_date >= contract$forbidden_start)
  ),
  stringsAsFactors = FALSE
)
if (!all(integrity$passed)) stop("HYP-MOM-04.2 integrity checks failed before feature analysis.", call. = FALSE)

message("Building feature diagnostics for ", length(contract$feature_names), " features...")
diagnostics <- h042_feature_diagnostics(panel, contract)
message("Running nested predefined-basket selection...")
nested <- h042_nested_outer(panel, contract = contract)
original <- h042_nested_outer(panel, candidates = "RIDGE_ORIGINAL_6", contract = contract)
message("Running ", contract$permutation_draws, " full-search permutations...")
permutation <- h042_permutation_search(panel, nested, contract)
gate_result <- h042_gate_matrix(panel, all(integrity$passed), nested, original, permutation, contract)
gates <- gate_result$gates
status <- if (gate_result$nominated) "TRAIN_NOMINATED_OOS_STILL_LOCKED" else "STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN"

inner_details <- do.call(rbind, lapply(nested$inner, `[[`, "details"))
inner_summary <- do.call(rbind, lapply(nested$inner, `[[`, "summary"))
redundancy_long <- as.data.frame(as.table(diagnostics$redundancy), stringsAsFactors = FALSE)
names(redundancy_long) <- c("feature_a", "feature_b", "rank_correlation")
selected_panel <- merge(nested$predictions, panel[c("row_id", "target_return", "target_relative_return")], by = "row_id", sort = FALSE)

run_spec <- data.frame(
  program_id = contract$program_id, run_id = run_id, as_of_timestamp = contract$as_of_timestamp,
  query_start = as.character(contract$query_start), train_query_end = as.character(contract$train_query_end),
  forbidden_start = as.character(contract$forbidden_start), registered_identities = nrow(registry),
  eligible_identities = length(unique(panel$symbol)), panel_rows = nrow(panel), train_quarters = 15L,
  feature_count = length(contract$feature_names), candidate_count = length(contract$baskets),
  permutation_draws = contract$permutation_draws, status = status,
  created_without_oos_access = TRUE, stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "hyp_mom_04_2_run_spec.csv"))
write_csv(integrity, file.path(output_dir, "hyp_mom_04_2_integrity.csv"))
write_csv(query$health, file.path(output_dir, "hyp_mom_04_2_query_health.csv"))
write_csv(registry, file.path(output_dir, "hyp_mom_04_2_frozen_registry.csv"))
write_csv(coverage, file.path(output_dir, "hyp_mom_04_2_train_coverage.csv"))
write_csv(quarter_counts, file.path(output_dir, "hyp_mom_04_2_quarter_counts.csv"))
write_csv(h042_feature_dictionary(), file.path(output_dir, "hyp_mom_04_2_feature_dictionary.csv"))
write_csv(h042_candidate_registry(contract), file.path(output_dir, "hyp_mom_04_2_candidate_registry.csv"))
write_csv(panel, file.path(output_dir, "hyp_mom_04_2_feature_panel.csv"))
write_csv(diagnostics$scorecard, file.path(output_dir, "hyp_mom_04_2_feature_scorecard.csv"))
write_csv(diagnostics$quarterly, file.path(output_dir, "hyp_mom_04_2_feature_quarterly_ic.csv"))
write_csv(diagnostics$deciles, file.path(output_dir, "hyp_mom_04_2_feature_decile_curves.csv"))
write_csv(redundancy_long, file.path(output_dir, "hyp_mom_04_2_feature_redundancy.csv"))
write_csv(diagnostics$redundancy_pairs, file.path(output_dir, "hyp_mom_04_2_redundancy_pairs.csv"))
write_csv(inner_details, file.path(output_dir, "hyp_mom_04_2_inner_details.csv"))
write_csv(inner_summary, file.path(output_dir, "hyp_mom_04_2_inner_summary.csv"))
write_csv(nested$selections, file.path(output_dir, "hyp_mom_04_2_outer_selections.csv"))
write_csv(nested$metrics, file.path(output_dir, "hyp_mom_04_2_outer_metrics.csv"))
write_csv(nested$predictions, file.path(output_dir, "hyp_mom_04_2_outer_predictions.csv"))
write_csv(nested$coefficients, file.path(output_dir, "hyp_mom_04_2_outer_coefficients.csv"))
write_csv(original$metrics, file.path(output_dir, "hyp_mom_04_2_original_challenger_metrics.csv"))
write_csv(permutation, file.path(output_dir, "hyp_mom_04_2_full_search_permutation.csv"))
write_csv(gates, file.path(output_dir, "hyp_mom_04_2_train_gates.csv"))
writeLines(status, file.path(output_dir, "status.txt"))
saveRDS(list(contract = contract, gates = gates, status = status, selections = nested$selections,
             created_without_oos_access = TRUE), file.path(output_dir, "hyp_mom_04_2_train_nomination.rds"))

blue <- "#167D9A"; navy <- "#142B4A"; green <- "#2AA876"; red <- "#D1495B"
orange <- "#F28E2B"; pale <- "#D9EEF3"; gray <- "#67717E"; purple <- "#7A5195"

png(file.path(visual_dir, "feature_scorecard.png"), 2200, 1400, res = 170)
par(mfrow = c(1, 2), mar = c(10, 5, 4, 1))
score <- diagnostics$scorecard[order(diagnostics$scorecard$mean_rank_ic), ]
barplot(score$mean_rank_ic, names.arg = score$feature, horiz = FALSE, las = 2,
        col = ifelse(score$mean_rank_ic > 0, green, red), border = NA,
        ylab = "Mean quarterly Spearman IC", main = "Feature direction across 15 TRAIN quarters")
abline(h = 0, col = gray)
score2 <- diagnostics$scorecard[order(diagnostics$scorecard$positive_ic_fraction), ]
barplot(score2$positive_ic_fraction, names.arg = score2$feature, las = 2,
        col = ifelse(score2$positive_ic_fraction >= 0.6, green, orange), border = NA,
        ylab = "Fraction of quarters with positive IC", main = "Feature sign stability")
abline(h = 0.6, lty = 2, col = navy)
dev.off()

ic_matrix <- xtabs(rank_ic ~ feature + signal_quarter, diagnostics$quarterly)
png(file.path(visual_dir, "feature_quarterly_ic_heatmap.png"), 2200, 1700, res = 170)
par(mar = c(7, 13, 4, 2))
z <- ic_matrix
z[] <- pmax(-0.25, pmin(0.25, ic_matrix))
image(seq_len(ncol(z)), seq_len(nrow(z)), t(z[nrow(z):1, , drop = FALSE]),
      col = colorRampPalette(c(red, "white", green))(101), axes = FALSE,
      xlab = "Signal quarter", ylab = "", main = "Quarter-aware feature IC: stability matters more than pooled fit")
axis(1, seq_len(ncol(z)), colnames(z), las = 2, cex.axis = 0.8)
axis(2, seq_len(nrow(z)), rev(rownames(z)), las = 2, cex.axis = 0.65)
box()
dev.off()

png(file.path(visual_dir, "feature_redundancy_heatmap.png"), 1900, 1800, res = 170)
par(mar = c(12, 12, 4, 2))
corr <- diagnostics$redundancy
image(seq_len(ncol(corr)), seq_len(nrow(corr)), t(corr[nrow(corr):1, , drop = FALSE]),
      col = colorRampPalette(c(navy, "white", orange))(101), zlim = c(-1, 1), axes = FALSE,
      xlab = "", ylab = "", main = "Feature redundancy: rank correlation across TRAIN")
axis(1, seq_len(ncol(corr)), colnames(corr), las = 2, cex.axis = 0.55)
axis(2, seq_len(nrow(corr)), rev(rownames(corr)), las = 2, cex.axis = 0.55)
box()
dev.off()

png(file.path(visual_dir, "nested_outer_validation.png"), 2100, 1300, res = 170)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 1))
m <- nested$metrics
plot(seq_len(nrow(m)), m$rank_ic, type = "b", pch = 19, xaxt = "n", lwd = 2,
     col = ifelse(m$rank_ic > 0, green, red), xlab = "Outer validation quarter", ylab = "Spearman IC",
     main = "Nested outer validation")
axis(1, seq_len(nrow(m)), m$signal_quarter, las = 2)
abline(h = 0, col = gray)
plot(seq_len(nrow(m)), 100 * m$q4_excess, type = "b", pch = 19, xaxt = "n", lwd = 2,
     col = ifelse(m$q4_excess > 0, green, red), xlab = "Outer validation quarter", ylab = "Top-quartile excess (pp)",
     main = "Selected top-quartile behavior")
axis(1, seq_len(nrow(m)), m$signal_quarter, las = 2)
abline(h = 0, col = gray)
dev.off()

png(file.path(visual_dir, "full_search_permutation.png"), 1900, 1200, res = 170)
hist(permutation$mean_outer_rank_ic, breaks = 25, col = pale, border = "white",
     xlab = "Mean outer IC after full basket search", main = "Full-search permutation null")
abline(v = unique(permutation$observed_mean_outer_rank_ic), col = purple, lwd = 4)
legend("topright", legend = c(
  paste0("Observed = ", formatC(unique(permutation$observed_mean_outer_rank_ic), digits = 3, format = "f")),
  paste0("Search-adjusted p = ", formatC(unique(permutation$search_adjusted_p_value), digits = 3, format = "f"))
), lwd = c(4, NA), col = c(purple, NA), bty = "n")
dev.off()

feature_chunks <- split(contract$feature_names, ceiling(seq_along(contract$feature_names) / 6))
for (sheet in seq_along(feature_chunks)) {
  features <- feature_chunks[[sheet]]
  png(file.path(visual_dir, sprintf("scatter_atlas_%02d.png", sheet)), 2400, 1600, res = 170)
  par(mfrow = c(2, 3), mar = c(5, 5, 4, 1))
  for (feature in features) {
    x <- panel[[feature]]; y <- 100 * panel$target_relative_return
    limits <- stats::quantile(x, c(0.01, 0.99), na.rm = TRUE)
    keep <- x >= limits[[1L]] & x <= limits[[2L]]
    plot(x[keep], y[keep], pch = 16, cex = 0.22, col = grDevices::adjustcolor(blue, alpha.f = 0.14),
         xlab = feature, ylab = "Next-quarter relative return (pp)", main = feature)
    d <- h042_decile(x)
    dx <- tapply(x, d, stats::median); dy <- 100 * tapply(panel$target_relative_return, d, mean)
    lines(dx, dy, col = orange, lwd = 3); points(dx, dy, col = orange, pch = 19, cex = 0.8)
    abline(h = 0, col = gray, lty = 3)
  }
  if (length(features) < 6L) for (unused in seq_len(6L - length(features))) plot.new()
  dev.off()
}

top_features <- diagnostics$scorecard[order(-diagnostics$scorecard$mean_rank_ic), c("feature", "family", "mean_rank_ic", "positive_ic_fraction")]
top_features <- head(top_features, 8L)
selection_text <- paste(paste0("outer ", nested$selections$outer_fold, ": ", nested$selections$candidate,
                               ifelse(is.na(nested$selections$lambda), "", paste0(" (lambda ", nested$selections$lambda, ")"))), collapse = "; ")
failed <- gates$gate_id[!gates$passed]
report <- c(
  "# HYP-MOM-04.2 Feature Atlas TRAIN Report", "",
  paste0("Status: `", status, "`"), "",
  "## Scope", "",
  paste0("The packet contains ", nrow(panel), " stock-quarter rows from ", length(unique(panel$symbol)),
         " coverage-eligible identities across 15 TRAIN quarters. The independent temporal evidence remains 15 quarters."),
  "No observation dated 2021 or later was queried.", "",
  "## Feature atlas", "",
  paste0("Thirty-three causal OHLCV features were examined. The strongest mean quarterly IC features were: ",
         paste(paste0(top_features$feature, " (", formatC(top_features$mean_rank_ic, digits = 3, format = "f"), ")"), collapse = ", "), "."),
  paste0("There were ", nrow(diagnostics$redundancy_pairs), " feature pairs with absolute rank correlation at or above ",
         contract$redundancy_threshold, "."), "",
  "## Nested basket readout", "",
  paste0("Selections: ", selection_text, "."),
  paste0("Mean outer IC: ", formatC(mean(nested$metrics$rank_ic), digits = 4, format = "f"),
         "; positive quarters: ", sum(nested$metrics$rank_ic > 0), " / 6."),
  paste0("Mean outer top-quartile excess: ", formatC(100 * mean(nested$metrics$q4_excess), digits = 2, format = "f"), " pp; positive quarters: ",
         sum(nested$metrics$q4_excess > 0), " / 6."),
  paste0("Frozen original-six challenger mean outer IC: ", formatC(mean(original$metrics$rank_ic), digits = 4, format = "f"), "."),
  paste0("Full-search permutation p-value: ", formatC(unique(permutation$search_adjusted_p_value), digits = 3, format = "f"), "."), "",
  "## Decision", "",
  if (length(failed)) paste0("Failed gates: ", paste(failed, collapse = ", "), ".") else "All frozen TRAIN gates passed; OOS remains locked pending an explicit operator decision.",
  "The scatterplots are descriptive. Basket promotion depends on nested quarter-level transport and the full-search null, not visual appeal."
)
writeLines(report, file.path(output_dir, "REPORT.md"))

cat("Status:", status, "\n")
cat("Output:", normalizePath(output_dir, winslash = "/", mustWork = TRUE), "\n")
print(gates)
