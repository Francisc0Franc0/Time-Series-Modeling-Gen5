# ADL-WIKI-02.1: reaction control versus causal one-session GME lead test.
# No threshold, strategy, costs, performance replay, or horizon search is run.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "alternative_data_lab", "R", "wikimedia_attention_lead.R"))

contract <- adwl_validate_contract(adwl_contract())
parent_dir <- file.path(
  repo_root, "runs", "research_workbench", "alternative_data_lab",
  "wikimedia_attention_gamestop_20260901"
)
attention_path <- file.path(parent_dir, "daily_pageviews.csv")
bars_path <- file.path(
  repo_root, "data_cache", "alpaca_daily_adjusted", "alpaca", "1D", "GME.rds"
)
if (!file.exists(attention_path)) {
  adwl_stop("Parent Wikimedia daily ledger is missing; run ADL-WIKI-01.1 first.")
}
if (!file.exists(bars_path)) adwl_stop("Cached adjusted Alpaca GME daily bars are missing.")

run_dir <- file.path(
  repo_root, "runs", "research_workbench", "alternative_data_lab",
  "wikimedia_attention_lead_gme_20260901"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

daily <- read.csv(attention_path, stringsAsFactors = FALSE)
daily$date <- as.Date(daily$date)
daily$observed_from_api <- as.logical(daily$observed_from_api)
bars <- readRDS(bars_path)

features <- adwl_attention_features(daily, contract)
reaction <- adwl_reaction_panel(features, bars, contract)
forward <- adwl_forward_panel(features, bars, contract)
summary_table <- rbind(
  adwl_relationship_summary(
    reaction$attention_log_ratio, reaction$completed_close_return,
    "completed_same_session_close_to_close_reaction_control"
  ),
  adwl_relationship_summary(
    forward$attention_log_ratio, forward$future_open_log_return,
    "causal_48h_buffer_next_open_one_session_forward"
  )
)

valid_features <- features[is.finite(features$attention_log_ratio), , drop = FALSE]
bars_checked <- adwl_validate_bars(bars, contract)
source_lag <- as.integer(forward$entry_session - forward$source_attention_date)
construction_checks <- data.frame(
  check_id = c(
    "parent_attention_ledger_present", "adjusted_alpaca_daily_authority",
    "attention_stops_2023", "market_stops_2023", "trailing_baseline_is_28_prior_days",
    "publication_buffer_is_48_hours", "attention_strictly_precedes_entry",
    "safe_availability_not_after_entry", "one_session_open_to_open_outcome",
    "no_threshold_or_rule"
  ),
  status = c(
    file.exists(attention_path),
    all(bars_checked$adjusted & bars_checked$provider == "alpaca" & bars_checked$timeframe == "1D"),
    max(features$date) == contract$attention_end,
    max(bars_checked$session_date) <= contract$market_end && max(forward$exit_session) <= contract$market_end,
    all(valid_features$prior_observation_count == contract$trailing_calendar_days),
    contract$publication_buffer_hours == 48L,
    all(forward$source_attention_date < forward$entry_session),
    all(forward$safe_available_date <= forward$entry_session),
    all(forward$exit_session == bars_checked$session_date[match(forward$entry_session, bars_checked$session_date) + 1L]),
    TRUE
  ),
  detail = c(
    attention_path,
    bars_path,
    paste(min(features$date), max(features$date), sep = " through "),
    paste(min(bars_checked$session_date), max(bars_checked$session_date), sep = " through "),
    paste(nrow(valid_features), "valid attention features"),
    "UTC day endpoint plus 48 hours; entry at first eligible session open",
    paste("source-to-entry lag range", min(source_lag), "to", max(source_lag), "calendar days"),
    "as-of join passed",
    paste(nrow(forward), "open-to-open outcomes"),
    "continuous descriptive feature only"
  ),
  stringsAsFactors = FALSE
)
if (!all(construction_checks$status)) {
  adwl_stop(paste(
    "Lead construction checks failed:",
    paste(construction_checks$check_id[!construction_checks$status], collapse = ", ")
  ))
}

run_spec <- data.frame(
  field = c(
    "hypothesis_id", "parent_id", "authority", "article", "symbol",
    "attention_feature", "attention_lookback", "publication_buffer",
    "entry_clock", "primary_outcome", "attention_range", "market_end",
    "attention_source", "market_source", "threshold", "costs", "strategy_replay"
  ),
  value = c(
    contract$hypothesis_id, contract$parent_id, contract$authority, contract$article,
    contract$symbol, "log(views / median(prior 28 calendar days))",
    "28 complete prior calendar days", "48 hours after UTC measurement-day endpoint",
    "first adjusted GME session open on/after safe availability date",
    "next open / entry open log return; exactly one session",
    paste(contract$attention_start, contract$attention_end, sep = " through "),
    as.character(contract$market_end), attention_path, bars_path,
    "NONE", "NONE", "NONE"
  ),
  stringsAsFactors = FALSE
)

top_tape <- forward[order(-forward$attention_log_ratio, forward$entry_session), c(
  "source_attention_date", "safe_available_date", "entry_session", "exit_session",
  "views", "prior_28d_median", "attention_log_ratio", "future_open_log_return"
)]
top_tape <- head(top_tape, 20L)

write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE, na = "")
write.csv(construction_checks, file.path(run_dir, "construction_checks.csv"), row.names = FALSE, na = "")
write.csv(features, file.path(run_dir, "attention_features.csv"), row.names = FALSE, na = "")
write.csv(reaction, file.path(run_dir, "reaction_control_panel.csv"), row.names = FALSE, na = "")
write.csv(forward, file.path(run_dir, "causal_forward_panel.csv"), row.names = FALSE, na = "")
write.csv(summary_table, file.path(run_dir, "descriptive_summary.csv"), row.names = FALSE, na = "")
write.csv(top_tape, file.path(run_dir, "highest_attention_tape.csv"), row.names = FALSE, na = "")

scatter_path <- file.path(visual_dir, "attention_reaction_vs_causal_forward.png")
png(scatter_path, width = 1900, height = 900, res = 170)
par(mfrow = c(1, 2), mar = c(5, 5, 4.5, 1.5), oma = c(0, 0, 2, 0),
    bg = "#FAFAF7", fg = "#24313A", col.axis = "#52616B", col.lab = "#24313A")
all_y <- range(c(reaction$completed_close_return, forward$future_open_log_return), finite = TRUE)
plot_relationship <- function(x, y, main, subtitle, label_dates = NULL, dates = NULL) {
  plot(
    x, y, pch = 16, cex = 0.62, col = grDevices::adjustcolor("#456990", alpha.f = 0.35),
    xlab = "Attention surprise: log(views / prior-28d median)",
    ylab = "GME log return", main = main, sub = subtitle, ylim = all_y
  )
  grid(col = "#D9DEDF")
  abline(h = 0, col = "#7A858A", lty = 2)
  fit <- stats::lm(y ~ x)
  abline(fit, col = "#C8553D", lwd = 2.3)
  if (!is.null(label_dates) && !is.null(dates)) {
    mark <- dates %in% label_dates
    if (any(mark)) {
      points(x[mark], y[mark], pch = 21, bg = "#F3B61F", col = "#24313A", cex = 1.2)
      label_pos <- ifelse(x[mark] > stats::median(x, na.rm = TRUE), 2, 4)
      text(x[mark], y[mark], labels = format(dates[mark], "%Y-%m-%d"), pos = label_pos, cex = 0.72)
    }
  }
}
reaction_stats <- summary_table[summary_table$relationship == "completed_same_session_close_to_close_reaction_control", ]
forward_stats <- summary_table[summary_table$relationship == "causal_48h_buffer_next_open_one_session_forward", ]
plot_relationship(
  reaction$attention_log_ratio, reaction$completed_close_return,
  "Reaction control",
  sprintf("Completed same-session move | Pearson r = %+.3f | n = %d", reaction_stats$pearson, reaction_stats$observations),
  as.Date("2021-01-28"), reaction$attention_date
)
plot_relationship(
  forward$attention_log_ratio, forward$future_open_log_return,
  "Causal forward test",
  sprintf("48h buffer, then next open-to-open | Pearson r = %+.3f | n = %d", forward_stats$pearson, forward_stats$observations),
  as.Date("2021-01-28"), forward$source_attention_date
)
mtext("Does Wikipedia attention lead GME, or document a move already underway?", outer = TRUE, cex = 1.35, font = 2)
dev.off()

timeline_path <- file.path(visual_dir, "attention_signal_and_gme_price_timeline.png")
timeline_bars <- bars_checked[
  bars_checked$session_date >= contract$attention_start &
    bars_checked$session_date <= contract$market_end,
  , drop = FALSE
]
png(timeline_path, width = 1900, height = 1050, res = 170)
par(mfrow = c(2, 1), mar = c(3.5, 5, 3.5, 2), oma = c(3, 0, 1, 0),
    bg = "#FAFAF7", fg = "#24313A", col.axis = "#52616B", col.lab = "#24313A")
plot(
  valid_features$date, valid_features$attention_log_ratio, type = "h", lend = 1,
  col = grDevices::adjustcolor("#456990", alpha.f = 0.55),
  xlab = "", ylab = "Log attention ratio", main = "Causal trailing attention surprise"
)
grid(col = "#D9DEDF")
abline(h = 0, col = "#7A858A", lty = 2)
plot(
  timeline_bars$session_date, timeline_bars$close, type = "l", log = "y", lwd = 1.5,
  col = "#C8553D", xlab = "", ylab = "Adjusted GME close (log scale)",
  main = "GME price shown only for temporal context"
)
grid(col = "#D9DEDF")
mtext("Date", side = 1, outer = TRUE, line = 1)
mtext("No threshold, position, or performance replay", side = 1, outer = TRUE, line = 2.4, cex = 0.85)
dev.off()

fmt <- function(x, digits = 3L) formatC(x, digits = digits, format = "f", flag = "+")
lead_verdict <- if (is.finite(forward_stats$pearson) && forward_stats$pearson > 0.05 &&
                    is.finite(forward_stats$spearman) && forward_stats$spearman > 0.05) {
  "DESCRIPTIVE_LEAD_CLUE_REQUIRES_FROZEN_CONFIRMATION"
} else {
  "STOP_NO_OBVIOUS_ONE_SESSION_DIRECTIONAL_LEAD"
}
report <- c(
  "# ADL-WIKI-02.1 — GameStop Wikipedia Attention Leading-Signal POC",
  "",
  "## Narrative hypothesis",
  "",
  "If public attention contains directional information before GME price discovery is complete, a causal attention surprise should be followed by positive GME return. If page views mainly document a move already underway, association should be more visible in the completed reaction control than after a conservative availability clock.",
  "",
  "## Frozen timing",
  "",
  "- Feature: `log(daily views / median of the prior 28 complete calendar days)`.",
  "- Historical-availability safeguard: the UTC measurement day must end, then 48 additional hours elapse.",
  "- Entry observation: first adjusted GME session open on or after that safe date.",
  "- Primary outcome: exactly one following open-to-open session.",
  "- Threshold, costs, trades, performance, horizon search, and post-2023 market data: `NONE`.",
  "",
  "## Readout",
  "",
  paste0("- Reaction control: `n=", reaction_stats$observations, "`, Pearson `", fmt(reaction_stats$pearson), "`, Spearman `", fmt(reaction_stats$spearman), "`, R-squared `", formatC(100 * reaction_stats$r_squared, digits = 2, format = "f"), "%`."),
  paste0("- Causal one-session forward test: `n=", forward_stats$observations, "`, Pearson `", fmt(forward_stats$pearson), "`, Spearman `", fmt(forward_stats$spearman), "`, R-squared `", formatC(100 * forward_stats$r_squared, digits = 2, format = "f"), "%`."),
  "",
  "The comparison is descriptive. The reaction panel is not a tradable benchmark because the attention measurement is incomplete during the associated session. The forward panel is the only causal leading-signal surface in this slice.",
  "",
  paste0("![Reaction versus forward scatter](visuals/", basename(scatter_path), ")"),
  "",
  paste0("![Attention and price timeline](visuals/", basename(timeline_path), ")"),
  "",
  "## Decision",
  "",
  paste0("`", lead_verdict, "`"),
  "",
  "Do not shorten the publication buffer, select an attention threshold, add horizons, choose favorable subperiods, or formulate a trading rule from this inspected surface. A faster historical claim would require archived first-availability timestamps; a live follow-up would require prospective receipt-time capture."
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("ADL-WIKI-02.1 complete")
message("Decision: ", lead_verdict)
message("Reaction Pearson: ", fmt(reaction_stats$pearson))
message("Forward Pearson: ", fmt(forward_stats$pearson))
message("Report: ", file.path(run_dir, "report.md"))
message("Scatter: ", scatter_path)
