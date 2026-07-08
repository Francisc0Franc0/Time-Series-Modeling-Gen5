args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else file.path("scripts", "inspect", "run_gen52_sofi_ema_cross_semantics_probe.R")
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "strategy_ema_cross.R"))

packet_dir <- file.path(
  repo_root,
  "runs",
  "research_workbench",
  "gen4_equivalence",
  "gen4_equivalence_gen52fallbackfull162024q420260708"
)
out_dir <- file.path(packet_dir, "sofi_ema_cross_semantics_probe")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

bars_path <- file.path(packet_dir, "query", "gen4_equivalence_query_bars.csv")
replay_path <- file.path(packet_dir, "gen4_equivalence_replay_oos.csv")
gen5_trades_path <- file.path(packet_dir, "gen4_equivalence_trades.csv")
gen4_trades_path <- file.path(packet_dir, "trade_tape_audit", "sofi_pltr_gen4_trade_tape.csv")

required_paths <- c(bars_path, replay_path, gen5_trades_path, gen4_trades_path)
missing_paths <- required_paths[!file.exists(required_paths)]
if (length(missing_paths)) {
  stop("Missing required input artifact(s): ", paste(missing_paths, collapse = ", "))
}

bars <- read.csv(bars_path, stringsAsFactors = FALSE)
bars$session_date <- as.Date(bars$session_date)
sofi_bars <- bars[bars$symbol == "SOFI", , drop = FALSE]
sofi_bars <- sofi_bars[order(sofi_bars$session_date), , drop = FALSE]
if (!nrow(sofi_bars)) stop("No SOFI bars found in query packet.")

fast_period <- 1L
slow_period <- 10L
ind <- g5_ema_cross_indicators(
  sofi_bars,
  symbol = "SOFI",
  fast_period = fast_period,
  slow_period = slow_period,
  start_date = as.Date("2024-09-01"),
  end_date = as.Date("2024-12-31")
)

ind$prev_fast_ema <- c(NA_real_, head(ind$fast_ema, -1L))
ind$prev_slow_ema <- c(NA_real_, head(ind$slow_ema, -1L))
ind$cross_event <- ifelse(
  is.finite(ind$prev_fast_ema) & is.finite(ind$prev_slow_ema) &
    ind$prev_fast_ema <= ind$prev_slow_ema & ind$fast_ema > ind$slow_ema,
  "cross_above",
  ifelse(
    is.finite(ind$prev_fast_ema) & is.finite(ind$prev_slow_ema) &
      ind$prev_fast_ema >= ind$prev_slow_ema & ind$fast_ema < ind$slow_ema,
    "cross_below",
    "none"
  )
)

replay <- read.csv(replay_path, stringsAsFactors = FALSE)
replay$session_date <- as.Date(replay$session_date)
fallback_policy <- "pooled_family_asset_variant_state_fallback"
sofi_replay <- replay[
  replay$symbol == "SOFI" &
    replay$selection_policy == fallback_policy &
    replay$session_date >= as.Date("2024-10-01") &
    replay$session_date <= as.Date("2024-12-31"),
  ,
  drop = FALSE
]

probe <- merge(
  ind[, c("session_date", "open", "high", "low", "close", "fast_ema", "slow_ema", "signal_state", "cross_event")],
  sofi_replay[, c(
    "session_date",
    "state_id",
    "selected_strategy_family",
    "selected_strategy_spec_id",
    "model_position_after_replay",
    "signal_status",
    "execution_status",
    "open_trade_strategy_spec_id",
    "open_trade_entry_execution_date"
  )],
  by = "session_date",
  all.x = TRUE
)
probe <- probe[probe$session_date >= as.Date("2024-10-01"), , drop = FALSE]

gen5_trades <- read.csv(gen5_trades_path, stringsAsFactors = FALSE)
gen5_trades <- gen5_trades[
  gen5_trades$symbol == "SOFI" &
    gen5_trades$selection_policy == fallback_policy,
  ,
  drop = FALSE
]
gen5_trades$entry_execution_date <- as.Date(gen5_trades$entry_execution_date)
gen5_trades$exit_execution_date <- as.Date(gen5_trades$exit_execution_date)

gen4_trades <- read.csv(gen4_trades_path, stringsAsFactors = FALSE)
gen4_trades <- gen4_trades[gen4_trades$asset == "SOFI", , drop = FALSE]
gen4_trades$entry_date <- as.Date(gen4_trades$entry_date)
gen4_trades$exit_date <- as.Date(gen4_trades$exit_date)

events <- data.frame(
  event_type = character(),
  event_date = as.Date(character()),
  detail = character(),
  stringsAsFactors = FALSE
)

append_event <- function(type, date, detail) {
  if (length(date) == 0L || is.na(date[[1L]])) return(invisible(NULL))
  events <<- rbind(
    events,
    data.frame(event_type = type, event_date = as.Date(date[[1L]]), detail = detail, stringsAsFactors = FALSE)
  )
}

cross_above <- probe[probe$cross_event == "cross_above", , drop = FALSE]
cross_below <- probe[probe$cross_event == "cross_below", , drop = FALSE]
first_cross_above_q4 <- cross_above[cross_above$session_date >= as.Date("2024-10-01"), , drop = FALSE]
first_cross_below_after_gen4_entry <- cross_below[cross_below$session_date >= as.Date("2024-10-04"), , drop = FALSE]

first_ema_state <- sofi_replay[sofi_replay$selected_strategy_family == "ema_cross", , drop = FALSE]
first_gen5_enter <- sofi_replay[sofi_replay$signal_status == "ENTER_LONG_NEXT_OPEN", , drop = FALSE]
first_gen5_exec <- sofi_replay[sofi_replay$execution_status == "ENTER_EXECUTED_AT_OPEN", , drop = FALSE]

append_event("ema_cross_signal", first_cross_above_q4$session_date, "First Q4 fast-above-slow signal for f1/s10")
append_event("gen4_entry", gen4_trades$entry_date, "Gen4 first SOFI entry execution")
append_event("gen5_state_switch", first_ema_state$session_date, "Gen5.2 fallback first routes SOFI to ema_cross")
append_event("gen5_entry_signal", first_gen5_enter$session_date, "Gen5.2 fallback first fresh entry signal after state routing")
append_event("gen5_entry", first_gen5_exec$session_date, "Gen5.2 fallback first SOFI entry execution")
append_event("ema_cross_exit_signal", first_cross_below_after_gen4_entry$session_date, "First f1/s10 cross-below after Gen4 entry")

write.csv(probe, file.path(out_dir, "sofi_ema_cross_signal_comparison.csv"), row.names = FALSE)
write.csv(events[order(events$event_date), , drop = FALSE], file.path(out_dir, "sofi_ema_cross_event_index.csv"), row.names = FALSE)

state_family_summary <- aggregate(
  list(oos_days = sofi_replay$session_date),
  by = list(state_id = sofi_replay$state_id, selected_strategy_family = sofi_replay$selected_strategy_family),
  FUN = length
)
state_family_summary <- state_family_summary[order(state_family_summary$state_id, state_family_summary$selected_strategy_family), , drop = FALSE]
write.csv(state_family_summary, file.path(out_dir, "sofi_fallback_state_family_summary.csv"), row.names = FALSE)
write.csv(gen5_trades, file.path(out_dir, "sofi_gen52_fallback_trades.csv"), row.names = FALSE)
write.csv(gen4_trades, file.path(out_dir, "sofi_gen4_trades.csv"), row.names = FALSE)

first_cross <- if (nrow(first_cross_above_q4)) first_cross_above_q4$session_date[[1L]] else as.Date(NA)
first_gen4_entry <- if (nrow(gen4_trades)) gen4_trades$entry_date[[1L]] else as.Date(NA)
first_state_switch <- if (nrow(first_ema_state)) first_ema_state$session_date[[1L]] else as.Date(NA)
first_gen5_entry <- if (nrow(first_gen5_exec)) first_gen5_exec$session_date[[1L]] else as.Date(NA)
first_gen4_ret <- if (nrow(gen4_trades)) gen4_trades$trade_ret[[1L]] else NA_real_
first_gen5_ret <- if (nrow(gen5_trades)) {
  (as.numeric(gen5_trades$exit_execution_price[[1L]]) / as.numeric(gen5_trades$entry_execution_price[[1L]])) - 1
} else {
  NA_real_
}

summary <- data.frame(
  probe = "SOFI ema_cross_f1_s10 state-gated timing",
  first_q4_cross_above_signal = as.character(first_cross),
  gen4_first_entry_execution = as.character(first_gen4_entry),
  gen52_fallback_first_ema_cross_state_date = as.character(first_state_switch),
  gen52_fallback_first_entry_execution = as.character(first_gen5_entry),
  gen4_first_trade_return = first_gen4_ret,
  gen52_fallback_first_trade_return = first_gen5_ret,
  interpretation = paste(
    "Gen5.2 fallback selected the Gen4-picked f1/s10 spec in S1_4,",
    "but it first routed SOFI to ema_cross after the early Q4 cross had already fired.",
    "The state-gated replay then waited for the next fresh cross, which arrived in December."
  ),
  stringsAsFactors = FALSE
)
write.csv(summary, file.path(out_dir, "sofi_ema_cross_summary.csv"), row.names = FALSE)

png(file.path(out_dir, "sofi_ema_cross_signal_timeline.png"), width = 2200, height = 1250, res = 180)
op <- par(mar = c(6, 5, 4, 5), bg = "white")
plot(
  probe$session_date,
  probe$close,
  type = "l",
  lwd = 2,
  col = "#111111",
  xlab = "",
  ylab = "SOFI adjusted close",
  main = "SOFI f1/s10 EMA Cross: Signal Timing vs Gen5.2 State Routing"
)
lines(probe$session_date, probe$fast_ema, col = "#2E86AB", lwd = 1.5)
lines(probe$session_date, probe$slow_ema, col = "#FF6B35", lwd = 1.5)
state_cols <- c(
  bollinger_touch = "#F4D35E",
  ema_cross = "#9B5DE5",
  pullback_in_uptrend = "#00A896"
)
usr <- par("usr")
for (i in seq_len(nrow(probe))) {
  fam <- probe$selected_strategy_family[[i]]
  if (!is.na(fam) && fam %in% names(state_cols)) {
    rect(
      xleft = probe$session_date[[i]] - 0.5,
      ybottom = usr[[3L]],
      xright = probe$session_date[[i]] + 0.5,
      ytop = usr[[4L]],
      col = adjustcolor(state_cols[[fam]], alpha.f = 0.12),
      border = NA
    )
  }
}
lines(probe$session_date, probe$close, col = "#111111", lwd = 2)
lines(probe$session_date, probe$fast_ema, col = "#2E86AB", lwd = 1.5)
lines(probe$session_date, probe$slow_ema, col = "#FF6B35", lwd = 1.5)

add_vline <- function(date, col, label, y_frac) {
  if (length(date) == 0L || is.na(date[[1L]])) return(invisible(NULL))
  abline(v = as.Date(date[[1L]]), col = col, lwd = 2, lty = 2)
  text(
    as.Date(date[[1L]]),
    usr[[3L]] + y_frac * diff(usr[3:4]),
    labels = label,
    srt = 90,
    adj = c(0, -0.25),
    cex = 0.78,
    col = col
  )
}
add_vline(first_cross, "#2E86AB", "cross above\nOct 3", 0.08)
add_vline(first_gen4_entry, "#111111", "Gen4 entry\nOct 4", 0.23)
add_vline(first_state_switch, "#9B5DE5", "Gen5.2 routes\nema_cross", 0.38)
add_vline(first_gen5_entry, "#D1495B", "Gen5.2 entry\nDec 12", 0.53)
legend(
  "topleft",
  legend = c("close", "fast EMA", "slow EMA", "ema_cross-routed days", "other routed days"),
  col = c("#111111", "#2E86AB", "#FF6B35", "#9B5DE5", "#00A896"),
  lwd = c(2, 1.5, 1.5, 8, 8),
  bty = "n",
  cex = 0.85
)
par(op)
dev.off()

report <- c(
  "# SOFI EMA Cross Semantics Probe",
  "",
  "Research inspection only. This probe does not change selection, replay, or allocation behavior.",
  "",
  "## Finding",
  "",
  paste0(
    "- The first Q4 `ema_cross_f1_s10` cross-above signal occurred on ",
    summary$first_q4_cross_above_signal,
    ", with Gen4 entering on ",
    summary$gen4_first_entry_execution,
    "."
  ),
  paste0(
    "- Gen5.2 fallback first routed SOFI to `ema_cross` on ",
    summary$gen52_fallback_first_ema_cross_state_date,
    ", after the early cross was already stale."
  ),
  paste0(
    "- Gen5.2 fallback therefore waited for the next fresh cross and first entered on ",
    summary$gen52_fallback_first_entry_execution,
    "."
  ),
  "",
  "## Interpretation",
  "",
  summary$interpretation,
  "",
  "## Artifacts",
  "",
  "- `sofi_ema_cross_signal_comparison.csv`",
  "- `sofi_ema_cross_event_index.csv`",
  "- `sofi_fallback_state_family_summary.csv`",
  "- `sofi_gen4_trades.csv`",
  "- `sofi_gen52_fallback_trades.csv`",
  "- `sofi_ema_cross_signal_timeline.png`"
)
writeLines(report, file.path(out_dir, "sofi_ema_cross_semantics_probe_report.md"))

message("Wrote SOFI EMA semantics probe to: ", out_dir)
