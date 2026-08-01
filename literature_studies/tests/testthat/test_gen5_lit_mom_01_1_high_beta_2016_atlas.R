source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_1_interday_momentum_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_1_stock_atlas.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_1_high_beta_2016_atlas.R"
))

high_beta_registry <- function() {
  utils::read.csv(
    testthat::test_path(
      "..", "..", "registries",
      "gen5_lit_mom_01_1_stock_atlas_02_high_beta_2016_registry.csv"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

testthat::test_that("high-beta registry exactly reproduces the 2016 filing panel", {
  checked <- g5_mom_high_beta_validate_registry(high_beta_registry())
  testthat::expect_equal(nrow(checked$registry), 99L)
  testthat::expect_equal(
    as.integer(table(checked$registry$sector)[
      names(g5_mom_high_beta_expected_sector_counts())
    ]),
    as.integer(g5_mom_high_beta_expected_sector_counts())
  )
  testthat::expect_true(all(checked$checks$passed))
})

testthat::test_that("high-beta registry validation rejects retrospective deletion", {
  registry <- high_beta_registry()
  testthat::expect_error(
    g5_mom_high_beta_validate_registry(registry[-1L, , drop = FALSE]),
    "row_count_99"
  )
})

testthat::test_that("the frozen strategy accepts only named replication lanes", {
  contract <- g5_mom01_replication_contract(
    "NFLX", "STOCK_ATLAS_02_HIGH_BETA_2016"
  )
  testthat::expect_equal(contract$symbol, "NFLX")
  testthat::expect_error(
    g5_mom01_replication_contract("NFLX", "OUTCOME_MINED_BATCH"),
    "Unknown LIT-MOM-01.1 replication batch"
  )
})

testthat::test_that("pre-TRAIN beta is computed only from dates before TRAIN", {
  dates <- as.Date("2016-01-04") + 0:29
  market_returns <- rep(c(0.01, -0.005, 0.007), length.out = length(dates) - 1L)
  stock_returns <- 2 * market_returns
  market_close <- 100 * exp(c(0, cumsum(market_returns)))
  stock_close <- 50 * exp(c(0, cumsum(stock_returns)))
  bars <- rbind(
    data.frame(symbol = "SPY", session_date = dates, close = market_close),
    data.frame(symbol = "NFLX", session_date = dates, close = stock_close)
  )
  beta <- g5_mom_high_beta_pretrain_beta(
    bars, "NFLX", g5_mom01_contract()
  )
  testthat::expect_equal(unname(beta[["observations"]]), 29)
  testthat::expect_equal(unname(beta[["beta"]]), 2, tolerance = 1e-10)
})

testthat::test_that("coverage audit rejects a truncated SPY reference window", {
  bars <- data.frame(
    symbol = c("SPY", "NFLX"),
    session_date = as.Date(c("2016-01-04", "2016-01-04")),
    close = c(100, 50),
    stringsAsFactors = FALSE
  )
  registry <- data.frame(symbol = "NFLX", stringsAsFactors = FALSE)
  testthat::expect_error(
    g5_mom_high_beta_coverage_audit(bars, registry, g5_mom01_contract()),
    "SPY does not cover"
  )
})
