module_path <- file.path("operator_hypothesis_lab", "R",
  "gen5_hyp_imom_04_1_cal_a02_tsla_direct_exposure.R")
if (!file.exists(module_path)) module_path <- file.path("..", "..", "R",
  "gen5_hyp_imom_04_1_cal_a02_tsla_direct_exposure.R")
source(module_path)

testthat::test_that("CAL-A02 contract preserves the sealed direct-exposure design", {
  contract <- him042_contract()
  testthat::expect_true(him042_validate_contract(contract))
  testthat::expect_identical(contract$attempt_id, "CAL-A02")
  testthat::expect_identical(contract$symbols, c("TSLA", "QQQ", "SPY", "SMH"))
  testthat::expect_lt(contract$development_end, contract$confirmation_start)
  testthat::expect_equal(length(him042_feature_names()), 12L)
  testthat::expect_equal(length(him042_interaction_names()), 4L)
  testthat::expect_equal(him042_roundtrip_log_buffer(10), -2 * log(.999))
})
make_him042_bars <- function(session_count = 620L) {
  sessions <- as.Date("2017-01-03") + seq_len(session_count) - 1L
  symbols <- c("TSLA", "QQQ", "SPY", "SMH")
  rows <- vector("list", length(symbols) * session_count * 13L); z <- 1L
  for (symbol_index in seq_along(symbols)) {
    level <- 50 + 10 * symbol_index
    for (i in seq_along(sessions)) {
      session_open <- level * exp(.0008 * i + .01 * sin(i / 17 + symbol_index))
      for (slot in 1:13) {
        open <- session_open * exp(.0003 * (slot - 1L))
        close <- session_open * exp(.0003 * slot + .0005 * sin(slot + i / 11))
        rows[[z]] <- data.frame(
          symbol = symbols[[symbol_index]],
          timestamp_utc = as.POSIXct(sessions[[i]], tz = "UTC") + slot * 1800,
          session_date = sessions[[i]], bar_slot = slot,
          open = open, high = max(open, close) * 1.001,
          low = min(open, close) * .999, close = close,
          volume = 1e6 + 1000 * i + 100 * slot + 5000 * symbol_index,
          stringsAsFactors = FALSE)
        z <- z + 1L
      }
    }
  }
  do.call(rbind, rows)
}

testthat::test_that("session panel is causal and aligns next-open intervals", {
  bars <- make_him042_bars()
  panel <- him042_build_session_panel(bars)
  testthat::expect_true(nrow(panel) > 100L)
  testthat::expect_true(all(panel$session_date < as.Date("2024-01-02")))
  testthat::expect_true(all(panel$entry_session > panel$session_date))
  testthat::expect_true(all(panel$exit_session > panel$entry_session))
  testthat::expect_equal(panel$forward_simple_return,
    panel$exit_open / panel$entry_open - 1, tolerance = 1e-12)
  testthat::expect_true(any(panel$feature_complete))
  first <- which(panel$feature_complete)[[1L]]
  testthat::expect_true(all(is.finite(as.numeric(panel[first, him042_model_feature_names()]))))
})

testthat::test_that("ridge and tree recover their planted mechanisms", {
  synthetic <- him042_synthetic_suite()
  testthat::expect_identical(synthetic$control,
    c("RIDGE_LINEAR_PLANT", "TREE_CONJUNCTION_PLANT"))
  testthat::expect_true(all(synthetic$gate_pass))
  testthat::expect_true(all(synthetic$model_mse < synthetic$baseline_mse))
})

testthat::test_that("policy replay charges transitions and measures capture", {
  ledger <- data.frame(
    row_id = 1:4, entry_session = as.Date("2021-01-04") + 0:3,
    exit_session = as.Date("2021-01-05") + 0:3,
    entry_open = 100, exit_open = 100 * (1 + c(.10, -.10, .05, -.05)),
    actual_simple_return = c(.10, -.10, .05, -.05), stringsAsFactors = FALSE)
  replay <- him042_policy_replay(ledger, c(1, 0, 1, 0), 0, "TEST")
  testthat::expect_equal(replay$summary$total_return, 1.10 * 1.05 - 1, tolerance = 1e-12)
  testthat::expect_equal(replay$summary$exposure, .5)
  testthat::expect_equal(replay$summary$upside_capture, 1)
  testthat::expect_equal(replay$summary$downside_capture, 0)
  testthat::expect_equal(replay$summary$entries, 2L)
  costly <- him042_policy_replay(ledger, c(1, 1, 0, 0), 10, "COSTLY")
  testthat::expect_lt(costly$summary$total_return,
                      him042_policy_replay(ledger, c(1, 1, 0, 0), 0, "GROSS")$summary$total_return)
})

testthat::test_that("quarterly OOF scoring applies the target embargo", {
  set.seed(42)
  dates <- seq(as.Date("2018-01-02"), as.Date("2023-12-27"), by = "day")
  panel <- data.frame(
    row_id = seq_along(dates), session_date = dates,
    entry_session = dates + 1L, exit_session = dates + 2L,
    entry_open = 100, exit_open = NA_real_, stringsAsFactors = FALSE)
  for (feature in him042_feature_names()) panel[[feature]] <- stats::rnorm(nrow(panel))
  panel$trend_x_efficiency <- panel$asset_trend_200 * panel$efficiency_20
  panel$trend_x_downside <- panel$asset_trend_200 * panel$downside_share_20
  panel$rs_qqq_x_qqq_trend <- panel$rs_qqq_20 * panel$qqq_trend_200
  panel$intraday_efficiency_x_volume <- panel$intraday_efficiency_5 * panel$relative_volume_20
  panel$forward_log_return <- .005 * panel$asset_trend_200 +
    .004 * panel$efficiency_20 + stats::rnorm(nrow(panel), sd = .01)
  panel$forward_simple_return <- exp(panel$forward_log_return) - 1
  panel$exit_open <- panel$entry_open * (1 + panel$forward_simple_return)
  panel$feature_complete <- TRUE
  oof <- him042_oof_predictions(panel)
  testthat::expect_equal(length(unique(oof$predictions$fold)), 12L)
  testthat::expect_identical(sort(unique(oof$predictions$model_id)),
                             c("R1_RIDGE", "T1_DEPTH2"))
  testthat::expect_true(all(oof$folds$embargo_pass))
  testthat::expect_true(all(oof$folds$maximum_train_exit < oof$folds$test_start))
})
