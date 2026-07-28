# Gen5 S0A frozen statistical-arbitrage admissibility POC.
# Research only: historical convergence is not historical borrow executability.

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
source(file.path(repo_root, "R", "gen5_s0_statistical_arbitrage_poc.R"))
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
  if (!dir.exists(path)) stop("Could not create S0A output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

s0_colors <- c(
  development_2018_2021 = "#94A3B8",
  confirmation_2022_2024 = "#3D8DFF",
  historical_shadow_2025_2026 = "#8B5CF6"
)

plot_selection_and_stability <- function(analysis, path) {
  q <- analysis$quarter_summary
  stability <- analysis$stability$quarterly
  png(path, width = 1900, height = 1100, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  matplot(
    as.Date(paste0(substr(q$fold_id, 1, 4), "-", c("01-01", "04-01", "07-01", "10-01")[
      as.integer(substr(q$fold_id, 6, 6))
    ])),
    cbind(q$selected_pair_count, q$active_pair_count),
    type = "s", lty = 1, lwd = c(2.5, 2.2),
    col = c("#0F172A", "#3D8DFF"),
    xlab = "", ylab = "Pairs",
    main = "Frozen structural selection and event-active breadth"
  )
  abline(h = analysis$contract$minimum_pairs, col = "#B42318", lty = 2)
  legend(
    "bottomright", c("Selected", "At least one event", "8-pair floor"),
    col = c("#0F172A", "#3D8DFF", "#B42318"), lty = c(1, 1, 2),
    lwd = c(2.5, 2.2, 2), bty = "n"
  )
  bar_colors <- ifelse(
    stability$survival_rate >= analysis$contract$minimum_quarter_survival,
    "#177245", "#B42318"
  )
  bars <- barplot(
    100 * stability$survival_rate,
    names.arg = stability$fold_id,
    las = 2, col = bar_colors, ylim = c(0, 105),
    ylab = "Selected pairs still eligible next formation (%)",
    main = "Confirmation relationship survival is evaluated one quarter later"
  )
  abline(h = 100 * analysis$contract$minimum_quarter_survival, col = "#B42318", lty = 2)
  text(bars, 100 * stability$survival_rate, sprintf("%.0f", 100 * stability$survival_rate), pos = 3, cex = 0.7)
  par(old)
  dev.off()
}

plot_quarterly_convergence <- function(analysis, path) {
  q <- analysis$quarter_summary
  confirmation <- q$evaluation_period == "confirmation_2022_2024"
  png(path, width = 1950, height = 1050, res = 150)
  old <- par(mar = c(7, 7, 4, 2))
  values <- 10000 * rbind(q$net_5_5bp, q$net_10_5bp, q$net_20_5bp)
  colors <- c("#94A3B8", "#3D8DFF", "#8B5CF6")
  matplot(
    seq_len(nrow(q)), t(values), type = "l", lty = 1,
    lwd = c(1.8, 3.2, 1.8), col = colors,
    xaxt = "n", xlab = "Walk-forward quarter", ylab = "Pair-equal net convergence (bp/event)",
    main = "No equity curve: each point is an independent quarter's event average"
  )
  axis(1, at = seq_len(nrow(q)), labels = q$fold_id, las = 2, cex.axis = 0.65)
  points(rep(seq_len(nrow(q)), each = 3L), as.vector(values), pch = 16, col = rep(colors, nrow(q)), cex = 0.55)
  abline(h = 0, col = "#0F172A")
  abline(v = which(confirmation)[[1L]] - 0.5, col = "#3D8DFF", lty = 3)
  abline(v = tail(which(confirmation), 1L) + 0.5, col = "#3D8DFF", lty = 3)
  legend(
    "topright", c("h5, 5 bp/side", "h10 primary, 5 bp/side", "h20, 5 bp/side"),
    col = colors, lty = 1, lwd = c(1.8, 3.2, 1.8), bty = "n"
  )
  par(old)
  dev.off()
}

plot_random_control <- function(analysis, path) {
  distribution <- analysis$random_control$distribution
  values <- distribution$mean_confirmation_net_10_5bp[distribution$valid]
  q <- analysis$quarter_summary
  observed <- mean(q$net_10_5bp[q$evaluation_period == "confirmation_2022_2024"])
  threshold <- if (length(values)) {
    as.numeric(stats::quantile(values, analysis$contract$random_percentile, names = FALSE))
  } else {
    NA_real_
  }
  png(path, width = 1800, height = 900, res = 150)
  old <- par(mar = c(6, 7, 4, 2))
  if (length(values)) {
    hist(
      10000 * values, breaks = 40, col = "#CBD5E1", border = "white",
      xlab = "Mean confirmation h10 net convergence (bp/event)",
      ylab = "Valid random pair-selection policies",
      main = "Frozen pair selection must beat the p90 of 2,000 random policies"
    )
    abline(v = 10000 * threshold, col = "#F59E0B", lwd = 3, lty = 2)
    abline(v = 10000 * observed, col = "#3D8DFF", lwd = 4)
    legend(
      "topright",
      c(sprintf("Observed %.2f bp", 10000 * observed), sprintf("Random p90 %.2f bp", 10000 * threshold)),
      col = c("#3D8DFF", "#F59E0B"), lty = c(1, 2), lwd = c(4, 3), bty = "n"
    )
  } else {
    plot.new()
    text(0.5, 0.5, "No valid random policies", cex = 1.5)
  }
  par(old)
  dev.off()
}

plot_non_event_control <- function(analysis, path) {
  x <- analysis$control_summary
  confirmation <- x$evaluation_period == "confirmation_2022_2024"
  png(path, width = 1900, height = 1000, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(6, 7, 4, 2))
  values <- 10000 * rbind(x$event_pair_equal, x$control_pair_equal)
  matplot(
    seq_len(nrow(x)), t(values), type = "b", pch = c(16, 1), lty = 1,
    lwd = c(2.8, 2), col = c("#3D8DFF", "#64748B"),
    xaxt = "n", xlab = "", ylab = "Pair-equal h10 net (bp/event)",
    main = "Extreme-spread events versus direction-matched quiet dates"
  )
  axis(1, at = seq_len(nrow(x)), labels = x$fold_id, las = 2, cex.axis = 0.65)
  abline(h = 0, col = "#0F172A")
  legend("topright", c("|z| >= 2 events", "|z| < 0.5 controls"), col = c("#3D8DFF", "#64748B"), lty = 1, pch = c(16, 1), bty = "n")
  differences <- 10000 * x$event_minus_control
  bars <- barplot(
    differences[confirmation], names.arg = x$fold_id[confirmation], las = 2,
    col = ifelse(differences[confirmation] > 0, "#177245", "#B42318"),
    ylab = "Event minus quiet control (bp)", main = "Confirmation-only matched-control difference"
  )
  abline(h = 0, col = "#0F172A")
  text(bars, differences[confirmation], sprintf("%.1f", differences[confirmation]), pos = ifelse(differences[confirmation] >= 0, 3, 1), cex = 0.65)
  par(old)
  dev.off()
}

plot_contribution_concentration <- function(analysis, path) {
  pieces <- list(
    `Economic group (cap 50%)` = analysis$attribution$by_group,
    `Pair (cap 20%)` = analysis$attribution$by_pair,
    `Calendar year (cap 50%)` = analysis$attribution$by_year
  )
  keys <- c("economic_group", "pair_id", "calendar_year")
  caps <- c(50, 20, 50)
  png(path, width = 2100, height = 1450, res = 150)
  old <- par(mfrow = c(3, 1), mar = c(7, 7, 4, 2))
  for (i in seq_along(pieces)) {
    frame <- pieces[[i]]
    if (!nrow(frame)) {
      plot.new()
      title(names(pieces)[[i]])
      text(0.5, 0.5, "No positive confirmation contribution")
      next
    }
    values <- 100 * frame$positive_contribution_share
    labels <- as.character(frame[[keys[[i]]]])
    bars <- barplot(
      values, names.arg = labels, las = 2,
      col = ifelse(values <= caps[[i]], "#3D8DFF", "#B42318"),
      ylim = c(0, 1.15 * max(c(values, caps[[i]]), na.rm = TRUE)),
      ylab = "Positive contribution share (%)", main = names(pieces)[[i]]
    )
    abline(h = caps[[i]], col = "#B42318", lty = 2, lwd = 2)
    text(bars, values, sprintf("%.1f", values), pos = 3, cex = 0.62)
  }
  par(old)
  dev.off()
}

representative_pair_folds <- function(analysis, count = 6L) {
  x <- analysis$selected_events[
    analysis$selected_events$evaluation_period == "confirmation_2022_2024",
    ,
    drop = FALSE
  ]
  if (!nrow(x)) return(data.frame())
  means <- aggregate(net_10_5bp ~ fold_id + pair_id, x, mean)
  means <- means[order(means$net_10_5bp), , drop = FALSE]
  indices <- unique(round(seq(1, nrow(means), length.out = min(count, nrow(means)))))
  means[indices, , drop = FALSE]
}

plot_representative_pair_tapes <- function(analysis, path) {
  chosen <- representative_pair_folds(analysis)
  png(path, width = 2100, height = 1000, res = 150)
  old <- par(mfrow = c(2, 3), mar = c(5, 5, 4, 2))
  if (!nrow(chosen)) {
    plot.new()
    text(0.5, 0.5, "No confirmation events")
  } else {
    for (i in seq_len(nrow(chosen))) {
      opportunity <- analysis$opportunities[
        analysis$opportunities$fold_id == chosen$fold_id[[i]] &
          analysis$opportunities$pair_id == chosen$pair_id[[i]],
        ,
        drop = FALSE
      ]
      events <- analysis$selected_events[
        analysis$selected_events$fold_id == chosen$fold_id[[i]] &
          analysis$selected_events$pair_id == chosen$pair_id[[i]],
        ,
        drop = FALSE
      ]
      plot(
        opportunity$signal_date, opportunity$z, type = "l", lwd = 2,
        col = "#0F172A", ylim = range(c(opportunity$z, -2.5, 2.5)),
        xlab = "", ylab = "Formation-frozen residual z",
        main = sprintf(
          "%s / %s | mean h10 %.1f bp",
          chosen$fold_id[[i]], chosen$pair_id[[i]], 10000 * chosen$net_10_5bp[[i]]
        )
      )
      abline(h = c(-2, 0, 2), col = c("#B42318", "#94A3B8", "#B42318"), lty = c(2, 3, 2))
      if (nrow(events)) {
        points(events$signal_date, events$z, pch = 21, bg = ifelse(events$net_10_5bp > 0, "#177245", "#B42318"), col = "white", cex = 1.4)
      }
    }
  }
  par(old)
  dev.off()
}

plot_gates <- function(analysis, path) {
  gates <- analysis$gates
  png(path, width = 2000, height = 1050, res = 150)
  old <- par(mar = c(4, 4, 3, 2))
  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0, nrow(gates) + 1))
  title(main = paste("S0A frozen gate verdict:", analysis$overall_status))
  for (i in seq_len(nrow(gates))) {
    y <- nrow(gates) - i + 1
    color <- if (gates$status[[i]] == "PASS") "#177245" else "#B42318"
    rect(0.01, y - 0.36, 0.08, y + 0.36, col = color, border = NA)
    text(0.045, y, gates$status[[i]], col = "white", font = 2, cex = 0.72)
    text(0.10, y + 0.12, paste(gates$gate_id[[i]], gates$gate[[i]]), adj = 0, font = 2, cex = 0.85)
    text(0.10, y - 0.18, gates$value[[i]], adj = 0, col = "#475569", cex = 0.76)
  }
  par(old)
  dev.off()
}

write_report <- function(path, analysis, run_spec, artifact_paths) {
  q <- analysis$quarter_summary
  confirmation <- q[q$evaluation_period == "confirmation_2022_2024", , drop = FALSE]
  failed <- analysis$gates$gate_id[analysis$gates$status == "FAIL"]
  lines <- c(
    "# Gen5 S0A Statistical-Arbitrage Admissibility POC",
    "",
    paste0("**Frozen verdict:** `", analysis$overall_status, "`"),
    "",
    "This packet tests whether formation-frozen within-group ETF residual spreads show repeated next-open convergence. It does not claim that historical short legs were borrowable.",
    "",
    "## Confirmation readout",
    "",
    paste0("- Pair-equal h10 net convergence at 5 bp/side: ", sprintf("%.2f bp/event", 10000 * mean(confirmation$net_10_5bp, na.rm = TRUE))),
    paste0("- Positive confirmation quarters: ", sum(confirmation$net_10_5bp > 0, na.rm = TRUE), "/12"),
    paste0("- Confirmation events: ", sum(confirmation$event_count)),
    paste0("- Failed frozen gates: ", if (length(failed)) paste(failed, collapse = ", ") else "none"),
    "",
    "## Frozen gates",
    "",
    paste0("- **", analysis$gates$gate_id, " ", analysis$gates$gate, ": ", analysis$gates$status, "** — ", analysis$gates$value),
    "",
    "## Interpretation boundary",
    "",
    if (identical(analysis$overall_status, "PASS_S0A_TO_PROSPECTIVE_BORROW_SHADOW_DISCUSSION")) {
      "S0A passes only to a discussion of a prospective Alpaca shortability/borrow shadow. It does not authorize strategy adoption, portfolio allocation, live advice, or execution."
    } else {
      "S0A stops as a relative-value mechanism under the frozen contract. The failed result must not be rescued by inspecting confirmation outcomes and retuning this test."
    },
    "",
    "## Run authority",
    "",
    paste0("- As of: `", run_spec$as_of_timestamp, "`"),
    paste0("- Data health: `", run_spec$data_health_max_severity, "`"),
    paste0("- Data-health interpretation: `", run_spec$data_health_interpretation, "`"),
    paste0("- Session coverage: `", run_spec$session_coverage_status, "`"),
    paste0("- Output: `", run_spec$output_dir, "`"),
    "",
    "## Key artifacts",
    "",
    paste0("- `", names(artifact_paths), "`: `", normalizePath(unlist(artifact_paths), winslash = "/", mustWork = FALSE), "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("Gen5 S0A frozen statistical-arbitrage POC starting.")
contract <- g5_s0_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_S0_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_S0_REFRESH", FALSE)
run_id <- env_or("GEN5_S0_RUN_ID", "s0_statistical_arbitrage_20260728")
as_of_timestamp <- env_or("GEN5_S0_AS_OF_TIMESTAMP", contract$as_of_timestamp)
if (!identical(as_of_timestamp, contract$as_of_timestamp)) {
  stop("GEN5_S0_AS_OF_TIMESTAMP must match the frozen contract.", call. = FALSE)
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
  symbols = g5_s0_required_symbols(contract),
  universe_name = "gen5_s0_frozen_statistical_arbitrage",
  universe_roles = "four_within_group_etf_relative_value_panels",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) stop("S0A workbench query returned no bars.", call. = FALSE)
health_max <- g5_health_max_severity(query$health)
coverage <- g5_s0_session_coverage_audit(query$bars, contract)
analysis_health <- if (
  !any(query$health$severity == "ERROR") && all(coverage$status == "PASS")
) "PASS" else "FAIL"
analysis <- g5_s0_run_analysis(query$bars, contract, analysis_health)

artifact_paths <- list(
  run_spec_csv = file.path(output_dir, "s0a_run_spec.csv"),
  contract_csv = file.path(output_dir, "s0a_frozen_contract.csv"),
  schedule_csv = file.path(output_dir, "s0a_schedule.csv"),
  eligibility_csv = file.path(output_dir, "s0a_symbol_eligibility.csv"),
  pair_fits_csv = file.path(output_dir, "s0a_pair_fits.csv"),
  selected_pairs_csv = file.path(output_dir, "s0a_selected_pairs.csv"),
  opportunities_csv = file.path(output_dir, "s0a_opportunities.csv"),
  selected_events_csv = file.path(output_dir, "s0a_selected_events.csv"),
  pair_means_csv = file.path(output_dir, "s0a_pair_means.csv"),
  quarter_summary_csv = file.path(output_dir, "s0a_quarter_summary.csv"),
  non_event_controls_csv = file.path(output_dir, "s0a_non_event_controls.csv"),
  control_summary_csv = file.path(output_dir, "s0a_control_summary.csv"),
  random_distribution_csv = file.path(output_dir, "s0a_random_policy_distribution.csv"),
  random_detail_csv = file.path(output_dir, "s0a_random_policy_detail.csv"),
  attribution_group_csv = file.path(output_dir, "s0a_attribution_by_group.csv"),
  attribution_pair_csv = file.path(output_dir, "s0a_attribution_by_pair.csv"),
  attribution_year_csv = file.path(output_dir, "s0a_attribution_by_year.csv"),
  stability_detail_csv = file.path(output_dir, "s0a_relationship_stability_detail.csv"),
  stability_quarterly_csv = file.path(output_dir, "s0a_relationship_stability_quarterly.csv"),
  integrity_csv = file.path(output_dir, "s0a_integrity_audit.csv"),
  coverage_csv = file.path(output_dir, "s0a_session_coverage_audit.csv"),
  gates_csv = file.path(output_dir, "s0a_gate_summary.csv"),
  report_md = file.path(output_dir, "s0a_report.md"),
  selection_png = file.path(visual_dir, "s0a_selection_and_stability.png"),
  convergence_png = file.path(visual_dir, "s0a_quarterly_convergence.png"),
  random_png = file.path(visual_dir, "s0a_random_control.png"),
  non_event_png = file.path(visual_dir, "s0a_non_event_control.png"),
  contribution_png = file.path(visual_dir, "s0a_contribution_concentration.png"),
  tapes_png = file.path(visual_dir, "s0a_representative_pair_tapes.png"),
  gates_png = file.path(visual_dir, "s0a_gate_summary.png")
)

run_spec <- data.frame(
  schema_version = g5_s0_schema_version(),
  wrapper = "scripts/inspect/run_gen5_s0_statistical_arbitrage_poc.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  data_health_interpretation = if (
    identical(health_max, "WARN") && identical(analysis_health, "PASS")
  ) "WARN_WITH_COMPLETE_REFERENCE_SESSION_COVERAGE" else health_max,
  session_coverage_status = analysis_health,
  query_start = contract$query_start,
  query_end = contract$query_end,
  oos_start = contract$oos_start,
  oos_end = contract$oos_end,
  universe_size = nrow(contract$universe),
  random_policy_count = contract$random_policy_count,
  historical_borrow_assumption_count = 0L,
  overall_status = analysis$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
contract_frame <- data.frame(
  symbols = paste(contract$universe$symbol, collapse = ","),
  groups = "11_us_sector,8_us_size_style,10_developed_country,8_emerging_country",
  formation = "504_sessions_min_480",
  filters = "corr_ge_.60,beta_.25_to_4,drift_le_.50,half_life_2_to_30",
  selection = "adf_like_gamma_t_max_3_per_group_no_shared_etf",
  timing = "after_close_signal_next_open_entry",
  event = "abs_z_ge_2_twenty_session_embargo",
  horizons = "5,10,20_sessions_primary_10",
  costs = "5bp_and_10bp_one_way_charged_entry_and_exit",
  controls = "2000_random_seed_5403,pair_matched_quiet_seed_5404",
  borrow = "not_historically_imputed",
  stringsAsFactors = FALSE
)

query_artifacts <- g5_write_workbench_query_artifacts(
  query, output_dir, "s0a_workbench_query"
)
write_csv(run_spec, artifact_paths$run_spec_csv)
write_csv(contract_frame, artifact_paths$contract_csv)
write_csv(analysis$schedule, artifact_paths$schedule_csv)
write_csv(analysis$symbol_eligibility, artifact_paths$eligibility_csv)
write_csv(analysis$pair_fits, artifact_paths$pair_fits_csv)
write_csv(analysis$pair_fits[analysis$pair_fits$selected, , drop = FALSE], artifact_paths$selected_pairs_csv)
write_csv(analysis$opportunities, artifact_paths$opportunities_csv)
write_csv(analysis$selected_events, artifact_paths$selected_events_csv)
write_csv(analysis$pair_means, artifact_paths$pair_means_csv)
write_csv(analysis$quarter_summary, artifact_paths$quarter_summary_csv)
write_csv(analysis$non_event_controls, artifact_paths$non_event_controls_csv)
write_csv(analysis$control_summary, artifact_paths$control_summary_csv)
write_csv(analysis$random_control$distribution, artifact_paths$random_distribution_csv)
write_csv(analysis$random_control$detail, artifact_paths$random_detail_csv)
write_csv(analysis$attribution$by_group, artifact_paths$attribution_group_csv)
write_csv(analysis$attribution$by_pair, artifact_paths$attribution_pair_csv)
write_csv(analysis$attribution$by_year, artifact_paths$attribution_year_csv)
write_csv(analysis$stability$detail, artifact_paths$stability_detail_csv)
write_csv(analysis$stability$quarterly, artifact_paths$stability_quarterly_csv)
write_csv(analysis$integrity, artifact_paths$integrity_csv)
write_csv(analysis$session_coverage, artifact_paths$coverage_csv)
write_csv(analysis$gates, artifact_paths$gates_csv)
plot_selection_and_stability(analysis, artifact_paths$selection_png)
plot_quarterly_convergence(analysis, artifact_paths$convergence_png)
plot_random_control(analysis, artifact_paths$random_png)
plot_non_event_control(analysis, artifact_paths$non_event_png)
plot_contribution_concentration(analysis, artifact_paths$contribution_png)
plot_representative_pair_tapes(analysis, artifact_paths$tapes_png)
plot_gates(analysis, artifact_paths$gates_png)
write_report(
  artifact_paths$report_md, analysis, run_spec,
  c(artifact_paths, query_artifacts$paths)
)

message("Gen5 S0A complete: ", analysis$overall_status)
message("Data health: ", health_max)
message("Session coverage: ", analysis_health)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report_md, winslash = "/", mustWork = FALSE))
