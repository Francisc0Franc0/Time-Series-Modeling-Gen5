g5_gen54_c1_feature_names <- function() c(
  "basket_realized_volatility_20",
  "spy_downside_volatility_20",
  "spy_drawdown_126",
  "average_cross_sectional_correlation_60"
)

g5_gen54_c1_horizons <- function() c(5L, 20L)

g5_gen54_c1_observed_basket_returns <- function(return_matrix, eligibility_matrix, minimum_cross_section = 20L) {
  if (!is.matrix(return_matrix) || !is.matrix(eligibility_matrix) || !identical(dim(return_matrix), dim(eligibility_matrix))) {
    stop("Return and eligibility inputs must be same-sized matrices.", call. = FALSE)
  }
  out <- rep(NA_real_, nrow(return_matrix))
  for (i in seq_len(nrow(return_matrix))) {
    eligibility_index <- i - 2L
    if (eligibility_index < 1L) next
    keep <- eligibility_matrix[eligibility_index, ] & is.finite(return_matrix[i, ])
    if (sum(keep) >= as.integer(minimum_cross_section)) out[[i]] <- mean(return_matrix[i, keep])
  }
  out
}

g5_gen54_c1_forward_realized_vol <- function(observed_returns, horizon) {
  horizon <- as.integer(horizon)
  out <- rep(NA_real_, length(observed_returns))
  for (i in seq_along(observed_returns)) {
    indices <- seq.int(i + 2L, i + horizon + 1L)
    if (max(indices) > length(observed_returns)) next
    values <- observed_returns[indices]
    if (all(is.finite(values))) out[[i]] <- stats::sd(values) * sqrt(252)
  }
  out
}

g5_gen54_c1_downside_volatility <- function(return_values, window = 20L) {
  g5_gen54_xs_rolling_apply(
    return_values,
    window,
    function(x) sqrt(mean(pmin(x, 0)^2)) * sqrt(252),
    minimum = window
  )
}

g5_gen54_c1_build_context <- function(
    bars,
    base_panel,
    registry = g5_gen54_xs_candidate_registry(),
    minimum_reference_basket = 18L) {
  candidates <- as.character(registry$symbol)
  dates <- sort(unique(base_panel$feature_date))
  aligned <- lapply(candidates, function(symbol) g5_gen54_xs_align_symbol(bars, symbol, dates))
  names(aligned) <- candidates
  opens <- sapply(aligned, function(x) x$open)
  closes <- sapply(aligned, function(x) x$close)
  colnames(opens) <- candidates
  colnames(closes) <- candidates

  open_returns <- matrix(NA_real_, nrow = nrow(opens), ncol = ncol(opens), dimnames = dimnames(opens))
  close_log_returns <- matrix(NA_real_, nrow = nrow(closes), ncol = ncol(closes), dimnames = dimnames(closes))
  if (nrow(opens) >= 2L) {
    open_returns[2:nrow(opens), ] <- opens[2:nrow(opens), , drop = FALSE] / opens[1:(nrow(opens) - 1L), , drop = FALSE] - 1
    close_log_returns[2:nrow(closes), ] <- log(closes[2:nrow(closes), , drop = FALSE] / closes[1:(nrow(closes) - 1L), , drop = FALSE])
  }

  eligibility <- matrix(FALSE, nrow = length(dates), ncol = length(candidates), dimnames = list(as.character(dates), candidates))
  for (symbol in candidates) {
    part <- base_panel[base_panel$symbol == symbol, c("feature_date", "point_in_time_eligible"), drop = FALSE]
    eligibility[, symbol] <- as.logical(part$point_in_time_eligible[match(dates, part$feature_date)])
    eligibility[is.na(eligibility[, symbol]), symbol] <- FALSE
  }
  observed_basket_return <- g5_gen54_c1_observed_basket_returns(
    open_returns,
    eligibility,
    minimum_cross_section = as.integer(minimum_reference_basket)
  )

  spy <- g5_gen54_xs_align_symbol(bars, "SPY", dates)
  spy_open_return <- rep(NA_real_, length(dates))
  if (length(dates) >= 2L) spy_open_return[2:length(dates)] <- spy$open[2:length(dates)] / spy$open[1:(length(dates) - 1L)] - 1
  spy_high_126 <- g5_gen54_xs_rolling_apply(spy$close, 126L, max, minimum = 126L)

  average_correlation <- rep(NA_real_, length(dates))
  for (i in seq_along(dates)) {
    if (i < 60L) next
    corr <- suppressWarnings(stats::cor(close_log_returns[(i - 59L):i, , drop = FALSE], use = "pairwise.complete.obs"))
    off_diagonal <- corr[upper.tri(corr)]
    if (any(is.finite(off_diagonal))) average_correlation[[i]] <- mean(off_diagonal, na.rm = TRUE)
  }

  context <- data.frame(
    feature_date = as.Date(dates),
    basket_realized_volatility_20 = g5_gen54_xs_rolling_apply(observed_basket_return, 20L, stats::sd, minimum = 20L) * sqrt(252),
    spy_downside_volatility_20 = g5_gen54_c1_downside_volatility(spy_open_return, 20L),
    spy_drawdown_126 = -(spy$close / spy_high_126 - 1),
    average_cross_sectional_correlation_60 = average_correlation,
    observed_equal_weight_open_return = observed_basket_return,
    stringsAsFactors = FALSE
  )
  for (horizon in g5_gen54_c1_horizons()) {
    context[[paste0("forward_realized_volatility_h", horizon)]] <- g5_gen54_c1_forward_realized_vol(observed_basket_return, horizon)
    context[[paste0("label_end_date_h", horizon)]] <- as.Date(g5_gen54_xs_lead(dates, horizon + 1L))
  }
  context
}

g5_gen54_c1_fold_audit <- function(context, folds) {
  rows <- list()
  idx <- 1L
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    train <- context[context$feature_date >= fold$train_start_date & context$feature_date <= fold$train_end_date, , drop = FALSE]
    for (feature in g5_gen54_c1_feature_names()) {
      threshold <- stats::median(train[[feature]], na.rm = TRUE)
      for (horizon in g5_gen54_c1_horizons()) {
        target_name <- paste0("forward_realized_volatility_h", horizon)
        label_name <- paste0("label_end_date_h", horizon)
        oos <- context[
          context$feature_date >= fold$oos_start_date &
            context$feature_date <= fold$oos_end_date &
            context[[label_name]] <= fold$oos_end_date,
          ,
          drop = FALSE
        ]
        keep <- is.finite(oos[[feature]]) & is.finite(oos[[target_name]])
        high <- keep & oos[[feature]] >= threshold
        low <- keep & oos[[feature]] < threshold
        correlation <- if (sum(keep) >= 10L) suppressWarnings(stats::cor(oos[[feature]][keep], oos[[target_name]][keep], method = "spearman")) else NA_real_
        rows[[idx]] <- data.frame(
          fold_id = fold$fold_id,
          feature_name = feature,
          horizon = horizon,
          train_threshold = threshold,
          oos_dates = sum(keep),
          high_state_share = if (sum(keep)) mean(high[keep]) else NA_real_,
          rank_correlation = correlation,
          high_state_mean_realized_volatility = if (any(high)) mean(oos[[target_name]][high]) else NA_real_,
          low_state_mean_realized_volatility = if (any(low)) mean(oos[[target_name]][low]) else NA_real_,
          separation_realized_volatility = if (any(high) && any(low)) mean(oos[[target_name]][high]) - mean(oos[[target_name]][low]) else NA_real_,
          stringsAsFactors = FALSE
        )
        idx <- idx + 1L
      }
    }
  }
  do.call(rbind, rows)
}

g5_gen54_c1_verdict <- function(fold_audit, required_positive_folds = 12L) {
  horizon_rows <- list()
  idx <- 1L
  for (feature in g5_gen54_c1_feature_names()) {
    for (horizon in g5_gen54_c1_horizons()) {
      part <- fold_audit[fold_audit$feature_name == feature & fold_audit$horizon == horizon, , drop = FALSE]
      positive_correlation <- sum(part$rank_correlation > 0, na.rm = TRUE)
      positive_separation <- sum(part$separation_realized_volatility > 0, na.rm = TRUE)
      pooled_correlation <- mean(part$rank_correlation, na.rm = TRUE)
      pooled_separation <- mean(part$separation_realized_volatility, na.rm = TRUE)
      high_share <- mean(part$high_state_share, na.rm = TRUE)
      pass <- positive_correlation >= required_positive_folds &&
        positive_separation >= required_positive_folds &&
        pooled_correlation > 0 && pooled_separation > 0 &&
        high_share >= 0.25 && high_share <= 0.75
      horizon_rows[[idx]] <- data.frame(
        feature_name = feature,
        horizon = horizon,
        positive_correlation_folds = positive_correlation,
        positive_separation_folds = positive_separation,
        pooled_mean_rank_correlation = pooled_correlation,
        pooled_mean_separation_realized_volatility = pooled_separation,
        mean_high_state_share = high_share,
        required_positive_folds = required_positive_folds,
        horizon_verdict = if (pass) "PASS_RISK_ORDERING_HORIZON" else "STOP_RISK_ORDERING_HORIZON",
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  horizon_summary <- do.call(rbind, horizon_rows)
  feature_summary <- do.call(rbind, lapply(g5_gen54_c1_feature_names(), function(feature) {
    part <- horizon_summary[horizon_summary$feature_name == feature, , drop = FALSE]
    pass <- nrow(part) == length(g5_gen54_c1_horizons()) && all(part$horizon_verdict == "PASS_RISK_ORDERING_HORIZON")
    data.frame(
      feature_name = feature,
      h5_verdict = part$horizon_verdict[match(5L, part$horizon)],
      h20_verdict = part$horizon_verdict[match(20L, part$horizon)],
      final_verdict = if (pass) "PASS_TO_RISK_SCALER_DESIGN" else "STOP_C1_RISK_PRIMITIVE",
      stringsAsFactors = FALSE
    )
  }))
  list(horizon_summary = horizon_summary, feature_summary = feature_summary)
}
