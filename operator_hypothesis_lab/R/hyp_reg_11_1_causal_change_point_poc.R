hreg111_stop <- function(message) stop(paste0("[HYP-REG-11.1] ", message), call. = FALSE)

hreg111_contract <- function() list(
  hypothesis_id = "HYP-REG-11.1", status = "FROZEN_FOR_DEVELOPMENT_EXECUTION", evidence_stage = "DEVELOPMENT_REUSED_WINDOW",
  as_of_timestamp = "2026-08-15 17:30:00 America/New_York", query_start = as.Date("2016-01-01"), analysis_start = as.Date("2018-01-02"),
  analysis_end = as.Date("2023-12-29"), confirmation_start = as.Date("2024-01-02"), years = 2018:2023,
  volatility_window = 20L, clip_z = 3, target_shift = .20, reference_k = .10,
  threshold_grid = seq(2, 30, by = .25), false_alarm_budget = .20, synthetic_paths = 1000L, synthetic_length = 504L,
  change_index = 252L, detection_horizon = 60L, strong_shift = .30, moderate_shift = .15, synthetic_seed = 11101L,
  refractory_sessions = 10L, eligibility_sessions = 10L, minimum_prehistory = 120L,
  fast = 8L, slow = 14L, initial_wealth = 100000, primary_bps = 5, stress_bps = 10,
  placebo_simulations = 200L, exposure_near_count = 40L, reproduction_tolerance = 1e-10,
  policies = c("UNFILTERED", "ENTRY_RECENT_POSITIVE_ONSET_ONLY")
)

hreg111_standardize_returns <- function(log_returns, window = 20L, clip_z = 3) {
  if (!is.numeric(log_returns)) hreg111_stop("Log returns must be numeric.")
  window <- as.integer(window); out <- rep(NA_real_, length(log_returns))
  if (length(log_returns) <= window) return(out)
  for (i in seq.int(window + 1L, length(log_returns))) {
    prior <- log_returns[seq.int(i - window, i - 1L)]
    sigma <- stats::sd(prior)
    if (all(is.finite(prior)) && is.finite(log_returns[[i]]) && is.finite(sigma) && sigma > 0) {
      out[[i]] <- max(-clip_z, min(clip_z, log_returns[[i]] / sigma))
    }
  }
  out
}

hreg111_cusum_stream <- function(z, threshold, contract = hreg111_contract()) {
  if (!is.numeric(z) || length(threshold) != 1L || !is.finite(threshold) || threshold <= 0) hreg111_stop("CUSUM inputs are invalid.")
  score <- rep(NA_real_, length(z)); alarm <- rep(FALSE, length(z)); eligible <- rep(FALSE, length(z)); days_since_alarm <- rep(NA_integer_, length(z))
  s <- 0; last_alarm <- NA_integer_; refractory <- 0L
  for (i in seq_along(z)) {
    if (is.finite(z[[i]])) {
      if (refractory > 0L) { s <- 0; refractory <- refractory - 1L } else {
        s <- max(0, s + z[[i]] - contract$reference_k)
        if (s >= threshold) { alarm[[i]] <- TRUE; last_alarm <- i; s <- 0; refractory <- contract$refractory_sessions - 1L }
      }
      score[[i]] <- s
      if (!is.na(last_alarm)) {
        age <- i - last_alarm; days_since_alarm[[i]] <- age
        eligible[[i]] <- age >= 0L && age < contract$eligibility_sessions
      }
    }
  }
  data.frame(cusum_score = score, positive_alarm = alarm, days_since_positive_alarm = days_since_alarm,
    recent_positive_onset_eligible = eligible, stringsAsFactors = FALSE)
}

hreg111_max_score <- function(z, contract = hreg111_contract()) {
  s <- 0; maximum <- 0
  for (value in z[is.finite(z)]) { s <- max(0, s + value - contract$reference_k); maximum <- max(maximum, s) }
  maximum
}

hreg111_simulate_returns <- function(kind, contract = hreg111_contract()) {
  n <- contract$synthetic_length; kind <- toupper(kind)
  if (kind == "GAUSSIAN_NULL") return(stats::rnorm(n))
  if (kind == "STUDENT_T5_NULL") return(stats::rt(n, df = 5) / sqrt(5 / 3))
  if (kind == "VOLATILITY_STEP_NULL") return(c(stats::rnorm(contract$change_index), stats::rnorm(n - contract$change_index, sd = 2)))
  if (kind == "POSITIVE_SHIFT_015") return(c(stats::rnorm(contract$change_index), stats::rnorm(n - contract$change_index, mean = contract$moderate_shift)))
  if (kind == "POSITIVE_SHIFT_030") return(c(stats::rnorm(contract$change_index), stats::rnorm(n - contract$change_index, mean = contract$strong_shift)))
  if (kind == "NEGATIVE_SHIFT_030") return(c(stats::rnorm(contract$change_index), stats::rnorm(n - contract$change_index, mean = -contract$strong_shift)))
  if (kind == "SINGLE_POSITIVE_JUMP") { x <- stats::rnorm(n); x[[contract$change_index + 1L]] <- x[[contract$change_index + 1L]] + 5; return(x) }
  hreg111_stop("Unknown synthetic process.")
}

hreg111_calibrate_threshold <- function(contract = hreg111_contract()) {
  set.seed(contract$synthetic_seed)
  null_kinds <- c("GAUSSIAN_NULL", "STUDENT_T5_NULL", "VOLATILITY_STEP_NULL")
  maxima <- do.call(rbind, lapply(null_kinds, function(kind) data.frame(process = kind, simulation = seq_len(contract$synthetic_paths),
    maximum_score = replicate(contract$synthetic_paths, {
      r <- hreg111_simulate_returns(kind, contract); z <- hreg111_standardize_returns(r, contract$volatility_window, contract$clip_z); hreg111_max_score(z, contract)
    }), stringsAsFactors = FALSE)))
  rates <- do.call(rbind, lapply(contract$threshold_grid, function(h) do.call(rbind, lapply(split(maxima, maxima$process), function(x)
    data.frame(threshold = h, process = x$process[[1L]], false_alarm_probability = mean(x$maximum_score >= h), stringsAsFactors = FALSE)))))
  by_h <- aggregate(false_alarm_probability ~ threshold, rates, max)
  valid <- by_h$threshold[by_h$false_alarm_probability <= contract$false_alarm_budget]
  if (!length(valid)) hreg111_stop("Frozen threshold grid cannot satisfy the false-alarm budget.")
  threshold <- min(valid)
  list(threshold = threshold, maxima = maxima, rates = rates[rates$threshold == threshold, , drop = FALSE])
}

hreg111_shift_calibration <- function(threshold, contract = hreg111_contract()) {
  set.seed(contract$synthetic_seed + 1L)
  kinds <- c("POSITIVE_SHIFT_015", "POSITIVE_SHIFT_030", "NEGATIVE_SHIFT_030", "SINGLE_POSITIVE_JUMP")
  rows <- vector("list", length(kinds) * contract$synthetic_paths); k <- 0L
  for (kind in kinds) for (simulation in seq_len(contract$synthetic_paths)) {
    r <- hreg111_simulate_returns(kind, contract); z <- hreg111_standardize_returns(r, contract$volatility_window, contract$clip_z)
    stream <- hreg111_cusum_stream(z, threshold, contract); alarm_rows <- which(stream$positive_alarm)
    post <- alarm_rows[alarm_rows > contract$change_index]; first_post <- if (length(post)) min(post) else NA_integer_
    k <- k + 1L; rows[[k]] <- data.frame(process = kind, simulation = simulation,
      prechange_alarm = any(alarm_rows <= contract$change_index), detection_delay = if (is.na(first_post)) NA_integer_ else first_post - contract$change_index,
      detected_within_horizon = !is.na(first_post) && first_post - contract$change_index <= contract$detection_horizon, stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

hreg111_shift_summary <- function(x) do.call(rbind, lapply(split(x, x$process), function(z) data.frame(
  process = z$process[[1L]], paths = nrow(z), prechange_alarm_probability = mean(z$prechange_alarm),
  detection_probability_60 = mean(z$detected_within_horizon), median_detection_delay = if (any(z$detected_within_horizon)) stats::median(z$detection_delay[z$detected_within_horizon]) else NA_real_, stringsAsFactors = FALSE)))

hreg111_build_asset_ledger <- function(bars, threshold, contract = hreg111_contract()) {
  x <- hreg91_assert_bars(bars, contract); if (length(unique(x$symbol)) != 1L) hreg111_stop("Asset ledger requires one symbol.")
  returns <- c(NA_real_, diff(log(x$close))); z <- hreg111_standardize_returns(returns, contract$volatility_window, contract$clip_z)
  stream <- hreg111_cusum_stream(z, threshold, contract)
  data.frame(symbol = x$symbol, session_date = x$session_date, open = x$open, high = x$high, low = x$low, close = x$close, volume = x$volume,
    log_return = returns, trailing_standardized_return = z, cusum_score = stream$cusum_score, positive_alarm = stream$positive_alarm,
    days_since_positive_alarm = stream$days_since_positive_alarm, recent_positive_onset_eligible = stream$recent_positive_onset_eligible, stringsAsFactors = FALSE)
}

hreg111_build_ledger <- function(bars, threshold, contract = hreg111_contract()) {
  x <- hreg91_assert_bars(bars, contract); rows <- lapply(split(x, x$symbol), hreg111_build_asset_ledger, threshold = threshold, contract = contract)
  out <- do.call(rbind, rows); rownames(out) <- NULL; out[order(out$symbol, out$session_date), , drop = FALSE]
}

hreg111_state_diagnostics <- function(ledger, cross_frames = NULL, contract = hreg111_contract()) {
  x <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end, , drop = FALSE]
  do.call(rbind, lapply(split(x, x$symbol), function(z) {
    eligible_crosses <- NA_integer_
    if (!is.null(cross_frames) && z$symbol[[1L]] %in% names(cross_frames)) {
      q <- cross_frames[[z$symbol[[1L]]]]; idx <- match(q$session_date, z$session_date); eligible_crosses <- sum(q$cross_up & z$recent_positive_onset_eligible[idx], na.rm = TRUE)
    }
    data.frame(symbol = z$symbol[[1L]], observations = nrow(z), alarms = sum(z$positive_alarm), alarms_per_year = sum(z$positive_alarm) / length(contract$years),
      eligible_fraction = mean(z$recent_positive_onset_eligible), median_alarm_spacing = { a <- which(z$positive_alarm); if (length(a) >= 2L) stats::median(diff(a)) else NA_real_ },
      eligible_crosses = eligible_crosses, stringsAsFactors = FALSE)
  }))
}

hreg111_causality_audit <- function(threshold, contract = hreg111_contract()) {
  set.seed(contract$synthetic_seed + 2L); close <- exp(cumsum(stats::rnorm(900L, .0003, .012)))
  bars <- data.frame(symbol = "TEST", session_date = seq(as.Date("2010-01-01"), by = "day", length.out = length(close)), timestamp_utc = as.POSIXct(seq(as.Date("2010-01-01"), by = "day", length.out = length(close)), tz = "UTC"), open = close, high = close, low = close, close = close, volume = 1)
  original <- hreg111_build_asset_ledger(bars, threshold, contract)
  extra <- exp(log(tail(close, 1L)) + cumsum(stats::rnorm(50L, .0003, .012))); all_close <- c(close, extra)
  appended <- bars[rep(nrow(bars), length(all_close)), ]; appended$session_date <- seq(as.Date("2010-01-01"), by = "day", length.out = length(all_close)); appended$timestamp_utc <- as.POSIXct(appended$session_date, tz = "UTC"); appended$open <- appended$high <- appended$low <- appended$close <- all_close
  extended <- hreg111_build_asset_ledger(appended, threshold, contract); cols <- c("trailing_standardized_return", "cusum_score", "positive_alarm", "days_since_positive_alarm", "recent_positive_onset_eligible")
  do.call(rbind, lapply(cols, function(column) { a <- original[[column]]; b <- head(extended[[column]], length(a)); same <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b); data.frame(column = column, passed = all(same), stringsAsFactors = FALSE) }))
}

hreg111_validate_ledger <- function(states, contract = hreg111_contract()) {
  required <- c("symbol", "session_date", "trailing_standardized_return", "cusum_score", "positive_alarm", "days_since_positive_alarm", "recent_positive_onset_eligible")
  if (!is.data.frame(states) || !all(required %in% names(states))) hreg111_stop("Change-point ledger schema is incomplete.")
  x <- states; x$session_date <- as.Date(x$session_date); x$positive_alarm <- as.logical(x$positive_alarm); x$recent_positive_onset_eligible <- as.logical(x$recent_positive_onset_eligible)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg111_stop("State dates are invalid or duplicated.")
  if (any(x$session_date >= contract$confirmation_start)) hreg111_stop("Confirmation states entered the overlay.")
  x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg111_align <- function(cross_frame, states) {
  key <- paste(states$symbol, states$session_date); idx <- match(paste(cross_frame$symbol, cross_frame$session_date), key); out <- cross_frame
  for (column in c("trailing_standardized_return", "cusum_score", "positive_alarm", "days_since_positive_alarm", "recent_positive_onset_eligible")) out[[column]] <- states[[column]][idx]
  out
}

hreg111_schedule <- function(aligned_frame, start, end, policy = "UNFILTERED", eligibility_override = NULL) {
  policy <- toupper(policy); if (!policy %in% hreg111_contract()$policies) hreg111_stop("Unknown policy.")
  x <- aligned_frame; x$quality_state60 <- ifelse(x$recent_positive_onset_eligible, "RECENT_POSITIVE_ONSET", "OTHER")
  x$normalized_strength60 <- x$cusum_score; x$path_quality60 <- x$days_since_positive_alarm; x$orderly_up_eligible <- x$recent_positive_onset_eligible
  if (!is.null(eligibility_override)) x$orderly_up_eligible <- eligibility_override
  mapped <- if (policy == "UNFILTERED") "UNFILTERED" else "ENTRY_ORDERLY_UP_ONLY"
  hreg91_schedule(x, start, end, mapped, x$orderly_up_eligible)
}

hreg111_shifted_schedule <- function(aligned_frame, start, end, simulation_id, contract = hreg111_contract()) {
  in_block <- aligned_frame$session_date >= as.Date(start) & aligned_frame$session_date <= as.Date(end); eligibility <- aligned_frame$recent_positive_onset_eligible
  block <- eligibility[in_block]; finite <- !is.na(block); offset <- hreg91_shift_offset(simulation_id, sum(finite), contract$placebo_simulations)
  shifted <- block; shifted[finite] <- hreg91_rotate(block[finite], offset); eligibility[in_block] <- shifted
  out <- hreg111_schedule(aligned_frame, start, end, "ENTRY_RECENT_POSITIVE_ONSET_ONLY", eligibility); attr(out, "shift_offset") <- offset; out
}

hreg111_label_trades <- function(trades, block_frame) {
  if (!nrow(trades)) return(trades); dates <- block_frame$session_date
  trades$entry_signal_date <- as.Date(NA); trades$entry_cusum_score <- NA_real_; trades$entry_days_since_alarm <- NA_integer_; trades$entry_eligible <- NA
  for (i in seq_len(nrow(trades))) { entry_i <- match(as.Date(trades$entry_date[[i]]), dates); if (!is.na(entry_i) && entry_i > 1L) { signal_i <- entry_i - 1L; trades$entry_signal_date[[i]] <- dates[[signal_i]]; trades$entry_cusum_score[[i]] <- block_frame$cusum_score[[signal_i]]; trades$entry_days_since_alarm[[i]] <- block_frame$days_since_positive_alarm[[signal_i]]; trades$entry_eligible[[i]] <- block_frame$recent_positive_onset_eligible[[signal_i]] } }
  trades
}

hreg111_policy_panel <- hreg91_policy_panel
hreg111_compound_by_asset <- hreg91_compound_by_asset
hreg111_midrank_percentile <- hreg91_midrank_percentile
hreg111_exposure_near_ids <- hreg91_exposure_near_ids
