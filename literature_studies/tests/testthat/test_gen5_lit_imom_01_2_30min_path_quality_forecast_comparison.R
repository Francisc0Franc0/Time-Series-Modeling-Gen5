library(testthat)

repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_01_4_multi_market_predictor_atlas.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_01_5_path_quality_forecast_comparison.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_imom_01_2_30min_path_quality_forecast_comparison.R"
))

imom012_synthetic_panel <- function(n, seed = 1L) {
  set.seed(seed)
  slot <- rep(1:13, length.out = n)
  raw <- matrix(stats::rnorm(n * 6L, sd = 0.02), nrow = n)
  coherent <- pmax(raw, 0) * matrix(stats::runif(n * 6L, 0.2, 0.9), nrow = n)
  shock <- pmax(raw, 0) * matrix(stats::runif(n * 6L, 0.03, 0.35), nrow = n)
  y <- matrix(stats::rnorm(n * 4L, sd = 0.015), nrow = n)
  list(
    anchor_timestamp = as.POSIXct("2021-01-04 14:30:00", tz = "UTC") + seq_len(n) * 1800,
    anchor_session = as.Date("2021-01-04") + (seq_len(n) - 1L) %/% 13L,
    anchor_slot = slot,
    clock = g5_imom012_clock_matrix(slot),
    features = list(
      raw_return = raw,
      path_efficiency = matrix(stats::runif(n * 6L), nrow = n),
      shock_concentration = matrix(stats::runif(n * 6L), nrow = n),
      coherent_positive = coherent,
      shock_positive = shock
    ),
    y = y,
    target_crosses_session = matrix(rep(c(FALSE, TRUE), length.out = n * 4L), nrow = n)
  )
}

test_that("frozen contract exposes the approved bar-domain comparison", {
  contract <- g5_imom012_contract()
  expect_equal(contract$literature_id, "LIT-IMOM-01.2")
  expect_equal(contract$lookback_grid, c(5L, 10L, 25L, 60L, 120L, 250L))
  expect_equal(contract$target_grid, c(5L, 10L, 25L, 60L))
  expect_length(contract$model_ids, 6L)
  expect_length(contract$contrast_ids, 6L)
  expect_equal(contract$bootstrap_expected_sessions, 20)
  expect_false(any(contract$query_end >= contract$confirmation_start))
})

test_that("contract mutation fails loudly", {
  changed <- g5_imom012_contract()
  changed$fdr_q <- 0.20
  expect_error(g5_imom012_validate_contract(changed), "Frozen contract changed")
})

test_that("frozen registry creates 22 candidate and four diagnostic rows", {
  registry <- read.csv(
    file.path(repo_root, "operator_hypothesis_lab", "registries", "gen5_intraday_momentum_poc_registry.csv"),
    stringsAsFactors = FALSE
  )
  x <- g5_imom012_validate_registry(registry)
  expect_equal(nrow(x), 26L)
  expect_equal(sum(x$candidate_fdr), 22L)
  expect_setequal(x$symbol[!x$candidate_fdr], c("AMD", "TSLA", "SPY", "QQQ"))
  expect_equal(sum(x$analysis_stratum == "REFERENCE_ETF"), 2L)
})

test_that("clock design is a full-rank 13-slot fixed-effect surface", {
  x <- g5_imom012_clock_matrix(1:13)
  expect_equal(dim(x), c(13L, 12L))
  expect_equal(qr(cbind(1, x))$rank, 13L)
  expect_equal(colnames(x), paste0("slot_", 2:13))
  expect_error(g5_imom012_clock_matrix(c(1, 14)), "13-slot")
})

test_that("period panel preserves bar units and session-boundary topology", {
  n <- 1100L
  slot <- rep(1:13, length.out = n)
  session <- as.Date("2017-12-01") + (seq_len(n) - 1L) %/% 13L
  close <- 100 * exp(cumsum(rep(0.0001, n) + sin(seq_len(n) / 17) * 0.0004))
  bars <- data.frame(
    timestamp_utc = as.POSIXct("2017-12-01 14:30:00", tz = "UTC") + seq_len(n) * 1800,
    session_date = session, bar_slot = slot, open = close * 0.9998,
    close = close, stringsAsFactors = FALSE
  )
  panel <- g5_imom012_period_panel(bars, as.Date("2018-01-02"), as.Date("2018-02-28"))
  expect_true(nrow(panel$y) > 0L)
  expect_equal(ncol(panel$y), 4L)
  expect_equal(ncol(panel$features$raw_return), 6L)
  expect_equal(ncol(panel$clock), 12L)
  expect_true(any(panel$target_crosses_session))
  expect_true(all(panel$anchor_slot %in% 1:13))
})

test_that("one cell fits all six exact and clock-aware authorities", {
  train <- imom012_synthetic_panel(520L, 10L)
  development <- imom012_synthetic_panel(390L, 11L)
  out <- g5_imom012_fit_cell(train, development, 2L, 3L)
  expect_setequal(out$metrics$model_id, g5_imom012_contract()$model_ids)
  expect_equal(nrow(out$metrics), 6L)
  expect_true(all(is.finite(out$metrics$development_scaled_loss)))
  expect_setequal(
    unique(out$coefficients$model_id),
    g5_imom012_contract()$model_ids
  )
  expect_equal(nrow(out$losses), 390L)
  expect_true(all(g5_imom012_contract()$model_ids %in% names(out$losses)))
  expect_equal(
    unique(out$coefficients$fit_rank[out$coefficients$model_id == "C2_CLOCK_PATH"]),
    16L
  )
})

test_that("session aggregation gives each session one row", {
  losses <- data.frame(
    anchor_session = as.Date(c("2021-01-04", "2021-01-04", "2021-01-05")),
    B0_DRIFT = c(1, 3, 9), B1_RAW = c(2, 2, 8), stringsAsFactors = FALSE
  )
  out <- g5_imom012_session_losses(losses, c("B0_DRIFT", "B1_RAW"))
  expect_equal(nrow(out), 2L)
  expect_equal(out$B0_DRIFT, c(2, 9))
  expect_equal(out$B1_RAW, c(2, 8))
})

test_that("contrast algebra follows the frozen positive-favors-second convention", {
  x <- data.frame(
    B0_DRIFT = 5, B1_RAW = 4, Q2_PATH = 3,
    C0_CLOCK = 6, C1_CLOCK_RAW = 4, C2_CLOCK_PATH = 2
  )
  out <- g5_imom012_add_contrasts(x)
  expect_equal(unname(unlist(out[c("D10", "D21", "D20", "K10", "K21", "K20")])), c(1, 1, 2, 2, 2, 4))
})

test_that("FDR is applied only to the 22 candidate rows", {
  contract <- g5_imom012_contract()
  contrasts <- expand.grid(
    contrast_id = contract$contrast_ids,
    row = 1:3,
    stringsAsFactors = FALSE
  )
  contrasts$candidate_fdr <- contrasts$row != 3L
  contrasts$centered_null_upper_p <- rep(c(0.01, 0.04, 0.001), length(contract$contrast_ids))
  out <- g5_imom012_apply_fdr(contrasts)
  expect_true(all(is.na(out$bh_q_value[!out$candidate_fdr])))
  expect_true(all(is.finite(out$bh_q_value[out$candidate_fdr])))
})

test_that("candidate gate requires clock control and candidate status", {
  contract <- g5_imom012_contract()
  registry <- data.frame(
    analysis_id = c("A", "B"), symbol = c("AAA", "AMD"), sector = "Test",
    analysis_stratum = c("DIVERSE_STOCK_CANDIDATE", "REMEMBERED_OPERATOR_CASE"),
    candidate_fdr = c(TRUE, FALSE), stringsAsFactors = FALSE
  )
  make_rows <- function(id, candidate) data.frame(
    analysis_id = id, contrast_id = contract$contrast_ids,
    observed_mean_differential = rep(0.1, 6L), ci_lower_90 = rep(0.01, 6L),
    bh_q_value = if (candidate) rep(0.05, 6L) else rep(NA_real_, 6L),
    stringsAsFactors = FALSE
  )
  contrasts <- rbind(make_rows("A", TRUE), make_rows("B", FALSE))
  coefficients <- data.frame(
    analysis_id = c("A", "B"), median_clock_gamma = c(0.2, 0.2),
    median_clock_delta = c(-0.1, -0.1), stringsAsFactors = FALSE
  )
  out <- g5_imom012_decisions(contrasts, coefficients, registry)
  expect_true(out$is_clock_controlled_path_candidate[out$analysis_id == "A"])
  expect_false(out$is_clock_controlled_path_candidate[out$analysis_id == "B"])
  expect_true(out$clock_controlled_raw_clue[out$analysis_id == "A"])
})

test_that("stationary session bootstrap is deterministic", {
  a <- g5_mom015_stationary_mean(seq(-0.2, 0.4, length.out = 80), 2026082161L, 200L, 20)
  b <- g5_mom015_stationary_mean(seq(-0.2, 0.4, length.out = 80), 2026082161L, 200L, 20)
  expect_equal(a, b)
  expect_equal(a$bootstrap_draws, 200L)
})

test_that("result vocabulary cannot imply strategy or confirmation authority", {
  contract <- g5_imom012_contract()
  forbidden <- c("trade", "position", "sharpe", "drawdown", "allocation", "leverage")
  expect_false(any(forbidden %in% names(contract)))
  expect_true(contract$query_end < contract$confirmation_start)
})
