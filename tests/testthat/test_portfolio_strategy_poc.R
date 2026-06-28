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
