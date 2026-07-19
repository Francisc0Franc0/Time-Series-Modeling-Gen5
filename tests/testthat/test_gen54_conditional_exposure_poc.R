source(test_path("..", "..", "R", "gen54_conditional_exposure_poc.R"))

make_ce_bars <- function(n = 120L) {
  symbols <- c("AMD", "NVDA", "TSLA", "MSTR", "AVGO", "SPY", "SMH")
  slopes <- c(AMD = 0.0020, NVDA = 0.0030, TSLA = 0.0015, MSTR = 0.0040,
              AVGO = 0.0025, SPY = 0.0010, SMH = 0.0022)
  dates <- as.Date("2019-01-01") + seq_len(n) - 1L
  rows <- lapply(symbols, function(symbol) {
    idx <- seq_len(n)
    close <- 100 * exp(slopes[[symbol]] * idx)
    data.frame(
      symbol = symbol,
      session_date = dates,
      open = close * (1 + 0.0002 * sin(idx / 3)),
      high = close * 1.01,
      low = close * 0.99,
      close = close,
      volume = 1e6 * exp(0.001 * idx),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

test_that("frozen feature panel uses exact leave-one-out and aligned h1 formulas", {
  panel <- g5_gen54_ce_build_feature_outcomes(make_ce_bars())
  amd <- panel[panel$symbol == "AMD", , drop = FALSE]
  row <- amd[65L, , drop = FALSE]

  expected_leadership <- 20 * (0.0020 - mean(c(0.0030, 0.0015, 0.0040, 0.0025)))
  expect_equal(row$target_leadership_20, expected_leadership, tolerance = 1e-10)
  expect_equal(row$opportunity_breadth_20, 1)
  expect_true(is.finite(row$participation_dollar_volume_5_60))
  expect_equal(row$execution_date, amd$feature_date[[66L]])
  expect_equal(row$label_end_date, amd$feature_date[[67L]])
  expect_true(row$complete_common)
})

test_that("sector challenger preserves structural missingness", {
  panel <- g5_gen54_ce_build_feature_outcomes(make_ce_bars())
  expect_true(all(is.na(panel$semiconductor_confirmation_20[panel$symbol %in% c("TSLA", "MSTR")])))
  expect_true(any(is.finite(panel$semiconductor_confirmation_20[panel$symbol == "AMD"])))
  expect_false(any(panel$complete_semiconductor_challenger[panel$symbol %in% c("TSLA", "MSTR")]))
})

test_that("fold ladder is frozen and boundary-crossing labels are ineligible", {
  folds <- g5_gen54_ce_build_folds()
  expect_equal(nrow(folds), 20L)
  expect_equal(folds$fold_id[[1L]], "2020Q1")
  expect_equal(folds$fold_id[[20L]], "2024Q4")

  dates <- as.Date(c("2019-12-30", "2019-12-31", "2020-01-01", "2020-03-30", "2020-03-31"))
  fixture <- data.frame(
    symbol = "AMD",
    feature_date = dates,
    execution_date = dates + 1L,
    label_end_date = dates + 2L,
    target_leadership_20 = 1,
    opportunity_breadth_20 = 1,
    spy_trend_20 = 1,
    spy_volatility_20 = 1,
    participation_dollar_volume_5_60 = 1,
    semiconductor_confirmation_20 = 1,
    target_open_to_open_return = 0.01,
    basket_open_to_open_return = 0.01,
    target_favorable = TRUE,
    basket_favorable = TRUE,
    complete_common = TRUE,
    complete_semiconductor_challenger = TRUE,
    stringsAsFactors = FALSE
  )
  assigned <- g5_gen54_ce_assign_fold_rows(fixture, folds[1L, , drop = FALSE])
  crossing_train <- assigned$split == "TRAIN" & assigned$feature_date == as.Date("2019-12-30")
  crossing_oos <- assigned$split == "OOS" & assigned$feature_date == as.Date("2020-03-30")
  expect_false(assigned$label_inside_split[crossing_train])
  expect_false(assigned$label_inside_split[crossing_oos])
})

test_that("TRAIN empirical percentiles do not learn from OOS values", {
  train <- c(1, 2, 3, 4)
  first <- g5_gen54_ce_train_percentile(train, c(2, 100))
  second <- g5_gen54_ce_train_percentile(train, c(2, 1000000))
  expect_equal(first[[1L]], 0.5)
  expect_equal(first[[1L]], second[[1L]])
  expect_equal(first[[2L]], 1)
})

test_that("one-way turnover costs reduce the fixed diagnostic proxy", {
  fixture <- data.frame(
    fold_no = 1L,
    fold_id = "2020Q1",
    window_id = "2020Y",
    lane = "common_panel",
    feature_name = "target_leadership_20",
    symbol = rep(c("AMD", "NVDA"), each = 4L),
    feature_date = rep(as.Date("2020-01-01") + 0:3, 2L),
    feature_value = 1,
    train_percentile = rep(c(0.8, 0.2, 0.8, 0.2), 2L),
    train_bin = rep(c(4L, 1L, 4L, 1L), 2L),
    target_open_to_open_return = 0.001,
    basket_open_to_open_return = 0.001,
    target_favorable = TRUE,
    basket_favorable = TRUE,
    stringsAsFactors = FALSE
  )
  summary <- g5_gen54_ce_proxy_cost_summary(fixture)
  zero <- summary$cumulative_net_return[summary$cost_bps_one_way == 0]
  stress <- summary$cumulative_net_return[summary$cost_bps_one_way == 20]
  expect_lt(stress, zero)
  expect_gt(summary$one_way_turnover[[1L]], 0)
})

test_that("leadership-participation confirmation uses TRAIN-only p60 thresholds", {
  fixture <- data.frame(
    fold_no = 1L,
    fold_id = "2025Q1",
    window_id = "2025Y",
    split = rep(c("TRAIN", "OOS"), c(10L, 4L)),
    label_inside_split = TRUE,
    complete_common = TRUE,
    feature_date = as.Date("2024-01-01") + 0:13,
    execution_date = as.Date("2024-01-02") + 0:13,
    label_end_date = as.Date("2024-01-03") + 0:13,
    train_start_date = as.Date("2023-01-01"),
    train_end_date = as.Date("2024-12-31"),
    oos_start_date = as.Date("2025-01-01"),
    oos_end_date = as.Date("2025-03-31"),
    symbol = "AMD",
    target_leadership_20 = c(1:10, 8, 8, 2, 2),
    participation_dollar_volume_5_60 = c(1:10, 8, 2, 8, 2),
    target_open_to_open_return = c(rep(0, 10), 0.04, 0.02, -0.01, -0.02),
    basket_open_to_open_return = c(rep(0, 10), 0.01, 0.01, -0.01, -0.01),
    target_favorable = c(rep(FALSE, 10), TRUE, TRUE, FALSE, FALSE),
    basket_favorable = c(rep(FALSE, 10), TRUE, TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  result <- g5_gen54_lp_confirmation_states(fixture, confirmation_fold_ids = "2025Q1")
  expect_equal(result$thresholds$leadership_train_p60, 6.4)
  expect_equal(result$thresholds$participation_train_p60, 6.4)
  expect_equal(
    result$states$confirmation_state,
    c(
      "A_high_leadership__high_participation",
      "B_high_leadership__low_participation",
      "C_low_leadership__high_participation",
      "D_low_leadership__low_participation"
    )
  )
})

test_that("confirmation gate requires A to beat both B and C", {
  states <- c(
    "A_high_leadership__high_participation",
    "B_high_leadership__low_participation",
    "C_low_leadership__high_participation",
    "D_low_leadership__low_participation"
  )
  summary <- data.frame(
    scope = rep(c("fold", "pooled"), each = 4L),
    fold_no = c(rep(1L, 4L), rep(NA_integer_, 4L)),
    fold_id = c(rep("2025Q1", 4L), rep("POOLED", 4L)),
    window_id = c(rep("2025Y", 4L), rep("2025Q1_2026Q2", 4L)),
    confirmation_state = rep(states, 2L),
    row_count = 20L,
    mean_target_return = rep(c(0.02, 0.01, 0.015, 0), 2L),
    target_favorable_rate = 0.55,
    mean_basket_return = 0.01,
    basket_favorable_rate = 0.55,
    stringsAsFactors = FALSE
  )
  contrasts <- g5_gen54_lp_fold_contrasts(summary)
  expect_true(contrasts$correct_state_a_ordering)
  cost <- data.frame(
    cost_bps_one_way = c(10, 20),
    cumulative_selection_excess = c(0.02, 0.01)
  )
  concentration <- data.frame(absolute_contribution_share = c(0.4, 0.3, 0.3))
  promotion <- g5_gen54_lp_promotion_summary(
    summary, contrasts, cost, concentration, required_correct_folds = 1L
  )
  expect_equal(promotion$confirmation_status, "PASS_FOR_OPERATOR_MODEL_GATE")

  summary$mean_target_return[summary$scope == "pooled" &
    summary$confirmation_state == "C_low_leadership__high_participation"] <- 0.03
  promotion_fail <- g5_gen54_lp_promotion_summary(
    summary, contrasts, cost, concentration, required_correct_folds = 1L
  )
  expect_equal(promotion_fail$confirmation_status, "STOP")
})
