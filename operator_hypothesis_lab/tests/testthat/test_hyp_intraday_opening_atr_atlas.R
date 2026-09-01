source(testthat::test_path("..", "..", "R", "hyp_reg_01_1_atr_percent.R"))
source(testthat::test_path("..", "..", "R", "hyp_intraday_opening_atr_atlas.R"))

testthat::test_that("opening ATR atlas contract is frozen and excludes NVDA", {
  contract <- ioaa_validate_contract()
  testthat::expect_identical(contract$rolling_sessions, 252L)
  testthat::expect_equal(contract$opening_quantile_probability, 0.80)
  testthat::expect_identical(contract$analysis_end, as.Date("2025-12-31"))
  testthat::expect_length(contract$expected_symbols, 26L)
  testthat::expect_false("NVDA" %in% contract$expected_symbols)
  changed <- contract
  changed$analysis_end <- as.Date("2026-01-02")
  testthat::expect_error(ioaa_validate_contract(changed), "contract changed")
})

testthat::test_that("rolling opening threshold is strictly prior", {
  x <- c(1, 2, 3, 4, 100, 6)
  out <- ioaa_rolling_threshold(x, lookback = 4L, probability = 0.50, quantile_type = 8L)
  testthat::expect_true(all(is.na(out[1:4])))
  testthat::expect_equal(out[[5L]], unname(stats::quantile(1:4, 0.50, type = 8)))
  testthat::expect_equal(out[[6L]], unname(stats::quantile(c(2, 3, 4, 100), 0.50, type = 8)))
})

testthat::test_that("era assignment respects frozen calendar boundaries", {
  dates <- as.Date(c("2018-01-02", "2020-12-31", "2021-01-04", "2024-01-02", "2025-12-31"))
  testthat::expect_identical(
    ioaa_assign_era(dates),
    c("2018-2020", "2018-2020", "2021-2023", "2024-2025", "2024-2025")
  )
})

testthat::test_that("mechanism gate requires breadth, era agreement, and nonpositive HIGH tail", {
  contract <- ioaa_contract()
  assets <- data.frame(
    symbol = contract$expected_symbols,
    high_minus_low_med_mean = c(rep(-0.001, 20), rep(0.001, 6)),
    eligible = TRUE,
    stringsAsFactors = FALSE
  )
  eras <- data.frame(
    era = contract$eras$era,
    median_asset_high_minus_low_med = rep(-0.001, 3),
    stringsAsFactors = FALSE
  )
  pooled <- data.frame(
    atr_group = c("LOW_MEDIUM", "HIGH"),
    mean_remainder_log_return = c(0.001, -0.0002),
    stringsAsFactors = FALSE
  )
  passed <- ioaa_mechanism_gate(assets, eras, pooled, contract)
  testthat::expect_true(all(passed$checks$passed))
  testthat::expect_match(passed$verdict, "PASS")
  pooled$mean_remainder_log_return[[2L]] <- 0.0001
  stopped <- ioaa_mechanism_gate(assets, eras, pooled, contract)
  testthat::expect_false(stopped$checks$passed[stopped$checks$gate_id == "pooled_high_atr_tail_nonpositive"])
  testthat::expect_match(stopped$verdict, "STOP")
})

testthat::test_that("registry validator rejects reordered or sealed symbols", {
  contract <- ioaa_contract()
  registry <- data.frame(
    symbol = contract$expected_symbols,
    sector = rep("Sector", length(contract$expected_symbols)),
    asset_type = rep("stock", length(contract$expected_symbols)),
    stringsAsFactors = FALSE
  )
  testthat::expect_equal(nrow(ioaa_validate_registry(registry, contract)), 26L)
  bad <- registry
  bad$symbol[[1L]] <- "NVDA"
  testthat::expect_error(ioaa_validate_registry(bad, contract), "symbols changed")
})
