# Frozen HYP-MR-01.1 QQQ intraday-shock reversal helpers.

g5_hmr011_stop <- function(message) stop(message, call. = FALSE)

g5_hmr011_schema_version <- function() "gen5_hyp_mr_01_1_v1"

g5_hmr011_contract <- function() {
  list(
    hypothesis_id = "HYP-MR-01.1",
    descriptive_name = "QQQ Intraday-Shock Reversal",
    symbol = "QQQ",
    as_of_timestamp = "2026-08-22 17:30:00 America/New_York",
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
    minimum_positive_folds = 2L,
    minimum_positive_development_years = 2L,
    bootstrap_count = 10000L,
    bootstrap_expected_block = 20,
    bootstrap_seed = 110101L,
    development_probability_gate = 0.90,
    decile_count = 10L
  )
}

g5_hmr011_validate_contract <- function(contract = g5_hmr011_contract()) {
  frozen <- g5_hmr011_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_hmr011_stop("Frozen HYP-MR-01.1 contract field set changed.")
  }
  same <- vapply(names(frozen), function(field) identical(contract[[field]], frozen[[field]]), logical(1))
  if (!all(same)) {
    g5_hmr011_stop(paste(
      "Frozen HYP-MR-01.1 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_hmr011_validate_bars <- function(bars, maximum_allowed_date, contract = g5_hmr011_contract()) {
  contract <- g5_hmr011_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_hmr011_stop(paste("Missing required bar columns:", paste(missing, collapse = ", ")))
  x <- bars[as.character(bars$symbol) == contract$symbol, required, drop = FALSE]
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  numeric_fields <- c("open", "high", "low", "close", "volume")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  x <- x[order(x$session_date), , drop = FALSE]
  duplicate_count <- sum(duplicated(x$session_date))
  strict_order <- nrow(x) > 1L && all(diff(x$session_date) > 0)
  finite_positive <- nrow(x) > 0L && all(is.finite(as.matrix(x[numeric_fields]))) && all(as.matrix(x[numeric_fields]) > 0)
  checks <- data.frame(
    check_id = c(
      "exact_symbol", "strict_date_order", "unique_sessions", "positive_finite_ohlcv",
      "adjusted_daily_only", "query_start_covered", "maximum_date_seal"
    ),
    passed = c(
      nrow(x) > 0L && identical(unique(x$symbol), contract$symbol),
      strict_order,
      duplicate_count == 0L,
      finite_positive,
      nrow(x) > 0L && all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      nrow(x) > 0L && min(x$session_date) <= contract$query_start,
      nrow(x) > 0L && max(x$session_date) <= as.Date(maximum_allowed_date)
    ),
    observed = c(
      paste(unique(x$symbol), collapse = ","),
      as.character(strict_order),
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
    g5_hmr011_stop(paste("HYP-MR-01.1 bar validation failed:", paste(checks$check_id[!checks$passed], collapse = ", ")))
  }
  list(bars = x, checks = checks)
}

g5_hmr011_prior_atr <- function(high, low, close, sessions) {
  n <- length(close)
  previous_close <- c(NA_real_, close[-n])
  true_range <- pmax(high - low, abs(high - previous_close), abs(low - previous_close), na.rm = TRUE)
  true_range[[1L]] <- NA_real_
  prior_atr <- rep(NA_real_, n)
  if (n > sessions + 1L) {
    for (i in seq.int(sessions + 2L, n)) {
      prior_atr[[i]] <- mean(true_range[(i - sessions):(i - 1L)])
    }
  }
  data.frame(true_range = true_range, prior_atr = prior_atr, stringsAsFactors = FALSE)
}

g5_hmr011_zone_panel <- function(
  bars,
  zone_start,
  zone_end,
  minimum_anchors,
  maximum_allowed_date = zone_end,
  contract = g5_hmr011_contract()
) {
  checked <- g5_hmr011_validate_bars(bars, maximum_allowed_date, contract)
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
    g5_hmr011_stop(paste("Insufficient HYP-MR-01.1 anchors in zone:", length(anchor_i)))
  }
  panel <- data.frame(
    anchor_date = x$session_date[anchor_i],
    target_date = x$session_date[anchor_i + 1L],
    x = log(x$close[anchor_i] / x$open[anchor_i]) / x$prior_atr_pct[anchor_i],
    y = log(x$close[anchor_i + 1L] / x$open[anchor_i + 1L]),
    current_intraday_return = log(x$close[anchor_i] / x$open[anchor_i]),
    prior_atr_pct = x$prior_atr_pct[anchor_i],
    current_open = x$open[anchor_i],
    current_close = x$close[anchor_i],
    next_open = x$open[anchor_i + 1L],
    next_close = x$close[anchor_i + 1L],
    stringsAsFactors = FALSE
  )
  finite <- all(is.finite(as.matrix(panel[c("x", "y", "current_intraday_return", "prior_atr_pct")])))
  exact_alignment <- all(panel$target_date > panel$anchor_date) &&
    identical(panel$target_date, x$session_date[anchor_i + 1L])
  checks <- data.frame(
    check_id = c("finite_feature_target", "positive_prior_atr", "exact_next_session_alignment", "signal_target_boundary"),
    passed = c(
      finite,
      all(is.finite(panel$prior_atr_pct) & panel$prior_atr_pct > 0),
      exact_alignment,
      all(panel$anchor_date < panel$target_date)
    ),
    observed = c(
      paste0("anchors=", nrow(panel)),
      paste(range(panel$prior_atr_pct), collapse = " to "),
      paste0(min(panel$target_date), " to ", max(panel$target_date)),
      "feature_after_close_t;target_open_to_close_t_plus_1"
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_hmr011_stop(paste("HYP-MR-01.1 construction failed:", paste(checks$check_id[!checks$passed], collapse = ", ")))
  }
  list(bars = x, anchor_index = anchor_i, panel = panel, integrity = checked$checks, construction_checks = checks)
}

g5_hmr011_fit <- function(data) {
  if (!all(c("x", "y") %in% names(data))) g5_hmr011_stop("Model data require x and y.")
  fit <- stats::lm.fit(cbind(1, data$x), data$y)
  if (fit$rank < 2L || any(!is.finite(fit$coefficients))) g5_hmr011_stop("HYP-MR-01.1 model is rank deficient.")
  list(alpha = unname(fit$coefficients[[1L]]), beta = unname(fit$coefficients[[2L]]))
}

g5_hmr011_predict <- function(model, x) model$alpha + model$beta * x

g5_hmr011_expanding_predictions <- function(panel, contract = g5_hmr011_contract()) {
  rows <- list()
  for (i in seq_along(contract$fold_years)) {
    year <- contract$fold_years[[i]]
    year_start <- as.Date(sprintf("%d-01-01", year))
    year_end <- as.Date(sprintf("%d-12-31", year))
    train <- panel[panel$target_date < year_start, , drop = FALSE]
    score <- panel[panel$target_date >= year_start & panel$target_date <= year_end, , drop = FALSE]
    if (nrow(train) < 200L || nrow(score) < 200L) {
      g5_hmr011_stop(paste("Insufficient expanding-fold rows for", year))
    }
    model <- g5_hmr011_fit(train)
    drift <- mean(train$y)
    model_prediction <- g5_hmr011_predict(model, score$x)
    rows[[i]] <- data.frame(
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

g5_hmr011_fold_metrics <- function(predictions) {
  rows <- lapply(split(predictions, predictions$fold_year), function(x) {
    data.frame(
      fold_year = x$fold_year[[1L]],
      training_rows = x$training_rows[[1L]],
      scored_rows = nrow(x),
      fitted_beta = x$fold_beta[[1L]],
      drift_mse = mean(x$drift_squared_error),
      reversal_mse = mean(x$model_squared_error),
      mse_improvement = mean(x$loss_improvement),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_hmr011_full_statistics <- function(panel) {
  model <- g5_hmr011_fit(panel)
  data.frame(
    anchor_count = nrow(panel),
    alpha = model$alpha,
    beta = model$beta,
    pearson = stats::cor(panel$x, panel$y),
    spearman = stats::cor(panel$x, panel$y, method = "spearman"),
    stringsAsFactors = FALSE
  )
}

g5_hmr011_influence_audit <- function(panel, contract = g5_hmr011_contract()) {
  cutoff <- as.numeric(stats::quantile(
    abs(panel$x), 1 - contract$influence_tail_fraction,
    type = contract$quantile_type, names = FALSE
  ))
  retained <- panel[abs(panel$x) <= cutoff, , drop = FALSE]
  fit <- g5_hmr011_fit(retained)
  data.frame(
    cutoff_abs_x = cutoff,
    excluded_rows = nrow(panel) - nrow(retained),
    retained_rows = nrow(retained),
    retained_fraction = nrow(retained) / nrow(panel),
    influence_excluded_beta = fit$beta,
    influence_excluded_spearman = stats::cor(retained$x, retained$y, method = "spearman"),
    stringsAsFactors = FALSE
  )
}

g5_hmr011_deciles <- function(panel, contract = g5_hmr011_contract()) {
  rank <- rank(panel$x, ties.method = "first")
  decile <- pmin(contract$decile_count, ceiling(rank * contract$decile_count / nrow(panel)))
  rows <- lapply(split(seq_len(nrow(panel)), decile), function(index) {
    data.frame(
      predictor_decile = decile[index[[1L]]],
      row_count = length(index),
      mean_x = mean(panel$x[index]),
      mean_target = mean(panel$y[index]),
      median_target = stats::median(panel$y[index]),
      positive_target_fraction = mean(panel$y[index] > 0),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_hmr011_rotate <- function(x, shift) {
  n <- length(x)
  x[((seq_len(n) - 1L + as.integer(shift)) %% n) + 1L]
}

g5_hmr011_admissible_shifts <- function(n, minimum_displacement) {
  shifts <- seq_len(n - 1L)
  shifts[pmin(shifts, n - shifts) >= as.integer(minimum_displacement)]
}

g5_hmr011_shift_test <- function(panel, observed_improvement, contract = g5_hmr011_contract()) {
  shifts <- g5_hmr011_admissible_shifts(nrow(panel), contract$circular_shift_minimum)
  null <- vapply(shifts, function(shift) {
    shifted <- panel
    shifted$y <- g5_hmr011_rotate(panel$y, shift)
    mean(g5_hmr011_expanding_predictions(shifted, contract)$loss_improvement)
  }, numeric(1))
  distribution <- data.frame(
    shift = shifts,
    circular_displacement = pmin(shifts, nrow(panel) - shifts),
    oof_mse_improvement = null,
    stringsAsFactors = FALSE
  )
  threshold <- as.numeric(stats::quantile(
    null, contract$null_percentile, type = contract$quantile_type, names = FALSE
  ))
  decision <- data.frame(
    observed_oof_mse_improvement = observed_improvement,
    shift_p90 = threshold,
    empirical_upper_tail_probability = (1 + sum(null >= observed_improvement)) / (1 + length(null)),
    eligible_shift_count = length(shifts),
    timing_specificity_passed = is.finite(observed_improvement) && observed_improvement > threshold,
    stringsAsFactors = FALSE
  )
  list(distribution = distribution, decision = decision)
}

g5_hmr011_run_train_panel <- function(panel, contract = g5_hmr011_contract()) {
  statistics <- g5_hmr011_full_statistics(panel)
  predictions <- g5_hmr011_expanding_predictions(panel, contract)
  folds <- g5_hmr011_fold_metrics(predictions)
  pooled_improvement <- mean(predictions$loss_improvement)
  influence <- g5_hmr011_influence_audit(panel, contract)
  shifts <- g5_hmr011_shift_test(panel, pooled_improvement, contract)
  gates <- data.frame(
    gate_id = c(
      "minimum_train_anchors", "negative_full_train_beta", "negative_full_train_spearman",
      "positive_oof_mse_improvement", "positive_fold_breadth", "timing_and_influence_stability"
    ),
    passed = c(
      nrow(panel) >= contract$minimum_train_anchors,
      statistics$beta[[1L]] < 0,
      statistics$spearman[[1L]] < 0,
      pooled_improvement > 0,
      sum(folds$mse_improvement > 0) >= contract$minimum_positive_folds,
      shifts$decision$timing_specificity_passed[[1L]] && influence$influence_excluded_beta[[1L]] < 0
    ),
    observed = c(
      as.character(nrow(panel)),
      sprintf("%.10f", statistics$beta[[1L]]),
      sprintf("%.10f", statistics$spearman[[1L]]),
      sprintf("%.12g", pooled_improvement),
      paste0(sum(folds$mse_improvement > 0), "/", nrow(folds)),
      paste0(
        "observed=", sprintf("%.12g", pooled_improvement),
        ";p90=", sprintf("%.12g", shifts$decision$shift_p90[[1L]]),
        ";influence_beta=", sprintf("%.10f", influence$influence_excluded_beta[[1L]])
      )
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  passed <- all(gates$passed)
  overall_status <- if (passed) {
    "TRAIN_PASS_HYP_MR_01_1_DEVELOPMENT_AUTHORIZED"
  } else {
    "STOP_HYP_MR_01_1_TRAIN_REVERSAL_GATES_FAILED"
  }
  decision <- cbind(
    shifts$decision,
    full_train_beta = statistics$beta[[1L]],
    full_train_spearman = statistics$spearman[[1L]],
    positive_fold_count = sum(folds$mse_improvement > 0),
    influence_excluded_beta = influence$influence_excluded_beta[[1L]],
    passed = passed,
    status = overall_status,
    stringsAsFactors = FALSE
  )
  list(
    statistics = statistics,
    predictions = predictions,
    folds = folds,
    pooled_improvement = pooled_improvement,
    shift_distribution = shifts$distribution,
    decision = decision,
    influence = influence,
    deciles = g5_hmr011_deciles(panel, contract),
    gates = gates,
    overall_status = overall_status
  )
}

g5_hmr011_run_train <- function(bars, contract = g5_hmr011_contract()) {
  panel <- g5_hmr011_zone_panel(
    bars, contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  result <- g5_hmr011_run_train_panel(panel$panel, contract)
  c(list(panel_bundle = panel), result)
}

g5_hmr011_stationary_indices <- function(n, expected_block) {
  restart_probability <- 1 / as.numeric(expected_block)
  out <- integer(n)
  out[[1L]] <- sample.int(n, 1L)
  if (n > 1L) {
    for (i in 2:n) {
      out[[i]] <- if (stats::runif(1) < restart_probability) sample.int(n, 1L) else if (out[[i - 1L]] == n) 1L else out[[i - 1L]] + 1L
    }
  }
  out
}

g5_hmr011_development_bootstrap <- function(improvement, contract = g5_hmr011_contract(), replicates = contract$bootstrap_count) {
  set.seed(contract$bootstrap_seed)
  values <- numeric(as.integer(replicates))
  for (b in seq_len(as.integer(replicates))) {
    index <- g5_hmr011_stationary_indices(length(improvement), contract$bootstrap_expected_block)
    values[[b]] <- mean(improvement[index])
  }
  data.frame(
    replicates = as.integer(replicates),
    probability_positive = mean(values > 0),
    lower_90 = as.numeric(stats::quantile(values, 0.05, type = contract$quantile_type)),
    upper_90 = as.numeric(stats::quantile(values, 0.95, type = contract$quantile_type)),
    stringsAsFactors = FALSE
  )
}

g5_hmr011_run_development <- function(train_bars, development_bars, contract = g5_hmr011_contract()) {
  train_bundle <- g5_hmr011_zone_panel(
    train_bars, contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  development_bundle <- g5_hmr011_zone_panel(
    development_bars, contract$development_start, contract$development_end,
    contract$minimum_development_anchors, contract$development_end, contract
  )
  train <- train_bundle$panel
  development <- development_bundle$panel
  model <- g5_hmr011_fit(train)
  drift <- mean(train$y)
  development$model_prediction <- g5_hmr011_predict(model, development$x)
  development$drift_prediction <- drift
  development$model_squared_error <- (development$y - development$model_prediction)^2
  development$drift_squared_error <- (development$y - development$drift_prediction)^2
  development$loss_improvement <- development$drift_squared_error - development$model_squared_error
  development$target_year <- as.integer(format(development$target_date, "%Y"))
  year_metrics <- do.call(rbind, lapply(split(development, development$target_year), function(x) {
    data.frame(
      target_year = x$target_year[[1L]], row_count = nrow(x),
      drift_mse = mean(x$drift_squared_error), reversal_mse = mean(x$model_squared_error),
      mse_improvement = mean(x$loss_improvement), stringsAsFactors = FALSE
    )
  }))
  bootstrap <- g5_hmr011_development_bootstrap(development$loss_improvement, contract)
  metrics <- data.frame(
    row_count = nrow(development),
    frozen_alpha = model$alpha,
    frozen_beta = model$beta,
    development_pearson = stats::cor(development$x, development$y),
    development_spearman = stats::cor(development$x, development$y, method = "spearman"),
    drift_mse = mean(development$drift_squared_error),
    reversal_mse = mean(development$model_squared_error),
    mse_improvement = mean(development$loss_improvement),
    stringsAsFactors = FALSE
  )
  gates <- data.frame(
    gate_id = c("minimum_development_rows", "negative_development_spearman", "positive_frozen_loss_improvement", "bootstrap_probability", "positive_year_breadth"),
    passed = c(
      nrow(development) >= contract$minimum_development_anchors,
      metrics$development_spearman[[1L]] < 0,
      metrics$mse_improvement[[1L]] > 0,
      bootstrap$probability_positive[[1L]] >= contract$development_probability_gate,
      sum(year_metrics$mse_improvement > 0) >= contract$minimum_positive_development_years
    ),
    observed = c(
      as.character(nrow(development)), sprintf("%.10f", metrics$development_spearman[[1L]]),
      sprintf("%.12g", metrics$mse_improvement[[1L]]), sprintf("%.6f", bootstrap$probability_positive[[1L]]),
      paste0(sum(year_metrics$mse_improvement > 0), "/", nrow(year_metrics))
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  overall_status <- if (all(gates$passed)) {
    "DEVELOPMENT_PASS_HYP_MR_01_1_CONFIRMATION_REVIEW_REQUIRED"
  } else {
    "STOP_HYP_MR_01_1_DEVELOPMENT_REVERSAL_GATES_FAILED_CONFIRMATION_NOT_RUN"
  }
  list(
    train_bundle = train_bundle,
    development_bundle = development_bundle,
    predictions = development,
    metrics = metrics,
    year_metrics = year_metrics,
    bootstrap = bootstrap,
    gates = gates,
    overall_status = overall_status
  )
}
