repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_09_1_robust_slope_fit_poc.R"))

hreg91_test_bars <- function() {
  dates <- seq(as.Date("2020-01-02"), by = "day", length.out = 34L)
  close <- c(rep(10, 14), 11, 12, 13, 12, 11, 10, 11, 12, 13, 14, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6)
  data.frame(symbol = "TEST", session_date = dates, timestamp_utc = as.POSIXct(dates, tz = "UTC"), open = close, high = close * 1.01, low = close * .99, close = close, volume = 1000)
}

hreg91_frame <- function() {
  x <- hreg12_cross_frame(hreg91_test_bars()); x$normalized_strength60 <- 2; x$path_quality60 <- .9; x$quality_percentile60 <- .8; x$quality_state60 <- "HIGH_QUALITY"; x$orderly_up_eligible <- TRUE; x$normalized_strength120 <- 1; x$path_quality120 <- .8; x
}

testthat::test_that("contract freezes the approved robust slope and fit lane", {
  x <- hreg91_contract()
  testthat::expect_equal(x$hypothesis_id, "HYP-REG-09.1")
  testthat::expect_equal(x$primary_window, 60L)
  testthat::expect_equal(x$durability_window, 120L)
  testthat::expect_equal(x$percentile_lookback, 252L)
  testthat::expect_equal(x$policies, c("UNFILTERED", "ENTRY_ORDERLY_UP_ONLY"))
  testthat::expect_equal(x$confirmation_start, as.Date("2024-01-02"))
})

testthat::test_that("Theil-Sen slope is exact for a line and robust to one outlier", {
  line <- 1 + .02 * seq_len(60)
  testthat::expect_equal(hreg91_theil_sen_slope(line), .02, tolerance = 1e-12)
  line[[30L]] <- line[[30L]] + 3
  testthat::expect_equal(hreg91_theil_sen_slope(line), .02, tolerance = 1e-12)
})

testthat::test_that("window metrics preserve direction and scale invariance", {
  up <- .002 * seq_len(60) + sin(seq_len(60)) * .0002; down <- -up
  a <- hreg91_window_metrics(up); b <- hreg91_window_metrics(down); c <- hreg91_window_metrics(4 * up)
  testthat::expect_gt(a[["normalized_strength"]], 0)
  testthat::expect_lt(b[["normalized_strength"]], 0)
  testthat::expect_gt(a[["path_quality"]], .99)
  testthat::expect_equal(abs(a[["normalized_strength"]]), abs(b[["normalized_strength"]]), tolerance = 1e-10)
  testthat::expect_equal(a[["normalized_strength"]], c[["normalized_strength"]], tolerance = 1e-10)
  testthat::expect_equal(a[["path_quality"]], c[["path_quality"]], tolerance = 1e-12)
})

testthat::test_that("rolling values begin only after the complete window", {
  close <- exp(cumsum(rep(.001, 140) + sin(seq_len(140)) * .0001))
  x <- hreg91_rolling_metrics(close, 60)
  testthat::expect_true(all(is.na(x$path_quality[1:59])))
  testthat::expect_true(all(is.finite(x$path_quality[60:140])))
})

testthat::test_that("causal percentile excludes the current observation", {
  x <- hreg91_rolling_percentile(1:10, 5)
  testthat::expect_true(all(is.na(x[1:5])))
  testthat::expect_equal(x[6:10], rep(1, 5))
})

testthat::test_that("quality hysteresis uses frozen enter and remain thresholds", {
  x <- hreg91_quality_state(c(.2, .35, .41, .75, .65, .59, .25))
  testthat::expect_equal(x, c("LOW_QUALITY", "LOW_QUALITY", "MEDIUM_QUALITY", "HIGH_QUALITY", "HIGH_QUALITY", "MEDIUM_QUALITY", "LOW_QUALITY"))
})

testthat::test_that("ledger eligibility requires positive strength and HIGH quality", {
  c <- hreg91_contract(); c$primary_window <- 5L; c$durability_window <- 6L; c$percentile_lookback <- 3L
  close <- exp(cumsum(rep(.01, 20) + sin(seq_len(20)) * .001)); bars <- data.frame(symbol = "X", session_date = seq(as.Date("2020-01-01"), by = "day", length.out = 20), open = close, high = close * 1.01, low = close * .99, close = close, volume = 100)
  x <- hreg91_build_asset_ledger(bars, c)
  testthat::expect_true(all(x$orderly_up_eligible %in% c(TRUE, FALSE, NA)))
  testthat::expect_true(all(!x$orderly_up_eligible[is.finite(x$normalized_strength60) & x$normalized_strength60 <= 0], na.rm = TRUE))
  testthat::expect_true(all(x$quality_state60[x$orderly_up_eligible %in% TRUE] == "HIGH_QUALITY"))
})

testthat::test_that("append audit is exact", {
  x <- hreg91_causality_audit()
  testthat::expect_true(all(x$passed))
  testthat::expect_equal(max(x$maximum_append_difference), 0)
})

testthat::test_that("synthetic paths order direction and quality", {
  c <- hreg91_contract(); c$synthetic_paths <- 40L
  s <- hreg91_synthetic_summary(hreg91_synthetic_calibration(c)); row <- function(name) s[s$process == name, ]
  testthat::expect_gt(row("CLEAN_UP")$positive_slope_fraction, .95)
  testthat::expect_lt(row("CLEAN_DOWN")$positive_slope_fraction, .05)
  testthat::expect_gt(row("CLEAN_UP")$median_path_quality, row("NOISY_UP")$median_path_quality)
  testthat::expect_gt(row("CLEAN_UP")$median_path_quality, row("REVERSAL")$median_path_quality)
})

testthat::test_that("confirmation rows and duplicate rows are rejected", {
  bars <- hreg91_test_bars(); bars$session_date <- seq(as.Date("2023-11-30"), by = "day", length.out = nrow(bars))
  testthat::expect_error(hreg91_assert_bars(bars), "Confirmation")
  bars <- hreg91_test_bars(); testthat::expect_error(hreg91_assert_bars(rbind(bars, bars[1, ])), "duplicated")
})

testthat::test_that("entry policy skips ineligible crosses rather than deferring", {
  frame <- hreg91_frame(); cross <- which(frame$cross_up)[1L]; frame$orderly_up_eligible[[cross]] <- FALSE
  schedule <- hreg91_schedule(frame, min(frame$session_date), max(frame$session_date), "ENTRY_ORDERLY_UP_ONLY")
  testthat::expect_true(schedule$blocked_entry[[cross + 1L]])
  testthat::expect_false(schedule$target[[cross + 1L]])
  testthat::expect_false(any(schedule$entry_signal[seq.int(cross + 2L, min(cross + 4L, nrow(schedule)))]))
})

testthat::test_that("unfiltered and fully eligible schedules agree", {
  frame <- hreg91_frame(); a <- hreg91_schedule(frame, min(frame$session_date), max(frame$session_date), "UNFILTERED"); b <- hreg91_schedule(frame, min(frame$session_date), max(frame$session_date), "ENTRY_ORDERLY_UP_ONLY")
  testthat::expect_equal(a$target, b$target)
})

testthat::test_that("circular eligibility controls are deterministic and nonzero", {
  frame <- hreg91_frame(); a <- hreg91_shifted_schedule(frame, min(frame$session_date), max(frame$session_date), 7); b <- hreg91_shifted_schedule(frame, min(frame$session_date), max(frame$session_date), 7)
  testthat::expect_equal(a$target, b$target)
  testthat::expect_gt(attr(a, "shift_offset"), 0)
})

testthat::test_that("exposure-nearest selection ignores returns", {
  x <- data.frame(simulation_id = 1:4, median_exposure = c(.1, .2, .3, .4), median_return = c(100, -100, 50, 0))
  testthat::expect_equal(hreg91_exposure_near_ids(x, .26, 2), c(3L, 2L))
})
