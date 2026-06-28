source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_multifold.R"))
source(test_path("..", "..", "R", "regime_pca_poc.R"))
source(test_path("..", "..", "R", "regime_pca_wfa_poc.R"))

test_that("PCA WFA context universe definitions keep AMD as target anchor", {
  defs <- g5_pca_wfa_context_universe_definitions("AMD")

  expect_equal(
    defs$universe_id,
    c("baseline_context", "similar_high_beta_tech_semis", "diverse_market_risk_context")
  )
  expect_equal(g5_pca_wfa_context_universe_symbols("baseline_context", "AMD"), c("AMD", "NVDA", "TSLA"))
  expect_true(all(vapply(strsplit(defs$symbols, ",", fixed = TRUE), function(x) x[[1L]] == "AMD", logical(1L))))
  expect_true(defs$symbol_count[[2L]] > defs$symbol_count[[1L]])
  expect_true(defs$symbol_count[[3L]] > defs$symbol_count[[2L]])
  expect_true(grepl("only traded symbol", defs$rationale[[3L]], fixed = TRUE))
})

test_that("PCA WFA context universe top-level report summarizes child comparison packets", {
  repo_root <- tempfile("g5_pcawfa_universe_repo_")
  dir.create(repo_root, recursive = TRUE)
  defs <- g5_pca_wfa_context_universe_definitions("AMD")

  for (i in seq_len(nrow(defs))) {
    symbols <- strsplit(defs$symbols[[i]], ",", fixed = TRUE)[[1L]]
    comparison_dir <- g5_pca_wfa_comparison_output_dir(
      repo_root = repo_root,
      as_of_timestamp = "2026-06-24 17:30:00",
      symbol = "AMD",
      fold_count = 5L,
      regime_context_symbols = symbols,
      wfa_end_date = as.Date("2026-06-24")
    )
    dir.create(comparison_dir, recursive = TRUE)
    utils::write.csv(
      data.frame(
        panel_mode = c("contextual_snapshot", "behavioral_pool"),
        state_map = c("quantile_grid", "kmeans"),
        state_count = c(3L, 9L),
        run_status = "ok",
        total_return = c(0.01, 0.02) * i,
        sharpe = c(0.3, 0.4) * i,
        max_drawdown = c(-0.05, -0.04),
        trade_count = c(2L, 3L),
        buy_hold_total_return = 0.1,
        oos_covered_states = c(3L, 6L),
        oos_state_count = c(9L, 9L),
        no_trade_state_selections = c(1L, 2L),
        selected_families = c("ema_cross,no_trade", "breakout,no_trade"),
        stringsAsFactors = FALSE
      ),
      file.path(comparison_dir, "pcawfa_cmp_summary.csv"),
      row.names = FALSE
    )
    writeLines("child comparison report", file.path(comparison_dir, "pcawfa_cmp_report.md"), useBytes = TRUE)
  }

  output_dir <- tempfile("g5_pcawfa_universe_packet_")
  written <- g5_write_pca_wfa_universe_comparison_outputs(
    universe_defs = defs,
    output_dir = output_dir,
    repo_root = repo_root,
    as_of_timestamp = "2026-06-24 17:30:00",
    symbol = "AMD",
    fold_count = 5L,
    wfa_end_date = as.Date("2026-06-24")
  )

  expect_true(file.exists(written$paths$universe_definitions_csv))
  expect_true(file.exists(written$paths$universe_index_csv))
  expect_true(file.exists(written$paths$summary_csv))
  expect_true(file.exists(written$paths$report_md))
  expect_equal(nrow(written$universe_index), 3L)
  expect_true(all(written$universe_index$run_status == "ok"))
  expect_equal(nrow(written$summary), 6L)
  expect_true(all(written$summary$universe_id %in% defs$universe_id))
  expect_true(all(grepl("pcawfa_cmp_equity_2x2.png", written$universe_index$equity_contact_sheet_png, fixed = TRUE)))

  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("Research Candidate Universe: `AMD`", report, fixed = TRUE)))
  expect_true(any(grepl("not final research evidence", report, fixed = TRUE)))
  expect_true(any(grepl("diverse_market_risk_context", report, fixed = TRUE)))
})
