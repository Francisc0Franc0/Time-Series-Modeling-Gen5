g5_gen54_ce_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message) else stop(message, call. = FALSE)
}

g5_gen54_ce_live_symbols <- function() c("AMD", "NVDA", "TSLA", "MSTR", "AVGO")

g5_gen54_ce_common_features <- function() {
  c(
    "target_leadership_20",
    "opportunity_breadth_20",
    "spy_trend_20",
    "spy_volatility_20",
    "participation_dollar_volume_5_60"
  )
}

g5_gen54_ce_directional_features <- function() {
  c(
    "target_leadership_20",
    "opportunity_breadth_20",
    "spy_trend_20",
    "participation_dollar_volume_5_60",
    "semiconductor_confirmation_20"
  )
}

g5_gen54_ce_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 1L) return(x)
  if (length(x) <= n) return(rep(NA, length(x)))
  c(rep(NA, n), x[seq_len(length(x) - n)])
}

g5_gen54_ce_lead <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 1L) return(x)
  if (length(x) <= n) return(rep(NA, length(x)))
  c(x[(n + 1L):length(x)], rep(NA, n))
}

g5_gen54_ce_rolling_sd <- function(x, window) {
  window <- as.integer(window)
  out <- rep(NA_real_, length(x))
  if (length(x) < window || window < 2L) return(out)
  for (i in seq.int(window, length(x))) {
    values <- x[seq.int(i - window + 1L, i)]
    if (all(is.finite(values))) out[[i]] <- stats::sd(values)
  }
  out
}

g5_gen54_ce_rolling_median_ratio <- function(x, recent = 5L, baseline = 60L) {
  recent <- as.integer(recent)
  baseline <- as.integer(baseline)
  out <- rep(NA_real_, length(x))
  required <- recent + baseline
  if (length(x) < required) return(out)
  for (i in seq.int(required, length(x))) {
    recent_values <- x[seq.int(i - recent + 1L, i)]
    baseline_values <- x[seq.int(i - recent - baseline + 1L, i - recent)]
    if (all(is.finite(recent_values)) && all(is.finite(baseline_values))) {
      recent_median <- stats::median(recent_values)
      baseline_median <- stats::median(baseline_values)
      if (is.finite(recent_median) && is.finite(baseline_median) &&
          recent_median > 0 && baseline_median > 0) {
        out[[i]] <- log(recent_median / baseline_median)
      }
    }
  }
  out
}

g5_gen54_ce_quarter_start <- function(year, quarter) {
  as.Date(sprintf("%04d-%02d-01", year, c(1L, 4L, 7L, 10L)[[quarter]]))
}

g5_gen54_ce_quarter_end <- function(year, quarter) {
  if (quarter == 4L) {
    as.Date(sprintf("%04d-01-01", year + 1L)) - 1L
  } else {
    g5_gen54_ce_quarter_start(year, quarter + 1L) - 1L
  }
}

g5_gen54_ce_build_folds <- function(years = 2020:2024, train_quarters = 8L) {
  train_quarters <- as.integer(train_quarters)
  if (train_quarters != 8L) {
    g5_gen54_ce_stop("The frozen minimal POC requires exactly eight TRAIN quarters.")
  }
  rows <- list()
  idx <- 1L
  for (year in as.integer(years)) {
    for (quarter in seq_len(4L)) {
      oos_start <- g5_gen54_ce_quarter_start(year, quarter)
      train_start <- g5_gen54_ce_quarter_start(year - 2L, quarter)
      rows[[idx]] <- data.frame(
        fold_no = idx,
        fold_id = paste0(year, "Q", quarter),
        window_id = paste0(year, "Y"),
        train_start_date = train_start,
        train_end_date = oos_start - 1L,
        oos_start_date = oos_start,
        oos_end_date = g5_gen54_ce_quarter_end(year, quarter),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_gen54_ce_validate_bars <- function(bars, required_symbols) {
  required_columns <- c("symbol", "session_date", "open", "close", "volume")
  missing_columns <- setdiff(required_columns, names(bars))
  if (length(missing_columns)) {
    g5_gen54_ce_stop(paste0("Conditional-exposure bars are missing columns: ", paste(missing_columns, collapse = ", ")))
  }
  bars$symbol <- toupper(trimws(as.character(bars$symbol)))
  bars$session_date <- as.Date(bars$session_date)
  bars <- bars[order(bars$symbol, bars$session_date), , drop = FALSE]
  duplicate_key <- duplicated(bars[, c("symbol", "session_date")])
  if (any(duplicate_key)) g5_gen54_ce_stop("Conditional-exposure bars contain duplicate symbol/session rows.")
  missing_symbols <- setdiff(required_symbols, unique(bars$symbol))
  if (length(missing_symbols)) {
    g5_gen54_ce_stop(paste0("Conditional-exposure bars are missing symbols: ", paste(missing_symbols, collapse = ", ")))
  }
  bars
}

g5_gen54_ce_wide_bars <- function(bars, symbols) {
  pieces <- lapply(symbols, function(symbol) {
    part <- bars[bars$symbol == symbol, c("session_date", "open", "close", "volume"), drop = FALSE]
    names(part)[-1L] <- paste0(c("open", "close", "volume"), "__", symbol)
    part
  })
  wide <- Reduce(function(x, y) merge(x, y, by = "session_date", all = TRUE, sort = TRUE), pieces)
  wide[order(wide$session_date), , drop = FALSE]
}

g5_gen54_ce_build_feature_outcomes <- function(
    bars,
    live_symbols = g5_gen54_ce_live_symbols(),
    semiconductor_symbols = c("AMD", "NVDA", "AVGO"),
    annualization = 252) {
  live_symbols <- toupper(as.character(live_symbols))
  required_symbols <- unique(c(live_symbols, "SPY", "SMH"))
  bars <- g5_gen54_ce_validate_bars(bars, required_symbols)
  wide <- g5_gen54_ce_wide_bars(bars, required_symbols)
  close_col <- function(symbol) wide[[paste0("close__", symbol)]]
  open_col <- function(symbol) wide[[paste0("open__", symbol)]]
  volume_col <- function(symbol) wide[[paste0("volume__", symbol)]]

  lr20 <- lapply(required_symbols, function(symbol) log(close_col(symbol) / g5_gen54_ce_lag(close_col(symbol), 20L)))
  names(lr20) <- required_symbols
  spy_daily_log_return <- log(close_col("SPY") / g5_gen54_ce_lag(close_col("SPY"), 1L))
  spy_volatility <- sqrt(as.numeric(annualization)) * g5_gen54_ce_rolling_sd(spy_daily_log_return, 20L)
  next_open <- lapply(live_symbols, function(symbol) g5_gen54_ce_lead(open_col(symbol), 1L))
  following_open <- lapply(live_symbols, function(symbol) g5_gen54_ce_lead(open_col(symbol), 2L))
  names(next_open) <- names(following_open) <- live_symbols
  target_returns <- lapply(live_symbols, function(symbol) following_open[[symbol]] / next_open[[symbol]] - 1)
  names(target_returns) <- live_symbols
  basket_matrix <- do.call(cbind, target_returns)
  basket_return <- rowMeans(basket_matrix, na.rm = FALSE)

  rows <- lapply(live_symbols, function(target) {
    peers <- setdiff(live_symbols, target)
    peer_lr <- do.call(cbind, lr20[peers])
    leadership <- lr20[[target]] - rowMeans(peer_lr, na.rm = FALSE)
    breadth_matrix <- sweep(peer_lr, 1L, lr20[["SPY"]], FUN = ">")
    breadth <- rowMeans(breadth_matrix, na.rm = FALSE)
    dollar_volume <- close_col(target) * volume_col(target)
    participation <- g5_gen54_ce_rolling_median_ratio(dollar_volume, recent = 5L, baseline = 60L)
    sector_confirmation <- if (target %in% semiconductor_symbols) lr20[["SMH"]] - lr20[["SPY"]] else rep(NA_real_, nrow(wide))
    result <- data.frame(
      symbol = target,
      feature_date = as.Date(wide$session_date),
      execution_date = as.Date(g5_gen54_ce_lead(wide$session_date, 1L)),
      label_end_date = as.Date(g5_gen54_ce_lead(wide$session_date, 2L)),
      target_leadership_20 = leadership,
      opportunity_breadth_20 = breadth,
      spy_trend_20 = lr20[["SPY"]],
      spy_volatility_20 = spy_volatility,
      participation_dollar_volume_5_60 = participation,
      semiconductor_confirmation_20 = sector_confirmation,
      target_open_to_open_return = target_returns[[target]],
      basket_open_to_open_return = basket_return,
      stringsAsFactors = FALSE
    )
    result$target_favorable <- result$target_open_to_open_return > 0
    result$basket_favorable <- result$basket_open_to_open_return > 0
    common <- g5_gen54_ce_common_features()
    result$complete_common <- stats::complete.cases(result[, common, drop = FALSE]) &
      is.finite(result$target_open_to_open_return) & is.finite(result$basket_open_to_open_return)
    result$complete_semiconductor_challenger <- result$complete_common &
      is.finite(result$semiconductor_confirmation_20)
    result
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$feature_date, match(out$symbol, live_symbols)), , drop = FALSE]
}

g5_gen54_ce_assign_fold_rows <- function(feature_outcomes, folds) {
  rows <- list()
  idx <- 1L
  feature_date <- as.Date(feature_outcomes$feature_date)
  label_end_date <- as.Date(feature_outcomes$label_end_date)
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    for (split in c("TRAIN", "OOS")) {
      if (split == "TRAIN") {
        keep <- feature_date >= fold$train_start_date & feature_date <= fold$train_end_date
        inside <- label_end_date <= fold$train_end_date
      } else {
        keep <- feature_date >= fold$oos_start_date & feature_date <= fold$oos_end_date
        inside <- label_end_date <= fold$oos_end_date
      }
      if (!any(keep)) next
      part <- feature_outcomes[keep, , drop = FALSE]
      part$fold_no <- fold$fold_no
      part$fold_id <- fold$fold_id
      part$window_id <- fold$window_id
      part$split <- split
      part$train_start_date <- fold$train_start_date
      part$train_end_date <- fold$train_end_date
      part$oos_start_date <- fold$oos_start_date
      part$oos_end_date <- fold$oos_end_date
      part$label_inside_split <- inside[keep]
      rows[[idx]] <- part
      idx <- idx + 1L
    }
  }
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_gen54_ce_train_percentile <- function(train_values, oos_values) {
  train_values <- sort(train_values[is.finite(train_values)])
  out <- rep(NA_real_, length(oos_values))
  if (!length(train_values)) return(out)
  keep <- is.finite(oos_values)
  out[keep] <- vapply(oos_values[keep], function(value) {
    mean(train_values <= value)
  }, numeric(1L))
  out
}

g5_gen54_ce_build_binned_oos <- function(fold_rows) {
  features <- c(g5_gen54_ce_common_features(), "semiconductor_confirmation_20")
  rows <- list()
  idx <- 1L
  for (fold_id in unique(fold_rows$fold_id)) {
    train <- fold_rows[fold_rows$fold_id == fold_id & fold_rows$split == "TRAIN" & fold_rows$label_inside_split, , drop = FALSE]
    oos <- fold_rows[fold_rows$fold_id == fold_id & fold_rows$split == "OOS" & fold_rows$label_inside_split, , drop = FALSE]
    if (!nrow(train) || !nrow(oos)) next
    for (feature in features) {
      if (feature == "semiconductor_confirmation_20") {
        train_keep <- train$complete_semiconductor_challenger
        oos_keep <- oos$complete_semiconductor_challenger
        lane <- "semiconductor_challenger"
      } else {
        train_keep <- train$complete_common
        oos_keep <- oos$complete_common
        lane <- "common_panel"
      }
      train_values <- as.numeric(train[[feature]][train_keep])
      part <- oos[oos_keep, , drop = FALSE]
      if (!nrow(part) || !any(is.finite(train_values))) next
      percentile <- g5_gen54_ce_train_percentile(train_values, as.numeric(part[[feature]]))
      bin <- pmax(1L, pmin(5L, ceiling(5 * pmax(percentile, .Machine$double.eps))))
      rows[[idx]] <- data.frame(
        fold_no = part$fold_no,
        fold_id = part$fold_id,
        window_id = part$window_id,
        lane = lane,
        feature_name = feature,
        symbol = part$symbol,
        feature_date = as.Date(part$feature_date),
        feature_value = as.numeric(part[[feature]]),
        train_percentile = percentile,
        train_bin = bin,
        target_open_to_open_return = part$target_open_to_open_return,
        basket_open_to_open_return = part$basket_open_to_open_return,
        target_favorable = part$target_favorable,
        basket_favorable = part$basket_favorable,
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_gen54_ce_bin_summary <- function(binned_oos) {
  if (!nrow(binned_oos)) return(data.frame())
  keys <- interaction(binned_oos$fold_id, binned_oos$lane, binned_oos$feature_name, binned_oos$train_bin, drop = TRUE)
  pieces <- split(binned_oos, keys)
  rows <- lapply(pieces, function(part) data.frame(
    fold_no = part$fold_no[[1L]],
    fold_id = part$fold_id[[1L]],
    window_id = part$window_id[[1L]],
    lane = part$lane[[1L]],
    feature_name = part$feature_name[[1L]],
    train_bin = part$train_bin[[1L]],
    row_count = nrow(part),
    mean_target_return = mean(part$target_open_to_open_return, na.rm = TRUE),
    target_favorable_rate = mean(part$target_favorable, na.rm = TRUE),
    mean_basket_return = mean(part$basket_open_to_open_return, na.rm = TRUE),
    basket_favorable_rate = mean(part$basket_favorable, na.rm = TRUE),
    stringsAsFactors = FALSE
  ))
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$fold_no, out$feature_name, out$train_bin), , drop = FALSE]
}

g5_gen54_ce_fold_separation <- function(bin_summary) {
  if (!nrow(bin_summary)) return(data.frame())
  keys <- interaction(bin_summary$fold_id, bin_summary$lane, bin_summary$feature_name, drop = TRUE)
  rows <- lapply(split(bin_summary, keys), function(part) {
    part <- part[order(part$train_bin), , drop = FALSE]
    low <- part[1L, , drop = FALSE]
    high <- part[nrow(part), , drop = FALSE]
    rank_correlation <- if (nrow(part) >= 3L) {
      suppressWarnings(stats::cor(part$train_bin, part$mean_target_return, method = "spearman"))
    } else NA_real_
    data.frame(
      fold_no = part$fold_no[[1L]],
      fold_id = part$fold_id[[1L]],
      window_id = part$window_id[[1L]],
      lane = part$lane[[1L]],
      feature_name = part$feature_name[[1L]],
      low_bin = low$train_bin,
      high_bin = high$train_bin,
      target_return_separation = high$mean_target_return - low$mean_target_return,
      target_favorable_rate_separation = high$target_favorable_rate - low$target_favorable_rate,
      basket_return_separation = high$mean_basket_return - low$mean_basket_return,
      rank_correlation = rank_correlation,
      ordering_positive = is.finite(rank_correlation) && rank_correlation > 0,
      separation_positive = high$mean_target_return > low$mean_target_return,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$fold_no, out$feature_name), , drop = FALSE]
}

g5_gen54_ce_proxy_cost_summary <- function(binned_oos, cost_bps = c(0, 10, 20), active_percentile = 0.60) {
  directional <- g5_gen54_ce_directional_features()
  x <- binned_oos[binned_oos$feature_name %in% directional, , drop = FALSE]
  if (!nrow(x)) return(data.frame())
  group_key <- interaction(x$fold_id, x$lane, x$feature_name, drop = TRUE)
  rows <- list()
  idx <- 1L
  for (part in split(x, group_key)) {
    part <- part[order(part$symbol, part$feature_date), , drop = FALSE]
    part$active <- as.numeric(part$train_percentile >= active_percentile)
    part$turnover <- 0
    for (symbol in unique(part$symbol)) {
      where <- which(part$symbol == symbol)
      state <- part$active[where]
      part$turnover[where] <- abs(state - c(0, state[-length(state)]))
    }
    date_parts <- split(part, part$feature_date)
    daily <- do.call(rbind, lapply(date_parts, function(day) data.frame(
      feature_date = day$feature_date[[1L]],
      gross_return = mean(day$active * day$target_open_to_open_return, na.rm = TRUE),
      exposure = mean(day$active, na.rm = TRUE),
      exposure_matched_basket_return = mean(day$active, na.rm = TRUE) * day$basket_open_to_open_return[[1L]],
      turnover = mean(day$turnover, na.rm = TRUE),
      stringsAsFactors = FALSE
    )))
    terminal_turnover <- mean(part$active[!duplicated(part$symbol, fromLast = TRUE)], na.rm = TRUE)
    for (bps in cost_bps) {
      rate <- as.numeric(bps) / 10000
      net_daily <- daily$gross_return - rate * daily$turnover
      if (nrow(daily)) net_daily[[nrow(daily)]] <- net_daily[[nrow(daily)]] - rate * terminal_turnover
      cumulative_net_return <- prod(1 + net_daily, na.rm = TRUE) - 1
      cumulative_exposure_matched_return <- prod(1 + daily$exposure_matched_basket_return, na.rm = TRUE) - 1
      rows[[idx]] <- data.frame(
        fold_no = part$fold_no[[1L]],
        fold_id = part$fold_id[[1L]],
        window_id = part$window_id[[1L]],
        lane = part$lane[[1L]],
        feature_name = part$feature_name[[1L]],
        cost_bps_one_way = as.numeric(bps),
        active_percentile_threshold = active_percentile,
        session_count = nrow(daily),
        mean_exposure = mean(daily$exposure, na.rm = TRUE),
        one_way_turnover = sum(daily$turnover, na.rm = TRUE) + terminal_turnover,
        cumulative_net_return = cumulative_net_return,
        cumulative_exposure_matched_return = cumulative_exposure_matched_return,
        cumulative_selection_excess = cumulative_net_return - cumulative_exposure_matched_return,
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$fold_no, out$feature_name, out$cost_bps_one_way), , drop = FALSE]
}

g5_gen54_ce_symbol_year_concentration <- function(binned_oos) {
  directional <- g5_gen54_ce_directional_features()
  x <- binned_oos[binned_oos$feature_name %in% directional, , drop = FALSE]
  if (!nrow(x)) return(data.frame())
  x$year <- as.integer(format(as.Date(x$feature_date), "%Y"))
  keys <- interaction(x$lane, x$feature_name, x$symbol, x$year, drop = TRUE)
  rows <- lapply(split(x, keys), function(part) {
    high <- part$target_open_to_open_return[part$train_percentile >= 0.8]
    low <- part$target_open_to_open_return[part$train_percentile <= 0.2]
    data.frame(
      lane = part$lane[[1L]],
      feature_name = part$feature_name[[1L]],
      symbol = part$symbol[[1L]],
      year = part$year[[1L]],
      high_count = sum(is.finite(high)),
      low_count = sum(is.finite(low)),
      target_return_separation = mean(high, na.rm = TRUE) - mean(low, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[is.finite(out$target_return_separation), , drop = FALSE]
  if (!nrow(out)) return(out)
  contribution_key <- interaction(out$lane, out$feature_name, drop = TRUE)
  out$absolute_separation_contribution <- abs(out$target_return_separation) * pmin(out$high_count, out$low_count)
  out$absolute_contribution_share <- ave(out$absolute_separation_contribution, contribution_key, FUN = function(value) {
    total <- sum(value, na.rm = TRUE)
    if (total > 0) value / total else rep(NA_real_, length(value))
  })
  rownames(out) <- NULL
  out
}

g5_gen54_ce_market_state_summary <- function(fold_rows) {
  rows <- list()
  idx <- 1L
  for (fold_id in unique(fold_rows$fold_id)) {
    train <- fold_rows[
      fold_rows$fold_id == fold_id & fold_rows$split == "TRAIN" &
        fold_rows$label_inside_split & fold_rows$complete_common,
      , drop = FALSE
    ]
    oos <- fold_rows[
      fold_rows$fold_id == fold_id & fold_rows$split == "OOS" &
        fold_rows$label_inside_split & fold_rows$complete_common,
      , drop = FALSE
    ]
    if (!nrow(train) || !nrow(oos)) next
    volatility_threshold <- stats::median(train$spy_volatility_20, na.rm = TRUE)
    oos$market_state <- paste0(
      ifelse(oos$spy_trend_20 > 0, "trend_positive", "trend_nonpositive"),
      "__",
      ifelse(oos$spy_volatility_20 <= volatility_threshold, "vol_low", "vol_high")
    )
    for (state in unique(oos$market_state)) {
      part <- oos[oos$market_state == state, , drop = FALSE]
      rows[[idx]] <- data.frame(
        fold_no = part$fold_no[[1L]],
        fold_id = part$fold_id[[1L]],
        window_id = part$window_id[[1L]],
        market_state = state,
        train_volatility_median = volatility_threshold,
        row_count = nrow(part),
        mean_target_return = mean(part$target_open_to_open_return, na.rm = TRUE),
        target_favorable_rate = mean(part$target_favorable, na.rm = TRUE),
        mean_basket_return = mean(part$basket_open_to_open_return, na.rm = TRUE),
        basket_favorable_rate = mean(part$basket_favorable, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$fold_no, out$market_state), , drop = FALSE]
}

g5_gen54_ce_promotion_summary <- function(fold_separation, proxy_cost, concentration, required_positive_folds = 12L) {
  directional <- g5_gen54_ce_directional_features()
  rows <- lapply(directional, function(feature) {
    sep <- fold_separation[fold_separation$feature_name == feature, , drop = FALSE]
    cost10 <- proxy_cost[proxy_cost$feature_name == feature & proxy_cost$cost_bps_one_way == 10, , drop = FALSE]
    cost20 <- proxy_cost[proxy_cost$feature_name == feature & proxy_cost$cost_bps_one_way == 20, , drop = FALSE]
    conc <- concentration[concentration$feature_name == feature, , drop = FALSE]
    positive_folds <- sum(sep$separation_positive, na.rm = TRUE)
    ordering_folds <- sum(sep$ordering_positive, na.rm = TRUE)
    max_share <- if (nrow(conc)) max(conc$absolute_contribution_share, na.rm = TRUE) else NA_real_
    base_cost_excess <- if (nrow(cost10)) sum(cost10$cumulative_selection_excess, na.rm = TRUE) else NA_real_
    stress_cost_excess <- if (nrow(cost20)) sum(cost20$cumulative_selection_excess, na.rm = TRUE) else NA_real_
    checks <- c(
      positive_folds >= required_positive_folds,
      ordering_folds >= required_positive_folds,
      is.finite(max_share) && max_share <= 0.50,
      is.finite(base_cost_excess) && base_cost_excess > 0,
      is.finite(stress_cost_excess) && stress_cost_excess >= 0
    )
    data.frame(
      lane = if (feature == "semiconductor_confirmation_20") "semiconductor_challenger" else "common_panel",
      feature_name = feature,
      assessed_fold_count = nrow(sep),
      positive_separation_folds = positive_folds,
      positive_ordering_folds = ordering_folds,
      required_positive_folds = required_positive_folds,
      max_symbol_year_absolute_contribution_share = max_share,
      base_10bps_selection_excess_sum = base_cost_excess,
      stress_20bps_selection_excess_sum = stress_cost_excess,
      promotion_status = if (all(checks)) "PASS" else "STOP",
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_gen54_ce_leakage_audit <- function(fold_rows, folds) {
  usable <- fold_rows[fold_rows$label_inside_split & fold_rows$complete_common, , drop = FALSE]
  train <- usable[usable$split == "TRAIN", , drop = FALSE]
  oos <- usable[usable$split == "OOS", , drop = FALSE]
  expected_folds <- paste0(rep(2020:2024, each = 4L), "Q", rep(1:4, times = 5L))
  data.frame(
    check_id = c(
      "frozen_20_quarter_fold_ladder",
      "feature_precedes_execution",
      "execution_precedes_label_end",
      "train_labels_end_inside_train",
      "oos_labels_end_inside_oos",
      "strict_common_complete_cases",
      "no_sector_fill_for_non_semiconductors"
    ),
    status = c(
      if (identical(as.character(folds$fold_id), expected_folds)) "PASS" else "FAIL",
      if (nrow(usable) && all(as.Date(usable$feature_date) < as.Date(usable$execution_date))) "PASS" else "FAIL",
      if (nrow(usable) && all(as.Date(usable$execution_date) < as.Date(usable$label_end_date))) "PASS" else "FAIL",
      if (!nrow(train) || all(as.Date(train$label_end_date) <= as.Date(train$train_end_date))) "PASS" else "FAIL",
      if (!nrow(oos) || all(as.Date(oos$label_end_date) <= as.Date(oos$oos_end_date))) "PASS" else "FAIL",
      if (nrow(usable) && all(stats::complete.cases(usable[, g5_gen54_ce_common_features(), drop = FALSE]))) "PASS" else "FAIL",
      if (all(!is.finite(fold_rows$semiconductor_confirmation_20[fold_rows$symbol %in% c("TSLA", "MSTR")]))) "PASS" else "FAIL"
    ),
    detail = c(
      "Eight-quarter TRAIN and one-quarter OOS authorities cover 2020Q1 through 2024Q4.",
      "All features end at close t before next-open execution.",
      "The h1 outcome ends at the following open.",
      "TRAIN labels that cross the authority boundary are ineligible.",
      "OOS labels that cross the quarter boundary are ineligible.",
      "Common diagnostics use aligned complete rows only.",
      "TSLA and MSTR retain structural missingness for the semiconductor challenger."
    ),
    stringsAsFactors = FALSE
  )
}

g5_gen54_lp_confirmation_states <- function(
    fold_rows,
    confirmation_fold_ids = c("2025Q1", "2025Q2", "2025Q3", "2025Q4", "2026Q1", "2026Q2"),
    high_percentile = 0.60) {
  rows <- list()
  thresholds <- list()
  idx <- 1L
  threshold_idx <- 1L
  for (fold_id in confirmation_fold_ids) {
    train <- fold_rows[
      fold_rows$fold_id == fold_id & fold_rows$split == "TRAIN" &
        fold_rows$label_inside_split & fold_rows$complete_common,
      , drop = FALSE
    ]
    oos <- fold_rows[
      fold_rows$fold_id == fold_id & fold_rows$split == "OOS" &
        fold_rows$label_inside_split & fold_rows$complete_common,
      , drop = FALSE
    ]
    if (!nrow(train) || !nrow(oos)) next
    leadership_threshold <- as.numeric(stats::quantile(
      train$target_leadership_20, probs = high_percentile, na.rm = TRUE, names = FALSE, type = 7
    ))
    participation_threshold <- as.numeric(stats::quantile(
      train$participation_dollar_volume_5_60, probs = high_percentile, na.rm = TRUE, names = FALSE, type = 7
    ))
    oos$leadership_high <- oos$target_leadership_20 >= leadership_threshold
    oos$participation_high <- oos$participation_dollar_volume_5_60 >= participation_threshold
    oos$confirmation_state <- ifelse(
      oos$leadership_high & oos$participation_high, "A_high_leadership__high_participation",
      ifelse(
        oos$leadership_high & !oos$participation_high, "B_high_leadership__low_participation",
        ifelse(
          !oos$leadership_high & oos$participation_high, "C_low_leadership__high_participation",
          "D_low_leadership__low_participation"
        )
      )
    )
    oos$leadership_train_p60 <- leadership_threshold
    oos$participation_train_p60 <- participation_threshold
    oos$confirmation_high_percentile <- high_percentile
    rows[[idx]] <- oos
    idx <- idx + 1L
    thresholds[[threshold_idx]] <- data.frame(
      fold_no = oos$fold_no[[1L]],
      fold_id = fold_id,
      window_id = oos$window_id[[1L]],
      train_start_date = oos$train_start_date[[1L]],
      train_end_date = oos$train_end_date[[1L]],
      leadership_train_p60 = leadership_threshold,
      participation_train_p60 = participation_threshold,
      train_complete_row_count = nrow(train),
      oos_complete_row_count = nrow(oos),
      stringsAsFactors = FALSE
    )
    threshold_idx <- threshold_idx + 1L
  }
  if (!length(rows)) return(list(states = data.frame(), thresholds = data.frame()))
  states <- do.call(rbind, rows)
  threshold_table <- do.call(rbind, thresholds)
  rownames(states) <- rownames(threshold_table) <- NULL
  list(
    states = states[order(states$fold_no, states$feature_date, states$symbol), , drop = FALSE],
    thresholds = threshold_table[order(threshold_table$fold_no), , drop = FALSE]
  )
}

g5_gen54_lp_state_summary <- function(states) {
  if (!nrow(states)) return(data.frame())
  summarize <- function(part, scope) data.frame(
    scope = scope,
    fold_no = if (scope == "fold") part$fold_no[[1L]] else NA_integer_,
    fold_id = if (scope == "fold") part$fold_id[[1L]] else "POOLED",
    window_id = if (scope == "fold") part$window_id[[1L]] else "2025Q1_2026Q2",
    confirmation_state = part$confirmation_state[[1L]],
    row_count = nrow(part),
    mean_target_return = mean(part$target_open_to_open_return, na.rm = TRUE),
    target_favorable_rate = mean(part$target_favorable, na.rm = TRUE),
    mean_basket_return = mean(part$basket_open_to_open_return, na.rm = TRUE),
    basket_favorable_rate = mean(part$basket_favorable, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  fold_key <- interaction(states$fold_id, states$confirmation_state, drop = TRUE)
  fold_rows <- lapply(split(states, fold_key), summarize, scope = "fold")
  pooled_rows <- lapply(split(states, states$confirmation_state), summarize, scope = "pooled")
  out <- do.call(rbind, c(fold_rows, pooled_rows))
  rownames(out) <- NULL
  out[order(out$scope, out$fold_no, out$confirmation_state), , drop = FALSE]
}

g5_gen54_lp_fold_contrasts <- function(state_summary) {
  fold_summary <- state_summary[state_summary$scope == "fold", , drop = FALSE]
  rows <- lapply(unique(fold_summary$fold_id), function(fold_id) {
    part <- fold_summary[fold_summary$fold_id == fold_id, , drop = FALSE]
    value <- function(state, column) {
      x <- part[part$confirmation_state == state, column, drop = TRUE]
      if (length(x)) as.numeric(x[[1L]]) else NA_real_
    }
    count <- function(state) {
      x <- part$row_count[part$confirmation_state == state]
      if (length(x)) as.integer(x[[1L]]) else 0L
    }
    a <- "A_high_leadership__high_participation"
    b <- "B_high_leadership__low_participation"
    c <- "C_low_leadership__high_participation"
    a_mean <- value(a, "mean_target_return")
    b_mean <- value(b, "mean_target_return")
    c_mean <- value(c, "mean_target_return")
    data.frame(
      fold_no = part$fold_no[[1L]],
      fold_id = fold_id,
      window_id = part$window_id[[1L]],
      state_a_count = count(a),
      state_b_count = count(b),
      state_c_count = count(c),
      state_a_minus_b_return = a_mean - b_mean,
      state_a_minus_c_return = a_mean - c_mean,
      correct_state_a_ordering = is.finite(a_mean) && is.finite(b_mean) && is.finite(c_mean) &&
        a_mean > b_mean && a_mean > c_mean,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$fold_no), , drop = FALSE]
}

g5_gen54_lp_cost_summary <- function(states, cost_bps = c(0, 10, 20)) {
  if (!nrow(states)) return(data.frame())
  rows <- list()
  idx <- 1L
  for (fold_id in unique(states$fold_id)) {
    part <- states[states$fold_id == fold_id, , drop = FALSE]
    part <- part[order(part$symbol, part$feature_date), , drop = FALSE]
    part$active <- as.numeric(part$confirmation_state == "A_high_leadership__high_participation")
    part$turnover <- 0
    for (symbol in unique(part$symbol)) {
      where <- which(part$symbol == symbol)
      position <- part$active[where]
      part$turnover[where] <- abs(position - c(0, position[-length(position)]))
    }
    daily <- do.call(rbind, lapply(split(part, part$feature_date), function(day) data.frame(
      feature_date = day$feature_date[[1L]],
      gross_return = mean(day$active * day$target_open_to_open_return, na.rm = TRUE),
      exposure = mean(day$active, na.rm = TRUE),
      exposure_matched_basket_return = mean(day$active, na.rm = TRUE) * day$basket_open_to_open_return[[1L]],
      turnover = mean(day$turnover, na.rm = TRUE),
      stringsAsFactors = FALSE
    )))
    terminal_turnover <- mean(part$active[!duplicated(part$symbol, fromLast = TRUE)], na.rm = TRUE)
    for (bps in cost_bps) {
      rate <- as.numeric(bps) / 10000
      net_daily <- daily$gross_return - rate * daily$turnover
      net_daily[[nrow(daily)]] <- net_daily[[nrow(daily)]] - rate * terminal_turnover
      net_return <- prod(1 + net_daily, na.rm = TRUE) - 1
      matched_return <- prod(1 + daily$exposure_matched_basket_return, na.rm = TRUE) - 1
      rows[[idx]] <- data.frame(
        fold_no = part$fold_no[[1L]],
        fold_id = fold_id,
        window_id = part$window_id[[1L]],
        cost_bps_one_way = as.numeric(bps),
        session_count = nrow(daily),
        mean_exposure = mean(daily$exposure, na.rm = TRUE),
        one_way_turnover = sum(daily$turnover, na.rm = TRUE) + terminal_turnover,
        cumulative_net_return = net_return,
        cumulative_exposure_matched_return = matched_return,
        cumulative_selection_excess = net_return - matched_return,
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$fold_no, out$cost_bps_one_way), , drop = FALSE]
}

g5_gen54_lp_concentration <- function(states) {
  if (!nrow(states)) return(data.frame())
  rows <- lapply(split(states, states$symbol), function(part) {
    state_mean <- function(state) mean(
      part$target_open_to_open_return[part$confirmation_state == state], na.rm = TRUE
    )
    state_count <- function(state) sum(part$confirmation_state == state)
    a <- "A_high_leadership__high_participation"
    b <- "B_high_leadership__low_participation"
    c <- "C_low_leadership__high_participation"
    a_mean <- state_mean(a)
    b_mean <- state_mean(b)
    c_mean <- state_mean(c)
    contrast <- mean(c(a_mean - b_mean, a_mean - c_mean), na.rm = TRUE)
    weight <- min(state_count(a), state_count(b) + state_count(c))
    data.frame(
      symbol = part$symbol[[1L]],
      state_a_count = state_count(a),
      state_b_count = state_count(b),
      state_c_count = state_count(c),
      mean_joint_contrast = contrast,
      absolute_contribution = abs(contrast) * weight,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  total <- sum(out$absolute_contribution, na.rm = TRUE)
  out$absolute_contribution_share <- if (total > 0) out$absolute_contribution / total else NA_real_
  rownames(out) <- NULL
  out
}

g5_gen54_lp_promotion_summary <- function(
    state_summary,
    fold_contrasts,
    cost_summary,
    concentration,
    required_correct_folds = 4L) {
  pooled <- state_summary[state_summary$scope == "pooled", , drop = FALSE]
  state_return <- function(state) {
    x <- pooled$mean_target_return[pooled$confirmation_state == state]
    if (length(x)) as.numeric(x[[1L]]) else NA_real_
  }
  a <- state_return("A_high_leadership__high_participation")
  b <- state_return("B_high_leadership__low_participation")
  c <- state_return("C_low_leadership__high_participation")
  correct_folds <- sum(fold_contrasts$correct_state_a_ordering, na.rm = TRUE)
  base_excess <- sum(cost_summary$cumulative_selection_excess[cost_summary$cost_bps_one_way == 10], na.rm = TRUE)
  stress_excess <- sum(cost_summary$cumulative_selection_excess[cost_summary$cost_bps_one_way == 20], na.rm = TRUE)
  max_share <- max(concentration$absolute_contribution_share, na.rm = TRUE)
  checks <- c(
    correct_folds >= required_correct_folds,
    is.finite(a) && is.finite(b) && a > b,
    is.finite(a) && is.finite(c) && a > c,
    is.finite(base_excess) && base_excess > 0,
    is.finite(stress_excess) && stress_excess >= 0,
    is.finite(max_share) && max_share <= 0.50
  )
  data.frame(
    confirmation_fold_count = nrow(fold_contrasts),
    correct_state_a_ordering_folds = correct_folds,
    required_correct_folds = required_correct_folds,
    pooled_state_a_mean_return = a,
    pooled_state_b_mean_return = b,
    pooled_state_c_mean_return = c,
    pooled_state_a_minus_b_return = a - b,
    pooled_state_a_minus_c_return = a - c,
    base_10bps_selection_excess_sum = base_excess,
    stress_20bps_selection_excess_sum = stress_excess,
    max_symbol_absolute_contribution_share = max_share,
    confirmation_status = if (all(checks)) "PASS_FOR_OPERATOR_MODEL_GATE" else "STOP",
    model_fit_count = 0L,
    stringsAsFactors = FALSE
  )
}
