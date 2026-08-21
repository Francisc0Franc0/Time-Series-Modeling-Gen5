# Frozen LIT-MOM-01.3 SPY horizon-surface predictor helpers.

g5_mom013_stop <- function(message) stop(message, call. = FALSE)

g5_mom013_schema_version <- function() "gen5_lit_mom_01_3_v1"

g5_mom013_contract <- function() {
  list(
    literature_id = "LIT-MOM-01.3",
    descriptive_name = "SPY Time-Series-Momentum Horizon-Surface Predictor",
    symbol = "SPY",
    as_of_timestamp = "2026-08-21 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    sandbox_start = as.Date("2017-01-03"),
    sandbox_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    confirmation_end = as.Date("2025-12-31"),
    lookback_grid = c(1L, 5L, 10L, 25L, 60L, 120L, 250L),
    target_grid = c(5L, 10L, 25L, 60L),
    common_lookback_sessions = 250L,
    common_target_sessions = 60L,
    circular_shift_minimum = 250L,
    surface_percentile = 0.90,
    quantile_type = 7L,
    bootstrap_count = 10000L,
    bootstrap_expected_block = 60,
    bootstrap_seed = 20260821L,
    minimum_confirmation_anchors = 400L,
    canonical_lookback = 250L,
    canonical_target = 25L
  )
}

g5_mom013_validate_contract <- function(contract = g5_mom013_contract()) {
  frozen <- g5_mom013_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom013_stop("Frozen LIT-MOM-01.3 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom013_stop(paste(
      "Frozen LIT-MOM-01.3 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom013_validate_bars <- function(bars, contract = g5_mom013_contract()) {
  contract <- g5_mom013_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_mom013_stop(paste("Missing required bar columns:", paste(missing, collapse = ", ")))
  }
  x <- bars[bars$symbol == contract$symbol, , drop = FALSE]
  if (!nrow(x)) g5_mom013_stop("No SPY bars were supplied.")
  x$session_date <- as.Date(x$session_date)
  x <- x[order(x$session_date), , drop = FALSE]
  checks <- data.frame(
    check_id = c(
      "single_symbol",
      "strict_date_order",
      "unique_sessions",
      "finite_positive_open_close",
      "adjusted_daily_only",
      "query_start_covered",
      "sandbox_end_covered",
      "confirmation_excluded"
    ),
    passed = c(
      identical(unique(as.character(x$symbol)), contract$symbol),
      all(diff(x$session_date) > 0),
      !anyDuplicated(x$session_date),
      all(is.finite(x$open) & x$open > 0 & is.finite(x$close) & x$close > 0),
      all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      min(x$session_date) <= contract$query_start,
      max(x$session_date) >= contract$sandbox_end,
      max(x$session_date) < contract$confirmation_start
    ),
    observed = c(
      paste(unique(as.character(x$symbol)), collapse = ","),
      as.character(all(diff(x$session_date) > 0)),
      as.character(sum(duplicated(x$session_date))),
      paste(range(c(x$open, x$close)), collapse = " to "),
      paste(unique(paste(x$adjusted, x$timeframe, sep = "/")), collapse = ","),
      as.character(min(x$session_date)),
      as.character(max(x$session_date)),
      as.character(max(x$session_date))
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_mom013_stop(paste(
      "LIT-MOM-01.3 bar validation failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  list(bars = x, checks = checks)
}

g5_mom013_common_panel <- function(bars, contract = g5_mom013_contract()) {
  checked <- g5_mom013_validate_bars(bars, contract)
  x <- checked$bars
  max_l <- contract$common_lookback_sessions
  max_h <- contract$common_target_sessions
  indices <- seq_len(nrow(x))
  anchor_i <- indices[
    indices > max_l &
      indices + 1L + max_h <= nrow(x) &
      x$session_date >= contract$sandbox_start
  ]
  anchor_i <- anchor_i[
    x$session_date[anchor_i + 1L + max_h] <= contract$sandbox_end
  ]
  if (!length(anchor_i)) g5_mom013_stop("No common sandbox anchors are available.")
  exit_i <- anchor_i + 1L + max_h
  if (any(exit_i > nrow(x)) || any(x$session_date[exit_i] > contract$sandbox_end)) {
    g5_mom013_stop("Common-anchor target endpoints escaped the sandbox.")
  }

  x_matrix <- vapply(contract$lookback_grid, function(lag_n) {
    log(x$close[anchor_i] / x$close[anchor_i - lag_n])
  }, numeric(length(anchor_i)))
  y_matrix <- vapply(contract$target_grid, function(horizon_n) {
    log(x$open[anchor_i + 1L + horizon_n] / x$open[anchor_i + 1L])
  }, numeric(length(anchor_i)))
  colnames(x_matrix) <- paste0("L", contract$lookback_grid)
  colnames(y_matrix) <- paste0("H", contract$target_grid)
  if (!all(is.finite(x_matrix)) || !all(is.finite(y_matrix))) {
    g5_mom013_stop("Nonfinite predictor or target values were constructed.")
  }
  list(
    bars = x,
    integrity = checked$checks,
    anchor_index = anchor_i,
    anchor_date = x$session_date[anchor_i],
    entry_date = x$session_date[anchor_i + 1L],
    maximum_exit_date = x$session_date[exit_i],
    x = x_matrix,
    y = y_matrix
  )
}

g5_mom013_cell_statistics <- function(x, y, lookback, target) {
  fit <- stats::lm.fit(cbind(1, x), y)
  beta <- unname(fit$coefficients[[2L]])
  alpha <- unname(fit$coefficients[[1L]])
  rho <- stats::cor(x, y)
  nominal_p <- if (length(x) >= 3L && is.finite(rho) && abs(rho) < 1) {
    2 * stats::pt(-abs(rho * sqrt((length(x) - 2) / (1 - rho^2))), df = length(x) - 2)
  } else {
    NA_real_
  }
  past_sign <- sign(x)
  future_sign <- sign(y)
  data.frame(
    lookback_sessions = as.integer(lookback),
    target_sessions = as.integer(target),
    anchor_count = length(x),
    alpha = alpha,
    beta = beta,
    correlation = rho,
    nominal_pearson_p_value = nominal_p,
    sign_accuracy = mean(past_sign == future_sign),
    positive_target_frequency = mean(y > 0),
    unconditional_target_mean = mean(y),
    stringsAsFactors = FALSE
  )
}

g5_mom013_surface <- function(panel, contract = g5_mom013_contract()) {
  contract <- g5_mom013_validate_contract(contract)
  rows <- vector("list", length(contract$lookback_grid) * length(contract$target_grid))
  row_i <- 1L
  for (l_i in seq_along(contract$lookback_grid)) {
    for (h_i in seq_along(contract$target_grid)) {
      rows[[row_i]] <- g5_mom013_cell_statistics(
        panel$x[, l_i], panel$y[, h_i],
        contract$lookback_grid[[l_i]], contract$target_grid[[h_i]]
      )
      row_i <- row_i + 1L
    }
  }
  out <- do.call(rbind, rows)
  out$is_canonical_250_25 <- out$lookback_sessions == contract$canonical_lookback &
    out$target_sessions == contract$canonical_target
  out$cell_id <- paste0("L", out$lookback_sessions, "_H", out$target_sessions)
  out <- out[order(out$lookback_sessions, out$target_sessions), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_mom013_admissible_shifts <- function(n, minimum_displacement) {
  shifts <- seq_len(n - 1L)
  shifts[pmin(shifts, n - shifts) >= as.integer(minimum_displacement)]
}

g5_mom013_rotate_rows <- function(x, shift) {
  n <- nrow(x)
  shift <- as.integer(shift) %% n
  if (shift == 0L) return(x)
  x[c((shift + 1L):n, seq_len(shift)), , drop = FALSE]
}

g5_mom013_correlation_matrix <- function(x_matrix, y_matrix) {
  xc <- scale(x_matrix, center = TRUE, scale = FALSE)
  yc <- scale(y_matrix, center = TRUE, scale = FALSE)
  denominator <- outer(
    sqrt(colSums(xc^2)), sqrt(colSums(yc^2)), FUN = "*"
  )
  crossprod(xc, yc) / denominator
}

g5_mom013_shift_control <- function(panel, surface, contract = g5_mom013_contract()) {
  contract <- g5_mom013_validate_contract(contract)
  shifts <- g5_mom013_admissible_shifts(
    nrow(panel$x), contract$circular_shift_minimum
  )
  if (!length(shifts)) g5_mom013_stop("No admissible circular shifts are available.")
  observed <- max(surface$correlation)
  null_max <- vapply(shifts, function(shift) {
    shifted_y <- g5_mom013_rotate_rows(panel$y, shift)
    max(g5_mom013_correlation_matrix(panel$x, shifted_y))
  }, numeric(1))
  threshold <- unname(stats::quantile(
    null_max, contract$surface_percentile,
    type = contract$quantile_type, names = FALSE
  ))
  passed <- is.finite(observed) && observed > 0 && observed > threshold
  distribution <- data.frame(
    shift_sessions = shifts,
    maximum_correlation = null_max,
    stringsAsFactors = FALSE
  )
  decision <- data.frame(
    gate_id = "SANDBOX_GLOBAL_SURFACE",
    observed_maximum_correlation = observed,
    null_shift_count = length(shifts),
    null_percentile = contract$surface_percentile,
    null_percentile_threshold = threshold,
    observed_percentile = mean(null_max < observed),
    empirical_upper_p_value = (1 + sum(null_max >= observed)) / (1 + length(null_max)),
    passed = passed,
    status = if (passed) "PASS" else "FAIL",
    stringsAsFactors = FALSE
  )
  list(distribution = distribution, decision = decision)
}

g5_mom013_nominate <- function(surface, surface_passed) {
  if (!isTRUE(surface_passed)) return(surface[FALSE, , drop = FALSE])
  candidates <- surface[is.finite(surface$correlation) & surface$correlation > 0, , drop = FALSE]
  if (!nrow(candidates)) g5_mom013_stop("Surface passed without a positive candidate.")
  candidates <- candidates[order(
    -candidates$correlation,
    candidates$target_sessions,
    candidates$lookback_sessions
  ), , drop = FALSE]
  nominee <- candidates[1L, , drop = FALSE]
  nominee$selection_rule <- "max_positive_correlation;tie_shorter_H_then_shorter_L"
  nominee$confirmation_opened <- FALSE
  nominee
}

g5_mom013_stationary_indices <- function(n, expected_block) {
  probability_restart <- 1 / as.numeric(expected_block)
  indices <- integer(n)
  indices[[1L]] <- sample.int(n, 1L)
  if (n >= 2L) {
    for (i in 2:n) {
      indices[[i]] <- if (stats::runif(1) < probability_restart) {
        sample.int(n, 1L)
      } else {
        if (indices[[i - 1L]] == n) 1L else indices[[i - 1L]] + 1L
      }
    }
  }
  indices
}

g5_mom013_beta_matrix <- function(x_matrix, y_matrix) {
  xc <- scale(x_matrix, center = TRUE, scale = FALSE)
  yc <- scale(y_matrix, center = TRUE, scale = FALSE)
  denominator <- colSums(xc^2)
  out <- sweep(crossprod(xc, yc), 1L, denominator, FUN = "/")
  out[!is.finite(out)] <- NA_real_
  out
}

g5_mom013_bootstrap <- function(panel, contract = g5_mom013_contract()) {
  contract <- g5_mom013_validate_contract(contract)
  n <- nrow(panel$x)
  draws <- matrix(
    NA_real_, nrow = contract$bootstrap_count,
    ncol = length(contract$lookback_grid) * length(contract$target_grid)
  )
  cell_names <- as.vector(outer(
    paste0("L", contract$lookback_grid), paste0("H", contract$target_grid),
    function(l, h) paste(l, h, sep = "_")
  ))
  colnames(draws) <- cell_names
  set.seed(contract$bootstrap_seed)
  for (draw_i in seq_len(contract$bootstrap_count)) {
    indices <- g5_mom013_stationary_indices(n, contract$bootstrap_expected_block)
    beta <- g5_mom013_beta_matrix(panel$x[indices, , drop = FALSE], panel$y[indices, , drop = FALSE])
    draws[draw_i, ] <- as.vector(beta)
  }
  intervals <- data.frame(
    cell_id = cell_names,
    beta_bootstrap_mean = colMeans(draws, na.rm = TRUE),
    beta_ci_lower_90 = apply(draws, 2L, stats::quantile, probs = 0.05, na.rm = TRUE, type = contract$quantile_type),
    beta_ci_upper_90 = apply(draws, 2L, stats::quantile, probs = 0.95, na.rm = TRUE, type = contract$quantile_type),
    finite_draws = colSums(is.finite(draws)),
    stringsAsFactors = FALSE
  )
  list(intervals = intervals, draws = draws)
}

g5_mom013_cell_pairs <- function(panel, lookback, target, contract = g5_mom013_contract()) {
  l_i <- match(as.integer(lookback), contract$lookback_grid)
  h_i <- match(as.integer(target), contract$target_grid)
  if (is.na(l_i) || is.na(h_i)) g5_mom013_stop("Requested cell is outside the frozen grid.")
  data.frame(
    anchor_date = panel$anchor_date,
    entry_date = panel$entry_date,
    outcome_date = panel$bars$session_date[panel$anchor_index + 1L + target],
    lookback_sessions = as.integer(lookback),
    target_sessions = as.integer(target),
    predictor_log_return = panel$x[, l_i],
    target_log_return = panel$y[, h_i],
    stringsAsFactors = FALSE
  )
}

g5_mom013_quintiles <- function(pairs) {
  breaks <- stats::quantile(
    pairs$predictor_log_return,
    probs = seq(0, 1, 0.2), names = FALSE, type = 7
  )
  breaks <- unique(breaks)
  if (length(breaks) < 6L) g5_mom013_stop("Predictor quintiles are not distinct.")
  quintile <- cut(
    pairs$predictor_log_return, breaks = breaks,
    include.lowest = TRUE, labels = paste0("Q", 1:5)
  )
  groups <- split(pairs, quintile)
  do.call(rbind, lapply(names(groups), function(id) {
    x <- groups[[id]]
    data.frame(
      quintile = id,
      anchor_count = nrow(x),
      predictor_min = min(x$predictor_log_return),
      predictor_max = max(x$predictor_log_return),
      mean_target_log_return = mean(x$target_log_return),
      median_target_log_return = stats::median(x$target_log_return),
      positive_target_frequency = mean(x$target_log_return > 0),
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom013_sign_confusion <- function(pairs) {
  predicted <- factor(ifelse(pairs$predictor_log_return > 0, "UP", "DOWN"), levels = c("UP", "DOWN"))
  actual <- factor(ifelse(pairs$target_log_return > 0, "UP", "DOWN"), levels = c("UP", "DOWN"))
  tab <- as.data.frame.matrix(table(predicted = predicted, actual = actual))
  tab$predicted <- rownames(tab)
  rownames(tab) <- NULL
  tab[, c("predicted", "UP", "DOWN"), drop = FALSE]
}

g5_mom013_year_summary <- function(pairs) {
  groups <- split(pairs, format(pairs$anchor_date, "%Y"))
  do.call(rbind, lapply(names(groups), function(year_id) {
    x <- groups[[year_id]]
    stats <- g5_mom013_cell_statistics(
      x$predictor_log_return, x$target_log_return,
      unique(x$lookback_sessions), unique(x$target_sessions)
    )
    data.frame(calendar_year = year_id, stats, stringsAsFactors = FALSE)
  }))
}

g5_mom013_phase_offsets <- function(pairs) {
  h <- unique(pairs$target_sessions)
  do.call(rbind, lapply(0:(h - 1L), function(offset) {
    x <- pairs[seq.int(offset + 1L, nrow(pairs), by = h), , drop = FALSE]
    stats <- g5_mom013_cell_statistics(
      x$predictor_log_return, x$target_log_return,
      unique(x$lookback_sessions), h
    )
    data.frame(phase_offset = offset, stats, stringsAsFactors = FALSE)
  }))
}

g5_mom013_neighbor_cells <- function(surface, nominee, contract = g5_mom013_contract()) {
  if (!nrow(nominee)) return(surface[FALSE, , drop = FALSE])
  l_i <- match(nominee$lookback_sessions, contract$lookback_grid)
  h_i <- match(nominee$target_sessions, contract$target_grid)
  l_keep <- contract$lookback_grid[pmax(1L, l_i - 1L):pmin(length(contract$lookback_grid), l_i + 1L)]
  h_keep <- contract$target_grid[pmax(1L, h_i - 1L):pmin(length(contract$target_grid), h_i + 1L)]
  out <- surface[surface$lookback_sessions %in% l_keep & surface$target_sessions %in% h_keep, , drop = FALSE]
  out$is_nominee <- out$cell_id == nominee$cell_id
  out
}

g5_mom013_run_sandbox <- function(bars, contract = g5_mom013_contract()) {
  contract <- g5_mom013_validate_contract(contract)
  panel <- g5_mom013_common_panel(bars, contract)
  surface <- g5_mom013_surface(panel, contract)
  if (nrow(surface) != 28L || anyDuplicated(surface$cell_id)) {
    g5_mom013_stop("Frozen 28-cell surface is incomplete or duplicated.")
  }
  shift <- g5_mom013_shift_control(panel, surface, contract)
  nominee <- g5_mom013_nominate(surface, shift$decision$passed)
  bootstrap <- g5_mom013_bootstrap(panel, contract)
  surface <- merge(surface, bootstrap$intervals, by = "cell_id", all.x = TRUE, sort = FALSE)
  surface <- surface[order(surface$lookback_sessions, surface$target_sessions), , drop = FALSE]
  canonical <- surface[surface$is_canonical_250_25, , drop = FALSE]
  if (nrow(canonical) != 1L) g5_mom013_stop("Canonical 250/25 row is missing.")
  if (nrow(nominee)) {
    nominee <- surface[surface$cell_id == nominee$cell_id, , drop = FALSE]
    nominee$selection_rule <- "max_positive_correlation;tie_shorter_H_then_shorter_L"
    nominee$confirmation_opened <- FALSE
    pairs <- g5_mom013_cell_pairs(
      panel, nominee$lookback_sessions, nominee$target_sessions, contract
    )
    quintiles <- g5_mom013_quintiles(pairs)
    sign_confusion <- g5_mom013_sign_confusion(pairs)
    years <- g5_mom013_year_summary(pairs)
    phases <- g5_mom013_phase_offsets(pairs)
    neighbors <- g5_mom013_neighbor_cells(surface, nominee, contract)
  } else {
    pairs <- data.frame()
    quintiles <- data.frame()
    sign_confusion <- data.frame()
    years <- data.frame()
    phases <- data.frame()
    neighbors <- data.frame()
  }
  status <- if (isTRUE(shift$decision$passed)) {
    "SANDBOX_SEARCH_ADJUSTED_SURFACE_PASS_NOMINEE_FROZEN_CONFIRMATION_CLOSED"
  } else {
    "STOP_LIT_MOM_01_3_SANDBOX_NO_SEARCH_ADJUSTED_PREDICTIVE_SURFACE"
  }
  list(
    contract = contract,
    panel = panel,
    surface = surface,
    shift_distribution = shift$distribution,
    decision = shift$decision,
    nominee = nominee,
    canonical = canonical,
    nominee_pairs = pairs,
    nominee_quintiles = quintiles,
    nominee_sign_confusion = sign_confusion,
    nominee_years = years,
    nominee_phase_offsets = phases,
    nominee_neighbors = neighbors,
    overall_status = status,
    confirmation_opened = FALSE
  )
}
