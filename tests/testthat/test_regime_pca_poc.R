source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "workbench_chart.R"))
source(test_path("..", "..", "R", "regime_pca_poc.R"))

g5_test_pca_bars <- function(n = 360L, symbol = "AMD", start = as.Date("2025-01-01")) {
  i <- seq_len(n)
  close <- 100 + 0.10 * i + 8 * sin(i / 13) + 2 * sin(i / 3)
  open <- close * (1 + 0.002 * sin(i / 5))
  high <- pmax(open, close) * 1.01
  low <- pmin(open, close) * 0.99
  data.frame(
    symbol = symbol,
    session_date = start + i - 1L,
    open = open,
    high = high,
    low = low,
    close = close,
    volume = 1000000 + i,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "test",
    as_of_timestamp = "2026-06-24 17:30:00",
    latest_completed_session = max(start + i - 1L),
    fetch_start_date = min(start + i - 1L),
    fetch_end_date = max(start + i - 1L),
    data_version_hash = paste0("h", i),
    stringsAsFactors = FALSE
  )
}

test_that("PCA regime POC fits on TRAIN and scores OOS with frozen states", {
  bars <- g5_test_pca_bars()
  features <- g5_pca_regime_feature_table(bars, "AMD")
  fit <- g5_pca_regime_fit(
    features,
    train_start_date = as.Date("2025-07-20"),
    train_end_date = as.Date("2025-11-30"),
    oos_start_date = as.Date("2025-12-01"),
    oos_end_date = as.Date("2025-12-26"),
    grid_n = 3L,
    min_train_rows = 60L
  )

  expect_equal(fit$grid_n, 3L)
  expect_true(all(c("pc1", "pc2", "state_id", "split") %in% names(fit$scores)))
  expect_true(all(fit$scores$split %in% c("TRAIN", "OOS")))
  expect_true(all(!is.na(fit$scores$state_id)))
  expect_true(all(c("feature", "pc_break", "meta") %in% fit$model_contract$record_type))
  expect_true("extend_to_infinity_for_oos_extremes" %in% fit$model_contract$value)
})

test_that("PCA regime context feature table builds a wide multi-asset panel for one target", {
  bars <- rbind(
    g5_test_pca_bars(symbol = "AMD"),
    transform(g5_test_pca_bars(symbol = "NVDA"), close = close * 1.2, open = open * 1.2, high = high * 1.2, low = low * 1.2),
    transform(g5_test_pca_bars(symbol = "TSLA"), close = close * 0.8, open = open * 0.8, high = high * 0.8, low = low * 0.8)
  )
  features <- g5_pca_regime_context_feature_table(bars, "AMD", c("AMD", "NVDA", "TSLA"))
  context_cols <- g5_pca_regime_context_feature_cols(c("AMD", "NVDA", "TSLA"))

  expect_true(all(context_cols %in% names(features)))
  expect_true(all(c("open", "high", "low", "close", "volume") %in% names(features)))
  expect_equal(unique(features$symbol), "AMD")
  expect_equal(unique(features$regime_context_symbols), "AMD,NVDA,TSLA")
})

test_that("PCA pooled feature table stacks asset-days with common feature names", {
  bars <- rbind(
    g5_test_pca_bars(symbol = "AMD"),
    transform(g5_test_pca_bars(symbol = "NVDA"), close = close * 1.2, open = open * 1.2, high = high * 1.2, low = low * 1.2),
    transform(g5_test_pca_bars(symbol = "TSLA"), close = close * 0.8, open = open * 0.8, high = high * 0.8, low = low * 0.8)
  )
  features <- g5_pca_regime_pooled_feature_table(bars, "AMD", c("AMD", "NVDA", "TSLA"))

  expect_equal(sort(unique(features$symbol)), c("AMD", "NVDA", "TSLA"))
  expect_true(all(g5_pca_regime_default_features() %in% names(features)))
  expect_false(any(grepl("^NVDA__", names(features))))
  expect_equal(unique(features$pca_panel_mode), "pooled_asset_day")
  expect_equal(unique(features$research_candidate_symbol), "AMD")
  expect_equal(unique(features$regime_context_symbols), "AMD,NVDA,TSLA")
})

test_that("PCA regime coverage includes all 3x3 states even when sparse", {
  bars <- g5_test_pca_bars()
  fit <- g5_pca_regime_fit(
    g5_pca_regime_feature_table(bars, "AMD"),
    train_start_date = as.Date("2025-07-20"),
    train_end_date = as.Date("2025-11-30"),
    oos_start_date = as.Date("2025-12-01"),
    oos_end_date = as.Date("2025-12-26"),
    grid_n = 3L,
    min_train_rows = 60L
  )
  coverage <- g5_pca_regime_state_coverage(fit$scores, fit$grid_n)

  expect_equal(nrow(coverage), 18L)
  expect_equal(sort(unique(coverage$split)), c("OOS", "TRAIN"))
  expect_true(all(paste0("S", rep(1:3, each = 3), "_", rep(1:3, times = 3)) %in% coverage$state_id))
})

test_that("PCA k-means regime POC fits TRAIN clusters and scores OOS by frozen centroids", {
  bars <- g5_test_pca_bars()
  fit <- g5_pca_regime_fit_kmeans(
    g5_pca_regime_feature_table(bars, "AMD"),
    train_start_date = as.Date("2025-07-20"),
    train_end_date = as.Date("2025-11-30"),
    oos_start_date = as.Date("2025-12-01"),
    oos_end_date = as.Date("2025-12-26"),
    cluster_count = 5L,
    min_train_rows = 60L,
    nstart = 5L
  )
  coverage <- g5_pca_regime_state_coverage(fit$scores, fit$grid_n, fit$state_ids)

  expect_equal(fit$state_engine, "pca_kmeans")
  expect_equal(fit$cluster_count, 5L)
  expect_equal(sort(unique(fit$scores$state_id)), sort(unique(stats::na.omit(fit$scores$state_id))))
  expect_true(all(g5_pca_regime_kmeans_states(5L) %in% coverage$state_id))
  expect_true(all(c("cluster_raw", "cluster_distance") %in% names(fit$scores)))
  expect_true(all(c("kmeans_centroid", "meta", "feature") %in% fit$model_contract$record_type))
  expect_true(all(is.finite(fit$scores$cluster_distance)))
})

test_that("PCA regime diagnostic PNGs render", {
  bars <- g5_test_pca_bars()
  fit <- g5_pca_regime_fit(
    g5_pca_regime_feature_table(bars, "AMD"),
    train_start_date = as.Date("2025-07-20"),
    train_end_date = as.Date("2025-11-30"),
    oos_start_date = as.Date("2025-12-01"),
    oos_end_date = as.Date("2025-12-26"),
    grid_n = 3L,
    min_train_rows = 60L
  )
  scatter_path <- tempfile("g5_pca_scatter_", fileext = ".png")
  price_path <- tempfile("g5_pca_price_", fileext = ".png")

  written_scatter <- g5_write_pca_regime_scatter_png(fit$scores, fit$pc1_breaks, fit$pc2_breaks, scatter_path)
  written_price <- g5_write_pca_regime_price_png(fit$scores, price_path, "AMD", as.Date("2025-11-30"), as.Date("2025-12-01"))

  expect_true(file.exists(written_scatter))
  expect_true(file.exists(written_price))
  expect_gt(file.info(written_scatter)$size, 0)
  expect_gt(file.info(written_price)$size, 0)
  expect_identical(as.integer(readBin(written_scatter, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_price, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})

test_that("PCA k-means diagnostic PNGs render with centroid markers", {
  bars <- g5_test_pca_bars()
  fit <- g5_pca_regime_fit_kmeans(
    g5_pca_regime_feature_table(bars, "AMD"),
    train_start_date = as.Date("2025-07-20"),
    train_end_date = as.Date("2025-11-30"),
    oos_start_date = as.Date("2025-12-01"),
    oos_end_date = as.Date("2025-12-26"),
    cluster_count = 5L,
    min_train_rows = 60L,
    nstart = 5L
  )
  scatter_path <- tempfile("g5_pca_kmeans_scatter_", fileext = ".png")
  price_path <- tempfile("g5_pca_kmeans_price_", fileext = ".png")

  written_scatter <- g5_write_pca_regime_scatter_png(fit$scores, fit$pc1_breaks, fit$pc2_breaks, scatter_path, centroids = fit$kmeans_centers)
  written_price <- g5_write_pca_regime_price_png(fit$scores, price_path, "AMD", as.Date("2025-11-30"), as.Date("2025-12-01"))

  expect_true(file.exists(written_scatter))
  expect_true(file.exists(written_price))
  expect_gt(file.info(written_scatter)$size, 0)
  expect_gt(file.info(written_price)$size, 0)
  expect_identical(as.integer(readBin(written_scatter, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  expect_identical(as.integer(readBin(written_price, what = "raw", n = 8L)), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})
