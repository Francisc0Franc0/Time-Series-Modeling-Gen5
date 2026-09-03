# Ex-ante deployment-cohort replay for the LIT-MOM-03 ranking principle.

g5_mom034_stop <- function(message) stop(message, call. = FALSE)

g5_mom034_schema_version <- function() "gen5_lit_mom_03_4_defensible_universe_v1"

g5_mom034_contract <- function() {
  list(
    literature_id = "LIT-MOM-03.4",
    parent_literature_id = "LIT-MOM-03.3",
    descriptive_name = "Defensible 2020 Deployment-Cohort Replay",
    source_cutoff_date = as.Date("2026-03-25"),
    as_of_timestamp = "2026-03-25 17:30:00 America/New_York",
    query_start = as.Date("2020-07-01"),
    signal_start = as.Date("2021-01-06"),
    signal_end = as.Date("2026-03-25"),
    universe_freeze_date = as.Date("2020-12-31"),
    source_report_date = as.Date("2020-09-30"),
    source_accepted_timestamp = "2020-11-18 20:32:42 America/New_York",
    source_accession = "0001752724-20-236128",
    registry_path = file.path(
      "runs", "research_workbench", "operator_hypothesis_lab",
      "hyp_mom_04_1_deployment_universe_train_20260811",
      "hyp_mom_04_1_frozen_registry.csv"
    ),
    registry_md5 = "40e1f4b3b731410aed1e0249cfc92195",
    universe_id = "SPY_2020_09_DEPLOYMENT_481",
    universe_label = "September 2020 SPY deployment cohort",
    universe_size = 481L,
    sector_count = 11L,
    benchmark_symbol = "SPY",
    lookback_weeks = c(short_horizon = 10L, long_horizon = 25L),
    selection_divisor = 3L,
    opening_top_n_per_sleeve = 160L,
    selection_fraction_rule = "FLOOR_CAUSALLY_SCOREABLE_COUNT_DIVIDED_BY_THREE",
    sleeve_weight = 0.50,
    positive_roc_threshold = 0,
    weekly_target_weekday = 3L,
    holiday_rule = "LAST_SPY_SESSION_ON_OR_BEFORE_WEDNESDAY_IN_SAME_MON_WED_WINDOW",
    tie_rule = "ROC_DESCENDING_THEN_SYMBOL_ASCENDING",
    execution_rule = "NEXT_SPY_SESSION_OPEN_WITH_FAILED_ENTRY_TO_CASH",
    terminal_rule = "LAST_OBSERVABLE_ADJUSTED_CLOSE_THROUGH_NEXT_REBALANCE",
    cost_bps_one_way = 5,
    cash_period_return = 0,
    annualization_periods = 52,
    minimum_initial_scoreable_fraction = 0.95,
    minimum_median_scoreable_fraction = 0.90,
    minimum_weekly_scoreable_fraction = 0.80,
    maximum_terminal_proxy_notional_fraction = 0.05,
    variants = c(
      "SOURCE_DUAL_MOMENTUM", "EQUAL_WEIGHT_UNIVERSE", "RELATIVE_ONLY",
      "ABSOLUTE_ONLY", "SPY_OWNERSHIP", "CASH_NO_TRADE"
    ),
    inference_opened = FALSE,
    parameter_search_opened = FALSE,
    forward_gate_opened = FALSE
  )
}

g5_mom034_validate_contract <- function(contract = g5_mom034_contract()) {
  frozen <- g5_mom034_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom034_stop("Frozen LIT-MOM-03.4 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom034_stop(paste(
      "Frozen LIT-MOM-03.4 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom034_registry <- function(repo_root, contract = g5_mom034_contract()) {
  contract <- g5_mom034_validate_contract(contract)
  path <- file.path(repo_root, contract$registry_path)
  if (!file.exists(path)) {
    g5_mom034_stop(paste(
      "Frozen deployment registry is missing; rebuild the audited",
      "HYP-MOM-04.1 deployment-universe packet first."
    ))
  }
  observed_md5 <- unname(tools::md5sum(path))
  if (!identical(tolower(observed_md5), contract$registry_md5)) {
    g5_mom034_stop("Frozen deployment registry MD5 does not match the contract.")
  }
  registry <- utils::read.csv(path, stringsAsFactors = FALSE)
  required <- c("instance_id", "symbol", "sector", "cohort")
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mom034_stop(paste("Deployment registry missing:", paste(missing, collapse = ", ")))
  }
  registry <- registry[, required, drop = FALSE]
  registry$symbol <- toupper(trimws(registry$symbol))
  registry$sector <- trimws(registry$sector)
  if (nrow(registry) != contract$universe_size || anyDuplicated(registry$symbol)) {
    g5_mom034_stop("Deployment registry must contain 481 unique symbols.")
  }
  if (length(unique(registry$sector)) != contract$sector_count) {
    g5_mom034_stop("Deployment registry must contain 11 contemporaneous sectors.")
  }
  if (!all(registry$cohort == "SPY_2020_09_DEPLOYMENT")) {
    g5_mom034_stop("Deployment registry cohort label changed.")
  }
  registry
}

g5_mom034_validate_bars <- function(bars, registry, contract = g5_mom034_contract()) {
  contract <- g5_mom034_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_mom034_stop(paste("Missing bar columns:", paste(missing, collapse = ", ")))
  symbols <- c(registry$symbol, contract$benchmark_symbol)
  x <- bars[bars$symbol %in% symbols, , drop = FALSE]
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  x <- x[x$session_date >= contract$query_start & x$session_date <= contract$signal_end, , drop = FALSE]
  spy <- x[x$symbol == contract$benchmark_symbol, , drop = FALSE]
  checks <- data.frame(
    check_id = c(
      "unique_symbol_sessions", "finite_positive_open_close", "adjusted_daily_only",
      "spy_query_start_covered", "spy_signal_end_covered", "source_cutoff_not_exceeded",
      "some_history_for_every_frozen_identity"
    ),
    passed = c(
      !anyDuplicated(paste(x$symbol, x$session_date)),
      nrow(x) > 0L && all(is.finite(x$open) & x$open > 0 & is.finite(x$close) & x$close > 0),
      nrow(x) > 0L && all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      nrow(spy) > 0L && min(spy$session_date) <= contract$query_start,
      nrow(spy) > 0L && max(spy$session_date) >= contract$signal_end,
      nrow(x) > 0L && max(x$session_date) <= contract$source_cutoff_date,
      all(registry$symbol %in% unique(x$symbol))
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_mom034_stop(paste(
      "LIT-MOM-03.4 bar validation failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  list(bars = x[order(x$symbol, x$session_date), , drop = FALSE], checks = checks)
}

g5_mom034_value_matrix <- function(bars, dates, symbols, field) {
  matrix_out <- matrix(
    NA_real_, nrow = length(dates), ncol = length(symbols),
    dimnames = list(as.character(dates), symbols)
  )
  rows <- bars[bars$session_date %in% dates & bars$symbol %in% symbols, , drop = FALSE]
  if (nrow(rows)) {
    matrix_out[cbind(match(as.character(rows$session_date), rownames(matrix_out)), match(rows$symbol, symbols))] <- rows[[field]]
  }
  matrix_out
}

g5_mom034_weekly_history <- function(bars, contract = g5_mom034_contract()) {
  spy_dates <- sort(unique(bars$session_date[bars$symbol == contract$benchmark_symbol]))
  calendar <- seq.Date(contract$query_start, contract$signal_end, by = "day")
  intended <- calendar[g5_mom032_weekday(calendar) == contract$weekly_target_weekday]
  rows <- lapply(intended, function(target) {
    candidates <- spy_dates[spy_dates >= target - 2L & spy_dates <= target]
    if (!length(candidates)) return(NULL)
    decision <- max(candidates)
    future <- spy_dates[spy_dates > decision]
    if (!length(future)) return(NULL)
    data.frame(
      intended_wednesday = target,
      decision_date = decision,
      execution_date = min(future),
      used_holiday_fallback = decision < target,
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  out <- do.call(rbind, rows)
  out <- out[!duplicated(out$decision_date), , drop = FALSE]
  out$weekly_index <- seq_len(nrow(out))
  rownames(out) <- NULL
  out
}

g5_mom034_rank <- function(values, symbols, eligible) {
  ranks <- rep(NA_integer_, length(values))
  index <- which(eligible)
  ordered <- index[order(-values[index], symbols[index])]
  ranks[ordered] <- seq_along(ordered)
  ranks
}

g5_mom034_target_set <- function(bars, registry, contract = g5_mom034_contract()) {
  history <- g5_mom034_weekly_history(bars, contract)
  anchors <- history[
    history$weekly_index > max(contract$lookback_weeks) &
      history$intended_wednesday >= contract$signal_start &
      history$intended_wednesday <= contract$signal_end,
    , drop = FALSE
  ]
  if (nrow(anchors) < 2L) g5_mom034_stop("Defensible cohort has insufficient weekly anchors.")
  symbols <- registry$symbol
  assets <- c(symbols, contract$benchmark_symbol)
  closes <- g5_mom034_value_matrix(bars, history$decision_date, symbols, "close")
  variants <- contract$variants
  targets <- lapply(variants, function(...) {
    matrix(
      0, nrow = nrow(anchors), ncol = length(assets) + 1L,
      dimnames = list(NULL, c(assets, "CASH"))
    )
  })
  names(targets) <- variants
  score_rows <- vector("list", nrow(anchors))
  breadth <- vector("list", nrow(anchors))
  for (i in seq_len(nrow(anchors))) {
    decision <- anchors$decision_date[[i]]
    history_index <- match(decision, history$decision_date)
    current <- closes[history_index, ]
    short <- closes[history_index - contract$lookback_weeks[["short_horizon"]], ]
    long <- closes[history_index - contract$lookback_weeks[["long_horizon"]], ]
    eligible <- is.finite(current) & is.finite(short) & is.finite(long)
    eligible_count <- sum(eligible)
    top_n <- floor(eligible_count / contract$selection_divisor)
    if (top_n < 1L) g5_mom034_stop("A weekly cohort has fewer than three scoreable assets.")
    roc_short <- current / short - 1
    roc_long <- current / long - 1
    rank_short <- g5_mom034_rank(roc_short, symbols, eligible)
    rank_long <- g5_mom034_rank(roc_long, symbols, eligible)
    selected_short <- eligible & rank_short <= top_n
    selected_long <- eligible & rank_long <= top_n
    permitted_short <- selected_short & roc_short > contract$positive_roc_threshold
    permitted_long <- selected_long & roc_long > contract$positive_roc_threshold
    slot <- contract$sleeve_weight / top_n
    absolute_slot <- contract$sleeve_weight / eligible_count
    source_weight <- slot * permitted_short + slot * permitted_long
    relative_weight <- slot * selected_short + slot * selected_long
    absolute_weight <- absolute_slot * (eligible & roc_short > 0) +
      absolute_slot * (eligible & roc_long > 0)
    targets[["SOURCE_DUAL_MOMENTUM"]][i, symbols] <- source_weight
    targets[["SOURCE_DUAL_MOMENTUM"]][i, "CASH"] <- 1 - sum(source_weight)
    targets[["EQUAL_WEIGHT_UNIVERSE"]][i, symbols[eligible]] <- 1 / eligible_count
    targets[["RELATIVE_ONLY"]][i, symbols] <- relative_weight
    targets[["ABSOLUTE_ONLY"]][i, symbols] <- absolute_weight
    targets[["ABSOLUTE_ONLY"]][i, "CASH"] <- 1 - sum(absolute_weight)
    targets[["SPY_OWNERSHIP"]][i, contract$benchmark_symbol] <- 1
    targets[["CASH_NO_TRADE"]][i, "CASH"] <- 1
    score_rows[[i]] <- data.frame(
      decision_date = decision,
      execution_date = anchors$execution_date[[i]],
      symbol = symbols,
      scoreable = eligible,
      roc_10w = as.numeric(roc_short),
      rank_10w = rank_short,
      selected_10w = selected_short,
      permitted_10w = permitted_short,
      roc_25w = as.numeric(roc_long),
      rank_25w = rank_long,
      selected_25w = selected_long,
      permitted_25w = permitted_long,
      source_target_weight = as.numeric(source_weight),
      relative_target_weight = as.numeric(relative_weight),
      stringsAsFactors = FALSE
    )
    breadth[[i]] <- data.frame(
      decision_date = decision,
      execution_date = anchors$execution_date[[i]],
      frozen_universe_size = length(symbols),
      scoreable_count = eligible_count,
      scoreable_fraction = eligible_count / length(symbols),
      top_n_per_sleeve = top_n,
      stringsAsFactors = FALSE
    )
  }
  for (variant in variants) {
    target <- targets[[variant]]
    if (any(!is.finite(target)) || any(target < -1e-12) || any(abs(rowSums(target) - 1) > 1e-10)) {
      g5_mom034_stop(paste("Invalid target matrix for", variant))
    }
  }
  list(
    anchors = anchors,
    targets = targets,
    scores = do.call(rbind, score_rows),
    breadth = do.call(rbind, breadth)
  )
}

g5_mom034_intervals <- function(bars, target_set, registry, contract = g5_mom034_contract()) {
  assets <- c(registry$symbol, contract$benchmark_symbol)
  start_dates <- target_set$anchors$execution_date[-nrow(target_set$anchors)]
  end_dates <- target_set$anchors$execution_date[-1L]
  start_open <- g5_mom034_value_matrix(bars, start_dates, assets, "open")
  end_open <- g5_mom034_value_matrix(bars, end_dates, assets, "open")
  returns <- matrix(NA_real_, nrow = length(start_dates), ncol = length(assets), dimnames = list(NULL, assets))
  entry_available <- is.finite(start_open)
  terminal_proxy <- matrix(FALSE, nrow = length(start_dates), ncol = length(assets), dimnames = list(NULL, assets))
  terminal_rows <- list()
  for (j in seq_along(assets)) {
    symbol <- assets[[j]]
    symbol_bars <- bars[bars$symbol == symbol, , drop = FALSE]
    for (i in seq_along(start_dates)) {
      if (!entry_available[i, j]) next
      if (is.finite(end_open[i, j])) {
        returns[i, j] <- end_open[i, j] / start_open[i, j] - 1
      } else {
        candidates <- symbol_bars[
          symbol_bars$session_date >= start_dates[[i]] & symbol_bars$session_date <= end_dates[[i]],
          , drop = FALSE
        ]
        if (!nrow(candidates)) next
        terminal_value <- tail(candidates$close, 1L)
        returns[i, j] <- terminal_value / start_open[i, j] - 1
        terminal_proxy[i, j] <- TRUE
        terminal_rows[[length(terminal_rows) + 1L]] <- data.frame(
          interval = i,
          symbol = symbol,
          execution_date = start_dates[[i]],
          next_execution_date = end_dates[[i]],
          terminal_value_date = tail(candidates$session_date, 1L),
          start_open = start_open[i, j],
          terminal_close = terminal_value,
          proxy_return = returns[i, j],
          stringsAsFactors = FALSE
        )
      }
    }
  }
  spy_index <- match(contract$benchmark_symbol, assets)
  if (any(!entry_available[, spy_index]) || any(!is.finite(returns[, spy_index]))) {
    g5_mom034_stop("SPY execution calendar is incomplete.")
  }
  list(
    metadata = data.frame(
      interval = seq_along(start_dates),
      decision_date = target_set$anchors$decision_date[-nrow(target_set$anchors)],
      execution_date = start_dates,
      next_execution_date = end_dates,
      stringsAsFactors = FALSE
    ),
    asset_returns = returns,
    entry_available = entry_available,
    terminal_proxy = terminal_proxy,
    terminal_events = if (length(terminal_rows)) do.call(rbind, terminal_rows) else data.frame()
  )
}

g5_mom034_replay <- function(target_set, intervals, contract = g5_mom034_contract()) {
  assets <- colnames(intervals$asset_returns)
  rate <- contract$cost_bps_one_way / 10000
  rows <- list()
  for (variant in contract$variants) {
    raw_targets <- target_set$targets[[variant]][seq_len(nrow(intervals$metadata)), , drop = FALSE]
    pretrade <- c(setNames(rep(0, length(assets)), assets), CASH = 1)
    wealth <- 1
    variant_rows <- vector("list", nrow(intervals$metadata))
    for (i in seq_len(nrow(intervals$metadata))) {
      target <- raw_targets[i, ]
      failed <- assets[!intervals$entry_available[i, assets] & target[assets] > 0]
      failed_weight <- if (length(failed)) sum(target[failed]) else 0
      if (length(failed)) {
        target["CASH"] <- target["CASH"] + failed_weight
        target[failed] <- 0
      }
      active <- assets[target[assets] > 0]
      if (length(active) && any(!is.finite(intervals$asset_returns[i, active]))) {
        g5_mom034_stop(paste("No terminal value for held assets in interval", i))
      }
      safe_return <- intervals$asset_returns[i, assets]
      safe_return[!is.finite(safe_return)] <- 0
      turnover <- 0.5 * sum(abs(target - pretrade))
      gross_return <- sum(target[assets] * safe_return)
      terminal_weight <- sum(target[assets][intervals$terminal_proxy[i, assets]])
      net_return <- (1 - rate * turnover) * (1 + gross_return) - 1
      wealth <- wealth * (1 + net_return)
      variant_rows[[i]] <- data.frame(
        universe_id = contract$universe_id,
        variant = variant,
        intervals$metadata[i, , drop = FALSE],
        turnover_one_way = turnover,
        gross_return = gross_return,
        net_return = net_return,
        wealth = wealth,
        invested_target_weight = sum(target[assets]),
        cash_target_weight = target[["CASH"]],
        failed_entry_target_weight = failed_weight,
        terminal_proxy_target_weight = terminal_weight,
        stringsAsFactors = FALSE
      )
      end_values <- c(target[assets] * (1 + safe_return), CASH = target[["CASH"]])
      pretrade <- end_values / sum(end_values)
    }
    rows[[variant]] <- do.call(rbind, variant_rows)
  }
  tape <- do.call(rbind, rows)
  groups <- interaction(tape$universe_id, tape$variant, drop = TRUE)
  tape$running_peak <- ave(tape$wealth, groups, FUN = function(x) cummax(c(1, x))[-1L])
  tape$drawdown <- tape$wealth / tape$running_peak - 1
  rownames(tape) <- NULL
  tape
}

g5_mom034_admission <- function(
  registry,
  bar_checks,
  target_set,
  intervals,
  contract = g5_mom034_contract()
) {
  breadth <- target_set$breadth
  scores <- target_set$scores[target_set$scores$decision_date %in%
    target_set$anchors$decision_date[-nrow(target_set$anchors)], , drop = FALSE]
  selection_check <- stats::aggregate(
    cbind(selected_10w, selected_25w) ~ decision_date,
    data = scores,
    FUN = sum
  )
  expected <- breadth$top_n_per_sleeve[match(selection_check$decision_date, breadth$decision_date)]
  relevant <- c(
    "SOURCE_DUAL_MOMENTUM", "EQUAL_WEIGHT_UNIVERSE", "RELATIVE_ONLY", "ABSOLUTE_ONLY"
  )
  terminal_rows <- lapply(relevant, function(variant) {
    raw <- target_set$targets[[variant]][seq_len(nrow(intervals$metadata)), , drop = FALSE]
    assets <- colnames(intervals$asset_returns)
    invested <- 0
    terminal <- 0
    for (i in seq_len(nrow(raw))) {
      weights <- raw[i, assets]
      weights[!intervals$entry_available[i, assets]] <- 0
      invested <- invested + sum(weights)
      terminal <- terminal + sum(weights[intervals$terminal_proxy[i, assets]])
    }
    data.frame(
      variant = variant,
      terminal_proxy_target_weight = terminal,
      invested_target_weight = invested,
      terminal_fraction = terminal / pmax(invested, .Machine$double.eps),
      stringsAsFactors = FALSE
    )
  })
  terminal_summary <- do.call(rbind, terminal_rows)
  maximum_terminal_fraction <- max(terminal_summary$terminal_fraction)
  gates <- data.frame(
    check_id = c(
      "frozen_registry_481_and_md5", "eleven_contemporaneous_sectors",
      "source_precedes_evaluation", "spy_calendar_complete",
      "initial_scoreable_at_least_95pct", "median_scoreable_at_least_90pct",
      "minimum_scoreable_at_least_80pct", "one_third_selection_exact",
      "terminal_proxy_notional_at_most_5pct",
      "no_inference_parameter_search_or_forward_gate"
    ),
    passed = c(
      nrow(registry) == contract$universe_size,
      length(unique(registry$sector)) == contract$sector_count,
      contract$universe_freeze_date < contract$signal_start,
      all(bar_checks$passed[bar_checks$check_id %in% c(
        "spy_query_start_covered", "spy_signal_end_covered"
      )]),
      breadth$scoreable_count[[1L]] / contract$universe_size >=
        contract$minimum_initial_scoreable_fraction,
      stats::median(breadth$scoreable_count) / contract$universe_size >=
        contract$minimum_median_scoreable_fraction,
      min(breadth$scoreable_count) / contract$universe_size >=
        contract$minimum_weekly_scoreable_fraction,
      all(selection_check$selected_10w == expected) && all(selection_check$selected_25w == expected),
      maximum_terminal_fraction <= contract$maximum_terminal_proxy_notional_fraction,
      !contract$inference_opened && !contract$parameter_search_opened && !contract$forward_gate_opened
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  list(
    admitted = all(gates$passed),
    gates = gates,
    selection_check = selection_check,
    terminal_summary = terminal_summary,
    maximum_terminal_fraction = maximum_terminal_fraction
  )
}

g5_mom034_summary <- function(metrics, tape, breadth, contract = g5_mom034_contract()) {
  get_row <- function(variant) metrics[metrics$variant == variant, , drop = FALSE][1L, ]
  source <- get_row("SOURCE_DUAL_MOMENTUM")
  equal <- get_row("EQUAL_WEIGHT_UNIVERSE")
  relative <- get_row("RELATIVE_ONLY")
  spy <- get_row("SPY_OWNERSHIP")
  relevant <- tape[tape$variant %in% c(
    "SOURCE_DUAL_MOMENTUM", "EQUAL_WEIGHT_UNIVERSE", "RELATIVE_ONLY", "ABSOLUTE_ONLY"
  ), , drop = FALSE]
  terminal_ratios <- stats::aggregate(
    cbind(terminal_proxy_target_weight, invested_target_weight) ~ variant,
    data = relevant,
    FUN = sum
  )
  terminal_ratios$terminal_fraction <- terminal_ratios$terminal_proxy_target_weight /
    pmax(terminal_ratios$invested_target_weight, .Machine$double.eps)
  data.frame(
    universe_id = contract$universe_id,
    frozen_assets = contract$universe_size,
    initial_scoreable = breadth$scoreable_count[[1L]],
    median_scoreable = stats::median(breadth$scoreable_count),
    minimum_scoreable = min(breadth$scoreable_count),
    source_cagr = source$cagr_net,
    equal_weight_cagr = equal$cagr_net,
    relative_only_cagr = relative$cagr_net,
    spy_cagr = spy$cagr_net,
    source_minus_equal_cagr = source$cagr_net - equal$cagr_net,
    relative_minus_equal_cagr = relative$cagr_net - equal$cagr_net,
    source_minus_relative_cagr = source$cagr_net - relative$cagr_net,
    source_max_drawdown = source$max_drawdown,
    equal_weight_max_drawdown = equal$max_drawdown,
    relative_only_max_drawdown = relative$max_drawdown,
    spy_max_drawdown = spy$max_drawdown,
    source_drawdown_improvement_vs_equal = source$max_drawdown - equal$max_drawdown,
    source_drawdown_improvement_vs_relative = source$max_drawdown - relative$max_drawdown,
    source_mean_invested_weight = source$mean_invested_weight,
    maximum_terminal_proxy_notional_fraction = max(terminal_ratios$terminal_fraction),
    stringsAsFactors = FALSE
  )
}

g5_mom034_run <- function(bars, repo_root, contract = g5_mom034_contract()) {
  contract <- g5_mom034_validate_contract(contract)
  registry <- g5_mom034_registry(repo_root, contract)
  checked <- g5_mom034_validate_bars(bars, registry, contract)
  target_set <- g5_mom034_target_set(checked$bars, registry, contract)
  intervals <- g5_mom034_intervals(checked$bars, target_set, registry, contract)
  admission <- g5_mom034_admission(
    registry, checked$checks, target_set, intervals, contract
  )
  if (!admission$admitted) {
    return(list(
      contract = contract,
      registry = registry,
      bar_integrity = checked$checks,
      target_set = target_set,
      intervals = intervals,
      admission = admission,
      weekly_tape = data.frame(),
      metrics = data.frame(),
      summary = data.frame(),
      gates = admission$gates
    ))
  }
  tape <- g5_mom034_replay(target_set, intervals, contract)
  metrics <- g5_mom032_metrics(tape, contract)
  summary <- g5_mom034_summary(metrics, tape, target_set$breadth, contract)
  list(
    contract = contract,
    registry = registry,
    bar_integrity = checked$checks,
    target_set = target_set,
    intervals = intervals,
    weekly_tape = tape,
    metrics = metrics,
    summary = summary,
    admission = admission,
    gates = admission$gates
  )
}
