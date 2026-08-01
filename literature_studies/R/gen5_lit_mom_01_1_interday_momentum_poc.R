# Frozen LIT-MOM-01.1 interday time-series momentum textbook exercise.

g5_mom01_stop <- function(message) {
  stop(message, call. = FALSE)
}

g5_mom01_schema_version <- function() "gen5_lit_mom_01_1_v1"

g5_mom01_contract <- function() {
  list(
    literature_id = "LIT-MOM-01.1",
    descriptive_name = "Interday Time-Series Momentum",
    symbol = "SHY",
    as_of_timestamp = "2026-07-30 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    horizon_grid = c(1L, 5L, 10L, 25L, 60L, 120L, 250L),
    minimum_selected_holding_sessions = 5L,
    minimum_screen_pairs = 20L,
    screen_p_value_maximum = 0.10,
    lookback_sessions = 250L,
    holding_sessions = 25L,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    stress_borrow_bps_annual = 100,
    bootstrap_count = 2000L,
    bootstrap_block_pairs = 5L,
    bootstrap_seed = 6101L,
    minimum_correlation_pairs = 40L,
    minimum_completed_sleeves = 40L,
    minimum_positive_years = 3L
  )
}

g5_mom01_validate_contract <- function(contract = g5_mom01_contract()) {
  frozen <- g5_mom01_contract()
  fields <- names(frozen)
  replication_batch <- attr(contract, "g5_mom01_replication_batch", exact = TRUE)
  if (!is.null(replication_batch)) {
    if (!identical(replication_batch, "STOCK_ATLAS_01")) {
      g5_mom01_stop("Unknown LIT-MOM-01.1 replication batch.")
    }
    if (!identical(names(contract), fields)) {
      g5_mom01_stop("Replication contracts must preserve the frozen field set.")
    }
    symbol <- contract$symbol
    if (!is.character(symbol) || length(symbol) != 1L ||
        is.na(symbol) || !grepl("^[A-Z][A-Z0-9.]{0,9}$", symbol)) {
      g5_mom01_stop("Replication symbol must be one uppercase US equity ticker.")
    }
    contract_for_comparison <- contract
    contract_for_comparison$symbol <- frozen$symbol
    same <- vapply(
      fields,
      function(field) identical(contract_for_comparison[[field]], frozen[[field]]),
      logical(1)
    )
    if (!all(same)) {
      g5_mom01_stop(paste(
        "Frozen LIT-MOM-01.1 replication contract changed:",
        paste(fields[!same], collapse = ", ")
      ))
    }
    return(contract)
  }
  same <- vapply(fields, function(field) identical(contract[[field]], frozen[[field]]), logical(1))
  if (!all(same)) {
    g5_mom01_stop(paste(
      "Frozen LIT-MOM-01.1 contract changed:",
      paste(fields[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom01_replication_contract <- function(
  symbol,
  replication_batch = "STOCK_ATLAS_01"
) {
  contract <- g5_mom01_contract()
  contract$symbol <- as.character(symbol)
  attr(contract, "g5_mom01_replication_batch") <- replication_batch
  g5_mom01_validate_contract(contract)
}

g5_mom01_validate_bars <- function(bars, contract = g5_mom01_contract()) {
  contract <- g5_mom01_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_mom01_stop(paste("Missing required bar columns:", paste(missing, collapse = ", ")))
  }
  out <- bars[bars$symbol == contract$symbol, , drop = FALSE]
  if (!nrow(out)) {
    g5_mom01_stop(paste("No", contract$symbol, "bars were supplied."))
  }
  out$session_date <- as.Date(out$session_date)
  out <- out[order(out$session_date), , drop = FALSE]
  checks <- data.frame(
    check_id = c(
      "single_symbol",
      "strict_date_order",
      "unique_sessions",
      "finite_positive_open_close",
      "adjusted_daily_only",
      "no_confirmation_bars"
    ),
    passed = c(
      identical(unique(out$symbol), contract$symbol),
      all(diff(out$session_date) > 0),
      !anyDuplicated(out$session_date),
      all(is.finite(out$open) & out$open > 0 & is.finite(out$close) & out$close > 0),
      all(out$adjusted %in% TRUE) && all(out$timeframe == "1D"),
      max(out$session_date) < contract$confirmation_start
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  list(bars = out, checks = checks)
}

g5_mom01_lag <- function(x, k) {
  k <- as.integer(k)
  if (k <= 0L) return(x)
  c(rep(NA, k), head(x, -k))
}

g5_mom01_lead <- function(x, k) {
  k <- as.integer(k)
  if (k <= 0L) return(x)
  c(tail(x, -k), rep(NA, k))
}

g5_mom01_signal_panel <- function(
  bars,
  contract = g5_mom01_contract(),
  lookback_sessions = contract$lookback_sessions,
  holding_sessions = contract$holding_sessions
) {
  contract <- g5_mom01_validate_contract(contract)
  checked <- g5_mom01_validate_bars(bars, contract)
  x <- checked$bars
  lookback_sessions <- as.integer(lookback_sessions)
  holding_sessions <- as.integer(holding_sessions)
  lookback_close <- g5_mom01_lag(x$close, lookback_sessions)
  future_close <- g5_mom01_lead(x$close, holding_sessions)
  past_return <- x$close / lookback_close - 1
  future_return <- future_close / x$close - 1
  signal <- ifelse(
    is.na(past_return),
    NA_integer_,
    ifelse(past_return > 0, 1L, ifelse(past_return < 0, -1L, 0L))
  )
  data.frame(
    signal_index = seq_len(nrow(x)),
    signal_date = x$session_date,
    current_close = x$close,
    lookback_close = lookback_close,
    future_close = future_close,
    past_return = past_return,
    future_return = future_return,
    signal = signal,
    future_sign = ifelse(
      is.na(future_return),
      NA_integer_,
      ifelse(future_return > 0, 1L, ifelse(future_return < 0, -1L, 0L))
    ),
    outcome_date = g5_mom01_lead(x$session_date, holding_sessions),
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions,
    stringsAsFactors = FALSE
  )
}

g5_mom01_anchor_pairs <- function(
  signal_panel,
  period_start,
  period_end,
  step_sessions,
  sampling_id
) {
  eligible <- signal_panel[
    signal_panel$signal_date >= as.Date(period_start) &
      signal_panel$outcome_date <= as.Date(period_end) &
      is.finite(signal_panel$past_return) &
      is.finite(signal_panel$future_return),
    ,
    drop = FALSE
  ]
  if (!nrow(eligible)) return(eligible)
  chosen <- seq.int(1L, nrow(eligible), by = as.integer(step_sessions))
  out <- eligible[chosen, , drop = FALSE]
  out$sampling_id <- sampling_id
  out$step_sessions <- as.integer(step_sessions)
  out$direction_correct <- out$signal == out$future_sign
  out
}

g5_mom01_correlation_views <- function(
  signal_panel,
  period_start,
  period_end,
  contract = g5_mom01_contract(),
  lookback_sessions = contract$lookback_sessions,
  holding_sessions = contract$holding_sessions
) {
  contract <- g5_mom01_validate_contract(contract)
  lookback_sessions <- as.integer(lookback_sessions)
  holding_sessions <- as.integer(holding_sessions)
  steps <- c(
    CHAN_MIN_STEP = min(lookback_sessions, holding_sessions),
    STRICT_FULL_PAIR_STEP = lookback_sessions + holding_sessions,
    DAILY_OVERLAPPING = 1L
  )
  pairs <- lapply(names(steps), function(id) {
    g5_mom01_anchor_pairs(
      signal_panel,
      period_start,
      period_end,
      steps[[id]],
      id
    )
  })
  names(pairs) <- names(steps)
  summaries <- lapply(names(pairs), function(id) {
    x <- pairs[[id]]
    test <- if (nrow(x) >= 3L && stats::sd(x$past_return) > 0 &&
      stats::sd(x$future_return) > 0) {
      stats::cor.test(x$past_return, x$future_return, method = "pearson")
    } else {
      NULL
    }
    data.frame(
      sampling_id = id,
      step_sessions = steps[[id]],
      pair_count = nrow(x),
      return_correlation = if (is.null(test)) NA_real_ else unname(test$estimate),
      naive_pearson_p_value = if (is.null(test)) NA_real_ else test$p.value,
      direction_accuracy = if (nrow(x)) mean(x$direction_correct) else NA_real_,
      long_call_precision = if (any(x$signal == 1L)) {
        mean(x$future_sign[x$signal == 1L] == 1L)
      } else {
        NA_real_
      },
      short_call_precision = if (any(x$signal == -1L)) {
        mean(x$future_sign[x$signal == -1L] == -1L)
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  })
  list(pairs = pairs, summary = do.call(rbind, summaries))
}

g5_mom01_horizon_screen <- function(
  bars,
  period_start,
  period_end,
  contract = g5_mom01_contract()
) {
  contract <- g5_mom01_validate_contract(contract)
  rows <- list()
  row_i <- 1L
  for (lookback in contract$horizon_grid) {
    for (holding in contract$horizon_grid) {
      signal_panel <- g5_mom01_signal_panel(
        bars,
        contract,
        lookback_sessions = lookback,
        holding_sessions = holding
      )
      pairs <- g5_mom01_anchor_pairs(
        signal_panel,
        period_start,
        period_end,
        step_sessions = min(lookback, holding),
        sampling_id = "CHAN_MIN_STEP"
      )
      test <- if (
        nrow(pairs) >= 3L &&
          stats::sd(pairs$past_return) > 0 &&
          stats::sd(pairs$future_return) > 0
      ) {
        stats::cor.test(
          pairs$past_return,
          pairs$future_return,
          method = "pearson"
        )
      } else {
        NULL
      }
      correlation <- if (is.null(test)) NA_real_ else unname(test$estimate)
      p_value <- if (is.null(test)) NA_real_ else test$p.value
      t_statistic <- if (
        is.finite(correlation) &&
          abs(correlation) < 1 &&
          nrow(pairs) > 2L
      ) {
        correlation * sqrt((nrow(pairs) - 2) / (1 - correlation^2))
      } else {
        NA_real_
      }
      rows[[row_i]] <- data.frame(
        lookback_sessions = as.integer(lookback),
        holding_sessions = as.integer(holding),
        pair_count = nrow(pairs),
        return_correlation = correlation,
        naive_pearson_p_value = p_value,
        correlation_t_statistic = t_statistic,
        direction_accuracy = if (nrow(pairs)) {
          mean(pairs$direction_correct)
        } else {
          NA_real_
        },
        stringsAsFactors = FALSE
      )
      row_i <- row_i + 1L
    }
  }
  out <- do.call(rbind, rows)
  out$support_eligible <- out$pair_count >= contract$minimum_screen_pairs &
    out$holding_sessions >= contract$minimum_selected_holding_sessions
  out$source_style_admissible <- out$support_eligible &
    is.finite(out$return_correlation) &
    out$return_correlation > 0 &
    is.finite(out$naive_pearson_p_value) &
    out$naive_pearson_p_value <= contract$screen_p_value_maximum
  out
}

g5_mom01_select_horizon <- function(
  horizon_screen,
  contract = g5_mom01_contract()
) {
  contract <- g5_mom01_validate_contract(contract)
  candidates <- horizon_screen[
    horizon_screen$support_eligible &
      is.finite(horizon_screen$correlation_t_statistic),
    ,
    drop = FALSE
  ]
  if (!nrow(candidates)) {
    g5_mom01_stop("No horizon candidate has the frozen minimum support.")
  }
  candidates <- candidates[order(
    -candidates$correlation_t_statistic,
    candidates$holding_sessions,
    candidates$lookback_sessions
  ), , drop = FALSE]
  selected <- candidates[1L, , drop = FALSE]
  selected$selection_rule <- paste(
    "maximum_correlation_t_statistic",
    "tie_shorter_holding_then_lookback",
    sep = ";"
  )
  selected$selected_before_oos <- TRUE
  selected
}

g5_mom01_block_indices <- function(n, block_length) {
  block_length <- min(as.integer(block_length), n)
  starts <- sample.int(n, ceiling(n / block_length), replace = TRUE)
  indices <- unlist(lapply(starts, function(start) {
    ((start - 1L + seq_len(block_length) - 1L) %% n) + 1L
  }), use.names = FALSE)
  indices[seq_len(n)]
}

g5_mom01_bootstrap_correlation <- function(
  pairs,
  contract = g5_mom01_contract()
) {
  contract <- g5_mom01_validate_contract(contract)
  if (nrow(pairs) < 3L) g5_mom01_stop("At least three pairs are required for bootstrap.")
  set.seed(contract$bootstrap_seed)
  draws <- replicate(contract$bootstrap_count, {
    idx <- g5_mom01_block_indices(nrow(pairs), contract$bootstrap_block_pairs)
    stats::cor(pairs$past_return[idx], pairs$future_return[idx])
  })
  data.frame(
    metric = "return_correlation",
    estimate = stats::cor(pairs$past_return, pairs$future_return),
    lower_90 = unname(stats::quantile(draws, 0.10, na.rm = TRUE)),
    median = unname(stats::quantile(draws, 0.50, na.rm = TRUE)),
    upper_90 = unname(stats::quantile(draws, 0.90, na.rm = TRUE)),
    block_pairs = contract$bootstrap_block_pairs,
    draw_count = contract$bootstrap_count,
    stringsAsFactors = FALSE
  )
}

g5_mom01_completed_sleeves <- function(
  bars,
  period_start,
  period_end,
  contract = g5_mom01_contract(),
  lookback_sessions = contract$lookback_sessions,
  holding_sessions = contract$holding_sessions
) {
  contract <- g5_mom01_validate_contract(contract)
  checked <- g5_mom01_validate_bars(bars, contract)
  x <- checked$bars
  holding_sessions <- as.integer(holding_sessions)
  signal_panel <- g5_mom01_signal_panel(
    x,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  entries <- which(
    signal_panel$signal_date >= as.Date(period_start) &
      signal_panel$signal_date < as.Date(period_end) &
      !is.na(signal_panel$signal) &
      signal_panel$signal != 0L
  )
  rows <- lapply(entries, function(i) {
    entry_i <- i + 1L
    exit_i <- entry_i + holding_sessions
    if (exit_i > nrow(x) || x$session_date[[exit_i]] > as.Date(period_end)) return(NULL)
    direction <- signal_panel$signal[[i]]
    gross <- direction * (x$open[[exit_i]] / x$open[[entry_i]] - 1)
    data.frame(
      signal_date = x$session_date[[i]],
      entry_date = x$session_date[[entry_i]],
      exit_date = x$session_date[[exit_i]],
      direction = direction,
      direction_label = ifelse(direction > 0, "LONG", "SHORT"),
      past_lookback_return = signal_panel$past_return[[i]],
      underlying_holding_open_return = x$open[[exit_i]] / x$open[[entry_i]] - 1,
      gross_sleeve_return = gross,
      primary_net_sleeve_return = gross - 2 * contract$primary_cost_bps / 10000,
      stress_net_sleeve_return = gross -
        2 * contract$stress_cost_bps / 10000 -
        ifelse(direction < 0, contract$stress_borrow_bps_annual / 10000 *
          holding_sessions / 252, 0),
      direction_correct = sign(x$open[[exit_i]] / x$open[[entry_i]] - 1) == direction,
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) {
    return(data.frame(
      signal_date = as.Date(character()),
      entry_date = as.Date(character()),
      exit_date = as.Date(character()),
      direction = integer(),
      direction_label = character(),
      past_lookback_return = numeric(),
      underlying_holding_open_return = numeric(),
      gross_sleeve_return = numeric(),
      primary_net_sleeve_return = numeric(),
      stress_net_sleeve_return = numeric(),
      direction_correct = logical(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

g5_mom01_replay_period <- function(
  bars,
  period_start,
  period_end,
  cost_bps,
  borrow_bps_annual = 0,
  contract = g5_mom01_contract(),
  lookback_sessions = contract$lookback_sessions,
  holding_sessions = contract$holding_sessions
) {
  contract <- g5_mom01_validate_contract(contract)
  checked <- g5_mom01_validate_bars(bars, contract)
  x <- checked$bars
  holding_sessions <- as.integer(holding_sessions)
  signals <- g5_mom01_signal_panel(
    x,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  interval_i <- which(
    x$session_date >= as.Date(period_start) &
      g5_mom01_lead(x$session_date, 1L) <= as.Date(period_end)
  )
  if (!length(interval_i)) g5_mom01_stop("No complete open-to-open intervals in period.")
  position <- numeric(length(interval_i))
  for (j in seq_along(interval_i)) {
    i <- interval_i[[j]]
    prior <- seq.int(max(1L, i - holding_sessions), i - 1L)
    prior <- prior[signals$signal_date[prior] >= as.Date(period_start)]
    active <- signals$signal[prior]
    active <- active[!is.na(active)]
    position[[j]] <- sum(active) / holding_sessions
  }
  prior_position <- c(0, head(position, -1L))
  turnover <- abs(position - prior_position)
  turnover[[length(turnover)]] <- turnover[[length(turnover)]] + abs(position[[length(position)]])
  underlying_return <- x$open[interval_i + 1L] / x$open[interval_i] - 1
  gross_return <- position * underlying_return
  short_borrow <- pmax(-position, 0) * borrow_bps_annual / 10000 / 252
  net_return <- gross_return - turnover * cost_bps / 10000 - short_borrow
  wealth <- cumprod(1 + net_return)
  peak <- cummax(c(1, wealth))[-1L]
  drawdown <- wealth / peak - 1
  data.frame(
    entry_date = x$session_date[interval_i],
    outcome_date = x$session_date[interval_i + 1L],
    position = position,
    long_exposure = pmax(position, 0),
    short_exposure = pmax(-position, 0),
    turnover = turnover,
    underlying_open_return = underlying_return,
    gross_return = gross_return,
    transaction_cost = turnover * cost_bps / 10000,
    borrow_cost = short_borrow,
    net_return = net_return,
    wealth = wealth,
    drawdown = drawdown,
    stringsAsFactors = FALSE
  )
}

g5_mom01_lo_sharpe <- function(returns, max_lag = 5L) {
  returns <- returns[is.finite(returns)]
  if (length(returns) < 3L || stats::sd(returns) == 0) return(NA_real_)
  max_lag <- min(as.integer(max_lag), length(returns) - 1L)
  rho <- if (max_lag > 0L) {
    vapply(seq_len(max_lag), function(k) {
      stats::cor(returns[(k + 1L):length(returns)], returns[1L:(length(returns) - k)])
    }, numeric(1))
  } else {
    numeric()
  }
  denominator <- sqrt(max(1e-12, 1 + 2 * sum((1 - seq_along(rho) / (max_lag + 1)) * rho)))
  sqrt(252) * mean(returns) / stats::sd(returns) / denominator
}

g5_mom01_metrics <- function(replay, strategy_id) {
  returns <- replay$net_return
  wealth <- cumprod(1 + returns)
  years <- max(1 / 252, length(returns) / 252)
  data.frame(
    strategy_id = strategy_id,
    interval_count = length(returns),
    cumulative_return = tail(wealth, 1) - 1,
    annualized_compound_return = tail(wealth, 1)^(1 / years) - 1,
    annualized_volatility = stats::sd(returns) * sqrt(252),
    naive_sharpe = ifelse(stats::sd(returns) > 0, sqrt(252) * mean(returns) / stats::sd(returns), NA_real_),
    autocorrelation_adjusted_sharpe = g5_mom01_lo_sharpe(returns),
    maximum_drawdown = min(replay$drawdown),
    average_net_exposure = mean(replay$position),
    average_gross_exposure = mean(abs(replay$position)),
    total_turnover = sum(replay$turnover),
    stringsAsFactors = FALSE
  )
}

g5_mom01_calendar_years <- function(replay, return_column = "net_return") {
  year <- format(replay$outcome_date, "%Y")
  groups <- split(replay[[return_column]], year)
  rows <- Map(function(x, year_id) {
    data.frame(
      calendar_year = year_id,
      interval_count = length(x),
      cumulative_return = prod(1 + x) - 1,
      stringsAsFactors = FALSE
    )
  }, groups, names(groups))
  do.call(rbind, rows)
}

g5_mom01_source_style_replay <- function(
  bars,
  period_start,
  period_end,
  contract = g5_mom01_contract(),
  lookback_sessions = contract$lookback_sessions,
  holding_sessions = contract$holding_sessions
) {
  contract <- g5_mom01_validate_contract(contract)
  checked <- g5_mom01_validate_bars(bars, contract)
  x <- checked$bars
  holding_sessions <- as.integer(holding_sessions)
  signals <- g5_mom01_signal_panel(
    x,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  interval_i <- which(
    x$session_date > as.Date(period_start) &
      x$session_date <= as.Date(period_end)
  )
  position <- numeric(length(interval_i))
  for (j in seq_along(interval_i)) {
    i <- interval_i[[j]]
    prior <- seq.int(max(1L, i - holding_sessions), i - 1L)
    prior <- prior[signals$signal_date[prior] >= as.Date(period_start)]
    active <- signals$signal[prior]
    active <- active[!is.na(active)]
    position[[j]] <- sum(active) / holding_sessions
  }
  close_return <- x$close[interval_i] / x$close[interval_i - 1L] - 1
  strategy_return <- position * close_return
  data.frame(
    session_date = x$session_date[interval_i],
    position = position,
    underlying_close_return = close_return,
    strategy_return = strategy_return,
    wealth = cumprod(1 + strategy_return),
    stringsAsFactors = FALSE
  )
}

g5_mom01_buy_hold_context <- function(bars, period_start, period_end) {
  x <- bars[
    bars$session_date >= as.Date(period_start) &
      bars$session_date <= as.Date(period_end),
    ,
    drop = FALSE
  ]
  x <- x[order(x$session_date), , drop = FALSE]
  returns <- c(NA_real_, x$open[-1L] / head(x$open, -1L) - 1)
  wealth <- cumprod(1 + ifelse(is.na(returns), 0, returns))
  data.frame(
    session_date = x$session_date,
    return = returns,
    wealth = wealth,
    drawdown = wealth / cummax(wealth) - 1,
    stringsAsFactors = FALSE
  )
}

g5_mom01_direction_confusion <- function(pairs) {
  predicted <- factor(ifelse(pairs$signal > 0, "UP", "DOWN"), levels = c("UP", "DOWN"))
  actual <- factor(ifelse(pairs$future_sign > 0, "UP", "DOWN"), levels = c("UP", "DOWN"))
  table <- as.data.frame.matrix(table(predicted = predicted, actual = actual))
  table$predicted <- rownames(table)
  rownames(table) <- NULL
  table[, c("predicted", "UP", "DOWN"), drop = FALSE]
}

g5_mom01_analyze_period <- function(
  bars,
  period_start,
  period_end,
  period_id,
  contract = g5_mom01_contract(),
  lookback_sessions = contract$lookback_sessions,
  holding_sessions = contract$holding_sessions
) {
  contract <- g5_mom01_validate_contract(contract)
  checked <- g5_mom01_validate_bars(bars, contract)
  lookback_sessions <- as.integer(lookback_sessions)
  holding_sessions <- as.integer(holding_sessions)
  signal_panel <- g5_mom01_signal_panel(
    checked$bars,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  correlations <- g5_mom01_correlation_views(
    signal_panel,
    period_start,
    period_end,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  chan_pairs <- correlations$pairs$CHAN_MIN_STEP
  bootstrap <- g5_mom01_bootstrap_correlation(chan_pairs, contract)
  sleeves <- g5_mom01_completed_sleeves(
    checked$bars,
    period_start,
    period_end,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  gross <- g5_mom01_replay_period(
    checked$bars,
    period_start,
    period_end,
    0,
    0,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  primary <- g5_mom01_replay_period(
    checked$bars,
    period_start,
    period_end,
    contract$primary_cost_bps,
    0,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  stress <- g5_mom01_replay_period(
    checked$bars,
    period_start,
    period_end,
    contract$stress_cost_bps,
    contract$stress_borrow_bps_annual,
    contract,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  gross$cost_regime <- "GROSS"
  primary$cost_regime <- "PRIMARY"
  stress$cost_regime <- "STRESS"
  metrics <- rbind(
    g5_mom01_metrics(gross, "GROSS"),
    g5_mom01_metrics(primary, "PRIMARY"),
    g5_mom01_metrics(stress, "STRESS")
  )
  years <- g5_mom01_calendar_years(primary)
  years$period_id <- period_id
  list(
    period_id = period_id,
    period_start = as.Date(period_start),
    period_end = as.Date(period_end),
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions,
    integrity = checked$checks,
    signal_panel = signal_panel,
    correlation_pairs = do.call(rbind, correlations$pairs),
    correlation_summary = correlations$summary,
    correlation_bootstrap = bootstrap,
    direction_confusion = g5_mom01_direction_confusion(chan_pairs),
    sleeves = sleeves,
    replay = rbind(gross, primary, stress),
    metrics = metrics,
    calendar_years = years,
    buy_hold = g5_mom01_buy_hold_context(checked$bars, period_start, period_end),
    source_style = g5_mom01_source_style_replay(
      checked$bars,
      period_start,
      period_end,
      contract,
      lookback_sessions = lookback_sessions,
      holding_sessions = holding_sessions
    )
  )
}

g5_mom01_train_gates <- function(
  train,
  selected_candidate,
  contract = g5_mom01_contract()
) {
  contract <- g5_mom01_validate_contract(contract)
  chan <- train$correlation_summary[
    train$correlation_summary$sampling_id == "CHAN_MIN_STEP",
    ,
    drop = FALSE
  ]
  primary <- train$metrics[train$metrics$strategy_id == "PRIMARY", , drop = FALSE]
  stress <- train$metrics[train$metrics$strategy_id == "STRESS", , drop = FALSE]
  positive_years <- sum(train$calendar_years$cumulative_return > 0)
  gates <- data.frame(
    gate_id = paste0("G", 1:6),
    gate = c(
      "Integrity and causal timing",
      "Horizon screen support and admissibility",
      "Selected-rule independent-outcome and sleeve support",
      "Past-sign versus future-sign accuracy above chance",
      "Positive primary-cost return and adjusted Sharpe",
      "Positive stress return and calendar stability"
    ),
    passed = c(
      all(train$integrity$passed),
      selected_candidate$source_style_admissible,
      chan$pair_count >= contract$minimum_correlation_pairs &&
        nrow(train$sleeves) >= contract$minimum_completed_sleeves,
      is.finite(chan$direction_accuracy) && chan$direction_accuracy > 0.5,
      primary$cumulative_return > 0 &&
        primary$autocorrelation_adjusted_sharpe > 0,
      stress$cumulative_return > 0 &&
        positive_years >= contract$minimum_positive_years
    ),
    value = c(
      paste(sum(train$integrity$passed), "of", nrow(train$integrity), "checks pass"),
      sprintf(
        "%d/%d selected; r=%.4f; p=%.4f; n=%d",
        selected_candidate$lookback_sessions,
        selected_candidate$holding_sessions,
        selected_candidate$return_correlation,
        selected_candidate$naive_pearson_p_value,
        selected_candidate$pair_count
      ),
      paste(chan$pair_count, "pairs;", nrow(train$sleeves), "completed sleeves"),
      sprintf("%.1f%%", 100 * chan$direction_accuracy),
      sprintf(
        "return %.2f%%; adjusted Sharpe %.2f",
        100 * primary$cumulative_return,
        primary$autocorrelation_adjusted_sharpe
      ),
      sprintf(
        "stress %.2f%%; %d positive years",
        100 * stress$cumulative_return,
        positive_years
      )
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  gates
}

g5_mom01_run_train <- function(bars, contract = g5_mom01_contract()) {
  contract <- g5_mom01_validate_contract(contract)
  horizon_screen <- g5_mom01_horizon_screen(
    bars,
    contract$train_start,
    contract$train_end,
    contract
  )
  selected_candidate <- g5_mom01_select_horizon(horizon_screen, contract)
  train <- g5_mom01_analyze_period(
    bars,
    contract$train_start,
    contract$train_end,
    "TRAIN",
    contract,
    lookback_sessions = selected_candidate$lookback_sessions,
    holding_sessions = selected_candidate$holding_sessions
  )
  canonical_250_25 <- g5_mom01_analyze_period(
    bars,
    contract$train_start,
    contract$train_end,
    "TRAIN_CANON_250_25",
    contract,
    lookback_sessions = contract$lookback_sessions,
    holding_sessions = contract$holding_sessions
  )
  gates <- g5_mom01_train_gates(train, selected_candidate, contract)
  list(
    contract = contract,
    horizon_screen = horizon_screen,
    selected_candidate = selected_candidate,
    train = train,
    canonical_250_25 = canonical_250_25,
    gates = gates,
    development_authorized = all(gates$passed),
    overall_status = if (all(gates$passed)) {
      "PASS_LIT_MOM_01_1_TRAIN_TO_DEVELOPMENT"
    } else {
      "STOP_LIT_MOM_01_1_TRAIN"
    }
  )
}

g5_mom01_run_development <- function(
  bars,
  train_result,
  contract = g5_mom01_contract()
) {
  contract <- g5_mom01_validate_contract(contract)
  if (!isTRUE(train_result$development_authorized)) {
    g5_mom01_stop("DEVELOPMENT is sealed because the TRAIN gates did not all pass.")
  }
  g5_mom01_analyze_period(
    bars,
    contract$development_start,
    contract$development_end,
    "DEVELOPMENT",
    contract,
    lookback_sessions = train_result$selected_candidate$lookback_sessions,
    holding_sessions = train_result$selected_candidate$holding_sessions
  )
}
