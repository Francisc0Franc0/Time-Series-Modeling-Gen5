source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_1_interday_momentum_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_1_stock_atlas.R"
))

stock_atlas_registry <- function() {
  utils::read.csv(
    testthat::test_path(
      "..", "..", "registries",
      "gen5_lit_mom_01_1_stock_atlas_01_registry.csv"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

testthat::test_that("stock atlas freezes two unique stocks in every sector", {
  checked <- g5_mom_stock_validate_registry(stock_atlas_registry())
  testthat::expect_equal(nrow(checked$registry), 22L)
  testthat::expect_equal(length(unique(checked$registry$sector)), 11L)
  testthat::expect_true(all(table(checked$registry$sector) == 2L))
  testthat::expect_true(all(checked$checks$passed))
})

testthat::test_that("registry validation rejects outcome-driven deletion", {
  registry <- stock_atlas_registry()
  testthat::expect_error(
    g5_mom_stock_validate_registry(registry[-1L, , drop = FALSE]),
    "row_count_22"
  )
})

testthat::test_that("direction summary retains both long and short rows", {
  sleeves <- data.frame(
    direction_label = c("LONG", "LONG", "SHORT"),
    primary_net_sleeve_return = c(0.01, -0.02, 0.03),
    direction_correct = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  summary <- g5_mom_stock_sleeve_direction_summary(sleeves)
  testthat::expect_equal(summary$direction_label, c("LONG", "SHORT"))
  testthat::expect_equal(summary$sleeve_count, c(2L, 1L))
  testthat::expect_equal(summary$direction_accuracy, c(0.5, 1.0))
})

testthat::test_that("atlas metadata prefix does not duplicate period_id", {
  frame <- data.frame(
    calendar_year = 2021L,
    period_id = "OLD",
    stringsAsFactors = FALSE
  )
  metadata <- data.frame(
    instance_id = "S11_HD",
    symbol = "HD",
    sector = "Consumer Discretionary",
    stringsAsFactors = FALSE
  )
  prefixed <- g5_mom_stock_prefix_frame(frame, metadata, "DEVELOPMENT")
  testthat::expect_equal(sum(names(prefixed) == "period_id"), 1L)
  testthat::expect_equal(prefixed$period_id, "DEVELOPMENT")
})
