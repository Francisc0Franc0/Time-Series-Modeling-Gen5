source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "strategy_ema_cross.R"))
source(test_path("..", "..", "R", "strategy_bollinger_touch.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_poc.R"))
source(test_path("..", "..", "R", "wfa_ema_cross_multifold.R"))
source(test_path("..", "..", "R", "regime_pca_poc.R"))
source(test_path("..", "..", "R", "regime_pca_wfa_poc.R"))

test_that("PCA WFA comparison report summarizes child packets", {
  root <- tempfile("g5_pcawfa_cmp_children_")
  dir.create(root, recursive = TRUE)
  run_index <- data.frame(
    panel_mode = c("contextual_snapshot", "contextual_snapshot", "behavioral_pool", "behavioral_pool"),
    state_map = c("quantile_grid", "kmeans", "quantile_grid", "kmeans"),
    internal_panel_mode = c("date_aligned_context", "date_aligned_context", "pooled_asset_day", "pooled_asset_day"),
    state_engine = c("quantile_grid", "pca_kmeans", "quantile_grid", "pca_kmeans"),
    state_count = c(3L, 9L, 3L, 9L),
    run_dir = file.path(root, c("aligned_grid", "aligned_kmeans", "pooled_grid", "pooled_kmeans")),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(run_index))) {
    dir.create(run_index$run_dir[[i]], recursive = TRUE)
    utils::write.csv(
      data.frame(
        total_return = 0.01 * i,
        sharpe = 0.2 * i,
        max_drawdown = -0.03 * i,
        trade_count = i + 1L,
        buy_hold_total_return = 0.05,
        stringsAsFactors = FALSE
      ),
      file.path(run_index$run_dir[[i]], "pcawfa_oos_metrics.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      data.frame(
        fold_id = c("fold_1", "fold_1", "fold_2"),
        state_id = c("S1_1", "S1_2", "S1_1"),
        strategy_family = c("ema_cross", "no_trade", "ema_cross"),
        strategy_spec_id = c("ema_a", "no_trade", "ema_a"),
        stringsAsFactors = FALSE
      ),
      file.path(run_index$run_dir[[i]], "pcawfa_selected_states.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      data.frame(
        split = c("TRAIN", "TRAIN", "OOS", "OOS", "OOS"),
        state_id = c("S1_1", "S1_2", "S1_1", "S1_2", "S1_3"),
        row_count = c(20L, 10L, 5L, 0L, 15L),
        row_fraction = c(0.667, 0.333, 0.25, 0, 0.75),
        stringsAsFactors = FALSE
      ),
      file.path(run_index$run_dir[[i]], "pcawfa_state_coverage.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      data.frame(
        fold_id = rep(c("fold_1", "fold_2"), each = 6L),
        fold_no = rep(c(1L, 2L), each = 6L),
        split = rep(c("TRAIN", "TRAIN", "TRAIN", "OOS", "OOS", "OOS"), 2L),
        session_date = as.Date("2025-01-01") + seq_len(12L),
        open = 100 + seq_len(12L),
        high = 102 + seq_len(12L),
        low = 99 + seq_len(12L),
        close = 101 + seq_len(12L),
        pc1 = seq(-1, 1, length.out = 12L) + i / 10,
        pc2 = rev(seq(-1, 1, length.out = 12L)) - i / 10,
        state_id = rep(c("S1_1", "S1_2", "S1_3"), 4L),
        stringsAsFactors = FALSE
      ),
      file.path(run_index$run_dir[[i]], "pcawfa_pca_scores.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      data.frame(
        fold_id = c("fold_1", "fold_2"),
        train_start_date = as.Date(c("2024-01-01", "2024-04-01")),
        train_end_date = as.Date(c("2024-12-31", "2025-03-31")),
        oos_start_date = as.Date(c("2025-01-05", "2025-01-11")),
        oos_end_date = as.Date(c("2025-01-10", "2025-01-12")),
        stringsAsFactors = FALSE
      ),
      file.path(run_index$run_dir[[i]], "pcawfa_folds.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      data.frame(
        session_date = as.Date("2025-01-05") + 0:7,
        strategy_equity = cumprod(1 + rep(0.01 * i, 8L)),
        buy_hold_equity = cumprod(1 + rep(0.005, 8L)),
        stringsAsFactors = FALSE
      ),
      file.path(run_index$run_dir[[i]], "pcawfa_oos_equity.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      data.frame(
        entry_execution_date = as.Date("2025-01-06"),
        entry_execution_price = 102,
        trace_end_date = as.Date("2025-01-09"),
        trace_end_price = 105,
        exit_execution_date = as.Date("2025-01-09"),
        exit_execution_price = 105,
        trade_outcome = "win",
        stringsAsFactors = FALSE
      ),
      file.path(run_index$run_dir[[i]], "pcawfa_oos_trades.csv"),
      row.names = FALSE
    )
    writeLines("child report", file.path(run_index$run_dir[[i]], "pcawfa_report.md"), useBytes = TRUE)
  }

  output_dir <- tempfile("g5_pcawfa_cmp_packet_")
  written <- g5_write_pca_wfa_comparison_outputs(
    run_index = run_index,
    output_dir = output_dir,
    settings = list(
      symbol = "AMD",
      regime_context_symbols = c("AMD", "NVDA", "TSLA"),
      fold_count = 5L,
      end_date = as.Date("2026-06-24"),
      as_of_timestamp = "2026-06-24 17:30:00"
    )
  )

  expect_true(file.exists(written$paths$summary_csv))
  expect_true(file.exists(written$paths$selected_family_counts_csv))
  expect_true(file.exists(written$paths$path_index_csv))
  expect_true(file.exists(written$paths$equity_contact_sheet_png))
  expect_true(file.exists(written$paths$strategy_contact_sheet_png))
  expect_true(file.exists(written$paths$pca_scatter_contact_sheet_png))
  expect_true(file.exists(written$paths$report_md))
  expect_gt(file.info(written$paths$equity_contact_sheet_png)$size, 0)
  expect_gt(file.info(written$paths$strategy_contact_sheet_png)$size, 0)
  expect_gt(file.info(written$paths$pca_scatter_contact_sheet_png)$size, 0)
  expect_equal(nrow(written$summary), 4L)
  expect_true(all(written$summary$run_status == "ok"))
  expect_equal(written$summary$oos_covered_states, rep(2L, 4L))
  expect_true(any(written$selected_family_counts$strategy_family == "no_trade"))
  expect_true(all(c("report_md", "oos_metrics_csv", "pca_scatter_png", "state_strategy_chart_png") %in% names(written$path_index)))
  expect_true(all(file.exists(written$path_index$pca_scatter_png)))
  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("entry_state_owns_trade_until_exit", report, fixed = TRUE)))
  expect_true(any(grepl("contextual_snapshot", report, fixed = TRUE)))
  expect_true(any(grepl("Contact Sheets", report, fixed = TRUE)))
})

test_that("PCA WFA comparison resolver finds actual resolved-fold output folders", {
  repo_root <- tempfile("g5_pcawfa_find_repo_")
  expected_dir <- file.path(
    repo_root,
    "runs",
    "research_workbench",
    "regime_wfa_pocs",
    "pcawfa_AMD_5f_3x3_aligned3a_11fam_20230327_20260624_20260624173000"
  )
  dir.create(expected_dir, recursive = TRUE)
  families <- c(
    "ema_cross",
    "ema_trend",
    "bollinger_touch",
    "bollinger_mid_reversion",
    "rsi_mr",
    "zret_mr",
    "breakout",
    "pullback_in_uptrend",
    "vol_expansion_breakout",
    "donchian_breakout_vol_expand",
    "no_trade"
  )

  found <- g5_pca_wfa_find_output_dir(
    repo_root = repo_root,
    as_of_timestamp = "2026-06-24 17:30:00",
    symbol = "AMD",
    fold_count = 5L,
    grid_n = 3L,
    wfa_end_date = as.Date("2026-06-24"),
    candidate_families = families,
    state_engine = "quantile_grid",
    regime_context_symbols = c("AMD", "NVDA", "TSLA"),
    pca_panel_mode = "date_aligned_context",
    fallback_wfa_start_date = as.Date("2023-03-25")
  )

  expect_equal(found, normalizePath(expected_dir, winslash = "/", mustWork = FALSE))
})

test_that("PCA WFA artifact paths distinguish expanded strategy grid preset", {
  families <- c("ema_cross", "bollinger_touch", "no_trade")
  standard <- g5_pca_wfa_artifact_prefix(
    as_of_timestamp = "2026-06-24 17:30:00",
    symbol = "AMD",
    fold_count = 5L,
    grid_n = 3L,
    wfa_start_date = as.Date("2024-01-01"),
    wfa_end_date = as.Date("2026-06-24"),
    candidate_families = families,
    state_engine = "quantile_grid",
    regime_context_symbols = c("AMD", "NVDA", "TSLA"),
    pca_panel_mode = "date_aligned_context"
  )
  expanded <- g5_pca_wfa_artifact_prefix(
    as_of_timestamp = "2026-06-24 17:30:00",
    symbol = "AMD",
    fold_count = 5L,
    grid_n = 3L,
    wfa_start_date = as.Date("2024-01-01"),
    wfa_end_date = as.Date("2026-06-24"),
    candidate_families = families,
    state_engine = "quantile_grid",
    regime_context_symbols = c("AMD", "NVDA", "TSLA"),
    pca_panel_mode = "date_aligned_context",
    strategy_grid_preset = "modest_expanded"
  )

  expect_false(grepl("gridmodestexpanded", standard, fixed = TRUE))
  expect_true(grepl("gridmodestexpanded", expanded, fixed = TRUE))
  expect_false(identical(standard, expanded))
})
