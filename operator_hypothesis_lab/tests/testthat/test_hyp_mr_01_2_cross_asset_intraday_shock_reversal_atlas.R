repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mr_01_1_qqq_intraday_shock_reversal.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mr_01_2_cross_asset_intraday_shock_reversal_atlas.R"))

hmr012_registry <- function() g5_hmr012_expected_registry()

hmr012_signal_panels <- function(beta = -0.6, seed = 1201L) {
  set.seed(seed)
  registry <- hmr012_registry()
  dates <- seq.Date(as.Date("2017-01-03"), as.Date("2020-12-31"), by = "day")
  panels <- lapply(seq_len(nrow(registry)), function(i) {
    x <- stats::rnorm(length(dates)) + 0.15 * sin(seq_along(dates) / (8 + i %% 5))
    data.frame(
      symbol = registry$symbol[[i]],
      anchor_date = dates - 1L,
      target_date = dates,
      x = x,
      y = beta * x + stats::rnorm(length(x), sd = 0.30),
      stringsAsFactors = FALSE
    )
  })
  names(panels) <- registry$symbol
  panels
}

hmr012_fixture_bars <- function(symbols = c("SPY", "QQQ"), end_date = as.Date("2020-12-31")) {
  dates <- seq.Date(as.Date("2016-01-04"), end_date, by = "day")
  do.call(rbind, lapply(seq_along(symbols), function(j) {
    i <- seq_along(dates)
    open <- (80 + 10 * j) * exp(0.0002 * i + 0.006 * sin(i / (17 + j)))
    intraday <- 0.006 * sin(i / (9 + j)) + 0.002 * cos(i / 5)
    close <- open * exp(intraday)
    data.frame(
      symbol = symbols[[j]], session_date = dates, open = open,
      high = pmax(open, close) * 1.004, low = pmin(open, close) * 0.996,
      close = close, volume = 1e7 * exp(0.1 * sin(i / 23)),
      adjusted = TRUE, timeframe = "1D", stringsAsFactors = FALSE
    )
  }))
}

testthat::test_that("HYP-MR-01.2 freezes 36 assets across nine balanced categories", {
  contract <- g5_hmr012_contract()
  registry <- hmr012_registry()
  testthat::expect_identical(contract$hypothesis_id, "HYP-MR-01.2")
  testthat::expect_identical(contract$parent_hypothesis_id, "HYP-MR-01.1")
  testthat::expect_equal(nrow(registry), 36L)
  testthat::expect_equal(length(unique(registry$category)), 9L)
  testthat::expect_true(all(table(registry$category) == 4L))
  testthat::expect_true("QQQ" %in% registry$symbol)
  changed <- contract
  changed$atr_sessions <- 10L
  testthat::expect_error(g5_hmr012_validate_contract(changed), "Frozen HYP-MR-01.2 contract changed")
})

testthat::test_that("dedicated registry matches the hard-frozen atlas", {
  path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mr_01_2_cross_asset_atlas_registry.csv")
  observed <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  testthat::expect_identical(g5_hmr012_validate_registry(observed), hmr012_registry())
  observed$symbol[[1L]] <- "DIA"
  testthat::expect_error(g5_hmr012_validate_registry(observed), "registry changed")
})

testthat::test_that("atlas panel construction preserves prior-only ATR and common dates", {
  contract <- g5_hmr012_contract()
  registry <- hmr012_registry()[1:2, ]
  contract2 <- contract
  contract2$expected_asset_count <- 2L
  contract2$expected_category_count <- 1L
  contract2$assets_per_category <- 2L
  bars <- hmr012_fixture_bars(registry$symbol)
  first <- g5_hmr012_zone_panel(
    bars, "SPY", contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  testthat::expect_true(all(first$construction$passed))
  testthat::expect_true(all(first$panel$anchor_date < first$panel$target_date))
  testthat::expect_true(all(is.finite(first$panel$x)))
  testthat::expect_error(g5_hmr012_validate_contract(contract2), "contract changed")
})

testthat::test_that("strong cross-asset reversal clears bounded TRAIN shift checks", {
  contract <- g5_hmr012_contract()
  panels <- hmr012_signal_panels(-0.6, 1202L)
  result <- g5_hmr012_run_train_panels(
    panels, hmr012_registry(), contract,
    shift_values = c(60L, 90L, 120L, 180L, 240L, 300L)
  )
  testthat::expect_true(result$atlas_summary$median_beta[[1L]] < 0)
  testthat::expect_equal(result$atlas_summary$negative_beta_fraction[[1L]], 1)
  testthat::expect_equal(result$atlas_summary$positive_asset_fraction[[1L]], 1)
  testthat::expect_true(result$shift_decision$timing_specificity_passed[[1L]])
  testthat::expect_true(all(result$gates$passed))
})

testthat::test_that("continuation-shaped atlas cannot pass reversal breadth", {
  contract <- g5_hmr012_contract()
  panels <- hmr012_signal_panels(0.6, 1203L)
  result <- g5_hmr012_run_train_panels(
    panels, hmr012_registry(), contract,
    shift_values = c(60L, 90L, 120L, 180L, 240L, 300L)
  )
  testthat::expect_true(result$atlas_summary$median_beta[[1L]] > 0)
  testthat::expect_false(result$gates$passed[result$gates$gate_id == "negative_beta_breadth"])
  testthat::expect_false(result$atlas_summary$train_passed[[1L]])
})

testthat::test_that("common shift null preserves one displacement across all assets", {
  panels <- hmr012_signal_panels(-0.4, 1204L)
  shifted <- panels[[1L]]
  shifted$y <- g5_hmr011_rotate(shifted$y, 60L)
  slow <- g5_hmr012_expanding_predictions(shifted)
  slow_relative <- (mean(slow$drift_squared_error) - mean(slow$model_squared_error)) / mean(slow$drift_squared_error)
  testthat::expect_equal(g5_hmr012_shift_asset_stat(panels[[1L]], 60L), slow_relative, tolerance = 1e-12)
  observed <- do.call(rbind, lapply(panels, function(panel) g5_hmr012_asset_train(panel)$summary))
  null <- g5_hmr012_common_shift_null(
    panels, observed, g5_hmr012_contract(), shift_values = c(60L, 61L, 62L)
  )
  testthat::expect_equal(nrow(null$aggregate), 3L)
  testthat::expect_equal(nrow(null$long), 3L * 36L)
  testthat::expect_true(all(table(null$long$shift) == 36L))
})

testthat::test_that("category bootstrap is deterministic", {
  values <- seq(-0.01, 0.03, length.out = 9L)
  first <- g5_hmr012_category_bootstrap(values, g5_hmr012_contract(), 250L)
  second <- g5_hmr012_category_bootstrap(values, g5_hmr012_contract(), 250L)
  testthat::expect_identical(first, second)
  testthat::expect_true(first$probability_positive[[1L]] > 0.5)
})

testthat::test_that("strategy and performance surfaces remain absent", {
  function_text <- paste(deparse(body(g5_hmr012_run_development_panels)), collapse = " ")
  testthat::expect_false(grepl("sharpe|drawdown|pnl|wealth|position|turnover", function_text, ignore.case = TRUE))
})
