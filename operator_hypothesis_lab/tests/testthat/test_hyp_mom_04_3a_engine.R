source(testthat::test_path("..", "..", "R", "hyp_mom_04_1_engine.R"))
source(testthat::test_path("..", "..", "R", "hyp_mom_04_2_engine.R"))
source(testthat::test_path("..", "..", "R", "hyp_mom_04_3a_engine.R"))

h043a_fixture <- function() {
  contract <- h043a_contract()
  rows <- expand.grid(
    signal_quarter = contract$train_signal_quarters,
    asset = seq_len(405L),
    stringsAsFactors = FALSE
  )
  rows <- rows[order(match(rows$signal_quarter, contract$train_signal_quarters), rows$asset), ]
  quarter_index <- match(rows$signal_quarter, contract$train_signal_quarters)
  rows$row_id <- seq_len(nrow(rows))
  rows$symbol <- sprintf("S%03d", rows$asset)
  rows$sector <- rep(c("A", "B", "C"), length.out = nrow(rows))
  rows$signal_date <- as.Date("2017-03-31") + 91 * (quarter_index - 1L)
  rows$entry_date <- rows$signal_date + 1
  rows$exit_date <- rows$signal_date + 60
  rows$beta126 <- 0.5 + rows$asset / 405
  rows$rv126 <- 0.1 + (rows$asset %% 7) / 20
  rows$momentum12_1 <- sin(rows$asset / 4) + quarter_index / 50
  rows$return126_raw <- 0.02 * quarter_index + rows$asset / 1000
  sector_key <- interaction(rows$signal_quarter, rows$sector, drop = TRUE)
  rows$sector_relative126 <- rows$return126_raw - ave(rows$return126_raw, sector_key, FUN = mean)
  sector_effect <- c(A = -0.03, B = 0.01, C = 0.04)[rows$sector]
  noise <- ((rows$asset * 17 + quarter_index * 11) %% 23 - 11) / 500
  rows$target_return <- 0.01 * quarter_index + sector_effect + 0.04 * rows$beta126 + noise
  rows$target_relative_return <- rows$target_return - ave(rows$target_return, rows$signal_quarter, FUN = mean)
  for (i in seq_along(contract$feature_names)) {
    feature <- contract$feature_names[[i]]
    if (!feature %in% names(rows)) rows[[feature]] <- sin(rows$asset / (i + 1)) + quarter_index / (i + 10)
  }
  rows
}

testthat::test_that("frozen target registry remains explicit", {
  dictionary <- h043a_target_dictionary()
  testthat::expect_equal(dictionary$target_id, c("UNIVERSE_RELATIVE", "SECTOR_RELATIVE", "SECTOR_BETA_RESIDUAL"))
  testthat::expect_equal(h043a_contract()$forbidden_start, as.Date("2021-01-01"))
  testthat::expect_error(h043a_validate_contract(within(h043a_contract(), minimum_assets <- 399L)), "changed")
})

testthat::test_that("targets are centered at their intended comparison level", {
  panel <- h043a_build_targets(h043a_fixture())
  testthat::expect_lt(max(abs(tapply(panel$target_universe_relative, panel$signal_quarter, mean))), 1e-12)
  sector_key <- interaction(panel$signal_quarter, panel$sector, drop = TRUE)
  testthat::expect_lt(max(abs(tapply(panel$target_sector_relative, sector_key, mean))), 1e-12)
  testthat::expect_lt(max(abs(tapply(panel$target_sector_beta_residual, sector_key, mean))), 1e-12)
  beta_residual_cor <- vapply(split(panel, panel$signal_quarter), function(x) {
    abs(stats::cor(x$beta126, x$target_sector_beta_residual))
  }, numeric(1))
  testthat::expect_lt(max(beta_residual_cor), 1e-10)
})

testthat::test_that("integrity enforces the retained TRAIN boundary", {
  panel <- h043a_build_targets(h043a_fixture())
  integrity <- h043a_integrity(
    panel, "STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN", data.frame(passed = TRUE)
  )
  testthat::expect_true(all(integrity$passed))
  panel$exit_date[[1L]] <- as.Date("2021-01-04")
  broken <- h043a_integrity(panel, "STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN", data.frame(passed = TRUE))
  testthat::expect_false(broken$passed[broken$check_id == "NO_OOS_OBSERVATIONS"])
})

testthat::test_that("audit emits all frozen diagnostic surfaces", {
  result <- h043a_run_audit(
    h043a_fixture(), "STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN", data.frame(passed = TRUE)
  )
  testthat::expect_equal(nrow(result$scale), 45L)
  testthat::expect_equal(nrow(result$agreement), 45L)
  testthat::expect_equal(nrow(result$decomposition), 15L)
  testthat::expect_equal(nrow(result$concentration), 45L)
  testthat::expect_equal(nrow(result$baseline_ic), 225L)
  testthat::expect_equal(nrow(result$feature_ic), 1485L)
  testthat::expect_equal(nrow(result$baseline_summary), 15L)
  testthat::expect_equal(nrow(result$feature_summary), 99L)
  testthat::expect_true(all(result$scale$winsorized_to_raw_sd <= 1 + 1e-12))
})

testthat::test_that("target agreement and concentration stay bounded", {
  panel <- h043a_build_targets(h043a_fixture())
  agreement <- h043a_target_agreement(panel)
  concentration <- h043a_sector_concentration(panel)
  testthat::expect_true(all(agreement$rank_correlation >= -1 & agreement$rank_correlation <= 1))
  testthat::expect_true(all(agreement$top_quartile_jaccard >= 0 & agreement$top_quartile_jaccard <= 1))
  testthat::expect_true(all(concentration$max_sector_share > 0 & concentration$max_sector_share <= 1))
  testthat::expect_true(all(concentration$sector_hhi > 0 & concentration$sector_hhi <= 1))
})
