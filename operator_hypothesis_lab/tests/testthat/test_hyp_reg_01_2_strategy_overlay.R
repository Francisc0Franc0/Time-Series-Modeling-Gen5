repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))

test_bars <- function() {
  dates <- seq(as.Date("2020-01-02"), by = "day", length.out = 30L)
  close <- c(rep(10, 14), 11, 12, 13, 12, 11, 10, 11, 12, 13, 14, 13, 12, 11, 10, 9, 8)
  data.frame(symbol = "TEST", session_date = dates, timestamp_utc = as.POSIXct(dates, tz = "UTC"),
             open = close, high = close * 1.01, low = close * .99, close = close, volume = 1000)
}

testthat::test_that("circular controls preserve state counts", {
  x <- rep(c("LOW", "MEDIUM", "HIGH"), c(4, 3, 5))
  y <- hreg12_rotate(x, 5)
  testthat::expect_equal(unname(sort(table(x))), unname(sort(table(y))))
  testthat::expect_equal(length(x), length(y))
})

testthat::test_that("shift offsets are deterministic and nonzero", {
  offsets <- vapply(1:200, hreg12_shift_offset, integer(1), n = 252L, simulations = 200L)
  testthat::expect_true(all(offsets >= 1L & offsets <= 251L))
  testthat::expect_equal(offsets, vapply(1:200, hreg12_shift_offset, integer(1), n = 252L, simulations = 200L))
})

testthat::test_that("unfiltered schedule reproduces the parent schedule", {
  bars <- test_bars(); frame <- hreg12_cross_frame(bars)
  frame$regime_state <- "MEDIUM"
  a <- hreg12_schedule(frame, min(bars$session_date), max(bars$session_date), gate_low = FALSE)
  b <- imom_sma_schedule(bars, min(bars$session_date), max(bars$session_date), 8, 14, 0)
  testthat::expect_identical(a$target, b$target)
  testthat::expect_identical(a$entry_signal, b$entry_signal)
  testthat::expect_identical(a$exit_signal, b$exit_signal)
})

testthat::test_that("LOW blocks only the fresh entry and does not defer it", {
  bars <- test_bars(); frame <- hreg12_cross_frame(bars); frame$regime_state <- "MEDIUM"
  cross_date <- frame$session_date[which(frame$cross_up)[[1L]]]
  frame$regime_state[frame$session_date == cross_date] <- "LOW"
  schedule <- hreg12_schedule(frame, min(bars$session_date), max(bars$session_date), gate_low = TRUE)
  testthat::expect_equal(sum(schedule$blocked_entry), 1L)
  entry_open <- match(cross_date, frame$session_date) + 1L
  testthat::expect_false(schedule$target[[entry_open]])
  testthat::expect_false(any(schedule$target[entry_open:min(entry_open + 2L, nrow(schedule))]))
})

testthat::test_that("entry permission uses the signal-close state, not entry-day state", {
  bars <- test_bars(); frame <- hreg12_cross_frame(bars); frame$regime_state <- "MEDIUM"
  signal_i <- which(frame$cross_up)[[1L]]
  frame$regime_state[[signal_i]] <- "LOW"
  frame$regime_state[[signal_i + 1L]] <- "HIGH"
  schedule <- hreg12_schedule(frame, min(bars$session_date), max(bars$session_date), gate_low = TRUE)
  testthat::expect_true(schedule$blocked_entry[[signal_i + 1L]])
  testthat::expect_identical(schedule$signal_state[[signal_i + 1L]], "LOW")
})

testthat::test_that("LOW after entry does not force an exit", {
  bars <- test_bars(); frame <- hreg12_cross_frame(bars); frame$regime_state <- "MEDIUM"
  signal_i <- which(frame$cross_up)[[1L]]
  frame$regime_state[(signal_i + 1L):min(signal_i + 3L, nrow(frame))] <- "LOW"
  schedule <- hreg12_schedule(frame, min(bars$session_date), max(bars$session_date), gate_low = TRUE)
  testthat::expect_true(schedule$target[[signal_i + 1L]])
  testthat::expect_true(schedule$target[[signal_i + 2L]])
})

testthat::test_that("exposure-near controls are selected without return columns", {
  controls <- data.frame(simulation_id = 1:5, median_exposure = c(.2, .4, .51, .55, .8), median_return = c(9, -9, 8, -8, 7))
  testthat::expect_equal(hreg12_exposure_near_ids(controls, .5, 2), c(3L, 4L))
})

testthat::test_that("confirmation states are rejected", {
  states <- data.frame(symbol = "X", session_date = as.Date(c("2023-12-29", "2024-01-02")), regime_state = "LOW")
  testthat::expect_error(hreg12_validate_state_ledger(states), "Confirmation")
})

testthat::test_that("midrank percentile handles ties", {
  testthat::expect_equal(hreg12_midrank_percentile(2, c(1, 2, 2, 3)), .5)
})
