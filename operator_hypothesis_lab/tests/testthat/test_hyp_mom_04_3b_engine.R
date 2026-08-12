source(testthat::test_path("..","..","R","hyp_mom_04_1_engine.R"))
source(testthat::test_path("..","..","R","hyp_mom_04_3b_engine.R"))

testthat::test_that("sector target centers inside sector-quarter", {
  x <- expand.grid(signal_quarter=c("Q1","Q2"),sector=c("A","B"),id=1:4)
  x$target_return <- seq_len(nrow(x))/100
  y <- h043b_sector_target(x,3L)
  key <- interaction(y$signal_quarter,y$sector,drop=TRUE)
  testthat::expect_lt(max(abs(tapply(y$target_sector_relative,key,mean))),1e-12)
  testthat::expect_equal(h043b_features(),c("sector_relative126","trend_r2_63","recovery_from_low252","positive_month_fraction12"))
})

testthat::test_that("quarter metrics and gates are bounded", {
  p <- data.frame(
    signal_quarter=rep(paste0("Q",1:11),each=20),
    sector=rep(rep(LETTERS[1:5],4),11)
  )
  score <- rep(seq_len(20),11); target <- score/100 + rep(seq_len(11),each=20)/1000
  m <- h043b_metrics(p,score,target)
  testthat::expect_equal(nrow(m),11L); testthat::expect_true(all(m$rank_ic>0))
  pred <- data.frame(p,target_sector_relative=target,quartile=rep(h04_quartile(1:20),11))
  gates <- h043b_gate_matrix(m,transform(m,rank_ic=rank_ic-.1),transform(m,rank_ic=rank_ic-.2),pred)
  testthat::expect_equal(nrow(gates),6L); testthat::expect_true(all(gates$passed))
})
