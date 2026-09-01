source(testthat::test_path("..", "..", "R", "hyp_nvda_daily_proto_rules.R"))

nvpr_fixture <- function(n = 90L) {
  dates <- seq.Date(as.Date("2023-01-02"), by = "day", length.out = n)
  close <- 100 * exp(seq(0, 0.40, length.out = n))
  data.frame(
    symbol = "NVDA",
    session_date = dates,
    open = close * 0.999,
    high = close * 1.01,
    low = close * 0.99,
    close = close,
    er20 = rep(0.40, n),
    er20_state = rep("GREEN_TRENDING", n),
    atrp_state = rep("LOW", n),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("candidate construction uses close-t information and a 20-open holding interval", {
  ledger <- nvpr_fixture()
  candidates <- nvpr_construct_candidates(ledger)
  first <- candidates[1L, ]
  testthat::expect_equal(first$anchor_index, 21L)
  testthat::expect_equal(first$entry_index, 22L)
  testthat::expect_equal(first$exit_index, 42L)
  testthat::expect_equal(first$prior_20_log_return, log(ledger$close[21L] / ledger$close[1L]))
  testthat::expect_equal(first$gross_open_log_return, log(ledger$open[42L] / ledger$open[22L]))
  testthat::expect_equal(first$net_open_log_return, first$gross_open_log_return - 0.001)
})

testthat::test_that("the two primary signals implement the frozen state and sign definitions", {
  ledger <- nvpr_fixture()
  ledger$close[1:21] <- exp(seq(log(120), log(100), length.out = 21L))
  ledger$open <- ledger$close * 0.999
  candidates <- nvpr_construct_candidates(ledger)
  first <- candidates[1L, ]
  testthat::expect_true(first$negative_r20_signal)
  testthat::expect_true(first$not_high_atr_state_signal)
  testthat::expect_true(first$not_high_atr_loss_rebound_signal)
  testthat::expect_false(first$efficient_up_continuation_signal)

  ledger$close[1:21] <- exp(seq(log(100), log(120), length.out = 21L))
  ledger$open <- ledger$close * 0.999
  candidates <- nvpr_construct_candidates(ledger)
  first <- candidates[1L, ]
  testthat::expect_true(first$positive_r20_signal)
  testthat::expect_true(first$efficient_state_signal)
  testthat::expect_true(first$efficient_up_continuation_signal)
  testthat::expect_false(first$not_high_atr_loss_rebound_signal)
})

testthat::test_that("non-overlap prevents a new entry before the prior exit", {
  ledger <- nvpr_fixture()
  candidates <- nvpr_construct_candidates(ledger)
  selected <- nvpr_select_nonoverlapping(
    candidates, "efficient_up_continuation_signal", "EFFICIENT_UP_CONTINUATION"
  )
  testthat::expect_true(nrow(selected) >= 2L)
  testthat::expect_true(all(selected$anchor_index[-1L] >= selected$exit_index[-nrow(selected)]))
  testthat::expect_true(all(selected$entry_index[-1L] > selected$exit_index[-nrow(selected)]))
})

testthat::test_that("post-2023 outcomes cannot enter the construction", {
  contract <- nvpr_contract()
  contract$analysis_end <- as.Date("2024-01-02")
  testthat::expect_error(nvpr_validate_contract(contract), "TRAIN boundary")
})

testthat::test_that("confirmation contract is one rule, one fixed window, and one fixed gate", {
  contract <- nvpr_confirmation_contract()
  testthat::expect_equal(contract$analysis_start, as.Date("2024-01-02"))
  testthat::expect_equal(contract$analysis_end, as.Date("2026-06-23"))
  testthat::expect_identical(contract$primary_rules, "NOT_HIGH_ATR_LOSS_REBOUND")
  testthat::expect_identical(contract$minimum_confirmation_trades, 10L)
  changed <- contract
  changed$analysis_end <- as.Date("2026-06-24")
  testthat::expect_error(nvpr_validate_contract(changed), "confirmation contract")
})

testthat::test_that("confirmation gate requires every frozen criterion", {
  contract <- nvpr_confirmation_contract()
  summary <- data.frame(
    rule_family = rep("NOT_HIGH_ATR_LOSS_REBOUND", 4L),
    rule_id = contract$rule_ids,
    primary_rule = c(TRUE, FALSE, FALSE, FALSE),
    trades = c(12L, 15L, 18L, 17L),
    mean_net_open_log_return = c(0.06, 0.02, 0.04, 0.03),
    median_net_open_log_return = c(0.05, 0.01, 0.02, 0.02),
    probability_profitable_net = c(0.60, 0.53, 0.55, 0.52),
    mean_net_excess_vs_unconditional = c(0.03, -0.01, 0.01, 0.00),
    stringsAsFactors = FALSE
  )
  passed <- nvpr_confirmation_gate(summary, contract)
  testthat::expect_identical(passed$verdict, "CONFIRMED_ON_FROZEN_OOS")
  summary$mean_net_open_log_return[[1L]] <- 0.035
  stopped <- nvpr_confirmation_gate(summary, contract)
  testthat::expect_identical(stopped$verdict, "STOP_CONFIRMATION_GATES_FAILED")
  testthat::expect_false(stopped$checks$passed[stopped$checks$gate_id == "mean_beats_each_ingredient_control"])
})
