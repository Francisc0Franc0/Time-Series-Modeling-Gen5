# HYP-MOM-01.1 Stock Atlas 02 breadth-extension helpers.

hyp_mom011_breadth_contract <- function() {
  list(
    atlas_id = "HYP-MOM-01.1-STOCK_ATLAS_02_BREADTH_EXTENSION",
    evidence_stage = "DISCOVERY_REUSED_WINDOW",
    registry_rows = 100L,
    core_rows = 75L,
    attention_rows = 25L,
    required_sector_count = 11L,
    minimum_prior_sessions = 220L,
    bootstrap_draws = 2000L,
    bootstrap_seed = 20260804L,
    source_registry = paste0(
      "literature_studies/registries/",
      "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"
    )
  )
}

hyp_mom011_breadth_validate_contract <- function(
  contract = hyp_mom011_breadth_contract()
) {
  frozen <- hyp_mom011_breadth_contract()
  if (!identical(names(contract), names(frozen))) {
    hyp_mom011_stop("Frozen breadth-extension field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    hyp_mom011_stop(paste(
      "Frozen breadth-extension contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

hyp_mom011_breadth_validate_registry <- function(
  registry,
  original_symbols,
  contract = hyp_mom011_breadth_contract()
) {
  contract <- hyp_mom011_breadth_validate_contract(contract)
  required <- c(
    "instance_id", "symbol", "cohort", "sector", "selection_basis",
    "source_id", "source_date"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    hyp_mom011_stop(paste(
      "Breadth registry missing columns:", paste(missing, collapse = ", ")
    ))
  }
  x <- as.data.frame(registry, stringsAsFactors = FALSE)
  if (nrow(x) != contract$registry_rows) {
    hyp_mom011_stop("Breadth registry must contain exactly 100 rows.")
  }
  if (any(!nzchar(x$instance_id)) || anyDuplicated(x$instance_id)) {
    hyp_mom011_stop("Breadth instance IDs must be non-empty and unique.")
  }
  if (any(!nzchar(x$symbol)) || anyDuplicated(x$symbol)) {
    hyp_mom011_stop("Breadth symbols must be non-empty and unique.")
  }
  counts <- table(x$cohort)
  if (!identical(unname(counts[["DIVERSIFIED_CORE"]]), contract$core_rows) ||
      !identical(unname(counts[["RETAIL_ATTENTION_2020"]]), contract$attention_rows)) {
    hyp_mom011_stop("Breadth cohort counts must be 75 core and 25 attention.")
  }
  if (length(unique(x$sector)) != contract$required_sector_count) {
    hyp_mom011_stop("Breadth registry must cover eleven sectors.")
  }
  if (length(intersect(x$symbol, as.character(original_symbols)))) {
    hyp_mom011_stop("Breadth registry overlaps the original 22 assets.")
  }
  source_dates <- as.Date(x$source_date)
  if (anyNA(source_dates) || any(source_dates > as.Date("2020-12-31"))) {
    hyp_mom011_stop("Breadth registry contains a source date after 2020.")
  }
  x
}

hyp_mom011_breadth_coverage <- function(
  bars,
  registry,
  spy_sessions,
  parent_contract = hyp_mom011_contract(),
  breadth_contract = hyp_mom011_breadth_contract()
) {
  parent_contract <- hyp_mom011_validate_contract(parent_contract)
  breadth_contract <- hyp_mom011_breadth_validate_contract(breadth_contract)
  x <- as.data.frame(bars, stringsAsFactors = FALSE)
  x$session_date <- as.Date(x$session_date)
  required_values <- c("open", "high", "low", "close", "volume")
  missing_values <- setdiff(required_values, names(x))
  if (length(missing_values)) {
    hyp_mom011_stop(paste(
      "Breadth coverage bars missing columns:",
      paste(missing_values, collapse = ", ")
    ))
  }
  expected <- as.Date(spy_sessions)
  expected <- expected[
    expected >= parent_contract$discovery_start &
      expected <= parent_contract$discovery_end
  ]
  if (!length(expected)) hyp_mom011_stop("SPY discovery calendar is empty.")

  rows <- lapply(seq_len(nrow(registry)), function(i) {
    reg <- registry[i, , drop = FALSE]
    asset <- x[x$symbol == reg$symbol, , drop = FALSE]
    observed <- sort(unique(asset$session_date))
    discovery <- observed[
      observed >= parent_contract$discovery_start &
        observed <= parent_contract$discovery_end
    ]
    prior_count <- sum(observed < parent_contract$discovery_start)
    missing <- setdiff(expected, discovery)
    extra <- setdiff(discovery, expected)
    full_discovery <- !length(missing) && !length(extra)
    enough_history <- prior_count >= breadth_contract$minimum_prior_sessions
    values <- as.matrix(asset[required_values])
    valid_ohlcv <- nrow(asset) > 0L && all(is.finite(values)) && all(values > 0)
    eligible <- nrow(asset) > 0L && full_discovery && enough_history && valid_ohlcv
    status <- if (!nrow(asset)) {
      "NO_BARS"
    } else if (!valid_ohlcv) {
      "INVALID_OHLCV"
    } else if (!full_discovery && !enough_history) {
      "DISCOVERY_AND_HISTORY_INCOMPLETE"
    } else if (!full_discovery) {
      "DISCOVERY_INCOMPLETE"
    } else if (!enough_history) {
      "HISTORY_INCOMPLETE"
    } else {
      "ELIGIBLE"
    }
    data.frame(
      instance_id = reg$instance_id,
      symbol = reg$symbol,
      cohort = reg$cohort,
      sector = reg$sector,
      first_observed = if (length(observed)) min(observed) else as.Date(NA),
      last_observed = if (length(observed)) max(observed) else as.Date(NA),
      prior_sessions = prior_count,
      discovery_observed_sessions = length(discovery),
      discovery_expected_sessions = length(expected),
      discovery_missing_sessions = length(missing),
      discovery_extra_sessions = length(extra),
      valid_ohlcv = valid_ohlcv,
      analysis_eligible = eligible,
      coverage_status = status,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

hyp_mom011_breadth_panel_summary <- function(asset_summary, trades, panel_id) {
  assets <- as.data.frame(asset_summary, stringsAsFactors = FALSE)
  x <- as.data.frame(trades, stringsAsFactors = FALSE)
  data.frame(
    panel_id = panel_id,
    asset_count = nrow(assets),
    executed_trade_count = nrow(x),
    mean_primary_trade_return = mean(x$primary_trade_return),
    median_primary_trade_return = stats::median(x$primary_trade_return),
    primary_hit_rate = mean(x$primary_trade_return > 0),
    mean_winning_trade_return = mean(x$primary_trade_return[x$primary_trade_return > 0]),
    mean_nonpositive_trade_return = mean(x$primary_trade_return[x$primary_trade_return <= 0]),
    p05_primary_trade_return = as.numeric(stats::quantile(x$primary_trade_return, 0.05)),
    p95_primary_trade_return = as.numeric(stats::quantile(x$primary_trade_return, 0.95)),
    mean_asset_primary_return = mean(assets$primary_compounded_return),
    median_asset_primary_return = stats::median(assets$primary_compounded_return),
    assets_positive_primary = sum(assets$primary_compounded_return > 0),
    assets_positive_stress = sum(assets$stress_compounded_return > 0),
    assets_beating_buy_hold = sum(assets$excess_vs_buy_hold > 0),
    median_random_percentile = stats::median(assets$observed_random_percentile),
    assets_random_percentile_above_50 = sum(assets$observed_random_percentile > 0.5),
    assets_random_percentile_above_80 = sum(assets$observed_random_percentile >= 0.8),
    worst_asset_maximum_drawdown = min(assets$maximum_drawdown),
    stringsAsFactors = FALSE
  )
}

hyp_mom011_breadth_cohort_summary <- function(asset_summary, trades) {
  groups <- unique(as.character(asset_summary$cohort))
  do.call(rbind, lapply(groups, function(group) {
    assets <- asset_summary[asset_summary$cohort == group, , drop = FALSE]
    x <- trades[trades$cohort == group, , drop = FALSE]
    cbind(
      data.frame(cohort = group, stringsAsFactors = FALSE),
      hyp_mom011_breadth_panel_summary(assets, x, "ATLAS_02")[-1L]
    )
  }))
}
