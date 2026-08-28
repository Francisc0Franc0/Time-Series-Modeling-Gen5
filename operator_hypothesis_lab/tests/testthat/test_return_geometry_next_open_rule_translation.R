source(file.path("..", "..", "R", "return_geometry_next_open_rule_translation.R"))

rgnor_test_ledger <- function(n = 420L) {
  dates <- seq.Date(as.Date("2016-01-04"), by = "day", length.out = 700L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- exp(seq(log(120), log(80), length.out = n) + 0.08 * sin(seq_len(n) / 8))
  data.frame(
    symbol = "TEST", session_date = dates,
    open = close * exp(0.002 * cos(seq_len(n) / 5)), close = close,
    signed_er20 = -0.5, signed_er20_state = "DOWN_TREND",
    stringsAsFactors = FALSE
  )
}

testthat::test_that("causal negative-return threshold excludes current and positive observations", {
  x <- c(-5, -4, 2, -3, -2, -10)
  threshold <- rgnor_causal_negative_threshold(
    x, probability = 0.5, minimum_observations = 2L, quantile_type = 7L
  )
  testthat::expect_true(is.na(threshold$negative_return_q20[[2L]]))
  testthat::expect_equal(threshold$negative_return_q20[[4L]], -4.5)
  testthat::expect_equal(threshold$negative_history_observations[[6L]], 4L)
  testthat::expect_equal(threshold$negative_return_q20[[6L]], -3.5)
})

testthat::test_that("candidate construction uses next open and exits after 20 held sessions", {
  ledger <- rgnor_test_ledger()
  contract <- rgnor_contract()
  contract$analysis_start <- ledger$session_date[[150L]]
  contract$analysis_end <- max(ledger$session_date)
  contract$minimum_prior_negative_observations <- 10L
  candidates <- rgnor_construct_candidates(ledger, contract)
  first <- candidates[1L, ]
  testthat::expect_equal(first$entry_index, first$anchor_index + 1L)
  testthat::expect_equal(first$exit_index, first$entry_index + 20L)
  testthat::expect_equal(first$entry_open, ledger$open[[first$entry_index]])
  testthat::expect_equal(first$exit_open, ledger$open[[first$exit_index]])
  testthat::expect_equal(
    first$gross_open_log_return,
    log(ledger$open[[first$exit_index]] / ledger$open[[first$entry_index]])
  )
})

testthat::test_that("primary signals require signed down state and bottom quintile loss", {
  ledger <- rgnor_test_ledger()
  contract <- rgnor_contract()
  contract$analysis_start <- ledger$session_date[[150L]]
  contract$analysis_end <- max(ledger$session_date)
  contract$minimum_prior_negative_observations <- 10L
  candidates <- rgnor_construct_candidates(ledger, contract)
  signal <- candidates[candidates$primary_signal, , drop = FALSE]
  testthat::expect_true(nrow(signal) > 0L)
  testthat::expect_true(all(signal$signed_er20_state == "DOWN_TREND"))
  testthat::expect_true(all(signal$prior_20_log_return < 0))
  testthat::expect_true(all(signal$prior_20_log_return <= signal$negative_return_q20))
})

testthat::test_that("nonoverlap ignores signals until the exit open", {
  candidates <- data.frame(
    anchor_index = 1:50,
    exit_index = 22:71,
    primary_signal = TRUE,
    state_signal = TRUE,
    stringsAsFactors = FALSE
  )
  selected <- rgnor_select_nonoverlapping(candidates, "primary_signal")
  testthat::expect_equal(selected$anchor_index, c(1L, 22L, 43L))
  testthat::expect_true(all(diff(selected$anchor_index) >= 21L))
})

testthat::test_that("trade paths begin at zero and end at the executable return", {
  ledger <- rgnor_test_ledger()
  contract <- rgnor_contract()
  contract$analysis_start <- ledger$session_date[[150L]]
  contract$analysis_end <- max(ledger$session_date)
  contract$minimum_prior_negative_observations <- 10L
  study <- rgnor_build_asset_study(ledger, contract)
  testthat::expect_true(nrow(study$primary) > 0L)
  paths <- rgnor_build_trade_paths(ledger, study$primary, contract)
  first <- paths[paths$anchor_session == paths$anchor_session[[1L]], , drop = FALSE]
  testthat::expect_equal(first$cumulative_open_log_return[[1L]], 0)
  testthat::expect_equal(
    first$cumulative_open_log_return[[nrow(first)]],
    study$primary$gross_open_log_return[[1L]]
  )
})

testthat::test_that("TRAIN classification requires coverage and broad positive excess", {
  sectors <- data.frame(
    sector = paste0("S", 1:11), assets = 8L, active_assets = 8L,
    total_trades = 40L, median_trades_per_active_asset = 5,
    median_asset_mean_net_log_return = 0.01,
    median_asset_mean_net_excess = 0.005,
    positive_net_asset_fraction = 0.75,
    positive_excess_asset_fraction = 0.75,
    median_state_only_mean_net_log_return = 0.002,
    median_asset_mean_net_difference_vs_state_only = 0.008,
    positive_difference_vs_state_only_asset_fraction = 0.75
  )
  assets <- data.frame(
    sector_balance_eligible = rep(TRUE, 88), trades = 5L,
    mean_net_excess_vs_unconditional = 0.005
  )
  equal_sector <- rgnor_equal_sector_summary(sectors)
  result <- rgnor_classify_train(equal_sector, sectors, assets)
  testthat::expect_true(all(result$checks$pass))
  testthat::expect_equal(
    result$status,
    "TRAIN_RULE_TRANSLATION_RETAINS_MECHANICAL_SUPPORT_STOP_BEFORE_OOS"
  )
})
