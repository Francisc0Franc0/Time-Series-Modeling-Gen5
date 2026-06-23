test_that("cache paths are symbol scoped", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "cache_store.R"))
  path <- g5_cache_symbol_path(tempdir(), "alpaca", "1D", "spy")
  expect_match(path, "SPY[.]rds$")
})
