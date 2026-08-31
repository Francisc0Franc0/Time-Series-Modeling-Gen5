source(file.path("..", "..", "R", "edl_ms_01_rule201_reclaim.R"))
source(file.path("..", "..", "R", "edl_ms_01_attention_falsification.R"))

edl_ms01_attention_test_events <- function() {
  rows <- list()
  index <- 0L
  for (year in c(2020L, 2021L)) {
    for (cohort in c("ATTENTION_SUPPLEMENT", "GICS_CORE")) {
      for (i in seq_len(if (cohort == "ATTENTION_SUPPLEMENT") 3L else 2L)) {
        index <- index + 1L
        date <- as.Date(sprintf("%d-01-%02d", year, i + ifelse(cohort == "GICS_CORE", 10L, 0L)))
        rows[[index]] <- data.frame(
          symbol = paste0(substr(cohort, 1, 1), year, i),
          session_date = date,
          atlas_cohort = cohort,
          instrument_type = "Stock",
          event_category = "TRIGGERED_PROXY__STRONG_RECLAIM",
          minimum_intraday_return = -0.105 - i / 1000,
          close_location_value = 0.80 + i / 100,
          abnormal_dollar_volume = 1.5 + i / 10,
          path_5_open_log_return = if (cohort == "ATTENTION_SUPPLEMENT") 0.05 else 0.01,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

testthat::test_that("the attention falsification contract is frozen", {
  contract <- edl_ms01_validate_attention_falsification_contract()
  testthat::expect_equal(contract$target_category, "TRIGGERED_PROXY__STRONG_RECLAIM")
  testthat::expect_equal(contract$primary_horizon, 5L)
  testthat::expect_equal(contract$alpha, 0.05)
  testthat::expect_equal(contract$max_abs_smd, 0.25)
  testthat::expect_equal(contract$expected_pair_count, 20L)
})

testthat::test_that("matching is exact-year, without replacement, and deterministic", {
  events <- edl_ms01_attention_test_events()
  first <- edl_ms01_match_attention_to_core(events)
  second <- edl_ms01_match_attention_to_core(events[sample(seq_len(nrow(events))), ])
  testthat::expect_equal(nrow(first$pairs), 4L)
  testthat::expect_equal(first$pairs, second$pairs)
  testthat::expect_equal(anyDuplicated(first$pairs$attention_event_id), 0L)
  testthat::expect_equal(anyDuplicated(first$pairs$core_event_id), 0L)
  testthat::expect_true(all(
    format(first$pairs$attention_session_date, "%Y") ==
      format(first$pairs$core_session_date, "%Y")
  ))
})

testthat::test_that("matching cannot read or react to the forward outcome", {
  events <- edl_ms01_attention_test_events()
  before <- edl_ms01_match_attention_to_core(events)$pairs
  events$path_5_open_log_return <- rev(events$path_5_open_log_return) * 100
  after <- edl_ms01_match_attention_to_core(events)$pairs
  testthat::expect_equal(before, after)
})

testthat::test_that("exact sign-flip inference enumerates every assignment", {
  result <- edl_ms01_exact_sign_flip_p(c(1, 1, 1), "greater")
  testthat::expect_equal(result$exact_assignments, 8L)
  testthat::expect_equal(result$observed_mean_difference, 1)
  testthat::expect_equal(result$exact_p_value, 1 / 8)
})

testthat::test_that("classification distinguishes balance failure from falsification", {
  testthat::expect_equal(
    edl_ms01_classify_attention_falsification(FALSE, 1, 0.01, TRUE, TRUE),
    "INCONCLUSIVE_MATCH_BALANCE_FAILED"
  )
  testthat::expect_equal(
    edl_ms01_classify_attention_falsification(TRUE, 1, 0.01, TRUE, TRUE),
    "ATTENTION_DISTINCTION_SURVIVES_NARROW_FALSIFICATION"
  )
  testthat::expect_equal(
    edl_ms01_classify_attention_falsification(TRUE, 1, 0.20, TRUE, TRUE),
    "ATTENTION_DISTINCTION_DOES_NOT_SURVIVE_NARROW_FALSIFICATION"
  )
})
