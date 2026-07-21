source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "alpaca_provider.R"))
source(test_path("..", "..", "R", "alpaca_context_provider.R"))
source(test_path("..", "..", "R", "alpaca_news_stream.R"))

test_that("N1L symbol subscription retains both point-in-time Meta aliases", {
  symbols <- g5_news_live_symbols()
  expect_length(symbols, 25L)
  expect_true(all(c("FB", "META") %in% symbols))
  expect_identical(anyDuplicated(symbols), 0L)
})

test_that("Alpaca stream acknowledgements and news map without content", {
  received_at <- "2026-07-21T06:30:00.000Z"
  ack <- g5_parse_alpaca_news_stream_frame(
    '[{"T":"success","msg":"connected"},{"T":"success","msg":"authenticated"}]',
    "connection_1",
    1L,
    received_at
  )
  expect_equal(nrow(ack), 2L)
  expect_identical(ack$message_type, c("success", "success"))
  expect_identical(ack$status_message, c("connected", "authenticated"))
  expect_true(all(ack$received_at == received_at))

  article <- g5_parse_alpaca_news_stream_frame(
    paste0(
      '[{"T":"n","id":42,"headline":"A headline","summary":"Summary",',
      '"author":"Desk","created_at":"2026-07-21T06:29:00Z",',
      '"updated_at":"2026-07-21T06:29:01Z","content":"not normalized",',
      '"url":"https://example.invalid/42","symbols":["META","FB","META"],',
      '"source":"benzinga"}]'
    ),
    "connection_1",
    2L,
    received_at
  )
  expect_equal(nrow(article), 1L)
  expect_identical(article$article_id, "42")
  expect_identical(article$symbols, "FB|META")
  expect_false("content" %in% names(article))
  expect_identical(article$connection_id, "connection_1")
})

test_that("Alpaca subscription acknowledgement retains requested symbols", {
  parsed <- g5_parse_alpaca_news_stream_frame(
    '[{"T":"subscription","news":["AAPL","AMD"]}]',
    "connection_2",
    1L,
    "2026-07-21T06:31:00.000Z"
  )
  expect_identical(parsed$message_type, "subscription")
  expect_identical(parsed$symbols, "")
  expect_identical(parsed$article_id, "")
})

test_that("stream and REST reconciliation is deterministic", {
  stream <- g5_news_empty_stream_messages()
  stream <- rbind(
    stream,
    data.frame(
      connection_id = c("connection_1", "connection_2"),
      frame_sequence = c(3L, 2L),
      message_index = c(1L, 1L),
      received_at = c("2026-07-21T06:30:01.000Z", "2026-07-21T06:31:01.000Z"),
      message_type = c("n", "n"),
      status_message = c("", ""),
      article_id = c("42", "42"),
      headline = c("A headline", "A headline"),
      summary = c("Summary", "Summary"),
      source = c("benzinga", "benzinga"),
      symbols = c("AAPL", "AAPL"),
      created_at = c("2026-07-21T06:29:00Z", "2026-07-21T06:29:00Z"),
      updated_at = c("2026-07-21T06:29:01Z", "2026-07-21T06:29:01Z"),
      url = c("https://example.invalid/42", "https://example.invalid/42"),
      stringsAsFactors = FALSE
    )
  )
  rest <- g5_alpaca_empty_news()
  rest <- rbind(
    rest,
    data.frame(
      article_id = "42", headline = "A headline", summary = "Summary", author = "Desk",
      source = "benzinga", symbols = "AAPL", created_at = "2026-07-21T06:29:00Z",
      updated_at = "2026-07-21T06:29:01Z", url = "https://example.invalid/42",
      content_present = FALSE, provider = "alpaca",
      request_start_timestamp = "2026-07-21T06:15:00Z",
      request_end_timestamp = "2026-07-21T06:32:00Z",
      as_of_timestamp = "2026-07-21T06:32:00Z", retrieved_at = "2026-07-21T06:32:00Z",
      stringsAsFactors = FALSE
    )
  )

  first <- g5_reconcile_alpaca_news(stream, rest)
  second <- g5_reconcile_alpaca_news(stream[2:1, ], rest)
  expect_identical(first$table, second$table)
  expect_identical(first$table$reconciliation_status, "matched")
  expect_identical(first$table$stream_first_received_at, "2026-07-21T06:30:01.000Z")
  expect_identical(first$table$stream_last_received_at, "2026-07-21T06:31:01.000Z")
  expect_length(first$conflicting_stream_ids, 0L)
})

test_that("conflicting same-version stream payloads are surfaced", {
  stream <- g5_news_empty_stream_messages()
  base <- data.frame(
    connection_id = "connection_1", frame_sequence = 1L, message_index = 1L,
    received_at = "2026-07-21T06:30:01.000Z", message_type = "n", status_message = "",
    article_id = "42", headline = "First", summary = "", source = "benzinga",
    symbols = "AAPL", created_at = "2026-07-21T06:29:00Z",
    updated_at = "2026-07-21T06:29:01Z", url = "", stringsAsFactors = FALSE
  )
  changed <- base
  changed$frame_sequence <- 2L
  changed$received_at <- "2026-07-21T06:30:02.000Z"
  changed$headline <- "Different text, same provider version"
  stream <- rbind(stream, base, changed)
  result <- g5_reconcile_alpaca_news(stream, g5_alpaca_empty_news())
  expect_identical(result$conflicting_stream_ids, "42")
})
