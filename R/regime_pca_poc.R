# Gen5.1 PCA regime/state proof-of-concept helpers.

g5_pca_regime_schema_version <- function() {
  "gen5_pca_regime_poc_v0.1"
}

g5_pca_regime_default_features <- function() {
  c(
    "ema_gap",
    "trend_slope_5",
    "rsi_14",
    "vol_20",
    "atr_pct",
    "dist_anchor_200",
    "chop_14",
    "bb_width",
    "efficiency_ratio_20",
    "z_close_sma20",
    "ret_skew_20"
  )
}

g5_pca_regime_feature_set <- function(feature_set_id = "workhorse_enriched") {
  feature_set_id <- as.character(feature_set_id)[[1L]]
  if (!nzchar(feature_set_id)) feature_set_id <- "workhorse_enriched"
  presets <- list(
    workhorse_enriched = g5_pca_regime_default_features(),
    momentum_participation = c(
      "ema_gap",
      "ema_gap_10_50",
      "ema_gap_20_100",
      "trend_slope_5",
      "trend_slope_20",
      "ret_5",
      "ret_20",
      "ret_60",
      "efficiency_ratio_20",
      "above_sma20_frac_20",
      "close_location_20",
      "drawdown_60",
      "recovery_from_low_60"
    ),
    momentum_plus_stress = c(
      "ema_gap",
      "ema_gap_10_50",
      "ema_gap_20_100",
      "trend_slope_5",
      "trend_slope_20",
      "ret_5",
      "ret_20",
      "ret_60",
      "efficiency_ratio_20",
      "above_sma20_frac_20",
      "close_location_20",
      "close_location_60",
      "drawdown_60",
      "recovery_from_low_60",
      "vol_20",
      "atr_pct",
      "bb_width",
      "ret_skew_20"
    )
  )
  if (!feature_set_id %in% names(presets)) {
    g5_stop(paste0("Unknown PCA regime feature_set_id: ", feature_set_id))
  }
  presets[[feature_set_id]]
}

g5_pca_regime_feature_set_taxonomy <- function() {
  data.frame(
    feature_set_id = c(
      "workhorse_enriched",
      "momentum_participation",
      "momentum_plus_stress"
    ),
    feature_set_label = c(
      "Workhorse enriched",
      "Momentum participation",
      "Momentum plus stress"
    ),
    purpose = c(
      "Current Gen5 workhorse surface combining trend, stretch, volatility, chop, efficiency, and return-shape descriptors.",
      "Sharper bullish-participation surface meant to detect trend strength, persistence, recent return impulse, and recovery position.",
      "Momentum-participation surface with volatility and stress descriptors added back to preserve drawdown-avoidance context."
    ),
    feature_cols = vapply(
      c("workhorse_enriched", "momentum_participation", "momentum_plus_stress"),
      function(id) paste(g5_pca_regime_feature_set(id), collapse = ","),
      character(1L)
    ),
    stringsAsFactors = FALSE
  )
}

g5_pca_regime_artifact_prefix <- function(as_of_timestamp, symbol, grid_n, train_start_date, oos_end_date) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  window_label <- paste0(
    "w",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(train_start_date))),
    "_to_",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(oos_end_date)))
  )
  paste(c("pca_regime", symbol, paste0(grid_n, "x", grid_n), window_label, stamp), collapse = "_")
}

g5_pca_regime_output_dir <- function(repo_root, as_of_timestamp, symbol, grid_n, train_start_date, oos_end_date) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "regime_pocs",
    g5_pca_regime_artifact_prefix(as_of_timestamp, symbol, grid_n, train_start_date, oos_end_date)
  )
}

g5_pca_kmeans_regime_artifact_prefix <- function(as_of_timestamp, symbol, cluster_count, train_start_date, oos_end_date) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  window_label <- paste0(
    "w",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(train_start_date))),
    "_to_",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(oos_end_date)))
  )
  paste(c("pca_kmeans", symbol, paste0("k", as.integer(cluster_count)), window_label, stamp), collapse = "_")
}

g5_pca_kmeans_regime_output_dir <- function(repo_root, as_of_timestamp, symbol, cluster_count, train_start_date, oos_end_date) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "regime_pocs",
    g5_pca_kmeans_regime_artifact_prefix(as_of_timestamp, symbol, cluster_count, train_start_date, oos_end_date)
  )
}

g5_pca_regime_rolling_mean <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  if (is.na(n) || n < 1L) {
    g5_stop("rolling mean period must be positive.")
  }
  out <- rep(NA_real_, length(x))
  if (length(x) < n) {
    return(out)
  }
  for (i in n:length(x)) {
    window <- x[(i - n + 1L):i]
    if (all(is.finite(window))) {
      out[[i]] <- mean(window)
    }
  }
  out
}

g5_pca_regime_rolling_sd <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  if (is.na(n) || n < 2L) {
    g5_stop("rolling sd period must be >= 2.")
  }
  out <- rep(NA_real_, length(x))
  if (length(x) < n) {
    return(out)
  }
  for (i in n:length(x)) {
    window <- x[(i - n + 1L):i]
    if (all(is.finite(window))) {
      out[[i]] <- stats::sd(window)
    }
  }
  out
}

g5_pca_regime_rolling_sum <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  if (is.na(n) || n < 1L) {
    g5_stop("rolling sum period must be positive.")
  }
  out <- rep(NA_real_, length(x))
  if (length(x) < n) {
    return(out)
  }
  for (i in n:length(x)) {
    window <- x[(i - n + 1L):i]
    if (all(is.finite(window))) {
      out[[i]] <- sum(window)
    }
  }
  out
}

g5_pca_regime_rolling_min <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  if (is.na(n) || n < 1L) {
    g5_stop("rolling min period must be positive.")
  }
  out <- rep(NA_real_, length(x))
  if (length(x) < n) {
    return(out)
  }
  for (i in n:length(x)) {
    window <- x[(i - n + 1L):i]
    if (all(is.finite(window))) {
      out[[i]] <- min(window)
    }
  }
  out
}

g5_pca_regime_rolling_max <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  if (is.na(n) || n < 1L) {
    g5_stop("rolling max period must be positive.")
  }
  out <- rep(NA_real_, length(x))
  if (length(x) < n) {
    return(out)
  }
  for (i in n:length(x)) {
    window <- x[(i - n + 1L):i]
    if (all(is.finite(window))) {
      out[[i]] <- max(window)
    }
  }
  out
}

g5_pca_regime_rolling_skewness <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  if (is.na(n) || n < 3L) {
    g5_stop("rolling skewness period must be >= 3.")
  }
  out <- rep(NA_real_, length(x))
  if (length(x) < n) {
    return(out)
  }
  for (i in n:length(x)) {
    window <- x[(i - n + 1L):i]
    if (all(is.finite(window))) {
      s <- stats::sd(window)
      if (is.finite(s) && s > 0) {
        m <- mean(window)
        out[[i]] <- mean(((window - m) / s)^3)
      }
    }
  }
  out
}

g5_pca_regime_ema <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  if (is.na(n) || n < 1L) {
    g5_stop("EMA period must be positive.")
  }
  out <- rep(NA_real_, length(x))
  finite_idx <- which(is.finite(x))
  if (length(finite_idx) < n) {
    return(out)
  }
  start <- finite_idx[[n]]
  seed_window <- x[finite_idx[seq_len(n)]]
  out[[start]] <- mean(seed_window)
  alpha <- 2 / (n + 1)
  if (start < length(x)) {
    for (i in (start + 1L):length(x)) {
      if (is.finite(x[[i]]) && is.finite(out[[i - 1L]])) {
        out[[i]] <- alpha * x[[i]] + (1 - alpha) * out[[i - 1L]]
      }
    }
  }
  out
}

g5_pca_regime_rsi <- function(close, n = 14L) {
  close <- as.numeric(close)
  n <- as.integer(n)
  out <- rep(NA_real_, length(close))
  if (length(close) <= n) {
    return(out)
  }
  change <- c(NA_real_, diff(close))
  gain <- pmax(change, 0)
  loss <- pmax(-change, 0)
  avg_gain <- g5_pca_regime_rolling_mean(gain[-1L], n)
  avg_loss <- g5_pca_regime_rolling_mean(loss[-1L], n)
  avg_gain <- c(NA_real_, avg_gain)
  avg_loss <- c(NA_real_, avg_loss)
  rs <- avg_gain / pmax(avg_loss, 1e-8)
  out <- 100 - (100 / (1 + rs))
  out[!is.finite(out)] <- NA_real_
  out
}

g5_pca_regime_true_range <- function(high, low, close) {
  high <- as.numeric(high)
  low <- as.numeric(low)
  close <- as.numeric(close)
  prior_close <- c(NA_real_, head(close, -1L))
  pmax(high - low, abs(high - prior_close), abs(low - prior_close), na.rm = TRUE)
}

g5_pca_regime_adx <- function(high, low, close, n = 14L) {
  high <- as.numeric(high)
  low <- as.numeric(low)
  close <- as.numeric(close)
  n <- as.integer(n)
  if (is.na(n) || n < 2L) {
    g5_stop("ADX period must be >= 2.")
  }
  if (length(close) < n * 2L) {
    return(rep(NA_real_, length(close)))
  }
  prior_high <- c(NA_real_, head(high, -1L))
  prior_low <- c(NA_real_, head(low, -1L))
  up_move <- high - prior_high
  down_move <- prior_low - low
  plus_dm <- ifelse(is.finite(up_move) & is.finite(down_move) & up_move > down_move & up_move > 0, up_move, 0)
  minus_dm <- ifelse(is.finite(up_move) & is.finite(down_move) & down_move > up_move & down_move > 0, down_move, 0)
  tr_sum <- g5_pca_regime_rolling_sum(g5_pca_regime_true_range(high, low, close), n)
  plus_di <- 100 * g5_pca_regime_rolling_sum(plus_dm, n) / pmax(tr_sum, 1e-8)
  minus_di <- 100 * g5_pca_regime_rolling_sum(minus_dm, n) / pmax(tr_sum, 1e-8)
  dx <- 100 * abs(plus_di - minus_di) / pmax(plus_di + minus_di, 1e-8)
  out <- g5_pca_regime_rolling_mean(dx, n)
  out[!is.finite(out)] <- NA_real_
  out
}

g5_pca_regime_efficiency_ratio <- function(close, n = 20L) {
  close <- as.numeric(close)
  n <- as.integer(n)
  out <- rep(NA_real_, length(close))
  if (length(close) <= n) {
    return(out)
  }
  abs_change <- abs(diff(close))
  path <- rep(NA_real_, length(close))
  for (i in (n + 1L):length(close)) {
    num <- abs(close[[i]] - close[[i - n]])
    den <- sum(abs_change[(i - n):(i - 1L)], na.rm = FALSE)
    if (is.finite(num) && is.finite(den) && den > 0) {
      path[[i]] <- num / den
    }
  }
  out <- path
  out[out < 0 | out > 1 + 1e-8] <- NA_real_
  out
}

g5_pca_regime_prepare_bars <- function(bars, symbol) {
  if (!is.data.frame(bars)) {
    g5_stop("PCA regime POC requires bars as a data.frame.")
  }
  bars <- g5_validate_bar_data(bars)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  bars <- bars[bars$symbol == symbol, , drop = FALSE]
  bars <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  if (nrow(bars) == 0L) {
    g5_stop("PCA regime POC requires non-empty bars for the requested symbol.")
  }
  bars
}

g5_pca_regime_feature_table <- function(bars, symbol, end_date = NULL) {
  bars <- g5_pca_regime_prepare_bars(bars, symbol)
  if (!is.null(end_date)) {
    bars <- bars[as.Date(bars$session_date) <= as.Date(end_date), , drop = FALSE]
  }
  if (nrow(bars) == 0L) {
    g5_stop("No bars remain for PCA regime feature calculation.")
  }
  close <- as.numeric(bars$close)
  high <- as.numeric(bars$high)
  low <- as.numeric(bars$low)
  ret1 <- c(NA_real_, close[-1L] / close[-length(close)] - 1)
  ret_n <- function(n) {
    n <- as.integer(n)
    out <- rep(NA_real_, length(close))
    if (length(close) > n) {
      out[(n + 1L):length(close)] <- close[(n + 1L):length(close)] / close[seq_len(length(close) - n)] - 1
    }
    out
  }
  ema_fast <- g5_pca_regime_ema(close, 20L)
  ema_slow <- g5_pca_regime_ema(close, 50L)
  ema_10 <- g5_pca_regime_ema(close, 10L)
  ema_100 <- g5_pca_regime_ema(close, 100L)
  sma_20 <- g5_pca_regime_rolling_mean(close, 20L)
  sma_50 <- g5_pca_regime_rolling_mean(close, 50L)
  sma_200 <- g5_pca_regime_rolling_mean(close, 200L)
  sd_20_close <- g5_pca_regime_rolling_sd(close, 20L)
  vol_20 <- g5_pca_regime_rolling_sd(ret1, 20L)
  atr_14 <- g5_pca_regime_rolling_mean(g5_pca_regime_true_range(high, low, close), 14L)
  high_20 <- g5_pca_regime_rolling_max(high, 20L)
  low_20 <- g5_pca_regime_rolling_min(low, 20L)
  high_60 <- g5_pca_regime_rolling_max(high, 60L)
  low_60 <- g5_pca_regime_rolling_min(low, 60L)
  close_high_60 <- g5_pca_regime_rolling_max(close, 60L)
  bb_mid <- sma_20
  bb_up <- bb_mid + 2 * sd_20_close
  bb_dn <- bb_mid - 2 * sd_20_close
  data.frame(
    schema_version = g5_pca_regime_schema_version(),
    symbol = g5_standardize_symbol(symbol)[[1L]],
    session_date = as.Date(bars$session_date),
    open = as.numeric(bars$open),
    high = high,
    low = low,
    close = close,
    volume = as.numeric(bars$volume),
    ret1 = ret1,
    ret_5 = ret_n(5L),
    ret_20 = ret_n(20L),
    ret_60 = ret_n(60L),
    ema_gap = ema_fast / ema_slow - 1,
    ema_gap_10_50 = ema_10 / ema_slow - 1,
    ema_gap_20_100 = ema_fast / ema_100 - 1,
    trend_slope_5 = (ema_fast / c(rep(NA_real_, 5L), head(ema_fast, -5L)) - 1) / 5,
    trend_slope_20 = (ema_fast / c(rep(NA_real_, 20L), head(ema_fast, -20L)) - 1) / 20,
    rsi_14 = g5_pca_regime_rsi(close, 14L),
    vol_20 = vol_20,
    atr_pct = atr_14 / close,
    dist_anchor_50 = close / sma_50 - 1,
    dist_anchor_200 = close / sma_200 - 1,
    chop_14 = g5_pca_regime_adx(high, low, close, 14L),
    bb_width = (bb_up - bb_dn) / pmax(bb_mid, 1e-8),
    efficiency_ratio_20 = g5_pca_regime_efficiency_ratio(close, 20L),
    z_close_sma20 = (close - sma_20) / pmax(sd_20_close, 1e-8),
    ret_skew_20 = g5_pca_regime_rolling_skewness(ret1, 20L),
    above_sma20_frac_20 = g5_pca_regime_rolling_mean(as.numeric(close > sma_20), 20L),
    close_location_20 = (close - low_20) / pmax(high_20 - low_20, 1e-8),
    close_location_60 = (close - low_60) / pmax(high_60 - low_60, 1e-8),
    drawdown_60 = close / pmax(close_high_60, 1e-8) - 1,
    recovery_from_low_60 = close / pmax(low_60, 1e-8) - 1,
    stringsAsFactors = FALSE
  )
}

g5_pca_regime_context_feature_name <- function(symbol, feature) {
  safe_symbol <- gsub("[^0-9A-Za-z]+", "_", g5_standardize_symbol(symbol)[[1L]])
  paste0(safe_symbol, "__", as.character(feature))
}

g5_pca_regime_context_feature_cols <- function(context_symbols, feature_cols = g5_pca_regime_default_features()) {
  context_symbols <- unique(g5_standardize_symbol(context_symbols))
  unlist(lapply(context_symbols, function(symbol) {
    vapply(feature_cols, function(feature) g5_pca_regime_context_feature_name(symbol, feature), character(1L))
  }), use.names = FALSE)
}

g5_pca_regime_context_feature_table <- function(
  bars,
  target_symbol,
  context_symbols,
  end_date = NULL,
  feature_cols = g5_pca_regime_default_features()
) {
  target_symbol <- g5_standardize_symbol(target_symbol)[[1L]]
  context_symbols <- unique(g5_standardize_symbol(context_symbols))
  if (!length(context_symbols)) {
    g5_stop("PCA context feature table requires at least one context symbol.")
  }
  target <- g5_pca_regime_feature_table(bars, target_symbol, end_date = end_date)
  base_cols <- c("schema_version", "symbol", "session_date", "open", "high", "low", "close", "volume")
  out <- target[, base_cols, drop = FALSE]
  for (symbol in context_symbols) {
    features <- g5_pca_regime_feature_table(bars, symbol, end_date = end_date)
    keep <- intersect(feature_cols, names(features))
    if (length(keep) < length(feature_cols)) {
      missing <- setdiff(feature_cols, keep)
      g5_stop(paste0("Missing PCA context features for ", symbol, ": ", paste(missing, collapse = ",")))
    }
    part <- features[, c("session_date", keep), drop = FALSE]
    names(part)[match(keep, names(part))] <- vapply(keep, function(feature) g5_pca_regime_context_feature_name(symbol, feature), character(1L))
    out <- merge(out, part, by = "session_date", all = FALSE, sort = FALSE)
  }
  out <- out[order(as.Date(out$session_date)), , drop = FALSE]
  rownames(out) <- NULL
  out$regime_context_symbols <- paste(context_symbols, collapse = ",")
  out$research_candidate_symbol <- target_symbol
  out$pca_training_role <- "context"
  attr(out, "feature_cols") <- g5_pca_regime_context_feature_cols(context_symbols, feature_cols)
  out
}

g5_pca_regime_pooled_feature_table <- function(
  bars,
  target_symbol,
  context_symbols,
  end_date = NULL,
  feature_cols = g5_pca_regime_default_features()
) {
  target_symbol <- g5_standardize_symbol(target_symbol)[[1L]]
  context_symbols <- unique(g5_standardize_symbol(context_symbols))
  if (!length(context_symbols)) {
    g5_stop("PCA pooled feature table requires at least one context symbol.")
  }
  scoring_symbols <- unique(c(context_symbols, target_symbol))
  parts <- lapply(scoring_symbols, function(symbol) {
    features <- g5_pca_regime_feature_table(bars, symbol, end_date = end_date)
    keep <- c("schema_version", "symbol", "session_date", "open", "high", "low", "close", "volume", feature_cols)
    missing <- setdiff(keep, names(features))
    if (length(missing)) {
      g5_stop(paste0("Missing pooled PCA features for ", symbol, ": ", paste(missing, collapse = ",")))
    }
    features <- features[, keep, drop = FALSE]
    features$pca_training_symbol <- symbol
    features$pca_training_role <- if (symbol %in% context_symbols) "context" else "routing_target_only"
    features
  })
  out <- do.call(rbind, parts)
  out <- out[order(as.Date(out$session_date), out$symbol), , drop = FALSE]
  rownames(out) <- NULL
  out$regime_context_symbols <- paste(context_symbols, collapse = ",")
  out$research_candidate_symbol <- target_symbol
  out$pca_panel_mode <- "pooled_asset_day"
  attr(out, "feature_cols") <- feature_cols
  out
}

g5_pca_regime_training_fit_rows <- function(scored_base) {
  if ("pca_training_role" %in% names(scored_base)) {
    scored_base$split == "TRAIN" & scored_base$pca_training_role == "context"
  } else {
    scored_base$split == "TRAIN"
  }
}

g5_pca_regime_state_palette <- function(state_ids) {
  all_states <- as.vector(outer(seq_len(3L), seq_len(3L), function(x, y) paste0("S", x, "_", y)))
  colors <- c(
    "#2E86AB", "#00A88F", "#7BC043",
    "#F6C85F", "#FF9F1C", "#F15A5A",
    "#9B5DE5", "#6E6878", "#242033"
  )
  names(colors) <- all_states
  missing <- setdiff(as.character(state_ids), names(colors))
  if (length(missing)) {
    extra <- grDevices::hcl.colors(length(missing), palette = "Dark 3")
    names(extra) <- missing
    colors <- c(colors, extra)
  }
  colors[as.character(state_ids)]
}

g5_pca_regime_kmeans_states <- function(cluster_count) {
  sprintf("K%02d", seq_len(as.integer(cluster_count)))
}

g5_pca_regime_kmeans_engine <- function(state_engine) {
  engine <- as.character(state_engine)[[1L]]
  if (identical(engine, "kmeans")) engine <- "pca_kmeans"
  allowed <- c("pca_kmeans", "pca_kmeans_auto")
  if (!engine %in% allowed) {
    g5_stop(paste0("K-means state engine must be one of: ", paste(allowed, collapse = ", ")))
  }
  engine
}

g5_pca_regime_kmeans_engine_label <- function(state_engine, cluster_count) {
  engine <- as.character(state_engine)[[1L]]
  if (identical(engine, "pca_kmeans_auto")) {
    paste0("kauto", as.integer(cluster_count))
  } else {
    paste0("k", as.integer(cluster_count))
  }
}

g5_pca_regime_kmeans_ch_index <- function(kmeans_fit) {
  k <- nrow(kmeans_fit$centers)
  n <- length(kmeans_fit$cluster)
  if (k < 2L || n <= k) return(NA_real_)
  within_ss <- sum(kmeans_fit$withinss)
  between_ss <- kmeans_fit$betweenss
  if (!is.finite(within_ss) || !is.finite(between_ss) || within_ss <= 0) return(NA_real_)
  (between_ss / (k - 1L)) / (within_ss / (n - k))
}

g5_pca_regime_select_kmeans_k <- function(pc_scores, min_clusters = 2L, max_clusters = 9L, nstart = 30L, seed = 5101L) {
  if (!is.data.frame(pc_scores) || !all(c("pc1", "pc2") %in% names(pc_scores))) {
    g5_stop("Auto k-means selection requires a data frame with pc1 and pc2.")
  }
  x <- pc_scores[, c("pc1", "pc2"), drop = FALSE]
  x <- x[stats::complete.cases(x), , drop = FALSE]
  n <- nrow(x)
  min_clusters <- as.integer(min_clusters)
  max_clusters <- as.integer(max_clusters)
  nstart <- as.integer(nstart)
  if (is.na(min_clusters) || min_clusters < 2L) g5_stop("min_clusters must be at least 2.")
  if (is.na(max_clusters) || max_clusters < min_clusters || max_clusters > 25L) g5_stop("max_clusters must be between min_clusters and 25.")
  if (is.na(nstart) || nstart < 1L) g5_stop("nstart must be a positive integer.")
  max_allowed <- min(max_clusters, n - 1L)
  if (max_allowed < min_clusters) {
    g5_stop("Auto k-means selection requires more TRAIN rows than the minimum candidate cluster count.")
  }
  candidate_k <- seq.int(min_clusters, max_allowed)
  fits <- vector("list", length(candidate_k))
  diagnostics <- vector("list", length(candidate_k))
  for (i in seq_along(candidate_k)) {
    k <- candidate_k[[i]]
    set.seed(as.integer(seed) + k)
    fit <- stats::kmeans(x, centers = k, nstart = nstart)
    fits[[i]] <- fit
    diagnostics[[i]] <- data.frame(
      candidate_cluster_count = k,
      train_row_count = n,
      tot_withinss = fit$tot.withinss,
      betweenss = fit$betweenss,
      ch_index = g5_pca_regime_kmeans_ch_index(fit),
      stringsAsFactors = FALSE
    )
  }
  diagnostics <- do.call(rbind, diagnostics)
  if (!any(is.finite(diagnostics$ch_index))) {
    g5_stop("Auto k-means selection could not compute a finite Calinski-Harabasz score.")
  }
  best_index <- which(diagnostics$ch_index == max(diagnostics$ch_index, na.rm = TRUE))[[1L]]
  diagnostics$selected <- seq_len(nrow(diagnostics)) == best_index
  list(
    cluster_count = diagnostics$candidate_cluster_count[[best_index]],
    criterion = "calinski_harabasz_train_pc1_pc2",
    diagnostics = diagnostics,
    fit = fits[[best_index]]
  )
}

g5_pca_regime_assign_split <- function(features, train_start_date, train_end_date, oos_start_date, oos_end_date) {
  dates <- as.Date(features$session_date)
  split <- rep(NA_character_, nrow(features))
  split[dates >= as.Date(train_start_date) & dates <= as.Date(train_end_date)] <- "TRAIN"
  split[dates >= as.Date(oos_start_date) & dates <= as.Date(oos_end_date)] <- "OOS"
  split
}

g5_pca_regime_fit <- function(
  features,
  train_start_date,
  train_end_date,
  oos_start_date,
  oos_end_date,
  feature_cols = g5_pca_regime_default_features(),
  grid_n = 3L,
  min_train_rows = 120L
) {
  if (!is.data.frame(features) || nrow(features) == 0L) {
    g5_stop("PCA regime fit requires non-empty features.")
  }
  grid_n <- as.integer(grid_n)
  if (is.na(grid_n) || grid_n < 2L || grid_n > 5L) {
    g5_stop("grid_n must be an integer from 2 to 5.")
  }
  feature_cols <- intersect(as.character(feature_cols), names(features))
  if (length(feature_cols) < 3L) {
    g5_stop("PCA regime fit requires at least three available feature columns.")
  }
  features <- features[order(as.Date(features$session_date)), , drop = FALSE]
  features$split <- g5_pca_regime_assign_split(features, train_start_date, train_end_date, oos_start_date, oos_end_date)
  scored_base <- features[features$split %in% c("TRAIN", "OOS"), , drop = FALSE]
  if (!nrow(scored_base)) {
    g5_stop("PCA regime fit has no rows inside TRAIN/OOS windows.")
  }
  train_fit_rows <- g5_pca_regime_training_fit_rows(scored_base)
  finite_train <- scored_base[train_fit_rows, , drop = FALSE]
  finite_train <- finite_train[stats::complete.cases(finite_train[, feature_cols, drop = FALSE]), , drop = FALSE]
  if (nrow(finite_train) < min_train_rows) {
    g5_stop(paste0("PCA regime fit requires at least ", min_train_rows, " fully finite TRAIN rows."))
  }
  keep <- feature_cols[vapply(feature_cols, function(col) {
    x <- as.numeric(finite_train[[col]])
    stats::sd(x, na.rm = TRUE) > 0 && all(is.finite(x))
  }, logical(1))]
  if (length(keep) < 3L) {
    g5_stop("PCA regime fit has fewer than three finite non-zero-variance TRAIN features.")
  }
  dropped <- setdiff(feature_cols, keep)
  train_used <- finite_train[, keep, drop = FALSE]
  x_train <- scale(as.matrix(train_used))
  center <- attr(x_train, "scaled:center")
  scale <- attr(x_train, "scaled:scale")
  pca <- stats::prcomp(x_train, center = FALSE, scale. = FALSE)
  scoring_rows <- scored_base[stats::complete.cases(scored_base[, keep, drop = FALSE]), , drop = FALSE]
  x_all <- as.matrix(scoring_rows[, keep, drop = FALSE])
  x_all <- sweep(x_all, 2, center, "-")
  x_all <- sweep(x_all, 2, scale, "/")
  score <- x_all %*% pca$rotation[, 1:2, drop = FALSE]
  scoring_rows$pc1 <- as.numeric(score[, 1L])
  scoring_rows$pc2 <- as.numeric(score[, 2L])
  train_scored <- scoring_rows[g5_pca_regime_training_fit_rows(scoring_rows), , drop = FALSE]
  pc1_q <- as.numeric(stats::quantile(train_scored$pc1, probs = seq(0, 1, length.out = grid_n + 1L), na.rm = TRUE, names = FALSE))
  pc2_q <- as.numeric(stats::quantile(train_scored$pc2, probs = seq(0, 1, length.out = grid_n + 1L), na.rm = TRUE, names = FALSE))
  if (length(unique(pc1_q)) < grid_n + 1L || length(unique(pc2_q)) < grid_n + 1L) {
    g5_stop("PCA regime quantile breaks collapsed; lower grid_n or improve feature variability.")
  }
  pc1_breaks <- c(-Inf, pc1_q[2:grid_n], Inf)
  pc2_breaks <- c(-Inf, pc2_q[2:grid_n], Inf)
  scoring_rows$pc1_bin <- as.integer(cut(scoring_rows$pc1, breaks = pc1_breaks, include.lowest = TRUE, labels = FALSE))
  scoring_rows$pc2_bin <- as.integer(cut(scoring_rows$pc2, breaks = pc2_breaks, include.lowest = TRUE, labels = FALSE))
  scoring_rows$state_id <- paste0("S", scoring_rows$pc1_bin, "_", scoring_rows$pc2_bin)
  scoring_rows$state_id[is.na(scoring_rows$pc1_bin) | is.na(scoring_rows$pc2_bin)] <- NA_character_
  explained <- (pca$sdev^2) / sum(pca$sdev^2)
  contract <- rbind(
    data.frame(
      record_type = "feature",
      feature = keep,
      center = as.numeric(center[keep]),
      scale = as.numeric(scale[keep]),
      loading_pc1 = as.numeric(pca$rotation[keep, 1L]),
      loading_pc2 = as.numeric(pca$rotation[keep, 2L]),
      break_axis = NA_character_,
      break_index = NA_integer_,
      break_value = NA_real_,
      key = NA_character_,
      value = NA_character_,
      stringsAsFactors = FALSE
    ),
    data.frame(
      record_type = "pc_break",
      feature = NA_character_,
      center = NA_real_,
      scale = NA_real_,
      loading_pc1 = NA_real_,
      loading_pc2 = NA_real_,
      break_axis = rep(c("pc1", "pc2"), each = grid_n + 1L),
      break_index = rep(seq_len(grid_n + 1L), times = 2L),
      break_value = c(pc1_q, pc2_q),
      key = NA_character_,
      value = NA_character_,
      stringsAsFactors = FALSE
    ),
    data.frame(
      record_type = "meta",
      feature = NA_character_,
      center = NA_real_,
      scale = NA_real_,
      loading_pc1 = NA_real_,
      loading_pc2 = NA_real_,
      break_axis = NA_character_,
      break_index = NA_integer_,
      break_value = NA_real_,
      key = c("grid_n", "outer_break_policy", "train_start_date", "train_end_date", "oos_start_date", "oos_end_date", "fit_row_policy", "dropped_features"),
      value = c(as.character(grid_n), "extend_to_infinity_for_oos_extremes", as.character(as.Date(train_start_date)), as.character(as.Date(train_end_date)), as.character(as.Date(oos_start_date)), as.character(as.Date(oos_end_date)), if ("pca_training_role" %in% names(scored_base)) "TRAIN rows with pca_training_role=context" else "all TRAIN rows", paste(dropped, collapse = ";")),
      stringsAsFactors = FALSE
    )
  )
  diagnostics <- data.frame(
    component = c("PC1", "PC2"),
    explained_variance = explained[1:2],
    stringsAsFactors = FALSE
  )
  list(
    scores = scoring_rows,
    model_contract = contract,
    diagnostics = diagnostics,
    kept_features = keep,
    dropped_features = dropped,
    state_engine = "quantile_grid",
    state_ids = as.vector(outer(seq_len(grid_n), seq_len(grid_n), function(x, y) paste0("S", x, "_", y))),
    grid_n = grid_n,
    pc1_breaks = pc1_q,
    pc2_breaks = pc2_q
  )
}

g5_pca_regime_fit_kmeans <- function(
  features,
  train_start_date,
  train_end_date,
  oos_start_date,
  oos_end_date,
  feature_cols = g5_pca_regime_default_features(),
  cluster_count = 9L,
  min_train_rows = 120L,
  nstart = 30L,
  state_engine = "pca_kmeans",
  auto_min_clusters = 2L,
  auto_max_clusters = cluster_count
) {
  if (!is.data.frame(features) || nrow(features) == 0L) {
    g5_stop("PCA k-means regime fit requires non-empty features.")
  }
  cluster_count <- as.integer(cluster_count)
  if (is.na(cluster_count) || cluster_count < 2L || cluster_count > 25L) {
    g5_stop("cluster_count must be an integer from 2 to 25.")
  }
  state_engine <- g5_pca_regime_kmeans_engine(state_engine)
  auto_min_clusters <- as.integer(auto_min_clusters)
  auto_max_clusters <- as.integer(auto_max_clusters)
  if (identical(state_engine, "pca_kmeans_auto")) {
    if (is.na(auto_min_clusters) || auto_min_clusters < 2L) g5_stop("auto_min_clusters must be at least 2.")
    if (is.na(auto_max_clusters) || auto_max_clusters < auto_min_clusters || auto_max_clusters > 25L) {
      g5_stop("auto_max_clusters must be between auto_min_clusters and 25.")
    }
    if (auto_max_clusters > cluster_count) {
      g5_stop("For pca_kmeans_auto, auto_max_clusters must be less than or equal to cluster_count.")
    }
  }
  nstart <- as.integer(nstart)
  if (is.na(nstart) || nstart < 1L) {
    g5_stop("nstart must be a positive integer.")
  }
  feature_cols <- intersect(as.character(feature_cols), names(features))
  if (length(feature_cols) < 3L) {
    g5_stop("PCA k-means regime fit requires at least three available feature columns.")
  }
  features <- features[order(as.Date(features$session_date)), , drop = FALSE]
  features$split <- g5_pca_regime_assign_split(features, train_start_date, train_end_date, oos_start_date, oos_end_date)
  scored_base <- features[features$split %in% c("TRAIN", "OOS"), , drop = FALSE]
  if (!nrow(scored_base)) {
    g5_stop("PCA k-means regime fit has no rows inside TRAIN/OOS windows.")
  }
  train_fit_rows <- g5_pca_regime_training_fit_rows(scored_base)
  finite_train <- scored_base[train_fit_rows, , drop = FALSE]
  finite_train <- finite_train[stats::complete.cases(finite_train[, feature_cols, drop = FALSE]), , drop = FALSE]
  if (nrow(finite_train) < min_train_rows) {
    g5_stop(paste0("PCA k-means regime fit requires at least ", min_train_rows, " fully finite TRAIN rows."))
  }
  if (nrow(finite_train) <= cluster_count) {
    g5_stop("PCA k-means regime fit requires more finite TRAIN rows than clusters.")
  }
  keep <- feature_cols[vapply(feature_cols, function(col) {
    x <- as.numeric(finite_train[[col]])
    stats::sd(x, na.rm = TRUE) > 0 && all(is.finite(x))
  }, logical(1))]
  if (length(keep) < 3L) {
    g5_stop("PCA k-means regime fit has fewer than three finite non-zero-variance TRAIN features.")
  }
  dropped <- setdiff(feature_cols, keep)
  train_used <- finite_train[, keep, drop = FALSE]
  x_train <- scale(as.matrix(train_used))
  center <- attr(x_train, "scaled:center")
  scale <- attr(x_train, "scaled:scale")
  pca <- stats::prcomp(x_train, center = FALSE, scale. = FALSE)
  scoring_rows <- scored_base[stats::complete.cases(scored_base[, keep, drop = FALSE]), , drop = FALSE]
  x_all <- as.matrix(scoring_rows[, keep, drop = FALSE])
  x_all <- sweep(x_all, 2, center, "-")
  x_all <- sweep(x_all, 2, scale, "/")
  score <- x_all %*% pca$rotation[, 1:2, drop = FALSE]
  scoring_rows$pc1 <- as.numeric(score[, 1L])
  scoring_rows$pc2 <- as.numeric(score[, 2L])
  train_scored <- scoring_rows[g5_pca_regime_training_fit_rows(scoring_rows), , drop = FALSE]
  k_selection <- NULL
  if (identical(state_engine, "pca_kmeans_auto")) {
    k_selection <- g5_pca_regime_select_kmeans_k(
      train_scored[, c("pc1", "pc2"), drop = FALSE],
      min_clusters = auto_min_clusters,
      max_clusters = auto_max_clusters,
      nstart = nstart
    )
    cluster_count <- as.integer(k_selection$cluster_count)
    km <- k_selection$fit
  } else {
    set.seed(5101L)
    km <- stats::kmeans(train_scored[, c("pc1", "pc2"), drop = FALSE], centers = cluster_count, nstart = nstart)
  }
  centers <- as.matrix(km$centers[, c("pc1", "pc2"), drop = FALSE])
  center_order <- order(centers[, 1L], centers[, 2L])
  raw_to_state <- stats::setNames(g5_pca_regime_kmeans_states(cluster_count), as.character(center_order))
  distances <- sapply(seq_len(cluster_count), function(i) {
    (scoring_rows$pc1 - centers[i, 1L])^2 + (scoring_rows$pc2 - centers[i, 2L])^2
  })
  assigned_raw <- max.col(-distances, ties.method = "first")
  scoring_rows$cluster_raw <- assigned_raw
  scoring_rows$state_id <- unname(raw_to_state[as.character(assigned_raw)])
  scoring_rows$cluster_distance <- sqrt(distances[cbind(seq_len(nrow(distances)), assigned_raw)])
  explained <- (pca$sdev^2) / sum(pca$sdev^2)
  centroid_rows <- data.frame(
    record_type = "kmeans_centroid",
    feature = NA_character_,
    center = NA_real_,
    scale = NA_real_,
    loading_pc1 = NA_real_,
    loading_pc2 = NA_real_,
    break_axis = NA_character_,
    break_index = NA_integer_,
    break_value = NA_real_,
    cluster_raw = as.integer(names(raw_to_state)),
    state_id = as.character(raw_to_state),
    centroid_pc1 = centers[as.integer(names(raw_to_state)), 1L],
    centroid_pc2 = centers[as.integer(names(raw_to_state)), 2L],
    key = NA_character_,
    value = NA_character_,
    stringsAsFactors = FALSE
  )
  contract <- rbind(
    data.frame(
      record_type = "feature",
      feature = keep,
      center = as.numeric(center[keep]),
      scale = as.numeric(scale[keep]),
      loading_pc1 = as.numeric(pca$rotation[keep, 1L]),
      loading_pc2 = as.numeric(pca$rotation[keep, 2L]),
      break_axis = NA_character_,
      break_index = NA_integer_,
      break_value = NA_real_,
      cluster_raw = NA_integer_,
      state_id = NA_character_,
      centroid_pc1 = NA_real_,
      centroid_pc2 = NA_real_,
      key = NA_character_,
      value = NA_character_,
      stringsAsFactors = FALSE
    ),
    centroid_rows,
    data.frame(
      record_type = "meta",
      feature = NA_character_,
      center = NA_real_,
      scale = NA_real_,
      loading_pc1 = NA_real_,
      loading_pc2 = NA_real_,
      break_axis = NA_character_,
      break_index = NA_integer_,
      break_value = NA_real_,
      cluster_raw = NA_integer_,
      state_id = NA_character_,
      centroid_pc1 = NA_real_,
      centroid_pc2 = NA_real_,
      key = c("state_engine", "cluster_count", "cluster_count_mode", "nstart", "auto_min_clusters", "auto_max_clusters", "auto_selection_criterion", "train_start_date", "train_end_date", "oos_start_date", "oos_end_date", "fit_row_policy", "dropped_features"),
      value = c(
        state_engine,
        as.character(cluster_count),
        if (identical(state_engine, "pca_kmeans_auto")) "auto" else "fixed",
        as.character(nstart),
        if (identical(state_engine, "pca_kmeans_auto")) as.character(auto_min_clusters) else NA_character_,
        if (identical(state_engine, "pca_kmeans_auto")) as.character(auto_max_clusters) else NA_character_,
        if (identical(state_engine, "pca_kmeans_auto")) k_selection$criterion else NA_character_,
        as.character(as.Date(train_start_date)),
        as.character(as.Date(train_end_date)),
        as.character(as.Date(oos_start_date)),
        as.character(as.Date(oos_end_date)),
        if ("pca_training_role" %in% names(scored_base)) "TRAIN rows with pca_training_role=context" else "all TRAIN rows",
        paste(dropped, collapse = ";")
      ),
      stringsAsFactors = FALSE
    )
  )
  diagnostics <- data.frame(
    component = c("PC1", "PC2"),
    explained_variance = explained[1:2],
    stringsAsFactors = FALSE
  )
  cluster_diagnostics <- aggregate(
    cluster_distance ~ split + state_id,
    data = scoring_rows,
    FUN = function(x) c(row_count = length(x), mean_distance = mean(x), max_distance = max(x))
  )
  cluster_diagnostics <- do.call(data.frame, cluster_diagnostics)
  names(cluster_diagnostics) <- c("split", "state_id", "row_count", "mean_distance", "max_distance")
  if (!is.null(k_selection)) {
    auto_diag <- k_selection$diagnostics
    auto_diag$split <- "TRAIN"
    auto_diag$state_id <- NA_character_
    auto_diag$row_count <- NA_integer_
    auto_diag$mean_distance <- NA_real_
    auto_diag$max_distance <- NA_real_
    auto_diag <- auto_diag[, c("split", "state_id", "row_count", "mean_distance", "max_distance", "candidate_cluster_count", "train_row_count", "tot_withinss", "betweenss", "ch_index", "selected"), drop = FALSE]
    cluster_diagnostics$candidate_cluster_count <- NA_integer_
    cluster_diagnostics$train_row_count <- NA_integer_
    cluster_diagnostics$tot_withinss <- NA_real_
    cluster_diagnostics$betweenss <- NA_real_
    cluster_diagnostics$ch_index <- NA_real_
    cluster_diagnostics$selected <- NA
    cluster_diagnostics <- rbind(cluster_diagnostics, auto_diag)
  }
  list(
    scores = scoring_rows,
    model_contract = contract,
    diagnostics = diagnostics,
    cluster_diagnostics = cluster_diagnostics,
    kept_features = keep,
    dropped_features = dropped,
    state_engine = state_engine,
    state_ids = g5_pca_regime_kmeans_states(cluster_count),
    grid_n = cluster_count,
    cluster_count = cluster_count,
    cluster_count_mode = if (identical(state_engine, "pca_kmeans_auto")) "auto" else "fixed",
    auto_k_diagnostics = if (is.null(k_selection)) NULL else k_selection$diagnostics,
    kmeans_nstart = nstart,
    kmeans_centers = centroid_rows[, c("state_id", "cluster_raw", "centroid_pc1", "centroid_pc2"), drop = FALSE],
    pc1_breaks = numeric(),
    pc2_breaks = numeric()
  )
}

g5_pca_regime_state_coverage <- function(scores, grid_n = 3L, state_ids = NULL) {
  states <- if (is.null(state_ids)) {
    as.vector(outer(seq_len(grid_n), seq_len(grid_n), function(x, y) paste0("S", x, "_", y)))
  } else {
    as.character(state_ids)
  }
  splits <- c("TRAIN", "OOS")
  rows <- list()
  for (split in splits) {
    split_rows <- scores[scores$split == split, , drop = FALSE]
    total <- nrow(split_rows)
    for (state in states) {
      n <- sum(split_rows$state_id == state, na.rm = TRUE)
      rows[[length(rows) + 1L]] <- data.frame(
        split = split,
        state_id = state,
        row_count = n,
        row_fraction = if (total == 0L) NA_real_ else n / total,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

g5_pca_regime_run_lengths <- function(scores) {
  scores <- scores[order(as.Date(scores$session_date)), , drop = FALSE]
  if (nrow(scores) == 0L) {
    return(data.frame())
  }
  runs <- list()
  start_i <- 1L
  for (i in seq_len(nrow(scores))) {
    last_row <- i == nrow(scores)
    changed <- if (last_row) TRUE else !identical(scores$state_id[[i]], scores$state_id[[i + 1L]]) || !identical(scores$split[[i]], scores$split[[i + 1L]])
    if (changed) {
      runs[[length(runs) + 1L]] <- data.frame(
        split = scores$split[[i]],
        state_id = scores$state_id[[i]],
        start_date = as.Date(scores$session_date[[start_i]]),
        end_date = as.Date(scores$session_date[[i]]),
        run_length = i - start_i + 1L,
        stringsAsFactors = FALSE
      )
      start_i <- i + 1L
    }
  }
  do.call(rbind, runs)
}

g5_pca_regime_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_write_pca_regime_scatter_png <- function(scores, pc1_breaks, pc2_breaks, path, title = "PCA Regime State Space", width = 1300L, height = 900L, centroids = NULL) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  aesthetic <- g5_chart_aesthetic()
  plot_rows <- scores[is.finite(scores$pc1) & is.finite(scores$pc2) & !is.na(scores$state_id), , drop = FALSE]
  if (nrow(plot_rows) == 0L) {
    g5_stop("PCA scatter plot requires scored rows.")
  }
  pal <- g5_pca_regime_state_palette(sort(unique(plot_rows$state_id)))
  alpha <- ifelse(plot_rows$split == "OOS", 0.9, 0.38)
  cols <- vapply(
    seq_len(nrow(plot_rows)),
    function(i) grDevices::adjustcolor(pal[[plot_rows$state_id[[i]]]], alpha.f = alpha[[i]]),
    character(1L)
  )
  pch <- ifelse(plot_rows$split == "OOS", 21L, 23L)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(5.2, 5.4, 4.2, 10), xpd = FALSE, bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  graphics::plot(
    plot_rows$pc1,
    plot_rows$pc2,
    type = "n",
    xlab = "PC1",
    ylab = "PC2",
    main = title,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text
  )
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(col = aesthetic$grid)
  if (length(pc1_breaks) > 2L) {
    for (b in pc1_breaks[2:(length(pc1_breaks) - 1L)]) {
      graphics::abline(v = b, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.45), lty = 2)
    }
  }
  if (length(pc2_breaks) > 2L) {
    for (b in pc2_breaks[2:(length(pc2_breaks) - 1L)]) {
      graphics::abline(h = b, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.45), lty = 2)
    }
  }
  graphics::points(plot_rows$pc1, plot_rows$pc2, pch = pch, bg = cols, col = cols, cex = ifelse(plot_rows$split == "OOS", 1.0, 0.72))
  if (is.data.frame(centroids) && nrow(centroids)) {
    centroid_cols <- grDevices::adjustcolor(pal[as.character(centroids$state_id)], alpha.f = 1)
    graphics::points(centroids$centroid_pc1, centroids$centroid_pc2, pch = 4L, col = centroid_cols, cex = 1.6, lwd = 2.1)
  }
  split_legend_col <- c(
    grDevices::adjustcolor(aesthetic$text, alpha.f = 0.45),
    grDevices::adjustcolor(aesthetic$text, alpha.f = 0.9)
  )
  graphics::legend(
    "topright",
    legend = c("TRAIN", "OOS"),
    pch = c(23L, 21L),
    pt.bg = split_legend_col,
    col = split_legend_col,
    bty = "n",
    text.col = aesthetic$text
  )
  graphics::par(xpd = NA)
  graphics::legend("right", inset = c(-0.19, 0), legend = names(pal), fill = pal, border = NA, bty = "n", cex = 0.75, text.col = aesthetic$text, title = "state")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_pca_regime_state_runs_for_plot <- function(scores) {
  scores <- scores[order(as.Date(scores$session_date)), , drop = FALSE]
  runs <- g5_pca_regime_run_lengths(scores)
  if (!nrow(runs)) {
    return(runs)
  }
  runs$xleft <- match(as.Date(runs$start_date), as.Date(scores$session_date)) - 0.5
  runs$xright <- match(as.Date(runs$end_date), as.Date(scores$session_date)) + 0.5
  runs
}

g5_write_pca_regime_price_png <- function(scores, path, symbol, train_end_date, oos_start_date, title = NULL, width = 1500L, height = 850L) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  aesthetic <- g5_chart_aesthetic()
  scores <- scores[order(as.Date(scores$session_date)), , drop = FALSE]
  if (nrow(scores) == 0L) {
    g5_stop("PCA regime price chart requires scored rows.")
  }
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  if (is.null(title)) {
    title <- paste(symbol, "PCA 3x3 Regime Diagnostic")
  }
  x <- seq_len(nrow(scores))
  y <- as.numeric(scores$close)
  y_range <- range(y, finite = TRUE)
  padding <- diff(y_range) * 0.06
  if (!is.finite(padding) || padding <= 0) {
    padding <- max(abs(y_range), 1) * 0.02
  }
  y_limits <- y_range + c(-padding, padding)
  pal <- g5_pca_regime_state_palette(sort(unique(stats::na.omit(scores$state_id))))
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height), res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(10.1, 5.4, 4.2, 10), bg = aesthetic$background, fg = aesthetic$axis, col.axis = aesthetic$axis, col.lab = aesthetic$text, col.main = aesthetic$text)
  graphics::plot(
    c(0.5, length(x) + 0.5),
    y_limits,
    type = "n",
    xaxt = "n",
    xlab = "",
    ylab = "Adjusted daily close",
    main = title,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text
  )
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  runs <- g5_pca_regime_state_runs_for_plot(scores)
  if (nrow(runs)) {
    for (i in seq_len(nrow(runs))) {
      state <- runs$state_id[[i]]
      if (!is.na(state) && state %in% names(pal)) {
        graphics::rect(runs$xleft[[i]], usr[[3L]], runs$xright[[i]], usr[[4L]], col = grDevices::adjustcolor(pal[[state]], alpha.f = 0.16), border = NA)
      }
    }
  }
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  boundary_date <- as.Date(oos_start_date)
  boundary_idx <- match(boundary_date, as.Date(scores$session_date))
  if (!is.na(boundary_idx)) {
    graphics::abline(v = boundary_idx - 0.5, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.75), lty = 2, lwd = 1.3)
  }
  graphics::lines(x, y, col = aesthetic$text, lwd = 1.2)
  tick_count <- min(8L, length(x))
  tick_positions <- unique(round(seq(1L, length(x), length.out = tick_count)))
  g5_axis_date_labels_45(tick_positions, as.character(as.Date(scores$session_date)[tick_positions]), line_offset = 0.066, color = aesthetic$axis)
  graphics::mtext("Session date", side = 1, line = 8.0, cex = 1.1, col = aesthetic$text)
  graphics::mtext(
    paste0("TRAIN through ", as.Date(train_end_date), " | OOS starts ", as.Date(oos_start_date), " | colored bands: PCA states"),
    side = 3,
    line = 0.3,
    cex = 0.75,
    col = aesthetic$text
  )
  graphics::legend("topleft", legend = c("close", "TRAIN/OOS boundary"), col = c(aesthetic$text, aesthetic$axis), lty = c(1, 2), lwd = c(1.2, 1.3), bty = "n", text.col = aesthetic$text)
  graphics::par(xpd = NA)
  graphics::legend("right", inset = c(-0.19, 0), legend = names(pal), fill = grDevices::adjustcolor(pal, alpha.f = 0.55), border = NA, bty = "n", cex = 0.75, text.col = aesthetic$text, title = "state")
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_pca_regime_markdown_report <- function(result, paths, symbol, as_of_timestamp, path) {
  scores <- result$scores
  diagnostics <- result$diagnostics
  coverage <- result$state_coverage
  pct <- function(x) sprintf("%.2f%%", 100 * as.numeric(x))
  coverage_line <- function(split) {
    dat <- coverage[coverage$split == split & coverage$row_count > 0L, , drop = FALSE]
    paste(paste0(dat$state_id, "=", dat$row_count), collapse = ", ")
  }
  lines <- c(
    paste0("# PCA Regime POC: ", g5_standardize_symbol(symbol)[[1L]]),
    "",
    "Diagnostic only: this run labels PCA states and does not route WFA strategy selection.",
    "",
    "## Model",
    "",
    paste0("- As-of timestamp: `", as.character(as_of_timestamp), "`"),
    paste0("- State engine: `", if ("state_engine" %in% names(result)) result$state_engine else "quantile_grid", "`"),
    paste0("- State count: `", length(result$state_ids), "`"),
    paste0("- TRAIN: `", min(scores$session_date[scores$split == "TRAIN"]), " to ", max(scores$session_date[scores$split == "TRAIN"]), "`"),
    paste0("- OOS: `", min(scores$session_date[scores$split == "OOS"]), " to ", max(scores$session_date[scores$split == "OOS"]), "`"),
    paste0("- Kept features: `", paste(result$kept_features, collapse = ", "), "`"),
    paste0("- Dropped features: `", if (length(result$dropped_features)) paste(result$dropped_features, collapse = ", ") else "none", "`"),
    paste0("- PC1 explained variance: `", pct(diagnostics$explained_variance[diagnostics$component == "PC1"]), "`"),
    paste0("- PC2 explained variance: `", pct(diagnostics$explained_variance[diagnostics$component == "PC2"]), "`"),
    "",
    "## State Coverage",
    "",
    paste0("- TRAIN non-empty states: `", coverage_line("TRAIN"), "`"),
    paste0("- OOS non-empty states: `", coverage_line("OOS"), "`"),
    "",
    "## Key Artifacts",
    "",
    paste0("- PCA scatter: `", paths$pca_scatter_png, "`"),
    paste0("- Price/state chart: `", paths$price_state_png, "`"),
    paste0("- Scores CSV: `", paths$scores_csv, "`"),
    paste0("- Model contract CSV: `", paths$model_contract_csv, "`"),
    paste0("- State coverage CSV: `", paths$state_coverage_csv, "`"),
    paste0("- Cluster diagnostics CSV: `", if ("cluster_diagnostics_csv" %in% names(paths)) paths$cluster_diagnostics_csv else "not_applicable", "`")
  )
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

g5_write_pca_regime_outputs <- function(pca_result, output_dir, prefix, symbol, as_of_timestamp) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- list(
    scores_csv = file.path(output_dir, paste0(prefix, "_scores.csv")),
    model_contract_csv = file.path(output_dir, paste0(prefix, "_model_contract.csv")),
    diagnostics_csv = file.path(output_dir, paste0(prefix, "_diagnostics.csv")),
    cluster_diagnostics_csv = file.path(output_dir, paste0(prefix, "_cluster_diagnostics.csv")),
    state_coverage_csv = file.path(output_dir, paste0(prefix, "_state_coverage.csv")),
    run_lengths_csv = file.path(output_dir, paste0(prefix, "_run_lengths.csv")),
    pca_scatter_png = file.path(output_dir, paste0(prefix, "_pca_scatter.png")),
    price_state_png = file.path(output_dir, paste0(prefix, "_price_states.png")),
    report_md = file.path(output_dir, paste0(prefix, "_report.md"))
  )
  pca_result$state_coverage <- g5_pca_regime_state_coverage(pca_result$scores, pca_result$grid_n, pca_result$state_ids)
  pca_result$run_lengths <- g5_pca_regime_run_lengths(pca_result$scores)
  paths$scores_csv <- g5_pca_regime_write_csv(pca_result$scores, paths$scores_csv)
  paths$model_contract_csv <- g5_pca_regime_write_csv(pca_result$model_contract, paths$model_contract_csv)
  paths$diagnostics_csv <- g5_pca_regime_write_csv(pca_result$diagnostics, paths$diagnostics_csv)
  if ("cluster_diagnostics" %in% names(pca_result)) {
    paths$cluster_diagnostics_csv <- g5_pca_regime_write_csv(pca_result$cluster_diagnostics, paths$cluster_diagnostics_csv)
  } else {
    paths$cluster_diagnostics_csv <- NA_character_
  }
  paths$state_coverage_csv <- g5_pca_regime_write_csv(pca_result$state_coverage, paths$state_coverage_csv)
  paths$run_lengths_csv <- g5_pca_regime_write_csv(pca_result$run_lengths, paths$run_lengths_csv)
  train_end <- max(pca_result$scores$session_date[pca_result$scores$split == "TRAIN"])
  oos_start <- min(pca_result$scores$session_date[pca_result$scores$split == "OOS"])
  centroids <- if ("kmeans_centers" %in% names(pca_result)) pca_result$kmeans_centers else NULL
  title_suffix <- if (identical(pca_result$state_engine, "pca_kmeans_auto")) {
    "PCA Auto K-Means State Space"
  } else if (identical(pca_result$state_engine, "pca_kmeans")) {
    "PCA K-Means State Space"
  } else {
    "PCA 3x3 State Space"
  }
  paths$pca_scatter_png <- g5_write_pca_regime_scatter_png(pca_result$scores, pca_result$pc1_breaks, pca_result$pc2_breaks, paths$pca_scatter_png, title = paste(g5_standardize_symbol(symbol)[[1L]], title_suffix), centroids = centroids)
  price_title <- if (identical(pca_result$state_engine, "pca_kmeans_auto")) {
    paste(g5_standardize_symbol(symbol)[[1L]], "PCA Auto K-Means Regime Diagnostic")
  } else if (identical(pca_result$state_engine, "pca_kmeans")) {
    paste(g5_standardize_symbol(symbol)[[1L]], "PCA K-Means Regime Diagnostic")
  } else {
    paste(g5_standardize_symbol(symbol)[[1L]], "PCA 3x3 Regime Diagnostic")
  }
  paths$price_state_png <- g5_write_pca_regime_price_png(pca_result$scores, paths$price_state_png, symbol, train_end_date = train_end, oos_start_date = oos_start, title = price_title)
  paths$report_md <- g5_pca_regime_markdown_report(pca_result, paths, symbol, as_of_timestamp, paths$report_md)
  list(paths = paths, result = pca_result)
}
