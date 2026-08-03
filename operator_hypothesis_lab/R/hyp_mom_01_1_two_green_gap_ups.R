# HYP-MOM-01.1: two consecutive green gap-ups, causal next-open discovery POC.

hyp_mom011_stop <- function(message) stop(message, call. = FALSE)

hyp_mom011_contract <- function() {
  list(
    hypothesis_id = "HYP-MOM-01.1",
    descriptive_name = "Two Consecutive Green Gap-Ups",
    evidence_stage = "DISCOVERY_REUSED_WINDOW",
    as_of_timestamp = "2026-07-30 17:30:00 America/New_York",
    discovery_start = as.Date("2021-01-04"),
    discovery_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    holding_sessions = 5L,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    initial_wealth = 1,
    random_simulations = 1000L,
    random_seed = 20260803L,
    allow_same_open_reentry = TRUE,
    position_scope = "LONG_ONLY_SINGLE_ASSET_FULL_CAPITAL"
  )
}
hyp_mom011_validate_contract <- function(contract = hyp_mom011_contract()) {
  frozen <- hyp_mom011_contract()
  if (!identical(names(contract), names(frozen))) {
    hyp_mom011_stop("Frozen HYP-MOM-01.1 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    hyp_mom011_stop(paste(
      "Frozen HYP-MOM-01.1 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

hyp_mom011_validate_registry <- function(registry) {
  required <- c("instance_id", "symbol", "sector", "role", "source_registry")
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    hyp_mom011_stop(paste("Registry missing columns:", paste(missing, collapse = ", ")))
  }
  if (nrow(registry) != 22L) hyp_mom011_stop("Discovery registry must contain 22 stocks.")
  if (any(!nzchar(registry$instance_id)) || anyDuplicated(registry$instance_id)) {
    hyp_mom011_stop("Discovery instance IDs must be non-empty and unique.")
  }
  if (any(!nzchar(registry$symbol)) || anyDuplicated(registry$symbol)) {
    hyp_mom011_stop("Discovery symbols must be non-empty and unique.")
  }
  if (length(unique(registry$sector)) != 11L) {
    hyp_mom011_stop("Discovery registry must cover eleven sectors.")
  }
  invisible(registry)
}

hyp_mom011_validate_bars <- function(bars, contract = hyp_mom011_contract()) {
  contract <- hyp_mom011_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    hyp_mom011_stop(paste("Bars missing columns:", paste(missing, collapse = ", ")))
  }
  x <- as.data.frame(bars, stringsAsFactors = FALSE)
  x$session_date <- as.Date(x$session_date)
  x[c("open", "high", "low", "close")] <- lapply(
    x[c("open", "high", "low", "close")], as.numeric
  )
  if (anyNA(x$session_date) || any(!is.finite(as.matrix(x[c("open", "high", "low", "close")])))) {
    hyp_mom011_stop("Bars contain missing or non-finite required values.")
  }
  if (any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0)) {
    hyp_mom011_stop("Bars contain non-positive prices.")
  }
  if (anyDuplicated(x[c("symbol", "session_date")])) {
    hyp_mom011_stop("Bars contain duplicate symbol/session rows.")
  }
  if (any(x$session_date >= contract$confirmation_start)) {
    hyp_mom011_stop("Confirmation observations entered HYP-MOM-01.1 discovery.")
  }
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  rownames(x) <- NULL
  x
}

hyp_mom011_drawdown <- function(wealth) {
  wealth <- as.numeric(wealth)
  wealth / cummax(wealth) - 1
}

hyp_mom011_signal_candidates <- function(
  bars,
  contract = hyp_mom011_contract()
) {
  contract <- hyp_mom011_validate_contract(contract)
  x <- hyp_mom011_validate_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) {
    hyp_mom011_stop("Signal candidates require exactly one symbol.")
  }
  x <- x[order(x$session_date), , drop = FALSE]
  n <- nrow(x)
  if (n < contract$holding_sessions + 4L) return(data.frame())

  gap_up <- c(FALSE, x$open[-1L] > x$close[-n])
  green <- x$close > x$open
  two_green_gap_ups <- gap_up & green & c(FALSE, head(gap_up & green, -1L))
  signal_index <- which(two_green_gap_ups)
  entry_index <- signal_index + 1L
  exit_index <- entry_index + contract$holding_sessions
  keep <- entry_index <= n & exit_index <= n
  signal_index <- signal_index[keep]
  entry_index <- entry_index[keep]
  exit_index <- exit_index[keep]
  if (!length(signal_index)) return(data.frame())

  keep <- x$session_date[signal_index] >= contract$discovery_start &
    x$session_date[exit_index] <= contract$discovery_end
  signal_index <- signal_index[keep]
  entry_index <- entry_index[keep]
  exit_index <- exit_index[keep]
  if (!length(signal_index)) return(data.frame())

  rows <- lapply(seq_along(signal_index), function(j) {
    s <- signal_index[[j]]
    e <- entry_index[[j]]
    z <- exit_index[[j]]
    holding_rows <- e:(z - 1L)
    data.frame(
      symbol = x$symbol[[s]],
      signal_id = sprintf("%s_%s", x$symbol[[s]], format(x$session_date[[s]], "%Y%m%d")),
      first_pattern_date = x$session_date[[s - 1L]],
      signal_date = x$session_date[[s]],
      entry_date = x$session_date[[e]],
      exit_date = x$session_date[[z]],
      signal_index = s,
      entry_index = e,
      exit_index = z,
      first_gap_return = x$open[[s - 1L]] / x$close[[s - 2L]] - 1,
      second_gap_return = x$open[[s]] / x$close[[s - 1L]] - 1,
      first_body_return = x$close[[s - 1L]] / x$open[[s - 1L]] - 1,
      second_body_return = x$close[[s]] / x$open[[s]] - 1,
      entry_open = x$open[[e]],
      exit_open = x$open[[z]],
      gross_trade_return = x$open[[z]] / x$open[[e]] - 1,
      maximum_favorable_excursion = max(x$high[holding_rows]) / x$open[[e]] - 1,
      maximum_adverse_excursion = min(x$low[holding_rows]) / x$open[[e]] - 1,
      first_session_return = x$close[[e]] / x$open[[e]] - 1,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

hyp_mom011_select_nonoverlap <- function(candidates, allow_same_open_reentry = TRUE) {
  if (!nrow(candidates)) return(candidates)
  x <- candidates[order(candidates$entry_index, candidates$signal_date), , drop = FALSE]
  chosen <- logical(nrow(x))
  next_entry_index <- -Inf
  for (i in seq_len(nrow(x))) {
    eligible <- if (allow_same_open_reentry) {
      x$entry_index[[i]] >= next_entry_index
    } else {
      x$entry_index[[i]] > next_entry_index
    }
    if (eligible) {
      chosen[[i]] <- TRUE
      next_entry_index <- x$exit_index[[i]]
    }
  }
  x$executed <- chosen
  x$overlap_disposition <- ifelse(chosen, "EXECUTED", "IGNORED_WHILE_INVESTED")
  x$trade_id <- NA_character_
  x$trade_id[chosen] <- sprintf("%s_T%03d", x$symbol[chosen], seq_len(sum(chosen)))
  x
}

hyp_mom011_apply_cost <- function(gross_return, one_way_bps) {
  cost <- as.numeric(one_way_bps) / 10000
  (1 - cost) * (1 + as.numeric(gross_return)) * (1 - cost) - 1
}

hyp_mom011_replay <- function(
  bars,
  trades,
  one_way_bps,
  contract = hyp_mom011_contract()
) {
  contract <- hyp_mom011_validate_contract(contract)
  x <- hyp_mom011_validate_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) hyp_mom011_stop("Replay requires one symbol.")
  x <- x[
    x$session_date >= contract$discovery_start &
      x$session_date <= contract$discovery_end,
    , drop = FALSE
  ]
  if (!nrow(x)) hyp_mom011_stop("Replay window contains no bars.")
  executed <- trades[trades$executed, , drop = FALSE]
  cost <- as.numeric(one_way_bps) / 10000
  cash <- contract$initial_wealth
  shares <- 0
  current_trade <- NA_character_
  wealth_open <- wealth_close <- numeric(nrow(x))
  in_position <- logical(nrow(x))
  trade_label <- rep(NA_character_, nrow(x))

  exits <- split(executed, as.character(executed$exit_date))
  entries <- split(executed, as.character(executed$entry_date))
  for (i in seq_len(nrow(x))) {
    day <- as.character(x$session_date[[i]])
    if (day %in% names(exits)) {
      cash <- shares * x$open[[i]] * (1 - cost)
      shares <- 0
      current_trade <- NA_character_
    }
    if (day %in% names(entries)) {
      entry <- entries[[day]][1L, , drop = FALSE]
      shares <- cash * (1 - cost) / x$open[[i]]
      cash <- 0
      current_trade <- entry$trade_id[[1L]]
    }
    wealth_open[[i]] <- cash + shares * x$open[[i]]
    wealth_close[[i]] <- cash + shares * x$close[[i]]
    in_position[[i]] <- shares > 0
    trade_label[[i]] <- current_trade
  }
  data.frame(
    symbol = x$symbol,
    session_date = x$session_date,
    open = x$open,
    close = x$close,
    strategy_wealth_open = wealth_open,
    strategy_wealth_close = wealth_close,
    strategy_drawdown = hyp_mom011_drawdown(wealth_close),
    in_position = in_position,
    trade_id = trade_label,
    stringsAsFactors = FALSE
  )
}

hyp_mom011_random_schedule <- function(entry_indices, trade_count, holding_sessions) {
  entry_indices <- sort(unique(as.integer(entry_indices)))
  if (trade_count == 0L) return(integer())
  for (attempt in seq_len(200L)) {
    chosen <- integer()
    for (candidate in sample(entry_indices)) {
      nonoverlap <- !length(chosen) || all(
        candidate >= chosen + holding_sessions |
          chosen >= candidate + holding_sessions
      )
      if (nonoverlap) chosen <- c(chosen, candidate)
      if (length(chosen) == trade_count) return(sort(chosen))
    }
  }
  hyp_mom011_stop("Unable to draw a matched non-overlapping random schedule.")
}

hyp_mom011_random_controls <- function(
  bars,
  trade_count,
  one_way_bps,
  contract = hyp_mom011_contract(),
  seed_offset = 0L
) {
  contract <- hyp_mom011_validate_contract(contract)
  x <- hyp_mom011_validate_bars(bars, contract)
  x <- x[order(x$session_date), , drop = FALSE]
  entry_indices <- which(
    x$session_date >= contract$discovery_start &
      seq_len(nrow(x)) + contract$holding_sessions <= nrow(x)
  )
  entry_indices <- entry_indices[
    x$session_date[entry_indices + contract$holding_sessions] <= contract$discovery_end
  ]
  set.seed(contract$random_seed + as.integer(seed_offset))
  returns <- numeric(contract$random_simulations)
  for (i in seq_len(contract$random_simulations)) {
    entries <- hyp_mom011_random_schedule(
      entry_indices, as.integer(trade_count), contract$holding_sessions
    )
    gross <- x$open[entries + contract$holding_sessions] / x$open[entries] - 1
    net <- hyp_mom011_apply_cost(gross, one_way_bps)
    returns[[i]] <- prod(1 + net) - 1
  }
  returns
}

hyp_mom011_analyze_asset <- function(
  bars,
  contract = hyp_mom011_contract(),
  seed_offset = 0L
) {
  contract <- hyp_mom011_validate_contract(contract)
  x <- hyp_mom011_validate_bars(bars, contract)
  symbol <- unique(x$symbol)
  if (length(symbol) != 1L) hyp_mom011_stop("Asset analysis requires one symbol.")
  candidates <- hyp_mom011_signal_candidates(x, contract)
  if (!nrow(candidates)) hyp_mom011_stop(paste(symbol, "has no eligible signals."))
  candidates <- hyp_mom011_select_nonoverlap(
    candidates, contract$allow_same_open_reentry
  )
  trades <- candidates[candidates$executed, , drop = FALSE]
  trades$primary_trade_return <- hyp_mom011_apply_cost(
    trades$gross_trade_return, contract$primary_cost_bps
  )
  trades$stress_trade_return <- hyp_mom011_apply_cost(
    trades$gross_trade_return, contract$stress_cost_bps
  )
  primary_path <- hyp_mom011_replay(x, candidates, contract$primary_cost_bps, contract)
  stress_path <- hyp_mom011_replay(x, candidates, contract$stress_cost_bps, contract)
  primary_path$stress_wealth_close <- stress_path$strategy_wealth_close

  window <- x[
    x$session_date >= contract$discovery_start &
      x$session_date <= contract$discovery_end,
    , drop = FALSE
  ]
  primary_cost <- contract$primary_cost_bps / 10000
  buy_hold_return <- (1 - primary_cost) *
    (tail(window$open, 1L) / window$open[[1L]]) * (1 - primary_cost) - 1
  eligible_entries <- seq_len(nrow(window) - contract$holding_sessions)
  unconditional <- window$open[eligible_entries + contract$holding_sessions] /
    window$open[eligible_entries] - 1
  random_returns <- hyp_mom011_random_controls(
    x, nrow(trades), contract$primary_cost_bps, contract, seed_offset
  )
  observed_primary <- prod(1 + trades$primary_trade_return) - 1
  primary_dd <- primary_path$strategy_drawdown
  summary <- data.frame(
    symbol = symbol,
    signal_count = nrow(candidates),
    executed_trade_count = nrow(trades),
    ignored_overlap_signal_count = sum(!candidates$executed),
    participation_fraction = mean(primary_path$in_position),
    gross_compounded_return = prod(1 + trades$gross_trade_return) - 1,
    primary_compounded_return = observed_primary,
    stress_compounded_return = prod(1 + trades$stress_trade_return) - 1,
    buy_hold_primary_return = buy_hold_return,
    excess_vs_buy_hold = observed_primary - buy_hold_return,
    mean_primary_trade_return = mean(trades$primary_trade_return),
    median_primary_trade_return = stats::median(trades$primary_trade_return),
    primary_hit_rate = mean(trades$primary_trade_return > 0),
    maximum_drawdown = min(primary_dd),
    time_under_water_fraction = mean(primary_dd < 0),
    unconditional_h_mean_return = mean(unconditional),
    unconditional_h_hit_rate = mean(unconditional > 0),
    random_median_return = stats::median(random_returns),
    observed_random_percentile = mean(random_returns <= observed_primary),
    random_one_sided_p_value = (1 + sum(random_returns >= observed_primary)) /
      (length(random_returns) + 1),
    stringsAsFactors = FALSE
  )
  list(
    candidates = candidates,
    trades = trades,
    daily_path = primary_path,
    random_returns = data.frame(
      symbol = symbol,
      simulation_id = seq_along(random_returns),
      primary_compounded_return = random_returns,
      stringsAsFactors = FALSE
    ),
    summary = summary
  )
}
