test_that("data-layer config loader merges example and local override without secrets", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "config_loader.R"))

  tmp_root <- tempfile("g5_cfg_")
  dir.create(file.path(tmp_root, "config"), recursive = TRUE)
  example_path <- file.path(tmp_root, "config", "data_layer.example.yml")
  local_path <- file.path(tmp_root, "config", "data_layer.local.yml")

  writeLines(c(
    "provider: alpaca",
    "timeframe: 1D",
    "adjusted: true",
    "feed: iex",
    "cache:",
    "  root: C:/example/cache",
    "  format: rds",
    "calendar:",
    "  timezone: America/New_York",
    "  market_close_time: \"16:00:00\"",
    "symbols:",
    "  - SPY",
    "  - QQQ"
  ), example_path)

  writeLines(c(
    "cache:",
    "  root: D:/local/cache",
    "symbols:",
    "  - TSLA"
  ), local_path)

  cfg <- g5_load_data_layer_config(
    repo_root = tmp_root,
    example_path = example_path,
    local_path = local_path
  )

  expect_identical(cfg$provider, "alpaca")
  expect_identical(cfg$timeframe, "1D")
  expect_true(cfg$adjusted)
  expect_identical(cfg$cache$root, "D:/local/cache")
  expect_identical(cfg$cache$format, "rds")
  expect_identical(cfg$symbols, "TSLA")
  expect_equal(length(cfg$config_source_files), 2L)
})

test_that("relative cache root resolves under the repository root", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "config_loader.R"))

  tmp_root <- tempfile("g5_cfg_relative_")
  dir.create(file.path(tmp_root, "config"), recursive = TRUE)
  example_path <- file.path(tmp_root, "config", "data_layer.example.yml")

  writeLines(c(
    "provider: alpaca",
    "timeframe: 1D",
    "adjusted: true",
    "feed: iex",
    "cache:",
    "  root: data_cache/alpaca_daily_adjusted",
    "  format: rds",
    "calendar:",
    "  timezone: America/New_York",
    "  market_close_time: \"16:00:00\"",
    "symbols:",
    "  - SPY"
  ), example_path)

  cfg <- g5_load_data_layer_config(
    repo_root = tmp_root,
    example_path = example_path,
    local_path = file.path(tmp_root, "config", "missing.local.yml")
  )

  expect_identical(
    cfg$cache$root,
    normalizePath(file.path(tmp_root, "data_cache", "alpaca_daily_adjusted"), winslash = "/", mustWork = FALSE)
  )
})
