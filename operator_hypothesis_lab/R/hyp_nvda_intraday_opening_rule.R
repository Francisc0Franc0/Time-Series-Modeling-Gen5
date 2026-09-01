nio_stop <- function(message) {
  stop(paste0("[NVDA INTRADAY OPENING RULE] ", message), call. = FALSE)
}

nio_contract <- function() {
  list(
    study_id = "HYP-NVDA-OPENING-RULE-01.2",
    sample_role = "TRAIN",
    symbol = "NVDA",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    rolling_sessions = 252L,
    opening_quantile_probability = 0.80,
    candidate_atrp_states = c("LOW", "MEDIUM"),
    opposite_atrp_state = "HIGH",
    entry_clock = "10:00",
    exit_clock = "16:00",
    round_trip_cost_bps = 10,
    minimum_candidate_trades = 100L,
    minimum_positive_years = 3L,
    primary_rule = "OPENING_TAIL_LOW_MED_ATR",
    rule_ids = c(
      "OPENING_TAIL_LOW_MED_ATR",
      "OPENING_TAIL_ONLY",
      "LOW_MED_ATR_ONLY",
      "OPENING_TAIL_HIGH_ATR",
      "UNCONDITIONAL_1000_CLOSE"
    )
  )
}

nio_validate_contract <- function(contract = nio_contract()) {
  if (!identical(contract$study_id, "HYP-NVDA-OPENING-RULE-01.2") ||
      !identical(contract$sample_role, "TRAIN") ||
      !identical(contract$symbol, "NVDA") ||
      !identical(contract$analysis_start, as.Date("2018-01-02")) ||
      !identical(contract$analysis_end, as.Date("2023-12-29")) ||
      !identical(contract$rolling_sessions, 252L) ||
      !isTRUE(all.equal(contract$opening_quantile_probability, 0.80)) ||
      !identical(contract$candidate_atrp_states, c("LOW", "MEDIUM")) ||
      !identical(contract$opposite_atrp_state, "HIGH") ||
      !identical(contract$entry_clock, "10:00") ||
      !identical(contract$exit_clock, "16:00") ||
      !identical(contract$round_trip_cost_bps, 10) ||
      !identical(contract$minimum_candidate_trades, 100L) ||
      !identical(contract$minimum_positive_years, 3L)) {
    nio_stop("The frozen TRAIN contract changed.")
  }
  contract
}

nio_rule_map <- function() {
  c(
    OPENING_TAIL_LOW_MED_ATR = "candidate_signal",
    OPENING_TAIL_ONLY = "opening_tail_signal",
    LOW_MED_ATR_ONLY = "low_med_atr_signal",
    OPENING_TAIL_HIGH_ATR = "opening_tail_high_atr_signal",
    UNCONDITIONAL_1000_CLOSE = "unconditional_signal"
  )
}

nio_validate_sessions <- function(sessions, contract = nio_contract()) {
  required <- c(
    "symbol", "session_date", "state_session", "atrp_state",
    "first_bar_open", "ten_am_price", "session_close",
    "opening_log_return", "remainder_log_return"
  )
  if (!is.data.frame(sessions) || !nrow(sessions) ||
      !all(required %in% names(sessions))) {
    nio_stop("The full-session ledger is unavailable or incomplete.")
  }
  x <- sessions[, required, drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  x$state_session <- as.Date(x$state_session)
  numeric_fields <- c(
    "first_bar_open", "ten_am_price", "session_close",
    "opening_log_return", "remainder_log_return"
  )
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  x <- x[order(x$session_date), , drop = FALSE]
  if (!all(x$symbol == contract$symbol) || anyDuplicated(x$session_date) ||
      any(diff(x$session_date) <= 0) || any(x$state_session >= x$session_date) ||
      any(!x$atrp_state %in% c("LOW", "MEDIUM", "HIGH")) ||
      any(!is.finite(as.matrix(x[numeric_fields]))) ||
      any(as.matrix(x[c("first_bar_open", "ten_am_price", "session_close")]) <= 0) ||
      any(abs(x$opening_log_return - log(x$ten_am_price / x$first_bar_open)) > 1e-10) ||
      any(abs(x$remainder_log_return - log(x$session_close / x$ten_am_price)) > 1e-10)) {
    nio_stop("Session timing, state, or price fields violate the causal contract.")
  }
  x <- x[x$session_date >= contract$analysis_start &
           x$session_date <= contract$analysis_end, , drop = FALSE]
  if (nrow(x) <= contract$rolling_sessions) {
    nio_stop("Insufficient full sessions for the rolling threshold warm-up.")
  }
  x
}

nio_build_candidates <- function(sessions, contract = nio_contract()) {
  contract <- nio_validate_contract(contract)
  x <- nio_validate_sessions(sessions, contract)
  evaluation_index <- (contract$rolling_sessions + 1L):nrow(x)
  rows <- lapply(evaluation_index, function(i) {
    history_index <- (i - contract$rolling_sessions):(i - 1L)
    threshold <- unname(stats::quantile(
      x$opening_log_return[history_index],
      probs = contract$opening_quantile_probability,
      type = 8,
      names = FALSE
    ))
    data.frame(
      symbol = x$symbol[[i]],
      session_index = i,
      session_date = x$session_date[[i]],
      state_session = x$state_session[[i]],
      atrp_state = x$atrp_state[[i]],
      threshold_window_start = x$session_date[[history_index[[1L]]]],
      threshold_window_end = x$session_date[[history_index[[length(history_index)]]]],
      threshold_observations = length(history_index),
      rolling_opening_q80 = threshold,
      first_bar_open = x$first_bar_open[[i]],
      entry_price_1000 = x$ten_am_price[[i]],
      exit_price_1600 = x$session_close[[i]],
      opening_log_return = x$opening_log_return[[i]],
      gross_trade_log_return = x$remainder_log_return[[i]],
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out$net_trade_log_return <- out$gross_trade_log_return -
    contract$round_trip_cost_bps / 10000
  out$opening_tail_signal <- out$opening_log_return >= out$rolling_opening_q80
  out$low_med_atr_signal <- out$atrp_state %in% contract$candidate_atrp_states
  out$candidate_signal <- out$opening_tail_signal & out$low_med_atr_signal
  out$opening_tail_high_atr_signal <- out$opening_tail_signal &
    out$atrp_state == contract$opposite_atrp_state
  out$unconditional_signal <- TRUE
  if (any(out$threshold_window_end >= out$session_date) ||
      any(out$threshold_observations != contract$rolling_sessions)) {
    nio_stop("A rolling opening threshold used current or future information.")
  }
  out
}

nio_build_trades <- function(candidates, contract = nio_contract()) {
  rules <- nio_rule_map()
  missing <- setdiff(unname(rules), names(candidates))
  if (length(missing)) nio_stop(paste("Missing signal columns:", paste(missing, collapse = ", ")))
  rows <- lapply(contract$rule_ids, function(rule_id) {
    signal <- rules[[rule_id]]
    x <- candidates[candidates[[signal]], , drop = FALSE]
    x$rule_id <- rule_id
    x$primary_rule <- rule_id == contract$primary_rule
    x
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

nio_rule_summary <- function(trades, contract = nio_contract()) {
  rows <- lapply(contract$rule_ids, function(rule_id) {
    x <- trades[trades$rule_id == rule_id, , drop = FALSE]
    data.frame(
      rule_id = rule_id,
      primary_rule = rule_id == contract$primary_rule,
      trades = nrow(x),
      mean_gross_trade_log_return = if (nrow(x)) mean(x$gross_trade_log_return) else NA_real_,
      mean_net_trade_log_return = if (nrow(x)) mean(x$net_trade_log_return) else NA_real_,
      median_net_trade_log_return = if (nrow(x)) stats::median(x$net_trade_log_return) else NA_real_,
      probability_profitable_net = if (nrow(x)) mean(x$net_trade_log_return > 0) else NA_real_,
      cumulative_net_log_return = if (nrow(x)) sum(x$net_trade_log_return) else NA_real_,
      ending_equity_per_dollar = if (nrow(x)) exp(sum(x$net_trade_log_return)) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

nio_calendar_summary <- function(trades) {
  if (!nrow(trades)) return(data.frame())
  trades$entry_year <- as.integer(format(trades$session_date, "%Y"))
  groups <- split(trades, interaction(trades$entry_year, trades$rule_id, drop = TRUE))
  out <- do.call(rbind, lapply(groups, function(x) data.frame(
    entry_year = x$entry_year[[1L]],
    rule_id = x$rule_id[[1L]],
    trades = nrow(x),
    mean_net_trade_log_return = mean(x$net_trade_log_return),
    median_net_trade_log_return = stats::median(x$net_trade_log_return),
    probability_profitable_net = mean(x$net_trade_log_return > 0),
    cumulative_net_log_return = sum(x$net_trade_log_return),
    stringsAsFactors = FALSE
  )))
  rownames(out) <- NULL
  out[order(out$entry_year, out$rule_id), , drop = FALSE]
}

nio_train_gate <- function(rule_summary, calendar_summary,
                           contract = nio_contract()) {
  contract <- nio_validate_contract(contract)
  primary <- rule_summary[
    rule_summary$rule_id == contract$primary_rule, , drop = FALSE
  ]
  controls <- rule_summary[
    rule_summary$rule_id != contract$primary_rule, , drop = FALSE
  ]
  annual <- calendar_summary[
    calendar_summary$rule_id == contract$primary_rule, , drop = FALSE
  ]
  if (nrow(primary) != 1L || nrow(controls) != 4L || !nrow(annual)) {
    nio_stop("The primary rule or predeclared controls are missing from the gate.")
  }
  positive_years <- sum(annual$mean_net_trade_log_return > 0)
  strongest_control <- controls$rule_id[[which.max(controls$mean_net_trade_log_return)]]
  strongest_control_mean <- max(controls$mean_net_trade_log_return)
  checks <- data.frame(
    gate_id = c(
      "minimum_candidate_support",
      "positive_mean_net_return",
      "positive_typical_trade",
      "beats_every_simpler_control",
      "calendar_breadth"
    ),
    passed = c(
      primary$trades >= contract$minimum_candidate_trades,
      primary$mean_net_trade_log_return > 0,
      primary$median_net_trade_log_return > 0 &
        primary$probability_profitable_net > 0.50,
      primary$mean_net_trade_log_return > strongest_control_mean,
      positive_years >= contract$minimum_positive_years
    ),
    observed = c(
      sprintf("%d trades; minimum %d", primary$trades, contract$minimum_candidate_trades),
      sprintf("%+.3f%% mean net", 100 * primary$mean_net_trade_log_return),
      sprintf(
        "%+.3f%% median; %.1f%% profitable",
        100 * primary$median_net_trade_log_return,
        100 * primary$probability_profitable_net
      ),
      sprintf(
        "primary %+.3f%%; strongest control %s %+.3f%%",
        100 * primary$mean_net_trade_log_return,
        strongest_control,
        100 * strongest_control_mean
      ),
      sprintf(
        "%d positive years; minimum %d",
        positive_years, contract$minimum_positive_years
      )
    ),
    stringsAsFactors = FALSE
  )
  list(
    checks = checks,
    verdict = if (all(checks$passed))
      "TRAIN_TRANSLATION_PASS_CANDIDATE_FOR_PROTECTED_CONFIRMATION" else
      "STOP_TRAIN_TRANSLATION_GATES_FAILED"
  )
}

nio_build_study <- function(sessions, contract = nio_contract()) {
  candidates <- nio_build_candidates(sessions, contract)
  trades <- nio_build_trades(candidates, contract)
  rule_summary <- nio_rule_summary(trades, contract)
  calendar_summary <- nio_calendar_summary(trades)
  gate <- nio_train_gate(rule_summary, calendar_summary, contract)
  list(
    candidates = candidates,
    trades = trades,
    rule_summary = rule_summary,
    calendar_summary = calendar_summary,
    gate = gate
  )
}
