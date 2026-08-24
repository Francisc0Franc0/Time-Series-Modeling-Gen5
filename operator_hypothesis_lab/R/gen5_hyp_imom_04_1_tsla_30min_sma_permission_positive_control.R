him041_stop <- function(message) {
  stop(paste0("[HYP-IMOM-04.1] ", message), call. = FALSE)
}

him041_contract <- function() list(
  attempt_id = "CAL-A01",
  as_of_timestamp = "2026-08-13 17:30:00 America/New_York",
  development_start = as.Date("2018-01-02"),
  calibration_start = as.Date("2021-01-01"),
  development_end = as.Date("2023-12-29"),
  confirmation_start = as.Date("2024-01-02"),
  primary_bps = 10,
  stress_bps = 20,
  initial_wealth = 100000,
  maintenance_ratio = .25,
  quantile_grid = c(.25, .35, .45, .50, .55, .65, .75),
  min_leaf = 20L,
  min_participation = .25,
  inner_blocks = 4L,
  simulations = 200L,
  random_seed = 104041L,
  probability_epsilon = 1e-6
)

him041_variant_registry <- function() data.frame(
  variant_id = c("T", "V", "I", "W", "P", "M", "T_AND_V", "I_AND_W", "T_AND_P"),
  family = c(rep("UNIVARIATE", 6), rep("AND_GATE", 3)),
  feature_1 = c("asset_trend", "atr_percentile", "cross_impulse", "whipsaw_count",
                "participation_surprise", "market_trend", "asset_trend",
                "cross_impulse", "asset_trend"),
  direction_1 = c("HIGHER", "HIGHER", "HIGHER", "LOWER", "HIGHER", "HIGHER",
                  "HIGHER", "HIGHER", "HIGHER"),
  feature_2 = c(rep(NA_character_, 6), "atr_percentile", "whipsaw_count",
                "participation_surprise"),
  direction_2 = c(rep(NA_character_, 6), "HIGHER", "LOWER", "HIGHER"),
  stringsAsFactors = FALSE
)

him041_wilder_atr <- function(high, low, close, n = 14L) {
  n <- as.integer(n)
  previous_close <- c(NA_real_, head(close, -1L))
  true_range <- pmax(high - low, abs(high - previous_close), abs(low - previous_close), na.rm = TRUE)
  true_range[[1L]] <- high[[1L]] - low[[1L]]
  out <- rep(NA_real_, length(close))
  if (length(close) < n) return(out)
  out[[n]] <- mean(true_range[seq_len(n)])
  if (length(close) > n) {
    for (i in (n + 1L):length(close)) out[[i]] <- ((n - 1) * out[[i - 1L]] + true_range[[i]]) / n
  }
  out
}

him041_causal_percentile <- function(x, lookback = 252L) {
  lookback <- as.integer(lookback)
  out <- rep(NA_real_, length(x))
  if (length(x) <= lookback) return(out)
  for (i in (lookback + 1L):length(x)) {
    history <- x[(i - lookback):(i - 1L)]
    if (is.finite(x[[i]]) && all(is.finite(history))) out[[i]] <- mean(history <= x[[i]])
  }
  out
}

him041_daily_state <- function(tsla_daily, qqq_daily, contract = him041_contract()) {
  required <- c("session_date", "open", "high", "low", "close", "volume")
  if (!all(required %in% names(tsla_daily)) || !all(required %in% names(qqq_daily))) {
    him041_stop("Daily state inputs are incomplete.")
  }
  build <- function(x, symbol) {
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    x$session_date <- as.Date(x$session_date)
    if (anyDuplicated(x$session_date) || any(x$session_date >= contract$confirmation_start)) {
      him041_stop(paste(symbol, "daily state contains duplicate or confirmation sessions."))
    }
    sma200 <- imom_sma(x$close, 200L)
    atr14 <- him041_wilder_atr(x$high, x$low, x$close, 14L)
    atr_pct <- atr14 / x$close
    data.frame(
      session_date = x$session_date,
      trend = x$close / sma200 - 1,
      atr_pct = atr_pct,
      atr_percentile = him041_causal_percentile(atr_pct, 252L),
      stringsAsFactors = FALSE
    )
  }
  tsla <- build(tsla_daily, "TSLA")
  qqq <- build(qqq_daily, "QQQ")
  names(qqq)[names(qqq) == "trend"] <- "market_trend"
  qqq <- qqq[c("session_date", "market_trend")]
  out <- merge(tsla, qqq, by = "session_date", all.x = TRUE, sort = TRUE)
  out[order(out$session_date), , drop = FALSE]
}

him041_build_feature_panel <- function(tsla_bars, daily_state, contract = him041_contract()) {
  required <- c("symbol", "timestamp_utc", "session_date", "bar_slot", "open", "high",
                "low", "close", "volume")
  if (!all(required %in% names(tsla_bars))) him041_stop("TSLA feature bars are incomplete.")
  x <- tsla_bars[order(tsla_bars$timestamp_utc), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  if (length(unique(x$symbol)) != 1L || unique(x$symbol) != "TSLA") him041_stop("Feature panel must contain TSLA only.")
  if (anyDuplicated(x$timestamp_utc) || any(x$session_date >= contract$confirmation_start)) {
    him041_stop("Feature panel contains duplicate or confirmation bars.")
  }
  x$panel_row_id <- seq_len(nrow(x))
  x$fast <- imom_sma(x$close, 8L)
  x$slow <- imom_sma(x$close, 14L)
  x$above <- is.finite(x$slow) & x$fast > x$slow
  spread <- x$fast - x$slow
  x$cross_impulse <- (spread - c(NA_real_, NA_real_, head(spread, -2L))) / x$close
  x$whipsaw_count <- NA_real_
  for (i in seq_len(nrow(x))) {
    if (i > 26L) {
      states <- x$above[(i - 26L):(i - 1L)]
      x$whipsaw_count[[i]] <- sum(states[-1L] != head(states, -1L))
    }
  }
  x$dollar_volume <- x$close * x$volume
  x$participation_surprise <- NA_real_
  for (slot in sort(unique(x$bar_slot))) {
    idx <- which(x$bar_slot == slot)
    if (length(idx) > 20L) {
      for (k in 21L:length(idx)) {
        i <- idx[[k]]
        history <- x$dollar_volume[idx[(k - 20L):(k - 1L)]]
        if (all(is.finite(history)) && median(history) > 0) {
          x$participation_surprise[[i]] <- x$dollar_volume[[i]] / median(history) - 1
        }
      }
    }
  }
  session_max <- ave(x$bar_slot, x$session_date, FUN = max)
  x$bars_remaining_in_session <- as.integer(session_max - x$bar_slot)
  state_position <- match(x$session_date, daily_state$session_date) - 1L
  valid <- state_position >= 1L
  x$asset_trend <- x$atr_percentile <- x$market_trend <- NA_real_
  x$prior_state_date <- as.Date(NA)
  x$asset_trend[valid] <- daily_state$trend[state_position[valid]]
  x$atr_percentile[valid] <- daily_state$atr_percentile[state_position[valid]]
  x$market_trend[valid] <- daily_state$market_trend[state_position[valid]]
  x$prior_state_date[valid] <- daily_state$session_date[state_position[valid]]
  x
}

him041_extract_parent_events <- function(feature_panel, contract = him041_contract()) {
  x <- feature_panel[order(feature_panel$timestamp_utc), , drop = FALSE]
  events <- list(); z <- 1L
  for (year in 2018:2023) {
    start <- as.Date(sprintf("%d-01-01", year))
    end <- min(as.Date(sprintf("%d-12-31", year)), contract$development_end)
    w_idx <- which(x$session_date >= start & x$session_date <= end)
    if (!length(w_idx)) next
    schedule <- imom_sma_schedule(x, start, end, 8L, 14L, 0L)
    target <- as.logical(schedule$target)
    starts <- which(target & !c(FALSE, head(target, -1L)))
    open_exits <- which(!target & c(FALSE, head(target, -1L)))
    for (s in starts) {
      later_exits <- open_exits[open_exits > s]
      forced <- !length(later_exits)
      e <- if (forced) length(w_idx) else later_exits[[1L]]
      signal_local <- s - 1L
      if (signal_local < 1L) him041_stop("Parent entry lacks a completed signal bar.")
      signal_global <- w_idx[[signal_local]]
      entry_global <- w_idx[[s]]
      exit_global <- w_idx[[e]]
      exit_price <- if (forced) x$close[[exit_global]] else x$open[[exit_global]]
      primary <- imom_trade_multiplier(x$open[[entry_global]], exit_price,
        x$timestamp_utc[[entry_global]], x$timestamp_utc[[exit_global]], 1,
        contract$primary_bps, 0)
      gross <- imom_trade_multiplier(x$open[[entry_global]], exit_price,
        x$timestamp_utc[[entry_global]], x$timestamp_utc[[exit_global]], 1, 0, 0)
      stress <- imom_trade_multiplier(x$open[[entry_global]], exit_price,
        x$timestamp_utc[[entry_global]], x$timestamp_utc[[exit_global]], 1,
        contract$stress_bps, 0)
      delayed_return <- NA_real_
      delayed_entry <- s + 1L
      delayed_exit <- if (forced) e else e + 1L
      if (delayed_entry < delayed_exit && delayed_entry <= length(w_idx) && delayed_exit <= length(w_idx)) {
        delayed_exit_price <- if (forced) x$close[w_idx[[delayed_exit]]] else x$open[w_idx[[delayed_exit]]]
        delayed_return <- imom_trade_multiplier(x$open[w_idx[[delayed_entry]]], delayed_exit_price,
          x$timestamp_utc[w_idx[[delayed_entry]]], x$timestamp_utc[w_idx[[delayed_exit]]],
          1, contract$primary_bps, 0) - 1
      }
      events[[z]] <- data.frame(
        event_id = sprintf("TSLA_%d_%04d", year, z), year = year,
        signal_timestamp = x$timestamp_utc[[signal_global]],
        signal_date = x$session_date[[signal_global]],
        signal_bar_slot = x$bar_slot[[signal_global]],
        bars_remaining_in_session = x$bars_remaining_in_session[[signal_global]],
        entry_timestamp = x$timestamp_utc[[entry_global]],
        entry_date = x$session_date[[entry_global]],
        entry_price = x$open[[entry_global]],
        exit_timestamp = x$timestamp_utc[[exit_global]],
        exit_date = x$session_date[[exit_global]],
        exit_price = exit_price, forced_exit = forced,
        holding_bars = e - s, overnight = x$session_date[[exit_global]] > x$session_date[[entry_global]],
        gross_return = gross - 1, primary_return = primary - 1,
        stress_return = stress - 1, delay1_return = delayed_return,
        profitable = as.integer(primary > 1),
        asset_trend = x$asset_trend[[signal_global]],
        atr_percentile = x$atr_percentile[[signal_global]],
        cross_impulse = x$cross_impulse[[signal_global]],
        whipsaw_count = x$whipsaw_count[[signal_global]],
        participation_surprise = x$participation_surprise[[signal_global]],
        market_trend = x$market_trend[[signal_global]],
        prior_state_date = x$prior_state_date[[signal_global]],
        signal_panel_row_id = x$panel_row_id[[signal_global]],
        parent_start_local = s, parent_exit_local = e,
        stringsAsFactors = FALSE
      )
      z <- z + 1L
    }
  }
  if (!length(events)) him041_stop("Parent event ledger is empty.")
  out <- do.call(rbind, events)
  out <- out[order(out$signal_timestamp), , drop = FALSE]
  rownames(out) <- NULL
  out
}

him041_feature_names <- function() c("asset_trend", "atr_percentile", "cross_impulse",
                                     "whipsaw_count", "participation_surprise", "market_trend")

him041_eligible_events <- function(events) {
  features <- him041_feature_names()
  events$feature_complete <- complete.cases(events[features])
  events$eligibility_reason <- ifelse(events$feature_complete, "ELIGIBLE", "CAUSAL_HISTORY_INCOMPLETE")
  events
}

him041_apply_rule <- function(x, threshold, direction) {
  if (direction == "HIGHER") x >= threshold else x <= threshold
}

him041_clip <- function(p, epsilon = him041_contract()$probability_epsilon) {
  pmin(1 - epsilon, pmax(epsilon, p))
}

him041_inner_splits <- function(n, blocks = 4L) {
  if (n < 100L) return(list())
  first_end <- max(60L, floor(.50 * n))
  cuts <- unique(as.integer(floor(seq(first_end, n, length.out = blocks + 1L))))
  if (length(cuts) < 2L) return(list())
  lapply(seq_len(length(cuts) - 1L), function(i) {
    list(train = seq_len(cuts[[i]]), validation = (cuts[[i]] + 1L):cuts[[i + 1L]])
  })
}

him041_leaf_fit <- function(y, permit, contract = him041_contract()) {
  n_permit <- sum(permit); n_reject <- sum(!permit)
  admissible <- n_permit >= contract$min_leaf && n_reject >= contract$min_leaf &&
    mean(permit) >= contract$min_participation
  p_permit <- if (n_permit) mean(y[permit]) else NA_real_
  p_reject <- if (n_reject) mean(y[!permit]) else NA_real_
  admissible <- admissible && is.finite(p_permit) && is.finite(p_reject) && p_permit > p_reject
  list(admissible = admissible, p_permit = p_permit, p_reject = p_reject,
       n_permit = n_permit, n_reject = n_reject, participation = mean(permit))
}

him041_fit_univariate <- function(train, feature, direction, contract = him041_contract()) {
  train <- train[order(train$signal_timestamp), , drop = FALSE]
  if (!all(is.finite(train[[feature]])) || !all(train$profitable %in% 0:1)) {
    him041_stop(paste("Invalid TRAIN data for", feature))
  }
  splits <- him041_inner_splits(nrow(train), contract$inner_blocks)
  candidates <- list()
  for (q in contract$quantile_grid) {
    losses <- numeric(); valid_candidate <- length(splits) > 0L
    for (split in splits) {
      inner <- train[split$train, , drop = FALSE]
      validation <- train[split$validation, , drop = FALSE]
      threshold <- as.numeric(stats::quantile(inner[[feature]], q, names = FALSE, type = 8))
      permit <- him041_apply_rule(inner[[feature]], threshold, direction)
      leaf <- him041_leaf_fit(inner$profitable, permit, contract)
      if (!leaf$admissible) { valid_candidate <- FALSE; break }
      val_permit <- him041_apply_rule(validation[[feature]], threshold, direction)
      prediction <- ifelse(val_permit, leaf$p_permit, leaf$p_reject)
      losses <- c(losses, (validation$profitable - prediction)^2)
    }
    if (valid_candidate && length(losses)) {
      full_threshold <- as.numeric(stats::quantile(train[[feature]], q, names = FALSE, type = 8))
      full_permit <- him041_apply_rule(train[[feature]], full_threshold, direction)
      full_leaf <- him041_leaf_fit(train$profitable, full_permit, contract)
      if (full_leaf$admissible) candidates[[length(candidates) + 1L]] <- data.frame(
        quantile = q, threshold = full_threshold, inner_brier = mean(losses),
        participation = full_leaf$participation, p_permit = full_leaf$p_permit,
        p_reject = full_leaf$p_reject, n_permit = full_leaf$n_permit,
        n_reject = full_leaf$n_reject, stringsAsFactors = FALSE)
    }
  }
  if (!length(candidates)) return(list(admissible = FALSE, feature = feature,
    direction = direction, threshold = NA_real_, quantile = NA_real_, p_permit = mean(train$profitable),
    p_reject = mean(train$profitable), participation = 0, inner_brier = NA_real_))
  table <- do.call(rbind, candidates)
  table <- table[order(table$inner_brier, -table$participation, table$quantile), , drop = FALSE]
  best <- table[1L, , drop = FALSE]
  list(admissible = TRUE, feature = feature, direction = direction,
       threshold = best$threshold[[1L]], quantile = best$quantile[[1L]],
       p_permit = best$p_permit[[1L]], p_reject = best$p_reject[[1L]],
       participation = best$participation[[1L]], inner_brier = best$inner_brier[[1L]],
       candidate_table = table)
}

him041_fit_atlas <- function(train, contract = him041_contract(), registry = him041_variant_registry()) {
  train <- train[order(train$signal_timestamp), , drop = FALSE]
  models <- list()
  univariate <- registry[registry$family == "UNIVARIATE", , drop = FALSE]
  for (i in seq_len(nrow(univariate))) {
    row <- univariate[i, ]
    model <- him041_fit_univariate(train, row$feature_1, row$direction_1, contract)
    model$variant_id <- row$variant_id
    model$family <- "UNIVARIATE"
    models[[row$variant_id]] <- model
  }
  combinations <- registry[registry$family == "AND_GATE", , drop = FALSE]
  for (i in seq_len(nrow(combinations))) {
    row <- combinations[i, ]
    component_ids <- strsplit(row$variant_id, "_AND_", fixed = TRUE)[[1L]]
    first <- models[[component_ids[[1L]]]]; second <- models[[component_ids[[2L]]]]
    admissible <- isTRUE(first$admissible) && isTRUE(second$admissible)
    permit <- rep(FALSE, nrow(train))
    if (admissible) {
      permit <- him041_apply_rule(train[[row$feature_1]], first$threshold, row$direction_1) &
        him041_apply_rule(train[[row$feature_2]], second$threshold, row$direction_2)
      leaf <- him041_leaf_fit(train$profitable, permit, contract)
      admissible <- leaf$admissible
    } else leaf <- list(p_permit = mean(train$profitable), p_reject = mean(train$profitable),
                        participation = 0, n_permit = 0, n_reject = nrow(train))
    models[[row$variant_id]] <- list(
      admissible = admissible, variant_id = row$variant_id, family = "AND_GATE",
      feature = row$feature_1, direction = row$direction_1,
      feature_2 = row$feature_2, direction_2 = row$direction_2,
      threshold = first$threshold, threshold_2 = second$threshold,
      quantile = first$quantile, quantile_2 = second$quantile,
      p_permit = if (admissible) leaf$p_permit else mean(train$profitable),
      p_reject = if (admissible) leaf$p_reject else mean(train$profitable),
      participation = if (admissible) leaf$participation else 0,
      inner_brier = NA_real_)
  }
  models
}

him041_predict_model <- function(model, newdata) {
  if (!isTRUE(model$admissible)) return(data.frame(permit = FALSE,
    probability = rep(model$p_reject, nrow(newdata))))
  permit <- him041_apply_rule(newdata[[model$feature]], model$threshold, model$direction)
  if (identical(model$family, "AND_GATE")) {
    permit <- permit & him041_apply_rule(newdata[[model$feature_2]], model$threshold_2, model$direction_2)
  }
  data.frame(permit = permit, probability = ifelse(permit, model$p_permit, model$p_reject))
}

him041_oof_predictions <- function(events, contract = him041_contract(), registry = him041_variant_registry()) {
  events <- events[events$feature_complete, , drop = FALSE]
  folds <- imom_quarters()
  predictions <- list(); thresholds <- list(); pz <- tz <- 1L
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, ]
    train <- events[events$signal_date >= contract$development_start &
      events$exit_date <= fold$train_end, , drop = FALSE]
    test <- events[events$signal_date >= fold$test_start & events$signal_date <= fold$test_end, , drop = FALSE]
    if (nrow(train) < 100L || !nrow(test)) next
    models <- him041_fit_atlas(train, contract, registry)
    intercept <- mean(train$profitable)
    for (variant_id in registry$variant_id) {
      model <- models[[variant_id]]
      scored <- him041_predict_model(model, test)
      predictions[[pz]] <- data.frame(
        fold = fold$fold, variant_id = variant_id, event_id = test$event_id,
        signal_timestamp = test$signal_timestamp, signal_date = test$signal_date,
        profitable = test$profitable, primary_return = test$primary_return,
        stress_return = test$stress_return, gross_return = test$gross_return,
        delay1_return = test$delay1_return, overnight = test$overnight,
        permit = scored$permit, probability = scored$probability,
        intercept_probability = intercept, stringsAsFactors = FALSE)
      thresholds[[tz]] <- data.frame(
        fold = fold$fold, variant_id = variant_id, admissible = model$admissible,
        train_events = nrow(train), threshold_1 = model$threshold,
        threshold_2 = if (!is.null(model$threshold_2)) model$threshold_2 else NA_real_,
        quantile_1 = model$quantile,
        quantile_2 = if (!is.null(model$quantile_2)) model$quantile_2 else NA_real_,
        train_participation = model$participation, train_p_permit = model$p_permit,
        train_p_reject = model$p_reject, inner_brier = model$inner_brier,
        stringsAsFactors = FALSE)
      pz <- pz + 1L; tz <- tz + 1L
    }
  }
  list(predictions = do.call(rbind, predictions), thresholds = do.call(rbind, thresholds))
}

him041_auc <- function(y, score) {
  positive <- sum(y == 1); negative <- sum(y == 0)
  if (!positive || !negative) return(NA_real_)
  (sum(rank(score, ties.method = "average")[y == 1]) - positive * (positive + 1) / 2) /
    (positive * negative)
}

him041_prediction_metrics <- function(predictions, contract = him041_contract()) {
  rows <- lapply(split(predictions, predictions$variant_id), function(x) {
    permit <- as.logical(x$permit)
    data.frame(
      variant_id = x$variant_id[[1L]], events = nrow(x),
      brier = mean((x$profitable - x$probability)^2),
      intercept_brier = mean((x$profitable - x$intercept_probability)^2),
      brier_improvement = mean((x$profitable - x$intercept_probability)^2) -
        mean((x$profitable - x$probability)^2),
      log_loss = -mean(x$profitable * log(him041_clip(x$probability, contract$probability_epsilon)) +
        (1 - x$profitable) * log(him041_clip(1 - x$probability, contract$probability_epsilon))),
      auc = him041_auc(x$profitable, x$probability),
      permitted_fraction = mean(permit), permitted_events = sum(permit),
      permitted_win_rate = if (any(permit)) mean(x$profitable[permit]) else NA_real_,
      rejected_win_rate = if (any(!permit)) mean(x$profitable[!permit]) else NA_real_,
      permitted_mean_return = if (any(permit)) mean(x$primary_return[permit]) else NA_real_,
      rejected_mean_return = if (any(!permit)) mean(x$primary_return[!permit]) else NA_real_,
      parent_mean_return = mean(x$primary_return), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out[order(-out$brier_improvement, -out$permitted_mean_return), , drop = FALSE]
}

him041_shift_event_features <- function(events, feature_panel, shift_sessions) {
  sessions <- sort(unique(feature_panel$session_date))
  target_rank <- match(events$signal_date, sessions)
  source_rank <- ((target_rank - as.integer(shift_sessions) - 1L) %% length(sessions)) + 1L
  source_date <- sessions[source_rank]
  panel_key <- paste(feature_panel$session_date, feature_panel$bar_slot, sep = "|")
  source_key <- paste(source_date, events$signal_bar_slot, sep = "|")
  source_index <- match(source_key, panel_key)
  out <- events
  for (feature in him041_feature_names()) out[[feature]] <- feature_panel[[feature]][source_index]
  out$prior_state_date <- feature_panel$prior_state_date[source_index]
  out$feature_complete <- complete.cases(out[him041_feature_names()])
  out
}

him041_compound_return <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(0)
  prod(1 + x) - 1
}

him041_trade_close_drawdown <- function(x) {
  wealth <- cumprod(c(1, 1 + x[is.finite(x)]))
  min(wealth / cummax(wealth) - 1)
}

him041_policy_summary <- function(prediction_rows, return_column = "primary_return") {
  x <- prediction_rows[as.logical(prediction_rows$permit), , drop = FALSE]
  returns <- x[[return_column]]
  data.frame(
    scenario = return_column, total_return = him041_compound_return(returns),
    trade_close_drawdown = him041_trade_close_drawdown(returns), trade_count = nrow(x),
    hit_rate = if (nrow(x)) mean(returns > 0, na.rm = TRUE) else NA_real_,
    mean_trade = if (nrow(x)) mean(returns, na.rm = TRUE) else NA_real_,
    median_trade = if (nrow(x)) median(returns, na.rm = TRUE) else NA_real_,
    overnight_fraction = if (nrow(x)) mean(x$overnight) else NA_real_,
    overnight_compound_return = if (nrow(x)) him041_compound_return(returns[x$overnight]) else 0,
    same_session_compound_return = if (nrow(x)) him041_compound_return(returns[!x$overnight]) else 0,
    stringsAsFactors = FALSE)
}

him041_replay_permissions <- function(feature_panel, events, permission_by_event,
                                      cost_bps = him041_contract()$primary_bps,
                                      scenario = "PRIMARY", contract = him041_contract()) {
  x <- feature_panel[order(feature_panel$timestamp_utc), , drop = FALSE]
  if (is.null(names(permission_by_event))) him041_stop("Permission vector must be named by event_id.")
  paths <- list(); trades <- list(); yearly <- list(); wealth_scale <- 1
  pz <- tz <- yz <- 1L
  for (year in 2021:2023) {
    start <- as.Date(sprintf("%d-01-01", year))
    end <- min(as.Date(sprintf("%d-12-31", year)), contract$development_end)
    schedule <- imom_sma_schedule(x, start, end, 8L, 14L, 0L)
    year_events <- events[events$year == year, , drop = FALSE]
    for (i in seq_len(nrow(year_events))) {
      event_id <- year_events$event_id[[i]]
      permitted <- isTRUE(permission_by_event[[event_id]])
      if (!permitted) {
        first <- year_events$parent_start_local[[i]]
        last <- year_events$parent_exit_local[[i]] - 1L
        if (last >= first) schedule$target[first:last] <- FALSE
      }
    }
    schedule$entry_signal <- schedule$target & !c(FALSE, head(schedule$target, -1L))
    schedule$exit_signal <- !schedule$target & c(FALSE, head(schedule$target, -1L))
    replay <- imom_replay(x, start, end, schedule, 1, cost_bps, 0, scenario, 3276L, contract)
    path <- replay$path
    path$equity <- path$equity * wealth_scale
    wealth_scale <- tail(path$equity, 1L) / contract$initial_wealth
    paths[[pz]] <- path; pz <- pz + 1L
    if (nrow(replay$trades)) { trades[[tz]] <- replay$trades; tz <- tz + 1L }
    yearly[[yz]] <- replay$summary; yearly[[yz]]$year <- year; yz <- yz + 1L
  }
  path <- do.call(rbind, paths)
  trade_table <- if (length(trades)) do.call(rbind, trades) else data.frame()
  year_table <- do.call(rbind, yearly)
  summary <- data.frame(
    policy = scenario, total_return = tail(path$equity, 1L) / contract$initial_wealth - 1,
    maximum_drawdown = imom_max_drawdown(path$equity), exposure = mean(path$target),
    mean_annual_turnover = mean(year_table$turnover), trade_count = nrow(trade_table),
    hit_rate = if (nrow(trade_table)) mean(trade_table$net_return > 0) else NA_real_,
    mean_trade = if (nrow(trade_table)) mean(trade_table$net_return) else NA_real_,
    median_trade = if (nrow(trade_table)) median(trade_table$net_return) else NA_real_,
    median_holding_bars = if (nrow(trade_table)) median(trade_table$holding_bars) else NA_real_,
    stringsAsFactors = FALSE)
  list(summary = summary, path = path, trades = trade_table, yearly = year_table)
}

him041_synthetic_suite <- function(contract = him041_contract(), registry = him041_variant_registry()) {
  results <- list()
  for (case_index in seq_len(nrow(registry))) {
    planted <- registry$variant_id[[case_index]]
    set.seed(contract$random_seed + case_index)
    n <- 4000L
    data <- data.frame(
      signal_timestamp = as.POSIXct("2010-01-01", tz = "UTC") + seq_len(n) * 86400,
      asset_trend = runif(n, -1, 1), atr_percentile = runif(n, -1, 1),
      cross_impulse = runif(n, -1, 1), whipsaw_count = runif(n, -1, 1),
      participation_surprise = runif(n, -1, 1), market_trend = runif(n, -1, 1),
      stringsAsFactors = FALSE)
    row <- registry[registry$variant_id == planted, , drop = FALSE]
    boundary_1 <- if (row$family == "AND_GATE") {
      if (row$direction_1 == "HIGHER") -.2 else .2
    } else 0
    boundary_2 <- if (row$family == "AND_GATE") {
      if (row$direction_2 == "HIGHER") -.2 else .2
    } else NA_real_
    permit <- him041_apply_rule(data[[row$feature_1]], boundary_1, row$direction_1)
    if (row$family == "AND_GATE") {
      permit <- permit & him041_apply_rule(data[[row$feature_2]], boundary_2, row$direction_2)
    }
    probability <- ifelse(permit, .76, .24)
    data$profitable <- rbinom(n, 1, probability)
    magnitude <- pmax(.001, rnorm(n, .011, .004))
    data$primary_return <- ifelse(data$profitable == 1, magnitude, -pmax(.001, rnorm(n, .009, .004)))
    train <- data[seq_len(3000L), , drop = FALSE]
    test <- data[3001:4000, , drop = FALSE]
    models <- him041_fit_atlas(train, contract, registry)
    metrics <- lapply(registry$variant_id, function(variant_id) {
      scored <- him041_predict_model(models[[variant_id]], test)
      data.frame(variant_id = variant_id,
        improvement = mean((test$profitable - mean(train$profitable))^2) -
          mean((test$profitable - scored$probability)^2),
        permitted_mean_return = if (any(scored$permit)) mean(test$primary_return[scored$permit]) else NA_real_,
        permitted_fraction = mean(scored$permit), stringsAsFactors = FALSE)
    })
    metrics <- do.call(rbind, metrics)
    selected <- metrics$variant_id[[which.max(metrics$improvement)]]
    selected_model <- models[[planted]]
    threshold_error <- abs(selected_model$threshold - boundary_1)
    if (!is.null(selected_model$threshold_2)) threshold_error <- max(threshold_error,
      abs(selected_model$threshold_2 - boundary_2))
    result <- metrics[metrics$variant_id == selected, , drop = FALSE]
    results[[case_index]] <- data.frame(
      planted_variant = planted, selected_variant = selected,
      exact_recovery = selected == planted, selected_brier_improvement = result$improvement,
      planted_threshold_error = threshold_error,
      selected_permitted_mean_return = result$permitted_mean_return,
      parent_mean_return = mean(test$primary_return),
      gate_pass = selected == planted && result$improvement > 0 && threshold_error <= .35 &&
        result$permitted_mean_return > mean(test$primary_return), stringsAsFactors = FALSE)
  }
  do.call(rbind, results)
}
