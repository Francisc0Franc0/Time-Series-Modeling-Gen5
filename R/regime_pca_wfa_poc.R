# Gen5.1 PCA-routed WFA proof-of-concept helpers.

g5_pca_wfa_schema_version <- function() {
  "gen5_pca_wfa_router_poc_v0.1"
}

g5_pca_wfa_artifact_prefix <- function(as_of_timestamp, symbol, fold_count, grid_n, wfa_start_date, wfa_end_date, candidate_families) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  families <- sort(unique(as.character(candidate_families)))
  paste(
    c(
      "pcawfa",
      symbol,
      paste0(fold_count, "f"),
      paste0(grid_n, "x", grid_n),
      paste0(length(families), "fam"),
      gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_start_date))),
      gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date))),
      stamp
    ),
    collapse = "_"
  )
}

g5_pca_wfa_output_dir <- function(repo_root, as_of_timestamp, symbol, fold_count, grid_n, wfa_start_date, wfa_end_date, candidate_families) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "regime_wfa_pocs",
    g5_pca_wfa_artifact_prefix(as_of_timestamp, symbol, fold_count, grid_n, wfa_start_date, wfa_end_date, candidate_families)
  )
}

g5_pca_wfa_all_states <- function(grid_n) {
  as.vector(outer(seq_len(grid_n), seq_len(grid_n), function(x, y) paste0("S", x, "_", y)))
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
  states <- g5_pca_wfa_all_states(pca_result$grid_n)
  scores <- pca_result$scores
  state_lookup <- g5_pca_wfa_state_lookup(scores)
  coverage <- g5_pca_regime_state_coverage(scores, pca_result$grid_n)
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
  min_train_state_rows = 20L
) {
  candidate_families <- unique(c(g5_wfa_candidate_families(candidate_families), "no_trade"))
  folds <- g5_ema_cross_wfa_resolve_folds(
    bars,
    symbol = symbol,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    fold_count = 1L
  )
  fold <- folds[1L, , drop = FALSE]
  features <- g5_pca_regime_feature_table(bars, symbol, end_date = fold$oos_end_date[[1L]])
  pca <- g5_pca_regime_fit(
    features,
    train_start_date = fold$train_start_date[[1L]],
    train_end_date = fold$train_end_date[[1L]],
    oos_start_date = fold$oos_start_date[[1L]],
    oos_end_date = fold$oos_end_date[[1L]],
    grid_n = grid_n
  )
  model_grid <- g5_wfa_candidate_model_grid(
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    candidate_families = candidate_families
  )
  selection <- g5_pca_wfa_select_state_specs(
    bars,
    symbol = symbol,
    pca_result = pca,
    fold = fold,
    model_grid = model_grid,
    exit_stacks = g5_pca_wfa_native_only_exit_stack(),
    min_train_state_rows = min_train_state_rows
  )
  oos <- g5_pca_wfa_simulate_oos(bars, symbol, fold, pca, selection$selected_states)
  metrics <- g5_pca_wfa_route_metrics(oos$trades, oos$equity_curve, symbol)
  list(
    folds = folds,
    pca = pca,
    model_grid = model_grid,
    selected_states = selection$selected_states,
    train_state_performance = selection$train_state_performance,
    state_coverage = selection$state_coverage,
    oos_trades = oos$trades,
    oos_equity_curve = oos$equity_curve,
    oos_metrics = metrics,
    settings = list(
      ownership_policy = "entry_state_owns_trade_until_exit",
      candidate_families = candidate_families,
      grid_n = grid_n,
      min_train_state_rows = min_train_state_rows
    )
  )
}

g5_pca_wfa_write_state_price_chart_png <- function(pca_wfa, symbol, path, width = 1500L, height = 850L) {
  scores <- pca_wfa$pca$scores
  fold <- pca_wfa$folds[1L, , drop = FALSE]
  trades <- pca_wfa$oos_trades
  scores <- scores[order(as.Date(scores$session_date)), , drop = FALSE]
  aesthetic <- g5_chart_aesthetic()
  pal <- g5_pca_regime_state_palette(sort(unique(stats::na.omit(scores$state_id))))
  keep <- as.Date(scores$session_date) >= as.Date(fold$train_end_date[[1L]]) & as.Date(scores$session_date) <= as.Date(fold$oos_end_date[[1L]])
  plot_rows <- scores[keep, , drop = FALSE]
  x <- seq_len(nrow(plot_rows))
  y <- range(c(plot_rows$low, plot_rows$high), finite = TRUE)
  padding <- diff(y) * 0.06
  y_limits <- y + c(-padding, padding)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(9.6, 5.4, 4.2, 10), bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  graphics::plot(c(0.5, length(x) + 0.5), y_limits, type = "n", xaxt = "n", xlab = "", ylab = "Adjusted daily price", main = paste(g5_standardize_symbol(symbol)[[1L]], "PCA-Routed WFA OOS"), xaxs = "i")
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  runs <- g5_pca_regime_state_runs_for_plot(plot_rows)
  if (nrow(runs)) {
    for (i in seq_len(nrow(runs))) {
      state <- runs$state_id[[i]]
      if (!is.na(state) && state %in% names(pal)) {
        graphics::rect(runs$xleft[[i]], usr[[3L]], runs$xright[[i]], usr[[4L]], col = grDevices::adjustcolor(pal[[state]], alpha.f = 0.16), border = NA)
      }
    }
  }
  boundary_idx <- match(as.Date(fold$oos_start_date[[1L]]), as.Date(plot_rows$session_date))
  if (!is.na(boundary_idx)) {
    graphics::abline(v = boundary_idx - 0.5, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.8), lty = 2, lwd = 1.3)
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
  graphics::mtext("Colored bands: PCA states | dashed line: TRAIN/OOS boundary | policy: entry-state owns trade until exit", side = 3, line = 0.3, cex = 0.75, col = aesthetic$text)
  graphics::par(xpd = NA)
  graphics::legend("right", inset = c(-0.19, 0), legend = names(pal), fill = grDevices::adjustcolor(pal, alpha.f = 0.55), border = NA, bty = "n", cex = 0.75, text.col = aesthetic$text, title = "state")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_pca_wfa_write_equity_png <- function(equity_curve, path, symbol, width = 1500L, height = 760L) {
  aesthetic <- g5_chart_aesthetic()
  x <- seq_len(nrow(equity_curve))
  y <- range(c(equity_curve$strategy_equity, equity_curve$buy_hold_equity), finite = TRUE)
  padding <- diff(y) * 0.08
  y_limits <- y + c(-padding, padding)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(9.2, 5.4, 4.2, 2), bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  graphics::plot(c(0.5, length(x) + 0.5), y_limits, type = "n", xaxt = "n", xlab = "", ylab = "Equity, starting at 1.0", main = paste(g5_standardize_symbol(symbol)[[1L]], "PCA-Routed WFA OOS Equity"), xaxs = "i")
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  graphics::abline(h = 1, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.45), lty = 3)
  graphics::lines(x, equity_curve$strategy_equity, col = aesthetic$trade_win_line, lwd = 2.1)
  graphics::lines(x, equity_curve$buy_hold_equity, col = "#000000", lwd = 1.2)
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(8L, length(x)))))
  g5_axis_date_labels_45(tick_positions, as.character(as.Date(equity_curve$session_date)[tick_positions]), line_offset = 0.08, color = aesthetic$axis)
  graphics::mtext("Session date", side = 1, line = 7.4, cex = 1.05, col = aesthetic$text)
  graphics::legend("topleft", legend = c("PCA-routed strategy", "buy and hold"), col = c(aesthetic$trade_win_line, "#000000"), lty = 1, lwd = c(2.1, 1.2), bty = "n", text.col = aesthetic$text)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_pca_wfa_markdown_report <- function(pca_wfa, paths, symbol, as_of_timestamp, path) {
  metric <- pca_wfa$oos_metrics[1L, , drop = FALSE]
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  selected <- pca_wfa$selected_states
  selected_lines <- apply(
    selected[, c("state_id", "strategy_family", "strategy_spec_id", "train_state_row_count", "train_state_trade_count", "sharpe", "total_return", "selection_reason"), drop = FALSE],
    1,
    function(x) paste0("| ", paste(x, collapse = " | "), " |")
  )
  lines <- c(
    paste0("# PCA-Routed WFA POC: ", g5_standardize_symbol(symbol)[[1L]]),
    "",
    "Diagnostic POC only: PCA states route one-fold OOS strategy specs, but this is not production WFA evidence or live advice.",
    "",
    "## Policy",
    "",
    "- Regime method: PCA 3x3 quantile grid fit on TRAIN only.",
    "- Ownership policy: `entry_state_owns_trade_until_exit`.",
    "- OOS behavior: current state can select entries only while flat; open trades remain managed by the entry-state spec.",
    "- Sparse TRAIN states route to `no_trade`.",
    paste0("- As-of timestamp: `", as.character(as_of_timestamp), "`"),
    "",
    "## Fold",
    "",
    paste0("- TRAIN: `", pca_wfa$folds$train_start_date[[1L]], " to ", pca_wfa$folds$train_end_date[[1L]], "`"),
    paste0("- OOS: `", pca_wfa$folds$oos_start_date[[1L]], " to ", pca_wfa$folds$oos_end_date[[1L]], "`"),
    "",
    "## OOS Metrics",
    "",
    paste0("- Total return: `", pct(metric$total_return[[1L]]), "`"),
    paste0("- Sharpe: `", ifelse(is.na(metric$sharpe[[1L]]), "NA", sprintf("%.3f", metric$sharpe[[1L]])), "`"),
    paste0("- Max drawdown: `", pct(metric$max_drawdown[[1L]]), "`"),
    paste0("- Trades: `", metric$trade_count[[1L]], "`"),
    paste0("- Buy-and-hold return: `", pct(metric$buy_hold_total_return[[1L]]), "`"),
    "",
    "## Selected Spec By PCA State",
    "",
    "| state_id | family | strategy_spec_id | train_state_rows | train_state_trades | train_sharpe | train_return | selection_reason |",
    "|---|---|---|---:|---:|---:|---:|---|",
    selected_lines,
    "",
    "## Artifacts",
    "",
    paste0("- Selected states: `", paths$selected_states_csv, "`"),
    paste0("- Train state performance: `", paths$train_state_performance_csv, "`"),
    paste0("- OOS trades: `", paths$oos_trades_csv, "`"),
    paste0("- OOS equity: `", paths$oos_equity_csv, "`"),
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
    state_strategy_chart_png = file.path(output_dir, paste0(prefix, "_state_strategy_chart.png")),
    equity_chart_png = file.path(output_dir, paste0(prefix, "_equity_curve.png")),
    report_md = file.path(output_dir, paste0(prefix, "_report.md"))
  )
  g5_wfa_write_csv(pca_wfa$folds, paths$fold_spec_csv)
  g5_wfa_write_csv(pca_wfa$selected_states, paths$selected_states_csv)
  g5_wfa_write_csv(pca_wfa$train_state_performance, paths$train_state_performance_csv)
  g5_wfa_write_csv(pca_wfa$state_coverage, paths$state_coverage_csv)
  g5_wfa_write_csv(pca_wfa$pca$scores, paths$pca_scores_csv)
  g5_wfa_write_csv(pca_wfa$pca$model_contract, paths$pca_model_contract_csv)
  g5_wfa_write_csv(pca_wfa$oos_trades, paths$oos_trades_csv)
  g5_wfa_write_csv(pca_wfa$oos_equity_curve, paths$oos_equity_csv)
  g5_wfa_write_csv(pca_wfa$oos_metrics, paths$oos_metrics_csv)
  paths$state_strategy_chart_png <- g5_pca_wfa_write_state_price_chart_png(pca_wfa, symbol, paths$state_strategy_chart_png)
  paths$equity_chart_png <- g5_pca_wfa_write_equity_png(pca_wfa$oos_equity_curve, paths$equity_chart_png, symbol)
  paths$report_md <- g5_pca_wfa_markdown_report(pca_wfa, paths, symbol, as_of_timestamp, paths$report_md)
  list(paths = paths, result = pca_wfa)
}
