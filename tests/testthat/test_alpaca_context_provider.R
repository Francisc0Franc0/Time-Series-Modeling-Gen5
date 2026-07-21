test_that("Alpaca context requests require explicit bounded timestamps", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "alpaca_context_provider.R"))

  news <- g5_alpaca_news_request(
    symbols = c("aapl", "AMD"),
    start_timestamp = "2024-01-02T00:00:00Z",
    end_timestamp = "2024-01-08T23:59:59Z",
    as_of_timestamp = "2026-07-21 17:30:00"
  )
  expect_identical(news$symbols, "AAPL,AMD")
  expect_identical(news$limit, 50L)
  expect_false(news$include_content)

  expect_error(
    g5_alpaca_news_request(
      "AAPL",
      "2024-01-02T00:00:00Z",
      "2026-07-22T00:00:00Z",
      "2026-07-21 17:30:00"
    ),
    "after as_of_timestamp"
  )
  expect_error(
    g5_alpaca_news_request("AAPL", "2024-01-02", "2024-01-08", "2026-07-21", limit = 51L),
    "between 1 and 50"
  )
})

test_that("Alpaca index capability request is separate from stock bars", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "alpaca_context_provider.R"))

  request <- g5_alpaca_index_values_request(
    index_symbols = c("vix", "SPX", "VIX"),
    start_timestamp = "2024-01-02T00:00:00Z",
    end_timestamp = "2024-01-08T23:59:59Z",
    as_of_timestamp = "2026-07-21 17:30:00"
  )
  expect_identical(request$endpoint, "/v1beta1/indices/values")
  expect_identical(request$index_symbols, "VIX,SPX")
  expect_false(grepl("stocks/bars", request$endpoint, fixed = TRUE))
})

test_that("Alpaca news payload maps metadata without storing article content", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "alpaca_context_provider.R"))

  request <- g5_alpaca_news_request(
    "AAPL",
    "2024-01-02T00:00:00Z",
    "2024-01-08T23:59:59Z",
    "2026-07-21 17:30:00"
  )
  payload <- list(
    news = list(list(
      id = 123L,
      headline = "Example headline",
      summary = "Example summary",
      author = "Reporter",
      source = "benzinga",
      symbols = list("MSFT", "AAPL", "AAPL"),
      created_at = "2024-01-03T12:00:00Z",
      updated_at = "2024-01-03T12:05:00Z",
      url = "https://example.invalid/article",
      content = "Full text is deliberately not normalized."
    )),
    next_page_token = NULL
  )
  mapped <- g5_alpaca_map_news_payload(payload, request, "2026-07-21 17:30:00")
  expect_equal(nrow(mapped), 1L)
  expect_identical(mapped$article_id, "123")
  expect_identical(mapped$symbols, "AAPL|MSFT")
  expect_true(mapped$content_present)
  expect_false("content" %in% names(mapped))
  expect_identical(mapped$provider, "alpaca")
})

test_that("Alpaca news mapper preserves an auditable empty schema", {
  source(test_path("..", "..", "R", "data_contract.R"))
  source(test_path("..", "..", "R", "alpaca_provider.R"))
  source(test_path("..", "..", "R", "alpaca_context_provider.R"))

  request <- g5_alpaca_news_request("AAPL", "2024-01-02", "2024-01-03", "2026-07-21")
  mapped <- g5_alpaca_map_news_payload(list(news = list()), request, "2026-07-21")
  expect_equal(nrow(mapped), 0L)
  expect_identical(names(mapped), names(g5_alpaca_empty_news()))
})
