source(testthat::test_path("..", "..", "R", "cboe_index_provider.R"))

testthat::test_that("Cboe VIX parser enforces explicit point-in-time bounds", {
  fixture <- paste(
    "DATE,OPEN,HIGH,LOW,CLOSE",
    "01/02/2024,13.20,14.10,13.00,13.70",
    "01/03/2024,13.60,14.30,13.50,14.00",
    "01/04/2024,14.00,15.00,13.90,14.80",
    sep = "\n"
  )
  parsed <- g5_cboe_parse_vix_history(
    fixture,
    start_date = as.Date("2024-01-02"),
    end_date = as.Date("2024-01-03"),
    as_of_timestamp = "2024-01-03 17:30:00"
  )
  testthat::expect_equal(nrow(parsed), 2L)
  testthat::expect_identical(parsed$series_id, rep("VIX", 2L))
  testthat::expect_error(
    g5_cboe_parse_vix_history(fixture, as.Date("2024-01-02"), as.Date("2024-01-04"), "2024-01-03 17:30:00"),
    "cannot be after"
  )
})

testthat::test_that("Cboe VIX parser fails loudly on schema and duplicate changes", {
  bad_schema <- "DATE,CLOSE\n01/02/2024,13.70"
  testthat::expect_error(
    g5_cboe_parse_vix_history(bad_schema, as.Date("2024-01-02"), as.Date("2024-01-02"), "2024-01-02 17:30:00"),
    "schema changed"
  )
  duplicate <- paste(
    "DATE,OPEN,HIGH,LOW,CLOSE",
    "01/02/2024,13.20,14.10,13.00,13.70",
    "01/02/2024,13.20,14.10,13.00,13.70",
    sep = "\n"
  )
  testthat::expect_error(
    g5_cboe_parse_vix_history(duplicate, as.Date("2024-01-02"), as.Date("2024-01-02"), "2024-01-02 17:30:00"),
    "duplicate"
  )
})
