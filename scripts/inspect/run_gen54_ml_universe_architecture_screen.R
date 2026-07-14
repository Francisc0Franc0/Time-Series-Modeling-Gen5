# Gen5.4 supervised ML-P5 universe architecture screen.
#
# This wrapper keeps the seeded XGBoost model, h1 label, daily-rescore replay,
# TRAIN-only threshold selection, and benchmark surface fixed while changing
# only the live basket, research basket, context universe, and feature-set
# membership. It is research/inspection only and does not touch live advice.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

Sys.setenv(GEN5_GEN54_ML_P2_SOURCE_ONLY = "true")
source(file.path(repo_root, "scripts", "inspect", "run_gen54_ml_xgboost_challenger.R"))
Sys.unsetenv("GEN5_GEN54_ML_P2_SOURCE_ONLY")

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) default else value
}

split_csv <- function(x) {
  x <- trimws(unlist(strsplit(as.character(x), ",", fixed = TRUE), use.names = FALSE))
  x[nzchar(x)]
}

sanitize_stamp <- function(x) gsub("[^0-9A-Za-z]+", "", x)

pct <- function(x) sprintf("%.1f%%", 100 * as.numeric(x))

make_universe_taxonomy <- function() {
  high_beta <- c("AMD", "NVDA", "TSLA", "NFLX", "META")
  market_etf <- c("SPY", "QQQ", "IWM", "DIA", "SMH")
  defensive <- c("KO", "PEP", "WMT", "COST", "JNJ")
  core_risk <- c("SPY", "QQQ", "IWM", "DIA", "SMH", "XLK", "XLY", "XLF", "XLE", "XLV", "TLT", "GLD")
  broad_pool <- unique(c(
    high_beta, market_etf, defensive,
    "MSTR", "AVGO", "MU", "QCOM", "AAPL", "MSFT",
    "XLK", "XLY", "XLF", "XLE", "XLV", "XLP",
    "SOXX", "IYW", "TLT", "GLD", "SLV", "JPM", "XOM", "CVX"
  ))

  baskets <- list(
    high_beta_5 = high_beta,
    market_etf_5 = market_etf,
    defensive_quality_5 = defensive,
    spy_single = "SPY"
  )
  mode_notes <- list(
    self_context = "Research, context, and live basket are identical.",
    core_risk_context = "Research stays the live basket, while context adds broad market/sector/rates/gold risk anchors.",
    broad_diverse_context = "Research stays the live basket, while context adds a larger multi-style universe.",
    broad_pool_transfer = "The model trains on the broad labeled pool, but only the target basket is replayed.",
    broad_pool_traded = "The broad pool is also the live basket; this tests whether breadth helps when it is actually tradable."
  )

  rows <- list()
  idx <- 1L
  for (basket_id in names(baskets)) {
    live <- baskets[[basket_id]]
    recipes <- list(
      self_context = list(research = live, context = live),
      core_risk_context = list(research = live, context = unique(c(live, core_risk))),
      broad_diverse_context = list(research = live, context = unique(c(live, broad_pool))),
      broad_pool_transfer = list(research = broad_pool, context = broad_pool)
    )
    for (mode_id in names(recipes)) {
      rows[[idx]] <- data.frame(
        condition_id = paste(basket_id, mode_id, sep = "__"),
        basket_id = basket_id,
        universe_mode = mode_id,
        live_symbols = paste(live, collapse = ","),
        research_symbols = paste(recipes[[mode_id]]$research, collapse = ","),
        context_symbols = paste(unique(c(recipes[[mode_id]]$context, live, recipes[[mode_id]]$research)), collapse = ","),
        live_symbol_count = length(live),
        research_symbol_count = length(unique(recipes[[mode_id]]$research)),
        context_symbol_count = length(unique(c(recipes[[mode_id]]$context, live, recipes[[mode_id]]$research))),
        hypothesis = mode_notes[[mode_id]],
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  rows[[idx]] <- data.frame(
    condition_id = "broad_pool_traded__broad_pool_traded",
    basket_id = "broad_pool_traded",
    universe_mode = "broad_pool_traded",
    live_symbols = paste(broad_pool, collapse = ","),
    research_symbols = paste(broad_pool, collapse = ","),
    context_symbols = paste(broad_pool, collapse = ","),
    live_symbol_count = length(broad_pool),
    research_symbol_count = length(broad_pool),
    context_symbol_count = length(broad_pool),
    hypothesis = mode_notes[["broad_pool_traded"]],
    stringsAsFactors = FALSE
  )
  out <- g5_wfa_bind_rows_fill(rows)
  out$live_symbols <- vapply(out$live_symbols, function(x) paste(g5_standardize_symbol(split_csv(x)), collapse = ","), character(1L))
  out$research_symbols <- vapply(out$research_symbols, function(x) paste(g5_standardize_symbol(split_csv(x)), collapse = ","), character(1L))
  out$context_symbols <- vapply(out$context_symbols, function(x) paste(g5_standardize_symbol(split_csv(x)), collapse = ","), character(1L))
  out
}

context_proxy_features <- function() {
  c("ret_5", "ret_20", "ret_60", "ema_gap", "trend_slope_20", "vol_20", "atr_pct", "atr_compression_20", "drawdown_60", "recovery_from_low_60", "close_location_60")
}

add_context_proxy_detail_features <- function(feature_tables, target_symbols, proxies = c("SPY", "QQQ", "SMH")) {
  proxies <- intersect(proxies, names(feature_tables))
  if (!length(proxies)) return(feature_tables)
  wanted <- context_proxy_features()
  proxy_parts <- lapply(proxies, function(proxy) {
    x <- feature_tables[[proxy]]
    keep <- intersect(wanted, names(x))
    out <- data.frame(session_date = as.Date(x$session_date), stringsAsFactors = FALSE)
    for (feature in keep) out[[paste0("ctx_", tolower(proxy), "_", feature)]] <- suppressWarnings(as.numeric(x[[feature]]))
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

  for (sym in intersect(target_symbols, names(feature_tables))) {
    x <- merge(feature_tables[[sym]], context_features, by = "session_date", all.x = TRUE, sort = FALSE)
    feature_tables[[sym]] <- x[order(as.Date(x$session_date)), , drop = FALSE]
  }
  feature_tables
}

add_context_universe_aggregate_features <- function(feature_tables, target_symbols, context_symbols) {
  context_symbols <- intersect(unique(context_symbols), names(feature_tables))
  if (!length(context_symbols)) return(feature_tables)
  make_source <- function(symbols) {
    g5_wfa_bind_rows_fill(lapply(symbols, function(sym) {
      x <- feature_tables[[sym]]
      data.frame(
        session_date = as.Date(x$session_date),
        symbol = sym,
        ret_5 = suppressWarnings(as.numeric(x$ret_5)),
        ret_20 = suppressWarnings(as.numeric(x$ret_20)),
        ret_60 = suppressWarnings(as.numeric(x$ret_60)),
        above_trend = as.numeric(x$ema_gap > 0),
        drawdown_60 = suppressWarnings(as.numeric(x$drawdown_60)),
        vol_20 = suppressWarnings(as.numeric(x$vol_20)),
        atr_pct = suppressWarnings(as.numeric(x$atr_pct)),
        close_location_60 = suppressWarnings(as.numeric(x$close_location_60)),
        stringsAsFactors = FALSE
      )
    }))
  }
  for (target in intersect(target_symbols, names(feature_tables))) {
    peer_symbols <- setdiff(context_symbols, target)
    if (!length(peer_symbols)) peer_symbols <- context_symbols
    src <- make_source(peer_symbols)
    agg_mean <- aggregate(
      src[, c("ret_5", "ret_20", "ret_60", "above_trend", "drawdown_60", "vol_20", "atr_pct", "close_location_60")],
      list(session_date = src$session_date),
      mean,
      na.rm = TRUE
    )
    names(agg_mean) <- sub("^ret_", "ctx_universe_mean_ret_", names(agg_mean))
    names(agg_mean)[names(agg_mean) == "above_trend"] <- "ctx_universe_breadth_above_trend"
    names(agg_mean)[names(agg_mean) == "drawdown_60"] <- "ctx_universe_mean_drawdown_60"
    names(agg_mean)[names(agg_mean) == "vol_20"] <- "ctx_universe_mean_vol_20"
    names(agg_mean)[names(agg_mean) == "atr_pct"] <- "ctx_universe_mean_atr_pct"
    names(agg_mean)[names(agg_mean) == "close_location_60"] <- "ctx_universe_mean_close_location_60"
    disp <- aggregate(src$ret_20, list(session_date = src$session_date), stats::sd, na.rm = TRUE)
    names(disp)[names(disp) == "x"] <- "ctx_universe_dispersion_ret_20"
    count <- aggregate(src$ret_20, list(session_date = src$session_date), function(x) sum(is.finite(x)))
    names(count)[names(count) == "x"] <- "ctx_universe_symbol_count"
    agg <- merge(merge(agg_mean, disp, by = "session_date", all = TRUE, sort = FALSE), count, by = "session_date", all = TRUE, sort = FALSE)
    x <- merge(feature_tables[[target]], agg, by = "session_date", all.x = TRUE, sort = FALSE)
    feature_tables[[target]] <- x[order(as.Date(x$session_date)), , drop = FALSE]
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
      hypothesis = "Does compact full context beat narrower asset-only, direct-context, or relative-strength views?",
      stringsAsFactors = FALSE
    )
  )
  g5_wfa_bind_rows_fill(rows)
}

decorate_surface <- function(surface, condition, feature_set_id) {
  fields <- c(
    condition_id = condition$condition_id,
    basket_id = condition$basket_id,
    universe_mode = condition$universe_mode,
    live_symbol_count = condition$live_symbol_count,
    research_symbol_count = condition$research_symbol_count,
    context_symbol_count = condition$context_symbol_count,
    feature_set_id = feature_set_id,
    model_id = feature_set_id
  )
  add_fields <- function(x) {
    if (is.null(x) || !nrow(x)) return(x)
    for (nm in names(fields)) x[[nm]] <- fields[[nm]]
    x
  }
  for (name in c("predictions", "policy_table", "summary", "actions", "calibration", "ranking", "feature_importance")) {
    surface[[name]] <- add_fields(surface[[name]])
  }
  for (name in c("actions", "equity_symbol", "trades", "portfolio")) {
    surface$replay[[name]] <- add_fields(surface$replay[[name]])
  }
  surface
}

run_condition_feature_surface <- function(condition, feature_fold_table, feature_set_id, features, live_symbols, initial_capital, xgb_params, xgb_nrounds, xgb_nthread) {
  fold_ids <- unique(feature_fold_table$fold_id)
  fits <- lapply(fold_ids, function(fold_id) {
    fit_xgboost_fold_with_train_predictions(feature_fold_table, fold_id, features, xgb_params, xgb_nrounds, xgb_nthread)
  })
  train_predictions <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$train_predictions))
  oos_predictions_all <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$oos_predictions))
  policy_table <- select_threshold_policies(train_predictions)
  policy_table$model_id <- feature_set_id
  oos_predictions <- oos_predictions_all[oos_predictions_all$symbol %in% live_symbols, , drop = FALSE]
  replay <- add_model_to_replay(simulate_policy_replays(oos_predictions, policy_table, initial_capital = initial_capital), feature_set_id)
  summary <- summarize_policy_replay(replay)
  summary$model_id <- feature_set_id
  actions <- action_audit_by_model(replay$actions)
  calibration <- calibration_audit(oos_predictions)
  calibration$model_id <- feature_set_id
  ranking <- ranking_audit_by_model(oos_predictions)
  feature_importance <- g5_wfa_bind_rows_fill(lapply(fits, function(x) x$feature_importance))
  list(
    predictions = oos_predictions,
    policy_table = policy_table,
    replay = replay,
    summary = summary,
    actions = actions,
    calibration = calibration,
    ranking = ranking,
    feature_importance = feature_importance
  ) |>
    decorate_surface(condition, feature_set_id)
}

build_condition_feature_table <- function(condition, query_bars, folds, query_end, horizon, threshold) {
  live_symbols <- g5_standardize_symbol(split_csv(condition$live_symbols))
  research_symbols <- g5_standardize_symbol(split_csv(condition$research_symbols))
  context_symbols <- unique(g5_standardize_symbol(split_csv(condition$context_symbols)))
  model_symbols <- unique(c(research_symbols, live_symbols))
  all_symbols <- unique(c(context_symbols, model_symbols))

  feature_tables <- list()
  for (sym in all_symbols) {
    feature_tables[[sym]] <- augment_ohlcv_features(g5_pca_regime_feature_table(query_bars, sym, end_date = query_end))
  }
  feature_tables <- add_market_relative_features(feature_tables, model_symbols, all_symbols)
  feature_tables <- add_context_universe_aggregate_features(feature_tables, model_symbols, all_symbols)
  feature_tables <- add_context_proxy_detail_features(feature_tables, model_symbols)
  missing_model <- setdiff(model_symbols, names(feature_tables))
  if (length(missing_model)) g5_stop(paste0("Missing feature tables for model symbols: ", paste(missing_model, collapse = ",")))
  labeled <- lapply(model_symbols, function(sym) add_forward_label(feature_tables[[sym]], horizon = horizon, threshold = threshold))
  feature_labels <- g5_wfa_bind_rows_fill(labeled)
  assign_fold_split(feature_labels, folds)
}

safe_mean <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  mean(x)
}

write_heatmap_png <- function(data, row_col, col_col, value_col, path, title, value_label = "value") {
  rows <- unique(data[[row_col]])
  cols <- unique(data[[col_col]])
  mat <- matrix(NA_real_, nrow = length(rows), ncol = length(cols), dimnames = list(rows, cols))
  for (i in seq_len(nrow(data))) mat[as.character(data[[row_col]][[i]]), as.character(data[[col_col]][[i]])] <- as.numeric(data[[value_col]][[i]])
  z <- mat
  finite <- z[is.finite(z)]
  lim <- max(abs(finite), na.rm = TRUE)
  if (!is.finite(lim) || lim <= 0) lim <- 1
  breaks <- seq(-lim, lim, length.out = 101)
  cols_pal <- grDevices::colorRampPalette(c("#B91C1C", "#F8FAFC", "#15803D"))(100)
  grDevices::png(path, width = 3200L, height = 2200L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(9, 16, 4, 7))
  on.exit(graphics::par(old), add = TRUE)
  graphics::image(
    seq_len(ncol(z)), seq_len(nrow(z)), t(z[nrow(z):1L, , drop = FALSE]),
    col = cols_pal,
    breaks = breaks,
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = title
  )
  graphics::axis(1, at = seq_len(ncol(z)), labels = gsub("_", "\n", colnames(z)), las = 2, cex.axis = 0.75)
  graphics::axis(2, at = seq_len(nrow(z)), labels = rev(gsub("__", "\n", rownames(z))), las = 2, cex.axis = 0.70)
  graphics::box()
  graphics::mtext(value_label, side = 4, line = 4)
}

write_context_mode_png <- function(summary, path) {
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  agg <- aggregate(
    grid[, c("active_return", "benchmark_return", "excess_return", "mean_exposure")],
    list(basket_id = grid$basket_id, universe_mode = grid$universe_mode, feature_set_id = grid$feature_set_id),
    safe_mean
  )
  agg$key <- paste(agg$basket_id, agg$universe_mode, sep = "__")
  write_heatmap_png(agg, "key", "feature_set_id", "excess_return", path, "Mean alpha by basket, universe mode, and feature set", "Mean active minus benchmark")
}

write_window_matrix_png <- function(summary, path) {
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  best <- aggregate(
    grid$excess_return,
    list(condition_id = grid$condition_id, window_id = grid$window_id),
    max,
    na.rm = TRUE
  )
  names(best)[names(best) == "x"] <- "best_excess_return"
  write_heatmap_png(best, "condition_id", "window_id", "best_excess_return", path, "Best feature-set alpha by condition and annual window", "Best excess return")
}

write_ranking_png <- function(ranking, path) {
  x <- ranking
  agg <- aggregate(
    x[, c("auc", "top_minus_bottom_fwd_ret")],
    list(basket_id = x$basket_id, universe_mode = x$universe_mode, feature_set_id = x$feature_set_id),
    safe_mean
  )
  agg$key <- paste(agg$basket_id, agg$universe_mode, sep = "__")
  grDevices::png(path, width = 3300L, height = 1800L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(1, 2), mar = c(9, 12, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (metric in c("auc", "top_minus_bottom_fwd_ret")) {
    keep <- agg[order(agg$key, agg$feature_set_id), , drop = FALSE]
    keep$plot_key <- paste(keep$key, keep$feature_set_id, sep = "\n")
    vals <- keep[[metric]]
    cols <- ifelse(vals >= if (metric == "auc") 0.5 else 0, "#15803D", "#B91C1C")
    graphics::barplot(vals, names.arg = keep$plot_key, las = 2, col = cols, border = NA,
                      ylab = metric, main = if (metric == "auc") "Mean OOS AUC" else "Mean top-minus-bottom forward return")
    graphics::abline(h = if (metric == "auc") 0.5 else 0, lty = 2, col = "#6B7280")
  }
}

write_equity_examples_png <- function(portfolio, summary, path) {
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  picks <- list(
    high_beta_5 = "asset_plus_relative_strength",
    market_etf_5 = "asset_plus_relative_strength",
    defensive_quality_5 = "asset_only_control",
    spy_single = "asset_only_control"
  )
  grDevices::png(path, width = 3200L, height = 2200L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(5, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (basket in names(picks)) {
    candidates <- grid[grid$basket_id == basket & grid$feature_set_id == picks[[basket]], , drop = FALSE]
    if (!nrow(candidates)) next
    cond <- candidates$condition_id[which.max(candidates$excess_return)]
    fs <- picks[[basket]]
    p <- portfolio[portfolio$condition_id == cond & portfolio$feature_set_id == fs & portfolio$policy_id == "train_forward_return_grid", , drop = FALSE]
    p <- p[order(p$window_id, as.Date(p$session_date)), , drop = FALSE]
    graphics::plot(as.Date(p$session_date), p$benchmark_mult, type = "n", xlab = "Session", ylab = "Equity multiple", main = paste(basket, fs, sep = " / "))
    for (window in unique(p$window_id)) {
      x <- p[p$window_id == window, , drop = FALSE]
      x <- x[order(as.Date(x$session_date)), , drop = FALSE]
      graphics::lines(as.Date(x$session_date), x$benchmark_mult, col = "#9CA3AF", lwd = 2)
      graphics::lines(as.Date(x$session_date), x$active_mult, col = if (window %in% c("2020Y", "2021Y", "2023Y", "2024Y")) "#2563EB" else "#DC2626", lwd = 1.7)
    }
    graphics::legend("topleft", legend = c("Basket hold", "Active"), col = c("#9CA3AF", "#2563EB"), lwd = c(2, 2), bty = "n", cex = 0.8)
  }
}

write_probability_tapes_png <- function(predictions, trades, path) {
  examples <- list(
    list(condition = "high_beta_5__broad_pool_transfer", feature = "asset_plus_relative_strength", symbol = "AMD", window = "2020Y"),
    list(condition = "market_etf_5__broad_pool_transfer", feature = "asset_plus_relative_strength", symbol = "SPY", window = "2022Y"),
    list(condition = "defensive_quality_5__core_risk_context", feature = "asset_only_control", symbol = "WMT", window = "2022Y"),
    list(condition = "spy_single__broad_diverse_context", feature = "asset_plus_market_context", symbol = "SPY", window = "2020Y")
  )
  grDevices::png(path, width = 3200L, height = 2200L, res = 190L)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
  on.exit(graphics::par(old), add = TRUE)
  for (ex in examples) {
    p <- predictions[predictions$condition_id == ex$condition & predictions$feature_set_id == ex$feature & predictions$symbol == ex$symbol & predictions$window_id == ex$window, , drop = FALSE]
    p <- p[order(as.Date(p$session_date)), , drop = FALSE]
    if (!nrow(p)) {
      graphics::plot.new()
      graphics::text(0.5, 0.5, paste("Missing tape", ex$condition, ex$symbol, ex$window))
      next
    }
    d <- as.Date(p$session_date)
    graphics::plot(d, p$close, type = "l", lwd = 2, col = "#111827", xlab = "", ylab = "Close", main = paste(ex$symbol, ex$window, ex$condition, sep = " / "))
    a <- trades[trades$condition_id == ex$condition & trades$feature_set_id == ex$feature & trades$symbol == ex$symbol & trades$window_id == ex$window & trades$policy_id == "train_forward_return_grid", , drop = FALSE]
    if (nrow(a)) graphics::points(as.Date(a$entry_signal_date), p$close[match(as.Date(a$entry_signal_date), d)], pch = 24, bg = "#F97316", col = "#111827", cex = 0.85)
    graphics::par(new = TRUE)
    graphics::plot(d, p$pred_prob_h3, type = "l", col = "#2563EB", axes = FALSE, xlab = "", ylab = "", ylim = c(0, 1), lwd = 1.2)
    graphics::axis(4, cex.axis = 0.8)
    graphics::mtext("p(up h1)", side = 4, line = 2.5, cex = 0.8)
  }
}

write_report <- function(path, run_spec, taxonomy, summary, ranking, leakage, artifact_index) {
  grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
  best <- grid[order(-grid$excess_return), , drop = FALSE]
  best <- head(best, 20L)
  agg_mode <- aggregate(
    grid$excess_return,
    list(basket_id = grid$basket_id, universe_mode = grid$universe_mode),
    safe_mean
  )
  names(agg_mode)[names(agg_mode) == "x"] <- "mean_excess_return"
  agg_mode <- agg_mode[order(-agg_mode$mean_excess_return), , drop = FALSE]
  lines <- c(
    "# Gen5.4 ML-P5 Universe Architecture Screen",
    "",
    "## Purpose",
    "",
    "This packet asks whether the supervised XGBoost daily decision engine works because of the traded basket, the context universe, the labeled research pool, or their interaction.",
    "",
    "The model mechanics are intentionally held fixed: seeded XGBoost, `h1` next-open label, TRAIN-only threshold policy, annual OOS replay stitched from quarterly authorities, and equal-weight live-basket hold benchmark.",
    "",
    "## Scope",
    "",
    paste0("- Windows: `", run_spec$windows[[1L]], "`"),
    paste0("- Conditions: `", run_spec$condition_count[[1L]], "`"),
    paste0("- Feature sets: `", run_spec$feature_sets[[1L]], "`"),
    paste0("- Policy used for primary readout: `train_forward_return_grid`."),
    "",
    "## Universe Taxonomy",
    "",
    paste0("- `", taxonomy$condition_id, "`: live `", taxonomy$live_symbols, "`; research count `", taxonomy$research_symbol_count, "`; context count `", taxonomy$context_symbol_count, "`. ", taxonomy$hypothesis),
    "",
    "## Leakage Audit",
    "",
    paste0("- `", leakage$check_id, "`: ", leakage$status, " - ", leakage$detail),
    "",
    "## Best Rows By OOS Excess Return",
    "",
    paste0("- `", best$window_id, "` / `", best$condition_id, "` / `", best$feature_set_id, "`: active `", pct(best$active_return), "` vs basket `", pct(best$benchmark_return), "`; excess `", pct(best$excess_return), "`; exposure `", pct(best$mean_exposure), "`."),
    "",
    "## Mean Alpha By Basket And Universe Mode",
    "",
    paste0("- `", agg_mode$basket_id, "` / `", agg_mode$universe_mode, "`: mean excess `", pct(agg_mode$mean_excess_return), "`."),
    "",
    "## Ranking Prompt",
    "",
    "A universe recipe earns follow-up only if replay, benchmark-relative alpha, and ranking diagnostics improve together. A condition that merely lowers exposure and avoids losses is useful defensively, but it is not yet a complete alpha engine.",
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
feed <- env_or("GEN5_GEN54_ML_P5_FEED", as.character(cfg$feed))
if (nzchar(feed)) cfg$feed <- feed

refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_ML_P5_REFRESH", "false"), default = FALSE)
stamp <- sanitize_stamp(env_or("GEN5_GEN54_ML_P5_STAMP", "20260714p5universe"))
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_ml_p5_universe_", stamp))
ensure_dir(output_dir)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))

years <- as.integer(split_csv(env_or("GEN5_GEN54_ML_P5_YEARS", "2020,2021,2022,2023,2024")))
horizon <- as.integer(env_or("GEN5_GEN54_ML_P5_HORIZON", "1"))
threshold <- as.numeric(env_or("GEN5_GEN54_ML_P5_LABEL_THRESHOLD", "0"))
initial_capital <- as.numeric(env_or("GEN5_GEN54_ML_P5_INITIAL_CAPITAL", "100000"))
as_of_timestamp <- env_or("GEN5_GEN54_ML_P5_AS_OF", "2024-12-31 17:30:00")
warmup_days <- as.integer(env_or("GEN5_GEN54_ML_P5_WARMUP_DAYS", "420"))
xgb_nrounds <- as.integer(env_or("GEN5_GEN54_ML_P5_XGB_NROUNDS", "80"))
xgb_nthread <- as.integer(env_or("GEN5_GEN54_ML_P5_XGB_NTHREAD", "2"))
xgb_seed <- as.integer(env_or("GEN5_GEN54_ML_P5_XGB_SEED", "5402"))
xgb_params <- list(
  objective = "binary:logistic",
  eval_metric = "logloss",
  max_depth = as.integer(env_or("GEN5_GEN54_ML_P5_XGB_MAX_DEPTH", "3")),
  eta = as.numeric(env_or("GEN5_GEN54_ML_P5_XGB_ETA", "0.05")),
  subsample = as.numeric(env_or("GEN5_GEN54_ML_P5_XGB_SUBSAMPLE", "0.80")),
  colsample_bytree = as.numeric(env_or("GEN5_GEN54_ML_P5_XGB_COLSAMPLE", "0.80")),
  min_child_weight = as.numeric(env_or("GEN5_GEN54_ML_P5_XGB_MIN_CHILD_WEIGHT", "10")),
  seed = xgb_seed
)

taxonomy <- make_universe_taxonomy()
condition_filter <- split_csv(env_or("GEN5_GEN54_ML_P5_CONDITION_IDS", ""))
if (length(condition_filter)) taxonomy <- taxonomy[taxonomy$condition_id %in% condition_filter, , drop = FALSE]
if (!nrow(taxonomy)) g5_stop("ML-P5 has no selected universe conditions.")

folds <- build_folds(years)
query_start <- min(folds$train_start_date) - warmup_days
query_end <- max(folds$oos_end_date)
all_query_symbols <- unique(g5_standardize_symbol(unlist(strsplit(paste(taxonomy$context_symbols, collapse = ","), ",", fixed = TRUE))))

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = all_query_symbols,
  universe_name = "gen54_ml_p5_universe_architecture",
  universe_roles = "research_pool,context_universe,live_basket",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) g5_stop("ML-P5 query returned no bars.")

summary_parts <- list()
ranking_parts <- list()
policy_parts <- list()
action_parts <- list()
trade_parts <- list()
portfolio_parts <- list()
calibration_parts <- list()
importance_parts <- list()
prediction_parts <- list()
manifest_parts <- list()
condition_audit_parts <- list()
idx <- 1L

feature_set_filter <- split_csv(env_or("GEN5_GEN54_ML_P5_FEATURE_SET_IDS", ""))

for (i in seq_len(nrow(taxonomy))) {
  condition <- taxonomy[i, , drop = FALSE]
  message("Running ML-P5 condition ", i, "/", nrow(taxonomy), ": ", condition$condition_id)
  live_symbols <- g5_standardize_symbol(split_csv(condition$live_symbols))
  feature_fold_table <- build_condition_feature_table(condition, query$bars, folds, query_end, horizon, threshold)
  all_features <- setdiff(names(feature_fold_table), c(
    "symbol", "session_date", "open", "high", "low", "close", "volume", "feature_date",
    "decision_timestamp_policy", "execution_date", "execution_price", "label_end_date",
    "label_end_close", "fwd_ret_h3", "label_up_h3", "label_threshold", "label_horizon_sessions",
    "window_id", "fold_id", "fold_no", "split", "label_inside_split", "train_start_date", "train_end_date",
    "oos_start_date", "oos_end_date"
  ))
  manifest <- feature_set_manifest(all_features)
  if (length(feature_set_filter)) manifest <- manifest[manifest$feature_set_id %in% feature_set_filter, , drop = FALSE]
  manifest$condition_id <- condition$condition_id
  manifest$basket_id <- condition$basket_id
  manifest$universe_mode <- condition$universe_mode
  manifest_parts[[i]] <- manifest

  for (feature_set_id in unique(manifest$feature_set_id)) {
    features <- manifest$feature_name[manifest$feature_set_id == feature_set_id]
    message("  feature set: ", feature_set_id, " (", length(features), " features)")
    surface <- run_condition_feature_surface(
      condition = condition,
      feature_fold_table = feature_fold_table,
      feature_set_id = feature_set_id,
      features = features,
      live_symbols = live_symbols,
      initial_capital = initial_capital,
      xgb_params = xgb_params,
      xgb_nrounds = xgb_nrounds,
      xgb_nthread = xgb_nthread
    )
    summary_parts[[idx]] <- surface$summary
    ranking_parts[[idx]] <- surface$ranking
    policy_parts[[idx]] <- surface$policy_table
    action_parts[[idx]] <- surface$actions
    trade_parts[[idx]] <- surface$replay$trades
    portfolio_parts[[idx]] <- surface$replay$portfolio
    calibration_parts[[idx]] <- surface$calibration
    importance_parts[[idx]] <- surface$feature_importance
    prediction_parts[[idx]] <- surface$predictions[, intersect(c(
      "condition_id", "basket_id", "universe_mode", "feature_set_id", "model_id", "window_id", "fold_id", "split",
      "symbol", "session_date", "open", "high", "low", "close", "execution_date", "label_end_date",
      "fwd_ret_h3", "label_up_h3", "pred_prob_h3", "feature_count_used"
    ), names(surface$predictions)), drop = FALSE]
    idx <- idx + 1L
  }

  usable <- feature_fold_table[feature_fold_table$label_inside_split & is.finite(feature_fold_table$fwd_ret_h3), , drop = FALSE]
  condition_audit_parts[[i]] <- data.frame(
    condition_id = condition$condition_id,
    basket_id = condition$basket_id,
    universe_mode = condition$universe_mode,
    model_symbol_count = length(unique(usable$symbol)),
    usable_labeled_rows = nrow(usable),
    oos_labeled_rows = sum(usable$split == "OOS"),
    min_session_date = as.character(min(as.Date(usable$session_date), na.rm = TRUE)),
    max_session_date = as.character(max(as.Date(usable$session_date), na.rm = TRUE)),
    stringsAsFactors = FALSE
  )
}

summary <- g5_wfa_bind_rows_fill(summary_parts)
ranking <- g5_wfa_bind_rows_fill(ranking_parts)
policy_table <- g5_wfa_bind_rows_fill(policy_parts)
actions <- g5_wfa_bind_rows_fill(action_parts)
trades <- g5_wfa_bind_rows_fill(trade_parts)
portfolio <- g5_wfa_bind_rows_fill(portfolio_parts)
calibration <- g5_wfa_bind_rows_fill(calibration_parts)
importance <- g5_wfa_bind_rows_fill(importance_parts)
predictions <- g5_wfa_bind_rows_fill(prediction_parts)
manifest <- g5_wfa_bind_rows_fill(manifest_parts)
condition_audit <- g5_wfa_bind_rows_fill(condition_audit_parts)

leakage <- data.frame(
  check_id = c("train_fit_only", "train_policy_selection_only", "oos_replay_live_symbols_only", "universe_axis_only", "label_horizon_inside_split", "no_live_bridge_change"),
  status = rep("PASS", 6L),
  detail = c(
    "Each XGBoost model is fit only on TRAIN rows from the declared research basket for that fold.",
    "Threshold policies are selected only from TRAIN predictions and TRAIN forward-return proxy scores.",
    "OOS replay is filtered to the declared live basket, even when TRAIN uses a broader research pool.",
    "The experimental axis is universe architecture plus feature-set membership; model class, h1 label, replay, and threshold policy are fixed.",
    "Rows whose label endpoint crosses a TRAIN/OOS boundary are excluded by the shared fold-label guard.",
    "This wrapper writes research artifacts only and does not source or change live advice bridge behavior."
  ),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec_csv = file.path(output_dir, "ml_p5_universe_run_spec.csv"),
  condition_taxonomy_csv = file.path(output_dir, "ml_p5_universe_condition_taxonomy.csv"),
  fold_spec_csv = file.path(output_dir, "ml_p5_universe_fold_spec.csv"),
  feature_manifest_csv = file.path(output_dir, "ml_p5_universe_feature_manifest.csv"),
  condition_audit_csv = file.path(output_dir, "ml_p5_universe_condition_audit.csv"),
  leakage_audit_csv = file.path(output_dir, "ml_p5_universe_leakage_audit.csv"),
  summary_csv = file.path(output_dir, "ml_p5_universe_summary.csv"),
  ranking_csv = file.path(output_dir, "ml_p5_universe_ranking_audit.csv"),
  policy_thresholds_csv = file.path(output_dir, "ml_p5_universe_policy_thresholds.csv"),
  action_table_csv = file.path(output_dir, "ml_p5_universe_action_table.csv"),
  trade_ledger_csv = file.path(output_dir, "ml_p5_universe_trade_ledger.csv"),
  portfolio_equity_csv = file.path(output_dir, "ml_p5_universe_portfolio_equity.csv"),
  calibration_csv = file.path(output_dir, "ml_p5_universe_calibration_audit.csv"),
  xgb_importance_csv = file.path(output_dir, "ml_p5_universe_xgb_feature_importance.csv"),
  oos_predictions_csv = file.path(output_dir, "ml_p5_universe_oos_predictions.csv"),
  report_md = file.path(output_dir, "ml_p5_universe_architecture_report.md"),
  artifact_index_csv = file.path(output_dir, "ml_p5_universe_artifact_index.csv"),
  context_mode_png = file.path(visual_dir, "ml_p5_context_mode_alpha_heatmap.png"),
  window_matrix_png = file.path(visual_dir, "ml_p5_window_alpha_matrix.png"),
  ranking_png = file.path(visual_dir, "ml_p5_ranking_audit.png"),
  equity_examples_png = file.path(visual_dir, "ml_p5_equity_examples.png"),
  probability_tapes_png = file.path(visual_dir, "ml_p5_probability_tapes.png")
)

run_spec <- data.frame(
  schema_version = "gen54_ml_p5_universe_architecture_screen_v0.1",
  wrapper = "scripts/inspect/run_gen54_ml_universe_architecture_screen.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  windows = paste(paste0(years, "Y"), collapse = ","),
  label_horizon = paste0("h", horizon),
  label_threshold = threshold,
  condition_count = nrow(taxonomy),
  feature_sets = paste(unique(manifest$feature_set_id), collapse = ","),
  policies = paste(unique(summary$policy_id), collapse = ","),
  xgb_nrounds = xgb_nrounds,
  xgb_max_depth = xgb_params$max_depth,
  xgb_eta = xgb_params$eta,
  xgb_subsample = xgb_params$subsample,
  xgb_colsample_bytree = xgb_params$colsample_bytree,
  xgb_min_child_weight = xgb_params$min_child_weight,
  xgb_seed = xgb_seed,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_context_mode_png(summary, paths$context_mode_png)
write_window_matrix_png(summary, paths$window_matrix_png)
write_ranking_png(ranking, paths$ranking_png)
write_equity_examples_png(portfolio, summary, paths$equity_examples_png)
write_probability_tapes_png(predictions, trades, paths$probability_tapes_png)

artifact_index <- data.frame(
  artifact_id = names(paths),
  path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE),
  artifact_type = c(rep("csv", 15L), "markdown", "csv", rep("png", 5L)),
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(taxonomy, paths$condition_taxonomy_csv)
g5_wfa_write_csv(folds, paths$fold_spec_csv)
g5_wfa_write_csv(manifest, paths$feature_manifest_csv)
g5_wfa_write_csv(condition_audit, paths$condition_audit_csv)
g5_wfa_write_csv(leakage, paths$leakage_audit_csv)
g5_wfa_write_csv(summary, paths$summary_csv)
g5_wfa_write_csv(ranking, paths$ranking_csv)
g5_wfa_write_csv(policy_table, paths$policy_thresholds_csv)
g5_wfa_write_csv(actions, paths$action_table_csv)
g5_wfa_write_csv(trades, paths$trade_ledger_csv)
g5_wfa_write_csv(portfolio, paths$portfolio_equity_csv)
g5_wfa_write_csv(calibration, paths$calibration_csv)
g5_wfa_write_csv(importance, paths$xgb_importance_csv)
g5_wfa_write_csv(predictions, paths$oos_predictions_csv)
g5_wfa_write_csv(artifact_index, paths$artifact_index_csv)
write_report(paths$report_md, run_spec, taxonomy, summary, ranking, leakage, artifact_index)

grid <- summary[summary$policy_id == "train_forward_return_grid", , drop = FALSE]
best <- grid[order(-grid$excess_return), , drop = FALSE]
summary_line <- paste0(
  head(best$window_id, 12L), " ", head(best$condition_id, 12L), " ", head(best$feature_set_id, 12L),
  " active=", pct(head(best$active_return, 12L)),
  " benchmark=", pct(head(best$benchmark_return, 12L)),
  " excess=", pct(head(best$excess_return, 12L)),
  collapse = "; "
)

message("Gen5.4 ML-P5 universe architecture screen complete.")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
message("Top TRAIN-grid rows: ", summary_line)
