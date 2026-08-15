hreg21_stop <- function(message) stop(paste0("[HYP-REG-02] ", message), call. = FALSE)

hreg21_contract <- function() {
  list(
    hypothesis_id = "HYP-REG-02.1",
    joint_hypothesis_id = "HYP-REG-02.2",
    as_of_timestamp = "2026-08-14 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    fast_sma = 20L,
    slow_sma = 60L,
    return_benchmark_lookback = 63L,
    percentile_lookback = 252L,
    horizons = c(5L, 20L, 63L),
    simulations = 200L,
    minimum_assets = 26L,
    breadth_assets = 18L,
    minimum_balanced_accuracy = 0.52,
    minimum_long_spearman = 0.05,
    minimum_positive_years = 4L,
    minimum_placebo_percentile = 0.90,
    maximum_joint_abs_correlation = 0.35
  )
}

hreg21_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) hreg21_stop("Lag must be non-negative.")
  if (n == 0L) return(x)
  if (n >= length(x)) return(rep(NA_real_, length(x)))
  c(rep(NA_real_, n), head(x, -n))
}

hreg21_sma <- function(x, n) {
  n <- as.integer(n)
  if (n < 1L) hreg21_stop("SMA length must be positive.")
  if (!length(x)) return(numeric())
  as.numeric(stats::filter(as.numeric(x), rep(1 / n, n), sides = 1L))
}

hreg21_prior_percentile <- function(x, lookback = 252L) {
  lookback <- as.integer(lookback)
  out <- rep(NA_real_, length(x))
  if (length(x) <= lookback) return(out)
  for (i in seq.int(lookback + 1L, length(x))) {
    history <- x[seq.int(i - lookback, i - 1L)]
    if (is.finite(x[[i]]) && all(is.finite(history))) out[[i]] <- mean(history <= x[[i]])
  }
  out
}

hreg21_forward_open_return <- function(open, horizon) {
  horizon <- as.integer(horizon)
  n <- length(open)
  out <- rep(NA_real_, n)
  if (n <= horizon + 1L) return(out)
  idx <- seq_len(n - horizon - 1L)
  out[idx] <- log(open[idx + horizon + 1L] / open[idx + 1L])
  out
}

hreg21_forward_exit_date <- function(dates, horizon) {
  horizon <- as.integer(horizon)
  n <- length(dates)
  out <- rep(as.Date(NA), n)
  if (n <= horizon + 1L) return(out)
  idx <- seq_len(n - horizon - 1L)
  out[idx] <- dates[idx + horizon + 1L]
  out
}

hreg21_validate_bars <- function(bars, contract = hreg21_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  if (!is.data.frame(bars) || !all(required %in% names(bars))) hreg21_stop("Daily-bar schema is incomplete.")
  if (!nrow(bars)) hreg21_stop("Daily bars are empty.")
  x <- bars
  x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg21_stop("Daily dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg21_stop("Confirmation rows entered the diagnostic.")
  numeric_cols <- c("open", "high", "low", "close", "volume")
  if (any(!is.finite(as.matrix(x[numeric_cols])))) hreg21_stop("Daily bars contain non-finite values.")
  if (any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) hreg21_stop("Daily bars contain invalid OHLCV values.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg21_build_asset_ledger <- function(bars, contract = hreg21_contract()) {
  x <- hreg21_validate_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) hreg21_stop("Asset ledger requires exactly one symbol.")
  x$sma20 <- hreg21_sma(x$close, contract$fast_sma)
  x$sma60 <- hreg21_sma(x$close, contract$slow_sma)
  x$trend_score <- log(x$sma20 / x$sma60)
  x$price_sma60_score <- log(x$close / x$sma60)
  x$return63_score <- log(x$close / hreg21_lag(x$close, contract$return_benchmark_lookback))
  x$trend_percentile <- hreg21_prior_percentile(x$trend_score, contract$percentile_lookback)
  x$trend_sign <- ifelse(is.na(x$trend_score), NA_character_, ifelse(x$trend_score >= 0, "UP", "DOWN"))
  analysis_rows <- x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end
  x$analysis_index <- NA_integer_
  x$analysis_index[analysis_rows] <- seq_len(sum(analysis_rows))
  for (h in contract$horizons) {
    target <- hreg21_forward_open_return(x$open, h)
    exit_date <- hreg21_forward_exit_date(x$session_date, h)
    target[!is.na(exit_date) & exit_date >= contract$confirmation_start] <- NA_real_
    x[[paste0("forward_return_h", h)]] <- target
    x[[paste0("forward_abs_return_h", h)]] <- abs(target)
    x[[paste0("target_exit_date_h", h)]] <- exit_date
    x[[paste0("nonoverlap_h", h)]] <- analysis_rows & !is.na(x$analysis_index) & ((x$analysis_index - 1L) %% h == 0L)
  }
  x
}

hreg21_direction_metrics <- function(score, target) {
  keep <- is.finite(score) & is.finite(target) & target != 0
  score <- score[keep]; target <- target[keep]
  if (!length(score)) return(c(accuracy = NA_real_, up_recall = NA_real_, down_recall = NA_real_, balanced_accuracy = NA_real_, predicted_up_fraction = NA_real_))
  predicted_up <- score >= 0
  actual_up <- target > 0
  up_recall <- if (any(actual_up)) mean(predicted_up[actual_up]) else NA_real_
  down_recall <- if (any(!actual_up)) mean(!predicted_up[!actual_up]) else NA_real_
  c(
    accuracy = mean(predicted_up == actual_up),
    up_recall = up_recall,
    down_recall = down_recall,
    balanced_accuracy = mean(c(up_recall, down_recall), na.rm = TRUE),
    predicted_up_fraction = mean(predicted_up)
  )
}

hreg21_quintile_spread <- function(percentile, target) {
  low <- is.finite(percentile) & percentile <= 0.20 & is.finite(target)
  high <- is.finite(percentile) & percentile > 0.80 & is.finite(target)
  if (!any(low) || !any(high)) return(c(q1_n = sum(low), q5_n = sum(high), q1_median = NA_real_, q5_median = NA_real_, q5_q1_spread = NA_real_))
  q1 <- stats::median(target[low]); q5 <- stats::median(target[high])
  c(q1_n = sum(low), q5_n = sum(high), q1_median = q1, q5_median = q5, q5_q1_spread = q5 - q1)
}

hreg21_asset_summary <- function(ledger, contract = hreg21_contract()) {
  model_columns <- c(TREND_SMA20_60 = "trend_score", PRICE_SMA60 = "price_sma60_score", RETURN63 = "return63_score")
  assets <- unique(ledger$symbol)
  rows <- list(); k <- 0L
  for (symbol in assets) {
    x <- ledger[ledger$symbol == symbol & ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
    for (h in contract$horizons) {
      keep_h <- x[[paste0("nonoverlap_h", h)]] & is.finite(x[[paste0("forward_return_h", h)]])
      target <- x[[paste0("forward_return_h", h)]][keep_h]
      for (model in names(model_columns)) {
        score <- x[[model_columns[[model]]]][keep_h]
        valid <- is.finite(score) & is.finite(target)
        direction <- hreg21_direction_metrics(score, target)
        quintiles <- if (model == "TREND_SMA20_60") hreg21_quintile_spread(x$trend_percentile[keep_h], target) else rep(NA_real_, 5L)
        k <- k + 1L
        rows[[k]] <- data.frame(
          symbol = symbol, horizon = h, model = model, observations = sum(valid),
          spearman = if (sum(valid) >= 5L) suppressWarnings(stats::cor(score[valid], target[valid], method = "spearman")) else NA_real_,
          accuracy = direction[["accuracy"]], up_recall = direction[["up_recall"]], down_recall = direction[["down_recall"]],
          balanced_accuracy = direction[["balanced_accuracy"]], predicted_up_fraction = direction[["predicted_up_fraction"]],
          q1_n = quintiles[[1L]], q5_n = quintiles[[2L]], q1_median = quintiles[[3L]], q5_median = quintiles[[4L]], q5_q1_spread = quintiles[[5L]],
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

hreg21_calendar_summary <- function(ledger, contract = hreg21_contract()) {
  rows <- list(); k <- 0L
  for (symbol in unique(ledger$symbol)) {
    for (year in 2018:2023) {
      x <- ledger[ledger$symbol == symbol & as.integer(format(ledger$session_date, "%Y")) == year, , drop = FALSE]
      for (h in contract$horizons) {
        target <- x[[paste0("forward_return_h", h)]]
        keep <- x[[paste0("nonoverlap_h", h)]] & is.finite(x$trend_score) & is.finite(target)
        k <- k + 1L
        rows[[k]] <- data.frame(symbol = symbol, year = year, horizon = h, observations = sum(keep),
                                spearman = if (sum(keep) >= 3L) suppressWarnings(stats::cor(x$trend_score[keep], target[keep], method = "spearman")) else NA_real_,
                                stringsAsFactors = FALSE)
      }
    }
  }
  do.call(rbind, rows)
}

hreg21_rotate <- function(x, shift) {
  n <- length(x)
  if (!n) return(x)
  shift <- as.integer(shift %% n)
  if (shift == 0L) return(x)
  c(tail(x, shift), head(x, n - shift))
}

hreg21_shift_scores <- function(ledger, simulation_id) {
  out <- ledger$trend_score
  groups <- split(seq_len(nrow(ledger)), interaction(ledger$symbol, format(ledger$session_date, "%Y"), drop = TRUE))
  g <- 0L
  for (idx in groups) {
    g <- g + 1L
    if (length(idx) < 3L) next
    shift <- 1L + ((as.integer(simulation_id) * 37L + g * 17L) %% (length(idx) - 1L))
    out[idx] <- hreg21_rotate(ledger$trend_score[idx], shift)
  }
  out
}

hreg21_placebo_summary <- function(ledger, contract = hreg21_contract()) {
  primary_horizons <- c(20L, 63L)
  rows <- list(); k <- 0L
  for (simulation_id in seq_len(contract$simulations)) {
    shifted <- hreg21_shift_scores(ledger, simulation_id)
    for (h in primary_horizons) {
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

hreg21_joint_state_summary <- function(ledger, contract = hreg21_contract()) {
  if (!all(c("regime_state", "atr_percentile") %in% names(ledger))) hreg21_stop("Accepted ATR state columns are missing.")
  states <- c("LOW", "MEDIUM", "HIGH")
  signs <- c("DOWN", "UP")
  rows <- list(); k <- 0L
  for (h in c(20L, 63L)) {
    target <- ledger[[paste0("forward_return_h", h)]]
    abs_target <- abs(target)
    for (state in states) {
      for (sign in signs) {
        keep <- ledger[[paste0("nonoverlap_h", h)]] & ledger$regime_state == state & ledger$trend_sign == sign & is.finite(target)
        k <- k + 1L
        rows[[k]] <- data.frame(horizon = h, regime_state = state, trend_sign = sign, observations = sum(keep),
                                median_return = if (any(keep)) stats::median(target[keep]) else NA_real_,
                                up_rate = if (any(keep)) mean(target[keep] > 0) else NA_real_,
                                median_abs_return = if (any(keep)) stats::median(abs_target[keep]) else NA_real_, stringsAsFactors = FALSE)
      }
    }
  }
  do.call(rbind, rows)
}

hreg21_joint_within_state <- function(ledger, contract = hreg21_contract()) {
  rows <- list(); k <- 0L
  for (h in c(20L, 63L)) {
    target <- ledger[[paste0("forward_return_h", h)]]
    for (state in c("LOW", "MEDIUM", "HIGH")) {
      asset_values <- vapply(split(seq_len(nrow(ledger)), ledger$symbol), function(idx) {
        keep <- ledger[[paste0("nonoverlap_h", h)]][idx] & ledger$regime_state[idx] == state & is.finite(ledger$trend_score[idx]) & is.finite(target[idx])
        if (sum(keep) < 5L) return(NA_real_)
        suppressWarnings(stats::cor(ledger$trend_score[idx][keep], target[idx][keep], method = "spearman"))
      }, numeric(1))
      k <- k + 1L
      rows[[k]] <- data.frame(horizon = h, regime_state = state, assets = sum(is.finite(asset_values)),
                              median_spearman = stats::median(asset_values, na.rm = TRUE), positive_asset_fraction = mean(asset_values > 0, na.rm = TRUE), stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}
