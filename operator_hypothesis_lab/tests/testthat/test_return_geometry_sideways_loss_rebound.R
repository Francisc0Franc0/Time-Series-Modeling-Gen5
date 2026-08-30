source(file.path("..", "..", "R", "return_geometry_continuation_next_open_rule.R"))
source(file.path("..", "..", "R", "return_geometry_continuation_20d_attribution.R"))
source(file.path("..", "..", "R", "return_geometry_sideways_loss_rebound.R"))

rgsr_test_ledger <- function(n = 420L) {
  dates <- seq.Date(as.Date("2016-01-04"), by = "day", length.out = 700L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- exp(log(100) + 0.0004 * seq_len(n) + 0.10 * sin(seq_len(n) / 11))
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

testthat::test_that("sideways-loss rebound contract is distinct and frozen", {
  contract <- rgsr_validate_contract()
  testthat::expect_equal(contract$primary_rule_id, "SIDEWAYS_NEGATIVE")
  testthat::expect_equal(contract$hold_sessions, 20L)
  testthat::expect_equal(contract$rule_ids, c(
    "SIDEWAYS_NEGATIVE", "NEGATIVE_ALL", "TRENDING_NEGATIVE", "SIDEWAYS_ALL"
  ))
})

testthat::test_that("matched controls separate negative return from ER20 state", {
  ledger <- rgsr_test_ledger()
  contract <- rgsr_contract()
  contract$inherited$inherited$analysis_start <- ledger$session_date[[100L]]
  contract$inherited$inherited$analysis_end <- max(ledger$session_date)
  candidates <- rgsr_construct_candidates(ledger, contract)
  testthat::expect_true(any(candidates$sideways_negative_signal))
  testthat::expect_true(any(candidates$trending_negative_signal))
  testthat::expect_true(all(
    candidates$prior_20_log_return[candidates$negative_all_signal] < 0
  ))
  testthat::expect_true(all(
    candidates$er20_state[candidates$trending_negative_signal] == "GREEN_TRENDING"
  ))
})

testthat::test_that("new slice preserves next-open timing and nonoverlap", {
  ledger <- rgsr_test_ledger()
  contract <- rgsr_contract()
  contract$inherited$inherited$analysis_start <- ledger$session_date[[100L]]
  contract$inherited$inherited$analysis_end <- max(ledger$session_date)
  study <- rgsr_build_asset_study(ledger, contract)
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

testthat::test_that("direct readout compares the primary with all three controls", {
  equal_sector <- data.frame(
    rule_id = rgsr_contract()$rule_ids,
    equal_sector_median_asset_mean_net_log_return = c(0.02, 0.01, 0.005, 0.015)
  )
  pooled <- data.frame(
    rule_id = rgsr_contract()$rule_ids,
    mean_net_open_log_return = c(0.018, 0.012, 0.004, 0.014)
  )
  readout <- rgsr_direct_readout(equal_sector, pooled)
  testthat::expect_equal(nrow(readout), 3L)
  testthat::expect_true(all(readout$equal_sector_net_difference > 0))
  testthat::expect_true(all(readout$event_pooled_net_difference > 0))
})

testthat::test_that("calendar summary is explicit and year-bounded", {
  trades <- data.frame(
    symbol = c("A", "B", "A"),
    entry_session = as.Date(c("2019-01-03", "2019-02-03", "2020-01-03")),
    rule_id = c("SIDEWAYS_NEGATIVE", "SIDEWAYS_NEGATIVE", "NEGATIVE_ALL"),
    net_open_log_return = c(0.01, -0.01, 0.02),
    net_excess_vs_unconditional = c(0.005, -0.005, 0.01)
  )
  out <- rgsr_calendar_summary(trades)
  testthat::expect_equal(sort(unique(out$entry_year)), c(2019L, 2020L))
  testthat::expect_equal(sum(out$trades), 3L)
})
