repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mom_09_1_qqq_volume_confirmed_continuation.R"))

hm091_fixture_bars <- function(end_date = as.Date("2023-12-29")) {
  dates <- seq.Date(as.Date("2016-01-04"), end_date, by = "day")
  i <- seq_along(dates)
  close <- 100 * exp(0.0003 * i + 0.012 * sin(i / 31) + 0.006 * cos(i / 13))
  open <- close * exp(0.0015 * sin(i / 17))
  volume <- 4e7 * exp(0.18 * sin(i / 23) + 0.08 * cos(i / 7))
  data.frame(
    symbol = "QQQ", session_date = dates, open = open,
    high = pmax(open, close) * 1.002, low = pmin(open, close) * 0.998,
    close = close, volume = volume, adjusted = TRUE, timeframe = "1D",
    stringsAsFactors = FALSE
  )
}

hm091_signal_panel <- function(n = 360L, seed = 91L) {
  set.seed(seed)
  r <- matrix(stats::rnorm(n * 3L), nrow = n)
  v <- matrix(stats::rexp(n * 3L, rate = 1.5), nrow = n)
  a <- abs(r)
  interaction <- r * v
  target <- sapply(seq_len(3L), function(h) {
    0.55 * interaction[, 2L] + 0.12 * r[, 2L] + stats::rnorm(n, sd = 0.35 + h * 0.02)
  })
  list(
    return_matrix = r,
    participation_matrix = v,
    magnitude_matrix = a,
    interaction_matrix = interaction,
    target_matrix = target,
    anchor_date = seq.Date(as.Date("2018-01-01"), by = "day", length.out = n),
    entry_date = seq.Date(as.Date("2018-01-02"), by = "day", length.out = n)
  )
}

testthat::test_that("HYP-MOM-09.1 freezes the participation transform and evidence seals", {
  contract <- g5_hm091_contract()
  testthat::expect_identical(contract$symbol, "QQQ")
  testthat::expect_identical(contract$lookback_grid, c(1L, 5L, 20L))
  testthat::expect_identical(contract$target_grid, c(1L, 5L, 20L))
  testthat::expect_identical(contract$volume_reference_sessions, 60L)
  testthat::expect_equal(contract$volume_cap_multiple, 5)
  testthat::expect_true(contract$development_end < contract$confirmation_start)
  testthat::expect_true(contract$confirmation_end < as.Date("2026-01-01"))
  changed <- contract
  changed$volume_reference_sessions <- 40L
  testthat::expect_error(g5_hm091_validate_contract(changed), "Frozen HYP-MOM-09.1 contract changed")
})
testthat::test_that("daily participation excludes the current observation from its reference", {
  contract <- g5_hm091_contract()
  dollar_volume <- c(rep(100, 60L), 1000, rep(100, 5L))
  participation <- g5_hm091_daily_participation(dollar_volume, contract)
  testthat::expect_true(is.na(participation$positive_surprise[[60L]]))
  testthat::expect_equal(participation$positive_surprise[[61L]], log(5))
  testthat::expect_true(participation$capped[[61L]])
  testthat::expect_equal(participation$positive_surprise[[62L]], 0)
})

testthat::test_that("zone panel constructs exact causal return, participation, and target values", {
  contract <- g5_hm091_contract()
  panel <- g5_hm091_zone_panel(
    hm091_fixture_bars(as.Date("2020-12-31")),
    contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  i <- panel$anchor_index[[1L]]
  l_i <- match(5L, contract$lookback_grid)
  h_i <- match(5L, contract$target_grid)
  expected_r <- log(panel$bars$close[i] / panel$bars$close[i - 5L])
  expected_v <- mean(panel$bars$positive_surprise[(i - 4L):i])
  expected_y <- log(panel$bars$open[i + 6L] / panel$bars$open[i + 1L])
  testthat::expect_equal(unname(panel$return_matrix[1L, l_i]), expected_r)
  testthat::expect_equal(unname(panel$participation_matrix[1L, l_i]), expected_v)
  testthat::expect_equal(unname(panel$interaction_matrix[1L, l_i]), expected_r * expected_v)
  testthat::expect_equal(unname(panel$target_matrix[1L, h_i]), expected_y)
  testthat::expect_true(all(panel$maximum_exit_date <= contract$train_end))
  testthat::expect_true(all(panel$construction_checks$passed))
})

testthat::test_that("bar validation rejects zero volume, split-like jumps, and sealed dates", {
  contract <- g5_hm091_contract()
  bars <- hm091_fixture_bars(as.Date("2020-12-31"))
  zero <- bars
  zero$volume[[100L]] <- 0
  testthat::expect_error(g5_hm091_validate_bars(zero, contract$train_end), "positive_finite_ohlcv")
  split <- bars
  split$close[[500L]] <- 2 * split$close[[499L]]
  split$open[[500L]] <- split$close[[500L]]
  split$high[[500L]] <- split$close[[500L]] * 1.002
  split$low[[500L]] <- split$close[[500L]] * 0.998
  split$volume[[500L]] <- 0.5 * split$volume[[499L]]
  testthat::expect_error(g5_hm091_validate_bars(split, contract$train_end), "split_like_discontinuity_gate")
  extra <- bars[nrow(bars), ]
  extra$session_date <- as.Date("2026-01-02")
  testthat::expect_error(
    g5_hm091_validate_bars(rbind(bars, extra), contract$confirmation_end),
    "maximum_date_seal"
  )
})

testthat::test_that("surface, complete shifts, and tie-breaking are deterministic", {
  contract <- g5_hm091_contract()
  panel <- hm091_signal_panel()
  surface <- g5_hm091_surface(panel, contract)
  testthat::expect_equal(nrow(surface), 9L)
  testthat::expect_equal(anyDuplicated(surface$cell_id), 0L)
  testthat::expect_true(max(surface$partial_correlation) > 0.5)
  shift <- g5_hm091_shift_test(panel, surface, contract)
  expected_shifts <- g5_hm091_admissible_shifts(nrow(panel$target_matrix), 60L)
  testthat::expect_identical(shift$distribution$shift, expected_shifts)
  testthat::expect_true(shift$decision$passed)
  tied <- data.frame(
    cell_id = c("L20_H5", "L5_H5", "L20_H1"),
    lookback_sessions = c(20L, 5L, 20L),
    target_sessions = c(5L, 5L, 1L),
    partial_correlation = c(0.2, 0.2, 0.2)
  )
  testthat::expect_identical(g5_hm091_nominate(tied, TRUE)$cell_id, "L5_H5")
  testthat::expect_equal(nrow(g5_hm091_nominate(tied, FALSE)), 0L)
})

testthat::test_that("frozen model comparison and stationary bootstrap are deterministic", {
  set.seed(1901)
  make_pairs <- function(n, start) {
    r <- stats::rnorm(n)
    v <- stats::rexp(n)
    a <- abs(r)
    interaction <- r * v
    data.frame(
      anchor_date = seq.Date(as.Date(start), by = "day", length.out = n),
      entry_date = seq.Date(as.Date(start) + 1L, by = "day", length.out = n),
      r = r, v = v, a = a, interaction = interaction,
      y = 0.08 * r + 0.35 * interaction + stats::rnorm(n, sd = 0.2),
      stringsAsFactors = FALSE
    )
  }
  train <- make_pairs(700L, "2017-01-03")
  development <- make_pairs(650L, "2021-01-04")
  predictions <- g5_hm091_model_predictions(train, development)
  metrics <- g5_hm091_model_metrics(predictions)
  testthat::expect_identical(metrics$model_id, c("DRIFT", "RETURN", "VOLUME", "ADDITIVE", "INTERACTION"))
  testthat::expect_true(metrics$development_mse[metrics$model_id == "INTERACTION"] <
                        metrics$development_mse[metrics$model_id == "ADDITIVE"])
  contract <- g5_hm091_contract()
  contract$bootstrap_count <- 200L
  first <- g5_hm091_development_bootstrap(development, predictions, contract)
  second <- g5_hm091_development_bootstrap(development, predictions, contract)
  testthat::expect_identical(first, second)
  testthat::expect_true(first$beta_probability_positive > 0.9)
  testthat::expect_true(first$loss_probability_positive > 0.9)
})

testthat::test_that("strategy and performance surfaces remain absent", {
  function_text <- paste(deparse(body(g5_hm091_run_development)), collapse = " ")
  testthat::expect_false(grepl("sharpe|drawdown|pnl|wealth|position|turnover", function_text, ignore.case = TRUE))
})
