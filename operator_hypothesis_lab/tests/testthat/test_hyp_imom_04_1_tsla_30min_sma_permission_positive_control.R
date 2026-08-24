source(testthat::test_path("..", "..", "R", "hyp_intraday_momentum_engine.R"))
source(testthat::test_path("..", "..", "R", "gen5_hyp_imom_04_1_tsla_30min_sma_permission_positive_control.R"))

him041_daily_fixture <- function(symbol = "TSLA", n = 520L) {
  date <- seq(as.Date("2010-01-04"), by = "day", length.out = n * 2L)
  date <- date[as.POSIXlt(date)$wday %in% 1:5][seq_len(n)]
  close <- 100 * cumprod(1 + .0005 + .01 * sin(seq_len(n) / 17))
  data.frame(symbol = symbol, session_date = date, open = close * .999,
    high = close * 1.012, low = close * .988, close = close,
    volume = 1e6 + seq_len(n), stringsAsFactors = FALSE)
}

him041_intraday_fixture <- function(n_sessions = 420L) {
  sessions <- him041_daily_fixture(n = n_sessions)$session_date
  n <- length(sessions) * 13L
  session_date <- rep(sessions, each = 13L)
  slot <- rep(seq_len(13L), times = length(sessions))
  close <- 100 + seq_len(n) * .002 + 2 * sin(seq_len(n) / 9)
  data.frame(symbol = "TSLA",
    timestamp_utc = as.POSIXct(session_date, tz = "UTC") + (13 + slot / 2) * 3600,
    session_date = session_date, bar_time_et = sprintf("S%02d", slot), bar_slot = slot,
    open = close + .01, high = close + .2, low = close - .2, close = close,
    volume = 1e6 + slot * 1000 + seq_len(n), stringsAsFactors = FALSE)
}

testthat::test_that("daily state is lagged before intraday attachment", {
  tsla <- him041_daily_fixture("TSLA", 520L)
  qqq <- him041_daily_fixture("QQQ", 520L)
  state <- him041_daily_state(tsla, qqq)
  bars <- him041_intraday_fixture(420L)
  panel <- him041_build_feature_panel(bars, state)
  eligible <- which(is.finite(panel$asset_trend))
  testthat::expect_true(length(eligible) > 0L)
  testthat::expect_true(all(panel$prior_state_date[eligible] < panel$session_date[eligible]))
})

testthat::test_that("same-slot participation excludes the current bar", {
  tsla <- him041_daily_fixture("TSLA", 520L)
  state <- him041_daily_state(tsla, him041_daily_fixture("QQQ", 520L))
  bars <- him041_intraday_fixture(420L)
  panel_a <- him041_build_feature_panel(bars, state)
  index <- which(panel_a$bar_slot == 5L)[30L]
  bars$volume[[index]] <- bars$volume[[index]] * 10
  panel_b <- him041_build_feature_panel(bars, state)
  testthat::expect_equal(panel_b$participation_surprise[[index]] + 1,
    10 * (panel_a$participation_surprise[[index]] + 1), tolerance = 1e-8)
  next_same_slot <- which(panel_a$bar_slot == 5L & seq_len(nrow(panel_a)) > index)[[1L]]
  testthat::expect_false(isTRUE(all.equal(panel_a$participation_surprise[[next_same_slot]],
    panel_b$participation_surprise[[next_same_slot]])))
})

testthat::test_that("monotone stump learns only the registered direction", {
  set.seed(41)
  n <- 800L
  x <- runif(n, -1, 1)
  train <- data.frame(signal_timestamp = as.POSIXct("2015-01-01", tz = "UTC") + seq_len(n) * 86400,
    asset_trend = x, profitable = rbinom(n, 1, ifelse(x >= 0, .8, .2)))
  fit <- him041_fit_univariate(train, "asset_trend", "HIGHER")
  testthat::expect_true(fit$admissible)
  testthat::expect_lt(abs(fit$threshold), .25)
  testthat::expect_gt(fit$p_permit, fit$p_reject)
})

testthat::test_that("all nine planted positive controls are recovered", {
  recovery <- him041_synthetic_suite()
  testthat::expect_equal(nrow(recovery), 9L)
  testthat::expect_true(all(recovery$gate_pass))
})

testthat::test_that("implementation has no implicit date or confirmation read", {
  path <- testthat::test_path("..", "..", "R",
    "gen5_hyp_imom_04_1_tsla_30min_sma_permission_positive_control.R")
  code <- paste(readLines(path), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
  testthat::expect_match(code, "2024-01-02")
})
