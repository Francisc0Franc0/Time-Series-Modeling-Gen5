hreg31_stop <- function(message) stop(paste0("[HYP-REG-03.1] ", message), call. = FALSE)

hreg31_contract <- function() {
  list(
    hypothesis_id = "HYP-REG-03.1",
    as_of_timestamp = "2026-08-14 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    moving_average = 20L,
    impulse_lookback = 20L,
    percentile_lookback = 252L,
    horizons = c(5L, 20L, 63L),
    signal_assets = 10L,
    target_assets = 26L,
    breadth_assets = 18L,
    simulations = 200L,
    minimum_balanced_accuracy = 0.52,
    minimum_long_spearman = 0.05,
    minimum_positive_years = 4L,
    minimum_placebo_percentile = 0.90
  )
}

hreg31_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg31_stop("Lag must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA_real_, length(x)))
  c(rep(NA_real_, n), head(x, -n))
}

hreg31_sma <- function(x, n) {
  n <- as.integer(n)
  if (n < 1L) hreg31_stop("SMA length must be positive.")
  as.numeric(stats::filter(as.numeric(x), rep(1 / n, n), sides = 1L))
}

hreg31_prior_percentile <- function(x, lookback = 252L) {
  out <- rep(NA_real_, length(x)); lookback <- as.integer(lookback)
  if (length(x) <= lookback) return(out)
  for (i in seq.int(lookback + 1L, length(x))) {
    history <- x[seq.int(i - lookback, i - 1L)]
    if (is.finite(x[[i]]) && all(is.finite(history))) out[[i]] <- mean(history <= x[[i]])
  }
  out
}

hreg31_forward_open_return <- function(open, horizon) {
  n <- length(open); horizon <- as.integer(horizon); out <- rep(NA_real_, n)
  if (n <= horizon + 1L) return(out)
  idx <- seq_len(n - horizon - 1L)
  out[idx] <- log(open[idx + horizon + 1L] / open[idx + 1L])
  out
}

hreg31_validate_bars <- function(bars, contract = hreg31_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  if (!is.data.frame(bars) || !all(required %in% names(bars)) || !nrow(bars)) hreg31_stop("Daily-bar schema is incomplete or empty.")
  x <- bars; x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg31_stop("Dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg31_stop("Confirmation rows entered the diagnostic.")
  numeric_cols <- c("open", "high", "low", "close", "volume")
  if (any(!is.finite(as.matrix(x[numeric_cols]))) || any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) hreg31_stop("OHLCV values are invalid.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg31_build_signal <- function(bars, signal_symbols, contract = hreg31_contract()) {
  x <- hreg31_validate_bars(bars, contract)
  if (length(signal_symbols) != contract$signal_assets || !setequal(unique(x$symbol), signal_symbols)) hreg31_stop("Signal universe does not match the frozen ten ETFs.")
  parts <- lapply(signal_symbols, function(symbol) {
    z <- x[x$symbol == symbol, c("session_date", "close"), drop = FALSE]
    z[[paste0("depth_", symbol)]] <- log(z$close / hreg31_sma(z$close, contract$moving_average))
    z[c("session_date", paste0("depth_", symbol))]
  })
  wide <- Reduce(function(a, b) merge(a, b, by = "session_date", all = FALSE, sort = TRUE), parts)
  depth_cols <- paste0("depth_", signal_symbols)
  depth <- as.matrix(wide[depth_cols])
  wide$sector_inputs <- rowSums(is.finite(depth))
  wide$breadth_score <- apply(depth, 1L, function(v) if (all(is.finite(v))) stats::median(v) else NA_real_)
  wide$participation_fraction <- apply(depth, 1L, function(v) if (all(is.finite(v))) mean(v >= 0) else NA_real_)
  wide$breadth_impulse20 <- wide$breadth_score - hreg31_lag(wide$breadth_score, contract$impulse_lookback)
  wide$breadth_percentile <- hreg31_prior_percentile(wide$breadth_score, contract$percentile_lookback)
  wide$breadth_sign <- ifelse(is.na(wide$breadth_score), NA_character_, ifelse(wide$breadth_score >= 0, "UP", "DOWN"))
  wide
}

hreg31_build_target_ledger <- function(bars, signal, contract = hreg31_contract()) {
  x <- hreg31_validate_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) hreg31_stop("Target ledger requires exactly one symbol.")
  x$target_sma20 <- hreg31_sma(x$close, contract$moving_average)
  x$target_sma60 <- hreg31_sma(x$close, 60L)
  x$target_trend_score <- log(x$target_sma20 / x$target_sma60)
  for (h in contract$horizons) x[[paste0("forward_return_h", h)]] <- hreg31_forward_open_return(x$open, h)
  keep <- x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end
  x <- x[keep, , drop = FALSE]
  x <- merge(x, signal, by = "session_date", all.x = TRUE, sort = TRUE)
  x$analysis_index <- seq_len(nrow(x))
  for (h in contract$horizons) x[[paste0("nonoverlap_h", h)]] <- ((x$analysis_index - 1L) %% h == 0L)
  x
}

hreg31_direction_metrics <- function(score, target) {
  keep <- is.finite(score) & is.finite(target) & target != 0
  score <- score[keep]; target <- target[keep]
  if (!length(score)) return(c(accuracy = NA_real_, up_recall = NA_real_, down_recall = NA_real_, balanced_accuracy = NA_real_, predicted_up_fraction = NA_real_))
  predicted_up <- score >= 0; actual_up <- target > 0
  up_recall <- if (any(actual_up)) mean(predicted_up[actual_up]) else NA_real_
  down_recall <- if (any(!actual_up)) mean(!predicted_up[!actual_up]) else NA_real_
  c(accuracy = mean(predicted_up == actual_up), up_recall = up_recall, down_recall = down_recall,
    balanced_accuracy = mean(c(up_recall, down_recall), na.rm = TRUE), predicted_up_fraction = mean(predicted_up))
}

hreg31_quintile_spread <- function(percentile, target) {
  low <- is.finite(percentile) & percentile <= .20 & is.finite(target)
  high <- is.finite(percentile) & percentile > .80 & is.finite(target)
  if (!any(low) || !any(high)) return(c(q1_n = sum(low), q5_n = sum(high), q1_median = NA_real_, q5_median = NA_real_, q5_q1_spread = NA_real_))
  q1 <- stats::median(target[low]); q5 <- stats::median(target[high])
  c(q1_n = sum(low), q5_n = sum(high), q1_median = q1, q5_median = q5, q5_q1_spread = q5 - q1)
}

hreg31_asset_summary <- function(ledger, contract = hreg31_contract()) {
  rows <- list(); k <- 0L
  for (symbol in unique(ledger$symbol)) for (h in contract$horizons) {
    x <- ledger[ledger$symbol == symbol, ]; target <- x[[paste0("forward_return_h", h)]]
    keep <- x[[paste0("nonoverlap_h", h)]] & is.finite(x$breadth_score) & is.finite(target)
    direction <- hreg31_direction_metrics(x$breadth_score[keep], target[keep])
    quintile <- hreg31_quintile_spread(x$breadth_percentile[keep], target[keep])
    k <- k + 1L
    rows[[k]] <- data.frame(symbol = symbol, horizon = h, observations = sum(keep),
      spearman = if (sum(keep) >= 5L) suppressWarnings(stats::cor(x$breadth_score[keep], target[keep], method = "spearman")) else NA_real_,
      accuracy = direction[["accuracy"]], up_recall = direction[["up_recall"]], down_recall = direction[["down_recall"]],
      balanced_accuracy = direction[["balanced_accuracy"]], predicted_up_fraction = direction[["predicted_up_fraction"]],
      q1_n = quintile[[1L]], q5_n = quintile[[2L]], q1_median = quintile[[3L]], q5_median = quintile[[4L]], q5_q1_spread = quintile[[5L]], stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

hreg31_calendar_summary <- function(ledger, contract = hreg31_contract()) {
  rows <- list(); k <- 0L
  for (symbol in unique(ledger$symbol)) for (year in 2018:2023) for (h in contract$horizons) {
    x <- ledger[ledger$symbol == symbol & as.integer(format(ledger$session_date, "%Y")) == year, ]
    target <- x[[paste0("forward_return_h", h)]]; keep <- x[[paste0("nonoverlap_h", h)]] & is.finite(x$breadth_score) & is.finite(target)
    k <- k + 1L
    rows[[k]] <- data.frame(symbol = symbol, year = year, horizon = h, observations = sum(keep),
      spearman = if (sum(keep) >= 3L) suppressWarnings(stats::cor(x$breadth_score[keep], target[keep], method = "spearman")) else NA_real_, stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

hreg31_rotate <- function(x, shift) {
  n <- length(x); if (!n) return(x); shift <- as.integer(shift %% n)
  if (shift == 0L) return(x)
  c(tail(x, shift), head(x, n - shift))
}

hreg31_shift_signal <- function(signal, simulation_id) {
  out <- signal$breadth_score
  groups <- split(seq_len(nrow(signal)), format(signal$session_date, "%Y"))
  g <- 0L
  for (idx in groups) { g <- g + 1L; if (length(idx) < 3L) next; shift <- 1L + ((as.integer(simulation_id) * 37L + g * 17L) %% (length(idx) - 1L)); out[idx] <- hreg31_rotate(signal$breadth_score[idx], shift) }
  out
}

hreg31_placebo_summary <- function(ledger, signal, contract = hreg31_contract()) {
  rows <- list(); k <- 0L; date_match <- match(ledger$session_date, signal$session_date)
  for (simulation_id in seq_len(contract$simulations)) {
    shifted_signal <- hreg31_shift_signal(signal, simulation_id)
    shifted <- shifted_signal[date_match]
    for (h in c(20L, 63L)) {
      asset_values <- vapply(split(seq_len(nrow(ledger)), ledger$symbol), function(idx) {
        target <- ledger[[paste0("forward_return_h", h)]][idx]
        keep <- ledger[[paste0("nonoverlap_h", h)]][idx] & is.finite(shifted[idx]) & is.finite(target)
        if (sum(keep) < 5L) return(NA_real_)
        suppressWarnings(stats::cor(shifted[idx][keep], target[keep], method = "spearman"))
      }, numeric(1))
      k <- k + 1L
      rows[[k]] <- data.frame(simulation_id = simulation_id, horizon = h, panel_median_spearman = stats::median(asset_values, na.rm = TRUE), stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}

hreg31_hidden_deterioration <- function(ledger, contract = hreg31_contract()) {
  x <- ledger[ledger$symbol == "SPY", ]
  rows <- list(); k <- 0L
  for (year in c(NA_integer_, 2018:2023)) for (h in c(20L, 63L)) {
    target <- x[[paste0("forward_return_h", h)]]
    keep_year <- if (is.na(year)) rep(TRUE, nrow(x)) else as.integer(format(x$session_date, "%Y")) == year
    base <- keep_year & x[[paste0("nonoverlap_h", h)]] & x$target_trend_score >= 0 & is.finite(x$breadth_impulse20) & is.finite(target)
    decay <- base & x$breadth_impulse20 < 0; improve <- base & x$breadth_impulse20 >= 0
    k <- k + 1L
    rows[[k]] <- data.frame(year = if (is.na(year)) "ALL" else as.character(year), horizon = h,
      decay_n = sum(decay), improve_n = sum(improve), decay_median = if (any(decay)) stats::median(target[decay]) else NA_real_,
      improve_median = if (any(improve)) stats::median(target[improve]) else NA_real_,
      decay_minus_improve = if (any(decay) && any(improve)) stats::median(target[decay]) - stats::median(target[improve]) else NA_real_, stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}
