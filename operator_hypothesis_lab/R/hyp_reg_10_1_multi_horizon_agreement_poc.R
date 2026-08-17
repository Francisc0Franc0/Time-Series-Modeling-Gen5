hreg101_stop <- function(message) stop(paste0("[HYP-REG-10.1] ", message), call. = FALSE)

hreg101_contract <- function() list(
  hypothesis_id = "HYP-REG-10.1", status = "FROZEN_FOR_DEVELOPMENT_EXECUTION", evidence_stage = "DEVELOPMENT_REUSED_WINDOW",
  as_of_timestamp = "2026-08-15 17:30:00 America/New_York", query_start = as.Date("2016-01-01"), analysis_start = as.Date("2018-01-02"),
  analysis_end = as.Date("2023-12-29"), confirmation_start = as.Date("2024-01-02"), years = 2018:2023,
  horizons = c(20L, 60L, 120L), preferred_prehistory = 252L, minimum_prehistory = 120L, synthetic_paths = 500L, synthetic_seed = 10101L,
  fast = 8L, slow = 14L, initial_wealth = 100000, primary_bps = 5, stress_bps = 10, placebo_simulations = 200L,
  exposure_near_count = 40L, reproduction_tolerance = 1e-10, policies = c("UNFILTERED", "ENTRY_FULL_UP_ONLY")
)

hreg101_normalized_return <- function(log_price) {
  if (!is.numeric(log_price) || length(log_price) < 3L || any(!is.finite(log_price))) hreg101_stop("Window log prices must be finite.")
  h <- length(log_price) - 1L; volatility <- stats::sd(diff(log_price)); displacement <- tail(log_price, 1L) - head(log_price, 1L)
  normalized <- if (is.finite(volatility) && volatility > 0) displacement / (volatility * sqrt(h)) else NA_real_
  c(displacement = displacement, realized_volatility = volatility, normalized_return = normalized, direction = if (is.finite(normalized)) sign(normalized) else NA_real_)
}

hreg101_rolling_horizon <- function(close, horizon) {
  horizon <- as.integer(horizon); out <- matrix(NA_real_, nrow = length(close), ncol = 4L, dimnames = list(NULL, c("displacement", "realized_volatility", "normalized_return", "direction")))
  if (!is.numeric(close) || any(!is.finite(close)) || any(close <= 0)) hreg101_stop("Close must contain positive finite values.")
  if (length(close) <= horizon) return(as.data.frame(out)); log_close <- log(close)
  for (i in seq.int(horizon + 1L, length(close))) out[i, ] <- hreg101_normalized_return(log_close[seq.int(i - horizon, i)])
  as.data.frame(out)
}

hreg101_classify <- function(s20, s60, s120) {
  n <- max(length(s20), length(s60), length(s120)); s20 <- rep_len(s20, n); s60 <- rep_len(s60, n); s120 <- rep_len(s120, n); out <- rep(NA_character_, n)
  finite <- is.finite(s20) & is.finite(s60) & is.finite(s120); out[finite] <- "MIXED"
  out[finite & s20 > 0 & s60 > 0 & s120 > 0] <- "FULL_UP"; out[finite & s20 < 0 & s60 < 0 & s120 < 0] <- "FULL_DOWN"
  out[finite & s20 < 0 & s60 > 0 & s120 > 0] <- "SHORT_OPPOSES_UP"; out[finite & s20 > 0 & s60 < 0 & s120 < 0] <- "SHORT_OPPOSES_DOWN"; out
}

hreg101_transition_event <- function(state, s60, s120) {
  out <- rep("NONE", length(state)); out[is.na(state)] <- NA_character_
  if (length(state) < 2L) return(out)
  for (i in 2:length(state)) {
    stable_up <- is.finite(s60[[i]]) && is.finite(s120[[i]]) && is.finite(s60[[i - 1L]]) && is.finite(s120[[i - 1L]]) && s60[[i]] > 0 && s120[[i]] > 0 && s60[[i - 1L]] > 0 && s120[[i - 1L]] > 0
    stable_down <- is.finite(s60[[i]]) && is.finite(s120[[i]]) && is.finite(s60[[i - 1L]]) && is.finite(s120[[i - 1L]]) && s60[[i]] < 0 && s120[[i]] < 0 && s60[[i - 1L]] < 0 && s120[[i - 1L]] < 0
    if (stable_up && identical(state[[i - 1L]], "SHORT_OPPOSES_UP") && identical(state[[i]], "FULL_UP")) out[[i]] <- "SHORT_JOINS_UP"
    if (stable_down && identical(state[[i - 1L]], "SHORT_OPPOSES_DOWN") && identical(state[[i]], "FULL_DOWN")) out[[i]] <- "SHORT_JOINS_DOWN"
  }
  out
}

hreg101_build_asset_ledger <- function(bars, contract = hreg101_contract()) {
  x <- hreg91_assert_bars(bars, contract); if (length(unique(x$symbol)) != 1L) hreg101_stop("Asset ledger requires one symbol.")
  m <- lapply(contract$horizons, function(h) hreg101_rolling_horizon(x$close, h)); names(m) <- paste0("h", contract$horizons)
  s20 <- m$h20$direction; s60 <- m$h60$direction; s120 <- m$h120$direction; state <- hreg101_classify(s20, s60, s120)
  positive_count <- rowSums(cbind(s20 > 0, s60 > 0, s120 > 0), na.rm = FALSE); negative_count <- rowSums(cbind(s20 < 0, s60 < 0, s120 < 0), na.rm = FALSE)
  data.frame(symbol = x$symbol, session_date = x$session_date, open = x$open, high = x$high, low = x$low, close = x$close, volume = x$volume,
    normalized_return20 = m$h20$normalized_return, normalized_return60 = m$h60$normalized_return, normalized_return120 = m$h120$normalized_return,
    sign20 = s20, sign60 = s60, sign120 = s120, agreement_score = (s20 + s60 + s120) / 3,
    agreement_fraction = pmax(positive_count, negative_count) / 3, agreement_state = state, transition_event = hreg101_transition_event(state, s60, s120),
    full_up_eligible = state == "FULL_UP", stringsAsFactors = FALSE)
}

hreg101_build_ledger <- function(bars, contract = hreg101_contract()) {
  x <- hreg91_assert_bars(bars, contract); rows <- lapply(split(x, x$symbol), hreg101_build_asset_ledger, contract = contract); out <- do.call(rbind, rows); rownames(out) <- NULL; out[order(out$symbol, out$session_date), , drop = FALSE]
}

hreg101_state_diagnostics <- function(ledger, contract = hreg101_contract()) {
  x <- ledger[ledger$session_date >= contract$analysis_start & ledger$session_date <= contract$analysis_end & !is.na(ledger$agreement_state), , drop = FALSE]
  states <- c("FULL_DOWN", "SHORT_OPPOSES_DOWN", "MIXED", "SHORT_OPPOSES_UP", "FULL_UP")
  do.call(rbind, lapply(split(x, x$symbol), function(z) { counts <- table(factor(z$agreement_state, levels = states)); data.frame(symbol = z$symbol[[1L]], observations = nrow(z),
    full_down_fraction = counts[["FULL_DOWN"]] / nrow(z), short_opposes_down_fraction = counts[["SHORT_OPPOSES_DOWN"]] / nrow(z), mixed_fraction = counts[["MIXED"]] / nrow(z),
    short_opposes_up_fraction = counts[["SHORT_OPPOSES_UP"]] / nrow(z), full_up_fraction = counts[["FULL_UP"]] / nrow(z),
    eligible_fraction = mean(z$full_up_eligible), short_joins_up = sum(z$transition_event == "SHORT_JOINS_UP", na.rm = TRUE), short_joins_down = sum(z$transition_event == "SHORT_JOINS_DOWN", na.rm = TRUE),
    sign20_60_agreement = mean(z$sign20 == z$sign60), sign60_120_agreement = mean(z$sign60 == z$sign120), stringsAsFactors = FALSE) }))
}

hreg101_simulate_log_path <- function(kind, n = 121L) {
  kind <- toupper(kind); if (n < 121L) hreg101_stop("Synthetic path requires at least 121 observations."); t <- seq_len(n)
  if (kind == "CLEAN_UP") return(.0025 * t + stats::rnorm(n, 0, .0003))
  if (kind == "CLEAN_DOWN") return(-.0025 * t + stats::rnorm(n, 0, .0003))
  if (kind == "SHORT_OPPOSES_UP") return(c(.003 * seq_len(n - 20L), .003 * (n - 20L) - .004 * seq_len(20L)) + stats::rnorm(n, 0, .0003))
  if (kind == "SHORT_OPPOSES_DOWN") return(c(-.003 * seq_len(n - 20L), -.003 * (n - 20L) + .004 * seq_len(20L)) + stats::rnorm(n, 0, .0003))
  if (kind == "RANDOM_WALK") return(cumsum(stats::rnorm(n, 0, .012)))
  hreg101_stop("Unknown synthetic path.")
}

hreg101_last_metrics <- function(log_path, contract = hreg101_contract()) {
  values <- vapply(contract$horizons, function(h) hreg101_normalized_return(tail(log_path, h + 1L))[["normalized_return"]], numeric(1)); signs <- sign(values); names(values) <- paste0("z", contract$horizons)
  c(values, state = hreg101_classify(signs[[1L]], signs[[2L]], signs[[3L]]))
}

hreg101_synthetic_calibration <- function(contract = hreg101_contract()) {
  set.seed(contract$synthetic_seed); kinds <- c("CLEAN_UP", "CLEAN_DOWN", "SHORT_OPPOSES_UP", "SHORT_OPPOSES_DOWN", "RANDOM_WALK"); rows <- vector("list", length(kinds) * contract$synthetic_paths); k <- 0L
  for (kind in kinds) for (simulation in seq_len(contract$synthetic_paths)) { metric <- hreg101_last_metrics(hreg101_simulate_log_path(kind), contract); k <- k + 1L; rows[[k]] <- data.frame(process = kind, simulation = simulation, z20 = as.numeric(metric[["z20"]]), z60 = as.numeric(metric[["z60"]]), z120 = as.numeric(metric[["z120"]]), state = as.character(metric[["state"]]), stringsAsFactors = FALSE) }
  do.call(rbind, rows)
}

hreg101_synthetic_summary <- function(x) do.call(rbind, lapply(split(x, x$process), function(z) { target <- switch(z$process[[1L]], CLEAN_UP = "FULL_UP", CLEAN_DOWN = "FULL_DOWN", SHORT_OPPOSES_UP = "SHORT_OPPOSES_UP", SHORT_OPPOSES_DOWN = "SHORT_OPPOSES_DOWN", RANDOM_WALK = NA_character_); data.frame(process = z$process[[1L]], paths = nrow(z), median_z20 = stats::median(z$z20), median_z60 = stats::median(z$z60), median_z120 = stats::median(z$z120), target_state = target, target_state_fraction = if (is.na(target)) NA_real_ else mean(z$state == target), full_agreement_fraction = mean(z$state %in% c("FULL_UP", "FULL_DOWN")), stringsAsFactors = FALSE) }))

hreg101_scale_invariance_audit <- function(contract = hreg101_contract()) {
  set.seed(contract$synthetic_seed + 1L); log_path <- hreg101_simulate_log_path("RANDOM_WALK"); base <- hreg101_last_metrics(log_path, contract); scaled <- hreg101_last_metrics(log_path + log(7), contract)
  data.frame(metric = paste0("z", contract$horizons), absolute_difference = abs(as.numeric(base[paste0("z", contract$horizons)]) - as.numeric(scaled[paste0("z", contract$horizons)])), stringsAsFactors = FALSE)
}

hreg101_causality_audit <- function(contract = hreg101_contract()) {
  set.seed(contract$synthetic_seed + 2L); close <- exp(cumsum(stats::rnorm(900L, .0003, .012))); original <- lapply(contract$horizons, function(h) hreg101_rolling_horizon(close, h)); appended_close <- c(close, exp(log(tail(close, 1L)) + cumsum(stats::rnorm(50L, .0003, .012)))); appended <- lapply(contract$horizons, function(h) hreg101_rolling_horizon(appended_close, h))
  rows <- list(); k <- 0L; for (j in seq_along(contract$horizons)) for (column in names(original[[j]])) { a <- original[[j]][[column]]; b <- head(appended[[j]][[column]], length(a)); keep <- is.finite(a) & is.finite(b); k <- k + 1L; rows[[k]] <- data.frame(horizon = contract$horizons[[j]], column = column, maximum_append_difference = if (any(keep)) max(abs(a[keep] - b[keep])) else NA_real_, stringsAsFactors = FALSE) }
  out <- do.call(rbind, rows); out$passed <- is.finite(out$maximum_append_difference) & out$maximum_append_difference == 0; out
}

hreg101_validate_ledger <- function(states, contract = hreg101_contract()) {
  required <- c("symbol", "session_date", "normalized_return20", "normalized_return60", "normalized_return120", "sign20", "sign60", "sign120", "agreement_score", "agreement_fraction", "agreement_state", "transition_event", "full_up_eligible")
  if (!is.data.frame(states) || !all(required %in% names(states))) hreg101_stop("Agreement-ledger schema is incomplete."); x <- states; x$session_date <- as.Date(x$session_date)
  if (any(is.na(x$session_date)) || anyDuplicated(x[c("symbol", "session_date")])) hreg101_stop("State dates are invalid or duplicated."); if (any(x$session_date >= contract$confirmation_start)) hreg101_stop("Confirmation states entered the overlay.")
  allowed <- c("FULL_UP", "FULL_DOWN", "SHORT_OPPOSES_UP", "SHORT_OPPOSES_DOWN", "MIXED"); if (any(!is.na(x$agreement_state) & !x$agreement_state %in% allowed)) hreg101_stop("Unexpected agreement state."); x[order(x$symbol, x$session_date), , drop = FALSE]
}

hreg101_align <- function(cross_frame, states) { key <- paste(states$symbol, states$session_date); idx <- match(paste(cross_frame$symbol, cross_frame$session_date), key); out <- cross_frame; for (column in c("normalized_return20", "normalized_return60", "normalized_return120", "sign20", "sign60", "sign120", "agreement_score", "agreement_fraction", "agreement_state", "transition_event", "full_up_eligible")) out[[column]] <- states[[column]][idx]; out }

hreg101_schedule <- function(aligned_frame, start, end, policy = "UNFILTERED", eligibility_override = NULL) {
  policy <- toupper(policy); if (!policy %in% hreg101_contract()$policies) hreg101_stop("Unknown policy."); x <- aligned_frame; x$quality_state60 <- x$agreement_state; x$normalized_strength60 <- x$agreement_score; x$path_quality60 <- x$agreement_fraction; x$orderly_up_eligible <- x$full_up_eligible
  mapped <- if (policy == "UNFILTERED") "UNFILTERED" else "ENTRY_ORDERLY_UP_ONLY"; if (!is.null(eligibility_override)) x$orderly_up_eligible <- eligibility_override
  hreg91_schedule(x, start, end, mapped, x$orderly_up_eligible)
}

hreg101_shifted_schedule <- function(aligned_frame, start, end, simulation_id, contract = hreg101_contract()) {
  in_block <- aligned_frame$session_date >= as.Date(start) & aligned_frame$session_date <= as.Date(end); eligibility <- aligned_frame$full_up_eligible; block <- eligibility[in_block]; finite <- !is.na(block); offset <- hreg91_shift_offset(simulation_id, sum(finite), contract$placebo_simulations)
  shifted <- block; shifted[finite] <- hreg91_rotate(block[finite], offset); eligibility[in_block] <- shifted; out <- hreg101_schedule(aligned_frame, start, end, "ENTRY_FULL_UP_ONLY", eligibility); attr(out, "shift_offset") <- offset; out
}

hreg101_label_trades <- function(trades, block_frame) {
  if (!nrow(trades)) return(trades); dates <- block_frame$session_date; trades$entry_signal_date <- as.Date(NA); trades$entry_state <- NA_character_; trades$entry_z20 <- NA_real_; trades$entry_z60 <- NA_real_; trades$entry_z120 <- NA_real_; trades$entry_eligible <- NA
  for (i in seq_len(nrow(trades))) { entry_i <- match(as.Date(trades$entry_date[[i]]), dates); if (!is.na(entry_i) && entry_i > 1L) { signal_i <- entry_i - 1L; trades$entry_signal_date[[i]] <- dates[[signal_i]]; trades$entry_state[[i]] <- block_frame$agreement_state[[signal_i]]; trades$entry_z20[[i]] <- block_frame$normalized_return20[[signal_i]]; trades$entry_z60[[i]] <- block_frame$normalized_return60[[signal_i]]; trades$entry_z120[[i]] <- block_frame$normalized_return120[[signal_i]]; trades$entry_eligible[[i]] <- block_frame$full_up_eligible[[signal_i]] } }; trades
}

hreg101_policy_panel <- hreg91_policy_panel
hreg101_compound_by_asset <- hreg91_compound_by_asset
hreg101_midrank_percentile <- hreg91_midrank_percentile
hreg101_exposure_near_ids <- hreg91_exposure_near_ids
