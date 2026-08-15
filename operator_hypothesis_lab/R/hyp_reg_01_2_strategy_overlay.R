hreg12_stop <- function(message) stop(paste0("[HYP-REG-01.2] ", message), call. = FALSE)

hreg12_contract <- function() list(
  hypothesis_id = "HYP-REG-01.2",
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
  leverages = c(1, 1.8),
  primary_bps = 5,
  stress_bps = 10,
  primary_financing = 0.06,
  stress_financing = 0.10,
  placebo_simulations = 200L,
  exposure_near_count = 40L,
  reproduction_tolerance = 1e-10
)

hreg12_validate_state_ledger <- function(states, contract = hreg12_contract()) {
  required <- c("symbol", "session_date", "regime_state")
  if (!is.data.frame(states) || !all(required %in% names(states))) hreg12_stop("State ledger schema is incomplete.")
  x <- states
  x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg12_stop("State ledger dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg12_stop("Confirmation states entered the overlay.")
  bad <- !is.na(x$regime_state) & !x$regime_state %in% c("LOW", "MEDIUM", "HIGH")
  if (any(bad)) hreg12_stop("Unexpected regime state.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg12_cross_frame <- function(bars, fast = 8L, slow = 14L) {
  required <- c("symbol", "session_date", "close")
  if (!is.data.frame(bars) || !all(required %in% names(bars))) hreg12_stop("Bar schema is incomplete.")
  if (length(unique(bars$symbol)) != 1L) hreg12_stop("Cross frame requires one symbol.")
  x <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  x$sma_fast <- imom_sma(x$close, fast)
  x$sma_slow <- imom_sma(x$close, slow)
  above <- !is.na(x$sma_slow) & x$sma_fast > x$sma_slow
  x$cross_up <- above & c(FALSE, !head(above, -1L))
  x$cross_down <- !above & c(FALSE, head(above, -1L))
  x
}

hreg12_align_states <- function(cross_frame, states) {
  x <- cross_frame
  key <- paste(states$symbol, states$session_date)
  idx <- match(paste(x$symbol, x$session_date), key)
  x$regime_state <- states$regime_state[idx]
  x
}

hreg12_rotate <- function(x, offset) {
  n <- length(x)
  if (!n) return(x)
  offset <- as.integer(offset) %% n
  if (!offset) return(x)
  c(tail(x, offset), head(x, n - offset))
}

hreg12_shift_offset <- function(simulation_id, n, simulations = 200L) {
  if (n < 3L) hreg12_stop("Too few sessions for a circular-state control.")
  simulation_id <- as.integer(simulation_id)
  simulations <- as.integer(simulations)
  if (simulation_id < 1L || simulation_id > simulations) hreg12_stop("Simulation id is out of range.")
  as.integer(1L + floor((simulation_id - 1L) * (n - 2L) / max(simulations - 1L, 1L)))
}

hreg12_schedule <- function(aligned_frame, start, end, gate_low = TRUE,
                            state_override = NULL) {
  x <- aligned_frame
  start <- as.Date(start); end <- as.Date(end)
  if (!is.null(state_override)) {
    if (length(state_override) != nrow(x)) hreg12_stop("State override length mismatch.")
    x$regime_state <- as.character(state_override)
  }
  in_block <- x$session_date >= start & x$session_date <= end
  idx <- which(in_block)
  if (!length(idx)) hreg12_stop("Schedule block is empty.")
  target <- rep(FALSE, nrow(x)); blocked <- rep(FALSE, nrow(x)); signal_state <- rep(NA_character_, nrow(x)); held <- FALSE
  for (i in idx) {
    signal_i <- i - 1L
    if (signal_i >= 1L && x$session_date[[signal_i]] >= start) {
      signal_state[[i]] <- x$regime_state[[signal_i]]
      if (held && isTRUE(x$cross_down[[signal_i]])) held <- FALSE
      if (!held && isTRUE(x$cross_up[[signal_i]])) {
        if (gate_low) {
          if (is.na(signal_state[[i]])) hreg12_stop("A fresh crossover lacks a causal regime state.")
          if (identical(signal_state[[i]], "LOW")) blocked[[i]] <- TRUE else held <- TRUE
        } else {
          held <- TRUE
        }
      }
    }
    target[[i]] <- held
  }
  out <- data.frame(
    target = target[idx],
    entry_signal = c(FALSE, diff(as.integer(target[idx])) == 1L),
    exit_signal = c(FALSE, diff(as.integer(target[idx])) == -1L),
    blocked_entry = blocked[idx],
    signal_state = signal_state[idx],
    fast = x$sma_fast[idx],
    slow = x$sma_slow[idx],
    stringsAsFactors = FALSE
  )
  out
}

hreg12_shifted_schedule <- function(aligned_frame, start, end, simulation_id,
                                    contract = hreg12_contract()) {
  in_block <- aligned_frame$session_date >= as.Date(start) & aligned_frame$session_date <= as.Date(end)
  block_states <- aligned_frame$regime_state[in_block]
  if (any(is.na(block_states))) hreg12_stop("Circular-state control has missing states.")
  shifted <- aligned_frame$regime_state
  offset <- hreg12_shift_offset(simulation_id, length(block_states), contract$placebo_simulations)
  shifted[in_block] <- hreg12_rotate(block_states, offset)
  schedule <- hreg12_schedule(aligned_frame, start, end, gate_low = TRUE, state_override = shifted)
  attr(schedule, "shift_offset") <- offset
  schedule
}

hreg12_midrank_percentile <- function(actual, controls) {
  controls <- controls[is.finite(controls)]
  if (!length(controls) || !is.finite(actual)) return(NA_real_)
  (sum(controls < actual) + 0.5 * sum(controls == actual)) / length(controls)
}

hreg12_exposure_near_ids <- function(control_panel, actual_exposure, count = 40L) {
  required <- c("simulation_id", "median_exposure")
  if (!all(required %in% names(control_panel))) hreg12_stop("Control-panel schema is incomplete.")
  x <- control_panel[is.finite(control_panel$median_exposure), , drop = FALSE]
  x$exposure_distance <- abs(x$median_exposure - actual_exposure)
  x <- x[order(x$exposure_distance, x$simulation_id), , drop = FALSE]
  head(x$simulation_id, min(as.integer(count), nrow(x)))
}

hreg12_compound_by_asset <- function(summary_rows) {
  required <- c("symbol", "policy", "leverage", "scenario", "total_return")
  if (!all(required %in% names(summary_rows))) hreg12_stop("Summary schema is incomplete.")
  keys <- interaction(summary_rows$symbol, summary_rows$policy, summary_rows$leverage, summary_rows$scenario, drop = TRUE)
  do.call(rbind, lapply(split(summary_rows, keys), function(x) data.frame(
    symbol = x$symbol[[1L]], policy = x$policy[[1L]], leverage = x$leverage[[1L]], scenario = x$scenario[[1L]],
    years = nrow(x), compounded_return = prod(1 + x$total_return) - 1,
    median_annual_return = stats::median(x$total_return), stringsAsFactors = FALSE
  )))
}

hreg12_label_parent_trades <- function(trades, aligned_frame) {
  if (!nrow(trades)) return(trades)
  dates <- aligned_frame$session_date
  trades$entry_signal_date <- as.Date(NA)
  trades$entry_state <- NA_character_
  for (i in seq_len(nrow(trades))) {
    entry_i <- match(as.Date(trades$entry_date[[i]]), dates)
    if (!is.na(entry_i) && entry_i > 1L) {
      trades$entry_signal_date[[i]] <- dates[[entry_i - 1L]]
      trades$entry_state[[i]] <- aligned_frame$regime_state[[entry_i - 1L]]
    }
  }
  trades$gate_disposition <- ifelse(trades$entry_state == "LOW", "REMOVED_BY_GATE", "RETAINED")
  trades
}
