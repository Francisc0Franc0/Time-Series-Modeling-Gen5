test_that("cache paths are symbol scoped", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "cache_store.R"))
  path <- g5_cache_symbol_path(tempdir(), "alpaca", "1D", "spy")
  expect_match(path, "SPY[.]rds$")
})

test_that("cache reads can report partial hits without hiding misses", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "cache_store.R"))

  bars <- data.frame(
    symbol = c("SPY", "QQQ"),
    session_date = as.Date(c("2026-06-22", "2026-06-19")),
    open = c(100, 200),
    high = c(101, 202),
    low = c(99, 199),
    close = c(100.5, 201),
    volume = c(1000, 1200),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = c("spy_hash", "qqq_hash"),
    stringsAsFactors = FALSE
  )

  tmp_cache <- tempfile("g5_cache_")
  written <- g5_write_bars_cache(bars, tmp_cache)
  expect_equal(nrow(written), 2L)

  expect_error(
    g5_read_bars_cache(c("SPY", "TSLA"), tmp_cache),
    "Missing cache files"
  )

  read_result <- g5_read_bars_cache(
    c("SPY", "TSLA"),
    tmp_cache,
    require_all = FALSE,
    return_metadata = TRUE
  )
  expect_equal(nrow(read_result$bars), 1L)
  expect_identical(read_result$cache_hit_symbols, "SPY")
  expect_identical(read_result$cache_missing_symbols, "TSLA")
})

test_that("incremental cache planning covers cold, stale, partial, and fully cached symbols", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "cache_store.R"))

  bars <- data.frame(
    symbol = c("SPY", "SPY", "QQQ", "QQQ", "IWM", "IWM"),
    session_date = as.Date(c(
      "2026-06-18", "2026-06-22",
      "2026-06-19", "2026-06-22",
      "2026-06-18", "2026-06-19"
    )),
    open = c(100, 102, 200, 202, 300, 301),
    high = c(101, 103, 201, 203, 301, 302),
    low = c(99, 101, 199, 201, 299, 300),
    close = c(100.5, 102.5, 200.5, 202.5, 300.5, 301.5),
    volume = c(1000, 1200, 1400, 1500, 1600, 1700),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = paste0("h", seq_len(6L)),
    stringsAsFactors = FALSE
  )

  tmp_cache <- tempfile("g5_incremental_cache_")
  g5_write_bars_cache(bars, tmp_cache)
  refresh <- g5_plan_incremental_cache_refresh(
    symbols = c("SPY", "QQQ", "IWM", "TSLA"),
    cache_root = tmp_cache,
    requested_start_date = as.Date("2026-06-18"),
    requested_end_date = as.Date("2026-06-22"),
    latest_completed_session = as.Date("2026-06-22")
  )
  decisions <- setNames(refresh$plan$refresh_decision, refresh$plan$symbol)

  expect_identical(decisions[["SPY"]], "fully_cached")
  expect_identical(decisions[["QQQ"]], "partial_history")
  expect_identical(decisions[["IWM"]], "stale_cache")
  expect_identical(decisions[["TSLA"]], "cold_cache")
  expect_equal(refresh$plan$fetch_start_date[refresh$plan$symbol == "IWM"], as.Date("2026-06-20"))
  expect_true(is.na(refresh$plan$fetch_start_date[refresh$plan$symbol == "SPY"]))

  artifact <- g5_refresh_plan_artifact(refresh$plan)
  expect_identical(
    names(artifact),
    c(
      "symbol",
      "cache_path",
      "cache_file_exists",
      "cached_row_count",
      "first_cached_session",
      "latest_cached_session",
      "requested_start_date",
      "requested_end_date",
      "needs_fetch",
      "refresh_decision",
      "fetch_start_date",
      "fetch_end_date"
    )
  )
  expect_identical(artifact$symbol, sort(artifact$symbol))

  plan_csv <- tempfile("g5_refresh_plan_", fileext = ".csv")
  g5_write_refresh_plan_artifact_csv(refresh$plan, plan_csv)
  plan_read <- utils::read.csv(plan_csv, stringsAsFactors = FALSE)
  expect_identical(names(plan_read), names(artifact))
  expect_false("X" %in% names(plan_read))
})

test_that("incremental cache writes merge deterministically and report symbols with no returned bars", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "cache_store.R"))

  existing <- data.frame(
    symbol = c("SPY", "SPY"),
    session_date = as.Date(c("2026-06-18", "2026-06-19")),
    open = c(100, 101),
    high = c(101, 102),
    low = c(99, 100),
    close = c(100.5, 101.5),
    volume = c(1000, 1100),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = c("old1", "old2"),
    stringsAsFactors = FALSE
  )
  fetched <- data.frame(
    symbol = c("SPY", "QQQ"),
    session_date = as.Date(c("2026-06-19", "2026-06-22")),
    open = c(111, 200),
    high = c(112, 201),
    low = c(110, 199),
    close = c(111.5, 200.5),
    volume = c(2100, 3000),
    adjusted = TRUE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-18"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = c("new_spy", "new_qqq"),
    stringsAsFactors = FALSE
  )
  tmp_cache <- tempfile("g5_incremental_write_")
  g5_write_bars_cache(existing, tmp_cache)
  refresh_plan <- data.frame(
    symbol = c("SPY", "QQQ", "EMPTY"),
    refresh_decision = c("stale_cache", "cold_cache", "cold_cache"),
    needs_fetch = c(TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )

  written <- g5_write_incremental_bars_cache(fetched, tmp_cache, refresh_plan)
  keys <- paste(written$bars$symbol, written$bars$session_date, sep = ":")

  expect_identical(keys, sort(keys))
  expect_equal(nrow(written$bars), 3L)
  expect_equal(written$bars$open[written$bars$symbol == "SPY" & written$bars$session_date == as.Date("2026-06-19")], 111)
  expect_identical(written$summary$symbol[written$summary$no_returned_bars], "EMPTY")
  expect_false(file.exists(g5_cache_symbol_path(tmp_cache, "alpaca", "1D", "EMPTY")))

  artifact <- g5_cache_merge_summary_artifact(written$summary)
  expect_identical(
    names(artifact),
    c(
      "symbol",
      "cache_path",
      "refresh_decision",
      "needs_fetch",
      "returned_bar_count",
      "merged_row_count",
      "first_merged_session",
      "latest_merged_session",
      "no_returned_bars",
      "wrote_cache"
    )
  )
  expect_identical(artifact$symbol, sort(artifact$symbol))

  merge_csv <- tempfile("g5_merge_summary_", fileext = ".csv")
  g5_write_cache_merge_summary_artifact_csv(written$summary, merge_csv)
  merge_read <- utils::read.csv(merge_csv, stringsAsFactors = FALSE)
  expect_identical(names(merge_read), names(artifact))
  expect_false("X" %in% names(merge_read))
})
