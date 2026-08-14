options(stringsAsFactors = FALSE)
repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(repo, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
paths <- file.path(repo, "data_cache", "alpaca_intraday_30min",
                   sprintf("intraday_30min_sip_all_%d.rds", 2017:2023))
if (!all(file.exists(paths))) stop("The frozen 2017-2023 cache is incomplete.")
bars <- do.call(rbind, lapply(paths, readRDS))
bars <- imom30_apply_rth_calendar(bars)
bars <- bars[as.Date(bars$session_date) >= as.Date("2018-01-02") &
               as.Date(bars$session_date) <= as.Date("2023-12-29"), , drop = FALSE]
reference <- bars[bars$symbol == "SPY", c("timestamp_utc", "session_date", "bar_time_et")]
symbols <- setdiff(unique(bars$symbol), "SPY")

missing_rows <- lapply(symbols, function(symbol) {
  observed <- bars[bars$symbol == symbol, , drop = FALSE]
  missing <- reference[!as.numeric(reference$timestamp_utc) %in%
                         as.numeric(observed$timestamp_utc), , drop = FALSE]
  data.frame(
    symbol = symbol,
    missing_bars = nrow(missing),
    missing_fraction = nrow(missing) / nrow(reference),
    missing_open = sum(missing$bar_time_et == "09:30:00"),
    missing_close = sum(missing$bar_time_et == "15:30:00"),
    affected_sessions = length(unique(missing$session_date)),
    maximum_missing_in_one_session = if (nrow(missing)) max(table(missing$session_date)) else 0L
  )
})
summary <- do.call(rbind, missing_rows)
summary <- summary[order(-summary$missing_bars, summary$symbol), ]

slot_values <- unlist(lapply(symbols, function(symbol) {
  observed <- bars[bars$symbol == symbol, , drop = FALSE]
  reference$bar_time_et[!as.numeric(reference$timestamp_utc) %in%
                          as.numeric(observed$timestamp_utc)]
}), use.names = FALSE)
slot_summary <- data.frame(
  bar_time_et = names(sort(table(slot_values), decreasing = TRUE)),
  missing_bars = as.integer(sort(table(slot_values), decreasing = TRUE))
)

missing_detail <- do.call(rbind, lapply(symbols, function(symbol) {
  observed <- bars[bars$symbol == symbol, , drop = FALSE]
  missing <- reference[!as.numeric(reference$timestamp_utc) %in%
                         as.numeric(observed$timestamp_utc), , drop = FALSE]
  if (!nrow(missing)) return(NULL)
  missing$symbol <- symbol
  missing[, c("symbol", "timestamp_utc", "session_date", "bar_time_et")]
}))
session_summary <- aggregate(bar_time_et ~ symbol + session_date, missing_detail, length)
names(session_summary)[3] <- "missing_bars"
session_summary <- session_summary[order(-session_summary$missing_bars,
                                         session_summary$session_date,
                                         session_summary$symbol), ]

run_dir <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab",
                     "intraday_momentum_data_admission_20260813")
write.csv(summary, file.path(run_dir, "intraday_calendar_mismatch_diagnostic.csv"), row.names = FALSE)
write.csv(slot_summary, file.path(run_dir, "intraday_calendar_mismatch_by_slot.csv"), row.names = FALSE)
write.csv(missing_detail, file.path(run_dir, "intraday_calendar_mismatch_detail.csv"), row.names = FALSE)
write.csv(session_summary, file.path(run_dir, "intraday_calendar_mismatch_by_session.csv"), row.names = FALSE)
print(summary, row.names = FALSE)
cat("\nMissing bars by clock slot:\n")
print(slot_summary, row.names = FALSE)
cat("\nSessions missing at least half their expected bars:\n")
print(session_summary[session_summary$missing_bars >= 7L, ], row.names = FALSE)
