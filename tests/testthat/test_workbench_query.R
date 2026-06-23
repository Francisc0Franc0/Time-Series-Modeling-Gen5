test_that("workbench query returns cache-backed canonical bars, manifest, and health", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "config_loader.R"))
  source(test_path("..", "..", "R", "calendar.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "cache_store.R"))
  source(test_path("..", "..", "R", "data_audit.R"))
  source(test_path("..", "..", "R", "universe_registry.R"))
  source(test_path("..", "..", "R", "workbench_query.R"))

  tmp_cache <- tempfile("g5_workbench_cache_")
  seed_bars <- data.frame(
    symbol = c("NVDA", "NVDA", "NVDA", "AMD"),
    session_date = as.Date(c("2026-06-18", "2026-06-19", "2026-06-22", "2026-06-19")),
    open = c(100, 101, 102, 50),
    high = c(101, 102, 103, 51),
    low = c(99, 100, 101, 49),
    close = c(100.5, 101.5, 102.5, 50.5),
    volume = c(1000, 1100, 1200, 900),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = paste0("h", seq_len(4L)),
    stringsAsFactors = FALSE
  )
  g5_write_bars_cache(seed_bars, tmp_cache)

  cfg <- list(
    provider = "alpaca",
    timeframe = "1D",
    adjusted = TRUE,
    feed = "iex",
    cache = list(root = tmp_cache, format = "rds"),
    calendar = list(timezone = "America/New_York", market_close_time = "16:00:00"),
    symbols = c("NVDA", "AMD")
  )
  registry <- data.frame(
    universe_name = c("demo", "demo"),
    role = c("research_universe", "research_universe"),
    symbol = c("NVDA", "AMD"),
    description = c("one", "two"),
    stringsAsFactors = FALSE
  )

  result <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = as.Date("2026-06-18"),
    end_date = as.Date("2026-06-23"),
    as_of_timestamp = as.POSIXct("2026-06-22 17:00:00", tz = "America/New_York"),
    universe_registry = registry,
    universe_name = "demo",
    universe_roles = "research_universe",
    refresh = FALSE,
    repo_root = test_path("..", ".."),
    git_sha = "testsha"
  )

  expect_equal(nrow(result$bars), 4L)
  expect_identical(result$manifest$requested_symbols, "AMD,NVDA")
  expect_identical(as.Date(result$manifest$fetch_end_date), as.Date("2026-06-22"))
  expect_identical(result$manifest$health_max_severity, "WARN")
  expect_true(any(result$health$severity == "WARN" & result$health$category == "partial_history"))
  expect_true(any(result$health$severity == "WARN" & result$health$category == "clipped_future_request"))
  expect_true(any(result$refresh_plan$needs_fetch))

  output_dir <- tempfile("g5_workbench_artifacts_")
  written <- g5_write_workbench_query_artifacts(
    result,
    output_dir = output_dir,
    prefix = "demo_query"
  )
  expect_true(file.exists(written$paths$bars_csv))
  expect_true(file.exists(written$paths$manifest_csv))
  expect_true(file.exists(written$paths$health_csv))
  manifest_read <- utils::read.csv(written$paths$manifest_csv, stringsAsFactors = FALSE)
  expect_true("health_csv" %in% names(manifest_read))
})
