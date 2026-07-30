g5_mr022_schema_version <- function() {
  "gen5_lit_mr_02_2_v1"
}

g5_mr022_stop <- function(message) {
  stop(paste0("[Gen5 LIT-MR-02.2] ", message), call. = FALSE)
}

g5_mr022_contract <- function() {
  list(
    literature_id = "LIT-MR-02.2",
    as_of_timestamp = "2026-07-24 17:30:00",
    train_start = as.Date("2016-01-04"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-01"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-01"),
    minimum_positive_beta_coverage = 0.95,
    minimum_completed_trades = 24L,
    minimum_trades_each_direction = 8L,
    trade_lower_probability = 0.10,
    convergence_upper_probability = 0.90,
    random_sign_percentile = 0.90
  )
}

g5_mr022_validate_contract <- function(contract = g5_mr022_contract()) {
  frozen <- g5_mr022_contract()
  if (!identical(contract, frozen)) {
    g5_mr022_stop("The frozen LIT-MR-02.2 gate contract changed.")
  }
  contract
}

g5_mr022_registry_columns <- function() {
  c(
    "lane", "candidate_index", "candidate_id", "symbol_y", "symbol_x",
    "candidate_category", "rationale", "source_batch", "source_id"
  )
}

g5_mr022_fresh_registry <- function() {
  data.frame(
    lane = "FRESH_ATLAS_01",
    candidate_index = 301L:320L,
    candidate_id = c(
      "F01_SCHX_VOO", "F02_SCHB_VTI", "F03_SPTM_ITOT", "F04_SCHF_VEA",
      "F05_SCHD_VYM", "F06_SPLV_USMV", "F07_IUSV_VTV", "F08_IUSG_VUG",
      "F09_XME_PICK", "F10_KIE_IAK", "F11_XSD_SOXX", "F12_XPH_PJP",
      "F13_SHY_VGSH", "F14_IEI_VGIT", "F15_TLT_VGLT", "F16_VCIT_LQD",
      "F17_XOM_CVX", "F18_CAT_DE", "F19_WMT_TGT", "F20_UNP_CSX"
    ),
    symbol_y = c(
      "SCHX", "SCHB", "SPTM", "SCHF", "SCHD", "SPLV", "IUSV", "IUSG",
      "XME", "KIE", "XSD", "XPH", "SHY", "IEI", "TLT", "VCIT",
      "XOM", "CAT", "WMT", "UNP"
    ),
    symbol_x = c(
      "VOO", "VTI", "ITOT", "VEA", "VYM", "USMV", "VTV", "VUG",
      "PICK", "IAK", "SOXX", "PJP", "VGSH", "VGIT", "VGLT", "LQD",
      "CVX", "DE", "TGT", "CSX"
    ),
    candidate_category = rep(
      c(
        "broad_etf_substitute", "factor_style_etf", "industry_etf",
        "term_credit", "stock_peer"
      ),
      each = 4L
    ),
    rationale = c(
      "Broad US large-cap implementations",
      "Broad total-US-market implementations",
      "Broad investable US equity implementations",
      "Developed-markets ex-US implementations",
      "Dividend-oriented US equity portfolios",
      "Low-volatility US equity portfolios",
      "Broad US value portfolios",
      "Broad US growth portfolios",
      "Metals and mining equity portfolios",
      "US insurance equity portfolios",
      "Differently weighted semiconductor portfolios",
      "Differently weighted pharmaceutical portfolios",
      "Short Treasury portfolios",
      "Intermediate Treasury portfolios",
      "Long Treasury portfolios",
      "Investment-grade corporate bond portfolios",
      "Integrated oil majors",
      "Global heavy-equipment manufacturers",
      "Large US general-merchandise retailers",
      "Large US freight railroads"
    ),
    source_batch = "",
    source_id = "",
    stringsAsFactors = FALSE
  )
}

g5_mr022_retrospective_registry <- function() {
  canonical <- data.frame(
    source_batch = "CANONICAL",
    source_id = "CANON_USO_GLD",
    symbol_y = "USO",
    symbol_x = "GLD",
    candidate_category = "canonical_literature",
    rationale = "Chan Example 3.2 literature pair",
    stringsAsFactors = FALSE
  )
  convert <- function(registry, source_batch) {
    registry <- registry[
      registry$analysis_role == "PRIMARY_TRADING_TEMPLATE", ,
      drop = FALSE
    ]
    data.frame(
      source_batch = source_batch,
      source_id = registry$pair_id,
      symbol_y = registry$symbol_y,
      symbol_x = registry$symbol_x,
      candidate_category = registry$pair_category,
      rationale = registry$rationale,
      stringsAsFactors = FALSE
    )
  }
  combined <- rbind(
    canonical,
    convert(g5_mr02_panel_registry(), "PANEL_A"),
    convert(g5_mr02_panel_b_registry(), "PANEL_B"),
    convert(g5_mr02_relationship_atlas_registry(), "RELATIONSHIP_ATLAS_01")
  )
  keys <- vapply(seq_len(nrow(combined)), function(i) {
    paste(sort(c(combined$symbol_y[[i]], combined$symbol_x[[i]])), collapse = "|")
  }, character(1))
  combined <- combined[!duplicated(keys), , drop = FALSE]
  data.frame(
    lane = "RETROSPECTIVE",
    candidate_index = seq_len(nrow(combined)),
    candidate_id = sprintf(
      "R%02d_%s", seq_len(nrow(combined)), combined$source_id
    ),
    symbol_y = combined$symbol_y,
    symbol_x = combined$symbol_x,
    candidate_category = combined$candidate_category,
    rationale = combined$rationale,
    source_batch = combined$source_batch,
    source_id = combined$source_id,
    stringsAsFactors = FALSE
  )
}

g5_mr022_registry_for_lane <- function(
  lane = c("RETROSPECTIVE", "FRESH_ATLAS_01")
) {
  lane <- match.arg(lane)
  if (identical(lane, "RETROSPECTIVE")) {
    g5_mr022_retrospective_registry()
  } else {
    g5_mr022_fresh_registry()
  }
}

g5_mr022_validate_registry <- function(
  registry,
  lane = c("RETROSPECTIVE", "FRESH_ATLAS_01")
) {
  lane <- match.arg(lane)
  required <- g5_mr022_registry_columns()
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mr022_stop(paste("Registry is missing:", paste(missing, collapse = ", ")))
  }
  frozen <- g5_mr022_registry_for_lane(lane)
  if (!identical(registry[, required], frozen[, required])) {
    g5_mr022_stop(paste("The frozen", lane, "pair registry changed."))
  }
  if (any(registry$symbol_y == registry$symbol_x) ||
      anyDuplicated(registry$candidate_id)) {
    g5_mr022_stop("Pair identities must be unique and use distinct symbols.")
  }
  registry
}

g5_mr022_required_symbols <- function(registry, lane) {
  registry <- g5_mr022_validate_registry(registry, lane)
  sort(unique(c(registry$symbol_y, registry$symbol_x)))
}

g5_mr022_instance_contract <- function(registry_row) {
  g5_mr02_pair_contract(
    symbol_y = registry_row$symbol_y[[1L]],
    symbol_x = registry_row$symbol_x[[1L]],
    instance_id = registry_row$candidate_id[[1L]],
    pair_category = registry_row$candidate_category[[1L]],
    pair_rationale = registry_row$rationale[[1L]],
    instance_scope = "RELATIONSHIP_ATLAS_01_PRIMARY",
    pair_index = 500L + as.integer(registry_row$candidate_index[[1L]])
  )
}

g5_mr022_quantile <- function(x, probability) {
  x <- as.numeric(x[is.finite(x)])
  if (!length(x)) return(NA_real_)
  unname(stats::quantile(x, probability, names = FALSE))
}

g5_mr022_relaxed_gates <- function(
  result,
  contract = g5_mr022_contract()
) {
  contract <- g5_mr022_validate_contract(contract)
  indicators <- result$train_indicators
  base_contract <- result$contract
  eligible <- indicators[
    indicators$session_date >= base_contract$train_start &
      indicators$session_date <= base_contract$train_end &
      is.finite(indicators$z_score),
    ,
    drop = FALSE
  ]
  positive_beta_coverage <- if (nrow(eligible)) {
    mean(is.finite(eligible$beta) & eligible$beta > 0)
  } else {
    0
  }
  completed <- result$train_trades[
    result$train_trades$completed, ,
    drop = FALSE
  ]
  long_count <- sum(completed$direction == 1L)
  short_count <- sum(completed$direction == -1L)
  mean_trade <- if (nrow(completed)) {
    mean(completed$primary_net_additive_return)
  } else {
    NA_real_
  }
  hit_rate <- if (nrow(completed)) {
    mean(completed$primary_net_additive_return > 0)
  } else {
    NA_real_
  }
  positive_years <- sum(result$train_years$primary_net_return > 0)
  trade_q10 <- g5_mr022_quantile(
    result$train_bootstrap$draws$mean_primary_net_trade_return,
    contract$trade_lower_probability
  )
  convergence_q90 <- g5_mr022_quantile(
    result$train_convergence_bootstrap$draws$correlation,
    contract$convergence_upper_probability
  )
  mandatory_values <- c(
    all(result$train_integrity$status == "PASS"),
    positive_beta_coverage >= contract$minimum_positive_beta_coverage,
    nrow(completed) >= contract$minimum_completed_trades &&
      long_count >= contract$minimum_trades_each_direction &&
      short_count >= contract$minimum_trades_each_direction,
    is.finite(mean_trade) && mean_trade > 0 &&
      is.finite(trade_q10) && trade_q10 > 0,
    is.finite(mean_trade) && is.finite(result$train_random$p90) &&
      mean_trade > result$train_random$p90,
    is.finite(result$train_convergence_bootstrap$summary$correlation) &&
      result$train_convergence_bootstrap$summary$correlation < 0 &&
      is.finite(convergence_q90) && convergence_q90 < 0
  )
  mandatory <- data.frame(
    gate_id = paste0("R", seq_along(mandatory_values)),
    gate_role = "MANDATORY",
    gate = c(
      "Integrity, timing, partitions, and accounting",
      "Positive rolling beta coverage at least 95%",
      "At least 24 completed trades and 8 each direction",
      "Positive mean net trade return with bootstrap q10 above zero",
      "Observed mean net trade return beats random-sign p90",
      "Negative forward convergence with bootstrap q90 below zero"
    ),
    status = ifelse(mandatory_values, "PASS", "FAIL"),
    details = c(
      sprintf(
        "%d / %d",
        sum(result$train_integrity$status == "PASS"),
        nrow(result$train_integrity)
      ),
      sprintf("%.4f", positive_beta_coverage),
      sprintf(
        "%d completed; %d long; %d short",
        nrow(completed), long_count, short_count
      ),
      sprintf("%.6f; q10 %.6f", mean_trade, trade_q10),
      sprintf("%.6f vs p90 %.6f", mean_trade, result$train_random$p90),
      sprintf(
        "%.6f; q90 %.6f",
        result$train_convergence_bootstrap$summary$correlation,
        convergence_q90
      )
    ),
    stringsAsFactors = FALSE
  )
  diagnostics <- data.frame(
    gate_id = c("D1", "D2"),
    gate_role = "DIAGNOSTIC",
    gate = c(
      "Completed-trade hit rate",
      "Positive primary-cost TRAIN calendar years"
    ),
    status = "REPORTED",
    details = c(
      sprintf("%.4f", hit_rate),
      sprintf("%d / %d", positive_years, nrow(result$train_years))
    ),
    stringsAsFactors = FALSE
  )
  rbind(mandatory, diagnostics)
}

g5_mr022_candidate_summary <- function(result, registry_row, relaxed_gates) {
  completed <- result$train_trades[
    result$train_trades$completed, ,
    drop = FALSE
  ]
  mandatory <- relaxed_gates[relaxed_gates$gate_role == "MANDATORY", , drop = FALSE]
  data.frame(
    lane = registry_row$lane[[1L]],
    candidate_index = registry_row$candidate_index[[1L]],
    candidate_id = registry_row$candidate_id[[1L]],
    source_batch = registry_row$source_batch[[1L]],
    source_id = registry_row$source_id[[1L]],
    symbol_y = registry_row$symbol_y[[1L]],
    symbol_x = registry_row$symbol_x[[1L]],
    candidate_category = registry_row$candidate_category[[1L]],
    positive_beta_coverage = g5_mr02_panel_positive_beta_coverage(
      result$train_indicators, result$contract
    ),
    completed_trades = nrow(completed),
    long_trades = sum(completed$direction == 1L),
    short_trades = sum(completed$direction == -1L),
    mean_net_trade_return = if (nrow(completed)) {
      mean(completed$primary_net_additive_return)
    } else {
      NA_real_
    },
    trade_q10 = g5_mr022_quantile(
      result$train_bootstrap$draws$mean_primary_net_trade_return, 0.10
    ),
    hit_rate = if (nrow(completed)) {
      mean(completed$primary_net_additive_return > 0)
    } else {
      NA_real_
    },
    random_sign_p90 = result$train_random$p90,
    positive_years = sum(result$train_years$primary_net_return > 0),
    forward_correlation =
      result$train_convergence_bootstrap$summary$correlation,
    forward_q90 = g5_mr022_quantile(
      result$train_convergence_bootstrap$draws$correlation, 0.90
    ),
    strict_gates_passed = sum(result$train_gates$status == "PASS"),
    strict_full_pass = all(result$train_gates$status == "PASS"),
    relaxed_gates_passed = sum(mandatory$status == "PASS"),
    relaxed_gates_total = nrow(mandatory),
    relaxed_full_pass = all(mandatory$status == "PASS"),
    stringsAsFactors = FALSE
  )
}

g5_mr022_run_train_batch <- function(
  bars,
  registry,
  lane = c("RETROSPECTIVE", "FRESH_ATLAS_01"),
  data_health_status = "PASS"
) {
  lane <- match.arg(lane)
  registry <- g5_mr022_validate_registry(registry, lane)
  results <- vector("list", nrow(registry))
  names(results) <- registry$candidate_id
  summaries <- vector("list", nrow(registry))
  gates <- vector("list", nrow(registry))
  strict_gates <- vector("list", nrow(registry))
  for (i in seq_len(nrow(registry))) {
    row <- registry[i, , drop = FALSE]
    base_result <- g5_mr02_run_analysis(
      bars = bars,
      contract = g5_mr022_instance_contract(row),
      data_health_status = data_health_status,
      allow_later_outcomes = FALSE
    )
    relaxed <- g5_mr022_relaxed_gates(base_result)
    results[[i]] <- list(
      registry_row = row,
      base_result = base_result,
      relaxed_gates = relaxed
    )
    summaries[[i]] <- g5_mr022_candidate_summary(base_result, row, relaxed)
    relaxed$candidate_id <- row$candidate_id[[1L]]
    relaxed$candidate_index <- row$candidate_index[[1L]]
    gates[[i]] <- relaxed
    strict <- base_result$train_gates
    strict$candidate_id <- row$candidate_id[[1L]]
    strict$candidate_index <- row$candidate_index[[1L]]
    strict_gates[[i]] <- strict
  }
  summary <- do.call(rbind, summaries)
  relaxed_gate_detail <- do.call(rbind, gates)
  strict_gate_detail <- do.call(rbind, strict_gates)
  passes <- summary[summary$relaxed_full_pass, , drop = FALSE]
  nominated <- if (
    identical(lane, "FRESH_ATLAS_01") && nrow(passes)
  ) {
    passes$candidate_id[[1L]]
  } else {
    NA_character_
  }
  list(
    schema_version = g5_mr022_schema_version(),
    lane = lane,
    registry = registry,
    results = results,
    summary = summary,
    relaxed_gate_detail = relaxed_gate_detail,
    strict_gate_detail = strict_gate_detail,
    relaxed_pass_ids = passes$candidate_id,
    nominated_candidate_id = nominated,
    later_outcomes_opened = FALSE,
    overall_status = if (identical(lane, "RETROSPECTIVE")) {
      "TRAIN_COMPLETE_LIT_MR_02_2_RETROSPECTIVE"
    } else if (is.na(nominated)) {
      "STOP_LIT_MR_02_2_FRESH_ATLAS_01_NO_PASS"
    } else {
      "TRAIN_NOMINATION_LIT_MR_02_2_FRESH_ATLAS_01_DEVELOPMENT_AUTHORIZED"
    }
  )
}

g5_mr022_run_development <- function(
  bars,
  train_result,
  data_health_status = "PASS"
) {
  contract <- train_result$base_result$contract
  contract$query_end <- contract$development_end
  contract <- g5_mr02_validate_contract(contract)
  validated <- g5_mr02_validate_bars(bars, contract)
  indicators <- g5_mr02_signal_states(
    g5_mr02_rolling_indicators(
      g5_mr02_common_panel(validated, contract),
      contract
    ),
    contract
  )
  replay <- g5_mr02_build_replay(indicators, contract)
  replay <- replay[replay$evaluation_period == "DEVELOPMENT", , drop = FALSE]
  if (!nrow(replay) ||
      any(!is.finite(replay$primary_net_return)) ||
      any(!is.finite(replay$stress_net_return))) {
    g5_mr022_stop(
      "DEVELOPMENT replay is empty or contains non-finite returns."
    )
  }
  trades <- g5_mr02_trade_summary(replay)
  completed <- trades[trades$completed, , drop = FALSE]
  convergence <- g5_mr02_forward_convergence(indicators, contract)
  convergence <- convergence[
    convergence$evaluation_period == "DEVELOPMENT", ,
    drop = FALSE
  ]
  metrics <- g5_mr02_performance_metrics(replay)
  row <- train_result$registry_row
  list(
    replay = replay,
    trades = trades,
    convergence = convergence,
    summary = data.frame(
      candidate_id = row$candidate_id[[1L]],
      source_id = row$source_id[[1L]],
      symbol_y = row$symbol_y[[1L]],
      symbol_x = row$symbol_x[[1L]],
      completed_trades = nrow(completed),
      long_trades = sum(completed$direction == 1L),
      short_trades = sum(completed$direction == -1L),
      mean_net_trade_return = if (nrow(completed)) {
        mean(completed$primary_net_additive_return)
      } else {
        NA_real_
      },
      hit_rate = if (nrow(completed)) {
        mean(completed$primary_net_additive_return > 0)
      } else {
        NA_real_
      },
      forward_correlation = if (nrow(convergence) >= 3L) {
        stats::cor(
          convergence$z_score,
          convergence$forward_5_session_spread_return
        )
      } else {
        NA_real_
      },
      cumulative_return = metrics$cumulative_return,
      stress_cumulative_return =
        prod(1 + replay$stress_net_return) - 1,
      naive_sharpe = metrics$naive_sharpe,
      autocorrelation_adjusted_sharpe =
        metrics$autocorrelation_adjusted_sharpe,
      maximum_drawdown = metrics$maximum_drawdown,
      data_health_status = data_health_status,
      stringsAsFactors = FALSE
    )
  )
}
