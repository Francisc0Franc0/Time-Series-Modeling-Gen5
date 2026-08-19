# Package-native directional Markov-switching proof-of-mechanism for LIT-REG-02.1.

g5_reg021_stop <- function(message) stop(message, call. = FALSE)

g5_reg021_schema_version <- function() "gen5_lit_reg_02_1_directional_hmm_v1"

g5_reg021_contract <- function() {
  list(
    literature_id = "LIT-REG-02.1",
    descriptive_name = "Directional Markov-Switching Proof-of-Mechanism",
    reference_package = "hmmTMB",
    reference_version = "1.1.2",
    horizon = 20L,
    forecast_paths = 2000L,
    starts = data.frame(
      start_id = sprintf("START_%02d", 1:6),
      self_transition = c(0.80, 0.90, 0.97, 0.80, 0.90, 0.97),
      phi_start = c(0.00, 0.00, 0.00, 0.20, -0.20, 0.10),
      mean_scale = c(0.50, 0.75, 1.00, 0.50, 0.75, 1.00),
      stringsAsFactors = FALSE
    ),
    positive_seeds = 72001:72010,
    frontier_seed_start = 73001L,
    stress_seeds = 74001:74010,
    maximum_iterations = 2000L,
    maximum_evaluations = 4000L,
    minimum_occupancy = 0.02,
    maximum_abs_phi = 0.995,
    probability_clip = 1e-6,
    monte_carlo_tolerance = 0.01
  )
}

g5_reg021_require_reference <- function(contract = g5_reg021_contract()) {
  if (!requireNamespace(contract$reference_package, quietly = TRUE)) {
    g5_reg021_stop("Approved hmmTMB reference package is unavailable in .libPaths().")
  }
  observed <- as.character(utils::packageVersion(contract$reference_package))
  if (!identical(observed, contract$reference_version)) {
    g5_reg021_stop(paste0(
      "Reference version mismatch: expected ", contract$reference_version,
      ", observed ", observed, "."
    ))
  }
  invisible(observed)
}

g5_reg021_stationary <- function(transition) {
  transition <- as.matrix(transition)
  solution <- tryCatch(
    solve(t(diag(nrow(transition)) - transition + 1), rep(1, nrow(transition))),
    error = function(error) NULL
  )
  if (is.null(solution) || any(!is.finite(solution)) || any(solution <= 0)) {
    eigen_result <- eigen(t(transition))
    index <- which.min(abs(eigen_result$values - 1))
    solution <- Re(eigen_result$vectors[, index])
    solution <- abs(solution)
  }
  solution / sum(solution)
}

g5_reg021_fixed_state_score <- function(alpha, phi, horizon = 20L) {
  vapply(seq_along(alpha), function(k) {
    previous <- 0
    total <- 0
    for (step in seq_len(horizon)) {
      previous <- alpha[[k]] + phi[[k]] * previous
      total <- total + previous
    }
    total
  }, numeric(1))
}

g5_reg021_order_fit <- function(fit, horizon = 20L) {
  scores <- g5_reg021_fixed_state_score(fit$alpha, fit$phi, horizon)
  order_index <- order(scores, seq_along(scores))
  fit$alpha <- fit$alpha[order_index]
  fit$phi <- fit$phi[order_index]
  fit$sigma <- fit$sigma[order_index]
  fit$transition <- fit$transition[order_index, order_index, drop = FALSE]
  fit$delta <- fit$delta[order_index]
  fit$directional_score <- scores[order_index]
  fit$state_order <- order_index
  fit
}

g5_reg021_forward <- function(
  returns,
  lags,
  transition,
  alpha,
  phi,
  sigma,
  initial_probability,
  initial_is_previous_filter = FALSE
) {
  returns <- as.numeric(returns)
  lags <- as.numeric(lags)
  transition <- as.matrix(transition)
  alpha <- as.numeric(alpha)
  phi <- as.numeric(phi)
  sigma <- as.numeric(sigma)
  initial_probability <- as.numeric(initial_probability)
  if (!length(returns) || length(returns) != length(lags) ||
      any(!is.finite(c(returns, lags, transition, alpha, phi, sigma, initial_probability))) ||
      any(sigma <= 0) || any(transition <= 0) ||
      max(abs(rowSums(transition) - 1)) > 1e-10) {
    g5_reg021_stop("Invalid arguments to directional causal filter.")
  }
  initial_probability <- initial_probability / sum(initial_probability)
  filtered <- matrix(NA_real_, nrow = length(returns), ncol = 2L)
  log_score <- numeric(length(returns))
  previous <- initial_probability
  for (index in seq_along(returns)) {
    prior <- if (index == 1L && !initial_is_previous_filter) {
      previous
    } else {
      as.numeric(previous %*% transition)
    }
    emission <- stats::dnorm(
      returns[[index]],
      mean = alpha + phi * lags[[index]],
      sd = sigma
    )
    joint <- prior * emission
    scale <- sum(joint)
    if (!is.finite(scale) || scale <= 0) g5_reg021_stop("Directional filter underflowed.")
    previous <- joint / scale
    filtered[index, ] <- previous
    log_score[[index]] <- log(scale)
  }
  if (max(abs(rowSums(filtered) - 1)) > 1e-12) {
    g5_reg021_stop("Directional filter probability invariant failed.")
  }
  list(filtered = filtered, log_score = log_score, log_likelihood = sum(log_score))
}

g5_reg021_simulate_msar <- function(
  n,
  alpha,
  phi,
  sigma,
  transition,
  seed,
  financial_noise = FALSE,
  t_df = 6,
  garch_alpha = 0.07,
  garch_beta = 0.91
) {
  set.seed(as.integer(seed))
  transition <- as.matrix(transition)
  delta <- g5_reg021_stationary(transition)
  states <- integer(n)
  returns <- numeric(n)
  innovations <- numeric(n)
  variance <- rep(mean(sigma^2), n)
  states[[1L]] <- sample.int(2L, 1L, prob = delta)
  if (financial_noise) {
    target_variance <- mean(sigma^2)
    omega <- (1 - garch_alpha - garch_beta) * target_variance
    standardized_t <- function() stats::rt(1L, df = t_df) / sqrt(t_df / (t_df - 2))
    innovations[[1L]] <- sqrt(variance[[1L]]) * standardized_t()
    returns[[1L]] <- alpha[states[[1L]]] + innovations[[1L]]
    for (index in 2:n) {
      states[[index]] <- sample.int(2L, 1L, prob = transition[states[[index - 1L]], ])
      variance[[index]] <- omega + garch_alpha * innovations[[index - 1L]]^2 +
        garch_beta * variance[[index - 1L]]
      innovations[[index]] <- sqrt(variance[[index]]) * standardized_t()
      returns[[index]] <- alpha[states[[index]]] +
        phi[states[[index]]] * returns[[index - 1L]] + innovations[[index]]
    }
  } else {
    innovations[[1L]] <- stats::rnorm(1L, sd = sigma[states[[1L]]])
    returns[[1L]] <- alpha[states[[1L]]] + innovations[[1L]]
    for (index in 2:n) {
      states[[index]] <- sample.int(2L, 1L, prob = transition[states[[index - 1L]], ])
      innovations[[index]] <- stats::rnorm(1L, sd = sigma[states[[index]]])
      returns[[index]] <- alpha[states[[index]]] +
        phi[states[[index]]] * returns[[index - 1L]] + innovations[[index]]
    }
  }
  data.frame(
    time = seq_len(n),
    state = states,
    ret = returns,
    innovation = innovations,
    conditional_variance = variance,
    stringsAsFactors = FALSE
  )
}

g5_reg021_fit_once <- function(train_returns, start_row, contract = g5_reg021_contract()) {
  data <- data.frame(
    ret = train_returns[-1L],
    ret_lag = train_returns[-length(train_returns)]
  )
  overall_sd <- stats::sd(data$ret)
  center <- mean(data$ret)
  scale <- start_row$mean_scale[[1L]] * overall_sd
  initial_alpha <- center + c(-scale, scale)
  initial_sigma <- rep(max(overall_sd, 1e-5), 2L)
  p <- start_row$self_transition[[1L]]
  transition <- matrix(c(p, 1 - p, 1 - p, p), nrow = 2L, byrow = TRUE)
  result <- list(
    start_id = start_row$start_id[[1L]],
    valid = FALSE,
    convergence = NA_integer_,
    message = "UNINITIALIZED",
    log_likelihood = -Inf
  )
  model <- tryCatch({
    hid <- hmmTMB::MarkovChain$new(
      data = data, n_states = 2L, tpm = transition, initial_state = "stationary"
    )
    obs <- hmmTMB::Observation$new(
      data = data,
      dists = list(ret = "norm"),
      formulas = list(ret = list(mean = ~ ret_lag)),
      par = list(ret = list(mean = initial_alpha, sd = initial_sigma))
    )
    initial_coefficients <- c(
      initial_alpha[[1L]], start_row$phi_start[[1L]],
      initial_alpha[[2L]], start_row$phi_start[[1L]],
      log(initial_sigma[[1L]]), log(initial_sigma[[2L]])
    )
    obs$update_coeff_fe(initial_coefficients)
    hmm <- hmmTMB::HMM$new(obs = obs, hid = hid)
    suppressWarnings(hmm$fit(
      silent = TRUE,
      control = list(
        iter.max = contract$maximum_iterations,
        eval.max = contract$maximum_evaluations
      )
    ))
    hmm
  }, error = function(error) structure(list(error = conditionMessage(error)), class = "g5_reg021_error"))
  if (inherits(model, "g5_reg021_error")) {
    result$message <- paste0("PACKAGE_ERROR: ", model$error)
    return(result)
  }
  output <- model$out()
  coefficients <- as.numeric(model$obs()$coeff_fe())
  names(coefficients) <- rownames(model$obs()$coeff_fe())
  result$convergence <- as.integer(output$convergence)
  result$message <- as.character(output$message)
  result$log_likelihood <- -as.numeric(output$objective)
  result$alpha <- coefficients[c(
    "ret.mean.state1.(Intercept)", "ret.mean.state2.(Intercept)"
  )]
  result$phi <- coefficients[c("ret.mean.state1.ret_lag", "ret.mean.state2.ret_lag")]
  result$sigma <- exp(coefficients[c(
    "ret.sd.state1.(Intercept)", "ret.sd.state2.(Intercept)"
  )])
  result$transition <- model$par()$tpm[, , 1L]
  result$delta <- g5_reg021_stationary(result$transition)
  finite <- all(is.finite(c(
    result$log_likelihood, result$alpha, result$phi, result$sigma,
    result$transition, result$delta
  )))
  structural <- finite && result$convergence == 0L && all(result$sigma > 0) &&
    all(abs(result$phi) < contract$maximum_abs_phi) &&
    all(result$transition > 0) && all(result$transition < 1) &&
    max(abs(rowSums(result$transition) - 1)) <= 1e-10
  if (!structural) return(result)
  result <- g5_reg021_order_fit(result, contract$horizon)
  filtered <- tryCatch(
    g5_reg021_forward(
      data$ret, data$ret_lag, result$transition, result$alpha,
      result$phi, result$sigma, result$delta
    ),
    error = function(error) NULL
  )
  if (is.null(filtered)) return(result)
  result$train_filtered <- filtered$filtered
  result$train_log_likelihood_crosscheck <- filtered$log_likelihood
  result$crosscheck_difference_per_observation <- abs(
    result$log_likelihood - filtered$log_likelihood
  ) / nrow(data)
  result$occupancy <- colMeans(filtered$filtered)
  result$valid <- min(result$occupancy) >= contract$minimum_occupancy &&
    result$crosscheck_difference_per_observation <= 1e-8
  result
}

g5_reg021_fit_multistart <- function(train_returns, contract = g5_reg021_contract()) {
  g5_reg021_require_reference(contract)
  fits <- lapply(seq_len(nrow(contract$starts)), function(index) {
    g5_reg021_fit_once(train_returns, contract$starts[index, , drop = FALSE], contract)
  })
  diagnostics <- do.call(rbind, lapply(fits, function(fit) {
    data.frame(
      start_id = fit$start_id,
      valid = isTRUE(fit$valid),
      convergence = fit$convergence,
      message = fit$message,
      log_likelihood = fit$log_likelihood,
      minimum_occupancy = if (is.null(fit$occupancy)) NA_real_ else min(fit$occupancy),
      maximum_abs_phi = if (is.null(fit$phi)) NA_real_ else max(abs(fit$phi)),
      crosscheck_difference_per_observation = if (is.null(fit$crosscheck_difference_per_observation)) NA_real_ else fit$crosscheck_difference_per_observation,
      selected = FALSE,
      stringsAsFactors = FALSE
    )
  }))
  valid <- which(vapply(fits, function(fit) isTRUE(fit$valid), logical(1)))
  if (!length(valid)) return(list(selected = NULL, diagnostics = diagnostics, fits = fits))
  selected_index <- valid[[which.max(vapply(fits[valid], `[[`, numeric(1), "log_likelihood"))]]
  diagnostics$selected[[selected_index]] <- TRUE
  fits[[selected_index]]$selected_start_id <- diagnostics$start_id[[selected_index]]
  list(selected = fits[[selected_index]], diagnostics = diagnostics, fits = fits)
}

g5_reg021_fit_ar1 <- function(returns, contract = g5_reg021_contract()) {
  current <- returns[-1L]
  lagged <- returns[-length(returns)]
  fit <- stats::lm(current ~ lagged)
  coefficients <- stats::coef(fit)
  phi <- max(-contract$maximum_abs_phi, min(contract$maximum_abs_phi, coefficients[[2L]]))
  alpha <- mean(current - phi * lagged)
  residual <- current - alpha - phi * lagged
  sigma <- sqrt(mean(residual^2))
  list(alpha = alpha, phi = phi, sigma = sigma)
}

g5_reg021_ar1_horizon_probability <- function(last_return, model, horizon = 20L) {
  expected <- numeric(horizon)
  previous <- last_return
  for (step in seq_len(horizon)) {
    previous <- model$alpha + model$phi * previous
    expected[[step]] <- previous
  }
  coefficients <- vapply(seq_len(horizon), function(j) {
    remaining <- horizon - j
    if (abs(1 - model$phi) < 1e-10) remaining + 1 else
      (1 - model$phi^(remaining + 1)) / (1 - model$phi)
  }, numeric(1))
  mean_sum <- sum(expected)
  sd_sum <- model$sigma * sqrt(sum(coefficients^2))
  stats::pnorm(mean_sum / sd_sum)
}

g5_reg021_horizon_probability <- function(
  last_return,
  filtered_probability,
  transition,
  alpha,
  phi,
  sigma,
  horizon,
  paths,
  seed
) {
  set.seed(as.integer(seed))
  states <- sample.int(2L, paths, replace = TRUE, prob = filtered_probability)
  previous <- rep(last_return, paths)
  total <- numeric(paths)
  for (step in seq_len(horizon)) {
    probability_state1 <- transition[states, 1L]
    states <- ifelse(stats::runif(paths) <= probability_state1, 1L, 2L)
    next_return <- alpha[states] + phi[states] * previous +
      stats::rnorm(paths, sd = sigma[states])
    total <- total + next_return
    previous <- next_return
  }
  mean(total > 0)
}

g5_reg021_nonoverlap_up_probability <- function(returns, horizon) {
  origins <- seq.int(1L, length(returns) - horizon, by = horizon)
  events <- vapply(origins, function(origin) {
    sum(returns[(origin + 1L):(origin + horizon)]) > 0
  }, logical(1))
  mean(events)
}

g5_reg021_score_probability <- function(probability, outcome, clip = 1e-6) {
  probability <- pmax(clip, pmin(1 - clip, probability))
  data.frame(
    brier = mean((probability - outcome)^2),
    log_loss = -mean(outcome * log(probability) + (1 - outcome) * log(1 - probability)),
    accuracy = mean((probability >= 0.5) == outcome),
    sharpness = stats::sd(probability),
    mean_probability = mean(probability),
    observed_rate = mean(outcome),
    stringsAsFactors = FALSE
  )
}

g5_reg021_evaluate_case <- function(
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
  contract = g5_reg021_contract(),
  save_tape = FALSE
) {
  total_length <- train_length + oos_length
  simulated <- g5_reg021_simulate_msar(
    total_length, alpha, phi, sigma, transition, seed,
    financial_noise = financial_noise
  )
  train <- simulated$ret[seq_len(train_length)]
  oos_index <- (train_length + 1L):total_length
  oos <- simulated$ret[oos_index]
  fitted <- g5_reg021_fit_multistart(train, contract)
  diagnostics <- fitted$diagnostics
  diagnostics$case_id <- case_id
  diagnostics$fixture_class <- fixture_class
  if (is.null(fitted$selected)) {
    return(list(
      summary = data.frame(
        case_id = case_id, fixture_class = fixture_class, seed = seed,
        train_length = train_length, oos_length = oos_length,
        valid_fit = FALSE, filtered_accuracy = NA_real_,
        maximum_transition_error = NA_real_, minimum_occupancy = NA_real_,
        brier_h2 = NA_real_, brier_b0 = NA_real_, brier_b1 = NA_real_, brier_oracle = NA_real_,
        logloss_h2 = NA_real_, logloss_b0 = NA_real_, logloss_b1 = NA_real_, logloss_oracle = NA_real_,
        stringsAsFactors = FALSE
      ),
      forecasts = NULL, diagnostics = diagnostics, tape = NULL, fit = NULL,
      simulated = simulated
    ))
  }
  model <- fitted$selected
  train_data_ret <- train[-1L]
  train_data_lag <- train[-length(train)]
  train_filter <- g5_reg021_forward(
    train_data_ret, train_data_lag, model$transition, model$alpha,
    model$phi, model$sigma, model$delta
  )
  oos_lags <- c(tail(train, 1L), head(oos, -1L))
  oos_filter <- g5_reg021_forward(
    oos, oos_lags, model$transition, model$alpha, model$phi, model$sigma,
    tail(train_filter$filtered, 1L), initial_is_previous_filter = TRUE
  )
  true_states <- simulated$state[oos_index]
  accuracy <- if (all(alpha == alpha[[1L]])) NA_real_ else
    mean(max.col(oos_filter$filtered, ties.method = "first") == true_states)
  transition_error <- if (all(alpha == alpha[[1L]])) NA_real_ else
    max(abs(model$transition - transition))
  baseline_ar <- g5_reg021_fit_ar1(train, contract)
  base_probability <- g5_reg021_nonoverlap_up_probability(train, contract$horizon)
  origins <- seq.int(1L, oos_length - contract$horizon, by = contract$horizon)
  forecasts <- do.call(rbind, lapply(seq_along(origins), function(origin_index) {
    origin <- origins[[origin_index]]
    realized <- sum(oos[(origin + 1L):(origin + contract$horizon)])
    p_h2 <- g5_reg021_horizon_probability(
      oos[[origin]], oos_filter$filtered[origin, ], model$transition,
      model$alpha, model$phi, model$sigma, contract$horizon,
      contract$forecast_paths, seed + 100000L + origin
    )
    p_oracle <- if (financial_noise) NA_real_ else g5_reg021_horizon_probability(
      oos[[origin]], as.numeric(seq_len(2L) == true_states[[origin]]), transition,
      alpha, phi, sigma, contract$horizon, contract$forecast_paths,
      seed + 200000L + origin
    )
    data.frame(
      case_id = case_id,
      fixture_class = fixture_class,
      origin = origin,
      outcome = as.integer(realized > 0),
      realized_horizon_return = realized,
      p_h2 = p_h2,
      p_b0 = base_probability,
      p_b1 = g5_reg021_ar1_horizon_probability(oos[[origin]], baseline_ar, contract$horizon),
      p_oracle = p_oracle,
      stringsAsFactors = FALSE
    )
  }))
  score <- function(column) g5_reg021_score_probability(
    forecasts[[column]], forecasts$outcome, contract$probability_clip
  )
  h2 <- score("p_h2")
  b0 <- score("p_b0")
  b1 <- score("p_b1")
  oracle <- if (financial_noise) {
    data.frame(brier = NA_real_, log_loss = NA_real_, accuracy = NA_real_, sharpness = NA_real_)
  } else score("p_oracle")
  summary <- data.frame(
    case_id = case_id,
    fixture_class = fixture_class,
    seed = seed,
    train_length = train_length,
    oos_length = oos_length,
    valid_fit = TRUE,
    filtered_accuracy = accuracy,
    maximum_transition_error = transition_error,
    minimum_occupancy = min(model$occupancy),
    alpha_less = model$alpha[[1L]],
    alpha_more = model$alpha[[2L]],
    phi_less = model$phi[[1L]],
    phi_more = model$phi[[2L]],
    sigma_less = model$sigma[[1L]],
    sigma_more = model$sigma[[2L]],
    brier_h2 = h2$brier,
    brier_b0 = b0$brier,
    brier_b1 = b1$brier,
    brier_oracle = oracle$brier,
    logloss_h2 = h2$log_loss,
    logloss_b0 = b0$log_loss,
    logloss_b1 = b1$log_loss,
    logloss_oracle = oracle$log_loss,
    accuracy_h2 = h2$accuracy,
    sharpness_h2 = h2$sharpness,
    stringsAsFactors = FALSE
  )
  tape <- if (save_tape) data.frame(
    case_id = case_id,
    oos_time = seq_len(oos_length),
    ret = oos,
    true_state = true_states,
    p_more_favorable = oos_filter$filtered[, 2L],
    filtered_state = max.col(oos_filter$filtered, ties.method = "first"),
    stringsAsFactors = FALSE
  ) else NULL
  list(
    summary = summary, forecasts = forecasts, diagnostics = diagnostics,
    tape = tape, fit = model, simulated = simulated
  )
}

g5_reg021_positive_registry <- function() {
  data.frame(
    case_id = sprintf("TEACHING_%02d", 1:10),
    fixture_class = "teaching_positive",
    seed = 72001:72010,
    train_length = 1800L,
    oos_length = 600L,
    drift = 0.003,
    self_transition = 0.97,
    financial_noise = FALSE,
    stringsAsFactors = FALSE
  )
}

g5_reg021_frontier_registry <- function() {
  grid <- expand.grid(
    drift = c(0, 0.0005, 0.0015, 0.0030),
    self_transition = c(0.90, 0.97),
    train_length = c(1000L, 2000L),
    replicate = 1:4,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid <- grid[order(grid$train_length, grid$self_transition, grid$drift, grid$replicate), ]
  rownames(grid) <- NULL
  grid$case_id <- sprintf("FRONTIER_%03d", seq_len(nrow(grid)))
  grid$fixture_class <- ifelse(grid$drift == 0, "frontier_null", "frontier_directional")
  grid$seed <- 73000L + seq_len(nrow(grid))
  grid$oos_length <- 400L
  grid$financial_noise <- FALSE
  grid[, c(
    "case_id", "fixture_class", "seed", "train_length", "oos_length",
    "drift", "self_transition", "replicate", "financial_noise"
  )]
}

g5_reg021_stress_registry <- function() {
  data.frame(
    case_id = sprintf("FINANCIAL_STRESS_%02d", 1:10),
    fixture_class = "financial_shaped_synthetic",
    seed = 74001:74010,
    train_length = 2000L,
    oos_length = 600L,
    drift = 0.0015,
    self_transition = 0.97,
    financial_noise = TRUE,
    stringsAsFactors = FALSE
  )
}

g5_reg021_evaluate_registry_row <- function(row, contract = g5_reg021_contract(), save_tape = FALSE) {
  drift <- row$drift[[1L]]
  p <- row$self_transition[[1L]]
  evaluated <- g5_reg021_evaluate_case(
    case_id = row$case_id[[1L]],
    seed = row$seed[[1L]],
    train_length = row$train_length[[1L]],
    oos_length = row$oos_length[[1L]],
    alpha = if (drift == 0) c(0, 0) else c(-drift, drift),
    phi = c(0.10, 0.10),
    sigma = c(0.012, 0.012),
    transition = matrix(c(p, 1 - p, 1 - p, p), nrow = 2L, byrow = TRUE),
    fixture_class = row$fixture_class[[1L]],
    financial_noise = isTRUE(row$financial_noise[[1L]]),
    contract = contract,
    save_tape = save_tape
  )
  evaluated$summary$drift <- drift
  evaluated$summary$self_transition <- p
  if ("replicate" %in% names(row)) evaluated$summary$replicate <- row$replicate[[1L]]
  evaluated
}

g5_reg021_stage_a_checks <- function(first_result, contract = g5_reg021_contract()) {
  model <- first_result$fit
  oos <- first_result$simulated$ret[1801:2400]
  lags <- c(first_result$simulated$ret[[1800]], head(oos, -1L))
  train_last <- tail(model$train_filtered, 1L)
  prefix <- g5_reg021_forward(
    oos[1:500], lags[1:500], model$transition, model$alpha, model$phi,
    model$sigma, train_last, initial_is_previous_filter = TRUE
  )$filtered
  full <- g5_reg021_forward(
    oos, lags, model$transition, model$alpha, model$phi,
    model$sigma, train_last, initial_is_previous_filter = TRUE
  )$filtered
  append_difference <- max(abs(prefix - full[1:500, , drop = FALSE]))
  replay <- g5_reg021_evaluate_registry_row(
    g5_reg021_positive_registry()[1L, , drop = FALSE], contract, save_tape = TRUE
  )
  parameter_difference <- max(abs(c(
    model$alpha - replay$fit$alpha,
    model$phi - replay$fit$phi,
    model$sigma - replay$fit$sigma,
    model$transition - replay$fit$transition
  )))
  filter_difference <- max(abs(first_result$tape$p_more_favorable - replay$tape$p_more_favorable))
  score_difference <- max(abs(unlist(
    first_result$summary[c("brier_h2", "logloss_h2")] -
      replay$summary[c("brier_h2", "logloss_h2")]
  )))
  list(
    append_difference = append_difference,
    parameter_difference = parameter_difference,
    filter_difference = filter_difference,
    score_difference = score_difference
  )
}

g5_reg021_stage_a_gates <- function(summary, checks, contract = g5_reg021_contract()) {
  valid <- summary[summary$valid_fit, , drop = FALSE]
  gate <- c(
    A1 = identical(as.character(utils::packageVersion("hmmTMB")), contract$reference_version) &&
      nrow(valid) == 10L,
    A2 = checks$append_difference <= 1e-12,
    A3 = stats::median(valid$filtered_accuracy) >= 0.85 &&
      as.numeric(stats::quantile(valid$filtered_accuracy, 0.10)) >= 0.75,
    A4 = stats::median(valid$maximum_transition_error) <= 0.05 &&
      as.numeric(stats::quantile(valid$maximum_transition_error, 0.90)) <= 0.10,
    A5 = mean(valid$brier_h2) < mean(valid$brier_b0) &&
      mean(valid$brier_h2) < mean(valid$brier_b1) &&
      sum(valid$brier_h2 < valid$brier_b0) >= 8L &&
      sum(valid$brier_h2 < valid$brier_b1) >= 8L,
    A6 = mean(valid$logloss_h2) < mean(valid$logloss_b0) &&
      mean(valid$logloss_h2) < mean(valid$logloss_b1) &&
      sum(valid$logloss_h2 < valid$logloss_b0) >= 8L &&
      sum(valid$logloss_h2 < valid$logloss_b1) >= 8L,
    A7 = mean(valid$brier_oracle) <= mean(valid$brier_h2) + contract$monte_carlo_tolerance &&
      all(is.finite(unlist(valid[c(
        "brier_h2", "brier_b0", "brier_b1", "brier_oracle",
        "logloss_h2", "logloss_b0", "logloss_b1", "logloss_oracle"
      )]))),
    A8 = max(unlist(checks[c(
      "parameter_difference", "filter_difference", "score_difference"
    )])) <= 1e-10
  )
  observed <- c(
    paste0("version=", as.character(utils::packageVersion("hmmTMB")), "; valid=", nrow(valid), "/10"),
    paste0("append_difference=", format(checks$append_difference, scientific = TRUE)),
    sprintf("median_accuracy=%.3f; p10=%.3f", stats::median(valid$filtered_accuracy), as.numeric(stats::quantile(valid$filtered_accuracy, 0.10))),
    sprintf("median_transition_error=%.4f; p90=%.4f", stats::median(valid$maximum_transition_error), as.numeric(stats::quantile(valid$maximum_transition_error, 0.90))),
    sprintf("mean_brier H2=%.4f B0=%.4f B1=%.4f; wins=%d/%d", mean(valid$brier_h2), mean(valid$brier_b0), mean(valid$brier_b1), sum(valid$brier_h2 < valid$brier_b0), sum(valid$brier_h2 < valid$brier_b1)),
    sprintf("mean_logloss H2=%.4f B0=%.4f B1=%.4f; wins=%d/%d", mean(valid$logloss_h2), mean(valid$logloss_b0), mean(valid$logloss_b1), sum(valid$logloss_h2 < valid$logloss_b0), sum(valid$logloss_h2 < valid$logloss_b1)),
    sprintf("oracle_brier=%.4f; H2_brier=%.4f", mean(valid$brier_oracle), mean(valid$brier_h2)),
    paste0("maximum_replay_difference=", format(max(unlist(checks[c("parameter_difference", "filter_difference", "score_difference")])), scientific = TRUE))
  )
  data.frame(
    gate_id = names(gate),
    passed = unname(gate),
    status = ifelse(unname(gate), "PASS", "FAIL"),
    observed = observed,
    stringsAsFactors = FALSE
  )
}

g5_reg021_frontier_summary <- function(summary) {
  aggregate_rows <- split(summary, list(
    summary$train_length, summary$self_transition, summary$drift
  ), drop = TRUE)
  do.call(rbind, lapply(aggregate_rows, function(part) {
    valid <- part[part$valid_fit, , drop = FALSE]
    data.frame(
      train_length = part$train_length[[1L]],
      self_transition = part$self_transition[[1L]],
      drift = part$drift[[1L]],
      drift_bp = 10000 * part$drift[[1L]],
      valid_fits = nrow(valid),
      replicates = nrow(part),
      median_state_accuracy = if (!nrow(valid) || part$drift[[1L]] == 0) NA_real_ else stats::median(valid$filtered_accuracy, na.rm = TRUE),
      mean_brier_gain_vs_b0 = if (!nrow(valid)) NA_real_ else mean(valid$brier_b0 - valid$brier_h2),
      mean_brier_gain_vs_b1 = if (!nrow(valid)) NA_real_ else mean(valid$brier_b1 - valid$brier_h2),
      mean_logloss_gain_vs_b0 = if (!nrow(valid)) NA_real_ else mean(valid$logloss_b0 - valid$logloss_h2),
      mean_logloss_gain_vs_b1 = if (!nrow(valid)) NA_real_ else mean(valid$logloss_b1 - valid$logloss_h2),
      joint_score_wins = if (!nrow(valid)) 0L else sum(
        valid$brier_h2 < valid$brier_b0 & valid$brier_h2 < valid$brier_b1 &
          valid$logloss_h2 < valid$logloss_b0 & valid$logloss_h2 < valid$logloss_b1
      ),
      detection_boundary_cell = nrow(valid) >= 3L && sum(
        valid$brier_h2 < valid$brier_b0 & valid$brier_h2 < valid$brier_b1 &
          valid$logloss_h2 < valid$logloss_b0 & valid$logloss_h2 < valid$logloss_b1
      ) >= 3L,
      stringsAsFactors = FALSE
    )
  }))
}
