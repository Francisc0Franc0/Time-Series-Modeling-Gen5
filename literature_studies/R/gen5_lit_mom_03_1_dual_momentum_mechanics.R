# Source-faithful LIT-MOM-03.1 dual-momentum signal and allocation mechanics.

g5_mom031_stop <- function(message) stop(message, call. = FALSE)

g5_mom031_schema_version <- function() "gen5_lit_mom_03_1_mechanics_v1"

g5_mom031_contract <- function() {
  list(
    literature_id = "LIT-MOM-03.1",
    descriptive_name = "Active Dual Momentum GTAA Replication",
    source_cutoff_date = as.Date("2026-03-25"),
    as_of_timestamp = "2026-03-25 17:30:00 America/New_York",
    published_query_start = as.Date("2007-02-21"),
    published_signal_start = as.Date("2008-02-21"),
    query_start = as.Date("2016-01-04"),
    signal_start = as.Date("2016-06-29"),
    signal_end = as.Date("2026-03-25"),
    local_window_constraint = "ALPACA_ACCOUNT_RETURNED_COMPLETE_COMMON_HISTORY_FROM_2016_ONLY",
    universe = c("SHY", "IEF", "UUP", "GLD", "USO", "SPY", "EFA", "QQQ", "EEM"),
    lookback_weeks = c(short_horizon = 10L, long_horizon = 25L),
    top_n_per_sleeve = 3L,
    sleeve_weight = 0.50,
    positive_roc_threshold = 0,
    weekly_target_weekday = 3L,
    holiday_rule = "LAST_COMMON_SESSION_ON_OR_BEFORE_WEDNESDAY_IN_SAME_MON_WED_WINDOW",
    tie_rule = "ROC_DESCENDING_THEN_SYMBOL_ASCENDING",
    execution_rule = "NEXT_COMMON_SESSION_OPEN",
    adjustment = "all",
    timeframe = "1D",
    cash_symbol = "CASH",
    representative_targets = as.Date(c(
      "2016-06-29", "2018-02-07", "2020-03-18", "2020-08-19",
      "2022-06-15", "2023-11-01", "2025-04-09", "2026-03-18"
    )),
    performance_opened = FALSE
  )
}

g5_mom031_validate_contract <- function(contract = g5_mom031_contract()) {
  frozen <- g5_mom031_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom031_stop("Frozen LIT-MOM-03.1 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom031_stop(paste(
      "Frozen LIT-MOM-03.1 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom031_validate_bars <- function(bars, contract = g5_mom031_contract()) {
  contract <- g5_mom031_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_mom031_stop(paste("Missing required bar columns:", paste(missing, collapse = ", ")))
  }
  x <- bars[bars$symbol %in% contract$universe, , drop = FALSE]
  if (!nrow(x)) g5_mom031_stop("No LIT-MOM-03.1 universe bars were supplied.")
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  if (any(x$session_date > contract$source_cutoff_date)) {
    g5_mom031_stop("LIT-MOM-03.1 bar validation failed: source_cutoff_not_exceeded")
  }
  x <- x[
    x$session_date >= contract$query_start &
      x$session_date <= contract$signal_end,
    , drop = FALSE
  ]
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  present <- sort(unique(x$symbol))
  expected <- sort(contract$universe)
  duplicate_keys <- duplicated(paste(x$symbol, x$session_date))
  coverage <- lapply(contract$universe, function(symbol) {
    dates <- x$session_date[x$symbol == symbol]
    c(
      minimum = if (length(dates)) as.character(min(dates)) else "none",
      maximum = if (length(dates)) as.character(max(dates)) else "none",
      rows = as.character(length(dates))
    )
  })
  names(coverage) <- contract$universe
  starts <- vapply(coverage, `[[`, character(1), "minimum")
  ends <- vapply(coverage, `[[`, character(1), "maximum")
  checks <- data.frame(
    check_id = c(
      "exact_universe",
      "unique_symbol_sessions",
      "finite_positive_open_close",
      "adjusted_daily_only",
      "query_start_covered_all_symbols",
      "source_cutoff_covered_all_symbols",
      "source_cutoff_not_exceeded"
    ),
    passed = c(
      identical(present, expected),
      !any(duplicate_keys),
      all(is.finite(x$open) & x$open > 0 & is.finite(x$close) & x$close > 0),
      all(x$adjusted %in% TRUE) && all(x$timeframe == contract$timeframe),
      all(starts != "none" & as.Date(starts) <= contract$query_start),
      all(ends != "none" & as.Date(ends) >= contract$signal_end),
      max(x$session_date) <= contract$source_cutoff_date
    ),
    observed = c(
      paste(present, collapse = ","),
      as.character(sum(duplicate_keys)),
      paste(range(c(x$open, x$close)), collapse = " to "),
      paste(unique(paste(x$adjusted, x$timeframe, sep = "/")), collapse = ","),
      paste(starts, collapse = ","),
      paste(ends, collapse = ","),
      as.character(max(x$session_date))
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_mom031_stop(paste(
      "LIT-MOM-03.1 bar validation failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  list(bars = x, checks = checks, coverage = coverage)
}

g5_mom031_common_panel <- function(bars, contract = g5_mom031_contract()) {
  checked <- g5_mom031_validate_bars(bars, contract)
  x <- checked$bars
  date_counts <- table(x$session_date)
  common_dates <- as.Date(names(date_counts)[date_counts == length(contract$universe)])
  common_dates <- sort(common_dates)
  if (!length(common_dates)) g5_mom031_stop("No complete common sessions are available.")
  make_matrix <- function(field) {
    matrix_values <- matrix(
      NA_real_, nrow = length(common_dates), ncol = length(contract$universe),
      dimnames = list(as.character(common_dates), contract$universe)
    )
    for (symbol in contract$universe) {
      rows <- x[x$symbol == symbol & x$session_date %in% common_dates, , drop = FALSE]
      matrix_values[as.character(rows$session_date), symbol] <- rows[[field]]
    }
    if (any(!is.finite(matrix_values))) {
      g5_mom031_stop(paste("Incomplete common", field, "matrix."))
    }
    matrix_values
  }
  list(
    dates = common_dates,
    open = make_matrix("open"),
    close = make_matrix("close"),
    integrity = checked$checks,
    coverage = checked$coverage
  )
}

g5_mom031_weekday_number <- function(date) as.POSIXlt(as.Date(date), tz = "UTC")$wday

g5_mom031_weekly_anchors <- function(panel, contract = g5_mom031_contract()) {
  contract <- g5_mom031_validate_contract(contract)
  calendar <- seq.Date(contract$query_start, contract$signal_end, by = "day")
  intended <- calendar[g5_mom031_weekday_number(calendar) == contract$weekly_target_weekday]
  rows <- lapply(intended, function(target) {
    candidates <- panel$dates[panel$dates >= target - 2L & panel$dates <= target]
    if (!length(candidates)) return(NULL)
    decision <- max(candidates)
    next_dates <- panel$dates[panel$dates > decision]
    if (!length(next_dates)) return(NULL)
    data.frame(
      intended_wednesday = target,
      decision_date = decision,
      execution_date = min(next_dates),
      used_holiday_fallback = decision < target,
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  anchors <- do.call(rbind, rows)
  anchors <- anchors[!duplicated(anchors$decision_date), , drop = FALSE]
  anchors$weekly_index <- seq_len(nrow(anchors))
  max_lookback <- max(contract$lookback_weeks)
  anchors <- anchors[
    anchors$weekly_index > max_lookback &
      anchors$intended_wednesday >= contract$signal_start &
      anchors$intended_wednesday <= contract$signal_end,
    , drop = FALSE
  ]
  rownames(anchors) <- NULL
  if (!nrow(anchors)) g5_mom031_stop("No eligible weekly decision anchors are available.")
  if (any(anchors$execution_date <= anchors$decision_date)) {
    g5_mom031_stop("A next-open execution date is not strictly after its decision date.")
  }
  anchors
}

g5_mom031_rank <- function(values, symbols) {
  if (length(values) != length(symbols) || any(!is.finite(values))) {
    g5_mom031_stop("Ranking inputs must be finite and aligned.")
  }
  order_index <- order(-values, symbols)
  ranks <- integer(length(values))
  ranks[order_index] <- seq_along(order_index)
  ranks
}

g5_mom031_allocate_scores <- function(
  roc_10w,
  roc_25w,
  contract = g5_mom031_contract()
) {
  contract <- g5_mom031_validate_contract(contract)
  symbols <- contract$universe
  if (is.null(names(roc_10w)) || is.null(names(roc_25w))) {
    g5_mom031_stop("ROC vectors must be named by symbol.")
  }
  roc_10w <- as.numeric(roc_10w[symbols])
  roc_25w <- as.numeric(roc_25w[symbols])
  names(roc_10w) <- symbols
  names(roc_25w) <- symbols
  rank_10w <- g5_mom031_rank(roc_10w, symbols)
  rank_25w <- g5_mom031_rank(roc_25w, symbols)
  selected_10w <- rank_10w <= contract$top_n_per_sleeve &
    roc_10w > contract$positive_roc_threshold
  selected_25w <- rank_25w <= contract$top_n_per_sleeve &
    roc_25w > contract$positive_roc_threshold
  slot_weight <- contract$sleeve_weight / contract$top_n_per_sleeve
  weight_10w <- ifelse(selected_10w, slot_weight, 0)
  weight_25w <- ifelse(selected_25w, slot_weight, 0)
  target_weight <- weight_10w + weight_25w
  score_rows <- data.frame(
    symbol = symbols,
    roc_10w = roc_10w,
    rank_10w = rank_10w,
    selected_10w = selected_10w,
    weight_10w = weight_10w,
    roc_25w = roc_25w,
    rank_25w = rank_25w,
    selected_25w = selected_25w,
    weight_25w = weight_25w,
    target_weight = target_weight,
    stringsAsFactors = FALSE
  )
  cash_weight <- 1 - sum(target_weight)
  if (cash_weight < -1e-12 || cash_weight > 1 + 1e-12) {
    g5_mom031_stop("Constructed cash weight escaped [0, 1].")
  }
  list(
    scores = score_rows,
    cash_weight = max(0, min(1, cash_weight)),
    selected_10w = symbols[selected_10w],
    selected_25w = symbols[selected_25w]
  )
}

g5_mom031_build_tapes <- function(panel, anchors, contract = g5_mom031_contract()) {
  contract <- g5_mom031_validate_contract(contract)
  all_calendar <- seq.Date(contract$query_start, contract$signal_end, by = "day")
  all_wed <- all_calendar[g5_mom031_weekday_number(all_calendar) == contract$weekly_target_weekday]
  history_rows <- lapply(all_wed, function(target) {
    candidates <- panel$dates[panel$dates >= target - 2L & panel$dates <= target]
    if (!length(candidates)) return(NULL)
    data.frame(intended_wednesday = target, decision_date = max(candidates))
  })
  history_rows <- history_rows[!vapply(history_rows, is.null, logical(1))]
  history <- do.call(rbind, history_rows)
  history <- history[!duplicated(history$decision_date), , drop = FALSE]
  history$weekly_index <- seq_len(nrow(history))
  rownames(history) <- NULL

  score_frames <- vector("list", nrow(anchors))
  allocation_frames <- vector("list", nrow(anchors))
  for (i in seq_len(nrow(anchors))) {
    decision <- anchors$decision_date[[i]]
    history_index <- match(decision, history$decision_date)
    if (is.na(history_index) || history_index <= max(contract$lookback_weeks)) {
      g5_mom031_stop("Weekly anchor lacks frozen lookback history.")
    }
    current_row <- match(as.character(decision), rownames(panel$close))
    lag_10_date <- history$decision_date[[history_index - contract$lookback_weeks[["short_horizon"]]]]
    lag_25_date <- history$decision_date[[history_index - contract$lookback_weeks[["long_horizon"]]]]
    lag_10_row <- match(as.character(lag_10_date), rownames(panel$close))
    lag_25_row <- match(as.character(lag_25_date), rownames(panel$close))
    roc_10w <- panel$close[current_row, ] / panel$close[lag_10_row, ] - 1
    roc_25w <- panel$close[current_row, ] / panel$close[lag_25_row, ] - 1
    allocation <- g5_mom031_allocate_scores(roc_10w, roc_25w, contract)
    score <- allocation$scores
    score$intended_wednesday <- anchors$intended_wednesday[[i]]
    score$decision_date <- decision
    score$execution_date <- anchors$execution_date[[i]]
    score$used_holiday_fallback <- anchors$used_holiday_fallback[[i]]
    score$lag_10w_date <- lag_10_date
    score$lag_25w_date <- lag_25_date
    score_frames[[i]] <- score

    asset_weights <- setNames(as.list(score$target_weight), paste0("weight_", score$symbol))
    allocation_frames[[i]] <- data.frame(
      intended_wednesday = anchors$intended_wednesday[[i]],
      decision_date = decision,
      execution_date = anchors$execution_date[[i]],
      used_holiday_fallback = anchors$used_holiday_fallback[[i]],
      selected_10w = paste(allocation$selected_10w, collapse = ","),
      selected_25w = paste(allocation$selected_25w, collapse = ","),
      sleeve_overlap = length(intersect(allocation$selected_10w, allocation$selected_25w)),
      unique_holdings = sum(score$target_weight > 0),
      as.data.frame(asset_weights, check.names = FALSE),
      cash_weight = allocation$cash_weight,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  scores <- do.call(rbind, score_frames)
  allocations <- do.call(rbind, allocation_frames)
  rownames(scores) <- NULL
  rownames(allocations) <- NULL
  list(scores = scores, allocations = allocations)
}

g5_mom031_representative_allocations <- function(
  allocations,
  contract = g5_mom031_contract()
) {
  rows <- lapply(contract$representative_targets, function(target) {
    eligible <- which(allocations$decision_date <= target)
    if (!length(eligible)) return(NULL)
    row <- allocations[max(eligible), , drop = FALSE]
    row$representative_target <- target
    row
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  out <- do.call(rbind, rows)
  out <- out[!duplicated(out$decision_date), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_mom031_integrity <- function(
  panel,
  anchors,
  tapes,
  contract = g5_mom031_contract()
) {
  scores <- tapes$scores
  allocations <- tapes$allocations
  weight_columns <- paste0("weight_", contract$universe)
  asset_weight_sum <- rowSums(allocations[, weight_columns, drop = FALSE])
  slot_weight <- contract$sleeve_weight / contract$top_n_per_sleeve
  allowed_weights <- c(0, slot_weight, 2 * slot_weight)
  score_weights <- scores$target_weight
  performance_names <- c("return", "pnl", "profit", "sharpe", "drawdown", "wealth", "equity")
  exposed_names <- tolower(c(names(scores), names(allocations)))
  checks <- data.frame(
    check_id = c(
      "source_cutoff_frozen",
      "performance_surface_closed",
      "one_score_row_per_symbol_week",
      "next_common_open_after_decision",
      "at_most_three_selections_per_sleeve",
      "positive_veto_enforced",
      "weights_use_only_zero_one_or_two_slots",
      "asset_plus_cash_weights_sum_to_one",
      "cash_weight_bounded",
      "holiday_fallback_stays_mon_wed",
      "allocation_tape_nonempty"
    ),
    passed = c(
      max(panel$dates) <= contract$source_cutoff_date &&
        max(allocations$decision_date) <= contract$source_cutoff_date,
      !contract$performance_opened &&
        !any(vapply(performance_names, function(term) any(grepl(term, exposed_names)), logical(1))),
      nrow(scores) == nrow(allocations) * length(contract$universe),
      all(allocations$execution_date > allocations$decision_date),
      all(rowsum(as.integer(scores$selected_10w), scores$decision_date) <= contract$top_n_per_sleeve) &&
        all(rowsum(as.integer(scores$selected_25w), scores$decision_date) <= contract$top_n_per_sleeve),
      all(!scores$selected_10w | scores$roc_10w > contract$positive_roc_threshold) &&
        all(!scores$selected_25w | scores$roc_25w > contract$positive_roc_threshold),
      all(vapply(score_weights, function(value) any(abs(value - allowed_weights) < 1e-12), logical(1))),
      all(abs(asset_weight_sum + allocations$cash_weight - 1) < 1e-12),
      all(allocations$cash_weight >= -1e-12 & allocations$cash_weight <= 1 + 1e-12),
      all(!anchors$used_holiday_fallback |
        anchors$decision_date >= anchors$intended_wednesday - 2L),
      nrow(allocations) > 0L
    ),
    observed = c(
      as.character(max(allocations$decision_date)),
      paste(contract$performance_opened, paste(exposed_names, collapse = ","), sep = ";"),
      paste(nrow(scores), "rows for", nrow(allocations), "weeks"),
      paste(range(as.integer(allocations$execution_date - allocations$decision_date)), collapse = " to "),
      paste(max(rowsum(as.integer(scores$selected_10w), scores$decision_date)), max(rowsum(as.integer(scores$selected_25w), scores$decision_date)), sep = "/"),
      as.character(all(!scores$selected_10w | scores$roc_10w > 0) && all(!scores$selected_25w | scores$roc_25w > 0)),
      paste(sort(unique(round(score_weights, 12))), collapse = ","),
      sprintf("%.12f", max(abs(asset_weight_sum + allocations$cash_weight - 1))),
      paste(range(allocations$cash_weight), collapse = " to "),
      as.character(sum(anchors$used_holiday_fallback)),
      as.character(nrow(allocations))
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  checks
}

g5_mom031_run <- function(bars, contract = g5_mom031_contract()) {
  contract <- g5_mom031_validate_contract(contract)
  panel <- g5_mom031_common_panel(bars, contract)
  anchors <- g5_mom031_weekly_anchors(panel, contract)
  tapes <- g5_mom031_build_tapes(panel, anchors, contract)
  integrity <- g5_mom031_integrity(panel, anchors, tapes, contract)
  if (!all(integrity$passed)) {
    g5_mom031_stop(paste(
      "LIT-MOM-03.1 integrity failed:",
      paste(integrity$check_id[!integrity$passed], collapse = ", ")
    ))
  }
  representatives <- g5_mom031_representative_allocations(tapes$allocations, contract)
  list(
    contract = contract,
    panel = panel,
    anchors = anchors,
    scores = tapes$scores,
    allocations = tapes$allocations,
    representatives = representatives,
    integrity = integrity
  )
}
