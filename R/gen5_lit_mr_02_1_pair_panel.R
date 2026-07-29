g5_mr02_panel_schema_version <- function(panel_id = "PANEL_A") {
  paste0("gen5_lit_mr_02_1_", tolower(panel_id), "_v1")
}

g5_mr02_panel_registry <- function() {
  data.frame(
    panel_id = "PANEL_A",
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
    instance_scope = c(rep("PANEL_A_PRIMARY", 12L), rep("PANEL_A_DIAGNOSTIC", 2L)),
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

g5_mr02_panel_b_registry <- function() {
  data.frame(
    panel_id = "PANEL_B",
    pair_index = 101L:115L,
    pair_id = c(
      "B01_XLP_VDC", "B02_XLU_VPU", "B03_XLRE_VNQ", "B04_XLI_VIS",
      "B05_XLY_VCR", "B06_XLE_VDE", "B07_XLV_VHT", "B08_XLF_VFH",
      "B09_XLB_VAW", "B10_ITA_XAR", "B11_IHI_XLV", "B12_XRT_XLY",
      "B13_XHB_ITB", "B14_XBI_IBB", "B15_GDX_GLD"
    ),
    symbol_y = c(
      "XLP", "XLU", "XLRE", "XLI", "XLY", "XLE", "XLV", "XLF",
      "XLB", "ITA", "IHI", "XRT", "XHB", "XBI", "GDX"
    ),
    symbol_x = c(
      "VDC", "VPU", "VNQ", "VIS", "VCR", "VDE", "VHT", "VFH",
      "VAW", "XAR", "XLV", "XLY", "ITB", "IBB", "GLD"
    ),
    pair_category = c(
      rep("sector_near_substitute", 9L),
      rep("industry_related_exposure", 5L),
      "producer_commodity_link"
    ),
    expected_relation = rep("positive", 15L),
    analysis_role = rep("PRIMARY_TRADING_TEMPLATE", 15L),
    instance_scope = rep("PANEL_B_PRIMARY", 15L),
    rationale = c(
      "Consumer-staples Select Sector SPDR versus Vanguard consumer-staples exposure",
      "Utilities Select Sector SPDR versus Vanguard utilities exposure",
      "US real-estate Select Sector SPDR versus broad US REIT exposure",
      "Industrials Select Sector SPDR versus Vanguard industrials exposure",
      "Consumer-discretionary Select Sector SPDR versus Vanguard discretionary exposure",
      "Energy Select Sector SPDR versus Vanguard energy exposure",
      "Health-care Select Sector SPDR versus Vanguard health-care exposure",
      "Financials Select Sector SPDR versus Vanguard financials exposure",
      "Materials Select Sector SPDR versus Vanguard materials exposure",
      "Market-cap-weighted versus modified-equal-weight US aerospace and defense exposure",
      "US medical-device equities versus broad US health-care exposure",
      "Retail-industry exposure versus broad consumer-discretionary exposure",
      "Broad versus concentrated US homebuilder exposure",
      "Equal-weighted versus market-cap-weighted US biotechnology exposure",
      "Gold-miner equity exposure versus physical gold exposure"
    ),
    stringsAsFactors = FALSE
  )
}

g5_mr02_relationship_atlas_registry <- function() {
  data.frame(
    panel_id = "RELATIONSHIP_ATLAS_01",
    pair_index = 201L:225L,
    pair_id = c(
      "A01_SPY_IVV", "A02_GLD_IAU", "A03_XLK_VGT", "A04_VOO_SPY",
      "A05_MDY_IJH", "A06_QQQ_XLK", "A07_TLT_IEF", "A08_HYG_LQD",
      "A09_XBI_IBB", "A10_ITA_XAR", "A11_XLE_XOM", "A12_XLF_JPM",
      "A13_XLV_JNJ", "A14_XLP_PG", "A15_SMH_NVDA", "A16_KO_PEP",
      "A17_V_MA", "A18_HD_LOW", "A19_JPM_BAC", "A20_UPS_FDX",
      "A21_GDX_GLD", "A22_XLE_USO", "A23_SIL_SLV", "A24_FCX_CPER",
      "A25_XOP_USO"
    ),
    symbol_y = c(
      "SPY", "GLD", "XLK", "VOO", "MDY", "QQQ", "TLT", "HYG",
      "XBI", "ITA", "XLE", "XLF", "XLV", "XLP", "SMH", "KO", "V",
      "HD", "JPM", "UPS", "GDX", "XLE", "SIL", "FCX", "XOP"
    ),
    symbol_x = c(
      "IVV", "IAU", "VGT", "SPY", "IJH", "XLK", "IEF", "LQD",
      "IBB", "XAR", "XOM", "JPM", "JNJ", "PG", "NVDA", "PEP", "MA",
      "LOW", "BAC", "FDX", "GLD", "USO", "SLV", "CPER", "USO"
    ),
    pair_category = rep(c(
      "etf_near_substitute",
      "etf_related_exposure",
      "etf_component_containment",
      "stock_peer_economics",
      "producer_asset_proxy"
    ), each = 5L),
    instrument_topology = rep(c(
      "ETF_ETF", "ETF_ETF", "ETF_COMPONENT", "STOCK_STOCK",
      "PRODUCER_ASSET_PROXY"
    ), each = 5L),
    economic_mechanism = c(
      "duplicate_claim", "duplicate_claim", "overlapping_basket",
      "duplicate_claim", "overlapping_basket",
      "common_factor", "curve_linkage", "credit_linkage",
      "overlapping_basket", "overlapping_basket",
      rep("constituent_containment", 5L),
      rep("peer_economics", 5L),
      rep("shared_commodity_driver", 5L)
    ),
    expected_relation = rep("positive", 25L),
    analysis_role = rep("PRIMARY_TRADING_TEMPLATE", 25L),
    instance_scope = rep("RELATIONSHIP_ATLAS_01_PRIMARY", 25L),
    rationale = c(
      "Two S&P 500 index implementations",
      "Two physically backed gold exposures",
      "Two broad US technology-sector portfolios",
      "Two S&P 500 index implementations with different sponsors",
      "Two US mid-cap index implementations",
      "Growth-heavy Nasdaq versus US technology",
      "Long- versus intermediate-duration US Treasuries",
      "High-yield versus investment-grade corporate credit",
      "Differently weighted biotechnology portfolios",
      "Differently weighted aerospace and defense portfolios",
      "Energy-sector basket versus a large component",
      "Financial-sector basket versus a large component",
      "Health-care basket versus a diversified component",
      "Staples basket versus a large component",
      "Semiconductor basket versus a major component",
      "Global non-alcoholic beverage peers",
      "Global card-network peers",
      "US home-improvement retail peers",
      "Diversified US bank peers",
      "Global parcel-delivery peers",
      "Gold miners versus physical gold",
      "Energy equities versus oil-futures proxy",
      "Silver miners versus physical silver",
      "Copper producer versus copper-futures proxy",
      "Oil-and-gas producers versus oil-futures proxy"
    ),
    stringsAsFactors = FALSE
  )
}

g5_mr02_panel_validate_registry <- function(
  registry = g5_mr02_panel_registry()
) {
  required <- c(
    "panel_id", "pair_index", "pair_id", "symbol_y", "symbol_x",
    "pair_category", "expected_relation", "analysis_role", "instance_scope",
    "rationale"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mr02_stop(paste(
      "Pair-panel registry is missing:", paste(missing, collapse = ", ")
    ))
  }
  panel_ids <- unique(as.character(registry$panel_id))
  recognized <- c("PANEL_A", "PANEL_B", "RELATIONSHIP_ATLAS_01")
  if (length(panel_ids) != 1L || !panel_ids %in% recognized) {
    g5_mr02_stop("The pair-panel identifier is not recognized.")
  }
  panel_id <- panel_ids[[1L]]
  expected_rows <- switch(
    panel_id,
    PANEL_A = 14L,
    PANEL_B = 15L,
    RELATIONSHIP_ATLAS_01 = 25L
  )
  expected_indices <- if (identical(panel_id, "PANEL_A")) {
    seq_len(14L)
  } else if (identical(panel_id, "PANEL_B")) {
    101L:115L
  } else {
    201L:225L
  }
  expected_roles <- if (identical(panel_id, "PANEL_A")) {
    c(rep("PRIMARY_TRADING_TEMPLATE", 12L), rep("DIAGNOSTIC_ONLY", 2L))
  } else {
    rep("PRIMARY_TRADING_TEMPLATE", expected_rows)
  }
  expected_scopes <- if (identical(panel_id, "PANEL_A")) {
    c(rep("PANEL_A_PRIMARY", 12L), rep("PANEL_A_DIAGNOSTIC", 2L))
  } else if (identical(panel_id, "PANEL_B")) {
    rep("PANEL_B_PRIMARY", 15L)
  } else {
    rep("RELATIONSHIP_ATLAS_01_PRIMARY", 25L)
  }
  if (nrow(registry) != expected_rows ||
      !identical(as.integer(registry$pair_index), expected_indices) ||
      anyDuplicated(registry$pair_id) ||
      any(registry$symbol_y == registry$symbol_x)) {
    g5_mr02_stop(paste("The frozen", panel_id, "identity or orientation changed."))
  }
  if (!identical(
    as.character(registry$analysis_role),
    expected_roles
  )) {
    g5_mr02_stop(paste("The frozen", panel_id, "analysis roles changed."))
  }
  if (!identical(as.character(registry$instance_scope), expected_scopes)) {
    g5_mr02_stop(paste("The frozen", panel_id, "instance scopes changed."))
  }
  if (identical(panel_id, "RELATIONSHIP_ATLAS_01")) {
    frozen <- g5_mr02_relationship_atlas_registry()
    identity_columns <- c(
      "panel_id", "pair_index", "pair_id", "symbol_y", "symbol_x",
      "pair_category", "instrument_topology", "economic_mechanism",
      "expected_relation", "analysis_role", "instance_scope", "rationale"
    )
    missing_atlas <- setdiff(identity_columns, names(registry))
    if (length(missing_atlas) ||
        !identical(registry[, identity_columns], frozen[, identity_columns])) {
      g5_mr02_stop("The frozen RELATIONSHIP_ATLAS_01 registry changed.")
    }
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
    instance_scope = registry_row$instance_scope[[1L]],
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
      "Pair-panel bars are missing:", paste(missing, collapse = ", ")
    ))
  }
  bars <- bars[bars$symbol %in% g5_mr02_panel_required_symbols(registry), required, drop = FALSE]
  bars$session_date <- as.Date(bars$session_date)
  if (anyDuplicated(bars[c("symbol", "session_date")])) {
    g5_mr02_stop("Pair-panel duplicate symbol-session bars are prohibited.")
  }
  observed <- sort(unique(bars$symbol))
  expected <- g5_mr02_panel_required_symbols(registry)
  if (!setequal(observed, expected)) {
    g5_mr02_stop(paste(
      "Pair-panel exact symbol coverage failed; missing:",
      paste(setdiff(expected, observed), collapse = ", ")
    ))
  }
  if (any(is.na(bars$session_date))) {
    g5_mr02_stop("Pair-panel session dates must be valid.")
  }
  numeric_columns <- c("open", "high", "low", "close", "volume")
  if (any(!vapply(bars[numeric_columns], is.numeric, logical(1)))) {
    g5_mr02_stop("Pair-panel OHLCV columns must be numeric.")
  }
  prices <- as.matrix(bars[c("open", "high", "low", "close")])
  if (any(!is.finite(prices)) || any(prices <= 0)) {
    g5_mr02_stop("Pair-panel prices must be finite and positive.")
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

g5_mr02_panel_empty_inverse_summary <- function() {
  data.frame(
    pair_index = integer(), pair_id = character(), symbol_y = character(),
    symbol_x = character(), pair_category = character(), rationale = character(),
    data_health_status = character(), eligible_sessions = integer(),
    positive_beta_coverage = numeric(), negative_beta_coverage = numeric(),
    median_beta = numeric(), beta_sign_changes = integer(),
    dynamic_spread_adf_t = numeric(), dynamic_spread_half_life = numeric(),
    signed_forward_correlation = numeric(), trade_replay_status = character(),
    stringsAsFactors = FALSE
  )
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
      data_health_status = data_health_status,
      allow_later_outcomes = FALSE
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
  inverse_summary <- if (length(inverse)) {
    do.call(rbind, inverse)
  } else {
    g5_mr02_panel_empty_inverse_summary()
  }
  category_summary <- g5_mr02_panel_category_summary(pair_summary)
  full_pass_count <- sum(pair_summary$full_gate_pass)
  panel_id <- unique(as.character(registry$panel_id))[[1L]]
  list(
    schema_version = g5_mr02_panel_schema_version(panel_id),
    panel_id = panel_id,
    registry = registry,
    pair_results = pair_results,
    pair_summary = pair_summary,
    gate_detail = gate_detail,
    category_summary = category_summary,
    inverse_summary = inverse_summary,
    later_outcomes_opened = FALSE,
    overall_status = if (full_pass_count > 0L) {
      paste0(
        "REVIEW_REQUIRED_LIT_MR_02_1_", panel_id,
        "_PAIR_SPECIFIC_CONFIRMATION"
      )
    } else {
      paste0("STOP_LIT_MR_02_1_", panel_id, "_NO_FULL_PASS")
    }
  )
}
