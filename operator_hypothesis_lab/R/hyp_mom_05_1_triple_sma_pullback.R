h051_stop <- function(message) stop(paste0("[HYP-MOM-05.1] ", message), call. = FALSE)

h051_contract <- function() {
  list(
    hypothesis_id = "HYP-MOM-05.1",
    descriptive_name = "Ordered Triple-SMA Pullback/Reclaim",
    evidence_stage = "DISCOVERY_REUSED_WINDOW",
    as_of_timestamp = "2026-08-07 17:30:00 America/New_York",
    discovery_start = as.Date("2021-01-04"),
    discovery_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    fast_sessions = 15L,
    medium_sessions = 30L,
    slow_sessions = 45L,
    prehistory_sessions = 60L,
    leverages = c(1, 1.8),
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    primary_financing_rate = 0.06,
    stress_financing_rate = 0.10,
    maintenance_equity_ratio = 0.30,
    initial_wealth = 1,
    random_simulations = 500L,
    random_seed = 20260812L,
    whipsaw_sessions = 20L
  )
}

h051_validate_contract <- function(contract = h051_contract()) {
  frozen <- h051_contract()
  if (!identical(names(contract), names(frozen))) h051_stop("Frozen contract field set changed.")
  same <- vapply(names(frozen), function(x) identical(contract[[x]], frozen[[x]]), logical(1))
  if (!all(same)) h051_stop(paste("Frozen contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  contract
}

h051_validate_bars <- function(bars, contract = h051_contract()) {
  contract <- h051_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) h051_stop(paste("Bars missing columns:", paste(missing, collapse = ", ")))
  x <- as.data.frame(bars, stringsAsFactors = FALSE)
  x$symbol <- toupper(trimws(as.character(x$symbol)))
  x$session_date <- as.Date(x$session_date)
  x[c("open", "high", "low", "close", "volume")] <- lapply(x[c("open", "high", "low", "close", "volume")], as.numeric)
  if (anyNA(x$session_date) || any(!is.finite(as.matrix(x[c("open", "high", "low", "close", "volume")])))) {
    h051_stop("Bars contain missing or non-finite values.")
  }
  if (any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) h051_stop("Bars contain invalid OHLCV values.")
  if (anyDuplicated(x[c("symbol", "session_date")])) h051_stop("Bars contain duplicate symbol/session rows.")
  if (any(x$session_date >= contract$confirmation_start)) h051_stop("Confirmation observations entered discovery.")
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  rownames(x) <- NULL
  x
}

h051_sma <- function(x, n) {
  out <- rep(NA_real_, length(x))
  if (length(x) >= n) out[n:length(x)] <- stats::filter(as.numeric(x), rep(1 / n, n), sides = 1)[n:length(x)]
  out
}

h051_drawdown <- function(wealth) {
  wealth <- as.numeric(wealth)
  peak <- cummax(wealth)
  wealth / peak - 1
}

h051_sharpe <- function(wealth) {
  if (length(wealth) < 3L || any(wealth <= 0)) return(NA_real_)
  r <- wealth[-1L] / head(wealth, -1L) - 1
  s <- stats::sd(r)
  if (!is.finite(s) || s == 0) return(NA_real_)
  sqrt(252) * mean(r) / s
}

h051_cagr <- function(wealth) {
  if (length(wealth) < 2L || tail(wealth, 1L) <= 0) return(NA_real_)
  tail(wealth, 1L)^(252 / (length(wealth) - 1L)) - 1
}

h051_state <- function(bars, contract = h051_contract()) {
  contract <- h051_validate_contract(contract)
  x <- h051_validate_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) h051_stop("State construction requires one symbol.")
  x$sma15 <- h051_sma(x$close, contract$fast_sessions)
  x$sma30 <- h051_sma(x$close, contract$medium_sessions)
  x$sma45 <- h051_sma(x$close, contract$slow_sessions)
  x$ordered <- !is.na(x$sma45) & x$sma15 > x$sma30 & x$sma30 > x$sma45
  x$above_medium <- !is.na(x$sma30) & x$close > x$sma30
  prior_ordered <- c(FALSE, head(x$ordered, -1L))
  prior_above <- c(FALSE, head(x$above_medium, -1L))
  x$order_activation <- x$ordered & !prior_ordered
  x$order_loss <- !x$ordered & prior_ordered
  x$cross_above_medium <- x$above_medium & !prior_above
  x$cross_below_medium <- !x$above_medium & prior_above
  x
}

h051_schedule <- function(state, policy = c("H051", "SMA30_ONLY", "ORDERED_STACK", "BUY_HOLD"), contract = h051_contract()) {
  policy <- match.arg(policy)
  contract <- h051_validate_contract(contract)
  idx <- which(state$session_date >= contract$discovery_start & state$session_date <= contract$discovery_end)
  if (length(idx) < 2L) h051_stop("Discovery window has fewer than two sessions.")
  if (idx[[1L]] <= 1L || is.na(state$sma45[idx[[1L]] - 1L])) h051_stop("Insufficient prehistory for triple-SMA state.")
  prior <- idx - 1L
  target <- rep(FALSE, length(idx))
  reason <- rep("HOLD_CASH", length(idx))
  signal_date <- state$session_date[prior]
  long <- FALSE
  completed_exit <- FALSE
  for (i in seq_along(idx)) {
    if (i == length(idx)) {
      if (long) reason[[i]] <- "BOUNDARY_EXIT"
      long <- FALSE
      target[[i]] <- FALSE
      next
    }
    j <- prior[[i]]
    in_window <- state$session_date[[j]] >= contract$discovery_start
    if (policy == "BUY_HOLD") {
      if (i == 1L) reason[[i]] <- "BUY_HOLD_ENTRY"
      long <- TRUE
    } else if (!in_window) {
      long <- FALSE
      reason[[i]] <- "PRE_WINDOW_STATE_IGNORED"
    } else if (policy == "H051") {
      if (long && !state$above_medium[[j]]) {
        long <- FALSE
        completed_exit <- TRUE
        reason[[i]] <- "CROSS_BELOW_MEDIUM"
      } else if (!long && !completed_exit && state$order_activation[[j]] && state$above_medium[[j]]) {
        long <- TRUE
        reason[[i]] <- "ORDER_ACTIVATION"
      } else if (!long && completed_exit && state$cross_above_medium[[j]] && state$ordered[[j]]) {
        long <- TRUE
        reason[[i]] <- "MEDIUM_RECLAIM"
      } else {
        reason[[i]] <- if (long) "HOLD_LONG" else "HOLD_CASH"
      }
    } else if (policy == "SMA30_ONLY") {
      if (long && !state$above_medium[[j]]) {
        long <- FALSE
        reason[[i]] <- "CROSS_BELOW_MEDIUM"
      } else if (!long && state$cross_above_medium[[j]]) {
        long <- TRUE
        reason[[i]] <- "CROSS_ABOVE_MEDIUM"
      } else {
        reason[[i]] <- if (long) "HOLD_LONG" else "HOLD_CASH"
      }
    } else if (policy == "ORDERED_STACK") {
      if (long && !state$ordered[[j]]) {
        long <- FALSE
        reason[[i]] <- "ORDER_LOSS"
      } else if (!long && state$order_activation[[j]]) {
        long <- TRUE
        reason[[i]] <- "ORDER_ACTIVATION"
      } else {
        reason[[i]] <- if (long) "HOLD_LONG" else "HOLD_CASH"
      }
    }
    target[[i]] <- long
  }
  data.frame(
    row_index = idx,
    session_date = state$session_date[idx],
    signal_date = signal_date,
    policy = policy,
    target_long = target,
    transition_reason = reason,
    stringsAsFactors = FALSE
  )
}

h051_empty_trades <- function() {
  data.frame(
    symbol = character(), policy = character(), leverage = numeric(), scenario = character(),
    trade_id = character(), entry_date = as.Date(character()), exit_date = as.Date(character()),
    entry_reason = character(), exit_reason = character(), entry_open = numeric(), exit_open = numeric(),
    holding_sessions = integer(), underlying_return = numeric(), equity_trade_return = numeric(),
    maximum_favorable_excursion = numeric(), maximum_adverse_excursion = numeric(),
    financing_cost = numeric(), maintenance_breach = logical(), minimum_equity_ratio = numeric(),
    stringsAsFactors = FALSE
  )
}

h051_replay <- function(
  state,
  schedule,
  leverage,
  one_way_bps,
  annual_financing_rate,
  scenario,
  contract = h051_contract()
) {
  contract <- h051_validate_contract(contract)
  if (!leverage %in% contract$leverages) h051_stop("Unsupported leverage.")
  if (nrow(schedule) < 2L || tail(schedule$target_long, 1L)) h051_stop("Schedule must finish in cash.")
  w <- state[schedule$row_index, , drop = FALSE]
  cost <- one_way_bps / 10000
  daily_rate <- (1 + annual_financing_rate)^(1 / 252) - 1
  cash <- contract$initial_wealth
  shares <- 0
  debt <- 0
  cumulative_financing <- 0
  wealth <- numeric(nrow(w))
  gross_position <- numeric(nrow(w))
  debt_path <- numeric(nrow(w))
  equity_ratio <- rep(NA_real_, nrow(w))
  effective_leverage <- numeric(nrow(w))
  position <- logical(nrow(w))
  trade_id_path <- rep(NA_character_, nrow(w))
  trade_rows <- list()
  trade_counter <- 0L
  entry_row <- NA_integer_
  entry_equity <- NA_real_
  entry_open <- NA_real_
  entry_reason <- NA_character_
  entry_financing <- NA_real_
  current_trade <- NA_character_
  trade_min_equity_ratio <- NA_real_
  trade_maintenance_breach <- FALSE

  for (i in seq_len(nrow(w))) {
    if (shares > 0 && i > entry_row) {
      charge <- debt * daily_rate
      debt <- debt + charge
      cumulative_financing <- cumulative_financing + charge
    }
    if (shares > 0) {
      gross_pretrade <- shares * w$open[[i]]
      ratio_pretrade <- (gross_pretrade - debt) / gross_pretrade
      trade_min_equity_ratio <- min(trade_min_equity_ratio, ratio_pretrade, na.rm = TRUE)
      trade_maintenance_breach <- trade_maintenance_breach || ratio_pretrade < contract$maintenance_equity_ratio
    }
    desired <- isTRUE(schedule$target_long[[i]])
    if (shares > 0 && !desired) {
      gross_before <- shares * w$open[[i]]
      cash <- gross_before * (1 - cost) - debt
      hold_rows <- entry_row:max(entry_row, i - 1L)
      trade_rows[[length(trade_rows) + 1L]] <- data.frame(
        symbol = w$symbol[[i]], policy = schedule$policy[[i]], leverage = leverage, scenario = scenario,
        trade_id = current_trade, entry_date = w$session_date[[entry_row]], exit_date = w$session_date[[i]],
        entry_reason = entry_reason, exit_reason = schedule$transition_reason[[i]],
        entry_open = entry_open, exit_open = w$open[[i]], holding_sessions = i - entry_row,
        underlying_return = w$open[[i]] / entry_open - 1,
        equity_trade_return = cash / entry_equity - 1,
        maximum_favorable_excursion = max(w$high[hold_rows]) / entry_open - 1,
        maximum_adverse_excursion = min(w$low[hold_rows]) / entry_open - 1,
        financing_cost = cumulative_financing - entry_financing,
        maintenance_breach = trade_maintenance_breach,
        minimum_equity_ratio = trade_min_equity_ratio,
        stringsAsFactors = FALSE
      )
      shares <- 0
      debt <- 0
      current_trade <- NA_character_
      trade_min_equity_ratio <- NA_real_
      trade_maintenance_breach <- FALSE
    }
    if (shares == 0 && desired && i < nrow(w) && cash > 0) {
      trade_counter <- trade_counter + 1L
      current_trade <- sprintf("%s_%s_L%s_T%03d", w$symbol[[i]], schedule$policy[[i]], format(leverage, trim = TRUE), trade_counter)
      entry_equity <- cash
      entry_open <- w$open[[i]]
      entry_row <- i
      entry_reason <- schedule$transition_reason[[i]]
      entry_financing <- cumulative_financing
      notional <- leverage * cash
      debt <- (leverage - 1) * cash
      shares <- notional * (1 - cost) / w$open[[i]]
      cash <- 0
      entry_gross <- shares * w$open[[i]]
      trade_min_equity_ratio <- (entry_gross - debt) / entry_gross
      trade_maintenance_breach <- trade_min_equity_ratio < contract$maintenance_equity_ratio
    }
    gross_position[[i]] <- shares * w$open[[i]]
    equity <- cash + gross_position[[i]] - debt
    wealth[[i]] <- equity
    debt_path[[i]] <- debt
    position[[i]] <- shares > 0
    trade_id_path[[i]] <- current_trade
    if (gross_position[[i]] > 0) {
      equity_ratio[[i]] <- equity / gross_position[[i]]
      effective_leverage[[i]] <- if (equity > 0) gross_position[[i]] / equity else Inf
    } else {
      effective_leverage[[i]] <- 0
    }
  }
  trades <- if (length(trade_rows)) do.call(rbind, trade_rows) else h051_empty_trades()
  path <- data.frame(
    symbol = w$symbol,
    session_date = w$session_date,
    signal_date = schedule$signal_date,
    policy = schedule$policy,
    leverage = leverage,
    scenario = scenario,
    open = w$open,
    close = w$close,
    sma15 = w$sma15,
    sma30 = w$sma30,
    sma45 = w$sma45,
    ordered = w$ordered,
    target_long = schedule$target_long,
    transition_reason = schedule$transition_reason,
    in_position_after_open = position,
    trade_id = trade_id_path,
    wealth_open = wealth,
    drawdown = h051_drawdown(wealth),
    gross_position = gross_position,
    debt = debt_path,
    equity_ratio = equity_ratio,
    effective_leverage = effective_leverage,
    stringsAsFactors = FALSE
  )
  list(path = path, trades = trades)
}

h051_summary <- function(replay, contract = h051_contract()) {
  p <- replay$path
  t <- replay$trades
  finite_eff <- p$effective_leverage[is.finite(p$effective_leverage)]
  exposed <- head(p$target_long, -1L)
  time_underwater <- mean(p$drawdown < 0)
  data.frame(
    symbol = p$symbol[[1L]], policy = p$policy[[1L]], leverage = p$leverage[[1L]], scenario = p$scenario[[1L]],
    trade_count = nrow(t), activation_entries = sum(t$entry_reason == "ORDER_ACTIVATION"),
    turnover_events = 2L * nrow(t),
    reclaim_entries = sum(t$entry_reason == "MEDIUM_RECLAIM"), exposure_fraction = mean(exposed),
    total_return = tail(p$wealth_open, 1L) - 1, cagr = h051_cagr(p$wealth_open), sharpe = h051_sharpe(p$wealth_open),
    maximum_drawdown = min(p$drawdown, na.rm = TRUE), time_underwater = time_underwater,
    minimum_equity = min(p$wealth_open, na.rm = TRUE),
    maximum_effective_leverage = if (length(finite_eff)) max(finite_eff) else NA_real_,
    maintenance_breach_sessions = sum(p$equity_ratio < contract$maintenance_equity_ratio, na.rm = TRUE),
    nonpositive_equity = any(p$wealth_open <= 0),
    mean_trade_return = if (nrow(t)) mean(t$equity_trade_return) else NA_real_,
    median_trade_return = if (nrow(t)) stats::median(t$equity_trade_return) else NA_real_,
    hit_rate = if (nrow(t)) mean(t$equity_trade_return > 0) else NA_real_,
    payoff_ratio = if (nrow(t) && any(t$equity_trade_return > 0) && any(t$equity_trade_return < 0)) mean(t$equity_trade_return[t$equity_trade_return > 0]) / abs(mean(t$equity_trade_return[t$equity_trade_return < 0])) else NA_real_,
    median_holding_sessions = if (nrow(t)) stats::median(t$holding_sessions) else NA_real_,
    whipsaw_fraction = if (nrow(t)) mean(t$holding_sessions <= contract$whipsaw_sessions) else NA_real_,
    total_financing_cost = sum(t$financing_cost),
    stringsAsFactors = FALSE
  )
}

h051_state_return <- function(open, target, leverage, one_way_bps, annual_financing_rate) {
  target <- as.logical(target)
  if (length(open) != length(target) || length(open) < 2L || tail(target, 1L)) h051_stop("Invalid control state.")
  cost <- one_way_bps / 10000
  daily_rate <- (1 + annual_financing_rate)^(1 / 252) - 1
  starts <- which(target & !c(FALSE, head(target, -1L)))
  ends <- which(!target & c(FALSE, head(target, -1L)))
  if (!length(starts)) return(0)
  if (length(starts) != length(ends)) h051_stop("Control state has unmatched trades.")
  wealth <- 1
  for (i in seq_along(starts)) {
    h <- ends[[i]] - starts[[i]]
    multiplier <- leverage * (1 - cost) * (open[ends[[i]]] / open[starts[[i]]]) * (1 - cost) -
      (leverage - 1) * (1 + daily_rate)^h
    wealth <- wealth * multiplier
    if (wealth <= 0) break
  }
  wealth - 1
}

h051_random_controls <- function(state, schedule, leverage, contract = h051_contract(), seed_offset = 0L) {
  w <- state[schedule$row_index, , drop = FALSE]
  exposure <- head(schedule$target_long, -1L)
  n <- length(exposure)
  if (n < 2L || !any(exposure)) return(numeric())
  set.seed(contract$random_seed + as.integer(seed_offset))
  shifts <- sample(seq_len(n - 1L), contract$random_simulations, replace = contract$random_simulations > n - 1L)
  vapply(shifts, function(k) {
    rotated <- c(tail(exposure, k), head(exposure, n - k))
    h051_state_return(w$open, c(rotated, FALSE), leverage, contract$primary_cost_bps, contract$primary_financing_rate)
  }, numeric(1))
}

h051_analyze_asset <- function(bars, contract = h051_contract(), seed_offset = 0L) {
  contract <- h051_validate_contract(contract)
  state <- h051_state(bars, contract)
  policies <- c("H051", "SMA30_ONLY", "ORDERED_STACK", "BUY_HOLD")
  schedules <- setNames(lapply(policies, function(p) h051_schedule(state, p, contract)), policies)
  scenarios <- data.frame(
    scenario = c("GROSS", "PRIMARY", "STRESS"),
    cost_bps = c(0, contract$primary_cost_bps, contract$stress_cost_bps),
    financing_rate = c(0, contract$primary_financing_rate, contract$stress_financing_rate),
    stringsAsFactors = FALSE
  )
  summaries <- paths <- trades <- list()
  z <- 0L
  for (policy in policies) {
    local_scenarios <- if (policy == "H051") scenarios else scenarios[scenarios$scenario == "PRIMARY", , drop = FALSE]
    for (leverage in contract$leverages) {
      for (j in seq_len(nrow(local_scenarios))) {
        z <- z + 1L
        s <- local_scenarios[j, ]
        replay <- h051_replay(state, schedules[[policy]], leverage, s$cost_bps, s$financing_rate, s$scenario, contract)
        summaries[[z]] <- h051_summary(replay, contract)
        if (policy == "H051" && s$scenario == "PRIMARY") {
          paths[[length(paths) + 1L]] <- replay$path
          trades[[length(trades) + 1L]] <- replay$trades
        }
      }
    }
  }
  summary <- do.call(rbind, summaries)
  summary$random_median_return <- NA_real_
  summary$random_percentile <- NA_real_
  path <- do.call(rbind, paths)
  trade <- do.call(rbind, trades)
  random <- do.call(rbind, lapply(seq_along(contract$leverages), function(i) {
    leverage <- contract$leverages[[i]]
    values <- h051_random_controls(state, schedules$H051, leverage, contract, seed_offset + i * 10000L)
    data.frame(symbol = unique(state$symbol), leverage = leverage, simulation_id = seq_along(values), total_return = values)
  }))
  for (leverage in contract$leverages) {
    row <- summary$policy == "H051" & summary$scenario == "PRIMARY" & summary$leverage == leverage
    controls <- random$total_return[random$leverage == leverage]
    summary$random_median_return[row] <- if (length(controls)) stats::median(controls) else NA_real_
    summary$random_percentile[row] <- if (length(controls)) mean(controls <= summary$total_return[row]) else NA_real_
  }
  list(state = state, summary = summary, paths = path, trades = trade, random = random)
}
