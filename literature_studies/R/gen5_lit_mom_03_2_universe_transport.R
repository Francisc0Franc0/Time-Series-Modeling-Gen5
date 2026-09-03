# Cross-universe transport POCs for the LIT-MOM-03 relative-rotation principle.

g5_mom032_stop <- function(message) stop(message, call. = FALSE)

g5_mom032_schema_version <- function() "gen5_lit_mom_03_2_universe_transport_v1"

g5_mom032_contract <- function() {
  list(
    literature_id = "LIT-MOM-03.2",
    parent_literature_id = "LIT-MOM-03.1",
    descriptive_name = "Dual-Momentum Universe Transport POCs",
    source_cutoff_date = as.Date("2026-03-25"),
    as_of_timestamp = "2026-03-25 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    signal_start = as.Date("2016-06-29"),
    signal_end = as.Date("2026-03-25"),
    stock_registry = file.path(
      "operator_hypothesis_lab", "registries", "return_geometry_wide_atlas.csv"
    ),
    stock_cohort = "GICS_CORE",
    stock_selection_basis = "PRE_EXISTING_EIGHT_PER_SECTOR_LONG_HISTORY_LIQUID_ATLAS",
    stock_evidence_label = "STATIC_SURVIVOR_BIASED_EXPLORATORY_POC",
    sector_etf_universe = c(
      "XLB", "XLE", "XLF", "XLI", "XLK",
      "XLP", "XLRE", "XLU", "XLV", "XLY"
    ),
    sector_etf_selection_basis = "LONG_LIVED_US_SECTOR_SPDRS_WITH_COMPLETE_2016_WINDOW",
    excluded_sector_etf = "XLC",
    excluded_sector_etf_reason = "INCEPTION_AFTER_2016_QUERY_START",
    benchmark_symbol = "SPY",
    lookback_weeks = c(short_horizon = 10L, long_horizon = 25L),
    top_n_per_sleeve = 3L,
    sleeve_weight = 0.50,
    positive_roc_threshold = 0,
    weekly_target_weekday = 3L,
    holiday_rule = "LAST_COMMON_SESSION_ON_OR_BEFORE_WEDNESDAY_IN_SAME_MON_WED_WINDOW",
    tie_rule = "ROC_DESCENDING_THEN_SYMBOL_ASCENDING",
    execution_rule = "NEXT_COMMON_SESSION_OPEN",
    cost_bps_one_way = 5,
    cash_period_return = 0,
    annualization_periods = 52,
    variants = c(
      "SOURCE_DUAL_MOMENTUM", "EQUAL_WEIGHT_UNIVERSE", "RELATIVE_ONLY",
      "ABSOLUTE_ONLY", "SPY_OWNERSHIP", "CASH_NO_TRADE"
    ),
    inference_opened = FALSE,
    parameter_search_opened = FALSE,
    forward_gate_opened = FALSE
  )
}

g5_mom032_validate_contract <- function(contract = g5_mom032_contract()) {
  frozen <- g5_mom032_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom032_stop("Frozen LIT-MOM-03.2 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom032_stop(paste(
      "Frozen LIT-MOM-03.2 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom032_universe_registry <- function(
  repo_root,
  contract = g5_mom032_contract()
) {
  contract <- g5_mom032_validate_contract(contract)
  path <- file.path(repo_root, contract$stock_registry)
  if (!file.exists(path)) g5_mom032_stop("Frozen stock atlas registry is missing.")
  registry <- utils::read.csv(path, stringsAsFactors = FALSE)
  required <- c("symbol", "atlas_cohort", "sector", "instrument_type", "selection_basis")
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mom032_stop(paste("Stock atlas registry missing:", paste(missing, collapse = ", ")))
  }
  stocks <- registry[
    registry$atlas_cohort == contract$stock_cohort &
      registry$instrument_type == "Stock",
    required,
    drop = FALSE
  ]
  stocks$symbol <- toupper(trimws(stocks$symbol))
  stocks$sector <- trimws(stocks$sector)
  counts <- table(stocks$sector)
  if (length(counts) != 11L || any(counts != 8L)) {
    g5_mom032_stop("Frozen stock atlas must contain exactly eight stocks in each of 11 sectors.")
  }
  if (anyDuplicated(stocks$symbol)) {
    g5_mom032_stop("Frozen stock atlas symbols must be unique across sectors.")
  }
  sector_map <- c(
    "Communication Services" = "XLC",
    "Consumer Discretionary" = "XLY",
    "Consumer Staples" = "XLP",
    "Energy" = "XLE",
    "Financials" = "XLF",
    "Health Care" = "XLV",
    "Industrials" = "XLI",
    "Information Technology" = "XLK",
    "Materials" = "XLB",
    "Real Estate" = "XLRE",
    "Utilities" = "XLU"
  )
  rows <- list(data.frame(
    universe_id = "ETF_US_SECTOR_ROTATION",
    universe_label = "U.S. sector ETFs",
    universe_type = "ETF_FLEET",
    sector = "Cross-sector",
    ownership_proxy = contract$benchmark_symbol,
    symbol = contract$sector_etf_universe,
    selection_basis = contract$sector_etf_selection_basis,
    evidence_label = "LONG_LIVED_ETF_TRANSPORT_POC",
    stringsAsFactors = FALSE
  ))
  sectors <- sort(unique(stocks$sector))
  for (sector in sectors) {
    sector_rows <- stocks[stocks$sector == sector, , drop = FALSE]
    rows[[length(rows) + 1L]] <- data.frame(
      universe_id = paste0("STOCK_", gsub("[^A-Z0-9]+", "_", toupper(sector))),
      universe_label = paste(sector, "stocks"),
      universe_type = "STATIC_STOCK_SECTOR",
      sector = sector,
      ownership_proxy = unname(sector_map[[sector]]),
      symbol = sector_rows$symbol,
      selection_basis = contract$stock_selection_basis,
      evidence_label = contract$stock_evidence_label,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_mom032_required_symbols <- function(universe_registry, contract = g5_mom032_contract()) {
  sort(unique(c(universe_registry$symbol, contract$benchmark_symbol)))
}

g5_mom032_validate_bars <- function(bars, required_symbols, contract = g5_mom032_contract()) {
  contract <- g5_mom032_validate_contract(contract)
  required_columns <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required_columns, names(bars))
  if (length(missing)) g5_mom032_stop(paste("Missing bar columns:", paste(missing, collapse = ", ")))
  x <- bars[bars$symbol %in% required_symbols, , drop = FALSE]
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  x <- x[
    x$session_date >= contract$query_start & x$session_date <= contract$signal_end,
    , drop = FALSE
  ]
  coverage <- do.call(rbind, lapply(required_symbols, function(symbol) {
    dates <- x$session_date[x$symbol == symbol]
    data.frame(
      symbol = symbol,
      rows = length(dates),
      minimum = if (length(dates)) min(dates) else as.Date(NA),
      maximum = if (length(dates)) max(dates) else as.Date(NA),
      stringsAsFactors = FALSE
    )
  }))
  checks <- data.frame(
    check_id = c(
      "exact_symbols", "unique_symbol_sessions", "finite_positive_open_close",
      "adjusted_daily_only", "query_start_covered", "signal_end_covered",
      "source_cutoff_not_exceeded"
    ),
    passed = c(
      identical(sort(unique(x$symbol)), sort(required_symbols)),
      !anyDuplicated(paste(x$symbol, x$session_date)),
      all(is.finite(x$open) & x$open > 0 & is.finite(x$close) & x$close > 0),
      all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      all(!is.na(coverage$minimum) & coverage$minimum <= contract$query_start),
      all(!is.na(coverage$maximum) & coverage$maximum >= contract$signal_end),
      max(x$session_date) <= contract$source_cutoff_date
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_mom032_stop(paste(
      "LIT-MOM-03.2 bar validation failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  list(bars = x[order(x$symbol, x$session_date), , drop = FALSE], coverage = coverage, checks = checks)
}

g5_mom032_panel <- function(bars, symbols) {
  x <- bars[bars$symbol %in% symbols, , drop = FALSE]
  counts <- table(x$session_date)
  dates <- sort(as.Date(names(counts)[counts == length(symbols)]))
  if (!length(dates)) g5_mom032_stop("No complete common sessions for transport universe.")
  make_matrix <- function(field) {
    out <- matrix(
      NA_real_, nrow = length(dates), ncol = length(symbols),
      dimnames = list(as.character(dates), symbols)
    )
    for (symbol in symbols) {
      rows <- x[x$symbol == symbol & x$session_date %in% dates, , drop = FALSE]
      out[as.character(rows$session_date), symbol] <- rows[[field]]
    }
    if (any(!is.finite(out))) g5_mom032_stop(paste("Incomplete", field, "panel."))
    out
  }
  list(dates = dates, open = make_matrix("open"), close = make_matrix("close"))
}

g5_mom032_weekday <- function(date) as.POSIXlt(as.Date(date), tz = "UTC")$wday

g5_mom032_weekly_history <- function(panel, contract = g5_mom032_contract()) {
  calendar <- seq.Date(contract$query_start, contract$signal_end, by = "day")
  intended <- calendar[g5_mom032_weekday(calendar) == contract$weekly_target_weekday]
  rows <- lapply(intended, function(target) {
    candidates <- panel$dates[panel$dates >= target - 2L & panel$dates <= target]
    if (!length(candidates)) return(NULL)
    decision <- max(candidates)
    future <- panel$dates[panel$dates > decision]
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

g5_mom032_rank <- function(values, symbols) {
  order_index <- order(-values, symbols)
  ranks <- integer(length(values))
  ranks[order_index] <- seq_along(order_index)
  ranks
}

g5_mom032_target_set <- function(panel, rank_symbols, contract = g5_mom032_contract()) {
  history <- g5_mom032_weekly_history(panel, contract)
  eligible <- history[
    history$weekly_index > max(contract$lookback_weeks) &
      history$intended_wednesday >= contract$signal_start &
      history$intended_wednesday <= contract$signal_end,
    , drop = FALSE
  ]
  if (nrow(eligible) < 2L) g5_mom032_stop("Transport universe has insufficient weekly anchors.")
  assets <- c(rank_symbols, contract$benchmark_symbol)
  cash <- "CASH"
  variants <- contract$variants
  target_list <- lapply(variants, function(...) {
    matrix(0, nrow = nrow(eligible), ncol = length(assets) + 1L,
      dimnames = list(NULL, c(assets, cash)))
  })
  names(target_list) <- variants
  score_rows <- vector("list", nrow(eligible))
  slot <- contract$sleeve_weight / contract$top_n_per_sleeve
  absolute_slot <- contract$sleeve_weight / length(rank_symbols)
  for (i in seq_len(nrow(eligible))) {
    decision <- eligible$decision_date[[i]]
    history_index <- match(decision, history$decision_date)
    current_row <- match(as.character(decision), rownames(panel$close))
    lag_short <- history$decision_date[[history_index - contract$lookback_weeks[["short_horizon"]]]]
    lag_long <- history$decision_date[[history_index - contract$lookback_weeks[["long_horizon"]]]]
    short_row <- match(as.character(lag_short), rownames(panel$close))
    long_row <- match(as.character(lag_long), rownames(panel$close))
    roc_short <- panel$close[current_row, rank_symbols] / panel$close[short_row, rank_symbols] - 1
    roc_long <- panel$close[current_row, rank_symbols] / panel$close[long_row, rank_symbols] - 1
    rank_short <- g5_mom032_rank(roc_short, rank_symbols)
    rank_long <- g5_mom032_rank(roc_long, rank_symbols)
    selected_short <- rank_short <= contract$top_n_per_sleeve
    selected_long <- rank_long <= contract$top_n_per_sleeve
    permitted_short <- selected_short & roc_short > contract$positive_roc_threshold
    permitted_long <- selected_long & roc_long > contract$positive_roc_threshold

    source_weight <- slot * permitted_short + slot * permitted_long
    relative_weight <- slot * selected_short + slot * selected_long
    absolute_weight <- absolute_slot * (roc_short > 0) + absolute_slot * (roc_long > 0)
    target_list[["SOURCE_DUAL_MOMENTUM"]][i, rank_symbols] <- source_weight
    target_list[["SOURCE_DUAL_MOMENTUM"]][i, cash] <- 1 - sum(source_weight)
    target_list[["EQUAL_WEIGHT_UNIVERSE"]][i, rank_symbols] <- 1 / length(rank_symbols)
    target_list[["RELATIVE_ONLY"]][i, rank_symbols] <- relative_weight
    target_list[["ABSOLUTE_ONLY"]][i, rank_symbols] <- absolute_weight
    target_list[["ABSOLUTE_ONLY"]][i, cash] <- 1 - sum(absolute_weight)
    target_list[["SPY_OWNERSHIP"]][i, contract$benchmark_symbol] <- 1
    target_list[["CASH_NO_TRADE"]][i, cash] <- 1
    score_rows[[i]] <- data.frame(
      decision_date = decision,
      execution_date = eligible$execution_date[[i]],
      symbol = rank_symbols,
      roc_10w = as.numeric(roc_short),
      rank_10w = rank_short,
      selected_10w = permitted_short,
      roc_25w = as.numeric(roc_long),
      rank_25w = rank_long,
      selected_25w = permitted_long,
      source_target_weight = as.numeric(source_weight),
      stringsAsFactors = FALSE
    )
  }
  for (variant in variants) {
    target <- target_list[[variant]]
    if (any(!is.finite(target)) || any(target < -1e-12) || any(abs(rowSums(target) - 1) > 1e-12)) {
      g5_mom032_stop(paste("Invalid target matrix for", variant))
    }
  }
  list(anchors = eligible, targets = target_list, scores = do.call(rbind, score_rows))
}

g5_mom032_intervals <- function(panel, anchors) {
  execution_dates <- as.Date(anchors$execution_date)
  start_dates <- execution_dates[-length(execution_dates)]
  end_dates <- execution_dates[-1L]
  start_rows <- match(as.character(start_dates), rownames(panel$open))
  end_rows <- match(as.character(end_dates), rownames(panel$open))
  if (anyNA(c(start_rows, end_rows))) g5_mom032_stop("Execution date missing from panel.")
  list(
    metadata = data.frame(
      interval = seq_along(start_dates),
      decision_date = anchors$decision_date[-nrow(anchors)],
      execution_date = start_dates,
      next_execution_date = end_dates,
      stringsAsFactors = FALSE
    ),
    asset_returns = panel$open[end_rows, , drop = FALSE] /
      panel$open[start_rows, , drop = FALSE] - 1
  )
}

g5_mom032_replay <- function(
  universe_id,
  target_set,
  intervals,
  contract = g5_mom032_contract()
) {
  assets <- colnames(intervals$asset_returns)
  cash <- "CASH"
  rate <- contract$cost_bps_one_way / 10000
  rows <- list()
  for (variant in contract$variants) {
    target <- target_set$targets[[variant]][seq_len(nrow(intervals$metadata)), , drop = FALSE]
    pretrade <- c(setNames(rep(0, length(assets)), assets), setNames(1, cash))
    wealth <- 1
    variant_rows <- vector("list", nrow(intervals$metadata))
    for (i in seq_len(nrow(intervals$metadata))) {
      target_row <- target[i, ]
      turnover <- 0.5 * sum(abs(target_row - pretrade))
      gross_return <- sum(target_row[assets] * intervals$asset_returns[i, assets])
      net_return <- (1 - rate * turnover) * (1 + gross_return) - 1
      wealth <- wealth * (1 + net_return)
      variant_rows[[i]] <- data.frame(
        universe_id = universe_id,
        variant = variant,
        intervals$metadata[i, , drop = FALSE],
        turnover_one_way = turnover,
        gross_return = gross_return,
        net_return = net_return,
        wealth = wealth,
        invested_target_weight = sum(target_row[assets]),
        cash_target_weight = target_row[[cash]],
        stringsAsFactors = FALSE
      )
      end_values <- c(
        target_row[assets] * (1 + intervals$asset_returns[i, assets]),
        setNames(target_row[[cash]], cash)
      )
      pretrade <- end_values / sum(end_values)
    }
    rows[[variant]] <- do.call(rbind, variant_rows)
  }
  tape <- do.call(rbind, rows)
  groups <- interaction(tape$universe_id, tape$variant, drop = TRUE)
  tape$running_peak <- ave(
    tape$wealth,
    groups,
    FUN = function(x) cummax(c(1, x))[-1L]
  )
  tape$drawdown <- tape$wealth / tape$running_peak - 1
  rownames(tape) <- NULL
  tape
}

g5_mom032_metrics <- function(tape, contract = g5_mom032_contract()) {
  keys <- interaction(tape$universe_id, tape$variant, drop = TRUE)
  rows <- lapply(split(tape, keys), function(x) {
    years <- as.numeric(max(x$next_execution_date) - min(x$execution_date)) / 365.25
    weekly_sd <- stats::sd(x$net_return)
    data.frame(
      universe_id = x$universe_id[[1L]],
      variant = x$variant[[1L]],
      intervals = nrow(x),
      start_date = min(x$execution_date),
      end_date = max(x$next_execution_date),
      ending_wealth_net = tail(x$wealth, 1L),
      cagr_net = tail(x$wealth, 1L)^(1 / years) - 1,
      annualized_volatility = weekly_sd * sqrt(contract$annualization_periods),
      annualized_sharpe_zero_cash = if (weekly_sd > 0) {
        mean(x$net_return) / weekly_sd * sqrt(contract$annualization_periods)
      } else {
        NA_real_
      },
      max_drawdown = min(x$drawdown),
      mean_invested_weight = mean(x$invested_target_weight),
      annualized_one_way_turnover = sum(x$turnover_one_way) / years,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_mom032_summary <- function(metrics, universe_registry) {
  meta <- unique(universe_registry[c(
    "universe_id", "universe_label", "universe_type", "sector",
    "ownership_proxy", "evidence_label"
  )])
  get_metric <- function(id, variant, field) {
    metrics[metrics$universe_id == id & metrics$variant == variant, field][[1L]]
  }
  rows <- lapply(meta$universe_id, function(id) {
    source_cagr <- get_metric(id, "SOURCE_DUAL_MOMENTUM", "cagr_net")
    equal_cagr <- get_metric(id, "EQUAL_WEIGHT_UNIVERSE", "cagr_net")
    relative_cagr <- get_metric(id, "RELATIVE_ONLY", "cagr_net")
    absolute_cagr <- get_metric(id, "ABSOLUTE_ONLY", "cagr_net")
    spy_cagr <- get_metric(id, "SPY_OWNERSHIP", "cagr_net")
    source_dd <- get_metric(id, "SOURCE_DUAL_MOMENTUM", "max_drawdown")
    equal_dd <- get_metric(id, "EQUAL_WEIGHT_UNIVERSE", "max_drawdown")
    source_invested <- get_metric(id, "SOURCE_DUAL_MOMENTUM", "mean_invested_weight")
    data.frame(
      universe_id = id,
      source_cagr = source_cagr,
      equal_weight_cagr = equal_cagr,
      relative_only_cagr = relative_cagr,
      absolute_only_cagr = absolute_cagr,
      spy_cagr = spy_cagr,
      source_minus_equal_cagr = source_cagr - equal_cagr,
      source_minus_relative_cagr = source_cagr - relative_cagr,
      source_minus_spy_cagr = source_cagr - spy_cagr,
      source_max_drawdown = source_dd,
      equal_weight_max_drawdown = equal_dd,
      drawdown_improvement_vs_equal = source_dd - equal_dd,
      source_mean_invested_weight = source_invested,
      source_beats_equal_cagr = source_cagr > equal_cagr,
      source_beats_spy_cagr = source_cagr > spy_cagr,
      source_drawdown_shallower_than_equal = source_dd > equal_dd,
      source_within_25bp_of_relative = abs(source_cagr - relative_cagr) <= 0.0025,
      stringsAsFactors = FALSE
    )
  })
  out <- merge(meta, do.call(rbind, rows), by = "universe_id", sort = FALSE)
  out[match(meta$universe_id, out$universe_id), , drop = FALSE]
}

g5_mom032_run <- function(
  bars,
  repo_root,
  contract = g5_mom032_contract()
) {
  contract <- g5_mom032_validate_contract(contract)
  registry <- g5_mom032_universe_registry(repo_root, contract)
  required_symbols <- g5_mom032_required_symbols(registry, contract)
  checked <- g5_mom032_validate_bars(bars, required_symbols, contract)
  universe_ids <- unique(registry$universe_id)
  universe_runs <- vector("list", length(universe_ids))
  names(universe_runs) <- universe_ids
  tapes <- vector("list", length(universe_ids))
  scores <- vector("list", length(universe_ids))
  for (i in seq_along(universe_ids)) {
    id <- universe_ids[[i]]
    rank_symbols <- registry$symbol[registry$universe_id == id]
    panel_symbols <- unique(c(rank_symbols, contract$benchmark_symbol))
    panel <- g5_mom032_panel(checked$bars, panel_symbols)
    target_set <- g5_mom032_target_set(panel, rank_symbols, contract)
    intervals <- g5_mom032_intervals(panel, target_set$anchors)
    tape <- g5_mom032_replay(id, target_set, intervals, contract)
    score <- target_set$scores
    score$universe_id <- id
    tapes[[i]] <- tape
    scores[[i]] <- score
    universe_runs[[i]] <- list(panel = panel, target_set = target_set, intervals = intervals)
  }
  weekly_tape <- do.call(rbind, tapes)
  score_tape <- do.call(rbind, scores)
  metrics <- g5_mom032_metrics(weekly_tape, contract)
  summary <- g5_mom032_summary(metrics, registry)
  integrity <- data.frame(
    check_id = c(
      "twelve_frozen_universes", "one_etf_and_eleven_stock_fleets",
      "eight_stocks_per_sector", "complete_interval_count_consistent",
      "source_weights_bounded", "stock_bias_label_explicit",
      "no_inference_or_parameter_search_or_forward_gate"
    ),
    passed = c(
      length(universe_ids) == 12L,
      sum(summary$universe_type == "ETF_FLEET") == 1L &&
        sum(summary$universe_type == "STATIC_STOCK_SECTOR") == 11L,
      all(table(registry$universe_id[registry$universe_type == "STATIC_STOCK_SECTOR"]) == 8L),
      length(unique(metrics$intervals)) == 1L,
      all(summary$source_mean_invested_weight >= 0 & summary$source_mean_invested_weight <= 1),
      all(summary$evidence_label[summary$universe_type == "STATIC_STOCK_SECTOR"] ==
        contract$stock_evidence_label),
      !contract$inference_opened && !contract$parameter_search_opened && !contract$forward_gate_opened
    ),
    stringsAsFactors = FALSE
  )
  integrity$status <- ifelse(integrity$passed, "PASS", "FAIL")
  if (!all(integrity$passed)) {
    g5_mom032_stop(paste(
      "LIT-MOM-03.2 integrity failed:",
      paste(integrity$check_id[!integrity$passed], collapse = ", ")
    ))
  }
  list(
    contract = contract,
    universe_registry = registry,
    bar_coverage = checked$coverage,
    bar_integrity = checked$checks,
    universe_runs = universe_runs,
    scores = score_tape,
    weekly_tape = weekly_tape,
    metrics = metrics,
    summary = summary,
    integrity = integrity
  )
}
