repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_03_2_universe_transport.R"
))

mom032_fixture_bars <- function(symbols = NULL) {
  contract <- g5_mom032_contract()
  if (is.null(symbols)) {
    registry <- g5_mom032_universe_registry(repo_root, contract)
    symbols <- g5_mom032_required_symbols(registry, contract)
  }
  dates <- seq.Date(contract$query_start, contract$signal_end, by = "day")
  dates <- dates[g5_mom032_weekday(dates) %in% 1:5]
  frames <- lapply(seq_along(symbols), function(symbol_i) {
    index <- seq_along(dates)
    close <- 40 * exp(
      0.00008 * ((symbol_i %% 9L) - 3L) * index +
        0.025 * sin(index / (13 + symbol_i %% 11L))
    )
    data.frame(
      symbol = symbols[[symbol_i]],
      session_date = dates,
      open = close * exp(0.0015 * cos(index / (11 + symbol_i %% 7L))),
      high = close * 1.003,
      low = close * 0.997,
      close = close,
      volume = 1e6,
      adjusted = TRUE,
      timeframe = "1D",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, frames)
}

testthat::test_that("transport registry freezes one ETF and eleven stock fleets", {
  contract <- g5_mom032_contract()
  registry <- g5_mom032_universe_registry(repo_root, contract)
  testthat::expect_equal(length(unique(registry$universe_id)), 12L)
  testthat::expect_equal(sum(registry$universe_type == "ETF_FLEET"), 10L)
  testthat::expect_equal(sum(registry$universe_type == "STATIC_STOCK_SECTOR"), 88L)
  testthat::expect_true(all(
    table(registry$universe_id[registry$universe_type == "STATIC_STOCK_SECTOR"]) == 8L
  ))
  testthat::expect_false("XLC" %in% contract$sector_etf_universe)
  testthat::expect_identical(contract$excluded_sector_etf_reason, "INCEPTION_AFTER_2016_QUERY_START")
  testthat::expect_false(contract$inference_opened)
  testthat::expect_false(contract$parameter_search_opened)
  testthat::expect_false(contract$forward_gate_opened)
})

testthat::test_that("target construction preserves the source component definitions", {
  contract <- g5_mom032_contract()
  symbols <- c("AAPL", "MSFT", "NVDA", "AMD", "AVGO", "ORCL", "CRM", "IBM")
  bars <- mom032_fixture_bars(c(symbols, contract$benchmark_symbol))
  panel <- g5_mom032_panel(bars, c(symbols, contract$benchmark_symbol))
  result <- g5_mom032_target_set(panel, symbols, contract)
  testthat::expect_identical(names(result$targets), contract$variants)
  testthat::expect_true(all(vapply(
    result$targets,
    function(x) all(abs(rowSums(x) - 1) < 1e-12),
    logical(1)
  )))
  testthat::expect_true(all(result$targets$EQUAL_WEIGHT_UNIVERSE[, symbols] == 1 / 8))
  testthat::expect_true(all(result$targets$RELATIVE_ONLY[, "CASH"] == 0))
  testthat::expect_true(all(result$targets$SPY_OWNERSHIP[, "SPY"] == 1))
  testthat::expect_true(all(result$targets$CASH_NO_TRADE[, "CASH"] == 1))
  testthat::expect_true(all(result$targets$SOURCE_DUAL_MOMENTUM[, "SPY"] == 0))
})

testthat::test_that("causal replay uses next-open intervals and drift-aware ownership cost", {
  contract <- g5_mom032_contract()
  symbols <- c("AAPL", "MSFT", "NVDA", "AMD", "AVGO", "ORCL", "CRM", "IBM")
  bars <- mom032_fixture_bars(c(symbols, contract$benchmark_symbol))
  panel <- g5_mom032_panel(bars, c(symbols, contract$benchmark_symbol))
  targets <- g5_mom032_target_set(panel, symbols, contract)
  intervals <- g5_mom032_intervals(panel, targets$anchors)
  tape <- g5_mom032_replay("TEST_TECH", targets, intervals, contract)
  spy <- tape[tape$variant == "SPY_OWNERSHIP", , drop = FALSE]
  cash <- tape[tape$variant == "CASH_NO_TRADE", , drop = FALSE]
  testthat::expect_equal(spy$turnover_one_way[1], 1, tolerance = 1e-12)
  testthat::expect_true(all(abs(spy$turnover_one_way[-1]) < 1e-12))
  testthat::expect_equal(cash$wealth, rep(1, nrow(cash)), tolerance = 1e-12)
  testthat::expect_true(all(tape$decision_date < tape$execution_date))
  testthat::expect_equal(nrow(g5_mom032_metrics(tape, contract)), length(contract$variants))
})

testthat::test_that("full transport POC keeps bias labels and matched intervals explicit", {
  bars <- mom032_fixture_bars()
  result <- g5_mom032_run(bars, repo_root)
  testthat::expect_true(all(result$integrity$status == "PASS"))
  testthat::expect_equal(nrow(result$summary), 12L)
  testthat::expect_equal(length(unique(result$metrics$intervals)), 1L)
  testthat::expect_true(all(
    result$summary$evidence_label[result$summary$universe_type == "STATIC_STOCK_SECTOR"] ==
      g5_mom032_contract()$stock_evidence_label
  ))
  testthat::expect_true(all(is.finite(result$summary$source_minus_equal_cagr)))
  testthat::expect_true(all(result$summary$source_mean_invested_weight >= 0))
  testthat::expect_true(all(result$summary$source_mean_invested_weight <= 1))
})

testthat::test_that("coverage failures and contract changes stop loudly", {
  contract <- g5_mom032_contract()
  registry <- g5_mom032_universe_registry(repo_root, contract)
  required <- g5_mom032_required_symbols(registry, contract)
  bars <- mom032_fixture_bars(required)
  testthat::expect_error(
    g5_mom032_validate_bars(bars[bars$symbol != required[[1L]], ], required, contract),
    "exact_symbols"
  )
  changed <- contract
  changed$top_n_per_sleeve <- 2L
  testthat::expect_error(g5_mom032_validate_contract(changed), "top_n_per_sleeve")
})
