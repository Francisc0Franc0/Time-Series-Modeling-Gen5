source(testthat::test_path("..", "..", "R", "hyp_alt_01_1_reddit_attention.R"))

ha011_test_registry <- function() {
  data.frame(
    symbol = c("AI", "DD", "GME", "IT", "NA", "NVDA", "TSLA"),
    name = c("C3.ai", "DuPont", "GameStop", "Gartner", "Nano Labs", "NVIDIA", "Tesla"),
    stringsAsFactors = FALSE
  )
}

ha011_test_comment <- function(id, created_utc, body) {
  list(kind = "t1", data = list(id = id, created_utc = created_utc, body = body))
}

ha011_test_listing <- function(comments, after = NULL) {
  list(data = list(children = comments, after = after))
}

testthat::test_that("ticker extraction distinguishes cashtags, bare symbols, and ambiguous words", {
  x <- ha011_extract_mentions(
    "AI is interesting; $AI and TSLA, $TSLA TSLA. DD on GME; IT is noisy. $GME $GME",
    ha011_test_registry()
  )
  testthat::expect_equal(x$ticker, c("AI", "GME", "TSLA"))
  testthat::expect_equal(x$cashtag_occurrences, c(1L, 2L, 1L))
  testthat::expect_equal(x$bare_occurrences, c(0L, 1L, 2L))
  testthat::expect_equal(x$detection_method, c("CASHTAG", "BOTH", "BOTH"))
  testthat::expect_false(any(x$ticker %in% c("DD", "IT")))
})

testthat::test_that("comment mapping stores no body or author and uses Eastern dates", {
  created <- as.numeric(as.POSIXct("2026-08-13 01:30:00", tz = "UTC"))
  x <- ha011_map_comment(
    list(id = "abc", created_utc = created, body = "Holding $NVDA"),
    ha011_test_registry(),
    "2026-08-13T01:31:00Z"
  )
  testthat::expect_equal(x$observation$date_et, as.Date("2026-08-12"))
  testthat::expect_equal(x$mentions$ticker, "NVDA")
  testthat::expect_false(any(c("body", "author", "username") %in% names(x$observation)))
  testthat::expect_false(any(c("body", "author", "username") %in% names(x$mentions)))
})

testthat::test_that("daily attention uses distinct comments as the primary count", {
  registry <- ha011_test_registry()
  created <- as.numeric(as.POSIXct("2026-08-12 16:00:00", tz = "UTC"))
  parsed <- ha011_parse_listing(
    ha011_test_listing(list(
      ha011_test_comment("c1", created, "$GME $GME"),
      ha011_test_comment("c2", created + 1, "GME and $TSLA"),
      ha011_test_comment("c3", created + 2, "No symbols here")
    )),
    registry,
    "2026-08-12T16:05:00Z"
  )
  daily <- ha011_daily_attention(parsed$observations, parsed$mentions)
  gme <- daily[daily$ticker == "GME", ]
  testthat::expect_equal(gme$comments_mentioning, 2L)
  testthat::expect_equal(gme$total_occurrences, 3L)
  testthat::expect_equal(gme$all_wsb_comments, 3L)
  testthat::expect_equal(gme$attention_rank, 1L)
})

testthat::test_that("collector bootstraps then proves overlap without duplicating comments", {
  root <- tempfile("ha011_store_")
  dir.create(root)
  registry_path <- file.path(root, "registry.csv")
  utils::write.csv(ha011_test_registry(), registry_path, row.names = FALSE)
  config <- list(
    access_approved = TRUE,
    client_id = "valid_client_123",
    client_secret = "valid_secret_456",
    user_agent = "windows:gen5-wsb-attention:v0.1 (by /u/example)",
    subreddit = "wallstreetbets",
    token_url = "unused",
    api_base_url = "unused",
    storage_root = root,
    ticker_registry_path = registry_path,
    max_pages = 3L,
    bootstrap_pages = 1L,
    poll_target_minutes = 2,
    poll_grace_minutes = 3
  )
  created <- as.numeric(as.POSIXct("2026-08-12 16:00:00", tz = "UTC"))
  current <- ha011_test_listing(list(
    ha011_test_comment("c3", created + 3, "$NVDA"),
    ha011_test_comment("c2", created + 2, "$GME")
  ))
  fetch <- function(config, token, after = NULL, limit = 100L) {
    list(parsed = current, rate_remaining = 99, rate_reset_seconds = 600)
  }
  first <- ha011_collect_once(
    config, as.POSIXct("2026-08-12 16:04:00", tz = "UTC"),
    fetch_page = fetch, token_fetch = function(config) "token"
  )
  testthat::expect_equal(first$status, "BOOTSTRAP_NO_COVERAGE_AUTHORITY")

  current <- ha011_test_listing(list(
    ha011_test_comment("c4", created + 4, "$TSLA"),
    ha011_test_comment("c3", created + 3, "$NVDA")
  ))
  second <- ha011_collect_once(
    config, as.POSIXct("2026-08-12 16:06:00", tz = "UTC"),
    fetch_page = fetch, token_fetch = function(config) "token"
  )
  observations <- utils::read.csv(second$paths$observations, stringsAsFactors = FALSE)
  testthat::expect_equal(second$status, "PASS_FORWARD_OVERLAP")
  testthat::expect_equal(sort(observations$comment_id), c("c2", "c3", "c4"))
  testthat::expect_equal(nrow(observations), 3L)
})

testthat::test_that("preflight fails closed without explicit Reddit approval", {
  config <- ha011_config_from_env(tempdir())
  config$access_approved <- FALSE
  config$client_id <- "valid_client"
  config$client_secret <- "valid_secret"
  config$user_agent <- "windows:gen5:v0.1 (by /u/example)"
  result <- ha011_preflight(config, require_registry = FALSE, require_runtime = FALSE)
  testthat::expect_false(result$ok)
  testthat::expect_equal(
    result$checks$status[result$checks$check == "reddit_access_explicitly_approved"],
    "FAIL"
  )
})

testthat::test_that("deletion reconciliation purges removed contributions", {
  root <- tempfile("ha011_reconcile_")
  dir.create(root)
  registry_path <- file.path(root, "registry.csv")
  utils::write.csv(ha011_test_registry(), registry_path, row.names = FALSE)
  config <- list(
    access_approved = TRUE, client_id = "valid_client", client_secret = "valid_secret",
    user_agent = "windows:gen5:v0.1 (by /u/example)", subreddit = "wallstreetbets",
    token_url = "unused", api_base_url = "unused", storage_root = root,
    ticker_registry_path = registry_path, max_pages = 1L, bootstrap_pages = 1L,
    poll_target_minutes = 2, poll_grace_minutes = 3
  )
  created <- as.numeric(as.POSIXct("2026-08-12 16:00:00", tz = "UTC"))
  current <- ha011_test_listing(list(
    ha011_test_comment("keep", created, "$NVDA"),
    ha011_test_comment("remove", created + 1, "$GME")
  ))
  fetch <- function(config, token, after = NULL, limit = 100L) list(parsed = current, rate_remaining = 99, rate_reset_seconds = 600)
  collected <- ha011_collect_once(
    config, as.POSIXct("2026-08-12 16:02:00", tz = "UTC"),
    fetch_page = fetch, token_fetch = function(config) "token"
  )
  info <- function(config, token, comment_ids) {
    ha011_test_listing(list(ha011_test_comment("keep", created, "$NVDA")))
  }
  reconciled <- ha011_reconcile_once(
    config, as.POSIXct("2026-08-13 16:02:00", tz = "UTC"),
    fetch_info = info, token_fetch = function(config) "token"
  )
  observations <- utils::read.csv(collected$paths$observations, stringsAsFactors = FALSE)
  mentions <- utils::read.csv(collected$paths$mentions, stringsAsFactors = FALSE)
  testthat::expect_equal(reconciled$purged, 1L)
  testthat::expect_equal(observations$comment_id, "keep")
  testthat::expect_equal(mentions$ticker, "NVDA")
})

testthat::test_that("storage lock prevents concurrent ledger writers", {
  root <- tempfile("ha011_lock_")
  lock <- ha011_acquire_storage_lock(root)
  on.exit(ha011_release_storage_lock(lock), add = TRUE)
  testthat::expect_error(
    ha011_acquire_storage_lock(root),
    "Storage is locked by another collector"
  )
})

testthat::test_that("CSV registry preserves the literal ticker NA", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(symbol = c("NA", "TSLA")), path, row.names = FALSE)
  registry <- ha011_validate_registry(utils::read.csv(path, stringsAsFactors = FALSE, na.strings = ""))
  testthat::expect_equal(registry$symbol, c("NA", "TSLA"))
})

testthat::test_that("ambiguous ticker NA requires cashtag syntax", {
  x <- ha011_extract_mentions("NA is not a signal, but $NA is explicit", ha011_test_registry())
  testthat::expect_equal(x$ticker, "NA")
  testthat::expect_equal(x$cashtag_occurrences, 1L)
  testthat::expect_equal(x$bare_occurrences, 0L)
})
