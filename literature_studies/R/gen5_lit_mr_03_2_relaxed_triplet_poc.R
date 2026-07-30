g5_mr032_schema_version <- function() {
  "gen5_lit_mr_03_2_v1"
}

g5_mr032_stop <- function(message) {
  stop(paste0("[Gen5 LIT-MR-03.2] ", message), call. = FALSE)
}

g5_mr032_contract <- function() {
  list(
    literature_id = "LIT-MR-03.2",
    as_of_timestamp = "2026-07-24 17:30:00",
    train_start = as.Date("2016-01-04"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-01"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-01"),
    minimum_vector_cosine = 0.80,
    minimum_half_life = 2,
    maximum_half_life = 90,
    minimum_completed_trades = 24L,
    minimum_trades_each_direction = 8L,
    trade_lower_probability = 0.10,
    convergence_upper_probability = 0.90
  )
}

g5_mr032_validate_contract <- function(contract = g5_mr032_contract()) {
  if (!identical(contract, g5_mr032_contract())) {
    g5_mr032_stop("The frozen LIT-MR-03.2 gate contract changed.")
  }
  contract
}

g5_mr032_fresh_registry <- function() {
  data.frame(
    triplet_index = 201L:220L,
    triplet_id = c(
      "F01_VTI_SCHB_ITOT", "F02_VOO_IVV_SPLG", "F03_SCHF_VEA_IEFA",
      "F04_SCHD_VYM_HDV", "F05_XSD_SOXX_SMH", "F06_XPH_PJP_IHE",
      "F07_KIE_IAK_XLF", "F08_XME_PICK_REMX", "F09_SHY_VGSH_SPTS",
      "F10_IEI_VGIT_SPTI", "F11_TLT_VGLT_SPTL", "F12_LQD_VCIT_IGIB",
      "F13_XLI_CAT_DE", "F14_XLK_MSFT_ORCL", "F15_XLP_KO_PEP",
      "F16_XLV_UNH_ELV", "F17_XOM_CVX_COP", "F18_CAT_DE_CMI",
      "F19_WMT_TGT_COST", "F20_UNP_CSX_NSC"
    ),
    symbol_1 = c(
      "VTI", "VOO", "SCHF", "SCHD", "XSD", "XPH", "KIE", "XME",
      "SHY", "IEI", "TLT", "LQD", "XLI", "XLK", "XLP", "XLV",
      "XOM", "CAT", "WMT", "UNP"
    ),
    symbol_2 = c(
      "SCHB", "IVV", "VEA", "VYM", "SOXX", "PJP", "IAK", "PICK",
      "VGSH", "VGIT", "VGLT", "VCIT", "CAT", "MSFT", "KO", "UNH",
      "CVX", "DE", "TGT", "CSX"
    ),
    symbol_3 = c(
      "ITOT", "SPLG", "IEFA", "HDV", "SMH", "IHE", "XLF", "REMX",
      "SPTS", "SPTI", "SPTL", "IGIB", "DE", "ORCL", "PEP", "ELV",
      "COP", "CMI", "COST", "NSC"
    ),
    triplet_category = rep(
      c(
        "etf_near_substitute", "sector_industry_triangle",
        "term_credit_structure", "basket_components",
        "stock_peer_triangle"
      ),
      each = 4L
    ),
    rationale = c(
      "Total-US-market implementations",
      "S&P 500 implementations",
      "Developed-markets ex-US implementations",
      "Dividend-oriented US equity portfolios",
      "Differently weighted semiconductor portfolios",
      "Differently weighted pharmaceutical portfolios",
      "Insurance portfolios with a broad financial anchor",
      "Mining portfolios with different commodity emphasis",
      "Short Treasury portfolios",
      "Intermediate Treasury portfolios",
      "Long Treasury portfolios",
      "Investment-grade corporate bond portfolios",
      "Industrials basket and heavy-equipment leaders",
      "Technology basket and mature software leaders",
      "Staples basket and beverage leaders",
      "Health-care basket and managed-care leaders",
      "Large oil and gas producers",
      "Heavy-equipment and engine manufacturers",
      "Large US general-merchandise retailers",
      "Large US freight railroads"
    ),
    source_batch = "",
    source_id = "",
    stringsAsFactors = FALSE
  )
}

g5_mr032_retrospective_registry <- function() {
  core <- g5_mr03_registry()
  core$source_batch <- "CORE"
  core$source_id <- core$triplet_id
  atlas <- g5_mr03_atlas_registry()
  atlas$source_batch <- "TRIPLET_ATLAS_01"
  atlas$source_id <- atlas$triplet_id
  rbind(core, atlas)
}

g5_mr032_registry_for_lane <- function(
  lane = c("RETROSPECTIVE", "FRESH_ATLAS_01")
) {
  lane <- match.arg(lane)
  if (identical(lane, "RETROSPECTIVE")) {
    g5_mr032_retrospective_registry()
  } else {
    g5_mr032_fresh_registry()
  }
}

g5_mr032_validate_registry <- function(
  registry,
  lane = c("RETROSPECTIVE", "FRESH_ATLAS_01")
) {
  lane <- match.arg(lane)
  frozen <- g5_mr032_registry_for_lane(lane)
  required <- names(frozen)
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mr032_stop(paste("Registry is missing:", paste(missing, collapse = ", ")))
  }
  if (!identical(registry[, required], frozen[, required])) {
    g5_mr032_stop(paste("The frozen", lane, "triplet registry changed."))
  }
  registry
}

g5_mr032_required_symbols <- function(registry, lane) {
  registry <- g5_mr032_validate_registry(registry, lane)
  sort(unique(unlist(registry[c("symbol_1", "symbol_2", "symbol_3")])))
}

g5_mr032_quantile <- function(x, probability) {
  x <- as.numeric(x[is.finite(x)])
  if (!length(x)) return(NA_real_)
  unname(stats::quantile(x, probability, names = FALSE))
}

g5_mr032_relaxed_gates <- function(
  result,
  contract = g5_mr032_contract()
) {
  contract <- g5_mr032_validate_contract(contract)
  completed <- result$trades[result$trades$completed, , drop = FALSE]
  long_count <- sum(completed$direction == 1L)
  short_count <- sum(completed$direction == -1L)
  mean_trade <- if (nrow(completed)) {
    mean(completed$primary_net_additive_return)
  } else {
    NA_real_
  }
  trade_q10 <- g5_mr032_quantile(
    result$trade_bootstrap$draws$mean_primary_net_trade_return,
    contract$trade_lower_probability
  )
  convergence_q90 <- g5_mr032_quantile(
    result$convergence_bootstrap$draws$correlation,
    contract$convergence_upper_probability
  )
  base_contract <- g5_mr03_contract()
  i1_pass <- all(result$adf$level_adf_t > base_contract$adf_threshold) &&
    all(result$adf$difference_adf_t < base_contract$adf_threshold)
  values <- c(
    all(result$integrity$status == "PASS"),
    i1_pass,
    isTRUE(result$johansen_bootstrap$summary$rank_one),
    is.finite(result$stability$cosine) &&
      result$stability$cosine >= contract$minimum_vector_cosine,
    is.finite(result$summary$spread_half_life) &&
      result$summary$spread_half_life >= contract$minimum_half_life &&
      result$summary$spread_half_life <= contract$maximum_half_life,
    nrow(completed) >= contract$minimum_completed_trades &&
      long_count >= contract$minimum_trades_each_direction &&
      short_count >= contract$minimum_trades_each_direction,
    is.finite(mean_trade) && mean_trade > 0 &&
      is.finite(trade_q10) && trade_q10 > 0,
    is.finite(result$convergence_bootstrap$summary$correlation) &&
      result$convergence_bootstrap$summary$correlation < 0 &&
      is.finite(convergence_q90) && convergence_q90 < 0
  )
  data.frame(
    gate_id = paste0("R", seq_along(values)),
    gate = c(
      "Integrity, timing, accounting, and mixed-sign vector",
      "All three components satisfy the frozen I(1) diagnostic",
      "Johansen bootstrap supports rank exactly one",
      "Split-TRAIN dollar-exposure cosine is at least 0.80",
      "TRAIN spread half-life is between 2 and 90 sessions",
      "At least 24 completed trades and 8 each direction",
      "Positive mean net trade return with bootstrap q10 above zero",
      "Negative forward convergence with bootstrap q90 below zero"
    ),
    status = ifelse(values, "PASS", "FAIL"),
    details = c(
      sprintf(
        "%d / %d",
        sum(result$integrity$status == "PASS"),
        nrow(result$integrity)
      ),
      paste(
        sprintf(
          "%s L %.3f D %.3f",
          result$adf$symbol,
          result$adf$level_adf_t,
          result$adf$difference_adf_t
        ),
        collapse = "; "
      ),
      sprintf(
        "p(rank0)=%.4f; p(rank<=1)=%.4f",
        result$johansen_bootstrap$summary$p_rank_0,
        result$johansen_bootstrap$summary$p_rank_at_most_1
      ),
      sprintf("%.4f", result$stability$cosine),
      sprintf("%.2f sessions", result$summary$spread_half_life),
      sprintf(
        "%d completed; %d long; %d short",
        nrow(completed), long_count, short_count
      ),
      sprintf("%.6f; q10 %.6f", mean_trade, trade_q10),
      sprintf(
        "%.6f; q90 %.6f",
        result$convergence_bootstrap$summary$correlation,
        convergence_q90
      )
    ),
    stringsAsFactors = FALSE
  )
}

g5_mr032_candidate_summary <- function(result, registry_row, relaxed_gates) {
  strict <- result$gates
  data.frame(
    lane = ifelse(
      nzchar(registry_row$source_batch[[1L]]),
      "RETROSPECTIVE",
      "FRESH_ATLAS_01"
    ),
    triplet_index = registry_row$triplet_index[[1L]],
    triplet_id = registry_row$triplet_id[[1L]],
    source_batch = registry_row$source_batch[[1L]],
    source_id = registry_row$source_id[[1L]],
    triplet_category = registry_row$triplet_category[[1L]],
    symbol_1 = registry_row$symbol_1[[1L]],
    symbol_2 = registry_row$symbol_2[[1L]],
    symbol_3 = registry_row$symbol_3[[1L]],
    rank_one = result$summary$rank_one,
    vector_cosine = result$summary$vector_cosine,
    spread_half_life = result$summary$spread_half_life,
    completed_trades = result$summary$completed_trades,
    long_trades = result$summary$long_trades,
    short_trades = result$summary$short_trades,
    mean_net_trade_return = result$summary$mean_net_trade_return,
    trade_q10 = g5_mr032_quantile(
      result$trade_bootstrap$draws$mean_primary_net_trade_return, 0.10
    ),
    hit_rate = result$summary$hit_rate,
    forward_correlation = result$summary$forward_correlation,
    forward_q90 = g5_mr032_quantile(
      result$convergence_bootstrap$draws$correlation, 0.90
    ),
    strict_gates_passed = sum(strict$status == "PASS"),
    strict_full_pass = all(strict$status == "PASS"),
    relaxed_gates_passed = sum(relaxed_gates$status == "PASS"),
    relaxed_gates_total = nrow(relaxed_gates),
    relaxed_full_pass = all(relaxed_gates$status == "PASS"),
    stringsAsFactors = FALSE
  )
}

g5_mr032_ineligible_summary <- function(registry_row) {
  data.frame(
    lane = ifelse(
      nzchar(registry_row$source_batch[[1L]]),
      "RETROSPECTIVE",
      "FRESH_ATLAS_01"
    ),
    triplet_index = registry_row$triplet_index[[1L]],
    triplet_id = registry_row$triplet_id[[1L]],
    source_batch = registry_row$source_batch[[1L]],
    source_id = registry_row$source_id[[1L]],
    triplet_category = registry_row$triplet_category[[1L]],
    symbol_1 = registry_row$symbol_1[[1L]],
    symbol_2 = registry_row$symbol_2[[1L]],
    symbol_3 = registry_row$symbol_3[[1L]],
    rank_one = NA,
    vector_cosine = NA_real_,
    spread_half_life = NA_real_,
    completed_trades = NA_integer_,
    long_trades = NA_integer_,
    short_trades = NA_integer_,
    mean_net_trade_return = NA_real_,
    trade_q10 = NA_real_,
    hit_rate = NA_real_,
    forward_correlation = NA_real_,
    forward_q90 = NA_real_,
    strict_gates_passed = 0L,
    strict_full_pass = FALSE,
    relaxed_gates_passed = 0L,
    relaxed_gates_total = 8L,
    relaxed_full_pass = FALSE,
    stringsAsFactors = FALSE
  )
}

g5_mr032_run_train_batch <- function(
  bars,
  registry,
  lane = c("RETROSPECTIVE", "FRESH_ATLAS_01"),
  data_health_status = "PASS",
  coverage_status = NULL
) {
  lane <- match.arg(lane)
  registry <- g5_mr032_validate_registry(registry, lane)
  if (is.null(coverage_status)) {
    coverage_status <- stats::setNames(
      rep("PASS", nrow(registry)),
      registry$triplet_id
    )
  }
  if (!all(registry$triplet_id %in% names(coverage_status))) {
    g5_mr032_stop("Coverage status must name every frozen triplet.")
  }
  results <- vector("list", nrow(registry))
  names(results) <- registry$triplet_id
  summaries <- vector("list", nrow(registry))
  relaxed_details <- vector("list", nrow(registry))
  strict_details <- vector("list", nrow(registry))
  for (i in seq_len(nrow(registry))) {
    row <- registry[i, , drop = FALSE]
    if (!identical(coverage_status[[row$triplet_id[[1L]]]], "PASS")) {
      relaxed <- data.frame(
        gate_id = paste0("R", 1:8),
        gate = c(
          "Integrity, timing, accounting, and mixed-sign vector",
          "All three components satisfy the frozen I(1) diagnostic",
          "Johansen bootstrap supports rank exactly one",
          "Split-TRAIN dollar-exposure cosine is at least 0.80",
          "TRAIN spread half-life is between 2 and 90 sessions",
          "At least 24 completed trades and 8 each direction",
          "Positive mean net trade return with bootstrap q10 above zero",
          "Negative forward convergence with bootstrap q90 below zero"
        ),
        status = c("FAIL", rep("NOT_RUN", 7L)),
        details = c(
          "candidate failed exact requested-session coverage",
          rep("not run after coverage failure", 7L)
        ),
        stringsAsFactors = FALSE
      )
      strict <- data.frame(
        gate_id = paste0("G", 1:8),
        gate = g5_mr03_train_gates(
          integrity = data.frame(status = "FAIL"),
          adf = data.frame(
            symbol = c("X", "Y", "Z"),
            level_adf_t = NA_real_,
            difference_adf_t = NA_real_
          ),
          johansen = list(
            rank_one = FALSE,
            p_rank_0 = NA_real_,
            p_rank_at_most_1 = NA_real_
          ),
          stability = list(cosine = NA_real_),
          half_life = NA_real_,
          trades = data.frame(
            completed = logical(),
            direction = integer(),
            primary_net_additive_return = numeric()
          ),
          trade_bootstrap = data.frame(lower_95 = NA_real_),
          convergence_bootstrap = data.frame(
            correlation = NA_real_,
            upper_95 = NA_real_
          )
        )$gate,
        status = c("FAIL", rep("NOT_RUN", 7L)),
        details = c(
          "candidate failed exact requested-session coverage",
          rep("not run after coverage failure", 7L)
        ),
        stringsAsFactors = FALSE
      )
      results[[i]] <- list(
        registry_row = row,
        base_result = NULL,
        relaxed_gates = relaxed,
        coverage_status = "FAIL"
      )
      summaries[[i]] <- g5_mr032_ineligible_summary(row)
      relaxed$triplet_id <- row$triplet_id[[1L]]
      relaxed$triplet_index <- row$triplet_index[[1L]]
      relaxed_details[[i]] <- relaxed
      strict$triplet_id <- row$triplet_id[[1L]]
      strict$triplet_index <- row$triplet_index[[1L]]
      strict_details[[i]] <- strict
      next
    }
    result <- g5_mr03_run_train_triplet(
      bars,
      row,
      data_health_status = data_health_status,
      contract = g5_mr03_contract()
    )
    relaxed <- g5_mr032_relaxed_gates(result)
    results[[i]] <- list(
      registry_row = row,
      base_result = result,
      relaxed_gates = relaxed
    )
    summaries[[i]] <- g5_mr032_candidate_summary(result, row, relaxed)
    relaxed$triplet_id <- row$triplet_id[[1L]]
    relaxed$triplet_index <- row$triplet_index[[1L]]
    relaxed_details[[i]] <- relaxed
    strict <- result$gates
    strict$triplet_id <- row$triplet_id[[1L]]
    strict$triplet_index <- row$triplet_index[[1L]]
    strict_details[[i]] <- strict
  }
  summary <- do.call(rbind, summaries)
  passes <- summary[summary$relaxed_full_pass, , drop = FALSE]
  nominated <- if (
    identical(lane, "FRESH_ATLAS_01") && nrow(passes)
  ) {
    passes$triplet_id[[1L]]
  } else {
    NA_character_
  }
  list(
    schema_version = g5_mr032_schema_version(),
    lane = lane,
    registry = registry,
    results = results,
    summary = summary,
    relaxed_gate_detail = do.call(rbind, relaxed_details),
    strict_gate_detail = do.call(rbind, strict_details),
    relaxed_pass_ids = passes$triplet_id,
    nominated_triplet_id = nominated,
    later_outcomes_opened = FALSE,
    overall_status = if (identical(lane, "RETROSPECTIVE")) {
      "TRAIN_COMPLETE_LIT_MR_03_2_RETROSPECTIVE"
    } else if (is.na(nominated)) {
      "STOP_LIT_MR_03_2_FRESH_ATLAS_01_NO_PASS"
    } else {
      "TRAIN_NOMINATION_LIT_MR_03_2_FRESH_ATLAS_01_DEVELOPMENT_AUTHORIZED"
    }
  )
}

g5_mr032_run_development <- function(
  bars,
  train_result,
  data_health_status = "PASS"
) {
  g5_mr03_run_development(
    bars = bars,
    train_result = train_result$base_result,
    data_health_status = data_health_status,
    contract = g5_mr03_contract()
  )
}
