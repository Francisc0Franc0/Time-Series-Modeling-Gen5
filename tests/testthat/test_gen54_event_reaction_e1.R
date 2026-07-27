source(testthat::test_path("..", "..", "R", "data_contract.R"))
source(testthat::test_path("..", "..", "R", "gen54_event_reaction_e1.R"))

testthat::test_that("E1 price measurements respect confirmation and entry timing", {
  sessions <- as.Date(c(
    "2025-01-02", "2025-01-03", "2025-01-06", "2025-01-07",
    "2025-01-08", "2025-01-09", "2025-01-10", "2025-01-13"
  ))
  issuer_bars <- data.frame(
    issuer_id = "A",
    session_date = sessions,
    open = c(99, 102, 104, 105, 106, 107, 108, 110),
    close = c(100, 103, 104.5, 105.5, 106.5, 107.5, 108.5, 110.5)
  )
  spy_bars <- data.frame(
    session_date = sessions,
    open = c(199, 202, 204, 204.5, 205, 205.5, 206, 206),
    close = c(200, 203, 204.2, 204.7, 205.2, 205.7, 206.2, 206.2)
  )
  panel <- data.frame(
    issuer_id = "A",
    decision_session = sessions[[1L]],
    execution_session = sessions[[2L]],
    fold_id = "2025Q1",
    oos_end_date = as.Date("2025-03-31"),
    novel_cluster_count = 3L,
    baseline_news_intensity_percentile = 0.9
  )
  out <- g5_gen54_e1_attach_price_measurements(
    panel, issuer_bars, spy_bars, sessions
  )
  testthat::expect_equal(out$reaction_session, sessions[[2L]])
  testthat::expect_equal(out$entry_session, sessions[[3L]])
  testthat::expect_equal(out$outcome_end_session_e1, sessions[[8L]])
  testthat::expect_equal(
    out$overnight_excess_log_return,
    log(102 / 100) - log(202 / 200)
  )
  testthat::expect_equal(
    out$intraday_excess_log_return,
    log(103 / 102) - log(203 / 202)
  )
  testthat::expect_equal(
    out$continuation_excess_h5,
    log(110 / 104) - log(206 / 204)
  )
})

testthat::test_that("E1 overlap embargo retains only independently timed paths", {
  panel <- data.frame(
    issuer_id = c("A", "A", "A", "B"),
    decision_session = as.Date(c(
      "2025-01-02", "2025-01-03", "2025-01-10", "2025-01-03"
    )),
    entry_session = as.Date(c(
      "2025-01-06", "2025-01-07", "2025-01-13", "2025-01-07"
    )),
    outcome_end_session_e1 = as.Date(c(
      "2025-01-13", "2025-01-14", "2025-01-21", "2025-01-14"
    )),
    raw_signal = TRUE
  )
  out <- g5_gen54_e1_apply_overlap_embargo(panel)
  testthat::expect_equal(
    out$overlap_retained[out$issuer_id == "A"],
    c(TRUE, FALSE, TRUE)
  )
  testthat::expect_true(out$overlap_retained[out$issuer_id == "B"])
})

g5_test_e1_match_panel <- function() {
  data.frame(
    fold_id = rep("2025Q1", 4),
    issuer_id = c("A", "A", "A", "B"),
    decision_session = as.Date(c(
      "2025-01-02", "2025-01-08", "2025-01-15", "2025-01-08"
    )),
    entry_session = as.Date(c(
      "2025-01-06", "2025-01-10", "2025-01-17", "2025-01-10"
    )),
    outcome_end_session_e1 = as.Date(c(
      "2025-01-13", "2025-01-17", "2025-01-24", "2025-01-17"
    )),
    baseline_news_intensity_percentile = c(0.9, 0, 0, 0),
    novel_cluster_count = c(4L, 0L, 0L, 0L),
    overnight_excess_log_return = c(0.010, 0.011, 0.030, 0.010),
    intraday_excess_log_return = c(0.008, 0.009, 0.020, 0.008),
    continuation_excess_h5 = c(0.03, 0.01, -0.04, 0.50),
    overnight_reaction_z = c(0.50, 0.55, 1.50, 0.50),
    intraday_reaction_z = c(0.40, 0.45, 1.20, 0.40),
    overlap_retained = c(TRUE, FALSE, FALSE, FALSE),
    control_candidate = c(FALSE, TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("E1 matching uses same issuer and fold within frozen caliper", {
  matches <- g5_gen54_e1_match_controls(g5_test_e1_match_panel(), caliper = 0.50)
  testthat::expect_true(matches$matched)
  testthat::expect_equal(matches$control_issuer_id, "A")
  testthat::expect_equal(matches$control_decision_session, as.Date("2025-01-08"))
  testthat::expect_equal(matches$control_novel_cluster_count, 0L)
  testthat::expect_equal(matches$matched_difference_h5, 0.02)
})

testthat::test_that("E1 control selection never learns from continuation outcomes", {
  first <- g5_test_e1_match_panel()
  second <- first
  second$continuation_excess_h5[c(2L, 3L)] <- c(100, -100)
  first_match <- g5_gen54_e1_match_controls(first, caliper = 0.50)
  second_match <- g5_gen54_e1_match_controls(second, caliper = 0.50)
  testthat::expect_equal(
    first_match$control_decision_session,
    second_match$control_decision_session
  )
  testthat::expect_equal(first_match$match_distance, second_match$match_distance)
})

testthat::test_that("E1 classification requires all three frozen conditions", {
  panel <- data.frame(
    novel_cluster_count = c(2L, 2L, 2L, 0L),
    baseline_news_intensity_percentile = c(0.8, 0.7, 0.9, 0),
    overnight_excess_log_return = c(0.01, 0.01, -0.01, 0.01),
    intraday_excess_log_return = c(0.01, 0.01, 0.01, 0.01),
    price_path_complete = TRUE,
    outcome_inside_oos = TRUE,
    support_ok = TRUE
  )
  out <- g5_gen54_e1_classify(panel)
  testthat::expect_equal(out$raw_signal, c(TRUE, FALSE, FALSE, FALSE))
  testthat::expect_true(out$control_candidate[[4L]])
})
