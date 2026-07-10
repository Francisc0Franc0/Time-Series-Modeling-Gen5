# Gen5.3 bullish momentum specialist baseline screen.
#
# This screen asks whether a narrowed PCA-routed, momentum-only hypothesis set
# can improve high-beta upside participation under true shared-account accounting.

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
source(file.path(repo_root, "R", "workbench_data_proof.R"))
source(file.path(repo_root, "R", "strategy_ema_cross.R"))
source(file.path(repo_root, "R", "strategy_bollinger_touch.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_poc.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))
source(file.path(repo_root, "R", "selection_policy_screen.R"))
source(file.path(repo_root, "R", "portfolio_strategy_poc.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

split_csv <- function(x) {
  x <- trimws(unlist(strsplit(as.character(x), ",", fixed = TRUE), use.names = FALSE))
  x[nzchar(x)]
}

unique_symbols <- function(symbols) unique(g5_standardize_symbol(symbols))

with_context <- function(symbols, add_on) unique_symbols(c(symbols, add_on))

pct_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f%%"), 100 * x))
}

num_label <- function(x, digits = 2L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f"), x))
}

md_table <- function(df, cols, n = Inf) {
  if (!is.data.frame(df) || !nrow(df)) return("_No rows._")
  df <- df[seq_len(min(nrow(df), n)), cols, drop = FALSE]
  df[] <- lapply(df, as.character)
  c(
    paste0("| ", paste(cols, collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(cols)), collapse = " | "), " |"),
    apply(df, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  )
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN53_BULL_MOMENTUM_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN53_BULL_MOMENTUM_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN53_BULL_MOMENTUM_STAMP", "20260710"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen53_bull_momentum_specialist", paste0("g53_bullmom_", stamp))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

selection_policies <- c("pooled_family_asset_variant")
entry_replay_semantics <- c("fresh_signal_only", "state_switch_continuation")
min_train_state_rows <- 20L
warmup_days <- 420L
grid_n <- 3L
initial_capital <- as.numeric(env_or("GEN5_GEN53_BULL_MOMENTUM_INITIAL_CAPITAL", "100000"))
strategy_grid_preset <- g5_wfa_strategy_grid_preset(env_or("GEN5_GEN53_BULL_MOMENTUM_STRATEGY_GRID_PRESET", "gen4_daily_default"))
candidate_families <- g5_wfa_candidate_families(split_csv(env_or(
  "GEN5_GEN53_BULL_MOMENTUM_CANDIDATE_FAMILIES",
  "ema_cross,ema_trend,breakout,pullback_in_uptrend,vol_expansion_breakout,donchian_breakout_vol_expand,no_trade"
)))
candidate_families <- unique(c(candidate_families, "no_trade"))
strategy_pool_id <- env_or("GEN5_GEN53_BULL_MOMENTUM_STRATEGY_POOL_ID", "momentum_specialist")
strategy_pool_label <- env_or("GEN5_GEN53_BULL_MOMENTUM_STRATEGY_POOL_LABEL", "Momentum specialist")

windows <- data.frame(
  window_id = c("2020Q3_asof_20200930", "2022Q1_asof_20220331"),
  quarter_id = c("2020Q3", "2022Q1"),
  as_of_timestamp = c("2020-09-30 17:30:00", "2022-03-31 17:30:00"),
  regime_label = c("risk_on_rebound", "rate_shock_drawdown"),
  stringsAsFactors = FALSE
)

broad_context <- c("SPY", "QQQ", "IWM", "SMH", "TLT", "GLD")
screen_specs <- list(
  list(
    screen_id = "HB_apr",
    screen_label = "High-beta growth / active-plus-risk context",
    basket_archetype = "high_beta_growth",
    symbols = unique_symbols(c("AMD", "NVDA", "TSLA", "AAPL", "MSTR")),
    context_symbols = with_context(c("AMD", "NVDA", "TSLA", "AAPL", "MSTR"), broad_context),
    interpretation_note = "First Gen5.3 baseline: hand-picked high-beta basket, active-plus-risk context, behavioral-pool PCA, 3x3 states, and momentum-compatible candidate families only."
  )
)

only_screens <- split_csv(env_or("GEN5_GEN53_BULL_MOMENTUM_ONLY", ""))
if (length(only_screens)) {
  screen_specs <- Filter(function(x) x$screen_id %in% only_screens, screen_specs)
  if (!length(screen_specs)) g5_stop("GEN5_GEN53_BULL_MOMENTUM_ONLY did not match any configured screen_id.")
}
window_override <- split_csv(env_or("GEN5_GEN53_BULL_MOMENTUM_WINDOWS", ""))
if (length(window_override)) {
  windows <- windows[windows$window_id %in% window_override | windows$quarter_id %in% window_override, , drop = FALSE]
  if (!nrow(windows)) g5_stop("GEN5_GEN53_BULL_MOMENTUM_WINDOWS did not match any configured window.")
}

symbol_fit_path <- function(authority_dir, symbol) {
  file.path(authority_dir, "symbol_models", paste0(g5_standardize_symbol(symbol)[[1L]], "_fit.rds"))
}

read_symbol_fit <- function(path) {
  fit <- readRDS(path)
  required <- c("fold", "selected_states", "train_state_performance", "state_coverage", "pca_scores", "pca_model_contract", "fold_model")
  missing <- setdiff(required, names(fit))
  if (length(missing)) g5_stop(paste0("Cached symbol authority fit is missing fields: ", paste(missing, collapse = ",")))
  fit
}

build_symbol_fit_checkpoint <- function(bars, symbol, contract, model_grid, context_symbols, authority_dir) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  path <- symbol_fit_path(authority_dir, symbol)
  if (!isTRUE(refresh) && file.exists(path)) {
    message("Reuse cached symbol fit: ", contract$quarter_id[[1L]], " / ", symbol)
    return(read_symbol_fit(path))
  }
  message("Fit symbol authority: ", contract$quarter_id[[1L]], " / ", symbol)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  fold <- g5_bridge_authority_fold(symbol, contract)
  fitted <- g5_pca_wfa_fit_fold_models(
    bars,
    symbol = symbol,
    folds = fold,
    model_grid = model_grid,
    grid_n = grid_n,
    state_engine = "quantile_grid",
    regime_context_symbols = context_symbols,
    pca_panel_mode = "pooled_asset_day",
    min_train_state_rows = min_train_state_rows
  )
  fitted$selected_states$symbol <- symbol
  fitted$selected_states$quarter_id <- contract$quarter_id[[1L]]
  fitted$train_state_performance$symbol <- symbol
  fitted$train_state_performance$quarter_id <- contract$quarter_id[[1L]]
  fitted$state_coverage$symbol <- symbol
  fitted$state_coverage$quarter_id <- contract$quarter_id[[1L]]
  fitted$pca_scores$symbol <- symbol
  fitted$pca_scores$quarter_id <- contract$quarter_id[[1L]]
  fitted$pca_model_contract$symbol <- symbol
  fitted$pca_model_contract$quarter_id <- contract$quarter_id[[1L]]
  fold$quarter_id <- contract$quarter_id[[1L]]
  fit <- list(
    fold = fold,
    selected_states = fitted$selected_states,
    train_state_performance = fitted$train_state_performance,
    state_coverage = fitted$state_coverage,
    pca_scores = fitted$pca_scores,
    pca_model_contract = fitted$pca_model_contract,
    fold_model = fitted$fold_models[[fold$fold_id[[1L]]]]
  )
  saveRDS(fit, path)
  fit
}

write_authority_packet <- function(authority, authority_dir) {
  dir.create(authority_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- g5_bridge_write_authority_outputs(authority, authority_dir)
  g5_wfa_write_csv(authority$train_state_performance, file.path(authority_dir, "bridge_train_state_performance.csv"))
  paths$train_state_performance_csv <- normalizePath(file.path(authority_dir, "bridge_train_state_performance.csv"), winslash = "/", mustWork = FALSE)
  paths
}

read_full_authority_packet <- function(authority_dir) {
  authority <- g5_bridge_read_authority(authority_dir)
  perf_path <- file.path(authority_dir, "bridge_train_state_performance.csv")
  if (!file.exists(perf_path)) g5_stop(paste0("Missing bridge_train_state_performance.csv in cached authority: ", authority_dir))
  authority$train_state_performance <- utils::read.csv(perf_path, stringsAsFactors = FALSE)
  authority
}

build_authority <- function(spec, bars, quarter_id, authority_dir) {
  if (!isTRUE(refresh) &&
      file.exists(file.path(authority_dir, "bridge_authority_contract.csv")) &&
      file.exists(file.path(authority_dir, "bridge_selected_states.csv")) &&
      file.exists(file.path(authority_dir, "bridge_train_state_performance.csv"))) {
    message("Reuse cached authority: ", spec$screen_id, " / ", quarter_id)
    return(read_full_authority_packet(authority_dir))
  }
  dates <- g5_bridge_authority_contract_dates(quarter_id, train_quarters = 8L)
  authority_as_of <- paste0(dates$train_end_date, " 17:30:00")
  contract <- g5_bridge_contract_frame(
    quarter_id,
    spec$symbols,
    spec$context_symbols,
    authority_as_of,
    refresh,
    g5_git_sha_or_na(repo_root),
    cfg$feed,
    candidate_families,
    strategy_grid_preset
  )
  contract$authority_status <- "RESEARCH_INSPECTION_ONLY"
  contract$research_note <- "Gen5.3 bullish momentum specialist baseline: behavioral-pool PCA, 3x3 quantile states, active-plus-risk context, momentum-compatible candidate families only, live-capital portfolio replay."
  contract$grid_n <- grid_n
  contract$selection_policy <- "base_direct_authority"
  model_grid <- g5_bridge_model_grid(candidate_families = candidate_families, strategy_grid_preset = strategy_grid_preset)
  fits <- lapply(spec$symbols, function(symbol) {
    build_symbol_fit_checkpoint(bars, symbol, contract, model_grid, spec$context_symbols, authority_dir)
  })
  names(fits) <- spec$symbols
  authority <- list(
    contract = contract,
    folds = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$fold)),
    selected_states = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$selected_states)),
    train_state_performance = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$train_state_performance)),
    state_coverage = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$state_coverage)),
    pca_scores = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$pca_scores)),
    pca_model_contract = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$pca_model_contract)),
    model_grid = model_grid,
    fold_models = stats::setNames(lapply(fits, function(x) x$fold_model), spec$symbols)
  )
  write_authority_packet(authority, authority_dir)
  authority
}

make_policy_authority <- function(authority, selection_policy) {
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

replay_symbol_oos <- function(bars, authority, symbol, as_of_date, entry_semantics, lane_id, screen_id, window_id) {
  scored <- g5_bridge_score_authority_symbol(bars, authority, symbol, as_of_date)
  contract <- authority$contract[1L, , drop = FALSE]
  live_start <- as.Date(contract$live_start_date[[1L]])
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
    authority_role = paste0("gen53_bull_momentum_", lane_id),
    entry_replay_semantics = entry_semantics
  )
  for (field in c("replay", "executions", "trades", "pending_actions")) {
    if (is.data.frame(out[[field]]) && nrow(out[[field]])) {
      out[[field]]$screen_id <- screen_id
      out[[field]]$window_id <- window_id
      out[[field]]$lane_id <- lane_id
      out[[field]]$selection_policy <- as.character(authority$contract$selection_policy[[1L]])
      out[[field]]$entry_replay_semantics <- entry_semantics
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

accounting_trade_table <- function(trades, symbol, lane_id, screen_id, window_id) {
  if (!is.data.frame(trades) || !nrow(trades)) return(trades)
  if (!"trade_id" %in% names(trades)) {
    trades$trade_id <- paste(
      "gen53bull",
      screen_id,
      window_id,
      lane_id,
      g5_standardize_symbol(symbol)[[1L]],
      seq_len(nrow(trades)),
      sep = "_"
    )
  }
  trades
}

equity_from_replay <- function(replay) {
  if (!is.data.frame(replay) || !nrow(replay)) return(data.frame())
  replay <- replay[order(as.Date(replay$session_date)), , drop = FALSE]
  close <- suppressWarnings(as.numeric(replay$close))
  ret <- c(0, close[-1L] / close[-length(close)] - 1)
  ret[!is.finite(ret)] <- 0
  pos <- as.character(replay$model_position_after_replay) == "LONG"
  pos_lag <- c(FALSE, pos[-length(pos)])
  data.frame(
    symbol = as.character(replay$symbol),
    session_date = as.Date(replay$session_date),
    close = close,
    strategy_equity = cumprod(1 + ifelse(pos_lag, ret, 0)),
    stringsAsFactors = FALSE
  )
}

drawdown <- function(equity) {
  equity <- suppressWarnings(as.numeric(equity))
  equity / cummax(equity) - 1
}

summarize_accounting <- function(screen_id, basket_archetype, window, lane_id, policy, semantics, accounting, initial_capital) {
  metrics <- g5_portfolio_poc_metrics(accounting$equity, initial_capital)
  baseline_metrics <- g5_portfolio_poc_baseline_metrics(accounting$baselines, initial_capital)
  active_baseline <- baseline_metrics[baseline_metrics$baseline_id == "active_equal_buy_hold", , drop = FALSE]
  spy_baseline <- baseline_metrics[baseline_metrics$baseline_id == "spy_buy_hold", , drop = FALSE]
  exposure <- mean(as.numeric(accounting$equity$open_position_count), na.rm = TRUE) / length(grep("_quantity$", names(accounting$equity)))
  data.frame(
    screen_id = screen_id,
    basket_archetype = basket_archetype,
    window_id = window$window_id[[1L]],
    quarter_id = window$quarter_id[[1L]],
    regime_label = window$regime_label[[1L]],
    lane_id = lane_id,
    selection_policy = policy,
    entry_replay_semantics = semantics,
    total_return = as.numeric(metrics$total_return[[1L]]),
    sharpe = as.numeric(metrics$sharpe[[1L]]),
    max_drawdown = as.numeric(metrics$max_drawdown[[1L]]),
    active_equal_buy_hold_return = if (nrow(active_baseline)) as.numeric(active_baseline$total_return[[1L]]) else NA_real_,
    spy_buy_hold_return = if (nrow(spy_baseline)) as.numeric(spy_baseline$total_return[[1L]]) else NA_real_,
    alpha_vs_active_equal = as.numeric(metrics$total_return[[1L]]) - if (nrow(active_baseline)) as.numeric(active_baseline$total_return[[1L]]) else NA_real_,
    alpha_vs_spy = as.numeric(metrics$total_return[[1L]]) - if (nrow(spy_baseline)) as.numeric(spy_baseline$total_return[[1L]]) else NA_real_,
    mean_open_position_fraction = exposure,
    total_entry_fills = sum(as.integer(accounting$symbol_summary$entry_fills), na.rm = TRUE),
    cash_capped_entries = sum(as.integer(accounting$symbol_summary$cash_capped_entries), na.rm = TRUE),
    skipped_entries = sum(as.integer(accounting$symbol_summary$skipped_entries), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

write_equity_overlay <- function(equity_all, summary, path) {
  aesthetic <- g5_chart_aesthetic()
  screens <- unique(as.character(summary$screen_id))
  windows_plot <- unique(as.character(summary$window_id))
  lane_colors <- c(
    pooled_family_asset_variant__fresh_signal_only = "#9B5DE5",
    pooled_family_asset_variant__state_switch_continuation = "#00A88F"
  )
  grDevices::png(path, width = 3600L, height = 2600L, res = 220L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(length(screens), length(windows_plot)), mar = c(4.5, 4.6, 3, 1), oma = c(0, 0, 3, 0))
  for (screen_id in screens) {
    for (window_id in windows_plot) {
      x <- equity_all[as.character(equity_all$screen_id) == screen_id & as.character(equity_all$window_id) == window_id, , drop = FALSE]
      if (!nrow(x)) {
        graphics::plot.new()
        next
      }
      dates <- sort(unique(as.Date(x$session_date)))
      ylim <- range(c(x$portfolio_equity, x$active_equal_buy_hold_equity, x$spy_buy_hold_equity), na.rm = TRUE)
      pad <- diff(ylim) * 0.07
      if (!is.finite(pad) || pad == 0) pad <- 1000
      graphics::plot(range(dates), ylim + c(-pad, pad), type = "n", xaxt = "n", xlab = "", ylab = "Equity", main = paste(screen_id, window_id, sep = "\n"), col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
      graphics::rect(par("usr")[[1L]], par("usr")[[3L]], par("usr")[[2L]], par("usr")[[4L]], col = aesthetic$panel_background, border = NA)
      graphics::grid(col = aesthetic$grid)
      graphics::axis.Date(1, at = pretty(dates, n = 4), format = "%Y-%m-%d", las = 2, cex.axis = 0.58, col.axis = aesthetic$axis)
      base <- x[!duplicated(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(base$session_date), as.numeric(base$active_equal_buy_hold_equity), col = "#111111", lwd = 1.4, lty = 2)
      graphics::lines(as.Date(base$session_date), as.numeric(base$spy_buy_hold_equity), col = "#777777", lwd = 1.2, lty = 3)
      for (lane_id in names(lane_colors)) {
        lane <- x[as.character(x$lane_id) == lane_id, , drop = FALSE]
        if (nrow(lane)) graphics::lines(as.Date(lane$session_date), as.numeric(lane$portfolio_equity), col = lane_colors[[lane_id]], lwd = 1.8)
      }
      graphics::abline(h = 100000, col = aesthetic$axis, lty = 3)
    }
  }
  graphics::mtext("Gen5.3 Bullish Momentum Specialist Equity Overlay", side = 3, outer = TRUE, line = 1, font = 2, col = aesthetic$text)
  graphics::legend("bottom", inset = -0.02, legend = c("pooled fresh", "pooled continuation", "basket hold", "SPY hold"), col = c(lane_colors, "#111111", "#777777"), lty = c(1, 1, 2, 3), lwd = c(1.8, 1.8, 1.4, 1.2), horiz = TRUE, bty = "n", cex = 0.82, xpd = NA)
  invisible(path)
}

heat_colors <- function(values) {
  values <- suppressWarnings(as.numeric(values))
  max_abs <- max(abs(values), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  vapply(values, function(value) {
    if (!is.finite(value) || value == 0) return("#FFFDF8")
    target <- if (value > 0) "#00A88F" else "#F15A5A"
    grDevices::adjustcolor(target, alpha.f = min(0.95, 0.22 + 0.73 * abs(value) / max_abs))
  }, character(1L))
}

write_alpha_heatmap <- function(summary, path) {
  aesthetic <- g5_chart_aesthetic()
  basket_label <- c(
    high_beta_growth = "High beta"
  )
  policy_label <- c(
    asset_state_direct_spec = "direct",
    pooled_family_asset_variant = "pooled"
  )
  semantics_label <- c(
    fresh_signal_only = "fresh",
    state_switch_continuation = "continuation"
  )
  summary$row_label <- paste(
    basket_label[as.character(summary$basket_archetype)],
    policy_label[as.character(summary$selection_policy)],
    semantics_label[as.character(summary$entry_replay_semantics)]
  )
  rows <- unique(as.character(summary$row_label))
  cols <- unique(as.character(summary$window_id))
  col_labels <- sub("_asof_.*$", "", cols)
  values <- matrix(NA_real_, nrow = length(rows), ncol = length(cols), dimnames = list(rows, cols))
  for (i in seq_len(nrow(summary))) {
    values[summary$row_label[[i]], summary$window_id[[i]]] <- as.numeric(summary$alpha_vs_active_equal[[i]])
  }
  grDevices::png(path, width = 2200L, height = 2300L, res = 220L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(6, 8, 4, 2))
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Alpha vs Equal-Weight Basket Hold", col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  colors <- heat_colors(as.vector(values))
  dim(colors) <- dim(values)
  for (r in seq_len(nrow(values))) {
    y <- nrow(values) - r + 1
    for (c in seq_len(ncol(values))) {
      graphics::rect(c - 0.5, y - 0.5, c + 0.5, y + 0.5, col = colors[r, c], border = aesthetic$grid)
      graphics::text(c, y, labels = pct_label(values[r, c], 1L), cex = 0.72, col = aesthetic$text)
    }
  }
  graphics::axis(1, at = seq_along(cols), labels = col_labels, las = 1, cex.axis = 0.86, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(rows)), labels = rows, las = 1, cex.axis = 0.58, col.axis = aesthetic$axis)
  graphics::mtext("Green means live-capital strategy beat equal-weight basket hold in the same quarter.", side = 1, line = 4.4, cex = 0.72, col = aesthetic$text)
  invisible(path)
}

write_exposure_alpha_scatter <- function(summary, path) {
  aesthetic <- g5_chart_aesthetic()
  colors <- c(high_beta_growth = "#2E86AB")
  pch <- c(fresh_signal_only = 21L, state_switch_continuation = 24L)
  x <- as.numeric(summary$mean_open_position_fraction)
  y <- as.numeric(summary$alpha_vs_active_equal)
  xlim <- range(c(x, 0, 1), na.rm = TRUE)
  ylim <- range(c(y, 0), na.rm = TRUE)
  pad <- diff(ylim) * 0.1
  if (!is.finite(pad) || pad == 0) pad <- 0.03
  grDevices::png(path, width = 1800L, height = 1300L, res = 220L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(5, 5, 4, 2))
  graphics::plot(x, y, type = "n", xlim = xlim, ylim = ylim + c(-pad, pad), xlab = "Mean open-position fraction", ylab = "Alpha vs basket hold", main = "Exposure vs Basket-Relative Alpha", col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(par("usr")[[1L]], par("usr")[[3L]], par("usr")[[2L]], par("usr")[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(col = aesthetic$grid)
  graphics::abline(h = 0, col = aesthetic$axis, lty = 2)
  for (i in seq_len(nrow(summary))) {
    graphics::points(
      x[[i]],
      y[[i]],
      pch = pch[[as.character(summary$entry_replay_semantics[[i]])]],
      bg = colors[[as.character(summary$basket_archetype[[i]])]],
      col = aesthetic$axis,
      cex = ifelse(summary$selection_policy[[i]] == "pooled_family_asset_variant", 1.45, 1.1)
    )
  }
  graphics::legend("bottomleft", legend = names(colors), pt.bg = colors, pch = 21L, bty = "n", cex = 0.78)
  graphics::legend("topright", legend = c("fresh", "continuation", "larger marker = pooled"), pch = c(21L, 24L, 21L), pt.bg = c("#AAAAAA", "#AAAAAA", "#AAAAAA"), bty = "n", cex = 0.78)
  invisible(path)
}

write_trade_tape_contact_sheet <- function(symbol_results_by_lane, path) {
  if (!length(symbol_results_by_lane)) return(invisible(NULL))
  lane_names <- names(symbol_results_by_lane)
  first_lane <- symbol_results_by_lane[[1L]]
  symbols <- names(first_lane)
  if (!length(symbols)) return(invisible(NULL))
  grDevices::png(path, width = 3800L, height = 3000L, res = 190L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(mfrow = c(length(lane_names), length(symbols)), mar = c(3.8, 3.6, 3, 0.8), oma = c(0, 0, 2, 0))
  for (lane_id in lane_names) {
    lane <- symbol_results_by_lane[[lane_id]]
    lane_label <- sub("^([0-9]{4}Q[0-9])__pooled_family_asset_variant__", "\\1 ", lane_id)
    lane_label <- sub("state_switch_continuation", "continuation", lane_label)
    lane_label <- sub("fresh_signal_only", "fresh", lane_label)
    for (symbol in symbols) {
      result <- lane[[symbol]]
      if (is.null(result)) {
        graphics::plot.new()
        next
      }
      g5_bridge_plot_panel(
        result$replay_oos,
        result$executions,
        result$pending_actions,
        result$trades,
        main = paste(symbol, lane_label, sep = " / ")
      )
    }
  }
  graphics::mtext("Gen5.3 Bullish Momentum Specialist Trade Tapes", side = 3, outer = TRUE, line = 0.5, font = 2)
  invisible(path)
}

write_selection_family_heatmap <- function(selected_states, path) {
  if (!is.data.frame(selected_states) || !nrow(selected_states)) return(invisible(NULL))
  aesthetic <- g5_chart_aesthetic()
  selected_states$symbol <- as.character(selected_states$symbol)
  selected_states$state_id <- as.character(selected_states$state_id)
  selected_states$strategy_family <- as.character(selected_states$strategy_family)
  selected_states <- do.call(rbind, lapply(split(selected_states, paste(selected_states$symbol, selected_states$state_id, sep = "::")), function(x) {
    tab <- sort(table(x$strategy_family), decreasing = TRUE)
    data.frame(
      symbol = x$symbol[[1L]],
      state_id = x$state_id[[1L]],
      strategy_family = names(tab)[[1L]],
      selected_count = as.integer(tab[[1L]]),
      selected_total = nrow(x),
      stringsAsFactors = FALSE
    )
  }))
  states <- sort(unique(selected_states$state_id))
  symbols <- sort(unique(selected_states$symbol))
  family_palette <- c(
    no_trade = "#D1D5DB",
    ema_cross = "#2563EB",
    ema_trend = "#00A88F",
    breakout = "#277DA1",
    pullback_in_uptrend = "#43AA8B",
    vol_expansion_breakout = "#F8961E",
    donchian_breakout_vol_expand = "#577590"
  )
  family_label <- c(
    no_trade = "Cash",
    ema_cross = "EMA cross",
    ema_trend = "EMA trend",
    breakout = "Breakout",
    pullback_in_uptrend = "Pullback",
    vol_expansion_breakout = "Vol BO",
    donchian_breakout_vol_expand = "Donchian BO"
  )
  grDevices::png(path, width = 2600L, height = 1700L, res = 220L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(5, 5, 4, 8))
  graphics::plot(NA, xlim = c(0.5, length(states) + 0.5), ylim = c(0.5, length(symbols) + 0.5), xaxt = "n", yaxt = "n", xlab = "PCA state", ylab = "Symbol", main = "Selected Strategy Family by Asset and State", col.main = aesthetic$text, col.axis = aesthetic$axis, col.lab = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, length(states) + 0.5, length(symbols) + 0.5, col = aesthetic$panel_background, border = NA)
  for (i in seq_len(nrow(selected_states))) {
    x <- match(selected_states$state_id[[i]], states)
    y <- length(symbols) - match(selected_states$symbol[[i]], symbols) + 1L
    fam <- selected_states$strategy_family[[i]]
    fill <- family_palette[[fam]]
    if (is.null(fill) || is.na(fill)) fill <- "#F5F7FA"
    graphics::rect(x - 0.5, y - 0.5, x + 0.5, y + 0.5, col = fill, border = aesthetic$grid)
    label <- paste0(family_label[[fam]], "\n", selected_states$selected_count[[i]], "/", selected_states$selected_total[[i]])
    graphics::text(x, y, labels = label, cex = 0.44, col = if (identical(fam, "no_trade")) aesthetic$text else "white", font = 2)
  }
  graphics::axis(1, at = seq_along(states), labels = states, las = 2, cex.axis = 0.72, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(symbols)), labels = symbols, las = 1, cex.axis = 0.82, col.axis = aesthetic$axis)
  present <- intersect(names(family_palette), unique(selected_states$strategy_family))
  graphics::legend("right", inset = -0.08, legend = unname(family_label[present]), fill = family_palette[present], bty = "n", cex = 0.62, xpd = NA)
  invisible(path)
}

write_report <- function(paths, run_spec, summary, aggregate) {
  printable <- summary
  for (col in c("total_return", "active_equal_buy_hold_return", "alpha_vs_active_equal", "max_drawdown", "mean_open_position_fraction")) {
    printable[[col]] <- pct_label(printable[[col]], 1L)
  }
  printable$sharpe <- num_label(printable$sharpe, 2L)
  agg <- aggregate
  for (col in c("mean_total_return", "mean_alpha_vs_active_equal", "mean_exposure", "worst_drawdown")) {
    agg[[col]] <- pct_label(agg[[col]], 1L)
  }
  lines <- c(
    "# Gen5.3 Bullish Momentum Specialist Baseline",
    "",
    "## Plain-Language Purpose",
    "",
    "This screen deliberately narrows the PCA engine's job. Instead of asking one universal router to trade every market behavior, it asks whether behavioral-pool PCA can act as a participation filter for a hand-picked high-beta bullish basket.",
    "",
    "The intent is to establish a clean baseline before adding TRAIN-only basket curation or new feature sets. If the specialist cannot participate well in its own chosen domain, expanding the system would only hide the problem.",
    "",
    "## Design",
    "",
    "- PCA/state surface: behavioral-pool long PCA plus `3x3` quantile states.",
    "- Context recipe: high-beta basket plus active-plus-risk anchors `SPY,QQQ,IWM,SMH,TLT,GLD`; no `VXX`.",
    "- Strategy pool: implemented momentum-compatible families plus `no_trade`.",
    "- Selection policy: pooled-family asset-variant, held fixed so this first slice tests specialist participation rather than reopening selection-policy as a factor.",
    "- Replay semantics: fresh-signal-only versus state-switch continuation.",
    "- Accounting: true shared-account live-capital replay with dynamic equal-slot, cash-capped entries.",
    "- Benchmark: equal-weight buy-and-hold of the exact live basket over the same quarter, plus SPY reference.",
    "",
    "## Run Spec",
    "",
    md_table(run_spec, c("screen_id", "basket_archetype", "symbols", "context_symbols", "window_id", "selection_policy", "entry_replay_semantics"), n = 18L),
    "",
    "## Live-Capital Summary",
    "",
    md_table(printable, c("screen_id", "window_id", "selection_policy", "entry_replay_semantics", "total_return", "active_equal_buy_hold_return", "alpha_vs_active_equal", "mean_open_position_fraction", "total_entry_fills", "max_drawdown")),
    "",
    "## Aggregate Readout",
    "",
    md_table(agg, c("basket_archetype", "selection_policy", "entry_replay_semantics", "windows_tested", "windows_beating_basket", "mean_total_return", "mean_alpha_vs_active_equal", "mean_exposure", "worst_drawdown")),
    "",
    "## Visual Outputs",
    "",
    paste0("- Equity overlay: `", paths$equity_overlay_png, "`"),
    paste0("- Alpha heatmap: `", paths$alpha_heatmap_png, "`"),
    paste0("- Exposure/alpha scatter: `", paths$exposure_alpha_scatter_png, "`"),
    paste0("- Selection family heatmap: `", paths$selection_family_heatmap_png, "`"),
    paste0("- Trade tape contact sheet: `", paths$trade_tape_contact_sheet_png, "`"),
    "",
    "## Guardrails",
    "",
    "- Authority is fit from TRAIN only for each quarter and basket.",
    "- OOS replay consumes frozen state maps and selected strategy authority.",
    "- The screen is research/inspection only and does not change live advice behavior.",
    "- Performance is not accepted allocation evidence.",
    "- Mean-reversion families and SMA families are intentionally excluded from this first specialist baseline."
  )
  writeLines(unlist(lines), paths$report_md, useBytes = TRUE)
}

screen_rows <- list()
replay_rows <- list()
trade_rows <- list()
execution_rows <- list()
pending_rows <- list()
equity_rows <- list()
event_rows <- list()
standalone_rows <- list()
symbol_summary_rows <- list()
summary_rows <- list()
authority_rows <- list()
packet_rows <- list()
trade_tape_symbol_results <- list()

message("Gen5.3 bullish momentum specialist baseline")
message("Output: ", output_dir)
message("Feed: ", cfg$feed)
message("Refresh: ", refresh)
message("Strategy pool: ", strategy_pool_id, " / ", strategy_pool_label)
message("Strategy grid preset: ", strategy_grid_preset)
message("Candidate families: ", paste(candidate_families, collapse = ","))

for (spec in screen_specs) {
  screen_dir <- file.path(output_dir, spec$screen_id)
  dir.create(screen_dir, recursive = TRUE, showWarnings = FALSE)
  dates <- lapply(windows$quarter_id, g5_bridge_authority_contract_dates, train_quarters = 8L)
  start_date <- min(as.Date(vapply(dates, function(x) as.character(x$train_start_date), character(1L)))) - warmup_days
  end_date <- max(as.Date(substr(windows$as_of_timestamp, 1L, 10L)))
  query_symbols <- unique(c(spec$symbols, spec$context_symbols, "SPY"))
  message("")
  message("Query bars: ", spec$screen_id, " / ", start_date, " through ", end_date)
  query <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = start_date,
    end_date = end_date,
    as_of_timestamp = paste0(end_date, " 17:30:00"),
    symbols = query_symbols,
    universe_name = paste0("gen53_bull_momentum_", spec$screen_id),
    universe_roles = "regime_context_universe,active_allocation_set,baseline_reference",
    refresh = refresh,
    repo_root = repo_root
  )
  for (symbol in spec$symbols) g5_require_chartable_symbol(query, symbol = symbol, refresh = refresh)
  g5_require_chartable_symbol(query, symbol = "SPY", refresh = refresh)
  query_dir <- file.path(screen_dir, "query")
  dir.create(query_dir, recursive = TRUE, showWarnings = FALSE)
  query_paths <- g5_write_workbench_query_artifacts(query, output_dir = query_dir, prefix = paste0("q_", spec$screen_id))
  bars <- query$bars
  bars$session_date <- as.Date(bars$session_date)

  for (w in seq_len(nrow(windows))) {
    window <- windows[w, , drop = FALSE]
    authority_dir <- file.path(screen_dir, "auth", window$quarter_id[[1L]])
    authority_base <- build_authority(spec, bars, window$quarter_id[[1L]], authority_dir)
    policy_authorities <- stats::setNames(lapply(selection_policies, function(policy) make_policy_authority(authority_base, policy)), selection_policies)
    policy_states <- g5_wfa_bind_rows_fill(lapply(policy_authorities, function(x) x$selected_states))
    policy_states$screen_id <- spec$screen_id
    policy_states$window_id <- window$window_id[[1L]]
    authority_rows[[length(authority_rows) + 1L]] <- policy_states
    as_of_date <- as.Date(substr(window$as_of_timestamp[[1L]], 1L, 10L))
    replay_bars <- bars[as.Date(bars$session_date) <= as_of_date, , drop = FALSE]
    for (policy in selection_policies) {
      for (semantics in entry_replay_semantics) {
        lane_id <- paste(policy, semantics, sep = "__")
        message("Replay/accounting: ", spec$screen_id, " / ", window$window_id[[1L]], " / ", lane_id)
        results <- stats::setNames(vector("list", length(spec$symbols)), spec$symbols)
        for (symbol in spec$symbols) {
          results[[symbol]] <- replay_symbol_oos(
            replay_bars,
            policy_authorities[[policy]],
            symbol,
            as_of_date,
            semantics,
            lane_id,
            spec$screen_id,
            window$window_id[[1L]]
          )
        }
        if (identical(spec$screen_id, "HB_apr")) {
          trade_tape_symbol_results[[paste(window$quarter_id[[1L]], lane_id, sep = "__")]] <- results
        }
        trades_by_symbol <- stats::setNames(lapply(spec$symbols, function(symbol) {
          accounting_trade_table(results[[symbol]]$trades, symbol, lane_id, spec$screen_id, window$window_id[[1L]])
        }), spec$symbols)
        equity_by_symbol <- stats::setNames(lapply(results, function(x) equity_from_replay(x$replay_oos)), spec$symbols)
        accounting <- g5_portfolio_poc_build_accounting(
          trades_by_symbol = trades_by_symbol,
          equity_by_symbol = equity_by_symbol,
          active_symbols = spec$symbols,
          initial_capital = initial_capital,
          slot_count = length(spec$symbols)
        )
        accounting$baselines <- g5_portfolio_poc_build_baselines(
          bars = replay_bars,
          dates = accounting$equity$session_date,
          active_symbols = spec$symbols,
          initial_capital = initial_capital,
          baseline_symbol = "SPY"
        )
        eq <- accounting$equity
        base <- accounting$baselines
        eq$screen_id <- spec$screen_id
        eq$basket_archetype <- spec$basket_archetype
        eq$window_id <- window$window_id[[1L]]
        eq$quarter_id <- window$quarter_id[[1L]]
        eq$regime_label <- window$regime_label[[1L]]
        eq$lane_id <- lane_id
        eq$selection_policy <- policy
        eq$entry_replay_semantics <- semantics
        eq$active_equal_buy_hold_equity <- base$active_equal_buy_hold_equity[match(as.Date(eq$session_date), as.Date(base$session_date))]
        eq$spy_buy_hold_equity <- base$spy_buy_hold_equity[match(as.Date(eq$session_date), as.Date(base$session_date))]
        equity_rows[[length(equity_rows) + 1L]] <- eq
        ev <- accounting$events
        if (is.data.frame(ev) && nrow(ev)) {
          ev$screen_id <- spec$screen_id
          ev$basket_archetype <- spec$basket_archetype
          ev$window_id <- window$window_id[[1L]]
          ev$quarter_id <- window$quarter_id[[1L]]
          ev$lane_id <- lane_id
          ev$selection_policy <- policy
          ev$entry_replay_semantics <- semantics
          event_rows[[length(event_rows) + 1L]] <- ev
        }
        standalone <- accounting$standalone_symbol_equity
        standalone$screen_id <- spec$screen_id
        standalone$basket_archetype <- spec$basket_archetype
        standalone$window_id <- window$window_id[[1L]]
        standalone$quarter_id <- window$quarter_id[[1L]]
        standalone$lane_id <- lane_id
        standalone$selection_policy <- policy
        standalone$entry_replay_semantics <- semantics
        standalone_rows[[length(standalone_rows) + 1L]] <- standalone
        sym <- accounting$symbol_summary
        sym$screen_id <- spec$screen_id
        sym$basket_archetype <- spec$basket_archetype
        sym$window_id <- window$window_id[[1L]]
        sym$quarter_id <- window$quarter_id[[1L]]
        sym$lane_id <- lane_id
        sym$selection_policy <- policy
        sym$entry_replay_semantics <- semantics
        symbol_summary_rows[[length(symbol_summary_rows) + 1L]] <- sym
        summary_rows[[length(summary_rows) + 1L]] <- summarize_accounting(spec$screen_id, spec$basket_archetype, window, lane_id, policy, semantics, accounting, initial_capital)
        replay_rows[[length(replay_rows) + 1L]] <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$replay_oos))
        trade_rows[[length(trade_rows) + 1L]] <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$trades))
        execution_rows[[length(execution_rows) + 1L]] <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$executions))
        pending_rows[[length(pending_rows) + 1L]] <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$pending_actions))
        packet_rows[[length(packet_rows) + 1L]] <- data.frame(
          screen_id = spec$screen_id,
          basket_archetype = spec$basket_archetype,
          strategy_pool_id = strategy_pool_id,
          window_id = window$window_id[[1L]],
          quarter_id = window$quarter_id[[1L]],
          selection_policy = policy,
          entry_replay_semantics = semantics,
          lane_id = lane_id,
          authority_dir = normalizePath(authority_dir, winslash = "/", mustWork = FALSE),
          query_manifest_csv = normalizePath(query_paths$paths$manifest_csv, winslash = "/", mustWork = FALSE),
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

run_spec <- do.call(rbind, lapply(screen_specs, function(spec) {
  data.frame(
    screen_id = spec$screen_id,
    screen_label = spec$screen_label,
    basket_archetype = spec$basket_archetype,
    strategy_pool_id = strategy_pool_id,
    strategy_pool_label = strategy_pool_label,
    symbols = paste(spec$symbols, collapse = ","),
    context_symbols = paste(spec$context_symbols, collapse = ","),
    context_recipe = "active_plus_risk_context_no_vxx",
    pca_panel_mode = "pooled_asset_day",
    state_engine = "quantile_grid",
    grid_n = grid_n,
    strategy_grid_preset = strategy_grid_preset,
    candidate_families = paste(candidate_families, collapse = ","),
    min_train_state_rows = min_train_state_rows,
    initial_capital = initial_capital,
    interpretation_note = spec$interpretation_note,
    stringsAsFactors = FALSE
  )
}))
run_spec <- merge(run_spec, windows[, c("window_id", "quarter_id", "as_of_timestamp", "regime_label"), drop = FALSE], by = NULL)
run_spec <- merge(run_spec, expand.grid(selection_policy = selection_policies, entry_replay_semantics = entry_replay_semantics, stringsAsFactors = FALSE), by = NULL)
run_spec$research_only <- TRUE
run_spec$output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)

summary <- g5_wfa_bind_rows_fill(summary_rows)
summary <- summary[order(summary$screen_id, summary$window_id, summary$selection_policy, summary$entry_replay_semantics), , drop = FALSE]
aggregate <- do.call(rbind, lapply(split(summary, paste(summary$basket_archetype, summary$selection_policy, summary$entry_replay_semantics, sep = "|")), function(x) {
  data.frame(
    basket_archetype = x$basket_archetype[[1L]],
    strategy_pool_id = strategy_pool_id,
    selection_policy = x$selection_policy[[1L]],
    entry_replay_semantics = x$entry_replay_semantics[[1L]],
    windows_tested = nrow(x),
    windows_beating_basket = sum(as.numeric(x$alpha_vs_active_equal) > 0, na.rm = TRUE),
    mean_total_return = mean(as.numeric(x$total_return), na.rm = TRUE),
    mean_alpha_vs_active_equal = mean(as.numeric(x$alpha_vs_active_equal), na.rm = TRUE),
    mean_exposure = mean(as.numeric(x$mean_open_position_fraction), na.rm = TRUE),
    worst_drawdown = min(as.numeric(x$max_drawdown), na.rm = TRUE),
    total_entry_fills = sum(as.integer(x$total_entry_fills), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
aggregate <- aggregate[order(aggregate$basket_archetype, aggregate$selection_policy, aggregate$entry_replay_semantics), , drop = FALSE]

paths <- list(
  run_spec_csv = file.path(output_dir, "bull_momentum_specialist_run_spec.csv"),
  packet_index_csv = file.path(output_dir, "bull_momentum_specialist_packet_index.csv"),
  selected_states_csv = file.path(output_dir, "bull_momentum_specialist_selected_states.csv"),
  replay_oos_csv = file.path(output_dir, "bull_momentum_specialist_replay_oos.csv"),
  executions_csv = file.path(output_dir, "bull_momentum_specialist_executions.csv"),
  trades_csv = file.path(output_dir, "bull_momentum_specialist_trades.csv"),
  pending_csv = file.path(output_dir, "bull_momentum_specialist_pending_actions.csv"),
  portfolio_equity_csv = file.path(output_dir, "bull_momentum_specialist_portfolio_equity.csv"),
  portfolio_events_csv = file.path(output_dir, "bull_momentum_specialist_portfolio_events.csv"),
  standalone_symbol_equity_csv = file.path(output_dir, "bull_momentum_specialist_standalone_symbol_equity.csv"),
  symbol_summary_csv = file.path(output_dir, "bull_momentum_specialist_symbol_summary.csv"),
  summary_csv = file.path(output_dir, "bull_momentum_specialist_summary.csv"),
  aggregate_csv = file.path(output_dir, "bull_momentum_specialist_aggregate.csv"),
  equity_overlay_png = file.path(output_dir, "bull_momentum_specialist_equity_overlay.png"),
  alpha_heatmap_png = file.path(output_dir, "bull_momentum_specialist_alpha_heatmap.png"),
  exposure_alpha_scatter_png = file.path(output_dir, "bull_momentum_specialist_exposure_alpha_scatter.png"),
  selection_family_heatmap_png = file.path(output_dir, "bull_momentum_specialist_selection_family_heatmap.png"),
  trade_tape_contact_sheet_png = file.path(output_dir, "bull_momentum_specialist_trade_tape_contact_sheet.png"),
  artifact_index_csv = file.path(output_dir, "bull_momentum_specialist_artifact_index.csv"),
  report_md = file.path(output_dir, "bull_momentum_specialist_report.md")
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(packet_rows), paths$packet_index_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(authority_rows), paths$selected_states_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(replay_rows), paths$replay_oos_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(execution_rows), paths$executions_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(trade_rows), paths$trades_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(pending_rows), paths$pending_csv)
equity_all <- g5_wfa_bind_rows_fill(equity_rows)
g5_wfa_write_csv(equity_all, paths$portfolio_equity_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(event_rows), paths$portfolio_events_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(standalone_rows), paths$standalone_symbol_equity_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(symbol_summary_rows), paths$symbol_summary_csv)
g5_wfa_write_csv(summary, paths$summary_csv)
g5_wfa_write_csv(aggregate, paths$aggregate_csv)
write_equity_overlay(equity_all, summary, paths$equity_overlay_png)
write_alpha_heatmap(summary, paths$alpha_heatmap_png)
write_exposure_alpha_scatter(summary, paths$exposure_alpha_scatter_png)
write_selection_family_heatmap(g5_wfa_bind_rows_fill(authority_rows), paths$selection_family_heatmap_png)
write_trade_tape_contact_sheet(trade_tape_symbol_results, paths$trade_tape_contact_sheet_png)

artifact_index <- data.frame(
  artifact = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_report(paths, run_spec, summary, aggregate)

printable <- summary
for (col in c("total_return", "active_equal_buy_hold_return", "alpha_vs_active_equal", "mean_open_position_fraction", "max_drawdown")) {
  printable[[col]] <- pct_label(printable[[col]], 1L)
}
message("")
message("Gen5.3 bullish momentum specialist screen complete: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Summary:")
print(printable[, c("screen_id", "window_id", "selection_policy", "entry_replay_semantics", "total_return", "active_equal_buy_hold_return", "alpha_vs_active_equal", "mean_open_position_fraction", "total_entry_fills"), drop = FALSE], row.names = FALSE)
message("")
message("Report: ", paths$report_md)
message("Deck visuals: ", paths$equity_overlay_png, " / ", paths$alpha_heatmap_png, " / ", paths$exposure_alpha_scatter_png, " / ", paths$selection_family_heatmap_png, " / ", paths$trade_tape_contact_sheet_png)
