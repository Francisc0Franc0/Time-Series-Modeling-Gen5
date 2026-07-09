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

test_that("active-plus-risk auto max15 triage defines 3x3, k9, and auto max15 surfaces", {
  surfaces <- g5_context_factorial_surface_definitions(auto_max15_triage = TRUE)

  expect_equal(nrow(surfaces), 3L)
  expect_equal(
    surfaces$surface_id,
    c(
      "behavioral_pool_quantile_grid_3x3",
      "behavioral_pool_kmeans_k9",
      "behavioral_pool_kmeans_auto_max15"
    )
  )
  expect_equal(surfaces$state_engine, c("quantile_grid", "pca_kmeans", "pca_kmeans_auto"))
  expect_equal(surfaces$grid_n, c(3L, 9L, 15L))
  expect_equal(surfaces$state_count, c("3x3", "k9", "kauto15"))
})

test_that("temporal context replication defines behavioral-pool 3x3 and fixed k9 surfaces", {
  surfaces <- g5_context_factorial_surface_definitions(temporal_context_replication = TRUE)

  expect_equal(nrow(surfaces), 2L)
  expect_equal(
    surfaces$surface_id,
    c(
      "behavioral_pool_quantile_grid_3x3",
      "behavioral_pool_kmeans_k9"
    )
  )
  expect_equal(surfaces$pca_panel_mode, c("pooled_asset_day", "pooled_asset_day"))
  expect_equal(surfaces$state_engine, c("quantile_grid", "pca_kmeans"))
  expect_equal(surfaces$grid_n, c(3L, 9L))
  expect_equal(surfaces$state_count, c("3x3", "k9"))
  expect_match(
    g5_context_factorial_temporal_replication_purpose(),
    "late-2024 through mid-2026",
    fixed = TRUE
  )
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

test_that("active-plus-risk auto max15 triage writes visual audit contact sheets", {
  repo_root <- file.path(tempdir(), "g5cff")
  unlink(repo_root, recursive = TRUE, force = TRUE)
  dir.create(repo_root, recursive = TRUE)
  active_symbols <- c("AMD", "NVDA", "TSLA", "COIN", "MSTR")
  defs <- g5_context_factorial_universe_definitions(active_symbols)
  defs <- defs[defs$universe_id == "active_plus_risk_context", , drop = FALSE]
  surfaces <- g5_context_factorial_surface_definitions(auto_max15_triage = TRUE)

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
    purpose = g5_context_factorial_auto_max15_triage_purpose()
  )

  expect_true(file.exists(written$paths$visual_audit_index_csv))
  expect_true(all(file.exists(written$visual_audit_index$path)))
  expect_true("auto_max15_triage" %in% written$visual_audit_index$chart_group)
  expect_true("auto_kmeans" %in% written$visual_audit_index$chart_group)
  triage_index <- written$visual_audit_index[written$visual_audit_index$chart_group == "auto_max15_triage", , drop = FALSE]
  expect_equal(nrow(triage_index), 10L)
  expect_true(all(c("pca_scatter", "stitched_oos_states") %in% triage_index$chart_type))
  auto_index <- written$visual_audit_index[written$visual_audit_index$chart_group == "auto_kmeans", , drop = FALSE]
  expect_equal(nrow(auto_index), 2L)
  expect_true(all(c("pca_scatter", "stitched_oos_states") %in% auto_index$chart_type))
  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("selecting k from 2..15", report, fixed = TRUE)))
})

g5_test_write_window_compare_packet <- function(packet_dir, surfaces, total_return_offset = 0) {
  dir.create(packet_dir, recursive = TRUE)
  utils::write.csv(
    data.frame(
      universe_id = "active_plus_risk_context",
      surface_id = surfaces,
      run_status = "ok",
      ending_equity = 100000 + seq_along(surfaces) * 1000,
      total_return = total_return_offset + seq_along(surfaces) * 0.01,
      cagr = total_return_offset + seq_along(surfaces) * 0.01,
      sharpe = seq_along(surfaces) * 0.2,
      max_drawdown = -seq_along(surfaces) * 0.03,
      total_entry_fills = seq_along(surfaces) * 10L,
      total_skipped_entries = 0L,
      total_cash_capped_entries = 0L,
      stringsAsFactors = FALSE
    ),
    file.path(packet_dir, "context_universe_factorial_summary.csv"),
    row.names = FALSE
  )
  child_rows <- list()
  for (surface in surfaces) {
    for (symbol in c("AMD", "NVDA")) {
      run_dir <- file.path(packet_dir, paste(surface, symbol, sep = "_"))
      dir.create(run_dir, recursive = TRUE)
      utils::write.csv(
        data.frame(
          split = rep(c("TRAIN", "OOS"), each = 2),
          state_id = rep(c("S1", "S2"), 2),
          row_count = c(30L, 4L, 6L, 1L),
          row_fraction = c(0.88, 0.12, 0.86, 0.14),
          fold_id = "fold_001",
          fold_no = 1L,
          stringsAsFactors = FALSE
        ),
        file.path(run_dir, "pcawfa_state_coverage.csv"),
        row.names = FALSE
      )
      utils::write.csv(
        data.frame(
          fold_id = "fold_001",
          fold_no = 1L,
          state_id = c("S1", "S2"),
          strategy_family = c("ema_cross", "no_trade"),
          stringsAsFactors = FALSE
        ),
        file.path(run_dir, "pcawfa_selected_states.csv"),
        row.names = FALSE
      )
      child_rows[[length(child_rows) + 1L]] <- data.frame(
        universe_id = "active_plus_risk_context",
        surface_id = surface,
        pca_panel_mode = "pooled_asset_day",
        state_engine = if (grepl("auto", surface)) "pca_kmeans_auto" else if (grepl("kmeans", surface)) "pca_kmeans" else "quantile_grid",
        state_count = if (grepl("max15", surface)) "kauto15" else if (grepl("auto", surface)) "kauto9" else if (grepl("k9", surface)) "k9" else "3x3",
        symbol = symbol,
        run_dir = run_dir,
        oos_metrics_csv = file.path(run_dir, "pcawfa_oos_metrics.csv"),
        stringsAsFactors = FALSE
      )
    }
  }
  utils::write.csv(do.call(rbind, child_rows), file.path(packet_dir, "context_universe_factorial_child_artifact_index.csv"), row.names = FALSE)
  auto_surfaces <- surfaces[grepl("auto", surfaces)]
  if (length(auto_surfaces)) {
    utils::write.csv(
      do.call(rbind, lapply(auto_surfaces, function(surface) {
        data.frame(
          universe_id = "active_plus_risk_context",
          surface_id = surface,
          symbol = "AMD",
          fold_id = "fold_001",
          fold_no = 1L,
          cluster_count_mode = "auto",
          auto_min_clusters = 2L,
          auto_max_clusters = if (grepl("max15", surface)) 15L else 9L,
          selected_cluster_count = if (grepl("max15", surface)) 13L else 5L,
          selection_criterion = "calinski_harabasz_train_pc1_pc2",
          stringsAsFactors = FALSE
        )
      })),
      file.path(packet_dir, "context_universe_factorial_auto_clusters.csv"),
      row.names = FALSE
    )
  } else {
    utils::write.csv(data.frame(), file.path(packet_dir, "context_universe_factorial_auto_clusters.csv"), row.names = FALSE)
  }
}

test_that("two-window comparison reads existing packets and writes diagnostics", {
  repo_root <- tempfile("g5_context_window_repo_")
  dir.create(repo_root, recursive = TRUE)
  packet_root <- file.path(repo_root, "packets")
  max9_surfaces <- c("behavioral_pool_quantile_grid_3x3", "behavioral_pool_kmeans_k9", "behavioral_pool_kmeans_auto_max9")
  max15_surfaces <- c("behavioral_pool_kmeans_auto_max15")
  source_packets <- data.frame(
    window_id = c("jun_2026", "jun_2026", "mar_2026", "mar_2026"),
    window_label = c("June", "June", "March", "March"),
    packet_role = c("max9_packet", "max15_packet", "max9_packet", "max15_packet"),
    packet_dir = file.path(packet_root, c("jun_max9", "jun_max15", "mar_max9", "mar_max15")),
    stringsAsFactors = FALSE
  )
  g5_test_write_window_compare_packet(source_packets$packet_dir[[1L]], max9_surfaces, 0.10)
  g5_test_write_window_compare_packet(source_packets$packet_dir[[2L]], max15_surfaces, 0.10)
  g5_test_write_window_compare_packet(source_packets$packet_dir[[3L]], max9_surfaces, -0.05)
  g5_test_write_window_compare_packet(source_packets$packet_dir[[4L]], max15_surfaces, -0.05)

  output_dir <- file.path(repo_root, "comparison")
  written <- g5_write_context_factorial_window_comparison(repo_root, output_dir, source_packets)

  expect_true(file.exists(written$paths$report_md))
  expect_true(file.exists(written$paths$merged_summary_csv))
  expect_true(file.exists(written$paths$auto_clusters_csv))
  expect_true(file.exists(written$paths$fold_diagnostics_csv))
  expect_true(file.exists(written$paths$diagnostic_summary_csv))
  expect_true(file.exists(written$paths$metrics_chart_png))
  expect_true(file.exists(written$paths$auto_cluster_chart_png))
  expect_true(file.exists(written$paths$fragmentation_chart_png))
  expect_equal(nrow(written$summary), 8L)
  expect_true(all(c("quantile_3x3", "fixed_k9", "auto_max9", "auto_max15") %in% written$summary$comparison_surface_id))
  expect_gt(nrow(written$fold_diagnostics), 0L)
  expect_gt(nrow(written$diagnostic_summary), 0L)
  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("Two-Window State-Map Comparison", report, fixed = TRUE)))
  expect_true(any(grepl("Fragmentation Diagnostics", report, fixed = TRUE)))
})

g5_test_write_temporal_packet <- function(packet_dir, window_return_offset = 0) {
  dir.create(packet_dir, recursive = TRUE)
  universes <- c("active_self_context", "active_plus_risk_context", "ex_active_market_risk_context")
  surfaces <- c("behavioral_pool_quantile_grid_3x3", "behavioral_pool_kmeans_k9")
  grid <- expand.grid(universe_id = universes, surface_id = surfaces, stringsAsFactors = FALSE)
  grid$total_return <- window_return_offset + seq_len(nrow(grid)) * 0.01
  grid$run_status <- "ok"
  grid$ending_equity <- 100000 * (1 + grid$total_return)
  grid$cagr <- grid$total_return
  grid$sharpe <- seq_len(nrow(grid)) * 0.1
  grid$max_drawdown <- -seq_len(nrow(grid)) * 0.02
  grid$total_entry_fills <- seq_len(nrow(grid)) * 5L
  grid$total_skipped_entries <- 0L
  grid$total_cash_capped_entries <- 0L
  utils::write.csv(grid, file.path(packet_dir, "context_universe_factorial_summary.csv"), row.names = FALSE)
  utils::write.csv(
    data.frame(
      chart_group = "quantile_vs_fixed_k9",
      chart_type = "pca_scatter",
      symbol = "AMD",
      page_no = 1L,
      path = file.path(packet_dir, "amd.png"),
      stringsAsFactors = FALSE
    ),
    file.path(packet_dir, "context_universe_factorial_visual_audit_index.csv"),
    row.names = FALSE
  )
}

test_that("temporal context replication summary reads packets and writes rank artifacts", {
  repo_root <- tempfile("g5_context_temporal_repo_")
  dir.create(repo_root, recursive = TRUE)
  packet_root <- file.path(repo_root, "packets")
  source_packets <- data.frame(
    window_id = c("w1", "w2"),
    window_label = c("Window 1", "Window 2"),
    packet_dir = file.path(packet_root, c("w1", "w2")),
    stringsAsFactors = FALSE
  )
  g5_test_write_temporal_packet(source_packets$packet_dir[[1L]], 0.00)
  g5_test_write_temporal_packet(source_packets$packet_dir[[2L]], 0.05)

  output_dir <- file.path(repo_root, "summary")
  written <- g5_write_context_factorial_temporal_summary(repo_root, output_dir, source_packets)

  expect_true(file.exists(written$paths$report_md))
  expect_true(file.exists(written$paths$merged_summary_csv))
  expect_true(file.exists(written$paths$rank_summary_csv))
  expect_true(file.exists(written$paths$visual_index_csv))
  expect_true(file.exists(written$paths$metrics_chart_png))
  expect_equal(nrow(written$summary), 12L)
  expect_equal(nrow(written$ranks), 6L)
  expect_true(all(c("mean_total_return", "return_rank_1_count", "negative_return_count") %in% names(written$ranks)))
  report <- readLines(written$paths$report_md, warn = FALSE)
  expect_true(any(grepl("Temporal Context-Universe Replication Summary", report, fixed = TRUE)))
  expect_true(any(grepl("Cross-Window Ranks", report, fixed = TRUE)))
})
