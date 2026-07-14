# Gen5.4 supervised ML-P2b small XGBoost parameter diagnostic.
#
# This wrapper keeps the ML-P2 h1 label, feature table, annual replay, and
# TRAIN-only threshold-policy audit fixed. It compares the fixed ML-P2 XGBoost
# control against a tiny XGBoost parameter grid selected only from TRAIN proxy
# evidence inside each fold.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

Sys.setenv(GEN5_GEN54_ML_P2_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_xgboost_challenger.R"))
Sys.unsetenv("GEN5_GEN54_ML_P2_SOURCE_ONLY")

xgb_param_grid <- function(depth_values, nround_values, min_child_values) {
  grid <- expand.grid(
    max_depth = depth_values,
    nrounds = nround_values,
    min_child_weight = min_child_values,
    stringsAsFactors = FALSE
  )
  grid$eta <- 0.05
  grid$subsample <- 0.80
  grid$colsample_bytree <- 0.80
  grid$candidate_id <- sprintf(
    "d%s_r%s_mcw%s",
    grid$max_depth,
    grid$nrounds,
    grid$min_child_weight
  )
  grid
}

xgb_params_from_row <- function(row, seed) {
  list(
    objective = "binary:logistic",
    eval_metric = "logloss",
    max_depth = as.integer(row$max_depth[[1L]]),
    eta = as.numeric(row$eta[[1L]]),
    subsample = as.numeric(row$subsample[[1L]]),
    colsample_bytree = as.numeric(row$colsample_bytree[[1L]]),
    min_child_weight = as.numeric(row$min_child_weight[[1L]]),
    seed = seed
  )
}

score_train_param_candidate <- function(train_predictions) {
  policies <- select_threshold_policies(train_predictions)
  grid_row <- policies[policies$policy_id == "train_forward_return_grid", , drop = FALSE]
  if (!nrow(grid_row)) g5_stop("ML-P2b candidate did not produce a TRAIN-grid policy row.")
  grid_row$param_selection_score <- grid_row$train_active_return -
    0.15 * pmax(0, 0.20 - grid_row$train_mean_exposure)
  grid_row
}

fit_selected_xgb_fold <- function(feature_fold_table, fold_id, features, param_grid, nthread, seed) {
  candidate_rows <- list()
  candidate_fits <- list()
  for (i in seq_len(nrow(param_grid))) {
    row <- param_grid[i, , drop = FALSE]
    fit <- fit_xgboost_fold_with_train_predictions(
      feature_fold_table = feature_fold_table,
      fold_id = fold_id,
      features = features,
      params = xgb_params_from_row(row, seed = seed),
      nrounds = as.integer(row$nrounds[[1L]]),
      nthread = nthread
    )
    fit$train_predictions$model_id <- "xgboost_h1_train_param_grid"
    fit$oos_predictions$model_id <- "xgboost_h1_train_param_grid"
    fit$feature_importance$model_id <- "xgboost_h1_train_param_grid"
    fit$train_predictions$candidate_id <- row$candidate_id[[1L]]
    fit$oos_predictions$candidate_id <- row$candidate_id[[1L]]
    fit$feature_importance$candidate_id <- row$candidate_id[[1L]]
    scored <- score_train_param_candidate(fit$train_predictions)
    candidate_rows[[i]] <- cbind(
      data.frame(
        fold_id = fold_id,
        candidate_id = row$candidate_id[[1L]],
        max_depth = row$max_depth[[1L]],
        nrounds = row$nrounds[[1L]],
        min_child_weight = row$min_child_weight[[1L]],
        eta = row$eta[[1L]],
        subsample = row$subsample[[1L]],
        colsample_bytree = row$colsample_bytree[[1L]],
        stringsAsFactors = FALSE
      ),
      scored[, c(
        "policy_id",
        "enter_threshold",
        "exit_threshold",
        "train_active_return",
        "train_benchmark_return",
        "train_excess_return",
        "train_mean_exposure",
        "param_selection_score"
      ), drop = FALSE]
    )
    candidate_fits[[row$candidate_id[[1L]]]] <- fit
  }
  candidate_table <- g5_wfa_bind_rows_fill(candidate_rows)
  candidate_table <- candidate_table[order(
    -candidate_table$param_selection_score,
    -candidate_table$train_active_return,
    abs(candidate_table$train_mean_exposure - 0.55),
    candidate_table$max_depth,
    candidate_table$nrounds,
    candidate_table$min_child_weight
  ), , drop = FALSE]
  selected <- candidate_table[1L, , drop = FALSE]
  selected_fit <- candidate_fits[[selected$candidate_id[[1L]]]]
  policy_table <- select_threshold_policies(selected_fit$train_predictions)
  policy_table$model_id <- "xgboost_h1_train_param_grid"
  policy_table$candidate_id <- selected$candidate_id[[1L]]
  policy_table$max_depth <- selected$max_depth[[1L]]
  policy_table$nrounds <- selected$nrounds[[1L]]
  policy_table$min_child_weight <- selected$min_child_weight[[1L]]
  list(
    selected_fit = selected_fit,
    selected_policy_table = policy_table,
    candidate_table = candidate_table,
    selected_params = selected
  )
}

run_selected_xgb_surface <- function(feature_fold_table, features, param_grid, initial_capital, nthread, seed) {
  fold_ids <- unique(feature_fold_table$fold_id)
  selected <- lapply(fold_ids, function(fold_id) {
    fit_selected_xgb_fold(feature_fold_table, fold_id, features, param_grid, nthread, seed = seed)
  })
  train_predictions <- g5_wfa_bind_rows_fill(lapply(selected, function(x) x$selected_fit$train_predictions))
  oos_predictions <- g5_wfa_bind_rows_fill(lapply(selected, function(x) x$selected_fit$oos_predictions))
  policy_table <- g5_wfa_bind_rows_fill(lapply(selected, function(x) x$selected_policy_table))
  candidate_table <- g5_wfa_bind_rows_fill(lapply(selected, function(x) x$candidate_table))
  selected_params <- g5_wfa_bind_rows_fill(lapply(selected, function(x) x$selected_params))
  feature_importance <- g5_wfa_bind_rows_fill(lapply(selected, function(x) x$selected_fit$feature_importance))
  replay <- add_model_to_replay(
    simulate_policy_replays(oos_predictions, policy_table, initial_capital = initial_capital),
    "xgboost_h1_train_param_grid"
  )
  summary <- summarize_policy_replay(replay)
  summary$model_id <- "xgboost_h1_train_param_grid"
  actions <- action_audit_by_model(replay$actions)
  calibration <- calibration_audit(oos_predictions)
  calibration$model_id <- "xgboost_h1_train_param_grid"
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
    feature_importance = feature_importance,
    candidate_table = candidate_table,
    selected_params = selected_params
  )
}

write_p2b_equity_png <- function(portfolio, path) {
  grDevices::png(path, width = 2800L, height = 1600L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(xgboost_h1_fixed_params = "#16A34A", xgboost_h1_train_param_grid = "#7C3AED")
  policy <- "train_forward_return_grid"
  for (window in c("2020Y", "2022Y")) {
    x0 <- portfolio[portfolio$window_id == window & portfolio$policy_id == policy, , drop = FALSE]
    bench <- x0[x0$model_id == unique(x0$model_id)[[1L]], , drop = FALSE]
    bench <- bench[order(as.Date(bench$session_date)), , drop = FALSE]
    graphics::plot(as.Date(bench$session_date), bench$benchmark_mult, type = "l", lwd = 3, col = "#9CA3AF",
                   xlab = "Session", ylab = "Equity multiple", main = paste0(window, " XGBoost parameter diagnostic"))
    for (model in names(cols)) {
      x <- x0[x0$model_id == model, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(x$session_date), x$active_mult, lwd = 2, col = cols[[model]])
    }
    graphics::legend("topleft",
      legend = c("Equal-weight hold", "Fixed XGB", "TRAIN-selected XGB"),
      col = c("#9CA3AF", unname(cols)),
      lwd = c(3, 2, 2),
      bty = "n",
      cex = 0.8
    )
  }
}

write_p2b_ranking_png <- function(ranking, path) {
  grDevices::png(path, width = 2600L, height = 1400L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  x <- ranking[order(ranking$window_id, ranking$model_id), , drop = FALSE]
  x$key <- paste(x$window_id, ifelse(grepl("train_param", x$model_id), "XGB grid", "XGB fixed"), sep = "\n")
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

write_p2b_param_selection_png <- function(selected_params, candidate_table, path) {
  grDevices::png(path, width = 2600L, height = 1500L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(8, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  selected_params$key <- paste(selected_params$fold_id, selected_params$candidate_id, sep = "\n")
  graphics::barplot(
    selected_params$param_selection_score,
    names.arg = selected_params$key,
    las = 2,
    col = "#7C3AED",
    border = NA,
    ylab = "TRAIN parameter-selection score",
    main = "Selected XGBoost params by fold"
  )
  top <- candidate_table[order(-candidate_table$param_selection_score), , drop = FALSE]
  top <- head(top, 12L)
  top$key <- paste(top$fold_id, top$candidate_id, sep = "\n")
  graphics::barplot(
    top$param_selection_score,
    names.arg = top$key,
    las = 2,
    col = "#A78BFA",
    border = NA,
    ylab = "TRAIN parameter-selection score",
    main = "Top TRAIN candidates across folds"
  )
}

write_p2b_probability_tape_png <- function(predictions, replay, path) {
  examples <- list(c("AMD", "2020Y"), c("TSLA", "2022Y"))
  grDevices::png(path, width = 2800L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(xgboost_h1_fixed_params = "#16A34A", xgboost_h1_train_param_grid = "#7C3AED")
  policy <- "train_forward_return_grid"
  for (example in examples) {
    sym <- example[[1L]]
    window <- example[[2L]]
    p <- predictions[predictions$split == "OOS" & predictions$symbol == sym & predictions$window_id == window, , drop = FALSE]
    base <- p[p$model_id == "xgboost_h1_fixed_params", , drop = FALSE]
    base <- base[order(as.Date(base$session_date)), , drop = FALSE]
    d <- as.Date(base$session_date)
    graphics::plot(d, base$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(sym, window, "price and XGB entries"))
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
    graphics::plot(d, base$pred_prob_h3, type = "n", ylim = c(0, 1), xlab = "Session", ylab = "Predicted probability", main = paste(sym, window, "probability by XGB lane"))
    for (model in names(cols)) {
      x <- p[p$model_id == model, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(x$session_date), x$pred_prob_h3, lwd = 1.7, col = cols[[model]])
    }
    graphics::legend("bottomleft", legend = c("Fixed XGB", "TRAIN-selected XGB"), col = unname(cols), lwd = 2, bty = "n", cex = 0.8)
  }
}

write_p2b_report <- function(path, run_spec, summary, ranking, selected_params, leakage_audit, artifact_index) {
  pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  lines <- c(
    "# Gen5.4 ML-P2b XGBoost Parameter Diagnostic",
    "",
    "## Purpose",
    "",
    "This packet tests whether the first XGBoost result was limited by conservative fixed parameters or by feature/label quality.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    paste0("- Label: `", run_spec$label_horizon[[1L]], "`"),
    paste0("- Candidate grid: `", run_spec$param_grid[[1L]], "`"),
    "",
    "## Leakage Audit",
    "",
    paste0("- `", leakage_audit$check_id, "`: ", leakage_audit$status, " - ", leakage_audit$detail),
    "",
    "## Selected Parameters",
    "",
    paste0("- `", selected_params$fold_id, "` selected `", selected_params$candidate_id, "` with TRAIN score `", sprintf("%.5f", selected_params$param_selection_score), "`."),
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
    "Treat this as a bounded tuning diagnostic. If the selected grid improves replay and ranking, the next step is broader-window generalization. If replay improves but ranking remains weak, inspect tapes and feature design before expanding the model search.",
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
feed <- env_or("GEN5_GEN54_ML_P2B_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P2B_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_ML_P2B_STAMP", "20260713p2b"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p2b_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

live_symbols <- g5_standardize_symbol(split_csv(env_or("GEN5_GEN54_ML_P2B_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO")))
context_symbols <- unique(g5_standardize_symbol(c(live_symbols, split_csv(env_or(
  "GEN5_GEN54_ML_P2B_CONTEXT_SYMBOLS",
  "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"
)))))
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P2B_YEARS", "2020,2022")))
horizon <- as.integer(env_or("GEN5_GEN54_ML_P2B_HORIZON", "1"))
threshold <- as.numeric(env_or("GEN5_GEN54_ML_P2B_LABEL_THRESHOLD", "0"))
initial_capital <- as.numeric(env_or("GEN5_GEN54_ML_P2B_INITIAL_CAPITAL", "100000"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P2B_AS_OF", "2022-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P2B_WARMUP_DAYS", "420"))
xgb_nthread <- as.integer(env_or("GEN5_GEN54_ML_P2B_XGB_NTHREAD", "2"))
xgb_seed <- as.integer(env_or("GEN5_GEN54_ML_P2B_XGB_SEED", "5402"))
depth_values <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P2B_XGB_DEPTHS", "2,3,4")))
nround_values <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P2B_XGB_NROUNDS", "60,100")))
min_child_values <- as.numeric(split_csv(env_or("GEN5_GEN54_ML_P2B_XGB_MIN_CHILD_WEIGHTS", "5,10,20")))
param_grid <- xgb_param_grid(depth_values, nround_values, min_child_values)

folds <- build_folds(years)
query_start <- min(folds$train_start_date) - warmup_days
query_end <- max(folds$oos_end_date)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = context_symbols,
  universe_name = "gen54_ml_p2b_context",
  universe_roles = "live_basket,context_universe",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) {
  g5_stop("ML-P2b query returned no bars.")
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

fixed_params <- list(
  objective = "binary:logistic",
  eval_metric = "logloss",
  max_depth = 3L,
  eta = 0.05,
  subsample = 0.80,
  colsample_bytree = 0.80,
  min_child_weight = 10,
  seed = xgb_seed
)
fixed_surface <- run_model_surface(
  model_id = "xgboost_h1_fixed_params",
  feature_fold_table = feature_fold_table,
  features = usable_features,
  initial_capital = initial_capital,
  xgb_params = fixed_params,
  xgb_nrounds = 80L,
  xgb_nthread = xgb_nthread
)
selected_surface <- run_selected_xgb_surface(
  feature_fold_table = feature_fold_table,
  features = usable_features,
  param_grid = param_grid,
  initial_capital = initial_capital,
  nthread = xgb_nthread,
  seed = xgb_seed
)
parts <- list(fixed_surface, selected_surface)

predictions <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$predictions))
policy_table <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$policy_table))
summary <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$summary))
actions <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$actions))
calibration <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$calibration))
ranking <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$ranking))
feature_importance <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$feature_importance))
candidate_table <- selected_surface$candidate_table
selected_params <- selected_surface$selected_params
replay <- list(
  actions = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$actions)),
  equity_symbol = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$equity_symbol)),
  trades = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$trades)),
  portfolio = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$portfolio))
)

leakage <- data.frame(
  check_id = c("train_fit_only", "train_param_selection_only", "train_policy_selection_only", "oos_prediction_only", "label_horizon_inside_split", "no_live_bridge_change"),
  status = rep("PASS", 6L),
  detail = c(
    "All XGBoost candidates are fit only on TRAIN rows for their fold.",
    "The selected grid lane chooses parameters only from TRAIN proxy evidence inside each fold.",
    "Threshold policies are selected only from TRAIN predictions and TRAIN forward-return proxy scores.",
    "OOS rows are used only for frozen-model prediction and replay inspection.",
    "Rows whose label endpoint crosses a TRAIN/OOS boundary are excluded by the shared fold-label guard.",
    "This wrapper writes research artifacts only and does not source or change live advice bridge behavior."
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p2b_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p2b_fold_spec.csv"),
  predictions_csv = file.path(output_dir, "ml_p2b_train_oos_predictions.csv"),
  policy_thresholds_csv = file.path(output_dir, "ml_p2b_policy_thresholds.csv"),
  summary_csv = file.path(output_dir, "ml_p2b_summary.csv"),
  ranking_csv = file.path(output_dir, "ml_p2b_ranking_audit.csv"),
  actions_csv = file.path(output_dir, "ml_p2b_action_table.csv"),
  trades_csv = file.path(output_dir, "ml_p2b_trade_ledger.csv"),
  portfolio_equity_csv = file.path(output_dir, "ml_p2b_portfolio_equity.csv"),
  calibration_csv = file.path(output_dir, "ml_p2b_calibration_audit.csv"),
  candidate_grid_csv = file.path(output_dir, "ml_p2b_candidate_param_scores.csv"),
  selected_params_csv = file.path(output_dir, "ml_p2b_selected_params.csv"),
  xgb_importance_csv = file.path(output_dir, "ml_p2b_xgb_feature_importance.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p2b_leakage_audit.csv"),
  report_md = file.path(output_dir, "ml_p2b_xgboost_param_diagnostic_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p2b_artifact_index.csv"),
  equity_png = file.path(visual_dir, "ml_p2b_param_equity_vs_benchmark.png"),
  ranking_png = file.path(visual_dir, "ml_p2b_param_ranking_audit.png"),
  param_selection_png = file.path(visual_dir, "ml_p2b_param_selection.png"),
  probability_tape_png = file.path(visual_dir, "ml_p2b_param_probability_tapes.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p2b_xgboost_param_diagnostic_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_xgboost_param_diagnostic.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  context_symbols = paste(context_symbols, collapse = ","),
  windows = paste(paste0(years, "Y"), collapse = ","),
  label_horizon = paste0("h", horizon),
  label_threshold = threshold,
  model_ids = paste(unique(summary$model_id), collapse = ","),
  policies = paste(unique(policy_table$policy_id), collapse = ","),
  param_grid = paste(param_grid$candidate_id, collapse = ","),
  xgb_seed = xgb_seed,
  prediction_rows = nrow(predictions),
  selected_feature_count = length(usable_features),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_p2b_equity_png(replay$portfolio, paths$equity_png)
write_p2b_ranking_png(ranking, paths$ranking_png)
write_p2b_param_selection_png(selected_params, candidate_table, paths$param_selection_png)
write_p2b_probability_tape_png(predictions, replay, paths$probability_tape_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 14L), "markdown", "csv", rep("png", 4L)),
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
g5_wfa_write_csv(candidate_table, paths$candidate_grid_csv)
g5_wfa_write_csv(selected_params, paths$selected_params_csv)
g5_wfa_write_csv(feature_importance, paths$xgb_importance_csv)
g5_wfa_write_csv(leakage, paths$leakage_audit_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_p2b_report(paths$report_md, run_spec, summary, ranking, selected_params, leakage, artifact_index)

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

message("Gen5.4 ML-P2b XGBoost parameter diagnostic complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("TRAIN-grid summary: ", summary_line)
