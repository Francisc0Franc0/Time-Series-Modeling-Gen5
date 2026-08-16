hreg81_stop <- function(message) stop(paste0("[HYP-REG-08.1] ", message), call. = FALSE)

hreg81_contract <- function() list(
  hypothesis_id = "HYP-REG-08.1",
  status = "FROZEN_FOR_DEVELOPMENT_EXECUTION",
  evidence_stage = "DEVELOPMENT_REUSED_WINDOW",
  as_of_timestamp = "2026-08-15 17:30:00 America/New_York",
  query_start = as.Date("2015-09-01"),
  analysis_start = as.Date("2018-01-02"),
  analysis_end = as.Date("2023-12-29"),
  confirmation_start = as.Date("2024-01-02"),
  years = 2018:2023,
  estimation_returns = 252L,
  percentile_lookback = 252L,
  preferred_prehistory = 550L,
  minimum_prehistory = 503L,
  primary_q = 5L,
  durability_q = 10L,
  low_enter = .30,
  low_exit = .40,
  high_exit = .60,
  high_enter = .70,
  synthetic_paths = 1000L,
  synthetic_seed = 8101L,
  synthetic_phi = .15,
  fast = 8L,
  slow = 14L,
  initial_wealth = 100000,
  primary_bps = 5,
  stress_bps = 10,
  placebo_simulations = 200L,
  exposure_near_count = 40L,
  reproduction_tolerance = 1e-10,
  policies = c("UNFILTERED", "ENTRY_HIGH_ONLY")
)

hreg81_assert_prices <- function(log_price, q) {
  q <- as.integer(q)
  if (!is.numeric(log_price) || any(!is.finite(log_price))) hreg81_stop("Log prices must be finite numeric values.")
  if (q < 2L || length(log_price) <= q + 2L) hreg81_stop("Aggregation horizon is invalid for the supplied history.")
  invisible(TRUE)
}

hreg81_variance_ratio <- function(log_price, q = 5L) {
  hreg81_assert_prices(log_price, q)
  q <- as.integer(q)
  returns <- diff(log_price)
  n <- length(returns)
  mu <- mean(returns)
  centered <- returns - mu
  sigma_one <- sum(centered^2) / (n - 1)
  if (!is.finite(sigma_one) || sigma_one <= 0) {
    return(c(vr = NA_real_, z_robust = NA_real_, p_value = NA_real_, robust_variance = NA_real_))
  }
  q_returns <- vapply(seq.int(q, n), function(i) sum(returns[seq.int(i - q + 1L, i)]) - q * mu, numeric(1))
  m <- q * (n - q + 1) * (1 - q / n)
  sigma_q <- sum(q_returns^2) / m
  vr <- sigma_q / sigma_one
  denominator <- sum(centered^2)^2
  robust_variance <- 0
  for (j in seq_len(q - 1L)) {
    products <- centered[seq.int(j + 1L, n)]^2 * centered[seq_len(n - j)]^2
    delta_j <- sum(products) / denominator
    robust_variance <- robust_variance + (2 * (q - j) / q)^2 * delta_j
  }
  z <- if (is.finite(robust_variance) && robust_variance > 0) (vr - 1) / sqrt(robust_variance) else NA_real_
  p <- if (is.finite(z)) 2 * stats::pnorm(-abs(z)) else NA_real_
  c(vr = vr, z_robust = z, p_value = p, robust_variance = robust_variance)
}

hreg81_population_vr_identity <- function(returns, q = 5L) {
  q <- as.integer(q)
  if (!is.numeric(returns) || any(!is.finite(returns)) || length(returns) <= q) hreg81_stop("Returns are invalid for the VR identity.")
  centered <- returns - mean(returns)
  gamma0 <- mean(centered^2)
  if (!is.finite(gamma0) || gamma0 <= 0) return(NA_real_)
  rho <- vapply(seq_len(q - 1L), function(k) mean(centered[seq.int(k + 1L, length(centered))] * centered[seq_len(length(centered) - k)]) / gamma0, numeric(1))
  1 + 2 * sum((1 - seq_len(q - 1L) / q) * rho)
}

hreg81_rolling_vr <- function(close, estimation_returns = 252L, q = 5L) {
  estimation_returns <- as.integer(estimation_returns)
  q <- as.integer(q)
  if (!is.numeric(close) || any(close <= 0, na.rm = TRUE)) hreg81_stop("Close must contain positive numeric values.")
  out <- matrix(NA_real_, nrow = length(close), ncol = 4L,
                dimnames = list(NULL, c("vr", "z_robust", "p_value", "robust_variance")))
  if (length(close) <= estimation_returns) return(as.data.frame(out))
  x <- log(close)
  for (i in seq.int(estimation_returns + 1L, length(close))) {
    window <- x[seq.int(i - estimation_returns, i)]
    if (all(is.finite(window))) out[i, ] <- hreg81_variance_ratio(window, q)
  }
  as.data.frame(out)
}

hreg81_rolling_percentile <- function(x, lookback = 252L) {
  lookback <- as.integer(lookback)
  if (lookback < 2L) hreg81_stop("Percentile lookback must be at least two.")
  out <- rep(NA_real_, length(x))
  if (length(x) <= lookback) return(out)
  for (i in seq.int(lookback + 1L, length(x))) {
    history <- x[seq.int(i - lookback, i - 1L)]
    if (is.finite(x[[i]]) && all(is.finite(history))) {
      out[[i]] <- (sum(history < x[[i]]) + .5 * sum(history == x[[i]])) / lookback
    }
  }
  out
}

hreg81_signed_hysteretic_state <- function(z, percentile, contract = hreg81_contract()) {
  if (length(z) != length(percentile)) hreg81_stop("State inputs have different lengths.")
  out <- rep(NA_character_, length(z))
  current <- NA_character_
  for (i in seq_along(z)) {
    value <- z[[i]]; rank <- percentile[[i]]
    if (!is.finite(value) || !is.finite(rank)) next
    if (is.na(current)) {
      current <- if (value < 0 && rank <= contract$low_enter) "LOW" else if (value > 0 && rank >= contract$high_enter) "HIGH" else "MEDIUM"
    } else if (identical(current, "LOW")) {
      if (value > 0 && rank >= contract$high_enter) current <- "HIGH" else if (value >= 0 || rank > contract$low_exit) current <- "MEDIUM"
    } else if (identical(current, "HIGH")) {
      if (value < 0 && rank <= contract$low_enter) current <- "LOW" else if (value <= 0 || rank < contract$high_exit) current <- "MEDIUM"
    } else {
      if (value < 0 && rank <= contract$low_enter) current <- "LOW" else if (value > 0 && rank >= contract$high_enter) current <- "HIGH"
    }
    out[[i]] <- current
  }
  out
}

hreg81_assert_bars <- function(bars, contract = hreg81_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  if (!is.data.frame(bars) || !nrow(bars) || !all(required %in% names(bars))) hreg81_stop("Daily-bar schema is incomplete or empty.")
  x <- bars
  x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg81_stop("Dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg81_stop("Confirmation rows entered the diagnostic.")
  numeric_cols <- c("open", "high", "low", "close", "volume")
  if (any(!is.finite(as.matrix(x[numeric_cols]))) || any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) hreg81_stop("OHLCV values are invalid.")
  if (any(x$high < pmax(x$open, x$close, x$low)) || any(x$low > pmin(x$open, x$close, x$high))) hreg81_stop("OHLC price ordering is invalid.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg81_build_asset_ledger <- function(bars, contract = hreg81_contract()) {
  x <- hreg81_assert_bars(bars, contract)
  if (length(unique(x$symbol)) != 1L) hreg81_stop("Asset ledger requires exactly one symbol.")
  primary <- hreg81_rolling_vr(x$close, contract$estimation_returns, contract$primary_q)
  durability <- hreg81_rolling_vr(x$close, contract$estimation_returns, contract$durability_q)
  percentile <- hreg81_rolling_percentile(primary$z_robust, contract$percentile_lookback)
  data.frame(
    symbol = x$symbol,
    session_date = x$session_date,
    open = x$open,
    high = x$high,
    low = x$low,
    close = x$close,
    volume = x$volume,
    vr5 = primary$vr,
    vr5_z_robust = primary$z_robust,
    vr5_p_value = primary$p_value,
    vr5_percentile = percentile,
    vr5_state = hreg81_signed_hysteretic_state(primary$z_robust, percentile, contract),
    vr10 = durability$vr,
    vr10_z_robust = durability$z_robust,
    vr10_p_value = durability$p_value,
    stringsAsFactors = FALSE
  )
}

hreg81_build_ledger <- function(bars, contract = hreg81_contract()) {
  x <- hreg81_assert_bars(bars, contract)
  rows <- lapply(split(x, x$symbol), hreg81_build_asset_ledger, contract = contract)
  out <- do.call(rbind, rows); rownames(out) <- NULL
  out[order(out$symbol, out$session_date), , drop = FALSE]
}

hreg81_state_diagnostics <- function(ledger, contract = hreg81_contract()) {
  x <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end & !is.na(ledger$vr5_state), , drop = FALSE]
  do.call(rbind, lapply(split(x, x$symbol), function(z) {
    states <- z$vr5_state
    groups <- cumsum(c(TRUE, states[-1L] != head(states, -1L)))
    runs <- do.call(rbind, lapply(split(seq_along(states), groups), function(idx) data.frame(state = states[idx[[1L]]], sessions = length(idx))))
    counts <- table(factor(states, levels = c("LOW", "MEDIUM", "HIGH")))
    years <- as.numeric(max(z$session_date) - min(z$session_date)) / 365.25
    data.frame(symbol = z$symbol[[1L]], observations = nrow(z),
               low_fraction = counts[["LOW"]] / length(states), medium_fraction = counts[["MEDIUM"]] / length(states), high_fraction = counts[["HIGH"]] / length(states),
               switches_per_year = max(0L, nrow(runs) - 1L) / years, median_run_sessions = stats::median(runs$sessions),
               median_vr5 = stats::median(z$vr5, na.rm = TRUE), median_z5 = stats::median(z$vr5_z_robust, na.rm = TRUE),
               median_vr10 = stats::median(z$vr10, na.rm = TRUE), q5_q10_sign_agreement = mean(sign(z$vr5_z_robust) == sign(z$vr10_z_robust), na.rm = TRUE),
               stringsAsFactors = FALSE)
  }))
}

hreg81_simulate_increments <- function(kind, n, phi = .15) {
  kind <- toupper(kind)
  if (kind == "IID") return(stats::rnorm(n))
  if (kind == "HETERO_IID") {
    scale <- rep(c(.45, 1.75, .75, 1.30), length.out = n)
    return(stats::rnorm(n, sd = scale))
  }
  if (!kind %in% c("AR_POS", "AR_NEG")) hreg81_stop("Unknown synthetic process.")
  coefficient <- if (kind == "AR_POS") abs(phi) else -abs(phi)
  as.numeric(stats::arima.sim(model = list(ar = coefficient), n = n, sd = 1))
}

hreg81_synthetic_calibration <- function(contract = hreg81_contract()) {
  set.seed(contract$synthetic_seed)
  kinds <- c("IID", "HETERO_IID", "AR_POS", "AR_NEG")
  rows <- vector("list", length(kinds) * contract$synthetic_paths)
  k <- 0L
  for (kind in kinds) for (simulation in seq_len(contract$synthetic_paths)) {
    increments <- hreg81_simulate_increments(kind, contract$estimation_returns, contract$synthetic_phi)
    stat <- hreg81_variance_ratio(c(0, cumsum(increments)), contract$primary_q)
    k <- k + 1L
    rows[[k]] <- data.frame(process = kind, simulation = simulation, vr = stat[["vr"]], z_robust = stat[["z_robust"]], p_value = stat[["p_value"]], stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

hreg81_synthetic_summary <- function(simulations) {
  do.call(rbind, lapply(split(simulations, simulations$process), function(x) data.frame(
    process = x$process[[1L]], paths = nrow(x), median_vr = stats::median(x$vr), median_z = stats::median(x$z_robust),
    rejection_rate_5pct = mean(x$p_value < .05), positive_vr_fraction = mean(x$vr > 1), stringsAsFactors = FALSE
  )))
}

hreg81_causality_audit <- function(contract = hreg81_contract()) {
  set.seed(contract$synthetic_seed + 1L)
  close <- exp(cumsum(c(0, stats::rnorm(900L, 0, .01))))
  original <- hreg81_rolling_vr(close, contract$estimation_returns, contract$primary_q)
  appended <- hreg81_rolling_vr(c(close, exp(log(tail(close, 1L)) + cumsum(stats::rnorm(50L, 0, .01)))), contract$estimation_returns, contract$primary_q)
  columns <- names(original)
  differences <- vapply(columns, function(column) {
    a <- original[[column]]; b <- head(appended[[column]], length(a)); keep <- is.finite(a) & is.finite(b)
    if (!any(keep)) NA_real_ else max(abs(a[keep] - b[keep]))
  }, numeric(1))
  data.frame(column = columns, maximum_append_difference = differences, passed = is.finite(differences) & differences == 0, stringsAsFactors = FALSE)
}

hreg81_validate_state_ledger <- function(states, contract = hreg81_contract()) {
  required <- c("symbol", "session_date", "vr5", "vr5_z_robust", "vr5_percentile", "vr5_state")
  if (!is.data.frame(states) || !all(required %in% names(states))) hreg81_stop("VR state-ledger schema is incomplete.")
  x <- states
  x$session_date <- as.Date(x$session_date)
  x$vr5_state <- trimws(as.character(x$vr5_state)); x$vr5_state[x$vr5_state == ""] <- NA_character_
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg81_stop("State dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg81_stop("Confirmation states entered the overlay.")
  bad <- !is.na(x$vr5_state) & !x$vr5_state %in% c("LOW", "MEDIUM", "HIGH")
  if (any(bad)) hreg81_stop("Unexpected VR state.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg81_align_vr <- function(cross_frame, states) {
  key <- paste(states$symbol, states$session_date)
  idx <- match(paste(cross_frame$symbol, cross_frame$session_date), key)
  out <- cross_frame
  for (column in c("vr5", "vr5_z_robust", "vr5_percentile", "vr5_state", "vr10", "vr10_z_robust")) out[[column]] <- states[[column]][idx]
  out
}

hreg81_rotate <- function(x, offset) {
  n <- length(x); if (!n) return(x)
  offset <- as.integer(offset) %% n; if (!offset) return(x)
  c(tail(x, offset), head(x, n - offset))
}

hreg81_shift_offset <- function(simulation_id, n, simulations = 200L) {
  if (n < 3L) hreg81_stop("Too few sessions for a circular-state control.")
  simulation_id <- as.integer(simulation_id); simulations <- as.integer(simulations)
  if (simulation_id < 1L || simulation_id > simulations) hreg81_stop("Simulation id is out of range.")
  as.integer(1L + floor((simulation_id - 1L) * (n - 2L) / max(simulations - 1L, 1L)))
}

hreg81_schedule <- function(aligned_frame, start, end, policy = "UNFILTERED", state_override = NULL) {
  policy <- toupper(policy)
  if (!policy %in% hreg81_contract()$policies) hreg81_stop("Unknown policy.")
  x <- aligned_frame
  if (!is.null(state_override)) {
    if (length(state_override) != nrow(x)) hreg81_stop("State override length mismatch.")
    x$vr5_state <- as.character(state_override)
  }
  start <- as.Date(start); end <- as.Date(end)
  idx <- which(x$session_date >= start & x$session_date <= end)
  if (!length(idx)) hreg81_stop("Schedule block is empty.")
  target <- rep(FALSE, nrow(x)); blocked <- rep(FALSE, nrow(x)); signal_state <- rep(NA_character_, nrow(x)); held <- FALSE
  for (i in idx) {
    signal_i <- i - 1L
    if (signal_i >= 1L && x$session_date[[signal_i]] >= start) {
      signal_state[[i]] <- x$vr5_state[[signal_i]]
      if (held && isTRUE(x$cross_down[[signal_i]])) held <- FALSE
      if (!held && isTRUE(x$cross_up[[signal_i]])) {
        if (identical(policy, "UNFILTERED")) held <- TRUE else {
          if (identical(signal_state[[i]], "HIGH")) held <- TRUE else blocked[[i]] <- TRUE
        }
      }
    }
    target[[i]] <- held
  }
  block <- target[idx]
  data.frame(target = block, entry_signal = c(FALSE, diff(as.integer(block)) == 1L), exit_signal = c(FALSE, diff(as.integer(block)) == -1L),
             blocked_entry = blocked[idx], signal_state = signal_state[idx], fast = x$sma_fast[idx], slow = x$sma_slow[idx], stringsAsFactors = FALSE)
}

hreg81_shifted_schedule <- function(aligned_frame, start, end, simulation_id, contract = hreg81_contract()) {
  in_block <- aligned_frame$session_date >= as.Date(start) & aligned_frame$session_date <= as.Date(end)
  states <- aligned_frame$vr5_state[in_block]
  shifted <- aligned_frame$vr5_state
  offset <- hreg81_shift_offset(simulation_id, length(states), contract$placebo_simulations)
  finite <- !is.na(states)
  shifted_block <- states
  shifted_block[finite] <- hreg81_rotate(states[finite], offset)
  shifted[in_block] <- shifted_block
  out <- hreg81_schedule(aligned_frame, start, end, "ENTRY_HIGH_ONLY", shifted)
  attr(out, "shift_offset") <- offset
  out
}

hreg81_midrank_percentile <- function(actual, controls) {
  controls <- controls[is.finite(controls)]
  if (!length(controls) || !is.finite(actual)) return(NA_real_)
  (sum(controls < actual) + .5 * sum(controls == actual)) / length(controls)
}

hreg81_exposure_near_ids <- function(control_panel, actual_exposure, count = 40L) {
  if (!all(c("simulation_id", "median_exposure") %in% names(control_panel))) hreg81_stop("Control-panel schema is incomplete.")
  x <- control_panel[is.finite(control_panel$median_exposure), , drop = FALSE]
  x$distance <- abs(x$median_exposure - actual_exposure)
  x <- x[order(x$distance, x$simulation_id), , drop = FALSE]
  head(x$simulation_id, min(as.integer(count), nrow(x)))
}

hreg81_compound_by_asset <- function(summary_rows) {
  required <- c("symbol", "policy", "scenario", "total_return")
  if (!all(required %in% names(summary_rows))) hreg81_stop("Summary schema is incomplete.")
  groups <- interaction(summary_rows$symbol, summary_rows$policy, summary_rows$scenario, drop = TRUE)
  do.call(rbind, lapply(split(summary_rows, groups), function(x) data.frame(symbol = x$symbol[[1L]], policy = x$policy[[1L]], scenario = x$scenario[[1L]],
    years = nrow(x), compounded_return = prod(1 + x$total_return) - 1, median_annual_return = stats::median(x$total_return), stringsAsFactors = FALSE)))
}

hreg81_label_trades <- function(trades, block_frame) {
  if (!nrow(trades)) return(trades)
  dates <- block_frame$session_date
  trades$entry_signal_date <- as.Date(NA); trades$entry_state <- NA_character_; trades$entry_z <- NA_real_; trades$entry_percentile <- NA_real_
  for (i in seq_len(nrow(trades))) {
    entry_i <- match(as.Date(trades$entry_date[[i]]), dates)
    if (!is.na(entry_i) && entry_i > 1L) {
      signal_i <- entry_i - 1L
      trades$entry_signal_date[[i]] <- dates[[signal_i]]; trades$entry_state[[i]] <- block_frame$vr5_state[[signal_i]]
      trades$entry_z[[i]] <- block_frame$vr5_z_robust[[signal_i]]; trades$entry_percentile[[i]] <- block_frame$vr5_percentile[[signal_i]]
    }
  }
  trades
}

hreg81_policy_panel <- function(primary) {
  do.call(rbind, lapply(split(primary, primary$policy), function(x) data.frame(policy = x$policy[[1L]], cells = nrow(x),
    median_return = stats::median(x$total_return), median_drawdown = stats::median(x$maximum_drawdown), median_sharpe = stats::median(x$sharpe, na.rm = TRUE),
    median_exposure = stats::median(x$exposure), median_turnover = stats::median(x$turnover), trades = sum(x$trade_count),
    positive_fraction = mean(x$total_return > 0), stringsAsFactors = FALSE)))
}
