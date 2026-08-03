# HYP-MOM-01.1 Diagnostic Atlas 01: causal feature and path diagnostics.

hyp_mom011_da_contract <- function() {
  list(
    atlas_id = "HYP-MOM-01.1-DIAGNOSTIC_ATLAS_01",
    parent_hypothesis_id = "HYP-MOM-01.1",
    evidence_stage = "DISCOVERY_REUSED_WINDOW",
    volatility_lookback = 20L,
    slow_anchor_sessions = 200L,
    anchor_reclaim_lookback = 20L,
    momentum_lookbacks = c(20L, 60L, 120L),
    high_lookback = 60L,
    high_near_sigma = -1,
    high_far_sigma = -3,
    volume_lookback = 20L,
    bootstrap_draws = 2000L,
    bootstrap_seed = 20260804L,
    minimum_asset_correlation_trades = 10L
  )
}

hyp_mom011_da_validate_contract <- function(contract = hyp_mom011_da_contract()) {
  frozen <- hyp_mom011_da_contract()
  if (!identical(names(contract), names(frozen))) {
    hyp_mom011_stop("Frozen Diagnostic Atlas 01 field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    hyp_mom011_stop(paste(
      "Frozen Diagnostic Atlas 01 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

hyp_mom011_da_validate_volume <- function(bars) {
  if (!"volume" %in% names(bars)) hyp_mom011_stop("Diagnostic bars require volume.")
  volume <- as.numeric(bars$volume)
  if (any(!is.finite(volume)) || any(volume <= 0)) {
    hyp_mom011_stop("Diagnostic bars contain invalid volume.")
  }
  volume
}

hyp_mom011_da_sma <- function(values, index, lookback) {
  start <- index - as.integer(lookback) + 1L
  if (start < 1L) return(NA_real_)
  mean(values[start:index])
}

hyp_mom011_da_prior_sd <- function(log_returns, end_index, lookback) {
  start <- end_index - as.integer(lookback) + 1L
  if (start < 2L || end_index > length(log_returns)) return(NA_real_)
  value <- stats::sd(log_returns[start:end_index])
  if (!is.finite(value) || value <= 0) return(NA_real_)
  value
}

hyp_mom011_da_spy_context <- function(
  spy_bars,
  atlas_contract = hyp_mom011_da_contract(),
  parent_contract = hyp_mom011_contract()
) {
  atlas_contract <- hyp_mom011_da_validate_contract(atlas_contract)
  x <- hyp_mom011_validate_bars(spy_bars, parent_contract)
  if (!identical(unique(x$symbol), "SPY")) {
    hyp_mom011_stop("Market context requires exactly SPY bars.")
  }
  x <- x[order(x$session_date), , drop = FALSE]
  close <- x$close
  rows <- lapply(seq_len(nrow(x)), function(i) {
    sma200 <- hyp_mom011_da_sma(close, i, atlas_contract$slow_anchor_sessions)
    mom60 <- if (i > 60L) log(close[[i]] / close[[i - 60L]]) else NA_real_
    data.frame(
      signal_date = x$session_date[[i]],
      spy_sma200 = sma200,
      spy_above_sma200 = if (is.finite(sma200)) close[[i]] > sma200 else NA,
      spy_momentum_60 = mom60,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

hyp_mom011_da_asset_features <- function(
  bars,
  spy_context,
  atlas_contract = hyp_mom011_da_contract(),
  parent_contract = hyp_mom011_contract()
) {
  atlas_contract <- hyp_mom011_da_validate_contract(atlas_contract)
  parent_contract <- hyp_mom011_validate_contract(parent_contract)
  x <- hyp_mom011_validate_bars(bars, parent_contract)
  volume <- hyp_mom011_da_validate_volume(x)
  if (length(unique(x$symbol)) != 1L) {
    hyp_mom011_stop("Diagnostic feature construction requires one asset.")
  }
  x <- x[order(x$session_date), , drop = FALSE]
  volume <- as.numeric(x$volume)
  candidates <- hyp_mom011_signal_candidates(x, parent_contract)
  candidates <- hyp_mom011_select_nonoverlap(
    candidates, parent_contract$allow_same_open_reentry
  )
  trades <- candidates[candidates$executed, , drop = FALSE]
  if (!nrow(trades)) hyp_mom011_stop("Diagnostic asset contains no executed trades.")
  trades$primary_trade_return <- hyp_mom011_apply_cost(
    trades$gross_trade_return, parent_contract$primary_cost_bps
  )
  trades$stress_trade_return <- hyp_mom011_apply_cost(
    trades$gross_trade_return, parent_contract$stress_cost_bps
  )

  close <- x$close
  open <- x$open
  log_returns <- c(NA_real_, diff(log(close)))
  qualifying <- c(FALSE, open[-1L] > close[-nrow(x)]) & close > open

  rows <- lapply(seq_len(nrow(trades)), function(i) {
    trade <- trades[i, , drop = FALSE]
    s <- as.integer(trade$signal_index[[1L]])
    e <- as.integer(trade$entry_index[[1L]])
    z <- as.integer(trade$exit_index[[1L]])
    sigma1 <- hyp_mom011_da_prior_sd(
      log_returns, s - 2L, atlas_contract$volatility_lookback
    )
    sigma2 <- hyp_mom011_da_prior_sd(
      log_returns, s - 1L, atlas_contract$volatility_lookback
    )
    if (!is.finite(sigma1) || !is.finite(sigma2)) {
      hyp_mom011_stop(paste("Non-finite lagged volatility for", trade$signal_id))
    }
    gap1_z <- log(open[[s - 1L]] / close[[s - 2L]]) / sigma1
    gap2_z <- log(open[[s]] / close[[s - 1L]]) / sigma2
    body1_z <- log(close[[s - 1L]] / open[[s - 1L]]) / sigma1
    body2_z <- log(close[[s]] / open[[s]]) / sigma2

    sma200 <- hyp_mom011_da_sma(close, s, atlas_contract$slow_anchor_sessions)
    prior_anchor_index <- s - atlas_contract$anchor_reclaim_lookback
    prior_sma200 <- hyp_mom011_da_sma(
      close, prior_anchor_index, atlas_contract$slow_anchor_sessions
    )
    if (!is.finite(sma200) || !is.finite(prior_sma200)) {
      hyp_mom011_stop(paste("Insufficient SMA200 history for", trade$signal_id))
    }
    above_now <- close[[s]] > sma200
    above_prior <- close[[prior_anchor_index]] > prior_sma200
    anchor_state <- if (!above_now) {
      "BELOW_ANCHOR"
    } else if (above_prior) {
      "ESTABLISHED_ABOVE"
    } else {
      "RECENT_RECLAIM"
    }

    momentum <- vapply(
      atlas_contract$momentum_lookbacks,
      function(lookback) log(close[[s]] / close[[s - lookback]]),
      numeric(1)
    )
    names(momentum) <- paste0("momentum_", atlas_contract$momentum_lookbacks)

    streak <- 0L
    j <- s
    while (j >= 1L && isTRUE(qualifying[[j]])) {
      streak <- streak + 1L
      j <- j - 1L
    }
    volume_reference <- stats::median(
      volume[(s - atlas_contract$volume_lookback):(s - 1L)]
    )
    high60 <- max(close[(s - atlas_contract$high_lookback + 1L):s])
    high_distance_z <- log(close[[s]] / high60) / sigma2

    path <- vapply(
      1:parent_contract$holding_sessions,
      function(k) open[[e + k]] / open[[e]] - 1,
      numeric(1)
    )
    remaining <- vapply(
      1:(parent_contract$holding_sessions - 1L),
      function(k) open[[z]] / open[[e + k]] - 1,
      numeric(1)
    )
    names(path) <- paste0("path_return_", seq_along(path))
    names(remaining) <- paste0("remaining_return_", seq_along(remaining))

    context_index <- match(as.Date(trade$signal_date), spy_context$signal_date)
    if (is.na(context_index)) {
      hyp_mom011_stop(paste("Missing SPY context for", trade$signal_id))
    }
    context <- spy_context[context_index, , drop = FALSE]

    cbind(
      trade,
      data.frame(
        lagged_sigma_first = sigma1,
        lagged_sigma_second = sigma2,
        gap1_z = gap1_z,
        gap2_z = gap2_z,
        body1_z = body1_z,
        body2_z = body2_z,
        gap_strength_z = gap1_z + gap2_z,
        body_strength_z = body1_z + body2_z,
        minimum_gap_z = min(gap1_z, gap2_z),
        minimum_body_z = min(body1_z, body2_z),
        second_minus_first_strength = (gap2_z + body2_z) - (gap1_z + body1_z),
        sma200 = sma200,
        above_sma200 = above_now,
        anchor_state = anchor_state,
        anchor_distance_z = log(close[[s]] / sma200) / sigma2,
        momentum_20 = momentum[["momentum_20"]],
        momentum_60 = momentum[["momentum_60"]],
        momentum_120 = momentum[["momentum_120"]],
        qualifying_streak = streak,
        volume_ratio20 = volume[[s]] / volume_reference,
        high60 = high60,
        high60_distance_z = high_distance_z,
        spy_sma200 = context$spy_sma200,
        spy_above_sma200 = context$spy_above_sma200,
        spy_momentum_60 = context$spy_momentum_60,
        peak_to_exit_giveback = trade$maximum_favorable_excursion -
          trade$gross_trade_return,
        trough_to_exit_recovery = trade$gross_trade_return -
          trade$maximum_adverse_excursion,
        stringsAsFactors = FALSE
      ),
      as.data.frame(as.list(c(path, remaining)), stringsAsFactors = FALSE)
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

hyp_mom011_da_rank_tercile <- function(x) {
  x <- as.numeric(x)
  ranks <- rank(x, ties.method = "average", na.last = "keep")
  pct <- ranks / sum(is.finite(x))
  as.character(cut(
    pct,
    breaks = c(0, 1 / 3, 2 / 3, 1),
    labels = c("LOW", "MID", "HIGH"),
    include.lowest = TRUE
  ))
}

hyp_mom011_da_add_groups <- function(
  trades,
  atlas_contract = hyp_mom011_da_contract()
) {
  atlas_contract <- hyp_mom011_da_validate_contract(atlas_contract)
  x <- as.data.frame(trades, stringsAsFactors = FALSE)
  x$gap_strength_tercile <- hyp_mom011_da_rank_tercile(x$gap_strength_z)
  x$body_strength_tercile <- hyp_mom011_da_rank_tercile(x$body_strength_z)
  x$gap_body_cell <- paste(x$gap_strength_tercile, x$body_strength_tercile, sep = "_GAP__BODY_")
  x$above_sma200_state <- ifelse(x$above_sma200, "ABOVE", "BELOW")
  for (lookback in atlas_contract$momentum_lookbacks) {
    field <- paste0("momentum_", lookback)
    x[[paste0(field, "_state")]] <- ifelse(x[[field]] > 0, "POSITIVE", "NONPOSITIVE")
  }
  x$streak_state <- ifelse(x$qualifying_streak >= 3L, "THREE_OR_MORE", "EXACTLY_TWO")
  x$volume_state <- ifelse(x$volume_ratio20 >= 1, "AT_OR_ABOVE_ONE", "BELOW_ONE")
  x$high60_state <- ifelse(
    x$high60_distance_z >= atlas_contract$high_near_sigma,
    "NEAR_HIGH",
    ifelse(
      x$high60_distance_z < atlas_contract$high_far_sigma,
      "FAR_BELOW_HIGH",
      "MID_RANGE"
    )
  )
  x$spy_sma200_state <- ifelse(x$spy_above_sma200, "ABOVE", "BELOW")
  x$spy_momentum_60_state <- ifelse(x$spy_momentum_60 > 0, "POSITIVE", "NONPOSITIVE")
  x
}

hyp_mom011_da_group_summary <- function(data, diagnostic_id, group_column) {
  if (!group_column %in% names(data)) {
    hyp_mom011_stop(paste("Missing diagnostic group column:", group_column))
  }
  groups <- split(data, as.character(data[[group_column]]))
  rows <- lapply(names(groups), function(group_name) {
    x <- groups[[group_name]]
    data.frame(
      diagnostic_id = diagnostic_id,
      group_column = group_column,
      group = group_name,
      trade_count = nrow(x),
      asset_count = length(unique(x$symbol)),
      mean_primary_return = mean(x$primary_trade_return),
      median_primary_return = stats::median(x$primary_trade_return),
      hit_rate = mean(x$primary_trade_return > 0),
      p05_primary_return = as.numeric(stats::quantile(x$primary_trade_return, 0.05)),
      p95_primary_return = as.numeric(stats::quantile(x$primary_trade_return, 0.95)),
      mean_maximum_adverse_excursion = mean(x$maximum_adverse_excursion),
      mean_maximum_favorable_excursion = mean(x$maximum_favorable_excursion),
      mean_peak_to_exit_giveback = mean(x$peak_to_exit_giveback),
      mean_trough_to_exit_recovery = mean(x$trough_to_exit_recovery),
      mean_first_session_return = mean(x$first_session_return),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

hyp_mom011_da_asset_contrast <- function(
  data,
  diagnostic_id,
  group_column,
  positive_group,
  reference_group,
  bootstrap_draws = hyp_mom011_da_contract()$bootstrap_draws,
  seed = hyp_mom011_da_contract()$bootstrap_seed
) {
  x <- data[data[[group_column]] %in% c(positive_group, reference_group), , drop = FALSE]
  means <- stats::aggregate(
    x$primary_trade_return,
    list(symbol = x$symbol, group = x[[group_column]]),
    mean
  )
  names(means)[[3L]] <- "mean_return"
  wide <- reshape(means, idvar = "symbol", timevar = "group", direction = "wide")
  positive_field <- paste0("mean_return.", positive_group)
  reference_field <- paste0("mean_return.", reference_group)
  if (!all(c(positive_field, reference_field) %in% names(wide))) {
    differences <- numeric()
  } else {
    keep <- is.finite(wide[[positive_field]]) & is.finite(wide[[reference_field]])
    differences <- wide[[positive_field]][keep] - wide[[reference_field]][keep]
  }
  if (!length(differences)) {
    return(data.frame(
      diagnostic_id = diagnostic_id,
      group_column = group_column,
      positive_group = positive_group,
      reference_group = reference_group,
      paired_asset_count = 0L,
      mean_asset_contrast = NA_real_,
      median_asset_contrast = NA_real_,
      fraction_asset_contrasts_positive = NA_real_,
      bootstrap_ci_low = NA_real_,
      bootstrap_ci_high = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  set.seed(as.integer(seed))
  boot <- replicate(
    as.integer(bootstrap_draws),
    mean(sample(differences, length(differences), replace = TRUE))
  )
  data.frame(
    diagnostic_id = diagnostic_id,
    group_column = group_column,
    positive_group = positive_group,
    reference_group = reference_group,
    paired_asset_count = length(differences),
    mean_asset_contrast = mean(differences),
    median_asset_contrast = stats::median(differences),
    fraction_asset_contrasts_positive = mean(differences > 0),
    bootstrap_ci_low = as.numeric(stats::quantile(boot, 0.025)),
    bootstrap_ci_high = as.numeric(stats::quantile(boot, 0.975)),
    stringsAsFactors = FALSE
  )
}

hyp_mom011_da_asset_correlations <- function(
  data,
  feature_columns,
  minimum_trades = hyp_mom011_da_contract()$minimum_asset_correlation_trades
) {
  rows <- list()
  index <- 0L
  for (feature in feature_columns) {
    for (symbol in sort(unique(data$symbol))) {
      x <- data[data$symbol == symbol, c(feature, "primary_trade_return"), drop = FALSE]
      x <- x[stats::complete.cases(x), , drop = FALSE]
      if (nrow(x) < minimum_trades || length(unique(x[[feature]])) < 2L) next
      index <- index + 1L
      rows[[index]] <- data.frame(
        feature = feature,
        symbol = symbol,
        trade_count = nrow(x),
        spearman_rho = suppressWarnings(stats::cor(
          x[[feature]], x$primary_trade_return, method = "spearman"
        )),
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

hyp_mom011_da_checkpoint_rows <- function(
  trades,
  holding_sessions = hyp_mom011_contract()$holding_sessions
) {
  rows <- list()
  index <- 0L
  for (k in seq_len(holding_sessions - 1L)) {
    for (i in seq_len(nrow(trades))) {
      index <- index + 1L
      cumulative <- trades[[paste0("path_return_", k)]][[i]]
      rows[[index]] <- data.frame(
        trade_id = trades$trade_id[[i]],
        symbol = trades$symbol[[i]],
        sector = trades$sector[[i]],
        checkpoint = k,
        cumulative_return = cumulative,
        checkpoint_state = ifelse(cumulative > 0, "POSITIVE", "NONPOSITIVE"),
        remaining_return = trades[[paste0("remaining_return_", k)]][[i]],
        final_primary_return = trades$primary_trade_return[[i]],
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

hyp_mom011_da_checkpoint_summary <- function(checkpoints) {
  keys <- interaction(checkpoints$checkpoint, checkpoints$checkpoint_state, drop = TRUE)
  groups <- split(checkpoints, keys)
  rows <- lapply(groups, function(x) {
    data.frame(
      checkpoint = unique(x$checkpoint),
      checkpoint_state = unique(x$checkpoint_state),
      trade_count = nrow(x),
      asset_count = length(unique(x$symbol)),
      mean_cumulative_return = mean(x$cumulative_return),
      mean_remaining_return = mean(x$remaining_return),
      median_remaining_return = stats::median(x$remaining_return),
      remaining_hit_rate = mean(x$remaining_return > 0),
      mean_final_primary_return = mean(x$final_primary_return),
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  result[order(result$checkpoint, result$checkpoint_state), , drop = FALSE]
}
