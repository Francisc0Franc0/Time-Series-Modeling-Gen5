source(testthat::test_path("..", "..", "R", "sec_edgar_provider.R"))

testthat::test_that("SEC CIKs and provider URLs are deterministic", {
  testthat::expect_identical(g5_sec_validate_cik("2488"), "0000002488")
  testthat::expect_identical(
    g5_sec_url("submissions", "2488"),
    "https://data.sec.gov/submissions/CIK0000002488.json"
  )
  testthat::expect_identical(
    g5_sec_url("companyfacts", "320193"),
    "https://data.sec.gov/api/xbrl/companyfacts/CIK0000320193.json"
  )
  testthat::expect_error(g5_sec_validate_cik("AMD"), "CIK")
  testthat::expect_error(g5_sec_url("other", "2488"), "Unsupported")
})

testthat::test_that("submission arrays become explicit data frames", {
  fixture <- list(
    accessionNumber = c("a", "b"),
    form = c("10-Q", "10-K"),
    filingDate = c("2024-01-01", "2024-02-01")
  )
  result <- g5_sec_submission_frame(fixture)
  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_identical(result$form, c("10-Q", "10-K"))
  testthat::expect_error(g5_sec_submission_frame(list(a = 1:2, b = 1:3)), "shape")
})

testthat::test_that("company facts retain accession and provenance columns", {
  payload <- list(facts = list(us.gaap = list(
    Revenues = list(
      label = "Revenue",
      units = list(USD = list(list(
        start = "2023-01-01", end = "2023-03-31", val = 100,
        accn = "0001", fy = 2023, fp = "Q1", form = "10-Q", filed = "2023-04-30"
      )))
    )
  )))
  result <- g5_sec_companyfacts_long(payload, "TEST", "1")
  testthat::expect_equal(nrow(result), 1L)
  testthat::expect_identical(result$symbol, "TEST")
  testthat::expect_identical(result$cik, "0000000001")
  testthat::expect_identical(result$concept, "Revenues")
  testthat::expect_identical(result$accn, "0001")
})
