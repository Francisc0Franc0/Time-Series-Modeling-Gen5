# Forecast-first directional HMM frontier for LIT-REG-02.2.
# Source gen5_lit_reg_02_1_directional_hmm_poc.R before this file.

g5_reg022_stop <- function(message) stop(message, call. = FALSE)

g5_reg022_schema_version <- function() "gen5_lit_reg_02_2_directional_forecast_v1"

g5_reg022_contract <- function() {
  inherited <- g5_reg021_contract()
  inherited$literature_id <- "LIT-REG-02.2"
  inherited$descriptive_name <- "Directional HMM Forecast-Skill Frontier"
  inherited$positive_seeds <- 75001:75024
  inherited$positive_case_count <- 24L
  inherited$ridge_lambda <- 1
  inherited$minimum_case_wins <- 15L
  inherited$paired_confidence_level <- 0.90
  inherited$calibration_intercept_bounds <- c(-0.50, 0.50)
  inherited$calibration_slope_bounds <- c(0.50, 1.50)
  inherited$minimum_pooled_sharpness <- 0.03
  inherited
}

g5_reg022_feature_values <- function(returns, origin) {
  returns <- as.numeric(returns)
  origin <- as.integer(origin)
  if (length(origin) != 1L || !is.finite(origin) || origin < 20L ||
      origin > length(returns) || any(!is.finite(returns[seq_len(origin)]))) {
    g5_reg022_stop("Invalid causal ridge feature origin.")
  }
  trailing_20 <- returns[(origin - 19L):origin]
  c(
    ret_1 = returns[[origin]],
    ret_5 = sum(returns[(origin - 4L):origin]),
    ret_20 = sum(trailing_20),
    vol_20 = stats::sd(trailing_20)
  )
}

g5_reg022_training_design <- function(returns, horizon = 20L) {
  returns <- as.numeric(returns)
  horizon <- as.integer(horizon)
  origins <- seq.int(20L, length(returns) - horizon, by = horizon)
  if (length(origins) < 10L) g5_reg022_stop("Insufficient TRAIN ridge origins.")
  features <- t(vapply(origins, function(origin) {
    g5_reg022_feature_values(returns, origin)
  }, numeric(4L)))
  outcome <- vapply(origins, function(origin) {
    as.integer(sum(returns[(origin + 1L):(origin + horizon)]) > 0)
  }, integer(1L))
  list(features = features, outcome = outcome, origins = origins)
}

g5_reg022_fit_ridge <- function(returns, contract = g5_reg022_contract()) {
  design <- g5_reg022_training_design(returns, contract$horizon)
  feature_mean <- colMeans(design$features)
  feature_sd <- apply(design$features, 2L, stats::sd)
  feature_sd[!is.finite(feature_sd) | feature_sd < 1e-12] <- 1
  x <- sweep(sweep(design$features, 2L, feature_mean, "-"), 2L, feature_sd, "/")
  y <- design$outcome
  if (length(unique(y)) < 2L) {
    return(list(valid = FALSE, convergence = 99L, reason = "single_class_train"))
  }
  start_probability <- pmin(1 - 1e-4, pmax(1e-4, mean(y)))
  start <- c(stats::qlogis(start_probability), rep(0, ncol(x)))
  objective <- function(parameter) {
    eta <- as.numeric(parameter[[1L]] + x %*% parameter[-1L])
    sum(pmax(eta, 0) + log1p(exp(-abs(eta))) - y * eta) +
      0.5 * contract$ridge_lambda * sum(parameter[-1L]^2)
  }
  gradient <- function(parameter) {
    eta <- as.numeric(parameter[[1L]] + x %*% parameter[-1L])
    residual <- stats::plogis(eta) - y
    c(sum(residual), as.numeric(crossprod(x, residual)) +
      contract$ridge_lambda * parameter[-1L])
  }
  fit <- tryCatch(
    stats::optim(
      start, objective, gradient, method = "BFGS",
      control = list(maxit = 2000L, reltol = 1e-12)
    ),
    error = function(error) NULL
  )
  valid <- !is.null(fit) && identical(as.integer(fit$convergence), 0L) &&
    all(is.finite(c(fit$par, fit$value)))
  list(
    valid = valid,
    convergence = if (is.null(fit)) 98L else as.integer(fit$convergence),
    coefficients = if (is.null(fit)) rep(NA_real_, 5L) else fit$par,
    feature_mean = feature_mean,
    feature_sd = feature_sd,
    lambda = contract$ridge_lambda,
    train_origins = design$origins,
    train_target_end = design$origins + contract$horizon,
    objective = if (is.null(fit)) NA_real_ else fit$value
  )
}

g5_reg022_predict_ridge <- function(model, features) {
  if (!isTRUE(model$valid)) return(NA_real_)
  standardized <- (as.numeric(features) - model$feature_mean) / model$feature_sd
  stats::plogis(model$coefficients[[1L]] +
    sum(model$coefficients[-1L] * standardized))
}

g5_reg022_evaluate_case <- function(
  case_id,
  seed,
  train_length,
  oos_length,
  alpha,
  phi,
  sigma,
  transition,
  fixture_class,
  financial_noise = FALSE,
  contract = g5_reg022_contract(),
  save_tape = FALSE
) {
  evaluated <- g5_reg021_evaluate_case(
    case_id = case_id,
    seed = seed,
    train_length = train_length,
    oos_length = oos_length,
    alpha = alpha,
    phi = phi,
    sigma = sigma,
    transition = transition,
    fixture_class = fixture_class,
    financial_noise = financial_noise,
    contract = contract,
    save_tape = save_tape
  )
  evaluated$summary$b2_valid <- FALSE
  evaluated$summary$brier_b2 <- NA_real_
  evaluated$summary$logloss_b2 <- NA_real_
  evaluated$summary$accuracy_b2 <- NA_real_
  evaluated$summary$sharpness_b2 <- NA_real_
  evaluated$b2_fit <- NULL
  if (!isTRUE(evaluated$summary$valid_fit[[1L]])) return(evaluated)

  all_returns <- evaluated$simulated$ret
  train <- all_returns[seq_len(train_length)]
  absolute_origins <- train_length + evaluated$forecasts$origin
  evaluated$forecasts$b2_feature_origin <- absolute_origins
  evaluated$forecasts$b2_latest_return_index <- absolute_origins
  evaluated$forecasts$p_b2 <- NA_real_
  ridge <- g5_reg022_fit_ridge(train, contract)
  evaluated$b2_fit <- ridge
  evaluated$summary$b2_valid <- isTRUE(ridge$valid)
  if (!isTRUE(ridge$valid)) return(evaluated)

  evaluated$forecasts$p_b2 <- vapply(absolute_origins, function(origin) {
    g5_reg022_predict_ridge(ridge, g5_reg022_feature_values(all_returns, origin))
  }, numeric(1L))
  b2 <- g5_reg021_score_probability(
    evaluated$forecasts$p_b2,
    evaluated$forecasts$outcome,
    contract$probability_clip
  )
  evaluated$summary$brier_b2 <- b2$brier
  evaluated$summary$logloss_b2 <- b2$log_loss
  evaluated$summary$accuracy_b2 <- b2$accuracy
  evaluated$summary$sharpness_b2 <- b2$sharpness
  evaluated
}

g5_reg022_positive_registry <- function() {
  data.frame(
    case_id = sprintf("FORECAST_CONFIRM_%02d", 1:24),
    fixture_class = "fresh_forecast_confirmation",
    seed = 75001:75024,
    train_length = 1800L,
    oos_length = 600L,
    drift = 0.003,
    self_transition = 0.97,
    financial_noise = FALSE,
    stringsAsFactors = FALSE
  )
}

g5_reg022_frontier_registry <- function() {
  registry <- g5_reg021_frontier_registry()
  registry$fixture_class <- ifelse(
    registry$drift == 0,
    "forecast_frontier_null",
    "forecast_frontier_directional"
  )
  registry
}

g5_reg022_stress_registry <- function() {
  registry <- g5_reg021_stress_registry()
  registry$fixture_class <- "forecast_financial_shaped_synthetic"
  registry
}

g5_reg022_evaluate_registry_row <- function(
  row,
  contract = g5_reg022_contract(),
  save_tape = FALSE
) {
  drift <- row$drift[[1L]]
  persistence <- row$self_transition[[1L]]
  evaluated <- g5_reg022_evaluate_case(
    case_id = row$case_id[[1L]],
    seed = row$seed[[1L]],
    train_length = row$train_length[[1L]],
    oos_length = row$oos_length[[1L]],
    alpha = if (drift == 0) c(0, 0) else c(-drift, drift),
    phi = c(0.10, 0.10),
    sigma = c(0.012, 0.012),
    transition = matrix(
      c(persistence, 1 - persistence, 1 - persistence, persistence),
      nrow = 2L,
      byrow = TRUE
    ),
    fixture_class = row$fixture_class[[1L]],
    financial_noise = isTRUE(row$financial_noise[[1L]]),
    contract = contract,
    save_tape = save_tape
  )
  evaluated$summary$drift <- drift
  evaluated$summary$self_transition <- persistence
  if ("replicate" %in% names(row)) evaluated$summary$replicate <- row$replicate[[1L]]
  evaluated
}

g5_reg022_calibration <- function(forecasts, probability = "p_h2", clip = 1e-6) {
  p <- pmax(clip, pmin(1 - clip, forecasts[[probability]]))
  x <- stats::qlogis(p)
  fit <- tryCatch(
    suppressWarnings(stats::glm(forecasts$outcome ~ x, family = stats::binomial())),
    error = function(error) NULL
  )
  coefficients <- if (is.null(fit)) c(NA_real_, NA_real_) else stats::coef(fit)
  data.frame(
    probability = probability,
    intercept = unname(coefficients[[1L]]),
    slope = unname(coefficients[[2L]]),
    sharpness = stats::sd(p),
    observations = length(p),
    stringsAsFactors = FALSE
  )
}

g5_reg022_paired_upper <- function(candidate, baseline, level = 0.90) {
  difference <- candidate - baseline
  difference <- difference[is.finite(difference)]
  if (length(difference) < 2L) return(NA_real_)
  mean(difference) + stats::qt(level, df = length(difference) - 1L) *
    stats::sd(difference) / sqrt(length(difference))
}

g5_reg022_stage_a_checks <- function(
  first_result,
  first_row,
  contract = g5_reg022_contract()
) {
  model <- first_result$fit
  train_length <- first_result$summary$train_length[[1L]]
  oos_length <- first_result$summary$oos_length[[1L]]
  oos_indices <- (train_length + 1L):(train_length + oos_length)
  oos <- first_result$simulated$ret[oos_indices]
  lags <- c(first_result$simulated$ret[[train_length]], head(oos, -1L))
  train_last <- tail(model$train_filtered, 1L)
  prefix_length <- oos_length - 100L
  prefix <- g5_reg021_forward(
    oos[seq_len(prefix_length)], lags[seq_len(prefix_length)],
    model$transition, model$alpha, model$phi, model$sigma,
    train_last, initial_is_previous_filter = TRUE
  )$filtered
  full <- g5_reg021_forward(
    oos, lags, model$transition, model$alpha, model$phi, model$sigma,
    train_last, initial_is_previous_filter = TRUE
  )$filtered
  replay <- g5_reg022_evaluate_registry_row(first_row, contract, save_tape = TRUE)
  parameter_difference <- max(abs(c(
    model$alpha - replay$fit$alpha,
    model$phi - replay$fit$phi,
    model$sigma - replay$fit$sigma,
    model$transition - replay$fit$transition,
    first_result$b2_fit$coefficients - replay$b2_fit$coefficients
  )))
  probability_difference <- max(abs(c(
    first_result$forecasts$p_h2 - replay$forecasts$p_h2,
    first_result$forecasts$p_b2 - replay$forecasts$p_b2
  )))
  filter_difference <- max(abs(
    first_result$tape$p_more_favorable - replay$tape$p_more_favorable
  ))
  score_columns <- c("brier_h2", "brier_b2", "logloss_h2", "logloss_b2")
  score_difference <- max(abs(unlist(
    first_result$summary[score_columns] - replay$summary[score_columns]
  )))
  list(
    append_difference = max(abs(prefix - full[seq_len(prefix_length), , drop = FALSE])),
    parameter_difference = parameter_difference,
    probability_difference = probability_difference,
    filter_difference = filter_difference,
    score_difference = score_difference,
    ridge_train_causal = max(first_result$b2_fit$train_target_end) <= train_length,
    ridge_oos_causal = all(
      first_result$forecasts$b2_feature_origin ==
        train_length + first_result$forecasts$origin &
      first_result$forecasts$b2_latest_return_index ==
        first_result$forecasts$b2_feature_origin &
      first_result$forecasts$b2_feature_origin <= train_length + oos_length
    )
  )
}

g5_reg022_skill_details <- function(summary, metric, contract = g5_reg022_contract()) {
  candidate <- summary[[paste0(metric, "_h2")]]
  baseline_columns <- paste0(metric, c("_b0", "_b1", "_b2"))
  data.frame(
    metric = metric,
    baseline = c("B0", "B1", "B2"),
    candidate_mean = mean(candidate),
    baseline_mean = vapply(baseline_columns, function(column) mean(summary[[column]]), numeric(1L)),
    case_wins = vapply(baseline_columns, function(column) sum(candidate < summary[[column]]), integer(1L)),
    paired_upper_90 = vapply(baseline_columns, function(column) {
      g5_reg022_paired_upper(candidate, summary[[column]], contract$paired_confidence_level)
    }, numeric(1L)),
    stringsAsFactors = FALSE
  )
}

g5_reg022_stage_a_gates <- function(
  summary,
  forecasts,
  checks,
  registry,
  contract = g5_reg022_contract()
) {
  valid <- summary[summary$valid_fit & summary$b2_valid, , drop = FALSE]
  brier <- g5_reg022_skill_details(valid, "brier", contract)
  logloss <- g5_reg022_skill_details(valid, "logloss", contract)
  calibration <- g5_reg022_calibration(forecasts, "p_h2", contract$probability_clip)
  brier_pass <- all(brier$candidate_mean < brier$baseline_mean) &&
    all(brier$case_wins >= contract$minimum_case_wins) &&
    all(brier$paired_upper_90 < 0)
  logloss_pass <- all(logloss$candidate_mean < logloss$baseline_mean) &&
    all(logloss$case_wins >= contract$minimum_case_wins) &&
    all(logloss$paired_upper_90 < 0)
  replay_max <- max(unlist(checks[c(
    "parameter_difference", "probability_difference",
    "filter_difference", "score_difference"
  )]))
  seed_integrity <- identical(as.integer(registry$seed), 75001:75024) &&
    !anyDuplicated(registry$seed) &&
    !any(registry$seed %in% 72001:74010)
  finite_columns <- c(
    "brier_h2", "brier_b0", "brier_b1", "brier_b2", "brier_oracle",
    "logloss_h2", "logloss_b0", "logloss_b1", "logloss_b2", "logloss_oracle"
  )
  gate <- c(
    A1 = identical(as.character(utils::packageVersion("hmmTMB")), contract$reference_version) &&
      nrow(valid) == contract$positive_case_count,
    A2 = checks$append_difference <= 1e-12,
    A3 = replay_max <= 1e-10,
    A4 = brier_pass,
    A5 = logloss_pass,
    A6 = is.finite(calibration$intercept) && is.finite(calibration$slope) &&
      calibration$intercept >= contract$calibration_intercept_bounds[[1L]] &&
      calibration$intercept <= contract$calibration_intercept_bounds[[2L]] &&
      calibration$slope >= contract$calibration_slope_bounds[[1L]] &&
      calibration$slope <= contract$calibration_slope_bounds[[2L]] &&
      calibration$sharpness >= contract$minimum_pooled_sharpness,
    A7 = mean(valid$brier_oracle) <= mean(valid$brier_h2) +
      contract$monte_carlo_tolerance &&
      all(is.finite(unlist(valid[finite_columns]))),
    A8 = seed_integrity && isTRUE(checks$ridge_train_causal) &&
      isTRUE(checks$ridge_oos_causal)
  )
  observed <- c(
    sprintf("version=%s; H2+B2 valid=%d/%d", as.character(utils::packageVersion("hmmTMB")), nrow(valid), contract$positive_case_count),
    paste0("append_difference=", format(checks$append_difference, scientific = TRUE)),
    paste0("maximum_replay_difference=", format(replay_max, scientific = TRUE)),
    paste0("Brier: ", paste(sprintf("%s mean=%.4f vs %.4f; wins=%d; upper90=%.5f", brier$baseline, brier$candidate_mean, brier$baseline_mean, brier$case_wins, brier$paired_upper_90), collapse = " | ")),
    paste0("Log loss: ", paste(sprintf("%s mean=%.4f vs %.4f; wins=%d; upper90=%.5f", logloss$baseline, logloss$candidate_mean, logloss$baseline_mean, logloss$case_wins, logloss$paired_upper_90), collapse = " | ")),
    sprintf("calibration intercept=%.3f slope=%.3f sharpness=%.3f", calibration$intercept, calibration$slope, calibration$sharpness),
    sprintf("oracle Brier=%.4f; H2 Brier=%.4f; finite=%s", mean(valid$brier_oracle), mean(valid$brier_h2), all(is.finite(unlist(valid[finite_columns])))),
    sprintf("seed_integrity=%s; ridge_train_causal=%s; ridge_oos_causal=%s", seed_integrity, checks$ridge_train_causal, checks$ridge_oos_causal)
  )
  list(
    gates = data.frame(
      gate_id = names(gate),
      passed = unname(gate),
      status = ifelse(unname(gate), "PASS", "FAIL"),
      observed = observed,
      stringsAsFactors = FALSE
    ),
    calibration = calibration,
    skill = rbind(brier, logloss)
  )
}

g5_reg022_frontier_summary <- function(summary) {
  groups <- split(summary, list(
    summary$train_length, summary$self_transition, summary$drift
  ), drop = TRUE)
  do.call(rbind, lapply(groups, function(part) {
    valid <- part[part$valid_fit & part$b2_valid, , drop = FALSE]
    if (!nrow(valid)) {
      return(data.frame(
        train_length = part$train_length[[1L]], self_transition = part$self_transition[[1L]],
        drift = part$drift[[1L]], drift_bp = 10000 * part$drift[[1L]],
        valid_fits = 0L, replicates = nrow(part), mean_brier_gain_vs_best = NA_real_,
        mean_logloss_gain_vs_best = NA_real_, joint_score_wins = 0L,
        detection_boundary_cell = FALSE, median_state_accuracy = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    brier_baselines <- cbind(valid$brier_b0, valid$brier_b1, valid$brier_b2)
    logloss_baselines <- cbind(valid$logloss_b0, valid$logloss_b1, valid$logloss_b2)
    joint_win <- valid$brier_h2 < apply(brier_baselines, 1L, min) &
      valid$logloss_h2 < apply(logloss_baselines, 1L, min)
    mean_brier_better_all <- all(mean(valid$brier_h2) < colMeans(brier_baselines))
    mean_logloss_better_all <- all(mean(valid$logloss_h2) < colMeans(logloss_baselines))
    data.frame(
      train_length = part$train_length[[1L]],
      self_transition = part$self_transition[[1L]],
      drift = part$drift[[1L]],
      drift_bp = 10000 * part$drift[[1L]],
      valid_fits = nrow(valid),
      replicates = nrow(part),
      mean_brier_gain_vs_best = mean(apply(brier_baselines, 1L, min) - valid$brier_h2),
      mean_logloss_gain_vs_best = mean(apply(logloss_baselines, 1L, min) - valid$logloss_h2),
      joint_score_wins = sum(joint_win),
      detection_boundary_cell = nrow(valid) >= 3L && sum(joint_win) >= 3L &&
        mean_brier_better_all && mean_logloss_better_all,
      median_state_accuracy = if (part$drift[[1L]] == 0) NA_real_ else
        stats::median(valid$filtered_accuracy, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
}
