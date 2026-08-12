# Causal TRAIN-only feature-atlas engine for HYP-MOM-04.2.
# Source hyp_mom_04_1_engine.R before this file.

h042_stop <- function(message) stop(message, call. = FALSE)

h042_feature_dictionary <- function() {
  data.frame(
    feature = c(
      "ret21", "ret63", "ret126", "ret252", "momentum12_1",
      "momentum_accel63_126", "positive_month_fraction12",
      "slope63_atr", "slow_slope_atr", "trend_r2_63", "efficiency63", "efficiency126",
      "ma50_200_atr", "price_sma50_atr", "price_sma200_atr",
      "high_proximity63", "high_proximity252",
      "current_drawdown252", "max_drawdown126", "recovery_from_low252", "extension20",
      "rv20", "rv126", "volatility_ratio", "downside_vol63", "atr20_pct",
      "volume_ratio20_126", "up_volume_share63", "price_volume_corr63",
      "beta126", "market_relative126", "residual_momentum126", "sector_relative126"
    ),
    family = c(
      rep("MOMENTUM_LEVEL", 7), rep("TREND_QUALITY", 5), rep("TREND_STATE_BREAKOUT", 5),
      rep("PATH_DRAWDOWN", 4), rep("RISK", 5), rep("PARTICIPATION", 3),
      rep("RELATIVE_STRENGTH", 4)
    ),
    plain_english = c(
      "One-month return", "Three-month return", "Six-month return", "Twelve-month return",
      "Twelve-to-one-month momentum", "Recent three-month return minus the preceding three months",
      "Fraction of twelve 21-session blocks with positive return",
      "63-session price-regression rise scaled by ATR", "20-session change in SMA200 scaled by ATR",
      "R-squared of the 63-session log-price trend", "63-session path efficiency",
      "126-session path efficiency", "SMA50 minus SMA200 scaled by ATR",
      "Price minus SMA50 scaled by ATR", "Price minus SMA200 scaled by ATR",
      "Price divided by 63-session high", "Price divided by 252-session high",
      "Current drawdown from the 252-session high", "Worst peak-to-trough drawdown in 126 sessions",
      "Recovery above the 252-session low", "20-session log-price z-score",
      "Annualized 20-session realized volatility", "Annualized 126-session realized volatility",
      "20-session volatility divided by 126-session volatility", "Annualized downside volatility over 63 sessions",
      "ATR20 divided by price", "Recent 20-session volume divided by 126-session volume",
      "Share of 63-session volume occurring on positive-return days",
      "Correlation of daily return with log-volume change over 63 sessions",
      "126-session beta to SPY", "Six-month return minus SPY six-month return",
      "Six-month return residualized by beta times SPY return",
      "Six-month return minus same-sector mean"
    ),
    stringsAsFactors = FALSE
  )
}

h042_baskets <- function() {
  list(
    RIDGE_ORIGINAL_6 = c("momentum12_1", "sector_relative126", "slow_slope_atr",
                         "extension20", "volatility_ratio", "high_proximity252"),
    RIDGE_MOMENTUM_LEVEL = c("ret21", "ret63", "ret126", "ret252", "momentum12_1",
                              "momentum_accel63_126", "positive_month_fraction12"),
    RIDGE_TREND_QUALITY = c("slope63_atr", "slow_slope_atr", "trend_r2_63",
                             "efficiency63", "efficiency126", "positive_month_fraction12"),
    RIDGE_RELATIVE_STRENGTH = c("market_relative126", "sector_relative126",
                                 "residual_momentum126", "momentum12_1"),
    RIDGE_BREAKOUT_STATE = c("price_sma50_atr", "price_sma200_atr", "ma50_200_atr",
                              "high_proximity63", "high_proximity252", "current_drawdown252"),
    RIDGE_RISK_PATH = c("momentum12_1", "volatility_ratio", "downside_vol63", "atr20_pct",
                         "current_drawdown252", "max_drawdown126"),
    RIDGE_PARTICIPATION = c("ret126", "volume_ratio20_126", "up_volume_share63",
                             "price_volume_corr63"),
    RIDGE_DIVERSE_CORE = c("momentum12_1", "sector_relative126", "trend_r2_63",
                            "efficiency63", "current_drawdown252", "volatility_ratio",
                            "volume_ratio20_126"),
    FIXED_THEORY_CORE = c("market_relative126", "sector_relative126", "momentum12_1",
                           "slope63_atr", "efficiency63", "positive_month_fraction12",
                           "current_drawdown252", "volatility_ratio")
  )
}

h042_contract <- function() {
  signs <- c(
    market_relative126 = 1, sector_relative126 = 1, momentum12_1 = 1,
    slope63_atr = 1, efficiency63 = 1, positive_month_fraction12 = 1,
    current_drawdown252 = 1, volatility_ratio = -1
  )
  list(
    program_id = "HYP-MOM-04.2",
    as_of_timestamp = "2026-08-07 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    train_query_end = as.Date("2020-12-31"),
    forbidden_start = as.Date("2021-01-01"),
    train_signal_quarters = paste0(rep(2017:2020, each = 4), "Q", rep(1:4, 4))[1:15],
    feature_names = h042_feature_dictionary()$feature,
    baskets = h042_baskets(),
    fixed_theory_signs = signs,
    lambdas = c(0.01, 0.1, 1, 10, 100),
    outer_train_quarters = c(9L, 12L),
    validation_quarters = 3L,
    inner_min_train_quarters = 6L,
    redundancy_threshold = 0.85,
    minimum_assets = 400L,
    minimum_assets_per_quarter = 20L,
    minimum_sector_members = 3L,
    permutation_draws = 200L,
    random_seed = 20260811L
  )
}

h042_validate_contract <- function(contract = h042_contract()) {
  frozen <- h042_contract()
  if (!identical(names(contract), names(frozen))) h042_stop("Frozen HYP-MOM-04.2 contract fields changed.")
  same <- vapply(names(frozen), function(name) identical(contract[[name]], frozen[[name]]), logical(1))
  if (!all(same)) h042_stop(paste("Frozen HYP-MOM-04.2 contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  dictionary <- h042_feature_dictionary()
  if (anyDuplicated(dictionary$feature) || !identical(contract$feature_names, dictionary$feature)) {
    h042_stop("Feature dictionary does not match the frozen feature order.")
  }
  basket_features <- unique(unlist(contract$baskets, use.names = FALSE))
  if (length(setdiff(basket_features, contract$feature_names))) h042_stop("Basket contains an unregistered feature.")
  contract
}

h042_candidate_registry <- function(contract = h042_contract()) {
  h042_validate_contract(contract)
  data.frame(
    candidate = names(contract$baskets),
    method = ifelse(names(contract$baskets) == "FIXED_THEORY_CORE", "FIXED_SIGN", "RIDGE"),
    feature_count = lengths(contract$baskets),
    features = vapply(contract$baskets, paste, collapse = "|", character(1)),
    stringsAsFactors = FALSE
  )
}

h042_safe_divide <- function(numerator, denominator) {
  if (!is.finite(numerator) || !is.finite(denominator) || denominator == 0) return(NA_real_)
  numerator / denominator
}

h042_efficiency <- function(close, start_index, end_index) {
  path <- close[start_index:end_index]
  h042_safe_divide(abs(tail(path, 1L) - head(path, 1L)), sum(abs(diff(path))))
}

h042_max_drawdown <- function(close) {
  running_high <- cummax(close)
  min(close / running_high - 1)
}

h042_regression_stats <- function(close) {
  y <- log(close)
  x <- seq_along(y)
  x_centered <- x - mean(x)
  y_centered <- y - mean(y)
  slope <- sum(x_centered * y_centered) / sum(x_centered^2)
  residual <- y_centered - slope * x_centered
  total <- sum(y_centered^2)
  r2 <- if (total == 0) 0 else 1 - sum(residual^2) / total
  c(slope = slope, r2 = r2)
}

h042_asset_rows <- function(bars, market_bars, schedule, identity) {
  x <- bars[order(bars$session_date), , drop = FALSE]
  market <- market_bars[match(x$session_date, market_bars$session_date), , drop = FALSE]
  if (anyNA(market$session_date)) h042_stop(paste("SPY calendar mismatch for", identity$symbol))
  tr <- h04_true_range(x$high, x$low, x$close)
  rows <- lapply(seq_len(nrow(schedule)), function(i) {
    s <- schedule[i, , drop = FALSE]
    t <- match(s$signal_date, x$session_date)
    entry <- match(s$entry_date, x$session_date)
    exit <- match(s$exit_date, x$session_date)
    if (anyNA(c(t, entry, exit)) || t < 253L || entry <= t || exit <= entry) return(NULL)

    close <- x$close
    log_close <- log(close)
    ret <- diff(log_close)
    market_ret <- diff(log(market$close))
    atr20 <- mean(tr[(t - 19L):t])
    sma50 <- mean(close[(t - 49L):t])
    sma200 <- mean(close[(t - 199L):t])
    sma200_lag20 <- mean(close[(t - 219L):(t - 20L)])
    ext_window <- log_close[(t - 19L):t]
    reg63 <- h042_regression_stats(close[(t - 62L):t])
    r63 <- ret[(t - 63L):(t - 1L)]
    r126 <- ret[(t - 126L):(t - 1L)]
    mr126 <- market_ret[(t - 126L):(t - 1L)]
    beta126 <- h042_safe_divide(stats::cov(r126, mr126), stats::var(mr126))
    monthly_returns <- vapply(0:11, function(j) log(close[[t - 21L * j]] / close[[t - 21L * (j + 1L)]]), numeric(1))
    recent_return <- log(close[[t]] / close[[t - 63L]])
    prior_return <- log(close[[t - 63L]] / close[[t - 126L]])
    volume_recent <- x$volume[(t - 19L):t]
    volume_long <- x$volume[(t - 125L):t]
    day_volume <- x$volume[(t - 62L):t]
    volume_change <- diff(log1p(x$volume[(t - 63L):t]))
    pv_corr <- if (stats::sd(r63) == 0 || stats::sd(volume_change) == 0) 0 else stats::cor(r63, volume_change)
    spy126 <- log(market$close[[t]] / market$close[[t - 126L]])
    raw126 <- log(close[[t]] / close[[t - 126L]])

    data.frame(
      instance_id = identity$instance_id, symbol = identity$symbol, sector = identity$sector,
      cohort = identity$cohort, signal_quarter = s$signal_quarter, target_quarter = s$target_quarter,
      signal_date = s$signal_date, entry_date = s$entry_date, exit_date = s$exit_date,
      ret21 = log(close[[t]] / close[[t - 21L]]),
      ret63 = recent_return, ret126 = raw126, ret252 = log(close[[t]] / close[[t - 252L]]),
      momentum12_1 = log(close[[t - 21L]] / close[[t - 252L]]),
      momentum_accel63_126 = recent_return - prior_return,
      positive_month_fraction12 = mean(monthly_returns > 0),
      slope63_atr = h042_safe_divide((exp(reg63[["slope"]] * 62) - 1) * close[[t - 62L]], atr20),
      slow_slope_atr = h042_safe_divide(sma200 - sma200_lag20, atr20),
      trend_r2_63 = reg63[["r2"]],
      efficiency63 = h042_efficiency(close, t - 63L, t),
      efficiency126 = h042_efficiency(close, t - 126L, t),
      ma50_200_atr = h042_safe_divide(sma50 - sma200, atr20),
      price_sma50_atr = h042_safe_divide(close[[t]] - sma50, atr20),
      price_sma200_atr = h042_safe_divide(close[[t]] - sma200, atr20),
      high_proximity63 = close[[t]] / max(close[(t - 62L):t]),
      high_proximity252 = close[[t]] / max(close[(t - 251L):t]),
      current_drawdown252 = close[[t]] / max(close[(t - 251L):t]) - 1,
      max_drawdown126 = h042_max_drawdown(close[(t - 125L):t]),
      recovery_from_low252 = close[[t]] / min(close[(t - 251L):t]) - 1,
      extension20 = (log_close[[t]] - mean(ext_window)) / stats::sd(ext_window),
      rv20 = stats::sd(ret[(t - 20L):(t - 1L)]) * sqrt(252),
      rv126 = stats::sd(r126) * sqrt(252),
      volatility_ratio = stats::sd(ret[(t - 20L):(t - 1L)]) / stats::sd(r126),
      downside_vol63 = sqrt(mean(pmin(r63, 0)^2)) * sqrt(252),
      atr20_pct = atr20 / close[[t]],
      volume_ratio20_126 = mean(volume_recent) / mean(volume_long),
      up_volume_share63 = h042_safe_divide(sum(day_volume[r63 > 0]), sum(day_volume)),
      price_volume_corr63 = pv_corr,
      beta126 = beta126,
      market_relative126 = raw126 - spy126,
      residual_momentum126 = raw126 - beta126 * spy126,
      return126_raw = raw126,
      entry_open = x$open[[entry]], exit_open = x$open[[exit]],
      target_return = x$open[[exit]] / x$open[[entry]] - 1,
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

h042_build_panel <- function(bars, market_bars, registry, calendar_dates, contract = h042_contract()) {
  contract <- h042_validate_contract(contract)
  old_contract <- h04_contract()
  x <- h04_validate_bars(bars, contract$train_query_end, old_contract)
  market <- h04_validate_bars(market_bars, contract$train_query_end, old_contract)
  registry <- h04_validate_registry(registry, expected_count = NULL)
  schedule <- h04_schedule(calendar_dates, contract$train_signal_quarters)
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    identity <- registry[i, , drop = FALSE]
    h042_asset_rows(x[x$symbol == identity$symbol, , drop = FALSE], market, schedule, identity)
  })
  rows <- Filter(function(z) nrow(z) > 0L, rows)
  if (!length(rows)) h042_stop("No complete HYP-MOM-04.2 feature rows were constructed.")
  panel <- do.call(rbind, rows)
  sector_key <- interaction(panel$signal_quarter, panel$sector, drop = TRUE)
  sector_count <- ave(panel$return126_raw, sector_key, FUN = length)
  panel$sector_relative126 <- panel$return126_raw - ave(panel$return126_raw, sector_key, FUN = mean)
  panel <- panel[sector_count >= contract$minimum_sector_members, , drop = FALSE]
  panel$target_relative_return <- panel$target_return - ave(panel$target_return, panel$signal_quarter, FUN = mean)
  finite <- apply(is.finite(as.matrix(panel[c(contract$feature_names, "target_return", "target_relative_return")])), 1L, all)
  panel <- panel[finite, , drop = FALSE]
  # Center on the final feature-eligible cross-section. Feature eligibility is
  # causal and outcome-blind, but removing a row after the first centering can
  # otherwise leave a small nonzero quarter mean.
  panel$target_relative_return <- panel$target_return - ave(panel$target_return, panel$signal_quarter, FUN = mean)
  for (feature in contract$feature_names) {
    panel[[paste0(feature, "_rn")]] <- ave(panel[[feature]], panel$signal_quarter, FUN = h04_rank_normal)
  }
  panel <- panel[order(match(panel$signal_quarter, contract$train_signal_quarters), panel$symbol), , drop = FALSE]
  rownames(panel) <- NULL
  panel$row_id <- seq_len(nrow(panel))
  panel
}

h042_decile <- function(x) pmin(10L, pmax(1L, ceiling(10 * rank(x, ties.method = "first") / length(x))))

h042_feature_diagnostics <- function(panel, contract = h042_contract()) {
  contract <- h042_validate_contract(contract)
  quarter_rows <- list(); decile_rows <- list(); qk <- 0L; dk <- 0L
  for (feature in contract$feature_names) {
    for (quarter in contract$train_signal_quarters) {
      x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
      value <- x[[feature]]
      decile <- h042_decile(value)
      qk <- qk + 1L
      quarter_rows[[qk]] <- data.frame(
        feature = feature, signal_quarter = quarter, observations = nrow(x),
        rank_ic = h04_spearman(value, x$target_relative_return),
        top_decile_excess = mean(x$target_relative_return[decile == 10L]),
        bottom_decile_excess = mean(x$target_relative_return[decile == 1L]),
        top_minus_bottom = mean(x$target_relative_return[decile == 10L]) - mean(x$target_relative_return[decile == 1L]),
        stringsAsFactors = FALSE
      )
      means <- tapply(x$target_relative_return, decile, mean)
      dk <- dk + 1L
      decile_rows[[dk]] <- data.frame(feature = feature, signal_quarter = quarter,
                                      decile = as.integer(names(means)), mean_relative_return = as.numeric(means),
                                      stringsAsFactors = FALSE)
    }
  }
  quarterly <- do.call(rbind, quarter_rows)
  deciles <- do.call(rbind, decile_rows)
  scorecard <- do.call(rbind, lapply(split(quarterly, quarterly$feature), function(x) {
    data.frame(
      feature = unique(x$feature), mean_rank_ic = mean(x$rank_ic), median_rank_ic = stats::median(x$rank_ic),
      positive_ic_fraction = mean(x$rank_ic > 0), mean_top_decile_excess = mean(x$top_decile_excess),
      mean_top_minus_bottom = mean(x$top_minus_bottom), positive_spread_fraction = mean(x$top_minus_bottom > 0),
      stringsAsFactors = FALSE
    )
  }))
  scorecard <- merge(h042_feature_dictionary(), scorecard, by = "feature", sort = FALSE)
  scorecard <- scorecard[match(contract$feature_names, scorecard$feature), , drop = FALSE]
  rank_columns <- paste0(contract$feature_names, "_rn")
  redundancy <- stats::cor(panel[rank_columns], method = "spearman")
  dimnames(redundancy) <- list(contract$feature_names, contract$feature_names)
  pairs <- which(abs(redundancy) >= contract$redundancy_threshold & upper.tri(redundancy), arr.ind = TRUE)
  redundancy_pairs <- if (nrow(pairs)) data.frame(
    feature_a = rownames(redundancy)[pairs[, 1]], feature_b = colnames(redundancy)[pairs[, 2]],
    rank_correlation = redundancy[pairs], stringsAsFactors = FALSE
  ) else data.frame(feature_a = character(), feature_b = character(), rank_correlation = numeric())
  list(quarterly = quarterly, deciles = deciles, scorecard = scorecard,
       redundancy = redundancy, redundancy_pairs = redundancy_pairs)
}

h042_candidate_score <- function(train, validation, target_train, candidate, lambda,
                                  contract = h042_contract()) {
  features <- contract$baskets[[candidate]]
  columns <- paste0(features, "_rn")
  if (candidate == "FIXED_THEORY_CORE") {
    signs <- contract$fixed_theory_signs[features]
    score <- rowMeans(sweep(as.matrix(validation[columns]), 2L, signs, `*`))
    coefficients <- signs
    return(list(score = score, coefficients = coefficients, lambda = NA_real_))
  }
  scaler <- h04_scaler_fit(train, columns)
  fit <- h04_ridge_fit(h04_scaler_apply(train, columns, scaler), target_train, lambda)
  score <- h04_ridge_predict(fit, h04_scaler_apply(validation, columns, scaler))
  list(score = score, coefficients = fit$coefficients, lambda = lambda)
}

h042_validation_metrics <- function(validation, score, target) {
  quarters <- unique(validation$signal_quarter)
  do.call(rbind, lapply(quarters, function(quarter) {
    local <- validation$signal_quarter == quarter
    quartile <- h04_quartile(score[local])
    data.frame(
      signal_quarter = quarter, observations = sum(local), rank_ic = h04_spearman(score[local], target[local]),
      q4_excess = mean(target[local][quartile == 4L]),
      q4_minus_q1 = mean(target[local][quartile == 4L]) - mean(target[local][quartile == 1L]),
      stringsAsFactors = FALSE
    )
  }))
}

h042_inner_search <- function(panel, target, available_quarters, candidates = names(h042_contract()$baskets),
                              contract = h042_contract()) {
  contract <- h042_validate_contract(contract)
  inner_train_sizes <- seq(contract$inner_min_train_quarters,
                           length(available_quarters) - contract$validation_quarters,
                           by = contract$validation_quarters)
  if (!length(inner_train_sizes)) h042_stop("Outer training window has no admissible inner fold.")
  rows <- list(); k <- 0L
  for (candidate in candidates) {
    lambda_values <- if (candidate == "FIXED_THEORY_CORE") NA_real_ else contract$lambdas
    for (lambda in lambda_values) {
      for (train_size in inner_train_sizes) {
        train_quarters <- available_quarters[seq_len(train_size)]
        validation_quarters <- available_quarters[(train_size + 1L):(train_size + contract$validation_quarters)]
        tr <- panel$signal_quarter %in% train_quarters
        va <- panel$signal_quarter %in% validation_quarters
        fitted <- h042_candidate_score(panel[tr, , drop = FALSE], panel[va, , drop = FALSE], target[tr],
                                       candidate, lambda, contract)
        metrics <- h042_validation_metrics(panel[va, , drop = FALSE], fitted$score, target[va])
        k <- k + 1L
        rows[[k]] <- data.frame(candidate = candidate, lambda = lambda, inner_train_quarters = train_size,
                                metrics, stringsAsFactors = FALSE)
      }
    }
  }
  details <- do.call(rbind, rows)
  key <- interaction(details$candidate, ifelse(is.na(details$lambda), "FIXED", format(details$lambda, scientific = FALSE)), drop = TRUE)
  summary <- do.call(rbind, lapply(split(details, key), function(x) {
    data.frame(candidate = x$candidate[[1L]], lambda = x$lambda[[1L]],
               mean_rank_ic = mean(x$rank_ic), positive_fraction = mean(x$rank_ic > 0),
               validation_quarters = nrow(x), stringsAsFactors = FALSE)
  }))
  registry <- h042_candidate_registry(contract)
  summary <- merge(summary, registry[c("candidate", "method", "feature_count")], by = "candidate", sort = FALSE)
  lambda_tie <- ifelse(is.na(summary$lambda), Inf, summary$lambda)
  selected_index <- order(-summary$mean_rank_ic, summary$feature_count, -lambda_tie, summary$candidate)[[1L]]
  list(details = details, summary = summary, selected = summary[selected_index, , drop = FALSE])
}

h042_nested_outer <- function(panel, target = panel$target_relative_return,
                              candidates = names(h042_contract()$baskets), contract = h042_contract(),
                              retain_inner = TRUE) {
  contract <- h042_validate_contract(contract)
  quarters <- contract$train_signal_quarters
  predictions <- list(); metrics <- list(); coefficients <- list(); selections <- list(); inner <- list()
  for (fold in seq_along(contract$outer_train_quarters)) {
    train_size <- contract$outer_train_quarters[[fold]]
    train_quarters <- quarters[seq_len(train_size)]
    validation_quarters <- quarters[(train_size + 1L):(train_size + contract$validation_quarters)]
    search <- h042_inner_search(panel, target, train_quarters, candidates, contract)
    selected <- search$selected
    candidate <- selected$candidate[[1L]]
    lambda <- selected$lambda[[1L]]
    tr <- panel$signal_quarter %in% train_quarters
    va <- panel$signal_quarter %in% validation_quarters
    fitted <- h042_candidate_score(panel[tr, , drop = FALSE], panel[va, , drop = FALSE], target[tr],
                                   candidate, lambda, contract)
    score <- fitted$score
    quartile <- ave(score, panel$signal_quarter[va], FUN = h04_quartile)
    predictions[[fold]] <- data.frame(
      outer_fold = fold, row_id = panel$row_id[va], signal_quarter = panel$signal_quarter[va],
      symbol = panel$symbol[va], sector = panel$sector[va], candidate = candidate, lambda = lambda,
      score = score, quartile = quartile, target = target[va], stringsAsFactors = FALSE
    )
    fold_metrics <- h042_validation_metrics(panel[va, , drop = FALSE], score, target[va])
    fold_metrics$outer_fold <- fold; fold_metrics$candidate <- candidate; fold_metrics$lambda <- lambda
    metrics[[fold]] <- fold_metrics
    coefficients[[fold]] <- data.frame(outer_fold = fold, candidate = candidate,
                                        term = names(fitted$coefficients), coefficient = as.numeric(fitted$coefficients),
                                        stringsAsFactors = FALSE)
    selections[[fold]] <- data.frame(outer_fold = fold, outer_train_quarters = train_size,
                                      candidate = candidate, lambda = lambda,
                                      inner_mean_rank_ic = selected$mean_rank_ic,
                                      inner_positive_fraction = selected$positive_fraction,
                                      stringsAsFactors = FALSE)
    if (retain_inner) {
      search$details$outer_fold <- fold; search$summary$outer_fold <- fold
      inner[[fold]] <- search
    }
  }
  list(predictions = do.call(rbind, predictions), metrics = do.call(rbind, metrics),
       coefficients = do.call(rbind, coefficients), selections = do.call(rbind, selections), inner = inner)
}

h042_permutation_search <- function(panel, observed, contract = h042_contract()) {
  contract <- h042_validate_contract(contract)
  set.seed(contract$random_seed)
  observed_stat <- mean(observed$metrics$rank_ic)
  rows <- vector("list", contract$permutation_draws)
  for (i in seq_len(contract$permutation_draws)) {
    permuted <- panel$target_relative_return
    for (quarter in contract$train_signal_quarters) {
      local <- which(panel$signal_quarter == quarter)
      permuted[local] <- sample(permuted[local], length(local), replace = FALSE)
    }
    result <- h042_nested_outer(panel, permuted, contract = contract, retain_inner = FALSE)
    rows[[i]] <- data.frame(
      simulation_id = i, mean_outer_rank_ic = mean(result$metrics$rank_ic),
      positive_fraction = mean(result$metrics$rank_ic > 0),
      selected_fold_1 = result$selections$candidate[[1L]],
      selected_fold_2 = result$selections$candidate[[2L]],
      stringsAsFactors = FALSE
    )
  }
  null <- do.call(rbind, rows)
  null$observed_mean_outer_rank_ic <- observed_stat
  null$search_adjusted_p_value <- (1 + sum(null$mean_outer_rank_ic >= observed_stat)) / (contract$permutation_draws + 1)
  null
}

h042_gate_matrix <- function(panel, integrity_passed, nested, original, permutation, contract = h042_contract()) {
  metrics <- nested$metrics
  block_means <- tapply(metrics$rank_ic, metrics$outer_fold, mean)
  predictions <- nested$predictions
  positive <- pmax(predictions$target[predictions$quartile == 4L], 0)
  sectors <- predictions$sector[predictions$quartile == 4L]
  sector_contribution <- if (sum(positive) > 0) tapply(positive, sectors, sum) / sum(positive) else numeric()
  max_sector_share <- if (length(sector_contribution)) max(sector_contribution) else 1
  same_candidate <- length(unique(nested$selections$candidate)) == 1L
  coefficient_stability <- FALSE
  if (same_candidate) {
    candidate <- nested$selections$candidate[[1L]]
    if (candidate == "FIXED_THEORY_CORE") {
      coefficient_stability <- TRUE
    } else {
      wide <- reshape(nested$coefficients[c("outer_fold", "term", "coefficient")], idvar = "term",
                      timevar = "outer_fold", direction = "wide")
      coefficient_stability <- mean(sign(wide$coefficient.1) == sign(wide$coefficient.2) &
                                      sign(wide$coefficient.1) != 0) >= 0.60
    }
  }
  search_p <- unique(permutation$search_adjusted_p_value)
  gates <- data.frame(
    gate_id = c("G1_INTEGRITY", "G2_SAMPLE", "G3_OUTER_IC", "G4_BLOCK_TRANSPORT",
                "G5_OUTER_Q4_EXCESS", "G6_SEARCH_ADJUSTED", "G7_ORIGINAL_CHALLENGER",
                "G8_SECTOR_CONCENTRATION", "G9_SELECTION_STABILITY"),
    passed = c(
      integrity_passed,
      length(unique(panel$signal_quarter)) == 15L && length(unique(panel$symbol)) >= contract$minimum_assets &&
        min(table(panel$signal_quarter)) >= contract$minimum_assets_per_quarter,
      mean(metrics$rank_ic) > 0 && mean(metrics$rank_ic > 0) >= 4 / 6,
      all(block_means > 0),
      mean(metrics$q4_excess) > 0 && mean(metrics$q4_excess > 0) >= 4 / 6,
      search_p <= 0.05,
      mean(metrics$rank_ic) > mean(original$metrics$rank_ic),
      max_sector_share <= 0.35,
      same_candidate && coefficient_stability
    ),
    estimate = c(
      as.numeric(integrity_passed), length(unique(panel$symbol)), mean(metrics$rank_ic), min(block_means),
      mean(metrics$q4_excess), search_p, mean(metrics$rank_ic) - mean(original$metrics$rank_ic),
      max_sector_share, as.numeric(same_candidate && coefficient_stability)
    ),
    threshold = c("all checks", ">=400 identities and 15 quarters", "mean>0 and >=4/6 positive",
                  "both block means>0", "mean>0 and >=4/6 positive", "p<=0.05",
                  "selected mean IC>original mean IC", "<=0.35", "same candidate and sign stability>=0.60"),
    stringsAsFactors = FALSE
  )
  list(gates = gates, block_means = block_means, max_sector_share = max_sector_share,
       coefficient_stability = coefficient_stability, same_candidate = same_candidate,
       nominated = all(gates$passed))
}
