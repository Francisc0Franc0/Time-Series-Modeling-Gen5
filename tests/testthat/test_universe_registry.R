test_that("manual universe registry validates roles and resolves symbols", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "universe_registry.R"))

  registry <- g5_load_universe_registry(test_path("..", "..", "config", "universe_registry.csv"))

  expect_true(all(c("candidate_universe", "research_universe", "context_universe") %in% registry$role))
  expect_true("live_basket" %in% g5_allowed_universe_roles())
  expect_identical(
    g5_universe_symbols(registry, roles = "research_universe"),
    c("AMD", "COIN", "META", "MSTR", "NVDA", "PLTR", "SMCI", "TSLA")
  )
  expect_identical(
    g5_universe_symbols(registry, roles = "context_universe"),
    c("QQQ", "SMH", "SPY", "XLK")
  )
  expect_identical(g5_universe_symbols(registry, roles = "live_basket"), character())
})

test_that("manual universe registry rejects invalid roles and duplicate rows", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "universe_registry.R"))

  bad_role <- data.frame(
    universe_name = "demo",
    role = "strategy_universe",
    symbol = "SPY",
    description = "bad",
    stringsAsFactors = FALSE
  )
  expect_error(g5_validate_universe_registry(bad_role), "Invalid universe role")

  duplicate <- data.frame(
    universe_name = c("demo", "demo"),
    role = c("research_universe", "research_universe"),
    symbol = c("SPY", "SPY"),
    description = c("one", "two"),
    stringsAsFactors = FALSE
  )
  expect_error(g5_validate_universe_registry(duplicate), "Duplicate")
})
