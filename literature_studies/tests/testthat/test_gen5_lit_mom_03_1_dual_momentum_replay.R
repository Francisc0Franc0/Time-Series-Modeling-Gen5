repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_03_1_dual_momentum_mechanics.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_03_1_dual_momentum_replay.R"
))

mom031r_fixture_mechanics <- function() {
  contract <- g5_mom031_contract()
  decisions <- as.Date(c("2016-06-29", "2016-07-06", "2016-07-13", "2016-07-20"))
  executions <- as.Date(c("2016-06-30", "2016-07-07", "2016-07-14", "2016-07-21"))
  score_frames <- vector("list", length(decisions))
  allocation_frames <- vector("list", length(decisions))
  for (i in seq_along(decisions)) {
    roc_10 <- setNames(seq(0.09, 0.01, length.out = 9) - if (i == 3L) 0.05 else 0, contract$universe)
    roc_25 <- setNames(seq(-0.01, 0.07, length.out = 9) - if (i == 2L) 0.04 else 0, contract$universe)
    allocation <- g5_mom031_allocate_scores(roc_10, roc_25, contract)
    score <- allocation$scores
    score$decision_date <- decisions[[i]]
    score$execution_date <- executions[[i]]
    score_frames[[i]] <- score
    weight_values <- setNames(as.list(score$target_weight), paste0("weight_", score$symbol))
    allocation_frames[[i]] <- data.frame(
      decision_date = decisions[[i]],
      execution_date = executions[[i]],
      as.data.frame(weight_values, check.names = FALSE),
      cash_weight = allocation$cash_weight,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }
  open <- matrix(
    c(
      100, 100, 100, 100, 100, 100, 100, 100, 100,
      101, 99, 102, 98, 103, 110, 97, 104, 96,
      102, 98, 101, 99, 105, 99, 98, 106, 95,
      103, 97, 104, 100, 104, 108, 99, 107, 94
    ),
    nrow = 4L, byrow = TRUE,
    dimnames = list(as.character(executions), contract$universe)
  )
  list(
    contract = contract,
    allocations = do.call(rbind, allocation_frames),
    scores = do.call(rbind, score_frames),
    panel = list(open = open)
  )
}

testthat::test_that("frozen control targets isolate the intended components", {
  mechanics <- mom031r_fixture_mechanics()
  targets <- g5_mom031r_targets(mechanics)
  testthat::expect_identical(names(targets), g5_mom031r_contract()$variants)
  testthat::expect_true(all(vapply(targets, function(x) all(abs(rowSums(x) - 1) < 1e-12), logical(1))))
  testthat::expect_true(all(targets$EQUAL_WEIGHT_ALL_NINE[, mechanics$contract$universe] == 1 / 9))
  testthat::expect_true(all(targets$EQUAL_WEIGHT_ALL_NINE[, "CASH"] == 0))
  testthat::expect_true(all(targets$RELATIVE_ONLY[, "CASH"] == 0))
  testthat::expect_true(any(targets$ABSOLUTE_ONLY[, "CASH"] > 0))
  testthat::expect_true(all(targets$SPY_OWNERSHIP[, "SPY"] == 1))
  testthat::expect_true(all(targets$CASH_NO_TRADE[, "CASH"] == 1))
  testthat::expect_true(all(targets$SOURCE_DUAL_MOMENTUM == g5_mom031r_source_targets(mechanics)))
})

testthat::test_that("causal replay uses complete next-open intervals and drift-aware turnover", {
  mechanics <- mom031r_fixture_mechanics()
  result <- g5_mom031r_run(mechanics)
  contract <- result$contract
  testthat::expect_equal(nrow(result$weekly_tape), 3L * length(contract$variants))
  testthat::expect_equal(nrow(result$metrics), length(contract$variants))
  testthat::expect_true(all(result$integrity$status == "PASS"))
  spy <- result$weekly_tape[result$weekly_tape$variant == "SPY_OWNERSHIP", , drop = FALSE]
  testthat::expect_equal(spy$turnover_one_way, c(1, 0, 0), tolerance = 1e-12)
  testthat::expect_equal(spy$cost_fraction, c(0.0005, 0, 0), tolerance = 1e-12)
  testthat::expect_equal(tail(spy$wealth, 1), (1 - 0.0005) * 1.08, tolerance = 1e-12)
  cash <- result$weekly_tape[result$weekly_tape$variant == "CASH_NO_TRADE", , drop = FALSE]
  testthat::expect_equal(cash$wealth, rep(1, 3), tolerance = 1e-12)
  testthat::expect_identical(
    max(result$weekly_tape$next_execution_date),
    tail(mechanics$allocations$execution_date, 1L)
  )
  testthat::expect_true(all(result$weekly_tape$decision_date < result$weekly_tape$execution_date))
})

testthat::test_that("frozen comparisons are deterministic and multiplicity controlled", {
  mechanics <- mom031r_fixture_mechanics()
  first <- g5_mom031r_run(mechanics)
  second <- g5_mom031r_run(mechanics)
  testthat::expect_equal(first$comparisons, second$comparisons, tolerance = 0)
  testthat::expect_identical(
    first$comparisons$comparator_variant,
    g5_mom031r_contract()$comparator_variants
  )
  testthat::expect_true(all(first$comparisons$bh_q_value >= first$comparisons$one_sided_p))
  testthat::expect_true(all(first$comparisons$bh_q_value <= 1))
  testthat::expect_equal(nrow(first$calendar_years), length(first$contract$variants))
  testthat::expect_equal(nrow(first$phases), length(first$contract$variants))
  testthat::expect_equal(nrow(first$source_contribution), 9L)
})

testthat::test_that("replay contract rejects post-hoc changes", {
  contract <- g5_mom031r_contract()
  contract$cost_bps_one_way <- 0
  testthat::expect_error(g5_mom031r_validate_contract(contract), "cost_bps_one_way")
})
