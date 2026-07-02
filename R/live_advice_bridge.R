g5_live_bridge_schema_version <- function() {
  "gen5_live_advice_bridge_v0.1"
}

g5_bridge_default_symbols <- function() {
  c("AMD", "NVDA", "PLTR", "TSLA", "SOFI")
}

g5_bridge_default_context_symbols <- function() {
  c(
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
}

g5_bridge_default_candidate_families <- function() {
  c(
    "ema_cross",
    "ema_trend",
    "bollinger_touch",
    "bollinger_mid_reversion",
    "rsi_mr",
    "zret_mr",
    "breakout",
    "pullback_in_uptrend",
    "vol_expansion_breakout",
    "donchian_breakout_vol_expand",
    "no_trade"
  )
}

g5_bridge_parse_quarter_id <- function(quarter_id) {
  q <- toupper(trimws(as.character(quarter_id)[[1L]]))
  if (!grepl("^[0-9]{4}Q[1-4]$", q)) {
    g5_stop("quarter_id must look like YYYYQ1, YYYYQ2, YYYYQ3, or YYYYQ4.")
  }
  list(year = as.integer(substr(q, 1L, 4L)), quarter = as.integer(substr(q, 6L, 6L)), quarter_id = q)
}

g5_bridge_quarter_id <- function(date) {
  date <- as.Date(date)
  if (length(date) != 1L || is.na(date)) {
    g5_stop("date must be a single valid Date.")
  }
  month <- as.integer(format(date, "%m"))
  quarter <- ((month - 1L) %/% 3L) + 1L
  paste0(format(date, "%Y"), "Q", quarter)
}

g5_bridge_next_quarter_id <- function(quarter_id) {
  parsed <- g5_bridge_parse_quarter_id(quarter_id)
  year <- parsed$year
  quarter <- parsed$quarter + 1L
  if (quarter > 4L) {
    quarter <- 1L
    year <- year + 1L
  }
  paste0(year, "Q", quarter)
}

g5_bridge_quarter_bounds <- function(quarter_id) {
  parsed <- g5_bridge_parse_quarter_id(quarter_id)
  start_month <- (parsed$quarter - 1L) * 3L + 1L
  start_date <- as.Date(sprintf("%04d-%02d-01", parsed$year, start_month))
  next_month <- start_month + 3L
  next_year <- parsed$year
  if (next_month > 12L) {
    next_month <- next_month - 12L
    next_year <- next_year + 1L
  }
  next_start <- as.Date(sprintf("%04d-%02d-01", next_year, next_month))
  list(
    quarter_id = parsed$quarter_id,
    live_start_date = start_date,
    live_end_date = next_start - 1L
  )
}

g5_bridge_authority_contract_dates <- function(quarter_id, train_quarters = 8L) {
  bounds <- g5_bridge_quarter_bounds(quarter_id)
  train_quarters <- as.integer(train_quarters)
  if (is.na(train_quarters) || train_quarters < 1L) {
    g5_stop("train_quarters must be a positive integer.")
  }
  train_end <- bounds$live_start_date - 1L
  train_start <- seq.Date(bounds$live_start_date, by = paste0("-", train_quarters * 3L, " months"), length.out = 2L)[[2L]]
  list(
    quarter_id = bounds$quarter_id,
    train_start_date = train_start,
    train_end_date = train_end,
    live_start_date = bounds$live_start_date,
    live_end_date = bounds$live_end_date,
    train_quarters = train_quarters,
    live_quarters = 1L
  )
}

g5_bridge_safe_stamp <- function(as_of_timestamp) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp)[[1L]])
  if (!nzchar(stamp)) g5_stop("as_of_timestamp must produce a non-empty artifact stamp.")
  stamp
}

g5_bridge_authority_dir <- function(repo_root, quarter_id) {
  file.path(repo_root, "runs", "live_advice_bridge", "authority", g5_bridge_parse_quarter_id(quarter_id)$quarter_id)
}

g5_bridge_daily_dir <- function(repo_root, quarter_id, as_of_timestamp) {
  file.path(repo_root, "runs", "live_advice_bridge", "daily", g5_bridge_parse_quarter_id(quarter_id)$quarter_id, g5_bridge_safe_stamp(as_of_timestamp))
}

g5_bridge_model_grid <- function(
  candidate_families = g5_bridge_default_candidate_families(),
  strategy_grid_preset = "standard"
) {
  strategy_grid_preset <- g5_wfa_strategy_grid_preset(strategy_grid_preset)
  candidate_families <- unique(c(g5_wfa_candidate_families(candidate_families), "no_trade"))
  args <- c(
    list(
      fast_periods = c(8L, 12L),
      slow_periods = c(30L, 50L),
      bb_lookback_periods = c(10L, 20L),
      bb_sd_multipliers = c(1.5, 2),
      candidate_families = candidate_families
    ),
    g5_wfa_strategy_grid_preset_values(strategy_grid_preset)
  )
  do.call(g5_wfa_candidate_model_grid, args)
}

g5_bridge_contract_frame <- function(quarter_id, symbols, context_symbols = symbols, as_of_timestamp, refresh, git_sha = NA_character_, market_data_feed = NA_character_, candidate_families = g5_bridge_default_candidate_families(), strategy_grid_preset = "standard") {
  dates <- g5_bridge_authority_contract_dates(quarter_id, train_quarters = 8L)
  symbols <- g5_standardize_symbol(symbols)
  context_symbols <- unique(g5_standardize_symbol(context_symbols))
  candidate_families <- unique(c(g5_wfa_candidate_families(candidate_families), "no_trade"))
  strategy_grid_preset <- g5_wfa_strategy_grid_preset(strategy_grid_preset)
  data.frame(
    schema_version = g5_live_bridge_schema_version(),
    quarter_id = dates$quarter_id,
    authority_status = "TEMPORARY_BRIDGE_ADVICE_ONLY",
    research_note = "Temporary bridge: Gen5.1 long/pooled PCA plus 5x5 quantile states, mimicking the Gen4 operating style while Gen5.1 production mechanics are still under construction.",
    symbols = paste(symbols, collapse = ","),
    context_symbols = paste(context_symbols, collapse = ","),
    train_start_date = dates$train_start_date,
    train_end_date = dates$train_end_date,
    live_start_date = dates$live_start_date,
    live_end_date = dates$live_end_date,
    train_quarters = dates$train_quarters,
    live_quarters = dates$live_quarters,
    pca_panel_mode = "pooled_asset_day",
    pca_panel_label = "long_pca_behavioral_pool",
    state_engine = "quantile_grid",
    grid_n = 5L,
    strategy_grid_preset = strategy_grid_preset,
    candidate_families = paste(candidate_families, collapse = ","),
    position_source = "model_replay_one_bar_delay",
    advice_mode = "after_close_signal_for_next_open_manual_order",
    market_data_feed = as.character(market_data_feed),
    as_of_timestamp = as.character(as_of_timestamp),
    refresh = isTRUE(refresh),
    git_sha = as.character(git_sha),
    stringsAsFactors = FALSE
  )
}

g5_bridge_authority_fold <- function(symbol, contract) {
  data.frame(
    fold_id = paste0(contract$quarter_id[[1L]], "_bridge_authority_", g5_standardize_symbol(symbol)[[1L]]),
    fold_no = 1L,
    symbol = g5_standardize_symbol(symbol)[[1L]],
    train_start_date = as.Date(contract$train_start_date[[1L]]),
    train_end_date = as.Date(contract$train_end_date[[1L]]),
    oos_start_date = as.Date(contract$live_start_date[[1L]]),
    oos_end_date = as.Date(contract$live_end_date[[1L]]),
    train_session_count = NA_integer_,
    oos_session_count = NA_integer_,
    stringsAsFactors = FALSE
  )
}

g5_bridge_assert_symbols_available <- function(bars, symbols) {
  have <- if (is.data.frame(bars) && nrow(bars)) unique(g5_standardize_symbol(bars$symbol)) else character()
  missing <- setdiff(g5_standardize_symbol(symbols), have)
  if (length(missing)) {
    g5_stop(paste0("Bridge bars are missing required symbols: ", paste(missing, collapse = ",")))
  }
  invisible(TRUE)
}

g5_bridge_build_authority_from_bars <- function(
  bars,
  symbols = g5_bridge_default_symbols(),
  context_symbols = symbols,
  quarter_id,
  as_of_timestamp,
  refresh = FALSE,
  git_sha = NA_character_,
  market_data_feed = NA_character_,
  candidate_families = g5_bridge_default_candidate_families(),
  strategy_grid_preset = "standard",
  min_train_state_rows = 20L
) {
  symbols <- g5_standardize_symbol(symbols)
  context_symbols <- unique(g5_standardize_symbol(context_symbols))
  g5_bridge_assert_symbols_available(bars, unique(c(symbols, context_symbols)))
  contract <- g5_bridge_contract_frame(quarter_id, symbols, context_symbols, as_of_timestamp, refresh, git_sha, market_data_feed, candidate_families, strategy_grid_preset)
  model_grid <- g5_bridge_model_grid(candidate_families = candidate_families, strategy_grid_preset = strategy_grid_preset)
  fold_rows <- list()
  selected_rows <- list()
  perf_rows <- list()
  coverage_rows <- list()
  score_rows <- list()
  contract_rows <- list()
  fold_models <- list()
  for (symbol in symbols) {
    fold <- g5_bridge_authority_fold(symbol, contract)
    fitted <- g5_pca_wfa_fit_fold_models(
      bars,
      symbol = symbol,
      folds = fold,
      model_grid = model_grid,
      grid_n = 5L,
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
    fold_rows[[length(fold_rows) + 1L]] <- fold
    selected_rows[[length(selected_rows) + 1L]] <- fitted$selected_states
    perf_rows[[length(perf_rows) + 1L]] <- fitted$train_state_performance
    coverage_rows[[length(coverage_rows) + 1L]] <- fitted$state_coverage
    score_rows[[length(score_rows) + 1L]] <- fitted$pca_scores
    contract_rows[[length(contract_rows) + 1L]] <- fitted$pca_model_contract
    fold_models[[symbol]] <- fitted$fold_models[[fold$fold_id[[1L]]]]
  }
  list(
    contract = contract,
    folds = g5_wfa_bind_rows_fill(fold_rows),
    selected_states = g5_wfa_bind_rows_fill(selected_rows),
    train_state_performance = g5_wfa_bind_rows_fill(perf_rows),
    state_coverage = g5_wfa_bind_rows_fill(coverage_rows),
    pca_scores = g5_wfa_bind_rows_fill(score_rows),
    pca_model_contract = g5_wfa_bind_rows_fill(contract_rows),
    model_grid = model_grid,
    fold_models = fold_models
  )
}

g5_bridge_score_frozen_quantile <- function(features, contract, symbol) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  contract <- contract[contract$research_candidate_symbol == symbol | contract$symbol == symbol, , drop = FALSE]
  feature_rows <- contract[contract$record_type == "feature", , drop = FALSE]
  if (!nrow(feature_rows)) {
    g5_stop(paste0("No frozen PCA feature rows found for ", symbol, "."))
  }
  feature_cols <- as.character(feature_rows$feature)
  missing <- setdiff(feature_cols, names(features))
  if (length(missing)) {
    g5_stop(paste0("Frozen PCA scoring features missing for ", symbol, ": ", paste(missing, collapse = ",")))
  }
  scored <- features[stats::complete.cases(features[, feature_cols, drop = FALSE]), , drop = FALSE]
  if (!nrow(scored)) {
    g5_stop(paste0("No complete feature rows available for frozen PCA scoring: ", symbol))
  }
  x <- as.matrix(scored[, feature_cols, drop = FALSE])
  centers <- stats::setNames(as.numeric(feature_rows$center), feature_cols)
  scales <- stats::setNames(as.numeric(feature_rows$scale), feature_cols)
  loading_pc1 <- stats::setNames(as.numeric(feature_rows$loading_pc1), feature_cols)
  loading_pc2 <- stats::setNames(as.numeric(feature_rows$loading_pc2), feature_cols)
  x <- sweep(x, 2, centers[feature_cols], "-")
  x <- sweep(x, 2, scales[feature_cols], "/")
  scored$pc1 <- as.numeric(x %*% loading_pc1[feature_cols])
  scored$pc2 <- as.numeric(x %*% loading_pc2[feature_cols])
  meta_grid <- contract[contract$record_type == "meta" & contract$key == "grid_n", "value", drop = TRUE]
  grid_n <- as.integer(meta_grid[[1L]])
  if (is.na(grid_n) || grid_n < 2L) {
    g5_stop("Frozen PCA contract has invalid grid_n metadata.")
  }
  pc1_q <- as.numeric(contract$break_value[contract$record_type == "pc_break" & contract$break_axis == "pc1"])
  pc2_q <- as.numeric(contract$break_value[contract$record_type == "pc_break" & contract$break_axis == "pc2"])
  pc1_breaks <- c(-Inf, pc1_q[2:grid_n], Inf)
  pc2_breaks <- c(-Inf, pc2_q[2:grid_n], Inf)
  scored$pc1_bin <- as.integer(cut(scored$pc1, breaks = pc1_breaks, include.lowest = TRUE, labels = FALSE))
  scored$pc2_bin <- as.integer(cut(scored$pc2, breaks = pc2_breaks, include.lowest = TRUE, labels = FALSE))
  scored$state_id <- paste0("S", scored$pc1_bin, "_", scored$pc2_bin)
  scored$state_id[is.na(scored$pc1_bin) | is.na(scored$pc2_bin)] <- NA_character_
  scored <- scored[scored$symbol == symbol, , drop = FALSE]
  rownames(scored) <- NULL
  scored
}

g5_bridge_latest_selected <- function(selected_by_state, state) {
  if (!is.na(state) && state %in% names(selected_by_state)) {
    return(selected_by_state[[state]][1L, , drop = FALSE])
  }
  selected_by_state[[1L]][0L, , drop = FALSE]
}

g5_bridge_replay_symbol <- function(bars, symbol, scored, selected_states, contract) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  train_end_date <- as.Date(contract$train_end_date[[1L]])
  live_start_date <- as.Date(contract$live_start_date[[1L]])
  live_end_date <- as.Date(contract$live_end_date[[1L]])
  as_of_date <- max(as.Date(scored$session_date), na.rm = TRUE)
  if (as_of_date < live_start_date) {
    g5_stop("Daily bridge as_of date is before authority live_start_date.")
  }
  if (as_of_date > live_end_date) {
    g5_stop("Daily bridge authority is expired for this as_of date.")
  }
  all_bars <- g5_ema_cross_prepare_bars(bars, symbol = symbol, end_date = as_of_date)
  session_dates <- as.Date(all_bars$session_date)
  state_lookup <- stats::setNames(as.character(scored$state_id), as.character(as.Date(scored$session_date)))
  selected_keep <- rep(FALSE, nrow(selected_states))
  if ("symbol" %in% names(selected_states)) {
    selected_keep <- selected_keep | selected_states$symbol == symbol
  }
  if ("research_candidate_symbol" %in% names(selected_states)) {
    selected_keep <- selected_keep | selected_states$research_candidate_symbol == symbol
  }
  selected_states <- selected_states[selected_keep, , drop = FALSE]
  if (!nrow(selected_states)) {
    g5_stop(paste0("Frozen selected state authority has no rows for ", symbol, "."))
  }
  selected_by_state <- split(selected_states, selected_states$state_id)
  indicator_cache <- list()
  for (i in seq_len(nrow(selected_states))) {
    row <- selected_states[i, , drop = FALSE]
    spec_id <- row$strategy_spec_id[[1L]]
    if (!spec_id %in% names(indicator_cache)) {
      indicator_cache[[spec_id]] <- g5_wfa_model_indicators(all_bars, symbol, g5_pca_wfa_model_from_metric(row))
    }
  }

  signal_indices <- which(session_dates >= train_end_date & session_dates <= as_of_date)
  rows <- list()
  executions <- list()
  pending_actions <- list()
  in_position <- FALSE
  open_trade <- NULL
  pending_entry <- NULL
  pending_exit <- NULL

  for (idx in signal_indices) {
    current_date <- session_dates[[idx]]
    current_state <- unname(state_lookup[[as.character(current_date)]])
    if (is.null(current_state) || is.na(current_state)) current_state <- NA_character_
    action_today <- "NONE"
    execution_today <- "NONE"
    selected <- g5_bridge_latest_selected(selected_by_state, current_state)
    selected_family <- if (nrow(selected)) as.character(selected$strategy_family[[1L]]) else NA_character_
    selected_spec <- if (nrow(selected)) as.character(selected$strategy_spec_id[[1L]]) else NA_character_

    if (!is.null(pending_entry) && identical(as.Date(pending_entry$execution_date), current_date) && !in_position && current_date >= live_start_date) {
      open_trade <- c(
        pending_entry,
        list(
          entry_execution_idx = idx,
          entry_execution_date = current_date,
          entry_execution_price = as.numeric(all_bars$open[[idx]]),
          entry_execution_state_id = current_state
        )
      )
      in_position <- TRUE
      execution_today <- "ENTER_EXECUTED_AT_OPEN"
      executions[[length(executions) + 1L]] <- data.frame(
        symbol = symbol,
        execution_date = current_date,
        execution_type = "ENTER_LONG",
        execution_price = as.numeric(all_bars$open[[idx]]),
        strategy_spec_id = open_trade$strategy_spec_id,
        state_id = current_state,
        stringsAsFactors = FALSE
      )
      pending_entry <- NULL
    }

    if (!is.null(pending_exit) && identical(as.Date(pending_exit$execution_date), current_date) && in_position) {
      execution_today <- "EXIT_EXECUTED_AT_OPEN"
      executions[[length(executions) + 1L]] <- data.frame(
        symbol = symbol,
        execution_date = current_date,
        execution_type = "EXIT_LONG",
        execution_price = as.numeric(all_bars$open[[idx]]),
        strategy_spec_id = open_trade$strategy_spec_id,
        state_id = current_state,
        stringsAsFactors = FALSE
      )
      in_position <- FALSE
      open_trade <- NULL
      pending_exit <- NULL
    }

    next_idx <- idx + 1L
    has_next_session_in_data <- next_idx <= nrow(all_bars)
    next_session <- if (has_next_session_in_data) session_dates[[next_idx]] else as.Date(NA)

    if (!in_position && is.null(pending_entry) && nrow(selected) && !identical(selected_family, "no_trade")) {
      ind <- indicator_cache[[selected_spec]]
      if (isTRUE(ind$entry_signal[[idx]])) {
        pending_entry <- list(
          entry_state_id = current_state,
          strategy_family = selected_family,
          model_instance_id = selected$model_instance_id[[1L]],
          exit_stack_id = selected$exit_stack_id[[1L]],
          strategy_spec_id = selected_spec,
          fast_period = g5_wfa_model_value(selected, "fast_period", NA_integer_),
          slow_period = g5_wfa_model_value(selected, "slow_period", NA_integer_),
          lookback_period = g5_wfa_model_value(selected, "lookback_period", NA_integer_),
          sd_multiplier = g5_wfa_model_value(selected, "sd_multiplier", NA_real_),
          entry_signal_rule = ind$entry_signal_rule[[idx]],
          entry_signal_date = current_date,
          entry_signal_idx = idx,
          entry_signal_price = as.numeric(all_bars$close[[idx]]),
          execution_date = next_session
        )
        action_today <- "ENTER_LONG_NEXT_OPEN"
        if (!has_next_session_in_data) {
          pending_actions[[length(pending_actions) + 1L]] <- data.frame(
            symbol = symbol,
            as_of_date = current_date,
            action = "ENTER_LONG_NEXT_OPEN",
            current_position = "FLAT",
            desired_position_after_execution = "LONG",
            state_id = current_state,
            strategy_family = selected_family,
            strategy_spec_id = selected_spec,
            signal_price = as.numeric(all_bars$close[[idx]]),
            execution_date = as.Date(NA),
            execution_timing = "next_open_after_as_of_close",
            signal_rule = ind$entry_signal_rule[[idx]],
            stringsAsFactors = FALSE
          )
        }
      }
    }

    if (in_position && is.null(pending_exit)) {
      owner <- selected_states[selected_states$strategy_spec_id == open_trade$strategy_spec_id & selected_states$state_id == open_trade$entry_state_id, , drop = FALSE]
      if (!nrow(owner)) owner <- selected_states[selected_states$strategy_spec_id == open_trade$strategy_spec_id, , drop = FALSE][1L, , drop = FALSE]
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
            execution_date = next_session
          )
        )
        action_today <- "EXIT_LONG_NEXT_OPEN"
        if (!has_next_session_in_data) {
          pending_actions[[length(pending_actions) + 1L]] <- data.frame(
            symbol = symbol,
            as_of_date = current_date,
            action = "EXIT_LONG_NEXT_OPEN",
            current_position = "LONG",
            desired_position_after_execution = "FLAT",
            state_id = current_state,
            strategy_family = open_trade$strategy_family,
            strategy_spec_id = open_trade$strategy_spec_id,
            signal_price = as.numeric(all_bars$close[[idx]]),
            execution_date = as.Date(NA),
            execution_timing = "next_open_after_as_of_close",
            signal_rule = pending_exit$exit_signal_rule,
            stringsAsFactors = FALSE
          )
        }
      }
    }

    rows[[length(rows) + 1L]] <- data.frame(
      schema_version = g5_live_bridge_schema_version(),
      symbol = symbol,
      session_date = current_date,
      open = as.numeric(all_bars$open[[idx]]),
      high = as.numeric(all_bars$high[[idx]]),
      low = as.numeric(all_bars$low[[idx]]),
      close = as.numeric(all_bars$close[[idx]]),
      state_id = current_state,
      selected_strategy_family = selected_family,
      selected_strategy_spec_id = selected_spec,
      model_position_after_replay = if (in_position) "LONG" else "FLAT",
      execution_status = execution_today,
      signal_status = action_today,
      open_trade_strategy_spec_id = if (in_position && !is.null(open_trade)) open_trade$strategy_spec_id else NA_character_,
      open_trade_entry_execution_date = if (in_position && !is.null(open_trade)) open_trade$entry_execution_date else as.Date(NA),
      stringsAsFactors = FALSE
    )
  }
  replay <- if (length(rows)) g5_wfa_bind_rows_fill(rows) else data.frame()
  pending <- if (length(pending_actions)) g5_wfa_bind_rows_fill(pending_actions) else data.frame()
  executions <- if (length(executions)) g5_wfa_bind_rows_fill(executions) else data.frame()
  trades <- g5_bridge_trades_from_replay(replay, executions, as.Date(contract$live_end_date[[1L]]))
  latest <- if (nrow(replay)) replay[nrow(replay), , drop = FALSE] else data.frame()
  list(replay = replay, pending_actions = pending, executions = executions, trades = trades, latest = latest)
}

g5_bridge_run_daily_from_bars <- function(bars, authority, as_of_timestamp) {
  contract <- authority$contract[1L, , drop = FALSE]
  symbols <- g5_standardize_symbol(strsplit(contract$symbols[[1L]], ",", fixed = TRUE)[[1L]])
  context_symbols <- if ("context_symbols" %in% names(contract) && nzchar(as.character(contract$context_symbols[[1L]]))) {
    unique(g5_standardize_symbol(strsplit(contract$context_symbols[[1L]], ",", fixed = TRUE)[[1L]]))
  } else {
    symbols
  }
  as_of_date <- as.Date(max(as.Date(bars$session_date), na.rm = TRUE))
  results <- list()
  for (symbol in symbols) {
    features <- g5_pca_regime_pooled_feature_table(
      bars,
      target_symbol = symbol,
      context_symbols = context_symbols,
      end_date = as_of_date
    )
    scored <- g5_bridge_score_frozen_quantile(features, authority$pca_model_contract, symbol)
    results[[symbol]] <- g5_bridge_replay_symbol(bars, symbol, scored, authority$selected_states, contract)
    results[[symbol]]$scores <- scored
  }
  replay <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$replay))
  pending <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$pending_actions))
  executions <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$executions))
  trades <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$trades))
  latest <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$latest))
  book <- latest[, c("symbol", "session_date", "close", "state_id", "selected_strategy_family", "model_position_after_replay", "signal_status", "execution_status", "open_trade_strategy_spec_id", "open_trade_entry_execution_date"), drop = FALSE]
  names(book)[names(book) == "session_date"] <- "as_of_date"
  names(book)[names(book) == "model_position_after_replay"] <- "current_model_position"
  list(
    contract = contract,
    as_of_timestamp = as_of_timestamp,
    as_of_date = as_of_date,
    symbol_results = results,
    replay = replay,
    pending_actions = pending,
    executions = executions,
    trades = trades,
    operator_packet = latest,
    book_summary = book
  )
}

g5_bridge_write_authority_outputs <- function(authority, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- list(
    contract_csv = file.path(output_dir, "bridge_authority_contract.csv"),
    folds_csv = file.path(output_dir, "bridge_authority_folds.csv"),
    selected_states_csv = file.path(output_dir, "bridge_selected_states.csv"),
    train_state_performance_csv = file.path(output_dir, "bridge_train_state_performance.csv"),
    state_coverage_csv = file.path(output_dir, "bridge_state_coverage.csv"),
    pca_scores_csv = file.path(output_dir, "bridge_train_pca_scores.csv"),
    pca_model_contract_csv = file.path(output_dir, "bridge_pca_model_contract.csv"),
    model_grid_csv = file.path(output_dir, "bridge_model_grid.csv"),
    report_md = file.path(output_dir, "bridge_authority_report.md")
  )
  g5_wfa_write_csv(authority$contract, paths$contract_csv)
  g5_wfa_write_csv(authority$folds, paths$folds_csv)
  g5_wfa_write_csv(authority$selected_states, paths$selected_states_csv)
  g5_wfa_write_csv(authority$train_state_performance, paths$train_state_performance_csv)
  g5_wfa_write_csv(authority$state_coverage, paths$state_coverage_csv)
  g5_wfa_write_csv(authority$pca_scores, paths$pca_scores_csv)
  g5_wfa_write_csv(authority$pca_model_contract, paths$pca_model_contract_csv)
  g5_wfa_write_csv(authority$model_grid, paths$model_grid_csv)
  contract <- authority$contract[1L, , drop = FALSE]
  lines <- c(
    paste0("# Gen5.1 Live Advice Bridge Authority: ", contract$quarter_id[[1L]]),
    "",
    "## Purpose",
    "",
    "This first bridge test exists to keep daily manual trading advice available while Gen5.1 production mechanics are still being built. It freezes a completed-quarter research authority packet, then uses that packet to replay model state and produce next-open advice. It is not allocation evidence and it is not an execution system.",
    "",
    "## Frozen Authority",
    "",
    paste0("- Symbols: `", contract$symbols[[1L]], "`"),
    paste0("- Regime Context Universe: `", if ("context_symbols" %in% names(contract)) contract$context_symbols[[1L]] else contract$symbols[[1L]], "`"),
    paste0("- TRAIN window: `", contract$train_start_date[[1L]], "` through `", contract$train_end_date[[1L]], "`"),
    paste0("- Live authority window: `", contract$live_start_date[[1L]], "` through `", contract$live_end_date[[1L]], "`"),
    "- PCA surface: long/pooled asset-day PCA (`pooled_asset_day`)",
    "- State map: `5x5` quantile grid",
    paste0("- Candidate families: `", contract$candidate_families[[1L]], "`"),
    "- Position source: model replay with one-bar delayed next-open execution",
    "",
    "## Guardrails",
    "",
    "- The authority is advice-only and expires at quarter end.",
    "- The daily runner must use an explicit `as_of_timestamp`.",
    "- Authority selection uses only completed data through the prior quarter end.",
    "- Daily outputs infer position from replay and do not place orders."
  )
  writeLines(lines, paths$report_md, useBytes = TRUE)
  paths
}

g5_bridge_read_authority <- function(authority_dir) {
  paths <- list(
    contract = file.path(authority_dir, "bridge_authority_contract.csv"),
    selected_states = file.path(authority_dir, "bridge_selected_states.csv"),
    pca_model_contract = file.path(authority_dir, "bridge_pca_model_contract.csv")
  )
  missing <- names(paths)[!file.exists(unlist(paths))]
  if (length(missing)) {
    g5_stop(paste0("Missing bridge authority artifact(s): ", paste(missing, collapse = ",")))
  }
  list(
    authority_dir = normalizePath(authority_dir, winslash = "/", mustWork = FALSE),
    contract = utils::read.csv(paths$contract, stringsAsFactors = FALSE),
    selected_states = utils::read.csv(paths$selected_states, stringsAsFactors = FALSE),
    pca_model_contract = utils::read.csv(paths$pca_model_contract, stringsAsFactors = FALSE)
  )
}

g5_bridge_trades_from_replay <- function(replay, executions, authority_end_date) {
  if (!is.data.frame(executions) || !nrow(executions)) {
    return(data.frame())
  }
  executions <- executions[order(as.Date(executions$execution_date)), , drop = FALSE]
  replay_dates <- if (is.data.frame(replay) && nrow(replay)) as.Date(replay$session_date) else as.Date(character())
  rows <- list()
  open_exec <- NULL
  for (i in seq_len(nrow(executions))) {
    row <- executions[i, , drop = FALSE]
    if (identical(as.character(row$execution_type[[1L]]), "ENTER_LONG")) {
      open_exec <- row
    } else if (identical(as.character(row$execution_type[[1L]]), "EXIT_LONG") && !is.null(open_exec)) {
      trace_return <- as.numeric(row$execution_price[[1L]]) / as.numeric(open_exec$execution_price[[1L]]) - 1
      rows[[length(rows) + 1L]] <- data.frame(
        symbol = as.character(row$symbol[[1L]]),
        trade_status = "closed",
        entry_execution_date = as.Date(open_exec$execution_date[[1L]]),
        entry_execution_price = as.numeric(open_exec$execution_price[[1L]]),
        exit_execution_date = as.Date(row$execution_date[[1L]]),
        exit_execution_price = as.numeric(row$execution_price[[1L]]),
        trace_end_date = as.Date(row$execution_date[[1L]]),
        trace_end_price = as.numeric(row$execution_price[[1L]]),
        trade_outcome = if (trace_return > 0) "win" else if (trace_return < 0) "loss" else "flat",
        strategy_spec_id = as.character(open_exec$strategy_spec_id[[1L]]),
        stringsAsFactors = FALSE
      )
      open_exec <- NULL
    }
  }
  if (!is.null(open_exec) && length(replay_dates)) {
    latest <- replay[nrow(replay), , drop = FALSE]
    trace_return <- as.numeric(latest$close[[1L]]) / as.numeric(open_exec$execution_price[[1L]]) - 1
    rows[[length(rows) + 1L]] <- data.frame(
      symbol = as.character(open_exec$symbol[[1L]]),
      trade_status = "open",
      entry_execution_date = as.Date(open_exec$execution_date[[1L]]),
      entry_execution_price = as.numeric(open_exec$execution_price[[1L]]),
      exit_execution_date = as.Date(NA),
      exit_execution_price = NA_real_,
      trace_end_date = as.Date(latest$session_date[[1L]]),
      trace_end_price = as.numeric(latest$close[[1L]]),
      trade_outcome = if (trace_return > 0) "win" else if (trace_return < 0) "loss" else "flat",
      strategy_spec_id = as.character(open_exec$strategy_spec_id[[1L]]),
      stringsAsFactors = FALSE
    )
  }
  if (length(rows)) g5_wfa_bind_rows_fill(rows) else data.frame()
}

g5_bridge_date_to_visible_x <- function(date, dates) {
  date <- as.Date(date)
  dates <- as.Date(dates)
  matched <- match(date, dates)
  if (!is.na(matched)) return(as.numeric(matched))
  if (date < dates[[1L]]) return(1 - as.numeric(dates[[1L]] - date))
  if (date > dates[[length(dates)]]) return(length(dates) + as.numeric(date - dates[[length(dates)]]))
  before <- max(which(dates < date))
  after <- min(which(dates > date))
  before + as.numeric(date - dates[[before]]) / as.numeric(dates[[after]] - dates[[before]])
}

g5_bridge_interpolate_trace_price <- function(target_date, start_date, start_price, end_date, end_price) {
  target_date <- as.Date(target_date)
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  start_price <- as.numeric(start_price)
  end_price <- as.numeric(end_price)
  if (!is.finite(start_price) || !is.finite(end_price)) return(NA_real_)
  span <- as.numeric(end_date - start_date)
  if (!is.finite(span) || span == 0) return(end_price)
  start_price + (end_price - start_price) * (as.numeric(target_date - start_date) / span)
}

g5_bridge_visible_trade_segments <- function(trades, dates) {
  if (!is.data.frame(trades) || !nrow(trades) || !length(dates)) return(data.frame())
  dates <- as.Date(dates)
  visible_start <- dates[[1L]]
  visible_end <- dates[[length(dates)]]
  rows <- list()
  for (i in seq_len(nrow(trades))) {
    trade <- trades[i, , drop = FALSE]
    entry_date <- as.Date(trade$entry_execution_date[[1L]])
    end_date <- as.Date(trade$trace_end_date[[1L]])
    entry_price <- as.numeric(trade$entry_execution_price[[1L]])
    end_price <- as.numeric(trade$trace_end_price[[1L]])
    if (is.na(entry_date) || is.na(end_date) || !is.finite(entry_price) || !is.finite(end_price)) next
    if (end_date < visible_start || entry_date > visible_end) next
    clipped_start <- max(entry_date, visible_start)
    clipped_end <- min(end_date, visible_end)
    y0 <- g5_bridge_interpolate_trace_price(clipped_start, entry_date, entry_price, end_date, end_price)
    y1 <- g5_bridge_interpolate_trace_price(clipped_end, entry_date, entry_price, end_date, end_price)
    x0 <- g5_bridge_date_to_visible_x(clipped_start, dates)
    x1 <- g5_bridge_date_to_visible_x(clipped_end, dates)
    if (!is.finite(x0) || !is.finite(x1) || !is.finite(y0) || !is.finite(y1)) next
    if (identical(x0, x1)) x1 <- min(length(dates) + 0.45, x1 + 0.45)
    rows[[length(rows) + 1L]] <- data.frame(
      x0 = x0,
      y0 = y0,
      x1 = x1,
      y1 = y1,
      trade_status = as.character(trade$trade_status[[1L]]),
      trade_outcome = as.character(trade$trade_outcome[[1L]]),
      stringsAsFactors = FALSE
    )
  }
  if (length(rows)) g5_wfa_bind_rows_fill(rows) else data.frame()
}

g5_bridge_plot_panel <- function(replay, executions, pending, trades = data.frame(), main = "") {
  if (!is.data.frame(replay) || !nrow(replay)) {
    graphics::plot.new()
    graphics::title(main)
    graphics::text(0.5, 0.5, "No replay rows")
    return(invisible(NULL))
  }
  aesthetic <- g5_chart_aesthetic()
  dates <- as.Date(replay$session_date)
  x <- seq_along(dates)
  open <- as.numeric(replay$open)
  high <- as.numeric(replay$high)
  low <- as.numeric(replay$low)
  close <- as.numeric(replay$close)
  yrange <- range(c(low, high, close), na.rm = TRUE)
  pad <- diff(yrange) * 0.08
  if (!is.finite(pad) || pad == 0) pad <- max(1, yrange[[1L]] * 0.02)
  graphics::plot(x, close, type = "n", xaxt = "n", xlab = "", ylab = "Adjusted price", main = main, ylim = yrange + c(-pad, pad), xlim = c(0.5, length(x) + 0.9), xaxs = "i", col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  states <- as.factor(replay$state_id)
  palette <- grDevices::hcl.colors(max(3L, length(levels(states))), "Set 3")
  for (i in seq_along(x)) {
    col <- grDevices::adjustcolor(palette[as.integer(states[[i]])], alpha.f = 0.22)
    graphics::rect(i - 0.5, par("usr")[[3L]], i + 0.5, par("usr")[[4L]], col = col, border = NA)
  }
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  body_colors <- ifelse(close > open, aesthetic$up_candle, ifelse(close < open, aesthetic$down_candle, aesthetic$flat_candle))
  candle_half_width <- 0.18
  graphics::segments(x0 = x, y0 = low, x1 = x, y1 = high, col = body_colors, lwd = 0.85)
  for (i in seq_along(x)) {
    body_low <- min(open[[i]], close[[i]], na.rm = TRUE)
    body_high <- max(open[[i]], close[[i]], na.rm = TRUE)
    if (!is.finite(body_low) || !is.finite(body_high)) next
    if (identical(body_low, body_high)) {
      graphics::segments(x[[i]] - candle_half_width, body_low, x[[i]] + candle_half_width, body_high, col = body_colors[[i]], lwd = 1.2)
    } else {
      graphics::rect(x[[i]] - candle_half_width, body_low, x[[i]] + candle_half_width, body_high, col = body_colors[[i]], border = body_colors[[i]])
    }
  }
  if (is.data.frame(trades) && nrow(trades)) {
    trace_segments <- g5_bridge_visible_trade_segments(trades, dates)
    if (nrow(trace_segments)) {
      line_cols <- ifelse(trace_segments$trade_outcome == "win", aesthetic$trade_win_line, ifelse(trace_segments$trade_outcome == "loss", aesthetic$trade_loss_line, aesthetic$flat_candle))
      graphics::segments(trace_segments$x0, trace_segments$y0, trace_segments$x1, trace_segments$y1, col = line_cols, lty = aesthetic$trade_line_lty, lwd = 1.15)
    }
  }
  at <- unique(round(seq(1, length(x), length.out = min(6L, length(x)))))
  graphics::axis(1, at = at, labels = format(dates[at], "%m-%d"), las = 2, cex.axis = 0.75)
  entry_sig <- which(replay$signal_status == "ENTER_LONG_NEXT_OPEN")
  exit_sig <- which(replay$signal_status == "EXIT_LONG_NEXT_OPEN")
  if (length(entry_sig)) graphics::points(entry_sig, close[entry_sig], pch = aesthetic$entry_signal_pch, bg = aesthetic$entry_signal_color, col = aesthetic$entry_signal_color, cex = 1.0)
  if (length(exit_sig)) graphics::points(exit_sig, close[exit_sig], pch = aesthetic$exit_signal_pch, bg = aesthetic$exit_signal_color, col = aesthetic$exit_signal_color, cex = 1.0)
  if (is.data.frame(executions) && nrow(executions)) {
    exec_x <- match(as.Date(executions$execution_date), dates)
    entry_exec <- executions$execution_type == "ENTER_LONG"
    exit_exec <- executions$execution_type == "EXIT_LONG"
    if (any(entry_exec, na.rm = TRUE)) graphics::points(exec_x[entry_exec], as.numeric(executions$execution_price[entry_exec]), pch = aesthetic$native_entry_pch, col = aesthetic$native_entry_color, bg = aesthetic$native_entry_color, cex = 1.15)
    if (any(exit_exec, na.rm = TRUE)) graphics::points(exec_x[exit_exec], as.numeric(executions$execution_price[exit_exec]), pch = aesthetic$native_exit_pch, col = aesthetic$native_exit_color, bg = aesthetic$native_exit_color, cex = 1.15)
  }
  if (is.data.frame(pending) && nrow(pending)) {
    graphics::mtext(paste("PENDING:", paste(pending$action, collapse = "; ")), side = 3, line = -1.2, adj = 1, cex = 0.75, col = "#7c2d12")
  }
  present_states <- levels(states)
  present_cols <- grDevices::adjustcolor(palette[seq_along(present_states)], alpha.f = 0.45)
  if (length(present_states)) {
    graphics::legend(
      "topleft",
      legend = present_states,
      fill = present_cols,
      border = NA,
      title = "State",
      bty = "n",
      cex = if (length(present_states) > 8L) 0.48 else 0.58,
      ncol = if (length(present_states) > 8L) 2L else 1L,
      text.col = aesthetic$text
    )
  }
  invisible(NULL)
}

g5_bridge_chart_replay <- function(symbol_result, min_rows = 80L) {
  replay <- symbol_result$replay
  scores <- symbol_result$scores
  if (!is.data.frame(scores) || !nrow(scores)) {
    return(replay)
  }
  if (is.data.frame(replay) && nrow(replay) >= min_rows) {
    return(replay)
  }
  keep <- tail(seq_len(nrow(scores)), min_rows)
  chart <- data.frame(
    schema_version = g5_live_bridge_schema_version(),
    symbol = as.character(scores$symbol[keep]),
    session_date = as.Date(scores$session_date[keep]),
    close = as.numeric(scores$close[keep]),
    open = as.numeric(scores$open[keep]),
    high = as.numeric(scores$high[keep]),
    low = as.numeric(scores$low[keep]),
    state_id = as.character(scores$state_id[keep]),
    selected_strategy_family = NA_character_,
    selected_strategy_spec_id = NA_character_,
    model_position_after_replay = NA_character_,
    execution_status = "NONE",
    signal_status = "NONE",
    open_trade_strategy_spec_id = NA_character_,
    open_trade_entry_execution_date = as.Date(NA),
    stringsAsFactors = FALSE
  )
  if (is.data.frame(replay) && nrow(replay)) {
    idx <- match(as.Date(replay$session_date), as.Date(chart$session_date))
    idx <- idx[!is.na(idx)]
    if (length(idx)) {
      replay_match <- replay[match(as.Date(chart$session_date[idx]), as.Date(replay$session_date)), , drop = FALSE]
      for (col in intersect(names(chart), names(replay_match))) {
        chart[idx, col] <- replay_match[[col]]
      }
    }
  }
  chart
}

g5_bridge_write_daily_outputs <- function(daily, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- list(
    operator_packet_csv = file.path(output_dir, "bridge_operator_packet.csv"),
    pending_actions_csv = file.path(output_dir, "bridge_pending_actions.csv"),
    book_summary_csv = file.path(output_dir, "bridge_book_summary.csv"),
    replay_csv = file.path(output_dir, "bridge_replay.csv"),
    executions_csv = file.path(output_dir, "bridge_executions.csv"),
    trades_csv = file.path(output_dir, "bridge_trades.csv"),
    report_md = file.path(output_dir, "bridge_daily_report.md"),
    contact_sheet_png = file.path(output_dir, "bridge_contact_sheet.png")
  )
  g5_wfa_write_csv(daily$operator_packet, paths$operator_packet_csv)
  g5_wfa_write_csv(daily$pending_actions, paths$pending_actions_csv)
  g5_wfa_write_csv(daily$book_summary, paths$book_summary_csv)
  g5_wfa_write_csv(daily$replay, paths$replay_csv)
  g5_wfa_write_csv(daily$executions, paths$executions_csv)
  g5_wfa_write_csv(daily$trades, paths$trades_csv)
  symbols <- names(daily$symbol_results)
  chart_paths <- character()
  for (symbol in symbols) {
    chart_path <- file.path(output_dir, paste0("bridge_chart_", symbol, ".png"))
    chart_replay <- g5_bridge_chart_replay(daily$symbol_results[[symbol]])
    grDevices::png(chart_path, width = 2200, height = 1200, res = 180)
    g5_bridge_plot_panel(
      chart_replay,
      daily$symbol_results[[symbol]]$executions,
      daily$symbol_results[[symbol]]$pending_actions,
      daily$symbol_results[[symbol]]$trades,
      main = paste0(symbol, " bridge replay")
    )
    grDevices::dev.off()
    chart_paths <- c(chart_paths, chart_path)
  }
  grDevices::png(paths$contact_sheet_png, width = 2600, height = 1800, res = 180)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(oldpar), add = TRUE)
  graphics::par(mfrow = c(ceiling(length(symbols) / 2), 2), mar = c(4, 4, 3, 1))
  for (symbol in symbols) {
    chart_replay <- g5_bridge_chart_replay(daily$symbol_results[[symbol]])
    g5_bridge_plot_panel(
      chart_replay,
      daily$symbol_results[[symbol]]$executions,
      daily$symbol_results[[symbol]]$pending_actions,
      daily$symbol_results[[symbol]]$trades,
      main = paste0(symbol, " bridge replay")
    )
  }
  grDevices::dev.off()
  pending_count <- if (is.data.frame(daily$pending_actions)) nrow(daily$pending_actions) else 0L
  lines <- c(
    paste0("# Gen5.1 Live Advice Bridge Daily Packet: ", daily$contract$quarter_id[[1L]]),
    "",
    "## Purpose",
    "",
    "This packet converts the frozen temporary Gen5.1 bridge authority into advice-only next-open signals. It is meant to keep manual daily operation fluid while the proper Gen5.1 production layer is still being built.",
    "",
    paste0("- As of timestamp: `", daily$as_of_timestamp, "`"),
    paste0("- Latest replay date: `", daily$as_of_date, "`"),
    paste0("- Pending next-open actions: `", pending_count, "`"),
    "",
    "## Artifacts",
    "",
    "- `bridge_operator_packet.csv`",
    "- `bridge_pending_actions.csv`",
    "- `bridge_book_summary.csv`",
    "- `bridge_replay.csv`",
    "- `bridge_executions.csv`",
    "- `bridge_trades.csv`",
    "- `bridge_contact_sheet.png`",
    "",
    "## Operator Guardrail",
    "",
    "These are advice-only artifacts. Review chart markers, pending action rows, and current model positions before any manual trade decision."
  )
  writeLines(lines, paths$report_md, useBytes = TRUE)
  paths$asset_chart_pngs <- chart_paths
  paths
}
