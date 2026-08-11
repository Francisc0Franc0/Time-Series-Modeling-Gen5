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

contract <- h04_validate_contract()
run_id <- env_or("GEN5_HYP_MOM_041_TRAIN_RUN_ID", "hyp_mom_04_1_train_20260810")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

deployment_audit_dir <- env_or("GEN5_HYP_MOM_041_TRAIN_AUDIT_DIR", "")
deployment_mode <- nzchar(deployment_audit_dir)
if (deployment_mode) {
  deployment_audit_dir <- normalizePath(deployment_audit_dir, winslash = "/", mustWork = TRUE)
  audit_status <- trimws(readLines(file.path(deployment_audit_dir, "status.txt"), warn = FALSE)[[1L]])
  audit_gates <- utils::read.csv(file.path(deployment_audit_dir, "universe_gate_matrix.csv"), stringsAsFactors = FALSE)
  if (audit_status != "DEPLOYMENT_UNIVERSE_DATA_AUDIT_PASS_TRAIN_AUTHORIZED" || !all(audit_gates$passed)) {
    stop("Deployment-universe TRAIN requires a passing frozen data audit.", call. = FALSE)
  }
  audit_coverage <- utils::read.csv(file.path(deployment_audit_dir, "train_coverage_ledger.csv"), stringsAsFactors = FALSE)
  audit_coverage <- audit_coverage[audit_coverage$complete_train, , drop = FALSE]
  registry <- data.frame(
    instance_id = paste0("SPY_202009_", audit_coverage$source_symbol),
    symbol = audit_coverage$provider_symbol,
    sector = audit_coverage$sector,
    cohort = "SPY_2020_09_DEPLOYMENT",
    stringsAsFactors = FALSE
  )
  registry_origin <- "PASSING_DEPLOYMENT_UNIVERSE_DATA_AUDIT"
  registry_source_integrity <- nrow(registry) == sum(audit_coverage$complete_train) && all(audit_gates$passed)
  sector_breadth_integrity <- length(unique(registry$sector)) >= 10L
  expected_registry_count <- NULL
} else {
  original <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_01_1_discovery_registry.csv"), stringsAsFactors = FALSE)
  original$cohort <- "ORIGINAL_22"
  wide <- utils::read.csv(file.path(repo_root, "literature_studies", "registries", "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"), stringsAsFactors = FALSE)
  registry <- rbind(
    original[c("instance_id", "symbol", "sector", "cohort")],
    wide[c("instance_id", "symbol", "sector", "cohort")]
  )
  registry_origin <- "FROZEN_122_CROSS_SECTION"
  registry_source_integrity <- !length(intersect(original$symbol, wide$symbol))
  sector_breadth_integrity <- length(unique(registry$sector)) == 11L
  expected_registry_count <- 122L
}
registry <- h04_validate_registry(registry, expected_count = expected_registry_count)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_MOM_041_TRAIN_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$train_query_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = c(registry$symbol, "SPY"),
  universe_name = if (deployment_mode) "hyp_mom_04_1_deployment_universe_train" else "hyp_mom_04_1_train",
  universe_roles = if (deployment_mode) "fixed_pre_oos_spy_cohort,spy_calendar" else "frozen_122_cross_section,spy_calendar",
  refresh = refresh,
  repo_root = repo_root
)
bars_all <- h04_validate_bars(query$bars, contract$train_query_end, contract)
spy <- bars_all[bars_all$symbol == "SPY", , drop = FALSE]
calendar_dates <- spy$session_date
coverage <- h04_coverage(bars_all[bars_all$symbol != "SPY", , drop = FALSE], registry,
                         calendar_dates, contract$train_query_end, contract,
                         expected_registry_count = expected_registry_count)
eligible_registry <- registry[registry$symbol %in% coverage$symbol[coverage$analysis_eligible], , drop = FALSE]
if (nrow(eligible_registry) < contract$minimum_assets_per_quarter) stop("Too few TRAIN identities passed complete coverage.", call. = FALSE)

panel <- h04_build_panel(
  bars = bars_all[bars_all$symbol %in% eligible_registry$symbol, , drop = FALSE],
  registry = eligible_registry,
  calendar_dates = calendar_dates,
  signal_quarters = contract$train_signal_quarters,
  authorized_end = contract$train_query_end,
  contract = contract
)

quarter_counts <- as.data.frame(table(panel$signal_quarter), stringsAsFactors = FALSE)
names(quarter_counts) <- c("signal_quarter", "asset_count")
integrity <- data.frame(
  check_id = c(
    if (deployment_mode) "FROZEN_DEPLOYMENT_REGISTRY" else "FROZEN_REGISTRY_122",
    if (deployment_mode) "DEPLOYMENT_DATA_AUDIT_PASSED" else "REGISTRY_SOURCES_NONOVERLAPPING",
    if (deployment_mode) "AT_LEAST_TEN_REGISTERED_SECTORS" else "ELEVEN_REGISTERED_SECTORS",
    "ALPACA_ADJUSTED_DAILY", "EXPLICIT_AS_OF_TIMESTAMP", "TRAIN_QUERY_BOUNDARY",
    "NO_DUPLICATE_BARS", "SPY_CALENDAR_AVAILABLE", "ALL_15_TRAIN_QUARTERS",
    "MINIMUM_ASSETS_PER_QUARTER", "FEATURES_FINITE", "SIGNAL_PRECEDES_ENTRY",
    "ENTRY_PRECEDES_EXIT", "RELATIVE_TARGET_CENTERED", "NO_2024_PLUS"
  ),
  passed = c(
    if (deployment_mode) nrow(registry) > 0L else nrow(registry) == 122L,
    registry_source_integrity,
    sector_breadth_integrity,
    all(bars_all$provider == "alpaca" & bars_all$adjusted %in% c(TRUE, "TRUE") & bars_all$timeframe == "1D"),
    all(nzchar(as.character(bars_all$as_of_timestamp))),
    max(bars_all$session_date) <= contract$train_query_end,
    !anyDuplicated(bars_all[c("symbol", "session_date")]),
    nrow(spy) > 0L,
    identical(unique(panel$signal_quarter), contract$train_signal_quarters),
    min(table(panel$signal_quarter)) >= contract$minimum_assets_per_quarter,
    all(is.finite(as.matrix(panel[c(contract$feature_names, "target_return", "target_relative_return")]))),
    all(panel$signal_date < panel$entry_date),
    all(panel$entry_date < panel$exit_date),
    max(abs(tapply(panel$target_relative_return, panel$signal_quarter, mean))) < 1e-12,
    max(bars_all$session_date) < contract$unqueried_start
  ),
  stringsAsFactors = FALSE
)

cv <- h04_cv(panel, contract = contract)
final_fit <- h04_fit_final(panel, cv$selected_lambda, contract = contract)
scored <- h04_score_panel(panel, final_fit, contract)
quarter_summary <- h04_quarter_summary(scored)
theory_quarter_summary <- h04_quarter_summary(scored, "theory_score", "theory_quartile")
univariate <- h04_univariate_sorts(panel, contract)
fama_macbeth <- h04_fama_macbeth(panel, contract)
permutation <- h04_permutation(panel, contract)
bootstrap <- h04_block_bootstrap(quarter_summary, contract$bootstrap_draws, contract$random_seed + 20000L)
gate_result <- h04_train_gates(panel, cv, scored, permutation, all(integrity$passed), contract)
gates <- gate_result$gates
nominated <- gate_result$nominated

coefficient_summary <- do.call(rbind, lapply(split(fama_macbeth, fama_macbeth$term), function(x) {
  data.frame(term = unique(x$term), mean_coefficient = mean(x$coefficient),
             median_coefficient = stats::median(x$coefficient),
             positive_fraction = mean(x$coefficient > 0), stringsAsFactors = FALSE)
}))
univariate_summary <- do.call(rbind, lapply(split(univariate, univariate$feature), function(x) {
  data.frame(feature = unique(x$feature), mean_rank_ic = mean(x$rank_ic),
             positive_ic_fraction = mean(x$rank_ic > 0), mean_q4_excess = mean(x$q4_excess),
             mean_q4_minus_q1 = mean(x$q4_minus_q1), stringsAsFactors = FALSE)
}))
selected <- scored[scored$ridge_quartile == 4L, , drop = FALSE]
sector_contribution <- aggregate(pmax(selected$target_relative_return, 0), list(sector = selected$sector), sum)
names(sector_contribution)[[2L]] <- "positive_relative_contribution"
sector_contribution$share <- sector_contribution$positive_relative_contribution / sum(sector_contribution$positive_relative_contribution)
sector_contribution <- sector_contribution[order(-sector_contribution$share), ]

blue <- "#2B6CB0"; light_blue <- "#90CDF4"; green <- "#2F855A"; red <- "#C53030"
gray <- "#718096"; dark <- "#1A202C"; purple <- "#805AD5"; pale <- "#EDF2F7"

png(file.path(visual_dir, "train_feature_diagnostics.png"), 1900, 1200, res = 150)
par(mfrow = c(1, 2), mar = c(9, 5, 4, 2))
u <- univariate_summary[order(univariate_summary$mean_rank_ic), ]
barplot(u$mean_rank_ic, names.arg = u$feature, las = 2,
        col = ifelse(u$mean_rank_ic > 0, green, red), ylab = "Mean quarterly Spearman IC",
        main = "Single-feature rank signal")
abline(h = 0, lty = 2, col = gray)
coef_no_intercept <- coefficient_summary[coefficient_summary$term != "intercept", ]
barplot(coef_no_intercept$positive_fraction, names.arg = coef_no_intercept$term, las = 2,
        col = blue, ylim = c(0, 1), ylab = "Fraction of quarterly coefficients > 0",
        main = "Fama-MacBeth sign stability")
abline(h = 0.5, lty = 2, col = gray)
dev.off()

png(file.path(visual_dir, "train_ridge_selection.png"), 1900, 1200, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(cv$summary$lambda, cv$summary$mean_rank_ic, type = "b", log = "x", pch = 19,
     col = blue, lwd = 2, xlab = "Ridge lambda (log scale)", ylab = "Mean validation rank IC",
     main = "Expanding-CV lambda selection")
arrows(cv$summary$lambda, cv$summary$mean_rank_ic - cv$summary$se_rank_ic,
       cv$summary$lambda, cv$summary$mean_rank_ic + cv$summary$se_rank_ic,
       angle = 90, code = 3, length = 0.05, col = gray)
abline(h = cv$one_se_threshold, lty = 2, col = purple)
abline(v = cv$selected_lambda, lty = 3, col = green)
plot(seq_len(nrow(cv$selected_details)), cv$selected_details$rank_ic, type = "h", lwd = 5,
     col = ifelse(cv$selected_details$rank_ic > 0, green, red), xaxt = "n",
     xlab = "Validation signal quarter", ylab = "Spearman IC",
     main = "Selected-lambda validation quarters")
axis(1, seq_len(nrow(cv$selected_details)), cv$selected_details$signal_quarter, las = 2, cex.axis = 0.8)
abline(h = 0, lty = 2, col = gray)
dev.off()

png(file.path(visual_dir, "train_quartile_behavior.png"), 1900, 1200, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 2))
quartile_returns <- aggregate(scored$target_return, list(quartile = scored$ridge_quartile), mean)
barplot(100 * quartile_returns$x, names.arg = paste("Q", quartile_returns$quartile),
        col = c(red, gray, light_blue, green), ylab = "Mean next-quarter return (%)",
        main = "Final TRAIN model by score quartile")
abline(h = 0, lty = 2, col = gray)
plot(seq_len(nrow(quarter_summary)), 100 * quarter_summary$q4_excess, type = "b", pch = 19,
     col = ifelse(quarter_summary$q4_excess > 0, green, red), xaxt = "n",
     xlab = "Signal quarter", ylab = "Q4 excess over universe (pp)",
     main = "Top-quartile behavior through TRAIN")
axis(1, seq_len(nrow(quarter_summary)), quarter_summary$signal_quarter, las = 2, cex.axis = 0.75)
abline(h = 0, lty = 2, col = gray)
dev.off()

png(file.path(visual_dir, "train_permutation_and_gates.png"), 1900, 1200, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 2))
hist(100 * permutation$q4_excess, breaks = 30, col = pale, border = "white",
     xlab = "Permuted full-procedure Q4 excess (pp)",
     main = "Within-quarter permutation control")
abline(v = 100 * unique(permutation$observed_q4_excess), col = purple, lwd = 3)
barplot(as.integer(gates$passed), names.arg = gates$gate_id, las = 2, ylim = c(0, 1.15),
        col = ifelse(gates$passed, green, red), ylab = "Pass (1) / fail (0)",
        main = if (nominated) "TRAIN nominated the frozen model" else "TRAIN stopped before OOS")
abline(h = 1, lty = 3, col = gray)
dev.off()

png(file.path(visual_dir, "train_sector_contribution.png"), 1700, 1100, res = 150)
par(mar = c(9, 5, 4, 2))
barplot(100 * sector_contribution$share, names.arg = sector_contribution$sector, las = 2,
        col = ifelse(sector_contribution$share <= 0.35, blue, red),
        ylab = "Share of positive Q4 relative contribution (%)",
        main = "Selected-name contribution is not allowed to hinge on one sector")
abline(h = 35, lty = 2, col = red)
dev.off()

status <- if (nominated) "TRAIN_NOMINATED_FOR_RETROSPECTIVE_OOS" else "STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN"
run_spec <- data.frame(
  program_id = contract$program_id, stage = "TRAIN", evidence_status = status,
  registry_origin = registry_origin,
  as_of_timestamp = contract$as_of_timestamp, query_start = as.character(contract$query_start),
  query_end = as.character(contract$train_query_end), frozen_registry_count = nrow(registry),
  eligible_identity_count = nrow(eligible_registry), panel_row_count = nrow(panel),
  train_quarter_count = length(unique(panel$signal_quarter)), selected_lambda = cv$selected_lambda,
  permutation_percentile = unique(permutation$observed_percentile), all_gates_pass = nominated,
  refresh = refresh, stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "hyp_mom_04_1_train_run_spec.csv"))
write_csv(integrity, file.path(output_dir, "hyp_mom_04_1_train_integrity.csv"))
write_csv(query$health, file.path(output_dir, "hyp_mom_04_1_train_query_health.csv"))
write_csv(registry, file.path(output_dir, "hyp_mom_04_1_frozen_registry.csv"))
write_csv(coverage, file.path(output_dir, "hyp_mom_04_1_train_coverage.csv"))
write_csv(panel, file.path(output_dir, "hyp_mom_04_1_train_panel.csv"))
write_csv(cv$details, file.path(output_dir, "hyp_mom_04_1_train_cv_details.csv"))
write_csv(cv$summary, file.path(output_dir, "hyp_mom_04_1_train_cv_summary.csv"))
write_csv(scored, file.path(output_dir, "hyp_mom_04_1_train_scored_panel.csv"))
write_csv(quarter_summary, file.path(output_dir, "hyp_mom_04_1_train_quarter_summary.csv"))
write_csv(theory_quarter_summary, file.path(output_dir, "hyp_mom_04_1_train_theory_quarter_summary.csv"))
write_csv(univariate, file.path(output_dir, "hyp_mom_04_1_train_univariate_quarter_sorts.csv"))
write_csv(univariate_summary, file.path(output_dir, "hyp_mom_04_1_train_univariate_summary.csv"))
write_csv(fama_macbeth, file.path(output_dir, "hyp_mom_04_1_train_fama_macbeth.csv"))
write_csv(coefficient_summary, file.path(output_dir, "hyp_mom_04_1_train_coefficient_summary.csv"))
write_csv(permutation, file.path(output_dir, "hyp_mom_04_1_train_permutation.csv"))
write_csv(bootstrap, file.path(output_dir, "hyp_mom_04_1_train_block_bootstrap.csv"))
write_csv(sector_contribution, file.path(output_dir, "hyp_mom_04_1_train_sector_contribution.csv"))
write_csv(gates, file.path(output_dir, "hyp_mom_04_1_train_gates.csv"))

nomination <- list(
  nominated = nominated, status = status, contract = contract,
  frozen_registry = registry, train_eligible_registry = eligible_registry,
  model = final_fit$model, scaler = final_fit$scaler,
  selected_lambda = cv$selected_lambda, train_run_id = run_id,
  train_gates = gates, created_without_oos_access = TRUE
)
saveRDS(nomination, file.path(output_dir, "hyp_mom_04_1_train_nomination.rds"))

report <- c(
  "# HYP-MOM-04.1 TRAIN readout", "",
  paste0("Status: `", status, "`."), "",
  paste0("Eligible identities: ", nrow(eligible_registry), " / ", nrow(registry), "; TRAIN rows: ", nrow(panel),
         "; selected ridge lambda: ", cv$selected_lambda, "."), "",
  paste0("Expanding-CV mean rank IC: ", formatC(mean(cv$selected_details$rank_ic), digits = 4, format = "f"),
         "; positive-quarter fraction: ", formatC(mean(cv$selected_details$rank_ic > 0), digits = 3, format = "f"), "."), "",
  paste0("Final TRAIN Q4 mean relative return: ", formatC(100 * mean(quarter_summary$q4_excess), digits = 2, format = "f"),
         " pp; permutation percentile: ", formatC(100 * unique(permutation$observed_percentile), digits = 1, format = "f"), "%."), "",
  "OOS is available only when every frozen TRAIN gate passes. No 2021+ observation was queried by this runner."
)
writeLines(report, file.path(output_dir, "hyp_mom_04_1_train_report.md"))

print(run_spec)
print(gates)
message("HYP-MOM-04.1 TRAIN complete: ", output_dir)
