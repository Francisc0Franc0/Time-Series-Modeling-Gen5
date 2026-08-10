library(testthat)

repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_engine.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_04_1_sp500_pit_audit.R"))

test_that("the PIT audit contract is frozen at the 2020 evidence boundary", {
  contract <- spit_validate_contract()
  expect_equal(contract$query_end, as.Date("2020-12-31"))
  expect_equal(contract$forbidden_start, as.Date("2021-01-01"))
  changed <- contract
  changed$minimum_jaccard <- 0.90
  expect_error(spit_validate_contract(changed), "Frozen SP500-PIT-DATA-AUDIT-01 contract changed")
})

test_that("membership intervals are start-inclusive and end-exclusive", {
  intervals <- data.frame(
    ticker = c("AAA", "BBB", "CCC", "AAA"),
    start_date = as.Date(c("2017-01-01", "2017-03-31", "2016-01-01", "2018-01-01")),
    end_date = as.Date(c("2017-03-31", NA, NA, NA)),
    stringsAsFactors = FALSE
  )
  members <- spit_members_at(intervals, as.Date("2017-03-31"))
  expect_setequal(members$ticker, c("BBB", "CCC"))
  expect_setequal(spit_members_at(intervals, as.Date("2018-01-01"))$ticker, c("AAA", "BBB", "CCC"))
})

test_that("symbol comparison is punctuation-stable but provider mapping remains explicit", {
  expect_equal(spit_normalize_symbol(c("BRK.B", "BRK/B", "brk-b")), rep("BRKB", 3))
  expect_equal(spit_provider_candidates("BRK.B"), "BRK.B")
  expect_equal(spit_provider_candidates("BRK/B"), c("BRK/B", "BRK.B"))
  bars <- data.frame(symbol = c("BRK.B", "BF.B"), stringsAsFactors = FALSE)
  resolution <- spit_resolve_provider_symbols(c("BRK.B", "BF.B", "MISS"), bars)
  expect_equal(resolution$identity_status, c("UNIQUE", "UNIQUE", "NO_HISTORY"))
})

test_that("the contemporaneous Wikipedia constituent table parser extracts symbol and sector", {
  html <- paste0(
    '<table class="wikitable sortable"><tr><th>Symbol</th><th>Security</th><th>GICS Sector</th></tr>',
    '<tr><td><a>AAA</a></td><td>Alpha &amp; Co</td><td>Industrials</td></tr>',
    '<tr><td>BRK.B<sup>[1]</sup></td><td>Beta</td><td>Financials</td></tr></table>'
  )
  parsed <- spit_parse_wikipedia_table(html)
  expect_equal(parsed$symbol, c("AAA", "BRK.B"))
  expect_equal(parsed$sector, c("Industrials", "Financials"))
  expect_equal(parsed$security[[1L]], "Alpha & Co")
})

test_that("member-quarter coverage requires every feature session and both target opens", {
  memberships <- data.frame(signal_quarter = "2017Q1", ticker = "AAA", start_date = as.Date("2010-01-01"), end_date = as.Date(NA))
  calendar <- as.Date("2017-01-01") + 0:6
  schedule <- data.frame(signal_quarter = "2017Q1", signal_date = calendar[[4L]], entry_date = calendar[[5L]], exit_date = calendar[[7L]])
  bars <- data.frame(symbol = "AAA", session_date = calendar)
  resolution <- spit_resolve_provider_symbols("AAA", bars)
  coverage <- spit_member_quarter_coverage(memberships, schedule, calendar, bars, resolution, feature_sessions = 3L)
  expect_true(coverage$ordinary_complete)
  coverage_missing <- spit_member_quarter_coverage(memberships, schedule, calendar, bars[-7L, ], resolution, feature_sessions = 3L)
  expect_false(coverage_missing$ordinary_complete)
})

test_that("index removal with a scheduled exit bar is distinct from an unresolved terminal outcome", {
  memberships <- data.frame(signal_quarter = "2017Q1", ticker = "AAA", start_date = as.Date("2010-01-01"), end_date = as.Date("2017-01-06"))
  calendar <- as.Date("2017-01-01") + 0:6
  schedule <- data.frame(signal_quarter = "2017Q1", signal_date = calendar[[4L]], entry_date = calendar[[5L]], exit_date = calendar[[7L]])
  bars <- data.frame(symbol = "AAA", session_date = calendar)
  coverage <- spit_member_quarter_coverage(memberships, schedule, calendar, bars, spit_resolve_provider_symbols("AAA", bars), feature_sessions = 3L)
  expect_true(coverage$terminal_event)
  expect_true(coverage$terminal_return_defensible)
  unresolved <- spit_member_quarter_coverage(memberships, schedule, calendar, bars[-7L, ], spit_resolve_provider_symbols("AAA", bars), feature_sessions = 3L)
  expect_true(unresolved$terminal_event)
  expect_false(unresolved$terminal_return_defensible)
})
