repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_4_multi_market_predictor_atlas.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_5_path_quality_forecast_comparison.R"
))

testthat::test_that("01.5 contract preserves the frozen forecast comparison", {
  contract <- g5_mom015_validate_contract()
  testthat::expect_identical(contract$literature_id, "LIT-MOM-01.5")
  testthat::expect_identical(contract$lookback_grid, c(5L, 10L, 25L, 60L, 120L, 250L))
  testthat::expect_identical(contract$target_grid, c(5L, 10L, 25L, 60L))
  testthat::expect_equal(length(contract$lookback_grid) * length(contract$target_grid), 24L)
  testthat::expect_identical(contract$model_ids, c("B0_DRIFT", "B1_RAW", "Q2_PATH"))
  testthat::expect_identical(contract$contrast_ids, c("D10", "D21", "D20"))
  testthat::expect_equal(contract$fdr_q, 0.10)
  testthat::expect_equal(contract$bootstrap_count, 10000L)
  testthat::expect_true(contract$query_end < contract$confirmation_start)
  changed <- contract
  changed$fdr_q <- 0.20
  testthat::expect_error(g5_mom015_validate_contract(changed), "contract changed")
})

testthat::test_that("path features separate coherence and shock concentration", {
  smooth_log <- c(0, cumsum(rep(0.01, 10)))
  choppy_steps <- c(0.04, -0.03, 0.04, -0.03, 0.04, -0.03, 0.04, -0.03, 0.04, 0.02)
  shock_steps <- c(0.10, rep(0, 9))
  smooth <- g5_mom015_path_features(exp(smooth_log), 11L, 10L)
  choppy <- g5_mom015_path_features(exp(c(0, cumsum(choppy_steps))), 11L, 10L)
  shock <- g5_mom015_path_features(exp(c(0, cumsum(shock_steps))), 11L, 10L)
  testthat::expect_equal(smooth$raw_return, 0.10, tolerance = 1e-12)
  testthat::expect_equal(smooth$path_efficiency, 1, tolerance = 1e-12)
  testthat::expect_lt(choppy$path_efficiency, smooth$path_efficiency)
  testthat::expect_equal(shock$path_efficiency, 1, tolerance = 1e-12)
  testthat::expect_gt(shock$shock_concentration, smooth$shock_concentration)
  testthat::expect_gt(smooth$coherent_positive, choppy$coherent_positive)
  testthat::expect_gt(shock$shock_positive, smooth$shock_positive)
  flat <- g5_mom015_path_features(rep(100, 11), 11L, 10L)
  testthat::expect_equal(flat$path_efficiency, 0)
  testthat::expect_equal(flat$shock_concentration, 0)
})

testthat::test_that("period panel is causal and uses common anchors", {
  contract <- g5_mom015_contract()
  dates <- seq(as.Date("2016-01-01"), by = "day", length.out = 3200)
  close <- 100 * exp(seq_along(dates) * 0.0001)
  bars <- data.frame(
    symbol = "SYN", session_date = dates,
    open = close * 0.999, close = close,
    adjusted = TRUE, timeframe = "1D", stringsAsFactors = FALSE
  )
  panel <- g5_mom015_period_panel(
    bars, contract$train_start, contract$train_end, contract
  )
  testthat::expect_false(is.null(panel))
  testthat::expect_equal(ncol(panel$features$raw_return), 6L)
  testthat::expect_equal(ncol(panel$y), 4L)
  testthat::expect_identical(panel$entry_date, panel$bars$session_date[panel$anchor_index + 1L])
  maximum_exit <- panel$bars$session_date[
    panel$anchor_index + 1L + contract$common_target_sessions
  ]
  testthat::expect_true(all(maximum_exit <= contract$train_end))
  testthat::expect_true(all(panel$anchor_date >= contract$train_start))
})

testthat::test_that("TRAIN-only fits reward a planted path-quality effect", {
  set.seed(1501)
  n_train <- 900L
  n_development <- 700L
  make_features <- function(n) {
    raw <- stats::rnorm(n, 0.01, 0.05)
    coherent <- pmax(raw, 0) * stats::runif(n)
    shock <- pmax(raw, 0) * stats::runif(n)
    list(raw = raw, coherent = coherent, shock = shock)
  }
  train <- make_features(n_train)
  development <- make_features(n_development)
  train_y <- 0.002 + 0.10 * train$raw + 0.80 * train$coherent - 0.70 * train$shock + stats::rnorm(n_train, 0, 0.01)
  development_y <- 0.002 + 0.10 * development$raw + 0.80 * development$coherent - 0.70 * development$shock + stats::rnorm(n_development, 0, 0.01)
  matrix6 <- function(first, n) cbind(first, matrix(stats::rnorm(n * 5L), nrow = n))
  train_panel <- list(
    anchor_date = seq(as.Date("2017-01-01"), by = "day", length.out = n_train),
    features = list(
      raw_return = matrix6(train$raw, n_train),
      path_efficiency = matrix6(stats::runif(n_train), n_train),
      shock_concentration = matrix6(stats::runif(n_train), n_train),
      coherent_positive = matrix6(train$coherent, n_train),
      shock_positive = matrix6(train$shock, n_train)
    ),
    y = cbind(train_y, matrix(stats::rnorm(n_train * 3L), nrow = n_train))
  )
  development_panel <- list(
    anchor_date = seq(as.Date("2021-01-01"), by = "day", length.out = n_development),
    features = list(
      raw_return = matrix6(development$raw, n_development),
      path_efficiency = matrix6(stats::runif(n_development), n_development),
      shock_concentration = matrix6(stats::runif(n_development), n_development),
      coherent_positive = matrix6(development$coherent, n_development),
      shock_positive = matrix6(development$shock, n_development)
    ),
    y = cbind(development_y, matrix(stats::rnorm(n_development * 3L), nrow = n_development))
  )
  result <- g5_mom015_fit_cell(train_panel, development_panel, 1L, 1L)
  metrics <- result$metrics
  mse <- setNames(metrics$development_mse, metrics$model_id)
  testthat::expect_lt(mse[["Q2_PATH"]], mse[["B1_RAW"]])
  testthat::expect_lt(mse[["Q2_PATH"]], mse[["B0_DRIFT"]])
  gamma <- result$coefficients$coefficient[
    result$coefficients$model_id == "Q2_PATH" &
      result$coefficients$feature == "coherent_positive"
  ]
  delta <- result$coefficients$coefficient[
    result$coefficients$model_id == "Q2_PATH" &
      result$coefficients$feature == "shock_positive"
  ]
  testthat::expect_gt(gamma, 0)
  testthat::expect_lt(delta, 0)
  testthat::expect_equal(nrow(result$losses), n_development)
  testthat::expect_equal(nrow(result$moments), 3L)
})

testthat::test_that("stationary mean bootstrap detects persistent improvement", {
  result <- g5_mom015_stationary_mean(
    rep(0.05, 240), seed = 2026082151L,
    draws = 500L, expected_block = 20
  )
  testthat::expect_equal(result$observed_mean_differential, 0.05)
  testthat::expect_gt(result$ci_lower_90, 0)
  testthat::expect_lte(result$centered_null_upper_p, 1 / 501 + 1e-12)
  repeat_result <- g5_mom015_stationary_mean(
    rep(0.05, 240), seed = 2026082151L,
    draws = 500L, expected_block = 20
  )
  testthat::expect_equal(result, repeat_result)
})

testthat::test_that("FDR and decision logic keep SPY reference-only", {
  base_contract <- g5_mom014_contract()
  registry <- g5_mom014_read_registry(repo_root, base_contract)
  registry <- g5_mom015_validate_registry(registry)
  contrast_rows <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
    do.call(rbind, lapply(g5_mom015_contract()$contrast_ids, function(contrast) {
      p <- if (i == 1L) 1e-8 else 0.50
      data.frame(
        analysis_id = registry$analysis_id[[i]],
        symbol = registry$symbol[[i]],
        category = registry$category[[i]],
        analysis_stratum = registry$analysis_stratum[[i]],
        is_spy_reference = registry$is_spy_reference[[i]],
        contrast_id = contrast,
        observed_mean_differential = if (i == 1L) 0.10 else -0.01,
        ci_lower_90 = if (i == 1L) 0.05 else -0.02,
        ci_upper_90 = if (i == 1L) 0.15 else 0.01,
        centered_null_upper_p = p,
        stringsAsFactors = FALSE
      )
    }))
  }))
  adjusted <- g5_mom015_apply_fdr(contrast_rows)
  testthat::expect_true(all(is.na(adjusted$bh_q_value[adjusted$is_spy_reference])))
  first_id <- registry$analysis_id[[1L]]
  testthat::expect_true(all(adjusted$bh_q_value[adjusted$analysis_id == first_id] <= 0.10))
  coefficient_summary <- cbind(
    registry[, c("analysis_id", "symbol", "category", "analysis_stratum", "is_spy_reference")],
    cell_count = 24L, median_gamma = 0.1, positive_gamma_cells = 20L,
    median_delta = -0.1, negative_delta_cells = 20L,
    mechanism_aligned = TRUE
  )
  decisions <- g5_mom015_decisions(adjusted, coefficient_summary, registry)
  testthat::expect_true(decisions$is_path_quality_candidate[[1L]])
  spy <- decisions[decisions$is_spy_reference, , drop = FALSE]
  testthat::expect_false(spy$is_path_quality_candidate)
  testthat::expect_false(spy$raw_beats_drift_clue)
})

testthat::test_that("confirmation and strategy surfaces remain excluded", {
  registry <- g5_mom014_read_registry(repo_root, g5_mom014_contract())
  bars <- data.frame(
    symbol = "SPY",
    session_date = as.Date("2024-01-02"),
    open = 100, close = 101, adjusted = TRUE, timeframe = "1D",
    stringsAsFactors = FALSE
  )
  testthat::expect_error(
    g5_mom015_validate_bars(bars, registry),
    "Confirmation bars entered"
  )
  forbidden <- c("position", "trade", "pnl", "sharpe", "drawdown", "allocation", "leverage")
  exported <- c(
    "cell_metrics", "coefficients", "feature_moments", "anchor_losses",
    "contrasts", "decisions", "candidates", "category_summary"
  )
  testthat::expect_length(intersect(forbidden, exported), 0L)
})
