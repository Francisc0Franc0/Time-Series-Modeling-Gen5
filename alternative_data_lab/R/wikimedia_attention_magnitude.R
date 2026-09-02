# Magnitude-response helpers for the first causal Wikimedia attention follow-up.

adwm_contract <- function() {
  x <- adwl_contract()
  x$hypothesis_id <- "ADL-WIKI-03.1"
  x$parent_id <- "ADL-WIKI-02.1"
  x$authority <- "DESCRIPTIVE_MAGNITUDE_SIGNAL_POC_ONLY"
  x$primary_outcome <- "absolute_next_open_to_open_log_return"
  x$diagnostic_outcome <- "entry_session_high_low_log_range"
  x$descriptive_attention_bins <- 10L
  x
}

adwm_as_lead_contract <- function(contract) {
  x <- contract
  x$hypothesis_id <- "ADL-WIKI-02.1"
  x$parent_id <- "ADL-WIKI-01.1"
  x$authority <- "DESCRIPTIVE_LEADING_SIGNAL_POC_ONLY"
  x[c("primary_outcome", "diagnostic_outcome", "descriptive_attention_bins")] <- NULL
  adwl_validate_contract(x)
}

adwm_validate_contract <- function(contract = adwm_contract()) {
  required <- c("primary_outcome", "diagnostic_outcome", "descriptive_attention_bins")
  if (!all(required %in% names(contract))) adwl_stop("Magnitude contract is missing required fields.")
  if (!identical(contract$hypothesis_id, "ADL-WIKI-03.1") ||
      !identical(contract$parent_id, "ADL-WIKI-02.1") ||
      !identical(contract$authority, "DESCRIPTIVE_MAGNITUDE_SIGNAL_POC_ONLY")) {
    adwl_stop("Magnitude contract identity or authority changed unexpectedly.")
  }
  if (!identical(contract$primary_outcome, "absolute_next_open_to_open_log_return") ||
      !identical(contract$diagnostic_outcome, "entry_session_high_low_log_range") ||
      !identical(as.integer(contract$descriptive_attention_bins), 10L)) {
    adwl_stop("Magnitude outcomes or descriptive bin count changed unexpectedly.")
  }
  adwm_as_lead_contract(contract)
  contract$descriptive_attention_bins <- as.integer(contract$descriptive_attention_bins)
  contract
}

adwm_attention_features <- function(daily, contract = adwm_contract()) {
  contract <- adwm_validate_contract(contract)
  adwl_attention_features(daily, adwm_as_lead_contract(contract))
}

adwm_market_bars <- function(bars, contract = adwm_contract()) {
  contract <- adwm_validate_contract(contract)
  lead_contract <- adwm_as_lead_contract(contract)
  base <- adwl_validate_bars(bars, lead_contract)
  required <- c("symbol", "session_date", "high", "low")
  if (!all(required %in% names(bars))) adwl_stop("GME bars lack high/low fields for magnitude diagnostics.")
  hl <- bars[bars$symbol == contract$symbol, required, drop = FALSE]
  hl$session_date <- as.Date(hl$session_date)
  hl <- hl[hl$session_date <= contract$market_end, , drop = FALSE]
  if (anyDuplicated(hl$session_date) || anyNA(hl$session_date)) {
    adwl_stop("GME high/low bar dates are missing or duplicated.")
  }
  out <- merge(base, hl[c("session_date", "high", "low")], by = "session_date", all.x = TRUE, sort = TRUE)
  if (any(!is.finite(out$high) | !is.finite(out$low) | out$low <= 0 | out$high < out$low)) {
    adwl_stop("GME bars contain invalid adjusted high/low prices.")
  }
  out
}

adwm_reaction_panel <- function(features, bars, contract = adwm_contract()) {
  contract <- adwm_validate_contract(contract)
  reaction <- adwl_reaction_panel(features, bars, adwm_as_lead_contract(contract))
  reaction$completed_abs_close_return <- abs(reaction$completed_close_return)
  reaction
}

adwm_forward_panel <- function(features, bars, contract = adwm_contract()) {
  contract <- adwm_validate_contract(contract)
  lead_contract <- adwm_as_lead_contract(contract)
  forward <- adwl_forward_panel(features, bars, lead_contract)
  market <- adwm_market_bars(bars, contract)
  lookup <- match(forward$entry_session, market$session_date)
  if (anyNA(lookup)) adwl_stop("Magnitude panel could not match entry-session high/low bars.")
  forward$entry_high <- market$high[lookup]
  forward$entry_low <- market$low[lookup]
  forward$future_abs_open_log_return <- abs(forward$future_open_log_return)
  forward$entry_session_log_range <- log(forward$entry_high / forward$entry_low)
  if (any(!is.finite(forward$future_abs_open_log_return)) ||
      any(!is.finite(forward$entry_session_log_range) | forward$entry_session_log_range < 0)) {
    adwl_stop("Magnitude outcomes are invalid.")
  }
  forward
}

adwm_attention_bin_summary <- function(panel, bins = 10L) {
  required <- c("attention_log_ratio", "future_abs_open_log_return", "entry_session_log_range")
  if (!all(required %in% names(panel))) adwl_stop("Magnitude panel lacks required binning fields.")
  bins <- as.integer(bins)
  if (is.na(bins) || bins < 2L) adwl_stop("At least two descriptive attention bins are required.")
  keep <- is.finite(panel$attention_log_ratio) & is.finite(panel$future_abs_open_log_return) &
    is.finite(panel$entry_session_log_range)
  x <- panel[keep, required, drop = FALSE]
  if (nrow(x) < bins) adwl_stop("Not enough observations for the frozen descriptive bins.")
  ranks <- rank(x$attention_log_ratio, ties.method = "first")
  x$attention_bin <- pmin(bins, ceiling(ranks * bins / nrow(x)))
  rows <- lapply(seq_len(bins), function(bin_id) {
    z <- x[x$attention_bin == bin_id, , drop = FALSE]
    data.frame(
      attention_bin = bin_id,
      observations = nrow(z),
      min_attention_log_ratio = min(z$attention_log_ratio),
      median_attention_log_ratio = stats::median(z$attention_log_ratio),
      max_attention_log_ratio = max(z$attention_log_ratio),
      mean_abs_open_log_return = mean(z$future_abs_open_log_return),
      median_abs_open_log_return = stats::median(z$future_abs_open_log_return),
      mean_entry_session_log_range = mean(z$entry_session_log_range),
      median_entry_session_log_range = stats::median(z$entry_session_log_range),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

adwm_readout_status <- function(summary_table) {
  primary <- summary_table[summary_table$relationship == "causal_attention_to_absolute_open_return", , drop = FALSE]
  diagnostic <- summary_table[summary_table$relationship == "causal_attention_to_entry_session_range", , drop = FALSE]
  if (nrow(primary) != 1L || nrow(diagnostic) != 1L) {
    adwl_stop("Magnitude summary lacks the frozen primary or diagnostic relationship.")
  }
  if (is.finite(primary$spearman) && is.finite(diagnostic$spearman) &&
      primary$spearman > 0.05 && diagnostic$spearman > 0.05) {
    "DESCRIPTIVE_MAGNITUDE_CLUE_REQUIRES_FRESH_CONFIRMATION"
  } else {
    "STOP_NO_OBVIOUS_ONE_SESSION_MAGNITUDE_LEAD"
  }
}
