rgavv_stop <- function(message) {
  stop(paste0("[RETURN-GEOMETRY-VOLUME-VETO] ", message), call. = FALSE)
}

rgavv_contract <- function() {
  list(
    study_id = "RETURN_GEOMETRY_ABNORMAL_VOLUME_VETO_01",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    event_sessions = 20L,
    baseline_sessions = 126L,
    percentile_history = 504L,
    minimum_percentile_history = 252L,
    veto_percentile = 0.60,
    minimum_retained_share = 0.50,
    minimum_negative_asset_breadth = 0.60,
    minimum_negative_sectors = 7L,
    expected_assets = 129L,
    expected_core_assets = 88L,
    expected_sectors = 11L
  )
}

rgavv_validate_contract <- function(contract = rgavv_contract()) {
  if (contract$analysis_end > as.Date("2023-12-29")) {
    rgavv_stop("Post-2023 outcomes are sealed.")
  }
  if (contract$event_sessions != 20L || contract$baseline_sessions != 126L ||
      contract$percentile_history != 504L ||
      contract$minimum_percentile_history != 252L ||
      !isTRUE(all.equal(contract$veto_percentile, 0.60))) {
    rgavv_stop("The frozen abnormal-volume veto contract changed.")
  }
  contract
}

rgavv_daily_abnormal_volume <- function(ledger, contract = rgavv_contract()) {
  contract <- rgavv_validate_contract(contract)
  x <- rgafa_prepare_ledger(ledger)
  out <- rep(NA_real_, nrow(x))
  for (i in seq_len(nrow(x))) {
    event_lo <- i - contract$event_sessions + 1L
    pre_hi <- i - contract$event_sessions
    pre_lo <- pre_hi - contract$baseline_sessions + 1L
    if (event_lo < 1L || pre_lo < 1L) next
    event_dv <- stats::median(x$dollar_volume[event_lo:i], na.rm = TRUE)
    baseline_dv <- stats::median(x$dollar_volume[pre_lo:pre_hi], na.rm = TRUE)
    if (is.finite(event_dv) && is.finite(baseline_dv) &&
        event_dv > 0 && baseline_dv > 0) {
      out[[i]] <- log(event_dv / baseline_dv)
    }
  }
  pct <- rgafa_causal_percentile(
    out, history = contract$percentile_history,
    minimum = contract$minimum_percentile_history
  )
  data.frame(
    symbol = x$symbol,
    session_date = x$session_date,
    abnormal_dollar_volume = out,
    abnormal_volume_causal_percentile = pct$percentile,
    abnormal_volume_history_observations = pct$history_observations,
    abnormal_volume_veto = ifelse(
      is.finite(pct$percentile),
      pct$percentile >= contract$veto_percentile,
      NA
    ),
    stringsAsFactors = FALSE
  )
}

rgavv_attach_veto <- function(events, state_panel,
                              contract = rgavv_contract()) {
  contract <- rgavv_validate_contract(contract)
  required_events <- c("symbol", "anchor_session", "abnormal_dollar_volume")
  required_state <- c(
    "symbol", "session_date", "abnormal_dollar_volume",
    "abnormal_volume_causal_percentile",
    "abnormal_volume_history_observations", "abnormal_volume_veto"
  )
  if (length(setdiff(required_events, names(events))) ||
      length(setdiff(required_state, names(state_panel)))) {
    rgavv_stop("Events or state panel are missing required columns.")
  }
  key_events <- paste(events$symbol, as.Date(events$anchor_session))
  key_state <- paste(state_panel$symbol, as.Date(state_panel$session_date))
  lookup <- match(key_events, key_state)
  if (anyNA(lookup)) rgavv_stop("One or more rule events are absent from the state panel.")
  out <- events
  out$abnormal_volume_causal_percentile <-
    state_panel$abnormal_volume_causal_percentile[lookup]
  out$abnormal_volume_history_observations <-
    state_panel$abnormal_volume_history_observations[lookup]
  out$abnormal_volume_veto <- state_panel$abnormal_volume_veto[lookup]
  recomputed <- state_panel$abnormal_dollar_volume[lookup]
  delta <- abs(out$abnormal_dollar_volume - recomputed)
  if (any(is.finite(delta) & delta > 1e-12)) {
    rgavv_stop("Recomputed abnormal dollar volume does not match the source ledger.")
  }
  out$volume_state <- ifelse(
    is.na(out$abnormal_volume_veto), "NOT_ELIGIBLE",
    ifelse(out$abnormal_volume_veto, "HIGH_VETO", "NORMAL_RETAIN")
  )
  out
}

rgavv_asset_contrasts <- function(events) {
  required <- c("symbol", "sector", "abnormal_volume_veto", "net_excess_vs_unconditional")
  if (length(setdiff(required, names(events)))) rgavv_stop("Event contrast columns are missing.")
  groups <- split(events, events$symbol)
  rows <- lapply(groups, function(x) {
    high <- x$net_excess_vs_unconditional[x$abnormal_volume_veto]
    normal <- x$net_excess_vs_unconditional[!x$abnormal_volume_veto]
    data.frame(
      symbol = x$symbol[[1L]], sector = x$sector[[1L]],
      high_events = length(high), normal_events = length(normal),
      high_mean_excess = if (length(high)) mean(high) else NA_real_,
      normal_mean_excess = if (length(normal)) mean(normal) else NA_real_,
      high_minus_normal = if (length(high) && length(normal)) mean(high) - mean(normal) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

rgavv_sector_contrasts <- function(asset_contrasts) {
  x <- asset_contrasts[is.finite(asset_contrasts$high_minus_normal), , drop = FALSE]
  groups <- split(x, x$sector)
  rows <- lapply(groups, function(z) {
    data.frame(
      sector = z$sector[[1L]], comparable_assets = nrow(z),
      median_asset_contrast = stats::median(z$high_minus_normal),
      mean_asset_contrast = mean(z$high_minus_normal),
      negative_asset_breadth = mean(z$high_minus_normal < 0),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$median_asset_contrast), , drop = FALSE]
}

rgavv_event_summary <- function(events) {
  groups <- split(events, events$volume_state)
  rows <- lapply(groups, function(x) {
    asset_means <- tapply(x$net_excess_vs_unconditional, x$symbol, mean)
    data.frame(
      volume_state = x$volume_state[[1L]], events = nrow(x),
      assets = length(unique(x$symbol)),
      event_pooled_mean_excess = mean(x$net_excess_vs_unconditional),
      asset_balanced_mean_excess = mean(asset_means),
      median_prior_20_log_return = stats::median(x$prior_20_log_return),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

rgavv_match_severity <- function(events) {
  required <- c(
    "symbol", "anchor_session", "prior_20_log_return", "abnormal_volume_veto",
    "net_excess_vs_unconditional"
  )
  if (length(setdiff(required, names(events)))) rgavv_stop("Severity matching columns are missing.")
  rows <- list()
  counter <- 0L
  for (symbol in sort(unique(events$symbol))) {
    x <- events[events$symbol == symbol, , drop = FALSE]
    high <- which(x$abnormal_volume_veto)
    normal <- which(!x$abnormal_volume_veto)
    if (!length(high) || !length(normal)) next
    high <- high[order(x$anchor_session[high])]
    available <- normal
    for (h in high) {
      if (!length(available)) break
      distances <- abs(x$prior_20_log_return[available] - x$prior_20_log_return[[h]])
      pick <- available[order(distances, x$anchor_session[available])[[1L]]]
      counter <- counter + 1L
      rows[[counter]] <- data.frame(
        pair_id = counter, symbol = symbol,
        high_anchor_session = as.Date(x$anchor_session[[h]]),
        normal_anchor_session = as.Date(x$anchor_session[[pick]]),
        high_prior_20_log_return = x$prior_20_log_return[[h]],
        normal_prior_20_log_return = x$prior_20_log_return[[pick]],
        severity_distance = distances[available == pick],
        high_outcome = x$net_excess_vs_unconditional[[h]],
        normal_outcome = x$net_excess_vs_unconditional[[pick]],
        paired_outcome_difference = x$net_excess_vs_unconditional[[h]] -
          x$net_excess_vs_unconditional[[pick]],
        stringsAsFactors = FALSE
      )
      available <- setdiff(available, pick)
    }
  }
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

rgavv_gate_table <- function(events, asset_contrasts, sector_contrasts,
                             matched_pairs, contract = rgavv_contract()) {
  contract <- rgavv_validate_contract(contract)
  comparable_assets <- asset_contrasts[is.finite(asset_contrasts$high_minus_normal), , drop = FALSE]
  high <- events[events$abnormal_volume_veto, , drop = FALSE]
  retained <- events[!events$abnormal_volume_veto, , drop = FALSE]
  high_asset <- tapply(high$net_excess_vs_unconditional, high$symbol, mean)
  retained_asset <- tapply(retained$net_excess_vs_unconditional, retained$symbol, mean)
  all_asset <- tapply(events$net_excess_vs_unconditional, events$symbol, mean)
  common <- intersect(names(high_asset), names(retained_asset))
  primary_difference <- mean(high_asset[common] - retained_asset[common])
  asset_breadth <- mean(comparable_assets$high_minus_normal < 0)
  negative_sectors <- sum(sector_contrasts$median_asset_contrast < 0)
  matched_difference <- mean(matched_pairs$paired_outcome_difference)
  retained_share <- nrow(retained) / nrow(events)
  original_event_mean <- mean(events$net_excess_vs_unconditional)
  retained_event_mean <- mean(retained$net_excess_vs_unconditional)
  data.frame(
    gate_id = c(
      "causal_percentile_coverage", "asset_balanced_contrast_negative",
      "negative_asset_breadth", "negative_sector_breadth",
      "severity_matched_contrast_negative", "retained_trade_share",
      "retained_event_mean_improves"
    ),
    observed = c(
      mean(is.finite(events$abnormal_volume_causal_percentile)),
      primary_difference, asset_breadth, negative_sectors,
      matched_difference, retained_share,
      retained_event_mean - original_event_mean
    ),
    required = c(
      1, 0, contract$minimum_negative_asset_breadth,
      contract$minimum_negative_sectors, 0,
      contract$minimum_retained_share, 0
    ),
    direction = c("at_least", "below", "at_least", "at_least", "below", "at_least", "above"),
    status = c(
      if (all(is.finite(events$abnormal_volume_causal_percentile))) "PASS" else "FAIL",
      if (is.finite(primary_difference) && primary_difference < 0) "PASS" else "FAIL",
      if (is.finite(asset_breadth) && asset_breadth >= contract$minimum_negative_asset_breadth) "PASS" else "FAIL",
      if (negative_sectors >= contract$minimum_negative_sectors) "PASS" else "FAIL",
      if (is.finite(matched_difference) && matched_difference < 0) "PASS" else "FAIL",
      if (retained_share >= contract$minimum_retained_share) "PASS" else "FAIL",
      if (retained_event_mean > original_event_mean) "PASS" else "FAIL"
    ),
    stringsAsFactors = FALSE
  )
}
