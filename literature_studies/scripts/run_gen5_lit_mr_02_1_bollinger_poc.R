# Run the frozen LIT-MR-02.1 adaptive GLD-USO spread Bollinger POC.

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
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mr_02_1_bollinger_poc.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in%
    c("1", "true", "yes", "y")
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create MR02 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

mr02_colors <- as.list(c(
  navy = "#123047",
  blue = "#3D8DFF",
  cyan = "#26C6DA",
  green = "#177245",
  red = "#B42318",
  amber = "#F59E0B",
  slate = "#64748B",
  light = "#E2E8F0"
))

plot_signal_tape <- function(analysis, path) {
  x <- analysis$train_indicators[
    analysis$train_indicators$session_date >= analysis$contract$train_start,
    ,
    drop = FALSE
  ]
  png(path, width = 2200, height = 1250, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(4, 6, 4, 2))
  plot(
    x$session_date,
    x$spread,
    type = "l",
    col = mr02_colors$navy,
    lwd = 1.5,
    xlab = "",
    ylab = "Adaptive raw-price spread",
    main = "TRAIN adaptive spread: USO close - rolling beta x GLD close"
  )
  lines(x$session_date, x$spread_mean, col = mr02_colors$blue, lwd = 2)
  lines(
    x$session_date,
    x$spread_mean + x$spread_sd,
    col = mr02_colors$slate,
    lty = 2
  )
  lines(
    x$session_date,
    x$spread_mean - x$spread_sd,
    col = mr02_colors$slate,
    lty = 2
  )
  legend(
    "topright",
    c("Spread", "20-session mean", "+/-1 SD"),
    col = c(mr02_colors$navy, mr02_colors$blue, mr02_colors$slate),
    lty = c(1, 1, 2),
    lwd = c(1.5, 2, 1),
    bty = "n"
  )
  plot(
    x$session_date,
    x$z_score,
    type = "l",
    col = mr02_colors$navy,
    lwd = 1.2,
    xlab = "Signal close",
    ylab = "Spread z-score",
    main = "Entry outside +/-1; exit at the rolling mean"
  )
  abline(h = c(-1, 0, 1), col = c(
    mr02_colors$red, mr02_colors$slate, mr02_colors$red
  ), lty = c(2, 1, 2))
  entry_long <- x$signal_action == "enter_long_spread"
  entry_short <- x$signal_action == "enter_short_spread"
  points(x$session_date[entry_long], x$z_score[entry_long], pch = 24,
    bg = mr02_colors$green, col = mr02_colors$green, cex = 0.8)
  points(x$session_date[entry_short], x$z_score[entry_short], pch = 25,
    bg = mr02_colors$red, col = mr02_colors$red, cex = 0.8)
  par(old)
  dev.off()
}

plot_trade_and_year_summary <- function(analysis, path) {
  trades <- analysis$train_trades[analysis$train_trades$completed, , drop = FALSE]
  years <- analysis$train_years
  png(path, width = 2100, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(6, 6, 4, 2))
  if (nrow(trades)) {
    values <- 10000 * trades$primary_net_additive_return
    hist(
      values,
      breaks = 30,
      col = mr02_colors$light,
      border = "white",
      xlab = "Primary-cost net additive return (bp/trade)",
      main = "Completed TRAIN trades"
    )
    abline(v = 0, col = mr02_colors$red, lwd = 2)
    abline(v = mean(values), col = mr02_colors$blue, lwd = 3)
  } else {
    plot.new()
    title("Completed TRAIN trades")
    text(0.5, 0.5, "No completed trades", cex = 1.4)
  }
  year_values <- 100 * years$primary_net_return
  bars <- barplot(
    year_values,
    names.arg = years$calendar_year,
    col = ifelse(
      years$primary_net_return > 0,
      mr02_colors$green,
      mr02_colors$red
    ),
    ylim = c(
      min(0, min(year_values) * 1.15),
      max(0, max(year_values) * 1.25)
    ),
    ylab = "Primary-cost return (%)",
    main = "Bar-by-bar TRAIN return by year"
  )
  abline(h = 0, col = mr02_colors$navy)
  text(
    bars,
    year_values,
    sprintf("%.1f", year_values),
    pos = ifelse(years$primary_net_return >= 0, 3, 1),
    cex = 0.8
  )
  par(old)
  dev.off()
}

plot_resampling <- function(analysis, path) {
  boot <- 10000 * analysis$train_bootstrap$draws$mean_primary_net_trade_return
  random <- 10000 * analysis$train_random$distribution$mean_primary_net_trade_return
  trades <- analysis$train_trades[analysis$train_trades$completed, , drop = FALSE]
  observed <- if (nrow(trades)) {
    10000 * mean(trades$primary_net_additive_return)
  } else {
    NA_real_
  }
  png(path, width = 2100, height = 1000, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(6, 6, 4, 2))
  finite_boot <- boot[is.finite(boot)]
  if (length(finite_boot)) {
    hist(
      finite_boot,
      breaks = 35,
      col = "#D0EDFA",
      border = "white",
      xlab = "Bootstrap mean net return (bp/trade)",
      main = "Moving-block trade uncertainty"
    )
    abline(v = 0, col = mr02_colors$red, lwd = 2)
    abline(v = observed, col = mr02_colors$blue, lwd = 3)
  } else {
    plot.new()
    title("Moving-block trade uncertainty")
    text(0.5, 0.5, "Insufficient completed trades")
  }
  finite_random <- random[is.finite(random)]
  if (length(finite_random)) {
    hist(
      finite_random,
      breaks = 35,
      col = mr02_colors$light,
      border = "white",
      xlab = "Random-sign mean net return (bp/trade)",
      main = "Signal sign versus matched random signs"
    )
    abline(v = 10000 * analysis$train_random$p90, col = mr02_colors$amber,
      lwd = 3, lty = 2)
    abline(v = observed, col = mr02_colors$blue, lwd = 3)
  } else {
    plot.new()
    title("Signal sign versus matched random signs")
    text(0.5, 0.5, "Insufficient completed trades")
  }
  par(old)
  dev.off()
}

plot_statistical_diagnostics <- function(analysis, path) {
  d <- analysis$train_diagnostics
  csum <- analysis$train_convergence_bootstrap$summary
  labels <- c(
    "Static residual\nADF t",
    "Dynamic spread\nADF t",
    "AR(1) phi",
    "Half-life\n(sessions)",
    "Variance ratio\nq=5",
    "Variance ratio\nq=20",
    "z vs forward-5\ncorrelation"
  )
  values <- c(
    d$static_residual_adf_t,
    d$dynamic_spread_adf_t,
    d$dynamic_spread_phi,
    d$dynamic_spread_half_life,
    d$variance_ratio_5,
    d$variance_ratio_20,
    csum$correlation
  )
  png(path, width = 2100, height = 900, res = 150)
  old <- par(mar = c(3, 2, 5, 2))
  plot.new()
  plot.window(xlim = c(0.5, length(values) + 0.5), ylim = c(0, 1))
  title("TRAIN statistical diagnostics describe the spread; they do not prove tradability")
  for (i in seq_along(values)) {
    rect(i - 0.42, 0.25, i + 0.42, 0.78, col = if (i %% 2) "#F8FAFC" else "#EAF6FB",
      border = mr02_colors$light)
    text(i, 0.64, labels[[i]], cex = 0.85)
    text(i, 0.40, ifelse(is.finite(values[[i]]), sprintf("%.4f", values[[i]]), "NA"),
      cex = 1.25, font = 2, col = mr02_colors$navy)
  }
  text(
    4,
    0.08,
    sprintf(
      "Forward-correlation 95%% block-bootstrap interval: [%.4f, %.4f]",
      csum$lower_95,
      csum$upper_95
    ),
    cex = 0.9
  )
  par(old)
  dev.off()
}

plot_equity_drawdown <- function(analysis, path) {
  x <- analysis$train_replay
  equity <- cumprod(1 + x$primary_net_return)
  peak <- cummax(c(1, equity))[-1L]
  drawdown <- equity / peak - 1
  png(path, width = 2100, height = 1100, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(4, 6, 4, 2))
  plot(
    x$execution_date,
    equity,
    type = "l",
    col = mr02_colors$blue,
    lwd = 2,
    xlab = "",
    ylab = "Growth of $1",
    main = "TRAIN-only bar replay after primary turnover costs"
  )
  abline(h = 1, col = mr02_colors$slate, lty = 2)
  plot(
    x$execution_date,
    100 * drawdown,
    type = "h",
    col = mr02_colors$red,
    xlab = "Execution open",
    ylab = "Drawdown (%)",
    main = "TRAIN-only drawdown"
  )
  abline(h = 0, col = mr02_colors$navy)
  par(old)
  dev.off()
}

representative_trades <- function(analysis, count = 6L) {
  trades <- analysis$train_trades[analysis$train_trades$completed, , drop = FALSE]
  if (!nrow(trades)) return(trades)
  directions <- intersect(c(1L, -1L), unique(trades$direction))
  per_direction <- max(1L, floor(count / length(directions)))
  selected <- lapply(directions, function(direction) {
    x <- trades[trades$direction == direction, , drop = FALSE]
    x <- x[order(x$primary_net_additive_return), , drop = FALSE]
    idx <- unique(round(seq(
      1,
      nrow(x),
      length.out = min(per_direction, nrow(x))
    )))
    x[idx, , drop = FALSE]
  })
  out <- do.call(rbind, selected)
  out[order(out$primary_net_additive_return), , drop = FALSE]
}

plot_representative_trades <- function(analysis, path) {
  selected <- representative_trades(analysis)
  png(path, width = 2200, height = 1400, res = 150)
  if (!nrow(selected)) {
    plot.new()
    title("Representative TRAIN trade tapes")
    text(0.5, 0.5, "No completed trades", cex = 1.4)
    dev.off()
    return(invisible(path))
  }
  old <- par(
    mfrow = c(ceiling(nrow(selected) / 2), 2),
    mar = c(3, 4, 3, 1)
  )
  for (i in seq_len(nrow(selected))) {
    trade <- selected[i, , drop = FALSE]
    start <- trade$entry_date - 15
    end <- trade$exit_date + 10
    x <- analysis$train_indicators[
      analysis$train_indicators$session_date >= start &
        analysis$train_indicators$session_date <= end,
      ,
      drop = FALSE
    ]
    plot(
      x$session_date,
      x$z_score,
      type = "l",
      col = mr02_colors$navy,
      ylim = range(c(-2, 2, x$z_score), na.rm = TRUE),
      xlab = "",
      ylab = "z-score",
      main = sprintf(
        "%s | %s | %.1f bp",
        trade$direction_label,
        format(trade$entry_date),
        10000 * trade$primary_net_additive_return
      )
    )
    abline(h = c(-1, 0, 1), col = c(
      mr02_colors$red, mr02_colors$slate, mr02_colors$red
    ), lty = c(2, 1, 2))
    abline(v = trade$entry_date, col = mr02_colors$green, lwd = 2)
    abline(v = trade$exit_date, col = mr02_colors$red, lwd = 2)
  }
  par(old)
  dev.off()
}

plot_gates <- function(analysis, path) {
  gates <- analysis$gates
  n <- nrow(gates)
  png(path, width = 2200, height = max(1100, 105 * n), res = 150)
  old <- par(mar = c(2, 2, 5, 2))
  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0, n + 1))
  title(paste("LIT-MR-02.1 frozen verdict:", analysis$overall_status))
  y <- rev(seq_len(n))
  for (i in seq_len(n)) {
    status <- gates$status[[i]]
    color <- switch(status,
      PASS = mr02_colors$green,
      FAIL = mr02_colors$red,
      mr02_colors$slate
    )
    text(0.02, y[[i]], gates$gate[[i]], adj = 0, cex = 0.82)
    rect(0.56, y[[i]] - 0.28, 0.67, y[[i]] + 0.28, col = color, border = NA)
    text(0.615, y[[i]], status, col = "white", font = 2, cex = 0.70)
    text(0.71, y[[i]], gates$details[[i]], adj = 0, cex = 0.78)
  }
  par(old)
  dev.off()
}

write_report <- function(path, analysis, run_spec, artifact_paths) {
  completed <- analysis$train_trades[analysis$train_trades$completed, , drop = FALSE]
  observed <- if (nrow(completed)) mean(completed$primary_net_additive_return) else NA_real_
  hit_rate <- if (nrow(completed)) mean(completed$primary_net_additive_return > 0) else NA_real_
  diagnostics <- analysis$train_diagnostics
  convergence <- analysis$train_convergence_bootstrap$summary
  metrics <- analysis$train_metrics
  lines <- c(
    "# LIT-MR-02.1 Adaptive GLD-USO Spread Bollinger POC",
    "",
    paste0("Status: `", analysis$overall_status, "`"),
    "",
    "## Frozen interpretation",
    "",
    "- Raw adjusted-price spread: `USO - rolling_beta * GLD`.",
    "- Rolling OLS and spread standardization: 20 completed sessions.",
    "- Enter outside `+/-1z`; exit at zero.",
    "- Signal after close; execute and adapt hedge at next open.",
    "- Long low spread = long USO and short beta shares of GLD.",
    "- Development and confirmation remain sealed unless every TRAIN gate passes.",
    "",
    "## TRAIN readout",
    "",
    paste0("- Completed trades: `", nrow(completed), "` (`",
      sum(completed$direction == 1L), "` long spread, `",
      sum(completed$direction == -1L), "` short spread)."),
    paste0("- Mean primary-cost net additive return: `",
      sprintf("%.2f bp/trade", 10000 * observed), "`."),
    paste0("- 95% moving-block interval: `[",
      sprintf("%.2f", 10000 * analysis$train_bootstrap$summary$lower_95),
      ", ", sprintf("%.2f", 10000 * analysis$train_bootstrap$summary$upper_95),
      "] bp/trade`."),
    paste0("- Completed-trade hit rate: `", sprintf("%.1f%%", 100 * hit_rate), "`."),
    paste0("- Random-sign p90: `",
      sprintf("%.2f bp/trade", 10000 * analysis$train_random$p90), "`."),
    paste0("- TRAIN bar return: `", sprintf("%.2f%%", 100 * metrics$cumulative_return), "`."),
    paste0("- TRAIN naive / autocorrelation-adjusted Sharpe: `",
      sprintf("%.3f", metrics$naive_sharpe), "` / `",
      sprintf("%.3f", metrics$autocorrelation_adjusted_sharpe), "`."),
    paste0("- TRAIN maximum drawdown: `",
      sprintf("%.2f%%", 100 * metrics$maximum_drawdown), "`."),
    "",
    "## Statistical diagnostics",
    "",
    paste0("- Static residual ADF t: `",
      sprintf("%.4f", diagnostics$static_residual_adf_t), "`."),
    paste0("- Dynamic-spread ADF t: `",
      sprintf("%.4f", diagnostics$dynamic_spread_adf_t), "`."),
    paste0("- Dynamic-spread AR(1) phi / half-life: `",
      sprintf("%.4f", diagnostics$dynamic_spread_phi), "` / `",
      sprintf("%.2f sessions", diagnostics$dynamic_spread_half_life), "`."),
    paste0("- Variance ratios q=5 / q=20: `",
      sprintf("%.4f", diagnostics$variance_ratio_5), "` / `",
      sprintf("%.4f", diagnostics$variance_ratio_20), "`."),
    paste0("- z versus forward-five spread return correlation: `",
      sprintf("%.4f", convergence$correlation), "`, 95% interval `[",
      sprintf("%.4f", convergence$lower_95), ", ",
      sprintf("%.4f", convergence$upper_95), "]`."),
    "",
    "These diagnostics answer different statistical questions. The frozen gate",
    "requires implemented, cost-aware convergence evidence as well as the",
    "forward relationship; no ADF statistic is treated as a trading verdict.",
    "",
    "## Gate decision",
    "",
    paste0("- TRAIN gates passed: `",
      sum(analysis$train_gates$status == "PASS"), " / ",
      nrow(analysis$train_gates), "`."),
    paste0("- Later outcomes opened: `", analysis$later_outcomes_opened, "`."),
    "- Do not change the pair, price transform, windows, thresholds, costs,",
    "  controls, or partitions after inspecting this run.",
    "",
    "## Run provenance",
    "",
    paste0("- Explicit as-of: `", run_spec$as_of_timestamp, "`."),
    paste0("- Feed: `", run_spec$feed, "`."),
    paste0("- Generic data health: `", run_spec$data_health_max_severity, "`."),
    paste0("- Frozen session coverage: `", run_spec$session_coverage_status, "`."),
    paste0("- Output: `", run_spec$output_dir, "`.")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("LIT-MR-02.1 frozen adaptive spread Bollinger POC starting.")
contract <- g5_mr02_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_MR02_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_MR02_REFRESH", FALSE)
run_id <- env_or("GEN5_MR02_RUN_ID", "lit_mr_02_1_bollinger_20260728")
as_of_timestamp <- env_or("GEN5_MR02_AS_OF_TIMESTAMP", contract$as_of_timestamp)
if (!identical(as_of_timestamp, contract$as_of_timestamp)) {
  stop("GEN5_MR02_AS_OF_TIMESTAMP must match the frozen contract.", call. = FALSE)
}

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = g5_mr02_required_symbols(contract),
  universe_name = "lit_mr_02_1_gld_uso",
  universe_roles = "pair_legs",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) stop("MR02 workbench query returned no bars.", call. = FALSE)
health_max <- g5_health_max_severity(query$health)
coverage <- g5_mr02_session_coverage_audit(query$bars, contract)
analysis_health <- if (
  !any(query$health$severity == "ERROR") &&
    all(coverage$status == "PASS")
) "PASS" else "FAIL"
analysis <- g5_mr02_run_analysis(
  query$bars,
  contract = contract,
  data_health_status = analysis_health
)

artifact_paths <- list(
  run_spec_csv = file.path(output_dir, "mr02_run_spec.csv"),
  contract_csv = file.path(output_dir, "mr02_frozen_contract.csv"),
  indicators_csv = file.path(output_dir, "mr02_train_indicators.csv"),
  replay_csv = file.path(output_dir, "mr02_train_bar_replay.csv"),
  trades_csv = file.path(output_dir, "mr02_train_trades.csv"),
  diagnostics_csv = file.path(output_dir, "mr02_train_statistical_diagnostics.csv"),
  convergence_csv = file.path(output_dir, "mr02_train_forward_convergence.csv"),
  convergence_summary_csv = file.path(output_dir, "mr02_train_forward_convergence_summary.csv"),
  bootstrap_summary_csv = file.path(output_dir, "mr02_train_trade_bootstrap_summary.csv"),
  bootstrap_draws_csv = file.path(output_dir, "mr02_train_trade_bootstrap_draws.csv"),
  random_distribution_csv = file.path(output_dir, "mr02_train_random_sign_distribution.csv"),
  year_summary_csv = file.path(output_dir, "mr02_train_year_summary.csv"),
  metrics_csv = file.path(output_dir, "mr02_train_performance_metrics.csv"),
  integrity_csv = file.path(output_dir, "mr02_integrity_audit.csv"),
  coverage_csv = file.path(output_dir, "mr02_session_coverage_audit.csv"),
  gates_csv = file.path(output_dir, "mr02_gate_summary.csv"),
  report_md = file.path(output_dir, "mr02_report.md"),
  signal_tape_png = file.path(visual_dir, "mr02_signal_tape.png"),
  trade_year_png = file.path(visual_dir, "mr02_trade_and_year_summary.png"),
  resampling_png = file.path(visual_dir, "mr02_resampling.png"),
  diagnostics_png = file.path(visual_dir, "mr02_statistical_diagnostics.png"),
  equity_drawdown_png = file.path(visual_dir, "mr02_train_equity_drawdown.png"),
  representative_trades_png = file.path(visual_dir, "mr02_representative_trades.png"),
  gates_png = file.path(visual_dir, "mr02_gate_summary.png")
)

if (analysis$later_outcomes_opened) {
  artifact_paths <- c(artifact_paths, list(
    full_indicators_csv = file.path(output_dir, "mr02_full_indicators.csv"),
    full_replay_csv = file.path(output_dir, "mr02_full_bar_replay.csv"),
    full_trades_csv = file.path(output_dir, "mr02_full_trades.csv"),
    later_metrics_csv = file.path(output_dir, "mr02_later_performance_metrics.csv"),
    confirmation_random_csv = file.path(output_dir, "mr02_confirmation_random_sign_distribution.csv")
  ))
}

run_spec <- data.frame(
  schema_version = g5_mr02_schema_version(),
  literature_id = contract$literature_id,
  wrapper = "literature_studies/scripts/run_gen5_lit_mr_02_1_bollinger_poc.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  session_coverage_status = analysis_health,
  query_start = contract$query_start,
  query_end = contract$query_end,
  signal = "raw_adjusted_price_spread_USO_minus_rolling_beta_times_GLD",
  timing = "after_close_signal_next_open_execution_and_rehedge",
  later_outcomes_opened = analysis$later_outcomes_opened,
  overall_status = analysis$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

contract_frame <- data.frame(
  literature_id = contract$literature_id,
  pair = "GLD-USO",
  transform = "raw_adjusted_price",
  hedge_model = "rolling_20_session_OLS_USO_on_GLD_with_intercept",
  traded_spread = "USO_minus_beta_times_GLD_intercept_not_subtracted",
  standardization = "rolling_20_session_sample_mean_and_sd",
  entry = "z_below_minus_1_long_spread,z_above_plus_1_short_spread",
  exit = "zero_crossing,no_same_close_reversal",
  sizing = "one_gross_normalized_unit,daily_next_open_adaptive_rehedge",
  primary_costs = "5bp_per_one_way_weight_change",
  stress_costs = "10bp_per_one_way_weight_change_plus_100bp_annual_short_gross",
  inference = "2000_trade_blocks_seed5801,2000_random_signs_seed5802,2000_convergence_blocks_seed5803",
  train = "2016-01-04_to_2020-12-31",
  development = "2021-01-01_to_2023-12-31",
  confirmation = "2024-01-01_to_2026-07-24",
  stringsAsFactors = FALSE
)

query_artifacts <- g5_write_workbench_query_artifacts(
  query, output_dir, "mr02_workbench_query"
)
write_csv(run_spec, artifact_paths$run_spec_csv)
write_csv(contract_frame, artifact_paths$contract_csv)
write_csv(analysis$train_indicators, artifact_paths$indicators_csv)
write_csv(analysis$train_replay, artifact_paths$replay_csv)
write_csv(analysis$train_trades, artifact_paths$trades_csv)
write_csv(analysis$train_diagnostics, artifact_paths$diagnostics_csv)
write_csv(analysis$train_convergence, artifact_paths$convergence_csv)
write_csv(
  analysis$train_convergence_bootstrap$summary,
  artifact_paths$convergence_summary_csv
)
write_csv(analysis$train_bootstrap$summary, artifact_paths$bootstrap_summary_csv)
write_csv(analysis$train_bootstrap$draws, artifact_paths$bootstrap_draws_csv)
write_csv(analysis$train_random$distribution, artifact_paths$random_distribution_csv)
write_csv(analysis$train_years, artifact_paths$year_summary_csv)
write_csv(analysis$train_metrics, artifact_paths$metrics_csv)
write_csv(analysis$train_integrity, artifact_paths$integrity_csv)
write_csv(analysis$train_coverage, artifact_paths$coverage_csv)
write_csv(analysis$gates, artifact_paths$gates_csv)

if (analysis$later_outcomes_opened) {
  write_csv(analysis$full_indicators, artifact_paths$full_indicators_csv)
  write_csv(analysis$full_replay, artifact_paths$full_replay_csv)
  write_csv(analysis$full_trades, artifact_paths$full_trades_csv)
  write_csv(analysis$later_metrics, artifact_paths$later_metrics_csv)
  write_csv(
    analysis$confirmation_random$distribution,
    artifact_paths$confirmation_random_csv
  )
}

plot_signal_tape(analysis, artifact_paths$signal_tape_png)
plot_trade_and_year_summary(analysis, artifact_paths$trade_year_png)
plot_resampling(analysis, artifact_paths$resampling_png)
plot_statistical_diagnostics(analysis, artifact_paths$diagnostics_png)
plot_equity_drawdown(analysis, artifact_paths$equity_drawdown_png)
plot_representative_trades(analysis, artifact_paths$representative_trades_png)
plot_gates(analysis, artifact_paths$gates_png)
write_report(
  artifact_paths$report_md,
  analysis,
  run_spec,
  c(artifact_paths, query_artifacts$paths)
)

message("LIT-MR-02.1 complete: ", analysis$overall_status)
message("Data health: ", health_max)
message("Later outcomes opened: ", analysis$later_outcomes_opened)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report_md, winslash = "/", mustWork = FALSE))
