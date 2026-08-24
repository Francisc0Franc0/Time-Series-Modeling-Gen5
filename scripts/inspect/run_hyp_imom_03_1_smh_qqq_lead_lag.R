options(stringsAsFactors = FALSE)

repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- file.path(repo, ".codex_r_libs")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
source(file.path(repo, "operator_hypothesis_lab", "R", "gen5_hyp_imom_03_1_smh_qqq_lead_lag.R"))

contract <- g5_him031_contract()
g5_him031_validate_contract(contract)
cache_dir <- file.path(repo, "data_cache", "alpaca_intraday_30min")
run_dir <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab", "hyp_imom_03_1_smh_qqq_lead_lag_20260822")
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

load_year <- function(year) {
  base_path <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d.rds", year))
  smh_path <- file.path(cache_dir, sprintf("intraday_30min_sip_smh_%d.rds", year))
  if (!file.exists(base_path) || !file.exists(smh_path)) stop("Required bounded intraday cache is missing: ", year)
  base <- readRDS(base_path)
  smh <- readRDS(smh_path)
  rbind(base[base$symbol %in% c("QQQ", "SPY"), , drop = FALSE], smh)
}

year_bars <- lapply(2017:2023, load_year)
names(year_bars) <- as.character(2017:2023)
all_bars <- do.call(rbind, year_bars)
all_bars <- all_bars[!duplicated(all_bars[c("symbol", "timestamp_utc")]), , drop = FALSE]

# Source audit may inspect timestamps and integrity through 2023, but outcome
# construction below is hard-capped at DEVELOPMENT end and never receives 2023 bars.
prepared_all <- g5_him031_prepare_bars(all_bars, contract)
coverage_rows <- lapply(2018:2023, function(year) {
  x <- prepared_all[as.integer(format(prepared_all$session_date, "%Y")) == year, , drop = FALSE]
  counts <- table(x$symbol)
  sessions <- unique(x$session_date[x$symbol == "SPY"])
  data.frame(
    year = year,
    first_session = min(sessions),
    last_session = max(sessions),
    session_count = length(sessions),
    smh_bars = unname(counts[["SMH"]]), qqq_bars = unname(counts[["QQQ"]]), spy_bars = unname(counts[["SPY"]]),
    exact_bar_counts = length(unique(unname(counts[c("SMH", "QQQ", "SPY")]))) == 1L,
    stringsAsFactors = FALSE
  )
})
coverage <- do.call(rbind, coverage_rows)
source_checks <- data.frame(
  check = c("three_symbols_only", "sip_30min_all", "exact_calendars", "train_support", "development_support", "confirmation_not_constructed"),
  passed = c(
    identical(sort(unique(prepared_all$symbol)), sort(contract$symbols)),
    all(prepared_all$feed == "sip" & prepared_all$timeframe == "30Min" & prepared_all$adjustment == "all"),
    all(coverage$exact_bar_counts),
    sum(coverage$session_count[coverage$year %in% 2018:2020]) >= 700L,
    sum(coverage$session_count[coverage$year %in% 2021:2022]) >= 450L,
    TRUE
  ), stringsAsFactors = FALSE
)
source_status <- if (all(source_checks$passed)) "PASS_HYP_IMOM_03_1_SOURCE_AUDIT" else "STOP_HYP_IMOM_03_1_SOURCE_AUDIT"

write.csv(data.frame(
  field = c("hypothesis_id", "as_of_timestamp", "provider", "feed", "timeframe", "adjustment",
            "prehistory_start", "train_start", "train_end", "development_start", "development_end",
            "confirmation_start", "confirmation_end", "signal_definition", "target_definition", "confirmation_outcomes_constructed"),
  value = c(contract$hypothesis_id, contract$as_of_timestamp, contract$provider, contract$feed, contract$timeframe,
            contract$adjustment, as.character(contract$prehistory_start), as.character(contract$train_start),
            as.character(contract$train_end), as.character(contract$development_start), as.character(contract$development_end),
            as.character(contract$confirmation_start), as.character(contract$confirmation_end),
            "slot1 open to slot2 close: SMH minus QQQ", "slot3 open to final RTH close: QQQ minus SPY", "FALSE")
), file.path(run_dir, "him031_run_spec.csv"), row.names = FALSE)
write.csv(coverage, file.path(run_dir, "him031_source_coverage.csv"), row.names = FALSE)
write.csv(source_checks, file.path(run_dir, "him031_source_checks.csv"), row.names = FALSE)
writeLines(source_status, file.path(run_dir, "SOURCE_STATUS.txt"))
if (!identical(source_status, "PASS_HYP_IMOM_03_1_SOURCE_AUDIT")) quit(status = 2L)

evaluation_bars <- prepared_all[prepared_all$session_date <= contract$development_end, , drop = FALSE]
panel <- g5_him031_make_panel(evaluation_bars, contract)
train_result <- g5_him031_train_run(panel, contract)

write.csv(train_result$metrics, file.path(run_dir, "him031_train_model_metrics.csv"), row.names = FALSE)
write.csv(train_result$coefficients, file.path(run_dir, "him031_train_coefficients.csv"), row.names = FALSE)
write.csv(train_result$loss_improvement, file.path(run_dir, "him031_train_loss_improvement.csv"), row.names = FALSE)
write.csv(train_result$gates, file.path(run_dir, "him031_train_gates.csv"), row.names = FALSE)
write.csv(train_result$decision, file.path(run_dir, "him031_train_decision.csv"), row.names = FALSE)
write.csv(train_result$predictions, file.path(run_dir, "him031_train_predictions.csv"), row.names = FALSE)

metrics <- train_result$metrics
metric_labels <- c(DOW_DRIFT = "Weekday drift", OWN_MARKET = "QQQ + SPY control", LEADER = "Add SMH leadership", WRONG_CLOCK = "Prior-session placebo")
png(file.path(visual_dir, "him031_train_model_loss.png"), width = 1600, height = 900, res = 150)
par(mar = c(7, 5, 3, 1))
values <- metrics$mse * 1e8
colors <- c("#94A3B8", "#2F6DB2", "#0F766E", "#D6A52A")
bp <- barplot(values, names.arg = unname(metric_labels[metrics$model_id]), col = colors, border = NA,
              las = 2, ylab = "Out-of-fold MSE (squared basis points)", main = "Frozen TRAIN forecast-loss comparison")
text(bp, values, labels = sprintf("%.3f", values), pos = 3, cex = 0.85)
dev.off()

train <- train_result$train
control_design <- g5_him031_design(train, "OWN_MARKET")
y_resid <- stats::lm.fit(control_design, train$y_excess)$residuals
x_resid <- stats::lm.fit(control_design, train$x_lead)$residuals
partial_beta <- unname(stats::coef(stats::lm(y_resid ~ x_resid))[[2L]])
png(file.path(visual_dir, "him031_train_partial_relationship.png"), width = 1600, height = 900, res = 150)
par(mar = c(5, 5, 3, 1))
plot(x_resid * 1e4, y_resid * 1e4, pch = 16, cex = 0.65, col = grDevices::adjustcolor("#0F766E", 0.45),
     xlab = "First-hour SMH leadership residual (bp)", ylab = "Remainder QQQ excess-return residual (bp)",
     main = "TRAIN partial relationship after QQQ, SPY, and weekday controls")
abline(h = 0, v = 0, col = "#CBD5E1")
abline(stats::lm(y_resid ~ x_resid), col = "#EA623D", lwd = 3)
legend("topleft", legend = sprintf("Partial slope %.4f", partial_beta), bty = "n", text.col = "#111827")
dev.off()

event_dates <- head(train$anchor_date[order(train$x_lead, decreasing = TRUE)], 3L)
event_rows <- list(); z <- 1L
for (event_i in seq_along(event_dates)) {
  date <- event_dates[[event_i]]
  day <- evaluation_bars[evaluation_bars$session_date == date, , drop = FALSE]
  for (symbol in contract$symbols) {
    x <- day[day$symbol == symbol, , drop = FALSE]
    cumulative <- log(x$close / x$open[[1L]]) * 1e4
    event_rows[[z]] <- data.frame(anchor_date = date, symbol = symbol, bar_slot = x$bar_slot,
                                  cumulative_return_bp = cumulative, stringsAsFactors = FALSE)
    z <- z + 1L
  }
}
event_tapes <- do.call(rbind, event_rows)
write.csv(event_tapes, file.path(run_dir, "him031_representative_event_tapes.csv"), row.names = FALSE)
png(file.path(visual_dir, "him031_representative_event_tapes.png"), width = 1800, height = 900, res = 150)
par(mfrow = c(1, 3), mar = c(4, 4, 4, 1))
symbol_colors <- c(SMH = "#EA623D", QQQ = "#0F766E", SPY = "#64748B")
for (event_i in seq_along(event_dates)) {
  date <- event_dates[[event_i]]
  x <- event_tapes[event_tapes$anchor_date == date, , drop = FALSE]
  yr <- range(x$cumulative_return_bp, finite = TRUE)
  plot(NA, xlim = range(x$bar_slot), ylim = yr, xlab = "30-minute slot", ylab = "Cumulative return (bp)",
       main = as.character(date))
  abline(v = 2.5, lty = 2, col = "#D6A52A")
  abline(h = 0, col = "#CBD5E1")
  for (symbol in contract$symbols) {
    y <- x[x$symbol == symbol, , drop = FALSE]
    lines(y$bar_slot, y$cumulative_return_bp, col = symbol_colors[[symbol]], lwd = 2.5)
  }
  legend("topleft", legend = contract$symbols, col = symbol_colors[contract$symbols], lwd = 2.5, bty = "n", cex = 0.8)
}
dev.off()

development_result <- NULL
if (identical(train_result$decision$status, "TRAIN_LEAD_LAG_GATES_PASS")) {
  development_result <- g5_him031_development_run(panel, train_result, contract)
  write.csv(development_result$metrics, file.path(run_dir, "him031_development_model_metrics.csv"), row.names = FALSE)
  write.csv(development_result$loss_improvement, file.path(run_dir, "him031_development_loss_improvement.csv"), row.names = FALSE)
  write.csv(development_result$quartile, file.path(run_dir, "him031_development_quartile.csv"), row.names = FALSE)
  write.csv(development_result$gates, file.path(run_dir, "him031_development_gates.csv"), row.names = FALSE)
  write.csv(development_result$decision, file.path(run_dir, "him031_development_decision.csv"), row.names = FALSE)
  write.csv(development_result$predictions, file.path(run_dir, "him031_development_predictions.csv"), row.names = FALSE)
  final_status <- development_result$decision$status
  development_note <- paste0(
    "DEVELOPMENT was opened by a complete TRAIN pass. Locked result: `", final_status, "`."
  )
} else {
  final_status <- train_result$decision$status
  writeLines("TRAIN gates failed; 2021-2022 DEVELOPMENT outcomes were not constructed or scored.",
             file.path(run_dir, "DEVELOPMENT_NOT_READ.txt"))
  development_note <- "TRAIN failed, so 2021-2022 DEVELOPMENT outcomes were not constructed or scored."
}
writeLines("2023 CONFIRMATION outcomes were not constructed or scored.", file.path(run_dir, "CONFIRMATION_NOT_READ.txt"))
writeLines(final_status, file.path(run_dir, "STATUS.txt"))

decision <- train_result$decision
gate_text <- paste0("- `", train_result$gates$gate, "`: ", ifelse(train_result$gates$passed, "PASS", "FAIL"), collapse = "\n")
report <- c(
  "# HYP-IMOM-03.1 SMH-to-QQQ First-Hour Lead-Lag Run Report",
  "",
  paste0("Status: `", final_status, "`"),
  "",
  "## Source audit",
  "",
  paste0("The bounded Alpaca SIP 30-minute source audit passed `", sum(source_checks$passed), " / ", nrow(source_checks), "` checks. ",
         "SMH, QQQ, and SPY shared exact calendars after the ten common archive-gap exclusions."),
  "",
  "## Frozen TRAIN result",
  "",
  paste0("The all-TRAIN SMH-leadership coefficient was `", sprintf("%.8f", decision$leader_coefficient), "`. ",
         "Out-of-fold LEADER MSE was `", sprintf("%.10g", decision$leader_mse), "` versus `", sprintf("%.10g", decision$own_market_mse),
         "` for OWN_MARKET and `", sprintf("%.10g", decision$wrong_clock_mse), "` for WRONG_CLOCK."),
  paste0("The stationary-bootstrap 10th percentile of squared-loss improvement was `", sprintf("%.10g", decision$loss_improvement_q10),
         "`; the bootstrap probability of positive improvement was `", sprintf("%.4f", decision$loss_improvement_probability_positive), "`."),
  "",
  "### TRAIN gates",
  "",
  gate_text,
  "",
  "## Evidence boundary",
  "",
  development_note,
  "2023 confirmation remained sealed. No strategy or performance surface was opened.",
  "",
  "## Artifacts",
  "",
  "- `him031_source_coverage.csv` and `him031_source_checks.csv`",
  "- `him031_train_model_metrics.csv`, `him031_train_coefficients.csv`, and `him031_train_gates.csv`",
  "- `visuals/him031_train_model_loss.png`",
  "- `visuals/him031_train_partial_relationship.png`",
  "- `visuals/him031_representative_event_tapes.png`"
)
writeLines(report, file.path(run_dir, "him031_report.md"))

message(final_status)
message("Source: ", source_status)
message("Packet: ", normalizePath(run_dir, winslash = "/", mustWork = TRUE))
