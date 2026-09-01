# Translate the descriptive NVDA opening-response candidate into one frozen,
# executable 10:00-to-close TRAIN rule. The 2024+ intraday period remains unread.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "hyp_nvda_intraday_opening_rule.R"
))

contract <- nio_validate_contract()
source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_intraday_opening_response_20260831"
)
run_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_intraday_opening_rule_20260831"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

sessions_path <- file.path(source_dir, "session_ledger.csv")
source_checks_path <- file.path(source_dir, "source_checks.csv")
paths_path <- file.path(source_dir, "intraday_paths.csv")
required_paths <- c(sessions_path, source_checks_path, paths_path)
if (any(!file.exists(required_paths))) {
  stop(
    "Missing frozen opening-response artifacts: ",
    paste(required_paths[!file.exists(required_paths)], collapse = ", "),
    call. = FALSE
  )
}

sessions <- utils::read.csv(sessions_path, stringsAsFactors = FALSE)
sessions$session_date <- as.Date(sessions$session_date)
sessions$state_session <- as.Date(sessions$state_session)
source_checks_prior <- utils::read.csv(source_checks_path, stringsAsFactors = FALSE)
paths <- utils::read.csv(paths_path, stringsAsFactors = FALSE)
paths$session_date <- as.Date(paths$session_date)
paths$state_session <- as.Date(paths$state_session)

study <- nio_build_study(sessions, contract)
primary <- study$rule_summary[
  study$rule_summary$rule_id == contract$primary_rule, , drop = FALSE
]
controls <- study$rule_summary[
  study$rule_summary$rule_id != contract$primary_rule, , drop = FALSE
]
candidate_trades <- study$trades[
  study$trades$rule_id == contract$primary_rule, , drop = FALSE
]
candidate_paths <- paths[
  paths$session_date %in% candidate_trades$session_date, , drop = FALSE
]

recomputed_thresholds <- vapply(seq_len(nrow(study$candidates)), function(j) {
  i <- study$candidates$session_index[[j]]
  unname(stats::quantile(
    sessions$opening_log_return[(i - contract$rolling_sessions):(i - 1L)],
    contract$opening_quantile_probability,
    type = 8,
    names = FALSE
  ))
}, numeric(1))
session_match <- match(study$candidates$session_date, sessions$session_date)
candidate_path_ends <- candidate_paths[
  candidate_paths$path_step == 12L,
  c("session_date", "cumulative_remainder_log_return"),
  drop = FALSE
]
candidate_path_match <- match(candidate_trades$session_date, candidate_path_ends$session_date)

construction_checks <- data.frame(
  check_id = c(
    "prior_packet_checks_pass", "exact_symbol", "train_window_only",
    "confirmation_intraday_unread", "complete_session_source",
    "rolling_history_fixed", "threshold_strictly_prior",
    "rolling_threshold_reproduces", "prior_day_atr_state",
    "entry_price_is_ten_am", "exit_price_is_session_close",
    "round_trip_cost_fixed", "primary_and_controls_present",
    "candidate_path_end_matches_trade"
  ),
  passed = c(
    all(source_checks_prior$passed %in% c(TRUE, "TRUE")),
    identical(unique(as.character(study$candidates$symbol)), contract$symbol),
    min(study$candidates$session_date) >= contract$analysis_start &&
      max(study$candidates$session_date) <= contract$analysis_end,
    max(study$candidates$session_date) < as.Date("2024-01-02"),
    nrow(sessions) == 1487L,
    all(study$candidates$threshold_observations == contract$rolling_sessions),
    all(study$candidates$threshold_window_end < study$candidates$session_date),
    max(abs(recomputed_thresholds - study$candidates$rolling_opening_q80)) < 1e-12,
    all(study$candidates$state_session < study$candidates$session_date),
    all(study$candidates$entry_price_1000 == sessions$ten_am_price[session_match]),
    all(study$candidates$exit_price_1600 == sessions$session_close[session_match]),
    identical(contract$round_trip_cost_bps, 10),
    setequal(study$rule_summary$rule_id, contract$rule_ids),
    max(abs(
      candidate_path_ends$cumulative_remainder_log_return[candidate_path_match] -
        candidate_trades$gross_trade_log_return
    )) < 1e-12
  ),
  observed = c(
    paste(sum(source_checks_prior$passed %in% c(TRUE, "TRUE")), nrow(source_checks_prior), sep = "/"),
    paste(unique(study$candidates$symbol), collapse = ","),
    paste(range(study$candidates$session_date), collapse = " to "),
    as.character(max(study$candidates$session_date)),
    paste(nrow(sessions), "full sessions"),
    as.character(unique(study$candidates$threshold_observations)),
    paste(range(as.numeric(
      study$candidates$session_date - study$candidates$threshold_window_end
    )), collapse = " to "),
    sprintf("max abs diff %.3g", max(abs(
      recomputed_thresholds - study$candidates$rolling_opening_q80
    ))),
    paste(range(as.numeric(
      study$candidates$session_date - study$candidates$state_session
    )), collapse = " to "),
    "first bar close at 10:00",
    "last regular-session bar close at 16:00",
    paste0(contract$round_trip_cost_bps, " bps"),
    paste(study$rule_summary$rule_id, collapse = ","),
    sprintf("max abs diff %.3g", max(abs(
      candidate_path_ends$cumulative_remainder_log_return[candidate_path_match] -
        candidate_trades$gross_trade_log_return
    )))
  ),
  stringsAsFactors = FALSE
)
if (!all(construction_checks$passed)) {
  stop(
    "NVDA intraday opening-rule construction checks failed: ",
    paste(construction_checks$check_id[!construction_checks$passed], collapse = ", "),
    call. = FALSE
  )
}

pretty_rule <- function(x) {
  labels <- c(
    OPENING_TAIL_LOW_MED_ATR = "Opening tail + LOW/MED ATR",
    OPENING_TAIL_ONLY = "Opening tail only",
    LOW_MED_ATR_ONLY = "LOW/MED ATR only",
    OPENING_TAIL_HIGH_ATR = "Opening tail + HIGH ATR",
    UNCONDITIONAL_1000_CLOSE = "Unconditional 10:00-close"
  )
  unname(labels[x])
}

rule_colors <- c(
  OPENING_TAIL_LOW_MED_ATR = "#14866D",
  OPENING_TAIL_ONLY = "#3D7EBB",
  LOW_MED_ATR_ONLY = "#8591A2",
  OPENING_TAIL_HIGH_ATR = "#B44738",
  UNCONDITIONAL_1000_CLOSE = "#B6BDC7"
)

# 1. The causal rolling threshold and resulting state split.
threshold_path <- file.path(visual_dir, "nvda_opening_rule_rolling_threshold.png")
grDevices::png(threshold_path, width = 2200, height = 1300, res = 180)
graphics::par(mar = c(6.2, 7.0, 6.5, 2.2), family = "sans", bg = "white")
graphics::plot(
  study$candidates$session_date,
  100 * study$candidates$opening_log_return,
  type = "p", pch = 16, cex = 0.45,
  col = grDevices::adjustcolor("#778394", alpha.f = 0.35),
  xlab = "", ylab = "Completed 09:30-10:00 log return (%)",
  main = "The opening threshold is learned only from the prior 252 full sessions",
  cex.main = 1.45, col.main = "#142033", col.lab = "#273548", bty = "n"
)
graphics::abline(h = 0, col = "#B8C0CA")
graphics::lines(
  study$candidates$session_date,
  100 * study$candidates$rolling_opening_q80,
  col = "#142033", lwd = 2.4
)
candidate_rows <- study$candidates$candidate_signal
high_rows <- study$candidates$opening_tail_high_atr_signal
graphics::points(
  study$candidates$session_date[candidate_rows],
  100 * study$candidates$opening_log_return[candidate_rows],
  pch = 16, cex = 0.85, col = "#14866D"
)
graphics::points(
  study$candidates$session_date[high_rows],
  100 * study$candidates$opening_log_return[high_rows],
  pch = 17, cex = 0.85, col = "#B44738"
)
graphics::legend(
  "topleft", bty = "n", lwd = c(2.4, NA, NA), pch = c(NA, 16, 17),
  col = c("#142033", "#14866D", "#B44738"),
  legend = c("Rolling prior-252 80th percentile", "Tail + LOW/MED ATR", "Tail + HIGH ATR"),
  cex = 0.87
)
graphics::mtext(
  "The first 252 full sessions are warm-up only; each dot can be classified at 10:00 without future data.",
  side = 3, line = 1.0, cex = 0.88, col = "#667386"
)
grDevices::dev.off()

# 2. Candidate versus every predeclared simpler control.
distribution_path <- file.path(visual_dir, "nvda_opening_rule_control_distributions.png")
values <- lapply(contract$rule_ids, function(rule_id) {
  100 * study$trades$net_trade_log_return[study$trades$rule_id == rule_id]
})
grDevices::png(distribution_path, width = 2300, height = 1400, res = 180)
graphics::par(mar = c(12.5, 7.0, 7.0, 2.2), family = "sans", bg = "white")
graphics::boxplot(
  values, names = pretty_rule(contract$rule_ids), las = 2, outline = FALSE,
  col = grDevices::adjustcolor(unname(rule_colors[contract$rule_ids]), alpha.f = 0.25),
  border = unname(rule_colors[contract$rule_ids]),
  ylab = "Net 10:00-16:00 log return (%)",
  main = "The joint rule must outperform each ingredient and the opposite state",
  cex.main = 1.42, col.main = "#142033", col.lab = "#273548"
)
graphics::abline(h = 0, col = "#667386")
for (i in seq_along(contract$rule_ids)) {
  row <- study$rule_summary[study$rule_summary$rule_id == contract$rule_ids[[i]], ]
  graphics::points(i, 100 * row$mean_net_trade_log_return, pch = 23, bg = "white", cex = 1.35)
}
graphics::legend(
  "topright", bty = "n", pch = 23, pt.bg = "white",
  legend = sprintf(
    "Mean: candidate %+.2f%% | opening-only %+.2f%% | HIGH-ATR opposite %+.2f%%",
    100 * primary$mean_net_trade_log_return,
    100 * study$rule_summary$mean_net_trade_log_return[
      study$rule_summary$rule_id == "OPENING_TAIL_ONLY"
    ],
    100 * study$rule_summary$mean_net_trade_log_return[
      study$rule_summary$rule_id == "OPENING_TAIL_HIGH_ATR"
    ]
  ),
  cex = 0.82, text.col = "#344054"
)
graphics::mtext(
  "Black diamonds are means; boxes show the interquartile range; 10 bps round trip is deducted from every observation.",
  side = 1, line = 10.8, cex = 0.80, col = "#667386"
)
grDevices::dev.off()

# 3. Calendar breadth of the primary rule.
annual <- study$calendar_summary[
  study$calendar_summary$rule_id == contract$primary_rule, , drop = FALSE
]
annual_path <- file.path(visual_dir, "nvda_opening_rule_annual_context.png")
grDevices::png(annual_path, width = 1900, height = 1150, res = 180)
graphics::par(mar = c(6.0, 6.8, 6.5, 2.0), family = "sans", bg = "white")
annual_colors <- ifelse(annual$mean_net_trade_log_return > 0, "#14866D", "#B44738")
annual_values <- 100 * annual$mean_net_trade_log_return
annual_ylim <- c(min(annual_values) - 0.13, max(annual_values) + 0.16)
bars <- graphics::barplot(
  annual_values,
  names.arg = annual$entry_year,
  col = annual_colors, border = NA,
  ylim = annual_ylim,
  ylab = "Mean net 10:00-16:00 log return (%)",
  main = "A credible TRAIN clue should not depend on one calendar year",
  cex.main = 1.45, col.main = "#142033", col.lab = "#273548"
)
graphics::abline(h = 0, col = "#667386")
for (i in seq_len(nrow(annual))) {
  label_y <- annual_values[[i]] + if (annual_values[[i]] >= 0) 0.045 else -0.045
  graphics::text(
    bars[[i]], label_y,
    labels = sprintf("n=%d\nup %.0f%%", annual$trades[[i]], 100 * annual$probability_profitable_net[[i]]),
    adj = c(0.5, if (annual_values[[i]] >= 0) 0 else 1),
    cex = 0.78, col = "#344054"
  )
}
graphics::mtext(
  sprintf(
    "%d of %d displayed years have positive mean net return; the frozen gate requires at least %d.",
    sum(annual$mean_net_trade_log_return > 0), nrow(annual), contract$minimum_positive_years
  ),
  side = 3, line = 1.0, cex = 0.90, col = "#667386"
)
grDevices::dev.off()

# 4. Realized primary-rule equity, flat between same-day trades.
equity_path <- file.path(visual_dir, "nvda_opening_rule_realized_equity.png")
calendar <- data.frame(session_date = study$candidates$session_date)
calendar$trade_log_return <- 0
matched <- match(candidate_trades$session_date, calendar$session_date)
calendar$trade_log_return[matched] <- candidate_trades$net_trade_log_return
calendar$realized_equity <- exp(cumsum(calendar$trade_log_return))
grDevices::png(equity_path, width = 2000, height = 1150, res = 180)
graphics::par(mar = c(6.2, 6.8, 6.5, 2.0), family = "sans", bg = "white")
graphics::plot(
  calendar$session_date, calendar$realized_equity,
  type = "s", lwd = 2.6, col = "#14866D", bty = "n",
  xlab = "", ylab = "Realized equity per $1 (flat between trades)",
  main = "The candidate's realized path reveals when the aggregate result was earned",
  cex.main = 1.42, col.main = "#142033", col.lab = "#273548"
)
graphics::abline(h = 1, col = "#AEB7C2")
graphics::mtext(
  "Same-day 10:00 entries and 16:00 exits | no overnight exposure | 10 bps round trip | TRAIN only",
  side = 3, line = 1.0, cex = 0.88, col = "#667386"
)
grDevices::dev.off()

# 5. Representative intraday paths for the candidate.
tapes_path <- file.path(visual_dir, "nvda_opening_rule_representative_tapes.png")
ordered <- candidate_trades[order(candidate_trades$net_trade_log_return), , drop = FALSE]
picks <- c(
  1L,
  which.min(abs(ordered$net_trade_log_return - stats::median(ordered$net_trade_log_return))),
  nrow(ordered)
)
pick_labels <- c("Worst", "Median-nearest", "Best")
grDevices::png(tapes_path, width = 2200, height = 1000, res = 180)
graphics::par(mfrow = c(1, 3), mar = c(5.2, 5.2, 5.5, 1.2), family = "sans", bg = "white")
for (j in seq_along(picks)) {
  trade <- ordered[picks[[j]], , drop = FALSE]
  path <- candidate_paths[candidate_paths$session_date == trade$session_date, , drop = FALSE]
  path <- path[order(path$path_step), , drop = FALSE]
  graphics::plot(
    path$path_step,
    100 * path$cumulative_remainder_log_return,
    type = "l", lwd = 2.8, col = "#14866D", bty = "n",
    xaxt = "n", xlab = "Clock time", ylab = "Cumulative return from 10:00 (%)",
    main = paste(pick_labels[[j]], trade$session_date, sep = " | "),
    cex.main = 1.05, col.main = "#142033"
  )
  tick <- seq(1, nrow(path), by = 3)
  graphics::axis(1, at = path$path_step[tick], labels = path$clock_label[tick], cex.axis = 0.78)
  graphics::abline(h = 0, col = "#B8C0CA")
  graphics::points(tail(path$path_step, 1L), 100 * tail(path$cumulative_remainder_log_return, 1L),
                   pch = 16, col = "#B44738")
  graphics::mtext(
    sprintf(
      "opening %+.2f%% | q80 %+.2f%% | net %+.2f%%",
      100 * trade$opening_log_return,
      100 * trade$rolling_opening_q80,
      100 * trade$net_trade_log_return
    ),
    side = 3, line = 0.55, cex = 0.72, col = "#667386"
  )
}
grDevices::dev.off()

run_spec <- data.frame(
  field = c(
    "study_id", "sample_role", "symbol", "source_packet", "analysis_start",
    "analysis_end", "warmup", "opening_threshold", "threshold_timing",
    "state_timing", "candidate_rule", "entry", "exit", "round_trip_cost_bps",
    "controls", "train_gates", "confirmation_data", "research_status"
  ),
  value = c(
    contract$study_id, contract$sample_role, contract$symbol,
    "nvda_intraday_opening_response_20260831 full-session ledger and paths",
    as.character(contract$analysis_start), as.character(contract$analysis_end),
    "first 252 full sessions; no trades or control observations during warm-up",
    "current opening log return >= rolling prior-252 full-session 80th percentile",
    "threshold excludes the current session and every future session",
    "ATR% state from the immediately preceding completed daily session",
    "opening tail and prior-day ATR% LOW or MEDIUM",
    "first 30-minute close at 10:00 America/New_York",
    "last regular-session 30-minute close at 16:00 America/New_York",
    as.character(contract$round_trip_cost_bps),
    paste(setdiff(contract$rule_ids, contract$primary_rule), collapse = "; "),
    "at least 100 trades; positive mean; positive median and majority profitable; beats every control; at least three positive years",
    "no post-2023 intraday outcomes read",
    "TRAIN causal translation only; no edge or live authority"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(construction_checks, file.path(run_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(study$candidates, file.path(run_dir, "candidate_ledger.csv"), row.names = FALSE)
utils::write.csv(study$trades, file.path(run_dir, "trade_ledger.csv"), row.names = FALSE)
utils::write.csv(study$rule_summary, file.path(run_dir, "rule_summary.csv"), row.names = FALSE)
utils::write.csv(study$calendar_summary, file.path(run_dir, "calendar_summary.csv"), row.names = FALSE)
utils::write.csv(study$gate$checks, file.path(run_dir, "train_gates.csv"), row.names = FALSE)
utils::write.csv(candidate_paths, file.path(run_dir, "candidate_intraday_paths.csv"), row.names = FALSE)

control_lines <- vapply(seq_len(nrow(controls)), function(i) {
  sprintf(
    "- %s: `n=%d`; mean net `%+.3f%%`; median net `%+.3f%%`; profitable `%.1f%%`.",
    pretty_rule(controls$rule_id[[i]]), controls$trades[[i]],
    100 * controls$mean_net_trade_log_return[[i]],
    100 * controls$median_net_trade_log_return[[i]],
    100 * controls$probability_profitable_net[[i]]
  )
}, character(1))
gate_lines <- vapply(seq_len(nrow(study$gate$checks)), function(i) {
  row <- study$gate$checks[i, ]
  sprintf("- `%s`: **%s** — %s", row$gate_id, if (row$passed) "PASS" else "FAIL", row$observed)
}, character(1))

report <- c(
  "# NVDA Intraday Opening-Tail Rule — Causal TRAIN Translation",
  "",
  "The completed first 30-minute return is compared with a rolling threshold built",
  "only from the prior 252 complete sessions. The candidate may enter at 10:00 only",
  "when that opening return reaches the rolling 80th percentile and the prior-day",
  "ATR% state is LOW or MEDIUM. Every trade exits at 16:00 the same session.",
  "",
  "## Primary readout",
  "",
  sprintf("- Verdict: `%s`", study$gate$verdict),
  sprintf("- Candidate trades: `%d`", primary$trades),
  sprintf("- Mean net return: `%+.3f%%`", 100 * primary$mean_net_trade_log_return),
  sprintf("- Median net return: `%+.3f%%`", 100 * primary$median_net_trade_log_return),
  sprintf("- Profitable trades: `%.1f%%`", 100 * primary$probability_profitable_net),
  sprintf("- Ending equity per $1 across sequential same-day trades: `%.3f`", primary$ending_equity_per_dollar),
  "",
  "## Simpler controls",
  "",
  control_lines,
  "",
  "## Frozen TRAIN gates",
  "",
  gate_lines,
  "",
  "## Interpretation boundary",
  "",
  "A TRAIN pass means the descriptive clue survived causal timing, a rolling threshold,",
  "10 bps round trip, and the predeclared simpler controls within 2018-2023. It does not",
  "mean the rule is an edge. A STOP means no nearby threshold, ATR state, cost, or clock",
  "variation may be chosen from this packet. Post-2023 intraday data remain unread.",
  "",
  "## Artifacts",
  "",
  "- `run_spec.csv`",
  "- `construction_checks.csv`",
  "- `candidate_ledger.csv`",
  "- `trade_ledger.csv`",
  "- `rule_summary.csv`",
  "- `calendar_summary.csv`",
  "- `train_gates.csv`",
  "- `candidate_intraday_paths.csv`",
  "- `visuals/nvda_opening_rule_rolling_threshold.png`",
  "- `visuals/nvda_opening_rule_control_distributions.png`",
  "- `visuals/nvda_opening_rule_annual_context.png`",
  "- `visuals/nvda_opening_rule_realized_equity.png`",
  "- `visuals/nvda_opening_rule_representative_tapes.png`"
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("NVDA intraday opening-rule TRAIN translation complete")
message("Verdict: ", study$gate$verdict)
message(
  "Candidate: n=", primary$trades,
  " | mean net ", sprintf("%+.3f%%", 100 * primary$mean_net_trade_log_return),
  " | median net ", sprintf("%+.3f%%", 100 * primary$median_net_trade_log_return),
  " | profitable ", sprintf("%.1f%%", 100 * primary$probability_profitable_net)
)
message("Report: ", file.path(run_dir, "report.md"))
