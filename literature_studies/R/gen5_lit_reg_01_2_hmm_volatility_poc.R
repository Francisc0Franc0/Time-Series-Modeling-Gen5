# Volatility-only reference HMM qualification and causal scoring for LIT-REG-01.2.

g5_reg012_stop <- function(message) stop(message, call. = FALSE)

g5_reg012_schema_version <- function() "gen5_lit_reg_01_2_hmm_volatility_v1"

g5_reg012_contract <- function() {
  list(
    literature_id = "LIT-REG-01.2",
    descriptive_name = "Two-State HMM Volatility-State Forecast",
    as_of_timestamp = "2026-08-18 17:30:00 America/New_York",
    history_start = as.Date("2016-01-04"),
    history_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    development_symbol = "SPY",
    replication_symbols = c("QQQ", "IWM", "EFA", "TLT"),
    reference_package = "HiddenMarkov",
    reference_version = "1.8.14",
    gmm_seeds = 62101:62112,
    hmm_seeds = 62201:62212,
    self_transitions = c(0.80, 0.90, 0.95, 0.98),
    maximum_iterations = 1000L,
    convergence_tolerance = 1e-6,
    minimum_sd = 0.01,
    minimum_occupancy = 0.10,
    minimum_self_transition = 0.50,
    minimum_emission_separation = 0.75,
    high_range_quantile = 0.80,
    block_length = 20L,
    bootstrap_replicates = 2000L,
    bootstrap_seed = 62301L,
    permutation_replicates = 200L,
    permutation_seed = 62302L,
    folds = data.frame(
      fold_id = paste0("F", 1:4),
      train_start = as.Date(rep("2016-01-04", 4)),
      train_end = as.Date(c("2019-12-31", "2020-12-31", "2021-12-31", "2022-12-30")),
      oos_start = as.Date(c("2020-01-02", "2021-01-04", "2022-01-03", "2023-01-03")),
      oos_end = as.Date(c("2020-12-31", "2021-12-31", "2022-12-30", "2023-12-29")),
      stringsAsFactors = FALSE
    )
  )
}

g5_reg012_require_reference <- function(contract = g5_reg012_contract()) {
  if (!requireNamespace(contract$reference_package, quietly = TRUE)) {
    g5_reg012_stop(paste0(
      "Approved reference package ", contract$reference_package,
      " is unavailable in .libPaths()."
    ))
  }
  observed <- as.character(utils::packageVersion(contract$reference_package))
  if (!identical(observed, contract$reference_version)) {
    g5_reg012_stop(paste0(
      "Reference version mismatch: expected ", contract$reference_version,
      ", observed ", observed, "."
    ))
  }
  invisible(observed)
}

g5_reg012_normalize_exact <- function(probability) {
  probability <- as.numeric(probability)
  if (!length(probability) || any(!is.finite(probability)) || any(probability <= 0)) {
    g5_reg012_stop("Probability vector must be finite and strictly positive.")
  }
  probability / sum(probability)
}

g5_reg012_normalize_rows_exact <- function(transition) {
  transition <- as.matrix(transition)
  if (!nrow(transition) || nrow(transition) != ncol(transition) ||
      any(!is.finite(transition)) || any(transition <= 0)) {
    g5_reg012_stop("Transition matrix must be square, finite, and strictly positive.")
  }
  transition / rowSums(transition)
}

g5_reg012_forward <- function(x, delta, transition, means, sds) {
  x <- as.numeric(x)
  delta <- g5_reg012_normalize_exact(delta)
  transition <- g5_reg012_normalize_rows_exact(transition)
  means <- as.numeric(means)
  sds <- as.numeric(sds)
  state_count <- length(delta)
  if (!length(x) || length(means) != state_count || length(sds) != state_count ||
      any(!is.finite(x)) || any(!is.finite(means)) || any(!is.finite(sds)) ||
      any(sds <= 0)) {
    g5_reg012_stop("Invalid univariate HMM arguments.")
  }
  log_emission <- vapply(seq_len(state_count), function(k) {
    stats::dnorm(x, mean = means[[k]], sd = sds[[k]], log = TRUE)
  }, numeric(length(x)))
  if (!is.matrix(log_emission)) log_emission <- matrix(log_emission, ncol = state_count)
  log_alpha <- matrix(-Inf, nrow = length(x), ncol = state_count)
  log_score <- numeric(length(x))
  first <- log(delta) + log_emission[1L, ]
  log_score[[1L]] <- g5_hmm_logsumexp(first)
  log_alpha[1L, ] <- first - log_score[[1L]]
  if (length(x) > 1L) {
    log_transition <- log(transition)
    for (index in 2:length(x)) {
      predicted <- vapply(seq_len(state_count), function(j) {
        g5_hmm_logsumexp(log_alpha[index - 1L, ] + log_transition[, j])
      }, numeric(1))
      current <- predicted + log_emission[index, ]
      log_score[[index]] <- g5_hmm_logsumexp(current)
      log_alpha[index, ] <- current - log_score[[index]]
    }
  }
  filtered <- exp(log_alpha)
  if (any(!is.finite(log_score)) || any(!is.finite(filtered)) ||
      max(abs(rowSums(filtered) - 1)) > 1e-12) {
    g5_reg012_stop("Reference cross-check probability invariant failed.")
  }
  list(
    log_likelihood = sum(log_score),
    log_score = log_score,
    filtered = filtered,
    log_emission = log_emission
  )
}

g5_reg012_order_reference_fit <- function(fit) {
  order_index <- order(fit$means, seq_along(fit$means))
  fit$means <- fit$means[order_index]
  fit$sds <- fit$sds[order_index]
  fit$delta <- fit$delta[order_index]
  fit$transition <- fit$transition[order_index, order_index, drop = FALSE]
  fit$filtered <- fit$filtered[, order_index, drop = FALSE]
  fit$smoothed <- fit$smoothed[, order_index, drop = FALSE]
  fit$occupancy <- fit$occupancy[order_index]
  fit$state_order <- order_index
  fit
}

g5_reg012_fit_reference_once <- function(
  x,
  seed,
  self_transition,
  maximum_iterations = 1000L,
  convergence_tolerance = 1e-6,
  minimum_sd = 0.01
) {
  x <- as.numeric(x)
  result <- list(
    seed = as.integer(seed),
    initial_self_transition = self_transition,
    converged = FALSE,
    convergence_code = "UNINITIALIZED",
    iterations = NA_integer_,
    difference = NA_real_,
    log_likelihood = -Inf,
    reference_log_likelihood = -Inf,
    crosscheck_difference_per_observation = Inf
  )
  initialized <- tryCatch(
    g5_hmm_kmeans_initialization(
      matrix(x, ncol = 1L), 2L, as.integer(seed), self_transition,
      eigen_floor = minimum_sd^2, probability_floor = 1e-6
    ),
    error = function(error) NULL
  )
  if (is.null(initialized)) {
    result$convergence_code <- "INITIALIZATION_FAILURE"
    return(result)
  }
  transition <- initialized$transition
  delta <- initialized$pi
  means <- as.numeric(initialized$means[, 1L])
  sds <- sqrt(vapply(initialized$covariances, function(x) x[1L, 1L], numeric(1)))
  object <- tryCatch(
    HiddenMarkov::dthmm(
      x = x,
      Pi = transition,
      delta = delta,
      distn = "norm",
      pm = list(mean = means, sd = sds),
      nonstat = TRUE
    ),
    error = function(error) NULL
  )
  if (is.null(object)) {
    result$convergence_code <- "OBJECT_FAILURE"
    return(result)
  }
  fitted <- tryCatch(
    HiddenMarkov::BaumWelch(
      object,
      HiddenMarkov::bwcontrol(
        maxiter = as.integer(maximum_iterations),
        tol = convergence_tolerance,
        prt = FALSE,
        posdiff = TRUE
      )
    ),
    error = function(error) structure(list(message = conditionMessage(error)), class = "g5_reg012_fit_error")
  )
  if (inherits(fitted, "g5_reg012_fit_error")) {
    result$convergence_code <- if (grepl("Worse log-likelihood", fitted$message, fixed = TRUE)) {
      "LIKELIHOOD_DECREASE"
    } else {
      paste0("PACKAGE_ERROR: ", fitted$message)
    }
    return(result)
  }
  result$iterations <- as.integer(fitted$iter)
  result$difference <- as.numeric(fitted$diff)
  result$reference_log_likelihood <- tryCatch(as.numeric(stats::logLik(fitted)), error = function(error) -Inf)
  result$means <- as.numeric(fitted$pm$mean)
  result$sds <- as.numeric(fitted$pm$sd)
  result$delta <- as.numeric(fitted$delta)
  result$transition <- as.matrix(fitted$Pi)
  result$smoothed <- as.matrix(fitted$u)
  valid_parameters <- all(is.finite(c(
    result$means, result$sds, result$delta, result$transition,
    result$reference_log_likelihood, result$difference
  ))) && all(result$sds >= minimum_sd) && all(result$delta > 0) &&
    all(result$transition > 0) && all(result$transition < 1)
  converged <- valid_parameters && result$iterations < maximum_iterations &&
    result$difference >= 0 && result$difference < convergence_tolerance
  if (!converged) {
    result$convergence_code <- if (!valid_parameters) {
      "INVALID_PARAMETERS"
    } else if (result$iterations >= maximum_iterations) {
      "MAX_ITERATIONS"
    } else if (result$difference < 0) {
      "LIKELIHOOD_DECREASE"
    } else {
      "NOT_CONVERGED"
    }
    return(result)
  }
  forward <- tryCatch(
    g5_reg012_forward(x, result$delta, result$transition, result$means, result$sds),
    error = function(error) NULL
  )
  if (is.null(forward)) {
    result$convergence_code <- "GEN5_FORWARD_FAILURE"
    return(result)
  }
  result$filtered <- forward$filtered
  result$log_likelihood <- forward$log_likelihood
  result$crosscheck_difference_per_observation <- abs(
    result$reference_log_likelihood - result$log_likelihood
  ) / length(x)
  result$occupancy <- colMeans(result$smoothed)
  result$converged <- TRUE
  result$convergence_code <- "CONVERGED"
  g5_reg012_order_reference_fit(result)
}

g5_reg012_fit_reference_multistart <- function(x, contract = g5_reg012_contract()) {
  g5_reg012_require_reference(contract)
  fits <- lapply(seq_along(contract$hmm_seeds), function(index) {
    g5_reg012_fit_reference_once(
      x = x,
      seed = contract$hmm_seeds[[index]],
      self_transition = contract$self_transitions[[
        1L + (index - 1L) %% length(contract$self_transitions)
      ]],
      maximum_iterations = contract$maximum_iterations,
      convergence_tolerance = contract$convergence_tolerance,
      minimum_sd = contract$minimum_sd
    )
  })
  valid <- vapply(fits, function(fit) {
    isTRUE(fit$converged) && is.finite(fit$log_likelihood)
  }, logical(1))
  diagnostics <- do.call(rbind, lapply(seq_along(fits), function(index) {
    fit <- fits[[index]]
    data.frame(
      fit_id = sprintf("H2_REFERENCE_START_%02d", index),
      seed = fit$seed,
      initial_self_transition = fit$initial_self_transition,
      converged = isTRUE(fit$converged),
      convergence_code = fit$convergence_code,
      iterations = fit$iterations,
      difference = fit$difference,
      log_likelihood = fit$log_likelihood,
      reference_log_likelihood = fit$reference_log_likelihood,
      crosscheck_difference_per_observation = fit$crosscheck_difference_per_observation,
      minimum_sd = if (is.null(fit$sds)) NA_real_ else min(fit$sds),
      minimum_occupancy = if (is.null(fit$occupancy)) NA_real_ else min(fit$occupancy),
      stringsAsFactors = FALSE
    )
  }))
  if (!any(valid)) return(list(selected = NULL, fits = fits, diagnostics = diagnostics))
  eligible <- which(valid)
  selected_index <- eligible[[which.max(vapply(
    fits[eligible], `[[`, numeric(1), "log_likelihood"
  ))]]
  diagnostics$selected <- seq_len(nrow(diagnostics)) == selected_index
  selected <- fits[[selected_index]]
  selected$selected_fit_id <- diagnostics$fit_id[[selected_index]]
  list(selected = selected, fits = fits, diagnostics = diagnostics)
}

g5_reg012_fit_ar1 <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 3L || any(!is.finite(x))) g5_reg012_stop("AR(1) requires finite observations.")
  lagged <- x[-length(x)]
  current <- x[-1L]
  phi <- stats::cov(lagged, current) / stats::var(lagged)
  if (!is.finite(phi)) phi <- 0
  phi <- max(-0.99, min(0.99, phi))
  alpha <- mean(current - phi * lagged)
  residual <- current - alpha - phi * lagged
  sigma <- sqrt(mean(residual^2))
  if (!is.finite(sigma) || sigma <= 0) g5_reg012_stop("AR(1) innovation variance is invalid.")
  log_likelihood <- sum(stats::dnorm(residual, mean = 0, sd = sigma, log = TRUE))
  list(model_id = "B2_AR1", alpha = alpha, phi = phi, sigma = sigma, log_likelihood = log_likelihood)
}

g5_reg012_bic <- function(log_likelihood, parameter_count, observation_count) {
  -2 * log_likelihood + parameter_count * log(observation_count)
}

g5_reg012_identify <- function(x, reference, gmm, b0, contract = g5_reg012_contract()) {
  if (is.null(reference$selected) || is.null(gmm$selected)) {
    return(list(status = "NUMERICAL_FAILURE", reason = "NO_VALID_SELECTED_FIT"))
  }
  hmm <- reference$selected
  gmm_fit <- gmm$selected
  crosscheck_pass <- is.finite(hmm$crosscheck_difference_per_observation) &&
    hmm$crosscheck_difference_per_observation <= 1e-8
  if (!crosscheck_pass) {
    return(list(status = "NUMERICAL_FAILURE", reason = "REFERENCE_CROSSCHECK_FAILED"))
  }
  separation <- abs(diff(hmm$means)) / sqrt(mean(hmm$sds^2))
  bic_h2 <- g5_reg012_bic(hmm$log_likelihood, 7L, length(x))
  bic_b1 <- g5_reg012_bic(gmm_fit$log_likelihood, 5L, length(x))
  bic_b0 <- g5_reg012_bic(b0$log_likelihood, 2L, length(x))
  checks <- c(
    occupancy = min(hmm$occupancy) >= contract$minimum_occupancy,
    self_transition = min(diag(hmm$transition)) > contract$minimum_self_transition,
    separation = separation >= contract$minimum_emission_separation,
    bic = bic_h2 < bic_b0 && bic_h2 < bic_b1
  )
  status <- if (all(checks)) {
    "VALID_TWO_STATE_MODEL"
  } else {
    "TWO_STATES_NOT_IDENTIFIABLE_USE_BASELINE"
  }
  list(
    status = status,
    reason = if (all(checks)) "ALL_IDENTIFICATION_CHECKS_PASS" else paste(names(checks)[!checks], collapse = ";"),
    checks = checks,
    separation = separation,
    bic_h2 = bic_h2,
    bic_b1 = bic_b1,
    bic_b0 = bic_b0
  )
}

g5_reg012_fit_case <- function(x, contract = g5_reg012_contract()) {
  x <- as.numeric(x)
  b0 <- g5_hmm_fit_b0(matrix(x, ncol = 1L), eigen_floor = contract$minimum_sd^2)
  gmm <- g5_hmm_fit_multistart(
    matrix(x, ncol = 1L), 2L, contract$gmm_seeds,
    model = "gmm", eigen_floor = contract$minimum_sd^2,
    max_iterations = contract$maximum_iterations,
    tolerance_per_observation = contract$convergence_tolerance / length(x),
    patience = 1L
  )
  reference <- g5_reg012_fit_reference_multistart(x, contract)
  identification <- g5_reg012_identify(x, reference, gmm, b0, contract)
  list(b0 = b0, gmm = gmm, reference = reference, identification = identification)
}

g5_reg012_synthetic_registry <- function() {
  data.frame(
    fixture_id = c(
      sprintf("STRONG_%02d", 1:20),
      sprintf("WEAK_%02d", 1:20),
      sprintf("NULL_%02d", 1:20)
    ),
    fixture_class = rep(c("strong", "weak", "null"), each = 20L),
    seed = c(62401:62420, 62501:62520, 62601:62620),
    observation_count = 1200L,
    stringsAsFactors = FALSE
  )
}

g5_reg012_simulation_parameters <- function(fixture_class) {
  fixture_class <- match.arg(fixture_class, c("strong", "weak", "null"))
  transition <- matrix(c(0.96, 0.04, 0.08, 0.92), nrow = 2L, byrow = TRUE)
  if (fixture_class == "strong") {
    return(list(transition = transition, means = c(-1.0, 1.0), sds = c(0.45, 0.55)))
  }
  if (fixture_class == "weak") {
    return(list(transition = transition, means = c(-0.15, 0.15), sds = c(1.0, 1.0)))
  }
  list(transition = NULL, means = 0, sds = 1)
}

g5_reg012_simulate_fixture <- function(registry_row) {
  fixture_class <- as.character(registry_row$fixture_class[[1L]])
  seed <- as.integer(registry_row$seed[[1L]])
  observation_count <- as.integer(registry_row$observation_count[[1L]])
  parameters <- g5_reg012_simulation_parameters(fixture_class)
  if (fixture_class == "null") {
    set.seed(seed)
    return(list(
      observations = stats::rnorm(observation_count),
      states = rep(1L, observation_count),
      parameters = parameters
    ))
  }
  simulated <- g5_hmm_simulate(
    n = observation_count,
    transition = parameters$transition,
    means = matrix(parameters$means, ncol = 1L),
    covariances = lapply(parameters$sds^2, matrix, nrow = 1L, ncol = 1L),
    seed = seed
  )
  list(
    observations = as.numeric(simulated$observations[, 1L]),
    states = simulated$states,
    parameters = parameters
  )
}

g5_reg012_evaluate_fixture <- function(registry_row, contract = g5_reg012_contract()) {
  simulated <- g5_reg012_simulate_fixture(registry_row)
  fitted <- g5_reg012_fit_case(simulated$observations, contract)
  selected <- fitted$reference$selected
  status <- fitted$identification$status
  filtered_accuracy <- if (!is.null(selected) && registry_row$fixture_class[[1L]] != "null") {
    mean(max.col(selected$filtered, ties.method = "first") == simulated$states)
  } else {
    NA_real_
  }
  transition_error <- if (!is.null(selected) && registry_row$fixture_class[[1L]] != "null") {
    max(abs(selected$transition - simulated$parameters$transition))
  } else {
    NA_real_
  }
  entropy <- if (is.null(selected)) NA_real_ else g5_hmm_posterior_entropy(selected$filtered)
  confidence <- if (is.null(selected)) NA_real_ else mean(apply(selected$filtered, 1L, max))
  summary <- data.frame(
    fixture_id = registry_row$fixture_id[[1L]],
    fixture_class = registry_row$fixture_class[[1L]],
    seed = registry_row$seed[[1L]],
    status = status,
    reason = fitted$identification$reason,
    filtered_accuracy = filtered_accuracy,
    maximum_transition_error = transition_error,
    posterior_entropy = entropy,
    maximum_confidence = confidence,
    emission_separation = if (is.null(fitted$identification$separation)) NA_real_ else fitted$identification$separation,
    bic_h2 = if (is.null(fitted$identification$bic_h2)) NA_real_ else fitted$identification$bic_h2,
    bic_b1 = if (is.null(fitted$identification$bic_b1)) NA_real_ else fitted$identification$bic_b1,
    bic_b0 = if (is.null(fitted$identification$bic_b0)) NA_real_ else fitted$identification$bic_b0,
    crosscheck_difference_per_observation = if (is.null(selected)) NA_real_ else selected$crosscheck_difference_per_observation,
    stringsAsFactors = FALSE
  )
  diagnostics <- fitted$reference$diagnostics
  diagnostics$fixture_id <- registry_row$fixture_id[[1L]]
  diagnostics$fixture_class <- registry_row$fixture_class[[1L]]
  list(summary = summary, diagnostics = diagnostics, fitted = fitted, simulated = simulated)
}

g5_reg012_short_likelihood_check <- function() {
  x <- c(-0.4, 0.2, 1.1, -0.1, 0.7, -0.8)
  transition <- matrix(c(0.91, 0.09, 0.14, 0.86), nrow = 2L, byrow = TRUE)
  delta <- c(0.6, 0.4)
  means <- c(-0.5, 0.8)
  sds <- c(0.7, 0.9)
  object <- HiddenMarkov::dthmm(
    x, transition, delta, "norm", list(mean = means, sd = sds), nonstat = TRUE
  )
  reference <- as.numeric(stats::logLik(object))
  gen5 <- g5_reg012_forward(x, delta, transition, means, sds)$log_likelihood
  data.frame(reference_log_likelihood = reference, gen5_log_likelihood = gen5, difference = abs(reference - gen5))
}

g5_reg012_replay_and_causality_checks <- function(contract = g5_reg012_contract()) {
  row <- g5_reg012_synthetic_registry()[1L, , drop = FALSE]
  simulated <- g5_reg012_simulate_fixture(row)
  first <- g5_reg012_fit_case(simulated$observations, contract)$reference$selected
  second <- g5_reg012_fit_case(simulated$observations, contract)$reference$selected
  if (is.null(first) || is.null(second)) g5_reg012_stop("Replay fixture did not produce a valid selected fit.")
  differences <- c(
    means = max(abs(first$means - second$means)),
    sds = max(abs(first$sds - second$sds)),
    delta = max(abs(first$delta - second$delta)),
    transition = max(abs(first$transition - second$transition)),
    filtered = max(abs(first$filtered - second$filtered)),
    likelihood = abs(first$log_likelihood - second$log_likelihood)
  )
  prefix <- simulated$observations[1:300]
  appended <- simulated$observations[1:325]
  short <- g5_reg012_forward(prefix, first$delta, first$transition, first$means, first$sds)$filtered
  long <- g5_reg012_forward(appended, first$delta, first$transition, first$means, first$sds)$filtered
  smoothing_prefix <- g5_hmm_forward_backward(
    matrix(prefix, ncol = 1L), first$delta, first$transition,
    matrix(first$means, ncol = 1L), lapply(first$sds^2, matrix, nrow = 1L, ncol = 1L)
  )$smoothed
  smoothing_appended <- g5_hmm_forward_backward(
    matrix(appended, ncol = 1L), first$delta, first$transition,
    matrix(first$means, ncol = 1L), lapply(first$sds^2, matrix, nrow = 1L, ncol = 1L)
  )$smoothed[1:300, , drop = FALSE]
  list(
    replay_maximum_difference = max(differences),
    replay_differences = differences,
    append_filtered_maximum_difference = max(abs(short - long[1:300, , drop = FALSE])),
    smoothing_revision_maximum = max(abs(smoothing_prefix - smoothing_appended))
  )
}

g5_reg012_stage_a_gates <- function(summary, short_check, causal_check, contract = g5_reg012_contract()) {
  strong <- summary[summary$fixture_class == "strong", , drop = FALSE]
  weak <- summary[summary$fixture_class == "weak", , drop = FALSE]
  null <- summary[summary$fixture_class == "null", , drop = FALSE]
  allowed <- c("VALID_TWO_STATE_MODEL", "TWO_STATES_NOT_IDENTIFIABLE_USE_BASELINE")
  strong_valid <- sum(strong$status == "VALID_TWO_STATE_MODEL")
  weak_abstain <- sum(weak$status == "TWO_STATES_NOT_IDENTIFIABLE_USE_BASELINE")
  null_abstain <- sum(null$status == "TWO_STATES_NOT_IDENTIFIABLE_USE_BASELINE")
  null_promoted <- sum(null$status == "VALID_TWO_STATE_MODEL")
  numerical_failures <- sum(summary$status == "NUMERICAL_FAILURE")
  gate <- c(
    A1 = identical(as.character(utils::packageVersion("HiddenMarkov")), contract$reference_version) &&
      short_check$difference[[1L]] <= 1e-10,
    A2 = causal_check$replay_maximum_difference <= 1e-10,
    A3 = causal_check$append_filtered_maximum_difference <= 1e-12 &&
      causal_check$smoothing_revision_maximum > 0,
    A4 = all(strong$status != "NUMERICAL_FAILURE") && strong_valid >= 18L &&
      stats::median(strong$filtered_accuracy, na.rm = TRUE) >= 0.90 &&
      as.numeric(stats::quantile(strong$filtered_accuracy, 0.10, na.rm = TRUE)) >= 0.85,
    A5 = stats::median(strong$maximum_transition_error, na.rm = TRUE) <= 0.05 &&
      as.numeric(stats::quantile(strong$maximum_transition_error, 0.90, na.rm = TRUE)) <= 0.10,
    A6 = weak_abstain >= 14L &&
      mean(weak$posterior_entropy, na.rm = TRUE) > mean(strong$posterior_entropy, na.rm = TRUE) &&
      mean(strong$maximum_confidence, na.rm = TRUE) - mean(weak$maximum_confidence, na.rm = TRUE) >= 0.10,
    A7 = null_abstain >= 18L && null_promoted <= 2L,
    A8 = numerical_failures == 0L && all(summary$status %in% allowed) &&
      all(is.finite(summary$crosscheck_difference_per_observation))
  )
  observed <- c(
    paste0("version=", as.character(utils::packageVersion("HiddenMarkov")), "; likelihood_difference=", format(short_check$difference[[1L]], digits = 5)),
    paste0("maximum_replay_difference=", format(causal_check$replay_maximum_difference, digits = 5)),
    paste0("append_difference=", format(causal_check$append_filtered_maximum_difference, digits = 5), "; smoothing_revision=", format(causal_check$smoothing_revision_maximum, digits = 5)),
    paste0("strong_promoted=", strong_valid, "/20; median_accuracy=", sprintf("%.3f", stats::median(strong$filtered_accuracy, na.rm = TRUE)), "; p10_accuracy=", sprintf("%.3f", as.numeric(stats::quantile(strong$filtered_accuracy, 0.10, na.rm = TRUE)))),
    paste0("median_transition_error=", sprintf("%.4f", stats::median(strong$maximum_transition_error, na.rm = TRUE)), "; p90=", sprintf("%.4f", as.numeric(stats::quantile(strong$maximum_transition_error, 0.90, na.rm = TRUE)))),
    paste0("weak_abstained=", weak_abstain, "/20; entropy_strong=", sprintf("%.3f", mean(strong$posterior_entropy, na.rm = TRUE)), "; entropy_weak=", sprintf("%.3f", mean(weak$posterior_entropy, na.rm = TRUE)), "; confidence_reduction=", sprintf("%.3f", mean(strong$maximum_confidence, na.rm = TRUE) - mean(weak$maximum_confidence, na.rm = TRUE))),
    paste0("null_abstained=", null_abstain, "/20; null_promoted=", null_promoted),
    paste0("numerical_failures=", numerical_failures, "; classified=", sum(summary$status %in% allowed), "/60")
  )
  data.frame(
    gate_id = names(gate),
    passed = unname(gate),
    status = ifelse(unname(gate), "PASS", "FAIL"),
    observed = observed,
    stringsAsFactors = FALSE
  )
}
