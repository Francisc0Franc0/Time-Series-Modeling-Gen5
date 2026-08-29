source(file.path("..", "..", "R", "return_geometry_continuation_next_open_rule.R"))

rgcnor_test_ledger <- function(n = 420L) {
  dates <- seq.Date(as.Date("2016-01-04"), by = "day", length.out = 700L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- exp(log(100) + 0.0008 * seq_len(n) + 0.08 * sin(seq_len(n) / 11))
  er20 <- rep(c(0.20, 0.45), each = 35L, length.out = n)
  data.frame(
    symbol = "TEST", session_date = dates,
    open = close * exp(0.002 * cos(seq_len(n) / 7)), close = close,
    er20 = er20,
    er20_state = ifelse(er20 < 0.30, "RED_SIDEWAYS", "GREEN_TRENDING"),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("contract freezes the prior window, ER threshold, and horizon diagnostic", {
  contract <- rgcnor_validate_contract()
  testthat::expect_equal(contract$prior_sessions, 20L)
  testthat::expect_equal(contract$er_cutoff, 0.30)
  testthat::expect_equal(contract$hold_sessions, c(5L, 10L, 20L))
})

testthat::test_that("candidate construction is close-known and next-open executable", {
  ledger <- rgcnor_test_ledger()
  contract <- rgcnor_contract()
  contract$analysis_start <- ledger$session_date[[100L]]
  contract$analysis_end <- max(ledger$session_date)
  candidates <- rgcnor_construct_candidates(ledger, 10L, contract)
  first <- candidates[1L, ]
  testthat::expect_equal(first$entry_index, first$anchor_index + 1L)
  testthat::expect_equal(first$exit_index, first$entry_index + 10L)
  testthat::expect_equal(first$gross_open_log_return,
                         log(ledger$open[[first$exit_index]] / ledger$open[[first$entry_index]]))
})

testthat::test_that("primary and control signals use only the frozen completed state", {
  ledger <- rgcnor_test_ledger()
  contract <- rgcnor_contract()
  contract$analysis_start <- ledger$session_date[[100L]]
  contract$analysis_end <- max(ledger$session_date)
  candidates <- rgcnor_construct_candidates(ledger, 5L, contract)
  primary <- candidates[candidates$sideways_positive_signal, ]
  trending <- candidates[candidates$trending_positive_signal, ]
  testthat::expect_true(nrow(primary) > 0L)
  testthat::expect_true(nrow(trending) > 0L)
  testthat::expect_true(all(primary$prior_20_log_return > 0 & primary$er20_state == "RED_SIDEWAYS"))
  testthat::expect_true(all(trending$prior_20_log_return > 0 & trending$er20_state == "GREEN_TRENDING"))
})

testthat::test_that("nonoverlap blocks a new entry until the prior exit open", {
  candidates <- data.frame(
    anchor_index = 1:30, exit_index = 7:36,
    signal = TRUE, stringsAsFactors = FALSE
  )
  selected <- rgcnor_select_nonoverlapping(candidates, "signal", "TEST")
  testthat::expect_equal(selected$anchor_index, c(1L, 7L, 13L, 19L, 25L))
})

testthat::test_that("net outcomes apply exactly the frozen round-trip cost", {
  ledger <- rgcnor_test_ledger()
  contract <- rgcnor_contract()
  contract$analysis_start <- ledger$session_date[[100L]]
  contract$analysis_end <- max(ledger$session_date)
  candidates <- rgcnor_construct_candidates(ledger, 20L, contract)
  testthat::expect_equal(candidates$gross_open_log_return - candidates$net_open_log_return,
                         rep(0.001, nrow(candidates)))
})

testthat::test_that("trade paths begin at zero and end at the executable return", {
  ledger <- rgcnor_test_ledger()
  contract <- rgcnor_contract()
  contract$analysis_start <- ledger$session_date[[100L]]
  contract$analysis_end <- max(ledger$session_date)
  study <- rgcnor_build_asset_horizon_study(ledger, 10L, contract)
  trades <- study$trades[study$trades$rule_id == "SIDEWAYS_POSITIVE", ]
  paths <- rgcnor_build_trade_paths(ledger, trades[1L, ])
  testthat::expect_equal(paths$cumulative_open_log_return[[1L]], 0)
  testthat::expect_equal(paths$cumulative_open_log_return[[nrow(paths)]],
                         trades$gross_open_log_return[[1L]])
})

testthat::test_that("asset comparison preserves all four frozen rules", {
  ledger <- rgcnor_test_ledger()
  contract <- rgcnor_contract()
  contract$analysis_start <- ledger$session_date[[100L]]
  contract$analysis_end <- max(ledger$session_date)
  study <- rgcnor_build_asset_horizon_study(ledger, 5L, contract)
  summary <- rgcnor_rule_summary(study$trades)
  summary$symbol <- "TEST"
  summary$hold_sessions <- 5L
  comparison <- rgcnor_asset_comparison(summary)
  testthat::expect_equal(nrow(comparison), 1L)
  testthat::expect_true(all(c("primary_minus_trending", "primary_minus_positive_only",
                              "primary_minus_sideways_only") %in% names(comparison)))
})
