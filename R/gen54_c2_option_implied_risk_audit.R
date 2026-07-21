g5_gen54_c2_partial_spearman <- function(x, y, control, minimum = 10L) {
  keep <- is.finite(x) & is.finite(y) & is.finite(control)
  if (sum(keep) < as.integer(minimum)) return(NA_real_)
  xr <- rank(x[keep], ties.method = "average")
  yr <- rank(y[keep], ties.method = "average")
  zr <- rank(control[keep], ties.method = "average")
  if (stats::sd(zr) == 0) return(NA_real_)
  design <- cbind(1, zr)
  x_residual <- stats::lm.fit(design, xr)$residuals
  y_residual <- stats::lm.fit(design, yr)$residuals
  suppressWarnings(stats::cor(x_residual, y_residual))
}

g5_gen54_c2_join_vix <- function(context, vix_data) {
  required_context <- c(
    "feature_date",
    "spy_drawdown_126",
    "forward_realized_volatility_h5",
    "forward_realized_volatility_h20",
    "label_end_date_h5",
    "label_end_date_h20"
  )
  if (!all(required_context %in% names(context))) {
    stop("C2 context is missing required C1 risk columns.", call. = FALSE)
  }
  if (!all(c("observation_date", "close") %in% names(vix_data))) {
    stop("C2 VIX data must contain observation_date and close.", call. = FALSE)
  }
  if (anyDuplicated(vix_data$observation_date)) stop("C2 VIX dates must be unique.", call. = FALSE)
  context$vix_30d_close <- vix_data$close[match(context$feature_date, vix_data$observation_date)] / 100
  context
}

g5_gen54_c2_fold_audit <- function(context, folds) {
  rows <- list()
  idx <- 1L
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    train <- context[
      context$feature_date >= fold$train_start_date & context$feature_date <= fold$train_end_date,
      ,
      drop = FALSE
    ]
    threshold <- stats::median(train$vix_30d_close, na.rm = TRUE)
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
      keep <- is.finite(oos$vix_30d_close) &
        is.finite(oos[[target_name]]) &
        is.finite(oos$spy_drawdown_126)
      high <- keep & oos$vix_30d_close >= threshold
      low <- keep & oos$vix_30d_close < threshold
      rows[[idx]] <- data.frame(
        fold_id = fold$fold_id,
        horizon = horizon,
        train_vix_median = threshold,
        oos_dates = sum(keep),
        high_state_share = if (sum(keep)) mean(high[keep]) else NA_real_,
        rank_correlation = if (sum(keep) >= 10L) suppressWarnings(stats::cor(oos$vix_30d_close[keep], oos[[target_name]][keep], method = "spearman")) else NA_real_,
        partial_rank_correlation_controlling_spy_drawdown = g5_gen54_c2_partial_spearman(
          oos$vix_30d_close,
          oos[[target_name]],
          oos$spy_drawdown_126,
          minimum = 10L
        ),
        high_state_mean_realized_volatility = if (any(high)) mean(oos[[target_name]][high]) else NA_real_,
        low_state_mean_realized_volatility = if (any(low)) mean(oos[[target_name]][low]) else NA_real_,
        separation_realized_volatility = if (any(high) && any(low)) mean(oos[[target_name]][high]) - mean(oos[[target_name]][low]) else NA_real_,
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  do.call(rbind, rows)
}

g5_gen54_c2_verdict <- function(fold_audit, required_positive_folds = 12L) {
  rows <- lapply(g5_gen54_c1_horizons(), function(horizon) {
    part <- fold_audit[fold_audit$horizon == horizon, , drop = FALSE]
    positive_correlation <- sum(part$rank_correlation > 0, na.rm = TRUE)
    positive_partial <- sum(part$partial_rank_correlation_controlling_spy_drawdown > 0, na.rm = TRUE)
    positive_separation <- sum(part$separation_realized_volatility > 0, na.rm = TRUE)
    mean_correlation <- mean(part$rank_correlation, na.rm = TRUE)
    mean_partial <- mean(part$partial_rank_correlation_controlling_spy_drawdown, na.rm = TRUE)
    mean_separation <- mean(part$separation_realized_volatility, na.rm = TRUE)
    high_share <- mean(part$high_state_share, na.rm = TRUE)
    correlation_pass <- positive_correlation >= required_positive_folds && mean_correlation > 0
    separation_pass <- positive_separation >= required_positive_folds && mean_separation > 0
    share_pass <- high_share >= 0.25 && high_share <= 0.75
    direct_pass <- correlation_pass && separation_pass && share_pass
    incremental_pass <- positive_partial >= required_positive_folds && mean_partial > 0
    data.frame(
      horizon = horizon,
      positive_correlation_folds = positive_correlation,
      positive_partial_correlation_folds = positive_partial,
      positive_separation_folds = positive_separation,
      mean_rank_correlation = mean_correlation,
      mean_partial_rank_correlation = mean_partial,
      mean_separation_realized_volatility = mean_separation,
      mean_high_state_share = high_share,
      correlation_verdict = if (correlation_pass) "PASS_CONTINUOUS_RISK_ORDERING" else "STOP_CONTINUOUS_RISK_ORDERING",
      separation_verdict = if (separation_pass) "PASS_MEDIAN_STATE_SEPARATION" else "STOP_MEDIAN_STATE_SEPARATION",
      direct_verdict = if (direct_pass) "PASS_DIRECT_RISK_ORDERING" else "STOP_DIRECT_RISK_ORDERING",
      incremental_verdict = if (incremental_pass) "PASS_INCREMENTAL_TO_SPY_DRAWDOWN" else "STOP_INCREMENTAL_TO_SPY_DRAWDOWN",
      horizon_verdict = if (direct_pass && incremental_pass) "PASS_C2_HORIZON" else "STOP_C2_HORIZON",
      stringsAsFactors = FALSE
    )
  })
  horizon_summary <- do.call(rbind, rows)
  both_correlation <- all(horizon_summary$correlation_verdict == "PASS_CONTINUOUS_RISK_ORDERING")
  both_direct <- all(horizon_summary$direct_verdict == "PASS_DIRECT_RISK_ORDERING")
  both_incremental <- all(horizon_summary$incremental_verdict == "PASS_INCREMENTAL_TO_SPY_DRAWDOWN")
  overall <- if (both_direct && both_incremental) {
    "PASS_TO_RISK_POLICY_THEORY_SESSION"
  } else if (both_correlation && both_incremental && !both_direct) {
    "STOP_THRESHOLD_INSTABILITY"
  } else if (both_direct && !both_incremental) {
    "REDUNDANT_WITH_PRICE_STRESS"
  } else if (sum(horizon_summary$horizon_verdict == "PASS_C2_HORIZON") == 1L) {
    "STOP_HORIZON_SPECIFIC"
  } else {
    "STOP_NON_OHLCV_RISK_PRIMITIVE"
  }
  list(horizon_summary = horizon_summary, overall_status = overall)
}
