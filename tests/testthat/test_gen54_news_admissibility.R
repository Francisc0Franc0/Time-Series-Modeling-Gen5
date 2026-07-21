test_that("news session assignment respects the frozen after-close cutoff", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "gen54_news_admissibility.R"))

  sessions <- as.Date(c("2024-01-05", "2024-01-08", "2024-01-09"))
  assigned <- g5_gen54_news_assign_sessions(
    c("2024-01-05T22:29:00Z", "2024-01-05T22:31:00Z", "2024-01-06T15:00:00Z"),
    sessions
  )
  expect_equal(assigned$decision_session, as.Date(c("2024-01-05", "2024-01-08", "2024-01-08")))
  expect_equal(assigned$execution_session, as.Date(c("2024-01-08", "2024-01-09", "2024-01-09")))
  expect_identical(assigned$at_or_before_cutoff, c(TRUE, FALSE, TRUE))
})

test_that("exact-title clustering compares only with earlier updates", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "gen54_news_admissibility.R"))

  articles <- data.frame(
    article_id = c("a", "b", "c"),
    headline = c("Company Raises Guidance!", "company raises guidance", "Company raises guidance"),
    updated_at = c("2024-01-02T12:00:00Z", "2024-01-03T12:00:00Z", "2024-01-08T12:00:00Z"),
    stringsAsFactors = FALSE
  )
  clustered <- g5_gen54_news_cluster_exact_titles(articles, repeat_window_hours = 72)
  expect_identical(clustered$normalized_headline, rep("company raises guidance", 3L))
  expect_identical(clustered$exact_title_repeat, c(FALSE, TRUE, FALSE))
  expect_identical(clustered$exact_title_cluster_id, c("title_a", "title_a", "title_c"))
  expect_equal(clustered$prior_exact_title_gap_hours[[2L]], 24)
})

test_that("admissibility preserves articles and explodes only requested symbols", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "gen54_news_admissibility.R"))

  articles <- data.frame(
    article_id = c("a", "b"),
    headline = c("Shared event", "Shared event"),
    symbols = c("AAPL|MSFT|SPY", "AAPL"),
    created_at = c("2024-01-05T22:29:00Z", "2024-01-05T22:29:00Z"),
    updated_at = c("2024-01-05T22:31:00Z", "2024-01-06T15:00:00Z"),
    stringsAsFactors = FALSE
  )
  built <- g5_gen54_news_build_admissibility(
    articles,
    candidate_symbols = c("AAPL", "MSFT"),
    session_dates = as.Date(c("2024-01-05", "2024-01-08", "2024-01-09"))
  )
  expect_equal(nrow(built$articles), 2L)
  expect_equal(nrow(built$associations), 3L)
  expect_setequal(built$associations$symbol, c("AAPL", "MSFT"))
  expect_true(built$articles$revision_crossed_decision_cycle[[1L]])
  expect_false(any(built$articles$update_delay_seconds < 0))

  coverage <- g5_gen54_news_coverage(
    built$associations,
    c("AAPL", "MSFT"),
    as.Date(c("2024-01-05", "2024-01-08", "2024-01-09")),
    "2024-01-05",
    "2024-01-09"
  )
  expect_equal(nrow(coverage$symbol_sessions), 6L)
  expect_equal(sum(coverage$symbol_year$novel_exact_title_count), 2L)
})

test_that("Alpaca calendar payload maps an auditable session table", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "alpaca_context_provider.R"))

  parsed <- list(
    list(date = "2024-01-05", open = "09:30", close = "16:00"),
    list(date = "2024-01-08", open = "09:30", close = "16:00")
  )
  calendar <- g5_alpaca_map_calendar_payload(parsed, "2026-07-21T17:30:00Z", "2026-07-21T17:30:00Z")
  expect_equal(calendar$session_date, as.Date(c("2024-01-05", "2024-01-08")))
  expect_identical(calendar$market_close, c("16:00", "16:00"))
})
