# Broad cross-sector stock-fleet POC for the LIT-MOM-03 relative-rotation principle.

g5_mom033_stop <- function(message) stop(message, call. = FALSE)

g5_mom033_schema_version <- function() "gen5_lit_mom_03_3_broad_stock_fleet_v1"

g5_mom033_contract <- function() {
  list(
    literature_id = "LIT-MOM-03.3",
    parent_literature_id = "LIT-MOM-03.2",
    descriptive_name = "Broad Cross-Sector Stock Fleet POC",
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
    universe_id = "STOCK_BROAD_CROSS_SECTOR_88",
    universe_label = "Broad cross-sector 88-stock fleet",
    benchmark_symbol = "SPY",
    lookback_weeks = c(short_horizon = 10L, long_horizon = 25L),
    source_universe_size = 9L,
    source_top_n_per_sleeve = 3L,
    broad_universe_size = 88L,
    top_n_per_sleeve = 29L,
    selection_fraction_rule = "ROUND_HALF_DOWN_88_TIMES_3_OVER_9_EQUALS_29",
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

g5_mom033_validate_contract <- function(contract = g5_mom033_contract()) {
  frozen <- g5_mom033_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom033_stop("Frozen LIT-MOM-03.3 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom033_stop(paste(
      "Frozen LIT-MOM-03.3 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom033_universe_registry <- function(repo_root, contract = g5_mom033_contract()) {
  contract <- g5_mom033_validate_contract(contract)
  path <- file.path(repo_root, contract$stock_registry)
  if (!file.exists(path)) g5_mom033_stop("Frozen stock atlas registry is missing.")
  registry <- utils::read.csv(path, stringsAsFactors = FALSE)
  required <- c("symbol", "atlas_cohort", "sector", "instrument_type", "selection_basis")
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mom033_stop(paste("Stock atlas registry missing:", paste(missing, collapse = ", ")))
  }
  stocks <- registry[
    registry$atlas_cohort == contract$stock_cohort & registry$instrument_type == "Stock",
    required,
    drop = FALSE
  ]
  stocks$symbol <- toupper(trimws(stocks$symbol))
  stocks$sector <- trimws(stocks$sector)
  counts <- table(stocks$sector)
  if (nrow(stocks) != contract$broad_universe_size || length(counts) != 11L || any(counts != 8L)) {
    g5_mom033_stop("Frozen broad atlas must contain 88 stocks: eight in each of 11 sectors.")
  }
  if (anyDuplicated(stocks$symbol)) g5_mom033_stop("Frozen broad-atlas symbols must be unique.")
  data.frame(
    universe_id = contract$universe_id,
    universe_label = contract$universe_label,
    universe_type = "STATIC_BROAD_STOCK_FLEET",
    sector = stocks$sector,
    ownership_proxy = contract$benchmark_symbol,
    symbol = stocks$symbol,
    selection_basis = contract$stock_selection_basis,
    evidence_label = contract$stock_evidence_label,
    stringsAsFactors = FALSE
  )
}

g5_mom033_required_symbols <- function(registry, contract = g5_mom033_contract()) {
  sort(unique(c(registry$symbol, contract$benchmark_symbol)))
}

g5_mom033_validate_bars <- function(bars, required_symbols, contract = g5_mom033_contract()) {
  contract <- g5_mom033_validate_contract(contract)
  required_columns <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required_columns, names(bars))
  if (length(missing)) g5_mom033_stop(paste("Missing bar columns:", paste(missing, collapse = ", ")))
  x <- bars[bars$symbol %in% required_symbols, , drop = FALSE]
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  x <- x[x$session_date >= contract$query_start & x$session_date <= contract$signal_end, , drop = FALSE]
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
      nrow(x) > 0L && max(x$session_date) <= contract$source_cutoff_date
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_mom033_stop(paste(
      "LIT-MOM-03.3 bar validation failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  list(
    bars = x[order(x$symbol, x$session_date), , drop = FALSE],
    coverage = coverage,
    checks = checks
  )
}

g5_mom033_summary <- function(metrics, contract = g5_mom033_contract()) {
  get_row <- function(variant) metrics[metrics$variant == variant, , drop = FALSE][1L, ]
  source <- get_row("SOURCE_DUAL_MOMENTUM")
  equal <- get_row("EQUAL_WEIGHT_UNIVERSE")
  relative <- get_row("RELATIVE_ONLY")
  absolute <- get_row("ABSOLUTE_ONLY")
  spy <- get_row("SPY_OWNERSHIP")
  data.frame(
    universe_id = contract$universe_id,
    assets = contract$broad_universe_size,
    sectors = 11L,
    top_n_per_sleeve = contract$top_n_per_sleeve,
    source_cagr = source$cagr_net,
    equal_weight_cagr = equal$cagr_net,
    relative_only_cagr = relative$cagr_net,
    absolute_only_cagr = absolute$cagr_net,
    spy_cagr = spy$cagr_net,
    source_minus_equal_cagr = source$cagr_net - equal$cagr_net,
    relative_minus_equal_cagr = relative$cagr_net - equal$cagr_net,
    source_minus_relative_cagr = source$cagr_net - relative$cagr_net,
    source_minus_spy_cagr = source$cagr_net - spy$cagr_net,
    source_max_drawdown = source$max_drawdown,
    equal_weight_max_drawdown = equal$max_drawdown,
    relative_only_max_drawdown = relative$max_drawdown,
    spy_max_drawdown = spy$max_drawdown,
    source_drawdown_improvement_vs_equal = source$max_drawdown - equal$max_drawdown,
    source_drawdown_improvement_vs_relative = source$max_drawdown - relative$max_drawdown,
    source_mean_invested_weight = source$mean_invested_weight,
    source_annualized_turnover = source$annualized_one_way_turnover,
    stringsAsFactors = FALSE
  )
}

g5_mom033_sector_tape <- function(scores, registry) {
  sector_map <- setNames(registry$sector, registry$symbol)
  scores$sector <- unname(sector_map[scores$symbol])
  if (anyNA(scores$sector)) g5_mom033_stop("Sector map did not cover every score row.")
  aggregated <- stats::aggregate(
    source_target_weight ~ decision_date + execution_date + sector,
    data = scores,
    FUN = sum
  )
  total <- stats::aggregate(source_target_weight ~ decision_date, data = aggregated, FUN = sum)
  names(total)[2L] <- "invested_target_weight"
  aggregated <- merge(aggregated, total, by = "decision_date", all.x = TRUE, sort = FALSE)
  aggregated$cash_target_weight <- 1 - aggregated$invested_target_weight
  aggregated[order(aggregated$decision_date, aggregated$sector), , drop = FALSE]
}

g5_mom033_run <- function(bars, repo_root, contract = g5_mom033_contract()) {
  contract <- g5_mom033_validate_contract(contract)
  registry <- g5_mom033_universe_registry(repo_root, contract)
  required_symbols <- g5_mom033_required_symbols(registry, contract)
  checked <- g5_mom033_validate_bars(bars, required_symbols, contract)
  rank_symbols <- registry$symbol
  panel <- g5_mom032_panel(checked$bars, c(rank_symbols, contract$benchmark_symbol))
  target_set <- g5_mom032_target_set(panel, rank_symbols, contract)
  intervals <- g5_mom032_intervals(panel, target_set$anchors)
  weekly_tape <- g5_mom032_replay(contract$universe_id, target_set, intervals, contract)
  metrics <- g5_mom032_metrics(weekly_tape, contract)
  summary <- g5_mom033_summary(metrics, contract)
  sector_tape <- g5_mom033_sector_tape(target_set$scores, registry)
  source_targets <- target_set$targets[["SOURCE_DUAL_MOMENTUM"]]
  relative_targets <- target_set$targets[["RELATIVE_ONLY"]]
  integrity <- data.frame(
    check_id = c(
      "one_frozen_88_stock_fleet", "eleven_sectors_eight_names_each",
      "selection_fraction_preserved_without_search", "complete_507_interval_replay",
      "relative_only_fully_invested", "source_weights_bounded",
      "stock_bias_label_explicit", "no_inference_or_parameter_search_or_forward_gate"
    ),
    passed = c(
      nrow(registry) == 88L && length(unique(registry$universe_id)) == 1L,
      length(table(registry$sector)) == 11L && all(table(registry$sector) == 8L),
      contract$top_n_per_sleeve == 29L &&
        contract$source_top_n_per_sleeve / contract$source_universe_size == 1 / 3,
      nrow(intervals$metadata) == 507L && all(metrics$intervals == 507L),
      all(abs(relative_targets[, "CASH"]) < 1e-12),
      all(source_targets >= -1e-12) && all(abs(rowSums(source_targets) - 1) < 1e-12),
      all(registry$evidence_label == contract$stock_evidence_label),
      !contract$inference_opened && !contract$parameter_search_opened && !contract$forward_gate_opened
    ),
    stringsAsFactors = FALSE
  )
  integrity$status <- ifelse(integrity$passed, "PASS", "FAIL")
  if (!all(integrity$passed)) {
    g5_mom033_stop(paste(
      "LIT-MOM-03.3 integrity failed:",
      paste(integrity$check_id[!integrity$passed], collapse = ", ")
    ))
  }
  list(
    contract = contract,
    universe_registry = registry,
    bar_coverage = checked$coverage,
    bar_integrity = checked$checks,
    panel = panel,
    target_set = target_set,
    intervals = intervals,
    scores = target_set$scores,
    weekly_tape = weekly_tape,
    metrics = metrics,
    summary = summary,
    sector_tape = sector_tape,
    integrity = integrity
  )
}
