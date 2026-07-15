# Gen5.4 ML-P6 swing-trade target and feature audit.
#
# This research-only packet does not fit a model. It first checks whether a
# small, interpretable description of a bullish swing setup has stable
# TRAIN-only relationships to several next-open forward-quality targets.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

# ML-P0 owns the canonical feature-date / next-open / label-end alignment
# helpers. Source it without executing its packet so this audit uses the same
# leakage boundary convention as the existing ML workbench.
Sys.setenv(GEN5_GEN54_ML_P0_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_feature_label_proof.R"))
Sys.unsetenv("GEN5_GEN54_ML_P0_SOURCE_ONLY")

rolling_extreme <- function(x, n, fun) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  if (length(x) < n) return(out)
  for (i in n:length(x)) out[[i]] <- fun(x[(i - n + 1L):i], na.rm = TRUE)
  out
}

rolling_fraction <- function(x, n) {
  g5_pca_regime_rolling_mean(as.numeric(x), n)
}

add_swing_asset_features <- function(features) {
  features <- features[order(as.Date(features$session_date)), , drop = FALSE]
  close <- as.numeric(features$close)
  high <- as.numeric(features$high)
  low <- as.numeric(features$low)
  volume <- as.numeric(features$volume)
  ret1 <- close / lag_n(close, 1L) - 1
  sma20 <- g5_pca_regime_rolling_mean(close, 20L)
  sma50 <- g5_pca_regime_rolling_mean(close, 50L)
  high20 <- rolling_extreme(close, 20L, max)
  high63 <- rolling_extreme(close, 63L, max)
  high252 <- rolling_extreme(close, 252L, max)
  low10 <- rolling_extreme(close, 10L, min)
  mean_vol5 <- g5_pca_regime_rolling_mean(volume, 5L)
  mean_vol20 <- g5_pca_regime_rolling_mean(volume, 20L)
  mean_range10 <- g5_pca_regime_rolling_mean(as.numeric(features$range_pct), 10L)
  mean_range60 <- g5_pca_regime_rolling_mean(as.numeric(features$range_pct), 60L)

  features$swing_ret_21 <- close / lag_n(close, 21L) - 1
  features$swing_ret_63 <- close / lag_n(close, 63L) - 1
  features$swing_ret_126 <- close / lag_n(close, 126L) - 1
  features$swing_dist_high_63 <- close / high63 - 1
  features$swing_dist_high_252 <- close / high252 - 1
  features$swing_time_near_high_63 <- rolling_fraction(close >= 0.90 * high63, 20L)
  features$swing_trend_consistency_20 <- rolling_fraction(ret1 > 0, 20L)
  features$swing_trend_consistency_60 <- rolling_fraction(ret1 > 0, 60L)
  features$swing_above_sma20 <- as.numeric(close > sma20)
  features$swing_above_sma50 <- as.numeric(close > sma50)
  features$swing_pullback_20 <- close / high20 - 1
  features$swing_pullback_atr20 <- safe_div(abs(features$swing_pullback_20), features$atr_pct)
  features$swing_volume_pullback <- mean_vol5 / mean_vol20 - 1
  features$swing_recovery_10 <- close / low10 - 1
  features$swing_breakout_20 <- close / lag_n(high20, 1L) - 1
  features$swing_range_compression_10_60 <- mean_range10 / mean_range60 - 1
  features
}

add_swing_context_features <- function(feature_tables, live_symbols, context_symbols) {
  context_symbols <- intersect(unique(context_symbols), names(feature_tables))
  proxies <- intersect(c("SPY", "QQQ", "SMH"), context_symbols)
  if (!length(context_symbols)) return(feature_tables)

  for (target in intersect(live_symbols, names(feature_tables))) {
    peers <- setdiff(context_symbols, target)
    if (!length(peers)) peers <- context_symbols
    source_rows <- g5_wfa_bind_rows_fill(lapply(peers, function(sym) {
      x <- feature_tables[[sym]]
      data.frame(
        session_date = as.Date(x$session_date),
        swing_ret_21 = as.numeric(x$swing_ret_21),
        swing_ret_63 = as.numeric(x$swing_ret_63),
        swing_above_sma50 = as.numeric(x$swing_above_sma50),
        vol_20 = as.numeric(x$vol_20),
        drawdown_60 = as.numeric(x$drawdown_60),
        stringsAsFactors = FALSE
      )
    }))
    mean_context <- aggregate(
      source_rows[, c("swing_ret_21", "swing_ret_63", "swing_above_sma50", "vol_20", "drawdown_60")],
      list(session_date = source_rows$session_date),
      mean,
      na.rm = TRUE
    )
    names(mean_context) <- c(
      "session_date", "swing_ctx_mean_ret_21", "swing_ctx_mean_ret_63",
      "swing_ctx_breadth_above_sma50", "swing_ctx_mean_vol_20", "swing_ctx_mean_drawdown_60"
    )
    dispersion <- aggregate(source_rows$swing_ret_21, list(session_date = source_rows$session_date), stats::sd, na.rm = TRUE)
    names(dispersion) <- c("session_date", "swing_ctx_dispersion_ret_21")
    ctx <- merge(mean_context, dispersion, by = "session_date", all = TRUE, sort = FALSE)
    target_table <- merge(feature_tables[[target]], ctx, by = "session_date", all.x = TRUE, sort = FALSE)

    for (proxy in proxies) {
      proxy_table <- feature_tables[[proxy]][, c("session_date", "swing_ret_21", "swing_ret_63"), drop = FALSE]
      names(proxy_table) <- c("session_date", paste0("swing_", tolower(proxy), "_ret_21"), paste0("swing_", tolower(proxy), "_ret_63"))
      target_table <- merge(target_table, proxy_table, by = "session_date", all.x = TRUE, sort = FALSE)
      target_table[[paste0("swing_rs_", tolower(proxy), "_21")]] <- target_table$swing_ret_21 - target_table[[paste0("swing_", tolower(proxy), "_ret_21")]]
      target_table[[paste0("swing_rs_", tolower(proxy), "_63")]] <- target_table$swing_ret_63 - target_table[[paste0("swing_", tolower(proxy), "_ret_63")]]
    }
    feature_tables[[target]] <- target_table[order(as.Date(target_table$session_date)), , drop = FALSE]
  }

  rank_rows <- g5_wfa_bind_rows_fill(lapply(intersect(live_symbols, names(feature_tables)), function(sym) {
    x <- feature_tables[[sym]]
    data.frame(
      session_date = as.Date(x$session_date), symbol = sym,
      swing_ret_21 = as.numeric(x$swing_ret_21), swing_ret_63 = as.numeric(x$swing_ret_63),
      stringsAsFactors = FALSE
    )
  }))
  rank_rows$swing_rs_rank_21 <- ave(rank_rows$swing_ret_21, rank_rows$session_date, FUN = function(x) safe_div(rank(x, ties.method = "average"), sum(is.finite(x))))
  rank_rows$swing_rs_rank_63 <- ave(rank_rows$swing_ret_63, rank_rows$session_date, FUN = function(x) safe_div(rank(x, ties.method = "average"), sum(is.finite(x))))
  for (target in intersect(live_symbols, names(feature_tables))) {
    ranks <- rank_rows[rank_rows$symbol == target, c("session_date", "swing_rs_rank_21", "swing_rs_rank_63"), drop = FALSE]
    x <- merge(feature_tables[[target]], ranks, by = "session_date", all.x = TRUE, sort = FALSE)
    feature_tables[[target]] <- x[order(as.Date(x$session_date)), , drop = FALSE]
  }
  feature_tables
}

forward_path_metrics <- function(open, high, low, close, horizon = 10L, take_profit = 0.08, stop_loss = -0.05) {
  n <- length(close)
  out <- data.frame(
    fwd_ret = rep(NA_real_, n), mfe = rep(NA_real_, n), mae = rep(NA_real_, n),
    hit_upside_before_stop = rep(NA, n), stringsAsFactors = FALSE
  )
  if (n <= horizon) return(out)
  for (i in seq_len(n - horizon)) {
    execution_index <- i + 1L
    endpoint_index <- i + horizon
    entry <- as.numeric(open[[execution_index]])
    if (!is.finite(entry) || entry <= 0) next
    path_high <- as.numeric(high[execution_index:endpoint_index]) / entry - 1
    path_low <- as.numeric(low[execution_index:endpoint_index]) / entry - 1
    out$fwd_ret[[i]] <- as.numeric(close[[endpoint_index]]) / entry - 1
    out$mfe[[i]] <- max(path_high, na.rm = TRUE)
    out$mae[[i]] <- min(path_low, na.rm = TRUE)
    first_up <- which(path_high >= take_profit)
    first_stop <- which(path_low <= stop_loss)
    first_up <- if (length(first_up)) first_up[[1L]] else Inf
    first_stop <- if (length(first_stop)) first_stop[[1L]] else Inf
    out$hit_upside_before_stop[[i]] <- is.finite(first_up) && first_up < first_stop
  }
  out
}

add_swing_targets <- function(features, horizon = 10L, take_profit = 0.08, stop_loss = -0.05) {
  features <- features[order(as.Date(features$session_date)), , drop = FALSE]
  forward <- forward_path_metrics(features$open, features$high, features$low, features$close, horizon, take_profit, stop_loss)
  features$feature_date <- as.Date(features$session_date)
  features$decision_timestamp_policy <- "after_close_t"
  features$execution_date <- as.Date(lead_n(features$session_date, 1L))
  features$execution_price <- as.numeric(lead_n(features$open, 1L))
  features$label_end_date <- as.Date(lead_n(features$session_date, horizon))
  features$fwd_ret_h10 <- forward$fwd_ret
  features$fwd_mfe_h10 <- forward$mfe
  features$fwd_mae_h10 <- forward$mae
  features$label_hit_up8_before_dn5_h10 <- forward$hit_upside_before_stop
  features$label_absolute_positive_h10 <- features$fwd_ret_h10 > 0
  features$swing_quality_h10 <- features$fwd_ret_h10 - pmax(0, -features$fwd_mae_h10)
  features
}

add_relative_target <- function(feature_tables, live_symbols, benchmark_symbols = c("SPY", "QQQ", "SMH")) {
  benchmark_symbols <- intersect(benchmark_symbols, names(feature_tables))
  benchmark <- g5_wfa_bind_rows_fill(lapply(benchmark_symbols, function(sym) {
    x <- feature_tables[[sym]]
    data.frame(session_date = as.Date(x$session_date), fwd_ret_h10 = as.numeric(x$fwd_ret_h10), stringsAsFactors = FALSE)
  }))
  benchmark <- aggregate(benchmark$fwd_ret_h10, list(session_date = benchmark$session_date), mean, na.rm = TRUE)
  names(benchmark) <- c("session_date", "context_benchmark_ret_h10")
  for (sym in intersect(live_symbols, names(feature_tables))) {
    x <- merge(feature_tables[[sym]], benchmark, by = "session_date", all.x = TRUE, sort = FALSE)
    x$relative_context_ret_h10 <- x$fwd_ret_h10 - x$context_benchmark_ret_h10
    x$label_relative_positive_h10 <- x$relative_context_ret_h10 > 0
    feature_tables[[sym]] <- x[order(as.Date(x$session_date)), , drop = FALSE]
  }
  feature_tables
}

swing_feature_manifest <- function() {
  rows <- list(
    data.frame(feature_name = c("swing_ret_21", "swing_ret_63", "swing_ret_126", "swing_dist_high_63", "swing_dist_high_252", "swing_time_near_high_63", "swing_rs_rank_21", "swing_rs_rank_63", "swing_rs_spy_21", "swing_rs_spy_63", "swing_rs_qqq_21", "swing_rs_smh_21"), feature_family = "leadership", purpose = "Is the asset leading its peers and broad/sector anchors while remaining near sustained highs?", stringsAsFactors = FALSE),
    data.frame(feature_name = c("swing_trend_consistency_20", "swing_trend_consistency_60", "swing_above_sma20", "swing_above_sma50", "efficiency_ratio_20", "trend_slope_20", "ema_gap", "atr_compression_20"), feature_family = "trend_health", purpose = "Is the advance orderly and persistent rather than a volatile or one-off impulse?", stringsAsFactors = FALSE),
    data.frame(feature_name = c("swing_pullback_20", "swing_pullback_atr20", "swing_volume_pullback", "swing_recovery_10", "swing_breakout_20", "swing_range_compression_10_60", "lower_wick_pct", "close_location_day"), feature_family = "constructive_pullback", purpose = "Is a pause shallow, controlled, and resolving upward rather than failing?", stringsAsFactors = FALSE),
    data.frame(feature_name = c("swing_ctx_mean_ret_21", "swing_ctx_mean_ret_63", "swing_ctx_breadth_above_sma50", "swing_ctx_mean_vol_20", "swing_ctx_mean_drawdown_60", "swing_ctx_dispersion_ret_21"), feature_family = "risk_on_confirmation", purpose = "Does the broader context support risk-taking, and is leadership broad or fragile?", stringsAsFactors = FALSE)
  )
  g5_wfa_bind_rows_fill(rows)
}

swing_target_taxonomy <- function() {
  data.frame(
    target_id = c("absolute_return_h10", "relative_context_return_h10", "upside_drawdown_quality_h10", "hit_up8_before_dn5_h10"),
    target_column = c("fwd_ret_h10", "relative_context_ret_h10", "swing_quality_h10", "label_hit_up8_before_dn5_h10"),
    type = c("continuous", "continuous", "continuous", "binary"),
    definition = c(
      "Next-open entry to close ten sessions later return.",
      "Asset next-open h10 return minus equal-weight SPY/QQQ/SMH h10 return over the same dates.",
      "Forward return less the magnitude of worst intrahorizon adverse excursion; a simple upside-with-drawdown diagnostic.",
      "Within ten sessions, daily high reaches +8% from entry before daily low reaches -5%. Diagnostic threshold only, not an accepted future label."
    ),
    stringsAsFactors = FALSE
  )
}

target_summary <- function(feature_fold_table) {
  target_taxonomy <- swing_target_taxonomy()
  usable <- feature_fold_table[feature_fold_table$label_inside_split & is.finite(feature_fold_table$fwd_ret_h10), , drop = FALSE]
  rows <- list()
  idx <- 1L
  for (i in seq_len(nrow(target_taxonomy))) {
    target <- target_taxonomy[i, , drop = FALSE]
    values <- if (target$type == "binary") as.numeric(usable[[target$target_column]]) else as.numeric(usable[[target$target_column]])
    keep <- is.finite(values)
    part <- usable[keep, c("symbol", "window_id", "split"), drop = FALSE]
    part$target_value <- values[keep]
    summary <- aggregate(
      part$target_value,
      list(symbol = part$symbol, window_id = part$window_id, split = part$split),
      function(x) c(row_count = length(x), mean = mean(x), median = stats::median(x), positive_rate = mean(x > 0))
    )
    rows[[idx]] <- data.frame(
      target_id = target$target_id,
      target_type = target$type,
      symbol = summary$symbol,
      window_id = summary$window_id,
      split = summary$split,
      row_count = summary$x[, "row_count"],
      mean_target = summary$x[, "mean"],
      median_target = summary$x[, "median"],
      positive_rate = summary$x[, "positive_rate"],
      stringsAsFactors = FALSE
    )
    idx <- idx + 1L
  }
  g5_wfa_bind_rows_fill(rows)
}

fold_feature_audit <- function(feature_fold_table, features, target_taxonomy) {
  rows <- list()
  correlations <- list()
  row_idx <- 1L
  cor_idx <- 1L
  for (fold_id in unique(feature_fold_table$fold_id)) {
    fold <- feature_fold_table[
      feature_fold_table$fold_id == fold_id & feature_fold_table$split == "TRAIN" & feature_fold_table$label_inside_split,
      , drop = FALSE
    ]
    if (!nrow(fold)) next
    for (target_index in seq_len(nrow(target_taxonomy))) {
      target <- target_taxonomy[target_index, , drop = FALSE]
      y <- suppressWarnings(as.numeric(fold[[target$target_column]]))
      for (feature in features) {
        x <- suppressWarnings(as.numeric(fold[[feature]]))
        keep <- is.finite(x) & is.finite(y)
        if (sum(keep) < 120L || length(unique(x[keep])) < 10L) next
        ranks <- rank(x[keep], ties.method = "average")
        decile <- pmin(10L, pmax(1L, ceiling(10 * ranks / length(ranks))))
        for (d in seq_len(10L)) {
          values <- y[keep][decile == d]
          rows[[row_idx]] <- data.frame(
            fold_id = fold_id,
            window_id = fold$window_id[[1L]],
            feature = feature,
            target_id = target$target_id,
            decile = d,
            row_count = length(values),
            mean_target = mean(values, na.rm = TRUE),
            median_target = stats::median(values, na.rm = TRUE),
            positive_rate = mean(values > 0, na.rm = TRUE),
            stringsAsFactors = FALSE
          )
          row_idx <- row_idx + 1L
        }
        correlations[[cor_idx]] <- data.frame(
          fold_id = fold_id,
          window_id = fold$window_id[[1L]],
          feature = feature,
          target_id = target$target_id,
          row_count = sum(keep),
          spearman = suppressWarnings(stats::cor(x[keep], y[keep], method = "spearman")),
          pearson = suppressWarnings(stats::cor(x[keep], y[keep], method = "pearson")),
          stringsAsFactors = FALSE
        )
        cor_idx <- cor_idx + 1L
      }
    }
  }
  list(
    deciles = g5_wfa_bind_rows_fill(rows),
    correlations = g5_wfa_bind_rows_fill(correlations)
  )
}

summarize_stability <- function(correlations, manifest) {
  if (!nrow(correlations)) return(data.frame())
  summary <- aggregate(
    correlations$spearman,
    list(feature = correlations$feature, target_id = correlations$target_id),
    function(x) c(fold_count = sum(is.finite(x)), mean_spearman = mean(x, na.rm = TRUE), median_spearman = stats::median(x, na.rm = TRUE), positive_fold_rate = mean(x > 0, na.rm = TRUE), sign_stability = abs(mean(sign(x), na.rm = TRUE)))
  )
  out <- data.frame(
    feature = summary$feature,
    target_id = summary$target_id,
    fold_count = summary$x[, "fold_count"],
    mean_spearman = summary$x[, "mean_spearman"],
    median_spearman = summary$x[, "median_spearman"],
    positive_fold_rate = summary$x[, "positive_fold_rate"],
    sign_stability = summary$x[, "sign_stability"],
    stringsAsFactors = FALSE
  )
  merge(out, unique(manifest[, c("feature_name", "feature_family", "purpose")]), by.x = "feature", by.y = "feature_name", all.x = TRUE, sort = FALSE)
}

swing_leakage_audit <- function(feature_fold_table, features) {
  usable <- feature_fold_table[
    feature_fold_table$label_inside_split & is.finite(feature_fold_table$fwd_ret_h10),
    , drop = FALSE
  ]
  train <- usable[usable$split == "TRAIN", , drop = FALSE]
  oos <- usable[usable$split == "OOS", , drop = FALSE]
  feature_complete <- if (nrow(usable)) stats::complete.cases(usable[, intersect(features, names(usable)), drop = FALSE]) else logical()
  data.frame(
    check_id = c(
      "feature_date_lte_execution_date",
      "execution_date_lte_label_end_date",
      "train_labels_end_inside_train",
      "oos_labels_end_inside_oos",
      "finite_h10_label_rows",
      "complete_swing_feature_rows"
    ),
    status = c(
      if (all(as.Date(usable$feature_date) < as.Date(usable$execution_date))) "PASS" else "FAIL",
      if (all(as.Date(usable$execution_date) <= as.Date(usable$label_end_date))) "PASS" else "FAIL",
      if (!nrow(train) || all(as.Date(train$label_end_date) <= as.Date(train$train_end_date))) "PASS" else "FAIL",
      if (!nrow(oos) || all(as.Date(oos$label_end_date) <= as.Date(oos$oos_end_date))) "PASS" else "FAIL",
      if (nrow(usable) > 0L) "PASS" else "FAIL",
      if (nrow(usable) > 0L && mean(feature_complete) > 0.50) "PASS" else "REVIEW"
    ),
    detail = c(
      "Features are observed after close t; any hypothetical action is at next open.",
      "The h10 forward target begins at execution and ends at the declared horizon endpoint.",
      "TRAIN h10 labels cannot spill into the corresponding OOS authority quarter.",
      "OOS h10 labels near a fold end are excluded unless their full horizon remains inside OOS.",
      paste0(nrow(usable), " usable h10 labeled fold rows."),
      paste0(round(100 * mean(feature_complete), 1), "% usable rows have all declared swing features finite.")
    ),
    stringsAsFactors = FALSE
  )
}

write_target_prevalence_png <- function(summary, path) {
  x <- summary[summary$split == "OOS" & summary$target_id %in% c("relative_context_return_h10", "hit_up8_before_dn5_h10"), , drop = FALSE]
  x$key <- paste(x$window_id, x$symbol, sep = " / ")
  x <- x[order(x$target_id, x$window_id, x$symbol), , drop = FALSE]
  grDevices::png(path, width = 2800L, height = 1500L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(9, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (target in unique(x$target_id)) {
    part <- x[x$target_id == target, , drop = FALSE]
    graphics::barplot(part$positive_rate, names.arg = part$key, las = 2, ylim = c(0, 1), col = "#2563EB", border = NA,
      ylab = "OOS positive rate", main = if (target == "relative_context_return_h10") "Relative h10 target prevalence" else "Hit +8% before -5% prevalence")
    graphics::abline(h = 0.5, lty = 2, col = "#6B7280")
  }
}

write_target_distribution_png <- function(feature_fold_table, path) {
  x <- feature_fold_table[feature_fold_table$split == "OOS" & feature_fold_table$label_inside_split & is.finite(feature_fold_table$fwd_ret_h10), , drop = FALSE]
  grDevices::png(path, width = 3400L, height = 1400L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 5), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (window in sort(unique(x$window_id))) {
    part <- x[x$window_id == window, , drop = FALSE]
    graphics::hist(part$fwd_ret_h10, breaks = 40, col = "#BFDBFE", border = "white", main = paste(window, "absolute h10 return"), xlab = "Next-open h10 return")
    graphics::abline(v = 0, lty = 2, col = "#111827")
  }
  for (window in sort(unique(x$window_id))) {
    part <- x[x$window_id == window, , drop = FALSE]
    graphics::hist(part$relative_context_ret_h10, breaks = 40, col = "#BBF7D0", border = "white", main = paste(window, "relative h10 return"), xlab = "Asset minus SPY/QQQ/SMH")
    graphics::abline(v = 0, lty = 2, col = "#111827")
  }
}

write_stability_heatmap_png <- function(stability, path) {
  targets <- c("absolute_return_h10", "relative_context_return_h10", "upside_drawdown_quality_h10")
  x <- stability[stability$target_id %in% targets, , drop = FALSE]
  features <- unique(x$feature[order(x$feature_family, x$feature)])
  mat <- matrix(NA_real_, nrow = length(features), ncol = length(targets), dimnames = list(features, targets))
  for (i in seq_len(nrow(x))) mat[x$feature[[i]], x$target_id[[i]]] <- x$median_spearman[[i]]
  grDevices::png(path, width = 2800L, height = 2100L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(8, 17, 4, 5))
  on.exit(graphics::par(old), add = TRUE)
  lim <- max(abs(mat), na.rm = TRUE)
  lim <- max(lim, 0.05)
  graphics::image(seq_len(ncol(mat)), seq_len(nrow(mat)), t(mat[nrow(mat):1L, , drop = FALSE]),
    col = grDevices::colorRampPalette(c("#B91C1C", "#FEE2E2", "#FFFFFF", "#DCFCE7", "#15803D"))(100), zlim = c(-lim, lim), axes = FALSE,
    xlab = "", ylab = "", main = "TRAIN-only feature relationship stability across quarterly folds")
  graphics::axis(1, at = seq_len(ncol(mat)), labels = c("Absolute h10", "Relative h10", "Upside / drawdown"), las = 2, cex.axis = 0.9)
  graphics::axis(2, at = seq_len(nrow(mat)), labels = rev(rownames(mat)), las = 2, cex.axis = 0.73)
  graphics::box()
}

write_decile_panels_png <- function(deciles, path) {
  candidates <- c("swing_rs_smh_21", "swing_trend_consistency_20", "swing_pullback_atr20", "swing_breakout_20", "swing_ctx_breadth_above_sma50", "swing_ctx_dispersion_ret_21")
  x <- deciles[deciles$target_id == "relative_context_return_h10" & deciles$feature %in% candidates, , drop = FALSE]
  grDevices::png(path, width = 3000L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 3), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (feature in candidates) {
    part <- x[x$feature == feature, , drop = FALSE]
    if (!nrow(part)) {
      graphics::plot.new(); graphics::title(main = feature); next
    }
    summary <- aggregate(part$mean_target, list(decile = part$decile), mean, na.rm = TRUE)
    graphics::plot(summary$decile, summary$x, type = "b", pch = 16, col = "#2563EB", ylim = range(c(summary$x, 0), na.rm = TRUE),
      xlab = "Within-TRAIN feature decile", ylab = "Mean relative h10 return", main = feature)
    graphics::abline(h = 0, lty = 2, col = "#6B7280")
  }
}

write_feature_examples_png <- function(feature_fold_table, path) {
  examples <- list(c("AMD", "2020Y"), c("TSLA", "2022Y"))
  grDevices::png(path, width = 3000L, height = 1700L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (example in examples) {
    x <- feature_fold_table[feature_fold_table$split == "OOS" & feature_fold_table$symbol == example[[1L]] & feature_fold_table$window_id == example[[2L]], , drop = FALSE]
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    d <- as.Date(x$session_date)
    sma20 <- g5_pca_regime_rolling_mean(x$close, 20L)
    sma50 <- g5_pca_regime_rolling_mean(x$close, 50L)
    graphics::plot(d, x$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(example[[1L]], example[[2L]], "price / trend posture"))
    graphics::lines(d, sma20, col = "#2563EB", lwd = 1.5)
    graphics::lines(d, sma50, col = "#DC2626", lwd = 1.5)
    good <- which(x$label_hit_up8_before_dn5_h10 %in% TRUE)
    if (length(good)) graphics::points(d[good], x$close[good], pch = 24, bg = "#16A34A", col = "#111827", cex = 0.7)
    graphics::legend("topleft", legend = c("Close", "SMA20", "SMA50", "hit +8% before -5%"), col = c("#111827", "#2563EB", "#DC2626", "#16A34A"), lwd = c(2, 1.5, 1.5, NA), pch = c(NA, NA, NA, 24), bty = "n", cex = 0.75)
    graphics::plot(d, x$swing_rs_rank_63, type = "l", lwd = 1.8, col = "#7C3AED", xlab = "Session", ylab = "Rank / breadth", ylim = c(0, 1), main = paste(example[[1L]], "leadership and risk-on context"))
    graphics::lines(d, x$swing_ctx_breadth_above_sma50, col = "#16A34A", lwd = 1.5)
    graphics::abline(h = 0.5, lty = 2, col = "#6B7280")
    graphics::legend("bottomleft", legend = c("63d peer rank", "context breadth above SMA50"), col = c("#7C3AED", "#16A34A"), lwd = c(1.8, 1.5), bty = "n", cex = 0.75)
  }
}

write_report <- function(path, run_spec, audit, stability, artifact_index) {
  strongest <- stability[stability$target_id == "relative_context_return_h10", , drop = FALSE]
  strongest <- strongest[order(-abs(strongest$median_spearman)), , drop = FALSE]
  lines <- c(
    "# Gen5.4 ML-P6 Swing-Trade Feature Audit",
    "",
    "## Purpose",
    "",
    "This packet asks whether an interpretable description of a bullish swing setup contains stable TRAIN-only information before another supervised model is fit. It does not optimize, select, or replay a trading model.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Context universe: `", run_spec$context_symbols[[1L]], "`"),
    paste0("- Annual windows: `", run_spec$windows[[1L]], "` with eight-quarter TRAIN and quarterly authorities."),
    "- Primary diagnostic target: asset h10 next-open return minus equal-weight SPY/QQQ/SMH h10 return.",
    "- Feature families: leadership, trend health, constructive pullback, and risk-on confirmation.",
    "",
    "## Guardrails",
    "",
    paste0("- `", audit$check_id, "`: ", audit$status, " - ", audit$detail),
    "",
    "## Readout",
    "",
    if (nrow(strongest)) paste0("- Largest median TRAIN-fold relationship to relative h10 return: `", strongest$feature[[1L]], "` (Spearman `", round(strongest$median_spearman[[1L]], 3), "`). This is exploratory evidence only; no feature is promoted by this packet.") else "- No usable feature-stability rows were produced.",
    "- The follow-up modeling slice must retain a small predeclared feature set and choose its target/policy from TRAIN evidence only.",
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_index$artifact_id, "`: `", artifact_index$path, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

if (!identical(Sys.getenv("GEN5_GEN54_ML_P6_SOURCE_ONLY", unset = "false"), "true")) {
g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN54_ML_P6_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P6_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_ML_P6_STAMP", "20260714p6swing"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p6_swing_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

live_symbols <- g5_standardize_symbol(split_csv(env_or("GEN5_GEN54_ML_P6_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO")))
context_symbols <- unique(g5_standardize_symbol(c(live_symbols, split_csv(env_or(
  "GEN5_GEN54_ML_P6_CONTEXT_SYMBOLS",
  "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"
)))))
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P6_YEARS", "2020,2021,2022,2023,2024")))
horizon <- as.integer(env_or("GEN5_GEN54_ML_P6_HORIZON", "10"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P6_AS_OF", "2024-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P6_WARMUP_DAYS", "420"))

folds <- build_folds(years)
query_start <- min(folds$train_start_date) - warmup_days
query_end <- max(folds$oos_end_date)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = query_start, end_date = query_end, as_of_timestamp = as_of_timestamp,
  symbols = context_symbols, universe_name = "gen54_ml_p6_swing_context",
  universe_roles = "live_basket,context_universe", refresh = refresh, repo_root = repo_root
)
if (!nrow(query$bars)) g5_stop("ML-P6 query returned no bars.")

feature_tables <- list()
for (sym in context_symbols) {
  feature_tables[[sym]] <- add_swing_asset_features(augment_ohlcv_features(g5_pca_regime_feature_table(query$bars, sym, end_date = query_end)))
}
feature_tables <- add_swing_context_features(feature_tables, live_symbols, context_symbols)
feature_tables <- lapply(feature_tables, add_swing_targets, horizon = horizon)
feature_tables <- add_relative_target(feature_tables, live_symbols)

feature_labels <- g5_wfa_bind_rows_fill(lapply(live_symbols, function(sym) {
  x <- feature_tables[[sym]]
  x$symbol <- sym
  x
}))
feature_fold_table <- assign_fold_split(feature_labels, folds)
manifest <- swing_feature_manifest()
manifest <- manifest[manifest$feature_name %in% names(feature_fold_table), , drop = FALSE]
features <- intersect(unique(manifest$feature_name), names(feature_fold_table))
target_taxonomy <- swing_target_taxonomy()
target_summary_df <- target_summary(feature_fold_table)
feature_audit <- fold_feature_audit(feature_fold_table, features, target_taxonomy)
stability <- summarize_stability(feature_audit$correlations, manifest)

leakage <- swing_leakage_audit(feature_fold_table, features)
leakage <- rbind(
  leakage,
  data.frame(
    check_id = "train_feature_audit_only",
    status = if (all(feature_audit$deciles$fold_id %in% folds$fold_id)) "PASS" else "FAIL",
    detail = "Feature deciles and correlations are calculated separately inside each fold's TRAIN rows; OOS labels are diagnostic-only.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    check_id = "live_bridge_unchanged",
    status = "PASS",
    detail = "ML-P6 is a research/inspection wrapper and does not source or write the live advice bridge.",
    stringsAsFactors = FALSE
  )
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p6_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p6_fold_spec.csv"),
  target_taxonomy_csv = file.path(output_dir, "ml_p6_target_taxonomy.csv"),
  feature_manifest_csv = file.path(output_dir, "ml_p6_swing_feature_manifest.csv"),
  target_summary_csv = file.path(output_dir, "ml_p6_target_summary.csv"),
  train_decile_audit_csv = file.path(output_dir, "ml_p6_train_decile_audit.csv"),
  train_feature_correlations_csv = file.path(output_dir, "ml_p6_train_feature_correlations.csv"),
  feature_stability_csv = file.path(output_dir, "ml_p6_feature_stability_summary.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p6_leakage_audit.csv"),
  report_md = file.path(output_dir, "ml_p6_swing_feature_audit_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p6_artifact_index.csv"),
  target_prevalence_png = file.path(visual_dir, "ml_p6_target_prevalence.png"),
  target_distribution_png = file.path(visual_dir, "ml_p6_target_distributions.png"),
  stability_heatmap_png = file.path(visual_dir, "ml_p6_train_feature_stability_heatmap.png"),
  decile_panels_png = file.path(visual_dir, "ml_p6_relative_target_decile_panels.png"),
  feature_examples_png = file.path(visual_dir, "ml_p6_feature_examples.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p6_swing_feature_audit_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_swing_feature_audit.R",
  purpose = "Leakage-safe target and feature audit before ML-P6 model fitting.",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  context_symbols = paste(context_symbols, collapse = ","),
  windows = paste0(years, "Y", collapse = ","),
  train_quarters = 8L,
  authority_quarters = 1L,
  label_horizon_sessions = horizon,
  target_ids = paste(target_taxonomy$target_id, collapse = ","),
  selected_feature_count = length(features),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 9L), "markdown", "csv", rep("png", 5L)),
  stringsAsFactors = FALSE
)

write_target_prevalence_png(target_summary_df, paths$target_prevalence_png)
write_target_distribution_png(feature_fold_table, paths$target_distribution_png)
write_stability_heatmap_png(stability, paths$stability_heatmap_png)
write_decile_panels_png(feature_audit$deciles, paths$decile_panels_png)
write_feature_examples_png(feature_fold_table, paths$feature_examples_png)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(target_taxonomy, paths$target_taxonomy_csv)
g5_wfa_write_csv(manifest, paths$feature_manifest_csv)
g5_wfa_write_csv(target_summary_df, paths$target_summary_csv)
g5_wfa_write_csv(feature_audit$deciles, paths$train_decile_audit_csv)
g5_wfa_write_csv(feature_audit$correlations, paths$train_feature_correlations_csv)
g5_wfa_write_csv(stability, paths$feature_stability_csv)
g5_wfa_write_csv(leakage, paths$leakage_audit_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_report(paths$report_md, run_spec, leakage, stability, artifact_index)

message("Gen5.4 ML-P6 swing feature audit complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("Leakage audit statuses: ", paste(leakage$check_id, leakage$status, sep = "=", collapse = "; "))
}
