repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_3_spy_horizon_surface.R"
))

mom013_fixture_bars <- function() {
  dates <- seq.Date(as.Date("2016-01-04"), as.Date("2023-12-29"), by = "day")
  index <- seq_along(dates)
  close <- 100 * exp(0.0003 * index + 0.03 * sin(index / 19))
  open <- close * exp(0.002 * cos(index / 11))
  data.frame(
    symbol = "SPY",
    session_date = dates,
    open = open,
    high = pmax(open, close) * 1.002,
    low = pmin(open, close) * 0.998,
    close = close,
    volume = 1e6,
    adjusted = TRUE,
    timeframe = "1D",
    stringsAsFactors = FALSE
  )
}

testthat::test_that("LIT-MOM-01.3 contract freezes the 28-cell outcome boundary", {
  contract <- g5_mom013_contract()
  testthat::expect_identical(contract$lookback_grid, c(1L, 5L, 10L, 25L, 60L, 120L, 250L))
  testthat::expect_identical(contract$target_grid, c(5L, 10L, 25L, 60L))
  testthat::expect_equal(length(contract$lookback_grid) * length(contract$target_grid), 28L)
  testthat::expect_false(contract$confirmation_start <= contract$sandbox_end)
  changed <- contract
  changed$target_grid <- c(5L, 10L, 25L)
  testthat::expect_error(
    g5_mom013_validate_contract(changed),
    "Frozen LIT-MOM-01.3 contract changed"
  )
})

testthat::test_that("common anchors and causal endpoints are exact across all cells", {
  contract <- g5_mom013_contract()
  bars <- mom013_fixture_bars()
  panel <- g5_mom013_common_panel(bars, contract)
  testthat::expect_true(nrow(panel$x) > 400L)
  testthat::expect_identical(dim(panel$x)[[2L]], 7L)
  testthat::expect_identical(dim(panel$y)[[2L]], 4L)
  testthat::expect_identical(nrow(panel$x), nrow(panel$y))
  i <- panel$anchor_index[[1L]]
  l_i <- match(250L, contract$lookback_grid)
  h_i <- match(25L, contract$target_grid)
  testthat::expect_equal(
    unname(panel$x[1L, l_i]), log(panel$bars$close[i] / panel$bars$close[i - 250L])
  )
  testthat::expect_equal(
    unname(panel$y[1L, h_i]), log(panel$bars$open[i + 26L] / panel$bars$open[i + 1L])
  )
  testthat::expect_true(all(panel$maximum_exit_date <= contract$sandbox_end))
})

testthat::test_that("surface is complete and canonical 250/25 remains one anchor", {
  contract <- g5_mom013_contract()
  panel <- g5_mom013_common_panel(mom013_fixture_bars(), contract)
  surface <- g5_mom013_surface(panel, contract)
  testthat::expect_equal(nrow(surface), 28L)
  testthat::expect_equal(anyDuplicated(surface$cell_id), 0L)
  testthat::expect_equal(sum(surface$is_canonical_250_25), 1L)
  testthat::expect_true(all(surface$anchor_count == nrow(panel$x)))
})

testthat::test_that("circular shifts preserve rows and enforce displacement", {
  matrix <- cbind(a = 1:8, b = 11:18)
  shifted <- g5_mom013_rotate_rows(matrix, 3L)
  testthat::expect_identical(shifted[, "a"], c(4:8, 1:3))
  shifts <- g5_mom013_admissible_shifts(1000L, 250L)
  testthat::expect_true(all(pmin(shifts, 1000L - shifts) >= 250L))
  testthat::expect_identical(range(shifts), c(250L, 750L))
})

testthat::test_that("deterministic nomination obeys correlation and tie rules", {
  surface <- data.frame(
    cell_id = c("L60_H25", "L25_H25", "L60_H10"),
    lookback_sessions = c(60L, 25L, 60L),
    target_sessions = c(25L, 25L, 10L),
    correlation = c(0.2, 0.2, 0.2),
    stringsAsFactors = FALSE
  )
  nominee <- g5_mom013_nominate(surface, TRUE)
  testthat::expect_identical(nominee$cell_id, "L60_H10")
  testthat::expect_equal(nrow(g5_mom013_nominate(surface, FALSE)), 0L)
})

testthat::test_that("stationary bootstrap is deterministic and returns every cell", {
  panel <- g5_mom013_common_panel(mom013_fixture_bars(), g5_mom013_contract())
  set.seed(20260821L)
  first <- g5_mom013_stationary_indices(nrow(panel$x), 60)
  set.seed(20260821L)
  second <- g5_mom013_stationary_indices(nrow(panel$x), 60)
  testthat::expect_identical(first, second)
  beta <- g5_mom013_beta_matrix(panel$x[first, , drop = FALSE], panel$y[first, , drop = FALSE])
  testthat::expect_identical(dim(beta), c(7L, 4L))
  testthat::expect_true(all(is.finite(beta)))
})

testthat::test_that("confirmation bars are rejected and no strategy fields exist", {
  bars <- mom013_fixture_bars()
  extra <- tail(bars, 1L)
  extra$session_date <- as.Date("2024-01-02")
  bars <- rbind(bars, extra)
  testthat::expect_error(
    g5_mom013_validate_bars(bars),
    "confirmation_excluded"
  )
  function_text <- paste(deparse(body(g5_mom013_run_sandbox)), collapse = " ")
  testthat::expect_false(grepl("sharpe|drawdown|pnl|wealth|position", function_text, ignore.case = TRUE))
})
