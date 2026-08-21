source(testthat::test_path("..", "..", "R", "gen5_m1_multicap_public_source_audit.R"))

testthat::test_that("public-source contract freezes three disjoint cap sleeves", {
  contract <- m1sr1_validate_contract()
  testthat::expect_identical(contract$fund_ticker, c("IWL", "IWR", "IWM"))
  testthat::expect_identical(contract$cap_sleeve, c("large", "mid", "small"))
  testthat::expect_length(unique(contract$series_id), 3L)
  changed <- contract
  changed$report_date[[1L]] <- as.Date("2020-12-31")
  testthat::expect_error(m1sr1_validate_contract(changed), "changed")
})

testthat::test_that("archive filters select only frozen keys", {
  lines <- c("0001\ta", "0002\tb", "00010\tc")
  testthat::expect_identical(m1sr1_filter_accession_lines(lines, c("0001", "0002")), c(TRUE, TRUE, FALSE))
  testthat::expect_identical(m1sr1_filter_holding_id_lines(lines, "0002"), c(FALSE, TRUE, FALSE))
})

testthat::test_that("iShares parser preserves explicit as-of and sector rows", {
  path <- tempfile(fileext = ".csv")
  writeLines(c(
    "iShares Test ETF",
    'Fund Holdings as of,"Sep 30, 2020"',
    'Inception Date,"Jan 01, 2000"',
    "",
    "Ticker,Name,Sector,Asset Class,Market Value",
    'AAA,"ALPHA INC",Industrials,Equity,"1,000"',
    'USD,"USD CASH",Cash and/or Derivatives,Cash,"10"'
  ), path)
  parsed <- m1sr1_read_ishares_holdings(path)
  testthat::expect_identical(parsed$holdings_as_of, as.Date("2020-09-30"))
  testthat::expect_identical(parsed$holdings$Sector[[1L]], "Industrials")
  summary <- m1sr1_current_summary(parsed, "TEST", "test")
  testthat::expect_equal(summary$sector_coverage, 1)
  testthat::expect_equal(summary$retained_equity_rows, 1L)
})

testthat::test_that("gate matrix keeps historical sector and panel closed", {
  nport_summary <- data.frame(
    fund_ticker = c("IWL", "IWR", "IWM"), cap_sleeve = c("large", "mid", "small"),
    reported_holdings = c(200L, 800L, 2000L), retained_common_equity = c(200L, 800L, 2000L),
    valid_cusip_coverage = c(1, 1, 1), placeholder_cusip_count = c(0L, 0L, 0L),
    security_identifier_coverage = c(1, 1, 1), unresolved_security_identifier = c(0L, 0L, 0L),
    issuer_lei_coverage = c(1, 1, 1),
    isin_coverage = c(1, 1, 1), ticker_coverage = c(1, 1, 1),
    duplicate_security_identifier = c(0L, 0L, 0L)
  )
  overlap <- data.frame(left_fund = c("IWL", "IWL", "IWR"), right_fund = c("IWM", "IWR", "IWM"), security_identifier_overlap = 0L)
  current <- data.frame(fund_ticker = c("IWL", "IWR", "IWM"), cap_sleeve = c("large", "mid", "small"), holdings_as_of = as.Date("2026-08-20"), reported_rows = 1L, retained_equity_rows = 1L, ticker_coverage = 1, sector_coverage = 1, sector_count = 11L)
  gates <- m1sr1_gate_matrix(nport_summary, overlap, current, TRUE)
  testthat::expect_false(gates$passed[gates$gate_id == "P7_HISTORICAL_SECTOR_AUTHORITY"])
  testthat::expect_false(gates$passed[gates$gate_id == "P8_LONGITUDINAL_PANEL"])
  testthat::expect_true(gates$passed[gates$gate_id == "P9_OUTCOME_BOUNDARY"])
})
