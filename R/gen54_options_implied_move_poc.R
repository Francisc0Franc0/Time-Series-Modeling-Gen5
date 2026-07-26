g5_gen54_o0_session_date <- function(timestamp, timezone = "America/New_York") {
  parsed <- as.POSIXct(timestamp, tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ")
  as.Date(format(parsed, tz = timezone, format = "%Y-%m-%d"))
}

g5_gen54_o0_bar_clock <- function(timestamp, timezone = "America/New_York") {
  parsed <- as.POSIXct(timestamp, tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ")
  format(parsed, tz = timezone, format = "%H:%M")
}

g5_gen54_o0_final_bars <- function(bars, symbol_column, target_clock = "15:45") {
  if (!all(c(symbol_column, "bar_timestamp", "vwap", "close") %in% names(bars))) {
    stop("O0 bars are missing required final-bar columns.", call. = FALSE)
  }
  keep <- g5_gen54_o0_bar_clock(bars$bar_timestamp) == target_clock
  out <- bars[keep, , drop = FALSE]
  out$session_date <- g5_gen54_o0_session_date(out$bar_timestamp)
  out$selected_price <- ifelse(is.finite(out$vwap), out$vwap, out$close)
  if (anyDuplicated(out[, c(symbol_column, "session_date")])) {
    stop("O0 final-bar selection produced duplicate symbol-session rows.", call. = FALSE)
  }
  out
}

g5_gen54_o0_select_pairs <- function(
  contracts,
  underlying_final_bars,
  session_dates,
  underlyings = c("SPY", "QQQ", "IWM"),
  target_dte = 30L,
  minimum_dte = 21L,
  maximum_dte = 45L
) {
  required_contracts <- c(
    "option_symbol", "underlying_symbol", "expiration_date",
    "strike_price", "option_type"
  )
  if (!all(required_contracts %in% names(contracts))) {
    stop("O0 contracts are missing required immutable definition columns.", call. = FALSE)
  }
  if (!all(c("symbol", "session_date", "selected_price") %in% names(underlying_final_bars))) {
    stop("O0 underlying bars are missing required selection columns.", call. = FALSE)
  }
  rows <- list()
  idx <- 1L
  for (session_date in as.Date(session_dates)) {
    session_date <- as.Date(session_date, origin = "1970-01-01")
    for (underlying in underlyings) {
      spot_rows <- underlying_final_bars[
        underlying_final_bars$symbol == underlying &
          underlying_final_bars$session_date == session_date,
        ,
        drop = FALSE
      ]
      if (nrow(spot_rows) != 1L || !is.finite(spot_rows$selected_price[[1L]])) {
        rows[[idx]] <- data.frame(
          session_date = session_date,
          underlying_symbol = underlying,
          underlying_price = NA_real_,
          expiration_date = as.Date(NA),
          dte = NA_integer_,
          strike_price = NA_real_,
          strike_distance_fraction = NA_real_,
          call_symbol = NA_character_,
          put_symbol = NA_character_,
          selection_status = "MISSING_UNDERLYING_FINAL_BAR",
          stringsAsFactors = FALSE
        )
        idx <- idx + 1L
        next
      }
      spot <- spot_rows$selected_price[[1L]]
      eligible <- contracts[contracts$underlying_symbol == underlying, , drop = FALSE]
      eligible$dte <- as.integer(eligible$expiration_date - session_date)
      eligible <- eligible[
        eligible$dte >= minimum_dte & eligible$dte <= maximum_dte,
        ,
        drop = FALSE
      ]
      pair_key <- paste(eligible$expiration_date, eligible$strike_price)
      call_keys <- pair_key[eligible$option_type == "call"]
      put_keys <- pair_key[eligible$option_type == "put"]
      matched_keys <- intersect(call_keys, put_keys)
      eligible <- eligible[pair_key %in% matched_keys, , drop = FALSE]
      if (!nrow(eligible)) {
        rows[[idx]] <- data.frame(
          session_date = session_date,
          underlying_symbol = underlying,
          underlying_price = spot,
          expiration_date = as.Date(NA),
          dte = NA_integer_,
          strike_price = NA_real_,
          strike_distance_fraction = NA_real_,
          call_symbol = NA_character_,
          put_symbol = NA_character_,
          selection_status = "NO_MATCHED_CONTRACT_PAIR",
          stringsAsFactors = FALSE
        )
        idx <- idx + 1L
        next
      }
      eligible$dte_distance <- abs(eligible$dte - target_dte)
      minimum_dte_distance <- min(eligible$dte_distance)
      eligible <- eligible[eligible$dte_distance == minimum_dte_distance, , drop = FALSE]
      chosen_expiration <- min(eligible$expiration_date)
      eligible <- eligible[eligible$expiration_date == chosen_expiration, , drop = FALSE]
      strikes <- sort(unique(eligible$strike_price))
      chosen_strike <- strikes[which.min(abs(strikes - spot))]
      pair <- eligible[eligible$strike_price == chosen_strike, , drop = FALSE]
      call_symbol <- pair$option_symbol[pair$option_type == "call"]
      put_symbol <- pair$option_symbol[pair$option_type == "put"]
      rows[[idx]] <- data.frame(
        session_date = session_date,
        underlying_symbol = underlying,
        underlying_price = spot,
        expiration_date = chosen_expiration,
        dte = as.integer(chosen_expiration - session_date),
        strike_price = chosen_strike,
        strike_distance_fraction = abs(chosen_strike - spot) / spot,
        call_symbol = call_symbol[[1L]],
        put_symbol = put_symbol[[1L]],
        selection_status = "SELECTED",
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_gen54_o0_construct_measure <- function(selections, option_final_bars) {
  required <- c(
    "session_date", "underlying_symbol", "underlying_price", "expiration_date",
    "dte", "strike_price", "call_symbol", "put_symbol", "selection_status"
  )
  if (!all(required %in% names(selections))) {
    stop("O0 selections are missing required columns.", call. = FALSE)
  }
  if (!all(c("option_symbol", "session_date", "selected_price", "bar_timestamp", "feed") %in%
      names(option_final_bars))) {
    stop("O0 option bars are missing required construction columns.", call. = FALSE)
  }
  out <- selections
  call_match <- match(
    paste(out$call_symbol, out$session_date),
    paste(option_final_bars$option_symbol, option_final_bars$session_date)
  )
  put_match <- match(
    paste(out$put_symbol, out$session_date),
    paste(option_final_bars$option_symbol, option_final_bars$session_date)
  )
  out$call_bar_timestamp <- option_final_bars$bar_timestamp[call_match]
  out$put_bar_timestamp <- option_final_bars$bar_timestamp[put_match]
  out$call_vwap <- option_final_bars$selected_price[call_match]
  out$put_vwap <- option_final_bars$selected_price[put_match]
  out$option_feed <- option_final_bars$feed[call_match]
  out$matched_pair_valid <- out$selection_status == "SELECTED" &
    is.finite(out$underlying_price) &
    is.finite(out$call_vwap) &
    is.finite(out$put_vwap) &
    out$dte >= 21L & out$dte <= 45L &
    out$call_bar_timestamp == out$put_bar_timestamp
  out$normalized_implied_move_30d <- ifelse(
    out$matched_pair_valid,
    (out$call_vwap + out$put_vwap) / out$underlying_price * sqrt(30 / out$dte),
    NA_real_
  )
  out$construction_status <- ifelse(
    out$selection_status != "SELECTED",
    out$selection_status,
    ifelse(
      !is.finite(out$call_vwap) & !is.finite(out$put_vwap),
      "MISSING_BOTH_OPTION_FINAL_BARS",
      ifelse(
        !is.finite(out$call_vwap),
        "MISSING_CALL_FINAL_BAR",
        ifelse(
          !is.finite(out$put_vwap),
          "MISSING_PUT_FINAL_BAR",
          ifelse(
            out$call_bar_timestamp != out$put_bar_timestamp,
            "MISMATCHED_LEG_TIMESTAMPS",
            "VALID_MATCHED_STRADDLE"
          )
        )
      )
    )
  )
  out
}

g5_gen54_o0_coverage <- function(measure, minimum_coverage = 0.90) {
  rows <- lapply(split(measure, measure$underlying_symbol), function(part) {
    coverage <- mean(part$matched_pair_valid)
    data.frame(
      underlying_symbol = part$underlying_symbol[[1L]],
      eligible_sessions = nrow(part),
      valid_matched_sessions = sum(part$matched_pair_valid),
      coverage = coverage,
      coverage_gate = minimum_coverage,
      verdict = if (coverage >= minimum_coverage) "PASS_O0_COVERAGE" else "STOP_O0_COVERAGE",
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_gen54_o0_verdict <- function(measure, coverage, resolved_feed) {
  same_pair <- all(
    is.na(measure$normalized_implied_move_30d) |
      (
        measure$matched_pair_valid &
          measure$call_bar_timestamp == measure$put_bar_timestamp &
          measure$dte >= 21L & measure$dte <= 45L
      )
  )
  feed_labeled <- resolved_feed %in% c("opra", "indicative") &&
    all(is.na(measure$option_feed) | measure$option_feed == resolved_feed)
  coverage_pass <- all(coverage$verdict == "PASS_O0_COVERAGE")
  if (same_pair && feed_labeled && coverage_pass) {
    "PASS_O0_NARROW_RECONSTRUCTION"
  } else {
    "STOP_O0_RECONSTRUCTION"
  }
}
