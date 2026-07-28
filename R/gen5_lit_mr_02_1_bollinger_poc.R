g5_mr02_schema_version <- function() {
  "gen5_lit_mr_02_1_v1"
}

g5_mr02_stop <- function(message) {
  stop(paste0("[Gen5 LIT-MR-02.1] ", message), call. = FALSE)
}

g5_mr02_contract <- function() {
  list(
    literature_id = "LIT-MR-02.1",
    symbol_x = "GLD",
    symbol_y = "USO",
    query_start = as.Date("2016-01-04"),
    query_end = as.Date("2026-07-24"),
    as_of_timestamp = "2026-07-24 17:30:00",
    train_start = as.Date("2016-01-04"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-01"),
    development_end = as.Date("2023-12-31"),
    confirmation_start = as.Date("2024-01-01"),
    confirmation_end = as.Date("2026-07-24"),
    lookback_sessions = 20L,
    entry_z = 1,
    exit_z = 0,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    stress_borrow_bps_annual = 100,
    bootstrap_count = 2000L,
    bootstrap_seed = 5801L,
    bootstrap_block_trades = 4L,
    random_policy_count = 2000L,
    random_seed = 5802L,
    random_percentile = 0.90,
    convergence_bootstrap_seed = 5803L,
    convergence_block_sessions = 20L,
    minimum_positive_beta_coverage = 0.95,
    minimum_completed_trades = 30L,
    minimum_trades_each_direction = 10L,
    minimum_positive_years = 3L
  )
}

g5_mr02_validate_contract <- function(contract = g5_mr02_contract()) {
  required <- c(
    "literature_id", "symbol_x", "symbol_y", "query_start", "query_end",
    "as_of_timestamp", "train_start", "train_end", "development_start",
    "development_end", "confirmation_start", "confirmation_end",
    "lookback_sessions", "entry_z", "exit_z", "primary_cost_bps",
    "stress_cost_bps", "stress_borrow_bps_annual", "bootstrap_count",
    "bootstrap_seed", "bootstrap_block_trades", "random_policy_count",
    "random_seed", "random_percentile", "convergence_bootstrap_seed",
    "convergence_block_sessions", "minimum_positive_beta_coverage",
    "minimum_completed_trades", "minimum_trades_each_direction",
    "minimum_positive_years"
  )
  missing <- setdiff(required, names(contract))
  if (length(missing)) {
    g5_mr02_stop(paste("Contract is missing:", paste(missing, collapse = ", ")))
  }
  dates <- c(
    contract$query_start, contract$query_end, contract$train_start,
    contract$train_end, contract$development_start, contract$development_end,
    contract$confirmation_start, contract$confirmation_end
  )
  if (any(is.na(dates))) g5_mr02_stop("Contract dates must be explicit.")
  if (!identical(contract$literature_id, "LIT-MR-02.1") ||
      !identical(contract$symbol_x, "GLD") ||
      !identical(contract$symbol_y, "USO")) {
    g5_mr02_stop("The frozen identifier and GLD-USO pair cannot change.")
  }
  if (!identical(as.integer(contract$lookback_sessions), 20L) ||
      !isTRUE(all.equal(as.numeric(contract$entry_z), 1)) ||
      !isTRUE(all.equal(as.numeric(contract$exit_z), 0))) {
    g5_mr02_stop("The frozen 20-session, +/-1 entry, zero-exit rule changed.")
  }
  if (!identical(as.integer(contract$bootstrap_count), 2000L) ||
      !identical(as.integer(contract$random_policy_count), 2000L)) {
    g5_mr02_stop("Frozen resampling counts changed.")
  }
  contract
}

g5_mr02_required_symbols <- function(contract = g5_mr02_contract()) {
  contract <- g5_mr02_validate_contract(contract)
  c(contract$symbol_x, contract$symbol_y)
}

g5_mr02_validate_bars <- function(bars, contract = g5_mr02_contract()) {
  contract <- g5_mr02_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_mr02_stop(paste("Bars are missing:", paste(missing, collapse = ", ")))
  }
  bars <- bars[bars$symbol %in% g5_mr02_required_symbols(contract), required, drop = FALSE]
  bars$session_date <- as.Date(bars$session_date)
  if (!nrow(bars)) g5_mr02_stop("No GLD-USO bars were supplied.")
  if (any(is.na(bars$session_date))) g5_mr02_stop("Session dates must be valid.")
  if (anyDuplicated(bars[c("symbol", "session_date")])) {
    g5_mr02_stop("Duplicate symbol-session bars are prohibited.")
  }
  numeric_columns <- c("open", "high", "low", "close", "volume")
  if (any(!vapply(bars[numeric_columns], is.numeric, logical(1)))) {
    g5_mr02_stop("OHLCV columns must be numeric.")
  }
  price_columns <- c("open", "high", "low", "close")
  if (any(!is.finite(as.matrix(bars[price_columns]))) ||
      any(as.matrix(bars[price_columns]) <= 0)) {
    g5_mr02_stop("Prices must be finite and positive.")
  }
  if (any(bars$session_date > contract$query_end)) {
    g5_mr02_stop("Future bars exceed the frozen query end.")
  }
  bars[order(bars$session_date, bars$symbol), , drop = FALSE]
}

g5_mr02_common_panel <- function(bars, contract = g5_mr02_contract()) {
  bars <- g5_mr02_validate_bars(bars, contract)
  x <- bars[bars$symbol == contract$symbol_x, c("session_date", "open", "close"), drop = FALSE]
  y <- bars[bars$symbol == contract$symbol_y, c("session_date", "open", "close"), drop = FALSE]
  names(x)[2:3] <- c("open_x", "close_x")
  names(y)[2:3] <- c("open_y", "close_y")
  panel <- merge(x, y, by = "session_date", all = FALSE)
  panel <- panel[order(panel$session_date), , drop = FALSE]
  rownames(panel) <- NULL
  if (nrow(panel) < 100L) g5_mr02_stop("Too few common GLD-USO sessions.")
  panel
}

g5_mr02_period <- function(date, contract = g5_mr02_contract()) {
  date <- as.Date(date)
  ifelse(
    date >= contract$train_start & date <= contract$train_end,
    "TRAIN",
    ifelse(
      date >= contract$development_start & date <= contract$development_end,
      "DEVELOPMENT",
      ifelse(
        date >= contract$confirmation_start & date <= contract$confirmation_end,
        "CONFIRMATION",
        "WARMUP"
      )
    )
  )
}

g5_mr02_rolling_indicators <- function(panel, contract = g5_mr02_contract()) {
  contract <- g5_mr02_validate_contract(contract)
  n <- nrow(panel)
  lookback <- contract$lookback_sessions
  intercept <- beta <- spread <- spread_mean <- spread_sd <- z_score <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    if (i < lookback) next
    idx <- (i - lookback + 1L):i
    design <- cbind(1, panel$close_x[idx])
    fit <- tryCatch(stats::lm.fit(design, panel$close_y[idx]), error = function(e) NULL)
    if (is.null(fit) || length(fit$coefficients) < 2L) next
    intercept[[i]] <- unname(fit$coefficients[[1L]])
    beta[[i]] <- unname(fit$coefficients[[2L]])
    if (is.finite(beta[[i]])) {
      spread[[i]] <- panel$close_y[[i]] - beta[[i]] * panel$close_x[[i]]
    }
    if (i < 2L * lookback - 1L) next
    spread_idx <- (i - lookback + 1L):i
    values <- spread[spread_idx]
    if (any(!is.finite(values))) next
    spread_mean[[i]] <- mean(values)
    spread_sd[[i]] <- stats::sd(values)
    if (is.finite(spread_sd[[i]]) && spread_sd[[i]] > 0) {
      z_score[[i]] <- (spread[[i]] - spread_mean[[i]]) / spread_sd[[i]]
    }
  }
  out <- panel
  out$intercept <- intercept
  out$beta <- beta
  out$spread <- spread
  out$spread_mean <- spread_mean
  out$spread_sd <- spread_sd
  out$z_score <- z_score
  out$evaluation_period <- g5_mr02_period(out$session_date, contract)
  out
}

g5_mr02_signal_states <- function(indicators, contract = g5_mr02_contract()) {
  state <- integer(nrow(indicators))
  previous <- 0L
  transition <- rep("carry_flat", nrow(indicators))
  for (i in seq_len(nrow(indicators))) {
    z <- indicators$z_score[[i]]
    beta <- indicators$beta[[i]]
    valid <- is.finite(z) && is.finite(beta) && beta > 0
    current <- previous
    action <- if (previous == 0L) "carry_flat" else "carry_position"
    if (!valid) {
      current <- 0L
      action <- if (previous == 0L) "invalid_flat" else "invalid_exit"
    } else if (previous == 0L && z < -contract$entry_z) {
      current <- 1L
      action <- "enter_long_spread"
    } else if (previous == 0L && z > contract$entry_z) {
      current <- -1L
      action <- "enter_short_spread"
    } else if (previous == 1L && z >= contract$exit_z) {
      current <- 0L
      action <- "exit_long_spread"
    } else if (previous == -1L && z <= -contract$exit_z) {
      current <- 0L
      action <- "exit_short_spread"
    }
    state[[i]] <- current
    transition[[i]] <- action
    previous <- current
  }
  indicators$target_state <- state
  indicators$signal_action <- transition
  indicators
}

g5_mr02_build_replay <- function(indicators, contract = g5_mr02_contract()) {
  contract <- g5_mr02_validate_contract(contract)
  if (nrow(indicators) < 3L) g5_mr02_stop("Replay requires at least three sessions.")
  rows <- vector("list", nrow(indicators) - 2L)
  previous_w_x <- 0
  previous_w_y <- 0
  active_trade <- 0L
  previous_state <- 0L
  for (i in seq_len(nrow(indicators) - 2L)) {
    signal <- indicators[i, , drop = FALSE]
    execution <- indicators[i + 1L, , drop = FALSE]
    next_execution <- indicators[i + 2L, , drop = FALSE]
    state <- as.integer(signal$target_state)
    beta <- signal$beta
    valid <- state != 0L && is.finite(beta) && beta > 0
    if (valid) {
      gross_value <- execution$open_y + beta * execution$open_x
      w_y <- state * execution$open_y / gross_value
      w_x <- -state * beta * execution$open_x / gross_value
    } else {
      w_x <- 0
      w_y <- 0
      state <- 0L
    }
    if (state != 0L && previous_state == 0L) active_trade <- active_trade + 1L
    trade_id <- if (state != 0L) active_trade else NA_integer_
    is_exit_row <- state == 0L && previous_state != 0L
    if (is_exit_row) trade_id <- active_trade
    turnover <- abs(w_x - previous_w_x) + abs(w_y - previous_w_y)
    ret_x <- next_execution$open_x / execution$open_x - 1
    ret_y <- next_execution$open_y / execution$open_y - 1
    gross_return <- w_x * ret_x + w_y * ret_y
    primary_cost <- turnover * contract$primary_cost_bps / 10000
    stress_cost <- turnover * contract$stress_cost_bps / 10000
    short_gross <- abs(min(w_x, 0)) + abs(min(w_y, 0))
    borrow_cost <- short_gross * contract$stress_borrow_bps_annual / 10000 / 252
    rows[[i]] <- data.frame(
      schema_version = g5_mr02_schema_version(),
      signal_date = signal$session_date,
      execution_date = execution$session_date,
      next_execution_date = next_execution$session_date,
      evaluation_period = g5_mr02_period(execution$session_date, contract),
      z_score = signal$z_score,
      beta = beta,
      signal_action = signal$signal_action,
      target_state = state,
      trade_id = trade_id,
      is_exit_row = is_exit_row,
      weight_gld = w_x,
      weight_uso = w_y,
      gross_exposure = abs(w_x) + abs(w_y),
      net_exposure = w_x + w_y,
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
    previous_w_x <- w_x
    previous_w_y <- w_y
    previous_state <- state
  }
  do.call(rbind, rows)
}

g5_mr02_trade_summary <- function(replay) {
  ids <- sort(unique(replay$trade_id[!is.na(replay$trade_id)]))
  rows <- lapply(ids, function(id) {
    x <- replay[
      !is.na(replay$trade_id) & replay$trade_id == id,
      ,
      drop = FALSE
    ]
    nonzero <- x[x$target_state != 0L, , drop = FALSE]
    completed <- any(x$is_exit_row)
    direction <- if (nrow(nonzero)) nonzero$target_state[[1L]] else NA_integer_
    gross_additive <- sum(x$gross_return)
    data.frame(
      schema_version = g5_mr02_schema_version(),
      trade_id = id,
      evaluation_period = if (nrow(nonzero)) nonzero$evaluation_period[[1L]] else x$evaluation_period[[1L]],
      entry_date = if (nrow(nonzero)) min(nonzero$execution_date) else as.Date(NA),
      exit_date = if (completed) max(x$execution_date[x$is_exit_row]) else as.Date(NA),
      direction = direction,
      direction_label = ifelse(direction == 1L, "LONG_SPREAD", "SHORT_SPREAD"),
      holding_bars = nrow(nonzero),
      completed = completed,
      gross_additive_return = gross_additive,
      base_pair_additive_return = if (is.finite(direction) && direction != 0L) {
        gross_additive / direction
      } else {
        NA_real_
      },
      primary_cost = sum(x$primary_cost),
      stress_cost_and_borrow = sum(x$stress_cost + x$borrow_cost),
      primary_net_additive_return = sum(x$primary_net_return),
      stress_net_additive_return = sum(x$stress_net_return),
      primary_compound_return = prod(1 + x$primary_net_return) - 1,
      stress_compound_return = prod(1 + x$stress_net_return) - 1,
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) {
    return(data.frame(
      schema_version = character(), trade_id = integer(),
      evaluation_period = character(), entry_date = as.Date(character()),
      exit_date = as.Date(character()), direction = integer(),
      direction_label = character(), holding_bars = integer(),
      completed = logical(), gross_additive_return = numeric(),
      base_pair_additive_return = numeric(), primary_cost = numeric(),
      stress_cost_and_borrow = numeric(),
      primary_net_additive_return = numeric(),
      stress_net_additive_return = numeric(),
      primary_compound_return = numeric(), stress_compound_return = numeric()
    ))
  }
  do.call(rbind, rows)
}

g5_mr02_moving_block_indices <- function(n, block_length) {
  if (n <= 0L) return(integer())
  block_length <- min(as.integer(block_length), n)
  starts <- sample.int(n, ceiling(n / block_length), replace = TRUE)
  unlist(lapply(starts, function(start) {
    ((start - 1L + seq_len(block_length) - 1L) %% n) + 1L
  }), use.names = FALSE)[seq_len(n)]
}

g5_mr02_trade_bootstrap <- function(trades, contract = g5_mr02_contract()) {
  trades <- trades[trades$completed, , drop = FALSE]
  set.seed(contract$bootstrap_seed)
  draws <- numeric(contract$bootstrap_count)
  if (nrow(trades)) {
    for (i in seq_len(contract$bootstrap_count)) {
      idx <- g5_mr02_moving_block_indices(
        nrow(trades), contract$bootstrap_block_trades
      )
      draws[[i]] <- mean(trades$primary_net_additive_return[idx])
    }
  } else {
    draws[] <- NA_real_
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
      draws = contract$bootstrap_count,
      seed = contract$bootstrap_seed,
      block_trades = contract$bootstrap_block_trades
    ),
    draws = data.frame(mean_primary_net_trade_return = draws)
  )
}

g5_mr02_random_sign_control <- function(
  trades,
  contract = g5_mr02_contract(),
  seed_offset = 0L
) {
  trades <- trades[trades$completed, , drop = FALSE]
  set.seed(contract$random_seed + as.integer(seed_offset))
  means <- numeric(contract$random_policy_count)
  if (nrow(trades)) {
    for (i in seq_len(contract$random_policy_count)) {
      random_direction <- sample(c(-1, 1), nrow(trades), replace = TRUE)
      random_net <- random_direction * trades$base_pair_additive_return -
        trades$primary_cost
      means[[i]] <- mean(random_net)
    }
  } else {
    means[] <- NA_real_
  }
  finite <- means[is.finite(means)]
  list(
    p90 = if (length(finite)) {
      unname(stats::quantile(finite, contract$random_percentile))
    } else {
      NA_real_
    },
    seed = contract$random_seed + as.integer(seed_offset),
    distribution = data.frame(mean_primary_net_trade_return = means)
  )
}

g5_mr02_adf_t <- function(series) {
  x <- as.numeric(series[is.finite(series)])
  if (length(x) < 10L) return(NA_real_)
  n <- length(x)
  dy <- x[3:n] - x[2:(n - 1L)]
  lag_level <- x[2:(n - 1L)]
  lag_delta <- x[2:(n - 1L)] - x[1:(n - 2L)]
  fit <- tryCatch(stats::lm(dy ~ 0 + lag_level + lag_delta), error = function(e) NULL)
  if (is.null(fit)) return(NA_real_)
  coefs <- summary(fit)$coefficients
  if (!"lag_level" %in% rownames(coefs)) return(NA_real_)
  unname(coefs["lag_level", "t value"])
}

g5_mr02_ar_half_life <- function(series) {
  x <- as.numeric(series[is.finite(series)])
  if (length(x) < 3L) {
    return(c(phi = NA_real_, half_life = NA_real_))
  }
  fit <- stats::lm(x[-1L] ~ x[-length(x)])
  phi <- unname(stats::coef(fit)[[2L]])
  half_life <- if (is.finite(phi) && phi > 0 && phi < 1) {
    log(0.5) / log(phi)
  } else {
    NA_real_
  }
  c(phi = phi, half_life = half_life)
}

g5_mr02_variance_ratio <- function(series, horizon) {
  x <- as.numeric(series[is.finite(series)])
  horizon <- as.integer(horizon)
  if (length(x) <= horizon + 1L) return(NA_real_)
  one <- diff(x)
  multi <- x[(horizon + 1L):length(x)] - x[1L:(length(x) - horizon)]
  denominator <- horizon * stats::var(one)
  if (!is.finite(denominator) || denominator <= 0) return(NA_real_)
  stats::var(multi) / denominator
}

g5_mr02_forward_convergence <- function(indicators, contract = g5_mr02_contract()) {
  horizon <- 5L
  rows <- list()
  n <- nrow(indicators)
  for (i in seq_len(max(0L, n - horizon - 1L))) {
    z <- indicators$z_score[[i]]
    beta <- indicators$beta[[i]]
    if (!is.finite(z) || !is.finite(beta) || beta <= 0) next
    entry_i <- i + 1L
    exit_i <- i + 1L + horizon
    gross <- indicators$open_y[[entry_i]] + beta * indicators$open_x[[entry_i]]
    w_y <- indicators$open_y[[entry_i]] / gross
    w_x <- -beta * indicators$open_x[[entry_i]] / gross
    spread_return <- w_y * (
      indicators$open_y[[exit_i]] / indicators$open_y[[entry_i]] - 1
    ) + w_x * (
      indicators$open_x[[exit_i]] / indicators$open_x[[entry_i]] - 1
    )
    rows[[length(rows) + 1L]] <- data.frame(
      signal_date = indicators$session_date[[i]],
      evaluation_period = g5_mr02_period(indicators$session_date[[i]], contract),
      z_score = z,
      forward_5_session_spread_return = spread_return
    )
  }
  if (!length(rows)) {
    return(data.frame(
      signal_date = as.Date(character()), evaluation_period = character(),
      z_score = numeric(), forward_5_session_spread_return = numeric()
    ))
  }
  do.call(rbind, rows)
}

g5_mr02_convergence_bootstrap <- function(
  convergence,
  contract = g5_mr02_contract()
) {
  x <- convergence[
    is.finite(convergence$z_score) &
      is.finite(convergence$forward_5_session_spread_return),
    ,
    drop = FALSE
  ]
  estimate <- if (nrow(x) >= 3L) {
    suppressWarnings(stats::cor(
      x$z_score, x$forward_5_session_spread_return
    ))
  } else {
    NA_real_
  }
  set.seed(contract$convergence_bootstrap_seed)
  draws <- numeric(contract$bootstrap_count)
  if (nrow(x) >= 3L) {
    for (i in seq_len(contract$bootstrap_count)) {
      idx <- g5_mr02_moving_block_indices(
        nrow(x), contract$convergence_block_sessions
      )
      draws[[i]] <- suppressWarnings(stats::cor(
        x$z_score[idx], x$forward_5_session_spread_return[idx]
      ))
    }
  } else {
    draws[] <- NA_real_
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
      draws = contract$bootstrap_count,
      seed = contract$convergence_bootstrap_seed,
      block_sessions = contract$convergence_block_sessions
    ),
    draws = data.frame(correlation = draws)
  )
}

g5_mr02_statistical_diagnostics <- function(
  indicators,
  contract = g5_mr02_contract()
) {
  train <- indicators[
    indicators$session_date >= contract$train_start &
      indicators$session_date <= contract$train_end,
    ,
    drop = FALSE
  ]
  complete <- train[is.finite(train$close_x) & is.finite(train$close_y), , drop = FALSE]
  static_fit <- stats::lm(close_y ~ close_x, data = complete)
  residual <- unname(stats::residuals(static_fit))
  dynamic <- train$spread[is.finite(train$spread)]
  ar <- g5_mr02_ar_half_life(dynamic)
  data.frame(
    static_alpha = unname(stats::coef(static_fit)[[1L]]),
    static_beta = unname(stats::coef(static_fit)[[2L]]),
    static_residual_adf_t = g5_mr02_adf_t(residual),
    dynamic_spread_adf_t = g5_mr02_adf_t(dynamic),
    dynamic_spread_phi = unname(ar[["phi"]]),
    dynamic_spread_half_life = unname(ar[["half_life"]]),
    variance_ratio_5 = g5_mr02_variance_ratio(dynamic, 5L),
    variance_ratio_20 = g5_mr02_variance_ratio(dynamic, 20L),
    stringsAsFactors = FALSE
  )
}

g5_mr02_session_coverage_audit <- function(
  bars,
  contract = g5_mr02_contract()
) {
  bars <- g5_mr02_validate_bars(bars, contract)
  symbols <- g5_mr02_required_symbols(contract)
  sessions <- sort(unique(bars$session_date))
  rows <- lapply(symbols, function(symbol) {
    observed <- sort(unique(bars$session_date[bars$symbol == symbol]))
    missing <- setdiff(sessions, observed)
    data.frame(
      symbol = symbol,
      observed_sessions = length(observed),
      reference_sessions = length(sessions),
      first_session = min(observed),
      last_session = max(observed),
      missing_sessions = length(missing),
      status = ifelse(length(missing) == 0L, "PASS", "FAIL"),
      details = ifelse(
        length(missing) == 0L,
        "covers_all_pair_reference_sessions",
        paste(format(head(missing, 5L)), collapse = ",")
      )
    )
  })
  do.call(rbind, rows)
}

g5_mr02_integrity_audit <- function(
  bars,
  indicators,
  replay,
  contract = g5_mr02_contract(),
  data_health_status = "PASS"
) {
  checks <- c(
    data_health_status == "PASS",
    !anyDuplicated(bars[c("symbol", "session_date")]),
    setequal(unique(bars$symbol), g5_mr02_required_symbols(contract)),
    all(g5_mr02_session_coverage_audit(bars, contract)$status == "PASS"),
    max(bars$session_date) <= contract$query_end,
    all(indicators$session_date == sort(indicators$session_date)),
    all(replay$signal_date < replay$execution_date),
    all(replay$execution_date < replay$next_execution_date),
    all(replay$target_state %in% c(-1L, 0L, 1L)),
    all(abs(replay$gross_exposure[replay$target_state != 0L] - 1) < 1e-10),
    all(replay$turnover >= 0 & replay$primary_cost >= 0),
    all(replay$evaluation_period == "TRAIN")
  )
  labels <- c(
    "Data health permits analysis",
    "No duplicate symbol-session bars",
    "Exact frozen GLD-USO universe",
    "Both assets cover common reference sessions",
    "No bars after explicit query end",
    "Indicators are session ordered",
    "Signals execute strictly after signal close",
    "Returns end after execution open",
    "State is flat, long spread, or short spread",
    "Non-flat target is normalized to one gross",
    "Turnover and costs are nonnegative",
    "TRAIN gate uses TRAIN execution rows only"
  )
  data.frame(
    check_id = sprintf("I%02d", seq_along(checks)),
    check = labels,
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

g5_mr02_year_summary <- function(replay) {
  replay$calendar_year <- as.integer(format(replay$execution_date, "%Y"))
  years <- sort(unique(replay$calendar_year))
  do.call(rbind, lapply(years, function(year) {
    x <- replay[replay$calendar_year == year, , drop = FALSE]
    data.frame(
      calendar_year = year,
      bars = nrow(x),
      primary_net_return = prod(1 + x$primary_net_return) - 1,
      stress_net_return = prod(1 + x$stress_net_return) - 1,
      gross_return = prod(1 + x$gross_return) - 1,
      average_gross_exposure = mean(x$gross_exposure),
      turnover = sum(x$turnover),
      stringsAsFactors = FALSE
    )
  }))
}

g5_mr02_train_gates <- function(
  indicators,
  replay,
  trades,
  bootstrap,
  random_control,
  convergence_bootstrap,
  integrity,
  contract = g5_mr02_contract()
) {
  eligible <- indicators[
    indicators$session_date >= contract$train_start &
      indicators$session_date <= contract$train_end &
      is.finite(indicators$z_score),
    ,
    drop = FALSE
  ]
  positive_beta_coverage <- if (nrow(eligible)) {
    mean(is.finite(eligible$beta) & eligible$beta > 0)
  } else {
    0
  }
  completed <- trades[trades$completed, , drop = FALSE]
  long_count <- sum(completed$direction == 1L)
  short_count <- sum(completed$direction == -1L)
  observed <- if (nrow(completed)) {
    mean(completed$primary_net_additive_return)
  } else {
    NA_real_
  }
  hit_rate <- if (nrow(completed)) {
    mean(completed$primary_net_additive_return > 0)
  } else {
    NA_real_
  }
  years <- g5_mr02_year_summary(replay)
  positive_years <- sum(years$primary_net_return > 0)
  values <- c(
    all(integrity$status == "PASS"),
    positive_beta_coverage >= contract$minimum_positive_beta_coverage,
    nrow(completed) >= contract$minimum_completed_trades &&
      long_count >= contract$minimum_trades_each_direction &&
      short_count >= contract$minimum_trades_each_direction,
    is.finite(observed) && observed > 0 &&
      is.finite(bootstrap$summary$lower_95) &&
      bootstrap$summary$lower_95 > 0,
    is.finite(hit_rate) && hit_rate > 0.50,
    is.finite(observed) && is.finite(random_control$p90) &&
      observed > random_control$p90,
    positive_years >= contract$minimum_positive_years,
    is.finite(convergence_bootstrap$summary$correlation) &&
      convergence_bootstrap$summary$correlation < 0 &&
      is.finite(convergence_bootstrap$summary$upper_95) &&
      convergence_bootstrap$summary$upper_95 < 0
  )
  details <- c(
    sprintf("%d / %d", sum(integrity$status == "PASS"), nrow(integrity)),
    sprintf("%.4f", positive_beta_coverage),
    sprintf("%d completed; %d long; %d short", nrow(completed), long_count, short_count),
    sprintf(
      "%.6f; lower %.6f",
      observed,
      bootstrap$summary$lower_95
    ),
    sprintf("%.4f", hit_rate),
    sprintf("%.6f vs p90 %.6f", observed, random_control$p90),
    sprintf("%d / %d", positive_years, nrow(years)),
    sprintf(
      "%.6f; upper %.6f",
      convergence_bootstrap$summary$correlation,
      convergence_bootstrap$summary$upper_95
    )
  )
  data.frame(
    gate_id = sprintf("G%d", seq_along(values)),
    gate = c(
      "Integrity, timing, partitions, and accounting",
      "Positive rolling beta coverage at least 95%",
      "At least 30 completed trades and 10 each direction",
      "Positive mean net trade return with lower 95% bound above zero",
      "Completed-trade hit rate above 50%",
      "Observed mean net trade return beats random-sign p90",
      "Positive primary-cost bar return in at least three TRAIN years",
      "Negative z-to-forward-spread correlation with upper 95% bound below zero"
    ),
    status = ifelse(values, "PASS", "FAIL"),
    details = details,
    stringsAsFactors = FALSE
  )
}

g5_mr02_long_run_variance <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 2L) return(NA_real_)
  centered <- x - mean(x)
  lag_max <- max(1L, floor(4 * (n / 100)^(2 / 9)))
  gamma0 <- sum(centered^2) / n
  value <- gamma0
  for (lag in seq_len(min(lag_max, n - 1L))) {
    weight <- 1 - lag / (lag_max + 1)
    gamma <- sum(centered[(lag + 1L):n] * centered[1L:(n - lag)]) / n
    value <- value + 2 * weight * gamma
  }
  value
}

g5_mr02_performance_metrics <- function(replay) {
  returns <- replay$primary_net_return
  equity <- cumprod(1 + returns)
  peak <- cummax(c(1, equity))[-1L]
  drawdown <- equity / peak - 1
  naive_sharpe <- if (stats::sd(returns) > 0) {
    sqrt(252) * mean(returns) / stats::sd(returns)
  } else {
    NA_real_
  }
  lrv <- g5_mr02_long_run_variance(returns)
  adjusted_sharpe <- if (is.finite(lrv) && lrv > 0) {
    sqrt(252) * mean(returns) / sqrt(lrv)
  } else {
    NA_real_
  }
  data.frame(
    bars = nrow(replay),
    cumulative_return = tail(equity, 1L) - 1,
    naive_sharpe = naive_sharpe,
    autocorrelation_adjusted_sharpe = adjusted_sharpe,
    maximum_drawdown = min(drawdown),
    average_gross_exposure = mean(replay$gross_exposure),
    total_turnover = sum(replay$turnover),
    stringsAsFactors = FALSE
  )
}

g5_mr02_not_run_gates <- function() {
  data.frame(
    gate_id = paste0("G", 9:13),
    gate = c(
      "DEVELOPMENT mean net trade return is positive",
      "CONFIRMATION mean net trade return is positive",
      "CONFIRMATION beats random-sign p90",
      "CONFIRMATION stress-cost return is positive",
      "At least two CONFIRMATION calendar years are positive"
    ),
    status = "NOT_RUN",
    details = "TRAIN mechanism gate failure",
    stringsAsFactors = FALSE
  )
}

g5_mr02_run_analysis <- function(
  bars,
  contract = g5_mr02_contract(),
  data_health_status = "PASS"
) {
  contract <- g5_mr02_validate_contract(contract)
  bars <- g5_mr02_validate_bars(bars, contract)
  train_bars <- bars[bars$session_date <= contract$train_end, , drop = FALSE]
  train_indicators <- g5_mr02_signal_states(
    g5_mr02_rolling_indicators(g5_mr02_common_panel(train_bars, contract), contract),
    contract
  )
  train_replay <- g5_mr02_build_replay(train_indicators, contract)
  train_replay <- train_replay[
    train_replay$execution_date >= contract$train_start &
      train_replay$execution_date <= contract$train_end,
    ,
    drop = FALSE
  ]
  train_trades <- g5_mr02_trade_summary(train_replay)
  train_bootstrap <- g5_mr02_trade_bootstrap(train_trades, contract)
  train_random <- g5_mr02_random_sign_control(train_trades, contract)
  train_convergence <- g5_mr02_forward_convergence(train_indicators, contract)
  train_convergence <- train_convergence[
    train_convergence$evaluation_period == "TRAIN",
    ,
    drop = FALSE
  ]
  train_convergence_bootstrap <- g5_mr02_convergence_bootstrap(
    train_convergence, contract
  )
  train_integrity <- g5_mr02_integrity_audit(
    train_bars, train_indicators, train_replay, contract, data_health_status
  )
  train_gates <- g5_mr02_train_gates(
    train_indicators, train_replay, train_trades, train_bootstrap,
    train_random, train_convergence_bootstrap, train_integrity, contract
  )
  train_years <- g5_mr02_year_summary(train_replay)
  train_diagnostics <- g5_mr02_statistical_diagnostics(train_indicators, contract)
  pass <- all(train_gates$status == "PASS")
  base <- list(
    contract = contract,
    train_indicators = train_indicators,
    train_replay = train_replay,
    train_trades = train_trades,
    train_bootstrap = train_bootstrap,
    train_random = train_random,
    train_convergence = train_convergence,
    train_convergence_bootstrap = train_convergence_bootstrap,
    train_integrity = train_integrity,
    train_coverage = g5_mr02_session_coverage_audit(train_bars, contract),
    train_years = train_years,
    train_diagnostics = train_diagnostics,
    train_metrics = g5_mr02_performance_metrics(train_replay),
    train_gates = train_gates
  )
  if (!pass) {
    return(c(base, list(
      later_outcomes_opened = FALSE,
      full_indicators = NULL,
      full_replay = NULL,
      full_trades = NULL,
      later_metrics = NULL,
      gates = rbind(train_gates, g5_mr02_not_run_gates()),
      overall_status = "STOP_LIT_MR_02_1_TRAIN_MECHANISM"
    )))
  }
  full_indicators <- g5_mr02_signal_states(
    g5_mr02_rolling_indicators(g5_mr02_common_panel(bars, contract), contract),
    contract
  )
  full_replay <- g5_mr02_build_replay(full_indicators, contract)
  full_replay <- full_replay[
    full_replay$execution_date >= contract$train_start &
      full_replay$execution_date <= contract$confirmation_end,
    ,
    drop = FALSE
  ]
  full_trades <- g5_mr02_trade_summary(full_replay)
  later_metrics <- do.call(rbind, lapply(
    c("TRAIN", "DEVELOPMENT", "CONFIRMATION"),
    function(period) {
      x <- full_replay[full_replay$evaluation_period == period, , drop = FALSE]
      if (!nrow(x)) return(NULL)
      cbind(evaluation_period = period, g5_mr02_performance_metrics(x))
    }
  ))
  confirmation_trades <- full_trades[
    full_trades$evaluation_period == "CONFIRMATION" & full_trades$completed,
    ,
    drop = FALSE
  ]
  development_trades <- full_trades[
    full_trades$evaluation_period == "DEVELOPMENT" & full_trades$completed,
    ,
    drop = FALSE
  ]
  confirmation_random <- g5_mr02_random_sign_control(
    confirmation_trades, contract, seed_offset = 100L
  )
  confirmation_replay <- full_replay[
    full_replay$evaluation_period == "CONFIRMATION",
    ,
    drop = FALSE
  ]
  confirmation_years <- g5_mr02_year_summary(confirmation_replay)
  later_values <- c(
    nrow(development_trades) > 0 &&
      mean(development_trades$primary_net_additive_return) > 0,
    nrow(confirmation_trades) > 0 &&
      mean(confirmation_trades$primary_net_additive_return) > 0,
    nrow(confirmation_trades) > 0 &&
      mean(confirmation_trades$primary_net_additive_return) > confirmation_random$p90,
    nrow(confirmation_replay) > 0 &&
      prod(1 + confirmation_replay$stress_net_return) - 1 > 0,
    sum(confirmation_years$primary_net_return > 0) >= 2L
  )
  later_gates <- data.frame(
    gate_id = paste0("G", 9:13),
    gate = g5_mr02_not_run_gates()$gate,
    status = ifelse(later_values, "PASS", "FAIL"),
    details = c(
      if (nrow(development_trades)) sprintf(
        "%.6f", mean(development_trades$primary_net_additive_return)
      ) else "no_completed_trades",
      if (nrow(confirmation_trades)) sprintf(
        "%.6f", mean(confirmation_trades$primary_net_additive_return)
      ) else "no_completed_trades",
      if (nrow(confirmation_trades)) sprintf(
        "%.6f vs p90 %.6f",
        mean(confirmation_trades$primary_net_additive_return),
        confirmation_random$p90
      ) else "no_completed_trades",
      sprintf("%.6f", prod(1 + confirmation_replay$stress_net_return) - 1),
      sprintf("%d / %d", sum(confirmation_years$primary_net_return > 0), nrow(confirmation_years))
    ),
    stringsAsFactors = FALSE
  )
  all_gates <- rbind(train_gates, later_gates)
  c(base, list(
    later_outcomes_opened = TRUE,
    full_indicators = full_indicators,
    full_replay = full_replay,
    full_trades = full_trades,
    later_metrics = later_metrics,
    confirmation_random = confirmation_random,
    confirmation_years = confirmation_years,
    gates = all_gates,
    overall_status = if (all(later_gates$status == "PASS")) {
      "PASS_LIT_MR_02_1_LATER_REPLICATION"
    } else {
      "STOP_LIT_MR_02_1_LATER_REPLICATION"
    }
  ))
}
