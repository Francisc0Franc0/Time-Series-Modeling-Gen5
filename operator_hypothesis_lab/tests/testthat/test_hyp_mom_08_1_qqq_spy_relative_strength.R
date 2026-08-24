repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mom_08_1_qqq_spy_relative_strength.R"))

hm081_fixture_bars <- function(end_date = as.Date("2023-12-29")) {
  dates <- seq.Date(as.Date("2016-01-04"), end_date, by = "day")
  i <- seq_along(dates)
  spy_close <- 100 * exp(0.00025 * i + 0.012 * sin(i / 37))
  relative <- 0.00008 * i + 0.018 * sin(i / 29)
  qqq_close <- spy_close * exp(relative)
  make <- function(symbol, close, phase) {
    open <- close * exp(0.001 * cos(i / phase))
    data.frame(
      symbol = symbol, session_date = dates, open = open,
      high = pmax(open, close) * 1.002, low = pmin(open, close) * 0.998,
      close = close, volume = 1e6, adjusted = TRUE, timeframe = "1D",
      stringsAsFactors = FALSE
    )
  }
  rbind(make("QQQ", qqq_close, 13), make("SPY", spy_close, 17))
}

testthat::test_that("HYP-MOM-08.1 freezes symbols, surface, and evidence seals", {
  contract <- g5_hm081_contract()
  testthat::expect_identical(contract$symbols, c("QQQ", "SPY"))
  testthat::expect_identical(contract$lookback_grid, c(5L, 20L, 60L))
  testthat::expect_identical(contract$target_grid, c(1L, 5L, 20L))
  testthat::expect_true(contract$development_end < contract$confirmation_start)
  testthat::expect_true(contract$confirmation_end < as.Date("2026-01-01"))
  changed <- contract
  changed$target_grid <- c(1L, 5L)
  testthat::expect_error(g5_hm081_validate_contract(changed), "Frozen HYP-MOM-08.1 contract changed")
})

testthat::test_that("aligned panels construct exact causal relative log returns", {
  contract <- g5_hm081_contract()
  panel <- g5_hm081_zone_panel(
    hm081_fixture_bars(as.Date("2020-12-31")),
    contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  i <- panel$anchor_index[[1L]]
  l_i <- match(20L, contract$lookback_grid)
  h_i <- match(5L, contract$target_grid)
  expected_x <- log(panel$wide$close_qqq[i] / panel$wide$close_qqq[i - 20L]) -
    log(panel$wide$close_spy[i] / panel$wide$close_spy[i - 20L])
  expected_y <- log(panel$wide$open_qqq[i + 6L] / panel$wide$open_qqq[i + 1L]) -
    log(panel$wide$open_spy[i + 6L] / panel$wide$open_spy[i + 1L])
  testthat::expect_equal(unname(panel$x_relative[1L, l_i]), expected_x)
  testthat::expect_equal(unname(panel$y_relative[1L, h_i]), expected_y)
  testthat::expect_true(all(panel$maximum_exit_date <= contract$train_end))
})

testthat::test_that("surface, shifts, and nomination are deterministic", {
  contract <- g5_hm081_contract()
  panel <- g5_hm081_zone_panel(
    hm081_fixture_bars(as.Date("2020-12-31")),
    contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  surface <- g5_hm081_surface(panel, contract)
  testthat::expect_equal(nrow(surface), 9L)
  testthat::expect_equal(anyDuplicated(surface$cell_id), 0L)
  shifts <- g5_hm081_admissible_shifts(nrow(panel$x_relative), contract$circular_shift_minimum)
  testthat::expect_true(all(pmin(shifts, nrow(panel$x_relative) - shifts) >= 60L))
  tied <- data.frame(
    cell_id = c("L20_H5", "L5_H5", "L20_H1"),
    lookback_sessions = c(20L, 5L, 20L),
    target_sessions = c(5L, 5L, 1L),
    correlation = c(0.2, 0.2, 0.2)
  )
  testthat::expect_identical(g5_hm081_nominate(tied, TRUE)$cell_id, "L20_H1")
})

testthat::test_that("bar validation rejects mismatched sessions and sealed dates", {
  contract <- g5_hm081_contract()
  bars <- hm081_fixture_bars(as.Date("2020-12-31"))
  dropped <- bars[!(bars$symbol == "SPY" & bars$session_date == as.Date("2018-06-01")), ]
  testthat::expect_error(g5_hm081_validate_bars(dropped, contract$train_end), "identical_common_sessions")
  extra <- bars[bars$session_date == max(bars$session_date), ]
  extra$session_date <- as.Date("2026-01-02")
  testthat::expect_error(g5_hm081_validate_bars(rbind(bars, extra), contract$confirmation_end), "maximum_date_seal")
})

testthat::test_that("bootstrap and frozen model comparison are deterministic", {
  contract <- g5_hm081_contract()
  n <- 30L
  x <- sin(seq_len(n) / 4)
  x_spy <- 0.2 * cos(seq_len(n) / 5)
  pairs <- data.frame(
    anchor_date = seq.Date(as.Date("2021-01-04"), by = "day", length.out = n),
    x_relative = x, x_qqq = x + x_spy, x_spy = x_spy,
    y_relative = 0.3 * x + 0.01 * cos(seq_len(n) / 3)
  )
  first <- g5_hm081_bootstrap_beta(pairs, contract)
  second <- g5_hm081_bootstrap_beta(pairs, contract)
  testthat::expect_identical(first, second)
  models <- g5_hm081_model_predictions(pairs, pairs)
  testthat::expect_identical(models$model_id, c("DRIFT", "RELATIVE", "QQQ_LEG", "SPY_LEG", "TWO_LEG"))
  testthat::expect_true(models$development_mse[models$model_id == "RELATIVE"] <
                        models$development_mse[models$model_id == "DRIFT"])
})

testthat::test_that("strategy and performance surfaces remain absent", {
  function_text <- paste(deparse(body(g5_hm081_run_development)), collapse = " ")
  testthat::expect_false(grepl("sharpe|drawdown|pnl|wealth|position|turnover", function_text, ignore.case = TRUE))
})
