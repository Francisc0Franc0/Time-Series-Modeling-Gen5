edl_ms01_stop <- function(message) {
  stop(paste0("[EDL-MS-01] ", message), call. = FALSE)
}

edl_ms01_contract <- function() {
  list(
    study_id = "EDL_MS_01_RULE201_RECLAIM_DISCOVERY_01",
    symbols = c(
      "TSLA", "AMD", "NVDA",
      "GME", "AMC", "CVNA", "PLTR", "COIN", "SOFI", "RIVN"
    ),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    threshold = -0.10,
    discovery_band = c(-0.12, -0.08),
    strong_reclaim = 0.75,
    weak_close = 0.25,
    forward_sessions = c(1L, 3L, 5L)
  )
}

edl_ms01_forward_path_contract <- function() {
  list(
    study_id = "EDL_MS_01_RULE201_FORWARD_PATH_01",
    horizons = 0:10,
    display_horizons = c(1L, 2L, 3L, 4L, 5L, 10L),
    focal_categories = c(
      "TRIGGERED_PROXY__STRONG_RECLAIM",
      "TRIGGERED_PROXY__WEAK_CLOSE",
      "NEAR_MISS__STRONG_RECLAIM",
      "NEAR_MISS__WEAK_CLOSE"
    )
  )
}

edl_ms01_wide_atlas_contract <- function() {
  list(
    study_id = "EDL_MS_01_RULE201_WIDE_ATLAS_01",
    registry_size = 129L,
    core_stock_count = 88L,
    attention_stock_count = 16L,
    equity_etf_count = 15L,
    non_equity_etf_count = 10L,
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    threshold = -0.10,
    discovery_band = c(-0.12, -0.08),
    strong_reclaim = 0.75,
    weak_close = 0.25,
    horizons = 0:10,
    display_horizons = c(1L, 2L, 3L, 4L, 5L, 10L),
    focal_categories = c(
      "TRIGGERED_PROXY__STRONG_RECLAIM",
      "TRIGGERED_PROXY__WEAK_CLOSE",
      "NEAR_MISS__STRONG_RECLAIM",
      "NEAR_MISS__WEAK_CLOSE"
    )
  )
}

edl_ms01_validate_wide_atlas_contract <- function(
  contract = edl_ms01_wide_atlas_contract()
) {
  expected_counts <- c(129L, 88L, 16L, 15L, 10L)
  observed_counts <- as.integer(c(
    contract$registry_size,
    contract$core_stock_count,
    contract$attention_stock_count,
    contract$equity_etf_count,
    contract$non_equity_etf_count
  ))
  if (!identical(observed_counts, expected_counts)) {
    edl_ms01_stop("The frozen wide-atlas cohort counts changed.")
  }
  if (!identical(contract$analysis_start, as.Date("2018-01-02")) ||
      !identical(contract$analysis_end, as.Date("2023-12-29"))) {
    edl_ms01_stop("The wide-atlas TRAIN window changed.")
  }
  if (!identical(contract$threshold, -0.10) ||
      !identical(contract$discovery_band, c(-0.12, -0.08)) ||
      !identical(contract$strong_reclaim, 0.75) ||
      !identical(contract$weak_close, 0.25)) {
    edl_ms01_stop("The Rule 201 proxy or reclaim definitions changed.")
  }
  if (!identical(contract$horizons, 0:10) ||
      !identical(contract$display_horizons, c(1L, 2L, 3L, 4L, 5L, 10L))) {
    edl_ms01_stop("The wide-atlas forward-path horizons changed.")
  }
  contract
}

edl_ms01_validate_wide_atlas_registry <- function(
  registry,
  contract = edl_ms01_wide_atlas_contract()
) {
  contract <- edl_ms01_validate_wide_atlas_contract(contract)
  required <- c(
    "atlas_order", "symbol", "atlas_cohort", "sector", "instrument_type",
    "sector_balance_eligible"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    edl_ms01_stop(paste("Missing registry columns:", paste(missing, collapse = ", ")))
  }
  if (nrow(registry) != contract$registry_size || anyDuplicated(registry$symbol)) {
    edl_ms01_stop("The wide-atlas registry size or symbol uniqueness changed.")
  }
  expected_cohorts <- c(
    GICS_CORE = contract$core_stock_count,
    ATTENTION_SUPPLEMENT = contract$attention_stock_count,
    EQUITY_ETF_CONTROL = contract$equity_etf_count,
    NON_EQUITY_CONTROL = contract$non_equity_etf_count
  )
  cohort_counts <- table(factor(registry$atlas_cohort, levels = names(expected_cohorts)))
  if (!identical(as.integer(cohort_counts), as.integer(expected_cohorts))) {
    edl_ms01_stop("The wide-atlas cohort membership counts changed.")
  }
  core <- registry$atlas_cohort == "GICS_CORE"
  if (!all(registry$instrument_type[core] == "Stock") ||
      !all(as.character(registry$sector_balance_eligible[core]) %in% c("TRUE", "T", "1"))) {
    edl_ms01_stop("The 88-stock equal-sector core contract changed.")
  }
  registry[order(as.integer(registry$atlas_order)), , drop = FALSE]
}

edl_ms01_wide_atlas_group <- function(atlas_cohort) {
  labels <- c(
    GICS_CORE = "Core stocks (88)",
    ATTENTION_SUPPLEMENT = "Attention stocks (16)",
    EQUITY_ETF_CONTROL = "Equity ETFs (15)",
    NON_EQUITY_CONTROL = "Non-equity ETFs (10)"
  )
  out <- unname(labels[as.character(atlas_cohort)])
  if (any(is.na(out))) edl_ms01_stop("Unknown wide-atlas cohort encountered.")
  out
}

edl_ms01_build_wide_atlas_ledger <- function(
  bars,
  registry,
  wide_contract = edl_ms01_wide_atlas_contract(),
  base_contract = edl_ms01_contract(),
  path_contract = edl_ms01_forward_path_contract()
) {
  wide_contract <- edl_ms01_validate_wide_atlas_contract(wide_contract)
  registry <- edl_ms01_validate_wide_atlas_registry(registry, wide_contract)
  base_contract <- edl_ms01_validate_contract(base_contract)
  path_contract <- edl_ms01_validate_forward_path_contract(path_contract)
  if (!identical(wide_contract$threshold, base_contract$threshold) ||
      !identical(wide_contract$discovery_band, base_contract$discovery_band) ||
      !identical(wide_contract$strong_reclaim, base_contract$strong_reclaim) ||
      !identical(wide_contract$weak_close, base_contract$weak_close) ||
      !identical(wide_contract$horizons, path_contract$horizons)) {
    edl_ms01_stop("The pilot and wide-atlas definitions are no longer identical.")
  }
  bars$session_date <- as.Date(bars$session_date)
  bars <- bars[
    bars$symbol %in% registry$symbol &
      bars$session_date >= wide_contract$analysis_start &
      bars$session_date <= wide_contract$analysis_end,
    , drop = FALSE
  ]
  missing_symbols <- setdiff(registry$symbol, unique(as.character(bars$symbol)))
  if (length(missing_symbols)) {
    edl_ms01_stop(paste(
      "Missing registry symbols in the frozen bar packet:",
      paste(missing_symbols, collapse = ", ")
    ))
  }
  rows <- lapply(registry$symbol, function(symbol) {
    x <- bars[as.character(bars$symbol) == symbol, , drop = FALSE]
    x <- edl_ms01_build_symbol_ledger(x, base_contract)
    edl_ms01_add_forward_paths(x, path_contract)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  match_index <- match(out$symbol, registry$symbol)
  out$atlas_order <- as.integer(registry$atlas_order[match_index])
  out$atlas_cohort <- as.character(registry$atlas_cohort[match_index])
  out$atlas_group <- edl_ms01_wide_atlas_group(out$atlas_cohort)
  out$sector <- as.character(registry$sector[match_index])
  out$instrument_type <- as.character(registry$instrument_type[match_index])
  out[order(out$atlas_order, out$session_date), , drop = FALSE]
}

edl_ms01_equal_symbol_path_summary <- function(path_long) {
  required <- c("atlas_group", "symbol", "event_category", "horizon", "open_log_return")
  missing <- setdiff(required, names(path_long))
  if (length(missing)) {
    edl_ms01_stop(paste("Missing equal-symbol columns:", paste(missing, collapse = ", ")))
  }
  symbol_keys <- unique(path_long[c(
    "atlas_group", "symbol", "event_category", "horizon"
  )])
  symbol_rows <- lapply(seq_len(nrow(symbol_keys)), function(i) {
    key <- symbol_keys[i, ]
    selected <- path_long$atlas_group == key$atlas_group &
      path_long$symbol == key$symbol &
      path_long$event_category == key$event_category &
      path_long$horizon == key$horizon
    x <- path_long$open_log_return[selected]
    data.frame(
      atlas_group = key$atlas_group,
      symbol = key$symbol,
      event_category = key$event_category,
      horizon = as.integer(key$horizon),
      event_n = length(x),
      symbol_median_open_log_return = stats::median(x),
      stringsAsFactors = FALSE
    )
  })
  symbol_paths <- do.call(rbind, symbol_rows)
  keys <- unique(symbol_paths[c("atlas_group", "event_category", "horizon")])
  summary_rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    selected <- symbol_paths$atlas_group == key$atlas_group &
      symbol_paths$event_category == key$event_category &
      symbol_paths$horizon == key$horizon
    x <- symbol_paths$symbol_median_open_log_return[selected]
    data.frame(
      atlas_group = key$atlas_group,
      event_category = key$event_category,
      horizon = as.integer(key$horizon),
      symbol_n = length(x),
      equal_symbol_mean = mean(x),
      equal_symbol_median = stats::median(x),
      q25_symbol_median = as.numeric(stats::quantile(x, 0.25, names = FALSE)),
      q75_symbol_median = as.numeric(stats::quantile(x, 0.75, names = FALSE)),
      stringsAsFactors = FALSE
    )
  })
  list(
    symbol_paths = symbol_paths,
    summary = do.call(rbind, summary_rows)
  )
}

edl_ms01_validate_forward_path_contract <- function(
  contract = edl_ms01_forward_path_contract()
) {
  if (!identical(contract$horizons, 0:10)) {
    edl_ms01_stop("The forward-path anatomy horizons changed.")
  }
  if (!identical(contract$display_horizons, c(1L, 2L, 3L, 4L, 5L, 10L))) {
    edl_ms01_stop("The displayed forward-path horizons changed.")
  }
  expected_categories <- c(
    "TRIGGERED_PROXY__STRONG_RECLAIM",
    "TRIGGERED_PROXY__WEAK_CLOSE",
    "NEAR_MISS__STRONG_RECLAIM",
    "NEAR_MISS__WEAK_CLOSE"
  )
  if (!identical(contract$focal_categories, expected_categories)) {
    edl_ms01_stop("The four focal threshold/reclaim categories changed.")
  }
  contract
}

edl_ms01_validate_contract <- function(contract = edl_ms01_contract()) {
  expected <- c(
    "TSLA", "AMD", "NVDA",
    "GME", "AMC", "CVNA", "PLTR", "COIN", "SOFI", "RIVN"
  )
  if (!identical(contract$symbols, expected)) {
    edl_ms01_stop("The frozen discovery basket changed.")
  }
  if (!identical(contract$threshold, -0.10) ||
      !identical(contract$discovery_band, c(-0.12, -0.08))) {
    edl_ms01_stop("The fixed Rule 201 proxy threshold or discovery band changed.")
  }
  if (!identical(contract$forward_sessions, c(1L, 3L, 5L))) {
    edl_ms01_stop("The descriptive forward horizons changed.")
  }
  contract
}

edl_ms01_prior_median <- function(x, window = 20L) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (length(x) <= window) return(out)
  for (i in seq.int(window + 1L, length(x))) {
    prior <- x[seq.int(i - window, i - 1L)]
    out[[i]] <- if (all(is.finite(prior))) stats::median(prior) else NA_real_
  }
  out
}

edl_ms01_lead <- function(x, n = 1L) {
  n <- as.integer(n)
  if (n < 0L) edl_ms01_stop("Lead length must be non-negative.")
  if (n == 0L) return(x)
  c(x[seq.int(n + 1L, length(x))], rep(NA, n))
}

edl_ms01_build_symbol_ledger <- function(bars, contract = edl_ms01_contract()) {
  contract <- edl_ms01_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    edl_ms01_stop(paste("Missing required columns:", paste(missing, collapse = ", ")))
  }
  symbols <- unique(as.character(bars$symbol))
  if (length(symbols) != 1L) edl_ms01_stop("Build one symbol ledger at a time.")
  out <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  out$session_date <- as.Date(out$session_date)
  if (anyDuplicated(out$session_date)) edl_ms01_stop("Duplicate sessions detected.")
  numeric_columns <- c("open", "high", "low", "close", "volume")
  if (any(!vapply(out[numeric_columns], function(x) all(is.finite(x)), logical(1)))) {
    edl_ms01_stop("Non-finite OHLCV values detected.")
  }
  if (any(out$high < pmax(out$open, out$close, out$low)) ||
      any(out$low > pmin(out$open, out$close, out$high))) {
    edl_ms01_stop("Invalid OHLC ordering detected.")
  }

  out$row_index <- seq_len(nrow(out))
  out$prior_close <- c(NA_real_, head(out$close, -1L))
  out$minimum_intraday_return <- out$low / out$prior_close - 1
  daily_range <- out$high - out$low
  out$close_location_value <- ifelse(
    daily_range > 0, (out$close - out$low) / daily_range, NA_real_
  )
  out$dollar_volume <- out$close * out$volume
  out$prior_20_median_dollar_volume <- edl_ms01_prior_median(out$dollar_volume, 20L)
  out$abnormal_dollar_volume <-
    out$dollar_volume / out$prior_20_median_dollar_volume
  out$rule201_proxy_trigger <- is.finite(out$minimum_intraday_return) &
    out$minimum_intraday_return <= contract$threshold
  out$inside_discovery_band <- is.finite(out$minimum_intraday_return) &
    out$minimum_intraday_return >= contract$discovery_band[[1L]] &
    out$minimum_intraday_return <= contract$discovery_band[[2L]]
  out$threshold_group <- ifelse(
    out$rule201_proxy_trigger, "TRIGGERED_PROXY", "NEAR_MISS"
  )
  out$reclaim_group <- ifelse(
    out$close_location_value >= contract$strong_reclaim, "STRONG_RECLAIM",
    ifelse(out$close_location_value <= contract$weak_close, "WEAK_CLOSE", "MIDDLE_CLOSE")
  )
  out$event_category <- paste(out$threshold_group, out$reclaim_group, sep = "__")

  out$entry_session <- edl_ms01_lead(out$session_date, 1L)
  out$entry_open <- edl_ms01_lead(out$open, 1L)
  for (h in contract$forward_sessions) {
    exit_open <- edl_ms01_lead(out$open, h + 1L)
    exit_session <- edl_ms01_lead(out$session_date, h + 1L)
    out[[paste0("exit_", h, "_session")]] <- exit_session
    out[[paste0("forward_", h, "_open_log_return")]] <- log(exit_open / out$entry_open)
  }
  out
}

edl_ms01_build_ledger <- function(bars, contract = edl_ms01_contract()) {
  contract <- edl_ms01_validate_contract(contract)
  rows <- lapply(contract$symbols, function(symbol) {
    x <- bars[as.character(bars$symbol) == symbol, , drop = FALSE]
    if (!nrow(x)) edl_ms01_stop(paste("Missing frozen symbol", symbol))
    edl_ms01_build_symbol_ledger(x, contract)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

edl_ms01_add_forward_paths <- function(
  ledger,
  path_contract = edl_ms01_forward_path_contract()
) {
  path_contract <- edl_ms01_validate_forward_path_contract(path_contract)
  required <- c("symbol", "session_date", "open", "entry_open")
  missing <- setdiff(required, names(ledger))
  if (length(missing)) {
    edl_ms01_stop(paste("Missing forward-path columns:", paste(missing, collapse = ", ")))
  }
  rows <- lapply(unique(as.character(ledger$symbol)), function(symbol) {
    x <- ledger[as.character(ledger$symbol) == symbol, , drop = FALSE]
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    if (anyDuplicated(as.Date(x$session_date))) {
      edl_ms01_stop(paste("Duplicate sessions detected for", symbol))
    }
    for (h in path_contract$horizons) {
      exit_open <- edl_ms01_lead(x$open, h + 1L)
      exit_session <- edl_ms01_lead(x$session_date, h + 1L)
      x[[paste0("path_exit_", h, "_session")]] <- exit_session
      x[[paste0("path_", h, "_open_log_return")]] <-
        log(exit_open / x$entry_open)
    }
    x
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

edl_ms01_forward_path_long <- function(
  events,
  path_contract = edl_ms01_forward_path_contract()
) {
  path_contract <- edl_ms01_validate_forward_path_contract(path_contract)
  required <- c("symbol", "session_date", "event_category")
  missing <- setdiff(required, names(events))
  if (length(missing)) {
    edl_ms01_stop(paste("Missing event columns:", paste(missing, collapse = ", ")))
  }
  events <- events[
    events$event_category %in% path_contract$focal_categories, , drop = FALSE
  ]
  rows <- lapply(path_contract$horizons, function(h) {
    return_column <- paste0("path_", h, "_open_log_return")
    if (!return_column %in% names(events)) {
      edl_ms01_stop(paste("Missing forward-path outcome", return_column))
    }
    data.frame(
      symbol = as.character(events$symbol),
      session_date = as.Date(events$session_date),
      event_category = as.character(events$event_category),
      horizon = as.integer(h),
      open_log_return = as.numeric(events[[return_column]]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[is.finite(out$open_log_return), , drop = FALSE]
  rownames(out) <- NULL
  out
}

edl_ms01_summarize_forward_paths <- function(
  path_long,
  path_contract = edl_ms01_forward_path_contract()
) {
  path_contract <- edl_ms01_validate_forward_path_contract(path_contract)
  required <- c("event_category", "horizon", "open_log_return")
  missing <- setdiff(required, names(path_long))
  if (length(missing)) {
    edl_ms01_stop(paste("Missing path-summary columns:", paste(missing, collapse = ", ")))
  }
  keys <- unique(path_long[c("event_category", "horizon")])
  keys <- keys[order(match(keys$event_category, path_contract$focal_categories), keys$horizon), ]
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    category <- keys$event_category[[i]]
    horizon <- keys$horizon[[i]]
    x <- path_long$open_log_return[
      path_long$event_category == category & path_long$horizon == horizon
    ]
    data.frame(
      event_category = category,
      horizon = as.integer(horizon),
      n = length(x),
      mean_open_log_return = mean(x),
      median_open_log_return = stats::median(x),
      q25_open_log_return = as.numeric(stats::quantile(x, 0.25, names = FALSE)),
      q75_open_log_return = as.numeric(stats::quantile(x, 0.75, names = FALSE)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

edl_ms01_select_event_tapes <- function(events) {
  targets <- c(
    "TRIGGERED_PROXY__STRONG_RECLAIM",
    "TRIGGERED_PROXY__WEAK_CLOSE",
    "NEAR_MISS__STRONG_RECLAIM",
    "NEAR_MISS__WEAK_CLOSE"
  )
  selected <- lapply(targets, function(target) {
    x <- events[
      events$event_category == target &
        is.finite(events$forward_5_open_log_return), , drop = FALSE
    ]
    x <- x[order(x$session_date, x$symbol), , drop = FALSE]
    if (!nrow(x)) edl_ms01_stop(paste("No event available for", target))
    x[1L, , drop = FALSE]
  })
  out <- do.call(rbind, selected)
  rownames(out) <- NULL
  out$tape_order <- seq_len(nrow(out))
  out
}
