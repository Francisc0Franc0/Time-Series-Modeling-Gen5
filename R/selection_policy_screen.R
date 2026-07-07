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

g5_selection_policy_trade_count <- function(rows) {
  if ("train_state_trade_count" %in% names(rows)) {
    out <- suppressWarnings(as.numeric(rows$train_state_trade_count))
  } else if ("trade_count" %in% names(rows)) {
    out <- suppressWarnings(as.numeric(rows$trade_count))
  } else {
    out <- rep(0, nrow(rows))
  }
  out[is.na(out) | !is.finite(out)] <- 0
  out
}

g5_selection_policy_gen4_no_trade_families <- function() {
  c("no_trade", "no_trade_exit_immediate")
}

g5_selection_policy_gen4_winner_score <- function(metric, family) {
  metric <- suppressWarnings(as.numeric(metric))
  family <- as.character(family)
  no_trade_family <- family %in% g5_selection_policy_gen4_no_trade_families()
  ifelse(is.na(metric) & no_trade_family, 0, ifelse(is.na(metric) | !is.finite(metric), -Inf, metric))
}

g5_selection_policy_gen4_eligible_rows <- function(rows, min_train_state_rows = 20L, min_train_trades = 5L) {
  if (!is.data.frame(rows) || !nrow(rows)) return(rows)
  row_count <- suppressWarnings(as.numeric(rows$train_state_row_count))
  row_count[is.na(row_count) | !is.finite(row_count)] <- 0
  trade_count <- g5_selection_policy_trade_count(rows)
  family <- as.character(rows$strategy_family)
  rows[row_count >= min_train_state_rows & (trade_count >= min_train_trades | family %in% g5_selection_policy_gen4_no_trade_families()), , drop = FALSE]
}

g5_selection_policy_gen4_rank_rows <- function(rows) {
  if (!is.data.frame(rows) || !nrow(rows)) return(rows)
  score <- g5_selection_policy_gen4_winner_score(rows$sharpe, rows$strategy_family)
  total_return <- g5_selection_policy_metric_score(rows$total_return)
  spec_id <- if ("strategy_spec_id" %in% names(rows)) as.character(rows$strategy_spec_id) else rep("", nrow(rows))
  rows[order(-score, -total_return, spec_id), , drop = FALSE]
}

g5_selection_policy_choose_gen4_pooled_family <- function(state_rows, min_train_state_rows = 20L, min_train_trades = 5L) {
  eligible <- g5_selection_policy_gen4_eligible_rows(state_rows, min_train_state_rows = min_train_state_rows, min_train_trades = min_train_trades)
  if (!nrow(eligible)) {
    return(data.frame(
      pooled_selected_family = "no_trade",
      pooled_family_mean_sharpe = 0,
      pooled_family_mean_total_return = 0,
      pooled_family_asset_count = 0L,
      pooled_family_trade_count = 0L,
      pooled_family_n_variants = 0L,
      stringsAsFactors = FALSE
    ))
  }
  eligible$gen4_score_metric <- g5_selection_policy_gen4_winner_score(eligible$sharpe, eligible$strategy_family)
  families <- sort(unique(as.character(eligible$strategy_family)))
  rows <- lapply(families, function(family) {
    x <- eligible[as.character(eligible$strategy_family) == family, , drop = FALSE]
    variant_id <- if ("strategy_spec_id" %in% names(x)) as.character(x$strategy_spec_id) else as.character(x$model_instance_id)
    data.frame(
      pooled_selected_family = family,
      pooled_family_mean_sharpe = mean(as.numeric(x$gen4_score_metric), na.rm = TRUE),
      pooled_family_mean_total_return = mean(g5_selection_policy_metric_score(x$total_return), na.rm = TRUE),
      pooled_family_asset_count = length(unique(as.character(x$symbol))),
      pooled_family_trade_count = sum(g5_selection_policy_trade_count(x), na.rm = TRUE),
      pooled_family_n_variants = length(unique(variant_id)),
      stringsAsFactors = FALSE
    )
  })
  summary <- g5_wfa_bind_rows_fill(rows)
  summary <- summary[order(
    -g5_selection_policy_metric_score(summary$pooled_family_mean_sharpe),
    -g5_selection_policy_metric_score(summary$pooled_family_mean_total_return),
    -suppressWarnings(as.numeric(summary$pooled_family_n_variants)),
    as.character(summary$pooled_selected_family)
  ), , drop = FALSE]
  summary[1L, , drop = FALSE]
}

g5_selection_policy_gen4_state_exit_override_fields <- function(winner) {
  force_exit <- is.data.frame(winner) && nrow(winner) && g5_wfa_is_force_exit_override(winner)
  data.frame(
    state_exit_override = force_exit,
    state_exit_override_action = if (force_exit) "force_exit_next_open" else NA_character_,
    state_exit_override_reason = if (force_exit) "gen4_no_trade_exit_immediate" else NA_character_,
    stringsAsFactors = FALSE
  )
}

g5_selection_policy_gen4_pooled_family_asset_variant <- function(train_state_performance, min_train_state_rows = 20L, min_train_trades = 5L) {
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
      family_pick <- g5_selection_policy_choose_gen4_pooled_family(state_rows, min_train_state_rows = min_train_state_rows, min_train_trades = min_train_trades)
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
          candidates <- g5_selection_policy_gen4_eligible_rows(candidates, min_train_state_rows = min_train_state_rows, min_train_trades = min_train_trades)
          if (!nrow(candidates)) {
            winner <- g5_selection_policy_no_trade_row(symbol_rows)
            winner$selection_reason <- paste0("pooled_policy_no_asset_variant_for_family_", selected_family)
          } else {
            winner <- g5_selection_policy_gen4_rank_rows(candidates)[1L, , drop = FALSE]
            winner$selection_reason <- paste0("gen4_pooled_family_asset_variant_family_", selected_family, "_asset_params_ranked_by_score_then_return")
          }
        }
        winner$selection_policy <- "pooled_family_asset_variant"
        winner$selection_policy_recipe <- "gen4_phase40_pooled_family_asset_variant"
        winner$pooled_selected_family <- selected_family
        winner$pooled_family_mean_sharpe <- as.numeric(family_pick$pooled_family_mean_sharpe[[1L]])
        winner$pooled_family_mean_total_return <- as.numeric(family_pick$pooled_family_mean_total_return[[1L]])
        winner$pooled_family_asset_count <- as.integer(family_pick$pooled_family_asset_count[[1L]])
        winner$pooled_family_trade_count <- as.integer(family_pick$pooled_family_trade_count[[1L]])
        winner$pooled_family_n_variants <- as.integer(family_pick$pooled_family_n_variants[[1L]])
        winner <- cbind(winner, g5_selection_policy_gen4_state_exit_override_fields(winner))
        out[[length(out) + 1L]] <- winner
      }
    }
  }
  selected <- if (length(out)) g5_wfa_bind_rows_fill(out) else perf[0L, , drop = FALSE]
  rownames(selected) <- NULL
  selected
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
  g5_selection_policy_gen4_pooled_family_asset_variant(
    train_state_performance,
    min_train_state_rows = min_train_state_rows,
    min_train_trades = 5L
  )
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

g5_selection_policy_visual_safe_read_csv <- function(path, required = TRUE) {
  if (!file.exists(path)) {
    if (isTRUE(required)) g5_stop(paste0("Missing required selection-policy visual input: ", path))
    return(data.frame())
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

g5_selection_policy_visual_paths <- function(output_dir) {
  list(
    visual_index_csv = file.path(output_dir, "selection_policy_visual_index.csv"),
    metric_dashboard_png = file.path(output_dir, "selection_policy_metric_delta_dashboard.png"),
    return_heatmap_png = file.path(output_dir, "selection_policy_symbol_return_delta_heatmap.png"),
    return_scatter_png = file.path(output_dir, "selection_policy_return_scatter.png"),
    churn_map_png = file.path(output_dir, "selection_policy_state_churn_map.png"),
    equity_proxy_png = file.path(output_dir, "selection_policy_equity_proxy_overlay.png"),
    report_md = file.path(output_dir, "selection_policy_visual_summary_report.md")
  )
}

g5_selection_policy_metric_label <- function(x, digits = 1, pct = FALSE) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", if (isTRUE(pct)) sprintf(paste0("%.", digits, "f%%"), x * 100) else sprintf(paste0("%.", digits, "f"), x))
}

g5_selection_policy_window_label <- function(window_id, multiline = FALSE) {
  x <- as.character(window_id)
  out <- sub("_asof_", if (isTRUE(multiline)) "\n" else " ", x, fixed = TRUE)
  out <- sub("([0-9]{4})([0-9]{2})([0-9]{2})$", "\\1-\\2-\\3", out)
  out
}

g5_selection_policy_trade_return_sharpe_proxy <- function(returns) {
  returns <- suppressWarnings(as.numeric(returns))
  returns <- returns[is.finite(returns)]
  if (length(returns) < 2L || stats::sd(returns) == 0) return(NA_real_)
  mean(returns) / stats::sd(returns) * sqrt(length(returns))
}

g5_selection_policy_prepare_metric_summary <- function(trade_summary, trade_ledger = data.frame()) {
  if (!is.data.frame(trade_summary) || !nrow(trade_summary)) {
    g5_stop("selection_policy_trade_summary.csv must contain rows for visual summary.")
  }
  grouped <- split(trade_summary, paste(trade_summary$window_id, trade_summary$selection_policy, sep = "::"))
  rows <- lapply(grouped, function(x) {
    returns <- suppressWarnings(as.numeric(x$compound_trace_return))
    trade_returns <- numeric()
    if (is.data.frame(trade_ledger) && nrow(trade_ledger)) {
      y <- trade_ledger[
        as.character(trade_ledger$window_id) == as.character(x$window_id[[1L]]) &
          as.character(trade_ledger$selection_policy) == as.character(x$selection_policy[[1L]]),
        ,
        drop = FALSE
      ]
      trade_returns <- g5_selection_policy_trace_return(y)
    }
    data.frame(
      window_id = as.character(x$window_id[[1L]]),
      selection_policy = as.character(x$selection_policy[[1L]]),
      symbol_count = length(unique(as.character(x$symbol))),
      equal_symbol_mean_compound_trace_return = mean(returns, na.rm = TRUE),
      worst_symbol_compound_trace_return = min(returns, na.rm = TRUE),
      best_symbol_compound_trace_return = max(returns, na.rm = TRUE),
      trade_count = sum(suppressWarnings(as.numeric(x$trade_count)), na.rm = TRUE),
      open_trade_count = sum(suppressWarnings(as.numeric(x$open_trade_count)), na.rm = TRUE),
      closed_trade_count = sum(suppressWarnings(as.numeric(x$closed_trade_count)), na.rm = TRUE),
      win_count = sum(suppressWarnings(as.numeric(x$win_count)), na.rm = TRUE),
      loss_count = sum(suppressWarnings(as.numeric(x$loss_count)), na.rm = TRUE),
      win_rate = {
        wins <- sum(suppressWarnings(as.numeric(x$win_count)), na.rm = TRUE)
        losses <- sum(suppressWarnings(as.numeric(x$loss_count)), na.rm = TRUE)
        if ((wins + losses) > 0) wins / (wins + losses) else NA_real_
      },
      trade_return_sharpe_proxy = g5_selection_policy_trade_return_sharpe_proxy(trade_returns),
      stringsAsFactors = FALSE
    )
  })
  out <- g5_wfa_bind_rows_fill(rows)
  rownames(out) <- NULL
  out
}

g5_selection_policy_prepare_symbol_delta <- function(trade_summary) {
  direct <- trade_summary[as.character(trade_summary$selection_policy) == "asset_state_direct_spec", , drop = FALSE]
  pooled <- trade_summary[as.character(trade_summary$selection_policy) == "pooled_family_asset_variant", , drop = FALSE]
  keys <- c("window_id", "symbol")
  merged <- merge(
    direct[, c(keys, "compound_trace_return", "trade_count", "win_count", "loss_count", "current_model_position", "latest_selected_strategy_family"), drop = FALSE],
    pooled[, c(keys, "compound_trace_return", "trade_count", "win_count", "loss_count", "current_model_position", "latest_selected_strategy_family"), drop = FALSE],
    by = keys,
    all = TRUE,
    suffixes = c("_direct", "_pooled")
  )
  merged$return_delta_pooled_minus_direct <- suppressWarnings(as.numeric(merged$compound_trace_return_pooled)) - suppressWarnings(as.numeric(merged$compound_trace_return_direct))
  merged$trade_count_delta_pooled_minus_direct <- suppressWarnings(as.numeric(merged$trade_count_pooled)) - suppressWarnings(as.numeric(merged$trade_count_direct))
  merged$position_match <- as.character(merged$current_model_position_direct) == as.character(merged$current_model_position_pooled)
  merged$latest_family_match <- as.character(merged$latest_selected_strategy_family_direct) == as.character(merged$latest_selected_strategy_family_pooled)
  merged
}

g5_selection_policy_order_states <- function(states) {
  states <- unique(as.character(states))
  parsed <- do.call(rbind, lapply(states, function(state) {
    parts <- regmatches(state, regexec("^S([0-9]+)_([0-9]+)$", state))[[1L]]
    if (length(parts) == 3L) {
      c(state = state, pc1 = as.integer(parts[[2L]]), pc2 = as.integer(parts[[3L]]))
    } else {
      c(state = state, pc1 = Inf, pc2 = Inf)
    }
  }))
  parsed <- as.data.frame(parsed, stringsAsFactors = FALSE)
  parsed$pc1 <- suppressWarnings(as.numeric(parsed$pc1))
  parsed$pc2 <- suppressWarnings(as.numeric(parsed$pc2))
  parsed$state[order(parsed$pc1, parsed$pc2, parsed$state)]
}

g5_selection_policy_write_metric_dashboard <- function(metric_summary, path, width = 2400L, height = 1500L, res = 180L) {
  aesthetic <- g5_chart_aesthetic()
  grDevices::png(path, width = width, height = height, res = res)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(2, 3), mar = c(6, 4, 3, 1), oma = c(0, 0, 3, 0))
  metrics <- list(
    list(col = "equal_symbol_mean_compound_trace_return", title = "Mean Symbol Trace Return", pct = TRUE),
    list(col = "win_rate", title = "Win Rate", pct = TRUE),
    list(col = "trade_return_sharpe_proxy", title = "Trade-Return Sharpe Proxy", pct = FALSE),
    list(col = "trade_count", title = "Trade Count", pct = FALSE),
    list(col = "open_trade_count", title = "Open Trade Count", pct = FALSE),
    list(col = "worst_symbol_compound_trace_return", title = "Worst Symbol Trace Return", pct = TRUE)
  )
  windows <- unique(as.character(metric_summary$window_id))
  colors <- c(asset_state_direct_spec = "#2E86AB", pooled_family_asset_variant = "#9B5DE5")
  for (metric in metrics) {
    values <- matrix(NA_real_, nrow = length(colors), ncol = length(windows), dimnames = list(names(colors), windows))
    for (i in seq_len(nrow(metric_summary))) {
      row <- match(as.character(metric_summary$selection_policy[[i]]), rownames(values))
      col <- match(as.character(metric_summary$window_id[[i]]), colnames(values))
      if (!is.na(row) && !is.na(col)) values[row, col] <- as.numeric(metric_summary[[metric$col]][[i]])
    }
    plot_values <- values
    if (isTRUE(metric$pct)) plot_values <- plot_values * 100
    ylim <- range(c(plot_values, 0), na.rm = TRUE)
    if (!all(is.finite(ylim)) || diff(ylim) == 0) ylim <- ylim + c(-1, 1)
    colnames(plot_values) <- g5_selection_policy_window_label(colnames(plot_values), multiline = TRUE)
    bars <- graphics::barplot(plot_values, beside = TRUE, col = colors, border = NA, ylim = ylim * c(ifelse(ylim[[1L]] < 0, 1.15, 0), 1.15), las = 1, cex.names = 0.72, main = metric$title, ylab = if (isTRUE(metric$pct)) "Percent" else "Value", col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
    graphics::abline(h = 0, col = aesthetic$axis, lwd = 0.8)
    graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
    graphics::legend("topleft", legend = c("Direct", "Pooled family"), fill = colors, bty = "n", cex = 0.75)
    for (r in seq_len(nrow(plot_values))) {
      for (c in seq_len(ncol(plot_values))) {
        value <- plot_values[r, c]
        if (!is.finite(value)) next
        graphics::text(bars[r, c], value, labels = if (isTRUE(metric$pct)) sprintf("%.1f", value) else sprintf("%.2f", value), pos = if (value >= 0) 3 else 1, cex = 0.58, col = aesthetic$text)
      }
    }
  }
  graphics::mtext("Selection Policy Metric Dashboard", side = 3, outer = TRUE, line = 1, font = 2, col = aesthetic$text)
  invisible(path)
}

g5_selection_policy_delta_color <- function(values, positive = "#00A88F", negative = "#F15A5A", neutral = "#FFFDF8") {
  values <- suppressWarnings(as.numeric(values))
  max_abs <- max(abs(values), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  vapply(values, function(value) {
    if (!is.finite(value) || value == 0) return(neutral)
    target <- if (value > 0) positive else negative
    grDevices::adjustcolor(target, alpha.f = min(0.95, 0.22 + 0.73 * abs(value) / max_abs))
  }, character(1L))
}

g5_selection_policy_write_return_heatmap <- function(symbol_delta, path, width = 1800L, height = 1100L, res = 180L) {
  aesthetic <- g5_chart_aesthetic()
  symbols <- sort(unique(as.character(symbol_delta$symbol)))
  windows <- unique(as.character(symbol_delta$window_id))
  values <- matrix(NA_real_, nrow = length(symbols), ncol = length(windows), dimnames = list(symbols, windows))
  for (i in seq_len(nrow(symbol_delta))) {
    values[as.character(symbol_delta$symbol[[i]]), as.character(symbol_delta$window_id[[i]])] <- as.numeric(symbol_delta$return_delta_pooled_minus_direct[[i]])
  }
  grDevices::png(path, width = width, height = height, res = res)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(7, 7, 4, 2))
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Pooled Minus Direct: Symbol Trace Return Delta", col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  cols <- g5_selection_policy_delta_color(as.vector(values))
  dim(cols) <- dim(values)
  for (r in seq_len(nrow(values))) {
    for (c in seq_len(ncol(values))) {
      graphics::rect(c - 0.5, nrow(values) - r + 0.5, c + 0.5, nrow(values) - r + 1.5, col = cols[r, c], border = aesthetic$grid)
      graphics::text(c, nrow(values) - r + 1, labels = g5_selection_policy_metric_label(values[r, c], digits = 1, pct = TRUE), cex = 0.85, col = aesthetic$text)
    }
  }
  graphics::axis(1, at = seq_along(windows), labels = g5_selection_policy_window_label(windows, multiline = TRUE), las = 1, cex.axis = 0.75, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(symbols)), labels = symbols, las = 1, cex.axis = 0.85, col.axis = aesthetic$axis)
  graphics::mtext("Green favors pooled-family; red favors direct. Trace-return proxy only.", side = 1, line = 5.2, cex = 0.72, col = aesthetic$text)
  invisible(path)
}

g5_selection_policy_write_return_scatter <- function(symbol_delta, path, width = 1800L, height = 1200L, res = 180L) {
  aesthetic <- g5_chart_aesthetic()
  x <- suppressWarnings(as.numeric(symbol_delta$compound_trace_return_direct))
  y <- suppressWarnings(as.numeric(symbol_delta$compound_trace_return_pooled))
  lim <- range(c(x, y, 0), na.rm = TRUE)
  pad <- diff(lim) * 0.08
  if (!is.finite(pad) || pad == 0) pad <- 0.05
  lim <- lim + c(-pad, pad)
  windows <- unique(as.character(symbol_delta$window_id))
  pch <- stats::setNames(c(21L, 24L, 22L, 25L)[seq_along(windows)], windows)
  fill <- stats::setNames(c("#2E86AB", "#9B5DE5", "#00A88F", "#FF9F1C")[seq_along(windows)], windows)
  grDevices::png(path, width = width, height = height, res = res)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(5, 5, 4, 2))
  graphics::plot(x, y, type = "n", xlim = lim, ylim = lim, xlab = "Direct compound trace return", ylab = "Pooled-family compound trace return", main = "Direct vs Pooled-Family Symbol Outcomes", col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(lim[[1L]], lim[[1L]], lim[[2L]], lim[[2L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(col = aesthetic$grid)
  graphics::abline(0, 1, col = aesthetic$axis, lty = 2)
  for (i in seq_len(nrow(symbol_delta))) {
    window <- as.character(symbol_delta$window_id[[i]])
    graphics::points(x[[i]], y[[i]], pch = pch[[window]], bg = fill[[window]], col = aesthetic$axis, cex = 1.4)
    graphics::text(x[[i]], y[[i]], labels = as.character(symbol_delta$symbol[[i]]), pos = 3, cex = 0.62, col = aesthetic$text)
  }
  graphics::legend("topleft", legend = windows, pt.bg = fill[windows], pch = pch[windows], bty = "n", cex = 0.8)
  invisible(path)
}

g5_selection_policy_write_churn_map <- function(selected_comparison, path, width = 2400L, height = 1500L, res = 180L) {
  aesthetic <- g5_chart_aesthetic()
  quarters <- unique(as.character(selected_comparison$quarter_id))
  symbols <- sort(unique(as.character(selected_comparison$symbol)))
  states <- g5_selection_policy_order_states(selected_comparison$state_id)
  status_color <- c(same_spec = "#00A88F", same_family = "#F6C85F", different_family = "#F15A5A", missing = "#6E6878")
  panel_height <- 360L
  dynamic_height <- max(height, as.integer(length(quarters) * panel_height + 360L))
  grDevices::png(path, width = width, height = dynamic_height, res = res)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(length(quarters), 1), mar = c(2.8, 5, 2.3, 1), oma = c(2, 0, 3, 0))
  for (quarter in quarters) {
    q <- selected_comparison[as.character(selected_comparison$quarter_id) == quarter, , drop = FALSE]
    graphics::plot(NA, xlim = c(0.5, length(states) + 0.5), ylim = c(0.5, length(symbols) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = paste("Selected-State Agreement", quarter), col.main = aesthetic$text, fg = aesthetic$axis)
    graphics::rect(0.5, 0.5, length(states) + 0.5, length(symbols) + 0.5, col = aesthetic$panel_background, border = NA)
    for (i in seq_len(nrow(q))) {
      x <- match(as.character(q$state_id[[i]]), states)
      y <- match(as.character(q$symbol[[i]]), symbols)
      status <- if (isTRUE(q$spec_match[[i]])) "same_spec" else if (isTRUE(q$family_match[[i]])) "same_family" else "different_family"
      if (is.na(x) || is.na(y)) status <- "missing"
      graphics::rect(x - 0.5, y - 0.5, x + 0.5, y + 0.5, col = status_color[[status]], border = aesthetic$grid)
    }
    graphics::axis(1, at = seq_along(states), labels = states, las = 2, cex.axis = 0.55, col.axis = aesthetic$axis)
    graphics::axis(2, at = seq_along(symbols), labels = symbols, las = 1, cex.axis = 0.75, col.axis = aesthetic$axis)
    graphics::legend("topright", legend = c("Same spec", "Same family", "Different family"), fill = status_color[c("same_spec", "same_family", "different_family")], bty = "n", cex = 0.72)
  }
  graphics::mtext("Direct vs Pooled-Family Selection Churn", side = 3, outer = TRUE, line = 1, font = 2, col = aesthetic$text)
  invisible(path)
}

g5_selection_policy_equity_proxy_from_replay <- function(replay) {
  if (!is.data.frame(replay) || !nrow(replay)) return(data.frame())
  pieces <- split(replay, as.character(replay$symbol))
  rows <- lapply(pieces, function(x) {
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    close <- suppressWarnings(as.numeric(x$close))
    ret <- c(0, close[-1L] / close[-length(close)] - 1)
    pos <- as.character(x$model_position_after_replay) == "LONG"
    pos_lag <- c(FALSE, pos[-length(pos)])
    equity <- cumprod(1 + ifelse(pos_lag, ret, 0))
    data.frame(symbol = as.character(x$symbol), session_date = as.Date(x$session_date), equity_proxy = equity, stringsAsFactors = FALSE)
  })
  symbol_equity <- g5_wfa_bind_rows_fill(rows)
  daily <- stats::aggregate(equity_proxy ~ session_date, data = symbol_equity, FUN = mean)
  names(daily)[names(daily) == "equity_proxy"] <- "equal_symbol_equity_proxy"
  daily
}

g5_selection_policy_prepare_equity_proxy <- function(packet_index) {
  rows <- list()
  for (i in seq_len(nrow(packet_index))) {
    replay <- g5_selection_policy_visual_safe_read_csv(packet_index$replay_csv[[i]])
    if (!nrow(replay)) next
    eq <- g5_selection_policy_equity_proxy_from_replay(replay)
    if (!nrow(eq)) next
    eq$window_id <- as.character(packet_index$window_id[[i]])
    eq$selection_policy <- as.character(packet_index$selection_policy[[i]])
    rows[[length(rows) + 1L]] <- eq
  }
  if (length(rows)) g5_wfa_bind_rows_fill(rows) else data.frame()
}

g5_selection_policy_write_equity_proxy_overlay <- function(equity_proxy, path, width = 2200L, height = 1300L, res = 180L) {
  aesthetic <- g5_chart_aesthetic()
  windows <- unique(as.character(equity_proxy$window_id))
  colors <- c(asset_state_direct_spec = "#2E86AB", pooled_family_asset_variant = "#9B5DE5")
  grDevices::png(path, width = width, height = height, res = res)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(length(windows), 1), mar = c(4.5, 5, 3, 2), oma = c(1, 0, 3, 0))
  for (window in windows) {
    x <- equity_proxy[as.character(equity_proxy$window_id) == window, , drop = FALSE]
    y_range <- range(x$equal_symbol_equity_proxy, na.rm = TRUE)
    pad <- diff(y_range) * 0.08
    if (!is.finite(pad) || pad == 0) pad <- 0.02
    date_range <- range(as.Date(x$session_date))
    graphics::plot(date_range, y_range, type = "n", xaxt = "n", ylim = y_range + c(-pad, pad), xlab = "", ylab = "Equity proxy", main = g5_selection_policy_window_label(window), col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
    graphics::rect(par("usr")[[1L]], par("usr")[[3L]], par("usr")[[2L]], par("usr")[[4L]], col = aesthetic$panel_background, border = NA)
    graphics::grid(col = aesthetic$grid)
    graphics::axis.Date(1, at = pretty(date_range, n = 6), format = "%Y-%m-%d", las = 2, cex.axis = 0.72, col.axis = aesthetic$axis)
    for (policy in names(colors)) {
      p <- x[as.character(x$selection_policy) == policy, , drop = FALSE]
      if (nrow(p)) graphics::lines(as.Date(p$session_date), as.numeric(p$equal_symbol_equity_proxy), col = colors[[policy]], lwd = 2.2)
    }
    graphics::abline(h = 1, col = aesthetic$axis, lty = 2)
    graphics::legend("topleft", legend = c("Direct", "Pooled family"), col = colors, lwd = 2.2, bty = "n", cex = 0.78)
  }
  graphics::mtext("Equal-Symbol Replay Equity Proxy", side = 3, outer = TRUE, line = 1, font = 2, col = aesthetic$text)
  invisible(path)
}

g5_selection_policy_md_table <- function(df, cols, n = Inf) {
  if (!is.data.frame(df) || !nrow(df)) return("_No rows._")
  df <- df[seq_len(min(nrow(df), n)), cols, drop = FALSE]
  df[] <- lapply(df, as.character)
  c(
    paste0("| ", paste(cols, collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(cols)), collapse = " | "), " |"),
    apply(df, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  )
}

g5_selection_policy_write_visual_summary <- function(screen_dir, output_dir = file.path(screen_dir, "visual_summary")) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- g5_selection_policy_visual_paths(output_dir)
  trade_summary <- g5_selection_policy_visual_safe_read_csv(file.path(screen_dir, "selection_policy_trade_summary.csv"))
  trade_ledger <- g5_selection_policy_visual_safe_read_csv(file.path(screen_dir, "selection_policy_trade_ledger.csv"), required = FALSE)
  selected_comparison <- g5_selection_policy_visual_safe_read_csv(file.path(screen_dir, "selection_policy_selected_state_comparison.csv"))
  packet_index <- g5_selection_policy_visual_safe_read_csv(file.path(screen_dir, "selection_policy_packet_index.csv"))

  metric_summary <- g5_selection_policy_prepare_metric_summary(trade_summary, trade_ledger)
  symbol_delta <- g5_selection_policy_prepare_symbol_delta(trade_summary)
  equity_proxy <- g5_selection_policy_prepare_equity_proxy(packet_index)

  g5_selection_policy_write_metric_dashboard(metric_summary, paths$metric_dashboard_png)
  g5_selection_policy_write_return_heatmap(symbol_delta, paths$return_heatmap_png)
  g5_selection_policy_write_return_scatter(symbol_delta, paths$return_scatter_png)
  g5_selection_policy_write_churn_map(selected_comparison, paths$churn_map_png)
  if (nrow(equity_proxy)) g5_selection_policy_write_equity_proxy_overlay(equity_proxy, paths$equity_proxy_png)

  visual_index <- data.frame(
    schema_version = g5_selection_policy_screen_schema_version(),
    chart_id = c("metric_delta_dashboard", "symbol_return_delta_heatmap", "return_scatter", "state_churn_map", "equity_proxy_overlay"),
    chart_type = c("dashboard", "heatmap", "scatter", "tile_map", "time_series"),
    path = normalizePath(c(paths$metric_dashboard_png, paths$return_heatmap_png, paths$return_scatter_png, paths$churn_map_png, paths$equity_proxy_png), winslash = "/", mustWork = FALSE),
    interpretation_note = c(
      "Side-by-side policy metrics by replay window; Sharpe is a trade-return proxy.",
      "Pooled-family minus direct return by symbol/window; highlights concentration of effect.",
      "Each point is one symbol/window; points above diagonal favor pooled-family.",
      "Shows whether selected state rows match by exact spec, family only, or different family.",
      "Equal-symbol replay equity proxy from model position and close-to-close movement."
    ),
    stringsAsFactors = FALSE
  )
  g5_wfa_write_csv(visual_index, paths$visual_index_csv)

  key_deltas <- symbol_delta[order(abs(symbol_delta$return_delta_pooled_minus_direct), decreasing = TRUE), , drop = FALSE]
  key_deltas$return_delta_pct <- sprintf("%.1f%%", 100 * as.numeric(key_deltas$return_delta_pooled_minus_direct))
  key_deltas$direct_return_pct <- sprintf("%.1f%%", 100 * as.numeric(key_deltas$compound_trace_return_direct))
  key_deltas$pooled_return_pct <- sprintf("%.1f%%", 100 * as.numeric(key_deltas$compound_trace_return_pooled))
  metric_print <- metric_summary
  metric_print$mean_trace_return_pct <- sprintf("%.1f%%", 100 * as.numeric(metric_print$equal_symbol_mean_compound_trace_return))
  metric_print$win_rate_pct <- sprintf("%.1f%%", 100 * as.numeric(metric_print$win_rate))
  metric_print$trade_return_sharpe_proxy <- sprintf("%.2f", as.numeric(metric_print$trade_return_sharpe_proxy))

  report <- c(
    "# Selection-Policy Visual Summary",
    "",
    "## Purpose",
    "",
    "This artifact-only visual summary makes the direct asset/state selection policy and pooled-family selection policy easier to compare. It reads the paired screen packet and does not rerun data pulls, PCA fitting, authority selection, or live advice.",
    "",
    "These charts are inspection aids only. Return, win-rate, and trade-return Sharpe proxy are not accepted allocation evidence.",
    "",
    "## Visuals",
    "",
    paste0("- Metric dashboard: `", paths$metric_dashboard_png, "`"),
    paste0("- Symbol return delta heatmap: `", paths$return_heatmap_png, "`"),
    paste0("- Return scatter: `", paths$return_scatter_png, "`"),
    paste0("- Selected-state churn map: `", paths$churn_map_png, "`"),
    paste0("- Equity proxy overlay: `", paths$equity_proxy_png, "`"),
    "",
    "## Metric Summary",
    "",
    g5_selection_policy_md_table(metric_print, c("window_id", "selection_policy", "mean_trace_return_pct", "win_rate_pct", "trade_return_sharpe_proxy", "trade_count", "open_trade_count")),
    "",
    "## Largest Symbol/Window Return Deltas",
    "",
    g5_selection_policy_md_table(key_deltas, c("window_id", "symbol", "direct_return_pct", "pooled_return_pct", "return_delta_pct", "position_match", "latest_family_match"), n = 10L),
    "",
    "## Guardrails",
    "",
    "- The visual summary consumes already-generated paired-screen CSVs.",
    "- The equity overlay is an equal-symbol replay proxy, not the full portfolio accounting surface.",
    "- The trade-return Sharpe proxy is computed from small replay trade samples and should be treated as a rough behavioral diagnostic."
  )
  writeLines(unlist(report), paths$report_md, useBytes = TRUE)

  list(
    paths = paths,
    visual_index = visual_index,
    metric_summary = metric_summary,
    symbol_delta = symbol_delta,
    equity_proxy = equity_proxy
  )
}
