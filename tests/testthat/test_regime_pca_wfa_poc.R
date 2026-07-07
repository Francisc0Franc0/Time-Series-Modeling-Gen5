source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_multifold.R"))
source(test_path("..", "..", "R", "regime_pca_poc.R"))
source(test_path("..", "..", "R", "regime_pca_wfa_poc.R"))

g5_test_pca_wfa_bars <- function(n = 520L, symbol = "AMD", start = as.Date("2024-01-02")) {
  i <- seq_len(n)
  close <- 100 + 0.12 * i + 10 * sin(i / 21) + 4 * sin(i / 5)
  open <- close * (1 + 0.003 * sin(i / 7))
  high <- pmax(open, close) * 1.012
  low <- pmin(open, close) * 0.988
  dates <- start + i - 1L
  data.frame(
    symbol = symbol,
    session_date = dates,
    open = open,
    high = high,
    low = low,
    close = close,
    volume = 1000000 + i,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "test",
    as_of_timestamp = "2026-06-24 17:30:00",
    latest_completed_session = max(dates),
    fetch_start_date = min(dates),
    fetch_end_date = max(dates),
    data_version_hash = paste0("h", i),
    stringsAsFactors = FALSE
  )
}

g5_test_pca_wfa_quarters_for_days <- function(days) {
  as.numeric(days) / (365.25 / 4)
}

g5_test_pca_wfa_context_bars <- function(n = 760L) {
  amd <- g5_test_pca_wfa_bars(n = n, symbol = "AMD")
  nvda <- g5_test_pca_wfa_bars(n = n, symbol = "NVDA")
  nvda$close <- nvda$close * (1.15 + 0.04 * sin(seq_len(n) / 31))
  nvda$open <- nvda$open * (1.15 + 0.04 * sin(seq_len(n) / 31))
  nvda$high <- nvda$high * (1.15 + 0.04 * sin(seq_len(n) / 31))
  nvda$low <- nvda$low * (1.15 + 0.04 * sin(seq_len(n) / 31))
  tsla <- g5_test_pca_wfa_bars(n = n, symbol = "TSLA")
  tsla$close <- tsla$close * (0.85 + 0.05 * cos(seq_len(n) / 27))
  tsla$open <- tsla$open * (0.85 + 0.05 * cos(seq_len(n) / 27))
  tsla$high <- tsla$high * (0.85 + 0.05 * cos(seq_len(n) / 27))
  tsla$low <- tsla$low * (0.85 + 0.05 * cos(seq_len(n) / 27))
  rbind(amd, nvda, tsla)
}

test_that("Gen5.2 direct selector uses shared trade-count eligibility and score ranking", {
  rows <- data.frame(
    symbol = "AMD",
    fold_id = "F1",
    fold_no = 1L,
    state_id = "S1_1",
    strategy_family = c("no_trade", "ema_trend", "ema_trend"),
    model_instance_id = c("no_trade", "fast_sparse", "steady"),
    exit_stack_id = "native_only",
    strategy_spec_id = c("no_trade", "fast_sparse", "steady"),
    sharpe = c(NA, 9.0, 1.0),
    total_return = c(0, 0.90, 0.10),
    train_state_row_count = 50L,
    train_state_trade_count = c(0L, 1L, 5L),
    stringsAsFactors = FALSE
  )

  winner <- g5_pca_wfa_choose_direct_state_winner(
    rows,
    no_trade_row = rows[rows$strategy_family == "no_trade", , drop = FALSE],
    min_train_state_rows = 20L,
    min_train_trades = 5L
  )

  expect_equal(winner$strategy_spec_id[[1L]], "steady")
  expect_equal(winner$selection_policy_recipe[[1L]], "gen52_direct_spec_min_trades_score_then_return")
  expect_match(winner$selection_reason[[1L]], "gen52_direct_spec_ranked_by_score_then_return_min_trades_5")
})

test_that("PCA-routed one-fold WFA selects one spec per state with entry-state ownership", {
  bars <- g5_test_pca_wfa_bars()
  wfa <- g5_pca_wfa_run_one_fold(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = c(3L, 5L),
    slow_periods = c(12L, 20L),
    bb_lookback_periods = 10L,
    bb_sd_multipliers = 1.5,
    candidate_families = c("ema_cross", "bollinger_touch", "no_trade"),
    train_quarters = g5_test_pca_wfa_quarters_for_days(380),
    oos_quarters = g5_test_pca_wfa_quarters_for_days(60),
    grid_n = 3L,
    min_train_state_rows = 5L
  )

  expect_equal(nrow(wfa$folds), 1L)
  expect_equal(nrow(wfa$selected_states), 9L)
  expect_equal(sort(wfa$selected_states$state_id), sort(g5_pca_wfa_all_states(3L)))
  expect_true(all(wfa$selected_states$ownership_policy == "entry_state_owns_trade_until_exit"))
  expect_true(all(c("ema_cross", "bollinger_touch", "no_trade") %in% unique(wfa$train_state_performance$strategy_family)))
  expect_true(all(c("entry_state_id", "ownership_policy") %in% names(wfa$oos_trades)) || nrow(wfa$oos_trades) == 0L)
  if (nrow(wfa$oos_trades) > 0L) {
    expect_true(all(wfa$oos_trades$ownership_policy == "entry_state_owns_trade_until_exit"))
  }
  expect_true(all(c("total_return", "sharpe", "max_drawdown", "buy_hold_total_return") %in% names(wfa$oos_metrics)))
  expect_equal(min(wfa$oos_equity_curve$session_date), min(wfa$folds$oos_start_date))
  expect_equal(max(wfa$oos_equity_curve$session_date), max(wfa$folds$oos_end_date))
})

test_that("PCA-routed multi-fold WFA stitches fold-local state routers", {
  bars <- g5_test_pca_wfa_bars(n = 760L)
  wfa <- g5_pca_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = c(3L, 5L),
    slow_periods = c(12L, 20L),
    bb_lookback_periods = 10L,
    bb_sd_multipliers = 1.5,
    candidate_families = c("ema_cross", "bollinger_touch", "no_trade"),
    train_quarters = g5_test_pca_wfa_quarters_for_days(380),
    oos_quarters = g5_test_pca_wfa_quarters_for_days(60),
    fold_count = 3L,
    grid_n = 3L,
    min_train_state_rows = 5L
  )

  expect_equal(nrow(wfa$folds), 3L)
  expect_equal(nrow(wfa$selected_states), 27L)
  expect_equal(sort(unique(wfa$selected_states$fold_id)), sort(wfa$folds$fold_id))
  expect_equal(sort(unique(wfa$pca_model_contract$fold_id)), sort(wfa$folds$fold_id))
  expect_true(all(c("fold_id", "fold_no", "state_id", "split") %in% names(wfa$pca_scores)))
  expect_equal(min(wfa$oos_equity_curve$session_date), min(wfa$folds$oos_start_date))
  expect_equal(max(wfa$oos_equity_curve$session_date), max(wfa$folds$oos_end_date))
  expect_true(all(wfa$selected_states$ownership_policy == "entry_state_owns_trade_until_exit"))
  if (nrow(wfa$oos_trades) > 0L) {
    expect_true(all(c("entry_signal_fold_id", "entry_execution_fold_id", "exit_signal_fold_id", "exit_execution_fold_id", "carried_across_fold_boundary") %in% names(wfa$oos_trades)))
    expect_true(all(wfa$oos_trades$ownership_policy == "entry_state_owns_trade_until_exit"))
  }
})

test_that("PCA k-means-routed multi-fold WFA reuses the same downstream router contract", {
  bars <- g5_test_pca_wfa_bars(n = 760L)
  wfa <- g5_pca_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = c(3L, 5L),
    slow_periods = c(12L, 20L),
    bb_lookback_periods = 10L,
    bb_sd_multipliers = 1.5,
    candidate_families = c("ema_cross", "bollinger_touch", "no_trade"),
    train_quarters = g5_test_pca_wfa_quarters_for_days(380),
    oos_quarters = g5_test_pca_wfa_quarters_for_days(60),
    fold_count = 3L,
    grid_n = 5L,
    state_engine = "pca_kmeans",
    kmeans_nstart = 5L,
    min_train_state_rows = 5L
  )

  expect_equal(nrow(wfa$folds), 3L)
  expect_equal(nrow(wfa$selected_states), 15L)
  expect_equal(sort(unique(wfa$selected_states$state_id)), g5_pca_regime_kmeans_states(5L))
  expect_equal(wfa$settings$state_engine, "pca_kmeans")
  expect_true(all(c("cluster_raw", "cluster_distance", "state_id", "split") %in% names(wfa$pca_scores)))
  expect_equal(min(wfa$oos_equity_curve$session_date), min(wfa$folds$oos_start_date))
  expect_equal(max(wfa$oos_equity_curve$session_date), max(wfa$folds$oos_end_date))
  expect_true(all(wfa$selected_states$ownership_policy == "entry_state_owns_trade_until_exit"))
})

test_that("PCA auto k-means-routed WFA records train-only selected cluster counts", {
  bars <- g5_test_pca_wfa_bars(n = 760L)
  wfa <- g5_pca_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = c(3L, 5L),
    slow_periods = c(12L, 20L),
    bb_lookback_periods = 10L,
    bb_sd_multipliers = 1.5,
    candidate_families = c("ema_cross", "bollinger_touch", "no_trade"),
    train_quarters = g5_test_pca_wfa_quarters_for_days(380),
    oos_quarters = g5_test_pca_wfa_quarters_for_days(60),
    fold_count = 3L,
    grid_n = 6L,
    state_engine = "pca_kmeans_auto",
    kmeans_nstart = 3L,
    min_train_state_rows = 5L
  )
  meta <- wfa$pca_model_contract[wfa$pca_model_contract$record_type == "meta", , drop = FALSE]

  expect_equal(wfa$settings$state_engine, "pca_kmeans_auto")
  expect_true(all(c("cluster_raw", "cluster_distance", "state_id", "split") %in% names(wfa$pca_scores)))
  expect_true(any(meta$key == "cluster_count_mode" & meta$value == "auto"))
  expect_true(any(meta$key == "auto_selection_criterion" & meta$value == "calinski_harabasz_train_pc1_pc2"))
  selected_k <- as.integer(meta$value[meta$key == "cluster_count"])
  expect_true(all(selected_k >= 2L & selected_k <= 6L))
  expect_equal(min(wfa$oos_equity_curve$session_date), min(wfa$folds$oos_start_date))
  expect_equal(max(wfa$oos_equity_curve$session_date), max(wfa$folds$oos_end_date))
})

test_that("PCA-routed WFA can use a multi-asset regime context while trading one symbol", {
  bars <- g5_test_pca_wfa_context_bars()
  wfa <- g5_pca_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = c(3L, 5L),
    slow_periods = c(12L, 20L),
    bb_lookback_periods = 10L,
    bb_sd_multipliers = 1.5,
    candidate_families = c("ema_cross", "bollinger_touch", "no_trade"),
    train_quarters = g5_test_pca_wfa_quarters_for_days(380),
    oos_quarters = g5_test_pca_wfa_quarters_for_days(60),
    fold_count = 2L,
    grid_n = 3L,
    regime_context_symbols = c("AMD", "NVDA", "TSLA"),
    min_train_state_rows = 5L
  )

  expect_equal(nrow(wfa$folds), 2L)
  expect_equal(wfa$settings$regime_context_symbols, c("AMD", "NVDA", "TSLA"))
  expect_equal(wfa$settings$research_candidate_universe, "AMD")
  expect_true(all(grepl("AMD,NVDA,TSLA", wfa$pca_scores$regime_context_symbols)))
  expect_true(any(grepl("^NVDA__", wfa$pca_model_contract$feature)))
  expect_true(any(grepl("^TSLA__", wfa$pca_model_contract$feature)))
  if (nrow(wfa$oos_trades) > 0L) {
    expect_true(all(wfa$oos_trades$symbol == "AMD"))
  }
})

test_that("PCA-routed WFA can train pooled asset-day states while routing one symbol", {
  bars <- g5_test_pca_wfa_context_bars()
  wfa <- g5_pca_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = c(3L, 5L),
    slow_periods = c(12L, 20L),
    bb_lookback_periods = 10L,
    bb_sd_multipliers = 1.5,
    candidate_families = c("ema_cross", "bollinger_touch", "no_trade"),
    train_quarters = g5_test_pca_wfa_quarters_for_days(380),
    oos_quarters = g5_test_pca_wfa_quarters_for_days(60),
    fold_count = 2L,
    grid_n = 3L,
    regime_context_symbols = c("AMD", "NVDA", "TSLA"),
    pca_panel_mode = "pooled_asset_day",
    min_train_state_rows = 5L
  )

  expect_equal(wfa$settings$pca_panel_mode, "pooled_asset_day")
  expect_equal(wfa$settings$regime_context_symbols, c("AMD", "NVDA", "TSLA"))
  expect_true(all(wfa$pca_scores$symbol == "AMD"))
  expect_true(all(wfa$pca_scores$pca_panel_mode == "pooled_asset_day"))
  expect_false(any(grepl("^NVDA__", wfa$pca_model_contract$feature)))
  expect_false(any(grepl("^TSLA__", wfa$pca_model_contract$feature)))
  expect_true(any(wfa$pca_model_contract$pca_panel_mode == "pooled_asset_day"))
  expect_true(any(wfa$pca_model_contract$routing_symbol == "AMD"))
  if (nrow(wfa$oos_trades) > 0L) {
    expect_true(all(wfa$oos_trades$symbol == "AMD"))
  }
})

test_that("PCA-routed WFA output PNGs render", {
  bars <- g5_test_pca_wfa_bars()
  wfa <- g5_pca_wfa_run_one_fold(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 3L,
    slow_periods = 12L,
    bb_lookback_periods = 10L,
    bb_sd_multipliers = 1.5,
    candidate_families = c("ema_cross", "no_trade"),
    train_quarters = g5_test_pca_wfa_quarters_for_days(380),
    oos_quarters = g5_test_pca_wfa_quarters_for_days(60),
    grid_n = 3L,
    min_train_state_rows = 5L
  )
  price_path <- tempfile("g5_pca_wfa_price_", fileext = ".png")
  equity_path <- tempfile("g5_pca_wfa_equity_", fileext = ".png")
  scatter_path <- tempfile("g5_pca_wfa_scatter_", fileext = ".png")

  written_price <- g5_pca_wfa_write_state_price_chart_png(wfa, "AMD", price_path)
  written_equity <- g5_pca_wfa_write_equity_png(wfa$oos_equity_curve, equity_path, "AMD")
  written_scatter <- g5_pca_wfa_write_pca_scatter_png(wfa, scatter_path, "AMD")

  expect_true(file.exists(written_price))
  expect_true(file.exists(written_equity))
  expect_true(file.exists(written_scatter))
  expect_gt(file.info(written_price)$size, 0)
  expect_gt(file.info(written_equity)$size, 0)
  expect_gt(file.info(written_scatter)$size, 0)
  expect_identical(as.integer(readBin(written_price, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_equity, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_scatter, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})
