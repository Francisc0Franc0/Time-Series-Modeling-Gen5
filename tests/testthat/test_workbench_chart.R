test_that("static candlestick PNG renders from canonical adjusted daily bars", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "workbench_chart.R"))

  bars <- data.frame(
    symbol = c("NVDA", "NVDA", "NVDA", "AMD"),
    session_date = as.Date(c("2026-06-18", "2026-06-19", "2026-06-22", "2026-06-19")),
    open = c(100, 102, 101, 50),
    high = c(103, 104, 102, 51),
    low = c(99, 100, 98, 49),
    close = c(102, 101, 99, 50.5),
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

  png_path <- tempfile("g5_candlestick_", fileext = ".png")
  written <- g5_write_static_candlestick_png(
    bars,
    symbol = "NVDA",
    path = png_path,
    start_date = as.Date("2026-06-18"),
    end_date = as.Date("2026-06-22")
  )

  expect_true(file.exists(written))
  expect_gt(file.info(written)$size, 0)
  signature <- readBin(written, what = "raw", n = 8L)
  expect_identical(as.integer(signature), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))

  expect_identical(
    g5_candlestick_artifact_prefix("2026-06-22 17:00:00", "nvda"),
    "candlestick_NVDA_2026_06_22_17_00_00"
  )
})

test_that("multi-symbol candlestick PNG renders chart panes from canonical bars", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "workbench_chart.R"))

  bars <- data.frame(
    symbol = c("NVDA", "NVDA", "AMD", "AMD"),
    session_date = as.Date(c("2026-06-18", "2026-06-19", "2026-06-18", "2026-06-19")),
    open = c(100, 102, 50, 51),
    high = c(103, 104, 52, 53),
    low = c(99, 100, 49, 50),
    close = c(102, 101, 51, 52),
    volume = c(1000, 1100, 900, 950),
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

  png_path <- tempfile("g5_multi_candlestick_", fileext = ".png")
  written <- g5_write_multi_symbol_candlestick_png(
    bars,
    symbols = c("NVDA", "AMD"),
    path = png_path,
    start_date = as.Date("2026-06-18"),
    end_date = as.Date("2026-06-22")
  )

  expect_true(file.exists(written))
  expect_gt(file.info(written)$size, 0)
  signature <- readBin(written, what = "raw", n = 8L)
  expect_identical(as.integer(signature), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})

test_that("static candlestick PNG rejects non-canonical or empty chart inputs", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "workbench_chart.R"))

  expect_error(
    g5_write_static_candlestick_png(
      g5_empty_bar_data(),
      symbol = "NVDA",
      path = tempfile("g5_empty_candlestick_", fileext = ".png")
    ),
    "requires non-empty canonical bars"
  )

  bad_bars <- data.frame(
    symbol = "NVDA",
    session_date = as.Date("2026-06-22"),
    open = 100,
    high = 101,
    low = 99,
    close = 100.5,
    volume = 1000,
    adjusted = FALSE,
    timeframe = "1D",
    provider = "alpaca",
    as_of_timestamp = "2026-06-22 17:00:00",
    latest_completed_session = as.Date("2026-06-22"),
    fetch_start_date = as.Date("2026-06-22"),
    fetch_end_date = as.Date("2026-06-22"),
    data_version_hash = "h1",
    stringsAsFactors = FALSE
  )

  expect_error(
    g5_write_static_candlestick_png(
      bad_bars,
      symbol = "NVDA",
      path = tempfile("g5_bad_candlestick_", fileext = ".png")
    ),
    "requires adjusted daily bars"
  )
})
