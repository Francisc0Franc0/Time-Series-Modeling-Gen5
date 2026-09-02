source(testthat::test_path("..", "..", "R", "hyp_intraday_alpaca_5min.R"))

testthat::test_that("five-minute request freezes SIP adjusted scope", {
  request <- imom5_request(
    c("NVDL", "NVDA"), "2023-01-01", "2023-12-29",
    "2026-08-31 17:30:00 America/New_York"
  )
  testthat::expect_equal(request$symbol, c("NVDA", "NVDL"))
  testthat::expect_true(all(request$timeframe == "5Min"))
  testthat::expect_true(all(request$feed == "sip"))
  testthat::expect_true(all(request$adjustment == "all"))
  testthat::expect_error(
    imom5_request("NVDA", "2023-01-01", "2023-12-29", "x", feed = "iex"),
    "Frozen feed"
  )
})

testthat::test_that("mapper retains only the 78 regular-session slots", {
  request <- imom5_request(
    "NVDA", "2023-01-03", "2023-01-03",
    "2026-08-31 17:30:00 America/New_York"
  )
  parsed <- list(NVDA = list(
    list(t = "2023-01-03T14:30:00Z", o = 100, h = 101, l = 99, c = 100.5, v = 10, n = 2, vw = 100.2),
    list(t = "2023-01-03T21:00:00Z", o = 101, h = 102, l = 100, c = 101.5, v = 12, n = 2, vw = 101.2)
  ))
  bars <- imom5_map_bars(parsed, request)
  testthat::expect_equal(nrow(bars), 1L)
  testthat::expect_equal(bars$bar_time_et, "09:30:00")
  testthat::expect_equal(bars$timeframe, "5Min")
})

testthat::test_that("provider contains no implicit current date", {
  code <- paste(readLines(testthat::test_path("..", "..", "R", "hyp_intraday_alpaca_5min.R")), collapse = "\n")
  testthat::expect_false(grepl("Sys\\.Date\\s*\\(", code))
})
