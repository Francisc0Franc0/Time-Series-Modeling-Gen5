# Frozen LIT-MOM-01.5 path-quality forecast-comparison helpers.
# Source gen5_lit_mom_01_4_multi_market_predictor_atlas.R first.

g5_mom015_stop <- function(message) stop(message, call. = FALSE)

g5_mom015_schema_version <- function() "gen5_lit_mom_01_5_v1"

g5_mom015_contract <- function() {
  list(
    literature_id = "LIT-MOM-01.5",
    descriptive_name = "Path-Quality Incremental Forecast Comparison",
    as_of_timestamp = "2026-08-21 17:30:00 America/New_York",
    registry_relative_path = file.path(
      "literature_studies", "registries",
      "gen5_lit_mom_02_1_opening_gap_atlas_registry.csv"
    ),
    registry_sha256 = "69C481DCB8443AADC30D8BF10FC7FFB7EC23D193CE88A992E42F8529225E4737",
    registry_count = 92L,
    query_start = as.Date("2016-01-04"),
    query_end = as.Date("2023-12-29"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    confirmation_end = as.Date("2025-12-31"),
    lookback_grid = c(5L, 10L, 25L, 60L, 120L, 250L),
    target_grid = c(5L, 10L, 25L, 60L),
    common_lookback_sessions = 250L,
    common_target_sessions = 60L,
    minimum_period_anchors = 600L,
    model_ids = c("B0_DRIFT", "B1_RAW", "Q2_PATH"),
    contrast_ids = c("D10", "D21", "D20"),
    fdr_q = 0.10,
    bootstrap_count = 10000L,
    bootstrap_expected_block = 60,
    bootstrap_seed_base = 2026082150L,
    bootstrap_quantile_type = 7L,
    spy_reference_symbol = "SPY"
  )
}

g5_mom015_validate_contract <- function(contract = g5_mom015_contract()) {
  frozen <- g5_mom015_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom015_stop("Frozen LIT-MOM-01.5 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom015_stop(paste(
      "Frozen LIT-MOM-01.5 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  if (length(contract$lookback_grid) * length(contract$target_grid) != 24L) {
    g5_mom015_stop("Frozen LIT-MOM-01.5 surface must contain 24 cells.")
  }
  contract
}

g5_mom015_validate_registry <- function(registry, contract = g5_mom015_contract()) {
  contract <- g5_mom015_validate_contract(contract)
  required <- c(
    "order", "instance_id", "symbol", "category", "instrument_type",
    "analysis_id", "analysis_stratum", "is_spy_reference"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mom015_stop(paste("Registry columns missing:", paste(missing, collapse = ", ")))
  }
  x <- registry[order(as.integer(registry$order)), , drop = FALSE]
  checks <- c(
    nrow(x) == contract$registry_count,
    identical(as.integer(x$order), seq_len(contract$registry_count)),
    !anyDuplicated(x$instance_id),
    !anyDuplicated(x$symbol),
    sum(x$analysis_stratum == "PLAIN_ETF") == 68L,
    sum(x$analysis_stratum == "ENGINEERED_ETF") == 6L,
    sum(x$analysis_stratum == "STOCK_CHALLENGER") == 18L,
    sum(x$symbol == contract$spy_reference_symbol) == 1L
  )
  if (!all(checks)) g5_mom015_stop("Frozen 92-row registry structure changed.")
  x$is_spy_reference <- x$symbol == contract$spy_reference_symbol
  x
}

g5_mom015_validate_bars <- function(bars, registry, contract = g5_mom015_contract()) {
  contract <- g5_mom015_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_mom015_stop(paste("Bar columns missing:", paste(missing, collapse = ", ")))
  }
  x <- bars[bars$symbol %in% registry$symbol, , drop = FALSE]
  x$symbol <- toupper(as.character(x$symbol))
  x$session_date <- as.Date(x$session_date)
  x <- x[order(match(x$symbol, registry$symbol), x$session_date), , drop = FALSE]
  if (any(x$session_date >= contract$confirmation_start)) {
    g5_mom015_stop("Confirmation bars entered the LIT-MOM-01.5 execution input.")
  }
  x
}

g5_mom015_path_features <- function(close, anchor_index, lookback) {
  lookback <- as.integer(lookback)
  log_close <- log(as.numeric(close))
  if (any(!is.finite(log_close)) || any(anchor_index <= lookback)) {
    g5_mom015_stop("Invalid close path or insufficient feature history.")
  }
  raw <- log_close[anchor_index] - log_close[anchor_index - lookback]
  denominator <- vapply(anchor_index, function(i) {
    sum(abs(diff(log_close[seq.int(i - lookback, i)])))
  }, numeric(1))
  maximum_step <- vapply(anchor_index, function(i) {
    max(abs(diff(log_close[seq.int(i - lookback, i)])))
  }, numeric(1))
  efficiency <- ifelse(denominator > 0, abs(raw) / denominator, 0)
  shock <- ifelse(denominator > 0, maximum_step / denominator, 0)
  positive <- pmax(raw, 0)
  out <- data.frame(
    raw_return = raw,
    path_efficiency = pmin(1, pmax(0, efficiency)),
    shock_concentration = pmin(1, pmax(0, shock)),
    coherent_positive = positive * efficiency,
    shock_positive = positive * shock,
    stringsAsFactors = FALSE
  )
  if (any(!is.finite(as.matrix(out)))) {
    g5_mom015_stop("Nonfinite LIT-MOM-01.5 feature was constructed.")
  }
  out
}

g5_mom015_period_panel <- function(
  symbol_bars, period_start, period_end,
  contract = g5_mom015_contract()
) {
  contract <- g5_mom015_validate_contract(contract)
  x <- symbol_bars[order(as.Date(symbol_bars$session_date)), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  indices <- seq_len(nrow(x))
  anchor_i <- indices[
    indices > contract$common_lookback_sessions &
      indices + 1L + contract$common_target_sessions <= nrow(x) &
      x$session_date >= as.Date(period_start)
  ]
  anchor_i <- anchor_i[
    x$session_date[anchor_i + 1L + contract$common_target_sessions] <= as.Date(period_end)
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
  colnames(y) <- paste0("H", contract$target_grid)
  if (any(!is.finite(y))) g5_mom015_stop("Nonfinite LIT-MOM-01.5 target was constructed.")
  list(
    bars = x,
    anchor_index = anchor_i,
    anchor_date = x$session_date[anchor_i],
    entry_date = x$session_date[anchor_i + 1L],
    features = feature_matrices,
    y = y
  )
}

g5_mom015_standardize <- function(train, development) {
  train <- as.matrix(train)
  development <- as.matrix(development)
  center <- colMeans(train)
  scale <- apply(train, 2L, stats::sd)
  if (any(!is.finite(center)) || any(!is.finite(scale)) || any(scale <= .Machine$double.eps)) {
    g5_mom015_stop("TRAIN feature standardization is degenerate.")
  }
  list(
    train = sweep(sweep(train, 2L, center, "-"), 2L, scale, "/"),
    development = sweep(sweep(development, 2L, center, "-"), 2L, scale, "/"),
    center = center,
    scale = scale
  )
}

g5_mom015_fit_design <- function(train_design, train_y, development_design) {
  fit <- stats::lm.fit(cbind(1, train_design), train_y)
  required_rank <- ncol(train_design) + 1L
  if (fit$rank != required_rank || any(!is.finite(fit$coefficients))) {
    g5_mom015_stop("TRAIN forecast fit is rank-deficient or nonfinite.")
  }
  list(
    coefficients = unname(fit$coefficients),
    rank = fit$rank,
    prediction = as.numeric(cbind(1, development_design) %*% fit$coefficients)
  )
}

g5_mom015_fit_cell <- function(
  train_panel, development_panel, lookback_index, target_index,
  contract = g5_mom015_contract()
) {
  contract <- g5_mom015_validate_contract(contract)
  lookback <- contract$lookback_grid[[lookback_index]]
  target <- contract$target_grid[[target_index]]
  train_y <- train_panel$y[, target_index]
  development_y <- development_panel$y[, target_index]
  target_variance <- stats::var(train_y)
  if (!is.finite(target_variance) || target_variance <= .Machine$double.eps) {
    g5_mom015_stop("TRAIN target variance is degenerate.")
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
  fit_q2 <- g5_mom015_fit_design(
    standardized$train, train_y, standardized$development
  )
  predictions <- list(
    B0_DRIFT = rep(mean(train_y), length(development_y)),
    B1_RAW = fit_b1$prediction,
    Q2_PATH = fit_q2$prediction
  )
  squared <- lapply(predictions, function(prediction) (development_y - prediction)^2)
  absolute <- lapply(predictions, function(prediction) abs(development_y - prediction))
  mse0 <- mean(squared$B0_DRIFT)
  cell_id <- paste0("L", lookback, "_H", target)
  metrics <- do.call(rbind, lapply(contract$model_ids, function(model) {
    mse <- mean(squared[[model]])
    data.frame(
      cell_id = cell_id,
      lookback_sessions = lookback,
      target_sessions = target,
      model_id = model,
      train_anchor_count = length(train_y),
      development_anchor_count = length(development_y),
      train_target_mean = mean(train_y),
      train_target_variance = target_variance,
      development_mse = mse,
      development_mae = mean(absolute[[model]]),
      development_scaled_loss = mse / target_variance,
      oos_skill_vs_drift = 1 - mse / mse0,
      stringsAsFactors = FALSE
    )
  }))
  coefficients <- rbind(
    data.frame(
      cell_id = cell_id, lookback_sessions = lookback, target_sessions = target,
      model_id = "B0_DRIFT", feature = "intercept", coefficient = mean(train_y),
      fit_rank = 1L, stringsAsFactors = FALSE
    ),
    data.frame(
      cell_id = cell_id, lookback_sessions = lookback, target_sessions = target,
      model_id = "B1_RAW", feature = c("intercept", "raw_return"),
      coefficient = fit_b1$coefficients, fit_rank = fit_b1$rank,
      stringsAsFactors = FALSE
    ),
    data.frame(
      cell_id = cell_id, lookback_sessions = lookback, target_sessions = target,
      model_id = "Q2_PATH",
      feature = c("intercept", "raw_return", "coherent_positive", "shock_positive"),
      coefficient = fit_q2$coefficients, fit_rank = fit_q2$rank,
      stringsAsFactors = FALSE
    )
  )
  moments <- data.frame(
    cell_id = cell_id,
    lookback_sessions = lookback,
    target_sessions = target,
    feature = colnames(train_features),
    train_mean = standardized$center,
    train_sd = standardized$scale,
    stringsAsFactors = FALSE
  )
  losses <- data.frame(
    anchor_date = development_panel$anchor_date,
    B0_DRIFT = squared$B0_DRIFT / target_variance,
    B1_RAW = squared$B1_RAW / target_variance,
    Q2_PATH = squared$Q2_PATH / target_variance,
    stringsAsFactors = FALSE
  )
  list(metrics = metrics, coefficients = coefficients, moments = moments, losses = losses)
}

g5_mom015_stationary_index_matrix <- function(n, draws, expected_block) {
  probability_restart <- 1 / as.numeric(expected_block)
  indices <- matrix(NA_integer_, nrow = draws, ncol = n)
  indices[, 1L] <- sample.int(n, draws, replace = TRUE)
  if (n >= 2L) {
    for (column_i in 2:n) {
      restart <- stats::runif(draws) < probability_restart
      continued <- (indices[, column_i - 1L] %% n) + 1L
      starts <- sample.int(n, draws, replace = TRUE)
      indices[, column_i] <- ifelse(restart, starts, continued)
    }
  }
  indices
}

g5_mom015_stationary_mean <- function(
  values, seed, draws = 10000L, expected_block = 60,
  quantile_type = 7L
) {
  values <- as.numeric(values)
  if (length(values) < 2L || any(!is.finite(values))) {
    g5_mom015_stop("Stationary mean bootstrap requires finite ordered values.")
  }
  observed <- mean(values)
  set.seed(as.integer(seed))
  indices <- g5_mom015_stationary_index_matrix(length(values), draws, expected_block)
  boot <- rowMeans(matrix(values[indices], nrow = draws))
  if (any(!is.finite(boot))) g5_mom015_stop("Stationary mean bootstrap produced nonfinite draws.")
  data.frame(
    bootstrap_seed = as.integer(seed),
    bootstrap_draws = as.integer(draws),
    observed_mean_differential = observed,
    bootstrap_mean = mean(boot),
    ci_lower_90 = unname(stats::quantile(boot, 0.05, type = quantile_type)),
    ci_upper_90 = unname(stats::quantile(boot, 0.95, type = quantile_type)),
    centered_null_upper_p = (1 + sum((boot - observed) >= observed)) / (1 + length(boot)),
    stringsAsFactors = FALSE
  )
}

g5_mom015_apply_fdr <- function(contrasts, contract = g5_mom015_contract()) {
  contract <- g5_mom015_validate_contract(contract)
  required <- c("contrast_id", "analysis_stratum", "is_spy_reference", "centered_null_upper_p")
  missing <- setdiff(required, names(contrasts))
  if (length(missing)) {
    g5_mom015_stop(paste("Contrast columns missing:", paste(missing, collapse = ", ")))
  }
  contrasts$bh_q_value <- NA_real_
  for (contrast in contract$contrast_ids) {
    for (stratum in unique(contrasts$analysis_stratum)) {
      keep <- contrasts$contrast_id == contrast &
        contrasts$analysis_stratum == stratum &
        !contrasts$is_spy_reference
      contrasts$bh_q_value[keep] <- stats::p.adjust(
        contrasts$centered_null_upper_p[keep], method = "BH"
      )
    }
  }
  contrasts
}

g5_mom015_decisions <- function(
  contrasts, coefficient_summary, registry,
  contract = g5_mom015_contract()
) {
  contract <- g5_mom015_validate_contract(contract)
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    identity <- registry[i, , drop = FALSE]
    x <- contrasts[contrasts$analysis_id == identity$analysis_id, , drop = FALSE]
    coefficients <- coefficient_summary[
      coefficient_summary$analysis_id == identity$analysis_id, , drop = FALSE
    ]
    get_contrast <- function(id) x[x$contrast_id == id, , drop = FALSE]
    d10 <- get_contrast("D10")
    d21 <- get_contrast("D21")
    d20 <- get_contrast("D20")
    complete <- nrow(d10) == 1L && nrow(d21) == 1L && nrow(d20) == 1L && nrow(coefficients) == 1L
    path_candidate <- complete && !identity$is_spy_reference &&
      d21$observed_mean_differential > 0 && d21$bh_q_value <= contract$fdr_q &&
      d20$observed_mean_differential > 0 && d20$bh_q_value <= contract$fdr_q &&
      d21$ci_lower_90 > 0 && d20$ci_lower_90 > 0 &&
      coefficients$median_gamma > 0 && coefficients$median_delta < 0
    raw_clue <- complete && !identity$is_spy_reference &&
      d10$observed_mean_differential > 0 && d10$ci_lower_90 > 0 &&
      d10$bh_q_value <= contract$fdr_q
    data.frame(
      analysis_id = identity$analysis_id,
      symbol = identity$symbol,
      category = identity$category,
      analysis_stratum = identity$analysis_stratum,
      is_spy_reference = identity$is_spy_reference,
      comparison_complete = complete,
      d10_mean = if (nrow(d10)) d10$observed_mean_differential else NA_real_,
      d10_q = if (nrow(d10)) d10$bh_q_value else NA_real_,
      d21_mean = if (nrow(d21)) d21$observed_mean_differential else NA_real_,
      d21_q = if (nrow(d21)) d21$bh_q_value else NA_real_,
      d20_mean = if (nrow(d20)) d20$observed_mean_differential else NA_real_,
      d20_q = if (nrow(d20)) d20$bh_q_value else NA_real_,
      median_gamma = if (nrow(coefficients)) coefficients$median_gamma else NA_real_,
      median_delta = if (nrow(coefficients)) coefficients$median_delta else NA_real_,
      raw_beats_drift_clue = raw_clue,
      is_path_quality_candidate = path_candidate,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_mom015_category_summary <- function(decisions) {
  keys <- unique(decisions[, c("analysis_stratum", "category"), drop = FALSE])
  do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    x <- decisions[
      decisions$analysis_stratum == keys$analysis_stratum[[i]] &
        decisions$category == keys$category[[i]], , drop = FALSE
    ]
    tested <- x[x$comparison_complete & !x$is_spy_reference, , drop = FALSE]
    data.frame(
      analysis_stratum = keys$analysis_stratum[[i]],
      category = keys$category[[i]],
      registry_assets = nrow(x),
      tested_non_spy_assets = nrow(tested),
      raw_beats_drift_clues = sum(tested$raw_beats_drift_clue),
      path_quality_candidates = sum(tested$is_path_quality_candidate),
      positive_d10 = sum(tested$d10_mean > 0, na.rm = TRUE),
      positive_d21 = sum(tested$d21_mean > 0, na.rm = TRUE),
      positive_d20 = sum(tested$d20_mean > 0, na.rm = TRUE),
      median_d10 = if (nrow(tested)) stats::median(tested$d10_mean) else NA_real_,
      median_d21 = if (nrow(tested)) stats::median(tested$d21_mean) else NA_real_,
      median_d20 = if (nrow(tested)) stats::median(tested$d20_mean) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom015_run_comparison <- function(
  bars, registry, contract = g5_mom015_contract()
) {
  contract <- g5_mom015_validate_contract(contract)
  registry <- g5_mom015_validate_registry(registry, contract)
  bars <- g5_mom015_validate_bars(bars, registry, contract)
  mom014_contract <- g5_mom014_contract()
  ledger <- g5_mom014_coverage_ledger(bars, registry, mom014_contract)
  ledger$train_anchor_count <- 0L
  ledger$development_anchor_count <- 0L
  ledger$valid_cell_count <- 0L
  ledger$analysis_eligible <- FALSE
  ledger$comparison_status <- "NOT_TESTED_INELIGIBLE"
  cell_metrics <- list()
  coefficients <- list()
  moments <- list()
  anchor_losses <- list()
  contrasts <- list()
  coefficient_summaries <- list()

  for (asset_i in seq_len(nrow(registry))) {
    identity <- registry[asset_i, , drop = FALSE]
    ledger_i <- match(identity$analysis_id, ledger$analysis_id)
    if (!ledger$mechanically_eligible[[ledger_i]]) next
    symbol_bars <- bars[bars$symbol == identity$symbol, , drop = FALSE]
    train_panel <- g5_mom015_period_panel(
      symbol_bars, contract$train_start, contract$train_end, contract
    )
    development_panel <- g5_mom015_period_panel(
      symbol_bars, contract$development_start, contract$development_end, contract
    )
    train_n <- if (is.null(train_panel)) 0L else nrow(train_panel$y)
    development_n <- if (is.null(development_panel)) 0L else nrow(development_panel$y)
    ledger$train_anchor_count[[ledger_i]] <- train_n
    ledger$development_anchor_count[[ledger_i]] <- development_n
    if (train_n < contract$minimum_period_anchors ||
        development_n < contract$minimum_period_anchors) {
      ledger$eligibility_reason[[ledger_i]] <- "insufficient_common_period_anchors"
      ledger$comparison_status[[ledger_i]] <- "INSUFFICIENT_COMMON_PERIOD_ANCHORS"
      next
    }
    fitted <- list()
    failure <- NULL
    for (l_i in seq_along(contract$lookback_grid)) {
      for (h_i in seq_along(contract$target_grid)) {
        result <- tryCatch(
          g5_mom015_fit_cell(train_panel, development_panel, l_i, h_i, contract),
          error = function(e) e
        )
        if (inherits(result, "error")) {
          failure <- conditionMessage(result)
          break
        }
        fitted[[paste0("L", l_i, "_H", h_i)]] <- result
      }
      if (!is.null(failure)) break
    }
    ledger$valid_cell_count[[ledger_i]] <- length(fitted)
    if (!is.null(failure) || length(fitted) != 24L) {
      ledger$eligibility_reason[[ledger_i]] <- paste0("invalid_model_cell:", failure)
      ledger$comparison_status[[ledger_i]] <- "INVALID_MODEL_CELL"
      next
    }
    ledger$analysis_eligible[[ledger_i]] <- TRUE
    ledger$comparison_status[[ledger_i]] <- "COMPLETE_24_CELL_COMPARISON"
    tag <- function(x) cbind(
      analysis_id = identity$analysis_id,
      symbol = identity$symbol,
      category = identity$category,
      analysis_stratum = identity$analysis_stratum,
      is_spy_reference = identity$is_spy_reference,
      x
    )
    metrics_asset <- do.call(rbind, lapply(fitted, `[[`, "metrics"))
    coefficients_asset <- do.call(rbind, lapply(fitted, `[[`, "coefficients"))
    moments_asset <- do.call(rbind, lapply(fitted, `[[`, "moments"))
    loss_arrays <- lapply(contract$model_ids, function(model) {
      do.call(cbind, lapply(fitted, function(cell) cell$losses[[model]]))
    })
    names(loss_arrays) <- contract$model_ids
    aggregate_losses <- data.frame(
      anchor_date = development_panel$anchor_date,
      B0_DRIFT = rowMeans(loss_arrays$B0_DRIFT),
      B1_RAW = rowMeans(loss_arrays$B1_RAW),
      Q2_PATH = rowMeans(loss_arrays$Q2_PATH),
      stringsAsFactors = FALSE
    )
    aggregate_losses$D10 <- aggregate_losses$B0_DRIFT - aggregate_losses$B1_RAW
    aggregate_losses$D21 <- aggregate_losses$B1_RAW - aggregate_losses$Q2_PATH
    aggregate_losses$D20 <- aggregate_losses$B0_DRIFT - aggregate_losses$Q2_PATH
    contrast_asset <- do.call(rbind, lapply(seq_along(contract$contrast_ids), function(j) {
      contrast <- contract$contrast_ids[[j]]
      seed <- contract$bootstrap_seed_base + 10L * identity$order[[1L]] + j
      cbind(
        contrast_id = contrast,
        g5_mom015_stationary_mean(
          aggregate_losses[[contrast]], seed,
          contract$bootstrap_count, contract$bootstrap_expected_block,
          contract$bootstrap_quantile_type
        )
      )
    }))
    gamma <- coefficients_asset$coefficient[
      coefficients_asset$model_id == "Q2_PATH" &
        coefficients_asset$feature == "coherent_positive"
    ]
    delta <- coefficients_asset$coefficient[
      coefficients_asset$model_id == "Q2_PATH" &
        coefficients_asset$feature == "shock_positive"
    ]
    coefficient_summaries[[identity$analysis_id]] <- tag(data.frame(
      cell_count = length(gamma),
      median_gamma = stats::median(gamma),
      positive_gamma_cells = sum(gamma > 0),
      median_delta = stats::median(delta),
      negative_delta_cells = sum(delta < 0),
      mechanism_aligned = stats::median(gamma) > 0 && stats::median(delta) < 0,
      stringsAsFactors = FALSE
    ))
    cell_metrics[[identity$analysis_id]] <- tag(metrics_asset)
    coefficients[[identity$analysis_id]] <- tag(coefficients_asset)
    moments[[identity$analysis_id]] <- tag(moments_asset)
    anchor_losses[[identity$analysis_id]] <- tag(aggregate_losses)
    contrasts[[identity$analysis_id]] <- tag(contrast_asset)
  }

  bind_or_empty <- function(x) if (length(x)) do.call(rbind, x) else data.frame()
  contrast_table <- g5_mom015_apply_fdr(bind_or_empty(contrasts), contract)
  coefficient_summary <- bind_or_empty(coefficient_summaries)
  decisions <- g5_mom015_decisions(contrast_table, coefficient_summary, registry, contract)
  candidates <- decisions[decisions$is_path_quality_candidate, , drop = FALSE]
  raw_clues <- decisions[decisions$raw_beats_drift_clue, , drop = FALSE]
  status <- if (nrow(candidates)) {
    "DEVELOPMENT_COMPLETE_LIT_MOM_01_5_PATH_QUALITY_CANDIDATES"
  } else {
    "STOP_LIT_MOM_01_5_NO_INCREMENTAL_PATH_QUALITY_FORECAST"
  }
  list(
    contract = contract,
    registry = registry,
    ledger = ledger,
    cell_metrics = bind_or_empty(cell_metrics),
    coefficients = bind_or_empty(coefficients),
    feature_moments = bind_or_empty(moments),
    anchor_losses = bind_or_empty(anchor_losses),
    contrasts = contrast_table,
    coefficient_summary = coefficient_summary,
    decisions = decisions,
    candidates = candidates,
    raw_clues = raw_clues,
    category_summary = g5_mom015_category_summary(decisions),
    overall_status = status,
    confirmation_opened = FALSE
  )
}
