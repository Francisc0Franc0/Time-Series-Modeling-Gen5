source(testthat::test_path("..", "..", "R", "hyp_intraday_alpaca_30min.R"))

testthat::test_that("request freezes SIP adjusted 30-minute scope", {
  r <- imom30_request(c("TSLA","AMD"), "2020-01-02", "2020-01-03", "2026-08-13 17:30:00 America/New_York")
  testthat::expect_equal(r$symbol, c("AMD","TSLA"))
  testthat::expect_true(all(r$timeframe == "30Min"))
  testthat::expect_true(all(r$feed == "sip"))
  testthat::expect_true(all(r$adjustment == "all"))
  testthat::expect_error(imom30_request("TSLA", "2020-01-03", "2020-01-02", "x"), "Invalid request dates")
})

testthat::test_that("diagnostic comparison request labels IEX without changing the SIP default", {
  comparison <- imom30_feed_comparison_request("AMD", "2020-01-02", "2020-01-03",
                                                "frozen", "iex")
  default <- imom30_request("AMD", "2020-01-02", "2020-01-03", "frozen")
  testthat::expect_true(all(comparison$feed == "iex"))
  testthat::expect_true(all(default$feed == "sip"))
  testthat::expect_error(
    imom30_feed_comparison_request("AMD", "2020-01-02", "2020-01-03", "frozen", "otc"),
    "Comparison feed"
  )
})

testthat::test_that("ET conversion respects daylight saving time", {
  testthat::expect_equal(imom30_et_to_utc("2020-01-02", "09:30:00"), "2020-01-02T14:30:00Z")
  testthat::expect_equal(imom30_et_to_utc("2020-07-02", "09:30:00"), "2020-07-02T13:30:00Z")
})

testthat::test_that("mapper keeps only regular-session half-hour slots", {
  req <- imom30_request("SPY", "2020-01-02", "2020-01-02", "frozen")
  bars <- list(SPY=list(
    list(t="2020-01-02T14:30:00Z",o=100,h=102,l=99,c=101,v=1000,n=10,vw=100.5),
    list(t="2020-01-02T21:00:00Z",o=101,h=102,l=100,c=101,v=20,n=2,vw=101)
  ))
  out <- imom30_map_bars(bars, req)
  testthat::expect_equal(nrow(out), 1L)
  testthat::expect_equal(out$bar_time_et, "09:30:00")
  testthat::expect_equal(out$bar_slot, 1L)
})

testthat::test_that("RTH calendar removes post-close bars on frozen early closes", {
  bars <- data.frame(
    session_date=as.Date(c(rep("2018-07-03",13),rep("2018-07-02",13))),
    bar_slot=rep(1:13,2)
  )
  filtered <- imom30_apply_rth_calendar(bars)
  testthat::expect_equal(sum(filtered$session_date == as.Date("2018-07-03")), 7L)
  testthat::expect_equal(sum(filtered$session_date == as.Date("2018-07-02")), 13L)
})

testthat::test_that("archive-gap exclusions remove the session globally without filling", {
  bars <- data.frame(
    symbol=rep(c("AMD","SPY"),each=2),
    session_date=as.Date(rep(c("2018-05-02","2018-05-04"),2)),
    bar_slot=1L
  )
  filtered <- imom30_apply_archive_exclusions(bars)
  testthat::expect_equal(unique(filtered$session_date), as.Date("2018-05-04"))
  testthat::expect_equal(sort(filtered$symbol), c("AMD","SPY"))
})

testthat::test_that("coverage audit enforces SPY timestamp parity", {
  slots <- imom30_slots()
  make <- function(symbol, drop_last=FALSE) {
    times <- as.POSIXct(paste("2020-01-02", slots), tz="America/New_York")
    if (drop_last) times <- head(times,-1)
    data.frame(symbol=symbol,timestamp_utc=as.POSIXct(format(times,tz="UTC",usetz=TRUE)),
      session_date=as.Date("2020-01-02"),bar_time_et=head(slots,length(times)),bar_slot=seq_along(times),
      open=100,high=101,low=99,close=100,volume=1000)
  }
  x <- rbind(make("SPY"),make("AAA"),make("BBB",TRUE))
  registry <- data.frame(symbol=c("SPY","AAA","BBB"),asset_type=c("etf","stock","stock"))
  a <- imom30_audit(x,registry,"2020-01-02","2020-01-02",minimum_prehistory=0L)
  testthat::expect_equal(a$coverage$coverage_status, c("ELIGIBLE","ELIGIBLE","CALENDAR_MISMATCH"))
  testthat::expect_true(all(a$integrity$passed))
})

testthat::test_that("intraday provider contains no implicit current date", {
  code <- paste(readLines(testthat::test_path("..", "..", "R", "hyp_intraday_alpaca_30min.R")), collapse="\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
