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

paths <- list(
  exposure_summary_csv = file.path(output_dir, "performance_audit_exposure_participation.csv"),
  trade_shape_csv = file.path(output_dir, "performance_audit_trade_shape.csv"),
  trades_enriched_csv = file.path(output_dir, "performance_audit_trades_enriched.csv"),
  state_accountability_csv = file.path(output_dir, "performance_audit_state_accountability.csv"),
  direct_tape_png = file.path(output_dir, "performance_audit_tape_2020Q3_direct.png"),
  pooled_tape_png = file.path(output_dir, "performance_audit_tape_2020Q3_pooled.png"),
  missed_flat_heatmap_png = file.path(output_dir, "performance_audit_missed_flat_heatmap.png"),
  trade_duration_scatter_png = file.path(output_dir, "performance_audit_trade_duration_scatter.png"),
  state_accountability_png = file.path(output_dir, "performance_audit_state_accountability.png"),
  report_md = file.path(output_dir, "performance_audit_report.md")
)

g5_wfa_write_csv(exposure_summary, paths$exposure_summary_csv)
g5_wfa_write_csv(trade_shape_summary, paths$trade_shape_csv)
g5_wfa_write_csv(trades_all, paths$trades_enriched_csv)
g5_wfa_write_csv(state_accountability, paths$state_accountability_csv)

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

write_policy_tape("asset_state_direct_spec", paths$direct_tape_png)
write_policy_tape("pooled_family_asset_variant", paths$pooled_tape_png)
write_missed_flat_heatmap(paths$missed_flat_heatmap_png)
write_trade_duration_scatter(paths$trade_duration_scatter_png)
write_state_accountability(paths$state_accountability_png)

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
  paste0("- Direct tape PNG: `", paths$direct_tape_png, "`"),
  paste0("- Pooled tape PNG: `", paths$pooled_tape_png, "`"),
  paste0("- Missed-flat heatmap: `", paths$missed_flat_heatmap_png, "`"),
  paste0("- Trade duration scatter: `", paths$trade_duration_scatter_png, "`"),
  paste0("- State accountability heatmap: `", paths$state_accountability_png, "`")
)
writeLines(lines, paths$report_md, useBytes = TRUE)

cat("Performance audit complete:\n")
print(data.frame(path_name = names(paths), path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE), row.names = NULL), row.names = FALSE)
