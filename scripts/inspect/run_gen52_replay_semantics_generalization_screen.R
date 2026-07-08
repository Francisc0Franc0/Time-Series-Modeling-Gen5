# Gen5.2 replay-semantics generalization screen.
#
# Replays cached non-SOFI selection-policy context packets under two entry
# semantics without refitting PCA, strategy selection, or authority packets.

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

split_csv <- function(x) {
  x <- trimws(unlist(strsplit(as.character(x), ",", fixed = TRUE), use.names = FALSE))
  x[nzchar(x)]
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
    out$selected_states <- g5_selection_policy_add_direct_label(
      out$selected_states,
      out$train_state_performance,
      min_train_state_rows = min_train_state_rows
    )
  } else if (identical(selection_policy, "pooled_family_asset_variant")) {
    out$selected_states <- g5_selection_policy_pooled_family_asset_variant(
      out$train_state_performance,
      min_train_state_rows = min_train_state_rows
    )
  } else {
    g5_stop(paste0("Unsupported selection policy: ", selection_policy))
  }
  out
}

read_current_state_path <- function(screen_dir, window_id, quarter_id, symbol, live_start, live_end, required_dates = NULL) {
  replay_path <- file.path(screen_dir, window_id, "asset_state_direct_spec", "bridge_replay.csv")
  if (!file.exists(replay_path)) {
    g5_stop(paste0("Missing cached direct replay state path: ", replay_path))
  }
  replay <- utils::read.csv(replay_path, stringsAsFactors = FALSE)
  required <- c("symbol", "session_date", "state_id")
  missing <- setdiff(required, names(replay))
  if (length(missing)) {
    g5_stop(paste0("Cached replay missing required state columns: ", paste(missing, collapse = ", ")))
  }
  replay$session_date <- as.Date(replay$session_date)
  keep <- as.character(replay$symbol) == symbol &
    replay$session_date >= as.Date(live_start) &
    replay$session_date <= as.Date(live_end)
  if ("authority_quarter_id" %in% names(replay)) {
    keep <- keep & as.character(replay$authority_quarter_id) == quarter_id
  }
  scored <- replay[keep, c("symbol", "session_date", "state_id"), drop = FALSE]
  if (!nrow(scored)) {
    return(NULL)
  }
  if (!is.null(required_dates)) {
    missing_dates <- setdiff(as.character(as.Date(required_dates)), as.character(as.Date(scored$session_date)))
    if (length(missing_dates)) {
      return(NULL)
    }
  }
  scored[order(as.Date(scored$session_date)), , drop = FALSE]
}

replay_symbol_oos <- function(bars, authority, scored, symbol, entry_replay_semantics, lane_id, screen_id, window_id) {
  contract <- authority$contract[1L, , drop = FALSE]
  live_start <- as.Date(contract$live_start_date[[1L]])
  live_end <- as.Date(contract$live_end_date[[1L]])
  as_of_date <- max(as.Date(scored$session_date), na.rm = TRUE)
  out <- g5_bridge_replay_symbol(
    bars,
    symbol,
    scored,
    authority$selected_states,
    contract,
    allow_as_of_after_live_end = TRUE,
    replay_start_date = live_start,
    entry_signal_start_date = live_start,
    entry_signal_end_date = as_of_date,
    honor_pending_entry_execution_until = as_of_date,
    authority_role = paste0("generalization_", lane_id),
    entry_replay_semantics = entry_replay_semantics
  )
  for (field in c("replay", "executions", "trades", "pending_actions")) {
    if (is.data.frame(out[[field]]) && nrow(out[[field]])) {
      out[[field]]$screen_id <- screen_id
      out[[field]]$window_id <- window_id
      out[[field]]$lane_id <- lane_id
      out[[field]]$selection_policy <- as.character(authority$contract$selection_policy[[1L]])
      out[[field]]$entry_replay_semantics <- entry_replay_semantics
      out[[field]]$quarter_id <- as.character(contract$quarter_id[[1L]])
    }
  }
  out$replay_oos <- out$replay[
    as.Date(out$replay$session_date) >= live_start & as.Date(out$replay$session_date) <= as_of_date,
    ,
    drop = FALSE
  ]
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
    screen_id = as.character(replay$screen_id),
    window_id = as.character(replay$window_id),
    lane_id = as.character(replay$lane_id),
    selection_policy = as.character(replay$selection_policy),
    entry_replay_semantics = as.character(replay$entry_replay_semantics),
    symbol = as.character(replay$symbol),
    session_date = as.Date(replay$session_date),
    strategy_ret = ifelse(pos_lag, ret, 0),
    benchmark_ret = ret,
    in_position = pos,
    stringsAsFactors = FALSE
  )
}

portfolio_equity <- function(daily_returns) {
  if (!is.data.frame(daily_returns) || !nrow(daily_returns)) return(data.frame())
  grouped <- stats::aggregate(
    cbind(strategy_ret, benchmark_ret, in_position) ~ screen_id + window_id + lane_id + selection_policy + entry_replay_semantics + session_date,
    data = daily_returns,
    FUN = mean
  )
  grouped <- grouped[order(grouped$screen_id, grouped$window_id, grouped$lane_id, as.Date(grouped$session_date)), , drop = FALSE]
  pieces <- split(grouped, paste(grouped$screen_id, grouped$window_id, grouped$lane_id, sep = "|"))
  out <- lapply(pieces, function(x) {
    x$strategy_equity <- cumprod(1 + as.numeric(x$strategy_ret))
    x$benchmark_equity <- cumprod(1 + as.numeric(x$benchmark_ret))
    x
  })
  rownames(out) <- NULL
  g5_wfa_bind_rows_fill(out)
}

summarize_equity <- function(equity) {
  if (!is.data.frame(equity) || !nrow(equity)) return(data.frame())
  pieces <- split(equity, paste(equity$screen_id, equity$window_id, equity$lane_id, sep = "|"))
  rows <- lapply(pieces, function(x) {
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    data.frame(
      screen_id = as.character(x$screen_id[[1L]]),
      window_id = as.character(x$window_id[[1L]]),
      lane_id = as.character(x$lane_id[[1L]]),
      selection_policy = as.character(x$selection_policy[[1L]]),
      entry_replay_semantics = as.character(x$entry_replay_semantics[[1L]]),
      strategy_return = tail(x$strategy_equity, 1L) - 1,
      benchmark_return = tail(x$benchmark_equity, 1L) - 1,
      alpha_vs_benchmark = tail(x$strategy_equity, 1L) - tail(x$benchmark_equity, 1L),
      mean_exposure = mean(as.numeric(x$in_position), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  g5_wfa_bind_rows_fill(rows)
}

summarize_symbol <- function(daily_returns, trades) {
  if (!is.data.frame(daily_returns) || !nrow(daily_returns)) return(data.frame())
  keys <- c("screen_id", "window_id", "lane_id", "selection_policy", "entry_replay_semantics", "symbol")
  pieces <- split(daily_returns, do.call(paste, c(daily_returns[, keys, drop = FALSE], sep = "|")))
  rows <- lapply(pieces, function(x) {
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    t <- if (is.data.frame(trades) && nrow(trades)) {
      trades[
        as.character(trades$screen_id) == as.character(x$screen_id[[1L]]) &
          as.character(trades$window_id) == as.character(x$window_id[[1L]]) &
          as.character(trades$lane_id) == as.character(x$lane_id[[1L]]) &
          as.character(trades$symbol) == as.character(x$symbol[[1L]]),
        ,
        drop = FALSE
      ]
    } else {
      data.frame()
    }
    data.frame(
      screen_id = as.character(x$screen_id[[1L]]),
      window_id = as.character(x$window_id[[1L]]),
      lane_id = as.character(x$lane_id[[1L]]),
      selection_policy = as.character(x$selection_policy[[1L]]),
      entry_replay_semantics = as.character(x$entry_replay_semantics[[1L]]),
      symbol = as.character(x$symbol[[1L]]),
      strategy_return = prod(1 + as.numeric(x$strategy_ret), na.rm = TRUE) - 1,
      benchmark_return = prod(1 + as.numeric(x$benchmark_ret), na.rm = TRUE) - 1,
      mean_exposure = mean(as.numeric(x$in_position), na.rm = TRUE),
      trade_count = if (nrow(t)) nrow(t) else 0L,
      open_trade_count = if (nrow(t)) sum(as.character(t$trade_status) == "open", na.rm = TRUE) else 0L,
      stringsAsFactors = FALSE
    )
  })
  g5_wfa_bind_rows_fill(rows)
}

semantic_delta <- function(summary) {
  fresh <- summary[as.character(summary$entry_replay_semantics) == "fresh_signal_only", , drop = FALSE]
  cont <- summary[as.character(summary$entry_replay_semantics) == "state_switch_continuation", , drop = FALSE]
  keys <- c("screen_id", "window_id", "selection_policy")
  merged <- merge(
    fresh[, c(keys, "lane_id", "strategy_return", "benchmark_return", "alpha_vs_benchmark", "mean_exposure"), drop = FALSE],
    cont[, c(keys, "lane_id", "strategy_return", "benchmark_return", "alpha_vs_benchmark", "mean_exposure"), drop = FALSE],
    by = keys,
    all = TRUE,
    suffixes = c("_fresh", "_continuation")
  )
  merged$strategy_return_delta_continuation_minus_fresh <- as.numeric(merged$strategy_return_continuation) - as.numeric(merged$strategy_return_fresh)
  merged$alpha_delta_continuation_minus_fresh <- as.numeric(merged$alpha_vs_benchmark_continuation) - as.numeric(merged$alpha_vs_benchmark_fresh)
  merged$exposure_delta_continuation_minus_fresh <- as.numeric(merged$mean_exposure_continuation) - as.numeric(merged$mean_exposure_fresh)
  merged
}

aggregate_delta <- function(delta, taxonomy) {
  if (!is.data.frame(delta) || !nrow(delta)) return(data.frame())
  pieces <- split(delta, paste(delta$screen_id, delta$selection_policy, sep = "|"))
  rows <- lapply(pieces, function(x) {
    data.frame(
      screen_id = as.character(x$screen_id[[1L]]),
      selection_policy = as.character(x$selection_policy[[1L]]),
      windows_tested = nrow(x),
      windows_continuation_improved_alpha = sum(as.numeric(x$alpha_delta_continuation_minus_fresh) > 0, na.rm = TRUE),
      mean_strategy_return_delta = mean(as.numeric(x$strategy_return_delta_continuation_minus_fresh), na.rm = TRUE),
      mean_alpha_delta = mean(as.numeric(x$alpha_delta_continuation_minus_fresh), na.rm = TRUE),
      mean_exposure_delta = mean(as.numeric(x$exposure_delta_continuation_minus_fresh), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- g5_wfa_bind_rows_fill(rows)
  merge(out, taxonomy[, c("screen_id", "screen_label", "basket_archetype", "context_philosophy"), drop = FALSE], by = "screen_id", all.x = TRUE)
}

delta_color <- function(values) {
  values <- suppressWarnings(as.numeric(values))
  max_abs <- max(abs(values), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  vapply(values, function(value) {
    if (!is.finite(value) || value == 0) return("#FFFDF8")
    target <- if (value > 0) "#00A88F" else "#F15A5A"
    grDevices::adjustcolor(target, alpha.f = min(0.95, 0.22 + 0.73 * abs(value) / max_abs))
  }, character(1L))
}

window_label <- function(window_id) {
  sub("_asof_", "\n", as.character(window_id), fixed = TRUE)
}

short_screen_label <- function(screen_id) {
  labels <- c(
    ETF_archetype_matched_no_vxx = "ETF archetype",
    ETF_broad_risk_no_vxx = "ETF broad-risk",
    HB_archetype_matched_no_vxx = "High-beta archetype",
    HB_broad_risk_no_vxx = "High-beta broad-risk"
  )
  out <- labels[as.character(screen_id)]
  out[is.na(out)] <- as.character(screen_id)[is.na(out)]
  unname(out)
}

short_policy_label <- function(selection_policy) {
  labels <- c(
    asset_state_direct_spec = "direct",
    pooled_family_asset_variant = "pooled-family"
  )
  out <- labels[as.character(selection_policy)]
  out[is.na(out)] <- as.character(selection_policy)[is.na(out)]
  unname(out)
}

write_delta_heatmap <- function(delta, taxonomy, path) {
  aesthetic <- g5_chart_aesthetic()
  delta <- merge(delta, taxonomy[, c("screen_id", "screen_label"), drop = FALSE], by = "screen_id", all.x = TRUE)
  delta$row_label <- paste(short_screen_label(delta$screen_id), short_policy_label(delta$selection_policy), sep = " | ")
  rows <- unique(as.character(delta$row_label))
  windows <- unique(as.character(delta$window_id))
  values <- matrix(NA_real_, nrow = length(rows), ncol = length(windows), dimnames = list(rows, windows))
  for (i in seq_len(nrow(delta))) {
    key <- as.character(delta$row_label[[i]])
    values[key, as.character(delta$window_id[[i]])] <- as.numeric(delta$alpha_delta_continuation_minus_fresh[[i]])
  }
  grDevices::png(path, width = 2600L, height = 1600L, res = 220L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(7, 10, 4, 2))
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Continuation Minus Fresh: Alpha Delta", col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  cols <- delta_color(as.vector(values))
  dim(cols) <- dim(values)
  for (r in seq_len(nrow(values))) {
    y <- nrow(values) - r + 1
    for (c in seq_len(ncol(values))) {
      graphics::rect(c - 0.5, y - 0.5, c + 0.5, y + 0.5, col = cols[r, c], border = aesthetic$grid)
      graphics::text(c, y, labels = pct_label(values[r, c], 1L), cex = 0.66, col = aesthetic$text)
    }
  }
  graphics::axis(1, at = seq_along(windows), labels = window_label(windows), las = 1, cex.axis = 0.62, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(rows)), labels = rows, las = 1, cex.axis = 0.62, col.axis = aesthetic$axis)
  graphics::mtext("Green means state-switch continuation improved alpha vs equal-weight basket buy-and-hold in that window.", side = 1, line = 5.6, cex = 0.68, col = aesthetic$text)
  invisible(path)
}

write_mean_delta_bars <- function(aggregate, path) {
  aesthetic <- g5_chart_aesthetic()
  aggregate <- aggregate[order(aggregate$basket_archetype, aggregate$context_philosophy, aggregate$selection_policy), , drop = FALSE]
  labels <- paste(short_screen_label(aggregate$screen_id), short_policy_label(aggregate$selection_policy), sep = "\n")
  values <- as.numeric(aggregate$mean_alpha_delta)
  colors <- ifelse(values >= 0, "#00A88F", "#F15A5A")
  grDevices::png(path, width = 2400L, height = 1600L, res = 220L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(11, 5, 4, 2))
  ylim <- range(c(values, 0), na.rm = TRUE)
  if (!all(is.finite(ylim)) || diff(ylim) == 0) ylim <- ylim + c(-0.02, 0.02)
  bars <- graphics::barplot(values, names.arg = labels, las = 2, col = colors, border = NA, ylim = ylim * c(ifelse(ylim[[1L]] < 0, 1.2, 0), 1.2), main = "Mean Alpha Delta: Continuation Minus Fresh", ylab = "Alpha delta", col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  graphics::abline(h = 0, col = aesthetic$axis, lwd = 1)
  graphics::text(bars, values, labels = pct_label(values, 1L), pos = ifelse(values >= 0, 3, 1), cex = 0.72, col = aesthetic$text)
  invisible(path)
}

write_report <- function(output_dir, source_root, run_spec, taxonomy, summary, delta, aggregate, artifact_index) {
  printable <- aggregate
  for (col in c("mean_strategy_return_delta", "mean_alpha_delta", "mean_exposure_delta")) {
    printable[[col]] <- pct_label(printable[[col]], 1L)
  }
  report <- c(
    "# Gen5.2 Non-SOFI Replay-Semantics Generalization Screen",
    "",
    "Purpose: test whether the state-switch continuation entry rule is a broad mechanics improvement, rather than a SOFI-specific explanation.",
    "",
    paste0("Source packet: `", normalizePath(source_root, winslash = "/", mustWork = FALSE), "`"),
    paste0("Output directory: `", normalizePath(output_dir, winslash = "/", mustWork = FALSE), "`"),
    "",
    "Design:",
    "- Reuses frozen authority and cached OOS state paths from the July 3 context-philosophy screen.",
    "- Tests non-SOFI high-beta and ETF-sector baskets only.",
    "- Crosses `asset_state_direct_spec` and `pooled_family_asset_variant` with `fresh_signal_only` and `state_switch_continuation`.",
    "- Isolates the current-quarter OOS window; previous-quarter open-trade continuity is intentionally not carried here.",
    "- Uses an equal-symbol daily replay proxy and equal-weight basket buy-and-hold benchmark for inspection.",
    "",
    "Guardrails:",
    "- No PCA refit, no strategy refit, no data refresh, no new authority acceptance.",
    "- Performance is an inspection layer only, not allocation evidence.",
    "- The only intended behavior delta is whether trend-following EMA routes may enter when a state switch lands on an already-active trend.",
    "",
    "Aggregate readout:",
    paste(capture.output(print(printable[, c("screen_id", "selection_policy", "windows_tested", "windows_continuation_improved_alpha", "mean_strategy_return_delta", "mean_alpha_delta", "mean_exposure_delta")], row.names = FALSE)), collapse = "\n"),
    "",
    "Artifacts:",
    paste0("- `", normalizePath(file.path(output_dir, "replay_semantics_generalization_run_spec.csv"), winslash = "/", mustWork = FALSE), "`"),
    paste0("- `", normalizePath(file.path(output_dir, "replay_semantics_generalization_summary.csv"), winslash = "/", mustWork = FALSE), "`"),
    paste0("- `", normalizePath(file.path(output_dir, "replay_semantics_generalization_semantic_delta.csv"), winslash = "/", mustWork = FALSE), "`"),
    paste0("- `", normalizePath(file.path(output_dir, "replay_semantics_generalization_delta_heatmap.png"), winslash = "/", mustWork = FALSE), "`"),
    paste0("- `", normalizePath(file.path(output_dir, "replay_semantics_generalization_mean_delta_bars.png"), winslash = "/", mustWork = FALSE), "`")
  )
  writeLines(report, file.path(output_dir, "replay_semantics_generalization_report.md"))
}

default_source <- file.path(repo_root, "runs", "research_workbench", "selpol_context", "selpol_context_20260703")
source_root <- normalizePath(env_or("GEN5_REPLAY_SEMANTICS_CONTEXT_PACKET", default_source), winslash = "/", mustWork = TRUE)
stamp <- env_or("GEN5_REPLAY_SEMANTICS_GENERALIZATION_STAMP", "20260708_nonsofi")
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen52_mechanics", paste0("replay_semantics_generalization_", stamp))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

screen_ids <- split_csv(env_or(
  "GEN5_REPLAY_SEMANTICS_GENERALIZATION_SCREENS",
  "HB_broad_risk_no_vxx,HB_archetype_matched_no_vxx,ETF_broad_risk_no_vxx,ETF_archetype_matched_no_vxx"
))
selection_policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
semantics <- c("fresh_signal_only", "state_switch_continuation")

taxonomy_path <- file.path(source_root, "selection_policy_context_philosophy_run_spec.csv")
if (!file.exists(taxonomy_path)) g5_stop(paste0("Missing context screen run spec: ", taxonomy_path))
taxonomy_all <- utils::read.csv(taxonomy_path, stringsAsFactors = FALSE)
taxonomy <- taxonomy_all[as.character(taxonomy_all$screen_id) %in% screen_ids, , drop = FALSE]
if (nrow(taxonomy) != length(screen_ids)) {
  missing <- setdiff(screen_ids, as.character(taxonomy$screen_id))
  g5_stop(paste0("Missing requested screen specs: ", paste(missing, collapse = ", ")))
}

windows <- split_csv(taxonomy$replay_windows[[1L]])
window_override <- env_or("GEN5_REPLAY_SEMANTICS_GENERALIZATION_WINDOWS", "")
if (nzchar(window_override)) windows <- split_csv(window_override)

run_spec <- expand.grid(
  screen_id = screen_ids,
  window_id = windows,
  selection_policy = selection_policies,
  entry_replay_semantics = semantics,
  stringsAsFactors = FALSE
)
run_spec$source_packet <- source_root
run_spec$output_dir <- output_dir
run_spec$research_only <- TRUE
run_spec$interpretation_note <- "Fixed-authority current-quarter OOS replay semantics screen; not accepted allocation evidence."

paths <- list(
  run_spec = file.path(output_dir, "replay_semantics_generalization_run_spec.csv"),
  taxonomy = file.path(output_dir, "replay_semantics_generalization_taxonomy.csv"),
  packet_index = file.path(output_dir, "replay_semantics_generalization_packet_index.csv"),
  replay_oos = file.path(output_dir, "replay_semantics_generalization_replay_oos.csv"),
  executions = file.path(output_dir, "replay_semantics_generalization_executions.csv"),
  trades = file.path(output_dir, "replay_semantics_generalization_trades.csv"),
  pending = file.path(output_dir, "replay_semantics_generalization_pending_actions.csv"),
  daily_returns = file.path(output_dir, "replay_semantics_generalization_symbol_daily_returns.csv"),
  daily_equity = file.path(output_dir, "replay_semantics_generalization_daily_equity.csv"),
  summary = file.path(output_dir, "replay_semantics_generalization_summary.csv"),
  symbol_summary = file.path(output_dir, "replay_semantics_generalization_symbol_summary.csv"),
  semantic_delta = file.path(output_dir, "replay_semantics_generalization_semantic_delta.csv"),
  aggregate_delta = file.path(output_dir, "replay_semantics_generalization_aggregate_delta.csv"),
  heatmap = file.path(output_dir, "replay_semantics_generalization_delta_heatmap.png"),
  bars = file.path(output_dir, "replay_semantics_generalization_mean_delta_bars.png"),
  report = file.path(output_dir, "replay_semantics_generalization_report.md")
)

if (identical(env_or("GEN5_REPLAY_SEMANTICS_GENERALIZATION_REBUILD_ONLY", "false"), "true")) {
  summary <- utils::read.csv(paths$summary, stringsAsFactors = FALSE)
  delta <- utils::read.csv(paths$semantic_delta, stringsAsFactors = FALSE)
  aggregate <- utils::read.csv(paths$aggregate_delta, stringsAsFactors = FALSE)
  artifact_index_path <- file.path(output_dir, "replay_semantics_generalization_artifact_index.csv")
  artifact_index <- if (file.exists(artifact_index_path)) utils::read.csv(artifact_index_path, stringsAsFactors = FALSE) else data.frame()
  write_delta_heatmap(delta, taxonomy, paths$heatmap)
  write_mean_delta_bars(aggregate, paths$bars)
  write_report(output_dir, source_root, run_spec, taxonomy, summary, delta, aggregate, artifact_index)
  message("Rebuilt Gen5.2 non-SOFI replay-semantics report/visuals: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
  quit(save = "no", status = 0)
}

results <- list()
packet_rows <- list()
for (screen_id in screen_ids) {
  screen_spec <- taxonomy[as.character(taxonomy$screen_id) == screen_id, , drop = FALSE]
  screen_dir <- file.path(source_root, screen_id)
  bars_path <- file.path(screen_dir, "query", paste0("query_", screen_id, "_bars.csv"))
  if (!file.exists(bars_path)) g5_stop(paste0("Missing cached query bars: ", bars_path))
  bars <- utils::read.csv(bars_path, stringsAsFactors = FALSE)
  bars$session_date <- as.Date(bars$session_date)
  symbols <- g5_standardize_symbol(split_csv(screen_spec$symbols[[1L]]))
  min_train_state_rows <- suppressWarnings(as.integer(screen_spec$min_train_state_rows[[1L]]))
  if (!is.finite(min_train_state_rows)) min_train_state_rows <- 20L
  for (window_id in windows) {
    quarter_id <- sub("_asof_.*$", "", window_id)
    auth_dir <- file.path(screen_dir, "auth", quarter_id)
    if (!dir.exists(auth_dir)) g5_stop(paste0("Missing cached authority: ", auth_dir))
    authority_base <- read_full_authority_packet(auth_dir)
    contract <- authority_base$contract[1L, , drop = FALSE]
    live_start <- as.Date(contract$live_start_date[[1L]])
    live_end <- as.Date(contract$live_end_date[[1L]])
    message("Replay semantics / ", screen_id, " / ", window_id)
    policy_authorities <- stats::setNames(
      lapply(selection_policies, function(policy) make_policy_authority(authority_base, policy, min_train_state_rows)),
      selection_policies
    )
    scored_cache <- stats::setNames(vector("list", length(symbols)), symbols)
    for (symbol in symbols) {
      symbol_dates <- sort(unique(as.Date(bars$session_date[as.character(bars$symbol) == symbol & as.Date(bars$session_date) >= live_start & as.Date(bars$session_date) <= live_end])))
      scored_cache[[symbol]] <- read_current_state_path(
        screen_dir,
        window_id,
        quarter_id,
        symbol,
        live_start,
        live_end,
        required_dates = symbol_dates
      )
      if (is.null(scored_cache[[symbol]])) {
        message("Score current-authority states / ", screen_id, " / ", window_id, " / ", symbol, " (cached continuity replay is incomplete for quarter start)")
        scored_cache[[symbol]] <- g5_bridge_score_authority_symbol(bars, authority_base, symbol, max(symbol_dates, na.rm = TRUE))
      }
    }
    for (policy in selection_policies) {
      authority <- policy_authorities[[policy]]
      for (entry_semantics in semantics) {
        lane_id <- paste(policy, entry_semantics, sep = "__")
        for (symbol in symbols) {
          key <- paste(screen_id, window_id, lane_id, symbol, sep = "|")
          results[[key]] <- replay_symbol_oos(
            bars,
            authority,
            scored_cache[[symbol]],
            symbol,
            entry_semantics,
            lane_id,
            screen_id,
            window_id
          )
        }
      }
    }
    packet_rows[[length(packet_rows) + 1L]] <- data.frame(
      screen_id = screen_id,
      window_id = window_id,
      authority_dir = normalizePath(auth_dir, winslash = "/", mustWork = FALSE),
      bars_path = normalizePath(bars_path, winslash = "/", mustWork = FALSE),
      stringsAsFactors = FALSE
    )
  }
}

replay_oos <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$replay_oos))
executions <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$executions))
trades <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$trades))
pending <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$pending_actions))
daily <- g5_wfa_bind_rows_fill(lapply(split(replay_oos, paste(replay_oos$screen_id, replay_oos$window_id, replay_oos$lane_id, replay_oos$symbol, sep = "|")), symbol_daily_returns))
equity <- portfolio_equity(daily)
summary <- summarize_equity(equity)
symbol_summary <- summarize_symbol(daily, trades)
delta <- semantic_delta(summary)
aggregate <- aggregate_delta(delta, taxonomy)
packet_index <- g5_wfa_bind_rows_fill(packet_rows)

g5_wfa_write_csv(run_spec, paths$run_spec)
g5_wfa_write_csv(taxonomy, paths$taxonomy)
g5_wfa_write_csv(packet_index, paths$packet_index)
g5_wfa_write_csv(replay_oos, paths$replay_oos)
g5_wfa_write_csv(executions, paths$executions)
g5_wfa_write_csv(trades, paths$trades)
g5_wfa_write_csv(pending, paths$pending)
g5_wfa_write_csv(daily, paths$daily_returns)
g5_wfa_write_csv(equity, paths$daily_equity)
g5_wfa_write_csv(summary, paths$summary)
g5_wfa_write_csv(symbol_summary, paths$symbol_summary)
g5_wfa_write_csv(delta, paths$semantic_delta)
g5_wfa_write_csv(aggregate, paths$aggregate_delta)
write_delta_heatmap(delta, taxonomy, paths$heatmap)
write_mean_delta_bars(aggregate, paths$bars)

artifact_index <- data.frame(
  artifact = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
g5_wfa_write_csv(artifact_index, file.path(output_dir, "replay_semantics_generalization_artifact_index.csv"))
write_report(output_dir, source_root, run_spec, taxonomy, summary, delta, aggregate, artifact_index)

printable <- aggregate
for (col in c("mean_strategy_return_delta", "mean_alpha_delta", "mean_exposure_delta")) {
  printable[[col]] <- pct_label(printable[[col]], 1L)
}
message("Wrote Gen5.2 non-SOFI replay-semantics screen: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
print(printable[, c("screen_id", "selection_policy", "windows_tested", "windows_continuation_improved_alpha", "mean_alpha_delta", "mean_exposure_delta")], row.names = FALSE)
