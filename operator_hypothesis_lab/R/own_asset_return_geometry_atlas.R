oarga_stop <- function(message) stop(paste0("[OWN-ASSET-RETURN-ATLAS] ", message), call. = FALSE)

oarga_contract <- function() {
  list(
    atlas_id = "OWN_ASSET_RETURN_GEOMETRY_ATLAS_01",
    expected_asset_count = 30L,
    expected_group_count = 6L,
    assets_per_group = 5L,
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    as_of_timestamp = "2026-08-26 17:30:00 America/New_York",
    horizons = c(1L, 2L, 3L, 4L, 5L, 10L, 15L, 20L, 25L),
    er_window = 20L,
    er_cutoff = 0.30,
    atr_length = 14L,
    atr_percentile_lookback = 252L,
    atr_low_enter = 0.30,
    atr_low_exit = 0.40,
    atr_high_exit = 0.60,
    atr_high_enter = 0.70,
    minimum_state_observations = 30L,
    minimum_branch_observations = 30L
  )
}

oarga_expected_registry <- function() {
  data.frame(
    atlas_order = seq_len(30L),
    symbol = c(
      "TSLA", "AMD", "NVDA", "GME", "AMC",
      "AAPL", "MSFT", "AMZN", "GOOGL", "CRM",
      "JPM", "CAT", "XOM", "BA", "F",
      "JNJ", "PG", "KO", "WMT", "PEP",
      "SPY", "QQQ", "IWM", "DIA", "SMH",
      "TLT", "IEF", "GLD", "SLV", "USO"
    ),
    behavior_group = rep(c(
      "Operator high beta", "Mature growth", "Cyclical or value",
      "Defensive equity", "Equity ETF", "Non-equity proxy"
    ), each = 5L),
    instrument_type = c(rep("Stock", 20L), rep("ETF", 10L)),
    selection_role = c(
      "discovery_reference", "operator_interest", "operator_interest",
      "meme_challenger", "meme_challenger", rep("balancing_member", 25L)
    ),
    selection_rule = c(
      rep("operator_named_reference_or_high_beta_challenger_with_full_2018_2023_history", 5L),
      rep("large_established_growth_stock_with_full_2018_2023_history", 5L),
      rep("established_cyclical_or_value_stock_with_full_2018_2023_history", 5L),
      rep("established_defensive_stock_with_full_2018_2023_history", 5L),
      rep("broad_or_sector_equity_etf_with_full_2018_2023_history", 5L),
      rep("fixed_income_or_commodity_proxy_with_full_2018_2023_history", 5L)
    ),
    stringsAsFactors = FALSE
  )
}

oarga_validate_registry <- function(registry, contract = oarga_contract()) {
  expected <- oarga_expected_registry()
  missing <- setdiff(names(expected), names(registry))
  if (length(missing)) oarga_stop(paste("Registry is missing:", paste(missing, collapse = ", ")))
  x <- registry[names(expected)]
  x$atlas_order <- as.integer(x$atlas_order)
  for (field in setdiff(names(expected), "atlas_order")) x[[field]] <- as.character(x[[field]])
  x <- x[order(x$atlas_order), , drop = FALSE]
  rownames(x) <- NULL
  if (!identical(x, expected)) oarga_stop("Frozen atlas registry changed.")
  if (nrow(x) != contract$expected_asset_count ||
      length(unique(x$behavior_group)) != contract$expected_group_count ||
      any(table(x$behavior_group) != contract$assets_per_group)) {
    oarga_stop("Frozen atlas dimensions changed.")
  }
  x
}

oarga_assert_bars <- function(bars, symbol, contract = oarga_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) oarga_stop(paste("Bars are missing:", paste(missing, collapse = ", ")))
  x <- bars[as.character(bars$symbol) == symbol, required, drop = FALSE]
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  x <- x[order(x$session_date), , drop = FALSE]
  if (!nrow(x) || anyDuplicated(x$session_date) || any(diff(x$session_date) <= 0)) {
    oarga_stop(paste(symbol, "bars are empty, duplicated, or unordered."))
  }
  numeric_fields <- c("open", "high", "low", "close", "volume")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  if (any(!is.finite(as.matrix(x[numeric_fields]))) || any(x$close <= 0) ||
      !all(x$adjusted %in% TRUE) || !all(x$timeframe == "1D")) {
    oarga_stop(paste(symbol, "bars violate the adjusted-daily contract."))
  }
  if (min(x$session_date) > contract$query_start || max(x$session_date) < contract$analysis_end) {
    oarga_stop(paste(symbol, "does not cover the frozen query window."))
  }
  x[x$session_date >= contract$query_start & x$session_date <= contract$analysis_end, , drop = FALSE]
}

oarga_build_ledger <- function(bars, symbol, contract = oarga_contract()) {
  x <- oarga_assert_bars(bars, symbol, contract)
  log_close <- log(x$close)
  signed_er <- tsder_signed_efficiency_ratio(log_close, contract$er_window)
  tr <- hreg_true_range(x$high, x$low, x$close)
  atr <- hreg_wilder_atr(tr, contract$atr_length)
  atr_percent <- 100 * atr / x$close
  atr_percentile <- hreg_rolling_percentile(atr_percent, contract$atr_percentile_lookback)
  atr_state <- hreg_hysteretic_state(
    atr_percentile, contract$atr_low_enter, contract$atr_low_exit,
    contract$atr_high_exit, contract$atr_high_enter
  )
  data.frame(
    symbol = symbol,
    session_date = x$session_date,
    open = x$open,
    high = x$high,
    low = x$low,
    close = x$close,
    log_close = log_close,
    signed_er20 = signed_er,
    er20 = abs(signed_er),
    er20_state = ifelse(is.na(signed_er), NA_character_, ifelse(abs(signed_er) >= contract$er_cutoff, "GREEN_TRENDING", "RED_SIDEWAYS")),
    signed_er20_state = tsder_classify_direction(signed_er, contract$er_cutoff),
    atr_percent = atr_percent,
    atr_percentile = atr_percentile,
    atrp_state = atr_state,
    stringsAsFactors = FALSE
  )
}

oarga_construct_surface <- function(ledger, prior_sessions, forward_sessions,
                                    contract = oarga_contract()) {
  prior_sessions <- as.integer(prior_sessions)
  forward_sessions <- as.integer(forward_sessions)
  anchors <- seq_len(nrow(ledger))
  usable <- anchors - prior_sessions >= 1L & anchors + forward_sessions <= nrow(ledger)
  anchors <- anchors[usable]
  keep <- ledger$session_date[anchors] >= contract$analysis_start &
    ledger$session_date[anchors + forward_sessions] <= contract$analysis_end
  anchors <- anchors[keep]
  if (!length(anchors)) oarga_stop("No complete observations for a horizon cell.")
  data.frame(
    symbol = ledger$symbol[anchors],
    anchor_session = ledger$session_date[anchors],
    forward_end_session = ledger$session_date[anchors + forward_sessions],
    prior_cumulative_log_return = log(ledger$close[anchors] / ledger$close[anchors - prior_sessions]),
    forward_cumulative_log_return = log(ledger$close[anchors + forward_sessions] / ledger$close[anchors]),
    er20_state = ledger$er20_state[anchors],
    atrp_state = ledger$atrp_state[anchors],
    signed_er20_state = ledger$signed_er20_state[anchors],
    stringsAsFactors = FALSE
  )
}

oarga_condition_specs <- function() {
  list(
    UNFILTERED = list(column = NULL, states = "ALL", pairs = list()),
    ER20 = list(
      column = "er20_state", states = c("RED_SIDEWAYS", "GREEN_TRENDING"),
      pairs = list(c("RED_SIDEWAYS", "GREEN_TRENDING"))
    ),
    ATRP = list(
      column = "atrp_state", states = c("LOW", "MEDIUM", "HIGH"),
      pairs = list(c("LOW", "MEDIUM"), c("LOW", "HIGH"), c("MEDIUM", "HIGH"))
    ),
    SIGNED_ER20 = list(
      column = "signed_er20_state", states = c("UP_TREND", "SIDEWAYS", "DOWN_TREND"),
      pairs = list(c("SIDEWAYS", "UP_TREND"), c("SIDEWAYS", "DOWN_TREND"), c("DOWN_TREND", "UP_TREND"))
    )
  )
}

oarga_describe_state <- function(surface, state, state_column = NULL,
                                 minimum_observations = 30L) {
  sample <- if (is.null(state_column)) surface else surface[surface[[state_column]] == state, , drop = FALSE]
  x <- sample$prior_cumulative_log_return
  y <- sample$forward_cumulative_log_return
  n <- length(y)
  estimable <- n >= minimum_observations && stats::sd(x) > 0 && stats::sd(y) > 0
  data.frame(
    state = state, observations = n,
    estimation_status = if (estimable) "DESCRIBED" else "INSUFFICIENT_STATE_OBSERVATIONS",
    pearson_correlation = if (estimable) stats::cor(x, y) else NA_real_,
    spearman_correlation = if (estimable) suppressWarnings(stats::cor(x, y, method = "spearman")) else NA_real_,
    ols_slope = if (estimable) unname(stats::coef(stats::lm(y ~ x))[["x"]]) else NA_real_,
    mean_forward_return = if (n) mean(y) else NA_real_,
    probability_forward_up = if (n) mean(y > 0) else NA_real_,
    stringsAsFactors = FALSE
  )
}

oarga_describe_comparison <- function(surface, reference_state, contrast_state,
                                      state_column, minimum_observations = 30L) {
  reference <- oarga_describe_state(surface, reference_state, state_column, minimum_observations)
  contrast <- oarga_describe_state(surface, contrast_state, state_column, minimum_observations)
  data.frame(
    reference_state = reference_state, contrast_state = contrast_state,
    reference_observations = reference$observations,
    contrast_observations = contrast$observations,
    estimation_status = if (reference$estimation_status == "DESCRIBED" && contrast$estimation_status == "DESCRIBED") "DESCRIBED" else "INSUFFICIENT_PAIR_OBSERVATIONS",
    reference_pearson_correlation = reference$pearson_correlation,
    contrast_pearson_correlation = contrast$pearson_correlation,
    contrast_minus_reference_pearson = contrast$pearson_correlation - reference$pearson_correlation,
    contrast_minus_reference_ols_slope = contrast$ols_slope - reference$ols_slope,
    stringsAsFactors = FALSE
  )
}

oarga_describe_sign <- function(surface, state, state_column = NULL,
                                minimum_branch_observations = 30L) {
  sample <- if (is.null(state_column)) surface else surface[surface[[state_column]] == state, , drop = FALSE]
  sample <- sample[sample$prior_cumulative_log_return != 0, , drop = FALSE]
  negative <- sample[sample$prior_cumulative_log_return < 0, , drop = FALSE]
  positive <- sample[sample$prior_cumulative_log_return > 0, , drop = FALSE]
  branch <- function(x) {
    n <- nrow(x)
    ok <- n >= minimum_branch_observations && stats::sd(x$prior_cumulative_log_return) > 0 && stats::sd(x$forward_cumulative_log_return) > 0
    list(
      n = n,
      correlation = if (ok) stats::cor(x$prior_cumulative_log_return, x$forward_cumulative_log_return) else NA_real_,
      slope = if (ok) unname(stats::coef(stats::lm(forward_cumulative_log_return ~ prior_cumulative_log_return, data = x))[["prior_cumulative_log_return"]]) else NA_real_,
      mean = if (n) mean(x$forward_cumulative_log_return) else NA_real_,
      probability_up = if (n) mean(x$forward_cumulative_log_return > 0) else NA_real_
    )
  }
  neg <- branch(negative)
  pos <- branch(positive)
  estimable <- neg$n >= minimum_branch_observations && pos$n >= minimum_branch_observations &&
    is.finite(neg$correlation) && is.finite(pos$correlation)
  data.frame(
    state = state, observations = nrow(sample), negative_observations = neg$n,
    positive_observations = pos$n, minimum_branch_observations = min(neg$n, pos$n),
    estimation_status = if (estimable) "DESCRIBED" else "STRUCTURALLY_OR_EMPIRICALLY_SPARSE_BRANCH",
    negative_pearson_correlation = neg$correlation,
    positive_pearson_correlation = pos$correlation,
    positive_minus_negative_pearson = pos$correlation - neg$correlation,
    negative_ols_slope = neg$slope, positive_ols_slope = pos$slope,
    positive_minus_negative_ols_slope = pos$slope - neg$slope,
    negative_mean_forward_return = neg$mean, positive_mean_forward_return = pos$mean,
    negative_probability_forward_up = neg$probability_up,
    positive_probability_forward_up = pos$probability_up,
    stringsAsFactors = FALSE
  )
}

oarga_measure_asset <- function(ledger, contract = oarga_contract()) {
  specs <- oarga_condition_specs()
  state_rows <- list(); comparison_rows <- list(); sign_rows <- list()
  state_index <- 0L; comparison_index <- 0L; sign_index <- 0L
  for (prior_sessions in contract$horizons) {
    for (forward_sessions in contract$horizons) {
      surface <- oarga_construct_surface(ledger, prior_sessions, forward_sessions, contract)
      for (condition in names(specs)) {
        spec <- specs[[condition]]
        for (state in spec$states) {
          state_index <- state_index + 1L
          row <- oarga_describe_state(surface, state, spec$column, contract$minimum_state_observations)
          row$symbol <- ledger$symbol[[1L]]; row$condition <- condition
          row$prior_sessions <- prior_sessions; row$forward_sessions <- forward_sessions
          state_rows[[state_index]] <- row
          sign_index <- sign_index + 1L
          sign_row <- oarga_describe_sign(surface, state, spec$column, contract$minimum_branch_observations)
          sign_row$symbol <- ledger$symbol[[1L]]; sign_row$condition <- condition
          sign_row$prior_sessions <- prior_sessions; sign_row$forward_sessions <- forward_sessions
          sign_rows[[sign_index]] <- sign_row
        }
        for (pair in spec$pairs) {
          comparison_index <- comparison_index + 1L
          comparison <- oarga_describe_comparison(
            surface, pair[[1L]], pair[[2L]], spec$column, contract$minimum_state_observations
          )
          comparison$symbol <- ledger$symbol[[1L]]; comparison$condition <- condition
          comparison$prior_sessions <- prior_sessions; comparison$forward_sessions <- forward_sessions
          comparison_rows[[comparison_index]] <- comparison
        }
      }
    }
  }
  list(
    state = do.call(rbind, state_rows),
    comparison = do.call(rbind, comparison_rows),
    sign = do.call(rbind, sign_rows)
  )
}

oarga_fixed_inference <- function(ledger, contract = oarga_contract()) {
  symbol <- ledger$symbol[[1L]]
  rows <- list(); index <- 0L
  add_sign <- function(prior, forward, condition, state, column, test_id) {
    surface <- oarga_construct_surface(ledger, prior, forward, contract)
    surface$direction_state <- if (is.null(column)) "ALL" else surface[[column]]
    result <- tsseg_measure_sign_asymmetry(surface, state, prior, forward, contract$minimum_branch_observations)
    data.frame(
      symbol = symbol, test_id = test_id, test_family = "PRIOR_SIGN_INTERACTION",
      condition = condition, state = state, prior_sessions = prior, forward_sessions = forward,
      observations = result$observations, minimum_branch_observations = result$minimum_branch_observations,
      effect = result$positive_minus_negative_ols_slope,
      descriptive_correlation_effect = result$positive_minus_negative_pearson,
      hac_lower_95 = result$slope_interaction_hac_lower_95,
      hac_upper_95 = result$slope_interaction_hac_upper_95,
      hac_p_value = result$slope_interaction_hac_p_value,
      estimation_status = result$estimation_status,
      stringsAsFactors = FALSE
    )
  }
  for (cell in list(c(1L, 1L), c(20L, 4L), c(20L, 5L), c(20L, 10L))) {
    index <- index + 1L
    rows[[index]] <- add_sign(cell[[1L]], cell[[2L]], "UNFILTERED", "ALL", NULL,
      paste0("UNFILTERED_SIGN_P", cell[[1L]], "_F", cell[[2L]]))
  }
  surface_20_20 <- oarga_construct_surface(ledger, 20L, 20L, contract)
  surface_20_20$direction_state <- surface_20_20$signed_er20_state
  state <- tsseg_measure_state(surface_20_20, "DOWN_TREND", 20L, 20L, contract$minimum_state_observations)
  index <- index + 1L
  rows[[index]] <- data.frame(
    symbol = symbol, test_id = "SIGNED_ER20_DOWN_STATE_P20_F20", test_family = "STATE_SLOPE",
    condition = "SIGNED_ER20", state = "DOWN_TREND", prior_sessions = 20L, forward_sessions = 20L,
    observations = state$observations, minimum_branch_observations = NA_integer_, effect = state$ols_slope,
    descriptive_correlation_effect = state$pearson_correlation,
    hac_lower_95 = state$slope_hac_lower_95, hac_upper_95 = state$slope_hac_upper_95,
    hac_p_value = state$slope_hac_p_value, estimation_status = state$estimation_status,
    stringsAsFactors = FALSE
  )
  comparison <- tsseg_compare_states(surface_20_20, "SIDEWAYS", "DOWN_TREND", 20L, 20L, contract$minimum_state_observations)
  index <- index + 1L
  rows[[index]] <- data.frame(
    symbol = symbol, test_id = "SIGNED_ER20_DOWN_MINUS_SIDEWAYS_P20_F20", test_family = "STATE_INTERACTION",
    condition = "SIGNED_ER20", state = "DOWN_MINUS_SIDEWAYS", prior_sessions = 20L, forward_sessions = 20L,
    observations = comparison$reference_observations + comparison$contrast_observations,
    minimum_branch_observations = min(comparison$reference_observations, comparison$contrast_observations),
    effect = comparison$contrast_minus_reference_ols_slope,
    descriptive_correlation_effect = comparison$contrast_minus_reference_pearson,
    hac_lower_95 = comparison$interaction_hac_lower_95, hac_upper_95 = comparison$interaction_hac_upper_95,
    hac_p_value = comparison$interaction_hac_p_value, estimation_status = comparison$estimation_status,
    stringsAsFactors = FALSE
  )
  index <- index + 1L
  rows[[index]] <- add_sign(5L, 20L, "SIGNED_ER20", "DOWN_TREND", "signed_er20_state", "SIGNED_ER20_DOWN_SIGN_P5_F20")
  output <- do.call(rbind, rows)
  rownames(output) <- NULL
  output
}
