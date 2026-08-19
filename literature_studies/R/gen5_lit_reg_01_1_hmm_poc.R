# Frozen contract, synthetic fixtures, and real-data helpers for LIT-REG-01.1.

g5_reg011_schema_version <- function() "gen5_lit_reg_01_1_hmm_v1"

g5_reg011_contract <- function() {
  list(
    literature_id = "LIT-REG-01.1",
    descriptive_name = "Two-State Hidden Markov Market Regime",
    symbol = "SPY",
    as_of_timestamp = "2026-08-18 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    analysis_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    folds = data.frame(
      fold_id = paste0("F", 1:4),
      train_start = rep(as.Date("2016-01-04"), 4L),
      train_end = as.Date(c("2019-12-31", "2020-12-31", "2021-12-31", "2022-12-30")),
      oos_start = as.Date(c("2020-01-02", "2021-01-04", "2022-01-03", "2023-01-03")),
      oos_end = as.Date(c("2020-12-31", "2021-12-31", "2022-12-30", "2023-12-29")),
      stringsAsFactors = FALSE
    ),
    b1_h2_seeds = 61001:61020,
    h3_seeds = 63001:63020,
    self_transitions = c(0.80, 0.90, 0.95, 0.98),
    eigen_floor = 1e-4,
    probability_floor = 1e-6,
    max_iterations = 1000L,
    tolerance_per_observation = 1e-8,
    convergence_patience = 5L,
    bootstrap_count = 2000L,
    bootstrap_block_length = 20L,
    bootstrap_seed = 61201L,
    permutation_count = 200L,
    permutation_block_length = 20L,
    permutation_seed = 61202L
  )
}

g5_reg011_validate_contract <- function(contract = g5_reg011_contract()) {
  frozen <- g5_reg011_contract()
  if (!identical(contract, frozen)) g5_hmm_stop("Frozen LIT-REG-01.1 contract changed.")
  contract
}

g5_reg011_synthetic_fixtures <- function() {
  strong_means <- rbind(
    CALMER = c(log_return = 0.00, log_normalized_true_range = -0.90),
    TURBULENT = c(log_return = 0.00, log_normalized_true_range = 0.90)
  )
  weak_means <- rbind(
    CALMER = c(log_return = 0.00, log_normalized_true_range = -0.12),
    TURBULENT = c(log_return = 0.00, log_normalized_true_range = 0.12)
  )
  strong_covariances <- list(
    CALMER = matrix(c(0.30, -0.02, -0.02, 0.09), 2L, 2L),
    TURBULENT = matrix(c(1.20, 0.08, 0.08, 0.16), 2L, 2L)
  )
  weak_covariances <- list(
    CALMER = matrix(c(0.75, 0.02, 0.02, 0.25), 2L, 2L),
    TURBULENT = matrix(c(0.90, 0.03, 0.03, 0.25), 2L, 2L)
  )
  list(
    fixture_version = "LIT_REG_01_1_SYNTHETIC_V1",
    sequence_length = 1500L,
    strong_seeds = 61101:61150,
    weak_seeds = 61301:61350,
    fit_seed_offset = 100000L,
    strong = list(
      transition = matrix(c(0.96, 0.04, 0.08, 0.92), 2L, 2L, byrow = TRUE),
      means = strong_means,
      covariances = strong_covariances
    ),
    weak = list(
      transition = matrix(c(0.92, 0.08, 0.08, 0.92), 2L, 2L, byrow = TRUE),
      means = weak_means,
      covariances = weak_covariances
    ),
    assertions = list(
      strong_median_accuracy_minimum = 0.90,
      strong_tenth_percentile_accuracy_minimum = 0.85,
      transition_median_maximum_error = 0.03,
      transition_ninetieth_percentile_maximum_error = 0.08,
      weak_confidence_reduction_minimum = 0.10,
      duration_median_relative_error_maximum = 0.25
    )
  )
}

g5_reg011_validate_bars <- function(bars, contract = g5_reg011_contract()) {
  contract <- g5_reg011_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_hmm_stop(paste("Missing required SPY bar columns:", paste(missing, collapse = ", ")))
  out <- bars[bars$symbol == contract$symbol, required, drop = FALSE]
  if (!nrow(out)) g5_hmm_stop("No SPY bars were supplied.")
  out$session_date <- as.Date(out$session_date)
  out <- out[order(out$session_date), , drop = FALSE]
  prices <- as.matrix(out[c("open", "high", "low", "close")])
  checks <- data.frame(
    check_id = c(
      "single_symbol", "strict_date_order", "unique_sessions", "finite_positive_ohlc",
      "ohlc_geometry", "adjusted_daily_only", "exact_requested_boundary", "confirmation_sealed"
    ),
    passed = c(
      identical(unique(out$symbol), contract$symbol),
      all(diff(out$session_date) > 0),
      !anyDuplicated(out$session_date),
      all(is.finite(prices) & prices > 0),
      all(out$high >= pmax(out$open, out$close, out$low) & out$low <= pmin(out$open, out$close, out$high)),
      all(out$adjusted %in% TRUE) && all(out$timeframe == "1D"),
      min(out$session_date) == contract$query_start && max(out$session_date) == contract$analysis_end,
      all(out$session_date < contract$confirmation_start)
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  list(bars = out, checks = checks)
}

g5_reg011_feature_frame <- function(bars, contract = g5_reg011_contract()) {
  checked <- g5_reg011_validate_bars(bars, contract)
  x <- checked$bars
  previous_close <- c(NA_real_, head(x$close, -1L))
  true_range <- pmax(
    x$high - x$low,
    abs(x$high - previous_close),
    abs(x$low - previous_close),
    na.rm = TRUE
  )
  normalized_true_range <- true_range / x$close
  frame <- data.frame(
    symbol = x$symbol,
    session_date = x$session_date,
    close = x$close,
    log_return = c(NA_real_, diff(log(x$close))),
    true_range = true_range,
    normalized_true_range = normalized_true_range,
    log_normalized_true_range = log(normalized_true_range),
    stringsAsFactors = FALSE
  )
  frame$true_range[[1L]] <- NA_real_
  frame$normalized_true_range[[1L]] <- NA_real_
  frame$log_normalized_true_range[[1L]] <- NA_real_
  if (any(!is.finite(frame$log_return[-1L])) || any(!is.finite(frame$log_normalized_true_range[-1L]))) {
    g5_hmm_stop("Feature construction produced invalid observations.")
  }
  list(frame = frame, checks = checked$checks)
}

g5_reg011_standardize_fold <- function(feature_frame, fold) {
  columns <- c("log_return", "log_normalized_true_range")
  train_rows <- feature_frame$session_date >= fold$train_start & feature_frame$session_date <= fold$train_end
  oos_rows <- feature_frame$session_date >= fold$oos_start & feature_frame$session_date <= fold$oos_end
  train <- feature_frame[train_rows & stats::complete.cases(feature_frame[columns]), , drop = FALSE]
  oos <- feature_frame[oos_rows & stats::complete.cases(feature_frame[columns]), , drop = FALSE]
  if (!nrow(train) || !nrow(oos)) g5_hmm_stop(paste("Fold", fold$fold_id, "has no complete TRAIN or OOS observations."))
  center <- vapply(train[columns], mean, numeric(1))
  scale <- vapply(train[columns], stats::sd, numeric(1))
  if (any(!is.finite(scale)) || any(scale <= 0)) g5_hmm_stop("TRAIN standardization scale is invalid.")
  standardize <- function(x) sweep(sweep(as.matrix(x[columns]), 2L, center, "-"), 2L, scale, "/")
  list(
    fold_id = fold$fold_id,
    train = train,
    oos = oos,
    train_x = standardize(train),
    oos_x = standardize(oos),
    center = center,
    scale = scale
  )
}

g5_reg011_fit_synthetic_case <- function(parameters, seed, fixtures, contract) {
  simulated <- g5_hmm_simulate(
    fixtures$sequence_length,
    parameters$transition,
    parameters$means,
    parameters$covariances,
    seed
  )
  raw_fit <- g5_hmm_fit_hmm_once(
    simulated$observations,
    state_count = 2L,
    seed = seed + fixtures$fit_seed_offset,
    self_transition = 0.90,
    eigen_floor = contract$eigen_floor,
    probability_floor = contract$probability_floor,
    max_iterations = contract$max_iterations,
    tolerance_per_observation = contract$tolerance_per_observation,
    patience = contract$convergence_patience
  )
  fit <- if (isTRUE(raw_fit$converged)) g5_hmm_order_fit(raw_fit) else raw_fit
  valid <- isTRUE(fit$converged) && is.finite(fit$log_likelihood) &&
    all(is.finite(g5_hmm_covariance_eigenvalues(fit$covariances))) &&
    min(g5_hmm_covariance_eigenvalues(fit$covariances)) >= contract$eigen_floor - 1e-10
  accuracy <- if (valid) g5_hmm_classification_accuracy(fit$filtered, simulated$states) else NA_real_
  transition_error <- if (valid) max(abs(fit$transition - parameters$transition)) else NA_real_
  expected_duration <- 1 / (1 - diag(parameters$transition))
  fitted_duration <- if (valid) 1 / (1 - diag(fit$transition)) else rep(NA_real_, 2L)
  duration_relative_error <- if (valid) max(abs(fitted_duration - expected_duration) / expected_duration) else NA_real_
  entropy <- if (valid) g5_hmm_posterior_entropy(fit$filtered) else NA_real_
  confidence <- if (valid) mean(apply(fit$filtered, 1L, max)) else NA_real_
  data.frame(
    seed = seed,
    converged = isTRUE(fit$converged),
    convergence_code = fit$convergence_code,
    iterations = fit$iterations,
    valid = valid,
    accuracy = accuracy,
    maximum_transition_error = transition_error,
    maximum_duration_relative_error = duration_relative_error,
    posterior_entropy = entropy,
    maximum_posterior_confidence = confidence,
    minimum_covariance_eigenvalue = min(g5_hmm_covariance_eigenvalues(fit$covariances)),
    stringsAsFactors = FALSE
  )
}

g5_reg011_stage_a <- function(
  contract = g5_reg011_contract(),
  fixtures = g5_reg011_synthetic_fixtures(),
  simulation_limit = NULL,
  case_map = lapply
) {
  contract <- g5_reg011_validate_contract(contract)
  strong_seeds <- fixtures$strong_seeds
  weak_seeds <- fixtures$weak_seeds
  if (!is.null(simulation_limit)) {
    strong_seeds <- head(strong_seeds, as.integer(simulation_limit))
    weak_seeds <- head(weak_seeds, as.integer(simulation_limit))
  }

  short <- g5_hmm_simulate(
    8L, fixtures$strong$transition, fixtures$strong$means,
    fixtures$strong$covariances, seed = 61090L
  )
  forward <- g5_hmm_forward_backward(
    short$observations,
    g5_hmm_stationary(fixtures$strong$transition),
    fixtures$strong$transition,
    fixtures$strong$means,
    fixtures$strong$covariances
  )
  brute <- g5_hmm_bruteforce_loglikelihood(
    short$observations,
    g5_hmm_stationary(fixtures$strong$transition),
    fixtures$strong$transition,
    fixtures$strong$means,
    fixtures$strong$covariances
  )
  h3_transition <- matrix(c(.9, .05, .05, .05, .9, .05, .05, .05, .9), 3L, 3L, byrow = TRUE)
  h3_means <- rbind(c(0, -1), c(0, 0), c(0, 1))
  h3_covariances <- replicate(3L, diag(c(.7, .25)), simplify = FALSE)
  h3_forward <- g5_hmm_forward_backward(
    short$observations, g5_hmm_stationary(h3_transition), h3_transition,
    h3_means, h3_covariances
  )
  b0 <- g5_hmm_fit_b0(short$observations)
  b1 <- g5_hmm_fit_gmm_once(short$observations, 2L, 61090L, max_iterations = 1000L)
  numerical_invariants <- is.finite(b0$log_likelihood) && is.finite(b1$log_likelihood) &&
    abs(forward$log_likelihood - brute) <= 1e-10 &&
    max(abs(rowSums(forward$filtered) - 1)) <= 1e-12 &&
    max(abs(rowSums(h3_forward$filtered) - 1)) <= 1e-12 &&
    min(g5_hmm_covariance_eigenvalues(c(b0$covariances, b1$covariances, h3_covariances))) > 0

  deterministic_sim <- g5_hmm_simulate(
    500L, fixtures$strong$transition, fixtures$strong$means,
    fixtures$strong$covariances, seed = 61091L
  )
  repeated_a <- g5_hmm_fit_multistart(
    deterministic_sim$observations, 2L, contract$b1_h2_seeds, model = "hmm",
    self_transitions = contract$self_transitions, eigen_floor = contract$eigen_floor,
    probability_floor = contract$probability_floor, max_iterations = contract$max_iterations,
    tolerance_per_observation = contract$tolerance_per_observation,
    patience = contract$convergence_patience
  )
  repeated_b <- g5_hmm_fit_multistart(
    deterministic_sim$observations, 2L, contract$b1_h2_seeds, model = "hmm",
    self_transitions = contract$self_transitions, eigen_floor = contract$eigen_floor,
    probability_floor = contract$probability_floor, max_iterations = contract$max_iterations,
    tolerance_per_observation = contract$tolerance_per_observation,
    patience = contract$convergence_patience
  )
  deterministic_difference <- if (is.null(repeated_a$selected) || is.null(repeated_b$selected)) Inf else max(c(
    abs(repeated_a$selected$log_likelihood - repeated_b$selected$log_likelihood),
    abs(repeated_a$selected$means - repeated_b$selected$means),
    abs(repeated_a$selected$transition - repeated_b$selected$transition),
    abs(repeated_a$selected$filtered - repeated_b$selected$filtered)
  ))

  append_prefix <- deterministic_sim$observations[1:350, , drop = FALSE]
  append_full <- deterministic_sim$observations[1:500, , drop = FALSE]
  append_parameters <- repeated_a$selected
  prefix_filtered <- g5_hmm_filter(
    append_prefix, append_parameters$pi, append_parameters$transition,
    append_parameters$means, append_parameters$covariances
  )
  full_filtered <- g5_hmm_filter(
    append_full, append_parameters$pi, append_parameters$transition,
    append_parameters$means, append_parameters$covariances
  )
  append_difference <- max(abs(prefix_filtered - full_filtered[seq_len(nrow(prefix_filtered)), ]))
  smoothing_revision <- max(abs(repeated_a$selected$filtered - repeated_a$selected$smoothed))

  strong <- do.call(rbind, case_map(strong_seeds, function(seed) {
    g5_reg011_fit_synthetic_case(fixtures$strong, seed, fixtures, contract)
  }))
  strong$fixture <- "STRONG"
  weak <- do.call(rbind, case_map(weak_seeds, function(seed) {
    g5_reg011_fit_synthetic_case(fixtures$weak, seed, fixtures, contract)
  }))
  weak$fixture <- "WEAK"
  simulations <- rbind(strong, weak)
  assertion <- fixtures$assertions
  all_valid <- all(simulations$valid) && all(is.finite(as.matrix(simulations[c(
    "accuracy", "maximum_transition_error", "maximum_duration_relative_error",
    "posterior_entropy", "maximum_posterior_confidence", "minimum_covariance_eigenvalue"
  )])))
  strong_median_accuracy <- stats::median(strong$accuracy)
  strong_tenth_accuracy <- as.numeric(stats::quantile(strong$accuracy, 0.10, names = FALSE, type = 7))
  transition_median <- stats::median(strong$maximum_transition_error)
  transition_ninetieth <- as.numeric(stats::quantile(strong$maximum_transition_error, 0.90, names = FALSE, type = 7))
  strong_entropy <- mean(strong$posterior_entropy)
  weak_entropy <- mean(weak$posterior_entropy)
  strong_confidence <- mean(strong$maximum_posterior_confidence)
  weak_confidence <- mean(weak$maximum_posterior_confidence)
  duration_median <- stats::median(strong$maximum_duration_relative_error)

  gates <- data.frame(
    gate = paste0("A", 1:8),
    gate_name = c(
      "ENGINE_INVARIANTS", "DETERMINISTIC_REPLAY", "APPEND_CAUSALITY",
      "STRONG_CLASSIFICATION", "TRANSITION_RECOVERY", "WEAK_UNCERTAINTY",
      "ORDERING_AND_DURATION", "ZERO_INVALID_FITS"
    ),
    threshold = c(
      "B0/B1/H2/H3 invariants; brute-force likelihood tolerance <=1e-10",
      "repeated selected parameters/probabilities/likelihood tolerance <=1e-12",
      "filtered prefix unchanged <=1e-12; smoothing separately revises history",
      "50 strong simulations: median accuracy >=90%; 10th percentile >=85%",
      "strong transition error: median <=0.03; 90th percentile <=0.08",
      "weak entropy > strong; mean maximum confidence >=0.10 lower",
      "exact ordering/permutation mechanics; median duration relative error <=25%",
      "zero nonfinite, invalid covariance/probability, or unreported failures"
    ),
    observed = c(
      sprintf("forward-brute %.3g; H2/H3 probability sums valid %s", abs(forward$log_likelihood - brute), numerical_invariants),
      sprintf("maximum replay difference %.3g", deterministic_difference),
      sprintf("prefix difference %.3g; smoothing revision %.3g", append_difference, smoothing_revision),
      sprintf("median %.1f%%; 10th percentile %.1f%%", 100 * strong_median_accuracy, 100 * strong_tenth_accuracy),
      sprintf("median %.4f; 90th percentile %.4f", transition_median, transition_ninetieth),
      sprintf("entropy strong %.3f vs weak %.3f; confidence reduction %.3f", strong_entropy, weak_entropy, strong_confidence - weak_confidence),
      sprintf("median maximum duration relative error %.1f%%", 100 * duration_median),
      sprintf("%d/%d valid fits", sum(simulations$valid), nrow(simulations))
    ),
    passed = c(
      numerical_invariants,
      deterministic_difference <= 1e-12,
      append_difference <= 1e-12 && smoothing_revision > 1e-6,
      length(strong_seeds) == 50L && strong_median_accuracy >= assertion$strong_median_accuracy_minimum && strong_tenth_accuracy >= assertion$strong_tenth_percentile_accuracy_minimum,
      length(strong_seeds) == 50L && transition_median <= assertion$transition_median_maximum_error && transition_ninetieth <= assertion$transition_ninetieth_percentile_maximum_error,
      length(weak_seeds) == 50L && weak_entropy > strong_entropy && strong_confidence - weak_confidence >= assertion$weak_confidence_reduction_minimum,
      duration_median <= assertion$duration_median_relative_error_maximum,
      all_valid
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  list(
    contract = contract,
    fixtures = fixtures,
    gates = gates,
    simulations = simulations,
    replay_diagnostics = rbind(
      transform(repeated_a$diagnostics, replay = "A"),
      transform(repeated_b$diagnostics, replay = "B")
    ),
    passed = all(gates$passed),
    verdict = if (all(gates$passed)) {
      "STAGE_A_PASS_REAL_DATA_RUN_OPEN"
    } else {
      "STOP_LIT_REG_01_1_ENGINE_OR_SYNTHETIC_GATES_FAILED_REAL_DATA_NOT_READ"
    }
  )
}

g5_reg011_moving_block_indices <- function(n, block_length) {
  starts <- seq_len(max(1L, n - block_length + 1L))
  out <- integer()
  while (length(out) < n) {
    start <- sample(starts, 1L)
    out <- c(out, seq.int(start, min(n, start + block_length - 1L)))
  }
  head(out, n)
}

g5_reg011_block_bootstrap <- function(daily_scores, contract = g5_reg011_contract()) {
  contract <- g5_reg011_validate_contract(contract)
  split_scores <- split(daily_scores$difference, daily_scores$fold_id)
  set.seed(contract$bootstrap_seed)
  draws <- replicate(contract$bootstrap_count, {
    sampled <- unlist(lapply(split_scores, function(x) {
      x[g5_reg011_moving_block_indices(length(x), contract$bootstrap_block_length)]
    }), use.names = FALSE)
    mean(sampled)
  })
  data.frame(
    replicate = seq_along(draws),
    mean_h2_minus_b1 = draws,
    stringsAsFactors = FALSE
  )
}

g5_reg011_permuted_blocks <- function(x, block_length) {
  n <- nrow(x)
  starts <- seq.int(1L, n, by = block_length)
  blocks <- lapply(starts, function(start) x[start:min(n, start + block_length - 1L), , drop = FALSE])
  do.call(rbind, blocks[sample.int(length(blocks))])
}
