tsseg_stop <- function(message) {
  stop(paste0("[TSLA-SIGNED-ER20-GRID] ", message), call. = FALSE)
}

tsseg_hac_lag <- function(observations, prior_sessions, forward_sessions) {
  observations <- as.integer(observations)
  if (observations < 2L) tsseg_stop("At least two observations are required for a HAC lag.")
  overlap_lag <- as.integer(prior_sessions) + as.integer(forward_sessions) - 1L
  rule_lag <- floor(4 * (observations / 100)^(2 / 9))
  min(max(overlap_lag, rule_lag), observations - 1L)
}

tsseg_hac_vcov <- function(fit, lag) {
  design <- stats::model.matrix(fit)
  residuals <- stats::residuals(fit)
  observations <- nrow(design)
  coefficients <- ncol(design)
  if (observations <= coefficients || qr(design)$rank < coefficients) {
    tsseg_stop("HAC model matrix is rank deficient.")
  }
  lag <- min(as.integer(lag), observations - 1L)
  meat <- matrix(0, nrow = coefficients, ncol = coefficients)
  for (index in seq_len(observations)) {
    x <- matrix(design[index, ], ncol = 1L)
    meat <- meat + residuals[[index]]^2 * (x %*% t(x))
  }
  if (lag > 0L) {
    for (offset in seq_len(lag)) {
      weight <- 1 - offset / (lag + 1)
      covariance_sum <- matrix(0, nrow = coefficients, ncol = coefficients)
      for (index in seq.int(offset + 1L, observations)) {
        x <- matrix(design[index, ], ncol = 1L)
        x_lag <- matrix(design[index - offset, ], ncol = 1L)
        covariance_sum <- covariance_sum +
          residuals[[index]] * residuals[[index - offset]] * (x %*% t(x_lag))
      }
      meat <- meat + weight * (covariance_sum + t(covariance_sum))
    }
  }
  bread <- solve(crossprod(design))
  observations / (observations - coefficients) * bread %*% meat %*% bread
}

tsseg_safe_correlation <- function(x, y, method = "pearson") {
  keep <- is.finite(x) & is.finite(y)
  x <- x[keep]
  y <- y[keep]
  if (length(x) < 3L || stats::sd(x) == 0 || stats::sd(y) == 0) return(NA_real_)
  stats::cor(x, y, method = method)
}

tsseg_adjust_bh <- function(p_value) {
  output <- rep(NA_real_, length(p_value))
  estimable <- is.finite(p_value)
  output[estimable] <- stats::p.adjust(p_value[estimable], method = "BH")
  output
}

tsseg_measure_state <- function(surface, state, prior_sessions, forward_sessions,
                                minimum_observations = 30L) {
  sample <- surface[surface$direction_state == state, , drop = FALSE]
  x <- sample$prior_cumulative_log_return
  y <- sample$forward_cumulative_log_return
  observations <- length(y)
  if (observations < minimum_observations) {
    return(data.frame(
      direction_state = state, prior_sessions = prior_sessions,
      forward_sessions = forward_sessions, observations = observations,
      estimation_status = "INSUFFICIENT_STATE_OBSERVATIONS",
      pearson_correlation = NA_real_, spearman_correlation = NA_real_,
      ols_slope = NA_real_, slope_hac_standard_error = NA_real_,
      slope_hac_lower_95 = NA_real_, slope_hac_upper_95 = NA_real_,
      slope_hac_p_value = NA_real_, mean_forward_return = NA_real_,
      probability_forward_up = NA_real_, hac_lag = NA_integer_,
      stringsAsFactors = FALSE
    ))
  }
  fit <- stats::lm(y ~ x)
  hac_lag <- tsseg_hac_lag(observations, prior_sessions, forward_sessions)
  covariance <- tsseg_hac_vcov(fit, hac_lag)
  slope <- unname(stats::coef(fit)[["x"]])
  slope_se <- sqrt(covariance["x", "x"])
  data.frame(
    direction_state = state, prior_sessions = prior_sessions,
    forward_sessions = forward_sessions, observations = observations,
    estimation_status = "ESTIMATED",
    pearson_correlation = tsseg_safe_correlation(x, y, "pearson"),
    spearman_correlation = tsseg_safe_correlation(x, y, "spearman"),
    ols_slope = slope, slope_hac_standard_error = slope_se,
    slope_hac_lower_95 = slope - stats::qnorm(0.975) * slope_se,
    slope_hac_upper_95 = slope + stats::qnorm(0.975) * slope_se,
    slope_hac_p_value = 2 * stats::pnorm(-abs(slope / slope_se)),
    mean_forward_return = mean(y), probability_forward_up = mean(y > 0),
    hac_lag = hac_lag, stringsAsFactors = FALSE
  )
}

tsseg_compare_states <- function(surface, reference_state, contrast_state,
                                 prior_sessions, forward_sessions,
                                 minimum_observations = 30L) {
  sample <- surface[
    surface$direction_state %in% c(reference_state, contrast_state),
    , drop = FALSE
  ]
  reference <- sample[sample$direction_state == reference_state, , drop = FALSE]
  contrast <- sample[sample$direction_state == contrast_state, , drop = FALSE]
  reference_n <- nrow(reference)
  contrast_n <- nrow(contrast)
  reference_correlation <- tsseg_safe_correlation(
    reference$prior_cumulative_log_return, reference$forward_cumulative_log_return
  )
  contrast_correlation <- tsseg_safe_correlation(
    contrast$prior_cumulative_log_return, contrast$forward_cumulative_log_return
  )
  base <- data.frame(
    reference_state = reference_state, contrast_state = contrast_state,
    prior_sessions = prior_sessions, forward_sessions = forward_sessions,
    reference_observations = reference_n, contrast_observations = contrast_n,
    reference_pearson_correlation = reference_correlation,
    contrast_pearson_correlation = contrast_correlation,
    contrast_minus_reference_pearson = contrast_correlation - reference_correlation,
    stringsAsFactors = FALSE
  )
  if (reference_n < minimum_observations || contrast_n < minimum_observations) {
    base$estimation_status <- "INSUFFICIENT_PAIR_OBSERVATIONS"
    base$contrast_minus_reference_ols_slope <- NA_real_
    base$interaction_hac_standard_error <- NA_real_
    base$interaction_hac_lower_95 <- NA_real_
    base$interaction_hac_upper_95 <- NA_real_
    base$interaction_hac_p_value <- NA_real_
    base$hac_lag <- NA_integer_
    return(base)
  }
  x <- sample$prior_cumulative_log_return
  y <- sample$forward_cumulative_log_return
  contrast_indicator <- as.numeric(sample$direction_state == contrast_state)
  fit <- stats::lm(y ~ x * contrast_indicator)
  hac_lag <- tsseg_hac_lag(nrow(sample), prior_sessions, forward_sessions)
  covariance <- tsseg_hac_vcov(fit, hac_lag)
  coefficient <- "x:contrast_indicator"
  slope_difference <- unname(stats::coef(fit)[[coefficient]])
  slope_se <- sqrt(covariance[coefficient, coefficient])
  base$estimation_status <- "ESTIMATED"
  base$contrast_minus_reference_ols_slope <- slope_difference
  base$interaction_hac_standard_error <- slope_se
  base$interaction_hac_lower_95 <- slope_difference - stats::qnorm(0.975) * slope_se
  base$interaction_hac_upper_95 <- slope_difference + stats::qnorm(0.975) * slope_se
  base$interaction_hac_p_value <- 2 * stats::pnorm(-abs(slope_difference / slope_se))
  base$hac_lag <- hac_lag
  base
}

tsseg_measure_sign_asymmetry <- function(surface, state, prior_sessions,
                                         forward_sessions,
                                         minimum_branch_observations = 30L) {
  sample <- surface[
    surface$direction_state == state &
      surface$prior_cumulative_log_return != 0,
    , drop = FALSE
  ]
  negative <- sample[sample$prior_cumulative_log_return < 0, , drop = FALSE]
  positive <- sample[sample$prior_cumulative_log_return > 0, , drop = FALSE]
  negative_n <- nrow(negative)
  positive_n <- nrow(positive)
  negative_correlation <- tsseg_safe_correlation(
    negative$prior_cumulative_log_return, negative$forward_cumulative_log_return
  )
  positive_correlation <- tsseg_safe_correlation(
    positive$prior_cumulative_log_return, positive$forward_cumulative_log_return
  )
  base <- data.frame(
    direction_state = state, prior_sessions = prior_sessions,
    forward_sessions = forward_sessions, observations = nrow(sample),
    negative_observations = negative_n, positive_observations = positive_n,
    minimum_branch_observations = min(negative_n, positive_n),
    negative_pearson_correlation = negative_correlation,
    positive_pearson_correlation = positive_correlation,
    positive_minus_negative_pearson = positive_correlation - negative_correlation,
    negative_mean_forward_return = if (negative_n) mean(negative$forward_cumulative_log_return) else NA_real_,
    positive_mean_forward_return = if (positive_n) mean(positive$forward_cumulative_log_return) else NA_real_,
    stringsAsFactors = FALSE
  )
  if (negative_n < minimum_branch_observations || positive_n < minimum_branch_observations) {
    base$estimation_status <- "STRUCTURALLY_OR_EMPIRICALLY_SPARSE_BRANCH"
    base$positive_minus_negative_ols_slope <- NA_real_
    base$slope_interaction_hac_standard_error <- NA_real_
    base$slope_interaction_hac_lower_95 <- NA_real_
    base$slope_interaction_hac_upper_95 <- NA_real_
    base$slope_interaction_hac_p_value <- NA_real_
    base$hac_lag <- NA_integer_
    return(base)
  }
  x <- sample$prior_cumulative_log_return
  y <- sample$forward_cumulative_log_return
  positive_indicator <- as.numeric(x > 0)
  fit <- stats::lm(y ~ x * positive_indicator)
  hac_lag <- tsseg_hac_lag(nrow(sample), prior_sessions, forward_sessions)
  covariance <- tsseg_hac_vcov(fit, hac_lag)
  coefficient <- "x:positive_indicator"
  slope_difference <- unname(stats::coef(fit)[[coefficient]])
  slope_se <- sqrt(covariance[coefficient, coefficient])
  base$estimation_status <- "ESTIMATED"
  base$positive_minus_negative_ols_slope <- slope_difference
  base$slope_interaction_hac_standard_error <- slope_se
  base$slope_interaction_hac_lower_95 <- slope_difference - stats::qnorm(0.975) * slope_se
  base$slope_interaction_hac_upper_95 <- slope_difference + stats::qnorm(0.975) * slope_se
  base$slope_interaction_hac_p_value <- 2 * stats::pnorm(-abs(slope_difference / slope_se))
  base$hac_lag <- hac_lag
  base
}
