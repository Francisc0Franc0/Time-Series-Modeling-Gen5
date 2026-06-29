source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_multifold.R"))
source(test_path("..", "..", "R", "regime_pca_poc.R"))
source(test_path("..", "..", "R", "regime_pca_wfa_poc.R"))
source(test_path("..", "..", "R", "portfolio_strategy_poc.R"))

test_that("behavioral-pool context can fit on external context and score target rows", {
  dates <- as.Date("2024-01-01") + 0:260
  bars <- do.call(rbind, lapply(c("AMD", "SPY", "QQQ"), function(symbol) {
    base <- switch(symbol, AMD = 100, SPY = 400, QQQ = 300)
    close <- base + seq_along(dates) * switch(symbol, AMD = 0.5, SPY = 0.2, QQQ = 0.3)
    data.frame(
      schema_version = "test",
      symbol = symbol,
      session_date = dates,
      open = close - 0.2,
      high = close + 1,
      low = close - 1,
      close = close,
      volume = 1000000 + seq_along(dates),
      adjusted = TRUE,
      timeframe = "1D",
      provider = "test",
      as_of_timestamp = "2026-06-24 17:30:00",
      latest_completed_session = as.Date("2026-06-24"),
      fetch_start_date = min(dates),
      fetch_end_date = max(dates),
      data_version_hash = paste0("test_", symbol),
      stringsAsFactors = FALSE
    )
  }))

  features <- g5_pca_regime_pooled_feature_table(
    bars,
    target_symbol = "AMD",
    context_symbols = c("SPY", "QQQ"),
    end_date = max(dates)
  )

  expect_true(any(features$symbol == "AMD"))
  expect_true(all(features$pca_training_role[features$symbol == "AMD"] == "routing_target_only"))
  expect_true(all(features$pca_training_role[features$symbol %in% c("SPY", "QQQ")] == "context"))
  expect_equal(unique(features$regime_context_symbols), "SPY,QQQ")

  fit <- g5_pca_regime_fit(
    features,
    train_start_date = as.Date("2024-04-15"),
    train_end_date = as.Date("2024-08-15"),
    oos_start_date = as.Date("2024-08-16"),
    oos_end_date = as.Date("2024-09-15"),
    min_train_rows = 20L
  )
  target_scores <- fit$scores[fit$scores$symbol == "AMD", , drop = FALSE]
  expect_gt(nrow(target_scores), 0L)
  expect_true(any(fit$model_contract$key == "fit_row_policy" & grepl("pca_training_role=context", fit$model_contract$value, fixed = TRUE)))
})

test_that("context-universe factorial writer summarizes portfolio packets", {
  repo_root <- tempfile("g5_context_factorial_repo_")
  dir.create(repo_root, recursive = TRUE)
  active_symbols <- c("AMD", "NVDA", "TSLA", "COIN", "MSTR")
  defs <- g5_context_factorial_universe_definitions(active_symbols)

  for (i in seq_len(nrow(defs))) {
    symbols <- strsplit(defs$symbols[[i]], ",", fixed = TRUE)[[1L]]
    portfolio_dir <- g5_portfolio_poc_packet_dir(
      repo_root = repo_root,
      as_of_timestamp = "2026-06-24 17:30:00",
      active_symbols = active_symbols,
      fold_count = 5L,
      grid_n = 3L,
      state_engine = "quantile_grid",
      pca_panel_mode = "pooled_asset_day",
      regime_context_symbols = symbols,
      end_date = as.Date("2026-06-24"),
      strategy_grid_preset = "standard"
    )
    dir.create(portfolio_dir, recursive = TRUE)
    utils::write.csv(
      data.frame(
        schema_version = g5_portfolio_poc_schema_version(),
        initial_capital = 100000,
        ending_equity = 100000 + i * 1000,
        total_return = i * 0.01,
        cagr = i * 0.02,
        sharpe = i * 0.3,
        max_drawdown = -0.05 * i,
        session_count = 100L,
        stringsAsFactors = FALSE
      ),
      file.path(portfolio_dir, "portfolio_poc_metrics.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      data.frame(symbol = active_symbols, entry_fills = i, cash_capped_entries = 0L, skipped_entries = 1L, stringsAsFactors = FALSE),
      file.path(portfolio_dir, "portfolio_poc_symbol_summary.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      data.frame(symbol = active_symbols, run_dir = file.path(portfolio_dir, active_symbols), stringsAsFactors = FALSE),
      file.path(portfolio_dir, "portfolio_poc_child_artifact_index.csv"),
      row.names = FALSE
    )
    writeLines("portfolio report", file.path(portfolio_dir, "portfolio_poc_report.md"), useBytes = TRUE)
    png(file.path(portfolio_dir, "portfolio_poc_equity_curves.png"), width = 500, height = 300)
    par(mar = c(3, 3, 1, 1))
    plot(1:3, 1:3)
    dev.off()
  }

  output_dir <- tempfile("g5_context_factorial_packet_")
  written <- g5_write_context_factorial_outputs(
    universe_defs = defs,
    output_dir = output_dir,
    repo_root = repo_root,
    as_of_timestamp = "2026-06-24 17:30:00",
    end_date = as.Date("2026-06-24"),
    active_symbols = active_symbols,
    fold_count = 5L,
    grid_n = 3L,
    state_engine = "quantile_grid",
    pca_panel_mode = "pooled_asset_day",
    strategy_grid_preset = "standard"
  )

  expect_true(file.exists(written$paths$report_md))
  expect_true(file.exists(written$paths$run_spec_csv))
  expect_true(file.exists(written$paths$taxonomy_csv))
  expect_true(file.exists(written$paths$summary_csv))
  expect_true(file.exists(written$paths$portfolio_index_csv))
  expect_true(file.exists(written$paths$child_artifact_index_csv))
  expect_true(file.exists(written$paths$metrics_overview_png))
  expect_equal(nrow(written$portfolio_index), 3L)
  expect_true(all(written$portfolio_index$run_status == "ok"))
  expect_equal(nrow(written$summary), 3L)
  expect_equal(nrow(written$child_artifact_index), 15L)

  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("This first test asks whether", report, fixed = TRUE)))
  expect_true(any(grepl("external market-risk context only", report, fixed = TRUE)))
  expect_true(any(grepl("not accepted allocation evidence", report, fixed = TRUE)))
})
