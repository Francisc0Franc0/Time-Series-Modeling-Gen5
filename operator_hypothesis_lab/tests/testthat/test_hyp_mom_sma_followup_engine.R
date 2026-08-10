library(testthat)

repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_sma_followup_engine.R"))

fixture_bars <- function(n = 360L, symbol = "TEST", start = as.Date("2019-01-01")) {
  close <- c(seq(100, 80, length.out = 250), seq(81, 140, length.out = n - 250L))
  data.frame(
    symbol = symbol, session_date = start + seq_len(n) - 1L,
    open = close, high = close * 1.01, low = close * .99, close = close,
    volume = 1000, stringsAsFactors = FALSE
  )
}

test_that("contract and evidence windows are frozen", {
  contract <- hmsf_validate_contract()
  expect_equal(hmsf_window("ATTRIBUTION"), c(as.Date("2021-01-04"), as.Date("2023-12-29")))
  expect_equal(contract$confirmation_end, as.Date("2025-12-31"))
  expect_error(hmsf_window("UNKNOWN"), "Unknown evidence stage")
})

test_that("validation rejects duplicates, invalid values, and sealed observations", {
  bars <- fixture_bars()
  expect_error(hmsf_validate_bars(rbind(bars, bars[1, ]), max(bars$session_date)), "duplicate")
  bad <- bars; bad$open[[1L]] <- 0
  expect_error(hmsf_validate_bars(bad, max(bad$session_date)), "invalid")
  sealed <- bars; sealed$session_date[[nrow(sealed)]] <- as.Date("2026-01-02")
  expect_error(hmsf_validate_bars(sealed, as.Date("2026-01-02")), "Sealed")
})

test_that("state uses completed closes and builds both averages causally", {
  bars <- fixture_bars()
  state <- hmsf_state(bars, max(bars$session_date))
  expect_true(all(is.na(state$sma200[1:199])))
  expect_equal(state$sma200[[200]], mean(bars$close[1:200]))
  expect_equal(state$sma50[[50]], mean(bars$close[1:50]))
  expect_true(any(state$cross200_up))
})

test_that("re-entry repair can re-enter on SMA50 reclaim without a new SMA200 cross", {
  n <- 430L
  close <- c(rep(100, 230), seq(100, 140, length.out = 60), seq(140, 118, length.out = 45),
             seq(118, 145, length.out = 45), rep(145, 50))
  bars <- data.frame(symbol = "TEST", session_date = as.Date("2019-01-01") + seq_len(n) - 1L,
                     open = close, high = close * 1.01, low = close * .99, close = close, volume = 1000)
  start <- bars$session_date[[221L]]; end <- max(bars$session_date)
  repaired <- hmsf_replay(bars, "REENTRY_REPAIR_023", start, end, 5)
  composite <- hmsf_replay(bars, "COMPOSITE_022", start, end, 5)
  expect_true(any(repaired$path$signal_type == "REENTRY_SMA50_RECLAIM"))
  expect_gt(nrow(repaired$trades), nrow(composite$trades))
})

test_that("pullback reclaim requires rising SMA200 permission", {
  bars <- fixture_bars(500L)
  start <- bars$session_date[[221L]]; end <- max(bars$session_date)
  replay <- hmsf_replay(bars, "PULLBACK_RECLAIM_031", start, end, 5)
  entries <- replay$path$signal_type == "ENTRY_SMA50_RECLAIM_IN_RISING_SMA200_REGIME"
  if (any(entries)) {
    state <- hmsf_state(bars, end)
    signal_dates <- replay$path$signal_date[entries]
    expect_true(all(state$permission031[match(signal_dates, state$session_date)]))
  } else succeed()
})

test_that("costs reduce strategy and trade returns", {
  bars <- fixture_bars(500L)
  start <- bars$session_date[[221L]]; end <- max(bars$session_date)
  gross <- hmsf_replay(bars, "FRESH_021", start, end, 0)
  net <- hmsf_replay(bars, "FRESH_021", start, end, 10)
  expect_lte(tail(net$path$strategy_wealth_open, 1L), tail(gross$path$strategy_wealth_open, 1L))
  if (nrow(net$trades)) expect_true(all(net$trades$net_trade_return <= net$trades$gross_trade_return))
})

test_that("event study uses next-open horizons and labels non-overlap", {
  asset <- fixture_bars(500L, "TEST")
  spy <- fixture_bars(500L, "SPY"); spy$close <- spy$open <- seq(100, 130, length.out = 500L)
  spy$high <- spy$close * 1.01; spy$low <- spy$close * .99
  sector <- spy; sector$symbol <- "XLK"
  start <- asset$session_date[[221L]]; end <- max(asset$session_date)
  events <- hmsf_event_study(asset, spy, sector, start, end, "XLK")
  expect_true(all(events$horizon %in% c(5L, 20L, 60L)))
  expect_true(all(events$entry_date > events$signal_date))
  expect_true(all(events$exit_date > events$entry_date))
  expect_true(is.logical(events$nonoverlap))
})
