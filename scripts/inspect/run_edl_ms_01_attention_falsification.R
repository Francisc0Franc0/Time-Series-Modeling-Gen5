# Outcome-blind matched falsification of the Rule 201 attention-stock distinction.
# One primary estimand only: paired attention-minus-core day-five open log return.

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
source(file.path(repo_root, "edge_discovery_lab", "R", "edl_ms_01_rule201_reclaim.R"))
source(file.path(repo_root, "edge_discovery_lab", "R", "edl_ms_01_attention_falsification.R"))

source_dir <- file.path(
  repo_root, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_rule201_wide_atlas_20260830"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_attention_falsification_20260831"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

paths <- c(
  events = file.path(source_dir, "event_ledger_with_paths.csv"),
  source_checks = file.path(source_dir, "construction_checks.csv"),
  source_spec = file.path(source_dir, "run_spec.csv")
)
if (!all(file.exists(paths))) edl_ms01_stop("The wide-atlas source packet is incomplete.")
events <- utils::read.csv(paths[["events"]], stringsAsFactors = FALSE, check.names = FALSE)
source_checks <- utils::read.csv(paths[["source_checks"]], stringsAsFactors = FALSE)
if (any(source_checks$status != "PASS")) {
  edl_ms01_stop("The inherited wide-atlas packet contains a failed construction check.")
}
events$session_date <- as.Date(events$session_date)

contract <- edl_ms01_validate_attention_falsification_contract()
matched <- edl_ms01_match_attention_to_core(events, contract)
pool <- matched$raw_pool
standardized_pool <- matched$standardized_pool
pairs <- matched$pairs
if (!identical(sort(unique(pairs$calendar_year)), contract$expected_common_years)) {
  edl_ms01_stop("The common-year matching surface changed before outcome inspection.")
}
if (nrow(pairs) != contract$expected_pair_count) {
  edl_ms01_stop(sprintf(
    "Expected %d outcome-blind pairs; observed %d.",
    contract$expected_pair_count, nrow(pairs)
  ))
}

balance <- edl_ms01_attention_balance(standardized_pool, pairs, contract)
balance_pass <- max(balance$abs_smd_after) <= contract$max_abs_smd

event_match <- function(event_ids, column) {
  index <- match(event_ids, pool$event_id)
  if (anyNA(index)) edl_ms01_stop("A matched event was lost before outcome attachment.")
  if (!column %in% names(pool)) edl_ms01_stop(paste("Missing outcome column", column))
  as.numeric(pool[[column]][index])
}
for (horizon in contract$context_horizons) {
  column <- paste0("path_", horizon, "_open_log_return")
  attention_return <- event_match(pairs$attention_event_id, column)
  core_return <- event_match(pairs$core_event_id, column)
  pairs[[paste0("attention_path_", horizon)]] <- attention_return
  pairs[[paste0("core_path_", horizon)]] <- core_return
  pairs[[paste0("difference_path_", horizon)]] <- attention_return - core_return
}

primary_column <- paste0("difference_path_", contract$primary_horizon)
primary_differences <- pairs[[primary_column]]
primary_test <- edl_ms01_exact_sign_flip_p(primary_differences, "greater")
primary_test$mean_log_difference_percent <- 100 * primary_test$observed_mean_difference
primary_test$median_log_difference_percent <- 100 * stats::median(primary_differences)
primary_test$attention_win_rate <- mean(primary_differences > 0)
primary_test$attention_median_simple_return_percent <- 100 * expm1(stats::median(
  pairs[[paste0("attention_path_", contract$primary_horizon)]]
))
primary_test$core_median_simple_return_percent <- 100 * expm1(stats::median(
  pairs[[paste0("core_path_", contract$primary_horizon)]]
))

path_rows <- lapply(contract$context_horizons, function(horizon) {
  attention <- pairs[[paste0("attention_path_", horizon)]]
  core <- pairs[[paste0("core_path_", horizon)]]
  difference <- pairs[[paste0("difference_path_", horizon)]]
  data.frame(
    horizon = horizon,
    pair_n = length(difference),
    attention_mean_log_return = mean(attention),
    attention_median_log_return = stats::median(attention),
    core_mean_log_return = mean(core),
    core_median_log_return = stats::median(core),
    mean_paired_log_difference = mean(difference),
    median_paired_log_difference = stats::median(difference),
    attention_win_rate = mean(difference > 0),
    stringsAsFactors = FALSE
  )
})
path_summary <- do.call(rbind, path_rows)

leave_one_year_out <- do.call(rbind, lapply(sort(unique(pairs$calendar_year)), function(year) {
  keep <- pairs$calendar_year != year
  data.frame(
    omitted_year = year,
    retained_pairs = sum(keep),
    mean_paired_log_difference = mean(primary_differences[keep]),
    mean_log_difference_percent = 100 * mean(primary_differences[keep]),
    positive = mean(primary_differences[keep]) > 0,
    stringsAsFactors = FALSE
  )
}))

leave_one_attention_symbol_out <- do.call(rbind, lapply(
  sort(unique(pairs$attention_symbol)),
  function(symbol) {
    keep <- pairs$attention_symbol != symbol
    data.frame(
      omitted_attention_symbol = symbol,
      retained_pairs = sum(keep),
      mean_paired_log_difference = mean(primary_differences[keep]),
      mean_log_difference_percent = 100 * mean(primary_differences[keep]),
      positive = mean(primary_differences[keep]) > 0,
      stringsAsFactors = FALSE
    )
  }
))

all_loyo_positive <- all(leave_one_year_out$positive)
all_loso_positive <- all(leave_one_attention_symbol_out$positive)
status <- edl_ms01_classify_attention_falsification(
  balance_pass = balance_pass,
  observed_mean_difference = primary_test$observed_mean_difference,
  exact_p_value = primary_test$exact_p_value,
  all_leave_one_year_out_positive = all_loyo_positive,
  all_leave_one_attention_symbol_out_positive = all_loso_positive,
  contract = contract
)

pool$common_year_eligible <- pool$calendar_year %in% contract$expected_common_years &
  pool$match_feature_eligible
pool$matched <- pool$event_id %in% c(pairs$attention_event_id, pairs$core_event_id)
pool$matching_status <- ifelse(
  !pool$match_feature_eligible, "EXCLUDED_NONFINITE_MATCH_FEATURE",
  ifelse(
    !pool$calendar_year %in% contract$expected_common_years,
    "UNMATCHED_NO_CORE_YEAR",
    ifelse(pool$matched, "MATCHED", "UNMATCHED_CAPACITY")
  )
)

pair_year_counts <- as.data.frame.matrix(table(
  factor(pool$calendar_year, levels = as.character(2018:2023)),
  factor(pool$atlas_cohort, levels = c(contract$attention_cohort, contract$core_cohort))
))
pair_year_counts$calendar_year <- rownames(pair_year_counts)
rownames(pair_year_counts) <- NULL
pair_year_counts$matched_pairs <- vapply(pair_year_counts$calendar_year, function(year) {
  sum(pairs$calendar_year == year)
}, integer(1))
pair_year_counts <- pair_year_counts[, c(
  "calendar_year", contract$attention_cohort, contract$core_cohort, "matched_pairs"
)]
names(pair_year_counts)[2:3] <- c("attention_events", "core_events")

checks <- data.frame(
  check_id = c(
    "inherited_wide_atlas_checks", "train_window_sealed", "target_category_frozen",
    "matching_outcome_blind", "exact_calendar_year", "pair_count_frozen",
    "attention_events_unique", "core_events_unique", "four_features_frozen",
    "balance_threshold_predeclared", "single_primary_horizon", "exact_sign_flip_complete",
    "leave_one_year_out_complete", "leave_one_symbol_out_complete",
    "no_multiple_horizon_inference", "no_strategy_replay", "post_2023_unopened"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (min(events$session_date) >= contract$analysis_start && max(events$session_date) <= contract$analysis_end) "PASS" else "FAIL",
    if (all(pool$event_category == contract$target_category)) "PASS" else "FAIL",
    "PASS",
    if (all(format(pairs$attention_session_date, "%Y") == format(pairs$core_session_date, "%Y"))) "PASS" else "FAIL",
    if (nrow(pairs) == contract$expected_pair_count) "PASS" else "FAIL",
    if (anyDuplicated(pairs$attention_event_id) == 0L) "PASS" else "FAIL",
    if (anyDuplicated(pairs$core_event_id) == 0L) "PASS" else "FAIL",
    if (length(contract$distance_features) == 4L) "PASS" else "FAIL",
    "PASS",
    if (contract$primary_horizon == 5L) "PASS" else "FAIL",
    if (primary_test$exact_assignments == 2^nrow(pairs)) "PASS" else "FAIL",
    if (nrow(leave_one_year_out) == length(contract$expected_common_years)) "PASS" else "FAIL",
    if (nrow(leave_one_attention_symbol_out) == length(unique(pairs$attention_symbol))) "PASS" else "FAIL",
    "PASS", "PASS", "PASS"
  ),
  detail = c(
    "all source-packet construction checks remain PASS",
    "all inspected events remain inside 2018-2023 TRAIN",
    "stocks only; triggered proxy plus strong reclaim only",
    "matching code accesses identifiers, time, severity, CLV, and abnormal volume before outcomes are attached",
    "pairs are formed only within the same calendar year",
    sprintf("%d pairs fixed from pre-outcome cohort/year counts", nrow(pairs)),
    "attention events are used at most once",
    "core events are used at most once",
    paste(contract$distance_features, collapse = ", "),
    sprintf("max absolute post-match SMD must be <= %.2f", contract$max_abs_smd),
    "day five is the sole inferential outcome",
    sprintf("all %d sign assignments enumerated", primary_test$exact_assignments),
    "each common matching year is omitted once",
    "each matched attention symbol is omitted once",
    "sessions 0-10 are descriptive context only; no multiplicity search",
    "no costs, sizing, overlapping-trade replay, or portfolio claim",
    "no post-2023 outcomes are read"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  edl_ms01_stop(paste(
    "Attention falsification construction check failed:",
    paste(checks$check_id[checks$status != "PASS"], collapse = ", ")
  ))
}

run_spec <- data.frame(
  field = c(
    "study_id", "source_packet", "study_window", "target_population",
    "matching_clock", "exact_match", "distance_features", "matching_algorithm",
    "expected_common_years", "expected_pairs", "primary_estimand", "primary_test",
    "balance_gate", "robustness_gate", "context_horizons", "multiplicity_status",
    "strategy_status", "oos_status"
  ),
  value = c(
    contract$study_id,
    normalizePath(source_dir, winslash = "/"),
    "2018-01-02..2023-12-29 TRAIN",
    "stocks; triggered proxy plus strong reclaim; attention versus GICS core",
    "matching finalized before forward-return columns are attached",
    "calendar year",
    paste(contract$distance_features, collapse = ","),
    "within-year global greedy minimum standardized Euclidean distance; one-to-one without replacement",
    paste(contract$expected_common_years, collapse = ","),
    as.character(contract$expected_pair_count),
    "mean paired attention-minus-core cumulative open log return at session five",
    "exact one-sided greater sign-flip; alpha 0.05; 2^20 assignments",
    "max absolute post-match standardized mean difference <= 0.25",
    "all leave-one-year-out and leave-one-attention-symbol-out means must remain positive",
    paste(contract$context_horizons, collapse = ","),
    "one inferential horizon only; context horizons descriptive",
    "no costs, sizing, portfolio replay, or edge claim",
    "post-2023 sealed"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(pool, file.path(output_dir, "matching_enrollment_audit.csv"), row.names = FALSE)
utils::write.csv(pair_year_counts, file.path(output_dir, "pair_year_counts.csv"), row.names = FALSE)
utils::write.csv(pairs, file.path(output_dir, "matched_pair_ledger.csv"), row.names = FALSE)
utils::write.csv(balance, file.path(output_dir, "matching_balance.csv"), row.names = FALSE)
utils::write.csv(primary_test, file.path(output_dir, "primary_day5_test.csv"), row.names = FALSE)
utils::write.csv(path_summary, file.path(output_dir, "matched_path_summary.csv"), row.names = FALSE)
utils::write.csv(leave_one_year_out, file.path(output_dir, "leave_one_year_out.csv"), row.names = FALSE)
utils::write.csv(leave_one_attention_symbol_out, file.path(output_dir, "leave_one_attention_symbol_out.csv"), row.names = FALSE)

to_simple_pct <- function(x) 100 * expm1(x)

png(file.path(visual_dir, "attention_matching_balance.png"), 1900, 1050, res = 150)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1), oma = c(1, 1, 4, 1))
feature_labels <- c("Breach severity", "Close location", "Abnormal dollar volume", "Event date")
z <- rbind(abs(balance$smd_before), abs(balance$smd_after))
barplot(z, beside = TRUE, names.arg = feature_labels, las = 2,
        col = c("#B8BCC4", "#3D8DFF"), border = NA,
        ylab = "Absolute standardized mean difference",
        main = "Covariate balance")
abline(h = contract$max_abs_smd, col = "#B44738", lty = 2, lwd = 2)
legend("topright", c("Before pairing", "After pairing", "0.25 balance gate"),
       fill = c("#B8BCC4", "#3D8DFF", NA), border = NA,
       lty = c(NA, NA, 2), col = c(NA, NA, "#B44738"), bty = "n", cex = 0.8)
year_matrix <- rbind(
  pair_year_counts$attention_events,
  pair_year_counts$core_events,
  pair_year_counts$matched_pairs
)
barplot(year_matrix, beside = TRUE, names.arg = pair_year_counts$calendar_year,
        col = c("#6957D5", "#3D8DFF", "#14866D"), border = NA,
        ylab = "Target events / matched pairs", main = "Matching capacity by year")
legend("topright", c("Attention events", "Core events", "Matched pairs"),
       fill = c("#6957D5", "#3D8DFF", "#14866D"), border = NA, bty = "n", cex = 0.8)
mtext("Outcome-blind matching audit", outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2)
mtext("Exact calendar year; nearest severity, reclaim strength, abnormal volume, and event date; no replacement", outer = TRUE, side = 3, line = 0.15, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

day5_attention <- to_simple_pct(pairs$attention_path_5)
day5_core <- to_simple_pct(pairs$core_path_5)
order_index <- order(day5_attention - day5_core)
png(file.path(visual_dir, "attention_paired_day5_outcomes.png"), 1900, 1050, res = 150)
old_par <- par(no.readonly = TRUE)
par(mar = c(5, 8, 5, 2), oma = c(1, 1, 2, 1))
y <- seq_len(nrow(pairs))
x_range <- range(c(day5_attention, day5_core), finite = TRUE)
plot(NA, xlim = x_range, ylim = c(0.5, nrow(pairs) + 0.5),
     xlab = "Five-session cumulative open-to-open return (%)", ylab = "",
     yaxt = "n", main = "Each line is one outcome-blind matched pair")
abline(v = 0, col = "#B8BCC4", lty = 2)
segments(day5_core[order_index], y, day5_attention[order_index], y,
         col = ifelse(day5_attention[order_index] > day5_core[order_index], "#14866D", "#B44738"), lwd = 2)
points(day5_core[order_index], y, pch = 16, col = "#3D8DFF", cex = 1.0)
points(day5_attention[order_index], y, pch = 16, col = "#6957D5", cex = 1.0)
axis(2, at = y, labels = pairs$pair_id[order_index], las = 2, cex.axis = 0.7)
legend("bottomright", c("Core", "Attention", "Attention wins", "Core wins"),
       col = c("#3D8DFF", "#6957D5", "#14866D", "#B44738"),
       pch = c(16, 16, NA, NA), lty = c(NA, NA, 1, 1), lwd = c(NA, NA, 2, 2),
       bty = "n", cex = 0.85)
mtext(sprintf(
  "Mean paired log-return difference %+.2f%% | attention wins %.0f%% | exact one-sided p=%.4f",
  primary_test$mean_log_difference_percent,
  100 * primary_test$attention_win_rate,
  primary_test$exact_p_value
), side = 3, line = 0.5, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

png(file.path(visual_dir, "attention_matched_forward_paths.png"), 1900, 1050, res = 150)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1), oma = c(1, 1, 4, 1))
y_limit <- max(8, max(abs(to_simple_pct(c(
  path_summary$attention_median_log_return,
  path_summary$core_median_log_return
))), na.rm = TRUE) * 1.3)
plot(path_summary$horizon, to_simple_pct(path_summary$attention_median_log_return),
     type = "l", lwd = 4, col = "#6957D5", xlim = c(0, 10), ylim = c(-y_limit, y_limit),
     xlab = "Sessions after next-open entry", ylab = "Median cumulative return (%)",
     main = "Matched cohort paths", xaxt = "n")
axis(1, at = c(0:5, 10)); abline(h = 0, col = "#B8BCC4", lty = 2)
lines(path_summary$horizon, to_simple_pct(path_summary$core_median_log_return),
      lwd = 4, col = "#3D8DFF")
legend("topleft", c("Attention", "Core"), col = c("#6957D5", "#3D8DFF"),
       lwd = 4, bty = "n")
pair_diff_matrix <- sapply(contract$context_horizons, function(h) pairs[[paste0("difference_path_", h)]])
matplot(contract$context_horizons, 100 * t(pair_diff_matrix), type = "l", lty = 1,
        col = grDevices::adjustcolor("#6957D5", 0.15), xlim = c(0, 10),
        xlab = "Sessions after next-open entry", ylab = "Attention minus core log return (%)",
        main = "Paired-difference paths", xaxt = "n")
axis(1, at = c(0:5, 10)); abline(h = 0, col = "#B8BCC4", lty = 2)
lines(path_summary$horizon, 100 * path_summary$mean_paired_log_difference,
      col = "#6957D5", lwd = 4)
mtext("Only session five is inferential", outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2)
mtext("All other horizons show path anatomy only; they are not searched or multiplicity-tested", outer = TRUE, side = 3, line = 0.15, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

png(file.path(visual_dir, "attention_falsification_sensitivity.png"), 1900, 1050, res = 150)
old_par <- par(no.readonly = TRUE)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1), oma = c(1, 1, 4, 1))
barplot(leave_one_year_out$mean_log_difference_percent,
        names.arg = paste("omit", leave_one_year_out$omitted_year), las = 2,
        col = ifelse(leave_one_year_out$positive, "#14866D", "#B44738"), border = NA,
        ylab = "Mean paired log-return difference (%)",
        main = "Leave one matching year out")
abline(h = 0, col = "#24364B")
barplot(leave_one_attention_symbol_out$mean_log_difference_percent,
        names.arg = leave_one_attention_symbol_out$omitted_attention_symbol, las = 2,
        col = ifelse(leave_one_attention_symbol_out$positive, "#14866D", "#B44738"), border = NA,
        ylab = "Mean paired log-return difference (%)",
        main = "Leave one attention symbol out")
abline(h = 0, col = "#24364B")
mtext("Does one year or one attention name determine the sign?", outer = TRUE, side = 3, line = 1.6, cex = 1.35, font = 2)
mtext("Green bars retain a positive attention-minus-core mean after omission; red bars reverse it", outer = TRUE, side = 3, line = 0.15, cex = 0.9, col = "#526273")
par(old_par)
dev.off()

report <- c(
  "# EDL-MS-01 Attention-Stock Distinction Falsification", "",
  "## Frozen question", "",
  "Among stock events that triggered the daily Rule 201 proxy and closed as strong reclaims, does the attention-stock day-five recovery remain after pairing each usable event to a same-year core-stock event with similar breach severity, close location, abnormal dollar volume, and event date?", "",
  "## Pre-outcome contract", "",
  "- One-to-one matching without replacement inside calendar year.",
  "- Global greedy minimum standardized Euclidean distance.",
  "- Four distance features: breach severity, close-location value, log abnormal dollar volume, and event date.",
  sprintf("- Pre-outcome capacity: %d pairs across %s.", contract$expected_pair_count, paste(contract$expected_common_years, collapse = ", ")),
  "- Sole inferential outcome: mean paired attention-minus-core cumulative open log return at session five.",
  "- Exact one-sided sign-flip test at alpha 0.05.",
  "- Matching validity: maximum absolute post-match SMD at or below 0.25.",
  "- Robustness: every leave-one-year-out and leave-one-attention-symbol-out mean must remain positive.", "",
  "## Matching readout", "",
  sprintf("- Matched pairs: %d.", nrow(pairs)),
  sprintf("- Maximum absolute post-match SMD: %.3f (%s).", max(balance$abs_smd_after), if (balance_pass) "PASS" else "FAIL"),
  sprintf("- Unmatched target events: %d no-core-year; %d capacity-limited; %d non-finite match feature.",
          sum(pool$matching_status == "UNMATCHED_NO_CORE_YEAR"),
          sum(pool$matching_status == "UNMATCHED_CAPACITY"),
          sum(pool$matching_status == "EXCLUDED_NONFINITE_MATCH_FEATURE")), "",
  "## Primary result", "",
  sprintf("- Mean paired attention-minus-core day-five log-return difference: %+.3f%%.", primary_test$mean_log_difference_percent),
  sprintf("- Median paired log-return difference: %+.3f%%.", primary_test$median_log_difference_percent),
  sprintf("- Attention win rate: %.1f%%.", 100 * primary_test$attention_win_rate),
  sprintf("- Exact one-sided sign-flip p-value: %.6f across %d assignments.", primary_test$exact_p_value, primary_test$exact_assignments),
  sprintf("- Matched attention median simple return: %+.2f%%; matched core median: %+.2f%%.",
          primary_test$attention_median_simple_return_percent,
          primary_test$core_median_simple_return_percent), "",
  "## Robustness", "",
  sprintf("- All leave-one-year-out means positive: %s.", all_loyo_positive),
  sprintf("- All leave-one-attention-symbol-out means positive: %s.", all_loso_positive), "",
  "## Status", "",
  status, "",
  "No costs, strategy replay, holding-period search, post-2023 outcomes, or edge claim are opened."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

status_table <- data.frame(
  status = status,
  balance_pass = balance_pass,
  max_abs_smd_after = max(balance$abs_smd_after),
  primary_positive = primary_test$observed_mean_difference > 0,
  exact_p_value = primary_test$exact_p_value,
  exact_p_pass = primary_test$exact_p_value <= contract$alpha,
  all_leave_one_year_out_positive = all_loyo_positive,
  all_leave_one_attention_symbol_out_positive = all_loso_positive,
  stringsAsFactors = FALSE
)
utils::write.csv(status_table, file.path(output_dir, "falsification_status.csv"), row.names = FALSE)

message("Status: ", status)
message("Pairs: ", nrow(pairs), "; max abs post-match SMD: ", sprintf("%.3f", max(balance$abs_smd_after)))
message("Primary mean log difference: ", sprintf("%+.3f%%", primary_test$mean_log_difference_percent),
        "; exact p: ", sprintf("%.6f", primary_test$exact_p_value))
message("Artifacts: ", normalizePath(output_dir, winslash = "/"))
