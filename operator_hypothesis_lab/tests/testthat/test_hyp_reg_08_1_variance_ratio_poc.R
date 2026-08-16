repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_momentum_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_2_strategy_overlay.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_08_1_variance_ratio_poc.R"))

hreg81_test_bars <- function() {
  dates <- seq(as.Date("2020-01-02"), by = "day", length.out = 34L)
  close <- c(rep(10, 14), 11, 12, 13, 12, 11, 10, 11, 12, 13, 14, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6)
  data.frame(symbol = "TEST", session_date = dates, timestamp_utc = as.POSIXct(dates, tz = "UTC"),
             open = close, high = close * 1.01, low = close * .99, close = close, volume = 1000)
}

hreg81_frame <- function() {
  x <- hreg12_cross_frame(hreg81_test_bars())
  x$vr5_state <- "HIGH"; x$vr5 <- 1.2; x$vr5_z_robust <- 1; x$vr5_percentile <- .8; x$vr10 <- 1.1; x$vr10_z_robust <- .5
  x
}

testthat::test_that("contract freezes the approved variance-ratio lane", {
  x <- hreg81_contract()
  testthat::expect_equal(x$hypothesis_id, "HYP-REG-08.1")
  testthat::expect_equal(x$estimation_returns, 252L)
  testthat::expect_equal(x$percentile_lookback, 252L)
  testthat::expect_equal(x$preferred_prehistory, 550L)
  testthat::expect_equal(x$minimum_prehistory, 503L)
  testthat::expect_equal(x$primary_q, 5L)
  testthat::expect_equal(x$durability_q, 10L)
  testthat::expect_equal(x$policies, c("UNFILTERED", "ENTRY_HIGH_ONLY"))
  testthat::expect_equal(x$confirmation_start, as.Date("2024-01-02"))
})

testthat::test_that("variance-ratio identity separates persistent and reversing increments", {
  set.seed(9)
  pos <- as.numeric(stats::arima.sim(list(ar = .35), n = 5000))
  neg <- as.numeric(stats::arima.sim(list(ar = -.35), n = 5000))
  iid <- stats::rnorm(5000)
  testthat::expect_gt(hreg81_population_vr_identity(pos, 5), 1)
  testthat::expect_lt(hreg81_population_vr_identity(neg, 5), 1)
  testthat::expect_lt(abs(hreg81_population_vr_identity(iid, 5) - 1), .1)
})

testthat::test_that("heteroskedasticity-robust statistic is finite and p-value is bounded", {
  set.seed(10)
  scale <- rep(c(.5, 2), 126)
  out <- hreg81_variance_ratio(c(0, cumsum(stats::rnorm(252, sd = scale))), 5)
  testthat::expect_true(all(is.finite(out)))
  testthat::expect_gte(out[["p_value"]], 0)
  testthat::expect_lte(out[["p_value"]], 1)
})

testthat::test_that("rolling construction is invariant to appended future data", {
  audit <- hreg81_causality_audit()
  testthat::expect_true(all(audit$passed))
})

testthat::test_that("signed state never labels negative z HIGH or positive z LOW", {
  z <- c(rep(-2, 4), rep(.2, 4), rep(2, 4), rep(-.2, 4))
  p <- c(.1, .2, .3, .35, .5, .55, .6, .65, .75, .8, .9, .85, .5, .45, .4, .35)
  state <- hreg81_signed_hysteretic_state(z, p)
  testthat::expect_false(any(state == "HIGH" & z <= 0, na.rm = TRUE))
  testthat::expect_false(any(state == "LOW" & z >= 0, na.rm = TRUE))
})

testthat::test_that("unfiltered schedule reproduces parent and HIGH alone admits entry", {
  frame <- hreg81_frame(); bars <- hreg81_test_bars()
  parent <- hreg81_schedule(frame, min(bars$session_date), max(bars$session_date), "UNFILTERED")
  reference <- imom_sma_schedule(bars, min(bars$session_date), max(bars$session_date), 8, 14, 0)
  testthat::expect_identical(parent$target, reference$target)
  signal_i <- which(frame$cross_up)[[1L]]
  high <- hreg81_schedule(frame, min(bars$session_date), max(bars$session_date), "ENTRY_HIGH_ONLY")
  testthat::expect_true(high$target[[signal_i + 1L]])
  frame$vr5_state[[signal_i]] <- "MEDIUM"
  blocked <- hreg81_schedule(frame, min(bars$session_date), max(bars$session_date), "ENTRY_HIGH_ONLY")
  testthat::expect_true(blocked$blocked_entry[[signal_i + 1L]])
  testthat::expect_false(blocked$target[[signal_i + 1L]])
  testthat::expect_false(blocked$target[[signal_i + 2L]])
})

testthat::test_that("entry state is read at signal close and exits remain parent-owned", {
  frame <- hreg81_frame(); signal_i <- which(frame$cross_up)[[1L]]; down_i <- which(frame$cross_down & seq_len(nrow(frame)) > signal_i)[[1L]]
  frame$vr5_state[[signal_i + 1L]] <- "MEDIUM"
  out <- hreg81_schedule(frame, min(frame$session_date), max(frame$session_date), "ENTRY_HIGH_ONLY")
  testthat::expect_true(out$target[[signal_i + 1L]])
  testthat::expect_true(out$target[[signal_i + 2L]])
  testthat::expect_false(out$target[[down_i + 1L]])
})

testthat::test_that("circular shifts preserve state counts and exposure matching ignores returns", {
  x <- rep(c("LOW", "MEDIUM", "HIGH"), c(4, 3, 5))
  testthat::expect_equal(unname(sort(table(x))), unname(sort(table(hreg81_rotate(x, 5)))))
  controls <- data.frame(simulation_id = 1:5, median_exposure = c(.2, .4, .51, .55, .8), median_return = c(9, -9, 8, -8, 7))
  testthat::expect_equal(hreg81_exposure_near_ids(controls, .5, 2), c(3L, 4L))
})

testthat::test_that("state validation rejects confirmation rows and malformed states", {
  good <- data.frame(symbol = "X", session_date = as.Date("2023-12-29"), vr5 = 1.2, vr5_z_robust = 1, vr5_percentile = .8, vr5_state = "HIGH")
  testthat::expect_equal(nrow(hreg81_validate_state_ledger(good)), 1L)
  testthat::expect_error(hreg81_validate_state_ledger(rbind(good, transform(good, session_date = as.Date("2024-01-02")))), "Confirmation")
  testthat::expect_error(hreg81_validate_state_ledger(transform(good, vr5_state = "TRENDING")), "Unexpected")
})
