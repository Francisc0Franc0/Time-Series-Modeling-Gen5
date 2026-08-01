# Frozen LIT-MOM-02.1 opening-gap momentum textbook exercise and atlas.

g5_mom02_schema_version <- function() "gen5_lit_mom_02_1_v1"

g5_mom02_stop <- function(message) {
  stop(paste0("[LIT-MOM-02.1] ", message), call. = FALSE)
}

g5_mom02_validate_registry <- function(registry) {
  required <- c(
    "order", "instance_id", "symbol", "category", "instrument_type",
    "poc_anchor", "rationale"
  )
  if (!is.data.frame(registry) || !all(required %in% names(registry))) {
    g5_mom02_stop(paste(
      "Registry requires:", paste(required, collapse = ", ")
    ))
  }
  registry <- registry[, required, drop = FALSE]
  registry$order <- as.integer(registry$order)
  registry$symbol <- toupper(trimws(as.character(registry$symbol)))
  registry$poc_anchor <- as.logical(registry$poc_anchor)
  checks <- c(
    nrow(registry) == 92L,
    identical(registry$order, seq_len(92L)),
    !anyDuplicated(registry$instance_id),
    !anyDuplicated(registry$symbol),
    all(grepl("^[A-Z][A-Z0-9.]{0,9}$", registry$symbol)),
    sum(registry$poc_anchor) == 8L,
    identical(
      registry$symbol[registry$poc_anchor],
      c("FEZ", "SPY", "QQQ", "IWM", "TLT", "GLD", "USO", "UUP")
    ),
    length(unique(registry$category)) == 9L,
    all(registry$instrument_type %in% c("ETF", "Stock")),
    all(nzchar(trimws(registry$rationale)))
  )
  if (!all(checks)) {
    g5_mom02_stop(paste(
      "Frozen registry failed checks:",
      paste(which(!checks), collapse = ", ")
    ))
  }
  registry
}

g5_mom02_contract <- function(registry) {
  registry <- g5_mom02_validate_registry(registry)
  list(
    schema_version = g5_mom02_schema_version(),
    literature_id = "LIT-MOM-02.1",
    atlas_id = "OPENING_GAP_ATLAS_01",
    as_of_timestamp = "2026-08-01 17:30:00 America/New_York",
    query_start = as.Date("2016-08-01"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    volatility_sessions = 90L,
    entry_sigma_multiple = 0.1,
    signal_time_et = "09:31:00",
    entry_time_et = "09:32:00",
    primary_round_trip_cost_bps = 10,
    stress_round_trip_cost_bps = 20,
    minimum_daily_coverage = 0.90,
    minimum_entry_coverage = 0.95,
    minimum_events = 24L,
    minimum_direction_events = 8L,
    minimum_event_years = 3L,
    minimum_positive_years = 3L,
    bootstrap_count = 2000L,
    bootstrap_block_events = 5L,
    bootstrap_seed = 72101L,
    sign_control_count = 1000L,
    sign_control_seed = 72102L,
    registry = registry
  )
}

g5_mom02_validate_contract <- function(contract) {
  frozen <- g5_mom02_contract(contract$registry)
  fields <- setdiff(names(frozen), "registry")
  for (field in fields) {
    if (!identical(contract[[field]], frozen[[field]])) {
      g5_mom02_stop(paste("Frozen contract changed:", field))
    }
  }
  if (!identical(contract$registry, frozen$registry)) {
    g5_mom02_stop("Frozen registry changed.")
  }
  invisible(contract)
}

g5_mom02_validate_analysis_registry <- function(
  registry, contract, require_full = FALSE
) {
  required <- names(contract$registry)
  if (!is.data.frame(registry) || !all(required %in% names(registry))) {
    g5_mom02_stop("Analysis registry does not match the frozen schema.")
  }
  registry <- registry[, required, drop = FALSE]
  if (require_full) {
    if (!identical(registry, contract$registry)) {
      g5_mom02_stop("TRAIN requires the complete frozen atlas registry.")
    }
    return(registry)
  }
  idx <- match(registry$instance_id, contract$registry$instance_id)
  if (anyNA(idx) || !identical(
    registry, contract$registry[idx, , drop = FALSE]
  )) {
    g5_mom02_stop("Analysis registry is not an exact frozen subset.")
  }
  registry
}

g5_mom02_validate_daily <- function(bars, contract, query_end) {
  required <- c("symbol", "session_date", "open", "high", "low", "close")
  if (!is.data.frame(bars) || !all(required %in% names(bars))) {
    g5_mom02_stop(paste(
      "Daily bars require:", paste(required, collapse = ", ")
    ))
  }
  bars$symbol <- toupper(trimws(as.character(bars$symbol)))
  bars$session_date <- as.Date(bars$session_date)
  for (field in c("open", "high", "low", "close")) {
    bars[[field]] <- as.numeric(bars[[field]])
  }
  prices <- as.matrix(bars[c("open", "high", "low", "close")])
  if (any(!is.finite(prices)) || any(prices <= 0)) {
    g5_mom02_stop("Daily OHLC contains non-positive or non-finite values.")
  }
  if (any(is.na(bars$session_date)) || anyDuplicated(
    bars[c("symbol", "session_date")]
  )) {
    g5_mom02_stop("Daily dates are invalid or duplicated.")
  }
  if (max(bars$session_date) > as.Date(query_end)) {
    g5_mom02_stop("Daily bars exceed the explicit query boundary.")
  }
  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

g5_mom02_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n <= 0L) return(x)
  c(rep(NA, n), head(x, -n))
}

g5_mom02_rolling_sd_lagged_returns <- function(close, n) {
  returns <- close / g5_mom02_lag(close) - 1
  output <- rep(NA_real_, length(close))
  if (length(close) <= n + 1L) return(output)
  for (i in seq.int(n + 2L, length(close))) {
    values <- returns[(i - n):(i - 1L)]
    output[[i]] <- stats::sd(values)
  }
  output
}

g5_mom02_symbol_features <- function(rows, contract) {
  rows <- rows[order(rows$session_date), , drop = FALSE]
  rows$prior_high <- g5_mom02_lag(rows$high)
  rows$prior_low <- g5_mom02_lag(rows$low)
  rows$sigma90_lagged <- g5_mom02_rolling_sd_lagged_returns(
    rows$close, contract$volatility_sessions
  )
  rows$upper_threshold <- rows$prior_high * (
    1 + contract$entry_sigma_multiple * rows$sigma90_lagged
  )
  rows$lower_threshold <- rows$prior_low * (
    1 - contract$entry_sigma_multiple * rows$sigma90_lagged
  )
  rows$long_signal <- is.finite(rows$upper_threshold) &
    rows$open > rows$upper_threshold
  rows$short_signal <- is.finite(rows$lower_threshold) &
    rows$open < rows$lower_threshold
  rows$position <- as.integer(rows$long_signal) - as.integer(rows$short_signal)
  rows$signal_direction <- ifelse(
    rows$position > 0, "LONG_GAP_UP",
    ifelse(rows$position < 0, "SHORT_GAP_DOWN", "NO_SIGNAL")
  )
  rows$gap_beyond_extreme <- ifelse(
    rows$position > 0,
    rows$open / rows$prior_high - 1,
    ifelse(rows$position < 0, rows$open / rows$prior_low - 1, NA_real_)
  )
  rows$source_narrative_return <- rows$position * (rows$close / rows$open - 1)
  rows$literal_printed_code_return <- rows$position *
    (rows$open - rows$close) / rows$open
  rows
}

g5_mom02_feature_panel <- function(bars, contract) {
  split_rows <- split(bars, bars$symbol)
  output <- do.call(rbind, lapply(
    split_rows, g5_mom02_symbol_features, contract = contract
  ))
  rownames(output) <- NULL
  output
}

g5_mom02_signal_events <- function(features, registry, start_date, end_date) {
  x <- features[
    features$symbol %in% registry$symbol &
      features$session_date >= as.Date(start_date) &
      features$session_date <= as.Date(end_date) &
      features$position != 0L,
    , drop = FALSE
  ]
  output <- merge(
    x, registry,
    by = "symbol", all.x = TRUE, sort = FALSE
  )
  output[order(output$session_date, output$symbol), , drop = FALSE]
}

g5_mom02_entry_manifest <- function(events) {
  unique(events[c("symbol", "session_date")])
}

g5_mom02_validate_entries <- function(entries, contract, query_end) {
  required <- c("symbol", "session_date", "entry_timestamp_et", "entry_open")
  if (!is.data.frame(entries) || !all(required %in% names(entries))) {
    g5_mom02_stop(paste(
      "Entry bars require:", paste(required, collapse = ", ")
    ))
  }
  entries$symbol <- toupper(trimws(as.character(entries$symbol)))
  entries$session_date <- as.Date(entries$session_date)
  entries$entry_timestamp_et <- as.character(entries$entry_timestamp_et)
  entries$entry_open <- as.numeric(entries$entry_open)
  if (anyDuplicated(entries[c("symbol", "session_date")])) {
    g5_mom02_stop("Duplicate 09:32 entry bars.")
  }
  if (any(entries$session_date > as.Date(query_end))) {
    g5_mom02_stop("Entry bars exceed the explicit query boundary.")
  }
  if (nrow(entries) && any(
    !is.finite(entries$entry_open) | entries$entry_open <= 0
  )) {
    g5_mom02_stop("Entry bars contain invalid prices.")
  }
  suffix <- paste0(" ", contract$entry_time_et)
  if (nrow(entries) && any(!endsWith(entries$entry_timestamp_et, suffix))) {
    g5_mom02_stop("Entries are not the frozen 09:32 ET bar open.")
  }
  entries
}

g5_mom02_join_entries <- function(events, entries, contract) {
  x <- merge(
    events,
    entries[c("symbol", "session_date", "entry_timestamp_et", "entry_open")],
    by = c("symbol", "session_date"), all.x = TRUE, sort = FALSE
  )
  x$entry_available <- is.finite(x$entry_open)
  x$underlying_entry_to_close_return <- x$close / x$entry_open - 1
  x$gross_return <- x$position * x$underlying_entry_to_close_return
  x$primary_net_return <- x$gross_return -
    contract$primary_round_trip_cost_bps / 10000
  x$stress_net_return <- x$gross_return -
    contract$stress_round_trip_cost_bps / 10000
  x$direction_correct <- x$gross_return > 0
  x[order(x$session_date, x$symbol), , drop = FALSE]
}

g5_mom02_block_indices <- function(n, block_length) {
  if (n <= 0L) return(integer())
  block_length <- min(as.integer(block_length), n)
  starts <- sample.int(n, ceiling(n / block_length), replace = TRUE)
  unlist(lapply(starts, function(start) {
    ((start - 1L + seq_len(block_length) - 1L) %% n) + 1L
  }), use.names = FALSE)[seq_len(n)]
}

g5_mom02_bootstrap <- function(event_returns, contract, instance_order) {
  x <- event_returns[is.finite(event_returns)]
  set.seed(contract$bootstrap_seed + as.integer(instance_order))
  draws <- rep(NA_real_, contract$bootstrap_count)
  if (length(x)) {
    for (i in seq_along(draws)) {
      idx <- g5_mom02_block_indices(
        length(x), contract$bootstrap_block_events
      )
      draws[[i]] <- mean(x[idx])
    }
  }
  finite <- draws[is.finite(draws)]
  interval <- if (length(finite)) {
    stats::quantile(finite, c(0.10, 0.90), names = FALSE)
  } else c(NA_real_, NA_real_)
  list(
    estimate = if (length(x)) mean(x) else NA_real_,
    lower_90_one_sided = interval[[1L]],
    upper_90_one_sided = interval[[2L]],
    draws = draws
  )
}

g5_mom02_sign_control <- function(events, contract, instance_order) {
  moves <- events$underlying_entry_to_close_return
  moves <- moves[is.finite(moves)]
  set.seed(contract$sign_control_seed + as.integer(instance_order))
  draws <- rep(NA_real_, contract$sign_control_count)
  if (length(moves)) {
    for (i in seq_along(draws)) {
      random_sign <- sample(c(-1, 1), length(moves), replace = TRUE)
      draws[[i]] <- mean(
        random_sign * moves - contract$primary_round_trip_cost_bps / 10000
      )
    }
  }
  list(
    p90 = if (any(is.finite(draws))) {
      as.numeric(stats::quantile(draws, 0.90, names = FALSE, na.rm = TRUE))
    } else NA_real_,
    draws = draws
  )
}

g5_mom02_long_run_variance <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 2L) return(NA_real_)
  centered <- x - mean(x)
  lag_max <- max(1L, floor(4 * (n / 100)^(2 / 9)))
  value <- sum(centered^2) / n
  for (lag in seq_len(min(lag_max, n - 1L))) {
    weight <- 1 - lag / (lag_max + 1)
    covariance <- sum(
      centered[(lag + 1L):n] * centered[seq_len(n - lag)]
    ) / n
    value <- value + 2 * weight * covariance
  }
  value
}

g5_mom02_daily_path <- function(events, calendar) {
  values <- data.frame(
    session_date = as.Date(calendar),
    primary_net_return = 0,
    stress_net_return = 0,
    source_narrative_return = 0,
    literal_printed_code_return = 0,
    event = FALSE,
    stringsAsFactors = FALSE
  )
  valid <- events[events$entry_available, , drop = FALSE]
  if (nrow(valid)) {
    idx <- match(valid$session_date, values$session_date)
    keep <- is.finite(idx)
    idx <- idx[keep]
    valid <- valid[keep, , drop = FALSE]
    values$primary_net_return[idx] <- valid$primary_net_return
    values$stress_net_return[idx] <- valid$stress_net_return
    values$source_narrative_return[idx] <- valid$source_narrative_return
    values$literal_printed_code_return[idx] <-
      valid$literal_printed_code_return
    values$event[idx] <- TRUE
  }
  values$equity <- cumprod(1 + values$primary_net_return)
  values$drawdown <- values$equity / cummax(c(1, values$equity))[-1L] - 1
  values
}

g5_mom02_performance <- function(events, daily) {
  valid <- events[events$entry_available, , drop = FALSE]
  lrv <- g5_mom02_long_run_variance(daily$primary_net_return)
  primary_equity <- cumprod(1 + daily$primary_net_return)
  stress_equity <- cumprod(1 + daily$stress_net_return)
  source_equity <- cumprod(1 + daily$source_narrative_return)
  literal_equity <- cumprod(1 + daily$literal_printed_code_return)
  data.frame(
    selected_events = nrow(events),
    valid_events = nrow(valid),
    long_events = sum(valid$position == 1L),
    short_events = sum(valid$position == -1L),
    event_years = length(unique(format(valid$session_date, "%Y"))),
    direction_accuracy = if (nrow(valid)) {
      mean(valid$direction_correct)
    } else NA_real_,
    long_accuracy = if (any(valid$position == 1L)) {
      mean(valid$direction_correct[valid$position == 1L])
    } else NA_real_,
    short_accuracy = if (any(valid$position == -1L)) {
      mean(valid$direction_correct[valid$position == -1L])
    } else NA_real_,
    mean_primary_event_return = if (nrow(valid)) {
      mean(valid$primary_net_return)
    } else NA_real_,
    mean_stress_event_return = if (nrow(valid)) {
      mean(valid$stress_net_return)
    } else NA_real_,
    cumulative_return = if (length(primary_equity)) {
      tail(primary_equity, 1L) - 1
    } else NA_real_,
    stress_cumulative_return = if (length(stress_equity)) {
      tail(stress_equity, 1L) - 1
    } else NA_real_,
    source_same_open_cumulative_return = if (length(source_equity)) {
      tail(source_equity, 1L) - 1
    } else NA_real_,
    literal_printed_code_cumulative_return = if (length(literal_equity)) {
      tail(literal_equity, 1L) - 1
    } else NA_real_,
    naive_sharpe = if (
      stats::sd(daily$primary_net_return) > 0
    ) {
      sqrt(252) * mean(daily$primary_net_return) /
        stats::sd(daily$primary_net_return)
    } else NA_real_,
    autocorrelation_adjusted_sharpe = if (is.finite(lrv) && lrv > 0) {
      sqrt(252) * mean(daily$primary_net_return) / sqrt(lrv)
    } else NA_real_,
    maximum_drawdown = if (nrow(daily)) min(daily$drawdown) else NA_real_,
    stringsAsFactors = FALSE
  )
}

g5_mom02_year_table <- function(events) {
  valid <- events[events$entry_available, , drop = FALSE]
  if (!nrow(valid)) {
    return(data.frame(
      year = character(), events = integer(), long_events = integer(),
      short_events = integer(), mean_primary_return = numeric(),
      cumulative_primary_return = numeric()
    ))
  }
  valid$year <- format(valid$session_date, "%Y")
  rows <- lapply(split(valid, valid$year), function(x) {
    data.frame(
      year = unique(x$year),
      events = nrow(x),
      long_events = sum(x$position == 1L),
      short_events = sum(x$position == -1L),
      mean_primary_return = mean(x$primary_net_return),
      cumulative_primary_return = prod(1 + x$primary_net_return) - 1,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_mom02_integrity <- function(
  symbol_rows, events, entries, contract, start_date, end_date, reference_dates
) {
  observed <- unique(symbol_rows$session_date[
    symbol_rows$session_date >= start_date & symbol_rows$session_date <= end_date
  ])
  daily_coverage <- length(intersect(observed, reference_dates)) /
    max(1L, length(reference_dates))
  available <- events$entry_available
  strict_entry <- if (any(available)) {
    all(substr(events$entry_timestamp_et[available], 12L, 19L) >
          contract$signal_time_et)
  } else FALSE
  printed_sign_check <- if (nrow(events)) {
    all(abs(
      events$literal_printed_code_return + events$source_narrative_return
    ) < 1e-12, na.rm = TRUE)
  } else FALSE
  checks <- c(
    daily_coverage >= contract$minimum_daily_coverage,
    !anyDuplicated(symbol_rows[c("symbol", "session_date")]),
    all(events$session_date >= start_date & events$session_date <= end_date),
    all(events$position %in% c(-1L, 1L)),
    all(is.finite(events$prior_high) & is.finite(events$prior_low) &
          is.finite(events$sigma90_lagged)),
    all(events$long_signal != events$short_signal),
    !anyDuplicated(entries[c("symbol", "session_date")]),
    strict_entry,
    printed_sign_check,
    all(events$close > 0, na.rm = TRUE)
  )
  data.frame(
    check_id = sprintf("I%02d", seq_along(checks)),
    check = c(
      "Daily coverage >= 90% of SPY reference sessions",
      "No duplicate daily bars",
      "Events remain inside the explicit partition",
      "Every event has a frozen long or short direction",
      "Every threshold input is finite and lagged",
      "Long and short conditions are mutually exclusive",
      "No duplicate 09:32 entry bars",
      "Available entry is strictly after the 09:31 signal",
      "Printed code return is exactly the negative narrative return",
      "Every closing proxy is positive"
    ),
    diagnostic = c(
      sprintf("%.1f%%", 100 * daily_coverage),
      nrow(symbol_rows), nrow(events),
      paste(table(events$signal_direction), collapse = "; "),
      sum(is.finite(events$sigma90_lagged)),
      sum(events$long_signal & events$short_signal),
      nrow(entries),
      ifelse(strict_entry, contract$entry_time_et, "timing failure"),
      ifelse(printed_sign_check, "exact negative", "sign mismatch"),
      sum(events$close > 0, na.rm = TRUE)
    ),
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

g5_mom02_gates <- function(
  events, performance, years, bootstrap, sign_control, integrity, contract
) {
  entry_coverage <- if (nrow(events)) mean(events$entry_available) else 0
  valid <- events[events$entry_available, , drop = FALSE]
  positive_years <- sum(years$mean_primary_return > 0)
  observed_mean <- performance$mean_primary_event_return
  pass <- c(
    all(integrity$status == "PASS"),
    entry_coverage >= contract$minimum_entry_coverage,
    nrow(valid) >= contract$minimum_events &&
      sum(valid$position == 1L) >= contract$minimum_direction_events &&
      sum(valid$position == -1L) >= contract$minimum_direction_events &&
      performance$event_years >= contract$minimum_event_years,
    is.finite(performance$direction_accuracy) &&
      performance$direction_accuracy > 0.50,
    is.finite(observed_mean) && observed_mean > 0,
    is.finite(bootstrap$lower_90_one_sided) &&
      bootstrap$lower_90_one_sided > 0,
    is.finite(observed_mean) && is.finite(sign_control$p90) &&
      observed_mean > sign_control$p90,
    is.finite(performance$stress_cumulative_return) &&
      performance$stress_cumulative_return > 0 &&
      positive_years >= contract$minimum_positive_years
  )
  data.frame(
    gate_id = seq_len(8L),
    gate = c(
      "Integrity and causal timing",
      "Selected-entry coverage >= 95%",
      "At least 24 events, 8 per direction, across 3 years",
      "Causal direction accuracy > 50%",
      "Positive primary-cost mean event return",
      "Moving-block one-sided 90% lower bound > 0",
      "Observed mean > random-sign p90",
      "Positive stress cumulative return and >= 3 positive years"
    ),
    diagnostic = c(
      paste0(sum(integrity$status == "PASS"), "/", nrow(integrity)),
      sprintf("%.1f%%", 100 * entry_coverage),
      sprintf(
        "%d total; %d long; %d short; %d years",
        nrow(valid), sum(valid$position == 1L),
        sum(valid$position == -1L), performance$event_years
      ),
      sprintf("%.1f%%", 100 * performance$direction_accuracy),
      sprintf("%.2f bp", 10000 * observed_mean),
      sprintf("%.2f bp", 10000 * bootstrap$lower_90_one_sided),
      sprintf(
        "%.2f bp vs %.2f bp",
        10000 * observed_mean, 10000 * sign_control$p90
      ),
      sprintf(
        "stress %.2f%%; %d positive years",
        100 * performance$stress_cumulative_return, positive_years
      )
    ),
    status = ifelse(pass, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

g5_mom02_analyze_symbol <- function(
  features, joined_events, entries, registry_row, reference_dates,
  contract, start_date, end_date
) {
  symbol <- registry_row$symbol[[1L]]
  symbol_rows <- features[features$symbol == symbol, , drop = FALSE]
  events <- joined_events[joined_events$symbol == symbol, , drop = FALSE]
  symbol_entries <- entries[entries$symbol == symbol, , drop = FALSE]
  daily <- g5_mom02_daily_path(events, reference_dates)
  performance <- g5_mom02_performance(events, daily)
  years <- g5_mom02_year_table(events)
  bootstrap <- g5_mom02_bootstrap(
    events$primary_net_return[events$entry_available],
    contract, registry_row$order[[1L]]
  )
  sign_control <- g5_mom02_sign_control(
    events[events$entry_available, , drop = FALSE],
    contract, registry_row$order[[1L]]
  )
  integrity <- g5_mom02_integrity(
    symbol_rows, events, symbol_entries, contract,
    start_date, end_date, reference_dates
  )
  gates <- g5_mom02_gates(
    events, performance, years, bootstrap, sign_control, integrity, contract
  )
  full_pass <- all(gates$status == "PASS")
  list(
    registry = registry_row,
    events = events,
    daily = daily,
    performance = performance,
    years = years,
    bootstrap = bootstrap,
    sign_control = sign_control,
    integrity = integrity,
    gates = gates,
    full_pass = full_pass
  )
}

g5_mom02_run_phase <- function(
  daily_bars, entries, registry, contract, start_date, end_date,
  phase = c("TRAIN", "DEVELOPMENT")
) {
  phase <- match.arg(phase)
  g5_mom02_validate_contract(contract)
  registry <- g5_mom02_validate_analysis_registry(
    registry, contract, require_full = identical(phase, "TRAIN")
  )
  daily_bars <- g5_mom02_validate_daily(daily_bars, contract, end_date)
  entries <- g5_mom02_validate_entries(entries, contract, end_date)
  features <- g5_mom02_feature_panel(daily_bars, contract)
  raw_events <- g5_mom02_signal_events(
    features, registry, start_date, end_date
  )
  events <- g5_mom02_join_entries(raw_events, entries, contract)
  reference_dates <- sort(unique(features$session_date[
    features$symbol == "SPY" & features$session_date >= start_date &
      features$session_date <= end_date
  ]))
  results <- lapply(seq_len(nrow(registry)), function(i) {
    g5_mom02_analyze_symbol(
      features, events, entries, registry[i, , drop = FALSE],
      reference_dates, contract, start_date, end_date
    )
  })
  names(results) <- registry$instance_id
  full_pass <- names(results)[vapply(
    results, function(x) x$full_pass, logical(1)
  )]
  list(
    phase = phase,
    contract = contract,
    registry = registry,
    features = features,
    raw_events = raw_events,
    entry_manifest = g5_mom02_entry_manifest(raw_events),
    events = events,
    results = results,
    full_pass = full_pass,
    status = if (phase == "TRAIN") {
      if (length(full_pass)) {
        "TRAIN_PASS_LIT_MOM_02_1_OPENING_GAP_HAS_NOMINEES"
      } else {
        "STOP_LIT_MOM_02_1_OPENING_GAP_NO_TRAIN_NOMINEE"
      }
    } else {
      "OOS_DEVELOPMENT_COMPLETE_LIT_MOM_02_1_OPENING_GAP"
    }
  )
}

g5_mom02_summary <- function(analysis) {
  do.call(rbind, lapply(analysis$results, function(result) {
    cbind(
      result$registry,
      full_pass = result$full_pass,
      gates_passed = sum(result$gates$status == "PASS"),
      result$performance,
      bootstrap_lower_90 = result$bootstrap$lower_90_one_sided,
      random_sign_p90 = result$sign_control$p90,
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom02_gate_table <- function(analysis) {
  do.call(rbind, lapply(analysis$results, function(result) {
    cbind(
      instance_id = result$registry$instance_id,
      symbol = result$registry$symbol,
      result$gates,
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom02_integrity_table <- function(analysis) {
  do.call(rbind, lapply(analysis$results, function(result) {
    cbind(
      instance_id = result$registry$instance_id,
      symbol = result$registry$symbol,
      result$integrity,
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom02_years_table <- function(analysis) {
  rows <- lapply(analysis$results, function(result) {
    if (!nrow(result$years)) return(NULL)
    cbind(
      instance_id = result$registry$instance_id,
      symbol = result$registry$symbol,
      result$years,
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows)) do.call(rbind, rows) else data.frame()
}
