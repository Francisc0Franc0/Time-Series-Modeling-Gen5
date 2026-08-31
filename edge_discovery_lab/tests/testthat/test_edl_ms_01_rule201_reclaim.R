source(file.path("..", "..", "R", "edl_ms_01_rule201_reclaim.R"))

edl_ms01_test_bars <- function(symbol = "TSLA", n = 60L) {
  dates <- seq.Date(as.Date("2020-01-02"), by = "day", length.out = 100L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- 100 + seq_len(n) * 0.2
  data.frame(
    symbol = symbol,
    session_date = dates,
    open = close - 0.1,
    high = close + 1,
    low = close - 1,
    close = close,
    volume = 1000 + seq_len(n),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("the learning-first contract is frozen", {
  contract <- edl_ms01_validate_contract()
  testthat::expect_equal(contract$threshold, -0.10)
  testthat::expect_equal(contract$discovery_band, c(-0.12, -0.08))
  testthat::expect_equal(contract$forward_sessions, c(1L, 3L, 5L))
  testthat::expect_equal(length(contract$symbols), 10L)
  path_contract <- edl_ms01_validate_forward_path_contract()
  testthat::expect_equal(path_contract$horizons, 0:10)
  testthat::expect_equal(length(path_contract$focal_categories), 4L)
})

testthat::test_that("the proxy trigger and reclaim geometry are explicit", {
  bars <- edl_ms01_test_bars()
  bars$low[[30L]] <- bars$close[[29L]] * 0.895
  bars$high[[30L]] <- bars$close[[29L]] * 1.01
  bars$close[[30L]] <- bars$high[[30L]] - 0.01
  ledger <- edl_ms01_build_symbol_ledger(bars)
  testthat::expect_true(ledger$rule201_proxy_trigger[[30L]])
  testthat::expect_true(ledger$inside_discovery_band[[30L]])
  testthat::expect_equal(ledger$reclaim_group[[30L]], "STRONG_RECLAIM")
})

testthat::test_that("abnormal dollar volume uses strictly prior observations", {
  bars <- edl_ms01_test_bars()
  ledger <- edl_ms01_build_symbol_ledger(bars)
  expected <- ledger$dollar_volume[[21L]] /
    stats::median(ledger$dollar_volume[1:20])
  testthat::expect_true(all(is.na(ledger$abnormal_dollar_volume[1:20])))
  testthat::expect_equal(ledger$abnormal_dollar_volume[[21L]], expected)
})

testthat::test_that("forward outcomes start at the next open", {
  bars <- edl_ms01_test_bars()
  ledger <- edl_ms01_build_symbol_ledger(bars)
  testthat::expect_equal(ledger$entry_session[[10L]], bars$session_date[[11L]])
  testthat::expect_equal(
    ledger$forward_1_open_log_return[[10L]],
    log(bars$open[[12L]] / bars$open[[11L]])
  )
  testthat::expect_equal(
    ledger$forward_5_open_log_return[[10L]],
    log(bars$open[[16L]] / bars$open[[11L]])
  )
})

testthat::test_that("event tapes are deterministic and not outcome-selected", {
  categories <- c(
    "TRIGGERED_PROXY__STRONG_RECLAIM",
    "TRIGGERED_PROXY__WEAK_CLOSE",
    "NEAR_MISS__STRONG_RECLAIM",
    "NEAR_MISS__WEAK_CLOSE"
  )
  events <- data.frame(
    symbol = rep(c("B", "A"), each = 4L),
    session_date = as.Date(c(
      "2020-02-01", "2020-02-02", "2020-02-03", "2020-02-04",
      "2020-01-01", "2020-01-02", "2020-01-03", "2020-01-04"
    )),
    event_category = rep(categories, 2L),
    forward_5_open_log_return = c(1, 1, 1, 1, -1, -1, -1, -1),
    stringsAsFactors = FALSE
  )
  selected <- edl_ms01_select_event_tapes(events)
  testthat::expect_equal(selected$symbol, rep("A", 4L))
  testthat::expect_equal(selected$event_category, categories)
})

testthat::test_that("forward paths remain anchored to the next open", {
  bars <- edl_ms01_test_bars()
  ledger <- edl_ms01_add_forward_paths(edl_ms01_build_symbol_ledger(bars))
  testthat::expect_equal(ledger$path_0_open_log_return[[10L]], 0)
  testthat::expect_equal(
    ledger$path_1_open_log_return[[10L]],
    log(bars$open[[12L]] / bars$open[[11L]])
  )
  testthat::expect_equal(
    ledger$path_10_open_log_return[[10L]],
    log(bars$open[[21L]] / bars$open[[11L]])
  )
})

testthat::test_that("path anatomy keeps only the four frozen focal categories", {
  bars <- edl_ms01_test_bars(n = 40L)
  ledger <- edl_ms01_add_forward_paths(edl_ms01_build_symbol_ledger(bars))
  ledger$event_category[10:14] <- c(
    "TRIGGERED_PROXY__STRONG_RECLAIM",
    "TRIGGERED_PROXY__WEAK_CLOSE",
    "NEAR_MISS__STRONG_RECLAIM",
    "NEAR_MISS__WEAK_CLOSE",
    "TRIGGERED_PROXY__MIDDLE_CLOSE"
  )
  paths <- edl_ms01_forward_path_long(ledger[10:14, ])
  testthat::expect_equal(length(unique(paths$event_category)), 4L)
  testthat::expect_false(any(paths$event_category == "TRIGGERED_PROXY__MIDDLE_CLOSE"))
  summary <- edl_ms01_summarize_forward_paths(paths)
  testthat::expect_true(all(c(
    "n", "mean_open_log_return", "median_open_log_return",
    "q25_open_log_return", "q75_open_log_return"
  ) %in% names(summary)))
})
