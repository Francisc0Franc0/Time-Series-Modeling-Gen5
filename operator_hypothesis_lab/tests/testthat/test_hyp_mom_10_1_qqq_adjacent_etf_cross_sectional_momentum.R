repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mom_10_1_qqq_adjacent_etf_cross_sectional_momentum.R"))

testthat::test_that("HYP-MOM-10.1 contract freezes twelve ETFs and four sleeves", {
  contract <- g5_hm101_contract()
  testthat::expect_equal(nrow(contract$universe), 12L)
  testthat::expect_equal(length(unique(contract$universe$sleeve)), 4L)
  testthat::expect_equal(contract$lookback_grid, c(5L, 20L, 60L))
  testthat::expect_equal(contract$target_grid, c(1L, 5L, 20L))
  testthat::expect_error(g5_hm101_validate_contract(within(contract, target_grid <- c(1L, 5L))), "contract changed")
})

testthat::test_that("row centering removes common return exactly", {
  x <- matrix(c(1, 2, 3, 5, 7, 9), nrow = 2L, byrow = TRUE)
  centered <- g5_hm101_center_rows(x)
  testthat::expect_equal(rowMeans(centered), c(0, 0), tolerance = 1e-12)
  testthat::expect_equal(centered[1L, ], c(-1, 0, 1))
})

testthat::test_that("rank IC and top-bottom recover perfect positive ordering", {
  x <- rbind(1:12, 12:1, seq(2, 24, by = 2))
  y <- 0.03 * x
  ic <- g5_hm101_row_rank_ic(g5_hm101_rank_rows(x), g5_hm101_rank_rows(y))
  spread <- g5_hm101_top_bottom(x, y, 3L)
  testthat::expect_equal(ic, rep(1, 3L), tolerance = 1e-12)
  testthat::expect_true(all(spread > 0))
})

testthat::test_that("circular shifts respect the frozen displacement", {
  shifts <- g5_hm101_admissible_shifts(200L, 60L)
  testthat::expect_true(all(pmin(shifts, 200L - shifts) >= 60L))
  testthat::expect_equal(range(shifts), c(60L, 140L))
})

testthat::test_that("cell rows retain one row per date and asset", {
  contract <- g5_hm101_contract()
  n <- 4L; p <- 12L
  panel <- list(
    anchor_date = as.Date("2020-01-01") + seq_len(n),
    symbols = contract$universe$symbol,
    sleeves = setNames(contract$universe$sleeve, contract$universe$symbol),
    raw_x = rep(list(matrix(seq_len(n * p), nrow = n)), 3L),
    relative_x = rep(list(matrix(seq_len(n * p), nrow = n)), 3L),
    relative_y = rep(list(matrix(seq_len(n * p), nrow = n)), 3L)
  )
  cell <- data.frame(lookback_sessions = 5L, target_sessions = 1L)
  rows <- g5_hm101_cell_rows(panel, cell, contract)
  testthat::expect_equal(nrow(rows), n * p)
  testthat::expect_equal(length(unique(rows$anchor_date)), n)
  testthat::expect_equal(length(unique(rows$symbol)), p)
})
