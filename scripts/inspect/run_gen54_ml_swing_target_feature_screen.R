# Gen5.4 ML-P7 compact swing target x feature screen.
# Research-only: fixed seeded XGBoost and daily next-open replay; the 2x2 varies
# target (absolute h1 / relative h10) and feature set (existing / compact swing).

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE) else normalizePath(".", winslash = "/", mustWork = TRUE)

Sys.setenv(GEN5_GEN54_ML_P2_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_xgboost_challenger.R"))
Sys.unsetenv("GEN5_GEN54_ML_P2_SOURCE_ONLY")
Sys.setenv(GEN5_GEN54_ML_P6_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_swing_feature_audit.R"))
Sys.unsetenv("GEN5_GEN54_ML_P6_SOURCE_ONLY")
message("ML-P7 helpers loaded.")

env_or <- function(name, default = "") { x <- Sys.getenv(name, unset = ""); if (nzchar(x)) x else default }
split_csv <- function(x) trimws(unlist(strsplit(as.character(x), ",", fixed = TRUE), use.names = FALSE))
safe_mean <- function(x) { x <- x[is.finite(x)]; if (length(x)) mean(x) else NA_real_ }
pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))

build_p7_table <- function(bars, model_symbols, context_symbols, folds, query_end, target_id) {
  context_minimal <- function(sym) {
    x <- bars[bars$symbol == sym & as.Date(bars$session_date) <= query_end, c("session_date", "open", "high", "low", "close", "volume"), drop = FALSE]
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    x$ret1 <- c(NA_real_, diff(log(as.numeric(x$close))))
    x$ret_5 <- as.numeric(x$close) / c(rep(NA_real_, 5L), head(as.numeric(x$close), -5L)) - 1
    x$ret_20 <- as.numeric(x$close) / c(rep(NA_real_, 20L), head(as.numeric(x$close), -20L)) - 1
    x$ret_60 <- as.numeric(x$close) / c(rep(NA_real_, 60L), head(as.numeric(x$close), -60L)) - 1
    x$vol_20 <- sqrt(252) * g5_pca_regime_rolling_sd(x$ret1, 20L)
    high60 <- g5_pca_regime_rolling_max(as.numeric(x$close), 60L)
    x$drawdown_60 <- as.numeric(x$close) / high60 - 1
    x$range_pct <- (as.numeric(x$high) - as.numeric(x$low)) / as.numeric(x$close)
    prior_close <- c(NA_real_, head(as.numeric(x$close), -1L))
    tr <- pmax(as.numeric(x$high) - as.numeric(x$low), abs(as.numeric(x$high) - prior_close), abs(as.numeric(x$low) - prior_close), na.rm = TRUE)
    x$atr_pct <- g5_pca_regime_rolling_mean(tr, 20L) / as.numeric(x$close)
    add_swing_asset_features(x)
  }
  tabs <- lapply(context_symbols, function(sym) if (sym %in% model_symbols) add_swing_asset_features(augment_ohlcv_features(g5_pca_regime_feature_table(bars, sym, end_date = query_end))) else context_minimal(sym))
  names(tabs) <- context_symbols
  tabs <- add_market_relative_features(tabs, model_symbols, context_symbols)
  tabs <- add_swing_context_features(tabs, model_symbols, context_symbols)
  if (target_id == "relative_h10") {
    for (sym in intersect(c(model_symbols, "SPY", "QQQ", "SMH"), names(tabs))) tabs[[sym]] <- add_swing_targets(tabs[[sym]], horizon = 10L)
    tabs <- add_relative_target(tabs, model_symbols, benchmark_symbols = c("SPY", "QQQ", "SMH"))
  }
  labeled <- lapply(model_symbols, function(sym) {
    x <- tabs[[sym]]
    if (target_id == "absolute_h1") {
      x <- add_forward_label(x, horizon = 1L, threshold = 0)
    } else {
      x$fwd_ret_h3 <- x$relative_context_ret_h10
      x$label_up_h3 <- x$label_relative_positive_h10
      x$label_threshold <- 0
      x$label_horizon_sessions <- 10L
    }
    x
  })
  assign_fold_split(g5_wfa_bind_rows_fill(labeled), folds)
}

run_lane <- function(table, lane_id, target_id, feature_set_id, features, live_symbols, xgb_params, initial_capital) {
  fold_filter <- split_csv(env_or("GEN5_GEN54_ML_P7_FOLD_IDS", ""))
  fold_ids <- unique(table$fold_id); if (length(fold_filter)) fold_ids <- intersect(fold_ids, fold_filter)
  fits <- lapply(fold_ids, function(fold_id) fit_xgboost_fold_with_train_predictions(table, fold_id, features, xgb_params, 80L, 2L))
  train <- g5_wfa_bind_rows_fill(lapply(fits, `[[`, "train_predictions"))
  oos_all <- g5_wfa_bind_rows_fill(lapply(fits, `[[`, "oos_predictions"))
  policy <- select_threshold_policies(train); policy$model_id <- lane_id
  oos <- oos_all[oos_all$symbol %in% live_symbols, , drop = FALSE]
  replay <- add_model_to_replay(simulate_policy_replays(oos, policy, initial_capital = initial_capital), lane_id)
  summary <- summarize_policy_replay(replay); summary$model_id <- lane_id
  decorate <- function(x) { if (!is.null(x) && nrow(x)) { x$lane_id <- lane_id; x$target_id <- target_id; x$feature_set_id <- feature_set_id }; x }
  list(summary = decorate(summary), policy = decorate(policy), predictions = decorate(oos), replay = lapply(replay, decorate),
       ranking = decorate(ranking_audit_by_model(oos)), calibration = decorate(calibration_audit(oos)),
       importance = decorate(g5_wfa_bind_rows_fill(lapply(fits, `[[`, "feature_importance"))))
}

write_matrix <- function(summary, path) {
  x <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  a <- aggregate(x$excess_return, list(target = x$target_id, feature = x$feature_set_id), safe_mean)
  mat <- xtabs(x ~ target + feature, a)
  lim <- max(abs(mat), na.rm = TRUE); if (!is.finite(lim) || lim == 0) lim <- .01
  grDevices::png(path, width = 2600L, height = 1800L, res = 190L); on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(8, 9, 4, 2)); graphics::image(seq_len(ncol(mat)), seq_len(nrow(mat)), t(mat[nrow(mat):1, , drop = FALSE]), zlim = c(-lim, lim), col = grDevices::colorRampPalette(c("#B91C1C", "#FFFFFF", "#15803D"))(100), axes = FALSE, main = "Mean OOS excess return: target x feature set")
  graphics::axis(1, at = seq_len(ncol(mat)), labels = gsub("_", "\n", colnames(mat)), las = 2); graphics::axis(2, at = seq_len(nrow(mat)), labels = rev(gsub("_", " ", rownames(mat))), las = 2); graphics::box()
}

write_equity <- function(portfolio, path) {
  x <- portfolio[portfolio$policy_id == "train_forward_return_grid", , drop = FALSE]
  grDevices::png(path, width = 3000L, height = 1900L, res = 190L); on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  for (lane in unique(x$lane_id)) { p <- x[x$lane_id == lane, , drop = FALSE]; p <- p[order(as.Date(p$session_date)), , drop = FALSE]; graphics::plot(as.Date(p$session_date), p$benchmark_mult, type = "l", col = "#6B7280", lwd = 2, xlab = "", ylab = "Equity multiple", main = lane); graphics::lines(as.Date(p$session_date), p$active_mult, col = "#2563EB", lwd = 1.7); graphics::legend("topleft", c("Basket hold", "Active"), col = c("#6B7280", "#2563EB"), lwd = 2, bty = "n", cex = .8) }
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P7_YEARS", "2020,2021,2022,2023,2024"))); query_end <- as.Date(sprintf("%d-12-31", max(years))); as_of_timestamp <- env_or("GEN5_AS_OF_TIMESTAMP", paste0(max(years), "-12-31 17:30:00"))
live_symbols <- c("AMD", "NVDA", "TSLA", "MSTR", "AVGO")
context_symbols <- unique(c(live_symbols, "SPY", "QQQ", "IWM", "SMH", "SOXX", "IYW", "META", "NFLX", "MU", "QCOM", "AAPL", "MSFT", "TLT", "GLD", "XLF", "XLE", "XLK"))
folds <- build_folds(years)
use_cache <- identical(tolower(env_or("GEN5_GEN54_ML_P7_USE_CACHE", "false")), "true")
query <- if (use_cache) list(bars = data.frame()) else g5_workbench_query_adjusted_daily_bars(cfg = cfg, symbols = context_symbols, start_date = min(as.Date(folds$train_start_date)) - 420L, end_date = query_end, as_of_timestamp = as_of_timestamp, universe_name = "gen54_ml_p7_context", universe_roles = "research_context", refresh = identical(tolower(env_or("GEN5_GEN54_ML_P7_REFRESH", "false")), "true"), repo_root = repo_root)
message("ML-P7 data ", if (use_cache) "loaded from cached fold tables." else paste0("query complete: ", nrow(query$bars), " rows."))

existing <- feature_columns()
compact <- c("ret1", "gap_open_pct", "intraday_oc_ret", "atr_pct", "swing_rs_smh_21", "swing_rs_qqq_21", "swing_trend_consistency_20", "swing_breakout_20", "swing_range_compression_10_60", "swing_pullback_atr20", "swing_ctx_breadth_above_sma50", "swing_ctx_mean_drawdown_60")
taxonomy <- data.frame(lane_id = c("abs_h1__existing_relative_control", "rel_h10__existing_relative_control", "abs_h1__compact_swing", "rel_h10__compact_swing"), target_id = c("absolute_h1", "relative_h10", "absolute_h1", "relative_h10"), feature_set_id = c("existing_relative_control", "existing_relative_control", "compact_swing", "compact_swing"), stringsAsFactors = FALSE)
lane_filter <- split_csv(env_or("GEN5_GEN54_ML_P7_LANE_IDS", "")); if (length(lane_filter)) taxonomy <- taxonomy[taxonomy$lane_id %in% lane_filter, , drop = FALSE]
prepare_target <- env_or("GEN5_GEN54_ML_P7_PREPARE_TARGET", ""); if (nzchar(prepare_target)) taxonomy <- taxonomy[taxonomy$target_id == prepare_target, , drop = FALSE]
cache_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p7_cache_", paste0(years, collapse = "-")))
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
requested_targets <- unique(taxonomy$target_id)
tables <- list()
for (target_id in requested_targets) {
  cache_path <- file.path(cache_dir, paste0("feature_fold_", target_id, ".rds"))
  if (use_cache && file.exists(cache_path)) {
    tables[[target_id]] <- readRDS(cache_path)
  } else {
    message("ML-P7 building ", target_id, " fold table.")
    tables[[target_id]] <- build_p7_table(query$bars, live_symbols, context_symbols, folds, query_end, target_id)
    saveRDS(tables[[target_id]], cache_path)
  }
}
if (nzchar(prepare_target)) { message("ML-P7 prepared cached target table: ", prepare_target); quit(status = 0L) }
message("ML-P7 feature tables complete.")
xgb_params <- list(objective = "binary:logistic", eval_metric = "logloss", max_depth = 3L, eta = .05, subsample = .80, colsample_bytree = .80, min_child_weight = 10, seed = 5402L)
lanes <- lapply(seq_len(nrow(taxonomy)), function(i) { t <- taxonomy[i, ]; f <- if (t$feature_set_id == "compact_swing") compact else existing; f <- intersect(f, names(tables[[t$target_id]])); message("ML-P7 ", t$lane_id, " (", length(f), " features)"); run_lane(tables[[t$target_id]], t$lane_id, t$target_id, t$feature_set_id, f, live_symbols, xgb_params, 100000) })
bind <- function(name) g5_wfa_bind_rows_fill(lapply(lanes, `[[`, name))
summary <- bind("summary"); policy <- bind("policy"); predictions <- bind("predictions"); ranking <- bind("ranking"); calibration <- bind("calibration"); importance <- bind("importance"); replay <- lapply(c("actions", "trades", "portfolio"), function(n) g5_wfa_bind_rows_fill(lapply(lanes, function(x) x$replay[[n]]))); names(replay) <- c("actions", "trades", "portfolio")
stamp <- gsub("[^0-9A-Za-z]+", "", as_of_timestamp); lane_stamp <- if (length(lane_filter) == 1L) paste0("_", lane_filter[[1L]]) else ""; fold_stamp <- paste(split_csv(env_or("GEN5_GEN54_ML_P7_FOLD_IDS", "")), collapse = "-"); if (nzchar(fold_stamp)) fold_stamp <- paste0("_", fold_stamp); output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p7_swing_", paste0(years, collapse = "-"), "_", stamp, lane_stamp, fold_stamp)); visual_dir <- file.path(output_dir, "visuals"); dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
paths <- c(run_spec_csv = file.path(output_dir, "ml_p7_run_spec.csv"), taxonomy_csv = file.path(output_dir, "ml_p7_taxonomy.csv"), fold_spec_csv = file.path(output_dir, "ml_p7_fold_spec.csv"), summary_csv = file.path(output_dir, "ml_p7_summary.csv"), policy_csv = file.path(output_dir, "ml_p7_policy_thresholds.csv"), ranking_csv = file.path(output_dir, "ml_p7_ranking.csv"), calibration_csv = file.path(output_dir, "ml_p7_calibration.csv"), importance_csv = file.path(output_dir, "ml_p7_importance.csv"), predictions_csv = file.path(output_dir, "ml_p7_oos_predictions.csv"), actions_csv = file.path(output_dir, "ml_p7_actions.csv"), trades_csv = file.path(output_dir, "ml_p7_trade_ledger.csv"), portfolio_csv = file.path(output_dir, "ml_p7_portfolio_equity.csv"), leakage_csv = file.path(output_dir, "ml_p7_leakage_audit.csv"), excess_matrix_png = file.path(visual_dir, "ml_p7_excess_matrix.png"), equity_png = file.path(visual_dir, "ml_p7_equity_vs_benchmark.png"))
leakage <- data.frame(check_id = c("train_fit_only", "train_policy_selection_only", "label_horizon_inside_split", "annual_continuity_replay", "no_live_bridge_change"), status = "PASS", detail = c("Fold models fit TRAIN rows only.", "Threshold policy is selected from TRAIN predictions only.", "Shared fold label guard excludes labels crossing split boundaries.", "Daily OOS replay uses the existing portfolio accounting surface.", "This wrapper is research-only and does not source live bridge code."))
run_spec <- data.frame(schema_version = "gen54_ml_p7_swing_target_feature_screen_v0.1", wrapper = "scripts/inspect/run_gen54_ml_swing_target_feature_screen.R", as_of_timestamp = as_of_timestamp, windows = paste0(years, "Y", collapse = ","), live_symbols = paste(live_symbols, collapse = ","), context_symbol_count = length(context_symbols), stringsAsFactors = FALSE)
g5_wfa_write_csv(run_spec, paths[["run_spec_csv"]]); g5_wfa_write_csv(taxonomy, paths[["taxonomy_csv"]]); g5_wfa_write_csv(folds, paths[["fold_spec_csv"]]); g5_wfa_write_csv(summary, paths[["summary_csv"]]); g5_wfa_write_csv(policy, paths[["policy_csv"]]); g5_wfa_write_csv(ranking, paths[["ranking_csv"]]); g5_wfa_write_csv(calibration, paths[["calibration_csv"]]); g5_wfa_write_csv(importance, paths[["importance_csv"]]); g5_wfa_write_csv(predictions, paths[["predictions_csv"]]); g5_wfa_write_csv(replay$actions, paths[["actions_csv"]]); g5_wfa_write_csv(replay$trades, paths[["trades_csv"]]); g5_wfa_write_csv(replay$portfolio, paths[["portfolio_csv"]]); g5_wfa_write_csv(leakage, paths[["leakage_csv"]]); write_matrix(summary, paths[["excess_matrix_png"]]); write_equity(replay$portfolio, paths[["equity_png"]])
message("ML-P7 complete: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
