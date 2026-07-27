# Gen5 T1 frozen multi-asset trend persistence POC.
# Research only: no live advice, allocation authority, or execution behavior.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
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
source(file.path(repo_root, "R", "gen5_t1_multi_asset_trend_poc.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in%
    c("1", "true", "yes", "y")
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create T1 output directory.", call. = FALSE)
}

t1_colors <- c(
  t1_trend = "#3D8DFF",
  static_equal_weight = "#0F172A",
  cash_bil = "#64748B",
  exposure_matched_equal_weight = "#177245"
)

plot_signal_support <- function(analysis, path) {
  support <- analysis$signal_support
  separation <- analysis$measurement$separation
  periods <- c(
    "development_2017_2021",
    "confirmation_2022_2024",
    "historical_shadow_2025_2026"
  )
  labels <- c("Development", "Confirmation", "Historical shadow")
  separation <- separation[match(periods, separation$evaluation_period), , drop = FALSE]
  png(path, width = 1800, height = 1100, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  on_counts <- tapply(support$on_count, support$evaluation_period, sum)
  off_counts <- tapply(support$off_count, support$evaluation_period, sum)
  counts <- rbind(
    ON = as.numeric(on_counts[periods]),
    OFF = as.numeric(off_counts[periods])
  )
  counts[is.na(counts)] <- 0
  bars <- barplot(
    counts,
    names.arg = labels,
    col = c("#3D8DFF", "#CBD5E1"),
    ylab = "Asset-month observations",
    main = "T1 signal support is visible before portfolio interpretation"
  )
  legend("topright", legend = rownames(counts), fill = c("#3D8DFF", "#CBD5E1"), bty = "n")
  for (column_i in seq_len(ncol(counts))) {
    text(
      bars[[column_i]],
      cumsum(counts[, column_i]) - counts[, column_i] / 2,
      labels = counts[, column_i],
      cex = 0.75
    )
  }
  values <- 10000 * separation$on_minus_off
  bars2 <- barplot(
    values,
    names.arg = labels,
    col = ifelse(values > 0, "#177245", "#B42318"),
    ylab = "ON minus OFF next-month excess return (bp)",
    main = "The mechanism test compares asset-minus-BIL outcomes"
  )
  abline(h = 0, col = "#0F172A")
  text(bars2, values, labels = sprintf("%.1f", values), pos = ifelse(values >= 0, 3, 1))
  par(old)
  dev.off()
}

plot_asset_separation <- function(analysis, path) {
  summary <- analysis$measurement$by_asset
  summary <- summary[match(analysis$contract$risk_assets, summary$symbol), , drop = FALSE]
  values <- 10000 * summary$on_minus_off
  value_range <- range(c(values, 0), na.rm = TRUE)
  padding <- max(10, 0.12 * diff(value_range))
  png(path, width = 1700, height = 850, res = 150)
  old <- par(mar = c(7, 7, 4, 2))
  bars <- barplot(
    values,
    names.arg = summary$symbol,
    las = 2,
    col = ifelse(values > 0, "#177245", "#B42318"),
    ylim = c(value_range[[1L]] - padding, value_range[[2L]] + padding),
    ylab = "Full-history ON minus OFF (bp per month)",
    main = "Asset-level separation prevents one-market storytelling"
  )
  abline(h = 0, col = "#0F172A")
  text(bars, values, labels = sprintf("%.1f", values), pos = ifelse(values >= 0, 3, 1), cex = 0.72)
  par(old)
  dev.off()
}

plot_exposure_tape <- function(analysis, path) {
  support <- analysis$signal_support
  png(path, width = 1900, height = 850, res = 150)
  old <- par(mar = c(6, 7, 4, 5))
  plot(
    support$decision_date,
    support$risky_exposure,
    type = "s",
    lwd = 2.5,
    col = "#3D8DFF",
    ylim = c(0, 1),
    xlab = "Month-end decision",
    ylab = "Risky-asset exposure",
    main = "Fixed sleeves translate fourteen binary signals into variable exposure"
  )
  abline(h = c(0.25, 0.5, 0.75), col = "#CBD5E1", lty = 3)
  abline(v = as.Date(c("2022-01-01", "2025-01-01")), col = "#64748B", lty = 2)
  points(support$decision_date, support$risky_exposure, pch = 16, cex = 0.55, col = "#3D8DFF")
  axis(4, at = seq(0, 1, by = 1 / 14), labels = 0:14, cex.axis = 0.65)
  mtext("ON sleeves", side = 4, line = 3)
  legend(
    "bottomleft",
    legend = c("T1 risky exposure", "2022 / 2025 boundaries"),
    col = c("#3D8DFF", "#64748B"),
    lty = c(1, 2),
    lwd = c(2.5, 1),
    bty = "n"
  )
  par(old)
  dev.off()
}

plot_equity_drawdown <- function(analysis, path) {
  replay <- analysis$primary_replay
  strategies <- names(t1_colors)
  png(path, width = 1900, height = 1150, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  xlim <- range(replay$outcome_end_date)
  ylim <- range(replay$wealth, na.rm = TRUE)
  plot(xlim, ylim, type = "n", xlab = "", ylab = "Growth of $1", main = "T1 and all frozen controls, net of 5 bp one-way costs")
  for (strategy in strategies) {
    part <- replay[replay$strategy_id == strategy, , drop = FALSE]
    lines(part$outcome_end_date, part$wealth, col = t1_colors[[strategy]], lwd = if (strategy == "t1_trend") 3 else 2)
  }
  legend(
    "topleft",
    legend = c("T1 trend", "Static equal weight", "100% BIL", "Exposure-matched equal weight"),
    col = t1_colors,
    lty = 1,
    lwd = c(3, 2, 2, 2),
    bty = "n",
    ncol = 2
  )
  drawdown_range <- range(replay$drawdown, na.rm = TRUE)
  plot(xlim, drawdown_range, type = "n", xlab = "Holding-period endpoint", ylab = "Drawdown", main = "Drawdown is evaluated on the same monthly open-to-open accounting")
  for (strategy in strategies) {
    part <- replay[replay$strategy_id == strategy, , drop = FALSE]
    lines(part$outcome_end_date, part$drawdown, col = t1_colors[[strategy]], lwd = if (strategy == "t1_trend") 3 else 2)
  }
  abline(h = 0, col = "#0F172A")
  par(old)
  dev.off()
}

plot_contributions <- function(analysis, path) {
  summary <- analysis$attribution$summary
  values <- summary$cumulative_arithmetic_contribution
  shares <- 100 * summary$positive_contribution_share
  contribution_range <- range(c(100 * values, 0), na.rm = TRUE)
  contribution_padding <- max(0.4, 0.20 * diff(contribution_range))
  png(path, width = 1800, height = 1000, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(6, 7, 5, 2))
  bars <- barplot(
    100 * values,
    names.arg = summary$symbol,
    las = 2,
    col = ifelse(values > 0, "#177245", "#B42318"),
    ylim = c(
      contribution_range[[1L]] - contribution_padding,
      contribution_range[[2L]] + contribution_padding
    ),
    ylab = "Arithmetic contribution (percentage points)",
    main = "Confirmation attribution: T1 minus exposure-matched control"
  )
  abline(h = 0, col = "#0F172A")
  text(bars, 100 * values, labels = sprintf("%.2f", 100 * values), pos = ifelse(values >= 0, 3, 1), cex = 0.68)
  bars2 <- barplot(
    shares,
    names.arg = summary$symbol,
    las = 2,
    col = ifelse(shares <= 35, "#3D8DFF", "#B42318"),
    ylim = c(0, max(40, shares, na.rm = TRUE) + 5),
    ylab = "Share of positive risk-asset attribution (%)",
    main = "The frozen concentration cap is 35%"
  )
  abline(h = 35, col = "#B42318", lty = 2, lwd = 2)
  text(bars2, shares, labels = sprintf("%.1f", shares), pos = 3, cex = 0.68)
  par(old)
  dev.off()
}

representative_decisions <- function(analysis) {
  support <- analysis$signal_support
  periods <- unique(support$evaluation_period)
  rows <- lapply(periods, function(period_id) {
    part <- support[support$evaluation_period == period_id & support$eligible_outcome_count == 14L, , drop = FALSE]
    if (!nrow(part)) return(NULL)
    low <- part[which.min(part$on_count), , drop = FALSE]
    high <- part[which.max(part$on_count), , drop = FALSE]
    rbind(low, high)
  })
  out <- do.call(rbind, rows)
  out <- out[!duplicated(out$decision_date), , drop = FALSE]
  out[seq_len(min(6L, nrow(out))), , drop = FALSE]
}

plot_representative_tapes <- function(analysis, path) {
  selected <- representative_decisions(analysis)
  panel <- analysis$primary_panel
  png(path, width = 2400, height = 1500, res = 150)
  old <- par(mfrow = c(2, 3), mar = c(7, 5, 4, 2))
  for (i in seq_len(6L)) {
    if (i > nrow(selected)) {
      plot.new()
      next
    }
    row <- selected[i, , drop = FALSE]
    part <- panel[panel$decision_date == row$decision_date, , drop = FALSE]
    part <- part[match(analysis$contract$risk_assets, part$symbol), , drop = FALSE]
    values <- rbind(
      `12m trend excess` = 100 * part$trend_excess_log_return,
      `next-month excess` = 100 * part$asset_minus_cash_next_month_return
    )
    barplot(
      values,
      beside = TRUE,
      names.arg = part$symbol,
      las = 2,
      col = c("#3D8DFF", "#177245"),
      ylab = "Percent",
      main = paste0(
        row$decision_date, " | ", row$on_count, "/14 ON\n",
        gsub("_", " ", row$evaluation_period)
      ),
      cex.names = 0.7
    )
    abline(h = 0, col = "#0F172A")
    if (i == 1L) {
      legend("topleft", legend = rownames(values), fill = c("#3D8DFF", "#177245"), bty = "n", cex = 0.8)
    }
  }
  par(old)
  dev.off()
}

plot_gates <- function(analysis, path) {
  gates <- analysis$gates
  png(path, width = 1900, height = 1050, res = 150)
  old <- par(mar = c(4, 22, 4, 3))
  y <- rev(seq_len(nrow(gates)))
  plot(
    c(0, 1),
    c(0.5, nrow(gates) + 0.5),
    type = "n",
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = paste("Frozen T1 gates:", analysis$overall_status)
  )
  axis(2, at = y, labels = gates$gate, las = 1, cex.axis = 0.78)
  points(
    rep(0.45, nrow(gates)),
    y,
    pch = 19,
    cex = 3.2,
    col = ifelse(gates$status == "PASS", "#177245", "#B42318")
  )
  text(rep(0.45, nrow(gates)), y, labels = gates$status, col = "white", font = 2, cex = 0.58)
  text(rep(0.62, nrow(gates)), y, labels = gates$value, pos = 4, cex = 0.8)
  par(old)
  dev.off()
}

write_report <- function(path, analysis, run_spec, query, artifact_paths) {
  confirmation <- analysis$primary_confirmation_metrics
  t1 <- confirmation[confirmation$strategy_id == "t1_trend", , drop = FALSE]
  static <- confirmation[confirmation$strategy_id == "static_equal_weight", , drop = FALSE]
  exposure <- confirmation[confirmation$strategy_id == "exposure_matched_equal_weight", , drop = FALSE]
  sep <- analysis$measurement$separation
  sep <- sep[sep$evaluation_period == "confirmation_2022_2024", , drop = FALSE]
  failed <- analysis$gates$gate[analysis$gates$status == "FAIL"]
  lines <- c(
    "# Gen5 T1 Multi-Asset Trend Persistence POC",
    "",
    paste0("Status: `", analysis$overall_status, "`"),
    "",
    "## Frozen question",
    "",
    "Does a fixed fourteen-sleeve portfolio that holds a risk ETF only when its trailing 12-month adjusted return exceeds BIL improve conditional exposure quality under monthly next-open execution?",
    "",
    "## Authority and scope",
    "",
    paste0("- Explicit as-of: `", run_spec$as_of_timestamp[[1L]], "`."),
    paste0("- Adjusted daily Alpaca feed: `", run_spec$feed[[1L]], "`."),
    paste0("- Generic workbench health: `", run_spec$data_health_max_severity[[1L]], "`; frozen T1 reference-session coverage: `", run_spec$t1_session_coverage_status[[1L]], "`."),
    paste0("- Frozen risk assets: `", paste(analysis$contract$risk_assets, collapse = ","), "`."),
    "- Cash proxy: `BIL`; no leverage, optimization, ranking, volatility scaling, or live behavior.",
    "",
    "## Measurement readout",
    "",
    paste0("- Confirmation pooled ON minus OFF asset-minus-BIL return: `", sprintf("%.2f bp", 10000 * sep$on_minus_off[[1L]]), "`."),
    paste0("- Assets with positive full-history ON minus OFF separation: `", sum(analysis$measurement$by_asset$on_minus_off > 0, na.rm = TRUE), " / 14`."),
    "",
    "## Confirmation portfolio readout at 5 bp one way",
    "",
    paste0("- T1 annualized compound return: `", sprintf("%.2f%%", 100 * t1$annualized_compound_return), "`; maximum drawdown: `", sprintf("%.2f%%", 100 * t1$maximum_drawdown), "`."),
    paste0("- Exposure-matched annualized return: `", sprintf("%.2f%%", 100 * exposure$annualized_compound_return), "`; T1 advantage: `", sprintf("%.2f pp", 100 * (t1$annualized_compound_return - exposure$annualized_compound_return)), "`."),
    paste0("- Static equal-weight annualized return: `", sprintf("%.2f%%", 100 * static$annualized_compound_return), "`; maximum drawdown: `", sprintf("%.2f%%", 100 * static$maximum_drawdown), "`."),
    "",
    "## Gate decision",
    "",
    paste0("- Passed gates: `", sum(analysis$gates$status == "PASS"), " / 9`."),
    paste0("- Failed gates: `", if (length(failed)) paste(failed, collapse = "; ") else "none", "`."),
    "",
    if (identical(analysis$overall_status, "PASS_T1_TO_PROSPECTIVE_SHADOW")) {
      "T1 may proceed only to prospective shadow observation. This packet does not adopt T1 as a production strategy or alter live advice."
    } else {
      "Stop T1 trend persistence. Do not rescue the result by changing the lookback, deleting an asset, replacing BIL, adding volatility scaling, or redefining the evaluation window."
    },
    "",
    "## Key artifacts",
    "",
    paste0("- `", names(artifact_paths), "`: `", normalizePath(unlist(artifact_paths), winslash = "/", mustWork = FALSE), "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("Gen5 T1 frozen multi-asset trend POC starting.")
contract <- g5_t1_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_T1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_T1_REFRESH", FALSE)
run_id <- env_or("GEN5_T1_RUN_ID", "t1_multi_asset_trend_20260727")
as_of_timestamp <- env_or("GEN5_T1_AS_OF_TIMESTAMP", contract$as_of_timestamp)
if (!identical(as_of_timestamp, contract$as_of_timestamp)) {
  stop("GEN5_T1_AS_OF_TIMESTAMP must match the frozen contract.", call. = FALSE)
}
output_dir <- file.path(
  repo_root, "runs", "research_workbench",
  "retail_quant_mechanisms", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = g5_t1_required_symbols(contract),
  universe_name = "gen5_t1_frozen_multi_asset_trend",
  universe_roles = "fourteen_risk_sleeves,cash_proxy",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) stop("T1 workbench query returned no bars.", call. = FALSE)
health_max <- g5_health_max_severity(query$health)
session_coverage <- g5_t1_session_coverage_audit(query$bars, contract)
analysis_health <- if (
  !any(query$health$severity == "ERROR") &&
    all(session_coverage$status == "PASS")
) "PASS" else "FAIL"
analysis <- g5_t1_run_analysis(
  query$bars,
  contract = contract,
  data_health_status = analysis_health
)

artifact_paths <- list(
  run_spec_csv = file.path(output_dir, "t1_run_spec.csv"),
  contract_csv = file.path(output_dir, "t1_frozen_contract.csv"),
  observation_panel_csv = file.path(output_dir, "t1_observation_panel.csv"),
  diagnostic_panel_csv = file.path(output_dir, "t1_diagnostic_panels.csv"),
  signal_support_csv = file.path(output_dir, "t1_signal_support.csv"),
  measurement_pooled_csv = file.path(output_dir, "t1_measurement_pooled.csv"),
  measurement_separation_csv = file.path(output_dir, "t1_measurement_separation.csv"),
  measurement_asset_csv = file.path(output_dir, "t1_measurement_by_asset.csv"),
  measurement_year_csv = file.path(output_dir, "t1_measurement_by_year.csv"),
  primary_replay_csv = file.path(output_dir, "t1_primary_replay.csv"),
  stress_replay_csv = file.path(output_dir, "t1_stress_replay.csv"),
  primary_weights_csv = file.path(output_dir, "t1_primary_weights.csv"),
  primary_all_metrics_csv = file.path(output_dir, "t1_primary_all_metrics.csv"),
  primary_confirmation_metrics_csv = file.path(output_dir, "t1_primary_confirmation_metrics.csv"),
  stress_confirmation_metrics_csv = file.path(output_dir, "t1_stress_confirmation_metrics.csv"),
  calendar_year_returns_csv = file.path(output_dir, "t1_calendar_year_returns.csv"),
  attribution_detail_csv = file.path(output_dir, "t1_attribution_detail.csv"),
  attribution_summary_csv = file.path(output_dir, "t1_attribution_summary.csv"),
  integrity_audit_csv = file.path(output_dir, "t1_integrity_audit.csv"),
  diagnostic_summary_csv = file.path(output_dir, "t1_diagnostic_summary.csv"),
  gate_summary_csv = file.path(output_dir, "t1_gate_summary.csv"),
  session_coverage_csv = file.path(output_dir, "t1_session_coverage_audit.csv"),
  report_md = file.path(output_dir, "t1_report.md"),
  signal_support_png = file.path(visual_dir, "t1_signal_support.png"),
  asset_separation_png = file.path(visual_dir, "t1_asset_separation.png"),
  exposure_tape_png = file.path(visual_dir, "t1_risky_exposure_tape.png"),
  equity_drawdown_png = file.path(visual_dir, "t1_equity_drawdown.png"),
  attribution_png = file.path(visual_dir, "t1_asset_attribution.png"),
  representative_tapes_png = file.path(visual_dir, "t1_representative_decision_tapes.png"),
  gate_summary_png = file.path(visual_dir, "t1_gate_summary.png")
)

run_spec <- data.frame(
  schema_version = g5_t1_schema_version(),
  wrapper = "scripts/inspect/run_gen5_t1_multi_asset_trend_poc.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  t1_session_coverage_status = analysis_health,
  query_start = contract$query_start,
  query_end = contract$query_end,
  decision_start = contract$decision_start,
  decision_end = contract$decision_end,
  risk_asset_count = length(contract$risk_assets),
  cash_proxy = contract$cash_proxy,
  primary_lookback_months = contract$primary_lookback_months,
  primary_cost_bps = contract$primary_cost_bps,
  stress_cost_bps = contract$stress_cost_bps,
  model_fit_count = 0L,
  optimization_count = 0L,
  leverage = 1,
  overall_status = analysis$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
contract_frame <- data.frame(
  risk_assets = paste(contract$risk_assets, collapse = ","),
  cash_proxy = contract$cash_proxy,
  signal = "12m_asset_log_return_minus_12m_BIL_log_return_gt_zero",
  timing = "completed_month_end_after_1730_for_following_open",
  portfolio = "fourteen_equal_fixed_sleeves_OFF_to_BIL",
  controls = "static_equal_weight,100pct_BIL,exposure_matched_equal_weight",
  primary_cost_bps = contract$primary_cost_bps,
  stress_cost_bps = contract$stress_cost_bps,
  development = "2017-01_to_2021-12_decisions",
  confirmation = "2022-01_to_2024-12_decisions",
  historical_shadow = "2025-01_to_2026-06_decisions",
  stringsAsFactors = FALSE
)

query_artifacts <- g5_write_workbench_query_artifacts(
  query,
  output_dir,
  "t1_workbench_query"
)
write_csv(run_spec, artifact_paths$run_spec_csv)
write_csv(contract_frame, artifact_paths$contract_csv)
write_csv(analysis$primary_panel, artifact_paths$observation_panel_csv)
write_csv(do.call(rbind, analysis$diagnostic_panels), artifact_paths$diagnostic_panel_csv)
write_csv(analysis$signal_support, artifact_paths$signal_support_csv)
write_csv(analysis$measurement$pooled, artifact_paths$measurement_pooled_csv)
write_csv(analysis$measurement$separation, artifact_paths$measurement_separation_csv)
write_csv(analysis$measurement$by_asset, artifact_paths$measurement_asset_csv)
write_csv(analysis$measurement$by_year, artifact_paths$measurement_year_csv)
write_csv(analysis$primary_replay, artifact_paths$primary_replay_csv)
write_csv(analysis$stress_replay, artifact_paths$stress_replay_csv)
write_csv(analysis$primary_weights, artifact_paths$primary_weights_csv)
write_csv(analysis$primary_all_metrics, artifact_paths$primary_all_metrics_csv)
write_csv(analysis$primary_confirmation_metrics, artifact_paths$primary_confirmation_metrics_csv)
write_csv(analysis$stress_confirmation_metrics, artifact_paths$stress_confirmation_metrics_csv)
write_csv(analysis$calendar_year_returns, artifact_paths$calendar_year_returns_csv)
write_csv(analysis$attribution$detail, artifact_paths$attribution_detail_csv)
write_csv(analysis$attribution$summary, artifact_paths$attribution_summary_csv)
write_csv(analysis$integrity, artifact_paths$integrity_audit_csv)
write_csv(analysis$diagnostic_summary, artifact_paths$diagnostic_summary_csv)
write_csv(analysis$gates, artifact_paths$gate_summary_csv)
write_csv(analysis$session_coverage, artifact_paths$session_coverage_csv)
plot_signal_support(analysis, artifact_paths$signal_support_png)
plot_asset_separation(analysis, artifact_paths$asset_separation_png)
plot_exposure_tape(analysis, artifact_paths$exposure_tape_png)
plot_equity_drawdown(analysis, artifact_paths$equity_drawdown_png)
plot_contributions(analysis, artifact_paths$attribution_png)
plot_representative_tapes(analysis, artifact_paths$representative_tapes_png)
plot_gates(analysis, artifact_paths$gate_summary_png)
write_report(
  artifact_paths$report_md,
  analysis,
  run_spec,
  query,
  c(artifact_paths, query_artifacts$paths)
)

message("Gen5 T1 complete: ", analysis$overall_status)
message("Data health: ", health_max)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report_md, winslash = "/", mustWork = FALSE))
