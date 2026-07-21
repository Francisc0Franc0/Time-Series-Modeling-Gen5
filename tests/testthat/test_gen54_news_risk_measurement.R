source(test_path("..", "..", "R", "data_contract.R"))
source(test_path("..", "..", "R", "alpaca_provider.R"))
source(test_path("..", "..", "R", "alpaca_context_provider.R"))
source(test_path("..", "..", "R", "gen54_cross_sectional_poc.R"))
source(test_path("..", "..", "R", "gen54_news_admissibility.R"))
source(test_path("..", "..", "R", "gen54_news_risk_measurement.R"))

test_that("FB and META form one issuer with point-in-time validity", {
  registry <- g5_gen54_n1b_issuer_registry()
  meta <- registry[registry$issuer_id == "META_PLATFORMS", ]
  expect_identical(meta$provider_symbol, c("FB", "META"))
  expect_identical(meta$valid_to[[1L]], as.Date("2022-06-08"))
  expect_identical(meta$valid_from[[2L]], as.Date("2022-06-09"))
  expect_length(unique(registry$issuer_id), 24L)
})

test_that("archive merge reconciles R unicode escapes without weakening article identity", {
  template <- g5_alpaca_empty_news()[rep(1L, 2L), , drop = FALSE]
  template$article_id <- "15525971"
  template$headline <- c(
    "Coronavirus <U+2013> Another Severe Hit",
    paste0("Coronavirus ", intToUtf8(0x2013), " Another Severe Hit")
  )
  template$symbols <- "AAPL|FB"
  template$created_at <- "2020-03-11T13:50:56Z"
  template$updated_at <- "2020-03-11T13:50:57Z"
  template$provider <- "alpaca"
  merged <- g5_gen54_n1b_combine_articles(template[1L, ], template[2L, ])
  expect_equal(nrow(merged), 1L)
  expect_identical(
    g5_gen54_news_normalize_headline(merged$headline),
    "coronavirus another severe hit"
  )
})

test_that("issuer bars switch from FB to META without duplicate sessions", {
  bars <- data.frame(
    symbol = c("FB", "FB", "META", "META"),
    session_date = as.Date(c("2022-06-08", "2022-06-09", "2022-06-08", "2022-06-09")),
    open = c(1, 2, 3, 4), close = c(1.1, 2.1, 3.1, 4.1), stringsAsFactors = FALSE
  )
  unified <- g5_gen54_n1b_unify_bars(bars)
  meta <- unified[unified$issuer_id == "META_PLATFORMS", ]
  expect_identical(meta$provider_symbol, c("FB", "META"))
  expect_identical(meta$session_date, as.Date(c("2022-06-08", "2022-06-09")))
})

test_that("bounded historical bar coverage is judged against the requested window", {
  bars <- data.frame(
    issuer_id = rep(c("AAPL", "META_PLATFORMS"), each = 3L),
    session_date = rep(as.Date(c("2020-01-02", "2020-01-03", "2020-01-06")), 2L),
    stringsAsFactors = FALSE
  )
  complete <- g5_gen54_n1b_validate_bar_coverage(
    bars, c("AAPL", "META_PLATFORMS"), as.Date("2020-01-02"), as.Date("2020-01-06")
  )
  expect_true(complete$passed)
  incomplete <- g5_gen54_n1b_validate_bar_coverage(
    bars[bars$issuer_id == "AAPL", ], c("AAPL", "META_PLATFORMS"), as.Date("2020-01-02"), as.Date("2020-01-06")
  )
  expect_false(incomplete$passed)
})

test_that("five-session path volatility uses first open and five closes", {
  sessions <- as.Date("2024-01-01") + 0:5
  news <- data.frame(
    issuer_id = rep("AAPL", 6), decision_session = sessions,
    execution_session = c(sessions[-1], as.Date(NA)), novel_cluster_count = 0L,
    news_log1p = 0, stringsAsFactors = FALSE
  )
  bars <- data.frame(
    issuer_id = "AAPL", provider_symbol = "AAPL", session_date = sessions,
    open = c(100, 100, 102, 101, 104, 103), close = c(100, 101, 100, 103, 102, 105),
    stringsAsFactors = FALSE
  )
  out <- g5_gen54_n1b_attach_h5_path_volatility(news, bars, sessions)
  expected <- sqrt(sum(c(log(101 / 100), log(100 / 101), log(103 / 100), log(102 / 103), log(105 / 102))^2))
  expect_equal(out$future_path_volatility_h5[[1L]], expected)
  expect_identical(out$outcome_end_session[[1L]], sessions[[6L]])
  expect_true(is.na(out$future_path_volatility_h5[[2L]]))
})

test_that("TRAIN empirical percentiles are fixed and include ties", {
  train <- c(0, 0, log(2), log(3))
  mapped <- g5_gen54_n1b_train_percentile(train, c(0, log(2), log(4)))
  expect_equal(mapped, c(0.5, 0.75, 1))
})

test_that("verdict requires all three frozen gates", {
  folds <- data.frame(
    spearman_correlation = c(rep(0.1, 8), rep(-0.1, 4)),
    high_minus_other_relative_volatility = c(rep(0.2, 8), rep(-0.2, 4))
  )
  verdict <- g5_gen54_n1b_verdict(folds)
  expect_true(verdict$passed)
  folds$spearman_correlation[[1L]] <- -1
  expect_false(g5_gen54_n1b_verdict(folds)$passed)
})
