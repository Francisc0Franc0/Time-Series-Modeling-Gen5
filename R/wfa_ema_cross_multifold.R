# Gen5.1 multi-signal WFA proof of concept.

g5_ema_cross_wfa_multi_schema_version <- function() {
  "gen5_ema_cross_wfa_multi_v0.1"
}

g5_ema_cross_wfa_multi_artifact_prefix <- function(as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count, candidate_families = c("ema_cross", "bollinger_touch")) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  family_label <- paste0(length(g5_wfa_candidate_families(candidate_families)), "fam")
  window_label <- paste0(
    "w",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_start_date))),
    "_to_",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date)))
  )
  paste(c("multi_wfa", symbol, paste0(fold_count, "f"), family_label, window_label, stamp), collapse = "_")
}

g5_ema_cross_wfa_multi_output_dir <- function(repo_root, as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count, candidate_families = c("ema_cross", "bollinger_touch")) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "wfa_pocs",
    g5_ema_cross_wfa_multi_artifact_prefix(as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count, candidate_families)
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

g5_wfa_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tryCatch(
    utils::write.csv(x, path, row.names = FALSE),
    error = function(e) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      utils::write.csv(x, path, row.names = FALSE)
    }
  )
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_wfa_candidate_families <- function(candidate_families) {
  candidate_families <- unique(trimws(as.character(candidate_families)))
  candidate_families <- candidate_families[nzchar(candidate_families)]
  allowed <- c(
    "ema_cross",
    "ema_trend",
    "bollinger_touch",
    "bollinger_mid_reversion",
    "rsi_mr",
    "zret_mr",
    "breakout",
    "pullback_in_uptrend",
    "vol_expansion_breakout",
    "donchian_breakout_vol_expand",
    "no_trade"
  )
  if (length(candidate_families) == 0L || any(!candidate_families %in% allowed)) {
    g5_stop(paste0("candidate_families must be drawn from: ", paste(allowed, collapse = ", ")))
  }
  candidate_families
}

g5_wfa_strategy_grid_preset <- function(strategy_grid_preset = "standard") {
  preset <- as.character(strategy_grid_preset)[[1L]]
  allowed <- c("standard", "modest_expanded", "gen4_daily_default")
  if (!preset %in% allowed) {
    g5_stop(paste0("strategy_grid_preset must be one of: ", paste(allowed, collapse = ", ")))
  }
  preset
}

g5_wfa_strategy_grid_preset_values <- function(strategy_grid_preset = "standard") {
  preset <- g5_wfa_strategy_grid_preset(strategy_grid_preset)
  if (identical(preset, "gen4_daily_default")) {
    return(list(
      fast_periods = c(1L, 5L, 10L, 15L),
      slow_periods = c(10L, 20L, 30L, 50L),
      bb_lookback_periods = c(14L, 20L, 30L),
      bb_sd_multipliers = c(1.5, 2.0, 2.5),
      ema_trend_fast_periods = c(5L, 10L, 15L, 20L),
      ema_trend_slow_periods = c(20L, 50L, 75L),
      rsi_periods = c(7L, 10L, 14L, 21L),
      rsi_lower_thresholds = c(25, 30, 35),
      rsi_upper_thresholds = c(65, 70, 75),
      zret_windows = c(10L, 20L, 40L),
      zret_entry_z = c(2.0, 2.5),
      zret_exit_z = c(0.0, 0.5, 1.0),
      breakout_lookbacks = c(20L, 30L),
      breakout_buffers = c(0.0),
      vol_expand_thresholds = c(0.0, 0.10, 0.20),
      pullback_fast_periods = c(5L, 10L, 15L),
      pullback_slow_periods = c(25L, 50L, 75L),
      pullback_rsi_lower_thresholds = c(30, 35, 40),
      pullback_rsi_upper_thresholds = c(55, 60, 65)
    ))
  }
  if (identical(preset, "modest_expanded")) {
    return(list(
      fast_periods = c(8L, 12L, 16L),
      slow_periods = c(30L, 50L),
      bb_lookback_periods = c(10L, 20L, 30L),
      bb_sd_multipliers = c(1.5, 2, 2.5),
      ema_trend_fast_periods = c(5L, 10L, 15L, 20L),
      ema_trend_slow_periods = c(25L, 50L, 75L),
      rsi_periods = c(7L, 14L),
      rsi_lower_thresholds = c(25, 30, 35),
      rsi_upper_thresholds = c(60, 70, 75),
      zret_windows = c(10L, 20L, 30L),
      zret_entry_z = c(2.0, 2.5),
      zret_exit_z = c(0.0, 0.5),
      breakout_lookbacks = c(20L, 30L, 40L),
      breakout_buffers = c(0, 0.005),
      vol_expand_thresholds = c(0.0, 0.10, 0.20),
      pullback_fast_periods = c(5L, 10L, 15L),
      pullback_slow_periods = c(25L, 50L),
      pullback_rsi_lower_thresholds = c(30, 35, 40),
      pullback_rsi_upper_thresholds = c(55, 60)
    ))
  }
  list()
}

g5_wfa_num_id_label <- function(x) {
  x <- as.numeric(x)
  if (length(x) != 1L || is.na(x) || !is.finite(x)) {
    g5_stop("Numeric WFA ID values must be finite numbers.")
  }
  label <- format(x, trim = TRUE, scientific = FALSE)
  if (grepl(".", label, fixed = TRUE)) {
    label <- sub("0+$", "", label)
    label <- sub("\\.$", "", label)
  }
  if (!nzchar(label)) {
    label <- "0"
  }
  gsub("-", "m", gsub(".", "p", label, fixed = TRUE), fixed = TRUE)
}

g5_wfa_model_value <- function(model, col, default = NA) {
  if (col %in% names(model)) model[[col]][[1L]] else default
}

g5_wfa_model_parameter_label <- function(model) {
  family <- as.character(model$strategy_family[[1L]])
  if (identical(family, "ema_cross")) {
    return(paste0("fast=", model$fast_period[[1L]], ", slow=", model$slow_period[[1L]]))
  }
  if (identical(family, "ema_trend")) {
    return(paste0("fast=", model$fast_period[[1L]], ", slow=", model$slow_period[[1L]], ", slope_lookback=3"))
  }
  if (identical(family, "bollinger_touch")) {
    return(paste0("lookback=", model$lookback_period[[1L]], ", sd=", model$sd_multiplier[[1L]], ", exit=upper_band"))
  }
  if (identical(family, "bollinger_mid_reversion")) {
    return(paste0("lookback=", model$lookback_period[[1L]], ", sd=", model$sd_multiplier[[1L]], ", exit=mid_band"))
  }
  if (identical(family, "rsi_mr")) {
    return(paste0("rsi_n=", model$rsi_period[[1L]], ", lo=", model$rsi_lower[[1L]], ", hi=", model$rsi_upper[[1L]]))
  }
  if (identical(family, "zret_mr")) {
    return(paste0("window=", model$zret_window[[1L]], ", entry_z=", model$zret_entry_z[[1L]], ", exit_z=", model$zret_exit_z[[1L]]))
  }
  if (identical(family, "breakout")) {
    return(paste0("lookback=", model$breakout_lookback[[1L]], ", buffer=", model$breakout_buffer[[1L]]))
  }
  if (identical(family, "vol_expansion_breakout")) {
    return(paste0("lookback=", model$breakout_lookback[[1L]], ", buffer=", model$breakout_buffer[[1L]], ", vol_expand>=", model$vol_expand_threshold[[1L]]))
  }
  if (identical(family, "donchian_breakout_vol_expand")) {
    return(paste0("lookback=", model$breakout_lookback[[1L]], ", buffer=", model$breakout_buffer[[1L]], ", vol_expand>=", model$vol_expand_threshold[[1L]], ", compression=prior_width_below_mean"))
  }
  if (identical(family, "pullback_in_uptrend")) {
    return(paste0("fast=", model$fast_period[[1L]], ", slow=", model$slow_period[[1L]], ", rsi_lo=", model$rsi_lower[[1L]], ", rsi_hi=", model$rsi_upper[[1L]]))
  }
  if (identical(family, "no_trade")) {
    return("cash/no-position benchmark")
  }
  ""
}

g5_wfa_pct_id_label <- function(x) {
  x <- as.numeric(x)
  if (length(x) != 1L || is.na(x) || !is.finite(x) || x <= 0) {
    g5_stop("Percentage values for WFA IDs must be positive finite numbers.")
  }
  pct <- 100 * x
  label <- if (abs(pct - round(pct)) < 1e-8) {
    as.character(as.integer(round(pct)))
  } else {
    sub("\\.?0+$", "", format(pct, trim = TRUE, scientific = FALSE))
  }
  paste0(gsub("\\.", "p", label), "pct")
}

g5_wfa_exit_stack_id <- function(include_native_exit = TRUE, max_hold_sessions = NA_integer_, stop_loss_pct = NA_real_, take_profit_pct = NA_real_) {
  parts <- character()
  if (isTRUE(include_native_exit)) {
    parts <- c(parts, "native")
  }
  if (!is.na(stop_loss_pct)) {
    parts <- c(parts, paste0("stop", g5_wfa_pct_id_label(stop_loss_pct)))
  }
  if (!is.na(take_profit_pct)) {
    parts <- c(parts, paste0("take", g5_wfa_pct_id_label(take_profit_pct)))
  }
  if (!is.na(max_hold_sessions)) {
    parts <- c(parts, paste0("maxhold", as.integer(max_hold_sessions)))
  }
  if (length(parts) == 0L) {
    g5_stop("Exit stack must include at least one exit rule.")
  }
  if (identical(parts, "native")) {
    return("native_only")
  }
  paste(parts, collapse = "_")
}

g5_wfa_exit_stack_grid <- function(max_hold_sessions = c(10L, 20L, 40L), stop_loss_pcts = 0.10, take_profit_pcts = 0.25) {
  max_hold_sessions <- sort(unique(as.integer(max_hold_sessions)))
  max_hold_sessions <- max_hold_sessions[!is.na(max_hold_sessions) & max_hold_sessions > 0L]
  stop_loss_pcts <- sort(unique(as.numeric(stop_loss_pcts)))
  stop_loss_pcts <- stop_loss_pcts[!is.na(stop_loss_pcts) & is.finite(stop_loss_pcts) & stop_loss_pcts > 0]
  take_profit_pcts <- sort(unique(as.numeric(take_profit_pcts)))
  take_profit_pcts <- take_profit_pcts[!is.na(take_profit_pcts) & is.finite(take_profit_pcts) & take_profit_pcts > 0]
  if (length(max_hold_sessions) == 0L || length(stop_loss_pcts) == 0L || length(take_profit_pcts) == 0L) {
    g5_stop("Exit stack grid requires at least one max hold, stop loss, and take profit value.")
  }

  rows <- list(
    data.frame(include_native_exit = TRUE, max_hold_sessions = NA_integer_, stop_loss_pct = NA_real_, take_profit_pct = NA_real_, stringsAsFactors = FALSE)
  )
  for (hold in max_hold_sessions) {
    rows[[length(rows) + 1L]] <- data.frame(include_native_exit = TRUE, max_hold_sessions = hold, stop_loss_pct = NA_real_, take_profit_pct = NA_real_, stringsAsFactors = FALSE)
  }
  for (stop in stop_loss_pcts) {
    rows[[length(rows) + 1L]] <- data.frame(include_native_exit = TRUE, max_hold_sessions = NA_integer_, stop_loss_pct = stop, take_profit_pct = NA_real_, stringsAsFactors = FALSE)
  }
  for (take in take_profit_pcts) {
    rows[[length(rows) + 1L]] <- data.frame(include_native_exit = TRUE, max_hold_sessions = NA_integer_, stop_loss_pct = NA_real_, take_profit_pct = take, stringsAsFactors = FALSE)
  }
  for (stop in stop_loss_pcts) {
    for (take in take_profit_pcts) {
      rows[[length(rows) + 1L]] <- data.frame(include_native_exit = TRUE, max_hold_sessions = NA_integer_, stop_loss_pct = stop, take_profit_pct = take, stringsAsFactors = FALSE)
      for (hold in max_hold_sessions) {
        rows[[length(rows) + 1L]] <- data.frame(include_native_exit = TRUE, max_hold_sessions = hold, stop_loss_pct = stop, take_profit_pct = take, stringsAsFactors = FALSE)
      }
    }
  }
  out <- do.call(rbind, rows)
  out$exit_stack_id <- mapply(
    g5_wfa_exit_stack_id,
    include_native_exit = out$include_native_exit,
    max_hold_sessions = out$max_hold_sessions,
    stop_loss_pct = out$stop_loss_pct,
    take_profit_pct = out$take_profit_pct,
    USE.NAMES = FALSE
  )
  out <- out[!duplicated(out$exit_stack_id), c("exit_stack_id", "include_native_exit", "max_hold_sessions", "stop_loss_pct", "take_profit_pct"), drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_wfa_no_trade_exit_stack <- function() {
  data.frame(
    exit_stack_id = "no_exit",
    include_native_exit = FALSE,
    max_hold_sessions = NA_integer_,
    stop_loss_pct = NA_real_,
    take_profit_pct = NA_real_,
    stringsAsFactors = FALSE
  )
}

g5_wfa_exit_stacks_for_candidates <- function(exit_stacks, candidate_families) {
  candidate_families <- g5_wfa_candidate_families(candidate_families)
  if (!"no_trade" %in% candidate_families) {
    return(exit_stacks)
  }
  out <- rbind(exit_stacks, g5_wfa_no_trade_exit_stack())
  out <- out[!duplicated(out$exit_stack_id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_wfa_exit_stack_label <- function(stack) {
  stack_value <- function(col) {
    if (col %in% names(stack)) stack[[col]][[1L]] else NA
  }
  present_number <- function(x) {
    x <- suppressWarnings(as.numeric(x))
    if (length(x) != 1L || is.na(x) || !is.finite(x)) NA_real_ else x
  }
  include_native <- stack_value("include_native_exit")
  include_native <- isTRUE(include_native) || identical(toupper(as.character(include_native)), "TRUE")
  stop_loss_pct <- present_number(stack_value("stop_loss_pct"))
  take_profit_pct <- present_number(stack_value("take_profit_pct"))
  max_hold_sessions <- present_number(stack_value("max_hold_sessions"))
  parts <- character()
  if (include_native) {
    parts <- c(parts, "native")
  }
  if (!is.na(stop_loss_pct)) {
    parts <- c(parts, paste0("stop=", sprintf("%.1f%%", 100 * stop_loss_pct)))
  }
  if (!is.na(take_profit_pct)) {
    parts <- c(parts, paste0("take=", sprintf("%.1f%%", 100 * take_profit_pct)))
  }
  if (!is.na(max_hold_sessions)) {
    parts <- c(parts, paste0("max_hold=", as.integer(max_hold_sessions), " sessions"))
  }
  if (length(parts) == 0L) {
    return("no exits (cash)")
  }
  paste(parts, collapse = " + ")
}

g5_wfa_strategy_spec_id <- function(model_instance_id, exit_stack_id) {
  paste(as.character(model_instance_id), as.character(exit_stack_id), sep = "__")
}

g5_wfa_exit_event <- function(ind, idx, open_trade, exit_stack) {
  triggered <- character()
  close_price <- as.numeric(ind$close[[idx]])
  if (isTRUE(exit_stack$include_native_exit[[1L]]) && isTRUE(ind$exit_signal[[idx]])) {
    triggered <- c(triggered, "native_exit")
  }
  if (!is.na(exit_stack$stop_loss_pct[[1L]]) && is.finite(close_price)) {
    stop_level <- open_trade$entry_execution_price * (1 - as.numeric(exit_stack$stop_loss_pct[[1L]]))
    if (close_price <= stop_level) {
      triggered <- c(triggered, "stop_loss")
    }
  }
  if (!is.na(exit_stack$take_profit_pct[[1L]]) && is.finite(close_price)) {
    take_level <- open_trade$entry_execution_price * (1 + as.numeric(exit_stack$take_profit_pct[[1L]]))
    if (close_price >= take_level) {
      triggered <- c(triggered, "take_profit")
    }
  }
  if (!is.na(exit_stack$max_hold_sessions[[1L]])) {
    holding_sessions <- idx - open_trade$entry_execution_idx + 1L
    if (holding_sessions >= as.integer(exit_stack$max_hold_sessions[[1L]])) {
      triggered <- c(triggered, "max_hold")
    }
  }
  if (length(triggered) == 0L) {
    return(NULL)
  }
  priority <- c("stop_loss", "native_exit", "take_profit", "max_hold")
  primary <- priority[priority %in% triggered][[1L]]
  list(
    primary_exit_reason = primary,
    exit_attribution = if (identical(primary, "native_exit")) "native" else "exit_stack",
    triggered_exit_rules = paste(triggered, collapse = ";"),
    exit_signal_rule = paste0(primary, "_close_based_next_open")
  )
}

g5_wfa_normalize_indicator_columns <- function(ind, model) {
  for (col in c("fast_ema", "slow_ema", "bb_mid", "bb_upper", "bb_lower", "rsi", "return_z", "breakout_high", "breakout_mid", "vol_width", "vol_width_mean", "vol_expansion")) {
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

g5_wfa_rolling_mean <- function(x, period) {
  g5_bollinger_touch_rolling_mean(x, period)
}

g5_wfa_rolling_sd <- function(x, period) {
  g5_bollinger_touch_rolling_sd(x, period)
}

g5_wfa_bollinger_width <- function(close, period, sd_multiplier = 2) {
  mid <- g5_wfa_rolling_mean(close, period)
  sigma <- g5_wfa_rolling_sd(close, period)
  upper <- mid + sd_multiplier * sigma
  lower <- mid - sd_multiplier * sigma
  width <- (upper - lower) / pmax(mid, 1e-8)
  width[!is.finite(width)] <- NA_real_
  width
}

g5_wfa_rolling_max <- function(x, period) {
  period <- as.integer(period)
  if (is.na(period) || period < 2L) {
    g5_stop("Rolling max period must be an integer >= 2.")
  }
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (length(x) < period) {
    return(out)
  }
  for (i in period:length(x)) {
    out[[i]] <- max(x[(i - period + 1L):i], na.rm = FALSE)
  }
  out
}

g5_wfa_rsi <- function(close, period) {
  period <- as.integer(period)
  if (is.na(period) || period < 2L) {
    g5_stop("RSI period must be an integer >= 2.")
  }
  close <- as.numeric(close)
  delta <- c(NA_real_, diff(close))
  gains <- pmax(delta, 0, na.rm = FALSE)
  losses <- pmax(-delta, 0, na.rm = FALSE)
  avg_gain <- g5_wfa_rolling_mean(gains, period)
  avg_loss <- g5_wfa_rolling_mean(losses, period)
  rs <- avg_gain / avg_loss
  rsi <- 100 - (100 / (1 + rs))
  rsi[is.finite(avg_gain) & avg_loss == 0 & avg_gain > 0] <- 100
  rsi[is.finite(avg_loss) & avg_gain == 0 & avg_loss > 0] <- 0
  rsi[is.finite(avg_gain) & is.finite(avg_loss) & avg_gain == 0 & avg_loss == 0] <- 50
  rsi
}

g5_wfa_signal_state_from_position <- function(desired_position) {
  desired_position <- as.numeric(desired_position)
  entry <- desired_position > 0 & c(TRUE, head(desired_position, -1L) <= 0)
  exit <- desired_position <= 0 & c(FALSE, head(desired_position, -1L) > 0)
  list(entry = entry, exit = exit)
}

g5_wfa_bollinger_mid_reversion_strategy_id <- function(lookback_period, sd_multiplier) {
  lookback_period <- as.integer(lookback_period)
  sd_multiplier <- as.numeric(sd_multiplier)
  if (is.na(lookback_period) || lookback_period < 2L || is.na(sd_multiplier) || sd_multiplier <= 0) {
    g5_stop("Bollinger mid reversion parameters must be lookback_period >= 2 and sd_multiplier > 0.")
  }
  paste0("bollinger_mid_reversion_n", lookback_period, "_sd", g5_bollinger_touch_sd_label(sd_multiplier))
}

g5_wfa_vol_expansion_breakout_id <- function(strategy_family, lookback, buffer, vol_expand_threshold) {
  lookback <- as.integer(lookback)
  buffer <- as.numeric(buffer)
  vol_expand_threshold <- as.numeric(vol_expand_threshold)
  if (is.na(lookback) || lookback < 2L || is.na(buffer) || buffer < 0 || is.na(vol_expand_threshold) || vol_expand_threshold < 0) {
    g5_stop("Volatility-expansion breakout parameters must be lookback >= 2, buffer >= 0, and vol_expand_threshold >= 0.")
  }
  prefix <- switch(
    as.character(strategy_family),
    vol_expansion_breakout = "vol_expansion_breakout",
    donchian_breakout_vol_expand = "donchian_volexp",
    g5_stop(paste0("Unsupported volatility breakout strategy family for ID: ", strategy_family))
  )
  paste0(prefix, "_lb", lookback, "_buf", g5_wfa_num_id_label(buffer), "_vx", g5_wfa_num_id_label(vol_expand_threshold))
}

g5_wfa_vol_expansion_breakout_indicators <- function(bars, symbol, model, require_prior_compression = FALSE) {
  ind <- g5_ema_cross_prepare_bars(bars, symbol)
  family <- as.character(model$strategy_family[[1L]])
  lookback <- as.integer(model$breakout_lookback[[1L]])
  buffer <- as.numeric(model$breakout_buffer[[1L]])
  threshold <- as.numeric(model$vol_expand_threshold[[1L]])
  prior_high <- c(NA_real_, head(g5_wfa_rolling_max(ind$close, lookback), -1L))
  mid <- g5_wfa_rolling_mean(ind$close, lookback)
  width <- g5_wfa_bollinger_width(ind$close, lookback, sd_multiplier = 2)
  prior_width <- c(NA_real_, head(width, -1L))
  width_mean <- g5_wfa_rolling_mean(width, lookback)
  vol_expand <- width / prior_width - 1
  vol_expand[!is.finite(vol_expand)] <- NA_real_
  compression_ok <- rep(TRUE, nrow(ind))
  if (isTRUE(require_prior_compression)) {
    compression_ok <- is.finite(prior_width) & is.finite(width_mean) & prior_width < width_mean
  }
  entry_level <- prior_high * (1 + buffer)
  ind$strategy_family <- family
  ind$strategy_id <- g5_wfa_vol_expansion_breakout_id(family, lookback, buffer, threshold)
  ind$model_instance_id <- ind$strategy_id
  ind$breakout_lookback <- lookback
  ind$breakout_buffer <- buffer
  ind$vol_expand_threshold <- threshold
  ind$breakout_high <- entry_level
  ind$breakout_mid <- mid
  ind$vol_width <- width
  ind$vol_width_mean <- width_mean
  ind$vol_expansion <- vol_expand
  ind$entry_signal <- is.finite(entry_level) & is.finite(vol_expand) & compression_ok & ind$close > entry_level & vol_expand >= threshold
  ind$exit_signal <- is.finite(mid) & ind$close < mid
  ind$entry_signal_rule <- if (isTRUE(require_prior_compression)) {
    "close_above_donchian_high_with_prior_compression_and_vol_expansion_when_flat"
  } else {
    "close_above_prior_rolling_high_with_vol_expansion_when_flat"
  }
  ind$exit_signal_rule <- "close_below_breakout_midline_when_long"
  ind$signal_state <- ifelse(ind$entry_signal, "vol_expansion_breakout", ifelse(ind$exit_signal, "midline_failure", ifelse(is.finite(vol_expand), "waiting_for_breakout_or_expansion", "unknown")))
  ind
}

g5_wfa_model_indicators <- function(bars, symbol, model) {
  family <- as.character(model$strategy_family[[1L]])
  if (identical(family, "no_trade")) {
    ind <- g5_ema_cross_prepare_bars(bars, symbol)
    ind$strategy_family <- "no_trade"
    ind$strategy_id <- "no_trade"
    ind$model_instance_id <- "no_trade"
    ind$entry_signal <- FALSE
    ind$exit_signal <- FALSE
    ind$entry_signal_rule <- "no_trade_never_enters"
    ind$exit_signal_rule <- "no_trade_no_exit"
    ind$signal_state <- "cash"
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
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
  if (identical(family, "ema_trend")) {
    fast_period <- as.integer(model$fast_period[[1L]])
    slow_period <- as.integer(model$slow_period[[1L]])
    ind <- g5_ema_cross_indicators(
      bars,
      symbol = symbol,
      fast_period = fast_period,
      slow_period = slow_period
    )
    slope <- ind$fast_ema / c(rep(NA_real_, 3L), head(ind$fast_ema, -3L)) - 1
    trend_on <- is.finite(ind$fast_ema) & is.finite(ind$slow_ema) & is.finite(slope) & ind$fast_ema > ind$slow_ema & slope > 0
    trend_on[is.na(trend_on)] <- FALSE
    state <- g5_wfa_signal_state_from_position(as.numeric(trend_on))
    ind$strategy_family <- "ema_trend"
    ind$strategy_id <- paste0("ema_trend_fast", fast_period, "_slow", slow_period)
    ind$model_instance_id <- ind$strategy_id
    ind$entry_signal <- state$entry
    ind$exit_signal <- state$exit
    ind$entry_signal_rule <- "fast_ema_above_slow_with_positive_fast_slope_turns_on"
    ind$exit_signal_rule <- "ema_trend_condition_turns_off"
    ind$signal_state <- ifelse(trend_on, "trend_on", "trend_off")
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
  if (identical(family, "bollinger_mid_reversion")) {
    ind <- g5_bollinger_touch_indicators(
      bars,
      symbol = symbol,
      lookback_period = model$lookback_period[[1L]],
      sd_multiplier = model$sd_multiplier[[1L]]
    )
    ind$strategy_family <- "bollinger_mid_reversion"
    ind$strategy_id <- g5_wfa_bollinger_mid_reversion_strategy_id(model$lookback_period[[1L]], model$sd_multiplier[[1L]])
    ind$model_instance_id <- ind$strategy_id
    ind$entry_signal <- is.finite(ind$bb_lower) & as.numeric(ind$low) <= ind$bb_lower
    ind$exit_signal <- is.finite(ind$bb_mid) & as.numeric(ind$close) >= ind$bb_mid
    ind$entry_signal_rule <- "lower_bollinger_band_touched_when_flat"
    ind$exit_signal_rule <- "close_recovered_to_bollinger_mid_when_long"
    ind$signal_state <- ifelse(ind$entry_signal, "lower_band_touched", ifelse(ind$exit_signal, "mid_band_recovered", ifelse(is.finite(ind$bb_mid), "inside_bands", "unknown")))
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  if (identical(family, "rsi_mr")) {
    ind <- g5_ema_cross_prepare_bars(bars, symbol)
    rsi_period <- as.integer(model$rsi_period[[1L]])
    rsi_lower <- as.numeric(model$rsi_lower[[1L]])
    rsi_upper <- as.numeric(model$rsi_upper[[1L]])
    ind$strategy_family <- "rsi_mr"
    ind$strategy_id <- paste0("rsi_mr_n", rsi_period, "_lo", g5_wfa_num_id_label(rsi_lower), "_hi", g5_wfa_num_id_label(rsi_upper))
    ind$model_instance_id <- ind$strategy_id
    ind$rsi_period <- rsi_period
    ind$rsi_lower <- rsi_lower
    ind$rsi_upper <- rsi_upper
    ind$rsi <- g5_wfa_rsi(ind$close, rsi_period)
    ind$entry_signal <- is.finite(ind$rsi) & ind$rsi < rsi_lower
    ind$exit_signal <- is.finite(ind$rsi) & ind$rsi > rsi_upper
    ind$entry_signal_rule <- "rsi_below_oversold_threshold_when_flat"
    ind$exit_signal_rule <- "rsi_above_recovery_threshold_when_long"
    ind$signal_state <- ifelse(ind$entry_signal, "rsi_oversold", ifelse(ind$exit_signal, "rsi_recovered", ifelse(is.finite(ind$rsi), "rsi_neutral", "unknown")))
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  if (identical(family, "zret_mr")) {
    ind <- g5_ema_cross_prepare_bars(bars, symbol)
    zret_window <- as.integer(model$zret_window[[1L]])
    entry_z <- as.numeric(model$zret_entry_z[[1L]])
    exit_z <- as.numeric(model$zret_exit_z[[1L]])
    ret1 <- ind$close / c(NA_real_, head(ind$close, -1L)) - 1
    mu <- g5_wfa_rolling_mean(ret1, zret_window)
    sigma <- g5_wfa_rolling_sd(ret1, zret_window)
    sigma[!is.finite(sigma) | sigma <= 1e-8] <- NA_real_
    z_ret <- (ret1 - mu) / sigma
    ind$strategy_family <- "zret_mr"
    ind$strategy_id <- paste0("zret_mr_n", zret_window, "_ent", g5_wfa_num_id_label(entry_z), "_ex", g5_wfa_num_id_label(exit_z))
    ind$model_instance_id <- ind$strategy_id
    ind$zret_window <- zret_window
    ind$zret_entry_z <- entry_z
    ind$zret_exit_z <- exit_z
    ind$return_z <- z_ret
    ind$entry_signal <- is.finite(z_ret) & z_ret <= -entry_z
    ind$exit_signal <- is.finite(z_ret) & z_ret >= -exit_z
    ind$entry_signal_rule <- "negative_return_zscore_shock_when_flat"
    ind$exit_signal_rule <- "return_zscore_normalized_when_long"
    ind$signal_state <- ifelse(ind$entry_signal, "negative_return_shock", ifelse(ind$exit_signal, "return_normalized", ifelse(is.finite(z_ret), "return_z_neutral", "unknown")))
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  if (identical(family, "breakout")) {
    ind <- g5_ema_cross_prepare_bars(bars, symbol)
    lookback <- as.integer(model$breakout_lookback[[1L]])
    buffer <- as.numeric(model$breakout_buffer[[1L]])
    prior_high <- c(NA_real_, head(g5_wfa_rolling_max(ind$close, lookback), -1L))
    mid <- g5_wfa_rolling_mean(ind$close, lookback)
    entry_level <- prior_high * (1 + buffer)
    ind$strategy_family <- "breakout"
    ind$strategy_id <- paste0("breakout_lb", lookback, "_buf", g5_wfa_num_id_label(buffer))
    ind$model_instance_id <- ind$strategy_id
    ind$breakout_lookback <- lookback
    ind$breakout_buffer <- buffer
    ind$breakout_high <- entry_level
    ind$breakout_mid <- mid
    ind$entry_signal <- is.finite(entry_level) & ind$close > entry_level
    ind$exit_signal <- is.finite(mid) & ind$close < mid
    ind$entry_signal_rule <- "close_above_prior_rolling_high_plus_buffer_when_flat"
    ind$exit_signal_rule <- "close_below_breakout_midline_when_long"
    ind$signal_state <- ifelse(ind$entry_signal, "breakout", ifelse(ind$exit_signal, "midline_failure", ifelse(is.finite(mid), "inside_channel", "unknown")))
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  if (identical(family, "vol_expansion_breakout")) {
    ind <- g5_wfa_vol_expansion_breakout_indicators(bars, symbol, model, require_prior_compression = FALSE)
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  if (identical(family, "donchian_breakout_vol_expand")) {
    ind <- g5_wfa_vol_expansion_breakout_indicators(bars, symbol, model, require_prior_compression = TRUE)
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  if (identical(family, "pullback_in_uptrend")) {
    ind <- g5_ema_cross_prepare_bars(bars, symbol)
    fast_period <- as.integer(model$fast_period[[1L]])
    slow_period <- as.integer(model$slow_period[[1L]])
    rsi_lower <- as.numeric(model$rsi_lower[[1L]])
    rsi_upper <- as.numeric(model$rsi_upper[[1L]])
    ind$fast_ema <- g5_ema_cross_ema(ind$close, fast_period)
    ind$slow_ema <- g5_ema_cross_ema(ind$close, slow_period)
    slow_slope <- ind$slow_ema / c(rep(NA_real_, 3L), head(ind$slow_ema, -3L)) - 1
    ind$rsi <- g5_wfa_rsi(ind$close, 14L)
    touch_fast <- is.finite(ind$fast_ema) & abs(ind$close / pmax(ind$fast_ema, 1e-8) - 1) < 0.003
    uptrend <- is.finite(ind$slow_ema) & is.finite(slow_slope) & ind$close > ind$slow_ema & slow_slope > 0
    ind$strategy_family <- "pullback_in_uptrend"
    ind$strategy_id <- paste0("pullback_up_f", fast_period, "_s", slow_period, "_lo", g5_wfa_num_id_label(rsi_lower), "_hi", g5_wfa_num_id_label(rsi_upper))
    ind$model_instance_id <- ind$strategy_id
    ind$rsi_period <- 14L
    ind$rsi_lower <- rsi_lower
    ind$rsi_upper <- rsi_upper
    ind$entry_signal <- uptrend & ((is.finite(ind$rsi) & ind$rsi < rsi_lower) | touch_fast)
    ind$exit_signal <- is.finite(ind$rsi) & ind$rsi > rsi_upper
    ind$entry_signal_rule <- "uptrend_pullback_rsi_or_fast_ema_touch_when_flat"
    ind$exit_signal_rule <- "rsi_recovered_from_pullback_when_long"
    ind$signal_state <- ifelse(ind$entry_signal, "uptrend_pullback", ifelse(ind$exit_signal, "pullback_recovered", ifelse(uptrend, "uptrend_no_pullback", "no_uptrend")))
    return(g5_wfa_normalize_indicator_columns(ind, model))
  }
  g5_stop(paste0("Unsupported WFA strategy_family: ", family))
}

g5_wfa_candidate_model_grid <- function(
  fast_periods,
  slow_periods,
  bb_lookback_periods = c(10L, 20L, 30L),
  bb_sd_multipliers = c(1.5, 2, 2.5),
  ema_trend_fast_periods = c(5L, 10L, 15L),
  ema_trend_slow_periods = c(25L, 50L, 75L),
  rsi_periods = c(7L, 14L),
  rsi_lower_thresholds = c(30, 35),
  rsi_upper_thresholds = c(60, 70),
  zret_windows = c(10L, 20L),
  zret_entry_z = c(2.0, 2.5),
  zret_exit_z = c(0.0, 0.5),
  breakout_lookbacks = c(20L, 30L),
  breakout_buffers = c(0),
  vol_expand_thresholds = c(0.0, 0.10, 0.20),
  pullback_fast_periods = c(5L, 10L),
  pullback_slow_periods = c(25L, 50L),
  pullback_rsi_lower_thresholds = c(35, 40),
  pullback_rsi_upper_thresholds = c(55, 60),
  candidate_families = c("ema_cross", "bollinger_touch")
) {
  candidate_families <- g5_wfa_candidate_families(candidate_families)
  rows <- list()
  add_model <- function(strategy_family, model_instance_id, fast_period = NA_integer_, slow_period = NA_integer_, lookback_period = NA_integer_, sd_multiplier = NA_real_, rsi_period = NA_integer_, rsi_lower = NA_real_, rsi_upper = NA_real_, zret_window = NA_integer_, zret_entry_z = NA_real_, zret_exit_z = NA_real_, breakout_lookback = NA_integer_, breakout_buffer = NA_real_, vol_expand_threshold = NA_real_) {
    rows[[length(rows) + 1L]] <<- data.frame(
      strategy_family = strategy_family,
      model_instance_id = model_instance_id,
      fast_period = fast_period,
      slow_period = slow_period,
      lookback_period = lookback_period,
      sd_multiplier = sd_multiplier,
      rsi_period = rsi_period,
      rsi_lower = rsi_lower,
      rsi_upper = rsi_upper,
      zret_window = zret_window,
      zret_entry_z = zret_entry_z,
      zret_exit_z = zret_exit_z,
      breakout_lookback = breakout_lookback,
      breakout_buffer = breakout_buffer,
      vol_expand_threshold = vol_expand_threshold,
      stringsAsFactors = FALSE
    )
  }
  if ("no_trade" %in% candidate_families) {
    add_model("no_trade", "no_trade")
  }
  if ("ema_cross" %in% candidate_families) {
    fast_periods <- sort(unique(as.integer(fast_periods)))
    slow_periods <- sort(unique(as.integer(slow_periods)))
    for (fast in fast_periods) {
      for (slow in slow_periods) {
        if (is.na(fast) || is.na(slow) || fast >= slow) {
          next
        }
        add_model("ema_cross", g5_ema_cross_strategy_id(fast, slow), fast_period = fast, slow_period = slow)
      }
    }
  }
  if ("ema_trend" %in% candidate_families) {
    ema_trend_fast_periods <- sort(unique(as.integer(ema_trend_fast_periods)))
    ema_trend_slow_periods <- sort(unique(as.integer(ema_trend_slow_periods)))
    for (fast in ema_trend_fast_periods) {
      for (slow in ema_trend_slow_periods) {
        if (is.na(fast) || is.na(slow) || fast >= slow) {
          next
        }
        add_model("ema_trend", paste0("ema_trend_fast", fast, "_slow", slow), fast_period = fast, slow_period = slow)
      }
    }
  }
  if (any(c("bollinger_touch", "bollinger_mid_reversion") %in% candidate_families)) {
    bb_lookback_periods <- sort(unique(as.integer(bb_lookback_periods)))
    bb_sd_multipliers <- sort(unique(as.numeric(bb_sd_multipliers)))
    for (lookback in bb_lookback_periods) {
      for (sd_multiplier in bb_sd_multipliers) {
        if (is.na(lookback) || lookback < 2L || is.na(sd_multiplier) || sd_multiplier <= 0) {
          next
        }
        if ("bollinger_touch" %in% candidate_families) {
          add_model("bollinger_touch", g5_bollinger_touch_strategy_id(lookback, sd_multiplier), lookback_period = lookback, sd_multiplier = sd_multiplier)
        }
        if ("bollinger_mid_reversion" %in% candidate_families) {
          add_model("bollinger_mid_reversion", g5_wfa_bollinger_mid_reversion_strategy_id(lookback, sd_multiplier), lookback_period = lookback, sd_multiplier = sd_multiplier)
        }
      }
    }
  }
  if ("rsi_mr" %in% candidate_families) {
    rsi_periods <- sort(unique(as.integer(rsi_periods)))
    rsi_lower_thresholds <- sort(unique(as.numeric(rsi_lower_thresholds)))
    rsi_upper_thresholds <- sort(unique(as.numeric(rsi_upper_thresholds)))
    for (period in rsi_periods) {
      for (lo in rsi_lower_thresholds) {
        for (hi in rsi_upper_thresholds) {
          if (is.na(period) || period < 2L || is.na(lo) || is.na(hi) || hi <= lo || (hi - lo) < 20) {
            next
          }
          add_model("rsi_mr", paste0("rsi_mr_n", period, "_lo", g5_wfa_num_id_label(lo), "_hi", g5_wfa_num_id_label(hi)), rsi_period = period, rsi_lower = lo, rsi_upper = hi)
        }
      }
    }
  }
  if ("zret_mr" %in% candidate_families) {
    zret_windows <- sort(unique(as.integer(zret_windows)))
    zret_entry_z <- sort(unique(as.numeric(zret_entry_z)))
    zret_exit_z <- sort(unique(as.numeric(zret_exit_z)))
    for (window in zret_windows) {
      for (entry_z in zret_entry_z) {
        for (exit_z in zret_exit_z) {
          if (is.na(window) || window < 2L || is.na(entry_z) || entry_z <= 0 || is.na(exit_z) || exit_z < 0) {
            next
          }
          add_model("zret_mr", paste0("zret_mr_n", window, "_ent", g5_wfa_num_id_label(entry_z), "_ex", g5_wfa_num_id_label(exit_z)), zret_window = window, zret_entry_z = entry_z, zret_exit_z = exit_z)
        }
      }
    }
  }
  if ("breakout" %in% candidate_families) {
    breakout_lookbacks <- sort(unique(as.integer(breakout_lookbacks)))
    breakout_buffers <- sort(unique(as.numeric(breakout_buffers)))
    for (lookback in breakout_lookbacks) {
      for (buffer in breakout_buffers) {
        if (is.na(lookback) || lookback < 2L || is.na(buffer) || buffer < 0) {
          next
        }
        add_model("breakout", paste0("breakout_lb", lookback, "_buf", g5_wfa_num_id_label(buffer)), breakout_lookback = lookback, breakout_buffer = buffer)
      }
    }
  }
  if (any(c("vol_expansion_breakout", "donchian_breakout_vol_expand") %in% candidate_families)) {
    breakout_lookbacks <- sort(unique(as.integer(breakout_lookbacks)))
    breakout_buffers <- sort(unique(as.numeric(breakout_buffers)))
    vol_expand_thresholds <- sort(unique(as.numeric(vol_expand_thresholds)))
    for (lookback in breakout_lookbacks) {
      for (buffer in breakout_buffers) {
        for (threshold in vol_expand_thresholds) {
          if (is.na(lookback) || lookback < 2L || is.na(buffer) || buffer < 0 || is.na(threshold) || threshold < 0) {
            next
          }
          if ("vol_expansion_breakout" %in% candidate_families) {
            add_model(
              "vol_expansion_breakout",
              g5_wfa_vol_expansion_breakout_id("vol_expansion_breakout", lookback, buffer, threshold),
              breakout_lookback = lookback,
              breakout_buffer = buffer,
              vol_expand_threshold = threshold
            )
          }
          if ("donchian_breakout_vol_expand" %in% candidate_families) {
            add_model(
              "donchian_breakout_vol_expand",
              g5_wfa_vol_expansion_breakout_id("donchian_breakout_vol_expand", lookback, buffer, threshold),
              breakout_lookback = lookback,
              breakout_buffer = buffer,
              vol_expand_threshold = threshold
            )
          }
        }
      }
    }
  }
  if ("pullback_in_uptrend" %in% candidate_families) {
    pullback_fast_periods <- sort(unique(as.integer(pullback_fast_periods)))
    pullback_slow_periods <- sort(unique(as.integer(pullback_slow_periods)))
    pullback_rsi_lower_thresholds <- sort(unique(as.numeric(pullback_rsi_lower_thresholds)))
    pullback_rsi_upper_thresholds <- sort(unique(as.numeric(pullback_rsi_upper_thresholds)))
    for (fast in pullback_fast_periods) {
      for (slow in pullback_slow_periods) {
        for (lo in pullback_rsi_lower_thresholds) {
          for (hi in pullback_rsi_upper_thresholds) {
            if (is.na(fast) || is.na(slow) || fast >= slow || is.na(lo) || is.na(hi) || hi <= lo) {
              next
            }
            add_model("pullback_in_uptrend", paste0("pullback_up_f", fast, "_s", slow, "_lo", g5_wfa_num_id_label(lo), "_hi", g5_wfa_num_id_label(hi)), fast_period = fast, slow_period = slow, rsi_period = 14L, rsi_lower = lo, rsi_upper = hi)
          }
        }
      }
    }
  }
  if (length(rows) == 0L) {
    g5_stop("WFA candidate model grid resolved zero valid model instances.")
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_wfa_strategy_spec_metrics <- function(trades, equity_curve, symbol, model, exit_stack, leverage = 1) {
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  leverage <- g5_ema_cross_validate_leverage(leverage)
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
  is_no_trade <- identical(as.character(model$strategy_family[[1L]]), "no_trade")
  data.frame(
    schema_version = g5_ema_cross_wfa_multi_schema_version(),
    symbol = symbol,
    strategy_family = model$strategy_family[[1L]],
    model_instance_id = model$model_instance_id[[1L]],
    exit_stack_id = exit_stack$exit_stack_id[[1L]],
    strategy_spec_id = g5_wfa_strategy_spec_id(model$model_instance_id[[1L]], exit_stack$exit_stack_id[[1L]]),
    include_native_exit = exit_stack$include_native_exit[[1L]],
    max_hold_sessions = exit_stack$max_hold_sessions[[1L]],
    stop_loss_pct = exit_stack$stop_loss_pct[[1L]],
    take_profit_pct = exit_stack$take_profit_pct[[1L]],
    fast_period = model$fast_period[[1L]],
    slow_period = model$slow_period[[1L]],
    lookback_period = model$lookback_period[[1L]],
    sd_multiplier = model$sd_multiplier[[1L]],
    rsi_period = g5_wfa_model_value(model, "rsi_period", NA_integer_),
    rsi_lower = g5_wfa_model_value(model, "rsi_lower", NA_real_),
    rsi_upper = g5_wfa_model_value(model, "rsi_upper", NA_real_),
    zret_window = g5_wfa_model_value(model, "zret_window", NA_integer_),
    zret_entry_z = g5_wfa_model_value(model, "zret_entry_z", NA_real_),
    zret_exit_z = g5_wfa_model_value(model, "zret_exit_z", NA_real_),
    breakout_lookback = g5_wfa_model_value(model, "breakout_lookback", NA_integer_),
    breakout_buffer = g5_wfa_model_value(model, "breakout_buffer", NA_real_),
    vol_expand_threshold = g5_wfa_model_value(model, "vol_expand_threshold", NA_real_),
    leverage = leverage,
    trade_count = if (is.data.frame(trades)) nrow(trades) else 0L,
    closed_trade_count = nrow(closed),
    open_trade_count = nrow(open_trades),
    win_count = length(wins),
    loss_count = length(losses),
    flat_count = length(flats),
    win_rate = if (length(closed_returns) == 0L) NA_real_ else length(wins) / length(closed_returns),
    ending_equity = ending_equity,
    total_return = ending_equity - 1,
    cagr = g5_ema_cross_cagr(1, ending_equity, start_date, end_date),
    sharpe = if (is_no_trade) 0 else g5_ema_cross_sharpe(equity_curve$strategy_equity),
    max_drawdown = min(equity_curve$strategy_drawdown, na.rm = TRUE),
    underwater_session_count = strategy_underwater$count,
    underwater_fraction = strategy_underwater$fraction,
    max_underwater_streak = strategy_underwater$max_streak,
    average_trade_return = if (length(closed_returns) == 0L) NA_real_ else mean(closed_returns),
    best_trade_return = if (length(closed_returns) == 0L) NA_real_ else max(closed_returns),
    worst_trade_return = if (length(closed_returns) == 0L) NA_real_ else min(closed_returns),
    profit_factor = if (length(closed_returns) == 0L || length(losses) == 0L) {
      if (length(wins) == 0L) NA_real_ else Inf
    } else {
      sum(wins) / abs(sum(losses))
    },
    exposure_fraction = mean(equity_curve$in_position, na.rm = TRUE),
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

g5_wfa_strategy_spec_trades <- function(bars, symbol, model, exit_stack, trading_start_date, trading_end_date, leverage = 1) {
  leverage <- g5_ema_cross_validate_leverage(leverage)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  trading_start_date <- as.Date(trading_start_date)
  trading_end_date <- as.Date(trading_end_date)
  if (any(is.na(c(trading_start_date, trading_end_date))) || trading_start_date > trading_end_date) {
    g5_stop("trading_start_date and trading_end_date must be valid ordered dates.")
  }
  all_bars <- g5_ema_cross_prepare_bars(bars, symbol = symbol, end_date = trading_end_date)
  ind <- g5_wfa_model_indicators(all_bars, symbol, model)
  session_dates <- as.Date(all_bars$session_date)
  signal_indices <- which(session_dates >= trading_start_date & session_dates <= trading_end_date)
  latest_idx <- max(which(session_dates <= trading_end_date))
  strategy_spec_id <- g5_wfa_strategy_spec_id(model$model_instance_id[[1L]], exit_stack$exit_stack_id[[1L]])

  trades <- list()
  trade_no <- 0L
  in_position <- FALSE
  open_trade <- NULL
  pending_entry <- NULL
  pending_exit <- NULL

  for (idx in signal_indices) {
    current_date <- session_dates[[idx]]

    if (!is.null(pending_entry) && identical(as.Date(pending_entry$execution_date), current_date) && !in_position) {
      trade_no <- trade_no + 1L
      open_trade <- c(
        pending_entry,
        list(
          trade_no = trade_no,
          entry_execution_idx = idx,
          entry_execution_date = current_date,
          entry_execution_price = as.numeric(all_bars$open[[idx]])
        )
      )
      in_position <- TRUE
      pending_entry <- NULL
    }

    if (!is.null(pending_exit) && identical(as.Date(pending_exit$execution_date), current_date) && in_position) {
      entry_price <- open_trade$entry_execution_price
      exit_price <- as.numeric(all_bars$open[[idx]])
      underlying_realized_return <- (exit_price / entry_price) - 1
      realized_return <- leverage * underlying_realized_return
      trades[[length(trades) + 1L]] <- data.frame(
        schema_version = g5_ema_cross_wfa_multi_schema_version(),
        trade_id = sprintf("%s_%s_%03d", symbol, strategy_spec_id, open_trade$trade_no),
        symbol = symbol,
        strategy_family = model$strategy_family[[1L]],
        model_instance_id = model$model_instance_id[[1L]],
        exit_stack_id = exit_stack$exit_stack_id[[1L]],
        strategy_spec_id = strategy_spec_id,
        primary_exit_reason = pending_exit$primary_exit_reason,
        triggered_exit_rules = pending_exit$triggered_exit_rules,
        exit_attribution = pending_exit$exit_attribution,
        fast_period = g5_wfa_model_value(model, "fast_period", NA_integer_),
        slow_period = g5_wfa_model_value(model, "slow_period", NA_integer_),
        lookback_period = g5_wfa_model_value(model, "lookback_period", NA_integer_),
        sd_multiplier = g5_wfa_model_value(model, "sd_multiplier", NA_real_),
        rsi_period = g5_wfa_model_value(model, "rsi_period", NA_integer_),
        rsi_lower = g5_wfa_model_value(model, "rsi_lower", NA_real_),
        rsi_upper = g5_wfa_model_value(model, "rsi_upper", NA_real_),
        zret_window = g5_wfa_model_value(model, "zret_window", NA_integer_),
        zret_entry_z = g5_wfa_model_value(model, "zret_entry_z", NA_real_),
        zret_exit_z = g5_wfa_model_value(model, "zret_exit_z", NA_real_),
        breakout_lookback = g5_wfa_model_value(model, "breakout_lookback", NA_integer_),
        breakout_buffer = g5_wfa_model_value(model, "breakout_buffer", NA_real_),
        vol_expand_threshold = g5_wfa_model_value(model, "vol_expand_threshold", NA_real_),
        trade_status = "closed",
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
        latest_mark_date = session_dates[[latest_idx]],
        latest_mark_price = as.numeric(all_bars$close[[latest_idx]]),
        trace_end_date = current_date,
        trace_end_index = idx,
        trace_end_price = exit_price,
        underlying_realized_return = underlying_realized_return,
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
        leverage = leverage,
        capital_fraction = 1,
        stringsAsFactors = FALSE
      )
      in_position <- FALSE
      open_trade <- NULL
      pending_exit <- NULL
    }

    next_idx <- idx + 1L
    if (next_idx > nrow(all_bars) || session_dates[[next_idx]] > trading_end_date) {
      next
    }

    if (!in_position && is.null(pending_entry) && isTRUE(ind$entry_signal[[idx]])) {
      pending_entry <- list(
        entry_signal_rule = ind$entry_signal_rule[[idx]],
        entry_signal_date = current_date,
        entry_signal_idx = idx,
        entry_signal_price = as.numeric(all_bars$close[[idx]]),
        execution_date = session_dates[[next_idx]]
      )
    }

    if (in_position && is.null(pending_exit)) {
      exit_event <- g5_wfa_exit_event(ind, idx, open_trade, exit_stack)
      if (!is.null(exit_event)) {
        pending_exit <- c(
          exit_event,
          list(
            exit_signal_date = current_date,
            exit_signal_idx = idx,
            exit_signal_price = as.numeric(all_bars$close[[idx]]),
            execution_date = session_dates[[next_idx]]
          )
        )
      }
    }
  }

  if (in_position && !is.null(open_trade)) {
    entry_price <- open_trade$entry_execution_price
    latest_close <- as.numeric(all_bars$close[[latest_idx]])
    underlying_unrealized_return <- (latest_close / entry_price) - 1
    unrealized_return <- leverage * underlying_unrealized_return
    trades[[length(trades) + 1L]] <- data.frame(
      schema_version = g5_ema_cross_wfa_multi_schema_version(),
      trade_id = sprintf("%s_%s_%03d", symbol, strategy_spec_id, open_trade$trade_no),
      symbol = symbol,
      strategy_family = model$strategy_family[[1L]],
      model_instance_id = model$model_instance_id[[1L]],
      exit_stack_id = exit_stack$exit_stack_id[[1L]],
      strategy_spec_id = strategy_spec_id,
      primary_exit_reason = NA_character_,
      triggered_exit_rules = NA_character_,
      exit_attribution = NA_character_,
      fast_period = g5_wfa_model_value(model, "fast_period", NA_integer_),
      slow_period = g5_wfa_model_value(model, "slow_period", NA_integer_),
      lookback_period = g5_wfa_model_value(model, "lookback_period", NA_integer_),
      sd_multiplier = g5_wfa_model_value(model, "sd_multiplier", NA_real_),
      rsi_period = g5_wfa_model_value(model, "rsi_period", NA_integer_),
      rsi_lower = g5_wfa_model_value(model, "rsi_lower", NA_real_),
      rsi_upper = g5_wfa_model_value(model, "rsi_upper", NA_real_),
      zret_window = g5_wfa_model_value(model, "zret_window", NA_integer_),
      zret_entry_z = g5_wfa_model_value(model, "zret_entry_z", NA_real_),
      zret_exit_z = g5_wfa_model_value(model, "zret_exit_z", NA_real_),
      breakout_lookback = g5_wfa_model_value(model, "breakout_lookback", NA_integer_),
      breakout_buffer = g5_wfa_model_value(model, "breakout_buffer", NA_real_),
      vol_expand_threshold = g5_wfa_model_value(model, "vol_expand_threshold", NA_real_),
      trade_status = "open",
      entry_signal_date = open_trade$entry_signal_date,
      entry_signal_index = open_trade$entry_signal_idx,
      entry_signal_price = open_trade$entry_signal_price,
      entry_execution_date = open_trade$entry_execution_date,
      entry_execution_index = open_trade$entry_execution_idx,
      entry_execution_price = entry_price,
      exit_signal_date = as.Date(NA),
      exit_signal_index = NA_integer_,
      exit_signal_price = NA_real_,
      exit_execution_date = as.Date(NA),
      exit_execution_index = NA_integer_,
      exit_execution_price = NA_real_,
      latest_mark_date = session_dates[[latest_idx]],
      latest_mark_price = latest_close,
      trace_end_date = session_dates[[latest_idx]],
      trace_end_index = latest_idx,
      trace_end_price = latest_close,
      underlying_realized_return = NA_real_,
      underlying_unrealized_return = underlying_unrealized_return,
      realized_return = NA_real_,
      unrealized_return = unrealized_return,
      trace_return = unrealized_return,
      trade_outcome = if (unrealized_return > 0) "win" else if (unrealized_return < 0) "loss" else "flat",
      holding_sessions_completed = latest_idx - open_trade$entry_execution_idx + 1L,
      signal_rule = open_trade$entry_signal_rule,
      entry_execution_rule = "next_session_open_after_entry_signal",
      exit_signal_rule = "active_exit_stack_when_long",
      exit_execution_rule = "next_session_open_after_exit_signal",
      leverage = leverage,
      capital_fraction = 1,
      stringsAsFactors = FALSE
    )
  }

  if (length(trades) == 0L) {
    return(data.frame())
  }
  out <- do.call(rbind, trades)
  rownames(out) <- NULL
  out
}

g5_wfa_evaluate_strategy_spec_grid <- function(bars, symbol, trading_start_date, trading_end_date, model_grid, exit_stacks, leverage = 1) {
  rows <- list()
  for (model_i in seq_len(nrow(model_grid))) {
    model <- model_grid[model_i, , drop = FALSE]
    stacks_for_model <- if (identical(as.character(model$strategy_family[[1L]]), "no_trade")) {
      g5_wfa_no_trade_exit_stack()
    } else {
      exit_stacks[exit_stacks$exit_stack_id != "no_exit", , drop = FALSE]
    }
    for (stack_i in seq_len(nrow(stacks_for_model))) {
      exit_stack <- stacks_for_model[stack_i, , drop = FALSE]
      trades <- g5_wfa_strategy_spec_trades(
        bars,
        symbol = symbol,
        model = model,
        exit_stack = exit_stack,
        trading_start_date = trading_start_date,
        trading_end_date = trading_end_date,
        leverage = leverage
      )
      equity_curve <- g5_ema_cross_equity_curve(
        trades,
        bars,
        symbol = symbol,
        trading_start_date = trading_start_date,
        trading_end_date = trading_end_date,
        leverage = leverage
      )
      rows[[length(rows) + 1L]] <- g5_wfa_strategy_spec_metrics(trades, equity_curve, symbol, model, exit_stack, leverage)
    }
  }
  out <- do.call(rbind, rows)
  out <- out[order(
    ifelse(is.na(out$sharpe), -Inf, out$sharpe),
    ifelse(is.na(out$total_return), -Inf, out$total_return),
    decreasing = TRUE
  ), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_ema_cross_wfa_select_fold_models <- function(
  bars,
  symbol,
  folds,
  fast_periods,
  slow_periods,
  bb_lookback_periods = c(10L, 20L, 30L),
  bb_sd_multipliers = c(1.5, 2, 2.5),
  ema_trend_fast_periods = c(5L, 10L, 15L),
  ema_trend_slow_periods = c(25L, 50L, 75L),
  rsi_periods = c(7L, 14L),
  rsi_lower_thresholds = c(30, 35),
  rsi_upper_thresholds = c(60, 70),
  zret_windows = c(10L, 20L),
  zret_entry_z = c(2.0, 2.5),
  zret_exit_z = c(0.0, 0.5),
  breakout_lookbacks = c(20L, 30L),
  breakout_buffers = c(0),
  vol_expand_thresholds = c(0.0, 0.10, 0.20),
  pullback_fast_periods = c(5L, 10L),
  pullback_slow_periods = c(25L, 50L),
  pullback_rsi_lower_thresholds = c(35, 40),
  pullback_rsi_upper_thresholds = c(55, 60),
  candidate_families = c("ema_cross", "bollinger_touch"),
  exit_stacks = g5_wfa_exit_stack_grid()
) {
  candidate_families <- g5_wfa_candidate_families(candidate_families)
  exit_stacks <- g5_wfa_exit_stacks_for_candidates(exit_stacks, candidate_families)
  model_grid <- g5_wfa_candidate_model_grid(
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    ema_trend_fast_periods = ema_trend_fast_periods,
    ema_trend_slow_periods = ema_trend_slow_periods,
    rsi_periods = rsi_periods,
    rsi_lower_thresholds = rsi_lower_thresholds,
    rsi_upper_thresholds = rsi_upper_thresholds,
    zret_windows = zret_windows,
    zret_entry_z = zret_entry_z,
    zret_exit_z = zret_exit_z,
    breakout_lookbacks = breakout_lookbacks,
    breakout_buffers = breakout_buffers,
    vol_expand_thresholds = vol_expand_thresholds,
    pullback_fast_periods = pullback_fast_periods,
    pullback_slow_periods = pullback_slow_periods,
    pullback_rsi_lower_thresholds = pullback_rsi_lower_thresholds,
    pullback_rsi_upper_thresholds = pullback_rsi_upper_thresholds,
    candidate_families = candidate_families
  )
  rows <- list()
  grid_rows <- list()
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    grid <- g5_wfa_evaluate_strategy_spec_grid(
      bars,
      symbol = symbol,
      trading_start_date = fold$train_start_date[[1L]],
      trading_end_date = fold$train_end_date[[1L]],
      model_grid = model_grid,
      exit_stacks = exit_stacks,
      leverage = 1
    )
    selected <- grid[1L, , drop = FALSE]
    rows[[i]] <- data.frame(
      schema_version = g5_ema_cross_wfa_multi_schema_version(),
      fold_id = fold$fold_id[[1L]],
      fold_no = fold$fold_no[[1L]],
      symbol = fold$symbol[[1L]],
      strategy_family = selected$strategy_family[[1L]],
      model_instance_id = selected$model_instance_id[[1L]],
      exit_stack_id = selected$exit_stack_id[[1L]],
      strategy_spec_id = selected$strategy_spec_id[[1L]],
      include_native_exit = selected$include_native_exit[[1L]],
      max_hold_sessions = selected$max_hold_sessions[[1L]],
      stop_loss_pct = selected$stop_loss_pct[[1L]],
      take_profit_pct = selected$take_profit_pct[[1L]],
      fast_period = if ("fast_period" %in% names(selected)) selected$fast_period[[1L]] else NA_integer_,
      slow_period = if ("slow_period" %in% names(selected)) selected$slow_period[[1L]] else NA_integer_,
      lookback_period = if ("lookback_period" %in% names(selected)) selected$lookback_period[[1L]] else NA_integer_,
      sd_multiplier = if ("sd_multiplier" %in% names(selected)) selected$sd_multiplier[[1L]] else NA_real_,
      rsi_period = if ("rsi_period" %in% names(selected)) selected$rsi_period[[1L]] else NA_integer_,
      rsi_lower = if ("rsi_lower" %in% names(selected)) selected$rsi_lower[[1L]] else NA_real_,
      rsi_upper = if ("rsi_upper" %in% names(selected)) selected$rsi_upper[[1L]] else NA_real_,
      zret_window = if ("zret_window" %in% names(selected)) selected$zret_window[[1L]] else NA_integer_,
      zret_entry_z = if ("zret_entry_z" %in% names(selected)) selected$zret_entry_z[[1L]] else NA_real_,
      zret_exit_z = if ("zret_exit_z" %in% names(selected)) selected$zret_exit_z[[1L]] else NA_real_,
      breakout_lookback = if ("breakout_lookback" %in% names(selected)) selected$breakout_lookback[[1L]] else NA_integer_,
      breakout_buffer = if ("breakout_buffer" %in% names(selected)) selected$breakout_buffer[[1L]] else NA_real_,
      vol_expand_threshold = if ("vol_expand_threshold" %in% names(selected)) selected$vol_expand_threshold[[1L]] else NA_real_,
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
  exit_stack_for_model <- function(model) {
    data.frame(
      exit_stack_id = model$exit_stack_id[[1L]],
      include_native_exit = if ("include_native_exit" %in% names(model)) model$include_native_exit[[1L]] else TRUE,
      max_hold_sessions = if ("max_hold_sessions" %in% names(model)) model$max_hold_sessions[[1L]] else NA_integer_,
      stop_loss_pct = if ("stop_loss_pct" %in% names(model)) model$stop_loss_pct[[1L]] else NA_real_,
      take_profit_pct = if ("take_profit_pct" %in% names(model)) model$take_profit_pct[[1L]] else NA_real_,
      stringsAsFactors = FALSE
    )
  }
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
            entry_execution_model_instance_id = selected_models$model_instance_id[[execution_fold_no]],
            entry_execution_exit_stack_id = selected_models$exit_stack_id[[execution_fold_no]],
            entry_execution_strategy_spec_id = selected_models$strategy_spec_id[[execution_fold_no]]
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
          exit_stack_id = open_trade$entry_signal_exit_stack_id,
          strategy_spec_id = open_trade$entry_signal_strategy_spec_id,
          primary_exit_reason = pending_exit$primary_exit_reason,
          triggered_exit_rules = pending_exit$triggered_exit_rules,
          exit_attribution = pending_exit$exit_attribution,
          entry_signal_strategy_family = open_trade$entry_signal_strategy_family,
          entry_execution_strategy_family = open_trade$entry_execution_strategy_family,
          exit_signal_strategy_family = pending_exit$exit_signal_strategy_family,
          exit_execution_strategy_family = selected_models$strategy_family[[execution_fold_no]],
          entry_signal_model_instance_id = open_trade$entry_signal_model_instance_id,
          entry_execution_model_instance_id = open_trade$entry_execution_model_instance_id,
          exit_signal_model_instance_id = pending_exit$exit_signal_model_instance_id,
          exit_execution_model_instance_id = selected_models$model_instance_id[[execution_fold_no]],
          entry_signal_exit_stack_id = open_trade$entry_signal_exit_stack_id,
          entry_execution_exit_stack_id = open_trade$entry_execution_exit_stack_id,
          exit_signal_exit_stack_id = pending_exit$exit_signal_exit_stack_id,
          exit_execution_exit_stack_id = selected_models$exit_stack_id[[execution_fold_no]],
          entry_signal_strategy_spec_id = open_trade$entry_signal_strategy_spec_id,
          entry_execution_strategy_spec_id = open_trade$entry_execution_strategy_spec_id,
          exit_signal_strategy_spec_id = pending_exit$exit_signal_strategy_spec_id,
          exit_execution_strategy_spec_id = selected_models$strategy_spec_id[[execution_fold_no]],
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
        entry_signal_exit_stack_id = model$exit_stack_id[[1L]],
        entry_signal_strategy_spec_id = model$strategy_spec_id[[1L]],
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

    if (in_position && is.null(pending_exit)) {
      exit_stack <- exit_stack_for_model(model)
      exit_event <- g5_wfa_exit_event(ind, idx, open_trade, exit_stack)
      if (is.null(exit_event)) {
        next
      }
      pending_exit <- list(
        exit_signal_fold_id = model$fold_id[[1L]],
        exit_signal_strategy_family = model$strategy_family[[1L]],
        exit_signal_model_instance_id = model$model_instance_id[[1L]],
        exit_signal_exit_stack_id = model$exit_stack_id[[1L]],
        exit_signal_strategy_spec_id = model$strategy_spec_id[[1L]],
        primary_exit_reason = exit_event$primary_exit_reason,
        triggered_exit_rules = exit_event$triggered_exit_rules,
        exit_attribution = exit_event$exit_attribution,
        exit_signal_fast_period = model_value(model, "fast_period", NA_integer_),
        exit_signal_slow_period = model_value(model, "slow_period", NA_integer_),
        exit_signal_lookback_period = model_value(model, "lookback_period", NA_integer_),
        exit_signal_sd_multiplier = model_value(model, "sd_multiplier", NA_real_),
        exit_signal_rule = exit_event$exit_signal_rule,
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
      exit_stack_id = open_trade$entry_signal_exit_stack_id,
      strategy_spec_id = open_trade$entry_signal_strategy_spec_id,
      primary_exit_reason = NA_character_,
      triggered_exit_rules = NA_character_,
      exit_attribution = NA_character_,
      entry_signal_strategy_family = open_trade$entry_signal_strategy_family,
      entry_execution_strategy_family = open_trade$entry_execution_strategy_family,
      exit_signal_strategy_family = NA_character_,
      exit_execution_strategy_family = NA_character_,
      entry_signal_model_instance_id = open_trade$entry_signal_model_instance_id,
      entry_execution_model_instance_id = open_trade$entry_execution_model_instance_id,
      exit_signal_model_instance_id = NA_character_,
      exit_execution_model_instance_id = NA_character_,
      entry_signal_exit_stack_id = open_trade$entry_signal_exit_stack_id,
      entry_execution_exit_stack_id = open_trade$entry_execution_exit_stack_id,
      exit_signal_exit_stack_id = NA_character_,
      exit_execution_exit_stack_id = NA_character_,
      entry_signal_strategy_spec_id = open_trade$entry_signal_strategy_spec_id,
      entry_execution_strategy_spec_id = open_trade$entry_execution_strategy_spec_id,
      exit_signal_strategy_spec_id = NA_character_,
      exit_execution_strategy_spec_id = NA_character_,
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
    part$exit_stack_id <- model$exit_stack_id[[1L]]
    part$strategy_spec_id <- model$strategy_spec_id[[1L]]
    rows[[i]] <- part
  }
  out <- g5_wfa_bind_rows_fill(rows)
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
    native_exit_count = if (nrow(closed) > 0L && "exit_attribution" %in% names(closed)) sum(closed$exit_attribution == "native", na.rm = TRUE) else 0L,
    exit_stack_exit_count = if (nrow(closed) > 0L && "exit_attribution" %in% names(closed)) sum(closed$exit_attribution == "exit_stack", na.rm = TRUE) else 0L,
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
      exit_stack_id = model$exit_stack_id[[1L]],
      strategy_spec_id = model$strategy_spec_id[[1L]],
      model_parameters = g5_wfa_model_parameter_label(model),
      exit_stack = g5_wfa_exit_stack_label(model),
      fast_period = if ("fast_period" %in% names(model)) model$fast_period[[1L]] else NA_integer_,
      slow_period = if ("slow_period" %in% names(model)) model$slow_period[[1L]] else NA_integer_,
      lookback_period = if ("lookback_period" %in% names(model)) model$lookback_period[[1L]] else NA_integer_,
      sd_multiplier = if ("sd_multiplier" %in% names(model)) model$sd_multiplier[[1L]] else NA_real_,
      vol_expand_threshold = if ("vol_expand_threshold" %in% names(model)) model$vol_expand_threshold[[1L]] else NA_real_,
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
  key_col <- if ("strategy_spec_id" %in% names(selected_models)) "strategy_spec_id" else "model_instance_id"
  keys <- unique(selected_models[[key_col]])
  rows <- lapply(keys, function(key) {
    selected <- selected_models[selected_models[[key_col]] == key, , drop = FALSE]
    data.frame(
      schema_version = g5_ema_cross_wfa_multi_schema_version(),
      strategy_family = selected$strategy_family[[1L]],
      model_instance_id = selected$model_instance_id[[1L]],
      exit_stack_id = if ("exit_stack_id" %in% names(selected)) selected$exit_stack_id[[1L]] else NA_character_,
      strategy_spec_id = if ("strategy_spec_id" %in% names(selected)) selected$strategy_spec_id[[1L]] else key,
      model_parameters = g5_wfa_model_parameter_label(selected[1L, , drop = FALSE]),
      exit_stack = if ("exit_stack_id" %in% names(selected)) g5_wfa_exit_stack_label(selected[1L, , drop = FALSE]) else NA_character_,
      fast_period = if ("fast_period" %in% names(selected)) selected$fast_period[[1L]] else NA_integer_,
      slow_period = if ("slow_period" %in% names(selected)) selected$slow_period[[1L]] else NA_integer_,
      lookback_period = if ("lookback_period" %in% names(selected)) selected$lookback_period[[1L]] else NA_integer_,
      sd_multiplier = if ("sd_multiplier" %in% names(selected)) selected$sd_multiplier[[1L]] else NA_real_,
      vol_expand_threshold = if ("vol_expand_threshold" %in% names(selected)) selected$vol_expand_threshold[[1L]] else NA_real_,
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
  y_range <- range(c(indicators$low, indicators$high, indicators$fast_ema, indicators$slow_ema, indicators$bb_mid, indicators$bb_upper, indicators$bb_lower, indicators$breakout_high, indicators$breakout_mid), finite = TRUE)
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
    if (length(family) > 0L && family[[1L]] %in% c("ema_cross", "ema_trend", "pullback_in_uptrend")) {
      graphics::lines(part_x, part$fast_ema, col = aesthetic$native_entry_color, lwd = 1.4)
      graphics::lines(part_x, part$slow_ema, col = aesthetic$non_native_exit_color, lwd = 1.4)
    }
    if (length(family) > 0L && family[[1L]] %in% c("bollinger_touch", "bollinger_mid_reversion")) {
      band_col <- grDevices::adjustcolor(aesthetic$non_native_exit_color, alpha.f = 0.7)
      graphics::lines(part_x, part$bb_mid, col = aesthetic$native_entry_color, lwd = 1.1)
      graphics::lines(part_x, part$bb_upper, col = band_col, lwd = 1.1, lty = 2)
      graphics::lines(part_x, part$bb_lower, col = band_col, lwd = 1.1, lty = 2)
    }
    if (length(family) > 0L && family[[1L]] %in% c("breakout", "vol_expansion_breakout", "donchian_breakout_vol_expand")) {
      graphics::lines(part_x, part$breakout_high, col = grDevices::adjustcolor(aesthetic$non_native_exit_color, alpha.f = 0.7), lwd = 1.1, lty = 2)
      graphics::lines(part_x, part$breakout_mid, col = grDevices::adjustcolor(aesthetic$native_entry_color, alpha.f = 0.7), lwd = 1.0)
    }
  }
  if (is.data.frame(trades) && nrow(trades) > 0L) {
    line_cols <- ifelse(trades$trade_outcome == "win", aesthetic$trade_win_line, ifelse(trades$trade_outcome == "loss", aesthetic$trade_loss_line, aesthetic$flat_candle))
    graphics::segments(match(trades$entry_execution_date, session_dates), trades$entry_execution_price, match(trades$trace_end_date, session_dates), trades$trace_end_price, col = line_cols, lty = aesthetic$trade_line_lty, lwd = 1.2)
    graphics::points(match(trades$entry_signal_date, session_dates), trades$entry_signal_price, pch = aesthetic$entry_signal_pch, col = aesthetic$entry_signal_color, bg = aesthetic$panel_background, cex = 1.1, lwd = 1.4)
    graphics::points(match(trades$entry_execution_date, session_dates), trades$entry_execution_price, pch = aesthetic$native_entry_pch, col = aesthetic$native_entry_color, bg = aesthetic$native_entry_color, cex = 1.05)
    exit_signal_rows <- trades[!is.na(trades$exit_signal_date), , drop = FALSE]
    if (nrow(exit_signal_rows) > 0L) {
      if ("exit_attribution" %in% names(exit_signal_rows)) {
        native_exit_signals <- exit_signal_rows[exit_signal_rows$exit_attribution == "native" | is.na(exit_signal_rows$exit_attribution), , drop = FALSE]
        stack_exit_signals <- exit_signal_rows[exit_signal_rows$exit_attribution == "exit_stack", , drop = FALSE]
      } else {
        native_exit_signals <- exit_signal_rows
        stack_exit_signals <- exit_signal_rows[FALSE, , drop = FALSE]
      }
      if (nrow(native_exit_signals) > 0L) {
        graphics::points(match(native_exit_signals$exit_signal_date, session_dates), native_exit_signals$exit_signal_price, pch = aesthetic$exit_signal_pch, col = aesthetic$exit_signal_color, bg = aesthetic$panel_background, cex = 1.1, lwd = 1.4)
      }
      if (nrow(stack_exit_signals) > 0L) {
        graphics::points(match(stack_exit_signals$exit_signal_date, session_dates), stack_exit_signals$exit_signal_price, pch = aesthetic$non_native_exit_pch, col = aesthetic$non_native_exit_color, bg = aesthetic$panel_background, cex = 1.2, lwd = 1.6)
      }
    }
    closed_rows <- trades[!is.na(trades$exit_execution_date), , drop = FALSE]
    if (nrow(closed_rows) > 0L) {
      if ("exit_attribution" %in% names(closed_rows)) {
        native_closed <- closed_rows[closed_rows$exit_attribution == "native" | is.na(closed_rows$exit_attribution), , drop = FALSE]
        stack_closed <- closed_rows[closed_rows$exit_attribution == "exit_stack", , drop = FALSE]
      } else {
        native_closed <- closed_rows
        stack_closed <- closed_rows[FALSE, , drop = FALSE]
      }
      if (nrow(native_closed) > 0L) {
        graphics::points(match(native_closed$exit_execution_date, session_dates), native_closed$exit_execution_price, pch = aesthetic$native_exit_pch, col = aesthetic$native_exit_color, bg = aesthetic$native_exit_color, cex = 1.05)
      }
      if (nrow(stack_closed) > 0L) {
        graphics::points(match(stack_closed$exit_execution_date, session_dates), stack_closed$exit_execution_price, pch = aesthetic$non_native_exit_pch, col = aesthetic$non_native_exit_color, bg = aesthetic$panel_background, cex = 1.2, lwd = 1.6)
      }
    }
  }
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(8L, length(x)))))
  g5_axis_date_labels_45(tick_positions, as.character(session_dates[tick_positions]), color = aesthetic$axis)
  has_ema <- any(indicators$strategy_family %in% c("ema_cross", "ema_trend", "pullback_in_uptrend"), na.rm = TRUE)
  has_bb <- any(indicators$strategy_family %in% c("bollinger_touch", "bollinger_mid_reversion"), na.rm = TRUE)
  has_breakout <- any(indicators$strategy_family %in% c("breakout", "vol_expansion_breakout", "donchian_breakout_vol_expand"), na.rm = TRUE)
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
  if (has_breakout) {
    legend_text <- c(legend_text, "breakout level", "breakout mid")
    legend_lty <- c(legend_lty, 2, 1)
    legend_pch <- c(legend_pch, NA, NA)
    legend_col <- c(legend_col, grDevices::adjustcolor(aesthetic$non_native_exit_color, alpha.f = 0.7), grDevices::adjustcolor(aesthetic$native_entry_color, alpha.f = 0.7))
    legend_bg <- c(legend_bg, NA, NA)
  }
  has_stack_exit <- is.data.frame(trades) && nrow(trades) > 0L && "exit_attribution" %in% names(trades) && any(trades$exit_attribution == "exit_stack", na.rm = TRUE)
  legend_text <- c(legend_text, "entry signal", "entry execution", "native exit signal", "native exit execution")
  legend_lty <- c(legend_lty, 0, 0, 0, 0)
  legend_pch <- c(legend_pch, aesthetic$entry_signal_pch, aesthetic$native_entry_pch, aesthetic$exit_signal_pch, aesthetic$native_exit_pch)
  legend_col <- c(legend_col, aesthetic$entry_signal_color, aesthetic$native_entry_color, aesthetic$exit_signal_color, aesthetic$native_exit_color)
  legend_bg <- c(legend_bg, aesthetic$panel_background, aesthetic$native_entry_color, aesthetic$panel_background, aesthetic$native_exit_color)
  if (has_stack_exit) {
    legend_text <- c(legend_text, "exit stack signal/execution")
    legend_lty <- c(legend_lty, 0)
    legend_pch <- c(legend_pch, aesthetic$non_native_exit_pch)
    legend_col <- c(legend_col, aesthetic$non_native_exit_color)
    legend_bg <- c(legend_bg, aesthetic$panel_background)
  }
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
      " | ", row[["exit_stack_id"]],
      " | ", g5_wfa_exit_stack_label(model),
      " | ", row[["strategy_spec_id"]],
      " | ", num(row[["train_sharpe"]]),
      " | ", pct(row[["train_total_return"]]),
      " |"
    )
  }
  candidate_models <- unique(train_parameter_performance[, c("strategy_family", "model_instance_id"), drop = FALSE])
  candidate_models <- candidate_models[order(candidate_models$strategy_family, candidate_models$model_instance_id), , drop = FALSE]
  candidate_exit_stacks <- unique(train_parameter_performance[, c("exit_stack_id", "include_native_exit", "max_hold_sessions", "stop_loss_pct", "take_profit_pct"), drop = FALSE])
  candidate_exit_stacks$exit_stack <- apply(candidate_exit_stacks, 1, function(row) g5_wfa_exit_stack_label(as.data.frame(as.list(row), stringsAsFactors = FALSE)))
  candidate_exit_stacks <- candidate_exit_stacks[order(candidate_exit_stacks$exit_stack_id), , drop = FALSE]
  candidate_specs <- unique(train_parameter_performance[, c("strategy_family", "model_instance_id", "exit_stack_id", "strategy_spec_id"), drop = FALSE])
  candidate_specs <- candidate_specs[order(candidate_specs$strategy_family, candidate_specs$model_instance_id, candidate_specs$exit_stack_id), , drop = FALSE]
  family_counts <- do.call(rbind, lapply(split(candidate_models, candidate_models$strategy_family), function(df) {
    data.frame(
      strategy_family = df$strategy_family[[1L]],
      tested_model_instances_per_fold = nrow(unique(df[, c("strategy_family", "model_instance_id"), drop = FALSE])),
      stringsAsFactors = FALSE
    )
  }))
  names(family_counts) <- c("strategy_family", "tested_model_instances_per_fold")
  active_families <- unique(candidate_models$strategy_family)
  candidate_grid_lines <- character()
  if ("ema_cross" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, paste0("- EMA cross grid: fast periods `", paste(settings$fast_periods, collapse = ", "), "`, slow periods `", paste(settings$slow_periods, collapse = ", "), "`"))
  }
  if ("ema_trend" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, paste0("- EMA trend grid: fast periods `", paste(settings$ema_trend_fast_periods, collapse = ", "), "`, slow periods `", paste(settings$ema_trend_slow_periods, collapse = ", "), "`"))
  }
  if ("bollinger_touch" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, paste0("- Bollinger touch grid: lookback periods `", paste(settings$bb_lookback_periods, collapse = ", "), "`, SD multipliers `", paste(settings$bb_sd_multipliers, collapse = ", "), "`"))
  }
  if ("bollinger_mid_reversion" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, "- Bollinger mid-reversion uses the Bollinger lookback and SD grid, but exits on recovery to the mid-band instead of the upper band.")
  }
  if ("rsi_mr" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, paste0("- RSI mean-reversion grid: periods `", paste(settings$rsi_periods, collapse = ", "), "`, lower thresholds `", paste(settings$rsi_lower_thresholds, collapse = ", "), "`, upper thresholds `", paste(settings$rsi_upper_thresholds, collapse = ", "), "`"))
  }
  if ("zret_mr" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, paste0("- Return-z mean-reversion grid: windows `", paste(settings$zret_windows, collapse = ", "), "`, entry z `", paste(settings$zret_entry_z, collapse = ", "), "`, exit z `", paste(settings$zret_exit_z, collapse = ", "), "`"))
  }
  if (any(active_families %in% c("breakout", "vol_expansion_breakout", "donchian_breakout_vol_expand"))) {
    candidate_grid_lines <- c(candidate_grid_lines, paste0("- Breakout grid: lookbacks `", paste(settings$breakout_lookbacks, collapse = ", "), "`, buffers `", paste(settings$breakout_buffers, collapse = ", "), "`"))
  }
  if (any(active_families %in% c("vol_expansion_breakout", "donchian_breakout_vol_expand"))) {
    candidate_grid_lines <- c(candidate_grid_lines, paste0("- Volatility-expansion breakout threshold grid: `", paste(settings$vol_expand_thresholds, collapse = ", "), "`"))
  }
  if ("donchian_breakout_vol_expand" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, "- Donchian volatility-expansion breakout uses the breakout grid plus prior Bollinger-width compression before the expansion filter.")
  }
  if ("pullback_in_uptrend" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, paste0("- Pullback-in-uptrend grid: fast periods `", paste(settings$pullback_fast_periods, collapse = ", "), "`, slow periods `", paste(settings$pullback_slow_periods, collapse = ", "), "`, RSI lower `", paste(settings$pullback_rsi_lower_thresholds, collapse = ", "), "`, RSI upper `", paste(settings$pullback_rsi_upper_thresholds, collapse = ", "), "`"))
  }
  if ("no_trade" %in% active_families) {
    candidate_grid_lines <- c(candidate_grid_lines, "- No-trade grid: one inert cash/no-position candidate with zero exposure and no exits.")
  }
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
    "Each TRAIN fold evaluates the same candidate entry/native model grid. A model instance means a strategy family plus a concrete parameter set.",
    "",
    table_lines(family_counts, names(family_counts)),
    "",
    candidate_grid_lines,
    paste0("- Exit stack max-hold sessions: `", paste(settings$max_hold_sessions, collapse = ", "), "`"),
    paste0("- Exit stack stop-loss percentages: `", paste(sprintf("%.1f%%", 100 * as.numeric(settings$stop_loss_pcts)), collapse = ", "), "`"),
    paste0("- Exit stack take-profit percentages: `", paste(sprintf("%.1f%%", 100 * as.numeric(settings$take_profit_pcts)), collapse = ", "), "`"),
    "",
    "<details>",
    "<summary>Tested model instances</summary>",
    "",
    table_lines(candidate_models, names(candidate_models)),
    "",
    "</details>",
    "",
    "## Candidate Exit Stacks",
    "",
    "An exit stack is a bundle of close-based exit rules that are all active while long. The first valid exit signal wins; same-bar attribution uses risk-first priority.",
    "",
    table_lines(candidate_exit_stacks[, c("exit_stack_id", "exit_stack"), drop = FALSE], c("exit_stack_id", "exit_stack")),
    "",
    "<details>",
    "<summary>Tested strategy specs</summary>",
    "",
    table_lines(candidate_specs, names(candidate_specs)),
    "",
    "</details>",
    "",
    "## Fold-Selected Strategy Specs",
    "",
    "| fold_id | strategy_family | model_instance_id | parameters | exit_stack_id | exit_stack | strategy_spec_id | train_sharpe | train_return |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    apply(selected_models, 1, fmt_model_row),
    "",
    "## Fold OOS Summary",
    "",
    table_lines(oos_table[, c("fold_id", "strategy_family", "model_instance_id", "exit_stack_id", "strategy_spec_id", "model_parameters", "exit_stack", "train_sharpe", "train_total_return", "oos_return", "oos_max_drawdown", "oos_trade_touch_count"), drop = FALSE], c("fold_id", "strategy_family", "model_instance_id", "exit_stack_id", "strategy_spec_id", "model_parameters", "exit_stack", "train_sharpe", "train_total_return", "oos_return", "oos_max_drawdown", "oos_trade_touch_count")),
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
    paste0("- Native exits: `", stitched_metrics$native_exit_count[[1L]], "`"),
    paste0("- Exit-stack exits: `", stitched_metrics$exit_stack_exit_count[[1L]], "`"),
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
    table_lines(stability[, c("strategy_family", "model_instance_id", "exit_stack_id", "strategy_spec_id", "model_parameters", "exit_stack", "selected_fold_count", "selected_fold_fraction", "selected_folds"), drop = FALSE], c("strategy_family", "model_instance_id", "exit_stack_id", "strategy_spec_id", "model_parameters", "exit_stack", "selected_fold_count", "selected_fold_fraction", "selected_folds")),
    "",
    "## Audit Notes",
    "",
    "- Selection metric for this POC is highest TRAIN Sharpe over complete strategy specs, with TRAIN total return as the existing secondary sort.",
    "- Exit stacks are close-based only in this POC and execute at the next session open.",
    "- OOS rows are stitched in chronological order to mimic updating the selected model instance at each fold boundary.",
    "- Open positions are carried across fold boundaries and then managed by the current fold-selected strategy spec."
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
  ema_trend_fast_periods = c(5L, 10L, 15L),
  ema_trend_slow_periods = c(25L, 50L, 75L),
  rsi_periods = c(7L, 14L),
  rsi_lower_thresholds = c(30, 35),
  rsi_upper_thresholds = c(60, 70),
  zret_windows = c(10L, 20L),
  zret_entry_z = c(2.0, 2.5),
  zret_exit_z = c(0.0, 0.5),
  breakout_lookbacks = c(20L, 30L),
  breakout_buffers = c(0),
  vol_expand_thresholds = c(0.0, 0.10, 0.20),
  pullback_fast_periods = c(5L, 10L),
  pullback_slow_periods = c(25L, 50L),
  pullback_rsi_lower_thresholds = c(35, 40),
  pullback_rsi_upper_thresholds = c(55, 60),
  candidate_families = c("ema_cross", "bollinger_touch"),
  max_hold_sessions = c(10L, 20L, 40L),
  stop_loss_pcts = 0.10,
  take_profit_pcts = 0.25,
  train_quarters = 8,
  oos_quarters = 1,
  fold_count = 3L
) {
  candidate_families <- g5_wfa_candidate_families(candidate_families)
  folds <- g5_ema_cross_wfa_resolve_folds(bars, symbol, wfa_start_date, wfa_end_date, train_quarters, oos_quarters, fold_count)
  exit_stacks <- g5_wfa_exit_stacks_for_candidates(
    g5_wfa_exit_stack_grid(max_hold_sessions, stop_loss_pcts, take_profit_pcts),
    candidate_families
  )
  selected <- g5_ema_cross_wfa_select_fold_models(
    bars = bars,
    symbol = symbol,
    folds = folds,
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    ema_trend_fast_periods = ema_trend_fast_periods,
    ema_trend_slow_periods = ema_trend_slow_periods,
    rsi_periods = rsi_periods,
    rsi_lower_thresholds = rsi_lower_thresholds,
    rsi_upper_thresholds = rsi_upper_thresholds,
    zret_windows = zret_windows,
    zret_entry_z = zret_entry_z,
    zret_exit_z = zret_exit_z,
    breakout_lookbacks = breakout_lookbacks,
    breakout_buffers = breakout_buffers,
    vol_expand_thresholds = vol_expand_thresholds,
    pullback_fast_periods = pullback_fast_periods,
    pullback_slow_periods = pullback_slow_periods,
    pullback_rsi_lower_thresholds = pullback_rsi_lower_thresholds,
    pullback_rsi_upper_thresholds = pullback_rsi_upper_thresholds,
    candidate_families = candidate_families,
    exit_stacks = exit_stacks
  )
  stitched <- g5_ema_cross_wfa_simulate_stitched_oos(bars, symbol, folds, selected$selected_models)
  indicators <- g5_ema_cross_wfa_stitched_indicators(bars, symbol, folds, selected$selected_models)
  stitched_metrics <- g5_ema_cross_wfa_stitched_metrics(stitched$trades, stitched$equity_curve, symbol, nrow(folds))
  fold_oos_summary <- g5_ema_cross_wfa_fold_oos_summary(folds, selected$selected_models, stitched$equity_curve, stitched$trades)
  stability <- g5_ema_cross_wfa_model_stability(selected$selected_models)
  list(
    folds = folds,
    exit_stacks = exit_stacks,
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
  ema_trend_fast_periods = c(5L, 10L, 15L),
  ema_trend_slow_periods = c(25L, 50L, 75L),
  rsi_periods = c(7L, 14L),
  rsi_lower_thresholds = c(30, 35),
  rsi_upper_thresholds = c(60, 70),
  zret_windows = c(10L, 20L),
  zret_entry_z = c(2.0, 2.5),
  zret_exit_z = c(0.0, 0.5),
  breakout_lookbacks = c(20L, 30L),
  breakout_buffers = c(0),
  vol_expand_thresholds = c(0.0, 0.10, 0.20),
  pullback_fast_periods = c(5L, 10L),
  pullback_slow_periods = c(25L, 50L),
  pullback_rsi_lower_thresholds = c(35, 40),
  pullback_rsi_upper_thresholds = c(55, 60),
  candidate_families = c("ema_cross", "bollinger_touch"),
  max_hold_sessions = c(10L, 20L, 40L),
  stop_loss_pcts = 0.10,
  take_profit_pcts = 0.25,
  train_quarters = 8,
  oos_quarters = 1,
  fold_count = 3L
) {
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("Multi-signal WFA output writing requires exactly one symbol.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  candidate_families <- g5_wfa_candidate_families(candidate_families)
  prefix <- g5_ema_cross_wfa_multi_artifact_prefix(result$resolved_session$as_of_timestamp, symbol, wfa_start_date, wfa_end_date, fold_count, candidate_families)
  written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
  wfa <- g5_ema_cross_wfa_run_multi(
    bars = result$bars,
    symbol = symbol,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    ema_trend_fast_periods = ema_trend_fast_periods,
    ema_trend_slow_periods = ema_trend_slow_periods,
    rsi_periods = rsi_periods,
    rsi_lower_thresholds = rsi_lower_thresholds,
    rsi_upper_thresholds = rsi_upper_thresholds,
    zret_windows = zret_windows,
    zret_entry_z = zret_entry_z,
    zret_exit_z = zret_exit_z,
    breakout_lookbacks = breakout_lookbacks,
    breakout_buffers = breakout_buffers,
    vol_expand_thresholds = vol_expand_thresholds,
    pullback_fast_periods = pullback_fast_periods,
    pullback_slow_periods = pullback_slow_periods,
    pullback_rsi_lower_thresholds = pullback_rsi_lower_thresholds,
    pullback_rsi_upper_thresholds = pullback_rsi_upper_thresholds,
    candidate_families = candidate_families,
    max_hold_sessions = max_hold_sessions,
    stop_loss_pcts = stop_loss_pcts,
    take_profit_pcts = take_profit_pcts,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    fold_count = fold_count
  )
  paths <- c(
    written$paths,
    list(
      fold_spec_csv = file.path(output_dir, paste0(prefix, "_folds.csv")),
      selected_models_csv = file.path(output_dir, paste0(prefix, "_selected.csv")),
      exit_stacks_csv = file.path(output_dir, paste0(prefix, "_exits.csv")),
      train_parameter_performance_csv = file.path(output_dir, paste0(prefix, "_train_perf.csv")),
      model_stability_csv = file.path(output_dir, paste0(prefix, "_stability.csv")),
      fold_oos_summary_csv = file.path(output_dir, paste0(prefix, "_fold_oos.csv")),
      stitched_indicators_csv = file.path(output_dir, paste0(prefix, "_indicators.csv")),
      stitched_trades_csv = file.path(output_dir, paste0(prefix, "_trades.csv")),
      stitched_equity_curve_csv = file.path(output_dir, paste0(prefix, "_equity.csv")),
      stitched_metrics_csv = file.path(output_dir, paste0(prefix, "_metrics.csv")),
      stitched_metrics_md = file.path(output_dir, paste0(prefix, "_metrics.md")),
      stitched_strategy_chart_png = file.path(output_dir, paste0(prefix, "_strategy.png")),
      stitched_equity_curve_png = file.path(output_dir, paste0(prefix, "_equity.png"))
    )
  )
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(output_dir)) {
    g5_stop(paste0("Could not create multi-signal WFA output directory: ", output_dir))
  }
  g5_wfa_write_csv(wfa$folds, paths$fold_spec_csv)
  g5_wfa_write_csv(wfa$selected_models, paths$selected_models_csv)
  g5_wfa_write_csv(wfa$exit_stacks, paths$exit_stacks_csv)
  g5_wfa_write_csv(wfa$train_parameter_performance, paths$train_parameter_performance_csv)
  g5_wfa_write_csv(wfa$model_stability, paths$model_stability_csv)
  g5_wfa_write_csv(wfa$fold_oos_summary, paths$fold_oos_summary_csv)
  g5_wfa_write_csv(wfa$stitched_indicators, paths$stitched_indicators_csv)
  g5_wfa_write_csv(wfa$stitched_trades, paths$stitched_trades_csv)
  g5_wfa_write_csv(wfa$stitched_equity_curve, paths$stitched_equity_curve_csv)
  g5_wfa_write_csv(wfa$stitched_metrics, paths$stitched_metrics_csv)
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
    ema_trend_fast_periods = ema_trend_fast_periods,
    ema_trend_slow_periods = ema_trend_slow_periods,
    rsi_periods = rsi_periods,
    rsi_lower_thresholds = rsi_lower_thresholds,
    rsi_upper_thresholds = rsi_upper_thresholds,
    zret_windows = zret_windows,
    zret_entry_z = zret_entry_z,
    zret_exit_z = zret_exit_z,
    breakout_lookbacks = breakout_lookbacks,
    breakout_buffers = breakout_buffers,
    vol_expand_thresholds = vol_expand_thresholds,
    pullback_fast_periods = pullback_fast_periods,
    pullback_slow_periods = pullback_slow_periods,
    pullback_rsi_lower_thresholds = pullback_rsi_lower_thresholds,
    pullback_rsi_upper_thresholds = pullback_rsi_upper_thresholds,
    candidate_families = candidate_families,
    max_hold_sessions = max_hold_sessions,
    stop_loss_pcts = stop_loss_pcts,
    take_profit_pcts = take_profit_pcts
  )
  g5_ema_cross_wfa_multi_metrics_markdown(wfa$folds, wfa$selected_models, wfa$train_parameter_performance, wfa$stitched_metrics, wfa$fold_oos_summary, wfa$model_stability, report_settings, paths$stitched_metrics_md)
  g5_write_ema_cross_wfa_stitched_strategy_chart_png(wfa$stitched_indicators, wfa$stitched_trades, wfa$folds, symbol, paths$stitched_strategy_chart_png)
  g5_write_ema_cross_wfa_stitched_equity_curve_png(wfa$stitched_equity_curve, wfa$folds, symbol, paths$stitched_equity_curve_png)
  paths <- lapply(paths, normalizePath, winslash = "/", mustWork = FALSE)
  c(wfa, list(paths = paths, manifest = written$manifest))
}
