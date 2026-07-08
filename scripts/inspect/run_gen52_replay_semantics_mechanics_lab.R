# Gen5.2 replay-semantics mechanics lab.
#
# This is a small synthetic inspection packet. It proves mechanics only; it is
# not evidence for allocation, symbol choice, or expected performance.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "strategy_ema_cross.R"))
source(file.path(repo_root, "R", "strategy_bollinger_touch.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_poc.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))
source(file.path(repo_root, "R", "selection_policy_screen.R"))

stamp <- Sys.getenv("GEN5_REPLAY_SEMANTICS_LAB_STAMP", unset = "20260708")
stamp <- gsub("[^0-9A-Za-z]+", "", as.character(stamp)[[1L]])
if (!nzchar(stamp)) g5_stop("GEN5_REPLAY_SEMANTICS_LAB_STAMP must produce a non-empty artifact stamp.")
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen52_mechanics", paste0("replay_semantics_mechanics_lab_", stamp))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

synthetic_bars <- function() {
  dates <- as.Date("2025-12-29") + 0:9
  close <- c(10, 9, 8, 12, 13, 14, 15, 16, 17, 18)
  data.frame(
    symbol = "AAA",
    session_date = dates,
    open = close + 0.1,
    high = close + 1,
    low = close - 1,
    close = close,
    volume = seq_along(close) * 100,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "fixture",
    as_of_timestamp = "2026-01-07 17:30:00",
    latest_completed_session = max(dates),
    fetch_start_date = min(dates),
    fetch_end_date = max(dates),
    data_version_hash = paste0("fixture_", seq_along(close)),
    stringsAsFactors = FALSE
  )
}

synthetic_contract <- function() {
  g5_bridge_contract_frame(
    quarter_id = "2026Q1",
    symbols = "AAA",
    context_symbols = "AAA",
    as_of_timestamp = "2026-01-07 17:30:00",
    refresh = FALSE
  )
}

selected_state_rows <- function(route = c("state_switch", "fold_asset_proxy")) {
  route <- match.arg(route)
  grid <- g5_wfa_candidate_model_grid(
    fast_periods = 1L,
    slow_periods = 3L,
    candidate_families = c("ema_cross", "no_trade")
  )
  no_trade <- grid[grid$strategy_family == "no_trade", , drop = FALSE][1L, , drop = FALSE]
  no_trade$symbol <- "AAA"
  no_trade$quarter_id <- "2026Q1"
  no_trade$state_id <- "S1_1"
  no_trade$exit_stack_id <- "no_exit"
  no_trade$strategy_spec_id <- "no_trade__no_exit"
  ema <- grid[grid$strategy_family == "ema_cross", , drop = FALSE][1L, , drop = FALSE]
  ema$symbol <- "AAA"
  ema$quarter_id <- "2026Q1"
  ema$state_id <- "S2_1"
  ema$exit_stack_id <- "native_only"
  ema$strategy_spec_id <- paste0(ema$model_instance_id[[1L]], "__native_only")
  if (identical(route, "fold_asset_proxy")) {
    ema_s1 <- ema
    ema_s1$state_id <- "S1_1"
    return(g5_wfa_bind_rows_fill(list(ema_s1, ema)))
  }
  g5_wfa_bind_rows_fill(list(no_trade, ema))
}

synthetic_scored <- function(bars) {
  data.frame(
    symbol = "AAA",
    session_date = as.Date(bars$session_date),
    state_id = ifelse(as.Date(bars$session_date) <= as.Date("2026-01-01"), "S1_1", "S2_1"),
    stringsAsFactors = FALSE
  )
}

policy_perf_fixture <- function() {
  data.frame(
    symbol = rep(c("AAA", "BBB"), each = 3L),
    quarter_id = "2026Q1",
    state_id = "S2_1",
    strategy_family = rep(c("no_trade", "ema_cross", "rsi_mr"), times = 2L),
    model_instance_id = c("no_trade", "aaa_ema", "aaa_rsi", "no_trade", "bbb_ema", "bbb_rsi"),
    exit_stack_id = c("no_exit", "native_only", "native_only", "no_exit", "native_only", "native_only"),
    strategy_spec_id = c("aaa_no_trade", "aaa_ema", "aaa_rsi", "bbb_no_trade", "bbb_ema", "bbb_rsi"),
    sharpe = c(0, 2.1, 0.4, 0, 1.7, 0.2),
    total_return = c(0, 0.18, 0.03, 0, 0.11, 0.02),
    train_state_row_count = 50L,
    train_state_trade_count = c(0L, 6L, 5L, 0L, 1L, 5L),
    stringsAsFactors = FALSE
  )
}

replay_case <- function(case_id, selected_states, entry_replay_semantics) {
  bars <- synthetic_bars()
  contract <- synthetic_contract()
  scored <- synthetic_scored(bars)
  out <- g5_bridge_replay_symbol(
    bars,
    "AAA",
    scored,
    selected_states,
    contract,
    replay_start_date = as.Date("2025-12-31"),
    entry_signal_start_date = as.Date("2025-12-31"),
    entry_signal_end_date = as.Date("2026-01-07"),
    entry_replay_semantics = entry_replay_semantics,
    authority_role = paste0("synthetic_", case_id)
  )
  for (field in c("replay", "executions", "trades", "pending_actions")) {
    if (is.data.frame(out[[field]]) && nrow(out[[field]])) {
      out[[field]]$case_id <- case_id
    }
  }
  out
}

perf <- policy_perf_fixture()
strict <- g5_selection_policy_pooled_family_asset_variant(perf, min_train_state_rows = 20L)
fallback <- g5_selection_policy_pooled_family_asset_variant_state_fallback(perf, min_train_state_rows = 20L)

fresh <- replay_case("fresh_signal_only", selected_state_rows("state_switch"), "fresh_signal_only")
continuation <- replay_case("state_switch_continuation", selected_state_rows("state_switch"), "state_switch_continuation")
fold_proxy <- replay_case("fold_asset_authority_proxy", selected_state_rows("fold_asset_proxy"), "fresh_signal_only")

truth <- data.frame(
  probe = c(
    "strict_pooled_family_missing_asset_variant",
    "fallback_pooled_family_missing_asset_variant",
    "fresh_signal_only_after_stale_cross",
    "state_switch_continuation_after_stale_cross",
    "fold_asset_authority_proxy"
  ),
  expected = c(
    "BBB becomes no_trade because its ema_cross variant has too few TRAIN trades.",
    "BBB borrows the state-leading ema_cross variant instead of becoming no_trade.",
    "No entry after the route changes because the EMA cross already happened.",
    "Entry is emitted when the route switches into an already-active trend state.",
    "Entry is caught at the original cross because EMA authority is active before the cross."
  ),
  observed = c(
    strict$strategy_family[strict$symbol == "BBB"][[1L]],
    paste(fallback$strategy_family[fallback$symbol == "BBB"][[1L]], fallback$fallback_source_symbol[fallback$symbol == "BBB"][[1L]], sep = " from "),
    paste0(nrow(fresh$executions), " executions"),
    paste0(nrow(continuation$executions), " executions; first trigger=", continuation$replay$entry_trigger_type[continuation$replay$signal_status == "ENTER_LONG_NEXT_OPEN"][[1L]]),
    paste0(nrow(fold_proxy$executions), " executions; first execution=", as.character(as.Date(fold_proxy$executions$execution_date[[1L]])))
  ),
  pass = c(
    identical(strict$strategy_family[strict$symbol == "BBB"][[1L]], "no_trade"),
    identical(fallback$strategy_family[fallback$symbol == "BBB"][[1L]], "ema_cross") && identical(fallback$fallback_source_symbol[fallback$symbol == "BBB"][[1L]], "AAA"),
    nrow(fresh$executions) == 0L,
    nrow(continuation$executions) == 1L,
    nrow(fold_proxy$executions) == 1L
  ),
  stringsAsFactors = FALSE
)

replays <- g5_wfa_bind_rows_fill(list(fresh$replay, continuation$replay, fold_proxy$replay))
executions <- g5_wfa_bind_rows_fill(list(fresh$executions, continuation$executions, fold_proxy$executions))
selected_index <- g5_wfa_bind_rows_fill(list(
  transform(strict, case_id = "strict_pooled_family"),
  transform(fallback, case_id = "fallback_pooled_family")
))

g5_wfa_write_csv(truth, file.path(output_dir, "mechanics_truth_table.csv"))
g5_wfa_write_csv(replays, file.path(output_dir, "synthetic_replay_events.csv"))
g5_wfa_write_csv(executions, file.path(output_dir, "synthetic_executions.csv"))
g5_wfa_write_csv(selected_index, file.path(output_dir, "synthetic_policy_selected_states.csv"))

png_path <- file.path(output_dir, "synthetic_replay_timeline.png")
aesthetic <- g5_chart_aesthetic()
grDevices::png(png_path, width = 2200L, height = 1300L, res = 180L)
oldpar <- graphics::par(no.readonly = TRUE)
on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
graphics::par(bg = aesthetic$background, mar = c(6, 5, 4, 2))
bars <- synthetic_bars()
x <- seq_len(nrow(bars))
graphics::plot(
  x,
  bars$close,
  type = "l",
  lwd = 2.5,
  col = "#222222",
  xaxt = "n",
  xlab = "",
  ylab = "Synthetic close",
  main = "Synthetic Replay Semantics: stale EMA cross plus later state switch"
)
graphics::axis(1, at = x, labels = as.character(as.Date(bars$session_date)), las = 2, cex.axis = 0.72)
graphics::abline(v = which(as.Date(bars$session_date) == as.Date("2026-01-01")), col = "#777777", lty = 3)
graphics::abline(v = which(as.Date(bars$session_date) == as.Date("2026-01-02")), col = "#1B9AAA", lty = 3)
graphics::text(which(as.Date(bars$session_date) == as.Date("2026-01-01")), max(bars$close), "EMA cross", pos = 4, cex = 0.8)
graphics::text(which(as.Date(bars$session_date) == as.Date("2026-01-02")), max(bars$close) - 0.8, "state route switches", pos = 4, cex = 0.8, col = "#1B9AAA")
if (nrow(executions)) {
  colors <- c(
    state_switch_continuation = "#F46036",
    fold_asset_authority_proxy = "#2E7D32"
  )
  for (i in seq_len(nrow(executions))) {
    idx <- match(as.Date(executions$execution_date[[i]]), as.Date(bars$session_date))
    if (!is.na(idx)) {
      graphics::points(idx, bars$open[[idx]], pch = 24, bg = colors[executions$case_id[[i]]], col = "#111111", cex = 1.4)
      graphics::text(idx, bars$open[[idx]], executions$case_id[[i]], pos = 3, cex = 0.7, col = colors[executions$case_id[[i]]])
    }
  }
}
graphics::legend(
  "topleft",
  legend = c("Close", "Fold-asset proxy entry", "State-switch continuation entry"),
  col = c("#222222", "#2E7D32", "#F46036"),
  lwd = c(2.5, NA, NA),
  pch = c(NA, 24, 24),
  pt.bg = c(NA, "#2E7D32", "#F46036"),
  bty = "n"
)

report <- c(
  "# Gen5.2 Replay-Semantics Mechanics Lab",
  "",
  "Purpose: isolate mechanics with synthetic data so the Gen4/Gen5.2 comparison is not overfit to SOFI or any single historical path.",
  "",
  "The synthetic price path crosses above its slow EMA on 2026-01-01 while the route is still `no_trade`; the route switches to the EMA spec on 2026-01-02, after the cross is already active.",
  "",
  "Key readout:",
  paste0("- Truth table: `", normalizePath(file.path(output_dir, "mechanics_truth_table.csv"), winslash = "/", mustWork = FALSE), "`"),
  paste0("- Timeline chart: `", normalizePath(png_path, winslash = "/", mustWork = FALSE), "`"),
  "",
  "Interpretation:",
  "- `fresh_signal_only` preserves current Gen5.2 behavior: it does not enter on an already-active EMA condition unless a fresh entry event occurs while routed to that spec.",
  "- `state_switch_continuation` is the explicit research toggle that enters when a state route switches into an already-active trend-following spec.",
  "- `fold_asset_authority_proxy` illustrates why Gen4-like fold/asset authority can catch the original cross: the strategy is active before the cross happens.",
  "",
  "STOP: this packet proves mechanics only. It should not be used as allocation evidence."
)
writeLines(report, file.path(output_dir, "README.md"))

message("Wrote Gen5.2 replay-semantics mechanics lab: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
