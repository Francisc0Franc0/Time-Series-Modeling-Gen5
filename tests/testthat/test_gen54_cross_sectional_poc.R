source(test_path("..", "..", "R", "gen54_cross_sectional_poc.R"))

make_xs_bars <- function(n = 180L) {
  registry <- g5_gen54_xs_candidate_registry()
  symbols <- c(registry$symbol, g5_gen54_xs_context_symbols())
  dates <- as.Date("2019-01-01") + seq_len(n) - 1L
  rows <- lapply(seq_along(symbols), function(j) {
    idx <- seq_len(n)
    slope <- 0.0005 + j * 0.00003
    close <- 50 * exp(slope * idx)
    data.frame(
      symbol = symbols[[j]],
      session_date = dates,
      open = close * (1 + 0.0001 * sin(idx / 4 + j)),
      high = close * 1.01,
      low = close * 0.99,
      close = close,
      volume = 2e6 + j * 1e5,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

test_that("candidate registry is fixed, diverse, and separate from context", {
  registry <- g5_gen54_xs_candidate_registry()
  expect_equal(nrow(registry), 24L)
  expect_equal(length(unique(registry$economic_group)), 6L)
  expect_length(intersect(registry$symbol, g5_gen54_xs_context_symbols()), 0L)
})

test_that("cross-sectional panel aligns next-open h5 labels without future features", {
  panel <- g5_gen54_xs_build_panel(make_xs_bars(), minimum_trailing_dollar_volume = 1e6)
  amd <- panel[panel$symbol == "AMD", , drop = FALSE]
  row <- amd[80L, , drop = FALSE]
  expect_equal(row$execution_date, amd$feature_date[[81L]])
  expect_equal(row$label_end_date, amd$feature_date[[86L]])
  expect_true(row$feature_date < row$execution_date)
  expect_true(row$execution_date < row$label_end_date)
  expect_true(row$cross_section_eligible)
  expect_true(is.finite(row$group_relative_20))
})

test_that("same-date cross-sectional ranks are bounded and label excess is zero sum", {
  panel <- g5_gen54_xs_build_panel(make_xs_bars(), minimum_trailing_dollar_volume = 1e6)
  eligible_dates <- unique(panel$feature_date[panel$cross_section_eligible])
  date <- eligible_dates[[1L]]
  part <- panel[panel$feature_date == date & panel$cross_section_eligible, , drop = FALSE]
  expect_equal(nrow(part), 24L)
  expect_true(all(part$momentum_20_rank >= 0 & part$momentum_20_rank <= 1))
  expect_equal(mean(part$relative_forward_return_h5), 0, tolerance = 1e-12)
})

test_that("quarterly boundary rows with labels outside authority are excluded", {
  panel <- g5_gen54_xs_build_panel(make_xs_bars(), minimum_trailing_dollar_volume = 1e6)
  fold <- data.frame(
    fold_no = 1L,
    fold_id = "2019Q1",
    window_id = "2019Y",
    train_start_date = as.Date("2017-01-01"),
    train_end_date = as.Date("2018-12-31"),
    oos_start_date = as.Date("2019-01-01"),
    oos_end_date = as.Date("2019-03-31"),
    stringsAsFactors = FALSE
  )
  assigned <- g5_gen54_xs_assign_oos(panel, fold)
  crossing <- assigned$label_end_date > fold$oos_end_date
  expect_true(any(crossing, na.rm = TRUE))
  expect_false(any(assigned$label_inside_oos[crossing], na.rm = TRUE))
})

test_that("promotion gate requires both IC and ordering breadth", {
  folds <- paste0("2020Q", 1:4)
  fold_summary <- data.frame(
    fold_id = rep(folds, each = 1L),
    window_id = "2020Y",
    feature_name = "momentum_20",
    decision_dates = 50L,
    mean_daily_rank_ic = 0.05,
    median_daily_rank_ic = 0.04,
    top_mean_relative_return_h5 = 0.01,
    middle_mean_relative_return_h5 = 0,
    bottom_mean_relative_return_h5 = -0.01,
    top_minus_bottom_h5 = 0.02,
    top_selection_max_group_share = 0.40,
    stringsAsFactors = FALSE
  )
  daily_ic <- data.frame(
    fold_id = rep(folds, each = 2L),
    window_id = "2020Y",
    feature_date = as.Date("2020-01-01") + 0:7,
    feature_name = "momentum_20",
    eligible_count = 24L,
    rank_ic = 0.05,
    stringsAsFactors = FALSE
  )
  verdict <- g5_gen54_xs_feature_verdict(fold_summary, daily_ic, required_positive_folds = 4L)
  expect_equal(verdict$verdict, "PASS_TO_COMBINATION_DESIGN")
  fold_summary$top_minus_bottom_h5[[1L]] <- -0.02
  verdict_fail <- g5_gen54_xs_feature_verdict(fold_summary, daily_ic, required_positive_folds = 4L)
  expect_equal(verdict_fail$verdict, "STOP_AS_STANDALONE_PRIMITIVE")
})
