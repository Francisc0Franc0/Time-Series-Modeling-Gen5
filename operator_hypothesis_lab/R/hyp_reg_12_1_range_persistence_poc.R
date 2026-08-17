hreg121_stop <- function(message) stop(paste0("[HYP-REG-12.1] ", message), call. = FALSE)

hreg121_contract <- function() list(
  hypothesis_id = "HYP-REG-12.1", status = "FROZEN_FOR_DEVELOPMENT_EXECUTION", evidence_stage = "DEVELOPMENT_REUSED_WINDOW",
  as_of_timestamp = "2026-08-15 17:30:00 America/New_York", query_start = as.Date("2016-01-01"), analysis_start = as.Date("2018-01-02"),
  analysis_end = as.Date("2023-12-29"), confirmation_start = as.Date("2024-01-02"), years = 2018:2023,
  range_window = 63L, persistence_window = 5L, persistence_required = 3L, upper_threshold = .75, lower_threshold = .25,
  event_sessions = 10L, synthetic_paths = 500L, synthetic_seed = 12101L, minimum_prehistory = 120L,
  fast = 8L, slow = 14L, initial_wealth = 100000, primary_bps = 5, stress_bps = 10,
  placebo_simulations = 200L, exposure_near_count = 40L, reproduction_tolerance = 1e-10,
  policies = c("UNFILTERED", "ENTRY_UPPER_PERSISTENT_ONLY")
)

hreg121_range_position <- function(close, window = 63L) {
  if (!is.numeric(close) || any(!is.finite(close)) || any(close <= 0)) hreg121_stop("Close must contain positive finite values.")
  window <- as.integer(window); n <- length(close); lo <- hi <- rp <- rep(NA_real_, n)
  if (n <= window) return(data.frame(prior_low = lo, prior_high = hi, range_position = rp))
  for (i in seq.int(window + 1L, n)) {
    prior <- close[seq.int(i - window, i - 1L)]; lo[[i]] <- min(prior); hi[[i]] <- max(prior)
    if (hi[[i]] > lo[[i]]) rp[[i]] <- (close[[i]] - lo[[i]]) / (hi[[i]] - lo[[i]])
  }
  data.frame(prior_low = lo, prior_high = hi, range_position = rp)
}

hreg121_persistence <- function(range_position, contract = hreg121_contract()) {
  n <- length(range_position); upper_count <- lower_count <- rep(NA_integer_, n)
  upper_now <- is.finite(range_position) & range_position >= contract$upper_threshold
  lower_now <- is.finite(range_position) & range_position <= contract$lower_threshold
  upper_persistent <- lower_persistent <- rep(FALSE, n)
  w <- contract$persistence_window
  if (n >= w) for (i in seq.int(w, n)) {
    idx <- seq.int(i - w + 1L, i)
    if (all(is.finite(range_position[idx]))) {
      upper_count[[i]] <- sum(upper_now[idx]); lower_count[[i]] <- sum(lower_now[idx])
      upper_persistent[[i]] <- upper_now[[i]] && upper_count[[i]] >= contract$persistence_required
      lower_persistent[[i]] <- lower_now[[i]] && lower_count[[i]] >= contract$persistence_required
    }
  }
  state <- rep(NA_character_, n); finite <- is.finite(range_position); state[finite] <- "OTHER"
  state[lower_persistent] <- "LOWER_PERSISTENT"; state[upper_persistent] <- "UPPER_PERSISTENT"
  data.frame(upper_now = upper_now, lower_now = lower_now, upper_count5 = upper_count, lower_count5 = lower_count,
    upper_persistent = upper_persistent, lower_persistent = lower_persistent, range_state = state, stringsAsFactors = FALSE)
}

hreg121_breakout_stream <- function(close, prior_high, range_position, contract = hreg121_contract()) {
  n <- length(close); event_id <- event_age <- retests <- rep(NA_integer_, n); boundary <- hold_fraction <- deepest_breach <- rep(NA_real_, n)
  event_active <- rep(FALSE, n); new_breakout <- rep(FALSE, n); above_boundary <- rep(NA, n)
  active_start <- NA_integer_; active_boundary <- NA_real_; active_id <- 0L; active_retests <- 0L; prior_above <- NA
  for (i in seq_len(n)) {
    transition <- is.finite(range_position[[i]]) && range_position[[i]] > 1 && (i == 1L || !is.finite(range_position[[i - 1L]]) || range_position[[i - 1L]] <= 1)
    active <- !is.na(active_start) && i - active_start < contract$event_sessions
    if (!active && transition) {
      active_start <- i; active_boundary <- prior_high[[i]]; active_id <- active_id + 1L; active_retests <- 0L; prior_above <- NA; active <- TRUE; new_breakout[[i]] <- TRUE
    }
    if (active) {
      idx <- seq.int(active_start, i); now_above <- close[[i]] > active_boundary
      if (!is.na(prior_above) && prior_above && !now_above) active_retests <- active_retests + 1L
      event_active[[i]] <- TRUE; event_id[[i]] <- active_id; event_age[[i]] <- i - active_start; boundary[[i]] <- active_boundary
      above_boundary[[i]] <- now_above; hold_fraction[[i]] <- mean(close[idx] > active_boundary)
      deepest_breach[[i]] <- min(close[idx] / active_boundary - 1); retests[[i]] <- active_retests; prior_above <- now_above
    }
  }
  data.frame(new_breakout = new_breakout, breakout_event_active = event_active, breakout_event_id = event_id,
    breakout_age = event_age, breakout_boundary = boundary, above_breakout_boundary = above_boundary,
    breakout_hold_fraction_so_far = hold_fraction, breakout_deepest_breach_so_far = deepest_breach,
    breakout_retests_so_far = retests, stringsAsFactors = FALSE)
}

hreg121_build_asset_ledger <- function(bars, contract = hreg121_contract()) {
  x <- hreg91_assert_bars(bars, contract); if (length(unique(x$symbol)) != 1L) hreg121_stop("Asset ledger requires one symbol.")
  r <- hreg121_range_position(x$close, contract$range_window); p <- hreg121_persistence(r$range_position, contract)
  e <- hreg121_breakout_stream(x$close, r$prior_high, r$range_position, contract)
  data.frame(symbol = x$symbol, session_date = x$session_date, open = x$open, high = x$high, low = x$low, close = x$close, volume = x$volume,
    r, p, e, stringsAsFactors = FALSE)
}

hreg121_build_ledger <- function(bars, contract = hreg121_contract()) {
  x <- hreg91_assert_bars(bars, contract); rows <- lapply(split(x, x$symbol), hreg121_build_asset_ledger, contract = contract)
  out <- do.call(rbind, rows); rownames(out) <- NULL; out[order(out$symbol, out$session_date), , drop = FALSE]
}

hreg121_event_outcomes <- function(asset_ledger, contract = hreg121_contract()) {
  events <- which(asset_ledger$new_breakout); rows <- list(); k <- 0L
  for (i in events) {
    end <- i + contract$event_sessions - 1L; if (end > nrow(asset_ledger)) next
    boundary <- asset_ledger$breakout_boundary[[i]]; path <- asset_ledger$close[i:end]; k <- k + 1L
    rows[[k]] <- data.frame(symbol = asset_ledger$symbol[[i]], event_date = asset_ledger$session_date[[i]], boundary = boundary,
      sessions = length(path), rapid_failure = any(path[seq_len(min(3L, length(path)))] <= boundary),
      hold_fraction10 = mean(path > boundary), terminal_above = tail(path, 1L) > boundary,
      maximum_breach = min(path / boundary - 1), maximum_extension = max(path / boundary - 1), stringsAsFactors = FALSE)
  }
  if (!length(rows)) return(data.frame(symbol = character(), event_date = as.Date(character()), boundary = numeric(), sessions = integer(), rapid_failure = logical(), hold_fraction10 = numeric(), terminal_above = logical(), maximum_breach = numeric(), maximum_extension = numeric()))
  do.call(rbind, rows)
}

hreg121_state_diagnostics <- function(ledger, cross_frames = NULL, contract = hreg121_contract()) {
  x <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end & !is.na(ledger$range_state), , drop = FALSE]
  do.call(rbind, lapply(split(x, x$symbol), function(z) {
    eligible_crosses <- NA_integer_
    if (!is.null(cross_frames) && z$symbol[[1L]] %in% names(cross_frames)) {
      q <- cross_frames[[z$symbol[[1L]]]]; idx <- match(q$session_date, z$session_date); eligible_crosses <- sum(q$cross_up & z$upper_persistent[idx], na.rm = TRUE)
    }
    data.frame(symbol = z$symbol[[1L]], observations = nrow(z), upper_persistent_fraction = mean(z$upper_persistent),
      lower_persistent_fraction = mean(z$lower_persistent), upper_now_fraction = mean(z$upper_now), breakouts = sum(z$new_breakout),
      event_fraction = mean(z$breakout_event_active), eligible_crosses = eligible_crosses,
      median_upper_dwell = hreg121_median_true_run(z$upper_persistent), stringsAsFactors = FALSE)
  }))
}

hreg121_median_true_run <- function(x) {
  y <- rle(x %in% TRUE); values <- y$lengths[y$values]; if (length(values)) stats::median(values) else 0
}

hreg121_simulate_log_path <- function(kind, n = 140L) {
  kind <- toupper(kind); t <- seq_len(n)
  if (kind == "CLEAN_UP") return(.003 * t + stats::rnorm(n, 0, .0005))
  if (kind == "CLEAN_DOWN") return(-.003 * t + stats::rnorm(n, 0, .0005))
  if (kind == "RANDOM_WALK") return(cumsum(stats::rnorm(n, 0, .012)))
  base <- rep(c(-.005, .005), length.out = n); event <- 100L
  if (kind == "BREAKOUT_HOLD") { base[event:n] <- base[event - 1L] + .06 + .0015 * seq_len(n - event + 1L) + stats::rnorm(n - event + 1L, 0, .0005); return(base) }
  if (kind == "BREAKOUT_FAIL") { base[event:n] <- base[event - 1L] + c(.06, .01, -.02, rep(-.02, n - event - 2L)) + stats::rnorm(n - event + 1L, 0, .0003); return(base) }
  hreg121_stop("Unknown synthetic path.")
}

hreg121_synthetic_calibration <- function(contract = hreg121_contract()) {
  set.seed(contract$synthetic_seed); kinds <- c("CLEAN_UP", "CLEAN_DOWN", "RANDOM_WALK", "BREAKOUT_HOLD", "BREAKOUT_FAIL")
  rows <- vector("list", length(kinds) * contract$synthetic_paths); k <- 0L
  for (kind in kinds) for (simulation in seq_len(contract$synthetic_paths)) {
    close <- exp(hreg121_simulate_log_path(kind)); dates <- seq(as.Date("2010-01-01"), by = "day", length.out = length(close))
    bars <- data.frame(symbol = "SYN", session_date = dates, timestamp_utc = as.POSIXct(dates, tz = "UTC"), open = close, high = close, low = close, close = close, volume = 1)
    ledger <- hreg121_build_asset_ledger(bars, contract); outcomes <- hreg121_event_outcomes(ledger, contract); last <- tail(ledger, 1L)
    k <- k + 1L; rows[[k]] <- data.frame(process = kind, simulation = simulation,
      upper_fraction = mean(ledger$upper_persistent, na.rm = TRUE), lower_fraction = mean(ledger$lower_persistent, na.rm = TRUE),
      terminal_state = last$range_state, terminal_above = if (nrow(outcomes)) tail(outcomes$terminal_above, 1L) else NA,
      rapid_failure = if (nrow(outcomes)) tail(outcomes$rapid_failure, 1L) else NA, stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

hreg121_synthetic_summary <- function(x) do.call(rbind, lapply(split(x, x$process), function(z) data.frame(
  process = z$process[[1L]], paths = nrow(z), median_upper_fraction = stats::median(z$upper_fraction), median_lower_fraction = stats::median(z$lower_fraction),
  upper_terminal_fraction = mean(z$terminal_state == "UPPER_PERSISTENT"), lower_terminal_fraction = mean(z$terminal_state == "LOWER_PERSISTENT"),
  terminal_above_fraction = if (all(is.na(z$terminal_above))) NA_real_ else mean(z$terminal_above, na.rm = TRUE),
  rapid_failure_fraction = if (all(is.na(z$rapid_failure))) NA_real_ else mean(z$rapid_failure, na.rm = TRUE), stringsAsFactors = FALSE)))

hreg121_causality_audit <- function(contract = hreg121_contract()) {
  set.seed(contract$synthetic_seed + 1L); close <- exp(cumsum(stats::rnorm(500L, .0003, .012))); dates <- seq(as.Date("2010-01-01"), by = "day", length.out = length(close))
  bars <- data.frame(symbol = "TEST", session_date = dates, timestamp_utc = as.POSIXct(dates, tz = "UTC"), open = close, high = close, low = close, close = close, volume = 1)
  original <- hreg121_build_asset_ledger(bars, contract); extra <- exp(log(tail(close, 1L)) + cumsum(stats::rnorm(40L, .0003, .012))); all_close <- c(close, extra)
  ext_dates <- seq(as.Date("2010-01-01"), by = "day", length.out = length(all_close)); ext <- data.frame(symbol = "TEST", session_date = ext_dates, timestamp_utc = as.POSIXct(ext_dates, tz = "UTC"), open = all_close, high = all_close, low = all_close, close = all_close, volume = 1)
  appended <- hreg121_build_asset_ledger(ext, contract); cols <- setdiff(names(original), c("symbol", "session_date", "open", "high", "low", "close", "volume"))
  do.call(rbind, lapply(cols, function(column) { a <- original[[column]]; b <- head(appended[[column]], length(a)); same <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b); data.frame(column = column, passed = all(same), stringsAsFactors = FALSE) }))
}

hreg121_validate_ledger <- function(states, contract = hreg121_contract()) {
  required <- c("symbol", "session_date", "range_position", "upper_count5", "range_state", "upper_persistent", "new_breakout", "breakout_boundary")
  if (!is.data.frame(states) || !all(required %in% names(states))) hreg121_stop("Range-persistence ledger schema is incomplete.")
  x <- states; x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg121_stop("State dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg121_stop("Confirmation states entered the overlay.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg121_align <- function(cross_frame, states) {
  key <- paste(states$symbol, states$session_date); idx <- match(paste(cross_frame$symbol, cross_frame$session_date), key); out <- cross_frame
  cols <- c("prior_low", "prior_high", "range_position", "upper_count5", "lower_count5", "range_state", "upper_persistent", "lower_persistent", "new_breakout", "breakout_event_active", "breakout_age", "breakout_boundary", "breakout_hold_fraction_so_far")
  for (column in cols) out[[column]] <- states[[column]][idx]
  out
}

hreg121_schedule <- function(aligned_frame, start, end, policy = "UNFILTERED", eligibility_override = NULL) {
  policy <- toupper(policy); if (!policy %in% hreg121_contract()$policies) hreg121_stop("Unknown policy.")
  x <- aligned_frame; x$quality_state60 <- x$range_state; x$normalized_strength60 <- x$range_position; x$path_quality60 <- x$upper_count5 / hreg121_contract()$persistence_window; x$orderly_up_eligible <- x$upper_persistent
  if (!is.null(eligibility_override)) x$orderly_up_eligible <- eligibility_override
  mapped <- if (policy == "UNFILTERED") "UNFILTERED" else "ENTRY_ORDERLY_UP_ONLY"; hreg91_schedule(x, start, end, mapped, x$orderly_up_eligible)
}

hreg121_shifted_schedule <- function(aligned_frame, start, end, simulation_id, contract = hreg121_contract()) {
  in_block <- aligned_frame$session_date >= as.Date(start) & aligned_frame$session_date <= as.Date(end); eligibility <- aligned_frame$upper_persistent
  block <- eligibility[in_block]; finite <- !is.na(block); offset <- hreg91_shift_offset(simulation_id, sum(finite), contract$placebo_simulations)
  shifted <- block; shifted[finite] <- hreg91_rotate(block[finite], offset); eligibility[in_block] <- shifted
  out <- hreg121_schedule(aligned_frame, start, end, "ENTRY_UPPER_PERSISTENT_ONLY", eligibility); attr(out, "shift_offset") <- offset; out
}

hreg121_label_trades <- function(trades, block_frame) {
  if (!nrow(trades)) return(trades); dates <- block_frame$session_date
  trades$entry_signal_date <- as.Date(NA); trades$entry_range_position <- NA_real_; trades$entry_range_state <- NA_character_; trades$entry_upper_count5 <- NA_integer_
  for (i in seq_len(nrow(trades))) { entry_i <- match(as.Date(trades$entry_date[[i]]), dates); if (!is.na(entry_i) && entry_i > 1L) { signal_i <- entry_i - 1L; trades$entry_signal_date[[i]] <- dates[[signal_i]]; trades$entry_range_position[[i]] <- block_frame$range_position[[signal_i]]; trades$entry_range_state[[i]] <- block_frame$range_state[[signal_i]]; trades$entry_upper_count5[[i]] <- block_frame$upper_count5[[signal_i]] } }
  trades
}

hreg121_policy_panel <- hreg91_policy_panel
hreg121_compound_by_asset <- hreg91_compound_by_asset
hreg121_midrank_percentile <- hreg91_midrank_percentile
hreg121_exposure_near_ids <- hreg91_exposure_near_ids
