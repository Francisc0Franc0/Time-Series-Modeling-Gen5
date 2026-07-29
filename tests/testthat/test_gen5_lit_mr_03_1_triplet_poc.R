source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_03_1_triplet_poc.R"
))

mr03_sessions <- function(n = 500L) {
  dates <- seq(as.Date("2016-01-04"), by = "day", length.out = ceiling(n * 7 / 5) + 20L)
  dates <- dates[!as.POSIXlt(dates)$wday %in% c(0L, 6L)]
  head(dates, n)
}

mr03_synthetic_panel <- function(n = 500L) {
  set.seed(42)
  dates <- mr03_sessions(n)
  x2 <- 100 + cumsum(stats::rnorm(n, 0.03, 0.6))
  x3 <- 80 + cumsum(stats::rnorm(n, 0.02, 0.5))
  spread <- numeric(n)
  for (i in 2:n) {
    spread[[i]] <- 0.82 * spread[[i - 1L]] + stats::rnorm(1, 0, 0.4)
  }
  beta <- c(1, -0.6, -0.4)
  x1 <- spread - beta[[2L]] * x2 - beta[[3L]] * x3
  data.frame(
    session_date = dates,
    open_1 = x1 * (1 + 0.0005),
    close_1 = x1,
    open_2 = x2 * (1 - 0.0003),
    close_2 = x2,
    open_3 = x3 * (1 + 0.0002),
    close_3 = x3,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("triplet contract and registry are finite and frozen", {
  contract <- g5_mr03_contract()
  registry <- g5_mr03_registry()
  testthat::expect_equal(contract$train_end, as.Date("2020-12-31"))
  testthat::expect_equal(contract$development_end, as.Date("2023-12-29"))
  testthat::expect_equal(nrow(registry), 8L)
  testthat::expect_equal(registry$triplet_id[[1L]], "T01_EWA_EWC_IGE")
  testthat::expect_equal(registry$triplet_id[[8L]], "T08_XLF_JPM_BAC")
  testthat::expect_equal(length(g5_mr03_required_symbols(registry)), 21L)
})

testthat::test_that("triplet registry mutation fails loudly", {
  registry <- g5_mr03_registry()
  registry$symbol_1[[1L]] <- "SPY"
  testthat::expect_error(
    g5_mr03_validate_registry(registry),
    "frozen triplet registry changed"
  )
})

testthat::test_that("base-R Johansen fit recovers a finite mixed-sign vector", {
  panel <- mr03_synthetic_panel()
  fit <- g5_mr03_johansen_fit(as.matrix(panel[paste0("close_", 1:3)]))
  testthat::expect_equal(fit$beta[[1L]], 1, tolerance = 1e-10)
  testthat::expect_true(all(is.finite(fit$beta)))
  testthat::expect_true(any(fit$beta > 0) && any(fit$beta < 0))
  testthat::expect_true(all(diff(fit$eigenvalues) <= 0))
  testthat::expect_true(all(is.finite(fit$trace_statistics)))
})

testthat::test_that("triplet signals replay at next open with normalized gross", {
  panel <- mr03_synthetic_panel()
  beta <- c(1, -0.6, -0.4)
  contract <- g5_mr03_contract()
  indicators <- g5_mr03_signal_states(
    g5_mr03_indicators(panel, beta, contract),
    contract
  )
  replay <- g5_mr03_build_replay(
    indicators, beta, c("AAA", "BBB", "CCC"), contract
  )
  active <- replay[replay$target_state != 0L, , drop = FALSE]
  testthat::expect_gt(nrow(active), 0L)
  testthat::expect_true(all(replay$signal_date < replay$execution_date))
  testthat::expect_true(all(replay$execution_date < replay$next_execution_date))
  testthat::expect_true(all(abs(active$gross_exposure - 1) < 1e-10))
  testthat::expect_true(all(replay$turnover >= 0))
  testthat::expect_true(all(replay$primary_cost >= 0))
})

testthat::test_that("triplet module contains no implicit current-date call", {
  path <- testthat::test_path(
    "..", "..", "R", "gen5_lit_mr_03_1_triplet_poc.R"
  )
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
