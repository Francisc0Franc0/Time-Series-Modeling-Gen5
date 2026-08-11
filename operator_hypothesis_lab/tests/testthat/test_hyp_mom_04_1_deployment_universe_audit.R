library(testthat)

repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_deployment_universe_audit.R"))

test_that("the deployment-universe audit contract freezes the pre-OOS boundary", {
  contract <- du_validate_contract()
  expect_equal(contract$accession, "0001752724-20-236128")
  expect_equal(contract$report_date, as.Date("2020-09-30"))
  expect_equal(contract$forbidden_start, as.Date("2021-01-01"))
  expect_match(contract$sec_bulk_archive_url, "2020q4_nport[.]zip$")
  changed <- contract
  changed$minimum_complete_train_retention <- 0.75
  expect_error(du_validate_contract(changed), "Frozen deployment-universe contract changed")
})

test_that("company normalization is deterministic but does not invent class mappings", {
  expect_equal(du_normalize_company(c("Wells Fargo & Co", "Wells Fargo and Company")), rep("WELLSFARGOAND", 2))
  expect_equal(du_normalize_company("Marriott International Inc/MD"), "MARRIOTTINTERNATIONAL")
  expect_equal(du_normalize_symbol(c("BRK.B", "BRK/B")), c("BRKB", "BRKB"))
})

test_that("bulk-archive row filters are exact and header-agnostic", {
  accession_lines <- c("0001\tA\tB", "00010\tC\tD", "0002\tE\tF")
  expect_equal(du_filter_accession_lines(accession_lines, "0001"), c(TRUE, FALSE, FALSE))
  identifier_lines <- c("10\tISIN1", "100\tISIN2", "20\tISIN3")
  expect_equal(du_filter_holding_id_lines(identifier_lines, c("10", "20")), c(TRUE, FALSE, TRUE))
})

test_that("source reconciliation keeps unresolved filing identities visible", {
  filing <- data.frame(
    HOLDING_ID = c("1", "2"), ISSUER_TITLE = c("Alpha Inc", "Late Addition Inc"),
    ISSUER_CUSIP = c("111", "222"), stringsAsFactors = FALSE
  )
  wikipedia <- data.frame(
    symbol = c("AAA", "BBB"), security = c("Alpha Corporation", "Beta Corp"),
    sector = c("Industrials", "Financials"), stringsAsFactors = FALSE
  )
  crosswalk <- data.frame(
    filing_issuer_title = character(), filing_cusip = character(), wikipedia_symbol = character(),
    wikipedia_security = character(), mapping_basis = character(), stringsAsFactors = FALSE
  )
  result <- du_reconcile_sources(filing, wikipedia, crosswalk)
  expect_equal(result$source_symbol, c("AAA", NA_character_))
  expect_equal(result$mapping_method, c("NORMALIZED_EXACT", "UNRESOLVED"))
  summary <- du_source_summary(result, wikipedia)
  expect_equal(summary$intersection_count, 1)
  expect_equal(summary$union_count, 3)
})

test_that("TRAIN coverage requires every bounded SPY session", {
  reconciliation <- data.frame(
    HOLDING_ID = c("1", "2"), ISSUER_TITLE = c("Alpha", "Beta"), ISSUER_CUSIP = c("1", "2"),
    source_symbol = c("AAA", "BBB"), mapping_method = "NORMALIZED_EXACT", sector = "Industrials",
    stringsAsFactors = FALSE
  )
  resolutions <- data.frame(source_symbol = c("AAA", "BBB"), resolved_symbol = c("AAA", "BBB"), stringsAsFactors = FALSE)
  calendar <- as.Date(c("2020-12-29", "2020-12-30", "2020-12-31"))
  bars <- data.frame(symbol = c(rep("AAA", 3), rep("BBB", 2)), session_date = c(calendar, calendar[-2L]))
  contract <- du_contract()
  contract$query_start <- min(calendar)
  expect_error(du_train_coverage(reconciliation, resolutions, bars, calendar, contract), "Frozen deployment-universe contract changed")

  frozen <- du_contract()
  calendar <- seq(frozen$query_start, frozen$query_end, by = "day")
  bars <- data.frame(symbol = c(rep("AAA", length(calendar)), rep("BBB", length(calendar) - 1L)),
                     session_date = c(calendar, calendar[-length(calendar)]))
  coverage <- du_train_coverage(reconciliation, resolutions, bars, calendar)
  expect_equal(coverage$complete_train, c(TRUE, FALSE))
})
