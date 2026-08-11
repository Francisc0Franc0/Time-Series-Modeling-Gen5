# Causal research engine for HYP-MOM-04.1.

h04_stop <- function(message) stop(message, call. = FALSE)

h04_contract <- function() {
  list(
    program_id = "HYP-MOM-04.1",
    name = "Regularized Trend-State Quartile",
    as_of_timestamp = "2026-08-07 17:30:00 America/New_York",
    query_start = as.Date("2016-01-04"),
    train_query_end = as.Date("2020-12-31"),
    oos_query_end = as.Date("2023-12-29"),
    unqueried_start = as.Date("2024-01-01"),
    train_signal_quarters = paste0(rep(2017:2020, each = 4), "Q", rep(1:4, 4))[1:15],
    oos_signal_quarters = paste0(rep(2020:2023, each = 4), "Q", rep(1:4, 4))[4:15],
    feature_names = c("momentum12_1", "sector_relative126", "slow_slope_atr",
                      "extension20", "volatility_ratio", "high_proximity252"),
    theory_signs = c(1, 1, 1, -1, -1, 1),
    lambdas = c(0.01, 0.1, 1, 10, 100),
    cv_train_quarters = c(6L, 9L, 12L),
    cv_validation_quarters = 3L,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    initial_wealth = 1,
    minimum_assets_per_quarter = 20L,
    minimum_sector_members = 3L,
    minimum_oos_identity_retention = 0.80,
    permutation_draws = 500L,
    bootstrap_draws = 2000L,
    random_portfolio_draws = 500L,
    random_seed = 20260810L
  )
}

h04_validate_contract <- function(contract = h04_contract()) {
  frozen <- h04_contract()
  if (!identical(names(contract), names(frozen))) h04_stop("Frozen HYP-MOM-04.1 contract fields changed.")
  same <- vapply(names(frozen), function(name) identical(contract[[name]], frozen[[name]]), logical(1))
  if (!all(same)) h04_stop(paste("Frozen HYP-MOM-04.1 contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  contract
}

h04_quarter_id <- function(date) {
  date <- as.Date(date)
  paste0(format(date, "%Y"), "Q", ((as.integer(format(date, "%m")) - 1L) %/% 3L) + 1L)
}

h04_next_quarter <- function(quarter_id) {
  year <- as.integer(substr(quarter_id, 1L, 4L))
  quarter <- as.integer(substr(quarter_id, 6L, 6L))
  ifelse(quarter == 4L, paste0(year + 1L, "Q1"), paste0(year, "Q", quarter + 1L))
}

h04_validate_bars <- function(bars, authorized_end, contract = h04_contract()) {
  h04_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "high", "low", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) h04_stop(paste("Bars missing columns:", paste(missing, collapse = ", ")))
  x <- as.data.frame(bars, stringsAsFactors = FALSE)
  x$symbol <- as.character(x$symbol)
  x$session_date <- as.Date(x$session_date)
  numeric_columns <- c("open", "high", "low", "close", "volume")
  x[numeric_columns] <- lapply(x[numeric_columns], as.numeric)
  if (anyNA(x$session_date) || any(!is.finite(as.matrix(x[numeric_columns])))) h04_stop("Bars contain missing or non-finite OHLCV values.")
  if (any(x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)) h04_stop("Bars contain invalid OHLCV values.")
  if (anyDuplicated(x[c("symbol", "session_date")])) h04_stop("Bars contain duplicate symbol/session rows.")
  if (any(x$session_date > as.Date(authorized_end))) h04_stop("Bars later than the authorized evidence window entered analysis.")
  if (any(x$session_date >= contract$unqueried_start)) h04_stop("Unqueried 2024+ observations entered HYP-MOM-04.1.")
  x <- x[order(x$symbol, x$session_date), , drop = FALSE]
  rownames(x) <- NULL
  x
}

h04_validate_registry <- function(registry, expected_count = 122L) {
  required <- c("instance_id", "symbol", "sector", "cohort")
  missing <- setdiff(required, names(registry))
  if (length(missing)) h04_stop(paste("Registry missing columns:", paste(missing, collapse = ", ")))
  registry <- as.data.frame(registry, stringsAsFactors = FALSE)
  if (!is.null(expected_count) && nrow(registry) != expected_count) {
    h04_stop(paste("HYP-MOM-04.1 registry count mismatch; expected", expected_count, "identities."))
  }
  if (anyDuplicated(registry$instance_id) || anyDuplicated(registry$symbol)) h04_stop("Frozen registry identifiers and symbols must be unique.")
  if (any(!nzchar(registry$instance_id) | !nzchar(registry$symbol) | !nzchar(registry$sector) | !nzchar(registry$cohort))) h04_stop("Frozen registry contains blank identity fields.")
  registry
}

h04_coverage <- function(bars, registry, calendar_dates, authorized_end, contract = h04_contract(),
                         expected_registry_count = 122L) {
  x <- h04_validate_bars(bars, authorized_end, contract)
  registry <- h04_validate_registry(registry, expected_count = expected_registry_count)
  calendar_dates <- sort(unique(as.Date(calendar_dates)))
  do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
    reg <- registry[i, , drop = FALSE]
    b <- x[x$symbol == reg$symbol, , drop = FALSE]
    missing_dates <- setdiff(calendar_dates, b$session_date)
    extra_dates <- setdiff(b$session_date, calendar_dates)
    data.frame(
      instance_id = reg$instance_id, symbol = reg$symbol, sector = reg$sector,
      cohort = reg$cohort, observed_sessions = nrow(b), expected_sessions = length(calendar_dates),
      missing_sessions = length(missing_dates), extra_sessions = length(extra_dates),
      first_session = if (nrow(b)) as.character(min(b$session_date)) else NA_character_,
      last_session = if (nrow(b)) as.character(max(b$session_date)) else NA_character_,
      analysis_eligible = nrow(b) == length(calendar_dates) && !length(missing_dates) && !length(extra_dates),
      stringsAsFactors = FALSE
    )
  }))
}

h04_schedule <- function(calendar_dates, signal_quarters) {
  dates <- sort(unique(as.Date(calendar_dates)))
  qid <- h04_quarter_id(dates)
  rows <- lapply(signal_quarters, function(signal_quarter) {
    target_quarter <- h04_next_quarter(signal_quarter)
    signal_dates <- dates[qid == signal_quarter]
    target_dates <- dates[qid == target_quarter]
    if (!length(signal_dates) || length(target_dates) < 2L) h04_stop(paste("Calendar lacks signal/target quarter:", signal_quarter))
    data.frame(
      signal_quarter = signal_quarter, target_quarter = target_quarter,
      signal_date = max(signal_dates), entry_date = min(target_dates), exit_date = max(target_dates),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

h04_true_range <- function(high, low, close) {
  prior <- c(NA_real_, head(close, -1L))
  tr <- pmax(high - low, abs(high - prior), abs(low - prior), na.rm = TRUE)
  tr[[1L]] <- high[[1L]] - low[[1L]]
  tr
}

h04_asset_feature_rows <- function(bars, schedule, identity, contract = h04_contract()) {
  h04_validate_contract(contract)
  x <- bars[order(bars$session_date), , drop = FALSE]
  tr <- h04_true_range(x$high, x$low, x$close)
  rows <- lapply(seq_len(nrow(schedule)), function(i) {
    s <- schedule[i, , drop = FALSE]
    signal_index <- match(s$signal_date, x$session_date)
    entry_index <- match(s$entry_date, x$session_date)
    exit_index <- match(s$exit_date, x$session_date)
    if (anyNA(c(signal_index, entry_index, exit_index)) || signal_index < 253L || entry_index <= signal_index || exit_index <= entry_index) return(NULL)
    log_close <- log(x$close)
    ret <- diff(log_close)
    # diff(log_close)[j] is the return from close[j] to close[j + 1].
    # Therefore the last admissible return at signal row t is element t - 1.
    rv20 <- stats::sd(ret[(signal_index - 20L):(signal_index - 1L)])
    rv126 <- stats::sd(ret[(signal_index - 126L):(signal_index - 1L)])
    atr20 <- mean(tr[(signal_index - 19L):signal_index])
    sma200 <- mean(x$close[(signal_index - 199L):signal_index])
    sma200_lag20 <- mean(x$close[(signal_index - 219L):(signal_index - 20L)])
    extension_window <- log_close[(signal_index - 19L):signal_index]
    extension_sd <- stats::sd(extension_window)
    data.frame(
      instance_id = identity$instance_id, symbol = identity$symbol,
      sector = identity$sector, cohort = identity$cohort,
      signal_quarter = s$signal_quarter, target_quarter = s$target_quarter,
      signal_date = s$signal_date, entry_date = s$entry_date, exit_date = s$exit_date,
      momentum12_1 = log(x$close[[signal_index - 21L]] / x$close[[signal_index - 252L]]),
      return126_raw = log(x$close[[signal_index]] / x$close[[signal_index - 126L]]),
      slow_slope_atr = (sma200 - sma200_lag20) / atr20,
      extension20 = (log_close[[signal_index]] - mean(extension_window)) / extension_sd,
      volatility_ratio = rv20 / rv126,
      high_proximity252 = x$close[[signal_index]] / max(x$close[(signal_index - 251L):signal_index]),
      entry_open = x$open[[entry_index]], exit_open = x$open[[exit_index]],
      target_return = x$open[[exit_index]] / x$open[[entry_index]] - 1,
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  numeric_fields <- c("momentum12_1", "return126_raw", "slow_slope_atr", "extension20",
                      "volatility_ratio", "high_proximity252", "target_return")
  out <- out[apply(is.finite(as.matrix(out[numeric_fields])), 1L, all), , drop = FALSE]
  rownames(out) <- NULL
  out
}

h04_rank_normal <- function(x) {
  n <- length(x)
  if (n < 2L || any(!is.finite(x))) h04_stop("Rank-normal transform requires at least two finite observations.")
  stats::qnorm((rank(x, ties.method = "average") - 0.5) / n)
}

h04_build_panel <- function(bars, registry, calendar_dates, signal_quarters,
                            authorized_end, contract = h04_contract()) {
  x <- h04_validate_bars(bars, authorized_end, contract)
  registry <- h04_validate_registry(registry, expected_count = NULL)
  schedule <- h04_schedule(calendar_dates, signal_quarters)
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    identity <- registry[i, , drop = FALSE]
    h04_asset_feature_rows(x[x$symbol == identity$symbol, , drop = FALSE], schedule, identity, contract)
  })
  rows <- Filter(function(z) nrow(z) > 0L, rows)
  if (!length(rows)) h04_stop("No complete feature rows were constructed.")
  panel <- do.call(rbind, rows)
  sector_key <- interaction(panel$signal_quarter, panel$sector, drop = TRUE)
  sector_count <- ave(panel$return126_raw, sector_key, FUN = length)
  sector_mean <- ave(panel$return126_raw, sector_key, FUN = mean)
  panel$sector_relative126 <- panel$return126_raw - sector_mean
  panel <- panel[sector_count >= contract$minimum_sector_members, , drop = FALSE]
  universe_mean <- ave(panel$target_return, panel$signal_quarter, FUN = mean)
  panel$target_relative_return <- panel$target_return - universe_mean
  for (feature in contract$feature_names) {
    panel[[paste0(feature, "_rn")]] <- ave(panel[[feature]], panel$signal_quarter, FUN = h04_rank_normal)
  }
  panel <- panel[order(match(panel$signal_quarter, signal_quarters), panel$symbol), , drop = FALSE]
  rownames(panel) <- NULL
  panel
}

h04_feature_columns <- function(contract = h04_contract()) paste0(h04_validate_contract(contract)$feature_names, "_rn")

h04_scaler_fit <- function(panel, columns) {
  center <- vapply(panel[columns], mean, numeric(1))
  scale <- vapply(panel[columns], stats::sd, numeric(1))
  if (any(!is.finite(scale) | scale <= 0)) h04_stop("TRAIN feature scaler contains invalid dispersion.")
  list(center = center, scale = scale)
}

h04_scaler_apply <- function(panel, columns, scaler) {
  matrix((as.matrix(panel[columns]) - rep(scaler$center, each = nrow(panel))) /
           rep(scaler$scale, each = nrow(panel)), nrow = nrow(panel),
         dimnames = list(NULL, columns))
}

h04_ridge_fit <- function(x, y, lambda) {
  x <- as.matrix(x); y <- as.numeric(y)
  design <- cbind(intercept = 1, x)
  penalty <- diag(c(0, rep(as.numeric(lambda), ncol(x))))
  beta <- solve(crossprod(design) + penalty, crossprod(design, y))
  list(intercept = unname(beta[[1L]]), coefficients = setNames(as.numeric(beta[-1L]), colnames(x)), lambda = lambda)
}

h04_ridge_predict <- function(model, x) as.numeric(model$intercept + as.matrix(x) %*% model$coefficients)

h04_spearman <- function(score, target) {
  if (length(score) < 3L || stats::sd(score) == 0 || stats::sd(target) == 0) return(NA_real_)
  suppressWarnings(stats::cor(score, target, method = "spearman"))
}

h04_quartile <- function(score) {
  n <- length(score)
  pmin(4L, pmax(1L, ceiling(4 * rank(score, ties.method = "first") / n)))
}

h04_cv <- function(panel, target = panel$target_relative_return, contract = h04_contract()) {
  contract <- h04_validate_contract(contract)
  quarters <- contract$train_signal_quarters
  columns <- h04_feature_columns(contract)
  rows <- list(); predictions <- list(); k <- 0L
  for (lambda in contract$lambdas) {
    for (fold in seq_along(contract$cv_train_quarters)) {
      train_q <- quarters[seq_len(contract$cv_train_quarters[[fold]])]
      validation_q <- quarters[(contract$cv_train_quarters[[fold]] + 1L):
                                 (contract$cv_train_quarters[[fold]] + contract$cv_validation_quarters)]
      tr <- panel$signal_quarter %in% train_q
      va <- panel$signal_quarter %in% validation_q
      scaler <- h04_scaler_fit(panel[tr, , drop = FALSE], columns)
      fit <- h04_ridge_fit(h04_scaler_apply(panel[tr, , drop = FALSE], columns, scaler), target[tr], lambda)
      score <- h04_ridge_predict(fit, h04_scaler_apply(panel[va, , drop = FALSE], columns, scaler))
      for (quarter in validation_q) {
        local <- which(panel$signal_quarter[va] == quarter)
        k <- k + 1L
        rows[[k]] <- data.frame(lambda = lambda, fold = fold, signal_quarter = quarter,
                                rank_ic = h04_spearman(score[local], target[va][local]), stringsAsFactors = FALSE)
      }
      predictions[[paste(lambda, fold, sep = "_")]] <- data.frame(
        row_id = which(va), lambda = lambda, fold = fold, signal_quarter = panel$signal_quarter[va],
        score = score, target = target[va], stringsAsFactors = FALSE
      )
    }
  }
  details <- do.call(rbind, rows)
  summary <- do.call(rbind, lapply(contract$lambdas, function(lambda) {
    values <- details$rank_ic[details$lambda == lambda]
    data.frame(lambda = lambda, mean_rank_ic = mean(values), se_rank_ic = stats::sd(values) / sqrt(length(values)),
               positive_fraction = mean(values > 0), validation_quarters = length(values), stringsAsFactors = FALSE)
  }))
  best_row <- summary[which.max(summary$mean_rank_ic), , drop = FALSE]
  threshold <- best_row$mean_rank_ic - best_row$se_rank_ic
  eligible <- summary$lambda[summary$mean_rank_ic >= threshold]
  selected_lambda <- max(eligible)
  selected_predictions <- do.call(rbind, predictions[grepl(paste0("^", selected_lambda, "_"), names(predictions))])
  selected_details <- details[details$lambda == selected_lambda, , drop = FALSE]
  list(details = details, summary = summary, selected_lambda = selected_lambda,
       selected_details = selected_details, selected_predictions = selected_predictions,
       one_se_threshold = threshold)
}

h04_fit_final <- function(panel, lambda, target = panel$target_relative_return,
                          contract = h04_contract()) {
  columns <- h04_feature_columns(contract)
  scaler <- h04_scaler_fit(panel, columns)
  x <- h04_scaler_apply(panel, columns, scaler)
  model <- h04_ridge_fit(x, target, lambda)
  list(model = model, scaler = scaler, score = h04_ridge_predict(model, x))
}

h04_score_panel <- function(panel, fit, contract = h04_contract()) {
  columns <- h04_feature_columns(contract)
  panel$ridge_score <- h04_ridge_predict(fit$model, h04_scaler_apply(panel, columns, fit$scaler))
  panel$theory_score <- as.numeric(as.matrix(panel[columns]) %*% contract$theory_signs)
  panel$ridge_quartile <- ave(panel$ridge_score, panel$signal_quarter, FUN = h04_quartile)
  panel$theory_quartile <- ave(panel$theory_score, panel$signal_quarter, FUN = h04_quartile)
  panel
}

h04_quarter_summary <- function(scored, score_column = "ridge_score", quartile_column = "ridge_quartile") {
  do.call(rbind, lapply(split(scored, scored$signal_quarter), function(x) {
    q4 <- x[x[[quartile_column]] == 4L, , drop = FALSE]
    q1 <- x[x[[quartile_column]] == 1L, , drop = FALSE]
    data.frame(
      signal_quarter = unique(x$signal_quarter), target_quarter = unique(x$target_quarter),
      asset_count = nrow(x), selected_count = nrow(q4),
      rank_ic = h04_spearman(x[[score_column]], x$target_relative_return),
      universe_return = mean(x$target_return), q4_return = mean(q4$target_return),
      q4_excess = mean(q4$target_relative_return), q1_return = mean(q1$target_return),
      q4_minus_q1 = mean(q4$target_return) - mean(q1$target_return),
      stringsAsFactors = FALSE
    )
  }))
}

h04_univariate_sorts <- function(panel, contract = h04_contract()) {
  rows <- list(); k <- 0L
  for (feature in contract$feature_names) {
    column <- paste0(feature, "_rn")
    for (quarter in unique(panel$signal_quarter)) {
      x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
      quartile <- h04_quartile(x[[column]])
      k <- k + 1L
      rows[[k]] <- data.frame(feature = feature, signal_quarter = quarter,
                              rank_ic = h04_spearman(x[[column]], x$target_relative_return),
                              q4_excess = mean(x$target_relative_return[quartile == 4L]),
                              q4_minus_q1 = mean(x$target_return[quartile == 4L]) - mean(x$target_return[quartile == 1L]),
                              stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}

h04_fama_macbeth <- function(panel, contract = h04_contract()) {
  columns <- h04_feature_columns(contract)
  rows <- lapply(split(panel, panel$signal_quarter), function(x) {
    fit <- stats::lm.fit(cbind(1, as.matrix(x[columns])), x$target_relative_return)
    data.frame(signal_quarter = unique(x$signal_quarter), term = c("intercept", contract$feature_names),
               coefficient = as.numeric(fit$coefficients), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

h04_permutation <- function(panel, contract = h04_contract()) {
  contract <- h04_validate_contract(contract)
  set.seed(contract$random_seed)
  observed_cv <- h04_cv(panel, panel$target_relative_return, contract)
  observed_fit <- h04_fit_final(panel, observed_cv$selected_lambda, panel$target_relative_return, contract)
  observed_scored <- h04_score_panel(panel, observed_fit, contract)
  observed <- mean(observed_scored$target_relative_return[observed_scored$ridge_quartile == 4L])
  simulations <- numeric(contract$permutation_draws)
  selected_lambdas <- numeric(contract$permutation_draws)
  quarter_groups <- split(seq_len(nrow(panel)), panel$signal_quarter)
  for (i in seq_len(contract$permutation_draws)) {
    permuted <- panel$target_relative_return
    for (idx in quarter_groups) permuted[idx] <- sample(permuted[idx], length(idx), replace = FALSE)
    cv <- h04_cv(panel, permuted, contract)
    fit <- h04_fit_final(panel, cv$selected_lambda, permuted, contract)
    score <- h04_ridge_predict(fit$model, h04_scaler_apply(panel, h04_feature_columns(contract), fit$scaler))
    quartile <- ave(score, panel$signal_quarter, FUN = h04_quartile)
    simulations[[i]] <- mean(permuted[quartile == 4L])
    selected_lambdas[[i]] <- cv$selected_lambda
  }
  data.frame(simulation_id = seq_len(contract$permutation_draws), q4_excess = simulations,
             selected_lambda = selected_lambdas, observed_q4_excess = observed,
             observed_percentile = mean(simulations <= observed), stringsAsFactors = FALSE)
}

h04_block_bootstrap <- function(quarter_summary, draws = 2000L, seed = 1L) {
  values <- quarter_summary$q4_excess
  set.seed(seed)
  means <- replicate(draws, mean(sample(values, length(values), replace = TRUE)))
  data.frame(statistic = "mean_q4_excess", estimate = mean(values),
             ci_low = unname(stats::quantile(means, 0.025)),
             ci_high = unname(stats::quantile(means, 0.975)), stringsAsFactors = FALSE)
}

h04_train_gates <- function(panel, cv, scored, permutation, integrity_passed,
                            contract = h04_contract()) {
  quarter_summary <- h04_quarter_summary(scored)
  positive_contribution <- pmax(scored$target_relative_return[scored$ridge_quartile == 4L], 0)
  selected_sector <- scored$sector[scored$ridge_quartile == 4L]
  sector_contribution <- tapply(positive_contribution, selected_sector, sum)
  max_sector_share <- if (sum(sector_contribution) > 0) max(sector_contribution) / sum(sector_contribution) else 1
  cv_ic <- cv$selected_details$rank_ic
  gates <- data.frame(
    gate_id = c("G1_INTEGRITY", "G2_SAMPLE", "G3_EXPANDING_CV_IC", "G4_TRAIN_Q4_EXCESS",
                "G5_Q4_MINUS_Q1", "G6_PERMUTATION", "G7_SECTOR_CONCENTRATION"),
    passed = c(
      isTRUE(integrity_passed),
      length(unique(panel$signal_quarter)) >= 12L && min(table(panel$signal_quarter)) >= contract$minimum_assets_per_quarter,
      mean(cv_ic) > 0 && mean(cv_ic > 0) >= 0.60,
      mean(quarter_summary$q4_excess) > 0 && mean(quarter_summary$q4_excess > 0) >= 0.60,
      mean(quarter_summary$q4_minus_q1) > 0,
      unique(permutation$observed_percentile) >= 0.90,
      max_sector_share <= 0.35
    ),
    value = c(
      as.numeric(isTRUE(integrity_passed)), min(table(panel$signal_quarter)), mean(cv_ic),
      mean(quarter_summary$q4_excess), mean(quarter_summary$q4_minus_q1),
      unique(permutation$observed_percentile), max_sector_share
    ),
    threshold = c("all checks pass", ">=12 quarters and >=20 assets/quarter",
                  ">0 mean IC and >=60% positive quarters", ">0 mean and >=60% positive quarters",
                  ">0 mean spread", ">=0.90 percentile", "<=0.35"),
    stringsAsFactors = FALSE
  )
  list(gates = gates, quarter_summary = quarter_summary, max_sector_share = max_sector_share,
       nominated = all(gates$passed))
}

h04_drawdown <- function(wealth) wealth / cummax(wealth) - 1

h04_sharpe <- function(returns, periods = 4) {
  returns <- as.numeric(returns)
  if (length(returns) < 2L || !is.finite(stats::sd(returns)) || stats::sd(returns) == 0) return(NA_real_)
  sqrt(periods) * mean(returns) / stats::sd(returns)
}

h04_policy_replay <- function(scored, quartile_column, one_way_bps, contract = h04_contract()) {
  cost <- one_way_bps / 10000
  quarters <- unique(scored$signal_quarter)
  wealth <- contract$initial_wealth
  rows <- list(); selections <- list()
  for (i in seq_along(quarters)) {
    quarter <- quarters[[i]]
    x <- scored[scored$signal_quarter == quarter, , drop = FALSE]
    selected <- x[x[[quartile_column]] == 4L, , drop = FALSE]
    gross <- if (nrow(selected)) mean(selected$target_return) else 0
    net <- if (nrow(selected)) (1 - cost) * (1 + gross) * (1 - cost) - 1 else 0
    start_wealth <- wealth
    wealth <- wealth * (1 + net)
    rows[[i]] <- data.frame(signal_quarter = quarter, target_quarter = unique(x$target_quarter),
                            entry_date = unique(x$entry_date), exit_date = unique(x$exit_date),
                            selected_count = nrow(selected), gross_return = gross, net_return = net,
                            start_wealth = start_wealth, end_wealth = wealth, stringsAsFactors = FALSE)
    if (nrow(selected)) {
      selected$weight <- 1 / nrow(selected)
      selected$one_way_cost_bps <- one_way_bps
      selections[[i]] <- selected
    }
  }
  path <- do.call(rbind, rows)
  path$drawdown <- h04_drawdown(path$end_wealth)
  selection <- if (length(selections)) do.call(rbind, selections) else data.frame()
  list(path = path, selections = selection)
}

h04_random_portfolios <- function(scored, one_way_bps, contract = h04_contract()) {
  cost <- one_way_bps / 10000
  groups <- split(scored, scored$signal_quarter)
  set.seed(contract$random_seed + 40000L)
  totals <- numeric(contract$random_portfolio_draws)
  for (simulation in seq_len(contract$random_portfolio_draws)) {
    wealth <- contract$initial_wealth
    for (x in groups) {
      count <- sum(x$ridge_quartile == 4L)
      picked <- sample(seq_len(nrow(x)), count, replace = FALSE)
      gross <- mean(x$target_return[picked])
      wealth <- wealth * (1 + (1 - cost) * (1 + gross) * (1 - cost) - 1)
    }
    totals[[simulation]] <- wealth - 1
  }
  data.frame(simulation_id = seq_len(contract$random_portfolio_draws), total_return = totals,
             stringsAsFactors = FALSE)
}
