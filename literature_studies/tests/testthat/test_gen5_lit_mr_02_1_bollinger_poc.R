source(testthat::test_path("..", "..", "R", "gen5_lit_mr_02_1_bollinger_poc.R"))

mr02_sessions <- function(start = as.Date("2015-09-01"), n = 1450L) {
  dates <- seq(start, by = "day", length.out = ceiling(n * 7 / 5) + 20L)
  dates <- dates[!as.POSIXlt(dates)$wday %in% c(0L, 6L)]
  head(dates, n)
}

mr02_bars <- function(n = 1450L, oscillating = TRUE) {
  dates <- mr02_sessions(n = n)
  i <- seq_along(dates)
  gld <- 100 + 0.10 * i + 5 * sin(i / 31)
  residual <- if (oscillating) 2 * sin(i / 7) else rep(0, length(i))
  uso <- 1.8 * gld + 20 + residual
  make <- function(symbol, close) {
    open <- close * (1 + 0.001 * sin(i / 3))
    data.frame(
      symbol = symbol,
      session_date = dates,
      open = open,
      high = pmax(open, close) * 1.002,
      low = pmin(open, close) * 0.998,
      close = close,
      volume = 1000000 + i,
      stringsAsFactors = FALSE
    )
  }
  rbind(make("GLD", gld), make("USO", uso))
}

testthat::test_that("frozen contract carries the literature identifier and source mechanics", {
  contract <- g5_mr02_contract()
  testthat::expect_equal(contract$literature_id, "LIT-MR-02.1")
  testthat::expect_equal(g5_mr02_required_symbols(contract), c("GLD", "USO"))
  testthat::expect_equal(contract$lookback_sessions, 20L)
  testthat::expect_equal(contract$entry_z, 1)
  testthat::expect_equal(contract$exit_z, 0)
  testthat::expect_equal(contract$bootstrap_seed, 5801L)
  testthat::expect_equal(contract$random_seed, 5802L)
})

testthat::test_that("rolling spread uses raw price levels and the frozen orientation", {
  contract <- g5_mr02_contract()
  panel <- g5_mr02_common_panel(mr02_bars(), contract)
  indicators <- g5_mr02_rolling_indicators(panel, contract)
  row <- which(is.finite(indicators$z_score))[[1L]]
  testthat::expect_equal(
    indicators$spread[[row]],
    indicators$close_y[[row]] - indicators$beta[[row]] * indicators$close_x[[row]],
    tolerance = 1e-12
  )
  testthat::expect_gt(indicators$beta[[row]], 0)
  testthat::expect_equal(
    indicators$z_score[[row]],
    (indicators$spread[[row]] - indicators$spread_mean[[row]]) /
      indicators$spread_sd[[row]],
    tolerance = 1e-12
  )
})

testthat::test_that("state machine buys a low spread and shorts a high spread", {
  contract <- g5_mr02_contract()
  indicators <- data.frame(
    z_score = c(NA, -1.2, -0.5, 0.1, 1.3, 0.4, -0.1),
    beta = rep(1, 7)
  )
  out <- g5_mr02_signal_states(indicators, contract)
  testthat::expect_equal(out$target_state, c(0L, 1L, 1L, 0L, -1L, -1L, 0L))
  testthat::expect_equal(
    out$signal_action,
    c(
      "invalid_flat", "enter_long_spread", "carry_position",
      "exit_long_spread", "enter_short_spread", "carry_position",
      "exit_short_spread"
    )
  )
})

testthat::test_that("replay executes next open with economically consistent normalized legs", {
  contract <- g5_mr02_contract()
  indicators <- g5_mr02_signal_states(
    g5_mr02_rolling_indicators(
      g5_mr02_common_panel(mr02_bars(), contract),
      contract
    ),
    contract
  )
  replay <- g5_mr02_build_replay(indicators, contract)
  active <- replay[replay$target_state != 0L, , drop = FALSE]
  testthat::expect_true(all(active$signal_date < active$execution_date))
  testthat::expect_true(all(active$execution_date < active$next_execution_date))
  testthat::expect_true(all(abs(active$gross_exposure - 1) < 1e-10))
  long <- active[active$target_state == 1L, , drop = FALSE]
  short <- active[active$target_state == -1L, , drop = FALSE]
  testthat::expect_true(all(long$weight_uso > 0 & long$weight_gld < 0))
  testthat::expect_true(all(short$weight_uso < 0 & short$weight_gld > 0))
  testthat::expect_true(all(replay$primary_cost >= 0))
  testthat::expect_true(all(replay$stress_net_return <= replay$gross_return + 1e-12))
})

testthat::test_that("trade tape includes entry, adaptive rehedging, and exit costs", {
  contract <- g5_mr02_contract()
  indicators <- g5_mr02_signal_states(
    g5_mr02_rolling_indicators(
      g5_mr02_common_panel(mr02_bars(), contract),
      contract
    ),
    contract
  )
  replay <- g5_mr02_build_replay(indicators, contract)
  trades <- g5_mr02_trade_summary(replay)
  completed <- trades[trades$completed, , drop = FALSE]
  testthat::expect_gt(nrow(completed), 0)
  testthat::expect_true(all(completed$primary_cost > 0))
  testthat::expect_true(all(completed$holding_bars >= 1L))
  testthat::expect_true(all(completed$direction %in% c(-1L, 1L)))
})

testthat::test_that("statistical diagnostics remain separate from trading gates", {
  contract <- g5_mr02_contract()
  indicators <- g5_mr02_rolling_indicators(
    g5_mr02_common_panel(mr02_bars(), contract),
    contract
  )
  diagnostics <- g5_mr02_statistical_diagnostics(indicators, contract)
  convergence <- g5_mr02_forward_convergence(indicators, contract)
  testthat::expect_equal(nrow(diagnostics), 1L)
  testthat::expect_true(is.finite(diagnostics$static_residual_adf_t))
  testthat::expect_true(is.finite(diagnostics$variance_ratio_5))
  testthat::expect_true(all(c(
    "z_score", "forward_5_session_spread_return"
  ) %in% names(convergence)))
})

testthat::test_that("future rows cannot change TRAIN indicators or states", {
  contract <- g5_mr02_contract()
  bars <- mr02_bars(n = 1600L)
  train_bars <- bars[bars$session_date <= contract$train_end, , drop = FALSE]
  full_indicators <- g5_mr02_signal_states(
    g5_mr02_rolling_indicators(g5_mr02_common_panel(bars, contract), contract),
    contract
  )
  train_indicators <- g5_mr02_signal_states(
    g5_mr02_rolling_indicators(g5_mr02_common_panel(train_bars, contract), contract),
    contract
  )
  compare <- full_indicators[
    full_indicators$session_date <= contract$train_end,
    c("session_date", "beta", "spread", "z_score", "target_state"),
    drop = FALSE
  ]
  expected <- train_indicators[, names(compare), drop = FALSE]
  testthat::expect_equal(compare, expected, tolerance = 1e-12)
})

testthat::test_that("invalid beta or z forces the next target flat", {
  indicators <- data.frame(
    z_score = c(-1.5, -0.5, -0.4),
    beta = c(1, NA, -1)
  )
  out <- g5_mr02_signal_states(indicators, g5_mr02_contract())
  testthat::expect_equal(out$target_state, c(1L, 0L, 0L))
  testthat::expect_equal(out$signal_action, c(
    "enter_long_spread", "invalid_exit", "invalid_flat"
  ))
})

testthat::test_that("source contains no implicit current-date call", {
  path <- testthat::test_path("..", "..", "R", "gen5_lit_mr_02_1_bollinger_poc.R")
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
