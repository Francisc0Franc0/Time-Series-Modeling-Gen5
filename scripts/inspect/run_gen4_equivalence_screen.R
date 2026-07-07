# Gen4-equivalence inspection screen for Gen5.1.

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

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

parse_bool <- function(x, default = FALSE) {
  g5_parse_bool_env(as.character(x), default = default)
}

parse_csv_env <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) return(default)
  out <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  out[nzchar(out)]
}

pct_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f%%"), 100 * x))
}

pp_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f pp"), 100 * x))
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

quarter_sequence <- function(first_quarter, last_quarter) {
  out <- character()
  q <- first_quarter
  repeat {
    out <- c(out, q)
    if (identical(q, last_quarter)) break
    q <- g5_bridge_next_quarter_id(q)
  }
  out
}

train_quarters_since_2016q4 <- function(quarter_id) {
  bounds <- g5_bridge_quarter_bounds(quarter_id)
  train_end_quarter <- g5_bridge_previous_quarter_id(bounds$quarter_id)
  length(quarter_sequence("2016Q4", train_end_quarter))
}

custom_contract_frame <- function(
  quarter_id,
  symbols,
  context_symbols,
  as_of_timestamp,
  refresh,
  git_sha,
  market_data_feed,
  candidate_families,
  strategy_grid_preset,
  grid_n,
  research_note
) {
  bounds <- g5_bridge_quarter_bounds(quarter_id)
  train_quarters <- train_quarters_since_2016q4(bounds$quarter_id)
  symbols <- g5_standardize_symbol(symbols)
  context_symbols <- unique(g5_standardize_symbol(context_symbols))
  candidate_families <- unique(c(g5_wfa_candidate_families(candidate_families), "no_trade"))
  strategy_grid_preset <- g5_wfa_strategy_grid_preset(strategy_grid_preset)
  data.frame(
    schema_version = g5_live_bridge_schema_version(),
    quarter_id = bounds$quarter_id,
    authority_status = "RESEARCH_INSPECTION_ONLY",
    research_note = research_note,
    symbols = paste(symbols, collapse = ","),
    context_symbols = paste(context_symbols, collapse = ","),
    train_start_date = as.Date("2016-10-01"),
    train_end_date = bounds$live_start_date - 1L,
    live_start_date = bounds$live_start_date,
    live_end_date = bounds$live_end_date,
    train_quarters = train_quarters,
    live_quarters = 1L,
    pca_panel_mode = "pooled_asset_day",
    pca_panel_label = "long_pca_behavioral_pool",
    state_engine = "quantile_grid",
    grid_n = as.integer(grid_n),
    strategy_grid_preset = strategy_grid_preset,
    candidate_families = paste(candidate_families, collapse = ","),
    position_source = "quarterly_model_replay_one_bar_delay",
    advice_mode = "research_inspection_not_live_advice",
    market_data_feed = as.character(market_data_feed),
    as_of_timestamp = as.character(as_of_timestamp),
    refresh = isTRUE(refresh),
    git_sha = as.character(git_sha),
    stringsAsFactors = FALSE
  )
}

symbol_fit_path <- function(authority_dir, symbol) {
  file.path(authority_dir, "symbol_models", paste0(g5_standardize_symbol(symbol)[[1L]], "_fit.rds"))
}

read_symbol_fit <- function(path) {
  fit <- readRDS(path)
  required <- c("fold", "selected_states", "train_state_performance", "state_coverage", "pca_scores", "pca_model_contract", "fold_model")
  missing <- setdiff(required, names(fit))
  if (length(missing)) {
    g5_stop(paste0("Cached symbol authority fit is missing fields: ", paste(missing, collapse = ",")))
  }
  fit
}

build_symbol_fit_checkpoint <- function(bars, symbol, contract, model_grid, context_symbols, authority_dir, grid_n, min_train_state_rows, refresh) {
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

write_authority_packet <- function(authority, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- g5_bridge_write_authority_outputs(authority, output_dir)
  if (is.data.frame(authority$train_state_performance)) {
    g5_wfa_write_csv(authority$train_state_performance, file.path(output_dir, "bridge_train_state_performance.csv"))
  }
  paths$train_state_performance_csv <- normalizePath(file.path(output_dir, "bridge_train_state_performance.csv"), winslash = "/", mustWork = FALSE)
  paths
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

numeric_match <- function(lhs, rhs, tolerance = 1e-9) {
  lhs <- suppressWarnings(as.numeric(lhs))
  rhs <- suppressWarnings(as.numeric(rhs))
  (is.na(lhs) & is.na(rhs)) | (!is.na(lhs) & !is.na(rhs) & abs(lhs - rhs) <= tolerance)
}

family_from_gen4 <- function(family) {
  family <- as.character(family)
  ifelse(family == "bb_touch", "bollinger_touch", family)
}

model_grid_empty_row <- function(model_grid) {
  row <- model_grid[1L, , drop = FALSE]
  for (name in names(row)) {
    if (is.character(row[[name]])) {
      row[[name]] <- NA_character_
    } else if (is.integer(row[[name]])) {
      row[[name]] <- NA_integer_
    } else if (is.numeric(row[[name]])) {
      row[[name]] <- NA_real_
    } else {
      row[[name]] <- NA
    }
  }
  row
}

safe_model_id <- function(x) {
  out <- gsub("[^0-9A-Za-z]+", "_", as.character(x))
  out <- gsub("_+", "_", out)
  gsub("^_|_$", "", out)
}

num_label <- function(x) {
  suppressWarnings(as.numeric(gsub("p", ".", as.character(x), fixed = TRUE)))
}

strategy_nums <- function(strategy, pattern) {
  m <- regexec(pattern, as.character(strategy), perl = TRUE)
  parts <- regmatches(as.character(strategy), m)[[1L]]
  if (length(parts) <= 1L) return(numeric())
  num_label(parts[-1L])
}

valid_num <- function(x, min_value = -Inf, allow_equal = TRUE) {
  x <- suppressWarnings(as.numeric(x))
  is.finite(x) && if (isTRUE(allow_equal)) x >= min_value else x > min_value
}

model_grid_from_gen4_picked_specs <- function(model_grid, picked_params_csv) {
  if (!file.exists(picked_params_csv)) {
    g5_stop(paste0("Cannot build Gen4 picked specs because file is missing: ", picked_params_csv))
  }
  picks <- utils::read.csv(picked_params_csv, stringsAsFactors = FALSE)
  required <- c("family", "param_1", "param_2", "param_3", "param_4")
  missing <- setdiff(required, names(picks))
  if (length(missing)) {
    g5_stop(paste0("Gen4 picked params file is missing columns: ", paste(missing, collapse = ",")))
  }
  rows <- list(model_grid[model_grid$strategy_family == "no_trade", , drop = FALSE][1L, , drop = FALSE])
  unmatched <- character()
  for (i in seq_len(nrow(picks))) {
    family <- family_from_gen4(picks$family[[i]])
    strategy <- if ("strategy" %in% names(picks)) as.character(picks$strategy[[i]]) else as.character(i)
    row <- model_grid_empty_row(model_grid)
    row$strategy_family <- family
    row$model_instance_id <- paste0("gen4picked_", safe_model_id(family), "_", safe_model_id(strategy))
    if (family %in% c("ema_cross", "ema_trend")) {
      nums <- strategy_nums(strategy, "f([0-9]+)_s([0-9]+)")
      row$fast_period <- if (length(nums) >= 1L) nums[[1L]] else suppressWarnings(as.numeric(picks$param_1[[i]]))
      row$slow_period <- if (length(nums) >= 2L) nums[[2L]] else suppressWarnings(as.numeric(picks$param_2[[i]]))
      if (identical(family, "ema_trend")) {
        row$ema_trend_slope_lookback <- 3
        row$ema_trend_entry_mode <- "slope_positive"
        row$ema_trend_exit_mode <- "trend_off"
      }
    } else if (identical(family, "bollinger_touch")) {
      nums <- strategy_nums(strategy, "n([0-9]+)_k([0-9p.]+)")
      row$lookback_period <- if (length(nums) >= 1L) nums[[1L]] else suppressWarnings(as.numeric(picks$param_1[[i]]))
      row$sd_multiplier <- if (length(nums) >= 2L) nums[[2L]] else suppressWarnings(as.numeric(picks$param_2[[i]]))
    } else if (identical(family, "rsi_mr")) {
      nums <- strategy_nums(strategy, "n([0-9]+)_lo([0-9p.]+)_hi([0-9p.]+)")
      row$rsi_period <- if (length(nums) >= 1L) nums[[1L]] else suppressWarnings(as.numeric(picks$param_1[[i]]))
      row$rsi_lower <- if (length(nums) >= 2L) nums[[2L]] else suppressWarnings(as.numeric(picks$param_2[[i]]))
      row$rsi_upper <- if (length(nums) >= 3L) nums[[3L]] else suppressWarnings(as.numeric(picks$param_3[[i]]))
    } else if (identical(family, "zret_mr")) {
      nums <- strategy_nums(strategy, "n([0-9]+)_ent([0-9p.]+)_ex([0-9p.]+)")
      row$zret_window <- if (length(nums) >= 1L) nums[[1L]] else suppressWarnings(as.numeric(picks$param_1[[i]]))
      row$zret_entry_z <- if (length(nums) >= 2L) nums[[2L]] else suppressWarnings(as.numeric(picks$param_2[[i]]))
      row$zret_exit_z <- if (length(nums) >= 3L) nums[[3L]] else suppressWarnings(as.numeric(picks$param_3[[i]]))
    } else if (identical(family, "pullback_in_uptrend")) {
      nums <- strategy_nums(strategy, "f([0-9]+)_s([0-9]+)_lo([0-9p.]+)_hi([0-9p.]+)")
      row$fast_period <- if (length(nums) >= 1L) nums[[1L]] else suppressWarnings(as.numeric(picks$param_1[[i]]))
      row$slow_period <- if (length(nums) >= 2L) nums[[2L]] else suppressWarnings(as.numeric(picks$param_2[[i]]))
      row$rsi_period <- 14
      row$rsi_lower <- if (length(nums) >= 3L) nums[[3L]] else suppressWarnings(as.numeric(picks$param_3[[i]]))
      row$rsi_upper <- if (length(nums) >= 4L) nums[[4L]] else suppressWarnings(as.numeric(picks$param_4[[i]]))
    } else {
      unmatched <- unique(c(unmatched, paste0(as.character(picks$family[[i]]), ":", strategy)))
      next
    }
    valid <- switch(
      family,
      ema_cross = valid_num(row$fast_period, 1) && valid_num(row$slow_period, 2) && as.numeric(row$fast_period) < as.numeric(row$slow_period),
      ema_trend = valid_num(row$fast_period, 1) && valid_num(row$slow_period, 2) && as.numeric(row$fast_period) < as.numeric(row$slow_period),
      bollinger_touch = valid_num(row$lookback_period, 2) && valid_num(row$sd_multiplier, 0, allow_equal = FALSE),
      rsi_mr = valid_num(row$rsi_period, 2) && valid_num(row$rsi_lower, 0) && valid_num(row$rsi_upper, 0) && as.numeric(row$rsi_lower) < as.numeric(row$rsi_upper),
      zret_mr = valid_num(row$zret_window, 2) && valid_num(row$zret_entry_z, 0, allow_equal = FALSE) && valid_num(row$zret_exit_z, 0),
      pullback_in_uptrend = valid_num(row$fast_period, 1) && valid_num(row$slow_period, 2) && as.numeric(row$fast_period) < as.numeric(row$slow_period) && valid_num(row$rsi_lower, 0) && valid_num(row$rsi_upper, 0) && as.numeric(row$rsi_lower) < as.numeric(row$rsi_upper),
      FALSE
    )
    if (!isTRUE(valid)) {
      unmatched <- unique(c(unmatched, paste0("invalid_params:", as.character(picks$family[[i]]), ":", strategy)))
      next
    }
    rows[[length(rows) + 1L]] <- row
  }
  out <- g5_wfa_bind_rows_fill(rows)
  key_cols <- setdiff(names(out), "model_instance_id")
  out <- out[!duplicated(out[, key_cols, drop = FALSE]), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "unmatched_gen4_specs") <- unmatched
  out
}

build_authority <- function(bars, quarter_id, authority_dir, settings) {
  if (!isTRUE(settings$refresh) &&
      file.exists(file.path(authority_dir, "bridge_authority_contract.csv")) &&
      file.exists(file.path(authority_dir, "bridge_selected_states.csv")) &&
      file.exists(file.path(authority_dir, "bridge_train_state_performance.csv"))) {
    message("Reuse cached authority: ", quarter_id)
    return(read_full_authority_packet(authority_dir))
  }
  dates <- g5_bridge_quarter_bounds(quarter_id)
  contract <- custom_contract_frame(
    quarter_id = quarter_id,
    symbols = settings$symbols,
    context_symbols = settings$context_symbols,
    as_of_timestamp = paste0(dates$live_start_date - 1L, " 17:30:00"),
    refresh = settings$refresh,
    git_sha = g5_git_sha_or_na(repo_root),
    market_data_feed = settings$feed,
    candidate_families = settings$candidate_families,
    strategy_grid_preset = settings$strategy_grid_preset,
    grid_n = settings$grid_n,
    research_note = settings$research_note
  )
  model_grid <- settings$model_grid
  fits <- lapply(settings$symbols, function(symbol) {
    build_symbol_fit_checkpoint(
      bars = bars,
      symbol = symbol,
      contract = contract,
      model_grid = model_grid,
      context_symbols = settings$context_symbols,
      authority_dir = authority_dir,
      grid_n = settings$grid_n,
      min_train_state_rows = settings$min_train_state_rows,
      refresh = settings$refresh
    )
  })
  names(fits) <- settings$symbols
  authority <- list(
    contract = contract,
    folds = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$fold)),
    selected_states = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$selected_states)),
    train_state_performance = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$train_state_performance)),
    state_coverage = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$state_coverage)),
    pca_scores = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$pca_scores)),
    pca_model_contract = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$pca_model_contract)),
    model_grid = model_grid,
    fold_models = stats::setNames(lapply(fits, function(x) x$fold_model), settings$symbols)
  )
  write_authority_packet(authority, authority_dir)
  authority
}

make_policy_authority <- function(authority, selection_policy, min_train_state_rows) {
  out <- authority
  out$contract$selection_policy <- selection_policy
  if (identical(selection_policy, "asset_state_direct_spec")) {
    out$selected_states <- g5_selection_policy_add_direct_label(out$selected_states)
  } else if (identical(selection_policy, "pooled_family_asset_variant")) {
    out$selected_states <- g5_selection_policy_pooled_family_asset_variant(out$train_state_performance, min_train_state_rows = min_train_state_rows)
  } else {
    g5_stop(paste0("Unsupported selection policy: ", selection_policy))
  }
  out
}

replay_symbol_quarter <- function(bars, authority, symbol, as_of_date) {
  contract <- authority$contract[1L, , drop = FALSE]
  scored <- g5_bridge_score_authority_symbol(bars, authority, symbol, as_of_date)
  replay <- g5_bridge_replay_symbol(
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
    authority_role = "phase40_style_quarterly_replay"
  )
  live_start <- as.Date(contract$live_start_date[[1L]])
  live_end <- as.Date(contract$live_end_date[[1L]])
  for (field in c("replay", "executions", "trades", "pending_actions")) {
    if (!is.null(replay[[field]]) && is.data.frame(replay[[field]]) && nrow(replay[[field]])) {
      replay[[field]]$quarter_id <- as.character(contract$quarter_id[[1L]])
    }
  }
  replay$replay_oos <- replay$replay[as.Date(replay$replay$session_date) >= live_start & as.Date(replay$replay$session_date) <= live_end, , drop = FALSE]
  replay
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
    symbol = as.character(replay$symbol),
    session_date = as.Date(replay$session_date),
    strategy_ret = ifelse(pos_lag, ret, 0),
    benchmark_ret = ret,
    in_position = pos,
    state_id = as.character(replay$state_id),
    selected_strategy_family = as.character(replay$selected_strategy_family),
    selected_strategy_spec_id = as.character(replay$selected_strategy_spec_id),
    stringsAsFactors = FALSE
  )
}

portfolio_equity <- function(daily_returns, group_id, symbols) {
  x <- daily_returns[as.character(daily_returns$symbol) %in% symbols, , drop = FALSE]
  if (!nrow(x)) return(data.frame())
  daily <- stats::aggregate(cbind(strategy_ret, benchmark_ret) ~ session_date, data = x, FUN = mean)
  daily <- daily[order(as.Date(daily$session_date)), , drop = FALSE]
  daily$group_id <- group_id
  daily$strategy_equity <- cumprod(1 + as.numeric(daily$strategy_ret))
  daily$benchmark_equity <- cumprod(1 + as.numeric(daily$benchmark_ret))
  daily
}

write_equity_overlay <- function(equity, gen4_equity, path) {
  aesthetic <- g5_chart_aesthetic()
  grDevices::png(path, width = 2400L, height = 1400L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  groups <- c("cluster_3", "cluster_1")
  graphics::par(bg = aesthetic$background, mfrow = c(2, 1), mar = c(4.5, 5, 3, 2), oma = c(0, 0, 3, 0))
  colors <- c(gen4 = "#000000", gen5_direct = "#2E86AB", gen5_pooled = "#9B5DE5", benchmark = "#B8BCC4")
  for (group in groups) {
    x <- equity[as.character(equity$group_id) == group, , drop = FALSE]
    g4 <- gen4_equity[as.character(gen4_equity$portfolio_id) == group, , drop = FALSE]
    date_range <- range(c(as.Date(x$session_date), as.Date(g4$datetime)), na.rm = TRUE)
    y_range <- range(c(x$strategy_equity, x$benchmark_equity, g4$port_eq_oos, g4$port_eq_benchmark), na.rm = TRUE)
    if (!all(is.finite(y_range))) y_range <- c(0.8, 1.2)
    graphics::plot(date_range, y_range, type = "n", xlab = "", ylab = "Equity", main = paste("Equity Overlay:", group), col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
    graphics::rect(par("usr")[[1L]], par("usr")[[3L]], par("usr")[[2L]], par("usr")[[4L]], col = aesthetic$panel_background, border = NA)
    graphics::grid(col = aesthetic$grid)
    if (nrow(g4)) {
      graphics::lines(as.Date(g4$datetime), as.numeric(g4$port_eq_oos), col = colors[["gen4"]], lwd = 2.6)
      graphics::lines(as.Date(g4$datetime), as.numeric(g4$port_eq_benchmark), col = colors[["benchmark"]], lwd = 2.0, lty = 2)
    }
    for (policy in c("asset_state_direct_spec", "pooled_family_asset_variant")) {
      p <- x[as.character(x$selection_policy) == policy, , drop = FALSE]
      if (nrow(p)) graphics::lines(as.Date(p$session_date), as.numeric(p$strategy_equity), col = if (policy == "asset_state_direct_spec") colors[["gen5_direct"]] else colors[["gen5_pooled"]], lwd = 2.1)
    }
    graphics::legend("topleft", legend = c("Gen4 artifact", "Gen4 benchmark", "Gen5 direct", "Gen5 pooled"), col = colors[c("gen4", "benchmark", "gen5_direct", "gen5_pooled")], lwd = c(2.6, 2, 2.1, 2.1), lty = c(1, 2, 1, 1), bty = "n", cex = 0.75)
  }
  graphics::mtext("Gen4 Artifact vs Gen5.1 Phase40-Style Replay", side = 3, outer = TRUE, line = 1, font = 2, col = aesthetic$text)
  invisible(path)
}

write_alpha_scorecard <- function(summary, path) {
  aesthetic <- g5_chart_aesthetic()
  grDevices::png(path, width = 2200L, height = 1100L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  x <- summary[order(as.character(summary$source), as.character(summary$group_id), as.character(summary$selection_policy)), , drop = FALSE]
  x$lane <- ifelse(x$source == "Gen4 artifact", paste("Gen4", x$group_id), paste("Gen5", ifelse(x$selection_policy == "asset_state_direct_spec", "direct", "pooled"), x$group_id))
  values <- as.numeric(x$alpha_vs_benchmark) * 100
  cols <- ifelse(x$source == "Gen4 artifact", "#000000", ifelse(x$selection_policy == "asset_state_direct_spec", "#2E86AB", "#9B5DE5"))
  graphics::par(bg = aesthetic$background, mar = c(7, 13, 4, 2))
  bp <- graphics::barplot(values, names.arg = x$lane, horiz = TRUE, las = 1, cex.names = 0.72, col = cols, border = NA, xlab = "Alpha vs internal benchmark, percentage points", main = "Benchmark-Relative Scorecard", col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  graphics::abline(v = 0, col = aesthetic$axis, lty = 2)
  graphics::grid(nx = NULL, ny = NA, col = aesthetic$grid)
  graphics::text(values, bp, labels = sprintf("%.1f pp", values), pos = ifelse(values >= 0, 4, 2), cex = 0.72, col = aesthetic$text)
  invisible(path)
}

write_quarter_heatmap <- function(quarter_summary, path) {
  aesthetic <- g5_chart_aesthetic()
  x <- quarter_summary
  lanes <- unique(paste(ifelse(x$selection_policy == "asset_state_direct_spec", "Direct", "Pooled"), x$group_id, sep = " / "))
  quarters <- unique(as.character(x$quarter_id))
  values <- matrix(NA_real_, nrow = length(lanes), ncol = length(quarters), dimnames = list(lanes, quarters))
  for (i in seq_len(nrow(x))) {
    row <- paste(ifelse(x$selection_policy[[i]] == "asset_state_direct_spec", "Direct", "Pooled"), x$group_id[[i]], sep = " / ")
    values[row, as.character(x$quarter_id[[i]])] <- as.numeric(x$alpha_vs_benchmark[[i]])
  }
  max_abs <- max(abs(values), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  color_for <- function(v) {
    if (!is.finite(v) || v == 0) return("#FFFDF8")
    grDevices::adjustcolor(if (v > 0) "#00A88F" else "#F15A5A", alpha.f = min(0.95, 0.22 + 0.73 * abs(v) / max_abs))
  }
  grDevices::png(path, width = 2800L, height = 1000L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(7, 10, 4, 2))
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Gen5.1 Quarterly Alpha vs Equal-Weight Hold", col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  for (r in seq_len(nrow(values))) {
    for (c in seq_len(ncol(values))) {
      graphics::rect(c - 0.5, nrow(values) - r + 0.5, c + 0.5, nrow(values) - r + 1.5, col = color_for(values[r, c]), border = aesthetic$grid)
      graphics::text(c, nrow(values) - r + 1, labels = pp_label(values[r, c]), cex = 0.52, col = aesthetic$text)
    }
  }
  graphics::axis(1, at = seq_along(quarters), labels = quarters, las = 2, cex.axis = 0.66, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(lanes)), labels = lanes, las = 1, cex.axis = 0.75, col.axis = aesthetic$axis)
  invisible(path)
}

write_family_comparison <- function(gen4_family, gen5_family, path) {
  aesthetic <- g5_chart_aesthetic()
  families <- sort(unique(c(as.character(gen4_family$family), as.character(gen5_family$strategy_family))))
  sources <- c("Gen4 artifact", "Gen5 direct", "Gen5 pooled")
  values <- matrix(0, nrow = length(families), ncol = length(sources), dimnames = list(families, sources))
  g4_counts <- aggregate(count ~ family, gen4_family, sum)
  for (i in seq_len(nrow(g4_counts))) values[as.character(g4_counts$family[[i]]), "Gen4 artifact"] <- as.numeric(g4_counts$count[[i]])
  for (i in seq_len(nrow(gen5_family))) {
    col <- if (gen5_family$selection_policy[[i]] == "asset_state_direct_spec") "Gen5 direct" else "Gen5 pooled"
    values[as.character(gen5_family$strategy_family[[i]]), col] <- as.numeric(gen5_family$count[[i]])
  }
  values <- sweep(values, 2, pmax(colSums(values), 1), "/") * 100
  grDevices::png(path, width = 2400L, height = 1300L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(7, 10, 4, 2))
  bp <- graphics::barplot(t(values), beside = TRUE, horiz = TRUE, las = 1, col = c("#000000", "#2E86AB", "#9B5DE5"), border = NA, xlab = "Share of selected rows / picks (%)", main = "Selected Strategy-Family Mix", col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  graphics::grid(nx = NULL, ny = NA, col = aesthetic$grid)
  graphics::legend("bottomright", legend = sources, fill = c("#000000", "#2E86AB", "#9B5DE5"), bty = "n", cex = 0.8)
  invisible(path)
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN4_EQ_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed
refresh <- parse_bool(env_or("GEN5_GEN4_EQ_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN4_EQ_STAMP", "20260706"))
root_output_dir <- file.path(repo_root, "runs", "research_workbench", "gen4_equivalence", paste0("gen4_equivalence_", stamp))
dir.create(root_output_dir, recursive = TRUE, showWarnings = FALSE)

gen4_root <- env_or("GEN5_GEN4_EQ_ARTIFACT_ROOT", "C:/Users/Franc/OneDrive/Documents/Francis/Peltata Project/Time-Series-Modeling/Experiments/FM-002-024-R3_med_16_bins")
gen4_phase40 <- file.path(gen4_root, "Phase40_WFA_Quarterly_Validation")
gen4_picked_params_csv <- file.path(gen4_phase40, "phase40_picked_params_by_fold_asset.csv")

research_symbols <- c(
  "SPY", "QQQ", "IWM", "DIA",
  "NVDA", "TSLA", "AMD", "PLTR", "SOFI", "META", "AAPL",
  "KO", "PEP", "WMT", "COST",
  "XLF", "JPM", "BAC",
  "XLE", "CVX", "XOM",
  "TLT", "IEF",
  "GLD", "SLV",
  "VNQ",
  "EFA", "EEM",
  "UVXY"
)
live_symbols <- parse_csv_env("GEN5_GEN4_EQ_SYMBOLS", c("SPY", "QQQ", "IWM", "NVDA", "TSLA", "AMD", "PLTR", "SOFI", "KO", "PEP", "WMT", "TLT", "XLF", "XLE", "GLD", "EFA"))
candidate_families <- parse_csv_env("GEN5_GEN4_EQ_CANDIDATE_FAMILIES", c("ema_cross", "ema_trend", "bollinger_touch", "rsi_mr", "zret_mr", "breakout", "pullback_in_uptrend", "vol_expansion_breakout", "no_trade"))
selection_policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
quarters <- parse_csv_env("GEN5_GEN4_EQ_QUARTERS", quarter_sequence("2020Q4", "2024Q4"))
grid_filter <- env_or("GEN5_GEN4_EQ_GRID_FILTER", "gen4_picked_specs")
grid_n <- 4L
min_train_state_rows <- 20L
strategy_grid_preset <- "gen4_daily_default"
research_note <- "Gen4-equivalence screen: Gen4 research universe as PCA context, Gen4 live/reporting universe as traded symbols, long/pooled PCA, 4x4 quantile states, expanding TRAIN from 2016Q4, and Gen4 daily parameter breadth for implemented Gen5.1 strategy families."

base_model_grid <- g5_bridge_model_grid(candidate_families, strategy_grid_preset)
model_grid <- if (identical(grid_filter, "gen4_picked_specs")) {
  model_grid_from_gen4_picked_specs(base_model_grid, gen4_picked_params_csv)
} else if (identical(grid_filter, "full")) {
  base_model_grid
} else {
  g5_stop(paste0("Unsupported GEN5_GEN4_EQ_GRID_FILTER: ", grid_filter))
}
candidate_families <- unique(as.character(model_grid$strategy_family))
unmatched_gen4_specs <- attr(model_grid, "unmatched_gen4_specs")
if (is.null(unmatched_gen4_specs)) unmatched_gen4_specs <- character()

settings <- list(
  feed = cfg$feed,
  refresh = refresh,
  symbols = g5_standardize_symbol(live_symbols),
  context_symbols = unique(g5_standardize_symbol(research_symbols)),
  candidate_families = candidate_families,
  strategy_grid_preset = strategy_grid_preset,
  model_grid = model_grid,
  grid_filter = grid_filter,
  model_grid_rows = nrow(model_grid),
  unmatched_gen4_specs = unmatched_gen4_specs,
  grid_n = grid_n,
  min_train_state_rows = min_train_state_rows,
  research_note = research_note
)

message("Gen5.1 Gen4-equivalence screen")
message("Output root: ", root_output_dir)
message("Gen4 artifact root: ", gen4_root)
message("Feed: ", cfg$feed)
message("Refresh: ", refresh)
message("Live symbols: ", paste(settings$symbols, collapse = ","))
message("Context symbols: ", paste(settings$context_symbols, collapse = ","))
message("Quarters: ", paste(quarters, collapse = ","))
message("Grid filter: ", settings$grid_filter, " (", settings$model_grid_rows, " model rows)")
if (length(settings$unmatched_gen4_specs)) {
  message("Unmatched Gen4 specs ignored: ", paste(head(settings$unmatched_gen4_specs, 10L), collapse = ", "), if (length(settings$unmatched_gen4_specs) > 10L) " ..." else "")
}

query_start <- as.Date("2016-01-04")
query_end <- as.Date("2024-12-31")
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = "2024-12-31 17:30:00",
  symbols = unique(c(settings$symbols, settings$context_symbols)),
  universe_name = "gen4_equivalence_research_universe",
  universe_roles = "gen4_equivalence_context_and_live_universe",
  refresh = refresh,
  repo_root = repo_root
)
query_dir <- file.path(root_output_dir, "query")
query_paths <- g5_write_workbench_query_artifacts(query, output_dir = query_dir, prefix = "gen4_equivalence_query")
bars <- query$bars

authority_rows <- list()
base_authorities <- list()
for (quarter_id in quarters) {
  authority_dir <- file.path(root_output_dir, "auth", quarter_id)
  authority <- build_authority(bars, quarter_id, authority_dir, settings)
  base_authorities[[quarter_id]] <- authority
  authority_rows[[length(authority_rows) + 1L]] <- data.frame(
    quarter_id = quarter_id,
    authority_dir = normalizePath(authority_dir, winslash = "/", mustWork = FALSE),
    train_start_date = as.Date(authority$contract$train_start_date[[1L]]),
    train_end_date = as.Date(authority$contract$train_end_date[[1L]]),
    live_start_date = as.Date(authority$contract$live_start_date[[1L]]),
    live_end_date = as.Date(authority$contract$live_end_date[[1L]]),
    train_quarters = as.integer(authority$contract$train_quarters[[1L]]),
    stringsAsFactors = FALSE
  )
}

policy_authorities <- list()
for (policy in selection_policies) {
  policy_authorities[[policy]] <- stats::setNames(lapply(base_authorities, make_policy_authority, selection_policy = policy, min_train_state_rows = min_train_state_rows), quarters)
}

packet_rows <- list()
replay_rows <- list()
trade_rows <- list()
daily_rows <- list()
for (quarter_id in quarters) {
  as_of_date <- as.Date(base_authorities[[quarter_id]]$contract$live_end_date[[1L]])
  replay_bars <- bars[as.Date(bars$session_date) <= as_of_date, , drop = FALSE]
  for (policy in selection_policies) {
    for (symbol in settings$symbols) {
      message("Replay: ", quarter_id, " / ", policy, " / ", symbol)
      result <- replay_symbol_quarter(replay_bars, policy_authorities[[policy]][[quarter_id]], symbol, as_of_date)
      for (field in c("replay", "replay_oos", "trades", "executions", "pending_actions")) {
        if (!is.null(result[[field]]) && is.data.frame(result[[field]]) && nrow(result[[field]])) {
          result[[field]]$selection_policy <- policy
          result[[field]]$quarter_id <- quarter_id
        }
      }
      if (is.data.frame(result$replay_oos) && nrow(result$replay_oos)) {
        replay_rows[[length(replay_rows) + 1L]] <- result$replay_oos
        dr <- symbol_daily_returns(result$replay)
        dr <- dr[as.Date(dr$session_date) >= as.Date(base_authorities[[quarter_id]]$contract$live_start_date[[1L]]) & as.Date(dr$session_date) <= as_of_date, , drop = FALSE]
        if (nrow(dr)) {
          dr$quarter_id <- quarter_id
          dr$selection_policy <- policy
          daily_rows[[length(daily_rows) + 1L]] <- dr
        }
      }
      if (is.data.frame(result$trades) && nrow(result$trades)) {
        trade_rows[[length(trade_rows) + 1L]] <- result$trades
      }
      packet_rows[[length(packet_rows) + 1L]] <- data.frame(
        quarter_id = quarter_id,
        selection_policy = policy,
        symbol = symbol,
        replay_rows = if (is.data.frame(result$replay_oos)) nrow(result$replay_oos) else 0L,
        trade_rows = if (is.data.frame(result$trades)) nrow(result$trades) else 0L,
        stringsAsFactors = FALSE
      )
    }
  }
}

replay_all <- g5_wfa_bind_rows_fill(replay_rows)
trade_all <- g5_wfa_bind_rows_fill(trade_rows)
daily_all <- g5_wfa_bind_rows_fill(daily_rows)
packet_index <- g5_wfa_bind_rows_fill(packet_rows)

cluster_map <- utils::read.csv(file.path(gen4_root, "asset_cluster_map.csv"), stringsAsFactors = FALSE)
names(cluster_map) <- tolower(names(cluster_map))
if (!"asset" %in% names(cluster_map)) g5_stop("Gen4 asset_cluster_map.csv is missing asset column.")
cluster_col <- if ("cluster" %in% names(cluster_map)) "cluster" else if ("cluster_id" %in% names(cluster_map)) "cluster_id" else NA_character_
if (is.na(cluster_col)) g5_stop("Gen4 asset_cluster_map.csv is missing cluster/cluster_id column.")
cluster_map$cluster_id <- paste0("cluster_", as.character(cluster_map[[cluster_col]]))
cluster_symbols <- split(as.character(cluster_map$asset[cluster_map$asset %in% settings$symbols]), as.character(cluster_map$cluster_id[cluster_map$asset %in% settings$symbols]))
cluster_symbols[["live_all"]] <- settings$symbols

equity_rows <- list()
quarter_summary_rows <- list()
for (policy in selection_policies) {
  for (group in names(cluster_symbols)) {
    eq <- portfolio_equity(daily_all[daily_all$selection_policy == policy, , drop = FALSE], group, cluster_symbols[[group]])
    if (nrow(eq)) {
      eq$selection_policy <- policy
      equity_rows[[length(equity_rows) + 1L]] <- eq
    }
    for (quarter_id in quarters) {
      q <- daily_all[daily_all$selection_policy == policy & daily_all$quarter_id == quarter_id, , drop = FALSE]
      qeq <- portfolio_equity(q, group, cluster_symbols[[group]])
      if (!nrow(qeq)) next
      tail_row <- qeq[nrow(qeq), , drop = FALSE]
      quarter_summary_rows[[length(quarter_summary_rows) + 1L]] <- data.frame(
        quarter_id = quarter_id,
        selection_policy = policy,
        group_id = group,
        strategy_return = as.numeric(tail_row$strategy_equity[[1L]]) - 1,
        benchmark_return = as.numeric(tail_row$benchmark_equity[[1L]]) - 1,
        alpha_vs_benchmark = as.numeric(tail_row$strategy_equity[[1L]]) - as.numeric(tail_row$benchmark_equity[[1L]]),
        stringsAsFactors = FALSE
      )
    }
  }
}
equity_all <- g5_wfa_bind_rows_fill(equity_rows)
quarter_summary <- g5_wfa_bind_rows_fill(quarter_summary_rows)

gen5_summary <- do.call(rbind, lapply(split(equity_all, paste(equity_all$selection_policy, equity_all$group_id, sep = "::")), function(x) {
  x <- x[order(as.Date(x$session_date)), , drop = FALSE]
  tail_row <- x[nrow(x), , drop = FALSE]
  data.frame(
    source = "Gen5.1 replay",
    selection_policy = as.character(x$selection_policy[[1L]]),
    group_id = as.character(x$group_id[[1L]]),
    strategy_return = as.numeric(tail_row$strategy_equity[[1L]]) - 1,
    benchmark_return = as.numeric(tail_row$benchmark_equity[[1L]]) - 1,
    alpha_vs_benchmark = as.numeric(tail_row$strategy_equity[[1L]]) - as.numeric(tail_row$benchmark_equity[[1L]]),
    stringsAsFactors = FALSE
  )
}))

gen4_summary_raw <- utils::read.csv(file.path(gen4_phase40, "phase40_live_summary_metrics.csv"), stringsAsFactors = FALSE)
gen4_summary <- data.frame(
  source = "Gen4 artifact",
  selection_policy = "pooled_family_asset_variant",
  group_id = as.character(gen4_summary_raw$portfolio_id),
  strategy_return = as.numeric(gen4_summary_raw$portfolio_oos_total_return),
  benchmark_return = as.numeric(gen4_summary_raw$portfolio_benchmark_total_return),
  alpha_vs_benchmark = as.numeric(gen4_summary_raw$portfolio_oos_total_return) - as.numeric(gen4_summary_raw$portfolio_benchmark_total_return),
  stringsAsFactors = FALSE
)
comparison_summary <- rbind(gen4_summary, gen5_summary)

gen4_equity <- utils::read.csv(file.path(gen4_phase40, "phase40_live_portfolio_cluster_oos_equity.csv"), stringsAsFactors = FALSE)
gen4_equity$datetime <- as.Date(gen4_equity$datetime)

gen4_family_raw <- utils::read.csv(file.path(gen4_phase40, "phase40_picked_params_by_fold_asset.csv"), stringsAsFactors = FALSE)
gen4_family <- as.data.frame(table(family = as.character(gen4_family_raw$family)), stringsAsFactors = FALSE)
names(gen4_family) <- c("family", "count")

selected_all <- g5_wfa_bind_rows_fill(list(
  g5_wfa_bind_rows_fill(lapply(policy_authorities$asset_state_direct_spec, function(x) x$selected_states)),
  g5_wfa_bind_rows_fill(lapply(policy_authorities$pooled_family_asset_variant, function(x) x$selected_states))
))
gen5_family <- as.data.frame(table(selection_policy = as.character(selected_all$selection_policy), strategy_family = as.character(selected_all$strategy_family)), stringsAsFactors = FALSE)
names(gen5_family) <- c("selection_policy", "strategy_family", "count")

paths <- list(
  run_spec_csv = file.path(root_output_dir, "gen4_equivalence_run_spec.csv"),
  query_health_csv = query_paths$paths$health_csv,
  authority_index_csv = file.path(root_output_dir, "gen4_equivalence_authority_index.csv"),
  packet_index_csv = file.path(root_output_dir, "gen4_equivalence_packet_index.csv"),
  replay_csv = file.path(root_output_dir, "gen4_equivalence_replay_oos.csv"),
  trades_csv = file.path(root_output_dir, "gen4_equivalence_trades.csv"),
  daily_equity_csv = file.path(root_output_dir, "gen4_equivalence_daily_equity.csv"),
  quarter_summary_csv = file.path(root_output_dir, "gen4_equivalence_quarter_summary.csv"),
  comparison_summary_csv = file.path(root_output_dir, "gen4_equivalence_comparison_summary.csv"),
  gen5_family_csv = file.path(root_output_dir, "gen4_equivalence_gen5_family_summary.csv"),
  gen4_family_csv = file.path(root_output_dir, "gen4_equivalence_gen4_family_summary.csv"),
  equity_overlay_png = file.path(root_output_dir, "gen4_equivalence_equity_overlay.png"),
  alpha_scorecard_png = file.path(root_output_dir, "gen4_equivalence_alpha_scorecard.png"),
  quarter_heatmap_png = file.path(root_output_dir, "gen4_equivalence_quarter_alpha_heatmap.png"),
  family_mix_png = file.path(root_output_dir, "gen4_equivalence_family_mix.png"),
  report_md = file.path(root_output_dir, "gen4_equivalence_report.md")
)

run_spec <- data.frame(
  schema_version = "gen5_gen4_equivalence_screen_v0.1",
  screen_id = paste0("gen4_equivalence_", stamp),
  evidence_role = "gen4_artifact_forensic_reproduction_lane",
  gen4_artifact_root = normalizePath(gen4_root, winslash = "/", mustWork = FALSE),
  symbols = paste(settings$symbols, collapse = ","),
  context_symbols = paste(settings$context_symbols, collapse = ","),
  pca_panel_mode = "pooled_asset_day",
  state_engine = "quantile_grid",
  grid_n = grid_n,
  train_policy = "expanding_from_2016Q4_to_prior_quarter",
  replay_quarters = paste(quarters, collapse = ","),
  selection_policies = paste(selection_policies, collapse = ","),
  strategy_grid_preset = strategy_grid_preset,
  model_grid_filter = settings$grid_filter,
  model_grid_rows = settings$model_grid_rows,
  unmatched_gen4_spec_count = length(settings$unmatched_gen4_specs),
  candidate_families = paste(settings$candidate_families, collapse = ","),
  known_remaining_gap = "Gen4 artifact included SMA trend/cross candidates and exact Gen4 volatility-breakout semantics; Gen5.1 does not implement SMA families. Default grid_filter=gen4_picked_specs limits Gen5.1 to specs actually selected by the Gen4 artifact; GEN5_GEN4_EQ_GRID_FILTER=full restores the full implemented Gen5.1 grid.",
  research_only = TRUE,
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(authority_rows), paths$authority_index_csv)
g5_wfa_write_csv(packet_index, paths$packet_index_csv)
g5_wfa_write_csv(replay_all, paths$replay_csv)
g5_wfa_write_csv(trade_all, paths$trades_csv)
g5_wfa_write_csv(equity_all, paths$daily_equity_csv)
g5_wfa_write_csv(quarter_summary, paths$quarter_summary_csv)
g5_wfa_write_csv(comparison_summary, paths$comparison_summary_csv)
g5_wfa_write_csv(gen5_family, paths$gen5_family_csv)
g5_wfa_write_csv(gen4_family, paths$gen4_family_csv)

write_equity_overlay(equity_all, gen4_equity, paths$equity_overlay_png)
write_alpha_scorecard(comparison_summary[comparison_summary$group_id %in% c("cluster_1", "cluster_3"), , drop = FALSE], paths$alpha_scorecard_png)
write_quarter_heatmap(quarter_summary[quarter_summary$group_id %in% c("cluster_1", "cluster_3"), , drop = FALSE], paths$quarter_heatmap_png)
write_family_comparison(gen4_family, gen5_family, paths$family_mix_png)

comparison_print <- comparison_summary
comparison_print$strategy_return <- pct_label(comparison_print$strategy_return)
comparison_print$benchmark_return <- pct_label(comparison_print$benchmark_return)
comparison_print$alpha_vs_benchmark <- pp_label(comparison_print$alpha_vs_benchmark)

report <- c(
  "# Gen5.1 Gen4-Equivalence Screen",
  "",
  "## Plain-Language Purpose",
  "",
  "This screen asks whether the apparent gap between recent Gen5.1 tactical replays and their equal-weight benchmarks is explained by a setup mismatch. It recreates the closest implemented Gen5.1 analogue of the Gen4 experiment packet `FM-002-024-R3_med_16_bins`, then compares it to the Gen4 artifact rather than relying on memory.",
  "",
  "The goal is not to crown a live allocation. It is to identify which remaining differences are methodological and which are simply benchmark/reporting differences.",
  "",
  "## Scope",
  "",
  "- Gen4 artifact: `FM-002-024-R3_med_16_bins`.",
  "- Gen5.1 context universe: Gen4 `RESEARCH_ASSETS` analogue, 29 symbols.",
  "- Gen5.1 trade/report universe: Gen4 live/reporting universe, 16 symbols.",
  "- PCA/state surface: long/pooled asset-day PCA plus `4x4` quantile grid.",
  "- TRAIN/OOS schedule: expanding TRAIN from `2016Q4` through the prior quarter; OOS quarters `2020Q4` through `2024Q4`.",
  "- Selection policies: current Gen5.1 direct-spec and Gen4-style pooled-family.",
  paste0("- Strategy grid: `", strategy_grid_preset, "` for implemented Gen5.1 families, with grid filter `", settings$grid_filter, "` (`", settings$model_grid_rows, "` model rows)."),
  "",
  "## Main Comparison",
  "",
  md_table(comparison_print[comparison_print$group_id %in% c("cluster_1", "cluster_3", "live_all"), , drop = FALSE], c("source", "selection_policy", "group_id", "strategy_return", "benchmark_return", "alpha_vs_benchmark")),
  "",
  "## Artifacts",
  "",
  paste0("- Run spec: `", normalizePath(paths$run_spec_csv, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Comparison summary: `", normalizePath(paths$comparison_summary_csv, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Daily equity: `", normalizePath(paths$daily_equity_csv, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Quarterly summary: `", normalizePath(paths$quarter_summary_csv, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Equity overlay: `", normalizePath(paths$equity_overlay_png, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Alpha scorecard: `", normalizePath(paths$alpha_scorecard_png, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Quarterly alpha heatmap: `", normalizePath(paths$quarter_heatmap_png, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Family mix: `", normalizePath(paths$family_mix_png, winslash = "/", mustWork = FALSE), "`"),
  "",
  "## Known Remaining Gaps",
  "",
  "- Gen4 included SMA trend/cross parameter families in its grid; Gen5.1 does not implement SMA strategy families.",
  "- The default run filters the Gen5.1 grid to the strategy specs actually picked in the Gen4 artifact; this is a forensic equivalence slice, not a full unused-grid search.",
  "- Gen4's exact `state_gated_volatility_expansion_breakout` semantics may not be identical to Gen5.1 `vol_expansion_breakout`.",
  "- This wrapper uses a Phase40-style quarterly replay proxy, not the live-advice bridge's adjacent-quarter continuity behavior.",
  "- The Gen5.1 benchmark curve is an equal-symbol close-to-close proxy built from replay positions; it is intended for inspection, not accepted allocation evidence.",
  "",
  "## Leakage Guardrails",
  "",
  "- Each quarter fits PCA state assignment and strategy selection using TRAIN dates only.",
  "- The 4x4 state map is frozen before the OOS quarter is replayed.",
  "- Selection-policy variants consume the same TRAIN performance table.",
  "- OOS replay consumes frozen selected-state maps only.",
  "- Generated artifacts live under ignored `runs/` and do not change live bridge behavior."
)
writeLines(unlist(report), paths$report_md, useBytes = TRUE)

message("")
message("Gen4-equivalence screen complete:")
print(data.frame(paths), row.names = FALSE)
message("")
message("Comparison summary:")
print(comparison_summary, row.names = FALSE)
