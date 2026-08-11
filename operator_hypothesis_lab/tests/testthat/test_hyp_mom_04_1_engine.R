library(testthat)

repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_engine.R"))

test_that("coverage can validate an explicitly audited non-122 registry", {
  dates <- as.Date(c("2020-12-30", "2020-12-31"))
  bars <- data.frame(
    symbol = rep("AAA", 2), session_date = dates,
    open = 1, high = 1, low = 1, close = 1, volume = 1,
    stringsAsFactors = FALSE
  )
  registry <- data.frame(instance_id = "AAA_1", symbol = "AAA", sector = "Industrials", cohort = "AUDITED")
  coverage <- h04_coverage(bars, registry, dates, max(dates), expected_registry_count = NULL)
  expect_true(coverage$analysis_eligible)
  expect_error(h04_coverage(bars, registry, dates, max(dates)), "expected 122 identities")
})

test_that("HYP-MOM-04.1 contract freezes windows and features", {
  contract <- h04_validate_contract()
  expect_equal(contract$train_signal_quarters[[1L]], "2017Q1")
  expect_equal(tail(contract$train_signal_quarters, 1L), "2020Q3")
  expect_equal(contract$oos_signal_quarters[[1L]], "2020Q4")
  expect_equal(tail(contract$oos_signal_quarters, 1L), "2023Q3")
  expect_equal(length(contract$feature_names), 6L)
  changed <- contract
  changed$lambdas <- c(0.1, 1)
  expect_error(h04_validate_contract(changed), "Frozen HYP-MOM-04.1 contract changed")
})

test_that("the HYP-MOM-04.1 engine refuses 2024-plus bars", {
  bars <- data.frame(
    symbol = "TEST", session_date = as.Date("2024-01-02"),
    open = 100, high = 101, low = 99, close = 100, volume = 1000,
    stringsAsFactors = FALSE
  )
  expect_error(h04_validate_bars(bars, as.Date("2024-01-02")), "Unqueried 2024\\+ observations")
})

test_that("feature construction never reads post-signal closes", {
  dates <- seq(as.Date("2016-01-01"), by = "day", length.out = 700)
  close <- 100 * exp(seq(0, 0.4, length.out = length(dates)))
  bars <- data.frame(
    symbol = "TEST", session_date = dates, open = close * 0.999,
    high = close * 1.01, low = close * 0.99, close = close, volume = 1e6,
    stringsAsFactors = FALSE
  )
  schedule <- data.frame(
    signal_quarter = "2017Q1", target_quarter = "2017Q2",
    signal_date = dates[[400L]], entry_date = dates[[401L]], exit_date = dates[[460L]],
    stringsAsFactors = FALSE
  )
  identity <- data.frame(instance_id = "T1", symbol = "TEST", sector = "Test",
                         cohort = "TEST", stringsAsFactors = FALSE)
  before <- h04_asset_feature_rows(bars, schedule, identity)
  changed <- bars
  changed$close[401:700] <- changed$close[401:700] * seq(1, 4, length.out = 300)
  changed$open[401:700] <- changed$close[401:700] * 0.999
  changed$high[401:700] <- changed$close[401:700] * 1.01
  changed$low[401:700] <- changed$close[401:700] * 0.99
  after <- h04_asset_feature_rows(changed, schedule, identity)
  feature_fields <- c("momentum12_1", "return126_raw", "slow_slope_atr",
                      "extension20", "volatility_ratio", "high_proximity252")
  expect_equal(before[feature_fields], after[feature_fields], tolerance = 1e-12)
  expect_false(isTRUE(all.equal(before$target_return, after$target_return)))
})

test_that("rank normal scores and quartiles are deterministic", {
  x <- c(10, 20, 20, 40, 50, 60, 70, 80)
  transformed <- h04_rank_normal(x)
  expect_equal(transformed[[2L]], transformed[[3L]])
  expect_equal(order(transformed), order(x))
  expect_equal(as.integer(table(h04_quartile(1:40))), rep(10L, 4L))
})

test_that("ridge penalty shrinks feature coefficients without penalizing intercept", {
  x <- cbind(a = seq(-1, 1, length.out = 100), b = sin(seq(0, 4, length.out = 100)))
  y <- 3 + 2 * x[, "a"] - x[, "b"]
  low <- h04_ridge_fit(x, y, 0.01)
  high <- h04_ridge_fit(x, y, 100)
  expect_lt(sum(abs(high$coefficients)), sum(abs(low$coefficients)))
  expect_equal(low$intercept, 3, tolerance = 1e-4)
})

test_that("failed integrity blocks nomination even with favorable statistics", {
  contract <- h04_contract()
  n_assets <- 40L
  panel <- do.call(rbind, lapply(seq_along(contract$train_signal_quarters), function(q) {
    signal <- seq(-2, 2, length.out = n_assets)
    x <- data.frame(
      symbol = paste0("S", seq_len(n_assets)), sector = rep(c("A", "B", "C", "D"), each = 10),
      signal_quarter = contract$train_signal_quarters[[q]],
      target_quarter = h04_next_quarter(contract$train_signal_quarters[[q]]),
      target_return = 0.02 + signal * 0.01,
      target_relative_return = signal * 0.01,
      stringsAsFactors = FALSE
    )
    for (feature in h04_feature_columns(contract)) x[[feature]] <- signal
    x
  }))
  cv <- h04_cv(panel, contract = contract)
  fit <- h04_fit_final(panel, cv$selected_lambda, contract = contract)
  scored <- h04_score_panel(panel, fit, contract)
  permutation <- data.frame(observed_percentile = 1)
  gates <- h04_train_gates(panel, cv, scored, permutation, FALSE, contract)
  expect_false(gates$nominated)
  expect_false(gates$gates$passed[gates$gates$gate_id == "G1_INTEGRITY"])
})
