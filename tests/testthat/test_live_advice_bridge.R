source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_multifold.R"))
source(test_path("..", "..", "R", "regime_pca_poc.R"))
source(test_path("..", "..", "R", "regime_pca_wfa_poc.R"))
source(test_path("..", "..", "R", "live_advice_bridge.R"))

test_that("bridge authority dates use traditional quarter boundaries", {
  dates <- g5_bridge_authority_contract_dates("2026Q3", train_quarters = 8L)

  expect_equal(dates$train_start_date, as.Date("2024-07-01"))
  expect_equal(dates$train_end_date, as.Date("2026-06-30"))
  expect_equal(dates$live_start_date, as.Date("2026-07-01"))
  expect_equal(dates$live_end_date, as.Date("2026-09-30"))
  expect_equal(g5_bridge_next_quarter_id("2026Q4"), "2027Q1")
})

test_that("bridge contract separates live symbols from context symbols", {
  contract <- g5_bridge_contract_frame(
    quarter_id = "2026Q3",
    symbols = c("AMD", "NVDA"),
    context_symbols = c("SPY", "QQQ", "AMD", "NVDA"),
    as_of_timestamp = "2026-06-30 17:30:00",
    refresh = FALSE,
    market_data_feed = "iex"
  )

  expect_equal(contract$symbols[[1L]], "AMD,NVDA")
  expect_equal(contract$context_symbols[[1L]], "SPY,QQQ,AMD,NVDA")
  expect_equal(contract$market_data_feed[[1L]], "iex")
  expect_equal(contract$candidate_families[[1L]], paste(g5_bridge_default_candidate_families(), collapse = ","))
  expect_equal(contract$strategy_grid_preset[[1L]], "gen4_daily_default")
})

test_that("bridge model grid defaults to the Gen4 daily_default implemented subset", {
  grid <- g5_bridge_model_grid()
  families <- sort(unique(grid$strategy_family))

  expect_setequal(
    families,
    sort(g5_bridge_default_candidate_families())
  )
  expect_false(any(c("bollinger_mid_reversion", "vol_expansion_breakout", "donchian_breakout_vol_expand") %in% families))
  expect_true("ema_cross_fast1_slow10" %in% grid$model_instance_id)
  expect_true("ema_trend_fast20_slow50" %in% grid$model_instance_id)
  expect_true("bollinger_touch_n14_sd1p5" %in% grid$model_instance_id)
  expect_true("rsi_mr_n21_lo35_hi75" %in% grid$model_instance_id)
  expect_true("zret_mr_n40_ent2p5_ex1" %in% grid$model_instance_id)
  expect_true("breakout_lb30_buf0" %in% grid$model_instance_id)
  expect_true("pullback_up_f15_s75_lo40_hi65" %in% grid$model_instance_id)
})

test_that("trade trace segments clip off-chart entries into the visible panel", {
  dates <- as.Date("2026-07-01") + 0:4
  trades <- data.frame(
    symbol = "AMD",
    trade_status = "open",
    entry_execution_date = as.Date("2026-06-29"),
    entry_execution_price = 100,
    exit_execution_date = as.Date(NA),
    exit_execution_price = NA_real_,
    trace_end_date = as.Date("2026-07-05"),
    trace_end_price = 112,
    trade_outcome = "win",
    strategy_spec_id = "fixture",
    stringsAsFactors = FALSE
  )

  segments <- g5_bridge_visible_trade_segments(trades, dates)

  expect_equal(nrow(segments), 1L)
  expect_equal(segments$x0[[1L]], 1)
  expect_equal(segments$x1[[1L]], 5)
  expect_equal(segments$y0[[1L]], 104)
  expect_equal(segments$y1[[1L]], 112)
})

test_that("frozen quantile scoring uses contract centers, loadings, and break rows", {
  features <- data.frame(
    schema_version = "fixture",
    symbol = c("AMD", "AMD", "NVDA"),
    session_date = as.Date("2026-07-01") + 0:2,
    open = 1:3,
    high = 1:3,
    low = 1:3,
    close = 1:3,
    volume = 100,
    f1 = c(-2, 2, 0),
    f2 = c(0, 0, 3),
    f3 = c(0, 0, 0),
    stringsAsFactors = FALSE
  )
  contract <- rbind(
    data.frame(
      record_type = "feature",
      feature = c("f1", "f2", "f3"),
      center = c(0, 0, 0),
      scale = c(1, 1, 1),
      loading_pc1 = c(1, 0, 0),
      loading_pc2 = c(0, 1, 0),
      break_axis = NA_character_,
      break_index = NA_integer_,
      break_value = NA_real_,
      key = NA_character_,
      value = NA_character_,
      research_candidate_symbol = "AMD",
      symbol = "AMD",
      stringsAsFactors = FALSE
    ),
    data.frame(
      record_type = "pc_break",
      feature = NA_character_,
      center = NA_real_,
      scale = NA_real_,
      loading_pc1 = NA_real_,
      loading_pc2 = NA_real_,
      break_axis = rep(c("pc1", "pc2"), each = 3L),
      break_index = rep(1:3, times = 2L),
      break_value = c(-2, 0, 2, -2, 0, 2),
      key = NA_character_,
      value = NA_character_,
      research_candidate_symbol = "AMD",
      symbol = "AMD",
      stringsAsFactors = FALSE
    ),
    data.frame(
      record_type = "meta",
      feature = NA_character_,
      center = NA_real_,
      scale = NA_real_,
      loading_pc1 = NA_real_,
      loading_pc2 = NA_real_,
      break_axis = NA_character_,
      break_index = NA_integer_,
      break_value = NA_real_,
      key = "grid_n",
      value = "2",
      research_candidate_symbol = "AMD",
      symbol = "AMD",
      stringsAsFactors = FALSE
    )
  )

  scored <- g5_bridge_score_frozen_quantile(features, contract, "AMD")

  expect_equal(nrow(scored), 2L)
  expect_equal(scored$state_id, c("S1_1", "S2_1"))
})
