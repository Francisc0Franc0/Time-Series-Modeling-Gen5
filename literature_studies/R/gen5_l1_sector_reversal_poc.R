# Gen5 L1 frozen long-short sector-reversal POC helpers.

g5_l1_schema_version <- function() {
  "gen5_l1_sector_reversal_v0.1"
}
g5_l1_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message)
  stop(message, call. = FALSE)
}

g5_l1_universe <- function() {
  data.frame(
    symbol = c("XLB", "XLE", "XLF", "XLI", "XLK", "XLP", "XLU", "XLV", "XLY"),
    sector = c(
      "Materials", "Energy", "Financials", "Industrials", "Technology",
      "Consumer Staples", "Utilities", "Health Care", "Consumer Discretionary"
    ),
    stringsAsFactors = FALSE
  )
}

g5_l1_contract <- function() {
  list(
    universe = g5_l1_universe(),
    benchmark = "SPY",
    reference_symbol = "XLB",
    lookback_sessions = 5L,
    holding_sessions = 5L,
    long_count = 2L,
    short_count = 2L,
    long_gross = 0.50,
    short_gross = 0.50,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    primary_borrow_bps_annual = 0,
    stress_borrow_bps_annual = 100,
    bootstrap_replicates = 2000L,
    bootstrap_block_cohorts = 4L,
    bootstrap_seed = 5701L,
    random_policy_count = 2000L,
    random_seed = 5702L,
    random_percentile = 0.90,
    train_positive_years = 3L,
    confirmation_positive_years = 2L,
    positive_contribution_cap = 0.35,
    periods = data.frame(
      evaluation_period = c("TRAIN", "DEVELOPMENT", "CONFIRMATION"),
      start_date = as.Date(c("2016-01-04", "2021-01-01", "2024-01-01")),
      end_date = as.Date(c("2020-12-31", "2023-12-31", "2026-07-24")),
      stringsAsFactors = FALSE
    ),
    query_start = as.Date("2016-01-04"),
    query_end = as.Date("2026-07-24"),
    as_of_timestamp = "2026-07-24 17:30:00",
    decision_time = "17:30 America/New_York"
  )
}

g5_l1_validate_contract <- function(contract) {
  required <- c(
    "universe", "benchmark", "reference_symbol", "lookback_sessions",
    "holding_sessions", "long_count", "short_count", "long_gross",
    "short_gross", "primary_cost_bps", "stress_cost_bps",
    "primary_borrow_bps_annual", "stress_borrow_bps_annual",
    "bootstrap_replicates", "bootstrap_block_cohorts", "bootstrap_seed",
    "random_policy_count", "random_seed", "random_percentile",
    "train_positive_years", "confirmation_positive_years",
    "positive_contribution_cap", "periods", "query_start", "query_end",
    "as_of_timestamp", "decision_time"
  )
  missing <- setdiff(required, names(contract))
  if (length(missing)) {
    g5_l1_stop(paste("L1 contract is missing:", paste(missing, collapse = ", ")))
  }
  if (!is.data.frame(contract$universe) ||
      !all(c("symbol", "sector") %in% names(contract$universe))) {
    g5_l1_stop("L1 universe must contain symbol and sector.")
  }
  contract$universe$symbol <- toupper(as.character(contract$universe$symbol))
  if (nrow(contract$universe) != 9L ||
      length(unique(contract$universe$symbol)) != 9L) {
    g5_l1_stop("L1 requires exactly nine unique sector ETFs.")
  }
  expected <- c("XLB", "XLE", "XLF", "XLI", "XLK", "XLP", "XLU", "XLV", "XLY")
  if (!identical(contract$universe$symbol, expected)) {
    g5_l1_stop("L1 sector ETF order is frozen.")
  }
  if (!identical(as.integer(contract$lookback_sessions), 5L) ||
      !identical(as.integer(contract$holding_sessions), 5L) ||
      !identical(as.integer(contract$long_count), 2L) ||
      !identical(as.integer(contract$short_count), 2L)) {
    g5_l1_stop("L1 must remain a five-by-five, two-long, two-short rule.")
  }
  if (!isTRUE(all.equal(as.numeric(contract$long_gross), 0.50)) ||
      !isTRUE(all.equal(as.numeric(contract$short_gross), 0.50))) {
    g5_l1_stop("L1 gross exposure must remain 50 percent long and 50 percent short.")
  }
  if (!identical(as.numeric(contract$primary_cost_bps), 5) ||
      !identical(as.numeric(contract$stress_cost_bps), 10) ||
      !identical(as.numeric(contract$primary_borrow_bps_annual), 0) ||
      !identical(as.numeric(contract$stress_borrow_bps_annual), 100)) {
    g5_l1_stop("L1 cost and borrow assumptions are frozen.")
  }
  if (!identical(as.integer(contract$bootstrap_replicates), 2000L) ||
      !identical(as.integer(contract$bootstrap_block_cohorts), 4L) ||
      !identical(as.integer(contract$bootstrap_seed), 5701L) ||
      !identical(as.integer(contract$random_policy_count), 2000L) ||
      !identical(as.integer(contract$random_seed), 5702L) ||
      !isTRUE(all.equal(as.numeric(contract$random_percentile), 0.90))) {
    g5_l1_stop("L1 resampling settings are frozen.")
  }
  if (!is.data.frame(contract$periods) ||
      !all(c("evaluation_period", "start_date", "end_date") %in%
        names(contract$periods)) ||
      !identical(as.character(contract$periods$evaluation_period),
        c("TRAIN", "DEVELOPMENT", "CONFIRMATION"))) {
    g5_l1_stop("L1 chronological partitions are invalid.")
  }
  contract$periods$start_date <- as.Date(contract$periods$start_date)
  contract$periods$end_date <- as.Date(contract$periods$end_date)
  contract
}

g5_l1_required_symbols <- function(contract = g5_l1_contract()) {
  contract <- g5_l1_validate_contract(contract)
  c(contract$universe$symbol, contract$benchmark)
}

g5_l1_validate_bars <- function(bars, contract = g5_l1_contract()) {
  contract <- g5_l1_validate_contract(contract)
  if (!is.data.frame(bars) || !nrow(bars)) {
    g5_l1_stop("L1 requires a non-empty adjusted daily bar table.")
  }
  if (exists("g5_validate_bar_data", mode = "function")) {
    bars <- g5_validate_bar_data(bars)
  }
  required <- c("symbol", "session_date", "open", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_l1_stop(paste("L1 bars are missing:", paste(missing, collapse = ", ")))
  }
  bars$symbol <- toupper(as.character(bars$symbol))
  bars$session_date <- as.Date(bars$session_date)
  bars$open <- as.numeric(bars$open)
  bars$close <- as.numeric(bars$close)
  bars$volume <- as.numeric(bars$volume)
  if (any(is.na(bars$session_date))) g5_l1_stop("L1 bars contain invalid dates.")
  if (any(!is.finite(bars$open) | bars$open <= 0) ||
      any(!is.finite(bars$close) | bars$close <= 0) ||
      any(!is.finite(bars$volume) | bars$volume < 0)) {
    g5_l1_stop("L1 bars contain invalid prices or volume.")
  }
  key <- paste(bars$symbol, bars$session_date)
  if (anyDuplicated(key)) g5_l1_stop("L1 bars contain duplicate symbol/session rows.")
  missing_symbols <- setdiff(g5_l1_required_symbols(contract), unique(bars$symbol))
  if (length(missing_symbols)) {
    g5_l1_stop(paste("L1 bars are missing symbols:", paste(missing_symbols, collapse = ", ")))
  }
  bars <- bars[bars$symbol %in% g5_l1_required_symbols(contract), , drop = FALSE]
  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

g5_l1_reference_sessions <- function(bars, contract = g5_l1_contract()) {
  bars <- g5_l1_validate_bars(bars, contract)
  sessions <- sort(unique(bars$session_date[
    bars$symbol == contract$reference_symbol &
      bars$session_date >= contract$query_start &
      bars$session_date <= contract$query_end
  ]))
  if (!length(sessions)) g5_l1_stop("L1 reference ETF supplied no sessions.")
  sessions
}

g5_l1_schedule <- function(bars, contract = g5_l1_contract(), periods = NULL) {
  contract <- g5_l1_validate_contract(contract)
  sessions <- g5_l1_reference_sessions(bars, contract)
  period_table <- contract$periods
  if (!is.null(periods)) {
    period_table <- period_table[period_table$evaluation_period %in% periods, , drop = FALSE]
  }
  rows <- list()
  for (p_i in seq_len(nrow(period_table))) {
    period <- period_table[p_i, , drop = FALSE]
    part <- sessions[
      sessions >= period$start_date[[1L]] &
        sessions <= period$end_date[[1L]]
    ]
    first_signal_i <- contract$lookback_sessions + 1L
    last_signal_i <- length(part) - contract$holding_sessions - 1L
    if (last_signal_i < first_signal_i) next
    signal_i <- seq(first_signal_i, last_signal_i, by = contract$holding_sessions)
    rows[[length(rows) + 1L]] <- data.frame(
      schema_version = g5_l1_schema_version(),
      evaluation_period = period$evaluation_period[[1L]],
      cohort_number = seq_along(signal_i),
      cohort_id = paste0(
        period$evaluation_period[[1L]], "_",
        sprintf("%03d", seq_along(signal_i))
      ),
      signal_window_start_date = part[signal_i - contract$lookback_sessions],
      decision_date = part[signal_i],
      execution_date = part[signal_i + 1L],
      exit_date = part[signal_i + 1L + contract$holding_sessions],
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) g5_l1_stop("L1 schedule produced no cohorts.")
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_l1_value_index <- function(bars, column) {
  values <- as.numeric(bars[[column]])
  names(values) <- paste(bars$symbol, bars$session_date, sep = "|")
  values
}

g5_l1_lookup <- function(index, symbol, date) {
  value <- unname(index[paste(symbol, as.Date(date), sep = "|")])
  if (!length(value) || !is.finite(value[[1L]])) NA_real_ else value[[1L]]
}

g5_l1_build_panel <- function(
  bars,
  contract = g5_l1_contract(),
  periods = NULL
) {
  contract <- g5_l1_validate_contract(contract)
  bars <- g5_l1_validate_bars(bars, contract)
  schedule <- g5_l1_schedule(bars, contract, periods)
  close_index <- g5_l1_value_index(bars, "close")
  open_index <- g5_l1_value_index(bars, "open")
  rows <- vector("list", nrow(schedule))
  for (s_i in seq_len(nrow(schedule))) {
    schedule_row <- schedule[s_i, , drop = FALSE]
    cohort <- lapply(seq_len(nrow(contract$universe)), function(u_i) {
      symbol <- contract$universe$symbol[[u_i]]
      prior_close <- g5_l1_lookup(
        close_index, symbol, schedule_row$signal_window_start_date[[1L]]
      )
      decision_close <- g5_l1_lookup(
        close_index, symbol, schedule_row$decision_date[[1L]]
      )
      entry_open <- g5_l1_lookup(
        open_index, symbol, schedule_row$execution_date[[1L]]
      )
      exit_open <- g5_l1_lookup(
        open_index, symbol, schedule_row$exit_date[[1L]]
      )
      data.frame(
        schema_version = g5_l1_schema_version(),
        evaluation_period = schedule_row$evaluation_period[[1L]],
        cohort_id = schedule_row$cohort_id[[1L]],
        cohort_number = schedule_row$cohort_number[[1L]],
        symbol = symbol,
        sector = contract$universe$sector[[u_i]],
        signal_window_start_date = schedule_row$signal_window_start_date[[1L]],
        decision_date = schedule_row$decision_date[[1L]],
        decision_time = contract$decision_time,
        execution_date = schedule_row$execution_date[[1L]],
        exit_date = schedule_row$exit_date[[1L]],
        prior_close = prior_close,
        decision_close = decision_close,
        entry_open = entry_open,
        exit_open = exit_open,
        signal_return = decision_close / prior_close - 1,
        future_return = exit_open / entry_open - 1,
        stringsAsFactors = FALSE
      )
    })
    cohort <- do.call(rbind, cohort)
    if (any(!is.finite(cohort$signal_return)) ||
        any(!is.finite(cohort$future_return))) {
      g5_l1_stop(paste("L1 cohort contains unavailable prices:", schedule_row$cohort_id))
    }
    ordered <- order(cohort$signal_return, cohort$symbol)
    cohort$rank <- NA_integer_
    cohort$rank[ordered] <- seq_len(nrow(cohort))
    cohort$position <- "NONE"
    cohort$position[cohort$rank <= contract$long_count] <- "LONG"
    cohort$position[
      cohort$rank > nrow(cohort) - contract$short_count
    ] <- "SHORT"
    cohort$weight <- 0
    cohort$weight[cohort$position == "LONG"] <-
      contract$long_gross / contract$long_count
    cohort$weight[cohort$position == "SHORT"] <-
      -contract$short_gross / contract$short_count
    cohort$predicted_direction <- ifelse(
      cohort$position == "LONG", "UP",
      ifelse(cohort$position == "SHORT", "DOWN", "NONE")
    )
    cohort$realized_direction <- ifelse(cohort$future_return > 0, "UP", "DOWN")
    cohort$direction_correct <- ifelse(
      cohort$position == "NONE",
      NA,
      cohort$predicted_direction == cohort$realized_direction
    )
    cohort$arithmetic_contribution <- cohort$weight * cohort$future_return
    rows[[s_i]] <- cohort
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$execution_date, out$rank), , drop = FALSE]
}

g5_l1_borrow_cost <- function(contract, borrow_bps_annual) {
  borrow_bps_annual / 10000 *
    contract$short_gross *
    contract$holding_sessions / 252
}

g5_l1_cohort_summary <- function(
  panel,
  cost_bps,
  borrow_bps_annual,
  contract = g5_l1_contract()
) {
  contract <- g5_l1_validate_contract(contract)
  pieces <- split(panel, panel$cohort_id)
  rows <- lapply(pieces, function(part) {
    part <- part[order(part$rank), , drop = FALSE]
    long <- part$future_return[part$position == "LONG"]
    short <- part$future_return[part$position == "SHORT"]
    gross_spread <- mean(long) - mean(short)
    gross_portfolio <- sum(part$weight * part$future_return)
    transaction_cost <- 2 * cost_bps / 10000
    borrow_cost <- g5_l1_borrow_cost(contract, borrow_bps_annual)
    net_return <- gross_portfolio - transaction_cost - borrow_cost
    data.frame(
      schema_version = g5_l1_schema_version(),
      evaluation_period = part$evaluation_period[[1L]],
      cohort_id = part$cohort_id[[1L]],
      cohort_number = part$cohort_number[[1L]],
      decision_date = part$decision_date[[1L]],
      execution_date = part$execution_date[[1L]],
      exit_date = part$exit_date[[1L]],
      calendar_year = as.integer(format(part$execution_date[[1L]], "%Y")),
      rank_ic = suppressWarnings(stats::cor(
        part$signal_return, part$future_return, method = "spearman"
      )),
      long_mean_return = mean(long),
      short_mean_return = mean(short),
      gross_long_minus_short_spread = gross_spread,
      gross_portfolio_return = gross_portfolio,
      transaction_cost = transaction_cost,
      borrow_cost = borrow_cost,
      net_portfolio_return = net_return,
      reverse_net_return = -gross_portfolio - transaction_cost - borrow_cost,
      spread_direction_correct = gross_spread > 0,
      long_up_count = sum(long > 0),
      short_down_count = sum(short < 0),
      selected_leg_count = length(long) + length(short),
      long_symbols = paste(part$symbol[part$position == "LONG"], collapse = ","),
      short_symbols = paste(part$symbol[part$position == "SHORT"], collapse = ","),
      cost_bps = cost_bps,
      borrow_bps_annual = borrow_bps_annual,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$execution_date), , drop = FALSE]
}

g5_l1_moving_block_indices <- function(n, block_length) {
  starts <- seq_len(max(1L, n - block_length + 1L))
  block_count <- ceiling(n / block_length)
  chosen <- sample(starts, block_count, replace = TRUE)
  indices <- unlist(lapply(chosen, function(start) {
    seq.int(start, min(n, start + block_length - 1L))
  }), use.names = FALSE)
  indices[seq_len(n)]
}

g5_l1_block_bootstrap <- function(
  cohorts,
  contract = g5_l1_contract()
) {
  contract <- g5_l1_validate_contract(contract)
  metrics <- c("rank_ic", "net_portfolio_return")
  n <- nrow(cohorts)
  if (n < contract$bootstrap_block_cohorts * 2L) {
    g5_l1_stop("L1 has too few cohorts for the frozen block bootstrap.")
  }
  set.seed(contract$bootstrap_seed)
  draws <- matrix(
    NA_real_,
    nrow = contract$bootstrap_replicates,
    ncol = length(metrics),
    dimnames = list(NULL, metrics)
  )
  for (i in seq_len(contract$bootstrap_replicates)) {
    indices <- g5_l1_moving_block_indices(n, contract$bootstrap_block_cohorts)
    draws[i, ] <- vapply(metrics, function(metric) {
      mean(cohorts[[metric]][indices], na.rm = TRUE)
    }, numeric(1L))
  }
  summary <- do.call(rbind, lapply(metrics, function(metric) {
    data.frame(
      schema_version = g5_l1_schema_version(),
      metric = metric,
      observed_mean = mean(cohorts[[metric]], na.rm = TRUE),
      ci_lower = as.numeric(stats::quantile(draws[, metric], 0.025, names = FALSE)),
      ci_upper = as.numeric(stats::quantile(draws[, metric], 0.975, names = FALSE)),
      replicates = contract$bootstrap_replicates,
      block_cohorts = contract$bootstrap_block_cohorts,
      seed = contract$bootstrap_seed,
      stringsAsFactors = FALSE
    )
  }))
  list(summary = summary, draws = as.data.frame(draws))
}

g5_l1_random_control <- function(
  panel,
  cost_bps,
  borrow_bps_annual,
  contract = g5_l1_contract(),
  seed_offset = 0L
) {
  contract <- g5_l1_validate_contract(contract)
  pieces <- split(panel, panel$cohort_id)
  set.seed(contract$random_seed + as.integer(seed_offset))
  policy_means <- numeric(contract$random_policy_count)
  fixed_cost <- 2 * cost_bps / 10000 +
    g5_l1_borrow_cost(contract, borrow_bps_annual)
  for (policy_i in seq_len(contract$random_policy_count)) {
    values <- vapply(pieces, function(part) {
      long_i <- sample(seq_len(nrow(part)), contract$long_count, replace = FALSE)
      remaining <- setdiff(seq_len(nrow(part)), long_i)
      short_i <- sample(remaining, contract$short_count, replace = FALSE)
      contract$long_gross / contract$long_count *
        sum(part$future_return[long_i]) -
        contract$short_gross / contract$short_count *
        sum(part$future_return[short_i]) -
        fixed_cost
    }, numeric(1L))
    policy_means[[policy_i]] <- mean(values)
  }
  distribution <- data.frame(
    schema_version = g5_l1_schema_version(),
    policy_id = seq_along(policy_means),
    mean_net_return = policy_means,
    stringsAsFactors = FALSE
  )
  list(
    distribution = distribution,
    p90 = as.numeric(stats::quantile(
      policy_means, contract$random_percentile, names = FALSE
    )),
    seed = contract$random_seed + as.integer(seed_offset)
  )
}

g5_l1_wilson_interval <- function(successes, total, level = 0.95) {
  if (!total) return(c(lower = NA_real_, upper = NA_real_))
  z <- stats::qnorm(1 - (1 - level) / 2)
  p <- successes / total
  denominator <- 1 + z^2 / total
  center <- (p + z^2 / (2 * total)) / denominator
  half <- z * sqrt(p * (1 - p) / total + z^2 / (4 * total^2)) / denominator
  c(lower = center - half, upper = center + half)
}

g5_l1_directional_scorecard <- function(
  panel,
  cost_bps,
  contract = g5_l1_contract()
) {
  contract <- g5_l1_validate_contract(contract)
  selected <- panel[panel$position != "NONE", , drop = FALSE]
  tp <- sum(selected$predicted_direction == "UP" &
    selected$realized_direction == "UP")
  fp <- sum(selected$predicted_direction == "UP" &
    selected$realized_direction == "DOWN")
  tn <- sum(selected$predicted_direction == "DOWN" &
    selected$realized_direction == "DOWN")
  fn <- sum(selected$predicted_direction == "DOWN" &
    selected$realized_direction == "UP")
  total <- tp + fp + tn + fn
  raw_accuracy <- (tp + tn) / total
  up_recall <- if (tp + fn) tp / (tp + fn) else NA_real_
  down_recall <- if (tn + fp) tn / (tn + fp) else NA_real_
  long_precision <- if (tp + fp) tp / (tp + fp) else NA_real_
  short_precision <- if (tn + fn) tn / (tn + fn) else NA_real_
  interval <- g5_l1_wilson_interval(tp + tn, total)
  friction <- 2 * cost_bps / 10000
  selected$cost_aware_realized <- ifelse(
    selected$future_return > friction, "UP_BEYOND_FRICTION",
    ifelse(selected$future_return < -friction, "DOWN_BEYOND_FRICTION", "NEUTRAL")
  )
  scorecard <- data.frame(
    schema_version = g5_l1_schema_version(),
    evaluation_period = unique(panel$evaluation_period)[[1L]],
    selected_leg_count = total,
    available_asset_outcomes = nrow(panel),
    coverage = total / nrow(panel),
    raw_direction_accuracy = raw_accuracy,
    raw_accuracy_ci_lower = interval[["lower"]],
    raw_accuracy_ci_upper = interval[["upper"]],
    long_call_precision = long_precision,
    short_call_precision = short_precision,
    up_recall = up_recall,
    down_recall = down_recall,
    balanced_accuracy = mean(c(up_recall, down_recall)),
    neutral_after_cost_count = sum(selected$cost_aware_realized == "NEUTRAL"),
    friction_return_threshold = friction,
    stringsAsFactors = FALSE
  )
  confusion <- data.frame(
    predicted_direction = c("UP", "UP", "DOWN", "DOWN"),
    realized_direction = c("UP", "DOWN", "UP", "DOWN"),
    count = c(tp, fp, fn, tn),
    stringsAsFactors = FALSE
  )
  list(scorecard = scorecard, confusion = confusion, detail = selected)
}

g5_l1_year_summary <- function(cohorts) {
  do.call(rbind, lapply(split(cohorts, cohorts$calendar_year), function(part) {
    data.frame(
      schema_version = g5_l1_schema_version(),
      evaluation_period = part$evaluation_period[[1L]],
      calendar_year = part$calendar_year[[1L]],
      cohort_count = nrow(part),
      mean_rank_ic = mean(part$rank_ic),
      mean_gross_spread = mean(part$gross_long_minus_short_spread),
      mean_net_return = mean(part$net_portfolio_return),
      spread_hit_rate = mean(part$spread_direction_correct),
      stringsAsFactors = FALSE
    )
  }))
}

g5_l1_session_coverage_audit <- function(
  bars,
  contract = g5_l1_contract()
) {
  contract <- g5_l1_validate_contract(contract)
  bars <- g5_l1_validate_bars(bars, contract)
  reference <- g5_l1_reference_sessions(bars, contract)
  rows <- lapply(g5_l1_required_symbols(contract), function(symbol) {
    observed <- sort(unique(bars$session_date[
      bars$symbol == symbol &
        bars$session_date >= contract$query_start &
        bars$session_date <= contract$query_end
    ]))
    missing <- setdiff(reference, observed)
    data.frame(
      schema_version = g5_l1_schema_version(),
      symbol = symbol,
      reference_first_session = reference[[1L]],
      reference_last_session = tail(reference, 1L),
      reference_session_count = length(reference),
      observed_first_session = if (length(observed)) observed[[1L]] else as.Date(NA),
      observed_last_session = if (length(observed)) tail(observed, 1L) else as.Date(NA),
      observed_session_count = length(observed),
      missing_reference_sessions = length(missing),
      status = if (!length(missing) &&
          length(observed) &&
          observed[[1L]] == reference[[1L]] &&
          tail(observed, 1L) == tail(reference, 1L)) "PASS" else "FAIL",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_l1_integrity_audit <- function(
  bars,
  panel,
  contract = g5_l1_contract(),
  data_health_status = "PASS"
) {
  contract <- g5_l1_validate_contract(contract)
  coverage <- g5_l1_session_coverage_audit(bars, contract)
  selected <- panel[panel$position != "NONE", , drop = FALSE]
  schedules <- unique(panel[, c(
    "evaluation_period", "cohort_id", "decision_date",
    "execution_date", "exit_date"
  )])
  schedules <- schedules[order(schedules$execution_date), , drop = FALSE]
  nonoverlap <- all(vapply(
    split(schedules, schedules$evaluation_period),
    function(part) {
      nrow(part) < 2L ||
        all(part$execution_date[-1L] >= part$exit_date[-nrow(part)])
    },
    logical(1L)
  ))
  period_ok <- all(vapply(seq_len(nrow(schedules)), function(i) {
    row <- schedules[i, , drop = FALSE]
    period <- contract$periods[
      contract$periods$evaluation_period == row$evaluation_period,
      ,
      drop = FALSE
    ]
    row$execution_date >= period$start_date &&
      row$exit_date <= period$end_date
  }, logical(1L)))
  data.frame(
    check_id = c(
      "canonical_adjusted_daily_bars",
      "all_frozen_symbols_present",
      "common_reference_session_coverage",
      "unique_symbol_session_rows",
      "explicit_as_of_boundary",
      "signal_uses_completed_history",
      "strict_next_open_execution",
      "five_session_holding_period",
      "nonoverlapping_return_intervals",
      "partition_boundaries",
      "frozen_long_short_weights",
      "workbench_data_health"
    ),
    status = c(
      if ("adjustment" %in% names(bars)) {
        if (all(bars$adjustment == "all")) "PASS" else "FAIL"
      } else if ("adjusted" %in% names(bars)) {
        if (all(bars$adjusted)) "PASS" else "FAIL"
      } else "PASS",
      if (all(g5_l1_required_symbols(contract) %in% unique(bars$symbol))) "PASS" else "FAIL",
      if (all(coverage$status == "PASS")) "PASS" else "FAIL",
      if (!anyDuplicated(paste(bars$symbol, bars$session_date))) "PASS" else "FAIL",
      if (max(bars$session_date) <= contract$query_end) "PASS" else "FAIL",
      if (all(panel$signal_window_start_date < panel$decision_date)) "PASS" else "FAIL",
      if (all(panel$decision_date < panel$execution_date)) "PASS" else "FAIL",
      if (all(vapply(split(panel, panel$cohort_id), function(part) {
        length(unique(part$exit_date)) == 1L &&
          length(unique(part$execution_date)) == 1L
      }, logical(1L)))) "PASS" else "FAIL",
      if (nonoverlap) "PASS" else "FAIL",
      if (period_ok) "PASS" else "FAIL",
      if (all(vapply(split(selected, selected$cohort_id), function(part) {
        isTRUE(all.equal(sum(part$weight[part$weight > 0]), contract$long_gross)) &&
          isTRUE(all.equal(abs(sum(part$weight[part$weight < 0])), contract$short_gross)) &&
          abs(sum(part$weight)) < 1e-12 &&
          isTRUE(all.equal(sum(abs(part$weight)), 1))
      }, logical(1L)))) "PASS" else "FAIL",
      if (identical(as.character(data_health_status), "PASS")) "PASS" else "FAIL"
    ),
    detail = c(
      "Adjusted daily OHLCV only.",
      "Nine sector ETFs plus SPY context are required.",
      "Every symbol contains every XLB reference session.",
      "No duplicate symbol/session rows.",
      paste("Bars bounded by", contract$query_end, "under", contract$as_of_timestamp),
      "Trailing return ends at the completed decision close.",
      "Execution is strictly later than the decision close.",
      "Each cohort exits five reference sessions after entry.",
      "Successive cohort return intervals do not overlap.",
      "Entry and exit remain inside one frozen partition.",
      "Each cohort is +50% long, -50% short, 100% gross, 0% net.",
      paste("Analysis-level workbench health:", data_health_status)
    ),
    stringsAsFactors = FALSE
  )
}

g5_l1_train_gates <- function(
  cohorts,
  bootstrap,
  random_control,
  years,
  integrity,
  contract = g5_l1_contract()
) {
  ic <- bootstrap$summary[bootstrap$summary$metric == "rank_ic", , drop = FALSE]
  net <- bootstrap$summary[
    bootstrap$summary$metric == "net_portfolio_return",
    ,
    drop = FALSE
  ]
  observed <- mean(cohorts$net_portfolio_return)
  positive_years <- sum(years$mean_net_return > 0)
  pass <- c(
    all(integrity$status == "PASS"),
    mean(cohorts$rank_ic) < 0 && ic$ci_upper[[1L]] < 0,
    observed > 0 && net$ci_lower[[1L]] > 0,
    mean(cohorts$spread_direction_correct) > 0.50,
    observed > random_control$p90,
    positive_years >= contract$train_positive_years
  )
  data.frame(
    gate_id = paste0("L1A_G", seq_len(6L)),
    gate = c(
      "Integrity, timing, partitions, and weights",
      "TRAIN negative rank IC with upper 95% bound below zero",
      "TRAIN positive net return with lower 95% bound above zero",
      "TRAIN spread-direction hit rate above 50%",
      "TRAIN observed net return beats random-policy p90",
      "TRAIN positive in at least three of five calendar years"
    ),
    status = ifelse(pass, "PASS", "FAIL"),
    value = c(
      paste(sum(integrity$status == "PASS"), "/", nrow(integrity)),
      sprintf("%.6f; upper %.6f", mean(cohorts$rank_ic), ic$ci_upper[[1L]]),
      sprintf("%.6f; lower %.6f", observed, net$ci_lower[[1L]]),
      sprintf("%.3f", mean(cohorts$spread_direction_correct)),
      sprintf("%.6f vs p90 %.6f", observed, random_control$p90),
      paste(positive_years, "/", nrow(years))
    ),
    stringsAsFactors = FALSE
  )
}

g5_l1_daily_replay <- function(
  panel,
  bars,
  cost_bps,
  borrow_bps_annual,
  contract = g5_l1_contract()
) {
  contract <- g5_l1_validate_contract(contract)
  bars <- g5_l1_validate_bars(bars, contract)
  sessions <- g5_l1_reference_sessions(bars, contract)
  open_index <- g5_l1_value_index(bars, "open")
  pieces <- split(panel, panel$cohort_id)
  rows <- list()
  for (part in pieces) {
    execution_i <- match(part$execution_date[[1L]], sessions)
    exit_i <- match(part$exit_date[[1L]], sessions)
    if (!is.finite(execution_i) || !is.finite(exit_i) ||
        exit_i - execution_i != contract$holding_sessions) {
      g5_l1_stop(paste("L1 replay interval is invalid:", part$cohort_id[[1L]]))
    }
    for (day_i in seq_len(contract$holding_sessions)) {
      start_date <- sessions[execution_i + day_i - 1L]
      end_date <- sessions[execution_i + day_i]
      asset_returns <- vapply(seq_len(nrow(part)), function(i) {
        g5_l1_lookup(open_index, part$symbol[[i]], end_date) /
          g5_l1_lookup(open_index, part$symbol[[i]], start_date) - 1
      }, numeric(1L))
      gross_return <- sum(part$weight * asset_returns)
      entry_cost <- if (day_i == 1L) cost_bps / 10000 else 0
      exit_cost <- if (day_i == contract$holding_sessions) cost_bps / 10000 else 0
      daily_borrow <- borrow_bps_annual / 10000 * contract$short_gross / 252
      rows[[length(rows) + 1L]] <- data.frame(
        schema_version = g5_l1_schema_version(),
        evaluation_period = part$evaluation_period[[1L]],
        cohort_id = part$cohort_id[[1L]],
        holding_day = day_i,
        period_start_date = start_date,
        period_end_date = end_date,
        gross_return = gross_return,
        transaction_cost = entry_cost + exit_cost,
        borrow_cost = daily_borrow,
        net_return = gross_return - entry_cost - exit_cost - daily_borrow,
        gross_exposure = sum(abs(part$weight)),
        net_exposure = sum(part$weight),
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  out <- out[order(out$period_end_date), , drop = FALSE]
  out$wealth <- ave(1 + out$net_return, out$evaluation_period, FUN = cumprod)
  out$drawdown <- ave(out$wealth, out$evaluation_period, FUN = function(x) {
    x / cummax(c(1, x))[-1L] - 1
  })
  out
}

g5_l1_long_run_variance <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 3L) return(NA_real_)
  centered <- x - mean(x)
  lag_count <- max(1L, floor(4 * (n / 100)^(2 / 9)))
  gamma0 <- sum(centered^2) / n
  value <- gamma0
  for (lag in seq_len(min(lag_count, n - 1L))) {
    gamma <- sum(centered[(lag + 1L):n] * centered[1L:(n - lag)]) / n
    weight <- 1 - lag / (lag_count + 1)
    value <- value + 2 * weight * gamma
  }
  value
}

g5_l1_max_drawdown_duration <- function(drawdown) {
  underwater <- drawdown < 0
  runs <- rle(underwater)
  if (!any(runs$values)) 0L else max(runs$lengths[runs$values])
}

g5_l1_performance_metrics <- function(
  daily,
  cohorts,
  evaluation_period
) {
  d <- daily[daily$evaluation_period == evaluation_period, , drop = FALSE]
  c <- cohorts[cohorts$evaluation_period == evaluation_period, , drop = FALSE]
  if (!nrow(d) || !nrow(c)) g5_l1_stop("L1 performance metrics have no requested rows.")
  cumulative <- prod(1 + d$net_return) - 1
  years <- nrow(d) / 252
  cagr <- (1 + cumulative)^(1 / years) - 1
  annual_vol <- stats::sd(d$net_return) * sqrt(252)
  naive_sharpe <- if (annual_vol > 0) mean(d$net_return) / stats::sd(d$net_return) * sqrt(252) else NA_real_
  long_run_variance <- g5_l1_long_run_variance(d$net_return)
  adjusted_sharpe <- if (is.finite(long_run_variance) && long_run_variance > 0) {
    mean(d$net_return) / sqrt(long_run_variance) * sqrt(252)
  } else {
    NA_real_
  }
  wins <- c$net_portfolio_return[c$net_portfolio_return > 0]
  losses <- c$net_portfolio_return[c$net_portfolio_return <= 0]
  average_win <- if (length(wins)) mean(wins) else NA_real_
  average_loss <- if (length(losses)) mean(losses) else NA_real_
  profit_factor <- if (length(losses) && sum(losses) < 0) {
    sum(wins) / abs(sum(losses))
  } else {
    NA_real_
  }
  data.frame(
    schema_version = g5_l1_schema_version(),
    evaluation_period = evaluation_period,
    daily_bar_count = nrow(d),
    cohort_count = nrow(c),
    cumulative_net_return = cumulative,
    total_pnl_per_initial_dollar = cumulative,
    cagr = cagr,
    annualized_volatility = annual_vol,
    naive_annualized_sharpe = naive_sharpe,
    autocorrelation_adjusted_sharpe = adjusted_sharpe,
    maximum_drawdown = min(d$drawdown),
    maximum_drawdown_duration_sessions = g5_l1_max_drawdown_duration(d$drawdown),
    time_under_water_fraction = mean(d$drawdown < 0),
    cohort_win_rate = mean(c$net_portfolio_return > 0),
    mean_cohort_return = mean(c$net_portfolio_return),
    median_cohort_return = stats::median(c$net_portfolio_return),
    average_win = average_win,
    average_loss = average_loss,
    payoff_ratio = if (is.finite(average_win) && is.finite(average_loss) &&
        average_loss < 0) average_win / abs(average_loss) else NA_real_,
    profit_factor = profit_factor,
    expectancy = mean(c$net_portfolio_return),
    best_cohort = max(c$net_portfolio_return),
    worst_cohort = min(c$net_portfolio_return),
    stringsAsFactors = FALSE
  )
}

g5_l1_contribution_attribution <- function(
  panel,
  evaluation_period = "CONFIRMATION"
) {
  selected <- panel[
    panel$evaluation_period == evaluation_period &
      panel$position != "NONE",
    ,
    drop = FALSE
  ]
  rows <- lapply(split(selected, selected$symbol), function(part) {
    data.frame(
      schema_version = g5_l1_schema_version(),
      symbol = part$symbol[[1L]],
      selected_leg_count = nrow(part),
      long_leg_count = sum(part$position == "LONG"),
      short_leg_count = sum(part$position == "SHORT"),
      arithmetic_contribution = sum(part$arithmetic_contribution),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  positive_total <- sum(pmax(out$arithmetic_contribution, 0))
  out$positive_contribution_share <- if (positive_total > 0) {
    pmax(out$arithmetic_contribution, 0) / positive_total
  } else {
    NA_real_
  }
  out[order(-out$arithmetic_contribution), , drop = FALSE]
}

g5_l1_l1b_gates <- function(
  cohorts,
  stress_cohorts,
  confirmation_random,
  years,
  metrics,
  attribution,
  contract = g5_l1_contract()
) {
  development <- cohorts[cohorts$evaluation_period == "DEVELOPMENT", , drop = FALSE]
  confirmation <- cohorts[cohorts$evaluation_period == "CONFIRMATION", , drop = FALSE]
  confirmation_stress <- stress_cohorts[
    stress_cohorts$evaluation_period == "CONFIRMATION",
    ,
    drop = FALSE
  ]
  confirmation_years <- years[years$evaluation_period == "CONFIRMATION", , drop = FALSE]
  positive_years <- sum(confirmation_years$mean_net_return > 0)
  observed_confirmation <- mean(confirmation$net_portfolio_return)
  max_share <- suppressWarnings(max(
    attribution$positive_contribution_share,
    na.rm = TRUE
  ))
  if (!is.finite(max_share)) max_share <- Inf
  pass <- c(
    mean(development$rank_ic) < 0 &&
      mean(development$net_portfolio_return) > 0,
    mean(confirmation$rank_ic) < 0 &&
      observed_confirmation > 0,
    observed_confirmation > confirmation_random$p90,
    positive_years >= contract$confirmation_positive_years,
    mean(confirmation_stress$net_portfolio_return) > 0,
    metrics$cumulative_net_return[[1L]] > 0 &&
      metrics$autocorrelation_adjusted_sharpe[[1L]] > 0 &&
      max_share <= contract$positive_contribution_cap
  )
  data.frame(
    gate_id = paste0("L1B_G", 7:12),
    gate = c(
      "DEVELOPMENT negative IC and positive net replication",
      "CONFIRMATION negative IC and positive net replication",
      "CONFIRMATION observed net return beats random-policy p90",
      "At least two CONFIRMATION calendar years are positive",
      "CONFIRMATION remains positive under stress costs",
      "Positive portfolio economics and contribution breadth"
    ),
    status = ifelse(pass, "PASS", "FAIL"),
    value = c(
      sprintf("%.6f IC; %.6f net",
        mean(development$rank_ic), mean(development$net_portfolio_return)),
      sprintf("%.6f IC; %.6f net",
        mean(confirmation$rank_ic), observed_confirmation),
      sprintf("%.6f vs p90 %.6f", observed_confirmation, confirmation_random$p90),
      paste(positive_years, "/", nrow(confirmation_years)),
      sprintf("%.6f", mean(confirmation_stress$net_portfolio_return)),
      sprintf(
        "return %.6f; HAC Sharpe %.3f; max share %.3f",
        metrics$cumulative_net_return[[1L]],
        metrics$autocorrelation_adjusted_sharpe[[1L]],
        max_share
      )
    ),
    stringsAsFactors = FALSE
  )
}

g5_l1_not_run_gates <- function() {
  data.frame(
    gate_id = paste0("L1B_G", 7:12),
    gate = c(
      "DEVELOPMENT negative IC and positive net replication",
      "CONFIRMATION negative IC and positive net replication",
      "CONFIRMATION observed net return beats random-policy p90",
      "At least two CONFIRMATION calendar years are positive",
      "CONFIRMATION remains positive under stress costs",
      "Positive portfolio economics and contribution breadth"
    ),
    status = "NOT_RUN",
    value = "L1A TRAIN mechanism gate failure",
    stringsAsFactors = FALSE
  )
}

g5_l1_run_analysis <- function(
  bars,
  contract = g5_l1_contract(),
  data_health_status = "PASS"
) {
  contract <- g5_l1_validate_contract(contract)
  bars <- g5_l1_validate_bars(bars, contract)
  train_panel <- g5_l1_build_panel(bars, contract, "TRAIN")
  train_cohorts <- g5_l1_cohort_summary(
    train_panel,
    contract$primary_cost_bps,
    contract$primary_borrow_bps_annual,
    contract
  )
  train_bootstrap <- g5_l1_block_bootstrap(train_cohorts, contract)
  train_random <- g5_l1_random_control(
    train_panel,
    contract$primary_cost_bps,
    contract$primary_borrow_bps_annual,
    contract
  )
  train_years <- g5_l1_year_summary(train_cohorts)
  train_direction <- g5_l1_directional_scorecard(
    train_panel, contract$primary_cost_bps, contract
  )
  integrity <- g5_l1_integrity_audit(
    bars, train_panel, contract, data_health_status
  )
  l1a_gates <- g5_l1_train_gates(
    train_cohorts, train_bootstrap, train_random, train_years,
    integrity, contract
  )
  l1a_pass <- all(l1a_gates$status == "PASS")
  base <- list(
    contract = contract,
    train_panel = train_panel,
    train_cohorts = train_cohorts,
    train_bootstrap = train_bootstrap,
    train_random = train_random,
    train_years = train_years,
    train_direction = train_direction,
    integrity = integrity,
    session_coverage = g5_l1_session_coverage_audit(bars, contract),
    l1a_pass = l1a_pass
  )
  if (!l1a_pass) {
    return(c(base, list(
      full_panel = NULL,
      primary_cohorts = NULL,
      stress_cohorts = NULL,
      direction_by_period = NULL,
      year_summary = NULL,
      confirmation_random = NULL,
      primary_daily_replay = NULL,
      stress_daily_replay = NULL,
      confirmation_metrics = NULL,
      attribution = NULL,
      gates = rbind(l1a_gates, g5_l1_not_run_gates()),
      l1b_run = FALSE,
      overall_status = "STOP_L1A_SECTOR_REVERSAL_MECHANISM"
    )))
  }
  full_panel <- g5_l1_build_panel(
    bars, contract, c("TRAIN", "DEVELOPMENT", "CONFIRMATION")
  )
  primary_cohorts <- g5_l1_cohort_summary(
    full_panel,
    contract$primary_cost_bps,
    contract$primary_borrow_bps_annual,
    contract
  )
  stress_cohorts <- g5_l1_cohort_summary(
    full_panel,
    contract$stress_cost_bps,
    contract$stress_borrow_bps_annual,
    contract
  )
  directions <- lapply(
    split(full_panel, full_panel$evaluation_period),
    g5_l1_directional_scorecard,
    cost_bps = contract$primary_cost_bps,
    contract = contract
  )
  direction_by_period <- do.call(rbind, lapply(directions, `[[`, "scorecard"))
  direction_confusion <- do.call(rbind, lapply(names(directions), function(period) {
    cbind(
      evaluation_period = period,
      directions[[period]]$confusion,
      stringsAsFactors = FALSE
    )
  }))
  years <- g5_l1_year_summary(primary_cohorts)
  confirmation_random <- g5_l1_random_control(
    full_panel[full_panel$evaluation_period == "CONFIRMATION", , drop = FALSE],
    contract$primary_cost_bps,
    contract$primary_borrow_bps_annual,
    contract,
    seed_offset = 1L
  )
  primary_daily <- g5_l1_daily_replay(
    full_panel, bars, contract$primary_cost_bps,
    contract$primary_borrow_bps_annual, contract
  )
  stress_daily <- g5_l1_daily_replay(
    full_panel, bars, contract$stress_cost_bps,
    contract$stress_borrow_bps_annual, contract
  )
  confirmation_metrics <- g5_l1_performance_metrics(
    primary_daily, primary_cohorts, "CONFIRMATION"
  )
  attribution <- g5_l1_contribution_attribution(full_panel, "CONFIRMATION")
  l1b_gates <- g5_l1_l1b_gates(
    primary_cohorts, stress_cohorts, confirmation_random, years,
    confirmation_metrics, attribution, contract
  )
  all_gates <- rbind(l1a_gates, l1b_gates)
  c(base, list(
    full_panel = full_panel,
    primary_cohorts = primary_cohorts,
    stress_cohorts = stress_cohorts,
    direction_by_period = direction_by_period,
    direction_confusion = direction_confusion,
    year_summary = years,
    confirmation_random = confirmation_random,
    primary_daily_replay = primary_daily,
    stress_daily_replay = stress_daily,
    confirmation_metrics = confirmation_metrics,
    attribution = attribution,
    gates = all_gates,
    l1b_run = TRUE,
    overall_status = if (all(l1b_gates$status == "PASS")) {
      "PASS_L1_TO_PROSPECTIVE_BORROW_SHADOW_DISCUSSION"
    } else {
      "STOP_L1B_SECTOR_REVERSAL_REPLICATION"
    }
  ))
}
