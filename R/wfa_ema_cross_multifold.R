# Gen5.1 multi-signal WFA proof of concept.

g5_ema_cross_wfa_multi_schema_version <- function() {
  "gen5_ema_cross_wfa_multi_v0.1"
}

g5_ema_cross_wfa_multi_artifact_prefix <- function(as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  window_label <- paste0(
    "w",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_start_date))),
    "_to_",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date)))
  )
  paste(c("multi_wfa", symbol, paste0(fold_count, "f"), window_label, stamp), collapse = "_")
}

g5_ema_cross_wfa_multi_output_dir <- function(repo_root, as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "wfa_pocs",
    g5_ema_cross_wfa_multi_artifact_prefix(as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count)
  )
}

g5_ema_cross_wfa_resolve_folds <- function(
  bars,
  symbol,
  wfa_start_date,
  wfa_end_date,
  train_quarters = 8,
  oos_quarters = 1,
  fold_count = 3L
) {
  fold_count <- as.integer(fold_count)
  if (is.na(fold_count) || fold_count < 1L) {
    g5_stop("fold_count must be a positive integer.")
  }
  train_days <- g5_ema_cross_wfa_quarters_to_days(train_quarters)
  oos_days <- g5_ema_cross_wfa_quarters_to_days(oos_quarters)
  window_bars <- g5_ema_cross_prepare_bars(bars, symbol = symbol, start_date = wfa_start_date, end_date = wfa_end_date)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  dates <- as.Date(window_bars$session_date)
  first_date <- min(dates)
  latest_date <- max(dates)
  folds <- list()
  for (fold_no in seq_len(fold_count)) {
    train_start_target <- first_date + (fold_no - 1L) * oos_days
    train_start_candidates <- dates[dates >= train_start_target]
    if (length(train_start_candidates) == 0L) {
      g5_stop(paste0("Insufficient data for fold ", fold_no, ": no train start session found."))
    }
    train_start_date <- min(train_start_candidates)
    train_end_target <- train_start_date + train_days - 1L
    if (fold_no == 1L && latest_date < train_end_target) {
      g5_stop(paste0(
        "Insufficient data for fold ",
        fold_no,
        ": latest available session ",
        latest_date,
        " is before required train end target ",
        train_end_target,
        "."
      ))
    }
    train_end_date <- if (fold_no == 1L) {
      max(dates[dates <= train_end_target])
    } else {
      as.Date(folds[[fold_no - 1L]]$oos_end_date[[1L]])
    }
    if (train_end_date < train_start_date) {
      g5_stop(paste0("Insufficient data for fold ", fold_no, ": rolling train window is empty."))
    }
    oos_start_candidates <- dates[dates > train_end_date]
    if (length(oos_start_candidates) == 0L) {
      g5_stop(paste0("Insufficient data for fold ", fold_no, ": no OOS session exists after the train window."))
    }
    oos_start_date <- min(oos_start_candidates)
    oos_end_target <- oos_start_date + oos_days - 1L
    if (latest_date < oos_end_target) {
      g5_stop(paste0(
        "Insufficient data for fold ",
        fold_no,
        ": latest available session ",
        latest_date,
        " is before required OOS end target ",
        oos_end_target,
        "."
      ))
    }
    oos_end_date <- max(dates[dates >= oos_start_date & dates <= oos_end_target])
    folds[[fold_no]] <- data.frame(
      schema_version = g5_ema_cross_wfa_multi_schema_version(),
      fold_id = sprintf("fold_%03d", fold_no),
      fold_no = fold_no,
      symbol = symbol,
      strategy_family = "ema_cross",
      wfa_start_date = as.Date(wfa_start_date),
      wfa_end_date = as.Date(wfa_end_date),
      train_quarters = train_quarters,
      oos_quarters = oos_quarters,
      train_days = train_days,
      oos_days = oos_days,
      train_start_date = train_start_date,
      train_end_target = train_end_target,
      train_end_date = train_end_date,
      oos_start_date = oos_start_date,
      oos_end_target = oos_end_target,
      oos_end_date = oos_end_date,
      train_session_count = sum(dates >= train_start_date & dates <= train_end_date),
      oos_session_count = sum(dates >= oos_start_date & dates <= oos_end_date),
      fold_policy = "rolling_train_window_step_by_oos_period",
      position_handoff_policy = "carry_open_positions_manage_with_current_fold_model",
      final_bar_signal_policy = "execute_next_open_if_next_session_is_inside_stitched_oos",
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, folds)
  rownames(out) <- NULL
  out
}

g5_wfa_bind_rows_fill <- function(rows) {
  rows <- Filter(function(x) is.data.frame(x) && nrow(x) > 0L, rows)
  if (length(rows) == 0L) {
    return(data.frame())
  }
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  aligned <- lapply(rows, function(row) {
    missing <- setdiff(cols, names(row))
    for (col in missing) {
      row[[col]] <- NA
    }
    row[, cols, drop = FALSE]
  })
  out <- do.call(rbind, aligned)
  rownames(out) <- NULL
  out
}

g5_wfa_candidate_families <- function(candidate_families) {
  candidate_families <- unique(trimws(as.character(candidate_families)))
  candidate_families <- candidate_families[nzchar(candidate_families)]
  allowed <- c("ema_cross", "bollinger_touch")
  if (length(candidate_families) == 0L || any(!candidate_families %in% allowed)) {
    g5_stop(paste0("candidate_families must be drawn from: ", paste(allowed, collapse = ", ")))
  }
  candidate_families
}

g5_wfa_model_parameter_label <- function(model) {
  family <- as.character(model$strategy_family[[1L]])
  if (identical(family, "ema_cross")) {
    return(paste0("fast=", model$fast_period[[1L]], ", slow=", model$slow_period[[1L]]))
  }
  if (identical(family, "bollinger_touch")) {
    return(paste0("lookback=", model$lookback_period[[1L]], ", sd=", model$sd_multiplier[[1L]]))
  }
  ""
}

g5_wfa_normalize_indicator_columns <- function(ind, model) {
  for (col in c("fast_ema", "slow_ema", "bb_mid", "bb_upper", "bb_lower")) {
    if (!col %in% names(ind)) {
      ind[[col]] <- NA_real_
    }
  }
  for (col in c("entry_signal", "exit_signal")) {
    if (!col %in% names(ind)) {
      ind[[col]] <- FALSE
    }
    ind[[col]][is.na(ind[[col]])] <- FALSE
  }
  ind$strategy_family <- as.character(model$strategy_family[[1L]])
  ind$model_instance_id <- as.character(model$model_instance_id[[1L]])
  ind
}

g5_wfa_model_indicators <- function(bars, symbol, model) {
  family <- as.character(model$strategy_family[[1L]])
  if (identical(family, "ema_cross")) {
    ind <- g5_ema_cross_indicators(
      bars,
      symbol = symbol,
      fast_period = model$fast_period[[1L]],
      slow_period = model$slow_period[[1L]]
    )
    entry <- rep(FALSE, nrow(ind))
    exit <- rep(FALSE, nrow(ind))
    if (nrow(ind) >= 2L) {
      for (i in 2:nrow(ind)) {
        has_inputs <- all(is.finite(c(ind$fast_ema[[i - 1L]], ind$slow_ema[[i - 1L]], ind$fast_ema[[i]], ind$slow_ema[[i]])))
        if (has_inputs) {
          entry[[i]] <- ind$fast_ema[[i - 1L]] <= ind$slow_ema[[i - 1L]] && ind$fast_ema[[i]] > ind$slow_ema[[i]]
          exit[[i]] <- ind$fast_ema[[i - 1L]] >= ind$slow_ema[[i - 1L]] && ind$fast_ema[[i]] < ind$slow_ema[[i]]
        }
      }
    }
    ind$entry_signal <- entry
    ind$exit_signal <- exit
    ind$entry_signal_rule <- "fast_ema_cross_above_slow_when_flat"
    ind$exit_signal_rule <- "fast_ema_cross_below_slow_when_long"
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  if (identical(family, "bollinger_touch")) {
    ind <- g5_bollinger_touch_indicators(
      bars,
      symbol = symbol,
      lookback_period = model$lookback_period[[1L]],
      sd_multiplier = model$sd_multiplier[[1L]]
    )
    ind$entry_signal_rule <- "lower_bollinger_band_touched_when_flat"
    ind$exit_signal_rule <- "upper_bollinger_band_touched_when_long"
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  g5_stop(paste0("Unsupported WFA strategy_family: ", family))
}

g5_ema_cross_wfa_select_fold_models <- function(
  bars,
  symbol,
  folds,
  fast_periods,
  slow_periods,
  bb_lookback_periods = c(10L, 20L, 30L),
  bb_sd_multipliers = c(1.5, 2, 2.5),
  candidate_families = c("ema_cross", "bollinger_touch")
) {
  candidate_families <- g5_wfa_candidate_families(candidate_families)
  rows <- list()
  grid_rows <- list()
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    evaluations <- list()
    if ("ema_cross" %in% candidate_families) {
      ema <- g5_ema_cross_evaluate_grid(
        bars,
        symbol = symbol,
        trading_start_date = fold$train_start_date[[1L]],
        trading_end_date = fold$train_end_date[[1L]],
        fast_periods = fast_periods,
        slow_periods = slow_periods,
        leverage = 1
      )
      ema$parameter_performance$strategy_family <- "ema_cross"
      ema$parameter_performance$model_instance_id <- ema$parameter_performance$strategy_id
      evaluations[["ema_cross"]] <- ema$parameter_performance
    }
    if ("bollinger_touch" %in% candidate_families) {
      bb <- g5_bollinger_touch_evaluate_grid(
        bars,
        symbol = symbol,
        trading_start_date = fold$train_start_date[[1L]],
        trading_end_date = fold$train_end_date[[1L]],
        lookback_periods = bb_lookback_periods,
        sd_multipliers = bb_sd_multipliers,
        leverage = 1
      )
      evaluations[["bollinger_touch"]] <- bb$parameter_performance
    }
    grid <- g5_wfa_bind_rows_fill(evaluations)
    grid <- grid[order(
      ifelse(is.na(grid$sharpe), -Inf, grid$sharpe),
      ifelse(is.na(grid$total_return), -Inf, grid$total_return),
      decreasing = TRUE
    ), , drop = FALSE]
    selected <- grid[1L, , drop = FALSE]
    rows[[i]] <- data.frame(
      schema_version = g5_ema_cross_wfa_multi_schema_version(),
      fold_id = fold$fold_id[[1L]],
      fold_no = fold$fold_no[[1L]],
      symbol = fold$symbol[[1L]],
      strategy_family = selected$strategy_family[[1L]],
      model_instance_id = selected$model_instance_id[[1L]],
      fast_period = if ("fast_period" %in% names(selected)) selected$fast_period[[1L]] else NA_integer_,
      slow_period = if ("slow_period" %in% names(selected)) selected$slow_period[[1L]] else NA_integer_,
      lookback_period = if ("lookback_period" %in% names(selected)) selected$lookback_period[[1L]] else NA_integer_,
      sd_multiplier = if ("sd_multiplier" %in% names(selected)) selected$sd_multiplier[[1L]] else NA_real_,
      train_sharpe = selected$sharpe[[1L]],
      train_total_return = selected$total_return[[1L]],
      train_cagr = selected$cagr[[1L]],
      train_max_drawdown = selected$max_drawdown[[1L]],
      train_trade_count = selected$trade_count[[1L]],
      stringsAsFactors = FALSE
    )
    grid$fold_id <- fold$fold_id[[1L]]
    grid$fold_no <- fold$fold_no[[1L]]
    grid_rows[[i]] <- grid
  }
  selected_models <- do.call(rbind, rows)
  train_grid <- do.call(rbind, grid_rows)
  rownames(selected_models) <- NULL
  rownames(train_grid) <- NULL
  list(selected_models = selected_models, train_parameter_performance = train_grid)
}

g5_ema_cross_wfa_fold_for_signal_date <- function(signal_date, folds) {
  signal_date <- as.Date(signal_date)
  if (signal_date == as.Date(folds$train_end_date[[1L]])) {
    return(1L)
  }
  matches <- which(signal_date >= as.Date(folds$oos_start_date) & signal_date <= as.Date(folds$oos_end_date))
  if (length(matches) == 0L) {
    return(NA_integer_)
  }
  matches[[1L]]
}

g5_ema_cross_wfa_fold_for_execution_date <- function(execution_date, folds) {
  execution_date <- as.Date(execution_date)
  matches <- which(execution_date >= as.Date(folds$oos_start_date) & execution_date <= as.Date(folds$oos_end_date))
  if (length(matches) == 0L) {
    return(NA_integer_)
  }
  matches[[1L]]
}

g5_ema_cross_wfa_make_indicator_by_fold <- function(bars, symbol, selected_models, end_date) {
  prepared <- g5_ema_cross_prepare_bars(bars, symbol = symbol, end_date = end_date)
  out <- list()
  for (i in seq_len(nrow(selected_models))) {
    model <- selected_models[i, , drop = FALSE]
    ind <- g5_wfa_model_indicators(prepared, symbol, model)
    out[[model$fold_id[[1L]]]] <- ind
  }
  out
}

g5_ema_cross_wfa_simulate_stitched_oos <- function(bars, symbol, folds, selected_models) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  first_signal_date <- as.Date(folds$train_end_date[[1L]])
  first_oos_date <- as.Date(folds$oos_start_date[[1L]])
  final_oos_date <- as.Date(folds$oos_end_date[[nrow(folds)]])
  all_bars <- g5_ema_cross_prepare_bars(bars, symbol = symbol, end_date = final_oos_date)
  session_dates <- as.Date(all_bars$session_date)
  indicator_by_fold <- g5_ema_cross_wfa_make_indicator_by_fold(all_bars, symbol, selected_models, final_oos_date)
  date_to_index <- function(x) match(as.Date(x), session_dates)
  signal_indices <- which(session_dates >= first_signal_date & session_dates <= final_oos_date)

  trades <- list()
  trade_no <- 0L
  in_position <- FALSE
  open_trade <- NULL
  pending_entry <- NULL
  pending_exit <- NULL

  model_value <- function(model, col, default = NA) {
    if (col %in% names(model)) model[[col]][[1L]] else default
  }

  for (idx in signal_indices) {
    current_date <- session_dates[[idx]]

    if (!is.null(pending_entry) && identical(as.Date(pending_entry$execution_date), current_date) && !in_position) {
      execution_fold_no <- g5_ema_cross_wfa_fold_for_execution_date(current_date, folds)
      if (!is.na(execution_fold_no)) {
        trade_no <- trade_no + 1L
        open_trade <- c(
          pending_entry,
          list(
            trade_no = trade_no,
            entry_execution_idx = idx,
            entry_execution_date = current_date,
            entry_execution_price = as.numeric(all_bars$open[[idx]]),
            entry_execution_fold_id = folds$fold_id[[execution_fold_no]],
            entry_execution_strategy_family = selected_models$strategy_family[[execution_fold_no]],
            entry_execution_model_instance_id = selected_models$model_instance_id[[execution_fold_no]]
          )
        )
        in_position <- TRUE
      }
      pending_entry <- NULL
    }

    if (!is.null(pending_exit) && identical(as.Date(pending_exit$execution_date), current_date) && in_position) {
      execution_fold_no <- g5_ema_cross_wfa_fold_for_execution_date(current_date, folds)
      if (!is.na(execution_fold_no)) {
        entry_price <- open_trade$entry_execution_price
        exit_price <- as.numeric(all_bars$open[[idx]])
        realized_return <- (exit_price / entry_price) - 1
        carried <- open_trade$entry_execution_fold_id != folds$fold_id[[execution_fold_no]]
        trades[[length(trades) + 1L]] <- data.frame(
          schema_version = g5_ema_cross_wfa_multi_schema_version(),
          trade_id = sprintf("%s_wfa_multi_%03d", symbol, open_trade$trade_no),
          symbol = symbol,
          strategy_family = open_trade$entry_signal_strategy_family,
          model_instance_id = open_trade$entry_signal_model_instance_id,
          entry_signal_strategy_family = open_trade$entry_signal_strategy_family,
          entry_execution_strategy_family = open_trade$entry_execution_strategy_family,
          exit_signal_strategy_family = pending_exit$exit_signal_strategy_family,
          exit_execution_strategy_family = selected_models$strategy_family[[execution_fold_no]],
          entry_signal_model_instance_id = open_trade$entry_signal_model_instance_id,
          entry_execution_model_instance_id = open_trade$entry_execution_model_instance_id,
          exit_signal_model_instance_id = pending_exit$exit_signal_model_instance_id,
          exit_execution_model_instance_id = selected_models$model_instance_id[[execution_fold_no]],
          fast_period = open_trade$entry_signal_fast_period,
          slow_period = open_trade$entry_signal_slow_period,
          lookback_period = open_trade$entry_signal_lookback_period,
          sd_multiplier = open_trade$entry_signal_sd_multiplier,
          exit_fast_period = pending_exit$exit_signal_fast_period,
          exit_slow_period = pending_exit$exit_signal_slow_period,
          exit_lookback_period = pending_exit$exit_signal_lookback_period,
          exit_sd_multiplier = pending_exit$exit_signal_sd_multiplier,
          trade_status = "closed",
          entry_signal_fold_id = open_trade$entry_signal_fold_id,
          entry_execution_fold_id = open_trade$entry_execution_fold_id,
          exit_signal_fold_id = pending_exit$exit_signal_fold_id,
          exit_execution_fold_id = folds$fold_id[[execution_fold_no]],
          carried_across_fold_boundary = carried,
          entry_signal_date = open_trade$entry_signal_date,
          entry_signal_index = open_trade$entry_signal_idx,
          entry_signal_price = open_trade$entry_signal_price,
          entry_execution_date = open_trade$entry_execution_date,
          entry_execution_index = open_trade$entry_execution_idx,
          entry_execution_price = entry_price,
          exit_signal_date = pending_exit$exit_signal_date,
          exit_signal_index = pending_exit$exit_signal_idx,
          exit_signal_price = pending_exit$exit_signal_price,
          exit_execution_date = current_date,
          exit_execution_index = idx,
          exit_execution_price = exit_price,
          latest_mark_date = final_oos_date,
          latest_mark_price = as.numeric(all_bars$close[[date_to_index(final_oos_date)]]),
          trace_end_date = current_date,
          trace_end_index = idx,
          trace_end_price = exit_price,
          underlying_realized_return = realized_return,
          underlying_unrealized_return = NA_real_,
          realized_return = realized_return,
          unrealized_return = NA_real_,
          trace_return = realized_return,
          trade_outcome = if (realized_return > 0) "win" else if (realized_return < 0) "loss" else "flat",
          holding_sessions_completed = idx - open_trade$entry_execution_idx + 1L,
          signal_rule = open_trade$entry_signal_rule,
          entry_execution_rule = "next_session_open_after_entry_signal",
          exit_signal_rule = pending_exit$exit_signal_rule,
          exit_execution_rule = "next_session_open_after_exit_signal",
          leverage = 1,
          capital_fraction = 1,
          stringsAsFactors = FALSE
        )
        in_position <- FALSE
        open_trade <- NULL
      }
      pending_exit <- NULL
    }

    signal_fold_no <- g5_ema_cross_wfa_fold_for_signal_date(current_date, folds)
    if (is.na(signal_fold_no)) {
      next
    }
    model <- selected_models[signal_fold_no, , drop = FALSE]
    ind <- indicator_by_fold[[model$fold_id[[1L]]]]
    entry_signal <- isTRUE(ind$entry_signal[[idx]])
    exit_signal <- isTRUE(ind$exit_signal[[idx]])
    next_idx <- idx + 1L
    if (next_idx > nrow(all_bars) || session_dates[[next_idx]] > final_oos_date) {
      next
    }
    next_execution_fold_no <- g5_ema_cross_wfa_fold_for_execution_date(session_dates[[next_idx]], folds)
    if (is.na(next_execution_fold_no)) {
      next
    }

    if (!in_position && is.null(pending_entry) && entry_signal) {
      pending_entry <- list(
        entry_signal_fold_id = model$fold_id[[1L]],
        entry_signal_strategy_family = model$strategy_family[[1L]],
        entry_signal_model_instance_id = model$model_instance_id[[1L]],
        entry_signal_fast_period = model_value(model, "fast_period", NA_integer_),
        entry_signal_slow_period = model_value(model, "slow_period", NA_integer_),
        entry_signal_lookback_period = model_value(model, "lookback_period", NA_integer_),
        entry_signal_sd_multiplier = model_value(model, "sd_multiplier", NA_real_),
        entry_signal_rule = ind$entry_signal_rule[[idx]],
        entry_signal_date = current_date,
        entry_signal_idx = idx,
        entry_signal_price = as.numeric(all_bars$close[[idx]]),
        execution_date = session_dates[[next_idx]]
      )
    }

    if (in_position && is.null(pending_exit) && exit_signal) {
      pending_exit <- list(
        exit_signal_fold_id = model$fold_id[[1L]],
        exit_signal_strategy_family = model$strategy_family[[1L]],
        exit_signal_model_instance_id = model$model_instance_id[[1L]],
        exit_signal_fast_period = model_value(model, "fast_period", NA_integer_),
        exit_signal_slow_period = model_value(model, "slow_period", NA_integer_),
        exit_signal_lookback_period = model_value(model, "lookback_period", NA_integer_),
        exit_signal_sd_multiplier = model_value(model, "sd_multiplier", NA_real_),
        exit_signal_rule = ind$exit_signal_rule[[idx]],
        exit_signal_date = current_date,
        exit_signal_idx = idx,
        exit_signal_price = as.numeric(all_bars$close[[idx]]),
        execution_date = session_dates[[next_idx]]
      )
    }
  }

  if (in_position && !is.null(open_trade)) {
    latest_idx <- date_to_index(final_oos_date)
    latest_close <- as.numeric(all_bars$close[[latest_idx]])
    unrealized_return <- (latest_close / open_trade$entry_execution_price) - 1
    final_fold_no <- g5_ema_cross_wfa_fold_for_execution_date(final_oos_date, folds)
    trades[[length(trades) + 1L]] <- data.frame(
      schema_version = g5_ema_cross_wfa_multi_schema_version(),
      trade_id = sprintf("%s_wfa_multi_%03d", symbol, open_trade$trade_no),
      symbol = symbol,
      strategy_family = open_trade$entry_signal_strategy_family,
      model_instance_id = open_trade$entry_signal_model_instance_id,
      entry_signal_strategy_family = open_trade$entry_signal_strategy_family,
      entry_execution_strategy_family = open_trade$entry_execution_strategy_family,
      exit_signal_strategy_family = NA_character_,
      exit_execution_strategy_family = NA_character_,
      entry_signal_model_instance_id = open_trade$entry_signal_model_instance_id,
      entry_execution_model_instance_id = open_trade$entry_execution_model_instance_id,
      exit_signal_model_instance_id = NA_character_,
      exit_execution_model_instance_id = NA_character_,
      fast_period = open_trade$entry_signal_fast_period,
      slow_period = open_trade$entry_signal_slow_period,
      lookback_period = open_trade$entry_signal_lookback_period,
      sd_multiplier = open_trade$entry_signal_sd_multiplier,
      exit_fast_period = NA_integer_,
      exit_slow_period = NA_integer_,
      exit_lookback_period = NA_integer_,
      exit_sd_multiplier = NA_real_,
      trade_status = "open",
      entry_signal_fold_id = open_trade$entry_signal_fold_id,
      entry_execution_fold_id = open_trade$entry_execution_fold_id,
      exit_signal_fold_id = NA_character_,
      exit_execution_fold_id = NA_character_,
      carried_across_fold_boundary = open_trade$entry_execution_fold_id != folds$fold_id[[final_fold_no]],
      entry_signal_date = open_trade$entry_signal_date,
      entry_signal_index = open_trade$entry_signal_idx,
      entry_signal_price = open_trade$entry_signal_price,
      entry_execution_date = open_trade$entry_execution_date,
      entry_execution_index = open_trade$entry_execution_idx,
      entry_execution_price = open_trade$entry_execution_price,
      exit_signal_date = as.Date(NA),
      exit_signal_index = NA_integer_,
      exit_signal_price = NA_real_,
      exit_execution_date = as.Date(NA),
      exit_execution_index = NA_integer_,
      exit_execution_price = NA_real_,
      latest_mark_date = final_oos_date,
      latest_mark_price = latest_close,
      trace_end_date = final_oos_date,
      trace_end_index = latest_idx,
      trace_end_price = latest_close,
      underlying_realized_return = NA_real_,
      underlying_unrealized_return = unrealized_return,
      realized_return = NA_real_,
      unrealized_return = unrealized_return,
      trace_return = unrealized_return,
      trade_outcome = if (unrealized_return > 0) "win" else if (unrealized_return < 0) "loss" else "flat",
      holding_sessions_completed = latest_idx - open_trade$entry_execution_idx + 1L,
      signal_rule = open_trade$entry_signal_rule,
      entry_execution_rule = "next_session_open_after_entry_signal",
      exit_signal_rule = "current_fold_exit_signal_when_long",
      exit_execution_rule = "next_session_open_after_exit_signal",
      leverage = 1,
      capital_fraction = 1,
      stringsAsFactors = FALSE
    )
  }

  trades_out <- if (length(trades) == 0L) data.frame() else do.call(rbind, trades)
  if (nrow(trades_out) > 0L) {
    rownames(trades_out) <- NULL
  }
  equity_curve <- g5_ema_cross_equity_curve(
    trades_out,
    all_bars,
    symbol = symbol,
    trading_start_date = first_oos_date,
    trading_end_date = final_oos_date,
    leverage = 1
  )
  list(trades = trades_out, equity_curve = equity_curve)
}

g5_ema_cross_wfa_stitched_indicators <- function(bars, symbol, folds, selected_models) {
  first_context_date <- as.Date(folds$train_end_date[[1L]])
  final_oos_date <- as.Date(folds$oos_end_date[[nrow(folds)]])
  all_bars <- g5_ema_cross_prepare_bars(bars, symbol = symbol, end_date = final_oos_date)
  indicator_by_fold <- g5_ema_cross_wfa_make_indicator_by_fold(all_bars, symbol, selected_models, final_oos_date)
  rows <- list()
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    model <- selected_models[i, , drop = FALSE]
    ind <- indicator_by_fold[[fold$fold_id[[1L]]]]
    start_date <- if (i == 1L) fold$train_end_date[[1L]] else fold$oos_start_date[[1L]]
    keep <- as.Date(ind$session_date) >= as.Date(start_date) & as.Date(ind$session_date) <= as.Date(fold$oos_end_date[[1L]])
    part <- ind[keep, , drop = FALSE]
    part$fold_id <- fold$fold_id[[1L]]
    part$fold_no <- fold$fold_no[[1L]]
    part$model_instance_id <- model$model_instance_id[[1L]]
    rows[[i]] <- part
  }
  out <- do.call(rbind, rows)
  out <- out[!duplicated(paste(out$session_date, out$fold_id)), , drop = FALSE]
  out <- out[as.Date(out$session_date) >= first_context_date, , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_ema_cross_wfa_stitched_metrics <- function(trades, equity_curve, symbol, fold_count) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  closed <- if (is.data.frame(trades) && nrow(trades) > 0L) trades[trades$trade_status == "closed", , drop = FALSE] else data.frame()
  open_trades <- if (is.data.frame(trades) && nrow(trades) > 0L) trades[trades$trade_status != "closed", , drop = FALSE] else data.frame()
  closed_returns <- if (nrow(closed) > 0L) as.numeric(closed$realized_return) else numeric()
  wins <- closed_returns[closed_returns > 0]
  losses <- closed_returns[closed_returns < 0]
  flats <- closed_returns[closed_returns == 0]
  strategy_underwater <- g5_ema_cross_time_underwater_summary(equity_curve$strategy_drawdown)
  buy_hold_underwater <- g5_ema_cross_time_underwater_summary(equity_curve$buy_hold_drawdown)
  start_date <- min(equity_curve$session_date)
  end_date <- max(equity_curve$session_date)
  ending_equity <- tail(equity_curve$strategy_equity, 1L)
  buy_hold_ending_equity <- tail(equity_curve$buy_hold_equity, 1L)
  data.frame(
    schema_version = g5_ema_cross_wfa_multi_schema_version(),
    symbol = symbol,
    strategy_family = "multi_signal",
    fold_count = fold_count,
    leverage = 1,
    trade_count = if (is.data.frame(trades)) nrow(trades) else 0L,
    closed_trade_count = nrow(closed),
    open_trade_count = nrow(open_trades),
    carried_trade_count = if (is.data.frame(trades) && nrow(trades) > 0L) sum(trades$carried_across_fold_boundary, na.rm = TRUE) else 0L,
    win_count = length(wins),
    loss_count = length(losses),
    flat_count = length(flats),
    win_rate = if (length(closed_returns) == 0L) NA_real_ else length(wins) / length(closed_returns),
    ending_equity = ending_equity,
    total_return = ending_equity - 1,
    cagr = g5_ema_cross_cagr(1, ending_equity, start_date, end_date),
    sharpe = g5_ema_cross_sharpe(equity_curve$strategy_equity),
    max_drawdown = min(equity_curve$strategy_drawdown, na.rm = TRUE),
    underwater_session_count = strategy_underwater$count,
    underwater_fraction = strategy_underwater$fraction,
    max_underwater_streak = strategy_underwater$max_streak,
    exposure_fraction = mean(equity_curve$in_position, na.rm = TRUE),
    average_trade_return = if (length(closed_returns) == 0L) NA_real_ else mean(closed_returns),
    best_trade_return = if (length(closed_returns) == 0L) NA_real_ else max(closed_returns),
    worst_trade_return = if (length(closed_returns) == 0L) NA_real_ else min(closed_returns),
    profit_factor = if (length(closed_returns) == 0L || length(losses) == 0L) {
      if (length(wins) == 0L) NA_real_ else Inf
    } else {
      sum(wins) / abs(sum(losses))
    },
    buy_hold_ending_equity = buy_hold_ending_equity,
    buy_hold_total_return = buy_hold_ending_equity - 1,
    buy_hold_cagr = g5_ema_cross_cagr(1, buy_hold_ending_equity, start_date, end_date),
    buy_hold_sharpe = g5_ema_cross_sharpe(equity_curve$buy_hold_equity),
    buy_hold_max_drawdown = min(equity_curve$buy_hold_drawdown, na.rm = TRUE),
    buy_hold_underwater_session_count = buy_hold_underwater$count,
    buy_hold_underwater_fraction = buy_hold_underwater$fraction,
    buy_hold_max_underwater_streak = buy_hold_underwater$max_streak,
    stringsAsFactors = FALSE
  )
}

g5_ema_cross_wfa_fold_oos_summary <- function(folds, selected_models, equity_curve, trades) {
  rows <- list()
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    model <- selected_models[i, , drop = FALSE]
    curve <- equity_curve[equity_curve$session_date >= fold$oos_start_date[[1L]] & equity_curve$session_date <= fold$oos_end_date[[1L]], , drop = FALSE]
    fold_trades <- if (is.data.frame(trades) && nrow(trades) > 0L) {
      trades[trades$entry_execution_fold_id == fold$fold_id[[1L]] | trades$exit_execution_fold_id == fold$fold_id[[1L]] | trades$exit_signal_fold_id == fold$fold_id[[1L]], , drop = FALSE]
    } else {
      data.frame()
    }
    start_equity <- curve$strategy_equity[[1L]]
    end_equity <- tail(curve$strategy_equity, 1L)
    rows[[i]] <- data.frame(
      schema_version = g5_ema_cross_wfa_multi_schema_version(),
      fold_id = fold$fold_id[[1L]],
      fold_no = fold$fold_no[[1L]],
      strategy_family = model$strategy_family[[1L]],
      model_instance_id = model$model_instance_id[[1L]],
      model_parameters = g5_wfa_model_parameter_label(model),
      fast_period = if ("fast_period" %in% names(model)) model$fast_period[[1L]] else NA_integer_,
      slow_period = if ("slow_period" %in% names(model)) model$slow_period[[1L]] else NA_integer_,
      lookback_period = if ("lookback_period" %in% names(model)) model$lookback_period[[1L]] else NA_integer_,
      sd_multiplier = if ("sd_multiplier" %in% names(model)) model$sd_multiplier[[1L]] else NA_real_,
      train_sharpe = model$train_sharpe[[1L]],
      train_total_return = model$train_total_return[[1L]],
      oos_start_date = fold$oos_start_date[[1L]],
      oos_end_date = fold$oos_end_date[[1L]],
      oos_session_count = nrow(curve),
      oos_return = if (is.finite(start_equity) && start_equity > 0) end_equity / start_equity - 1 else NA_real_,
      oos_max_drawdown = min(curve$strategy_drawdown, na.rm = TRUE),
      oos_trade_touch_count = nrow(fold_trades),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_ema_cross_wfa_model_stability <- function(selected_models) {
  keys <- unique(selected_models$model_instance_id)
  rows <- lapply(keys, function(key) {
    selected <- selected_models[selected_models$model_instance_id == key, , drop = FALSE]
    data.frame(
      schema_version = g5_ema_cross_wfa_multi_schema_version(),
      strategy_family = selected$strategy_family[[1L]],
      model_instance_id = key,
      model_parameters = g5_wfa_model_parameter_label(selected[1L, , drop = FALSE]),
      fast_period = if ("fast_period" %in% names(selected)) selected$fast_period[[1L]] else NA_integer_,
      slow_period = if ("slow_period" %in% names(selected)) selected$slow_period[[1L]] else NA_integer_,
      lookback_period = if ("lookback_period" %in% names(selected)) selected$lookback_period[[1L]] else NA_integer_,
      sd_multiplier = if ("sd_multiplier" %in% names(selected)) selected$sd_multiplier[[1L]] else NA_real_,
      selected_fold_count = nrow(selected),
      selected_fold_fraction = nrow(selected) / nrow(selected_models),
      selected_folds = paste(selected$fold_id, collapse = ","),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$selected_fold_count, decreasing = TRUE), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_ema_cross_wfa_fold_background_spans <- function(session_dates, folds, fold_ids = NULL, color_a = "#FFFFFF", color_b = "#F2F3F5") {
  session_dates <- as.Date(session_dates)
  if (!is.data.frame(folds) || nrow(folds) == 0L) {
    g5_stop("folds must be a non-empty data.frame.")
  }
  if (length(session_dates) == 0L || anyNA(session_dates)) {
    g5_stop("session_dates must be non-empty dates with no missing values.")
  }
  if (is.null(fold_ids)) {
    fold_ids <- vapply(session_dates, function(session_date) {
      idx <- which(session_date >= as.Date(folds$oos_start_date) & session_date <= as.Date(folds$oos_end_date))
      if (length(idx) == 0L) NA_character_ else as.character(folds$fold_id[[idx[[1L]]]])
    }, character(1L))
  }
  fold_ids <- as.character(fold_ids)
  if (length(fold_ids) != length(session_dates)) {
    g5_stop("fold_ids must be the same length as session_dates.")
  }
  if (anyNA(fold_ids)) {
    g5_stop("Every plotted row must map to a WFA fold before drawing fold backgrounds.")
  }
  fold_match <- match(fold_ids, as.character(folds$fold_id))
  if (anyNA(fold_match)) {
    g5_stop("fold_ids contains a fold not present in folds.")
  }

  runs <- rle(fold_ids)
  run_ends <- cumsum(runs$lengths)
  run_starts <- run_ends - runs$lengths + 1L
  rows <- vector("list", length(runs$values))
  for (i in seq_along(runs$values)) {
    fold_idx <- match(runs$values[[i]], as.character(folds$fold_id))
    fold_no <- if ("fold_no" %in% names(folds)) as.integer(folds$fold_no[[fold_idx]]) else fold_idx
    rows[[i]] <- data.frame(
      fold_id = runs$values[[i]],
      fold_no = fold_no,
      start_index = run_starts[[i]],
      end_index = run_ends[[i]],
      xleft = if (run_starts[[i]] == 1L) 0.5 else run_starts[[i]] - 0.5,
      xright = if (run_ends[[i]] == length(session_dates)) length(session_dates) + 0.5 else run_ends[[i]] + 0.5,
      fill = if (fold_no %% 2L == 1L) color_a else color_b,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_plot_fold_backgrounds <- function(session_dates, folds, fold_ids = NULL, color_a = "#FFFFFF", color_b = "#F2F3F5") {
  usr <- graphics::par("usr")
  spans <- g5_ema_cross_wfa_fold_background_spans(session_dates, folds, fold_ids = fold_ids, color_a = color_a, color_b = color_b)
  for (i in seq_len(nrow(spans))) {
    graphics::rect(spans$xleft[[i]], usr[[3L]], spans$xright[[i]], usr[[4L]], col = spans$fill[[i]], border = NA)
  }
}

g5_write_ema_cross_wfa_stitched_strategy_chart_png <- function(indicators, trades, folds, symbol, path, width = 1500L, height = 840L) {
  if (!is.data.frame(indicators) || nrow(indicators) == 0L) {
    g5_stop("indicators must be a non-empty data.frame.")
  }
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  aesthetic <- g5_chart_aesthetic()
  session_dates <- as.Date(indicators$session_date)
  x <- seq_len(nrow(indicators))
  y_range <- range(c(indicators$low, indicators$high, indicators$fast_ema, indicators$slow_ema, indicators$bb_mid, indicators$bb_upper, indicators$bb_lower), finite = TRUE)
  padding <- diff(y_range) * 0.06
  if (!is.finite(padding) || padding <= 0) {
    padding <- max(abs(y_range), 1) * 0.02
  }
  y_limits <- y_range + c(-padding, padding)
  body_colors <- ifelse(indicators$close > indicators$open, aesthetic$up_candle, ifelse(indicators$close < indicators$open, aesthetic$down_candle, aesthetic$flat_candle))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(7.5, 5.2, 4, 2), bg = aesthetic$background, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::plot(x = c(0.5, length(x) + 0.5), y = y_limits, type = "n", xaxt = "n", xaxs = "i", xlab = "Session date", ylab = "Adjusted daily price", main = paste(symbol, "Multi-Signal Three-Fold WFA OOS"), col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  g5_plot_fold_backgrounds(session_dates, folds, fold_ids = indicators$fold_id)
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  graphics::segments(x0 = x, y0 = indicators$low, x1 = x, y1 = indicators$high, col = body_colors, lwd = 1.2)
  candle_width <- 0.62
  body_bottom <- pmin(indicators$open, indicators$close)
  body_top <- pmax(indicators$open, indicators$close)
  flat_body <- body_bottom == body_top
  if (any(!flat_body)) {
    graphics::rect(xleft = x[!flat_body] - candle_width / 2, ybottom = body_bottom[!flat_body], xright = x[!flat_body] + candle_width / 2, ytop = body_top[!flat_body], col = body_colors[!flat_body], border = body_colors[!flat_body])
  }
  if (any(flat_body)) {
    graphics::segments(x0 = x[flat_body] - candle_width / 2, y0 = indicators$close[flat_body], x1 = x[flat_body] + candle_width / 2, y1 = indicators$close[flat_body], col = body_colors[flat_body], lwd = 2)
  }
  for (fold_id in unique(indicators$fold_id)) {
    part <- indicators[indicators$fold_id == fold_id, , drop = FALSE]
    part_x <- match(as.Date(part$session_date), session_dates)
    family <- unique(part$strategy_family)
    if (length(family) > 0L && identical(family[[1L]], "ema_cross")) {
      graphics::lines(part_x, part$fast_ema, col = aesthetic$native_entry_color, lwd = 1.4)
      graphics::lines(part_x, part$slow_ema, col = aesthetic$non_native_exit_color, lwd = 1.4)
    }
    if (length(family) > 0L && identical(family[[1L]], "bollinger_touch")) {
      band_col <- grDevices::adjustcolor(aesthetic$non_native_exit_color, alpha.f = 0.7)
      graphics::lines(part_x, part$bb_mid, col = aesthetic$native_entry_color, lwd = 1.1)
      graphics::lines(part_x, part$bb_upper, col = band_col, lwd = 1.1, lty = 2)
      graphics::lines(part_x, part$bb_lower, col = band_col, lwd = 1.1, lty = 2)
    }
  }
  if (is.data.frame(trades) && nrow(trades) > 0L) {
    line_cols <- ifelse(trades$trade_outcome == "win", aesthetic$trade_win_line, ifelse(trades$trade_outcome == "loss", aesthetic$trade_loss_line, aesthetic$flat_candle))
    graphics::segments(match(trades$entry_execution_date, session_dates), trades$entry_execution_price, match(trades$trace_end_date, session_dates), trades$trace_end_price, col = line_cols, lty = aesthetic$trade_line_lty, lwd = 1.2)
    graphics::points(match(trades$entry_signal_date, session_dates), trades$entry_signal_price, pch = aesthetic$entry_signal_pch, col = aesthetic$entry_signal_color, bg = aesthetic$panel_background, cex = 1.1, lwd = 1.4)
    graphics::points(match(trades$entry_execution_date, session_dates), trades$entry_execution_price, pch = aesthetic$native_entry_pch, col = aesthetic$native_entry_color, bg = aesthetic$native_entry_color, cex = 1.05)
    exit_signal_rows <- trades[!is.na(trades$exit_signal_date), , drop = FALSE]
    if (nrow(exit_signal_rows) > 0L) {
      graphics::points(match(exit_signal_rows$exit_signal_date, session_dates), exit_signal_rows$exit_signal_price, pch = aesthetic$exit_signal_pch, col = aesthetic$exit_signal_color, bg = aesthetic$panel_background, cex = 1.1, lwd = 1.4)
    }
    closed_rows <- trades[!is.na(trades$exit_execution_date), , drop = FALSE]
    if (nrow(closed_rows) > 0L) {
      graphics::points(match(closed_rows$exit_execution_date, session_dates), closed_rows$exit_execution_price, pch = aesthetic$native_exit_pch, col = aesthetic$native_exit_color, bg = aesthetic$native_exit_color, cex = 1.05)
    }
  }
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(8L, length(x)))))
  g5_axis_date_labels_45(tick_positions, as.character(session_dates[tick_positions]), color = aesthetic$axis)
  has_ema <- any(indicators$strategy_family == "ema_cross", na.rm = TRUE)
  has_bb <- any(indicators$strategy_family == "bollinger_touch", na.rm = TRUE)
  legend_text <- character()
  legend_lty <- numeric()
  legend_pch <- numeric()
  legend_col <- character()
  legend_bg <- character()
  if (has_ema) {
    legend_text <- c(legend_text, "fast EMA", "slow EMA")
    legend_lty <- c(legend_lty, 1, 1)
    legend_pch <- c(legend_pch, NA, NA)
    legend_col <- c(legend_col, aesthetic$native_entry_color, aesthetic$non_native_exit_color)
    legend_bg <- c(legend_bg, NA, NA)
  }
  if (has_bb) {
    legend_text <- c(legend_text, "BB mid", "BB upper/lower")
    legend_lty <- c(legend_lty, 1, 2)
    legend_pch <- c(legend_pch, NA, NA)
    legend_col <- c(legend_col, aesthetic$native_entry_color, grDevices::adjustcolor(aesthetic$non_native_exit_color, alpha.f = 0.7))
    legend_bg <- c(legend_bg, NA, NA)
  }
  legend_text <- c(legend_text, "entry signal", "entry execution", "exit signal", "exit execution")
  legend_lty <- c(legend_lty, NA, NA, NA, NA)
  legend_pch <- c(legend_pch, aesthetic$entry_signal_pch, aesthetic$native_entry_pch, aesthetic$exit_signal_pch, aesthetic$native_exit_pch)
  legend_col <- c(legend_col, aesthetic$entry_signal_color, aesthetic$native_entry_color, aesthetic$exit_signal_color, aesthetic$native_exit_color)
  legend_bg <- c(legend_bg, aesthetic$panel_background, aesthetic$native_entry_color, aesthetic$panel_background, aesthetic$native_exit_color)
  graphics::legend("topleft", legend = legend_text, lty = legend_lty, pch = legend_pch, col = legend_col, pt.bg = legend_bg, bty = "n", text.col = aesthetic$text, cex = 0.78)
  graphics::mtext(paste("Rows:", nrow(indicators), "|", min(session_dates), "to", max(session_dates), "| shaded regions: OOS folds"), side = 3, line = 0.3, cex = 0.85, col = aesthetic$text)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_ema_cross_wfa_stitched_equity_curve_png <- function(equity_curve, folds, symbol, path, width = 1500L, height = 760L) {
  if (!is.data.frame(equity_curve) || nrow(equity_curve) == 0L) {
    g5_stop("equity_curve must be a non-empty data.frame.")
  }
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  aesthetic <- g5_chart_aesthetic()
  x <- seq_len(nrow(equity_curve))
  session_dates <- as.Date(equity_curve$session_date)
  strategy_peak <- cummax(as.numeric(equity_curve$strategy_equity))
  y <- range(c(equity_curve$strategy_equity, strategy_peak, equity_curve$buy_hold_equity), finite = TRUE)
  padding <- diff(y) * 0.08
  if (!is.finite(padding) || padding <= 0) {
    padding <- max(abs(y), 1) * 0.03
  }
  y_limits <- y + c(-padding, padding)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(7.5, 5.2, 4, 2), bg = aesthetic$background, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::plot(x = c(0.5, length(x) + 0.5), y = y_limits, type = "n", xaxt = "n", xaxs = "i", xlab = "Session date", ylab = "Equity, starting at 1.0", main = paste(symbol, "Multi-Signal Three-Fold WFA Stitched OOS Equity"), col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text, fg = aesthetic$axis)
  g5_plot_fold_backgrounds(session_dates, folds)
  underwater <- equity_curve$strategy_equity < strategy_peak
  if (any(underwater, na.rm = TRUE)) {
    runs <- rle(underwater)
    run_ends <- cumsum(runs$lengths)
    run_starts <- run_ends - runs$lengths + 1L
    for (i in seq_along(runs$values)) {
      if (!isTRUE(runs$values[[i]])) next
      idx <- seq(run_starts[[i]], run_ends[[i]])
      peak_level <- strategy_peak[[idx[[1L]]]]
      segment_start <- max(1L, idx[[1L]] - 1L)
      segment_end <- idx[[length(idx)]]
      segment_end_x <- x[[segment_end]]
      if (segment_end < length(x) && !isTRUE(underwater[[segment_end + 1L]])) {
        y0 <- as.numeric(equity_curve$strategy_equity[[segment_end]])
        y1 <- as.numeric(equity_curve$strategy_equity[[segment_end + 1L]])
        if (is.finite(y0) && is.finite(y1) && y1 != y0) {
          crossing_fraction <- max(0, min(1, (peak_level - y0) / (y1 - y0)))
          segment_end_x <- x[[segment_end]] + crossing_fraction * (x[[segment_end + 1L]] - x[[segment_end]])
        }
      }
      graphics::segments(x[[segment_start]], peak_level, segment_end_x, peak_level, col = grDevices::adjustcolor(aesthetic$down_candle, alpha.f = 0.42), lwd = 2.4, lend = "round")
    }
  }
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  graphics::abline(h = 1, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.35), lty = 3)
  graphics::lines(x, equity_curve$buy_hold_equity, col = "#000000", lwd = 1.8)
  graphics::lines(x, equity_curve$strategy_equity, col = aesthetic$trade_win_line, lwd = 2.2)
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(8L, length(x)))))
  g5_axis_date_labels_45(tick_positions, as.character(session_dates[tick_positions]), color = aesthetic$axis)
  graphics::legend("topleft", legend = c("stitched OOS strategy", "buy and hold", "drawdown shelf"), lty = c(1, 1, 1), lwd = c(2.2, 1.8, 2.4), col = c(aesthetic$trade_win_line, "#000000", grDevices::adjustcolor(aesthetic$down_candle, alpha.f = 0.42)), bty = "n", text.col = aesthetic$text, cex = 0.9)
  graphics::mtext(paste("Rows:", nrow(equity_curve), "|", min(session_dates), "to", max(session_dates), "| shaded regions: OOS folds"), side = 3, line = 0.3, cex = 0.85, col = aesthetic$text)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_ema_cross_wfa_multi_metrics_markdown <- function(folds, selected_models, train_parameter_performance, stitched_metrics, fold_oos_summary, stability, settings, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  num <- function(x) ifelse(is.na(x), "NA", ifelse(is.infinite(x), "Inf", sprintf("%.3f", as.numeric(x))))
  qtr <- function(x) {
    x <- as.Date(x)
    paste0(format(x, "%Y"), " Q", ((as.integer(format(x, "%m")) - 1L) %/% 3L) + 1L)
  }
  table_lines <- function(df, cols) {
    df <- df[, cols, drop = FALSE]
    header <- paste(c("", names(df), ""), collapse = " | ")
    sep <- paste(c("", rep("---", ncol(df)), ""), collapse = " | ")
    rows <- apply(df, 1, function(row) paste(c("", as.character(row), ""), collapse = " | "))
    c(header, sep, rows)
  }
  fmt_model_row <- function(row) {
    model <- as.data.frame(as.list(row), stringsAsFactors = FALSE)
    paste0(
      "| ", row[["fold_id"]],
      " | ", row[["strategy_family"]],
      " | ", row[["model_instance_id"]],
      " | ", g5_wfa_model_parameter_label(model),
      " | ", num(row[["train_sharpe"]]),
      " | ", pct(row[["train_total_return"]]),
      " |"
    )
  }
  candidate_models <- unique(train_parameter_performance[, c("strategy_family", "model_instance_id"), drop = FALSE])
  candidate_models <- candidate_models[order(candidate_models$strategy_family, candidate_models$model_instance_id), , drop = FALSE]
  family_counts <- do.call(rbind, lapply(split(candidate_models, candidate_models$strategy_family), function(df) {
    data.frame(
      strategy_family = df$strategy_family[[1L]],
      tested_model_instances_per_fold = nrow(unique(df[, c("strategy_family", "model_instance_id"), drop = FALSE])),
      stringsAsFactors = FALSE
    )
  }))
  names(family_counts) <- c("strategy_family", "tested_model_instances_per_fold")
  fold_table <- data.frame(
    fold_id = folds$fold_id,
    train_range = paste0(folds$train_start_date, " to ", folds$train_end_date),
    train_quarters = paste0(qtr(folds$train_start_date), " to ", qtr(folds$train_end_date)),
    oos_range = paste0(folds$oos_start_date, " to ", folds$oos_end_date),
    oos_quarters = paste0(qtr(folds$oos_start_date), " to ", qtr(folds$oos_end_date)),
    oos_sessions = folds$oos_session_count,
    stringsAsFactors = FALSE
  )
  oos_table <- fold_oos_summary
  oos_table$train_sharpe <- num(oos_table$train_sharpe)
  oos_table$train_total_return <- pct(oos_table$train_total_return)
  oos_table$oos_return <- pct(oos_table$oos_return)
  oos_table$oos_max_drawdown <- pct(oos_table$oos_max_drawdown)
  lines <- c(
    paste0("# Multi-Signal Three-Fold WFA POC: ", stitched_metrics$symbol[[1L]]),
    "",
    "Proof-of-concept only: this is not final research evidence, live advice, allocation logic, or a deployable strategy.",
    "",
    "## Run Context",
    "",
    paste0("- Symbol: `", stitched_metrics$symbol[[1L]], "`"),
    paste0("- As-of timestamp: `", settings$as_of_timestamp, "`"),
    paste0("- Query/data window: `", settings$query_start_date, " to ", settings$query_end_date, "`"),
    paste0("- WFA analysis window: `", settings$wfa_start_date, " to ", settings$wfa_end_date, "`"),
    paste0("- Stitched OOS window: `", min(folds$oos_start_date), " to ", max(folds$oos_end_date), "`"),
    paste0("- Input bars in packet: `", settings$bar_count, "`"),
    paste0("- Leverage: `", stitched_metrics$leverage[[1L]], "x`"),
    "",
    "## WFA Settings",
    "",
    paste0("- Train period: `", settings$train_quarters, " quarters` (`", settings$train_days, "` calendar days target)"),
    paste0("- OOS period: `", settings$oos_quarters, " quarter` (`", settings$oos_days, "` calendar days target)"),
    paste0("- Fold count: `", nrow(folds), "`"),
    paste0("- Fold policy: `", folds$fold_policy[[1L]], "`"),
    paste0("- Position handoff policy: `", folds$position_handoff_policy[[1L]], "`"),
    paste0("- Final bar signal policy: `", folds$final_bar_signal_policy[[1L]], "`"),
    "",
    "## Fold Calendar",
    "",
    table_lines(fold_table, names(fold_table)),
    "",
    "## Candidate Signal Models",
    "",
    "Each TRAIN fold evaluates the same candidate model grid. A model instance means a strategy family plus a concrete parameter set.",
    "",
    table_lines(family_counts, names(family_counts)),
    "",
    paste0("- EMA cross grid: fast periods `", paste(settings$fast_periods, collapse = ", "), "`, slow periods `", paste(settings$slow_periods, collapse = ", "), "`"),
    paste0("- Bollinger touch grid: lookback periods `", paste(settings$bb_lookback_periods, collapse = ", "), "`, SD multipliers `", paste(settings$bb_sd_multipliers, collapse = ", "), "`"),
    "",
    "<details>",
    "<summary>Tested model instances</summary>",
    "",
    table_lines(candidate_models, names(candidate_models)),
    "",
    "</details>",
    "",
    "## Fold-Selected Model Instances",
    "",
    "| fold_id | strategy_family | model_instance_id | parameters | train_sharpe | train_return |",
    "| --- | --- | --- | --- | --- | --- |",
    apply(selected_models, 1, fmt_model_row),
    "",
    "## Fold OOS Summary",
    "",
    table_lines(oos_table[, c("fold_id", "strategy_family", "model_instance_id", "model_parameters", "train_sharpe", "train_total_return", "oos_return", "oos_max_drawdown", "oos_trade_touch_count"), drop = FALSE], c("fold_id", "strategy_family", "model_instance_id", "model_parameters", "train_sharpe", "train_total_return", "oos_return", "oos_max_drawdown", "oos_trade_touch_count")),
    "",
    "## Stitched OOS Performance",
    "",
    paste0("- Stitched OOS return: `", pct(stitched_metrics$total_return[[1L]]), "`"),
    paste0("- Stitched OOS CAGR: `", pct(stitched_metrics$cagr[[1L]]), "`"),
    paste0("- Stitched OOS Sharpe: `", num(stitched_metrics$sharpe[[1L]]), "`"),
    paste0("- Stitched OOS max drawdown: `", pct(stitched_metrics$max_drawdown[[1L]]), "`"),
    paste0("- Time underwater: `", stitched_metrics$underwater_session_count[[1L]], "` sessions (`", pct(stitched_metrics$underwater_fraction[[1L]]), "`)"),
    paste0("- Max underwater streak: `", stitched_metrics$max_underwater_streak[[1L]], "` sessions"),
    paste0("- Exposure: `", pct(stitched_metrics$exposure_fraction[[1L]]), "`"),
    paste0("- Trades: `", stitched_metrics$trade_count[[1L]], "` total, `", stitched_metrics$closed_trade_count[[1L]], "` closed, `", stitched_metrics$open_trade_count[[1L]], "` open"),
    paste0("- Carried trades: `", stitched_metrics$carried_trade_count[[1L]], "`"),
    paste0("- Win rate: `", pct(stitched_metrics$win_rate[[1L]]), "`"),
    paste0("- Profit factor: `", num(stitched_metrics$profit_factor[[1L]]), "`"),
    "",
    "## Buy-And-Hold Baseline",
    "",
    paste0("- Buy-and-hold return over stitched OOS: `", pct(stitched_metrics$buy_hold_total_return[[1L]]), "`"),
    paste0("- Buy-and-hold CAGR: `", pct(stitched_metrics$buy_hold_cagr[[1L]]), "`"),
    paste0("- Buy-and-hold Sharpe: `", num(stitched_metrics$buy_hold_sharpe[[1L]]), "`"),
    paste0("- Buy-and-hold max drawdown: `", pct(stitched_metrics$buy_hold_max_drawdown[[1L]]), "`"),
    "",
    "## Model Stability",
    "",
    table_lines(stability[, c("strategy_family", "model_instance_id", "model_parameters", "selected_fold_count", "selected_fold_fraction", "selected_folds"), drop = FALSE], c("strategy_family", "model_instance_id", "model_parameters", "selected_fold_count", "selected_fold_fraction", "selected_folds")),
    "",
    "## Audit Notes",
    "",
    "- Selection metric for this POC is highest TRAIN Sharpe, with TRAIN total return as the existing secondary sort.",
    "- OOS rows are stitched in chronological order to mimic updating the selected model instance at each fold boundary.",
    "- Open positions are carried across fold boundaries and then managed by the current fold-selected model instance."
  )
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_ema_cross_wfa_run_multi <- function(
  bars,
  symbol,
  wfa_start_date,
  wfa_end_date,
  fast_periods = c(8L, 12L, 20L),
  slow_periods = c(30L, 50L, 80L, 120L),
  bb_lookback_periods = c(10L, 20L, 30L),
  bb_sd_multipliers = c(1.5, 2, 2.5),
  candidate_families = c("ema_cross", "bollinger_touch"),
  train_quarters = 8,
  oos_quarters = 1,
  fold_count = 3L
) {
  folds <- g5_ema_cross_wfa_resolve_folds(bars, symbol, wfa_start_date, wfa_end_date, train_quarters, oos_quarters, fold_count)
  selected <- g5_ema_cross_wfa_select_fold_models(bars, symbol, folds, fast_periods, slow_periods, bb_lookback_periods, bb_sd_multipliers, candidate_families)
  stitched <- g5_ema_cross_wfa_simulate_stitched_oos(bars, symbol, folds, selected$selected_models)
  indicators <- g5_ema_cross_wfa_stitched_indicators(bars, symbol, folds, selected$selected_models)
  stitched_metrics <- g5_ema_cross_wfa_stitched_metrics(stitched$trades, stitched$equity_curve, symbol, nrow(folds))
  fold_oos_summary <- g5_ema_cross_wfa_fold_oos_summary(folds, selected$selected_models, stitched$equity_curve, stitched$trades)
  stability <- g5_ema_cross_wfa_model_stability(selected$selected_models)
  list(
    folds = folds,
    selected_models = selected$selected_models,
    train_parameter_performance = selected$train_parameter_performance,
    stitched_trades = stitched$trades,
    stitched_equity_curve = stitched$equity_curve,
    stitched_indicators = indicators,
    stitched_metrics = stitched_metrics,
    fold_oos_summary = fold_oos_summary,
    model_stability = stability
  )
}

g5_write_ema_cross_wfa_multi_outputs <- function(
  result,
  symbol,
  output_dir,
  wfa_start_date,
  wfa_end_date,
  fast_periods,
  slow_periods,
  bb_lookback_periods = c(10L, 20L, 30L),
  bb_sd_multipliers = c(1.5, 2, 2.5),
  candidate_families = c("ema_cross", "bollinger_touch"),
  train_quarters = 8,
  oos_quarters = 1,
  fold_count = 3L
) {
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("Multi-signal WFA output writing requires exactly one symbol.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  prefix <- g5_ema_cross_wfa_multi_artifact_prefix(result$resolved_session$as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count)
  written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
  wfa <- g5_ema_cross_wfa_run_multi(result$bars, symbol, wfa_start_date, wfa_end_date, fast_periods, slow_periods, bb_lookback_periods, bb_sd_multipliers, candidate_families, train_quarters, oos_quarters, fold_count)
  paths <- c(
    written$paths,
    list(
      fold_spec_csv = file.path(output_dir, paste0(prefix, "_fold_spec.csv")),
      selected_models_csv = file.path(output_dir, paste0(prefix, "_selected_models.csv")),
      train_parameter_performance_csv = file.path(output_dir, paste0(prefix, "_train_parameter_performance.csv")),
      model_stability_csv = file.path(output_dir, paste0(prefix, "_model_stability.csv")),
      fold_oos_summary_csv = file.path(output_dir, paste0(prefix, "_fold_oos_summary.csv")),
      stitched_indicators_csv = file.path(output_dir, paste0(prefix, "_stitched_indicators.csv")),
      stitched_trades_csv = file.path(output_dir, paste0(prefix, "_stitched_trades.csv")),
      stitched_equity_curve_csv = file.path(output_dir, paste0(prefix, "_stitched_equity_curve.csv")),
      stitched_metrics_csv = file.path(output_dir, paste0(prefix, "_stitched_metrics.csv")),
      stitched_metrics_md = file.path(output_dir, paste0(prefix, "_stitched_metrics.md")),
      stitched_strategy_chart_png = file.path(output_dir, paste0(prefix, "_stitched_strategy_chart.png")),
      stitched_equity_curve_png = file.path(output_dir, paste0(prefix, "_stitched_equity_curve.png"))
    )
  )
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(output_dir)) {
    g5_stop(paste0("Could not create multi-signal WFA output directory: ", output_dir))
  }
  utils::write.csv(wfa$folds, paths$fold_spec_csv, row.names = FALSE)
  utils::write.csv(wfa$selected_models, paths$selected_models_csv, row.names = FALSE)
  utils::write.csv(wfa$train_parameter_performance, paths$train_parameter_performance_csv, row.names = FALSE)
  utils::write.csv(wfa$model_stability, paths$model_stability_csv, row.names = FALSE)
  utils::write.csv(wfa$fold_oos_summary, paths$fold_oos_summary_csv, row.names = FALSE)
  utils::write.csv(wfa$stitched_indicators, paths$stitched_indicators_csv, row.names = FALSE)
  utils::write.csv(wfa$stitched_trades, paths$stitched_trades_csv, row.names = FALSE)
  utils::write.csv(wfa$stitched_equity_curve, paths$stitched_equity_curve_csv, row.names = FALSE)
  utils::write.csv(wfa$stitched_metrics, paths$stitched_metrics_csv, row.names = FALSE)
  report_settings <- list(
    as_of_timestamp = result$resolved_session$as_of_timestamp,
    query_start_date = min(as.Date(result$bars$session_date)),
    query_end_date = max(as.Date(result$bars$session_date)),
    wfa_start_date = as.Date(wfa_start_date),
    wfa_end_date = as.Date(wfa_end_date),
    bar_count = nrow(result$bars),
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    train_days = g5_ema_cross_wfa_quarters_to_days(train_quarters),
    oos_days = g5_ema_cross_wfa_quarters_to_days(oos_quarters),
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    candidate_families = candidate_families
  )
  g5_ema_cross_wfa_multi_metrics_markdown(wfa$folds, wfa$selected_models, wfa$train_parameter_performance, wfa$stitched_metrics, wfa$fold_oos_summary, wfa$model_stability, report_settings, paths$stitched_metrics_md)
  g5_write_ema_cross_wfa_stitched_strategy_chart_png(wfa$stitched_indicators, wfa$stitched_trades, wfa$folds, symbol, paths$stitched_strategy_chart_png)
  g5_write_ema_cross_wfa_stitched_equity_curve_png(wfa$stitched_equity_curve, wfa$folds, symbol, paths$stitched_equity_curve_png)
  paths <- lapply(paths, normalizePath, winslash = "/", mustWork = FALSE)
  c(wfa, list(paths = paths, manifest = written$manifest))
}
