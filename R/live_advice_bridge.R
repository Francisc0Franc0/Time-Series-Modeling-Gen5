g5_live_bridge_schema_version <- function() {
  "gen5_live_advice_bridge_v0.1"
}

g5_live_bridge_code_version <- function() {
  "gen5_1_live_bridge_freeze_guard_v1"
}

g5_bridge_git_executable <- function() {
  candidates <- c(
    unname(Sys.which("git")),
    "C:/Program Files/Git/cmd/git.exe",
    "C:/Program Files/Git/bin/git.exe"
  )
  candidates <- candidates[nzchar(candidates)]
  existing <- candidates[file.exists(candidates)]
  if (!length(existing)) NA_character_ else existing[[1L]]
}

g5_bridge_git_output_or_na <- function(repo_root, args) {
  git <- g5_bridge_git_executable()
  if (!length(git) || is.na(git) || !nzchar(git)) return(NA_character_)
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = FALSE)
  value <- tryCatch(
    suppressWarnings(system2(git, c("-C", shQuote(repo_root), args), stdout = TRUE, stderr = FALSE)),
    error = function(e) NA_character_
  )
  if (!length(value)) return(NA_character_)
  value <- paste(as.character(value), collapse = "\n")
  if (!nzchar(value)) NA_character_ else value
}

g5_bridge_runtime_provenance <- function(
  repo_root,
  quarter_id = NA_character_,
  as_of_timestamp = NA_character_,
  selection_policy = NA_character_,
  selection_policy_label = NA_character_,
  authority_dir = NA_character_,
  previous_authority_dir = NA_character_
) {
  status <- g5_bridge_git_output_or_na(repo_root, c("status", "--porcelain"))
  dirty <- !is.na(status) && nzchar(status)
  data.frame(
    schema_version = g5_live_bridge_schema_version(),
    live_bridge_code_version = g5_live_bridge_code_version(),
    live_bridge_semantics = "frozen_gen5_1_authority_consumption",
    quarter_id = as.character(quarter_id),
    as_of_timestamp = as.character(as_of_timestamp),
    selection_policy = as.character(selection_policy),
    selection_policy_label = as.character(selection_policy_label),
    authority_dir = normalizePath(as.character(authority_dir), winslash = "/", mustWork = FALSE),
    previous_authority_dir = normalizePath(as.character(previous_authority_dir), winslash = "/", mustWork = FALSE),
    git_branch = g5_bridge_git_output_or_na(repo_root, c("rev-parse", "--abbrev-ref", "HEAD")),
    git_sha = g5_bridge_git_output_or_na(repo_root, c("rev-parse", "--short", "HEAD")),
    git_dirty = dirty,
    git_dirty_row_count = if (is.na(status) || !nzchar(status)) 0L else length(strsplit(status, "\n", fixed = TRUE)[[1L]]),
    stringsAsFactors = FALSE
  )
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
    "rsi_mr",
    "zret_mr",
    "breakout",
    "pullback_in_uptrend",
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

g5_bridge_previous_quarter_id <- function(quarter_id) {
  parsed <- g5_bridge_parse_quarter_id(quarter_id)
  year <- parsed$year
  quarter <- parsed$quarter - 1L
  if (quarter < 1L) {
    quarter <- 4L
    year <- year - 1L
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
  strategy_grid_preset = "gen4_daily_default"
) {
  strategy_grid_preset <- g5_wfa_strategy_grid_preset(strategy_grid_preset)
  candidate_families <- unique(c(g5_wfa_candidate_families(candidate_families), "no_trade"))
  args <- utils::modifyList(
    list(
      fast_periods = c(8L, 12L),
      slow_periods = c(30L, 50L),
      bb_lookback_periods = c(10L, 20L),
      bb_sd_multipliers = c(1.5, 2)
    ),
    g5_wfa_strategy_grid_preset_values(strategy_grid_preset)
  )
  args$candidate_families <- candidate_families
  do.call(g5_wfa_candidate_model_grid, args)
}

g5_bridge_contract_frame <- function(quarter_id, symbols, context_symbols = symbols, as_of_timestamp, refresh, git_sha = NA_character_, market_data_feed = NA_character_, candidate_families = g5_bridge_default_candidate_families(), strategy_grid_preset = "gen4_daily_default") {
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
  strategy_grid_preset = "gen4_daily_default",
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
  contract_keep <- rep(FALSE, nrow(contract))
  if ("research_candidate_symbol" %in% names(contract)) {
    contract_keep <- contract_keep | (!is.na(contract$research_candidate_symbol) & contract$research_candidate_symbol == symbol)
  }
  if ("symbol" %in% names(contract)) {
    contract_keep <- contract_keep | (!is.na(contract$symbol) & contract$symbol == symbol)
  }
  if (any(contract_keep)) {
    contract <- contract[contract_keep, , drop = FALSE]
  }
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
  meta_grid <- contract[contract$record_type == "meta" & contract$key %in% c("grid_n", "state_grid_n"), "value", drop = TRUE]
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

g5_bridge_model_param_summary <- function(row) {
  if (!is.data.frame(row) || !nrow(row)) return(NA_character_)
  param_cols <- c(
    "fast_period",
    "slow_period",
    "lookback_period",
    "sd_multiplier",
    "rsi_period",
    "rsi_lower",
    "rsi_upper",
    "zret_window",
    "zret_entry_z",
    "zret_exit_z",
    "breakout_lookback",
    "breakout_buffer",
    "vol_expand_threshold",
    "include_native_exit",
    "max_hold_sessions",
    "stop_loss_pct",
    "take_profit_pct"
  )
  pieces <- character()
  for (col in intersect(param_cols, names(row))) {
    value <- row[[col]][[1L]]
    if (length(value) == 0L || is.na(value)) next
    pieces <- c(pieces, paste0(col, "=", as.character(value)))
  }
  if (length(pieces)) paste(pieces, collapse = ";") else NA_character_
}

g5_bridge_entry_replay_semantics <- function(entry_replay_semantics = "fresh_signal_only") {
  value <- as.character(entry_replay_semantics)[[1L]]
  choices <- c("fresh_signal_only", "state_switch_continuation")
  if (!nzchar(value) || !value %in% choices) {
    g5_stop(paste0("entry_replay_semantics must be one of: ", paste(choices, collapse = ",")))
  }
  value
}

g5_bridge_continuation_signal_state <- function(ind, idx, selected_family) {
  selected_family <- as.character(selected_family)[[1L]]
  if (!"signal_state" %in% names(ind)) return(NA_character_)
  state <- as.character(ind$signal_state[[idx]])
  if (selected_family == "ema_cross" && identical(state, "fast_above")) return(state)
  if (selected_family == "ema_trend" && identical(state, "trend_on")) return(state)
  NA_character_
}

g5_bridge_replay_symbol <- function(
  bars,
  symbol,
  scored,
  selected_states,
  contract,
  allow_as_of_after_live_end = FALSE,
  replay_start_date = NULL,
  entry_signal_start_date = NULL,
  entry_signal_end_date = NULL,
  honor_pending_entry_execution_until = NULL,
  authority_role = "current",
  entry_replay_semantics = "fresh_signal_only",
  state_switch_continuation_families = c("ema_cross", "ema_trend"),
  initial_open_trade = NULL
) {
  entry_replay_semantics <- g5_bridge_entry_replay_semantics(entry_replay_semantics)
  state_switch_continuation_families <- unique(as.character(state_switch_continuation_families))
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  train_end_date <- as.Date(contract$train_end_date[[1L]])
  live_start_date <- as.Date(contract$live_start_date[[1L]])
  live_end_date <- as.Date(contract$live_end_date[[1L]])
  as_of_date <- max(as.Date(scored$session_date), na.rm = TRUE)
  if (as_of_date < live_start_date) {
    g5_stop("Daily bridge as_of date is before authority live_start_date.")
  }
  if (as_of_date > live_end_date && !isTRUE(allow_as_of_after_live_end)) {
    g5_stop("Daily bridge authority is expired for this as_of date.")
  }
  replay_start_date <- if (is.null(replay_start_date)) train_end_date else as.Date(replay_start_date)
  entry_signal_start_date <- if (is.null(entry_signal_start_date)) train_end_date else as.Date(entry_signal_start_date)
  entry_signal_end_date <- if (is.null(entry_signal_end_date)) as_of_date else as.Date(entry_signal_end_date)
  honor_pending_entry_execution_until <- if (is.null(honor_pending_entry_execution_until)) as_of_date else as.Date(honor_pending_entry_execution_until)
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

  signal_indices <- which(session_dates >= replay_start_date & session_dates <= as_of_date)
  rows <- list()
  executions <- list()
  pending_actions <- list()
  in_position <- FALSE
  open_trade <- NULL
  pending_entry <- NULL
  pending_exit <- NULL
  previous_selected_spec <- NA_character_
  if (is.data.frame(initial_open_trade) && nrow(initial_open_trade)) {
    seed <- initial_open_trade[1L, , drop = FALSE]
    seed_date <- as.Date(seed$entry_execution_date[[1L]])
    if (!is.na(seed_date)) {
      seed_idx <- suppressWarnings(max(which(session_dates <= seed_date)))
      if (!is.finite(seed_idx)) seed_idx <- signal_indices[[1L]]
      seed_state <- if ("entry_state_id" %in% names(seed) && nzchar(as.character(seed$entry_state_id[[1L]]))) {
        as.character(seed$entry_state_id[[1L]])
      } else {
        unname(state_lookup[[as.character(session_dates[[seed_idx]])]])
      }
      seed_spec <- as.character(seed$strategy_spec_id[[1L]])
      seed_selected <- selected_states[selected_states$strategy_spec_id == seed_spec, , drop = FALSE]
      if (!nrow(seed_selected) && !is.na(seed_state)) {
        seed_selected <- selected_states[selected_states$state_id == seed_state, , drop = FALSE]
      }
      if (!nrow(seed_selected)) {
        g5_stop(paste0("Initial open trade seed has no matching selected-state authority for ", symbol, ": ", seed_spec))
      }
      seed_selected <- seed_selected[1L, , drop = FALSE]
      seed_price <- if ("entry_execution_price" %in% names(seed)) suppressWarnings(as.numeric(seed$entry_execution_price[[1L]])) else NA_real_
      if (!is.finite(seed_price)) seed_price <- as.numeric(all_bars$close[[seed_idx]])
      open_trade <- list(
        entry_state_id = seed_state,
        strategy_family = as.character(seed_selected$strategy_family[[1L]]),
        model_instance_id = as.character(seed_selected$model_instance_id[[1L]]),
        exit_stack_id = as.character(seed_selected$exit_stack_id[[1L]]),
        strategy_spec_id = as.character(seed_selected$strategy_spec_id[[1L]]),
        signal_model_params = g5_bridge_model_param_summary(seed_selected),
        entry_signal_rule = "seeded_open_position_from_external_live_runner",
        entry_trigger_type = if ("entry_trigger_type" %in% names(seed)) as.character(seed$entry_trigger_type[[1L]]) else "external_seed_position",
        entry_replay_semantics = entry_replay_semantics,
        entry_signal_date = seed_date,
        entry_signal_idx = seed_idx,
        entry_signal_price = seed_price,
        entry_execution_idx = seed_idx,
        entry_execution_date = seed_date,
        entry_execution_price = seed_price,
        entry_execution_state_id = seed_state
      )
      in_position <- TRUE
      executions[[length(executions) + 1L]] <- data.frame(
        symbol = symbol,
        execution_date = seed_date,
        execution_type = "ENTER_LONG",
        execution_price = seed_price,
        strategy_spec_id = open_trade$strategy_spec_id,
        state_id = seed_state,
        entry_trigger_type = open_trade$entry_trigger_type,
        authority_quarter_id = as.character(contract$quarter_id[[1L]]),
        authority_role = as.character(authority_role),
        execution_source = "seeded_open_position_from_external_live_runner",
        stringsAsFactors = FALSE
      )
    }
  }

  for (idx in signal_indices) {
    current_date <- session_dates[[idx]]
    current_state <- unname(state_lookup[[as.character(current_date)]])
    if (is.null(current_state) || is.na(current_state)) current_state <- NA_character_
    action_today <- "NONE"
    execution_today <- "NONE"
    selected <- g5_bridge_latest_selected(selected_by_state, current_state)
    selected_family <- if (nrow(selected)) as.character(selected$strategy_family[[1L]]) else NA_character_
    selected_spec <- if (nrow(selected)) as.character(selected$strategy_spec_id[[1L]]) else NA_character_
    selected_params <- g5_bridge_model_param_summary(selected)
    selected_spec_changed <- nrow(selected) && !identical(selected_spec, previous_selected_spec)
    entry_trigger_today <- NA_character_

    if (!is.null(pending_entry) && identical(as.Date(pending_entry$execution_date), current_date) && !in_position && current_date >= live_start_date && current_date <= honor_pending_entry_execution_until) {
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
        entry_trigger_type = if (!is.null(open_trade$entry_trigger_type)) open_trade$entry_trigger_type else NA_character_,
        authority_quarter_id = as.character(contract$quarter_id[[1L]]),
        authority_role = as.character(authority_role),
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
        authority_quarter_id = as.character(contract$quarter_id[[1L]]),
        authority_role = as.character(authority_role),
        stringsAsFactors = FALSE
      )
      in_position <- FALSE
      open_trade <- NULL
      pending_exit <- NULL
    }

    next_idx <- idx + 1L
    has_next_session_in_data <- next_idx <= nrow(all_bars)
    next_session <- if (has_next_session_in_data) session_dates[[next_idx]] else as.Date(NA)

    can_emit_entry_signal <- current_date >= entry_signal_start_date && current_date <= entry_signal_end_date
    if (!in_position && is.null(pending_entry) && can_emit_entry_signal && nrow(selected) && !identical(selected_family, "no_trade") && !g5_wfa_is_force_exit_override(selected)) {
      ind <- indicator_cache[[selected_spec]]
      entry_signal_rule <- NA_character_
      entry_trigger_type <- NA_character_
      if (isTRUE(ind$entry_signal[[idx]])) {
        entry_signal_rule <- ind$entry_signal_rule[[idx]]
        entry_trigger_type <- "fresh_signal"
      } else if (
        identical(entry_replay_semantics, "state_switch_continuation") &&
          selected_spec_changed &&
          selected_family %in% state_switch_continuation_families
      ) {
        continuation_state <- g5_bridge_continuation_signal_state(ind, idx, selected_family)
        if (!is.na(continuation_state)) {
          entry_signal_rule <- paste0("state_switch_continuation_", continuation_state, "_when_flat")
          entry_trigger_type <- "state_switch_continuation"
        }
      }
      if (!is.na(entry_signal_rule)) {
        pending_entry <- list(
          entry_state_id = current_state,
          strategy_family = selected_family,
          model_instance_id = selected$model_instance_id[[1L]],
          exit_stack_id = selected$exit_stack_id[[1L]],
          strategy_spec_id = selected_spec,
          signal_model_params = selected_params,
          fast_period = g5_wfa_model_value(selected, "fast_period", NA_integer_),
          slow_period = g5_wfa_model_value(selected, "slow_period", NA_integer_),
          lookback_period = g5_wfa_model_value(selected, "lookback_period", NA_integer_),
          sd_multiplier = g5_wfa_model_value(selected, "sd_multiplier", NA_real_),
          entry_signal_rule = entry_signal_rule,
          entry_trigger_type = entry_trigger_type,
          entry_replay_semantics = entry_replay_semantics,
          entry_signal_date = current_date,
          entry_signal_idx = idx,
          entry_signal_price = as.numeric(all_bars$close[[idx]]),
          execution_date = next_session
        )
        entry_trigger_today <- entry_trigger_type
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
            signal_rule = entry_signal_rule,
            entry_trigger_type = entry_trigger_type,
            entry_replay_semantics = entry_replay_semantics,
            authority_quarter_id = as.character(contract$quarter_id[[1L]]),
            authority_role = as.character(authority_role),
            stringsAsFactors = FALSE
          )
        }
      }
    }

    if (in_position && is.null(pending_exit)) {
      if (g5_wfa_is_force_exit_override(selected)) {
        pending_exit <- list(
          primary_exit_reason = "state_exit_override",
          triggered_exit_rules = "force_exit_next_open",
          exit_attribution = "current_state_exit_override",
          exit_signal_rule = "state_exit_override_force_exit_next_open",
          exit_signal_state_id = current_state,
          exit_signal_date = current_date,
          exit_signal_idx = idx,
          exit_signal_price = as.numeric(all_bars$close[[idx]]),
          execution_date = next_session
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
            authority_quarter_id = as.character(contract$quarter_id[[1L]]),
            authority_role = as.character(authority_role),
            stringsAsFactors = FALSE
          )
        }
      } else {
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
            authority_quarter_id = as.character(contract$quarter_id[[1L]]),
            authority_role = as.character(authority_role),
            stringsAsFactors = FALSE
          )
        }
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
      selected_signal_model = selected_spec,
      selected_signal_params = selected_params,
      model_position_after_replay = if (in_position) "LONG" else "FLAT",
      execution_status = execution_today,
      signal_status = action_today,
      entry_trigger_type = entry_trigger_today,
      entry_replay_semantics = entry_replay_semantics,
      open_trade_strategy_spec_id = if (in_position && !is.null(open_trade)) open_trade$strategy_spec_id else NA_character_,
      open_trade_signal_params = if (in_position && !is.null(open_trade)) open_trade$signal_model_params else NA_character_,
      open_trade_entry_execution_date = if (in_position && !is.null(open_trade)) open_trade$entry_execution_date else as.Date(NA),
      authority_quarter_id = as.character(contract$quarter_id[[1L]]),
      authority_role = as.character(authority_role),
      stringsAsFactors = FALSE
    )
    previous_selected_spec <- selected_spec
  }
  replay <- if (length(rows)) g5_wfa_bind_rows_fill(rows) else data.frame()
  pending <- if (length(pending_actions)) g5_wfa_bind_rows_fill(pending_actions) else data.frame()
  executions <- if (length(executions)) g5_wfa_bind_rows_fill(executions) else data.frame()
  trades <- g5_bridge_trades_from_replay(replay, executions, as.Date(contract$live_end_date[[1L]]))
  latest <- if (nrow(replay)) replay[nrow(replay), , drop = FALSE] else data.frame()
  list(replay = replay, pending_actions = pending, executions = executions, trades = trades, latest = latest)
}

g5_bridge_score_authority_symbol <- function(bars, authority, symbol, as_of_date) {
  contract <- authority$contract[1L, , drop = FALSE]
  symbols <- g5_standardize_symbol(strsplit(contract$symbols[[1L]], ",", fixed = TRUE)[[1L]])
  context_symbols <- if ("context_symbols" %in% names(contract) && nzchar(as.character(contract$context_symbols[[1L]]))) {
    unique(g5_standardize_symbol(strsplit(contract$context_symbols[[1L]], ",", fixed = TRUE)[[1L]]))
  } else {
    symbols
  }
  feature_cols <- as.character(authority$pca_model_contract$feature[authority$pca_model_contract$record_type == "feature"])
  feature_cols <- feature_cols[nzchar(feature_cols) & !is.na(feature_cols)]
  features <- g5_pca_regime_pooled_feature_table(
    bars,
    target_symbol = symbol,
    context_symbols = context_symbols,
    end_date = as_of_date,
    feature_cols = feature_cols
  )
  g5_bridge_score_frozen_quantile(features, authority$pca_model_contract, symbol)
}

g5_bridge_first_flat_date_from_prior <- function(prior_replay, current_live_start_date) {
  if (!is.data.frame(prior_replay) || !nrow(prior_replay)) return(as.Date(current_live_start_date))
  prior_replay <- prior_replay[order(as.Date(prior_replay$session_date)), , drop = FALSE]
  current_live_start_date <- as.Date(current_live_start_date)
  after_start <- prior_replay[as.Date(prior_replay$session_date) >= current_live_start_date, , drop = FALSE]
  if (nrow(after_start) && identical(as.Date(after_start$session_date[[1L]]), current_live_start_date) && identical(as.character(after_start$model_position_after_replay[[1L]]), "LONG")) {
    flat_rows <- after_start[as.character(after_start$model_position_after_replay) == "FLAT", , drop = FALSE]
    if (!nrow(flat_rows)) return(as.Date(NA))
    return(as.Date(flat_rows$session_date[[1L]]))
  }
  pre_current <- prior_replay[as.Date(prior_replay$session_date) < current_live_start_date, , drop = FALSE]
  if (!nrow(pre_current)) return(as.Date(current_live_start_date))
  latest_pre_current <- pre_current[nrow(pre_current), , drop = FALSE]
  if (!identical(as.character(latest_pre_current$model_position_after_replay[[1L]]), "LONG")) {
    return(as.Date(current_live_start_date))
  }
  flat_rows <- after_start[as.character(after_start$model_position_after_replay) == "FLAT", , drop = FALSE]
  if (!nrow(flat_rows)) return(as.Date(NA))
  as.Date(flat_rows$session_date[[1L]])
}

g5_bridge_previous_executions_through_switch <- function(executions, current_start) {
  if (!is.data.frame(executions) || !nrow(executions)) return(data.frame())
  executions[as.Date(executions$execution_date) <= as.Date(current_start), , drop = FALSE]
}

g5_bridge_run_daily_continuity_from_bars <- function(bars, current_authority, previous_authority, as_of_timestamp) {
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
    previous_seed <- g5_bridge_seed_for_symbol(previous_authority, symbol)
    previous_replay_start <- if (!is.null(previous_seed)) as.Date(previous_seed$entry_execution_date[[1L]]) else as.Date(previous_contract$train_end_date[[1L]])
    previous_scored <- g5_bridge_score_authority_symbol(bars, previous_authority, symbol, current_as_of_date)
    previous_result <- g5_bridge_replay_symbol(
      bars,
      symbol,
      previous_scored,
      previous_authority$selected_states,
      previous_contract,
      allow_as_of_after_live_end = TRUE,
      replay_start_date = previous_replay_start,
      entry_signal_start_date = as.Date(previous_contract$train_end_date[[1L]]),
      entry_signal_end_date = previous_live_end,
      honor_pending_entry_execution_until = current_live_start,
      authority_role = "previous_continuity",
      initial_open_trade = previous_seed
    )

    current_start <- g5_bridge_first_flat_date_from_prior(previous_result$replay, current_live_start)
    if (is.na(current_start)) {
      chosen_replay <- previous_result$replay
      chosen_executions <- previous_result$executions
      chosen_pending <- previous_result$pending_actions
      chosen_scores <- previous_scored
      continuity_mode <- "previous_authority_open_trade_carry"
    } else {
      current_scored <- g5_bridge_score_authority_symbol(bars, current_authority, symbol, current_as_of_date)
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
      prior_exec_keep <- g5_bridge_previous_executions_through_switch(previous_result$executions, current_start)
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
  book <- latest[, c("symbol", "session_date", "close", "state_id", "selected_strategy_family", "selected_strategy_spec_id", "selected_signal_params", "model_position_after_replay", "signal_status", "execution_status", "open_trade_strategy_spec_id", "open_trade_signal_params", "open_trade_entry_execution_date"), drop = FALSE]
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

g5_bridge_read_authority <- function(authority_dir, include_train_state_performance = FALSE) {
  paths <- list(
    contract = file.path(authority_dir, "bridge_authority_contract.csv"),
    selected_states = file.path(authority_dir, "bridge_selected_states.csv"),
    pca_model_contract = file.path(authority_dir, "bridge_pca_model_contract.csv")
  )
  if (isTRUE(include_train_state_performance)) {
    paths$train_state_performance <- file.path(authority_dir, "bridge_train_state_performance.csv")
  }
  missing <- names(paths)[!file.exists(unlist(paths))]
  if (length(missing)) {
    g5_stop(paste0("Missing bridge authority artifact(s): ", paste(missing, collapse = ",")))
  }
  out <- list(
    authority_dir = normalizePath(authority_dir, winslash = "/", mustWork = FALSE),
    contract = utils::read.csv(paths$contract, stringsAsFactors = FALSE),
    selected_states = utils::read.csv(paths$selected_states, stringsAsFactors = FALSE),
    pca_model_contract = utils::read.csv(paths$pca_model_contract, stringsAsFactors = FALSE)
  )
  if (isTRUE(include_train_state_performance)) {
    out$train_state_performance <- utils::read.csv(paths$train_state_performance, stringsAsFactors = FALSE)
  }
  out
}

g5_bridge_label_frozen_direct_authority <- function(selected_states) {
  selected_states$selection_policy <- "asset_state_direct_spec"
  selected_states$selection_policy_recipe <- "gen5_1_frozen_bridge_selected_states"
  selected_states$live_bridge_authority_source <- "bridge_selected_states.csv"
  selected_states$live_bridge_code_version <- g5_live_bridge_code_version()
  if (!"pooled_selected_family" %in% names(selected_states)) selected_states$pooled_selected_family <- NA_character_
  if (!"pooled_family_mean_sharpe" %in% names(selected_states)) selected_states$pooled_family_mean_sharpe <- NA_real_
  if (!"pooled_family_mean_total_return" %in% names(selected_states)) selected_states$pooled_family_mean_total_return <- NA_real_
  if (!"pooled_family_asset_count" %in% names(selected_states)) selected_states$pooled_family_asset_count <- NA_integer_
  if (!"pooled_family_trade_count" %in% names(selected_states)) selected_states$pooled_family_trade_count <- NA_integer_
  if (!"pooled_family_n_variants" %in% names(selected_states)) selected_states$pooled_family_n_variants <- NA_integer_
  selected_states
}

g5_bridge_apply_live_selection_policy <- function(authority, selection_policy, min_train_state_rows = 20L) {
  out <- authority
  out$contract$selection_policy <- selection_policy
  out$contract$live_bridge_code_version <- g5_live_bridge_code_version()
  if (identical(selection_policy, "asset_state_direct_spec")) {
    out$contract$live_bridge_authority_source <- "bridge_selected_states.csv"
    out$contract$live_bridge_selection_guardrail <- "direct_lane_consumes_frozen_selected_states_without_recomputing_from_train_performance"
    out$selected_states <- g5_bridge_label_frozen_direct_authority(out$selected_states)
  } else if (identical(selection_policy, "pooled_family_asset_variant")) {
    if (!is.data.frame(out$train_state_performance) || !nrow(out$train_state_performance)) {
      g5_stop("Pooled-family live advice requires bridge_train_state_performance.csv in the authority packet.")
    }
    out$contract$live_bridge_authority_source <- "bridge_train_state_performance.csv"
    out$contract$live_bridge_selection_guardrail <- "pooled_family_lane_recomputed_from_frozen_train_performance_for_side_by_side_inspection"
    out$selected_states <- g5_selection_policy_pooled_family_asset_variant(
      out$train_state_performance,
      min_train_state_rows = min_train_state_rows
    )
  } else {
    g5_stop(paste0("Unsupported live advice selection policy: ", selection_policy))
  }
  out
}

g5_bridge_gen4_current_live_root <- function(repo_root) {
  override <- Sys.getenv("GEN5_BRIDGE_GEN4_CURRENT_LIVE_ROOT", unset = "")
  if (nzchar(override)) return(normalizePath(override, winslash = "/", mustWork = FALSE))
  sibling_root <- normalizePath(
    file.path(dirname(normalizePath(repo_root, winslash = "/", mustWork = FALSE)), "Time-Series-Modeling", "Experiments", "CURRENT_LIVE"),
    winslash = "/",
    mustWork = FALSE
  )
  if (dir.exists(sibling_root)) return(sibling_root)
  userprofile <- Sys.getenv("USERPROFILE", unset = "")
  if (nzchar(userprofile)) {
    onedrive_root <- normalizePath(
      file.path(userprofile, "OneDrive", "Documents", "Francis", "Peltata Project", "Time-Series-Modeling", "Experiments", "CURRENT_LIVE"),
      winslash = "/",
      mustWork = FALSE
    )
    if (dir.exists(onedrive_root)) return(onedrive_root)
  }
  sibling_root
}

g5_bridge_gen4_phase50_dir <- function(repo_root, quarter_id) {
  file.path(g5_bridge_gen4_current_live_root(repo_root), "Phase50_Quarterly_FreezePack", as.character(quarter_id))
}

g5_bridge_gen4_phase60_dir <- function(repo_root, quarter_id) {
  file.path(g5_bridge_gen4_current_live_root(repo_root), "Phase60_Daily_LiveRunner", as.character(quarter_id))
}

g5_bridge_gen4_strategy_family <- function(family) {
  family <- as.character(family)
  family[family == "bb_touch"] <- "bollinger_touch"
  family
}

g5_bridge_gen4_strategy_id <- function(family, strategy) {
  family <- g5_bridge_gen4_strategy_family(family)
  strategy <- as.character(strategy)
  out <- strategy
  ema <- grepl("^ema_cross_f[0-9]+_s[0-9]+$", strategy)
  out[ema] <- sub("^ema_cross_f([0-9]+)_s([0-9]+)$", "ema_cross_fast\\1_slow\\2", strategy[ema])
  trend <- grepl("^ema_trend_f[0-9]+_s[0-9]+$", strategy)
  out[trend] <- sub("^ema_trend_f([0-9]+)_s([0-9]+)$", "ema_trend_fast\\1_slow\\2", strategy[trend])
  bb <- family == "bollinger_touch" & grepl("^bb_touch_n[0-9]+_k", strategy)
  if (any(bb, na.rm = TRUE)) {
    bb_n <- as.integer(sub("^bb_touch_n([0-9]+)_k(.+)$", "\\1", strategy[bb]))
    bb_sd <- as.numeric(sub("^bb_touch_n([0-9]+)_k(.+)$", "\\2", strategy[bb]))
    out[bb] <- mapply(g5_bollinger_touch_strategy_id, bb_n, bb_sd, USE.NAMES = FALSE)
  }
  out[family == "no_trade"] <- "no_trade"
  out
}

g5_bridge_authority_from_gen4_phase50 <- function(phase50_dir, template_authority) {
  paths <- list(
    asset_map = file.path(phase50_dir, "phase50_asset_variant_map.csv"),
    quarter_contract = file.path(phase50_dir, "phase50_quarter_contract.csv"),
    state_model_contract = file.path(phase50_dir, "phase50_state_model_contract.csv")
  )
  missing <- names(paths)[!file.exists(unlist(paths))]
  if (length(missing)) {
    g5_stop(paste0("Missing Gen4 Phase50 artifact(s): ", paste(missing, collapse = ","), " in ", phase50_dir))
  }
  asset_map <- utils::read.csv(paths$asset_map, stringsAsFactors = FALSE)
  quarter_contract <- utils::read.csv(paths$quarter_contract, stringsAsFactors = FALSE)
  state_model_contract <- utils::read.csv(paths$state_model_contract, stringsAsFactors = FALSE)
  contract <- template_authority$contract[1L, , drop = FALSE]
  symbols <- g5_standardize_symbol(strsplit(contract$symbols[[1L]], ",", fixed = TRUE)[[1L]])
  keep <- g5_standardize_symbol(asset_map$asset) %in% symbols
  asset_map <- asset_map[keep, , drop = FALSE]
  if (!nrow(asset_map)) {
    g5_stop(paste0("Gen4 Phase50 asset map has no rows for bridge symbols in ", phase50_dir))
  }
  grid <- g5_bridge_model_grid(
    candidate_families = g5_bridge_default_candidate_families(),
    strategy_grid_preset = "gen4_daily_default"
  )
  asset_map$strategy_family <- g5_bridge_gen4_strategy_family(asset_map$family)
  asset_map$model_instance_id <- g5_bridge_gen4_strategy_id(asset_map$strategy_family, asset_map$strategy)
  bb_rows <- asset_map$strategy_family == "bollinger_touch"
  if (any(bb_rows, na.rm = TRUE)) {
    asset_map$model_instance_id[bb_rows] <- mapply(
      g5_bollinger_touch_strategy_id,
      as.integer(asset_map$x_param[bb_rows]),
      as.numeric(asset_map$y_param[bb_rows]),
      USE.NAMES = FALSE
    )
  }
  selected <- merge(asset_map, grid, by = c("strategy_family", "model_instance_id"), all.x = TRUE, sort = FALSE)
  selected$symbol <- g5_standardize_symbol(selected$asset)
  selected$quarter_id <- as.character(contract$quarter_id[[1L]])
  selected$state_id <- paste0("S", as.character(selected$state_id))
  selected$exit_stack_id <- ifelse(selected$strategy_family == "no_trade", "no_exit", "native_only")
  selected$strategy_spec_id <- ifelse(
    selected$strategy_family == "no_trade",
    "no_trade__no_exit",
    paste0(selected$model_instance_id, "__native_only")
  )
  selected$include_native_exit <- selected$strategy_family != "no_trade"
  selected$selection_policy <- "pooled_family_asset_variant"
  selected$selection_policy_recipe <- "gen4_phase50_asset_variant_map"
  selected$live_bridge_authority_source <- "Gen4 Phase50 phase50_asset_variant_map.csv"
  selected$live_bridge_code_version <- g5_live_bridge_code_version()
  selected$selection_reason <- "gen4_phase50_frozen_asset_variant"
  selected$train_state_row_count <- NA_integer_
  selected$train_state_trade_count <- NA_integer_
  selected$sharpe <- suppressWarnings(as.numeric(selected$variant_metric))
  selected$total_return <- NA_real_
  state_model_contract$record_type <- as.character(state_model_contract$record_type)
  if ("key" %in% names(state_model_contract)) {
    state_model_contract$key <- as.character(state_model_contract$key)
    state_model_contract$key[state_model_contract$key == "state_grid_n"] <- "grid_n"
  }
  contract$selection_policy <- "pooled_family_asset_variant"
  contract$live_bridge_authority_source <- normalizePath(phase50_dir, winslash = "/", mustWork = FALSE)
  contract$live_bridge_selection_guardrail <- "gen4_style_previous_continuity_consumes_actual_phase50_freeze_pack"
  contract$live_bridge_code_version <- g5_live_bridge_code_version()
  if ("phase50_schema_version" %in% names(quarter_contract)) {
    contract$gen4_phase50_schema_version <- as.character(quarter_contract$phase50_schema_version[[1L]])
  }
  list(
    authority_dir = normalizePath(phase50_dir, winslash = "/", mustWork = FALSE),
    contract = contract,
    selected_states = selected,
    pca_model_contract = state_model_contract,
    train_state_performance = data.frame()
  )
}

g5_bridge_seed_positions_from_gen4_phase60 <- function(phase60_dir, template_authority) {
  path <- file.path(phase60_dir, "phase60_operator_packet.csv")
  if (!file.exists(path)) return(data.frame())
  packet <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!nrow(packet) || !"asset" %in% names(packet)) return(data.frame())
  contract <- template_authority$contract[1L, , drop = FALSE]
  symbols <- g5_standardize_symbol(strsplit(contract$symbols[[1L]], ",", fixed = TRUE)[[1L]])
  exec_col <- if ("current_exec_pos" %in% names(packet)) "current_exec_pos" else if ("exec_pos" %in% names(packet)) "exec_pos" else ""
  if (!nzchar(exec_col)) return(data.frame())
  packet$symbol <- g5_standardize_symbol(packet$asset)
  packet <- packet[packet$symbol %in% symbols & suppressWarnings(as.numeric(packet[[exec_col]])) > 0, , drop = FALSE]
  if (!nrow(packet)) return(data.frame())
  packet$strategy_family <- g5_bridge_gen4_strategy_family(packet$chosen_family)
  packet$model_instance_id <- g5_bridge_gen4_strategy_id(packet$strategy_family, packet$chosen_strategy)
  bb_rows <- rep(FALSE, nrow(packet))
  if (all(c("x_param", "y_param") %in% names(packet))) {
    bb_rows <- packet$strategy_family == "bollinger_touch"
  }
  if (any(bb_rows, na.rm = TRUE)) {
    packet$model_instance_id[bb_rows] <- mapply(
      g5_bollinger_touch_strategy_id,
      as.integer(packet$x_param[bb_rows]),
      as.numeric(packet$y_param[bb_rows]),
      USE.NAMES = FALSE
    )
  }
  data.frame(
    symbol = packet$symbol,
    entry_execution_date = as.Date(packet$date),
    entry_execution_price = NA_real_,
    entry_state_id = paste0("S", as.character(packet$state_id)),
    strategy_family = packet$strategy_family,
    model_instance_id = packet$model_instance_id,
    exit_stack_id = ifelse(packet$strategy_family == "no_trade", "no_exit", "native_only"),
    strategy_spec_id = ifelse(packet$strategy_family == "no_trade", "no_trade__no_exit", paste0(packet$model_instance_id, "__native_only")),
    entry_trigger_type = "gen4_phase60_seed_position",
    seed_source = normalizePath(path, winslash = "/", mustWork = FALSE),
    stringsAsFactors = FALSE
  )
}

g5_bridge_seed_for_symbol <- function(authority, symbol) {
  if (is.null(authority$seed_positions) || !is.data.frame(authority$seed_positions) || !nrow(authority$seed_positions)) {
    return(NULL)
  }
  rows <- authority$seed_positions[g5_standardize_symbol(authority$seed_positions$symbol) == g5_standardize_symbol(symbol)[[1L]], , drop = FALSE]
  if (nrow(rows)) rows[1L, , drop = FALSE] else NULL
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
  candle_width <- 0.62
  graphics::segments(x0 = x, y0 = low, x1 = x, y1 = high, col = body_colors, lwd = 1.2)
  body_bottom <- pmin(open, close)
  body_top <- pmax(open, close)
  flat_body <- body_bottom == body_top
  if (any(!flat_body)) {
    graphics::rect(
      xleft = x[!flat_body] - candle_width / 2,
      ybottom = body_bottom[!flat_body],
      xright = x[!flat_body] + candle_width / 2,
      ytop = body_top[!flat_body],
      col = body_colors[!flat_body],
      border = body_colors[!flat_body]
    )
  }
  if (any(flat_body)) {
    graphics::segments(
      x0 = x[flat_body] - candle_width / 2,
      y0 = close[flat_body],
      x1 = x[flat_body] + candle_width / 2,
      y1 = close[flat_body],
      col = body_colors[flat_body],
      lwd = 2
    )
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

g5_bridge_chart_replay <- function(symbol_result, min_rows = 80L, chart_start_date = NULL, chart_end_date = NULL) {
  replay <- symbol_result$replay
  scores <- symbol_result$scores
  if (!is.null(chart_start_date) && is.data.frame(replay) && nrow(replay)) {
    chart_start_date <- as.Date(chart_start_date)
    chart_end_date <- if (is.null(chart_end_date)) max(as.Date(replay$session_date), na.rm = TRUE) else as.Date(chart_end_date)
    replay <- replay[as.Date(replay$session_date) >= chart_start_date & as.Date(replay$session_date) <= chart_end_date, , drop = FALSE]
    if (nrow(replay)) return(replay)
  }
  if (!is.data.frame(scores) || !nrow(scores)) {
    return(replay)
  }
  if (is.data.frame(replay) && nrow(replay) >= min_rows) {
    return(replay)
  }
  if (!is.null(chart_start_date)) {
    chart_start_date <- as.Date(chart_start_date)
    chart_end_date <- if (is.null(chart_end_date)) max(as.Date(scores$session_date), na.rm = TRUE) else as.Date(chart_end_date)
    keep <- which(as.Date(scores$session_date) >= chart_start_date & as.Date(scores$session_date) <= chart_end_date)
    if (!length(keep)) keep <- tail(seq_len(nrow(scores)), min_rows)
  } else {
    keep <- tail(seq_len(nrow(scores)), min_rows)
  }
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
    selected_signal_model = NA_character_,
    selected_signal_params = NA_character_,
    model_position_after_replay = NA_character_,
    execution_status = "NONE",
    signal_status = "NONE",
    open_trade_strategy_spec_id = NA_character_,
    open_trade_signal_params = NA_character_,
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

g5_bridge_write_daily_outputs <- function(daily, output_dir, chart_lookback_days = 90L) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- list(
    operator_packet_csv = file.path(output_dir, "bridge_operator_packet.csv"),
    pending_actions_csv = file.path(output_dir, "bridge_pending_actions.csv"),
    book_summary_csv = file.path(output_dir, "bridge_book_summary.csv"),
    replay_csv = file.path(output_dir, "bridge_replay.csv"),
    executions_csv = file.path(output_dir, "bridge_executions.csv"),
    trades_csv = file.path(output_dir, "bridge_trades.csv"),
    continuity_csv = file.path(output_dir, "bridge_continuity.csv"),
    runtime_provenance_csv = file.path(output_dir, "bridge_runtime_provenance.csv"),
    report_md = file.path(output_dir, "bridge_daily_report.md"),
    contact_sheet_png = file.path(output_dir, "bridge_contact_sheet.png")
  )
  g5_wfa_write_csv(daily$operator_packet, paths$operator_packet_csv)
  g5_wfa_write_csv(daily$pending_actions, paths$pending_actions_csv)
  g5_wfa_write_csv(daily$book_summary, paths$book_summary_csv)
  g5_wfa_write_csv(daily$replay, paths$replay_csv)
  g5_wfa_write_csv(daily$executions, paths$executions_csv)
  g5_wfa_write_csv(daily$trades, paths$trades_csv)
  if (!is.null(daily$continuity)) g5_wfa_write_csv(daily$continuity, paths$continuity_csv)
  if (!is.null(daily$runtime_provenance)) g5_wfa_write_csv(daily$runtime_provenance, paths$runtime_provenance_csv)
  symbols <- names(daily$symbol_results)
  chart_paths <- character()
  packet_label <- if (!is.null(daily$selection_policy_label) && nzchar(as.character(daily$selection_policy_label))) {
    as.character(daily$selection_policy_label)
  } else {
    "Gen5.1 live advice bridge"
  }
  chart_lookback_days <- as.integer(chart_lookback_days)
  if (is.na(chart_lookback_days) || chart_lookback_days < 1L) chart_lookback_days <- 90L
  chart_start_date <- as.Date(daily$as_of_date) - chart_lookback_days
  for (symbol in symbols) {
    chart_path <- file.path(output_dir, paste0("bridge_chart_", symbol, ".png"))
    chart_replay <- g5_bridge_chart_replay(daily$symbol_results[[symbol]], chart_start_date = chart_start_date, chart_end_date = daily$as_of_date)
    grDevices::png(chart_path, width = 2200, height = 1200, res = 180)
    g5_bridge_plot_panel(
      chart_replay,
      daily$symbol_results[[symbol]]$executions,
      daily$symbol_results[[symbol]]$pending_actions,
      daily$symbol_results[[symbol]]$trades,
      main = paste0(symbol, " - ", packet_label)
    )
    grDevices::dev.off()
    chart_paths <- c(chart_paths, chart_path)
  }
  grDevices::png(paths$contact_sheet_png, width = 2600, height = 1800, res = 180)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(oldpar), add = TRUE)
  graphics::par(mfrow = c(ceiling(length(symbols) / 2), 2), mar = c(4, 4, 3, 1))
  for (symbol in symbols) {
    chart_replay <- g5_bridge_chart_replay(daily$symbol_results[[symbol]], chart_start_date = chart_start_date, chart_end_date = daily$as_of_date)
    g5_bridge_plot_panel(
      chart_replay,
      daily$symbol_results[[symbol]]$executions,
      daily$symbol_results[[symbol]]$pending_actions,
      daily$symbol_results[[symbol]]$trades,
      main = paste0(symbol, " - ", packet_label)
    )
  }
  grDevices::dev.off()
  pending_count <- if (is.data.frame(daily$pending_actions)) nrow(daily$pending_actions) else 0L
  continuity_lines <- character()
  if (!is.null(daily$continuity) && is.data.frame(daily$continuity) && nrow(daily$continuity)) {
    continuity_lines <- c(
      "",
      "## Quarter Continuity",
      "",
      paste0("- Previous authority: `", daily$previous_contract$quarter_id[[1L]], "`"),
      paste0("- Current authority: `", daily$contract$quarter_id[[1L]], "`"),
      paste0("- Chart window: `", chart_start_date, "` through `", daily$as_of_date, "`"),
      "",
      unlist(lapply(seq_len(nrow(daily$continuity)), function(i) {
        row <- daily$continuity[i, , drop = FALSE]
        paste0(
          "- `", row$symbol[[1L]], "`: `", row$continuity_mode[[1L]], "`; current authority starts `",
          row$current_authority_start_date[[1L]], "`"
        )
      }))
    )
  }
  model_lines <- character()
  book <- daily$book_summary
  if (is.data.frame(book) && nrow(book)) {
    model_lines <- unlist(lapply(seq_len(nrow(book)), function(i) {
      row <- book[i, , drop = FALSE]
      state_model <- paste0(
        "- `", row$symbol[[1L]], "` state `", row$state_id[[1L]], "` selects `",
        row$selected_strategy_spec_id[[1L]], "`",
        if (!is.na(row$selected_signal_params[[1L]]) && nzchar(row$selected_signal_params[[1L]])) paste0(" (", row$selected_signal_params[[1L]], ")") else ""
      )
      trade_model <- if (!is.na(row$open_trade_strategy_spec_id[[1L]]) && nzchar(row$open_trade_strategy_spec_id[[1L]])) {
        paste0(
          "  Open trade locked to `", row$open_trade_strategy_spec_id[[1L]], "`",
          if (!is.na(row$open_trade_signal_params[[1L]]) && nzchar(row$open_trade_signal_params[[1L]])) paste0(" (", row$open_trade_signal_params[[1L]], ")") else ""
        )
      } else {
        "  No open trade model lock."
      }
      c(state_model, trade_model)
    }))
  }
  lines <- c(
    paste0("# Gen5.1 Live Advice Bridge Daily Packet: ", daily$contract$quarter_id[[1L]], " - ", packet_label),
    "",
    "## Purpose",
    "",
    "This packet converts the frozen temporary Gen5.1 bridge authority into advice-only next-open signals. It is meant to keep manual daily operation fluid while the proper Gen5.1 production layer is still being built.",
    "",
    paste0("- As of timestamp: `", daily$as_of_timestamp, "`"),
    paste0("- Latest replay date: `", daily$as_of_date, "`"),
    paste0("- Pending next-open actions: `", pending_count, "`"),
    paste0("- Live bridge code version: `", g5_live_bridge_code_version(), "`"),
    "",
    "## Current Model Readout",
    "",
    model_lines,
    continuity_lines,
    "",
    "## Artifacts",
    "",
    "- `bridge_operator_packet.csv`",
    "- `bridge_pending_actions.csv`",
    "- `bridge_book_summary.csv`",
    "- `bridge_replay.csv`",
    "- `bridge_executions.csv`",
    "- `bridge_trades.csv`",
    "- `bridge_continuity.csv`",
    "- `bridge_runtime_provenance.csv`",
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
