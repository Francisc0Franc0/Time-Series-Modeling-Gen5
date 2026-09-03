testthat::local_edition(3)

source(testthat::test_path("..", "..", "R", "hyp_port_01_1_aggressive_compounding.R"))

port011_synthetic_bars <- function() {
  contract <- g5_port011_contract()
  dates <- seq(contract$query_start, contract$evaluation_end, by = "day")
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5]
  symbols <- g5_port011_required_symbols(contract)
  rows <- lapply(seq_along(symbols), function(i) {
    phase <- seq_along(dates)
    drift <- c(0.00045, 0.00025, 0.0005, 0.0007, 0.0008, 0.00055, 0.0004, 0.0003)[[i]]
    price <- 50 * exp(drift * phase + 0.04 * sin(phase / (23 + i)))
    data.frame(
      symbol = symbols[[i]],
      session_date = dates,
      open = price,
      close = price * exp(0.001 * cos(phase / 7)),
      adjusted = TRUE,
      timeframe = "1D",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

testthat::test_that("frozen portfolio contract preserves the requested comparison", {
  contract <- g5_port011_validate_contract()
  testthat::expect_equal(sum(contract$policy_targets), 1)
  testthat::expect_equal(
    unname(contract$policy_targets),
    c(0.50, 0.20, 0.15, 0.05, 0.05, 0.05)
  )
  testthat::expect_equal(length(contract$variants), 6L)
  testthat::expect_false(contract$historical_lookthrough_caps_tested)
  testthat::expect_false(contract$live_authority_opened)
})

testthat::test_that("synthetic comparison admits and honors next-open timing", {
  contract <- g5_port011_contract()
  result <- g5_port011_run(port011_synthetic_bars(), contract)
  testthat::expect_true(result$admitted)
  testthat::expect_true(all(result$gates$status == "PASS"))
  testthat::expect_equal(sort(unique(result$daily_tape$variant)), sort(contract$variants))
  first <- result$daily_tape[result$daily_tape$interval == 1L, ]
  testthat::expect_true(all(first$decision_date == contract$initial_decision_date))
  testthat::expect_true(all(first$execution_date > first$decision_date))
  testthat::expect_true(all(first$rebalance_trigger == "INITIAL_ALLOCATION"))
  testthat::expect_equal(first$turnover_one_way, rep(1, nrow(first)))
})

testthat::test_that("buy-and-hold controls trade once while the policy restores annually", {
  result <- g5_port011_run(port011_synthetic_bars())
  buy_hold <- setdiff(
    result$contract$variants,
    "AGGRESSIVE_POLICY_BAND_REBALANCE"
  )
  control_metrics <- result$metrics[result$metrics$variant %in% buy_hold, ]
  testthat::expect_true(all(control_metrics$rebalance_events == 1L))
  policy <- result$rebalance_tape
  testthat::expect_true(any(policy$rebalance_trigger == "ANNUAL_RESTORE"))
  target <- result$targets[["AGGRESSIVE_POLICY_BAND_REBALANCE"]]
  first_restore <- policy[policy$rebalance_trigger == "ANNUAL_RESTORE", ][1L, ]
  observed <- unlist(first_restore[paste0("posttrade_weight_", names(target))], use.names = FALSE)
  testthat::expect_equal(observed, unname(target), tolerance = 1e-12)
})

testthat::test_that("contract mutation is rejected", {
  changed <- g5_port011_contract()
  changed$cost_bps_one_way <- 0
  testthat::expect_error(
    g5_port011_validate_contract(changed),
    "Frozen HYP-PORT-01.1 contract changed"
  )
})
