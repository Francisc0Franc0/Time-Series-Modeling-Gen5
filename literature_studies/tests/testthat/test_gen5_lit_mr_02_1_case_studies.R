source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_02_1_bollinger_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_02_1_case_studies.R"
))

testthat::test_that("Yahoo reference URL has explicit inclusive dates", {
  url <- g5_mr02_yahoo_chart_url(
    "GLD", as.Date("2006-05-24"), as.Date("2012-04-09")
  )
  testthat::expect_match(url, "query1.finance.yahoo.com")
  testthat::expect_match(url, "interval=1d")
  testthat::expect_match(url, "includeAdjustedClose=true")
  testthat::expect_false(grepl("Sys.Date", url, fixed = TRUE))
})

testthat::test_that("Yahoo parser adjusts every OHLC field consistently", {
  timestamps <- as.numeric(as.POSIXct(
    c("2006-05-24 13:30:00", "2006-05-25 13:30:00"), tz = "UTC"
  ))
  payload <- list(chart = list(
    result = list(list(
      timestamp = as.list(timestamps),
      indicators = list(
        quote = list(list(
          open = list(10, 11),
          high = list(12, 13),
          low = list(9, 10),
          close = list(10, 12),
          volume = list(1000, 1200)
        )),
        adjclose = list(list(adjclose = list(5, 6)))
      )
    )),
    error = NULL
  ))
  bars <- g5_mr02_parse_yahoo_chart(
    payload, "USO", "2026-07-29 17:30:00 America/New_York"
  )
  testthat::expect_equal(bars$adjustment_factor, c(0.5, 0.5))
  testthat::expect_equal(bars$open, c(5, 5.5))
  testthat::expect_equal(bars$high, c(6, 6.5))
  testthat::expect_equal(bars$low, c(4.5, 5))
  testthat::expect_equal(bars$close, c(5, 6))
  testthat::expect_identical(
    unique(bars$provider), "yahoo_chart_reference_only"
  )
})

testthat::test_that("source-style replay uses lagged close positions", {
  indicators <- data.frame(
    session_date = as.Date("2020-01-01") + 0:2,
    close_x = c(100, 101, 102),
    close_y = c(50, 52, 51),
    beta = c(0.5, 0.5, 0.5),
    target_state = c(1L, -1L, 0L)
  )
  replay <- g5_mr02_source_close_replay(indicators)
  expected_first <- (-0.5 * (101 - 100) + (52 - 50)) /
    (0.5 * 100 + 50)
  expected_second <- (0.5 * (102 - 101) - (51 - 52)) /
    (0.5 * 101 + 52)
  testthat::expect_equal(
    replay$source_gross_return, c(expected_first, expected_second)
  )
})

testthat::test_that("reference contract preserves core LIT-MR-02.1 mechanics", {
  contract <- g5_mr02_reference_contract()
  testthat::expect_identical(contract$literature_id, "LIT-MR-02.1")
  testthat::expect_identical(contract$lookback_sessions, 20L)
  testthat::expect_equal(contract$entry_z, 1)
  testthat::expect_equal(contract$exit_z, 0)
  testthat::expect_identical(contract$symbol_x, "GLD")
  testthat::expect_identical(contract$symbol_y, "USO")
  testthat::expect_identical(contract$query_start, as.Date("2006-05-24"))
  testthat::expect_identical(contract$query_end, as.Date("2012-04-09"))
})
