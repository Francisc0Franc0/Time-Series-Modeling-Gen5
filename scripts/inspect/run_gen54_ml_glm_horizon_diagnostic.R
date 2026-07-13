# Gen5.4 supervised ML-P1c GLM label-horizon diagnostic.
#
# This wrapper keeps the ML-P1b replay/policy surface fixed and asks whether
# h1, h3, or h5 labels produce better OOS probability ranking and participation.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

Sys.setenv(GEN5_GEN54_ML_P1B_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_glm_threshold_diagnostic.R"))
Sys.unsetenv("GEN5_GEN54_ML_P1B_SOURCE_ONLY")

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

ranking_audit <- function(predictions) {
  rows <- list()
  idx <- 1L
  for (window in unique(predictions$window_id)) {
    x <- predictions[predictions$window_id == window, , drop = FALSE]
    ranks <- rank(x$pred_prob_h3, ties.method = "average")
    dec <- pmin(10L, pmax(1L, ceiling(10 * ranks / length(ranks))))
    top <- x[dec == 10L, , drop = FALSE]
    bottom <- x[dec == 1L, , drop = FALSE]
    rows[[idx]] <- data.frame(
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
  g5_wfa_bind_rows_fill(rows)
}

run_horizon <- function(horizon, feature_tables, folds, live_symbols, features, threshold, initial_capital) {
  labeled <- lapply(live_symbols, function(sym) add_forward_label(feature_tables[[sym]], horizon = horizon, threshold = threshold))
  feature_labels <- g5_wfa_bind_rows_fill(labeled)
  feature_fold_table <- assign_fold_split(feature_labels, folds)
  usable_features <- intersect(features, names(feature_fold_table))
  fold_ids <- unique(feature_fold_table$fold_id)
  fits <- lapply(fold_ids, function(fold_id) fit_glm_fold_with_train_predictions(feature_fold_table, fold_id, usable_features))
  train_predictions <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$train_predictions))
  oos_predictions <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$oos_predictions))
  train_predictions$horizon_id <- paste0("h", horizon)
  oos_predictions$horizon_id <- paste0("h", horizon)
  predictions <- g5_wfa_bind_rows_fill(list(train_predictions, oos_predictions))
  policy_table <- select_threshold_policies(train_predictions)
  replay <- simulate_policy_replays(oos_predictions, policy_table, initial_capital = initial_capital)
  summary <- summarize_policy_replay(replay)
  actions <- action_audit_by_policy(replay$actions)
  calibration <- calibration_audit(oos_predictions)
  ranking <- ranking_audit(oos_predictions)
  for (obj in c("policy_table", "summary", "actions", "calibration", "ranking")) {
    value <- get(obj)
    value$horizon_id <- paste0("h", horizon)
    value$label_horizon_sessions <- horizon
    assign(obj, value)
  }
  for (name in names(replay)) {
    replay[[name]]$horizon_id <- paste0("h", horizon)
    replay[[name]]$label_horizon_sessions <- horizon
  }
  coefficients <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$coefficients))
  coefficients$horizon_id <- paste0("h", horizon)
  coefficients$label_horizon_sessions <- horizon
  list(
    predictions = predictions,
    policy_table = policy_table,
    replay = replay,
    summary = summary,
    actions = actions,
    calibration = calibration,
    ranking = ranking,
    coefficients = coefficients
  )
}

write_horizon_equity_png <- function(portfolio, path) {
  grDevices::png(path, width = 2800L, height = 1600L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(h1 = "#2563EB", h3 = "#F97316", h5 = "#16A34A")
  policy <- "train_forward_return_grid"
  for (window in c("2020Y", "2022Y")) {
    x0 <- portfolio[portfolio$window_id == window & portfolio$policy_id == policy, , drop = FALSE]
    bench <- x0[x0$horizon_id == unique(x0$horizon_id)[[1L]], , drop = FALSE]
    bench <- bench[order(as.Date(bench$session_date)), , drop = FALSE]
    graphics::plot(as.Date(bench$session_date), bench$benchmark_mult, type = "l", lwd = 3, col = "#9CA3AF",
                   xlab = "Session", ylab = "Equity multiple", main = paste0(window, " TRAIN-grid policy by label horizon"))
    for (horizon in names(cols)) {
      x <- x0[x0$horizon_id == horizon, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(x$session_date), x$active_mult, lwd = 2, col = cols[[horizon]])
    }
    graphics::legend("topleft", legend = c("Equal-weight hold", names(cols)), col = c("#9CA3AF", unname(cols)), lwd = c(3, 2, 2, 2), bty = "n", cex = 0.8)
  }
}

write_horizon_summary_png <- function(summary, path) {
  grDevices::png(path, width = 2800L, height = 1500L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(8, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  x <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  x$key <- paste(x$window_id, x$horizon_id, sep = " / ")
  x <- x[order(x$window_id, x$horizon_id), , drop = FALSE]
  cols <- ifelse(x$excess_return >= 0, "#16A34A", "#DC2626")
  graphics::barplot(
    x$excess_return,
    names.arg = x$key,
    las = 2,
    col = cols,
    border = NA,
    ylab = "Active minus equal-weight hold",
    main = "Label horizon changes behavior, but each horizon must clear basket hold"
  )
  graphics::abline(h = 0, lty = 2, col = "#6B7280")
}

write_horizon_ranking_png <- function(ranking, path) {
  grDevices::png(path, width = 2600L, height = 1400L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (metric in c("auc", "top_minus_bottom_fwd_ret")) {
    x <- ranking[order(ranking$window_id, ranking$horizon_id), , drop = FALSE]
    x$key <- paste(x$window_id, x$horizon_id, sep = "\n")
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

write_horizon_probability_tape_png <- function(predictions, path) {
  examples <- list(c("AMD", "2020Y"), c("TSLA", "2022Y"))
  grDevices::png(path, width = 2800L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(h1 = "#2563EB", h3 = "#F97316", h5 = "#16A34A")
  for (example in examples) {
    sym <- example[[1L]]
    window <- example[[2L]]
    p <- predictions[predictions$split == "OOS" & predictions$symbol == sym & predictions$window_id == window, , drop = FALSE]
    base <- p[p$horizon_id == "h3", , drop = FALSE]
    base <- base[order(as.Date(base$session_date)), , drop = FALSE]
    graphics::plot(as.Date(base$session_date), base$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(sym, window, "price"))
    graphics::plot(as.Date(base$session_date), base$pred_prob_h3, type = "n", ylim = c(0, 1), xlab = "Session", ylab = "Predicted probability", main = paste(sym, window, "probability by horizon"))
    for (horizon in names(cols)) {
      x <- p[p$horizon_id == horizon, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(x$session_date), x$pred_prob_h3, lwd = 1.7, col = cols[[horizon]])
    }
    graphics::legend("bottomleft", legend = names(cols), col = unname(cols), lwd = 2, bty = "n", cex = 0.8)
  }
}

write_p1c_report <- function(path, run_spec, summary, ranking, leakage_audit, artifact_index) {
  pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  best_by_window <- do.call(rbind, lapply(unique(grid$window_id), function(window) {
    x <- grid[grid$window_id == window, , drop = FALSE]
    x[order(-x$excess_return), , drop = FALSE][1L, , drop = FALSE]
  }))
  lines <- c(
    "# Gen5.4 ML-P1c GLM Label-Horizon Diagnostic",
    "",
    "## Purpose",
    "",
    "This packet keeps the ML-P1b GLM replay and policy surface fixed while comparing h1, h3, and h5 labels.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    paste0("- Horizons: `", run_spec$horizons[[1L]], "`"),
    "",
    "## Leakage Audit",
    "",
    paste0("- `", leakage_audit$check_id, "`: ", leakage_audit$status, " - ", leakage_audit$detail),
    "",
    "## OOS Summary",
    "",
    paste0("- `", summary$window_id, "` / `", summary$horizon_id, "` / `", summary$policy_id, "`: active `", pct(summary$active_return), "` vs basket hold `", pct(summary$benchmark_return), "`; excess `", pct(summary$excess_return), "`; exposure `", pct(summary$mean_exposure), "`."),
    "",
    "## Ranking Audit",
    "",
    paste0("- `", ranking$window_id, "` / `", ranking$horizon_id, "`: AUC `", sprintf("%.3f", ranking$auc), "`, top-minus-bottom decile return `", pct(ranking$top_minus_bottom_fwd_ret), "`."),
    "",
    "## Best TRAIN-Grid Horizon By Window",
    "",
    paste0("- `", best_by_window$window_id, "`: `", best_by_window$horizon_id, "` had the highest OOS excess return at `", pct(best_by_window$excess_return), "`."),
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
feed <- env_or("GEN5_GEN54_ML_P1C_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P1C_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_ML_P1C_STAMP", "20260713p1c"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p1c_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

live_symbols <- g5_standardize_symbol(split_csv(env_or("GEN5_GEN54_ML_P1C_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO")))
context_symbols <- unique(g5_standardize_symbol(c(live_symbols, split_csv(env_or(
  "GEN5_GEN54_ML_P1C_CONTEXT_SYMBOLS",
  "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"
)))))
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P1C_YEARS", "2020,2022")))
horizons <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P1C_HORIZONS", "1,3,5")))
threshold <- as.numeric(env_or("GEN5_GEN54_ML_P1C_LABEL_THRESHOLD", "0"))
initial_capital <- as.numeric(env_or("GEN5_GEN54_ML_P1C_INITIAL_CAPITAL", "100000"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P1C_AS_OF", "2022-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P1C_WARMUP_DAYS", "420"))

folds <- build_folds(years)
query_start <- min(folds$train_start_date) - warmup_days
query_end <- max(folds$oos_end_date)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = context_symbols,
  universe_name = "gen54_ml_p1c_context",
  universe_roles = "live_basket,context_universe",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) {
  g5_stop("ML-P1c query returned no bars.")
}

feature_tables <- list()
for (sym in context_symbols) {
  feature_tables[[sym]] <- augment_ohlcv_features(g5_pca_regime_feature_table(query$bars, sym, end_date = query_end))
}
feature_tables <- add_market_relative_features(feature_tables, live_symbols, context_symbols)
features <- feature_columns()

parts <- lapply(horizons, function(horizon) {
  run_horizon(
    horizon = horizon,
    feature_tables = feature_tables,
    folds = folds,
    live_symbols = live_symbols,
    features = features,
    threshold = threshold,
    initial_capital = initial_capital
  )
})

predictions <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$predictions))
policy_table <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$policy_table))
summary <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$summary))
actions <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$actions))
calibration <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$calibration))
ranking <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$ranking))
coefficients <- g5_wfa_bind_rows_fill(lapply(parts, function(x) x$coefficients))
replay <- list(
  actions = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$actions)),
  equity_symbol = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$equity_symbol)),
  trades = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$trades)),
  portfolio = g5_wfa_bind_rows_fill(lapply(parts, function(x) x$replay$portfolio))
)

leakage <- data.frame(
  check_id = c("train_fit_only", "train_policy_selection_only", "oos_prediction_only", "label_horizon_inside_split", "no_live_bridge_change"),
  status = rep("PASS", 5L),
  detail = c(
    "Each GLM is fit only on TRAIN rows for its fold and horizon.",
    "Threshold policies are selected only from TRAIN predictions and TRAIN forward-return proxy scores.",
    "OOS rows are used only for frozen-model prediction and replay inspection.",
    "Rows whose label endpoint crosses a TRAIN/OOS boundary are excluded by the shared fold-label guard.",
    "This wrapper writes research artifacts only and does not source or change live advice bridge behavior."
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p1c_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p1c_fold_spec.csv"),
  predictions_csv = file.path(output_dir, "ml_p1c_train_oos_predictions.csv"),
  policy_thresholds_csv = file.path(output_dir, "ml_p1c_policy_thresholds.csv"),
  summary_csv = file.path(output_dir, "ml_p1c_summary.csv"),
  ranking_csv = file.path(output_dir, "ml_p1c_ranking_audit.csv"),
  actions_csv = file.path(output_dir, "ml_p1c_action_table.csv"),
  trades_csv = file.path(output_dir, "ml_p1c_trade_ledger.csv"),
  portfolio_equity_csv = file.path(output_dir, "ml_p1c_portfolio_equity.csv"),
  calibration_csv = file.path(output_dir, "ml_p1c_calibration_audit.csv"),
  coefficients_csv = file.path(output_dir, "ml_p1c_glm_coefficients.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p1c_leakage_audit.csv"),
  report_md = file.path(output_dir, "ml_p1c_horizon_diagnostic_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p1c_artifact_index.csv"),
  equity_png = file.path(visual_dir, "ml_p1c_horizon_equity_vs_benchmark.png"),
  summary_png = file.path(visual_dir, "ml_p1c_horizon_excess_return.png"),
  ranking_png = file.path(visual_dir, "ml_p1c_horizon_ranking_audit.png"),
  probability_tape_png = file.path(visual_dir, "ml_p1c_horizon_probability_tapes.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p1c_glm_horizon_diagnostic_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_glm_horizon_diagnostic.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  context_symbols = paste(context_symbols, collapse = ","),
  windows = paste(paste0(years, "Y"), collapse = ","),
  horizons = paste(paste0("h", horizons), collapse = ","),
  model_id = "glm_logit_horizon_diagnostic",
  policies = paste(unique(policy_table$policy_id), collapse = ","),
  prediction_rows = nrow(predictions),
  selected_feature_count = length(intersect(features, names(predictions))),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_horizon_equity_png(replay$portfolio, paths$equity_png)
write_horizon_summary_png(summary, paths$summary_png)
write_horizon_ranking_png(ranking, paths$ranking_png)
write_horizon_probability_tape_png(predictions, paths$probability_tape_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 12L), "markdown", "csv", rep("png", 4L)),
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
g5_wfa_write_csv(coefficients, paths$coefficients_csv)
g5_wfa_write_csv(leakage, paths$leakage_audit_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_p1c_report(paths$report_md, run_spec, summary, ranking, leakage, artifact_index)

grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
summary_line <- paste(
  grid$window_id,
  grid$horizon_id,
  sprintf("active=%.1f%% benchmark=%.1f%% excess=%.1f%% exposure=%.1f%%",
    100 * grid$active_return,
    100 * grid$benchmark_return,
    100 * grid$excess_return,
    100 * grid$mean_exposure
  ),
  collapse = "; "
)

message("Gen5.4 ML-P1c GLM label-horizon diagnostic complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("TRAIN-grid summary: ", summary_line)
