source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "portfolio_strategy_poc.R"))

g5_test_portfolio_equity <- function(symbol, closes) {
  data.frame(
    symbol = symbol,
    session_date = as.Date("2026-01-01") + seq_along(closes) - 1L,
    close = closes,
    strategy_equity = cumprod(c(1, closes[-1L] / closes[-length(closes)])),
    stringsAsFactors = FALSE
  )
}

test_that("portfolio POC sizes entries to dynamic equal slots and caps by cash", {
  symbols <- c("AAA", "BBB")
  equity_by_symbol <- list(
    AAA = g5_test_portfolio_equity("AAA", c(10, 11, 12, 13)),
    BBB = g5_test_portfolio_equity("BBB", c(20, 18, 19, 21))
  )
  trades_by_symbol <- list(
    AAA = data.frame(
      trade_id = "AAA_1",
      symbol = "AAA",
      entry_execution_date = as.Date("2026-01-01"),
      entry_execution_price = 10,
      exit_execution_date = as.Date("2026-01-03"),
      exit_execution_price = 12,
      trade_status = "closed",
      stringsAsFactors = FALSE
    ),
    BBB = data.frame(
      trade_id = "BBB_1",
      symbol = "BBB",
      entry_execution_date = as.Date("2026-01-02"),
      entry_execution_price = 18,
      exit_execution_date = as.Date(NA),
      exit_execution_price = NA_real_,
      trade_status = "open",
      stringsAsFactors = FALSE
    )
  )

  accounting <- g5_portfolio_poc_build_accounting(
    trades_by_symbol = trades_by_symbol,
    equity_by_symbol = equity_by_symbol,
    active_symbols = symbols,
    initial_capital = 100,
    slot_count = 2
  )

  entries <- accounting$events[accounting$events$event_type == "entry", , drop = FALSE]
  expect_equal(entries$event_status, c("filled", "filled_cash_capped"))
  expect_equal(entries$target_notional[[1L]], 50)
  expect_equal(entries$actual_notional[[1L]], 50)
  expect_equal(entries$portfolio_equity_reference[[1L]], 100)
  expect_equal(round(entries$target_notional[[2L]], 6), 52.5)
  expect_equal(entries$actual_notional[[2L]], 50)
  expect_equal(entries$portfolio_equity_reference[[2L]], 105)

  exits <- accounting$events[accounting$events$event_type == "exit", , drop = FALSE]
  expect_equal(nrow(exits), 1L)
  expect_equal(exits$actual_notional[[1L]], 60)

  final <- tail(accounting$equity, 1L)
  expect_equal(round(final$portfolio_equity[[1L]], 6), 118.333333)
  expect_equal(accounting$symbol_summary$cash_capped_entries[accounting$symbol_summary$symbol == "BBB"], 1L)
})

test_that("portfolio POC builds SPY and active-set buy-and-hold baselines", {
  dates <- as.Date("2026-01-01") + 0:2
  bars <- rbind(
    data.frame(symbol = "SPY", session_date = dates, close = c(100, 110, 120), stringsAsFactors = FALSE),
    data.frame(symbol = "AAA", session_date = dates, close = c(10, 15, 20), stringsAsFactors = FALSE),
    data.frame(symbol = "BBB", session_date = dates, close = c(20, 10, 20), stringsAsFactors = FALSE)
  )

  baselines <- g5_portfolio_poc_build_baselines(
    bars = bars,
    dates = dates,
    active_symbols = c("AAA", "BBB"),
    initial_capital = 100,
    baseline_symbol = "SPY"
  )

  expect_equal(baselines$spy_buy_hold_equity, c(100, 110, 120))
  expect_equal(baselines$active_equal_buy_hold_equity, c(100, 100, 150))
  expect_equal(round(baselines$spy_buy_hold_return[[3L]], 6), 0.2)
  expect_equal(round(baselines$active_equal_buy_hold_return[[3L]], 6), 0.5)

  metrics <- g5_portfolio_poc_baseline_metrics(baselines, initial_capital = 100)
  expect_equal(metrics$baseline_id, c("spy_buy_hold", "active_equal_buy_hold"))
  expect_equal(metrics$ending_equity, c(120, 150))
})

test_that("portfolio POC leverage increases target notional and allows margin-style cash", {
  symbols <- c("AAA", "BBB")
  equity_by_symbol <- list(
    AAA = g5_test_portfolio_equity("AAA", c(10, 11, 12)),
    BBB = g5_test_portfolio_equity("BBB", c(20, 21, 22))
  )
  trades_by_symbol <- list(
    AAA = data.frame(
      trade_id = "AAA_1",
      symbol = "AAA",
      entry_execution_date = as.Date("2026-01-01"),
      entry_execution_price = 10,
      exit_execution_date = as.Date(NA),
      exit_execution_price = NA_real_,
      trade_status = "open",
      stringsAsFactors = FALSE
    ),
    BBB = data.frame(
      trade_id = "BBB_1",
      symbol = "BBB",
      entry_execution_date = as.Date("2026-01-01"),
      entry_execution_price = 20,
      exit_execution_date = as.Date(NA),
      exit_execution_price = NA_real_,
      trade_status = "open",
      stringsAsFactors = FALSE
    )
  )

  accounting <- g5_portfolio_poc_build_accounting(
    trades_by_symbol = trades_by_symbol,
    equity_by_symbol = equity_by_symbol,
    active_symbols = symbols,
    initial_capital = 100,
    slot_count = 2,
    leverage = 1.8
  )

  entries <- accounting$events[accounting$events$event_type == "entry", , drop = FALSE]
  expect_equal(entries$event_status, c("filled", "filled"))
  expect_equal(entries$target_notional, c(90, 90))
  expect_equal(entries$actual_notional, c(90, 90))
  expect_equal(tail(accounting$equity$cash, 1L), -80)
  expect_equal(unique(accounting$equity$leverage), 1.8)
})

test_that("portfolio POC baselines include same-leverage passive comparators", {
  dates <- as.Date("2026-01-01") + 0:1
  bars <- rbind(
    data.frame(symbol = "SPY", session_date = dates, close = c(100, 110), stringsAsFactors = FALSE),
    data.frame(symbol = "AAA", session_date = dates, close = c(10, 12), stringsAsFactors = FALSE),
    data.frame(symbol = "BBB", session_date = dates, close = c(20, 20), stringsAsFactors = FALSE)
  )

  baselines <- g5_portfolio_poc_build_baselines(
    bars = bars,
    dates = dates,
    active_symbols = c("AAA", "BBB"),
    initial_capital = 100,
    baseline_symbol = "SPY",
    leverage = 1.8
  )

  expect_equal(baselines$active_equal_buy_hold_equity, c(100, 110))
  expect_equal(baselines$active_equal_buy_hold_levered_equity, c(100, 118))
  expect_equal(baselines$spy_buy_hold_levered_equity, c(100, 118))
  expect_equal(unique(baselines$leverage), 1.8)
})
