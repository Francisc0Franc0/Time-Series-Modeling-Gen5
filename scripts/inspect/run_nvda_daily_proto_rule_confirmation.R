# One-shot untouched confirmation of the frozen NVDA calm-pullback rebound rule.
# The rule, controls, timing, cost, pass gates, and 2024-01-02 through 2026-06-23
# window are declared in code before outcomes are read.

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
for (file in c(
  "data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R",
  "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R"
)) source(file.path(repo_root, "R", file))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_direction.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "own_asset_return_geometry_atlas.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_nvda_daily_proto_rules.R"))
g5_load_local_renviron(repo_root)

contract <- nvpr_validate_contract(nvpr_confirmation_contract())
train_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_daily_proto_rules_20260831"
)
run_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "nvda_daily_proto_rule_confirmation_20260831"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

train_summary_path <- file.path(train_dir, "rule_summary.csv")
required <- train_summary_path
if (any(!file.exists(required))) {
  stop("Missing frozen TRAIN summary: ", paste(required[!file.exists(required)], collapse = ", "), call. = FALSE)
}

# This is the first outcome read for the predeclared confirmation window.
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- "sip"
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = as.Date("2016-01-04"),
  end_date = contract$analysis_end,
  as_of_timestamp = "2026-06-23 17:30:00 America/New_York",
  symbols = contract$symbol,
  universe_name = "nvda_rebound_one_shot_confirmation",
  universe_roles = "single_asset_frozen_confirmation",
  refresh = identical(tolower(Sys.getenv("GEN5_NVDA_CONFIRM_REFRESH", "false")), "true"),
  repo_root = repo_root
)
bars <- query$bars
if (g5_health_max_severity(query$health) %in% c("WARN", "ERROR")) {
  stop(
    "Confirmation data health is not clean: ",
    paste(query$health$code[query$health$severity %in% c("WARN", "ERROR")], collapse = ", "),
    call. = FALSE
  )
}
state_contract <- oarga_contract()
state_contract$analysis_end <- contract$analysis_end
ledger <- oarga_build_ledger(bars, contract$symbol, state_contract)
study <- nvpr_build_study(ledger, contract)
rule_summary <- nvpr_rule_summary(study$trades, contract)
calendar_summary <- nvpr_calendar_summary(study$trades)
condition_summary <- nvpr_condition_summary(study$candidates)
trade_paths <- nvpr_trade_paths(ledger, study$trades)
gate <- nvpr_confirmation_gate(rule_summary, contract)

primary_id <- contract$primary_rules[[1L]]
primary_trades <- study$trades[study$trades$rule_id == primary_id, , drop = FALSE]
primary_summary <- rule_summary[rule_summary$rule_id == primary_id, , drop = FALSE]
control_summary <- rule_summary[rule_summary$rule_id != primary_id, , drop = FALSE]
train_summary <- utils::read.csv(train_summary_path, stringsAsFactors = FALSE)
train_summary <- train_summary[train_summary$rule_id %in% contract$rule_ids, , drop = FALSE]

construction_checks <- data.frame(
  check_id = c(
    "explicit_as_of_query", "frozen_train_summary", "exact_symbol", "adjusted_daily_bars",
    "sip_feed_requested", "clean_data_health",
    "unique_ordered_sessions", "confirmation_window_exact", "prior_history_precedes_oos",
    "single_primary_rule", "rule_ingredients_frozen", "next_open_entry", "fixed_open_exit",
    "cost_fixed", "nonoverlap", "gate_count_fixed", "continuation_not_reopened"
  ),
  passed = c(
    identical(as.character(query$manifest$as_of_timestamp[[1L]]), "2026-06-23 17:30:00"),
    file.exists(train_summary_path),
    identical(unique(as.character(ledger$symbol)), contract$symbol),
    all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
    identical(as.character(query$manifest$feed[[1L]]), "sip"),
    identical(g5_health_max_severity(query$health), "INFO"),
    !anyDuplicated(ledger$session_date) && all(diff(ledger$session_date) > 0),
    min(study$candidates$anchor_session) >= contract$analysis_start &&
      max(study$candidates$exit_session) <= contract$analysis_end,
    min(ledger$session_date) < contract$analysis_start,
    identical(contract$primary_rules, primary_id),
    identical(contract$rebound_atrp_states, c("LOW", "MEDIUM")) &&
      identical(contract$prior_sessions, 20L),
    all(study$candidates$entry_index == study$candidates$anchor_index + 1L),
    all(study$candidates$exit_index == study$candidates$entry_index + 20L),
    identical(contract$round_trip_cost_bps, 10),
    nrow(primary_trades) < 2L ||
      all(primary_trades$entry_index[-1L] > primary_trades$exit_index[-nrow(primary_trades)]),
    nrow(gate$checks) == 5L,
    !"EFFICIENT_UP_CONTINUATION" %in% contract$rule_ids
  ),
  observed = c(
    as.character(query$manifest$as_of_timestamp[[1L]]),
    normalizePath(train_summary_path, winslash = "/"),
    paste(unique(ledger$symbol), collapse = ","),
    paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
    as.character(query$manifest$feed[[1L]]),
    g5_health_max_severity(query$health),
    paste(min(ledger$session_date), max(ledger$session_date), sep = " to "),
    paste(min(study$candidates$anchor_session), max(study$candidates$exit_session), sep = " to "),
    as.character(min(ledger$session_date)), primary_id,
    "R20<0; ATR%=LOW|MEDIUM; prior=20", "close t -> open t+1",
    "open t+1 -> open t+21", "10 bps round trip",
    paste(nrow(primary_trades), "trades"), paste(nrow(gate$checks), "gates"),
    paste(contract$rule_ids, collapse = ",")
  ),
  stringsAsFactors = FALSE
)
if (!all(construction_checks$passed)) {
  stop("NVDA confirmation construction checks failed: ",
       paste(construction_checks$check_id[!construction_checks$passed], collapse = ", "),
       call. = FALSE)
}

pretty_rule <- function(x) {
  labels <- c(
    NOT_HIGH_ATR_LOSS_REBOUND = "Calm-pullback rebound",
    NEGATIVE_R20_ONLY = "Negative R20 only",
    NOT_HIGH_ATR_STATE_ONLY = "Low/medium ATR state only",
    NOT_HIGH_ATR_POSITIVE_OPPOSITE = "Calm positive opposite"
  )
  unname(labels[x])
}

# TRAIN versus confirmation means for the primary rule and frozen controls.
comparison <- rbind(
  data.frame(sample_role = "TRAIN", train_summary, stringsAsFactors = FALSE),
  data.frame(sample_role = "CONFIRMATION", rule_summary, stringsAsFactors = FALSE)
)
comparison$rule_label <- pretty_rule(comparison$rule_id)
comparison$mean_net_return_pct <- 100 * comparison$mean_net_open_log_return
comparison$median_net_return_pct <- 100 * comparison$median_net_open_log_return
comparison$drift_pct <- 100 * comparison$unconditional_open_log_return

comparison_path <- file.path(visual_dir, "nvda_rebound_train_confirmation_controls.png")
grDevices::png(comparison_path, width = 2200, height = 1300, res = 180)
graphics::par(mar = c(11.0, 6.4, 6.2, 2.0), family = "sans", bg = "white")
rule_order <- contract$rule_ids
value_matrix <- sapply(c("TRAIN", "CONFIRMATION"), function(role) {
  rows <- comparison[comparison$sample_role == role, ]
  setNames(rows$mean_net_return_pct, rows$rule_id)[rule_order]
})
bp <- graphics::barplot(
  t(value_matrix), beside = TRUE, col = c("#98A2B3", "#14866D"), border = NA,
  names.arg = pretty_rule(rule_order), las = 2,
  ylab = "Mean net 20-session open-to-open log return (%)",
  main = "The frozen rebound rule: TRAIN versus untouched confirmation",
  col.main = "#142033", cex.main = 1.45,
  ylim = c(min(0, min(value_matrix)) * 1.15, max(value_matrix) * 1.38)
)
graphics::abline(h = 0, col = "#667386")
graphics::abline(h = unique(comparison$drift_pct[comparison$sample_role == "TRAIN"]), col = "#98A2B3", lty = 2, lwd = 2)
graphics::abline(h = unique(comparison$drift_pct[comparison$sample_role == "CONFIRMATION"]), col = "#14866D", lty = 3, lwd = 2)
graphics::legend(
  "topright", legend = c("TRAIN rules", "Confirmation rules", "TRAIN drift", "Confirmation drift"),
  fill = c("#98A2B3", "#14866D", NA, NA), border = NA,
  lty = c(NA, NA, 2, 3), lwd = c(NA, NA, 2, 2),
  col = c(NA, NA, "#98A2B3", "#14866D"), bty = "n", cex = 0.86
)
for (i in seq_len(nrow(bp))) for (j in seq_len(ncol(bp))) {
  value <- t(value_matrix)[i, j]
  graphics::text(bp[i, j], value, labels = sprintf("%.1f", value), pos = if (value >= 0) 3 else 1, cex = 0.78, col = "#344054")
}
graphics::mtext(
  sprintf("Frozen confirmation verdict: %s", gate$verdict),
  side = 3, line = 1.0, cex = 0.95,
  col = if (gate$verdict == "CONFIRMED_ON_FROZEN_OOS") "#14866D" else "#B44738"
)
grDevices::dev.off()

# Confirmation price participation.
price_path <- file.path(visual_dir, "nvda_rebound_confirmation_price_trades.png")
grDevices::png(price_path, width = 2100, height = 1200, res = 180)
graphics::par(mar = c(6.0, 6.4, 6.0, 2.0), family = "sans", bg = "white")
visible <- ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end
graphics::plot(
  ledger$session_date[visible], ledger$close[visible], type = "l", lwd = 1.6,
  col = "#24364B", xlab = "", ylab = "Adjusted close",
  main = "Untouched confirmation participation",
  col.main = "#142033", cex.main = 1.5, bty = "n"
)
usr <- graphics::par("usr")
for (i in seq_len(nrow(primary_trades))) {
  graphics::rect(
    primary_trades$entry_session[[i]], usr[[3L]], primary_trades$exit_session[[i]], usr[[4L]],
    col = grDevices::adjustcolor("#14866D", alpha.f = 0.12), border = NA
  )
}
graphics::lines(ledger$session_date[visible], ledger$close[visible], lwd = 1.6, col = "#24364B")
graphics::points(primary_trades$entry_session, primary_trades$entry_open, pch = 24, bg = "#14866D", col = "white", cex = 1.15)
graphics::points(primary_trades$exit_session, primary_trades$exit_open, pch = 25, bg = "#B44738", col = "white", cex = 1.15)
graphics::mtext(
  sprintf("%d non-overlapping trades | green = entry; red = exit | 2024-01-02 through 2026-06-23", nrow(primary_trades)),
  side = 3, line = 1.0, cex = 0.9, col = "#667386"
)
grDevices::dev.off()

# Realized confirmation equity versus a separate normalized price reference.
equity <- nvpr_realized_equity_path(ledger, primary_trades, primary_id)
equity_path <- file.path(visual_dir, "nvda_rebound_confirmation_equity.png")
grDevices::png(equity_path, width = 2100, height = 1200, res = 180)
graphics::par(mar = c(6.0, 6.6, 6.0, 6.2), family = "sans", bg = "white")
date_range <- range(equity$session_date)
close_ref <- ledger[ledger$session_date >= date_range[[1L]] & ledger$session_date <= date_range[[2L]], ]
close_ref$normalized_close <- close_ref$close / close_ref$close[[1L]]
graphics::plot(
  equity$session_date, equity$realized_equity, type = "l", lwd = 3.2, col = "#14866D",
  xlab = "", ylab = "Realized rule equity (start = 1)", bty = "n",
  main = "Frozen rebound rule in untouched time", col.main = "#142033", cex.main = 1.5
)
graphics::abline(h = 1, col = "#B8BCC4")
graphics::par(new = TRUE)
graphics::plot(
  close_ref$session_date, close_ref$normalized_close, type = "l", axes = FALSE,
  xlab = "", ylab = "", lty = 3, lwd = 1.6, col = "#8A93A1",
  xlim = date_range, ylim = range(close_ref$normalized_close)
)
graphics::axis(4, las = 1, col.axis = "#6B7280")
graphics::mtext("Normalized NVDA close reference", side = 4, line = 4.2, col = "#6B7280")
graphics::legend(
  "topleft", legend = c("Realized rebound equity", "NVDA close reference"),
  col = c("#14866D", "#8A93A1"), lwd = c(3.2, 1.6), lty = c(1, 3), bty = "n"
)
graphics::mtext(
  "Next-open entry | 20 open-to-open sessions | no overlap | 10 bps round trip",
  side = 3, line = 1.0, cex = 0.9, col = "#667386"
)
grDevices::dev.off()

# Every confirmation trade return in chronological order.
trade_return_path <- file.path(visual_dir, "nvda_rebound_confirmation_trade_returns.png")
grDevices::png(trade_return_path, width = 2100, height = 1200, res = 180)
graphics::par(mar = c(8.0, 6.4, 6.0, 2.0), family = "sans", bg = "white")
trade_pct <- 100 * primary_trades$net_open_log_return
bar_colors <- ifelse(trade_pct > 0, "#14866D", "#B44738")
bp_trade <- graphics::barplot(
  trade_pct, names.arg = format(primary_trades$entry_session, "%Y-%m-%d"), las = 2,
  col = bar_colors, border = NA, ylab = "Net open-to-open log return (%)",
  main = "Every confirmation trade, in the order it occurred",
  col.main = "#142033", cex.main = 1.45
)
graphics::abline(h = 0, col = "#667386")
graphics::abline(h = 100 * primary_summary$unconditional_open_log_return, col = "#A86B00", lty = 2, lwd = 2)
graphics::text(bp_trade, trade_pct, labels = sprintf("%.1f", trade_pct), pos = ifelse(trade_pct >= 0, 3, 1), cex = 0.8, col = "#344054")
graphics::mtext("Dashed amber = unconditional confirmation-period 20-session drift", side = 3, line = 0.8, cex = 0.9, col = "#A86B00")
grDevices::dev.off()

# All paths plus representative paths.
primary_paths <- trade_paths[trade_paths$rule_id == primary_id, , drop = FALSE]
tapes_path <- file.path(visual_dir, "nvda_rebound_confirmation_trade_tapes.png")
grDevices::png(tapes_path, width = 2200, height = 1300, res = 180)
graphics::par(mfrow = c(1, 2), mar = c(6.0, 6.0, 6.0, 1.6), family = "sans", bg = "white")
graphics::plot(
  NA, xlim = c(0, contract$hold_sessions),
  ylim = 100 * range(primary_paths$cumulative_open_log_return),
  xlab = "Held sessions", ylab = "Open-path log return (%)", bty = "n",
  main = "All confirmation paths", col.main = "#142033", cex.main = 1.25
)
graphics::abline(h = 0, col = "#B8BCC4")
for (entry in unique(primary_paths$entry_session)) {
  x <- primary_paths[primary_paths$entry_session == entry, ]
  graphics::lines(x$held_session, 100 * x$cumulative_open_log_return, col = grDevices::adjustcolor("#14866D", alpha.f = 0.35), lwd = 1.5)
}
ordered <- primary_trades[order(primary_trades$net_open_log_return), , drop = FALSE]
picks <- c(1L, which.min(abs(ordered$net_open_log_return - stats::median(ordered$net_open_log_return))), nrow(ordered))
labels <- c("Worst", "Median-nearest", "Best")
colors <- c("#B44738", "#A86B00", "#14866D")
graphics::plot(
  NA, xlim = c(0, contract$hold_sessions),
  ylim = 100 * range(primary_paths$cumulative_open_log_return),
  xlab = "Held sessions", ylab = "Open-path log return (%)", bty = "n",
  main = "Representative confirmation paths", col.main = "#142033", cex.main = 1.25
)
graphics::abline(h = 0, col = "#B8BCC4")
for (j in seq_along(picks)) {
  trade <- ordered[picks[[j]], ]
  x <- primary_paths[primary_paths$entry_session == trade$entry_session, ]
  graphics::lines(x$held_session, 100 * x$cumulative_open_log_return, col = colors[[j]], lwd = 2.8)
}
graphics::legend(
  "topleft", legend = sprintf("%s | %+.1f%%", labels, 100 * ordered$net_open_log_return[picks]),
  col = colors, lwd = 2.8, bty = "n", cex = 0.88
)
grDevices::dev.off()

run_spec <- data.frame(
  field = c(
    "study_id", "sample_role", "symbol", "analysis_start", "analysis_end",
    "source_as_of_timestamp", "frozen_rule", "entry", "exit", "overlap",
    "round_trip_cost_bps", "baseline", "minimum_trades", "confirmation_gates",
    "verdict"
  ),
  value = c(
    contract$study_id, contract$sample_role, contract$symbol,
    as.character(contract$analysis_start), as.character(contract$analysis_end),
    "2026-06-23 17:30:00 America/New_York",
    "R20 < 0 and trailing ATR% state LOW or MEDIUM at close t",
    "next regular-session open t+1", "regular-session open t+21",
    "no overlapping positions", as.character(contract$round_trip_cost_bps),
    "unconditional overlapping 20-session open-to-open gross log-return drift",
    as.character(contract$minimum_confirmation_trades),
    "minimum trades; mean beats drift; positive median; majority profitable; mean beats every ingredient control",
    gate$verdict
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(construction_checks, file.path(run_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(query$manifest, file.path(run_dir, "query_manifest.csv"), row.names = FALSE)
utils::write.csv(query$audit, file.path(run_dir, "query_audit.csv"), row.names = FALSE)
utils::write.csv(query$symbol_coverage, file.path(run_dir, "query_symbol_coverage.csv"), row.names = FALSE)
utils::write.csv(query$health, file.path(run_dir, "query_health.csv"), row.names = FALSE)
utils::write.csv(query$refresh_plan, file.path(run_dir, "query_refresh_plan.csv"), row.names = FALSE)
utils::write.csv(gate$checks, file.path(run_dir, "confirmation_gates.csv"), row.names = FALSE)
utils::write.csv(rule_summary, file.path(run_dir, "rule_summary.csv"), row.names = FALSE)
utils::write.csv(comparison, file.path(run_dir, "train_confirmation_comparison.csv"), row.names = FALSE)
utils::write.csv(calendar_summary, file.path(run_dir, "calendar_summary.csv"), row.names = FALSE)
utils::write.csv(condition_summary, file.path(run_dir, "condition_summary.csv"), row.names = FALSE)
utils::write.csv(primary_trades, file.path(run_dir, "confirmation_trade_ledger.csv"), row.names = FALSE)
utils::write.csv(primary_paths, file.path(run_dir, "confirmation_trade_paths.csv"), row.names = FALSE)

gate_lines <- sprintf(
  "- %s: `%s` (%s)", gate$checks$gate_id,
  ifelse(gate$checks$passed, "PASS", "FAIL"), gate$checks$observed
)
report <- c(
  "# NVDA Calm-Pullback Rebound: One-Shot Confirmation",
  "",
  paste0("Verdict: `", gate$verdict, "`"),
  "",
  "The exact TRAIN-selected rule was read once on the previously untouched",
  "2024-01-02 through 2026-06-23 period. No threshold, state, timing, holding",
  "period, overlap rule, cost, control, or gate changed after outcomes were opened.",
  "",
  "## Frozen rule",
  "",
  "- At close t: R20 < 0 and trailing ATR% state is LOW or MEDIUM.",
  "- Enter next open; exit open t+21; no overlap; 10 bps round trip.",
  "",
  "## Readout",
  "",
  sprintf("- Trades: `%d`", primary_summary$trades),
  sprintf("- Mean net return: `%.2f%%`", 100 * primary_summary$mean_net_open_log_return),
  sprintf("- Median net return: `%.2f%%`", 100 * primary_summary$median_net_open_log_return),
  sprintf("- Probability profitable: `%.1f%%`", 100 * primary_summary$probability_profitable_net),
  sprintf("- Mean excess versus unconditional drift: `%+.2f percentage points`", 100 * primary_summary$mean_net_excess_vs_unconditional),
  "",
  "## Predeclared gates",
  "",
  gate_lines,
  "",
  "## Interpretation boundary",
  "",
  "Passing confirms temporal replication of this exact one-asset rule on this",
  "specific frozen period. It does not establish portfolio value, risk-adjusted",
  "superiority, nearby-parameter robustness, cross-asset generalization, or live",
  "authority. Failing stops the exact rule without rescue tuning.",
  "",
  "## Artifacts",
  "",
  "- `confirmation_gates.csv`",
  "- `rule_summary.csv`",
  "- `train_confirmation_comparison.csv`",
  "- `calendar_summary.csv`",
  "- `condition_summary.csv`",
  "- `confirmation_trade_ledger.csv`",
  "- `confirmation_trade_paths.csv`",
  "- `construction_checks.csv`",
  "- `run_spec.csv`",
  "- `query_manifest.csv`",
  "- `query_audit.csv`",
  "- `query_symbol_coverage.csv`",
  "- `query_health.csv`",
  "- `query_refresh_plan.csv`",
  "- `visuals/nvda_rebound_train_confirmation_controls.png`",
  "- `visuals/nvda_rebound_confirmation_price_trades.png`",
  "- `visuals/nvda_rebound_confirmation_equity.png`",
  "- `visuals/nvda_rebound_confirmation_trade_returns.png`",
  "- `visuals/nvda_rebound_confirmation_trade_tapes.png`"
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("NVDA rebound confirmation complete")
message("Verdict: ", gate$verdict)
message("Trades: ", primary_summary$trades)
message("Report: ", file.path(run_dir, "report.md"))
