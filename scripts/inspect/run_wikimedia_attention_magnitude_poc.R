# ADL-WIKI-03.1: causal attention surprise versus one-session move magnitude.
# No threshold, strategy, costs, inference, performance replay, or horizon search.

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
source(file.path(repo_root, "alternative_data_lab", "R", "wikimedia_attention_magnitude.R"))

contract <- adwm_validate_contract(adwm_contract())
attention_path <- file.path(
  repo_root, "runs", "research_workbench", "alternative_data_lab",
  "wikimedia_attention_gamestop_20260901", "daily_pageviews.csv"
)
bars_path <- file.path(
  repo_root, "data_cache", "alpaca_daily_adjusted", "alpaca", "1D", "GME.rds"
)
if (!file.exists(attention_path)) adwl_stop("Parent Wikimedia daily ledger is missing.")
if (!file.exists(bars_path)) adwl_stop("Cached adjusted Alpaca GME daily bars are missing.")

run_dir <- file.path(
  repo_root, "runs", "research_workbench", "alternative_data_lab",
  "wikimedia_attention_magnitude_gme_20260901"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

daily <- read.csv(attention_path, stringsAsFactors = FALSE)
daily$date <- as.Date(daily$date)
daily$observed_from_api <- as.logical(daily$observed_from_api)
bars <- readRDS(bars_path)

features <- adwm_attention_features(daily, contract)
reaction <- adwm_reaction_panel(features, bars, contract)
forward <- adwm_forward_panel(features, bars, contract)
summary_table <- rbind(
  adwl_relationship_summary(
    reaction$attention_log_ratio, reaction$completed_abs_close_return,
    "completed_same_session_absolute_close_return_control"
  ),
  adwl_relationship_summary(
    forward$attention_log_ratio, forward$future_abs_open_log_return,
    "causal_attention_to_absolute_open_return"
  ),
  adwl_relationship_summary(
    forward$attention_log_ratio, forward$entry_session_log_range,
    "causal_attention_to_entry_session_range"
  )
)
bin_summary <- adwm_attention_bin_summary(forward, contract$descriptive_attention_bins)
status <- adwm_readout_status(summary_table)

valid_features <- features[is.finite(features$attention_log_ratio), , drop = FALSE]
market <- adwm_market_bars(bars, contract)
source_lag <- as.integer(forward$entry_session - forward$source_attention_date)
construction_checks <- data.frame(
  check_id = c(
    "parent_attention_ledger_present", "adjusted_alpaca_daily_authority",
    "attention_stops_2023", "market_stops_2023", "trailing_baseline_is_28_prior_days",
    "publication_buffer_is_48_hours", "attention_strictly_precedes_entry",
    "safe_availability_not_after_entry", "one_session_open_to_open_outcome",
    "primary_is_absolute_return", "diagnostic_is_high_low_range",
    "ten_bins_are_descriptive_only", "no_threshold_or_rule"
  ),
  status = c(
    file.exists(attention_path),
    all(market$adjusted & market$provider == "alpaca" & market$timeframe == "1D"),
    max(features$date) == contract$attention_end,
    max(market$session_date) <= contract$market_end && max(forward$exit_session) <= contract$market_end,
    all(valid_features$prior_observation_count == contract$trailing_calendar_days),
    contract$publication_buffer_hours == 48L,
    all(forward$source_attention_date < forward$entry_session),
    all(forward$safe_available_date <= forward$entry_session),
    all(forward$exit_session == market$session_date[match(forward$entry_session, market$session_date) + 1L]),
    all(forward$future_abs_open_log_return == abs(forward$future_open_log_return)),
    all(abs(forward$entry_session_log_range - log(forward$entry_high / forward$entry_low)) < 1e-12),
    nrow(bin_summary) == contract$descriptive_attention_bins && sum(bin_summary$observations) == nrow(forward),
    TRUE
  ),
  detail = c(
    attention_path, bars_path,
    paste(min(features$date), max(features$date), sep = " through "),
    paste(min(market$session_date), max(market$session_date), sep = " through "),
    paste(nrow(valid_features), "valid attention features"),
    "UTC day endpoint plus 48 hours; first eligible session open",
    paste("source-to-entry lag range", min(source_lag), "to", max(source_lag), "calendar days"),
    "as-of join passed", paste(nrow(forward), "one-session outcomes"),
    "absolute next-open log return", "entry-session log(high / low)",
    "equal-count full-sample bins used only as a visual summary",
    "continuous descriptive feature; no position or performance replay"
  ),
  stringsAsFactors = FALSE
)
if (!all(construction_checks$status)) {
  adwl_stop(paste(
    "Magnitude construction checks failed:",
    paste(construction_checks$check_id[!construction_checks$status], collapse = ", ")
  ))
}

run_spec <- data.frame(
  field = c(
    "hypothesis_id", "parent_id", "authority", "article", "symbol",
    "attention_feature", "attention_lookback", "publication_buffer",
    "entry_clock", "primary_outcome", "diagnostic_outcome",
    "descriptive_shape_view", "attention_range", "market_end",
    "threshold", "inference", "costs", "strategy_replay", "horizon_search"
  ),
  value = c(
    contract$hypothesis_id, contract$parent_id, contract$authority, contract$article,
    contract$symbol, "log(views / median(prior 28 calendar days))",
    "28 complete prior calendar days", "48 hours after UTC measurement-day endpoint",
    "first adjusted GME session open on/after safe availability date",
    "absolute log(next open / entry open); exactly one session",
    "log(entry-session high / entry-session low)",
    "10 equal-count attention bins; visualization only",
    paste(contract$attention_start, contract$attention_end, sep = " through "),
    as.character(contract$market_end), "NONE", "NONE", "NONE", "NONE", "NONE"
  ),
  stringsAsFactors = FALSE
)

top_tape <- forward[order(-forward$attention_log_ratio, forward$entry_session), c(
  "source_attention_date", "safe_available_date", "entry_session", "exit_session",
  "views", "prior_28d_median", "attention_log_ratio", "future_open_log_return",
  "future_abs_open_log_return", "entry_session_log_range"
)]
top_tape <- head(top_tape, 20L)

write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE, na = "")
write.csv(construction_checks, file.path(run_dir, "construction_checks.csv"), row.names = FALSE, na = "")
write.csv(forward, file.path(run_dir, "causal_magnitude_panel.csv"), row.names = FALSE, na = "")
write.csv(summary_table, file.path(run_dir, "descriptive_summary.csv"), row.names = FALSE, na = "")
write.csv(bin_summary, file.path(run_dir, "attention_bin_summary.csv"), row.names = FALSE, na = "")
write.csv(top_tape, file.path(run_dir, "highest_attention_magnitude_tape.csv"), row.names = FALSE, na = "")

primary_stats <- summary_table[summary_table$relationship == "causal_attention_to_absolute_open_return", ]
range_stats <- summary_table[summary_table$relationship == "causal_attention_to_entry_session_range", ]
reaction_stats <- summary_table[summary_table$relationship == "completed_same_session_absolute_close_return_control", ]

scatter_path <- file.path(visual_dir, "attention_vs_future_move_magnitude.png")
png(scatter_path, width = 1900, height = 900, res = 170)
par(mfrow = c(1, 2), mar = c(5, 5, 4.5, 1.5), oma = c(0, 0, 2, 0),
    bg = "#FAFAF7", fg = "#24313A", col.axis = "#52616B", col.lab = "#24313A")
plot_magnitude <- function(y, main, subtitle, label_dates = NULL) {
  x <- forward$attention_log_ratio
  plot(
    x, 100 * y, pch = 16, cex = 0.62,
    col = grDevices::adjustcolor("#456990", alpha.f = 0.35),
    xlab = "Attention surprise: log(views / prior-28d median)",
    ylab = "One-session magnitude (%)", main = main, sub = subtitle
  )
  grid(col = "#D9DEDF")
  fit <- stats::lm((100 * y) ~ x)
  abline(fit, col = "#C8553D", lwd = 2.3)
  if (!is.null(label_dates)) {
    mark <- forward$source_attention_date %in% label_dates
    if (any(mark)) {
      points(x[mark], 100 * y[mark], pch = 21, bg = "#F3B61F", col = "#24313A", cex = 1.2)
      label_pos <- ifelse(x[mark] > stats::median(x, na.rm = TRUE), 2, 4)
      text(x[mark], 100 * y[mark], labels = format(forward$source_attention_date[mark], "%Y-%m-%d"),
           pos = label_pos, cex = 0.72)
    }
  }
}
plot_magnitude(
  forward$future_abs_open_log_return, "Absolute next-open return",
  sprintf("Pearson r = %+.3f | Spearman rho = %+.3f | n = %d",
          primary_stats$pearson, primary_stats$spearman, primary_stats$observations),
  as.Date("2021-01-28")
)
plot_magnitude(
  forward$entry_session_log_range, "Entry-session high-low range",
  sprintf("Pearson r = %+.3f | Spearman rho = %+.3f | n = %d",
          range_stats$pearson, range_stats$spearman, range_stats$observations),
  as.Date("2021-01-28")
)
mtext("Does Wikipedia attention forecast the size of GME's next move?", outer = TRUE, cex = 1.35, font = 2)
dev.off()

bins_path <- file.path(visual_dir, "attention_deciles_vs_future_magnitude.png")
png(bins_path, width = 1600, height = 900, res = 170)
par(mar = c(5, 5, 4.5, 2), bg = "#FAFAF7", fg = "#24313A",
    col.axis = "#52616B", col.lab = "#24313A")
ylim <- range(100 * c(bin_summary$median_abs_open_log_return, bin_summary$median_entry_session_log_range))
plot(
  bin_summary$attention_bin, 100 * bin_summary$median_abs_open_log_return,
  type = "b", pch = 16, lwd = 2.3, col = "#C8553D", ylim = ylim,
  xlab = "Attention surprise bin (1 = lowest, 10 = highest)",
  ylab = "Median one-session magnitude (%)",
  main = "Higher attention bins do not automatically imply a larger next move",
  xaxt = "n"
)
axis(1, at = bin_summary$attention_bin)
lines(
  bin_summary$attention_bin, 100 * bin_summary$median_entry_session_log_range,
  type = "b", pch = 17, lwd = 2.3, col = "#456990"
)
grid(col = "#D9DEDF")
legend(
  "topleft", legend = c("Absolute next-open return", "Entry-session high-low range"),
  col = c("#C8553D", "#456990"), pch = c(16, 17), lwd = 2.3, bty = "n"
)
mtext("Equal-count bins summarize shape only; they are not trading thresholds", side = 1, line = 3.8, cex = 0.8)
dev.off()

fmt <- function(x, digits = 3L) formatC(x, digits = digits, format = "f", flag = "+")
report <- c(
  "# ADL-WIKI-03.1 — GameStop Wikipedia Attention Magnitude POC",
  "",
  "## Narrative hypothesis",
  "",
  "Direction may be unpredictable even when attention identifies a period in which a larger GME move is about to occur. Under this hypothesis, a causal attention surprise should rise monotonically with the absolute next-open return and with the entry session's high-low range.",
  "",
  "## Frozen surface",
  "",
  "- Reused the same 28-day trailing attention feature and 48-hour post-UTC-day safeguard as ADL-WIKI-02.1.",
  "- Primary outcome: absolute one-session open-to-open log return.",
  "- Convergent diagnostic: entry-session `log(high / low)` range.",
  "- Ten equal-count attention bins are a descriptive shape view, not thresholds.",
  "- Inference, costs, trades, performance, horizon search, and post-2023 market data: `NONE`.",
  "",
  "## Readout",
  "",
  paste0("- Completed same-session magnitude control: `n=", reaction_stats$observations,
         "`, Pearson `", fmt(reaction_stats$pearson), "`, Spearman `", fmt(reaction_stats$spearman), "`."),
  paste0("- Causal absolute next-open return: `n=", primary_stats$observations,
         "`, Pearson `", fmt(primary_stats$pearson), "`, Spearman `", fmt(primary_stats$spearman), "`."),
  paste0("- Causal entry-session high-low range: `n=", range_stats$observations,
         "`, Pearson `", fmt(range_stats$pearson), "`, Spearman `", fmt(range_stats$spearman), "`."),
  "",
  paste0("![Magnitude scatter](visuals/", basename(scatter_path), ")"),
  "",
  paste0("![Attention-bin shape](visuals/", basename(bins_path), ")"),
  "",
  "## Decision",
  "",
  paste0("`", status, "`"),
  "",
  "This is a descriptive one-asset POC. Do not select a threshold, add horizons or outcomes, formulate a volatility trade, or reinterpret the directional stop from this surface."
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("ADL-WIKI-03.1 complete")
message("Decision: ", status)
message("Absolute-return Spearman: ", fmt(primary_stats$spearman))
message("Range Spearman: ", fmt(range_stats$spearman))
message("Report: ", file.path(run_dir, "report.md"))
message("Scatter: ", scatter_path)
