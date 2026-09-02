library(testthat)

source(testthat::test_path("..", "..", "R", "wikimedia_pageviews.R"))

fixture_payload <- function() {
  list(items = list(
    list(project = "en.wikipedia", article = "GameStop", granularity = "daily",
         timestamp = "2021010100", access = "all-access", agent = "user", views = 100L),
    list(project = "en.wikipedia", article = "GameStop", granularity = "daily",
         timestamp = "2021010300", access = "all-access", agent = "user", views = 300L)
  ))
}

fixture_contract <- function() {
  x <- adw_contract()
  x$start_date <- as.Date("2021-01-01")
  x$end_date <- as.Date("2021-01-03")
  x
}

test_that("the Wikimedia request is explicit and bounded", {
  contract <- adw_contract()
  url <- adw_request_url(contract)
  expect_match(url, "en.wikipedia.org/all-access/user/GameStop/daily/20190101/20231231$")
  expect_identical(contract$authority, "COLLECTION_AND_HANDLING_POC_ONLY")
  expect_match(contract$as_of_timestamp, "Z$")
})

test_that("the Wikimedia parser preserves exact daily observations", {
  out <- adw_parse_payload(fixture_payload(), fixture_contract())
  expect_identical(out$date, as.Date(c("2021-01-01", "2021-01-03")))
  expect_equal(out$views, c(100, 300))
  expect_identical(out$agent, rep("user", 2L))
})

test_that("omitted days remain unresolved rather than becoming zero", {
  out <- adw_complete_calendar(
    adw_parse_payload(fixture_payload(), fixture_contract()),
    fixture_contract()
  )
  expect_equal(nrow(out), 3L)
  expect_true(is.na(out$views[[2L]]))
  expect_false(out$observed_from_api[[2L]])
  expect_identical(
    out$missing_reason[[2L]],
    "API_OMITTED_ZERO_OR_NOT_LOADED_UNRESOLVED"
  )
})

test_that("duplicate dates and future-unbounded contracts fail loudly", {
  duplicated <- fixture_payload()
  duplicated$items[[2L]]$timestamp <- "2021010100"
  expect_error(
    adw_parse_payload(duplicated, fixture_contract()),
    "duplicate daily rows"
  )
  invalid <- fixture_contract()
  invalid$end_date <- as.Date("2027-01-01")
  expect_error(adw_validate_contract(invalid), "not bounded")
})

test_that("trailing medians use only observations available through each row", {
  expect_equal(adw_trailing_median(c(1, 9, 3), 2L), c(1, 5, 6))
})
