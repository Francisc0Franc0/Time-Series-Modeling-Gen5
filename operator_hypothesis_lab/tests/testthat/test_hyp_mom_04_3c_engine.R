source(testthat::test_path("..","..","R","hyp_mom_04_1_engine.R"))
source(testthat::test_path("..","..","R","hyp_mom_04_3b_engine.R"))
source(testthat::test_path("..","..","R","hyp_mom_04_3c_engine.R"))

testthat::test_that("feature audit preserves quarter and tail structure", {
  p <- data.frame(
    signal_quarter = rep(paste0("Q", 1:3), each = 40),
    sector = rep(rep(LETTERS[1:4], each = 10), 3),
    target_sector_relative = rep(scale(1:40, scale = FALSE), 3)
  )
  for (f in h043c_features()) p[[f]] <- rep(1:40, 3)
  a <- h043c_audit(p)
  testthat::expect_equal(nrow(a$quarter_metrics), 12L)
  testthat::expect_true(all(a$summary$mean_rank_ic > .99))
  testthat::expect_true(all(a$summary$positive_d10_quarters == 3L))
  testthat::expect_equal(nrow(a$quartile_shape), 16L)
  testthat::expect_equal(nrow(a$sector_metrics), 16L)
})

testthat::test_that("quarter summaries count signs without fitting a model", {
  x <- data.frame(feature = rep("x", 3), signal_quarter = paste0("Q", 1:3),
    rank_ic = c(.2, -.1, .3), q4_target = c(.1, -.2, .3),
    q4_minus_q1 = c(.2, -.1, .4), d10_target = c(.3, -.2, .5))
  s <- h043c_feature_summary(x)
  testthat::expect_equal(s$positive_ic_quarters, 2L)
  testthat::expect_equal(s$positive_q4_quarters, 2L)
  testthat::expect_equal(s$mean_rank_ic, mean(x$rank_ic))
})
