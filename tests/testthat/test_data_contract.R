test_that("bar contract exposes required columns", {
  source(test_path("..", "..", "R", "data_contract.R"))
  expect_true("symbol" %in% g5_required_bar_columns())
  expect_true("latest_completed_session" %in% g5_required_bar_columns())
})
