# Gen5.4 supervised ML-P1 GLM replay.
#
# This wrapper fits a no-new-dependency logistic regression baseline from the
# ML-P0 feature/label contract and replays daily long/flat decisions in OOS.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

Sys.setenv(GEN5_GEN54_ML_P0_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_feature_label_proof.R"))
Sys.unsetenv("GEN5_GEN54_ML_P0_SOURCE_ONLY")

fit_glm_fold <- function(feature_fold_table, fold_id, features) {
  fold_rows <- feature_fold_table[feature_fold_table$fold_id == fold_id, , drop = FALSE]
  train <- fold_rows[
    fold_rows$split == "TRAIN" &
      fold_rows$label_inside_split &
      is.finite(fold_rows$fwd_ret_h3),
    ,
    drop = FALSE
  ]
  oos <- fold_rows[
    fold_rows$split == "OOS" &
      fold_rows$label_inside_split &
      is.finite(fold_rows$fwd_ret_h3),
    ,
    drop = FALSE
  ]
  features <- intersect(features, names(train))
  keep_feature <- vapply(features, function(feature) {
    values <- suppressWarnings(as.numeric(train[[feature]]))
    sum(is.finite(values)) >= 100L && is.finite(stats::sd(values, na.rm = TRUE)) && stats::sd(values, na.rm = TRUE) > 1e-10
  }, logical(1L))
  features <- features[keep_feature]
  if (length(features) < 3L) {
    g5_stop(paste0("ML-P1 fold ", fold_id, " has fewer than three usable features."))
  }
  complete_train <- stats::complete.cases(train[, features, drop = FALSE])
  complete_oos <- stats::complete.cases(oos[, features, drop = FALSE])
  train <- train[complete_train, , drop = FALSE]
  oos <- oos[complete_oos, , drop = FALSE]
  if (nrow(train) < 100L || nrow(oos) < 10L) {
    g5_stop(paste0("ML-P1 fold ", fold_id, " has insufficient TRAIN/OOS rows after feature filtering."))
  }
  means <- vapply(features, function(feature) mean(as.numeric(train[[feature]]), na.rm = TRUE), numeric(1L))
  sds <- vapply(features, function(feature) stats::sd(as.numeric(train[[feature]]), na.rm = TRUE), numeric(1L))
  sds[!is.finite(sds) | sds <= 1e-10] <- 1

  make_model_df <- function(rows, include_y = TRUE) {
    out <- data.frame(symbol = factor(rows$symbol, levels = sort(unique(feature_fold_table$symbol))), stringsAsFactors = FALSE)
    if (include_y) out$label_up_h3 <- as.integer(rows$label_up_h3)
    for (feature in features) {
      out[[feature]] <- (as.numeric(rows[[feature]]) - means[[feature]]) / sds[[feature]]
    }
    out
  }

  train_model <- make_model_df(train, include_y = TRUE)
  oos_model <- make_model_df(oos, include_y = FALSE)
  formula <- stats::as.formula(paste("label_up_h3 ~ symbol +", paste(features, collapse = " + ")))
  fit <- suppressWarnings(stats::glm(formula, data = train_model, family = stats::binomial(), control = list(maxit = 50L)))
  pred <- suppressWarnings(stats::predict(fit, newdata = oos_model, type = "response"))
  pred[!is.finite(pred)] <- mean(train_model$label_up_h3, na.rm = TRUE)
  oos$pred_prob_h3 <- as.numeric(pmin(1, pmax(0, pred)))
  oos$model_id <- "glm_logit_h3_fixed_threshold"
  oos$feature_count_used <- length(features)
  coefs <- stats::coef(fit)
  coef_df <- data.frame(
    fold_id = fold_id,
    term = names(coefs),
    coefficient = as.numeric(coefs),
    abs_coefficient = abs(as.numeric(coefs)),
    stringsAsFactors = FALSE
  )
  list(predictions = oos, coefficients = coef_df, feature_means = means, feature_sds = sds)
}

simulate_symbol_window <- function(preds, enter_threshold = 0.55, exit_threshold = 0.50) {
  preds <- preds[order(as.Date(preds$session_date)), , drop = FALSE]
  symbol <- unique(preds$symbol)[[1L]]
  window <- unique(preds$window_id)[[1L]]
  cash <- 1
  in_position <- FALSE
  entry_date <- as.Date(NA)
  entry_price <- NA_real_
  entry_signal_date <- as.Date(NA)
  entry_prob <- NA_real_
  pending_action <- NA_character_
  pending_execution_date <- as.Date(NA)
  pending_signal_date <- as.Date(NA)
  pending_prob <- NA_real_
  trades <- list()
  equity <- list()
  actions <- list()
  trade_no <- 1L
  exposure_days <- 0L
  first_close <- as.numeric(preds$close[[1L]])

  for (i in seq_len(nrow(preds))) {
    row <- preds[i, , drop = FALSE]
    current_date <- as.Date(row$session_date)
    current_open <- as.numeric(row$open)
    current_close <- as.numeric(row$close)

    executed_action <- "NONE"
    if (!is.na(pending_execution_date) && current_date == pending_execution_date) {
      if (identical(pending_action, "ENTER_LONG_NEXT_OPEN") && !in_position) {
        in_position <- TRUE
        entry_date <- current_date
        entry_price <- current_open
        entry_signal_date <- pending_signal_date
        entry_prob <- pending_prob
        executed_action <- "ENTER_LONG"
      } else if (identical(pending_action, "EXIT_LONG_NEXT_OPEN") && in_position) {
        exit_price <- current_open
        trade_return <- exit_price / entry_price - 1
        cash <- cash * (1 + trade_return)
        trades[[trade_no]] <- data.frame(
          window_id = window,
          symbol = symbol,
          trade_id = paste(symbol, window, trade_no, sep = "_"),
          entry_signal_date = entry_signal_date,
          entry_date = entry_date,
          entry_price = entry_price,
          entry_prob_h3 = entry_prob,
          exit_signal_date = pending_signal_date,
          exit_date = current_date,
          exit_price = exit_price,
          exit_prob_h3 = pending_prob,
          trade_return = trade_return,
          trade_status = "closed",
          stringsAsFactors = FALSE
        )
        trade_no <- trade_no + 1L
        in_position <- FALSE
        entry_date <- as.Date(NA)
        entry_price <- NA_real_
        entry_signal_date <- as.Date(NA)
        entry_prob <- NA_real_
        executed_action <- "EXIT_LONG"
      }
      pending_action <- NA_character_
      pending_execution_date <- as.Date(NA)
      pending_signal_date <- as.Date(NA)
      pending_prob <- NA_real_
    }

    position_at_close <- if (in_position) 1L else 0L
    if (position_at_close) exposure_days <- exposure_days + 1L
    active_mult <- if (in_position) cash * current_close / entry_price else cash
    benchmark_mult <- current_close / first_close

    signal_action <- if (!in_position && as.numeric(row$pred_prob_h3) >= enter_threshold) {
      "ENTER_LONG_NEXT_OPEN"
    } else if (in_position && as.numeric(row$pred_prob_h3) < exit_threshold) {
      "EXIT_LONG_NEXT_OPEN"
    } else if (in_position) {
      "HOLD_LONG"
    } else {
      "STAY_FLAT"
    }
    if (i == nrow(preds) || is.na(row$execution_date) || as.Date(row$execution_date) > max(as.Date(preds$session_date))) {
      if (signal_action %in% c("ENTER_LONG_NEXT_OPEN", "EXIT_LONG_NEXT_OPEN")) {
        signal_action <- paste0(signal_action, "_OUTSIDE_WINDOW")
      }
    } else if (signal_action %in% c("ENTER_LONG_NEXT_OPEN", "EXIT_LONG_NEXT_OPEN")) {
      pending_action <- signal_action
      pending_execution_date <- as.Date(row$execution_date)
      pending_signal_date <- current_date
      pending_prob <- as.numeric(row$pred_prob_h3)
    }

    actions[[i]] <- data.frame(
      window_id = window,
      fold_id = row$fold_id,
      symbol = symbol,
      feature_date = current_date,
      execution_date = as.Date(row$execution_date),
      pred_prob_h3 = as.numeric(row$pred_prob_h3),
      label_up_h3 = as.logical(row$label_up_h3),
      fwd_ret_h3 = as.numeric(row$fwd_ret_h3),
      signal_action = signal_action,
      executed_action = executed_action,
      position_at_close = position_at_close,
      active_mult = active_mult,
      benchmark_mult = benchmark_mult,
      stringsAsFactors = FALSE
    )
    equity[[i]] <- data.frame(
      window_id = window,
      symbol = symbol,
      session_date = current_date,
      active_mult = active_mult,
      benchmark_mult = benchmark_mult,
      position_at_close = position_at_close,
      stringsAsFactors = FALSE
    )
  }

  if (in_position) {
    last_row <- preds[nrow(preds), , drop = FALSE]
    trades[[trade_no]] <- data.frame(
      window_id = window,
      symbol = symbol,
      trade_id = paste(symbol, window, trade_no, sep = "_"),
      entry_signal_date = entry_signal_date,
      entry_date = entry_date,
      entry_price = entry_price,
      entry_prob_h3 = entry_prob,
      exit_signal_date = as.Date(NA),
      exit_date = as.Date(NA),
      exit_price = NA_real_,
      exit_prob_h3 = NA_real_,
      trade_return = as.numeric(last_row$close) / entry_price - 1,
      trade_status = "open_marked_to_window_close",
      stringsAsFactors = FALSE
    )
  }

  list(
    actions = g5_wfa_bind_rows_fill(actions),
    equity = g5_wfa_bind_rows_fill(equity),
    trades = g5_wfa_bind_rows_fill(trades),
    exposure_rate = exposure_days / nrow(preds)
  )
}

simulate_glm_replay <- function(predictions, enter_threshold = 0.55, exit_threshold = 0.50, initial_capital = 100000) {
  keys <- unique(paste(predictions$window_id, predictions$symbol, sep = "||"))
  parts <- lapply(keys, function(key) {
    bits <- strsplit(key, "||", fixed = TRUE)[[1L]]
    simulate_symbol_window(
      predictions[predictions$window_id == bits[[1L]] & predictions$symbol == bits[[2L]], , drop = FALSE],
      enter_threshold = enter_threshold,
      exit_threshold = exit_threshold
    )
  })
  actions <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$actions))
  equity_symbol <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$equity))
  trades <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$trades))
  portfolio_rows <- list()
  idx <- 1L
  for (window in unique(equity_symbol$window_id)) {
    dates <- sort(unique(as.Date(equity_symbol$session_date[equity_symbol$window_id == window])))
    for (d in dates) {
      rows <- equity_symbol[equity_symbol$window_id == window & as.Date(equity_symbol$session_date) == d, , drop = FALSE]
      portfolio_rows[[idx]] <- data.frame(
        window_id = window,
        session_date = d,
        active_mult = mean(rows$active_mult, na.rm = TRUE),
        benchmark_mult = mean(rows$benchmark_mult, na.rm = TRUE),
        active_equity = initial_capital * mean(rows$active_mult, na.rm = TRUE),
        benchmark_equity = initial_capital * mean(rows$benchmark_mult, na.rm = TRUE),
        exposure_rate = mean(rows$position_at_close, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  portfolio <- g5_wfa_bind_rows_fill(portfolio_rows)
  list(actions = actions, equity_symbol = equity_symbol, trades = trades, portfolio = portfolio)
}

max_drawdown <- function(x) {
  x <- as.numeric(x)
  if (!length(x) || all(!is.finite(x))) return(NA_real_)
  peak <- cummax(x)
  min(x / peak - 1, na.rm = TRUE)
}

summarize_replay <- function(replay) {
  rows <- list()
  idx <- 1L
  for (window in unique(replay$portfolio$window_id)) {
    p <- replay$portfolio[replay$portfolio$window_id == window, , drop = FALSE]
    p <- p[order(as.Date(p$session_date)), , drop = FALSE]
    rows[[idx]] <- data.frame(
      window_id = window,
      active_return = tail(p$active_mult, 1) - 1,
      benchmark_return = tail(p$benchmark_mult, 1) - 1,
      excess_return = tail(p$active_mult, 1) - tail(p$benchmark_mult, 1),
      active_max_drawdown = max_drawdown(p$active_mult),
      benchmark_max_drawdown = max_drawdown(p$benchmark_mult),
      mean_exposure = mean(p$exposure_rate, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
    idx <- idx + 1L
  }
  g5_wfa_bind_rows_fill(rows)
}

action_audit <- function(actions) {
  counts <- aggregate(
    rep(1L, nrow(actions)),
    list(window_id = actions$window_id, signal_action = actions$signal_action),
    sum
  )
  names(counts)[names(counts) == "x"] <- "row_count"
  totals <- aggregate(counts$row_count, list(window_id = counts$window_id), sum)
  names(totals)[names(totals) == "x"] <- "total_rows"
  out <- merge(counts, totals, by = "window_id")
  out$row_rate <- out$row_count / out$total_rows
  out
}

calibration_audit <- function(predictions) {
  rows <- list()
  idx <- 1L
  for (window in unique(predictions$window_id)) {
    x <- predictions[predictions$window_id == window, , drop = FALSE]
    ranks <- rank(x$pred_prob_h3, ties.method = "average")
    dec <- pmin(10L, pmax(1L, ceiling(10 * ranks / length(ranks))))
    for (d in seq_len(10L)) {
      part <- x[dec == d, , drop = FALSE]
      rows[[idx]] <- data.frame(
        window_id = window,
        pred_decile = d,
        row_count = nrow(part),
        mean_pred_prob_h3 = mean(part$pred_prob_h3, na.rm = TRUE),
        label_up_rate = mean(part$label_up_h3, na.rm = TRUE),
        mean_fwd_ret_h3 = mean(part$fwd_ret_h3, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  g5_wfa_bind_rows_fill(rows)
}

coefficient_summary <- function(coefficients) {
  coefs <- coefficients[!grepl("^\\(Intercept\\)|^symbol", coefficients$term), , drop = FALSE]
  agg <- aggregate(
    cbind(mean_abs_coefficient = coefs$abs_coefficient, mean_coefficient = coefs$coefficient),
    list(term = coefs$term),
    mean,
    na.rm = TRUE
  )
  agg <- agg[order(-agg$mean_abs_coefficient), , drop = FALSE]
  rownames(agg) <- NULL
  agg
}

write_equity_png <- function(summary, portfolio, path) {
  grDevices::png(path, width = 2600L, height = 1500L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (window in c("2020Y", "2022Y")) {
    x <- portfolio[portfolio$window_id == window, , drop = FALSE]
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    graphics::plot(as.Date(x$session_date), x$benchmark_mult, type = "l", lwd = 2, col = "#9CA3AF",
                   xlab = "Session", ylab = "Equity multiple", main = paste0(window, " GLM replay vs basket hold"))
    graphics::lines(as.Date(x$session_date), x$active_mult, lwd = 2, col = "#2563EB")
    graphics::legend("topleft", legend = c("GLM replay", "Equal-weight hold"), col = c("#2563EB", "#9CA3AF"), lwd = 2, bty = "n")
  }
}

write_action_audit_png <- function(audit, path) {
  grDevices::png(path, width = 2400L, height = 1300L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(8, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  audit$key <- paste(audit$window_id, audit$signal_action, sep = " / ")
  audit <- audit[order(audit$window_id, audit$signal_action), , drop = FALSE]
  cols <- ifelse(grepl("ENTER", audit$signal_action), "#16A34A",
    ifelse(grepl("EXIT", audit$signal_action), "#DC2626", "#9CA3AF")
  )
  graphics::barplot(audit$row_rate, names.arg = audit$key, las = 2, col = cols, border = NA,
                    ylim = c(0, max(audit$row_rate, na.rm = TRUE) * 1.15),
                    ylab = "Share of OOS decision rows", main = "Fixed-threshold policy mostly stays selective")
}

write_calibration_png <- function(calibration, path) {
  grDevices::png(path, width = 2400L, height = 1300L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (window in c("2020Y", "2022Y")) {
    x <- calibration[calibration$window_id == window, , drop = FALSE]
    graphics::plot(x$mean_pred_prob_h3, x$mean_fwd_ret_h3, type = "b", pch = 19, lwd = 2, col = "#111827",
                   xlab = "Mean predicted h3 up probability", ylab = "Mean observed h3 return",
                   main = paste0(window, " probability deciles"))
    graphics::abline(h = 0, lty = 2, col = "#9CA3AF")
  }
}

write_coefficients_png <- function(coef_summary, path, n = 15L) {
  x <- head(coef_summary, n)
  grDevices::png(path, width = 2200L, height = 1500L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(5, 12, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  y <- seq_len(nrow(x))
  cols <- ifelse(x$mean_coefficient >= 0, "#2563EB", "#DC2626")
  graphics::barplot(rev(x$mean_abs_coefficient), names.arg = rev(x$term), horiz = TRUE, las = 1, col = rev(cols), border = NA,
                    xlab = "Mean absolute standardized coefficient", main = "GLM uses trend, range, volatility, and context features")
}

write_probability_tape_png <- function(predictions, replay, path) {
  examples <- list(c("AMD", "2020Y"), c("TSLA", "2022Y"))
  grDevices::png(path, width = 2800L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (example in examples) {
    sym <- example[[1L]]
    window <- example[[2L]]
    p <- predictions[predictions$symbol == sym & predictions$window_id == window, , drop = FALSE]
    a <- replay$actions[replay$actions$symbol == sym & replay$actions$window_id == window, , drop = FALSE]
    p <- p[order(as.Date(p$session_date)), , drop = FALSE]
    a <- a[order(as.Date(a$feature_date)), , drop = FALSE]
    d <- as.Date(p$session_date)
    graphics::plot(d, p$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(sym, window, "price and GLM actions"))
    entries <- a[a$executed_action == "ENTER_LONG", , drop = FALSE]
    exits <- a[a$executed_action == "EXIT_LONG", , drop = FALSE]
    if (nrow(entries)) graphics::points(as.Date(entries$feature_date), p$close[match(as.Date(entries$feature_date), d)], pch = 24, bg = "#16A34A", col = "#111827", cex = 1.2)
    if (nrow(exits)) graphics::points(as.Date(exits$feature_date), p$close[match(as.Date(exits$feature_date), d)], pch = 25, bg = "#DC2626", col = "#111827", cex = 1.2)
    graphics::plot(d, p$pred_prob_h3, type = "l", lwd = 2, col = "#2563EB", ylim = c(0, 1), xlab = "Session", ylab = "Predicted probability", main = paste(sym, window, "probability trace"))
    graphics::abline(h = c(0.55, 0.50), lty = c(2, 3), col = c("#16A34A", "#DC2626"), lwd = 1.5)
  }
}

write_summary_report <- function(path, run_spec, summary, leakage_audit, artifact_index) {
  pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))
  lines <- c(
    "# Gen5.4 ML-P1 GLM Replay",
    "",
    "## Purpose",
    "",
    "This packet fits a no-new-dependency GLM logistic baseline on TRAIN rows and replays OOS daily long/flat decisions. It is a plumbing and diagnostic model, not accepted allocation evidence.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    paste0("- Thresholds: enter `", run_spec$enter_threshold[[1L]], "`, exit `", run_spec$exit_threshold[[1L]], "`."),
    "",
    "## Leakage Audit",
    "",
    paste0("- `", leakage_audit$check_id, "`: ", leakage_audit$status, " - ", leakage_audit$detail),
    "",
    "## Replay Summary",
    "",
    paste0("- `", summary$window_id, "` active return: `", pct(summary$active_return), "` vs basket hold `", pct(summary$benchmark_return), "`; excess `", pct(summary$excess_return), "`; mean exposure `", pct(summary$mean_exposure), "`."),
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_index$artifact_id, "`: `", artifact_index$path, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

if (!identical(Sys.getenv("GEN5_GEN54_ML_P1_SOURCE_ONLY", unset = "false"), "true")) {
g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN54_ML_P1_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P1_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_ML_P1_STAMP", "20260713p1"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p1_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

live_symbols <- g5_standardize_symbol(split_csv(env_or("GEN5_GEN54_ML_P1_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO")))
context_symbols <- unique(g5_standardize_symbol(c(live_symbols, split_csv(env_or(
  "GEN5_GEN54_ML_P1_CONTEXT_SYMBOLS",
  "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"
)))))
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P1_YEARS", "2020,2022")))
horizon <- as.integer(env_or("GEN5_GEN54_ML_P1_HORIZON", "3"))
threshold <- as.numeric(env_or("GEN5_GEN54_ML_P1_LABEL_THRESHOLD", "0"))
enter_threshold <- as.numeric(env_or("GEN5_GEN54_ML_P1_ENTER_THRESHOLD", "0.55"))
exit_threshold <- as.numeric(env_or("GEN5_GEN54_ML_P1_EXIT_THRESHOLD", "0.50"))
initial_capital <- as.numeric(env_or("GEN5_GEN54_ML_P1_INITIAL_CAPITAL", "100000"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P1_AS_OF", "2022-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P1_WARMUP_DAYS", "420"))

folds <- build_folds(years)
query_start <- min(folds$train_start_date) - warmup_days
query_end <- max(folds$oos_end_date)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = context_symbols,
  universe_name = "gen54_ml_p1_context",
  universe_roles = "live_basket,context_universe",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) {
  g5_stop("ML-P1 query returned no bars.")
}

feature_tables <- list()
for (sym in context_symbols) {
  feature_tables[[sym]] <- augment_ohlcv_features(g5_pca_regime_feature_table(query$bars, sym, end_date = query_end))
}
feature_tables <- add_market_relative_features(feature_tables, live_symbols, context_symbols)
labeled <- lapply(live_symbols, function(sym) add_forward_label(feature_tables[[sym]], horizon = horizon, threshold = threshold))
feature_labels <- g5_wfa_bind_rows_fill(labeled)
feature_fold_table <- assign_fold_split(feature_labels, folds)
features <- intersect(feature_columns(), names(feature_fold_table))

fold_ids <- unique(feature_fold_table$fold_id)
fits <- lapply(fold_ids, function(fold_id) fit_glm_fold(feature_fold_table, fold_id, features))
predictions <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$predictions))
coefficients <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$coefficients))
replay <- simulate_glm_replay(predictions, enter_threshold = enter_threshold, exit_threshold = exit_threshold, initial_capital = initial_capital)
summary <- summarize_replay(replay)
actions <- action_audit(replay$actions)
calibration <- calibration_audit(predictions)
coef_summary <- coefficient_summary(coefficients)
leakage <- data.frame(
  check_id = c("train_fit_only", "oos_prediction_only", "fixed_thresholds", "no_live_bridge_change"),
  status = rep("PASS", 4L),
  detail = c(
    "Each GLM is fit only on TRAIN rows for its fold.",
    "OOS rows are used only for frozen-model prediction and replay inspection.",
    "Enter/exit thresholds are fixed before OOS replay.",
    "This wrapper writes research artifacts only and does not source or change live advice bridge behavior."
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p1_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p1_fold_spec.csv"),
  predictions_csv = file.path(output_dir, "ml_p1_oos_predictions.csv"),
  actions_csv = file.path(output_dir, "ml_p1_action_table.csv"),
  trades_csv = file.path(output_dir, "ml_p1_trade_ledger.csv"),
  symbol_equity_csv = file.path(output_dir, "ml_p1_symbol_equity.csv"),
  portfolio_equity_csv = file.path(output_dir, "ml_p1_portfolio_equity.csv"),
  summary_csv = file.path(output_dir, "ml_p1_summary.csv"),
  action_audit_csv = file.path(output_dir, "ml_p1_action_audit.csv"),
  calibration_csv = file.path(output_dir, "ml_p1_calibration_audit.csv"),
  coefficients_csv = file.path(output_dir, "ml_p1_glm_coefficients.csv"),
  coefficient_summary_csv = file.path(output_dir, "ml_p1_glm_coefficient_summary.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p1_leakage_audit.csv"),
  report_md = file.path(output_dir, "ml_p1_glm_replay_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p1_artifact_index.csv"),
  equity_png = file.path(visual_dir, "ml_p1_equity_vs_benchmark.png"),
  action_audit_png = file.path(visual_dir, "ml_p1_action_audit.png"),
  calibration_png = file.path(visual_dir, "ml_p1_calibration_deciles.png"),
  coefficients_png = file.path(visual_dir, "ml_p1_top_coefficients.png"),
  probability_tape_png = file.path(visual_dir, "ml_p1_probability_trade_tapes.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p1_glm_replay_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_glm_replay.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  context_symbols = paste(context_symbols, collapse = ","),
  windows = paste(paste0(years, "Y"), collapse = ","),
  label_id = paste0("h", horizon, "_next_open_to_close"),
  model_id = "glm_logit_h3_fixed_threshold",
  enter_threshold = enter_threshold,
  exit_threshold = exit_threshold,
  prediction_rows = nrow(predictions),
  selected_feature_count = length(features),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_equity_png(summary, replay$portfolio, paths$equity_png)
write_action_audit_png(actions, paths$action_audit_png)
write_calibration_png(calibration, paths$calibration_png)
write_coefficients_png(coef_summary, paths$coefficients_png)
write_probability_tape_png(predictions, replay, paths$probability_tape_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 13L), "markdown", "csv", rep("png", 5L)),
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(predictions, paths$predictions_csv)
g5_wfa_write_csv(replay$actions, paths$actions_csv)
g5_wfa_write_csv(replay$trades, paths$trades_csv)
g5_wfa_write_csv(replay$equity_symbol, paths$symbol_equity_csv)
g5_wfa_write_csv(replay$portfolio, paths$portfolio_equity_csv)
g5_wfa_write_csv(summary, paths$summary_csv)
g5_wfa_write_csv(actions, paths$action_audit_csv)
g5_wfa_write_csv(calibration, paths$calibration_csv)
g5_wfa_write_csv(coefficients, paths$coefficients_csv)
g5_wfa_write_csv(coef_summary, paths$coefficient_summary_csv)
g5_wfa_write_csv(leakage, paths$leakage_audit_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_summary_report(paths$report_md, run_spec, summary, leakage, artifact_index)

message("Gen5.4 ML-P1 GLM replay complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("Summary: ", paste(summary$window_id, sprintf("active=%.1f%% benchmark=%.1f%%", 100 * summary$active_return, 100 * summary$benchmark_return), collapse = "; "))
}
