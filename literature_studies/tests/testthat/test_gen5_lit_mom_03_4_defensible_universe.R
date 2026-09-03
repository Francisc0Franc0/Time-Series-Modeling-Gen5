repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_03_2_universe_transport.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_03_4_defensible_universe.R"))

mom034_fixture_registry <- function() {
  data.frame(
    instance_id = paste0("I", seq_len(9)),
    symbol = paste0("S", seq_len(9)),
    sector = rep(c("A", "B", "C"), each = 3),
    cohort = "TEST",
    stringsAsFactors = FALSE
  )
}

mom034_fixture_bars <- function(registry = mom034_fixture_registry()) {
  contract <- g5_mom034_contract()
  dates <- seq.Date(contract$query_start, contract$signal_end, by = "day")
  dates <- dates[g5_mom032_weekday(dates) %in% 1:5]
  symbols <- c(registry$symbol, contract$benchmark_symbol)
  frames <- lapply(seq_along(symbols), function(j) {
    index <- seq_along(dates)
    close <- 50 * exp(0.00015 * (j - 4) * index + 0.012 * sin(index / (11 + j)))
    data.frame(
      symbol = symbols[[j]],
      session_date = dates,
      open = close * exp(0.0008 * cos(index / (7 + j))),
      high = close * 1.004,
      low = close * 0.996,
      close = close,
      volume = 1e6,
      adjusted = TRUE,
      timeframe = "1D",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, frames)
}

testthat::test_that("the defensible-universe contract freezes the ex-ante boundary", {
  contract <- g5_mom034_contract()
  testthat::expect_equal(contract$universe_size, 481L)
  testthat::expect_equal(contract$opening_top_n_per_sleeve, 160L)
  testthat::expect_lt(contract$universe_freeze_date, contract$signal_start)
  testthat::expect_identical(
    contract$selection_fraction_rule,
    "FLOOR_CAUSALLY_SCOREABLE_COUNT_DIVIDED_BY_THREE"
  )
  testthat::expect_false(contract$inference_opened)
  testthat::expect_false(contract$parameter_search_opened)
  testthat::expect_false(contract$forward_gate_opened)
})

testthat::test_that("dynamic scoreability preserves one-third ranking breadth", {
  registry <- mom034_fixture_registry()
  bars <- mom034_fixture_bars(registry)
  target_set <- g5_mom034_target_set(bars, registry)
  testthat::expect_true(all(target_set$breadth$scoreable_count == 9L))
  testthat::expect_true(all(target_set$breadth$top_n_per_sleeve == 3L))
  selected <- stats::aggregate(
    cbind(selected_10w, selected_25w) ~ decision_date,
    data = target_set$scores,
    FUN = sum
  )
  testthat::expect_true(all(selected$selected_10w == 3L))
  testthat::expect_true(all(selected$selected_25w == 3L))
  testthat::expect_true(all(abs(rowSums(target_set$targets$RELATIVE_ONLY) - 1) < 1e-12))
})

testthat::test_that("execution intervals and replay remain self-financing", {
  registry <- mom034_fixture_registry()
  bars <- mom034_fixture_bars(registry)
  target_set <- g5_mom034_target_set(bars, registry)
  intervals <- g5_mom034_intervals(bars, target_set, registry)
  tape <- g5_mom034_replay(target_set, intervals)
  testthat::expect_equal(length(unique(tape$variant)), length(g5_mom034_contract()$variants))
  testthat::expect_true(all(is.finite(tape$net_return)))
  testthat::expect_true(all(tape$wealth > 0))
  testthat::expect_true(all(tape$failed_entry_target_weight == 0))
  testthat::expect_true(all(tape$terminal_proxy_target_weight == 0))
})

testthat::test_that("missing next open is exposed as a terminal proxy", {
  registry <- mom034_fixture_registry()
  bars <- mom034_fixture_bars(registry)
  target_set <- g5_mom034_target_set(bars, registry)
  end_date <- target_set$anchors$execution_date[[5L]]
  bars <- bars[!(bars$symbol == registry$symbol[[1L]] & bars$session_date == end_date), , drop = FALSE]
  intervals <- g5_mom034_intervals(bars, target_set, registry)
  event <- intervals$terminal_events[
    intervals$terminal_events$symbol == registry$symbol[[1L]] &
      intervals$terminal_events$next_execution_date == end_date,
    , drop = FALSE
  ]
  testthat::expect_equal(nrow(event), 1L)
  testthat::expect_true(is.finite(event$proxy_return))
})

testthat::test_that("contract changes fail loudly", {
  contract <- g5_mom034_contract()
  contract$opening_top_n_per_sleeve <- 161L
  testthat::expect_error(g5_mom034_validate_contract(contract), "opening_top_n_per_sleeve")
})
