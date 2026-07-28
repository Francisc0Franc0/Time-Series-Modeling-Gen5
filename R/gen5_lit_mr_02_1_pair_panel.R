g5_mr02_panel_schema_version <- function() {
  "gen5_lit_mr_02_1_panel_a_v1"
}

g5_mr02_panel_registry <- function() {
  data.frame(
    pair_index = seq_len(14L),
    pair_id = c(
      "P01_IVV_SPY", "P02_IAU_GLD", "P03_SOXX_SMH", "P04_VEA_EFA",
      "P05_VWO_EEM", "P06_QQQ_XLK", "P07_IJR_IWM", "P08_KRE_XLF",
      "P09_IBB_XLV", "P10_USO_XLE", "P11_TLT_IEF", "P12_HYG_LQD",
      "D01_GLD_UUP", "D02_TLT_SPY"
    ),
    symbol_y = c(
      "IVV", "IAU", "SOXX", "VEA", "VWO", "QQQ", "IJR", "KRE",
      "IBB", "USO", "TLT", "HYG", "GLD", "TLT"
    ),
    symbol_x = c(
      "SPY", "GLD", "SMH", "EFA", "EEM", "XLK", "IWM", "XLF",
      "XLV", "XLE", "IEF", "LQD", "UUP", "SPY"
    ),
    pair_category = c(
      rep("near_substitute", 5L),
      rep("related_exposure", 7L),
      rep("inverse_challenger", 2L)
    ),
    expected_relation = c(rep("positive", 12L), rep("negative_or_unstable", 2L)),
    analysis_role = c(rep("PRIMARY_TRADING_TEMPLATE", 12L), rep("DIAGNOSTIC_ONLY", 2L)),
    rationale = c(
      "Two highly overlapping S&P 500 index ETFs",
      "Two physically backed gold exposure ETFs",
      "Two semiconductor-industry ETFs with overlapping holdings",
      "Two developed-markets ex-US equity ETFs",
      "Two broad emerging-markets equity ETFs",
      "Growth-heavy Nasdaq exposure versus US technology-sector exposure",
      "S&P SmallCap 600 versus Russell 2000 small-cap exposure",
      "Regional banks versus broad US financial-sector exposure",
      "Biotechnology versus broad US health-care exposure",
      "Oil futures exposure versus energy-equity exposure",
      "Long-duration versus intermediate-duration US Treasury exposure",
      "High-yield versus investment-grade corporate-credit exposure",
      "Gold versus US-dollar exposure as an inverse-beta contrast",
      "Long-duration Treasuries versus US equities as an unstable inverse contrast"
    ),
    stringsAsFactors = FALSE
  )
}

g5_mr02_panel_validate_registry <- function(
  registry = g5_mr02_panel_registry()
) {
  required <- c(
    "pair_index", "pair_id", "symbol_y", "symbol_x", "pair_category",
    "expected_relation", "analysis_role", "rationale"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mr02_stop(paste(
      "PANEL-A registry is missing:", paste(missing, collapse = ", ")
    ))
  }
  if (nrow(registry) != 14L ||
      !identical(as.integer(registry$pair_index), seq_len(14L)) ||
      anyDuplicated(registry$pair_id) ||
      any(registry$symbol_y == registry$symbol_x)) {
    g5_mr02_stop("The frozen PANEL-A identity or orientation changed.")
  }
  if (!identical(
    as.character(registry$analysis_role),
    c(rep("PRIMARY_TRADING_TEMPLATE", 12L), rep("DIAGNOSTIC_ONLY", 2L))
  )) {
    g5_mr02_stop("The frozen PANEL-A primary and diagnostic roles changed.")
  }
  registry
}

g5_mr02_panel_required_symbols <- function(
  registry = g5_mr02_panel_registry()
) {
  registry <- g5_mr02_panel_validate_registry(registry)
  sort(unique(c(registry$symbol_y, registry$symbol_x)))
}

g5_mr02_panel_instance_contract <- function(registry_row) {
  role <- as.character(registry_row$analysis_role[[1L]])
  g5_mr02_pair_contract(
    symbol_y = registry_row$symbol_y[[1L]],
    symbol_x = registry_row$symbol_x[[1L]],
    instance_id = registry_row$pair_id[[1L]],
    pair_category = registry_row$pair_category[[1L]],
    pair_rationale = registry_row$rationale[[1L]],
    instance_scope = if (identical(role, "DIAGNOSTIC_ONLY")) {
      "PANEL_A_DIAGNOSTIC"
    } else {
      "PANEL_A_PRIMARY"
    },
    pair_index = registry_row$pair_index[[1L]]
  )
}

g5_mr02_panel_validate_bars <- function(
  bars,
  registry = g5_mr02_panel_registry()
) {
  registry <- g5_mr02_panel_validate_registry(registry)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_mr02_stop(paste(
      "PANEL-A bars are missing:", paste(missing, collapse = ", ")
    ))
  }
  bars <- bars[bars$symbol %in% g5_mr02_panel_required_symbols(registry), required, drop = FALSE]
  bars$session_date <- as.Date(bars$session_date)
  if (anyDuplicated(bars[c("symbol", "session_date")])) {
    g5_mr02_stop("PANEL-A duplicate symbol-session bars are prohibited.")
  }
  observed <- sort(unique(bars$symbol))
  expected <- g5_mr02_panel_required_symbols(registry)
  if (!setequal(observed, expected)) {
    g5_mr02_stop(paste(
      "PANEL-A exact symbol coverage failed; missing:",
      paste(setdiff(expected, observed), collapse = ", ")
    ))
  }
  if (any(is.na(bars$session_date))) {
    g5_mr02_stop("PANEL-A session dates must be valid.")
  }
  numeric_columns <- c("open", "high", "low", "close", "volume")
  if (any(!vapply(bars[numeric_columns], is.numeric, logical(1)))) {
    g5_mr02_stop("PANEL-A OHLCV columns must be numeric.")
  }
  prices <- as.matrix(bars[c("open", "high", "low", "close")])
  if (any(!is.finite(prices)) || any(prices <= 0)) {
    g5_mr02_stop("PANEL-A prices must be finite and positive.")
  }
  bars[order(bars$session_date, bars$symbol), , drop = FALSE]
}

g5_mr02_panel_positive_beta_coverage <- function(indicators, contract) {
  eligible <- indicators[
    indicators$session_date >= contract$train_start &
      indicators$session_date <= contract$train_end &
      is.finite(indicators$z_score),
    ,
    drop = FALSE
  ]
  if (!nrow(eligible)) return(NA_real_)
  mean(is.finite(eligible$beta) & eligible$beta > 0)
}

g5_mr02_panel_pair_summary <- function(result, registry_row) {
  completed <- result$train_trades[result$train_trades$completed, , drop = FALSE]
  bootstrap <- result$train_bootstrap$summary
  convergence <- result$train_convergence_bootstrap$summary
  diagnostics <- result$train_diagnostics
  metrics <- result$train_metrics
  positive_years <- sum(result$train_years$primary_net_return > 0)
  data.frame(
    pair_index = registry_row$pair_index[[1L]],
    pair_id = registry_row$pair_id[[1L]],
    symbol_y = registry_row$symbol_y[[1L]],
    symbol_x = registry_row$symbol_x[[1L]],
    pair_category = registry_row$pair_category[[1L]],
    rationale = registry_row$rationale[[1L]],
    positive_beta_coverage = g5_mr02_panel_positive_beta_coverage(
      result$train_indicators, result$contract
    ),
    completed_trades = nrow(completed),
    long_spread_trades = sum(completed$direction == 1L),
    short_spread_trades = sum(completed$direction == -1L),
    mean_net_trade_return = if (nrow(completed)) {
      mean(completed$primary_net_additive_return)
    } else {
      NA_real_
    },
    trade_bootstrap_lower_95 = bootstrap$lower_95,
    trade_bootstrap_upper_95 = bootstrap$upper_95,
    hit_rate = if (nrow(completed)) {
      mean(completed$primary_net_additive_return > 0)
    } else {
      NA_real_
    },
    random_sign_p90 = result$train_random$p90,
    positive_years = positive_years,
    train_years = nrow(result$train_years),
    forward_correlation = convergence$correlation,
    forward_lower_95 = convergence$lower_95,
    forward_upper_95 = convergence$upper_95,
    dynamic_spread_adf_t = diagnostics$dynamic_spread_adf_t,
    dynamic_spread_half_life = diagnostics$dynamic_spread_half_life,
    bar_cumulative_return = metrics$cumulative_return,
    adjusted_sharpe = metrics$autocorrelation_adjusted_sharpe,
    maximum_drawdown = metrics$maximum_drawdown,
    gates_passed = sum(result$train_gates$status == "PASS"),
    gates_total = nrow(result$train_gates),
    full_gate_pass = all(result$train_gates$status == "PASS"),
    later_outcomes_opened = isTRUE(result$later_outcomes_opened),
    stringsAsFactors = FALSE
  )
}

g5_mr02_panel_signed_forward_convergence <- function(
  indicators,
  contract,
  horizon = 5L
) {
  rows <- list()
  n <- nrow(indicators)
  if (n <= horizon + 1L) {
    return(data.frame(
      signal_date = as.Date(character()), z_score = numeric(),
      forward_5_session_spread_return = numeric()
    ))
  }
  for (i in seq_len(n - horizon - 1L)) {
    z <- indicators$z_score[[i]]
    beta <- indicators$beta[[i]]
    if (!is.finite(z) || !is.finite(beta) || abs(beta) < 1e-12) next
    entry_i <- i + 1L
    exit_i <- i + 1L + horizon
    gross <- indicators$open_y[[entry_i]] +
      abs(beta) * indicators$open_x[[entry_i]]
    w_y <- indicators$open_y[[entry_i]] / gross
    w_x <- -beta * indicators$open_x[[entry_i]] / gross
    rows[[length(rows) + 1L]] <- data.frame(
      signal_date = indicators$session_date[[i]],
      z_score = z,
      forward_5_session_spread_return =
        w_y * (indicators$open_y[[exit_i]] / indicators$open_y[[entry_i]] - 1) +
        w_x * (indicators$open_x[[exit_i]] / indicators$open_x[[entry_i]] - 1)
    )
  }
  if (!length(rows)) {
    return(data.frame(
      signal_date = as.Date(character()), z_score = numeric(),
      forward_5_session_spread_return = numeric()
    ))
  }
  do.call(rbind, rows)
}

g5_mr02_panel_inverse_diagnostic <- function(
  bars,
  registry_row,
  data_health_status = "PASS"
) {
  contract <- g5_mr02_panel_instance_contract(registry_row)
  pair_bars <- g5_mr02_validate_bars(bars, contract)
  pair_bars <- pair_bars[pair_bars$session_date <= contract$train_end, , drop = FALSE]
  indicators <- g5_mr02_rolling_indicators(
    g5_mr02_common_panel(pair_bars, contract), contract
  )
  eligible <- indicators[
    indicators$session_date >= contract$train_start &
      indicators$session_date <= contract$train_end &
      is.finite(indicators$z_score) & is.finite(indicators$beta),
    ,
    drop = FALSE
  ]
  convergence <- g5_mr02_panel_signed_forward_convergence(indicators, contract)
  convergence <- convergence[
    convergence$signal_date >= contract$train_start &
      convergence$signal_date <= contract$train_end,
    ,
    drop = FALSE
  ]
  correlation <- if (nrow(convergence) >= 3L) {
    stats::cor(
      convergence$z_score,
      convergence$forward_5_session_spread_return
    )
  } else {
    NA_real_
  }
  diagnostics <- g5_mr02_statistical_diagnostics(indicators, contract)
  data.frame(
    pair_index = registry_row$pair_index[[1L]],
    pair_id = registry_row$pair_id[[1L]],
    symbol_y = registry_row$symbol_y[[1L]],
    symbol_x = registry_row$symbol_x[[1L]],
    pair_category = registry_row$pair_category[[1L]],
    rationale = registry_row$rationale[[1L]],
    data_health_status = data_health_status,
    eligible_sessions = nrow(eligible),
    positive_beta_coverage = if (nrow(eligible)) mean(eligible$beta > 0) else NA_real_,
    negative_beta_coverage = if (nrow(eligible)) mean(eligible$beta < 0) else NA_real_,
    median_beta = if (nrow(eligible)) stats::median(eligible$beta) else NA_real_,
    beta_sign_changes = if (nrow(eligible) > 1L) {
      sum(sign(eligible$beta[-1L]) != sign(eligible$beta[-nrow(eligible)]))
    } else {
      NA_integer_
    },
    dynamic_spread_adf_t = diagnostics$dynamic_spread_adf_t,
    dynamic_spread_half_life = diagnostics$dynamic_spread_half_life,
    signed_forward_correlation = correlation,
    trade_replay_status = "NOT_RUN_NEGATIVE_BETA_CHANGES_POSITION_SEMANTICS",
    stringsAsFactors = FALSE
  )
}

g5_mr02_panel_category_summary <- function(pair_summary) {
  categories <- sort(unique(pair_summary$pair_category))
  rows <- lapply(categories, function(category) {
    x <- pair_summary[pair_summary$pair_category == category, , drop = FALSE]
    data.frame(
      pair_category = category,
      pairs = nrow(x),
      full_gate_pass_pairs = sum(x$full_gate_pass),
      positive_mean_net_pairs = sum(x$mean_net_trade_return > 0, na.rm = TRUE),
      negative_forward_pairs = sum(x$forward_correlation < 0, na.rm = TRUE),
      median_mean_net_trade_return = stats::median(
        x$mean_net_trade_return, na.rm = TRUE
      ),
      median_hit_rate = stats::median(x$hit_rate, na.rm = TRUE),
      median_positive_beta_coverage = stats::median(
        x$positive_beta_coverage, na.rm = TRUE
      ),
      median_bar_cumulative_return = stats::median(
        x$bar_cumulative_return, na.rm = TRUE
      ),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_mr02_panel_run <- function(
  bars,
  registry = g5_mr02_panel_registry(),
  data_health_status = "PASS"
) {
  registry <- g5_mr02_panel_validate_registry(registry)
  bars <- g5_mr02_panel_validate_bars(bars, registry)
  bars <- bars[bars$session_date <= as.Date("2020-12-31"), , drop = FALSE]
  primary_registry <- registry[
    registry$analysis_role == "PRIMARY_TRADING_TEMPLATE", ,
    drop = FALSE
  ]
  diagnostic_registry <- registry[
    registry$analysis_role == "DIAGNOSTIC_ONLY", ,
    drop = FALSE
  ]
  pair_results <- vector("list", nrow(primary_registry))
  names(pair_results) <- primary_registry$pair_id
  pair_summaries <- vector("list", nrow(primary_registry))
  gate_details <- vector("list", nrow(primary_registry))
  for (i in seq_len(nrow(primary_registry))) {
    row <- primary_registry[i, , drop = FALSE]
    contract <- g5_mr02_panel_instance_contract(row)
    result <- g5_mr02_run_analysis(
      bars = bars,
      contract = contract,
      data_health_status = data_health_status
    )
    pair_results[[i]] <- result
    pair_summaries[[i]] <- g5_mr02_panel_pair_summary(result, row)
    gates <- result$train_gates
    gates$pair_index <- row$pair_index[[1L]]
    gates$pair_id <- row$pair_id[[1L]]
    gates$pair_category <- row$pair_category[[1L]]
    gate_details[[i]] <- gates[
      , c("pair_index", "pair_id", "pair_category", "gate_id", "gate",
          "status", "details"),
      drop = FALSE
    ]
  }
  inverse <- lapply(seq_len(nrow(diagnostic_registry)), function(i) {
    g5_mr02_panel_inverse_diagnostic(
      bars, diagnostic_registry[i, , drop = FALSE], data_health_status
    )
  })
  pair_summary <- do.call(rbind, pair_summaries)
  gate_detail <- do.call(rbind, gate_details)
  inverse_summary <- do.call(rbind, inverse)
  category_summary <- g5_mr02_panel_category_summary(pair_summary)
  full_pass_count <- sum(pair_summary$full_gate_pass)
  list(
    schema_version = g5_mr02_panel_schema_version(),
    registry = registry,
    pair_results = pair_results,
    pair_summary = pair_summary,
    gate_detail = gate_detail,
    category_summary = category_summary,
    inverse_summary = inverse_summary,
    later_outcomes_opened = FALSE,
    overall_status = if (full_pass_count > 0L) {
      "REVIEW_REQUIRED_LIT_MR_02_1_PANEL_A_PAIR_SPECIFIC_CONFIRMATION"
    } else {
      "STOP_LIT_MR_02_1_PANEL_A_NO_FULL_PASS"
    }
  )
}
