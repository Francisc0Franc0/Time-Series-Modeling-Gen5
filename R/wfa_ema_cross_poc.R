# Gen5.1 one-fold EMA cross WFA proof of concept.

g5_ema_cross_wfa_schema_version <- function() {
  "gen5_ema_cross_wfa_poc_v0.1"
}

g5_ema_cross_wfa_validate_quarters <- function(value, label) {
  value <- as.numeric(value)
  if (length(value) != 1L || is.na(value) || !is.finite(value) || value <= 0) {
    g5_stop(paste0(label, " must be a positive finite number of quarters."))
  }
  value
}

g5_ema_cross_wfa_quarters_to_days <- function(quarters) {
  as.integer(round(g5_ema_cross_wfa_validate_quarters(quarters, "quarters") * 365.25 / 4))
}

g5_ema_cross_wfa_artifact_prefix <- function(as_of_timestamp, symbol, wfa_start_date = NULL, wfa_end_date = NULL) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  window_label <- if (!is.null(wfa_start_date) && !is.null(wfa_end_date)) {
    paste0(
      "w",
      gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_start_date))),
      "_to_",
      gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date)))
    )
  } else {
    NULL
  }
  paste(c("ema_wfa", symbol, window_label, stamp), collapse = "_")
}

g5_ema_cross_wfa_output_dir <- function(repo_root, as_of_timestamp, symbol, wfa_start_date = NULL, wfa_end_date = NULL) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "wfa_pocs",
    g5_ema_cross_wfa_artifact_prefix(as_of_timestamp, symbol, wfa_start_date = wfa_start_date, wfa_end_date = wfa_end_date)
  )
}

g5_ema_cross_wfa_resolve_one_fold <- function(
  bars,
  symbol,
  wfa_start_date,
  wfa_end_date,
  train_quarters = 8,
  oos_quarters = 1
) {
  train_days <- g5_ema_cross_wfa_quarters_to_days(train_quarters)
  oos_days <- g5_ema_cross_wfa_quarters_to_days(oos_quarters)
  window_bars <- g5_ema_cross_prepare_bars(
    bars,
    symbol = symbol,
    start_date = wfa_start_date,
    end_date = wfa_end_date
  )
  dates <- as.Date(window_bars$session_date)
  train_start_date <- min(dates)
  latest_window_date <- max(dates)
  train_end_target <- train_start_date + train_days
  if (latest_window_date < train_end_target) {
    g5_stop(paste0(
      "Insufficient data for one EMA WFA fold: latest available session ",
      latest_window_date,
      " is before required train end target ",
      train_end_target,
      "."
    ))
  }
  train_end_candidates <- dates[dates <= train_end_target]
  train_end_date <- max(train_end_candidates)
  oos_start_candidates <- dates[dates > train_end_date]
  if (length(oos_start_candidates) == 0L) {
    g5_stop("Insufficient data for one EMA WFA fold: no OOS session exists after the train window.")
  }
  oos_start_date <- min(oos_start_candidates)
  oos_end_target <- oos_start_date + oos_days
  if (latest_window_date < oos_end_target) {
    g5_stop(paste0(
      "Insufficient data for one EMA WFA fold: latest available session ",
      latest_window_date,
      " is before required OOS end target ",
      oos_end_target,
      "."
    ))
  }
  oos_end_candidates <- dates[dates >= oos_start_date & dates <= oos_end_target]
  if (length(oos_end_candidates) == 0L) {
    g5_stop("Insufficient data for one EMA WFA fold: no OOS sessions resolved.")
  }
  oos_end_date <- max(oos_end_candidates)

  data.frame(
    schema_version = g5_ema_cross_wfa_schema_version(),
    fold_id = "fold_001",
    symbol = g5_standardize_symbol(symbol)[[1L]],
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
    fold_policy = "earliest_possible_single_fold",
    final_train_signal_policy = "allowed_to_execute_at_first_oos_open",
    stringsAsFactors = FALSE
  )
}

g5_ema_cross_wfa_metrics_markdown <- function(fold, train_selected, oos_metrics, path) {
  if (!is.data.frame(fold) || nrow(fold) != 1L) {
    g5_stop("fold must be a one-row data.frame.")
  }
  if (!is.data.frame(train_selected) || nrow(train_selected) != 1L) {
    g5_stop("train_selected must be a one-row data.frame.")
  }
  if (!is.data.frame(oos_metrics) || nrow(oos_metrics) != 1L) {
    g5_stop("oos_metrics must be a one-row data.frame.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  pct <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
  num <- function(x) ifelse(is.na(x), "NA", ifelse(is.infinite(x), "Inf", sprintf("%.3f", as.numeric(x))))
  lines <- c(
    paste0("# EMA Cross One-Fold WFA POC: ", fold$symbol[[1L]]),
    "",
    paste0("- Fold: `", fold$fold_id[[1L]], "`"),
    paste0("- Train: `", fold$train_start_date[[1L]], " to ", fold$train_end_date[[1L]], "`"),
    paste0("- OOS: `", fold$oos_start_date[[1L]], " to ", fold$oos_end_date[[1L]], "`"),
    paste0("- Selected on train: `fast=", train_selected$fast_period[[1L]], ", slow=", train_selected$slow_period[[1L]], "`"),
    paste0("- Train Sharpe: `", num(train_selected$sharpe[[1L]]), "`"),
    paste0("- Train total return: `", pct(train_selected$total_return[[1L]]), "`"),
    paste0("- OOS Sharpe: `", num(oos_metrics$sharpe[[1L]]), "`"),
    paste0("- OOS total return: `", pct(oos_metrics$total_return[[1L]]), "`"),
    paste0("- OOS CAGR: `", pct(oos_metrics$cagr[[1L]]), "`"),
    paste0("- OOS max drawdown: `", pct(oos_metrics$max_drawdown[[1L]]), "`"),
    paste0("- OOS time underwater: `", oos_metrics$underwater_session_count[[1L]], " sessions / ", pct(oos_metrics$underwater_fraction[[1L]]), "`"),
    paste0("- OOS trades: `", oos_metrics$trade_count[[1L]], "`"),
    paste0("- OOS buy-and-hold return: `", pct(oos_metrics$buy_hold_total_return[[1L]]), "`"),
    "",
    "One-fold WFA proof only: this is not multi-fold evidence, live advice, allocation logic, or a deployable strategy."
  )
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_ema_cross_wfa_run_one_fold <- function(
  bars,
  symbol,
  wfa_start_date,
  wfa_end_date,
  fast_periods = c(8L, 12L, 20L),
  slow_periods = c(30L, 50L, 80L, 120L),
  train_quarters = 8,
  oos_quarters = 1
) {
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("EMA WFA POC requires exactly one symbol.")
  }
  fold <- g5_ema_cross_wfa_resolve_one_fold(
    bars = bars,
    symbol = symbol,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters
  )
  train_evaluation <- g5_ema_cross_evaluate_grid(
    bars = bars,
    symbol = symbol,
    trading_start_date = fold$train_start_date[[1L]],
    trading_end_date = fold$train_end_date[[1L]],
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    leverage = 1
  )
  selected <- train_evaluation$selected
  oos_trades <- g5_ema_cross_trades(
    bars = bars,
    symbol = symbol,
    fast_period = selected$fast_period[[1L]],
    slow_period = selected$slow_period[[1L]],
    trading_start_date = fold$train_end_date[[1L]],
    trading_end_date = fold$oos_end_date[[1L]],
    leverage = 1
  )
  oos_events <- g5_ema_cross_chart_events(oos_trades)
  oos_equity <- g5_ema_cross_equity_curve(
    oos_trades,
    bars,
    symbol = symbol,
    trading_start_date = fold$oos_start_date[[1L]],
    trading_end_date = fold$oos_end_date[[1L]],
    leverage = 1
  )
  oos_metrics <- g5_ema_cross_metrics(
    oos_trades,
    oos_equity,
    symbol = symbol,
    fast_period = selected$fast_period[[1L]],
    slow_period = selected$slow_period[[1L]],
    leverage = 1
  )
  context_indicators <- g5_ema_cross_indicators(
    bars,
    symbol = symbol,
    fast_period = selected$fast_period[[1L]],
    slow_period = selected$slow_period[[1L]],
    start_date = fold$train_end_date[[1L]],
    end_date = fold$oos_end_date[[1L]]
  )
  list(
    fold = fold,
    train_parameter_performance = train_evaluation$parameter_performance,
    train_selected = selected,
    train_selected_detail = train_evaluation$selected_detail,
    oos_trades = oos_trades,
    oos_events = oos_events,
    oos_equity_curve = oos_equity,
    oos_metrics = oos_metrics,
    oos_context_indicators = context_indicators
  )
}

g5_write_ema_cross_wfa_outputs <- function(
  result,
  symbol,
  output_dir,
  wfa_start_date,
  wfa_end_date,
  fast_periods,
  slow_periods,
  train_quarters = 8,
  oos_quarters = 1
) {
  if (!is.list(result)) {
    g5_stop("result must be a workbench query result list.")
  }
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("EMA WFA output writing requires exactly one symbol.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  prefix <- g5_ema_cross_wfa_artifact_prefix(
    result$resolved_session$as_of_timestamp,
    symbol,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date
  )
  written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
  wfa <- g5_ema_cross_wfa_run_one_fold(
    bars = result$bars,
    symbol = symbol,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters
  )

  paths <- c(
    written$paths,
    list(
      fold_spec_csv = file.path(output_dir, paste0(prefix, "_fold_spec.csv")),
      train_parameter_performance_csv = file.path(output_dir, paste0(prefix, "_train_parameter_performance.csv")),
      train_selected_metrics_csv = file.path(output_dir, paste0(prefix, "_train_selected_metrics.csv")),
      oos_context_indicators_csv = file.path(output_dir, paste0(prefix, "_oos_context_indicators.csv")),
      oos_trades_csv = file.path(output_dir, paste0(prefix, "_oos_trades.csv")),
      oos_chart_events_csv = file.path(output_dir, paste0(prefix, "_oos_chart_events.csv")),
      oos_equity_curve_csv = file.path(output_dir, paste0(prefix, "_oos_equity_curve.csv")),
      oos_metrics_csv = file.path(output_dir, paste0(prefix, "_oos_metrics.csv")),
      oos_metrics_md = file.path(output_dir, paste0(prefix, "_oos_metrics.md")),
      oos_strategy_chart_png = file.path(output_dir, paste0(prefix, "_oos_strategy_chart.png")),
      oos_equity_curve_png = file.path(output_dir, paste0(prefix, "_oos_equity_curve.png"))
    )
  )

  utils::write.csv(wfa$fold, paths$fold_spec_csv, row.names = FALSE)
  utils::write.csv(wfa$train_parameter_performance, paths$train_parameter_performance_csv, row.names = FALSE)
  utils::write.csv(wfa$train_selected, paths$train_selected_metrics_csv, row.names = FALSE)
  utils::write.csv(wfa$oos_context_indicators, paths$oos_context_indicators_csv, row.names = FALSE)
  utils::write.csv(wfa$oos_trades, paths$oos_trades_csv, row.names = FALSE)
  utils::write.csv(wfa$oos_events, paths$oos_chart_events_csv, row.names = FALSE)
  utils::write.csv(wfa$oos_equity_curve, paths$oos_equity_curve_csv, row.names = FALSE)
  utils::write.csv(wfa$oos_metrics, paths$oos_metrics_csv, row.names = FALSE)
  g5_ema_cross_wfa_metrics_markdown(wfa$fold, wfa$train_selected, wfa$oos_metrics, paths$oos_metrics_md)
  g5_write_ema_cross_chart_png(
    result$bars,
    symbol = symbol,
    trades = wfa$oos_trades,
    fast_period = wfa$train_selected$fast_period[[1L]],
    slow_period = wfa$train_selected$slow_period[[1L]],
    trading_start_date = wfa$fold$train_end_date[[1L]],
    trading_end_date = wfa$fold$oos_end_date[[1L]],
    path = paths$oos_strategy_chart_png,
    title = paste(symbol, "EMA Cross One-Fold WFA OOS")
  )
  g5_write_ema_cross_equity_curve_png(
    wfa$oos_equity_curve,
    symbol = symbol,
    path = paths$oos_equity_curve_png,
    title = paste(symbol, "EMA Cross One-Fold WFA OOS Equity")
  )

  paths <- lapply(paths, normalizePath, winslash = "/", mustWork = FALSE)
  c(
    wfa,
    list(paths = paths, manifest = written$manifest)
  )
}
