test_that("latest completed session requires explicit as-of timestamp", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "calendar.R"))
  expect_error(g5_resolve_latest_completed_session(), "as_of_timestamp")
})
