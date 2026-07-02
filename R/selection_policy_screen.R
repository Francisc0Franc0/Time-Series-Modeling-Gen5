g5_selection_policy_screen_schema_version <- function() {
  "gen5_selection_policy_screen_v0.1"
}

g5_selection_policy_metric_score <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x[is.na(x) | !is.finite(x)] <- -Inf
  x
}

g5_selection_policy_rank_rows <- function(rows) {
  if (!is.data.frame(rows) || !nrow(rows)) return(rows)
  sharpe <- g5_selection_policy_metric_score(rows$sharpe)
  total_return <- g5_selection_policy_metric_score(rows$total_return)
  trade_count <- if ("train_state_trade_count" %in% names(rows)) {
    suppressWarnings(as.numeric(rows$train_state_trade_count))
  } else if ("trade_count" %in% names(rows)) {
    suppressWarnings(as.numeric(rows$trade_count))
  } else {
    rep(0, nrow(rows))
  }
  trade_count[is.na(trade_count) | !is.finite(trade_count)] <- -Inf
  spec_id <- if ("strategy_spec_id" %in% names(rows)) as.character(rows$strategy_spec_id) else rep("", nrow(rows))
  rows[order(-sharpe, -total_return, -trade_count, spec_id), , drop = FALSE]
}

g5_selection_policy_no_trade_row <- function(rows) {
  no_trade <- rows[as.character(rows$strategy_family) == "no_trade", , drop = FALSE]
  if (!nrow(no_trade)) {
    g5_stop("Selection-policy screen expected a no_trade candidate row for every symbol/state.")
  }
  g5_selection_policy_rank_rows(no_trade)[1L, , drop = FALSE]
}

g5_selection_policy_state_row_count <- function(rows) {
  if (!"train_state_row_count" %in% names(rows) || !nrow(rows)) return(0L)
  value <- suppressWarnings(max(as.numeric(rows$train_state_row_count), na.rm = TRUE))
  if (!is.finite(value)) 0L else as.integer(value)
}

g5_selection_policy_best_asset_family_rows <- function(state_rows) {
  if (!is.data.frame(state_rows) || !nrow(state_rows)) return(data.frame())
  keys <- paste(as.character(state_rows$symbol), as.character(state_rows$strategy_family), sep = "::")
  pieces <- split(state_rows, keys)
  best <- lapply(pieces, function(piece) g5_selection_policy_rank_rows(piece)[1L, , drop = FALSE])
  g5_wfa_bind_rows_fill(best)
}

g5_selection_policy_choose_pooled_family <- function(state_rows, min_train_state_rows = 20L) {
  eligible <- state_rows[suppressWarnings(as.numeric(state_rows$train_state_row_count)) >= min_train_state_rows, , drop = FALSE]
  if (!nrow(eligible)) {
    return(data.frame(
      pooled_selected_family = "no_trade",
      pooled_family_mean_sharpe = 0,
      pooled_family_mean_total_return = 0,
      pooled_family_asset_count = 0L,
      pooled_family_trade_count = 0L,
      stringsAsFactors = FALSE
    ))
  }
  family_reps <- g5_selection_policy_best_asset_family_rows(eligible)
  families <- sort(unique(as.character(family_reps$strategy_family)))
  rows <- lapply(families, function(family) {
    x <- family_reps[as.character(family_reps$strategy_family) == family, , drop = FALSE]
    data.frame(
      pooled_selected_family = family,
      pooled_family_mean_sharpe = mean(g5_selection_policy_metric_score(x$sharpe)),
      pooled_family_mean_total_return = mean(g5_selection_policy_metric_score(x$total_return)),
      pooled_family_asset_count = length(unique(as.character(x$symbol))),
      pooled_family_trade_count = sum(suppressWarnings(as.numeric(x$train_state_trade_count)), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  summary <- g5_wfa_bind_rows_fill(rows)
  summary <- summary[order(
    -g5_selection_policy_metric_score(summary$pooled_family_mean_sharpe),
    -g5_selection_policy_metric_score(summary$pooled_family_mean_total_return),
    -suppressWarnings(as.numeric(summary$pooled_family_asset_count)),
    as.character(summary$pooled_selected_family)
  ), , drop = FALSE]
  summary[1L, , drop = FALSE]
}

g5_selection_policy_pooled_family_asset_variant <- function(train_state_performance, min_train_state_rows = 20L) {
  required <- c("symbol", "quarter_id", "state_id", "strategy_family", "strategy_spec_id", "sharpe", "total_return", "train_state_row_count")
  missing <- setdiff(required, names(train_state_performance))
  if (length(missing)) {
    g5_stop(paste0("train_state_performance is missing required columns: ", paste(missing, collapse = ", ")))
  }
  perf <- train_state_performance
  perf$selection_policy <- "pooled_family_asset_variant"
  quarters <- sort(unique(as.character(perf$quarter_id)))
  out <- list()
  for (quarter_id in quarters) {
    q_rows <- perf[as.character(perf$quarter_id) == quarter_id, , drop = FALSE]
    states <- sort(unique(as.character(q_rows$state_id)))
    symbols <- sort(unique(as.character(q_rows$symbol)))
    for (state_id in states) {
      state_rows <- q_rows[as.character(q_rows$state_id) == state_id, , drop = FALSE]
      family_pick <- g5_selection_policy_choose_pooled_family(state_rows, min_train_state_rows = min_train_state_rows)
      selected_family <- as.character(family_pick$pooled_selected_family[[1L]])
      for (symbol in symbols) {
        symbol_rows <- state_rows[as.character(state_rows$symbol) == symbol, , drop = FALSE]
        if (!nrow(symbol_rows)) next
        row_count <- g5_selection_policy_state_row_count(symbol_rows)
        if (is.na(row_count) || row_count < min_train_state_rows) {
          winner <- g5_selection_policy_no_trade_row(symbol_rows)
          winner$selection_reason <- paste0("pooled_policy_forced_no_trade_sparse_state_min_rows_", min_train_state_rows)
        } else {
          candidates <- symbol_rows[as.character(symbol_rows$strategy_family) == selected_family, , drop = FALSE]
          if (!nrow(candidates)) {
            winner <- g5_selection_policy_no_trade_row(symbol_rows)
            winner$selection_reason <- paste0("pooled_policy_no_asset_variant_for_family_", selected_family)
          } else {
            winner <- g5_selection_policy_rank_rows(candidates)[1L, , drop = FALSE]
            winner$selection_reason <- paste0("pooled_family_asset_variant_family_", selected_family, "_asset_params_ranked_by_sharpe_then_return")
          }
        }
        winner$selection_policy <- "pooled_family_asset_variant"
        winner$pooled_selected_family <- selected_family
        winner$pooled_family_mean_sharpe <- as.numeric(family_pick$pooled_family_mean_sharpe[[1L]])
        winner$pooled_family_mean_total_return <- as.numeric(family_pick$pooled_family_mean_total_return[[1L]])
        winner$pooled_family_asset_count <- as.integer(family_pick$pooled_family_asset_count[[1L]])
        winner$pooled_family_trade_count <- as.integer(family_pick$pooled_family_trade_count[[1L]])
        out[[length(out) + 1L]] <- winner
      }
    }
  }
  selected <- if (length(out)) g5_wfa_bind_rows_fill(out) else perf[0L, , drop = FALSE]
  rownames(selected) <- NULL
  selected
}

g5_selection_policy_add_direct_label <- function(selected_states) {
  selected_states$selection_policy <- "asset_state_direct_spec"
  selected_states$pooled_selected_family <- NA_character_
  selected_states$pooled_family_mean_sharpe <- NA_real_
  selected_states$pooled_family_mean_total_return <- NA_real_
  selected_states$pooled_family_asset_count <- NA_integer_
  selected_states$pooled_family_trade_count <- NA_integer_
  selected_states
}

g5_selection_policy_compare_selected_states <- function(direct_states, pooled_states) {
  keys <- c("quarter_id", "symbol", "state_id")
  direct_keep <- direct_states[, intersect(c(keys, "strategy_family", "strategy_spec_id", "model_instance_id", "exit_stack_id", "selection_reason"), names(direct_states)), drop = FALSE]
  pooled_keep <- pooled_states[, intersect(c(keys, "strategy_family", "strategy_spec_id", "model_instance_id", "exit_stack_id", "selection_reason", "pooled_selected_family"), names(pooled_states)), drop = FALSE]
  comparison <- merge(direct_keep, pooled_keep, by = keys, all = TRUE, suffixes = c("_direct", "_pooled"))
  comparison$family_match <- as.character(comparison$strategy_family_direct) == as.character(comparison$strategy_family_pooled)
  comparison$spec_match <- as.character(comparison$strategy_spec_id_direct) == as.character(comparison$strategy_spec_id_pooled)
  comparison$family_match[is.na(comparison$family_match)] <- FALSE
  comparison$spec_match[is.na(comparison$spec_match)] <- FALSE
  comparison
}

g5_selection_policy_trace_return <- function(trades) {
  if (!is.data.frame(trades) || !nrow(trades)) return(numeric())
  end_price <- suppressWarnings(as.numeric(trades$trace_end_price))
  entry_price <- suppressWarnings(as.numeric(trades$entry_execution_price))
  out <- end_price / entry_price - 1
  out[!is.finite(out)] <- NA_real_
  out
}

g5_selection_policy_summarize_daily <- function(daily, selection_policy, window_id) {
  symbols <- sort(unique(as.character(daily$book_summary$symbol)))
  rows <- lapply(symbols, function(symbol) {
    trades <- if (is.data.frame(daily$trades) && nrow(daily$trades)) daily$trades[as.character(daily$trades$symbol) == symbol, , drop = FALSE] else data.frame()
    returns <- g5_selection_policy_trace_return(trades)
    latest <- daily$book_summary[as.character(daily$book_summary$symbol) == symbol, , drop = FALSE]
    data.frame(
      schema_version = g5_selection_policy_screen_schema_version(),
      selection_policy = selection_policy,
      window_id = window_id,
      quarter_id = as.character(daily$contract$quarter_id[[1L]]),
      as_of_date = as.Date(daily$as_of_date),
      symbol = symbol,
      trade_count = if (is.data.frame(trades)) nrow(trades) else 0L,
      closed_trade_count = if (is.data.frame(trades) && nrow(trades)) sum(as.character(trades$trade_status) == "closed", na.rm = TRUE) else 0L,
      open_trade_count = if (is.data.frame(trades) && nrow(trades)) sum(as.character(trades$trade_status) == "open", na.rm = TRUE) else 0L,
      win_count = if (length(returns)) sum(returns > 0, na.rm = TRUE) else 0L,
      loss_count = if (length(returns)) sum(returns < 0, na.rm = TRUE) else 0L,
      compound_trace_return = if (length(stats::na.omit(returns))) prod(1 + stats::na.omit(returns)) - 1 else 0,
      mean_trace_return = if (length(stats::na.omit(returns))) mean(returns, na.rm = TRUE) else NA_real_,
      worst_trace_return = if (length(stats::na.omit(returns))) min(returns, na.rm = TRUE) else NA_real_,
      best_trace_return = if (length(stats::na.omit(returns))) max(returns, na.rm = TRUE) else NA_real_,
      current_model_position = if (nrow(latest)) as.character(latest$current_model_position[[1L]]) else NA_character_,
      latest_state_id = if (nrow(latest)) as.character(latest$state_id[[1L]]) else NA_character_,
      latest_selected_strategy_family = if (nrow(latest)) as.character(latest$selected_strategy_family[[1L]]) else NA_character_,
      latest_selected_strategy_spec_id = if (nrow(latest)) as.character(latest$selected_strategy_spec_id[[1L]]) else NA_character_,
      stringsAsFactors = FALSE
    )
  })
  g5_wfa_bind_rows_fill(rows)
}

g5_selection_policy_score_pooled_authority_symbol_fast <- function(bars, authority, symbol, as_of_date) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  contract <- authority$contract[1L, , drop = FALSE]
  panel_mode <- if ("pca_panel_mode" %in% names(contract)) as.character(contract$pca_panel_mode[[1L]]) else "pooled_asset_day"
  if (!identical(panel_mode, "pooled_asset_day")) {
    g5_stop("Fast selection-policy scoring is only valid for pooled_asset_day PCA authority packets.")
  }
  features <- g5_pca_regime_feature_table(bars, symbol, end_date = as.Date(as_of_date))
  features$pca_training_symbol <- symbol
  features$pca_training_role <- "routing_target_only"
  features$regime_context_symbols <- if ("context_symbols" %in% names(contract)) as.character(contract$context_symbols[[1L]]) else symbol
  features$research_candidate_symbol <- symbol
  features$pca_panel_mode <- "pooled_asset_day"
  g5_bridge_score_frozen_quantile(features, authority$pca_model_contract, symbol)
}

g5_selection_policy_run_daily_continuity_fast <- function(bars, current_authority, previous_authority, as_of_timestamp) {
  current_contract <- current_authority$contract[1L, , drop = FALSE]
  previous_contract <- previous_authority$contract[1L, , drop = FALSE]
  symbols <- g5_standardize_symbol(strsplit(current_contract$symbols[[1L]], ",", fixed = TRUE)[[1L]])
  previous_symbols <- g5_standardize_symbol(strsplit(previous_contract$symbols[[1L]], ",", fixed = TRUE)[[1L]])
  if (!identical(symbols, previous_symbols)) {
    g5_stop("Continuity replay requires previous and current bridge authorities to use the same live symbol set.")
  }
  current_live_start <- as.Date(current_contract$live_start_date[[1L]])
  current_as_of_date <- as.Date(max(as.Date(bars$session_date), na.rm = TRUE))
  previous_live_end <- as.Date(previous_contract$live_end_date[[1L]])
  if (previous_live_end + 1L < current_live_start) {
    g5_stop("Continuity replay expected adjacent previous/current authority windows.")
  }

  results <- list()
  continuity_rows <- list()
  for (symbol in symbols) {
    previous_scored <- g5_selection_policy_score_pooled_authority_symbol_fast(bars, previous_authority, symbol, current_as_of_date)
    previous_result <- g5_bridge_replay_symbol(
      bars,
      symbol,
      previous_scored,
      previous_authority$selected_states,
      previous_contract,
      allow_as_of_after_live_end = TRUE,
      replay_start_date = as.Date(previous_contract$train_end_date[[1L]]),
      entry_signal_start_date = as.Date(previous_contract$train_end_date[[1L]]),
      entry_signal_end_date = previous_live_end,
      honor_pending_entry_execution_until = current_live_start,
      authority_role = "previous_continuity"
    )

    current_start <- g5_bridge_first_flat_date_from_prior(previous_result$replay, current_live_start)
    if (is.na(current_start)) {
      chosen_replay <- previous_result$replay
      chosen_executions <- previous_result$executions
      chosen_pending <- previous_result$pending_actions
      chosen_scores <- previous_scored
      continuity_mode <- "previous_authority_open_trade_carry"
    } else {
      current_scored <- g5_selection_policy_score_pooled_authority_symbol_fast(bars, current_authority, symbol, current_as_of_date)
      current_result <- g5_bridge_replay_symbol(
        bars,
        symbol,
        current_scored,
        current_authority$selected_states,
        current_contract,
        replay_start_date = current_start,
        entry_signal_start_date = current_start,
        entry_signal_end_date = current_as_of_date,
        honor_pending_entry_execution_until = current_as_of_date,
        authority_role = "current"
      )
      prior_keep <- previous_result$replay[as.Date(previous_result$replay$session_date) < current_start, , drop = FALSE]
      prior_exec_keep <- if (is.data.frame(previous_result$executions) && nrow(previous_result$executions)) {
        previous_result$executions[as.Date(previous_result$executions$execution_date) < current_start, , drop = FALSE]
      } else {
        data.frame()
      }
      chosen_replay <- g5_wfa_bind_rows_fill(list(prior_keep, current_result$replay))
      chosen_executions <- g5_wfa_bind_rows_fill(list(prior_exec_keep, current_result$executions))
      chosen_pending <- current_result$pending_actions
      chosen_scores <- current_scored
      continuity_mode <- if (current_start > current_live_start) "previous_authority_until_flat_then_current" else "current_authority_from_quarter_start"
    }
    chosen_trades <- g5_bridge_trades_from_replay(chosen_replay, chosen_executions, as.Date(current_contract$live_end_date[[1L]]))
    latest <- if (nrow(chosen_replay)) chosen_replay[nrow(chosen_replay), , drop = FALSE] else data.frame()
    results[[symbol]] <- list(
      replay = chosen_replay,
      pending_actions = chosen_pending,
      executions = chosen_executions,
      trades = chosen_trades,
      latest = latest,
      scores = chosen_scores,
      previous_replay = previous_result$replay,
      continuity_mode = continuity_mode,
      current_authority_start_date = current_start
    )
    continuity_rows[[length(continuity_rows) + 1L]] <- data.frame(
      symbol = symbol,
      previous_quarter_id = as.character(previous_contract$quarter_id[[1L]]),
      current_quarter_id = as.character(current_contract$quarter_id[[1L]]),
      continuity_mode = continuity_mode,
      current_authority_start_date = current_start,
      stringsAsFactors = FALSE
    )
  }
  replay <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$replay))
  pending <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$pending_actions))
  executions <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$executions))
  trades <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$trades))
  latest <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$latest))
  book <- latest[, c("symbol", "session_date", "close", "state_id", "selected_strategy_family", "selected_strategy_spec_id", "selected_signal_params", "model_position_after_replay", "signal_status", "execution_status", "open_trade_strategy_spec_id", "open_trade_signal_params", "open_trade_entry_execution_date", "authority_quarter_id", "authority_role"), drop = FALSE]
  names(book)[names(book) == "session_date"] <- "as_of_date"
  names(book)[names(book) == "model_position_after_replay"] <- "current_model_position"
  list(
    contract = current_contract,
    previous_contract = previous_contract,
    as_of_timestamp = as_of_timestamp,
    as_of_date = current_as_of_date,
    continuity = g5_wfa_bind_rows_fill(continuity_rows),
    symbol_results = results,
    replay = replay,
    pending_actions = pending,
    executions = executions,
    trades = trades,
    operator_packet = latest,
    book_summary = book
  )
}
