# Translate two previously observed NVDA daily return-geometry clues into
# executable next-open, fixed-20-session proto-rules. This is a TRAIN-only
# construction check: the 2024+ confirmation period remains sealed.

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_direction.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "own_asset_return_geometry_atlas.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_nvda_daily_proto_rules.R"))

contract <- nvpr_validate_contract()
source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "own_asset_return_geometry_atlas_20260826"
)
run_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_daily_proto_rules_20260831"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

bars_path <- file.path(source_dir, "atlas_query_bars.csv")
if (!file.exists(bars_path)) stop("Missing frozen atlas bars: ", bars_path, call. = FALSE)
bars <- utils::read.csv(bars_path, stringsAsFactors = FALSE)
bars$session_date <- as.Date(bars$session_date)
bars <- bars[
  bars$symbol == contract$symbol & bars$session_date <= contract$analysis_end,
  , drop = FALSE
]
ledger <- oarga_build_ledger(bars, contract$symbol)
study <- nvpr_build_study(ledger, contract)
rule_summary <- nvpr_rule_summary(study$trades, contract)
calendar_summary <- nvpr_calendar_summary(study$trades)
condition_summary <- nvpr_condition_summary(study$candidates)
trade_paths <- nvpr_trade_paths(ledger, study$trades)

primary <- rule_summary[rule_summary$primary_rule, , drop = FALSE]
construction_checks <- data.frame(
  check_id = c(
    "frozen_atlas_source", "exact_symbol", "adjusted_daily_bars", "unique_ordered_sessions",
    "analysis_boundary", "confirmation_period_sealed", "prior_horizon_fixed",
    "holding_horizon_fixed", "next_open_entry", "open_to_open_exit", "cost_fixed",
    "nonoverlap_continuation", "nonoverlap_rebound", "primary_rules_present"
  ),
  passed = c(
    file.exists(bars_path),
    identical(unique(as.character(ledger$symbol)), contract$symbol),
    all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
    !anyDuplicated(ledger$session_date) && all(diff(ledger$session_date) > 0),
    min(study$candidates$anchor_session) >= contract$analysis_start &&
      max(study$candidates$exit_session) <= contract$analysis_end,
    max(ledger$session_date) <= contract$analysis_end,
    identical(contract$prior_sessions, 20L),
    identical(contract$hold_sessions, 20L),
    all(study$candidates$entry_index == study$candidates$anchor_index + 1L),
    all(study$candidates$exit_index == study$candidates$entry_index + 20L),
    identical(contract$round_trip_cost_bps, 10),
    with(study$trades[study$trades$rule_id == "EFFICIENT_UP_CONTINUATION", ],
         nrow(study$trades[study$trades$rule_id == "EFFICIENT_UP_CONTINUATION", ]) < 2L ||
           all(entry_index[-1L] > exit_index[-length(exit_index)])),
    with(study$trades[study$trades$rule_id == "NOT_HIGH_ATR_LOSS_REBOUND", ],
         nrow(study$trades[study$trades$rule_id == "NOT_HIGH_ATR_LOSS_REBOUND", ]) < 2L ||
           all(entry_index[-1L] > exit_index[-length(exit_index)])),
    setequal(primary$rule_id, contract$primary_rules)
  ),
  observed = c(
    normalizePath(bars_path, winslash = "/"),
    paste(unique(ledger$symbol), collapse = ","),
    paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
    paste(min(ledger$session_date), max(ledger$session_date), sep = " to "),
    paste(min(study$candidates$anchor_session), max(study$candidates$exit_session), sep = " to "),
    as.character(max(ledger$session_date)),
    as.character(contract$prior_sessions), as.character(contract$hold_sessions),
    "close t -> open t+1", "open t+1 -> open t+21",
    paste0(contract$round_trip_cost_bps, " bps round trip"),
    paste(primary$trades[primary$rule_id == "EFFICIENT_UP_CONTINUATION"], "trades"),
    paste(primary$trades[primary$rule_id == "NOT_HIGH_ATR_LOSS_REBOUND"], "trades"),
    paste(primary$rule_id, collapse = ",")
  ),
  stringsAsFactors = FALSE
)
if (!all(construction_checks$passed)) {
  stop("NVDA proto-rule checks failed: ",
       paste(construction_checks$check_id[!construction_checks$passed], collapse = ", "),
       call. = FALSE)
}

pretty_rule <- function(x) {
  labels <- c(
    EFFICIENT_UP_CONTINUATION = "Efficient-up continuation",
    POSITIVE_R20_ONLY = "Positive R20 only",
    EFFICIENT_STATE_ONLY = "Efficient state only",
    EFFICIENT_DOWN_OPPOSITE = "Efficient-down opposite",
    NOT_HIGH_ATR_LOSS_REBOUND = "Calm-pullback rebound",
    NEGATIVE_R20_ONLY = "Negative R20 only",
    NOT_HIGH_ATR_STATE_ONLY = "Low/medium ATR state only",
    NOT_HIGH_ATR_POSITIVE_OPPOSITE = "Calm positive opposite"
  )
  unname(labels[x])
}

rule_colors <- c(
  EFFICIENT_UP_CONTINUATION = "#2563A8",
  NOT_HIGH_ATR_LOSS_REBOUND = "#14866D"
)

# Price and trade-window overlay.
price_path <- file.path(visual_dir, "nvda_proto_rule_price_entries.png")
grDevices::png(price_path, width = 2200, height = 1500, res = 180)
graphics::par(mfrow = c(2, 1), mar = c(4.8, 6.3, 5.0, 2.0), family = "sans", bg = "white")
for (rule_id in contract$primary_rules) {
  trades <- study$trades[study$trades$rule_id == rule_id, , drop = FALSE]
  visible <- ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end
  graphics::plot(
    ledger$session_date[visible], ledger$close[visible], type = "l", lwd = 1.35,
    col = "#283548", xlab = "", ylab = "Adjusted close",
    main = pretty_rule(rule_id), col.main = "#142033", cex.main = 1.35, bty = "n"
  )
  usr <- graphics::par("usr")
  for (i in seq_len(nrow(trades))) {
    graphics::rect(
      trades$entry_session[[i]], usr[[3L]], trades$exit_session[[i]], usr[[4L]],
      col = grDevices::adjustcolor(rule_colors[[rule_id]], alpha.f = 0.10), border = NA
    )
  }
  graphics::lines(ledger$session_date[visible], ledger$close[visible], lwd = 1.35, col = "#283548")
  graphics::points(trades$entry_session, trades$entry_open, pch = 24, bg = rule_colors[[rule_id]], col = "white", cex = 0.9)
  graphics::points(trades$exit_session, trades$exit_open, pch = 25, bg = "#B44738", col = "white", cex = 0.9)
  graphics::mtext(
    sprintf("%d non-overlapping trades | blue/green = entry; red = exit", nrow(trades)),
    side = 3, line = 0.45, cex = 0.85, col = "#667386"
  )
}
grDevices::dev.off()

# Realized equity paths, explicitly separated from a normalized buy-and-hold reference.
equity_rows <- lapply(contract$primary_rules, function(rule_id) {
  nvpr_realized_equity_path(ledger, study$trades, rule_id)
})
equity <- do.call(rbind, equity_rows)
equity_path <- file.path(visual_dir, "nvda_proto_rule_equity_paths.png")
grDevices::png(equity_path, width = 2100, height = 1250, res = 180)
graphics::par(mar = c(6.0, 6.6, 6.0, 6.2), family = "sans", bg = "white")
date_range <- range(equity$session_date)
close_ref <- ledger[ledger$session_date >= date_range[[1L]] & ledger$session_date <= date_range[[2L]], ]
close_ref$normalized_close <- close_ref$close / close_ref$close[[1L]]
strategy_ylim <- range(equity$realized_equity)
graphics::plot(
  equity$session_date, equity$realized_equity, type = "n",
  xlim = date_range, ylim = strategy_ylim, xlab = "", ylab = "Realized strategy equity (start = 1)",
  main = "Two executable translations of the NVDA geometry clues",
  col.main = "#142033", cex.main = 1.5, bty = "n"
)
graphics::abline(h = 1, col = "#B8BCC4", lwd = 1)
for (rule_id in contract$primary_rules) {
  x <- equity[equity$rule_id == rule_id, ]
  graphics::lines(x$session_date, x$realized_equity, lwd = 3, col = rule_colors[[rule_id]])
}
graphics::par(new = TRUE)
graphics::plot(
  close_ref$session_date, close_ref$normalized_close, type = "l", axes = FALSE,
  xlab = "", ylab = "", lty = 3, lwd = 1.5, col = "#8A93A1",
  xlim = date_range, ylim = range(close_ref$normalized_close)
)
graphics::axis(4, las = 1, col.axis = "#6B7280")
graphics::mtext("Normalized NVDA close reference", side = 4, line = 4.2, col = "#6B7280")
graphics::legend(
  "topleft", bty = "n", lwd = c(3, 3, 1.5), lty = c(1, 1, 3),
  col = c(rule_colors, "#8A93A1"),
  legend = c(pretty_rule(contract$primary_rules), "NVDA buy-and-hold reference"), cex = 0.9
)
graphics::mtext(
  "Next-open entries | 20 open-to-open sessions | no overlap | 10 bps round trip | TRAIN only",
  side = 3, line = 1.0, cex = 0.92, col = "#667386"
)
grDevices::dev.off()

# Primary rules and their controls.
distribution_path <- file.path(visual_dir, "nvda_proto_rule_return_distributions.png")
grDevices::png(distribution_path, width = 2200, height = 1350, res = 180)
graphics::par(mfrow = c(1, 2), mar = c(12.0, 5.8, 5.0, 1.5), family = "sans", bg = "white")
for (family in contract$primary_rules) {
  x <- study$trades[study$trades$rule_family == family, , drop = FALSE]
  ids <- contract$rule_ids[nvpr_rule_family(contract$rule_ids) == family]
  values <- lapply(ids, function(id) 100 * x$net_open_log_return[x$rule_id == id])
  graphics::boxplot(
    values, names = pretty_rule(ids), las = 2, col = c(rule_colors[[family]], rep("#E4E7EC", 3)),
    border = "#667386", ylab = "Net 20-session open-to-open log return (%)",
    main = pretty_rule(family), col.main = "#142033", cex.main = 1.25, outline = FALSE
  )
  graphics::abline(h = 100 * unique(x$unconditional_open_log_return)[[1L]], col = "#B44738", lwd = 2, lty = 2)
  for (j in seq_along(ids)) {
    y <- values[[j]]
    jitter_x <- j + (((seq_along(y) * 37) %% 101) / 101 - 0.5) * 0.26
    graphics::points(jitter_x, y, pch = 16, cex = 0.55, col = grDevices::adjustcolor("#24364B", alpha.f = 0.45))
  }
  graphics::mtext("Dashed red = unconditional 20-session drift", side = 3, line = 0.5, cex = 0.8, col = "#B44738")
}
grDevices::dev.off()

# Calendar context for the two primary rules.
annual_primary <- calendar_summary[calendar_summary$rule_id %in% contract$primary_rules, ]
annual_path <- file.path(visual_dir, "nvda_proto_rule_annual_context.png")
grDevices::png(annual_path, width = 2000, height = 1200, res = 180)
graphics::par(mar = c(6.0, 6.5, 6.0, 2.0), family = "sans", bg = "white")
years <- sort(unique(annual_primary$entry_year))
annual_matrix <- sapply(contract$primary_rules, function(rule_id) {
  rows <- annual_primary[annual_primary$rule_id == rule_id, ]
  out <- setNames(rep(NA_real_, length(years)), years)
  out[as.character(rows$entry_year)] <- 100 * rows$mean_net_open_log_return
  out
})
counts_matrix <- sapply(contract$primary_rules, function(rule_id) {
  rows <- annual_primary[annual_primary$rule_id == rule_id, ]
  out <- setNames(rep(0L, length(years)), years)
  out[as.character(rows$entry_year)] <- rows$trades
  out
})
bp <- graphics::barplot(
  t(annual_matrix), beside = TRUE, col = unname(rule_colors), border = NA,
  names.arg = years, ylab = "Mean net trade log return (%)",
  main = "The apparent result is distributed unevenly through time",
  col.main = "#142033", cex.main = 1.45
)
graphics::abline(h = 0, col = "#667386")
for (i in seq_len(nrow(bp))) for (j in seq_len(ncol(bp))) {
  value <- t(annual_matrix)[i, j]
  if (is.finite(value)) graphics::text(bp[i, j], value, labels = paste0("n=", t(counts_matrix)[i, j]), pos = if (value >= 0) 3 else 1, cex = 0.75, col = "#344054")
}
graphics::legend("topleft", legend = pretty_rule(contract$primary_rules), fill = unname(rule_colors), bty = "n", cex = 0.9)
graphics::mtext("Annual means are context, not independent replications.", side = 3, line = 0.8, cex = 0.9, col = "#667386")
grDevices::dev.off()

# Worst, median-nearest, and best realized paths for each primary rule.
tapes_path <- file.path(visual_dir, "nvda_proto_rule_representative_tapes.png")
grDevices::png(tapes_path, width = 2200, height = 1400, res = 180)
graphics::par(mfrow = c(2, 3), mar = c(4.6, 5.0, 4.8, 1.2), family = "sans", bg = "white")
for (rule_id in contract$primary_rules) {
  trades <- study$trades[study$trades$rule_id == rule_id, , drop = FALSE]
  ordered <- trades[order(trades$net_open_log_return), , drop = FALSE]
  picks <- c(1L, which.min(abs(ordered$net_open_log_return - stats::median(ordered$net_open_log_return))), nrow(ordered))
  labels <- c("Worst", "Median-nearest", "Best")
  for (j in seq_along(picks)) {
    trade <- ordered[picks[[j]], ]
    held <- trade$entry_index:trade$exit_index
    y <- 100 * log(ledger$open[held] / trade$entry_open)
    graphics::plot(
      0:contract$hold_sessions, y, type = "l", lwd = 2.5, col = rule_colors[[rule_id]],
      xlab = "Held sessions", ylab = "Open-path log return (%)", bty = "n",
      main = paste(pretty_rule(rule_id), labels[[j]], sep = " | "), cex.main = 1.05, col.main = "#142033"
    )
    graphics::abline(h = 0, col = "#B8BCC4")
    graphics::points(contract$hold_sessions, tail(y, 1L), pch = 16, col = "#B44738")
    graphics::mtext(
      sprintf("Entry %s | net %.1f%%", trade$entry_session, 100 * trade$net_open_log_return),
      side = 3, line = 0.45, cex = 0.72, col = "#667386"
    )
  }
}
grDevices::dev.off()

run_spec <- data.frame(
  field = c(
    "study_id", "symbol", "analysis_start", "analysis_end", "confirmation_boundary",
    "prior_return", "continuation_signal", "rebound_signal", "entry", "exit",
    "overlap", "round_trip_cost_bps", "baseline", "research_status"
  ),
  value = c(
    contract$study_id, contract$symbol, as.character(contract$analysis_start),
    as.character(contract$analysis_end), "2024+ sealed and unread",
    "20-session close-to-close log return known at close t",
    "R20 > 0 and ER20 >= 0.30 at close t",
    "R20 < 0 and ATR% trailing state is LOW or MEDIUM at close t",
    "next regular-session open t+1", "regular-session open t+21",
    "no overlapping positions within each rule", as.character(contract$round_trip_cost_bps),
    "unconditional overlapping 20-session open-to-open log-return drift",
    "TRAIN translation only; no edge authority"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(construction_checks, file.path(run_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(rule_summary, file.path(run_dir, "rule_summary.csv"), row.names = FALSE)
utils::write.csv(calendar_summary, file.path(run_dir, "calendar_summary.csv"), row.names = FALSE)
utils::write.csv(condition_summary, file.path(run_dir, "condition_summary.csv"), row.names = FALSE)
utils::write.csv(study$trades, file.path(run_dir, "trade_ledger.csv"), row.names = FALSE)
utils::write.csv(trade_paths, file.path(run_dir, "trade_paths.csv"), row.names = FALSE)

primary_lines <- unlist(lapply(seq_len(nrow(primary)), function(i) {
  sprintf(
    "- %s: %d trades; mean net %.2f%%; median net %.2f%%; P(net > 0) %.1f%%; mean excess vs unconditional drift %.2f%%.",
    pretty_rule(primary$rule_id[[i]]), primary$trades[[i]],
    100 * primary$mean_net_open_log_return[[i]],
    100 * primary$median_net_open_log_return[[i]],
    100 * primary$probability_profitable_net[[i]],
    100 * primary$mean_net_excess_vs_unconditional[[i]]
  )
}))
report <- c(
  "# NVDA Daily Proto-Rule Translation",
  "",
  "Two descriptive 20/20 return-geometry clues are translated into executable",
  "next-open rules on the same frozen 2018-2023 NVDA research period.",
  "This is a construction and TRAIN diagnostic, not confirmation evidence.",
  "",
  "## Frozen rules",
  "",
  "- Efficient-up continuation: R20 > 0 and ER20 >= 0.30 at close t.",
  "- Calm-pullback rebound: R20 < 0 and ATR% state LOW or MEDIUM at close t.",
  "- Enter next open; exit 20 open-to-open sessions later; no overlap; 10 bps round trip.",
  "",
  "## Primary readout",
  "",
  primary_lines,
  "",
  sprintf("- Unconditional 20-session open-to-open gross drift: %.2f%%.", 100 * primary$unconditional_open_log_return[[1L]]),
  "",
  "## Interpretation boundary",
  "",
  "Efficient-up continuation does not clear this TRAIN translation gate: it trails",
  "unconditional drift and each simple continuation control. Calm-pullback rebound",
  "does clear the narrow TRAIN translation gate: its mean and median exceed drift,",
  "and the joint sign-plus-state rule is stronger than either ingredient alone and",
  "than the same calm state after positive R20. This is a candidate for confirmation,",
  "not an edge claim.",
  "",
  "A rule beating unconditional drift in this packet would show that the close-to-close",
  "geometry survived an executable timing translation inside TRAIN. It would not show",
  "that the rule generalizes. A weak or control-dominated result is still informative:",
  "it identifies which part of the descriptive state split did not survive execution.",
  "The 2024+ confirmation period remains sealed.",
  "",
  "## Artifacts",
  "",
  "- `rule_summary.csv`",
  "- `calendar_summary.csv`",
  "- `condition_summary.csv`",
  "- `trade_ledger.csv`",
  "- `trade_paths.csv`",
  "- `construction_checks.csv`",
  "- `run_spec.csv`",
  "- `visuals/nvda_proto_rule_price_entries.png`",
  "- `visuals/nvda_proto_rule_equity_paths.png`",
  "- `visuals/nvda_proto_rule_return_distributions.png`",
  "- `visuals/nvda_proto_rule_annual_context.png`",
  "- `visuals/nvda_proto_rule_representative_tapes.png`"
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("NVDA daily proto-rule slice complete")
message("Primary rules: ", paste(sprintf("%s=%d trades", primary$rule_id, primary$trades), collapse = " | "))
message("Summary: ", file.path(run_dir, "rule_summary.csv"))
message("Report: ", file.path(run_dir, "report.md"))
