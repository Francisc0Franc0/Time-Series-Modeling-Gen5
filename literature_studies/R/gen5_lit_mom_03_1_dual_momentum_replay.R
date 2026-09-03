# Causal weekly performance replay for the admitted LIT-MOM-03.1 window.

g5_mom031r_stop <- function(message) stop(message, call. = FALSE)

g5_mom031r_schema_version <- function() "gen5_lit_mom_03_1_replay_v1"

g5_mom031r_contract <- function() {
  list(
    literature_id = "LIT-MOM-03.1",
    mechanics_schema_version = g5_mom031_schema_version(),
    replay_start = as.Date("2016-06-30"),
    replay_end = as.Date("2026-03-19"),
    cost_bps_one_way = 5,
    cash_period_return = 0,
    annualization_periods = 52,
    initial_wealth = 1,
    complete_execution_intervals_only = TRUE,
    variants = c(
      "SOURCE_DUAL_MOMENTUM",
      "EQUAL_WEIGHT_ALL_NINE",
      "RELATIVE_ONLY",
      "ABSOLUTE_ONLY",
      "SPY_OWNERSHIP",
      "CASH_NO_TRADE"
    ),
    source_variant = "SOURCE_DUAL_MOMENTUM",
    comparator_variants = c(
      "EQUAL_WEIGHT_ALL_NINE", "RELATIVE_ONLY", "ABSOLUTE_ONLY",
      "SPY_OWNERSHIP", "CASH_NO_TRADE"
    ),
    absolute_only_rule = "EACH_SLEEVE_FUNDS_ONE_EIGHTE_PER_POSITIVE_ASSET_AND_LEAVES_FAILED_SHARES_IN_CASH",
    turnover_rule = "ONE_HALF_L1_DISTANCE_INCLUDING_CASH_FROM_DRIFTED_PRETRADE_TO_TARGET",
    cost_rule = "FIVE_BPS_PER_ONE_WAY_TRADED_NOTIONAL_AT_EXECUTION_OPEN",
    final_liquidation_cost = FALSE,
    bootstrap_repetitions = 5000L,
    bootstrap_block_weeks = 8L,
    bootstrap_seed = 3101L,
    multiplicity_rule = "BH_ACROSS_FIVE_FROZEN_SOURCE_MINUS_CONTROL_COMPARISONS",
    robustness_or_forward_gate_opened = FALSE
  )
}

g5_mom031r_validate_contract <- function(contract = g5_mom031r_contract()) {
  frozen <- g5_mom031r_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom031r_stop("Frozen LIT-MOM-03.1 replay contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom031r_stop(paste(
      "Frozen LIT-MOM-03.1 replay contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom031r_weight_columns <- function(mechanics) {
  c(mechanics$contract$universe, mechanics$contract$cash_symbol)
}

g5_mom031r_source_targets <- function(mechanics) {
  universe <- mechanics$contract$universe
  weights <- as.matrix(mechanics$allocations[, paste0("weight_", universe), drop = FALSE])
  colnames(weights) <- universe
  cbind(weights, CASH = mechanics$allocations$cash_weight)
}

g5_mom031r_relative_targets <- function(mechanics) {
  universe <- mechanics$contract$universe
  decisions <- mechanics$allocations$decision_date
  slot <- mechanics$contract$sleeve_weight / mechanics$contract$top_n_per_sleeve
  out <- matrix(0, nrow = length(decisions), ncol = length(universe) + 1L)
  colnames(out) <- c(universe, mechanics$contract$cash_symbol)
  for (i in seq_along(decisions)) {
    rows <- mechanics$scores$decision_date == decisions[[i]]
    score <- mechanics$scores[rows, , drop = FALSE]
    score <- score[match(universe, score$symbol), , drop = FALSE]
    out[i, universe] <- slot * (score$rank_10w <= mechanics$contract$top_n_per_sleeve) +
      slot * (score$rank_25w <= mechanics$contract$top_n_per_sleeve)
  }
  out
}

g5_mom031r_absolute_targets <- function(mechanics) {
  universe <- mechanics$contract$universe
  decisions <- mechanics$allocations$decision_date
  per_asset_sleeve <- mechanics$contract$sleeve_weight / length(universe)
  out <- matrix(0, nrow = length(decisions), ncol = length(universe) + 1L)
  colnames(out) <- c(universe, mechanics$contract$cash_symbol)
  for (i in seq_along(decisions)) {
    rows <- mechanics$scores$decision_date == decisions[[i]]
    score <- mechanics$scores[rows, , drop = FALSE]
    score <- score[match(universe, score$symbol), , drop = FALSE]
    out[i, universe] <- per_asset_sleeve * (score$roc_10w > 0) +
      per_asset_sleeve * (score$roc_25w > 0)
    out[i, mechanics$contract$cash_symbol] <- 1 - sum(out[i, universe])
  }
  out
}

g5_mom031r_constant_targets <- function(mechanics, variant) {
  universe <- mechanics$contract$universe
  out <- matrix(
    0, nrow = nrow(mechanics$allocations), ncol = length(universe) + 1L,
    dimnames = list(NULL, c(universe, mechanics$contract$cash_symbol))
  )
  if (variant == "EQUAL_WEIGHT_ALL_NINE") {
    out[, universe] <- 1 / length(universe)
  } else if (variant == "SPY_OWNERSHIP") {
    out[, "SPY"] <- 1
  } else if (variant == "CASH_NO_TRADE") {
    out[, mechanics$contract$cash_symbol] <- 1
  } else {
    g5_mom031r_stop(paste("Unknown constant target variant:", variant))
  }
  out
}

g5_mom031r_targets <- function(
  mechanics,
  contract = g5_mom031r_contract()
) {
  contract <- g5_mom031r_validate_contract(contract)
  builders <- list(
    SOURCE_DUAL_MOMENTUM = function() g5_mom031r_source_targets(mechanics),
    EQUAL_WEIGHT_ALL_NINE = function() g5_mom031r_constant_targets(mechanics, "EQUAL_WEIGHT_ALL_NINE"),
    RELATIVE_ONLY = function() g5_mom031r_relative_targets(mechanics),
    ABSOLUTE_ONLY = function() g5_mom031r_absolute_targets(mechanics),
    SPY_OWNERSHIP = function() g5_mom031r_constant_targets(mechanics, "SPY_OWNERSHIP"),
    CASH_NO_TRADE = function() g5_mom031r_constant_targets(mechanics, "CASH_NO_TRADE")
  )
  out <- lapply(contract$variants, function(variant) builders[[variant]]())
  names(out) <- contract$variants
  expected_columns <- g5_mom031r_weight_columns(mechanics)
  for (variant in names(out)) {
    if (!identical(colnames(out[[variant]]), expected_columns)) {
      g5_mom031r_stop(paste("Target columns are misaligned for", variant))
    }
    if (any(!is.finite(out[[variant]])) || any(out[[variant]] < -1e-12)) {
      g5_mom031r_stop(paste("Target weights are invalid for", variant))
    }
    if (any(abs(rowSums(out[[variant]]) - 1) > 1e-12)) {
      g5_mom031r_stop(paste("Target weights do not sum to one for", variant))
    }
  }
  out
}

g5_mom031r_execution_intervals <- function(mechanics) {
  allocations <- mechanics$allocations
  if (nrow(allocations) < 2L) g5_mom031r_stop("At least two execution dates are required.")
  execution_dates <- as.Date(allocations$execution_date)
  if (is.unsorted(execution_dates, strictly = TRUE)) {
    g5_mom031r_stop("Execution dates must be strictly increasing.")
  }
  start_dates <- execution_dates[-length(execution_dates)]
  end_dates <- execution_dates[-1L]
  start_rows <- match(as.character(start_dates), rownames(mechanics$panel$open))
  end_rows <- match(as.character(end_dates), rownames(mechanics$panel$open))
  if (anyNA(c(start_rows, end_rows))) {
    g5_mom031r_stop("An execution date is missing from the common open matrix.")
  }
  asset_returns <- mechanics$panel$open[end_rows, , drop = FALSE] /
    mechanics$panel$open[start_rows, , drop = FALSE] - 1
  list(
    metadata = data.frame(
      interval = seq_along(start_dates),
      decision_date = allocations$decision_date[-nrow(allocations)],
      execution_date = start_dates,
      next_execution_date = end_dates,
      calendar_days = as.integer(end_dates - start_dates),
      stringsAsFactors = FALSE
    ),
    asset_returns = asset_returns
  )
}

g5_mom031r_replay_variant <- function(
  variant,
  targets,
  intervals,
  mechanics,
  contract = g5_mom031r_contract()
) {
  contract <- g5_mom031r_validate_contract(contract)
  universe <- mechanics$contract$universe
  cash <- mechanics$contract$cash_symbol
  n_periods <- nrow(intervals$metadata)
  target <- targets[seq_len(n_periods), , drop = FALSE]
  asset_returns <- intervals$asset_returns
  one_way_rate <- contract$cost_bps_one_way / 10000
  pretrade <- c(setNames(rep(0, length(universe)), universe), setNames(1, cash))
  wealth <- contract$initial_wealth
  rows <- vector("list", n_periods)
  contribution_rows <- vector("list", n_periods)
  for (i in seq_len(n_periods)) {
    target_row <- target[i, ]
    turnover <- 0.5 * sum(abs(target_row - pretrade))
    cost_fraction <- one_way_rate * turnover
    contributions <- target_row[universe] * asset_returns[i, universe]
    gross_return <- sum(contributions) + target_row[[cash]] * contract$cash_period_return
    net_return <- (1 - cost_fraction) * (1 + gross_return) - 1
    wealth_before <- wealth
    wealth <- wealth * (1 + net_return)
    rows[[i]] <- data.frame(
      variant = variant,
      intervals$metadata[i, , drop = FALSE],
      turnover_one_way = turnover,
      cost_fraction = cost_fraction,
      gross_return = gross_return,
      net_return = net_return,
      wealth_before = wealth_before,
      wealth = wealth,
      invested_target_weight = sum(target_row[universe]),
      cash_target_weight = target_row[[cash]],
      stringsAsFactors = FALSE
    )
    contribution_rows[[i]] <- data.frame(
      variant = variant,
      interval = i,
      execution_date = intervals$metadata$execution_date[[i]],
      symbol = universe,
      target_weight = as.numeric(target_row[universe]),
      asset_return = as.numeric(asset_returns[i, universe]),
      gross_contribution = as.numeric(contributions),
      stringsAsFactors = FALSE
    )
    end_values <- c(
      target_row[universe] * (1 + asset_returns[i, universe]),
      setNames(target_row[[cash]] * (1 + contract$cash_period_return), cash)
    )
    pretrade <- end_values / sum(end_values)
  }
  tape <- do.call(rbind, rows)
  tape$running_peak <- cummax(c(contract$initial_wealth, tape$wealth))[-1L]
  tape$drawdown <- tape$wealth / tape$running_peak - 1
  list(tape = tape, contributions = do.call(rbind, contribution_rows))
}

g5_mom031r_metrics <- function(tape, contract = g5_mom031r_contract()) {
  years <- as.numeric(max(tape$next_execution_date) - min(tape$execution_date)) / 365.25
  weekly_sd <- stats::sd(tape$net_return)
  gross_wealth <- prod(1 + tape$gross_return)
  data.frame(
    variant = tape$variant[[1L]],
    intervals = nrow(tape),
    start_date = min(tape$execution_date),
    end_date = max(tape$next_execution_date),
    years = years,
    ending_wealth_net = tail(tape$wealth, 1L),
    ending_wealth_gross = gross_wealth,
    total_net_return = tail(tape$wealth, 1L) - 1,
    cagr_net = tail(tape$wealth, 1L)^(1 / years) - 1,
    annualized_volatility = weekly_sd * sqrt(contract$annualization_periods),
    annualized_sharpe_zero_cash = if (weekly_sd > 0) {
      mean(tape$net_return) / weekly_sd * sqrt(contract$annualization_periods)
    } else {
      NA_real_
    },
    max_drawdown = min(tape$drawdown),
    positive_week_fraction = mean(tape$net_return > 0),
    worst_week = min(tape$net_return),
    best_week = max(tape$net_return),
    mean_invested_weight = mean(tape$invested_target_weight),
    total_one_way_turnover = sum(tape$turnover_one_way),
    annualized_one_way_turnover = sum(tape$turnover_one_way) / years,
    total_cost_fraction_charged = sum(tape$cost_fraction),
    terminal_cost_drag = gross_wealth - tail(tape$wealth, 1L),
    stringsAsFactors = FALSE
  )
}

g5_mom031r_block_bootstrap <- function(
  differences,
  contract = g5_mom031r_contract()
) {
  contract <- g5_mom031r_validate_contract(contract)
  x <- as.numeric(differences)
  n <- length(x)
  block <- min(contract$bootstrap_block_weeks, n)
  starts <- seq_len(n - block + 1L)
  blocks_needed <- ceiling(n / block)
  set.seed(contract$bootstrap_seed)
  draws <- replicate(contract$bootstrap_repetitions, {
    chosen <- sample(starts, blocks_needed, replace = TRUE)
    values <- unlist(lapply(chosen, function(start) x[start:(start + block - 1L)]), use.names = FALSE)
    mean(values[seq_len(n)])
  })
  c(
    mean_difference = mean(x),
    ci_low = unname(stats::quantile(draws, 0.025)),
    ci_high = unname(stats::quantile(draws, 0.975)),
    one_sided_p = (1 + sum(draws <= 0)) / (length(draws) + 1)
  )
}

g5_mom031r_comparisons <- function(
  weekly_tape,
  metrics,
  contract = g5_mom031r_contract()
) {
  contract <- g5_mom031r_validate_contract(contract)
  source <- weekly_tape[weekly_tape$variant == contract$source_variant, , drop = FALSE]
  rows <- lapply(contract$comparator_variants, function(comparator) {
    control <- weekly_tape[weekly_tape$variant == comparator, , drop = FALSE]
    if (!identical(source$execution_date, control$execution_date)) {
      g5_mom031r_stop(paste("Weekly comparison misalignment for", comparator))
    }
    boot <- g5_mom031r_block_bootstrap(source$net_return - control$net_return, contract)
    source_metrics <- metrics[metrics$variant == contract$source_variant, , drop = FALSE]
    control_metrics <- metrics[metrics$variant == comparator, , drop = FALSE]
    data.frame(
      source_variant = contract$source_variant,
      comparator_variant = comparator,
      intervals = nrow(source),
      mean_weekly_difference = unname(boot[["mean_difference"]]),
      block_bootstrap_ci_low = unname(boot[["ci_low"]]),
      block_bootstrap_ci_high = unname(boot[["ci_high"]]),
      one_sided_p = unname(boot[["one_sided_p"]]),
      source_cagr = source_metrics$cagr_net,
      comparator_cagr = control_metrics$cagr_net,
      cagr_difference = source_metrics$cagr_net - control_metrics$cagr_net,
      source_max_drawdown = source_metrics$max_drawdown,
      comparator_max_drawdown = control_metrics$max_drawdown,
      weekly_outperformance_fraction = mean(source$net_return > control$net_return),
      terminal_wealth_ratio = source_metrics$ending_wealth_net / control_metrics$ending_wealth_net,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$bh_q_value <- stats::p.adjust(out$one_sided_p, method = "BH")
  out$ci_excludes_zero_positive <- out$block_bootstrap_ci_low > 0
  rownames(out) <- NULL
  out
}

g5_mom031r_calendar_years <- function(weekly_tape) {
  weekly_tape$calendar_year <- format(weekly_tape$next_execution_date, "%Y")
  keys <- interaction(weekly_tape$variant, weekly_tape$calendar_year, drop = TRUE)
  rows <- lapply(split(weekly_tape, keys), function(x) data.frame(
    variant = x$variant[[1L]],
    calendar_year = as.integer(x$calendar_year[[1L]]),
    intervals = nrow(x),
    net_return = prod(1 + x$net_return) - 1,
    gross_return = prod(1 + x$gross_return) - 1,
    mean_invested_weight = mean(x$invested_target_weight),
    one_way_turnover = sum(x$turnover_one_way),
    stringsAsFactors = FALSE
  ))
  out <- do.call(rbind, rows)
  out[order(out$variant, out$calendar_year), , drop = FALSE]
}

g5_mom031r_phases <- function(weekly_tape) {
  year <- as.integer(format(weekly_tape$next_execution_date, "%Y"))
  weekly_tape$phase <- ifelse(
    year <= 2019, "2016-2019",
    ifelse(year <= 2022, "2020-2022", "2023-2026")
  )
  keys <- interaction(weekly_tape$variant, weekly_tape$phase, drop = TRUE)
  rows <- lapply(split(weekly_tape, keys), function(x) data.frame(
    variant = x$variant[[1L]],
    phase = x$phase[[1L]],
    intervals = nrow(x),
    net_return = prod(1 + x$net_return) - 1,
    mean_weekly_return = mean(x$net_return),
    max_drawdown_from_phase_start = min(cumprod(1 + x$net_return) / cummax(cumprod(1 + x$net_return)) - 1),
    mean_invested_weight = mean(x$invested_target_weight),
    stringsAsFactors = FALSE
  ))
  out <- do.call(rbind, rows)
  out[order(out$variant, out$phase), , drop = FALSE]
}

g5_mom031r_source_contribution <- function(contributions, contract = g5_mom031r_contract()) {
  source <- contributions[contributions$variant == contract$source_variant, , drop = FALSE]
  rows <- lapply(split(source, source$symbol), function(x) data.frame(
    symbol = x$symbol[[1L]],
    active_intervals = sum(x$target_weight > 0),
    mean_target_weight = mean(x$target_weight),
    mean_weekly_gross_contribution = mean(x$gross_contribution),
    sum_weekly_gross_contribution = sum(x$gross_contribution),
    stringsAsFactors = FALSE
  ))
  out <- do.call(rbind, rows)
  out[order(-out$sum_weekly_gross_contribution), , drop = FALSE]
}

g5_mom031r_representative_weeks <- function(weekly_tape, contract = g5_mom031r_contract()) {
  source <- weekly_tape[weekly_tape$variant == contract$source_variant, , drop = FALSE]
  labels <- c("worst_net_week", "best_net_week", "highest_turnover", "highest_cash")
  selected <- c(
    which.min(source$net_return),
    which.max(source$net_return),
    which.max(source$turnover_one_way),
    which.max(source$cash_target_weight)
  )
  rows <- lapply(seq_along(selected), function(i) {
    row <- source[selected[[i]], , drop = FALSE]
    row$case <- labels[[i]]
    row
  })
  out <- do.call(rbind, rows)
  out <- out[!duplicated(out$interval), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_mom031r_integrity <- function(
  mechanics,
  targets,
  intervals,
  weekly_tape,
  contract = g5_mom031r_contract()
) {
  all_target_weights <- do.call(rbind, targets)
  source <- weekly_tape[weekly_tape$variant == contract$source_variant, , drop = FALSE]
  cash <- weekly_tape[weekly_tape$variant == "CASH_NO_TRADE", , drop = FALSE]
  checks <- data.frame(
    check_id = c(
      "complete_execution_intervals_only",
      "execution_dates_within_frozen_window",
      "all_targets_sum_to_one",
      "all_targets_nonnegative",
      "one_tape_per_variant_interval",
      "costs_nonnegative_and_bounded",
      "wealth_identity_holds",
      "cash_control_stays_one",
      "source_has_no_future_signal_use",
      "final_unmatched_target_excluded",
      "robustness_and_forward_gates_closed"
    ),
    passed = c(
      nrow(intervals$metadata) == nrow(mechanics$allocations) - 1L,
      min(intervals$metadata$execution_date) >= contract$replay_start &&
        max(intervals$metadata$next_execution_date) <= contract$replay_end,
      all(abs(rowSums(all_target_weights) - 1) < 1e-12),
      all(all_target_weights >= -1e-12),
      nrow(weekly_tape) == nrow(intervals$metadata) * length(contract$variants),
      all(weekly_tape$cost_fraction >= 0 & weekly_tape$cost_fraction <= contract$cost_bps_one_way / 10000),
      all(abs(weekly_tape$wealth - weekly_tape$wealth_before * (1 + weekly_tape$net_return)) < 1e-12),
      all(abs(cash$wealth - contract$initial_wealth) < 1e-12),
      all(source$decision_date < source$execution_date),
      max(weekly_tape$next_execution_date) == tail(mechanics$allocations$execution_date, 1L),
      !contract$robustness_or_forward_gate_opened
    ),
    observed = c(
      paste(nrow(intervals$metadata), "of", nrow(mechanics$allocations) - 1L),
      paste(range(c(intervals$metadata$execution_date, intervals$metadata$next_execution_date)), collapse = " to "),
      sprintf("%.12f", max(abs(rowSums(all_target_weights) - 1))),
      as.character(min(all_target_weights)),
      paste(nrow(weekly_tape), "rows"),
      paste(range(weekly_tape$cost_fraction), collapse = " to "),
      sprintf("%.12f", max(abs(weekly_tape$wealth - weekly_tape$wealth_before * (1 + weekly_tape$net_return)))),
      paste(range(cash$wealth), collapse = " to "),
      as.character(all(source$decision_date < source$execution_date)),
      as.character(max(weekly_tape$next_execution_date)),
      as.character(contract$robustness_or_forward_gate_opened)
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  checks
}

g5_mom031r_run <- function(
  mechanics,
  contract = g5_mom031r_contract()
) {
  contract <- g5_mom031r_validate_contract(contract)
  targets <- g5_mom031r_targets(mechanics, contract)
  intervals <- g5_mom031r_execution_intervals(mechanics)
  replays <- lapply(contract$variants, function(variant) {
    g5_mom031r_replay_variant(
      variant, targets[[variant]], intervals, mechanics, contract
    )
  })
  names(replays) <- contract$variants
  weekly_tape <- do.call(rbind, lapply(replays, `[[`, "tape"))
  contributions <- do.call(rbind, lapply(replays, `[[`, "contributions"))
  rownames(weekly_tape) <- NULL
  rownames(contributions) <- NULL
  metrics <- do.call(rbind, lapply(split(weekly_tape, weekly_tape$variant), g5_mom031r_metrics, contract = contract))
  metrics <- metrics[match(contract$variants, metrics$variant), , drop = FALSE]
  comparisons <- g5_mom031r_comparisons(weekly_tape, metrics, contract)
  integrity <- g5_mom031r_integrity(mechanics, targets, intervals, weekly_tape, contract)
  if (!all(integrity$passed)) {
    g5_mom031r_stop(paste(
      "LIT-MOM-03.1 replay integrity failed:",
      paste(integrity$check_id[!integrity$passed], collapse = ", ")
    ))
  }
  list(
    contract = contract,
    targets = targets,
    intervals = intervals,
    weekly_tape = weekly_tape,
    contributions = contributions,
    metrics = metrics,
    comparisons = comparisons,
    calendar_years = g5_mom031r_calendar_years(weekly_tape),
    phases = g5_mom031r_phases(weekly_tape),
    source_contribution = g5_mom031r_source_contribution(contributions, contract),
    representative_weeks = g5_mom031r_representative_weeks(weekly_tape, contract),
    integrity = integrity
  )
}
