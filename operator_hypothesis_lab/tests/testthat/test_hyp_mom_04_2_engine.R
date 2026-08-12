repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_2_engine.R"))

testthat::test_that("HYP-MOM-04.2 contract freezes the atlas and predefined search", {
  contract <- h042_validate_contract()
  testthat::expect_equal(contract$program_id, "HYP-MOM-04.2")
  testthat::expect_length(contract$feature_names, 33L)
  testthat::expect_length(contract$baskets, 9L)
  testthat::expect_equal(contract$outer_train_quarters, c(9L, 12L))
  testthat::expect_equal(contract$permutation_draws, 200L)
  testthat::expect_error(h042_validate_contract(within(contract, permutation_draws <- 201L)), "changed")
})

testthat::test_that("closed-form trend regression returns stable slope and R-squared", {
  close <- exp(1 + 0.01 * seq_len(63L))
  stats <- h042_regression_stats(close)
  testthat::expect_equal(unname(stats[["slope"]]), 0.01, tolerance = 1e-12)
  testthat::expect_equal(unname(stats[["r2"]]), 1, tolerance = 1e-12)
})

testthat::test_that("causal asset feature rows use only signal-close history and later target opens", {
  dates <- seq.Date(as.Date("2019-01-01"), by = "day", length.out = 520L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5]
  n <- length(dates)
  close <- 50 * exp(seq(0, 0.40, length.out = n) + 0.01 * sin(seq_len(n) / 9))
  bars <- data.frame(
    symbol = "AAA", session_date = dates, open = close * 1.001,
    high = close * 1.01, low = close * 0.99, close = close,
    volume = 1e6 + 1000 * seq_len(n), stringsAsFactors = FALSE
  )
  market <- transform(bars, symbol = "SPY", open = open * 2, high = high * 2,
                      low = low * 2, close = close * 2)
  signal_index <- 300L
  schedule <- data.frame(
    signal_quarter = "2019Q4", target_quarter = "2020Q1",
    signal_date = dates[[signal_index]], entry_date = dates[[signal_index + 1L]],
    exit_date = dates[[signal_index + 20L]], stringsAsFactors = FALSE
  )
  identity <- data.frame(instance_id = "I1", symbol = "AAA", sector = "Test",
                         cohort = "SYNTHETIC", stringsAsFactors = FALSE)
  row <- h042_asset_rows(bars, market, schedule, identity)
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_true(all(is.finite(as.matrix(row[h042_feature_dictionary()$feature[h042_feature_dictionary()$feature != "sector_relative126"]]))))
  testthat::expect_equal(row$entry_open, bars$open[[signal_index + 1L]])
  testthat::expect_equal(row$exit_open, bars$open[[signal_index + 20L]])
  testthat::expect_gt(row$ret126, 0)
})

h042_synthetic_panel <- function(n_assets = 40L) {
  contract <- h042_contract()
  set.seed(42)
  rows <- do.call(rbind, lapply(seq_along(contract$train_signal_quarters), function(q) {
    z <- stats::rnorm(n_assets)
    out <- data.frame(
      row_id = ((q - 1L) * n_assets + 1L):(q * n_assets),
      signal_quarter = contract$train_signal_quarters[[q]],
      symbol = paste0("S", seq_len(n_assets)), sector = rep(c("A", "B", "C", "D"), length.out = n_assets),
      target_relative_return = 0.03 * z + stats::rnorm(n_assets, sd = 0.01),
      stringsAsFactors = FALSE
    )
    for (feature in contract$feature_names) out[[feature]] <- z + stats::rnorm(n_assets, sd = 0.5)
    for (feature in contract$feature_names) out[[paste0(feature, "_rn")]] <- h04_rank_normal(out[[feature]])
    out
  }))
  rows
}

testthat::test_that("feature diagnostics retain quarter-aware and redundancy evidence", {
  panel <- h042_synthetic_panel()
  diagnostics <- h042_feature_diagnostics(panel)
  testthat::expect_equal(nrow(diagnostics$quarterly), 33L * 15L)
  testthat::expect_equal(nrow(diagnostics$scorecard), 33L)
  testthat::expect_equal(dim(diagnostics$redundancy), c(33L, 33L))
  testthat::expect_true(all(diagnostics$scorecard$positive_ic_fraction >= 0 &
                            diagnostics$scorecard$positive_ic_fraction <= 1))
})

testthat::test_that("nested outer validation keeps later TRAIN blocks untouched during selection", {
  panel <- h042_synthetic_panel()
  nested <- h042_nested_outer(panel, candidates = "FIXED_THEORY_CORE")
  testthat::expect_equal(nrow(nested$metrics), 6L)
  testthat::expect_equal(nested$metrics$signal_quarter, h042_contract()$train_signal_quarters[10:15])
  testthat::expect_true(all(nested$selections$candidate == "FIXED_THEORY_CORE"))
  testthat::expect_equal(sort(unique(nested$predictions$outer_fold)), 1:2)
  testthat::expect_gt(mean(nested$metrics$rank_ic), 0)
})
