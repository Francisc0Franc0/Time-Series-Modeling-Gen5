# Frozen LIT-IMOM-01.2 30-minute path-quality forecast helpers.
# Source the LIT-MOM-01.5 helper and the isolated 30-minute provider helper first.

g5_imom012_stop <- function(message) stop(paste0("[LIT-IMOM-01.2] ", message), call. = FALSE)

g5_imom012_schema_version <- function() "gen5_lit_imom_01_2_v1"

g5_imom012_contract <- function() {
  list(
    literature_id = "LIT-IMOM-01.2",
    descriptive_name = "30-Minute Path-Quality Incremental Forecast Comparison",
    design_as_of_timestamp = "2026-08-21 17:30:00 America/New_York",
    cache_as_of_timestamp = "2026-08-13 17:30:00 America/New_York",
    registry_relative_path = file.path(
      "operator_hypothesis_lab", "registries",
      "gen5_intraday_momentum_poc_registry.csv"
    ),
    registry_sha256 = "ED6A9C87E00E53970528F9638BFB972323D47AF86B273C19A13DC89DE9D7B4AF",
    registry_count = 26L,
    candidate_count = 22L,
    query_start = as.Date("2017-09-01"),
    query_end = as.Date("2023-12-29"),
    train_start = as.Date("2018-01-02"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    lookback_grid = c(5L, 10L, 25L, 60L, 120L, 250L),
    target_grid = c(5L, 10L, 25L, 60L),
    common_lookback_bars = 250L,
    common_target_bars = 60L,
    minimum_period_anchors = 9000L,
    model_ids = c(
      "B0_DRIFT", "B1_RAW", "Q2_PATH",
      "C0_CLOCK", "C1_CLOCK_RAW", "C2_CLOCK_PATH"
    ),
    contrast_ids = c("D10", "D21", "D20", "K10", "K21", "K20"),
    fdr_q = 0.10,
    bootstrap_count = 10000L,
    bootstrap_expected_sessions = 20,
    bootstrap_seed_base = 2026082160L,
    bootstrap_quantile_type = 7L,
    diagnostic_symbols = c("AMD", "TSLA", "SPY", "QQQ"),
    archive_exclusion_dates = as.Date(c(
      "2018-05-02", "2018-05-03", "2018-08-07", "2019-08-12", "2019-10-09",
      "2021-04-19", "2021-10-25", "2022-01-24", "2022-01-26", "2022-03-08"
    ))
  )
}

g5_imom012_validate_contract <- function(contract = g5_imom012_contract()) {
  frozen <- g5_imom012_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_imom012_stop("Frozen contract field set changed.")
  }
  same <- vapply(names(frozen), function(field) {
    identical(contract[[field]], frozen[[field]])
  }, logical(1))
  if (!all(same)) {
    g5_imom012_stop(paste("Frozen contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  }
  if (length(contract$lookback_grid) * length(contract$target_grid) != 24L) {
    g5_imom012_stop("Frozen surface must contain 24 cells.")
  }
  contract
}

g5_imom012_validate_registry <- function(registry, contract = g5_imom012_contract()) {
  contract <- g5_imom012_validate_contract(contract)
  required <- c("instance_id", "symbol", "sector", "asset_type", "panel_role", "source_registry")
  missing <- setdiff(required, names(registry))
  if (length(missing)) g5_imom012_stop(paste("Registry columns missing:", paste(missing, collapse = ", ")))
  x <- registry
  x$symbol <- toupper(trimws(as.character(x$symbol)))
  checks <- c(
    nrow(x) == contract$registry_count,
    !anyDuplicated(x$instance_id),
    !anyDuplicated(x$symbol),
    sum(x$panel_role == "diverse_stock_panel") == contract$candidate_count,
    identical(sort(x$symbol[x$panel_role != "diverse_stock_panel"]), sort(contract$diagnostic_symbols))
  )
  if (!all(checks)) g5_imom012_stop("Frozen 26-row registry structure changed.")
  x$order <- seq_len(nrow(x))
  x$analysis_id <- x$instance_id
  x$analysis_stratum <- ifelse(
    x$panel_role == "diverse_stock_panel", "DIVERSE_STOCK_CANDIDATE",
    ifelse(x$asset_type == "etf", "REFERENCE_ETF", "REMEMBERED_OPERATOR_CASE")
  )
  x$candidate_fdr <- x$panel_role == "diverse_stock_panel"
  x
}

g5_imom012_prepare_bars <- function(bars, registry, contract = g5_imom012_contract()) {
  contract <- g5_imom012_validate_contract(contract)
  required <- c(
    "symbol", "timestamp_utc", "session_date", "bar_time_et", "bar_slot",
    "open", "high", "low", "close", "volume", "provider", "feed",
    "timeframe", "adjustment", "as_of_timestamp"
  )
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_imom012_stop(paste("Bar columns missing:", paste(missing, collapse = ", ")))
  x <- bars[bars$symbol %in% registry$symbol, , drop = FALSE]
  x$symbol <- toupper(as.character(x$symbol))
  x$session_date <- as.Date(x$session_date)
  x <- imom30_apply_rth_calendar(x)
  x <- imom30_apply_archive_exclusions(x)
  x <- x[x$session_date >= contract$query_start & x$session_date <= contract$query_end, , drop = FALSE]
  x <- x[order(match(x$symbol, registry$symbol), x$timestamp_utc), , drop = FALSE]
  if (any(x$session_date >= contract$confirmation_start)) {
    g5_imom012_stop("Confirmation bars entered execution input.")
  }
  metadata_ok <- all(
    x$provider == "alpaca" & x$feed == "sip" & x$timeframe == "30Min" &
      x$adjustment == "all" & x$as_of_timestamp == contract$cache_as_of_timestamp
  )
  if (!metadata_ok) g5_imom012_stop("Frozen provider, feed, timeframe, adjustment, or cache timestamp changed.")
  x
}

g5_imom012_coverage_ledger <- function(bars, registry, contract = g5_imom012_contract()) {
  contract <- g5_imom012_validate_contract(contract)
  reference <- bars[
    bars$symbol == "SPY" & bars$session_date >= contract$train_start &
      bars$session_date <= contract$development_end, , drop = FALSE
  ]
  train_reference <- as.numeric(reference$timestamp_utc[
    reference$session_date >= contract$train_start & reference$session_date <= contract$train_end
  ])
  development_reference <- as.numeric(reference$timestamp_utc[
    reference$session_date >= contract$development_start & reference$session_date <= contract$development_end
  ])
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    identity <- registry[i, , drop = FALSE]
    x <- bars[bars$symbol == identity$symbol, , drop = FALSE]
    train <- x[x$session_date >= contract$train_start & x$session_date <= contract$train_end, , drop = FALSE]
    development <- x[
      x$session_date >= contract$development_start & x$session_date <= contract$development_end,
      , drop = FALSE
    ]
    finite <- nrow(x) > 0L && all(
      is.finite(x$open) & x$open > 0 & is.finite(x$high) & x$high > 0 &
        is.finite(x$low) & x$low > 0 & is.finite(x$close) & x$close > 0 &
        is.finite(x$volume) & x$volume >= 0
    )
    ohlc <- nrow(x) > 0L && all(
      x$high >= pmax(x$open, x$close, x$low) &
        x$low <= pmin(x$open, x$close, x$high)
    )
    duplicate <- anyDuplicated(x$timestamp_utc) > 0L
    train_exact <- identical(as.numeric(train$timestamp_utc), train_reference)
    development_exact <- identical(as.numeric(development$timestamp_utc), development_reference)
    prehistory <- sum(x$session_date < contract$train_start)
    mechanically_eligible <- nrow(x) > 0L && finite && ohlc && !duplicate &&
      train_exact && development_exact && prehistory >= contract$common_lookback_bars
    reason <- if (!nrow(x)) "no_bars" else if (duplicate) "duplicate_timestamps" else if (!finite) {
      "invalid_numeric_bars"
    } else if (!ohlc) "invalid_ohlc" else if (!train_exact) "train_calendar_mismatch" else if (!development_exact) {
      "development_calendar_mismatch"
    } else if (prehistory < contract$common_lookback_bars) "insufficient_prehistory" else "eligible"
    data.frame(
      order = identity$order, analysis_id = identity$analysis_id, symbol = identity$symbol,
      sector = identity$sector, analysis_stratum = identity$analysis_stratum,
      candidate_fdr = identity$candidate_fdr,
      total_bars = nrow(x), prehistory_bars = prehistory,
      train_bars = nrow(train), development_bars = nrow(development),
      first_session = if (nrow(x)) min(x$session_date) else as.Date(NA),
      last_session = if (nrow(x)) max(x$session_date) else as.Date(NA),
      train_calendar_exact = train_exact, development_calendar_exact = development_exact,
      mechanically_eligible = mechanically_eligible, eligibility_reason = reason,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_imom012_clock_matrix <- function(slot) {
  slot <- as.integer(slot)
  if (any(!slot %in% 1:13)) g5_imom012_stop("Anchor slot is outside the frozen 13-slot grid.")
  factor_slot <- factor(slot, levels = 1:13)
  out <- stats::model.matrix(~ factor_slot)[, -1L, drop = FALSE]
  colnames(out) <- paste0("slot_", 2:13)
  out
}

g5_imom012_period_panel <- function(symbol_bars, period_start, period_end,
                                    contract = g5_imom012_contract()) {
  contract <- g5_imom012_validate_contract(contract)
  x <- symbol_bars[order(symbol_bars$timestamp_utc), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  indices <- seq_len(nrow(x))
  anchor_i <- indices[
    indices > contract$common_lookback_bars &
      indices + 1L + contract$common_target_bars <= nrow(x) &
      x$session_date >= as.Date(period_start)
  ]
  anchor_i <- anchor_i[
    x$session_date[anchor_i + 1L + contract$common_target_bars] <= as.Date(period_end)
  ]
  if (!length(anchor_i)) return(NULL)
  feature_objects <- lapply(contract$lookback_grid, function(lookback) {
    g5_mom015_path_features(x$close, anchor_i, lookback)
  })
  feature_names <- names(feature_objects[[1L]])
  feature_matrices <- setNames(lapply(feature_names, function(feature) {
    out <- vapply(feature_objects, function(object) object[[feature]], numeric(length(anchor_i)))
    colnames(out) <- paste0("L", contract$lookback_grid)
    out
  }), feature_names)
  y <- vapply(contract$target_grid, function(horizon) {
    log(x$open[anchor_i + 1L + horizon] / x$open[anchor_i + 1L])
  }, numeric(length(anchor_i)))
  crosses_session <- vapply(contract$target_grid, function(horizon) {
    x$session_date[anchor_i + 1L] != x$session_date[anchor_i + 1L + horizon]
  }, logical(length(anchor_i)))
  colnames(y) <- colnames(crosses_session) <- paste0("H", contract$target_grid)
  if (any(!is.finite(y))) g5_imom012_stop("Nonfinite future-return target was constructed.")
  list(
    anchor_index = anchor_i,
    anchor_timestamp = x$timestamp_utc[anchor_i],
    anchor_session = x$session_date[anchor_i],
    anchor_slot = as.integer(x$bar_slot[anchor_i]),
    clock = g5_imom012_clock_matrix(x$bar_slot[anchor_i]),
    features = feature_matrices,
    y = y,
    target_crosses_session = crosses_session
  )
}

g5_imom012_fit_cell <- function(train_panel, development_panel, lookback_index,
                                target_index, contract = g5_imom012_contract()) {
  contract <- g5_imom012_validate_contract(contract)
  lookback <- contract$lookback_grid[[lookback_index]]
  target <- contract$target_grid[[target_index]]
  train_y <- train_panel$y[, target_index]
  development_y <- development_panel$y[, target_index]
  target_variance <- stats::var(train_y)
  if (!is.finite(target_variance) || target_variance <= .Machine$double.eps) {
    g5_imom012_stop("TRAIN target variance is degenerate.")
  }
  train_features <- cbind(
    raw_return = train_panel$features$raw_return[, lookback_index],
    coherent_positive = train_panel$features$coherent_positive[, lookback_index],
    shock_positive = train_panel$features$shock_positive[, lookback_index]
  )
  development_features <- cbind(
    raw_return = development_panel$features$raw_return[, lookback_index],
    coherent_positive = development_panel$features$coherent_positive[, lookback_index],
    shock_positive = development_panel$features$shock_positive[, lookback_index]
  )
  standardized <- g5_mom015_standardize(train_features, development_features)
  fit_b1 <- g5_mom015_fit_design(
    standardized$train[, "raw_return", drop = FALSE], train_y,
    standardized$development[, "raw_return", drop = FALSE]
  )
  fit_q2 <- g5_mom015_fit_design(standardized$train, train_y, standardized$development)
  fit_c0 <- g5_mom015_fit_design(train_panel$clock, train_y, development_panel$clock)
  fit_c1 <- g5_mom015_fit_design(
    cbind(train_panel$clock, standardized$train[, "raw_return", drop = FALSE]), train_y,
    cbind(development_panel$clock, standardized$development[, "raw_return", drop = FALSE])
  )
  fit_c2 <- g5_mom015_fit_design(
    cbind(train_panel$clock, standardized$train), train_y,
    cbind(development_panel$clock, standardized$development)
  )
  predictions <- list(
    B0_DRIFT = rep(mean(train_y), length(development_y)),
    B1_RAW = fit_b1$prediction,
    Q2_PATH = fit_q2$prediction,
    C0_CLOCK = fit_c0$prediction,
    C1_CLOCK_RAW = fit_c1$prediction,
    C2_CLOCK_PATH = fit_c2$prediction
  )
  squared <- lapply(predictions, function(prediction) (development_y - prediction)^2)
  absolute <- lapply(predictions, function(prediction) abs(development_y - prediction))
  baseline_by_model <- c(
    B0_DRIFT = "B0_DRIFT", B1_RAW = "B0_DRIFT", Q2_PATH = "B0_DRIFT",
    C0_CLOCK = "C0_CLOCK", C1_CLOCK_RAW = "C0_CLOCK", C2_CLOCK_PATH = "C0_CLOCK"
  )
  cell_id <- paste0("L", lookback, "_H", target)
  metrics <- do.call(rbind, lapply(contract$model_ids, function(model) {
    mse <- mean(squared[[model]])
    baseline_mse <- mean(squared[[baseline_by_model[[model]]]])
    data.frame(
      cell_id = cell_id, lookback_bars = lookback, target_bars = target,
      model_id = model, train_anchor_count = length(train_y),
      development_anchor_count = length(development_y),
      train_target_mean = mean(train_y), train_target_variance = target_variance,
      development_mse = mse, development_mae = mean(absolute[[model]]),
      development_scaled_loss = mse / target_variance,
      oos_skill_vs_chain_baseline = 1 - mse / baseline_mse,
      stringsAsFactors = FALSE
    )
  }))
  coefficient_rows <- function(model, feature, coefficient, rank) data.frame(
    cell_id = cell_id, lookback_bars = lookback, target_bars = target,
    model_id = model, feature = feature, coefficient = coefficient,
    fit_rank = rank, stringsAsFactors = FALSE
  )
  clock_names <- colnames(train_panel$clock)
  coefficients <- rbind(
    coefficient_rows("B0_DRIFT", "intercept", mean(train_y), 1L),
    coefficient_rows("B1_RAW", c("intercept", "raw_return"), fit_b1$coefficients, fit_b1$rank),
    coefficient_rows(
      "Q2_PATH", c("intercept", "raw_return", "coherent_positive", "shock_positive"),
      fit_q2$coefficients, fit_q2$rank
    ),
    coefficient_rows("C0_CLOCK", c("intercept", clock_names), fit_c0$coefficients, fit_c0$rank),
    coefficient_rows(
      "C1_CLOCK_RAW", c("intercept", clock_names, "raw_return"),
      fit_c1$coefficients, fit_c1$rank
    ),
    coefficient_rows(
      "C2_CLOCK_PATH", c("intercept", clock_names, "raw_return", "coherent_positive", "shock_positive"),
      fit_c2$coefficients, fit_c2$rank
    )
  )
  moments <- data.frame(
    cell_id = cell_id, lookback_bars = lookback, target_bars = target,
    feature = colnames(train_features), train_mean = standardized$center,
    train_sd = standardized$scale, stringsAsFactors = FALSE
  )
  losses <- data.frame(
    anchor_timestamp = development_panel$anchor_timestamp,
    anchor_session = development_panel$anchor_session,
    anchor_slot = development_panel$anchor_slot,
    target_crosses_session = development_panel$target_crosses_session[, target_index],
    stringsAsFactors = FALSE
  )
  for (model in contract$model_ids) losses[[model]] <- squared[[model]] / target_variance
  list(metrics = metrics, coefficients = coefficients, moments = moments, losses = losses)
}

g5_imom012_session_losses <- function(anchor_losses, model_ids) {
  aggregate(
    anchor_losses[, model_ids, drop = FALSE],
    by = list(session_date = as.Date(anchor_losses$anchor_session)),
    FUN = mean
  )
}

g5_imom012_add_contrasts <- function(losses) {
  losses$D10 <- losses$B0_DRIFT - losses$B1_RAW
  losses$D21 <- losses$B1_RAW - losses$Q2_PATH
  losses$D20 <- losses$B0_DRIFT - losses$Q2_PATH
  losses$K10 <- losses$C0_CLOCK - losses$C1_CLOCK_RAW
  losses$K21 <- losses$C1_CLOCK_RAW - losses$C2_CLOCK_PATH
  losses$K20 <- losses$C0_CLOCK - losses$C2_CLOCK_PATH
  losses
}

g5_imom012_apply_fdr <- function(contrasts, contract = g5_imom012_contract()) {
  contract <- g5_imom012_validate_contract(contract)
  contrasts$bh_q_value <- NA_real_
  for (contrast in contract$contrast_ids) {
    keep <- contrasts$contrast_id == contrast & contrasts$candidate_fdr
    contrasts$bh_q_value[keep] <- stats::p.adjust(
      contrasts$centered_null_upper_p[keep], method = "BH"
    )
  }
  contrasts
}

g5_imom012_decisions <- function(contrasts, coefficient_summary, registry,
                                 contract = g5_imom012_contract()) {
  contract <- g5_imom012_validate_contract(contract)
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    identity <- registry[i, , drop = FALSE]
    x <- contrasts[contrasts$analysis_id == identity$analysis_id, , drop = FALSE]
    csum <- coefficient_summary[coefficient_summary$analysis_id == identity$analysis_id, , drop = FALSE]
    get_one <- function(id) x[x$contrast_id == id, , drop = FALSE]
    values <- setNames(lapply(contract$contrast_ids, get_one), contract$contrast_ids)
    complete <- all(vapply(values, nrow, integer(1)) == 1L) && nrow(csum) == 1L
    candidate <- complete && identity$candidate_fdr &&
      values$D21$observed_mean_differential > 0 && values$D20$observed_mean_differential > 0 &&
      values$K21$observed_mean_differential > 0 && values$K20$observed_mean_differential > 0 &&
      values$K21$ci_lower_90 > 0 && values$K20$ci_lower_90 > 0 &&
      values$K21$bh_q_value <= contract$fdr_q && values$K20$bh_q_value <= contract$fdr_q &&
      csum$median_clock_gamma > 0 && csum$median_clock_delta < 0
    raw_clue <- complete && identity$candidate_fdr &&
      values$D10$observed_mean_differential > 0 && values$K10$observed_mean_differential > 0 &&
      values$K10$ci_lower_90 > 0 && values$K10$bh_q_value <= contract$fdr_q
    row <- data.frame(
      analysis_id = identity$analysis_id, symbol = identity$symbol, sector = identity$sector,
      analysis_stratum = identity$analysis_stratum, candidate_fdr = identity$candidate_fdr,
      comparison_complete = complete, stringsAsFactors = FALSE
    )
    for (id in contract$contrast_ids) {
      key <- tolower(id)
      row[[paste0(key, "_mean")]] <- if (nrow(values[[id]])) values[[id]]$observed_mean_differential else NA_real_
      row[[paste0(key, "_q")]] <- if (nrow(values[[id]])) values[[id]]$bh_q_value else NA_real_
    }
    row$median_clock_gamma <- if (nrow(csum)) csum$median_clock_gamma else NA_real_
    row$median_clock_delta <- if (nrow(csum)) csum$median_clock_delta else NA_real_
    row$clock_controlled_raw_clue <- raw_clue
    row$is_clock_controlled_path_candidate <- candidate
    row
  })
  do.call(rbind, rows)
}

g5_imom012_slot_diagnostics <- function(fitted, identity, contract = g5_imom012_contract()) {
  rows <- list(); z <- 1L
  for (cell in fitted) {
    loss <- cell$losses
    cell_id <- cell$metrics$cell_id[[1L]]
    for (model in contract$model_ids) {
      grouped <- aggregate(
        loss[[model]],
        by = list(anchor_slot = loss$anchor_slot, target_crosses_session = loss$target_crosses_session),
        FUN = mean
      )
      names(grouped)[3L] <- "mean_scaled_loss"
      grouped$cell_id <- cell_id
      grouped$model_id <- model
      rows[[z]] <- grouped
      z <- z + 1L
    }
  }
  out <- do.call(rbind, rows)
  cbind(
    data.frame(
      analysis_id = rep(identity$analysis_id[[1L]], nrow(out)),
      symbol = rep(identity$symbol[[1L]], nrow(out)), stringsAsFactors = FALSE
    ),
    out
  )
}

g5_imom012_role_summary <- function(decisions) {
  keys <- unique(decisions$analysis_stratum)
  do.call(rbind, lapply(keys, function(key) {
    x <- decisions[decisions$analysis_stratum == key & decisions$comparison_complete, , drop = FALSE]
    data.frame(
      analysis_stratum = key, tested_assets = nrow(x),
      positive_d10 = sum(x$d10_mean > 0), positive_d21 = sum(x$d21_mean > 0),
      positive_d20 = sum(x$d20_mean > 0), positive_k10 = sum(x$k10_mean > 0),
      positive_k21 = sum(x$k21_mean > 0), positive_k20 = sum(x$k20_mean > 0),
      raw_clues = sum(x$clock_controlled_raw_clue),
      path_candidates = sum(x$is_clock_controlled_path_candidate),
      stringsAsFactors = FALSE
    )
  }))
}

g5_imom012_run_comparison <- function(bars, registry, contract = g5_imom012_contract()) {
  contract <- g5_imom012_validate_contract(contract)
  registry <- g5_imom012_validate_registry(registry, contract)
  bars <- g5_imom012_prepare_bars(bars, registry, contract)
  ledger <- g5_imom012_coverage_ledger(bars, registry, contract)
  ledger$train_anchor_count <- 0L
  ledger$development_anchor_count <- 0L
  ledger$valid_cell_count <- 0L
  ledger$cells_completed_before_invalid <- 0L
  ledger$analysis_eligible <- FALSE
  ledger$comparison_status <- "NOT_TESTED_INELIGIBLE"
  cell_metrics <- coefficients <- moments <- anchor_losses <- session_losses <- list()
  contrasts <- coefficient_summaries <- slot_diagnostics <- list()

  for (asset_i in seq_len(nrow(registry))) {
    identity <- registry[asset_i, , drop = FALSE]
    ledger_i <- match(identity$analysis_id, ledger$analysis_id)
    if (!ledger$mechanically_eligible[[ledger_i]]) next
    symbol_bars <- bars[bars$symbol == identity$symbol, , drop = FALSE]
    train_panel <- g5_imom012_period_panel(symbol_bars, contract$train_start, contract$train_end, contract)
    development_panel <- g5_imom012_period_panel(
      symbol_bars, contract$development_start, contract$development_end, contract
    )
    train_n <- if (is.null(train_panel)) 0L else nrow(train_panel$y)
    development_n <- if (is.null(development_panel)) 0L else nrow(development_panel$y)
    ledger$train_anchor_count[[ledger_i]] <- train_n
    ledger$development_anchor_count[[ledger_i]] <- development_n
    if (train_n < contract$minimum_period_anchors || development_n < contract$minimum_period_anchors) {
      ledger$eligibility_reason[[ledger_i]] <- "insufficient_common_period_anchors"
      ledger$comparison_status[[ledger_i]] <- "INSUFFICIENT_COMMON_PERIOD_ANCHORS"
      next
    }
    fitted <- list(); failure <- NULL
    for (l_i in seq_along(contract$lookback_grid)) {
      for (h_i in seq_along(contract$target_grid)) {
        result <- tryCatch(
          g5_imom012_fit_cell(train_panel, development_panel, l_i, h_i, contract),
          error = function(e) e
        )
        if (inherits(result, "error")) { failure <- conditionMessage(result); break }
        fitted[[paste0("L", l_i, "_H", h_i)]] <- result
      }
      if (!is.null(failure)) break
    }
    ledger$cells_completed_before_invalid[[ledger_i]] <- length(fitted)
    if (!is.null(failure) || length(fitted) != 24L) {
      ledger$eligibility_reason[[ledger_i]] <- paste0("invalid_model_cell:", failure)
      ledger$comparison_status[[ledger_i]] <- "INVALID_MODEL_CELL"
      next
    }
    ledger$valid_cell_count[[ledger_i]] <- 24L
    ledger$analysis_eligible[[ledger_i]] <- TRUE
    ledger$comparison_status[[ledger_i]] <- "COMPLETE_24_CELL_SIX_MODEL_COMPARISON"
    tag <- function(x) cbind(
      data.frame(
        analysis_id = rep(identity$analysis_id[[1L]], nrow(x)),
        symbol = rep(identity$symbol[[1L]], nrow(x)),
        sector = rep(identity$sector[[1L]], nrow(x)),
        analysis_stratum = rep(identity$analysis_stratum[[1L]], nrow(x)),
        candidate_fdr = rep(identity$candidate_fdr[[1L]], nrow(x)),
        stringsAsFactors = FALSE
      ), x
    )
    metrics_asset <- do.call(rbind, lapply(fitted, `[[`, "metrics"))
    coefficients_asset <- do.call(rbind, lapply(fitted, `[[`, "coefficients"))
    moments_asset <- do.call(rbind, lapply(fitted, `[[`, "moments"))
    loss_arrays <- setNames(lapply(contract$model_ids, function(model) {
      do.call(cbind, lapply(fitted, function(cell) cell$losses[[model]]))
    }), contract$model_ids)
    aggregate_anchor <- data.frame(
      anchor_timestamp = development_panel$anchor_timestamp,
      anchor_session = development_panel$anchor_session,
      anchor_slot = development_panel$anchor_slot,
      stringsAsFactors = FALSE
    )
    for (model in contract$model_ids) aggregate_anchor[[model]] <- rowMeans(loss_arrays[[model]])
    aggregate_session <- g5_imom012_session_losses(aggregate_anchor, contract$model_ids)
    aggregate_session <- g5_imom012_add_contrasts(aggregate_session)
    contrast_asset <- do.call(rbind, lapply(seq_along(contract$contrast_ids), function(j) {
      contrast <- contract$contrast_ids[[j]]
      seed <- contract$bootstrap_seed_base + 10L * identity$order[[1L]] + j
      cbind(
        contrast_id = contrast,
        g5_mom015_stationary_mean(
          aggregate_session[[contrast]], seed, contract$bootstrap_count,
          contract$bootstrap_expected_sessions, contract$bootstrap_quantile_type
        )
      )
    }))
    clock_gamma <- coefficients_asset$coefficient[
      coefficients_asset$model_id == "C2_CLOCK_PATH" & coefficients_asset$feature == "coherent_positive"
    ]
    clock_delta <- coefficients_asset$coefficient[
      coefficients_asset$model_id == "C2_CLOCK_PATH" & coefficients_asset$feature == "shock_positive"
    ]
    exact_gamma <- coefficients_asset$coefficient[
      coefficients_asset$model_id == "Q2_PATH" & coefficients_asset$feature == "coherent_positive"
    ]
    exact_delta <- coefficients_asset$coefficient[
      coefficients_asset$model_id == "Q2_PATH" & coefficients_asset$feature == "shock_positive"
    ]
    coefficient_summaries[[identity$analysis_id]] <- tag(data.frame(
      cell_count = length(clock_gamma),
      median_exact_gamma = stats::median(exact_gamma),
      median_exact_delta = stats::median(exact_delta),
      median_clock_gamma = stats::median(clock_gamma),
      positive_clock_gamma_cells = sum(clock_gamma > 0),
      median_clock_delta = stats::median(clock_delta),
      negative_clock_delta_cells = sum(clock_delta < 0),
      clock_mechanism_aligned = stats::median(clock_gamma) > 0 && stats::median(clock_delta) < 0,
      stringsAsFactors = FALSE
    ))
    cell_metrics[[identity$analysis_id]] <- tag(metrics_asset)
    coefficients[[identity$analysis_id]] <- tag(coefficients_asset)
    moments[[identity$analysis_id]] <- tag(moments_asset)
    anchor_losses[[identity$analysis_id]] <- tag(aggregate_anchor)
    session_losses[[identity$analysis_id]] <- tag(aggregate_session)
    contrasts[[identity$analysis_id]] <- tag(contrast_asset)
    slot_diagnostics[[identity$analysis_id]] <- g5_imom012_slot_diagnostics(fitted, identity, contract)
  }
  bind_or_empty <- function(x) if (length(x)) do.call(rbind, x) else data.frame()
  contrast_table <- g5_imom012_apply_fdr(bind_or_empty(contrasts), contract)
  coefficient_summary <- bind_or_empty(coefficient_summaries)
  decisions <- g5_imom012_decisions(contrast_table, coefficient_summary, registry, contract)
  candidates <- decisions[decisions$is_clock_controlled_path_candidate, , drop = FALSE]
  raw_clues <- decisions[decisions$clock_controlled_raw_clue, , drop = FALSE]
  status <- if (nrow(candidates)) {
    "DEVELOPMENT_COMPLETE_LIT_IMOM_01_2_CLOCK_CONTROLLED_PATH_CANDIDATES"
  } else {
    "STOP_LIT_IMOM_01_2_NO_CLOCK_CONTROLLED_PATH_QUALITY_FORECAST"
  }
  list(
    contract = contract, registry = registry, ledger = ledger,
    cell_metrics = bind_or_empty(cell_metrics), coefficients = bind_or_empty(coefficients),
    feature_moments = bind_or_empty(moments), anchor_losses = bind_or_empty(anchor_losses),
    session_losses = bind_or_empty(session_losses), contrasts = contrast_table,
    coefficient_summary = coefficient_summary, decisions = decisions,
    candidates = candidates, raw_clues = raw_clues,
    role_summary = g5_imom012_role_summary(decisions),
    slot_diagnostics = bind_or_empty(slot_diagnostics), overall_status = status,
    confirmation_opened = FALSE
  )
}
