source(testthat::test_path("..", "..", "R", "hyp_nvda_intraday_clock_descriptive.R"))

nic_fixture <- function(session_dates = as.Date(c("2023-01-03", "2023-01-04"))) {
  slots <- nic_slot_labels()
  rows <- lapply(seq_along(session_dates), function(i) {
    base <- 100 + 2 * (i - 1L)
    data.frame(
      symbol = "NVDA",
      timestamp_utc = as.POSIXct(paste(session_dates[[i]], slots$bar_time_et), tz = "America/New_York"),
      session_date = session_dates[[i]],
      bar_time_et = slots$bar_time_et,
      bar_slot = slots$clock_order,
      open = base + seq_len(13) / 10,
      high = base + seq_len(13) / 10 + 0.2,
      low = base + seq_len(13) / 10 - 0.2,
      close = base + seq_len(13) / 10 + 0.1,
      volume = 1000 + seq_len(13),
      feed = "sip", timeframe = "30Min", adjustment = "all",
      as_of_timestamp = "2026-08-31 17:30:00 America/New_York",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

testthat::test_that("clock-point construction places the overnight gap before 13 bars", {
  bars <- nic_fixture()
  points <- nic_build_clock_points(
    bars, as.Date("2023-01-04"), as.Date("2023-01-04")
  )
  testthat::expect_equal(nrow(points), 14L)
  testthat::expect_equal(sort(unique(points$clock_order)), 0:13)
  testthat::expect_equal(sum(points$observation_type == "OVERNIGHT_GAP"), 1L)
  gap <- points[points$observation_type == "OVERNIGHT_GAP", ]
  expected <- log(bars$open[bars$session_date == as.Date("2023-01-04")][[1L]] /
                    tail(bars$close[bars$session_date == as.Date("2023-01-03")], 1L))
  testthat::expect_equal(gap$log_return, expected)
  testthat::expect_equal(
    points$log_return[points$bar_slot == 1L & points$observation_type == "RTH_BAR"],
    log(102.2 / 102.1)
  )
})

testthat::test_that("a known unavailable session suppresses the contaminated following gap only", {
  bars <- nic_fixture(as.Date(c("2023-01-03", "2023-01-05")))
  points <- nic_build_clock_points(
    bars, as.Date("2023-01-05"), as.Date("2023-01-05"),
    unavailable_session_dates = as.Date("2023-01-04")
  )
  testthat::expect_equal(nrow(points), 13L)
  testthat::expect_false(any(points$observation_type == "OVERNIGHT_GAP"))
  testthat::expect_equal(sum(points$observation_type == "RTH_BAR"), 13L)
})

testthat::test_that("clock summary preserves all fourteen ordered bins", {
  bars <- nic_fixture()
  points <- nic_build_clock_points(
    bars, as.Date("2023-01-04"), as.Date("2023-01-04")
  )
  summary <- nic_clock_summary(points)
  testthat::expect_equal(summary$clock_order, 0:13)
  testthat::expect_true(all(summary$observations == 1L))
  testthat::expect_true(all(is.finite(summary$median_log_return)))
})

testthat::test_that("source contract rejects the wrong feed or duplicate timestamps", {
  bars <- nic_fixture()
  wrong_feed <- bars
  wrong_feed$feed <- "iex"
  testthat::expect_error(nic_validate_bars(wrong_feed), "frozen contract")
  duplicate <- rbind(bars, bars[1L, ])
  testthat::expect_error(nic_validate_bars(duplicate), "Duplicate")
})
