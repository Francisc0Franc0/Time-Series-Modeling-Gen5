repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mom_07_1_qqq_equal_weight_leadership.R"))

hm071_fixture_bars <- function(end_date = as.Date("2023-12-29")) {
  dates <- seq.Date(as.Date("2016-01-04"), end_date, by = "day")
  i <- seq_along(dates)
  qqq_close <- 100 * exp(0.0004 * i + 0.02 * sin(i / 31))
  qqew_close <- 100 * exp(0.0003 * i + 0.015 * sin(i / 37))
  make <- function(symbol, close, phase) {
    open <- close * exp(0.001 * cos(i / phase))
    data.frame(symbol = symbol, session_date = dates, open = open,
               high = pmax(open, close) * 1.002, low = pmin(open, close) * 0.998,
               close = close, volume = 1e6, adjusted = TRUE, timeframe = "1D",
               stringsAsFactors = FALSE)
  }
  rbind(make("QQQ", qqq_close, 13), make("QQEW", qqew_close, 17))
}

testthat::test_that("HYP-MOM-07.1 contract freezes source and nine-cell boundary", {
  contract <- g5_hm071_contract()
  testthat::expect_identical(contract$symbols, c("QQQ", "QQEW"))
  testthat::expect_identical(contract$lookback_grid, c(5L, 20L, 60L))
  testthat::expect_identical(contract$target_grid, c(1L, 5L, 20L))
  testthat::expect_true(contract$confirmation_end < contract$qqew_mandate_change)
  changed <- contract
  changed$target_grid <- c(1L, 5L)
  testthat::expect_error(g5_hm071_validate_contract(changed), "Frozen HYP-MOM-07.1 contract changed")
})

testthat::test_that("aligned panels construct exact log-return spreads", {
  contract <- g5_hm071_contract()
  panel <- g5_hm071_zone_panel(hm071_fixture_bars(as.Date("2020-12-31")), contract$train_start, contract$train_end)
  i <- panel$anchor_index[[1L]]
  l_i <- match(20L, contract$lookback_grid)
  h_i <- match(5L, contract$target_grid)
  expected_x <- log(panel$wide$close_qqq[i] / panel$wide$close_qqq[i - 20L]) -
    log(panel$wide$close_qqew[i] / panel$wide$close_qqew[i - 20L])
  expected_y <- log(panel$wide$open_qqq[i + 6L] / panel$wide$open_qqq[i + 1L]) -
    log(panel$wide$open_qqew[i + 6L] / panel$wide$open_qqew[i + 1L])
  testthat::expect_equal(unname(panel$x_spread[1L, l_i]), expected_x)
  testthat::expect_equal(unname(panel$y_spread[1L, h_i]), expected_y)
  testthat::expect_true(all(panel$maximum_exit_date <= contract$train_end))
})

testthat::test_that("surface, shifts, and nomination are deterministic", {
  contract <- g5_hm071_contract()
  panel <- g5_hm071_zone_panel(hm071_fixture_bars(as.Date("2020-12-31")), contract$train_start, contract$train_end)
  surface <- g5_hm071_surface(panel, contract)
  testthat::expect_equal(nrow(surface), 9L)
  testthat::expect_equal(anyDuplicated(surface$cell_id), 0L)
  shifts <- g5_hm071_admissible_shifts(nrow(panel$x_spread), contract$circular_shift_minimum)
  testthat::expect_true(all(pmin(shifts, nrow(panel$x_spread) - shifts) >= 60L))
  tied <- data.frame(cell_id = c("L20_H5", "L5_H5", "L20_H1"),
                     lookback_sessions = c(20L, 5L, 20L), target_sessions = c(5L, 5L, 1L),
                     correlation = c(0.2, 0.2, 0.2))
  testthat::expect_identical(g5_hm071_nominate(tied, TRUE)$cell_id, "L20_H1")
})

testthat::test_that("bar validation rejects mismatched sessions and mandate-change rows", {
  contract <- g5_hm071_contract()
  bars <- hm071_fixture_bars(as.Date("2020-12-31"))
  dropped <- bars[!(bars$symbol == "QQEW" & bars$session_date == as.Date("2018-06-01")), ]
  testthat::expect_error(g5_hm071_validate_bars(dropped, contract$train_end), "identical_common_sessions")
  extra <- bars[bars$session_date == max(bars$session_date), ]
  extra$session_date <- contract$qqew_mandate_change
  testthat::expect_error(g5_hm071_validate_bars(rbind(bars, extra), contract$confirmation_end), "maximum_date_seal")
})

testthat::test_that("stationary bootstrap and frozen model comparison are deterministic", {
  contract <- g5_hm071_contract()
  n <- 700L
  x <- sin(seq_len(n) / 13)
  x_qqew <- 0.2 * sin(seq_len(n) / 17) + 0.05 * cos(seq_len(n) / 29)
  pairs <- data.frame(anchor_date = seq.Date(as.Date("2021-01-04"), by = "day", length.out = n),
                      x_spread = x, x_qqq = x + x_qqew, x_qqew = x_qqew,
                      y_spread = 0.3 * x + 0.01 * cos(seq_len(n) / 7))
  first <- g5_hm071_bootstrap_beta(pairs, contract)
  second <- g5_hm071_bootstrap_beta(pairs, contract)
  testthat::expect_identical(first, second)
  models <- g5_hm071_model_predictions(pairs, pairs)
  testthat::expect_identical(models$model_id, c("DRIFT", "SPREAD", "QQQ_LEG", "QQEW_LEG", "TWO_LEG"))
  testthat::expect_true(models$development_mse[models$model_id == "SPREAD"] < models$development_mse[models$model_id == "DRIFT"])
})

testthat::test_that("strategy and performance surfaces remain absent", {
  function_text <- paste(deparse(body(g5_hm071_run_development)), collapse = " ")
  testthat::expect_false(grepl("sharpe|drawdown|pnl|wealth|position|turnover", function_text, ignore.case = TRUE))
})
