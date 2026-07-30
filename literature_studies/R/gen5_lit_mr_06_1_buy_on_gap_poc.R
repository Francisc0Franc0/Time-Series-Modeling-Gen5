# Frozen LIT-MR-06.1 causal buy-on-gap textbook exercise.

g5_mr06_schema_version <- function() "gen5_lit_mr_06_1_v1"

g5_mr06_registry <- function() {
  rows <- list(
    c("G01_BROAD_US", "Broad large-cap control", "SPY",
      "AAPL,MSFT,AMZN,GOOGL,META,NVDA,JPM,JNJ,XOM,PG,HD,CVX,ABBV,BAC,KO,PEP,CAT,WMT,MRK,MCD"),
    c("G02_TECHNOLOGY", "Technology", "XLK",
      "AAPL,MSFT,NVDA,AVGO,ORCL,CRM,AMD,ADI,TXN,QCOM,CSCO,IBM,AMAT,MU,INTU"),
    c("G03_FINANCIALS", "Financials", "XLF",
      "JPM,BAC,WFC,C,GS,MS,BLK,AXP,USB,PNC,BK,STT,SCHW,CME,ICE"),
    c("G04_ENERGY", "Energy", "XLE",
      "XOM,CVX,COP,EOG,SLB,OXY,MPC,VLO,PSX,HES,HAL,BKR,KMI,WMB,DVN"),
    c("G05_HEALTH_CARE", "Health care", "XLV",
      "JNJ,LLY,MRK,ABBV,PFE,AMGN,GILD,BMY,UNH,CVS,CI,HUM,MDT,TMO,DHR"),
    c("G06_CONSUMER_STAPLES", "Consumer staples", "XLP",
      "PG,KO,PEP,WMT,COST,PM,MO,MDLZ,CL,KMB,GIS,SYY,KR,HSY,KHC"),
    c("G07_INDUSTRIALS", "Industrials", "XLI",
      "CAT,DE,GE,HON,UPS,UNP,RTX,LMT,NOC,ETN,EMR,ITW,PH,MMM,CMI"),
    c("G08_DISCRETIONARY", "Consumer discretionary", "XLY",
      "AMZN,HD,MCD,NKE,SBUX,LOW,TJX,BKNG,ORLY,AZO,ROST,DRI,TGT,GM,F"),
    c("G09_COMMUNICATION", "Communication services", "XLC",
      "GOOGL,META,NFLX,DIS,CMCSA,T,VZ,TMUS,CHTR,EA,TTWO,OMC,IPG,FOX,FOXA"),
    c("G10_UTILITIES", "Utilities", "XLU",
      "NEE,SO,DUK,AEP,SRE,D,EXC,XEL,ED,WEC,PEG,AWK,ETR,ES,PPL")
  )
  do.call(rbind, lapply(seq_along(rows), function(i) {
    data.frame(
      order = 600L + i,
      instance_id = rows[[i]][[1L]],
      category = rows[[i]][[2L]],
      benchmark = rows[[i]][[3L]],
      symbols = rows[[i]][[4L]],
      stringsAsFactors = FALSE
    )
  }))
}

g5_mr06_contract <- function() {
  list(
    schema_version = g5_mr06_schema_version(),
    literature_id = "LIT-MR-06.1",
    atlas_id = "BUY_ON_GAP_ATLAS_01",
    as_of_timestamp = "2026-07-24 17:30:00 America/New_York",
    query_start = as.Date("2018-08-01"),
    train_start = as.Date("2019-01-02"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    volatility_sessions = 90L,
    moving_average_sessions = 20L,
    gap_sigma_multiple = 1,
    top_n = 10L,
    signal_time_et = "09:31:00",
    entry_time_et = "09:32:00",
    primary_round_trip_cost_bps = 10,
    stress_round_trip_cost_bps = 20,
    minimum_entry_coverage = 0.95,
    minimum_stock_events = 60L,
    minimum_portfolio_days = 30L,
    maximum_positive_pnl_concentration = 0.50,
    bootstrap_count = 2000L,
    bootstrap_block_days = 5L,
    bootstrap_seed = 61101L,
    random_control_count = 500L,
    random_control_seed = 61102L,
    registry = g5_mr06_registry()
  )
}

g5_mr06_stop <- function(message) {
  stop(paste0("[LIT-MR-06.1] ", message), call. = FALSE)
}

g5_mr06_validate_contract <- function(contract = g5_mr06_contract()) {
  frozen <- g5_mr06_contract()
  scalar_fields <- setdiff(names(frozen), "registry")
  for (field in scalar_fields) {
    if (!identical(contract[[field]], frozen[[field]])) {
      g5_mr06_stop(paste("Frozen contract changed:", field))
    }
  }
  if (!identical(contract$registry, frozen$registry)) {
    g5_mr06_stop("Frozen atlas registry changed.")
  }
  invisible(contract)
}

g5_mr06_all_symbols <- function(contract = g5_mr06_contract()) {
  g5_mr06_validate_contract(contract)
  constituents <- unique(unlist(strsplit(
    contract$registry$symbols, ",", fixed = TRUE
  )))
  unique(c(constituents, contract$registry$benchmark))
}

g5_mr06_validate_daily <- function(bars, contract, query_end) {
  required <- c("symbol", "session_date", "open", "low", "close")
  if (!is.data.frame(bars) || !all(required %in% names(bars))) {
    g5_mr06_stop(paste(
      "Daily bars require columns:",
      paste(required, collapse = ", ")
    ))
  }
  bars <- bars[, unique(c(required, intersect(
    c("high", "volume", "adjusted", "timeframe", "provider",
      "as_of_timestamp", "data_version_hash"),
    names(bars)
  ))), drop = FALSE]
  bars$symbol <- toupper(trimws(as.character(bars$symbol)))
  bars$session_date <- as.Date(bars$session_date)
  for (field in c("open", "low", "close")) {
    bars[[field]] <- as.numeric(bars[[field]])
  }
  if (any(!is.finite(as.matrix(bars[c("open", "low", "close")])))) {
    g5_mr06_stop("Daily bars contain non-finite signal prices.")
  }
  if (any(bars[c("open", "low", "close")] <= 0)) {
    g5_mr06_stop("Daily signal prices must be positive.")
  }
  if (any(is.na(bars$session_date))) {
    g5_mr06_stop("Daily bars contain invalid session dates.")
  }
  if (anyDuplicated(bars[c("symbol", "session_date")])) {
    g5_mr06_stop("Duplicate daily symbol-session rows.")
  }
  if (max(bars$session_date) > as.Date(query_end)) {
    g5_mr06_stop("Daily bars exceed the explicit query boundary.")
  }
  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

g5_mr06_lag <- function(x, n = 1L) {
  n <- as.integer(n)
  c(rep(NA, n), head(x, -n))
}

g5_mr06_rolling_mean_lagged <- function(x, n) {
  output <- rep(NA_real_, length(x))
  if (length(x) <= n) return(output)
  for (i in seq.int(n + 1L, length(x))) {
    output[[i]] <- mean(x[(i - n):(i - 1L)])
  }
  output
}

g5_mr06_rolling_sd_lagged_returns <- function(close, n) {
  returns <- close / g5_mr06_lag(close) - 1
  output <- rep(NA_real_, length(close))
  if (length(close) <= n + 1L) return(output)
  for (i in seq.int(n + 2L, length(close))) {
    values <- returns[(i - n):(i - 1L)]
    output[[i]] <- stats::sd(values)
  }
  output
}

g5_mr06_symbol_features <- function(rows, contract) {
  rows <- rows[order(rows$session_date), , drop = FALSE]
  rows$prior_low <- g5_mr06_lag(rows$low)
  rows$ma20_lagged <- g5_mr06_rolling_mean_lagged(
    rows$close, contract$moving_average_sessions
  )
  rows$sigma90_lagged <- g5_mr06_rolling_sd_lagged_returns(
    rows$close, contract$volatility_sessions
  )
  rows$gap_return <- rows$open / rows$prior_low - 1
  rows$ma_qualified <- is.finite(rows$ma20_lagged) &
    rows$open > rows$ma20_lagged
  rows$gap_qualified <- is.finite(rows$sigma90_lagged) &
    rows$gap_return < -contract$gap_sigma_multiple * rows$sigma90_lagged
  rows$eligible <- rows$ma_qualified & rows$gap_qualified
  rows$source_open_close_return <- rows$close / rows$open - 1
  rows
}

g5_mr06_feature_panel <- function(bars, contract) {
  split_rows <- split(bars, bars$symbol)
  do.call(rbind, lapply(split_rows, g5_mr06_symbol_features, contract = contract))
}

g5_mr06_instance_symbols <- function(registry_row) {
  strsplit(registry_row$symbols[[1L]], ",", fixed = TRUE)[[1L]]
}

g5_mr06_select_ranked <- function(rows, top_n, eligible_field = "eligible") {
  rows <- rows[rows[[eligible_field]], , drop = FALSE]
  if (!nrow(rows)) return(rows)
  rows <- rows[order(rows$gap_return, rows$symbol), , drop = FALSE]
  rows <- head(rows, top_n)
  rows$selection_rank <- seq_len(nrow(rows))
  rows
}

g5_mr06_seed_for <- function(base_seed, instance_order, session_date, draw = 0L) {
  as.integer(
    (as.numeric(as.Date(session_date)) + base_seed +
       1009L * as.integer(instance_order) + 9176L * as.integer(draw)) %%
      .Machine$integer.max
  )
}

g5_mr06_build_instance_signals <- function(
  features,
  registry_row,
  start_date,
  end_date,
  contract
) {
  symbols <- g5_mr06_instance_symbols(registry_row)
  x <- features[
    features$symbol %in% symbols &
      features$session_date >= as.Date(start_date) &
      features$session_date <= as.Date(end_date),
    ,
    drop = FALSE
  ]
  dates <- sort(unique(x$session_date))
  selected <- list()
  no_ma <- list()
  candidate_days <- list()
  random_manifest <- list()
  for (date in dates) {
    day <- x[x$session_date == date, , drop = FALSE]
    ranked <- g5_mr06_select_ranked(day, contract$top_n, "eligible")
    ablation <- g5_mr06_select_ranked(day, contract$top_n, "gap_qualified")
    if (nrow(ranked)) {
      ranked$instance_id <- registry_row$instance_id[[1L]]
      ranked$category <- registry_row$category[[1L]]
      ranked$benchmark <- registry_row$benchmark[[1L]]
      selected[[length(selected) + 1L]] <- ranked
      candidate_days[[length(candidate_days) + 1L]] <- data.frame(
        instance_id = registry_row$instance_id[[1L]],
        session_date = date,
        selected_count = nrow(ranked),
        stringsAsFactors = FALSE
      )
      pool <- day[day$ma_qualified, , drop = FALSE]
      if (nrow(pool) >= nrow(ranked)) {
        for (draw in seq_len(contract$random_control_count)) {
          set.seed(g5_mr06_seed_for(
            contract$random_control_seed,
            registry_row$order[[1L]], date, draw
          ))
          chosen <- sample(seq_len(nrow(pool)), nrow(ranked), replace = FALSE)
          random_manifest[[length(random_manifest) + 1L]] <- data.frame(
            instance_id = registry_row$instance_id[[1L]],
            session_date = date,
            draw = draw,
            symbol = pool$symbol[chosen],
            stringsAsFactors = FALSE
          )
        }
      }
    }
    if (nrow(ablation)) {
      ablation$instance_id <- registry_row$instance_id[[1L]]
      ablation$category <- registry_row$category[[1L]]
      ablation$benchmark <- registry_row$benchmark[[1L]]
      no_ma[[length(no_ma) + 1L]] <- ablation
    }
  }
  empty_like <- x[FALSE, , drop = FALSE]
  empty_like$selection_rank <- integer()
  empty_like$instance_id <- character()
  empty_like$category <- character()
  empty_like$benchmark <- character()
  list(
    selected = if (length(selected)) do.call(rbind, selected) else empty_like,
    no_ma = if (length(no_ma)) do.call(rbind, no_ma) else empty_like,
    candidate_days = if (length(candidate_days)) {
      do.call(rbind, candidate_days)
    } else data.frame(
      instance_id = character(),
      session_date = as.Date(character()),
      selected_count = integer()
    ),
    random_manifest = if (length(random_manifest)) {
      do.call(rbind, random_manifest)
    } else data.frame(
      instance_id = character(),
      session_date = as.Date(character()),
      draw = integer(),
      symbol = character()
    )
  )
}

g5_mr06_build_signals <- function(
  daily_bars,
  contract = g5_mr06_contract(),
  start_date = contract$train_start,
  end_date = contract$train_end
) {
  g5_mr06_validate_contract(contract)
  daily <- g5_mr06_validate_daily(daily_bars, contract, end_date)
  features <- g5_mr06_feature_panel(daily, contract)
  instances <- lapply(seq_len(nrow(contract$registry)), function(i) {
    g5_mr06_build_instance_signals(
      features, contract$registry[i, , drop = FALSE],
      start_date, end_date, contract
    )
  })
  names(instances) <- contract$registry$instance_id
  list(features = features, instances = instances)
}

g5_mr06_entry_manifest <- function(signals, contract = g5_mr06_contract()) {
  rows <- list()
  for (i in seq_len(nrow(contract$registry))) {
    registry_row <- contract$registry[i, , drop = FALSE]
    instance <- signals$instances[[registry_row$instance_id]]
    selected_days <- unique(instance$selected$session_date)
    if (!length(selected_days)) next
    panel_symbols <- g5_mr06_instance_symbols(registry_row)
    pool <- signals$features[
      signals$features$session_date %in% selected_days &
        signals$features$symbol %in% panel_symbols &
        signals$features$ma_qualified,
      c("symbol", "session_date"),
      drop = FALSE
    ]
    ablation <- instance$no_ma[c("symbol", "session_date")]
    benchmark <- data.frame(
      symbol = registry_row$benchmark[[1L]],
      session_date = selected_days,
      stringsAsFactors = FALSE
    )
    rows[[length(rows) + 1L]] <- rbind(pool, ablation, benchmark)
  }
  if (!length(rows)) {
    return(data.frame(
      symbol = character(),
      session_date = as.Date(character()),
      stringsAsFactors = FALSE
    ))
  }
  unique(do.call(rbind, rows))
}

g5_mr06_validate_entries <- function(entries, contract, query_end) {
  required <- c("symbol", "session_date", "entry_timestamp_et", "entry_open")
  if (!is.data.frame(entries) || !all(required %in% names(entries))) {
    g5_mr06_stop(paste(
      "Entry bars require columns:", paste(required, collapse = ", ")
    ))
  }
  entries$symbol <- toupper(trimws(as.character(entries$symbol)))
  entries$session_date <- as.Date(entries$session_date)
  entries$entry_timestamp_et <- as.character(entries$entry_timestamp_et)
  entries$entry_open <- as.numeric(entries$entry_open)
  if (anyDuplicated(entries[c("symbol", "session_date")])) {
    g5_mr06_stop("Duplicate 09:32 symbol-session entry rows.")
  }
  if (any(entries$session_date > as.Date(query_end))) {
    g5_mr06_stop("Entry bars exceed the explicit query boundary.")
  }
  if (any(!is.finite(entries$entry_open) | entries$entry_open <= 0)) {
    g5_mr06_stop("Entry bars contain invalid prices.")
  }
  expected_suffix <- paste0(" ", contract$entry_time_et)
  if (any(!endsWith(entries$entry_timestamp_et, expected_suffix))) {
    g5_mr06_stop("Entry timestamps are not the frozen 09:32 ET bar open.")
  }
  entries
}

g5_mr06_join_entries <- function(rows, entries) {
  merge(
    rows, entries[c("symbol", "session_date", "entry_timestamp_et", "entry_open")],
    by = c("symbol", "session_date"), all.x = TRUE, sort = FALSE
  )
}

g5_mr06_event_returns <- function(rows, entries, contract) {
  x <- g5_mr06_join_entries(rows, entries)
  x$entry_available <- is.finite(x$entry_open)
  x$gross_return <- x$close / x$entry_open - 1
  x$primary_net_return <- x$gross_return -
    contract$primary_round_trip_cost_bps / 10000
  x$stress_net_return <- x$gross_return -
    contract$stress_round_trip_cost_bps / 10000
  x$up_down_accuracy <- x$gross_return > 0
  x
}

g5_mr06_daily_portfolio <- function(events, contract) {
  dates <- sort(unique(events$session_date))
  rows <- lapply(dates, function(date) {
    x <- events[events$session_date == date, , drop = FALSE]
    valid <- x[x$entry_available, , drop = FALSE]
    data.frame(
      session_date = date,
      selected_count = nrow(x),
      valid_count = nrow(valid),
      invested_fraction = nrow(valid) / contract$top_n,
      gross_return = sum(valid$gross_return) / contract$top_n,
      primary_net_return = sum(valid$primary_net_return) / contract$top_n,
      stress_net_return = sum(valid$stress_net_return) / contract$top_n,
      source_noncausal_return =
        sum(x$source_open_close_return) / contract$top_n,
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) {
    return(data.frame(
      session_date = as.Date(character()),
      selected_count = integer(), valid_count = integer(),
      invested_fraction = numeric(), gross_return = numeric(),
      primary_net_return = numeric(), stress_net_return = numeric(),
      source_noncausal_return = numeric()
    ))
  }
  do.call(rbind, rows)
}

g5_mr06_benchmark_days <- function(
  portfolio,
  registry_row,
  features,
  entries,
  contract
) {
  x <- features[
    features$symbol == registry_row$benchmark[[1L]] &
      features$session_date %in% portfolio$session_date,
    c("symbol", "session_date", "close"),
    drop = FALSE
  ]
  x <- g5_mr06_join_entries(x, entries)
  x$benchmark_gross_return <- x$close / x$entry_open - 1
  x$benchmark_primary_net_return <- x$benchmark_gross_return -
    contract$primary_round_trip_cost_bps / 10000
  output <- merge(
    portfolio, x[c("session_date", "benchmark_gross_return",
                   "benchmark_primary_net_return")],
    by = "session_date", all.x = TRUE, sort = TRUE
  )
  output$matched_benchmark_return <- output$invested_fraction *
    output$benchmark_primary_net_return
  output$excess_return <- output$primary_net_return -
    output$matched_benchmark_return
  output
}

g5_mr06_random_control <- function(
  manifest,
  features,
  entries,
  contract
) {
  if (!nrow(manifest)) {
    return(list(
      draw_summary = data.frame(draw = integer(), mean_return = numeric()),
      p90 = NA_real_
    ))
  }
  values <- merge(
    manifest,
    features[c("symbol", "session_date", "close")],
    by = c("symbol", "session_date"), all.x = TRUE, sort = FALSE
  )
  values <- g5_mr06_join_entries(values, entries)
  values$net_return <- values$close / values$entry_open - 1 -
    contract$primary_round_trip_cost_bps / 10000
  day_draw <- stats::aggregate(
    values$net_return / contract$top_n,
    by = list(draw = values$draw, session_date = values$session_date),
    FUN = sum, na.rm = TRUE
  )
  names(day_draw)[[3L]] <- "portfolio_return"
  draw_summary <- stats::aggregate(
    day_draw$portfolio_return,
    by = list(draw = day_draw$draw),
    FUN = mean, na.rm = TRUE
  )
  names(draw_summary)[[2L]] <- "mean_return"
  list(
    draw_summary = draw_summary,
    p90 = as.numeric(stats::quantile(
      draw_summary$mean_return, 0.90, names = FALSE, na.rm = TRUE
    ))
  )
}

g5_mr06_block_indices <- function(n, block_length) {
  if (n <= 0L) return(integer())
  block_length <- min(as.integer(block_length), n)
  starts <- sample.int(n, ceiling(n / block_length), replace = TRUE)
  unlist(lapply(starts, function(start) {
    ((start - 1L + seq_len(block_length) - 1L) %% n) + 1L
  }), use.names = FALSE)[seq_len(n)]
}

g5_mr06_bootstrap_days <- function(portfolio, contract, instance_order) {
  x <- portfolio$primary_net_return
  x <- x[is.finite(x)]
  set.seed(contract$bootstrap_seed + as.integer(instance_order))
  draws <- rep(NA_real_, contract$bootstrap_count)
  if (length(x)) {
    for (i in seq_along(draws)) {
      draws[[i]] <- mean(x[g5_mr06_block_indices(
        length(x), contract$bootstrap_block_days
      )])
    }
  }
  finite <- draws[is.finite(draws)]
  interval <- if (length(finite)) {
    stats::quantile(finite, c(0.05, 0.95), names = FALSE)
  } else c(NA_real_, NA_real_)
  list(
    estimate = if (length(x)) mean(x) else NA_real_,
    lower_90 = interval[[1L]],
    upper_90 = interval[[2L]],
    draws = draws
  )
}

g5_mr06_long_run_variance <- function(x) {
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

g5_mr06_performance <- function(portfolio, events) {
  returns <- portfolio$primary_net_return
  equity <- cumprod(1 + returns)
  peak <- cummax(c(1, equity))[-1L]
  drawdown <- equity / peak - 1
  lrv <- g5_mr06_long_run_variance(returns)
  data.frame(
    portfolio_days = nrow(portfolio),
    stock_events = nrow(events),
    cumulative_return = if (length(equity)) tail(equity, 1L) - 1 else NA_real_,
    stress_cumulative_return = if (nrow(portfolio)) {
      prod(1 + portfolio$stress_net_return) - 1
    } else NA_real_,
    source_noncausal_cumulative_return = if (nrow(portfolio)) {
      prod(1 + portfolio$source_noncausal_return) - 1
    } else NA_real_,
    naive_sharpe = if (length(returns) > 1L && stats::sd(returns) > 0) {
      sqrt(252) * mean(returns) / stats::sd(returns)
    } else NA_real_,
    autocorrelation_adjusted_sharpe =
      if (is.finite(lrv) && lrv > 0) {
        sqrt(252) * mean(returns) / sqrt(lrv)
      } else NA_real_,
    maximum_drawdown = if (length(drawdown)) min(drawdown) else NA_real_,
    stock_event_hit_rate = if (nrow(events)) {
      mean(events$primary_net_return > 0, na.rm = TRUE)
    } else NA_real_,
    stock_event_up_down_accuracy = if (nrow(events)) {
      mean(events$up_down_accuracy, na.rm = TRUE)
    } else NA_real_,
    average_invested_fraction = if (nrow(portfolio)) {
      mean(portfolio$invested_fraction)
    } else 0,
    stringsAsFactors = FALSE
  )
}

g5_mr06_positive_concentration <- function(events) {
  pnl <- stats::aggregate(
    pmax(events$gross_return, 0),
    by = list(symbol = events$symbol),
    FUN = sum, na.rm = TRUE
  )
  names(pnl)[[2L]] <- "positive_gross_pnl"
  total <- sum(pnl$positive_gross_pnl)
  list(
    table = pnl[order(-pnl$positive_gross_pnl), , drop = FALSE],
    maximum_share = if (total > 0) max(pnl$positive_gross_pnl) / total else Inf
  )
}

g5_mr06_integrity <- function(
  selected,
  events,
  entries,
  features,
  registry_row,
  contract,
  start_date,
  end_date
) {
  coverage <- if (nrow(events)) mean(events$entry_available) else 0
  strict_after_signal <- if (nrow(events)) {
    all(substr(events$entry_timestamp_et[events$entry_available], 12L, 19L) >
          contract$signal_time_et)
  } else FALSE
  required_symbols <- c(
    g5_mr06_instance_symbols(registry_row),
    registry_row$benchmark[[1L]]
  )
  observed_symbols <- unique(features$symbol)
  reference_dates <- sort(unique(features$session_date[
    features$symbol == registry_row$benchmark[[1L]] &
      features$session_date >= start_date &
      features$session_date <= end_date
  ]))
  symbol_coverage <- vapply(required_symbols, function(symbol) {
    observed <- features$session_date[
      features$symbol == symbol &
        features$session_date >= start_date &
        features$session_date <= end_date
    ]
    length(reference_dates) > 0L &&
      length(unique(observed)) / length(reference_dates) >= 0.90
  }, logical(1))
  price_alignment <- if (nrow(events) && any(events$entry_available)) {
    all(abs(
      events$entry_open[events$entry_available] /
        events$open[events$entry_available] - 1
    ) < 0.50)
  } else FALSE
  checks <- c(
    all(required_symbols %in% observed_symbols) && all(symbol_coverage),
    !anyDuplicated(selected[c("instance_id", "symbol", "session_date")]),
    all(selected$session_date >= start_date & selected$session_date <= end_date),
    all(selected$selection_rank >= 1L &
          selected$selection_rank <= contract$top_n),
    all(selected$eligible),
    all(is.finite(selected$prior_low) &
          is.finite(selected$ma20_lagged) &
          is.finite(selected$sigma90_lagged)),
    !anyDuplicated(entries[c("symbol", "session_date")]),
    strict_after_signal,
    price_alignment,
    all(events$close > 0, na.rm = TRUE)
  )
  data.frame(
    check_id = sprintf("I%02d", seq_along(checks)),
    check = c(
      "All frozen symbols have >= 90% TRAIN daily coverage",
      "No duplicate selected stock-events",
      "Selected events stay inside the explicit partition",
      "Ranks stay inside the frozen top-ten rule",
      "Every selected row passes both frozen signal rules",
      "Every signal diagnostic is finite and lagged",
      "No duplicate 09:32 entry bars",
      "Every available entry is strictly after the 09:31 signal",
      "Adjusted daily open and 09:32 entry stay scale-aligned",
      "Every closing proxy is positive"
    ),
    diagnostic = c(
      paste0(sum(symbol_coverage), "/", length(symbol_coverage), " symbols"),
      nrow(selected),
      paste(min(selected$session_date), max(selected$session_date), sep = " to "),
      if (nrow(selected)) max(selected$selection_rank) else 0,
      sum(selected$eligible),
      sum(is.finite(selected$sigma90_lagged)),
      nrow(entries),
      ifelse(strict_after_signal, contract$entry_time_et, "timing failure"),
      ifelse(price_alignment, "all within 50%", "scale mismatch or no fills"),
      sum(events$close > 0, na.rm = TRUE)
    ),
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

g5_mr06_gate_detail <- function(
  events,
  portfolio,
  bootstrap,
  random_control,
  concentration,
  integrity,
  contract
) {
  coverage <- if (nrow(events)) mean(events$entry_available) else 0
  valid_events <- events[events$entry_available, , drop = FALSE]
  mean_event <- if (nrow(valid_events)) {
    mean(valid_events$primary_net_return)
  } else NA_real_
  mean_excess <- if (nrow(portfolio)) {
    mean(portfolio$excess_return, na.rm = TRUE)
  } else NA_real_
  mean_portfolio <- if (nrow(portfolio)) {
    mean(portfolio$primary_net_return, na.rm = TRUE)
  } else NA_real_
  stress_cumulative <- if (nrow(portfolio)) {
    prod(1 + portfolio$stress_net_return) - 1
  } else NA_real_
  values <- c(
    all(integrity$status == "PASS"),
    coverage >= contract$minimum_entry_coverage,
    nrow(valid_events) >= contract$minimum_stock_events &&
      nrow(portfolio) >= contract$minimum_portfolio_days,
    is.finite(mean_event) && mean_event > 0,
    is.finite(bootstrap$lower_90) && bootstrap$lower_90 > 0,
    is.finite(mean_excess) && mean_excess > 0,
    is.finite(mean_portfolio) && is.finite(random_control$p90) &&
      mean_portfolio > random_control$p90,
    is.finite(stress_cumulative) && stress_cumulative > 0 &&
      is.finite(concentration$maximum_share) &&
      concentration$maximum_share <=
        contract$maximum_positive_pnl_concentration
  )
  data.frame(
    gate_id = seq_len(8L),
    gate = c(
      "Integrity and causal timing",
      "Selected-entry coverage >= 95%",
      "At least 60 stock-events and 30 portfolio days",
      "Positive primary-cost mean stock-event return",
      "Portfolio-day bootstrap lower 90% > 0",
      "Positive mean matched-benchmark excess",
      "Observed portfolio mean > random-control p90",
      "Positive stress return and <= 50% symbol concentration"
    ),
    diagnostic = c(
      paste0(sum(integrity$status == "PASS"), "/", nrow(integrity), " checks"),
      sprintf("%.1f%%", 100 * coverage),
      paste0(nrow(valid_events), " events; ", nrow(portfolio), " days"),
      sprintf("%.2f bp", 10000 * mean_event),
      sprintf("%.2f bp", 10000 * bootstrap$lower_90),
      sprintf("%.2f bp", 10000 * mean_excess),
      sprintf(
        "%.2f bp vs %.2f bp",
        10000 * mean_portfolio, 10000 * random_control$p90
      ),
      sprintf(
        "stress %.2f%%; max positive P&L share %.1f%%",
        100 * stress_cumulative, 100 * concentration$maximum_share
      )
    ),
    status = ifelse(values, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

g5_mr06_run_instance <- function(
  signals,
  entries,
  contract,
  registry_row,
  start_date,
  end_date
) {
  instance <- signals$instances[[registry_row$instance_id]]
  selected <- instance$selected
  events <- g5_mr06_event_returns(selected, entries, contract)
  daily <- g5_mr06_daily_portfolio(events, contract)
  portfolio <- g5_mr06_benchmark_days(
    daily, registry_row, signals$features, entries, contract
  )
  no_ma_events <- g5_mr06_event_returns(instance$no_ma, entries, contract)
  no_ma_portfolio <- g5_mr06_daily_portfolio(no_ma_events, contract)
  random_control <- g5_mr06_random_control(
    instance$random_manifest, signals$features, entries, contract
  )
  bootstrap <- g5_mr06_bootstrap_days(
    portfolio, contract, registry_row$order[[1L]]
  )
  concentration <- g5_mr06_positive_concentration(events)
  integrity <- g5_mr06_integrity(
    selected, events, entries, signals$features, registry_row,
    contract, start_date, end_date
  )
  performance <- g5_mr06_performance(portfolio, events)
  gates <- g5_mr06_gate_detail(
    events, portfolio, bootstrap, random_control, concentration,
    integrity, contract
  )
  full_pass <- all(gates$status == "PASS")
  list(
    registry = registry_row,
    selected = selected,
    events = events,
    portfolio = portfolio,
    no_ma_events = no_ma_events,
    no_ma_portfolio = no_ma_portfolio,
    random_control = random_control,
    bootstrap = bootstrap,
    concentration = concentration,
    integrity = integrity,
    performance = performance,
    gates = gates,
    full_pass = full_pass,
    status = if (full_pass) {
      "TRAIN_PASS_LIT_MR_06_1"
    } else {
      "STOP_LIT_MR_06_1_TRAIN"
    }
  )
}

g5_mr06_run_train <- function(
  daily_bars,
  entries,
  contract = g5_mr06_contract()
) {
  g5_mr06_validate_contract(contract)
  daily <- g5_mr06_validate_daily(daily_bars, contract, contract$train_end)
  entries <- g5_mr06_validate_entries(entries, contract, contract$train_end)
  signals <- g5_mr06_build_signals(
    daily, contract, contract$train_start, contract$train_end
  )
  results <- lapply(seq_len(nrow(contract$registry)), function(i) {
    g5_mr06_run_instance(
      signals, entries, contract, contract$registry[i, , drop = FALSE],
      contract$train_start, contract$train_end
    )
  })
  names(results) <- contract$registry$instance_id
  list(
    contract = contract,
    signals = signals,
    entry_manifest = g5_mr06_entry_manifest(signals, contract),
    results = results,
    nominated_instances = names(results)[vapply(
      results, function(x) x$full_pass, logical(1)
    )],
    status = if (any(vapply(results, function(x) x$full_pass, logical(1)))) {
      "TRAIN_PASS_LIT_MR_06_1_ATLAS_HAS_NOMINEE"
    } else {
      "STOP_LIT_MR_06_1_ATLAS_NO_FULL_PASS"
    }
  )
}

g5_mr06_run_development <- function(
  daily_bars,
  entries,
  nominated_instances,
  contract = g5_mr06_contract()
) {
  g5_mr06_validate_contract(contract)
  nominated_instances <- unique(as.character(nominated_instances))
  if (!length(nominated_instances) ||
      any(!nominated_instances %in% contract$registry$instance_id)) {
    g5_mr06_stop("DEVELOPMENT requires valid TRAIN-nominated instances.")
  }
  daily <- g5_mr06_validate_daily(
    daily_bars, contract, contract$development_end
  )
  entries <- g5_mr06_validate_entries(
    entries, contract, contract$development_end
  )
  signals <- g5_mr06_build_signals(
    daily, contract, contract$development_start, contract$development_end
  )
  rows <- match(nominated_instances, contract$registry$instance_id)
  results <- lapply(rows, function(i) {
    result <- g5_mr06_run_instance(
      signals, entries, contract, contract$registry[i, , drop = FALSE],
      contract$development_start, contract$development_end
    )
    result$status <- "OOS_DEVELOPMENT_COMPLETE_LIT_MR_06_1"
    result
  })
  names(results) <- nominated_instances
  list(
    contract = contract,
    signals = signals,
    entry_manifest = g5_mr06_entry_manifest(signals, contract),
    results = results,
    status = "OOS_DEVELOPMENT_COMPLETE_LIT_MR_06_1"
  )
}
