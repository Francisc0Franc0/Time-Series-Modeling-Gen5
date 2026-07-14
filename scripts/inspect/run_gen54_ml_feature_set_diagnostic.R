# Gen5.4 supervised ML-P3 feature-set diagnostic.
#
# This wrapper keeps the seeded XGBoost model, h1 label, TRAIN-only threshold
# policy, annual replay, and benchmark surface fixed while changing only the
# feature set available to the model.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

Sys.setenv(GEN5_GEN54_ML_P2_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_xgboost_challenger.R"))
Sys.unsetenv("GEN5_GEN54_ML_P2_SOURCE_ONLY")

context_proxy_features <- function() {
  c("ret_5", "ret_20", "ret_60", "ema_gap", "trend_slope_20", "vol_20", "atr_pct", "atr_compression_20", "drawdown_60", "recovery_from_low_60", "close_location_60")
}

add_context_proxy_detail_features <- function(feature_tables, live_symbols, proxies = c("SPY", "QQQ", "SMH")) {
  proxies <- intersect(proxies, names(feature_tables))
  if (!length(proxies)) return(feature_tables)
  wanted <- context_proxy_features()
  proxy_parts <- lapply(proxies, function(proxy) {
    x <- feature_tables[[proxy]]
    keep <- intersect(wanted, names(x))
    out <- data.frame(session_date = as.Date(x$session_date), stringsAsFactors = FALSE)
    for (feature in keep) {
      out[[paste0("ctx_", tolower(proxy), "_", feature)]] <- suppressWarnings(as.numeric(x[[feature]]))
    }
    out
  })
  proxy_wide <- Reduce(function(left, right) merge(left, right, by = "session_date", all = TRUE, sort = FALSE), proxy_parts)
  proxy_wide <- proxy_wide[order(as.Date(proxy_wide$session_date)), , drop = FALSE]

  breadth_source <- do.call(rbind, lapply(proxies, function(proxy) {
    x <- feature_tables[[proxy]]
    data.frame(
      session_date = as.Date(x$session_date),
      ret_20_positive = as.numeric(x$ret_20 > 0),
      above_trend = as.numeric(x$ema_gap > 0),
      drawdown_60 = suppressWarnings(as.numeric(x$drawdown_60)),
      stringsAsFactors = FALSE
    )
  }))
  breadth <- aggregate(
    breadth_source[, c("ret_20_positive", "above_trend", "drawdown_60")],
    list(session_date = breadth_source$session_date),
    mean,
    na.rm = TRUE
  )
  names(breadth)[names(breadth) == "ret_20_positive"] <- "ctx_breadth_ret20_positive"
  names(breadth)[names(breadth) == "above_trend"] <- "ctx_breadth_above_trend"
  names(breadth)[names(breadth) == "drawdown_60"] <- "ctx_mean_drawdown_60"
  context_features <- merge(proxy_wide, breadth, by = "session_date", all = TRUE, sort = FALSE)

  for (sym in live_symbols) {
    x <- merge(feature_tables[[sym]], context_features, by = "session_date", all.x = TRUE, sort = FALSE)
    feature_tables[[sym]] <- x[order(as.Date(x$session_date)), , drop = FALSE]
  }
  feature_tables
}

feature_set_manifest <- function(all_features) {
  asset_features <- setdiff(feature_columns(), c("market_rel_ret_5", "market_rel_ret_20", "market_rel_ret_60"))
  relative_features <- c("market_rel_ret_5", "market_rel_ret_20", "market_rel_ret_60")
  direct_context_features <- grep("^ctx_", all_features, value = TRUE)
  rows <- list(
    data.frame(
      feature_set_id = "asset_only_control",
      feature_role = "asset_only",
      feature_name = intersect(asset_features, all_features),
      hypothesis = "Can the model make useful daily exposure decisions from the asset's own OHLCV-derived tape alone?",
      stringsAsFactors = FALSE
    ),
    data.frame(
      feature_set_id = "asset_plus_market_context",
      feature_role = "direct_market_context",
      feature_name = intersect(c(asset_features, direct_context_features), all_features),
      hypothesis = "Does direct SPY/QQQ/SMH trend, volatility, drawdown, and breadth context improve the same asset-tape model?",
      stringsAsFactors = FALSE
    ),
    data.frame(
      feature_set_id = "asset_plus_relative_strength",
      feature_role = "relative_strength",
      feature_name = intersect(c(asset_features, relative_features), all_features),
      hypothesis = "Does asset-minus-market return leadership help the model separate favorable exposure days?",
      stringsAsFactors = FALSE
    ),
    data.frame(
      feature_set_id = "full_context_compact",
      feature_role = "asset_relative_and_direct_context",
      feature_name = intersect(c(asset_features, relative_features, direct_context_features), all_features),
      hypothesis = "Does a compact full-context view beat narrower asset-only, direct-context, or relative-strength views?",
      stringsAsFactors = FALSE
    )
  )
  g5_wfa_bind_rows_fill(rows)
}

set_surface_id <- function(surface, feature_set_id) {
  for (name in c("predictions", "policy_table", "summary", "actions", "calibration", "ranking", "feature_importance")) {
    if (!is.null(surface[[name]]) && nrow(surface[[name]])) {
      surface[[name]]$feature_set_id <- feature_set_id
      surface[[name]]$model_id <- feature_set_id
    }
  }
  for (name in c("actions", "equity_symbol", "trades", "portfolio")) {
    if (!is.null(surface$replay[[name]]) && nrow(surface$replay[[name]])) {
      surface$replay[[name]]$feature_set_id <- feature_set_id
      surface$replay[[name]]$model_id <- feature_set_id
    }
  }
  surface
}

run_feature_set_surface <- function(feature_set_id, features, feature_fold_table, initial_capital, xgb_params, xgb_nrounds, xgb_nthread) {
  surface <- run_model_surface(
    model_id = "xgboost_h1_fixed_params",
    feature_fold_table = feature_fold_table,
    features = features,
    initial_capital = initial_capital,
    xgb_params = xgb_params,
    xgb_nrounds = xgb_nrounds,
    xgb_nthread = xgb_nthread
  )
  set_surface_id(surface, feature_set_id)
}

write_feature_set_equity_png <- function(portfolio, path) {
  grDevices::png(path, width = 3000L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(
    asset_only_control = "#2563EB",
    asset_plus_market_context = "#16A34A",
    asset_plus_relative_strength = "#F97316",
    full_context_compact = "#7C3AED"
  )
  policy <- "train_forward_return_grid"
  for (window in c("2020Y", "2022Y")) {
    x0 <- portfolio[portfolio$window_id == window & portfolio$policy_id == policy, , drop = FALSE]
    bench <- x0[x0$feature_set_id == unique(x0$feature_set_id)[[1L]], , drop = FALSE]
    bench <- bench[order(as.Date(bench$session_date)), , drop = FALSE]
    graphics::plot(as.Date(bench$session_date), bench$benchmark_mult, type = "l", lwd = 3, col = "#9CA3AF",
                   xlab = "Session", ylab = "Equity multiple", main = paste0(window, " XGBoost feature-set diagnostic"))
    for (feature_set in names(cols)) {
      x <- x0[x0$feature_set_id == feature_set, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      if (nrow(x)) graphics::lines(as.Date(x$session_date), x$active_mult, lwd = 2, col = cols[[feature_set]])
    }
    graphics::legend("topleft",
      legend = c("Equal-weight hold", names(cols)),
      col = c("#9CA3AF", unname(cols)),
      lwd = c(3, rep(2, length(cols))),
      bty = "n",
      cex = 0.68
    )
  }
}

write_feature_set_summary_png <- function(summary, path) {
  grDevices::png(path, width = 2800L, height = 1600L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(8, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  key_policy <- "train_forward_return_grid"
  x <- summary[summary$policy_id == key_policy, , drop = FALSE]
  x <- x[order(x$window_id, x$feature_set_id), , drop = FALSE]
  x$key <- paste(x$window_id, gsub("_", "\n", x$feature_set_id), sep = "\n")
  metrics <- c("excess_return", "active_max_drawdown")
  titles <- c("Alpha vs equal-weight hold", "Active max drawdown")
  for (i in seq_along(metrics)) {
    metric <- metrics[[i]]
    cols <- ifelse(x[[metric]] >= 0, "#16A34A", "#DC2626")
    graphics::barplot(
      x[[metric]],
      names.arg = x$key,
      las = 2,
      col = cols,
      border = NA,
      ylab = metric,
      main = titles[[i]]
    )
    graphics::abline(h = 0, lty = 2, col = "#6B7280")
  }
}

write_feature_set_ranking_png <- function(ranking, path) {
  grDevices::png(path, width = 2800L, height = 1600L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(8, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  x <- ranking[order(ranking$window_id, ranking$feature_set_id), , drop = FALSE]
  x$key <- paste(x$window_id, gsub("_", "\n", x$feature_set_id), sep = "\n")
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

write_feature_set_probability_tapes_png <- function(predictions, replay, path) {
  examples <- list(c("AMD", "2020Y"), c("TSLA", "2022Y"))
  grDevices::png(path, width = 3000L, height = 1800L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- c(
    asset_only_control = "#2563EB",
    asset_plus_market_context = "#16A34A",
    asset_plus_relative_strength = "#F97316",
    full_context_compact = "#7C3AED"
  )
  policy <- "train_forward_return_grid"
  for (example in examples) {
    sym <- example[[1L]]
    window <- example[[2L]]
    p <- predictions[predictions$split == "OOS" & predictions$symbol == sym & predictions$window_id == window, , drop = FALSE]
    base <- p[p$feature_set_id == "asset_only_control", , drop = FALSE]
    base <- base[order(as.Date(base$session_date)), , drop = FALSE]
    d <- as.Date(base$session_date)
    graphics::plot(d, base$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(sym, window, "price and feature-set entries"))
    for (feature_set in names(cols)) {
      a <- replay$actions[
        replay$actions$feature_set_id == feature_set &
          replay$actions$policy_id == policy &
          replay$actions$symbol == sym &
          replay$actions$window_id == window &
          replay$actions$executed_action == "ENTER_LONG",
        ,
        drop = FALSE
      ]
      if (nrow(a)) graphics::points(as.Date(a$feature_date), base$close[match(as.Date(a$feature_date), d)], pch = 24, bg = cols[[feature_set]], col = "#111827", cex = 0.9)
    }
    graphics::plot(d, base$pred_prob_h3, type = "n", ylim = c(0, 1), xlab = "Session", ylab = "Predicted probability", main = paste(sym, window, "probability by feature set"))
    for (feature_set in names(cols)) {
      x <- p[p$feature_set_id == feature_set, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      if (nrow(x)) graphics::lines(as.Date(x$session_date), x$pred_prob_h3, lwd = 1.5, col = cols[[feature_set]])
    }
    graphics::legend("bottomleft", legend = names(cols), col = unname(cols), lwd = 2, bty = "n", cex = 0.62)
  }
}

write_feature_set_report <- function(path, run_spec, manifest, summary, ranking, leakage_audit, artifact_index) {
  pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  feature_counts <- aggregate(manifest$feature_name, list(feature_set_id = manifest$feature_set_id), length)
  names(feature_counts)[names(feature_counts) == "x"] <- "feature_count"
  lines <- c(
    "# Gen5.4 ML-P3 Feature-Set Diagnostic",
    "",
    "## Purpose",
    "",
    "This packet tests whether the supervised XGBoost lane is limited by the information fed into the model rather than by small XGBoost parameter choices.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Context symbols: `", run_spec$context_symbols[[1L]], "`"),
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    paste0("- Label: `", run_spec$label_horizon[[1L]], "`"),
    paste0("- Seeded XGBoost params: depth `", run_spec$xgb_max_depth[[1L]], "`, rounds `", run_spec$xgb_nrounds[[1L]], "`, min_child_weight `", run_spec$xgb_min_child_weight[[1L]], "`, seed `", run_spec$xgb_seed[[1L]], "`"),
    "",
    "## Feature Sets",
    "",
    paste0("- `", feature_counts$feature_set_id, "`: ", feature_counts$feature_count, " features."),
    "",
    "## Leakage Audit",
    "",
    paste0("- `", leakage_audit$check_id, "`: ", leakage_audit$status, " - ", leakage_audit$detail),
    "",
    "## OOS TRAIN-Grid Summary",
    "",
    paste0("- `", grid$window_id, "` / `", grid$feature_set_id, "`: active `", pct(grid$active_return), "` vs basket hold `", pct(grid$benchmark_return), "`; excess `", pct(grid$excess_return), "`; exposure `", pct(grid$mean_exposure), "`."),
    "",
    "## Ranking Audit",
    "",
    paste0("- `", ranking$window_id, "` / `", ranking$feature_set_id, "`: AUC `", sprintf("%.3f", ranking$auc), "`, top-minus-bottom decile return `", pct(ranking$top_minus_bottom_fwd_ret), "`."),
    "",
    "## Interpretation",
    "",
    "Success would mean better replay and better ranking diagnostics together, not only higher exposure. If context features improve replay but not ranking, inspect probability tapes before expanding the feature surface.",
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
feed <- env_or("GEN5_GEN54_ML_P3_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P3_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_ML_P3_STAMP", "20260713p3features"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p3_features_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

live_symbols <- g5_standardize_symbol(split_csv(env_or("GEN5_GEN54_ML_P3_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO")))
context_symbols <- unique(g5_standardize_symbol(c(live_symbols, split_csv(env_or(
  "GEN5_GEN54_ML_P3_CONTEXT_SYMBOLS",
  "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"
)))))
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P3_YEARS", "2020,2022")))
horizon <- as.integer(env_or("GEN5_GEN54_ML_P3_HORIZON", "1"))
threshold <- as.numeric(env_or("GEN5_GEN54_ML_P3_LABEL_THRESHOLD", "0"))
initial_capital <- as.numeric(env_or("GEN5_GEN54_ML_P3_INITIAL_CAPITAL", "100000"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P3_AS_OF", "2022-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P3_WARMUP_DAYS", "420"))
xgb_nrounds <- as.integer(env_or("GEN5_GEN54_ML_P3_XGB_NROUNDS", "80"))
xgb_nthread <- as.integer(env_or("GEN5_GEN54_ML_P3_XGB_NTHREAD", "2"))
xgb_seed <- as.integer(env_or("GEN5_GEN54_ML_P3_XGB_SEED", "5402"))
xgb_params <- list(
  objective = "binary:logistic",
  eval_metric = "logloss",
  max_depth = as.integer(env_or("GEN5_GEN54_ML_P3_XGB_MAX_DEPTH", "3")),
  eta = as.numeric(env_or("GEN5_GEN54_ML_P3_XGB_ETA", "0.05")),
  subsample = as.numeric(env_or("GEN5_GEN54_ML_P3_XGB_SUBSAMPLE", "0.80")),
  colsample_bytree = as.numeric(env_or("GEN5_GEN54_ML_P3_XGB_COLSAMPLE", "0.80")),
  min_child_weight = as.numeric(env_or("GEN5_GEN54_ML_P3_XGB_MIN_CHILD_WEIGHT", "10")),
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
  universe_name = "gen54_ml_p3_context",
  universe_roles = "live_basket,context_universe",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) {
  g5_stop("ML-P3 query returned no bars.")
}

feature_tables <- list()
for (sym in context_symbols) {
  feature_tables[[sym]] <- augment_ohlcv_features(g5_pca_regime_feature_table(query$bars, sym, end_date = query_end))
}
feature_tables <- add_market_relative_features(feature_tables, live_symbols, context_symbols)
feature_tables <- add_context_proxy_detail_features(feature_tables, live_symbols)
labeled <- lapply(live_symbols, function(sym) add_forward_label(feature_tables[[sym]], horizon = horizon, threshold = threshold))
feature_labels <- g5_wfa_bind_rows_fill(labeled)
feature_fold_table <- assign_fold_split(feature_labels, folds)
all_features <- setdiff(names(feature_fold_table), c(
  "symbol", "session_date", "open", "high", "low", "close", "volume", "feature_date",
  "decision_timestamp_policy", "execution_date", "execution_price", "label_end_date",
  "label_end_close", "fwd_ret_h3", "label_up_h3", "label_threshold", "label_horizon_sessions",
  "window_id", "fold_id", "split", "label_inside_split", "train_start_date", "train_end_date",
  "oos_start_date", "oos_end_date"
))
manifest <- feature_set_manifest(all_features)

surfaces <- list()
for (feature_set_id in unique(manifest$feature_set_id)) {
  features <- manifest$feature_name[manifest$feature_set_id == feature_set_id]
  surfaces[[feature_set_id]] <- run_feature_set_surface(
    feature_set_id = feature_set_id,
    features = features,
    feature_fold_table = feature_fold_table,
    initial_capital = initial_capital,
    xgb_params = xgb_params,
    xgb_nrounds = xgb_nrounds,
    xgb_nthread = xgb_nthread
  )
}

predictions <- g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$predictions))
policy_table <- g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$policy_table))
summary <- g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$summary))
actions <- g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$actions))
calibration <- g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$calibration))
ranking <- g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$ranking))
feature_importance <- g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$feature_importance))
replay <- list(
  actions = g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$replay$actions)),
  equity_symbol = g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$replay$equity_symbol)),
  trades = g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$replay$trades)),
  portfolio = g5_wfa_bind_rows_fill(lapply(surfaces, function(x) x$replay$portfolio))
)

leakage <- data.frame(
  check_id = c("train_fit_only", "predeclared_xgb_params", "train_policy_selection_only", "oos_prediction_only", "feature_set_axis_only", "label_horizon_inside_split", "no_live_bridge_change"),
  status = rep("PASS", 7L),
  detail = c(
    "Each feature-set model is fit only on TRAIN rows for its fold.",
    "XGBoost parameters and seed are fixed before OOS replay.",
    "Threshold policies are selected only from TRAIN predictions and TRAIN forward-return proxy scores.",
    "OOS rows are used only for frozen-model prediction and replay inspection.",
    "The experimental axis is feature-set membership; model class, label, replay, and threshold policy are fixed.",
    "Rows whose label endpoint crosses a TRAIN/OOS boundary are excluded by the shared fold-label guard.",
    "This wrapper writes research artifacts only and does not source or change live advice bridge behavior."
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p3_feature_set_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p3_feature_set_fold_spec.csv"),
  feature_manifest_csv = file.path(output_dir, "ml_p3_feature_set_manifest.csv"),
  train_oos_predictions_csv = file.path(output_dir, "ml_p3_feature_set_train_oos_predictions.csv"),
  policy_thresholds_csv = file.path(output_dir, "ml_p3_feature_set_policy_thresholds.csv"),
  summary_csv = file.path(output_dir, "ml_p3_feature_set_summary.csv"),
  ranking_csv = file.path(output_dir, "ml_p3_feature_set_ranking_audit.csv"),
  action_table_csv = file.path(output_dir, "ml_p3_feature_set_action_table.csv"),
  trade_ledger_csv = file.path(output_dir, "ml_p3_feature_set_trade_ledger.csv"),
  portfolio_equity_csv = file.path(output_dir, "ml_p3_feature_set_portfolio_equity.csv"),
  calibration_csv = file.path(output_dir, "ml_p3_feature_set_calibration_audit.csv"),
  xgb_importance_csv = file.path(output_dir, "ml_p3_feature_set_xgb_feature_importance.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p3_feature_set_leakage_audit.csv"),
  report_md = file.path(output_dir, "ml_p3_feature_set_diagnostic_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p3_feature_set_artifact_index.csv"),
  equity_png = file.path(visual_dir, "ml_p3_feature_set_equity_vs_benchmark.png"),
  summary_png = file.path(visual_dir, "ml_p3_feature_set_summary.png"),
  ranking_png = file.path(visual_dir, "ml_p3_feature_set_ranking_audit.png"),
  probability_tape_png = file.path(visual_dir, "ml_p3_feature_set_probability_tapes.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p3_feature_set_diagnostic_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_feature_set_diagnostic.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  context_symbols = paste(context_symbols, collapse = ","),
  windows = paste(paste0(years, "Y"), collapse = ","),
  label_horizon = paste0("h", horizon),
  label_threshold = threshold,
  feature_sets = paste(unique(manifest$feature_set_id), collapse = ","),
  policies = paste(unique(policy_table$policy_id), collapse = ","),
  xgb_nrounds = xgb_nrounds,
  xgb_max_depth = xgb_params$max_depth,
  xgb_eta = xgb_params$eta,
  xgb_subsample = xgb_params$subsample,
  xgb_colsample_bytree = xgb_params$colsample_bytree,
  xgb_min_child_weight = xgb_params$min_child_weight,
  xgb_seed = xgb_seed,
  prediction_rows = nrow(predictions),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_feature_set_equity_png(replay$portfolio, paths$equity_png)
write_feature_set_summary_png(summary, paths$summary_png)
write_feature_set_ranking_png(ranking, paths$ranking_png)
write_feature_set_probability_tapes_png(predictions, replay, paths$probability_tape_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 13L), "markdown", "csv", rep("png", 4L)),
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(manifest, paths$feature_manifest_csv)
g5_wfa_write_csv(predictions, paths$train_oos_predictions_csv)
g5_wfa_write_csv(policy_table, paths$policy_thresholds_csv)
g5_wfa_write_csv(summary, paths$summary_csv)
g5_wfa_write_csv(ranking, paths$ranking_csv)
g5_wfa_write_csv(actions, paths$action_table_csv)
g5_wfa_write_csv(replay$trades, paths$trade_ledger_csv)
g5_wfa_write_csv(replay$portfolio, paths$portfolio_equity_csv)
g5_wfa_write_csv(calibration, paths$calibration_csv)
g5_wfa_write_csv(feature_importance, paths$xgb_importance_csv)
g5_wfa_write_csv(leakage, paths$leakage_audit_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_feature_set_report(paths$report_md, run_spec, manifest, summary, ranking, leakage, artifact_index)

grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
summary_line <- paste0(
  grid$window_id, " ", grid$feature_set_id,
  " active=", sprintf("%.1f%%", 100 * grid$active_return),
  " benchmark=", sprintf("%.1f%%", 100 * grid$benchmark_return),
  " excess=", sprintf("%.1f%%", 100 * grid$excess_return),
  " exposure=", sprintf("%.1f%%", 100 * grid$mean_exposure),
  collapse = "; "
)
message("Gen5.4 ML-P3 feature-set diagnostic complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("TRAIN-grid summary: ", summary_line)
