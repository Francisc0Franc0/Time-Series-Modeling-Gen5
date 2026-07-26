test_that("option requests require explicit bounded timestamps", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "alpaca_options_provider.R"))

  contracts <- g5_alpaca_option_contracts_request(
    c("spy", "QQQ"),
    "2026-06-19",
    "2026-07-17",
    "2026-07-26 17:30:00"
  )
  expect_identical(contracts$underlying_symbols, "SPY,QQQ")
  expect_identical(contracts$status, "inactive")

  expect_silent(g5_alpaca_option_contracts_request(
    "SPY", "2026-08-21", "2026-08-21", "2026-07-26 17:30:00",
    status = "active"
  ))

  bars <- g5_alpaca_option_bars_request(
    c("SPY260619C00500000", "SPY260619P00500000"),
    "2026-06-18T19:30:00Z",
    "2026-06-18T20:00:00Z",
    "2026-07-26 17:30:00",
    feed = "opra"
  )
  expect_identical(bars$timeframe, "15Min")
  expect_identical(bars$feed, "opra")

  default_bars <- g5_alpaca_option_bars_request(
    "SPY260619C00500000",
    "2026-06-18T19:30:00Z",
    "2026-06-18T20:00:00Z",
    "2026-07-26 17:30:00"
  )
  expect_identical(default_bars$feed, "account_default")

  expect_error(
    g5_alpaca_option_bars_request(
      "SPY260619C00500000",
      "2026-07-27T19:30:00Z",
      "2026-07-27T20:00:00Z",
      "2026-07-26 17:30:00"
    ),
    "after as_of_timestamp"
  )
})

test_that("contract mapper excludes mutable historical fields", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "alpaca_options_provider.R"))

  request <- g5_alpaca_option_contracts_request(
    "SPY", "2026-06-19", "2026-06-19", "2026-07-26 17:30:00"
  )
  payload <- list(option_contracts = list(list(
    symbol = "SPY260619C00500000",
    underlying_symbol = "SPY",
    expiration_date = "2026-06-19",
    strike_price = "500",
    type = "call",
    style = "american",
    size = "100",
    status = "inactive",
    open_interest = "12345",
    open_interest_date = "2026-06-18",
    close_price = "10.00"
  )))
  mapped <- g5_alpaca_map_option_contracts_payload(
    payload, request, "2026-07-26 17:30:00"
  )
  expect_equal(nrow(mapped), 1L)
  expect_identical(mapped$option_symbol, "SPY260619C00500000")
  expect_equal(mapped$strike_price, 500)
  expect_false(any(c("open_interest", "open_interest_date", "close_price") %in% names(mapped)))
})

test_that("option bar mapper preserves feed and VWAP provenance", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "alpaca_options_provider.R"))

  request <- g5_alpaca_option_bars_request(
    "SPY260619C00500000",
    "2026-06-18T19:30:00Z",
    "2026-06-18T20:00:00Z",
    "2026-07-26 17:30:00",
    feed = "indicative"
  )
  payload <- list(bars = list(
    SPY260619C00500000 = list(list(
      t = "2026-06-18T19:45:00Z",
      o = 10.0, h = 10.5, l = 9.8, c = 10.2,
      v = 50, n = 17, vw = 10.15
    ))
  ))
  mapped <- g5_alpaca_map_option_bars_payload(
    payload, request, "2026-07-26 17:30:00"
  )
  expect_equal(nrow(mapped), 1L)
  expect_identical(mapped$feed, "indicative")
  expect_equal(mapped$vwap, 10.15)
  expect_identical(mapped$bar_timestamp, "2026-06-18T19:45:00Z")
})
