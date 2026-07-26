test_that("O0 selects same-strike same-expiry pairs nearest 30 DTE and spot", {
  source(test_path("..", "..", "R", "gen54_options_implied_move_poc.R"))
  contracts <- data.frame(
    option_symbol = c("C100", "P100", "C105", "P105", "C100L", "P100L"),
    underlying_symbol = "SPY",
    expiration_date = as.Date(c(
      "2026-08-21", "2026-08-21", "2026-08-21", "2026-08-21",
      "2026-08-28", "2026-08-28"
    )),
    strike_price = c(100, 100, 105, 105, 100, 100),
    option_type = c("call", "put", "call", "put", "call", "put"),
    stringsAsFactors = FALSE
  )
  underlying <- data.frame(
    symbol = "SPY",
    session_date = as.Date("2026-07-24"),
    selected_price = 103,
    stringsAsFactors = FALSE
  )
  selected <- g5_gen54_o0_select_pairs(
    contracts, underlying, as.Date("2026-07-24"), underlyings = "SPY"
  )
  expect_identical(selected$call_symbol, "C105")
  expect_identical(selected$put_symbol, "P105")
  expect_equal(selected$dte, 28L)
  expect_equal(selected$strike_price, 105)
})

test_that("O0 measure requires both legs at the same timestamp", {
  source(test_path("..", "..", "R", "gen54_options_implied_move_poc.R"))
  selections <- data.frame(
    session_date = as.Date("2026-07-24"),
    underlying_symbol = "SPY",
    underlying_price = 100,
    expiration_date = as.Date("2026-08-21"),
    dte = 28L,
    strike_price = 100,
    strike_distance_fraction = 0,
    call_symbol = "C100",
    put_symbol = "P100",
    selection_status = "SELECTED",
    stringsAsFactors = FALSE
  )
  bars <- data.frame(
    option_symbol = c("C100", "P100"),
    session_date = as.Date(c("2026-07-24", "2026-07-24")),
    selected_price = c(3, 2.5),
    bar_timestamp = c("2026-07-24T19:45:00Z", "2026-07-24T19:45:00Z"),
    feed = "indicative",
    stringsAsFactors = FALSE
  )
  measure <- g5_gen54_o0_construct_measure(selections, bars)
  expect_true(measure$matched_pair_valid)
  expect_equal(
    measure$normalized_implied_move_30d,
    0.055 * sqrt(30 / 28)
  )
  expect_identical(measure$construction_status, "VALID_MATCHED_STRADDLE")

  bars$bar_timestamp[[2L]] <- "2026-07-24T19:30:00Z"
  invalid <- g5_gen54_o0_construct_measure(selections, bars)
  expect_false(invalid$matched_pair_valid)
  expect_identical(invalid$construction_status, "MISMATCHED_LEG_TIMESTAMPS")
})

test_that("O0 coverage gate is per underlying", {
  source(test_path("..", "..", "R", "gen54_options_implied_move_poc.R"))
  measure <- data.frame(
    underlying_symbol = rep(c("SPY", "QQQ"), each = 10),
    matched_pair_valid = c(rep(TRUE, 10), rep(TRUE, 8), rep(FALSE, 2)),
    stringsAsFactors = FALSE
  )
  coverage <- g5_gen54_o0_coverage(measure)
  expect_identical(
    coverage$verdict[coverage$underlying_symbol == "SPY"],
    "PASS_O0_COVERAGE"
  )
  expect_identical(
    coverage$verdict[coverage$underlying_symbol == "QQQ"],
    "STOP_O0_COVERAGE"
  )
})
