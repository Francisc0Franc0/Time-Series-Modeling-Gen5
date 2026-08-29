source(file.path("..", "..", "R", "return_geometry_continuation_state_contrast.R"))

testthat::test_that("continuation contrast contract freezes the existing daily surface", {
  contract <- rgcsc_contract()
  testthat::expect_equal(length(contract$horizons), 15L)
  testthat::expect_equal(contract$expected_cells, 225L)
  testthat::expect_equal(contract$expected_incomplete_pairs, 1L)
  testthat::expect_equal(contract$analysis_end, as.Date("2023-12-29"))
  testthat::expect_equal(contract$branch, "positive_prior")
  testthat::expect_equal(contract$lead_region_horizons, c(5L, 10L, 15L, 20L))
})

testthat::test_that("paired contrast subtracts trending from sideways by asset and cell", {
  base <- expand.grid(
    symbol = c("A", "B"), prior_sessions = 1L, forward_sessions = 1L,
    state = c("RED_SIDEWAYS", "GREEN_TRENDING"), stringsAsFactors = FALSE
  )
  base$condition <- "ER20"
  base$positive_pearson_correlation <- c(0.10, 0.20, -0.10, 0.05)
  base$positive_observations <- 50L
  base$atlas_cohort <- "GICS_CORE"
  base$sector <- c("S1", "S2", "S1", "S2")
  base$sector_balance_eligible <- TRUE
  base$instrument_type <- "Stock"
  base$atlas_order <- match(base$symbol, c("A", "B"))
  out <- rgcsc_prepare_pairs(base, modifyList(rgcsc_contract(), list(expected_assets = 2L)))
  testthat::expect_equal(nrow(out), 2L)
  testthat::expect_equal(out$sideways_minus_trending_pearson[out$symbol == "A"], 0.20)
  testthat::expect_equal(out$sideways_minus_trending_pearson[out$symbol == "B"], 0.15)
  testthat::expect_true(all(out$paired_status == "PAIRED"))
})

testthat::test_that("equal-sector summary gives sectors equal weight", {
  sector <- data.frame(
    sector = c("S1", "S2", "S3"), prior_sessions = 5L, forward_sessions = 5L,
    median_sideways_positive_pearson = c(0.10, 0.20, 0.30),
    median_trending_positive_pearson = c(-0.10, 0.05, 0.10),
    median_sideways_minus_trending_pearson = c(0.20, 0.15, 0.20),
    asset_sideways_advantage_fraction = c(0.75, 0.50, 1.00),
    stringsAsFactors = FALSE
  )
  out <- rgcsc_equal_sector_summary(sector)
  testthat::expect_equal(out$equal_sector_median_sideways_minus_trending_pearson, 0.20)
  testthat::expect_equal(out$sector_sideways_advantage_fraction, 1)
  testthat::expect_equal(out$median_within_sector_asset_advantage_fraction, 0.75)
})
