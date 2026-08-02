# Deterministic representative trade-tape helpers for LIT-MOM-01.2 Audit 01.

g5_mom012t_stop <- function(message) stop(message, call. = FALSE)

g5_mom012t_contract <- function() {
  list(
    review_id = "LIT-MOM-01.2 / AUDIT_01_REPRESENTATIVE_TRADE_TAPES",
    evidence_label = "RETROSPECTIVE_DESCRIPTIVE_TRADE_TAPE_REVIEW",
    source_run_id = "lit_mom_01_2_audit_01_exposure_selection_20260802",
    retrospective_start = as.Date("2021-01-04"),
    retrospective_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    archetype_count = 8L,
    random_survivor_percentile = 0.80,
    random_disappointment_percentile = 0.20,
    deep_drawdown_quantile = 0.10,
    countercyclical_minimum_trades_per_state = 10L
  )
}

g5_mom012t_validate_contract <- function(contract = g5_mom012t_contract()) {
  frozen <- g5_mom012t_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom012t_stop("Frozen trade-tape contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom012t_stop(paste(
      "Frozen trade-tape contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom012t_numeric_columns <- function() {
  c(
    "lookback_sessions", "holding_sessions", "selected_return",
    "selected_maximum_drawdown", "selected_trade_count",
    "selected_long_call_accuracy", "calendar_participation",
    "buy_hold_return", "excess_vs_buy_hold",
    "excess_vs_constant_exposure", "observed_random_percentile",
    "spy_beta", "annualized_alpha"
  )
}

g5_mom012t_prepare_assets <- function(asset_summary) {
  required <- c(
    "symbol", "cohort", "sector", "lookback_sessions", "holding_sessions",
    "selected_return", "selected_maximum_drawdown", "selected_trade_count",
    "selected_long_call_accuracy", "calendar_participation",
    "buy_hold_return", "excess_vs_buy_hold",
    "excess_vs_constant_exposure", "observed_random_percentile",
    "spy_beta", "annualized_alpha"
  )
  missing <- setdiff(required, names(asset_summary))
  if (length(missing)) {
    g5_mom012t_stop(paste(
      "Trade-tape asset summary is missing columns:",
      paste(missing, collapse = ", ")
    ))
  }
  x <- as.data.frame(asset_summary, stringsAsFactors = FALSE)
  numeric <- intersect(g5_mom012t_numeric_columns(), names(x))
  x[numeric] <- lapply(x[numeric], as.numeric)
  if (anyDuplicated(x$symbol)) {
    g5_mom012t_stop("Trade-tape asset summary contains duplicate symbols.")
  }
  x
}

g5_mom012t_robust_distance <- function(data, metrics) {
  x <- as.data.frame(data[metrics])
  x[] <- lapply(x, as.numeric)
  centers <- vapply(x, stats::median, numeric(1), na.rm = TRUE)
  scales <- vapply(x, stats::mad, numeric(1), na.rm = TRUE, constant = 1)
  fallback <- vapply(x, stats::sd, numeric(1), na.rm = TRUE)
  scales[!is.finite(scales) | scales == 0] <- fallback[!is.finite(scales) | scales == 0]
  scales[!is.finite(scales) | scales == 0] <- 1
  z <- sweep(as.matrix(x), 2, centers, "-")
  z <- sweep(z, 2, scales, "/")
  z[!is.finite(z)] <- 0
  rowSums(z^2)
}

g5_mom012t_percentile_rank <- function(x) {
  x <- as.numeric(x)
  if (!length(x)) return(numeric())
  rank(x, ties.method = "average", na.last = "keep") / sum(is.finite(x))
}

g5_mom012t_pick <- function(candidates, score, used, decreasing = FALSE) {
  if (!nrow(candidates)) g5_mom012t_stop("Trade-tape archetype has no eligible assets.")
  candidates$selection_score <- as.numeric(score)
  candidates <- candidates[!candidates$symbol %in% used, , drop = FALSE]
  candidates <- candidates[is.finite(candidates$selection_score), , drop = FALSE]
  if (!nrow(candidates)) {
    g5_mom012t_stop("Trade-tape archetype has no unused eligible assets.")
  }
  order_index <- order(
    if (decreasing) -candidates$selection_score else candidates$selection_score,
    candidates$symbol
  )
  candidates[order_index[[1L]], , drop = FALSE]
}

g5_mom012t_countercyclical_scores <- function(environment_trades, minimum_trades) {
  required <- c("symbol", "market_trend", "trade_return")
  missing <- setdiff(required, names(environment_trades))
  if (length(missing)) {
    g5_mom012t_stop(paste(
      "Trade-tape environment data are missing columns:",
      paste(missing, collapse = ", ")
    ))
  }
  x <- as.data.frame(environment_trades, stringsAsFactors = FALSE)
  x$trade_return <- as.numeric(x$trade_return)
  x <- x[x$symbol != "SHY" & x$market_trend %in% c("POSITIVE", "NON_POSITIVE"), , drop = FALSE]
  split_rows <- split(x, x$symbol)
  rows <- lapply(split_rows, function(asset) {
    positive <- asset$trade_return[asset$market_trend == "POSITIVE"]
    non_positive <- asset$trade_return[asset$market_trend == "NON_POSITIVE"]
    data.frame(
      symbol = asset$symbol[[1L]],
      positive_trade_count = length(positive),
      non_positive_trade_count = length(non_positive),
      positive_mean_trade_return = mean(positive, na.rm = TRUE),
      non_positive_mean_trade_return = mean(non_positive, na.rm = TRUE),
      countercyclical_gap = mean(non_positive, na.rm = TRUE) - mean(positive, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[
    out$positive_trade_count >= as.integer(minimum_trades) &
      out$non_positive_trade_count >= as.integer(minimum_trades) &
      is.finite(out$countercyclical_gap),
    , drop = FALSE
  ]
  rownames(out) <- NULL
  out
}

g5_mom012t_select_representatives <- function(
  asset_summary,
  environment_trades,
  contract = g5_mom012t_contract()
) {
  contract <- g5_mom012t_validate_contract(contract)
  assets <- g5_mom012t_prepare_assets(asset_summary)
  stocks <- assets[assets$symbol != "SHY", , drop = FALSE]
  if (nrow(assets[assets$symbol == "SHY", , drop = FALSE]) != 1L) {
    g5_mom012t_stop("Trade-tape review requires exactly one SHY row.")
  }

  archetypes <- list()
  used <- character()
  asset_columns <- names(assets)
  add_pick <- function(archetype_id, row, selection_basis) {
    row <- row[asset_columns]
    row$archetype_id <- archetype_id
    row$selection_basis <- selection_basis
    archetypes[[length(archetypes) + 1L]] <<- row
    used <<- c(used, row$symbol[[1L]])
  }

  add_pick(
    "SHY_TUTORIAL",
    assets[assets$symbol == "SHY", , drop = FALSE],
    "Fixed worked-example and cost-fragility anchor"
  )

  medoid_metrics <- c(
    "selected_return", "excess_vs_buy_hold", "excess_vs_constant_exposure",
    "observed_random_percentile", "selected_maximum_drawdown", "spy_beta"
  )
  row <- g5_mom012t_pick(
    stocks,
    g5_mom012t_robust_distance(stocks, medoid_metrics),
    used
  )
  add_pick(
    "CROSS_SECTIONAL_MEDOID", row,
    "Nearest robust multivariate stock-path center"
  )

  eligible <- stocks[
    stocks$selected_return > 0 & stocks$excess_vs_buy_hold < 0 &
      stocks$excess_vs_constant_exposure < 0,
    , drop = FALSE
  ]
  row <- g5_mom012t_pick(
    eligible,
    g5_mom012t_robust_distance(eligible, medoid_metrics),
    used
  )
  add_pick(
    "POSITIVE_BUT_EXPOSURE_DOMINATED", row,
    "Positive endpoint; trails buy-and-hold and matched constant exposure"
  )

  eligible <- stocks[
    stocks$excess_vs_buy_hold > 0 & stocks$excess_vs_constant_exposure > 0 &
      stocks$observed_random_percentile >= contract$random_survivor_percentile &
      stocks$annualized_alpha > 0,
    , drop = FALSE
  ]
  survivor_score <- pmin(
    g5_mom012t_percentile_rank(eligible$excess_vs_buy_hold),
    g5_mom012t_percentile_rank(eligible$excess_vs_constant_exposure),
    g5_mom012t_percentile_rank(eligible$observed_random_percentile),
    g5_mom012t_percentile_rank(eligible$annualized_alpha)
  )
  row <- g5_mom012t_pick(eligible, survivor_score, used, decreasing = TRUE)
  add_pick(
    "ATTRIBUTION_SURVIVOR", row,
    "Balanced positive exposure, random-timing, and SPY-alpha diagnostics"
  )

  eligible <- stocks[
    stocks$selected_return > 0 &
      stocks$observed_random_percentile <= contract$random_disappointment_percentile,
    , drop = FALSE
  ]
  row <- g5_mom012t_pick(
    eligible,
    g5_mom012t_robust_distance(
      eligible,
      c("selected_return", "excess_vs_constant_exposure", "selected_maximum_drawdown", "spy_beta")
    ),
    used
  )
  add_pick(
    "RANDOM_TIMING_DISAPPOINTMENT", row,
    "Positive endpoint but bottom-quintile matched-random timing"
  )

  deep_cutoff <- stats::quantile(
    stocks$selected_maximum_drawdown,
    probs = contract$deep_drawdown_quantile,
    na.rm = TRUE,
    names = FALSE,
    type = 7
  )
  eligible <- stocks[
    stocks$selected_return > 0 & stocks$selected_maximum_drawdown <= deep_cutoff,
    , drop = FALSE
  ]
  row <- g5_mom012t_pick(
    eligible,
    g5_mom012t_robust_distance(
      eligible,
      c("selected_return", "excess_vs_buy_hold", "observed_random_percentile", "spy_beta")
    ),
    used
  )
  add_pick(
    "DEEP_DRAWDOWN_POSITIVE_FINISH", row,
    "Positive endpoint inside the deepest stock-path drawdown decile"
  )

  eligible <- stocks[stocks$cohort == "RETAIL_ATTENTION_2020", , drop = FALSE]
  row <- g5_mom012t_pick(
    eligible,
    g5_mom012t_robust_distance(eligible, medoid_metrics),
    used
  )
  add_pick(
    "ATTENTION_COHORT_MEDOID", row,
    "Nearest robust multivariate center of the frozen 2020 attention cohort"
  )

  counter <- g5_mom012t_countercyclical_scores(
    environment_trades,
    contract$countercyclical_minimum_trades_per_state
  )
  eligible <- merge(stocks, counter, by = "symbol", all = FALSE)
  row <- g5_mom012t_pick(
    eligible,
    eligible$countercyclical_gap,
    used,
    decreasing = TRUE
  )
  add_pick(
    "COUNTERCYCLICAL_TRADE_MIX", row,
    "Largest supported asset-level mean trade-return gap: market down/flat minus up"
  )

  selected <- do.call(rbind, archetypes)
  selected$archetype_order <- seq_len(nrow(selected))
  selected <- selected[order(selected$archetype_order), , drop = FALSE]
  rownames(selected) <- NULL
  if (nrow(selected) != contract$archetype_count || anyDuplicated(selected$symbol)) {
    g5_mom012t_stop("Trade-tape selection did not produce eight unique archetypes.")
  }
  selected
}

g5_mom012t_tape_series <- function(daily_paths, selected_trades, symbol, contract = g5_mom012t_contract()) {
  contract <- g5_mom012t_validate_contract(contract)
  daily <- daily_paths[daily_paths$symbol == symbol, , drop = FALSE]
  trades <- selected_trades[selected_trades$symbol == symbol, , drop = FALSE]
  if (!nrow(daily) || !nrow(trades)) {
    g5_mom012t_stop(paste("Trade-tape source rows are missing for", symbol))
  }
  daily$outcome_date <- as.Date(daily$outcome_date)
  daily$asset_open_return <- as.numeric(daily$asset_open_return)
  daily$strategy_return <- as.numeric(daily$strategy_return)
  daily <- daily[order(daily$outcome_date), , drop = FALSE]
  if (min(daily$outcome_date) < contract$retrospective_start ||
      max(daily$outcome_date) > contract$retrospective_end ||
      any(daily$outcome_date >= contract$confirmation_start)) {
    g5_mom012t_stop("Trade-tape daily path exceeds the frozen evidence window.")
  }
  daily$buy_hold_wealth <- cumprod(1 + daily$asset_open_return)
  daily$strategy_wealth <- cumprod(1 + daily$strategy_return)
  daily$buy_hold_drawdown <- daily$buy_hold_wealth / cummax(c(1, daily$buy_hold_wealth))[-1L] - 1
  daily$strategy_drawdown <- daily$strategy_wealth / cummax(c(1, daily$strategy_wealth))[-1L] - 1
  trades$signal_date <- as.Date(trades$signal_date)
  trades$entry_date <- as.Date(trades$entry_date)
  trades$exit_date <- as.Date(trades$exit_date)
  trades$trade_return <- as.numeric(trades$trade_return)
  trades <- trades[order(trades$entry_date), , drop = FALSE]
  list(daily = daily, trades = trades)
}
