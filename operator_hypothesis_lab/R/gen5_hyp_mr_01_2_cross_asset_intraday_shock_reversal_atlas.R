# Frozen HYP-MR-01.2 cross-asset intraday-shock reversal atlas helpers.
# Source gen5_hyp_mr_01_1_qqq_intraday_shock_reversal.R first.

g5_hmr012_stop <- function(message) stop(message, call. = FALSE)

g5_hmr012_schema_version <- function() "gen5_hyp_mr_01_2_v1"

g5_hmr012_contract <- function() {
  list(
    hypothesis_id = "HYP-MR-01.2",
    parent_hypothesis_id = "HYP-MR-01.1",
    descriptive_name = "Cross-Asset Intraday-Shock Reversal Atlas",
    expected_asset_count = 36L,
    expected_category_count = 9L,
    assets_per_category = 4L,
    as_of_timestamp = "2026-08-23 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    confirmation_end = as.Date("2025-12-31"),
    atr_sessions = 20L,
    fold_years = 2018:2020,
    minimum_train_anchors = 900L,
    minimum_development_anchors = 600L,
    circular_shift_minimum = 60L,
    null_percentile = 0.90,
    quantile_type = 7L,
    influence_tail_fraction = 0.01,
    train_direction_fraction_gate = 0.60,
    train_positive_asset_fraction_gate = 0.50,
    train_multi_fold_fraction_gate = 0.50,
    development_direction_fraction_gate = 0.60,
    development_positive_asset_fraction_gate = 0.50,
    development_positive_category_count = 5L,
    development_positive_year_count = 2L,
    bootstrap_count = 10000L,
    bootstrap_seed = 110102L,
    development_probability_gate = 0.90
  )
}

g5_hmr012_validate_contract <- function(contract = g5_hmr012_contract()) {
  frozen <- g5_hmr012_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_hmr012_stop("Frozen HYP-MR-01.2 contract field set changed.")
  }
  same <- vapply(names(frozen), function(field) identical(contract[[field]], frozen[[field]]), logical(1))
  if (!all(same)) {
    g5_hmr012_stop(paste(
      "Frozen HYP-MR-01.2 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_hmr012_expected_registry <- function() {
  data.frame(
    atlas_order = seq_len(36L),
    source_order = c(
      2L, 3L, 4L, 9L, 11L, 12L, 13L, 14L, 21L, 22L, 23L, 24L,
      1L, 35L, 36L, 37L, 5L, 48L, 49L, 50L, 6L, 7L, 58L, 59L,
      8L, 64L, 65L, 66L, 69L, 70L, 71L, 72L, 75L, 76L, 77L, 78L
    ),
    source_instance_id = c(
      "OG002_SPY", "OG003_QQQ", "OG004_IWM", "OG009_DIA",
      "OG011_XLB", "OG012_XLE", "OG013_XLF", "OG014_XLI",
      "OG021_SMH", "OG022_XBI", "OG023_KRE", "OG024_XRT",
      "OG001_FEZ", "OG035_VGK", "OG036_EFA", "OG037_EEM",
      "OG005_TLT", "OG048_SHY", "OG049_IEI", "OG050_IEF",
      "OG006_GLD", "OG007_USO", "OG058_SLV", "OG059_DBA",
      "OG008_UUP", "OG064_FXE", "OG065_FXY", "OG066_FXB",
      "OG069_UPRO", "OG070_TQQQ", "OG071_TNA", "OG072_SPXU",
      "OG075_MSFT", "OG076_TXN", "OG077_JPM", "OG078_AXP"
    ),
    symbol = c(
      "SPY", "QQQ", "IWM", "DIA", "XLB", "XLE", "XLF", "XLI",
      "SMH", "XBI", "KRE", "XRT", "FEZ", "VGK", "EFA", "EEM",
      "TLT", "SHY", "IEI", "IEF", "GLD", "USO", "SLV", "DBA",
      "UUP", "FXE", "FXY", "FXB", "UPRO", "TQQQ", "TNA", "SPXU",
      "MSFT", "TXN", "JPM", "AXP"
    ),
    category = rep(c(
      "Broad US equity", "US sector", "US industry", "International equity",
      "Fixed income", "Commodity", "Currency", "Leveraged or inverse ETF",
      "Individual-stock challenger"
    ), each = 4L),
    instrument_type = c(rep("ETF", 32L), rep("Stock", 4L)),
    selection_rule = rep("first_four_by_source_order_within_category", 36L),
    stringsAsFactors = FALSE
  )
}

g5_hmr012_validate_registry <- function(registry, contract = g5_hmr012_contract()) {
  contract <- g5_hmr012_validate_contract(contract)
  expected <- g5_hmr012_expected_registry()
  required <- names(expected)
  missing <- setdiff(required, names(registry))
  if (length(missing)) g5_hmr012_stop(paste("Atlas registry is missing:", paste(missing, collapse = ", ")))
  x <- registry[required]
  x$atlas_order <- as.integer(x$atlas_order)
  x$source_order <- as.integer(x$source_order)
  for (field in setdiff(required, c("atlas_order", "source_order"))) x[[field]] <- as.character(x[[field]])
  x <- x[order(x$atlas_order), , drop = FALSE]
  row.names(x) <- NULL
  if (!identical(x, expected)) g5_hmr012_stop("Frozen HYP-MR-01.2 atlas registry changed.")
  if (nrow(x) != contract$expected_asset_count || length(unique(x$category)) != contract$expected_category_count) {
    g5_hmr012_stop("Frozen HYP-MR-01.2 atlas dimensions changed.")
  }
  category_counts <- table(x$category)
  if (!all(category_counts == contract$assets_per_category)) {
    g5_hmr012_stop("Every frozen atlas category must contain exactly four assets.")
  }
  x
}

g5_hmr012_validate_symbol_bars <- function(bars, symbol, maximum_allowed_date, contract = g5_hmr012_contract()) {
  contract <- g5_hmr012_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_hmr012_stop(paste("Missing required bar columns:", paste(missing, collapse = ", ")))
  x <- bars[as.character(bars$symbol) == symbol, required, drop = FALSE]
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  numeric_fields <- c("open", "high", "low", "close", "volume")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  x <- x[order(x$session_date), , drop = FALSE]
  duplicate_count <- sum(duplicated(x$session_date))
  strict_order <- nrow(x) > 1L && all(diff(x$session_date) > 0)
  finite_positive <- nrow(x) > 0L && all(is.finite(as.matrix(x[numeric_fields]))) && all(as.matrix(x[numeric_fields]) > 0)
  checks <- data.frame(
    symbol = symbol,
    check_id = c(
      "exact_symbol", "strict_date_order", "unique_sessions", "positive_finite_ohlcv",
      "adjusted_daily_only", "query_start_covered", "maximum_date_seal"
    ),
    passed = c(
      nrow(x) > 0L && identical(unique(x$symbol), symbol),
      strict_order,
      duplicate_count == 0L,
      finite_positive,
      nrow(x) > 0L && all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      nrow(x) > 0L && min(x$session_date) <= contract$query_start,
      nrow(x) > 0L && max(x$session_date) <= as.Date(maximum_allowed_date)
    ),
    observed = c(
      paste(unique(x$symbol), collapse = ","), as.character(strict_order),
      as.character(duplicate_count),
      if (nrow(x)) paste(range(as.matrix(x[numeric_fields])), collapse = " to ") else "none",
      paste(unique(paste(x$adjusted, x$timeframe, sep = "/")), collapse = ","),
      if (nrow(x)) as.character(min(x$session_date)) else "none",
      if (nrow(x)) as.character(max(x$session_date)) else "none"
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_hmr012_stop(paste(symbol, "bar validation failed:", paste(checks$check_id[!checks$passed], collapse = ", ")))
  }
  list(bars = x, checks = checks)
}

g5_hmr012_zone_panel <- function(
  bars, symbol, zone_start, zone_end, minimum_anchors,
  maximum_allowed_date = zone_end, contract = g5_hmr012_contract()
) {
  checked <- g5_hmr012_validate_symbol_bars(bars, symbol, maximum_allowed_date, contract)
  x <- checked$bars
  atr <- g5_hmr011_prior_atr(x$high, x$low, x$close, contract$atr_sessions)
  x$true_range <- atr$true_range
  x$prior_atr <- atr$prior_atr
  x$prior_atr_pct <- x$prior_atr / c(NA_real_, x$close[-nrow(x)])
  index <- if (nrow(x) > 1L) seq_len(nrow(x) - 1L) else integer()
  anchor_i <- index[
    x$session_date[index] >= as.Date(zone_start) &
      x$session_date[index + 1L] <= as.Date(zone_end) &
      is.finite(x$prior_atr_pct[index]) & x$prior_atr_pct[index] > 0
  ]
  if (length(anchor_i) < as.integer(minimum_anchors)) {
    g5_hmr012_stop(paste("Insufficient", symbol, "anchors in zone:", length(anchor_i)))
  }
  panel <- data.frame(
    symbol = symbol,
    anchor_date = x$session_date[anchor_i],
    target_date = x$session_date[anchor_i + 1L],
    x = log(x$close[anchor_i] / x$open[anchor_i]) / x$prior_atr_pct[anchor_i],
    y = log(x$close[anchor_i + 1L] / x$open[anchor_i + 1L]),
    current_intraday_return = log(x$close[anchor_i] / x$open[anchor_i]),
    prior_atr_pct = x$prior_atr_pct[anchor_i],
    stringsAsFactors = FALSE
  )
  checks <- data.frame(
    symbol = symbol,
    check_id = c("finite_feature_target", "positive_prior_atr", "exact_next_session_alignment", "signal_target_boundary"),
    passed = c(
      all(is.finite(as.matrix(panel[c("x", "y", "current_intraday_return", "prior_atr_pct")]))),
      all(panel$prior_atr_pct > 0),
      identical(panel$target_date, x$session_date[anchor_i + 1L]),
      all(panel$anchor_date < panel$target_date)
    ),
    observed = c(
      paste0("anchors=", nrow(panel)), paste(range(panel$prior_atr_pct), collapse = " to "),
      paste0(min(panel$target_date), " to ", max(panel$target_date)),
      "feature_after_close_t;target_open_to_close_t_plus_1"
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) g5_hmr012_stop(paste(symbol, "construction failed."))
  list(panel = panel, integrity = checked$checks, construction = checks)
}

g5_hmr012_prepare_atlas_panels <- function(
  bars, registry, zone_start, zone_end, minimum_anchors,
  maximum_allowed_date = zone_end, contract = g5_hmr012_contract()
) {
  registry <- g5_hmr012_validate_registry(registry, contract)
  bundles <- lapply(registry$symbol, function(symbol) {
    g5_hmr012_zone_panel(
      bars, symbol, zone_start, zone_end, minimum_anchors,
      maximum_allowed_date, contract
    )
  })
  names(bundles) <- registry$symbol
  keys <- lapply(bundles, function(bundle) paste(bundle$panel$anchor_date, bundle$panel$target_date, sep = "|"))
  common <- Reduce(intersect, keys)
  common_dates <- as.Date(sub("\\|.*$", "", common))
  common <- common[order(common_dates)]
  if (length(common) < as.integer(minimum_anchors)) {
    g5_hmr012_stop(paste("Common atlas calendar has insufficient anchors:", length(common)))
  }
  panels <- lapply(names(bundles), function(symbol) {
    panel <- bundles[[symbol]]$panel
    key <- paste(panel$anchor_date, panel$target_date, sep = "|")
    index <- match(common, key)
    if (anyNA(index)) g5_hmr012_stop(paste("Common calendar alignment failed for", symbol))
    panel[index, , drop = FALSE]
  })
  names(panels) <- names(bundles)
  reference_dates <- panels[[1L]][c("anchor_date", "target_date")]
  exact <- vapply(panels, function(panel) identical(panel[c("anchor_date", "target_date")], reference_dates), logical(1))
  alignment <- data.frame(
    symbol = names(bundles),
    original_rows = vapply(bundles, function(bundle) nrow(bundle$panel), integer(1)),
    common_rows = vapply(panels, nrow, integer(1)),
    dropped_for_common_calendar = vapply(bundles, function(bundle) nrow(bundle$panel), integer(1)) - length(common),
    exact_common_calendar = exact,
    stringsAsFactors = FALSE
  )
  if (!all(exact)) g5_hmr012_stop("Atlas panels do not share the exact common calendar.")
  list(
    panels = panels,
    integrity = do.call(rbind, lapply(bundles, `[[`, "integrity")),
    construction = do.call(rbind, lapply(bundles, `[[`, "construction")),
    alignment = alignment
  )
}

g5_hmr012_expanding_predictions <- function(panel, contract = g5_hmr012_contract()) {
  rows <- list()
  for (i in seq_along(contract$fold_years)) {
    year <- contract$fold_years[[i]]
    year_start <- as.Date(sprintf("%d-01-01", year))
    year_end <- as.Date(sprintf("%d-12-31", year))
    train <- panel[panel$target_date < year_start, , drop = FALSE]
    score <- panel[panel$target_date >= year_start & panel$target_date <= year_end, , drop = FALSE]
    if (nrow(train) < 200L || nrow(score) < 200L) g5_hmr012_stop(paste("Insufficient fold rows for", year))
    model <- g5_hmr011_fit(train)
    drift <- mean(train$y)
    model_prediction <- g5_hmr011_predict(model, score$x)
    rows[[i]] <- data.frame(
      symbol = score$symbol,
      anchor_date = score$anchor_date,
      target_date = score$target_date,
      fold_year = year,
      x = score$x,
      y = score$y,
      training_rows = nrow(train),
      fold_alpha = model$alpha,
      fold_beta = model$beta,
      drift_prediction = drift,
      model_prediction = model_prediction,
      drift_squared_error = (score$y - drift)^2,
      model_squared_error = (score$y - model_prediction)^2,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  out$loss_improvement <- out$drift_squared_error - out$model_squared_error
  out
}

g5_hmr012_fold_metrics <- function(predictions) {
  do.call(rbind, lapply(split(predictions, predictions$fold_year), function(x) {
    drift_mse <- mean(x$drift_squared_error)
    reversal_mse <- mean(x$model_squared_error)
    data.frame(
      symbol = x$symbol[[1L]], fold_year = x$fold_year[[1L]],
      training_rows = x$training_rows[[1L]], scored_rows = nrow(x),
      fitted_beta = x$fold_beta[[1L]], drift_mse = drift_mse,
      reversal_mse = reversal_mse,
      mse_improvement = drift_mse - reversal_mse,
      relative_mse_improvement = (drift_mse - reversal_mse) / drift_mse,
      stringsAsFactors = FALSE
    )
  }))
}

g5_hmr012_asset_train <- function(panel, contract = g5_hmr012_contract()) {
  statistics <- g5_hmr011_full_statistics(panel)
  predictions <- g5_hmr012_expanding_predictions(panel, contract)
  folds <- g5_hmr012_fold_metrics(predictions)
  drift_mse <- mean(predictions$drift_squared_error)
  reversal_mse <- mean(predictions$model_squared_error)
  influence_contract <- list(
    influence_tail_fraction = contract$influence_tail_fraction,
    quantile_type = contract$quantile_type
  )
  influence <- g5_hmr011_influence_audit(panel, influence_contract)
  summary <- data.frame(
    symbol = panel$symbol[[1L]],
    anchor_count = nrow(panel),
    alpha = statistics$alpha[[1L]],
    beta = statistics$beta[[1L]],
    pearson = statistics$pearson[[1L]],
    spearman = statistics$spearman[[1L]],
    drift_mse = drift_mse,
    reversal_mse = reversal_mse,
    mse_improvement = drift_mse - reversal_mse,
    relative_mse_improvement = (drift_mse - reversal_mse) / drift_mse,
    positive_fold_count = sum(folds$relative_mse_improvement > 0),
    influence_excluded_beta = influence$influence_excluded_beta[[1L]],
    influence_excluded_spearman = influence$influence_excluded_spearman[[1L]],
    influence_excluded_rows = influence$excluded_rows[[1L]],
    stringsAsFactors = FALSE
  )
  list(summary = summary, folds = folds, predictions = predictions, influence = influence)
}

g5_hmr012_expanding_relative_fast <- function(panel, y, contract = g5_hmr012_contract()) {
  drift_error <- numeric()
  model_error <- numeric()
  for (year in contract$fold_years) {
    year_start <- as.Date(sprintf("%d-01-01", year))
    year_end <- as.Date(sprintf("%d-12-31", year))
    train_index <- panel$target_date < year_start
    score_index <- panel$target_date >= year_start & panel$target_date <= year_end
    train_x <- panel$x[train_index]
    train_y <- y[train_index]
    score_x <- panel$x[score_index]
    score_y <- y[score_index]
    if (length(train_y) < 200L || length(score_y) < 200L) g5_hmr012_stop(paste("Insufficient fast fold rows for", year))
    x_centered <- train_x - mean(train_x)
    denominator <- sum(x_centered^2)
    if (!is.finite(denominator) || denominator <= 0) g5_hmr012_stop("Fast shift fit is rank deficient.")
    beta <- sum(x_centered * (train_y - mean(train_y))) / denominator
    alpha <- mean(train_y) - beta * mean(train_x)
    drift <- mean(train_y)
    drift_error <- c(drift_error, (score_y - drift)^2)
    model_error <- c(model_error, (score_y - alpha - beta * score_x)^2)
  }
  drift_mse <- mean(drift_error)
  reversal_mse <- mean(model_error)
  (drift_mse - reversal_mse) / drift_mse
}

g5_hmr012_shift_asset_stat <- function(panel, shift, contract = g5_hmr012_contract()) {
  shifted_y <- g5_hmr011_rotate(panel$y, shift)
  g5_hmr012_expanding_relative_fast(panel, shifted_y, contract)
}

g5_hmr012_common_shift_null <- function(
  panels, observed_asset_summary, contract = g5_hmr012_contract(), shift_values = NULL
) {
  n <- unique(vapply(panels, nrow, integer(1)))
  if (length(n) != 1L) g5_hmr012_stop("Common shift null requires equal panel rows.")
  shifts <- if (is.null(shift_values)) {
    g5_hmr011_admissible_shifts(n, contract$circular_shift_minimum)
  } else {
    as.integer(shift_values)
  }
  admissible <- g5_hmr011_admissible_shifts(n, contract$circular_shift_minimum)
  if (!length(shifts) || any(!shifts %in% admissible)) g5_hmr012_stop("Invalid atlas shift values.")
  long_rows <- vector("list", length(shifts))
  aggregate_rows <- vector("list", length(shifts))
  for (i in seq_along(shifts)) {
    shift <- shifts[[i]]
    values <- vapply(panels, g5_hmr012_shift_asset_stat, numeric(1), shift = shift, contract = contract)
    long_rows[[i]] <- data.frame(
      shift = shift,
      circular_displacement = pmin(shift, n - shift),
      symbol = names(values),
      relative_mse_improvement = unname(values),
      stringsAsFactors = FALSE
    )
    aggregate_rows[[i]] <- data.frame(
      shift = shift,
      circular_displacement = pmin(shift, n - shift),
      median_relative_improvement = stats::median(values),
      positive_asset_fraction = mean(values > 0),
      stringsAsFactors = FALSE
    )
  }
  long <- do.call(rbind, long_rows)
  aggregate <- do.call(rbind, aggregate_rows)
  observed_median <- stats::median(observed_asset_summary$relative_mse_improvement)
  observed_fraction <- mean(observed_asset_summary$relative_mse_improvement > 0)
  median_p90 <- as.numeric(stats::quantile(
    aggregate$median_relative_improvement, contract$null_percentile,
    type = contract$quantile_type, names = FALSE
  ))
  fraction_p90 <- as.numeric(stats::quantile(
    aggregate$positive_asset_fraction, contract$null_percentile,
    type = contract$quantile_type, names = FALSE
  ))
  decision <- data.frame(
    observed_median_relative_improvement = observed_median,
    median_shift_p90 = median_p90,
    median_upper_tail_probability = (1 + sum(aggregate$median_relative_improvement >= observed_median)) / (1 + nrow(aggregate)),
    observed_positive_asset_fraction = observed_fraction,
    positive_fraction_shift_p90 = fraction_p90,
    positive_fraction_upper_tail_probability = (1 + sum(aggregate$positive_asset_fraction >= observed_fraction)) / (1 + nrow(aggregate)),
    eligible_shift_count = nrow(aggregate),
    timing_specificity_passed = observed_median > median_p90 && observed_fraction > fraction_p90,
    stringsAsFactors = FALSE
  )
  asset_shift <- do.call(rbind, lapply(split(long, long$symbol), function(x) {
    observed <- observed_asset_summary$relative_mse_improvement[match(x$symbol[[1L]], observed_asset_summary$symbol)]
    data.frame(
      symbol = x$symbol[[1L]],
      observed_relative_improvement = observed,
      shift_p90 = as.numeric(stats::quantile(x$relative_mse_improvement, contract$null_percentile, type = contract$quantile_type)),
      shift_percentile = (1 + sum(x$relative_mse_improvement <= observed)) / (1 + nrow(x)),
      upper_tail_probability = (1 + sum(x$relative_mse_improvement >= observed)) / (1 + nrow(x)),
      stringsAsFactors = FALSE
    )
  }))
  list(long = long, aggregate = aggregate, asset_summary = asset_shift, decision = decision)
}

g5_hmr012_category_train_summary <- function(asset_summary, registry) {
  x <- merge(registry[c("atlas_order", "symbol", "category")], asset_summary, by = "symbol", sort = FALSE)
  x <- x[order(x$atlas_order), , drop = FALSE]
  do.call(rbind, lapply(split(x, x$category), function(z) {
    data.frame(
      category = z$category[[1L]], asset_count = nrow(z),
      median_beta = stats::median(z$beta), negative_beta_fraction = mean(z$beta < 0),
      median_spearman = stats::median(z$spearman), negative_spearman_fraction = mean(z$spearman < 0),
      median_relative_mse_improvement = stats::median(z$relative_mse_improvement),
      positive_asset_fraction = mean(z$relative_mse_improvement > 0),
      median_positive_fold_count = stats::median(z$positive_fold_count),
      stringsAsFactors = FALSE
    )
  }))
}

g5_hmr012_run_train_panels <- function(
  panels, registry, contract = g5_hmr012_contract(), shift_values = NULL
) {
  contract <- g5_hmr012_validate_contract(contract)
  registry <- g5_hmr012_validate_registry(registry, contract)
  if (!identical(sort(names(panels)), sort(registry$symbol))) g5_hmr012_stop("TRAIN panel symbols changed.")
  asset_results <- lapply(registry$symbol, function(symbol) g5_hmr012_asset_train(panels[[symbol]], contract))
  names(asset_results) <- registry$symbol
  asset_summary <- do.call(rbind, lapply(asset_results, `[[`, "summary"))
  folds <- do.call(rbind, lapply(asset_results, `[[`, "folds"))
  predictions <- do.call(rbind, lapply(asset_results, `[[`, "predictions"))
  shifts <- g5_hmr012_common_shift_null(panels, asset_summary, contract, shift_values)
  category_summary <- g5_hmr012_category_train_summary(asset_summary, registry)
  median_beta <- stats::median(asset_summary$beta)
  negative_beta_fraction <- mean(asset_summary$beta < 0)
  median_spearman <- stats::median(asset_summary$spearman)
  negative_spearman_fraction <- mean(asset_summary$spearman < 0)
  median_improvement <- stats::median(asset_summary$relative_mse_improvement)
  positive_asset_fraction <- mean(asset_summary$relative_mse_improvement > 0)
  median_positive_folds <- stats::median(asset_summary$positive_fold_count)
  multi_fold_fraction <- mean(asset_summary$positive_fold_count >= 2L)
  influence_negative_fraction <- mean(asset_summary$influence_excluded_beta < 0)
  gates <- data.frame(
    gate_id = c(
      "complete_atlas_and_common_calendar", "negative_beta_breadth", "negative_spearman_breadth",
      "positive_relative_loss_breadth", "positive_fold_breadth",
      "common_shift_timing_specificity", "influence_sign_breadth"
    ),
    passed = c(
      length(panels) == contract$expected_asset_count &&
        all(vapply(panels, nrow, integer(1)) >= contract$minimum_train_anchors),
      median_beta < 0 && negative_beta_fraction >= contract$train_direction_fraction_gate,
      median_spearman < 0 && negative_spearman_fraction >= contract$train_direction_fraction_gate,
      median_improvement > 0 && positive_asset_fraction >= contract$train_positive_asset_fraction_gate,
      median_positive_folds >= 2 && multi_fold_fraction >= contract$train_multi_fold_fraction_gate,
      shifts$decision$timing_specificity_passed[[1L]],
      influence_negative_fraction >= contract$train_direction_fraction_gate
    ),
    observed = c(
      paste0(length(panels), " assets;", unique(vapply(panels, nrow, integer(1))), " common rows"),
      paste0("median=", sprintf("%.8f", median_beta), ";negative=", sprintf("%.3f", negative_beta_fraction)),
      paste0("median=", sprintf("%.6f", median_spearman), ";negative=", sprintf("%.3f", negative_spearman_fraction)),
      paste0("median=", sprintf("%.8f", median_improvement), ";positive=", sprintf("%.3f", positive_asset_fraction)),
      paste0("median=", median_positive_folds, ";at_least_two=", sprintf("%.3f", multi_fold_fraction)),
      paste0(
        "median=", sprintf("%.8f", shifts$decision$observed_median_relative_improvement[[1L]]),
        ";p90=", sprintf("%.8f", shifts$decision$median_shift_p90[[1L]]),
        ";fraction=", sprintf("%.3f", shifts$decision$observed_positive_asset_fraction[[1L]]),
        ";fraction_p90=", sprintf("%.3f", shifts$decision$positive_fraction_shift_p90[[1L]])
      ),
      sprintf("%.3f", influence_negative_fraction)
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  passed <- all(gates$passed)
  overall_status <- if (passed) {
    "TRAIN_PASS_HYP_MR_01_2_DEVELOPMENT_AUTHORIZED"
  } else {
    "STOP_HYP_MR_01_2_ATLAS_TRAIN_BREADTH_GATES_FAILED_DEVELOPMENT_NOT_RUN"
  }
  atlas_summary <- data.frame(
    asset_count = nrow(asset_summary), category_count = nrow(category_summary),
    common_anchor_count = unique(vapply(panels, nrow, integer(1))),
    median_beta = median_beta, negative_beta_fraction = negative_beta_fraction,
    median_spearman = median_spearman, negative_spearman_fraction = negative_spearman_fraction,
    median_relative_mse_improvement = median_improvement,
    positive_asset_fraction = positive_asset_fraction,
    median_positive_fold_count = median_positive_folds,
    multi_fold_fraction = multi_fold_fraction,
    influence_negative_fraction = influence_negative_fraction,
    train_passed = passed, overall_status = overall_status,
    stringsAsFactors = FALSE
  )
  list(
    asset_summary = asset_summary, folds = folds, predictions = predictions,
    category_summary = category_summary, shift_long = shifts$long,
    shift_aggregate = shifts$aggregate, asset_shift_summary = shifts$asset_summary,
    shift_decision = shifts$decision, gates = gates, atlas_summary = atlas_summary,
    overall_status = overall_status
  )
}

g5_hmr012_category_bootstrap <- function(category_improvement, contract = g5_hmr012_contract(), replicates = contract$bootstrap_count) {
  set.seed(contract$bootstrap_seed)
  values <- replicate(as.integer(replicates), stats::median(sample(category_improvement, length(category_improvement), replace = TRUE)))
  data.frame(
    replicates = as.integer(replicates),
    probability_positive = mean(values > 0),
    lower_90 = as.numeric(stats::quantile(values, 0.05, type = contract$quantile_type)),
    upper_90 = as.numeric(stats::quantile(values, 0.95, type = contract$quantile_type)),
    stringsAsFactors = FALSE
  )
}

g5_hmr012_run_development_panels <- function(
  train_panels, development_panels, registry, contract = g5_hmr012_contract(),
  bootstrap_replicates = contract$bootstrap_count
) {
  contract <- g5_hmr012_validate_contract(contract)
  registry <- g5_hmr012_validate_registry(registry, contract)
  if (!identical(sort(names(train_panels)), sort(registry$symbol)) ||
      !identical(sort(names(development_panels)), sort(registry$symbol))) {
    g5_hmr012_stop("DEVELOPMENT panel symbols changed.")
  }
  asset_rows <- list()
  year_rows <- list()
  prediction_rows <- list()
  for (i in seq_along(registry$symbol)) {
    symbol <- registry$symbol[[i]]
    train <- train_panels[[symbol]]
    development <- development_panels[[symbol]]
    model <- g5_hmr011_fit(train)
    drift <- mean(train$y)
    development$model_prediction <- g5_hmr011_predict(model, development$x)
    development$drift_prediction <- drift
    development$model_squared_error <- (development$y - development$model_prediction)^2
    development$drift_squared_error <- (development$y - drift)^2
    development$loss_improvement <- development$drift_squared_error - development$model_squared_error
    development$target_year <- as.integer(format(development$target_date, "%Y"))
    drift_mse <- mean(development$drift_squared_error)
    reversal_mse <- mean(development$model_squared_error)
    asset_rows[[i]] <- data.frame(
      symbol = symbol, row_count = nrow(development),
      frozen_alpha = model$alpha, frozen_beta = model$beta,
      pearson = stats::cor(development$x, development$y),
      spearman = stats::cor(development$x, development$y, method = "spearman"),
      drift_mse = drift_mse, reversal_mse = reversal_mse,
      mse_improvement = drift_mse - reversal_mse,
      relative_mse_improvement = (drift_mse - reversal_mse) / drift_mse,
      stringsAsFactors = FALSE
    )
    year_rows[[i]] <- do.call(rbind, lapply(split(development, development$target_year), function(z) {
      year_drift <- mean(z$drift_squared_error)
      year_reversal <- mean(z$model_squared_error)
      data.frame(
        symbol = symbol, target_year = z$target_year[[1L]], row_count = nrow(z),
        drift_mse = year_drift, reversal_mse = year_reversal,
        mse_improvement = year_drift - year_reversal,
        relative_mse_improvement = (year_drift - year_reversal) / year_drift,
        stringsAsFactors = FALSE
      )
    }))
    prediction_rows[[i]] <- development
  }
  asset_summary <- do.call(rbind, asset_rows)
  asset_years <- do.call(rbind, year_rows)
  predictions <- do.call(rbind, prediction_rows)
  merged <- merge(registry[c("atlas_order", "symbol", "category")], asset_summary, by = "symbol", sort = FALSE)
  merged <- merged[order(merged$atlas_order), , drop = FALSE]
  category_summary <- do.call(rbind, lapply(split(merged, merged$category), function(z) {
    data.frame(
      category = z$category[[1L]], asset_count = nrow(z),
      median_spearman = stats::median(z$spearman),
      negative_spearman_fraction = mean(z$spearman < 0),
      median_relative_mse_improvement = stats::median(z$relative_mse_improvement),
      positive_asset_fraction = mean(z$relative_mse_improvement > 0),
      stringsAsFactors = FALSE
    )
  }))
  year_summary <- do.call(rbind, lapply(split(asset_years, asset_years$target_year), function(z) {
    data.frame(
      target_year = z$target_year[[1L]], asset_count = nrow(z),
      median_relative_mse_improvement = stats::median(z$relative_mse_improvement),
      positive_asset_fraction = mean(z$relative_mse_improvement > 0),
      stringsAsFactors = FALSE
    )
  }))
  bootstrap <- g5_hmr012_category_bootstrap(category_summary$median_relative_mse_improvement, contract, bootstrap_replicates)
  median_spearman <- stats::median(asset_summary$spearman)
  negative_fraction <- mean(asset_summary$spearman < 0)
  median_improvement <- stats::median(asset_summary$relative_mse_improvement)
  positive_fraction <- mean(asset_summary$relative_mse_improvement > 0)
  positive_categories <- sum(category_summary$median_relative_mse_improvement > 0)
  positive_years <- sum(year_summary$median_relative_mse_improvement > 0)
  gates <- data.frame(
    gate_id = c(
      "complete_development_atlas", "negative_development_spearman_breadth",
      "positive_relative_loss_breadth", "positive_category_breadth",
      "positive_calendar_breadth", "category_bootstrap_probability"
    ),
    passed = c(
      nrow(asset_summary) == contract$expected_asset_count && all(asset_summary$row_count >= contract$minimum_development_anchors),
      median_spearman < 0 && negative_fraction >= contract$development_direction_fraction_gate,
      median_improvement > 0 && positive_fraction >= contract$development_positive_asset_fraction_gate,
      positive_categories >= contract$development_positive_category_count,
      positive_years >= contract$development_positive_year_count,
      bootstrap$probability_positive[[1L]] >= contract$development_probability_gate
    ),
    observed = c(
      paste0(nrow(asset_summary), " assets;", unique(asset_summary$row_count), " common rows"),
      paste0("median=", sprintf("%.6f", median_spearman), ";negative=", sprintf("%.3f", negative_fraction)),
      paste0("median=", sprintf("%.8f", median_improvement), ";positive=", sprintf("%.3f", positive_fraction)),
      paste0(positive_categories, "/", nrow(category_summary)),
      paste0(positive_years, "/", nrow(year_summary)),
      sprintf("%.6f", bootstrap$probability_positive[[1L]])
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  passed <- all(gates$passed)
  overall_status <- if (passed) {
    "DEVELOPMENT_PASS_HYP_MR_01_2_CONFIRMATION_REVIEW_REQUIRED"
  } else {
    "STOP_HYP_MR_01_2_ATLAS_DEVELOPMENT_BREADTH_GATES_FAILED_CONFIRMATION_NOT_RUN"
  }
  atlas_summary <- data.frame(
    asset_count = nrow(asset_summary), category_count = nrow(category_summary),
    common_row_count = unique(asset_summary$row_count),
    median_spearman = median_spearman, negative_spearman_fraction = negative_fraction,
    median_relative_mse_improvement = median_improvement,
    positive_asset_fraction = positive_fraction,
    positive_category_count = positive_categories,
    positive_year_count = positive_years,
    bootstrap_probability_positive = bootstrap$probability_positive[[1L]],
    development_passed = passed, overall_status = overall_status,
    stringsAsFactors = FALSE
  )
  list(
    asset_summary = asset_summary, asset_years = asset_years,
    category_summary = category_summary, year_summary = year_summary,
    predictions = predictions, bootstrap = bootstrap, gates = gates,
    atlas_summary = atlas_summary, overall_status = overall_status
  )
}
