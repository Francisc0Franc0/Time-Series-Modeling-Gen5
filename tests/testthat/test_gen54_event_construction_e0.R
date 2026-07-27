source(testthat::test_path("..", "..", "R", "data_contract.R"))
source(testthat::test_path("..", "..", "R", "gen54_news_admissibility.R"))
source(testthat::test_path("..", "..", "R", "gen54_event_construction_e0.R"))

g5_test_e0_events <- function() {
  data.frame(
    information_cycle_id = c("cycle_A_20250102", "cycle_A_20250102", "cycle_B_20250102"),
    issuer_id = c("A", "A", "B"),
    economic_group = c("g1", "g1", "g2"),
    decision_session = as.Date(c("2025-01-02", "2025-01-02", "2025-01-02")),
    execution_session = as.Date(c("2025-01-03", "2025-01-03", "2025-01-03")),
    article_id = c("a1", "a2", "b1"),
    exact_title_cluster_id = c("title_a1", "title_a2", "title_b1"),
    exact_title_repeat = FALSE,
    source = c("s1", "s2", "s1"),
    headline = c("First event", "Second event", "Third event"),
    availability_timestamp = as.POSIXct(
      c("2025-01-02 16:00:00", "2025-01-02 20:00:00", "2025-01-02 18:00:00"),
      tz = "UTC"
    ),
    decision_cutoff_timestamp = as.POSIXct(
      rep("2025-01-02 22:30:00", 3),
      tz = "UTC"
    ),
    age_hours_at_decision = c(6.5, 2.5, 4.5),
    update_delay_seconds = c(60, 120, 180),
    revision_crossed_decision_cycle = c(FALSE, TRUE, FALSE),
    multi_symbol_article = c(FALSE, TRUE, FALSE),
    provider_symbol_count = c(1L, 2L, 1L),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("E0 cycle builder aggregates only within issuer decision", {
  cycles <- g5_gen54_e0_build_cycles(g5_test_e0_events())
  testthat::expect_equal(nrow(cycles), 2L)
  a <- cycles[cycles$issuer_id == "A", , drop = FALSE]
  testthat::expect_equal(a$novel_cluster_count, 2L)
  testthat::expect_equal(a$source_count, 2L)
  testthat::expect_equal(a$youngest_age_hours, 2.5)
  testthat::expect_equal(a$oldest_age_hours, 6.5)
  testthat::expect_equal(a$revision_crossed_cycle_count, 1L)
  testthat::expect_equal(a$multi_symbol_article_count, 1L)
})

testthat::test_that("E0 coverage preserves missing issuer quarters as zeros", {
  cycles <- g5_gen54_e0_build_cycles(g5_test_e0_events())
  coverage <- g5_gen54_e0_coverage(
    cycles,
    issuer_ids = c("A", "B"),
    quarters = c("2025Q1", "2025Q2")
  )
  testthat::expect_equal(nrow(coverage), 4L)
  testthat::expect_equal(
    coverage$information_cycle_count[
      coverage$issuer_id == "A" & coverage$quarter == "2025Q2"
    ],
    0L
  )
})

testthat::test_that("E0 representative tape selects the strongest cycle per quarter", {
  events <- g5_test_e0_events()
  cycles <- g5_gen54_e0_build_cycles(events)
  tape <- g5_gen54_e0_representative_tape(events, cycles)
  testthat::expect_equal(unique(tape$information_cycle_id), "cycle_A_20250102")
  testthat::expect_equal(tape$article_rank_in_cycle, 1:2)
})

testthat::test_that("E0 integrity audit rejects future availability", {
  events <- g5_test_e0_events()
  cycles <- g5_gen54_e0_build_cycles(events)
  coverage <- g5_gen54_e0_coverage(
    cycles,
    issuer_ids = c("A", "B"),
    quarters = "2025Q1"
  )
  audit <- g5_gen54_e0_integrity_audit(
    events,
    cycles,
    coverage,
    source_leakage_passed = TRUE,
    authority_reproduced = TRUE,
    raw_pages_ok = TRUE,
    minimum_cycles_per_issuer_quarter = 1L
  )
  testthat::expect_equal(
    audit$status[audit$check_id == "availability_no_later_than_decision"],
    "PASS"
  )
  events$availability_timestamp[[1L]] <- events$decision_cutoff_timestamp[[1L]] + 1
  audit_bad <- g5_gen54_e0_integrity_audit(
    events,
    cycles,
    coverage,
    source_leakage_passed = TRUE,
    authority_reproduced = TRUE,
    raw_pages_ok = TRUE,
    minimum_cycles_per_issuer_quarter = 1L
  )
  testthat::expect_equal(
    audit_bad$status[audit_bad$check_id == "availability_no_later_than_decision"],
    "FAIL"
  )
})
