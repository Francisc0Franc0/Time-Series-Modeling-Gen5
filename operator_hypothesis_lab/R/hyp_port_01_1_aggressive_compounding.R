# HYP-PORT-01.1 aggressive-compounding portfolio comparison helpers.

g5_port011_stop <- function(message) stop(message, call. = FALSE)

g5_port011_schema_version <- function() "gen5_hyp_port_01_1_v1"

g5_port011_contract <- function() {
  targets <- c(
    SCHG = 0.50,
    QUAL = 0.20,
    XSD = 0.15,
    AMD = 0.05,
    NVDA = 0.05,
    TSLA = 0.05
  )
  list(
    hypothesis_id = "HYP-PORT-01.1",
    evidence_stage = "DESCRIPTIVE_PORTFOLIO_POLICY_POC",
    as_of_timestamp = "2026-09-03 10:30:00 America/Los_Angeles",
    query_start = as.Date("2020-10-13"),
    initial_decision_date = as.Date("2020-10-14"),
    evaluation_end = as.Date("2026-09-02"),
    policy_assets = names(targets),
    policy_targets = targets,
    trio_assets = c("AMD", "NVDA", "TSLA"),
    benchmark_assets = c("QQQM", "SPY"),
    variants = c(
      "AGGRESSIVE_POLICY_BAND_REBALANCE",
      "AGGRESSIVE_POLICY_BUY_HOLD",
      "EQUAL_WEIGHT_AMD_NVDA_TSLA",
      "SCHG_BUY_HOLD",
      "QQQM_BUY_HOLD",
      "SPY_DIAGNOSTIC"
    ),
    rebalance_review = "FIRST_SESSION_OF_EACH_CALENDAR_QUARTER_USING_PRIOR_CLOSE_INFORMATION",
    forced_restore = "FIRST_SESSION_OF_EACH_CALENDAR_YEAR",
    relative_band_fraction = 0.20,
    cost_bps_one_way = 5,
    initial_wealth = 1,
    annualization_sessions = 252,
    rolling_short_sessions = 63L,
    rolling_year_sessions = 252L,
    rolling_three_year_sessions = 756L,
    minimum_common_session_fraction = 0.995,
    historical_lookthrough_caps_tested = FALSE,
    historical_tax_drag_tested = FALSE,
    recurring_contributions_tested = FALSE,
    inference_opened = FALSE,
    parameter_search_opened = FALSE,
    forward_gate_opened = FALSE,
    live_authority_opened = FALSE
  )
}

g5_port011_validate_contract <- function(contract = g5_port011_contract()) {
  frozen <- g5_port011_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_port011_stop("Frozen HYP-PORT-01.1 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_port011_stop(paste(
      "Frozen HYP-PORT-01.1 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  if (abs(sum(contract$policy_targets) - 1) > 1e-12) {
    g5_port011_stop("Policy targets must sum to one.")
  }
  if (!identical(names(contract$policy_targets), contract$policy_assets)) {
    g5_port011_stop("Policy target names must match policy assets in order.")
  }
  contract
}

g5_port011_required_symbols <- function(contract = g5_port011_contract()) {
  contract <- g5_port011_validate_contract(contract)
  unique(c(contract$policy_assets, contract$benchmark_assets))
}

g5_port011_validate_bars <- function(bars, contract = g5_port011_contract()) {
  contract <- g5_port011_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_port011_stop(paste("HYP-PORT-01.1 bars missing:", paste(missing, collapse = ", ")))
  }
  symbols <- g5_port011_required_symbols(contract)
  x <- bars[bars$symbol %in% symbols, , drop = FALSE]
  x$symbol <- toupper(trimws(as.character(x$symbol)))
  x$session_date <- as.Date(x$session_date)
  x$open <- as.numeric(x$open)
  x$close <- as.numeric(x$close)
  x <- x[
    x$session_date >= contract$query_start &
      x$session_date <= contract$evaluation_end,
    , drop = FALSE
  ]
  per_symbol <- do.call(rbind, lapply(symbols, function(symbol) {
    rows <- x[x$symbol == symbol, , drop = FALSE]
    data.frame(
      symbol = symbol,
      rows = nrow(rows),
      first_date = if (nrow(rows)) min(rows$session_date) else as.Date(NA),
      last_date = if (nrow(rows)) max(rows$session_date) else as.Date(NA),
      finite_positive = nrow(rows) > 0L && all(
        is.finite(rows$open) & rows$open > 0 &
          is.finite(rows$close) & rows$close > 0
      ),
      adjusted_daily = nrow(rows) > 0L &&
        all(rows$adjusted %in% TRUE) && all(rows$timeframe == "1D"),
      stringsAsFactors = FALSE
    )
  }))
  checks <- data.frame(
    check_id = c(
      "all_required_symbols_present",
      "unique_symbol_sessions",
      "finite_positive_open_close",
      "adjusted_daily_only",
      "all_symbols_cover_initial_decision",
      "all_symbols_cover_evaluation_end"
    ),
    passed = c(
      all(symbols %in% unique(x$symbol)),
      !anyDuplicated(paste(x$symbol, x$session_date)),
      nrow(x) > 0L && all(per_symbol$finite_positive),
      nrow(x) > 0L && all(per_symbol$adjusted_daily),
      all(!is.na(per_symbol$first_date) & per_symbol$first_date <= contract$initial_decision_date),
      all(!is.na(per_symbol$last_date) & per_symbol$last_date >= contract$evaluation_end)
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  list(
    bars = x[order(x$symbol, x$session_date), , drop = FALSE],
    coverage = per_symbol,
    checks = checks
  )
}

g5_port011_open_panel <- function(validated, contract = g5_port011_contract()) {
  contract <- g5_port011_validate_contract(contract)
  symbols <- g5_port011_required_symbols(contract)
  bars <- validated$bars
  dates_by_symbol <- lapply(symbols, function(symbol) {
    bars$session_date[bars$symbol == symbol]
  })
  names(dates_by_symbol) <- symbols
  common_dates <- as.Date(sort(Reduce(intersect, dates_by_symbol)), origin = "1970-01-01")
  common_dates <- common_dates[
    common_dates >= contract$initial_decision_date &
      common_dates <= contract$evaluation_end
  ]
  if (length(common_dates) < 4L) {
    g5_port011_stop("Insufficient common sessions for HYP-PORT-01.1.")
  }
  open <- matrix(
    NA_real_, nrow = length(common_dates), ncol = length(symbols),
    dimnames = list(as.character(common_dates), symbols)
  )
  for (symbol in symbols) {
    rows <- bars[bars$symbol == symbol & bars$session_date %in% common_dates, , drop = FALSE]
    open[as.character(rows$session_date), symbol] <- rows$open
  }
  if (any(!is.finite(open)) || any(open <= 0)) {
    g5_port011_stop("Common HYP-PORT-01.1 open matrix contains invalid values.")
  }
  spy_dates <- dates_by_symbol[["SPY"]]
  spy_dates <- spy_dates[
    spy_dates >= contract$initial_decision_date &
      spy_dates <= contract$evaluation_end
  ]
  common_fraction <- length(common_dates) / length(spy_dates)
  list(
    dates = common_dates,
    open = open,
    common_session_fraction = common_fraction,
    spy_session_count = length(spy_dates)
  )
}

g5_port011_quarter_key <- function(dates) {
  dates <- as.Date(dates)
  paste0(
    format(dates, "%Y"),
    "Q",
    (as.integer(format(dates, "%m")) - 1L) %/% 3L + 1L
  )
}

g5_port011_variant_targets <- function(contract = g5_port011_contract()) {
  contract <- g5_port011_validate_contract(contract)
  symbols <- g5_port011_required_symbols(contract)
  columns <- c(symbols, "CASH")
  blank <- setNames(rep(0, length(columns)), columns)
  make <- function(weights) {
    out <- blank
    out[names(weights)] <- weights
    out[["CASH"]] <- 1 - sum(weights)
    out
  }
  out <- list(
    AGGRESSIVE_POLICY_BAND_REBALANCE = make(contract$policy_targets),
    AGGRESSIVE_POLICY_BUY_HOLD = make(contract$policy_targets),
    EQUAL_WEIGHT_AMD_NVDA_TSLA = make(setNames(rep(1 / 3, 3L), contract$trio_assets)),
    SCHG_BUY_HOLD = make(c(SCHG = 1)),
    QQQM_BUY_HOLD = make(setNames(1, "QQQM")),
    SPY_DIAGNOSTIC = make(c(SPY = 1))
  )
  out <- out[contract$variants]
  if (any(vapply(out, function(x) abs(sum(x) - 1) > 1e-12, logical(1)))) {
    g5_port011_stop("A HYP-PORT-01.1 variant target does not sum to one.")
  }
  out
}

g5_port011_max_underwater_sessions <- function(drawdown) {
  underwater <- drawdown < -1e-12
  if (!any(underwater)) return(0L)
  runs <- rle(underwater)
  max(runs$lengths[runs$values])
}

g5_port011_rolling_return <- function(values, sessions) {
  out <- rep(NA_real_, length(values))
  if (length(values) > sessions) {
    idx <- seq.int(sessions + 1L, length(values))
    out[idx] <- values[idx] / values[idx - sessions] - 1
  }
  out
}

g5_port011_replay_variant <- function(
  variant,
  target,
  panel,
  contract = g5_port011_contract()
) {
  contract <- g5_port011_validate_contract(contract)
  symbols <- g5_port011_required_symbols(contract)
  columns <- c(symbols, "CASH")
  dates <- panel$dates
  start_rows <- seq.int(2L, length(dates) - 1L)
  end_rows <- start_rows + 1L
  decision_rows <- start_rows - 1L
  returns <- panel$open[end_rows, symbols, drop = FALSE] /
    panel$open[start_rows, symbols, drop = FALSE] - 1
  pretrade <- setNames(rep(0, length(columns)), columns)
  pretrade[["CASH"]] <- 1
  wealth <- contract$initial_wealth
  one_way_rate <- contract$cost_bps_one_way / 10000
  rows <- vector("list", length(start_rows))

  for (j in seq_along(start_rows)) {
    start_i <- start_rows[[j]]
    decision_i <- decision_rows[[j]]
    execution_date <- dates[[start_i]]
    decision_date <- dates[[decision_i]]
    next_execution_date <- dates[[end_rows[[j]]]]
    initial <- j == 1L
    quarter_review <- initial ||
      g5_port011_quarter_key(execution_date) != g5_port011_quarter_key(decision_date)
    annual_restore <- !initial &&
      format(execution_date, "%Y") != format(decision_date, "%Y")
    breach <- FALSE
    trigger <- "NONE"
    should_trade <- initial
    if (initial) {
      trigger <- "INITIAL_ALLOCATION"
    } else if (variant == "AGGRESSIVE_POLICY_BAND_REBALANCE" && quarter_review) {
      lower <- target * (1 - contract$relative_band_fraction)
      upper <- target * (1 + contract$relative_band_fraction)
      invested <- names(target)[target > 0]
      breach <- any(pretrade[invested] < lower[invested] - 1e-12) ||
        any(pretrade[invested] > upper[invested] + 1e-12)
      should_trade <- annual_restore || breach
      if (annual_restore) {
        trigger <- "ANNUAL_RESTORE"
      } else if (breach) {
        trigger <- "QUARTERLY_BAND_BREACH"
      }
    }
    turnover <- if (should_trade) 0.5 * sum(abs(target - pretrade)) else 0
    cost_fraction <- one_way_rate * turnover
    posttrade <- if (should_trade) target else pretrade
    gross_return <- sum(posttrade[symbols] * returns[j, symbols])
    net_return <- (1 - cost_fraction) * (1 + gross_return) - 1
    wealth_before <- wealth
    wealth <- wealth * (1 + net_return)
    end_values <- c(
      posttrade[symbols] * (1 + returns[j, symbols]),
      CASH = posttrade[["CASH"]]
    )
    pretrade <- end_values / sum(end_values)
    row <- data.frame(
      variant = variant,
      interval = j,
      decision_date = decision_date,
      execution_date = execution_date,
      next_execution_date = next_execution_date,
      quarter_review = quarter_review,
      annual_restore = annual_restore,
      band_breach = breach,
      rebalance_trigger = trigger,
      turnover_one_way = turnover,
      cost_fraction = cost_fraction,
      gross_return = gross_return,
      net_return = net_return,
      wealth_before = wealth_before,
      wealth = wealth,
      stringsAsFactors = FALSE
    )
    for (name in columns) {
      row[[paste0("posttrade_weight_", name)]] <- posttrade[[name]]
      row[[paste0("end_weight_", name)]] <- pretrade[[name]]
    }
    rows[[j]] <- row
  }
  tape <- do.call(rbind, rows)
  tape$running_peak <- cummax(c(contract$initial_wealth, tape$wealth))[-1L]
  tape$drawdown <- tape$wealth / tape$running_peak - 1
  tape
}

g5_port011_metrics <- function(tape, contract = g5_port011_contract()) {
  contract <- g5_port011_validate_contract(contract)
  wealth <- c(contract$initial_wealth, tape$wealth)
  dates <- c(tape$execution_date[[1L]], tape$next_execution_date)
  drawdown <- wealth / cummax(wealth) - 1
  years <- as.numeric(max(dates) - min(dates)) / 365.25
  r63 <- g5_port011_rolling_return(wealth, contract$rolling_short_sessions)
  r252 <- g5_port011_rolling_return(wealth, contract$rolling_year_sessions)
  daily_sd <- stats::sd(tape$net_return)
  data.frame(
    variant = tape$variant[[1L]],
    intervals = nrow(tape),
    start_date = min(dates),
    end_date = max(dates),
    years = years,
    ending_wealth = tail(wealth, 1L),
    total_return = tail(wealth, 1L) - 1,
    cagr_net = tail(wealth, 1L)^(1 / years) - 1,
    annualized_volatility = daily_sd * sqrt(contract$annualization_sessions),
    sharpe_zero_cash = if (daily_sd > 0) {
      mean(tape$net_return) / daily_sd * sqrt(contract$annualization_sessions)
    } else {
      NA_real_
    },
    max_drawdown = min(drawdown),
    max_drawdown_date = dates[[which.min(drawdown)]],
    maximum_underwater_sessions = g5_port011_max_underwater_sessions(drawdown),
    worst_63_session_return = if (any(is.finite(r63))) min(r63, na.rm = TRUE) else NA_real_,
    worst_252_session_return = if (any(is.finite(r252))) min(r252, na.rm = TRUE) else NA_real_,
    total_turnover_one_way = sum(tape$turnover_one_way),
    rebalance_events = sum(tape$rebalance_trigger != "NONE"),
    stringsAsFactors = FALSE
  )
}

g5_port011_calendar_returns <- function(tape, contract = g5_port011_contract()) {
  contract <- g5_port011_validate_contract(contract)
  dates <- c(tape$execution_date[[1L]], tape$next_execution_date)
  wealth <- c(contract$initial_wealth, tape$wealth)
  years <- format(dates, "%Y")
  split_rows <- split(seq_along(dates), years)
  do.call(rbind, lapply(names(split_rows), function(year) {
    idx <- split_rows[[year]]
    start_i <- min(idx)
    end_i <- max(idx)
    data.frame(
      variant = tape$variant[[1L]],
      calendar_year = as.integer(year),
      partial_year = dates[[start_i]] > as.Date(paste0(year, "-01-07")) ||
        dates[[end_i]] < as.Date(paste0(year, "-12-20")),
      start_date = dates[[start_i]],
      end_date = dates[[end_i]],
      return = wealth[[end_i]] / wealth[[start_i]] - 1,
      stringsAsFactors = FALSE
    )
  }))
}

g5_port011_rolling_three_year <- function(tape, contract = g5_port011_contract()) {
  contract <- g5_port011_validate_contract(contract)
  wealth <- c(contract$initial_wealth, tape$wealth)
  dates <- c(tape$execution_date[[1L]], tape$next_execution_date)
  rolling <- g5_port011_rolling_return(wealth, contract$rolling_three_year_sessions)
  data.frame(
    variant = tape$variant[[1L]],
    session_date = dates,
    rolling_three_year_total_return = rolling,
    rolling_three_year_annualized = ifelse(
      is.finite(rolling),
      (1 + rolling)^(contract$annualization_sessions / contract$rolling_three_year_sessions) - 1,
      NA_real_
    ),
    stringsAsFactors = FALSE
  )
}

g5_port011_summary <- function(metrics) {
  required <- c(
    "AGGRESSIVE_POLICY_BAND_REBALANCE", "AGGRESSIVE_POLICY_BUY_HOLD",
    "EQUAL_WEIGHT_AMD_NVDA_TSLA", "SCHG_BUY_HOLD", "QQQM_BUY_HOLD",
    "SPY_DIAGNOSTIC"
  )
  if (!all(required %in% metrics$variant)) {
    g5_port011_stop("HYP-PORT-01.1 metrics do not contain all frozen variants.")
  }
  get <- function(variant, field) metrics[metrics$variant == variant, field][[1L]]
  data.frame(
    policy_cagr = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "cagr_net"),
    policy_max_drawdown = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "max_drawdown"),
    policy_sharpe_zero_cash = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "sharpe_zero_cash"),
    policy_minus_buy_hold_cagr = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "cagr_net") -
      get("AGGRESSIVE_POLICY_BUY_HOLD", "cagr_net"),
    policy_minus_trio_cagr = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "cagr_net") -
      get("EQUAL_WEIGHT_AMD_NVDA_TSLA", "cagr_net"),
    policy_minus_schg_cagr = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "cagr_net") -
      get("SCHG_BUY_HOLD", "cagr_net"),
    policy_minus_qqqm_cagr = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "cagr_net") -
      get("QQQM_BUY_HOLD", "cagr_net"),
    policy_minus_spy_cagr = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "cagr_net") -
      get("SPY_DIAGNOSTIC", "cagr_net"),
    policy_drawdown_minus_trio = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "max_drawdown") -
      get("EQUAL_WEIGHT_AMD_NVDA_TSLA", "max_drawdown"),
    policy_drawdown_minus_qqqm = get("AGGRESSIVE_POLICY_BAND_REBALANCE", "max_drawdown") -
      get("QQQM_BUY_HOLD", "max_drawdown"),
    stringsAsFactors = FALSE
  )
}

g5_port011_run <- function(bars, contract = g5_port011_contract()) {
  contract <- g5_port011_validate_contract(contract)
  validated <- g5_port011_validate_bars(bars, contract)
  panel <- g5_port011_open_panel(validated, contract)
  target <- g5_port011_variant_targets(contract)
  panel_checks <- data.frame(
    check_id = c(
      "common_panel_begins_on_frozen_decision_date",
      "common_panel_ends_on_frozen_evaluation_date",
      "common_session_fraction_meets_floor",
      "first_execution_is_after_initial_decision",
      "all_variant_targets_sum_to_one",
      "historical_lookthrough_caps_explicitly_unavailable"
    ),
    passed = c(
      isTRUE(panel$dates[[1L]] == contract$initial_decision_date),
      isTRUE(tail(panel$dates, 1L) == contract$evaluation_end),
      panel$common_session_fraction >= contract$minimum_common_session_fraction,
      length(panel$dates) >= 2L && panel$dates[[2L]] > panel$dates[[1L]],
      all(vapply(target, function(x) abs(sum(x) - 1) <= 1e-12, logical(1))),
      identical(contract$historical_lookthrough_caps_tested, FALSE)
    ),
    stringsAsFactors = FALSE
  )
  panel_checks$status <- ifelse(panel_checks$passed, "PASS", "FAIL")
  gates <- rbind(validated$checks, panel_checks)
  admitted <- all(gates$passed)
  if (!admitted) {
    return(list(
      contract = contract,
      coverage = validated$coverage,
      gates = gates,
      panel = panel,
      targets = target,
      admitted = FALSE
    ))
  }
  tapes <- lapply(contract$variants, function(variant) {
    g5_port011_replay_variant(variant, target[[variant]], panel, contract)
  })
  names(tapes) <- contract$variants
  daily_tape <- do.call(rbind, tapes)
  rownames(daily_tape) <- NULL
  metrics <- do.call(rbind, lapply(tapes, g5_port011_metrics, contract = contract))
  rownames(metrics) <- NULL
  calendar_returns <- do.call(rbind, lapply(tapes, g5_port011_calendar_returns, contract = contract))
  rownames(calendar_returns) <- NULL
  rolling_three_year <- do.call(rbind, lapply(tapes, g5_port011_rolling_three_year, contract = contract))
  rownames(rolling_three_year) <- NULL
  rebalance_tape <- daily_tape[
    daily_tape$variant == "AGGRESSIVE_POLICY_BAND_REBALANCE" &
      daily_tape$rebalance_trigger != "NONE",
    , drop = FALSE
  ]
  list(
    contract = contract,
    coverage = validated$coverage,
    gates = gates,
    panel = panel,
    targets = target,
    admitted = TRUE,
    daily_tape = daily_tape,
    metrics = metrics,
    summary = g5_port011_summary(metrics),
    calendar_returns = calendar_returns,
    rolling_three_year = rolling_three_year,
    rebalance_tape = rebalance_tape
  )
}
