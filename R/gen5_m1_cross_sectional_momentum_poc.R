# Gen5 M1 cross-sectional momentum POC helpers.

g5_m1_schema_version <- function() {
  "gen5_m1_cross_sectional_momentum_v0.1"
}

g5_m1_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message)
  stop(message, call. = FALSE)
}

g5_m1_universe <- function() {
  data.frame(
    symbol = c(
      "XLB", "XLE", "XLF", "XLI", "XLK", "XLP", "XLU", "XLV", "XLY",
      "EWA", "EWC", "EWG", "EWH", "EWJ", "EWL", "EWU",
      "EIDO", "EWT", "EWY", "EWZ", "EWW", "EZA", "FXI", "INDA"
    ),
    economic_group = c(
      rep("us_sector", 9L),
      rep("developed_country", 7L),
      rep("emerging_country", 8L)
    ),
    stringsAsFactors = FALSE
  )
}

g5_m1_contract <- function() {
  list(
    universe = g5_m1_universe(),
    cash_proxy = "BIL",
    reference_symbol = "XLB",
    primary_lookback_months = 12L,
    diagnostic_lookbacks = c(6L, 18L),
    skip_months = 1L,
    minimum_month_ends = 13L,
    recent_reference_sessions = 63L,
    minimum_recent_bars = 60L,
    minimum_adjusted_close = 5,
    minimum_median_dollar_volume = 5e6,
    minimum_eligible_total = 18L,
    minimum_eligible_by_group = c(
      us_sector = 6L,
      developed_country = 5L,
      emerging_country = 6L
    ),
    top_fraction = 0.25,
    random_policy_count = 2000L,
    random_seed = 5401L,
    random_percentile = 0.90,
    positive_ic_months = 21L,
    positive_spread_quarters = 7L,
    group_contribution_cap = 0.50,
    asset_contribution_cap = 0.25,
    year_contribution_cap = 0.50,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    turnover_cap = 0.50,
    drawdown_disadvantage_cap = 0.05,
    decision_start = as.Date("2017-01-01"),
    development_end = as.Date("2021-12-31"),
    confirmation_start = as.Date("2022-01-01"),
    confirmation_end = as.Date("2024-12-31"),
    shadow_start = as.Date("2025-01-01"),
    decision_end = as.Date("2026-06-30"),
    query_start = as.Date("2016-01-01"),
    query_end = as.Date("2026-07-01"),
    as_of_timestamp = "2026-07-27 17:30:00",
    decision_time = "17:30 America/New_York"
  )
}

g5_m1_validate_contract <- function(contract) {
  required <- c(
    "universe", "cash_proxy", "reference_symbol", "primary_lookback_months",
    "diagnostic_lookbacks", "skip_months", "minimum_month_ends",
    "recent_reference_sessions", "minimum_recent_bars",
    "minimum_adjusted_close", "minimum_median_dollar_volume",
    "minimum_eligible_total", "minimum_eligible_by_group", "top_fraction",
    "random_policy_count", "random_seed", "random_percentile",
    "positive_ic_months", "positive_spread_quarters",
    "group_contribution_cap", "asset_contribution_cap",
    "year_contribution_cap", "primary_cost_bps", "stress_cost_bps",
    "turnover_cap", "drawdown_disadvantage_cap", "decision_start",
    "development_end", "confirmation_start", "confirmation_end",
    "shadow_start", "decision_end", "query_start", "query_end",
    "as_of_timestamp", "decision_time"
  )
  missing <- setdiff(required, names(contract))
  if (length(missing)) {
    g5_m1_stop(paste("M1 contract is missing:", paste(missing, collapse = ", ")))
  }
  if (!is.data.frame(contract$universe) ||
      !all(c("symbol", "economic_group") %in% names(contract$universe))) {
    g5_m1_stop("M1 universe must contain symbol and economic_group.")
  }
  contract$universe$symbol <- toupper(as.character(contract$universe$symbol))
  contract$universe$economic_group <- as.character(contract$universe$economic_group)
  if (nrow(contract$universe) != 24L ||
      length(unique(contract$universe$symbol)) != 24L) {
    g5_m1_stop("M1 requires exactly twenty-four unique ETFs.")
  }
  expected_counts <- c(
    developed_country = 7L,
    emerging_country = 8L,
    us_sector = 9L
  )
  actual_counts <- table(contract$universe$economic_group)
  if (!identical(
    as.integer(actual_counts[names(expected_counts)]),
    as.integer(expected_counts)
  )) {
    g5_m1_stop("M1 economic-group counts must remain 9, 7, and 8.")
  }
  contract$cash_proxy <- toupper(as.character(contract$cash_proxy[[1L]]))
  contract$reference_symbol <- toupper(as.character(contract$reference_symbol[[1L]]))
  if (contract$cash_proxy %in% contract$universe$symbol) {
    g5_m1_stop("M1 cash proxy cannot be ranked.")
  }
  if (!contract$reference_symbol %in% contract$universe$symbol) {
    g5_m1_stop("M1 reference symbol must be one of the frozen ETFs.")
  }
  if (!identical(as.integer(contract$primary_lookback_months), 12L) ||
      !identical(sort(as.integer(contract$diagnostic_lookbacks)), c(6L, 18L)) ||
      !identical(as.integer(contract$skip_months), 1L)) {
    g5_m1_stop("M1 lookbacks must remain 12-minus-1 with 6-minus-1 and 18-minus-1 diagnostics.")
  }
  if (!identical(as.integer(contract$random_policy_count), 2000L) ||
      !identical(as.integer(contract$random_seed), 5401L) ||
      !isTRUE(all.equal(as.numeric(contract$random_percentile), 0.90))) {
    g5_m1_stop("M1 randomized control must remain 2,000 policies, seed 5401, and p90.")
  }
  if (!identical(as.numeric(contract$primary_cost_bps), 5) ||
      !identical(as.numeric(contract$stress_cost_bps), 10)) {
    g5_m1_stop("M1 cost assumptions must remain 5 and 10 bp one way.")
  }
  contract
}

g5_m1_required_symbols <- function(contract = g5_m1_contract()) {
  contract <- g5_m1_validate_contract(contract)
  c(contract$universe$symbol, contract$cash_proxy)
}

g5_m1_validate_bars <- function(bars, contract = g5_m1_contract()) {
  contract <- g5_m1_validate_contract(contract)
  if (!is.data.frame(bars) || !nrow(bars)) {
    g5_m1_stop("M1 requires a non-empty adjusted daily bar table.")
  }
  if (exists("g5_validate_bar_data", mode = "function")) {
    bars <- g5_validate_bar_data(bars)
  }
  required <- c("symbol", "session_date", "open", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_m1_stop(paste("M1 bars are missing:", paste(missing, collapse = ", ")))
  }
  bars$symbol <- toupper(as.character(bars$symbol))
  bars$session_date <- as.Date(bars$session_date)
  bars$open <- as.numeric(bars$open)
  bars$close <- as.numeric(bars$close)
  bars$volume <- as.numeric(bars$volume)
  if (any(is.na(bars$session_date))) g5_m1_stop("M1 bars contain invalid dates.")
  if (any(!is.finite(bars$open) | bars$open <= 0, na.rm = TRUE) ||
      any(!is.finite(bars$close) | bars$close <= 0, na.rm = TRUE) ||
      any(!is.finite(bars$volume) | bars$volume < 0, na.rm = TRUE)) {
    g5_m1_stop("M1 bars contain invalid prices or volume.")
  }
  key <- paste(bars$symbol, bars$session_date)
  if (anyDuplicated(key)) g5_m1_stop("M1 bars contain duplicate symbol/session rows.")
  missing_symbols <- setdiff(g5_m1_required_symbols(contract), unique(bars$symbol))
  if (length(missing_symbols)) {
    g5_m1_stop(paste("M1 bars are missing symbols:", paste(missing_symbols, collapse = ", ")))
  }
  bars <- bars[bars$symbol %in% g5_m1_required_symbols(contract), , drop = FALSE]
  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

g5_m1_month_id <- function(date) format(as.Date(date), "%Y-%m")

g5_m1_period_id <- function(date, contract = g5_m1_contract()) {
  date <- as.Date(date)
  ifelse(
    date <= contract$development_end,
    "development_2017_2021",
    ifelse(
      date >= contract$confirmation_start & date <= contract$confirmation_end,
      "confirmation_2022_2024",
      ifelse(date >= contract$shadow_start, "historical_shadow_2025_2026", "outside_contract")
    )
  )
}

g5_m1_reference_sessions <- function(bars, contract = g5_m1_contract()) {
  sessions <- sort(unique(as.Date(
    bars$session_date[bars$symbol == contract$reference_symbol]
  )))
  sessions <- sessions[sessions >= contract$query_start & sessions <= contract$query_end]
  if (!length(sessions)) g5_m1_stop("M1 reference symbol supplied no sessions.")
  sessions
}

g5_m1_schedule <- function(bars, contract = g5_m1_contract()) {
  contract <- g5_m1_validate_contract(contract)
  bars <- g5_m1_validate_bars(bars, contract)
  sessions <- g5_m1_reference_sessions(bars, contract)
  ids <- g5_m1_month_id(sessions)
  month_ends <- sort(as.Date(vapply(
    split(sessions, ids),
    function(x) as.character(max(as.Date(x))),
    character(1L)
  )))
  month_ends <- month_ends[month_ends <= contract$decision_end]
  next_session <- function(date) {
    future <- sessions[sessions > date]
    if (length(future)) future[[1L]] else as.Date(NA)
  }
  execution <- as.Date(vapply(
    month_ends,
    function(x) as.character(next_session(x)),
    character(1L)
  ))
  data.frame(
    month_index = seq_along(month_ends),
    month_id = g5_m1_month_id(month_ends),
    decision_date = month_ends,
    execution_date = execution,
    next_execution_date = c(execution[-1L], as.Date(NA)),
    stringsAsFactors = FALSE
  )
}

g5_m1_value_index <- function(bars, column) {
  values <- as.numeric(bars[[column]])
  names(values) <- paste(bars$symbol, bars$session_date, sep = "|")
  values
}

g5_m1_lookup <- function(index, symbol, date) {
  if (is.na(date)) return(NA_real_)
  value <- unname(index[paste(symbol, as.Date(date), sep = "|")])
  if (!length(value) || !is.finite(value[[1L]])) NA_real_ else value[[1L]]
}

g5_m1_build_panel <- function(
  bars,
  lookback_months = 12L,
  contract = g5_m1_contract()
) {
  contract <- g5_m1_validate_contract(contract)
  lookback_months <- as.integer(lookback_months)
  if (!lookback_months %in% c(6L, 12L, 18L)) {
    g5_m1_stop("M1 lookback must be 6, 12, or 18 months.")
  }
  bars <- g5_m1_validate_bars(bars, contract)
  schedule <- g5_m1_schedule(bars, contract)
  sessions <- g5_m1_reference_sessions(bars, contract)
  close_index <- g5_m1_value_index(bars, "close")
  open_index <- g5_m1_value_index(bars, "open")
  bars_by_symbol <- split(bars, bars$symbol)
  universe <- contract$universe
  rows <- list()
  for (schedule_i in seq_len(nrow(schedule))) {
    decision_date <- schedule$decision_date[[schedule_i]]
    if (decision_date < contract$decision_start) next
    prior_1_i <- schedule_i - contract$skip_months
    prior_l_i <- schedule_i - lookback_months
    prior_1_date <- if (prior_1_i >= 1L) schedule$decision_date[[prior_1_i]] else as.Date(NA)
    prior_l_date <- if (prior_l_i >= 1L) schedule$decision_date[[prior_l_i]] else as.Date(NA)
    execution_date <- schedule$execution_date[[schedule_i]]
    outcome_end_date <- schedule$next_execution_date[[schedule_i]]
    recent <- sessions[sessions <= decision_date]
    recent <- tail(recent, contract$recent_reference_sessions)
    month_end_count <- sum(schedule$decision_date <= decision_date)
    month_rows <- list()
    for (u_i in seq_len(nrow(universe))) {
      symbol <- universe$symbol[[u_i]]
      symbol_bars <- bars_by_symbol[[symbol]]
      symbol_recent <- symbol_bars[symbol_bars$session_date %in% recent, , drop = FALSE]
      decision_close <- g5_m1_lookup(close_index, symbol, decision_date)
      prior_1_close <- g5_m1_lookup(close_index, symbol, prior_1_date)
      prior_l_close <- g5_m1_lookup(close_index, symbol, prior_l_date)
      entry_open <- g5_m1_lookup(open_index, symbol, execution_date)
      exit_open <- g5_m1_lookup(open_index, symbol, outcome_end_date)
      median_dollar_volume <- if (nrow(symbol_recent)) {
        stats::median(symbol_recent$close * symbol_recent$volume, na.rm = TRUE)
      } else {
        NA_real_
      }
      has_history <- month_end_count >= contract$minimum_month_ends
      has_decision_close <- is.finite(decision_close)
      has_recent_bars <- length(recent) == contract$recent_reference_sessions &&
        nrow(symbol_recent) >= contract$minimum_recent_bars &&
        decision_date %in% symbol_recent$session_date
      price_ok <- is.finite(decision_close) &&
        decision_close >= contract$minimum_adjusted_close
      liquidity_ok <- is.finite(median_dollar_volume) &&
        median_dollar_volume >= contract$minimum_median_dollar_volume
      signal_prices_ok <- all(is.finite(c(prior_1_close, prior_l_close)))
      eligible <- has_history && has_decision_close && has_recent_bars &&
        price_ok && liquidity_ok && signal_prices_ok
      momentum <- if (eligible) log(prior_1_close / prior_l_close) else NA_real_
      outcome_available <- eligible && all(is.finite(c(entry_open, exit_open)))
      next_return <- if (outcome_available) exit_open / entry_open - 1 else NA_real_
      month_rows[[u_i]] <- data.frame(
        schema_version = g5_m1_schema_version(),
        lookback_months = lookback_months,
        symbol = symbol,
        economic_group = universe$economic_group[[u_i]],
        month_id = schedule$month_id[[schedule_i]],
        decision_date = decision_date,
        decision_time = contract$decision_time,
        prior_lookback_date = prior_l_date,
        prior_skip_date = prior_1_date,
        execution_date = execution_date,
        outcome_end_date = outcome_end_date,
        evaluation_period = g5_m1_period_id(decision_date, contract),
        recent_reference_count = length(recent),
        recent_observed_count = nrow(symbol_recent),
        decision_close = decision_close,
        median_dollar_volume_63 = median_dollar_volume,
        history_ok = has_history,
        freshness_ok = has_recent_bars,
        price_ok = price_ok,
        liquidity_ok = liquidity_ok,
        signal_prices_ok = signal_prices_ok,
        eligible = eligible,
        momentum_lookback_skip_log_return = momentum,
        entry_open = entry_open,
        exit_open = exit_open,
        outcome_available = outcome_available,
        next_month_return = next_return,
        stringsAsFactors = FALSE
      )
    }
    month_frame <- do.call(rbind, month_rows)
    group_counts <- table(factor(
      month_frame$economic_group[month_frame$eligible],
      levels = names(contract$minimum_eligible_by_group)
    ))
    breadth_ok <- sum(month_frame$eligible) >= contract$minimum_eligible_total &&
      all(group_counts >= contract$minimum_eligible_by_group[names(group_counts)])
    month_frame$eligible_count <- sum(month_frame$eligible)
    month_frame$eligible_us_sector <- unname(group_counts[["us_sector"]])
    month_frame$eligible_developed_country <- unname(group_counts[["developed_country"]])
    month_frame$eligible_emerging_country <- unname(group_counts[["emerging_country"]])
    month_frame$month_admissible <- breadth_ok
    month_frame$rank_ic_rank <- NA_real_
    month_frame$portfolio_rank <- NA_integer_
    month_frame$top_k <- FALSE
    month_frame$bottom_k <- FALSE
    month_frame$k_count <- if (breadth_ok) ceiling(sum(month_frame$eligible) * contract$top_fraction) else NA_integer_
    if (breadth_ok) {
      eligible_i <- which(month_frame$eligible)
      month_frame$rank_ic_rank[eligible_i] <- rank(
        -month_frame$momentum_lookback_skip_log_return[eligible_i],
        ties.method = "average"
      )
      ordered_i <- eligible_i[order(
        -month_frame$momentum_lookback_skip_log_return[eligible_i],
        month_frame$symbol[eligible_i]
      )]
      month_frame$portfolio_rank[ordered_i] <- seq_along(ordered_i)
      k <- month_frame$k_count[[1L]]
      month_frame$top_k[ordered_i[seq_len(k)]] <- TRUE
      month_frame$bottom_k[tail(ordered_i, k)] <- TRUE
    }
    rows[[length(rows) + 1L]] <- month_frame
  }
  panel <- do.call(rbind, rows)
  rownames(panel) <- NULL
  panel[order(panel$decision_date, match(panel$symbol, universe$symbol)), , drop = FALSE]
}

g5_m1_monthly_measurement <- function(panel) {
  dates <- sort(unique(panel$decision_date[
    panel$month_admissible & panel$outcome_available
  ]))
  rows <- lapply(dates, function(date) {
    part <- panel[
      panel$decision_date == date & panel$eligible,
      ,
      drop = FALSE
    ]
    if (!nrow(part) || !all(part$outcome_available)) return(NULL)
    top <- part$next_month_return[part$top_k]
    bottom <- part$next_month_return[part$bottom_k]
    panel_mean <- mean(part$next_month_return)
    data.frame(
      schema_version = g5_m1_schema_version(),
      lookback_months = part$lookback_months[[1L]],
      decision_date = as.Date(date),
      execution_date = part$execution_date[[1L]],
      outcome_end_date = part$outcome_end_date[[1L]],
      evaluation_period = part$evaluation_period[[1L]],
      calendar_year = as.integer(format(date, "%Y")),
      calendar_quarter = paste0(format(date, "%Y"), "Q", (as.integer(format(date, "%m")) - 1L) %/% 3L + 1L),
      eligible_count = nrow(part),
      k_count = sum(part$top_k),
      rank_ic = suppressWarnings(stats::cor(
        part$momentum_lookback_skip_log_return,
        part$next_month_return,
        method = "spearman"
      )),
      top_mean_return = mean(top),
      bottom_mean_return = mean(bottom),
      eligible_equal_weight_return = panel_mean,
      top_minus_bottom = mean(top) - mean(bottom),
      top_minus_eligible_equal_weight = mean(top) - panel_mean,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows[!vapply(rows, is.null, logical(1L))])
  if (is.null(out) || !nrow(out)) g5_m1_stop("M1 has no admissible matured monthly measurements.")
  out
}

g5_m1_complete_matured_dates <- function(panel, evaluation_period = NULL) {
  x <- panel[panel$month_admissible, , drop = FALSE]
  if (!is.null(evaluation_period)) {
    x <- x[x$evaluation_period == evaluation_period, , drop = FALSE]
  }
  dates <- sort(unique(x$decision_date))
  dates[vapply(dates, function(date) {
    part <- x[x$decision_date == date & x$eligible, , drop = FALSE]
    nrow(part) > 0L && all(part$outcome_available)
  }, logical(1L))]
}

g5_m1_quarterly_measurement <- function(monthly) {
  pieces <- split(monthly, list(monthly$lookback_months, monthly$calendar_quarter), drop = TRUE)
  do.call(rbind, lapply(pieces, function(part) {
    data.frame(
      schema_version = g5_m1_schema_version(),
      lookback_months = part$lookback_months[[1L]],
      evaluation_period = part$evaluation_period[[1L]],
      calendar_quarter = part$calendar_quarter[[1L]],
      month_count = nrow(part),
      mean_rank_ic = mean(part$rank_ic),
      mean_top_minus_bottom = mean(part$top_minus_bottom),
      mean_top_minus_eligible_equal_weight = mean(part$top_minus_eligible_equal_weight),
      stringsAsFactors = FALSE
    )
  }))
}

g5_m1_random_control <- function(
  panel,
  policy_count = 2000L,
  seed = 5401L,
  evaluation_period = "confirmation_2022_2024"
) {
  dates <- g5_m1_complete_matured_dates(panel, evaluation_period)
  if (!length(dates)) g5_m1_stop("M1 random control has no confirmation months.")
  x <- panel[panel$decision_date %in% dates, , drop = FALSE]
  policy_count <- as.integer(policy_count)
  set.seed(as.integer(seed))
  policy_means <- numeric(policy_count)
  detail <- vector("list", policy_count * length(dates))
  detail_i <- 0L
  for (policy_i in seq_len(policy_count)) {
    monthly_excess <- numeric(length(dates))
    for (date_i in seq_along(dates)) {
      part <- x[x$decision_date == dates[[date_i]] & x$eligible, , drop = FALSE]
      k <- unique(part$k_count)[[1L]]
      selected <- sample(seq_len(nrow(part)), k, replace = FALSE)
      excess <- mean(part$next_month_return[selected]) - mean(part$next_month_return)
      monthly_excess[[date_i]] <- excess
      detail_i <- detail_i + 1L
      detail[[detail_i]] <- data.frame(
        policy_id = policy_i,
        decision_date = as.Date(dates[[date_i]]),
        excess_return = excess,
        stringsAsFactors = FALSE
      )
    }
    policy_means[[policy_i]] <- mean(monthly_excess)
  }
  distribution <- data.frame(
    schema_version = g5_m1_schema_version(),
    policy_id = seq_len(policy_count),
    mean_confirmation_excess = policy_means,
    stringsAsFactors = FALSE
  )
  list(
    distribution = distribution,
    detail = do.call(rbind, detail),
    seed = as.integer(seed)
  )
}

g5_m1_contribution_attribution <- function(
  panel,
  evaluation_period = "confirmation_2022_2024"
) {
  dates <- g5_m1_complete_matured_dates(panel, evaluation_period)
  x <- panel[panel$decision_date %in% dates & panel$eligible, , drop = FALSE]
  x$calendar_year <- as.integer(format(x$decision_date, "%Y"))
  x$arithmetic_contribution <- ifelse(
    x$top_k,
    x$next_month_return / x$k_count,
    ifelse(x$bottom_k, -x$next_month_return / x$k_count, 0)
  )
  summarize <- function(group_columns) {
    groups <- lapply(group_columns, function(column) x[[column]])
    out <- aggregate(x$arithmetic_contribution, groups, sum)
    names(out) <- c(group_columns, "cumulative_arithmetic_contribution")
    positive_total <- sum(pmax(out$cumulative_arithmetic_contribution, 0))
    out$positive_contribution_share <- if (positive_total > 0) {
      pmax(out$cumulative_arithmetic_contribution, 0) / positive_total
    } else {
      NA_real_
    }
    out
  }
  list(
    detail = x[, c(
      "decision_date", "symbol", "economic_group", "calendar_year",
      "top_k", "bottom_k", "next_month_return", "arithmetic_contribution"
    )],
    by_asset = summarize("symbol"),
    by_group = summarize("economic_group"),
    by_year = summarize("calendar_year")
  )
}

g5_m1_session_coverage_audit <- function(bars, contract = g5_m1_contract()) {
  contract <- g5_m1_validate_contract(contract)
  bars <- g5_m1_validate_bars(bars, contract)
  reference <- g5_m1_reference_sessions(bars, contract)
  rows <- lapply(g5_m1_required_symbols(contract), function(symbol) {
    observed <- sort(unique(bars$session_date[
      bars$symbol == symbol &
        bars$session_date >= contract$query_start &
        bars$session_date <= contract$query_end
    ]))
    first_ok <- length(observed) && observed[[1L]] <= reference[[1L]]
    last_ok <- length(observed) && tail(observed, 1L) == tail(reference, 1L)
    data.frame(
      schema_version = g5_m1_schema_version(),
      symbol = symbol,
      reference_first_session = reference[[1L]],
      reference_last_session = tail(reference, 1L),
      reference_session_count = length(reference),
      observed_first_session = if (length(observed)) observed[[1L]] else as.Date(NA),
      observed_last_session = if (length(observed)) tail(observed, 1L) else as.Date(NA),
      observed_session_count = length(observed),
      missing_reference_sessions = length(setdiff(reference, observed)),
      first_session_ok = first_ok,
      last_session_ok = last_ok,
      status = if (first_ok && last_ok) "PASS" else "FAIL",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_m1_integrity_audit <- function(
  bars,
  panel,
  contract = g5_m1_contract(),
  data_health_status = "PASS"
) {
  contract <- g5_m1_validate_contract(contract)
  matured <- panel[panel$outcome_available, , drop = FALSE]
  eligible <- panel[panel$eligible, , drop = FALSE]
  session_coverage <- g5_m1_session_coverage_audit(bars, contract)
  key <- paste(bars$symbol, bars$session_date)
  breadth_invalid_ranked <- panel$portfolio_rank[
    !panel$month_admissible & !is.na(panel$portfolio_rank)
  ]
  data.frame(
    check_id = c(
      "canonical_adjusted_daily_bars",
      "all_frozen_symbols_present",
      "common_session_coverage",
      "unique_symbol_session_rows",
      "explicit_as_of_boundary",
      "point_in_time_eligibility",
      "next_open_execution",
      "common_open_to_open_outcomes",
      "no_outcome_in_signal",
      "monthly_breadth_enforced",
      "workbench_data_health"
    ),
    status = c(
      if ("adjustment" %in% names(bars)) {
        if (all(bars$adjustment == "all")) "PASS" else "FAIL"
      } else if ("adjusted" %in% names(bars)) {
        if (all(bars$adjusted)) "PASS" else "FAIL"
      } else "PASS",
      if (all(g5_m1_required_symbols(contract) %in% unique(bars$symbol))) "PASS" else "FAIL",
      if (all(session_coverage$status == "PASS")) "PASS" else "FAIL",
      if (!anyDuplicated(key)) "PASS" else "FAIL",
      if (max(bars$session_date) <= contract$query_end) "PASS" else "FAIL",
      if (all(eligible$prior_lookback_date < eligible$decision_date) &&
          all(eligible$prior_skip_date < eligible$decision_date)) "PASS" else "FAIL",
      if (all(eligible$execution_date > eligible$decision_date)) "PASS" else "FAIL",
      if (all(matured$outcome_end_date > matured$execution_date) &&
          all(vapply(split(matured, matured$decision_date), function(x) {
            length(unique(x$execution_date)) == 1L &&
              length(unique(x$outcome_end_date)) == 1L
          }, logical(1L)))) "PASS" else "FAIL",
      if (all(eligible$prior_skip_date < eligible$execution_date) &&
          all(eligible$prior_lookback_date < eligible$execution_date)) "PASS" else "FAIL",
      if (!length(breadth_invalid_ranked)) "PASS" else "FAIL",
      if (identical(as.character(data_health_status), "PASS")) "PASS" else "FAIL"
    ),
    detail = c(
      "Canonical adjusted 1D OHLCV bars only.",
      "Twenty-four ranked ETFs plus BIL are required.",
      "Every symbol spans the frozen reference interval through the final session.",
      "No duplicate symbol/session rows.",
      paste("Bars bounded by", contract$query_end, "under explicit as-of", contract$as_of_timestamp),
      "Eligibility uses only completed history through the decision.",
      "Every eligible decision enters strictly after month-end.",
      "Every matured cross-section shares one next-open interval.",
      "Signal and eligibility timestamps precede execution and outcome.",
      "Inadmissible months produce no ranks or membership.",
      paste("Analysis-level workbench health:", data_health_status)
    ),
    stringsAsFactors = FALSE
  )
}

g5_m1_diagnostic_summary <- function(diagnostic_panels) {
  do.call(rbind, lapply(diagnostic_panels, function(panel) {
    monthly <- g5_m1_monthly_measurement(panel)
    confirmation <- monthly[monthly$evaluation_period == "confirmation_2022_2024", , drop = FALSE]
    data.frame(
      schema_version = g5_m1_schema_version(),
      lookback_months = unique(panel$lookback_months)[[1L]],
      confirmation_month_count = nrow(confirmation),
      mean_rank_ic = mean(confirmation$rank_ic),
      mean_top_minus_bottom = mean(confirmation$top_minus_bottom),
      supports_primary = mean(confirmation$rank_ic) > 0 &&
        mean(confirmation$top_minus_bottom) > 0,
      stringsAsFactors = FALSE
    )
  }))
}

g5_m1_m1a_gates <- function(
  primary_panel,
  monthly,
  quarterly,
  random_control,
  attribution,
  integrity,
  diagnostics,
  contract = g5_m1_contract()
) {
  confirmation <- monthly[
    monthly$evaluation_period == "confirmation_2022_2024",
    ,
    drop = FALSE
  ]
  confirmation_quarters <- quarterly[
    quarterly$evaluation_period == "confirmation_2022_2024",
    ,
    drop = FALSE
  ]
  observed_excess <- mean(confirmation$top_minus_eligible_equal_weight)
  random_threshold <- as.numeric(stats::quantile(
    random_control$distribution$mean_confirmation_excess,
    probs = contract$random_percentile,
    names = FALSE,
    type = 7
  ))
  max_share <- function(x) {
    value <- suppressWarnings(max(x$positive_contribution_share, na.rm = TRUE))
    if (is.finite(value)) value else Inf
  }
  max_group <- max_share(attribution$by_group)
  max_asset <- max_share(attribution$by_asset)
  max_year <- max_share(attribution$by_year)
  diagnostic_reversals <- sum(!diagnostics$supports_primary)
  complete_confirmation <- nrow(confirmation) == 36L
  complete_confirmation_quarters <- nrow(confirmation_quarters) == 12L &&
    all(confirmation_quarters$month_count == 3L)
  pass <- c(
    all(integrity$status == "PASS"),
    complete_confirmation &&
      mean(confirmation$rank_ic) > 0 &&
      sum(confirmation$rank_ic > 0) >= contract$positive_ic_months,
    complete_confirmation_quarters &&
      mean(confirmation$top_minus_bottom) > 0 &&
      sum(confirmation_quarters$mean_top_minus_bottom > 0) >=
        contract$positive_spread_quarters,
    observed_excess > random_threshold,
    max_group <= contract$group_contribution_cap &&
      max_asset <= contract$asset_contribution_cap &&
      max_year <= contract$year_contribution_cap,
    diagnostic_reversals < 2L
  )
  gates <- data.frame(
    gate_id = paste0("M1A_G", seq_len(6L)),
    gate = c(
      "Integrity and timing",
      "Positive repeated rank IC",
      "Positive repeated top-minus-bottom ordering",
      "Observed top-K beats randomized concentration",
      "Group, ETF, and year concentration caps",
      "6-minus-1 and 18-minus-1 do not both reverse"
    ),
    status = ifelse(pass, "PASS", "FAIL"),
    value = c(
      paste(sum(integrity$status == "PASS"), "/", nrow(integrity)),
      paste0(sprintf("%.6f", mean(confirmation$rank_ic)), "; ", sum(confirmation$rank_ic > 0), " / ", nrow(confirmation)),
      paste0(sprintf("%.6f", mean(confirmation$top_minus_bottom)), "; ", sum(confirmation_quarters$mean_top_minus_bottom > 0), " / ", nrow(confirmation_quarters)),
      paste0(sprintf("%.6f", observed_excess), " vs p90 ", sprintf("%.6f", random_threshold)),
      paste0("group ", sprintf("%.3f", max_group), "; ETF ", sprintf("%.3f", max_asset), "; year ", sprintf("%.3f", max_year)),
      paste(diagnostic_reversals, "/ 2 reverse")
    ),
    stringsAsFactors = FALSE
  )
  list(
    gates = gates,
    pass = all(pass),
    observed_excess = observed_excess,
    random_threshold = random_threshold
  )
}

g5_m1_strategy_weights <- function(part, strategy, contract = g5_m1_contract()) {
  symbols <- g5_m1_required_symbols(contract)
  weights <- setNames(rep(0, length(symbols)), symbols)
  eligible <- part$symbol[part$eligible]
  if (identical(strategy, "m1_top_quartile")) {
    selected <- part$symbol[part$top_k]
    weights[selected] <- 1 / length(selected)
  } else if (identical(strategy, "eligible_equal_weight")) {
    weights[eligible] <- 1 / length(eligible)
  } else if (identical(strategy, "cash_bil")) {
    weights[[contract$cash_proxy]] <- 1
  } else if (identical(strategy, "bottom_quartile")) {
    selected <- part$symbol[part$bottom_k]
    weights[selected] <- 1 / length(selected)
  } else {
    g5_m1_stop(paste("Unknown M1 strategy:", strategy))
  }
  if (abs(sum(weights) - 1) > 1e-10 || any(weights < -1e-12)) {
    g5_m1_stop("M1 weights must be long-only and sum to one.")
  }
  weights
}

g5_m1_portfolio_replay <- function(
  panel,
  bars,
  cost_bps,
  contract = g5_m1_contract()
) {
  contract <- g5_m1_validate_contract(contract)
  bars <- g5_m1_validate_bars(bars, contract)
  open_index <- g5_m1_value_index(bars, "open")
  strategies <- c(
    "m1_top_quartile", "eligible_equal_weight", "cash_bil",
    "bottom_quartile"
  )
  dates <- sort(unique(panel$decision_date[
    panel$month_admissible & panel$outcome_available
  ]))
  previous <- setNames(lapply(strategies, function(x) {
    setNames(rep(0, length(g5_m1_required_symbols(contract))), g5_m1_required_symbols(contract))
  }), strategies)
  wealth <- setNames(rep(1, length(strategies)), strategies)
  rows <- list()
  weight_rows <- list()
  cost_rate <- cost_bps / 10000
  for (date in dates) {
    part <- panel[panel$decision_date == date, , drop = FALSE]
    eligible_part <- part[part$eligible, , drop = FALSE]
    if (!all(eligible_part$outcome_available)) next
    asset_returns <- setNames(part$next_month_return, part$symbol)
    bil_entry <- g5_m1_lookup(open_index, contract$cash_proxy, part$execution_date[[1L]])
    bil_exit <- g5_m1_lookup(open_index, contract$cash_proxy, part$outcome_end_date[[1L]])
    asset_returns[[contract$cash_proxy]] <- bil_exit / bil_entry - 1
    for (strategy in strategies) {
      weights <- g5_m1_strategy_weights(part, strategy, contract)
      used <- names(weights)[weights > 0]
      if (any(!is.finite(asset_returns[used]))) {
        g5_m1_stop(paste("M1 replay contains missing selected return at", date))
      }
      gross_return <- sum(weights[used] * asset_returns[used])
      gross_traded_notional <- sum(abs(weights - previous[[strategy]]))
      turnover <- gross_traded_notional / 2
      implementation_cost <- cost_rate * gross_traded_notional
      net_return <- (1 - implementation_cost) * (1 + gross_return) - 1
      wealth[[strategy]] <- wealth[[strategy]] * (1 + net_return)
      rows[[length(rows) + 1L]] <- data.frame(
        schema_version = g5_m1_schema_version(),
        strategy_id = strategy,
        cost_bps = cost_bps,
        decision_date = as.Date(date),
        execution_date = part$execution_date[[1L]],
        outcome_end_date = part$outcome_end_date[[1L]],
        evaluation_period = part$evaluation_period[[1L]],
        eligible_count = sum(part$eligible),
        k_count = unique(part$k_count)[[1L]],
        gross_return = gross_return,
        gross_traded_notional = gross_traded_notional,
        one_way_turnover = turnover,
        implementation_cost = implementation_cost,
        net_return = net_return,
        wealth = wealth[[strategy]],
        stringsAsFactors = FALSE
      )
      weight_rows[[length(weight_rows) + 1L]] <- data.frame(
        schema_version = g5_m1_schema_version(),
        strategy_id = strategy,
        cost_bps = cost_bps,
        decision_date = as.Date(date),
        symbol = names(weights),
        weight = as.numeric(weights),
        stringsAsFactors = FALSE
      )
      previous[[strategy]] <- weights
    }
  }
  replay <- do.call(rbind, rows)
  replay$drawdown <- ave(replay$wealth, replay$strategy_id, FUN = function(x) {
    x / cummax(c(1, x))[-1L] - 1
  })
  list(replay = replay, weights = do.call(rbind, weight_rows))
}

g5_m1_metrics <- function(replay, evaluation_period = NULL) {
  x <- replay
  if (!is.null(evaluation_period)) {
    x <- x[x$evaluation_period %in% evaluation_period, , drop = FALSE]
  }
  if (!nrow(x)) g5_m1_stop("M1 replay has no requested rows.")
  do.call(rbind, lapply(split(x, x$strategy_id), function(part) {
    part <- part[order(part$decision_date), , drop = FALSE]
    cumulative <- prod(1 + part$net_return) - 1
    cagr <- (1 + cumulative)^(12 / nrow(part)) - 1
    wealth <- cumprod(1 + part$net_return)
    drawdown <- wealth / cummax(c(1, wealth))[-1L] - 1
    data.frame(
      schema_version = g5_m1_schema_version(),
      strategy_id = part$strategy_id[[1L]],
      cost_bps = part$cost_bps[[1L]],
      evaluation_period = if (is.null(evaluation_period)) "all_matured" else evaluation_period,
      period_count = nrow(part),
      cumulative_net_return = cumulative,
      annualized_compound_return = cagr,
      annualized_volatility = stats::sd(part$net_return) * sqrt(12),
      maximum_drawdown = min(drawdown),
      return_over_abs_drawdown = if (min(drawdown) < 0) cagr / abs(min(drawdown)) else NA_real_,
      median_monthly_one_way_turnover = stats::median(part$one_way_turnover),
      mean_monthly_one_way_turnover = mean(part$one_way_turnover),
      worst_month = min(part$net_return),
      stringsAsFactors = FALSE
    )
  }))
}

g5_m1_metric <- function(metrics, strategy, column) {
  value <- metrics[metrics$strategy_id == strategy, column, drop = TRUE]
  if (length(value)) as.numeric(value[[1L]]) else NA_real_
}

g5_m1_m1b_gates <- function(primary_replay, stress_replay, contract = g5_m1_contract()) {
  primary <- g5_m1_metrics(primary_replay, "confirmation_2022_2024")
  stress <- g5_m1_metrics(stress_replay, "confirmation_2022_2024")
  m1_cagr <- g5_m1_metric(primary, "m1_top_quartile", "annualized_compound_return")
  ew_cagr <- g5_m1_metric(primary, "eligible_equal_weight", "annualized_compound_return")
  stress_m1 <- g5_m1_metric(stress, "m1_top_quartile", "annualized_compound_return")
  stress_ew <- g5_m1_metric(stress, "eligible_equal_weight", "annualized_compound_return")
  turnover <- g5_m1_metric(primary, "m1_top_quartile", "median_monthly_one_way_turnover")
  m1_dd <- abs(g5_m1_metric(primary, "m1_top_quartile", "maximum_drawdown"))
  ew_dd <- abs(g5_m1_metric(primary, "eligible_equal_weight", "maximum_drawdown"))
  pass <- c(
    m1_cagr > ew_cagr,
    stress_m1 > stress_ew,
    turnover <= contract$turnover_cap,
    m1_dd <= ew_dd + contract$drawdown_disadvantage_cap
  )
  list(
    gates = data.frame(
      gate_id = paste0("M1B_G", 7:10),
      gate = c(
        "M1 net CAGR beats eligible equal weight at 5 bp",
        "M1 advantage survives 10 bp",
        "Median monthly one-way turnover at or below 50%",
        "Maximum drawdown no more than 5 pp worse"
      ),
      status = ifelse(pass, "PASS", "FAIL"),
      value = c(
        sprintf("%.6f", m1_cagr - ew_cagr),
        sprintf("%.6f", stress_m1 - stress_ew),
        sprintf("%.6f", turnover),
        sprintf("%.6f", m1_dd - ew_dd)
      ),
      stringsAsFactors = FALSE
    ),
    pass = all(pass),
    primary_metrics = primary,
    stress_metrics = stress
  )
}

g5_m1_not_run_gates <- function() {
  data.frame(
    gate_id = paste0("M1B_G", 7:10),
    gate = c(
      "M1 net CAGR beats eligible equal weight at 5 bp",
      "M1 advantage survives 10 bp",
      "Median monthly one-way turnover at or below 50%",
      "Maximum drawdown no more than 5 pp worse"
    ),
    status = "NOT_RUN",
    value = "M1A gate failure",
    stringsAsFactors = FALSE
  )
}

g5_m1_run_analysis <- function(
  bars,
  contract = g5_m1_contract(),
  data_health_status = "PASS"
) {
  contract <- g5_m1_validate_contract(contract)
  bars <- g5_m1_validate_bars(bars, contract)
  primary_panel <- g5_m1_build_panel(bars, contract$primary_lookback_months, contract)
  diagnostic_panels <- setNames(lapply(contract$diagnostic_lookbacks, function(x) {
    g5_m1_build_panel(bars, x, contract)
  }), paste0("lookback_", contract$diagnostic_lookbacks))
  monthly <- g5_m1_monthly_measurement(primary_panel)
  quarterly <- g5_m1_quarterly_measurement(monthly)
  random_control <- g5_m1_random_control(
    primary_panel,
    contract$random_policy_count,
    contract$random_seed
  )
  attribution <- g5_m1_contribution_attribution(primary_panel)
  integrity <- g5_m1_integrity_audit(
    bars, primary_panel, contract, data_health_status
  )
  diagnostics <- g5_m1_diagnostic_summary(diagnostic_panels)
  m1a <- g5_m1_m1a_gates(
    primary_panel, monthly, quarterly, random_control, attribution,
    integrity, diagnostics, contract
  )
  if (!m1a$pass) {
    return(list(
      contract = contract,
      primary_panel = primary_panel,
      diagnostic_panels = diagnostic_panels,
      monthly_measurement = monthly,
      quarterly_measurement = quarterly,
      random_control = random_control,
      attribution = attribution,
      integrity = integrity,
      diagnostic_summary = diagnostics,
      gates = rbind(m1a$gates, g5_m1_not_run_gates()),
      m1a_pass = FALSE,
      m1b_run = FALSE,
      primary_replay = NULL,
      primary_weights = NULL,
      stress_replay = NULL,
      stress_weights = NULL,
      primary_confirmation_metrics = NULL,
      stress_confirmation_metrics = NULL,
      session_coverage = g5_m1_session_coverage_audit(bars, contract),
      overall_status = "STOP_M1_RANKING_MECHANISM"
    ))
  }
  primary_replay <- g5_m1_portfolio_replay(
    primary_panel, bars, contract$primary_cost_bps, contract
  )
  stress_replay <- g5_m1_portfolio_replay(
    primary_panel, bars, contract$stress_cost_bps, contract
  )
  m1b <- g5_m1_m1b_gates(primary_replay$replay, stress_replay$replay, contract)
  list(
    contract = contract,
    primary_panel = primary_panel,
    diagnostic_panels = diagnostic_panels,
    monthly_measurement = monthly,
    quarterly_measurement = quarterly,
    random_control = random_control,
    attribution = attribution,
    integrity = integrity,
    diagnostic_summary = diagnostics,
    gates = rbind(m1a$gates, m1b$gates),
    m1a_pass = TRUE,
    m1b_run = TRUE,
    primary_replay = primary_replay$replay,
    primary_weights = primary_replay$weights,
    stress_replay = stress_replay$replay,
    stress_weights = stress_replay$weights,
    primary_confirmation_metrics = m1b$primary_metrics,
    stress_confirmation_metrics = m1b$stress_metrics,
    session_coverage = g5_m1_session_coverage_audit(bars, contract),
    overall_status = if (m1b$pass) {
      "PASS_M1_TO_PROSPECTIVE_SHADOW"
    } else {
      "STOP_M1_PORTFOLIO_IMPLEMENTATION"
    }
  )
}
