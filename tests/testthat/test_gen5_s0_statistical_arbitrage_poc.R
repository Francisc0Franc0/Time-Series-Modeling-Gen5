source(testthat::test_path("..", "..", "R", "gen5_s0_statistical_arbitrage_poc.R"))

testthat::test_that("S0A frozen contract retains the approved universe and controls", {
  contract <- g5_s0_validate_contract(g5_s0_contract())
  testthat::expect_equal(nrow(contract$universe), 37L)
  testthat::expect_equal(
    as.integer(table(contract$universe$economic_group)[
      c("us_sector", "us_size_style", "developed_country", "emerging_country")
    ]),
    c(11L, 8L, 10L, 8L)
  )
  testthat::expect_equal(contract$horizons, c(5L, 10L, 20L))
  testthat::expect_equal(contract$primary_horizon, 10L)
  testthat::expect_equal(contract$random_policy_count, 2000L)
  testthat::expect_equal(contract$as_of_timestamp, "2026-07-24 17:30:00")
})

testthat::test_that("S0A execution is next-open with full round-trip costs", {
  contract <- g5_s0_contract()
  sessions <- seq(as.Date("2025-01-02"), by = "day", length.out = 110L)
  sessions <- sessions[!weekdays(sessions) %in% c("Saturday", "Sunday")]
  make_bars <- function(symbol, close) {
    data.frame(
      symbol = symbol,
      session_date = sessions,
      open = close * 1.001,
      close = close,
      volume = 5e6,
      stringsAsFactors = FALSE
    )
  }
  base <- exp(seq(log(50), log(55), length.out = length(sessions)))
  bars <- rbind(
    make_bars("XLB", base * exp(c(rep(0, 35L), 0.12, rep(0, length(sessions) - 36L)))),
    make_bars("XLC", base)
  )
  fit <- data.frame(
    fold_id = "2025Q1",
    formation_date = as.Date("2024-12-31"),
    oos_start = min(sessions),
    oos_end = max(sessions),
    evaluation_period = "historical_shadow_2025_2026",
    economic_group = "us_sector",
    pair_id = "XLB~XLC",
    symbol_a = "XLB",
    symbol_b = "XLC",
    alpha = 0,
    beta = 1,
    residual_mean = 0,
    residual_sd = 0.02,
    structural_eligible = TRUE,
    selected = TRUE,
    stringsAsFactors = FALSE
  )
  opportunities <- g5_s0_opportunity_table(bars, fit, contract)
  events <- g5_s0_event_table(opportunities, contract)
  testthat::expect_gt(nrow(events), 0L)
  testthat::expect_true(all(events$entry_date > events$signal_date))
  testthat::expect_equal(
    events$entry_session_index - events$signal_session_index,
    rep(1L, nrow(events))
  )
  testthat::expect_equal(
    events$gross_10 - events$net_10_5bp,
    rep(0.001, nrow(events)),
    tolerance = 1e-12
  )
  testthat::expect_equal(
    events$gross_10 - events$net_10_10bp,
    rep(0.002, nrow(events)),
    tolerance = 1e-12
  )
  testthat::expect_equal(
    abs(events$weight_a) + abs(events$weight_b),
    rep(1, nrow(events)),
    tolerance = 1e-12
  )
})

testthat::test_that("S0A embargo permits no pair events less than twenty sessions apart", {
  contract <- g5_s0_contract()
  candidates <- data.frame(
    fold_id = "2025Q1",
    pair_id = "XLB~XLC",
    selected_pair = TRUE,
    signal_session_index = c(10L, 12L, 29L, 30L, 50L),
    endpoint_20_session_index = c(30L, 32L, 49L, 50L, 70L),
    z = c(2.2, 2.5, -2.1, 2.4, -2.3),
    beta = 1,
    return_a_5 = 0, return_b_5 = 0,
    return_a_10 = 0, return_b_10 = 0,
    return_a_20 = 0, return_b_20 = 0,
    stringsAsFactors = FALSE
  )
  events <- g5_s0_event_table(candidates, contract)
  testthat::expect_equal(events$signal_session_index, c(10L, 30L, 50L))
  testthat::expect_true(all(diff(events$signal_session_index) >= 20L))
})

testthat::test_that("S0A integrity audit rejects same-close execution and borrow claims", {
  contract <- g5_s0_contract()
  events <- data.frame(
    fold_id = "2025Q1",
    pair_id = "XLB~XLC",
    signal_date = as.Date("2025-01-02"),
    entry_date = as.Date("2025-01-03"),
    endpoint_5 = as.Date("2025-01-10"),
    endpoint_10 = as.Date("2025-01-17"),
    endpoint_20 = as.Date("2025-01-31"),
    signal_session_index = 1L,
    entry_session_index = 2L,
    endpoint_20_session_index = 22L,
    weight_a = -0.5,
    weight_b = 0.5,
    stringsAsFactors = FALSE
  )
  bars <- data.frame(
    symbol = c("XLB", "XLC"),
    session_date = as.Date(c("2025-01-02", "2025-01-02")),
    adjusted = TRUE,
    stringsAsFactors = FALSE
  )
  pair_fits <- data.frame(
    symbol_a = "XLB",
    symbol_b = "XLC",
    structural_eligible = TRUE,
    selected = TRUE,
    stringsAsFactors = FALSE
  )
  audit <- g5_s0_integrity_audit(bars, pair_fits, events, contract)
  testthat::expect_true(all(audit$status == "PASS"))

  same_close <- events
  same_close$entry_date <- same_close$signal_date
  rejected <- g5_s0_integrity_audit(bars, pair_fits, same_close, contract)
  testthat::expect_equal(
    rejected$status[rejected$check_id == "next_open_execution"],
    "FAIL"
  )

  events$borrow_fee <- 0
  borrow_rejected <- g5_s0_integrity_audit(bars, pair_fits, events, contract)
  testthat::expect_equal(
    borrow_rejected$status[
      borrow_rejected$check_id == "historical_borrow_not_imputed"
    ],
    "FAIL"
  )
})

testthat::test_that("S0A random selection is seeded and enforces disjoint pairs", {
  candidates <- data.frame(
    pair_id = c("A~B", "A~C", "B~C", "C~D", "D~E", "E~F"),
    symbol_a = c("A", "A", "B", "C", "D", "E"),
    symbol_b = c("B", "C", "C", "D", "E", "F"),
    stringsAsFactors = FALSE
  )
  set.seed(5403L)
  first <- g5_s0_random_select_group(candidates, 2L)
  set.seed(5403L)
  second <- g5_s0_random_select_group(candidates, 2L)
  testthat::expect_equal(first, second)
  selected <- candidates[candidates$pair_id %in% first, , drop = FALSE]
  selected_symbols <- c(selected$symbol_a, selected$symbol_b)
  testthat::expect_equal(length(selected_symbols), length(unique(selected_symbols)))
})
