# Shared causal Kalman dynamic-regression helpers for LIT-MR-04.1/05.1.

g5_kf_schema_version <- function() "gen5_lit_mr_kalman_v1"

g5_kf_stop <- function(message) stop(message, call. = FALSE)

g5_kf_validate_bars <- function(bars, symbols, query_end) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_kf_stop(paste("Bars are missing:", paste(missing, collapse = ", ")))
  }
  symbols <- toupper(as.character(symbols))
  if (length(symbols) < 2L || length(symbols) > 3L || anyDuplicated(symbols)) {
    g5_kf_stop("Kalman POC requires two or three distinct symbols.")
  }
  bars <- bars[bars$symbol %in% symbols, required, drop = FALSE]
  bars$symbol <- toupper(as.character(bars$symbol))
  bars$session_date <- as.Date(bars$session_date)
  if (!setequal(unique(bars$symbol), symbols)) {
    g5_kf_stop("Exact frozen symbol coverage failed.")
  }
  if (anyDuplicated(bars[c("symbol", "session_date")])) {
    g5_kf_stop("Duplicate symbol-session bars are prohibited.")
  }
  if (any(is.na(bars$session_date)) || any(bars$session_date > as.Date(query_end))) {
    g5_kf_stop("Bars violate the explicit date boundary.")
  }
  numeric_columns <- c("open", "high", "low", "close", "volume")
  if (any(!vapply(bars[numeric_columns], is.numeric, logical(1)))) {
    g5_kf_stop("OHLCV columns must be numeric.")
  }
  prices <- as.matrix(bars[c("open", "high", "low", "close")])
  if (any(!is.finite(prices)) || any(prices <= 0)) {
    g5_kf_stop("Prices must be finite and positive.")
  }
  bars[order(bars$session_date, bars$symbol), , drop = FALSE]
}

g5_kf_common_panel <- function(bars, symbols, query_end) {
  bars <- g5_kf_validate_bars(bars, symbols, query_end)
  legs <- lapply(seq_along(symbols), function(i) {
    x <- bars[
      bars$symbol == symbols[[i]],
      c("session_date", "open", "close"),
      drop = FALSE
    ]
    names(x)[2:3] <- paste0(c("open_", "close_"), i)
    x
  })
  panel <- Reduce(function(x, y) merge(x, y, by = "session_date"), legs)
  panel <- panel[order(panel$session_date), , drop = FALSE]
  rownames(panel) <- NULL
  if (nrow(panel) < 260L) g5_kf_stop("Too few common sessions for warm-up.")
  panel
}

g5_kf_regularized_inverse <- function(x) {
  scale <- mean(abs(diag(x)))
  ridge <- max(.Machine$double.eps^0.5, scale * 1e-10)
  solve(x + diag(ridge, nrow(x)))
}

g5_kf_initialize <- function(y, x, warmup, delta) {
  if (warmup < ncol(x) + 3L || length(y) < warmup) {
    g5_kf_stop("Warm-up is too short for initialization.")
  }
  x0 <- cbind(x[seq_len(warmup), , drop = FALSE], intercept = 1)
  y0 <- y[seq_len(warmup)]
  xtx_inverse <- g5_kf_regularized_inverse(crossprod(x0))
  theta <- as.numeric(xtx_inverse %*% crossprod(x0, y0))
  residual <- y0 - as.numeric(x0 %*% theta)
  sigma2 <- sum(residual^2) / max(1L, nrow(x0) - ncol(x0))
  sigma2 <- max(sigma2, .Machine$double.eps^0.5)
  p0 <- sigma2 * xtx_inverse
  q <- delta / (1 - delta) * diag(pmax(diag(p0), .Machine$double.eps^0.5))
  list(theta = theta, p = p0, q = q, r = sigma2, residual = residual)
}

g5_kf_rolling_ols <- function(y, x, lookback = 20L) {
  n <- length(y)
  p <- ncol(x) + 1L
  coefficients <- matrix(NA_real_, nrow = n, ncol = p)
  prediction <- standard_error <- residual <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    if (i <= lookback) next
    idx <- (i - lookback):(i - 1L)
    design <- cbind(x[idx, , drop = FALSE], intercept = 1)
    inverse <- tryCatch(
      g5_kf_regularized_inverse(crossprod(design)),
      error = function(e) NULL
    )
    if (is.null(inverse)) next
    theta <- as.numeric(inverse %*% crossprod(design, y[idx]))
    h <- c(x[i, ], 1)
    fitted_residual <- y[idx] - as.numeric(design %*% theta)
    sigma2 <- sum(fitted_residual^2) / max(1L, nrow(design) - ncol(design))
    prediction[[i]] <- sum(h * theta)
    residual[[i]] <- y[[i]] - prediction[[i]]
    standard_error[[i]] <- sqrt(max(
      sigma2 * (1 + as.numeric(t(h) %*% inverse %*% h)),
      .Machine$double.eps^0.5
    ))
    coefficients[i, ] <- theta
  }
  colnames(coefficients) <- c(paste0("rolling_beta_", seq_len(ncol(x))), "rolling_intercept")
  data.frame(
    coefficients,
    rolling_prediction = prediction,
    rolling_innovation = residual,
    rolling_innovation_sd = standard_error,
    rolling_z = residual / standard_error,
    check.names = FALSE
  )
}

g5_kf_filter <- function(panel, contract) {
  k <- length(contract$predictor_symbols)
  y <- as.numeric(panel$close_1)
  x <- as.matrix(panel[paste0("close_", seq.int(2L, k + 1L))])
  initialization <- g5_kf_initialize(
    y, x, contract$warmup_sessions, contract$delta
  )
  n <- nrow(panel)
  p <- k + 1L
  prior <- posterior <- matrix(NA_real_, nrow = n, ncol = p)
  innovation <- innovation_variance <- z <- rep(NA_real_, n)
  prior_sd <- matrix(NA_real_, nrow = n, ncol = p)
  posterior_sd <- matrix(NA_real_, nrow = n, ncol = p)
  warmup <- contract$warmup_sessions
  theta <- initialization$theta
  state_covariance <- initialization$p
  posterior[warmup, ] <- theta
  posterior_sd[warmup, ] <- sqrt(pmax(diag(state_covariance), 0))
  for (i in seq.int(warmup + 1L, n)) {
    h <- c(x[i, ], 1)
    p_minus <- state_covariance + initialization$q
    theta_minus <- theta
    e <- y[[i]] - sum(h * theta_minus)
    s <- as.numeric(t(h) %*% p_minus %*% h + initialization$r)
    if (!is.finite(s) || s <= 0) g5_kf_stop("Innovation variance is not positive.")
    gain <- as.numeric(p_minus %*% h / s)
    theta <- theta_minus + gain * e
    state_covariance <- (diag(p) - tcrossprod(gain, h)) %*% p_minus
    state_covariance <- (state_covariance + t(state_covariance)) / 2
    prior[i, ] <- theta_minus
    posterior[i, ] <- theta
    prior_sd[i, ] <- sqrt(pmax(diag(p_minus), 0))
    posterior_sd[i, ] <- sqrt(pmax(diag(state_covariance), 0))
    innovation[[i]] <- e
    innovation_variance[[i]] <- s
    z[[i]] <- e / sqrt(s)
  }
  colnames(prior) <- c(paste0("prior_beta_", seq_len(k)), "prior_intercept")
  colnames(posterior) <- c(paste0("posterior_beta_", seq_len(k)), "posterior_intercept")
  colnames(prior_sd) <- paste0(colnames(prior), "_sd")
  colnames(posterior_sd) <- paste0(colnames(posterior), "_sd")
  rolling <- g5_kf_rolling_ols(y, x, contract$rolling_lookback)
  output <- cbind(
    panel,
    as.data.frame(prior),
    as.data.frame(posterior),
    as.data.frame(prior_sd),
    as.data.frame(posterior_sd),
    innovation = innovation,
    innovation_variance = innovation_variance,
    z_score = z,
    rolling
  )
  list(
    rows = output,
    initialization = initialization,
    response = y,
    predictors = x
  )
}

g5_kf_signal_states <- function(rows, contract) {
  state <- integer(nrow(rows))
  action <- rep("hold_flat", nrow(rows))
  previous <- 0L
  first_signal <- contract$warmup_sessions + 1L
  for (i in seq_len(nrow(rows))) {
    current <- previous
    z <- rows$z_score[[i]]
    transition <- if (previous == 0L) "hold_flat" else "hold_position"
    if (i < first_signal || !is.finite(z)) {
      current <- 0L
      transition <- "warmup_or_unavailable"
    } else if (previous == 0L && z < -contract$entry_z) {
      current <- 1L
      transition <- "enter_long_spread"
    } else if (previous == 0L && z > contract$entry_z) {
      current <- -1L
      transition <- "enter_short_spread"
    } else if (previous == 1L && z >= contract$exit_z) {
      current <- 0L
      transition <- "exit_long_spread"
    } else if (previous == -1L && z <= -contract$exit_z) {
      current <- 0L
      transition <- "exit_short_spread"
    }
    state[[i]] <- current
    action[[i]] <- transition
    previous <- current
  }
  rows$target_state <- state
  rows$signal_action <- action
  rows
}

g5_kf_build_replay <- function(rows, contract) {
  k <- length(contract$predictor_symbols)
  legs <- k + 1L
  if (nrow(rows) < 3L) g5_kf_stop("Replay requires at least three sessions.")
  previous_weights <- rep(0, legs)
  previous_state <- 0L
  active_trade <- 0L
  output <- vector("list", nrow(rows) - 2L)
  for (i in seq_len(nrow(rows) - 2L)) {
    signal <- rows[i, , drop = FALSE]
    execution <- rows[i + 1L, , drop = FALSE]
    next_execution <- rows[i + 2L, , drop = FALSE]
    state <- as.integer(signal$target_state)
    slopes <- as.numeric(signal[paste0("posterior_beta_", seq_len(k))])
    share_vector <- c(1, -slopes)
    open_now <- as.numeric(execution[paste0("open_", seq_len(legs))])
    open_next <- as.numeric(next_execution[paste0("open_", seq_len(legs))])
    dollar_vector <- share_vector * open_now
    gross_value <- sum(abs(dollar_vector))
    if (
      state != 0L && all(is.finite(dollar_vector)) &&
        is.finite(gross_value) && gross_value > 0
    ) {
      weights <- state * dollar_vector / gross_value
    } else {
      state <- 0L
      weights <- rep(0, legs)
    }
    if (state != 0L && previous_state == 0L) active_trade <- active_trade + 1L
    trade_id <- if (state != 0L) active_trade else NA_integer_
    is_exit_row <- state == 0L && previous_state != 0L
    if (is_exit_row) trade_id <- active_trade
    turnover <- sum(abs(weights - previous_weights))
    leg_returns <- open_next / open_now - 1
    gross_return <- sum(weights * leg_returns)
    primary_cost <- turnover * contract$primary_cost_bps / 10000
    stress_cost <- turnover * contract$stress_cost_bps / 10000
    short_gross <- sum(abs(pmin(weights, 0)))
    borrow_cost <- short_gross *
      contract$stress_borrow_bps_annual / 10000 / 252
    base <- data.frame(
      schema_version = g5_kf_schema_version(),
      signal_date = signal$session_date,
      execution_date = execution$session_date,
      next_execution_date = next_execution$session_date,
      z_score = signal$z_score,
      signal_action = signal$signal_action,
      target_state = state,
      trade_id = trade_id,
      is_exit_row = is_exit_row,
      gross_exposure = sum(abs(weights)),
      net_exposure = sum(weights),
      short_gross = short_gross,
      turnover = turnover,
      response_return = leg_returns[[1L]],
      gross_return = gross_return,
      primary_cost = primary_cost,
      stress_cost = stress_cost,
      borrow_cost = borrow_cost,
      primary_net_return = gross_return - primary_cost,
      stress_net_return = gross_return - stress_cost - borrow_cost,
      stringsAsFactors = FALSE
    )
    for (j in seq_len(legs)) {
      base[[paste0("symbol_", j)]] <- contract$symbols[[j]]
      base[[paste0("weight_", j)]] <- weights[[j]]
      base[[paste0("share_coefficient_", j)]] <- share_vector[[j]]
    }
    output[[i]] <- base
    previous_weights <- weights
    previous_state <- state
  }
  do.call(rbind, output)
}

g5_kf_trade_summary <- function(replay) {
  ids <- sort(unique(replay$trade_id[!is.na(replay$trade_id)]))
  rows <- lapply(ids, function(id) {
    x <- replay[!is.na(replay$trade_id) & replay$trade_id == id, , drop = FALSE]
    active <- x[x$target_state != 0L, , drop = FALSE]
    completed <- any(x$is_exit_row)
    direction <- if (nrow(active)) active$target_state[[1L]] else NA_integer_
    data.frame(
      trade_id = id,
      entry_date = if (nrow(active)) min(active$execution_date) else as.Date(NA),
      exit_date = if (completed) max(x$execution_date[x$is_exit_row]) else as.Date(NA),
      direction = direction,
      direction_label = ifelse(direction == 1L, "LONG_SPREAD", "SHORT_SPREAD"),
      holding_bars = nrow(active),
      completed = completed,
      gross_additive_return = sum(x$gross_return),
      primary_cost_additive = sum(x$primary_cost),
      stress_cost_additive = sum(x$stress_cost + x$borrow_cost),
      primary_net_additive_return = sum(x$primary_net_return),
      stress_net_additive_return = sum(x$stress_net_return),
      primary_compound_return = prod(1 + x$primary_net_return) - 1,
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) {
    return(data.frame(
      trade_id = integer(), entry_date = as.Date(character()),
      exit_date = as.Date(character()), direction = integer(),
      direction_label = character(), holding_bars = integer(),
      completed = logical(), gross_additive_return = numeric(),
      primary_cost_additive = numeric(), stress_cost_additive = numeric(),
      primary_net_additive_return = numeric(),
      stress_net_additive_return = numeric(),
      primary_compound_return = numeric()
    ))
  }
  do.call(rbind, rows)
}

g5_kf_block_indices <- function(n, block_length) {
  if (n <= 0L) return(integer())
  block_length <- min(as.integer(block_length), n)
  starts <- sample.int(n, ceiling(n / block_length), replace = TRUE)
  unlist(lapply(starts, function(start) {
    ((start - 1L + seq_len(block_length) - 1L) %% n) + 1L
  }), use.names = FALSE)[seq_len(n)]
}

g5_kf_trade_bootstrap <- function(trades, contract) {
  x <- trades[trades$completed, , drop = FALSE]
  set.seed(contract$trade_bootstrap_seed)
  draws <- rep(NA_real_, contract$bootstrap_count)
  if (nrow(x)) {
    for (i in seq_along(draws)) {
      idx <- g5_kf_block_indices(nrow(x), contract$bootstrap_block_trades)
      draws[[i]] <- mean(x$primary_net_additive_return[idx])
    }
  }
  finite <- draws[is.finite(draws)]
  interval <- if (length(finite)) {
    stats::quantile(finite, c(0.05, 0.95), names = FALSE)
  } else c(NA_real_, NA_real_)
  list(
    estimate = if (nrow(x)) mean(x$primary_net_additive_return) else NA_real_,
    lower_90 = interval[[1L]],
    upper_90 = interval[[2L]],
    draws = draws
  )
}

g5_kf_random_sign_control <- function(trades, contract) {
  x <- trades[trades$completed, , drop = FALSE]
  set.seed(contract$random_sign_seed)
  draws <- rep(NA_real_, contract$random_sign_count)
  if (nrow(x)) {
    for (i in seq_along(draws)) {
      multiplier <- sample(c(-1, 1), nrow(x), replace = TRUE)
      randomized <- multiplier * x$direction * x$gross_additive_return -
        x$primary_cost_additive
      draws[[i]] <- mean(randomized)
    }
  }
  finite <- draws[is.finite(draws)]
  list(
    observed = if (nrow(x)) mean(x$primary_net_additive_return) else NA_real_,
    random_p90 = if (length(finite)) {
      as.numeric(stats::quantile(finite, 0.90, names = FALSE))
    } else NA_real_,
    draws = draws
  )
}

g5_kf_forward_convergence <- function(rows, contract) {
  k <- length(contract$predictor_symbols)
  legs <- k + 1L
  horizon <- contract$convergence_horizon
  output <- list()
  if (nrow(rows) <= horizon + 2L) return(data.frame())
  for (i in seq_len(nrow(rows) - horizon - 1L)) {
    z <- rows$z_score[[i]]
    slopes <- as.numeric(rows[i, paste0("posterior_beta_", seq_len(k))])
    if (!is.finite(z) || any(!is.finite(slopes))) next
    entry <- as.numeric(rows[i + 1L, paste0("open_", seq_len(legs))])
    exit <- as.numeric(rows[i + 1L + horizon, paste0("open_", seq_len(legs))])
    share_vector <- c(1, -slopes)
    dollar <- share_vector * entry
    if (!all(is.finite(dollar)) || sum(abs(dollar)) <= 0) next
    weights <- dollar / sum(abs(dollar))
    output[[length(output) + 1L]] <- data.frame(
      signal_date = rows$session_date[[i]],
      z_score = z,
      forward_5_session_return = sum(weights * (exit / entry - 1)),
      stringsAsFactors = FALSE
    )
  }
  if (!length(output)) return(data.frame())
  do.call(rbind, output)
}

g5_kf_convergence_bootstrap <- function(convergence, contract) {
  x <- convergence[
    is.finite(convergence$z_score) &
      is.finite(convergence$forward_5_session_return),
    ,
    drop = FALSE
  ]
  estimate <- if (nrow(x) >= 3L) {
    stats::cor(x$z_score, x$forward_5_session_return)
  } else NA_real_
  set.seed(contract$convergence_bootstrap_seed)
  draws <- rep(NA_real_, contract$bootstrap_count)
  if (nrow(x) >= 3L) {
    for (i in seq_along(draws)) {
      idx <- g5_kf_block_indices(nrow(x), contract$convergence_block_sessions)
      draws[[i]] <- suppressWarnings(stats::cor(
        x$z_score[idx], x$forward_5_session_return[idx]
      ))
    }
  }
  finite <- draws[is.finite(draws)]
  interval <- if (length(finite)) {
    stats::quantile(finite, c(0.05, 0.95), names = FALSE)
  } else c(NA_real_, NA_real_)
  list(
    estimate = estimate,
    lower_90 = interval[[1L]],
    upper_90 = interval[[2L]],
    observations = nrow(x),
    draws = draws
  )
}

g5_kf_long_run_variance <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 2L) return(NA_real_)
  centered <- x - mean(x)
  lag_max <- max(1L, floor(4 * (n / 100)^(2 / 9)))
  value <- sum(centered^2) / n
  for (lag in seq_len(min(lag_max, n - 1L))) {
    weight <- 1 - lag / (lag_max + 1)
    covariance <- sum(
      centered[(lag + 1L):n] * centered[seq_len(n - lag)]
    ) / n
    value <- value + 2 * weight * covariance
  }
  value
}

g5_kf_performance_metrics <- function(replay) {
  returns <- replay$primary_net_return
  equity <- cumprod(1 + returns)
  peak <- cummax(c(1, equity))[-1L]
  drawdown <- equity / peak - 1
  lrv <- g5_kf_long_run_variance(returns)
  active <- replay$target_state != 0L
  data.frame(
    bars = nrow(replay),
    cumulative_return = tail(equity, 1L) - 1,
    stress_cumulative_return = prod(1 + replay$stress_net_return) - 1,
    naive_sharpe = if (stats::sd(returns) > 0) {
      sqrt(252) * mean(returns) / stats::sd(returns)
    } else NA_real_,
    autocorrelation_adjusted_sharpe = if (is.finite(lrv) && lrv > 0) {
      sqrt(252) * mean(returns) / sqrt(lrv)
    } else NA_real_,
    maximum_drawdown = min(drawdown),
    average_gross_exposure = mean(replay$gross_exposure),
    total_turnover = sum(replay$turnover),
    spread_direction_hit_rate = if (any(active)) {
      mean(replay$gross_return[active] > 0)
    } else NA_real_,
    response_up_down_accuracy = if (any(active)) {
      mean(sign(replay$target_state[active]) == sign(replay$response_return[active]))
    } else NA_real_,
    stringsAsFactors = FALSE
  )
}

g5_kf_calibration_metrics <- function(rows, contract) {
  idx <- seq.int(contract$warmup_sessions + 1L, nrow(rows))
  kalman <- rows$z_score[idx]
  rolling <- rows$rolling_z[idx]
  lag_one <- function(x) {
    x <- x[is.finite(x)]
    if (length(x) < 3L) NA_real_ else stats::cor(x[-length(x)], x[-1L])
  }
  metrics <- function(label, residual, standardized) {
    valid <- is.finite(residual) & is.finite(standardized)
    data.frame(
      estimator = label,
      observations = sum(valid),
      rmse = sqrt(mean(residual[valid]^2)),
      mean_absolute_error = mean(abs(residual[valid])),
      z_mean = mean(standardized[valid]),
      z_sd = stats::sd(standardized[valid]),
      z_lag_1 = lag_one(standardized[valid]),
      abs_z_above_1_rate = mean(abs(standardized[valid]) > 1),
      stringsAsFactors = FALSE
    )
  }
  rbind(
    metrics("Kalman", rows$innovation[idx], kalman),
    metrics("Rolling OLS 20", rows$rolling_innovation[idx], rolling)
  )
}

g5_kf_coefficient_metrics <- function(rows, contract) {
  k <- length(contract$predictor_symbols)
  idx <- seq.int(contract$warmup_sessions + 1L, nrow(rows))
  do.call(rbind, lapply(seq_len(k), function(j) {
    kalman <- rows[[paste0("posterior_beta_", j)]][idx]
    rolling <- rows[[paste0("rolling_beta_", j)]][idx]
    data.frame(
      predictor = contract$predictor_symbols[[j]],
      kalman_start = kalman[which(is.finite(kalman))[[1L]]],
      kalman_end = tail(kalman[is.finite(kalman)], 1L),
      kalman_mean_abs_daily_change = mean(abs(diff(kalman)), na.rm = TRUE),
      rolling_mean_abs_daily_change = mean(abs(diff(rolling)), na.rm = TRUE),
      kalman_rolling_correlation = stats::cor(
        kalman, rolling, use = "complete.obs"
      ),
      stringsAsFactors = FALSE
    )
  }))
}

g5_kf_integrity <- function(bars, panel, rows, replay, contract, health_status) {
  reference <- sort(unique(bars$session_date))
  coverage <- vapply(contract$symbols, function(symbol) {
    identical(
      sort(unique(bars$session_date[bars$symbol == symbol])),
      reference
    )
  }, logical(1))
  active <- replay$target_state != 0L
  warmup_active <- rows$target_state[seq_len(contract$warmup_sessions)] != 0L
  checks <- c(
    identical(health_status, "PASS"),
    !anyDuplicated(bars[c("symbol", "session_date")]),
    setequal(unique(bars$symbol), contract$symbols),
    all(coverage),
    max(bars$session_date) <= contract$query_end,
    all(panel$session_date == sort(panel$session_date)),
    !any(warmup_active),
    all(replay$signal_date < replay$execution_date),
    all(replay$execution_date < replay$next_execution_date),
    all(replay$target_state %in% c(-1L, 0L, 1L)),
    all(abs(replay$gross_exposure[active] - 1) < 1e-10),
    all(replay$turnover >= 0 & replay$primary_cost >= 0),
    max(replay$next_execution_date) <= contract$query_end
  )
  data.frame(
    check_id = sprintf("I%02d", seq_along(checks)),
    check = c(
      "Data health permits analysis",
      "No duplicate symbol-session bars",
      "Exact frozen universe",
      "All legs have identical sessions",
      "Query respects explicit end",
      "Panel chronology is increasing",
      "Warm-up contains no positions",
      "Signals precede execution",
      "Returns end after execution open",
      "State is bounded",
      "Active gross exposure is one",
      "Turnover and costs are nonnegative",
      "Replay respects sealed end"
    ),
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

g5_kf_gate_detail <- function(
  rows,
  replay,
  trades,
  integrity,
  trade_bootstrap,
  random_control,
  convergence_bootstrap,
  contract
) {
  idx <- seq.int(contract$warmup_sessions + 1L, nrow(rows))
  state_columns <- c(
    paste0("posterior_beta_", seq_along(contract$predictor_symbols)),
    "posterior_intercept", "innovation", "innovation_variance", "z_score"
  )
  finite_filter_rate <- mean(apply(
    as.matrix(rows[idx, state_columns, drop = FALSE]),
    1,
    function(x) all(is.finite(x)) && x[[length(x) - 1L]] > 0
  ))
  if (length(contract$predictor_symbols) == 1L) {
    semantic_rate <- mean(rows$posterior_beta_1[idx] > 0, na.rm = TRUE)
    semantic_label <- "Positive pair slope coverage >= 95%"
  } else {
    semantics <- vapply(idx, function(i) {
      slopes <- as.numeric(rows[i, paste0(
        "posterior_beta_", seq_along(contract$predictor_symbols)
      )])
      share <- c(1, -slopes)
      all(is.finite(share)) && any(share > 0) && any(share < 0)
    }, logical(1))
    semantic_rate <- mean(semantics)
    semantic_label <- "Mixed-sign triplet coverage >= 95%"
  }
  completed <- trades[trades$completed, , drop = FALSE]
  long_count <- sum(completed$direction == 1L)
  short_count <- sum(completed$direction == -1L)
  mean_return <- if (nrow(completed)) {
    mean(completed$primary_net_additive_return)
  } else NA_real_
  values <- c(
    all(integrity$status == "PASS"),
    finite_filter_rate >= 0.95,
    semantic_rate >= 0.95,
    nrow(completed) >= contract$minimum_trades &&
      long_count >= contract$minimum_direction_trades &&
      short_count >= contract$minimum_direction_trades,
    is.finite(mean_return) && mean_return > 0,
    is.finite(trade_bootstrap$lower_90) && trade_bootstrap$lower_90 > 0,
    is.finite(random_control$observed) &&
      is.finite(random_control$random_p90) &&
      random_control$observed > random_control$random_p90,
    is.finite(convergence_bootstrap$estimate) &&
      convergence_bootstrap$estimate < 0 &&
      is.finite(convergence_bootstrap$upper_90) &&
      convergence_bootstrap$upper_90 < 0
  )
  diagnostics <- c(
    paste0(sum(integrity$status == "PASS"), "/", nrow(integrity), " checks"),
    sprintf("%.1f%%", 100 * finite_filter_rate),
    sprintf("%.1f%%", 100 * semantic_rate),
    paste0(nrow(completed), " total; ", long_count, " long; ", short_count, " short"),
    sprintf("%.2f bp/trade", 10000 * mean_return),
    sprintf("%.2f bp", 10000 * trade_bootstrap$lower_90),
    sprintf(
      "observed %.2f bp vs random p90 %.2f bp",
      10000 * random_control$observed,
      10000 * random_control$random_p90
    ),
    sprintf(
      "corr %.4f; upper90 %.4f",
      convergence_bootstrap$estimate,
      convergence_bootstrap$upper_90
    )
  )
  data.frame(
    gate_id = seq_len(8L),
    gate = c(
      "Integrity and causality",
      "Finite filter coverage >= 95%",
      semantic_label,
      "At least 24 completed, 8 each direction",
      "Positive primary-cost mean trade return",
      "90% bootstrap lower bound > 0",
      "Observed mean > random-sign p90",
      "Forward convergence corr and upper90 < 0"
    ),
    diagnostic = diagnostics,
    status = ifelse(values, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

g5_kf_run_train <- function(bars, contract, data_health_status = "PASS") {
  contract$query_end <- contract$train_end
  validated <- g5_kf_validate_bars(bars, contract$symbols, contract$query_end)
  panel <- g5_kf_common_panel(validated, contract$symbols, contract$query_end)
  filter <- g5_kf_filter(panel, contract)
  rows <- g5_kf_signal_states(filter$rows, contract)
  replay <- g5_kf_build_replay(rows, contract)
  trades <- g5_kf_trade_summary(replay)
  convergence <- g5_kf_forward_convergence(rows, contract)
  trade_bootstrap <- g5_kf_trade_bootstrap(trades, contract)
  random_control <- g5_kf_random_sign_control(trades, contract)
  convergence_bootstrap <- g5_kf_convergence_bootstrap(convergence, contract)
  integrity <- g5_kf_integrity(
    validated, panel, rows, replay, contract, data_health_status
  )
  gates <- g5_kf_gate_detail(
    rows, replay, trades, integrity, trade_bootstrap, random_control,
    convergence_bootstrap, contract
  )
  performance <- g5_kf_performance_metrics(replay)
  calibration <- g5_kf_calibration_metrics(rows, contract)
  coefficients <- g5_kf_coefficient_metrics(rows, contract)
  structural_pass <- all(gates$status[1:3] == "PASS")
  full_pass <- all(gates$status == "PASS")
  status <- if (!structural_pass) {
    paste0("STOP_", gsub("[.-]", "_", contract$literature_id), "_FILTER_STRUCTURE")
  } else if (!full_pass) {
    paste0("STOP_", gsub("[.-]", "_", contract$literature_id), "_TRAIN_STRATEGY")
  } else {
    paste0("TRAIN_PASS_", gsub("[.-]", "_", contract$literature_id))
  }
  list(
    contract = contract,
    panel = panel,
    filter = filter,
    rows = rows,
    replay = replay,
    trades = trades,
    convergence = convergence,
    trade_bootstrap = trade_bootstrap,
    random_control = random_control,
    convergence_bootstrap = convergence_bootstrap,
    integrity = integrity,
    gates = gates,
    performance = performance,
    calibration = calibration,
    coefficients = coefficients,
    structural_pass = structural_pass,
    full_pass = full_pass,
    status = status
  )
}

g5_kf_run_development <- function(bars, contract, data_health_status = "PASS") {
  contract$query_end <- contract$development_end
  validated <- g5_kf_validate_bars(bars, contract$symbols, contract$query_end)
  panel <- g5_kf_common_panel(validated, contract$symbols, contract$query_end)
  filter <- g5_kf_filter(panel, contract)
  rows <- g5_kf_signal_states(filter$rows, contract)
  replay_all <- g5_kf_build_replay(rows, contract)
  replay <- replay_all[
    replay_all$execution_date >= contract$development_start &
      replay_all$execution_date <= contract$development_end,
    ,
    drop = FALSE
  ]
  trades <- g5_kf_trade_summary(replay)
  convergence_all <- g5_kf_forward_convergence(rows, contract)
  convergence <- convergence_all[
    convergence_all$signal_date >= contract$development_start &
      convergence_all$signal_date <= contract$development_end,
    ,
    drop = FALSE
  ]
  performance <- g5_kf_performance_metrics(replay)
  completed <- trades[trades$completed, , drop = FALSE]
  summary <- data.frame(
    literature_id = contract$literature_id,
    bars = nrow(replay),
    completed_trades = nrow(completed),
    long_trades = sum(completed$direction == 1L),
    short_trades = sum(completed$direction == -1L),
    mean_primary_net_trade_return = if (nrow(completed)) {
      mean(completed$primary_net_additive_return)
    } else NA_real_,
    trade_hit_rate = if (nrow(completed)) {
      mean(completed$primary_net_additive_return > 0)
    } else NA_real_,
    forward_convergence_correlation = if (nrow(convergence) >= 3L) {
      stats::cor(
        convergence$z_score,
        convergence$forward_5_session_return,
        use = "complete.obs"
      )
    } else NA_real_,
    performance,
    stringsAsFactors = FALSE
  )
  list(
    rows = rows,
    replay = replay,
    trades = trades,
    convergence = convergence,
    performance = performance,
    summary = summary,
    data_health_status = data_health_status
  )
}
