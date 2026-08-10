# Shared causal engine for the approved HYP-MOM SMA follow-up series.

hmsf_stop <- function(message) stop(message, call. = FALSE)

hmsf_contract <- function() {
  list(
    program_id = "HYP-MOM-SMA-FOLLOWUP-SERIES",
    as_of_timestamp = "2026-08-07 17:30:00 America/New_York",
    attribution_start = as.Date("2021-01-04"),
    attribution_end = as.Date("2023-12-29"),
    development_start = as.Date("2016-01-04"),
    development_end = as.Date("2020-12-31"),
    confirmation_start = as.Date("2024-01-02"),
    confirmation_end = as.Date("2025-12-31"),
    sealed_start = as.Date("2026-01-02"),
    sma_fast = 50L,
    sma_slow = 200L,
    slow_slope_sessions = 20L,
    relative_strength_sessions = 126L,
    atr_sessions = 20L,
    prehistory_sessions = 220L,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    initial_wealth = 1,
    random_simulations = 500L,
    random_seed = 20260810L,
    event_horizons = c(5L, 20L, 60L),
    variants = c("FRESH_021", "ENTRY_CONFIRMATION", "EXIT_LOCKOUT",
                 "COMPOSITE_022", "REENTRY_REPAIR_023", "PULLBACK_RECLAIM_031")
  )
}

hmsf_validate_contract <- function(contract = hmsf_contract()) {
  frozen <- hmsf_contract()
  if (!identical(names(contract), names(frozen))) hmsf_stop("Frozen follow-up contract fields changed.")
  same <- vapply(names(frozen), function(name) identical(contract[[name]], frozen[[name]]), logical(1))
  if (!all(same)) hmsf_stop(paste("Frozen follow-up contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  contract
}

hmsf_window <- function(stage, contract = hmsf_contract()) {
  contract <- hmsf_validate_contract(contract)
  switch(stage,
    ATTRIBUTION = c(contract$attribution_start, contract$attribution_end),
    DEVELOPMENT = c(contract$development_start, contract$development_end),
    CONFIRMATION = c(contract$confirmation_start, contract$confirmation_end),
    hmsf_stop(paste("Unknown evidence stage:", stage))
  )
}

hmsf_validate_bars <- function(bars, end_date, contract = hmsf_contract()) {
  hmsf_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) hmsf_stop(paste("Bars missing columns:", paste(missing, collapse = ", ")))
  x <- as.data.frame(bars, stringsAsFactors = FALSE)
  x$session_date <- as.Date(x$session_date)
  numeric_columns <- c("open", "high", "low", "close", "volume")
  x[numeric_columns] <- lapply(x[numeric_columns], as.numeric)
  if (anyNA(x$session_date) || any(!is.finite(as.matrix(x[numeric_columns])))) hmsf_stop("Bars contain missing or non-finite values.")
  if (any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) hmsf_stop("Bars contain invalid OHLCV values.")
  if (anyDuplicated(x[c("symbol", "session_date")])) hmsf_stop("Bars contain duplicate symbol/session rows.")
  if (any(x$session_date > as.Date(end_date))) hmsf_stop("Bars later than the authorized evidence window entered analysis.")
  if (any(x$session_date >= contract$sealed_start)) hmsf_stop("Sealed 2026+ observations entered analysis.")
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  rownames(x) <- NULL
  x
}

hmsf_sma <- function(x, n) {
  out <- rep(NA_real_, length(x))
  if (length(x) >= n) out[n:length(x)] <- stats::filter(as.numeric(x), rep(1 / n, n), sides = 1)[n:length(x)]
  out
}

hmsf_atr <- function(high, low, close, n = 20L) {
  prior_close <- c(NA_real_, head(close, -1L))
  tr <- pmax(high - low, abs(high - prior_close), abs(low - prior_close), na.rm = TRUE)
  tr[[1L]] <- high[[1L]] - low[[1L]]
  hmsf_sma(tr, n)
}

hmsf_drawdown <- function(wealth) wealth / cummax(wealth) - 1

hmsf_sharpe <- function(returns) {
  returns <- as.numeric(returns)
  if (length(returns) < 2L || !is.finite(stats::sd(returns)) || stats::sd(returns) == 0) return(NA_real_)
  sqrt(252) * mean(returns) / stats::sd(returns)
}

hmsf_state <- function(bars, end_date, contract = hmsf_contract()) {
  contract <- hmsf_validate_contract(contract)
  x <- hmsf_validate_bars(bars, end_date, contract)
  if (length(unique(x$symbol)) != 1L) hmsf_stop("State construction requires one symbol.")
  x$sma50 <- hmsf_sma(x$close, contract$sma_fast)
  x$sma200 <- hmsf_sma(x$close, contract$sma_slow)
  x$atr20 <- hmsf_atr(x$high, x$low, x$close, contract$atr_sessions)
  x$above50 <- !is.na(x$sma50) & x$close > x$sma50
  x$above200 <- !is.na(x$sma200) & x$close > x$sma200
  x$cross50_up <- x$above50 & c(FALSE, !head(x$above50, -1L))
  x$cross200_up <- x$above200 & c(FALSE, !head(x$above200, -1L))
  x$cross200_down <- !x$above200 & c(FALSE, head(x$above200, -1L))
  x$sma200_rising20 <- !is.na(x$sma200) & c(rep(FALSE, contract$slow_slope_sessions),
    tail(x$sma200, -contract$slow_slope_sessions) > head(x$sma200, -contract$slow_slope_sessions))
  x$permission031 <- x$above200 & x$sma200_rising20
  x$distance200_atr <- (x$close - x$sma200) / x$atr20
  x$slope200_20_atr <- (x$sma200 - c(rep(NA_real_, contract$slow_slope_sessions),
    head(x$sma200, -contract$slow_slope_sessions))) / x$atr20
  x$return126 <- x$close / c(rep(NA_real_, contract$relative_strength_sessions),
    head(x$close, -contract$relative_strength_sessions)) - 1
  x
}

hmsf_empty_trades <- function() {
  data.frame(
    symbol = character(), variant = character(), trade_id = character(),
    entry_date = as.Date(character()), exit_date = as.Date(character()),
    entry_reason = character(), exit_reason = character(), entry_open = numeric(),
    exit_open = numeric(), holding_sessions = integer(), gross_trade_return = numeric(),
    maximum_favorable_excursion = numeric(), maximum_adverse_excursion = numeric(),
    net_trade_return = numeric(), stringsAsFactors = FALSE
  )
}

hmsf_replay <- function(bars, variant, window_start, window_end, one_way_bps,
                        entry_filter = NULL, contract = hmsf_contract()) {
  contract <- hmsf_validate_contract(contract)
  if (!variant %in% contract$variants) hmsf_stop(paste("Unknown variant:", variant))
  x <- hmsf_state(bars, window_end, contract)
  idx <- which(x$session_date >= as.Date(window_start) & x$session_date <= as.Date(window_end))
  if (length(idx) < 2L) hmsf_stop("Evidence window has fewer than two sessions.")
  if (idx[[1L]] <= contract$prehistory_sessions || is.na(x$sma200[idx[[1L]] - 1L])) hmsf_stop("Insufficient prehistory.")
  if (is.null(entry_filter)) entry_filter <- rep(TRUE, nrow(x))
  if (length(entry_filter) != nrow(x) || anyNA(entry_filter)) hmsf_stop("Entry filter must be complete and bar-aligned.")
  w <- x[idx, , drop = FALSE]
  prior_idx <- idx - 1L
  signal_date <- x$session_date[prior_idx]
  signal_in_window <- signal_date >= as.Date(window_start)
  target <- rep(FALSE, nrow(w))
  signal_type <- rep("HOLD_STATE", nrow(w))
  desired <- FALSE
  initial_entry_completed <- FALSE

  for (i in seq_len(nrow(w))) {
    p <- prior_idx[[i]]
    if (!signal_in_window[[i]]) {
      signal_type[[i]] <- "PRE_WINDOW_STATE_IGNORED"
      target[[i]] <- FALSE
      next
    }
    exit_now <- desired && switch(variant,
      FRESH_021 = !x$above200[[p]],
      ENTRY_CONFIRMATION = !x$above200[[p]],
      EXIT_LOCKOUT = !x$above50[[p]],
      COMPOSITE_022 = !x$above50[[p]],
      REENTRY_REPAIR_023 = !x$above50[[p]],
      PULLBACK_RECLAIM_031 = !x$above50[[p]] || !x$permission031[[p]]
    )
    if (exit_now) {
      desired <- FALSE
      signal_type[[i]] <- if (variant %in% c("FRESH_021", "ENTRY_CONFIRMATION")) "EXIT_SMA200" else "EXIT_SMA50_OR_PERMISSION"
    }
    if (!desired) {
      entry_now <- switch(variant,
        FRESH_021 = x$cross200_up[[p]],
        ENTRY_CONFIRMATION = x$cross200_up[[p]] && x$above50[[p]],
        EXIT_LOCKOUT = x$cross200_up[[p]],
        COMPOSITE_022 = x$cross200_up[[p]] && x$above50[[p]],
        REENTRY_REPAIR_023 = if (!initial_entry_completed) {
          x$cross200_up[[p]] && x$above50[[p]]
        } else {
          x$cross50_up[[p]] && x$above200[[p]]
        },
        PULLBACK_RECLAIM_031 = x$cross50_up[[p]] && x$permission031[[p]]
      ) && entry_filter[[p]]
      if (entry_now) {
        desired <- TRUE
        initial_entry_completed <- TRUE
        signal_type[[i]] <- switch(variant,
          FRESH_021 = "ENTRY_SMA200",
          ENTRY_CONFIRMATION = "ENTRY_SMA200_CONFIRMED_SMA50",
          EXIT_LOCKOUT = "ENTRY_SMA200",
          COMPOSITE_022 = "ENTRY_SMA200_CONFIRMED_SMA50",
          REENTRY_REPAIR_023 = if (x$cross200_up[[p]]) "ENTRY_INITIAL_SMA200" else "REENTRY_SMA50_RECLAIM",
          PULLBACK_RECLAIM_031 = "ENTRY_SMA50_RECLAIM_IN_RISING_SMA200_REGIME"
        )
      } else if (variant %in% c("ENTRY_CONFIRMATION", "COMPOSITE_022", "REENTRY_REPAIR_023") &&
                 x$cross200_up[[p]] && !x$above50[[p]]) {
        signal_type[[i]] <- "SKIPPED_SMA200_CROSS_BELOW_SMA50"
      }
    }
    target[[i]] <- desired
  }

  cost <- as.numeric(one_way_bps) / 10000
  cash <- contract$initial_wealth
  shares <- 0
  wealth_open <- numeric(nrow(w))
  position <- logical(nrow(w))
  trade_id <- rep(NA_character_, nrow(w))
  current_trade <- NA_character_
  next_trade <- 0L
  entry_row <- NA_integer_
  entry_open <- NA_real_
  entry_reason <- NA_character_
  trade_rows <- list()

  close_trade <- function(i, reason) {
    hold_rows <- entry_row:max(entry_row, i - 1L)
    data.frame(
      symbol = w$symbol[[i]], variant = variant, trade_id = current_trade,
      entry_date = w$session_date[[entry_row]], exit_date = w$session_date[[i]],
      entry_reason = entry_reason, exit_reason = reason, entry_open = entry_open,
      exit_open = w$open[[i]], holding_sessions = i - entry_row,
      gross_trade_return = w$open[[i]] / entry_open - 1,
      maximum_favorable_excursion = max(w$high[hold_rows]) / entry_open - 1,
      maximum_adverse_excursion = min(w$low[hold_rows]) / entry_open - 1,
      stringsAsFactors = FALSE
    )
  }

  for (i in seq_len(nrow(w))) {
    if (shares > 0 && !target[[i]]) {
      cash <- shares * w$open[[i]] * (1 - cost)
      shares <- 0
      trade_rows[[length(trade_rows) + 1L]] <- close_trade(i, signal_type[[i]])
      current_trade <- NA_character_
    }
    if (shares == 0 && target[[i]] && i < nrow(w)) {
      next_trade <- next_trade + 1L
      current_trade <- sprintf("%s_%s_T%03d", w$symbol[[i]], variant, next_trade)
      shares <- cash * (1 - cost) / w$open[[i]]
      cash <- 0
      entry_row <- i
      entry_open <- w$open[[i]]
      entry_reason <- signal_type[[i]]
    }
    wealth_open[[i]] <- cash + shares * w$open[[i]]
    position[[i]] <- shares > 0
    trade_id[[i]] <- current_trade
  }
  if (shares > 0) {
    i <- nrow(w)
    cash <- shares * w$open[[i]] * (1 - cost)
    wealth_open[[i]] <- cash
    trade_rows[[length(trade_rows) + 1L]] <- close_trade(i, "BOUNDARY_EXIT")
    position[[i]] <- FALSE
    trade_id[[i]] <- NA_character_
  }
  trades <- if (length(trade_rows)) do.call(rbind, trade_rows) else hmsf_empty_trades()
  if (nrow(trades)) trades$net_trade_return <- (1 - cost) * (1 + trades$gross_trade_return) * (1 - cost) - 1
  path <- data.frame(
    symbol = w$symbol, variant = variant, session_date = w$session_date,
    open = w$open, high = w$high, low = w$low, close = w$close,
    sma50 = w$sma50, sma200 = w$sma200, atr20 = w$atr20,
    signal_date = signal_date, signal_type = signal_type, target_long = target,
    in_position_after_open = position, trade_id = trade_id,
    strategy_wealth_open = wealth_open, strategy_drawdown = hmsf_drawdown(wealth_open),
    distance200_atr = w$distance200_atr, slope200_20_atr = w$slope200_20_atr,
    return126 = w$return126, stringsAsFactors = FALSE
  )
  list(path = path, trades = trades)
}

hmsf_random_controls <- function(bars, state, window_start, window_end, one_way_bps,
                                 seed_offset = 0L, contract = hmsf_contract()) {
  x <- hmsf_validate_bars(bars, window_end, contract)
  w <- x[x$session_date >= as.Date(window_start) & x$session_date <= as.Date(window_end), , drop = FALSE]
  interval_returns <- w$open[-1L] / head(w$open, -1L) - 1
  state <- as.logical(state)[seq_along(interval_returns)]
  n <- length(state)
  if (n < 2L) return(numeric())
  set.seed(contract$random_seed + as.integer(seed_offset))
  shifts <- sample(seq_len(n - 1L), contract$random_simulations, replace = contract$random_simulations > n - 1L)
  cost <- one_way_bps / 10000
  vapply(shifts, function(k) {
    shifted <- c(tail(state, k), head(state, n - k))
    transitions <- sum(shifted != c(FALSE, head(shifted, -1L))) + as.integer(tail(shifted, 1L))
    prod(1 + ifelse(shifted, interval_returns, 0)) * (1 - cost)^transitions - 1
  }, numeric(1))
}

hmsf_analyze_asset <- function(bars, variant, window_start, window_end,
                               entry_filter = NULL, seed_offset = 0L,
                               contract = hmsf_contract()) {
  x <- hmsf_validate_bars(bars, window_end, contract)
  symbol <- unique(x$symbol)
  if (length(symbol) != 1L) hmsf_stop("Asset analysis requires one symbol.")
  primary <- hmsf_replay(x, variant, window_start, window_end, contract$primary_cost_bps, entry_filter, contract)
  stress <- hmsf_replay(x, variant, window_start, window_end, contract$stress_cost_bps, entry_filter, contract)
  trades <- primary$trades
  if (nrow(trades)) {
    trades$primary_trade_return <- trades$net_trade_return
    trades$stress_trade_return <- stress$trades$net_trade_return
  }
  path <- primary$path
  path$stress_wealth_open <- stress$path$strategy_wealth_open
  w <- x[x$session_date >= as.Date(window_start) & x$session_date <= as.Date(window_end), , drop = FALSE]
  cost <- contract$primary_cost_bps / 10000
  bh_wealth <- (1 - cost) * w$open / w$open[[1L]]
  bh_wealth[[length(bh_wealth)]] <- bh_wealth[[length(bh_wealth)]] * (1 - cost)
  path$buy_hold_wealth_open <- bh_wealth
  path$buy_hold_drawdown <- hmsf_drawdown(bh_wealth)
  daily_returns <- path$strategy_wealth_open[-1L] / head(path$strategy_wealth_open, -1L) - 1
  exposure_state <- head(path$in_position_after_open, -1L)
  random <- hmsf_random_controls(x, exposure_state, window_start, window_end,
                                 contract$primary_cost_bps, seed_offset, contract)
  observed <- tail(path$strategy_wealth_open, 1L) - 1
  trade_stat <- function(fun, column) if (nrow(trades)) fun(trades[[column]]) else NA_real_
  summary <- data.frame(
    symbol = symbol, variant = variant, trade_count = nrow(trades),
    entry_count = if (nrow(trades)) nrow(trades) else 0L,
    boundary_exit_count = if (nrow(trades)) sum(trades$exit_reason == "BOUNDARY_EXIT") else 0L,
    exposure_fraction = mean(exposure_state), primary_return = observed,
    stress_return = tail(path$stress_wealth_open, 1L) - 1,
    buy_hold_primary_return = tail(bh_wealth, 1L) - 1,
    excess_vs_buy_hold = observed - (tail(bh_wealth, 1L) - 1),
    primary_sharpe = hmsf_sharpe(daily_returns), maximum_drawdown = min(path$strategy_drawdown),
    buy_hold_maximum_drawdown = min(path$buy_hold_drawdown),
    drawdown_improvement = min(path$strategy_drawdown) - min(path$buy_hold_drawdown),
    mean_primary_trade_return = trade_stat(mean, "primary_trade_return"),
    median_primary_trade_return = trade_stat(stats::median, "primary_trade_return"),
    primary_hit_rate = trade_stat(function(z) mean(z > 0), "primary_trade_return"),
    payoff_ratio = if (nrow(trades) && any(trades$primary_trade_return > 0) && any(trades$primary_trade_return < 0)) {
      mean(trades$primary_trade_return[trades$primary_trade_return > 0]) /
        abs(mean(trades$primary_trade_return[trades$primary_trade_return < 0]))
    } else NA_real_,
    median_holding_sessions = trade_stat(stats::median, "holding_sessions"),
    mean_maximum_favorable_excursion = trade_stat(mean, "maximum_favorable_excursion"),
    mean_maximum_adverse_excursion = trade_stat(mean, "maximum_adverse_excursion"),
    random_median_return = if (length(random)) stats::median(random) else NA_real_,
    excess_vs_random_median = if (length(random)) observed - stats::median(random) else NA_real_,
    observed_random_percentile = if (length(random) && any(exposure_state)) mean(random <= observed) else NA_real_,
    stringsAsFactors = FALSE
  )
  list(path = path, trades = trades, summary = summary,
       random = data.frame(symbol = symbol, variant = variant,
                           simulation_id = seq_along(random), primary_return = random))
}

hmsf_event_study <- function(asset_bars, spy_bars, sector_bars, window_start,
                             window_end, sector_symbol, contract = hmsf_contract()) {
  asset <- hmsf_state(asset_bars, window_end, contract)
  spy <- hmsf_validate_bars(spy_bars, window_end, contract)
  sector <- hmsf_validate_bars(sector_bars, window_end, contract)
  if (length(unique(spy$symbol)) != 1L || length(unique(sector$symbol)) != 1L) hmsf_stop("Context series must each contain one symbol.")
  signals <- which(asset$cross200_up & asset$session_date >= as.Date(window_start) & asset$session_date <= as.Date(window_end))
  rows <- list()
  for (signal_index in signals) {
    entry_index <- signal_index + 1L
    if (entry_index > nrow(asset)) next
    for (horizon in contract$event_horizons) {
      exit_index <- entry_index + horizon
      if (exit_index > nrow(asset) || asset$session_date[[exit_index]] > as.Date(window_end)) next
      entry_date <- asset$session_date[[entry_index]]
      exit_date <- asset$session_date[[exit_index]]
      spy_entry <- match(entry_date, spy$session_date); spy_exit <- match(exit_date, spy$session_date)
      sector_entry <- match(entry_date, sector$session_date); sector_exit <- match(exit_date, sector$session_date)
      if (anyNA(c(spy_entry, spy_exit, sector_entry, sector_exit))) next
      hold_rows <- entry_index:(exit_index - 1L)
      asset_return <- asset$open[[exit_index]] / asset$open[[entry_index]] - 1
      spy_return <- spy$open[[spy_exit]] / spy$open[[spy_entry]] - 1
      sector_return <- sector$open[[sector_exit]] / sector$open[[sector_entry]] - 1
      sector_state_index <- match(asset$session_date[[signal_index]], sector$session_date)
      sector_return126 <- if (!is.na(sector_state_index) && sector_state_index > contract$relative_strength_sessions) {
        sector$close[[sector_state_index]] / sector$close[[sector_state_index - contract$relative_strength_sessions]] - 1
      } else NA_real_
      rows[[length(rows) + 1L]] <- data.frame(
        symbol = asset$symbol[[signal_index]], sector_symbol = sector_symbol,
        signal_date = asset$session_date[[signal_index]], entry_date = entry_date,
        exit_date = exit_date, horizon = horizon, asset_return = asset_return,
        spy_return = spy_return, sector_return = sector_return,
        spy_relative_return = asset_return - spy_return,
        sector_relative_return = asset_return - sector_return,
        direction_positive = asset_return > 0,
        maximum_favorable_excursion = max(asset$high[hold_rows]) / asset$open[[entry_index]] - 1,
        maximum_adverse_excursion = min(asset$low[hold_rows]) / asset$open[[entry_index]] - 1,
        above50_at_signal = asset$above50[[signal_index]],
        sma200_rising20_at_signal = asset$sma200_rising20[[signal_index]],
        distance200_atr = asset$distance200_atr[[signal_index]],
        slope200_20_atr = asset$slope200_20_atr[[signal_index]],
        asset_return126 = asset$return126[[signal_index]],
        sector_return126 = sector_return126,
        relative_strength126 = asset$return126[[signal_index]] - sector_return126,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- if (length(rows)) do.call(rbind, rows) else data.frame()
  if (nrow(out)) {
    out$nonoverlap <- FALSE
    for (horizon in unique(out$horizon)) {
      which_h <- which(out$horizon == horizon)
      ordered <- which_h[order(out$entry_date[which_h])]
      last_exit <- as.Date("1900-01-01")
      for (j in ordered) {
        if (out$entry_date[[j]] >= last_exit) {
          out$nonoverlap[[j]] <- TRUE
          last_exit <- out$exit_date[[j]]
        }
      }
    }
  }
  out
}
