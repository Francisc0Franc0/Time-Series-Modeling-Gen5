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

g5_test_write_context_factorial_portfolio_packets <- function(repo_root, active_symbols, defs, surfaces) {
  packet_no <- 0L
  for (s in seq_len(nrow(surfaces))) {
    for (i in seq_len(nrow(defs))) {
      packet_no <- packet_no + 1L
      symbols <- strsplit(defs$symbols[[i]], ",", fixed = TRUE)[[1L]]
      portfolio_dir <- g5_portfolio_poc_packet_dir(
        repo_root = repo_root,
        as_of_timestamp = "2026-06-24 17:30:00",
        active_symbols = active_symbols,
        fold_count = 5L,
        grid_n = surfaces$grid_n[[s]],
        state_engine = surfaces$state_engine[[s]],
        pca_panel_mode = surfaces$pca_panel_mode[[s]],
        regime_context_symbols = symbols,
        end_date = as.Date("2026-06-24"),
        strategy_grid_preset = "standard"
      )
      dir.create(portfolio_dir, recursive = TRUE)
      utils::write.csv(
        data.frame(
          schema_version = g5_portfolio_poc_schema_version(),
          initial_capital = 100000,
          ending_equity = 100000 + packet_no * 1000,
          total_return = packet_no * 0.01,
          cagr = packet_no * 0.02,
          sharpe = packet_no * 0.3,
          max_drawdown = -0.01 * packet_no,
          session_count = 100L,
          stringsAsFactors = FALSE
        ),
        file.path(portfolio_dir, "portfolio_poc_metrics.csv"),
        row.names = FALSE
      )
      utils::write.csv(
        data.frame(symbol = active_symbols, entry_fills = packet_no, cash_capped_entries = 0L, skipped_entries = 1L, stringsAsFactors = FALSE),
        file.path(portfolio_dir, "portfolio_poc_symbol_summary.csv"),
        row.names = FALSE
      )
      child_index <- do.call(rbind, lapply(seq_along(active_symbols), function(j) {
        run_dir <- file.path(portfolio_dir, active_symbols[[j]])
        dir.create(run_dir, recursive = TRUE)
        utils::write.csv(
          data.frame(
            schema_version = "test",
            symbol = active_symbols[[j]],
            total_return = packet_no * 0.01 + j * 0.001,
            sharpe = packet_no * 0.1,
            max_drawdown = -0.02,
            trade_count = j,
            closed_trade_count = j - 1L,
            buy_hold_total_return = packet_no * 0.02,
            stringsAsFactors = FALSE
          ),
          file.path(run_dir, "pcawfa_oos_metrics.csv"),
          row.names = FALSE
        )
        utils::write.csv(
          data.frame(
            split = c("TRAIN", "TRAIN", "OOS", "OOS"),
            state_id = c("S1", "S2", "S1", "S2"),
            row_count = c(20L, 0L, 5L, 3L),
            row_fraction = c(1, 0, 0.625, 0.375),
            stringsAsFactors = FALSE
          ),
          file.path(run_dir, "pcawfa_state_coverage.csv"),
          row.names = FALSE
        )
        utils::write.csv(
          data.frame(
            fold_id = c("fold_001", "fold_001"),
            state_id = c("S1", "S2"),
            strategy_family = c("ema_cross", "no_trade"),
            stringsAsFactors = FALSE
          ),
          file.path(run_dir, "pcawfa_selected_states.csv"),
          row.names = FALSE
        )
        data.frame(
          symbol = active_symbols[[j]],
          run_dir = run_dir,
          oos_metrics_csv = file.path(run_dir, "pcawfa_oos_metrics.csv"),
          stringsAsFactors = FALSE
        )
      }))
      utils::write.csv(child_index, file.path(portfolio_dir, "portfolio_poc_child_artifact_index.csv"), row.names = FALSE)
      writeLines("portfolio report", file.path(portfolio_dir, "portfolio_poc_report.md"), useBytes = TRUE)
      png(file.path(portfolio_dir, "portfolio_poc_equity_curves.png"), width = 500, height = 300)
      par(mar = c(3, 3, 1, 1))
      plot(1:3, 1:3)
      dev.off()
    }
  }
}

test_that("context-universe factorial writer summarizes portfolio packets", {
  repo_root <- tempfile("g5_context_factorial_repo_")
  dir.create(repo_root, recursive = TRUE)
  active_symbols <- c("AMD", "NVDA", "TSLA", "COIN", "MSTR")
  defs <- g5_context_factorial_universe_definitions(active_symbols)
  surfaces <- g5_context_factorial_surface_definitions(
    medium_grid = FALSE,
    pca_panel_mode = "pooled_asset_day",
    state_engine = "quantile_grid",
    grid_n = 3L
  )

  g5_test_write_context_factorial_portfolio_packets(repo_root, active_symbols, defs, surfaces)

  output_dir <- tempfile("g5_context_factorial_packet_")
  written <- g5_write_context_factorial_outputs(
    universe_defs = defs,
    surface_defs = surfaces,
    output_dir = output_dir,
    repo_root = repo_root,
    as_of_timestamp = "2026-06-24 17:30:00",
    end_date = as.Date("2026-06-24"),
    active_symbols = active_symbols,
    fold_count = 5L,
    strategy_grid_preset = "standard"
  )

  expect_true(file.exists(written$paths$report_md))
  expect_true(file.exists(written$paths$run_spec_csv))
  expect_true(file.exists(written$paths$taxonomy_csv))
  expect_true(file.exists(written$paths$surface_definitions_csv))
  expect_true(file.exists(written$paths$summary_csv))
  expect_true(file.exists(written$paths$portfolio_index_csv))
  expect_true(file.exists(written$paths$child_artifact_index_csv))
  expect_true(file.exists(written$paths$child_metric_summary_csv))
  expect_true(file.exists(written$paths$state_coverage_summary_csv))
  expect_true(file.exists(written$paths$selected_family_summary_csv))
  expect_true(file.exists(written$paths$metrics_overview_png))
  expect_true(file.exists(written$paths$visual_audit_index_csv))
  expect_equal(nrow(written$portfolio_index), 3L)
  expect_true(all(written$portfolio_index$run_status == "ok"))
  expect_equal(nrow(written$summary), 3L)
  expect_equal(nrow(written$child_artifact_index), 15L)
  expect_equal(nrow(written$child_metric_summary), 15L)
  expect_equal(nrow(written$state_coverage_summary), 15L)
  expect_equal(nrow(written$selected_family_summary), 15L)

  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("This first test asks whether", report, fixed = TRUE)))
  expect_true(any(grepl("external market-risk context only", report, fixed = TRUE)))
  expect_true(any(grepl("not accepted allocation evidence", report, fixed = TRUE)))
  expect_true(any(grepl("PCA Surfaces", report, fixed = TRUE)))
  expect_true(any(grepl("Child Summaries", report, fixed = TRUE)))
  expect_true(any(grepl("Visual Audit", report, fixed = TRUE)))
})

test_that("medium context-universe factorial writer indexes all PCA surfaces", {
  repo_root <- tempfile("g5_context_factorial_medium_repo_")
  dir.create(repo_root, recursive = TRUE)
  active_symbols <- c("AMD", "NVDA", "TSLA", "COIN", "MSTR")
  defs <- g5_context_factorial_universe_definitions(active_symbols)
  surfaces <- g5_context_factorial_surface_definitions(medium_grid = TRUE)

  expect_equal(nrow(surfaces), 4L)
  expect_equal(
    surfaces$surface_id,
    c(
      "contextual_snapshot_quantile_grid",
      "contextual_snapshot_kmeans",
      "behavioral_pool_quantile_grid",
      "behavioral_pool_kmeans"
    )
  )

  g5_test_write_context_factorial_portfolio_packets(repo_root, active_symbols, defs, surfaces)

  output_dir <- tempfile("g5_context_factorial_medium_packet_")
  written <- g5_write_context_factorial_outputs(
    universe_defs = defs,
    surface_defs = surfaces,
    output_dir = output_dir,
    repo_root = repo_root,
    as_of_timestamp = "2026-06-24 17:30:00",
    end_date = as.Date("2026-06-24"),
    active_symbols = active_symbols,
    fold_count = 5L,
    strategy_grid_preset = "standard"
  )

  expect_equal(nrow(written$portfolio_index), 12L)
  expect_equal(nrow(written$summary), 12L)
  expect_equal(nrow(written$child_artifact_index), 60L)
  expect_equal(nrow(written$child_metric_summary), 60L)
  expect_equal(nrow(written$state_coverage_summary), 60L)
  expect_equal(nrow(written$selected_family_summary), 60L)
  expect_equal(unique(written$run_spec$surface_count), 4L)
  expect_true(all(surfaces$surface_id %in% written$portfolio_index$surface_id))
  expect_true(all(c("surface_id", "pca_panel_mode", "state_engine", "state_count") %in% names(written$child_artifact_index)))
  expect_true(file.exists(written$paths$surface_definitions_csv))
  expect_true(file.exists(written$paths$child_metric_summary_csv))
})

test_that("active-plus-risk state-map triage defines quantile, fixed k, and auto k surfaces", {
  active_symbols <- c("AMD", "NVDA", "TSLA", "COIN", "MSTR")
  defs <- g5_context_factorial_universe_definitions(active_symbols)
  defs <- defs[defs$universe_id == "active_plus_risk_context", , drop = FALSE]
  surfaces <- g5_context_factorial_surface_definitions(state_map_triage = TRUE)

  expect_equal(nrow(defs), 1L)
  expect_equal(nrow(surfaces), 3L)
  expect_equal(
    surfaces$surface_id,
    c(
      "behavioral_pool_quantile_grid_3x3",
      "behavioral_pool_kmeans_k9",
      "behavioral_pool_kmeans_auto_max9"
    )
  )
  expect_equal(surfaces$state_engine, c("quantile_grid", "pca_kmeans", "pca_kmeans_auto"))
  expect_equal(surfaces$grid_n, c(3L, 9L, 9L))
  expect_equal(surfaces$state_count, c("3x3", "k9", "kauto9"))
})

test_that("active-plus-risk fixed-k scale triage defines 3x3, k9, and k15 surfaces", {
  surfaces <- g5_context_factorial_surface_definitions(fixed_k_scale_triage = TRUE)

  expect_equal(nrow(surfaces), 3L)
  expect_equal(
    surfaces$surface_id,
    c(
      "behavioral_pool_quantile_grid_3x3",
      "behavioral_pool_kmeans_k9",
      "behavioral_pool_kmeans_k15"
    )
  )
  expect_equal(surfaces$state_engine, c("quantile_grid", "pca_kmeans", "pca_kmeans"))
  expect_equal(surfaces$grid_n, c(3L, 9L, 15L))
  expect_equal(surfaces$state_count, c("3x3", "k9", "k15"))
})

test_that("active-plus-risk state-map triage writes visual audit contact sheets", {
  repo_root <- file.path(tempdir(), "g5cfv")
  unlink(repo_root, recursive = TRUE, force = TRUE)
  dir.create(repo_root, recursive = TRUE)
  active_symbols <- c("AMD", "NVDA", "TSLA", "COIN", "MSTR")
  defs <- g5_context_factorial_universe_definitions(active_symbols)
  defs <- defs[defs$universe_id == "active_plus_risk_context", , drop = FALSE]
  surfaces <- g5_context_factorial_surface_definitions(state_map_triage = TRUE)

  g5_test_write_context_factorial_portfolio_packets(repo_root, active_symbols, defs, surfaces)

  output_dir <- tempfile("g5_context_factorial_visual_packet_")
  written <- g5_write_context_factorial_outputs(
    universe_defs = defs,
    surface_defs = surfaces,
    output_dir = output_dir,
    repo_root = repo_root,
    as_of_timestamp = "2026-06-24 17:30:00",
    end_date = as.Date("2026-06-24"),
    active_symbols = active_symbols,
    fold_count = 5L,
    strategy_grid_preset = "standard",
    purpose = g5_context_factorial_state_map_triage_purpose()
  )

  expect_true(file.exists(written$paths$visual_audit_index_csv))
  expect_equal(nrow(written$visual_audit_index), 12L)
  expect_true(all(file.exists(written$visual_audit_index$path)))
  expect_true(all(c("quantile_vs_fixed_k9", "auto_kmeans") %in% written$visual_audit_index$chart_group))
  expect_true(all(c("pca_scatter", "stitched_oos_states") %in% written$visual_audit_index$chart_type))
  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("TRAIN-only auto k-means", report, fixed = TRUE)))
  expect_true(any(grepl("Visual audit index", report, fixed = TRUE)))
})

test_that("active-plus-risk fixed-k scale triage writes three-panel visual audit contact sheets", {
  repo_root <- file.path(tempdir(), "g5cff")
  unlink(repo_root, recursive = TRUE, force = TRUE)
  dir.create(repo_root, recursive = TRUE)
  active_symbols <- c("AMD", "NVDA", "TSLA", "COIN", "MSTR")
  defs <- g5_context_factorial_universe_definitions(active_symbols)
  defs <- defs[defs$universe_id == "active_plus_risk_context", , drop = FALSE]
  surfaces <- g5_context_factorial_surface_definitions(fixed_k_scale_triage = TRUE)

  g5_test_write_context_factorial_portfolio_packets(repo_root, active_symbols, defs, surfaces)

  output_dir <- tempfile("g5_context_factorial_fixed_k_visual_packet_")
  written <- g5_write_context_factorial_outputs(
    universe_defs = defs,
    surface_defs = surfaces,
    output_dir = output_dir,
    repo_root = repo_root,
    as_of_timestamp = "2026-06-24 17:30:00",
    end_date = as.Date("2026-06-24"),
    active_symbols = active_symbols,
    fold_count = 5L,
    strategy_grid_preset = "standard",
    purpose = g5_context_factorial_fixed_k_scale_triage_purpose()
  )

  expect_true(file.exists(written$paths$visual_audit_index_csv))
  expect_true(all(file.exists(written$visual_audit_index$path)))
  expect_true("fixed_k_scale" %in% written$visual_audit_index$chart_group)
  fixed_scale_index <- written$visual_audit_index[written$visual_audit_index$chart_group == "fixed_k_scale", , drop = FALSE]
  expect_equal(nrow(fixed_scale_index), 10L)
  expect_true(all(c("pca_scatter", "stitched_oos_states") %in% fixed_scale_index$chart_type))
  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("fixed k-means with k=15", report, fixed = TRUE)))
})
