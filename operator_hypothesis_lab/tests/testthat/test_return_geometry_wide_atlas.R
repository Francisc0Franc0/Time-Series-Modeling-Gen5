source(file.path("..", "..", "R", "tsla_signed_er20_direction.R"))
source(file.path("..", "..", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path("..", "..", "R", "own_asset_return_geometry_atlas.R"))
source(file.path("..", "..", "R", "return_geometry_wide_atlas.R"))

testthat::test_that("wide atlas identities, cohorts, and sectors are frozen", {
  registry <- utils::read.csv(
    file.path("..", "..", "registries", "return_geometry_wide_atlas.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  validated <- rgwa_validate_registry(registry)
  testthat::expect_equal(nrow(validated), 129L)
  testthat::expect_equal(sum(validated$sector_balance_eligible), 88L)
  testthat::expect_equal(length(unique(validated$sector[validated$sector_balance_eligible])), 11L)
  testthat::expect_equal(
    as.integer(table(validated$sector[validated$sector_balance_eligible])),
    rep(8L, 11L)
  )
  testthat::expect_false(any(validated$sector_balance_eligible[validated$atlas_cohort != "GICS_CORE"]))
})

testthat::test_that("coarse horizon contract stops at 100", {
  testthat::expect_equal(rgwa_contract()$horizons, c(20L, 25L, 30L, 35L, 40L, 50L, 75L, 100L))
})

testthat::test_that("partial-history ledgers remain causal and analyzable", {
  n <- 600L
  dates <- seq.Date(as.Date("2020-09-01"), by = "day", length.out = 900L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- exp(cumsum(0.0003 + 0.01 * sin(seq_len(n) / 13))) * 20
  bars <- data.frame(
    symbol = "PLTR", session_date = dates, open = close * 0.995,
    high = close * 1.02, low = close * 0.98, close = close,
    volume = 1e6, adjusted = TRUE, timeframe = "1D",
    stringsAsFactors = FALSE
  )
  contract <- rgwa_contract()
  contract$analysis_end <- max(dates)
  ledger <- rgwa_build_ledger(bars, "PLTR", contract)
  testthat::expect_equal(min(ledger$session_date), min(dates))
  testthat::expect_true(all(c("signed_er20_state", "atrp_state") %in% names(ledger)))
  surface <- oarga_construct_surface(ledger, 100L, 100L, contract)
  testthat::expect_true(all(surface$forward_end_session > surface$anchor_session))
  contract$horizons <- c(20L, 100L)
  measured <- rgwa_measure_asset(ledger, contract)
  testthat::expect_equal(nrow(measured), 2L * 2L * 9L)
  testthat::expect_false(any(is.na(measured$condition)))
})

testthat::test_that("equal-sector aggregation weights sector summaries equally", {
  sectors <- paste0("S", seq_len(11L))
  x <- data.frame(
    sector = sectors,
    condition = "SIGNED_ER20",
    state = "DOWN_TREND",
    state_label = "Signed ER20 down",
    state_order = 9L,
    prior_sessions = 20L,
    forward_sessions = 20L,
    median_negative_pearson = seq(-0.30, -0.10, length.out = 11L),
    stringsAsFactors = FALSE
  )
  out <- rgwa_sector_balanced_summary(x)
  testthat::expect_equal(out$described_sectors, 11L)
  testthat::expect_equal(out$equal_sector_mean_negative_pearson, mean(x$median_negative_pearson))
  testthat::expect_equal(out$equal_sector_median_negative_pearson, stats::median(x$median_negative_pearson))
})
