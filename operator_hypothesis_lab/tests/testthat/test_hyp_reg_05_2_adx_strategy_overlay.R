repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_05_2_adx_strategy_overlay.R"))

hreg52_test_bars <- function() {
  dates <- seq(as.Date("2020-01-02"), by = "day", length.out = 34L)
  close <- c(rep(10, 14), 11, 12, 13, 12, 11, 10, 11, 12, 13, 14, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6)
  data.frame(symbol = "TEST", session_date = dates, timestamp_utc = as.POSIXct(dates, tz = "UTC"),
             open = close, high = close * 1.01, low = close * .99, close = close, volume = 1000)
}

hreg52_frame <- function() {
  bars <- hreg52_test_bars()
  x <- hreg12_cross_frame(bars)
  x$adx_state <- "HIGH"
  x$adx14 <- 30
  x$adx_percentile <- .8
  x
}

testthat::test_that("contract freezes the two strategy-relative overlays", {
  x <- hreg52_contract()
  testthat::expect_equal(x$hypothesis_id, "HYP-REG-05.2")
  testthat::expect_equal(x$policies, c("UNFILTERED", "ENTRY_HIGH_ONLY", "REACTIVE_HIGH_ONLY"))
  testthat::expect_equal(x$primary_bps, 5)
  testthat::expect_equal(x$placebo_simulations, 200L)
  testthat::expect_equal(x$confirmation_start, as.Date("2024-01-02"))
})

testthat::test_that("blank prehistory states normalize to missing without inventing a regime", {
  states <- data.frame(
    symbol = "TEST",
    session_date = as.Date(c("2017-12-29", "2018-01-02")),
    adx14 = c(NA, 25),
    adx_percentile = c(NA, .75),
    adx_state = c("", "HIGH"),
    stringsAsFactors = FALSE
  )
  out <- hreg52_validate_state_ledger(states)
  testthat::expect_true(is.na(out$adx_state[[1L]]))
  testthat::expect_equal(out$adx_state[[2L]], "HIGH")
})

testthat::test_that("unfiltered policy reproduces the parent schedule", {
  bars <- hreg52_test_bars(); frame <- hreg52_frame()
  a <- hreg52_schedule(frame, min(bars$session_date), max(bars$session_date), "UNFILTERED")
  b <- imom_sma_schedule(bars, min(bars$session_date), max(bars$session_date), 8, 14, 0)
  testthat::expect_identical(a$target, b$target)
  testthat::expect_identical(a$entry_signal, b$entry_signal)
  testthat::expect_identical(a$exit_signal, b$exit_signal)
})

testthat::test_that("HIGH admits a fresh entry and MEDIUM blocks without deferral", {
  frame <- hreg52_frame(); signal_i <- which(frame$cross_up)[[1L]]
  high <- hreg52_schedule(frame, min(frame$session_date), max(frame$session_date), "ENTRY_HIGH_ONLY")
  testthat::expect_true(high$target[[signal_i + 1L]])
  frame$adx_state[[signal_i]] <- "MEDIUM"
  blocked <- hreg52_schedule(frame, min(frame$session_date), max(frame$session_date), "ENTRY_HIGH_ONLY")
  testthat::expect_true(blocked$blocked_entry[[signal_i + 1L]])
  testthat::expect_false(blocked$target[[signal_i + 1L]])
  testthat::expect_false(blocked$target[[signal_i + 2L]])
})

testthat::test_that("entry permission uses signal-close rather than entry-open state", {
  frame <- hreg52_frame(); signal_i <- which(frame$cross_up)[[1L]]
  frame$adx_state[[signal_i]] <- "MEDIUM"
  frame$adx_state[[signal_i + 1L]] <- "HIGH"
  out <- hreg52_schedule(frame, min(frame$session_date), max(frame$session_date), "ENTRY_HIGH_ONLY")
  testthat::expect_true(out$blocked_entry[[signal_i + 1L]])
  testthat::expect_equal(out$signal_state[[signal_i + 1L]], "MEDIUM")
})

testthat::test_that("entry-only ignores later state changes", {
  frame <- hreg52_frame(); signal_i <- which(frame$cross_up)[[1L]]
  frame$adx_state[[signal_i + 1L]] <- "MEDIUM"
  out <- hreg52_schedule(frame, min(frame$session_date), max(frame$session_date), "ENTRY_HIGH_ONLY")
  testthat::expect_true(out$target[[signal_i + 1L]])
  testthat::expect_true(out$target[[signal_i + 2L]])
  testthat::expect_false(out$state_exit[[signal_i + 2L]])
})

testthat::test_that("reactive policy exits next open after ADX leaves HIGH", {
  frame <- hreg52_frame(); signal_i <- which(frame$cross_up)[[1L]]
  frame$adx_state[[signal_i + 1L]] <- "MEDIUM"
  out <- hreg52_schedule(frame, min(frame$session_date), max(frame$session_date), "REACTIVE_HIGH_ONLY")
  testthat::expect_true(out$target[[signal_i + 1L]])
  testthat::expect_false(out$target[[signal_i + 2L]])
  testthat::expect_true(out$state_exit[[signal_i + 2L]])
  testthat::expect_equal(out$exit_reason[[signal_i + 2L]], "ADX_LEFT_HIGH")
})

testthat::test_that("reactive exit does not re-enter without a new parent cross", {
  frame <- hreg52_frame(); signal_i <- which(frame$cross_up)[[1L]]
  frame$adx_state[[signal_i + 1L]] <- "MEDIUM"
  frame$adx_state[[signal_i + 2L]] <- "HIGH"
  out <- hreg52_schedule(frame, min(frame$session_date), max(frame$session_date), "REACTIVE_HIGH_ONLY")
  testthat::expect_false(out$target[[signal_i + 2L]])
  testthat::expect_false(out$target[[signal_i + 3L]])
})

testthat::test_that("parent cross-down takes exit-reason priority", {
  frame <- hreg52_frame(); signal_i <- which(frame$cross_up)[[1L]]; down_i <- which(frame$cross_down & seq_len(nrow(frame)) > signal_i)[[1L]]
  frame$adx_state[[down_i]] <- "MEDIUM"
  out <- hreg52_schedule(frame, min(frame$session_date), max(frame$session_date), "REACTIVE_HIGH_ONLY")
  testthat::expect_equal(out$exit_reason[[down_i + 1L]], "PARENT_CROSS_DOWN")
  testthat::expect_false(out$state_exit[[down_i + 1L]])
})

testthat::test_that("circular controls preserve state counts and use deterministic nonzero shifts", {
  x <- rep(c("LOW", "MEDIUM", "HIGH"), c(4, 3, 5))
  y <- hreg52_rotate(x, 5)
  testthat::expect_equal(unname(sort(table(x))), unname(sort(table(y))))
  offsets <- vapply(1:200, hreg52_shift_offset, integer(1), n = 252L, simulations = 200L)
  testthat::expect_true(all(offsets >= 1L & offsets <= 251L))
  testthat::expect_equal(offsets, vapply(1:200, hreg52_shift_offset, integer(1), n = 252L, simulations = 200L))
})

testthat::test_that("exposure matching ignores returns and percentile handles ties", {
  controls <- data.frame(simulation_id = 1:5, median_exposure = c(.2, .4, .51, .55, .8), median_return = c(9, -9, 8, -8, 7))
  testthat::expect_equal(hreg52_exposure_near_ids(controls, .5, 2), c(3L, 4L))
  testthat::expect_equal(hreg52_midrank_percentile(2, c(1, 2, 2, 3)), .5)
})

testthat::test_that("state validation rejects confirmation and malformed states", {
  good <- data.frame(symbol = "X", session_date = as.Date("2023-12-29"), adx14 = 30, adx_percentile = .8, adx_state = "HIGH")
  testthat::expect_equal(nrow(hreg52_validate_state_ledger(good)), 1L)
  future <- rbind(good, transform(good, session_date = as.Date("2024-01-02")))
  testthat::expect_error(hreg52_validate_state_ledger(future), "Confirmation")
  bad <- transform(good, adx_state = "TRENDING")
  testthat::expect_error(hreg52_validate_state_ledger(bad), "Unexpected")
})
