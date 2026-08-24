repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/")
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_imom_03_1_smh_qqq_lead_lag.R"))

him031_fixture_bars <- function(end_date = as.Date("2022-12-30")) {
  contract <- g5_him031_contract()
  dates <- seq.Date(contract$prehistory_start, end_date, by = "day")
  dates <- dates[as.POSIXlt(dates, tz = "UTC")$wday %in% 1:5]
  dates <- dates[!dates %in% contract$archive_gap_dates]
  rows <- list(); z <- 1L
  for (i in seq_along(dates)) {
    date <- dates[[i]]
    last_slot <- if (date %in% contract$early_close_dates) 7L else 13L
    spy_fh <- 0.0015 * sin(i / 9)
    qqq_fh <- spy_fh + 0.0012 * cos(i / 11)
    x_lead <- 0.004 * sin(i / 5) + 0.001 * cos(i / 17)
    first_hour <- c(SMH = qqq_fh + x_lead, QQQ = qqq_fh, SPY = spy_fh)
    spy_rem <- 0.001 * sin(i / 13)
    y_excess <- 0.45 * x_lead + 0.00015 * cos(i / 3)
    remainder <- c(SMH = spy_rem + 0.2 * x_lead, QQQ = spy_rem + y_excess, SPY = spy_rem)
    for (symbol in contract$symbols) {
      base <- 100 * exp(0.0001 * i + c(SMH = 0.02, QQQ = 0.01, SPY = 0)[[symbol]])
      slot_open <- numeric(last_slot); slot_close <- numeric(last_slot)
      slot_open[[1L]] <- base
      slot_close[[1L]] <- base * exp(first_hour[[symbol]] / 2)
      slot_open[[2L]] <- slot_close[[1L]]
      slot_close[[2L]] <- base * exp(first_hour[[symbol]])
      if (last_slot >= 3L) {
        step <- remainder[[symbol]] / (last_slot - 2L)
        for (slot in 3:last_slot) {
          slot_open[[slot]] <- if (slot == 3L) slot_close[[2L]] else slot_close[[slot - 1L]]
          slot_close[[slot]] <- slot_open[[slot]] * exp(step)
        }
      }
      start <- as.POSIXct(paste(date, "09:30:00"), tz = "America/New_York")
      timestamp_utc <- as.POSIXct(as.numeric(start + (seq_len(last_slot) - 1L) * 1800), origin = "1970-01-01", tz = "UTC")
      rows[[z]] <- data.frame(
        symbol = symbol, timestamp_utc = timestamp_utc, session_date = date,
        bar_slot = seq_len(last_slot), open = slot_open,
        high = pmax(slot_open, slot_close) * 1.001,
        low = pmin(slot_open, slot_close) * 0.999, close = slot_close,
        volume = 1e6 + i * 10 + seq_len(last_slot), feed = "sip",
        timeframe = "30Min", adjustment = "all", stringsAsFactors = FALSE
      )
      z <- z + 1L
    }
  }
  do.call(rbind, rows)
}

testthat::test_that("HYP-IMOM-03.1 freezes one causal clock and evidence boundary", {
  contract <- g5_him031_contract()
  testthat::expect_identical(contract$symbols, c("SMH", "QQQ", "SPY"))
  testthat::expect_identical(contract$signal_end_slot, 2L)
  testthat::expect_identical(contract$target_entry_slot, 3L)
  testthat::expect_true(contract$development_end < contract$confirmation_start)
  changed <- contract; changed$signal_end_slot <- 3L
  testthat::expect_error(g5_him031_validate_contract(changed), "Frozen contract changed")
})

testthat::test_that("panel constructs exact first-hour leadership and next-bar remainder target", {
  bars <- him031_fixture_bars(as.Date("2018-01-10"))
  panel <- g5_him031_make_panel(bars)
  date <- as.Date("2018-01-10")
  row <- panel[panel$anchor_date == date, , drop = FALSE]
  day <- bars[bars$session_date == date, , drop = FALSE]
  pick <- function(symbol, slot, field) day[[field]][day$symbol == symbol & day$bar_slot == slot]
  last <- max(day$bar_slot)
  expected_x <- log(pick("SMH", 2L, "close") / pick("SMH", 1L, "open")) -
    log(pick("QQQ", 2L, "close") / pick("QQQ", 1L, "open"))
  expected_y <- log(pick("QQQ", last, "close") / pick("QQQ", 3L, "open")) -
    log(pick("SPY", last, "close") / pick("SPY", 3L, "open"))
  testthat::expect_equal(row$x_lead, expected_x)
  testthat::expect_equal(row$y_excess, expected_y)
  testthat::expect_equal(row$x_wrong_clock, panel$x_lead[match(date, panel$anchor_date) - 1L])
})

testthat::test_that("calendar and confirmation boundary failures are loud", {
  bars <- him031_fixture_bars(as.Date("2018-01-10"))
  dropped <- bars[!(bars$symbol == "SMH" & bars$session_date == as.Date("2018-01-10") & bars$bar_slot == 4L), ]
  testthat::expect_error(g5_him031_make_panel(dropped), "calendars are not identical")
  extra <- bars[bars$session_date == max(bars$session_date), ]
  extra$session_date <- as.Date("2024-01-02")
  extra$timestamp_utc <- extra$timestamp_utc + as.numeric(as.Date("2024-01-02") - max(bars$session_date)) * 86400
  testthat::expect_error(g5_him031_make_panel(rbind(bars, extra)), "evidence boundary")
})

testthat::test_that("frozen TRAIN evaluation is deterministic and recognizes designed lead-lag", {
  panel <- g5_him031_make_panel(him031_fixture_bars(as.Date("2020-12-31")))
  first <- g5_him031_train_run(panel)
  second <- g5_him031_train_run(panel)
  testthat::expect_identical(first$decision, second$decision)
  testthat::expect_identical(first$loss_improvement, second$loss_improvement)
  testthat::expect_identical(first$decision$status, "TRAIN_LEAD_LAG_GATES_PASS")
  testthat::expect_true(all(first$gates$passed))
  testthat::expect_gt(first$decision$leader_coefficient, 0)
  testthat::expect_lt(first$decision$leader_mse, first$decision$own_market_mse)
  testthat::expect_lt(first$decision$leader_mse, first$decision$wrong_clock_mse)
})

testthat::test_that("DEVELOPMENT stays sealed after a TRAIN stop", {
  panel <- g5_him031_make_panel(him031_fixture_bars(as.Date("2022-12-30")))
  stopped <- list(decision = data.frame(status = "STOP_HYP_IMOM_03_1_TRAIN_LEAD_LAG_GATES_FAILED"))
  testthat::expect_error(g5_him031_development_run(panel, stopped), "DEVELOPMENT is sealed")
})

testthat::test_that("strategy and performance surfaces remain absent", {
  text <- paste(deparse(body(g5_him031_train_run)), collapse = " ")
  testthat::expect_false(grepl("sharpe|drawdown|pnl|wealth|position|turnover|trade", text, ignore.case = TRUE))
})
