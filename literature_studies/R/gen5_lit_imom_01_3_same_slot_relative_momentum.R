# Frozen LIT-IMOM-01.3 same-slot relative-momentum helpers.
# Source the LIT-MOM-01.5 helper and isolated 30-minute provider helper first.

g5_imom013_stop <- function(message) stop(paste0("[LIT-IMOM-01.3] ", message), call. = FALSE)

g5_imom013_schema_version <- function() "gen5_lit_imom_01_3_v1"

g5_imom013_contract <- function() {
  list(
    literature_id = "LIT-IMOM-01.3",
    descriptive_name = "Same-Slot Relative Momentum",
    design_as_of_timestamp = "2026-08-21 17:30:00 America/New_York",
    cache_as_of_timestamp = "2026-08-13 17:30:00 America/New_York",
    registry_relative_path = file.path(
      "operator_hypothesis_lab", "registries", "gen5_intraday_momentum_poc_registry.csv"
    ),
    registry_sha256 = "ED6A9C87E00E53970528F9638BFB972323D47AF86B273C19A13DC89DE9D7B4AF",
    registry_count = 26L,
    fitted_asset_count = 25L,
    candidate_count = 22L,
    benchmark_symbol = "SPY",
    diagnostic_symbols = c("AMD", "TSLA", "QQQ"),
    query_start = as.Date("2017-09-01"),
    query_end = as.Date("2023-12-29"),
    train_start = as.Date("2018-01-02"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    full_session_slots = 1:13,
    minimum_target_sessions = 700L,
    model_ids = c("M0_CLOCK", "M1_DAY", "M2_SAME", sprintf("P%02d", 1:12)),
    primary_model_ids = c("M0_CLOCK", "M1_DAY", "M2_SAME"),
    contrast_ids = c("G10", "S21", "S20", "U"),
    placebo_offsets = 1:12,
    fdr_q = 0.10,
    panel_p = 0.05,
    bootstrap_count = 10000L,
    bootstrap_expected_sessions = 20,
    bootstrap_seed_base = 2026082170L,
    panel_bootstrap_seed = 2026082990L,
    bootstrap_quantile_type = 7L,
    archive_exclusion_dates = as.Date(c(
      "2018-05-02", "2018-05-03", "2018-08-07", "2019-08-12", "2019-10-09",
      "2021-04-19", "2021-10-25", "2022-01-24", "2022-01-26", "2022-03-08"
    ))
  )
}

g5_imom013_validate_contract <- function(contract = g5_imom013_contract()) {
  frozen <- g5_imom013_contract()
  if (!identical(names(contract), names(frozen))) g5_imom013_stop("Frozen contract field set changed.")
  same <- vapply(names(frozen), function(field) identical(contract[[field]], frozen[[field]]), logical(1))
  if (!all(same)) {
    g5_imom013_stop(paste("Frozen contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  }
  if (length(contract$full_session_slots) != 13L || length(contract$placebo_offsets) != 12L) {
    g5_imom013_stop("Frozen 13-slot and 12-placebo surfaces changed.")
  }
  contract
}

g5_imom013_validate_registry <- function(registry, contract = g5_imom013_contract()) {
  contract <- g5_imom013_validate_contract(contract)
  required <- c("instance_id", "symbol", "sector", "asset_type", "panel_role", "source_registry")
  missing <- setdiff(required, names(registry))
  if (length(missing)) g5_imom013_stop(paste("Registry columns missing:", paste(missing, collapse = ", ")))
  x <- registry
  x$symbol <- toupper(trimws(as.character(x$symbol)))
  checks <- c(
    nrow(x) == contract$registry_count,
    !anyDuplicated(x$instance_id), !anyDuplicated(x$symbol),
    sum(x$panel_role == "diverse_stock_panel") == contract$candidate_count,
    sum(x$symbol == contract$benchmark_symbol) == 1L,
    identical(
      sort(x$symbol[!x$panel_role %in% "diverse_stock_panel" & x$symbol != contract$benchmark_symbol]),
      sort(contract$diagnostic_symbols)
    )
  )
  if (!all(checks)) g5_imom013_stop("Frozen registry structure or roles changed.")
  x$order <- seq_len(nrow(x))
  x$analysis_id <- x$instance_id
  x$benchmark_only <- x$symbol == contract$benchmark_symbol
  x$candidate_fdr <- x$panel_role == "diverse_stock_panel"
  x$analysis_stratum <- ifelse(
    x$benchmark_only, "BENCHMARK_ONLY",
    ifelse(x$candidate_fdr, "DIVERSE_STOCK_CANDIDATE",
      ifelse(x$asset_type == "etf", "REFERENCE_ETF", "REMEMBERED_OPERATOR_CASE")
    )
  )
  x
}

g5_imom013_prepare_bars <- function(bars, registry, contract = g5_imom013_contract()) {
  contract <- g5_imom013_validate_contract(contract)
  required <- c(
    "symbol", "timestamp_utc", "session_date", "bar_time_et", "bar_slot",
    "open", "high", "low", "close", "volume", "provider", "feed",
    "timeframe", "adjustment", "as_of_timestamp"
  )
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_imom013_stop(paste("Bar columns missing:", paste(missing, collapse = ", ")))
  x <- bars[bars$symbol %in% registry$symbol, , drop = FALSE]
  x$symbol <- toupper(as.character(x$symbol))
  x$session_date <- as.Date(x$session_date)
  x <- x[x$session_date >= contract$query_start & x$session_date <= contract$query_end, , drop = FALSE]
  x <- imom30_apply_rth_calendar(x)
  x <- x[order(x$session_date, x$bar_slot, match(x$symbol, registry$symbol)), , drop = FALSE]
  if (!nrow(x)) g5_imom013_stop("No frozen 30-minute bars are available.")
  if (any(x$session_date >= contract$confirmation_start)) g5_imom013_stop("Confirmation bars entered input.")
  metadata_ok <- all(
    x$provider == "alpaca" & x$feed == "sip" & x$timeframe == "30Min" &
      x$adjustment == "all" & x$as_of_timestamp == contract$cache_as_of_timestamp
  )
  if (!metadata_ok) g5_imom013_stop("Frozen provider metadata changed.")
  finite <- all(
    is.finite(x$open) & x$open > 0 & is.finite(x$high) & x$high > 0 &
      is.finite(x$low) & x$low > 0 & is.finite(x$close) & x$close > 0 &
      is.finite(x$volume) & x$volume >= 0
  )
  if (!finite) g5_imom013_stop("Bar panel contains invalid numeric values.")
  if (!all(x$high >= pmax(x$open, x$close, x$low) & x$low <= pmin(x$open, x$close, x$high))) {
    g5_imom013_stop("Bar panel violates OHLC ordering.")
  }
  if (anyDuplicated(x[c("symbol", "timestamp_utc")])) g5_imom013_stop("Duplicate symbol timestamps detected.")
  x
}

g5_imom013_session_calendar <- function(bars, registry, contract = g5_imom013_contract()) {
  contract <- g5_imom013_validate_contract(contract)
  spy <- bars[bars$symbol == contract$benchmark_symbol, , drop = FALSE]
  dates <- sort(unique(as.Date(spy$session_date)))
  if (!length(dates)) g5_imom013_stop("SPY session calendar is empty.")
  full <- logical(length(dates))
  timestamp_exact <- logical(length(dates))
  for (i in seq_along(dates)) {
    day <- bars[bars$session_date == dates[[i]], , drop = FALSE]
    ref <- day[day$symbol == contract$benchmark_symbol, , drop = FALSE]
    ref <- ref[order(ref$bar_slot), , drop = FALSE]
    full_rows <- nrow(ref) == 13L && identical(as.integer(ref$bar_slot), contract$full_session_slots)
    exact <- full_rows
    if (full_rows) {
      for (symbol in registry$symbol) {
        z <- day[day$symbol == symbol, , drop = FALSE]
        z <- z[order(z$bar_slot), , drop = FALSE]
        full_rows <- full_rows && nrow(z) == 13L && identical(as.integer(z$bar_slot), contract$full_session_slots)
        exact <- exact && nrow(z) == 13L && identical(as.numeric(z$timestamp_utc), as.numeric(ref$timestamp_utc))
      }
    }
    full[[i]] <- full_rows
    timestamp_exact[[i]] <- exact
  }
  excluded <- dates %in% contract$archive_exclusion_dates
  previous <- c(as.Date(NA), dates[-length(dates)])
  pair <- full & timestamp_exact & !excluded & c(FALSE, full[-length(full)]) &
    c(FALSE, timestamp_exact[-length(timestamp_exact)]) & c(FALSE, !excluded[-length(excluded)])
  split <- rep("OUTSIDE", length(dates))
  split[dates >= contract$train_start & dates <= contract$train_end] <- "TRAIN"
  split[dates >= contract$development_start & dates <= contract$development_end] <- "DEVELOPMENT"
  data.frame(
    session_date = dates, previous_session = previous,
    full_13_slot_panel = full, timestamp_exact = timestamp_exact,
    archive_excluded = excluded, consecutive_pair_eligible = pair,
    analysis_split = split, stringsAsFactors = FALSE
  )
}

g5_imom013_coverage_ledger <- function(bars, registry, calendar, contract = g5_imom013_contract()) {
  contract <- g5_imom013_validate_contract(contract)
  train_targets <- calendar$session_date[
    calendar$consecutive_pair_eligible & calendar$analysis_split == "TRAIN"
  ]
  development_targets <- calendar$session_date[
    calendar$consecutive_pair_eligible & calendar$analysis_split == "DEVELOPMENT"
  ]
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    identity <- registry[i, , drop = FALSE]
    x <- bars[bars$symbol == identity$symbol, , drop = FALSE]
    mechanically_eligible <- nrow(x) > 0L && length(train_targets) >= contract$minimum_target_sessions &&
      length(development_targets) >= contract$minimum_target_sessions
    data.frame(
      order = identity$order, analysis_id = identity$analysis_id, symbol = identity$symbol,
      sector = identity$sector, analysis_stratum = identity$analysis_stratum,
      benchmark_only = identity$benchmark_only, candidate_fdr = identity$candidate_fdr,
      total_rth_bars = nrow(x), first_session = min(x$session_date), last_session = max(x$session_date),
      train_target_sessions = length(train_targets), development_target_sessions = length(development_targets),
      mechanically_eligible = mechanically_eligible,
      eligibility_reason = if (mechanically_eligible) "eligible" else "insufficient_common_full_session_pairs",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_imom013_clock_matrix <- function(slot) {
  slot <- as.integer(slot)
  if (any(!slot %in% 1:13)) g5_imom013_stop("Target slot is outside the frozen 13-slot grid.")
  out <- stats::model.matrix(~ factor(slot, levels = 1:13))[, -1L, drop = FALSE]
  colnames(out) <- paste0("slot_", 2:13)
  out
}

g5_imom013_relative_return_matrix <- function(bars, symbol, full_dates, contract = g5_imom013_contract()) {
  asset <- bars[bars$symbol == symbol & bars$session_date %in% full_dates, , drop = FALSE]
  spy <- bars[bars$symbol == contract$benchmark_symbol & bars$session_date %in% full_dates, , drop = FALSE]
  asset <- asset[order(asset$session_date, asset$bar_slot), , drop = FALSE]
  spy <- spy[order(spy$session_date, spy$bar_slot), , drop = FALSE]
  if (nrow(asset) != length(full_dates) * 13L || !identical(as.numeric(asset$timestamp_utc), as.numeric(spy$timestamp_utc))) {
    g5_imom013_stop(paste("Common full-session timestamps changed for", symbol))
  }
  rel <- log(asset$close / asset$open) - log(spy$close / spy$open)
  matrix(rel, nrow = length(full_dates), ncol = 13L, byrow = TRUE,
    dimnames = list(as.character(full_dates), as.character(1:13)))
}

g5_imom013_asset_panel <- function(bars, calendar, symbol, contract = g5_imom013_contract()) {
  contract <- g5_imom013_validate_contract(contract)
  full_dates <- calendar$session_date[calendar$full_13_slot_panel & calendar$timestamp_exact]
  relative <- g5_imom013_relative_return_matrix(bars, symbol, full_dates, contract)
  asset <- bars[bars$symbol == symbol & bars$session_date %in% full_dates, , drop = FALSE]
  spy <- bars[bars$symbol == contract$benchmark_symbol & bars$session_date %in% full_dates, , drop = FALSE]
  asset <- asset[order(asset$session_date, asset$bar_slot), , drop = FALSE]
  spy <- spy[order(spy$session_date, spy$bar_slot), , drop = FALSE]
  asset_open <- asset$open[asset$bar_slot == 1L]
  asset_close <- asset$close[asset$bar_slot == 13L]
  spy_open <- spy$open[spy$bar_slot == 1L]
  spy_close <- spy$close[spy$bar_slot == 13L]
  day_relative <- log(asset_close / asset_open) - log(spy_close / spy_open)
  names(day_relative) <- as.character(full_dates)
  target_calendar <- calendar[
    calendar$consecutive_pair_eligible & calendar$analysis_split %in% c("TRAIN", "DEVELOPMENT"),
    , drop = FALSE
  ]
  target_dates <- target_calendar$session_date
  previous_dates <- target_calendar$previous_session
  if (!all(as.character(target_dates) %in% rownames(relative)) ||
      !all(as.character(previous_dates) %in% rownames(relative))) {
    g5_imom013_stop(paste("Eligible pair matrix is incomplete for", symbol))
  }
  n <- length(target_dates)
  source <- relative[as.character(previous_dates), , drop = FALSE]
  source_long <- source[rep(seq_len(n), each = 13L), , drop = FALSE]
  out <- data.frame(
    target_session = rep(target_dates, each = 13L),
    previous_session = rep(previous_dates, each = 13L),
    analysis_split = rep(target_calendar$analysis_split, each = 13L),
    target_slot = rep(1:13, times = n),
    target_relative_return = as.vector(t(relative[as.character(target_dates), , drop = FALSE])),
    prior_session_relative_return = rep(unname(day_relative[as.character(previous_dates)]), each = 13L),
    stringsAsFactors = FALSE
  )
  for (slot in 1:13) out[[sprintf("source_%02d", slot)]] <- source_long[, slot]
  out
}

g5_imom013_train_moments <- function(train_panel) {
  target_rows <- lapply(1:13, function(slot) {
    values <- train_panel$target_relative_return[train_panel$target_slot == slot]
    data.frame(kind = "target", slot = slot, train_mean = mean(values), train_sd = stats::sd(values))
  })
  source_rows <- lapply(1:13, function(slot) {
    values <- train_panel[[sprintf("source_%02d", slot)]][train_panel$target_slot == 1L]
    data.frame(kind = "source", slot = slot, train_mean = mean(values), train_sd = stats::sd(values))
  })
  day_values <- train_panel$prior_session_relative_return[train_panel$target_slot == 1L]
  out <- rbind(
    do.call(rbind, target_rows), do.call(rbind, source_rows),
    data.frame(kind = "prior_session", slot = NA_integer_, train_mean = mean(day_values), train_sd = stats::sd(day_values))
  )
  if (any(!is.finite(out$train_mean)) || any(!is.finite(out$train_sd)) || any(out$train_sd <= 0)) {
    g5_imom013_stop("TRAIN normalization moments are invalid.")
  }
  out
}

g5_imom013_standardize_panel <- function(panel, moments) {
  out <- panel
  target_mean <- moments$train_mean[moments$kind == "target"]
  target_sd <- moments$train_sd[moments$kind == "target"]
  out$target_z <- (out$target_relative_return - target_mean[out$target_slot]) / target_sd[out$target_slot]
  day <- moments[moments$kind == "prior_session", , drop = FALSE]
  out$prior_session_z <- (out$prior_session_relative_return - day$train_mean) / day$train_sd
  for (slot in 1:13) {
    moment <- moments[moments$kind == "source" & moments$slot == slot, , drop = FALSE]
    out[[sprintf("source_z_%02d", slot)]] <-
      (out[[sprintf("source_%02d", slot)]] - moment$train_mean) / moment$train_sd
  }
  if (any(!is.finite(out$target_z)) || any(!is.finite(out$prior_session_z))) {
    g5_imom013_stop("Standardized panel contains nonfinite values.")
  }
  out
}

g5_imom013_source_vector <- function(panel, offset = 0L) {
  source_slot <- ((panel$target_slot - 1L + as.integer(offset)) %% 13L) + 1L
  source <- as.matrix(panel[, sprintf("source_z_%02d", 1:13), drop = FALSE])
  as.numeric(source[cbind(seq_len(nrow(panel)), source_slot)])
}

g5_imom013_fit_asset <- function(panel, contract = g5_imom013_contract()) {
  contract <- g5_imom013_validate_contract(contract)
  train_raw <- panel[panel$analysis_split == "TRAIN", , drop = FALSE]
  development_raw <- panel[panel$analysis_split == "DEVELOPMENT", , drop = FALSE]
  moments <- g5_imom013_train_moments(train_raw)
  train <- g5_imom013_standardize_panel(train_raw, moments)
  development <- g5_imom013_standardize_panel(development_raw, moments)
  clock_train <- g5_imom013_clock_matrix(train$target_slot)
  clock_development <- g5_imom013_clock_matrix(development$target_slot)
  fit_one <- function(train_feature, development_feature) {
    out <- g5_mom015_fit_design(train_feature, train$target_z, development_feature)
    names(out$coefficients) <- c("intercept", colnames(train_feature))
    out
  }
  fits <- list(
    M0_CLOCK = fit_one(clock_train, clock_development),
    M1_DAY = fit_one(
      cbind(clock_train, prior_session = train$prior_session_z),
      cbind(clock_development, prior_session = development$prior_session_z)
    ),
    M2_SAME = fit_one(
      cbind(clock_train, prior_session = train$prior_session_z, same_slot = g5_imom013_source_vector(train, 0L)),
      cbind(clock_development, prior_session = development$prior_session_z, same_slot = g5_imom013_source_vector(development, 0L))
    )
  )
  for (offset in contract$placebo_offsets) {
    id <- sprintf("P%02d", offset)
    fits[[id]] <- fit_one(
      cbind(clock_train, prior_session = train$prior_session_z,
        displaced_slot = g5_imom013_source_vector(train, offset)),
      cbind(clock_development, prior_session = development$prior_session_z,
        displaced_slot = g5_imom013_source_vector(development, offset))
    )
  }
  predictions <- lapply(fits, `[[`, "prediction")
  scaled_loss <- lapply(predictions, function(prediction) (development$target_z - prediction)^2)
  target_mean <- moments$train_mean[moments$kind == "target"]
  target_sd <- moments$train_sd[moments$kind == "target"]
  unscaled_prediction <- lapply(predictions, function(prediction) {
    target_mean[development$target_slot] + target_sd[development$target_slot] * prediction
  })
  unscaled_squared <- lapply(unscaled_prediction, function(prediction) {
    (development$target_relative_return - prediction)^2
  })
  unscaled_absolute <- lapply(unscaled_prediction, function(prediction) {
    abs(development$target_relative_return - prediction)
  })
  loss <- data.frame(
    target_session = development$target_session,
    target_slot = development$target_slot,
    target_relative_return = development$target_relative_return,
    target_z = development$target_z,
    stringsAsFactors = FALSE
  )
  for (model in contract$model_ids) {
    loss[[model]] <- scaled_loss[[model]]
    loss[[paste0(model, "_unscaled_sq")]] <- unscaled_squared[[model]]
    loss[[paste0(model, "_unscaled_abs")]] <- unscaled_absolute[[model]]
  }
  session <- aggregate(
    loss[, contract$model_ids, drop = FALSE],
    by = list(session_date = as.Date(loss$target_session)), FUN = mean
  )
  session$G10 <- session$M0_CLOCK - session$M1_DAY
  session$S21 <- session$M1_DAY - session$M2_SAME
  session$S20 <- session$M0_CLOCK - session$M2_SAME
  for (offset in contract$placebo_offsets) {
    id <- sprintf("P%02d", offset)
    session[[sprintf("W%02d", offset)]] <- session$M1_DAY - session[[id]]
  }
  coefficients <- do.call(rbind, lapply(names(fits), function(model) {
    data.frame(
      model_id = model,
      feature = names(fits[[model]]$coefficients),
      coefficient = unname(fits[[model]]$coefficients),
      fit_rank = fits[[model]]$rank,
      stringsAsFactors = FALSE
    )
  }))
  metrics <- do.call(rbind, lapply(contract$model_ids, function(model) {
    data.frame(
      model_id = model,
      development_scaled_loss = mean(loss[[model]]),
      development_mse = mean(loss[[paste0(model, "_unscaled_sq")]]),
      development_mae = mean(loss[[paste0(model, "_unscaled_abs")]]),
      train_observations = nrow(train), development_observations = nrow(development),
      train_sessions = length(unique(train$target_session)),
      development_sessions = length(unique(development$target_session)),
      stringsAsFactors = FALSE
    )
  }))
  list(
    moments = moments, coefficients = coefficients, metrics = metrics,
    anchor_losses = loss, session_losses = session,
    train = train, development = development
  )
}

g5_imom013_specificity_inference <- function(
  session_losses, seed, draws = 10000L, expected_block = 20, quantile_type = 7L
) {
  same <- as.numeric(session_losses$S21)
  placebo_names <- sprintf("W%02d", 1:12)
  placebo <- as.matrix(session_losses[, placebo_names, drop = FALSE])
  if (length(same) < 2L || any(!is.finite(same)) || any(!is.finite(placebo))) {
    g5_imom013_stop("Specificity bootstrap requires finite ordered session losses.")
  }
  placebo_mean <- colMeans(placebo)
  best <- unname(which.max(placebo_mean))
  observed <- mean(same) - placebo_mean[[best]]
  set.seed(as.integer(seed))
  indices <- g5_mom015_stationary_index_matrix(length(same), draws, expected_block)
  same_boot <- rowMeans(matrix(same[indices], nrow = draws))
  placebo_boot <- vapply(seq_len(ncol(placebo)), function(j) {
    rowMeans(matrix(placebo[indices, j], nrow = draws))
  }, numeric(draws))
  boot <- same_boot - apply(placebo_boot, 1L, max)
  data.frame(
    bootstrap_seed = as.integer(seed), bootstrap_draws = as.integer(draws),
    observed_mean_differential = observed, bootstrap_mean = mean(boot),
    ci_lower_90 = unname(stats::quantile(boot, 0.05, type = quantile_type)),
    ci_upper_90 = unname(stats::quantile(boot, 0.95, type = quantile_type)),
    centered_null_upper_p = (1 + sum((boot - observed) >= observed)) / (1 + length(boot)),
    best_placebo_offset = best,
    same_slot_improvement = mean(same), best_placebo_improvement = placebo_mean[[best]],
    stringsAsFactors = FALSE
  )
}

g5_imom013_contrast_inference <- function(session_losses, order, contract = g5_imom013_contract()) {
  fixed <- do.call(rbind, lapply(seq_len(3L), function(j) {
    id <- contract$contrast_ids[[j]]
    cbind(
      contrast_id = id,
      g5_mom015_stationary_mean(
        session_losses[[id]], contract$bootstrap_seed_base + 10L * order + j,
        contract$bootstrap_count, contract$bootstrap_expected_sessions,
        contract$bootstrap_quantile_type
      )
    )
  }))
  specificity <- cbind(
    contrast_id = "U",
    g5_imom013_specificity_inference(
      session_losses, contract$bootstrap_seed_base + 10L * order + 4L,
      contract$bootstrap_count, contract$bootstrap_expected_sessions,
      contract$bootstrap_quantile_type
    )
  )
  for (name in setdiff(names(specificity), names(fixed))) fixed[[name]] <- NA
  for (name in setdiff(names(fixed), names(specificity))) specificity[[name]] <- NA
  specificity <- specificity[, names(fixed), drop = FALSE]
  rbind(fixed, specificity)
}

g5_imom013_apply_fdr <- function(contrasts, contract = g5_imom013_contract()) {
  contrasts$bh_q_value <- NA_real_
  for (id in contract$contrast_ids) {
    keep <- contrasts$contrast_id == id & contrasts$candidate_fdr
    contrasts$bh_q_value[keep] <- stats::p.adjust(contrasts$centered_null_upper_p[keep], method = "BH")
  }
  contrasts
}

g5_imom013_panel_inference <- function(session_losses, contract = g5_imom013_contract()) {
  x <- session_losses[session_losses$candidate_fdr, , drop = FALSE]
  models_and_contrasts <- c(contract$model_ids, "G10", "S21", "S20", sprintf("W%02d", 1:12))
  panel <- aggregate(
    x[, models_and_contrasts, drop = FALSE],
    by = list(session_date = as.Date(x$session_date)), FUN = mean
  )
  fixed <- do.call(rbind, lapply(seq_len(3L), function(j) {
    id <- contract$contrast_ids[[j]]
    cbind(
      contrast_id = id,
      g5_mom015_stationary_mean(
        panel[[id]], contract$panel_bootstrap_seed,
        contract$bootstrap_count, contract$bootstrap_expected_sessions,
        contract$bootstrap_quantile_type
      )
    )
  }))
  specificity <- cbind(
    contrast_id = "U",
    g5_imom013_specificity_inference(
      panel, contract$panel_bootstrap_seed, contract$bootstrap_count,
      contract$bootstrap_expected_sessions, contract$bootstrap_quantile_type
    )
  )
  for (name in setdiff(names(specificity), names(fixed))) fixed[[name]] <- NA
  for (name in setdiff(names(fixed), names(specificity))) specificity[[name]] <- NA
  specificity <- specificity[, names(fixed), drop = FALSE]
  list(session_losses = panel, contrasts = rbind(fixed, specificity))
}

g5_imom013_decisions <- function(contrasts, coefficient_summary, registry, contract = g5_imom013_contract()) {
  assets <- registry[!registry$benchmark_only, , drop = FALSE]
  rows <- lapply(seq_len(nrow(assets)), function(i) {
    identity <- assets[i, , drop = FALSE]
    x <- contrasts[contrasts$analysis_id == identity$analysis_id, , drop = FALSE]
    coef <- coefficient_summary[coefficient_summary$analysis_id == identity$analysis_id, , drop = FALSE]
    get <- function(id) x[x$contrast_id == id, , drop = FALSE]
    values <- setNames(lapply(contract$contrast_ids, get), contract$contrast_ids)
    complete <- all(vapply(values, nrow, integer(1)) == 1L) && nrow(coef) == 1L
    passes <- function(row) nrow(row) == 1L && row$observed_mean_differential > 0 &&
      row$ci_lower_90 > 0 && is.finite(row$bh_q_value) && row$bh_q_value <= contract$fdr_q
    candidate <- complete && identity$candidate_fdr && passes(values$S21) &&
      passes(values$S20) && passes(values$U) && coef$same_slot_coefficient > 0
    general <- complete && identity$candidate_fdr && passes(values$G10)
    data.frame(
      analysis_id = identity$analysis_id, symbol = identity$symbol, sector = identity$sector,
      analysis_stratum = identity$analysis_stratum, candidate_fdr = identity$candidate_fdr,
      comparison_complete = complete,
      g10_mean = values$G10$observed_mean_differential,
      s21_mean = values$S21$observed_mean_differential,
      s20_mean = values$S20$observed_mean_differential,
      u_mean = values$U$observed_mean_differential,
      g10_q = values$G10$bh_q_value, s21_q = values$S21$bh_q_value,
      s20_q = values$S20$bh_q_value, u_q = values$U$bh_q_value,
      same_slot_coefficient = coef$same_slot_coefficient,
      general_day_clue = general,
      is_same_slot_candidate = candidate,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_imom013_run_comparison <- function(bars, registry, contract = g5_imom013_contract()) {
  contract <- g5_imom013_validate_contract(contract)
  registry <- g5_imom013_validate_registry(registry, contract)
  bars <- g5_imom013_prepare_bars(bars, registry, contract)
  calendar <- g5_imom013_session_calendar(bars, registry, contract)
  ledger <- g5_imom013_coverage_ledger(bars, registry, calendar, contract)
  if (!all(ledger$mechanically_eligible)) g5_imom013_stop("Frozen common panel failed mechanical eligibility.")
  fitted_assets <- registry[!registry$benchmark_only, , drop = FALSE]
  metrics <- coefficients <- moments <- anchor_losses <- session_losses <- contrasts <- list()
  coefficient_summary <- list()
  tag <- function(x, identity) cbind(
    data.frame(
      analysis_id = rep(unname(identity$analysis_id[[1L]]), nrow(x)),
      symbol = rep(unname(identity$symbol[[1L]]), nrow(x)),
      sector = rep(unname(identity$sector[[1L]]), nrow(x)),
      analysis_stratum = rep(unname(identity$analysis_stratum[[1L]]), nrow(x)),
      candidate_fdr = rep(unname(identity$candidate_fdr[[1L]]), nrow(x)),
      stringsAsFactors = FALSE
    ), x
  )
  for (i in seq_len(nrow(fitted_assets))) {
    identity <- fitted_assets[i, , drop = FALSE]
    panel <- g5_imom013_asset_panel(bars, calendar, identity$symbol, contract)
    fit <- g5_imom013_fit_asset(panel, contract)
    inference <- g5_imom013_contrast_inference(fit$session_losses, identity$order[[1L]], contract)
    same_coef <- fit$coefficients$coefficient[
      fit$coefficients$model_id == "M2_SAME" & fit$coefficients$feature == "same_slot"
    ]
    coefficient_summary[[identity$analysis_id]] <- tag(data.frame(
      same_slot_coefficient = same_coef,
      same_slot_coefficient_positive = same_coef > 0,
      stringsAsFactors = FALSE
    ), identity)
    metrics[[identity$analysis_id]] <- tag(fit$metrics, identity)
    coefficients[[identity$analysis_id]] <- tag(fit$coefficients, identity)
    moments[[identity$analysis_id]] <- tag(fit$moments, identity)
    anchor_losses[[identity$analysis_id]] <- tag(fit$anchor_losses, identity)
    session_losses[[identity$analysis_id]] <- tag(fit$session_losses, identity)
    contrasts[[identity$analysis_id]] <- tag(inference, identity)
  }
  bind <- function(x) if (length(x)) do.call(rbind, x) else data.frame()
  metrics <- bind(metrics); coefficients <- bind(coefficients); moments <- bind(moments)
  anchor_losses <- bind(anchor_losses); session_losses <- bind(session_losses)
  coefficient_summary <- bind(coefficient_summary)
  contrast_table <- g5_imom013_apply_fdr(bind(contrasts), contract)
  decisions <- g5_imom013_decisions(contrast_table, coefficient_summary, registry, contract)
  panel <- g5_imom013_panel_inference(session_losses, contract)
  panel_values <- setNames(lapply(contract$contrast_ids, function(id) {
    panel$contrasts[panel$contrasts$contrast_id == id, , drop = FALSE]
  }), contract$contrast_ids)
  candidate_rows <- decisions[decisions$candidate_fdr, , drop = FALSE]
  panel_pass <- function(row) row$observed_mean_differential > 0 && row$ci_lower_90 > 0 &&
    row$centered_null_upper_p <= contract$panel_p
  broad_clue <- all(vapply(panel_values[c("S21", "S20", "U")], panel_pass, logical(1))) &&
    stats::median(candidate_rows$s21_mean) > 0 && stats::median(candidate_rows$u_mean) > 0 &&
    stats::median(candidate_rows$same_slot_coefficient) > 0
  candidates <- decisions[decisions$is_same_slot_candidate, , drop = FALSE]
  general_clues <- decisions[decisions$general_day_clue, , drop = FALSE]
  status <- if (broad_clue || nrow(candidates)) {
    "DEVELOPMENT_COMPLETE_LIT_IMOM_01_3_SAME_SLOT_RELATIVE_MOMENTUM_CLUES"
  } else {
    "STOP_LIT_IMOM_01_3_NO_CLOCK_SPECIFIC_RELATIVE_MOMENTUM"
  }
  placebo_summary <- do.call(rbind, lapply(unique(session_losses$analysis_id), function(id) {
    x <- session_losses[session_losses$analysis_id == id, , drop = FALSE]
    identity <- unique(x[, c("analysis_id", "symbol", "sector", "analysis_stratum", "candidate_fdr")])
    cbind(identity[rep(1L, 12L), , drop = FALSE], data.frame(
      offset = 1:12,
      mean_improvement_over_day = vapply(1:12, function(k) mean(x[[sprintf("W%02d", k)]]), numeric(1)),
      stringsAsFactors = FALSE
    ))
  }))
  slot_diagnostics <- aggregate(
    anchor_losses$M1_DAY - anchor_losses$M2_SAME,
    by = list(
      analysis_id = anchor_losses$analysis_id, symbol = anchor_losses$symbol,
      candidate_fdr = anchor_losses$candidate_fdr, target_slot = anchor_losses$target_slot
    ), FUN = mean
  )
  names(slot_diagnostics)[5L] <- "same_slot_improvement_over_day"
  list(
    contract = contract, registry = registry, session_calendar = calendar,
    ledger = ledger, metrics = metrics, coefficients = coefficients,
    feature_moments = moments, anchor_losses = anchor_losses,
    session_losses = session_losses, contrasts = contrast_table,
    coefficient_summary = coefficient_summary, decisions = decisions,
    candidates = candidates, general_day_clues = general_clues,
    panel_session_losses = panel$session_losses, panel_contrasts = panel$contrasts,
    broad_panel_clue = broad_clue, placebo_summary = placebo_summary,
    slot_diagnostics = slot_diagnostics, overall_status = status,
    confirmation_opened = FALSE
  )
}
