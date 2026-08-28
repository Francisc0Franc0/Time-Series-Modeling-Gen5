source(testthat::test_path("..", "..", "R", "return_geometry_applicability_feature_atlas.R"))
source(testthat::test_path("..", "..", "R", "return_geometry_abnormal_volume_veto.R"))

make_veto_ledger <- function(n = 900L, symbol = "AAA") {
  data.frame(
    symbol = symbol,
    session_date = as.Date("2010-01-01") + seq_len(n),
    open = 100 * exp(seq_len(n) * 0.0002),
    close = 100 * exp(seq_len(n) * 0.0002),
    volume = 1000000 * (1 + (seq_len(n) %% 17L) / 100),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("abnormal-volume percentile is causal and deployable", {
  ledger <- make_veto_ledger()
  original <- rgavv_daily_abnormal_volume(ledger)
  changed <- ledger
  changed$volume[850:900] <- changed$volume[850:900] * 100
  revised <- rgavv_daily_abnormal_volume(changed)

  testthat::expect_equal(
    original$abnormal_volume_causal_percentile[1:849],
    revised$abnormal_volume_causal_percentile[1:849]
  )
  testthat::expect_true(all(
    original$abnormal_volume_history_observations[is.finite(
      original$abnormal_volume_causal_percentile
    )] >= 252L
  ))
})

testthat::test_that("veto threshold is frozen at the top forty percent", {
  contract <- rgavv_contract()
  testthat::expect_equal(contract$veto_percentile, 0.60)
  panel <- data.frame(
    symbol = "AAA", session_date = as.Date("2020-01-01"),
    abnormal_dollar_volume = 0.2,
    abnormal_volume_causal_percentile = 0.60,
    abnormal_volume_history_observations = 300L,
    abnormal_volume_veto = TRUE
  )
  events <- data.frame(
    symbol = "AAA", anchor_session = as.Date("2020-01-01"),
    abnormal_dollar_volume = 0.2
  )
  attached <- rgavv_attach_veto(events, panel)
  testthat::expect_true(attached$abnormal_volume_veto)
  testthat::expect_equal(attached$volume_state, "HIGH_VETO")
})

testthat::test_that("asset and sector contrasts preserve balanced weighting", {
  events <- data.frame(
    symbol = c(rep("A", 6), rep("B", 2)),
    sector = "One",
    abnormal_volume_veto = c(rep(TRUE, 3), rep(FALSE, 3), TRUE, FALSE),
    net_excess_vs_unconditional = c(rep(-0.10, 3), rep(0.10, 3), 0.05, 0.00)
  )
  assets <- rgavv_asset_contrasts(events)
  sectors <- rgavv_sector_contrasts(assets)
  testthat::expect_equal(assets$high_minus_normal[assets$symbol == "A"], -0.20)
  testthat::expect_equal(assets$high_minus_normal[assets$symbol == "B"], 0.05)
  testthat::expect_equal(sectors$mean_asset_contrast, mean(c(-0.20, 0.05)))
  testthat::expect_equal(sectors$negative_asset_breadth, 0.5)
})

testthat::test_that("severity matching ignores outcomes and does not reuse controls", {
  events <- data.frame(
    symbol = rep("A", 4),
    anchor_session = as.Date("2020-01-01") + 0:3,
    prior_20_log_return = c(-0.20, -0.10, -0.19, -0.11),
    abnormal_volume_veto = c(TRUE, TRUE, FALSE, FALSE),
    net_excess_vs_unconditional = c(100, -100, -1, 1)
  )
  pairs <- rgavv_match_severity(events)
  testthat::expect_equal(nrow(pairs), 2L)
  testthat::expect_equal(sort(pairs$normal_anchor_session), sort(events$anchor_session[3:4]))
  testthat::expect_equal(pairs$normal_prior_20_log_return, c(-0.19, -0.11))
})

testthat::test_that("post-2023 data remains sealed", {
  contract <- rgavv_contract()
  contract$analysis_end <- as.Date("2024-01-02")
  testthat::expect_error(rgavv_validate_contract(contract), "sealed")
})
