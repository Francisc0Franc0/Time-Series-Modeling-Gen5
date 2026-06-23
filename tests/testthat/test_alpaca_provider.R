test_that("Alpaca adjusted daily request enforces explicit session bounds", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))

  expect_error(
    g5_alpaca_daily_adjusted_request(
      symbols = "SPY",
      start_date = as.Date("2026-06-20"),
      end_date = as.Date("2026-06-19"),
      as_of_timestamp = "2026-06-22 17:00:00",
      latest_completed_session = as.Date("2026-06-22")
    ),
    "start_date"
  )

  expect_error(
    g5_alpaca_daily_adjusted_request(
      symbols = "SPY",
      start_date = as.Date("2026-06-18"),
      end_date = as.Date("2026-06-23"),
      as_of_timestamp = "2026-06-22 17:00:00",
      latest_completed_session = as.Date("2026-06-22")
    ),
    "latest_completed_session"
  )
})

test_that("Alpaca provider payload maps to canonical adjusted daily bars", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))

  request <- g5_alpaca_daily_adjusted_request(
    symbols = c("SPY", "QQQ"),
    start_date = as.Date("2026-06-18"),
    end_date = as.Date("2026-06-19"),
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22")
  )
  payload <- list(
    SPY = list(
      list(t = "2026-06-18T04:00:00Z", o = 100, h = 101, l = 99, c = 100.5, v = 1000)
    ),
    QQQ = list(
      list(t = "2026-06-19T04:00:00Z", o = 200, h = 202, l = 199, c = 201, v = 1200)
    )
  )

  bars <- g5_alpaca_map_bars_to_canonical(payload, request)
  expect_identical(names(bars), g5_required_bar_columns())
  expect_equal(nrow(bars), 2L)
  expect_true(all(bars$adjusted))
  expect_true(all(bars$timeframe == "1D"))
  expect_true(all(bars$provider == "alpaca"))
})
