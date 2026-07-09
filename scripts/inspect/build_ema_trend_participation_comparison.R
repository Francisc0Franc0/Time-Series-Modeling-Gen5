script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

screen_id <- env_or("GEN5_EMA_TREND_AUDIT_SCREEN_ID", "HB_broad_risk_no_vxx")
baseline_grid <- env_or("GEN5_EMA_TREND_AUDIT_BASELINE_GRID", "gen4_daily_default")
probe_grid <- env_or("GEN5_EMA_TREND_AUDIT_PROBE_GRID", "ema_trend_participation_compact")
candidate_families <- env_or("GEN5_EMA_TREND_AUDIT_CANDIDATE_FAMILIES", "ema_trend,no_trade")
baseline_root <- normalizePath(
  env_or("GEN5_EMA_TREND_AUDIT_BASELINE_ROOT", file.path(repo_root, "runs", "research_workbench", "selpol_context", "selpol_context_e0")),
  winslash = "/",
  mustWork = TRUE
)
probe_root <- normalizePath(
  env_or("GEN5_EMA_TREND_AUDIT_PROBE_ROOT", file.path(repo_root, "runs", "research_workbench", "selpol_context", "selpol_context_e2")),
  winslash = "/",
  mustWork = TRUE
)
output_dir <- file.path(probe_root, "ema_trend_participation_comparison", screen_id)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

read_csv_if_exists <- function(path) {
  if (!file.exists(path)) return(data.frame())
  info <- file.info(path)
  if (!is.finite(info$size[[1L]]) || info$size[[1L]] == 0) return(data.frame())
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) data.frame())
}

safe_prod_return <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x[!is.finite(x)] <- 0
  prod(1 + x) - 1
}

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

packet_index_path <- function(root) {
  file.path(root, "selection_policy_context_philosophy_packet_index.csv")
}

portfolio_path <- function(root) {
  file.path(root, "selection_policy_context_philosophy_portfolio_proxy_summary.csv")
}

run_spec_path <- function(root) {
  file.path(root, "selection_policy_context_philosophy_run_spec.csv")
}

add_daily_returns <- function(replay) {
  if (!is.data.frame(replay) || !nrow(replay)) return(data.frame())
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

portfolio_summary <- function(root, dataset_label) {
  portfolio <- read_csv_if_exists(portfolio_path(root))
  portfolio <- portfolio[portfolio$screen_id == screen_id, , drop = FALSE]
  if (!nrow(portfolio)) return(data.frame())
  portfolio$dataset_label <- dataset_label
  portfolio[, c(
    "dataset_label", "screen_id", "basket_archetype", "context_philosophy", "window_id",
    "selection_policy", "trade_count", "open_trade_count", "equal_symbol_mean_compound_trace_return",
    "worst_symbol_compound_trace_return", "best_symbol_compound_trace_return"
  ), drop = FALSE]
}

exposure_summary <- function(root, dataset_label) {
  packet_index <- read_csv_if_exists(packet_index_path(root))
  packet_index <- packet_index[packet_index$screen_id == screen_id, , drop = FALSE]
  if (!nrow(packet_index)) return(data.frame())
  replay_rows <- list()
  for (i in seq_len(nrow(packet_index))) {
    replay <- read_csv_if_exists(packet_index$replay_csv[[i]])
    if (nrow(replay)) replay_rows[[length(replay_rows) + 1L]] <- replay
  }
  replay_all <- add_daily_returns(g5_wfa_bind_rows_fill(replay_rows))
  if (!nrow(replay_all)) return(data.frame())
  out <- do.call(rbind, lapply(split(replay_all, paste(replay_all$selection_policy, replay_all$window_id, replay_all$symbol, sep = "::")), function(x) {
    data.frame(
      dataset_label = dataset_label,
      screen_id = screen_id,
      selection_policy = as.character(x$selection_policy[[1L]]),
      window_id = as.character(x$window_id[[1L]]),
      symbol = as.character(x$symbol[[1L]]),
      exposure_ratio = mean(as.logical(x$model_long_lag), na.rm = TRUE),
      strategy_return = safe_prod_return(x$strategy_daily_return),
      benchmark_return = safe_prod_return(x$daily_return),
      missed_flat_return = safe_prod_return(x$flat_daily_return),
      stringsAsFactors = FALSE
    )
  }))
  do.call(rbind, lapply(split(out, paste(out$selection_policy, out$window_id, sep = "::")), function(x) {
    data.frame(
      dataset_label = dataset_label,
      screen_id = screen_id,
      selection_policy = as.character(x$selection_policy[[1L]]),
      window_id = as.character(x$window_id[[1L]]),
      mean_exposure_ratio = mean(as.numeric(x$exposure_ratio), na.rm = TRUE),
      mean_strategy_return = mean(as.numeric(x$strategy_return), na.rm = TRUE),
      mean_benchmark_return = mean(as.numeric(x$benchmark_return), na.rm = TRUE),
      mean_missed_flat_return = mean(as.numeric(x$missed_flat_return), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
}

family_selection_summary <- function(root, dataset_label) {
  selected <- read_csv_if_exists(file.path(root, screen_id, "selection_policy_selected_states_all.csv"))
  if (!nrow(selected)) return(data.frame())
  tab <- as.data.frame(table(
    selection_policy = as.character(selected$selection_policy),
    strategy_family = as.character(selected$strategy_family)
  ), stringsAsFactors = FALSE)
  names(tab)[names(tab) == "Freq"] <- "selected_count"
  totals <- stats::aggregate(selected_count ~ selection_policy, tab, sum)
  names(totals)[names(totals) == "selected_count"] <- "policy_selected_count"
  out <- merge(tab, totals, by = "selection_policy", all.x = TRUE)
  out$dataset_label <- dataset_label
  out$screen_id <- screen_id
  out$selected_share <- out$selected_count / pmax(out$policy_selected_count, 1L)
  out[, c("dataset_label", "screen_id", "selection_policy", "strategy_family", "selected_count", "policy_selected_count", "selected_share"), drop = FALSE]
}

baseline_portfolio <- portfolio_summary(baseline_root, "baseline_gen4_daily_default")
probe_portfolio <- portfolio_summary(probe_root, "probe_ema_trend_participation_compact")
baseline_exposure <- exposure_summary(baseline_root, "baseline_gen4_daily_default")
probe_exposure <- exposure_summary(probe_root, "probe_ema_trend_participation_compact")
baseline_family <- family_selection_summary(baseline_root, "baseline_gen4_daily_default")
probe_family <- family_selection_summary(probe_root, "probe_ema_trend_participation_compact")

portfolio_all <- g5_wfa_bind_rows_fill(list(baseline_portfolio, probe_portfolio))
exposure_all <- g5_wfa_bind_rows_fill(list(baseline_exposure, probe_exposure))
family_all <- g5_wfa_bind_rows_fill(list(baseline_family, probe_family))

required_key <- c("selection_policy", "window_id")
comparison <- merge(
  baseline_portfolio[, c(required_key, "equal_symbol_mean_compound_trace_return", "trade_count", "open_trade_count"), drop = FALSE],
  probe_portfolio[, c(required_key, "equal_symbol_mean_compound_trace_return", "trade_count", "open_trade_count"), drop = FALSE],
  by = required_key,
  suffixes = c("_baseline", "_probe")
)
comparison <- merge(
  comparison,
  baseline_exposure[, c(required_key, "mean_exposure_ratio", "mean_missed_flat_return"), drop = FALSE],
  by = required_key,
  all.x = TRUE
)
names(comparison)[names(comparison) %in% c("mean_exposure_ratio", "mean_missed_flat_return")] <- c("mean_exposure_ratio_baseline", "mean_missed_flat_return_baseline")
comparison <- merge(
  comparison,
  probe_exposure[, c(required_key, "mean_exposure_ratio", "mean_missed_flat_return"), drop = FALSE],
  by = required_key,
  all.x = TRUE
)
names(comparison)[names(comparison) %in% c("mean_exposure_ratio", "mean_missed_flat_return")] <- c("mean_exposure_ratio_probe", "mean_missed_flat_return_probe")
comparison$return_delta_probe_minus_baseline <- as.numeric(comparison$equal_symbol_mean_compound_trace_return_probe) - as.numeric(comparison$equal_symbol_mean_compound_trace_return_baseline)
comparison$trade_count_delta_probe_minus_baseline <- as.numeric(comparison$trade_count_probe) - as.numeric(comparison$trade_count_baseline)
comparison$exposure_delta_probe_minus_baseline <- as.numeric(comparison$mean_exposure_ratio_probe) - as.numeric(comparison$mean_exposure_ratio_baseline)
comparison$missed_flat_delta_probe_minus_baseline <- as.numeric(comparison$mean_missed_flat_return_probe) - as.numeric(comparison$mean_missed_flat_return_baseline)

family_comparison <- merge(
  baseline_family[, c("selection_policy", "strategy_family", "selected_count", "selected_share"), drop = FALSE],
  probe_family[, c("selection_policy", "strategy_family", "selected_count", "selected_share"), drop = FALSE],
  by = c("selection_policy", "strategy_family"),
  all = TRUE,
  suffixes = c("_baseline", "_probe")
)
for (col in c("selected_count_baseline", "selected_count_probe", "selected_share_baseline", "selected_share_probe")) {
  if (!col %in% names(family_comparison)) family_comparison[[col]] <- 0
  family_comparison[[col]][is.na(family_comparison[[col]])] <- 0
}
family_comparison$selected_count_delta_probe_minus_baseline <- family_comparison$selected_count_probe - family_comparison$selected_count_baseline
family_comparison$selected_share_delta_probe_minus_baseline <- family_comparison$selected_share_probe - family_comparison$selected_share_baseline

paths <- list(
  run_spec_csv = file.path(output_dir, "ema_trend_participation_comparison_run_spec.csv"),
  portfolio_all_csv = file.path(output_dir, "ema_trend_participation_portfolio_all.csv"),
  exposure_all_csv = file.path(output_dir, "ema_trend_participation_exposure_all.csv"),
  comparison_csv = file.path(output_dir, "ema_trend_participation_comparison_summary.csv"),
  family_comparison_csv = file.path(output_dir, "ema_trend_participation_family_selection_delta.csv"),
  return_heatmap_png = file.path(output_dir, "ema_trend_participation_return_delta_heatmap.png"),
  exposure_heatmap_png = file.path(output_dir, "ema_trend_participation_exposure_delta_heatmap.png"),
  family_delta_png = file.path(output_dir, "ema_trend_participation_family_delta.png"),
  report_md = file.path(output_dir, "ema_trend_participation_comparison_report.md")
)

run_spec <- data.frame(
  schema_version = "gen5_ema_trend_participation_audit_v0.1",
  screen_id = screen_id,
  baseline_root = baseline_root,
  probe_root = probe_root,
  baseline_grid = baseline_grid,
  probe_grid = probe_grid,
  candidate_families = candidate_families,
  research_only = TRUE,
  comparison_note = "Artifact-only comparison of EMA-only default trend specs against compact participation trend variants.",
  stringsAsFactors = FALSE
)

g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(portfolio_all, paths$portfolio_all_csv)
g5_wfa_write_csv(exposure_all, paths$exposure_all_csv)
g5_wfa_write_csv(comparison, paths$comparison_csv)
g5_wfa_write_csv(family_comparison, paths$family_comparison_csv)

delta_colors <- function(values, positive = "#00A88F", negative = "#F15A5A", neutral = "#FFFDF8") {
  values <- suppressWarnings(as.numeric(values))
  max_abs <- max(abs(values), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  vapply(values, function(value) {
    if (!is.finite(value) || value == 0) return(neutral)
    grDevices::adjustcolor(if (value > 0) positive else negative, alpha.f = min(0.95, 0.20 + 0.75 * abs(value) / max_abs))
  }, character(1L))
}

write_delta_heatmap <- function(metric, path, title, label_fun = pp_label, positive = "#00A88F", negative = "#F15A5A") {
  aesthetic <- g5_chart_aesthetic()
  windows <- unique(as.character(comparison$window_id))
  policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
  values <- matrix(NA_real_, nrow = length(policies), ncol = length(windows), dimnames = list(policy_label(policies), windows))
  for (i in seq_len(nrow(comparison))) {
    p <- policy_label(comparison$selection_policy[[i]])
    w <- as.character(comparison$window_id[[i]])
    values[p, w] <- as.numeric(comparison[[metric]][[i]])
  }
  grDevices::png(path, width = 1900L, height = 900L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(7, 7, 4, 1))
  colors <- delta_colors(as.vector(values), positive = positive, negative = negative)
  dim(colors) <- dim(values)
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = title, col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  for (r in seq_len(nrow(values))) {
    for (c in seq_len(ncol(values))) {
      y <- nrow(values) - r + 1
      graphics::rect(c - 0.5, y - 0.5, c + 0.5, y + 0.5, col = colors[r, c], border = aesthetic$grid)
      graphics::text(c, y, labels = label_fun(values[r, c]), cex = 0.75, col = aesthetic$text, font = 2)
    }
  }
  graphics::axis(1, at = seq_along(windows), labels = sub("_asof_.*$", "", windows), las = 2, cex.axis = 0.78, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_len(nrow(values))), labels = rownames(values), las = 1, cex.axis = 0.86, col.axis = aesthetic$axis)
  invisible(path)
}

write_family_delta <- function(path) {
  aesthetic <- g5_chart_aesthetic()
  policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")
  families <- unique(as.character(family_comparison$strategy_family))
  families <- families[order(families)]
  values <- matrix(0, nrow = length(families), ncol = length(policies), dimnames = list(families, policy_label(policies)))
  for (i in seq_len(nrow(family_comparison))) {
    values[as.character(family_comparison$strategy_family[[i]]), policy_label(family_comparison$selection_policy[[i]])] <- as.numeric(family_comparison$selected_share_delta_probe_minus_baseline[[i]])
  }
  grDevices::png(path, width = 1200L, height = 1300L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(4.5, 10, 4.5, 1))
  colors <- delta_colors(as.vector(values))
  dim(colors) <- dim(values)
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Selection Share Delta By Family | Probe Minus Baseline", col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  for (r in seq_len(nrow(values))) {
    for (c in seq_len(ncol(values))) {
      y <- nrow(values) - r + 1
      graphics::rect(c - 0.5, y - 0.5, c + 0.5, y + 0.5, col = colors[r, c], border = aesthetic$grid)
      graphics::text(c, y, labels = pp_label(values[r, c], 1L), cex = 0.62, col = aesthetic$text)
    }
  }
  graphics::axis(1, at = seq_along(policies), labels = policy_label(policies), las = 1, cex.axis = 0.82, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(families)), labels = families, las = 1, cex.axis = 0.68, col.axis = aesthetic$axis)
  invisible(path)
}

write_delta_heatmap("return_delta_probe_minus_baseline", paths$return_heatmap_png, "EMA Trend Probe Return Delta | Probe Minus Baseline", pp_label)
write_delta_heatmap("exposure_delta_probe_minus_baseline", paths$exposure_heatmap_png, "EMA Trend Probe Exposure Delta | Probe Minus Baseline", pp_label)
write_family_delta(paths$family_delta_png)

mean_return_delta <- stats::aggregate(return_delta_probe_minus_baseline ~ selection_policy, comparison, mean, na.rm = TRUE)
mean_exposure_delta <- stats::aggregate(exposure_delta_probe_minus_baseline ~ selection_policy, comparison, mean, na.rm = TRUE)
readout <- merge(mean_return_delta, mean_exposure_delta, by = "selection_policy", all = TRUE)
readout$policy_label <- policy_label(readout$selection_policy)

lines <- c(
  "# EMA Trend Participation Probe Comparison",
  "",
  "## Purpose",
  "",
  "This artifact-only comparison uses the current `HB_broad_risk_no_vxx` audit lane as a troubleshooting testbed. It compares default EMA trend specs against a compact participation preset, with candidate families restricted to `ema_trend,no_trade` so the mechanism is isolated before spending full-family compute.",
  "",
  "## Scope",
  "",
  paste0("- Screen: `", screen_id, "`"),
  paste0("- Baseline root: `", baseline_root, "`"),
  paste0("- Probe root: `", probe_root, "`"),
  paste0("- Baseline grid: `", baseline_grid, "`"),
  paste0("- Probe grid: `", probe_grid, "`"),
  paste0("- Candidate families: `", candidate_families, "`"),
  "- Selection policies: `asset_state_direct_spec`, `pooled_family_asset_variant`",
  "- Leakage guardrail: the probe reruns TRAIN-only authority selection and frozen replay; this comparison reads artifacts only.",
  "",
  "## Early Readout",
  "",
  paste0("- Direct mean return delta: `", pp_label(readout$return_delta_probe_minus_baseline[readout$selection_policy == "asset_state_direct_spec"], 1L), "`; exposure delta: `", pp_label(readout$exposure_delta_probe_minus_baseline[readout$selection_policy == "asset_state_direct_spec"], 1L), "`."),
  paste0("- Pooled mean return delta: `", pp_label(readout$return_delta_probe_minus_baseline[readout$selection_policy == "pooled_family_asset_variant"], 1L), "`; exposure delta: `", pp_label(readout$exposure_delta_probe_minus_baseline[readout$selection_policy == "pooled_family_asset_variant"], 1L), "`."),
  "- Positive deltas mean the participation probe exceeded the baseline for that inspection metric. This is troubleshooting evidence only, not accepted allocation evidence.",
  "",
  "## Artifacts",
  "",
  paste0("- Run spec: `", paths$run_spec_csv, "`"),
  paste0("- Comparison summary: `", paths$comparison_csv, "`"),
  paste0("- Exposure summary: `", paths$exposure_all_csv, "`"),
  paste0("- Family selection delta: `", paths$family_comparison_csv, "`"),
  paste0("- Return delta heatmap: `", paths$return_heatmap_png, "`"),
  paste0("- Exposure delta heatmap: `", paths$exposure_heatmap_png, "`"),
  paste0("- Family delta heatmap: `", paths$family_delta_png, "`")
)
writeLines(lines, paths$report_md, useBytes = TRUE)

cat("EMA trend participation comparison complete:\n")
print(data.frame(path_name = names(paths), path = normalizePath(unlist(paths), winslash = "/", mustWork = FALSE), row.names = NULL), row.names = FALSE)
