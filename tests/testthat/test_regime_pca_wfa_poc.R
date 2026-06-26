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

  written_price <- g5_pca_wfa_write_state_price_chart_png(wfa, "AMD", price_path)
  written_equity <- g5_pca_wfa_write_equity_png(wfa$oos_equity_curve, equity_path, "AMD")

  expect_true(file.exists(written_price))
  expect_true(file.exists(written_equity))
  expect_gt(file.info(written_price)$size, 0)
  expect_gt(file.info(written_equity)$size, 0)
  expect_identical(as.integer(readBin(written_price, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_equity, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})
