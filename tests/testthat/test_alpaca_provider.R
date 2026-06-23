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

test_that("Alpaca config accepts Gen4-style credential objects", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))

  old_key_exists <- exists("ALPACA_KEY", envir = globalenv(), inherits = FALSE)
  old_secret_exists <- exists("ALPACA_SECRET", envir = globalenv(), inherits = FALSE)
  old_key <- if (old_key_exists) get("ALPACA_KEY", envir = globalenv()) else NULL
  old_secret <- if (old_secret_exists) get("ALPACA_SECRET", envir = globalenv()) else NULL

  on.exit({
    if (old_key_exists) {
      assign("ALPACA_KEY", old_key, envir = globalenv())
    } else if (exists("ALPACA_KEY", envir = globalenv(), inherits = FALSE)) {
      rm("ALPACA_KEY", envir = globalenv())
    }
    if (old_secret_exists) {
      assign("ALPACA_SECRET", old_secret, envir = globalenv())
    } else if (exists("ALPACA_SECRET", envir = globalenv(), inherits = FALSE)) {
      rm("ALPACA_SECRET", envir = globalenv())
    }
  }, add = TRUE)

  assign("ALPACA_KEY", "object_key", envir = globalenv())
  assign("ALPACA_SECRET", "object_secret", envir = globalenv())

  cfg <- g5_alpaca_config_from_env()
  expect_true(cfg$has_credentials)
  expect_identical(cfg$key_id, "object_key")
  expect_identical(cfg$secret_key, "object_secret")
})
