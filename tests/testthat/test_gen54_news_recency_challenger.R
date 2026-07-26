source(testthat::test_path("..", "..", "R", "data_contract.R"))
source(testthat::test_path("..", "..", "R", "alpaca_provider.R"))
source(testthat::test_path("..", "..", "R", "alpaca_context_provider.R"))
source(testthat::test_path("..", "..", "R", "gen54_cross_sectional_poc.R"))
source(testthat::test_path("..", "..", "R", "gen54_news_admissibility.R"))
source(testthat::test_path("..", "..", "R", "gen54_news_risk_measurement.R"))
source(testthat::test_path("..", "..", "R", "gen54_news_nonredundancy.R"))
source(testthat::test_path("..", "..", "R", "gen54_news_recency_challenger.R"))

testthat::test_that("N1D weights availability with the frozen 24-hour half-life", {
  decision <- as.Date("2025-01-02")
  cutoff <- g5_gen54_n1d_cutoff_timestamp(decision)
  updated <- format(
    cutoff - c(0, 24, 48) * 3600,
    tz = "UTC",
    format = "%Y-%m-%dT%H:%M:%SZ"
  )
  articles <- data.frame(
    article_id = paste0("a", 1:3),
    updated_at = updated,
    stringsAsFactors = FALSE
  )
  associations <- data.frame(
    article_id = paste0("a", 1:3),
    issuer_id = "AAPL",
    decision_session = decision,
    exact_title_cluster_id = paste0("title_a", 1:3),
    stringsAsFactors = FALSE
  )
  panel <- data.frame(
    issuer_id = "AAPL",
    decision_session = decision,
    novel_cluster_count = 3L,
    news_log1p = log1p(3),
    stringsAsFactors = FALSE
  )
  out <- g5_gen54_n1d_attach_recency_mass(list(
    panel = panel,
    articles = articles,
    admissible_associations = associations
  ))
  testthat::expect_equal(out$events$age_hours, c(0, 24, 48), tolerance = 1e-8)
  testthat::expect_equal(out$events$recency_weight, c(1, 0.5, 0.25), tolerance = 1e-8)
  testthat::expect_equal(out$panel$recency_mass_24h, 1.75, tolerance = 1e-8)
  testthat::expect_identical(out$panel$recency_cluster_count, 3L)
})

testthat::test_that("N1D rejects alternate half-lives", {
  testthat::expect_error(
    g5_gen54_n1d_attach_recency_mass(
      list(panel = data.frame(), articles = data.frame(), admissible_associations = data.frame()),
      half_life_hours = 12
    ),
    "exactly 24 hours"
  )
})

testthat::test_that("N1D verdict requires absolute and paired confirmation gates", {
  passing <- data.frame(
    fold_id = paste0(rep(2025:2026, c(4, 2)), "Q", c(1:4, 1:2)),
    baseline_partial_spearman = rep(0.05, 6),
    recency_partial_spearman = c(0.08, 0.07, 0.06, 0.04, 0.08, 0.07)
  )
  passing$recency_minus_baseline_partial <-
    passing$recency_partial_spearman - passing$baseline_partial_spearman
  verdict <- g5_gen54_n1d_verdict(passing, integrity_passed = TRUE)
  testthat::expect_true(verdict$passed)
  testthat::expect_equal(verdict$positive_recency_folds, 6L)
  testthat::expect_equal(verdict$positive_improvement_folds, 5L)

  passing$recency_minus_baseline_partial <- rep(0.005, 6)
  passing$recency_partial_spearman <-
    passing$baseline_partial_spearman + passing$recency_minus_baseline_partial
  weak <- g5_gen54_n1d_verdict(passing, integrity_passed = TRUE)
  testthat::expect_false(weak$passed)
  testthat::expect_false(
    weak$gates$passed[
      weak$gates$gate_id ==
        "mean_partial_spearman_improvement_at_least_0_01"
    ]
  )
})

testthat::test_that("N1D timing pairs are selected within equal-count issuer folds", {
  x <- data.frame(
    fold_id = rep("2025Q1", 4),
    issuer_id = rep("AAPL", 4),
    decision_session = as.Date("2025-01-01") + 0:3,
    novel_cluster_count = c(1L, 1L, 2L, 2L),
    recency_mass_24h = c(0.2, 0.9, 0.4, 1.6),
    recency_weighted_mean_age_hours = c(55, 4, 40, 5),
    relative_future_path_volatility_h5 = c(1, 2, 3, 4),
    stringsAsFactors = FALSE
  )
  pairs <- g5_gen54_n1d_representative_timing_pairs(x, maximum_pairs = 2L)
  testthat::expect_equal(nrow(pairs), 2L)
  testthat::expect_true(all(pairs$fresher_recency_mass > pairs$older_recency_mass))
  testthat::expect_true(
    all(pairs$fresher_weighted_mean_age_hours <
      pairs$older_weighted_mean_age_hours)
  )
})
