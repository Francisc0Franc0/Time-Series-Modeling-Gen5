rgnor_stop <- function(message) {
  stop(paste0("[RETURN-GEOMETRY-NEXT-OPEN-RULE] ", message), call. = FALSE)
}

rgnor_contract <- function() {
  list(
    study_id = "RETURN_GEOMETRY_NEXT_OPEN_RULE_TRANSLATION_01",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    as_of_timestamp = "2026-08-27 17:30:00 America/New_York",
    prior_sessions = 20L,
    hold_sessions = 20L,
    entry_offset = 1L,
    exit_offset = 21L,
    state_column = "signed_er20_state",
    state = "DOWN_TREND",
    severity_quantile = 0.20,
    quantile_type = 7L,
    minimum_prior_negative_observations = 100L,
    round_trip_cost_bps = 10,
    expected_assets = 129L,
    expected_core_assets = 88L,
    expected_sectors = 11L,
    minimum_active_core_assets = 70L,
    minimum_positive_excess_sectors = 7L
  )
}

rgnor_validate_contract <- function(contract = rgnor_contract()) {
  if (contract$prior_sessions != 20L || contract$hold_sessions != 20L ||
      contract$entry_offset != 1L || contract$exit_offset != 21L) {
    rgnor_stop("The frozen 20-prior / next-open / 20-session rule changed.")
  }
  if (!isTRUE(all.equal(contract$severity_quantile, 0.20)) ||
      contract$minimum_prior_negative_observations < 1L) {
    rgnor_stop("The causal negative-return severity rule is invalid.")
  }
  if (contract$analysis_end > as.Date("2023-12-29")) {
    rgnor_stop("Post-2023 outcomes are sealed.")
  }
  contract
}

rgnor_prior_log_return <- function(close, sessions = 20L) {
  close <- as.numeric(close)
  sessions <- as.integer(sessions)
  if (sessions < 1L || length(close) <= sessions ||
      any(!is.finite(close)) || any(close <= 0)) {
    rgnor_stop("Close data cannot support the requested prior return.")
  }
  c(rep(NA_real_, sessions), log(close[(sessions + 1L):length(close)] /
    close[seq_len(length(close) - sessions)]))
}

rgnor_causal_negative_threshold <- function(prior_return,
                                            probability = 0.20,
                                            minimum_observations = 100L,
                                            quantile_type = 7L) {
  x <- as.numeric(prior_return)
  out <- rep(NA_real_, length(x))
  history_n <- integer(length(x))
  for (i in seq_along(x)) {
    history <- if (i > 1L) x[seq_len(i - 1L)] else numeric()
    history <- history[is.finite(history) & history < 0]
    history_n[[i]] <- length(history)
    if (length(history) >= minimum_observations) {
      out[[i]] <- as.numeric(stats::quantile(
        history, probs = probability, type = quantile_type, names = FALSE
      ))
    }
  }
  data.frame(
    negative_history_observations = history_n,
    negative_return_q20 = out,
    stringsAsFactors = FALSE
  )
}

rgnor_construct_candidates <- function(ledger, contract = rgnor_contract()) {
  contract <- rgnor_validate_contract(contract)
  required <- c(
    "symbol", "session_date", "open", "close", "signed_er20",
    contract$state_column
  )
  missing <- setdiff(required, names(ledger))
  if (length(missing)) rgnor_stop(paste("Ledger is missing:", paste(missing, collapse = ", ")))
  x <- ledger[order(as.Date(ledger$session_date)), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  if (anyDuplicated(x$session_date) || any(diff(x$session_date) <= 0) ||
      any(!is.finite(x$open)) || any(!is.finite(x$close)) ||
      any(x$open <= 0) || any(x$close <= 0)) {
    rgnor_stop("Ledger dates or prices are invalid.")
  }

  prior <- rgnor_prior_log_return(x$close, contract$prior_sessions)
  threshold <- rgnor_causal_negative_threshold(
    prior,
    probability = contract$severity_quantile,
    minimum_observations = contract$minimum_prior_negative_observations,
    quantile_type = contract$quantile_type
  )
  anchor_index <- seq_len(nrow(x))
  entry_index <- anchor_index + contract$entry_offset
  exit_index <- anchor_index + contract$exit_offset
  research_exit_index <- anchor_index + contract$hold_sessions
  valid <- anchor_index > contract$prior_sessions &
    exit_index <= nrow(x) & research_exit_index <= nrow(x) &
    x$session_date >= contract$analysis_start &
    x$session_date[exit_index] <= contract$analysis_end
  anchor_index <- anchor_index[valid]
  entry_index <- entry_index[valid]
  exit_index <- exit_index[valid]
  research_exit_index <- research_exit_index[valid]

  out <- data.frame(
    symbol = as.character(x$symbol[anchor_index]),
    anchor_index = anchor_index,
    anchor_session = x$session_date[anchor_index],
    anchor_close = x$close[anchor_index],
    prior_20_log_return = prior[anchor_index],
    negative_history_observations = threshold$negative_history_observations[anchor_index],
    negative_return_q20 = threshold$negative_return_q20[anchor_index],
    signed_er20 = as.numeric(x$signed_er20[anchor_index]),
    signed_er20_state = as.character(x[[contract$state_column]][anchor_index]),
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
  out$state_signal <- !is.na(out$signed_er20_state) &
    out$signed_er20_state == contract$state & out$prior_20_log_return < 0
  out$primary_signal <- out$state_signal &
    is.finite(out$negative_return_q20) &
    out$prior_20_log_return <= out$negative_return_q20
  out$entry_gap_log_return <- log(out$entry_open / out$anchor_close)
  out$gross_open_log_return <- log(out$exit_open / out$entry_open)
  out$net_open_log_return <- out$gross_open_log_return -
    contract$round_trip_cost_bps / 10000
  out$research_close_log_return <- log(out$research_exit_close / out$anchor_close)
  out$translation_difference <- out$gross_open_log_return -
    out$research_close_log_return
  out
}

rgnor_select_nonoverlapping <- function(candidates, signal_column,
                                        contract = rgnor_contract()) {
  if (!signal_column %in% names(candidates)) {
    rgnor_stop(paste("Candidate frame is missing signal column", signal_column))
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
  out$rule_id <- if (signal_column == "primary_signal") {
    "SIGNED_DOWN_NEGATIVE_Q20"
  } else {
    "SIGNED_DOWN_STATE_ONLY"
  }
  out
}

rgnor_add_unconditional_baseline <- function(trades, candidates) {
  baseline <- mean(candidates$gross_open_log_return, na.rm = TRUE)
  trades$unconditional_open_log_return <- baseline
  trades$gross_excess_vs_unconditional <- trades$gross_open_log_return - baseline
  trades$net_excess_vs_unconditional <- trades$net_open_log_return - baseline
  trades
}

rgnor_build_asset_study <- function(ledger, contract = rgnor_contract()) {
  candidates <- rgnor_construct_candidates(ledger, contract)
  primary <- rgnor_select_nonoverlapping(candidates, "primary_signal", contract)
  state_only <- rgnor_select_nonoverlapping(candidates, "state_signal", contract)
  primary <- rgnor_add_unconditional_baseline(primary, candidates)
  state_only <- rgnor_add_unconditional_baseline(state_only, candidates)
  state_only_mean <- if (nrow(state_only)) mean(state_only$net_open_log_return) else NA_real_
  primary$state_only_mean_net_log_return <- state_only_mean
  primary$net_difference_vs_state_only <- primary$net_open_log_return - state_only_mean
  list(candidates = candidates, primary = primary, state_only = state_only)
}

rgnor_build_trade_paths <- function(ledger, trades, contract = rgnor_contract()) {
  if (!nrow(trades)) return(data.frame())
  rows <- vector("list", nrow(trades))
  for (i in seq_len(nrow(trades))) {
    entry <- trades$entry_index[[i]]
    indices <- entry + 0:contract$hold_sessions
    rows[[i]] <- data.frame(
      symbol = trades$symbol[[i]],
      anchor_session = trades$anchor_session[[i]],
      entry_session = trades$entry_session[[i]],
      exit_session = trades$exit_session[[i]],
      held_session = 0:contract$hold_sessions,
      cumulative_open_log_return = log(ledger$open[indices] / ledger$open[[entry]]),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

rgnor_asset_summary <- function(primary, state_only) {
  summarize <- function(x) {
    if (!nrow(x)) {
      return(data.frame(
        trades = 0L, mean_gross_open_log_return = NA_real_,
        mean_net_open_log_return = NA_real_, median_net_open_log_return = NA_real_,
        probability_profitable_net = NA_real_, mean_research_close_log_return = NA_real_,
        mean_translation_difference = NA_real_, mean_net_excess_vs_unconditional = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    data.frame(
      trades = nrow(x),
      mean_gross_open_log_return = mean(x$gross_open_log_return),
      mean_net_open_log_return = mean(x$net_open_log_return),
      median_net_open_log_return = stats::median(x$net_open_log_return),
      probability_profitable_net = mean(x$net_open_log_return > 0),
      mean_research_close_log_return = mean(x$research_close_log_return),
      mean_translation_difference = mean(x$translation_difference),
      mean_net_excess_vs_unconditional = mean(x$net_excess_vs_unconditional),
      stringsAsFactors = FALSE
    )
  }
  primary_summary <- summarize(primary)
  state_summary <- summarize(state_only)
  names(state_summary) <- paste0("state_only_", names(state_summary))
  out <- cbind(primary_summary, state_summary)
  out$mean_net_difference_vs_state_only <-
    out$mean_net_open_log_return - out$state_only_mean_net_open_log_return
  out
}

rgnor_summarize_assets <- function(asset_summary, grouping_fields) {
  keys <- interaction(asset_summary[grouping_fields], drop = TRUE, lex.order = TRUE)
  groups <- split(asset_summary, keys)
  out <- do.call(rbind, lapply(groups, function(x) {
    active <- x$trades > 0L & is.finite(x$mean_net_open_log_return)
    data.frame(
      assets = nrow(x),
      active_assets = sum(active),
      total_trades = sum(x$trades),
      median_trades_per_active_asset = if (any(active)) stats::median(x$trades[active]) else NA_real_,
      median_asset_mean_net_log_return = if (any(active)) stats::median(x$mean_net_open_log_return[active]) else NA_real_,
      median_asset_mean_net_excess = if (any(active)) stats::median(x$mean_net_excess_vs_unconditional[active]) else NA_real_,
      positive_net_asset_fraction = if (any(active)) mean(x$mean_net_open_log_return[active] > 0) else NA_real_,
      positive_excess_asset_fraction = if (any(active)) mean(x$mean_net_excess_vs_unconditional[active] > 0) else NA_real_,
      median_state_only_mean_net_log_return = if (any(active)) stats::median(
        x$state_only_mean_net_open_log_return[active], na.rm = TRUE
      ) else NA_real_,
      median_asset_mean_net_difference_vs_state_only = if (any(active)) stats::median(
        x$mean_net_difference_vs_state_only[active], na.rm = TRUE
      ) else NA_real_,
      positive_difference_vs_state_only_asset_fraction = if (any(active)) mean(
        x$mean_net_difference_vs_state_only[active] > 0, na.rm = TRUE
      ) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  key_rows <- do.call(rbind, lapply(groups, function(x) x[1L, grouping_fields, drop = FALSE]))
  rownames(out) <- rownames(key_rows) <- NULL
  cbind(key_rows, out)
}

rgnor_equal_sector_summary <- function(sector_summary) {
  required <- c(
    "sector", "assets", "active_assets", "total_trades",
    "median_trades_per_active_asset", "median_asset_mean_net_log_return",
    "median_asset_mean_net_excess", "positive_net_asset_fraction",
    "positive_excess_asset_fraction", "median_state_only_mean_net_log_return",
    "median_asset_mean_net_difference_vs_state_only",
    "positive_difference_vs_state_only_asset_fraction"
  )
  missing <- setdiff(required, names(sector_summary))
  if (length(missing)) rgnor_stop(paste("Sector summary is missing:", paste(missing, collapse = ", ")))
  numeric_fields <- setdiff(required, "sector")
  values <- lapply(numeric_fields, function(field) {
    stats::median(sector_summary[[field]], na.rm = TRUE)
  })
  names(values) <- numeric_fields
  as.data.frame(values, stringsAsFactors = FALSE)
}

rgnor_classify_train <- function(equal_sector, sector_summary, asset_summary,
                                 contract = rgnor_contract()) {
  core <- asset_summary[asset_summary$sector_balance_eligible, , drop = FALSE]
  active_core <- sum(core$trades > 0L)
  positive_excess_sectors <- sum(
    is.finite(sector_summary$median_asset_mean_net_excess) &
      sector_summary$median_asset_mean_net_excess > 0
  )
  headline_excess <- equal_sector$median_asset_mean_net_excess[[1L]]
  median_core_excess <- stats::median(
    core$mean_net_excess_vs_unconditional[core$trades > 0L], na.rm = TRUE
  )
  passes <- c(
    active_core >= contract$minimum_active_core_assets,
    positive_excess_sectors >= contract$minimum_positive_excess_sectors,
    is.finite(headline_excess) && headline_excess > 0,
    is.finite(median_core_excess) && median_core_excess > 0
  )
  status <- if (all(passes)) {
    "TRAIN_RULE_TRANSLATION_RETAINS_MECHANICAL_SUPPORT_STOP_BEFORE_OOS"
  } else {
    "TRAIN_RULE_TRANSLATION_DOES_NOT_RETAIN_MECHANICAL_SUPPORT_STOP_OOS"
  }
  list(
    status = status,
    checks = data.frame(
      gate = c(
        "active_core_assets", "positive_excess_sectors",
        "equal_sector_net_excess", "median_core_asset_net_excess"
      ),
      value = c(active_core, positive_excess_sectors, headline_excess, median_core_excess),
      threshold = c(
        contract$minimum_active_core_assets,
        contract$minimum_positive_excess_sectors, 0, 0
      ),
      pass = passes,
      stringsAsFactors = FALSE
    )
  )
}
