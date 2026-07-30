source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_06_1_buy_on_gap_poc.R"
))

mr06_sessions <- function(n = 600L) {
  dates <- seq(as.Date("2018-08-01"), by = "day", length.out = n * 2L)
  head(dates[!as.POSIXlt(dates)$wday %in% c(0L, 6L)], n)
}

mr06_synthetic_daily <- function() {
  contract <- g5_mr06_contract()
  symbols <- g5_mr06_all_symbols(contract)
  dates <- mr06_sessions()
  do.call(rbind, lapply(seq_along(symbols), function(j) {
    set.seed(61000L + j)
    close <- 40 + j / 10 + cumsum(stats::rnorm(length(dates), 0.03, 0.25))
    low <- close * 0.995
    open <- close * (1 + stats::rnorm(length(dates), 0, 0.002))
    shock <- seq(120L, length(dates), by = 17L)
    open[shock] <- low[pmax(1L, shock - 1L)] * 0.96
    close[shock] <- open[shock] * 1.02
    data.frame(
      symbol = symbols[[j]],
      session_date = dates,
      open = open,
      low = pmin(low, open * 0.999),
      close = close,
      stringsAsFactors = FALSE
    )
  }))
}

mr06_synthetic_entries <- function(daily, contract) {
  signals <- g5_mr06_build_signals(daily, contract)
  manifest <- g5_mr06_entry_manifest(signals, contract)
  close_map <- daily[c("symbol", "session_date", "close")]
  x <- merge(manifest, close_map, by = c("symbol", "session_date"), all.x = TRUE)
  data.frame(
    symbol = x$symbol,
    session_date = x$session_date,
    entry_timestamp_et = paste(x$session_date, contract$entry_time_et),
    entry_open = x$close / 1.01,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("buy-on-gap contract freezes causal timing and atlas", {
  contract <- g5_mr06_contract()
  testthat::expect_equal(contract$signal_time_et, "09:31:00")
  testthat::expect_equal(contract$entry_time_et, "09:32:00")
  testthat::expect_equal(nrow(contract$registry), 10L)
  testthat::expect_equal(contract$top_n, 10L)
  changed <- contract
  changed$entry_time_et <- "09:31:00"
  testthat::expect_error(
    g5_mr06_validate_contract(changed),
    "Frozen contract changed"
  )
})

testthat::test_that("features use prior low, lagged MA, and lagged volatility", {
  contract <- g5_mr06_contract()
  rows <- data.frame(
    symbol = "TEST",
    session_date = mr06_sessions(130L),
    open = 100,
    low = seq(95, 107.9, length.out = 130L),
    close = seq(100, 112.9, length.out = 130L),
    stringsAsFactors = FALSE
  )
  features <- g5_mr06_symbol_features(rows, contract)
  i <- 100L
  expected_sd <- stats::sd(
    rows$close[(i - 90L):(i - 1L)] /
      rows$close[(i - 91L):(i - 2L)] - 1
  )
  testthat::expect_equal(features$prior_low[[i]], rows$low[[i - 1L]])
  testthat::expect_equal(
    features$ma20_lagged[[i]],
    mean(rows$close[(i - 20L):(i - 1L)])
  )
  testthat::expect_equal(features$sigma90_lagged[[i]], expected_sd)
})

testthat::test_that("entry manifest is fixed before outcome and after signal", {
  contract <- g5_mr06_contract()
  daily <- mr06_synthetic_daily()
  entries <- mr06_synthetic_entries(daily, contract)
  result <- g5_mr06_run_train(daily, entries, contract)
  testthat::expect_true(nrow(result$entry_manifest) > 0L)
  testthat::expect_true(all(vapply(
    result$results,
    function(x) all(x$integrity$status == "PASS"),
    logical(1)
  )))
  event_rows <- do.call(rbind, lapply(result$results, `[[`, "events"))
  testthat::expect_true(all(
    substr(event_rows$entry_timestamp_et, 12L, 19L) >
      contract$signal_time_et
  ))
})

testthat::test_that("unused top-ten sleeves remain cash", {
  contract <- g5_mr06_contract()
  events <- data.frame(
    session_date = rep(as.Date("2020-03-02"), 2L),
    entry_available = TRUE,
    gross_return = c(0.01, 0.02),
    primary_net_return = c(0.009, 0.019),
    stress_net_return = c(0.008, 0.018),
    source_open_close_return = c(0.012, 0.022)
  )
  portfolio <- g5_mr06_daily_portfolio(events, contract)
  testthat::expect_equal(portfolio$invested_fraction, 0.2)
  testthat::expect_equal(portfolio$gross_return, 0.003)
  testthat::expect_equal(portfolio$primary_net_return, 0.0028)
})

testthat::test_that("future daily and minute rows fail explicit boundary", {
  contract <- g5_mr06_contract()
  daily <- mr06_synthetic_daily()
  daily$session_date[[1L]] <- as.Date("2024-01-02")
  testthat::expect_error(
    g5_mr06_run_train(daily, data.frame(), contract),
    "explicit query boundary"
  )
})

testthat::test_that("buy-on-gap module contains no implicit current date", {
  code <- paste(readLines(testthat::test_path(
    "..", "..", "R", "gen5_lit_mr_06_1_buy_on_gap_poc.R"
  )), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
