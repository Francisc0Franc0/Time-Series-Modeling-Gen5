source(testthat::test_path("..", "..", "R", "gen5_lit_mr_02_1_bollinger_poc.R"))
source(testthat::test_path("..", "..", "R", "gen5_lit_mr_02_1_pair_panel.R"))

panel_sessions <- function(start = as.Date("2016-01-04"), n = 300L) {
  dates <- seq(start, by = "day", length.out = ceiling(n * 7 / 5) + 20L)
  dates <- dates[!as.POSIXlt(dates)$wday %in% c(0L, 6L)]
  head(dates, n)
}

panel_pair_bars <- function(symbol_y = "IVV", symbol_x = "SPY", beta = 1.2) {
  dates <- panel_sessions()
  i <- seq_along(dates)
  x <- if (beta < 0) {
    100 + 0.02 * i + 20 * sin(i / 5)
  } else {
    100 + 0.08 * i + 4 * sin(i / 23)
  }
  intercept <- if (beta < 0) 200 else 15
  residual_scale <- if (beta < 0) 0.05 else 2
  y <- intercept + beta * x + residual_scale * sin(i / 7)
  make <- function(symbol, close) {
    open <- close * (1 + 0.001 * sin(i / 3))
    data.frame(
      symbol = symbol,
      session_date = dates,
      open = open,
      high = pmax(open, close) * 1.002,
      low = pmin(open, close) * 0.998,
      close = close,
      volume = 1000000 + i,
      stringsAsFactors = FALSE
    )
  }
  rbind(make(symbol_x, x), make(symbol_y, y))
}

testthat::test_that("PANEL-A registry is finite, oriented, and role separated", {
  registry <- g5_mr02_panel_registry()
  testthat::expect_equal(nrow(registry), 14L)
  testthat::expect_equal(
    sum(registry$analysis_role == "PRIMARY_TRADING_TEMPLATE"), 12L
  )
  testthat::expect_equal(sum(registry$analysis_role == "DIAGNOSTIC_ONLY"), 2L)
  testthat::expect_false(any(registry$symbol_y == registry$symbol_x))
  testthat::expect_equal(registry$pair_id[[1L]], "P01_IVV_SPY")
  testthat::expect_equal(registry$pair_id[[14L]], "D02_TLT_SPY")
  testthat::expect_true(all(c(
    "IVV", "SPY", "IAU", "GLD", "SOXX", "SMH", "UUP"
  ) %in% g5_mr02_panel_required_symbols(registry)))
})

testthat::test_that("PANEL-B freezes 15 industry-diverse primary pairs", {
  registry <- g5_mr02_panel_b_registry()
  testthat::expect_equal(nrow(registry), 15L)
  testthat::expect_true(all(registry$panel_id == "PANEL_B"))
  testthat::expect_equal(registry$pair_index, 101L:115L)
  testthat::expect_true(all(
    registry$analysis_role == "PRIMARY_TRADING_TEMPLATE"
  ))
  testthat::expect_true(all(registry$instance_scope == "PANEL_B_PRIMARY"))
  testthat::expect_equal(registry$pair_id[[1L]], "B01_XLP_VDC")
  testthat::expect_equal(registry$pair_id[[15L]], "B15_GDX_GLD")
  testthat::expect_equal(length(unique(registry$pair_category)), 3L)
  testthat::expect_false(any(registry$symbol_y == registry$symbol_x))
  testthat::expect_equal(
    g5_mr02_panel_validate_registry(registry),
    registry
  )
})

testthat::test_that("PANEL-B uses distinct deterministic seeds", {
  row <- g5_mr02_panel_b_registry()[1L, , drop = FALSE]
  contract <- g5_mr02_panel_instance_contract(row)
  testthat::expect_equal(contract$instance_scope, "PANEL_B_PRIMARY")
  testthat::expect_equal(contract$symbol_y, "XLP")
  testthat::expect_equal(contract$symbol_x, "VDC")
  testthat::expect_equal(contract$bootstrap_seed, 106801L)
  testthat::expect_equal(contract$random_seed, 106802L)
  testthat::expect_equal(contract$convergence_bootstrap_seed, 106803L)
})

testthat::test_that("pair instances change assets without changing mechanics", {
  row <- g5_mr02_panel_registry()[1L, , drop = FALSE]
  contract <- g5_mr02_panel_instance_contract(row)
  testthat::expect_equal(contract$instance_scope, "PANEL_A_PRIMARY")
  testthat::expect_equal(contract$symbol_y, "IVV")
  testthat::expect_equal(contract$symbol_x, "SPY")
  testthat::expect_equal(contract$query_end, contract$train_end)
  testthat::expect_equal(contract$lookback_sessions, 20L)
  testthat::expect_equal(contract$entry_z, 1)
  testthat::expect_equal(contract$exit_z, 0)
  testthat::expect_equal(contract$bootstrap_seed, 6801L)
  testthat::expect_equal(contract$random_seed, 6802L)
})

testthat::test_that("canonical identity remains immutable", {
  contract <- g5_mr02_contract()
  contract$symbol_y <- "IVV"
  testthat::expect_error(
    g5_mr02_validate_contract(contract),
    "canonical GLD-USO instance cannot change"
  )
})

testthat::test_that("custom positive-beta pair uses generic executable legs", {
  row <- g5_mr02_panel_registry()[1L, , drop = FALSE]
  contract <- g5_mr02_panel_instance_contract(row)
  indicators <- g5_mr02_signal_states(
    g5_mr02_rolling_indicators(
      g5_mr02_common_panel(panel_pair_bars(), contract),
      contract
    ),
    contract
  )
  replay <- g5_mr02_build_replay(indicators, contract)
  active <- replay[replay$target_state != 0L, , drop = FALSE]
  testthat::expect_gt(nrow(active), 0L)
  testthat::expect_true(all(active$symbol_x == "SPY"))
  testthat::expect_true(all(active$symbol_y == "IVV"))
  testthat::expect_true(all(abs(active$weight_x) + abs(active$weight_y) > 0))
  testthat::expect_true(all(abs(active$gross_exposure - 1) < 1e-10))
  long <- active[active$target_state == 1L, , drop = FALSE]
  short <- active[active$target_state == -1L, , drop = FALSE]
  testthat::expect_true(all(long$weight_y > 0 & long$weight_x < 0))
  testthat::expect_true(all(short$weight_y < 0 & short$weight_x > 0))
})

testthat::test_that("negative beta changes position semantics and stays diagnostic", {
  row <- g5_mr02_panel_registry()[13L, , drop = FALSE]
  contract <- g5_mr02_panel_instance_contract(row)
  testthat::expect_equal(contract$instance_scope, "PANEL_A_DIAGNOSTIC")
  bars <- panel_pair_bars(symbol_y = "GLD", symbol_x = "UUP", beta = -0.8)
  indicators <- g5_mr02_rolling_indicators(
    g5_mr02_common_panel(bars, contract),
    contract
  )
  eligible <- indicators[is.finite(indicators$z_score), , drop = FALSE]
  testthat::expect_gt(nrow(eligible), 0L)
  testthat::expect_gt(mean(eligible$beta < 0), 0.95)
  states <- g5_mr02_signal_states(indicators, contract)
  testthat::expect_true(all(states$target_state == 0L))
  diagnostic <- g5_mr02_panel_inverse_diagnostic(bars, row)
  testthat::expect_equal(
    diagnostic$trade_replay_status,
    "NOT_RUN_NEGATIVE_BETA_CHANGES_POSITION_SEMANTICS"
  )
  testthat::expect_gt(diagnostic$negative_beta_coverage, 0.95)
})

testthat::test_that("panel source contains no implicit current-date call", {
  path <- testthat::test_path(
    "..", "..", "R", "gen5_lit_mr_02_1_pair_panel.R"
  )
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
