# Gen5 M1 frozen cross-sectional momentum POC.
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
source(file.path(repo_root, "R", "gen5_m1_cross_sectional_momentum_poc.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create M1 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

m1_period_boundaries <- as.Date(c("2022-01-01", "2025-01-01"))
m1_group_colors <- c(
  us_sector = "#3D8DFF",
  developed_country = "#8B5CF6",
  emerging_country = "#F59E0B"
)

plot_eligibility_coverage <- function(analysis, path) {
  panel <- analysis$primary_panel
  one <- panel[!duplicated(panel$decision_date), , drop = FALSE]
  png(path, width = 1900, height = 1050, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  plot(
    one$decision_date, one$eligible_count,
    type = "s", lwd = 2.5, col = "#0F172A", ylim = c(0, 24),
    xlab = "", ylab = "Eligible ETFs",
    main = "Point-in-time eligibility and the frozen 18-of-24 breadth floor"
  )
  abline(h = analysis$contract$minimum_eligible_total, col = "#B42318", lty = 2, lwd = 2)
  abline(v = m1_period_boundaries, col = "#94A3B8", lty = 3)
  legend("bottomright", c("Eligible", "18-ETF floor"), col = c("#0F172A", "#B42318"), lty = c(1, 2), lwd = 2, bty = "n")
  group_values <- rbind(
    `US sectors` = one$eligible_us_sector,
    `Developed countries` = one$eligible_developed_country,
    `Emerging countries` = one$eligible_emerging_country
  )
  matplot(
    one$decision_date, t(group_values),
    type = "l", lty = 1, lwd = 2.2,
    col = unname(m1_group_colors),
    ylim = c(4.5, 9.5),
    xlab = "Month-end decision", ylab = "Eligible ETFs",
    main = "Group breadth prevents one-region ranking months"
  )
  abline(h = c(6, 5, 6), col = unname(m1_group_colors), lty = 3)
  abline(v = m1_period_boundaries, col = "#94A3B8", lty = 3)
  legend("topright", rownames(group_values), col = unname(m1_group_colors), lty = 1, lwd = 2, bty = "n", ncol = 3)
  par(old)
  dev.off()
}

plot_rank_ordering <- function(analysis, path) {
  monthly <- analysis$monthly_measurement
  quarterly <- analysis$quarterly_measurement
  confirmation <- monthly$evaluation_period == "confirmation_2022_2024"
  confirmation_q <- quarterly$evaluation_period == "confirmation_2022_2024"
  png(path, width = 1900, height = 1100, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  colors <- ifelse(confirmation, "#3D8DFF", "#CBD5E1")
  plot(
    monthly$decision_date, monthly$rank_ic,
    type = "h", lwd = 3, col = colors,
    xlab = "", ylab = "Monthly Spearman rank IC",
    main = "Does the frozen ranking order next-month returns?"
  )
  points(monthly$decision_date, monthly$rank_ic, pch = 16, cex = 0.55, col = colors)
  abline(h = 0, col = "#0F172A")
  abline(v = m1_period_boundaries, col = "#94A3B8", lty = 3)
  q <- quarterly[confirmation_q, , drop = FALSE]
  values <- 10000 * q$mean_top_minus_bottom
  bars <- barplot(
    values,
    names.arg = q$calendar_quarter,
    las = 2,
    col = ifelse(values > 0, "#177245", "#B42318"),
    ylim = range(c(values, 0)) + c(-1, 1) * 0.12 * diff(range(c(values, 0))),
    ylab = "Mean top-minus-bottom (bp)",
    main = "Confirmation ordering must repeat across complete quarters"
  )
  abline(h = 0, col = "#0F172A")
  text(bars, values, sprintf("%.0f", values), pos = ifelse(values >= 0, 3, 1), cex = 0.68)
  par(old)
  dev.off()
}

plot_random_control <- function(analysis, path) {
  distribution <- analysis$random_control$distribution$mean_confirmation_excess
  observed <- mean(
    analysis$monthly_measurement$top_minus_eligible_equal_weight[
      analysis$monthly_measurement$evaluation_period == "confirmation_2022_2024"
    ]
  )
  threshold <- as.numeric(stats::quantile(distribution, 0.9, names = FALSE))
  png(path, width = 1800, height = 900, res = 150)
  old <- par(mar = c(6, 7, 4, 2))
  hist(
    10000 * distribution,
    breaks = 40,
    col = "#CBD5E1",
    border = "white",
    xlab = "Mean confirmation excess over eligible equal weight (bp/month)",
    ylab = "Random K-of-N policies",
    main = "Observed concentration must beat the p90 of 2,000 random policies"
  )
  abline(v = 10000 * threshold, col = "#F59E0B", lwd = 3, lty = 2)
  abline(v = 10000 * observed, col = "#3D8DFF", lwd = 4)
  legend(
    "topright",
    c(sprintf("Observed %.2f bp", 10000 * observed), sprintf("Random p90 %.2f bp", 10000 * threshold)),
    col = c("#3D8DFF", "#F59E0B"), lty = c(1, 2), lwd = c(4, 3), bty = "n"
  )
  par(old)
  dev.off()
}

plot_contribution_concentration <- function(analysis, path) {
  pieces <- list(
    `Economic group (cap 50%)` = analysis$attribution$by_group,
    `ETF (cap 25%)` = analysis$attribution$by_asset,
    `Calendar year (cap 50%)` = analysis$attribution$by_year
  )
  labels <- c("economic_group", "symbol", "calendar_year")
  caps <- c(50, 25, 50)
  png(path, width = 2200, height = 1500, res = 150)
  old <- par(mfrow = c(3, 1), mar = c(7, 7, 4, 2))
  for (i in seq_along(pieces)) {
    frame <- pieces[[i]]
    values <- 100 * frame$positive_contribution_share
    names_arg <- as.character(frame[[labels[[i]]]])
    bars <- barplot(
      values, names.arg = names_arg, las = 2,
      col = ifelse(values <= caps[[i]], "#3D8DFF", "#B42318"),
      ylim = c(0, 1.12 * max(c(caps[[i]] + 5, values), na.rm = TRUE)),
      ylab = "Positive contribution share (%)",
      main = names(pieces)[[i]]
    )
    abline(h = caps[[i]], col = "#B42318", lty = 2, lwd = 2)
    text(bars, values, sprintf("%.1f", values), pos = 3, cex = 0.65)
  }
  par(old)
  dev.off()
}

plot_membership_turnover <- function(analysis, path) {
  panel <- analysis$primary_panel
  dates <- sort(unique(panel$decision_date[panel$month_admissible]))
  symbols <- analysis$contract$universe$symbol
  membership <- sapply(dates, function(date) {
    part <- panel[panel$decision_date == date, , drop = FALSE]
    as.integer(part$top_k[match(symbols, part$symbol)])
  })
  rownames(membership) <- symbols
  changes <- if (ncol(membership) > 1L) {
    colSums(abs(membership[, -1L, drop = FALSE] - membership[, -ncol(membership), drop = FALSE])) / 2
  } else numeric()
  png(path, width = 2100, height = 1300, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 8, 4, 3))
  image(
    x = seq_along(dates), y = seq_along(symbols), z = t(membership),
    col = c("#F1F5F9", "#3D8DFF"), axes = FALSE,
    xlab = "", ylab = "", main = "Top-quartile membership tape"
  )
  axis(2, at = seq_along(symbols), labels = symbols, las = 1, cex.axis = 0.5, gap.axis = -1)
  ticks <- unique(round(seq(1, length(dates), length.out = 10)))
  axis(1, at = ticks, labels = format(dates[ticks], "%Y-%m"), las = 2, cex.axis = 0.65)
  if (length(changes)) {
    plot(
      dates[-1L], changes,
      type = "h", lwd = 3, col = "#8B5CF6",
      xlab = "Month-end decision", ylab = "Names entering/leaving",
      main = "Membership changes reveal ranking stability before portfolio replay"
    )
    points(dates[-1L], changes, pch = 16, cex = 0.5, col = "#8B5CF6")
  } else plot.new()
  par(old)
  dev.off()
}

representative_dates <- function(analysis) {
  monthly <- analysis$monthly_measurement
  periods <- unique(monthly$evaluation_period)
  rows <- lapply(periods, function(period) {
    x <- monthly[monthly$evaluation_period == period, , drop = FALSE]
    if (!nrow(x)) return(NULL)
    x[unique(c(which.min(x$rank_ic), which.max(x$rank_ic))), , drop = FALSE]
  })
  out <- do.call(rbind, rows)
  out[seq_len(min(6L, nrow(out))), , drop = FALSE]
}

plot_representative_tapes <- function(analysis, path) {
  selected <- representative_dates(analysis)
  panel <- analysis$primary_panel
  png(path, width = 2400, height = 1500, res = 150)
  old <- par(mfrow = c(2, 3), mar = c(7, 5, 4, 2))
  for (i in seq_len(6L)) {
    if (i > nrow(selected)) {
      plot.new()
      next
    }
    row <- selected[i, , drop = FALSE]
    part <- panel[panel$decision_date == row$decision_date & panel$eligible, , drop = FALSE]
    part <- part[order(part$portfolio_rank), , drop = FALSE]
    values <- rbind(
      `12-1 momentum` = 100 * part$momentum_lookback_skip_log_return,
      `next-month return` = 100 * part$next_month_return
    )
    bar_positions <- barplot(
      values, beside = TRUE, names.arg = part$symbol, las = 2,
      col = c("#3D8DFF", "#177245"), ylab = "Percent",
      main = paste0(row$decision_date, " | IC ", sprintf("%.2f", row$rank_ic), "\n", gsub("_", " ", row$evaluation_period)),
      cex.names = 0.58
    )
    abline(h = 0, col = "#0F172A")
    k <- row$k_count[[1L]]
    if (k < ncol(bar_positions)) {
      boundary <- (max(bar_positions[, k]) + min(bar_positions[, k + 1L])) / 2
      abline(v = boundary, col = "#B42318", lty = 2)
    }
    if (i == 1L) legend("topleft", rownames(values), fill = c("#3D8DFF", "#177245"), bty = "n", cex = 0.75)
  }
  par(old)
  dev.off()
}

plot_gates <- function(analysis, path) {
  gates <- analysis$gates
  colors <- c(PASS = "#177245", FAIL = "#B42318", NOT_RUN = "#64748B")
  png(path, width = 2000, height = 1100, res = 150)
  old <- par(mar = c(4, 24, 4, 3))
  y <- rev(seq_len(nrow(gates)))
  plot(c(0, 1), c(0.5, nrow(gates) + 0.5), type = "n", axes = FALSE, xlab = "", ylab = "", main = paste("Frozen M1 gates:", analysis$overall_status))
  axis(2, at = y, labels = gates$gate, las = 1, cex.axis = 0.72)
  points(rep(0.42, nrow(gates)), y, pch = 19, cex = 3.2, col = unname(colors[gates$status]))
  gate_labels <- ifelse(gates$status == "NOT_RUN", "N/R", gates$status)
  text(rep(0.42, nrow(gates)), y, gate_labels, col = "white", font = 2, cex = 0.52)
  text(rep(0.57, nrow(gates)), y, gates$value, pos = 4, cex = 0.73)
  par(old)
  dev.off()
}

plot_equity_drawdown <- function(analysis, path) {
  replay <- analysis$primary_replay
  colors <- c(m1_top_quartile = "#3D8DFF", eligible_equal_weight = "#0F172A", cash_bil = "#64748B", bottom_quartile = "#B42318")
  png(path, width = 1900, height = 1100, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  plot(range(replay$outcome_end_date), range(replay$wealth), type = "n", xlab = "", ylab = "Growth of $1", main = "M1B net-of-cost replay (created only after all M1A gates pass)")
  for (strategy in names(colors)) {
    x <- replay[replay$strategy_id == strategy, , drop = FALSE]
    lines(x$outcome_end_date, x$wealth, col = colors[[strategy]], lwd = if (strategy == "m1_top_quartile") 3 else 2)
  }
  legend("topleft", names(colors), col = colors, lty = 1, lwd = c(3, 2, 2, 2), bty = "n", ncol = 2)
  plot(range(replay$outcome_end_date), range(replay$drawdown), type = "n", xlab = "Holding-period endpoint", ylab = "Drawdown", main = "Same monthly next-open accounting")
  for (strategy in names(colors)) {
    x <- replay[replay$strategy_id == strategy, , drop = FALSE]
    lines(x$outcome_end_date, x$drawdown, col = colors[[strategy]], lwd = if (strategy == "m1_top_quartile") 3 else 2)
  }
  abline(h = 0, col = "#0F172A")
  par(old)
  dev.off()
}

write_report <- function(path, analysis, run_spec, artifact_paths) {
  confirmation <- analysis$monthly_measurement[
    analysis$monthly_measurement$evaluation_period == "confirmation_2022_2024",
    ,
    drop = FALSE
  ]
  failed_m1a <- analysis$gates$gate[
    grepl("^M1A", analysis$gates$gate_id) & analysis$gates$status == "FAIL"
  ]
  lines <- c(
    "# Gen5 M1 Cross-Sectional Momentum POC",
    "",
    paste0("Status: `", analysis$overall_status, "`"),
    "",
    "## Frozen question",
    "",
    "Does a point-in-time eligible 12-minus-1 momentum ranking order next-month ETF returns repeatedly enough to beat randomized concentration, without relying on one group, ETF, or year?",
    "",
    "## Authority and scope",
    "",
    paste0("- Explicit as-of: `", run_spec$as_of_timestamp[[1L]], "`."),
    paste0("- Adjusted daily Alpaca feed: `", run_spec$feed[[1L]], "`."),
    paste0("- Workbench health: `", run_spec$data_health_max_severity[[1L]], "`; M1 session coverage: `", run_spec$m1_session_coverage_status[[1L]], "`."),
    "- Twenty-four frozen ETFs are ranked; BIL is a comparator and is never ranked.",
    "- Research only: no leverage, optimization, scaling, live advice, or execution behavior.",
    "",
    "## M1A mechanism readout",
    "",
    paste0("- Complete confirmation months: `", nrow(confirmation), " / 36`."),
    paste0("- Mean confirmation rank IC: `", sprintf("%.4f", mean(confirmation$rank_ic)), "`; positive months: `", sum(confirmation$rank_ic > 0), " / 36`."),
    paste0("- Mean confirmation top-minus-bottom: `", sprintf("%.2f bp", 10000 * mean(confirmation$top_minus_bottom)), "`."),
    paste0("- M1A gates passed: `", sum(analysis$gates$status[grepl("^M1A", analysis$gates$gate_id)] == "PASS"), " / 6`."),
    "",
    "## Gate consequence",
    "",
    if (!analysis$m1a_pass) {
      paste0(
        "M1A failed (", paste(failed_m1a, collapse = "; "),
        "). M1B portfolio replay was structurally NOT RUN; no M1 portfolio performance is computed or interpreted."
      )
    } else if (identical(analysis$overall_status, "PASS_M1_TO_PROSPECTIVE_SHADOW")) {
      "M1A and M1B passed. M1 may proceed only to prospective shadow observation; this packet does not adopt a production strategy."
    } else {
      "M1A passed, so M1B was run. One or more frozen portfolio-implementation gates failed; stop this implementation without rescuing it by retuning."
    },
    "",
    "## Key artifacts",
    "",
    paste0("- `", names(artifact_paths), "`: `", normalizePath(unlist(artifact_paths), winslash = "/", mustWork = FALSE), "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("Gen5 M1 frozen cross-sectional momentum POC starting.")
contract <- g5_m1_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_M1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_M1_REFRESH", FALSE)
run_id <- env_or("GEN5_M1_RUN_ID", "m1_cross_sectional_momentum_20260727")
as_of_timestamp <- env_or("GEN5_M1_AS_OF_TIMESTAMP", contract$as_of_timestamp)
if (!identical(as_of_timestamp, contract$as_of_timestamp)) {
  stop("GEN5_M1_AS_OF_TIMESTAMP must match the frozen contract.", call. = FALSE)
}
output_dir <- file.path(repo_root, "runs", "research_workbench", "retail_quant_mechanisms", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$query_end,
  as_of_timestamp = as_of_timestamp,
  symbols = g5_m1_required_symbols(contract),
  universe_name = "gen5_m1_frozen_cross_sectional_momentum",
  universe_roles = "twenty_four_ranked_etfs,bil_comparator",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) stop("M1 workbench query returned no bars.", call. = FALSE)
health_max <- g5_health_max_severity(query$health)
session_coverage <- g5_m1_session_coverage_audit(query$bars, contract)
analysis_health <- if (!any(query$health$severity == "ERROR") && all(session_coverage$status == "PASS")) "PASS" else "FAIL"
analysis <- g5_m1_run_analysis(query$bars, contract, analysis_health)

artifact_paths <- list(
  run_spec_csv = file.path(output_dir, "m1_run_spec.csv"),
  contract_csv = file.path(output_dir, "m1_frozen_contract.csv"),
  observation_panel_csv = file.path(output_dir, "m1_observation_panel.csv"),
  diagnostic_panels_csv = file.path(output_dir, "m1_diagnostic_panels.csv"),
  monthly_measurement_csv = file.path(output_dir, "m1_monthly_measurement.csv"),
  quarterly_measurement_csv = file.path(output_dir, "m1_quarterly_measurement.csv"),
  random_distribution_csv = file.path(output_dir, "m1_random_policy_distribution.csv"),
  random_detail_csv = file.path(output_dir, "m1_random_policy_detail.csv"),
  attribution_detail_csv = file.path(output_dir, "m1_attribution_detail.csv"),
  attribution_asset_csv = file.path(output_dir, "m1_attribution_by_asset.csv"),
  attribution_group_csv = file.path(output_dir, "m1_attribution_by_group.csv"),
  attribution_year_csv = file.path(output_dir, "m1_attribution_by_year.csv"),
  integrity_audit_csv = file.path(output_dir, "m1_integrity_audit.csv"),
  diagnostic_summary_csv = file.path(output_dir, "m1_diagnostic_summary.csv"),
  gate_summary_csv = file.path(output_dir, "m1_gate_summary.csv"),
  session_coverage_csv = file.path(output_dir, "m1_session_coverage_audit.csv"),
  report_md = file.path(output_dir, "m1_report.md"),
  eligibility_png = file.path(visual_dir, "m1_eligibility_coverage.png"),
  ordering_png = file.path(visual_dir, "m1_rank_ordering.png"),
  random_png = file.path(visual_dir, "m1_random_control.png"),
  contribution_png = file.path(visual_dir, "m1_contribution_concentration.png"),
  membership_png = file.path(visual_dir, "m1_membership_turnover.png"),
  tapes_png = file.path(visual_dir, "m1_representative_ranking_tapes.png"),
  gates_png = file.path(visual_dir, "m1_gate_summary.png")
)
if (analysis$m1b_run) {
  artifact_paths <- c(artifact_paths, list(
    primary_replay_csv = file.path(output_dir, "m1b_primary_replay.csv"),
    stress_replay_csv = file.path(output_dir, "m1b_stress_replay.csv"),
    primary_weights_csv = file.path(output_dir, "m1b_primary_weights.csv"),
    stress_weights_csv = file.path(output_dir, "m1b_stress_weights.csv"),
    primary_metrics_csv = file.path(output_dir, "m1b_primary_confirmation_metrics.csv"),
    stress_metrics_csv = file.path(output_dir, "m1b_stress_confirmation_metrics.csv"),
    equity_drawdown_png = file.path(visual_dir, "m1b_equity_drawdown.png")
  ))
}

run_spec <- data.frame(
  schema_version = g5_m1_schema_version(),
  wrapper = "scripts/inspect/run_gen5_m1_cross_sectional_momentum_poc.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  m1_session_coverage_status = analysis_health,
  query_start = contract$query_start,
  query_end = contract$query_end,
  decision_start = contract$decision_start,
  decision_end = contract$decision_end,
  ranked_asset_count = nrow(contract$universe),
  cash_proxy = contract$cash_proxy,
  random_policy_count = contract$random_policy_count,
  model_fit_count = 0L,
  optimization_count = 0L,
  m1a_pass = analysis$m1a_pass,
  m1b_run = analysis$m1b_run,
  leverage = 1,
  overall_status = analysis$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
contract_frame <- data.frame(
  ranked_symbols = paste(contract$universe$symbol, collapse = ","),
  groups = "9_us_sector,7_developed_country,8_emerging_country",
  cash_proxy = contract$cash_proxy,
  signal = "12_minus_1_log_return_rank_descending",
  selection = "top_ceiling_eligible_over_4",
  timing = "completed_month_end_to_following_next_open",
  eligibility = "13_month_ends,60_of_63_fresh,close_ge_5,median_dollar_volume_ge_5m",
  breadth = "18_total,6_us_sector,5_developed,6_emerging",
  random_control = "2000_random_K_policies_seed_5401_p90",
  primary_cost_bps = contract$primary_cost_bps,
  stress_cost_bps = contract$stress_cost_bps,
  stringsAsFactors = FALSE
)

query_artifacts <- g5_write_workbench_query_artifacts(query, output_dir, "m1_workbench_query")
write_csv(run_spec, artifact_paths$run_spec_csv)
write_csv(contract_frame, artifact_paths$contract_csv)
write_csv(analysis$primary_panel, artifact_paths$observation_panel_csv)
write_csv(do.call(rbind, analysis$diagnostic_panels), artifact_paths$diagnostic_panels_csv)
write_csv(analysis$monthly_measurement, artifact_paths$monthly_measurement_csv)
write_csv(analysis$quarterly_measurement, artifact_paths$quarterly_measurement_csv)
write_csv(analysis$random_control$distribution, artifact_paths$random_distribution_csv)
write_csv(analysis$random_control$detail, artifact_paths$random_detail_csv)
write_csv(analysis$attribution$detail, artifact_paths$attribution_detail_csv)
write_csv(analysis$attribution$by_asset, artifact_paths$attribution_asset_csv)
write_csv(analysis$attribution$by_group, artifact_paths$attribution_group_csv)
write_csv(analysis$attribution$by_year, artifact_paths$attribution_year_csv)
write_csv(analysis$integrity, artifact_paths$integrity_audit_csv)
write_csv(analysis$diagnostic_summary, artifact_paths$diagnostic_summary_csv)
write_csv(analysis$gates, artifact_paths$gate_summary_csv)
write_csv(analysis$session_coverage, artifact_paths$session_coverage_csv)
if (analysis$m1b_run) {
  write_csv(analysis$primary_replay, artifact_paths$primary_replay_csv)
  write_csv(analysis$stress_replay, artifact_paths$stress_replay_csv)
  write_csv(analysis$primary_weights, artifact_paths$primary_weights_csv)
  write_csv(analysis$stress_weights, artifact_paths$stress_weights_csv)
  write_csv(analysis$primary_confirmation_metrics, artifact_paths$primary_metrics_csv)
  write_csv(analysis$stress_confirmation_metrics, artifact_paths$stress_metrics_csv)
}
plot_eligibility_coverage(analysis, artifact_paths$eligibility_png)
plot_rank_ordering(analysis, artifact_paths$ordering_png)
plot_random_control(analysis, artifact_paths$random_png)
plot_contribution_concentration(analysis, artifact_paths$contribution_png)
plot_membership_turnover(analysis, artifact_paths$membership_png)
plot_representative_tapes(analysis, artifact_paths$tapes_png)
plot_gates(analysis, artifact_paths$gates_png)
if (analysis$m1b_run) plot_equity_drawdown(analysis, artifact_paths$equity_drawdown_png)
write_report(artifact_paths$report_md, analysis, run_spec, c(artifact_paths, query_artifacts$paths))

message("Gen5 M1 complete: ", analysis$overall_status)
message("Data health: ", health_max)
message("M1B run: ", analysis$m1b_run)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report_md, winslash = "/", mustWork = FALSE))
