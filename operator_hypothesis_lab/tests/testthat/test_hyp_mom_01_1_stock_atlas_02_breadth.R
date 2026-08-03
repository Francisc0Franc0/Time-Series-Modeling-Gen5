source(testthat::test_path(
  "..", "..", "R", "hyp_mom_01_1_two_green_gap_ups.R"
))
source(testthat::test_path(
  "..", "..", "R", "hyp_mom_01_1_diagnostic_atlas.R"
))
source(testthat::test_path(
  "..", "..", "R", "hyp_mom_01_1_stock_atlas_02_breadth.R"
))
test_repo_root <- normalizePath(
  testthat::test_path("..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)

testthat::test_that("breadth contract and registry preserve frozen scope", {
  contract <- hyp_mom011_breadth_validate_contract()
  testthat::expect_identical(contract$registry_rows, 100L)
  registry <- utils::read.csv(
    file.path(
      test_repo_root, "literature_studies", "registries",
      "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"
    ),
    stringsAsFactors = FALSE
  )
  original <- utils::read.csv(
    file.path(
      test_repo_root, "operator_hypothesis_lab", "registries",
      "hyp_mom_01_1_discovery_registry.csv"
    ),
    stringsAsFactors = FALSE
  )
  validated <- hyp_mom011_breadth_validate_registry(
    registry, original$symbol, contract
  )
  testthat::expect_equal(nrow(validated), 100L)
  testthat::expect_length(intersect(validated$symbol, original$symbol), 0L)
  testthat::expect_equal(length(unique(validated$sector)), 11L)
})

testthat::test_that("breadth coverage requires exact discovery and prior history", {
  dates <- seq(as.Date("2019-01-01"), as.Date("2023-12-29"), by = "day")
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5]
  spy <- dates[dates >= as.Date("2021-01-04")]
  registry <- data.frame(
    instance_id = c("A", "B", "C"),
    symbol = c("AAA", "BBB", "CCC"),
    cohort = "DIVERSIFIED_CORE",
    sector = "Test",
    stringsAsFactors = FALSE
  )
  make_bars <- function(symbol, observed) {
    data.frame(
      symbol = symbol,
      session_date = observed,
      open = 100,
      high = 101,
      low = 99,
      close = 100.5,
      volume = 1000000,
      stringsAsFactors = FALSE
    )
  }
  bars <- rbind(
    make_bars("AAA", dates),
    make_bars("BBB", dates[dates != spy[[10L]]]),
    make_bars("CCC", dates[dates >= as.Date("2020-01-01")])
  )
  coverage <- hyp_mom011_breadth_coverage(bars, registry, spy)
  testthat::expect_identical(
    coverage$coverage_status,
    c("ELIGIBLE", "DISCOVERY_INCOMPLETE", "ELIGIBLE")
  )
})

testthat::test_that("panel summary gives assets one row and trades their own count", {
  assets <- data.frame(
    primary_compounded_return = c(0.1, -0.1),
    excess_vs_buy_hold = c(0.02, -0.03),
    observed_random_percentile = c(0.9, 0.2),
    maximum_drawdown = c(-0.1, -0.2)
  )
  trades <- data.frame(primary_trade_return = c(0.1, -0.05, 0.02))
  result <- hyp_mom011_breadth_panel_summary(assets, trades, "TEST")
  testthat::expect_equal(result$asset_count, 2L)
  testthat::expect_equal(result$executed_trade_count, 3L)
  testthat::expect_equal(result$assets_beating_buy_hold, 1L)
  testthat::expect_equal(result$assets_random_percentile_above_80, 1L)
})
