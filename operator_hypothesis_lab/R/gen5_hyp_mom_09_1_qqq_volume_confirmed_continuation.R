# Frozen HYP-MOM-09.1 QQQ volume-confirmed continuation helpers.

g5_hm091_stop <- function(message) stop(message, call. = FALSE)

g5_hm091_schema_version <- function() "gen5_hyp_mom_09_1_v1"

g5_hm091_contract <- function() {
  list(
    hypothesis_id = "HYP-MOM-09.1",
    descriptive_name = "QQQ Volume-Confirmed Continuation",
    symbol = "QQQ",
    as_of_timestamp = "2026-08-22 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    confirmation_end = as.Date("2025-12-31"),
    lookback_grid = c(1L, 5L, 20L),
    target_grid = c(1L, 5L, 20L),
    volume_reference_sessions = 60L,
    volume_cap_multiple = 5,
    common_feature_sessions = 80L,
    common_target_sessions = 20L,
    circular_shift_minimum = 60L,
    surface_percentile = 0.90,
    quantile_type = 7L,
    bootstrap_count = 10000L,
    bootstrap_expected_block = 20,
    bootstrap_seed = 905101L,
    minimum_train_anchors = 900L,
    minimum_development_anchors = 600L,
    minimum_positive_years = 2L,
    development_probability_gate = 0.90,
    split_close_ratio_low = 0.55,
    split_close_ratio_high = 1.80,
    split_reciprocal_log_tolerance = 0.25,
    maximum_split_like_events = 0L,
    maximum_capped_participation_fraction = 0.01
  )
}

g5_hm091_validate_contract <- function(contract = g5_hm091_contract()) {
  frozen <- g5_hm091_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_hm091_stop("Frozen HYP-MOM-09.1 contract field set changed.")
  }
  same <- vapply(names(frozen), function(field) identical(contract[[field]], frozen[[field]]), logical(1))
  if (!all(same)) {
    g5_hm091_stop(paste(
      "Frozen HYP-MOM-09.1 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_hm091_validate_bars <- function(bars, maximum_allowed_date, contract = g5_hm091_contract()) {
  contract <- g5_hm091_validate_contract(contract)
  required <- c(
    "symbol", "session_date", "open", "high", "low", "close", "volume",
    "adjusted", "timeframe"
  )
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_hm091_stop(paste("Missing required bar columns:", paste(missing, collapse = ", ")))
  }
  x <- bars[bars$symbol == contract$symbol, required, drop = FALSE]
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  numeric_fields <- c("open", "high", "low", "close", "volume")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  x <- x[order(x$session_date), , drop = FALSE]
  duplicate_count <- sum(duplicated(x$session_date))
  strict_order <- nrow(x) > 1L && all(diff(x$session_date) > 0)
  maximum_observed <- if (nrow(x)) max(x$session_date) else as.Date(NA)
  minimum_observed <- if (nrow(x)) min(x$session_date) else as.Date(NA)
  x$dollar_volume <- x$close * x$volume

  split_audit <- if (nrow(x) > 1L) {
    data.frame(
      session_date = x$session_date[-1L],
      close_ratio = x$close[-1L] / x$close[-nrow(x)],
      volume_ratio = x$volume[-1L] / x$volume[-nrow(x)],
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(session_date = as.Date(character()), close_ratio = numeric(), volume_ratio = numeric())
  }
  split_audit$extreme_close_ratio <-
    split_audit$close_ratio < contract$split_close_ratio_low |
    split_audit$close_ratio > contract$split_close_ratio_high
  split_audit$reciprocal_volume_move <- abs(
    log(split_audit$close_ratio) + log(split_audit$volume_ratio)
  ) <= contract$split_reciprocal_log_tolerance
  split_audit$split_like <- split_audit$extreme_close_ratio & split_audit$reciprocal_volume_move
  split_like_count <- sum(split_audit$split_like, na.rm = TRUE)

  finite_ohlcv <- nrow(x) > 0L && all(is.finite(as.matrix(x[numeric_fields])))
  positive_ohlcv <- finite_ohlcv && all(as.matrix(x[numeric_fields]) > 0)
  checks <- data.frame(
    check_id = c(
      "exact_symbol", "strict_date_order", "unique_sessions", "positive_finite_ohlcv",
      "adjusted_daily_only", "positive_finite_dollar_volume", "query_start_covered",
      "maximum_date_seal", "split_like_discontinuity_gate"
    ),
    passed = c(
      nrow(x) > 0L && identical(unique(x$symbol), contract$symbol),
      strict_order,
      duplicate_count == 0L,
      positive_ohlcv,
      nrow(x) > 0L && all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      nrow(x) > 0L && all(is.finite(x$dollar_volume) & x$dollar_volume > 0),
      nrow(x) > 0L && minimum_observed <= contract$query_start,
      nrow(x) > 0L && maximum_observed <= as.Date(maximum_allowed_date),
      split_like_count <= contract$maximum_split_like_events
    ),
    observed = c(
      paste(unique(x$symbol), collapse = ","),
      as.character(strict_order),
      as.character(duplicate_count),
      if (nrow(x)) paste(range(as.matrix(x[numeric_fields])), collapse = " to ") else "none",
      paste(unique(paste(x$adjusted, x$timeframe, sep = "/")), collapse = ","),
      if (nrow(x)) paste(range(x$dollar_volume), collapse = " to ") else "none",
      as.character(minimum_observed),
      as.character(maximum_observed),
      as.character(split_like_count)
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_hm091_stop(paste(
      "HYP-MOM-09.1 bar validation failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  list(bars = x, checks = checks, split_audit = split_audit)
}

g5_hm091_daily_participation <- function(dollar_volume, contract = g5_hm091_contract()) {
  contract <- g5_hm091_validate_contract(contract)
  n <- length(dollar_volume)
  raw <- rep(NA_real_, n)
  positive <- rep(NA_real_, n)
  capped <- rep(FALSE, n)
  cap_value <- log(contract$volume_cap_multiple)
  window <- contract$volume_reference_sessions
  if (n <= window) return(data.frame(raw_log_ratio = raw, positive_surprise = positive, capped = capped))
  for (i in seq.int(window + 1L, n)) {
    reference <- stats::median(dollar_volume[(i - window):(i - 1L)])
    raw[[i]] <- log(dollar_volume[[i]] / reference)
    uncapped <- max(raw[[i]], 0)
    positive[[i]] <- min(uncapped, cap_value)
    capped[[i]] <- uncapped > cap_value
  }
  data.frame(raw_log_ratio = raw, positive_surprise = positive, capped = capped)
}

g5_hm091_zone_panel <- function(
  bars,
  zone_start,
  zone_end,
  minimum_anchors,
  maximum_allowed_date = zone_end,
  contract = g5_hm091_contract()
) {
  checked <- g5_hm091_validate_bars(bars, maximum_allowed_date, contract)
  x <- checked$bars
  participation <- g5_hm091_daily_participation(x$dollar_volume, contract)
  x <- cbind(x, participation)
  eligible_participation <- !is.na(x$positive_surprise)
  capped_fraction <- if (any(eligible_participation)) {
    mean(x$capped[eligible_participation])
  } else {
    NA_real_
  }
  index <- seq_len(nrow(x))
  max_feature <- contract$common_feature_sessions
  max_h <- contract$common_target_sessions
  anchor_i <- index[
    index > max_feature &
      index + 1L + max_h <= nrow(x) &
      x$session_date >= as.Date(zone_start)
  ]
  anchor_i <- anchor_i[x$session_date[anchor_i + 1L + max_h] <= as.Date(zone_end)]
  if (length(anchor_i) < as.integer(minimum_anchors)) {
    g5_hm091_stop(paste("Insufficient common anchors in zone:", length(anchor_i)))
  }

  return_matrix <- vapply(contract$lookback_grid, function(lag_n) {
    log(x$close[anchor_i] / x$close[anchor_i - lag_n])
  }, numeric(length(anchor_i)))
  participation_matrix <- vapply(contract$lookback_grid, function(lag_n) {
    vapply(anchor_i, function(i) {
      mean(x$positive_surprise[seq.int(i - lag_n + 1L, i)])
    }, numeric(1))
  }, numeric(length(anchor_i)))
  magnitude_matrix <- abs(return_matrix)
  interaction_matrix <- return_matrix * participation_matrix
  target_matrix <- vapply(contract$target_grid, function(horizon_n) {
    log(x$open[anchor_i + 1L + horizon_n] / x$open[anchor_i + 1L])
  }, numeric(length(anchor_i)))
  colnames(return_matrix) <- colnames(participation_matrix) <-
    colnames(magnitude_matrix) <- colnames(interaction_matrix) <- paste0("L", contract$lookback_grid)
  colnames(target_matrix) <- paste0("H", contract$target_grid)
  matrices <- list(return_matrix, participation_matrix, magnitude_matrix, interaction_matrix, target_matrix)
  if (!all(vapply(matrices, function(m) all(is.finite(m)), logical(1)))) {
    g5_hm091_stop("Nonfinite feature or target values were constructed.")
  }
  participation_sd <- apply(participation_matrix, 2L, stats::sd)
  construction_checks <- data.frame(
    check_id = c(
      "causal_reference_available", "finite_common_features", "positive_participation_variation",
      "participation_cap_fraction"
    ),
    passed = c(
      all(is.finite(x$positive_surprise[anchor_i])),
      all(vapply(matrices, function(m) all(is.finite(m)), logical(1))),
      all(is.finite(participation_sd) & participation_sd > 0),
      is.finite(capped_fraction) && capped_fraction <= contract$maximum_capped_participation_fraction
    ),
    observed = c(
      paste0("first_eligible=", x$session_date[min(which(eligible_participation))]),
      paste0("anchors=", length(anchor_i)),
      paste(sprintf("L%s=%.6f", contract$lookback_grid, participation_sd), collapse = ";"),
      sprintf("%.8f", capped_fraction)
    ),
    stringsAsFactors = FALSE
  )
  construction_checks$status <- ifelse(construction_checks$passed, "PASS", "FAIL")
  if (!all(construction_checks$passed)) {
    g5_hm091_stop(paste(
      "HYP-MOM-09.1 participation construction failed:",
      paste(construction_checks$check_id[!construction_checks$passed], collapse = ", ")
    ))
  }
  list(
    integrity = checked$checks,
    split_audit = checked$split_audit,
    construction_checks = construction_checks,
    bars = x,
    anchor_index = anchor_i,
    anchor_date = x$session_date[anchor_i],
    entry_date = x$session_date[anchor_i + 1L],
    maximum_exit_date = x$session_date[anchor_i + 1L + max_h],
    return_matrix = return_matrix,
    participation_matrix = participation_matrix,
    magnitude_matrix = magnitude_matrix,
    interaction_matrix = interaction_matrix,
    target_matrix = target_matrix
  )
}

g5_hm091_residuals <- function(y, controls) {
  fit <- stats::lm.fit(cbind(1, controls), y)
  if (fit$rank < ncol(cbind(1, controls))) {
    g5_hm091_stop("Additive control design is rank deficient.")
  }
  fit$residuals
}

g5_hm091_cell_statistics <- function(r, v, a, interaction, y, lookback, target) {
  controls <- cbind(r, v, a)
  interaction_residual <- g5_hm091_residuals(interaction, controls)
  target_residual <- g5_hm091_residuals(y, controls)
  full <- stats::lm.fit(cbind(1, r, v, a, interaction), y)
  additive <- stats::lm.fit(cbind(1, r, v, a), y)
  data.frame(
    cell_id = paste0("L", lookback, "_H", target),
    lookback_sessions = as.integer(lookback),
    target_sessions = as.integer(target),
    anchor_count = length(y),
    interaction_beta = unname(full$coefficients[[5L]]),
    partial_correlation = unname(stats::cor(interaction_residual, target_residual)),
    partial_spearman = unname(stats::cor(interaction_residual, target_residual, method = "spearman")),
    additive_mse = mean(additive$residuals^2),
    interaction_mse = mean(full$residuals^2),
    in_sample_mse_improvement = mean(additive$residuals^2) - mean(full$residuals^2),
    stringsAsFactors = FALSE
  )
}

g5_hm091_surface <- function(panel, contract = g5_hm091_contract()) {
  rows <- list()
  row_i <- 1L
  for (l_i in seq_along(contract$lookback_grid)) {
    for (h_i in seq_along(contract$target_grid)) {
      rows[[row_i]] <- g5_hm091_cell_statistics(
        panel$return_matrix[, l_i], panel$participation_matrix[, l_i],
        panel$magnitude_matrix[, l_i], panel$interaction_matrix[, l_i],
        panel$target_matrix[, h_i], contract$lookback_grid[[l_i]],
        contract$target_grid[[h_i]]
      )
      row_i <- row_i + 1L
    }
  }
  out <- do.call(rbind, rows)
  if (nrow(out) != 9L || anyDuplicated(out$cell_id)) {
    g5_hm091_stop("Frozen HYP-MOM-09.1 surface is incomplete.")
  }
  out
}

g5_hm091_rotate_rows <- function(matrix, shift) {
  n <- nrow(matrix)
  matrix[((seq_len(n) - 1L + as.integer(shift)) %% n) + 1L, , drop = FALSE]
}

g5_hm091_admissible_shifts <- function(n, minimum_displacement) {
  shifts <- seq_len(n - 1L)
  shifts[pmin(shifts, n - shifts) >= as.integer(minimum_displacement)]
}

g5_hm091_shift_test <- function(panel, surface, contract = g5_hm091_contract()) {
  n <- nrow(panel$target_matrix)
  shifts <- g5_hm091_admissible_shifts(n, contract$circular_shift_minimum)
  interaction_residuals <- lapply(seq_along(contract$lookback_grid), function(l_i) {
    controls <- cbind(
      panel$return_matrix[, l_i], panel$participation_matrix[, l_i],
      panel$magnitude_matrix[, l_i]
    )
    g5_hm091_residuals(panel$interaction_matrix[, l_i], controls)
  })
  maximum <- vapply(shifts, function(shift) {
    shifted <- g5_hm091_rotate_rows(panel$target_matrix, shift)
    values <- numeric(9L)
    value_i <- 1L
    for (l_i in seq_along(contract$lookback_grid)) {
      controls <- cbind(
        panel$return_matrix[, l_i], panel$participation_matrix[, l_i],
        panel$magnitude_matrix[, l_i]
      )
      for (h_i in seq_along(contract$target_grid)) {
        target_residual <- g5_hm091_residuals(shifted[, h_i], controls)
        values[[value_i]] <- stats::cor(interaction_residuals[[l_i]], target_residual)
        value_i <- value_i + 1L
      }
    }
    max(values)
  }, numeric(1))
  distribution <- data.frame(
    shift = shifts,
    circular_displacement = pmin(shifts, n - shifts),
    maximum_partial_correlation = maximum,
    stringsAsFactors = FALSE
  )
  threshold <- as.numeric(stats::quantile(
    maximum, probs = contract$surface_percentile, type = contract$quantile_type, names = FALSE
  ))
  observed <- max(surface$partial_correlation)
  passed <- is.finite(observed) && observed > 0 && observed > threshold
  decision <- data.frame(
    observed_maximum_partial_correlation = observed,
    shift_maximum_p90 = threshold,
    empirical_upper_tail_probability = (1 + sum(maximum >= observed)) / (1 + length(maximum)),
    eligible_shift_count = length(shifts),
    passed = passed,
    status = if (passed) {
      "TRAIN_INTERACTION_SEARCH_ADJUSTED_PASS"
    } else {
      "STOP_HYP_MOM_09_1_NO_SEARCH_ADJUSTED_TRAIN_INTERACTION"
    },
    stringsAsFactors = FALSE
  )
  list(distribution = distribution, decision = decision)
}

g5_hm091_nominate <- function(surface, passed) {
  if (!isTRUE(passed)) return(surface[FALSE, , drop = FALSE])
  ordered <- surface[order(
    -surface$partial_correlation, surface$lookback_sessions, surface$target_sessions
  ), , drop = FALSE]
  ordered[1L, , drop = FALSE]
}

g5_hm091_cell_vectors <- function(panel, lookback, target, contract = g5_hm091_contract()) {
  l_i <- match(as.integer(lookback), contract$lookback_grid)
  h_i <- match(as.integer(target), contract$target_grid)
  if (is.na(l_i) || is.na(h_i)) g5_hm091_stop("Nominee is outside the frozen grid.")
  data.frame(
    anchor_date = panel$anchor_date,
    entry_date = panel$entry_date,
    r = panel$return_matrix[, l_i],
    v = panel$participation_matrix[, l_i],
    a = panel$magnitude_matrix[, l_i],
    interaction = panel$interaction_matrix[, l_i],
    y = panel$target_matrix[, h_i],
    stringsAsFactors = FALSE
  )
}

g5_hm091_model_fields <- function(model_id) {
  switch(
    model_id,
    DRIFT = character(),
    RETURN = "r",
    VOLUME = "v",
    ADDITIVE = c("r", "v", "a"),
    INTERACTION = c("r", "v", "a", "interaction"),
    g5_hm091_stop(paste("Unknown model:", model_id))
  )
}

g5_hm091_fit_model <- function(data, model_id) {
  fields <- g5_hm091_model_fields(model_id)
  design <- if (length(fields)) cbind(1, as.matrix(data[fields])) else matrix(1, nrow(data), 1L)
  fit <- stats::lm.fit(design, data$y)
  if (fit$rank < ncol(design)) g5_hm091_stop(paste("Rank-deficient model:", model_id))
  list(model_id = model_id, fields = fields, coefficients = unname(fit$coefficients))
}

g5_hm091_predict_model <- function(model, data) {
  design <- if (length(model$fields)) {
    cbind(1, as.matrix(data[model$fields]))
  } else {
    matrix(1, nrow(data), 1L)
  }
  as.numeric(design %*% model$coefficients)
}

g5_hm091_model_predictions <- function(train, development) {
  model_ids <- c("DRIFT", "RETURN", "VOLUME", "ADDITIVE", "INTERACTION")
  rows <- lapply(model_ids, function(model_id) {
    model <- g5_hm091_fit_model(train, model_id)
    prediction <- g5_hm091_predict_model(model, development)
    data.frame(
      anchor_date = development$anchor_date,
      model_id = model_id,
      actual = development$y,
      prediction = prediction,
      squared_error = (development$y - prediction)^2,
      absolute_error = abs(development$y - prediction),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_hm091_model_metrics <- function(predictions) {
  rows <- lapply(split(predictions, predictions$model_id), function(x) {
    data.frame(
      model_id = x$model_id[[1L]],
      anchor_count = nrow(x),
      development_mse = mean(x$squared_error),
      development_mae = mean(x$absolute_error),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[match(c("DRIFT", "RETURN", "VOLUME", "ADDITIVE", "INTERACTION"), out$model_id), , drop = FALSE]
}

g5_hm091_stationary_indices <- function(n, expected_block) {
  restart_probability <- 1 / as.numeric(expected_block)
  out <- integer(n)
  out[[1L]] <- sample.int(n, 1L)
  if (n > 1L) {
    for (i in 2:n) {
      out[[i]] <- if (stats::runif(1) < restart_probability) {
        sample.int(n, 1L)
      } else {
        if (out[[i - 1L]] == n) 1L else out[[i - 1L]] + 1L
      }
    }
  }
  out
}

g5_hm091_development_bootstrap <- function(pairs, predictions, contract = g5_hm091_contract()) {
  additive <- predictions[predictions$model_id == "ADDITIVE", , drop = FALSE]
  interaction <- predictions[predictions$model_id == "INTERACTION", , drop = FALSE]
  if (!identical(as.character(additive$anchor_date), as.character(interaction$anchor_date))) {
    g5_hm091_stop("DEVELOPMENT prediction rows are not aligned.")
  }
  improvement <- additive$squared_error - interaction$squared_error
  set.seed(contract$bootstrap_seed)
  beta <- numeric(contract$bootstrap_count)
  loss <- numeric(contract$bootstrap_count)
  for (b in seq_len(contract$bootstrap_count)) {
    idx <- g5_hm091_stationary_indices(nrow(pairs), contract$bootstrap_expected_block)
    fit <- g5_hm091_fit_model(pairs[idx, , drop = FALSE], "INTERACTION")
    beta[[b]] <- tail(fit$coefficients, 1L)
    loss[[b]] <- mean(improvement[idx])
  }
  data.frame(
    beta_probability_positive = mean(beta > 0),
    beta_lower_90 = as.numeric(stats::quantile(beta, 0.05, type = contract$quantile_type)),
    beta_upper_90 = as.numeric(stats::quantile(beta, 0.95, type = contract$quantile_type)),
    loss_probability_positive = mean(loss > 0),
    loss_improvement_lower_90 = as.numeric(stats::quantile(loss, 0.05, type = contract$quantile_type)),
    loss_improvement_upper_90 = as.numeric(stats::quantile(loss, 0.95, type = contract$quantile_type)),
    stringsAsFactors = FALSE
  )
}

g5_hm091_year_diagnostics <- function(pairs) {
  years <- format(pairs$anchor_date, "%Y")
  rows <- lapply(split(seq_len(nrow(pairs)), years), function(idx) {
    fit <- g5_hm091_fit_model(pairs[idx, , drop = FALSE], "INTERACTION")
    data.frame(
      year = format(pairs$anchor_date[idx[[1L]]], "%Y"),
      anchor_count = length(idx),
      interaction_beta = tail(fit$coefficients, 1L),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_hm091_participation_quintiles <- function(pairs) {
  rank_index <- rank(pairs$v, ties.method = "first")
  quintile <- pmin(5L, ceiling(5 * rank_index / nrow(pairs)))
  rows <- lapply(split(seq_len(nrow(pairs)), quintile), function(idx) {
    fit <- stats::lm.fit(cbind(1, pairs$r[idx]), pairs$y[idx])
    data.frame(
      participation_quintile = as.integer(quintile[idx[[1L]]]),
      anchor_count = length(idx),
      mean_participation = mean(pairs$v[idx]),
      return_slope = unname(fit$coefficients[[2L]]),
      mean_forward_return = mean(pairs$y[idx]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_hm091_run_train <- function(bars, contract = g5_hm091_contract()) {
  panel <- g5_hm091_zone_panel(
    bars, contract$train_start, contract$train_end, contract$minimum_train_anchors,
    contract$train_end, contract
  )
  surface <- g5_hm091_surface(panel, contract)
  shift <- g5_hm091_shift_test(panel, surface, contract)
  nominee <- g5_hm091_nominate(surface, shift$decision$passed[[1L]])
  list(
    panel = panel,
    surface = surface,
    shift_distribution = shift$distribution,
    decision = shift$decision,
    nominee = nominee,
    overall_status = shift$decision$status[[1L]],
    development_opened = FALSE,
    confirmation_opened = FALSE
  )
}

g5_hm091_run_development <- function(train_bars, development_bars, nominee, contract = g5_hm091_contract()) {
  if (nrow(nominee) != 1L) g5_hm091_stop("Exactly one frozen TRAIN nominee is required.")
  train_panel <- g5_hm091_zone_panel(
    train_bars, contract$train_start, contract$train_end, contract$minimum_train_anchors,
    contract$train_end, contract
  )
  development_panel <- g5_hm091_zone_panel(
    development_bars, contract$development_start, contract$development_end,
    contract$minimum_development_anchors, contract$development_end, contract
  )
  lookback <- nominee$lookback_sessions[[1L]]
  target <- nominee$target_sessions[[1L]]
  train_pairs <- g5_hm091_cell_vectors(train_panel, lookback, target, contract)
  development_pairs <- g5_hm091_cell_vectors(development_panel, lookback, target, contract)
  predictions <- g5_hm091_model_predictions(train_pairs, development_pairs)
  metrics <- g5_hm091_model_metrics(predictions)
  statistics <- g5_hm091_cell_statistics(
    development_pairs$r, development_pairs$v, development_pairs$a,
    development_pairs$interaction, development_pairs$y, lookback, target
  )
  bootstrap <- g5_hm091_development_bootstrap(development_pairs, predictions, contract)
  years <- g5_hm091_year_diagnostics(development_pairs)
  quintiles <- g5_hm091_participation_quintiles(development_pairs)
  interaction_mse <- metrics$development_mse[metrics$model_id == "INTERACTION"]
  comparator_mse <- metrics$development_mse[metrics$model_id != "INTERACTION"]
  positive_years <- sum(years$interaction_beta > 0)
  gates <- data.frame(
    gate_id = c(
      "minimum_development_anchors", "positive_partial_correlation",
      "bootstrap_positive_interaction_beta", "interaction_lowest_mse",
      "bootstrap_positive_loss_improvement", "positive_year_breadth"
    ),
    passed = c(
      nrow(development_pairs) >= contract$minimum_development_anchors,
      statistics$partial_correlation[[1L]] > 0,
      bootstrap$beta_probability_positive[[1L]] >= contract$development_probability_gate,
      all(interaction_mse < comparator_mse),
      bootstrap$loss_probability_positive[[1L]] >= contract$development_probability_gate,
      positive_years >= contract$minimum_positive_years
    ),
    observed = c(
      as.character(nrow(development_pairs)),
      sprintf("%.8f", statistics$partial_correlation[[1L]]),
      sprintf("%.8f", bootstrap$beta_probability_positive[[1L]]),
      paste0("interaction=", sprintf("%.10g", interaction_mse), ";min_comparator=", sprintf("%.10g", min(comparator_mse))),
      sprintf("%.8f", bootstrap$loss_probability_positive[[1L]]),
      paste0(positive_years, "/", nrow(years))
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  overall_status <- if (all(gates$passed)) {
    "DEVELOPMENT_PASS_HYP_MOM_09_1_CONFIRMATION_REVIEW_REQUIRED"
  } else {
    "STOP_HYP_MOM_09_1_DEVELOPMENT_INTERACTION_GATES_FAILED"
  }
  list(
    train_pairs = train_pairs,
    development_pairs = development_pairs,
    development_statistics = statistics,
    predictions = predictions,
    model_comparison = metrics,
    bootstrap = bootstrap,
    year_diagnostics = years,
    participation_quintiles = quintiles,
    gates = gates,
    overall_status = overall_status,
    confirmation_opened = FALSE
  )
}
