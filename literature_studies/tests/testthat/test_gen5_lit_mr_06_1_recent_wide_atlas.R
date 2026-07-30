source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_06_1_buy_on_gap_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_06_1_recent_wide_atlas.R"
))

testthat::test_that("recent-wide contract freezes newer partitions", {
  contract <- g5_mr06_recent_wide_contract()
  testthat::expect_equal(contract$atlas_id, "RECENT_WIDE_ATLAS_02")
  testthat::expect_equal(contract$query_start, as.Date("2022-08-01"))
  testthat::expect_equal(contract$train_start, as.Date("2023-01-03"))
  testthat::expect_equal(contract$train_end, as.Date("2024-12-31"))
  testthat::expect_equal(contract$development_start, as.Date("2025-01-02"))
  testthat::expect_equal(contract$development_end, as.Date("2026-06-30"))
  testthat::expect_equal(contract$confirmation_start, as.Date("2026-07-01"))
  testthat::expect_silent(g5_mr06_validate_contract(contract))
})

testthat::test_that("recent-wide registry is the frozen sector union", {
  registry <- g5_mr06_recent_wide_registry()
  parts <- strsplit(registry$symbols, ",", fixed = TRUE)
  testthat::expect_equal(nrow(registry), 12L)
  testthat::expect_equal(length(parts[[1L]]), 305L)
  testthat::expect_identical(
    sort(parts[[1L]]),
    sort(unique(unlist(parts[-1L])))
  )
  testthat::expect_equal(
    lengths(parts[-1L]),
    c(30L, 30L, 21L, 30L, 30L, 30L, 30L, 18L, 30L, 26L, 30L)
  )
  testthat::expect_true(all(registry$benchmark == c(
    "SPY", "XLK", "XLF", "XLE", "XLV", "XLP",
    "XLI", "XLY", "XLC", "XLU", "XLB", "XLRE"
  )))
})

testthat::test_that("recent-wide registry changes fail frozen validation", {
  contract <- g5_mr06_recent_wide_contract()
  changed <- contract
  changed$registry$symbols[[2L]] <- paste0(
    changed$registry$symbols[[2L]], ",FAKE"
  )
  testthat::expect_error(
    g5_mr06_validate_contract(changed),
    "Frozen atlas registry changed"
  )
})
