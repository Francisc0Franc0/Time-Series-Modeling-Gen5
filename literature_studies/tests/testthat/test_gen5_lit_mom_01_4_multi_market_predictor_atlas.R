repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_4_multi_market_predictor_atlas.R"
))

mom014_fixture_bars <- function() {
  dates <- seq.Date(as.Date("2016-01-04"), as.Date("2023-12-29"), by = "day")
  index <- seq_along(dates)
  close <- 100 * exp(0.0002 * index + 0.04 * sin(index / 23))
  open <- close * exp(0.003 * cos(index / 13))
  data.frame(
    symbol = "ZZZ",
    session_date = dates,
    open = open,
    high = pmax(open, close) * 1.002,
    low = pmin(open, close) * 0.998,
    close = close,
    volume = 1e6,
    adjusted = TRUE,
    timeframe = "1D",
    stringsAsFactors = FALSE
  )
}

testthat::test_that("LIT-MOM-01.4 contract freezes the split atlas boundary", {
  contract <- g5_mom014_contract()
  testthat::expect_identical(contract$registry_count, 92L)
  testthat::expect_identical(contract$lookback_grid, c(1L, 5L, 10L, 25L, 60L, 120L, 250L))
  testthat::expect_identical(contract$target_grid, c(5L, 10L, 25L, 60L))
  testthat::expect_equal(contract$fdr_q, 0.10)
  testthat::expect_true(contract$train_end < contract$development_start)
  testthat::expect_true(contract$development_end < contract$confirmation_start)
  changed <- contract
  changed$fdr_q <- 0.20
  testthat::expect_error(g5_mom014_validate_contract(changed), "contract changed")
})

testthat::test_that("frozen registry checksum, rows, and strata are exact", {
  contract <- g5_mom014_contract()
  registry <- g5_mom014_read_registry(repo_root, contract)
  testthat::expect_identical(attr(registry, "sha256"), contract$registry_sha256)
  testthat::expect_equal(nrow(registry), 92L)
  testthat::expect_equal(sum(registry$analysis_stratum == "PLAIN_ETF"), 68L)
  testthat::expect_equal(sum(registry$analysis_stratum == "ENGINEERED_ETF"), 6L)
  testthat::expect_equal(sum(registry$analysis_stratum == "STOCK_CHALLENGER"), 18L)
  testthat::expect_equal(sum(registry$is_spy_reference), 1L)
  testthat::expect_identical(registry$analysis_id, sprintf("A%03d", 1:92))
})

testthat::test_that("TRAIN and DEVELOPMENT panels have independent exact endpoints", {
  bars <- mom014_fixture_bars()
  contract <- g5_mom014_contract()
  train <- g5_mom014_period_panel(bars, contract$train_start, contract$train_end, contract)
  development <- g5_mom014_period_panel(
    bars, contract$development_start, contract$development_end, contract
  )
  testthat::expect_true(nrow(train$x) >= contract$minimum_period_anchors)
  testthat::expect_true(nrow(development$x) >= contract$minimum_period_anchors)
  testthat::expect_true(all(train$maximum_exit_date <= contract$train_end))
  testthat::expect_true(all(development$anchor_date >= contract$development_start))
  testthat::expect_true(all(development$maximum_exit_date <= contract$development_end))
  testthat::expect_true(max(train$maximum_exit_date) < min(development$anchor_date))
  testthat::expect_identical(dim(train$x)[[2L]], 7L)
  testthat::expect_identical(dim(train$y)[[2L]], 4L)
})

testthat::test_that("surface and nomination use all 28 cells without a TRAIN significance veto", {
  contract <- g5_mom014_contract()
  panel <- g5_mom014_period_panel(
    mom014_fixture_bars(), contract$train_start, contract$train_end, contract
  )
  surface <- g5_mom014_surface(panel, contract)
  testthat::expect_equal(nrow(surface), 28L)
  testthat::expect_equal(anyDuplicated(surface$cell_id), 0L)
  testthat::expect_equal(sum(surface$is_canonical_250_25), 1L)
  ties <- data.frame(
    cell_id = c("L60_H25", "L25_H25", "L60_H10"),
    lookback_sessions = c(60L, 25L, 60L),
    target_sessions = c(25L, 25L, 10L),
    correlation = c(0.01, 0.01, 0.01),
    stringsAsFactors = FALSE
  )
  testthat::expect_identical(g5_mom014_nominate(ties)$cell_id, "L60_H10")
  ties$correlation <- -abs(ties$correlation)
  testthat::expect_equal(nrow(g5_mom014_nominate(ties)), 0L)
})

testthat::test_that("fixed-cell shift test respects the frozen displacement", {
  contract <- g5_mom014_contract()
  panel <- g5_mom014_period_panel(
    mom014_fixture_bars(), contract$development_start, contract$development_end, contract
  )
  pairs <- g5_mom014_cell_pairs(panel, 60L, 25L, contract)
  shift <- g5_mom014_fixed_shift_test(pairs, contract)
  testthat::expect_true(all(
    pmin(
      shift$distribution$shift_sessions,
      nrow(pairs) - shift$distribution$shift_sessions
    ) >= contract$fixed_cell_shift_minimum
  ))
  testthat::expect_true(shift$summary$empirical_upper_p_value > 0)
  testthat::expect_true(shift$summary$empirical_upper_p_value <= 1)
})

testthat::test_that("BH adjustment is separate by stratum and SPY cannot become a candidate", {
  development <- data.frame(
    symbol = c("SPY", "AAA", "BBB", "CCC", "DDD"),
    analysis_stratum = c("PLAIN_ETF", "PLAIN_ETF", "PLAIN_ETF", "ENGINEERED_ETF", "STOCK_CHALLENGER"),
    is_spy_reference = c(TRUE, FALSE, FALSE, FALSE, FALSE),
    empirical_upper_p_value = c(0.001, 0.01, 0.20, 0.08, 0.08),
    correlation = rep(0.1, 5),
    beta = rep(0.1, 5),
    stringsAsFactors = FALSE
  )
  out <- g5_mom014_apply_fdr(development)
  testthat::expect_true(is.na(out$bh_q_value[out$symbol == "SPY"]))
  testthat::expect_equal(out$bh_q_value[out$symbol == "AAA"], 0.02)
  testthat::expect_false(out$is_development_candidate[out$symbol == "SPY"])
  testthat::expect_true(out$is_development_candidate[out$symbol == "AAA"])
  testthat::expect_true(out$is_development_candidate[out$symbol == "CCC"])
  testthat::expect_true(out$is_development_candidate[out$symbol == "DDD"])
})

testthat::test_that("stationary bootstrap index generation is deterministic", {
  set.seed(2026082105L)
  first <- g5_mom014_stationary_index_matrix(700L, 25L, 60)
  set.seed(2026082105L)
  second <- g5_mom014_stationary_index_matrix(700L, 25L, 60)
  testthat::expect_identical(first, second)
  testthat::expect_identical(dim(first), c(25L, 700L))
  testthat::expect_true(all(first >= 1L & first <= 700L))
})

testthat::test_that("confirmation input and strategy outcomes stay closed", {
  registry <- g5_mom014_read_registry(repo_root)
  bars <- mom014_fixture_bars()
  bars$symbol <- registry$symbol[[1L]]
  extra <- tail(bars, 1L)
  extra$session_date <- as.Date("2024-01-02")
  testthat::expect_error(
    g5_mom014_validate_bars(rbind(bars, extra), registry),
    "Confirmation bars"
  )
  function_text <- paste(deparse(body(g5_mom014_run_atlas)), collapse = " ")
  testthat::expect_false(grepl(
    "sharpe|drawdown|pnl|wealth|position|turnover",
    function_text, ignore.case = TRUE
  ))
})
