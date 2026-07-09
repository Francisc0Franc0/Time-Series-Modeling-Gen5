# Selection-policy x basket-archetype research screen.

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

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_SELECTION_POLICY_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed
refresh <- g5_parse_bool_env(env_or("GEN5_SELECTION_POLICY_BASKET_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_SELECTION_POLICY_BASKET_STAMP", "20260703"))
root_output_dir <- file.path(repo_root, "runs", "research_workbench", "selpol_basket", paste0("selpol_basket_", stamp))
dir.create(root_output_dir, recursive = TRUE, showWarnings = FALSE)

selection_policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
min_train_state_rows <- 20L
warmup_days <- 420L
grid_n <- 3L

research_candidate_families <- c(
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

recent_risk_context_symbols <- c("SPY", "QQQ", "IWM", "SMH", "TLT", "GLD", "VXX")
long_history_risk_context_symbols <- c("SPY", "QQQ", "IWM", "SMH", "TLT", "GLD")
active_plus_risk <- function(symbols, risk_symbols = recent_risk_context_symbols) {
  unique(g5_standardize_symbol(c(symbols, risk_symbols)))
}

screen_specs <- list(
  list(
    screen_id = "A_live_like",
    screen_label = "Screen A: current live-like basket",
    evidence_role = "live_basket_evidence",
    symbols = c("AMD", "NVDA", "PLTR", "TSLA", "SOFI"),
    context_symbols = active_plus_risk(c("AMD", "NVDA", "PLTR", "TSLA", "SOFI")),
    basket_archetype = "current_live_like_high_beta_growth",
    authority_quarters = c("2025Q3", "2025Q4", "2026Q1", "2026Q2", "2026Q3"),
    replay_windows = data.frame(
      window_id = c("2025Q4_asof_20251231", "2026Q1_asof_20260331", "2026Q2_asof_20260630", "2026Q3_asof_20260701"),
      quarter_id = c("2025Q4", "2026Q1", "2026Q2", "2026Q3"),
      as_of_timestamp = c("2025-12-31 17:30:00", "2026-03-31 17:30:00", "2026-06-30 17:30:00", "2026-07-01 17:30:00"),
      stringsAsFactors = FALSE
    ),
    interpretation_note = "This screen keeps the current temporary live basket but uses the research lane: active-plus-risk context, behavioral-pool PCA, 3x3 quantile states, and the broader Gen5.1 research candidate grid. History is limited by SOFI and PLTR, so the useful replay span is recent."
  ),
  list(
    screen_id = "B_high_beta_long_history",
    screen_label = "Screen B: long-history high-beta basket",
    evidence_role = "long_history_high_beta_evidence",
    symbols = c("AMD", "NVDA", "TSLA", "AAPL", "MSTR"),
    context_symbols = active_plus_risk(c("AMD", "NVDA", "TSLA", "AAPL", "MSTR"), long_history_risk_context_symbols),
    basket_archetype = "long_history_high_beta_growth",
    authority_quarters = c("2019Q2", "2019Q3", "2020Q2", "2020Q3", "2021Q4", "2022Q1", "2022Q3", "2022Q4", "2024Q4", "2025Q1", "2026Q1", "2026Q2"),
    replay_windows = data.frame(
      window_id = c("2019Q3_asof_20190930", "2020Q3_asof_20200930", "2022Q1_asof_20220331", "2022Q4_asof_20221230", "2025Q1_asof_20250331", "2026Q2_asof_20260630"),
      quarter_id = c("2019Q3", "2020Q3", "2022Q1", "2022Q4", "2025Q1", "2026Q2"),
      as_of_timestamp = c("2019-09-30 17:30:00", "2020-09-30 17:30:00", "2022-03-31 17:30:00", "2022-12-30 17:30:00", "2025-03-31 17:30:00", "2026-06-30 17:30:00"),
      stringsAsFactors = FALSE
    ),
    interpretation_note = "This screen swaps out SOFI and PLTR so the same research question can span older market regimes. It is not a live-basket replication; it is robustness evidence for a long-history volatile-growth basket."
  ),
  list(
    screen_id = "C_etf_sector",
    screen_label = "Screen C: ETF/sector basket",
    evidence_role = "etf_sector_generalization_evidence",
    symbols = c("QQQ", "SMH", "XLK", "XLE", "XLF"),
    context_symbols = active_plus_risk(c("QQQ", "SMH", "XLK", "XLE", "XLF"), long_history_risk_context_symbols),
    basket_archetype = "etf_sector_tradeable_proxy",
    authority_quarters = c("2019Q2", "2019Q3", "2020Q2", "2020Q3", "2021Q4", "2022Q1", "2022Q3", "2022Q4", "2024Q4", "2025Q1", "2026Q1", "2026Q2"),
    replay_windows = data.frame(
      window_id = c("2019Q3_asof_20190930", "2020Q3_asof_20200930", "2022Q1_asof_20220331", "2022Q4_asof_20221230", "2025Q1_asof_20250331", "2026Q2_asof_20260630"),
      quarter_id = c("2019Q3", "2020Q3", "2022Q1", "2022Q4", "2025Q1", "2026Q2"),
      as_of_timestamp = c("2019-09-30 17:30:00", "2020-09-30 17:30:00", "2022-03-31 17:30:00", "2022-12-30 17:30:00", "2025-03-31 17:30:00", "2026-06-30 17:30:00"),
      stringsAsFactors = FALSE
    ),
    interpretation_note = "This screen tests whether the selection-policy behavior is specific to single-name high-beta stocks or also appears on a more liquid ETF/sector proxy basket. It is a generalization probe, not a proposed final universe."
  )
)

only_screens <- strsplit(env_or("GEN5_SELECTION_POLICY_BASKET_ONLY", ""), ",", fixed = TRUE)[[1L]]
only_screens <- trimws(only_screens[nzchar(trimws(only_screens))])
if (length(only_screens)) {
  screen_specs <- Filter(function(x) x$screen_id %in% only_screens, screen_specs)
  if (!length(screen_specs)) g5_stop("GEN5_SELECTION_POLICY_BASKET_ONLY did not match any configured screen_id.")
}

make_policy_authority <- function(authority, selection_policy) {
  out <- authority
  out$contract$selection_policy <- selection_policy
  if (identical(selection_policy, "asset_state_direct_spec")) {
    out$selected_states <- g5_selection_policy_add_direct_label(out$selected_states, out$train_state_performance, min_train_state_rows = min_train_state_rows)
  } else if (identical(selection_policy, "pooled_family_asset_variant")) {
    out$selected_states <- g5_selection_policy_pooled_family_asset_variant(out$train_state_performance, min_train_state_rows = min_train_state_rows)
  } else {
    g5_stop(paste0("Unsupported selection policy: ", selection_policy))
  }
  out
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

query_screen_bars <- function(spec, screen_dir) {
  dates <- lapply(spec$authority_quarters, g5_bridge_authority_contract_dates, train_quarters = 8L)
  start_date <- min(as.Date(vapply(dates, function(x) as.character(x$train_start_date), character(1L)))) - warmup_days
  end_date <- max(as.Date(vapply(spec$replay_windows$as_of_timestamp, function(x) substr(x, 1L, 10L), character(1L))))
  symbols <- unique(c(spec$symbols, spec$context_symbols))
  message("Query bars: ", spec$screen_id, " / ", start_date, " through ", end_date)
  result <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = start_date,
    end_date = end_date,
    as_of_timestamp = paste0(end_date, " 17:30:00"),
    symbols = symbols,
    universe_name = paste0("selection_policy_", spec$screen_id),
    universe_roles = "selection_policy_context_universe",
    refresh = refresh,
    repo_root = repo_root
  )
  for (symbol in spec$symbols) {
    g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
  }
  prefix <- paste0("query_", spec$screen_id)
  query_dir <- file.path(screen_dir, "query")
  dir.create(query_dir, recursive = TRUE, showWarnings = FALSE)
  query_paths <- g5_write_workbench_query_artifacts(result, output_dir = query_dir, prefix = prefix)
  list(result = result, query_paths = query_paths)
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

build_authority_with_symbol_checkpoints <- function(
  bars,
  symbols,
  context_symbols,
  quarter_id,
  as_of_timestamp,
  authority_dir
) {
  symbols <- g5_standardize_symbol(symbols)
  context_symbols <- unique(g5_standardize_symbol(context_symbols))
  g5_bridge_assert_symbols_available(bars, unique(c(symbols, context_symbols)))
  contract <- g5_bridge_contract_frame(
    quarter_id,
    symbols,
    context_symbols,
    as_of_timestamp,
    refresh,
    g5_git_sha_or_na(repo_root),
    cfg$feed,
    research_candidate_families,
    "gen4_daily_default"
  )
  contract$authority_status <- "RESEARCH_INSPECTION_ONLY"
  contract$research_note <- "Selection-policy x basket-archetype screen: active-plus-risk context, behavioral-pool PCA, 3x3 quantile states, broad Gen5.1 research candidate families with Gen4 daily parameter breadth."
  contract$grid_n <- grid_n
  contract$selection_policy <- "base_direct_authority"
  model_grid <- g5_bridge_model_grid(
    candidate_families = research_candidate_families,
    strategy_grid_preset = "gen4_daily_default"
  )
  fits <- lapply(symbols, function(symbol) {
    build_symbol_fit_checkpoint(
      bars = bars,
      symbol = symbol,
      contract = contract,
      model_grid = model_grid,
      context_symbols = context_symbols,
      authority_dir = authority_dir
    )
  })
  names(fits) <- symbols
  list(
    contract = contract,
    folds = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$fold)),
    selected_states = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$selected_states)),
    train_state_performance = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$train_state_performance)),
    state_coverage = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$state_coverage)),
    pca_scores = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$pca_scores)),
    pca_model_contract = g5_wfa_bind_rows_fill(lapply(fits, function(x) x$pca_model_contract)),
    model_grid = model_grid,
    fold_models = stats::setNames(lapply(fits, function(x) x$fold_model), symbols)
  )
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

contract_symbols_match <- function(contract, symbols, context_symbols) {
  if (!is.data.frame(contract) || !nrow(contract)) return(FALSE)
  same_symbols <- identical(g5_standardize_symbol(strsplit(as.character(contract$symbols[[1L]]), ",", fixed = TRUE)[[1L]]), g5_standardize_symbol(symbols))
  same_context <- identical(g5_standardize_symbol(strsplit(as.character(contract$context_symbols[[1L]]), ",", fixed = TRUE)[[1L]]), g5_standardize_symbol(context_symbols))
  same_symbols && same_context
}

maybe_reuse_live_authority <- function(spec, quarter_id) {
  live_dir <- g5_bridge_authority_dir(repo_root, quarter_id)
  if (!dir.exists(live_dir)) return(NULL)
  authority <- tryCatch(read_full_authority_packet(live_dir), error = function(e) NULL)
  if (is.null(authority)) return(NULL)
  if (!contract_symbols_match(authority$contract, spec$symbols, spec$context_symbols)) return(NULL)
  authority
}

get_or_build_authority <- function(spec, bars, screen_dir, quarter_id) {
  authority_dir <- file.path(screen_dir, "auth", quarter_id)
  if (!isTRUE(refresh) &&
      file.exists(file.path(authority_dir, "bridge_authority_contract.csv")) &&
      file.exists(file.path(authority_dir, "bridge_selected_states.csv")) &&
      file.exists(file.path(authority_dir, "bridge_train_state_performance.csv"))) {
    message("Reuse cached authority: ", spec$screen_id, " / ", quarter_id)
    return(read_full_authority_packet(authority_dir))
  }
  reused <- maybe_reuse_live_authority(spec, quarter_id)
  if (!is.null(reused)) {
    message("Reuse matching live authority: ", spec$screen_id, " / ", quarter_id)
    write_authority_packet(reused, authority_dir)
    return(reused)
  }
  dates <- g5_bridge_authority_contract_dates(quarter_id, train_quarters = 8L)
  authority_as_of <- paste0(dates$train_end_date, " 17:30:00")
  message("Build authority: ", spec$screen_id, " / ", quarter_id)
  authority <- build_authority_with_symbol_checkpoints(
    bars,
    symbols = spec$symbols,
    context_symbols = spec$context_symbols,
    quarter_id = quarter_id,
    as_of_timestamp = authority_as_of,
    authority_dir = authority_dir
  )
  write_authority_packet(authority, authority_dir)
  authority
}

run_screen <- function(spec) {
  screen_dir <- file.path(root_output_dir, spec$screen_id)
  dir.create(screen_dir, recursive = TRUE, showWarnings = FALSE)
  message("")
  message("Running ", spec$screen_label)
  query <- query_screen_bars(spec, screen_dir)
  bars <- query$result$bars

  base_authorities <- list()
  authority_index_rows <- list()
  for (quarter_id in spec$authority_quarters) {
    authority <- get_or_build_authority(spec, bars, screen_dir, quarter_id)
    base_authorities[[quarter_id]] <- authority
    authority_dir <- file.path(screen_dir, "auth", quarter_id)
    paths <- list(
      selected_states_csv = file.path(authority_dir, "bridge_selected_states.csv"),
      train_state_performance_csv = file.path(authority_dir, "bridge_train_state_performance.csv")
    )
    authority_index_rows[[length(authority_index_rows) + 1L]] <- data.frame(
      schema_version = g5_selection_policy_screen_schema_version(),
      screen_id = spec$screen_id,
      quarter_id = quarter_id,
      selection_policy = "base_direct_authority",
      authority_dir = normalizePath(authority_dir, winslash = "/", mustWork = FALSE),
      selected_states_csv = normalizePath(paths$selected_states_csv, winslash = "/", mustWork = FALSE),
      train_state_performance_csv = normalizePath(paths$train_state_performance_csv, winslash = "/", mustWork = FALSE),
      stringsAsFactors = FALSE
    )
  }

  authorities <- list()
  for (policy in selection_policies) {
    authorities[[policy]] <- stats::setNames(lapply(base_authorities, make_policy_authority, selection_policy = policy), names(base_authorities))
  }

  direct_states <- g5_wfa_bind_rows_fill(lapply(authorities$asset_state_direct_spec, function(x) x$selected_states))
  pooled_states <- g5_wfa_bind_rows_fill(lapply(authorities$pooled_family_asset_variant, function(x) x$selected_states))
  comparison <- g5_selection_policy_compare_selected_states(direct_states, pooled_states)
  agreement_by_quarter <- do.call(rbind, lapply(split(comparison, comparison$quarter_id), function(x) {
    data.frame(
      screen_id = spec$screen_id,
      quarter_id = as.character(x$quarter_id[[1L]]),
      state_asset_rows = nrow(x),
      family_match_count = sum(x$family_match, na.rm = TRUE),
      family_match_rate = mean(x$family_match, na.rm = TRUE),
      spec_match_count = sum(x$spec_match, na.rm = TRUE),
      spec_match_rate = mean(x$spec_match, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
  agreement_overall <- data.frame(
    screen_id = spec$screen_id,
    quarter_id = "ALL",
    state_asset_rows = nrow(comparison),
    family_match_count = sum(comparison$family_match, na.rm = TRUE),
    family_match_rate = mean(comparison$family_match, na.rm = TRUE),
    spec_match_count = sum(comparison$spec_match, na.rm = TRUE),
    spec_match_rate = mean(comparison$spec_match, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  agreement_summary <- rbind(agreement_by_quarter, agreement_overall)

  packet_rows <- list()
  summary_rows <- list()
  book_rows <- list()
  trade_rows <- list()
  for (i in seq_len(nrow(spec$replay_windows))) {
    window <- spec$replay_windows[i, , drop = FALSE]
    previous_quarter <- g5_bridge_previous_quarter_id(window$quarter_id[[1L]])
    as_of_date <- as.Date(substr(window$as_of_timestamp[[1L]], 1L, 10L))
    replay_bars <- bars[as.Date(bars$session_date) <= as_of_date, , drop = FALSE]
    for (policy in selection_policies) {
      message("Replay: ", spec$screen_id, " / ", window$window_id[[1L]], " / ", policy)
      daily <- g5_selection_policy_run_daily_continuity_fast(
        replay_bars,
        current_authority = authorities[[policy]][[window$quarter_id[[1L]]]],
        previous_authority = authorities[[policy]][[previous_quarter]],
        as_of_timestamp = window$as_of_timestamp[[1L]]
      )
      daily$contract$selection_policy <- policy
      if (!is.null(daily$previous_contract)) daily$previous_contract$selection_policy <- policy
      for (field in c("replay", "pending_actions", "executions", "trades", "operator_packet", "book_summary", "continuity")) {
        if (!is.null(daily[[field]]) && is.data.frame(daily[[field]]) && nrow(daily[[field]])) {
          daily[[field]]$selection_policy <- policy
          daily[[field]]$window_id <- window$window_id[[1L]]
          daily[[field]]$screen_id <- spec$screen_id
        }
      }
      policy_dir <- file.path(screen_dir, window$window_id[[1L]], policy)
      dir.create(policy_dir, recursive = TRUE, showWarnings = FALSE)
      paths <- g5_bridge_write_daily_outputs(daily, policy_dir, chart_lookback_days = 90L)
      packet_rows[[length(packet_rows) + 1L]] <- data.frame(
        schema_version = g5_selection_policy_screen_schema_version(),
        screen_id = spec$screen_id,
        window_id = window$window_id[[1L]],
        quarter_id = window$quarter_id[[1L]],
        previous_quarter_id = previous_quarter,
        as_of_timestamp = window$as_of_timestamp[[1L]],
        selection_policy = policy,
        packet_dir = normalizePath(policy_dir, winslash = "/", mustWork = FALSE),
        report_md = normalizePath(paths$report_md, winslash = "/", mustWork = FALSE),
        contact_sheet_png = normalizePath(paths$contact_sheet_png, winslash = "/", mustWork = FALSE),
        trades_csv = normalizePath(paths$trades_csv, winslash = "/", mustWork = FALSE),
        replay_csv = normalizePath(paths$replay_csv, winslash = "/", mustWork = FALSE),
        stringsAsFactors = FALSE
      )
      summary <- g5_selection_policy_summarize_daily(daily, policy, window$window_id[[1L]])
      summary$screen_id <- spec$screen_id
      summary_rows[[length(summary_rows) + 1L]] <- summary
      if (is.data.frame(daily$book_summary) && nrow(daily$book_summary)) book_rows[[length(book_rows) + 1L]] <- daily$book_summary
      if (is.data.frame(daily$trades) && nrow(daily$trades)) trade_rows[[length(trade_rows) + 1L]] <- daily$trades
    }
  }

  packet_index <- g5_wfa_bind_rows_fill(packet_rows)
  trade_summary <- g5_wfa_bind_rows_fill(summary_rows)
  book_summary <- g5_wfa_bind_rows_fill(book_rows)
  trade_ledger <- if (length(trade_rows)) g5_wfa_bind_rows_fill(trade_rows) else data.frame()
  portfolio_proxy <- do.call(rbind, lapply(split(trade_summary, paste(trade_summary$window_id, trade_summary$selection_policy, sep = "::")), function(x) {
    returns <- suppressWarnings(as.numeric(x$compound_trace_return))
    finite <- is.finite(returns)
    best_idx <- if (any(finite)) which.max(ifelse(finite, returns, -Inf)) else NA_integer_
    worst_idx <- if (any(finite)) which.min(ifelse(finite, returns, Inf)) else NA_integer_
    ex_best <- if (sum(finite) > 1L) mean(returns[finite & seq_along(returns) != best_idx], na.rm = TRUE) else NA_real_
    ex_worst <- if (sum(finite) > 1L) mean(returns[finite & seq_along(returns) != worst_idx], na.rm = TRUE) else NA_real_
    data.frame(
      screen_id = spec$screen_id,
      basket_archetype = spec$basket_archetype,
      window_id = as.character(x$window_id[[1L]]),
      selection_policy = as.character(x$selection_policy[[1L]]),
      symbol_count = nrow(x),
      trade_count = sum(x$trade_count, na.rm = TRUE),
      open_trade_count = sum(x$open_trade_count, na.rm = TRUE),
      equal_symbol_mean_compound_trace_return = mean(x$compound_trace_return, na.rm = TRUE),
      worst_symbol_compound_trace_return = min(x$compound_trace_return, na.rm = TRUE),
      best_symbol_compound_trace_return = max(x$compound_trace_return, na.rm = TRUE),
      ex_best_symbol_mean_compound_trace_return = ex_best,
      ex_worst_symbol_mean_compound_trace_return = ex_worst,
      best_symbol = if (!is.na(best_idx)) as.character(x$symbol[[best_idx]]) else NA_character_,
      worst_symbol = if (!is.na(worst_idx)) as.character(x$symbol[[worst_idx]]) else NA_character_,
      stringsAsFactors = FALSE
    )
  }))

  taxonomy <- data.frame(
    schema_version = g5_selection_policy_screen_schema_version(),
    selection_policy = selection_policies,
    description = c(
    "Direct-spec policy: rank the full executable strategy spec inside each asset/state by TRAIN Sharpe, then TRAIN total return.",
      "Gen4-style policy: choose a state-level strategy family from pooled TRAIN evidence across assets, then choose asset-specific parameters inside that family."
    ),
    leakage_guardrail = c(
      "Uses TRAIN-only asset/state performance and freezes selected specs before replay.",
      "Uses TRAIN-only pooled family evidence and TRAIN-only asset parameter selection before replay."
    ),
    stringsAsFactors = FALSE
  )
  run_spec <- data.frame(
    schema_version = g5_selection_policy_screen_schema_version(),
    screen_id = spec$screen_id,
    screen_label = spec$screen_label,
    evidence_role = spec$evidence_role,
    basket_archetype = spec$basket_archetype,
    symbols = paste(spec$symbols, collapse = ","),
    context_symbols = paste(spec$context_symbols, collapse = ","),
    authority_quarters = paste(spec$authority_quarters, collapse = ","),
    replay_windows = paste(spec$replay_windows$window_id, collapse = ","),
    pca_panel_mode = "pooled_asset_day",
    pca_panel_label = "long_pca_behavioral_pool",
    state_engine = "quantile_grid",
    grid_n = grid_n,
    strategy_grid_preset = "gen4_daily_default",
    candidate_family_count = length(unique(c(research_candidate_families, "no_trade"))),
    candidate_families = paste(unique(c(research_candidate_families, "no_trade")), collapse = ","),
    context_template = "active_plus_risk_context",
    context_history_policy = if ("VXX" %in% spec$context_symbols) "recent_context_includes_vxx" else "long_history_context_omits_vxx_to_avoid_partial_history",
    min_train_state_rows = min_train_state_rows,
    intended_variable = "selection_policy_x_basket_archetype",
    research_only = TRUE,
    interpretation_note = spec$interpretation_note,
    stringsAsFactors = FALSE
  )

  paths <- list(
    run_spec_csv = file.path(screen_dir, "selection_policy_run_spec.csv"),
    taxonomy_csv = file.path(screen_dir, "selection_policy_taxonomy.csv"),
    authority_index_csv = file.path(screen_dir, "selection_policy_authority_index.csv"),
    selected_states_csv = file.path(screen_dir, "selection_policy_selected_states_all.csv"),
    selected_state_comparison_csv = file.path(screen_dir, "selection_policy_selected_state_comparison.csv"),
    agreement_summary_csv = file.path(screen_dir, "selection_policy_agreement_summary.csv"),
    packet_index_csv = file.path(screen_dir, "selection_policy_packet_index.csv"),
    book_summary_csv = file.path(screen_dir, "selection_policy_book_summary.csv"),
    trade_ledger_csv = file.path(screen_dir, "selection_policy_trade_ledger.csv"),
    trade_summary_csv = file.path(screen_dir, "selection_policy_trade_summary.csv"),
    portfolio_proxy_csv = file.path(screen_dir, "selection_policy_portfolio_proxy_summary.csv"),
    report_md = file.path(screen_dir, "selection_policy_screen_report.md")
  )
  g5_wfa_write_csv(run_spec, paths$run_spec_csv)
  g5_wfa_write_csv(taxonomy, paths$taxonomy_csv)
  g5_wfa_write_csv(g5_wfa_bind_rows_fill(authority_index_rows), paths$authority_index_csv)
  g5_wfa_write_csv(g5_wfa_bind_rows_fill(list(direct_states, pooled_states)), paths$selected_states_csv)
  g5_wfa_write_csv(comparison, paths$selected_state_comparison_csv)
  g5_wfa_write_csv(agreement_summary, paths$agreement_summary_csv)
  g5_wfa_write_csv(packet_index, paths$packet_index_csv)
  g5_wfa_write_csv(book_summary, paths$book_summary_csv)
  g5_wfa_write_csv(trade_ledger, paths$trade_ledger_csv)
  g5_wfa_write_csv(trade_summary, paths$trade_summary_csv)
  g5_wfa_write_csv(portfolio_proxy, paths$portfolio_proxy_csv)
  visual_paths <- g5_selection_policy_write_visual_summary(screen_dir)
  visual_paths$output_dir <- normalizePath(file.path(screen_dir, "visual_summary"), winslash = "/", mustWork = FALSE)

  report <- c(
    paste0("# Gen5.1 Selection-Policy x Basket-Archetype Screen: ", spec$screen_label),
    "",
    "## Plain-Language Purpose",
    "",
    "This screen tests a narrow architectural question across a declared basket archetype: after pooled PCA creates shared market states, should Gen5.1 choose the best full strategy separately for each asset/state, or should it first choose the best strategy family for the state from pooled TRAIN evidence and only then choose asset-level parameters?",
    "",
    "The purpose is not to crown a live allocation. It is to see whether the policy fork changes behavior consistently across basket types and market windows, while holding context construction, PCA, state map, strategy grid, replay mechanics, and continuity rules fixed within each screen.",
    "",
    "## Scope Note",
    "",
    spec$interpretation_note,
    "",
    "## Run Spec",
    "",
    paste0("- Screen ID: `", spec$screen_id, "`"),
    paste0("- Evidence role: `", spec$evidence_role, "`"),
    paste0("- Basket archetype: `", spec$basket_archetype, "`"),
    paste0("- Symbols: `", paste(spec$symbols, collapse = ","), "`"),
    paste0("- Context universe: `", paste(spec$context_symbols, collapse = ","), "`"),
    paste0("- Context history policy: `", if ("VXX" %in% spec$context_symbols) "recent context includes VXX" else "long-history context omits VXX to avoid partial-history TRAIN context", "`"),
    "- PCA surface: long/pooled asset-day PCA (`pooled_asset_day`)",
    "- State map: `3x3` quantile grid",
    "- Strategy grid: broad Gen5.1 research families with Gen4 `daily_default` parameter breadth",
    paste0("- Replay windows: `", paste(spec$replay_windows$window_id, collapse = ","), "`"),
    "",
    "## Selection-Map Agreement",
    "",
    md_table(agreement_summary, c("quarter_id", "state_asset_rows", "family_match_count", "family_match_rate", "spec_match_count", "spec_match_rate")),
    "",
    "## Portfolio-Proxy Inspection Summary",
    "",
    "Compact replay summaries are inspection aids only. They help identify path-dependent behavior worth reviewing in the charts and ledgers.",
    "",
    md_table(portfolio_proxy, c("window_id", "selection_policy", "symbol_count", "trade_count", "open_trade_count", "equal_symbol_mean_compound_trace_return", "worst_symbol_compound_trace_return", "best_symbol_compound_trace_return")),
    "",
    "## Graphics",
    "",
    paste0("- Visual summary folder: `", visual_paths$output_dir, "`"),
    paste0("- Metric dashboard: `", visual_paths$paths$metric_dashboard_png, "`"),
    paste0("- Symbol return delta heatmap: `", visual_paths$paths$return_heatmap_png, "`"),
    paste0("- Return scatter: `", visual_paths$paths$return_scatter_png, "`"),
    paste0("- State churn map: `", visual_paths$paths$churn_map_png, "`"),
    paste0("- Equity proxy overlay: `", visual_paths$paths$equity_proxy_png, "`"),
    "",
    "## Leakage Guardrails",
    "",
    "- Authority is rebuilt per quarter from TRAIN-only dates.",
    "- Pooled family selection uses only TRAIN performance rows.",
    "- Asset parameter selection inside the pooled family uses only TRAIN performance rows.",
    "- OOS replay consumes frozen maps only.",
    "- Live bridge behavior is not changed by this screen."
  )
  writeLines(unlist(report), paths$report_md, useBytes = TRUE)

  list(
    screen_dir = normalizePath(screen_dir, winslash = "/", mustWork = FALSE),
    run_spec = run_spec,
    agreement_summary = agreement_summary,
    portfolio_proxy = portfolio_proxy,
    trade_summary = trade_summary,
    packet_index = packet_index,
    paths = paths,
    visual_paths = visual_paths
  )
}

message("Gen5.1 selection-policy x basket-archetype screen")
message("Output root: ", root_output_dir)
message("Feed: ", cfg$feed)
message("Refresh: ", refresh)

screen_results <- lapply(screen_specs, run_screen)
names(screen_results) <- vapply(screen_specs, function(x) x$screen_id, character(1L))

master_run_spec <- g5_wfa_bind_rows_fill(lapply(screen_results, function(x) x$run_spec))
master_agreement <- g5_wfa_bind_rows_fill(lapply(screen_results, function(x) x$agreement_summary))
master_portfolio <- g5_wfa_bind_rows_fill(lapply(screen_results, function(x) x$portfolio_proxy))
master_trade_summary <- g5_wfa_bind_rows_fill(lapply(screen_results, function(x) x$trade_summary))
master_packet_index <- g5_wfa_bind_rows_fill(lapply(screen_results, function(x) x$packet_index))

master_paths <- list(
  run_spec_csv = file.path(root_output_dir, "selection_policy_basket_archetype_run_spec.csv"),
  agreement_summary_csv = file.path(root_output_dir, "selection_policy_basket_archetype_agreement_summary.csv"),
  portfolio_proxy_csv = file.path(root_output_dir, "selection_policy_basket_archetype_portfolio_proxy_summary.csv"),
  trade_summary_csv = file.path(root_output_dir, "selection_policy_basket_archetype_trade_summary.csv"),
  packet_index_csv = file.path(root_output_dir, "selection_policy_basket_archetype_packet_index.csv"),
  report_md = file.path(root_output_dir, "selection_policy_basket_archetype_report.md")
)
g5_wfa_write_csv(master_run_spec, master_paths$run_spec_csv)
g5_wfa_write_csv(master_agreement, master_paths$agreement_summary_csv)
g5_wfa_write_csv(master_portfolio, master_paths$portfolio_proxy_csv)
g5_wfa_write_csv(master_trade_summary, master_paths$trade_summary_csv)
g5_wfa_write_csv(master_packet_index, master_paths$packet_index_csv)

report <- c(
  "# Gen5.1 Selection-Policy x Basket-Archetype Packet",
  "",
  "## Purpose",
  "",
  "This packet broadens the Gen4-style pooled-family versus direct-spec selection comparison by treating basket archetype as an explicit research factor. The goal is to learn whether the selection-policy tradeoff is live-basket-specific, high-beta-single-name-specific, or visible even in a more liquid ETF/sector proxy basket.",
  "",
  "## Screens",
  "",
  md_table(master_run_spec, c("screen_id", "evidence_role", "basket_archetype", "symbols", "authority_quarters", "replay_windows")),
  "",
  "## Agreement Summary",
  "",
  md_table(master_agreement, c("screen_id", "quarter_id", "state_asset_rows", "family_match_rate", "spec_match_rate")),
  "",
  "## Portfolio-Proxy Summary",
  "",
  md_table(master_portfolio, c("screen_id", "window_id", "selection_policy", "trade_count", "open_trade_count", "equal_symbol_mean_compound_trace_return", "worst_symbol_compound_trace_return", "best_symbol_compound_trace_return")),
  "",
  "## Interpretation Guardrail",
  "",
  "Screen A is the current live-like basket comparison. Screens B and C are generalization probes that deliberately change the basket to obtain older-history and non-single-name evidence. Do not merge the lanes into one winner table without preserving those evidentiary roles.",
  "",
  "## Artifact Roots",
  "",
  unlist(lapply(screen_results, function(x) paste0("- `", x$screen_dir, "`"))),
  "",
  "## STOP Decisions",
  "",
  "- Whether future research screens should keep direct-spec and pooled-family selection as a declared factor.",
  "- Whether future context-universe/state-map factorial screens should include selection policy as a declared factor.",
  "- Whether basket archetype evidence is strong enough to motivate asset-universe research, or whether the next slice should stay on the current active basket."
)
writeLines(unlist(report), master_paths$report_md, useBytes = TRUE)

message("")
message("Basket-archetype screen complete:")
print(data.frame(master_paths), row.names = FALSE)
message("")
message("Agreement summary:")
print(master_agreement, row.names = FALSE)
message("")
message("Portfolio proxy:")
print(master_portfolio, row.names = FALSE)
