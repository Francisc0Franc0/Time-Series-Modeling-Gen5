him042_stop <- function(message) {
  stop(paste0("[HYP-IMOM-04.1 CAL-A02] ", message), call. = FALSE)
}
him042_contract <- function() list(
  hypothesis_id = "HYP-IMOM-04.1",
  attempt_id = "CAL-A02",
  as_of_timestamp = "2026-08-13 17:30:00 America/New_York",
  symbols = c("TSLA", "QQQ", "SPY", "SMH"),
  prehistory_start = as.Date("2017-01-03"),
  development_start = as.Date("2018-01-02"),
  calibration_start = as.Date("2021-01-01"),
  development_end = as.Date("2023-12-29"),
  confirmation_start = as.Date("2024-01-02"),
  primary_bps = 10,
  stress_bps = 20,
  lambda_grid = c(.1, 1, 10, 100, 1000),
  split_quantiles = c(.25, .50, .75),
  root_min_leaf = 60L,
  terminal_min_leaf = 30L,
  inner_blocks = 3L,
  simulations = 200L,
  random_seed = 104042L,
  minimum_upside_capture = .60,
  maximum_downside_capture = .40,
  minimum_exposure = .20,
  maximum_exposure = .80,
  minimum_positive_quarters = 8L
)

him042_validate_contract <- function(contract = him042_contract()) {
  required_symbols <- c("TSLA", "QQQ", "SPY", "SMH")
  if (!identical(contract$symbols, required_symbols)) him042_stop("Symbol registry changed.")
  if (contract$development_end >= contract$confirmation_start) {
    him042_stop("Development and confirmation overlap.")
  }
  if (!identical(contract$lambda_grid, c(.1, 1, 10, 100, 1000))) {
    him042_stop("Ridge lambda grid changed.")
  }
  if (contract$primary_bps != 10 || contract$stress_bps != 20) {
    him042_stop("Frozen cost contract changed.")
  }
  invisible(TRUE)
}

him042_feature_names <- function() c(
  "asset_trend_200", "trend_alignment_20_50", "efficiency_20",
  "intraday_efficiency_5", "drawdown_63", "downside_share_20",
  "vol_of_vol_20", "relative_volume_20", "rs_qqq_20", "rs_smh_20",
  "qqq_trend_200", "smh_trend_200"
)

him042_interaction_names <- function() c(
  "trend_x_efficiency", "trend_x_downside", "rs_qqq_x_qqq_trend",
  "intraday_efficiency_x_volume"
)

him042_model_feature_names <- function() c(him042_feature_names(), him042_interaction_names())

him042_roll_mean <- function(x, n) {
  out <- rep(NA_real_, length(x)); n <- as.integer(n)
  if (length(x) < n) return(out)
  for (i in n:length(x)) {
    w <- x[(i - n + 1L):i]
    if (all(is.finite(w))) out[[i]] <- mean(w)
  }
  out
}

him042_roll_sd <- function(x, n) {
  out <- rep(NA_real_, length(x)); n <- as.integer(n)
  if (length(x) < n) return(out)
  for (i in n:length(x)) {
    w <- x[(i - n + 1L):i]
    if (all(is.finite(w))) out[[i]] <- stats::sd(w)
  }
  out
}

him042_roll_max <- function(x, n) {
  out <- rep(NA_real_, length(x)); n <- as.integer(n)
  if (length(x) < n) return(out)
  for (i in n:length(x)) {
    w <- x[(i - n + 1L):i]
    if (all(is.finite(w))) out[[i]] <- max(w)
  }
  out
}

him042_sma <- function(x, n) him042_roll_mean(x, n)

him042_lag_return <- function(close, n) {
  out <- rep(NA_real_, length(close)); n <- as.integer(n)
  if (length(close) <= n) return(out)
  for (i in (n + 1L):length(close)) {
    if (is.finite(close[[i]]) && is.finite(close[[i - n]]) && close[[i - n]] > 0) {
      out[[i]] <- log(close[[i]] / close[[i - n]])
    }
  }
  out
}

him042_efficiency <- function(close, n = 20L) {
  out <- rep(NA_real_, length(close)); n <- as.integer(n)
  if (length(close) <= n) return(out)
  log_close <- log(close)
  for (i in (n + 1L):length(close)) {
    path <- log_close[(i - n):i]
    denominator <- sum(abs(diff(path)))
    if (all(is.finite(path)) && denominator > 0) {
      out[[i]] <- abs(path[[length(path)]] - path[[1L]]) / denominator
    }
  }
  out
}

him042_prior_relative_volume <- function(volume, n = 20L) {
  out <- rep(NA_real_, length(volume)); n <- as.integer(n)
  if (length(volume) <= n) return(out)
  for (i in (n + 1L):length(volume)) {
    history <- volume[(i - n):(i - 1L)]
    denominator <- stats::median(history)
    if (all(is.finite(history)) && is.finite(volume[[i]]) && denominator > 0) {
      out[[i]] <- log(volume[[i]] / denominator)
    }
  }
  out
}

him042_downside_share <- function(log_return, n = 20L) {
  out <- rep(NA_real_, length(log_return)); n <- as.integer(n)
  if (length(log_return) < n) return(out)
  for (i in n:length(log_return)) {
    w <- log_return[(i - n + 1L):i]
    denominator <- sum(w^2)
    if (all(is.finite(w)) && denominator > 0) out[[i]] <- sum(pmin(w, 0)^2) / denominator
  }
  out
}

him042_session_daily <- function(x) {
  x <- x[order(x$session_date, x$bar_slot), , drop = FALSE]
  groups <- split(seq_len(nrow(x)), x$session_date)
  rows <- lapply(groups, function(index) {
    z <- x[index, , drop = FALSE]
    points <- c(z$open[[1L]], z$close)
    path <- sum(abs(diff(log(points))))
    displacement <- abs(log(z$close[[nrow(z)]] / z$open[[1L]]))
    data.frame(
      session_date = as.Date(z$session_date[[1L]]),
      open = z$open[[1L]], high = max(z$high), low = min(z$low),
      close = z$close[[nrow(z)]], volume = sum(z$volume),
      intraday_efficiency = if (is.finite(path) && path > 0) displacement / path else 0,
      bar_count = nrow(z), stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL; out
}

him042_build_session_panel <- function(bars, contract = him042_contract()) {
  him042_validate_contract(contract)
  required <- c("symbol", "timestamp_utc", "session_date", "bar_slot", "open", "high",
                "low", "close", "volume")
  if (!all(required %in% names(bars))) him042_stop("Intraday bars are incomplete.")
  bars$session_date <- as.Date(bars$session_date)
  bars <- bars[bars$session_date >= contract$prehistory_start &
                 bars$session_date <= contract$development_end, , drop = FALSE]
  if (any(bars$session_date >= contract$confirmation_start)) him042_stop("Confirmation bars were read.")
  if (!identical(sort(unique(bars$symbol)), sort(contract$symbols))) {
    him042_stop("Bars must contain exactly TSLA, QQQ, SPY, and SMH.")
  }
  if (anyDuplicated(bars[c("symbol", "timestamp_utc")])) him042_stop("Duplicate intraday bars detected.")
  daily <- lapply(contract$symbols, function(symbol) {
    out <- him042_session_daily(bars[bars$symbol == symbol, , drop = FALSE])
    names(out)[names(out) != "session_date"] <- paste0(tolower(symbol), "_", names(out)[names(out) != "session_date"])
    out
  })
  names(daily) <- contract$symbols
  calendars <- lapply(daily, function(x) as.character(x$session_date))
  if (!all(vapply(calendars[-1L], identical, logical(1L), calendars[[1L]]))) {
    him042_stop("Symbol calendars are not exact after archive exclusions.")
  }
  panel <- Reduce(function(a, b) merge(a, b, by = "session_date", all = FALSE, sort = TRUE), daily)
  panel <- panel[order(panel$session_date), , drop = FALSE]
  close <- panel$tsla_close
  daily_return <- c(NA_real_, diff(log(close)))
  sma20 <- him042_sma(close, 20L); sma50 <- him042_sma(close, 50L); sma200 <- him042_sma(close, 200L)
  qqq_sma200 <- him042_sma(panel$qqq_close, 200L)
  smh_sma200 <- him042_sma(panel$smh_close, 200L)
  panel$asset_trend_200 <- close / sma200 - 1
  panel$trend_alignment_20_50 <- sma20 / sma50 - 1
  panel$efficiency_20 <- him042_efficiency(close, 20L)
  panel$intraday_efficiency_5 <- him042_roll_mean(panel$tsla_intraday_efficiency, 5L)
  panel$drawdown_63 <- close / him042_roll_max(close, 63L) - 1
  panel$downside_share_20 <- him042_downside_share(daily_return, 20L)
  panel$vol_of_vol_20 <- him042_roll_sd(abs(daily_return), 20L)
  panel$relative_volume_20 <- him042_prior_relative_volume(panel$tsla_volume, 20L)
  panel$rs_qqq_20 <- him042_lag_return(close, 20L) - him042_lag_return(panel$qqq_close, 20L)
  panel$rs_smh_20 <- him042_lag_return(close, 20L) - him042_lag_return(panel$smh_close, 20L)
  panel$qqq_trend_200 <- panel$qqq_close / qqq_sma200 - 1
  panel$smh_trend_200 <- panel$smh_close / smh_sma200 - 1
  panel$trend_x_efficiency <- panel$asset_trend_200 * panel$efficiency_20
  panel$trend_x_downside <- panel$asset_trend_200 * panel$downside_share_20
  panel$rs_qqq_x_qqq_trend <- panel$rs_qqq_20 * panel$qqq_trend_200
  panel$intraday_efficiency_x_volume <- panel$intraday_efficiency_5 * panel$relative_volume_20
  n <- nrow(panel)
  panel$entry_session <- as.Date(NA); panel$exit_session <- as.Date(NA)
  panel$entry_open <- panel$exit_open <- panel$forward_log_return <- panel$forward_simple_return <- NA_real_
  if (n >= 3L) {
    i <- seq_len(n - 2L)
    panel$entry_session[i] <- panel$session_date[i + 1L]
    panel$exit_session[i] <- panel$session_date[i + 2L]
    panel$entry_open[i] <- panel$tsla_open[i + 1L]
    panel$exit_open[i] <- panel$tsla_open[i + 2L]
    panel$forward_log_return[i] <- log(panel$exit_open[i] / panel$entry_open[i])
    panel$forward_simple_return[i] <- panel$exit_open[i] / panel$entry_open[i] - 1
  }
  panel <- panel[panel$session_date >= contract$development_start &
                   panel$session_date <= contract$development_end &
                   !is.na(panel$exit_session) & panel$exit_session <= contract$development_end, , drop = FALSE]
  panel$row_id <- seq_len(nrow(panel))
  panel$feature_complete <- complete.cases(panel[him042_model_feature_names()]) &
    is.finite(panel$forward_log_return) & is.finite(panel$forward_simple_return)
  panel$eligibility_reason <- ifelse(panel$feature_complete, "ELIGIBLE", "CAUSAL_HISTORY_INCOMPLETE")
  panel
}

him042_matrix <- function(data, include_interactions = TRUE) {
  features <- if (include_interactions) him042_model_feature_names() else him042_feature_names()
  x <- as.matrix(data[features]); storage.mode(x) <- "double"; x
}

him042_ridge_fit <- function(x, y, lambda) {
  x <- as.matrix(x); y <- as.numeric(y)
  center <- colMeans(x); scale <- apply(x, 2L, stats::sd)
  scale[!is.finite(scale) | scale <= 0] <- 1
  z <- sweep(sweep(x, 2L, center, "-"), 2L, scale, "/")
  design <- cbind(1, z)
  penalty <- diag(c(0, rep(as.numeric(lambda), ncol(z))))
  coefficients <- solve(crossprod(design) + penalty, crossprod(design, y))
  list(intercept = coefficients[[1L]], coefficients = as.numeric(coefficients[-1L]),
       center = center, scale = scale, lambda = as.numeric(lambda),
       feature_names = colnames(x))
}

him042_ridge_predict <- function(model, x) {
  x <- as.matrix(x)
  z <- sweep(sweep(x, 2L, model$center, "-"), 2L, model$scale, "/")
  as.numeric(model$intercept + z %*% model$coefficients)
}

him042_inner_splits <- function(n, blocks = 3L) {
  if (n < 240L) return(list())
  first_end <- max(180L, floor(.55 * n))
  cuts <- unique(as.integer(floor(seq(first_end, n, length.out = blocks + 1L))))
  if (length(cuts) < 2L) return(list())
  lapply(seq_len(length(cuts) - 1L), function(i) {
    list(train = seq_len(cuts[[i]]), validation = (cuts[[i]] + 1L):cuts[[i + 1L]])
  })
}

him042_select_lambda <- function(x, y, contract = him042_contract()) {
  splits <- him042_inner_splits(nrow(x), contract$inner_blocks)
  if (!length(splits)) return(contract$lambda_grid[[3L]])
  loss <- vapply(contract$lambda_grid, function(lambda) {
    fold_loss <- vapply(splits, function(split) {
      model <- him042_ridge_fit(x[split$train, , drop = FALSE], y[split$train], lambda)
      prediction <- him042_ridge_predict(model, x[split$validation, , drop = FALSE])
      mean((y[split$validation] - prediction)^2)
    }, numeric(1L))
    mean(fold_loss)
  }, numeric(1L))
  contract$lambda_grid[[which.min(loss)]]
}

him042_best_split <- function(x, y, minimum_leaf, quantiles = c(.25, .50, .75)) {
  baseline <- sum((y - mean(y))^2); best <- NULL; best_sse <- baseline
  for (j in seq_len(ncol(x))) {
    thresholds <- unique(as.numeric(stats::quantile(x[, j], quantiles, names = FALSE, type = 8)))
    for (threshold in thresholds) {
      left <- x[, j] <= threshold; right <- !left
      if (sum(left) < minimum_leaf || sum(right) < minimum_leaf) next
      sse <- sum((y[left] - mean(y[left]))^2) + sum((y[right] - mean(y[right]))^2)
      if (is.finite(sse) && sse < best_sse - 1e-15) {
        best_sse <- sse
        best <- list(feature_index = j, feature = colnames(x)[[j]], threshold = threshold,
                     reduction = baseline - sse, left = left, right = right)
      }
    }
  }
  best
}

him042_tree_fit <- function(x, y, contract = him042_contract()) {
  x <- as.matrix(x); y <- as.numeric(y)
  root <- him042_best_split(x, y, contract$root_min_leaf, contract$split_quantiles)
  model <- list(mean = mean(y), root = root, feature_names = colnames(x))
  if (is.null(root)) return(model)
  make_child <- function(index) {
    split <- him042_best_split(x[index, , drop = FALSE], y[index],
                              contract$terminal_min_leaf, contract$split_quantiles)
    list(mean = mean(y[index]), split = split,
         left_mean = if (!is.null(split)) mean(y[index][split$left]) else NA_real_,
         right_mean = if (!is.null(split)) mean(y[index][split$right]) else NA_real_)
  }
  model$left_child <- make_child(root$left)
  model$right_child <- make_child(root$right)
  model
}

him042_tree_predict <- function(model, x) {
  x <- as.matrix(x); prediction <- rep(model$mean, nrow(x))
  if (is.null(model$root)) return(prediction)
  root_left <- x[, model$root$feature_index] <= model$root$threshold
  apply_child <- function(index, child) {
    if (!length(index)) return(invisible(NULL))
    prediction[index] <<- child$mean
    if (!is.null(child$split)) {
      child_left <- x[index, child$split$feature_index] <= child$split$threshold
      prediction[index[child_left]] <<- child$left_mean
      prediction[index[!child_left]] <<- child$right_mean
    }
    invisible(NULL)
  }
  apply_child(which(root_left), model$left_child)
  apply_child(which(!root_left), model$right_child)
  prediction
}

him042_quarter_table <- function(contract = him042_contract()) {
  starts <- seq(as.Date("2021-01-01"), as.Date("2023-10-01"), by = "quarter")
  ends <- c(starts[-1L] - 1L, contract$development_end)
  data.frame(fold = sprintf("%dQ%d", as.integer(format(starts, "%Y")),
                            (as.integer(format(starts, "%m")) - 1L) %/% 3L + 1L),
             start = starts, end = ends, stringsAsFactors = FALSE)
}

him042_roundtrip_log_buffer <- function(bps) -2 * log(1 - as.numeric(bps) / 10000)

him042_tree_ledger <- function(model, fold) {
  rows <- list(data.frame(fold = fold, node = "ROOT", mean = model$mean,
                          feature = NA_character_, threshold = NA_real_, reduction = NA_real_))
  if (!is.null(model$root)) {
    rows[[1L]]$feature <- model$root$feature; rows[[1L]]$threshold <- model$root$threshold
    rows[[1L]]$reduction <- model$root$reduction
    for (side in c("LEFT", "RIGHT")) {
      child <- if (side == "LEFT") model$left_child else model$right_child
      rows[[length(rows) + 1L]] <- data.frame(
        fold = fold, node = side, mean = child$mean,
        feature = if (!is.null(child$split)) child$split$feature else NA_character_,
        threshold = if (!is.null(child$split)) child$split$threshold else NA_real_,
        reduction = if (!is.null(child$split)) child$split$reduction else NA_real_)
    }
  }
  do.call(rbind, rows)
}

him042_oof_predictions <- function(panel, contract = him042_contract()) {
  eligible <- panel[panel$feature_complete, , drop = FALSE]
  eligible <- eligible[order(eligible$session_date), , drop = FALSE]
  quarters <- him042_quarter_table(contract)
  predictions <- list(); coefficients <- list(); trees <- list(); folds <- list(); z <- 1L
  threshold <- him042_roundtrip_log_buffer(contract$primary_bps)
  for (q in seq_len(nrow(quarters))) {
    fold <- quarters[q, ]
    train <- eligible[eligible$exit_session < fold$start, , drop = FALSE]
    test <- eligible[eligible$session_date >= fold$start & eligible$session_date <= fold$end, , drop = FALSE]
    if (nrow(train) < 400L || !nrow(test)) him042_stop(paste("Insufficient support for", fold$fold))
    x_train_ridge <- him042_matrix(train, TRUE); x_test_ridge <- him042_matrix(test, TRUE)
    y_train <- train$forward_log_return
    lambda <- him042_select_lambda(x_train_ridge, y_train, contract)
    ridge <- him042_ridge_fit(x_train_ridge, y_train, lambda)
    ridge_prediction <- him042_ridge_predict(ridge, x_test_ridge)
    x_train_tree <- him042_matrix(train, FALSE); x_test_tree <- him042_matrix(test, FALSE)
    tree <- him042_tree_fit(x_train_tree, y_train, contract)
    tree_prediction <- him042_tree_predict(tree, x_test_tree)
    baseline <- mean(y_train)
    base <- data.frame(
      row_id = test$row_id, fold = fold$fold, decision_session = test$session_date,
      entry_session = test$entry_session, exit_session = test$exit_session,
      entry_open = test$entry_open, exit_open = test$exit_open,
      actual_log_return = test$forward_log_return,
      actual_simple_return = test$forward_simple_return,
      baseline_prediction = baseline, train_rows = nrow(train),
      maximum_train_exit = max(train$exit_session), stringsAsFactors = FALSE)
    predictions[[z]] <- transform(base, model_id = "R1_RIDGE", prediction = ridge_prediction,
                                  permit = ridge_prediction > threshold, lambda = lambda); z <- z + 1L
    predictions[[z]] <- transform(base, model_id = "T1_DEPTH2", prediction = tree_prediction,
                                  permit = tree_prediction > threshold, lambda = NA_real_); z <- z + 1L
    coefficients[[q]] <- data.frame(
      fold = fold$fold, lambda = lambda,
      feature = c("(Intercept)", ridge$feature_names),
      coefficient_standardized = c(ridge$intercept, ridge$coefficients), stringsAsFactors = FALSE)
    trees[[q]] <- him042_tree_ledger(tree, fold$fold)
    folds[[q]] <- data.frame(fold = fold$fold, train_rows = nrow(train), test_rows = nrow(test),
                             maximum_train_exit = max(train$exit_session), test_start = fold$start,
                             embargo_pass = max(train$exit_session) < fold$start,
                             lambda = lambda, stringsAsFactors = FALSE)
  }
  list(predictions = do.call(rbind, predictions), coefficients = do.call(rbind, coefficients),
       trees = do.call(rbind, trees), folds = do.call(rbind, folds))
}

him042_prediction_metrics <- function(predictions) {
  rows <- lapply(split(predictions, predictions$model_id), function(x) {
    mse <- mean((x$actual_log_return - x$prediction)^2)
    baseline_mse <- mean((x$actual_log_return - x$baseline_prediction)^2)
    data.frame(
      model_id = x$model_id[[1L]], observations = nrow(x), mse = mse,
      baseline_mse = baseline_mse, mse_improvement = baseline_mse - mse,
      mae = mean(abs(x$actual_log_return - x$prediction)),
      baseline_mae = mean(abs(x$actual_log_return - x$baseline_prediction)),
      correlation = suppressWarnings(stats::cor(x$actual_log_return, x$prediction)),
      permission_fraction = mean(x$permit),
      permitted_mean_return = if (any(x$permit)) mean(x$actual_simple_return[x$permit]) else NA_real_,
      rejected_mean_return = if (any(!x$permit)) mean(x$actual_simple_return[!x$permit]) else NA_real_,
      stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL; out
}

him042_policy_replay <- function(ledger, position, bps, policy) {
  x <- ledger[order(ledger$entry_session), , drop = FALSE]
  position <- as.integer(position[match(x$row_id, ledger$row_id)])
  if (length(position) != nrow(x) || any(!position %in% 0:1)) him042_stop("Invalid policy position vector.")
  cost <- as.numeric(bps) / 10000
  wealth <- 1; previous <- 0L
  curve <- vector("list", nrow(x))
  for (i in seq_len(nrow(x))) {
    start_wealth <- wealth
    transition <- abs(position[[i]] - previous)
    if (transition) wealth <- wealth * (1 - cost)^transition
    if (position[[i]] == 1L) wealth <- wealth * (1 + x$actual_simple_return[[i]])
    curve[[i]] <- data.frame(
      row_id = x$row_id[[i]], policy = policy, entry_session = x$entry_session[[i]],
      exit_session = x$exit_session[[i]], entry_open = x$entry_open[[i]],
      position = position[[i]], transition = transition,
      interval_multiplier = wealth / start_wealth, wealth = wealth,
      tsla_interval_return = x$actual_simple_return[[i]], stringsAsFactors = FALSE)
    previous <- position[[i]]
  }
  curve <- do.call(rbind, curve)
  if (previous == 1L) {
    curve$wealth[[nrow(curve)]] <- curve$wealth[[nrow(curve)]] * (1 - cost)
    curve$interval_multiplier[[nrow(curve)]] <- curve$interval_multiplier[[nrow(curve)]] * (1 - cost)
  }
  equity <- c(1, curve$wealth)
  drawdown <- equity / cummax(equity) - 1
  positive <- curve$tsla_interval_return > 0
  negative <- curve$tsla_interval_return < 0
  upside_capture <- if (any(positive)) sum(curve$position[positive] * curve$tsla_interval_return[positive]) /
    sum(curve$tsla_interval_return[positive]) else NA_real_
  downside_capture <- if (any(negative)) sum(curve$position[negative] * abs(curve$tsla_interval_return[negative])) /
    sum(abs(curve$tsla_interval_return[negative])) else NA_real_
  quarter <- paste0(format(curve$entry_session, "%Y"), "Q",
                    (as.integer(format(curve$entry_session, "%m")) - 1L) %/% 3L + 1L)
  quarter_multiplier <- tapply(curve$interval_multiplier, quarter, prod)
  years <- length(unique(format(curve$entry_session, "%Y")))
  one_way <- sum(curve$transition) + as.integer(previous == 1L)
  summary <- data.frame(
    policy = policy, bps_per_side = bps, total_return = tail(curve$wealth, 1L) - 1,
    maximum_drawdown = min(drawdown), exposure = mean(curve$position),
    entries = sum(curve$transition == 1L & curve$position == 1L),
    annual_one_way_turnover = one_way / years,
    upside_capture = upside_capture, downside_capture = downside_capture,
    positive_quarters = sum(quarter_multiplier > 1), quarter_count = length(quarter_multiplier),
    stringsAsFactors = FALSE)
  list(summary = summary, curve = curve,
       quarterly = data.frame(policy = policy, quarter = names(quarter_multiplier),
                              return = as.numeric(quarter_multiplier) - 1, stringsAsFactors = FALSE))
}

him042_circular_shift <- function(x, offset) {
  n <- length(x); offset <- as.integer(offset %% n)
  if (!offset) return(x)
  c(tail(x, offset), head(x, n - offset))
}

him042_matched_permission <- function(primary_predictions, simulation, seed = him042_contract()$random_seed) {
  set.seed(seed + as.integer(simulation))
  out <- primary_predictions$permit
  for (fold in unique(primary_predictions$fold)) {
    index <- which(primary_predictions$fold == fold)
    if (length(index) > 1L) out[index] <- him042_circular_shift(out[index], sample.int(length(index) - 1L, 1L))
  }
  out
}

him042_synthetic_suite <- function(contract = him042_contract()) {
  set.seed(contract$random_seed)
  n <- 1200L
  x <- matrix(stats::rnorm(n * length(him042_feature_names())), nrow = n)
  colnames(x) <- him042_feature_names()
  train <- 1:800; test <- 801:1200
  linear_y <- .012 * x[, 1L] + .009 * x[, 3L] - .010 * x[, 6L] + stats::rnorm(n, sd = .002)
  ridge <- him042_ridge_fit(x[train, , drop = FALSE], linear_y[train], 1)
  ridge_prediction <- him042_ridge_predict(ridge, x[test, , drop = FALSE])
  ridge_mse <- mean((linear_y[test] - ridge_prediction)^2)
  ridge_baseline <- mean((linear_y[test] - mean(linear_y[train]))^2)
  tree_y <- ifelse(x[, 1L] > 0 & x[, 3L] > 0, .025, -.006) + stats::rnorm(n, sd = .002)
  tree <- him042_tree_fit(x[train, , drop = FALSE], tree_y[train], contract)
  tree_prediction <- him042_tree_predict(tree, x[test, , drop = FALSE])
  tree_mse <- mean((tree_y[test] - tree_prediction)^2)
  tree_baseline <- mean((tree_y[test] - mean(tree_y[train]))^2)
  data.frame(
    control = c("RIDGE_LINEAR_PLANT", "TREE_CONJUNCTION_PLANT"),
    model_mse = c(ridge_mse, tree_mse), baseline_mse = c(ridge_baseline, tree_baseline),
    improvement_fraction = 1 - c(ridge_mse, tree_mse) / c(ridge_baseline, tree_baseline),
    gate_pass = c(ridge_mse < .25 * ridge_baseline, tree_mse < .50 * tree_baseline),
    stringsAsFactors = FALSE)
}
