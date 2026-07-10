source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_multifold.R"))
source(test_path("..", "..", "R", "regime_pca_poc.R"))
source(test_path("..", "..", "R", "regime_pca_wfa_poc.R"))
source(test_path("..", "..", "R", "live_advice_bridge.R"))
source(test_path("..", "..", "R", "selection_policy_screen.R"))

test_that("bridge authority dates use traditional quarter boundaries", {
  dates <- g5_bridge_authority_contract_dates("2026Q3", train_quarters = 8L)

  expect_equal(dates$train_start_date, as.Date("2024-07-01"))
  expect_equal(dates$train_end_date, as.Date("2026-06-30"))
  expect_equal(dates$live_start_date, as.Date("2026-07-01"))
  expect_equal(dates$live_end_date, as.Date("2026-09-30"))
  expect_equal(g5_bridge_next_quarter_id("2026Q4"), "2027Q1")
  expect_equal(g5_bridge_previous_quarter_id("2026Q1"), "2025Q4")
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

test_that("bridge authority reader can include TRAIN state performance", {
  authority_dir <- tempfile("g5_bridge_authority_")
  dir.create(authority_dir, recursive = TRUE)
  utils::write.csv(
    g5_bridge_contract_frame(
      quarter_id = "2026Q3",
      symbols = c("AMD", "NVDA"),
      context_symbols = c("AMD", "NVDA", "SPY"),
      as_of_timestamp = "2026-06-30 17:30:00",
      refresh = FALSE,
      market_data_feed = "iex"
    ),
    file.path(authority_dir, "bridge_authority_contract.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(symbol = "AMD", state_id = "S1_1", strategy_spec_id = "no_trade", stringsAsFactors = FALSE),
    file.path(authority_dir, "bridge_selected_states.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(record_type = "meta", key = "grid_n", value = "5", stringsAsFactors = FALSE),
    file.path(authority_dir, "bridge_pca_model_contract.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      symbol = "AMD",
      quarter_id = "2026Q3",
      state_id = "S1_1",
      strategy_family = "no_trade",
      strategy_spec_id = "no_trade",
      sharpe = 0,
      total_return = 0,
      train_state_row_count = 50L,
      stringsAsFactors = FALSE
    ),
    file.path(authority_dir, "bridge_train_state_performance.csv"),
    row.names = FALSE
  )

  authority <- g5_bridge_read_authority(authority_dir, include_train_state_performance = TRUE)

  expect_true(is.data.frame(authority$train_state_performance))
  expect_equal(authority$train_state_performance$quarter_id[[1L]], "2026Q3")
})

test_that("live bridge direct lane consumes frozen selected-state authority", {
  authority <- list(
    contract = g5_bridge_contract_frame(
      quarter_id = "2026Q3",
      symbols = "SOFI",
      context_symbols = "SOFI",
      as_of_timestamp = "2026-06-30 17:30:00",
      refresh = FALSE,
      market_data_feed = "iex"
    ),
    selected_states = data.frame(
      symbol = "SOFI",
      quarter_id = "2026Q3",
      state_id = "S1_1",
      strategy_family = "ema_trend",
      model_instance_id = "frozen_ema_trend",
      exit_stack_id = "native_only",
      strategy_spec_id = "frozen_ema_trend__native_only",
      sharpe = 0.5,
      total_return = 0.05,
      train_state_row_count = 40L,
      train_state_trade_count = 5L,
      stringsAsFactors = FALSE
    ),
    train_state_performance = data.frame(
      symbol = "SOFI",
      quarter_id = "2026Q3",
      state_id = "S1_1",
      strategy_family = c("no_trade", "ema_cross"),
      model_instance_id = c("no_trade", "recomputed_ema_cross"),
      exit_stack_id = "native_only",
      strategy_spec_id = c("no_trade__no_exit", "recomputed_ema_cross__native_only"),
      sharpe = c(0, 9),
      total_return = c(0, 0.9),
      train_state_row_count = 40L,
      train_state_trade_count = c(0L, 10L),
      stringsAsFactors = FALSE
    )
  )

  direct <- g5_bridge_apply_live_selection_policy(authority, "asset_state_direct_spec", min_train_state_rows = 20L)

  expect_equal(direct$selected_states$strategy_spec_id[[1L]], "frozen_ema_trend__native_only")
  expect_equal(direct$selected_states$selection_policy_recipe[[1L]], "gen5_1_frozen_bridge_selected_states")
  expect_equal(direct$selected_states$live_bridge_authority_source[[1L]], "bridge_selected_states.csv")
  expect_equal(direct$contract$live_bridge_selection_guardrail[[1L]], "direct_lane_consumes_frozen_selected_states_without_recomputing_from_train_performance")
})

test_that("SOFI Q2 continuity fixture carries 2026-06-29 open trade when still long", {
  prior_replay <- data.frame(
    symbol = "SOFI",
    session_date = as.Date(c("2026-06-26", "2026-06-29", "2026-06-30", "2026-07-01", "2026-07-08")),
    model_position_after_replay = c("FLAT", "LONG", "LONG", "LONG", "LONG"),
    stringsAsFactors = FALSE
  )
  open_trade <- data.frame(
    symbol = "SOFI",
    trade_status = "open",
    entry_execution_date = as.Date("2026-06-29"),
    strategy_spec_id = "ema_trend_fast15_slow50__native_only",
    stringsAsFactors = FALSE
  )

  carry_until <- g5_bridge_first_flat_date_from_prior(prior_replay, as.Date("2026-07-01"))

  expect_true(is.na(carry_until))
  expect_equal(open_trade$symbol[[1L]], "SOFI")
  expect_equal(open_trade$entry_execution_date[[1L]], as.Date("2026-06-29"))
  expect_equal(open_trade$trade_status[[1L]], "open")
})

test_that("PCA feature table exposes legacy Gen4 dist_anchor_50 without changing defaults", {
  bars <- data.frame(
    symbol = "AMD",
    session_date = as.Date("2026-01-01") + 0:80,
    open = 100 + 0:80,
    high = 101 + 0:80,
    low = 99 + 0:80,
    close = 100 + 0:80,
    volume = 1000,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "fixture",
    as_of_timestamp = "2026-03-31 17:30:00",
    latest_completed_session = as.Date("2026-03-31"),
    fetch_start_date = as.Date("2026-01-01"),
    fetch_end_date = as.Date("2026-03-31"),
    data_version_hash = "fixture",
    stringsAsFactors = FALSE
  )

  features <- g5_pca_regime_feature_table(bars, "AMD")

  expect_true("dist_anchor_50" %in% names(features))
  expect_false("dist_anchor_50" %in% g5_pca_regime_default_features())
})

test_that("frozen scoring accepts global Gen4-style state contracts", {
  features <- data.frame(
    schema_version = "fixture",
    symbol = "AMD",
    session_date = as.Date("2026-06-30") + 0:1,
    open = 1,
    high = 1,
    low = 1,
    close = 1,
    volume = 1,
    dist_anchor_50 = c(-0.75, 0.75),
    stringsAsFactors = FALSE
  )
  contract <- data.frame(
    record_type = c("feature", rep("pc_break", 12), "meta"),
    feature = c("dist_anchor_50", rep(NA_character_, 13)),
    center = c(0, rep(NA_real_, 13)),
    scale = c(1, rep(NA_real_, 13)),
    loading_pc1 = c(1, rep(NA_real_, 13)),
    loading_pc2 = c(1, rep(NA_real_, 13)),
    break_axis = c(NA, rep("pc1", 6), rep("pc2", 6), NA),
    break_index = c(NA, 1:6, 1:6, NA),
    break_value = c(NA, -2, -1, 0, 1, 2, 3, -2, -1, 0, 1, 2, 3, NA),
    key = c(NA, rep(NA_character_, 12), "state_grid_n"),
    value = c(NA, rep(NA_character_, 12), "5"),
    stringsAsFactors = FALSE
  )

  scored <- g5_bridge_score_frozen_quantile(features, contract, "AMD")

  expect_equal(scored$state_id, c("S2_2", "S3_3"))
})

test_that("Gen4 Phase50 and Phase60 artifacts seed prior open AMD continuity", {
  phase50_dir <- tempfile("phase50_")
  phase60_dir <- tempfile("phase60_")
  dir.create(phase50_dir, recursive = TRUE)
  dir.create(phase60_dir, recursive = TRUE)
  utils::write.csv(
    data.frame(
      asset = "AMD",
      state_id = "1_1",
      family = "ema_cross",
      strategy = "ema_cross_f10_s20",
      selection_mode = "pooled_family_asset_variant",
      variant_metric = 0.25,
      x_param = 10,
      y_param = 20,
      source_fold_id = 19,
      source_validated_quarter = "2026Q1",
      live_quarter_id = "2026Q2",
      stringsAsFactors = FALSE
    ),
    file.path(phase50_dir, "phase50_asset_variant_map.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      quarter_id = "2026Q2",
      live_quarter_start_date = "2026-04-01",
      live_quarter_end_date = "2026-06-30",
      phase50_schema_version = "phase50_freeze_pack_v1",
      stringsAsFactors = FALSE
    ),
    file.path(phase50_dir, "phase50_quarter_contract.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      record_type = c("feature", "meta"),
      feature = c("dist_anchor_50", NA),
      center = c(0, NA),
      scale = c(1, NA),
      loading_pc1 = c(1, NA),
      loading_pc2 = c(1, NA),
      break_axis = NA,
      break_index = NA,
      break_value = NA,
      key = c(NA, "state_grid_n"),
      value = c(NA, "5"),
      stringsAsFactors = FALSE
    ),
    file.path(phase50_dir, "phase50_state_model_contract.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      asset = "AMD",
      date = "2026-06-30",
      state_id = "1_1",
      chosen_family = "ema_cross",
      chosen_strategy = "ema_cross_f10_s20",
      current_exec_pos = 1,
      stringsAsFactors = FALSE
    ),
    file.path(phase60_dir, "phase60_operator_packet.csv"),
    row.names = FALSE
  )
  template <- list(
    contract = g5_bridge_contract_frame(
      quarter_id = "2026Q2",
      symbols = "AMD",
      context_symbols = "AMD",
      as_of_timestamp = "2026-03-31 17:30:00",
      refresh = FALSE,
      market_data_feed = "iex"
    )
  )

  authority <- g5_bridge_authority_from_gen4_phase50(phase50_dir, template)
  authority$seed_positions <- g5_bridge_seed_positions_from_gen4_phase60(phase60_dir, authority)
  seed <- g5_bridge_seed_for_symbol(authority, "AMD")

  expect_equal(authority$selected_states$state_id[[1L]], "S1_1")
  expect_equal(authority$selected_states$strategy_spec_id[[1L]], "ema_cross_fast10_slow20__native_only")
  expect_equal(seed$strategy_spec_id[[1L]], "ema_cross_fast10_slow20__native_only")
  expect_equal(seed$entry_execution_date[[1L]], as.Date("2026-06-30"))
  expect_equal(seed$entry_trigger_type[[1L]], "gen4_phase60_seed_position")
})

test_that("live bridge runtime provenance records code and git fields", {
  provenance <- g5_bridge_runtime_provenance(
    repo_root = test_path("..", ".."),
    quarter_id = "2026Q3",
    as_of_timestamp = "2026-07-08 17:30:00",
    selection_policy = "asset_state_direct_spec",
    selection_policy_label = "Gen5.1 direct-spec",
    authority_dir = "runs/live_advice_bridge/authority/2026Q3",
    previous_authority_dir = "runs/live_advice_bridge/authority/2026Q2"
  )

  expect_equal(nrow(provenance), 1L)
  expect_equal(provenance$live_bridge_code_version[[1L]], g5_live_bridge_code_version())
  expect_equal(provenance$live_bridge_semantics[[1L]], "frozen_gen5_1_authority_consumption")
  expect_true("git_sha" %in% names(provenance))
  expect_true("git_dirty" %in% names(provenance))
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
  expect_true("bollinger_touch_n10_sd1p5" %in% grid$model_instance_id)
  expect_true("bollinger_touch_n14_sd1p5" %in% grid$model_instance_id)
  expect_true("rsi_mr_n21_lo35_hi75" %in% grid$model_instance_id)
  expect_true("zret_mr_n10_ent1p5_ex0" %in% grid$model_instance_id)
  expect_true("zret_mr_n40_ent2p5_ex1" %in% grid$model_instance_id)
  expect_true("breakout_lb10_buf0p0013" %in% grid$model_instance_id)
  expect_true("breakout_lb30_buf0" %in% grid$model_instance_id)
  expect_true("breakout_lb30_buf0p0025" %in% grid$model_instance_id)
  expect_true("pullback_up_f15_s75_lo40_hi65" %in% grid$model_instance_id)
  expect_equal(nrow(grid), 191L)
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

test_that("continuity detector carries prior authority when first current-quarter bar is long", {
  prior_replay <- data.frame(
    session_date = as.Date(c("2026-06-30", "2026-07-01", "2026-07-02", "2026-07-03")),
    model_position_after_replay = c("FLAT", "LONG", "LONG", "FLAT"),
    stringsAsFactors = FALSE
  )

  expect_equal(
    g5_bridge_first_flat_date_from_prior(prior_replay, as.Date("2026-07-01")),
    as.Date("2026-07-03")
  )
})

test_that("chart replay can use a 90 calendar-day window", {
  replay <- data.frame(
    session_date = as.Date("2026-03-01") + 0:140,
    symbol = "AMD",
    open = 1:141,
    high = 1:141,
    low = 1:141,
    close = 1:141,
    state_id = "S1_1",
    stringsAsFactors = FALSE
  )
  symbol_result <- list(replay = replay, scores = replay)

  chart <- g5_bridge_chart_replay(
    symbol_result,
    chart_start_date = as.Date("2026-07-01") - 90,
    chart_end_date = as.Date("2026-07-01")
  )

  expect_true(min(as.Date(chart$session_date)) >= as.Date("2026-04-02"))
  expect_true(max(as.Date(chart$session_date)) <= as.Date("2026-07-01"))
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

test_that("pooled family policy selects family first and asset params second", {
  perf <- data.frame(
    symbol = rep(c("AAA", "BBB"), each = 4L),
    quarter_id = "2026Q2",
    state_id = "S1_1",
    strategy_family = rep(c("no_trade", "trend", "trend", "mean_reversion"), times = 2L),
    model_instance_id = c(
      "no_trade", "trend_fast", "trend_slow", "mean_rev",
      "no_trade", "trend_fast", "trend_slow", "mean_rev"
    ),
    exit_stack_id = "native_only",
    strategy_spec_id = c(
      "no_trade__no_exit", "aaa_trend_fast", "aaa_trend_slow", "aaa_mean_rev",
      "no_trade__no_exit", "bbb_trend_fast", "bbb_trend_slow", "bbb_mean_rev"
    ),
    sharpe = c(0, 2.0, 1.2, 0.4, 0, 0.1, -0.1, 1.0),
    total_return = c(0, 0.20, 0.10, 0.04, 0, 0.01, -0.01, 0.10),
    train_state_row_count = 50L,
    train_state_trade_count = c(0, 5, 4, 2, 0, 5, 1, 3),
    stringsAsFactors = FALSE
  )

  selected <- g5_selection_policy_pooled_family_asset_variant(perf, min_train_state_rows = 20L)

  expect_equal(nrow(selected), 2L)
  expect_true(all(selected$pooled_selected_family == "trend"))
  expect_equal(
    selected$strategy_spec_id[match(c("AAA", "BBB"), selected$symbol)],
    c("aaa_trend_fast", "bbb_trend_fast")
  )
  expect_true(all(selected$selection_policy_recipe == "gen4_phase40_pooled_family_asset_variant"))
})

test_that("Gen4-faithful pooled family policy filters low-trade active variants", {
  perf <- data.frame(
    symbol = rep(c("AAA", "BBB"), each = 3L),
    quarter_id = "2026Q2",
    state_id = "S1_1",
    strategy_family = rep(c("no_trade", "trend", "mean_reversion"), times = 2L),
    model_instance_id = c("no_trade", "trend", "mean_rev", "no_trade", "trend", "mean_rev"),
    exit_stack_id = "native_only",
    strategy_spec_id = c("aaa_no_trade", "aaa_trend", "aaa_mean", "bbb_no_trade", "bbb_trend", "bbb_mean"),
    sharpe = c(0, 2.0, 0.5, 0, 1.5, 1.0),
    total_return = c(0, 0.20, 0.05, 0, 0.15, 0.10),
    train_state_row_count = 50L,
    train_state_trade_count = c(0, 5, 5, 0, 1, 1),
    stringsAsFactors = FALSE
  )

  selected <- g5_selection_policy_pooled_family_asset_variant(perf, min_train_state_rows = 20L)
  bbb <- selected[selected$symbol == "BBB", , drop = FALSE]

  expect_equal(bbb$strategy_family[[1L]], "no_trade")
  expect_match(bbb$selection_reason[[1L]], "no_asset_variant_for_family_trend")
})

test_that("Gen4 state-leader fallback fills missing asset variants", {
  perf <- data.frame(
    symbol = rep(c("AAA", "BBB"), each = 3L),
    quarter_id = "2026Q2",
    state_id = "S1_1",
    strategy_family = rep(c("no_trade", "trend", "mean_reversion"), times = 2L),
    model_instance_id = c("no_trade", "trend", "mean_rev", "no_trade", "trend", "mean_rev"),
    exit_stack_id = "native_only",
    strategy_spec_id = c("aaa_no_trade", "aaa_trend", "aaa_mean", "bbb_no_trade", "bbb_trend", "bbb_mean"),
    sharpe = c(0, 2.0, 0.5, 0, 1.5, 1.0),
    total_return = c(0, 0.20, 0.05, 0, 0.15, 0.10),
    train_state_row_count = 50L,
    train_state_trade_count = c(0, 5, 5, 0, 1, 1),
    stringsAsFactors = FALSE
  )

  strict <- g5_selection_policy_pooled_family_asset_variant(perf, min_train_state_rows = 20L)
  fallback <- g5_selection_policy_pooled_family_asset_variant_state_fallback(perf, min_train_state_rows = 20L)
  bbb_strict <- strict[strict$symbol == "BBB", , drop = FALSE]
  bbb_fallback <- fallback[fallback$symbol == "BBB", , drop = FALSE]

  expect_equal(bbb_strict$strategy_family[[1L]], "no_trade")
  expect_equal(bbb_fallback$strategy_family[[1L]], "trend")
  expect_equal(bbb_fallback$strategy_spec_id[[1L]], "aaa_trend")
  expect_true(isTRUE(bbb_fallback$fallback_used[[1L]]))
  expect_equal(bbb_fallback$fallback_source_symbol[[1L]], "AAA")
  expect_match(bbb_fallback$selection_reason[[1L]], "state_leader_fallback")
  expect_true(all(fallback$selection_policy_recipe == "gen4_phase40_pooled_family_asset_variant_state_leader_fallback"))
})

test_that("bridge replay can opt into state-switch trend continuation entries", {
  dates <- as.Date("2025-12-29") + 0:9
  close <- c(10, 9, 8, 12, 13, 14, 15, 16, 17, 18)
  bars <- data.frame(
    symbol = "AAA",
    session_date = dates,
    open = close + 0.1,
    high = close + 1,
    low = close - 1,
    close = close,
    volume = seq_along(close) * 100,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "fixture",
    as_of_timestamp = "2026-01-07 17:30:00",
    latest_completed_session = max(dates),
    fetch_start_date = min(dates),
    fetch_end_date = max(dates),
    data_version_hash = paste0("fixture_", seq_along(close)),
    stringsAsFactors = FALSE
  )
  scored <- data.frame(
    symbol = "AAA",
    session_date = dates,
    state_id = ifelse(dates <= as.Date("2026-01-01"), "S1_1", "S2_1"),
    stringsAsFactors = FALSE
  )
  grid <- g5_wfa_candidate_model_grid(
    fast_periods = 1L,
    slow_periods = 3L,
    candidate_families = c("ema_cross", "no_trade")
  )
  no_trade <- grid[grid$strategy_family == "no_trade", , drop = FALSE][1L, , drop = FALSE]
  no_trade$symbol <- "AAA"
  no_trade$quarter_id <- "2026Q1"
  no_trade$state_id <- "S1_1"
  no_trade$exit_stack_id <- "no_exit"
  no_trade$strategy_spec_id <- "no_trade__no_exit"
  ema <- grid[grid$strategy_family == "ema_cross", , drop = FALSE][1L, , drop = FALSE]
  ema$symbol <- "AAA"
  ema$quarter_id <- "2026Q1"
  ema$state_id <- "S2_1"
  ema$exit_stack_id <- "native_only"
  ema$strategy_spec_id <- paste0(ema$model_instance_id[[1L]], "__native_only")
  selected_states <- g5_wfa_bind_rows_fill(list(no_trade, ema))
  contract <- g5_bridge_contract_frame(
    quarter_id = "2026Q1",
    symbols = "AAA",
    context_symbols = "AAA",
    as_of_timestamp = "2026-01-07 17:30:00",
    refresh = FALSE
  )

  fresh <- g5_bridge_replay_symbol(
    bars,
    "AAA",
    scored,
    selected_states,
    contract,
    replay_start_date = as.Date("2025-12-31"),
    entry_signal_start_date = as.Date("2025-12-31"),
    entry_signal_end_date = as.Date("2026-01-07"),
    entry_replay_semantics = "fresh_signal_only"
  )
  continuation <- g5_bridge_replay_symbol(
    bars,
    "AAA",
    scored,
    selected_states,
    contract,
    replay_start_date = as.Date("2025-12-31"),
    entry_signal_start_date = as.Date("2025-12-31"),
    entry_signal_end_date = as.Date("2026-01-07"),
    entry_replay_semantics = "state_switch_continuation"
  )

  expect_equal(nrow(fresh$executions), 0L)
  expect_true(any(continuation$replay$signal_status == "ENTER_LONG_NEXT_OPEN"))
  expect_equal(
    continuation$replay$entry_trigger_type[continuation$replay$signal_status == "ENTER_LONG_NEXT_OPEN"][[1L]],
    "state_switch_continuation"
  )
  expect_equal(continuation$executions$execution_type[[1L]], "ENTER_LONG")
  expect_equal(as.Date(continuation$executions$execution_date[[1L]]), as.Date("2026-01-03"))
  expect_error(
    g5_bridge_replay_symbol(
      bars,
      "AAA",
      scored,
      selected_states,
      contract,
      entry_replay_semantics = "wide_open"
    ),
    "entry_replay_semantics"
  )
})

test_that("Gen5.2 direct policy rebuilds selected states from TRAIN performance", {
  perf <- data.frame(
    symbol = "AAA",
    quarter_id = "2026Q2",
    state_id = "S1_1",
    strategy_family = c("no_trade", "trend", "trend"),
    model_instance_id = c("no_trade", "sparse_fast", "steady"),
    exit_stack_id = "native_only",
    strategy_spec_id = c("aaa_no_trade", "aaa_sparse_fast", "aaa_steady"),
    sharpe = c(NA, 5.0, 1.0),
    total_return = c(0, 0.50, 0.10),
    train_state_row_count = 50L,
    train_state_trade_count = c(0L, 1L, 5L),
    stringsAsFactors = FALSE
  )

  selected <- g5_selection_policy_direct_asset_state_spec(perf, min_train_state_rows = 20L)

  expect_equal(nrow(selected), 1L)
  expect_equal(selected$strategy_spec_id[[1L]], "aaa_steady")
  expect_equal(selected$selection_policy[[1L]], "asset_state_direct_spec")
  expect_equal(selected$selection_policy_recipe[[1L]], "gen52_direct_spec_min_trades_score_then_return")
})

test_that("Gen4 no-trade exit-immediate rows become explicit state exit overrides", {
  row <- data.frame(
    strategy_family = "no_trade_exit_immediate",
    strategy_spec_id = "no_trade_exit_immediate",
    model_instance_id = "no_trade_exit_immediate",
    stringsAsFactors = FALSE
  )

  expect_true(g5_wfa_is_force_exit_override(row))
  expect_equal(g5_wfa_state_exit_override_action(row), "force_exit_next_open")
})

test_that("pooled family policy forces sparse asset states to no trade", {
  perf <- data.frame(
    symbol = c("AAA", "AAA", "BBB", "BBB"),
    quarter_id = "2026Q2",
    state_id = "S1_1",
    strategy_family = c("no_trade", "trend", "no_trade", "trend"),
    model_instance_id = c("no_trade", "trend", "no_trade", "trend"),
    exit_stack_id = "native_only",
    strategy_spec_id = c("aaa_no_trade", "aaa_trend", "bbb_no_trade", "bbb_trend"),
    sharpe = c(0, 2, 0, 3),
    total_return = c(0, 0.2, 0, 0.3),
    train_state_row_count = c(50L, 50L, 5L, 5L),
    train_state_trade_count = c(0, 3, 0, 4),
    stringsAsFactors = FALSE
  )

  selected <- g5_selection_policy_pooled_family_asset_variant(perf, min_train_state_rows = 20L)
  bbb <- selected[selected$symbol == "BBB", , drop = FALSE]

  expect_equal(bbb$strategy_family[[1L]], "no_trade")
  expect_match(bbb$selection_reason[[1L]], "forced_no_trade_sparse_state")
})

test_that("selection policy visual summary reads a packet and writes charts", {
  screen_dir <- tempfile("g5_selection_policy_visual_packet_")
  dir.create(screen_dir, recursive = TRUE)
  replay_dir <- file.path(screen_dir, "replays")
  dir.create(replay_dir, recursive = TRUE)

  trade_summary <- data.frame(
    selection_policy = rep(c("asset_state_direct_spec", "pooled_family_asset_variant"), each = 2L),
    window_id = "W1",
    quarter_id = "2026Q2",
    as_of_date = as.Date("2026-06-30"),
    symbol = rep(c("AAA", "BBB"), times = 2L),
    trade_count = c(1, 1, 1, 1),
    closed_trade_count = c(1, 1, 1, 1),
    open_trade_count = c(0, 0, 0, 0),
    win_count = c(1, 0, 1, 1),
    loss_count = c(0, 1, 0, 0),
    compound_trace_return = c(0.10, -0.03, 0.05, 0.02),
    mean_trace_return = c(0.10, -0.03, 0.05, 0.02),
    worst_trace_return = c(0.10, -0.03, 0.05, 0.02),
    best_trace_return = c(0.10, -0.03, 0.05, 0.02),
    current_model_position = "FLAT",
    latest_state_id = "S1_1",
    latest_selected_strategy_family = c("trend", "mean", "trend", "trend"),
    latest_selected_strategy_spec_id = c("d1", "d2", "p1", "p2"),
    stringsAsFactors = FALSE
  )
  trade_ledger <- data.frame(
    window_id = "W1",
    selection_policy = rep(c("asset_state_direct_spec", "pooled_family_asset_variant"), each = 2L),
    symbol = rep(c("AAA", "BBB"), times = 2L),
    entry_execution_date = as.Date("2026-06-01"),
    entry_execution_price = 100,
    trace_end_date = as.Date("2026-06-10"),
    trace_end_price = c(110, 97, 105, 102),
    trade_status = "closed",
    trade_outcome = c("win", "loss", "win", "win"),
    strategy_spec_id = "fixture",
    stringsAsFactors = FALSE
  )
  selected_comparison <- expand.grid(
    quarter_id = "2026Q2",
    symbol = c("AAA", "BBB"),
    state_id = c("S1_1", "S1_2"),
    stringsAsFactors = FALSE
  )
  selected_comparison$strategy_family_direct <- c("trend", "trend", "mean", "mean")
  selected_comparison$strategy_family_pooled <- c("trend", "mean", "mean", "trend")
  selected_comparison$strategy_spec_id_direct <- paste0("d", seq_len(nrow(selected_comparison)))
  selected_comparison$strategy_spec_id_pooled <- c(selected_comparison$strategy_spec_id_direct[[1L]], "p2", selected_comparison$strategy_spec_id_direct[[3L]], "p4")
  selected_comparison$family_match <- selected_comparison$strategy_family_direct == selected_comparison$strategy_family_pooled
  selected_comparison$spec_match <- selected_comparison$strategy_spec_id_direct == selected_comparison$strategy_spec_id_pooled

  replay_paths <- character()
  for (policy in unique(trade_summary$selection_policy)) {
    replay <- data.frame(
      symbol = rep(c("AAA", "BBB"), each = 4L),
      session_date = rep(as.Date("2026-06-01") + 0:3, times = 2L),
      close = c(100, 102, 101, 104, 50, 49, 51, 52),
      model_position_after_replay = c("FLAT", "LONG", "LONG", "FLAT", "FLAT", "LONG", "LONG", "FLAT"),
      stringsAsFactors = FALSE
    )
    path <- file.path(replay_dir, paste0(policy, ".csv"))
    utils::write.csv(replay, path, row.names = FALSE)
    replay_paths <- c(replay_paths, path)
  }
  packet_index <- data.frame(
    window_id = "W1",
    quarter_id = "2026Q2",
    previous_quarter_id = "2026Q1",
    as_of_timestamp = "2026-06-30 17:30:00",
    selection_policy = unique(trade_summary$selection_policy),
    replay_csv = replay_paths,
    stringsAsFactors = FALSE
  )

  utils::write.csv(trade_summary, file.path(screen_dir, "selection_policy_trade_summary.csv"), row.names = FALSE)
  utils::write.csv(trade_ledger, file.path(screen_dir, "selection_policy_trade_ledger.csv"), row.names = FALSE)
  utils::write.csv(selected_comparison, file.path(screen_dir, "selection_policy_selected_state_comparison.csv"), row.names = FALSE)
  utils::write.csv(packet_index, file.path(screen_dir, "selection_policy_packet_index.csv"), row.names = FALSE)

  written <- g5_selection_policy_write_visual_summary(screen_dir)

  expect_true(file.exists(written$paths$visual_index_csv))
  expect_true(file.exists(written$paths$metric_dashboard_png))
  expect_true(file.exists(written$paths$return_heatmap_png))
  expect_true(file.exists(written$paths$return_scatter_png))
  expect_true(file.exists(written$paths$churn_map_png))
  expect_true(file.exists(written$paths$equity_proxy_png))
  expect_equal(nrow(written$visual_index), 5L)
  expect_equal(nrow(written$symbol_delta), 2L)
})
