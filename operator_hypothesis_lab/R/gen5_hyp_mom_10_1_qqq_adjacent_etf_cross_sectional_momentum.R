# Frozen HYP-MOM-10.1 QQQ-adjacent ETF cross-sectional momentum helpers.

g5_hm101_stop <- function(message) stop(message, call. = FALSE)

g5_hm101_schema_version <- function() "gen5_hyp_mom_10_1_v1"

g5_hm101_contract <- function() {
  list(
    hypothesis_id = "HYP-MOM-10.1",
    descriptive_name = "QQQ-Adjacent ETF Cross-Sectional Momentum",
    universe = data.frame(
      symbol = c("QQQ", "VUG", "IWF", "IUSG", "XLK", "VGT", "IYW", "SMH", "SOXX", "XSD", "IBB", "XBI"),
      sleeve = c(rep("broad_growth", 4L), rep("broad_technology", 3L), rep("semiconductors", 3L), rep("biotech_innovation", 2L)),
      stringsAsFactors = FALSE
    ),
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
    top_bottom_count = 3L,
    circular_shift_minimum = 60L,
    surface_percentile = 0.90,
    quantile_type = 7L,
    random_rank_count = 1000L,
    random_rank_seed = 1006101L,
    bootstrap_count = 10000L,
    bootstrap_expected_block = 20,
    bootstrap_seed = 1010101L,
    development_probability_gate = 0.90,
    minimum_train_dates = 900L,
    minimum_development_dates = 600L
  )
}

g5_hm101_validate_contract <- function(contract = g5_hm101_contract()) {
  frozen <- g5_hm101_contract()
  if (!identical(names(contract), names(frozen))) g5_hm101_stop("Frozen HYP-MOM-10.1 field set changed.")
  same <- vapply(names(frozen), function(field) identical(contract[[field]], frozen[[field]]), logical(1))
  if (!all(same)) g5_hm101_stop(paste("Frozen HYP-MOM-10.1 contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  contract
}

g5_hm101_validate_bars <- function(bars, maximum_allowed_date, contract = g5_hm101_contract()) {
  contract <- g5_hm101_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_hm101_stop(paste("Missing bar columns:", paste(missing, collapse = ", ")))
  x <- bars[bars$symbol %in% contract$universe$symbol, required, drop = FALSE]
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  numeric_fields <- c("open", "high", "low", "close", "volume")
  x[numeric_fields] <- lapply(x[numeric_fields], as.numeric)
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  expected <- contract$universe$symbol
  key <- paste(x$symbol, x$session_date)
  groups <- split(x$session_date, x$symbol)
  strict <- all(vapply(groups, function(d) length(d) > 1L && all(diff(d) > 0), logical(1)))
  finite_positive <- nrow(x) > 0L && all(is.finite(as.matrix(x[numeric_fields]))) && all(as.matrix(x[numeric_fields]) > 0)
  checks <- data.frame(
    check_id = c("exact_frozen_symbols", "unique_symbol_sessions", "strict_symbol_date_order", "positive_finite_ohlcv", "adjusted_daily_only", "query_start_coverage", "maximum_date_seal"),
    passed = c(
      setequal(unique(x$symbol), expected),
      !anyDuplicated(key),
      strict,
      finite_positive,
      nrow(x) > 0L && all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      all(vapply(groups[expected], function(d) min(d) <= contract$train_start - max(contract$lookback_grid), logical(1))),
      nrow(x) > 0L && max(x$session_date) <= as.Date(maximum_allowed_date)
    ),
    observed = c(
      paste(sort(unique(x$symbol)), collapse = ","),
      as.character(sum(duplicated(key))),
      as.character(strict),
      if (nrow(x)) paste(range(as.matrix(x[numeric_fields])), collapse = " to ") else "none",
      paste(unique(paste(x$adjusted, x$timeframe, sep = "/")), collapse = ","),
      paste(vapply(groups[expected], function(d) as.character(min(d)), character(1)), collapse = ";"),
      if (nrow(x)) as.character(max(x$session_date)) else "none"
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) g5_hm101_stop(paste("HYP-MOM-10.1 bar validation failed:", paste(checks$check_id[!checks$passed], collapse = ", ")))
  list(bars = x, checks = checks)
}

g5_hm101_wide <- function(x, field, symbols, dates) {
  out <- matrix(NA_real_, nrow = length(dates), ncol = length(symbols), dimnames = list(as.character(dates), symbols))
  row_i <- match(as.character(x$session_date), as.character(dates))
  col_i <- match(x$symbol, symbols)
  out[cbind(row_i, col_i)] <- as.numeric(x[[field]])
  out
}

g5_hm101_center_rows <- function(matrix) matrix - rowMeans(matrix)

g5_hm101_rank_rows <- function(matrix) {
  t(apply(matrix, 1L, rank, ties.method = "average"))
}

g5_hm101_row_rank_ic <- function(x_rank, y_rank) {
  xc <- x_rank - rowMeans(x_rank)
  yc <- y_rank - rowMeans(y_rank)
  numerator <- rowSums(xc * yc)
  denominator <- sqrt(rowSums(xc^2) * rowSums(yc^2))
  numerator / denominator
}

g5_hm101_top_bottom <- function(x, y, k) {
  vapply(seq_len(nrow(x)), function(i) {
    ord <- order(x[i, ], decreasing = TRUE)
    mean(y[i, ord[seq_len(k)]]) - mean(y[i, tail(ord, k)])
  }, numeric(1))
}

g5_hm101_zone_panel <- function(bars, zone_start, zone_end, minimum_dates, maximum_allowed_date = zone_end, contract = g5_hm101_contract()) {
  checked <- g5_hm101_validate_bars(bars, maximum_allowed_date, contract)
  x <- checked$bars
  symbols <- contract$universe$symbol
  calendars <- split(x$session_date, x$symbol)
  common_dates <- Reduce(intersect, calendars[symbols])
  common_dates <- sort(as.Date(common_dates, origin = "1970-01-01"))
  close <- g5_hm101_wide(x, "close", symbols, common_dates)
  open <- g5_hm101_wide(x, "open", symbols, common_dates)
  if (!all(is.finite(close)) || !all(is.finite(open))) g5_hm101_stop("Nonfinite common price matrix.")
  max_l <- max(contract$lookback_grid)
  max_h <- max(contract$target_grid)
  index <- seq_along(common_dates)
  anchor <- index[index > max_l & index + 1L + max_h <= length(index) & common_dates >= as.Date(zone_start)]
  anchor <- anchor[common_dates[anchor + 1L + max_h] <= as.Date(zone_end)]
  if (length(anchor) < as.integer(minimum_dates)) g5_hm101_stop(paste("Insufficient common dates:", length(anchor)))
  raw_x <- lapply(contract$lookback_grid, function(l) log(close[anchor, , drop = FALSE] / close[anchor - l, , drop = FALSE]))
  relative_x <- lapply(raw_x, g5_hm101_center_rows)
  raw_y <- lapply(contract$target_grid, function(h) log(open[anchor + 1L + h, , drop = FALSE] / open[anchor + 1L, , drop = FALSE]))
  relative_y <- lapply(raw_y, g5_hm101_center_rows)
  predictor_rank <- lapply(relative_x, g5_hm101_rank_rows)
  target_rank <- lapply(relative_y, g5_hm101_rank_rows)
  all_matrices <- c(raw_x, relative_x, raw_y, relative_y, predictor_rank, target_rank)
  if (!all(vapply(all_matrices, function(z) all(is.finite(z)), logical(1)))) g5_hm101_stop("Nonfinite feature or target matrix.")
  list(
    integrity = checked$checks,
    symbols = symbols,
    sleeves = setNames(contract$universe$sleeve, contract$universe$symbol),
    common_dates = common_dates,
    anchor_index = anchor,
    anchor_date = common_dates[anchor],
    entry_date = common_dates[anchor + 1L],
    maximum_exit_date = common_dates[anchor + 1L + max_h],
    raw_x = raw_x,
    relative_x = relative_x,
    raw_y = raw_y,
    relative_y = relative_y,
    predictor_rank = predictor_rank,
    target_rank = target_rank,
    close = close
  )
}

g5_hm101_leave_one_sleeve <- function(x_rank, y_rank, sleeves) {
  omitted <- unique(unname(sleeves))
  data.frame(
    omitted_sleeve = omitted,
    mean_rank_ic = vapply(omitted, function(s) {
      keep <- sleeves != s
      mean(g5_hm101_row_rank_ic(x_rank[, keep, drop = FALSE], y_rank[, keep, drop = FALSE]))
    }, numeric(1)),
    stringsAsFactors = FALSE
  )
}

g5_hm101_cell_statistics <- function(panel, l_i, h_i, contract = g5_hm101_contract()) {
  x <- panel$relative_x[[l_i]]
  y <- panel$relative_y[[h_i]]
  daily_ic <- g5_hm101_row_rank_ic(panel$predictor_rank[[l_i]], panel$target_rank[[h_i]])
  spread <- g5_hm101_top_bottom(x, y, contract$top_bottom_count)
  loo <- g5_hm101_leave_one_sleeve(panel$predictor_rank[[l_i]], panel$target_rank[[h_i]], panel$sleeves)
  data.frame(
    cell_id = paste0("L", contract$lookback_grid[[l_i]], "_H", contract$target_grid[[h_i]]),
    lookback_sessions = contract$lookback_grid[[l_i]],
    target_sessions = contract$target_grid[[h_i]],
    anchor_dates = nrow(x),
    asset_date_rows = length(x),
    mean_daily_rank_ic = mean(daily_ic),
    positive_daily_ic_fraction = mean(daily_ic > 0),
    pooled_pearson = stats::cor(as.vector(x), as.vector(y)),
    mean_top_minus_bottom = mean(spread),
    positive_top_minus_bottom_fraction = mean(spread > 0),
    minimum_leave_one_sleeve_out_ic = min(loo$mean_rank_ic),
    stringsAsFactors = FALSE
  )
}

g5_hm101_surface <- function(panel, contract = g5_hm101_contract()) {
  rows <- list(); i <- 1L
  for (l_i in seq_along(contract$lookback_grid)) for (h_i in seq_along(contract$target_grid)) {
    rows[[i]] <- g5_hm101_cell_statistics(panel, l_i, h_i, contract); i <- i + 1L
  }
  out <- do.call(rbind, rows)
  if (nrow(out) != 9L || anyDuplicated(out$cell_id)) g5_hm101_stop("Frozen HYP-MOM-10.1 surface is incomplete.")
  out
}

g5_hm101_rotate_rows <- function(matrix, shift) {
  n <- nrow(matrix)
  matrix[((seq_len(n) - 1L + as.integer(shift)) %% n) + 1L, , drop = FALSE]
}

g5_hm101_admissible_shifts <- function(n, minimum_displacement) {
  shifts <- seq_len(n - 1L)
  shifts[pmin(shifts, n - shifts) >= as.integer(minimum_displacement)]
}

g5_hm101_shift_test <- function(panel, surface, contract = g5_hm101_contract()) {
  n <- length(panel$anchor_date)
  shifts <- g5_hm101_admissible_shifts(n, contract$circular_shift_minimum)
  maxima <- vapply(shifts, function(shift) {
    max(vapply(seq_along(contract$lookback_grid), function(l_i) {
      max(vapply(seq_along(contract$target_grid), function(h_i) {
        shifted <- g5_hm101_rotate_rows(panel$target_rank[[h_i]], shift)
        mean(g5_hm101_row_rank_ic(panel$predictor_rank[[l_i]], shifted))
      }, numeric(1)))
    }, numeric(1)))
  }, numeric(1))
  threshold <- as.numeric(stats::quantile(maxima, contract$surface_percentile, type = contract$quantile_type, names = FALSE))
  best <- surface[order(-surface$mean_daily_rank_ic, surface$target_sessions, surface$lookback_sessions), , drop = FALSE][1L, ]
  passed <- n >= contract$minimum_train_dates && best$mean_daily_rank_ic > threshold && best$mean_top_minus_bottom > 0 && best$minimum_leave_one_sleeve_out_ic > 0
  distribution <- data.frame(shift = shifts, circular_displacement = pmin(shifts, n - shifts), maximum_mean_daily_rank_ic = maxima, stringsAsFactors = FALSE)
  decision <- data.frame(
    observed_maximum_mean_daily_rank_ic = best$mean_daily_rank_ic,
    shift_maximum_p90 = threshold,
    empirical_upper_tail_probability = (1 + sum(maxima >= best$mean_daily_rank_ic)) / (1 + length(maxima)),
    best_mean_top_minus_bottom = best$mean_top_minus_bottom,
    best_minimum_leave_one_sleeve_out_ic = best$minimum_leave_one_sleeve_out_ic,
    eligible_shift_count = length(shifts),
    passed = passed,
    status = if (passed) "TRAIN_RANKING_SEARCH_ADJUSTED_PASS" else "STOP_HYP_MOM_10_1_NO_SEARCH_ADJUSTED_TRAIN_RANKING",
    stringsAsFactors = FALSE
  )
  list(distribution = distribution, decision = decision, best = best)
}

g5_hm101_nominate <- function(surface, passed) {
  if (!isTRUE(passed)) return(surface[FALSE, , drop = FALSE])
  surface[order(-surface$mean_daily_rank_ic, surface$target_sessions, surface$lookback_sessions), , drop = FALSE][1L, ]
}

g5_hm101_cell_indices <- function(contract, lookback, target) {
  list(l_i = match(as.integer(lookback), contract$lookback_grid), h_i = match(as.integer(target), contract$target_grid))
}

g5_hm101_random_rank_control <- function(panel, cell, contract = g5_hm101_contract()) {
  idx <- g5_hm101_cell_indices(contract, cell$lookback_sessions[[1L]], cell$target_sessions[[1L]])
  y <- panel$relative_y[[idx$h_i]]
  n <- nrow(y); p <- ncol(y); k <- contract$top_bottom_count
  set.seed(contract$random_rank_seed)
  observed <- mean(g5_hm101_top_bottom(panel$relative_x[[idx$l_i]], y, k))
  random <- vapply(seq_len(contract$random_rank_count), function(rep_i) {
    spreads <- vapply(seq_len(n), function(i) {
      ord <- sample.int(p)
      mean(y[i, ord[seq_len(k)]]) - mean(y[i, tail(ord, k)])
    }, numeric(1))
    mean(spreads)
  }, numeric(1))
  data.frame(
    replicate = seq_along(random),
    randomized_mean_top_minus_bottom = random,
    observed_mean_top_minus_bottom = observed,
    random_p90 = as.numeric(stats::quantile(random, 0.90, type = contract$quantile_type, names = FALSE)),
    empirical_upper_tail_probability = (1 + sum(random >= observed)) / (1 + length(random)),
    stringsAsFactors = FALSE
  )
}

g5_hm101_sleeve_diagnostic <- function(panel, cell, contract = g5_hm101_contract()) {
  idx <- g5_hm101_cell_indices(contract, cell$lookback_sessions[[1L]], cell$target_sessions[[1L]])
  g5_hm101_leave_one_sleeve(panel$predictor_rank[[idx$l_i]], panel$target_rank[[idx$h_i]], panel$sleeves)
}

g5_hm101_overlap_diagnostic <- function(panel, contract = g5_hm101_contract()) {
  dates <- panel$common_dates
  close <- panel$close
  keep <- dates >= contract$train_start & dates <= contract$train_end
  close <- close[keep, , drop = FALSE]
  returns <- log(close[-1L, , drop = FALSE] / close[-nrow(close), , drop = FALSE])
  correlation <- stats::cor(returns)
  pairs <- which(upper.tri(correlation), arr.ind = TRUE)
  data.frame(
    symbol_1 = colnames(correlation)[pairs[, 1L]],
    symbol_2 = colnames(correlation)[pairs[, 2L]],
    sleeve_1 = unname(panel$sleeves[colnames(correlation)[pairs[, 1L]]]),
    sleeve_2 = unname(panel$sleeves[colnames(correlation)[pairs[, 2L]]]),
    daily_return_correlation = correlation[pairs],
    stringsAsFactors = FALSE
  )
}

g5_hm101_cell_rows <- function(panel, cell, contract = g5_hm101_contract()) {
  idx <- g5_hm101_cell_indices(contract, cell$lookback_sessions[[1L]], cell$target_sessions[[1L]])
  n <- length(panel$anchor_date); p <- length(panel$symbols)
  data.frame(
    anchor_date = rep(panel$anchor_date, each = p),
    symbol = rep(panel$symbols, times = n),
    sleeve = rep(unname(panel$sleeves[panel$symbols]), times = n),
    raw_x = as.vector(t(panel$raw_x[[idx$l_i]])),
    relative_x = as.vector(t(panel$relative_x[[idx$l_i]])),
    relative_y = as.vector(t(panel$relative_y[[idx$h_i]])),
    stringsAsFactors = FALSE
  )
}

g5_hm101_fit_models <- function(train_rows, development_rows) {
  specifications <- list(DRIFT = character(), RAW_RETURN = "raw_x", RELATIVE_SCORE = "relative_x")
  do.call(rbind, lapply(names(specifications), function(model_id) {
    fields <- specifications[[model_id]]
    train_x <- cbind(1, if (length(fields)) as.matrix(train_rows[fields]) else NULL)
    fit <- stats::lm.fit(train_x, train_rows$relative_y)
    dev_x <- cbind(1, if (length(fields)) as.matrix(development_rows[fields]) else NULL)
    prediction <- as.vector(dev_x %*% fit$coefficients)
    data.frame(model_id = model_id, development_mse = mean((development_rows$relative_y - prediction)^2), development_mae = mean(abs(development_rows$relative_y - prediction)), stringsAsFactors = FALSE)
  }))
}

g5_hm101_stationary_indices <- function(n, expected_block) {
  out <- integer(n); out[[1L]] <- sample.int(n, 1L)
  restart_probability <- 1 / expected_block
  if (n > 1L) for (i in 2:n) out[[i]] <- if (stats::runif(1) < restart_probability) sample.int(n, 1L) else (out[[i - 1L]] %% n) + 1L
  out
}

g5_hm101_bootstrap_ic <- function(daily_ic, contract = g5_hm101_contract()) {
  set.seed(contract$bootstrap_seed)
  values <- replicate(contract$bootstrap_count, mean(daily_ic[g5_hm101_stationary_indices(length(daily_ic), contract$bootstrap_expected_block)]))
  data.frame(
    replicate_count = contract$bootstrap_count,
    probability_positive = mean(values > 0),
    lower_90 = as.numeric(stats::quantile(values, 0.05, type = contract$quantile_type, names = FALSE)),
    upper_90 = as.numeric(stats::quantile(values, 0.95, type = contract$quantile_type, names = FALSE)),
    stringsAsFactors = FALSE
  )
}

g5_hm101_run_train <- function(bars, contract = g5_hm101_contract()) {
  panel <- g5_hm101_zone_panel(bars, contract$train_start, contract$train_end, contract$minimum_train_dates, contract$train_end, contract)
  surface <- g5_hm101_surface(panel, contract)
  shift <- g5_hm101_shift_test(panel, surface, contract)
  nominee <- g5_hm101_nominate(surface, shift$decision$passed[[1L]])
  random <- g5_hm101_random_rank_control(panel, shift$best, contract)
  list(panel = panel, surface = surface, shift_distribution = shift$distribution, decision = shift$decision, best = shift$best, nominee = nominee, randomized_rank = random, sleeve_diagnostic = g5_hm101_sleeve_diagnostic(panel, shift$best, contract), overlap = g5_hm101_overlap_diagnostic(panel, contract), overall_status = shift$decision$status[[1L]])
}

g5_hm101_run_development <- function(train_bars, development_bars, nominee, contract = g5_hm101_contract()) {
  if (!nrow(nominee)) g5_hm101_stop("DEVELOPMENT requires one frozen TRAIN nominee.")
  train <- g5_hm101_zone_panel(train_bars, contract$train_start, contract$train_end, contract$minimum_train_dates, contract$train_end, contract)
  development <- g5_hm101_zone_panel(development_bars, contract$development_start, contract$development_end, contract$minimum_development_dates, contract$development_end, contract)
  idx <- g5_hm101_cell_indices(contract, nominee$lookback_sessions[[1L]], nominee$target_sessions[[1L]])
  daily_ic <- g5_hm101_row_rank_ic(development$predictor_rank[[idx$l_i]], development$target_rank[[idx$h_i]])
  spread <- g5_hm101_top_bottom(development$relative_x[[idx$l_i]], development$relative_y[[idx$h_i]], contract$top_bottom_count)
  loo <- g5_hm101_sleeve_diagnostic(development, nominee, contract)
  models <- g5_hm101_fit_models(g5_hm101_cell_rows(train, nominee, contract), g5_hm101_cell_rows(development, nominee, contract))
  bootstrap <- g5_hm101_bootstrap_ic(daily_ic, contract)
  relative_mse <- models$development_mse[models$model_id == "RELATIVE_SCORE"]
  pass <- c(
    length(daily_ic) >= contract$minimum_development_dates,
    mean(daily_ic) > 0,
    bootstrap$probability_positive[[1L]] >= contract$development_probability_gate,
    mean(spread) > 0,
    all(relative_mse < models$development_mse[models$model_id %in% c("DRIFT", "RAW_RETURN")]),
    all(loo$mean_rank_ic > 0)
  )
  gates <- data.frame(
    gate_id = paste0("DEV_G", seq_along(pass)),
    gate = c("Minimum DEVELOPMENT dates", "Positive mean daily rank IC", "Bootstrap probability positive", "Positive top-minus-bottom ordering", "Relative score beats drift and raw return", "Every leave-one-sleeve-out IC positive"),
    passed = pass,
    status = ifelse(pass, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
  list(
    panel = development,
    mean_daily_rank_ic = mean(daily_ic),
    positive_daily_ic_fraction = mean(daily_ic > 0),
    mean_top_minus_bottom = mean(spread),
    bootstrap = bootstrap,
    models = models,
    sleeve_diagnostic = loo,
    gates = gates,
    overall_status = if (all(pass)) "DEVELOPMENT_PASS_HYP_MOM_10_1_CONFIRMATION_REVIEW_REQUIRED" else "STOP_HYP_MOM_10_1_DEVELOPMENT_RANKING_GATES_FAILED"
  )
}
