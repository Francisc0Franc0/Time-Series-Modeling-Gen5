source(file.path("..", "..", "R", "return_geometry_incremental_forward_decomposition.R"))

testthat::test_that("incremental blocks partition sessions 1 through 100", {
  blocks <- rgifd_validate_blocks()
  testthat::expect_equal(blocks$block_start, c(1L, 6L, 11L, 21L, 41L, 61L))
  testthat::expect_equal(blocks$block_end, c(5L, 10L, 20L, 40L, 60L, 100L))
  testthat::expect_equal(sum(blocks$block_sessions), 100L)
})

testthat::test_that("all incremental blocks use identical common anchors and sum to R1:100", {
  n <- 420L
  dates <- seq.Date(as.Date("2017-01-02"), by = "day", length.out = 650L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- exp(seq(log(200), log(40), length.out = n))
  ledger <- data.frame(
    symbol = "TEST", session_date = dates, close = close,
    signed_er20_state = "DOWN_TREND", stringsAsFactors = FALSE
  )
  contract <- rgifd_contract()
  contract$analysis_start <- as.Date("2017-06-01")
  contract$analysis_end <- max(dates)
  surface <- rgifd_construct_surface(ledger, contract)
  counts <- table(surface$block_id)
  testthat::expect_equal(length(unique(as.integer(counts))), 1L)
  anchors <- split(surface, surface$anchor_session)
  errors <- vapply(anchors, function(x) {
    sum(x$forward_incremental_log_return) -
      x$forward_cumulative_log_return[x$block_id == "B61_100"]
  }, numeric(1L))
  testthat::expect_lt(max(abs(errors)), 1e-12)
  testthat::expect_true(all(surface$common_forward_end_session <= contract$analysis_end))
})

testthat::test_that("asset measurement retains the frozen block vocabulary", {
  n <- 420L
  dates <- seq.Date(as.Date("2017-01-02"), by = "day", length.out = 650L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  close <- exp(seq(log(200), log(40), length.out = n) + 0.02 * sin(seq_len(n) / 9))
  ledger <- data.frame(
    symbol = "TEST", session_date = dates, close = close,
    signed_er20_state = "DOWN_TREND", stringsAsFactors = FALSE
  )
  contract <- rgifd_contract()
  contract$analysis_start <- as.Date("2017-06-01")
  contract$analysis_end <- max(dates)
  surface <- rgifd_construct_surface(ledger, contract)
  measured <- rgifd_measure_asset(surface, contract)
  testthat::expect_equal(nrow(measured), 6L)
  testthat::expect_equal(measured$block_id, rgifd_block_registry()$block_id)
  testthat::expect_equal(length(unique(measured$common_anchor_observations)), 1L)
  testthat::expect_true(all(measured$primary_observations == measured$common_anchor_observations))
})

testthat::test_that("duration classification requires broad late incremental support", {
  blocks <- rgifd_block_registry()
  equal_sector <- data.frame(
    blocks,
    primary_incremental_pearson = c(-0.2, -0.1, -0.05, -0.08, -0.06, 0.01),
    incremental_excess_mean_per_session = c(0.001, 0.001, 0.001, 0.001, 0.001, -0.001)
  )
  sector_summary <- do.call(rbind, lapply(seq_len(nrow(blocks)), function(i) {
    block_rows <- blocks[rep(i, 11L), , drop = FALSE]
    rownames(block_rows) <- NULL
    cbind(
      data.frame(sector = paste0("S", seq_len(11L))),
      block_rows,
      data.frame(
        primary_incremental_pearson = if (i %in% c(4L, 5L)) {
          rep(-0.1, 11L)
        } else {
          rep(0.1, 11L)
        }
      )
    )
  }))
  result <- rgifd_classify_duration(equal_sector, sector_summary)
  testthat::expect_equal(
    result$status, "LATE_INCREMENTAL_DURATION_RETAINS_DESCRIPTIVE_SUPPORT"
  )
  testthat::expect_equal(result$supportive_late_blocks, 2L)
})
