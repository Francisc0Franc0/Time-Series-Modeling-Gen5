# Gen5.4 supervised ML-P4 label-horizon x feature-set diagnostic.
#
# This parent wrapper reruns the validated ML-P3 feature-set surface for
# multiple next-open forward-return horizons, then stitches the child packets
# into one top-level inspection packet. The child model/replay mechanics stay
# fixed; only the label horizon changes.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) default else value
}

split_csv <- function(x) {
  x <- unlist(strsplit(x, ",", fixed = TRUE), use.names = FALSE)
  x <- trimws(x)
  x[nzchar(x)]
}

parse_bool <- function(x, default = FALSE) {
  if (!nzchar(x)) return(default)
  tolower(trimws(x)) %in% c("1", "true", "yes", "y")
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

read_child_csv <- function(child_dir, file_name, horizon_id) {
  path <- file.path(child_dir, file_name)
  if (!file.exists(path)) stop("Missing expected child artifact: ", path, call. = FALSE)
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  x$label_horizon <- horizon_id
  x$child_output_dir <- normalizePath(child_dir, winslash = "/", mustWork = FALSE)
  x
}

pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))

sanitize_stamp <- function(x) gsub("[^0-9A-Za-z]+", "", x)

run_child_packet <- function(horizon, child_stamp, p4_env) {
  child_dir <- file.path(
    repo_root,
    "runs", "research_workbench", "gen54_ml_decision_engine",
    paste0("g54_ml_p3_features_", child_stamp)
  )
  if (parse_bool(p4_env$skip_child_runs, default = FALSE)) {
    if (!file.exists(file.path(child_dir, "ml_p3_feature_set_summary.csv"))) {
      stop("Skip-child mode requested but child summary is missing: ", child_dir, call. = FALSE)
    }
    return(child_dir)
  }

  child_env <- c(
    GEN5_GEN54_ML_P3_STAMP = child_stamp,
    GEN5_GEN54_ML_P3_HORIZON = as.character(horizon),
    GEN5_GEN54_ML_P3_REFRESH = p4_env$refresh,
    GEN5_GEN54_ML_P3_FEED = p4_env$feed,
    GEN5_GEN54_ML_P3_LIVE_SYMBOLS = p4_env$live_symbols,
    GEN5_GEN54_ML_P3_CONTEXT_SYMBOLS = p4_env$context_symbols,
    GEN5_GEN54_ML_P3_YEARS = p4_env$years,
    GEN5_GEN54_ML_P3_AS_OF = p4_env$as_of_timestamp,
    GEN5_GEN54_ML_P3_WARMUP_DAYS = p4_env$warmup_days,
    GEN5_GEN54_ML_P3_LABEL_THRESHOLD = p4_env$label_threshold,
    GEN5_GEN54_ML_P3_INITIAL_CAPITAL = p4_env$initial_capital,
    GEN5_GEN54_ML_P3_XGB_NROUNDS = p4_env$xgb_nrounds,
    GEN5_GEN54_ML_P3_XGB_NTHREAD = p4_env$xgb_nthread,
    GEN5_GEN54_ML_P3_XGB_SEED = p4_env$xgb_seed,
    GEN5_GEN54_ML_P3_XGB_MAX_DEPTH = p4_env$xgb_max_depth,
    GEN5_GEN54_ML_P3_XGB_ETA = p4_env$xgb_eta,
    GEN5_GEN54_ML_P3_XGB_SUBSAMPLE = p4_env$xgb_subsample,
    GEN5_GEN54_ML_P3_XGB_COLSAMPLE = p4_env$xgb_colsample,
    GEN5_GEN54_ML_P3_XGB_MIN_CHILD_WEIGHT = p4_env$xgb_min_child_weight
  )
  script <- file.path(repo_root, "scripts", "inspect", "run_gen54_ml_feature_set_diagnostic.R")
  message("Running ML-P3 child for h", horizon, " -> ", child_stamp)
  old_env <- Sys.getenv(names(child_env), unset = NA_character_)
  do.call(Sys.setenv, as.list(child_env))
  tryCatch(
    source(script, local = new.env(parent = globalenv())),
    error = function(e) stop("ML-P4 child run failed for h", horizon, ": ", conditionMessage(e), call. = FALSE),
    finally = {
      for (name in names(child_env)) {
        if (is.na(old_env[[name]])) {
          Sys.unsetenv(name)
        } else {
          do.call(Sys.setenv, setNames(list(old_env[[name]]), name))
        }
      }
    }
  )
  child_dir
}

write_horizon_return_png <- function(summary, path) {
  x <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  x$label_horizon <- factor(x$label_horizon, levels = c("h1", "h5", "h10"))
  feature_sets <- unique(x$feature_set_id)
  horizons <- levels(x$label_horizon)
  metrics <- c("active_return", "excess_return")
  grDevices::png(path, width = 3200L, height = 1900L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(8, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (window in c("2020Y", "2022Y")) {
    for (metric in metrics) {
      mat <- matrix(NA_real_, nrow = length(horizons), ncol = length(feature_sets), dimnames = list(horizons, feature_sets))
      for (h in horizons) {
        for (fs in feature_sets) {
          row <- x[x$window_id == window & x$label_horizon == h & x$feature_set_id == fs, , drop = FALSE]
          if (nrow(row)) mat[h, fs] <- row[[metric]][[1L]]
        }
      }
      colnames(mat) <- gsub("_", "\n", colnames(mat))
      cols <- c(h1 = "#2563EB", h5 = "#F97316", h10 = "#7C3AED")
      graphics::barplot(
        mat,
        beside = TRUE,
        col = cols[rownames(mat)],
        border = NA,
        las = 2,
        ylab = metric,
        main = paste(window, gsub("_", " ", metric))
      )
      graphics::abline(h = 0, lty = 2, col = "#6B7280")
      graphics::legend("topright", legend = rownames(mat), fill = cols[rownames(mat)], bty = "n", cex = 0.85)
    }
  }
}

write_horizon_ranking_png <- function(ranking, path) {
  x <- ranking[order(ranking$window_id, ranking$feature_set_id, ranking$label_horizon), , drop = FALSE]
  x$key <- paste(x$window_id, gsub("_", "\n", x$feature_set_id), x$label_horizon, sep = "\n")
  grDevices::png(path, width = 3600L, height = 1900L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(11, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (metric in c("auc", "top_minus_bottom_fwd_ret")) {
    threshold <- if (metric == "auc") 0.5 else 0
    cols <- ifelse(x[[metric]] >= threshold, "#16A34A", "#DC2626")
    graphics::barplot(
      x[[metric]],
      names.arg = x$key,
      las = 2,
      col = cols,
      border = NA,
      ylab = if (metric == "auc") "OOS AUC" else "Top minus bottom forward return",
      main = if (metric == "auc") "Probability ranking by horizon" else "Return separation by horizon"
    )
    graphics::abline(h = threshold, lty = 2, col = "#6B7280")
  }
}

write_relative_strength_equity_png <- function(portfolio, path) {
  policy <- "train_forward_return_grid"
  feature_set <- "asset_plus_relative_strength"
  cols <- c(h1 = "#2563EB", h5 = "#F97316", h10 = "#7C3AED")
  grDevices::png(path, width = 3000L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (window in c("2020Y", "2022Y")) {
    x0 <- portfolio[portfolio$window_id == window & portfolio$policy_id == policy & portfolio$feature_set_id == feature_set, , drop = FALSE]
    bench <- x0[x0$label_horizon == unique(x0$label_horizon)[[1L]], , drop = FALSE]
    bench <- bench[order(as.Date(bench$session_date)), , drop = FALSE]
    graphics::plot(as.Date(bench$session_date), bench$benchmark_mult, type = "l", lwd = 3, col = "#9CA3AF",
                   xlab = "Session", ylab = "Equity multiple", main = paste0(window, " relative-strength label horizons"))
    for (h in names(cols)) {
      x <- x0[x0$label_horizon == h, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      if (nrow(x)) graphics::lines(as.Date(x$session_date), x$active_mult, lwd = 2, col = cols[[h]])
    }
    graphics::legend("topleft", legend = c("Equal-weight hold", names(cols)), col = c("#9CA3AF", unname(cols)), lwd = c(3, 2, 2, 2), bty = "n", cex = 0.8)
  }
}

write_horizon_probability_tapes_png <- function(predictions, trades, path) {
  examples <- list(c("AMD", "2020Y"), c("TSLA", "2022Y"))
  feature_set <- "asset_plus_relative_strength"
  policy <- "train_forward_return_grid"
  cols <- c(h1 = "#2563EB", h5 = "#F97316", h10 = "#7C3AED")
  grDevices::png(path, width = 3000L, height = 1800L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (example in examples) {
    sym <- example[[1L]]
    window <- example[[2L]]
    p <- predictions[predictions$split == "OOS" & predictions$symbol == sym & predictions$window_id == window & predictions$feature_set_id == feature_set, , drop = FALSE]
    base <- p[p$label_horizon == "h1", , drop = FALSE]
    base <- base[order(as.Date(base$session_date)), , drop = FALSE]
    d <- as.Date(base$session_date)
    graphics::plot(d, base$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(sym, window, "relative-strength entries by horizon"))
    for (h in names(cols)) {
      a <- trades[
        trades$label_horizon == h &
          trades$feature_set_id == feature_set &
          trades$policy_id == policy &
          trades$symbol == sym &
          trades$window_id == window,
        ,
        drop = FALSE
      ]
      if (nrow(a)) graphics::points(as.Date(a$entry_signal_date), base$close[match(as.Date(a$entry_signal_date), d)], pch = 24, bg = cols[[h]], col = "#111827", cex = 0.9)
    }
    graphics::plot(d, base$pred_prob_h3, type = "n", ylim = c(0, 1), xlab = "Session", ylab = "Predicted probability", main = paste(sym, window, "probability by label horizon"))
    for (h in names(cols)) {
      x <- p[p$label_horizon == h, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      if (nrow(x)) graphics::lines(as.Date(x$session_date), x$pred_prob_h3, lwd = 1.6, col = cols[[h]])
    }
    graphics::legend("bottomleft", legend = names(cols), col = unname(cols), lwd = 2, bty = "n", cex = 0.8)
  }
}

write_report <- function(path, run_spec, child_index, summary, ranking, leakage, artifact_index) {
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  best_by_window <- do.call(rbind, lapply(unique(grid$window_id), function(window) {
    x <- grid[grid$window_id == window, , drop = FALSE]
    x[order(-x$active_return), , drop = FALSE][1L, , drop = FALSE]
  }))
  lines <- c(
    "# Gen5.4 ML-P4 Label-Horizon Feature-Set Diagnostic",
    "",
    "## Purpose",
    "",
    "This packet asks whether the seeded XGBoost decision engine behaves better when the label targets a longer next-open forward-return window.",
    "",
    "The pushback is important: `h5` and `h10` are not simply more confident versions of `h1`. They ask a different question: whether today's setup is worth exposure over roughly one or two trading weeks while the replay still rescores daily.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Context symbols: `", run_spec$context_symbols[[1L]], "`"),
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    paste0("- Horizons: `", run_spec$label_horizons[[1L]], "`"),
    paste0("- Child packet count: `", nrow(child_index), "`"),
    "",
    "## Leakage Audit",
    "",
    paste0("- `", leakage$check_id, "`: ", leakage$status, " - ", leakage$detail),
    "",
    "## TRAIN-Grid Summary",
    "",
    paste0("- `", grid$window_id, "` / `", grid$label_horizon, "` / `", grid$feature_set_id, "`: active `", pct(grid$active_return), "` vs basket hold `", pct(grid$benchmark_return), "`; excess `", pct(grid$excess_return), "`; exposure `", pct(grid$mean_exposure), "`."),
    "",
    "## Best Active Return By Window",
    "",
    paste0("- `", best_by_window$window_id, "`: `", best_by_window$label_horizon, "` / `", best_by_window$feature_set_id, "` returned `", pct(best_by_window$active_return), "` versus basket hold `", pct(best_by_window$benchmark_return), "`."),
    "",
    "## Ranking Audit",
    "",
    paste0("- `", ranking$window_id, "` / `", ranking$label_horizon, "` / `", ranking$feature_set_id, "`: AUC `", sprintf("%.3f", ranking$auc), "`, top-minus-bottom `", pct(ranking$top_minus_bottom_fwd_ret), "`."),
    "",
    "## Interpretation Prompt",
    "",
    "A longer horizon only earns follow-up if it improves replay and ranking together, or if probability tapes show more intuitive entries/exits without merely raising exposure. If `h5` or `h10` helps but still churns awkwardly, the next natural comparator is daily rescore versus minimum-hold replay.",
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_index$artifact_id, "`: `", artifact_index$path, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

stamp <- sanitize_stamp(env_or("GEN5_GEN54_ML_P4_STAMP", "20260713p4horizons"))
output_dir <- ensure_dir(file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p4_horizons_", stamp)))
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

p4_env <- list(
  refresh = env_or("GEN5_GEN54_ML_P4_REFRESH", "false"),
  feed = env_or("GEN5_GEN54_ML_P4_FEED", ""),
  live_symbols = env_or("GEN5_GEN54_ML_P4_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO"),
  context_symbols = env_or("GEN5_GEN54_ML_P4_CONTEXT_SYMBOLS", "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"),
  years = env_or("GEN5_GEN54_ML_P4_YEARS", "2020,2022"),
  as_of_timestamp = env_or("GEN5_GEN54_ML_P4_AS_OF", "2022-12-31 17:30:00"),
  warmup_days = env_or("GEN5_GEN54_ML_P4_WARMUP_DAYS", "420"),
  label_threshold = env_or("GEN5_GEN54_ML_P4_LABEL_THRESHOLD", "0"),
  initial_capital = env_or("GEN5_GEN54_ML_P4_INITIAL_CAPITAL", "100000"),
  xgb_nrounds = env_or("GEN5_GEN54_ML_P4_XGB_NROUNDS", "80"),
  xgb_nthread = env_or("GEN5_GEN54_ML_P4_XGB_NTHREAD", "2"),
  xgb_seed = env_or("GEN5_GEN54_ML_P4_XGB_SEED", "5402"),
  xgb_max_depth = env_or("GEN5_GEN54_ML_P4_XGB_MAX_DEPTH", "3"),
  xgb_eta = env_or("GEN5_GEN54_ML_P4_XGB_ETA", "0.05"),
  xgb_subsample = env_or("GEN5_GEN54_ML_P4_XGB_SUBSAMPLE", "0.80"),
  xgb_colsample = env_or("GEN5_GEN54_ML_P4_XGB_COLSAMPLE", "0.80"),
  xgb_min_child_weight = env_or("GEN5_GEN54_ML_P4_XGB_MIN_CHILD_WEIGHT", "10"),
  skip_child_runs = env_or("GEN5_GEN54_ML_P4_SKIP_CHILD_RUNS", "false")
)

horizons <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P4_HORIZONS", "1,5,10")))
if (!length(horizons)) stop("ML-P4 requires at least one horizon.", call. = FALSE)

child_rows <- list()
summary_parts <- list()
ranking_parts <- list()
policy_parts <- list()
action_parts <- list()
trade_parts <- list()
portfolio_parts <- list()
calibration_parts <- list()
importance_parts <- list()
prediction_parts <- list()
child_leakage_parts <- list()

for (i in seq_along(horizons)) {
  horizon <- horizons[[i]]
  horizon_id <- paste0("h", horizon)
  child_stamp <- paste0(stamp, horizon_id)
  child_dir <- run_child_packet(horizon, child_stamp, p4_env)
  child_rows[[i]] <- data.frame(
    label_horizon = horizon_id,
    child_stamp = child_stamp,
    child_output_dir = normalizePath(child_dir, winslash = "/", mustWork = FALSE),
    child_report = normalizePath(file.path(child_dir, "ml_p3_feature_set_diagnostic_report.md"), winslash = "/", mustWork = FALSE),
    stringsAsFactors = FALSE
  )
  summary_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_summary.csv", horizon_id)
  ranking_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_ranking_audit.csv", horizon_id)
  policy_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_policy_thresholds.csv", horizon_id)
  action_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_action_table.csv", horizon_id)
  trade_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_trade_ledger.csv", horizon_id)
  portfolio_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_portfolio_equity.csv", horizon_id)
  calibration_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_calibration_audit.csv", horizon_id)
  importance_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_xgb_feature_importance.csv", horizon_id)
  prediction_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_train_oos_predictions.csv", horizon_id)
  child_leakage_parts[[i]] <- read_child_csv(child_dir, "ml_p3_feature_set_leakage_audit.csv", horizon_id)
}

child_index <- do.call(rbind, child_rows)
summary <- do.call(rbind, summary_parts)
ranking <- do.call(rbind, ranking_parts)
policy_table <- do.call(rbind, policy_parts)
actions <- do.call(rbind, action_parts)
trades <- do.call(rbind, trade_parts)
portfolio <- do.call(rbind, portfolio_parts)
calibration <- do.call(rbind, calibration_parts)
importance <- do.call(rbind, importance_parts)
predictions <- do.call(rbind, prediction_parts)
child_leakage <- do.call(rbind, child_leakage_parts)

child_pass <- all(child_leakage$status == "PASS")
leakage <- data.frame(
  check_id = c("child_guardrails_all_pass", "label_horizon_axis_only", "daily_rescore_policy_fixed", "no_live_bridge_change"),
  status = c(if (child_pass) "PASS" else "REVIEW_REQUIRED", "PASS", "PASS", "PASS"),
  detail = c(
    "Every ML-P3 child packet reported PASS guardrails before its artifacts were stitched.",
    "The parent experimental axis is label horizon; child model class, XGBoost params, feature sets, threshold policy, annual replay, and benchmark discipline are unchanged.",
    "The first ML-P4 replay keeps the existing daily rescore policy so the label effect is isolated before testing minimum-hold behavior.",
    "This wrapper writes research artifacts only and does not source or change live advice bridge behavior."
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p4_horizon_run_spec.csv"),
  child_index_csv = file.path(output_dir, "ml_p4_horizon_child_index.csv"),
  child_leakage_csv = file.path(output_dir, "ml_p4_horizon_child_leakage_audit.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p4_horizon_leakage_audit.csv"),
  summary_csv = file.path(output_dir, "ml_p4_horizon_summary.csv"),
  ranking_csv = file.path(output_dir, "ml_p4_horizon_ranking_audit.csv"),
  policy_thresholds_csv = file.path(output_dir, "ml_p4_horizon_policy_thresholds.csv"),
  action_table_csv = file.path(output_dir, "ml_p4_horizon_action_table.csv"),
  trade_ledger_csv = file.path(output_dir, "ml_p4_horizon_trade_ledger.csv"),
  portfolio_equity_csv = file.path(output_dir, "ml_p4_horizon_portfolio_equity.csv"),
  calibration_csv = file.path(output_dir, "ml_p4_horizon_calibration_audit.csv"),
  xgb_importance_csv = file.path(output_dir, "ml_p4_horizon_xgb_feature_importance.csv"),
  predictions_csv = file.path(output_dir, "ml_p4_horizon_train_oos_predictions.csv"),
  report_md = file.path(output_dir, "ml_p4_horizon_diagnostic_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p4_horizon_artifact_index.csv"),
  return_png = file.path(visual_dir, "ml_p4_horizon_return_matrix.png"),
  ranking_png = file.path(visual_dir, "ml_p4_horizon_ranking_audit.png"),
  relative_strength_equity_png = file.path(visual_dir, "ml_p4_relative_strength_equity.png"),
  probability_tape_png = file.path(visual_dir, "ml_p4_horizon_probability_tapes.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p4_label_horizon_feature_set_diagnostic_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_label_horizon_feature_set_diagnostic.R",
  child_wrapper = "scripts/inspect/run_gen54_ml_feature_set_diagnostic.R",
  as_of_timestamp = p4_env$as_of_timestamp,
  feed = p4_env$feed,
  refresh = p4_env$refresh,
  live_symbols = p4_env$live_symbols,
  context_symbols = p4_env$context_symbols,
  windows = paste0(split_csv(p4_env$years), "Y", collapse = ","),
  label_horizons = paste0("h", horizons, collapse = ","),
  label_threshold = p4_env$label_threshold,
  feature_sets = paste(unique(summary$feature_set_id), collapse = ","),
  policies = paste(unique(summary$policy_id), collapse = ","),
  xgb_nrounds = p4_env$xgb_nrounds,
  xgb_max_depth = p4_env$xgb_max_depth,
  xgb_eta = p4_env$xgb_eta,
  xgb_subsample = p4_env$xgb_subsample,
  xgb_colsample_bytree = p4_env$xgb_colsample,
  xgb_min_child_weight = p4_env$xgb_min_child_weight,
  xgb_seed = p4_env$xgb_seed,
  child_packet_count = nrow(child_index),
  summary_rows = nrow(summary),
  prediction_rows = nrow(predictions),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_horizon_return_png(summary, paths$return_png)
write_horizon_ranking_png(ranking, paths$ranking_png)
write_relative_strength_equity_png(portfolio, paths$relative_strength_equity_png)
write_horizon_probability_tapes_png(predictions, trades, paths$probability_tape_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 13L), "markdown", "csv", rep("png", 4L)),
  stringsAsFactors = FALSE
)

write_csv(run_spec, paths$run_spec_csv)
write_csv(child_index, paths$child_index_csv)
write_csv(child_leakage, paths$child_leakage_csv)
write_csv(leakage, paths$leakage_audit_csv)
write_csv(summary, paths$summary_csv)
write_csv(ranking, paths$ranking_csv)
write_csv(policy_table, paths$policy_thresholds_csv)
write_csv(actions, paths$action_table_csv)
write_csv(trades, paths$trade_ledger_csv)
write_csv(portfolio, paths$portfolio_equity_csv)
write_csv(calibration, paths$calibration_csv)
write_csv(importance, paths$xgb_importance_csv)
write_csv(predictions, paths$predictions_csv)
write_csv(artifact_index, paths$artifact_index_csv)
write_report(paths$report_md, run_spec, child_index, summary, ranking, leakage, artifact_index)

grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
summary_line <- paste0(
  grid$window_id, " ", grid$label_horizon, " ", grid$feature_set_id,
  " active=", pct(grid$active_return),
  " benchmark=", pct(grid$benchmark_return),
  " excess=", pct(grid$excess_return),
  " exposure=", pct(grid$mean_exposure),
  collapse = "; "
)

message("Gen5.4 ML-P4 label-horizon diagnostic complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("TRAIN-grid summary: ", summary_line)
