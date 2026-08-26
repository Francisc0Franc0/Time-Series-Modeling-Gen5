source(file.path("..", "..", "R", "tsla_signed_er20_direction.R"))
source(file.path("..", "..", "R", "tsla_signed_er20_grid.R"))
source(file.path("..", "..", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path("..", "..", "R", "own_asset_return_geometry_atlas.R"))

testthat::test_that("atlas registry is exact and balanced", {
  registry <- oarga_expected_registry()
  validated <- oarga_validate_registry(registry)
  testthat::expect_equal(nrow(validated), 30L)
  testthat::expect_equal(as.integer(table(validated$behavior_group)), rep(5L, 6L))
  testthat::expect_equal(validated$symbol[1:5], c("TSLA", "AMD", "NVDA", "GME", "AMC"))
})

testthat::test_that("ledger and surface are causal and complete", {
  n <- 700L
  dates <- seq.Date(as.Date("2016-01-04"), by = "day", length.out = 1000L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- exp(cumsum(0.0004 + 0.012 * sin(seq_len(n) / 11))) * 20
  bars <- data.frame(
    symbol = "TSLA", session_date = dates, open = close * 0.995,
    high = close * 1.02, low = close * 0.98, close = close,
    volume = 1e6, adjusted = TRUE, timeframe = "1D",
    stringsAsFactors = FALSE
  )
  contract <- oarga_contract()
  contract$analysis_end <- max(dates)
  ledger <- oarga_build_ledger(bars, "TSLA", contract)
  testthat::expect_true(all(c("er20_state", "signed_er20_state", "atrp_state") %in% names(ledger)))
  surface <- oarga_construct_surface(ledger, 5L, 10L, contract)
  testthat::expect_true(all(surface$forward_end_session > surface$anchor_session))
  testthat::expect_equal(
    surface$prior_cumulative_log_return[[1L]],
    log(ledger$close[match(surface$anchor_session[[1L]], ledger$session_date)] /
      ledger$close[match(surface$anchor_session[[1L]], ledger$session_date) - 5L])
  )
})

testthat::test_that("descriptive measurements report sparse branches honestly", {
  surface <- data.frame(
    prior_cumulative_log_return = c(rep(-0.1, 10L), seq(0.01, 0.4, length.out = 40L)),
    forward_cumulative_log_return = seq(-0.2, 0.3, length.out = 50L),
    state = "X"
  )
  sign <- oarga_describe_sign(surface, "X", "state", 30L)
  testthat::expect_equal(sign$estimation_status, "STRUCTURALLY_OR_EMPIRICALLY_SPARSE_BRANCH")
  testthat::expect_equal(sign$minimum_branch_observations, 10L)
  testthat::expect_true(is.na(sign$positive_minus_negative_pearson))
})

testthat::test_that("condition specification freezes the complete microscope", {
  specs <- oarga_condition_specs()
  testthat::expect_equal(names(specs), c("UNFILTERED", "ER20", "ATRP", "SIGNED_ER20"))
  testthat::expect_equal(sum(vapply(specs, function(x) length(x$states), integer(1))), 9L)
  testthat::expect_equal(sum(vapply(specs, function(x) length(x$pairs), integer(1))), 7L)
})
