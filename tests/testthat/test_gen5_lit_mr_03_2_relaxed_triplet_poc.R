source(testthat::test_path("..", "..", "R", "gen5_lit_mr_03_1_triplet_poc.R"))
source(testthat::test_path("..", "..", "R", "gen5_lit_mr_03_2_relaxed_triplet_poc.R"))

mr032_fake_result <- function() {
  directions <- rep(c(1L, -1L), each = 12L)
  list(
    trades = data.frame(
      completed = TRUE,
      direction = directions,
      primary_net_additive_return = rep(0.02, 24L)
    ),
    trade_bootstrap = list(
      draws = data.frame(mean_primary_net_trade_return = rep(0.01, 100L))
    ),
    convergence_bootstrap = list(
      summary = data.frame(correlation = -0.20),
      draws = data.frame(correlation = rep(-0.10, 100L))
    ),
    integrity = data.frame(status = rep("PASS", 13L)),
    adf = data.frame(
      symbol = c("AAA", "BBB", "CCC"),
      level_adf_t = c(0, 0, 0),
      difference_adf_t = c(-5, -5, -5)
    ),
    johansen_bootstrap = list(
      summary = data.frame(
        rank_one = TRUE,
        p_rank_0 = 0.01,
        p_rank_at_most_1 = 0.50
      )
    ),
    stability = list(cosine = 0.80),
    summary = data.frame(spread_half_life = 90)
  )
}

testthat::test_that("03.2 registries are finite, categorized, and frozen", {
  retro <- g5_mr032_retrospective_registry()
  fresh <- g5_mr032_fresh_registry()
  testthat::expect_equal(nrow(retro), 36L)
  testthat::expect_equal(nrow(fresh), 20L)
  testthat::expect_equal(as.integer(table(fresh$triplet_category)), rep(4L, 5L))
  testthat::expect_equal(fresh$triplet_id[[1L]], "F01_VTI_SCHB_ITOT")
  testthat::expect_equal(fresh$triplet_id[[20L]], "F20_UNP_CSX_NSC")
})

testthat::test_that("03.2 fresh registry mutation fails loudly", {
  fresh <- g5_mr032_fresh_registry()
  fresh$symbol_3[[1L]] <- "SPY"
  testthat::expect_error(
    g5_mr032_validate_registry(fresh, "FRESH_ATLAS_01"),
    "frozen FRESH_ATLAS_01 triplet registry changed"
  )
})

testthat::test_that("03.2 boundary thresholds are inclusive and mandatory", {
  result <- mr032_fake_result()
  gates <- g5_mr032_relaxed_gates(result)
  testthat::expect_true(all(gates$status == "PASS"))
  result$stability$cosine <- 0.799
  gates <- g5_mr032_relaxed_gates(result)
  testthat::expect_equal(gates$status[gates$gate_id == "R4"], "FAIL")
  result <- mr032_fake_result()
  result$summary$spread_half_life <- 90.01
  gates <- g5_mr032_relaxed_gates(result)
  testthat::expect_equal(gates$status[gates$gate_id == "R5"], "FAIL")
})

testthat::test_that("03.2 source contains no implicit current-date call", {
  path <- testthat::test_path(
    "..", "..", "R", "gen5_lit_mr_03_2_relaxed_triplet_poc.R"
  )
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
