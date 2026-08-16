hreg52_stop <- function(message) stop(paste0("[HYP-REG-05.2] ", message), call. = FALSE)

hreg52_contract <- function() list(
  hypothesis_id = "HYP-REG-05.2",
  status = "FROZEN_FOR_DEVELOPMENT_EXECUTION",
  evidence_stage = "DEVELOPMENT_REUSED_WINDOW",
  as_of_timestamp = "2026-08-14 17:30:00 America/New_York",
  analysis_start = as.Date("2018-01-02"),
  analysis_end = as.Date("2023-12-29"),
  confirmation_start = as.Date("2024-01-02"),
  years = 2018:2023,
  fast = 8L,
  slow = 14L,
  initial_wealth = 100000,
  primary_bps = 5,
  stress_bps = 10,
  placebo_simulations = 200L,
  exposure_near_count = 40L,
  reproduction_tolerance = 1e-10,
  policies = c("UNFILTERED", "ENTRY_HIGH_ONLY", "REACTIVE_HIGH_ONLY")
)

hreg52_validate_state_ledger <- function(states, contract = hreg52_contract()) {
  required <- c("symbol", "session_date", "adx14", "adx_percentile", "adx_state")
  if (!is.data.frame(states) || !all(required %in% names(states))) hreg52_stop("ADX state ledger schema is incomplete.")
  x <- states
  x$session_date <- as.Date(x$session_date)
  x$adx_state <- trimws(as.character(x$adx_state))
  x$adx_state[x$adx_state == ""] <- NA_character_
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg52_stop("State dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg52_stop("Confirmation states entered the overlay.")
  bad <- !is.na(x$adx_state) & !x$adx_state %in% c("LOW", "MEDIUM", "HIGH")
  if (any(bad)) hreg52_stop("Unexpected ADX state.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg52_align_adx <- function(cross_frame, states) {
  x <- cross_frame
  key <- paste(states$symbol, states$session_date)
  idx <- match(paste(x$symbol, x$session_date), key)
  x$adx14 <- states$adx14[idx]
  x$adx_percentile <- states$adx_percentile[idx]
  x$adx_state <- states$adx_state[idx]
  x
}

hreg52_rotate <- function(x, offset) {
  n <- length(x)
  if (!n) return(x)
  offset <- as.integer(offset) %% n
  if (!offset) return(x)
  c(tail(x, offset), head(x, n - offset))
}

hreg52_shift_offset <- function(simulation_id, n, simulations = 200L) {
  if (n < 3L) hreg52_stop("Too few sessions for a circular-state control.")
  simulation_id <- as.integer(simulation_id)
  simulations <- as.integer(simulations)
  if (simulation_id < 1L || simulation_id > simulations) hreg52_stop("Simulation id is out of range.")
  as.integer(1L + floor((simulation_id - 1L) * (n - 2L) / max(simulations - 1L, 1L)))
}

hreg52_schedule <- function(aligned_frame, start, end, policy = "UNFILTERED",
                            state_override = NULL) {
  policy <- toupper(policy)
  if (!policy %in% hreg52_contract()$policies) hreg52_stop("Unknown policy.")
  x <- aligned_frame
  if (!is.null(state_override)) {
    if (length(state_override) != nrow(x)) hreg52_stop("State override length mismatch.")
    x$adx_state <- as.character(state_override)
  }
  start <- as.Date(start); end <- as.Date(end)
  idx <- which(x$session_date >= start & x$session_date <= end)
  if (!length(idx)) hreg52_stop("Schedule block is empty.")
  target <- rep(FALSE, nrow(x)); blocked <- rep(FALSE, nrow(x)); state_exit <- rep(FALSE, nrow(x))
  signal_state <- rep(NA_character_, nrow(x)); exit_reason <- rep(NA_character_, nrow(x)); held <- FALSE
  for (i in idx) {
    signal_i <- i - 1L
    if (signal_i >= 1L && x$session_date[[signal_i]] >= start) {
      signal_state[[i]] <- x$adx_state[[signal_i]]
      if (held) {
        if (isTRUE(x$cross_down[[signal_i]])) {
          held <- FALSE
          exit_reason[[i]] <- "PARENT_CROSS_DOWN"
        } else if (identical(policy, "REACTIVE_HIGH_ONLY")) {
          if (is.na(signal_state[[i]])) hreg52_stop("An open reactive trade lacks a causal ADX state.")
          if (!identical(signal_state[[i]], "HIGH")) {
            held <- FALSE
            state_exit[[i]] <- TRUE
            exit_reason[[i]] <- "ADX_LEFT_HIGH"
          }
        }
      }
      if (!held && isTRUE(x$cross_up[[signal_i]])) {
        if (identical(policy, "UNFILTERED")) {
          held <- TRUE
        } else {
          if (is.na(signal_state[[i]])) hreg52_stop("A fresh crossover lacks a causal ADX state.")
          if (identical(signal_state[[i]], "HIGH")) held <- TRUE else blocked[[i]] <- TRUE
        }
      }
    }
    target[[i]] <- held
  }
  block_target <- target[idx]
  data.frame(
    target = block_target,
    entry_signal = c(FALSE, diff(as.integer(block_target)) == 1L),
    exit_signal = c(FALSE, diff(as.integer(block_target)) == -1L),
    blocked_entry = blocked[idx],
    state_exit = state_exit[idx],
    signal_state = signal_state[idx],
    exit_reason = exit_reason[idx],
    fast = x$sma_fast[idx],
    slow = x$sma_slow[idx],
    stringsAsFactors = FALSE
  )
}

hreg52_shifted_schedule <- function(aligned_frame, start, end, simulation_id,
                                    policy, contract = hreg52_contract()) {
  in_block <- aligned_frame$session_date >= as.Date(start) & aligned_frame$session_date <= as.Date(end)
  states <- aligned_frame$adx_state[in_block]
  if (any(is.na(states))) hreg52_stop("Circular control has missing ADX states.")
  shifted <- aligned_frame$adx_state
  offset <- hreg52_shift_offset(simulation_id, length(states), contract$placebo_simulations)
  shifted[in_block] <- hreg52_rotate(states, offset)
  out <- hreg52_schedule(aligned_frame, start, end, policy, shifted)
  attr(out, "shift_offset") <- offset
  out
}

hreg52_midrank_percentile <- function(actual, controls) {
  controls <- controls[is.finite(controls)]
  if (!length(controls) || !is.finite(actual)) return(NA_real_)
  (sum(controls < actual) + 0.5 * sum(controls == actual)) / length(controls)
}

hreg52_exposure_near_ids <- function(control_panel, actual_exposure, count = 40L) {
  required <- c("simulation_id", "median_exposure")
  if (!all(required %in% names(control_panel))) hreg52_stop("Control-panel schema is incomplete.")
  x <- control_panel[is.finite(control_panel$median_exposure), , drop = FALSE]
  x$distance <- abs(x$median_exposure - actual_exposure)
  x <- x[order(x$distance, x$simulation_id), , drop = FALSE]
  head(x$simulation_id, min(as.integer(count), nrow(x)))
}

hreg52_compound_by_asset <- function(summary_rows) {
  required <- c("symbol", "policy", "scenario", "total_return")
  if (!all(required %in% names(summary_rows))) hreg52_stop("Summary schema is incomplete.")
  groups <- interaction(summary_rows$symbol, summary_rows$policy, summary_rows$scenario, drop = TRUE)
  do.call(rbind, lapply(split(summary_rows, groups), function(x) data.frame(
    symbol = x$symbol[[1L]], policy = x$policy[[1L]], scenario = x$scenario[[1L]],
    years = nrow(x), compounded_return = prod(1 + x$total_return) - 1,
    median_annual_return = stats::median(x$total_return), stringsAsFactors = FALSE
  )))
}

hreg52_label_trades <- function(trades, schedule, block_frame) {
  if (!nrow(trades)) return(trades)
  dates <- block_frame$session_date
  trades$entry_signal_date <- as.Date(NA)
  trades$entry_state <- NA_character_
  trades$exit_signal_date <- as.Date(NA)
  trades$exit_state <- NA_character_
  trades$exit_reason <- NA_character_
  for (i in seq_len(nrow(trades))) {
    entry_i <- match(as.Date(trades$entry_date[[i]]), dates)
    exit_i <- match(as.Date(trades$exit_date[[i]]), dates)
    if (!is.na(entry_i) && entry_i > 1L) {
      trades$entry_signal_date[[i]] <- dates[[entry_i - 1L]]
      trades$entry_state[[i]] <- block_frame$adx_state[[entry_i - 1L]]
    }
    if (!is.na(exit_i)) {
      if (exit_i > 1L) {
        trades$exit_signal_date[[i]] <- dates[[exit_i - 1L]]
        trades$exit_state[[i]] <- block_frame$adx_state[[exit_i - 1L]]
      }
      reason <- schedule$exit_reason[[exit_i]]
      trades$exit_reason[[i]] <- if (!is.na(reason)) reason else if (exit_i == nrow(schedule)) "YEAR_END_FORCED" else "UNLABELED"
    }
  }
  trades
}

hreg52_policy_panel <- function(primary) {
  do.call(rbind, lapply(split(primary, primary$policy), function(x) data.frame(
    policy = x$policy[[1L]], cells = nrow(x), median_return = stats::median(x$total_return),
    median_drawdown = stats::median(x$maximum_drawdown), median_sharpe = stats::median(x$sharpe, na.rm = TRUE),
    median_exposure = stats::median(x$exposure), median_turnover = stats::median(x$turnover),
    trades = sum(x$trade_count), positive_fraction = mean(x$total_return > 0), stringsAsFactors = FALSE
  )))
}
