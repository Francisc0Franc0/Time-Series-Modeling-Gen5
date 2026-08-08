# HYP-MOM-02.1: causal next-open SMA200 cross long/cash wide discovery.

hyp_mom021_stop <- function(message) stop(message, call. = FALSE)

hyp_mom021_contract <- function() {
  list(
    hypothesis_id = "HYP-MOM-02.1",
    descriptive_name = "SMA200 Cross Long/Cash",
    evidence_stage = "DISCOVERY_REUSED_WINDOW",
    as_of_timestamp = "2026-08-07 17:30:00 America/New_York",
    discovery_start = as.Date("2021-01-04"),
    discovery_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    sma_sessions = 200L,
    prehistory_sessions = 220L,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    initial_wealth = 1,
    random_simulations = 500L,
    random_seed = 20260808L,
    whipsaw_sessions = 20L,
    position_scope = "LONG_ONLY_SINGLE_ASSET_FULL_CAPITAL"
  )
}

hyp_mom021_validate_contract <- function(contract = hyp_mom021_contract()) {
  frozen <- hyp_mom021_contract()
  if (!identical(names(contract), names(frozen))) {
    hyp_mom021_stop("Frozen HYP-MOM-02.1 contract field set changed.")
  }
  same <- vapply(names(frozen), function(x) identical(contract[[x]], frozen[[x]]), logical(1))
  if (!all(same)) {
    hyp_mom021_stop(paste("Frozen HYP-MOM-02.1 contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  }
  contract
}

hyp_mom021_validate_bars <- function(bars, contract = hyp_mom021_contract()) {
  contract <- hyp_mom021_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) hyp_mom021_stop(paste("Bars missing columns:", paste(missing, collapse = ", ")))
  x <- as.data.frame(bars, stringsAsFactors = FALSE)
  x$session_date <- as.Date(x$session_date)
  x[c("open", "high", "low", "close", "volume")] <- lapply(x[c("open", "high", "low", "close", "volume")], as.numeric)
  if (anyNA(x$session_date) || any(!is.finite(as.matrix(x[c("open", "high", "low", "close", "volume")])))) {
    hyp_mom021_stop("Bars contain missing or non-finite values.")
  }
  if (any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) {
    hyp_mom021_stop("Bars contain invalid OHLCV values.")
  }
  if (anyDuplicated(x[c("symbol", "session_date")])) hyp_mom021_stop("Bars contain duplicate symbol/session rows.")
  if (any(x$session_date >= contract$confirmation_start)) hyp_mom021_stop("Confirmation observations entered discovery.")
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  rownames(x) <- NULL
  x
}

hyp_mom021_sma <- function(x, n = 200L) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (length(x) >= n) out[n:length(x)] <- stats::filter(x, rep(1 / n, n), sides = 1)[n:length(x)]
  out
}

hyp_mom021_drawdown <- function(wealth) wealth / cummax(wealth) - 1

hyp_mom021_sharpe <- function(returns) {
  returns <- as.numeric(returns)
  if (length(returns) < 2L || !is.finite(stats::sd(returns)) || stats::sd(returns) == 0) return(NA_real_)
  sqrt(252) * mean(returns) / stats::sd(returns)
}

hyp_mom021_state <- function(bars, contract = hyp_mom021_contract()) {
  contract <- hyp_mom021_validate_contract(contract)
  x <- hyp_mom021_validate_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) hyp_mom021_stop("State construction requires one symbol.")
  x$sma200 <- hyp_mom021_sma(x$close, contract$sma_sessions)
  x$above_sma200 <- !is.na(x$sma200) & x$close > x$sma200
  x$cross_above <- x$above_sma200 & c(FALSE, !head(x$above_sma200, -1L))
  x$cross_below <- !x$above_sma200 & c(FALSE, head(x$above_sma200, -1L))
  x
}

hyp_mom021_replay <- function(bars, one_way_bps, contract = hyp_mom021_contract()) {
  contract <- hyp_mom021_validate_contract(contract)
  x <- hyp_mom021_state(bars, contract)
  idx <- which(x$session_date >= contract$discovery_start & x$session_date <= contract$discovery_end)
  if (length(idx) < 2L) hyp_mom021_stop("Discovery window has fewer than two sessions.")
  if (idx[[1L]] <= 1L || is.na(x$sma200[idx[[1L]] - 1L])) hyp_mom021_stop("Insufficient prehistory for warm-start state.")
  w <- x[idx, , drop = FALSE]
  prior_idx <- idx - 1L
  target <- x$above_sma200[prior_idx]
  signal_type <- ifelse(x$cross_above[prior_idx], "CROSS_ABOVE", ifelse(x$cross_below[prior_idx], "CROSS_BELOW", "HOLD_STATE"))
  if (target[[1L]] && signal_type[[1L]] != "CROSS_ABOVE") signal_type[[1L]] <- "WARM_START_ENTRY"
  cost <- as.numeric(one_way_bps) / 10000
  wealth <- contract$initial_wealth
  shares <- 0
  cash <- wealth
  wealth_open <- numeric(nrow(w))
  position <- logical(nrow(w))
  trade_id <- rep(NA_character_, nrow(w))
  current_trade <- NA_character_
  next_trade <- 0L
  trade_rows <- list()
  entry_row <- NA_integer_
  entry_open <- NA_real_
  entry_reason <- NA_character_

  for (i in seq_len(nrow(w))) {
    desired <- target[[i]]
    if (shares > 0 && !desired) {
      cash <- shares * w$open[[i]] * (1 - cost)
      shares <- 0
      z <- length(trade_rows) + 1L
      hold_rows <- entry_row:(i - 1L)
      trade_rows[[z]] <- data.frame(
        symbol = w$symbol[[i]], trade_id = current_trade,
        entry_date = w$session_date[[entry_row]], exit_date = w$session_date[[i]],
        entry_reason = entry_reason, exit_reason = "CROSS_BELOW",
        entry_open = entry_open, exit_open = w$open[[i]],
        holding_sessions = i - entry_row,
        gross_trade_return = w$open[[i]] / entry_open - 1,
        maximum_favorable_excursion = max(w$high[hold_rows]) / entry_open - 1,
        maximum_adverse_excursion = min(w$low[hold_rows]) / entry_open - 1,
        stringsAsFactors = FALSE
      )
      current_trade <- NA_character_
    }
    if (shares == 0 && desired && i < nrow(w)) {
      next_trade <- next_trade + 1L
      current_trade <- sprintf("%s_T%03d", w$symbol[[i]], next_trade)
      shares <- cash * (1 - cost) / w$open[[i]]
      cash <- 0
      entry_row <- i
      entry_open <- w$open[[i]]
      entry_reason <- if (i == 1L && signal_type[[i]] == "WARM_START_ENTRY") "WARM_START_ENTRY" else "CROSS_ABOVE"
    }
    wealth_open[[i]] <- cash + shares * w$open[[i]]
    position[[i]] <- shares > 0
    trade_id[[i]] <- current_trade
  }
  if (shares > 0) {
    i <- nrow(w)
    cash <- shares * w$open[[i]] * (1 - cost)
    wealth_open[[i]] <- cash
    hold_rows <- entry_row:max(entry_row, i - 1L)
    trade_rows[[length(trade_rows) + 1L]] <- data.frame(
      symbol = w$symbol[[i]], trade_id = current_trade,
      entry_date = w$session_date[[entry_row]], exit_date = w$session_date[[i]],
      entry_reason = entry_reason, exit_reason = "BOUNDARY_EXIT",
      entry_open = entry_open, exit_open = w$open[[i]],
      holding_sessions = i - entry_row,
      gross_trade_return = w$open[[i]] / entry_open - 1,
      maximum_favorable_excursion = max(w$high[hold_rows]) / entry_open - 1,
      maximum_adverse_excursion = min(w$low[hold_rows]) / entry_open - 1,
      stringsAsFactors = FALSE
    )
    position[[i]] <- FALSE
    trade_id[[i]] <- NA_character_
  }
  trades <- if (length(trade_rows)) do.call(rbind, trade_rows) else data.frame()
  if (nrow(trades)) {
    trades$net_trade_return <- (1 - cost) * (1 + trades$gross_trade_return) * (1 - cost) - 1
    trades$whipsaw_20 <- trades$holding_sessions <= contract$whipsaw_sessions
  }
  path <- data.frame(
    symbol = w$symbol, session_date = w$session_date, open = w$open, close = w$close,
    sma200 = w$sma200, target_from_prior_close = target, signal_type = signal_type,
    in_position_after_open = position, trade_id = trade_id,
    strategy_wealth_open = wealth_open,
    strategy_drawdown = hyp_mom021_drawdown(wealth_open),
    stringsAsFactors = FALSE
  )
  list(path = path, trades = trades)
}

hyp_mom021_random_controls <- function(bars, state, one_way_bps, contract = hyp_mom021_contract(), seed_offset = 0L) {
  contract <- hyp_mom021_validate_contract(contract)
  x <- hyp_mom021_validate_bars(bars, contract)
  w <- x[x$session_date >= contract$discovery_start & x$session_date <= contract$discovery_end, , drop = FALSE]
  interval_returns <- w$open[-1L] / head(w$open, -1L) - 1
  state <- as.logical(state)[seq_along(interval_returns)]
  n <- length(state)
  if (n < 2L) return(numeric())
  set.seed(contract$random_seed + as.integer(seed_offset))
  shifts <- sample(seq_len(n - 1L), contract$random_simulations, replace = contract$random_simulations > n - 1L)
  cost <- one_way_bps / 10000
  vapply(shifts, function(k) {
    s <- c(tail(state, k), head(state, n - k))
    transitions <- sum(s != c(FALSE, head(s, -1L))) + as.integer(tail(s, 1L))
    prod(1 + ifelse(s, interval_returns, 0)) * (1 - cost)^transitions - 1
  }, numeric(1))
}

hyp_mom021_analyze_asset <- function(bars, contract = hyp_mom021_contract(), seed_offset = 0L) {
  contract <- hyp_mom021_validate_contract(contract)
  x <- hyp_mom021_validate_bars(bars, contract)
  symbol <- unique(x$symbol)
  if (length(symbol) != 1L) hyp_mom021_stop("Asset analysis requires one symbol.")
  primary <- hyp_mom021_replay(x, contract$primary_cost_bps, contract)
  stress <- hyp_mom021_replay(x, contract$stress_cost_bps, contract)
  trades <- primary$trades
  if (!nrow(trades)) hyp_mom021_stop(paste(symbol, "has no SMA200 ownership trades."))
  trades$primary_trade_return <- trades$net_trade_return
  trades$stress_trade_return <- stress$trades$net_trade_return
  path <- primary$path
  path$stress_wealth_open <- stress$path$strategy_wealth_open
  w <- x[x$session_date >= contract$discovery_start & x$session_date <= contract$discovery_end, , drop = FALSE]
  cost <- contract$primary_cost_bps / 10000
  bh_wealth <- (1 - cost) * w$open / w$open[[1L]]
  bh_wealth[[length(bh_wealth)]] <- bh_wealth[[length(bh_wealth)]] * (1 - cost)
  bh_return <- tail(bh_wealth, 1L) - 1
  bh_dd <- hyp_mom021_drawdown(bh_wealth)
  path$buy_hold_wealth_open <- bh_wealth
  path$buy_hold_drawdown <- bh_dd
  daily_returns <- path$strategy_wealth_open[-1L] / head(path$strategy_wealth_open, -1L) - 1
  random <- hyp_mom021_random_controls(x, path$target_from_prior_close, contract$primary_cost_bps, contract, seed_offset)
  observed <- tail(path$strategy_wealth_open, 1L) - 1
  summary <- data.frame(
    symbol = symbol,
    trade_count = nrow(trades),
    signal_entry_count = sum(trades$entry_reason == "CROSS_ABOVE"),
    warm_start_count = sum(trades$entry_reason == "WARM_START_ENTRY"),
    boundary_exit_count = sum(trades$exit_reason == "BOUNDARY_EXIT"),
    exposure_fraction = mean(path$target_from_prior_close),
    primary_return = observed,
    stress_return = tail(path$stress_wealth_open, 1L) - 1,
    buy_hold_primary_return = bh_return,
    excess_vs_buy_hold = observed - bh_return,
    primary_sharpe = hyp_mom021_sharpe(daily_returns),
    maximum_drawdown = min(path$strategy_drawdown),
    buy_hold_maximum_drawdown = min(bh_dd),
    drawdown_improvement = min(path$strategy_drawdown) - min(bh_dd),
    mean_primary_trade_return = mean(trades$primary_trade_return),
    median_primary_trade_return = stats::median(trades$primary_trade_return),
    primary_hit_rate = mean(trades$primary_trade_return > 0),
    median_holding_sessions = stats::median(trades$holding_sessions),
    whipsaw_20_fraction = mean(trades$whipsaw_20),
    mean_maximum_adverse_excursion = mean(trades$maximum_adverse_excursion),
    random_median_return = stats::median(random),
    observed_random_percentile = mean(random <= observed),
    stringsAsFactors = FALSE
  )
  list(path = path, trades = trades, summary = summary,
       random = data.frame(symbol = symbol, simulation_id = seq_along(random), primary_return = random))
}
