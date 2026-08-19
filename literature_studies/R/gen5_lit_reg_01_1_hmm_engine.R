# Dependency-free Gaussian-mixture and hidden-Markov mechanics for LIT-REG-01.1.

g5_hmm_stop <- function(message) stop(message, call. = FALSE)

g5_hmm_logsumexp <- function(x) {
  x <- as.numeric(x)
  if (!length(x) || all(!is.finite(x))) return(-Inf)
  maximum <- max(x)
  maximum + log(sum(exp(x - maximum)))
}

g5_hmm_normalize <- function(x, floor = 1e-6) {
  x <- as.numeric(x)
  if (!length(x) || any(!is.finite(x))) g5_hmm_stop("Invalid probability vector.")
  x <- pmin(pmax(x, floor), 1 - floor)
  total <- sum(x)
  if (!is.finite(total) || total <= 0) g5_hmm_stop("Probability vector cannot be normalized.")
  x / total
}

g5_hmm_normalize_rows <- function(x, floor = 1e-6) {
  x <- as.matrix(x)
  if (!nrow(x) || !ncol(x) || any(!is.finite(x))) g5_hmm_stop("Invalid probability matrix.")
  out <- t(vapply(seq_len(nrow(x)), function(i) {
    g5_hmm_normalize(x[i, ], floor = floor)
  }, numeric(ncol(x))))
  dimnames(out) <- dimnames(x)
  out
}

g5_hmm_floor_covariance <- function(sigma, eigen_floor = 1e-4) {
  sigma <- as.matrix(sigma)
  if (nrow(sigma) != ncol(sigma) || any(!is.finite(sigma))) {
    g5_hmm_stop("Covariance matrix must be finite and square.")
  }
  sigma <- (sigma + t(sigma)) / 2
  eig <- eigen(sigma, symmetric = TRUE)
  values <- pmax(eig$values, eigen_floor)
  out <- eig$vectors %*% diag(values, nrow = length(values)) %*% t(eig$vectors)
  (out + t(out)) / 2
}

g5_hmm_covariance_eigenvalues <- function(covariances) {
  unlist(lapply(covariances, function(x) eigen(x, symmetric = TRUE, only.values = TRUE)$values))
}

g5_hmm_log_dmvnorm <- function(x, mean, sigma) {
  x <- as.matrix(x)
  mean <- as.numeric(mean)
  sigma <- as.matrix(sigma)
  if (ncol(x) != length(mean) || any(dim(sigma) != length(mean))) {
    g5_hmm_stop("Gaussian dimensions do not agree.")
  }
  root <- tryCatch(chol(sigma), error = function(e) NULL)
  if (is.null(root)) g5_hmm_stop("Gaussian covariance is not positive definite.")
  centered <- sweep(x, 2L, mean, "-")
  standardized <- forwardsolve(t(root), t(centered))
  quadratic <- colSums(standardized^2)
  -0.5 * (ncol(x) * log(2 * pi) + 2 * sum(log(diag(root))) + quadratic)
}

g5_hmm_log_emissions <- function(x, means, covariances) {
  x <- as.matrix(x)
  means <- as.matrix(means)
  if (ncol(x) != ncol(means) || length(covariances) != nrow(means)) {
    g5_hmm_stop("Emission parameters do not agree with observations.")
  }
  out <- vapply(seq_len(nrow(means)), function(k) {
    g5_hmm_log_dmvnorm(x, means[k, ], covariances[[k]])
  }, numeric(nrow(x)))
  if (!is.matrix(out)) out <- matrix(out, ncol = nrow(means))
  colnames(out) <- paste0("state_", seq_len(ncol(out)))
  out
}

g5_hmm_stationary <- function(transition, floor = 1e-6) {
  transition <- g5_hmm_normalize_rows(transition, floor = floor)
  k <- nrow(transition)
  system <- rbind(t(transition) - diag(k), rep(1, k))
  target <- c(rep(0, k), 1)
  probability <- tryCatch(
    as.numeric(qr.solve(system, target)),
    error = function(e) rep(1 / k, k)
  )
  g5_hmm_normalize(probability, floor = floor)
}

g5_hmm_forward_backward <- function(x, pi, transition, means, covariances) {
  x <- as.matrix(x)
  pi <- g5_hmm_normalize(pi)
  transition <- g5_hmm_normalize_rows(transition)
  k <- length(pi)
  if (nrow(transition) != k || ncol(transition) != k || nrow(means) != k) {
    g5_hmm_stop("HMM state dimensions do not agree.")
  }
  log_emission <- g5_hmm_log_emissions(x, means, covariances)
  n <- nrow(x)
  log_alpha <- matrix(-Inf, nrow = n, ncol = k)
  scales <- rep(NA_real_, n)

  first <- log(pi) + log_emission[1L, ]
  scales[[1L]] <- g5_hmm_logsumexp(first)
  log_alpha[1L, ] <- first - scales[[1L]]
  if (n > 1L) {
    log_transition <- log(transition)
    for (t in 2:n) {
      predicted <- vapply(seq_len(k), function(j) {
        g5_hmm_logsumexp(log_alpha[t - 1L, ] + log_transition[, j])
      }, numeric(1))
      current <- predicted + log_emission[t, ]
      scales[[t]] <- g5_hmm_logsumexp(current)
      log_alpha[t, ] <- current - scales[[t]]
    }
  }
  log_likelihood <- sum(scales)
  if (!is.finite(log_likelihood)) g5_hmm_stop("HMM likelihood is non-finite.")

  log_beta <- matrix(0, nrow = n, ncol = k)
  xi_sum <- matrix(0, nrow = k, ncol = k)
  if (n > 1L) {
    log_transition <- log(transition)
    for (t in (n - 1L):1L) {
      log_beta[t, ] <- vapply(seq_len(k), function(i) {
        g5_hmm_logsumexp(
          log_transition[i, ] + log_emission[t + 1L, ] + log_beta[t + 1L, ]
        ) - scales[[t + 1L]]
      }, numeric(1))
    }
  }
  log_gamma <- log_alpha + log_beta
  gamma <- t(vapply(seq_len(n), function(t) {
    exp(log_gamma[t, ] - g5_hmm_logsumexp(log_gamma[t, ]))
  }, numeric(k)))
  if (n > 1L) {
    log_transition <- log(transition)
    for (i in seq_len(k)) {
      for (j in seq_len(k)) {
        xi_sum[i, j] <- sum(exp(
          log_alpha[seq_len(n - 1L), i] + log_transition[i, j] +
            log_emission[2:n, j] + log_beta[2:n, j] - scales[2:n]
        ))
      }
    }
  }
  filtered <- exp(log_alpha)
  if (any(!is.finite(filtered)) || max(abs(rowSums(filtered) - 1)) > 1e-12 ||
      any(!is.finite(gamma)) || max(abs(rowSums(gamma) - 1)) > 1e-12) {
    g5_hmm_stop("HMM probability invariant failed.")
  }
  list(
    log_likelihood = log_likelihood,
    log_emission = log_emission,
    log_alpha = log_alpha,
    filtered = filtered,
    smoothed = gamma,
    xi_sum = xi_sum,
    scales = scales
  )
}

g5_hmm_filter <- function(x, pi, transition, means, covariances) {
  fit <- g5_hmm_forward_backward(x, pi, transition, means, covariances)
  fit$filtered
}

g5_hmm_viterbi <- function(x, pi, transition, means, covariances) {
  x <- as.matrix(x)
  pi <- g5_hmm_normalize(pi)
  transition <- g5_hmm_normalize_rows(transition)
  log_emission <- g5_hmm_log_emissions(x, means, covariances)
  n <- nrow(x)
  k <- length(pi)
  delta <- matrix(-Inf, nrow = n, ncol = k)
  pointer <- matrix(NA_integer_, nrow = n, ncol = k)
  delta[1L, ] <- log(pi) + log_emission[1L, ]
  if (n > 1L) {
    for (t in 2:n) {
      for (j in seq_len(k)) {
        candidate <- delta[t - 1L, ] + log(transition[, j])
        pointer[t, j] <- which.max(candidate)
        delta[t, j] <- max(candidate) + log_emission[t, j]
      }
    }
  }
  path <- integer(n)
  path[[n]] <- which.max(delta[n, ])
  if (n > 1L) for (t in (n - 1L):1L) path[[t]] <- pointer[t + 1L, path[[t + 1L]]]
  path
}

g5_hmm_weighted_covariance <- function(x, weights, mean, eigen_floor = 1e-4) {
  x <- as.matrix(x)
  weights <- as.numeric(weights)
  total <- sum(weights)
  if (!is.finite(total) || total <= 0) g5_hmm_stop("State has no posterior mass.")
  centered <- sweep(x, 2L, mean, "-")
  sigma <- crossprod(centered * sqrt(weights), centered * sqrt(weights)) / total
  g5_hmm_floor_covariance(sigma, eigen_floor = eigen_floor)
}

g5_hmm_kmeans_initialization <- function(
  x,
  state_count,
  seed,
  self_transition,
  eigen_floor = 1e-4,
  probability_floor = 1e-6
) {
  x <- as.matrix(x)
  set.seed(as.integer(seed))
  clustered <- stats::kmeans(x, centers = state_count, iter.max = 100L, nstart = 1L)
  membership <- clustered$cluster
  means <- t(vapply(seq_len(state_count), function(k) {
    colMeans(x[membership == k, , drop = FALSE])
  }, numeric(ncol(x))))
  covariances <- lapply(seq_len(state_count), function(k) {
    rows <- x[membership == k, , drop = FALSE]
    if (nrow(rows) <= ncol(x)) rows <- x
    g5_hmm_floor_covariance(stats::cov(rows), eigen_floor = eigen_floor)
  })
  weights <- g5_hmm_normalize(tabulate(membership, nbins = state_count) / nrow(x), floor = probability_floor)
  off_diagonal <- (1 - self_transition) / max(1L, state_count - 1L)
  transition <- matrix(off_diagonal, nrow = state_count, ncol = state_count)
  diag(transition) <- self_transition
  transition <- g5_hmm_normalize_rows(transition, floor = probability_floor)
  list(
    means = means,
    covariances = covariances,
    weights = weights,
    transition = transition,
    pi = g5_hmm_stationary(transition, floor = probability_floor)
  )
}

g5_hmm_fit_gmm_once <- function(
  x,
  state_count,
  seed,
  eigen_floor = 1e-4,
  probability_floor = 1e-6,
  max_iterations = 1000L,
  tolerance_per_observation = 1e-8,
  patience = 5L
) {
  x <- as.matrix(x)
  initialized <- g5_hmm_kmeans_initialization(
    x, state_count, seed, self_transition = 0.90,
    eigen_floor = eigen_floor, probability_floor = probability_floor
  )
  means <- initialized$means
  covariances <- initialized$covariances
  weights <- initialized$weights
  previous <- -Inf
  stable <- 0L
  converged <- FALSE
  code <- "MAX_ITERATIONS"
  iteration <- 0L
  responsibilities <- matrix(NA_real_, nrow(x), state_count)
  log_likelihood <- -Inf
  for (iteration in seq_len(max_iterations)) {
    log_emission <- g5_hmm_log_emissions(x, means, covariances)
    log_joint <- sweep(log_emission, 2L, log(weights), "+")
    row_norm <- apply(log_joint, 1L, g5_hmm_logsumexp)
    log_likelihood <- sum(row_norm)
    responsibilities <- exp(log_joint - row_norm)
    if (!is.finite(log_likelihood) || any(!is.finite(responsibilities))) {
      code <- "NONFINITE"
      break
    }
    if (is.finite(previous)) {
      improvement <- (log_likelihood - previous) / nrow(x)
      if (improvement < -tolerance_per_observation) {
        code <- "LIKELIHOOD_DECREASE"
        break
      }
      stable <- if (abs(improvement) < tolerance_per_observation) stable + 1L else 0L
      if (stable >= patience) {
        converged <- TRUE
        code <- "CONVERGED"
        break
      }
    }
    previous <- log_likelihood
    mass <- colSums(responsibilities)
    weights <- g5_hmm_normalize(mass / sum(mass), floor = probability_floor)
    means <- t(vapply(seq_len(state_count), function(k) {
      colSums(x * responsibilities[, k]) / mass[[k]]
    }, numeric(ncol(x))))
    covariances <- lapply(seq_len(state_count), function(k) {
      g5_hmm_weighted_covariance(x, responsibilities[, k], means[k, ], eigen_floor)
    })
  }
  list(
    model_id = paste0("B1_GMM_", state_count),
    seed = as.integer(seed),
    converged = converged,
    convergence_code = code,
    iterations = iteration,
    log_likelihood = log_likelihood,
    weights = weights,
    means = means,
    covariances = covariances,
    responsibilities = responsibilities,
    occupancy = colMeans(responsibilities)
  )
}

g5_hmm_fit_hmm_once <- function(
  x,
  state_count,
  seed,
  self_transition,
  eigen_floor = 1e-4,
  probability_floor = 1e-6,
  max_iterations = 1000L,
  tolerance_per_observation = 1e-8,
  patience = 5L
) {
  x <- as.matrix(x)
  initialized <- g5_hmm_kmeans_initialization(
    x, state_count, seed, self_transition,
    eigen_floor = eigen_floor, probability_floor = probability_floor
  )
  means <- initialized$means
  covariances <- initialized$covariances
  transition <- initialized$transition
  pi <- initialized$pi
  previous <- -Inf
  stable <- 0L
  converged <- FALSE
  code <- "MAX_ITERATIONS"
  iteration <- 0L
  fb <- NULL
  for (iteration in seq_len(max_iterations)) {
    fb <- tryCatch(
      g5_hmm_forward_backward(x, pi, transition, means, covariances),
      error = function(e) NULL
    )
    if (is.null(fb) || !is.finite(fb$log_likelihood)) {
      code <- "NONFINITE"
      break
    }
    if (is.finite(previous)) {
      improvement <- (fb$log_likelihood - previous) / nrow(x)
      if (improvement < -tolerance_per_observation) {
        code <- "LIKELIHOOD_DECREASE"
        break
      }
      stable <- if (abs(improvement) < tolerance_per_observation) stable + 1L else 0L
      if (stable >= patience) {
        converged <- TRUE
        code <- "CONVERGED"
        break
      }
    }
    previous <- fb$log_likelihood
    gamma <- fb$smoothed
    mass <- colSums(gamma)
    means <- t(vapply(seq_len(state_count), function(k) {
      colSums(x * gamma[, k]) / mass[[k]]
    }, numeric(ncol(x))))
    covariances <- lapply(seq_len(state_count), function(k) {
      g5_hmm_weighted_covariance(x, gamma[, k], means[k, ], eigen_floor)
    })
    denominator <- colSums(gamma[-nrow(gamma), , drop = FALSE])
    transition <- fb$xi_sum / denominator
    transition <- g5_hmm_normalize_rows(transition, floor = probability_floor)
    pi <- g5_hmm_stationary(transition, floor = probability_floor)
  }
  if (!is.null(fb) && isTRUE(converged)) {
    fb <- g5_hmm_forward_backward(x, pi, transition, means, covariances)
  }
  list(
    model_id = paste0("H", state_count, "_GAUSSIAN_HMM"),
    seed = as.integer(seed),
    initial_self_transition = self_transition,
    converged = converged,
    convergence_code = code,
    iterations = iteration,
    log_likelihood = if (is.null(fb)) -Inf else fb$log_likelihood,
    pi = pi,
    transition = transition,
    means = means,
    covariances = covariances,
    filtered = if (is.null(fb)) NULL else fb$filtered,
    smoothed = if (is.null(fb)) NULL else fb$smoothed,
    occupancy = if (is.null(fb)) rep(NA_real_, state_count) else colMeans(fb$smoothed)
  )
}

g5_hmm_order_fit <- function(fit, observation_index = 2L) {
  order_index <- order(fit$means[, observation_index], seq_len(nrow(fit$means)))
  fit$means <- fit$means[order_index, , drop = FALSE]
  fit$covariances <- fit$covariances[order_index]
  if (!is.null(fit$weights)) fit$weights <- fit$weights[order_index]
  if (!is.null(fit$pi)) fit$pi <- fit$pi[order_index]
  if (!is.null(fit$transition)) fit$transition <- fit$transition[order_index, order_index, drop = FALSE]
  if (!is.null(fit$filtered)) fit$filtered <- fit$filtered[, order_index, drop = FALSE]
  if (!is.null(fit$smoothed)) fit$smoothed <- fit$smoothed[, order_index, drop = FALSE]
  if (!is.null(fit$responsibilities)) fit$responsibilities <- fit$responsibilities[, order_index, drop = FALSE]
  if (!is.null(fit$occupancy)) fit$occupancy <- fit$occupancy[order_index]
  fit$state_order <- order_index
  fit
}

g5_hmm_fit_multistart <- function(
  x,
  state_count,
  seeds,
  model = c("hmm", "gmm"),
  self_transitions = c(0.80, 0.90, 0.95, 0.98),
  eigen_floor = 1e-4,
  probability_floor = 1e-6,
  max_iterations = 1000L,
  tolerance_per_observation = 1e-8,
  patience = 5L
) {
  model <- match.arg(model)
  x <- as.matrix(x)
  seeds <- as.integer(seeds)
  fits <- lapply(seq_along(seeds), function(i) {
    if (model == "gmm") {
      g5_hmm_fit_gmm_once(
        x, state_count, seeds[[i]], eigen_floor, probability_floor,
        max_iterations, tolerance_per_observation, patience
      )
    } else {
      g5_hmm_fit_hmm_once(
        x, state_count, seeds[[i]],
        self_transitions[[1L + (i - 1L) %% length(self_transitions)]],
        eigen_floor, probability_floor, max_iterations,
        tolerance_per_observation, patience
      )
    }
  })
  valid <- vapply(fits, function(fit) isTRUE(fit$converged) && is.finite(fit$log_likelihood), logical(1))
  diagnostics <- do.call(rbind, lapply(seq_along(fits), function(i) {
    fit <- fits[[i]]
    eigenvalues <- tryCatch(g5_hmm_covariance_eigenvalues(fit$covariances), error = function(e) NA_real_)
    data.frame(
      fit_id = sprintf("%s_K%d_START_%02d", toupper(model), state_count, i),
      model = model,
      state_count = state_count,
      seed = fit$seed,
      initial_self_transition = if (is.null(fit$initial_self_transition)) NA_real_ else fit$initial_self_transition,
      converged = isTRUE(fit$converged),
      convergence_code = fit$convergence_code,
      iterations = fit$iterations,
      log_likelihood = fit$log_likelihood,
      log_likelihood_per_observation = fit$log_likelihood / nrow(x),
      minimum_covariance_eigenvalue = min(eigenvalues),
      maximum_covariance_eigenvalue = max(eigenvalues),
      minimum_posterior_occupancy = min(fit$occupancy),
      stringsAsFactors = FALSE
    )
  }))
  if (!any(valid)) {
    return(list(selected = NULL, fits = fits, diagnostics = diagnostics))
  }
  eligible <- which(valid)
  selected_index <- eligible[[which.max(vapply(fits[eligible], `[[`, numeric(1), "log_likelihood"))]]
  selected <- g5_hmm_order_fit(fits[[selected_index]])
  diagnostics$selected <- seq_len(nrow(diagnostics)) == selected_index
  selected$selected_fit_id <- diagnostics$fit_id[[selected_index]]
  list(selected = selected, fits = fits, diagnostics = diagnostics)
}

g5_hmm_fit_b0 <- function(x, eigen_floor = 1e-4) {
  x <- as.matrix(x)
  mean <- colMeans(x)
  covariance <- g5_hmm_floor_covariance(stats::cov(x), eigen_floor)
  log_scores <- g5_hmm_log_dmvnorm(x, mean, covariance)
  list(
    model_id = "B0_GAUSSIAN_1",
    means = matrix(mean, nrow = 1L),
    covariances = list(covariance),
    log_likelihood = sum(log_scores)
  )
}

g5_hmm_score_static <- function(x, fit) {
  x <- as.matrix(x)
  if (fit$model_id == "B0_GAUSSIAN_1") {
    return(g5_hmm_log_dmvnorm(x, fit$means[1L, ], fit$covariances[[1L]]))
  }
  log_emission <- g5_hmm_log_emissions(x, fit$means, fit$covariances)
  apply(sweep(log_emission, 2L, log(fit$weights), "+"), 1L, g5_hmm_logsumexp)
}

g5_hmm_score_oos <- function(x, fit, initial_filtered) {
  x <- as.matrix(x)
  transition <- fit$transition
  previous <- g5_hmm_normalize(initial_filtered)
  n <- nrow(x)
  k <- length(previous)
  prior <- filtered <- matrix(NA_real_, nrow = n, ncol = k)
  log_score <- rep(NA_real_, n)
  log_emission <- g5_hmm_log_emissions(x, fit$means, fit$covariances)
  for (t in seq_len(n)) {
    prior[t, ] <- as.numeric(previous %*% transition)
    log_joint <- log(prior[t, ]) + log_emission[t, ]
    log_score[[t]] <- g5_hmm_logsumexp(log_joint)
    filtered[t, ] <- exp(log_joint - log_score[[t]])
    previous <- filtered[t, ]
  }
  if (any(!is.finite(log_score)) || max(abs(rowSums(prior) - 1)) > 1e-12 ||
      max(abs(rowSums(filtered) - 1)) > 1e-12) {
    g5_hmm_stop("OOS causal scoring invariant failed.")
  }
  list(log_score = log_score, prior = prior, filtered = filtered)
}

g5_hmm_bruteforce_loglikelihood <- function(x, pi, transition, means, covariances) {
  x <- as.matrix(x)
  n <- nrow(x)
  k <- length(pi)
  if (n > 8L) g5_hmm_stop("Brute-force enumeration is limited to eight observations.")
  grid <- expand.grid(rep(list(seq_len(k)), n))
  log_emission <- g5_hmm_log_emissions(x, means, covariances)
  paths <- apply(grid, 1L, function(states) {
    value <- log(pi[[states[[1L]]]]) + log_emission[1L, states[[1L]]]
    if (n > 1L) for (t in 2:n) {
      value <- value + log(transition[states[[t - 1L]], states[[t]]]) + log_emission[t, states[[t]]]
    }
    value
  })
  g5_hmm_logsumexp(paths)
}

g5_hmm_simulate <- function(n, transition, means, covariances, seed) {
  set.seed(as.integer(seed))
  transition <- g5_hmm_normalize_rows(transition)
  pi <- g5_hmm_stationary(transition)
  k <- length(pi)
  states <- integer(n)
  observations <- matrix(NA_real_, nrow = n, ncol = ncol(means))
  states[[1L]] <- sample.int(k, 1L, prob = pi)
  for (t in seq_len(n)) {
    if (t > 1L) states[[t]] <- sample.int(k, 1L, prob = transition[states[[t - 1L]], ])
    root <- chol(covariances[[states[[t]]]])
    observations[t, ] <- means[states[[t]], ] + as.numeric(stats::rnorm(ncol(means)) %*% root)
  }
  colnames(observations) <- colnames(means)
  list(observations = observations, states = states)
}

g5_hmm_classification_accuracy <- function(filtered, states) {
  mean(max.col(filtered, ties.method = "first") == as.integer(states))
}

g5_hmm_posterior_entropy <- function(probability) {
  probability <- as.matrix(probability)
  mean(-rowSums(probability * log(pmax(probability, 1e-15))))
}

g5_hmm_completed_runs <- function(states) {
  encoded <- rle(as.integer(states))
  data.frame(
    run_id = seq_along(encoded$lengths),
    state = encoded$values,
    duration = encoded$lengths,
    completed = seq_along(encoded$lengths) < length(encoded$lengths),
    stringsAsFactors = FALSE
  )
}
