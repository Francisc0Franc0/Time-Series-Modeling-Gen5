script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))

run_dir <- normalizePath(file.path(repo_root, "runs", "research_workbench", "g53", "feat_full5w_20260709a"), winslash = "/", mustWork = TRUE)
out_dir <- file.path(run_dir, "feature_audit")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_csv <- function(name) {
  path <- file.path(run_dir, paste0("style_diversified_live_capital_", name, ".csv"))
  if (!file.exists(path)) g5_stop(paste0("Missing required Gen5.3 audit input: ", path))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

pct_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f%%"), 100 * x))
}

pp_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f pp"), 100 * x))
}

safe_prod_return <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x[!is.finite(x)] <- 0
  prod(1 + x) - 1
}

safe_cor <- function(x, y) {
  x <- suppressWarnings(as.numeric(x))
  y <- suppressWarnings(as.numeric(y))
  keep <- is.finite(x) & is.finite(y)
  if (sum(keep) < 3L || stats::sd(x[keep]) == 0 || stats::sd(y[keep]) == 0) return(NA_real_)
  suppressWarnings(stats::cor(x[keep], y[keep]))
}

weighted_sd <- function(values, weights) {
  values <- suppressWarnings(as.numeric(values))
  weights <- suppressWarnings(as.numeric(weights))
  keep <- is.finite(values) & is.finite(weights) & weights > 0
  if (sum(keep) < 2L) return(NA_real_)
  values <- values[keep]
  weights <- weights[keep] / sum(weights[keep])
  mu <- sum(weights * values)
  sqrt(sum(weights * (values - mu)^2))
}

mode_value <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) return(NA_character_)
  names(sort(table(x), decreasing = TRUE))[[1L]]
}

feature_label <- function(x) {
  labels <- c(
    current_features_control = "control",
    trend_participation_plus = "trend",
    trend_volatility_plus = "trend+vol",
    trend_volatility_relative_plus = "trend+vol+rel"
  )
  out <- unname(labels[as.character(x)])
  ifelse(is.na(out), as.character(x), out)
}

policy_label <- function(x) {
  labels <- c(
    asset_state_direct_spec = "direct",
    pooled_family_asset_variant = "pooled"
  )
  out <- unname(labels[as.character(x)])
  ifelse(is.na(out), as.character(x), out)
}

basket_label <- function(x) {
  labels <- c(
    high_beta_growth = "high beta",
    defensive_staples = "defensive",
    energy_commodity = "commodity"
  )
  out <- unname(labels[as.character(x)])
  ifelse(is.na(out), as.character(x), out)
}

family_label <- function(x) {
  labels <- c(
    no_trade = "no trade",
    ema_cross = "EMA cross",
    ema_trend = "EMA trend",
    bollinger_touch = "BB touch",
    bollinger_mid_reversion = "BB mid",
    rsi_mr = "RSI MR",
    zret_mr = "z-ret MR",
    breakout = "breakout",
    pullback_in_uptrend = "pullback",
    vol_expansion_breakout = "vol BO",
    donchian_breakout_vol_expand = "Donchian"
  )
  out <- unname(labels[as.character(x)])
  ifelse(is.na(out), as.character(x), out)
}

family_palette <- function(x) {
  colors <- c(
    no_trade = "#B9C0C9",
    ema_cross = "#2E86AB",
    ema_trend = "#00A88F",
    bollinger_touch = "#F4A261",
    bollinger_mid_reversion = "#E76F51",
    rsi_mr = "#9B5DE5",
    zret_mr = "#F15BB5",
    breakout = "#277DA1",
    pullback_in_uptrend = "#43AA8B",
    vol_expansion_breakout = "#F8961E",
    donchian_breakout_vol_expand = "#577590"
  )
  out <- unname(colors[as.character(x)])
  ifelse(is.na(out), "#D8DEE9", out)
}

delta_colors <- function(values, positive = "#00A88F", negative = "#F15A5A", neutral = "#FFFDF8") {
  values <- suppressWarnings(as.numeric(values))
  max_abs <- max(abs(values), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  vapply(values, function(value) {
    if (!is.finite(value) || value == 0) return(neutral)
    grDevices::adjustcolor(if (value > 0) positive else negative, alpha.f = min(0.95, 0.20 + 0.75 * abs(value) / max_abs))
  }, character(1L))
}

add_spec_meta <- function(x, run_spec) {
  spec_cols <- c("screen_id", "window_id", "selection_policy", "basket_archetype", "feature_set_id", "regime_label")
  spec <- unique(run_spec[, intersect(spec_cols, names(run_spec)), drop = FALSE])
  merge(x, spec, by = intersect(c("screen_id", "window_id", "selection_policy"), names(x)), all.x = TRUE, sort = FALSE)
}

add_returns <- function(x, group_cols, include_position = FALSE) {
  if (!nrow(x)) return(x)
  groups <- split(x, interaction(x[, group_cols, drop = FALSE], drop = TRUE, lex.order = TRUE))
  rows <- lapply(groups, function(d) {
    d <- d[order(as.Date(d$session_date)), , drop = FALSE]
    close <- suppressWarnings(as.numeric(d$close))
    ret <- c(0, close[-1L] / close[-length(close)] - 1)
    next_ret <- c(close[-1L] / close[-length(close)] - 1, NA_real_)
    ret[!is.finite(ret)] <- 0
    next_ret[!is.finite(next_ret)] <- NA_real_
    d$daily_return <- ret
    d$next_return <- next_ret
    d$state_switched <- c(FALSE, as.character(d$state_id[-1L]) != as.character(d$state_id[-nrow(d)]))
    if (include_position) {
      pos <- as.character(d$model_position_after_replay) == "LONG"
      d$model_long_after_close <- pos
      d$model_long_lag <- c(FALSE, pos[-length(pos)])
      d$strategy_daily_return <- ifelse(d$model_long_lag, ret, 0)
      d$flat_daily_return <- ifelse(!d$model_long_lag, ret, 0)
    }
    d
  })
  g5_wfa_bind_rows_fill(rows)
}

summary <- read_csv("summary")
run_spec <- read_csv("run_spec")
replay <- add_spec_meta(read_csv("replay_oos"), run_spec)
selected_states <- read_csv("selected_states")
selected_state_meta <- unique(run_spec[, c("screen_id", "window_id", "selection_policy", "basket_archetype", "regime_label"), drop = FALSE])
selected_states <- merge(selected_states, selected_state_meta, by = c("screen_id", "window_id", "selection_policy"), all.x = TRUE, sort = FALSE)
trades <- add_spec_meta(read_csv("trades"), run_spec)
executions <- add_spec_meta(read_csv("executions"), run_spec)

replay <- add_returns(replay, c("screen_id", "window_id", "selection_policy", "symbol"), include_position = TRUE)

state_source <- replay[as.character(replay$selection_policy) == "asset_state_direct_spec", , drop = FALSE]
state_source <- unique(state_source[, c(
  "screen_id", "window_id", "basket_archetype", "feature_set_id", "regime_label",
  "symbol", "session_date", "close", "state_id"
), drop = FALSE])
state_source <- add_returns(state_source, c("screen_id", "window_id", "symbol"), include_position = FALSE)

state_means <- do.call(rbind, lapply(split(state_source, paste(state_source$screen_id, state_source$window_id, state_source$state_id, sep = "::")), function(d) {
  nr <- suppressWarnings(as.numeric(d$next_return))
  data.frame(
    screen_id = as.character(d$screen_id[[1L]]),
    window_id = as.character(d$window_id[[1L]]),
    basket_archetype = as.character(d$basket_archetype[[1L]]),
    feature_set_id = as.character(d$feature_set_id[[1L]]),
    regime_label = as.character(d$regime_label[[1L]]),
    state_id = as.character(d$state_id[[1L]]),
    row_count = sum(is.finite(nr)),
    mean_next_return = mean(nr, na.rm = TRUE),
    hit_rate = mean(nr > 0, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

state_diagnostics <- do.call(rbind, lapply(split(state_source, paste(state_source$screen_id, state_source$window_id, sep = "::")), function(d) {
  sm <- state_means[state_means$screen_id == d$screen_id[[1L]] & state_means$window_id == d$window_id[[1L]], , drop = FALSE]
  counts <- table(as.character(d$state_id))
  probs <- as.numeric(counts) / sum(counts)
  entropy <- -sum(probs * log(probs))
  row_counts <- suppressWarnings(as.numeric(sm$row_count))
  mean_next <- suppressWarnings(as.numeric(sm$mean_next_return))
  hit_rates <- suppressWarnings(as.numeric(sm$hit_rate))
  data.frame(
    screen_id = as.character(d$screen_id[[1L]]),
    window_id = as.character(d$window_id[[1L]]),
    basket_archetype = as.character(d$basket_archetype[[1L]]),
    feature_set_id = as.character(d$feature_set_id[[1L]]),
    regime_label = as.character(d$regime_label[[1L]]),
    observed_state_count = length(counts),
    effective_state_count = exp(entropy),
    mean_symbol_state_switch_rate = mean(tapply(as.logical(d$state_switched), as.character(d$symbol), mean, na.rm = TRUE), na.rm = TRUE),
    state_next_return_dispersion = weighted_sd(mean_next, row_counts),
    state_next_return_spread = max(mean_next, na.rm = TRUE) - min(mean_next, na.rm = TRUE),
    state_hit_rate_spread = max(hit_rates, na.rm = TRUE) - min(hit_rates, na.rm = TRUE),
    best_forward_state = as.character(sm$state_id[which.max(mean_next)][[1L]]),
    worst_forward_state = as.character(sm$state_id[which.min(mean_next)][[1L]]),
    stringsAsFactors = FALSE
  )
}))

state_diagnostics_agg <- do.call(rbind, lapply(split(state_diagnostics, paste(state_diagnostics$basket_archetype, state_diagnostics$feature_set_id, sep = "::")), function(d) {
  data.frame(
    basket_archetype = as.character(d$basket_archetype[[1L]]),
    feature_set_id = as.character(d$feature_set_id[[1L]]),
    mean_effective_state_count = mean(d$effective_state_count, na.rm = TRUE),
    mean_state_switch_rate = mean(d$mean_symbol_state_switch_rate, na.rm = TRUE),
    mean_state_next_return_dispersion = mean(d$state_next_return_dispersion, na.rm = TRUE),
    mean_state_next_return_spread = mean(d$state_next_return_spread, na.rm = TRUE),
    mean_state_hit_rate_spread = mean(d$state_hit_rate_spread, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
state_diagnostics_agg <- state_diagnostics_agg[order(state_diagnostics_agg$basket_archetype, -state_diagnostics_agg$mean_state_next_return_dispersion), , drop = FALSE]

action_state <- do.call(rbind, lapply(split(replay, paste(replay$screen_id, replay$window_id, replay$selection_policy, replay$state_id, sep = "::")), function(d) {
  nr <- suppressWarnings(as.numeric(d$next_return))
  long <- as.logical(d$model_long_after_close)
  data.frame(
    screen_id = as.character(d$screen_id[[1L]]),
    window_id = as.character(d$window_id[[1L]]),
    basket_archetype = as.character(d$basket_archetype[[1L]]),
    feature_set_id = as.character(d$feature_set_id[[1L]]),
    regime_label = as.character(d$regime_label[[1L]]),
    selection_policy = as.character(d$selection_policy[[1L]]),
    state_id = as.character(d$state_id[[1L]]),
    row_count = sum(is.finite(nr)),
    mean_next_return = mean(nr, na.rm = TRUE),
    long_rate = mean(long, na.rm = TRUE),
    no_trade_rate = mean(as.character(d$selected_strategy_family) == "no_trade", na.rm = TRUE),
    dominant_family = mode_value(d$selected_strategy_family),
    stringsAsFactors = FALSE
  )
}))

action_alignment <- do.call(rbind, lapply(split(action_state, paste(action_state$screen_id, action_state$window_id, action_state$selection_policy, sep = "::")), function(d) {
  good <- suppressWarnings(as.numeric(d$mean_next_return)) > 0
  weights <- suppressWarnings(as.numeric(d$row_count))
  data.frame(
    screen_id = as.character(d$screen_id[[1L]]),
    window_id = as.character(d$window_id[[1L]]),
    basket_archetype = as.character(d$basket_archetype[[1L]]),
    feature_set_id = as.character(d$feature_set_id[[1L]]),
    regime_label = as.character(d$regime_label[[1L]]),
    selection_policy = as.character(d$selection_policy[[1L]]),
    state_long_return_alignment = safe_cor(d$mean_next_return, d$long_rate),
    good_state_no_trade_rate = if (any(good, na.rm = TRUE)) stats::weighted.mean(d$no_trade_rate[good], weights[good], na.rm = TRUE) else NA_real_,
    bad_state_long_rate = if (any(!good, na.rm = TRUE)) stats::weighted.mean(d$long_rate[!good], weights[!good], na.rm = TRUE) else NA_real_,
    mean_state_long_rate = stats::weighted.mean(d$long_rate, weights, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

alpha_key <- summary[, c("screen_id", "window_id", "selection_policy", "alpha_vs_active_equal", "total_return", "active_equal_buy_hold_return"), drop = FALSE]
action_alignment <- merge(action_alignment, alpha_key, by = c("screen_id", "window_id", "selection_policy"), all.x = TRUE, sort = FALSE)

action_alignment_agg <- do.call(rbind, lapply(split(action_alignment, paste(action_alignment$basket_archetype, action_alignment$feature_set_id, action_alignment$selection_policy, sep = "::")), function(d) {
  data.frame(
    basket_archetype = as.character(d$basket_archetype[[1L]]),
    feature_set_id = as.character(d$feature_set_id[[1L]]),
    selection_policy = as.character(d$selection_policy[[1L]]),
    mean_alpha = mean(d$alpha_vs_active_equal, na.rm = TRUE),
    positive_alpha_window_rate = mean(d$alpha_vs_active_equal > 0, na.rm = TRUE),
    mean_state_long_return_alignment = mean(d$state_long_return_alignment, na.rm = TRUE),
    mean_good_state_no_trade_rate = mean(d$good_state_no_trade_rate, na.rm = TRUE),
    mean_bad_state_long_rate = mean(d$bad_state_long_rate, na.rm = TRUE),
    mean_state_long_rate = mean(d$mean_state_long_rate, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
action_alignment_agg <- action_alignment_agg[order(action_alignment_agg$basket_archetype, -action_alignment_agg$mean_state_long_return_alignment), , drop = FALSE]

trades$trade_return <- suppressWarnings(as.numeric(trades$trace_end_price) / as.numeric(trades$entry_execution_price) - 1)
trades$trade_duration_days <- as.numeric(as.Date(trades$trace_end_date) - as.Date(trades$entry_execution_date))

symbol_behavior <- do.call(rbind, lapply(split(replay, paste(replay$screen_id, replay$window_id, replay$selection_policy, replay$symbol, sep = "::")), function(d) {
  d <- d[order(as.Date(d$session_date)), , drop = FALSE]
  data.frame(
    screen_id = as.character(d$screen_id[[1L]]),
    window_id = as.character(d$window_id[[1L]]),
    basket_archetype = as.character(d$basket_archetype[[1L]]),
    feature_set_id = as.character(d$feature_set_id[[1L]]),
    selection_policy = as.character(d$selection_policy[[1L]]),
    symbol = as.character(d$symbol[[1L]]),
    benchmark_return = safe_prod_return(d$daily_return),
    strategy_return = safe_prod_return(d$strategy_daily_return),
    alpha_vs_symbol_hold = safe_prod_return(d$strategy_daily_return) - safe_prod_return(d$daily_return),
    mean_long_fraction = mean(as.logical(d$model_long_lag), na.rm = TRUE),
    missed_flat_return = safe_prod_return(d$flat_daily_return),
    stringsAsFactors = FALSE
  )
}))

selected_cases <- data.frame(
  case_id = c("missed_upside", "downside_avoidance", "defensive_lag", "commodity_lag", "commodity_pocket", "high_beta_pocket"),
  case_label = c(
    "Missed upside: TSLA 2020Q3 trend+vol direct",
    "Downside avoidance: MSTR 2022Q4 control direct",
    "Defensive lag: WMT 2021Q4 trend+vol direct",
    "Commodity lag: XLE 2022Q1 control pooled",
    "Commodity pocket: SLV 2020Q3 trend+vol+rel pooled",
    "High-beta pocket: AMD 2022Q1 trend+vol+rel direct"
  ),
  screen_id = c(
    "HB_uniform_broad_context__trendvol",
    "HB_uniform_broad_context__ctrl",
    "DEF_uniform_broad_context__trendvol",
    "COM_uniform_broad_context__ctrl",
    "COM_uniform_broad_context__trendrel",
    "HB_uniform_broad_context__trendrel"
  ),
  window_id = c(
    "2020Q3_asof_20200930",
    "2022Q4_asof_20221230",
    "2021Q4_asof_20211231",
    "2022Q1_asof_20220331",
    "2020Q3_asof_20200930",
    "2022Q1_asof_20220331"
  ),
  selection_policy = c(
    "asset_state_direct_spec",
    "asset_state_direct_spec",
    "asset_state_direct_spec",
    "pooled_family_asset_variant",
    "pooled_family_asset_variant",
    "asset_state_direct_spec"
  ),
  symbol = c("TSLA", "MSTR", "WMT", "XLE", "SLV", "AMD"),
  stringsAsFactors = FALSE
)
selected_cases <- merge(selected_cases, symbol_behavior, by = c("screen_id", "window_id", "selection_policy", "symbol"), all.x = TRUE, sort = FALSE)
selected_cases <- selected_cases[, c(
  "case_id", "case_label", "screen_id", "basket_archetype", "feature_set_id", "selection_policy", "window_id", "symbol",
  "benchmark_return", "strategy_return", "alpha_vs_symbol_hold", "mean_long_fraction", "missed_flat_return"
), drop = FALSE]

state_family_mix <- do.call(rbind, lapply(split(selected_states, paste(selected_states$basket_archetype, selected_states$feature_set_id, selected_states$selection_policy, selected_states$strategy_family, sep = "::")), function(d) {
  data.frame(
    basket_archetype = as.character(d$basket_archetype[[1L]]),
    feature_set_id = as.character(d$feature_set_id[[1L]]),
    selection_policy = as.character(d$selection_policy[[1L]]),
    strategy_family = as.character(d$strategy_family[[1L]]),
    selected_rows = nrow(d),
    stringsAsFactors = FALSE
  )
}))
totals <- aggregate(selected_rows ~ basket_archetype + feature_set_id + selection_policy, state_family_mix, sum)
state_family_mix <- merge(state_family_mix, totals, by = c("basket_archetype", "feature_set_id", "selection_policy"), suffixes = c("", "_total"), sort = FALSE)
state_family_mix$selected_share <- state_family_mix$selected_rows / state_family_mix$selected_rows_total

paths <- list(
  state_diagnostics_csv = file.path(out_dir, "gen53_feature_state_diagnostics.csv"),
  state_diagnostics_agg_csv = file.path(out_dir, "gen53_feature_state_diagnostics_aggregate.csv"),
  action_alignment_csv = file.path(out_dir, "gen53_feature_action_alignment.csv"),
  action_alignment_agg_csv = file.path(out_dir, "gen53_feature_action_alignment_aggregate.csv"),
  symbol_behavior_csv = file.path(out_dir, "gen53_symbol_behavior_summary.csv"),
  selected_cases_csv = file.path(out_dir, "gen53_representative_trade_tape_cases.csv"),
  family_mix_csv = file.path(out_dir, "gen53_selected_family_mix.csv"),
  state_discrimination_png = file.path(out_dir, "gen53_state_discrimination_diagnostics.png"),
  action_alignment_png = file.path(out_dir, "gen53_action_alignment_diagnostics.png"),
  family_mix_png = file.path(out_dir, "gen53_selected_family_mix_heatmap.png"),
  trade_tapes_png = file.path(out_dir, "gen53_representative_trade_tapes.png"),
  report_md = file.path(out_dir, "gen53_feature_audit_report.md")
)

g5_wfa_write_csv(state_diagnostics, paths$state_diagnostics_csv)
g5_wfa_write_csv(state_diagnostics_agg, paths$state_diagnostics_agg_csv)
g5_wfa_write_csv(action_alignment, paths$action_alignment_csv)
g5_wfa_write_csv(action_alignment_agg, paths$action_alignment_agg_csv)
g5_wfa_write_csv(symbol_behavior, paths$symbol_behavior_csv)
g5_wfa_write_csv(selected_cases, paths$selected_cases_csv)
g5_wfa_write_csv(state_family_mix, paths$family_mix_csv)

write_state_discrimination_chart <- function(path) {
  aesthetic <- g5_chart_aesthetic()
  d <- state_diagnostics_agg
  d$row_label <- paste(basket_label(d$basket_archetype), feature_label(d$feature_set_id), sep = " / ")
  d <- d[order(d$basket_archetype, -d$mean_state_next_return_dispersion), , drop = FALSE]
  grDevices::png(path, width = 2800L, height = 1800L, res = 200L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(1, 3), mar = c(9, 5, 4, 1), oma = c(0, 0, 2.5, 0))
  metrics <- list(
    "Forward-return state dispersion" = 100 * d$mean_state_next_return_dispersion,
    "Effective states used" = d$mean_effective_state_count,
    "State switch rate" = 100 * d$mean_state_switch_rate
  )
  fills <- c("#2E86AB", "#00A88F", "#F8961E")
  for (i in seq_along(metrics)) {
    values <- metrics[[i]]
    bp <- graphics::barplot(
      values,
      names.arg = d$row_label,
      las = 2,
      col = grDevices::adjustcolor(fills[[i]], alpha.f = 0.82),
      border = NA,
      ylab = if (i == 2L) "count" else "%",
      main = names(metrics)[[i]],
      col.axis = aesthetic$axis,
      col.lab = aesthetic$text,
      col.main = aesthetic$text,
      cex.names = 0.62
    )
    graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
    graphics::text(bp, values, labels = if (i == 2L) sprintf("%.1f", values) else sprintf("%.2f", values), pos = 3, cex = 0.62, col = aesthetic$text, xpd = NA)
  }
  graphics::mtext("Regime-quality diagnostics. Higher dispersion can mean states separate future behavior; high switch rate can mean noisier states.", side = 3, outer = TRUE, line = 0.7, font = 2, col = aesthetic$text)
  invisible(path)
}

write_action_alignment_chart <- function(path) {
  aesthetic <- g5_chart_aesthetic()
  d <- action_alignment_agg
  d$label <- paste(basket_label(d$basket_archetype), feature_label(d$feature_set_id), policy_label(d$selection_policy), sep = " / ")
  colors <- c(high_beta_growth = "#2E86AB", defensive_staples = "#00A88F", energy_commodity = "#F8961E")
  shapes <- c(asset_state_direct_spec = 16L, pooled_family_asset_variant = 17L)
  grDevices::png(path, width = 2200L, height = 1600L, res = 200L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(5, 5, 4, 2))
  x <- suppressWarnings(as.numeric(d$mean_state_long_return_alignment))
  y <- suppressWarnings(as.numeric(d$mean_alpha))
  graphics::plot(
    x, 100 * y,
    type = "n",
    xlab = "Correlation: state forward return vs long rate",
    ylab = "Mean alpha vs basket hold (pp)",
    main = "Action Alignment vs Final Alpha",
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text,
    fg = aesthetic$axis
  )
  graphics::rect(par("usr")[[1L]], par("usr")[[3L]], par("usr")[[2L]], par("usr")[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(nx = NULL, ny = NULL, col = aesthetic$grid)
  graphics::abline(h = 0, v = 0, lty = 2, col = aesthetic$axis)
  graphics::points(x, 100 * y, pch = shapes[as.character(d$selection_policy)], col = colors[as.character(d$basket_archetype)], bg = colors[as.character(d$basket_archetype)], cex = 1.35)
  top <- d[order(-d$mean_state_long_return_alignment), , drop = FALSE]
  if (nrow(top)) {
    label_rows <- unique(c(seq_len(min(4L, nrow(top))), tail(seq_len(nrow(top)), min(3L, nrow(top)))))
    graphics::text(
      x[match(top$label[label_rows], d$label)],
      100 * y[match(top$label[label_rows], d$label)],
      labels = top$label[label_rows],
      pos = 3,
      cex = 0.62,
      col = aesthetic$text
    )
  }
  graphics::legend("bottomright", legend = names(colors), col = colors, pch = 16L, bty = "n", cex = 0.8, text.col = aesthetic$text)
  graphics::legend("bottomleft", legend = names(shapes), pch = shapes, col = "#111827", bty = "n", cex = 0.8, text.col = aesthetic$text)
  invisible(path)
}

write_family_mix_heatmap <- function(path) {
  aesthetic <- g5_chart_aesthetic()
  d <- state_family_mix
  d$row_label <- paste(basket_label(d$basket_archetype), feature_label(d$feature_set_id), policy_label(d$selection_policy), sep = " / ")
  row_labels <- unique(d$row_label)
  families <- sort(unique(as.character(d$strategy_family)))
  values <- matrix(0, nrow = length(row_labels), ncol = length(families), dimnames = list(row_labels, families))
  for (i in seq_len(nrow(d))) {
    values[d$row_label[[i]], as.character(d$strategy_family[[i]])] <- as.numeric(d$selected_share[[i]])
  }
  grDevices::png(path, width = 2800L, height = 1900L, res = 200L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(8, 16, 4, 2))
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Selected Family Mix by Feature Set and Policy", col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  for (r in seq_len(nrow(values))) {
    for (c in seq_len(ncol(values))) {
      fill <- grDevices::adjustcolor(family_palette(families[[c]]), alpha.f = 0.20 + 0.80 * values[r, c])
      graphics::rect(c - 0.5, nrow(values) - r + 0.5, c + 0.5, nrow(values) - r + 1.5, col = fill, border = aesthetic$grid)
      if (values[r, c] >= 0.08) graphics::text(c, nrow(values) - r + 1, labels = pct_label(values[r, c], 0L), cex = 0.58, col = aesthetic$text)
    }
  }
  graphics::axis(1, at = seq_along(families), labels = family_label(families), las = 2, cex.axis = 0.7, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(row_labels)), labels = row_labels, las = 1, cex.axis = 0.62, col.axis = aesthetic$axis)
  graphics::mtext("Darker cells mean that family occupied more selected asset/state authority rows.", side = 1, line = 6.4, cex = 0.72, col = aesthetic$text)
  invisible(path)
}

write_trade_tapes <- function(path) {
  aesthetic <- g5_chart_aesthetic()
  grDevices::png(path, width = 3600L, height = 1900L, res = 190L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(2, 3), mar = c(4, 4, 3.2, 1), oma = c(0, 0, 2.2, 0))
  for (i in seq_len(nrow(selected_cases))) {
    case <- selected_cases[i, , drop = FALSE]
    r <- replay[
      replay$screen_id == case$screen_id[[1L]] &
        replay$window_id == case$window_id[[1L]] &
        replay$selection_policy == case$selection_policy[[1L]] &
        replay$symbol == case$symbol[[1L]],
      ,
      drop = FALSE
    ]
    e <- executions[
      executions$screen_id == case$screen_id[[1L]] &
        executions$window_id == case$window_id[[1L]] &
        executions$selection_policy == case$selection_policy[[1L]] &
        executions$symbol == case$symbol[[1L]],
      ,
      drop = FALSE
    ]
    t <- trades[
      trades$screen_id == case$screen_id[[1L]] &
        trades$window_id == case$window_id[[1L]] &
        trades$selection_policy == case$selection_policy[[1L]] &
        trades$symbol == case$symbol[[1L]],
      ,
      drop = FALSE
    ]
    title <- paste0(
      case$case_id[[1L]], " | ", case$symbol[[1L]], " | ",
      feature_label(case$feature_set_id[[1L]]), " / ", policy_label(case$selection_policy[[1L]]),
      " | alpha ", pp_label(case$alpha_vs_symbol_hold[[1L]], 0L)
    )
    g5_bridge_plot_panel(r, e, data.frame(), t, main = title)
  }
  graphics::mtext("Representative Gen5.3 trade tapes. State bands, signal/execution markers, and trade traces use the live-bridge plotting surface.", side = 3, outer = TRUE, line = 0.5, font = 2, col = aesthetic$text)
  invisible(path)
}

write_state_discrimination_chart(paths$state_discrimination_png)
write_action_alignment_chart(paths$action_alignment_png)
write_family_mix_heatmap(paths$family_mix_png)
write_trade_tapes(paths$trade_tapes_png)

top_state <- state_diagnostics_agg[order(-state_diagnostics_agg$mean_state_next_return_dispersion), , drop = FALSE][1L, , drop = FALSE]
top_align <- action_alignment_agg[order(-action_alignment_agg$mean_state_long_return_alignment), , drop = FALSE][1L, , drop = FALSE]
worst_good_no_trade <- action_alignment_agg[order(-action_alignment_agg$mean_good_state_no_trade_rate), , drop = FALSE][1L, , drop = FALSE]

report <- c(
  "# Gen5.3 Feature/State Audit",
  "",
  "## Purpose",
  "",
  "This artifact-only audit inspects the completed five-window Gen5.3 feature screen without refitting authority or refreshing data. It separates final trading alpha from three upstream questions: whether PCA states separate forward behavior, whether the selected action map aligns exposure with better states, and what representative trade tapes actually looked like.",
  "",
  "## Representative Trade Tapes",
  "",
  paste0("- Contact sheet: `", paths$trade_tapes_png, "`."),
  "- Included cases cover missed high-beta upside, downside avoidance, defensive lag, commodity lag, and two pockets where state/action behavior looked more promising.",
  "",
  "## Feature/State Diagnostics",
  "",
  paste0("- Highest mean state forward-return dispersion: `", basket_label(top_state$basket_archetype), " / ", feature_label(top_state$feature_set_id), "` at ", pp_label(top_state$mean_state_next_return_dispersion, 2L), "."),
  paste0("- Highest mean action-alignment correlation: `", basket_label(top_align$basket_archetype), " / ", feature_label(top_align$feature_set_id), " / ", policy_label(top_align$selection_policy), "` at ", sprintf("%.2f", top_align$mean_state_long_return_alignment), "."),
  paste0("- Highest no-trade rate inside positive-forward states: `", basket_label(worst_good_no_trade$basket_archetype), " / ", feature_label(worst_good_no_trade$feature_set_id), " / ", policy_label(worst_good_no_trade$selection_policy), "` at ", pct_label(worst_good_no_trade$mean_good_state_no_trade_rate, 1L), "."),
  "",
  "Interpretation: these diagnostics can show that a feature set contains regime information even if the first action policy underuses it. Conversely, a feature set can create visually distinct states while still failing if the action map goes long in the wrong states or stays flat in favorable states.",
  "",
  "## Artifact Index",
  "",
  paste0("- State diagnostics: `", paths$state_diagnostics_csv, "`."),
  paste0("- Aggregate state diagnostics: `", paths$state_diagnostics_agg_csv, "`."),
  paste0("- Action alignment: `", paths$action_alignment_csv, "`."),
  paste0("- Aggregate action alignment: `", paths$action_alignment_agg_csv, "`."),
  paste0("- Representative cases: `", paths$selected_cases_csv, "`."),
  paste0("- Family mix: `", paths$family_mix_csv, "`."),
  paste0("- State chart: `", paths$state_discrimination_png, "`."),
  paste0("- Action alignment chart: `", paths$action_alignment_png, "`."),
  paste0("- Family mix chart: `", paths$family_mix_png, "`.")
)
writeLines(report, paths$report_md)

message("Gen5.3 feature audit complete: ", normalizePath(out_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
