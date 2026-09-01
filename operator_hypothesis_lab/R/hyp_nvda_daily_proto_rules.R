nvpr_stop <- function(message) {
  stop(paste0("[NVDA-DAILY-PROTO-RULES] ", message), call. = FALSE)
}

nvpr_contract <- function() {
  list(
    study_id = "NVDA_DAILY_PROTO_RULES_01",
    sample_role = "TRAIN",
    symbol = "NVDA",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    prior_sessions = 20L,
    hold_sessions = 20L,
    er_cutoff = 0.30,
    rebound_atrp_states = c("LOW", "MEDIUM"),
    round_trip_cost_bps = 10,
    primary_rules = c("EFFICIENT_UP_CONTINUATION", "NOT_HIGH_ATR_LOSS_REBOUND"),
    rule_ids = c(
      "EFFICIENT_UP_CONTINUATION",
      "POSITIVE_R20_ONLY",
      "EFFICIENT_STATE_ONLY",
      "EFFICIENT_DOWN_OPPOSITE",
      "NOT_HIGH_ATR_LOSS_REBOUND",
      "NEGATIVE_R20_ONLY",
      "NOT_HIGH_ATR_STATE_ONLY",
      "NOT_HIGH_ATR_POSITIVE_OPPOSITE"
    )
  )
}

nvpr_confirmation_contract <- function() {
  contract <- nvpr_contract()
  contract$study_id <- "NVDA_DAILY_PROTO_RULES_CONFIRMATION_01"
  contract$sample_role <- "CONFIRMATION"
  contract$analysis_start <- as.Date("2024-01-02")
  contract$analysis_end <- as.Date("2026-06-23")
  contract$primary_rules <- "NOT_HIGH_ATR_LOSS_REBOUND"
  contract$rule_ids <- c(
    "NOT_HIGH_ATR_LOSS_REBOUND",
    "NEGATIVE_R20_ONLY",
    "NOT_HIGH_ATR_STATE_ONLY",
    "NOT_HIGH_ATR_POSITIVE_OPPOSITE"
  )
  contract$minimum_confirmation_trades <- 10L
  contract
}

nvpr_validate_contract <- function(contract = nvpr_contract()) {
  if (!identical(contract$symbol, "NVDA") ||
      !identical(contract$prior_sessions, 20L) ||
      !identical(contract$hold_sessions, 20L) ||
      !isTRUE(all.equal(contract$er_cutoff, 0.30)) ||
      !identical(contract$rebound_atrp_states, c("LOW", "MEDIUM")) ||
      !identical(contract$round_trip_cost_bps, 10)) {
    nvpr_stop("The frozen symbol, horizon, state, or cost contract changed.")
  }
  if (!contract$sample_role %in% c("TRAIN", "CONFIRMATION")) {
    nvpr_stop("Sample role must be TRAIN or CONFIRMATION.")
  }
  if (contract$sample_role == "TRAIN" &&
      (!identical(contract$analysis_start, as.Date("2018-01-02")) ||
       !identical(contract$analysis_end, as.Date("2023-12-29")))) {
    nvpr_stop("The frozen TRAIN boundary changed.")
  }
  if (contract$sample_role == "CONFIRMATION" &&
      (!identical(contract$analysis_start, as.Date("2024-01-02")) ||
       !identical(contract$analysis_end, as.Date("2026-06-23")) ||
       !identical(contract$primary_rules, "NOT_HIGH_ATR_LOSS_REBOUND") ||
       !identical(contract$minimum_confirmation_trades, 10L))) {
    nvpr_stop("The frozen one-shot confirmation contract changed.")
  }
  contract
}

nvpr_rule_map <- function() {
  c(
    EFFICIENT_UP_CONTINUATION = "efficient_up_continuation_signal",
    POSITIVE_R20_ONLY = "positive_r20_signal",
    EFFICIENT_STATE_ONLY = "efficient_state_signal",
    EFFICIENT_DOWN_OPPOSITE = "efficient_down_signal",
    NOT_HIGH_ATR_LOSS_REBOUND = "not_high_atr_loss_rebound_signal",
    NEGATIVE_R20_ONLY = "negative_r20_signal",
    NOT_HIGH_ATR_STATE_ONLY = "not_high_atr_state_signal",
    NOT_HIGH_ATR_POSITIVE_OPPOSITE = "not_high_atr_positive_signal"
  )
}

nvpr_rule_family <- function(rule_id) {
  ifelse(
    rule_id %in% c(
      "EFFICIENT_UP_CONTINUATION", "POSITIVE_R20_ONLY",
      "EFFICIENT_STATE_ONLY", "EFFICIENT_DOWN_OPPOSITE"
    ),
    "EFFICIENT_UP_CONTINUATION",
    "NOT_HIGH_ATR_LOSS_REBOUND"
  )
}

nvpr_construct_candidates <- function(ledger, contract = nvpr_contract()) {
  contract <- nvpr_validate_contract(contract)
  required <- c(
    "symbol", "session_date", "open", "high", "low", "close",
    "er20", "er20_state", "atrp_state"
  )
  missing <- setdiff(required, names(ledger))
  if (length(missing)) nvpr_stop(paste("Ledger is missing:", paste(missing, collapse = ", ")))
  x <- ledger[order(as.Date(ledger$session_date)), required, drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  numeric_fields <- c("open", "high", "low", "close", "er20")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  if (!all(x$symbol == contract$symbol) || anyDuplicated(x$session_date) ||
      any(diff(x$session_date) <= 0) ||
      any(!is.finite(as.matrix(x[c("open", "high", "low", "close")]))) ||
      any(as.matrix(x[c("open", "high", "low", "close")]) <= 0)) {
    nvpr_stop("Ledger symbol, dates, or prices are invalid.")
  }

  n <- nrow(x)
  prior <- c(
    rep(NA_real_, contract$prior_sessions),
    log(x$close[(contract$prior_sessions + 1L):n] /
          x$close[seq_len(n - contract$prior_sessions)])
  )
  anchors <- seq_len(n)
  entry_index <- anchors + 1L
  exit_index <- entry_index + contract$hold_sessions
  valid <- anchors > contract$prior_sessions & exit_index <= n &
    x$session_date[anchors] >= contract$analysis_start &
    x$session_date[exit_index] <= contract$analysis_end
  anchors <- anchors[valid]
  entry_index <- entry_index[valid]
  exit_index <- exit_index[valid]

  excursion <- lapply(seq_along(anchors), function(i) {
    held <- entry_index[[i]]:(exit_index[[i]] - 1L)
    entry <- x$open[entry_index[[i]]]
    highs <- c(x$high[held], x$open[exit_index[[i]]])
    lows <- c(x$low[held], x$open[exit_index[[i]]])
    c(
      maximum_favorable_excursion = max(log(highs / entry)),
      maximum_adverse_excursion = min(log(lows / entry))
    )
  })
  excursion <- do.call(rbind, excursion)

  out <- data.frame(
    symbol = x$symbol[anchors],
    anchor_index = anchors,
    anchor_session = x$session_date[anchors],
    anchor_close = x$close[anchors],
    prior_20_log_return = prior[anchors],
    er20 = x$er20[anchors],
    er20_state = as.character(x$er20_state[anchors]),
    atrp_state = as.character(x$atrp_state[anchors]),
    entry_index = entry_index,
    entry_session = x$session_date[entry_index],
    entry_open = x$open[entry_index],
    exit_index = exit_index,
    exit_session = x$session_date[exit_index],
    exit_open = x$open[exit_index],
    gross_open_log_return = log(x$open[exit_index] / x$open[entry_index]),
    maximum_favorable_excursion = excursion[, "maximum_favorable_excursion"],
    maximum_adverse_excursion = excursion[, "maximum_adverse_excursion"],
    stringsAsFactors = FALSE
  )
  out$net_open_log_return <- out$gross_open_log_return -
    contract$round_trip_cost_bps / 10000
  out$positive_r20_signal <- out$prior_20_log_return > 0
  out$negative_r20_signal <- out$prior_20_log_return < 0
  out$efficient_state_signal <- out$er20_state == "GREEN_TRENDING"
  out$not_high_atr_state_signal <- out$atrp_state %in% contract$rebound_atrp_states
  out$efficient_up_continuation_signal <- out$positive_r20_signal &
    out$efficient_state_signal
  out$efficient_down_signal <- out$negative_r20_signal &
    out$efficient_state_signal
  out$not_high_atr_loss_rebound_signal <- out$negative_r20_signal &
    out$not_high_atr_state_signal
  out$not_high_atr_positive_signal <- out$positive_r20_signal &
    out$not_high_atr_state_signal
  out
}

nvpr_select_nonoverlapping <- function(candidates, signal_column, rule_id) {
  if (!signal_column %in% names(candidates)) {
    nvpr_stop(paste("Missing signal column", signal_column))
  }
  x <- candidates[order(candidates$anchor_index), , drop = FALSE]
  selected <- logical(nrow(x))
  next_eligible_anchor <- -Inf
  for (i in seq_len(nrow(x))) {
    if (isTRUE(x[[signal_column]][[i]]) &&
        x$anchor_index[[i]] >= next_eligible_anchor) {
      selected[[i]] <- TRUE
      next_eligible_anchor <- x$exit_index[[i]]
    }
  }
  out <- x[selected, , drop = FALSE]
  rownames(out) <- NULL
  out$rule_id <- rule_id
  out$rule_family <- nvpr_rule_family(rule_id)
  out
}

nvpr_build_study <- function(ledger, contract = nvpr_contract()) {
  contract <- nvpr_validate_contract(contract)
  candidates <- nvpr_construct_candidates(ledger, contract)
  unconditional <- mean(candidates$gross_open_log_return)
  trades <- do.call(rbind, lapply(contract$rule_ids, function(rule_id) {
    x <- nvpr_select_nonoverlapping(
      candidates, nvpr_rule_map()[[rule_id]], rule_id
    )
    x$unconditional_open_log_return <- unconditional
    x$net_excess_vs_unconditional <- x$net_open_log_return - unconditional
    x
  }))
  rownames(trades) <- NULL
  list(candidates = candidates, trades = trades)
}

nvpr_confirmation_gate <- function(rule_summary, contract = nvpr_confirmation_contract()) {
  contract <- nvpr_validate_contract(contract)
  if (!identical(contract$sample_role, "CONFIRMATION")) {
    nvpr_stop("Confirmation gate requires the confirmation contract.")
  }
  primary <- rule_summary[
    rule_summary$rule_id == "NOT_HIGH_ATR_LOSS_REBOUND", , drop = FALSE
  ]
  controls <- rule_summary[
    rule_summary$rule_id %in% setdiff(contract$rule_ids, contract$primary_rules),
    , drop = FALSE
  ]
  if (nrow(primary) != 1L || nrow(controls) != 3L) {
    nvpr_stop("Confirmation summary is missing the primary rule or controls.")
  }
  checks <- data.frame(
    gate_id = c(
      "minimum_trade_count", "mean_beats_unconditional_drift",
      "median_is_positive", "majority_profitable",
      "mean_beats_each_ingredient_control"
    ),
    passed = c(
      primary$trades >= contract$minimum_confirmation_trades,
      primary$mean_net_excess_vs_unconditional > 0,
      primary$median_net_open_log_return > 0,
      primary$probability_profitable_net > 0.50,
      primary$mean_net_open_log_return > max(controls$mean_net_open_log_return)
    ),
    observed = c(
      sprintf("%d trades; minimum %d", primary$trades, contract$minimum_confirmation_trades),
      sprintf("%+.2f percentage points", 100 * primary$mean_net_excess_vs_unconditional),
      sprintf("%+.2f%%", 100 * primary$median_net_open_log_return),
      sprintf("%.1f%%", 100 * primary$probability_profitable_net),
      sprintf(
        "primary %.2f%%; strongest control %.2f%%",
        100 * primary$mean_net_open_log_return,
        100 * max(controls$mean_net_open_log_return)
      )
    ),
    stringsAsFactors = FALSE
  )
  list(
    checks = checks,
    verdict = if (all(checks$passed)) "CONFIRMED_ON_FROZEN_OOS" else
      "STOP_CONFIRMATION_GATES_FAILED"
  )
}

nvpr_rule_summary <- function(trades, contract = nvpr_contract()) {
  contract <- nvpr_validate_contract(contract)
  rows <- lapply(contract$rule_ids, function(rule_id) {
    x <- trades[trades$rule_id == rule_id, , drop = FALSE]
    data.frame(
      rule_family = nvpr_rule_family(rule_id),
      rule_id = rule_id,
      primary_rule = rule_id %in% contract$primary_rules,
      trades = nrow(x),
      mean_net_open_log_return = if (nrow(x)) mean(x$net_open_log_return) else NA_real_,
      median_net_open_log_return = if (nrow(x)) stats::median(x$net_open_log_return) else NA_real_,
      probability_profitable_net = if (nrow(x)) mean(x$net_open_log_return > 0) else NA_real_,
      mean_net_excess_vs_unconditional = if (nrow(x)) mean(x$net_excess_vs_unconditional) else NA_real_,
      mean_maximum_favorable_excursion = if (nrow(x)) mean(x$maximum_favorable_excursion) else NA_real_,
      mean_maximum_adverse_excursion = if (nrow(x)) mean(x$maximum_adverse_excursion) else NA_real_,
      unconditional_open_log_return = if (nrow(x)) x$unconditional_open_log_return[[1L]] else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

nvpr_calendar_summary <- function(trades) {
  if (!nrow(trades)) return(data.frame())
  trades$entry_year <- as.integer(format(trades$entry_session, "%Y"))
  groups <- split(trades, interaction(trades$entry_year, trades$rule_id, drop = TRUE))
  out <- do.call(rbind, lapply(groups, function(x) data.frame(
    entry_year = x$entry_year[[1L]],
    rule_id = x$rule_id[[1L]],
    rule_family = x$rule_family[[1L]],
    trades = nrow(x),
    mean_net_open_log_return = mean(x$net_open_log_return),
    median_net_open_log_return = stats::median(x$net_open_log_return),
    probability_profitable_net = mean(x$net_open_log_return > 0),
    stringsAsFactors = FALSE
  )))
  rownames(out) <- NULL
  out[order(out$entry_year, out$rule_id), , drop = FALSE]
}

nvpr_condition_summary <- function(candidates) {
  rules <- nvpr_rule_map()
  rows <- lapply(names(rules), function(rule_id) {
    x <- candidates[candidates[[rules[[rule_id]]]], , drop = FALSE]
    data.frame(
      rule_family = nvpr_rule_family(rule_id),
      rule_id = rule_id,
      overlapping_observations = nrow(x),
      mean_gross_open_log_return = if (nrow(x)) mean(x$gross_open_log_return) else NA_real_,
      probability_profitable_gross = if (nrow(x)) mean(x$gross_open_log_return > 0) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

nvpr_trade_paths <- function(ledger, trades) {
  rows <- list()
  index <- 0L
  for (i in seq_len(nrow(trades))) {
    trade <- trades[i, , drop = FALSE]
    held <- trade$entry_index:trade$exit_index
    path_return <- log(ledger$open[held] / trade$entry_open)
    for (j in seq_along(held)) {
      index <- index + 1L
      rows[[index]] <- data.frame(
        rule_id = trade$rule_id,
        anchor_session = trade$anchor_session,
        entry_session = trade$entry_session,
        exit_session = trade$exit_session,
        held_session = j - 1L,
        path_session = ledger$session_date[held[[j]]],
        cumulative_open_log_return = path_return[[j]],
        final_net_open_log_return = trade$net_open_log_return,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

nvpr_realized_equity_path <- function(ledger, trades, rule_id) {
  x <- trades[trades$rule_id == rule_id, , drop = FALSE]
  dates <- ledger$session_date[
    ledger$session_date >= min(trades$entry_session) &
      ledger$session_date <= max(trades$exit_session)
  ]
  equity <- rep(1, length(dates))
  realized <- 1
  for (i in seq_along(dates)) {
    exits <- x[x$exit_session == dates[[i]], , drop = FALSE]
    if (nrow(exits)) realized <- realized * exp(sum(exits$net_open_log_return))
    equity[[i]] <- realized
  }
  data.frame(
    session_date = dates,
    rule_id = rule_id,
    realized_equity = equity,
    stringsAsFactors = FALSE
  )
}
