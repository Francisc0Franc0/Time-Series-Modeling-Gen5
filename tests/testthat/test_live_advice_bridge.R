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
