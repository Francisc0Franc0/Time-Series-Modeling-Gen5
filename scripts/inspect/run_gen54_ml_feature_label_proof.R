# Gen5.4 supervised ML feature/label proof.
#
# This wrapper builds the first leakage-audited supervised-learning table. It
# intentionally does not fit a model.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_poc.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

split_csv <- function(x) {
  x <- trimws(unlist(strsplit(as.character(x), ",", fixed = TRUE), use.names = FALSE))
  x[nzchar(x)]
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) {
    Sys.sleep(0.5)
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(path)) {
    g5_stop(paste0("Could not create required output directory: ", normalizePath(path, winslash = "/", mustWork = FALSE)))
  }
  invisible(path)
}

safe_div <- function(num, den, eps = 1e-8) {
  out <- num / ifelse(abs(den) < eps, NA_real_, den)
  out[!is.finite(out)] <- NA_real_
  out
}

lead_n <- function(x, n) {
  n <- as.integer(n)
  if (n < 1L) return(x)
  if (length(x) <= n) return(rep(NA, length(x)))
  c(x[(n + 1L):length(x)], rep(NA, n))
}

lag_n <- function(x, n) {
  n <- as.integer(n)
  if (n < 1L) return(x)
  if (length(x) <= n) return(rep(NA, length(x)))
  c(rep(NA, n), x[seq_len(length(x) - n)])
}

quarter_end_date <- function(year, quarter) {
  starts <- as.Date(sprintf("%04d-%02d-01", year, c(1L, 4L, 7L, 10L)[quarter]))
  next_start <- if (quarter == 4L) as.Date(sprintf("%04d-01-01", year + 1L)) else as.Date(sprintf("%04d-%02d-01", year, c(4L, 7L, 10L)[quarter]))
  next_start - 1L
}

quarter_start_date <- function(year, quarter) {
  as.Date(sprintf("%04d-%02d-01", year, c(1L, 4L, 7L, 10L)[quarter]))
}

build_folds <- function(years, train_quarters = 8L) {
  rows <- list()
  idx <- 1L
  for (year in years) {
    for (q in seq_len(4L)) {
      oos_start <- quarter_start_date(year, q)
      train_start <- quarter_start_date(year - train_quarters %/% 4L, q)
      rows[[idx]] <- data.frame(
        window_id = paste0(year, "Y"),
        fold_id = paste0(year, "Q", q),
        fold_no = idx,
        train_start_date = train_start,
        train_end_date = oos_start - 1L,
        oos_start_date = oos_start,
        oos_end_date = quarter_end_date(year, q),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

assign_fold_split <- function(feature_labels, folds) {
  rows <- list()
  idx <- 1L
  dates <- as.Date(feature_labels$session_date)
  label_end <- as.Date(feature_labels$label_end_date)
  for (i in seq_len(nrow(folds))) {
    fold <- folds[i, , drop = FALSE]
    train_keep <- dates >= fold$train_start_date & dates <= fold$train_end_date
    oos_keep <- dates >= fold$oos_start_date & dates <= fold$oos_end_date
    for (split in c("TRAIN", "OOS")) {
      keep <- if (split == "TRAIN") train_keep else oos_keep
      if (!any(keep)) next
      part <- feature_labels[keep, , drop = FALSE]
      part$window_id <- fold$window_id
      part$fold_id <- fold$fold_id
      part$fold_no <- fold$fold_no
      part$split <- split
      part$train_start_date <- fold$train_start_date
      part$train_end_date <- fold$train_end_date
      part$oos_start_date <- fold$oos_start_date
      part$oos_end_date <- fold$oos_end_date
      part$label_inside_split <- if (split == "TRAIN") {
        label_end[keep] <= fold$train_end_date
      } else {
        label_end[keep] <= fold$oos_end_date
      }
      rows[[idx]] <- part
      idx <- idx + 1L
    }
  }
  if (!length(rows)) data.frame() else g5_wfa_bind_rows_fill(rows)
}

augment_ohlcv_features <- function(features) {
  features <- features[order(as.Date(features$session_date)), , drop = FALSE]
  close <- as.numeric(features$close)
  open <- as.numeric(features$open)
  high <- as.numeric(features$high)
  low <- as.numeric(features$low)
  volume <- as.numeric(features$volume)
  prior_close <- lag_n(close, 1L)
  range <- high - low
  volume_mean_20 <- g5_pca_regime_rolling_mean(volume, 20L)
  volume_sd_20 <- g5_pca_regime_rolling_sd(volume, 20L)
  atr_mean_20 <- g5_pca_regime_rolling_mean(features$atr_pct, 20L)
  features$ret_3 <- close / lag_n(close, 3L) - 1
  features$ret_10 <- close / lag_n(close, 10L) - 1
  features$gap_open_pct <- open / prior_close - 1
  features$intraday_oc_ret <- close / open - 1
  features$range_pct <- range / close
  features$body_pct <- abs(close - open) / close
  features$upper_wick_pct <- (high - pmax(open, close)) / close
  features$lower_wick_pct <- (pmin(open, close) - low) / close
  features$close_location_day <- safe_div(close - low, range)
  features$volume_z20 <- safe_div(volume - volume_mean_20, volume_sd_20)
  features$rel_volume_20 <- volume / volume_mean_20 - 1
  features$log_dollar_volume <- log(pmax(close * volume, 1))
  features$atr_compression_20 <- features$atr_pct / atr_mean_20 - 1
  features
}

add_market_relative_features <- function(feature_tables, live_symbols, context_symbols) {
  proxies <- intersect(c("SPY", "QQQ", "SMH"), names(feature_tables))
  if (!length(proxies)) return(feature_tables)
  proxy_rows <- do.call(rbind, lapply(proxies, function(sym) {
    x <- feature_tables[[sym]]
    data.frame(
      session_date = as.Date(x$session_date),
      proxy_symbol = sym,
      proxy_ret_5 = x$ret_5,
      proxy_ret_20 = x$ret_20,
      proxy_ret_60 = x$ret_60,
      stringsAsFactors = FALSE
    )
  }))
  proxy_agg <- aggregate(
    proxy_rows[, c("proxy_ret_5", "proxy_ret_20", "proxy_ret_60")],
    list(session_date = proxy_rows$session_date),
    mean,
    na.rm = TRUE
  )
  names(proxy_agg)[names(proxy_agg) == "proxy_ret_5"] <- "context_mean_ret_5"
  names(proxy_agg)[names(proxy_agg) == "proxy_ret_20"] <- "context_mean_ret_20"
  names(proxy_agg)[names(proxy_agg) == "proxy_ret_60"] <- "context_mean_ret_60"
  for (sym in live_symbols) {
    x <- merge(feature_tables[[sym]], proxy_agg, by = "session_date", all.x = TRUE, sort = FALSE)
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    x$market_rel_ret_5 <- x$ret_5 - x$context_mean_ret_5
    x$market_rel_ret_20 <- x$ret_20 - x$context_mean_ret_20
    x$market_rel_ret_60 <- x$ret_60 - x$context_mean_ret_60
    feature_tables[[sym]] <- x
  }
  feature_tables
}

add_forward_label <- function(features, horizon = 3L, threshold = 0) {
  features <- features[order(as.Date(features$session_date)), , drop = FALSE]
  features$feature_date <- as.Date(features$session_date)
  features$decision_timestamp_policy <- "after_close_t"
  features$execution_date <- as.Date(lead_n(features$session_date, 1L))
  features$execution_price <- as.numeric(lead_n(features$open, 1L))
  features$label_end_date <- as.Date(lead_n(features$session_date, horizon))
  features$label_end_close <- as.numeric(lead_n(features$close, horizon))
  features$fwd_ret_h3 <- features$label_end_close / features$execution_price - 1
  features$label_up_h3 <- features$fwd_ret_h3 > threshold
  features$label_threshold <- threshold
  features$label_horizon_sessions <- horizon
  features
}

feature_taxonomy <- function() {
  data.frame(
    feature_name = c(
      "ret_1/3/5/10/20/60",
      "ema_gap / trend_slope",
      "dist_anchor_50/200",
      "close_location_day/20/60",
      "range_pct / body_pct / wick_pct",
      "vol_20 / atr_pct / atr_compression_20",
      "volume_z20 / rel_volume_20 / log_dollar_volume",
      "drawdown_60 / recovery_from_low_60",
      "market_rel_ret_5/20/60"
    ),
    feature_group = c(
      "recent_return",
      "trend",
      "anchor_distance",
      "range_location",
      "candle_structure",
      "volatility_range",
      "participation",
      "drawdown_recovery",
      "market_relative_context"
    ),
    purpose = c(
      "Capture short and medium impulse without forcing a specific moving-average rule.",
      "Describe trend direction and speed in a smooth way.",
      "Expose whether price is extended or depressed versus slower anchors.",
      "Capture where the close sits inside the day and recent trading range.",
      "Use OHLC information that close-to-close returns discard.",
      "Detect turbulent, quiet, compressed, or expanding conditions.",
      "Capture liquidity and attention shifts.",
      "Separate fresh highs, drawdowns, and recovery behavior.",
      "Ask whether the asset is leading or lagging broad/sector proxies."
    ),
    stringsAsFactors = FALSE
  )
}

feature_columns <- function() {
  unique(c(
    "ret1", "ret_3", "ret_5", "ret_10", "ret_20", "ret_60",
    "ema_gap", "ema_gap_10_50", "ema_gap_20_100", "trend_slope_5", "trend_slope_20",
    "rsi_14", "vol_20", "atr_pct", "atr_compression_20",
    "dist_anchor_50", "dist_anchor_200", "chop_14", "bb_width",
    "efficiency_ratio_20", "z_close_sma20", "ret_skew_20",
    "above_sma20_frac_20", "close_location_day", "close_location_20", "close_location_60",
    "drawdown_60", "recovery_from_low_60", "gap_open_pct", "intraday_oc_ret",
    "range_pct", "body_pct", "upper_wick_pct", "lower_wick_pct",
    "volume_z20", "rel_volume_20", "log_dollar_volume",
    "market_rel_ret_5", "market_rel_ret_20", "market_rel_ret_60"
  ))
}

coverage_summary <- function(feature_fold_table, features) {
  rows <- list()
  idx <- 1L
  for (sym in unique(feature_fold_table$symbol)) {
    for (window in unique(feature_fold_table$window_id)) {
      part <- feature_fold_table[feature_fold_table$symbol == sym & feature_fold_table$window_id == window, , drop = FALSE]
      for (feature in features) {
        if (!feature %in% names(part)) next
        values <- suppressWarnings(as.numeric(part[[feature]]))
        rows[[idx]] <- data.frame(
          symbol = sym,
          window_id = window,
          feature = feature,
          total_rows = nrow(part),
          finite_rows = sum(is.finite(values)),
          finite_rate = mean(is.finite(values)),
          stringsAsFactors = FALSE
        )
        idx <- idx + 1L
      }
    }
  }
  g5_wfa_bind_rows_fill(rows)
}

label_summary <- function(feature_fold_table, features) {
  usable <- feature_fold_table[feature_fold_table$label_inside_split & is.finite(feature_fold_table$fwd_ret_h3), , drop = FALSE]
  complete_features <- stats::complete.cases(usable[, intersect(features, names(usable)), drop = FALSE])
  usable$complete_feature_row <- complete_features
  rows <- aggregate(
    cbind(
      row_count = rep(1, nrow(usable)),
      label_up_count = as.numeric(usable$label_up_h3),
      mean_fwd_ret_h3 = usable$fwd_ret_h3,
      complete_feature_count = as.numeric(usable$complete_feature_row)
    ),
    list(symbol = usable$symbol, window_id = usable$window_id, split = usable$split),
    function(x) c(sum = sum(x, na.rm = TRUE), mean = mean(x, na.rm = TRUE))
  )
  data.frame(
    symbol = rows$symbol,
    window_id = rows$window_id,
    split = rows$split,
    row_count = rows$row_count[, "sum"],
    label_up_count = rows$label_up_count[, "sum"],
    label_up_rate = rows$label_up_count[, "mean"],
    mean_fwd_ret_h3 = rows$mean_fwd_ret_h3[, "mean"],
    complete_feature_count = rows$complete_feature_count[, "sum"],
    complete_feature_rate = rows$complete_feature_count[, "mean"],
    stringsAsFactors = FALSE
  )
}

leakage_audit <- function(feature_fold_table, features) {
  usable <- feature_fold_table[feature_fold_table$label_inside_split & is.finite(feature_fold_table$fwd_ret_h3), , drop = FALSE]
  train <- usable[usable$split == "TRAIN", , drop = FALSE]
  oos <- usable[usable$split == "OOS", , drop = FALSE]
  feature_complete <- if (nrow(usable)) stats::complete.cases(usable[, intersect(features, names(usable)), drop = FALSE]) else logical()
  data.frame(
    check_id = c(
      "feature_date_lte_execution_date",
      "execution_date_lte_label_end_date",
      "train_labels_end_inside_train",
      "oos_labels_end_inside_oos",
      "finite_label_rows",
      "complete_feature_rows"
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
      "Features are observed after close t; next action is next open.",
      "Forward label starts at execution and ends after the declared horizon.",
      "TRAIN labels cannot spill into OOS.",
      "OOS labels near fold end are dropped unless horizon is complete inside OOS.",
      paste0(nrow(usable), " usable labeled fold rows."),
      paste0(round(100 * mean(feature_complete), 1), "% usable rows have all selected features finite.")
    ),
    stringsAsFactors = FALSE
  )
}

decile_audit <- function(feature_fold_table, features) {
  train <- feature_fold_table[
    feature_fold_table$split == "TRAIN" &
      feature_fold_table$label_inside_split &
      is.finite(feature_fold_table$fwd_ret_h3),
    ,
    drop = FALSE
  ]
  rows <- list()
  idx <- 1L
  for (feature in features) {
    if (!feature %in% names(train)) next
    x <- suppressWarnings(as.numeric(train[[feature]]))
    y <- suppressWarnings(as.numeric(train$fwd_ret_h3))
    keep <- is.finite(x) & is.finite(y)
    if (sum(keep) < 100L || length(unique(x[keep])) < 10L) next
    ranks <- rank(x[keep], ties.method = "average")
    dec <- pmin(10L, pmax(1L, ceiling(10 * ranks / length(ranks))))
    for (d in seq_len(10L)) {
      rows[[idx]] <- data.frame(
        feature = feature,
        decile = d,
        row_count = sum(dec == d),
        mean_fwd_ret_h3 = mean(y[keep][dec == d], na.rm = TRUE),
        label_up_rate = mean(train$label_up_h3[keep][dec == d], na.rm = TRUE),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  g5_wfa_bind_rows_fill(rows)
}

write_fold_calendar_png <- function(folds, path) {
  grDevices::png(path, width = 2400L, height = 1200L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(5, 8, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  folds <- folds[order(folds$fold_no), , drop = FALSE]
  x_min <- min(folds$train_start_date)
  x_max <- max(folds$oos_end_date)
  graphics::plot(
    as.Date(c(x_min, x_max)), c(0.5, nrow(folds) + 0.5),
    type = "n", yaxt = "n", xlab = "Calendar date", ylab = "",
    main = "ML-P0 fold calendar and label horizon guardrail"
  )
  graphics::axis(2, at = seq_len(nrow(folds)), labels = rev(folds$fold_id), las = 2, cex.axis = 0.75)
  for (i in seq_len(nrow(folds))) {
    row <- folds[nrow(folds) - i + 1L, , drop = FALSE]
    y <- i
    graphics::rect(row$train_start_date, y - 0.28, row$train_end_date, y + 0.28, col = "#C7D2FE", border = NA)
    graphics::rect(row$oos_start_date, y - 0.28, row$oos_end_date, y + 0.28, col = "#FDBA74", border = NA)
    graphics::segments(row$train_end_date, y - 0.35, row$train_end_date, y + 0.35, col = "#111827", lwd = 1.5)
  }
  graphics::legend(
    "bottomright",
    legend = c("TRAIN feature/label rows", "OOS audit rows", "TRAIN/OOS boundary"),
    fill = c("#C7D2FE", "#FDBA74", NA),
    border = c(NA, NA, NA),
    lty = c(NA, NA, 1),
    col = c(NA, NA, "#111827"),
    bty = "n",
    cex = 0.9
  )
}

write_feature_coverage_png <- function(coverage, path, features_for_plot) {
  grDevices::png(path, width = 2600L, height = 1500L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(9, 10, 4, 6))
  on.exit(graphics::par(old), add = TRUE)
  coverage <- coverage[coverage$feature %in% features_for_plot, , drop = FALSE]
  coverage$key <- paste(coverage$symbol, coverage$window_id, sep = " / ")
  keys <- unique(coverage$key)
  features <- features_for_plot[features_for_plot %in% unique(coverage$feature)]
  mat <- matrix(NA_real_, nrow = length(features), ncol = length(keys), dimnames = list(features, keys))
  for (i in seq_len(nrow(coverage))) {
    mat[coverage$feature[[i]], coverage$key[[i]]] <- coverage$finite_rate[[i]]
  }
  graphics::image(
    seq_len(ncol(mat)), seq_len(nrow(mat)), t(mat[nrow(mat):1L, , drop = FALSE]),
    col = grDevices::colorRampPalette(c("#FEE2E2", "#FEF3C7", "#DCFCE7"))(100),
    axes = FALSE,
    xlab = "", ylab = "", main = "Feature coverage is broad enough for a first supervised table"
  )
  graphics::axis(1, at = seq_len(ncol(mat)), labels = colnames(mat), las = 2, cex.axis = 0.7)
  graphics::axis(2, at = seq_len(nrow(mat)), labels = rev(rownames(mat)), las = 2, cex.axis = 0.75)
  graphics::box()
}

write_label_balance_png <- function(summary, path) {
  plot_rows <- summary[summary$split == "OOS", , drop = FALSE]
  plot_rows$key <- paste(plot_rows$symbol, plot_rows$window_id, sep = " / ")
  plot_rows <- plot_rows[order(plot_rows$window_id, plot_rows$symbol), , drop = FALSE]
  grDevices::png(path, width = 2400L, height = 1300L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(8, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  cols <- ifelse(plot_rows$window_id == "2020Y", "#2563EB", "#DC2626")
  graphics::barplot(
    plot_rows$label_up_rate,
    names.arg = plot_rows$key,
    las = 2,
    ylim = c(0, 1),
    col = cols,
    border = NA,
    ylab = "Positive h3 label rate",
    main = "OOS label balance shows the target is not one-sided"
  )
  graphics::abline(h = 0.5, lty = 2, col = "#111827")
  graphics::legend("topright", legend = c("2020", "2022"), fill = c("#2563EB", "#DC2626"), bty = "n")
}

write_forward_return_distribution_png <- function(feature_fold_table, path) {
  oos <- feature_fold_table[
    feature_fold_table$split == "OOS" &
      feature_fold_table$label_inside_split &
      is.finite(feature_fold_table$fwd_ret_h3),
    ,
    drop = FALSE
  ]
  grDevices::png(path, width = 2400L, height = 1200L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (window in c("2020Y", "2022Y")) {
    x <- oos$fwd_ret_h3[oos$window_id == window]
    graphics::hist(
      x,
      breaks = 45,
      col = if (window == "2020Y") "#BFDBFE" else "#FECACA",
      border = "white",
      xlab = "Forward h3 return",
      main = paste0(window, " next-open h3 return distribution")
    )
    graphics::abline(v = 0, lty = 2, col = "#111827", lwd = 1.5)
  }
}

write_alignment_example_png <- function(feature_fold_table, path, symbol = "AMD", window = "2020Y") {
  x <- feature_fold_table[
    feature_fold_table$symbol == symbol &
      feature_fold_table$window_id == window &
      feature_fold_table$split == "OOS",
    ,
    drop = FALSE
  ]
  x <- x[order(as.Date(x$session_date)), , drop = FALSE]
  x <- x[is.finite(x$fwd_ret_h3) & x$label_inside_split, , drop = FALSE]
  if (nrow(x) < 30L) return(invisible(FALSE))
  mid <- max(15L, min(nrow(x) - 10L, round(nrow(x) * 0.45)))
  ex <- x[mid, , drop = FALSE]
  plot <- x[pmax(1L, mid - 22L):pmin(nrow(x), mid + 18L), , drop = FALSE]
  grDevices::png(path, width = 2400L, height = 1200L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  graphics::plot(as.Date(plot$session_date), plot$close, type = "l", lwd = 2, col = "#111827",
                 xlab = "Session", ylab = "Adjusted close",
                 main = paste0(symbol, " example: feature date, next-open execution, h3 label endpoint"))
  graphics::abline(v = as.Date(ex$feature_date), col = "#2563EB", lwd = 2)
  graphics::abline(v = as.Date(ex$execution_date), col = "#F97316", lwd = 2)
  graphics::abline(v = as.Date(ex$label_end_date), col = "#16A34A", lwd = 2)
  graphics::legend(
    "topleft",
    legend = c("feature date t", "next-open execution", "label close t+3"),
    col = c("#2563EB", "#F97316", "#16A34A"),
    lwd = 2,
    bty = "n"
  )
}

write_feature_behavior_png <- function(feature_fold_table, path, symbol = "TSLA", window = "2022Y") {
  x <- feature_fold_table[
    feature_fold_table$symbol == symbol &
      feature_fold_table$window_id == window &
      feature_fold_table$split == "OOS",
    ,
    drop = FALSE
  ]
  x <- x[order(as.Date(x$session_date)), , drop = FALSE]
  if (nrow(x) < 30L) return(invisible(FALSE))
  grDevices::png(path, width = 2600L, height = 1600L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(4, 1), mar = c(3, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  d <- as.Date(x$session_date)
  graphics::plot(d, x$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste0(symbol, " ", window, ": price and selected feature behavior"))
  graphics::plot(d, x$ema_gap, type = "l", lwd = 2, col = "#2563EB", xlab = "", ylab = "EMA gap", main = "Trend descriptor")
  graphics::abline(h = 0, lty = 2, col = "#9CA3AF")
  graphics::plot(d, x$close_location_60, type = "l", lwd = 2, col = "#16A34A", xlab = "", ylab = "0..1", main = "Close location in 60-session range")
  graphics::plot(d, x$volume_z20, type = "l", lwd = 2, col = "#F97316", xlab = "", ylab = "z-score", main = "Relative volume")
  graphics::abline(h = 0, lty = 2, col = "#9CA3AF")
}

write_decile_audit_png <- function(deciles, path) {
  features <- unique(deciles$feature)
  features <- features[seq_len(min(6L, length(features)))]
  plot_rows <- deciles[deciles$feature %in% features, , drop = FALSE]
  grDevices::png(path, width = 2600L, height = 1600L, res = 180L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 3), mar = c(4, 4, 3, 1))
  on.exit(graphics::par(old), add = TRUE)
  for (feature in features) {
    x <- plot_rows[plot_rows$feature == feature, , drop = FALSE]
    graphics::plot(x$decile, x$mean_fwd_ret_h3, type = "b", pch = 19, lwd = 2, col = "#111827",
                   xlab = "TRAIN feature decile", ylab = "Mean h3 return",
                   main = feature)
    graphics::abline(h = 0, lty = 2, col = "#9CA3AF")
  }
}

write_report <- function(path, run_spec, label_summary_df, audit, artifact_index) {
  lines <- c(
    "# Gen5.4 ML-P0 Feature/Label Proof",
    "",
    "## Purpose",
    "",
    "This packet proves the supervised-learning table before any model is fit. It checks whether adjusted daily OHLCV can produce deterministic, execution-aligned features and h3 labels without leaking OOS information into TRAIN.",
    "",
    "## Scope",
    "",
    paste0("- Live basket: `", run_spec$live_symbols[[1L]], "`"),
    paste0("- Context symbols: `", run_spec$context_symbols[[1L]], "`"),
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    "- Label: after close t, hypothetical entry at next open, return through close three sessions later.",
    "",
    "## Leakage Audit",
    "",
    paste0("- `", audit$check_id, "`: ", audit$status, " - ", audit$detail),
    "",
    "## Label Readout",
    "",
    paste0("- Usable rows: `", sum(label_summary_df$row_count, na.rm = TRUE), "` across TRAIN/OOS folds."),
    paste0("- OOS positive-label rate range: `", round(100 * min(label_summary_df$label_up_rate[label_summary_df$split == "OOS"], na.rm = TRUE), 1), "%` to `", round(100 * max(label_summary_df$label_up_rate[label_summary_df$split == "OOS"], na.rm = TRUE), 1), "%`."),
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_index$artifact_id, "`: `", artifact_index$path, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

if (!identical(Sys.getenv("GEN5_GEN54_ML_P0_SOURCE_ONLY", unset = "false"), "true")) {
g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
feed <- env_or("GEN5_GEN54_ML_P0_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P0_REFRESH", "false"), default = FALSE)
stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_ML_P0_STAMP", "20260713p0"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p0_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

live_symbols <- g5_standardize_symbol(split_csv(env_or("GEN5_GEN54_ML_P0_LIVE_SYMBOLS", "AMD,NVDA,TSLA,MSTR,AVGO")))
context_symbols <- unique(g5_standardize_symbol(c(live_symbols, split_csv(env_or(
  "GEN5_GEN54_ML_P0_CONTEXT_SYMBOLS",
  "MU,QCOM,META,NFLX,SMH,SOXX,IYW,SPY,QQQ,IWM,TLT,GLD"
)))))
years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P0_YEARS", "2020,2022")))
horizon <- as.integer(env_or("GEN5_GEN54_ML_P0_HORIZON", "3"))
threshold <- as.numeric(env_or("GEN5_GEN54_ML_P0_LABEL_THRESHOLD", "0"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P0_AS_OF", "2022-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P0_WARMUP_DAYS", "420"))

folds <- build_folds(years)
query_start <- min(folds$train_start_date) - warmup_days
query_end <- max(folds$oos_end_date)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = context_symbols,
  universe_name = "gen54_ml_p0_context",
  universe_roles = "live_basket,context_universe",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) {
  g5_stop("ML-P0 query returned no bars.")
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

usable <- feature_fold_table[feature_fold_table$label_inside_split & is.finite(feature_fold_table$fwd_ret_h3), , drop = FALSE]
sample_rows <- usable[seq_len(min(nrow(usable), 500L)), c(
  "symbol", "window_id", "fold_id", "split", "feature_date", "execution_date", "execution_price",
  "label_end_date", "label_end_close", "fwd_ret_h3", "label_up_h3", features
), drop = FALSE]

coverage <- coverage_summary(feature_fold_table, features)
labels <- label_summary(feature_fold_table, features)
audit <- leakage_audit(feature_fold_table, features)
deciles <- decile_audit(feature_fold_table, intersect(c(
  "ret_20", "ema_gap", "close_location_60", "volume_z20", "intraday_oc_ret",
  "gap_open_pct", "atr_pct", "market_rel_ret_20"
), features))

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p0_run_spec.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p0_fold_spec.csv"),
  feature_taxonomy_csv = file.path(output_dir, "ml_p0_feature_taxonomy.csv"),
  feature_label_sample_csv = file.path(output_dir, "ml_p0_feature_label_sample.csv"),
  feature_coverage_csv = file.path(output_dir, "ml_p0_feature_coverage.csv"),
  label_summary_csv = file.path(output_dir, "ml_p0_label_summary.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p0_leakage_audit.csv"),
  decile_audit_csv = file.path(output_dir, "ml_p0_univariate_decile_audit.csv"),
  report_md = file.path(output_dir, "ml_p0_feature_label_proof_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p0_artifact_index.csv"),
  fold_calendar_png = file.path(visual_dir, "ml_p0_fold_calendar_leakage_diagram.png"),
  feature_coverage_png = file.path(visual_dir, "ml_p0_feature_coverage_heatmap.png"),
  label_balance_png = file.path(visual_dir, "ml_p0_label_balance_bars.png"),
  forward_return_png = file.path(visual_dir, "ml_p0_forward_return_distribution.png"),
  alignment_png = file.path(visual_dir, "ml_p0_example_alignment_chart.png"),
  feature_behavior_png = file.path(visual_dir, "ml_p0_feature_behavior_strips.png"),
  decile_png = file.path(visual_dir, "ml_p0_univariate_decile_audit.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p0_feature_label_proof_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_feature_label_proof.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  live_symbols = paste(live_symbols, collapse = ","),
  context_symbols = paste(context_symbols, collapse = ","),
  windows = paste(paste0(years, "Y"), collapse = ","),
  label_id = paste0("h", horizon, "_next_open_to_close"),
  label_threshold = threshold,
  row_count_fold_table = nrow(feature_fold_table),
  usable_label_rows = nrow(usable),
  selected_feature_count = length(features),
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

plot_features <- intersect(c(
  "ret_20", "ema_gap", "trend_slope_20", "close_location_day", "close_location_60",
  "range_pct", "body_pct", "volume_z20", "atr_pct", "drawdown_60", "market_rel_ret_20"
), features)

write_fold_calendar_png(folds, paths$fold_calendar_png)
write_feature_coverage_png(coverage, paths$feature_coverage_png, plot_features)
write_label_balance_png(labels, paths$label_balance_png)
write_forward_return_distribution_png(feature_fold_table, paths$forward_return_png)
write_alignment_example_png(feature_fold_table, paths$alignment_png, symbol = "AMD", window = "2020Y")
write_feature_behavior_png(feature_fold_table, paths$feature_behavior_png, symbol = "TSLA", window = "2022Y")
write_decile_audit_png(deciles, paths$decile_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(
    rep("csv", 8L),
    "markdown",
    "csv",
    rep("png", 7L)
  ),
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(feature_taxonomy(), paths$feature_taxonomy_csv)
g5_wfa_write_csv(sample_rows, paths$feature_label_sample_csv)
g5_wfa_write_csv(coverage, paths$feature_coverage_csv)
g5_wfa_write_csv(labels, paths$label_summary_csv)
g5_wfa_write_csv(audit, paths$leakage_audit_csv)
g5_wfa_write_csv(deciles, paths$decile_audit_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_report(paths$report_md, run_spec, labels, audit, artifact_index)

message("Gen5.4 ML-P0 feature/label proof complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("Leakage audit statuses: ", paste(audit$check_id, audit$status, sep = "=", collapse = "; "))
}
