# Run the frozen causal LIT-MOM-03.1 performance replay and controls.

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
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_03_1_dual_momentum_mechanics.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_03_1_dual_momentum_replay.R"
))
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
  if (!dir.exists(path)) stop("Could not create LIT-MOM-03.1 replay output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract_table <- function(contract) {
  data.frame(
    field = names(contract),
    value = vapply(contract, function(value) paste(value, collapse = ","), character(1)),
    stringsAsFactors = FALSE
  )
}

health_maximum <- function(health) {
  if (!nrow(health)) return("PASS")
  severity <- toupper(as.character(health$severity))
  rank <- c(PASS = 1L, INFO = 1L, WARN = 2L, ERROR = 3L)
  observed <- unname(rank[severity])
  observed[is.na(observed)] <- 3L
  names(rank)[which(rank == max(observed))[1L]]
}

variant_label <- function(x) {
  labels <- c(
    SOURCE_DUAL_MOMENTUM = "Source dual momentum",
    EQUAL_WEIGHT_ALL_NINE = "Equal-weight all nine",
    RELATIVE_ONLY = "Relative only",
    ABSOLUTE_ONLY = "Absolute only",
    SPY_OWNERSHIP = "SPY ownership",
    CASH_NO_TRADE = "Cash / no trade"
  )
  unname(labels[x])
}

variant_colors <- c(
  SOURCE_DUAL_MOMENTUM = "#101820",
  EQUAL_WEIGHT_ALL_NINE = "#3D8DFF",
  RELATIVE_ONLY = "#6DCBF4",
  ABSOLUTE_ONLY = "#2E7D5B",
  SPY_OWNERSHIP = "#C8553D",
  CASH_NO_TRADE = "#8B95A1"
)

targets_long <- function(targets, mechanics) {
  rows <- list()
  index <- 0L
  for (variant in names(targets)) {
    matrix_values <- targets[[variant]]
    for (column in colnames(matrix_values)) {
      index <- index + 1L
      rows[[index]] <- data.frame(
        variant = variant,
        decision_date = mechanics$allocations$decision_date,
        execution_date = mechanics$allocations$execution_date,
        symbol = column,
        target_weight = matrix_values[, column],
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

plot_wealth <- function(weekly_tape, contract, path) {
  variants <- contract$variants
  source <- weekly_tape[weekly_tape$variant == variants[[1L]], , drop = FALSE]
  range_values <- range(c(contract$initial_wealth, weekly_tape$wealth))
  png(path, width = 1800, height = 980, res = 150)
  old <- par(mar = c(5, 6, 5, 12), xpd = TRUE)
  on.exit({ par(old); dev.off() }, add = TRUE)
  plot(
    source$next_execution_date, source$wealth, type = "n", log = "y",
    ylim = range_values, xlab = "Execution interval end", ylab = "Growth of $1 (log scale)",
    main = "Dual momentum versus frozen controls - net of 5 bps one-way turnover cost"
  )
  for (variant in variants) {
    x <- weekly_tape[weekly_tape$variant == variant, , drop = FALSE]
    lines(x$next_execution_date, x$wealth, col = variant_colors[[variant]], lwd = if (variant == contract$source_variant) 3.5 else 2)
  }
  abline(h = 1, col = "#B8BCC4", lty = 3)
  legend(
    "topright", inset = c(-0.28, 0), legend = variant_label(variants),
    col = variant_colors[variants], lwd = c(3.5, rep(2, length(variants) - 1L)),
    bty = "n", cex = 0.86
  )
  mtext("Signals use completed Wednesday closes; portfolio changes occur at the next common-session open.", side = 3, line = 0.6, cex = 0.82)
}

plot_drawdowns <- function(weekly_tape, contract, path) {
  variants <- setdiff(contract$variants, "CASH_NO_TRADE")
  source <- weekly_tape[weekly_tape$variant == contract$source_variant, , drop = FALSE]
  png(path, width = 1800, height = 980, res = 150)
  old <- par(mar = c(5, 6, 5, 12), xpd = TRUE)
  on.exit({ par(old); dev.off() }, add = TRUE)
  plot(
    source$next_execution_date, source$drawdown, type = "n",
    ylim = c(min(weekly_tape$drawdown), 0), xlab = "Execution interval end", ylab = "Drawdown",
    main = "Drawdown paths expose the price of staying invested"
  )
  for (variant in variants) {
    x <- weekly_tape[weekly_tape$variant == variant, , drop = FALSE]
    lines(x$next_execution_date, x$drawdown, col = variant_colors[[variant]], lwd = if (variant == contract$source_variant) 3.5 else 2)
  }
  abline(h = 0, col = "#B8BCC4")
  legend(
    "bottomright", inset = c(-0.28, 0), legend = variant_label(variants),
    col = variant_colors[variants], lwd = c(3.5, rep(2, length(variants) - 1L)),
    bty = "n", cex = 0.86
  )
}

plot_risk_return <- function(metrics, contract, path) {
  variants <- setdiff(contract$variants, "CASH_NO_TRADE")
  x <- metrics[match(variants, metrics$variant), , drop = FALSE]
  png(path, width = 1600, height = 980, res = 150)
  old <- par(mar = c(6, 7, 5, 3))
  on.exit({ par(old); dev.off() }, add = TRUE)
  plot(
    -100 * x$max_drawdown, 100 * x$cagr_net,
    xlab = "Maximum drawdown magnitude (%)", ylab = "Net CAGR (%)",
    main = "Return and drawdown must be judged together", type = "n",
    xlim = range(-100 * x$max_drawdown) + c(-2, 4),
    ylim = range(100 * x$cagr_net) + c(-2, 2)
  )
  point_x <- -100 * x$max_drawdown
  point_y <- 100 * x$cagr_net
  points(point_x, point_y, pch = 19, cex = 1.7, col = variant_colors[x$variant])
  source_index <- which(x$variant == contract$source_variant)
  points(point_x[source_index], point_y[source_index], pch = 1, cex = 2.35, lwd = 2.2, col = "#101820")
  label_x <- point_x + c(0.5, 0.5, 0.5, 0.5, 0.5)
  label_y <- point_y
  label_y[x$variant == "SOURCE_DUAL_MOMENTUM"] <- point_y[x$variant == "SOURCE_DUAL_MOMENTUM"] - 0.38
  label_y[x$variant == "RELATIVE_ONLY"] <- point_y[x$variant == "RELATIVE_ONLY"] + 0.38
  text(label_x, label_y, labels = variant_label(x$variant), pos = 4, cex = 0.82, offset = 0)
  mtext("Source and relative-only results overlap almost exactly.", side = 3, line = 0.6, cex = 0.82)
  grid(col = "#D7DCE5")
}

plot_yearly <- function(calendar_years, contract, path) {
  variants <- setdiff(contract$variants, "CASH_NO_TRADE")
  years <- sort(unique(calendar_years$calendar_year))
  matrix_values <- sapply(variants, function(variant) {
    x <- calendar_years[calendar_years$variant == variant, , drop = FALSE]
    x$net_return[match(years, x$calendar_year)]
  })
  png(path, width = 1800, height = 980, res = 150)
  old <- par(mar = c(6, 6, 5, 12), xpd = TRUE)
  on.exit({ par(old); dev.off() }, add = TRUE)
  matplot(
    years, 100 * matrix_values, type = "o", lty = 1, pch = 19,
    col = variant_colors[variants], lwd = c(3.5, rep(2, length(variants) - 1L)),
    xlab = "Calendar year", ylab = "Net return within observed weekly intervals (%)",
    main = "Calendar-year behavior reveals whether value-add was persistent"
  )
  abline(h = 0, col = "#B8BCC4", lty = 3)
  legend(
    "topright", inset = c(-0.28, 0), legend = variant_label(variants),
    col = variant_colors[variants], lwd = c(3.5, rep(2, length(variants) - 1L)),
    pch = 19, bty = "n", cex = 0.86
  )
}

write_report <- function(run_spec, replay, paths) {
  metrics <- replay$metrics
  source <- metrics[metrics$variant == replay$contract$source_variant, , drop = FALSE]
  comparison_lines <- vapply(seq_len(nrow(replay$comparisons)), function(i) {
    row <- replay$comparisons[i, ]
    paste0(
      "- Versus `", row$comparator_variant, "`: CAGR difference `",
      sprintf("%+.2f pp", 100 * row$cagr_difference), "`; mean weekly difference `",
      sprintf("%+.3f%%", 100 * row$mean_weekly_difference), "` with 95% block-bootstrap interval `[",
      sprintf("%+.3f%%", 100 * row$block_bootstrap_ci_low), ", ",
      sprintf("%+.3f%%", 100 * row$block_bootstrap_ci_high), "]`; BH q=`",
      sprintf("%.3f", row$bh_q_value), "`."
    )
  }, character(1))
  metric_lines <- vapply(seq_len(nrow(metrics)), function(i) {
    row <- metrics[i, ]
    paste0(
      "- `", row$variant, "`: ending wealth `", sprintf("%.3f", row$ending_wealth_net),
      "`; CAGR `", sprintf("%.2f%%", 100 * row$cagr_net), "`; max drawdown `",
      sprintf("%.2f%%", 100 * row$max_drawdown), "`; annualized volatility `",
      sprintf("%.2f%%", 100 * row$annualized_volatility), "`; turnover `",
      sprintf("%.2fx/year", row$annualized_one_way_turnover), "`."
    )
  }, character(1))
  lines <- c(
    "# LIT-MOM-03.1 causal dual-momentum replay",
    "",
    "## Question",
    "",
    "Did the source-described combination of relative ranking and absolute permission add economic value in the clean 2016-2026 local window after causal next-open execution and modest turnover costs?",
    "",
    "## Frozen accounting",
    "",
    "- Signal: completed Wednesday close; execution and rebalance: next complete common-session open.",
    "- Outcome: open-to-open return until the next weekly execution. The final unmatched target is excluded.",
    "- Accounting: drifted pretrade weights, self-financing weekly rebalance, cash return fixed at zero.",
    "- Cost: 5 bps per one-way traded notional, where turnover is one-half the L1 distance including cash.",
    "- Controls: cash, weekly equal-weight all nine, relative-only top-three sleeves, absolute-only fixed asset shares, and continuous SPY ownership.",
    "",
    "## Portfolio results",
    "",
    metric_lines,
    "",
    "## Source-minus-control comparisons",
    "",
    comparison_lines,
    "",
    "The confidence intervals use 5,000 moving-block bootstrap draws with eight-week blocks. BH correction covers the five frozen source-minus-control comparisons. These diagnostics describe this retrospective window; they do not create untouched confirmation evidence.",
    "",
    "## Evidence boundary",
    "",
    paste0("- Status: `", run_spec$overall_status, "`."),
    paste0("- Source ending wealth: `", sprintf("%.3f", source$ending_wealth_net), "`; net CAGR: `", sprintf("%.2f%%", 100 * source$cagr_net), "`; maximum drawdown: `", sprintf("%.2f%%", 100 * source$max_drawdown), "`."),
    "- The publisher's 2008-2015 segment remains unavailable under the current Alpaca account and was not imputed or replaced.",
    "- No parameter search, alternative universe, leverage, forward test, robustness gate, or live decision was opened.",
    "",
    "## Artifacts",
    "",
    paste0("- Metrics: `", basename(paths$metrics), "`."),
    paste0("- Weekly portfolio tape: `", basename(paths$weekly_tape), "`."),
    paste0("- Frozen comparisons: `", basename(paths$comparisons), "`."),
    paste0("- Calendar years and phases: `", basename(paths$calendar_years), "`, `", basename(paths$phases), "`."),
    paste0("- Source contribution and representative weeks: `", basename(paths$source_contribution), "`, `", basename(paths$representative_weeks), "`."),
    "",
    "## Next decision",
    "",
    "Interpret the source rule against every frozen comparator and across time. Any robustness or forward slice must be separately frozen; this replay cannot by itself promote the rule to edge."
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("LIT-MOM-03.1 causal performance replay starting.")
mechanics_contract <- g5_mom031_contract()
replay_contract <- g5_mom031r_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_03_1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_03_1_REPLAY_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_03_1_REPLAY_RUN_ID",
  "lit_mom_03_1_dual_momentum_replay_20260902"
)
output_dir <- file.path(repo_root, "runs", "research_workbench", "literature_grounded", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = mechanics_contract$query_start,
  end_date = mechanics_contract$signal_end,
  as_of_timestamp = mechanics_contract$as_of_timestamp,
  symbols = mechanics_contract$universe,
  universe_name = "lit_mom_03_1_source_nine_etf_universe",
  universe_roles = "source_replay_assets",
  refresh = refresh,
  repo_root = repo_root
)
invisible(g5_write_workbench_query_artifacts(query, output_dir, "mom031r_workbench_query"))
health_max <- health_maximum(query$health)
if (health_max %in% c("WARN", "ERROR")) {
  stop(paste("LIT-MOM-03.1 replay data admission stopped at", health_max), call. = FALSE)
}

mechanics <- g5_mom031_run(query$bars, mechanics_contract)
replay <- g5_mom031r_run(mechanics, replay_contract)
source_metrics <- replay$metrics[replay$metrics$variant == replay_contract$source_variant, , drop = FALSE]
non_cash_controls <- replay$metrics[replay$metrics$variant %in% setdiff(replay_contract$comparator_variants, "CASH_NO_TRADE"), , drop = FALSE]
controls_beaten_on_cagr <- sum(source_metrics$cagr_net > non_cash_controls$cagr_net)
positive_ci_comparisons <- sum(replay$comparisons$ci_excludes_zero_positive)

run_spec <- data.frame(
  schema_version = g5_mom031r_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_03_1_dual_momentum_replay.R",
  run_id = run_id,
  as_of_timestamp = mechanics_contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  weekly_intervals = nrow(replay$intervals$metadata),
  first_execution_date = min(replay$intervals$metadata$execution_date),
  last_execution_date = max(replay$intervals$metadata$next_execution_date),
  cost_bps_one_way = replay_contract$cost_bps_one_way,
  frozen_comparators = length(replay_contract$comparator_variants),
  non_cash_controls_beaten_on_cagr = controls_beaten_on_cagr,
  positive_ci_comparisons = positive_ci_comparisons,
  source_ending_wealth = source_metrics$ending_wealth_net,
  source_cagr = source_metrics$cagr_net,
  source_max_drawdown = source_metrics$max_drawdown,
  robustness_or_forward_gate_opened = replay_contract$robustness_or_forward_gate_opened,
  published_window_blocked = TRUE,
  overall_status = "RETROSPECTIVE_VALUE_ADD_REPLAY_COMPLETE_NO_ROBUSTNESS_OR_FORWARD_AUTHORITY",
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "mom031r_run_spec.csv"),
  mechanics_contract = file.path(output_dir, "mom031r_mechanics_contract.csv"),
  replay_contract = file.path(output_dir, "mom031r_replay_contract.csv"),
  mechanics_integrity = file.path(output_dir, "mom031r_mechanics_integrity.csv"),
  replay_integrity = file.path(output_dir, "mom031r_replay_integrity.csv"),
  targets = file.path(output_dir, "mom031r_targets_long.csv"),
  weekly_tape = file.path(output_dir, "mom031r_weekly_portfolio_tape.csv"),
  contributions = file.path(output_dir, "mom031r_weekly_asset_contributions.csv"),
  metrics = file.path(output_dir, "mom031r_portfolio_metrics.csv"),
  comparisons = file.path(output_dir, "mom031r_source_control_comparisons.csv"),
  calendar_years = file.path(output_dir, "mom031r_calendar_years.csv"),
  phases = file.path(output_dir, "mom031r_phases.csv"),
  source_contribution = file.path(output_dir, "mom031r_source_asset_contribution.csv"),
  representative_weeks = file.path(output_dir, "mom031r_representative_weeks.csv"),
  wealth_png = file.path(visual_dir, "mom031r_growth_of_one.png"),
  drawdown_png = file.path(visual_dir, "mom031r_drawdowns.png"),
  risk_return_png = file.path(visual_dir, "mom031r_risk_return.png"),
  yearly_png = file.path(visual_dir, "mom031r_calendar_years.png"),
  report = file.path(output_dir, "mom031r_report.md")
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(mechanics_contract), paths$mechanics_contract)
write_csv(contract_table(replay_contract), paths$replay_contract)
write_csv(mechanics$integrity, paths$mechanics_integrity)
write_csv(replay$integrity, paths$replay_integrity)
write_csv(targets_long(replay$targets, mechanics), paths$targets)
write_csv(replay$weekly_tape, paths$weekly_tape)
write_csv(replay$contributions, paths$contributions)
write_csv(replay$metrics, paths$metrics)
write_csv(replay$comparisons, paths$comparisons)
write_csv(replay$calendar_years, paths$calendar_years)
write_csv(replay$phases, paths$phases)
write_csv(replay$source_contribution, paths$source_contribution)
write_csv(replay$representative_weeks, paths$representative_weeks)
plot_wealth(replay$weekly_tape, replay_contract, paths$wealth_png)
plot_drawdowns(replay$weekly_tape, replay_contract, paths$drawdown_png)
plot_risk_return(replay$metrics, replay_contract, paths$risk_return_png)
plot_yearly(replay$calendar_years, replay_contract, paths$yearly_png)
write_report(run_spec, replay, paths)

message("LIT-MOM-03.1 causal performance replay complete.")
message("Status: ", run_spec$overall_status)
message("Data health: ", health_max)
message("Weekly intervals: ", run_spec$weekly_intervals)
message("Source ending wealth: ", sprintf("%.3f", source_metrics$ending_wealth_net))
message("Source CAGR: ", sprintf("%.2f%%", 100 * source_metrics$cagr_net))
message("Source max drawdown: ", sprintf("%.2f%%", 100 * source_metrics$max_drawdown))
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
