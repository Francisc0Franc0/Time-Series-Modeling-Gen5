source(file.path("..", "..", "R", "return_geometry_continuation_next_open_rule.R"))
source(file.path("..", "..", "R", "return_geometry_continuation_20d_attribution.R"))

rgca_test_ledger <- function(n = 420L) {
  dates <- seq.Date(as.Date("2016-01-04"), by = "day", length.out = 700L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- exp(log(100) + 0.0006 * seq_len(n) + 0.09 * sin(seq_len(n) / 12))
  er20 <- rep(c(0.20, 0.45), each = 35L, length.out = n)
  data.frame(
    symbol = "TEST",
    session_date = dates,
    open = close * exp(0.002 * cos(seq_len(n) / 9)),
    close = close,
    er20 = er20,
    er20_state = ifelse(er20 < 0.30, "RED_SIDEWAYS", "GREEN_TRENDING"),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("attribution contract freezes one 20-session mechanism slice", {
  contract <- rgca_validate_contract()
  testthat::expect_equal(contract$hold_sessions, 20L)
  testthat::expect_equal(contract$inherited$er_cutoff, 0.30)
  testthat::expect_equal(length(contract$rule_ids), 4L)
})

testthat::test_that("four branches use only completed close information", {
  ledger <- rgca_test_ledger()
  contract <- rgca_contract()
  contract$inherited$analysis_start <- ledger$session_date[[100L]]
  contract$inherited$analysis_end <- max(ledger$session_date)
  candidates <- rgca_construct_candidates(ledger, contract)
  testthat::expect_true(any(candidates$sideways_positive_signal))
  testthat::expect_true(any(candidates$sideways_negative_signal))
  testthat::expect_true(any(candidates$trending_all_signal))
  testthat::expect_true(all(
    candidates$prior_20_log_return[candidates$sideways_positive_signal] > 0
  ))
  testthat::expect_true(all(
    candidates$prior_20_log_return[candidates$sideways_negative_signal] < 0
  ))
  testthat::expect_true(all(
    candidates$er20_state[candidates$trending_all_signal] == "GREEN_TRENDING"
  ))
})

testthat::test_that("attribution study remains next-open, fixed-exit, and nonoverlapping", {
  ledger <- rgca_test_ledger()
  contract <- rgca_contract()
  contract$inherited$analysis_start <- ledger$session_date[[100L]]
  contract$inherited$analysis_end <- max(ledger$session_date)
  study <- rgca_build_asset_study(ledger, contract)
  testthat::expect_equal(unique(study$trades$hold_sessions), 20L)
  testthat::expect_true(all(
    study$trades$entry_index == study$trades$anchor_index + 1L
  ))
  testthat::expect_true(all(
    study$trades$exit_index == study$trades$entry_index + 20L
  ))
  for (x in split(study$trades, study$trades$rule_id)) {
    x <- x[order(x$anchor_index), ]
    testthat::expect_true(
      nrow(x) < 2L || all(x$anchor_index[-1L] >= x$exit_index[-nrow(x)])
    )
  }
})

testthat::test_that("summaries preserve all branches and paired contrasts", {
  ledger <- rgca_test_ledger()
  contract <- rgca_contract()
  contract$inherited$analysis_start <- ledger$session_date[[100L]]
  contract$inherited$analysis_end <- max(ledger$session_date)
  study <- rgca_build_asset_study(ledger, contract)
  summary <- rgca_rule_summary(study$trades, contract)
  testthat::expect_equal(summary$rule_id, contract$rule_ids)
  summary$symbol <- "TEST"
  summary$sector <- "Test Sector"
  grouped <- rgca_group_rule_summary(summary, "sector")
  equal_sector <- rgca_equal_sector_summary(grouped)
  pooled <- rgca_event_pooled_summary(study$trades, contract)
  contrasts <- rgca_pairwise_readout(equal_sector, pooled)
  testthat::expect_equal(nrow(grouped), 4L)
  testthat::expect_equal(nrow(equal_sector), 4L)
  testthat::expect_equal(nrow(pooled), 4L)
  testthat::expect_equal(nrow(contrasts), 3L)
})
