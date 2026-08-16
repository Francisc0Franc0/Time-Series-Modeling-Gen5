locate_repo_root <- function() {
  candidates <- c(".", "..", "../..", "../../..")
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "AGENTS.md"))) return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
  }
  stop("Repository root not found.", call. = FALSE)
}

repo_root <- locate_repo_root()
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_05_1_path_trendability.R"))

make_bars <- function(symbol = "AAA", n = 700L, start = as.Date("2016-01-04"), pattern = "up") {
  dates <- seq.Date(start, by = "day", length.out = n * 2L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  step <- switch(pattern,
    up = rep(.002, n),
    down = rep(-.002, n),
    choppy = rep(c(.02, -.019), length.out = n)
  )
  close <- 100 * exp(cumsum(step))
  open <- close * exp(rep(c(-.001, .001), length.out = n))
  high <- pmax(open, close) * 1.005
  low <- pmin(open, close) * .995
  data.frame(symbol, session_date = dates, open, high, low, close, volume = 1000, stringsAsFactors = FALSE)
}

testthat::test_that("contract freezes the intended lane", {
  c <- hreg51_contract()
  testthat::expect_equal(c$hypothesis_id, "HYP-REG-05.1")
  testthat::expect_equal(c$er_length, 20L)
  testthat::expect_equal(c$adx_length, 14L)
  testthat::expect_equal(c$horizons, c(5L, 10L, 20L))
  testthat::expect_equal(c$registry_assets, 26L)
  testthat::expect_equal(c$confirmation_start, as.Date("2024-01-02"))
})

testthat::test_that("bar validation is strict", {
  bars <- make_bars(n = 50L)
  clean <- hreg51_assert_bars(bars)
  testthat::expect_equal(nrow(clean), 50L)
  testthat::expect_error(hreg51_assert_bars(rbind(bars, bars[1, ])), "duplicated")
  bad <- bars; bad$high[[2L]] <- bad$low[[2L]] - 1
  testthat::expect_error(hreg51_assert_bars(bad), "ordering")
  future <- bars; future$session_date[[1L]] <- as.Date("2024-01-02")
  testthat::expect_error(hreg51_assert_bars(future), "Confirmation")
})

testthat::test_that("efficiency ratio distinguishes straight and choppy paths", {
  straight <- exp(seq(0, .3, length.out = 41))
  choppy <- exp(cumsum(rep(c(.03, -.025), 20)))
  er_straight <- hreg51_efficiency_ratio(straight, 20L)
  er_choppy <- hreg51_efficiency_ratio(choppy, 20L)
  testthat::expect_equal(tail(er_straight, 1L), 1, tolerance = 1e-12)
  testthat::expect_lt(tail(er_choppy, 1L), .2)
  testthat::expect_true(all(er_straight[is.finite(er_straight)] >= 0 & er_straight[is.finite(er_straight)] <= 1))
  testthat::expect_error(hreg51_efficiency_ratio(straight, 1L), "at least two")
})

testthat::test_that("Wilder directional movement and ADX preserve sign semantics", {
  up <- make_bars(n = 100L, pattern = "up")
  down <- make_bars(n = 100L, pattern = "down")
  au <- hreg51_adx(up$high, up$low, up$close, 14L)
  ad <- hreg51_adx(down$high, down$low, down$close, 14L)
  testthat::expect_gt(tail(au$plus_di, 1L), tail(au$minus_di, 1L))
  testthat::expect_lt(tail(ad$plus_di, 1L), tail(ad$minus_di, 1L))
  testthat::expect_equal(tail(au$direction, 1L), 1)
  testthat::expect_equal(tail(ad$direction, 1L), -1)
  testthat::expect_true(is.finite(tail(au$adx, 1L)))
  testthat::expect_true(all(au$adx[is.finite(au$adx)] >= 0 & au$adx[is.finite(au$adx)] <= 100))
})

testthat::test_that("rolling percentile excludes the current value", {
  score <- hreg51_rolling_percentile(1:6, 5L)
  testthat::expect_true(all(is.na(score[1:5])))
  testthat::expect_equal(score[[6L]], 1)
  tied <- hreg51_rolling_percentile(c(rep(1, 5), 1), 5L)
  testthat::expect_equal(tied[[6L]], .5)
})

testthat::test_that("hysteresis suppresses boundary chatter", {
  state <- hreg51_hysteretic_state(c(.2, .35, .41, .65, .71, .65, .59, .3))
  testthat::expect_equal(state, c("LOW", "LOW", "MEDIUM", "MEDIUM", "HIGH", "HIGH", "MEDIUM", "MEDIUM"))
})

testthat::test_that("future path metrics use next open and capture turns", {
  open <- c(100, 100, 101, 102, 103, 104)
  close <- c(100, 101, 102, 103, 104, 105)
  path <- hreg51_future_path_metrics(open, close, 5L)
  testthat::expect_equal(path$efficiency[[1L]], 1, tolerance = 1e-12)
  testthat::expect_equal(path$turn_rate[[1L]], 0)
  choppy_close <- c(100, 102, 100, 102, 100, 102)
  choppy <- hreg51_future_path_metrics(open, choppy_close, 5L)
  testthat::expect_lt(choppy$efficiency[[1L]], path$efficiency[[1L]])
  testthat::expect_gt(choppy$turn_rate[[1L]], 0)
})

testthat::test_that("asset ledger is causal and contains no strategy surface", {
  ledger <- hreg51_build_asset_ledger(make_bars(n = 700L, pattern = "up"))
  testthat::expect_true(all(c("er20", "adx14", "future_efficiency_h10", "er_direction_survival_h10") %in% names(ledger)))
  testthat::expect_false(any(c("pnl", "strategy_return", "sharpe", "drawdown", "atr_state") %in% names(ledger)))
  first_analysis <- which(ledger$session_date >= hreg51_contract()$analysis_start)[[1L]]
  testthat::expect_true(is.finite(ledger$er_percentile[[first_analysis]]))
  testthat::expect_true(is.finite(ledger$adx_percentile[[first_analysis]]))
  testthat::expect_true(is.na(tail(ledger$future_efficiency_h20, 1L)))
})

testthat::test_that("multi-asset ledger preserves symbols and ordering", {
  bars <- rbind(make_bars("BBB", 700L, pattern = "choppy"), make_bars("AAA", 700L, pattern = "up"))
  ledger <- hreg51_build_ledger(bars)
  testthat::expect_equal(unique(ledger$symbol), c("AAA", "BBB"))
  counts <- table(ledger$symbol)
  testthat::expect_equal(names(counts), c("AAA", "BBB"))
  testthat::expect_equal(as.integer(counts), c(700L, 700L))
})

make_summary_ledger <- function() {
  bars <- rbind(
    make_bars("AAA", 1500L, start = as.Date("2018-01-02"), pattern = "up"),
    make_bars("BBB", 1500L, start = as.Date("2018-01-02"), pattern = "choppy")
  )
  ledger <- hreg51_build_ledger(bars)
  ledger$er_state <- ifelse(ledger$analysis_index %% 3L == 0L, "LOW", ifelse(ledger$analysis_index %% 3L == 1L, "MEDIUM", "HIGH"))
  ledger$adx_state <- ledger$er_state
  ledger$er_percentile <- (ledger$analysis_index %% 100L) / 100
  ledger$adx_percentile <- ledger$er_percentile
  ledger
}

testthat::test_that("candidate summaries preserve common targets", {
  ledger <- make_summary_ledger()
  a <- hreg51_asset_summary(ledger, "ER", 10L, "ALL")
  n <- hreg51_asset_summary(ledger, "ADX", 10L, "NON_OVERLAP", 0L)
  testthat::expect_equal(nrow(a), 2L)
  testthat::expect_equal(nrow(n), 2L)
  testthat::expect_true(all(a$candidate == "ER"))
  testthat::expect_true(all(n$sample == "NON_OVERLAP"))
  testthat::expect_true(all(n$observations < a$observations))
  testthat::expect_true(all(c("high_low_ratio", "survival_gap", "turn_rate_gap") %in% names(a)))
})

testthat::test_that("panel and offset summaries are structurally complete", {
  ledger <- make_summary_ledger()
  all <- hreg51_all_summaries(ledger)
  offsets <- hreg51_offset_summary(ledger)
  testthat::expect_equal(nrow(all$asset), 24L)
  testthat::expect_equal(nrow(all$panel), 12L)
  testthat::expect_equal(nrow(offsets), 20L)
  testthat::expect_equal(sort(unique(offsets$offset)), 0:9)
  testthat::expect_equal(sort(unique(offsets$candidate)), c("ADX", "ER"))
})

testthat::test_that("temporal and calendar summaries retain frozen partitions", {
  ledger <- make_summary_ledger()
  periods <- hreg51_temporal_summary(ledger)
  years <- hreg51_calendar_summary(ledger)
  testthat::expect_equal(sort(unique(periods$period)), c("2018-2020", "2021-2023"))
  testthat::expect_equal(nrow(periods), 4L)
  testthat::expect_equal(sort(unique(years$year)), 2018:2023)
  testthat::expect_equal(nrow(years), 12L)
})

testthat::test_that("state diagnostics report occupancy and run behavior", {
  diagnostics <- hreg51_state_diagnostics(make_summary_ledger(), "ER")
  testthat::expect_equal(nrow(diagnostics), 2L)
  testthat::expect_equal(diagnostics$low_fraction + diagnostics$medium_fraction + diagnostics$high_fraction, rep(1, 2), tolerance = 1e-12)
  testthat::expect_true(all(diagnostics$switches_per_year > 0))
  testthat::expect_true(all(diagnostics$median_run_sessions >= 1))
})

testthat::test_that("circular controls are deterministic and candidate-complete", {
  ledger <- make_summary_ledger()
  c <- hreg51_contract(); c$simulations <- 3L; c$simulation_seed <- 99L
  first <- hreg51_circular_controls(ledger, c)
  second <- hreg51_circular_controls(ledger, c)
  testthat::expect_equal(first, second)
  testthat::expect_equal(nrow(first), 6L)
  testthat::expect_equal(sort(unique(first$candidate)), c("ADX", "ER"))
  testthat::expect_true(all(is.finite(first$median_spearman)))
})

testthat::test_that("candidate column routing fails loudly", {
  testthat::expect_equal(hreg51_candidate_columns("er")$score, "er_percentile")
  testthat::expect_equal(hreg51_candidate_columns("ADX")$state, "adx_state")
  testthat::expect_error(hreg51_candidate_columns("HURST"), "ER or ADX")
})
