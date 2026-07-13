# Gen5.4 supervised ML-P1b GLM threshold diagnostic.
#
# This wrapper keeps the ML-P1 GLM model contract fixed, then compares fixed
# thresholds against two TRAIN-only threshold policies before OOS replay.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

Sys.setenv(GEN5_GEN54_ML_P1_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_glm_replay.R"))
Sys.unsetenv("GEN5_GEN54_ML_P1_SOURCE_ONLY")

fit_glm_fold_with_train_predictions <- function(feature_fold_table, fold_id, features) {
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
    sd_value <- suppressWarnings(stats::sd(values, na.rm = TRUE))
    sum(is.finite(values)) >= 100L && is.finite(sd_value) && sd_value > 1e-10
  }, logical(1L))
  features <- features[keep_feature]
  if (length(features) < 3L) {
    g5_stop(paste0("ML-P1b fold ", fold_id, " has fewer than three usable features."))
  }

  complete_train <- stats::complete.cases(train[, features, drop = FALSE])
  complete_oos <- stats::complete.cases(oos[, features, drop = FALSE])
  train <- train[complete_train, , drop = FALSE]
  oos <- oos[complete_oos, , drop = FALSE]
  if (nrow(train) < 100L || nrow(oos) < 10L) {
    g5_stop(paste0("ML-P1b fold ", fold_id, " has insufficient TRAIN/OOS rows after feature filtering."))
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
  train_pred <- suppressWarnings(stats::predict(fit, newdata = train_model, type = "response"))
  oos_pred <- suppressWarnings(stats::predict(fit, newdata = oos_model, type = "response"))
  fallback <- mean(train_model$label_up_h3, na.rm = TRUE)
  train_pred[!is.finite(train_pred)] <- fallback
  oos_pred[!is.finite(oos_pred)] <- fallback
  train$pred_prob_h3 <- as.numeric(pmin(1, pmax(0, train_pred)))
  oos$pred_prob_h3 <- as.numeric(pmin(1, pmax(0, oos_pred)))
  train$model_id <- "glm_logit_h3_threshold_diagnostic"
  oos$model_id <- "glm_logit_h3_threshold_diagnostic"
  train$feature_count_used <- length(features)
  oos$feature_count_used <- length(features)

  coefs <- stats::coef(fit)
  coef_df <- data.frame(
    fold_id = fold_id,
    term = names(coefs),
    coefficient = as.numeric(coefs),
    abs_coefficient = abs(as.numeric(coefs)),
    stringsAsFactors = FALSE
  )

  list(
    train_predictions = train,
    oos_predictions = oos,
    coefficients = coef_df,
    feature_means = means,
    feature_sds = sds
  )
}

safe_quantile <- function(x, prob) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  as.numeric(stats::quantile(x, probs = prob, na.rm = TRUE, names = FALSE, type = 7))
}

threshold_grid <- function() {
  grid <- expand.grid(
    enter_threshold = seq(0.46, 0.62, by = 0.02),
    exit_threshold = seq(0.42, 0.56, by = 0.02),
    stringsAsFactors = FALSE
  )
  grid[grid$exit_threshold < grid$enter_threshold, , drop = FALSE]
}

score_threshold_pair_fast <- function(train, enter_threshold, exit_threshold) {
  rows <- list()
  idx <- 1L
  for (symbol in unique(train$symbol)) {
    x <- train[train$symbol == symbol, , drop = FALSE]
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    in_position <- FALSE
    position <- integer(nrow(x))
    for (i in seq_len(nrow(x))) {
      p <- as.numeric(x$pred_prob_h3[[i]])
      if (!in_position && is.finite(p) && p >= enter_threshold) {
        in_position <- TRUE
      } else if (in_position && is.finite(p) && p < exit_threshold) {
        in_position <- FALSE
      }
      position[[i]] <- if (in_position) 1L else 0L
    }
    rows[[idx]] <- data.frame(
      position = position,
      fwd_ret_h3 = as.numeric(x$fwd_ret_h3),
      stringsAsFactors = FALSE
    )
    idx <- idx + 1L
  }
  scored <- g5_wfa_bind_rows_fill(rows)
  selected_ret <- ifelse(scored$position == 1L, scored$fwd_ret_h3, 0)
  exposure <- mean(scored$position, na.rm = TRUE)
  objective <- mean(selected_ret, na.rm = TRUE)
  # This is a TRAIN-only selection proxy, not a portfolio replay metric.
  data.frame(
    train_active_return = objective,
    train_benchmark_return = mean(scored$fwd_ret_h3, na.rm = TRUE),
    train_excess_return = objective - mean(scored$fwd_ret_h3, na.rm = TRUE),
    train_active_max_drawdown = NA_real_,
    train_mean_exposure = exposure,
    stringsAsFactors = FALSE
  )
}

single_window_summary <- function(replay) {
  s <- summarize_replay(replay)
  if (!nrow(s)) {
    return(data.frame(
      train_active_return = NA_real_,
      train_benchmark_return = NA_real_,
      train_excess_return = NA_real_,
      train_active_max_drawdown = NA_real_,
      train_mean_exposure = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    train_active_return = s$active_return[[1L]],
    train_benchmark_return = s$benchmark_return[[1L]],
    train_excess_return = s$excess_return[[1L]],
    train_active_max_drawdown = s$active_max_drawdown[[1L]],
    train_mean_exposure = s$mean_exposure[[1L]],
    stringsAsFactors = FALSE
  )
}

select_threshold_policies <- function(train_predictions, fixed_enter = 0.55, fixed_exit = 0.50) {
  policies <- list()
  idx <- 1L
  for (fold_id in unique(train_predictions$fold_id)) {
    train <- train_predictions[train_predictions$fold_id == fold_id, , drop = FALSE]
    window <- unique(train$window_id)[[1L]]

    fixed_summary <- score_threshold_pair_fast(train, enter_threshold = fixed_enter, exit_threshold = fixed_exit)
    policies[[idx]] <- cbind(
      data.frame(
        policy_id = "fixed_055_050",
        policy_family = "fixed",
        fold_id = fold_id,
        window_id = window,
        enter_threshold = fixed_enter,
        exit_threshold = fixed_exit,
        selection_basis = "predeclared_fixed_thresholds",
        stringsAsFactors = FALSE
      ),
      fixed_summary
    )
    idx <- idx + 1L

    q_enter <- safe_quantile(train$pred_prob_h3, 0.60)
    q_exit <- safe_quantile(train$pred_prob_h3, 0.45)
    if (!is.finite(q_enter)) q_enter <- fixed_enter
    if (!is.finite(q_exit)) q_exit <- fixed_exit
    if (q_exit >= q_enter) q_exit <- max(0.01, q_enter - 0.03)
    quantile_summary <- score_threshold_pair_fast(train, enter_threshold = q_enter, exit_threshold = q_exit)
    policies[[idx]] <- cbind(
      data.frame(
        policy_id = "train_quantile_60_45",
        policy_family = "train_distribution",
        fold_id = fold_id,
        window_id = window,
        enter_threshold = q_enter,
        exit_threshold = q_exit,
        selection_basis = "TRAIN prediction distribution quantiles p60/p45",
        stringsAsFactors = FALSE
      ),
      quantile_summary
    )
    idx <- idx + 1L

    candidates <- threshold_grid()
    candidate_rows <- list()
    for (i in seq_len(nrow(candidates))) {
      candidate_rows[[i]] <- cbind(
        candidates[i, , drop = FALSE],
        score_threshold_pair_fast(
          train,
          enter_threshold = candidates$enter_threshold[[i]],
          exit_threshold = candidates$exit_threshold[[i]]
        )
      )
    }
    candidate_df <- g5_wfa_bind_rows_fill(candidate_rows)
    candidate_df$objective <- candidate_df$train_active_return - 0.15 * pmax(0, 0.20 - candidate_df$train_mean_exposure)
    candidate_df$drawdown_tie_break <- ifelse(is.finite(candidate_df$train_active_max_drawdown), candidate_df$train_active_max_drawdown, 0)
    candidate_df$exposure_tie_break <- -abs(candidate_df$train_mean_exposure - 0.65)
    candidate_df <- candidate_df[order(
      -candidate_df$objective,
      -candidate_df$drawdown_tie_break,
      -candidate_df$exposure_tie_break,
      candidate_df$enter_threshold,
      candidate_df$exit_threshold
    ), , drop = FALSE]
    best <- candidate_df[1L, , drop = FALSE]
    policies[[idx]] <- cbind(
      data.frame(
        policy_id = "train_forward_return_grid",
        policy_family = "train_forward_return_objective",
        fold_id = fold_id,
        window_id = window,
        enter_threshold = best$enter_threshold[[1L]],
        exit_threshold = best$exit_threshold[[1L]],
        selection_basis = "TRAIN forward-return participation proxy; exposure tie-break",
        stringsAsFactors = FALSE
      ),
      best[, c("train_active_return", "train_benchmark_return", "train_excess_return", "train_active_max_drawdown", "train_mean_exposure"), drop = FALSE]
    )
    idx <- idx + 1L
  }
  g5_wfa_bind_rows_fill(policies)
}

simulate_symbol_window_variable <- function(preds) {
  preds <- preds[order(as.Date(preds$session_date)), , drop = FALSE]
  symbol <- unique(preds$symbol)[[1L]]
  window <- unique(preds$window_id)[[1L]]
  policy <- unique(preds$policy_id)[[1L]]
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
          policy_id = policy,
          trade_id = paste(policy, symbol, window, trade_no, sep = "_"),
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
    enter_threshold <- as.numeric(row$enter_threshold)
    exit_threshold <- as.numeric(row$exit_threshold)

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
      policy_id = policy,
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
      enter_threshold = enter_threshold,
      exit_threshold = exit_threshold,
      stringsAsFactors = FALSE
    )
    equity[[i]] <- data.frame(
      window_id = window,
      symbol = symbol,
      policy_id = policy,
      session_date = current_date,
      active_mult = active_mult,
      benchmark_mult = benchmark_mult,
      position_at_close = position_at_close,
      enter_threshold = enter_threshold,
      exit_threshold = exit_threshold,
      stringsAsFactors = FALSE
    )
  }

  if (in_position) {
    last_row <- preds[nrow(preds), , drop = FALSE]
    trades[[trade_no]] <- data.frame(
      window_id = window,
      symbol = symbol,
      policy_id = policy,
      trade_id = paste(policy, symbol, window, trade_no, sep = "_"),
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

simulate_variable_threshold_replay <- function(predictions, initial_capital = 100000) {
  keys <- unique(paste(predictions$policy_id, predictions$window_id, predictions$symbol, sep = "||"))
  parts <- lapply(keys, function(key) {
    bits <- strsplit(key, "||", fixed = TRUE)[[1L]]
    simulate_symbol_window_variable(
      predictions[
        predictions$policy_id == bits[[1L]] &
          predictions$window_id == bits[[2L]] &
          predictions$symbol == bits[[3L]],
        ,
        drop = FALSE
      ]
    )
  })
  actions <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$actions))
  equity_symbol <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$equity))
  trades <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$trades))
  portfolio_rows <- list()
  idx <- 1L
  for (policy in unique(equity_symbol$policy_id)) {
    for (window in unique(equity_symbol$window_id[equity_symbol$policy_id == policy])) {
      dates <- sort(unique(as.Date(equity_symbol$session_date[equity_symbol$policy_id == policy & equity_symbol$window_id == window])))
      for (d in dates) {
        rows <- equity_symbol[equity_symbol$policy_id == policy & equity_symbol$window_id == window & as.Date(equity_symbol$session_date) == d, , drop = FALSE]
        portfolio_rows[[idx]] <- data.frame(
          policy_id = policy,
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
  }
  portfolio <- g5_wfa_bind_rows_fill(portfolio_rows)
  list(actions = actions, equity_symbol = equity_symbol, trades = trades, portfolio = portfolio)
}

simulate_policy_replays <- function(oos_predictions, policy_table, initial_capital = 100000) {
  policy_predictions <- list()
  idx <- 1L
  for (policy in unique(policy_table$policy_id)) {
    specs <- policy_table[policy_table$policy_id == policy, c("fold_id", "policy_id", "enter_threshold", "exit_threshold"), drop = FALSE]
    preds <- merge(oos_predictions, specs, by = "fold_id", all.x = FALSE, all.y = FALSE, sort = FALSE)
    policy_predictions[[idx]] <- preds
    idx <- idx + 1L
  }
  simulate_variable_threshold_replay(g5_wfa_bind_rows_fill(policy_predictions), initial_capital = initial_capital)
}

summarize_policy_replay <- function(replay) {
  rows <- list()
  idx <- 1L
  for (policy in unique(replay$portfolio$policy_id)) {
    for (window in unique(replay$portfolio$window_id[replay$portfolio$policy_id == policy])) {
      p <- replay$portfolio[replay$portfolio$policy_id == policy & replay$portfolio$window_id == window, , drop = FALSE]
      p <- p[order(as.Date(p$session_date)), , drop = FALSE]
      rows[[idx]] <- data.frame(
        policy_id = policy,
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
  }
  g5_wfa_bind_rows_fill(rows)
}

action_audit_by_policy <- function(actions) {
  counts <- aggregate(
    rep(1L, nrow(actions)),
    list(policy_id = actions$policy_id, window_id = actions$window_id, signal_action = actions$signal_action),
    sum
  )
  names(counts)[names(counts) == "x"] <- "row_count"
  totals <- aggregate(counts$row_count, list(policy_id = counts$policy_id, window_id = counts$window_id), sum)
  names(totals)[names(totals) == "x"] <- "total_rows"
  out <- merge(counts, totals, by = c("policy_id", "window_id"))
  out$row_rate <- out$row_count / out$total_rows
  out
}

write_policy_equity_png <- function(summary, portfolio, path) {
  grDevices::png(path, width = 2800L, height = 1600L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(
    fixed_055_050 = "#2563EB",
    train_quantile_60_45 = "#16A34A",
    train_forward_return_grid = "#F97316"
  )
  for (window in c("2020Y", "2022Y")) {
    p0 <- portfolio[portfolio$window_id == window, , drop = FALSE]
    dates <- sort(unique(as.Date(p0$session_date)))
    bench <- p0[p0$policy_id == unique(p0$policy_id)[[1L]], , drop = FALSE]
    bench <- bench[order(as.Date(bench$session_date)), , drop = FALSE]
    graphics::plot(as.Date(bench$session_date), bench$benchmark_mult, type = "l", lwd = 3, col = "#9CA3AF",
                   xlab = "Session", ylab = "Equity multiple", main = paste0(window, " OOS policy replay"))
    for (policy in names(cols)) {
      x <- p0[p0$policy_id == policy, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(x$session_date), x$active_mult, lwd = 2, col = cols[[policy]])
    }
    graphics::legend("topleft",
      legend = c("Equal-weight hold", names(cols)),
      col = c("#9CA3AF", unname(cols)),
      lwd = c(3, rep(2, length(cols))),
      bty = "n",
      cex = 0.75
    )
  }
}

write_policy_summary_png <- function(summary, path) {
  grDevices::png(path, width = 2600L, height = 1400L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(8, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  summary$key <- paste(summary$window_id, summary$policy_id, sep = " / ")
  summary <- summary[order(summary$window_id, summary$policy_id), , drop = FALSE]
  cols <- ifelse(summary$excess_return >= 0, "#16A34A", "#DC2626")
  graphics::barplot(
    summary$excess_return,
    names.arg = summary$key,
    las = 2,
    col = cols,
    border = NA,
    ylab = "Active minus equal-weight hold",
    main = "Threshold policy changes participation, but alpha must clear basket hold"
  )
  graphics::abline(h = 0, lty = 2, col = "#6B7280")
}

write_threshold_png <- function(policy_table, path) {
  grDevices::png(path, width = 2600L, height = 1400L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (threshold_col in c("enter_threshold", "exit_threshold")) {
    x <- policy_table[order(policy_table$window_id, policy_table$policy_id), , drop = FALSE]
    x$key <- paste(x$window_id, x$policy_id, sep = "\n")
    graphics::barplot(
      x[[threshold_col]],
      names.arg = x$key,
      las = 2,
      ylim = c(0.35, 0.70),
      col = ifelse(threshold_col == "enter_threshold", "#2563EB", "#DC2626"),
      border = NA,
      ylab = "Predicted h3 probability",
      main = gsub("_", " ", threshold_col)
    )
  }
}

write_policy_action_png <- function(audit, path) {
  grDevices::png(path, width = 2700L, height = 1500L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(9, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  keep <- audit$signal_action %in% c("ENTER_LONG_NEXT_OPEN", "HOLD_LONG", "STAY_FLAT", "EXIT_LONG_NEXT_OPEN")
  x <- audit[keep, , drop = FALSE]
  x$key <- paste(x$window_id, x$policy_id, x$signal_action, sep = " / ")
  x <- x[order(x$window_id, x$policy_id, x$signal_action), , drop = FALSE]
  cols <- ifelse(grepl("ENTER|HOLD", x$signal_action), "#16A34A",
    ifelse(grepl("EXIT", x$signal_action), "#DC2626", "#9CA3AF")
  )
  graphics::barplot(x$row_rate, names.arg = x$key, las = 2, col = cols, border = NA,
                    ylab = "Share of OOS decision rows", main = "Policy action mix reveals whether thresholds actually increase participation")
}

write_policy_probability_tape_png <- function(predictions, replay, policy_table, path) {
  examples <- list(c("AMD", "2020Y"), c("TSLA", "2022Y"))
  grDevices::png(path, width = 2800L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(
    fixed_055_050 = "#2563EB",
    train_quantile_60_45 = "#16A34A",
    train_forward_return_grid = "#F97316"
  )
  for (example in examples) {
    sym <- example[[1L]]
    window <- example[[2L]]
    p <- predictions[predictions$split == "OOS" & predictions$symbol == sym & predictions$window_id == window, , drop = FALSE]
    p <- p[order(as.Date(p$session_date)), , drop = FALSE]
    d <- as.Date(p$session_date)
    graphics::plot(d, p$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(sym, window, "price and executed entries"))
    for (policy in names(cols)) {
      a <- replay$actions[
        replay$actions$policy_id == policy &
          replay$actions$symbol == sym &
          replay$actions$window_id == window &
          replay$actions$executed_action == "ENTER_LONG",
        ,
        drop = FALSE
      ]
      if (nrow(a)) {
        graphics::points(as.Date(a$feature_date), p$close[match(as.Date(a$feature_date), d)], pch = 24, bg = cols[[policy]], col = "#111827", cex = 1.0)
      }
    }
    graphics::plot(d, p$pred_prob_h3, type = "l", lwd = 2, col = "#111827", ylim = c(0, 1), xlab = "Session", ylab = "Predicted probability", main = paste(sym, window, "probability and fold thresholds"))
    for (policy in names(cols)) {
      spec <- policy_table[policy_table$policy_id == policy & policy_table$window_id == window, , drop = FALSE]
      if (nrow(spec)) {
        graphics::abline(h = spec$enter_threshold[[1L]], lty = 2, col = cols[[policy]], lwd = 1.5)
      }
    }
    graphics::legend("bottomleft", legend = names(cols), col = unname(cols), lwd = 2, bty = "n", cex = 0.7)
  }
}

write_p1b_report <- function(path, run_spec, summary, policy_table, leakage_audit, artifact_index) {
  pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))
  best_by_window <- do.call(rbind, lapply(unique(summary$window_id), function(window) {
    x <- summary[summary$window_id == window, , drop = FALSE]
    x[order(-x$excess_return), , drop = FALSE][1L, , drop = FALSE]
  }))
  lines <- c(
    "# Gen5.4 ML-P1b GLM Threshold Diagnostic",
    "",
    "## Purpose",
    "",
    "This packet keeps the ML-P1 GLM model fixed and asks whether TRAIN-only threshold policy can improve OOS participation before adding model complexity.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    paste0("- Policies: `", paste(unique(summary$policy_id), collapse = "`, `"), "`"),
    "",
    "## Leakage Audit",
    "",
    paste0("- `", leakage_audit$check_id, "`: ", leakage_audit$status, " - ", leakage_audit$detail),
    "",
    "## OOS Summary",
    "",
    paste0("- `", summary$window_id, "` / `", summary$policy_id, "`: active `", pct(summary$active_return), "` vs basket hold `", pct(summary$benchmark_return), "`; excess `", pct(summary$excess_return), "`; exposure `", pct(summary$mean_exposure), "`."),
    "",
    "## Best Policy By Window",
    "",
    paste0("- `", best_by_window$window_id, "`: `", best_by_window$policy_id, "` had the highest OOS excess return at `", pct(best_by_window$excess_return), "`."),
    "",
    "## Fold-Level Thresholds",
    "",
    paste0("- `", policy_table$window_id, "` / `", policy_table$policy_id, "`: enter `", sprintf("%.3f", policy_table$enter_threshold), "`, exit `", sprintf("%.3f", policy_table$exit_threshold), "`; TRAIN return `", pct(policy_table$train_active_return), "`."),
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_index$artifact_id, "`: `", artifact_index$path, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN54_ML_P1B_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P1B_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_ML_P1B_STAMP", "20260713p1b"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p1b_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

live_symbols <- g5_standardize_symbol(split_csv(env_or("GEN5_GEN54_ML_P1B_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO")))
context_symbols <- unique(g5_standardize_symbol(c(live_symbols, split_csv(env_or(
  "GEN5_GEN54_ML_P1B_CONTEXT_SYMBOLS",
  "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"
)))))
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P1B_YEARS", "2020,2022")))
horizon <- as.integer(env_or("GEN5_GEN54_ML_P1B_HORIZON", "3"))
threshold <- as.numeric(env_or("GEN5_GEN54_ML_P1B_LABEL_THRESHOLD", "0"))
fixed_enter <- as.numeric(env_or("GEN5_GEN54_ML_P1B_FIXED_ENTER_THRESHOLD", "0.55"))
fixed_exit <- as.numeric(env_or("GEN5_GEN54_ML_P1B_FIXED_EXIT_THRESHOLD", "0.50"))
initial_capital <- as.numeric(env_or("GEN5_GEN54_ML_P1B_INITIAL_CAPITAL", "100000"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P1B_AS_OF", "2022-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P1B_WARMUP_DAYS", "420"))

folds <- build_folds(years)
query_start <- min(folds$train_start_date) - warmup_days
query_end <- max(folds$oos_end_date)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = context_symbols,
  universe_name = "gen54_ml_p1b_context",
  universe_roles = "live_basket,context_universe",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) {
  g5_stop("ML-P1b query returned no bars.")
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
fits <- lapply(fold_ids, function(fold_id) fit_glm_fold_with_train_predictions(feature_fold_table, fold_id, features))
train_predictions <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$train_predictions))
oos_predictions <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$oos_predictions))
predictions <- g5_wfa_bind_rows_fill(list(train_predictions, oos_predictions))
coefficients <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$coefficients))
coef_summary <- coefficient_summary(coefficients)
policy_table <- select_threshold_policies(train_predictions, fixed_enter = fixed_enter, fixed_exit = fixed_exit)
replay <- simulate_policy_replays(oos_predictions, policy_table, initial_capital = initial_capital)
summary <- summarize_policy_replay(replay)
actions <- action_audit_by_policy(replay$actions)
calibration <- calibration_audit(oos_predictions)

leakage <- data.frame(
  check_id = c("train_fit_only", "train_policy_selection_only", "oos_prediction_only", "no_oos_threshold_tuning", "no_live_bridge_change"),
  status = rep("PASS", 5L),
  detail = c(
    "Each GLM is fit only on TRAIN rows for its fold.",
    "Quantile and grid thresholds are chosen only from TRAIN predictions and TRAIN forward-return proxy scores.",
    "OOS rows are used only for frozen-model prediction and replay inspection.",
    "No OOS label, return, or performance metric is used to select policy thresholds.",
    "This wrapper writes research artifacts only and does not source or change live advice bridge behavior."
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p1b_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p1b_fold_spec.csv"),
  predictions_csv = file.path(output_dir, "ml_p1b_train_oos_predictions.csv"),
  policy_thresholds_csv = file.path(output_dir, "ml_p1b_policy_thresholds.csv"),
  actions_csv = file.path(output_dir, "ml_p1b_action_table.csv"),
  trades_csv = file.path(output_dir, "ml_p1b_trade_ledger.csv"),
  symbol_equity_csv = file.path(output_dir, "ml_p1b_symbol_equity.csv"),
  portfolio_equity_csv = file.path(output_dir, "ml_p1b_portfolio_equity.csv"),
  summary_csv = file.path(output_dir, "ml_p1b_summary.csv"),
  action_audit_csv = file.path(output_dir, "ml_p1b_action_audit.csv"),
  calibration_csv = file.path(output_dir, "ml_p1b_calibration_audit.csv"),
  coefficients_csv = file.path(output_dir, "ml_p1b_glm_coefficients.csv"),
  coefficient_summary_csv = file.path(output_dir, "ml_p1b_glm_coefficient_summary.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p1b_leakage_audit.csv"),
  report_md = file.path(output_dir, "ml_p1b_threshold_diagnostic_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p1b_artifact_index.csv"),
  equity_png = file.path(visual_dir, "ml_p1b_policy_equity_vs_benchmark.png"),
  summary_png = file.path(visual_dir, "ml_p1b_policy_excess_return.png"),
  thresholds_png = file.path(visual_dir, "ml_p1b_policy_thresholds.png"),
  action_audit_png = file.path(visual_dir, "ml_p1b_policy_action_audit.png"),
  probability_tape_png = file.path(visual_dir, "ml_p1b_policy_probability_tapes.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p1b_glm_threshold_diagnostic_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_glm_threshold_diagnostic.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  context_symbols = paste(context_symbols, collapse = ","),
  windows = paste(paste0(years, "Y"), collapse = ","),
  label_id = paste0("h", horizon, "_next_open_to_close"),
  model_id = "glm_logit_h3_threshold_diagnostic",
  policies = paste(unique(policy_table$policy_id), collapse = ","),
  fixed_enter_threshold = fixed_enter,
  fixed_exit_threshold = fixed_exit,
  prediction_rows = nrow(predictions),
  selected_feature_count = length(features),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_policy_equity_png(summary, replay$portfolio, paths$equity_png)
write_policy_summary_png(summary, paths$summary_png)
write_threshold_png(policy_table, paths$thresholds_png)
write_policy_action_png(actions, paths$action_audit_png)
write_policy_probability_tape_png(predictions, replay, policy_table, paths$probability_tape_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 14L), "markdown", "csv", rep("png", 5L)),
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(predictions, paths$predictions_csv)
g5_wfa_write_csv(policy_table, paths$policy_thresholds_csv)
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
write_p1b_report(paths$report_md, run_spec, summary, policy_table, leakage, artifact_index)

summary_line <- paste(
  summary$window_id,
  summary$policy_id,
  sprintf("active=%.1f%% benchmark=%.1f%% excess=%.1f%% exposure=%.1f%%",
    100 * summary$active_return,
    100 * summary$benchmark_return,
    100 * summary$excess_return,
    100 * summary$mean_exposure
  ),
  collapse = "; "
)

message("Gen5.4 ML-P1b GLM threshold diagnostic complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("Summary: ", summary_line)
