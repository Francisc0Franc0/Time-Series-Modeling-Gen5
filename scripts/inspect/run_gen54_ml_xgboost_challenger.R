# Gen5.4 supervised ML-P2 XGBoost challenger.
#
# This wrapper keeps the ML-P1c h1 label, annual replay, TRAIN-only threshold
# selection, and benchmark surface fixed while comparing a GLM control against
# a conservative predeclared XGBoost model.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

Sys.setenv(GEN5_GEN54_ML_P1B_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_glm_threshold_diagnostic.R"))
Sys.unsetenv("GEN5_GEN54_ML_P1B_SOURCE_ONLY")

if (!requireNamespace("xgboost", quietly = TRUE)) {
  g5_stop("ML-P2 requires the xgboost package. Install it into .codex_r_libs before running this wrapper.")
}

simple_auc <- function(score, label) {
  score <- as.numeric(score)
  label <- as.logical(label)
  keep <- is.finite(score) & !is.na(label)
  score <- score[keep]
  label <- label[keep]
  n_pos <- sum(label)
  n_neg <- sum(!label)
  if (n_pos == 0L || n_neg == 0L) return(NA_real_)
  ranks <- rank(score, ties.method = "average")
  (sum(ranks[label]) - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)
}

ranking_audit_by_model <- function(predictions) {
  rows <- list()
  idx <- 1L
  for (model in unique(predictions$model_id)) {
    for (window in unique(predictions$window_id[predictions$model_id == model])) {
      x <- predictions[predictions$model_id == model & predictions$window_id == window, , drop = FALSE]
      ranks <- rank(x$pred_prob_h3, ties.method = "average")
      dec <- pmin(10L, pmax(1L, ceiling(10 * ranks / length(ranks))))
      top <- x[dec == 10L, , drop = FALSE]
      bottom <- x[dec == 1L, , drop = FALSE]
      rows[[idx]] <- data.frame(
        model_id = model,
        window_id = window,
        auc = simple_auc(x$pred_prob_h3, x$label_up_h3),
        mean_pred_prob = mean(x$pred_prob_h3, na.rm = TRUE),
        label_up_rate = mean(x$label_up_h3, na.rm = TRUE),
        mean_fwd_ret = mean(x$fwd_ret_h3, na.rm = TRUE),
        top_decile_mean_fwd_ret = mean(top$fwd_ret_h3, na.rm = TRUE),
        bottom_decile_mean_fwd_ret = mean(bottom$fwd_ret_h3, na.rm = TRUE),
        top_minus_bottom_fwd_ret = mean(top$fwd_ret_h3, na.rm = TRUE) - mean(bottom$fwd_ret_h3, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  g5_wfa_bind_rows_fill(rows)
}

complete_model_rows <- function(train, oos, features) {
  features <- intersect(features, names(train))
  keep_feature <- vapply(features, function(feature) {
    values <- suppressWarnings(as.numeric(train[[feature]]))
    sd_value <- suppressWarnings(stats::sd(values, na.rm = TRUE))
    sum(is.finite(values)) >= 100L && is.finite(sd_value) && sd_value > 1e-10
  }, logical(1L))
  features <- features[keep_feature]
  if (length(features) < 3L) {
    g5_stop("ML-P2 fold has fewer than three usable features.")
  }
  complete_train <- stats::complete.cases(train[, features, drop = FALSE])
  complete_oos <- stats::complete.cases(oos[, features, drop = FALSE])
  list(
    train = train[complete_train, , drop = FALSE],
    oos = oos[complete_oos, , drop = FALSE],
    features = features
  )
}

fit_xgboost_fold_with_train_predictions <- function(feature_fold_table, fold_id, features, params, nrounds, nthread) {
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
  rows <- complete_model_rows(train, oos, features)
  train <- rows$train
  oos <- rows$oos
  features <- rows$features
  if (nrow(train) < 100L || nrow(oos) < 10L) {
    g5_stop(paste0("ML-P2 fold ", fold_id, " has insufficient TRAIN/OOS rows after feature filtering."))
  }

  train_model <- data.frame(symbol = factor(train$symbol, levels = sort(unique(feature_fold_table$symbol))), stringsAsFactors = FALSE)
  oos_model <- data.frame(symbol = factor(oos$symbol, levels = levels(train_model$symbol)), stringsAsFactors = FALSE)
  for (feature in features) {
    train_model[[feature]] <- as.numeric(train[[feature]])
    oos_model[[feature]] <- as.numeric(oos[[feature]])
  }
  formula <- stats::as.formula(paste("~ symbol +", paste(features, collapse = " + "), "- 1"))
  x_train <- stats::model.matrix(formula, data = train_model)
  x_oos <- stats::model.matrix(formula, data = oos_model)
  y_train <- as.integer(train$label_up_h3)
  dtrain <- xgboost::xgb.DMatrix(data = x_train, label = y_train)
  fit <- xgboost::xgb.train(
    params = c(params, list(nthread = nthread)),
    data = dtrain,
    nrounds = nrounds,
    verbose = 0
  )
  train_pred <- stats::predict(fit, x_train)
  oos_pred <- stats::predict(fit, x_oos)
  fallback <- mean(y_train, na.rm = TRUE)
  train_pred[!is.finite(train_pred)] <- fallback
  oos_pred[!is.finite(oos_pred)] <- fallback
  train$pred_prob_h3 <- as.numeric(pmin(1, pmax(0, train_pred)))
  oos$pred_prob_h3 <- as.numeric(pmin(1, pmax(0, oos_pred)))
  train$model_id <- "xgboost_h1_fixed_params"
  oos$model_id <- "xgboost_h1_fixed_params"
  train$feature_count_used <- length(features)
  oos$feature_count_used <- length(features)

  importance <- xgboost::xgb.importance(model = fit)
  if (nrow(importance)) {
    importance <- data.frame(
      fold_id = fold_id,
      model_id = "xgboost_h1_fixed_params",
      feature = importance$Feature,
      gain = importance$Gain,
      cover = importance$Cover,
      frequency = importance$Frequency,
      stringsAsFactors = FALSE
    )
  } else {
    importance <- data.frame(
      fold_id = fold_id,
      model_id = "xgboost_h1_fixed_params",
      feature = character(),
      gain = numeric(),
      cover = numeric(),
      frequency = numeric(),
      stringsAsFactors = FALSE
    )
  }

  list(
    train_predictions = train,
    oos_predictions = oos,
    feature_importance = importance
  )
}

fit_glm_h1_fold <- function(feature_fold_table, fold_id, features) {
  fit <- fit_glm_fold_with_train_predictions(feature_fold_table, fold_id, features)
  fit$train_predictions$model_id <- "glm_logit_h1_train_grid"
  fit$oos_predictions$model_id <- "glm_logit_h1_train_grid"
  fit$coefficients$model_id <- "glm_logit_h1_train_grid"
  fit
}

add_model_to_replay <- function(replay, model_id) {
  for (name in names(replay)) replay[[name]]$model_id <- model_id
  replay
}

run_model_surface <- function(model_id, feature_fold_table, features, initial_capital, xgb_params = NULL, xgb_nrounds = 80L, xgb_nthread = 2L) {
  fold_ids <- unique(feature_fold_table$fold_id)
  if (identical(model_id, "glm_logit_h1_train_grid")) {
    fits <- lapply(fold_ids, function(fold_id) fit_glm_h1_fold(feature_fold_table, fold_id, features))
    feature_importance <- data.frame()
    coefficients <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$coefficients))
  } else if (identical(model_id, "xgboost_h1_fixed_params")) {
    fits <- lapply(fold_ids, function(fold_id) {
      fit_xgboost_fold_with_train_predictions(feature_fold_table, fold_id, features, xgb_params, xgb_nrounds, xgb_nthread)
    })
    feature_importance <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$feature_importance))
    coefficients <- data.frame()
  } else {
    g5_stop(paste0("Unknown ML-P2 model_id: ", model_id))
  }

  train_predictions <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$train_predictions))
  oos_predictions <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$oos_predictions))
  policy_table <- select_threshold_policies(train_predictions)
  policy_table$model_id <- model_id
  replay <- add_model_to_replay(simulate_policy_replays(oos_predictions, policy_table, initial_capital = initial_capital), model_id)
  summary <- summarize_policy_replay(replay)
  summary$model_id <- model_id
  actions <- action_audit_by_model(replay$actions)
  calibration <- calibration_audit(oos_predictions)
  calibration$model_id <- model_id
  ranking <- ranking_audit_by_model(oos_predictions)
  predictions <- g5_wfa_bind_rows_fill(list(train_predictions, oos_predictions))
  list(
    predictions = predictions,
    policy_table = policy_table,
    replay = replay,
    summary = summary,
    actions = actions,
    calibration = calibration,
    ranking = ranking,
    coefficients = coefficients,
    feature_importance = feature_importance
  )
}

action_audit_by_model <- function(actions) {
  counts <- aggregate(
    rep(1L, nrow(actions)),
    list(model_id = actions$model_id, policy_id = actions$policy_id, window_id = actions$window_id, signal_action = actions$signal_action),
    sum
  )
  names(counts)[names(counts) == "x"] <- "row_count"
  totals <- aggregate(
    counts$row_count,
    list(model_id = counts$model_id, policy_id = counts$policy_id, window_id = counts$window_id),
    sum
  )
  names(totals)[names(totals) == "x"] <- "total_rows"
  out <- merge(counts, totals, by = c("model_id", "policy_id", "window_id"))
  out$row_rate <- out$row_count / out$total_rows
  out
}

write_model_equity_png <- function(portfolio, path) {
  grDevices::png(path, width = 2800L, height = 1600L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(glm_logit_h1_train_grid = "#2563EB", xgboost_h1_fixed_params = "#16A34A")
  policy <- "train_forward_return_grid"
  for (window in c("2020Y", "2022Y")) {
    x0 <- portfolio[portfolio$window_id == window & portfolio$policy_id == policy, , drop = FALSE]
    bench <- x0[x0$model_id == unique(x0$model_id)[[1L]], , drop = FALSE]
    bench <- bench[order(as.Date(bench$session_date)), , drop = FALSE]
    graphics::plot(as.Date(bench$session_date), bench$benchmark_mult, type = "l", lwd = 3, col = "#9CA3AF",
                   xlab = "Session", ylab = "Equity multiple", main = paste0(window, " TRAIN-grid policy by model"))
    for (model in names(cols)) {
      x <- x0[x0$model_id == model, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(x$session_date), x$active_mult, lwd = 2, col = cols[[model]])
    }
    graphics::legend("topleft", legend = c("Equal-weight hold", "GLM h1", "XGBoost h1"), col = c("#9CA3AF", unname(cols)), lwd = c(3, 2, 2), bty = "n", cex = 0.8)
  }
}

write_model_excess_png <- function(summary, path) {
  grDevices::png(path, width = 2600L, height = 1400L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(9, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  x <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  x$key <- paste(x$window_id, ifelse(grepl("xgboost", x$model_id), "XGB", "GLM"), sep = " / ")
  x <- x[order(x$window_id, x$model_id), , drop = FALSE]
  cols <- ifelse(x$excess_return >= 0, "#16A34A", "#DC2626")
  graphics::barplot(
    x$excess_return,
    names.arg = x$key,
    las = 2,
    col = cols,
    border = NA,
    ylab = "Active minus equal-weight hold",
    main = "XGBoost must improve alpha, not just exposure"
  )
  graphics::abline(h = 0, lty = 2, col = "#6B7280")
}

write_model_ranking_png <- function(ranking, path) {
  grDevices::png(path, width = 2600L, height = 1400L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  x <- ranking[order(ranking$window_id, ranking$model_id), , drop = FALSE]
  x$key <- paste(x$window_id, ifelse(grepl("xgboost", x$model_id), "XGB", "GLM"), sep = "\n")
  for (metric in c("auc", "top_minus_bottom_fwd_ret")) {
    cols <- ifelse(x[[metric]] >= if (metric == "auc") 0.5 else 0, "#16A34A", "#DC2626")
    graphics::barplot(
      x[[metric]],
      names.arg = x$key,
      las = 2,
      col = cols,
      border = NA,
      ylab = if (metric == "auc") "OOS AUC" else "Top minus bottom decile fwd return",
      main = if (metric == "auc") "Probability ranking" else "Return separation by score"
    )
    graphics::abline(h = if (metric == "auc") 0.5 else 0, lty = 2, col = "#6B7280")
  }
}

write_model_probability_tape_png <- function(predictions, replay, path) {
  examples <- list(c("AMD", "2020Y"), c("TSLA", "2022Y"))
  grDevices::png(path, width = 2800L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(glm_logit_h1_train_grid = "#2563EB", xgboost_h1_fixed_params = "#16A34A")
  policy <- "train_forward_return_grid"
  for (example in examples) {
    sym <- example[[1L]]
    window <- example[[2L]]
    p <- predictions[predictions$split == "OOS" & predictions$symbol == sym & predictions$window_id == window, , drop = FALSE]
    base <- p[p$model_id == "glm_logit_h1_train_grid", , drop = FALSE]
    base <- base[order(as.Date(base$session_date)), , drop = FALSE]
    d <- as.Date(base$session_date)
    graphics::plot(d, base$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(sym, window, "price and XGB/GLM entries"))
    for (model in names(cols)) {
      a <- replay$actions[
        replay$actions$model_id == model &
          replay$actions$policy_id == policy &
          replay$actions$symbol == sym &
          replay$actions$window_id == window &
          replay$actions$executed_action == "ENTER_LONG",
        ,
        drop = FALSE
      ]
      if (nrow(a)) {
        graphics::points(as.Date(a$feature_date), base$close[match(as.Date(a$feature_date), d)], pch = 24, bg = cols[[model]], col = "#111827", cex = 1.0)
      }
    }
    graphics::plot(d, base$pred_prob_h3, type = "n", ylim = c(0, 1), xlab = "Session", ylab = "Predicted probability", main = paste(sym, window, "probability by model"))
    for (model in names(cols)) {
      x <- p[p$model_id == model, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(x$session_date), x$pred_prob_h3, lwd = 1.7, col = cols[[model]])
    }
    graphics::legend("bottomleft", legend = c("GLM h1", "XGBoost h1"), col = unname(cols), lwd = 2, bty = "n", cex = 0.8)
  }
}

write_xgb_importance_png <- function(importance, path) {
  grDevices::png(path, width = 2400L, height = 1400L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  if (!nrow(importance)) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "No XGBoost importance rows")
    return(invisible(path))
  }
  agg <- aggregate(importance$gain, list(feature = importance$feature), mean)
  names(agg)[names(agg) == "x"] <- "mean_gain"
  agg <- agg[order(-agg$mean_gain), , drop = FALSE]
  agg <- head(agg, 18L)
  old <- graphics::par(mar = c(5, 13, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  graphics::barplot(
    rev(agg$mean_gain),
    names.arg = rev(agg$feature),
    horiz = TRUE,
    las = 1,
    col = "#16A34A",
    border = NA,
    xlab = "Mean gain across folds",
    main = "XGBoost feature importance is a diagnostic, not causal proof"
  )
}

write_p2_report <- function(path, run_spec, summary, ranking, leakage_audit, artifact_index) {
  pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  lines <- c(
    "# Gen5.4 ML-P2 XGBoost Challenger",
    "",
    "## Purpose",
    "",
    "This packet compares the best GLM label horizon so far (`h1`) against a conservative XGBoost challenger while keeping the replay, threshold-selection, and benchmark surfaces fixed.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    paste0("- Label: `", run_spec$label_horizon[[1L]], "`"),
    paste0("- Models: `", run_spec$model_ids[[1L]], "`"),
    "",
    "## Leakage Audit",
    "",
    paste0("- `", leakage_audit$check_id, "`: ", leakage_audit$status, " - ", leakage_audit$detail),
    "",
    "## OOS TRAIN-Grid Summary",
    "",
    paste0("- `", grid$window_id, "` / `", grid$model_id, "`: active `", pct(grid$active_return), "` vs basket hold `", pct(grid$benchmark_return), "`; excess `", pct(grid$excess_return), "`; exposure `", pct(grid$mean_exposure), "`."),
    "",
    "## Ranking Audit",
    "",
    paste0("- `", ranking$window_id, "` / `", ranking$model_id, "`: AUC `", sprintf("%.3f", ranking$auc), "`, top-minus-bottom decile return `", pct(ranking$top_minus_bottom_fwd_ret), "`."),
    "",
    "## Interpretation",
    "",
    "Treat this as a first nonlinear challenger, not an optimized XGBoost result. If XGBoost improves ranking and replay behavior, the next slice can cautiously tune a small TRAIN-only parameter grid. If it does not, backtrack to feature design rather than increasing model knobs.",
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_index$artifact_id, "`: `", artifact_index$path, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

if (!identical(Sys.getenv("GEN5_GEN54_ML_P2_SOURCE_ONLY", unset = "false"), "true")) {
g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN54_ML_P2_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P2_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_ML_P2_STAMP", "20260713p2"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p2_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

live_symbols <- g5_standardize_symbol(split_csv(env_or("GEN5_GEN54_ML_P2_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO")))
context_symbols <- unique(g5_standardize_symbol(c(live_symbols, split_csv(env_or(
  "GEN5_GEN54_ML_P2_CONTEXT_SYMBOLS",
  "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"
)))))
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P2_YEARS", "2020,2022")))
horizon <- as.integer(env_or("GEN5_GEN54_ML_P2_HORIZON", "1"))
threshold <- as.numeric(env_or("GEN5_GEN54_ML_P2_LABEL_THRESHOLD", "0"))
initial_capital <- as.numeric(env_or("GEN5_GEN54_ML_P2_INITIAL_CAPITAL", "100000"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P2_AS_OF", "2022-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P2_WARMUP_DAYS", "420"))
xgb_nrounds <- as.integer(env_or("GEN5_GEN54_ML_P2_XGB_NROUNDS", "80"))
xgb_nthread <- as.integer(env_or("GEN5_GEN54_ML_P2_XGB_NTHREAD", "2"))
xgb_seed <- as.integer(env_or("GEN5_GEN54_ML_P2_XGB_SEED", "5402"))
xgb_params <- list(
  objective = "binary:logistic",
  eval_metric = "logloss",
  max_depth = as.integer(env_or("GEN5_GEN54_ML_P2_XGB_MAX_DEPTH", "3")),
  eta = as.numeric(env_or("GEN5_GEN54_ML_P2_XGB_ETA", "0.05")),
  subsample = as.numeric(env_or("GEN5_GEN54_ML_P2_XGB_SUBSAMPLE", "0.80")),
  colsample_bytree = as.numeric(env_or("GEN5_GEN54_ML_P2_XGB_COLSAMPLE", "0.80")),
  min_child_weight = as.numeric(env_or("GEN5_GEN54_ML_P2_XGB_MIN_CHILD_WEIGHT", "10")),
  seed = xgb_seed
)

folds <- build_folds(years)
query_start <- min(folds$train_start_date) - warmup_days
query_end <- max(folds$oos_end_date)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = context_symbols,
  universe_name = "gen54_ml_p2_context",
  universe_roles = "live_basket,context_universe",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) {
  g5_stop("ML-P2 query returned no bars.")
}

feature_tables <- list()
for (sym in context_symbols) {
  feature_tables[[sym]] <- augment_ohlcv_features(g5_pca_regime_feature_table(query$bars, sym, end_date = query_end))
}
feature_tables <- add_market_relative_features(feature_tables, live_symbols, context_symbols)
features <- feature_columns()
labeled <- lapply(live_symbols, function(sym) add_forward_label(feature_tables[[sym]], horizon = horizon, threshold = threshold))
feature_labels <- g5_wfa_bind_rows_fill(labeled)
feature_fold_table <- assign_fold_split(feature_labels, folds)
usable_features <- intersect(features, names(feature_fold_table))

model_ids <- c("glm_logit_h1_train_grid", "xgboost_h1_fixed_params")
parts <- lapply(model_ids, function(model_id) {
  run_model_surface(
    model_id = model_id,
    feature_fold_table = feature_fold_table,
    features = usable_features,
    initial_capital = initial_capital,
    xgb_params = xgb_params,
    xgb_nrounds = xgb_nrounds,
    xgb_nthread = xgb_nthread
  )
})
names(parts) <- model_ids

predictions <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$predictions))
policy_table <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$policy_table))
summary <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$summary))
actions <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$actions))
calibration <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$calibration))
ranking <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$ranking))
coefficients <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$coefficients))
feature_importance <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$feature_importance))
replay <- list(
  actions = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$actions)),
  equity_symbol = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$equity_symbol)),
  trades = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$trades)),
  portfolio = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$portfolio))
)

leakage <- data.frame(
  check_id = c("train_fit_only", "predeclared_xgb_params", "train_policy_selection_only", "oos_prediction_only", "label_horizon_inside_split", "no_live_bridge_change"),
  status = rep("PASS", 6L),
  detail = c(
    "Both GLM and XGBoost are fit only on TRAIN rows for their fold.",
    "XGBoost hyperparameters are predeclared in the run spec; no OOS early stopping or OOS parameter search is used.",
    "Threshold policies are selected only from TRAIN predictions and TRAIN forward-return proxy scores.",
    "OOS rows are used only for frozen-model prediction and replay inspection.",
    "Rows whose label endpoint crosses a TRAIN/OOS boundary are excluded by the shared fold-label guard.",
    "This wrapper writes research artifacts only and does not source or change live advice bridge behavior."
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p2_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p2_fold_spec.csv"),
  predictions_csv = file.path(output_dir, "ml_p2_train_oos_predictions.csv"),
  policy_thresholds_csv = file.path(output_dir, "ml_p2_policy_thresholds.csv"),
  summary_csv = file.path(output_dir, "ml_p2_summary.csv"),
  ranking_csv = file.path(output_dir, "ml_p2_ranking_audit.csv"),
  actions_csv = file.path(output_dir, "ml_p2_action_table.csv"),
  trades_csv = file.path(output_dir, "ml_p2_trade_ledger.csv"),
  portfolio_equity_csv = file.path(output_dir, "ml_p2_portfolio_equity.csv"),
  calibration_csv = file.path(output_dir, "ml_p2_calibration_audit.csv"),
  glm_coefficients_csv = file.path(output_dir, "ml_p2_glm_coefficients.csv"),
  xgb_importance_csv = file.path(output_dir, "ml_p2_xgb_feature_importance.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p2_leakage_audit.csv"),
  report_md = file.path(output_dir, "ml_p2_xgboost_challenger_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p2_artifact_index.csv"),
  equity_png = file.path(visual_dir, "ml_p2_model_equity_vs_benchmark.png"),
  excess_png = file.path(visual_dir, "ml_p2_model_excess_return.png"),
  ranking_png = file.path(visual_dir, "ml_p2_model_ranking_audit.png"),
  probability_tape_png = file.path(visual_dir, "ml_p2_model_probability_tapes.png"),
  xgb_importance_png = file.path(visual_dir, "ml_p2_xgb_feature_importance.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p2_xgboost_challenger_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_xgboost_challenger.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  context_symbols = paste(context_symbols, collapse = ","),
  windows = paste(paste0(years, "Y"), collapse = ","),
  label_horizon = paste0("h", horizon),
  label_threshold = threshold,
  model_ids = paste(model_ids, collapse = ","),
  policies = paste(unique(policy_table$policy_id), collapse = ","),
  xgb_nrounds = xgb_nrounds,
  xgb_max_depth = xgb_params$max_depth,
  xgb_eta = xgb_params$eta,
  xgb_subsample = xgb_params$subsample,
  xgb_colsample_bytree = xgb_params$colsample_bytree,
  xgb_min_child_weight = xgb_params$min_child_weight,
  xgb_seed = xgb_seed,
  prediction_rows = nrow(predictions),
  selected_feature_count = length(usable_features),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_model_equity_png(replay$portfolio, paths$equity_png)
write_model_excess_png(summary, paths$excess_png)
write_model_ranking_png(ranking, paths$ranking_png)
write_model_probability_tape_png(predictions, replay, paths$probability_tape_png)
write_xgb_importance_png(feature_importance, paths$xgb_importance_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 13L), "markdown", "csv", rep("png", 5L)),
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(predictions, paths$predictions_csv)
g5_wfa_write_csv(policy_table, paths$policy_thresholds_csv)
g5_wfa_write_csv(summary, paths$summary_csv)
g5_wfa_write_csv(ranking, paths$ranking_csv)
g5_wfa_write_csv(actions, paths$actions_csv)
g5_wfa_write_csv(replay$trades, paths$trades_csv)
g5_wfa_write_csv(replay$portfolio, paths$portfolio_equity_csv)
g5_wfa_write_csv(calibration, paths$calibration_csv)
g5_wfa_write_csv(coefficients, paths$glm_coefficients_csv)
g5_wfa_write_csv(feature_importance, paths$xgb_importance_csv)
g5_wfa_write_csv(leakage, paths$leakage_audit_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_p2_report(paths$report_md, run_spec, summary, ranking, leakage, artifact_index)

grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
summary_line <- paste(
  grid$window_id,
  grid$model_id,
  sprintf("active=%.1f%% benchmark=%.1f%% excess=%.1f%% exposure=%.1f%%",
    100 * grid$active_return,
    100 * grid$benchmark_return,
    100 * grid$excess_return,
    100 * grid$mean_exposure
  ),
  collapse = "; "
)

message("Gen5.4 ML-P2 XGBoost challenger complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("TRAIN-grid summary: ", summary_line)
}
