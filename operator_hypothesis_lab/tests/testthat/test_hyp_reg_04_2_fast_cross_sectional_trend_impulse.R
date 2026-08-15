source(testthat::test_path("..", "..", "R", "hyp_reg_04_2_fast_cross_sectional_trend_impulse.R"))

testthat::test_that("HYP-REG-04.2 contract freezes the derivative evidence boundary", {
  contract <- hreg42_contract()
  testthat::expect_identical(contract$hypothesis_id, "HYP-REG-04.2")
  testthat::expect_identical(contract$fast_horizon, 5L)
  testthat::expect_identical(contract$context_horizon, 20L)
  testthat::expect_identical(contract$durability_horizon, 10L)
  testthat::expect_identical(contract$decay_horizon, 20L)
  testthat::expect_equal(contract$confirmation_start, as.Date("2024-01-02"))
  testthat::expect_identical(contract$signal_assets, 24L)
  testthat::expect_identical(contract$simulations, 200L)
})

testthat::test_that("next-open targets begin after the signal close", {
  open <- c(100, 102, 101, 106, 108, 110, 111)
  target <- hreg42_forward_open_return(open, 2L)
  testthat::expect_equal(target[[1L]], log(106 / 102))
  testthat::expect_equal(target[[2L]], log(108 / 101))
  testthat::expect_true(all(is.na(tail(target, 3L))))
  testthat::expect_error(hreg42_forward_open_return(open, 0L), "must be positive")
})

testthat::test_that("the volatility normalizer is lagged before the current return", {
  returns <- c(rep(c(-0.01, 0.01), 40L), 0.40)
  current_inclusive <- hreg42_roll_sd(returns, 63L)
  prior <- hreg42_lag(current_inclusive, 1L)
  testthat::expect_lt(prior[[81L]], current_inclusive[[81L]])
  testthat::expect_equal(prior[[81L]], current_inclusive[[80L]])
})

testthat::test_that("state classification requires both breadth and current impulse", {
  state <- hreg42_classify_state(
    direction5 = c(1, 1, -1, -1, 1),
    participation5 = c(.70, .70, .30, .30, .55),
    participation_impulse = c(.10, -.10, -.10, .10, .20)
  )
  testthat::expect_identical(state, c("BROAD_UP_IMPULSE", "OTHER_UP", "BROAD_DOWN_IMPULSE", "OTHER_DOWN", "OTHER_UP"))
})

testthat::test_that("medium context distinguishes continuation from reversal", {
  context <- hreg42_classify_context(c(1, 1, -1, -1), c(1, -1, -1, 1))
  testthat::expect_identical(context, c("UP_CONTINUATION", "UP_REVERSAL", "DOWN_CONTINUATION", "DOWN_REVERSAL"))
})

testthat::test_that("bar validation rejects duplicate and confirmation rows", {
  bars <- data.frame(
    symbol = c("SPY", "SPY"),
    session_date = as.Date(c("2023-12-28", "2023-12-28")),
    open = 1, high = 1, low = 1, close = 1, volume = 1
  )
  testthat::expect_error(hreg42_validate_bars(bars), "duplicated")
  bars$session_date <- as.Date(c("2023-12-28", "2024-01-02"))
  testthat::expect_error(hreg42_validate_bars(bars), "Confirmation")
})

testthat::test_that("future prices cannot change a previously known fast score", {
  dates <- seq.Date(as.Date("2018-01-01"), by = "day", length.out = 120L)
  close <- 100 * exp(cumsum(0.0005 + 0.004 * sin(seq_along(dates))))
  bars <- data.frame(symbol = "X", session_date = dates, close = close)
  base <- hreg42_asset_component(bars, "X")
  shocked <- bars
  shocked$close[101:120] <- shocked$close[101:120] * 3
  changed <- hreg42_asset_component(shocked, "X")
  testthat::expect_equal(base$z5[90L], changed$z5[90L])
  testthat::expect_false(isTRUE(all.equal(base$future_return_h20[90L], changed$future_return_h20[90L])))
})

testthat::test_that("continuous summaries preserve the frozen target map", {
  ledger <- data.frame(
    direction5 = 1:8,
    participation5 = seq(.2, .9, length.out = 8),
    participation_impulse = seq(-.2, .2, length.out = 8),
    alignment = rep(c(0, 1), 4),
    future_field_return_h5 = 1:8,
    future_participation_change_h5 = seq(-.1, .1, length.out = 8),
    directional_persistence_h5 = 1:8,
    future_field_return_h10 = 1:8,
    future_field_return_h20 = 1:8,
    spy_return_h5 = 1:8,
    spy_return_h10 = 1:8,
    spy_up_h5 = c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE)
  )
  out <- hreg42_continuous_summary(ledger)
  testthat::expect_equal(nrow(out), 9L)
  testthat::expect_true(all(c("future_field_return_h5", "future_participation_change_h5", "spy_up_h5_auc") %in% out$target))
  testthat::expect_equal(out$spearman[out$target == "spy_up_h5_auc"], 1)
})

testthat::test_that("circular state shifts preserve within-year state counts", {
  ledger <- data.frame(
    session_date = as.Date(c("2018-01-01", "2018-01-02", "2018-01-03", "2019-01-01", "2019-01-02", "2019-01-03")),
    state = c("A", "B", "B", "A", "A", "B")
  )
  shifted <- hreg42_shift_states(ledger, 7L)
  for (year in c("2018", "2019")) {
    idx <- format(ledger$session_date, "%Y") == year
    testthat::expect_identical(sort(table(shifted[idx])), sort(table(ledger$state[idx])))
  }
})

testthat::test_that("the frozen registry remains equal-group and excludes SPY from the field", {
  registry <- utils::read.csv(testthat::test_path("..", "..", "registries", "hyp_reg_04_2_fast_cross_sectional_trend_impulse_registry.csv"), stringsAsFactors = FALSE)
  signals <- registry[registry$role == "field_signal", ]
  testthat::expect_equal(nrow(registry), 25L)
  testthat::expect_equal(nrow(signals), 24L)
  testthat::expect_equal(length(unique(signals$group)), 4L)
  testthat::expect_false("SPY" %in% signals$symbol)
  testthat::expect_identical(registry$symbol[registry$role == "context_target"], "SPY")
})
