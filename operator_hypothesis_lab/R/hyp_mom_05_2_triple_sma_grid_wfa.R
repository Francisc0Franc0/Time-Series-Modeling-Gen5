h052_stop <- function(message) stop(paste0("[HYP-MOM-05.2] ", message), call. = FALSE)

h052_contract <- function() {
  list(
    hypothesis_id = "HYP-MOM-05.2",
    descriptive_name = "Triple-SMA Grid Walk-Forward",
    evidence_stage = "REUSED_WINDOW_WALK_FORWARD_DEVELOPMENT",
    as_of_timestamp = "2026-08-07 17:30:00 America/New_York",
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    fast_grid = c(10L, 15L, 20L),
    medium_grid = c(30L, 40L, 50L),
    slow_grid = c(60L, 90L, 120L),
    prehistory_sessions = 130L,
    leverages = c(1, 1.8),
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    primary_financing_rate = 0.06,
    stress_financing_rate = 0.10,
    maintenance_equity_ratio = 0.30,
    random_simulations = 500L,
    random_seed = 20260813L,
    minimum_plateau_size = 3L,
    minimum_positive_folds = 3L,
    minimum_high_random_fraction = 0.20
  )
}

h052_validate_contract <- function(contract = h052_contract()) {
  frozen <- h052_contract()
  if (!identical(names(contract), names(frozen))) h052_stop("Frozen contract field set changed.")
  same <- vapply(names(frozen), function(x) identical(contract[[x]], frozen[[x]]), logical(1))
  if (!all(same)) h052_stop(paste("Frozen contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  contract
}

h052_grid <- function(contract = h052_contract()) {
  contract <- h052_validate_contract(contract)
  grid <- expand.grid(
    fast = contract$fast_grid, medium = contract$medium_grid, slow = contract$slow_grid,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  grid <- grid[grid$fast < grid$medium & grid$medium < grid$slow, , drop = FALSE]
  grid$candidate_id <- sprintf("F%03d_M%03d_S%03d", grid$fast, grid$medium, grid$slow)
  grid <- grid[order(grid$fast, grid$medium, grid$slow), c("candidate_id", "fast", "medium", "slow")]
  rownames(grid) <- NULL
  if (nrow(grid) != 27L) h052_stop("Frozen grid must contain exactly 27 candidates.")
  grid
}

h052_blocks <- function() {
  data.frame(
    block_id = c("2021H1", "2021H2", "2022H1", "2022H2", "2023H1", "2023H2"),
    start_date = as.Date(c("2021-01-04", "2021-07-01", "2022-01-03", "2022-07-01", "2023-01-03", "2023-07-03")),
    end_date = as.Date(c("2021-06-30", "2021-12-31", "2022-06-30", "2022-12-30", "2023-06-30", "2023-12-29")),
    stringsAsFactors = FALSE
  )
}

h052_folds <- function() {
  blocks <- h052_blocks()$block_id
  lapply(3:6, function(i) list(
    fold = i - 2L,
    train_blocks = blocks[seq_len(i - 1L)],
    test_block = blocks[[i]]
  ))
}

h052_validate_bars <- function(bars, contract = h052_contract()) {
  contract <- h052_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) h052_stop(paste("Bars missing columns:", paste(missing, collapse = ", ")))
  x <- as.data.frame(bars, stringsAsFactors = FALSE)
  x$symbol <- toupper(trimws(as.character(x$symbol)))
  x$session_date <- as.Date(x$session_date)
  x[c("open", "high", "low", "close", "volume")] <- lapply(x[c("open", "high", "low", "close", "volume")], as.numeric)
  if (anyNA(x$session_date) || any(!is.finite(as.matrix(x[c("open", "high", "low", "close", "volume")])))) h052_stop("Bars contain missing or non-finite values.")
  if (any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) h052_stop("Bars contain invalid OHLCV values.")
  if (anyDuplicated(x[c("symbol", "session_date")])) h052_stop("Bars contain duplicate symbol/session rows.")
  if (any(x$session_date >= contract$confirmation_start)) h052_stop("Confirmation observations entered development.")
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  rownames(x) <- NULL
  x
}

h052_sma <- function(x, n) {
  out <- rep(NA_real_, length(x))
  if (length(x) >= n) out[n:length(x)] <- stats::filter(as.numeric(x), rep(1 / n, n), sides = 1)[n:length(x)]
  out
}

h052_state <- function(bars, candidate, contract = h052_contract()) {
  contract <- h052_validate_contract(contract)
  x <- h052_validate_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) h052_stop("State construction requires one symbol.")
  required <- c("candidate_id", "fast", "medium", "slow")
  if (!all(required %in% names(candidate)) || nrow(candidate) != 1L) h052_stop("Candidate must be one frozen grid row.")
  frozen <- h052_grid(contract)
  if (!candidate$candidate_id %in% frozen$candidate_id) h052_stop("Candidate is outside the frozen grid.")
  expected <- frozen[frozen$candidate_id == candidate$candidate_id, , drop = FALSE]
  if (!identical(as.integer(candidate[c("fast", "medium", "slow")]), as.integer(expected[c("fast", "medium", "slow")]))) h052_stop("Candidate parameters do not match its frozen ID.")
  x$sma_fast <- h052_sma(x$close, candidate$fast)
  x$sma_medium <- h052_sma(x$close, candidate$medium)
  x$sma_slow <- h052_sma(x$close, candidate$slow)
  x$ordered <- !is.na(x$sma_slow) & x$sma_fast > x$sma_medium & x$sma_medium > x$sma_slow
  x$above_medium <- !is.na(x$sma_medium) & x$close > x$sma_medium
  prior_ordered <- c(FALSE, head(x$ordered, -1L))
  prior_above <- c(FALSE, head(x$above_medium, -1L))
  x$order_activation <- x$ordered & !prior_ordered
  x$cross_above_medium <- x$above_medium & !prior_above
  x
}

h052_schedule <- function(state, start_date, end_date,
                          policy = c("H052", "SMA_MEDIUM_ONLY", "ORDERED_STACK_ONLY", "BUY_HOLD")) {
  policy <- match.arg(policy)
  start_date <- as.Date(start_date); end_date <- as.Date(end_date)
  idx <- which(state$session_date >= start_date & state$session_date <= end_date)
  if (length(idx) < 2L) h052_stop("Evaluation block has fewer than two sessions.")
  if (idx[[1L]] <= 1L || is.na(state$sma_slow[idx[[1L]] - 1L])) h052_stop("Insufficient prehistory at block start.")
  target <- rep(FALSE, length(idx)); reason <- rep("HOLD_CASH", length(idx))
  signal_date <- state$session_date[idx - 1L]
  long <- FALSE; completed_exit <- FALSE
  for (i in seq_along(idx)) {
    if (i == length(idx)) {
      if (long) reason[[i]] <- "BOUNDARY_EXIT"
      target[[i]] <- FALSE
      next
    }
    j <- idx[[i]] - 1L
    in_block <- state$session_date[[j]] >= start_date
    if (policy == "BUY_HOLD") {
      long <- TRUE
      reason[[i]] <- if (i == 1L) "BUY_HOLD_ENTRY" else "HOLD_LONG"
    } else if (!in_block) {
      long <- FALSE
      reason[[i]] <- "PRE_BLOCK_STATE_IGNORED"
    } else if (policy == "H052") {
      if (long && !state$above_medium[[j]]) {
        long <- FALSE; completed_exit <- TRUE; reason[[i]] <- "CROSS_BELOW_MEDIUM"
      } else if (!long && !completed_exit && state$order_activation[[j]] && state$above_medium[[j]]) {
        long <- TRUE; reason[[i]] <- "ORDER_ACTIVATION"
      } else if (!long && completed_exit && state$cross_above_medium[[j]] && state$ordered[[j]]) {
        long <- TRUE; reason[[i]] <- "MEDIUM_RECLAIM"
      } else reason[[i]] <- if (long) "HOLD_LONG" else "HOLD_CASH"
    } else if (policy == "SMA_MEDIUM_ONLY") {
      if (long && !state$above_medium[[j]]) {
        long <- FALSE; reason[[i]] <- "CROSS_BELOW_MEDIUM"
      } else if (!long && state$cross_above_medium[[j]]) {
        long <- TRUE; reason[[i]] <- "CROSS_ABOVE_MEDIUM"
      } else reason[[i]] <- if (long) "HOLD_LONG" else "HOLD_CASH"
    } else {
      if (long && !state$ordered[[j]]) {
        long <- FALSE; reason[[i]] <- "ORDER_LOSS"
      } else if (!long && state$order_activation[[j]]) {
        long <- TRUE; reason[[i]] <- "ORDER_ACTIVATION"
      } else reason[[i]] <- if (long) "HOLD_LONG" else "HOLD_CASH"
    }
    target[[i]] <- long
  }
  data.frame(row_index = idx, session_date = state$session_date[idx], signal_date = signal_date,
             policy = policy, target_long = target, transition_reason = reason, stringsAsFactors = FALSE)
}

h052_drawdown <- function(wealth) wealth / cummax(wealth) - 1

h052_sharpe <- function(wealth) {
  if (length(wealth) < 3L || any(wealth <= 0)) return(NA_real_)
  r <- wealth[-1L] / head(wealth, -1L) - 1
  s <- stats::sd(r)
  if (!is.finite(s) || s == 0) return(NA_real_)
  sqrt(252) * mean(r) / s
}

h052_replay <- function(state, schedule, leverage = 1, one_way_bps = 5,
                        annual_financing_rate = 0.06, contract = h052_contract()) {
  contract <- h052_validate_contract(contract)
  if (!leverage %in% contract$leverages) h052_stop("Unsupported leverage.")
  if (nrow(schedule) < 2L || tail(schedule$target_long, 1L)) h052_stop("Schedule must finish in cash.")
  w <- state[schedule$row_index, , drop = FALSE]
  cost <- one_way_bps / 10000
  daily_rate <- (1 + annual_financing_rate)^(1 / 252) - 1
  cash <- 1; shares <- 0; debt <- 0; financing <- 0
  wealth <- numeric(nrow(w)); gross <- numeric(nrow(w)); debt_path <- numeric(nrow(w))
  equity_ratio <- rep(NA_real_, nrow(w)); effective_leverage <- numeric(nrow(w)); position <- logical(nrow(w))
  trade_id <- rep(NA_integer_, nrow(w)); trade_counter <- 0L; current_trade <- NA_integer_
  entry_reason <- rep(NA_character_, nrow(w)); exit_reason <- rep(NA_character_, nrow(w))
  trade_rows <- list(); entry_equity <- NA_real_; entry_row <- NA_integer_; entry_open <- NA_real_
  current_entry_reason <- NA_character_; entry_financing <- NA_real_
  for (i in seq_len(nrow(w))) {
    if (shares > 0 && i > 1L) {
      charge <- debt * daily_rate; debt <- debt + charge; financing <- financing + charge
    }
    desired <- isTRUE(schedule$target_long[[i]])
    if (shares > 0 && !desired) {
      gross_before <- shares * w$open[[i]]
      cash <- shares * w$open[[i]] * (1 - cost) - debt
      hold_rows <- entry_row:max(entry_row, i - 1L)
      trade_rows[[length(trade_rows) + 1L]] <- data.frame(
        symbol = w$symbol[[i]], policy = schedule$policy[[i]], leverage = leverage,
        trade_id = current_trade, entry_date = w$session_date[[entry_row]], exit_date = w$session_date[[i]],
        entry_reason = current_entry_reason, exit_reason = schedule$transition_reason[[i]],
        entry_open = entry_open, exit_open = w$open[[i]], holding_sessions = i - entry_row,
        underlying_return = w$open[[i]] / entry_open - 1,
        equity_trade_return = cash / entry_equity - 1,
        maximum_favorable_excursion = max(w$high[hold_rows]) / entry_open - 1,
        maximum_adverse_excursion = min(w$low[hold_rows]) / entry_open - 1,
        financing_cost = financing - entry_financing,
        exit_gross_notional = gross_before, stringsAsFactors = FALSE
      )
      shares <- 0; debt <- 0; exit_reason[[i]] <- schedule$transition_reason[[i]]; current_trade <- NA_integer_
    }
    if (shares == 0 && desired && i < nrow(w) && cash > 0) {
      trade_counter <- trade_counter + 1L; current_trade <- trade_counter
      entry_equity <- cash; entry_row <- i; entry_open <- w$open[[i]]
      current_entry_reason <- schedule$transition_reason[[i]]; entry_financing <- financing
      notional <- leverage * cash; debt <- (leverage - 1) * cash
      shares <- notional * (1 - cost) / w$open[[i]]; cash <- 0
      entry_reason[[i]] <- schedule$transition_reason[[i]]
    }
    gross[[i]] <- shares * w$open[[i]]
    wealth[[i]] <- cash + gross[[i]] - debt
    debt_path[[i]] <- debt; position[[i]] <- shares > 0; trade_id[[i]] <- current_trade
    if (gross[[i]] > 0) {
      equity_ratio[[i]] <- wealth[[i]] / gross[[i]]
      effective_leverage[[i]] <- if (wealth[[i]] > 0) gross[[i]] / wealth[[i]] else Inf
    }
  }
  path <- data.frame(
    symbol = w$symbol, session_date = w$session_date, signal_date = schedule$signal_date,
    policy = schedule$policy, leverage = leverage, open = w$open, close = w$close,
    sma_fast = w$sma_fast, sma_medium = w$sma_medium, sma_slow = w$sma_slow,
    ordered = w$ordered, target_long = schedule$target_long,
    transition_reason = schedule$transition_reason, in_position_after_open = position,
    trade_id = trade_id, wealth_open = wealth, drawdown = h052_drawdown(wealth),
    gross_position = gross, debt = debt_path, equity_ratio = equity_ratio,
    effective_leverage = effective_leverage, entry_reason = entry_reason,
    exit_reason = exit_reason, stringsAsFactors = FALSE
  )
  trades <- if (length(trade_rows)) do.call(rbind, trade_rows) else data.frame(
    symbol = character(), policy = character(), leverage = numeric(), trade_id = integer(),
    entry_date = as.Date(character()), exit_date = as.Date(character()), entry_reason = character(),
    exit_reason = character(), entry_open = numeric(), exit_open = numeric(), holding_sessions = integer(),
    underlying_return = numeric(), equity_trade_return = numeric(), maximum_favorable_excursion = numeric(),
    maximum_adverse_excursion = numeric(), financing_cost = numeric(), exit_gross_notional = numeric(),
    stringsAsFactors = FALSE
  )
  finite_eff <- effective_leverage[is.finite(effective_leverage)]
  summary <- data.frame(
    symbol = w$symbol[[1L]], policy = schedule$policy[[1L]], leverage = leverage,
    trade_count = trade_counter, turnover_events = 2L * trade_counter,
    activation_entries = sum(entry_reason == "ORDER_ACTIVATION", na.rm = TRUE),
    reclaim_entries = sum(entry_reason == "MEDIUM_RECLAIM", na.rm = TRUE),
    exposure_fraction = mean(head(schedule$target_long, -1L)),
    total_return = tail(wealth, 1L) - 1, sharpe = h052_sharpe(wealth),
    maximum_drawdown = min(path$drawdown, na.rm = TRUE),
    time_underwater = mean(path$drawdown < 0), total_financing_cost = financing,
    minimum_equity = min(wealth),
    maximum_effective_leverage = if (length(finite_eff)) max(finite_eff) else NA_real_,
    maintenance_breach_sessions = sum(equity_ratio < contract$maintenance_equity_ratio, na.rm = TRUE),
    nonpositive_equity = any(wealth <= 0),
    hit_rate = if (nrow(trades)) mean(trades$equity_trade_return > 0) else NA_real_,
    median_trade_return = if (nrow(trades)) stats::median(trades$equity_trade_return) else NA_real_,
    median_holding_sessions = if (nrow(trades)) stats::median(trades$holding_sessions) else NA_real_,
    stringsAsFactors = FALSE
  )
  list(path = path, trades = trades, summary = summary)
}

h052_replay_fast_1x <- function(state, schedule, one_way_bps = 5) {
  if (nrow(schedule) < 2L || tail(schedule$target_long, 1L)) h052_stop("Schedule must finish in cash.")
  w <- state[schedule$row_index, , drop = FALSE]
  target <- as.logical(schedule$target_long); cost_factor <- 1 - one_way_bps / 10000
  factors <- rep(1, nrow(w))
  if (target[[1L]]) factors[[1L]] <- cost_factor
  if (nrow(w) > 1L) for (i in 2:nrow(w)) {
    if (target[[i - 1L]]) factors[[i]] <- w$open[[i]] / w$open[[i - 1L]]
    if (target[[i]] != target[[i - 1L]]) factors[[i]] <- factors[[i]] * cost_factor
  }
  wealth <- cumprod(factors); drawdown <- h052_drawdown(wealth)
  entries <- which(target & !c(FALSE, head(target, -1L)))
  data.frame(
    symbol = w$symbol[[1L]], policy = schedule$policy[[1L]], leverage = 1,
    trade_count = length(entries), turnover_events = 2L * length(entries),
    activation_entries = sum(schedule$transition_reason[entries] == "ORDER_ACTIVATION"),
    reclaim_entries = sum(schedule$transition_reason[entries] == "MEDIUM_RECLAIM"),
    exposure_fraction = mean(head(target, -1L)), total_return = tail(wealth, 1L) - 1,
    sharpe = h052_sharpe(wealth), maximum_drawdown = min(drawdown),
    time_underwater = mean(drawdown < 0), stringsAsFactors = FALSE
  )
}

h052_fractional_rank <- function(x) {
  if (all(is.na(x))) return(rep(NA_real_, length(x)))
  rank(x, na.last = "keep", ties.method = "average") / sum(!is.na(x))
}

h052_block_scorecard <- function(asset_metrics) {
  required <- c("candidate_id", "block_id", "symbol", "policy", "total_return", "sharpe", "maximum_drawdown", "trade_count")
  if (!all(required %in% names(asset_metrics))) h052_stop("Asset metrics lack scorecard columns.")
  primary <- asset_metrics[asset_metrics$policy == "H052" & asset_metrics$leverage == 1, , drop = FALSE]
  sma <- asset_metrics[asset_metrics$policy == "SMA_MEDIUM_ONLY" & asset_metrics$leverage == 1,
                       c("candidate_id", "block_id", "symbol", "total_return"), drop = FALSE]
  ordered <- asset_metrics[asset_metrics$policy == "ORDERED_STACK_ONLY" & asset_metrics$leverage == 1,
                           c("candidate_id", "block_id", "symbol", "total_return"), drop = FALSE]
  names(sma)[[4L]] <- "sma_return"; names(ordered)[[4L]] <- "ordered_return"
  x <- merge(merge(primary, sma, by = c("candidate_id", "block_id", "symbol"), all.x = TRUE),
             ordered, by = c("candidate_id", "block_id", "symbol"), all.x = TRUE)
  x$excess_stronger_trend <- x$total_return - pmax(x$sma_return, x$ordered_return)
  groups <- split(x, interaction(x$candidate_id, x$block_id, drop = TRUE))
  out <- do.call(rbind, lapply(groups, function(z) data.frame(
    candidate_id = z$candidate_id[[1L]], block_id = z$block_id[[1L]], asset_count = nrow(z),
    median_return = stats::median(z$total_return), positive_fraction = mean(z$total_return > 0),
    median_sharpe = stats::median(z$sharpe, na.rm = TRUE),
    median_maximum_drawdown = stats::median(z$maximum_drawdown),
    median_excess_stronger_trend = stats::median(z$excess_stronger_trend),
    median_trade_count = stats::median(z$trade_count), stringsAsFactors = FALSE
  )))
  rownames(out) <- NULL
  components <- c("median_return", "positive_fraction", "median_sharpe", "median_maximum_drawdown", "median_excess_stronger_trend")
  out$block_composite <- NA_real_
  for (block in unique(out$block_id)) {
    rows <- out$block_id == block
    ranks <- sapply(components, function(column) h052_fractional_rank(out[[column]][rows]))
    out$block_composite[rows] <- rowMeans(ranks)
  }
  out
}

h052_select_fold <- function(block_scorecard, grid, fold) {
  train <- block_scorecard[block_scorecard$block_id %in% fold$train_blocks, , drop = FALSE]
  if (!nrow(train)) h052_stop("Fold has no training score rows.")
  groups <- split(train, train$candidate_id)
  summary <- do.call(rbind, lapply(groups, function(z) data.frame(
    candidate_id = z$candidate_id[[1L]], training_blocks = nrow(z),
    mean_score = mean(z$block_composite),
    se_score = if (nrow(z) > 1L) stats::sd(z$block_composite) / sqrt(nrow(z)) else 0,
    median_trade_count = stats::median(z$median_trade_count), stringsAsFactors = FALSE
  )))
  summary <- merge(summary, grid, by = "candidate_id", all.x = TRUE, sort = FALSE)
  best <- summary[order(-summary$mean_score, summary$candidate_id), , drop = FALSE][1L, ]
  threshold <- best$mean_score - best$se_score
  summary$in_tolerance_set <- summary$mean_score >= threshold
  eligible <- summary[summary$in_tolerance_set, , drop = FALSE]
  selected <- eligible[order(eligible$median_trade_count, -eligible$slow, -eligible$medium, -eligible$fast, eligible$candidate_id), , drop = FALSE][1L, ]
  summary$selected <- summary$candidate_id == selected$candidate_id
  summary$fold <- fold$fold; summary$test_block <- fold$test_block
  summary$best_candidate_id <- best$candidate_id; summary$tolerance_threshold <- threshold
  summary$plateau_size <- nrow(eligible)
  summary
}

h052_run_selection <- function(asset_metrics, contract = h052_contract()) {
  contract <- h052_validate_contract(contract)
  grid <- h052_grid(contract); scorecard <- h052_block_scorecard(asset_metrics)
  selections <- lapply(h052_folds(), function(fold) h052_select_fold(scorecard, grid, fold))
  surface <- do.call(rbind, selections); rownames(surface) <- NULL
  selected <- surface[surface$selected, c("fold", "test_block", "candidate_id", "fast", "medium", "slow", "mean_score", "se_score", "median_trade_count", "best_candidate_id", "tolerance_threshold", "plateau_size")]
  selected <- selected[order(selected$fold), ]; rownames(selected) <- NULL
  list(block_scorecard = scorecard, selection_surface = surface, selections = selected)
}

h052_grid_neighbors <- function(grid, candidate_id) {
  x <- grid[grid$candidate_id == candidate_id, , drop = FALSE]
  if (nrow(x) != 1L) h052_stop("Unknown candidate for neighbor lookup.")
  step_difference <- (grid$fast != x$fast) + (grid$medium != x$medium) + (grid$slow != x$slow)
  grid$candidate_id[step_difference == 1L]
}

h052_state_return <- function(open, target, leverage, one_way_bps, annual_financing_rate) {
  target <- as.logical(target)
  if (length(open) != length(target) || length(open) < 2L || tail(target, 1L)) h052_stop("Invalid control state.")
  cost <- one_way_bps / 10000
  daily_rate <- (1 + annual_financing_rate)^(1 / 252) - 1
  starts <- which(target & !c(FALSE, head(target, -1L)))
  ends <- which(!target & c(FALSE, head(target, -1L)))
  if (!length(starts)) return(0)
  if (length(starts) != length(ends)) h052_stop("Control state has unmatched trades.")
  wealth <- 1
  for (i in seq_along(starts)) {
    holding <- ends[[i]] - starts[[i]]
    multiplier <- leverage * (1 - cost) * (open[ends[[i]]] / open[starts[[i]]]) * (1 - cost) -
      (leverage - 1) * (1 + daily_rate)^holding
    wealth <- wealth * multiplier
    if (wealth <= 0) break
  }
  wealth - 1
}

h052_circular_controls <- function(open, target, leverage, contract = h052_contract(), seed_offset = 0L) {
  contract <- h052_validate_contract(contract)
  exposure <- head(as.logical(target), -1L); n <- length(exposure)
  if (n < 2L || !any(exposure)) return(rep(0, contract$random_simulations))
  set.seed(contract$random_seed + as.integer(seed_offset))
  shifts <- sample(seq_len(n - 1L), contract$random_simulations, replace = contract$random_simulations > n - 1L)
  vapply(shifts, function(k) {
    rotated <- c(tail(exposure, k), head(exposure, n - k))
    h052_state_return(open, c(rotated, FALSE), leverage, contract$primary_cost_bps, contract$primary_financing_rate)
  }, numeric(1))
}

h052_compound_fold_controls <- function(x) {
  required <- c("instance_id", "symbol", "leverage", "simulation_id", "fold_return")
  if (!all(required %in% names(x))) h052_stop("Fold controls lack compounding columns.")
  key <- paste(x$instance_id, x$leverage, x$simulation_id, sep = "|")
  key_factor <- factor(key, levels = unique(key))
  first <- !duplicated(key)
  log_wealth <- rowsum(log1p(x$fold_return), key_factor, reorder = FALSE)[, 1L]
  data.frame(instance_id = x$instance_id[first], symbol = x$symbol[first], leverage = x$leverage[first],
             simulation_id = x$simulation_id[first], total_return = expm1(log_wealth), stringsAsFactors = FALSE)
}
