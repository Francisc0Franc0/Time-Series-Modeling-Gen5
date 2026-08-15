hreg_contract <- function() {
  list(
    hypothesis_id = "HYP-REG-01.1",
    status = "FROZEN_FOR_DIAGNOSTIC_EXECUTION",
    as_of_timestamp = "2026-08-14 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    atr_length = 14L,
    percentile_lookback = 252L,
    low_enter = 0.30,
    low_exit = 0.40,
    high_exit = 0.60,
    high_enter = 0.70,
    ewma_lambda = 0.94,
    horizons = c(1L, 5L, 20L),
    sensitivity_specs = data.frame(
      specification = c("ATR10_P252", "ATR20_P252", "ATR14_P126", "ATR14_P504"),
      atr_length = c(10L, 20L, 14L, 14L),
      percentile_lookback = c(252L, 252L, 126L, 504L),
      stringsAsFactors = FALSE
    )
  )
}

hreg_assert_bars <- function(bars) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) stop("Missing required columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(bars)) stop("Bars are empty.", call. = FALSE)
  bars$session_date <- as.Date(bars$session_date)
  if (any(is.na(bars$session_date))) stop("Invalid session_date.", call. = FALSE)
  if (anyDuplicated(bars[c("symbol", "session_date")])) stop("Duplicate symbol/session rows.", call. = FALSE)
  numeric_cols <- c("open", "high", "low", "close", "volume")
  invalid <- !is.finite(as.matrix(bars[numeric_cols]))
  if (any(invalid)) stop("Non-finite OHLCV values.", call. = FALSE)
  if (any(bars$open <= 0 | bars$high <= 0 | bars$low <= 0 | bars$close <= 0 | bars$volume < 0)) {
    stop("Invalid OHLCV values.", call. = FALSE)
  }
  if (any(bars$high < pmax(bars$open, bars$close, bars$low)) ||
      any(bars$low > pmin(bars$open, bars$close, bars$high))) {
    stop("OHLC price ordering is invalid.", call. = FALSE)
  }
  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

hreg_true_range <- function(high, low, close) {
  n <- length(close)
  if (length(high) != n || length(low) != n) stop("OHLC vectors differ in length.", call. = FALSE)
  previous_close <- c(NA_real_, head(close, -1L))
  out <- pmax(high - low, abs(high - previous_close), abs(low - previous_close), na.rm = TRUE)
  out[is.na(previous_close)] <- NA_real_
  out
}

hreg_wilder_atr <- function(true_range, length = 14L) {
  length <- as.integer(length)
  if (length < 2L) stop("ATR length must be at least 2.", call. = FALSE)
  out <- rep(NA_real_, length(true_range))
  finite <- which(is.finite(true_range))
  if (length(finite) < length) return(out)
  initial_position <- finite[[length]]
  initial_window <- finite[seq_len(length)]
  out[[initial_position]] <- mean(true_range[initial_window])
  if (initial_position < length(true_range)) {
    for (i in seq.int(initial_position + 1L, length(true_range))) {
      if (is.finite(true_range[[i]]) && is.finite(out[[i - 1L]])) {
        out[[i]] <- ((length - 1) * out[[i - 1L]] + true_range[[i]]) / length
      }
    }
  }
  out
}

hreg_ewma_volatility <- function(close, lambda = 0.94) {
  if (!is.numeric(close) || any(close <= 0, na.rm = TRUE)) stop("Close must be positive numeric values.", call. = FALSE)
  log_change <- c(NA_real_, diff(log(close)))
  variance <- rep(NA_real_, length(close))
  first <- which(is.finite(log_change))[[1L]]
  variance[[first]] <- log_change[[first]] ^ 2
  if (first < length(close)) {
    for (i in seq.int(first + 1L, length(close))) {
      if (is.finite(log_change[[i]]) && is.finite(variance[[i - 1L]])) {
        variance[[i]] <- lambda * variance[[i - 1L]] + (1 - lambda) * log_change[[i]] ^ 2
      }
    }
  }
  sqrt(variance)
}

hreg_rolling_percentile <- function(x, lookback = 252L) {
  lookback <- as.integer(lookback)
  if (lookback < 2L) stop("Percentile lookback must be at least 2.", call. = FALSE)
  out <- rep(NA_real_, length(x))
  if (length(x) <= lookback) return(out)
  for (i in seq.int(lookback + 1L, length(x))) {
    current <- x[[i]]
    history <- x[seq.int(i - lookback, i - 1L)]
    if (is.finite(current) && all(is.finite(history))) {
      out[[i]] <- (sum(history < current) + 0.5 * sum(history == current)) / lookback
    }
  }
  out
}

hreg_raw_state <- function(score, low = 0.30, high = 0.70) {
  out <- rep(NA_character_, length(score))
  out[is.finite(score) & score < low] <- "LOW"
  out[is.finite(score) & score >= low & score <= high] <- "MEDIUM"
  out[is.finite(score) & score > high] <- "HIGH"
  out
}

hreg_hysteretic_state <- function(score, low_enter = 0.30, low_exit = 0.40,
                                  high_exit = 0.60, high_enter = 0.70) {
  out <- rep(NA_character_, length(score))
  current <- NA_character_
  for (i in seq_along(score)) {
    value <- score[[i]]
    if (!is.finite(value)) next
    if (is.na(current)) {
      current <- if (value < low_enter) "LOW" else if (value > high_enter) "HIGH" else "MEDIUM"
    } else if (identical(current, "LOW")) {
      if (value > high_enter) current <- "HIGH" else if (value > low_exit) current <- "MEDIUM"
    } else if (identical(current, "HIGH")) {
      if (value < low_enter) current <- "LOW" else if (value < high_exit) current <- "MEDIUM"
    } else {
      if (value < low_enter) current <- "LOW" else if (value > high_enter) current <- "HIGH"
    }
    out[[i]] <- current
  }
  out
}

hreg_forward_mean <- function(x, horizon) {
  horizon <- as.integer(horizon)
  if (horizon < 1L) stop("Horizon must be positive.", call. = FALSE)
  out <- rep(NA_real_, length(x))
  if (length(x) <= horizon) return(out)
  for (i in seq_len(length(x) - horizon)) {
    future <- x[seq.int(i + 1L, i + horizon)]
    if (all(is.finite(future))) out[[i]] <- mean(future)
  }
  out
}

hreg_nonoverlap_flag <- function(eligible, horizon) {
  out <- rep(FALSE, length(eligible))
  positions <- which(eligible)
  if (length(positions)) out[positions[seq.int(1L, length(positions), by = as.integer(horizon))]] <- TRUE
  out
}

hreg_build_asset_ledger <- function(bars, contract = hreg_contract()) {
  bars <- hreg_assert_bars(bars)
  if (length(unique(bars$symbol)) != 1L) stop("Asset ledger requires exactly one symbol.", call. = FALSE)
  bars <- bars[order(bars$session_date), , drop = FALSE]
  tr <- hreg_true_range(bars$high, bars$low, bars$close)
  ntr <- tr / c(NA_real_, head(bars$close, -1L))
  atr <- hreg_wilder_atr(tr, contract$atr_length)
  atr_pct <- 100 * atr / bars$close
  atr_score <- hreg_rolling_percentile(atr_pct, contract$percentile_lookback)
  ewma_vol <- hreg_ewma_volatility(bars$close, contract$ewma_lambda)
  ewma_score <- hreg_rolling_percentile(ewma_vol, contract$percentile_lookback)
  ntr_score <- hreg_rolling_percentile(ntr, contract$percentile_lookback)
  out <- data.frame(
    symbol = bars$symbol,
    session_date = bars$session_date,
    open = bars$open,
    high = bars$high,
    low = bars$low,
    close = bars$close,
    true_range = tr,
    normalized_true_range = ntr,
    atr = atr,
    atr_percent = atr_pct,
    atr_percentile = atr_score,
    raw_state = hreg_raw_state(atr_score, contract$low_enter, contract$high_enter),
    regime_state = hreg_hysteretic_state(
      atr_score, contract$low_enter, contract$low_exit,
      contract$high_exit, contract$high_enter
    ),
    current_ntr_percentile = ntr_score,
    ewma_volatility = ewma_vol,
    ewma_vol_percentile = ewma_score,
    stringsAsFactors = FALSE
  )
  for (h in contract$horizons) {
    target_name <- paste0("future_mean_ntr_h", h)
    flag_name <- paste0("nonoverlap_h", h)
    out[[target_name]] <- hreg_forward_mean(ntr, h)
    eligible <- out$session_date >= contract$analysis_start &
      out$session_date <= contract$analysis_end &
      is.finite(out$atr_percentile) & is.finite(out[[target_name]])
    out[[flag_name]] <- hreg_nonoverlap_flag(eligible, h)
  }
  for (i in seq_len(nrow(contract$sensitivity_specs))) {
    spec <- contract$sensitivity_specs[i, , drop = FALSE]
    spec_atr <- hreg_wilder_atr(tr, spec$atr_length)
    spec_score <- hreg_rolling_percentile(100 * spec_atr / bars$close, spec$percentile_lookback)
    state_name <- paste0("sensitivity_state_", tolower(spec$specification))
    out[[state_name]] <- hreg_hysteretic_state(
      spec_score, contract$low_enter, contract$low_exit,
      contract$high_exit, contract$high_enter
    )
  }
  out
}

hreg_spearman <- function(x, y) {
  keep <- is.finite(x) & is.finite(y)
  if (sum(keep) < 4L || length(unique(x[keep])) < 2L || length(unique(y[keep])) < 2L) return(NA_real_)
  suppressWarnings(stats::cor(x[keep], y[keep], method = "spearman"))
}

hreg_asset_predictive_summary <- function(ledger, contract = hreg_contract()) {
  score_columns <- c(
    ATR_PERCENTILE = "atr_percentile",
    CURRENT_NTR_PERCENTILE = "current_ntr_percentile",
    EWMA_VOL_PERCENTILE = "ewma_vol_percentile"
  )
  rows <- list(); k <- 0L
  for (symbol in unique(ledger$symbol)) {
    x <- ledger[ledger$symbol == symbol & ledger$session_date >= contract$analysis_start &
                  ledger$session_date <= contract$analysis_end, , drop = FALSE]
    for (h in contract$horizons) {
      target <- x[[paste0("future_mean_ntr_h", h)]]
      for (sample_name in c("ALL_OVERLAPPING", "NON_OVERLAPPING")) {
        sample_keep <- if (sample_name == "ALL_OVERLAPPING") rep(TRUE, nrow(x)) else x[[paste0("nonoverlap_h", h)]]
        for (model in names(score_columns)) {
          score <- x[[score_columns[[model]]]]
          keep <- sample_keep & is.finite(score) & is.finite(target)
          k <- k + 1L
          rows[[k]] <- data.frame(
            symbol = symbol, horizon = h, sample = sample_name, model = model,
            observations = sum(keep), spearman = hreg_spearman(score[keep], target[keep]),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  do.call(rbind, rows)
}

hreg_state_prediction_summary <- function(ledger, contract = hreg_contract()) {
  rows <- list(); k <- 0L
  for (symbol in unique(ledger$symbol)) {
    x <- ledger[ledger$symbol == symbol & ledger$session_date >= contract$analysis_start &
                  ledger$session_date <= contract$analysis_end, , drop = FALSE]
    for (h in contract$horizons) {
      target <- x[[paste0("future_mean_ntr_h", h)]]
      for (sample_name in c("ALL_OVERLAPPING", "NON_OVERLAPPING")) {
        sample_keep <- if (sample_name == "ALL_OVERLAPPING") rep(TRUE, nrow(x)) else x[[paste0("nonoverlap_h", h)]]
        medians <- setNames(rep(NA_real_, 3L), c("LOW", "MEDIUM", "HIGH"))
        counts <- setNames(integer(3L), c("LOW", "MEDIUM", "HIGH"))
        for (state in names(medians)) {
          keep <- sample_keep & x$regime_state == state & is.finite(target)
          counts[[state]] <- sum(keep, na.rm = TRUE)
          if (counts[[state]]) medians[[state]] <- stats::median(target[keep], na.rm = TRUE)
        }
        k <- k + 1L
        rows[[k]] <- data.frame(
          symbol = symbol, horizon = h, sample = sample_name,
          low_n = counts[["LOW"]], medium_n = counts[["MEDIUM"]], high_n = counts[["HIGH"]],
          low_median = medians[["LOW"]], medium_median = medians[["MEDIUM"]], high_median = medians[["HIGH"]],
          medium_low_ratio = medians[["MEDIUM"]] / medians[["LOW"]],
          high_low_ratio = medians[["HIGH"]] / medians[["LOW"]],
          monotonic_ordering = isTRUE(medians[["HIGH"]] > medians[["MEDIUM"]] && medians[["MEDIUM"]] > medians[["LOW"]]),
          high_above_low = isTRUE(medians[["HIGH"]] > medians[["LOW"]]), stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

hreg_run_ledger <- function(ledger, contract = hreg_contract()) {
  rows <- list(); k <- 0L
  for (symbol in unique(ledger$symbol)) {
    x <- ledger[ledger$symbol == symbol & ledger$session_date >= contract$analysis_start &
                  ledger$session_date <= contract$analysis_end & !is.na(ledger$regime_state), , drop = FALSE]
    if (!nrow(x)) next
    groups <- cumsum(c(TRUE, x$regime_state[-1L] != head(x$regime_state, -1L)))
    for (g in unique(groups)) {
      z <- x[groups == g, , drop = FALSE]
      k <- k + 1L
      rows[[k]] <- data.frame(
        symbol = symbol, state = z$regime_state[[1L]], start_date = min(z$session_date),
        end_date = max(z$session_date), sessions = nrow(z), stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows)) do.call(rbind, rows) else data.frame()
}

hreg_state_diagnostics <- function(ledger, contract = hreg_contract()) {
  analysis <- ledger[ledger$session_date >= contract$analysis_start &
                       ledger$session_date <= contract$analysis_end & !is.na(ledger$regime_state), , drop = FALSE]
  occupancy <- do.call(rbind, lapply(split(analysis, analysis$symbol), function(x) {
    counts <- table(factor(x$regime_state, levels = c("LOW", "MEDIUM", "HIGH")))
    data.frame(symbol = x$symbol[[1L]], total_sessions = sum(counts),
               low_fraction = counts[["LOW"]] / sum(counts),
               medium_fraction = counts[["MEDIUM"]] / sum(counts),
               high_fraction = counts[["HIGH"]] / sum(counts), stringsAsFactors = FALSE)
  }))
  transition_counts <- matrix(0L, 3L, 3L, dimnames = list(from = c("LOW", "MEDIUM", "HIGH"), to = c("LOW", "MEDIUM", "HIGH")))
  reversal_rows <- list(); r <- 0L
  for (symbol in unique(analysis$symbol)) {
    x <- analysis[analysis$symbol == symbol, , drop = FALSE]
    states <- x$regime_state
    if (length(states) > 1L) {
      for (i in seq_len(length(states) - 1L)) transition_counts[states[[i]], states[[i + 1L]]] <- transition_counts[states[[i]], states[[i + 1L]]] + 1L
    }
    reversals <- if (length(states) >= 3L) sum(states[-c(1L, length(states))] != states[-c(length(states) - 1L, length(states))] &
                                                states[-c(1L, 2L)] == states[-c(length(states) - 1L, length(states))]) else 0L
    switches <- if (length(states) > 1L) sum(states[-1L] != head(states, -1L)) else 0L
    years <- max(1, as.numeric(max(x$session_date) - min(x$session_date)) / 365.25)
    r <- r + 1L
    reversal_rows[[r]] <- data.frame(symbol = symbol, switches = switches, switches_per_year = switches / years,
                                     one_session_reversals = reversals, reversal_fraction = reversals / max(switches, 1L), stringsAsFactors = FALSE)
  }
  transition <- as.data.frame(as.table(transition_counts), stringsAsFactors = FALSE)
  names(transition) <- c("from_state", "to_state", "count")
  totals <- rowSums(transition_counts)
  transition$probability <- mapply(function(from, count) count / max(totals[[from]], 1L), transition$from_state, transition$count)
  list(occupancy = occupancy, transition = transition, switching = do.call(rbind, reversal_rows), runs = hreg_run_ledger(ledger, contract))
}

hreg_sensitivity_summary <- function(ledger, contract = hreg_contract()) {
  rows <- list(); k <- 0L
  for (i in seq_len(nrow(contract$sensitivity_specs))) {
    name <- contract$sensitivity_specs$specification[[i]]
    column <- paste0("sensitivity_state_", tolower(name))
    for (symbol in unique(ledger$symbol)) {
      x <- ledger[ledger$symbol == symbol & ledger$session_date >= contract$analysis_start &
                    ledger$session_date <= contract$analysis_end, , drop = FALSE]
      keep <- !is.na(x$regime_state) & !is.na(x[[column]])
      k <- k + 1L
      rows[[k]] <- data.frame(
        specification = name, symbol = symbol, observations = sum(keep),
        state_agreement = if (any(keep)) mean(x$regime_state[keep] == x[[column]][keep]) else NA_real_,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}
