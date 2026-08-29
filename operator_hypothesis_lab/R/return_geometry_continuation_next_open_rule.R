rgcnor_stop <- function(message) {
  stop(paste0("[RETURN-GEOMETRY-CONTINUATION-NEXT-OPEN] ", message), call. = FALSE)
}

rgcnor_contract <- function() {
  list(
    study_id = "RETURN_GEOMETRY_CONTINUATION_NEXT_OPEN_RULE_01",
    source_contrast_id = "RETURN_GEOMETRY_CONTINUATION_STATE_CONTRAST_01",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    as_of_timestamp = "2026-08-27 17:30:00 America/New_York",
    prior_sessions = 20L,
    hold_sessions = c(5L, 10L, 20L),
    er_window = 20L,
    er_cutoff = 0.30,
    sideways_state = "RED_SIDEWAYS",
    trending_state = "GREEN_TRENDING",
    round_trip_cost_bps = 10,
    expected_assets = 129L,
    expected_core_assets = 88L,
    expected_sectors = 11L
  )
}

rgcnor_validate_contract <- function(contract = rgcnor_contract()) {
  if (contract$prior_sessions != 20L || contract$er_window != 20L ||
      !identical(as.integer(contract$hold_sessions), c(5L, 10L, 20L))) {
    rgcnor_stop("The frozen 20-session prior and 5/10/20-session hold contract changed.")
  }
  if (!isTRUE(all.equal(contract$er_cutoff, 0.30)) ||
      !identical(contract$sideways_state, "RED_SIDEWAYS") ||
      !identical(contract$trending_state, "GREEN_TRENDING")) {
    rgcnor_stop("The inherited causal ER20 state definition changed.")
  }
  if (contract$round_trip_cost_bps < 0 || contract$analysis_end > as.Date("2023-12-29")) {
    rgcnor_stop("Cost or sealed analysis boundary is invalid.")
  }
  contract
}

rgcnor_prior_log_return <- function(close, sessions = 20L) {
  close <- as.numeric(close)
  sessions <- as.integer(sessions)
  if (sessions < 1L || length(close) <= sessions ||
      any(!is.finite(close)) || any(close <= 0)) {
    rgcnor_stop("Close data cannot support the requested prior return.")
  }
  c(
    rep(NA_real_, sessions),
    log(close[(sessions + 1L):length(close)] /
          close[seq_len(length(close) - sessions)])
  )
}

rgcnor_construct_candidates <- function(ledger, hold_sessions,
                                        contract = rgcnor_contract()) {
  contract <- rgcnor_validate_contract(contract)
  hold_sessions <- as.integer(hold_sessions)
  if (length(hold_sessions) != 1L || !hold_sessions %in% contract$hold_sessions) {
    rgcnor_stop("Hold must be one frozen 5/10/20-session diagnostic.")
  }
  required <- c("symbol", "session_date", "open", "close", "er20", "er20_state")
  missing <- setdiff(required, names(ledger))
  if (length(missing)) rgcnor_stop(paste("Ledger is missing:", paste(missing, collapse = ", ")))

  x <- ledger[order(as.Date(ledger$session_date)), required, drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  x$open <- as.numeric(x$open)
  x$close <- as.numeric(x$close)
  if (anyDuplicated(x$session_date) || any(diff(x$session_date) <= 0) ||
      any(!is.finite(x$open)) || any(!is.finite(x$close)) ||
      any(x$open <= 0) || any(x$close <= 0)) {
    rgcnor_stop("Ledger dates or prices are invalid.")
  }

  prior <- rgcnor_prior_log_return(x$close, contract$prior_sessions)
  anchor_index <- seq_len(nrow(x))
  entry_index <- anchor_index + 1L
  exit_index <- entry_index + hold_sessions
  research_exit_index <- anchor_index + hold_sessions
  valid <- anchor_index > contract$prior_sessions &
    exit_index <= nrow(x) &
    x$session_date[anchor_index] >= contract$analysis_start &
    x$session_date[exit_index] <= contract$analysis_end
  anchor_index <- anchor_index[valid]
  entry_index <- entry_index[valid]
  exit_index <- exit_index[valid]
  research_exit_index <- research_exit_index[valid]

  out <- data.frame(
    symbol = as.character(x$symbol[anchor_index]),
    hold_sessions = hold_sessions,
    anchor_index = anchor_index,
    anchor_session = x$session_date[anchor_index],
    anchor_close = x$close[anchor_index],
    prior_20_log_return = prior[anchor_index],
    er20 = as.numeric(x$er20[anchor_index]),
    er20_state = as.character(x$er20_state[anchor_index]),
    entry_index = entry_index,
    entry_session = x$session_date[entry_index],
    entry_open = x$open[entry_index],
    exit_index = exit_index,
    exit_session = x$session_date[exit_index],
    exit_open = x$open[exit_index],
    research_exit_session = x$session_date[research_exit_index],
    research_exit_close = x$close[research_exit_index],
    stringsAsFactors = FALSE
  )
  out$sideways_positive_signal <- is.finite(out$prior_20_log_return) &
    out$prior_20_log_return > 0 & out$er20_state == contract$sideways_state
  out$trending_positive_signal <- is.finite(out$prior_20_log_return) &
    out$prior_20_log_return > 0 & out$er20_state == contract$trending_state
  out$positive_only_signal <- is.finite(out$prior_20_log_return) & out$prior_20_log_return > 0
  out$sideways_only_signal <- out$er20_state == contract$sideways_state
  out$entry_gap_log_return <- log(out$entry_open / out$anchor_close)
  out$gross_open_log_return <- log(out$exit_open / out$entry_open)
  out$net_open_log_return <- out$gross_open_log_return - contract$round_trip_cost_bps / 10000
  out$research_close_log_return <- log(out$research_exit_close / out$anchor_close)
  out$translation_difference <- out$gross_open_log_return - out$research_close_log_return
  out
}

rgcnor_rule_map <- function() {
  c(
    SIDEWAYS_POSITIVE = "sideways_positive_signal",
    TRENDING_POSITIVE = "trending_positive_signal",
    POSITIVE_ONLY = "positive_only_signal",
    SIDEWAYS_ONLY = "sideways_only_signal"
  )
}

rgcnor_select_nonoverlapping <- function(candidates, signal_column, rule_id) {
  if (!signal_column %in% names(candidates)) {
    rgcnor_stop(paste("Candidate frame is missing signal column", signal_column))
  }
  x <- candidates[order(candidates$anchor_index), , drop = FALSE]
  selected <- logical(nrow(x))
  next_eligible_anchor <- -Inf
  for (i in seq_len(nrow(x))) {
    if (isTRUE(x[[signal_column]][[i]]) && x$anchor_index[[i]] >= next_eligible_anchor) {
      selected[[i]] <- TRUE
      next_eligible_anchor <- x$exit_index[[i]]
    }
  }
  out <- x[selected, , drop = FALSE]
  rownames(out) <- NULL
  out$rule_id <- rule_id
  out
}

rgcnor_build_asset_horizon_study <- function(ledger, hold_sessions,
                                             contract = rgcnor_contract()) {
  candidates <- rgcnor_construct_candidates(ledger, hold_sessions, contract)
  unconditional <- mean(candidates$gross_open_log_return, na.rm = TRUE)
  rules <- rgcnor_rule_map()
  trades <- do.call(rbind, lapply(names(rules), function(rule_id) {
    selected <- rgcnor_select_nonoverlapping(candidates, rules[[rule_id]], rule_id)
    selected$unconditional_open_log_return <- unconditional
    selected$net_excess_vs_unconditional <- selected$net_open_log_return - unconditional
    selected
  }))
  rownames(trades) <- NULL
  list(candidates = candidates, trades = trades)
}

rgcnor_rule_summary <- function(trades, rule_ids = names(rgcnor_rule_map())) {
  rows <- lapply(rule_ids, function(rule_id) {
    x <- trades[trades$rule_id == rule_id, , drop = FALSE]
    data.frame(
      rule_id = rule_id,
      trades = nrow(x),
      mean_gross_open_log_return = if (nrow(x)) mean(x$gross_open_log_return) else NA_real_,
      mean_net_open_log_return = if (nrow(x)) mean(x$net_open_log_return) else NA_real_,
      median_net_open_log_return = if (nrow(x)) stats::median(x$net_open_log_return) else NA_real_,
      probability_profitable_net = if (nrow(x)) mean(x$net_open_log_return > 0) else NA_real_,
      mean_research_close_log_return = if (nrow(x)) mean(x$research_close_log_return) else NA_real_,
      mean_translation_difference = if (nrow(x)) mean(x$translation_difference) else NA_real_,
      unconditional_open_log_return = if (nrow(x)) x$unconditional_open_log_return[[1L]] else NA_real_,
      mean_net_excess_vs_unconditional = if (nrow(x)) mean(x$net_excess_vs_unconditional) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

rgcnor_asset_comparison <- function(asset_rule_summary) {
  required <- c("symbol", "hold_sessions", "rule_id", "trades", "mean_net_open_log_return",
                "mean_net_excess_vs_unconditional", "unconditional_open_log_return")
  missing <- setdiff(required, names(asset_rule_summary))
  if (length(missing)) rgcnor_stop(paste("Rule summary is missing:", paste(missing, collapse = ", ")))
  keys <- c("symbol", "hold_sessions")
  primary <- asset_rule_summary[asset_rule_summary$rule_id == "SIDEWAYS_POSITIVE", ]
  out <- primary[c(keys, "trades", "mean_net_open_log_return", "mean_net_excess_vs_unconditional",
                   "unconditional_open_log_return")]
  names(out)[3:5] <- c("primary_trades", "primary_mean_net_log_return",
                       "primary_mean_net_excess_vs_unconditional")
  for (rule_id in c("TRENDING_POSITIVE", "POSITIVE_ONLY", "SIDEWAYS_ONLY")) {
    control <- asset_rule_summary[asset_rule_summary$rule_id == rule_id,
                                  c(keys, "trades", "mean_net_open_log_return")]
    suffix <- tolower(rule_id)
    names(control)[3:4] <- paste0(c("trades_", "mean_net_"), suffix)
    out <- merge(out, control, by = keys, all = TRUE, sort = FALSE)
  }
  out$primary_minus_trending <- out$primary_mean_net_log_return - out$mean_net_trending_positive
  out$primary_minus_positive_only <- out$primary_mean_net_log_return - out$mean_net_positive_only
  out$primary_minus_sideways_only <- out$primary_mean_net_log_return - out$mean_net_sideways_only
  out[order(out$symbol, out$hold_sessions), ]
}

rgcnor_group_summary <- function(asset_comparison, grouping_fields) {
  metrics <- c(
    "primary_mean_net_log_return", "primary_mean_net_excess_vs_unconditional",
    "primary_minus_trending", "primary_minus_positive_only", "primary_minus_sideways_only"
  )
  keys <- interaction(asset_comparison[grouping_fields], drop = TRUE, lex.order = TRUE)
  groups <- split(asset_comparison, keys)
  out <- do.call(rbind, lapply(groups, function(x) {
    active <- x$primary_trades > 0L & is.finite(x$primary_mean_net_log_return)
    values <- lapply(metrics, function(metric) {
      v <- x[[metric]][active & is.finite(x[[metric]])]
      c(median = if (length(v)) stats::median(v) else NA_real_,
        positive_fraction = if (length(v)) mean(v > 0) else NA_real_)
    })
    names(values) <- metrics
    data.frame(
      x[1L, grouping_fields, drop = FALSE],
      assets = nrow(x),
      active_assets = sum(active),
      total_primary_trades = sum(x$primary_trades, na.rm = TRUE),
      median_primary_trades_per_active_asset = if (any(active)) stats::median(x$primary_trades[active]) else NA_real_,
      median_asset_primary_mean_net_log_return = values$primary_mean_net_log_return[["median"]],
      positive_net_asset_fraction = values$primary_mean_net_log_return[["positive_fraction"]],
      median_asset_primary_excess_vs_unconditional = values$primary_mean_net_excess_vs_unconditional[["median"]],
      positive_excess_asset_fraction = values$primary_mean_net_excess_vs_unconditional[["positive_fraction"]],
      median_asset_primary_minus_trending = values$primary_minus_trending[["median"]],
      positive_primary_minus_trending_asset_fraction = values$primary_minus_trending[["positive_fraction"]],
      median_asset_primary_minus_positive_only = values$primary_minus_positive_only[["median"]],
      median_asset_primary_minus_sideways_only = values$primary_minus_sideways_only[["median"]],
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}

rgcnor_equal_sector_summary <- function(sector_summary) {
  horizons <- sort(unique(sector_summary$hold_sessions))
  rows <- lapply(horizons, function(hold) {
    x <- sector_summary[sector_summary$hold_sessions == hold, , drop = FALSE]
    data.frame(
      hold_sessions = hold,
      sectors = nrow(x),
      active_assets = sum(x$active_assets),
      total_primary_trades = sum(x$total_primary_trades),
      equal_sector_median_asset_primary_mean_net_log_return = stats::median(x$median_asset_primary_mean_net_log_return),
      equal_sector_median_asset_primary_excess_vs_unconditional = stats::median(x$median_asset_primary_excess_vs_unconditional),
      equal_sector_median_asset_primary_minus_trending = stats::median(x$median_asset_primary_minus_trending),
      equal_sector_median_asset_primary_minus_positive_only = stats::median(x$median_asset_primary_minus_positive_only),
      equal_sector_median_asset_primary_minus_sideways_only = stats::median(x$median_asset_primary_minus_sideways_only),
      positive_excess_sectors = sum(x$median_asset_primary_excess_vs_unconditional > 0),
      positive_primary_minus_trending_sectors = sum(x$median_asset_primary_minus_trending > 0),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

rgcnor_build_trade_paths <- function(ledger, trades) {
  if (!nrow(trades)) return(data.frame())
  rows <- vector("list", nrow(trades))
  for (i in seq_len(nrow(trades))) {
    indices <- trades$entry_index[[i]]:trades$exit_index[[i]]
    rows[[i]] <- data.frame(
      symbol = trades$symbol[[i]],
      rule_id = trades$rule_id[[i]],
      hold_sessions = trades$hold_sessions[[i]],
      anchor_session = trades$anchor_session[[i]],
      held_session = seq_along(indices) - 1L,
      cumulative_open_log_return = log(ledger$open[indices] / ledger$open[[indices[[1L]]]]),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
