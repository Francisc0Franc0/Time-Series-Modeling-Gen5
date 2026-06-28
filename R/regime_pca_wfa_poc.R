# Gen5.1 PCA-routed WFA proof-of-concept helpers.

g5_pca_wfa_schema_version <- function() {
  "gen5_pca_wfa_router_poc_v0.1"
}

g5_pca_wfa_panel_mode <- function(panel_mode = "date_aligned_context") {
  mode <- as.character(panel_mode)[[1L]]
  allowed <- c("date_aligned_context", "pooled_asset_day")
  if (!mode %in% allowed) {
    g5_stop(paste0("PCA panel mode must be one of: ", paste(allowed, collapse = ", ")))
  }
  mode
}

g5_pca_wfa_panel_label <- function(panel_mode) {
  mode <- g5_pca_wfa_panel_mode(panel_mode)
  if (identical(mode, "pooled_asset_day")) "pooled" else "aligned"
}

g5_pca_wfa_artifact_prefix <- function(as_of_timestamp, symbol, fold_count, grid_n, wfa_start_date, wfa_end_date, candidate_families, state_engine = "quantile_grid", regime_context_symbols = symbol, pca_panel_mode = "date_aligned_context") {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  families <- sort(unique(as.character(candidate_families)))
  engine_label <- if (identical(as.character(state_engine), "pca_kmeans")) paste0("k", as.integer(grid_n)) else paste0(grid_n, "x", grid_n)
  context_symbols <- unique(g5_standardize_symbol(regime_context_symbols))
  context_label <- paste0(g5_pca_wfa_panel_label(pca_panel_mode), length(context_symbols), "a")
  paste(
    c(
      "pcawfa",
      symbol,
      paste0(fold_count, "f"),
      engine_label,
      context_label,
      paste0(length(families), "fam"),
      gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_start_date))),
      gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date))),
      stamp
    ),
    collapse = "_"
  )
}

g5_pca_wfa_output_dir <- function(repo_root, as_of_timestamp, symbol, fold_count, grid_n, wfa_start_date, wfa_end_date, candidate_families, state_engine = "quantile_grid", regime_context_symbols = symbol, pca_panel_mode = "date_aligned_context") {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "regime_wfa_pocs",
    g5_pca_wfa_artifact_prefix(as_of_timestamp, symbol, fold_count, grid_n, wfa_start_date, wfa_end_date, candidate_families, state_engine, regime_context_symbols, pca_panel_mode)
  )
}

g5_pca_wfa_find_output_dir <- function(repo_root, as_of_timestamp, symbol, fold_count, grid_n, wfa_end_date, candidate_families, state_engine = "quantile_grid", regime_context_symbols = symbol, pca_panel_mode = "date_aligned_context", fallback_wfa_start_date = NULL) {
  base_dir <- file.path(repo_root, "runs", "research_workbench", "regime_wfa_pocs")
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol_label <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  families <- sort(unique(as.character(candidate_families)))
  engine_label <- if (identical(as.character(state_engine), "pca_kmeans")) paste0("k", as.integer(grid_n)) else paste0(grid_n, "x", grid_n)
  context_symbols <- unique(g5_standardize_symbol(regime_context_symbols))
  context_label <- paste0(g5_pca_wfa_panel_label(pca_panel_mode), length(context_symbols), "a")
  end_label <- gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date)))
  pattern <- paste0(
    "^pcawfa_",
    symbol_label,
    "_",
    as.integer(fold_count),
    "f_",
    engine_label,
    "_",
    context_label,
    "_",
    length(families),
    "fam_[0-9]+_",
    end_label,
    "_",
    stamp,
    "$"
  )
  if (dir.exists(base_dir)) {
    dirs <- list.dirs(base_dir, recursive = FALSE, full.names = TRUE)
    matches <- dirs[grepl(pattern, basename(dirs))]
    if (length(matches)) {
      info <- file.info(matches)
      matches <- matches[order(info$mtime, matches)]
      return(normalizePath(matches[[length(matches)]], winslash = "/", mustWork = FALSE))
    }
  }
  if (!is.null(fallback_wfa_start_date)) {
    return(normalizePath(
      g5_pca_wfa_output_dir(repo_root, as_of_timestamp, symbol, fold_count, grid_n, fallback_wfa_start_date, wfa_end_date, candidate_families, state_engine, regime_context_symbols, pca_panel_mode),
      winslash = "/",
      mustWork = FALSE
    ))
  }
  normalizePath(file.path(base_dir, paste0("missing_", gsub("[^0-9A-Za-z_.-]+", "_", pattern))), winslash = "/", mustWork = FALSE)
}

g5_pca_wfa_all_states <- function(grid_n) {
  as.vector(outer(seq_len(grid_n), seq_len(grid_n), function(x, y) paste0("S", x, "_", y)))
}

g5_pca_wfa_state_ids <- function(pca_result, grid_n) {
  if ("state_ids" %in% names(pca_result) && length(pca_result$state_ids)) {
    return(as.character(pca_result$state_ids))
  }
  g5_pca_wfa_all_states(grid_n)
}

g5_pca_wfa_native_only_exit_stack <- function() {
  data.frame(
    exit_stack_id = "native_only",
    include_native_exit = TRUE,
    max_hold_sessions = NA_integer_,
    stop_loss_pct = NA_real_,
    take_profit_pct = NA_real_,
    stringsAsFactors = FALSE
  )
}

g5_pca_wfa_model_from_metric <- function(row) {
  data.frame(
    strategy_family = row$strategy_family[[1L]],
    model_instance_id = row$model_instance_id[[1L]],
    fast_period = if ("fast_period" %in% names(row)) row$fast_period[[1L]] else NA_integer_,
    slow_period = if ("slow_period" %in% names(row)) row$slow_period[[1L]] else NA_integer_,
    lookback_period = if ("lookback_period" %in% names(row)) row$lookback_period[[1L]] else NA_integer_,
    sd_multiplier = if ("sd_multiplier" %in% names(row)) row$sd_multiplier[[1L]] else NA_real_,
    rsi_period = if ("rsi_period" %in% names(row)) row$rsi_period[[1L]] else NA_integer_,
    rsi_lower = if ("rsi_lower" %in% names(row)) row$rsi_lower[[1L]] else NA_real_,
    rsi_upper = if ("rsi_upper" %in% names(row)) row$rsi_upper[[1L]] else NA_real_,
    zret_window = if ("zret_window" %in% names(row)) row$zret_window[[1L]] else NA_integer_,
    zret_entry_z = if ("zret_entry_z" %in% names(row)) row$zret_entry_z[[1L]] else NA_real_,
    zret_exit_z = if ("zret_exit_z" %in% names(row)) row$zret_exit_z[[1L]] else NA_real_,
    breakout_lookback = if ("breakout_lookback" %in% names(row)) row$breakout_lookback[[1L]] else NA_integer_,
    breakout_buffer = if ("breakout_buffer" %in% names(row)) row$breakout_buffer[[1L]] else NA_real_,
    vol_expand_threshold = if ("vol_expand_threshold" %in% names(row)) row$vol_expand_threshold[[1L]] else NA_real_,
    stringsAsFactors = FALSE
  )
}

g5_pca_wfa_exit_stack_from_metric <- function(row) {
  data.frame(
    exit_stack_id = row$exit_stack_id[[1L]],
    include_native_exit = if ("include_native_exit" %in% names(row)) row$include_native_exit[[1L]] else TRUE,
    max_hold_sessions = if ("max_hold_sessions" %in% names(row)) row$max_hold_sessions[[1L]] else NA_integer_,
    stop_loss_pct = if ("stop_loss_pct" %in% names(row)) row$stop_loss_pct[[1L]] else NA_real_,
    take_profit_pct = if ("take_profit_pct" %in% names(row)) row$take_profit_pct[[1L]] else NA_real_,
    stringsAsFactors = FALSE
  )
}

g5_pca_wfa_state_lookup <- function(scores) {
  out <- as.character(scores$state_id)
  names(out) <- as.character(as.Date(scores$session_date))
  out
}

g5_pca_wfa_add_entry_states <- function(trades, state_lookup) {
  if (!is.data.frame(trades) || nrow(trades) == 0L) {
    return(trades)
  }
  trades$entry_state_id <- unname(state_lookup[as.character(as.Date(trades$entry_signal_date))])
  trades$entry_state_id[is.na(trades$entry_state_id)] <- NA_character_
  trades
}

g5_pca_wfa_select_state_specs <- function(
  bars,
  symbol,
  pca_result,
  fold,
  model_grid,
  exit_stacks,
  min_train_state_rows = 20L,
  leverage = 1
) {
  states <- g5_pca_wfa_state_ids(pca_result, pca_result$grid_n)
  scores <- pca_result$scores
  state_lookup <- g5_pca_wfa_state_lookup(scores)
  coverage <- g5_pca_regime_state_coverage(scores, pca_result$grid_n, states)
  train_coverage <- coverage[coverage$split == "TRAIN", , drop = FALSE]
  train_rows_by_state <- stats::setNames(train_coverage$row_count, train_coverage$state_id)
  exit_stacks <- g5_wfa_exit_stacks_for_candidates(exit_stacks, unique(model_grid$strategy_family))

  perf_rows <- list()
  no_trade_rows <- list()
  for (model_i in seq_len(nrow(model_grid))) {
    model <- model_grid[model_i, , drop = FALSE]
    stacks_for_model <- if (identical(as.character(model$strategy_family[[1L]]), "no_trade")) {
      g5_wfa_no_trade_exit_stack()
    } else {
      exit_stacks[exit_stacks$exit_stack_id != "no_exit", , drop = FALSE]
    }
    for (stack_i in seq_len(nrow(stacks_for_model))) {
      exit_stack <- stacks_for_model[stack_i, , drop = FALSE]
      trades <- g5_wfa_strategy_spec_trades(
        bars,
        symbol = symbol,
        model = model,
        exit_stack = exit_stack,
        trading_start_date = fold$train_start_date[[1L]],
        trading_end_date = fold$train_end_date[[1L]],
        leverage = leverage
      )
      trades <- g5_pca_wfa_add_entry_states(trades, state_lookup)
      for (state in states) {
        state_trades <- if (nrow(trades)) trades[trades$entry_state_id == state & !is.na(trades$entry_state_id), , drop = FALSE] else data.frame()
        equity_curve <- g5_ema_cross_equity_curve(
          state_trades,
          bars,
          symbol = symbol,
          trading_start_date = fold$train_start_date[[1L]],
          trading_end_date = fold$train_end_date[[1L]],
          leverage = leverage
        )
        metrics <- g5_wfa_strategy_spec_metrics(state_trades, equity_curve, symbol, model, exit_stack, leverage)
        metrics$fold_id <- fold$fold_id[[1L]]
        metrics$fold_no <- fold$fold_no[[1L]]
        metrics$state_id <- state
        metrics$train_state_row_count <- unname(train_rows_by_state[[state]])
        metrics$train_state_trade_count <- if (is.data.frame(state_trades)) nrow(state_trades) else 0L
        metrics$ownership_policy <- "entry_state_owns_trade_until_exit"
        perf_rows[[length(perf_rows) + 1L]] <- metrics
        if (identical(as.character(model$strategy_family[[1L]]), "no_trade")) {
          no_trade_rows[[state]] <- metrics
        }
      }
    }
  }
  train_performance <- g5_wfa_bind_rows_fill(perf_rows)
  selected <- list()
  for (state in states) {
    state_rows <- train_performance[train_performance$state_id == state, , drop = FALSE]
    row_count <- if (state %in% names(train_rows_by_state)) unname(train_rows_by_state[[state]]) else 0L
    if (is.na(row_count) || row_count < min_train_state_rows) {
      winner <- no_trade_rows[[state]]
      winner$selection_reason <- paste0("forced_no_trade_sparse_state_min_rows_", min_train_state_rows)
    } else {
      ranked <- state_rows[order(
        ifelse(is.na(state_rows$sharpe), -Inf, state_rows$sharpe),
        ifelse(is.na(state_rows$total_return), -Inf, state_rows$total_return),
        decreasing = TRUE
      ), , drop = FALSE]
      winner <- ranked[1L, , drop = FALSE]
      winner$selection_reason <- "ranked_by_train_state_sharpe_then_return"
    }
    selected[[length(selected) + 1L]] <- winner
  }
  selected_states <- g5_wfa_bind_rows_fill(selected)
  rownames(selected_states) <- NULL
  rownames(train_performance) <- NULL
  list(
    selected_states = selected_states,
    train_state_performance = train_performance,
    state_coverage = coverage
  )
}

g5_pca_wfa_simulate_oos <- function(bars, symbol, fold, pca_result, selected_states, leverage = 1) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  final_oos_date <- as.Date(fold$oos_end_date[[1L]])
  first_oos_date <- as.Date(fold$oos_start_date[[1L]])
  first_signal_date <- as.Date(fold$train_end_date[[1L]])
  all_bars <- g5_ema_cross_prepare_bars(bars, symbol = symbol, end_date = final_oos_date)
  session_dates <- as.Date(all_bars$session_date)
  state_lookup <- g5_pca_wfa_state_lookup(pca_result$scores)
  date_to_index <- function(x) match(as.Date(x), session_dates)

  selected_by_state <- split(selected_states, selected_states$state_id)
  indicator_cache <- list()
  for (i in seq_len(nrow(selected_states))) {
    row <- selected_states[i, , drop = FALSE]
    spec_id <- row$strategy_spec_id[[1L]]
    if (!spec_id %in% names(indicator_cache)) {
      indicator_cache[[spec_id]] <- g5_wfa_model_indicators(all_bars, symbol, g5_pca_wfa_model_from_metric(row))
    }
  }
  get_selected <- function(state) {
    if (!is.na(state) && state %in% names(selected_by_state)) {
      return(selected_by_state[[state]][1L, , drop = FALSE])
    }
    selected_by_state[["S1_1"]][0L, , drop = FALSE]
  }

  signal_indices <- which(session_dates >= first_signal_date & session_dates <= final_oos_date)
  trades <- list()
  trade_no <- 0L
  in_position <- FALSE
  open_trade <- NULL
  pending_entry <- NULL
  pending_exit <- NULL

  for (idx in signal_indices) {
    current_date <- session_dates[[idx]]
    current_state <- unname(state_lookup[[as.character(current_date)]])
    if (is.null(current_state) || is.na(current_state)) current_state <- NA_character_

    if (!is.null(pending_entry) && identical(as.Date(pending_entry$execution_date), current_date) && !in_position && current_date >= first_oos_date) {
      trade_no <- trade_no + 1L
      open_trade <- c(
        pending_entry,
        list(
          trade_no = trade_no,
          entry_execution_idx = idx,
          entry_execution_date = current_date,
          entry_execution_price = as.numeric(all_bars$open[[idx]]),
          entry_execution_state_id = current_state
        )
      )
      in_position <- TRUE
      pending_entry <- NULL
    }

    if (!is.null(pending_exit) && identical(as.Date(pending_exit$execution_date), current_date) && in_position) {
      entry_price <- open_trade$entry_execution_price
      exit_price <- as.numeric(all_bars$open[[idx]])
      underlying_realized_return <- (exit_price / entry_price) - 1
      realized_return <- leverage * underlying_realized_return
      trades[[length(trades) + 1L]] <- data.frame(
        schema_version = g5_pca_wfa_schema_version(),
        trade_id = sprintf("%s_pca_wfa_%03d", symbol, open_trade$trade_no),
        symbol = symbol,
        fold_id = fold$fold_id[[1L]],
        fold_no = fold$fold_no[[1L]],
        ownership_policy = "entry_state_owns_trade_until_exit",
        entry_state_id = open_trade$entry_state_id,
        entry_execution_state_id = open_trade$entry_execution_state_id,
        exit_signal_state_id = pending_exit$exit_signal_state_id,
        exit_execution_state_id = current_state,
        strategy_family = open_trade$strategy_family,
        model_instance_id = open_trade$model_instance_id,
        exit_stack_id = open_trade$exit_stack_id,
        strategy_spec_id = open_trade$strategy_spec_id,
        primary_exit_reason = pending_exit$primary_exit_reason,
        triggered_exit_rules = pending_exit$triggered_exit_rules,
        exit_attribution = pending_exit$exit_attribution,
        fast_period = open_trade$fast_period,
        slow_period = open_trade$slow_period,
        lookback_period = open_trade$lookback_period,
        sd_multiplier = open_trade$sd_multiplier,
        trade_status = "closed",
        entry_signal_date = open_trade$entry_signal_date,
        entry_signal_index = open_trade$entry_signal_idx,
        entry_signal_price = open_trade$entry_signal_price,
        entry_execution_date = open_trade$entry_execution_date,
        entry_execution_index = open_trade$entry_execution_idx,
        entry_execution_price = entry_price,
        exit_signal_date = pending_exit$exit_signal_date,
        exit_signal_index = pending_exit$exit_signal_idx,
        exit_signal_price = pending_exit$exit_signal_price,
        exit_execution_date = current_date,
        exit_execution_index = idx,
        exit_execution_price = exit_price,
        latest_mark_date = final_oos_date,
        latest_mark_price = as.numeric(all_bars$close[[date_to_index(final_oos_date)]]),
        trace_end_date = current_date,
        trace_end_index = idx,
        trace_end_price = exit_price,
        underlying_realized_return = underlying_realized_return,
        underlying_unrealized_return = NA_real_,
        realized_return = realized_return,
        unrealized_return = NA_real_,
        trace_return = realized_return,
        trade_outcome = if (realized_return > 0) "win" else if (realized_return < 0) "loss" else "flat",
        holding_sessions_completed = idx - open_trade$entry_execution_idx + 1L,
        signal_rule = open_trade$entry_signal_rule,
        entry_execution_rule = "next_session_open_after_entry_signal",
        exit_signal_rule = pending_exit$exit_signal_rule,
        exit_execution_rule = "next_session_open_after_exit_signal",
        leverage = leverage,
        capital_fraction = 1,
        stringsAsFactors = FALSE
      )
      in_position <- FALSE
      open_trade <- NULL
      pending_exit <- NULL
    }

    next_idx <- idx + 1L
    if (next_idx > nrow(all_bars) || session_dates[[next_idx]] > final_oos_date) {
      next
    }

    if (!in_position && is.null(pending_entry)) {
      selected <- get_selected(current_state)
      if (nrow(selected) == 0L || identical(as.character(selected$strategy_family[[1L]]), "no_trade")) {
        next
      }
      ind <- indicator_cache[[selected$strategy_spec_id[[1L]]]]
      if (isTRUE(ind$entry_signal[[idx]])) {
        pending_entry <- list(
          entry_state_id = current_state,
          strategy_family = selected$strategy_family[[1L]],
          model_instance_id = selected$model_instance_id[[1L]],
          exit_stack_id = selected$exit_stack_id[[1L]],
          strategy_spec_id = selected$strategy_spec_id[[1L]],
          fast_period = g5_wfa_model_value(selected, "fast_period", NA_integer_),
          slow_period = g5_wfa_model_value(selected, "slow_period", NA_integer_),
          lookback_period = g5_wfa_model_value(selected, "lookback_period", NA_integer_),
          sd_multiplier = g5_wfa_model_value(selected, "sd_multiplier", NA_real_),
          entry_signal_rule = ind$entry_signal_rule[[idx]],
          entry_signal_date = current_date,
          entry_signal_idx = idx,
          entry_signal_price = as.numeric(all_bars$close[[idx]]),
          execution_date = session_dates[[next_idx]]
        )
      }
    }

    if (in_position && is.null(pending_exit)) {
      owner <- selected_states[selected_states$strategy_spec_id == open_trade$strategy_spec_id & selected_states$state_id == open_trade$entry_state_id, , drop = FALSE]
      if (nrow(owner) == 0L) {
        owner <- selected_states[selected_states$strategy_spec_id == open_trade$strategy_spec_id, , drop = FALSE][1L, , drop = FALSE]
      }
      ind <- indicator_cache[[open_trade$strategy_spec_id]]
      exit_event <- g5_wfa_exit_event(ind, idx, open_trade, g5_pca_wfa_exit_stack_from_metric(owner))
      if (!is.null(exit_event)) {
        pending_exit <- c(
          exit_event,
          list(
            exit_signal_state_id = current_state,
            exit_signal_date = current_date,
            exit_signal_idx = idx,
            exit_signal_price = as.numeric(all_bars$close[[idx]]),
            execution_date = session_dates[[next_idx]]
          )
        )
      }
    }
  }

  if (in_position && !is.null(open_trade)) {
    latest_idx <- date_to_index(final_oos_date)
    latest_close <- as.numeric(all_bars$close[[latest_idx]])
    underlying_unrealized_return <- (latest_close / open_trade$entry_execution_price) - 1
    unrealized_return <- leverage * underlying_unrealized_return
    trades[[length(trades) + 1L]] <- data.frame(
      schema_version = g5_pca_wfa_schema_version(),
      trade_id = sprintf("%s_pca_wfa_%03d", symbol, open_trade$trade_no),
      symbol = symbol,
      fold_id = fold$fold_id[[1L]],
      fold_no = fold$fold_no[[1L]],
      ownership_policy = "entry_state_owns_trade_until_exit",
      entry_state_id = open_trade$entry_state_id,
      entry_execution_state_id = open_trade$entry_execution_state_id,
      exit_signal_state_id = NA_character_,
      exit_execution_state_id = NA_character_,
      strategy_family = open_trade$strategy_family,
      model_instance_id = open_trade$model_instance_id,
      exit_stack_id = open_trade$exit_stack_id,
      strategy_spec_id = open_trade$strategy_spec_id,
      primary_exit_reason = NA_character_,
      triggered_exit_rules = NA_character_,
      exit_attribution = NA_character_,
      fast_period = open_trade$fast_period,
      slow_period = open_trade$slow_period,
      lookback_period = open_trade$lookback_period,
      sd_multiplier = open_trade$sd_multiplier,
      trade_status = "open",
      entry_signal_date = open_trade$entry_signal_date,
      entry_signal_index = open_trade$entry_signal_idx,
      entry_signal_price = open_trade$entry_signal_price,
      entry_execution_date = open_trade$entry_execution_date,
      entry_execution_index = open_trade$entry_execution_idx,
      entry_execution_price = open_trade$entry_execution_price,
      exit_signal_date = as.Date(NA),
      exit_signal_index = NA_integer_,
      exit_signal_price = NA_real_,
      exit_execution_date = as.Date(NA),
      exit_execution_index = NA_integer_,
      exit_execution_price = NA_real_,
      latest_mark_date = final_oos_date,
      latest_mark_price = latest_close,
      trace_end_date = final_oos_date,
      trace_end_index = latest_idx,
      trace_end_price = latest_close,
      underlying_realized_return = NA_real_,
      underlying_unrealized_return = underlying_unrealized_return,
      realized_return = NA_real_,
      unrealized_return = unrealized_return,
      trace_return = unrealized_return,
      trade_outcome = if (unrealized_return > 0) "win" else if (unrealized_return < 0) "loss" else "flat",
      holding_sessions_completed = latest_idx - open_trade$entry_execution_idx + 1L,
      signal_rule = open_trade$entry_signal_rule,
      entry_execution_rule = "next_session_open_after_entry_signal",
      exit_signal_rule = "entry_state_owned_spec_until_exit",
      exit_execution_rule = "next_session_open_after_exit_signal",
      leverage = leverage,
      capital_fraction = 1,
      stringsAsFactors = FALSE
    )
  }

  trades_out <- if (length(trades) == 0L) data.frame() else do.call(rbind, trades)
  if (nrow(trades_out) > 0L) rownames(trades_out) <- NULL
  equity_curve <- g5_ema_cross_equity_curve(
    trades_out,
    all_bars,
    symbol = symbol,
    trading_start_date = first_oos_date,
    trading_end_date = final_oos_date,
    leverage = leverage
  )
  list(trades = trades_out, equity_curve = equity_curve)
}

g5_pca_wfa_route_metrics <- function(trades, equity_curve, symbol) {
  closed <- if (is.data.frame(trades) && nrow(trades)) trades[trades$trade_status == "closed", , drop = FALSE] else data.frame()
  closed_returns <- if (nrow(closed)) as.numeric(closed$realized_return) else numeric()
  ending_equity <- tail(equity_curve$strategy_equity, 1L)
  data.frame(
    schema_version = g5_pca_wfa_schema_version(),
    symbol = g5_standardize_symbol(symbol)[[1L]],
    total_return = ending_equity - 1,
    cagr = g5_ema_cross_cagr(1, ending_equity, min(equity_curve$session_date), max(equity_curve$session_date)),
    sharpe = g5_ema_cross_sharpe(equity_curve$strategy_equity),
    max_drawdown = min(equity_curve$strategy_drawdown, na.rm = TRUE),
    trade_count = if (is.data.frame(trades)) nrow(trades) else 0L,
    closed_trade_count = nrow(closed),
    win_rate = if (!length(closed_returns)) NA_real_ else mean(closed_returns > 0),
    buy_hold_total_return = tail(equity_curve$buy_hold_equity, 1L) - 1,
    stringsAsFactors = FALSE
  )
}

g5_pca_wfa_prepare_panel_for_fold <- function(
  bars,
  symbol,
  regime_context_symbols,
  pca_panel_mode,
  fold,
  feature_cols = g5_pca_regime_default_features()
) {
  mode <- g5_pca_wfa_panel_mode(pca_panel_mode)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  regime_context_symbols <- unique(c(symbol, g5_standardize_symbol(regime_context_symbols)))
  if (identical(mode, "pooled_asset_day")) {
    features <- g5_pca_regime_pooled_feature_table(
      bars,
      target_symbol = symbol,
      context_symbols = regime_context_symbols,
      end_date = fold$oos_end_date[[1L]],
      feature_cols = feature_cols
    )
    return(list(features = features, feature_cols = feature_cols, routing_symbol = symbol, pca_panel_mode = mode))
  }
  use_context_panel <- length(regime_context_symbols) > 1L || !identical(regime_context_symbols[[1L]], symbol)
  features <- if (use_context_panel) {
    g5_pca_regime_context_feature_table(bars, symbol, regime_context_symbols, end_date = fold$oos_end_date[[1L]], feature_cols = feature_cols)
  } else {
    g5_pca_regime_feature_table(bars, symbol, end_date = fold$oos_end_date[[1L]])
  }
  pca_feature_cols <- if (use_context_panel) {
    g5_pca_regime_context_feature_cols(regime_context_symbols, feature_cols)
  } else {
    feature_cols
  }
  list(features = features, feature_cols = pca_feature_cols, routing_symbol = symbol, pca_panel_mode = mode)
}

g5_pca_wfa_route_scores_to_symbol <- function(pca, symbol, pca_panel_mode) {
  mode <- g5_pca_wfa_panel_mode(pca_panel_mode)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  if (identical(mode, "pooled_asset_day")) {
    pca$scores <- pca$scores[pca$scores$symbol == symbol, , drop = FALSE]
    rownames(pca$scores) <- NULL
  }
  pca$scores$pca_panel_mode <- mode
  pca$model_contract$pca_panel_mode <- mode
  pca$model_contract$routing_symbol <- symbol
  pca
}

g5_pca_wfa_fit_fold_models <- function(
  bars,
  symbol,
  folds,
  model_grid,
  grid_n = 3L,
  state_engine = c("quantile_grid", "pca_kmeans"),
  kmeans_nstart = 30L,
  regime_context_symbols = symbol,
  pca_panel_mode = "date_aligned_context",
  min_train_state_rows = 20L
) {
  state_engine <- match.arg(state_engine)
  pca_panel_mode <- g5_pca_wfa_panel_mode(pca_panel_mode)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  regime_context_symbols <- unique(c(symbol, g5_standardize_symbol(regime_context_symbols)))
  fold_models <- list()
  selected_rows <- list()
  perf_rows <- list()
  coverage_rows <- list()
  score_rows <- list()
  contract_rows <- list()
  for (fold_i in seq_len(nrow(folds))) {
    fold <- folds[fold_i, , drop = FALSE]
    panel <- g5_pca_wfa_prepare_panel_for_fold(
      bars,
      symbol = symbol,
      regime_context_symbols = regime_context_symbols,
      pca_panel_mode = pca_panel_mode,
      fold = fold
    )
    pca <- if (identical(state_engine, "pca_kmeans")) {
      g5_pca_regime_fit_kmeans(
        panel$features,
        train_start_date = fold$train_start_date[[1L]],
        train_end_date = fold$train_end_date[[1L]],
        oos_start_date = fold$oos_start_date[[1L]],
        oos_end_date = fold$oos_end_date[[1L]],
        feature_cols = panel$feature_cols,
        cluster_count = grid_n,
        nstart = kmeans_nstart
      )
    } else {
      g5_pca_regime_fit(
        panel$features,
        train_start_date = fold$train_start_date[[1L]],
        train_end_date = fold$train_end_date[[1L]],
        oos_start_date = fold$oos_start_date[[1L]],
        oos_end_date = fold$oos_end_date[[1L]],
        feature_cols = panel$feature_cols,
        grid_n = grid_n
      )
    }
    pca <- g5_pca_wfa_route_scores_to_symbol(pca, symbol, pca_panel_mode)
    pca$scores$regime_context_symbols <- paste(regime_context_symbols, collapse = ",")
    pca$model_contract$regime_context_symbols <- paste(regime_context_symbols, collapse = ",")
    pca$model_contract$research_candidate_symbol <- symbol
    selection <- g5_pca_wfa_select_state_specs(
      bars,
      symbol = symbol,
      pca_result = pca,
      fold = fold,
      model_grid = model_grid,
      exit_stacks = g5_pca_wfa_native_only_exit_stack(),
      min_train_state_rows = min_train_state_rows
    )
    pca$scores$fold_id <- fold$fold_id[[1L]]
    pca$scores$fold_no <- fold$fold_no[[1L]]
    pca$model_contract$fold_id <- fold$fold_id[[1L]]
    pca$model_contract$fold_no <- fold$fold_no[[1L]]
    selection$state_coverage$fold_id <- fold$fold_id[[1L]]
    selection$state_coverage$fold_no <- fold$fold_no[[1L]]

    fold_models[[fold$fold_id[[1L]]]] <- list(fold = fold, pca = pca, selection = selection)
    selected_rows[[length(selected_rows) + 1L]] <- selection$selected_states
    perf_rows[[length(perf_rows) + 1L]] <- selection$train_state_performance
    coverage_rows[[length(coverage_rows) + 1L]] <- selection$state_coverage
    score_rows[[length(score_rows) + 1L]] <- pca$scores
    contract_rows[[length(contract_rows) + 1L]] <- pca$model_contract
  }
  list(
    fold_models = fold_models,
    selected_states = g5_wfa_bind_rows_fill(selected_rows),
    train_state_performance = g5_wfa_bind_rows_fill(perf_rows),
    state_coverage = g5_wfa_bind_rows_fill(coverage_rows),
    pca_scores = g5_wfa_bind_rows_fill(score_rows),
    pca_model_contract = g5_wfa_bind_rows_fill(contract_rows)
  )
}

g5_pca_wfa_simulate_stitched_oos <- function(bars, symbol, folds, fold_models, selected_states, leverage = 1) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  final_oos_date <- as.Date(folds$oos_end_date[[nrow(folds)]])
  first_oos_date <- as.Date(folds$oos_start_date[[1L]])
  first_signal_date <- as.Date(folds$train_end_date[[1L]])
  all_bars <- g5_ema_cross_prepare_bars(bars, symbol = symbol, end_date = final_oos_date)
  session_dates <- as.Date(all_bars$session_date)
  date_to_index <- function(x) match(as.Date(x), session_dates)

  state_lookup_by_fold <- list()
  for (fold_id in names(fold_models)) {
    state_lookup_by_fold[[fold_id]] <- g5_pca_wfa_state_lookup(fold_models[[fold_id]]$pca$scores)
  }
  state_for <- function(fold_no, date) {
    if (is.na(fold_no) || fold_no < 1L || fold_no > nrow(folds)) return(NA_character_)
    fold_id <- folds$fold_id[[fold_no]]
    out <- unname(state_lookup_by_fold[[fold_id]][[as.character(as.Date(date))]])
    if (is.null(out) || is.na(out)) NA_character_ else out
  }

  selected_keys <- paste(selected_states$fold_id, selected_states$state_id, sep = "::")
  selected_by_key <- split(selected_states, selected_keys)
  get_selected <- function(fold_no, state) {
    if (is.na(fold_no) || is.na(state)) return(selected_states[0L, , drop = FALSE])
    key <- paste(folds$fold_id[[fold_no]], state, sep = "::")
    if (key %in% names(selected_by_key)) return(selected_by_key[[key]][1L, , drop = FALSE])
    selected_states[0L, , drop = FALSE]
  }

  indicator_cache <- list()
  for (i in seq_len(nrow(selected_states))) {
    row <- selected_states[i, , drop = FALSE]
    spec_id <- row$strategy_spec_id[[1L]]
    if (!spec_id %in% names(indicator_cache)) {
      indicator_cache[[spec_id]] <- g5_wfa_model_indicators(all_bars, symbol, g5_pca_wfa_model_from_metric(row))
    }
  }

  signal_indices <- which(session_dates >= first_signal_date & session_dates <= final_oos_date)
  trades <- list()
  trade_no <- 0L
  in_position <- FALSE
  open_trade <- NULL
  pending_entry <- NULL
  pending_exit <- NULL

  for (idx in signal_indices) {
    current_date <- session_dates[[idx]]

    if (!is.null(pending_entry) && identical(as.Date(pending_entry$execution_date), current_date) && !in_position && current_date >= first_oos_date) {
      execution_fold_no <- g5_ema_cross_wfa_fold_for_execution_date(current_date, folds)
      execution_state <- state_for(execution_fold_no, current_date)
      if (!is.na(execution_fold_no)) {
        trade_no <- trade_no + 1L
        open_trade <- c(
          pending_entry,
          list(
            trade_no = trade_no,
            entry_execution_idx = idx,
            entry_execution_date = current_date,
            entry_execution_price = as.numeric(all_bars$open[[idx]]),
            entry_execution_fold_id = folds$fold_id[[execution_fold_no]],
            entry_execution_state_id = execution_state
          )
        )
        in_position <- TRUE
      }
      pending_entry <- NULL
    }

    if (!is.null(pending_exit) && identical(as.Date(pending_exit$execution_date), current_date) && in_position) {
      execution_fold_no <- g5_ema_cross_wfa_fold_for_execution_date(current_date, folds)
      execution_state <- state_for(execution_fold_no, current_date)
      if (!is.na(execution_fold_no)) {
        entry_price <- open_trade$entry_execution_price
        exit_price <- as.numeric(all_bars$open[[idx]])
        underlying_realized_return <- (exit_price / entry_price) - 1
        realized_return <- leverage * underlying_realized_return
        carried <- open_trade$entry_execution_fold_id != folds$fold_id[[execution_fold_no]]
        trades[[length(trades) + 1L]] <- data.frame(
          schema_version = g5_pca_wfa_schema_version(),
          trade_id = sprintf("%s_pca_wfa_%03d", symbol, open_trade$trade_no),
          symbol = symbol,
          fold_id = open_trade$entry_signal_fold_id,
          fold_no = open_trade$entry_signal_fold_no,
          ownership_policy = "entry_state_owns_trade_until_exit",
          entry_state_id = open_trade$entry_state_id,
          entry_execution_state_id = open_trade$entry_execution_state_id,
          exit_signal_state_id = pending_exit$exit_signal_state_id,
          exit_execution_state_id = execution_state,
          entry_signal_fold_id = open_trade$entry_signal_fold_id,
          entry_execution_fold_id = open_trade$entry_execution_fold_id,
          exit_signal_fold_id = pending_exit$exit_signal_fold_id,
          exit_execution_fold_id = folds$fold_id[[execution_fold_no]],
          carried_across_fold_boundary = carried,
          strategy_family = open_trade$strategy_family,
          model_instance_id = open_trade$model_instance_id,
          exit_stack_id = open_trade$exit_stack_id,
          strategy_spec_id = open_trade$strategy_spec_id,
          primary_exit_reason = pending_exit$primary_exit_reason,
          triggered_exit_rules = pending_exit$triggered_exit_rules,
          exit_attribution = pending_exit$exit_attribution,
          fast_period = open_trade$fast_period,
          slow_period = open_trade$slow_period,
          lookback_period = open_trade$lookback_period,
          sd_multiplier = open_trade$sd_multiplier,
          trade_status = "closed",
          entry_signal_date = open_trade$entry_signal_date,
          entry_signal_index = open_trade$entry_signal_idx,
          entry_signal_price = open_trade$entry_signal_price,
          entry_execution_date = open_trade$entry_execution_date,
          entry_execution_index = open_trade$entry_execution_idx,
          entry_execution_price = entry_price,
          exit_signal_date = pending_exit$exit_signal_date,
          exit_signal_index = pending_exit$exit_signal_idx,
          exit_signal_price = pending_exit$exit_signal_price,
          exit_execution_date = current_date,
          exit_execution_index = idx,
          exit_execution_price = exit_price,
          latest_mark_date = final_oos_date,
          latest_mark_price = as.numeric(all_bars$close[[date_to_index(final_oos_date)]]),
          trace_end_date = current_date,
          trace_end_index = idx,
          trace_end_price = exit_price,
          underlying_realized_return = underlying_realized_return,
          underlying_unrealized_return = NA_real_,
          realized_return = realized_return,
          unrealized_return = NA_real_,
          trace_return = realized_return,
          trade_outcome = if (realized_return > 0) "win" else if (realized_return < 0) "loss" else "flat",
          holding_sessions_completed = idx - open_trade$entry_execution_idx + 1L,
          signal_rule = open_trade$entry_signal_rule,
          entry_execution_rule = "next_session_open_after_entry_signal",
          exit_signal_rule = pending_exit$exit_signal_rule,
          exit_execution_rule = "next_session_open_after_exit_signal",
          leverage = leverage,
          capital_fraction = 1,
          stringsAsFactors = FALSE
        )
        in_position <- FALSE
        open_trade <- NULL
      }
      pending_exit <- NULL
    }

    signal_fold_no <- g5_ema_cross_wfa_fold_for_signal_date(current_date, folds)
    if (is.na(signal_fold_no)) {
      next
    }
    signal_fold_id <- folds$fold_id[[signal_fold_no]]
    current_state <- state_for(signal_fold_no, current_date)
    next_idx <- idx + 1L
    if (next_idx > nrow(all_bars) || session_dates[[next_idx]] > final_oos_date) {
      next
    }
    next_execution_fold_no <- g5_ema_cross_wfa_fold_for_execution_date(session_dates[[next_idx]], folds)
    if (is.na(next_execution_fold_no)) {
      next
    }

    if (!in_position && is.null(pending_entry)) {
      selected <- get_selected(signal_fold_no, current_state)
      if (nrow(selected) == 0L || identical(as.character(selected$strategy_family[[1L]]), "no_trade")) {
        next
      }
      ind <- indicator_cache[[selected$strategy_spec_id[[1L]]]]
      if (isTRUE(ind$entry_signal[[idx]])) {
        pending_entry <- list(
          entry_state_id = current_state,
          entry_signal_fold_id = signal_fold_id,
          entry_signal_fold_no = signal_fold_no,
          strategy_family = selected$strategy_family[[1L]],
          model_instance_id = selected$model_instance_id[[1L]],
          exit_stack_id = selected$exit_stack_id[[1L]],
          strategy_spec_id = selected$strategy_spec_id[[1L]],
          fast_period = g5_wfa_model_value(selected, "fast_period", NA_integer_),
          slow_period = g5_wfa_model_value(selected, "slow_period", NA_integer_),
          lookback_period = g5_wfa_model_value(selected, "lookback_period", NA_integer_),
          sd_multiplier = g5_wfa_model_value(selected, "sd_multiplier", NA_real_),
          entry_signal_rule = ind$entry_signal_rule[[idx]],
          entry_signal_date = current_date,
          entry_signal_idx = idx,
          entry_signal_price = as.numeric(all_bars$close[[idx]]),
          execution_date = session_dates[[next_idx]]
        )
      }
    }

    if (in_position && is.null(pending_exit)) {
      owner <- selected_states[
        selected_states$fold_id == open_trade$entry_signal_fold_id &
          selected_states$state_id == open_trade$entry_state_id &
          selected_states$strategy_spec_id == open_trade$strategy_spec_id,
        ,
        drop = FALSE
      ]
      if (nrow(owner) == 0L) {
        owner <- selected_states[selected_states$strategy_spec_id == open_trade$strategy_spec_id, , drop = FALSE][1L, , drop = FALSE]
      }
      ind <- indicator_cache[[open_trade$strategy_spec_id]]
      exit_event <- g5_wfa_exit_event(ind, idx, open_trade, g5_pca_wfa_exit_stack_from_metric(owner))
      if (!is.null(exit_event)) {
        pending_exit <- c(
          exit_event,
          list(
            exit_signal_fold_id = signal_fold_id,
            exit_signal_state_id = current_state,
            exit_signal_date = current_date,
            exit_signal_idx = idx,
            exit_signal_price = as.numeric(all_bars$close[[idx]]),
            execution_date = session_dates[[next_idx]]
          )
        )
      }
    }
  }

  if (in_position && !is.null(open_trade)) {
    latest_idx <- date_to_index(final_oos_date)
    latest_close <- as.numeric(all_bars$close[[latest_idx]])
    underlying_unrealized_return <- (latest_close / open_trade$entry_execution_price) - 1
    unrealized_return <- leverage * underlying_unrealized_return
    final_fold_no <- g5_ema_cross_wfa_fold_for_execution_date(final_oos_date, folds)
    trades[[length(trades) + 1L]] <- data.frame(
      schema_version = g5_pca_wfa_schema_version(),
      trade_id = sprintf("%s_pca_wfa_%03d", symbol, open_trade$trade_no),
      symbol = symbol,
      fold_id = open_trade$entry_signal_fold_id,
      fold_no = open_trade$entry_signal_fold_no,
      ownership_policy = "entry_state_owns_trade_until_exit",
      entry_state_id = open_trade$entry_state_id,
      entry_execution_state_id = open_trade$entry_execution_state_id,
      exit_signal_state_id = NA_character_,
      exit_execution_state_id = NA_character_,
      entry_signal_fold_id = open_trade$entry_signal_fold_id,
      entry_execution_fold_id = open_trade$entry_execution_fold_id,
      exit_signal_fold_id = NA_character_,
      exit_execution_fold_id = NA_character_,
      carried_across_fold_boundary = open_trade$entry_execution_fold_id != folds$fold_id[[final_fold_no]],
      strategy_family = open_trade$strategy_family,
      model_instance_id = open_trade$model_instance_id,
      exit_stack_id = open_trade$exit_stack_id,
      strategy_spec_id = open_trade$strategy_spec_id,
      primary_exit_reason = NA_character_,
      triggered_exit_rules = NA_character_,
      exit_attribution = NA_character_,
      fast_period = open_trade$fast_period,
      slow_period = open_trade$slow_period,
      lookback_period = open_trade$lookback_period,
      sd_multiplier = open_trade$sd_multiplier,
      trade_status = "open",
      entry_signal_date = open_trade$entry_signal_date,
      entry_signal_index = open_trade$entry_signal_idx,
      entry_signal_price = open_trade$entry_signal_price,
      entry_execution_date = open_trade$entry_execution_date,
      entry_execution_index = open_trade$entry_execution_idx,
      entry_execution_price = open_trade$entry_execution_price,
      exit_signal_date = as.Date(NA),
      exit_signal_index = NA_integer_,
      exit_signal_price = NA_real_,
      exit_execution_date = as.Date(NA),
      exit_execution_index = NA_integer_,
      exit_execution_price = NA_real_,
      latest_mark_date = final_oos_date,
      latest_mark_price = latest_close,
      trace_end_date = final_oos_date,
      trace_end_index = latest_idx,
      trace_end_price = latest_close,
      underlying_realized_return = NA_real_,
      underlying_unrealized_return = underlying_unrealized_return,
      realized_return = NA_real_,
      unrealized_return = unrealized_return,
      trace_return = unrealized_return,
      trade_outcome = if (unrealized_return > 0) "win" else if (unrealized_return < 0) "loss" else "flat",
      holding_sessions_completed = latest_idx - open_trade$entry_execution_idx + 1L,
      signal_rule = open_trade$entry_signal_rule,
      entry_execution_rule = "next_session_open_after_entry_signal",
      exit_signal_rule = "entry_state_owned_spec_until_exit",
      exit_execution_rule = "next_session_open_after_exit_signal",
      leverage = leverage,
      capital_fraction = 1,
      stringsAsFactors = FALSE
    )
  }

  trades_out <- if (length(trades) == 0L) data.frame() else do.call(rbind, trades)
  if (nrow(trades_out) > 0L) rownames(trades_out) <- NULL
  equity_curve <- g5_ema_cross_equity_curve(
    trades_out,
    all_bars,
    symbol = symbol,
    trading_start_date = first_oos_date,
    trading_end_date = final_oos_date,
    leverage = leverage
  )
  list(trades = trades_out, equity_curve = equity_curve)
}

g5_pca_wfa_run_multi <- function(
  bars,
  symbol,
  wfa_start_date,
  wfa_end_date,
  fast_periods = c(8L, 12L),
  slow_periods = c(30L, 50L),
  bb_lookback_periods = c(10L, 20L),
  bb_sd_multipliers = c(1.5, 2),
  candidate_families = c("ema_cross", "bollinger_touch", "no_trade"),
  train_quarters = 8,
  oos_quarters = 1,
  fold_count = 1L,
  grid_n = 3L,
  state_engine = c("quantile_grid", "pca_kmeans"),
  kmeans_nstart = 30L,
  regime_context_symbols = symbol,
  pca_panel_mode = "date_aligned_context",
  min_train_state_rows = 20L
) {
  state_engine <- match.arg(state_engine)
  pca_panel_mode <- g5_pca_wfa_panel_mode(pca_panel_mode)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  regime_context_symbols <- unique(c(symbol, g5_standardize_symbol(regime_context_symbols)))
  candidate_families <- unique(c(g5_wfa_candidate_families(candidate_families), "no_trade"))
  folds <- g5_ema_cross_wfa_resolve_folds(
    bars,
    symbol = symbol,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    fold_count = fold_count
  )
  model_grid <- g5_wfa_candidate_model_grid(
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    candidate_families = candidate_families
  )
  fitted <- g5_pca_wfa_fit_fold_models(
    bars,
    symbol = symbol,
    folds = folds,
    model_grid = model_grid,
    grid_n = grid_n,
    state_engine = state_engine,
    kmeans_nstart = kmeans_nstart,
    regime_context_symbols = regime_context_symbols,
    pca_panel_mode = pca_panel_mode,
    min_train_state_rows = min_train_state_rows
  )
  oos <- g5_pca_wfa_simulate_stitched_oos(bars, symbol, folds, fitted$fold_models, fitted$selected_states)
  metrics <- g5_pca_wfa_route_metrics(oos$trades, oos$equity_curve, symbol)
  list(
    folds = folds,
    pca = fitted$fold_models[[folds$fold_id[[1L]]]]$pca,
    fold_models = fitted$fold_models,
    pca_scores = fitted$pca_scores,
    pca_model_contract = fitted$pca_model_contract,
    model_grid = model_grid,
    selected_states = fitted$selected_states,
    train_state_performance = fitted$train_state_performance,
    state_coverage = fitted$state_coverage,
    oos_trades = oos$trades,
    oos_equity_curve = oos$equity_curve,
    oos_metrics = metrics,
    settings = list(
      ownership_policy = "entry_state_owns_trade_until_exit",
      candidate_families = candidate_families,
      fold_count = nrow(folds),
      grid_n = grid_n,
      state_engine = state_engine,
      kmeans_nstart = kmeans_nstart,
      regime_context_symbols = regime_context_symbols,
      pca_panel_mode = pca_panel_mode,
      research_candidate_universe = symbol,
      tradeable_universe = symbol,
      active_allocation_set = symbol,
      min_train_state_rows = min_train_state_rows
    )
  )
}

g5_pca_wfa_run_one_fold <- function(
  bars,
  symbol,
  wfa_start_date,
  wfa_end_date,
  fast_periods = c(8L, 12L),
  slow_periods = c(30L, 50L),
  bb_lookback_periods = c(10L, 20L),
  bb_sd_multipliers = c(1.5, 2),
  candidate_families = c("ema_cross", "bollinger_touch", "no_trade"),
  train_quarters = 8,
  oos_quarters = 1,
  grid_n = 3L,
  state_engine = c("quantile_grid", "pca_kmeans"),
  kmeans_nstart = 30L,
  regime_context_symbols = symbol,
  pca_panel_mode = "date_aligned_context",
  min_train_state_rows = 20L
) {
  g5_pca_wfa_run_multi(
    bars = bars,
    symbol = symbol,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    candidate_families = candidate_families,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    fold_count = 1L,
    grid_n = grid_n,
    state_engine = state_engine,
    kmeans_nstart = kmeans_nstart,
    regime_context_symbols = regime_context_symbols,
    pca_panel_mode = pca_panel_mode,
    min_train_state_rows = min_train_state_rows
  )
}

g5_pca_wfa_write_state_price_chart_png <- function(pca_wfa, symbol, path, width = 1500L, height = 850L) {
  scores <- if ("pca_scores" %in% names(pca_wfa)) pca_wfa$pca_scores else pca_wfa$pca$scores
  folds <- pca_wfa$folds
  trades <- pca_wfa$oos_trades
  scores <- scores[order(as.Date(scores$session_date), scores$fold_no), , drop = FALSE]
  aesthetic <- g5_chart_aesthetic()
  pal <- g5_pca_regime_state_palette(sort(unique(stats::na.omit(scores$state_id))))
  first_signal_date <- as.Date(folds$train_end_date[[1L]])
  final_oos_date <- as.Date(folds$oos_end_date[[nrow(folds)]])
  keep <- !is.na(scores$split) & scores$split == "OOS" & as.Date(scores$session_date) <= final_oos_date
  first_context <- as.Date(scores$session_date) == first_signal_date & scores$fold_id == folds$fold_id[[1L]]
  keep <- keep | ifelse(is.na(first_context), FALSE, first_context)
  plot_rows <- scores[keep, , drop = FALSE]
  plot_rows <- plot_rows[!duplicated(paste(plot_rows$session_date, plot_rows$fold_id)), , drop = FALSE]
  plot_rows <- plot_rows[order(as.Date(plot_rows$session_date), plot_rows$fold_no), , drop = FALSE]
  x <- seq_len(nrow(plot_rows))
  y <- range(c(plot_rows$low, plot_rows$high), finite = TRUE)
  padding <- diff(y) * 0.06
  y_limits <- y + c(-padding, padding)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(9.6, 5.4, 4.2, 10), bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  engine_label <- if ("settings" %in% names(pca_wfa) && identical(pca_wfa$settings$state_engine, "pca_kmeans")) "PCA K-Means-Routed WFA OOS" else "PCA-Routed WFA OOS"
  if ("settings" %in% names(pca_wfa) && identical(pca_wfa$settings$pca_panel_mode, "pooled_asset_day")) {
    engine_label <- sub("PCA", "Pooled PCA", engine_label, fixed = TRUE)
  }
  graphics::plot(c(0.5, length(x) + 0.5), y_limits, type = "n", xaxt = "n", xlab = "", ylab = "Adjusted daily price", main = paste(g5_standardize_symbol(symbol)[[1L]], engine_label), xaxs = "i")
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  if (nrow(plot_rows)) {
    run_key <- paste(plot_rows$fold_id, plot_rows$state_id, sep = "::")
    runs <- rle(run_key)
    run_ends <- cumsum(runs$lengths)
    run_starts <- run_ends - runs$lengths + 1L
    for (i in seq_along(runs$values)) {
      state <- plot_rows$state_id[[run_starts[[i]]]]
      if (!is.na(state) && state %in% names(pal)) {
        graphics::rect(run_starts[[i]] - 0.5, usr[[3L]], run_ends[[i]] + 0.5, usr[[4L]], col = grDevices::adjustcolor(pal[[state]], alpha.f = 0.16), border = NA)
      }
    }
  }
  for (i in seq_len(nrow(folds))) {
    boundary_idx <- match(as.Date(folds$oos_start_date[[i]]), as.Date(plot_rows$session_date))
    if (!is.na(boundary_idx)) {
      graphics::abline(v = boundary_idx - 0.5, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.8), lty = 2, lwd = 1.3)
    }
  }
  body_cols <- ifelse(plot_rows$close > plot_rows$open, aesthetic$up_candle, ifelse(plot_rows$close < plot_rows$open, aesthetic$down_candle, aesthetic$flat_candle))
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  graphics::segments(x, plot_rows$low, x, plot_rows$high, col = body_cols, lwd = 1.1)
  graphics::rect(x - 0.28, pmin(plot_rows$open, plot_rows$close), x + 0.28, pmax(plot_rows$open, plot_rows$close), col = body_cols, border = body_cols)
  if (is.data.frame(trades) && nrow(trades)) {
    dates <- as.Date(plot_rows$session_date)
    line_cols <- ifelse(trades$trade_outcome == "win", aesthetic$trade_win_line, ifelse(trades$trade_outcome == "loss", aesthetic$trade_loss_line, aesthetic$flat_candle))
    graphics::segments(match(trades$entry_execution_date, dates), trades$entry_execution_price, match(trades$trace_end_date, dates), trades$trace_end_price, col = line_cols, lty = aesthetic$trade_line_lty, lwd = 1.2)
    graphics::points(match(trades$entry_signal_date, dates), trades$entry_signal_price, pch = aesthetic$entry_signal_pch, col = aesthetic$entry_signal_color, bg = aesthetic$panel_background, cex = 1.1, lwd = 1.4)
    graphics::points(match(trades$entry_execution_date, dates), trades$entry_execution_price, pch = aesthetic$native_entry_pch, col = aesthetic$native_entry_color, bg = aesthetic$native_entry_color, cex = 1.05)
    closed <- trades[!is.na(trades$exit_execution_date), , drop = FALSE]
    if (nrow(closed)) {
      graphics::points(match(closed$exit_signal_date, dates), closed$exit_signal_price, pch = aesthetic$exit_signal_pch, col = aesthetic$exit_signal_color, bg = aesthetic$panel_background, cex = 1.1, lwd = 1.4)
      graphics::points(match(closed$exit_execution_date, dates), closed$exit_execution_price, pch = aesthetic$native_exit_pch, col = aesthetic$native_exit_color, bg = aesthetic$native_exit_color, cex = 1.05)
    }
  }
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(8L, length(x)))))
  g5_axis_date_labels_45(tick_positions, as.character(as.Date(plot_rows$session_date)[tick_positions]), line_offset = 0.066, color = aesthetic$axis)
  graphics::mtext("Session date", side = 1, line = 7.7, cex = 1.05, col = aesthetic$text)
  graphics::mtext("Colored bands: fold-local PCA states | dashed lines: OOS fold starts | policy: entry-state owns trade until exit", side = 3, line = 0.3, cex = 0.75, col = aesthetic$text)
  graphics::par(xpd = NA)
  graphics::legend("right", inset = c(-0.19, 0), legend = names(pal), fill = grDevices::adjustcolor(pal, alpha.f = 0.55), border = NA, bty = "n", cex = 0.75, text.col = aesthetic$text, title = "state")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_pca_wfa_write_equity_png <- function(equity_curve, path, symbol, folds = NULL, width = 1500L, height = 760L, state_engine = "quantile_grid", pca_panel_mode = "date_aligned_context") {
  aesthetic <- g5_chart_aesthetic()
  x <- seq_len(nrow(equity_curve))
  y <- range(c(equity_curve$strategy_equity, equity_curve$buy_hold_equity), finite = TRUE)
  padding <- diff(y) * 0.08
  y_limits <- y + c(-padding, padding)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(9.2, 5.4, 4.2, 2), bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  route_label <- if (identical(as.character(state_engine), "pca_kmeans")) "PCA K-Means-routed strategy" else "PCA-routed strategy"
  title_label <- if (identical(as.character(state_engine), "pca_kmeans")) "PCA K-Means-Routed WFA OOS Equity" else "PCA-Routed WFA OOS Equity"
  if (identical(g5_pca_wfa_panel_mode(pca_panel_mode), "pooled_asset_day")) {
    route_label <- sub("PCA", "Pooled PCA", route_label, fixed = TRUE)
    title_label <- sub("PCA", "Pooled PCA", title_label, fixed = TRUE)
  }
  graphics::plot(c(0.5, length(x) + 0.5), y_limits, type = "n", xaxt = "n", xlab = "", ylab = "Equity, starting at 1.0", main = paste(g5_standardize_symbol(symbol)[[1L]], title_label), xaxs = "i")
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  if (is.data.frame(folds) && nrow(folds)) {
    for (i in seq_len(nrow(folds))) {
      boundary_idx <- match(as.Date(folds$oos_start_date[[i]]), as.Date(equity_curve$session_date))
      if (!is.na(boundary_idx)) {
        graphics::abline(v = boundary_idx - 0.5, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.65), lty = 2, lwd = 1.1)
      }
    }
  }
  strategy_peak <- cummax(as.numeric(equity_curve$strategy_equity))
  underwater <- equity_curve$strategy_equity < strategy_peak
  if (any(underwater, na.rm = TRUE)) {
    runs <- rle(underwater)
    run_ends <- cumsum(runs$lengths)
    run_starts <- run_ends - runs$lengths + 1L
    for (i in seq_along(runs$values)) {
      if (!isTRUE(runs$values[[i]])) next
      idx <- seq(run_starts[[i]], run_ends[[i]])
      peak_level <- strategy_peak[[idx[[1L]]]]
      segment_start <- max(1L, idx[[1L]] - 1L)
      segment_end <- idx[[length(idx)]]
      segment_end_x <- x[[segment_end]]
      if (segment_end < length(x) && !isTRUE(underwater[[segment_end + 1L]])) {
        y0 <- as.numeric(equity_curve$strategy_equity[[segment_end]])
        y1 <- as.numeric(equity_curve$strategy_equity[[segment_end + 1L]])
        if (is.finite(y0) && is.finite(y1) && y1 != y0) {
          crossing_fraction <- max(0, min(1, (peak_level - y0) / (y1 - y0)))
          segment_end_x <- x[[segment_end]] + crossing_fraction * (x[[segment_end + 1L]] - x[[segment_end]])
        }
      }
      graphics::segments(x[[segment_start]], peak_level, segment_end_x, peak_level, col = grDevices::adjustcolor(aesthetic$down_candle, alpha.f = 0.42), lwd = 2.3, lend = "round")
    }
  }
  graphics::abline(h = 1, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.45), lty = 3)
  graphics::lines(x, equity_curve$strategy_equity, col = aesthetic$trade_win_line, lwd = 2.1)
  graphics::lines(x, equity_curve$buy_hold_equity, col = "#000000", lwd = 1.2)
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(8L, length(x)))))
  g5_axis_date_labels_45(tick_positions, as.character(as.Date(equity_curve$session_date)[tick_positions]), line_offset = 0.08, color = aesthetic$axis)
  graphics::mtext("Session date", side = 1, line = 7.4, cex = 1.05, col = aesthetic$text)
  graphics::legend("topleft", legend = c(route_label, "buy and hold", "drawdown shelf", "fold start"), col = c(aesthetic$trade_win_line, "#000000", grDevices::adjustcolor(aesthetic$down_candle, alpha.f = 0.42), grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.65)), lty = c(1, 1, 1, 2), lwd = c(2.1, 1.2, 2.3, 1.1), bty = "n", text.col = aesthetic$text)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_pca_wfa_scatter_title <- function(symbol, state_engine, pca_panel_mode) {
  engine <- if (identical(as.character(state_engine), "pca_kmeans")) "PCA k-means" else "PCA quantile grid"
  panel <- if (identical(g5_pca_wfa_panel_mode(pca_panel_mode), "pooled_asset_day")) "pooled asset-day" else "date-aligned context"
  paste(g5_standardize_symbol(symbol)[[1L]], engine, panel, "fold-local scores")
}

g5_pca_wfa_write_pca_scatter_from_scores <- function(scores, path, title = "PCA-Routed WFA State Space", width = 1300L, height = 900L) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  aesthetic <- g5_chart_aesthetic()
  plot_rows <- scores[is.finite(scores$pc1) & is.finite(scores$pc2) & !is.na(scores$state_id), , drop = FALSE]
  if (nrow(plot_rows) == 0L) {
    g5_stop("PCA WFA scatter plot requires scored rows.")
  }
  pal <- g5_pca_regime_state_palette(sort(unique(plot_rows$state_id)))
  alpha <- ifelse(plot_rows$split == "OOS", 0.9, 0.30)
  cols <- vapply(
    seq_len(nrow(plot_rows)),
    function(i) grDevices::adjustcolor(pal[[plot_rows$state_id[[i]]]], alpha.f = alpha[[i]]),
    character(1L)
  )
  pch <- ifelse(plot_rows$split == "OOS", 21L, 23L)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(5.2, 5.4, 4.2, 10), xpd = FALSE, bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  graphics::plot(
    plot_rows$pc1,
    plot_rows$pc2,
    type = "n",
    xlab = "PC1",
    ylab = "PC2",
    main = title,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text
  )
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(col = aesthetic$grid)
  graphics::points(plot_rows$pc1, plot_rows$pc2, pch = pch, bg = cols, col = cols, cex = ifelse(plot_rows$split == "OOS", 0.95, 0.58))
  split_legend_col <- c(
    grDevices::adjustcolor(aesthetic$text, alpha.f = 0.45),
    grDevices::adjustcolor(aesthetic$text, alpha.f = 0.9)
  )
  graphics::legend(
    "topright",
    legend = c("TRAIN", "OOS"),
    pch = c(23L, 21L),
    pt.bg = split_legend_col,
    col = split_legend_col,
    bty = "n",
    text.col = aesthetic$text
  )
  graphics::mtext("Fold-local PCA coordinates are overlaid for inspection; axes are not a single global PCA fit.", side = 3, line = 0.2, cex = 0.72, col = aesthetic$text)
  graphics::par(xpd = NA)
  graphics::legend("right", inset = c(-0.19, 0), legend = names(pal), fill = pal, border = NA, bty = "n", cex = 0.72, text.col = aesthetic$text, title = "state")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_pca_wfa_write_pca_scatter_png <- function(pca_wfa, path, symbol, width = 1300L, height = 900L) {
  scores <- if ("pca_scores" %in% names(pca_wfa)) pca_wfa$pca_scores else pca_wfa$pca$scores
  title <- g5_pca_wfa_scatter_title(symbol, pca_wfa$settings$state_engine, pca_wfa$settings$pca_panel_mode)
  g5_pca_wfa_write_pca_scatter_from_scores(scores, path, title = title, width = width, height = height)
}

g5_pca_wfa_markdown_report <- function(pca_wfa, paths, symbol, as_of_timestamp, path) {
  metric <- pca_wfa$oos_metrics[1L, , drop = FALSE]
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  selected <- pca_wfa$selected_states
  selected_lines <- apply(
    selected[, c("fold_id", "state_id", "strategy_family", "strategy_spec_id", "train_state_row_count", "train_state_trade_count", "sharpe", "total_return", "selection_reason"), drop = FALSE],
    1,
    function(x) paste0("| ", paste(x, collapse = " | "), " |")
  )
  fold_lines <- apply(
    pca_wfa$folds[, c("fold_id", "train_start_date", "train_end_date", "oos_start_date", "oos_end_date", "train_session_count", "oos_session_count"), drop = FALSE],
    1,
    function(x) paste0("| ", paste(x, collapse = " | "), " |")
  )
  lines <- c(
    paste0("# PCA-Routed WFA POC: ", g5_standardize_symbol(symbol)[[1L]]),
    "",
    "Diagnostic POC only: PCA states route OOS strategy specs, but this is not production WFA evidence or live advice.",
    "",
    "## Policy",
    "",
    paste0("- Regime method: `", if (identical(pca_wfa$settings$state_engine, "pca_kmeans")) paste0("PCA k-means, k=", pca_wfa$settings$grid_n) else paste0("PCA ", pca_wfa$settings$grid_n, "x", pca_wfa$settings$grid_n, " quantile grid"), "` fit on each TRAIN fold only."),
    paste0("- PCA panel mode: `", pca_wfa$settings$pca_panel_mode, "`."),
    paste0("- Fold count: `", nrow(pca_wfa$folds), "`."),
    paste0("- Regime Context Universe: `", paste(pca_wfa$settings$regime_context_symbols, collapse = ", "), "`."),
    paste0("- Research Candidate Universe: `", paste(pca_wfa$settings$research_candidate_universe, collapse = ", "), "`."),
    paste0("- Tradeable Universe: `", paste(pca_wfa$settings$tradeable_universe, collapse = ", "), "`."),
    paste0("- Active Allocation Set: `", paste(pca_wfa$settings$active_allocation_set, collapse = ", "), "`."),
    "- Ownership policy: `entry_state_owns_trade_until_exit`.",
    "- OOS behavior: current state can select entries only while flat; open trades remain managed by the entry-state spec.",
    "- Sparse TRAIN states route to `no_trade`.",
    paste0("- Candidate families: `", paste(pca_wfa$settings$candidate_families, collapse = ", "), "`"),
    paste0("- As-of timestamp: `", as.character(as_of_timestamp), "`"),
    "",
    "## Folds",
    "",
    "| fold_id | train_start | train_end | oos_start | oos_end | train_sessions | oos_sessions |",
    "|---|---|---|---|---|---:|---:|",
    fold_lines,
    "",
    "## OOS Metrics",
    "",
    paste0("- Total return: `", pct(metric$total_return[[1L]]), "`"),
    paste0("- Sharpe: `", ifelse(is.na(metric$sharpe[[1L]]), "NA", sprintf("%.3f", metric$sharpe[[1L]])), "`"),
    paste0("- Max drawdown: `", pct(metric$max_drawdown[[1L]]), "`"),
    paste0("- Trades: `", metric$trade_count[[1L]], "`"),
    paste0("- Buy-and-hold return: `", pct(metric$buy_hold_total_return[[1L]]), "`"),
    "",
    "## Selected Spec By Fold And PCA State",
    "",
    "| fold_id | state_id | family | strategy_spec_id | train_state_rows | train_state_trades | train_sharpe | train_return | selection_reason |",
    "|---|---|---|---|---:|---:|---:|---:|---|",
    selected_lines,
    "",
    "## Artifacts",
    "",
    paste0("- Selected states: `", paths$selected_states_csv, "`"),
    paste0("- Train state performance: `", paths$train_state_performance_csv, "`"),
    paste0("- OOS trades: `", paths$oos_trades_csv, "`"),
    paste0("- OOS equity: `", paths$oos_equity_csv, "`"),
    paste0("- PCA scatter: `", paths$pca_scatter_png, "`"),
    paste0("- State strategy chart: `", paths$state_strategy_chart_png, "`"),
    paste0("- Equity chart: `", paths$equity_chart_png, "`")
  )
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_write_pca_wfa_outputs <- function(pca_wfa, output_dir, prefix, symbol, as_of_timestamp) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- list(
    fold_spec_csv = file.path(output_dir, paste0(prefix, "_folds.csv")),
    selected_states_csv = file.path(output_dir, paste0(prefix, "_selected_states.csv")),
    train_state_performance_csv = file.path(output_dir, paste0(prefix, "_train_state_performance.csv")),
    state_coverage_csv = file.path(output_dir, paste0(prefix, "_state_coverage.csv")),
    pca_scores_csv = file.path(output_dir, paste0(prefix, "_pca_scores.csv")),
    pca_model_contract_csv = file.path(output_dir, paste0(prefix, "_pca_model_contract.csv")),
    oos_trades_csv = file.path(output_dir, paste0(prefix, "_oos_trades.csv")),
    oos_equity_csv = file.path(output_dir, paste0(prefix, "_oos_equity.csv")),
    oos_metrics_csv = file.path(output_dir, paste0(prefix, "_oos_metrics.csv")),
    pca_scatter_png = file.path(output_dir, paste0(prefix, "_pca_scatter.png")),
    state_strategy_chart_png = file.path(output_dir, paste0(prefix, "_state_strategy_chart.png")),
    equity_chart_png = file.path(output_dir, paste0(prefix, "_equity_curve.png")),
    report_md = file.path(output_dir, paste0(prefix, "_report.md"))
  )
  g5_wfa_write_csv(pca_wfa$folds, paths$fold_spec_csv)
  g5_wfa_write_csv(pca_wfa$selected_states, paths$selected_states_csv)
  g5_wfa_write_csv(pca_wfa$train_state_performance, paths$train_state_performance_csv)
  g5_wfa_write_csv(pca_wfa$state_coverage, paths$state_coverage_csv)
  pca_scores <- if ("pca_scores" %in% names(pca_wfa)) pca_wfa$pca_scores else pca_wfa$pca$scores
  pca_model_contract <- if ("pca_model_contract" %in% names(pca_wfa)) pca_wfa$pca_model_contract else pca_wfa$pca$model_contract
  g5_wfa_write_csv(pca_scores, paths$pca_scores_csv)
  g5_wfa_write_csv(pca_model_contract, paths$pca_model_contract_csv)
  g5_wfa_write_csv(pca_wfa$oos_trades, paths$oos_trades_csv)
  g5_wfa_write_csv(pca_wfa$oos_equity_curve, paths$oos_equity_csv)
  g5_wfa_write_csv(pca_wfa$oos_metrics, paths$oos_metrics_csv)
  paths$pca_scatter_png <- g5_pca_wfa_write_pca_scatter_png(pca_wfa, paths$pca_scatter_png, symbol)
  paths$state_strategy_chart_png <- g5_pca_wfa_write_state_price_chart_png(pca_wfa, symbol, paths$state_strategy_chart_png)
  paths$equity_chart_png <- g5_pca_wfa_write_equity_png(pca_wfa$oos_equity_curve, paths$equity_chart_png, symbol, pca_wfa$folds, state_engine = pca_wfa$settings$state_engine, pca_panel_mode = pca_wfa$settings$pca_panel_mode)
  paths$report_md <- g5_pca_wfa_markdown_report(pca_wfa, paths, symbol, as_of_timestamp, paths$report_md)
  list(paths = paths, result = pca_wfa)
}

g5_pca_wfa_comparison_prefix <- function(as_of_timestamp, symbol, fold_count, regime_context_symbols, wfa_end_date) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  context_symbols <- unique(g5_standardize_symbol(regime_context_symbols))
  paste(
    c(
      "pcawfa_cmp",
      symbol,
      paste0(fold_count, "f"),
      paste0(length(context_symbols), "ctx"),
      gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date))),
      stamp
    ),
    collapse = "_"
  )
}

g5_pca_wfa_comparison_output_dir <- function(repo_root, as_of_timestamp, symbol, fold_count, regime_context_symbols, wfa_end_date) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "regime_wfa_comparisons",
    g5_pca_wfa_comparison_prefix(as_of_timestamp, symbol, fold_count, regime_context_symbols, wfa_end_date)
  )
}

g5_pca_wfa_read_csv_if_exists <- function(path) {
  if (!file.exists(path)) {
    return(data.frame())
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

g5_pca_wfa_comparison_artifact_paths <- function(run_dir) {
  list(
    fold_spec_csv = file.path(run_dir, "pcawfa_folds.csv"),
    selected_states_csv = file.path(run_dir, "pcawfa_selected_states.csv"),
    train_state_performance_csv = file.path(run_dir, "pcawfa_train_state_performance.csv"),
    state_coverage_csv = file.path(run_dir, "pcawfa_state_coverage.csv"),
    pca_scores_csv = file.path(run_dir, "pcawfa_pca_scores.csv"),
    pca_model_contract_csv = file.path(run_dir, "pcawfa_pca_model_contract.csv"),
    oos_trades_csv = file.path(run_dir, "pcawfa_oos_trades.csv"),
    oos_equity_csv = file.path(run_dir, "pcawfa_oos_equity.csv"),
    oos_metrics_csv = file.path(run_dir, "pcawfa_oos_metrics.csv"),
    pca_scatter_png = file.path(run_dir, "pcawfa_pca_scatter.png"),
    state_strategy_chart_png = file.path(run_dir, "pcawfa_state_strategy_chart.png"),
    equity_chart_png = file.path(run_dir, "pcawfa_equity_curve.png"),
    report_md = file.path(run_dir, "pcawfa_report.md")
  )
}

g5_pca_wfa_comparison_family_counts <- function(run_index) {
  rows <- list()
  for (i in seq_len(nrow(run_index))) {
    paths <- g5_pca_wfa_comparison_artifact_paths(run_index$run_dir[[i]])
    selected <- g5_pca_wfa_read_csv_if_exists(paths$selected_states_csv)
    if (!nrow(selected) || !"strategy_family" %in% names(selected)) {
      rows[[length(rows) + 1L]] <- data.frame(
        panel_mode = run_index$panel_mode[[i]],
        state_map = run_index$state_map[[i]],
        state_count = run_index$state_count[[i]],
        strategy_family = NA_character_,
        selected_state_count = 0L,
        selected_fold_count = 0L,
        stringsAsFactors = FALSE
      )
      next
    }
    counts <- as.data.frame(table(selected$strategy_family), stringsAsFactors = FALSE)
    names(counts) <- c("strategy_family", "selected_state_count")
    counts$selected_state_count <- as.integer(counts$selected_state_count)
    fold_counts <- if ("fold_id" %in% names(selected)) {
      aggregate(fold_id ~ strategy_family, selected, function(x) length(unique(x)))
    } else {
      data.frame(strategy_family = counts$strategy_family, fold_id = NA_integer_, stringsAsFactors = FALSE)
    }
    names(fold_counts) <- c("strategy_family", "selected_fold_count")
    merged <- merge(counts, fold_counts, by = "strategy_family", all.x = TRUE, sort = FALSE)
    merged$panel_mode <- run_index$panel_mode[[i]]
    merged$state_map <- run_index$state_map[[i]]
    merged$state_count <- run_index$state_count[[i]]
    rows[[length(rows) + 1L]] <- merged[, c("panel_mode", "state_map", "state_count", "strategy_family", "selected_state_count", "selected_fold_count"), drop = FALSE]
  }
  do.call(rbind, rows)
}

g5_pca_wfa_comparison_summary <- function(run_index) {
  rows <- list()
  for (i in seq_len(nrow(run_index))) {
    paths <- g5_pca_wfa_comparison_artifact_paths(run_index$run_dir[[i]])
    metrics <- g5_pca_wfa_read_csv_if_exists(paths$oos_metrics_csv)
    selected <- g5_pca_wfa_read_csv_if_exists(paths$selected_states_csv)
    coverage <- g5_pca_wfa_read_csv_if_exists(paths$state_coverage_csv)
    oos_coverage <- if (nrow(coverage) && "split" %in% names(coverage)) coverage[coverage$split == "OOS", , drop = FALSE] else data.frame()
    selected_families <- if (nrow(selected) && "strategy_family" %in% names(selected)) {
      paste(sort(unique(selected$strategy_family)), collapse = ",")
    } else {
      ""
    }
    metric <- if (nrow(metrics)) metrics[1L, , drop = FALSE] else data.frame()
    metric_value <- function(name) {
      if (nrow(metric) && name %in% names(metric)) metric[[name]][[1L]] else NA
    }
    rows[[length(rows) + 1L]] <- data.frame(
      panel_mode = run_index$panel_mode[[i]],
      state_map = run_index$state_map[[i]],
      internal_panel_mode = run_index$internal_panel_mode[[i]],
      state_engine = run_index$state_engine[[i]],
      state_count = run_index$state_count[[i]],
      run_status = if (file.exists(paths$oos_metrics_csv)) "ok" else "missing_outputs",
      total_return = metric_value("total_return"),
      sharpe = metric_value("sharpe"),
      max_drawdown = metric_value("max_drawdown"),
      trade_count = metric_value("trade_count"),
      buy_hold_total_return = metric_value("buy_hold_total_return"),
      oos_state_count = if (nrow(oos_coverage)) nrow(oos_coverage) else 0L,
      oos_covered_states = if (nrow(oos_coverage) && "row_count" %in% names(oos_coverage)) sum(oos_coverage$row_count > 0, na.rm = TRUE) else 0L,
      oos_total_state_rows = if (nrow(oos_coverage) && "row_count" %in% names(oos_coverage)) sum(oos_coverage$row_count, na.rm = TRUE) else 0L,
      min_oos_state_fraction = if (nrow(oos_coverage) && "row_fraction" %in% names(oos_coverage)) min(oos_coverage$row_fraction, na.rm = TRUE) else NA_real_,
      max_oos_state_fraction = if (nrow(oos_coverage) && "row_fraction" %in% names(oos_coverage)) max(oos_coverage$row_fraction, na.rm = TRUE) else NA_real_,
      selected_state_count = if (nrow(selected)) nrow(selected) else 0L,
      no_trade_state_selections = if (nrow(selected) && "strategy_family" %in% names(selected)) sum(selected$strategy_family == "no_trade", na.rm = TRUE) else 0L,
      selected_families = selected_families,
      run_dir = run_index$run_dir[[i]],
      report_md = paths$report_md,
      state_strategy_chart_png = paths$state_strategy_chart_png,
      equity_chart_png = paths$equity_chart_png,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

g5_pca_wfa_comparison_table_lines <- function(df, cols) {
  df <- df[, cols, drop = FALSE]
  header <- paste(c("", names(df), ""), collapse = " | ")
  sep <- paste(c("", rep("---", ncol(df)), ""), collapse = " | ")
  rows <- if (nrow(df)) apply(df, 1, function(row) paste(c("", as.character(row), ""), collapse = " | ")) else character()
  c(header, sep, rows)
}

g5_pca_wfa_comparison_item_label <- function(item) {
  paste0(item$panel_mode, " / ", item$state_map)
}

g5_pca_wfa_comparison_plot_date_axis <- function(session_dates, tick_count = 4L, cex = 0.62) {
  if (!length(session_dates)) return(invisible(NULL))
  tick_positions <- unique(round(seq(1L, length(session_dates), length.out = min(tick_count, length(session_dates)))))
  graphics::axis(1, at = tick_positions, labels = FALSE)
  usr <- graphics::par("usr")
  y <- usr[[3L]] - diff(usr[3:4]) * 0.055
  graphics::text(
    x = tick_positions,
    y = y,
    labels = format(as.Date(session_dates[tick_positions]), "%Y-%m"),
    srt = 45,
    adj = 1,
    xpd = NA,
    cex = cex,
    col = g5_chart_aesthetic()$axis
  )
}

g5_pca_wfa_read_comparison_items <- function(path_index) {
  items <- vector("list", nrow(path_index))
  for (i in seq_len(nrow(path_index))) {
    paths <- g5_pca_wfa_comparison_artifact_paths(path_index$run_dir[[i]])
    items[[i]] <- list(
      panel_mode = path_index$panel_mode[[i]],
      state_map = path_index$state_map[[i]],
      state_count = path_index$state_count[[i]],
      run_dir = path_index$run_dir[[i]],
      folds = g5_pca_wfa_read_csv_if_exists(paths$fold_spec_csv),
      scores = g5_pca_wfa_read_csv_if_exists(paths$pca_scores_csv),
      trades = g5_pca_wfa_read_csv_if_exists(paths$oos_trades_csv),
      equity = g5_pca_wfa_read_csv_if_exists(paths$oos_equity_csv),
      metrics = g5_pca_wfa_read_csv_if_exists(paths$oos_metrics_csv)
    )
  }
  items
}

g5_pca_wfa_draw_comparison_equity_panel <- function(item) {
  aesthetic <- g5_chart_aesthetic()
  curve <- item$equity
  if (!is.data.frame(curve) || !nrow(curve)) {
    graphics::plot.new()
    graphics::title(g5_pca_wfa_comparison_item_label(item))
    graphics::text(0.5, 0.5, "missing equity")
    return(invisible(NULL))
  }
  session_dates <- as.Date(curve$session_date)
  x <- seq_len(nrow(curve))
  y <- range(c(curve$strategy_equity, curve$buy_hold_equity), finite = TRUE)
  padding <- diff(y) * 0.08
  if (!is.finite(padding) || padding <= 0) padding <- 0.05
  graphics::plot(c(0.5, length(x) + 0.5), y + c(-padding, padding), type = "n", xaxt = "n", xlab = "", ylab = "", main = g5_pca_wfa_comparison_item_label(item), xaxs = "i", col.main = aesthetic$text)
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  folds <- item$folds
  if (is.data.frame(folds) && nrow(folds)) {
    for (j in seq_len(nrow(folds))) {
      boundary_idx <- match(as.Date(folds$oos_start_date[[j]]), session_dates)
      if (!is.na(boundary_idx)) graphics::abline(v = boundary_idx - 0.5, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.55), lty = 2)
    }
  }
  graphics::abline(h = 1, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.4), lty = 3)
  graphics::lines(x, curve$strategy_equity, col = aesthetic$trade_win_line, lwd = 1.8)
  graphics::lines(x, curve$buy_hold_equity, col = "#000000", lwd = 1)
  g5_pca_wfa_comparison_plot_date_axis(session_dates)
  metric <- if (is.data.frame(item$metrics) && nrow(item$metrics)) item$metrics[1L, , drop = FALSE] else data.frame()
  if (nrow(metric)) {
    label <- sprintf("ret %.1f%% | sharpe %.2f | dd %.1f%%", 100 * metric$total_return[[1L]], metric$sharpe[[1L]], 100 * metric$max_drawdown[[1L]])
    graphics::mtext(label, side = 3, line = -1.1, cex = 0.72, col = aesthetic$text)
  }
  invisible(NULL)
}

g5_pca_wfa_draw_comparison_strategy_panel <- function(item) {
  aesthetic <- g5_chart_aesthetic()
  scores <- item$scores
  if (!is.data.frame(scores) || !nrow(scores)) {
    graphics::plot.new()
    graphics::title(g5_pca_wfa_comparison_item_label(item))
    graphics::text(0.5, 0.5, "missing scores")
    return(invisible(NULL))
  }
  scores <- scores[order(as.Date(scores$session_date), scores$fold_no), , drop = FALSE]
  plot_rows <- scores[!is.na(scores$split) & scores$split == "OOS", , drop = FALSE]
  plot_rows <- plot_rows[!duplicated(paste(plot_rows$session_date, plot_rows$fold_id)), , drop = FALSE]
  plot_rows <- plot_rows[order(as.Date(plot_rows$session_date), plot_rows$fold_no), , drop = FALSE]
  session_dates <- as.Date(plot_rows$session_date)
  x <- seq_len(nrow(plot_rows))
  y <- range(c(plot_rows$low, plot_rows$high), finite = TRUE)
  padding <- diff(y) * 0.06
  if (!is.finite(padding) || padding <= 0) padding <- 1
  pal <- g5_pca_regime_state_palette(sort(unique(stats::na.omit(plot_rows$state_id))))
  graphics::plot(c(0.5, length(x) + 0.5), y + c(-padding, padding), type = "n", xaxt = "n", xlab = "", ylab = "", main = g5_pca_wfa_comparison_item_label(item), xaxs = "i", col.main = aesthetic$text)
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  if (nrow(plot_rows)) {
    run_key <- paste(plot_rows$fold_id, plot_rows$state_id, sep = "::")
    runs <- rle(run_key)
    run_ends <- cumsum(runs$lengths)
    run_starts <- run_ends - runs$lengths + 1L
    for (j in seq_along(runs$values)) {
      state <- plot_rows$state_id[[run_starts[[j]]]]
      if (!is.na(state) && state %in% names(pal)) {
        graphics::rect(run_starts[[j]] - 0.5, usr[[3L]], run_ends[[j]] + 0.5, usr[[4L]], col = grDevices::adjustcolor(pal[[state]], alpha.f = 0.14), border = NA)
      }
    }
  }
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  body_cols <- ifelse(plot_rows$close > plot_rows$open, aesthetic$up_candle, ifelse(plot_rows$close < plot_rows$open, aesthetic$down_candle, aesthetic$flat_candle))
  graphics::segments(x, plot_rows$low, x, plot_rows$high, col = body_cols, lwd = 0.75)
  graphics::segments(x, plot_rows$open, x, plot_rows$close, col = body_cols, lwd = 1.9)
  folds <- item$folds
  if (is.data.frame(folds) && nrow(folds)) {
    for (j in seq_len(nrow(folds))) {
      boundary_idx <- match(as.Date(folds$oos_start_date[[j]]), session_dates)
      if (!is.na(boundary_idx)) graphics::abline(v = boundary_idx - 0.5, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.65), lty = 2)
    }
  }
  trades <- item$trades
  if (is.data.frame(trades) && nrow(trades)) {
    line_cols <- ifelse(trades$trade_outcome == "win", aesthetic$trade_win_line, ifelse(trades$trade_outcome == "loss", aesthetic$trade_loss_line, aesthetic$flat_candle))
    graphics::segments(match(as.Date(trades$entry_execution_date), session_dates), trades$entry_execution_price, match(as.Date(trades$trace_end_date), session_dates), trades$trace_end_price, col = line_cols, lty = aesthetic$trade_line_lty, lwd = 0.95)
    graphics::points(match(as.Date(trades$entry_execution_date), session_dates), trades$entry_execution_price, pch = aesthetic$native_entry_pch, col = aesthetic$native_entry_color, bg = aesthetic$native_entry_color, cex = 0.65)
    closed <- trades[!is.na(trades$exit_execution_date), , drop = FALSE]
    if (nrow(closed)) {
      graphics::points(match(as.Date(closed$exit_execution_date), session_dates), closed$exit_execution_price, pch = aesthetic$native_exit_pch, col = aesthetic$native_exit_color, bg = aesthetic$native_exit_color, cex = 0.65)
    }
  }
  g5_pca_wfa_comparison_plot_date_axis(session_dates)
  invisible(NULL)
}

g5_pca_wfa_draw_comparison_scatter_panel <- function(item) {
  aesthetic <- g5_chart_aesthetic()
  scores <- item$scores
  plot_rows <- if (is.data.frame(scores) && nrow(scores)) scores[is.finite(scores$pc1) & is.finite(scores$pc2) & !is.na(scores$state_id), , drop = FALSE] else data.frame()
  if (!nrow(plot_rows)) {
    graphics::plot.new()
    graphics::title(g5_pca_wfa_comparison_item_label(item))
    graphics::text(0.5, 0.5, "missing PCA scores")
    return(invisible(NULL))
  }
  pal <- g5_pca_regime_state_palette(sort(unique(plot_rows$state_id)))
  alpha <- ifelse(plot_rows$split == "OOS", 0.92, 0.25)
  cols <- vapply(seq_len(nrow(plot_rows)), function(i) grDevices::adjustcolor(pal[[plot_rows$state_id[[i]]]], alpha.f = alpha[[i]]), character(1L))
  pch <- ifelse(plot_rows$split == "OOS", 21L, 23L)
  graphics::plot(plot_rows$pc1, plot_rows$pc2, type = "n", xlab = "", ylab = "", main = g5_pca_wfa_comparison_item_label(item), col.main = aesthetic$text)
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(col = aesthetic$grid)
  graphics::points(plot_rows$pc1, plot_rows$pc2, pch = pch, bg = cols, col = cols, cex = ifelse(plot_rows$split == "OOS", 0.72, 0.42))
  graphics::mtext("PC1", side = 1, line = 2.1, cex = 0.72, col = aesthetic$text)
  graphics::mtext("PC2", side = 2, line = 2.1, cex = 0.72, col = aesthetic$text)
  invisible(NULL)
}

g5_pca_wfa_write_comparison_contact_sheet <- function(items, path, chart_type = c("equity", "strategy", "pca_scatter"), title = NULL, width = 1800L, height = 1300L) {
  chart_type <- match.arg(chart_type)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  aesthetic <- g5_chart_aesthetic()
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = 130)
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mfrow = c(2L, 2L), mar = c(5.8, 4.1, 3.1, 1.4), oma = c(0, 0, 3.2, 0), bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  for (item in items) {
    if (identical(chart_type, "equity")) {
      g5_pca_wfa_draw_comparison_equity_panel(item)
    } else if (identical(chart_type, "strategy")) {
      g5_pca_wfa_draw_comparison_strategy_panel(item)
    } else {
      g5_pca_wfa_draw_comparison_scatter_panel(item)
    }
  }
  if (length(items) < 4L) {
    for (i in seq_len(4L - length(items))) graphics::plot.new()
  }
  default_title <- switch(
    chart_type,
    equity = "Gen5 PCA Router 2x2 Equity Contact Sheet",
    strategy = "Gen5 PCA Router 2x2 Stitched OOS Contact Sheet",
    pca_scatter = "Gen5 PCA Router 2x2 PCA State-Space Contact Sheet"
  )
  graphics::mtext(if (is.null(title)) default_title else title, side = 3, outer = TRUE, line = 1, col = aesthetic$text, font = 2)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_pca_wfa_comparison_markdown_report <- function(summary, family_counts, path_index, settings, path) {
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  num <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", as.numeric(x)))
  summary_table <- summary
  summary_table$total_return <- pct(summary_table$total_return)
  summary_table$max_drawdown <- pct(summary_table$max_drawdown)
  summary_table$buy_hold_total_return <- pct(summary_table$buy_hold_total_return)
  summary_table$sharpe <- num(summary_table$sharpe)
  summary_table$min_oos_state_fraction <- pct(summary_table$min_oos_state_fraction)
  summary_table$max_oos_state_fraction <- pct(summary_table$max_oos_state_fraction)
  artifact_table <- path_index[, c("panel_mode", "state_map", "state_count", "run_dir", "report_md"), drop = FALSE]
  lines <- c(
    "# Gen5 PCA Router Comparison Report",
    "",
    "POC only: this comparison summarizes already-generated PCA-routed WFA packets. It does not introduce portfolio allocation, live advice, execution, or state-adaptive exits.",
    "",
    "## Run Context",
    "",
    paste0("- Symbol: `", settings$symbol, "`"),
    paste0("- Regime Context Universe: `", paste(settings$regime_context_symbols, collapse = ", "), "`"),
    paste0("- Research Candidate Universe: `", settings$symbol, "`"),
    paste0("- Tradeable Universe: `", settings$symbol, "`"),
    paste0("- Active Allocation Set: `", settings$symbol, "`"),
    paste0("- Fold count: `", settings$fold_count, "`"),
    paste0("- End date: `", settings$end_date, "`"),
    paste0("- As-of timestamp: `", settings$as_of_timestamp, "`"),
    "- Ownership policy: `entry_state_owns_trade_until_exit`.",
    "",
    "## Comparison Summary",
    "",
    g5_pca_wfa_comparison_table_lines(
      summary_table,
      c("panel_mode", "state_map", "state_count", "run_status", "total_return", "sharpe", "max_drawdown", "trade_count", "buy_hold_total_return", "oos_covered_states", "oos_state_count", "selected_families")
    ),
    "",
    "## OOS State Coverage",
    "",
    g5_pca_wfa_comparison_table_lines(
      summary_table,
      c("panel_mode", "state_map", "state_count", "oos_total_state_rows", "oos_covered_states", "oos_state_count", "min_oos_state_fraction", "max_oos_state_fraction")
    ),
    "",
    "## Selected Family Counts",
    "",
    g5_pca_wfa_comparison_table_lines(
      family_counts,
      c("panel_mode", "state_map", "state_count", "strategy_family", "selected_state_count", "selected_fold_count")
    ),
    "",
    "## Contact Sheets",
    "",
    paste0("- Equity 2x2: `", settings$equity_contact_sheet_png, "`"),
    paste0("- Stitched OOS 2x2: `", settings$strategy_contact_sheet_png, "`"),
    paste0("- PCA scatter 2x2: `", settings$pca_scatter_contact_sheet_png, "`"),
    "",
    "## Child Artifacts",
    "",
    g5_pca_wfa_comparison_table_lines(artifact_table, names(artifact_table))
  )
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_write_pca_wfa_comparison_outputs <- function(run_index, output_dir, settings, prefix = "pcawfa_cmp") {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  summary <- g5_pca_wfa_comparison_summary(run_index)
  family_counts <- g5_pca_wfa_comparison_family_counts(run_index)
  path_index <- run_index
  artifact_paths <- lapply(path_index$run_dir, g5_pca_wfa_comparison_artifact_paths)
  path_index$report_md <- vapply(artifact_paths, function(x) x$report_md, character(1L))
  path_index$selected_states_csv <- vapply(artifact_paths, function(x) x$selected_states_csv, character(1L))
  path_index$state_coverage_csv <- vapply(artifact_paths, function(x) x$state_coverage_csv, character(1L))
  path_index$oos_metrics_csv <- vapply(artifact_paths, function(x) x$oos_metrics_csv, character(1L))
  path_index$pca_scatter_png <- vapply(artifact_paths, function(x) x$pca_scatter_png, character(1L))
  path_index$state_strategy_chart_png <- vapply(artifact_paths, function(x) x$state_strategy_chart_png, character(1L))
  path_index$equity_chart_png <- vapply(artifact_paths, function(x) x$equity_chart_png, character(1L))
  paths <- list(
    summary_csv = file.path(output_dir, paste0(prefix, "_summary.csv")),
    selected_family_counts_csv = file.path(output_dir, paste0(prefix, "_selected_family_counts.csv")),
    path_index_csv = file.path(output_dir, paste0(prefix, "_path_index.csv")),
    equity_contact_sheet_png = file.path(output_dir, paste0(prefix, "_equity_2x2.png")),
    strategy_contact_sheet_png = file.path(output_dir, paste0(prefix, "_stitched_oos_2x2.png")),
    pca_scatter_contact_sheet_png = file.path(output_dir, paste0(prefix, "_pca_scatter_2x2.png")),
    report_md = file.path(output_dir, paste0(prefix, "_report.md"))
  )
  items <- g5_pca_wfa_read_comparison_items(path_index)
  for (i in seq_along(items)) {
    if (!file.exists(path_index$pca_scatter_png[[i]]) && is.data.frame(items[[i]]$scores) && nrow(items[[i]]$scores)) {
      child_title <- paste0(items[[i]]$panel_mode, " / ", items[[i]]$state_map, " fold-local PCA scores")
      g5_pca_wfa_write_pca_scatter_from_scores(items[[i]]$scores, path_index$pca_scatter_png[[i]], title = child_title)
    }
  }
  paths$equity_contact_sheet_png <- g5_pca_wfa_write_comparison_contact_sheet(items, paths$equity_contact_sheet_png, chart_type = "equity")
  paths$strategy_contact_sheet_png <- g5_pca_wfa_write_comparison_contact_sheet(items, paths$strategy_contact_sheet_png, chart_type = "strategy")
  paths$pca_scatter_contact_sheet_png <- g5_pca_wfa_write_comparison_contact_sheet(items, paths$pca_scatter_contact_sheet_png, chart_type = "pca_scatter")
  settings$equity_contact_sheet_png <- paths$equity_contact_sheet_png
  settings$strategy_contact_sheet_png <- paths$strategy_contact_sheet_png
  settings$pca_scatter_contact_sheet_png <- paths$pca_scatter_contact_sheet_png
  utils::write.csv(summary, paths$summary_csv, row.names = FALSE)
  utils::write.csv(family_counts, paths$selected_family_counts_csv, row.names = FALSE)
  utils::write.csv(path_index, paths$path_index_csv, row.names = FALSE)
  paths$report_md <- g5_pca_wfa_comparison_markdown_report(summary, family_counts, path_index, settings, paths$report_md)
  list(paths = paths, summary = summary, selected_family_counts = family_counts, path_index = path_index)
}
