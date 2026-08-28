source(testthat::test_path("..", "..", "R", "return_geometry_applicability_feature_atlas.R"))

make_rgafa_ledger <- function(symbol = "AAA", n = 220L, multiplier = 1) {
  close <- exp(seq(log(100), log(140), length.out = n))
  data.frame(
    symbol = symbol,
    session_date = as.Date("2020-01-01") + seq_len(n) - 1L,
    open = close * 0.999,
    close = close,
    volume = multiplier * seq(1e6, 1.4e6, length.out = n),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("own features use the event window and pre-event history only", {
  ledger <- make_rgafa_ledger(n = 220L)
  ledger$volume[201:220] <- ledger$volume[201:220] * 2
  features <- rgafa_own_features(ledger, 220L)
  testthat::expect_gt(features$abnormal_dollar_volume, log(1.5))
  testthat::expect_true(is.finite(features$price_impact_shock))
  testthat::expect_true(is.finite(features$pre_shock_normalized_trend))

  altered <- rbind(ledger, data.frame(
    symbol = rep("AAA", 10),
    session_date = max(ledger$session_date) + 1:10,
    open = rep(9999, 10), close = rep(9999, 10), volume = rep(1, 10),
    stringsAsFactors = FALSE
  ))
  testthat::expect_equal(rgafa_own_features(altered, 220L), features)
})

testthat::test_that("peer features exclude the focal asset", {
  registry <- data.frame(
    symbol = LETTERS[1:7], sector = "One", sector_balance_eligible = TRUE,
    stringsAsFactors = FALSE
  )
  panel <- data.frame(
    symbol = LETTERS[1:7], session_date = as.Date("2022-01-31"),
    prior_20_log_return = c(-0.20, rep(-0.05, 5), 0.02), stringsAsFactors = FALSE
  )
  result <- rgafa_peer_features("A", as.Date("2022-01-31"), "One", panel, registry)
  testthat::expect_equal(result$sector_peer_count, 6)
  testthat::expect_equal(result$sector_peer_prior_20_return, mean(c(rep(-0.05, 5), 0.02)))
  testthat::expect_equal(result$peer_negative_breadth, 5 / 6)
  testthat::expect_equal(result$sector_relative_loss,
    -0.20 - mean(c(rep(-0.05, 5), 0.02)))
})

testthat::test_that("market volatility percentile excludes the current observation", {
  x <- c(rep(1, 252), 100)
  pct <- rgafa_causal_percentile(x, history = 504L, minimum = 252L)
  testthat::expect_true(is.na(pct$percentile[[252]]))
  testthat::expect_equal(pct$percentile[[253]], 1)
  testthat::expect_equal(pct$history_observations[[253]], 252)
})

testthat::test_that("asset-balanced profiles do not let prolific assets dominate", {
  events <- data.frame(
    symbol = c(rep("A", 10), "B", "C"),
    feature = c(rep(c(0, 1), each = 5), 0, 1),
    net_excess_vs_unconditional = c(rep(0.10, 5), rep(-0.10, 5), -0.30, 0.30),
    stringsAsFactors = FALSE
  )
  profile <- rgafa_binned_profile(events, "feature", bins = 2L)
  testthat::expect_equal(nrow(profile), 2)
  testthat::expect_false(isTRUE(all.equal(
    profile$event_pooled_mean_excess,
    profile$asset_balanced_mean_excess
  )))
})

testthat::test_that("contract keeps post-2023 outcomes sealed", {
  contract <- rgafa_contract()
  contract$analysis_end <- as.Date("2024-01-02")
  testthat::expect_error(rgafa_validate_contract(contract), "Post-2023 outcomes are sealed")
})
