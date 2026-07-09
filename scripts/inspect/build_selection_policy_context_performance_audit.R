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

screen_id <- "HB_broad_risk_no_vxx"
audit_window_id <- "2020Q3_asof_20200930"
run_root <- normalizePath(file.path(repo_root, "runs", "research_workbench", "selpol_context", "selpol_context_20260703"), winslash = "/", mustWork = TRUE)
screen_dir <- file.path(run_root, screen_id)
output_dir <- file.path(run_root, "performance_audit", screen_id)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

pct_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f%%"), 100 * x))
}

pp_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f pp"), 100 * x))
}

policy_label <- function(x) {
  labels <- c(asset_state_direct_spec = "Direct", pooled_family_asset_variant = "Pooled")
  out <- unname(labels[as.character(x)])
  ifelse(is.na(out), as.character(x), out)
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

safe_prod_return <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x[!is.finite(x)] <- 0
  prod(1 + x) - 1
}

mode_value <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) return(NA_character_)
  tab <- sort(table(x), decreasing = TRUE)
  names(tab)[[1L]]
}

read_csv_if_exists <- function(path) {
  if (!file.exists(path)) return(data.frame())
  info <- file.info(path)
  if (!is.finite(info$size[[1L]]) || info$size[[1L]] == 0) return(data.frame())
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) data.frame())
}

packet_index <- utils::read.csv(file.path(run_root, "selection_policy_context_philosophy_packet_index.csv"), stringsAsFactors = FALSE)
packet_index <- packet_index[packet_index$screen_id == screen_id, , drop = FALSE]
if (!nrow(packet_index)) g5_stop(paste0("No packet rows found for screen_id=", screen_id))

add_daily_returns <- function(replay) {
  pieces <- split(replay, paste(replay$selection_policy, replay$window_id, replay$symbol, sep = "::"))
  rows <- lapply(pieces, function(x) {
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    close <- as.numeric(x$close)
    ret <- c(0, close[-1L] / close[-length(close)] - 1)
    ret[!is.finite(ret)] <- 0
    pos <- as.character(x$model_position_after_replay) == "LONG"
    pos_lag <- c(FALSE, pos[-length(pos)])
    x$daily_return <- ret
    x$model_long_lag <- pos_lag
    x$strategy_daily_return <- ifelse(pos_lag, ret, 0)
    x$flat_daily_return <- ifelse(!pos_lag, ret, 0)
    x
  })
  g5_wfa_bind_rows_fill(rows)
}

replay_rows <- list()
trade_rows <- list()
execution_rows <- list()
for (i in seq_len(nrow(packet_index))) {
  row <- packet_index[i, , drop = FALSE]
  replay <- read_csv_if_exists(row$replay_csv[[1L]])
  trades <- read_csv_if_exists(row$trades_csv[[1L]])
  executions <- read_csv_if_exists(file.path(row$packet_dir[[1L]], "bridge_executions.csv"))
  if (nrow(replay)) replay_rows[[length(replay_rows) + 1L]] <- replay
  if (nrow(trades)) trade_rows[[length(trade_rows) + 1L]] <- trades
  if (nrow(executions)) {
    executions$selection_policy <- row$selection_policy[[1L]]
    executions$window_id <- row$window_id[[1L]]
    executions$screen_id <- row$screen_id[[1L]]
    execution_rows[[length(execution_rows) + 1L]] <- executions
  }
}

replay_all <- add_daily_returns(g5_wfa_bind_rows_fill(replay_rows))
trades_all <- if (length(trade_rows)) g5_wfa_bind_rows_fill(trade_rows) else data.frame()
executions_all <- if (length(execution_rows)) g5_wfa_bind_rows_fill(execution_rows) else data.frame()
selected_states_all <- read_csv_if_exists(file.path(screen_dir, "selection_policy_selected_states_all.csv"))

exposure_summary <- do.call(rbind, lapply(split(replay_all, paste(replay_all$selection_policy, replay_all$window_id, replay_all$symbol, sep = "::")), function(x) {
  pos <- as.logical(x$model_long_lag)
  up_denom <- sum(pmax(as.numeric(x$daily_return), 0), na.rm = TRUE)
  down_denom <- sum(pmin(as.numeric(x$daily_return), 0), na.rm = TRUE)
  data.frame(
    selection_policy = as.character(x$selection_policy[[1L]]),
    policy_label = policy_label(x$selection_policy[[1L]]),
    window_id = as.character(x$window_id[[1L]]),
    symbol = as.character(x$symbol[[1L]]),
    session_count = nrow(x),
    long_days = sum(pos, na.rm = TRUE),
    exposure_ratio = mean(pos, na.rm = TRUE),
    strategy_return = safe_prod_return(x$strategy_daily_return),
    benchmark_return = safe_prod_return(x$daily_return),
    excess_return = safe_prod_return(x$strategy_daily_return) - safe_prod_return(x$daily_return),
    missed_flat_return = safe_prod_return(x$flat_daily_return),
    upside_participation = if (is.finite(up_denom) && up_denom > 0) sum(pmax(as.numeric(x$strategy_daily_return), 0), na.rm = TRUE) / up_denom else NA_real_,
    downside_participation = if (is.finite(down_denom) && down_denom < 0) sum(pmin(as.numeric(x$strategy_daily_return), 0), na.rm = TRUE) / down_denom else NA_real_,
    stringsAsFactors = FALSE
  )
}))

if (nrow(trades_all)) {
  trades_all$trade_return <- as.numeric(trades_all$trace_end_price) / as.numeric(trades_all$entry_execution_price) - 1
  trades_all$trade_duration_days <- as.numeric(as.Date(trades_all$trace_end_date) - as.Date(trades_all$entry_execution_date))
  trades_all$policy_label <- policy_label(trades_all$selection_policy)
}

trade_shape_summary <- if (nrow(trades_all)) {
  do.call(rbind, lapply(split(trades_all, paste(trades_all$selection_policy, trades_all$window_id, sep = "::")), function(x) {
    data.frame(
      selection_policy = as.character(x$selection_policy[[1L]]),
      policy_label = policy_label(x$selection_policy[[1L]]),
      window_id = as.character(x$window_id[[1L]]),
      trade_count = nrow(x),
      win_count = sum(as.character(x$trade_outcome) == "win", na.rm = TRUE),
      loss_count = sum(as.character(x$trade_outcome) == "loss", na.rm = TRUE),
      open_trade_count = sum(as.character(x$trade_status) == "open", na.rm = TRUE),
      median_trade_return = stats::median(as.numeric(x$trade_return), na.rm = TRUE),
      worst_trade_return = min(as.numeric(x$trade_return), na.rm = TRUE),
      best_trade_return = max(as.numeric(x$trade_return), na.rm = TRUE),
      median_duration_days = stats::median(as.numeric(x$trade_duration_days), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
} else {
  data.frame()
}

state_accountability <- do.call(rbind, lapply(split(replay_all, paste(replay_all$selection_policy, replay_all$state_id, sep = "::")), function(x) {
  daily_excess <- as.numeric(x$strategy_daily_return) - as.numeric(x$daily_return)
  data.frame(
    selection_policy = as.character(x$selection_policy[[1L]]),
    policy_label = policy_label(x$selection_policy[[1L]]),
    state_id = as.character(x$state_id[[1L]]),
    row_count = nrow(x),
    exposure_ratio = mean(as.logical(x$model_long_lag), na.rm = TRUE),
    strategy_return = safe_prod_return(x$strategy_daily_return),
    benchmark_return = safe_prod_return(x$daily_return),
    excess_return = safe_prod_return(x$strategy_daily_return) - safe_prod_return(x$daily_return),
    mean_daily_excess_return = mean(daily_excess, na.rm = TRUE),
    dominant_selected_family = mode_value(x$selected_strategy_family),
    stringsAsFactors = FALSE
  )
}))

family_abbrev <- function(x) {
  labels <- c(
    no_trade = "NT",
    ema_cross = "EMA-x",
    ema_trend = "EMA-t",
    bollinger_touch = "BB-t",
    bollinger_mid_reversion = "BB-m",
    rsi_mr = "RSI",
    zret_mr = "ZRet",
    breakout = "BO",
    pullback_in_uptrend = "PB",
    vol_expansion_breakout = "VolBO",
    donchian_breakout_vol_expand = "Donch"
  )
  out <- unname(labels[as.character(x)])
  ifelse(is.na(out), as.character(x), out)
}

family_palette <- function(family) {
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
  out <- unname(colors[as.character(family)])
  ifelse(is.na(out), "#D8DEE9", out)
}

param_value <- function(row, name) {
  if (!name %in% names(row)) return(NA_real_)
  value <- suppressWarnings(as.numeric(row[[name]][[1L]]))
  if (!is.finite(value)) NA_real_ else value
}

param_label <- function(row) {
  family <- as.character(row$strategy_family[[1L]])
  fmt_int <- function(x) if (is.na(x)) "NA" else sprintf("%.0f", x)
  fmt_num <- function(x) if (is.na(x)) "NA" else sub("\\.?0+$", "", sprintf("%.3f", x))
  label <- switch(
    family,
    no_trade = "no trade",
    ema_cross = paste0("f", fmt_int(param_value(row, "fast_period")), "/s", fmt_int(param_value(row, "slow_period"))),
    ema_trend = paste0("f", fmt_int(param_value(row, "fast_period")), "/s", fmt_int(param_value(row, "slow_period"))),
    pullback_in_uptrend = paste0("f", fmt_int(param_value(row, "fast_period")), "/s", fmt_int(param_value(row, "slow_period"))),
    bollinger_touch = paste0("lb", fmt_int(param_value(row, "lookback_period")), "/sd", fmt_num(param_value(row, "sd_multiplier"))),
    bollinger_mid_reversion = paste0("lb", fmt_int(param_value(row, "lookback_period")), "/sd", fmt_num(param_value(row, "sd_multiplier"))),
    rsi_mr = paste0("p", fmt_int(param_value(row, "rsi_period")), "/", fmt_int(param_value(row, "rsi_lower")), "-", fmt_int(param_value(row, "rsi_upper"))),
    zret_mr = paste0("w", fmt_int(param_value(row, "zret_window")), "/e", fmt_num(param_value(row, "zret_entry_z")), "/x", fmt_num(param_value(row, "zret_exit_z"))),
    breakout = paste0("lb", fmt_int(param_value(row, "breakout_lookback")), "/b", fmt_num(param_value(row, "breakout_buffer"))),
    vol_expansion_breakout = paste0("lb", fmt_int(param_value(row, "breakout_lookback")), "/b", fmt_num(param_value(row, "breakout_buffer")), "/v", fmt_num(param_value(row, "vol_expand_threshold"))),
    donchian_breakout_vol_expand = paste0("lb", fmt_int(param_value(row, "breakout_lookback")), "/b", fmt_num(param_value(row, "breakout_buffer")), "/v", fmt_num(param_value(row, "vol_expand_threshold"))),
    as.character(row$model_instance_id[[1L]])
  )
  exit_stack <- if ("exit_stack_id" %in% names(row)) as.character(row$exit_stack_id[[1L]]) else ""
  if (nzchar(exit_stack) && !identical(exit_stack, "no_exit")) {
    label <- paste0(label, "\n", exit_stack)
  }
  label
}

dominant_row <- function(x, field) {
  values <- as.character(x[[field]])
  values <- values[!is.na(values) & nzchar(values)]
  if (!length(values)) return(x[1L, , drop = FALSE])
  tab <- sort(table(values), decreasing = TRUE)
  keep <- names(tab)[[1L]]
  x[as.character(x[[field]]) == keep, , drop = FALSE][1L, , drop = FALSE]
}

selected_state_asset <- data.frame()
selected_family_state_mix <- data.frame()
selected_parameter_profile <- data.frame()
if (nrow(selected_states_all)) {
  selected_states_all$strategy_family <- as.character(selected_states_all$strategy_family)
  selected_states_all$selection_policy <- as.character(selected_states_all$selection_policy)
  selected_states_all$symbol <- as.character(selected_states_all$symbol)
  selected_states_all$state_id <- as.character(selected_states_all$state_id)
  selected_states_all$quarter_id <- as.character(selected_states_all$quarter_id)
  selected_state_asset <- do.call(rbind, lapply(split(selected_states_all, paste(selected_states_all$selection_policy, selected_states_all$symbol, selected_states_all$state_id, sep = "::")), function(x) {
    fam <- sort(table(x$strategy_family), decreasing = TRUE)
    dominant_family <- names(fam)[[1L]]
    row <- dominant_row(x[x$strategy_family == dominant_family, , drop = FALSE], "strategy_spec_id")
    data.frame(
      selection_policy = as.character(x$selection_policy[[1L]]),
      policy_label = policy_label(x$selection_policy[[1L]]),
      symbol = as.character(x$symbol[[1L]]),
      state_id = as.character(x$state_id[[1L]]),
      selected_rows = nrow(x),
      dominant_family = dominant_family,
      dominant_family_label = family_abbrev(dominant_family),
      dominant_family_count = as.integer(fam[[1L]]),
      dominant_family_share = as.integer(fam[[1L]]) / nrow(x),
      unique_family_count = length(fam),
      dominant_strategy_spec_id = as.character(row$strategy_spec_id[[1L]]),
      dominant_parameter_label = param_label(row),
      stringsAsFactors = FALSE
    )
  }))
  selected_family_state_mix <- as.data.frame(table(
    selection_policy = selected_states_all$selection_policy,
    state_id = selected_states_all$state_id,
    strategy_family = selected_states_all$strategy_family
  ), stringsAsFactors = FALSE)
  names(selected_family_state_mix)[names(selected_family_state_mix) == "Freq"] <- "selected_count"
  selected_family_state_mix$policy_label <- policy_label(selected_family_state_mix$selection_policy)
  selected_parameter_profile <- do.call(rbind, lapply(split(selected_states_all, paste(selected_states_all$selection_policy, selected_states_all$symbol, selected_states_all$strategy_family, sep = "::")), function(x) {
    row <- dominant_row(x, "strategy_spec_id")
    specs <- unique(as.character(x$strategy_spec_id))
    data.frame(
      selection_policy = as.character(x$selection_policy[[1L]]),
      policy_label = policy_label(x$selection_policy[[1L]]),
      symbol = as.character(x$symbol[[1L]]),
      strategy_family = as.character(x$strategy_family[[1L]]),
      strategy_family_label = family_abbrev(x$strategy_family[[1L]]),
      selected_count = nrow(x),
      unique_spec_count = length(specs[!is.na(specs) & nzchar(specs)]),
      dominant_strategy_spec_id = as.character(row$strategy_spec_id[[1L]]),
      dominant_parameter_label = param_label(row),
      stringsAsFactors = FALSE
    )
  }))
}

paths <- list(
  exposure_summary_csv = file.path(output_dir, "performance_audit_exposure_participation.csv"),
  trade_shape_csv = file.path(output_dir, "performance_audit_trade_shape.csv"),
  trades_enriched_csv = file.path(output_dir, "performance_audit_trades_enriched.csv"),
  state_accountability_csv = file.path(output_dir, "performance_audit_state_accountability.csv"),
  selected_state_asset_csv = file.path(output_dir, "performance_audit_selected_state_asset.csv"),
  selected_family_state_mix_csv = file.path(output_dir, "performance_audit_selected_family_state_mix.csv"),
  selected_parameter_profile_csv = file.path(output_dir, "performance_audit_selected_parameter_profile.csv"),
  direct_tape_png = file.path(output_dir, "performance_audit_tape_2020Q3_direct.png"),
  pooled_tape_png = file.path(output_dir, "performance_audit_tape_2020Q3_pooled.png"),
  missed_flat_heatmap_png = file.path(output_dir, "performance_audit_missed_flat_heatmap.png"),
  trade_duration_scatter_png = file.path(output_dir, "performance_audit_trade_duration_scatter.png"),
  state_accountability_png = file.path(output_dir, "performance_audit_state_accountability.png"),
  selection_state_asset_heatmap_png = file.path(output_dir, "performance_audit_selection_state_asset_heatmap.png"),
  selection_family_state_mix_png = file.path(output_dir, "performance_audit_selection_family_state_mix.png"),
  selection_parameter_profile_png = file.path(output_dir, "performance_audit_selection_parameter_profile.png"),
  report_md = file.path(output_dir, "performance_audit_report.md")
)

g5_wfa_write_csv(exposure_summary, paths$exposure_summary_csv)
g5_wfa_write_csv(trade_shape_summary, paths$trade_shape_csv)
g5_wfa_write_csv(trades_all, paths$trades_enriched_csv)
g5_wfa_write_csv(state_accountability, paths$state_accountability_csv)
g5_wfa_write_csv(selected_state_asset, paths$selected_state_asset_csv)
g5_wfa_write_csv(selected_family_state_mix, paths$selected_family_state_mix_csv)
g5_wfa_write_csv(selected_parameter_profile, paths$selected_parameter_profile_csv)

write_policy_tape <- function(selection_policy, path) {
  row <- packet_index[packet_index$window_id == audit_window_id & packet_index$selection_policy == selection_policy, , drop = FALSE]
  if (nrow(row) != 1L) g5_stop(paste0("Expected one packet row for ", audit_window_id, " / ", selection_policy))
  replay <- read_csv_if_exists(row$replay_csv[[1L]])
  trades <- read_csv_if_exists(row$trades_csv[[1L]])
  executions <- read_csv_if_exists(file.path(row$packet_dir[[1L]], "bridge_executions.csv"))
  pending <- read_csv_if_exists(file.path(row$packet_dir[[1L]], "bridge_pending_actions.csv"))
  symbols <- unique(as.character(replay$symbol))
  grDevices::png(path, width = 3000L, height = 2100L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = g5_chart_aesthetic()$background, mfrow = c(ceiling(length(symbols) / 2), 2), mar = c(4, 4, 3, 1))
  for (symbol in symbols) {
    r <- replay[as.character(replay$symbol) == symbol, , drop = FALSE]
    e <- executions[as.character(executions$symbol) == symbol, , drop = FALSE]
    p <- pending[as.character(pending$symbol) == symbol, , drop = FALSE]
    t <- trades[as.character(trades$symbol) == symbol, , drop = FALSE]
    g5_bridge_plot_panel(
      r,
      e,
      p,
      t,
      main = paste0(symbol, " | ", policy_label(selection_policy), " | ", audit_window_id)
    )
  }
  invisible(path)
}

write_missed_flat_heatmap <- function(path) {
  aesthetic <- g5_chart_aesthetic()
  windows <- unique(as.character(exposure_summary$window_id))
  symbols <- unique(as.character(exposure_summary$symbol))
  policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
  grDevices::png(path, width = 2800L, height = 1450L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(1, 2), mar = c(7.5, 7, 4, 1), oma = c(0, 0, 2.5, 0))
  for (policy in policies) {
    x <- exposure_summary[exposure_summary$selection_policy == policy, , drop = FALSE]
    row_ids <- symbols
    values <- matrix(NA_real_, nrow = length(row_ids), ncol = length(windows), dimnames = list(row_ids, windows))
    exposure <- values
    for (i in seq_len(nrow(x))) {
      values[as.character(x$symbol[[i]]), as.character(x$window_id[[i]])] <- as.numeric(x$missed_flat_return[[i]])
      exposure[as.character(x$symbol[[i]]), as.character(x$window_id[[i]])] <- as.numeric(x$exposure_ratio[[i]])
    }
    colors <- delta_colors(as.vector(values), positive = "#F15A5A", negative = "#00A88F")
    dim(colors) <- dim(values)
    graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = paste(policy_label(policy), "policy"), col.main = aesthetic$text, fg = aesthetic$axis)
    graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
    for (r in seq_len(nrow(values))) {
      for (c in seq_len(ncol(values))) {
        graphics::rect(c - 0.5, nrow(values) - r + 0.5, c + 0.5, nrow(values) - r + 1.5, col = colors[r, c], border = aesthetic$grid)
        lab <- paste0(pp_label(values[r, c], 0L), "\nlong ", pct_label(exposure[r, c], 0L))
        graphics::text(c, nrow(values) - r + 1, labels = lab, cex = 0.62, col = aesthetic$text)
      }
    }
    graphics::axis(1, at = seq_along(windows), labels = sub("_asof_.*$", "", windows), las = 2, cex.axis = 0.72, col.axis = aesthetic$axis)
    graphics::axis(2, at = rev(seq_along(row_ids)), labels = row_ids, las = 1, cex.axis = 0.78, col.axis = aesthetic$axis)
  }
  graphics::mtext("Return that occurred while the model was flat. Red means missed upside; green means avoided downside.", side = 3, outer = TRUE, line = 0.7, font = 2, col = aesthetic$text)
  invisible(path)
}

write_trade_duration_scatter <- function(path) {
  aesthetic <- g5_chart_aesthetic()
  if (!nrow(trades_all)) return(invisible(NULL))
  policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
  colors <- c(asset_state_direct_spec = "#2E86AB", pooled_family_asset_variant = "#9B5DE5")
  grDevices::png(path, width = 2800L, height = 1200L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(1, 2), mar = c(5, 5, 4, 1), oma = c(0, 0, 2.4, 0))
  y_lim <- range(as.numeric(trades_all$trade_return), finite = TRUE)
  x_lim <- range(as.numeric(trades_all$trade_duration_days), finite = TRUE)
  y_pad <- diff(y_lim) * 0.08
  if (!is.finite(y_pad) || y_pad == 0) y_pad <- 0.05
  for (policy in policies) {
    x <- trades_all[trades_all$selection_policy == policy, , drop = FALSE]
    graphics::plot(
      as.numeric(x$trade_duration_days),
      as.numeric(x$trade_return) * 100,
      pch = ifelse(as.character(x$trade_status) == "open", 17L, 19L),
      col = grDevices::adjustcolor(colors[[policy]], alpha.f = 0.78),
      bg = colors[[policy]],
      xlim = x_lim,
      ylim = (y_lim + c(-y_pad, y_pad)) * 100,
      xlab = "Trade duration, calendar days",
      ylab = "Trade return (%)",
      main = paste(policy_label(policy), "policy"),
      col.axis = aesthetic$axis,
      col.lab = aesthetic$text,
      col.main = aesthetic$text,
      fg = aesthetic$axis
    )
    graphics::rect(par("usr")[[1L]], par("usr")[[3L]], par("usr")[[2L]], par("usr")[[4L]], col = aesthetic$panel_background, border = NA)
    graphics::grid(nx = NULL, ny = NULL, col = aesthetic$grid)
    graphics::points(as.numeric(x$trade_duration_days), as.numeric(x$trade_return) * 100, pch = ifelse(as.character(x$trade_status) == "open", 17L, 19L), col = grDevices::adjustcolor(colors[[policy]], alpha.f = 0.78))
    graphics::abline(h = 0, lty = 2, col = aesthetic$axis)
    if (nrow(x)) {
      worst <- x[which.min(as.numeric(x$trade_return)), , drop = FALSE]
      best <- x[which.max(as.numeric(x$trade_return)), , drop = FALSE]
      graphics::text(as.numeric(worst$trade_duration_days), as.numeric(worst$trade_return) * 100, labels = worst$symbol, pos = 3, cex = 0.7, col = aesthetic$text)
      graphics::text(as.numeric(best$trade_duration_days), as.numeric(best$trade_return) * 100, labels = best$symbol, pos = 3, cex = 0.7, col = aesthetic$text)
    }
  }
  graphics::mtext("Each point is one replayed trade across all six windows. Triangles are still open at window end.", side = 3, outer = TRUE, line = 0.7, font = 2, col = aesthetic$text)
  invisible(path)
}

write_state_accountability <- function(path) {
  aesthetic <- g5_chart_aesthetic()
  states <- sort(unique(as.character(state_accountability$state_id)))
  policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
  values <- matrix(NA_real_, nrow = length(states), ncol = length(policies), dimnames = list(states, policies))
  exposure <- values
  family <- matrix("", nrow = length(states), ncol = length(policies), dimnames = list(states, policies))
  for (i in seq_len(nrow(state_accountability))) {
    s <- as.character(state_accountability$state_id[[i]])
    p <- as.character(state_accountability$selection_policy[[i]])
    values[s, p] <- as.numeric(state_accountability$mean_daily_excess_return[[i]])
    exposure[s, p] <- as.numeric(state_accountability$exposure_ratio[[i]])
    family[s, p] <- as.character(state_accountability$dominant_selected_family[[i]])
  }
  grDevices::png(path, width = 1800L, height = 1450L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(4.5, 8, 4.5, 2))
  colors <- delta_colors(as.vector(values))
  dim(colors) <- dim(values)
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "State Accountability | Mean Daily Excess While In Each State", col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  for (r in seq_len(nrow(values))) {
    for (c in seq_len(ncol(values))) {
      graphics::rect(c - 0.5, nrow(values) - r + 0.5, c + 0.5, nrow(values) - r + 1.5, col = colors[r, c], border = aesthetic$grid)
      lab <- paste0(pp_label(values[r, c], 1L), "\nlong ", pct_label(exposure[r, c], 0L), "\n", family[r, c])
      graphics::text(c, nrow(values) - r + 1, labels = lab, cex = 0.58, col = aesthetic$text)
    }
  }
  graphics::axis(1, at = seq_along(policies), labels = policy_label(policies), las = 1, cex.axis = 0.8, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(states)), labels = states, las = 1, cex.axis = 0.8, col.axis = aesthetic$axis)
  graphics::mtext("Green beat hold on average in that state; red lagged. Labels show daily excess, exposure, and dominant family.", side = 1, line = 3.0, cex = 0.72, col = aesthetic$text)
  invisible(path)
}

write_selection_state_asset_heatmap <- function(path) {
  if (!nrow(selected_state_asset)) return(invisible(NULL))
  aesthetic <- g5_chart_aesthetic()
  policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
  symbols <- c("AMD", "NVDA", "TSLA", "AAPL", "MSTR")
  symbols <- symbols[symbols %in% unique(selected_state_asset$symbol)]
  states <- sort(unique(as.character(selected_state_asset$state_id)))
  grDevices::png(path, width = 3000L, height = 1500L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(1, 2), mar = c(6, 6.5, 4, 1), oma = c(0, 0, 3, 0))
  for (policy in policies) {
    x <- selected_state_asset[selected_state_asset$selection_policy == policy, , drop = FALSE]
    graphics::plot(NA, xlim = c(0.5, length(states) + 0.5), ylim = c(0.5, length(symbols) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = paste(policy_label(policy), "policy"), col.main = aesthetic$text, fg = aesthetic$axis)
    graphics::rect(0.5, 0.5, length(states) + 0.5, length(symbols) + 0.5, col = aesthetic$panel_background, border = NA)
    for (r in seq_along(symbols)) {
      for (c in seq_along(states)) {
        cell <- x[x$symbol == symbols[[r]] & x$state_id == states[[c]], , drop = FALSE]
        y <- length(symbols) - r + 1
        fill <- if (nrow(cell)) family_palette(cell$dominant_family[[1L]]) else "#F5F7FA"
        graphics::rect(c - 0.5, y - 0.5, c + 0.5, y + 0.5, col = fill, border = aesthetic$grid)
        if (nrow(cell)) {
          lab <- paste0(cell$dominant_family_label[[1L]], "\n", cell$dominant_family_count[[1L]], "/", cell$selected_rows[[1L]])
          graphics::text(c, y, labels = lab, cex = 0.58, col = if (identical(cell$dominant_family[[1L]], "no_trade")) aesthetic$text else "white", font = 2)
        }
      }
    }
    graphics::axis(1, at = seq_along(states), labels = states, las = 2, cex.axis = 0.72, col.axis = aesthetic$axis)
    graphics::axis(2, at = rev(seq_along(symbols)), labels = symbols, las = 1, cex.axis = 0.85, col.axis = aesthetic$axis)
  }
  graphics::mtext("Dominant selected strategy family by asset/state across frozen authority quarters. Labels show family and count/quarters.", side = 3, outer = TRUE, line = 0.8, font = 2, col = aesthetic$text)
  invisible(path)
}

write_selection_family_state_mix <- function(path) {
  if (!nrow(selected_family_state_mix)) return(invisible(NULL))
  aesthetic <- g5_chart_aesthetic()
  policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
  states <- sort(unique(as.character(selected_family_state_mix$state_id)))
  families <- c(
    "no_trade", "ema_cross", "ema_trend", "bollinger_touch", "bollinger_mid_reversion",
    "rsi_mr", "zret_mr", "breakout", "pullback_in_uptrend", "vol_expansion_breakout",
    "donchian_breakout_vol_expand"
  )
  families <- families[families %in% unique(as.character(selected_family_state_mix$strategy_family))]
  max_count <- max(selected_family_state_mix$selected_count, na.rm = TRUE)
  if (!is.finite(max_count) || max_count <= 0) max_count <- 1
  grDevices::png(path, width = 3000L, height = 1800L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(1, 2), mar = c(6, 10, 4, 1), oma = c(0, 0, 3, 0))
  for (policy in policies) {
    x <- selected_family_state_mix[selected_family_state_mix$selection_policy == policy, , drop = FALSE]
    graphics::plot(NA, xlim = c(0.5, length(states) + 0.5), ylim = c(0.5, length(families) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = paste(policy_label(policy), "policy"), col.main = aesthetic$text, fg = aesthetic$axis)
    graphics::rect(0.5, 0.5, length(states) + 0.5, length(families) + 0.5, col = aesthetic$panel_background, border = NA)
    for (r in seq_along(families)) {
      for (c in seq_along(states)) {
        cell <- x[x$strategy_family == families[[r]] & x$state_id == states[[c]], , drop = FALSE]
        count <- if (nrow(cell)) as.numeric(cell$selected_count[[1L]]) else 0
        alpha <- if (count > 0) 0.18 + 0.78 * count / max_count else 0.04
        y <- length(families) - r + 1
        graphics::rect(c - 0.5, y - 0.5, c + 0.5, y + 0.5, col = grDevices::adjustcolor(family_palette(families[[r]]), alpha.f = alpha), border = aesthetic$grid)
        if (count > 0) graphics::text(c, y, labels = count, cex = 0.64, col = aesthetic$text, font = 2)
      }
    }
    graphics::axis(1, at = seq_along(states), labels = states, las = 2, cex.axis = 0.72, col.axis = aesthetic$axis)
    graphics::axis(2, at = rev(seq_along(families)), labels = family_abbrev(families), las = 1, cex.axis = 0.78, col.axis = aesthetic$axis)
  }
  graphics::mtext("Selected-family count by state. This shows whether states consistently prefer no-trade, trend, breakout, or mean-reversion families.", side = 3, outer = TRUE, line = 0.8, font = 2, col = aesthetic$text)
  invisible(path)
}

write_selection_parameter_profile <- function(path) {
  if (!nrow(selected_parameter_profile)) return(invisible(NULL))
  aesthetic <- g5_chart_aesthetic()
  policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
  symbols <- c("AMD", "NVDA", "TSLA", "AAPL", "MSTR")
  symbols <- symbols[symbols %in% unique(selected_parameter_profile$symbol)]
  families <- unique(as.character(selected_parameter_profile$strategy_family))
  families <- setdiff(families, "no_trade")
  family_order <- c("ema_cross", "ema_trend", "bollinger_touch", "bollinger_mid_reversion", "rsi_mr", "zret_mr", "breakout", "pullback_in_uptrend", "vol_expansion_breakout", "donchian_breakout_vol_expand")
  families <- family_order[family_order %in% families]
  max_count <- max(selected_parameter_profile$selected_count, na.rm = TRUE)
  if (!is.finite(max_count) || max_count <= 0) max_count <- 1
  grDevices::png(path, width = 3000L, height = 1900L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(1, 2), mar = c(6, 9.5, 4, 1), oma = c(0, 0, 3, 0))
  for (policy in policies) {
    x <- selected_parameter_profile[selected_parameter_profile$selection_policy == policy, , drop = FALSE]
    graphics::plot(NA, xlim = c(0.5, length(symbols) + 0.5), ylim = c(0.5, length(families) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = paste(policy_label(policy), "policy"), col.main = aesthetic$text, fg = aesthetic$axis)
    graphics::rect(0.5, 0.5, length(symbols) + 0.5, length(families) + 0.5, col = aesthetic$panel_background, border = NA)
    for (r in seq_along(families)) {
      for (c in seq_along(symbols)) {
        cell <- x[x$strategy_family == families[[r]] & x$symbol == symbols[[c]], , drop = FALSE]
        y <- length(families) - r + 1
        if (nrow(cell)) {
          alpha <- 0.16 + 0.80 * as.numeric(cell$selected_count[[1L]]) / max_count
          fill <- grDevices::adjustcolor(family_palette(families[[r]]), alpha.f = alpha)
          lab <- paste0(cell$dominant_parameter_label[[1L]], "\n", cell$selected_count[[1L]], " picks")
        } else {
          fill <- "#F5F7FA"
          lab <- ""
        }
        graphics::rect(c - 0.5, y - 0.5, c + 0.5, y + 0.5, col = fill, border = aesthetic$grid)
        if (nzchar(lab)) graphics::text(c, y, labels = lab, cex = 0.44, col = aesthetic$text)
      }
    }
    graphics::axis(1, at = seq_along(symbols), labels = symbols, las = 1, cex.axis = 0.82, col.axis = aesthetic$axis)
    graphics::axis(2, at = rev(seq_along(families)), labels = family_abbrev(families), las = 1, cex.axis = 0.78, col.axis = aesthetic$axis)
  }
  graphics::mtext("Dominant selected parameter profile by asset/family across frozen authority quarters. Labels are compact parameter digests plus pick counts.", side = 3, outer = TRUE, line = 0.8, font = 2, col = aesthetic$text)
  invisible(path)
}

write_policy_tape("asset_state_direct_spec", paths$direct_tape_png)
write_policy_tape("pooled_family_asset_variant", paths$pooled_tape_png)
write_missed_flat_heatmap(paths$missed_flat_heatmap_png)
write_trade_duration_scatter(paths$trade_duration_scatter_png)
write_state_accountability(paths$state_accountability_png)
write_selection_state_asset_heatmap(paths$selection_state_asset_heatmap_png)
write_selection_family_state_mix(paths$selection_family_state_mix_png)
write_selection_parameter_profile(paths$selection_parameter_profile_png)

direct_2020 <- exposure_summary[exposure_summary$window_id == audit_window_id & exposure_summary$selection_policy == "asset_state_direct_spec", , drop = FALSE]
pooled_2020 <- exposure_summary[exposure_summary$window_id == audit_window_id & exposure_summary$selection_policy == "pooled_family_asset_variant", , drop = FALSE]

lines <- c(
  "# Performance Audit: HB Broad Risk",
  "",
  "## Purpose",
  "",
  "This artifact-only audit inspects one condition from the context-philosophy screen rather than rerunning the full factorial. It focuses on the high-beta broad-risk lane because it is closest in spirit to the live bridge's high-beta basket plus market/risk context.",
  "",
  "## Scope",
  "",
  paste0("- Screen: `", screen_id, "`"),
  "- Basket: `AMD,NVDA,TSLA,AAPL,MSTR`",
  "- Context recipe: broad risk without VXX",
  "- Policies: `asset_state_direct_spec` and `pooled_family_asset_variant`",
  paste0("- Tape audit window: `", audit_window_id, "`"),
  "",
  "## Early Readout",
  "",
  paste0("- Direct 2020Q3 mean exposure: `", pct_label(mean(direct_2020$exposure_ratio, na.rm = TRUE)), "`; mean missed-flat return: `", pp_label(mean(direct_2020$missed_flat_return, na.rm = TRUE)), "`."),
  paste0("- Pooled 2020Q3 mean exposure: `", pct_label(mean(pooled_2020$exposure_ratio, na.rm = TRUE)), "`; mean missed-flat return: `", pp_label(mean(pooled_2020$missed_flat_return, na.rm = TRUE)), "`."),
  "- The charts are qualitative inspection aids. They do not change authority selection and are not allocation evidence.",
  "",
  "## Artifacts",
  "",
  paste0("- Exposure/participation CSV: `", paths$exposure_summary_csv, "`"),
  paste0("- Trade shape CSV: `", paths$trade_shape_csv, "`"),
  paste0("- State accountability CSV: `", paths$state_accountability_csv, "`"),
  paste0("- Selection state/asset CSV: `", paths$selected_state_asset_csv, "`"),
  paste0("- Selection family/state mix CSV: `", paths$selected_family_state_mix_csv, "`"),
  paste0("- Selection parameter profile CSV: `", paths$selected_parameter_profile_csv, "`"),
  paste0("- Direct tape PNG: `", paths$direct_tape_png, "`"),
  paste0("- Pooled tape PNG: `", paths$pooled_tape_png, "`"),
  paste0("- Missed-flat heatmap: `", paths$missed_flat_heatmap_png, "`"),
  paste0("- Trade duration scatter: `", paths$trade_duration_scatter_png, "`"),
  paste0("- State accountability heatmap: `", paths$state_accountability_png, "`"),
  paste0("- Selection state/asset heatmap: `", paths$selection_state_asset_heatmap_png, "`"),
  paste0("- Selection family/state mix heatmap: `", paths$selection_family_state_mix_png, "`"),
  paste0("- Selection parameter profile heatmap: `", paths$selection_parameter_profile_png, "`")
)
writeLines(lines, paths$report_md, useBytes = TRUE)

cat("Performance audit complete:\n")
print(data.frame(path_name = names(paths), path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE), row.names = NULL), row.names = FALSE)
