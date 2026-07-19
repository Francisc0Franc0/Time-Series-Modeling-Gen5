g5_gen54_x1b_feature_names <- function() c(
  "residual_momentum_60",
  "residual_reversal_5",
  "signed_efficiency_20",
  "intraday_minus_overnight_20"
)

g5_gen54_c0_feature_names <- function() c(
  "breadth_60",
  "group_participation_60",
  "inverse_average_correlation_60",
  "inverse_cross_sectional_dispersion_20"
)

g5_gen54_roll_sum_complete <- function(x, window) {
  g5_gen54_xs_rolling_apply(x, window, sum, minimum = window)
}

g5_gen54_signed_efficiency <- function(return_values, window = 20L) {
  out <- rep(NA_real_, length(return_values))
  for (i in seq_along(return_values)) {
    if (i < window) next
    values <- return_values[(i - window + 1L):i]
    if (!all(is.finite(values))) next
    denominator <- sum(abs(values))
    if (denominator > 0) out[[i]] <- sum(values) / denominator
  }
  out
}

g5_gen54_one_step_residuals <- function(asset_return, market_return, peer_return, estimation_window = 126L) {
  out <- rep(NA_real_, length(asset_return))
  for (i in seq_along(asset_return)) {
    if (i <= estimation_window) next
    train <- seq.int(i - estimation_window, i - 1L)
    y <- asset_return[train]
    x <- cbind(1, market_return[train], peer_return[train])
    current <- c(1, market_return[[i]], peer_return[[i]])
    if (!all(is.finite(c(y, x, current)))) next
    fit <- stats::lm.fit(x = x, y = y)
    if (any(!is.finite(fit$coefficients))) next
    out[[i]] <- asset_return[[i]] - sum(current * fit$coefficients)
  }
  out
}

g5_gen54_build_ohlcv_extension <- function(bars, base_panel, registry = g5_gen54_xs_candidate_registry()) {
  candidates <- registry$symbol
  dates <- sort(unique(base_panel$feature_date))
  aligned <- lapply(candidates, function(symbol) g5_gen54_xs_align_symbol(bars, symbol, dates))
  names(aligned) <- candidates
  spy <- g5_gen54_xs_align_symbol(bars, "SPY", dates)
  spy_return <- log(spy$close / g5_gen54_xs_lag(spy$close, 1L))

  return_matrix <- sapply(aligned, function(x) log(x$close / g5_gen54_xs_lag(x$close, 1L)))
  colnames(return_matrix) <- candidates
  feature_rows <- list()
  for (symbol in candidates) {
    x <- aligned[[symbol]]
    asset_return <- return_matrix[, symbol]
    peers <- registry$symbol[registry$economic_group == registry$economic_group[match(symbol, registry$symbol)] & registry$symbol != symbol]
    peer_return <- if (length(peers) == 1L) return_matrix[, peers] else rowMeans(return_matrix[, peers, drop = FALSE], na.rm = FALSE)
    residual <- g5_gen54_one_step_residuals(asset_return, spy_return, peer_return, estimation_window = 126L)
    intraday <- log(x$close / x$open)
    overnight <- log(x$open / g5_gen54_xs_lag(x$close, 1L))
    feature_rows[[symbol]] <- data.frame(
      symbol = symbol,
      feature_date = dates,
      residual_momentum_60 = g5_gen54_roll_sum_complete(residual, 60L),
      residual_reversal_5 = -g5_gen54_roll_sum_complete(residual, 5L),
      signed_efficiency_20 = g5_gen54_signed_efficiency(asset_return, 20L),
      intraday_minus_overnight_20 = g5_gen54_roll_sum_complete(intraday - overnight, 20L),
      stringsAsFactors = FALSE
    )
  }
  features <- do.call(rbind, feature_rows)
  rownames(features) <- NULL
  out <- merge(base_panel, features, by = c("symbol", "feature_date"), all.x = TRUE, sort = FALSE)
  out <- out[order(out$feature_date, match(out$symbol, candidates)), , drop = FALSE]
  for (feature in g5_gen54_x1b_feature_names()) {
    rank_name <- paste0(feature, "_rank")
    out[[rank_name]] <- NA_real_
    eligible <- which(out$cross_section_eligible & is.finite(out[[feature]]))
    groups <- split(eligible, out$feature_date[eligible])
    for (indices in groups) {
      if (length(indices) >= 20L) out[[rank_name]][indices] <- g5_gen54_xs_rank01(out[[feature]][indices])
    }
  }

  daily_dispersion <- apply(return_matrix, 1L, stats::sd, na.rm = TRUE)
  average_correlation <- rep(NA_real_, length(dates))
  for (i in seq_along(dates)) {
    if (i < 60L) next
    corr <- suppressWarnings(stats::cor(return_matrix[(i - 59L):i, , drop = FALSE], use = "pairwise.complete.obs"))
    average_correlation[[i]] <- mean(corr[upper.tri(corr)], na.rm = TRUE)
  }
  context <- unique(out[, c("feature_date", "equal_weight_universe_forward_return_h5", "label_end_date")])
  context <- context[order(context$feature_date), , drop = FALSE]
  context$breadth_60 <- vapply(context$feature_date, function(date) {
    part <- out[out$feature_date == date & out$cross_section_eligible, , drop = FALSE]
    if (nrow(part) < 20L) NA_real_ else mean(part$momentum_60 > 0, na.rm = TRUE)
  }, numeric(1L))
  context$group_participation_60 <- vapply(context$feature_date, function(date) {
    part <- out[out$feature_date == date & out$cross_section_eligible, , drop = FALSE]
    if (nrow(part) < 20L) return(NA_real_)
    medians <- aggregate(part$momentum_60, list(group = part$economic_group), stats::median, na.rm = TRUE)
    mean(medians$x > 0)
  }, numeric(1L))
  context$inverse_average_correlation_60 <- -average_correlation[match(context$feature_date, dates)]
  dispersion_20 <- g5_gen54_xs_rolling_apply(daily_dispersion, 20L, mean, minimum = 20L)
  context$inverse_cross_sectional_dispersion_20 <- -dispersion_20[match(context$feature_date, dates)]
  list(panel = out, context = context)
}

g5_gen54_x1b_redundancy_audit <- function(oos_panel, reference_feature = "group_relative_20") {
  rows <- list()
  idx <- 1L
  for (feature in g5_gen54_x1b_feature_names()) {
    for (date in unique(oos_panel$feature_date)) {
      part <- oos_panel[oos_panel$feature_date == date & oos_panel$cross_section_eligible, , drop = FALSE]
      x <- part[[paste0(feature, "_rank")]]
      y <- part[[paste0(reference_feature, "_rank")]]
      keep <- is.finite(x) & is.finite(y)
      rows[[idx]] <- data.frame(feature_date = as.Date(date, origin = "1970-01-01"), feature_name = feature,
        rank_correlation = if (sum(keep) >= 5L) suppressWarnings(stats::cor(x[keep], y[keep], method = "spearman")) else NA_real_, stringsAsFactors = FALSE)
      idx <- idx + 1L
    }
  }
  daily <- do.call(rbind, rows)
  summary <- aggregate(abs(daily$rank_correlation), list(feature_name = daily$feature_name), stats::median, na.rm = TRUE)
  names(summary)[[2L]] <- "median_absolute_rank_correlation_to_group_relative_20"
  summary$redundancy_cap <- 0.70
  summary$redundancy_status <- ifelse(summary$median_absolute_rank_correlation_to_group_relative_20 <= 0.70, "PASS_DISTINCT", "STOP_REDUNDANT")
  list(daily = daily, summary = summary)
}

g5_gen54_c0_fold_audit <- function(context, folds) {
  rows <- list()
  idx <- 1L
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    train <- context[context$feature_date >= fold$train_start_date & context$feature_date <= fold$train_end_date, , drop = FALSE]
    oos <- context[context$feature_date >= fold$oos_start_date & context$feature_date <= fold$oos_end_date & context$label_end_date <= fold$oos_end_date, , drop = FALSE]
    for (feature in g5_gen54_c0_feature_names()) {
      threshold <- stats::median(train[[feature]], na.rm = TRUE)
      keep <- is.finite(oos[[feature]]) & is.finite(oos$equal_weight_universe_forward_return_h5)
      favorable <- keep & oos[[feature]] >= threshold
      unfavorable <- keep & oos[[feature]] < threshold
      rows[[idx]] <- data.frame(
        fold_id = fold$fold_id, feature_name = feature, train_threshold = threshold,
        oos_dates = sum(keep), favorable_share = if (sum(keep)) mean(favorable[keep]) else NA_real_,
        favorable_mean_h5 = if (any(favorable)) mean(oos$equal_weight_universe_forward_return_h5[favorable]) else NA_real_,
        unfavorable_mean_h5 = if (any(unfavorable)) mean(oos$equal_weight_universe_forward_return_h5[unfavorable]) else NA_real_,
        separation_h5 = if (any(favorable) && any(unfavorable)) mean(oos$equal_weight_universe_forward_return_h5[favorable]) - mean(oos$equal_weight_universe_forward_return_h5[unfavorable]) else NA_real_,
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  do.call(rbind, rows)
}

g5_gen54_c0_verdict <- function(fold_audit, required_positive_folds = 12L) {
  rows <- lapply(unique(fold_audit$feature_name), function(feature) {
    part <- fold_audit[fold_audit$feature_name == feature, , drop = FALSE]
    positive <- sum(part$separation_h5 > 0, na.rm = TRUE)
    pooled <- mean(part$separation_h5, na.rm = TRUE)
    share <- mean(part$favorable_share, na.rm = TRUE)
    pass <- positive >= required_positive_folds && pooled > 0 && share >= 0.25 && share <= 0.75
    data.frame(feature_name = feature, positive_separation_folds = positive,
      pooled_mean_separation_h5 = pooled, mean_favorable_share = share,
      required_positive_folds = required_positive_folds,
      verdict = if (pass) "PASS_EXPOSURE_PERMISSION_DIAGNOSTIC" else "STOP_AS_EXPOSURE_PERMISSION_DIAGNOSTIC", stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}
