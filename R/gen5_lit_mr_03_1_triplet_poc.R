g5_mr03_schema_version <- function() {
  "gen5_lit_mr_03_1_v1"
}

g5_mr03_stop <- function(message) {
  stop(paste0("[Gen5 LIT-MR-03.1] ", message), call. = FALSE)
}

g5_mr03_contract <- function() {
  list(
    literature_id = "LIT-MR-03.1",
    as_of_timestamp = "2026-07-24 17:30:00",
    train_start = as.Date("2016-01-04"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-01"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-01"),
    lookback_sessions = 20L,
    entry_z = 1,
    exit_z = 0,
    johansen_lag = 1L,
    johansen_bootstrap_count = 1000L,
    trade_bootstrap_count = 2000L,
    convergence_bootstrap_count = 2000L,
    bootstrap_block_trades = 4L,
    convergence_block_sessions = 20L,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    stress_borrow_bps_annual = 100,
    adf_threshold = -3,
    minimum_vector_cosine = 0.85,
    minimum_half_life = 2,
    maximum_half_life = 60,
    minimum_completed_trades = 30L,
    minimum_trades_each_direction = 10L
  )
}

g5_mr03_validate_contract <- function(contract = g5_mr03_contract()) {
  required <- names(g5_mr03_contract())
  missing <- setdiff(required, names(contract))
  if (length(missing)) {
    g5_mr03_stop(paste("Contract is missing:", paste(missing, collapse = ", ")))
  }
  if (!identical(contract$literature_id, "LIT-MR-03.1")) {
    g5_mr03_stop("The literature identifier cannot change.")
  }
  if (!identical(as.integer(contract$lookback_sessions), 20L) ||
      !isTRUE(all.equal(contract$entry_z, 1)) ||
      !isTRUE(all.equal(contract$exit_z, 0))) {
    g5_mr03_stop("The frozen 20-session, +/-1 entry, zero-exit rule changed.")
  }
  if (!identical(as.integer(contract$johansen_lag), 1L) ||
      !identical(as.integer(contract$johansen_bootstrap_count), 1000L)) {
    g5_mr03_stop("The frozen Johansen specification changed.")
  }
  dates <- c(
    contract$train_start, contract$train_end, contract$development_start,
    contract$development_end, contract$confirmation_start
  )
  if (any(is.na(dates)) ||
      !(contract$train_end < contract$development_start) ||
      !(contract$development_end < contract$confirmation_start)) {
    g5_mr03_stop("Contract partitions must be explicit, ordered, and disjoint.")
  }
  contract
}

g5_mr03_registry <- function() {
  data.frame(
    triplet_index = 1L:8L,
    triplet_id = c(
      "T01_EWA_EWC_IGE", "T02_GLD_GDX_USO", "T03_SPY_IVV_VOO",
      "T04_SHY_IEF_TLT", "T05_XLE_XOP_USO", "T06_GLD_SLV_GDX",
      "T07_QQQ_XLK_SMH", "T08_XLF_JPM_BAC"
    ),
    symbol_1 = c("EWA", "GLD", "SPY", "SHY", "XLE", "GLD", "QQQ", "XLF"),
    symbol_2 = c("EWC", "GDX", "IVV", "IEF", "XOP", "SLV", "XLK", "JPM"),
    symbol_3 = c("IGE", "USO", "VOO", "TLT", "USO", "GDX", "SMH", "BAC"),
    triplet_category = c(
      "literature_anchor", "literature_anchor", "duplicate_claim",
      "treasury_curve", "energy_complex", "precious_metals_complex",
      "technology_factor", "basket_components"
    ),
    rationale = c(
      "Chan country and commodity-sensitive triplet",
      "Chan omitted-common-factor illustration",
      "Three implementations of the S&P 500 claim",
      "Short, intermediate, and long-duration Treasuries",
      "Broad energy, producers, and oil-futures proxy",
      "Gold, silver, and gold-miner equities",
      "Growth, broad technology, and semiconductors",
      "Financial basket and two large bank components"
    ),
    stringsAsFactors = FALSE
  )
}

g5_mr03_validate_registry <- function(registry = g5_mr03_registry()) {
  required <- names(g5_mr03_registry())
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mr03_stop(paste("Registry is missing:", paste(missing, collapse = ", ")))
  }
  frozen <- g5_mr03_registry()
  if (!identical(registry[, required], frozen[, required])) {
    g5_mr03_stop("The frozen triplet registry changed.")
  }
  registry
}

g5_mr03_required_symbols <- function(registry = g5_mr03_registry()) {
  registry <- g5_mr03_validate_registry(registry)
  sort(unique(unlist(registry[c("symbol_1", "symbol_2", "symbol_3")])))
}

g5_mr03_validate_bars <- function(
  bars,
  symbols,
  query_end = g5_mr03_contract()$train_end
) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_mr03_stop(paste("Bars are missing:", paste(missing, collapse = ", ")))
  }
  symbols <- toupper(as.character(symbols))
  if (length(symbols) != 3L || anyDuplicated(symbols)) {
    g5_mr03_stop("Exactly three distinct symbols are required.")
  }
  bars <- bars[bars$symbol %in% symbols, required, drop = FALSE]
  bars$session_date <- as.Date(bars$session_date)
  if (!setequal(unique(bars$symbol), symbols)) {
    g5_mr03_stop("Exact triplet symbol coverage failed.")
  }
  if (anyDuplicated(bars[c("symbol", "session_date")])) {
    g5_mr03_stop("Duplicate symbol-session bars are prohibited.")
  }
  if (any(is.na(bars$session_date)) || any(bars$session_date > query_end)) {
    g5_mr03_stop("Bars violate the explicit date boundary.")
  }
  numeric_columns <- c("open", "high", "low", "close", "volume")
  if (any(!vapply(bars[numeric_columns], is.numeric, logical(1)))) {
    g5_mr03_stop("OHLCV columns must be numeric.")
  }
  prices <- as.matrix(bars[c("open", "high", "low", "close")])
  if (any(!is.finite(prices)) || any(prices <= 0)) {
    g5_mr03_stop("Prices must be finite and positive.")
  }
  bars[order(bars$session_date, bars$symbol), , drop = FALSE]
}

g5_mr03_common_panel <- function(bars, symbols, query_end) {
  bars <- g5_mr03_validate_bars(bars, symbols, query_end)
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
  if (nrow(panel) < 250L) {
    g5_mr03_stop("Too few common triplet sessions.")
  }
  panel
}

g5_mr03_adf_t <- function(series) {
  x <- as.numeric(series[is.finite(series)])
  if (length(x) < 10L) return(NA_real_)
  n <- length(x)
  dy <- x[3:n] - x[2:(n - 1L)]
  lag_level <- x[2:(n - 1L)]
  lag_delta <- x[2:(n - 1L)] - x[1:(n - 2L)]
  fit <- tryCatch(
    stats::lm(dy ~ 0 + lag_level + lag_delta),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NA_real_)
  coefs <- summary(fit)$coefficients
  if (!"lag_level" %in% rownames(coefs)) return(NA_real_)
  unname(coefs["lag_level", "t value"])
}

g5_mr03_regularized_solve <- function(matrix, rhs = NULL) {
  ridge <- max(1e-10, mean(diag(matrix)) * 1e-10)
  adjusted <- matrix + diag(ridge, nrow(matrix))
  if (is.null(rhs)) solve(adjusted) else solve(adjusted, rhs)
}

g5_mr03_orient_vector <- function(vector) {
  vector <- as.numeric(Re(vector))
  if (length(vector) != 3L || any(!is.finite(vector)) ||
      abs(vector[[1L]]) < 1e-10) {
    return(rep(NA_real_, 3L))
  }
  vector <- vector / vector[[1L]]
  if (vector[[1L]] < 0) vector <- -vector
  vector
}

g5_mr03_johansen_fit <- function(price_matrix) {
  x <- as.matrix(price_matrix)
  storage.mode(x) <- "double"
  if (ncol(x) != 3L || nrow(x) < 100L || any(!is.finite(x))) {
    g5_mr03_stop("Johansen estimation requires a finite T-by-3 price matrix.")
  }
  delta <- x[-1L, , drop = FALSE] - x[-nrow(x), , drop = FALSE]
  lagged <- x[-nrow(x), , drop = FALSE]
  deterministic <- matrix(1, nrow(delta), 1L)
  r0 <- stats::lm.fit(deterministic, delta)$residuals
  r1 <- stats::lm.fit(deterministic, lagged)$residuals
  n <- nrow(r0)
  s00 <- crossprod(r0) / n
  s11 <- crossprod(r1) / n
  s01 <- crossprod(r0, r1) / n
  s10 <- t(s01)
  eigen_matrix <- g5_mr03_regularized_solve(
    s11,
    s10 %*% g5_mr03_regularized_solve(s00, s01)
  )
  eig <- eigen(eigen_matrix)
  order_index <- order(Re(eig$values), decreasing = TRUE)
  values <- pmin(pmax(Re(eig$values[order_index]), 0), 1 - 1e-10)
  vectors <- Re(eig$vectors[, order_index, drop = FALSE])
  beta <- g5_mr03_orient_vector(vectors[, 1L])
  trace <- c(
    rank_0 = -n * sum(log1p(-values)),
    rank_at_most_1 = -n * sum(log1p(-values[2:3]))
  )
  list(
    observations = n,
    eigenvalues = values,
    eigenvectors = vectors,
    beta = beta,
    trace_statistics = trace,
    delta_mean = colMeans(delta),
    delta_covariance = stats::cov(delta),
    level_start = as.numeric(x[1L, ])
  )
}

g5_mr03_random_innovations <- function(n, covariance) {
  covariance <- as.matrix(covariance)
  ridge <- max(1e-10, mean(diag(covariance)) * 1e-10)
  root <- chol(covariance + diag(ridge, nrow(covariance)))
  matrix(stats::rnorm(n * ncol(covariance)), nrow = n) %*% root
}

g5_mr03_simulate_rank0 <- function(fit, n) {
  innovations <- g5_mr03_random_innovations(n - 1L, fit$delta_covariance)
  delta <- sweep(innovations, 2, fit$delta_mean, "+")
  rbind(fit$level_start, sweep(apply(delta, 2, cumsum), 2, fit$level_start, "+"))
}

g5_mr03_rank1_parameters <- function(price_matrix, beta) {
  x <- as.matrix(price_matrix)
  delta <- x[-1L, , drop = FALSE] - x[-nrow(x), , drop = FALSE]
  ec <- as.numeric(x[-nrow(x), , drop = FALSE] %*% beta)
  design <- cbind(1, ec)
  fit <- stats::lm.fit(design, delta)
  coefficients <- fit$coefficients
  list(
    intercept = coefficients[1L, ],
    alpha = coefficients[2L, ],
    covariance = stats::cov(fit$residuals)
  )
}

g5_mr03_simulate_rank1 <- function(fit, price_matrix, n) {
  params <- g5_mr03_rank1_parameters(price_matrix, fit$beta)
  innovations <- g5_mr03_random_innovations(n - 1L, params$covariance)
  simulated <- matrix(NA_real_, nrow = n, ncol = 3L)
  simulated[1L, ] <- fit$level_start
  for (i in 2:n) {
    ec <- sum(fit$beta * simulated[i - 1L, ])
    delta <- params$intercept + params$alpha * ec + innovations[i - 1L, ]
    simulated[i, ] <- simulated[i - 1L, ] + delta
  }
  simulated
}

g5_mr03_johansen_bootstrap <- function(
  price_matrix,
  fit,
  triplet_index,
  contract = g5_mr03_contract()
) {
  contract <- g5_mr03_validate_contract(contract)
  draws <- contract$johansen_bootstrap_count
  rank0 <- rep(NA_real_, draws)
  rank1 <- rep(NA_real_, draws)
  set.seed(7300L + as.integer(triplet_index))
  for (i in seq_len(draws)) {
    simulated0 <- g5_mr03_simulate_rank0(fit, nrow(price_matrix))
    simulated1 <- g5_mr03_simulate_rank1(fit, price_matrix, nrow(price_matrix))
    rank0[[i]] <- tryCatch(
      g5_mr03_johansen_fit(simulated0)$trace_statistics[["rank_0"]],
      error = function(e) NA_real_
    )
    rank1[[i]] <- tryCatch(
      g5_mr03_johansen_fit(simulated1)$trace_statistics[["rank_at_most_1"]],
      error = function(e) NA_real_
    )
  }
  finite0 <- rank0[is.finite(rank0)]
  finite1 <- rank1[is.finite(rank1)]
  p0 <- if (length(finite0)) {
    (1 + sum(finite0 >= fit$trace_statistics[["rank_0"]])) /
      (1 + length(finite0))
  } else {
    NA_real_
  }
  p1 <- if (length(finite1)) {
    (1 + sum(finite1 >= fit$trace_statistics[["rank_at_most_1"]])) /
      (1 + length(finite1))
  } else {
    NA_real_
  }
  list(
    summary = data.frame(
      trace_rank_0 = fit$trace_statistics[["rank_0"]],
      p_rank_0 = p0,
      trace_rank_at_most_1 = fit$trace_statistics[["rank_at_most_1"]],
      p_rank_at_most_1 = p1,
      rank_one = is.finite(p0) && is.finite(p1) && p0 < 0.05 && p1 >= 0.05,
      draws_rank_0 = length(finite0),
      draws_rank_1 = length(finite1),
      seed = 7300L + as.integer(triplet_index),
      stringsAsFactors = FALSE
    ),
    draws = data.frame(rank_0_trace = rank0, rank_at_most_1_trace = rank1)
  )
}

g5_mr03_vector_stability <- function(price_matrix) {
  n <- nrow(price_matrix)
  split <- floor(n / 2)
  first <- g5_mr03_johansen_fit(price_matrix[seq_len(split), , drop = FALSE])$beta
  second <- g5_mr03_johansen_fit(
    price_matrix[(split + 1L):n, , drop = FALSE]
  )$beta
  prices <- price_matrix[n, ]
  exposure_first <- first * prices
  exposure_second <- second * prices
  cosine <- sum(exposure_first * exposure_second) /
    sqrt(sum(exposure_first^2) * sum(exposure_second^2))
  list(first_beta = first, second_beta = second, cosine = abs(cosine))
}

g5_mr03_half_life <- function(series) {
  x <- as.numeric(series[is.finite(series)])
  if (length(x) < 3L) return(c(phi = NA_real_, half_life = NA_real_))
  fit <- stats::lm(x[-1L] ~ x[-length(x)])
  phi <- unname(stats::coef(fit)[[2L]])
  half_life <- if (is.finite(phi) && phi > 0 && phi < 1) {
    log(0.5) / log(phi)
  } else {
    NA_real_
  }
  c(phi = phi, half_life = half_life)
}

g5_mr03_period <- function(date, contract = g5_mr03_contract()) {
  date <- as.Date(date)
  ifelse(
    date >= contract$train_start & date <= contract$train_end,
    "TRAIN",
    ifelse(
      date >= contract$development_start & date <= contract$development_end,
      "DEVELOPMENT",
      ifelse(date >= contract$confirmation_start, "CONFIRMATION", "WARMUP")
    )
  )
}

g5_mr03_indicators <- function(panel, beta, contract = g5_mr03_contract()) {
  beta <- as.numeric(beta)
  close_matrix <- as.matrix(panel[paste0("close_", 1:3)])
  spread <- as.numeric(close_matrix %*% beta)
  n <- length(spread)
  mean20 <- rep(NA_real_, n)
  sd20 <- rep(NA_real_, n)
  z <- rep(NA_real_, n)
  lookback <- contract$lookback_sessions
  for (i in seq_len(n)) {
    if (i < lookback) next
    window <- spread[(i - lookback + 1L):i]
    mean20[[i]] <- mean(window)
    sd20[[i]] <- stats::sd(window)
    if (is.finite(sd20[[i]]) && sd20[[i]] > 0) {
      z[[i]] <- (spread[[i]] - mean20[[i]]) / sd20[[i]]
    }
  }
  cbind(
    panel,
    spread = spread,
    spread_mean_20 = mean20,
    spread_sd_20 = sd20,
    z_score = z
  )
}

g5_mr03_signal_states <- function(indicators, contract = g5_mr03_contract()) {
  state <- integer(nrow(indicators))
  action <- rep("hold_flat", nrow(indicators))
  previous <- 0L
  for (i in seq_len(nrow(indicators))) {
    z <- indicators$z_score[[i]]
    current <- previous
    transition <- if (previous == 0L) "hold_flat" else "hold_position"
    if (!is.finite(z)) {
      current <- 0L
      transition <- "not_eligible"
    } else if (previous == 0L && z < -contract$entry_z) {
      current <- 1L
      transition <- "enter_long_triplet"
    } else if (previous == 0L && z > contract$entry_z) {
      current <- -1L
      transition <- "enter_short_triplet"
    } else if (previous == 1L && z >= contract$exit_z) {
      current <- 0L
      transition <- "exit_long_triplet"
    } else if (previous == -1L && z <= -contract$exit_z) {
      current <- 0L
      transition <- "exit_short_triplet"
    }
    state[[i]] <- current
    action[[i]] <- transition
    previous <- current
  }
  indicators$target_state <- state
  indicators$signal_action <- action
  indicators
}

g5_mr03_build_replay <- function(
  indicators,
  beta,
  symbols,
  contract = g5_mr03_contract()
) {
  if (nrow(indicators) < 3L) g5_mr03_stop("Replay requires three sessions.")
  beta <- as.numeric(beta)
  previous_weights <- rep(0, 3L)
  previous_state <- 0L
  active_trade <- 0L
  rows <- vector("list", nrow(indicators) - 2L)
  for (i in seq_len(nrow(indicators) - 2L)) {
    signal <- indicators[i, , drop = FALSE]
    execution <- indicators[i + 1L, , drop = FALSE]
    next_execution <- indicators[i + 2L, , drop = FALSE]
    state <- as.integer(signal$target_state)
    open_now <- as.numeric(execution[paste0("open_", 1:3)])
    open_next <- as.numeric(next_execution[paste0("open_", 1:3)])
    dollar_vector <- beta * open_now
    gross_value <- sum(abs(dollar_vector))
    if (state != 0L && is.finite(gross_value) && gross_value > 0) {
      weights <- state * dollar_vector / gross_value
    } else {
      state <- 0L
      weights <- rep(0, 3L)
    }
    if (state != 0L && previous_state == 0L) active_trade <- active_trade + 1L
    trade_id <- if (state != 0L) active_trade else NA_integer_
    is_exit_row <- state == 0L && previous_state != 0L
    if (is_exit_row) trade_id <- active_trade
    turnover <- sum(abs(weights - previous_weights))
    gross_return <- sum(weights * (open_next / open_now - 1))
    primary_cost <- turnover * contract$primary_cost_bps / 10000
    stress_cost <- turnover * contract$stress_cost_bps / 10000
    short_gross <- sum(abs(pmin(weights, 0)))
    borrow_cost <- short_gross *
      contract$stress_borrow_bps_annual / 10000 / 252
    rows[[i]] <- data.frame(
      schema_version = g5_mr03_schema_version(),
      signal_date = signal$session_date,
      execution_date = execution$session_date,
      next_execution_date = next_execution$session_date,
      evaluation_period = g5_mr03_period(execution$session_date, contract),
      z_score = signal$z_score,
      signal_action = signal$signal_action,
      target_state = state,
      trade_id = trade_id,
      is_exit_row = is_exit_row,
      symbol_1 = symbols[[1L]],
      symbol_2 = symbols[[2L]],
      symbol_3 = symbols[[3L]],
      weight_1 = weights[[1L]],
      weight_2 = weights[[2L]],
      weight_3 = weights[[3L]],
      gross_exposure = sum(abs(weights)),
      net_exposure = sum(weights),
      short_gross = short_gross,
      turnover = turnover,
      gross_return = gross_return,
      primary_cost = primary_cost,
      stress_cost = stress_cost,
      borrow_cost = borrow_cost,
      primary_net_return = gross_return - primary_cost,
      stress_net_return = gross_return - stress_cost - borrow_cost,
      stringsAsFactors = FALSE
    )
    previous_weights <- weights
    previous_state <- state
  }
  do.call(rbind, rows)
}

g5_mr03_trade_summary <- function(replay) {
  ids <- sort(unique(replay$trade_id[!is.na(replay$trade_id)]))
  rows <- lapply(ids, function(id) {
    x <- replay[!is.na(replay$trade_id) & replay$trade_id == id, , drop = FALSE]
    active <- x[x$target_state != 0L, , drop = FALSE]
    completed <- any(x$is_exit_row)
    direction <- if (nrow(active)) active$target_state[[1L]] else NA_integer_
    data.frame(
      trade_id = id,
      evaluation_period = if (nrow(active)) active$evaluation_period[[1L]] else x$evaluation_period[[1L]],
      entry_date = if (nrow(active)) min(active$execution_date) else as.Date(NA),
      exit_date = if (completed) max(x$execution_date[x$is_exit_row]) else as.Date(NA),
      direction = direction,
      direction_label = ifelse(direction == 1L, "LONG_TRIPLET", "SHORT_TRIPLET"),
      holding_bars = nrow(active),
      completed = completed,
      primary_net_additive_return = sum(x$primary_net_return),
      stress_net_additive_return = sum(x$stress_net_return),
      primary_compound_return = prod(1 + x$primary_net_return) - 1,
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) {
    return(data.frame(
      trade_id = integer(), evaluation_period = character(),
      entry_date = as.Date(character()), exit_date = as.Date(character()),
      direction = integer(), direction_label = character(),
      holding_bars = integer(), completed = logical(),
      primary_net_additive_return = numeric(),
      stress_net_additive_return = numeric(),
      primary_compound_return = numeric()
    ))
  }
  do.call(rbind, rows)
}

g5_mr03_moving_block_indices <- function(n, block_length) {
  if (n <= 0L) return(integer())
  block_length <- min(as.integer(block_length), n)
  starts <- sample.int(n, ceiling(n / block_length), replace = TRUE)
  unlist(lapply(starts, function(start) {
    ((start - 1L + seq_len(block_length) - 1L) %% n) + 1L
  }), use.names = FALSE)[seq_len(n)]
}

g5_mr03_trade_bootstrap <- function(
  trades,
  seed,
  contract = g5_mr03_contract()
) {
  trades <- trades[trades$completed, , drop = FALSE]
  set.seed(seed)
  draws <- rep(NA_real_, contract$trade_bootstrap_count)
  if (nrow(trades)) {
    for (i in seq_along(draws)) {
      idx <- g5_mr03_moving_block_indices(
        nrow(trades), contract$bootstrap_block_trades
      )
      draws[[i]] <- mean(trades$primary_net_additive_return[idx])
    }
  }
  finite <- draws[is.finite(draws)]
  interval <- if (length(finite)) {
    stats::quantile(finite, c(0.025, 0.975), names = FALSE)
  } else {
    c(NA_real_, NA_real_)
  }
  list(
    summary = data.frame(
      estimate = if (nrow(trades)) mean(trades$primary_net_additive_return) else NA_real_,
      lower_95 = interval[[1L]],
      upper_95 = interval[[2L]],
      draws = length(draws),
      seed = seed,
      stringsAsFactors = FALSE
    ),
    draws = data.frame(mean_primary_net_trade_return = draws)
  )
}

g5_mr03_forward_convergence <- function(
  indicators,
  beta,
  contract = g5_mr03_contract()
) {
  horizon <- 5L
  rows <- list()
  n <- nrow(indicators)
  if (n <= horizon + 1L) return(data.frame())
  for (i in seq_len(n - horizon - 1L)) {
    z <- indicators$z_score[[i]]
    if (!is.finite(z)) next
    entry <- as.numeric(indicators[i + 1L, paste0("open_", 1:3)])
    exit <- as.numeric(indicators[i + 1L + horizon, paste0("open_", 1:3)])
    dollar <- beta * entry
    weights <- dollar / sum(abs(dollar))
    rows[[length(rows) + 1L]] <- data.frame(
      signal_date = indicators$session_date[[i]],
      evaluation_period = g5_mr03_period(indicators$session_date[[i]], contract),
      z_score = z,
      forward_5_session_return = sum(weights * (exit / entry - 1)),
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

g5_mr03_convergence_bootstrap <- function(
  convergence,
  seed,
  contract = g5_mr03_contract()
) {
  x <- convergence[
    is.finite(convergence$z_score) &
      is.finite(convergence$forward_5_session_return),
    ,
    drop = FALSE
  ]
  estimate <- if (nrow(x) >= 3L) {
    stats::cor(x$z_score, x$forward_5_session_return)
  } else {
    NA_real_
  }
  set.seed(seed)
  draws <- rep(NA_real_, contract$convergence_bootstrap_count)
  if (nrow(x) >= 3L) {
    for (i in seq_along(draws)) {
      idx <- g5_mr03_moving_block_indices(
        nrow(x), contract$convergence_block_sessions
      )
      draws[[i]] <- suppressWarnings(stats::cor(
        x$z_score[idx], x$forward_5_session_return[idx]
      ))
    }
  }
  finite <- draws[is.finite(draws)]
  interval <- if (length(finite)) {
    stats::quantile(finite, c(0.025, 0.975), names = FALSE)
  } else {
    c(NA_real_, NA_real_)
  }
  list(
    summary = data.frame(
      correlation = estimate,
      lower_95 = interval[[1L]],
      upper_95 = interval[[2L]],
      observations = nrow(x),
      seed = seed,
      stringsAsFactors = FALSE
    ),
    draws = data.frame(correlation = draws)
  )
}

g5_mr03_long_run_variance <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 2L) return(NA_real_)
  centered <- x - mean(x)
  lag_max <- max(1L, floor(4 * (n / 100)^(2 / 9)))
  value <- sum(centered^2) / n
  for (lag in seq_len(min(lag_max, n - 1L))) {
    weight <- 1 - lag / (lag_max + 1)
    covariance <- sum(
      centered[(lag + 1L):n] * centered[1L:(n - lag)]
    ) / n
    value <- value + 2 * weight * covariance
  }
  value
}

g5_mr03_performance_metrics <- function(replay) {
  returns <- replay$primary_net_return
  equity <- cumprod(1 + returns)
  peak <- cummax(c(1, equity))[-1L]
  drawdown <- equity / peak - 1
  lrv <- g5_mr03_long_run_variance(returns)
  data.frame(
    bars = nrow(replay),
    cumulative_return = tail(equity, 1L) - 1,
    stress_cumulative_return = prod(1 + replay$stress_net_return) - 1,
    naive_sharpe = if (stats::sd(returns) > 0) {
      sqrt(252) * mean(returns) / stats::sd(returns)
    } else {
      NA_real_
    },
    autocorrelation_adjusted_sharpe = if (is.finite(lrv) && lrv > 0) {
      sqrt(252) * mean(returns) / sqrt(lrv)
    } else {
      NA_real_
    },
    maximum_drawdown = min(drawdown),
    average_gross_exposure = mean(replay$gross_exposure),
    total_turnover = sum(replay$turnover),
    stringsAsFactors = FALSE
  )
}

g5_mr03_integrity_audit <- function(
  bars,
  panel,
  replay,
  beta,
  symbols,
  query_end,
  expected_period,
  data_health_status
) {
  reference_sessions <- sort(unique(bars$session_date))
  coverage <- vapply(symbols, function(symbol) {
    identical(
      sort(unique(bars$session_date[bars$symbol == symbol])),
      reference_sessions
    )
  }, logical(1))
  active <- replay$target_state != 0L
  checks <- c(
    identical(data_health_status, "PASS"),
    !anyDuplicated(bars[c("symbol", "session_date")]),
    setequal(unique(bars$symbol), symbols),
    all(coverage),
    max(bars$session_date) <= query_end,
    all(panel$session_date == sort(panel$session_date)),
    all(replay$signal_date < replay$execution_date),
    all(replay$execution_date < replay$next_execution_date),
    all(replay$target_state %in% c(-1L, 0L, 1L)),
    all(abs(replay$gross_exposure[active] - 1) < 1e-10),
    all(replay$turnover >= 0 & replay$primary_cost >= 0),
    all(replay$evaluation_period == expected_period),
    any(beta > 0) && any(beta < 0)
  )
  data.frame(
    check_id = sprintf("I%02d", seq_along(checks)),
    check = c(
      "Data health permits analysis",
      "No duplicate symbol-session bars",
      "Exact frozen triplet universe",
      "All legs cover the same reference sessions",
      "No bars after explicit query end",
      "Panel is session ordered",
      "Signals execute after signal close",
      "Returns end after execution open",
      "State is flat, long triplet, or short triplet",
      "Non-flat target is normalized to one gross",
      "Turnover and costs are nonnegative",
      paste(expected_period, "replay contains only its partition"),
      "Cointegrating vector contains both positive and negative legs"
    ),
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

g5_mr03_train_gates <- function(
  integrity,
  adf,
  johansen,
  stability,
  half_life,
  trades,
  trade_bootstrap,
  convergence_bootstrap,
  contract = g5_mr03_contract()
) {
  completed <- trades[trades$completed, , drop = FALSE]
  long_count <- sum(completed$direction == 1L)
  short_count <- sum(completed$direction == -1L)
  mean_trade <- if (nrow(completed)) {
    mean(completed$primary_net_additive_return)
  } else {
    NA_real_
  }
  i1_pass <- all(adf$level_adf_t > contract$adf_threshold) &&
    all(adf$difference_adf_t < contract$adf_threshold)
  values <- c(
    all(integrity$status == "PASS"),
    i1_pass,
    isTRUE(johansen$rank_one),
    is.finite(stability$cosine) &&
      stability$cosine >= contract$minimum_vector_cosine,
    is.finite(half_life) &&
      half_life >= contract$minimum_half_life &&
      half_life <= contract$maximum_half_life,
    nrow(completed) >= contract$minimum_completed_trades &&
      long_count >= contract$minimum_trades_each_direction &&
      short_count >= contract$minimum_trades_each_direction,
    is.finite(mean_trade) && mean_trade > 0 &&
      is.finite(trade_bootstrap$lower_95) &&
      trade_bootstrap$lower_95 > 0,
    is.finite(convergence_bootstrap$correlation) &&
      convergence_bootstrap$correlation < 0 &&
      is.finite(convergence_bootstrap$upper_95) &&
      convergence_bootstrap$upper_95 < 0
  )
  data.frame(
    gate_id = paste0("G", seq_along(values)),
    gate = c(
      "Integrity, timing, partitions, accounting, and mixed-sign vector",
      "All three components satisfy the frozen I(1) diagnostic",
      "Johansen bootstrap supports rank exactly one",
      "Split-TRAIN dollar-exposure cosine is at least 0.85",
      "TRAIN spread half-life is between 2 and 60 sessions",
      "At least 30 completed trades and 10 each direction",
      "Positive mean net trade return with lower 95% bound above zero",
      "Negative z-to-forward return correlation with upper 95% below zero"
    ),
    status = ifelse(values, "PASS", "FAIL"),
    details = c(
      sprintf("%d / %d", sum(integrity$status == "PASS"), nrow(integrity)),
      paste(
        sprintf("%s L %.3f D %.3f", adf$symbol, adf$level_adf_t, adf$difference_adf_t),
        collapse = "; "
      ),
      sprintf(
        "p(rank0)=%.4f; p(rank<=1)=%.4f",
        johansen$p_rank_0, johansen$p_rank_at_most_1
      ),
      sprintf("%.4f", stability$cosine),
      sprintf("%.2f sessions", half_life),
      sprintf("%d completed; %d long; %d short", nrow(completed), long_count, short_count),
      sprintf("%.6f; lower %.6f", mean_trade, trade_bootstrap$lower_95),
      sprintf(
        "%.6f; upper %.6f",
        convergence_bootstrap$correlation,
        convergence_bootstrap$upper_95
      )
    ),
    stringsAsFactors = FALSE
  )
}

g5_mr03_run_train_triplet <- function(
  bars,
  registry_row,
  data_health_status = "PASS",
  contract = g5_mr03_contract()
) {
  contract <- g5_mr03_validate_contract(contract)
  symbols <- as.character(registry_row[1L, c("symbol_1", "symbol_2", "symbol_3")])
  panel <- g5_mr03_common_panel(bars, symbols, contract$train_end)
  panel <- panel[
    panel$session_date >= contract$train_start &
      panel$session_date <= contract$train_end,
    ,
    drop = FALSE
  ]
  price_matrix <- as.matrix(panel[paste0("close_", 1:3)])
  fit <- g5_mr03_johansen_fit(price_matrix)
  bootstrap <- g5_mr03_johansen_bootstrap(
    price_matrix, fit, registry_row$triplet_index[[1L]], contract
  )
  stability <- g5_mr03_vector_stability(price_matrix)
  spread <- as.numeric(price_matrix %*% fit$beta)
  ar <- g5_mr03_half_life(spread)
  adf <- data.frame(
    symbol = symbols,
    level_adf_t = vapply(seq_len(3L), function(i) {
      g5_mr03_adf_t(price_matrix[, i])
    }, numeric(1)),
    difference_adf_t = vapply(seq_len(3L), function(i) {
      g5_mr03_adf_t(diff(price_matrix[, i]))
    }, numeric(1)),
    stringsAsFactors = FALSE
  )
  indicators <- g5_mr03_signal_states(
    g5_mr03_indicators(panel, fit$beta, contract),
    contract
  )
  replay <- g5_mr03_build_replay(indicators, fit$beta, symbols, contract)
  replay <- replay[replay$evaluation_period == "TRAIN", , drop = FALSE]
  trades <- g5_mr03_trade_summary(replay)
  trade_bootstrap <- g5_mr03_trade_bootstrap(
    trades, 8300L + registry_row$triplet_index[[1L]], contract
  )
  convergence <- g5_mr03_forward_convergence(indicators, fit$beta, contract)
  convergence <- convergence[convergence$evaluation_period == "TRAIN", , drop = FALSE]
  convergence_bootstrap <- g5_mr03_convergence_bootstrap(
    convergence, 9300L + registry_row$triplet_index[[1L]], contract
  )
  integrity <- g5_mr03_integrity_audit(
    bars = g5_mr03_validate_bars(bars, symbols, contract$train_end),
    panel = panel,
    replay = replay,
    beta = fit$beta,
    symbols = symbols,
    query_end = contract$train_end,
    expected_period = "TRAIN",
    data_health_status = data_health_status
  )
  gates <- g5_mr03_train_gates(
    integrity, adf, bootstrap$summary, stability,
    unname(ar[["half_life"]]), trades, trade_bootstrap$summary,
    convergence_bootstrap$summary, contract
  )
  completed <- trades[trades$completed, , drop = FALSE]
  summary <- data.frame(
    triplet_index = registry_row$triplet_index[[1L]],
    triplet_id = registry_row$triplet_id[[1L]],
    triplet_category = registry_row$triplet_category[[1L]],
    symbol_1 = symbols[[1L]],
    symbol_2 = symbols[[2L]],
    symbol_3 = symbols[[3L]],
    beta_1 = fit$beta[[1L]],
    beta_2 = fit$beta[[2L]],
    beta_3 = fit$beta[[3L]],
    p_rank_0 = bootstrap$summary$p_rank_0,
    p_rank_at_most_1 = bootstrap$summary$p_rank_at_most_1,
    rank_one = bootstrap$summary$rank_one,
    vector_cosine = stability$cosine,
    spread_adf_t = g5_mr03_adf_t(spread),
    spread_half_life = unname(ar[["half_life"]]),
    completed_trades = nrow(completed),
    long_trades = sum(completed$direction == 1L),
    short_trades = sum(completed$direction == -1L),
    mean_net_trade_return = if (nrow(completed)) {
      mean(completed$primary_net_additive_return)
    } else {
      NA_real_
    },
    trade_lower_95 = trade_bootstrap$summary$lower_95,
    hit_rate = if (nrow(completed)) {
      mean(completed$primary_net_additive_return > 0)
    } else {
      NA_real_
    },
    forward_correlation = convergence_bootstrap$summary$correlation,
    forward_upper_95 = convergence_bootstrap$summary$upper_95,
    cumulative_return = g5_mr03_performance_metrics(replay)$cumulative_return,
    maximum_drawdown = g5_mr03_performance_metrics(replay)$maximum_drawdown,
    gates_passed = sum(gates$status == "PASS"),
    full_gate_pass = all(gates$status == "PASS"),
    stringsAsFactors = FALSE
  )
  list(
    registry_row = registry_row,
    symbols = symbols,
    panel = panel,
    fit = fit,
    johansen_bootstrap = bootstrap,
    stability = stability,
    adf = adf,
    indicators = indicators,
    replay = replay,
    trades = trades,
    trade_bootstrap = trade_bootstrap,
    convergence = convergence,
    convergence_bootstrap = convergence_bootstrap,
    integrity = integrity,
    gates = gates,
    summary = summary
  )
}

g5_mr03_run_train_batch <- function(
  bars,
  registry = g5_mr03_registry(),
  data_health_status = "PASS",
  contract = g5_mr03_contract()
) {
  registry <- g5_mr03_validate_registry(registry)
  results <- lapply(seq_len(nrow(registry)), function(i) {
    row <- registry[i, , drop = FALSE]
    triplet_bars <- bars[
      bars$symbol %in% as.character(row[c("symbol_1", "symbol_2", "symbol_3")]),
      ,
      drop = FALSE
    ]
    g5_mr03_run_train_triplet(
      triplet_bars, row, data_health_status, contract
    )
  })
  names(results) <- registry$triplet_id
  summary <- do.call(rbind, lapply(results, function(x) x$summary))
  gate_detail <- do.call(rbind, lapply(results, function(x) {
    gates <- x$gates
    gates$triplet_index <- x$registry_row$triplet_index[[1L]]
    gates$triplet_id <- x$registry_row$triplet_id[[1L]]
    gates[, c("triplet_index", "triplet_id", "gate_id", "gate", "status", "details")]
  }))
  pass_rows <- summary[summary$full_gate_pass, , drop = FALSE]
  nominated <- if (nrow(pass_rows)) pass_rows$triplet_id[[1L]] else NA_character_
  list(
    schema_version = g5_mr03_schema_version(),
    registry = registry,
    results = results,
    summary = summary,
    gate_detail = gate_detail,
    nominated_triplet_id = nominated,
    later_outcomes_opened = FALSE,
    overall_status = if (is.na(nominated)) {
      "STOP_LIT_MR_03_1_NO_TRAIN_NOMINATION"
    } else {
      "TRAIN_NOMINATION_LIT_MR_03_1_DEVELOPMENT_AUTHORIZED"
    }
  )
}

g5_mr03_run_development <- function(
  bars,
  train_result,
  data_health_status = "PASS",
  contract = g5_mr03_contract()
) {
  symbols <- train_result$symbols
  panel <- g5_mr03_common_panel(bars, symbols, contract$development_end)
  indicators <- g5_mr03_signal_states(
    g5_mr03_indicators(panel, train_result$fit$beta, contract),
    contract
  )
  replay <- g5_mr03_build_replay(
    indicators, train_result$fit$beta, symbols, contract
  )
  replay <- replay[replay$evaluation_period == "DEVELOPMENT", , drop = FALSE]
  trades <- g5_mr03_trade_summary(replay)
  convergence <- g5_mr03_forward_convergence(
    indicators, train_result$fit$beta, contract
  )
  convergence <- convergence[
    convergence$evaluation_period == "DEVELOPMENT", ,
    drop = FALSE
  ]
  integrity <- g5_mr03_integrity_audit(
    bars = g5_mr03_validate_bars(bars, symbols, contract$development_end),
    panel = panel,
    replay = replay,
    beta = train_result$fit$beta,
    symbols = symbols,
    query_end = contract$development_end,
    expected_period = "DEVELOPMENT",
    data_health_status = data_health_status
  )
  metrics <- g5_mr03_performance_metrics(replay)
  completed <- trades[trades$completed, , drop = FALSE]
  list(
    indicators = indicators,
    replay = replay,
    trades = trades,
    convergence = convergence,
    integrity = integrity,
    metrics = metrics,
    summary = data.frame(
      triplet_id = train_result$registry_row$triplet_id[[1L]],
      beta_1 = train_result$fit$beta[[1L]],
      beta_2 = train_result$fit$beta[[2L]],
      beta_3 = train_result$fit$beta[[3L]],
      completed_trades = nrow(completed),
      long_trades = sum(completed$direction == 1L),
      short_trades = sum(completed$direction == -1L),
      mean_net_trade_return = if (nrow(completed)) {
        mean(completed$primary_net_additive_return)
      } else {
        NA_real_
      },
      hit_rate = if (nrow(completed)) {
        mean(completed$primary_net_additive_return > 0)
      } else {
        NA_real_
      },
      forward_correlation = if (nrow(convergence) >= 3L) {
        stats::cor(convergence$z_score, convergence$forward_5_session_return)
      } else {
        NA_real_
      },
      cumulative_return = metrics$cumulative_return,
      stress_cumulative_return = metrics$stress_cumulative_return,
      naive_sharpe = metrics$naive_sharpe,
      autocorrelation_adjusted_sharpe =
        metrics$autocorrelation_adjusted_sharpe,
      maximum_drawdown = metrics$maximum_drawdown,
      stringsAsFactors = FALSE
    )
  )
}
