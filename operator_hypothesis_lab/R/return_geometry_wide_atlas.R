rgwa_stop <- function(message) {
  stop(paste0("[RETURN-GEOMETRY-WIDE-ATLAS] ", message), call. = FALSE)
}

rgwa_contract <- function() {
  list(
    atlas_id = "RETURN_GEOMETRY_WIDE_ATLAS_01",
    query_start = as.Date("2016-01-04"),
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    as_of_timestamp = "2026-08-27 17:30:00 America/New_York",
    horizons = c(20L, 25L, 30L, 35L, 40L, 50L, 75L, 100L),
    expected_assets = 129L,
    expected_core_assets = 88L,
    expected_sectors = 11L,
    assets_per_sector = 8L,
    expected_attention_assets = 16L,
    expected_equity_etfs = 15L,
    expected_non_equity_controls = 10L,
    er_window = 20L,
    er_cutoff = 0.30,
    atr_length = 14L,
    atr_percentile_lookback = 252L,
    atr_low_enter = 0.30,
    atr_low_exit = 0.40,
    atr_high_exit = 0.60,
    atr_high_enter = 0.70,
    minimum_branch_observations = 30L,
    minimum_total_sessions = 250L
  )
}

rgwa_expected_symbols <- function() {
  c(
    "GOOGL", "META", "NFLX", "DIS", "CMCSA", "T", "VZ", "TMUS",
    "AMZN", "TSLA", "HD", "MCD", "NKE", "SBUX", "LOW", "BKNG",
    "PG", "KO", "PEP", "WMT", "COST", "PM", "MO", "CL",
    "XOM", "CVX", "COP", "SLB", "EOG", "MPC", "OXY", "PSX",
    "JPM", "BAC", "WFC", "GS", "MS", "BLK", "C", "AXP",
    "UNH", "JNJ", "LLY", "PFE", "MRK", "ABBV", "TMO", "ABT",
    "CAT", "BA", "HON", "UNP", "UPS", "GE", "RTX", "DE",
    "AAPL", "MSFT", "NVDA", "AMD", "AVGO", "ORCL", "CRM", "IBM",
    "APD", "SHW", "ECL", "NEM", "FCX", "NUE", "PPG", "VMC",
    "AMT", "PLD", "CCI", "EQIX", "SPG", "O", "PSA", "WELL",
    "NEE", "DUK", "SO", "D", "AEP", "EXC", "SRE", "XEL",
    "GME", "AMC", "KOSS", "BB", "NOK", "CVNA", "BYND", "ROKU",
    "MSTR", "PLTR", "COIN", "SOFI", "HOOD", "RIVN", "LCID", "MARA",
    "SPY", "QQQ", "IWM", "DIA", "SMH", "XLF", "XLK", "XLE", "XLY",
    "XLP", "XLV", "XLI", "XLU", "XLB", "XLRE", "TLT", "IEF", "SHY",
    "GLD", "SLV", "USO", "UNG", "UUP", "FXE", "DBA"
  )
}

rgwa_validate_registry <- function(registry, contract = rgwa_contract()) {
  required <- c(
    "atlas_order", "symbol", "atlas_cohort", "sector", "instrument_type",
    "sector_balance_eligible", "selection_role", "selection_basis"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) rgwa_stop(paste("Registry is missing:", paste(missing, collapse = ", ")))
  x <- registry[required]
  x$atlas_order <- as.integer(x$atlas_order)
  x$symbol <- as.character(x$symbol)
  x$atlas_cohort <- as.character(x$atlas_cohort)
  x$sector <- as.character(x$sector)
  x$instrument_type <- as.character(x$instrument_type)
  x$sector_balance_eligible <- as.logical(x$sector_balance_eligible)
  x$selection_role <- as.character(x$selection_role)
  x$selection_basis <- as.character(x$selection_basis)
  x <- x[order(x$atlas_order), , drop = FALSE]
  rownames(x) <- NULL

  if (nrow(x) != contract$expected_assets || anyDuplicated(x$symbol) ||
      !identical(x$atlas_order, seq_len(contract$expected_assets)) ||
      !identical(x$symbol, rgwa_expected_symbols())) {
    rgwa_stop("Frozen atlas identities or ordering changed.")
  }
  cohort_counts <- table(x$atlas_cohort)
  expected_cohorts <- c(
    ATTENTION_SUPPLEMENT = contract$expected_attention_assets,
    EQUITY_ETF_CONTROL = contract$expected_equity_etfs,
    GICS_CORE = contract$expected_core_assets,
    NON_EQUITY_CONTROL = contract$expected_non_equity_controls
  )
  if (!identical(names(cohort_counts), names(expected_cohorts)) ||
      !identical(as.integer(cohort_counts), as.integer(expected_cohorts))) {
    rgwa_stop("Frozen cohort dimensions changed.")
  }
  core <- x[x$atlas_cohort == "GICS_CORE", , drop = FALSE]
  if (!all(core$sector_balance_eligible) || length(unique(core$sector)) != contract$expected_sectors ||
      any(table(core$sector) != contract$assets_per_sector) || any(x$sector_balance_eligible != (x$atlas_cohort == "GICS_CORE"))) {
    rgwa_stop("The equal-sector core must remain eight assets in each of 11 sectors.")
  }
  x
}

rgwa_build_ledger <- function(bars, symbol, contract = rgwa_contract()) {
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) rgwa_stop(paste("Bars are missing:", paste(missing, collapse = ", ")))
  x <- bars[as.character(bars$symbol) == symbol, required, drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  x <- x[order(x$session_date), , drop = FALSE]
  if (nrow(x) < contract$minimum_total_sessions || anyDuplicated(x$session_date) ||
      any(diff(x$session_date) <= 0)) {
    rgwa_stop(paste(symbol, "has insufficient, duplicated, or unordered bars."))
  }
  numeric_fields <- c("open", "high", "low", "close", "volume")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  if (any(!is.finite(as.matrix(x[numeric_fields]))) || any(x$close <= 0) ||
      !all(as.logical(x$adjusted)) || !all(x$timeframe == "1D")) {
    rgwa_stop(paste(symbol, "bars violate the adjusted-daily contract."))
  }
  if (max(x$session_date) < contract$analysis_end) {
    rgwa_stop(paste(symbol, "does not reach the frozen analysis end."))
  }
  x <- x[x$session_date >= contract$query_start & x$session_date <= contract$analysis_end, , drop = FALSE]
  log_close <- log(x$close)
  signed_er <- tsder_signed_efficiency_ratio(log_close, contract$er_window)
  tr <- hreg_true_range(x$high, x$low, x$close)
  atr <- hreg_wilder_atr(tr, contract$atr_length)
  atr_percent <- 100 * atr / x$close
  atr_percentile <- hreg_rolling_percentile(atr_percent, contract$atr_percentile_lookback)
  atr_state <- hreg_hysteretic_state(
    atr_percentile, contract$atr_low_enter, contract$atr_low_exit,
    contract$atr_high_exit, contract$atr_high_enter
  )
  data.frame(
    symbol = symbol,
    session_date = x$session_date,
    open = x$open, high = x$high, low = x$low, close = x$close,
    log_close = log_close,
    signed_er20 = signed_er,
    er20 = abs(signed_er),
    er20_state = ifelse(
      is.na(signed_er), NA_character_,
      ifelse(abs(signed_er) >= contract$er_cutoff, "GREEN_TRENDING", "RED_SIDEWAYS")
    ),
    signed_er20_state = tsder_classify_direction(signed_er, contract$er_cutoff),
    atr_percent = atr_percent,
    atr_percentile = atr_percentile,
    atrp_state = atr_state,
    stringsAsFactors = FALSE
  )
}

rgwa_measure_asset <- function(ledger, contract = rgwa_contract()) {
  specs <- oarga_condition_specs()
  rows <- list()
  index <- 0L
  for (prior_sessions in contract$horizons) {
    for (forward_sessions in contract$horizons) {
      surface <- oarga_construct_surface(ledger, prior_sessions, forward_sessions, contract)
      surface <- surface[
        is.finite(surface$prior_cumulative_log_return) &
          is.finite(surface$forward_cumulative_log_return),
        , drop = FALSE
      ]
      for (condition in names(specs)) {
        spec <- specs[[condition]]
        condition_surface <- if (is.null(spec$column)) {
          surface
        } else {
          surface[!is.na(surface[[spec$column]]), , drop = FALSE]
        }
        for (state in spec$states) {
          index <- index + 1L
          row <- oarga_describe_sign(
            condition_surface, state, spec$column, contract$minimum_branch_observations
          )
          row$symbol <- ledger$symbol[[1L]]
          row$condition <- condition
          row$prior_sessions <- prior_sessions
          row$forward_sessions <- forward_sessions
          rows[[index]] <- row
        }
      }
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

rgwa_summarize_cells <- function(cells, grouping_fields) {
  keys <- interaction(cells[grouping_fields], drop = TRUE, lex.order = TRUE)
  groups <- split(cells, keys)
  summarize <- function(x) {
    described <- is.finite(x$negative_pearson_correlation)
    positive_described <- is.finite(x$positive_pearson_correlation)
    data.frame(
      assets = nrow(x),
      described_negative_assets = sum(described),
      described_positive_assets = sum(positive_described),
      median_negative_pearson = if (any(described)) stats::median(x$negative_pearson_correlation[described]) else NA_real_,
      mean_negative_pearson = if (any(described)) mean(x$negative_pearson_correlation[described]) else NA_real_,
      negative_asset_fraction = if (any(described)) mean(x$negative_pearson_correlation[described] < 0) else NA_real_,
      strong_negative_asset_fraction = if (any(described)) mean(x$negative_pearson_correlation[described] <= -0.10) else NA_real_,
      median_positive_pearson = if (any(positive_described)) stats::median(x$positive_pearson_correlation[positive_described]) else NA_real_,
      median_sign_difference = if (any(described & positive_described)) stats::median(x$positive_minus_negative_pearson[described & positive_described]) else NA_real_,
      median_negative_observations = if (any(described)) stats::median(x$negative_observations[described]) else NA_real_,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, lapply(groups, function(x) cbind(x[1L, grouping_fields, drop = FALSE], summarize(x))))
  rownames(out) <- NULL
  out
}

rgwa_sector_balanced_summary <- function(sector_summary) {
  grouping <- c("condition", "state", "prior_sessions", "forward_sessions")
  keys <- interaction(sector_summary[grouping], drop = TRUE, lex.order = TRUE)
  groups <- split(sector_summary, keys)
  out <- do.call(rbind, lapply(groups, function(x) {
    valid <- is.finite(x$median_negative_pearson)
    data.frame(
      x[1L, grouping, drop = FALSE],
      sectors = nrow(x),
      described_sectors = sum(valid),
      equal_sector_median_negative_pearson = if (any(valid)) stats::median(x$median_negative_pearson[valid]) else NA_real_,
      equal_sector_mean_negative_pearson = if (any(valid)) mean(x$median_negative_pearson[valid]) else NA_real_,
      negative_sector_fraction = if (any(valid)) mean(x$median_negative_pearson[valid] < 0) else NA_real_,
      strong_negative_sector_fraction = if (any(valid)) mean(x$median_negative_pearson[valid] <= -0.10) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}
