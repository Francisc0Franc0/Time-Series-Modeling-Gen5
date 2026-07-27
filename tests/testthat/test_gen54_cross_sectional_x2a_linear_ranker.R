source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_poc.R"))
source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_x2a_linear_ranker.R"))

g5_test_x2a_panel <- function() {
  dates <- seq(as.Date("2022-01-03"), as.Date("2025-03-31"), by = "day")
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5]
  registry <- g5_gen54_xs_candidate_registry()
  grid <- expand.grid(
    feature_date = dates,
    symbol = registry$symbol,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid <- grid[order(grid$feature_date, match(grid$symbol, registry$symbol)), , drop = FALSE]
  symbol_no <- match(grid$symbol, registry$symbol)
  date_no <- match(grid$feature_date, dates)
  grid$economic_group <- registry$economic_group[match(grid$symbol, registry$symbol)]
  grid$execution_date <- grid$feature_date + 1L
  grid$label_end_date <- grid$feature_date + 6L
  grid$cross_section_eligible <- TRUE
  grid$group_relative_20_rank <- (symbol_no - 1) / 23
  grid$intraday_minus_overnight_20_rank <- ((symbol_no + date_no) %% 24) / 23
  grid$relative_forward_return_h5 <- 0.02 * grid$group_relative_20_rank +
    0.01 * grid$intraday_minus_overnight_20_rank +
    0.00001 * ((symbol_no * 7 + date_no) %% 11)
  grid
}

testthat::test_that("X2a freezes six confirmation quarters", {
  folds <- g5_gen54_x2a_build_folds()
  testthat::expect_equal(folds$fold_id, c(
    "2025Q1", "2025Q2", "2025Q3", "2025Q4", "2026Q1", "2026Q2"
  ))
  testthat::expect_true(all(folds$oos_start_date > folds$train_end_date))
})

testthat::test_that("X2a fold fitting purges crossing TRAIN labels", {
  panel <- g5_test_x2a_panel()
  fold <- data.frame(
    fold_id = "2025Q1",
    train_start_date = as.Date("2023-01-01"),
    train_end_date = as.Date("2024-12-31"),
    oos_start_date = as.Date("2025-01-01"),
    oos_end_date = as.Date("2025-03-31"),
    stringsAsFactors = FALSE
  )
  result <- g5_gen54_x2a_fit_fold(panel, fold)
  testthat::expect_equal(unique(result$scored$method), g5_gen54_x2a_method_names())
  testthat::expect_true(all(result$coefficients$train_last_label_end_date <= fold$train_end_date))
  testthat::expect_true(all(result$coefficients$oos_last_label_end_date <= fold$oos_end_date))
  slopes <- result$coefficients$estimate[result$coefficients$term != "(Intercept)"]
  testthat::expect_equal(slopes, c(0.02, 0.01), tolerance = 5e-4)
})

testthat::test_that("X2a summaries include both concentration caps", {
  panel <- g5_test_x2a_panel()
  fold <- data.frame(
    fold_id = "2025Q1",
    train_start_date = as.Date("2023-01-01"),
    train_end_date = as.Date("2024-12-31"),
    oos_start_date = as.Date("2025-01-01"),
    oos_end_date = as.Date("2025-03-31"),
    stringsAsFactors = FALSE
  )
  scored <- g5_gen54_x2a_fit_fold(panel, fold)$scored
  daily <- g5_gen54_x2a_daily_ic(scored)
  summary <- g5_gen54_x2a_fold_summary(scored, daily)
  testthat::expect_equal(sort(unique(summary$method)), sort(g5_gen54_x2a_method_names()))
  testthat::expect_true(all(summary$top_selection_max_group_share <= 1))
  testthat::expect_true(all(summary$top_selection_max_symbol_share <= 1))
})

testthat::test_that("X2a gate requires every frozen condition", {
  methods <- g5_gen54_x2a_method_names()
  method_summary <- data.frame(
    method = methods,
    mean_oos_daily_rank_ic = c(0.01, 0.005, 0.012, 0.020),
    positive_ic_quarters = c(4, 4, 4, 5),
    overall_top_minus_bottom_h5 = c(0.001, 0.001, 0.002, 0.003),
    positive_ordering_quarters = c(4, 4, 4, 5),
    maximum_top_selection_group_share = c(0.4, 0.4, 0.4, 0.4),
    maximum_top_selection_symbol_share = c(0.2, 0.2, 0.2, 0.2),
    stringsAsFactors = FALSE
  )
  fold_summary <- do.call(rbind, lapply(methods, function(method) {
    data.frame(
      fold_id = paste0("F", 1:6),
      method = method,
      mean_daily_rank_ic = if (method == "pooled_linear_ranker") rep(0.02, 6) else rep(0.01, 6),
      stringsAsFactors = FALSE
    )
  }))
  leakage <- data.frame(status = "PASS")
  audit <- g5_gen54_x2a_gate_audit(method_summary, fold_summary, leakage)
  testthat::expect_equal(audit$overall_status, "PASS_X2A_TO_TOP5_POLICY_THEORY")
  testthat::expect_true(all(audit$gates$status == "PASS"))
})
