# Frozen HYP-MOM-08.1 QQQ / SPY relative-strength predictor helpers.

g5_hm081_stop <- function(message) stop(message, call. = FALSE)

g5_hm081_schema_version <- function() "gen5_hyp_mom_08_1_v1"

g5_hm081_contract <- function() {
  list(
    hypothesis_id = "HYP-MOM-08.1",
    descriptive_name = "QQQ / SPY Relative-Strength Persistence",
    symbols = c("QQQ", "SPY"),
    qqq_symbol = "QQQ",
    spy_symbol = "SPY",
    as_of_timestamp = "2026-08-22 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    confirmation_end = as.Date("2025-12-31"),
    lookback_grid = c(5L, 20L, 60L),
    target_grid = c(1L, 5L, 20L),
    common_lookback_sessions = 60L,
    common_target_sessions = 20L,
    circular_shift_minimum = 60L,
    surface_percentile = 0.90,
    quantile_type = 7L,
    bootstrap_count = 10000L,
    bootstrap_expected_block = 20,
    bootstrap_seed = 803101L,
    minimum_train_anchors = 900L,
    minimum_development_anchors = 600L
  )
}

g5_hm081_validate_contract <- function(contract = g5_hm081_contract()) {
  frozen <- g5_hm081_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_hm081_stop("Frozen HYP-MOM-08.1 contract field set changed.")
  }
  same <- vapply(names(frozen), function(field) identical(contract[[field]], frozen[[field]]), logical(1))
  if (!all(same)) {
    g5_hm081_stop(paste(
      "Frozen HYP-MOM-08.1 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_hm081_validate_bars <- function(bars, maximum_allowed_date, contract = g5_hm081_contract()) {
  contract <- g5_hm081_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_hm081_stop(paste("Missing required bar columns:", paste(missing, collapse = ", ")))
  }
  x <- bars[bars$symbol %in% contract$symbols, required, drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  per_symbol <- split(x, x$symbol)
  complete_symbols <- identical(sort(names(per_symbol)), sort(contract$symbols))
  duplicate_count <- sum(duplicated(x[c("symbol", "session_date")]))
  strict_order <- complete_symbols && all(vapply(per_symbol, function(z) all(diff(z$session_date) > 0), logical(1)))
  date_sets <- if (complete_symbols) lapply(per_symbol, function(z) as.character(z$session_date)) else list()
  identical_sessions <- complete_symbols && length(date_sets) == 2L && identical(date_sets[[1L]], date_sets[[2L]])
  maximum_observed <- if (nrow(x)) max(x$session_date) else as.Date(NA)
  minimum_observed <- if (nrow(x)) min(x$session_date) else as.Date(NA)
  checks <- data.frame(
    check_id = c(
      "exact_symbols", "strict_symbol_date_order", "unique_symbol_sessions",
      "identical_common_sessions", "finite_positive_open_close",
      "adjusted_daily_only", "query_start_covered", "maximum_date_seal"
    ),
    passed = c(
      complete_symbols,
      strict_order,
      duplicate_count == 0L,
      identical_sessions,
      nrow(x) > 0L && all(is.finite(x$open) & x$open > 0 & is.finite(x$close) & x$close > 0),
      nrow(x) > 0L && all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      nrow(x) > 0L && minimum_observed <= contract$query_start,
      nrow(x) > 0L && maximum_observed <= as.Date(maximum_allowed_date)
    ),
    observed = c(
      paste(sort(unique(as.character(x$symbol))), collapse = ","),
      as.character(strict_order),
      as.character(duplicate_count),
      as.character(identical_sessions),
      if (nrow(x)) paste(range(c(x$open, x$close)), collapse = " to ") else "none",
      paste(unique(paste(x$adjusted, x$timeframe, sep = "/")), collapse = ","),
      as.character(minimum_observed),
      as.character(maximum_observed)
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_hm081_stop(paste(
      "HYP-MOM-08.1 bar validation failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  wide <- merge(
    per_symbol[[contract$qqq_symbol]][c("session_date", "open", "close")],
    per_symbol[[contract$spy_symbol]][c("session_date", "open", "close")],
    by = "session_date", suffixes = c("_qqq", "_spy"), all = FALSE, sort = TRUE
  )
  list(bars = x, wide = wide, checks = checks)
}

g5_hm081_zone_panel <- function(
  bars,
  zone_start,
  zone_end,
  minimum_anchors,
  maximum_allowed_date = zone_end,
  contract = g5_hm081_contract()
) {
  checked <- g5_hm081_validate_bars(bars, maximum_allowed_date, contract)
  x <- checked$wide
  max_l <- contract$common_lookback_sessions
  max_h <- contract$common_target_sessions
  index <- seq_len(nrow(x))
  anchor_i <- index[
    index > max_l &
      index + 1L + max_h <= nrow(x) &
      x$session_date >= as.Date(zone_start)
  ]
  anchor_i <- anchor_i[x$session_date[anchor_i + 1L + max_h] <= as.Date(zone_end)]
  if (length(anchor_i) < as.integer(minimum_anchors)) {
    g5_hm081_stop(paste("Insufficient common anchors in zone:", length(anchor_i)))
  }
  x_q <- vapply(contract$lookback_grid, function(lag_n) {
    log(x$close_qqq[anchor_i] / x$close_qqq[anchor_i - lag_n])
  }, numeric(length(anchor_i)))
  x_s <- vapply(contract$lookback_grid, function(lag_n) {
    log(x$close_spy[anchor_i] / x$close_spy[anchor_i - lag_n])
  }, numeric(length(anchor_i)))
  y_q <- vapply(contract$target_grid, function(horizon_n) {
    log(x$open_qqq[anchor_i + 1L + horizon_n] / x$open_qqq[anchor_i + 1L])
  }, numeric(length(anchor_i)))
  y_s <- vapply(contract$target_grid, function(horizon_n) {
    log(x$open_spy[anchor_i + 1L + horizon_n] / x$open_spy[anchor_i + 1L])
  }, numeric(length(anchor_i)))
  colnames(x_q) <- colnames(x_s) <- paste0("L", contract$lookback_grid)
  colnames(y_q) <- colnames(y_s) <- paste0("H", contract$target_grid)
  matrices <- list(x_qqq = x_q, x_spy = x_s, x_relative = x_q - x_s,
                   y_qqq = y_q, y_spy = y_s, y_relative = y_q - y_s)
  if (!all(vapply(matrices, function(m) all(is.finite(m)), logical(1)))) {
    g5_hm081_stop("Nonfinite predictor or target values were constructed.")
  }
  list(
    integrity = checked$checks,
    wide = x,
    anchor_index = anchor_i,
    anchor_date = x$session_date[anchor_i],
    entry_date = x$session_date[anchor_i + 1L],
    maximum_exit_date = x$session_date[anchor_i + 1L + max_h],
    x_qqq = x_q,
    x_spy = x_s,
    x_relative = x_q - x_s,
    y_qqq = y_q,
    y_spy = y_s,
    y_relative = y_q - y_s
  )
}

g5_hm081_cell_statistics <- function(x, y, lookback, target) {
  fit <- stats::lm.fit(cbind(1, x), y)
  data.frame(
    cell_id = paste0("L", lookback, "_H", target),
    lookback_sessions = as.integer(lookback),
    target_sessions = as.integer(target),
    anchor_count = length(x),
    alpha = unname(fit$coefficients[[1L]]),
    beta = unname(fit$coefficients[[2L]]),
    correlation = unname(stats::cor(x, y)),
    spearman = unname(stats::cor(x, y, method = "spearman")),
    stringsAsFactors = FALSE
  )
}

g5_hm081_surface <- function(panel, contract = g5_hm081_contract()) {
  rows <- list()
  row_i <- 1L
  for (l_i in seq_along(contract$lookback_grid)) {
    for (h_i in seq_along(contract$target_grid)) {
      rows[[row_i]] <- g5_hm081_cell_statistics(
        panel$x_relative[, l_i], panel$y_relative[, h_i],
        contract$lookback_grid[[l_i]], contract$target_grid[[h_i]]
      )
      row_i <- row_i + 1L
    }
  }
  out <- do.call(rbind, rows)
  if (nrow(out) != 9L || anyDuplicated(out$cell_id)) {
    g5_hm081_stop("Frozen nine-cell surface is incomplete or duplicated.")
  }
  out
}

g5_hm081_rotate_rows <- function(matrix, shift) {
  n <- nrow(matrix)
  shift <- as.integer(shift) %% n
  if (shift == 0L) return(matrix)
  matrix[c((shift + 1L):n, seq_len(shift)), , drop = FALSE]
}

g5_hm081_admissible_shifts <- function(n, minimum_displacement) {
  shifts <- seq_len(n - 1L)
  shifts[pmin(shifts, n - shifts) >= minimum_displacement]
}

g5_hm081_shift_test <- function(panel, surface, contract = g5_hm081_contract()) {
  n <- nrow(panel$x_relative)
  shifts <- g5_hm081_admissible_shifts(n, contract$circular_shift_minimum)
  maxima <- vapply(shifts, function(shift) {
    y_shift <- g5_hm081_rotate_rows(panel$y_relative, shift)
    max(vapply(seq_along(contract$lookback_grid), function(l_i) {
      max(vapply(seq_along(contract$target_grid), function(h_i) {
        stats::cor(panel$x_relative[, l_i], y_shift[, h_i])
      }, numeric(1)))
    }, numeric(1)))
  }, numeric(1))
  observed <- max(surface$correlation)
  threshold <- unname(stats::quantile(
    maxima, probs = contract$surface_percentile,
    type = contract$quantile_type, names = FALSE
  ))
  support_passed <- n >= contract$minimum_train_anchors
  passed <- support_passed && is.finite(observed) && observed > 0 && observed > threshold
  list(
    distribution = data.frame(shift = shifts, maximum_correlation = maxima, stringsAsFactors = FALSE),
    decision = data.frame(
      train_anchor_count = n,
      support_passed = support_passed,
      observed_maximum_correlation = observed,
      shift_maximum_p90 = threshold,
      empirical_upper_tail_probability = (1 + sum(maxima >= observed)) / (1 + length(maxima)),
      admissible_shift_count = length(shifts),
      passed = passed,
      status = if (passed) "TRAIN_SEARCH_ADJUSTED_SURFACE_PASS" else "STOP_HYP_MOM_08_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE",
      stringsAsFactors = FALSE
    )
  )
}

g5_hm081_nominate <- function(surface, passed) {
  if (!isTRUE(passed)) return(surface[FALSE, , drop = FALSE])
  candidates <- surface[surface$correlation == max(surface$correlation), , drop = FALSE]
  candidates <- candidates[order(candidates$target_sessions, candidates$lookback_sessions), , drop = FALSE]
  candidates[1L, , drop = FALSE]
}

g5_hm081_cell_vectors <- function(panel, lookback, target, contract = g5_hm081_contract()) {
  l_i <- match(as.integer(lookback), contract$lookback_grid)
  h_i <- match(as.integer(target), contract$target_grid)
  if (is.na(l_i) || is.na(h_i)) g5_hm081_stop("Requested cell is outside the frozen surface.")
  data.frame(
    anchor_date = panel$anchor_date,
    entry_date = panel$entry_date,
    maximum_exit_date = panel$maximum_exit_date,
    x_relative = panel$x_relative[, l_i],
    x_qqq = panel$x_qqq[, l_i],
    x_spy = panel$x_spy[, l_i],
    y_relative = panel$y_relative[, h_i],
    y_qqq = panel$y_qqq[, h_i],
    y_spy = panel$y_spy[, h_i],
    stringsAsFactors = FALSE
  )
}

g5_hm081_fit_coefficients <- function(y, predictors) {
  design <- cbind(1, as.matrix(predictors))
  fit <- stats::lm.fit(design, y)
  if (any(!is.finite(fit$coefficients))) g5_hm081_stop("Nonfinite frozen-model coefficient.")
  unname(fit$coefficients)
}

g5_hm081_model_predictions <- function(train, development) {
  definitions <- list(
    DRIFT = character(),
    RELATIVE = "x_relative",
    QQQ_LEG = "x_qqq",
    SPY_LEG = "x_spy",
    TWO_LEG = c("x_qqq", "x_spy")
  )
  rows <- lapply(names(definitions), function(model_id) {
    fields <- definitions[[model_id]]
    train_x <- if (length(fields)) train[fields] else matrix(numeric(nrow(train) * 0L), nrow = nrow(train))
    development_x <- if (length(fields)) development[fields] else matrix(numeric(nrow(development) * 0L), nrow = nrow(development))
    coefficients <- g5_hm081_fit_coefficients(train$y_relative, train_x)
    prediction <- as.numeric(cbind(1, as.matrix(development_x)) %*% coefficients)
    error <- development$y_relative - prediction
    data.frame(
      model_id = model_id,
      train_coefficients = paste(sprintf("%.12g", coefficients), collapse = ";"),
      development_count = length(error),
      development_mse = mean(error^2),
      development_mae = mean(abs(error)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_hm081_stationary_indices <- function(n, expected_block) {
  p <- 1 / expected_block
  out <- integer(n)
  out[[1L]] <- sample.int(n, 1L)
  if (n >= 2L) {
    for (i in 2:n) {
      out[[i]] <- if (stats::runif(1L) < p) sample.int(n, 1L) else if (out[[i - 1L]] == n) 1L else out[[i - 1L]] + 1L
    }
  }
  out
}

g5_hm081_bootstrap_beta <- function(pairs, contract = g5_hm081_contract()) {
  set.seed(contract$bootstrap_seed)
  beta <- replicate(contract$bootstrap_count, {
    idx <- g5_hm081_stationary_indices(nrow(pairs), contract$bootstrap_expected_block)
    unname(stats::lm.fit(cbind(1, pairs$x_relative[idx]), pairs$y_relative[idx])$coefficients[[2L]])
  })
  stats::quantile(beta, probs = c(0.05, 0.95), type = contract$quantile_type, names = FALSE)
}

g5_hm081_years <- function(pairs) {
  years <- format(pairs$anchor_date, "%Y")
  do.call(rbind, lapply(split(seq_len(nrow(pairs)), years), function(idx) {
    statistics <- g5_hm081_cell_statistics(pairs$x_relative[idx], pairs$y_relative[idx], NA_integer_, NA_integer_)
    data.frame(year = years[idx[[1L]]], anchor_count = length(idx), beta = statistics$beta,
               correlation = statistics$correlation, spearman = statistics$spearman, stringsAsFactors = FALSE)
  }))
}

g5_hm081_phases <- function(pairs, horizon) {
  phases <- seq_len(as.integer(horizon)) - 1L
  do.call(rbind, lapply(phases, function(phase) {
    idx <- seq.int(phase + 1L, nrow(pairs), by = as.integer(horizon))
    statistics <- g5_hm081_cell_statistics(pairs$x_relative[idx], pairs$y_relative[idx], NA_integer_, NA_integer_)
    data.frame(phase_offset = phase, anchor_count = length(idx), beta = statistics$beta,
               correlation = statistics$correlation, stringsAsFactors = FALSE)
  }))
}

g5_hm081_quintiles <- function(pairs) {
  ordered_rank <- rank(pairs$x_relative, ties.method = "first")
  quintile <- pmin(5L, ceiling(5 * ordered_rank / nrow(pairs)))
  do.call(rbind, lapply(split(seq_len(nrow(pairs)), quintile), function(idx) {
    data.frame(
      quintile = as.integer(quintile[idx[[1L]]]),
      count = length(idx),
      mean_predictor = mean(pairs$x_relative[idx]),
      mean_target = mean(pairs$y_relative[idx]),
      stringsAsFactors = FALSE
    )
  }))
}

g5_hm081_run_train <- function(bars, contract = g5_hm081_contract()) {
  panel <- g5_hm081_zone_panel(
    bars, contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  surface <- g5_hm081_surface(panel, contract)
  shift <- g5_hm081_shift_test(panel, surface, contract)
  nominee <- g5_hm081_nominate(surface, shift$decision$passed[[1L]])
  list(
    contract = contract,
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

g5_hm081_run_development <- function(train_bars, development_bars, nominee, contract = g5_hm081_contract()) {
  if (!is.data.frame(nominee) || nrow(nominee) != 1L) {
    g5_hm081_stop("Exactly one frozen TRAIN nominee is required.")
  }
  train_panel <- g5_hm081_zone_panel(
    train_bars, contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  development_panel <- g5_hm081_zone_panel(
    development_bars, contract$development_start, contract$development_end,
    contract$minimum_development_anchors, contract$development_end, contract
  )
  lookback <- nominee$lookback_sessions[[1L]]
  target <- nominee$target_sessions[[1L]]
  train_pairs <- g5_hm081_cell_vectors(train_panel, lookback, target, contract)
  development_pairs <- g5_hm081_cell_vectors(development_panel, lookback, target, contract)
  development_statistics <- g5_hm081_cell_statistics(
    development_pairs$x_relative, development_pairs$y_relative, lookback, target
  )
  interval <- g5_hm081_bootstrap_beta(development_pairs, contract)
  models <- g5_hm081_model_predictions(train_pairs, development_pairs)
  years <- g5_hm081_years(development_pairs)
  phases <- g5_hm081_phases(development_pairs, target)
  mse <- stats::setNames(models$development_mse, models$model_id)
  gates <- data.frame(
    gate_id = c(
      "G1_INTEGRITY", "G2_DIRECTIONAL_TRANSPORT", "G3_RANK_TRANSPORT",
      "G4_RELATIVE_DRIFT_VALUE_ADD", "G5_LEG_SPECIFICITY", "G6_TEMPORAL_STABILITY"
    ),
    passed = c(
      all(development_panel$integrity$passed),
      development_statistics$beta[[1L]] > 0 && interval[[1L]] > 0,
      development_statistics$spearman[[1L]] > 0,
      mse[["RELATIVE"]] < mse[["DRIFT"]],
      mse[["RELATIVE"]] < mse[["QQQ_LEG"]] && mse[["RELATIVE"]] < mse[["SPY_LEG"]],
      sum(years$beta > 0) >= 2L && sum(phases$beta > 0) > nrow(phases) / 2
    ),
    observed = c(
      paste0(sum(development_panel$integrity$passed), "/", nrow(development_panel$integrity)),
      sprintf("beta=%.8f;lower90=%.8f", development_statistics$beta[[1L]], interval[[1L]]),
      sprintf("spearman=%.8f", development_statistics$spearman[[1L]]),
      sprintf("relative=%.12g;drift=%.12g", mse[["RELATIVE"]], mse[["DRIFT"]]),
      sprintf("relative=%.12g;qqq=%.12g;spy=%.12g", mse[["RELATIVE"]], mse[["QQQ_LEG"]], mse[["SPY_LEG"]]),
      paste0("positive_years=", sum(years$beta > 0), "/", nrow(years),
             ";positive_phases=", sum(phases$beta > 0), "/", nrow(phases))
    ),
    stringsAsFactors = FALSE
  )
  gates$status <- ifelse(gates$passed, "PASS", "FAIL")
  overall <- if (all(gates$passed)) {
    "DEVELOPMENT_PASS_HYP_MOM_08_1_CONFIRMATION_REVIEW_REQUIRED"
  } else {
    "STOP_HYP_MOM_08_1_DEVELOPMENT_RELATIVE_STRENGTH_GATES_FAILED"
  }
  list(
    contract = contract,
    nominee = nominee,
    train_panel = train_panel,
    development_panel = development_panel,
    train_pairs = train_pairs,
    development_pairs = development_pairs,
    development_statistics = transform(
      development_statistics,
      beta_lower_90 = interval[[1L]], beta_upper_90 = interval[[2L]]
    ),
    model_comparison = models,
    year_diagnostics = years,
    phase_diagnostics = phases,
    quintile_diagnostics = g5_hm081_quintiles(development_pairs),
    gates = gates,
    overall_status = overall,
    confirmation_opened = FALSE
  )
}
