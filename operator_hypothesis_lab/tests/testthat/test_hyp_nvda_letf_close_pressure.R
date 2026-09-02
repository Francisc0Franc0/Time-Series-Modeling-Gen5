source(testthat::test_path("..", "..", "R", "hyp_nvda_letf_close_pressure.R"))

nlcp_fixture <- function() {
  dates <- as.Date(c(
    "2023-01-03", "2023-01-04", "2023-01-05", "2023-01-06", "2023-01-09"
  ))
  slots <- format(seq(
    as.POSIXct("2000-01-03 09:30:00", tz = "America/New_York"),
    as.POSIXct("2000-01-03 15:55:00", tz = "America/New_York"), by = "5 min"
  ), "%H:%M:%S")
  rows <- list()
  z <- 1L
  for (sym in c("NVDA", "NVDL")) {
    leverage <- if (sym == "NVDL") 1.5 else 1
    for (i in seq_along(dates)) {
      path <- 100 * exp(leverage * (0.002 * (i - 1L) + seq_along(slots) / 10000))
      rows[[z]] <- data.frame(
        symbol = sym,
        timestamp_utc = as.POSIXct(paste(dates[[i]], slots), tz = "America/New_York"),
        session_date = dates[[i]], bar_time_et = slots, bar_slot = seq_along(slots),
        open = path, high = path * 1.001, low = path * 0.999,
        close = path * exp(leverage * 0.00005), volume = 1000,
        provider = "alpaca", feed = "sip", timeframe = "5Min", adjustment = "all",
        as_of_timestamp = "2026-08-31 17:30:00 America/New_York",
        stringsAsFactors = FALSE
      )
      z <- z + 1L
    }
  }
  do.call(rbind, rows)
}

testthat::test_that("clock panel uses completed anchors and exactly three controls", {
  panel <- nlcp_build_clock_panel(nlcp_fixture())
  testthat::expect_equal(nrow(panel), 12L)
  testthat::expect_equal(unique(panel$clock), c("12:00", "14:00", "15:30"))
  testthat::expect_equal(range(panel$session_date), as.Date(c("2023-01-04", "2023-01-09")))
  testthat::expect_true(all(abs(panel$tracking_residual_to_anchor) < 1e-12))
  testthat::expect_true(all(abs(panel$tracking_residual_future_change) < 1e-12))
})

testthat::test_that("missing an exact NVDL anchor excludes only that clock", {
  bars <- nlcp_fixture()
  remove <- bars$symbol == "NVDL" & bars$session_date == as.Date("2023-01-04") &
    bars$bar_time_et == "15:25:00"
  panel <- nlcp_build_clock_panel(bars[!remove, , drop = FALSE])
  testthat::expect_equal(nrow(panel), 11L)
  testthat::expect_false(any(panel$session_date == as.Date("2023-01-04") & panel$clock == "15:30"))
})

testthat::test_that("contract rejects 2024 bars and source drift", {
  bars <- nlcp_fixture()
  wrong <- bars
  wrong$timeframe <- "30Min"
  testthat::expect_error(nlcp_validate_bars(wrong), "timeframe")
  future <- bars
  future$session_date <- as.Date("2024-01-02")
  testthat::expect_error(nlcp_validate_bars(future), "2024")
})

testthat::test_that("summaries expose clock-specific continuation and residual correction", {
  panel <- nlcp_build_clock_panel(nlcp_fixture())
  # Give the tiny deterministic fixture enough variation for finite regressions.
  panel$nvda_daily_to_anchor <- ave(
    seq_len(nrow(panel)), panel$clock, FUN = function(x) seq_along(x) / 1000
  )
  panel$nvda_local_60m <- panel$nvda_daily_to_anchor / 2
  panel$nvda_future_30m <- panel$nvda_daily_to_anchor * 0.2 + seq_len(nrow(panel)) / 100000
  panel$tracking_residual_to_anchor <- seq_len(nrow(panel)) / 10000
  panel$tracking_residual_future_change <- -0.5 * panel$tracking_residual_to_anchor
  clock <- nlcp_clock_summary(panel)
  residual <- nlcp_tracking_summary(panel)
  testthat::expect_equal(clock$clock, c("12:00", "14:00", "15:30"))
  testthat::expect_true(all(is.finite(clock$daily_move_pearson)))
  testthat::expect_equal(residual$residual_slope, rep(-0.5, 3), tolerance = 1e-10)
})
