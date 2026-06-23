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
