source(testthat::test_path("..","..","R","hyp_intraday_momentum_engine.R"))

fixture <- function(n=80,symbol="AAA") data.frame(symbol=symbol,
  timestamp_utc=seq(as.POSIXct("2020-01-02 14:30:00",tz="UTC"),by="30 min",length.out=n),
  session_date=as.Date("2020-01-02")+((seq_len(n)-1)%/%13),bar_time_et=rep(sprintf("B%02d",1:13),length.out=n),
  open=100+seq_len(n)*.1,high=101+seq_len(n)*.1,low=99+seq_len(n)*.1,close=100+seq_len(n)*.1,volume=1000)

testthat::test_that("daily aggregation preserves first open and last close", {
  x<-fixture(26); d<-imom_aggregate_daily(x)
  testthat::expect_equal(nrow(d),2L); testthat::expect_equal(d$open[[1]],x$open[[1]])
  testthat::expect_equal(d$close[[1]],x$close[[13]])
})

testthat::test_that("SMA schedule starts cash and delays completed-bar signal", {
  x<-fixture(80); x$close<-c(rep(100,20),seq(100,120,length.out=30),seq(120,90,length.out=30)); x$open<-x$close
  a<-imom_sma_schedule(x,min(x$session_date),max(x$session_date),8,14,0)
  b<-imom_sma_schedule(x,min(x$session_date),max(x$session_date),8,14,1)
  testthat::expect_false(a$target[[1]]); testthat::expect_true(which(b$entry_signal)[[1]]>which(a$entry_signal)[[1]])
})

testthat::test_that("fixed-quantity leverage reinvests and charges financing", {
  x<-fixture(40); s<-data.frame(target=c(FALSE,rep(TRUE,38),FALSE))
  a<-imom_replay(x,min(x$session_date),max(x$session_date),s,1,0,0)
  b<-imom_replay(x,min(x$session_date),max(x$session_date),s,1.8,0,.06)
  testthat::expect_true(b$summary$total_return>a$summary$total_return)
  testthat::expect_true(b$summary$financing_paid>0)
})

testthat::test_that("Chan screen uses minimum horizon step and selection gates", {
  x<-fixture(400); x$close<-cumprod(1+rep(c(.002,-.001,.003),length.out=400))*100; x$open<-x$close
  c<-imom_contract(); c$chan_L<-c(13L,26L); c$chan_H<-c(13L); c$chan_min_pairs<-5L
  screen<-imom_chan_screen(x,min(x$session_date),max(x$session_date),c)
  testthat::expect_equal(nrow(screen),2L); testthat::expect_true(all(screen$pair_count>0))
})

testthat::test_that("Chan sleeves reuse capital only after H bars", {
  x<-fixture(120); x$close<-100+seq_len(120)*.2; x$open<-x$close
  out<-imom_chan_sleeve_replay(x,min(x$session_date),max(x$session_date),13L,13L,1,0,0)
  testthat::expect_true(nrow(out$trades)>0); testthat::expect_true(all(out$trades$holding_bars<=13L))
  complete<-out$trades$exit_timestamp<max(x$timestamp_utc)
  testthat::expect_true(all(out$trades$holding_bars[complete]==13L))
})

testthat::test_that("fast terminal replay matches full fixed-quantity accounting", {
  x<-fixture(120);x$close<-100+sin(seq_len(120)/7)*3+seq_len(120)*.05;x$open<-x$close+c(0,diff(x$close))*.1
  s<-data.frame(target=rep(c(FALSE,FALSE,TRUE,TRUE,TRUE,FALSE),length.out=120))
  for(lev in c(1,1.8)){
    full<-imom_replay(x,min(x$session_date),max(x$session_date),s,lev,10,.06)
    fast<-imom_fast_terminal_return(x,min(x$session_date),max(x$session_date),s,lev,10,.06)
    testthat::expect_equal(fast,full$summary$total_return,tolerance=1e-10)
  }
})

testthat::test_that("fast Chan sleeves match full terminal equity", {
  x<-fixture(180);x$close<-100+sin(seq_len(180)/9)*4+seq_len(180)*.04;x$open<-x$close+c(0,diff(x$close))*.1
  for(lev in c(1,1.8)){
    full<-imom_chan_sleeve_replay(x,min(x$session_date),max(x$session_date),13L,13L,lev,10,.06)
    fast<-imom_chan_fast_terminal_return(x,min(x$session_date),max(x$session_date),13L,13L,lev,10,.06)
    testthat::expect_equal(fast,full$summary$total_return,tolerance=1e-10)
  }
})

testthat::test_that("engine has no implicit current date or confirmation access", {
  code<-paste(readLines(testthat::test_path("..","..","R","hyp_intraday_momentum_engine.R")),collapse="\n")
  testthat::expect_false(grepl("Sys.Date\\(",code)); testthat::expect_match(code,"2024-01-02")
})
