rgafa_stop <- function(message) {
  stop(paste0("[RETURN-GEOMETRY-APPLICABILITY] ", message), call. = FALSE)
}

rgafa_contract <- function() {
  list(
    study_id = "RETURN_GEOMETRY_APPLICABILITY_FEATURE_ATLAS_01",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    prior_sessions = 20L,
    pre_event_sessions = 126L,
    market_volatility_sessions = 20L,
    market_percentile_history = 504L,
    minimum_market_percentile_history = 252L,
    minimum_sector_peers = 5L,
    bins = 5L,
    expected_assets = 129L,
    expected_core_assets = 88L,
    expected_sectors = 11L,
    round_trip_cost_bps = 10
  )
}

rgafa_validate_contract <- function(contract = rgafa_contract()) {
  if (contract$analysis_end > as.Date("2023-12-29")) {
    rgafa_stop("Post-2023 outcomes are sealed.")
  }
  if (contract$prior_sessions != 20L || contract$pre_event_sessions != 126L ||
      contract$market_volatility_sessions != 20L || contract$bins < 2L) {
    rgafa_stop("The frozen feature-window contract changed.")
  }
  contract
}

rgafa_daily_log_return <- function(close) {
  close <- as.numeric(close)
  if (any(!is.finite(close)) || any(close <= 0)) {
    rgafa_stop("Close prices must be finite and positive.")
  }
  c(NA_real_, diff(log(close)))
}

rgafa_prior_log_return <- function(close, sessions = 20L) {
  close <- as.numeric(close)
  sessions <- as.integer(sessions)
  if (length(close) <= sessions) return(rep(NA_real_, length(close)))
  c(rep(NA_real_, sessions), log(
    close[(sessions + 1L):length(close)] /
      close[seq_len(length(close) - sessions)]
  ))
}

rgafa_rolling_sd <- function(x, sessions = 20L) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (sessions < 2L || length(x) < sessions) return(out)
  for (i in sessions:length(x)) {
    window <- x[(i - sessions + 1L):i]
    if (all(is.finite(window))) out[[i]] <- stats::sd(window)
  }
  out
}

rgafa_causal_percentile <- function(x, history = 504L, minimum = 252L) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  history_n <- integer(length(x))
  for (i in seq_along(x)) {
    if (!is.finite(x[[i]]) || i <= 1L) next
    lo <- max(1L, i - history)
    prior <- x[lo:(i - 1L)]
    prior <- prior[is.finite(prior)]
    history_n[[i]] <- length(prior)
    if (length(prior) >= minimum) {
      out[[i]] <- mean(prior <= x[[i]])
    }
  }
  data.frame(percentile = out, history_observations = history_n)
}

rgafa_prepare_ledger <- function(ledger) {
  required <- c("symbol", "session_date", "open", "close", "volume")
  missing <- setdiff(required, names(ledger))
  if (length(missing)) rgafa_stop(paste("Ledger is missing:", paste(missing, collapse = ", ")))
  x <- ledger[order(as.Date(ledger$session_date)), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  if (anyDuplicated(x$session_date) || any(diff(x$session_date) <= 0) ||
      any(!is.finite(x$open)) || any(!is.finite(x$close)) ||
      any(!is.finite(x$volume)) || any(x$open <= 0) ||
      any(x$close <= 0) || any(x$volume < 0)) {
    rgafa_stop("Ledger dates or adjusted OHLCV values are invalid.")
  }
  x$daily_log_return <- rgafa_daily_log_return(x$close)
  x$prior_20_log_return <- rgafa_prior_log_return(x$close, 20L)
  x$dollar_volume <- ifelse(x$volume > 0, x$close * x$volume, NA_real_)
  x$daily_price_impact <- abs(x$daily_log_return) / x$dollar_volume
  x
}

rgafa_own_features <- function(ledger, anchor_index,
                               contract = rgafa_contract()) {
  contract <- rgafa_validate_contract(contract)
  x <- rgafa_prepare_ledger(ledger)
  a <- as.integer(anchor_index)
  event_lo <- a - contract$prior_sessions + 1L
  pre_hi <- a - contract$prior_sessions
  pre_lo <- pre_hi - contract$pre_event_sessions + 1L
  trend_start <- a - contract$prior_sessions - contract$pre_event_sessions
  if (event_lo < 2L || pre_lo < 2L || trend_start < 1L || a > nrow(x)) {
    return(data.frame(
      abnormal_dollar_volume = NA_real_, price_impact_shock = NA_real_,
      pre_shock_normalized_trend = NA_real_, stringsAsFactors = FALSE
    ))
  }
  event_dv <- stats::median(x$dollar_volume[event_lo:a], na.rm = TRUE)
  pre_dv <- stats::median(x$dollar_volume[pre_lo:pre_hi], na.rm = TRUE)
  event_impact <- mean(x$daily_price_impact[event_lo:a], na.rm = TRUE)
  pre_impact <- stats::median(x$daily_price_impact[pre_lo:pre_hi], na.rm = TRUE)
  trend_return <- log(x$close[[pre_hi]] / x$close[[trend_start]])
  trend_daily <- x$daily_log_return[(trend_start + 1L):pre_hi]
  trend_scale <- stats::sd(trend_daily) * sqrt(contract$pre_event_sessions)
  data.frame(
    abnormal_dollar_volume = if (event_dv > 0 && pre_dv > 0) log(event_dv / pre_dv) else NA_real_,
    price_impact_shock = if (event_impact > 0 && pre_impact > 0) log(event_impact / pre_impact) else NA_real_,
    pre_shock_normalized_trend = if (is.finite(trend_scale) && trend_scale > 0) {
      trend_return / trend_scale
    } else NA_real_,
    stringsAsFactors = FALSE
  )
}

rgafa_peer_features <- function(symbol, anchor_session, sector, prior_return_panel,
                                registry, contract = rgafa_contract()) {
  core <- registry$sector_balance_eligible & registry$sector == sector &
    registry$symbol != symbol
  peers <- registry$symbol[core]
  rows <- prior_return_panel$session_date == as.Date(anchor_session) &
    prior_return_panel$symbol %in% peers &
    is.finite(prior_return_panel$prior_20_log_return)
  values <- prior_return_panel$prior_20_log_return[rows]
  focal <- prior_return_panel$prior_20_log_return[
    prior_return_panel$session_date == as.Date(anchor_session) &
      prior_return_panel$symbol == symbol
  ]
  focal <- focal[is.finite(focal)]
  if (length(values) < contract$minimum_sector_peers || length(focal) != 1L) {
    return(data.frame(
      sector_peer_count = length(values), sector_peer_prior_20_return = NA_real_,
      sector_relative_loss = NA_real_, peer_negative_breadth = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  peer_return <- mean(values)
  data.frame(
    sector_peer_count = length(values),
    sector_peer_prior_20_return = peer_return,
    sector_relative_loss = focal[[1L]] - peer_return,
    peer_negative_breadth = mean(values < 0),
    stringsAsFactors = FALSE
  )
}

rgafa_market_state <- function(spy_ledger, contract = rgafa_contract()) {
  x <- rgafa_prepare_ledger(spy_ledger)
  rv <- rgafa_rolling_sd(x$daily_log_return, contract$market_volatility_sessions)
  pct <- rgafa_causal_percentile(
    rv, history = contract$market_percentile_history,
    minimum = contract$minimum_market_percentile_history
  )
  data.frame(
    session_date = x$session_date,
    spy_realized_volatility_20 = rv * sqrt(252),
    spy_realized_volatility_percentile = pct$percentile,
    spy_volatility_history_observations = pct$history_observations,
    stringsAsFactors = FALSE
  )
}

rgafa_assign_bins <- function(x, bins = 5L) {
  out <- rep(NA_integer_, length(x))
  ok <- is.finite(x)
  if (sum(ok) < bins) return(out)
  breaks <- unique(as.numeric(stats::quantile(
    x[ok], probs = seq(0, 1, length.out = bins + 1L),
    names = FALSE, type = 7
  )))
  if (length(breaks) < 3L) return(out)
  out[ok] <- findInterval(x[ok], breaks, all.inside = TRUE)
  out
}

rgafa_binned_profile <- function(events, feature, bins = 5L) {
  required <- c("symbol", "net_excess_vs_unconditional", feature)
  missing <- setdiff(required, names(events))
  if (length(missing)) rgafa_stop(paste("Event frame is missing:", paste(missing, collapse = ", ")))
  x <- events[is.finite(events[[feature]]) &
    is.finite(events$net_excess_vs_unconditional), required, drop = FALSE]
  if (!nrow(x)) return(data.frame())
  x$feature_bin <- rgafa_assign_bins(x[[feature]], bins)
  x <- x[is.finite(x$feature_bin), , drop = FALSE]
  split_asset_bin <- split(x, interaction(x$symbol, x$feature_bin, drop = TRUE, lex.order = TRUE))
  asset_bin <- do.call(rbind, lapply(split_asset_bin, function(z) {
    data.frame(
      symbol = z$symbol[[1L]], feature_bin = z$feature_bin[[1L]],
      events = nrow(z), feature_mean = mean(z[[feature]]),
      outcome_mean = mean(z$net_excess_vs_unconditional), stringsAsFactors = FALSE
    )
  }))
  split_bin <- split(x, x$feature_bin)
  rows <- lapply(split_bin, function(z) {
    b <- z$feature_bin[[1L]]
    balanced <- asset_bin[asset_bin$feature_bin == b, , drop = FALSE]
    data.frame(
      feature = feature, feature_bin = b, events = nrow(z),
      assets = length(unique(z$symbol)), feature_mean = mean(z[[feature]]),
      event_pooled_mean_excess = mean(z$net_excess_vs_unconditional),
      asset_balanced_mean_excess = mean(balanced$outcome_mean),
      asset_balanced_median_excess = stats::median(balanced$outcome_mean),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$feature_bin), , drop = FALSE]
}

rgafa_feature_summary <- function(events, feature, bins = 5L) {
  x <- events[is.finite(events[[feature]]) &
    is.finite(events$net_excess_vs_unconditional), , drop = FALSE]
  profile <- rgafa_binned_profile(x, feature, bins)
  if (!nrow(x) || !nrow(profile)) {
    return(data.frame(
      feature = feature, events = nrow(x), assets = length(unique(x$symbol)),
      spearman_rho = NA_real_, low_to_high_asset_balanced_difference = NA_real_,
      low_to_high_event_pooled_difference = NA_real_, stringsAsFactors = FALSE
    ))
  }
  low <- profile[which.min(profile$feature_bin), , drop = FALSE]
  high <- profile[which.max(profile$feature_bin), , drop = FALSE]
  data.frame(
    feature = feature, events = nrow(x), assets = length(unique(x$symbol)),
    spearman_rho = suppressWarnings(stats::cor(
      x[[feature]], x$net_excess_vs_unconditional,
      method = "spearman", use = "complete.obs"
    )),
    low_to_high_asset_balanced_difference =
      high$asset_balanced_mean_excess - low$asset_balanced_mean_excess,
    low_to_high_event_pooled_difference =
      high$event_pooled_mean_excess - low$event_pooled_mean_excess,
    stringsAsFactors = FALSE
  )
}
