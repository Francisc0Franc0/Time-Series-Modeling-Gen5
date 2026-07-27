# Gen5 T1 multi-asset trend persistence POC helpers.

g5_t1_schema_version <- function() {
  "gen5_t1_multi_asset_trend_v0.1"
}

g5_t1_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) {
    g5_stop(message)
  }
  stop(message, call. = FALSE)
}

g5_t1_contract <- function() {
  list(
    risk_assets = c(
      "SPY", "IWM", "EFA", "EEM", "TLT", "IEF", "LQD",
      "HYG", "GLD", "SLV", "DBC", "UUP", "VNQ", "XLE"
    ),
    cash_proxy = "BIL",
    reference_symbol = "SPY",
    primary_lookback_months = 12L,
    diagnostic_lookbacks = c(9L, 15L),
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    decision_start = as.Date("2017-01-01"),
    development_end = as.Date("2021-12-31"),
    confirmation_start = as.Date("2022-01-01"),
    confirmation_end = as.Date("2024-12-31"),
    shadow_start = as.Date("2025-01-01"),
    decision_end = as.Date("2026-06-30"),
    as_of_timestamp = "2026-07-27 17:30:00",
    query_start = as.Date("2016-01-01"),
    query_end = as.Date("2026-07-01"),
    decision_time = "17:30 America/New_York",
    pass_asset_count = 8L,
    drawdown_reduction = 0.10,
    return_sacrifice = 0.02,
    contribution_cap = 0.35
  )
}

g5_t1_required_symbols <- function(contract = g5_t1_contract()) {
  unique(c(contract$risk_assets, contract$cash_proxy))
}

g5_t1_validate_contract <- function(contract) {
  required <- c(
    "risk_assets", "cash_proxy", "reference_symbol",
    "primary_lookback_months", "diagnostic_lookbacks",
    "primary_cost_bps", "stress_cost_bps", "decision_start",
    "development_end", "confirmation_start", "confirmation_end",
    "shadow_start", "decision_end", "as_of_timestamp", "query_start",
    "query_end", "pass_asset_count", "drawdown_reduction",
    "return_sacrifice", "contribution_cap"
  )
  missing <- setdiff(required, names(contract))
  if (length(missing)) {
    g5_t1_stop(paste("T1 contract is missing:", paste(missing, collapse = ", ")))
  }
  contract$risk_assets <- toupper(as.character(contract$risk_assets))
  contract$cash_proxy <- toupper(as.character(contract$cash_proxy[[1L]]))
  contract$reference_symbol <- toupper(as.character(contract$reference_symbol[[1L]]))
  if (length(contract$risk_assets) != 14L ||
      length(unique(contract$risk_assets)) != 14L) {
    g5_t1_stop("T1 requires exactly fourteen unique risk assets.")
  }
  if (contract$cash_proxy %in% contract$risk_assets) {
    g5_t1_stop("T1 cash proxy cannot also be a risk asset.")
  }
  if (!contract$reference_symbol %in% contract$risk_assets) {
    g5_t1_stop("T1 reference symbol must be one of the frozen risk assets.")
  }
  if (!identical(as.integer(contract$primary_lookback_months), 12L)) {
    g5_t1_stop("T1 primary lookback must remain twelve month-ends.")
  }
  if (!identical(sort(as.integer(contract$diagnostic_lookbacks)), c(9L, 15L))) {
    g5_t1_stop("T1 diagnostic lookbacks must remain nine and fifteen month-ends.")
  }
  if (!identical(as.numeric(contract$primary_cost_bps), 5) ||
      !identical(as.numeric(contract$stress_cost_bps), 10)) {
    g5_t1_stop("T1 cost assumptions must remain 5 bp primary and 10 bp stress.")
  }
  contract
}

g5_t1_validate_bars <- function(bars, contract = g5_t1_contract()) {
  contract <- g5_t1_validate_contract(contract)
  if (!is.data.frame(bars) || !nrow(bars)) {
    g5_t1_stop("T1 requires a non-empty adjusted daily bar table.")
  }
  if (exists("g5_validate_bar_data", mode = "function")) {
    bars <- g5_validate_bar_data(bars)
  }
  required <- c("symbol", "session_date", "open", "close")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_t1_stop(paste("T1 bars are missing:", paste(missing, collapse = ", ")))
  }
  bars$symbol <- toupper(as.character(bars$symbol))
  bars$session_date <- as.Date(bars$session_date)
  bars$open <- as.numeric(bars$open)
  bars$close <- as.numeric(bars$close)
  if (any(is.na(bars$session_date))) g5_t1_stop("T1 bars contain invalid dates.")
  if (any(!is.finite(bars$open) | bars$open <= 0, na.rm = TRUE) ||
      any(!is.finite(bars$close) | bars$close <= 0, na.rm = TRUE)) {
    g5_t1_stop("T1 bars contain non-positive finite prices.")
  }
  key <- paste(bars$symbol, bars$session_date)
  if (anyDuplicated(key)) g5_t1_stop("T1 bars contain duplicate symbol/session rows.")
  required_symbols <- g5_t1_required_symbols(contract)
  missing_symbols <- setdiff(required_symbols, unique(bars$symbol))
  if (length(missing_symbols)) {
    g5_t1_stop(paste("T1 bars are missing symbols:", paste(missing_symbols, collapse = ", ")))
  }
  bars <- bars[bars$symbol %in% required_symbols, , drop = FALSE]
  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

g5_t1_month_id <- function(date) {
  format(as.Date(date), "%Y-%m")
}

g5_t1_reference_sessions <- function(bars, contract = g5_t1_contract()) {
  contract <- g5_t1_validate_contract(contract)
  sessions <- sort(unique(as.Date(
    bars$session_date[bars$symbol == contract$reference_symbol]
  )))
  if (!length(sessions)) {
    g5_t1_stop("T1 reference symbol did not supply any market sessions.")
  }
  sessions
}

g5_t1_month_end_schedule <- function(bars, contract = g5_t1_contract()) {
  contract <- g5_t1_validate_contract(contract)
  bars <- g5_t1_validate_bars(bars, contract)
  sessions <- g5_t1_reference_sessions(bars, contract)
  sessions <- sessions[
    sessions >= contract$query_start &
      sessions <= contract$query_end
  ]
  ids <- g5_t1_month_id(sessions)
  month_ends <- as.Date(vapply(
    split(sessions, ids),
    function(x) as.character(max(as.Date(x))),
    character(1L)
  ))
  month_ends <- sort(month_ends[month_ends <= contract$decision_end])
  if (!length(month_ends)) g5_t1_stop("T1 found no completed month-ends.")
  next_session <- vapply(month_ends, function(decision_date) {
    future <- sessions[sessions > decision_date]
    if (!length(future)) return(NA_character_)
    as.character(future[[1L]])
  }, character(1L))
  out <- data.frame(
    month_id = g5_t1_month_id(month_ends),
    decision_date = month_ends,
    execution_date = as.Date(next_session),
    stringsAsFactors = FALSE
  )
  out$next_execution_date <- c(out$execution_date[-1L], as.Date(NA))
  out$prior_9m_date <- c(rep(as.Date(NA), 9L), out$decision_date[seq_len(max(0L, nrow(out) - 9L))])
  out$prior_12m_date <- c(rep(as.Date(NA), 12L), out$decision_date[seq_len(max(0L, nrow(out) - 12L))])
  out$prior_15m_date <- c(rep(as.Date(NA), 15L), out$decision_date[seq_len(max(0L, nrow(out) - 15L))])
  out
}

g5_t1_price_index <- function(bars, column) {
  if (!column %in% names(bars)) g5_t1_stop(paste("Missing price column:", column))
  values <- as.numeric(bars[[column]])
  names(values) <- paste(bars$symbol, as.Date(bars$session_date), sep = "|")
  values
}

g5_t1_lookup <- function(index, symbol, date) {
  if (is.na(date)) return(NA_real_)
  value <- unname(index[paste(symbol, as.Date(date), sep = "|")])
  if (!length(value) || !is.finite(value[[1L]])) NA_real_ else as.numeric(value[[1L]])
}

g5_t1_period_id <- function(decision_date, contract = g5_t1_contract()) {
  decision_date <- as.Date(decision_date)
  ifelse(
    decision_date <= contract$development_end,
    "development_2017_2021",
    ifelse(
      decision_date >= contract$confirmation_start &
        decision_date <= contract$confirmation_end,
      "confirmation_2022_2024",
      ifelse(
        decision_date >= contract$shadow_start,
        "historical_shadow_2025_2026",
        "outside_contract"
      )
    )
  )
}

g5_t1_build_observation_panel <- function(
  bars,
  lookback_months = 12L,
  contract = g5_t1_contract()
) {
  contract <- g5_t1_validate_contract(contract)
  lookback_months <- as.integer(lookback_months)
  if (!lookback_months %in% c(9L, 12L, 15L)) {
    g5_t1_stop("T1 lookback must be one of 9, 12, or 15 month-ends.")
  }
  bars <- g5_t1_validate_bars(bars, contract)
  schedule <- g5_t1_month_end_schedule(bars, contract)
  prior_column <- paste0("prior_", lookback_months, "m_date")
  close_index <- g5_t1_price_index(bars, "close")
  open_index <- g5_t1_price_index(bars, "open")
  rows <- vector("list", nrow(schedule) * length(contract$risk_assets))
  row_i <- 0L
  for (schedule_i in seq_len(nrow(schedule))) {
    decision_date <- schedule$decision_date[[schedule_i]]
    if (decision_date < contract$decision_start) next
    prior_date <- schedule[[prior_column]][[schedule_i]]
    execution_date <- schedule$execution_date[[schedule_i]]
    next_execution_date <- schedule$next_execution_date[[schedule_i]]
    cash_close <- g5_t1_lookup(close_index, contract$cash_proxy, decision_date)
    cash_prior_close <- g5_t1_lookup(close_index, contract$cash_proxy, prior_date)
    cash_entry_open <- g5_t1_lookup(open_index, contract$cash_proxy, execution_date)
    cash_exit_open <- g5_t1_lookup(open_index, contract$cash_proxy, next_execution_date)
    cash_trend <- if (all(is.finite(c(cash_close, cash_prior_close)))) {
      log(cash_close / cash_prior_close)
    } else {
      NA_real_
    }
    cash_return <- if (all(is.finite(c(cash_entry_open, cash_exit_open)))) {
      cash_exit_open / cash_entry_open - 1
    } else {
      NA_real_
    }
    for (symbol in contract$risk_assets) {
      row_i <- row_i + 1L
      asset_close <- g5_t1_lookup(close_index, symbol, decision_date)
      asset_prior_close <- g5_t1_lookup(close_index, symbol, prior_date)
      asset_entry_open <- g5_t1_lookup(open_index, symbol, execution_date)
      asset_exit_open <- g5_t1_lookup(open_index, symbol, next_execution_date)
      asset_trend <- if (all(is.finite(c(asset_close, asset_prior_close)))) {
        log(asset_close / asset_prior_close)
      } else {
        NA_real_
      }
      trend_excess <- asset_trend - cash_trend
      eligible_signal <- all(is.finite(c(
        asset_close, asset_prior_close, cash_close, cash_prior_close,
        asset_entry_open, cash_entry_open
      )))
      eligible_outcome <- eligible_signal && all(is.finite(c(
        asset_exit_open, cash_exit_open
      )))
      asset_return <- if (eligible_outcome) {
        asset_exit_open / asset_entry_open - 1
      } else {
        NA_real_
      }
      rows[[row_i]] <- data.frame(
        schema_version = g5_t1_schema_version(),
        lookback_months = lookback_months,
        symbol = symbol,
        month_id = schedule$month_id[[schedule_i]],
        decision_date = decision_date,
        decision_time = contract$decision_time,
        prior_month_end_date = prior_date,
        execution_date = execution_date,
        outcome_end_date = next_execution_date,
        evaluation_period = g5_t1_period_id(decision_date, contract),
        asset_close = asset_close,
        asset_prior_close = asset_prior_close,
        cash_close = cash_close,
        cash_prior_close = cash_prior_close,
        asset_trend_log_return = asset_trend,
        cash_trend_log_return = cash_trend,
        trend_excess_log_return = trend_excess,
        eligible_signal = eligible_signal,
        signal = if (eligible_signal) {
          if (trend_excess > 0) "ON" else "OFF"
        } else {
          "INELIGIBLE"
        },
        asset_entry_open = asset_entry_open,
        asset_exit_open = asset_exit_open,
        cash_entry_open = cash_entry_open,
        cash_exit_open = cash_exit_open,
        eligible_outcome = eligible_outcome,
        asset_next_month_return = asset_return,
        cash_next_month_return = cash_return,
        asset_minus_cash_next_month_return = asset_return - cash_return,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows[seq_len(row_i)])
  rownames(out) <- NULL
  out[order(out$decision_date, match(out$symbol, contract$risk_assets)), , drop = FALSE]
}

g5_t1_weight_row <- function(panel_month, strategy, contract = g5_t1_contract()) {
  contract <- g5_t1_validate_contract(contract)
  symbols <- g5_t1_required_symbols(contract)
  weights <- setNames(rep(0, length(symbols)), symbols)
  if (!all(contract$risk_assets %in% panel_month$symbol)) {
    g5_t1_stop("T1 panel month is missing one or more frozen risk assets.")
  }
  signal_on <- panel_month$signal[match(contract$risk_assets, panel_month$symbol)] == "ON"
  on_count <- sum(signal_on)
  if (identical(strategy, "t1_trend")) {
    weights[contract$risk_assets] <- as.numeric(signal_on) / length(contract$risk_assets)
    weights[[contract$cash_proxy]] <- 1 - sum(weights[contract$risk_assets])
  } else if (identical(strategy, "static_equal_weight")) {
    weights[contract$risk_assets] <- 1 / length(contract$risk_assets)
  } else if (identical(strategy, "cash_bil")) {
    weights[[contract$cash_proxy]] <- 1
  } else if (identical(strategy, "exposure_matched_equal_weight")) {
    risky_fraction <- on_count / length(contract$risk_assets)
    weights[contract$risk_assets] <- risky_fraction / length(contract$risk_assets)
    weights[[contract$cash_proxy]] <- 1 - risky_fraction
  } else {
    g5_t1_stop(paste("Unknown T1 strategy:", strategy))
  }
  if (abs(sum(weights) - 1) > 1e-10 || any(weights < -1e-12)) {
    g5_t1_stop("T1 strategy weights must be long-only and sum to one.")
  }
  weights
}

g5_t1_portfolio_replay <- function(
  panel,
  cost_bps = 5,
  contract = g5_t1_contract()
) {
  contract <- g5_t1_validate_contract(contract)
  if (!is.data.frame(panel) || !nrow(panel)) g5_t1_stop("T1 panel is empty.")
  strategies <- c(
    "t1_trend", "static_equal_weight", "cash_bil",
    "exposure_matched_equal_weight"
  )
  month_dates <- sort(unique(panel$decision_date[panel$eligible_outcome]))
  month_dates <- month_dates[vapply(month_dates, function(date) {
    part <- panel[panel$decision_date == date, , drop = FALSE]
    nrow(part) == length(contract$risk_assets) && all(part$eligible_outcome)
  }, logical(1L))]
  if (!length(month_dates)) g5_t1_stop("T1 has no complete matured holding periods.")
  previous_weights <- setNames(
    replicate(length(strategies), setNames(rep(0, length(g5_t1_required_symbols(contract))), g5_t1_required_symbols(contract)), simplify = FALSE),
    strategies
  )
  wealth <- setNames(rep(1, length(strategies)), strategies)
  rows <- list()
  weight_rows <- list()
  cost_rate <- as.numeric(cost_bps) / 10000
  for (decision_date in month_dates) {
    part <- panel[panel$decision_date == decision_date, , drop = FALSE]
    part <- part[match(contract$risk_assets, part$symbol), , drop = FALSE]
    returns <- setNames(
      c(part$asset_next_month_return, part$cash_next_month_return[[1L]]),
      g5_t1_required_symbols(contract)
    )
    if (any(!is.finite(returns))) {
      g5_t1_stop(paste("T1 matured period contains missing returns at", decision_date))
    }
    for (strategy in strategies) {
      weights <- g5_t1_weight_row(part, strategy, contract)
      gross_return <- sum(weights * returns)
      gross_traded_notional <- sum(abs(weights - previous_weights[[strategy]]))
      conventional_turnover <- gross_traded_notional / 2
      implementation_cost <- cost_rate * gross_traded_notional
      net_return <- (1 - implementation_cost) * (1 + gross_return) - 1
      wealth[[strategy]] <- wealth[[strategy]] * (1 + net_return)
      risky_exposure <- sum(weights[contract$risk_assets])
      rows[[length(rows) + 1L]] <- data.frame(
        schema_version = g5_t1_schema_version(),
        strategy_id = strategy,
        cost_bps = as.numeric(cost_bps),
        decision_date = as.Date(decision_date),
        execution_date = part$execution_date[[1L]],
        outcome_end_date = part$outcome_end_date[[1L]],
        evaluation_period = part$evaluation_period[[1L]],
        on_count = sum(part$signal == "ON"),
        risky_exposure = risky_exposure,
        gross_return = gross_return,
        gross_traded_notional = gross_traded_notional,
        conventional_turnover = conventional_turnover,
        implementation_cost = implementation_cost,
        net_return = net_return,
        wealth = wealth[[strategy]],
        stringsAsFactors = FALSE
      )
      weight_rows[[length(weight_rows) + 1L]] <- data.frame(
        schema_version = g5_t1_schema_version(),
        strategy_id = strategy,
        cost_bps = as.numeric(cost_bps),
        decision_date = as.Date(decision_date),
        symbol = names(weights),
        weight = as.numeric(weights),
        stringsAsFactors = FALSE
      )
      previous_weights[[strategy]] <- weights
    }
  }
  replay <- do.call(rbind, rows)
  replay$drawdown <- ave(
    replay$wealth,
    replay$strategy_id,
    FUN = function(x) x / cummax(c(1, x))[-1L] - 1
  )
  list(
    replay = replay,
    weights = do.call(rbind, weight_rows)
  )
}

g5_t1_metrics <- function(replay, evaluation_period = NULL) {
  if (!is.data.frame(replay) || !nrow(replay)) g5_t1_stop("T1 replay is empty.")
  x <- replay
  if (!is.null(evaluation_period)) {
    x <- x[x$evaluation_period %in% evaluation_period, , drop = FALSE]
  }
  strategies <- unique(x$strategy_id)
  rows <- lapply(strategies, function(strategy) {
    part <- x[x$strategy_id == strategy, , drop = FALSE]
    part <- part[order(part$decision_date), , drop = FALSE]
    n <- nrow(part)
    cumulative <- prod(1 + part$net_return) - 1
    cagr <- if (n > 0L) (1 + cumulative)^(12 / n) - 1 else NA_real_
    wealth <- cumprod(1 + part$net_return)
    drawdown <- wealth / cummax(c(1, wealth))[-1L] - 1
    max_drawdown <- min(drawdown, na.rm = TRUE)
    data.frame(
      schema_version = g5_t1_schema_version(),
      strategy_id = strategy,
      cost_bps = unique(part$cost_bps)[[1L]],
      evaluation_period = if (is.null(evaluation_period)) "all_matured" else paste(evaluation_period, collapse = ","),
      period_count = n,
      cumulative_net_return = cumulative,
      annualized_compound_return = cagr,
      annualized_volatility = stats::sd(part$net_return) * sqrt(12),
      maximum_drawdown = max_drawdown,
      return_over_abs_drawdown = if (is.finite(max_drawdown) && max_drawdown < 0) cagr / abs(max_drawdown) else NA_real_,
      mean_monthly_turnover = mean(part$conventional_turnover),
      mean_gross_traded_notional = mean(part$gross_traded_notional),
      mean_risky_exposure = mean(part$risky_exposure),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_t1_calendar_year_returns <- function(replay) {
  x <- replay
  x$calendar_year <- as.integer(format(x$decision_date, "%Y"))
  pieces <- split(x, list(x$strategy_id, x$cost_bps, x$calendar_year), drop = TRUE)
  out <- lapply(pieces, function(part) {
    data.frame(
      schema_version = g5_t1_schema_version(),
      strategy_id = part$strategy_id[[1L]],
      cost_bps = part$cost_bps[[1L]],
      calendar_year = part$calendar_year[[1L]],
      period_count = nrow(part),
      net_return = prod(1 + part$net_return) - 1,
      mean_risky_exposure = mean(part$risky_exposure),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

g5_t1_measurement_summary <- function(panel) {
  x <- panel[panel$eligible_outcome & panel$signal %in% c("ON", "OFF"), , drop = FALSE]
  if (!nrow(x)) g5_t1_stop("T1 measurement panel has no matured observations.")
  groups <- split(x, list(x$evaluation_period, x$signal), drop = TRUE)
  pooled <- do.call(rbind, lapply(groups, function(part) {
    data.frame(
      schema_version = g5_t1_schema_version(),
      lookback_months = part$lookback_months[[1L]],
      evaluation_period = part$evaluation_period[[1L]],
      signal = part$signal[[1L]],
      observation_count = nrow(part),
      mean_asset_minus_cash_next_month_return = mean(part$asset_minus_cash_next_month_return),
      median_asset_minus_cash_next_month_return = stats::median(part$asset_minus_cash_next_month_return),
      positive_share = mean(part$asset_minus_cash_next_month_return > 0),
      stringsAsFactors = FALSE
    )
  }))
  period_ids <- unique(pooled$evaluation_period)
  separation <- do.call(rbind, lapply(period_ids, function(period_id) {
    part <- pooled[pooled$evaluation_period == period_id, , drop = FALSE]
    on <- part$mean_asset_minus_cash_next_month_return[part$signal == "ON"]
    off <- part$mean_asset_minus_cash_next_month_return[part$signal == "OFF"]
    data.frame(
      schema_version = g5_t1_schema_version(),
      lookback_months = unique(part$lookback_months)[[1L]],
      evaluation_period = period_id,
      on_mean = if (length(on)) on[[1L]] else NA_real_,
      off_mean = if (length(off)) off[[1L]] else NA_real_,
      on_minus_off = if (length(on) && length(off)) on[[1L]] - off[[1L]] else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  by_asset <- do.call(rbind, lapply(split(x, x$symbol), function(part) {
    on <- part$asset_minus_cash_next_month_return[part$signal == "ON"]
    off <- part$asset_minus_cash_next_month_return[part$signal == "OFF"]
    data.frame(
      schema_version = g5_t1_schema_version(),
      lookback_months = part$lookback_months[[1L]],
      symbol = part$symbol[[1L]],
      on_count = length(on),
      off_count = length(off),
      on_mean = if (length(on)) mean(on) else NA_real_,
      off_mean = if (length(off)) mean(off) else NA_real_,
      on_minus_off = if (length(on) && length(off)) mean(on) - mean(off) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  x$calendar_year <- as.integer(format(x$decision_date, "%Y"))
  by_year <- do.call(rbind, lapply(split(x, x$calendar_year), function(part) {
    on <- part$asset_minus_cash_next_month_return[part$signal == "ON"]
    off <- part$asset_minus_cash_next_month_return[part$signal == "OFF"]
    data.frame(
      schema_version = g5_t1_schema_version(),
      lookback_months = part$lookback_months[[1L]],
      calendar_year = part$calendar_year[[1L]],
      on_count = length(on),
      off_count = length(off),
      on_minus_off = if (length(on) && length(off)) mean(on) - mean(off) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  list(pooled = pooled, separation = separation, by_asset = by_asset, by_year = by_year)
}

g5_t1_signal_support <- function(panel, contract = g5_t1_contract()) {
  contract <- g5_t1_validate_contract(contract)
  pieces <- split(panel, panel$decision_date)
  out <- lapply(pieces, function(part) {
    data.frame(
      schema_version = g5_t1_schema_version(),
      lookback_months = part$lookback_months[[1L]],
      decision_date = part$decision_date[[1L]],
      execution_date = part$execution_date[[1L]],
      evaluation_period = part$evaluation_period[[1L]],
      eligible_signal_count = sum(part$eligible_signal),
      eligible_outcome_count = sum(part$eligible_outcome),
      on_count = sum(part$signal == "ON"),
      off_count = sum(part$signal == "OFF"),
      risky_exposure = sum(part$signal == "ON") / length(contract$risk_assets),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

g5_t1_session_coverage_audit <- function(
  bars,
  contract = g5_t1_contract()
) {
  contract <- g5_t1_validate_contract(contract)
  bars <- g5_t1_validate_bars(bars, contract)
  reference_sessions <- g5_t1_reference_sessions(bars, contract)
  reference_sessions <- reference_sessions[
    reference_sessions >= contract$query_start &
      reference_sessions <= contract$query_end
  ]
  if (!length(reference_sessions)) {
    g5_t1_stop("T1 reference-session coverage audit found no sessions.")
  }
  rows <- lapply(g5_t1_required_symbols(contract), function(symbol) {
    observed <- sort(unique(as.Date(
      bars$session_date[
        bars$symbol == symbol &
          bars$session_date >= contract$query_start &
          bars$session_date <= contract$query_end
      ]
    )))
    missing <- setdiff(reference_sessions, observed)
    extra <- setdiff(observed, reference_sessions)
    data.frame(
      schema_version = g5_t1_schema_version(),
      symbol = symbol,
      requested_start_date = contract$query_start,
      requested_end_date = contract$query_end,
      reference_first_session = min(reference_sessions),
      reference_last_session = max(reference_sessions),
      reference_session_count = length(reference_sessions),
      observed_first_session = if (length(observed)) min(observed) else as.Date(NA),
      observed_last_session = if (length(observed)) max(observed) else as.Date(NA),
      observed_session_count = length(observed),
      missing_reference_sessions = length(missing),
      extra_nonreference_sessions = length(extra),
      status = if (
        length(observed) == length(reference_sessions) &&
          !length(missing) &&
          !length(extra)
      ) "PASS" else "FAIL",
      detail = paste0(
        "missing=", length(missing),
        "; extra=", length(extra),
        "; requested calendar boundaries may be non-sessions"
      ),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_t1_contribution_attribution <- function(
  panel,
  replay,
  contract = g5_t1_contract(),
  evaluation_period = "confirmation_2022_2024"
) {
  contract <- g5_t1_validate_contract(contract)
  months <- sort(unique(replay$decision_date[
    replay$evaluation_period == evaluation_period
  ]))
  rows <- list()
  for (decision_date in months) {
    part <- panel[panel$decision_date == decision_date, , drop = FALSE]
    part <- part[match(contract$risk_assets, part$symbol), , drop = FALSE]
    t1_weights <- g5_t1_weight_row(part, "t1_trend", contract)
    control_weights <- g5_t1_weight_row(part, "exposure_matched_equal_weight", contract)
    asset_relative <- part$asset_next_month_return - part$cash_next_month_return
    for (i in seq_along(contract$risk_assets)) {
      symbol <- contract$risk_assets[[i]]
      rows[[length(rows) + 1L]] <- data.frame(
        schema_version = g5_t1_schema_version(),
        decision_date = as.Date(decision_date),
        symbol = symbol,
        t1_weight = t1_weights[[symbol]],
        control_weight = control_weights[[symbol]],
        asset_minus_cash_return = asset_relative[[i]],
        arithmetic_return_contribution = (
          t1_weights[[symbol]] - control_weights[[symbol]]
        ) * asset_relative[[i]],
        stringsAsFactors = FALSE
      )
    }
  }
  detail <- do.call(rbind, rows)
  summary <- aggregate(
    detail$arithmetic_return_contribution,
    list(symbol = detail$symbol),
    sum
  )
  names(summary)[[2L]] <- "cumulative_arithmetic_contribution"
  positive_total <- sum(pmax(summary$cumulative_arithmetic_contribution, 0))
  summary$positive_contribution_share <- if (positive_total > 0) {
    pmax(summary$cumulative_arithmetic_contribution, 0) / positive_total
  } else {
    NA_real_
  }
  summary <- summary[match(contract$risk_assets, summary$symbol), , drop = FALSE]
  list(detail = detail, summary = summary)
}

g5_t1_integrity_audit <- function(
  bars,
  panel,
  contract = g5_t1_contract(),
  data_health_status = "PASS"
) {
  contract <- g5_t1_validate_contract(contract)
  required_symbols <- g5_t1_required_symbols(contract)
  key <- paste(bars$symbol, bars$session_date)
  matured <- panel[!is.na(panel$outcome_end_date), , drop = FALSE]
  checks <- data.frame(
    check_id = c(
      "canonical_adjusted_daily_bars",
      "all_frozen_symbols_present",
      "unique_symbol_session_rows",
      "explicit_as_of_boundary",
      "completed_month_end_decisions",
      "next_open_execution",
      "open_to_open_outcomes",
      "signal_coverage",
      "matured_outcome_coverage",
      "workbench_data_health"
    ),
    status = c(
      if ("adjustment" %in% names(bars)) {
        if (all(bars$adjustment == "all")) "PASS" else "FAIL"
      } else if ("adjusted" %in% names(bars)) {
        if (all(bars$adjusted)) "PASS" else "FAIL"
      } else {
        "PASS"
      },
      if (all(required_symbols %in% unique(bars$symbol))) "PASS" else "FAIL",
      if (!anyDuplicated(key)) "PASS" else "FAIL",
      if (max(as.Date(bars$session_date)) <= contract$query_end) "PASS" else "FAIL",
      if (all(panel$decision_date <= contract$decision_end) &&
          all(g5_t1_month_id(panel$decision_date) == panel$month_id)) "PASS" else "FAIL",
      if (all(panel$execution_date > panel$decision_date)) "PASS" else "FAIL",
      if (all(matured$outcome_end_date > matured$execution_date)) "PASS" else "FAIL",
      if (all(panel$eligible_signal)) "PASS" else "FAIL",
      if (all(matured$eligible_outcome)) "PASS" else "FAIL",
      if (identical(as.character(data_health_status), "PASS")) "PASS" else "FAIL"
    ),
    detail = c(
      "Canonical adjusted 1D bars are the only input.",
      paste(length(required_symbols), "frozen symbols required."),
      "No duplicate symbol/session keys.",
      paste("Bars are capped at", contract$query_end, "under explicit as-of", contract$as_of_timestamp),
      paste("Month-end decisions end at", contract$decision_end),
      "Every signal is acted on strictly after its completed month-end.",
      "Every matured return is execution-open to following execution-open.",
      paste(sum(panel$eligible_signal), "of", nrow(panel), "signal rows eligible."),
      paste(sum(matured$eligible_outcome), "of", nrow(matured), "matured rows eligible."),
      paste("Workbench health:", data_health_status)
    ),
    stringsAsFactors = FALSE
  )
  checks
}

g5_t1_metric_value <- function(metrics, strategy, column) {
  value <- metrics[metrics$strategy_id == strategy, column, drop = TRUE]
  if (!length(value)) NA_real_ else as.numeric(value[[1L]])
}

g5_t1_gate_summary <- function(
  primary_panel,
  diagnostic_panels,
  primary_replays,
  stress_replays,
  integrity,
  attribution,
  contract = g5_t1_contract()
) {
  contract <- g5_t1_validate_contract(contract)
  measurement <- g5_t1_measurement_summary(primary_panel)
  confirmation_sep <- measurement$separation$on_minus_off[
    measurement$separation$evaluation_period == "confirmation_2022_2024"
  ]
  positive_assets <- sum(measurement$by_asset$on_minus_off > 0, na.rm = TRUE)
  primary_metrics <- g5_t1_metrics(
    primary_replays$replay,
    "confirmation_2022_2024"
  )
  stress_metrics <- g5_t1_metrics(
    stress_replays$replay,
    "confirmation_2022_2024"
  )
  t1_cagr <- g5_t1_metric_value(primary_metrics, "t1_trend", "annualized_compound_return")
  exposure_cagr <- g5_t1_metric_value(primary_metrics, "exposure_matched_equal_weight", "annualized_compound_return")
  static_cagr <- g5_t1_metric_value(primary_metrics, "static_equal_weight", "annualized_compound_return")
  t1_dd <- abs(g5_t1_metric_value(primary_metrics, "t1_trend", "maximum_drawdown"))
  static_dd <- abs(g5_t1_metric_value(primary_metrics, "static_equal_weight", "maximum_drawdown"))
  max_contribution_share <- max(attribution$summary$positive_contribution_share, na.rm = TRUE)
  if (!is.finite(max_contribution_share)) max_contribution_share <- Inf
  stress_t1_cagr <- g5_t1_metric_value(stress_metrics, "t1_trend", "annualized_compound_return")
  stress_exposure_cagr <- g5_t1_metric_value(stress_metrics, "exposure_matched_equal_weight", "annualized_compound_return")
  stress_static_cagr <- g5_t1_metric_value(stress_metrics, "static_equal_weight", "annualized_compound_return")
  stress_t1_dd <- abs(g5_t1_metric_value(stress_metrics, "t1_trend", "maximum_drawdown"))
  stress_static_dd <- abs(g5_t1_metric_value(stress_metrics, "static_equal_weight", "maximum_drawdown"))
  diagnostic_rows <- lapply(names(diagnostic_panels), function(name) {
    panel <- diagnostic_panels[[name]]
    lookback <- unique(panel$lookback_months)[[1L]]
    sep <- g5_t1_measurement_summary(panel)$separation
    sep <- sep$on_minus_off[sep$evaluation_period == "confirmation_2022_2024"]
    replay <- g5_t1_portfolio_replay(panel, contract$primary_cost_bps, contract)
    metrics <- g5_t1_metrics(replay$replay, "confirmation_2022_2024")
    advantage <- g5_t1_metric_value(metrics, "t1_trend", "annualized_compound_return") -
      g5_t1_metric_value(metrics, "exposure_matched_equal_weight", "annualized_compound_return")
    data.frame(
      lookback_months = lookback,
      confirmation_on_minus_off = if (length(sep)) sep[[1L]] else NA_real_,
      confirmation_cagr_advantage = advantage,
      reverses_primary = !is.finite(sep[[1L]]) || sep[[1L]] <= 0 || advantage <= 0,
      stringsAsFactors = FALSE
    )
  })
  diagnostics <- do.call(rbind, diagnostic_rows)
  both_diagnostics_reverse <- all(diagnostics$reverses_primary)
  pass <- c(
    all(integrity$status == "PASS"),
    length(confirmation_sep) == 1L && is.finite(confirmation_sep) && confirmation_sep > 0,
    positive_assets >= contract$pass_asset_count,
    is.finite(t1_cagr) && is.finite(exposure_cagr) && t1_cagr > exposure_cagr,
    is.finite(t1_dd) && is.finite(static_dd) && t1_dd <= (1 - contract$drawdown_reduction) * static_dd,
    is.finite(t1_cagr) && is.finite(static_cagr) && t1_cagr >= static_cagr - contract$return_sacrifice,
    is.finite(max_contribution_share) && max_contribution_share <= contract$contribution_cap,
    is.finite(stress_t1_cagr) && is.finite(stress_exposure_cagr) &&
      stress_t1_cagr > stress_exposure_cagr &&
      stress_t1_dd <= (1 - contract$drawdown_reduction) * stress_static_dd &&
      stress_t1_cagr >= stress_static_cagr - contract$return_sacrifice,
    !both_diagnostics_reverse
  )
  gates <- data.frame(
    gate_id = paste0("T1_G", seq_len(9L)),
    gate = c(
      "Integrity and coverage",
      "Confirmation pooled ON minus OFF positive",
      "At least 8 of 14 assets positive",
      "T1 beats exposure-matched control",
      "At least 10% relative drawdown reduction",
      "No more than 2 pp return sacrifice",
      "No asset exceeds 35% contribution share",
      "Central portfolio conclusions survive 10 bp",
      "9m and 15m do not both reverse"
    ),
    status = ifelse(pass, "PASS", "FAIL"),
    value = c(
      paste(sum(integrity$status == "PASS"), "/", nrow(integrity)),
      sprintf("%.6f", if (length(confirmation_sep)) confirmation_sep[[1L]] else NA_real_),
      paste(positive_assets, "/ 14"),
      sprintf("%.6f", t1_cagr - exposure_cagr),
      sprintf("%.3f", if (static_dd > 0) 1 - t1_dd / static_dd else NA_real_),
      sprintf("%.6f", t1_cagr - static_cagr),
      sprintf("%.3f", max_contribution_share),
      sprintf("%.6f", stress_t1_cagr - stress_exposure_cagr),
      paste(sum(diagnostics$reverses_primary), "/ 2 reverse")
    ),
    detail = c(
      "All timing, adjusted-bar, explicit-as-of, cache-health, and coverage checks must pass.",
      "Mean next-month asset-minus-BIL return for ON observations must exceed OFF observations in 2022-2024.",
      "Full matured history uses the frozen fourteen assets without deletion.",
      "Five-bp net annualized return is compared in the confirmation window.",
      "Absolute confirmation maximum drawdown is compared with static equal weight.",
      "Confirmation annualized return may trail static equal weight by at most two percentage points.",
      "Positive arithmetic attribution versus the exposure-matched control is normalized across risk assets.",
      "The exposure, drawdown, and return-sacrifice conclusions are repeated at ten bp one way.",
      "A diagnostic reverses when either confirmation separation or confirmation CAGR advantage is non-positive."
    ),
    stringsAsFactors = FALSE
  )
  list(
    gates = gates,
    diagnostics = diagnostics,
    primary_confirmation_metrics = primary_metrics,
    stress_confirmation_metrics = stress_metrics,
    measurement = measurement,
    overall_status = if (all(gates$status == "PASS")) {
      "PASS_T1_TO_PROSPECTIVE_SHADOW"
    } else {
      "STOP_T1_TREND_PERSISTENCE"
    }
  )
}

g5_t1_run_analysis <- function(
  bars,
  contract = g5_t1_contract(),
  data_health_status = "PASS"
) {
  contract <- g5_t1_validate_contract(contract)
  bars <- g5_t1_validate_bars(bars, contract)
  session_coverage <- g5_t1_session_coverage_audit(bars, contract)
  primary_panel <- g5_t1_build_observation_panel(
    bars, contract$primary_lookback_months, contract
  )
  diagnostic_panels <- setNames(
    lapply(contract$diagnostic_lookbacks, function(lookback) {
      g5_t1_build_observation_panel(bars, lookback, contract)
    }),
    paste0("lookback_", contract$diagnostic_lookbacks)
  )
  primary_replays <- g5_t1_portfolio_replay(
    primary_panel, contract$primary_cost_bps, contract
  )
  stress_replays <- g5_t1_portfolio_replay(
    primary_panel, contract$stress_cost_bps, contract
  )
  integrity <- g5_t1_integrity_audit(
    bars, primary_panel, contract, data_health_status
  )
  attribution <- g5_t1_contribution_attribution(
    primary_panel, primary_replays$replay, contract
  )
  gates <- g5_t1_gate_summary(
    primary_panel = primary_panel,
    diagnostic_panels = diagnostic_panels,
    primary_replays = primary_replays,
    stress_replays = stress_replays,
    integrity = integrity,
    attribution = attribution,
    contract = contract
  )
  list(
    contract = contract,
    primary_panel = primary_panel,
    diagnostic_panels = diagnostic_panels,
    primary_replay = primary_replays$replay,
    primary_weights = primary_replays$weights,
    stress_replay = stress_replays$replay,
    stress_weights = stress_replays$weights,
    primary_all_metrics = g5_t1_metrics(primary_replays$replay),
    primary_confirmation_metrics = gates$primary_confirmation_metrics,
    stress_confirmation_metrics = gates$stress_confirmation_metrics,
    calendar_year_returns = rbind(
      g5_t1_calendar_year_returns(primary_replays$replay),
      g5_t1_calendar_year_returns(stress_replays$replay)
    ),
    measurement = gates$measurement,
    signal_support = g5_t1_signal_support(primary_panel, contract),
    session_coverage = session_coverage,
    attribution = attribution,
    integrity = integrity,
    diagnostic_summary = gates$diagnostics,
    gates = gates$gates,
    overall_status = gates$overall_status
  )
}
