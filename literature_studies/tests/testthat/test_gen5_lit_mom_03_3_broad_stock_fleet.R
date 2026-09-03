repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_03_2_universe_transport.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_03_3_broad_stock_fleet.R"
))

mom033_fixture_bars <- function(symbols = NULL) {
  contract <- g5_mom033_contract()
  if (is.null(symbols)) {
    registry <- g5_mom033_universe_registry(repo_root, contract)
    symbols <- g5_mom033_required_symbols(registry, contract)
  }
  dates <- seq.Date(contract$query_start, contract$signal_end, by = "day")
  dates <- dates[g5_mom032_weekday(dates) %in% 1:5]
  frames <- lapply(seq_along(symbols), function(symbol_i) {
    index <- seq_along(dates)
    close <- 35 * exp(
      0.00004 * ((symbol_i %% 13L) - 4L) * index +
        0.022 * sin(index / (13 + symbol_i %% 17L))
    )
    data.frame(
      symbol = symbols[[symbol_i]],
      session_date = dates,
      open = close * exp(0.0012 * cos(index / (9 + symbol_i %% 11L))),
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

testthat::test_that("broad fleet freezes 88 stocks and preserves source selection breadth", {
  contract <- g5_mom033_contract()
  registry <- g5_mom033_universe_registry(repo_root, contract)
  testthat::expect_equal(nrow(registry), 88L)
  testthat::expect_equal(length(unique(registry$sector)), 11L)
  testthat::expect_true(all(table(registry$sector) == 8L))
  testthat::expect_equal(contract$top_n_per_sleeve, 29L)
  testthat::expect_equal(contract$source_top_n_per_sleeve / contract$source_universe_size, 1 / 3)
  testthat::expect_identical(
    contract$selection_fraction_rule,
    "ROUND_HALF_DOWN_88_TIMES_3_OVER_9_EQUALS_29"
  )
  testthat::expect_false(contract$inference_opened)
  testthat::expect_false(contract$parameter_search_opened)
  testthat::expect_false(contract$forward_gate_opened)
})

testthat::test_that("29-name sleeves create valid causal targets without hidden leverage", {
  contract <- g5_mom033_contract()
  registry <- g5_mom033_universe_registry(repo_root, contract)
  symbols <- registry$symbol
  bars <- mom033_fixture_bars(c(symbols, contract$benchmark_symbol))
  panel <- g5_mom032_panel(bars, c(symbols, contract$benchmark_symbol))
  target_set <- g5_mom032_target_set(panel, symbols, contract)
  testthat::expect_true(all(vapply(
    target_set$targets,
    function(x) all(abs(rowSums(x) - 1) < 1e-12),
    logical(1)
  )))
  testthat::expect_true(all(target_set$targets$RELATIVE_ONLY[, "CASH"] == 0))
  testthat::expect_lte(
    max(target_set$targets$SOURCE_DUAL_MOMENTUM[, symbols]),
    2 * contract$sleeve_weight / contract$top_n_per_sleeve + 1e-12
  )
  testthat::expect_true(all(target_set$anchors$decision_date < target_set$anchors$execution_date))
})

testthat::test_that("full broad-fleet POC produces matched controls and sector allocations", {
  result <- g5_mom033_run(mom033_fixture_bars(), repo_root)
  testthat::expect_true(all(result$integrity$status == "PASS"))
  testthat::expect_equal(nrow(result$summary), 1L)
  testthat::expect_equal(nrow(result$metrics), length(g5_mom033_contract()$variants))
  testthat::expect_true(all(result$metrics$intervals == 507L))
  testthat::expect_equal(length(unique(result$sector_tape$sector)), 11L)
  testthat::expect_true(all(result$sector_tape$cash_target_weight >= -1e-12))
  testthat::expect_true(all(is.finite(unlist(result$summary[-(1:4)]))))
})

testthat::test_that("broad-fleet contract and coverage failures stop loudly", {
  contract <- g5_mom033_contract()
  registry <- g5_mom033_universe_registry(repo_root, contract)
  required <- g5_mom033_required_symbols(registry, contract)
  bars <- mom033_fixture_bars(required)
  testthat::expect_error(
    g5_mom033_validate_bars(bars[bars$symbol != required[[1L]], ], required, contract),
    "exact_symbols"
  )
  changed <- contract
  changed$top_n_per_sleeve <- 30L
  testthat::expect_error(g5_mom033_validate_contract(changed), "top_n_per_sleeve")
})
