source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_multifold.R"))

g5_test_wfa_multi_bars <- function(symbol = "AMD", close) {
  dates <- as.Date("2026-01-01") + seq_along(close) - 1L
  g5_test_wfa_multi_bars_for_dates(symbol = symbol, dates = dates, close = close)
}

g5_test_wfa_multi_bars_for_dates <- function(symbol = "AMD", dates, close) {
  data.frame(
    symbol = symbol,
    session_date = dates,
    open = close + 0.1,
    high = close + 1,
    low = close - 1,
    close = close,
    volume = seq_along(close) * 1000,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-24 17:30:00",
    latest_completed_session = max(dates),
    fetch_start_date = min(dates),
    fetch_end_date = max(dates),
    data_version_hash = paste0("h", seq_along(close)),
    stringsAsFactors = FALSE
  )
}

g5_test_multi_quarters_for_days <- function(days) {
  as.numeric(days) / (365.25 / 4)
}

test_that("multi-fold EMA WFA resolves rolling non-overlapping OOS folds", {
  bars <- g5_test_wfa_multi_bars(close = seq(10, 40, length.out = 35))

  folds <- g5_ema_cross_wfa_resolve_folds(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 3L
  )

  expect_equal(nrow(folds), 3L)
  expect_equal(folds$fold_id, c("fold_001", "fold_002", "fold_003"))
  expect_equal(folds$train_start_date, as.Date(c("2026-01-01", "2026-01-06", "2026-01-11")))
  expect_equal(folds$train_end_date, as.Date(c("2026-01-10", "2026-01-15", "2026-01-20")))
  expect_equal(folds$oos_start_date, as.Date(c("2026-01-11", "2026-01-16", "2026-01-21")))
  expect_equal(folds$oos_end_date, as.Date(c("2026-01-15", "2026-01-20", "2026-01-25")))
  expect_true(all(folds$oos_start_date[-1L] > folds$oos_end_date[-nrow(folds)]))
})

test_that("multi-signal WFA artifact prefix no longer uses EMA-only naming", {
  prefix <- g5_ema_cross_wfa_multi_artifact_prefix(
    as_of_timestamp = "2026-06-24 17:30:00",
    symbol = "AMD",
    wfa_start_date = as.Date("2023-09-23"),
    wfa_end_date = as.Date("2026-06-24"),
    fold_count = 3L,
    candidate_families = c("vol_expansion_breakout", "donchian_breakout_vol_expand")
  )

  expect_true(startsWith(prefix, "multi_wfa_AMD_3f_2fam_"))
  expect_false(grepl("ema_wfa3", prefix, fixed = TRUE))
})

test_that("exit stack grid names curated close-based stacks", {
  stacks <- g5_wfa_exit_stack_grid(max_hold_sessions = c(5L, 10L, 20L), stop_loss_pcts = 0.10, take_profit_pcts = 0.25)

  expect_true("native_only" %in% stacks$exit_stack_id)
  expect_true("native_maxhold5" %in% stacks$exit_stack_id)
  expect_true("native_stop10pct_take25pct_maxhold20" %in% stacks$exit_stack_id)
  expect_equal(nrow(stacks), length(unique(stacks$exit_stack_id)))
})

test_that("exit stack arbitration uses earliest close signal with risk-first same-bar attribution", {
  ind <- data.frame(
    close = 90,
    exit_signal = TRUE,
    stringsAsFactors = FALSE
  )
  open_trade <- list(entry_execution_price = 100, entry_execution_idx = 1L)
  stack <- data.frame(
    exit_stack_id = "native_stop10pct_maxhold1",
    include_native_exit = TRUE,
    max_hold_sessions = 1L,
    stop_loss_pct = 0.10,
    take_profit_pct = NA_real_,
    stringsAsFactors = FALSE
  )

  event <- g5_wfa_exit_event(ind, 1L, open_trade, stack)

  expect_equal(event$primary_exit_reason, "stop_loss")
  expect_equal(event$exit_attribution, "exit_stack")
  expect_true(grepl("native_exit", event$triggered_exit_rules, fixed = TRUE))
  expect_true(grepl("max_hold", event$triggered_exit_rules, fixed = TRUE))
})

test_that("multi-fold EMA WFA rolls OOS folds by available sessions without overlap gaps", {
  dates <- as.Date("2026-01-01") + 0:60
  dates <- dates[!weekdays(dates) %in% c("Saturday", "Sunday")]
  bars <- g5_test_wfa_multi_bars_for_dates(close = seq(10, 60, length.out = length(dates)), dates = dates)

  folds <- g5_ema_cross_wfa_resolve_folds(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(10),
    fold_count = 3L
  )

  for (i in 2:nrow(folds)) {
    expected_start <- min(dates[dates > folds$oos_end_date[[i - 1L]]])
    expect_equal(folds$oos_start_date[[i]], expected_start)
    expect_gt(folds$oos_start_date[[i]], folds$oos_end_date[[i - 1L]])
  }
})

test_that("multi-fold EMA WFA fails loudly when three folds cannot fit", {
  bars <- g5_test_wfa_multi_bars(close = seq(10, 25, length.out = 16))

  expect_error(
    g5_ema_cross_wfa_resolve_folds(
      bars,
      symbol = "AMD",
      wfa_start_date = min(bars$session_date),
      wfa_end_date = max(bars$session_date),
      train_quarters = g5_test_multi_quarters_for_days(10),
      oos_quarters = g5_test_multi_quarters_for_days(5),
      fold_count = 3L
    ),
    "Insufficient data"
  )
})

test_that("multi-fold EMA WFA selects a model instance per fold and stitches OOS equity", {
  close <- c(
    10, 9, 8, 8, 9, 11, 13, 14, 13, 12,
    10, 8, 7, 8, 9, 10, 12, 14, 13, 11,
    10, 9, 11, 13, 15, 14, 13, 12, 14, 16,
    18, 17, 16, 18, 20
  )
  bars <- g5_test_wfa_multi_bars(close = close)

  wfa <- g5_ema_cross_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 2L,
    slow_periods = 4L,
    candidate_families = "ema_cross",
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 3L
  )

  expect_equal(nrow(wfa$folds), 3L)
  expect_equal(nrow(wfa$selected_models), 3L)
  expect_true(all(wfa$selected_models$strategy_family == "ema_cross"))
  expect_true(all(wfa$selected_models$model_instance_id == "ema_cross_fast2_slow4"))
  expect_true(all(c("exit_stack_id", "strategy_spec_id") %in% names(wfa$selected_models)))
  expect_true(all(c("exit_stack_id", "strategy_spec_id") %in% names(wfa$train_parameter_performance)))
  expect_equal(min(wfa$stitched_equity_curve$session_date), min(wfa$folds$oos_start_date))
  expect_equal(max(wfa$stitched_equity_curve$session_date), max(wfa$folds$oos_end_date))
  expect_equal(nrow(wfa$fold_oos_summary), 3L)
  expect_equal(wfa$model_stability$selected_fold_count[[1L]], 3L)
  expect_true("carried_across_fold_boundary" %in% names(wfa$stitched_trades) || nrow(wfa$stitched_trades) == 0L)
})

test_that("multi-fold WFA can evaluate EMA cross and Bollinger touch candidates together", {
  close <- c(
    10, 10, 10, 9, 7, 8, 11, 13, 15, 13,
    11, 9, 7, 8, 10, 12, 15, 14, 12, 10,
    8, 7, 9, 12, 14, 16, 13, 11, 9, 8,
    10, 13, 15, 14, 12, 10, 8, 9, 12, 15,
    17, 15, 13, 11, 10
  )
  bars <- g5_test_wfa_multi_bars(close = close)

  wfa <- g5_ema_cross_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 2L,
    slow_periods = 4L,
    bb_lookback_periods = c(3L, 4L),
    bb_sd_multipliers = c(1, 1.5),
    candidate_families = c("ema_cross", "bollinger_touch"),
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 3L
  )

  expect_equal(nrow(wfa$selected_models), 3L)
  expect_true(all(c("ema_cross", "bollinger_touch") %in% unique(wfa$train_parameter_performance$strategy_family)))
  expect_true(all(wfa$selected_models$strategy_family %in% c("ema_cross", "bollinger_touch")))
  expect_true(all(c("lookback_period", "sd_multiplier") %in% names(wfa$selected_models)))
  expect_true(all(c("exit_stack_id", "strategy_spec_id") %in% names(wfa$selected_models)))
})

test_that("Gen4-inspired WFA candidate grid keeps Bollinger variants distinct", {
  grid <- g5_wfa_candidate_model_grid(
    fast_periods = 2L,
    slow_periods = 4L,
    bb_lookback_periods = 3L,
    bb_sd_multipliers = 1,
    ema_trend_fast_periods = 2L,
    ema_trend_slow_periods = 5L,
    rsi_periods = 3L,
    rsi_lower_thresholds = 30,
    rsi_upper_thresholds = 60,
    zret_windows = 3L,
    zret_entry_z = 1.5,
    zret_exit_z = 0.5,
    breakout_lookbacks = 3L,
    breakout_buffers = 0,
    vol_expand_thresholds = 0.1,
    pullback_fast_periods = 2L,
    pullback_slow_periods = 5L,
    pullback_rsi_lower_thresholds = 35,
    pullback_rsi_upper_thresholds = 55,
    candidate_families = c("ema_cross", "ema_trend", "bollinger_touch", "bollinger_mid_reversion", "rsi_mr", "zret_mr", "breakout", "pullback_in_uptrend", "vol_expansion_breakout", "donchian_breakout_vol_expand", "no_trade")
  )

  expect_equal(
    sort(unique(grid$strategy_family)),
    sort(c("ema_cross", "ema_trend", "bollinger_touch", "bollinger_mid_reversion", "rsi_mr", "zret_mr", "breakout", "pullback_in_uptrend", "vol_expansion_breakout", "donchian_breakout_vol_expand", "no_trade"))
  )
  expect_true("bollinger_touch_n3_sd1" %in% grid$model_instance_id)
  expect_true("bollinger_mid_reversion_n3_sd1" %in% grid$model_instance_id)
  expect_true("rsi_mr_n3_lo30_hi60" %in% grid$model_instance_id)
  expect_true("pullback_up_f2_s5_lo35_hi55" %in% grid$model_instance_id)
  expect_true("vol_expansion_breakout_lb3_buf0_vx0p1" %in% grid$model_instance_id)
  expect_true("donchian_volexp_lb3_buf0_vx0p1" %in% grid$model_instance_id)
  expect_true("no_trade" %in% grid$model_instance_id)
  expect_equal(nrow(grid), length(unique(grid$model_instance_id)))
  expect_true(all(c("rsi_period", "zret_window", "breakout_lookback", "breakout_buffer", "vol_expand_threshold") %in% names(grid)))
})

test_that("modest expanded WFA strategy grid preset adds local flexibility", {
  families <- c("ema_cross", "ema_trend", "bollinger_touch", "bollinger_mid_reversion", "rsi_mr", "zret_mr", "breakout", "pullback_in_uptrend", "vol_expansion_breakout", "donchian_breakout_vol_expand", "no_trade")
  standard <- do.call(
    g5_wfa_candidate_model_grid,
    c(
      list(
        fast_periods = c(8L, 12L),
        slow_periods = c(30L, 50L),
        bb_lookback_periods = c(10L, 20L),
        bb_sd_multipliers = c(1.5, 2),
        candidate_families = families
      ),
      g5_wfa_strategy_grid_preset_values("standard")
    )
  )
  expanded <- do.call(
    g5_wfa_candidate_model_grid,
    c(
      list(candidate_families = families),
      g5_wfa_strategy_grid_preset_values("modest_expanded")
    )
  )

  expect_equal(g5_wfa_strategy_grid_preset("modest_expanded"), "modest_expanded")
  expect_gt(nrow(expanded), nrow(standard))
  expect_true("ema_cross_fast16_slow30" %in% expanded$model_instance_id)
  expect_true("ema_trend_fast20_slow25" %in% expanded$model_instance_id)
  expect_true("bollinger_touch_n30_sd2p5" %in% expanded$model_instance_id)
  expect_true("bollinger_mid_reversion_n30_sd2p5" %in% expanded$model_instance_id)
  expect_true("rsi_mr_n14_lo25_hi75" %in% expanded$model_instance_id)
  expect_true("zret_mr_n30_ent2_ex0" %in% expanded$model_instance_id)
  expect_true("breakout_lb40_buf0p005" %in% expanded$model_instance_id)
  expect_true("vol_expansion_breakout_lb40_buf0p005_vx0p2" %in% expanded$model_instance_id)
  expect_true("donchian_volexp_lb40_buf0p005_vx0p2" %in% expanded$model_instance_id)
  expect_true("pullback_up_f15_s25_lo30_hi55" %in% expanded$model_instance_id)
  expect_equal(nrow(expanded), length(unique(expanded$model_instance_id)))
  expect_error(g5_wfa_strategy_grid_preset("wide_open"), "strategy_grid_preset")
})

test_that("WFA numeric ID labels preserve integer zeros", {
  expect_equal(g5_wfa_num_id_label(30), "30")
  expect_equal(g5_wfa_num_id_label(60), "60")
  expect_equal(g5_wfa_num_id_label(2.5), "2p5")
  expect_equal(g5_wfa_num_id_label(0.10), "0p1")
  expect_equal(g5_wfa_num_id_label(-0.25), "m0p25")
})

test_that("Gen4-inspired WFA indicators emit close-based signals", {
  bars <- g5_test_wfa_multi_bars(close = c(10, 11, 12, 13, 14, 13, 12, 13, 14, 15, 16, 17))

  ema_trend <- g5_wfa_model_indicators(
    bars,
    "AMD",
    data.frame(strategy_family = "ema_trend", model_instance_id = "ema_trend_fast2_slow4", fast_period = 2L, slow_period = 4L, stringsAsFactors = FALSE)
  )
  expect_true(any(ema_trend$entry_signal, na.rm = TRUE))
  expect_equal(unique(ema_trend$entry_signal_rule), "fast_ema_above_slow_with_positive_fast_slope_turns_on")

  breakout <- g5_wfa_model_indicators(
    bars,
    "AMD",
    data.frame(strategy_family = "breakout", model_instance_id = "breakout_lb3_buf0", breakout_lookback = 3L, breakout_buffer = 0, stringsAsFactors = FALSE)
  )
  expect_true(any(breakout$entry_signal, na.rm = TRUE))
  expect_true(all(c("breakout_high", "breakout_mid") %in% names(breakout)))

  vol_bars <- g5_test_wfa_multi_bars(close = c(10, 10.1, 10, 10.05, 10, 10.1, 10.05, 11.5, 12, 11.8, 12.2, 12.5))
  vol_expansion <- g5_wfa_model_indicators(
    vol_bars,
    "AMD",
    data.frame(strategy_family = "vol_expansion_breakout", model_instance_id = "vol_expansion_breakout_lb3_buf0_vx0", breakout_lookback = 3L, breakout_buffer = 0, vol_expand_threshold = 0, stringsAsFactors = FALSE)
  )
  expect_true(any(vol_expansion$entry_signal, na.rm = TRUE))
  expect_true(all(c("breakout_high", "breakout_mid", "vol_width", "vol_expansion") %in% names(vol_expansion)))

  donchian <- g5_wfa_model_indicators(
    vol_bars,
    "AMD",
    data.frame(strategy_family = "donchian_breakout_vol_expand", model_instance_id = "donchian_volexp_lb3_buf0_vx0", breakout_lookback = 3L, breakout_buffer = 0, vol_expand_threshold = 0, stringsAsFactors = FALSE)
  )
  expect_true(any(donchian$entry_signal, na.rm = TRUE))
  expect_equal(unique(donchian$entry_signal_rule), "close_above_donchian_high_with_prior_compression_and_vol_expansion_when_flat")

  no_trade <- g5_wfa_model_indicators(
    bars,
    "AMD",
    data.frame(strategy_family = "no_trade", model_instance_id = "no_trade", stringsAsFactors = FALSE)
  )
  expect_false(any(no_trade$entry_signal, na.rm = TRUE))
  expect_false(any(no_trade$exit_signal, na.rm = TRUE))
  expect_equal(unique(no_trade$signal_state), "cash")

  rsi <- g5_wfa_model_indicators(
    g5_test_wfa_multi_bars(close = c(10, 9, 8, 7, 8, 9, 10, 11)),
    "AMD",
    data.frame(strategy_family = "rsi_mr", model_instance_id = "rsi_mr_n3_lo40_hi60", rsi_period = 3L, rsi_lower = 40, rsi_upper = 60, stringsAsFactors = FALSE)
  )
  expect_true(any(rsi$entry_signal, na.rm = TRUE))
  expect_true(any(rsi$exit_signal, na.rm = TRUE))
  expect_equal(unique(rsi$entry_signal_rule), "rsi_below_oversold_threshold_when_flat")
})

test_that("no-trade candidate is inert and uses one cash exit stack", {
  bars <- g5_test_wfa_multi_bars(close = c(10, 9.8, 9.6, 9.5, 9.4, 9.2, 9.1, 9.0, 8.9, 8.8, 8.7, 8.6))
  model_grid <- g5_wfa_candidate_model_grid(
    fast_periods = 2L,
    slow_periods = 4L,
    breakout_lookbacks = 3L,
    breakout_buffers = 0,
    candidate_families = c("breakout", "no_trade")
  )
  exit_stacks <- g5_wfa_exit_stacks_for_candidates(g5_wfa_exit_stack_grid(max_hold_sessions = 3L, stop_loss_pcts = 0.1, take_profit_pcts = 0.2), c("breakout", "no_trade"))
  grid <- g5_wfa_evaluate_strategy_spec_grid(
    bars,
    symbol = "AMD",
    trading_start_date = min(bars$session_date),
    trading_end_date = max(bars$session_date),
    model_grid = model_grid,
    exit_stacks = exit_stacks
  )
  no_trade_rows <- grid[grid$strategy_family == "no_trade", , drop = FALSE]

  expect_equal(nrow(no_trade_rows), 1L)
  expect_equal(no_trade_rows$exit_stack_id[[1L]], "no_exit")
  expect_equal(no_trade_rows$total_return[[1L]], 0)
  expect_equal(no_trade_rows$sharpe[[1L]], 0)
  expect_equal(no_trade_rows$exposure_fraction[[1L]], 0)
  expect_equal(no_trade_rows$trade_count[[1L]], 0L)
})

test_that("stitched indicators tolerate mixed selected model families", {
  close <- c(
    10, 10, 10, 9, 7, 8, 11, 13, 15, 13,
    11, 9, 7, 8, 10, 12, 15, 14, 12, 10,
    8, 7, 9, 12, 14, 16, 13, 11, 9, 8,
    10, 13, 15, 14, 12
  )
  bars <- g5_test_wfa_multi_bars(close = close)
  folds <- g5_ema_cross_wfa_resolve_folds(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 2L
  )
  selected_models <- data.frame(
    schema_version = g5_ema_cross_wfa_multi_schema_version(),
    fold_id = folds$fold_id,
    fold_no = folds$fold_no,
    symbol = "AMD",
    strategy_family = c("ema_cross", "bollinger_touch"),
    model_instance_id = c("ema_cross_fast2_slow4", "bollinger_touch_n3_sd1"),
    exit_stack_id = "native_only",
    strategy_spec_id = c("ema_cross_fast2_slow4__native_only", "bollinger_touch_n3_sd1__native_only"),
    include_native_exit = TRUE,
    max_hold_sessions = NA_integer_,
    stop_loss_pct = NA_real_,
    take_profit_pct = NA_real_,
    fast_period = c(2L, NA_integer_),
    slow_period = c(4L, NA_integer_),
    lookback_period = c(NA_integer_, 3L),
    sd_multiplier = c(NA_real_, 1),
    train_sharpe = 1,
    train_total_return = 0.1,
    train_cagr = 0.1,
    train_max_drawdown = -0.1,
    train_trade_count = 1L,
    stringsAsFactors = FALSE
  )

  indicators <- g5_ema_cross_wfa_stitched_indicators(bars, "AMD", folds, selected_models)

  expect_true(all(c("fast_ema", "slow_ema", "bb_mid", "bb_upper", "bb_lower") %in% names(indicators)))
  expect_true(all(c("ema_cross", "bollinger_touch") %in% unique(indicators$strategy_family)))
})

test_that("multi-fold chart background spans cover plotted folds without side gaps", {
  folds <- data.frame(
    fold_id = c("fold_001", "fold_002", "fold_003"),
    fold_no = 1:3,
    oos_start_date = as.Date(c("2026-01-02", "2026-01-05", "2026-01-08")),
    oos_end_date = as.Date(c("2026-01-04", "2026-01-07", "2026-01-10")),
    stringsAsFactors = FALSE
  )
  session_dates <- as.Date("2026-01-01") + 0:8
  fold_ids <- c(rep("fold_001", 3L), rep("fold_002", 3L), rep("fold_003", 3L))

  spans <- g5_ema_cross_wfa_fold_background_spans(session_dates, folds, fold_ids = fold_ids)

  expect_equal(spans$fold_id, folds$fold_id)
  expect_equal(spans$xleft, c(0.5, 3.5, 6.5))
  expect_equal(spans$xright, c(3.5, 6.5, 9.5))
  expect_equal(spans$fill, c("#FFFFFF", "#F2F3F5", "#FFFFFF"))
})

test_that("multi-fold WFA stitched charts render fold-shaded PNGs", {
  close <- c(
    10, 9, 8, 8, 9, 11, 13, 14, 13, 12,
    10, 8, 7, 8, 9, 10, 12, 14, 13, 11,
    10, 9, 11, 13, 15, 14, 13, 12, 14, 16,
    18, 17, 16, 18, 20
  )
  bars <- g5_test_wfa_multi_bars(close = close)
  wfa <- g5_ema_cross_wfa_run_multi(
    bars,
    symbol = "AMD",
    wfa_start_date = min(bars$session_date),
    wfa_end_date = max(bars$session_date),
    fast_periods = 2L,
    slow_periods = 4L,
    candidate_families = "ema_cross",
    train_quarters = g5_test_multi_quarters_for_days(10),
    oos_quarters = g5_test_multi_quarters_for_days(5),
    fold_count = 3L
  )
  strategy_path <- tempfile("g5_wfa_multi_strategy_", fileext = ".png")
  equity_path <- tempfile("g5_wfa_multi_equity_", fileext = ".png")

  written_strategy <- g5_write_ema_cross_wfa_stitched_strategy_chart_png(wfa$stitched_indicators, wfa$stitched_trades, wfa$folds, "AMD", strategy_path)
  written_equity <- g5_write_ema_cross_wfa_stitched_equity_curve_png(wfa$stitched_equity_curve, wfa$folds, "AMD", equity_path)

  expect_true(file.exists(written_strategy))
  expect_true(file.exists(written_equity))
  expect_gt(file.info(written_strategy)$size, 0)
  expect_gt(file.info(written_equity)$size, 0)
  expect_identical(as.integer(readBin(written_strategy, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_equity, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})
