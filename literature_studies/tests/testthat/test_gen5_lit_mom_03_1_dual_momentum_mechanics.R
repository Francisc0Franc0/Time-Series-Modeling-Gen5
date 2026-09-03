repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_03_1_dual_momentum_mechanics.R"
))

mom031_fixture_bars <- function() {
  contract <- g5_mom031_contract()
  dates <- seq.Date(contract$query_start, contract$signal_end, by = "day")
  dates <- dates[g5_mom031_weekday_number(dates) %in% 1:5]
  frames <- lapply(seq_along(contract$universe), function(symbol_i) {
    index <- seq_along(dates)
    close <- 50 * exp((0.00005 * symbol_i) * index + 0.02 * sin(index / (17 + symbol_i)))
    data.frame(
      symbol = contract$universe[[symbol_i]],
      session_date = dates,
      open = close * exp(0.001 * cos(index / 13)),
      high = close * 1.002,
      low = close * 0.998,
      close = close,
      volume = 1e6,
      adjusted = TRUE,
      timeframe = "1D",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, frames)
}

testthat::test_that("LIT-MOM-03.1 contract freezes the published mechanics", {
  contract <- g5_mom031_contract()
  testthat::expect_identical(
    contract$universe,
    c("SHY", "IEF", "UUP", "GLD", "USO", "SPY", "EFA", "QQQ", "EEM")
  )
  testthat::expect_identical(unname(contract$lookback_weeks), c(10L, 25L))
  testthat::expect_identical(contract$top_n_per_sleeve, 3L)
  testthat::expect_equal(contract$sleeve_weight, 0.5)
  testthat::expect_false(contract$performance_opened)
  changed <- contract
  changed$top_n_per_sleeve <- 2L
  testthat::expect_error(
    g5_mom031_validate_contract(changed),
    "Frozen LIT-MOM-03.1 contract changed"
  )
})

testthat::test_that("ranking is deterministic and positive failed slots remain cash", {
  contract <- g5_mom031_contract()
  roc10 <- setNames(c(0.20, 0.20, 0.10, 0.05, -0.01, -0.02, -0.03, -0.04, -0.05), contract$universe)
  roc25 <- setNames(c(-0.01, -0.02, -0.03, -0.04, -0.05, -0.06, -0.07, -0.08, -0.09), contract$universe)
  out <- g5_mom031_allocate_scores(roc10, roc25, contract)
  testthat::expect_identical(out$selected_10w, c("SHY", "IEF", "UUP"))
  testthat::expect_identical(out$selected_25w, character())
  testthat::expect_equal(out$cash_weight, 0.5)
  testthat::expect_equal(sum(out$scores$target_weight) + out$cash_weight, 1)
  testthat::expect_identical(out$scores$rank_10w[1:2], c(2L, 1L))
})

testthat::test_that("an asset selected in both sleeves receives one third", {
  contract <- g5_mom031_contract()
  values <- setNames(seq(0.20, 0.04, length.out = length(contract$universe)), contract$universe)
  out <- g5_mom031_allocate_scores(values, values, contract)
  testthat::expect_equal(out$scores$target_weight[1:3], rep(1 / 3, 3))
  testthat::expect_equal(out$cash_weight, 0)
  testthat::expect_equal(sum(out$scores$target_weight), 1)
})

testthat::test_that("weekly anchors use only a same-week Monday-to-Wednesday fallback", {
  bars <- mom031_fixture_bars()
  removed_wednesday <- as.Date("2020-03-18")
  bars <- bars[bars$session_date != removed_wednesday, , drop = FALSE]
  panel <- g5_mom031_common_panel(bars)
  anchors <- g5_mom031_weekly_anchors(panel)
  row <- anchors[anchors$intended_wednesday == removed_wednesday, , drop = FALSE]
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_equal(row$decision_date, as.Date("2020-03-17"))
  testthat::expect_true(row$used_holiday_fallback)
  testthat::expect_true(row$execution_date > row$decision_date)
})

testthat::test_that("full mechanics emit balanced return-free tapes", {
  out <- g5_mom031_run(mom031_fixture_bars())
  contract <- out$contract
  weight_columns <- paste0("weight_", contract$universe)
  testthat::expect_true(nrow(out$allocations) > 450L)
  testthat::expect_equal(nrow(out$scores), nrow(out$allocations) * 9L)
  testthat::expect_true(all(out$integrity$status == "PASS"))
  testthat::expect_true(all(abs(
    rowSums(out$allocations[, weight_columns, drop = FALSE]) +
      out$allocations$cash_weight - 1
  ) < 1e-12))
  forbidden <- "return|pnl|profit|sharpe|drawdown|wealth|equity"
  testthat::expect_false(any(grepl(forbidden, names(out$allocations), ignore.case = TRUE)))
  testthat::expect_false(any(grepl(forbidden, names(out$scores), ignore.case = TRUE)))
  testthat::expect_true(all(out$allocations$decision_date <= contract$source_cutoff_date))
})

testthat::test_that("future bars and incomplete universes fail loudly", {
  bars <- mom031_fixture_bars()
  testthat::expect_error(
    g5_mom031_run(bars[bars$symbol != "EEM", , drop = FALSE]),
    "exact_universe"
  )
  extra <- bars[bars$session_date == max(bars$session_date), , drop = FALSE]
  extra$session_date <- as.Date("2026-03-26")
  testthat::expect_error(
    g5_mom031_run(rbind(bars, extra)),
    "source_cutoff_not_exceeded"
  )
})
