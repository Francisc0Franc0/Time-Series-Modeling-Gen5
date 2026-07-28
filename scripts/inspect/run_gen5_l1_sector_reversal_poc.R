# Run the frozen Gen5 L1 long-short sector-reversal POC.

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
source(file.path(repo_root, "R", "gen5_l1_sector_reversal_poc.R"))
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
  if (!dir.exists(path)) stop("Could not create L1 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

l1_period_colors <- c(
  TRAIN = "#64748B",
  DEVELOPMENT = "#3D8DFF",
  CONFIRMATION = "#8B5CF6"
)

plot_train_stability <- function(analysis, path) {
  x <- analysis$train_cohorts
  years <- analysis$train_years
  png(path, width = 2100, height = 1250, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  plot(
    x$execution_date,
    x$rank_ic,
    type = "h",
    lwd = 2,
    col = ifelse(x$rank_ic < 0, "#177245", "#B42318"),
    xlab = "",
    ylab = "Spearman rank IC",
    main = "TRAIN mechanism: negative rank IC means loser-to-winner reversal"
  )
  abline(h = 0, col = "#0F172A")
  abline(h = mean(x$rank_ic), col = "#3D8DFF", lwd = 3)
  bars <- barplot(
    10000 * years$mean_net_return,
    names.arg = years$calendar_year,
    col = ifelse(years$mean_net_return > 0, "#177245", "#B42318"),
    ylab = "Mean net portfolio return (bp/cohort)",
    main = "Primary costs included: positive years are required for stability"
  )
  abline(h = 0, col = "#0F172A")
  text(
    bars,
    10000 * years$mean_net_return,
    sprintf("%.1f", 10000 * years$mean_net_return),
    pos = ifelse(years$mean_net_return >= 0, 3, 1),
    cex = 0.8
  )
  par(old)
  dev.off()
}

plot_train_resampling <- function(analysis, path) {
  draws <- analysis$train_bootstrap$draws
  random <- analysis$train_random$distribution$mean_net_return
  observed <- mean(analysis$train_cohorts$net_portfolio_return)
  png(path, width = 2100, height = 1000, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(6, 6, 4, 2))
  hist(
    10000 * draws$net_portfolio_return,
    breaks = 40,
    col = "#D0EDFA",
    border = "white",
    xlab = "Bootstrap mean net return (bp/cohort)",
    main = "Moving-block uncertainty"
  )
  abline(v = 0, col = "#B42318", lwd = 2)
  abline(v = 10000 * observed, col = "#3D8DFF", lwd = 4)
  hist(
    10000 * random,
    breaks = 40,
    col = "#E2E8F0",
    border = "white",
    xlab = "Random-policy mean net return (bp/cohort)",
    main = "Frozen rank versus random long-short policies"
  )
  abline(v = 10000 * analysis$train_random$p90, col = "#F59E0B", lwd = 3, lty = 2)
  abline(v = 10000 * observed, col = "#3D8DFF", lwd = 4)
  legend(
    "topright",
    c(
      sprintf("Observed %.2f bp", 10000 * observed),
      sprintf("Random p90 %.2f bp", 10000 * analysis$train_random$p90)
    ),
    col = c("#3D8DFF", "#F59E0B"),
    lty = c(1, 2),
    lwd = c(4, 3),
    bty = "n"
  )
  par(old)
  dev.off()
}

plot_directional_scorecard <- function(analysis, path) {
  score <- if (analysis$l1b_run) {
    analysis$direction_by_period
  } else {
    analysis$train_direction$scorecard
  }
  metrics <- c(
    "raw_direction_accuracy",
    "long_call_precision",
    "short_call_precision",
    "balanced_accuracy"
  )
  labels <- c("Raw accuracy", "Long calls up", "Short calls down", "Balanced accuracy")
  values <- do.call(rbind, lapply(metrics, function(metric) {
    as.numeric(score[[metric]])
  }))
  rownames(values) <- labels
  colnames(values) <- score$evaluation_period
  png(path, width = 1900, height = 1000, res = 150)
  old <- par(mar = c(6, 7, 4, 2))
  bars <- barplot(
    100 * values,
    beside = TRUE,
    names.arg = labels,
    col = l1_period_colors[colnames(values)],
    ylim = c(0, 100),
    ylab = "Percent",
    main = "Absolute up/down prediction is reported separately from spread profit"
  )
  abline(h = 50, col = "#B42318", lty = 2)
  legend(
    "topright",
    legend = colnames(values),
    fill = l1_period_colors[colnames(values)],
    bty = "n"
  )
  text(bars, 100 * values, sprintf("%.1f", 100 * values), pos = 3, cex = 0.7)
  par(old)
  dev.off()
}

representative_cohorts <- function(analysis, count = 6L) {
  x <- if (analysis$l1b_run) {
    analysis$primary_cohorts[
      analysis$primary_cohorts$evaluation_period == "CONFIRMATION",
      ,
      drop = FALSE
    ]
  } else {
    analysis$train_cohorts
  }
  x <- x[order(x$net_portfolio_return), , drop = FALSE]
  indices <- unique(round(seq(1, nrow(x), length.out = min(count, nrow(x)))))
  x[indices, , drop = FALSE]
}

plot_representative_cohorts <- function(analysis, path) {
  chosen <- representative_cohorts(analysis)
  panel <- if (analysis$l1b_run) analysis$full_panel else analysis$train_panel
  png(path, width = 2250, height = 1450, res = 150)
  old <- par(mfrow = c(2, 3), mar = c(7, 5, 4, 2))
  for (i in seq_len(6L)) {
    if (i > nrow(chosen)) {
      plot.new()
      next
    }
    cohort <- chosen[i, , drop = FALSE]
    part <- panel[panel$cohort_id == cohort$cohort_id, , drop = FALSE]
    part <- part[order(part$rank), , drop = FALSE]
    values <- rbind(
      `Past 5 sessions` = 100 * part$signal_return,
      `Future 5 sessions` = 100 * part$future_return
    )
    barplot(
      values,
      beside = TRUE,
      names.arg = part$symbol,
      las = 2,
      col = c("#64748B", "#3D8DFF"),
      ylab = "Return (%)",
      main = sprintf(
        "%s | net %.1f bp\nLong %s | Short %s",
        cohort$execution_date,
        10000 * cohort$net_portfolio_return,
        cohort$long_symbols,
        cohort$short_symbols
      ),
      cex.names = 0.75
    )
    abline(h = 0, col = "#0F172A")
    if (i == 1L) {
      legend(
        "topleft",
        legend = rownames(values),
        fill = c("#64748B", "#3D8DFF"),
        bty = "n",
        cex = 0.8
      )
    }
  }
  par(old)
  dev.off()
}

plot_equity_drawdown <- function(analysis, path) {
  png(path, width = 2000, height = 1100, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  if (!analysis$l1b_run) {
    plot.new()
    text(0.5, 0.62, "Portfolio replay structurally not run", cex = 1.7, font = 2)
    text(0.5, 0.35, "TRAIN mechanism gates did not all pass", cex = 1.1)
    plot.new()
    text(0.5, 0.5, "No Sharpe, drawdown, trade PnL, or equity claim", cex = 1.3)
  } else {
    x <- analysis$primary_daily_replay
    x <- x[x$evaluation_period == "CONFIRMATION", , drop = FALSE]
    plot(
      x$period_end_date,
      x$wealth,
      type = "l",
      lwd = 3,
      col = "#3D8DFF",
      xlab = "",
      ylab = "Wealth per $1",
      main = "Conditional CONFIRMATION bar-by-bar replay at primary costs"
    )
    abline(h = 1, col = "#94A3B8", lty = 2)
    plot(
      x$period_end_date,
      100 * x$drawdown,
      type = "h",
      lwd = 2,
      col = "#B42318",
      xlab = "",
      ylab = "Drawdown (%)",
      main = "Drawdown depth and duration remain distinct"
    )
    abline(h = 0, col = "#0F172A")
  }
  par(old)
  dev.off()
}

plot_gates <- function(analysis, path) {
  gates <- analysis$gates
  png(path, width = 2100, height = 1250, res = 150)
  old <- par(mar = c(4, 22, 4, 3))
  y <- rev(seq_len(nrow(gates)))
  plot(
    c(0, 1),
    c(0.5, nrow(gates) + 0.5),
    type = "n",
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = paste("L1 frozen verdict:", analysis$overall_status)
  )
  axis(2, at = y, labels = gates$gate, las = 1, cex.axis = 0.72)
  colors <- ifelse(
    gates$status == "PASS",
    "#177245",
    ifelse(gates$status == "FAIL", "#B42318", "#64748B")
  )
  for (i in seq_len(nrow(gates))) {
    rect(0.28, y[[i]] - 0.27, 0.42, y[[i]] + 0.27, col = colors[[i]], border = NA)
  }
  text(
    rep(0.35, nrow(gates)),
    y,
    labels = gsub("_", " ", gates$status),
    col = "white",
    font = 2,
    cex = 0.48
  )
  text(rep(0.48, nrow(gates)), y, labels = gates$value, pos = 4, cex = 0.70)
  par(old)
  dev.off()
}

write_report <- function(path, analysis, run_spec, artifact_paths) {
  gates <- analysis$gates
  failed <- gates$gate_id[gates$status == "FAIL"]
  train_boot <- analysis$train_bootstrap$summary
  train_ic <- train_boot[train_boot$metric == "rank_ic", , drop = FALSE]
  train_net <- train_boot[train_boot$metric == "net_portfolio_return", , drop = FALSE]
  train_direction <- analysis$train_direction$scorecard
  lines <- c(
    "# Gen5 L1 Long-Short Sector-Reversal POC",
    "",
    paste0("**Frozen verdict:** `", analysis$overall_status, "`"),
    "",
    "## Frozen question",
    "",
    "Do the two weakest five-session U.S. sector ETFs subsequently outperform the two strongest over the next five sessions under a fixed dollar-neutral long-short rule?",
    "",
    "## TRAIN-first mechanism readout",
    "",
    paste0("- TRAIN cohorts: `", nrow(analysis$train_cohorts), "`."),
    paste0("- Mean rank IC: `", sprintf("%.6f", mean(analysis$train_cohorts$rank_ic)),
      "`; block-bootstrap 95% interval `", sprintf("[%.6f, %.6f]", train_ic$ci_lower, train_ic$ci_upper), "`."),
    paste0("- Mean primary-cost net return: `", sprintf("%.2f bp/cohort", 10000 * mean(analysis$train_cohorts$net_portfolio_return)),
      "`; block-bootstrap 95% interval `", sprintf("[%.2f, %.2f] bp", 10000 * train_net$ci_lower, 10000 * train_net$ci_upper), "`."),
    paste0("- Spread-direction hit rate: `", sprintf("%.1f%%", 100 * mean(analysis$train_cohorts$spread_direction_correct)), "`."),
    paste0("- Random-policy p90: `", sprintf("%.2f bp/cohort", 10000 * analysis$train_random$p90), "`."),
    "",
    "## Direction is not the same as spread profit",
    "",
    paste0("- Absolute direction accuracy: `", sprintf("%.1f%%", 100 * train_direction$raw_direction_accuracy), "`."),
    paste0("- Long calls that rose: `", sprintf("%.1f%%", 100 * train_direction$long_call_precision), "`."),
    paste0("- Short calls that fell: `", sprintf("%.1f%%", 100 * train_direction$short_call_precision), "`."),
    paste0("- Balanced accuracy: `", sprintf("%.1f%%", 100 * train_direction$balanced_accuracy), "`."),
    "",
    "## Frozen gates",
    "",
    paste0("- **", gates$gate_id, " ", gates$gate, ": ", gates$status, "** - ", gates$value),
    "",
    "## Interpretation boundary",
    "",
    if (!analysis$l1b_run) {
      "L1A stopped before DEVELOPMENT, CONFIRMATION, portfolio replay, Sharpe, drawdown, and trade PnL. The inspected TRAIN result must not be rescued by changing the universe, horizon, rank count, costs, cadence, seeds, or gates."
    } else if (identical(
      analysis$overall_status,
      "PASS_L1_TO_PROSPECTIVE_BORROW_SHADOW_DISCUSSION"
    )) {
      "L1 passes only to an operator discussion of prospective borrow monitoring. Historical adjusted bars do not prove borrow availability, and this packet does not authorize live advice or execution."
    } else {
      "L1B failed replication or economic gates. Do not rescue it by changing the frozen contract after inspecting later outcomes."
    },
    "",
    "## Run authority",
    "",
    paste0("- As of: `", run_spec$as_of_timestamp, "`."),
    paste0("- Feed: `", run_spec$feed, "`."),
    paste0("- Generic data health: `", run_spec$data_health_max_severity, "`."),
    paste0("- Frozen session coverage: `", run_spec$session_coverage_status, "`."),
    paste0("- Later outcomes opened: `", run_spec$later_outcomes_opened, "`."),
    paste0("- Output: `", run_spec$output_dir, "`."),
    "",
    "## Key artifacts",
    "",
    paste0("- `", names(artifact_paths), "`: `",
      normalizePath(unlist(artifact_paths), winslash = "/", mustWork = FALSE), "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("Gen5 L1 frozen long-short sector-reversal POC starting.")
contract <- g5_l1_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_L1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_L1_REFRESH", FALSE)
run_id <- env_or("GEN5_L1_RUN_ID", "l1_sector_reversal_20260728")
as_of_timestamp <- env_or("GEN5_L1_AS_OF_TIMESTAMP", contract$as_of_timestamp)
if (!identical(as_of_timestamp, contract$as_of_timestamp)) {
  stop("GEN5_L1_AS_OF_TIMESTAMP must match the frozen contract.", call. = FALSE)
}
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "retail_quant_mechanisms", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = g5_l1_required_symbols(contract),
  universe_name = "gen5_l1_frozen_sector_reversal",
  universe_roles = "nine_sector_etfs,spy_context_only",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) stop("L1 workbench query returned no bars.", call. = FALSE)
health_max <- g5_health_max_severity(query$health)
coverage <- g5_l1_session_coverage_audit(query$bars, contract)
analysis_health <- if (
  !any(query$health$severity == "ERROR") &&
    all(coverage$status == "PASS")
) "PASS" else "FAIL"
analysis <- g5_l1_run_analysis(
  query$bars,
  contract = contract,
  data_health_status = analysis_health
)

artifact_paths <- list(
  run_spec_csv = file.path(output_dir, "l1_run_spec.csv"),
  contract_csv = file.path(output_dir, "l1_frozen_contract.csv"),
  train_panel_csv = file.path(output_dir, "l1_train_panel.csv"),
  train_cohorts_csv = file.path(output_dir, "l1_train_cohorts.csv"),
  train_bootstrap_summary_csv = file.path(output_dir, "l1_train_bootstrap_summary.csv"),
  train_bootstrap_draws_csv = file.path(output_dir, "l1_train_bootstrap_draws.csv"),
  train_random_distribution_csv = file.path(output_dir, "l1_train_random_policy_distribution.csv"),
  train_year_summary_csv = file.path(output_dir, "l1_train_year_summary.csv"),
  train_direction_scorecard_csv = file.path(output_dir, "l1_train_direction_scorecard.csv"),
  train_direction_confusion_csv = file.path(output_dir, "l1_train_direction_confusion.csv"),
  integrity_csv = file.path(output_dir, "l1_integrity_audit.csv"),
  coverage_csv = file.path(output_dir, "l1_session_coverage_audit.csv"),
  gates_csv = file.path(output_dir, "l1_gate_summary.csv"),
  report_md = file.path(output_dir, "l1_report.md"),
  train_stability_png = file.path(visual_dir, "l1_train_stability.png"),
  train_resampling_png = file.path(visual_dir, "l1_train_resampling.png"),
  direction_png = file.path(visual_dir, "l1_directional_scorecard.png"),
  representative_png = file.path(visual_dir, "l1_representative_cohorts.png"),
  equity_drawdown_png = file.path(visual_dir, "l1_equity_drawdown.png"),
  gates_png = file.path(visual_dir, "l1_gate_summary.png")
)

if (analysis$l1b_run) {
  artifact_paths <- c(artifact_paths, list(
    full_panel_csv = file.path(output_dir, "l1_full_panel.csv"),
    primary_cohorts_csv = file.path(output_dir, "l1_primary_cohorts.csv"),
    stress_cohorts_csv = file.path(output_dir, "l1_stress_cohorts.csv"),
    direction_by_period_csv = file.path(output_dir, "l1_direction_by_period.csv"),
    direction_confusion_by_period_csv = file.path(output_dir, "l1_direction_confusion_by_period.csv"),
    year_summary_csv = file.path(output_dir, "l1_year_summary.csv"),
    confirmation_random_distribution_csv = file.path(output_dir, "l1_confirmation_random_policy_distribution.csv"),
    primary_daily_replay_csv = file.path(output_dir, "l1_primary_daily_replay.csv"),
    stress_daily_replay_csv = file.path(output_dir, "l1_stress_daily_replay.csv"),
    confirmation_metrics_csv = file.path(output_dir, "l1_confirmation_performance_metrics.csv"),
    attribution_csv = file.path(output_dir, "l1_confirmation_attribution.csv")
  ))
}

run_spec <- data.frame(
  schema_version = g5_l1_schema_version(),
  wrapper = "scripts/inspect/run_gen5_l1_sector_reversal_poc.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  session_coverage_status = analysis_health,
  query_start = contract$query_start,
  query_end = contract$query_end,
  universe_size = nrow(contract$universe),
  lookback_sessions = contract$lookback_sessions,
  holding_sessions = contract$holding_sessions,
  long_count = contract$long_count,
  short_count = contract$short_count,
  gross_exposure = contract$long_gross + contract$short_gross,
  net_exposure = contract$long_gross - contract$short_gross,
  primary_cost_bps = contract$primary_cost_bps,
  stress_cost_bps = contract$stress_cost_bps,
  stress_borrow_bps_annual = contract$stress_borrow_bps_annual,
  historical_borrow_availability_imputed = FALSE,
  later_outcomes_opened = analysis$l1b_run,
  overall_status = analysis$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
contract_frame <- data.frame(
  universe = paste(contract$universe$symbol, collapse = ","),
  benchmark = contract$benchmark,
  signal = "rank_trailing_5_session_adjusted_close_return",
  positions = "long_bottom_2_short_top_2_equal_25pct_legs",
  timing = "after_close_signal_next_open_entry_five_session_exit",
  cadence = "nonoverlapping_return_intervals_partition_anchored",
  primary_estimands = "spearman_rank_ic,long_minus_short_spread",
  primary_costs = "5bp_one_way_zero_historical_borrow_fee",
  stress_costs = "10bp_one_way_plus_100bp_annual_on_50pct_short_gross",
  inference = "2000_moving_block_bootstrap_seed_5701,2000_random_policies_seed_5702",
  train = "2016-01-04_to_2020-12-31",
  development = "2021-01-01_to_2023-12-31",
  confirmation = "2024-01-01_to_2026-07-24",
  stringsAsFactors = FALSE
)

query_artifacts <- g5_write_workbench_query_artifacts(
  query, output_dir, "l1_workbench_query"
)
write_csv(run_spec, artifact_paths$run_spec_csv)
write_csv(contract_frame, artifact_paths$contract_csv)
write_csv(analysis$train_panel, artifact_paths$train_panel_csv)
write_csv(analysis$train_cohorts, artifact_paths$train_cohorts_csv)
write_csv(analysis$train_bootstrap$summary, artifact_paths$train_bootstrap_summary_csv)
write_csv(analysis$train_bootstrap$draws, artifact_paths$train_bootstrap_draws_csv)
write_csv(analysis$train_random$distribution, artifact_paths$train_random_distribution_csv)
write_csv(analysis$train_years, artifact_paths$train_year_summary_csv)
write_csv(analysis$train_direction$scorecard, artifact_paths$train_direction_scorecard_csv)
write_csv(analysis$train_direction$confusion, artifact_paths$train_direction_confusion_csv)
write_csv(analysis$integrity, artifact_paths$integrity_csv)
write_csv(analysis$session_coverage, artifact_paths$coverage_csv)
write_csv(analysis$gates, artifact_paths$gates_csv)

if (analysis$l1b_run) {
  write_csv(analysis$full_panel, artifact_paths$full_panel_csv)
  write_csv(analysis$primary_cohorts, artifact_paths$primary_cohorts_csv)
  write_csv(analysis$stress_cohorts, artifact_paths$stress_cohorts_csv)
  write_csv(analysis$direction_by_period, artifact_paths$direction_by_period_csv)
  write_csv(analysis$direction_confusion, artifact_paths$direction_confusion_by_period_csv)
  write_csv(analysis$year_summary, artifact_paths$year_summary_csv)
  write_csv(
    analysis$confirmation_random$distribution,
    artifact_paths$confirmation_random_distribution_csv
  )
  write_csv(analysis$primary_daily_replay, artifact_paths$primary_daily_replay_csv)
  write_csv(analysis$stress_daily_replay, artifact_paths$stress_daily_replay_csv)
  write_csv(analysis$confirmation_metrics, artifact_paths$confirmation_metrics_csv)
  write_csv(analysis$attribution, artifact_paths$attribution_csv)
}

plot_train_stability(analysis, artifact_paths$train_stability_png)
plot_train_resampling(analysis, artifact_paths$train_resampling_png)
plot_directional_scorecard(analysis, artifact_paths$direction_png)
plot_representative_cohorts(analysis, artifact_paths$representative_png)
plot_equity_drawdown(analysis, artifact_paths$equity_drawdown_png)
plot_gates(analysis, artifact_paths$gates_png)
write_report(
  artifact_paths$report_md,
  analysis,
  run_spec,
  c(artifact_paths, query_artifacts$paths)
)

message("Gen5 L1 complete: ", analysis$overall_status)
message("Data health: ", health_max)
message("Later outcomes opened: ", analysis$l1b_run)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report_md, winslash = "/", mustWork = FALSE))
