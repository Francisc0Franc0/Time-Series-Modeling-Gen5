# Gen5.2 replay-semantics historical A/B.
#
# Replays an existing fixed authority packet with two entry semantics:
# fresh_signal_only vs state_switch_continuation. This intentionally avoids
# refitting so the difference is isolated to replay timing.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "strategy_ema_cross.R"))
source(file.path(repo_root, "R", "strategy_bollinger_touch.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_poc.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))
source(file.path(repo_root, "R", "selection_policy_screen.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

pct_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f%%"), 100 * x))
}

read_full_authority_packet <- function(authority_dir) {
  authority <- g5_bridge_read_authority(authority_dir)
  perf_path <- file.path(authority_dir, "bridge_train_state_performance.csv")
  if (!file.exists(perf_path)) {
    g5_stop(paste0("Missing bridge_train_state_performance.csv in cached authority: ", authority_dir))
  }
  authority$train_state_performance <- utils::read.csv(perf_path, stringsAsFactors = FALSE)
  authority
}

make_policy_authority <- function(authority, selection_policy, min_train_state_rows = 20L) {
  out <- authority
  out$contract$selection_policy <- selection_policy
  if (identical(selection_policy, "asset_state_direct_spec")) {
    out$selected_states <- g5_selection_policy_add_direct_label(out$selected_states, out$train_state_performance, min_train_state_rows = min_train_state_rows)
  } else if (identical(selection_policy, "pooled_family_asset_variant_state_fallback")) {
    out$selected_states <- g5_selection_policy_pooled_family_asset_variant_state_fallback(out$train_state_performance, min_train_state_rows = min_train_state_rows)
  } else {
    g5_stop(paste0("Unsupported policy for replay-semantics A/B: ", selection_policy))
  }
  out
}

replay_symbol_quarter <- function(bars, authority, symbol, as_of_date, entry_replay_semantics, lane_id, scored = NULL) {
  contract <- authority$contract[1L, , drop = FALSE]
  if (is.null(scored)) {
    scored <- g5_bridge_score_authority_symbol(bars, authority, symbol, as_of_date)
  }
  out <- g5_bridge_replay_symbol(
    bars,
    symbol,
    scored,
    authority$selected_states,
    contract,
    allow_as_of_after_live_end = TRUE,
    replay_start_date = as.Date(contract$train_end_date[[1L]]),
    entry_signal_start_date = as.Date(contract$train_end_date[[1L]]),
    entry_signal_end_date = as.Date(contract$live_end_date[[1L]]),
    honor_pending_entry_execution_until = as.Date(contract$live_end_date[[1L]]),
    authority_role = paste0("historical_ab_", lane_id),
    entry_replay_semantics = entry_replay_semantics
  )
  live_start <- as.Date(contract$live_start_date[[1L]])
  live_end <- as.Date(contract$live_end_date[[1L]])
  for (field in c("replay", "executions", "trades", "pending_actions")) {
    if (is.data.frame(out[[field]]) && nrow(out[[field]])) {
      out[[field]]$lane_id <- lane_id
      out[[field]]$entry_replay_semantics <- entry_replay_semantics
      out[[field]]$quarter_id <- as.character(contract$quarter_id[[1L]])
    }
  }
  out$replay_oos <- out$replay[as.Date(out$replay$session_date) >= live_start & as.Date(out$replay$session_date) <= live_end, , drop = FALSE]
  out
}

symbol_daily_returns <- function(replay) {
  if (!is.data.frame(replay) || !nrow(replay)) return(data.frame())
  replay <- replay[order(as.Date(replay$session_date)), , drop = FALSE]
  close <- suppressWarnings(as.numeric(replay$close))
  ret <- c(0, close[-1L] / close[-length(close)] - 1)
  ret[!is.finite(ret)] <- 0
  pos <- as.character(replay$model_position_after_replay) == "LONG"
  pos_lag <- c(FALSE, pos[-length(pos)])
  data.frame(
    lane_id = as.character(replay$lane_id),
    symbol = as.character(replay$symbol),
    session_date = as.Date(replay$session_date),
    strategy_ret = ifelse(pos_lag, ret, 0),
    benchmark_ret = ret,
    in_position = pos,
    stringsAsFactors = FALSE
  )
}

portfolio_equity <- function(daily_returns, group_id, symbols) {
  x <- daily_returns[as.character(daily_returns$symbol) %in% symbols, , drop = FALSE]
  if (!nrow(x)) return(data.frame())
  daily <- stats::aggregate(cbind(strategy_ret, benchmark_ret) ~ lane_id + session_date, data = x, FUN = mean)
  daily <- daily[order(as.character(daily$lane_id), as.Date(daily$session_date)), , drop = FALSE]
  out <- do.call(rbind, lapply(split(daily, daily$lane_id), function(lane) {
    lane$group_id <- group_id
    lane$strategy_equity <- cumprod(1 + as.numeric(lane$strategy_ret))
    lane$benchmark_equity <- cumprod(1 + as.numeric(lane$benchmark_ret))
    lane
  }))
  rownames(out) <- NULL
  out
}

summarize_equity <- function(equity) {
  if (!is.data.frame(equity) || !nrow(equity)) return(data.frame())
  rows <- lapply(split(equity, paste(equity$lane_id, equity$group_id, sep = "|")), function(x) {
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    data.frame(
      lane_id = x$lane_id[[1L]],
      group_id = x$group_id[[1L]],
      strategy_return = tail(x$strategy_equity, 1L) - 1,
      benchmark_return = tail(x$benchmark_equity, 1L) - 1,
      alpha_vs_benchmark = tail(x$strategy_equity, 1L) - tail(x$benchmark_equity, 1L),
      stringsAsFactors = FALSE
    )
  })
  g5_wfa_bind_rows_fill(rows)
}

write_equity_overlay <- function(equity, path) {
  aesthetic <- g5_chart_aesthetic()
  grDevices::png(path, width = 2400L, height = 1400L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  groups <- unique(as.character(equity$group_id))
  groups <- groups[groups %in% c("cluster_3_proxy", "live_all")]
  if (!length(groups)) groups <- unique(as.character(equity$group_id))
  graphics::par(bg = aesthetic$background, mfrow = c(length(groups), 1), mar = c(4.5, 5, 3, 2), oma = c(0, 0, 3, 0))
  colors <- c(
    direct_fresh_signal_only = "#2E86AB",
    fallback_fresh_signal_only = "#FF6B35",
    fallback_state_switch_continuation = "#2E7D32"
  )
  for (group in groups) {
    x <- equity[as.character(equity$group_id) == group, , drop = FALSE]
    dates <- sort(unique(as.Date(x$session_date)))
    y_range <- range(c(x$strategy_equity, x$benchmark_equity), na.rm = TRUE)
    graphics::plot(dates, rep(NA_real_, length(dates)), ylim = y_range, xlab = "", ylab = "Equity", main = group, col = NA)
    bx <- x[x$lane_id == unique(x$lane_id)[[1L]], , drop = FALSE]
    graphics::lines(as.Date(bx$session_date), bx$benchmark_equity, col = "#888888", lwd = 2, lty = 2)
    for (lane in unique(as.character(x$lane_id))) {
      y <- x[as.character(x$lane_id) == lane, , drop = FALSE]
      graphics::lines(as.Date(y$session_date), y$strategy_equity, col = colors[[lane]], lwd = 2.5)
    }
    graphics::legend(
      "topleft",
      legend = c("Benchmark", unique(as.character(x$lane_id))),
      col = c("#888888", colors[unique(as.character(x$lane_id))]),
      lwd = c(2, rep(2.5, length(unique(as.character(x$lane_id))))),
      lty = c(2, rep(1, length(unique(as.character(x$lane_id))))),
      bty = "n",
      cex = 0.82
    )
  }
  graphics::mtext("Gen5.2 fixed-authority replay semantics A/B", outer = TRUE, cex = 1.1, font = 2)
}

default_packet <- file.path(repo_root, "runs", "research_workbench", "gen4_equivalence", "gen4_equivalence_gen52fallbackfull162024q420260708")
packet_dir <- normalizePath(env_or("GEN5_REPLAY_SEMANTICS_PACKET_DIR", default_packet), winslash = "/", mustWork = TRUE)
output_dir <- file.path(packet_dir, "replay_semantics_ab")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

query_bars_path <- file.path(packet_dir, "query", "gen4_equivalence_query_bars.csv")
auth_dir <- file.path(packet_dir, "auth", "2024Q4")
if (!file.exists(query_bars_path)) g5_stop(paste0("Missing query bars: ", query_bars_path))
if (!dir.exists(auth_dir)) g5_stop(paste0("Missing authority directory: ", auth_dir))

bars <- utils::read.csv(query_bars_path, stringsAsFactors = FALSE)
bars$session_date <- as.Date(bars$session_date)
authority_base <- read_full_authority_packet(auth_dir)
contract <- authority_base$contract[1L, , drop = FALSE]
symbols <- g5_standardize_symbol(strsplit(as.character(contract$symbols[[1L]]), ",", fixed = TRUE)[[1L]])
as_of_date <- as.Date(contract$live_end_date[[1L]])

message("Score frozen PCA states once per symbol.")
score_cache <- stats::setNames(vector("list", length(symbols)), symbols)
for (symbol in symbols) {
  message("Score states / ", symbol)
  score_cache[[symbol]] <- g5_bridge_score_authority_symbol(bars, authority_base, symbol, as_of_date)
}

lanes <- list(
  direct_fresh_signal_only = list(policy = "asset_state_direct_spec", semantics = "fresh_signal_only"),
  fallback_fresh_signal_only = list(policy = "pooled_family_asset_variant_state_fallback", semantics = "fresh_signal_only"),
  fallback_state_switch_continuation = list(policy = "pooled_family_asset_variant_state_fallback", semantics = "state_switch_continuation")
)

results <- list()
for (lane in names(lanes)) {
  authority <- make_policy_authority(authority_base, lanes[[lane]]$policy)
  for (symbol in symbols) {
    message("Replay ", lane, " / ", symbol)
    results[[paste(lane, symbol, sep = "|")]] <- replay_symbol_quarter(
      bars,
      authority,
      symbol,
      as_of_date,
      entry_replay_semantics = lanes[[lane]]$semantics,
      lane_id = lane,
      scored = score_cache[[symbol]]
    )
  }
}

replay_oos <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$replay_oos))
executions <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$executions))
trades <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$trades))
daily <- g5_wfa_bind_rows_fill(lapply(split(replay_oos, paste(replay_oos$lane_id, replay_oos$symbol, sep = "|")), symbol_daily_returns))

cluster3_proxy <- intersect(c("AMD", "NVDA", "PLTR", "SOFI", "TSLA"), symbols)
groups <- list(live_all = symbols, cluster_3_proxy = cluster3_proxy)
equity <- g5_wfa_bind_rows_fill(lapply(names(groups), function(group) portfolio_equity(daily, group, groups[[group]])))
summary <- summarize_equity(equity)
trade_summary <- if (nrow(trades)) {
  stats::aggregate(
    list(trade_count = trades$symbol),
    by = list(lane_id = trades$lane_id, symbol = trades$symbol, trade_status = trades$trade_status),
    FUN = length
  )
} else {
  data.frame()
}

g5_wfa_write_csv(replay_oos, file.path(output_dir, "replay_semantics_ab_replay_oos.csv"))
g5_wfa_write_csv(executions, file.path(output_dir, "replay_semantics_ab_executions.csv"))
g5_wfa_write_csv(trades, file.path(output_dir, "replay_semantics_ab_trades.csv"))
g5_wfa_write_csv(daily, file.path(output_dir, "replay_semantics_ab_symbol_daily_returns.csv"))
g5_wfa_write_csv(equity, file.path(output_dir, "replay_semantics_ab_daily_equity.csv"))
g5_wfa_write_csv(summary, file.path(output_dir, "replay_semantics_ab_summary.csv"))
g5_wfa_write_csv(trade_summary, file.path(output_dir, "replay_semantics_ab_trade_summary.csv"))

overlay_path <- file.path(output_dir, "replay_semantics_ab_equity_overlay.png")
write_equity_overlay(equity, overlay_path)

print_summary <- summary
for (col in c("strategy_return", "benchmark_return", "alpha_vs_benchmark")) {
  print_summary[[col]] <- pct_label(print_summary[[col]])
}

report <- c(
  "# Gen5.2 Historical Replay-Semantics A/B",
  "",
  "Purpose: replay the same fixed 2024Q4 authority packet under different entry semantics, without refitting PCA or strategy selection.",
  "",
  paste0("Source packet: `", packet_dir, "`"),
  paste0("Output directory: `", normalizePath(output_dir, winslash = "/", mustWork = FALSE), "`"),
  "",
  "Lanes:",
  "- `direct_fresh_signal_only`: Gen5.2 direct selection with current fresh-signal replay.",
  "- `fallback_fresh_signal_only`: pooled-family state-leader fallback with current fresh-signal replay.",
  "- `fallback_state_switch_continuation`: same fallback authority, but trend-following EMA routes may enter when a state switch lands on an already-active trend.",
  "",
  "Summary:",
  paste(capture.output(print(print_summary, row.names = FALSE)), collapse = "\n"),
  "",
  "Interpretation guardrail: this is a fixed-authority mechanics probe. It helps explain replay behavior; it is not accepted allocation evidence.",
  "",
  paste0("Equity overlay: `", normalizePath(overlay_path, winslash = "/", mustWork = FALSE), "`")
)
writeLines(report, file.path(output_dir, "replay_semantics_ab_report.md"))

message("Wrote Gen5.2 replay-semantics historical A/B: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
