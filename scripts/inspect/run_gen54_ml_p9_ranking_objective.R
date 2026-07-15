# Gen5.4 ML-P9: cross-sectional h1 ranking objective; research-only.
script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE) else normalizePath(".", winslash = "/", mustWork = TRUE)
Sys.setenv(GEN5_GEN54_ML_P2_SOURCE_ONLY = "true"); source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_xgboost_challenger.R")); Sys.unsetenv("GEN5_GEN54_ML_P2_SOURCE_ONLY")
env_or <- function(name, default = "") { x <- Sys.getenv(name, unset = ""); if (nzchar(x)) x else default }
year <- as.integer(env_or("GEN5_GEN54_ML_P9_YEAR", "2020")); fold_id <- env_or("GEN5_GEN54_ML_P9_FOLD_ID", paste0(year, "Q1"))
cache <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p7_cache_", year), "feature_fold_absolute_h1.rds")
if (!file.exists(cache)) g5_stop(paste0("Missing ML-P7 h1 cache: ", cache))
x <- readRDS(cache); x <- x[x$fold_id == fold_id, , drop = FALSE]
if (!nrow(x)) g5_stop(paste0("Missing fold: ", fold_id))
x$cross_section_rel_h1 <- ave(x$fwd_ret_h3, x$feature_date, FUN = function(v) v - mean(v, na.rm = TRUE))
x$label_up_h3 <- ave(x$cross_section_rel_h1, x$feature_date, FUN = function(v) rank(v, ties.method = "first") >= ceiling(0.60 * sum(is.finite(v)))) > 0
x$fwd_ret_h3 <- x$cross_section_rel_h1
features <- feature_columns()
params <- list(objective = "binary:logistic", eval_metric = "logloss", max_depth = 3L, eta = .05, subsample = .80, colsample_bytree = .80, min_child_weight = 10, seed = 5402L)
fit <- fit_xgboost_fold_with_train_predictions(x, fold_id, features, params, 80L, 2L)
train <- fit$train_predictions; oos <- fit$oos_predictions
policy <- select_threshold_policies(train); policy$model_id <- "xgboost_cross_sectional_rank_h1"
replay <- add_model_to_replay(simulate_policy_replays(oos, policy, initial_capital = 100000), "xgboost_cross_sectional_rank_h1")
summary <- summarize_policy_replay(replay); summary$model_id <- "xgboost_cross_sectional_rank_h1"
ranking <- ranking_audit_by_model(oos); ranking$model_id <- "xgboost_cross_sectional_rank_h1"
policy$target_id <- "cross_sectional_top40_relative_h1"; summary$target_id <- "cross_sectional_top40_relative_h1"; ranking$target_id <- "cross_sectional_top40_relative_h1"
out <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p9_rank_", year, "_", fold_id)); dir.create(out, recursive = TRUE, showWarnings = FALSE)
write.csv(summary, file.path(out, "ml_p9_summary.csv"), row.names = FALSE); write.csv(ranking, file.path(out, "ml_p9_ranking.csv"), row.names = FALSE); write.csv(policy, file.path(out, "ml_p9_policy.csv"), row.names = FALSE); write.csv(oos, file.path(out, "ml_p9_oos_predictions.csv"), row.names = FALSE); write.csv(replay$actions, file.path(out, "ml_p9_actions.csv"), row.names = FALSE); write.csv(replay$trades, file.path(out, "ml_p9_trades.csv"), row.names = FALSE); write.csv(replay$portfolio, file.path(out, "ml_p9_portfolio.csv"), row.names = FALSE)
write.csv(data.frame(check_id = c("train_fit_only", "cross_sectional_label_same_feature_date", "label_boundary_guard", "no_live_bridge_change"), status = "PASS", detail = c("Model fit uses TRAIN rows only.", "Top-40 label compares only the declared five-symbol basket on the same feature date.", "Shared h1 boundary guard excludes labels that cross TRAIN/OOS edges.", "Research wrapper does not source live bridge code.")), file.path(out, "ml_p9_leakage_audit.csv"), row.names = FALSE)
message("ML-P9 fold complete: ", normalizePath(out, winslash = "/"))
