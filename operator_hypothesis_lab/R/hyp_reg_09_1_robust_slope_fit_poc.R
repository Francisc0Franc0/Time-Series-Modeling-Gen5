hreg91_stop <- function(message) stop(paste0("[HYP-REG-09.1] ", message), call. = FALSE)

hreg91_contract <- function() list(
  hypothesis_id = "HYP-REG-09.1",
  status = "FROZEN_FOR_DEVELOPMENT_EXECUTION",
  evidence_stage = "DEVELOPMENT_REUSED_WINDOW",
  as_of_timestamp = "2026-08-15 17:30:00 America/New_York",
  query_start = as.Date("2016-01-01"),
  analysis_start = as.Date("2018-01-02"),
  analysis_end = as.Date("2023-12-29"),
  confirmation_start = as.Date("2024-01-02"),
  years = 2018:2023,
  primary_window = 60L,
  durability_window = 120L,
  percentile_lookback = 252L,
  preferred_prehistory = 400L,
  minimum_prehistory = 372L,
  low_enter = .30,
  low_exit = .40,
  high_exit = .60,
  high_enter = .70,
  synthetic_paths = 500L,
  synthetic_seed = 9101L,
  fast = 8L,
  slow = 14L,
  initial_wealth = 100000,
  primary_bps = 5,
  stress_bps = 10,
  placebo_simulations = 200L,
  exposure_near_count = 40L,
  reproduction_tolerance = 1e-10,
  policies = c("UNFILTERED", "ENTRY_ORDERLY_UP_ONLY")
)

hreg91_theil_sen_slope <- function(y) {
  if (!is.numeric(y) || length(y) < 3L || any(!is.finite(y))) hreg91_stop("Theil-Sen input must contain at least three finite values.")
  n <- length(y)
  slopes <- unlist(lapply(seq_len(n - 1L), function(lag) (y[seq.int(lag + 1L, n)] - y[seq_len(n - lag)]) / lag), use.names = FALSE)
  stats::median(slopes)
}

hreg91_window_metrics <- function(log_price) {
  if (!is.numeric(log_price) || length(log_price) < 3L || any(!is.finite(log_price))) hreg91_stop("Window log prices must be finite.")
  returns <- diff(log_price)
  realized_volatility <- stats::sd(returns)
  slope <- hreg91_theil_sen_slope(log_price)
  normalized_strength <- if (is.finite(realized_volatility) && realized_volatility > 0) slope * sqrt(length(log_price) - 1L) / realized_volatility else NA_real_
  quality <- suppressWarnings(abs(stats::cor(seq_along(log_price), log_price, method = "spearman")))
  c(slope = slope, realized_volatility = realized_volatility, normalized_strength = normalized_strength, path_quality = quality)
}

hreg91_rolling_metrics <- function(close, window) {
  window <- as.integer(window)
  if (!is.numeric(close) || any(!is.finite(close)) || any(close <= 0)) hreg91_stop("Close must contain positive finite values.")
  out <- matrix(NA_real_, nrow = length(close), ncol = 4L,
                dimnames = list(NULL, c("slope", "realized_volatility", "normalized_strength", "path_quality")))
  if (length(close) < window) return(as.data.frame(out))
  log_close <- log(close)
  for (i in seq.int(window, length(close))) out[i, ] <- hreg91_window_metrics(log_close[seq.int(i - window + 1L, i)])
  as.data.frame(out)
}

hreg91_rolling_percentile <- function(x, lookback = 252L) {
  lookback <- as.integer(lookback)
  if (lookback < 2L) hreg91_stop("Percentile lookback must be at least two.")
  out <- rep(NA_real_, length(x))
  if (length(x) <= lookback) return(out)
  for (i in seq.int(lookback + 1L, length(x))) {
    history <- x[seq.int(i - lookback, i - 1L)]
    if (is.finite(x[[i]]) && all(is.finite(history))) out[[i]] <- (sum(history < x[[i]]) + .5 * sum(history == x[[i]])) / lookback
  }
  out
}

hreg91_quality_state <- function(percentile, contract = hreg91_contract()) {
  out <- rep(NA_character_, length(percentile)); current <- NA_character_
  for (i in seq_along(percentile)) {
    rank <- percentile[[i]]
    if (!is.finite(rank)) next
    if (is.na(current)) {
      current <- if (rank <= contract$low_enter) "LOW_QUALITY" else if (rank >= contract$high_enter) "HIGH_QUALITY" else "MEDIUM_QUALITY"
    } else if (identical(current, "LOW_QUALITY")) {
      if (rank >= contract$high_enter) current <- "HIGH_QUALITY" else if (rank > contract$low_exit) current <- "MEDIUM_QUALITY"
    } else if (identical(current, "HIGH_QUALITY")) {
      if (rank <= contract$low_enter) current <- "LOW_QUALITY" else if (rank < contract$high_exit) current <- "MEDIUM_QUALITY"
    } else {
      if (rank <= contract$low_enter) current <- "LOW_QUALITY" else if (rank >= contract$high_enter) current <- "HIGH_QUALITY"
    }
    out[[i]] <- current
  }
  out
}

hreg91_assert_bars <- function(bars, contract = hreg91_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  if (!is.data.frame(bars) || !nrow(bars) || !all(required %in% names(bars))) hreg91_stop("Daily-bar schema is incomplete or empty.")
  x <- bars; x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg91_stop("Dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg91_stop("Confirmation rows entered the diagnostic.")
  numeric_cols <- c("open", "high", "low", "close", "volume")
  if (any(!is.finite(as.matrix(x[numeric_cols]))) || any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) hreg91_stop("OHLCV values are invalid.")
  if (any(x$high < pmax(x$open, x$close, x$low)) || any(x$low > pmin(x$open, x$close, x$high))) hreg91_stop("OHLC price ordering is invalid.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg91_build_asset_ledger <- function(bars, contract = hreg91_contract()) {
  x <- hreg91_assert_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) hreg91_stop("Asset ledger requires exactly one symbol.")
  primary <- hreg91_rolling_metrics(x$close, contract$primary_window)
  durability <- hreg91_rolling_metrics(x$close, contract$durability_window)
  percentile <- hreg91_rolling_percentile(primary$path_quality, contract$percentile_lookback)
  state <- hreg91_quality_state(percentile, contract)
  data.frame(
    symbol = x$symbol, session_date = x$session_date, open = x$open, high = x$high, low = x$low, close = x$close, volume = x$volume,
    slope60 = primary$slope, realized_vol60 = primary$realized_volatility, normalized_strength60 = primary$normalized_strength,
    path_quality60 = primary$path_quality, quality_percentile60 = percentile, quality_state60 = state,
    orderly_up_eligible = is.finite(primary$normalized_strength) & primary$normalized_strength > 0 & state == "HIGH_QUALITY",
    slope120 = durability$slope, realized_vol120 = durability$realized_volatility, normalized_strength120 = durability$normalized_strength,
    path_quality120 = durability$path_quality, stringsAsFactors = FALSE
  )
}

hreg91_build_ledger <- function(bars, contract = hreg91_contract()) {
  x <- hreg91_assert_bars(bars, contract)
  rows <- lapply(split(x, x$symbol), hreg91_build_asset_ledger, contract = contract)
  out <- do.call(rbind, rows); rownames(out) <- NULL
  out[order(out$symbol, out$session_date), , drop = FALSE]
}

hreg91_state_diagnostics <- function(ledger, contract = hreg91_contract()) {
  x <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end & !is.na(ledger$quality_state60), , drop = FALSE]
  do.call(rbind, lapply(split(x, x$symbol), function(z) {
    states <- z$quality_state60; groups <- cumsum(c(TRUE, states[-1L] != head(states, -1L)))
    runs <- vapply(split(seq_along(states), groups), length, integer(1)); counts <- table(factor(states, levels = c("LOW_QUALITY", "MEDIUM_QUALITY", "HIGH_QUALITY")))
    years <- as.numeric(max(z$session_date) - min(z$session_date)) / 365.25
    data.frame(symbol = z$symbol[[1L]], observations = nrow(z), low_fraction = counts[["LOW_QUALITY"]] / length(states), medium_fraction = counts[["MEDIUM_QUALITY"]] / length(states),
      high_fraction = counts[["HIGH_QUALITY"]] / length(states), eligible_fraction = mean(z$orderly_up_eligible), switches_per_year = max(0L, length(runs) - 1L) / years,
      median_run_sessions = stats::median(runs), sign_agreement_60_120 = mean(sign(z$normalized_strength60) == sign(z$normalized_strength120), na.rm = TRUE),
      quality_correlation_60_120 = suppressWarnings(stats::cor(z$path_quality60, z$path_quality120, method = "spearman", use = "complete.obs")), stringsAsFactors = FALSE)
  }))
}

hreg91_simulate_path <- function(kind, n = 60L) {
  kind <- toupper(kind); t <- seq_len(n)
  if (kind == "CLEAN_UP") return(.002 * t + stats::rnorm(n, 0, .0005))
  if (kind == "CLEAN_DOWN") return(-.002 * t + stats::rnorm(n, 0, .0005))
  if (kind == "NOISY_UP") return(cumsum(stats::rnorm(n, .0015, .012)))
  if (kind == "RANDOM_WALK") return(cumsum(stats::rnorm(n, 0, .012)))
  if (kind == "REVERSAL") return(c(.0025 * seq_len(n %/% 2L), .0025 * (n %/% 2L) - .0025 * seq_len(n - n %/% 2L)) + stats::rnorm(n, 0, .001))
  hreg91_stop("Unknown synthetic path.")
}

hreg91_synthetic_calibration <- function(contract = hreg91_contract()) {
  set.seed(contract$synthetic_seed)
  kinds <- c("CLEAN_UP", "CLEAN_DOWN", "NOISY_UP", "RANDOM_WALK", "REVERSAL")
  rows <- vector("list", length(kinds) * contract$synthetic_paths); k <- 0L
  for (kind in kinds) for (simulation in seq_len(contract$synthetic_paths)) {
    path <- hreg91_simulate_path(kind, contract$primary_window); metric <- hreg91_window_metrics(path); k <- k + 1L
    rows[[k]] <- data.frame(process = kind, simulation = simulation, slope = metric[["slope"]], normalized_strength = metric[["normalized_strength"]], path_quality = metric[["path_quality"]], stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

hreg91_synthetic_summary <- function(simulations) do.call(rbind, lapply(split(simulations, simulations$process), function(x) data.frame(
  process = x$process[[1L]], paths = nrow(x), median_slope = stats::median(x$slope), positive_slope_fraction = mean(x$slope > 0),
  median_normalized_strength = stats::median(x$normalized_strength), median_path_quality = stats::median(x$path_quality), stringsAsFactors = FALSE)))

hreg91_scale_invariance_audit <- function(contract = hreg91_contract()) {
  set.seed(contract$synthetic_seed + 1L); path <- hreg91_simulate_path("NOISY_UP", contract$primary_window)
  base <- hreg91_window_metrics(path); scaled <- hreg91_window_metrics(3 * path)
  data.frame(metric = c("normalized_strength", "path_quality"), absolute_difference = abs(base[c("normalized_strength", "path_quality")] - scaled[c("normalized_strength", "path_quality")]), stringsAsFactors = FALSE)
}

hreg91_causality_audit <- function(contract = hreg91_contract()) {
  set.seed(contract$synthetic_seed + 2L); close <- exp(cumsum(stats::rnorm(900L, .0003, .012)))
  original <- hreg91_rolling_metrics(close, contract$primary_window)
  appended <- hreg91_rolling_metrics(c(close, exp(log(tail(close, 1L)) + cumsum(stats::rnorm(50L, .0003, .012)))), contract$primary_window)
  differences <- vapply(names(original), function(column) { a <- original[[column]]; b <- head(appended[[column]], length(a)); keep <- is.finite(a) & is.finite(b); if (!any(keep)) NA_real_ else max(abs(a[keep] - b[keep])) }, numeric(1))
  data.frame(column = names(original), maximum_append_difference = differences, passed = is.finite(differences) & differences == 0, stringsAsFactors = FALSE)
}

hreg91_validate_state_ledger <- function(states, contract = hreg91_contract()) {
  required <- c("symbol", "session_date", "normalized_strength60", "path_quality60", "quality_percentile60", "quality_state60", "orderly_up_eligible")
  if (!is.data.frame(states) || !all(required %in% names(states))) hreg91_stop("Slope/fit state-ledger schema is incomplete.")
  x <- states; x$session_date <- as.Date(x$session_date); x$quality_state60 <- trimws(as.character(x$quality_state60)); x$quality_state60[x$quality_state60 == ""] <- NA_character_
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg91_stop("State dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg91_stop("Confirmation states entered the overlay.")
  bad <- !is.na(x$quality_state60) & !x$quality_state60 %in% c("LOW_QUALITY", "MEDIUM_QUALITY", "HIGH_QUALITY")
  if (any(bad)) hreg91_stop("Unexpected quality state.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg91_align <- function(cross_frame, states) {
  key <- paste(states$symbol, states$session_date); idx <- match(paste(cross_frame$symbol, cross_frame$session_date), key); out <- cross_frame
  for (column in c("normalized_strength60", "path_quality60", "quality_percentile60", "quality_state60", "orderly_up_eligible", "normalized_strength120", "path_quality120")) out[[column]] <- states[[column]][idx]
  out
}

hreg91_rotate <- function(x, offset) { n <- length(x); if (!n) return(x); offset <- as.integer(offset) %% n; if (!offset) return(x); c(tail(x, offset), head(x, n - offset)) }
hreg91_shift_offset <- function(simulation_id, n, simulations = 200L) {
  if (n < 3L) hreg91_stop("Too few sessions for a circular control.")
  simulation_id <- as.integer(simulation_id); simulations <- as.integer(simulations)
  if (simulation_id < 1L || simulation_id > simulations) hreg91_stop("Simulation id is out of range.")
  as.integer(1L + floor((simulation_id - 1L) * (n - 2L) / max(simulations - 1L, 1L)))
}

hreg91_schedule <- function(aligned_frame, start, end, policy = "UNFILTERED", eligibility_override = NULL) {
  policy <- toupper(policy); if (!policy %in% hreg91_contract()$policies) hreg91_stop("Unknown policy.")
  x <- aligned_frame; if (!is.null(eligibility_override)) { if (length(eligibility_override) != nrow(x)) hreg91_stop("Eligibility override length mismatch."); x$orderly_up_eligible <- as.logical(eligibility_override) }
  start <- as.Date(start); end <- as.Date(end); idx <- which(x$session_date >= start & x$session_date <= end); if (!length(idx)) hreg91_stop("Schedule block is empty.")
  target <- rep(FALSE, nrow(x)); blocked <- rep(FALSE, nrow(x)); signal_state <- rep(NA_character_, nrow(x)); signal_strength <- rep(NA_real_, nrow(x)); signal_quality <- rep(NA_real_, nrow(x)); held <- FALSE
  for (i in idx) {
    signal_i <- i - 1L
    if (signal_i >= 1L && x$session_date[[signal_i]] >= start) {
      signal_state[[i]] <- x$quality_state60[[signal_i]]; signal_strength[[i]] <- x$normalized_strength60[[signal_i]]; signal_quality[[i]] <- x$path_quality60[[signal_i]]
      if (held && isTRUE(x$cross_down[[signal_i]])) held <- FALSE
      if (!held && isTRUE(x$cross_up[[signal_i]])) {
        if (identical(policy, "UNFILTERED")) held <- TRUE else if (isTRUE(x$orderly_up_eligible[[signal_i]])) held <- TRUE else blocked[[i]] <- TRUE
      }
    }
    target[[i]] <- held
  }
  block <- target[idx]
  data.frame(target = block, entry_signal = c(FALSE, diff(as.integer(block)) == 1L), exit_signal = c(FALSE, diff(as.integer(block)) == -1L), blocked_entry = blocked[idx],
    signal_state = signal_state[idx], signal_strength = signal_strength[idx], signal_quality = signal_quality[idx], fast = x$sma_fast[idx], slow = x$sma_slow[idx], stringsAsFactors = FALSE)
}

hreg91_shifted_schedule <- function(aligned_frame, start, end, simulation_id, contract = hreg91_contract()) {
  in_block <- aligned_frame$session_date >= as.Date(start) & aligned_frame$session_date <= as.Date(end)
  eligibility <- aligned_frame$orderly_up_eligible; block <- eligibility[in_block]; finite <- !is.na(block); offset <- hreg91_shift_offset(simulation_id, sum(finite), contract$placebo_simulations)
  shifted_block <- block; shifted_block[finite] <- hreg91_rotate(block[finite], offset); eligibility[in_block] <- shifted_block
  out <- hreg91_schedule(aligned_frame, start, end, "ENTRY_ORDERLY_UP_ONLY", eligibility); attr(out, "shift_offset") <- offset; out
}

hreg91_midrank_percentile <- function(actual, controls) { controls <- controls[is.finite(controls)]; if (!length(controls) || !is.finite(actual)) return(NA_real_); (sum(controls < actual) + .5 * sum(controls == actual)) / length(controls) }
hreg91_exposure_near_ids <- function(control_panel, actual_exposure, count = 40L) {
  if (!all(c("simulation_id", "median_exposure") %in% names(control_panel))) hreg91_stop("Control-panel schema is incomplete.")
  x <- control_panel[is.finite(control_panel$median_exposure), , drop = FALSE]; x$distance <- abs(x$median_exposure - actual_exposure); x <- x[order(x$distance, x$simulation_id), , drop = FALSE]
  head(x$simulation_id, min(as.integer(count), nrow(x)))
}

hreg91_compound_by_asset <- function(summary_rows) {
  required <- c("symbol", "policy", "scenario", "total_return"); if (!all(required %in% names(summary_rows))) hreg91_stop("Summary schema is incomplete.")
  groups <- interaction(summary_rows$symbol, summary_rows$policy, summary_rows$scenario, drop = TRUE)
  do.call(rbind, lapply(split(summary_rows, groups), function(x) data.frame(symbol = x$symbol[[1L]], policy = x$policy[[1L]], scenario = x$scenario[[1L]], years = nrow(x), compounded_return = prod(1 + x$total_return) - 1, median_annual_return = stats::median(x$total_return), stringsAsFactors = FALSE)))
}

hreg91_label_trades <- function(trades, block_frame) {
  if (!nrow(trades)) return(trades)
  dates <- block_frame$session_date; trades$entry_signal_date <- as.Date(NA); trades$entry_state <- NA_character_; trades$entry_strength <- NA_real_; trades$entry_quality <- NA_real_; trades$entry_eligible <- NA
  for (i in seq_len(nrow(trades))) {
    entry_i <- match(as.Date(trades$entry_date[[i]]), dates)
    if (!is.na(entry_i) && entry_i > 1L) { signal_i <- entry_i - 1L; trades$entry_signal_date[[i]] <- dates[[signal_i]]; trades$entry_state[[i]] <- block_frame$quality_state60[[signal_i]]; trades$entry_strength[[i]] <- block_frame$normalized_strength60[[signal_i]]; trades$entry_quality[[i]] <- block_frame$path_quality60[[signal_i]]; trades$entry_eligible[[i]] <- block_frame$orderly_up_eligible[[signal_i]] }
  }
  trades
}

hreg91_policy_panel <- function(primary) do.call(rbind, lapply(split(primary, primary$policy), function(x) data.frame(policy = x$policy[[1L]], cells = nrow(x),
  median_return = stats::median(x$total_return), median_drawdown = stats::median(x$maximum_drawdown), median_sharpe = stats::median(x$sharpe, na.rm = TRUE), median_exposure = stats::median(x$exposure),
  median_turnover = stats::median(x$turnover), trades = sum(x$trade_count), positive_fraction = mean(x$total_return > 0), stringsAsFactors = FALSE)))
