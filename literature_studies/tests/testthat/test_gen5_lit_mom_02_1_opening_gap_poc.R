module_path <- file.path(
  "..", "..", "R", "gen5_lit_mom_02_1_opening_gap_poc.R"
)
source(module_path)

registry_path <- file.path(
  "..", "..", "registries",
  "gen5_lit_mom_02_1_opening_gap_atlas_registry.csv"
)
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
registry$poc_anchor <- as.logical(registry$poc_anchor)
contract <- g5_mom02_contract(registry)

testthat::test_that("opening-gap contract and atlas are frozen", {
  testthat::expect_silent(g5_mom02_validate_contract(contract))
  testthat::expect_equal(nrow(contract$registry), 92L)
  testthat::expect_equal(sum(contract$registry$poc_anchor), 8L)
  testthat::expect_equal(contract$entry_sigma_multiple, 0.1)
  testthat::expect_equal(contract$volatility_sessions, 90L)
  testthat::expect_equal(contract$signal_time_et, "09:31:00")
  testthat::expect_equal(contract$entry_time_et, "09:32:00")
  testthat::expect_equal(contract$confirmation_start, as.Date("2024-01-02"))
})

testthat::test_that("lagged volatility excludes the current close", {
  close <- c(100, cumprod(1 + seq(0.001, 0.100, length.out = 100)) * 100)
  got <- g5_mom02_rolling_sd_lagged_returns(close, 90L)
  returns <- close / g5_mom02_lag(close) - 1
  testthat::expect_equal(got[[92L]], stats::sd(returns[2:91]))
  changed <- close
  changed[[92L]] <- changed[[92L]] * 10
  testthat::expect_equal(
    g5_mom02_rolling_sd_lagged_returns(changed, 90L)[[92L]],
    got[[92L]]
  )
})

testthat::test_that("gap-up and gap-down signals follow Chan thresholds", {
  n <- 94L
  rows <- data.frame(
    symbol = "SPY",
    session_date = as.Date("2016-08-01") + seq_len(n) - 1L,
    open = rep(100, n), high = rep(101, n), low = rep(99, n),
    close = 100 * cumprod(1 + rep(c(0.01, -0.009), length.out = n)),
    stringsAsFactors = FALSE
  )
  base <- g5_mom02_symbol_features(rows, contract)
  rows$open[[93L]] <- base$upper_threshold[[93L]] * 1.001
  rows$open[[94L]] <- base$lower_threshold[[94L]] * 0.999
  got <- g5_mom02_symbol_features(rows, contract)
  testthat::expect_true(got$long_signal[[93L]])
  testthat::expect_equal(got$position[[93L]], 1L)
  testthat::expect_true(got$short_signal[[94L]])
  testthat::expect_equal(got$position[[94L]], -1L)
})

testthat::test_that("printed source code has the opposite PnL sign", {
  rows <- data.frame(
    symbol = "SPY", session_date = as.Date("2020-01-02") + 0:1,
    open = c(100, 102), high = c(101, 103), low = c(99, 101),
    close = c(100, 105), stringsAsFactors = FALSE
  )
  rows$position <- c(0L, 1L)
  rows$source_narrative_return <- rows$position * (rows$close / rows$open - 1)
  rows$literal_printed_code_return <- rows$position *
    (rows$open - rows$close) / rows$open
  testthat::expect_equal(
    rows$literal_printed_code_return,
    -rows$source_narrative_return
  )
})

testthat::test_that("causal event return uses 09:32 entry and signal direction", {
  events <- data.frame(
    symbol = c("SPY", "TLT"),
    session_date = as.Date(c("2020-01-02", "2020-01-03")),
    position = c(1L, -1L),
    close = c(105, 95), open = c(102, 98),
    source_narrative_return = c(105 / 102 - 1, -(95 / 98 - 1)),
    literal_printed_code_return = c(-(105 / 102 - 1), 95 / 98 - 1),
    stringsAsFactors = FALSE
  )
  entries <- data.frame(
    symbol = c("SPY", "TLT"),
    session_date = events$session_date,
    entry_timestamp_et = paste(events$session_date, "09:32:00"),
    entry_open = c(103, 97), stringsAsFactors = FALSE
  )
  got <- g5_mom02_join_entries(events, entries, contract)
  testthat::expect_equal(got$gross_return, c(105 / 103 - 1, -(95 / 97 - 1)))
  testthat::expect_true(all(got$direction_correct))
  testthat::expect_equal(
    got$primary_net_return,
    got$gross_return - contract$primary_round_trip_cost_bps / 10000
  )
})

testthat::test_that("DEVELOPMENT cannot exceed its frozen boundary", {
  entries <- data.frame(
    symbol = "SPY", session_date = as.Date("2024-01-02"),
    entry_timestamp_et = "2024-01-02 09:32:00", entry_open = 100
  )
  testthat::expect_error(
    g5_mom02_validate_entries(entries, contract, contract$development_end),
    "explicit query boundary"
  )
})

testthat::test_that("module contains no implicit current date", {
  text <- paste(readLines(module_path, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("Sys\\.Date\\s*\\(", text))
})
