# LIT-MOM-01.2 single-position, fully compounded retrospective exercise.

g5_mom012_stop <- function(message) stop(message, call. = FALSE)

g5_mom012_schema_version <- function() "gen5_lit_mom_01_2_v1"

g5_mom012_require_parent <- function() {
  required <- c(
    "g5_mom01_contract",
    "g5_mom01_validate_bars",
    "g5_mom01_signal_panel",
    "g5_mom01_anchor_pairs",
    "g5_mom01_horizon_screen",
    "g5_mom01_select_horizon"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    g5_mom012_stop(paste(
      "Source the LIT-MOM-01.1 module before LIT-MOM-01.2:",
      paste(missing, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

g5_mom012_contract <- function() {
  list(
    literature_id = "LIT-MOM-01.2",
    parent_literature_id = "LIT-MOM-01.1",
    descriptive_name = "Long-Only Single-Position Open-Horizon Momentum",
    evidence_label = "RETROSPECTIVE_EXPLORATION",
    position_scope = "LONG_ONLY",
    symbol = "SHY",
    as_of_timestamp = "2026-07-30 17:30:00 America/New_York",
    source_packet = file.path(
      "runs", "research_workbench", "literature_grounded",
      "lit_mom_01_1_interday_momentum_20260730_v6"
    ),
    query_start = as.Date("2016-01-04"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    retrospective_start = as.Date("2021-01-04"),
    retrospective_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    horizon_grid = c(1L, 5L, 10L, 25L, 60L, 120L, 250L),
    minimum_selected_holding_sessions = 5L,
    minimum_screen_pairs = 20L,
    screen_p_value_maximum = 0.10,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    stress_borrow_bps_annual = 0,
    initial_wealth = 1,
    entry_equity_fraction = 1,
    allow_pyramiding = FALSE,
    rebalance_within_trade = FALSE,
    allow_same_open_reentry = TRUE
  )
}

g5_mom012_validate_contract <- function(contract = g5_mom012_contract()) {
  frozen <- g5_mom012_contract()
  replication_batch <- attr(
    contract,
    "g5_mom012_replication_batch",
    exact = TRUE
  )
  if (!identical(names(contract), names(frozen))) {
    g5_mom012_stop("Frozen LIT-MOM-01.2 contract field set changed.")
  }
  if (!is.null(replication_batch)) {
    allowed_batches <- c(
      "STOCK_ATLAS_01_RETROSPECTIVE",
      "STOCK_ATLAS_02_2020_BREADTH_ATTENTION"
    )
    if (!replication_batch %in% allowed_batches) {
      g5_mom012_stop("Unknown LIT-MOM-01.2 replication batch.")
    }
    if (
      !is.character(contract$symbol) || length(contract$symbol) != 1L ||
        is.na(contract$symbol) ||
        !grepl("^[A-Z][A-Z0-9.]{0,9}$", contract$symbol)
    ) {
      g5_mom012_stop("Replication symbol must be one uppercase US equity ticker.")
    }
    contract_for_comparison <- contract
    contract_for_comparison$symbol <- frozen$symbol
    same <- vapply(
      names(frozen),
      function(field) identical(contract_for_comparison[[field]], frozen[[field]]),
      logical(1)
    )
    if (!all(same)) {
      g5_mom012_stop(paste(
        "Frozen LIT-MOM-01.2 replication contract changed:",
        paste(names(frozen)[!same], collapse = ", ")
      ))
    }
    return(contract)
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom012_stop(paste(
      "Frozen LIT-MOM-01.2 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom012_replication_contract <- function(
  symbol,
  batch_id = "STOCK_ATLAS_01_RETROSPECTIVE"
) {
  allowed_batches <- c(
    "STOCK_ATLAS_01_RETROSPECTIVE",
    "STOCK_ATLAS_02_2020_BREADTH_ATTENTION"
  )
  if (length(batch_id) != 1L || !batch_id %in% allowed_batches) {
    g5_mom012_stop("Unknown LIT-MOM-01.2 replication batch.")
  }
  contract <- g5_mom012_contract()
  contract$symbol <- as.character(symbol)
  attr(contract, "g5_mom012_replication_batch") <- batch_id
  g5_mom012_validate_contract(contract)
}

g5_mom012_validate_atlas02_registry <- function(
  registry,
  prior_symbols = character()
) {
  required <- c(
    "instance_id", "symbol", "source_symbol", "cohort", "sector",
    "selection_basis", "source_id", "source_date", "documented_rank",
    "history_note"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mom012_stop(paste(
      "Stock Atlas 02 registry missing columns:",
      paste(missing, collapse = ", ")
    ))
  }
  if (nrow(registry) != 100L) {
    g5_mom012_stop("Stock Atlas 02 registry must contain exactly 100 rows.")
  }
  if (any(!nzchar(registry$instance_id)) || anyDuplicated(registry$instance_id)) {
    g5_mom012_stop("Stock Atlas 02 instance IDs must be non-empty and unique.")
  }
  if (any(!nzchar(registry$symbol)) || anyDuplicated(registry$symbol)) {
    g5_mom012_stop("Stock Atlas 02 symbols must be non-empty and unique.")
  }
  if (length(intersect(registry$symbol, prior_symbols))) {
    g5_mom012_stop("Stock Atlas 02 must not overlap Stock Atlas 01 symbols.")
  }
  cohort_counts <- table(registry$cohort)
  expected <- c(DIVERSIFIED_CORE = 75L, RETAIL_ATTENTION_2020 = 25L)
  observed_counts <- as.integer(cohort_counts[names(expected)])
  if (anyNA(observed_counts) || !identical(observed_counts, unname(expected))) {
    g5_mom012_stop("Stock Atlas 02 cohort counts must be 75 core and 25 attention.")
  }
  expected_sectors <- c(
    "Communication Services", "Consumer Discretionary", "Consumer Staples",
    "Energy", "Financials", "Health Care", "Industrials",
    "Information Technology", "Materials", "Real Estate", "Utilities"
  )
  core_sectors <- sort(unique(registry$sector[registry$cohort == "DIVERSIFIED_CORE"]))
  if (!identical(core_sectors, sort(expected_sectors))) {
    g5_mom012_stop("Diversified core must cover all eleven broad sectors.")
  }
  source_dates <- as.Date(registry$source_date)
  if (anyNA(source_dates) || any(source_dates > as.Date("2020-12-31"))) {
    g5_mom012_stop("Every Stock Atlas 02 source date must be known by TRAIN end.")
  }
  checks <- data.frame(
    check_id = c(
      "ROW_COUNT_100", "UNIQUE_IDS", "UNIQUE_SYMBOLS", "NO_ATLAS01_OVERLAP",
      "COHORT_COUNTS_75_25", "CORE_ELEVEN_SECTORS", "SOURCES_KNOWN_BY_TRAIN_END"
    ),
    passed = TRUE,
    stringsAsFactors = FALSE
  )
  list(registry = registry, checks = checks)
}

g5_mom012_parent_contract <- function(contract = g5_mom012_contract()) {
  g5_mom012_require_parent()
  contract <- g5_mom012_validate_contract(contract)
  replication_batch <- attr(
    contract,
    "g5_mom012_replication_batch",
    exact = TRUE
  )
  parent <- if (is.null(replication_batch)) {
    g5_mom01_contract()
  } else {
    g5_mom01_replication_contract(contract$symbol, "STOCK_ATLAS_01")
  }
  parent$horizon_grid <- contract$horizon_grid
  parent$minimum_selected_holding_sessions <-
    contract$minimum_selected_holding_sessions
  parent$minimum_screen_pairs <- contract$minimum_screen_pairs
  parent$screen_p_value_maximum <- contract$screen_p_value_maximum
  parent
}

g5_mom012_summarize_pairs <- function(pairs, sampling_id, step_sessions) {
  test <- if (
    nrow(pairs) >= 3L &&
      stats::sd(pairs$past_return) > 0 &&
      stats::sd(pairs$future_return) > 0
  ) {
    stats::cor.test(pairs$past_return, pairs$future_return, method = "pearson")
  } else {
    NULL
  }
  data.frame(
    sampling_id = sampling_id,
    step_sessions = as.integer(step_sessions),
    pair_count = nrow(pairs),
    return_correlation = if (is.null(test)) NA_real_ else unname(test$estimate),
    naive_pearson_p_value = if (is.null(test)) NA_real_ else test$p.value,
    direction_accuracy = if (nrow(pairs)) mean(pairs$direction_correct) else NA_real_,
    long_call_precision = if (any(pairs$signal == 1L)) {
      mean(pairs$future_sign[pairs$signal == 1L] == 1L)
    } else {
      NA_real_
    },
    short_call_precision = if (any(pairs$signal == -1L)) {
      mean(pairs$future_sign[pairs$signal == -1L] == -1L)
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
}

g5_mom012_step_l_phase_offsets <- function(
  signal_panel,
  period_start,
  period_end,
  lookback_sessions
) {
  eligible <- signal_panel[
    signal_panel$signal_date >= as.Date(period_start) &
      signal_panel$outcome_date <= as.Date(period_end) &
      is.finite(signal_panel$past_return) &
      is.finite(signal_panel$future_return),
    ,
    drop = FALSE
  ]
  lookback_sessions <- as.integer(lookback_sessions)
  rows <- lapply(0:(lookback_sessions - 1L), function(offset) {
    first <- 1L + offset
    chosen <- if (first <= nrow(eligible)) {
      seq.int(first, nrow(eligible), by = lookback_sessions)
    } else {
      integer()
    }
    pairs <- eligible[chosen, , drop = FALSE]
    pairs$direction_correct <- pairs$signal == pairs$future_sign
    summary <- g5_mom012_summarize_pairs(
      pairs,
      "STEP_L_PHASE",
      lookback_sessions
    )
    data.frame(
      phase_offset = as.integer(offset),
      first_signal_date = if (nrow(pairs)) {
        as.character(pairs$signal_date[[1L]])
      } else {
        NA_character_
      },
      summary,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_mom012_inference_views <- function(
  bars,
  period_start,
  period_end,
  lookback_sessions,
  holding_sessions,
  contract = g5_mom012_contract()
) {
  g5_mom012_require_parent()
  contract <- g5_mom012_validate_contract(contract)
  parent <- g5_mom012_parent_contract(contract)
  panel <- g5_mom01_signal_panel(
    bars,
    parent,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  steps <- c(
    CHAN_MIN_STEP = min(lookback_sessions, holding_sessions),
    STEP_L = lookback_sessions,
    STRICT_L_PLUS_H = lookback_sessions + holding_sessions
  )
  pairs <- lapply(names(steps), function(id) {
    g5_mom01_anchor_pairs(
      panel,
      period_start,
      period_end,
      step_sessions = steps[[id]],
      sampling_id = id
    )
  })
  names(pairs) <- names(steps)
  summary <- do.call(rbind, lapply(names(pairs), function(id) {
    g5_mom012_summarize_pairs(pairs[[id]], id, steps[[id]])
  }))
  phase_offsets <- g5_mom012_step_l_phase_offsets(
    panel,
    period_start,
    period_end,
    lookback_sessions
  )
  list(
    signal_panel = panel,
    pairs = pairs,
    summary = summary,
    step_l_phase_offsets = phase_offsets
  )
}

g5_mom012_horizon_screen <- function(
  bars,
  period_start,
  period_end,
  contract = g5_mom012_contract()
) {
  g5_mom012_require_parent()
  contract <- g5_mom012_validate_contract(contract)
  parent <- g5_mom012_parent_contract(contract)
  base <- g5_mom01_horizon_screen(
    bars,
    period_start,
    period_end,
    parent
  )
  diagnostics <- lapply(seq_len(nrow(base)), function(i) {
    row <- base[i, , drop = FALSE]
    views <- g5_mom012_inference_views(
      bars,
      period_start,
      period_end,
      row$lookback_sessions,
      row$holding_sessions,
      contract
    )
    step_l <- views$summary[views$summary$sampling_id == "STEP_L", , drop = FALSE]
    phases <- views$step_l_phase_offsets
    finite_cor <- phases$return_correlation[is.finite(phases$return_correlation)]
    finite_acc <- phases$direction_accuracy[is.finite(phases$direction_accuracy)]
    data.frame(
      step_l_pair_count = step_l$pair_count,
      step_l_return_correlation = step_l$return_correlation,
      step_l_direction_accuracy = step_l$direction_accuracy,
      step_l_phase_pair_count_min = min(phases$pair_count),
      step_l_phase_pair_count_max = max(phases$pair_count),
      step_l_phase_correlation_median = if (length(finite_cor)) {
        stats::median(finite_cor)
      } else {
        NA_real_
      },
      step_l_phase_correlation_min = if (length(finite_cor)) min(finite_cor) else NA_real_,
      step_l_phase_correlation_max = if (length(finite_cor)) max(finite_cor) else NA_real_,
      step_l_phase_accuracy_median = if (length(finite_acc)) {
        stats::median(finite_acc)
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  })
  cbind(base, do.call(rbind, diagnostics))
}

g5_mom012_select_horizon <- function(
  horizon_screen,
  contract = g5_mom012_contract()
) {
  contract <- g5_mom012_validate_contract(contract)
  parent <- g5_mom012_parent_contract(contract)
  selected <- g5_mom01_select_horizon(horizon_screen, parent)
  selected$primary_sampling_id <- "CHAN_MIN_STEP"
  selected$robustness_sampling_id <- "STEP_L"
  selected$strict_sampling_id <- "STRICT_L_PLUS_H"
  selected$evidence_label <- contract$evidence_label
  selected
}

g5_mom012_trade_schedule <- function(
  bars,
  period_start,
  period_end,
  lookback_sessions,
  holding_sessions,
  contract = g5_mom012_contract()
) {
  g5_mom012_require_parent()
  contract <- g5_mom012_validate_contract(contract)
  parent <- g5_mom012_parent_contract(contract)
  checked <- g5_mom01_validate_bars(bars, parent)
  x <- checked$bars
  panel <- g5_mom01_signal_panel(
    x,
    parent,
    lookback_sessions = lookback_sessions,
    holding_sessions = holding_sessions
  )
  period_start <- as.Date(period_start)
  period_end <- as.Date(period_end)
  signal_i <- which(
    panel$signal_date >= period_start &
      panel$signal_date < period_end &
      !is.na(panel$signal) &
      panel$signal == 1L
  )
  if (!length(signal_i)) {
    g5_mom012_stop("No eligible positive signal exists in the requested period.")
  }
  signal_i <- signal_i[[1L]]
  rows <- list()
  trade_id <- 1L
  repeat {
    while (
      signal_i <= nrow(panel) &&
        (is.na(panel$signal[[signal_i]]) || panel$signal[[signal_i]] != 1L)
    ) {
      signal_i <- signal_i + 1L
    }
    if (signal_i >= nrow(x)) break
    entry_i <- signal_i + 1L
    exit_i <- entry_i + as.integer(holding_sessions)
    if (
      exit_i > nrow(x) ||
        x$session_date[[entry_i]] > period_end ||
        x$session_date[[exit_i]] > period_end
    ) break
    direction <- 1L
    rows[[trade_id]] <- data.frame(
      trade_id = trade_id,
      signal_index = signal_i,
      entry_index = entry_i,
      exit_index = exit_i,
      signal_date = x$session_date[[signal_i]],
      entry_date = x$session_date[[entry_i]],
      exit_date = x$session_date[[exit_i]],
      direction = direction,
      direction_label = "LONG",
      past_lookback_return = panel$past_return[[signal_i]],
      entry_open = x$open[[entry_i]],
      exit_open = x$open[[exit_i]],
      underlying_holding_return = x$open[[exit_i]] / x$open[[entry_i]] - 1,
      direction_correct =
        sign(x$open[[exit_i]] / x$open[[entry_i]] - 1) == direction,
      stringsAsFactors = FALSE
    )
    trade_id <- trade_id + 1L
    signal_i <- exit_i - 1L
    if (panel$signal_date[[signal_i]] < period_start) signal_i <- signal_i + 1L
  }
  if (!length(rows)) {
    g5_mom012_stop("No complete single-position trades exist in the period.")
  }
  out <- do.call(rbind, rows)
  if (nrow(out) > 1L && any(out$entry_index[-1L] < out$exit_index[-nrow(out)])) {
    g5_mom012_stop("Single-position trade schedule overlaps.")
  }
  out
}

g5_mom012_replay_regime <- function(
  bars,
  schedule,
  cost_bps,
  borrow_bps_annual,
  regime_id,
  contract = g5_mom012_contract()
) {
  g5_mom012_require_parent()
  contract <- g5_mom012_validate_contract(contract)
  parent <- g5_mom012_parent_contract(contract)
  x <- g5_mom01_validate_bars(bars, parent)$bars
  cost_rate <- as.numeric(cost_bps) / 10000
  borrow_rate_daily <- as.numeric(borrow_bps_annual) / 10000 / 252
  wealth <- as.numeric(contract$initial_wealth)
  peak <- wealth
  rows <- list()
  row_i <- 1L
  trade_returns <- numeric(nrow(schedule))
  executed_trades <- 0L
  for (trade_i in seq_len(nrow(schedule))) {
    if (wealth <= 0) break
    trade <- schedule[trade_i, , drop = FALSE]
    executed_trades <- trade_i
    start_wealth <- wealth
    entry_notional <- start_wealth * contract$entry_equity_fraction / (1 + cost_rate)
    entry_cost <- entry_notional * cost_rate
    units <- entry_notional / trade$entry_open
    wealth <- wealth - entry_cost
    for (bar_i in trade$entry_index:(trade$exit_index - 1L)) {
      is_entry <- bar_i == trade$entry_index
      wealth_before <- if (is_entry) start_wealth else wealth
      current_notional <- units * x$open[[bar_i]]
      price_pnl <- trade$direction * units *
        (x$open[[bar_i + 1L]] - x$open[[bar_i]])
      borrow_cost <- if (trade$direction < 0L) {
        current_notional * borrow_rate_daily
      } else {
        0
      }
      is_exit <- bar_i + 1L == trade$exit_index
      exit_cost <- if (is_exit) units * x$open[[bar_i + 1L]] * cost_rate else 0
      transaction_cost <- if (is_entry) entry_cost else 0
      transaction_cost <- transaction_cost + exit_cost
      raw_wealth <- wealth + price_pnl - borrow_cost - exit_cost
      bankruptcy_event <- raw_wealth <= 0
      wealth <- max(raw_wealth, 0)
      peak <- max(peak, wealth)
      rows[[row_i]] <- data.frame(
        regime_id = regime_id,
        trade_id = trade$trade_id,
        signal_date = trade$signal_date,
        trade_entry_date = trade$entry_date,
        trade_exit_date = trade$exit_date,
        interval_entry_date = x$session_date[[bar_i]],
        outcome_date = x$session_date[[bar_i + 1L]],
        direction = trade$direction,
        direction_label = trade$direction_label,
        units = units,
        entry_notional = entry_notional,
        current_market_notional = current_notional,
        wealth_before_interval = wealth_before,
        effective_exposure = trade$direction * current_notional / wealth_before,
        underlying_open_return =
          x$open[[bar_i + 1L]] / x$open[[bar_i]] - 1,
        price_pnl = price_pnl,
        transaction_cost = transaction_cost,
        borrow_cost = borrow_cost,
        net_pnl = wealth - wealth_before,
        net_return = wealth / wealth_before - 1,
        wealth = wealth,
        drawdown = wealth / peak - 1,
        bankruptcy_event = bankruptcy_event,
        is_trade_entry_interval = is_entry,
        is_trade_exit_interval = is_exit,
        stringsAsFactors = FALSE
      )
      row_i <- row_i + 1L
      if (bankruptcy_event) break
    }
    trade_returns[[trade_i]] <- wealth / start_wealth - 1
    if (wealth <= 0) break
  }
  replay <- do.call(rbind, rows)
  trade_results <- schedule[seq_len(executed_trades), , drop = FALSE]
  trade_results$regime_id <- regime_id
  trade_results$trade_return <- trade_returns[seq_len(executed_trades)]
  trade_results$bankruptcy_trade <- trade_results$trade_return <= -1
  list(replay = replay, trade_results = trade_results)
}

g5_mom012_metrics <- function(replay, regime_id) {
  returns <- replay$net_return
  years <- max(length(returns) / 252, 1 / 252)
  volatility <- stats::sd(returns) * sqrt(252)
  data.frame(
    regime_id = regime_id,
    interval_count = nrow(replay),
    trade_count = length(unique(replay$trade_id)),
    cumulative_return = tail(replay$wealth, 1) - 1,
    annualized_compound_return = tail(replay$wealth, 1)^(1 / years) - 1,
    annualized_volatility = volatility,
    naive_sharpe = if (stats::sd(returns) > 0) {
      sqrt(252) * mean(returns) / stats::sd(returns)
    } else {
      NA_real_
    },
    maximum_drawdown = min(replay$drawdown),
    average_effective_exposure = mean(replay$effective_exposure),
    average_gross_exposure = mean(abs(replay$effective_exposure)),
    total_transaction_cost = sum(replay$transaction_cost),
    total_borrow_cost = sum(replay$borrow_cost),
    bankruptcy_occurred = any(replay$bankruptcy_event),
    bankruptcy_date = if (any(replay$bankruptcy_event)) {
      as.character(min(replay$outcome_date[replay$bankruptcy_event]))
    } else {
      NA_character_
    },
    stringsAsFactors = FALSE
  )
}

g5_mom012_calendar_years <- function(replay) {
  groups <- split(replay$net_return, format(replay$outcome_date, "%Y"))
  do.call(rbind, Map(function(returns, year_id) {
    data.frame(
      calendar_year = year_id,
      interval_count = length(returns),
      cumulative_return = prod(1 + returns) - 1,
      stringsAsFactors = FALSE
    )
  }, groups, names(groups)))
}

g5_mom012_direction_audit <- function(trade_results, period_id) {
  primary <- trade_results[trade_results$regime_id == "PRIMARY", , drop = FALSE]
  groups <- split(primary, primary$direction_label)
  do.call(rbind, lapply("LONG", function(direction) {
    x <- groups[[direction]]
    if (is.null(x) || !nrow(x)) {
      return(data.frame(
        period_id = period_id,
        direction = direction,
        trade_count = 0L,
        direction_accuracy = NA_real_,
        mean_primary_trade_return = NA_real_,
        cumulative_compounded_trade_return = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    data.frame(
      period_id = period_id,
      direction = direction,
      trade_count = nrow(x),
      direction_accuracy = mean(x$direction_correct),
      mean_primary_trade_return = mean(x$trade_return),
      cumulative_compounded_trade_return = prod(1 + x$trade_return) - 1,
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom012_analyze_period <- function(
  bars,
  period_start,
  period_end,
  period_id,
  lookback_sessions,
  holding_sessions,
  contract = g5_mom012_contract()
) {
  contract <- g5_mom012_validate_contract(contract)
  inference <- g5_mom012_inference_views(
    bars,
    period_start,
    period_end,
    lookback_sessions,
    holding_sessions,
    contract
  )
  schedule <- g5_mom012_trade_schedule(
    bars,
    period_start,
    period_end,
    lookback_sessions,
    holding_sessions,
    contract
  )
  regimes <- list(
    GROSS = c(cost_bps = 0, borrow_bps_annual = 0),
    PRIMARY = c(
      cost_bps = contract$primary_cost_bps,
      borrow_bps_annual = 0
    ),
    STRESS = c(
      cost_bps = contract$stress_cost_bps,
      borrow_bps_annual = 0
    )
  )
  replayed <- lapply(names(regimes), function(regime_id) {
    settings <- regimes[[regime_id]]
    g5_mom012_replay_regime(
      bars,
      schedule,
      settings[["cost_bps"]],
      settings[["borrow_bps_annual"]],
      regime_id,
      contract
    )
  })
  names(replayed) <- names(regimes)
  replay <- do.call(rbind, lapply(replayed, function(x) x$replay))
  trade_results <- do.call(rbind, lapply(replayed, function(x) x$trade_results))
  metrics <- do.call(rbind, lapply(names(regimes), function(regime_id) {
    g5_mom012_metrics(
      replay[replay$regime_id == regime_id, , drop = FALSE],
      regime_id
    )
  }))
  primary_replay <- replay[replay$regime_id == "PRIMARY", , drop = FALSE]
  list(
    period_id = period_id,
    period_start = as.Date(period_start),
    period_end = as.Date(period_end),
    lookback_sessions = as.integer(lookback_sessions),
    holding_sessions = as.integer(holding_sessions),
    inference = inference,
    schedule = schedule,
    replay = replay,
    trade_results = trade_results,
    metrics = metrics,
    calendar_years = g5_mom012_calendar_years(primary_replay),
    direction_audit = g5_mom012_direction_audit(trade_results, period_id)
  )
}

g5_mom012_integrity_audit <- function(
  bars,
  selected,
  train,
  retrospective,
  contract = g5_mom012_contract()
) {
  contract <- g5_mom012_validate_contract(contract)
  parent <- g5_mom012_parent_contract(contract)
  checked <- g5_mom01_validate_bars(bars, parent)
  nonoverlap <- function(schedule) {
    nrow(schedule) <= 1L ||
      all(schedule$entry_index[-1L] >= schedule$exit_index[-nrow(schedule)])
  }
  fixed_units <- function(replay) {
    groups <- split(replay$units, paste(replay$regime_id, replay$trade_id))
    all(vapply(groups, function(x) length(unique(signif(x, 12))) == 1L, logical(1)))
  }
  compounded <- function(analysis) {
    all(vapply(split(analysis$replay, analysis$replay$regime_id), function(x) {
      all(is.finite(x$wealth)) && all(x$wealth >= 0) &&
        (tail(x$wealth, 1) > 0 || any(x$bankruptcy_event))
    }, logical(1)))
  }
  rows <- data.frame(
    check_id = c(
      "parent_data_integrity",
      "confirmation_excluded",
      "train_only_horizon_selection",
      "three_inference_views",
      "step_l_phase_offsets_reported",
      "train_trades_nonoverlapping",
      "retrospective_trades_nonoverlapping",
      "fixed_units_within_trade",
      "long_only_schedule_and_zero_borrow",
      "fully_compounded_nonnegative_or_bankruptcy_stopped",
      "retrospective_label_explicit"
    ),
    passed = c(
      all(checked$checks$passed),
      max(checked$bars$session_date) < contract$confirmation_start,
      isTRUE(selected$selected_before_oos),
      identical(
        train$inference$summary$sampling_id,
        c("CHAN_MIN_STEP", "STEP_L", "STRICT_L_PLUS_H")
      ),
      nrow(train$inference$step_l_phase_offsets) ==
        selected$lookback_sessions,
      nonoverlap(train$schedule),
      nonoverlap(retrospective$schedule),
      fixed_units(train$replay) && fixed_units(retrospective$replay),
      all(train$schedule$direction == 1L) &&
        all(retrospective$schedule$direction == 1L) &&
        sum(train$replay$borrow_cost) == 0 &&
        sum(retrospective$replay$borrow_cost) == 0,
      compounded(train) && compounded(retrospective),
      identical(contract$evidence_label, "RETROSPECTIVE_EXPLORATION")
    ),
    stringsAsFactors = FALSE
  )
  rows$status <- ifelse(rows$passed, "PASS", "FAIL")
  rows
}

g5_mom012_run <- function(
  bars,
  contract = g5_mom012_contract()
) {
  contract <- g5_mom012_validate_contract(contract)
  horizon_screen <- g5_mom012_horizon_screen(
    bars,
    contract$train_start,
    contract$train_end,
    contract
  )
  selected <- g5_mom012_select_horizon(horizon_screen, contract)
  train <- g5_mom012_analyze_period(
    bars,
    contract$train_start,
    contract$train_end,
    "TRAIN",
    selected$lookback_sessions,
    selected$holding_sessions,
    contract
  )
  retrospective <- g5_mom012_analyze_period(
    bars,
    contract$retrospective_start,
    contract$retrospective_end,
    "RETROSPECTIVE_2021_2023",
    selected$lookback_sessions,
    selected$holding_sessions,
    contract
  )
  integrity <- g5_mom012_integrity_audit(
    bars,
    selected,
    train,
    retrospective,
    contract
  )
  list(
    contract = contract,
    horizon_screen = horizon_screen,
    selected_candidate = selected,
    train = train,
    retrospective = retrospective,
    integrity_audit = integrity,
    overall_status = if (all(integrity$passed)) {
      "RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2"
    } else {
      "STOP_LIT_MOM_01_2_INTEGRITY"
    }
  )
}
