ioaa_stop <- function(message) {
  stop(paste0("[INTRADAY OPENING ATR ATLAS] ", message), call. = FALSE)
}

ioaa_contract <- function() {
  list(
    study_id = "HYP-INTRADAY-OPENING-ATR-ATLAS-01.1",
    sample_role = "MECHANISM_REPLICATION",
    as_of_timestamp = "2026-08-31 17:30:00 America/New_York",
    source_start = as.Date("2017-09-01"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2025-12-31"),
    required_slots = 1:13,
    rolling_sessions = 252L,
    opening_quantile_probability = 0.80,
    quantile_type = 8L,
    atr_length = 14L,
    atr_percentile_lookback = 252L,
    atr_states = c("LOW", "MEDIUM", "HIGH"),
    expected_symbols = c(
      "AMD", "TSLA", "MSFT", "TXN", "JPM", "AXP", "JNJ", "UNH",
      "XOM", "SLB", "PG", "KO", "HD", "MCD", "CAT", "UNP", "NEE",
      "DUK", "APD", "SHW", "AMT", "PLD", "GOOGL", "CMCSA", "SPY", "QQQ"
    ),
    excluded_symbol = "NVDA",
    eras = data.frame(
      era = c("2018-2020", "2021-2023", "2024-2025"),
      start = as.Date(c("2018-01-02", "2021-01-04", "2024-01-02")),
      end = as.Date(c("2020-12-31", "2023-12-29", "2025-12-31")),
      stringsAsFactors = FALSE
    ),
    minimum_tail_state_trades = 25L,
    minimum_eligible_assets = 24L,
    minimum_negative_asset_fraction = 0.60
  )
}

ioaa_validate_contract <- function(contract = ioaa_contract()) {
  frozen <- ioaa_contract()
  scalar_fields <- c(
    "study_id", "sample_role", "as_of_timestamp", "source_start",
    "analysis_start", "analysis_end", "required_slots", "rolling_sessions",
    "opening_quantile_probability", "quantile_type", "atr_length",
    "atr_percentile_lookback", "atr_states", "expected_symbols",
    "excluded_symbol", "minimum_tail_state_trades", "minimum_eligible_assets",
    "minimum_negative_asset_fraction"
  )
  if (!all(vapply(scalar_fields, function(field) {
    isTRUE(all.equal(contract[[field]], frozen[[field]], check.attributes = TRUE))
  }, logical(1))) || !isTRUE(all.equal(contract$eras, frozen$eras))) {
    ioaa_stop("The frozen mechanism-replication contract changed.")
  }
  contract
}

ioaa_validate_registry <- function(registry, contract = ioaa_contract()) {
  required <- c("symbol", "sector", "asset_type")
  if (!is.data.frame(registry) || !all(required %in% names(registry))) {
    ioaa_stop("The pre-existing intraday registry is unavailable or incomplete.")
  }
  x <- registry[, required, drop = FALSE]
  x$symbol <- toupper(trimws(as.character(x$symbol)))
  if (anyDuplicated(x$symbol) || !identical(x$symbol, contract$expected_symbols) ||
      contract$excluded_symbol %in% x$symbol) {
    ioaa_stop("The atlas symbols changed or the sealed NVDA symbol entered the atlas.")
  }
  x
}

ioaa_validate_bars <- function(bars, contract = ioaa_contract()) {
  required <- c(
    "symbol", "timestamp_utc", "session_date", "bar_slot", "open", "high",
    "low", "close", "volume", "provider", "feed", "timeframe", "adjustment"
  )
  if (!is.data.frame(bars) || !nrow(bars) || !all(required %in% names(bars))) {
    ioaa_stop("The adjusted SIP 30-minute atlas is unavailable or incomplete.")
  }
  x <- bars[, required, drop = FALSE]
  x$symbol <- toupper(as.character(x$symbol))
  x$session_date <- as.Date(x$session_date)
  x$bar_slot <- as.integer(x$bar_slot)
  numeric_fields <- c("open", "high", "low", "close", "volume")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  x <- x[x$symbol %in% contract$expected_symbols &
           x$session_date >= contract$source_start &
           x$session_date <= contract$analysis_end, , drop = FALSE]
  x <- x[order(x$symbol, x$session_date, x$bar_slot), , drop = FALSE]
  if (!identical(unique(x$symbol), sort(contract$expected_symbols)) ||
      anyDuplicated(x[c("symbol", "session_date", "bar_slot")]) ||
      any(!x$bar_slot %in% 1:13) || any(!is.finite(as.matrix(x[numeric_fields]))) ||
      any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0) ||
      any(x$high < pmax(x$open, x$close, x$low)) ||
      any(x$low > pmin(x$open, x$close, x$high)) ||
      !all(x$provider == "alpaca") || !all(x$feed == "sip") ||
      !all(x$timeframe == "30Min") || !all(x$adjustment == "all") ||
      contract$excluded_symbol %in% x$symbol) {
    ioaa_stop("Bars violate the frozen symbol, timing, OHLCV, or provider contract.")
  }
  x
}

ioaa_rolling_threshold <- function(x, lookback = 252L, probability = 0.80,
                                   quantile_type = 8L) {
  x <- as.numeric(x)
  lookback <- as.integer(lookback)
  out <- rep(NA_real_, length(x))
  if (lookback < 2L || length(x) <= lookback || any(!is.finite(x))) return(out)
  for (i in seq.int(lookback + 1L, length(x))) {
    out[[i]] <- unname(stats::quantile(
      x[seq.int(i - lookback, i - 1L)], probability,
      type = quantile_type, names = FALSE
    ))
  }
  out
}

ioaa_assign_era <- function(date, eras = ioaa_contract()$eras) {
  date <- as.Date(date)
  out <- rep(NA_character_, length(date))
  for (i in seq_len(nrow(eras))) {
    keep <- date >= eras$start[[i]] & date <= eras$end[[i]]
    out[keep] <- eras$era[[i]]
  }
  out
}

ioaa_daily_from_intraday <- function(bars) {
  groups <- split(seq_len(nrow(bars)), interaction(bars$symbol, bars$session_date, drop = TRUE))
  rows <- lapply(groups, function(index) {
    x <- bars[index, , drop = FALSE]
    x <- x[order(x$bar_slot), , drop = FALSE]
    data.frame(
      symbol = x$symbol[[1L]], session_date = x$session_date[[1L]],
      open = x$open[[1L]], high = max(x$high), low = min(x$low),
      close = x$close[[nrow(x)]], volume = sum(x$volume),
      intraday_bar_count = nrow(x), stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$symbol, out$session_date), , drop = FALSE]
}

ioaa_full_sessions <- function(bars, contract = ioaa_contract()) {
  groups <- split(seq_len(nrow(bars)), interaction(bars$symbol, bars$session_date, drop = TRUE))
  rows <- lapply(groups, function(index) {
    x <- bars[index, , drop = FALSE]
    x <- x[order(x$bar_slot), , drop = FALSE]
    if (!identical(x$bar_slot, contract$required_slots)) return(NULL)
    data.frame(
      symbol = x$symbol[[1L]], session_date = x$session_date[[1L]],
      first_bar_open = x$open[[1L]], ten_am_price = x$close[[1L]],
      session_close = x$close[[nrow(x)]],
      opening_log_return = log(x$close[[1L]] / x$open[[1L]]),
      remainder_log_return = log(x$close[[nrow(x)]] / x$close[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) ioaa_stop("No full 13-bar sessions remain.")
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$symbol, out$session_date), , drop = FALSE]
}

ioaa_build_asset_sessions <- function(bars, symbol, contract = ioaa_contract()) {
  x <- bars[bars$symbol == symbol, , drop = FALSE]
  daily <- ioaa_daily_from_intraday(x)
  state_contract <- hreg_contract()
  state_contract$atr_length <- contract$atr_length
  state_contract$percentile_lookback <- contract$atr_percentile_lookback
  state_contract$analysis_start <- contract$source_start
  state_contract$analysis_end <- contract$analysis_end
  state_contract$horizons <- 1L
  state_contract$sensitivity_specs <- state_contract$sensitivity_specs[0, , drop = FALSE]
  state <- hreg_build_asset_ledger(daily, state_contract)
  full <- ioaa_full_sessions(x, contract)
  full$rolling_opening_q80 <- ioaa_rolling_threshold(
    full$opening_log_return, contract$rolling_sessions,
    contract$opening_quantile_probability, contract$quantile_type
  )
  full$threshold_window_end <- c(rep(as.Date(NA), contract$rolling_sessions),
                                 head(full$session_date, -contract$rolling_sessions))
  current_index <- match(full$session_date, state$session_date)
  prior_index <- current_index - 1L
  full$state_session <- as.Date(NA)
  full$atrp_state <- NA_character_
  valid_prior <- !is.na(current_index) & prior_index >= 1L
  full$state_session[valid_prior] <- state$session_date[prior_index[valid_prior]]
  full$atrp_state[valid_prior] <- state$regime_state[prior_index[valid_prior]]
  full$opening_tail_signal <- is.finite(full$rolling_opening_q80) &
    full$opening_log_return >= full$rolling_opening_q80
  full$era <- ioaa_assign_era(full$session_date, contract$eras)
  full <- full[
    full$session_date >= contract$analysis_start &
      full$session_date <= contract$analysis_end &
      !is.na(full$era) & !is.na(full$atrp_state) &
      is.finite(full$rolling_opening_q80), , drop = FALSE
  ]
  if (!nrow(full) || any(full$state_session >= full$session_date) ||
      any(full$threshold_window_end >= full$session_date) ||
      any(!full$atrp_state %in% contract$atr_states)) {
    ioaa_stop(paste("Causal session construction failed for", symbol))
  }
  full
}

ioaa_state_statistics <- function(x) {
  data.frame(
    observations = nrow(x),
    mean_remainder_log_return = if (nrow(x)) mean(x$remainder_log_return) else NA_real_,
    median_remainder_log_return = if (nrow(x)) stats::median(x$remainder_log_return) else NA_real_,
    probability_remainder_up = if (nrow(x)) mean(x$remainder_log_return > 0) else NA_real_,
    stringsAsFactors = FALSE
  )
}

ioaa_asset_summary <- function(sessions, contract = ioaa_contract()) {
  rows <- lapply(contract$expected_symbols, function(symbol) {
    x <- sessions[sessions$symbol == symbol & sessions$opening_tail_signal, , drop = FALSE]
    low_med <- x[x$atrp_state %in% c("LOW", "MEDIUM"), , drop = FALSE]
    high <- x[x$atrp_state == "HIGH", , drop = FALSE]
    a <- ioaa_state_statistics(low_med)
    b <- ioaa_state_statistics(high)
    data.frame(
      symbol = symbol,
      low_med_observations = a$observations,
      high_observations = b$observations,
      low_med_mean_remainder = a$mean_remainder_log_return,
      high_mean_remainder = b$mean_remainder_log_return,
      low_med_median_remainder = a$median_remainder_log_return,
      high_median_remainder = b$median_remainder_log_return,
      low_med_probability_up = a$probability_remainder_up,
      high_probability_up = b$probability_remainder_up,
      high_minus_low_med_mean = b$mean_remainder_log_return - a$mean_remainder_log_return,
      eligible = a$observations >= contract$minimum_tail_state_trades &
        b$observations >= contract$minimum_tail_state_trades,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

ioaa_asset_era_summary <- function(sessions, contract = ioaa_contract()) {
  rows <- list()
  z <- 0L
  for (era in contract$eras$era) for (symbol in contract$expected_symbols) {
    x <- sessions[sessions$symbol == symbol & sessions$era == era &
                    sessions$opening_tail_signal, , drop = FALSE]
    low_med <- x[x$atrp_state %in% c("LOW", "MEDIUM"), , drop = FALSE]
    high <- x[x$atrp_state == "HIGH", , drop = FALSE]
    z <- z + 1L
    rows[[z]] <- data.frame(
      era = era, symbol = symbol,
      low_med_observations = nrow(low_med), high_observations = nrow(high),
      low_med_mean_remainder = if (nrow(low_med)) mean(low_med$remainder_log_return) else NA_real_,
      high_mean_remainder = if (nrow(high)) mean(high$remainder_log_return) else NA_real_,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  out$high_minus_low_med_mean <- out$high_mean_remainder - out$low_med_mean_remainder
  out$eligible <- out$low_med_observations >= 5L & out$high_observations >= 5L &
    is.finite(out$high_minus_low_med_mean)
  out
}

ioaa_era_summary <- function(asset_era, sessions, contract = ioaa_contract()) {
  rows <- lapply(contract$eras$era, function(era) {
    asset <- asset_era[asset_era$era == era & asset_era$eligible, , drop = FALSE]
    x <- sessions[sessions$era == era & sessions$opening_tail_signal, , drop = FALSE]
    low_med <- x[x$atrp_state %in% c("LOW", "MEDIUM"), , drop = FALSE]
    high <- x[x$atrp_state == "HIGH", , drop = FALSE]
    data.frame(
      era = era, eligible_assets = nrow(asset),
      median_asset_high_minus_low_med = stats::median(asset$high_minus_low_med_mean),
      negative_asset_fraction = mean(asset$high_minus_low_med_mean < 0),
      pooled_low_med_observations = nrow(low_med), pooled_high_observations = nrow(high),
      pooled_low_med_mean_remainder = mean(low_med$remainder_log_return),
      pooled_high_mean_remainder = mean(high$remainder_log_return),
      pooled_high_minus_low_med = mean(high$remainder_log_return) - mean(low_med$remainder_log_return),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

ioaa_sector_summary <- function(asset_summary, registry) {
  x <- merge(registry, asset_summary, by = "symbol", sort = FALSE)
  x <- x[x$eligible, , drop = FALSE]
  rows <- lapply(split(x, x$sector), function(z) data.frame(
    sector = z$sector[[1L]], assets = nrow(z),
    median_high_minus_low_med = stats::median(z$high_minus_low_med_mean),
    negative_asset_fraction = mean(z$high_minus_low_med_mean < 0),
    stringsAsFactors = FALSE
  ))
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$median_high_minus_low_med), , drop = FALSE]
}

ioaa_pooled_state_summary <- function(sessions) {
  x <- sessions[sessions$opening_tail_signal, , drop = FALSE]
  states <- list(
    LOW_MEDIUM = x[x$atrp_state %in% c("LOW", "MEDIUM"), , drop = FALSE],
    HIGH = x[x$atrp_state == "HIGH", , drop = FALSE]
  )
  do.call(rbind, lapply(names(states), function(state) {
    out <- ioaa_state_statistics(states[[state]])
    data.frame(atr_group = state, out, stringsAsFactors = FALSE)
  }))
}

ioaa_mechanism_gate <- function(asset_summary, era_summary, pooled_state,
                                contract = ioaa_contract()) {
  eligible <- asset_summary[asset_summary$eligible, , drop = FALSE]
  median_contrast <- stats::median(eligible$high_minus_low_med_mean)
  negative_fraction <- mean(eligible$high_minus_low_med_mean < 0)
  high_mean <- pooled_state$mean_remainder_log_return[pooled_state$atr_group == "HIGH"]
  checks <- data.frame(
    gate_id = c(
      "asset_support", "negative_median_asset_contrast",
      "negative_asset_breadth", "negative_contrast_in_every_era",
      "pooled_high_atr_tail_nonpositive"
    ),
    passed = c(
      nrow(eligible) >= contract$minimum_eligible_assets,
      is.finite(median_contrast) && median_contrast < 0,
      is.finite(negative_fraction) && negative_fraction >= contract$minimum_negative_asset_fraction,
      nrow(era_summary) == nrow(contract$eras) &&
        all(era_summary$median_asset_high_minus_low_med < 0),
      length(high_mean) == 1L && is.finite(high_mean) && high_mean <= 0
    ),
    observed = c(
      sprintf("%d eligible assets; minimum %d", nrow(eligible), contract$minimum_eligible_assets),
      sprintf("%+.3f%% median HIGH-minus-LOW/MED", 100 * median_contrast),
      sprintf("%.1f%% negative; minimum %.1f%%", 100 * negative_fraction,
              100 * contract$minimum_negative_asset_fraction),
      paste(sprintf("%s %+.3f%%", era_summary$era,
                    100 * era_summary$median_asset_high_minus_low_med), collapse = "; "),
      sprintf("%+.3f%% pooled HIGH-ATR tail mean", 100 * high_mean)
    ),
    stringsAsFactors = FALSE
  )
  list(
    checks = checks,
    verdict = if (all(checks$passed))
      "MECHANISM_REPLICATION_PASS_FOLLOWUP_REVIEW_REQUIRED" else
      "STOP_MECHANISM_REPLICATION_GATES_FAILED"
  )
}

ioaa_build_study <- function(bars, registry, contract = ioaa_contract()) {
  contract <- ioaa_validate_contract(contract)
  registry <- ioaa_validate_registry(registry, contract)
  bars <- ioaa_validate_bars(bars, contract)
  sessions <- do.call(rbind, lapply(contract$expected_symbols, function(symbol) {
    ioaa_build_asset_sessions(bars, symbol, contract)
  }))
  rownames(sessions) <- NULL
  sessions <- sessions[order(sessions$symbol, sessions$session_date), , drop = FALSE]
  assets <- ioaa_asset_summary(sessions, contract)
  asset_eras <- ioaa_asset_era_summary(sessions, contract)
  eras <- ioaa_era_summary(asset_eras, sessions, contract)
  sectors <- ioaa_sector_summary(assets, registry)
  pooled <- ioaa_pooled_state_summary(sessions)
  gate <- ioaa_mechanism_gate(assets, eras, pooled, contract)
  list(
    sessions = sessions, asset_summary = assets,
    asset_era_summary = asset_eras, era_summary = eras,
    sector_summary = sectors, pooled_state_summary = pooled,
    gate = gate
  )
}
