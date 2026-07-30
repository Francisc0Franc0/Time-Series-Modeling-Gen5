source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_06_1_buy_on_gap_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_06_1_alpaca_intraday.R"
))

testthat::test_that("intraday helper resolves fixed ET clocks across DST", {
  testthat::expect_equal(
    g5_mr06_alpaca_et_to_utc(as.Date("2020-01-02"), "09:32:00"),
    "2020-01-02T14:32:00Z"
  )
  testthat::expect_equal(
    g5_mr06_alpaca_et_to_utc(as.Date("2020-07-02"), "09:32:00"),
    "2020-07-02T13:32:00Z"
  )
})

testthat::test_that("historical META sessions use same-issuer FB ticker", {
  old <- g5_mr06_alpaca_symbol_map(
    c("META", "AAPL"), as.Date("2020-01-02")
  )
  recent <- g5_mr06_alpaca_symbol_map("META", as.Date("2023-01-03"))
  testthat::expect_equal(
    old$provider_symbol[old$research_symbol == "META"], "FB"
  )
  testthat::expect_equal(recent$provider_symbol, "META")
})

testthat::test_that("intraday helper contains no implicit current date", {
  code <- paste(readLines(testthat::test_path(
    "..", "..", "R", "gen5_lit_mr_06_1_alpaca_intraday.R"
  )), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
