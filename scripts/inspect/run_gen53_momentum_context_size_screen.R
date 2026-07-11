# Gen5.3 bullish momentum context-size specialist screen.
#
# This screen asks whether a narrowed PCA-routed, momentum-only hypothesis set
# can improve high-beta upside participation when feature design and context
# universe size/composition are varied together.

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

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) {
    Sys.sleep(0.5)
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(path)) {
    g5_stop(paste0("Could not create required output directory: ", normalizePath(path, winslash = "/", mustWork = FALSE)))
  }
  invisible(path)
}

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
feed <- env_or("GEN5_GEN53_MOM_CTX_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN53_MOM_CTX_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN53_MOM_CTX_STAMP", "20260710ctxsize"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen53_momentum_context_size", paste0("g53_momctx_", stamp))
ensure_dir(output_dir)
reuse_auth_root <- env_or("GEN5_GEN53_MOM_CTX_REUSE_AUTH_ROOT", "")
if (nzchar(reuse_auth_root)) {
  reuse_auth_root <- normalizePath(reuse_auth_root, winslash = "/", mustWork = FALSE)
}

selection_policies <- c("pooled_family_asset_variant")
entry_replay_semantics <- c("fresh_signal_only", "state_switch_continuation")
annual_replay_mode <- env_or("GEN5_GEN53_MOM_CTX_ANNUAL_REPLAY_MODE", "quarter_continuity_replay")
annual_replay_choices <- c("quarter_independent_stitch", "quarter_continuity_replay")
if (!annual_replay_mode %in% annual_replay_choices) {
  g5_stop(paste0("GEN5_GEN53_MOM_CTX_ANNUAL_REPLAY_MODE must be one of: ", paste(annual_replay_choices, collapse = ",")))
}
min_train_state_rows <- 20L
warmup_days <- 420L
grid_n <- 3L
initial_capital <- as.numeric(env_or("GEN5_GEN53_MOM_CTX_INITIAL_CAPITAL", "100000"))
strategy_grid_preset <- g5_wfa_strategy_grid_preset(env_or("GEN5_GEN53_MOM_CTX_STRATEGY_GRID_PRESET", "gen4_daily_default"))
candidate_families <- g5_wfa_candidate_families(split_csv(env_or(
  "GEN5_GEN53_MOM_CTX_CANDIDATE_FAMILIES",
  "ema_cross,ema_trend,no_trade,no_trade_exit_immediate"
)))
candidate_families <- unique(c(candidate_families, "no_trade", "no_trade_exit_immediate"))
strategy_pool_id <- env_or("GEN5_GEN53_MOM_CTX_STRATEGY_POOL_ID", "ema_only_momentum_specialist")
strategy_pool_label <- env_or("GEN5_GEN53_MOM_CTX_STRATEGY_POOL_LABEL", "EMA-only momentum specialist")

windows <- data.frame(
  window_id = c("2019Y_asof_20191231", "2020Y_asof_20201231", "2022Y_asof_20221231", "2024Y_asof_20241231"),
  quarter_ids = c("2019Q1,2019Q2,2019Q3,2019Q4", "2020Q1,2020Q2,2020Q3,2020Q4", "2022Q1,2022Q2,2022Q3,2022Q4", "2024Q1,2024Q2,2024Q3,2024Q4"),
  as_of_timestamp = c("2019-12-31 17:30:00", "2020-12-31 17:30:00", "2022-12-31 17:30:00", "2024-12-31 17:30:00"),
  regime_label = c("pre_covid_late_cycle", "covid_crash_rebound", "rate_shock_drawdown", "ai_high_beta_momentum"),
  stringsAsFactors = FALSE
)

live_symbols <- unique_symbols(c("AMD", "NVDA", "TSLA", "MSTR", "AVGO"))
context_recipes <- list(
  list(
    context_id = "hb_self_5",
    context_label = "High-beta self only",
    context_recipe = "live_basket_only",
    context_symbols = live_symbols,
    interpretation_note = "Smallest context: tests whether the live basket alone can define useful momentum states."
  ),
  list(
    context_id = "hb_peer_12",
    context_label = "High-beta peer context",
    context_recipe = "live_plus_high_beta_peers",
    context_symbols = with_context(live_symbols, c("MU", "QCOM", "META", "NFLX", "SMH", "SOXX", "IYW")),
    interpretation_note = "Like-for-like context: tests whether high-beta peers improve state discrimination without defensive macro assets."
  ),
  list(
    context_id = "hb_risk_aware_18",
    context_label = "High-beta risk-aware context",
    context_recipe = "live_plus_high_beta_peers_plus_macro_risk",
    context_symbols = with_context(live_symbols, c("MU", "QCOM", "META", "NFLX", "SMH", "SOXX", "IYW", "SPY", "QQQ", "IWM", "TLT", "GLD")),
    interpretation_note = "Gen4-memory context: tests whether a larger, more diverse but still momentum-relevant pool improves PCA states."
  )
)
feature_recipes <- list(
  list(
    feature_set_id = "workhorse_enriched",
    feature_set_label = "Workhorse enriched",
    feature_cols = g5_pca_regime_feature_set("workhorse_enriched"),
    feature_note = "Control surface: trend, stretch, volatility, chop, efficiency, and return-shape descriptors."
  ),
  list(
    feature_set_id = "momentum_participation",
    feature_set_label = "Momentum participation",
    feature_cols = g5_pca_regime_feature_set("momentum_participation"),
    feature_note = "Bullish-participation surface: trend strength, return impulse, persistence, range location, drawdown, and recovery."
  ),
  list(
    feature_set_id = "momentum_plus_stress",
    feature_set_label = "Momentum plus stress",
    feature_cols = g5_pca_regime_feature_set("momentum_plus_stress"),
    feature_note = "Momentum surface with volatility/range/stress descriptors added back."
  ),
  list(
    feature_set_id = "market_relative_momentum",
    feature_set_label = "Market-relative momentum",
    feature_cols = g5_pca_regime_feature_set("market_relative_momentum"),
    feature_note = "Compact trend surface meant to let pooled PCA compare return, anchor distance, persistence, and drawdown posture across the context pool."
  )
)
screen_specs <- list()
for (context in context_recipes) {
  for (feature in feature_recipes) {
    screen_specs[[length(screen_specs) + 1L]] <- c(
      list(
        screen_id = paste(context$context_id, feature$feature_set_id, sep = "__"),
        screen_label = paste(context$context_label, feature$feature_set_label, sep = " / "),
        basket_archetype = "high_beta_long_history",
        context_id = context$context_id,
        context_label = context$context_label,
        context_recipe = context$context_recipe,
        symbols = live_symbols,
        context_symbols = context$context_symbols,
        interpretation_note = paste(context$interpretation_note, feature$feature_note)
      ),
      feature[c("feature_set_id", "feature_set_label", "feature_cols", "feature_note")]
    )
  }
}

only_screens <- split_csv(env_or("GEN5_GEN53_MOM_CTX_ONLY", ""))
if (length(only_screens)) {
  screen_specs <- Filter(function(x) x$screen_id %in% only_screens, screen_specs)
  if (!length(screen_specs)) g5_stop("GEN5_GEN53_MOM_CTX_ONLY did not match any configured screen_id.")
}
window_override <- split_csv(env_or("GEN5_GEN53_MOM_CTX_WINDOWS", ""))
if (length(window_override)) {
  windows <- windows[
    windows$window_id %in% window_override |
      vapply(windows$quarter_ids, function(x) any(split_csv(x) %in% window_override), logical(1L)),
    ,
    drop = FALSE
  ]
  if (!nrow(windows)) g5_stop("GEN5_GEN53_MOM_CTX_WINDOWS did not match any configured window.")
}
assessment_quarters <- unique(unlist(lapply(windows$quarter_ids, split_csv), use.names = FALSE))
data_floor <- as.Date(env_or("GEN5_GEN53_MOM_CTX_DATA_FLOOR", "2016-01-04"))
score_cache <- new.env(parent = emptyenv())

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

build_symbol_fit_checkpoint <- function(bars, symbol, contract, model_grid, context_symbols, authority_dir, feature_cols) {
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
    min_train_state_rows = min_train_state_rows,
    feature_cols = feature_cols
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
  ensure_dir(authority_dir)
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
  if (!isTRUE(refresh) && nzchar(reuse_auth_root)) {
    reuse_dir <- file.path(reuse_auth_root, spec$screen_id, "auth", quarter_id)
    if (file.exists(file.path(reuse_dir, "bridge_authority_contract.csv")) &&
        file.exists(file.path(reuse_dir, "bridge_selected_states.csv")) &&
        file.exists(file.path(reuse_dir, "bridge_train_state_performance.csv"))) {
      message("Reuse authority from prior packet: ", spec$screen_id, " / ", quarter_id)
      authority <- read_full_authority_packet(reuse_dir)
      write_authority_packet(authority, authority_dir)
      return(authority)
    }
  }
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
  contract$research_note <- "Gen5.3 momentum context-size specialist screen: behavioral-pool PCA, 3x3 quantile states, high-beta live basket, feature-set and context-size axes, EMA-only momentum candidate families plus no-trade controls, live-capital portfolio replay."
  contract$grid_n <- grid_n
  contract$selection_policy <- "base_direct_authority"
  contract$feature_set_id <- spec$feature_set_id
  contract$feature_set_label <- spec$feature_set_label
  contract$feature_cols <- paste(spec$feature_cols, collapse = ",")
  model_grid <- g5_bridge_model_grid(candidate_families = candidate_families, strategy_grid_preset = strategy_grid_preset)
  fits <- lapply(spec$symbols, function(symbol) {
    build_symbol_fit_checkpoint(bars, symbol, contract, model_grid, spec$context_symbols, authority_dir, spec$feature_cols)
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

score_authority_symbol_cached <- function(bars, authority, symbol, as_of_date, screen_id, cache_env = score_cache) {
  contract <- authority$contract[1L, , drop = FALSE]
  key <- paste(
    screen_id,
    as.character(contract$quarter_id[[1L]]),
    if ("feature_set_id" %in% names(contract)) as.character(contract$feature_set_id[[1L]]) else "feature_set_unknown",
    g5_standardize_symbol(symbol)[[1L]],
    as.character(as.Date(as_of_date)),
    sep = "|"
  )
  if (exists(key, envir = cache_env, inherits = FALSE)) {
    return(get(key, envir = cache_env, inherits = FALSE))
  }
  scored <- g5_bridge_score_authority_symbol(bars, authority, symbol, as.Date(as_of_date))
  assign(key, scored, envir = cache_env)
  scored
}

replay_symbol_oos <- function(bars, authority, symbol, as_of_date, entry_semantics, lane_id, screen_id, window_id, feature_set_id) {
  scored <- score_authority_symbol_cached(bars, authority, symbol, as_of_date, screen_id)
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
    authority_role = paste0("gen53_momentum_context_size_", lane_id),
    entry_replay_semantics = entry_semantics
  )
  for (field in c("replay", "executions", "trades", "pending_actions")) {
    if (is.data.frame(out[[field]]) && nrow(out[[field]])) {
      out[[field]]$screen_id <- screen_id
      out[[field]]$window_id <- window_id
      out[[field]]$lane_id <- lane_id
      out[[field]]$feature_set_id <- feature_set_id
      out[[field]]$selection_policy <- as.character(authority$contract$selection_policy[[1L]])
      out[[field]]$entry_replay_semantics <- entry_semantics
      out[[field]]$annual_replay_mode <- "quarter_independent_stitch"
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

first_symbol_session_on_or_after <- function(bars, symbol, date, max_date) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  dates <- sort(unique(as.Date(bars$session_date[g5_standardize_symbol(bars$symbol) == symbol])))
  dates <- dates[dates >= as.Date(date) & dates <= as.Date(max_date)]
  if (length(dates)) dates[[1L]] else as.Date(max_date)
}

annotate_symbol_result <- function(out, authority, screen_id, window_id, lane_id, feature_set_id, entry_semantics, replay_mode) {
  contract <- authority$contract[1L, , drop = FALSE]
  for (field in c("replay", "replay_oos", "executions", "trades", "pending_actions")) {
    if (is.data.frame(out[[field]]) && nrow(out[[field]])) {
      out[[field]]$screen_id <- screen_id
      out[[field]]$window_id <- window_id
      out[[field]]$lane_id <- lane_id
      out[[field]]$feature_set_id <- feature_set_id
      out[[field]]$selection_policy <- as.character(contract$selection_policy[[1L]])
      out[[field]]$entry_replay_semantics <- entry_semantics
      out[[field]]$annual_replay_mode <- replay_mode
    }
  }
  out
}

quarter_contract_bounds <- function(authority) {
  contract <- authority$contract[1L, , drop = FALSE]
  data.frame(
    quarter_id = as.character(contract$quarter_id[[1L]]),
    live_start_date = as.Date(contract$live_start_date[[1L]]),
    live_end_date = as.Date(contract$live_end_date[[1L]]),
    stringsAsFactors = FALSE
  )
}

replay_symbol_annual_continuity <- function(bars, authorities, symbol, as_of_date, entry_semantics, lane_id, screen_id, window_id, feature_set_id) {
  if (!length(authorities)) return(list(replay = data.frame(), replay_oos = data.frame(), executions = data.frame(), trades = data.frame(), pending_actions = data.frame(), latest = data.frame(), continuity = data.frame()))
  bounds <- do.call(rbind, lapply(authorities, quarter_contract_bounds))
  bounds <- bounds[order(bounds$live_start_date), , drop = FALSE]
  authorities <- authorities[match(bounds$quarter_id, names(authorities))]
  names(authorities) <- bounds$quarter_id
  as_of_date <- as.Date(as_of_date)
  annual_start <- bounds$live_start_date[[1L]]
  segment_start <- annual_start
  replay_rows <- list()
  execution_rows <- list()
  pending_rows <- list()
  continuity_rows <- list()

  while (segment_start <= as_of_date) {
    active_idx <- which(bounds$live_end_date >= segment_start)
    active_idx <- active_idx[active_idx >= 1L]
    if (!length(active_idx)) break
    i <- active_idx[[1L]]
    authority <- authorities[[i]]
    contract <- authority$contract[1L, , drop = FALSE]
    quarter_id <- as.character(contract$quarter_id[[1L]])
    quarter_end <- min(as.Date(contract$live_end_date[[1L]]), as_of_date)
    if (segment_start > quarter_end && i < nrow(bounds)) {
      segment_start <- max(segment_start, bounds$live_start_date[[i + 1L]])
      next
    }

    next_start <- if (i < nrow(bounds)) bounds$live_start_date[[i + 1L]] else as.Date(NA)
    honor_until <- if (!is.na(next_start)) {
      first_symbol_session_on_or_after(bars, symbol, next_start, as_of_date)
    } else {
      as_of_date
    }
    scored <- score_authority_symbol_cached(bars, authority, symbol, as_of_date, screen_id)
    result <- g5_bridge_replay_symbol(
      bars,
      symbol,
      scored,
      authority$selected_states,
      contract,
      allow_as_of_after_live_end = TRUE,
      replay_start_date = segment_start,
      entry_signal_start_date = segment_start,
      entry_signal_end_date = quarter_end,
      honor_pending_entry_execution_until = honor_until,
      authority_role = paste0("gen53_momentum_context_size_continuity_", lane_id),
      entry_replay_semantics = entry_semantics
    )

    if (i >= nrow(bounds) || is.na(next_start) || next_start > as_of_date) {
      keep_replay <- result$replay[as.Date(result$replay$session_date) >= segment_start & as.Date(result$replay$session_date) <= as_of_date, , drop = FALSE]
      keep_exec <- result$executions
      replay_rows[[length(replay_rows) + 1L]] <- keep_replay
      execution_rows[[length(execution_rows) + 1L]] <- keep_exec
      pending_rows[[length(pending_rows) + 1L]] <- result$pending_actions
      continuity_rows[[length(continuity_rows) + 1L]] <- data.frame(
        symbol = g5_standardize_symbol(symbol)[[1L]],
        authority_quarter_id = quarter_id,
        next_quarter_id = NA_character_,
        boundary_date = as.Date(NA),
        continuity_mode = "final_authority_to_as_of",
        current_authority_start_date = segment_start,
        stringsAsFactors = FALSE
      )
      break
    }

    switch_date <- g5_bridge_first_flat_date_from_prior(result$replay, next_start)
    if (is.na(switch_date)) {
      keep_replay <- result$replay[as.Date(result$replay$session_date) >= segment_start & as.Date(result$replay$session_date) <= as_of_date, , drop = FALSE]
      replay_rows[[length(replay_rows) + 1L]] <- keep_replay
      execution_rows[[length(execution_rows) + 1L]] <- result$executions
      pending_rows[[length(pending_rows) + 1L]] <- result$pending_actions
      continuity_rows[[length(continuity_rows) + 1L]] <- data.frame(
        symbol = g5_standardize_symbol(symbol)[[1L]],
        authority_quarter_id = quarter_id,
        next_quarter_id = bounds$quarter_id[[i + 1L]],
        boundary_date = next_start,
        continuity_mode = "prior_authority_open_trade_carry_through_as_of",
        current_authority_start_date = as.Date(NA),
        stringsAsFactors = FALSE
      )
      break
    }

    keep_replay <- result$replay[as.Date(result$replay$session_date) >= segment_start & as.Date(result$replay$session_date) < switch_date, , drop = FALSE]
    keep_exec <- g5_bridge_previous_executions_through_switch(result$executions, switch_date)
    replay_rows[[length(replay_rows) + 1L]] <- keep_replay
    execution_rows[[length(execution_rows) + 1L]] <- keep_exec
    continuity_rows[[length(continuity_rows) + 1L]] <- data.frame(
      symbol = g5_standardize_symbol(symbol)[[1L]],
      authority_quarter_id = quarter_id,
      next_quarter_id = bounds$quarter_id[[i + 1L]],
      boundary_date = next_start,
      continuity_mode = if (switch_date > next_start) "prior_authority_until_flat_then_active_quarter" else "next_authority_from_quarter_start",
      current_authority_start_date = switch_date,
      stringsAsFactors = FALSE
    )
    segment_start <- switch_date
  }

  replay <- g5_wfa_bind_rows_fill(replay_rows)
  executions <- g5_wfa_bind_rows_fill(execution_rows)
  pending <- g5_wfa_bind_rows_fill(pending_rows)
  if (is.data.frame(replay) && nrow(replay)) replay <- replay[order(as.Date(replay$session_date)), , drop = FALSE]
  if (is.data.frame(executions) && nrow(executions)) executions <- executions[order(as.Date(executions$execution_date)), , drop = FALSE]
  trades <- g5_bridge_trades_from_replay(replay, executions, as_of_date)
  latest <- if (is.data.frame(replay) && nrow(replay)) replay[nrow(replay), , drop = FALSE] else data.frame()
  out <- list(
    replay = replay,
    replay_oos = replay,
    executions = executions,
    trades = trades,
    pending_actions = pending,
    latest = latest,
    continuity = g5_wfa_bind_rows_fill(continuity_rows)
  )
  annotate_symbol_result(out, authorities[[length(authorities)]], screen_id, window_id, lane_id, feature_set_id, entry_semantics, "quarter_continuity_replay")
}

combine_symbol_results <- function(pieces) {
  pieces <- Filter(function(x) is.list(x) && is.data.frame(x$replay_oos) && nrow(x$replay_oos), pieces)
  if (!length(pieces)) return(list(replay = data.frame(), replay_oos = data.frame(), executions = data.frame(), trades = data.frame(), pending_actions = data.frame(), latest = data.frame()))
  replay <- g5_wfa_bind_rows_fill(lapply(pieces, function(x) x$replay))
  replay_oos <- g5_wfa_bind_rows_fill(lapply(pieces, function(x) x$replay_oos))
  executions <- g5_wfa_bind_rows_fill(lapply(pieces, function(x) x$executions))
  trades <- g5_wfa_bind_rows_fill(lapply(pieces, function(x) x$trades))
  pending_actions <- g5_wfa_bind_rows_fill(lapply(pieces, function(x) x$pending_actions))
  replay <- replay[order(as.Date(replay$session_date)), , drop = FALSE]
  replay_oos <- replay_oos[order(as.Date(replay_oos$session_date)), , drop = FALSE]
  latest <- if (nrow(replay_oos)) replay_oos[nrow(replay_oos), , drop = FALSE] else data.frame()
  list(
    replay = replay,
    replay_oos = replay_oos,
    executions = executions,
    trades = trades,
    pending_actions = pending_actions,
    latest = latest
  )
}

accounting_trade_table <- function(trades, symbol, lane_id, screen_id, window_id, replay_mode) {
  if (!is.data.frame(trades) || !nrow(trades)) return(trades)
  trades$trade_id <- paste(
    "gen53momctx",
    screen_id,
    window_id,
    replay_mode,
    lane_id,
    g5_standardize_symbol(symbol)[[1L]],
    seq_len(nrow(trades)),
    sep = "_"
  )
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

summarize_accounting <- function(screen_id, basket_archetype, context_id, context_label, context_recipe, feature_set_id, feature_set_label, window, lane_id, policy, semantics, replay_mode, accounting, initial_capital) {
  metrics <- g5_portfolio_poc_metrics(accounting$equity, initial_capital)
  baseline_metrics <- g5_portfolio_poc_baseline_metrics(accounting$baselines, initial_capital)
  active_baseline <- baseline_metrics[baseline_metrics$baseline_id == "active_equal_buy_hold", , drop = FALSE]
  spy_baseline <- baseline_metrics[baseline_metrics$baseline_id == "spy_buy_hold", , drop = FALSE]
  exposure <- mean(as.numeric(accounting$equity$open_position_count), na.rm = TRUE) / length(grep("_quantity$", names(accounting$equity)))
  data.frame(
    screen_id = screen_id,
    basket_archetype = basket_archetype,
    context_id = context_id,
    context_label = context_label,
    context_recipe = context_recipe,
    feature_set_id = feature_set_id,
    feature_set_label = feature_set_label,
    window_id = window$window_id[[1L]],
    quarter_ids = window$quarter_ids[[1L]],
    regime_label = window$regime_label[[1L]],
    lane_id = lane_id,
    selection_policy = policy,
    entry_replay_semantics = semantics,
    annual_replay_mode = replay_mode,
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
  grDevices::png(path, width = 3600L, height = max(2600L, 900L * length(screens)), res = 220L)
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
  graphics::mtext("Gen5.3 Momentum Context-Size Specialist Equity Overlay", side = 3, outer = TRUE, line = 1, font = 2, col = aesthetic$text)
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
  feature_label <- c(
    workhorse_enriched = "Workhorse",
    momentum_participation = "Momentum",
    momentum_plus_stress = "Momentum+stress",
    market_relative_momentum = "Market-relative"
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
    as.character(summary$context_id),
    feature_label[as.character(summary$feature_set_id)],
    semantics_label[as.character(summary$entry_replay_semantics)]
  )
  rows <- unique(as.character(summary$row_label))
  cols <- unique(as.character(summary$window_id))
  col_labels <- sub("_asof_.*$", "", cols)
  values <- matrix(NA_real_, nrow = length(rows), ncol = length(cols), dimnames = list(rows, cols))
  for (i in seq_len(nrow(summary))) {
    values[summary$row_label[[i]], summary$window_id[[i]]] <- as.numeric(summary$alpha_vs_active_equal[[i]])
  }
  grDevices::png(path, width = 2900L, height = max(2600L, 230L * nrow(values) + 900L), res = 220L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(6, 16, 4, 2))
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
  graphics::axis(2, at = rev(seq_along(rows)), labels = rows, las = 1, cex.axis = 0.68, col.axis = aesthetic$axis)
  graphics::mtext("Green means live-capital strategy beat equal-weight basket hold in the same annual OOS window.", side = 1, line = 4.4, cex = 0.72, col = aesthetic$text)
  invisible(path)
}

write_exposure_alpha_scatter <- function(summary, path) {
  aesthetic <- g5_chart_aesthetic()
  colors <- c(
    workhorse_enriched = "#2E86AB",
    momentum_participation = "#00A88F",
    momentum_plus_stress = "#D97706",
    market_relative_momentum = "#7C3AED"
  )
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
      bg = colors[[as.character(summary$feature_set_id[[i]])]],
      col = aesthetic$axis,
      cex = ifelse(summary$selection_policy[[i]] == "pooled_family_asset_variant", 1.45, 1.1)
    )
  }
  graphics::legend("bottomleft", legend = c("workhorse", "momentum", "momentum+stress", "market-relative"), pt.bg = colors, pch = 21L, bty = "n", cex = 0.78)
  graphics::legend("topright", legend = c("fresh", "continuation", "larger marker = pooled"), pch = c(21L, 24L, 21L), pt.bg = c("#AAAAAA", "#AAAAAA", "#AAAAAA"), bty = "n", cex = 0.78)
  invisible(path)
}

write_trade_tape_contact_sheet <- function(symbol_results_by_lane, path) {
  if (!length(symbol_results_by_lane)) return(invisible(NULL))
  lane_names <- names(symbol_results_by_lane)
  first_lane <- symbol_results_by_lane[[1L]]
  symbols <- names(first_lane)
  if (!length(symbols)) return(invisible(NULL))
  grDevices::png(path, width = 3800L, height = max(3000L, 360L * length(lane_names) + 500L), res = 190L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(mfrow = c(length(lane_names), length(symbols)), mar = c(3.8, 3.6, 3, 0.8), oma = c(0, 0, 2, 0))
  for (lane_id in lane_names) {
    lane <- symbol_results_by_lane[[lane_id]]
    parts <- strsplit(lane_id, "__", fixed = TRUE)[[1L]]
    lane_label <- if (length(parts) >= 5L) {
      paste(parts[[1L]], parts[[2L]], parts[[3L]], sub("state_switch_continuation", "continuation", sub("fresh_signal_only", "fresh", parts[[5L]])))
    } else if (length(parts) >= 4L) {
      paste(parts[[1L]], parts[[2L]], sub("state_switch_continuation", "continuation", sub("fresh_signal_only", "fresh", parts[[4L]])))
    } else {
      lane_id
    }
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
  graphics::mtext("Gen5.3 Momentum Context-Size Trade Tapes", side = 3, outer = TRUE, line = 0.5, font = 2)
  invisible(path)
}

write_representative_trade_tapes <- function(symbol_results_by_lane, path) {
  focus_lane <- "hb_risk_aware_18__workhorse_enriched__2024Y_asof_20241231__pooled_family_asset_variant__state_switch_continuation"
  focus_symbols <- c("AMD", "NVDA", "TSLA", "MSTR")
  if (!focus_lane %in% names(symbol_results_by_lane)) return(invisible(NULL))
  lane <- symbol_results_by_lane[[focus_lane]]
  focus_symbols <- focus_symbols[focus_symbols %in% names(lane)]
  if (!length(focus_symbols)) return(invisible(NULL))
  grDevices::png(path, width = 2600L, height = 1900L, res = 190L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1), oma = c(0, 0, 2.2, 0))
  for (symbol in focus_symbols) {
    result <- lane[[symbol]]
    g5_bridge_plot_panel(
      result$replay_oos,
      result$executions,
      result$pending_actions,
      result$trades,
      main = paste0(symbol, " / risk-aware workhorse / 2024Y continuation")
    )
  }
  graphics::mtext(
    "Representative Timing Tapes: Risk-Aware Workhorse 2024Y Continuation",
    side = 3,
    outer = TRUE,
    line = 0.6,
    font = 2
  )
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
    no_trade_exit_immediate = "#B8BCC4",
    ema_cross = "#2563EB",
    ema_trend = "#00A88F",
    breakout = "#277DA1",
    pullback_in_uptrend = "#43AA8B",
    vol_expansion_breakout = "#F8961E",
    donchian_breakout_vol_expand = "#577590"
  )
  family_label <- c(
    no_trade = "Cash",
    no_trade_exit_immediate = "Exit cash",
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
    "# Gen5.3 Momentum Context-Size Specialist Screen",
    "",
    "## Plain-Language Purpose",
    "",
    "This screen deliberately narrows the PCA engine's job. Instead of asking one universal router to trade every market behavior, it asks whether behavioral-pool PCA can act as a participation filter for a hand-picked high-beta bullish basket.",
    "",
    "The motivating memory from Gen4 is that reliable alpha seemed to appear only after the research universe became larger and more diverse. This screen tests that memory with a stricter downstream hypothesis set: only EMA cross, EMA trend, no-trade, and no-trade exit-immediate behavior may compete.",
    "",
    "## Design",
    "",
    "- PCA/state surface: behavioral-pool long PCA plus `3x3` quantile states.",
    "- Live basket: long-history high-beta symbols `AMD,NVDA,TSLA,MSTR,AVGO`.",
    "- Context-size axis: live basket only, live plus high-beta peers, and live plus high-beta peers plus macro/risk anchors.",
    "- Feature-set axis: workhorse enriched, momentum participation, momentum plus stress, and market-relative momentum.",
    "- Strategy pool: `ema_cross`, `ema_trend`, `no_trade`, and `no_trade_exit_immediate` only.",
    "- Selection policy: pooled-family asset-variant, held fixed so this first slice tests specialist participation rather than reopening selection-policy as a factor.",
    "- Replay semantics: fresh-signal-only versus state-switch continuation.",
    "- Accounting: true shared-account live-capital replay with dynamic equal-slot, cash-capped entries.",
    "- Benchmark: equal-weight buy-and-hold of the exact live basket over the same annual OOS window, plus SPY reference.",
    paste0("- Annual replay mode: `", annual_replay_mode, "`. `quarter_continuity_replay` keeps independent quarterly authority fitting, but lets an open trade remain locked to its entry-quarter authority until it exits; new entries then use the authority active at the flat date."),
    "",
    "## Run Spec",
    "",
    md_table(run_spec, c("screen_id", "context_id", "feature_set_label", "basket_archetype", "symbols", "context_symbols", "window_id", "selection_policy", "entry_replay_semantics", "annual_replay_mode"), n = 36L),
    "",
    "## Live-Capital Summary",
    "",
    md_table(printable, c("context_id", "feature_set_label", "window_id", "entry_replay_semantics", "annual_replay_mode", "total_return", "active_equal_buy_hold_return", "alpha_vs_active_equal", "mean_open_position_fraction", "total_entry_fills", "max_drawdown")),
    "",
    "## Aggregate Readout",
    "",
    md_table(agg, c("context_id", "feature_set_label", "entry_replay_semantics", "annual_replay_mode", "windows_tested", "windows_beating_basket", "mean_total_return", "mean_alpha_vs_active_equal", "mean_exposure", "worst_drawdown")),
    "",
    "## Visual Outputs",
    "",
    paste0("- Equity overlay: `", paths$equity_overlay_png, "`"),
    paste0("- Alpha heatmap: `", paths$alpha_heatmap_png, "`"),
    paste0("- Exposure/alpha scatter: `", paths$exposure_alpha_scatter_png, "`"),
    paste0("- Selection family heatmap: `", paths$selection_family_heatmap_png, "`"),
    paste0("- Trade tape contact sheet: `", paths$trade_tape_contact_sheet_png, "`"),
    paste0("- Representative timing tapes: `", paths$representative_trade_tapes_png, "`"),
    paste0("- Continuity audit: `", paths$continuity_csv, "`"),
    paste0("- Feature taxonomy: `", paths$feature_taxonomy_csv, "`"),
    "",
    "## Guardrails",
    "",
    "- Authority is fit from TRAIN only for each quarter and basket.",
    "- OOS replay consumes frozen state maps and selected strategy authority.",
    "- Cross-quarter continuity preserves open-trade exit ownership; it does not allow OOS information to refit, relabel, or reselect authority.",
    "- The screen is research/inspection only and does not change live advice behavior.",
    "- Performance is not accepted allocation evidence.",
    "- Mean-reversion, breakout, pullback, and SMA families are intentionally excluded from this EMA-only specialist probe."
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
continuity_rows <- list()
trade_tape_symbol_results <- list()

message("Gen5.3 momentum context-size specialist screen")
message("Output: ", output_dir)
message("Feed: ", cfg$feed)
message("Refresh: ", refresh)
message("Strategy pool: ", strategy_pool_id, " / ", strategy_pool_label)
message("Strategy grid preset: ", strategy_grid_preset)
message("Candidate families: ", paste(candidate_families, collapse = ","))
message("Annual replay mode: ", annual_replay_mode)
if (nzchar(reuse_auth_root)) message("Reuse authority root: ", reuse_auth_root)

for (spec in screen_specs) {
  screen_dir <- file.path(output_dir, spec$screen_id)
  ensure_dir(screen_dir)
  dates <- lapply(assessment_quarters, g5_bridge_authority_contract_dates, train_quarters = 8L)
  start_date <- max(min(as.Date(vapply(dates, function(x) as.character(x$train_start_date), character(1L)))) - warmup_days, data_floor)
  end_date <- max(as.Date(substr(windows$as_of_timestamp, 1L, 10L)))
  query_symbols <- unique(c(spec$symbols, spec$context_symbols, "SPY"))
  message("")
  message("Query bars: ", spec$screen_id, " / ", spec$feature_set_id, " / ", start_date, " through ", end_date)
  query <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = start_date,
    end_date = end_date,
    as_of_timestamp = paste0(end_date, " 17:30:00"),
    symbols = query_symbols,
    universe_name = paste0("gen53_momentum_context_size_", spec$screen_id),
    universe_roles = "regime_context_universe,active_allocation_set,baseline_reference",
    refresh = refresh,
    repo_root = repo_root
  )
  for (symbol in spec$symbols) g5_require_chartable_symbol(query, symbol = symbol, refresh = refresh)
  g5_require_chartable_symbol(query, symbol = "SPY", refresh = refresh)
  query_dir <- file.path(screen_dir, "query")
  ensure_dir(query_dir)
  query_paths <- g5_write_workbench_query_artifacts(query, output_dir = query_dir, prefix = "q")
  bars <- query$bars
  bars$session_date <- as.Date(bars$session_date)

  for (w in seq_len(nrow(windows))) {
    window <- windows[w, , drop = FALSE]
    window_quarters <- split_csv(window$quarter_ids[[1L]])
    as_of_date <- as.Date(substr(window$as_of_timestamp[[1L]], 1L, 10L))
    replay_bars <- bars[as.Date(bars$session_date) <= as_of_date, , drop = FALSE]
    authority_dirs <- stats::setNames(vector("list", length(window_quarters)), window_quarters)
    quarter_policy_authorities <- stats::setNames(vector("list", length(window_quarters)), window_quarters)
    for (quarter_id in window_quarters) {
      authority_dir <- file.path(screen_dir, "auth", quarter_id)
      authority_dirs[[quarter_id]] <- normalizePath(authority_dir, winslash = "/", mustWork = FALSE)
      authority_base <- build_authority(spec, bars, quarter_id, authority_dir)
      policy_authorities <- stats::setNames(lapply(selection_policies, function(policy) make_policy_authority(authority_base, policy)), selection_policies)
      quarter_policy_authorities[[quarter_id]] <- policy_authorities
      policy_states <- g5_wfa_bind_rows_fill(lapply(policy_authorities, function(x) x$selected_states))
      policy_states$screen_id <- spec$screen_id
      policy_states$context_id <- spec$context_id
      policy_states$context_label <- spec$context_label
      policy_states$context_recipe <- spec$context_recipe
      policy_states$feature_set_id <- spec$feature_set_id
      policy_states$feature_set_label <- spec$feature_set_label
      policy_states$window_id <- window$window_id[[1L]]
      policy_states$assessment_quarters <- window$quarter_ids[[1L]]
      authority_rows[[length(authority_rows) + 1L]] <- policy_states
    }
    for (policy in selection_policies) {
      for (semantics in entry_replay_semantics) {
        lane_id <- paste(policy, semantics, sep = "__")
        message("Replay/accounting: ", spec$screen_id, " / ", window$window_id[[1L]], " / ", lane_id, " / ", annual_replay_mode)
        results <- stats::setNames(vector("list", length(spec$symbols)), spec$symbols)
        for (symbol in spec$symbols) {
          if (identical(annual_replay_mode, "quarter_continuity_replay")) {
            authorities_for_policy <- stats::setNames(lapply(window_quarters, function(quarter_id) {
              quarter_policy_authorities[[quarter_id]][[policy]]
            }), window_quarters)
            results[[symbol]] <- replay_symbol_annual_continuity(
              replay_bars,
              authorities_for_policy,
              symbol,
              as_of_date,
              semantics,
              lane_id,
              spec$screen_id,
              window$window_id[[1L]],
              spec$feature_set_id
            )
          } else {
            quarter_results <- lapply(window_quarters, function(quarter_id) {
              authority <- quarter_policy_authorities[[quarter_id]][[policy]]
              quarter_end <- as.Date(authority$contract$live_end_date[[1L]])
              replay_symbol_oos(
                replay_bars,
                authority,
                symbol,
                min(as_of_date, quarter_end),
                semantics,
                lane_id,
                spec$screen_id,
                window$window_id[[1L]],
                spec$feature_set_id
              )
            })
            results[[symbol]] <- combine_symbol_results(quarter_results)
          }
        }
        if (identical(annual_replay_mode, "quarter_continuity_replay")) {
          continuity <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$continuity))
          if (is.data.frame(continuity) && nrow(continuity)) {
            continuity$screen_id <- spec$screen_id
            continuity$context_id <- spec$context_id
            continuity$feature_set_id <- spec$feature_set_id
            continuity$window_id <- window$window_id[[1L]]
            continuity$lane_id <- lane_id
            continuity$selection_policy <- policy
            continuity$entry_replay_semantics <- semantics
            continuity$annual_replay_mode <- annual_replay_mode
            continuity_rows[[length(continuity_rows) + 1L]] <- continuity
          }
        }
        if (spec$context_id %in% c("hb_self_5", "hb_risk_aware_18") &&
            spec$feature_set_id %in% c("workhorse_enriched", "momentum_plus_stress", "market_relative_momentum") &&
            window$window_id[[1L]] %in% c("2020Y_asof_20201231", "2022Y_asof_20221231") &&
            identical(semantics, "state_switch_continuation")) {
          trade_tape_symbol_results[[paste(spec$context_id, spec$feature_set_id, window$window_id[[1L]], lane_id, sep = "__")]] <- results
        }
        trades_by_symbol <- stats::setNames(lapply(spec$symbols, function(symbol) {
          accounting_trade_table(results[[symbol]]$trades, symbol, lane_id, spec$screen_id, window$window_id[[1L]], annual_replay_mode)
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
        eq$context_id <- spec$context_id
        eq$context_label <- spec$context_label
        eq$context_recipe <- spec$context_recipe
        eq$feature_set_id <- spec$feature_set_id
        eq$feature_set_label <- spec$feature_set_label
        eq$window_id <- window$window_id[[1L]]
        eq$quarter_ids <- window$quarter_ids[[1L]]
        eq$regime_label <- window$regime_label[[1L]]
        eq$lane_id <- lane_id
        eq$selection_policy <- policy
        eq$entry_replay_semantics <- semantics
        eq$annual_replay_mode <- annual_replay_mode
        eq$active_equal_buy_hold_equity <- base$active_equal_buy_hold_equity[match(as.Date(eq$session_date), as.Date(base$session_date))]
        eq$spy_buy_hold_equity <- base$spy_buy_hold_equity[match(as.Date(eq$session_date), as.Date(base$session_date))]
        equity_rows[[length(equity_rows) + 1L]] <- eq
        ev <- accounting$events
        if (is.data.frame(ev) && nrow(ev)) {
          ev$screen_id <- spec$screen_id
          ev$basket_archetype <- spec$basket_archetype
          ev$context_id <- spec$context_id
          ev$context_label <- spec$context_label
          ev$context_recipe <- spec$context_recipe
          ev$feature_set_id <- spec$feature_set_id
          ev$feature_set_label <- spec$feature_set_label
          ev$window_id <- window$window_id[[1L]]
          ev$quarter_ids <- window$quarter_ids[[1L]]
          ev$lane_id <- lane_id
          ev$selection_policy <- policy
          ev$entry_replay_semantics <- semantics
          ev$annual_replay_mode <- annual_replay_mode
          event_rows[[length(event_rows) + 1L]] <- ev
        }
        standalone <- accounting$standalone_symbol_equity
        standalone$screen_id <- spec$screen_id
        standalone$basket_archetype <- spec$basket_archetype
        standalone$context_id <- spec$context_id
        standalone$context_label <- spec$context_label
        standalone$context_recipe <- spec$context_recipe
        standalone$feature_set_id <- spec$feature_set_id
        standalone$feature_set_label <- spec$feature_set_label
        standalone$window_id <- window$window_id[[1L]]
        standalone$quarter_ids <- window$quarter_ids[[1L]]
        standalone$lane_id <- lane_id
        standalone$selection_policy <- policy
        standalone$entry_replay_semantics <- semantics
        standalone$annual_replay_mode <- annual_replay_mode
        standalone_rows[[length(standalone_rows) + 1L]] <- standalone
        sym <- accounting$symbol_summary
        sym$screen_id <- spec$screen_id
        sym$basket_archetype <- spec$basket_archetype
        sym$context_id <- spec$context_id
        sym$context_label <- spec$context_label
        sym$context_recipe <- spec$context_recipe
        sym$feature_set_id <- spec$feature_set_id
        sym$feature_set_label <- spec$feature_set_label
        sym$window_id <- window$window_id[[1L]]
        sym$quarter_ids <- window$quarter_ids[[1L]]
        sym$lane_id <- lane_id
        sym$selection_policy <- policy
        sym$entry_replay_semantics <- semantics
        sym$annual_replay_mode <- annual_replay_mode
        symbol_summary_rows[[length(symbol_summary_rows) + 1L]] <- sym
        summary_rows[[length(summary_rows) + 1L]] <- summarize_accounting(spec$screen_id, spec$basket_archetype, spec$context_id, spec$context_label, spec$context_recipe, spec$feature_set_id, spec$feature_set_label, window, lane_id, policy, semantics, annual_replay_mode, accounting, initial_capital)
        replay_rows[[length(replay_rows) + 1L]] <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$replay_oos))
        trade_rows[[length(trade_rows) + 1L]] <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$trades))
        execution_rows[[length(execution_rows) + 1L]] <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$executions))
        pending_rows[[length(pending_rows) + 1L]] <- g5_wfa_bind_rows_fill(lapply(results, function(x) x$pending_actions))
        packet_rows[[length(packet_rows) + 1L]] <- data.frame(
          screen_id = spec$screen_id,
          basket_archetype = spec$basket_archetype,
          context_id = spec$context_id,
          context_label = spec$context_label,
          context_recipe = spec$context_recipe,
          feature_set_id = spec$feature_set_id,
          feature_set_label = spec$feature_set_label,
          strategy_pool_id = strategy_pool_id,
          window_id = window$window_id[[1L]],
          quarter_ids = window$quarter_ids[[1L]],
          selection_policy = policy,
          entry_replay_semantics = semantics,
          annual_replay_mode = annual_replay_mode,
          lane_id = lane_id,
          authority_dirs = paste(unlist(authority_dirs, use.names = FALSE), collapse = ";"),
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
    context_id = spec$context_id,
    context_label = spec$context_label,
    context_recipe = spec$context_recipe,
    strategy_pool_id = strategy_pool_id,
    strategy_pool_label = strategy_pool_label,
    feature_set_id = spec$feature_set_id,
    feature_set_label = spec$feature_set_label,
    feature_cols = paste(spec$feature_cols, collapse = ","),
    symbols = paste(spec$symbols, collapse = ","),
    context_symbols = paste(spec$context_symbols, collapse = ","),
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
run_spec <- merge(run_spec, windows[, c("window_id", "quarter_ids", "as_of_timestamp", "regime_label"), drop = FALSE], by = NULL)
run_spec <- merge(run_spec, expand.grid(selection_policy = selection_policies, entry_replay_semantics = entry_replay_semantics, stringsAsFactors = FALSE), by = NULL)
run_spec$annual_replay_mode <- annual_replay_mode
run_spec$research_only <- TRUE
run_spec$output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)

summary <- g5_wfa_bind_rows_fill(summary_rows)
summary <- summary[order(summary$context_id, summary$feature_set_id, summary$window_id, summary$selection_policy, summary$entry_replay_semantics, summary$annual_replay_mode), , drop = FALSE]
aggregate <- do.call(rbind, lapply(split(summary, paste(summary$context_id, summary$feature_set_id, summary$basket_archetype, summary$selection_policy, summary$entry_replay_semantics, summary$annual_replay_mode, sep = "|")), function(x) {
  data.frame(
    basket_archetype = x$basket_archetype[[1L]],
    context_id = x$context_id[[1L]],
    context_label = x$context_label[[1L]],
    context_recipe = x$context_recipe[[1L]],
    feature_set_id = x$feature_set_id[[1L]],
    feature_set_label = x$feature_set_label[[1L]],
    strategy_pool_id = strategy_pool_id,
    selection_policy = x$selection_policy[[1L]],
    entry_replay_semantics = x$entry_replay_semantics[[1L]],
    annual_replay_mode = x$annual_replay_mode[[1L]],
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
aggregate <- aggregate[order(aggregate$context_id, aggregate$feature_set_id, aggregate$selection_policy, aggregate$entry_replay_semantics, aggregate$annual_replay_mode), , drop = FALSE]

paths <- list(
  run_spec_csv = file.path(output_dir, "momentum_context_size_run_spec.csv"),
  packet_index_csv = file.path(output_dir, "momentum_context_size_packet_index.csv"),
  selected_states_csv = file.path(output_dir, "momentum_context_size_selected_states.csv"),
  replay_oos_csv = file.path(output_dir, "momentum_context_size_replay_oos.csv"),
  executions_csv = file.path(output_dir, "momentum_context_size_executions.csv"),
  trades_csv = file.path(output_dir, "momentum_context_size_trades.csv"),
  pending_csv = file.path(output_dir, "momentum_context_size_pending_actions.csv"),
  continuity_csv = file.path(output_dir, "momentum_context_size_continuity.csv"),
  portfolio_equity_csv = file.path(output_dir, "momentum_context_size_portfolio_equity.csv"),
  portfolio_events_csv = file.path(output_dir, "momentum_context_size_portfolio_events.csv"),
  standalone_symbol_equity_csv = file.path(output_dir, "momentum_context_size_standalone_symbol_equity.csv"),
  symbol_summary_csv = file.path(output_dir, "momentum_context_size_symbol_summary.csv"),
  summary_csv = file.path(output_dir, "momentum_context_size_summary.csv"),
  aggregate_csv = file.path(output_dir, "momentum_context_size_aggregate.csv"),
  feature_taxonomy_csv = file.path(output_dir, "momentum_context_size_feature_taxonomy.csv"),
  equity_overlay_png = file.path(output_dir, "momentum_context_size_equity_overlay.png"),
  alpha_heatmap_png = file.path(output_dir, "momentum_context_size_alpha_heatmap.png"),
  exposure_alpha_scatter_png = file.path(output_dir, "momentum_context_size_exposure_alpha_scatter.png"),
  selection_family_heatmap_png = file.path(output_dir, "momentum_context_size_selection_family_heatmap.png"),
  trade_tape_contact_sheet_png = file.path(output_dir, "momentum_context_size_trade_tape_contact_sheet.png"),
  representative_trade_tapes_png = file.path(output_dir, "momentum_context_size_representative_trade_tapes.png"),
  artifact_index_csv = file.path(output_dir, "momentum_context_size_artifact_index.csv"),
  report_md = file.path(output_dir, "momentum_context_size_report.md")
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(packet_rows), paths$packet_index_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(authority_rows), paths$selected_states_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(replay_rows), paths$replay_oos_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(execution_rows), paths$executions_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(trade_rows), paths$trades_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(pending_rows), paths$pending_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(continuity_rows), paths$continuity_csv)
equity_all <- g5_wfa_bind_rows_fill(equity_rows)
g5_wfa_write_csv(equity_all, paths$portfolio_equity_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(event_rows), paths$portfolio_events_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(standalone_rows), paths$standalone_symbol_equity_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(symbol_summary_rows), paths$symbol_summary_csv)
g5_wfa_write_csv(summary, paths$summary_csv)
g5_wfa_write_csv(aggregate, paths$aggregate_csv)
g5_wfa_write_csv(g5_pca_regime_feature_set_taxonomy(), paths$feature_taxonomy_csv)
write_equity_overlay(equity_all, summary, paths$equity_overlay_png)
write_alpha_heatmap(summary, paths$alpha_heatmap_png)
write_exposure_alpha_scatter(summary, paths$exposure_alpha_scatter_png)
write_selection_family_heatmap(g5_wfa_bind_rows_fill(authority_rows), paths$selection_family_heatmap_png)
write_trade_tape_contact_sheet(trade_tape_symbol_results, paths$trade_tape_contact_sheet_png)
write_representative_trade_tapes(trade_tape_symbol_results, paths$representative_trade_tapes_png)

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
message("Gen5.3 momentum context-size specialist annual screen complete: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Summary:")
print(printable[, c("context_id", "feature_set_label", "window_id", "entry_replay_semantics", "annual_replay_mode", "total_return", "active_equal_buy_hold_return", "alpha_vs_active_equal", "mean_open_position_fraction", "total_entry_fills"), drop = FALSE], row.names = FALSE)
message("")
message("Report: ", paths$report_md)
message("Deck visuals: ", paths$equity_overlay_png, " / ", paths$alpha_heatmap_png, " / ", paths$exposure_alpha_scatter_png, " / ", paths$selection_family_heatmap_png, " / ", paths$trade_tape_contact_sheet_png, " / ", paths$representative_trade_tapes_png)
