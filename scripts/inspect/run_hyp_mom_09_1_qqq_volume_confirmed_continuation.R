# Run frozen HYP-MOM-09.1 TRAIN, then DEVELOPMENT only if TRAIN passes.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "scripts/inspect/run_hyp_mom_09_1_qqq_volume_confirmed_continuation.R"
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mom_09_1_qqq_volume_confirmed_continuation.R"))
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
  if (!dir.exists(path)) stop("Could not create HYP-MOM-09.1 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract_table <- function(contract) {
  data.frame(
    field = names(contract),
    value = vapply(contract, function(x) paste(x, collapse = ","), character(1)),
    stringsAsFactors = FALSE
  )
}

health_severity <- function(health) {
  if (!nrow(health)) return("PASS")
  rank <- c(PASS = 1L, INFO = 1L, WARN = 2L, ERROR = 3L)
  values <- unname(rank[as.character(health$severity)])
  if (all(is.na(values))) return("UNKNOWN")
  names(rank)[which(rank == max(values, na.rm = TRUE))[[1L]]]
}

query_zone <- function(cfg, contract, end_date, universe_name, refresh) {
  g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = contract$query_start,
    end_date = end_date,
    as_of_timestamp = contract$as_of_timestamp,
    symbols = contract$symbol,
    universe_name = universe_name,
    universe_roles = "nasdaq_100_growth_proxy",
    refresh = refresh,
    repo_root = repo_root
  )
}

coverage_table <- function(bars, contract, requested_end) {
  dates <- sort(unique(as.Date(bars$session_date[bars$symbol == contract$symbol])))
  data.frame(
    symbol = contract$symbol,
    first_session = if (length(dates)) min(dates) else as.Date(NA),
    last_session = if (length(dates)) max(dates) else as.Date(NA),
    row_count = length(dates),
    duplicate_sessions = sum(duplicated(dates)),
    query_start_covered = length(dates) && min(dates) <= contract$query_start,
    requested_end_covered = length(dates) && max(dates) >= as.Date(requested_end),
    stringsAsFactors = FALSE
  )
}

source_audit <- function(coverage, bars, contract, requested_end) {
  volume <- as.numeric(bars$volume)
  dollar_volume <- as.numeric(bars$close) * volume
  data.frame(
    check_id = c(
      "exact_symbol", "adjusted_daily_only", "query_start_covered", "requested_end_covered",
      "positive_volume", "positive_adjusted_dollar_volume", "requested_boundary_respected",
      "post_2025_excluded"
    ),
    passed = c(
      identical(unique(as.character(bars$symbol)), contract$symbol),
      all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
      isTRUE(coverage$query_start_covered[[1L]]),
      isTRUE(coverage$requested_end_covered[[1L]]),
      length(volume) > 0L && all(is.finite(volume) & volume > 0),
      length(dollar_volume) > 0L && all(is.finite(dollar_volume) & dollar_volume > 0),
      max(as.Date(bars$session_date)) <= as.Date(requested_end),
      max(as.Date(bars$session_date)) < as.Date("2026-01-01")
    ),
    observed = c(
      paste(unique(as.character(bars$symbol)), collapse = ","),
      paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
      as.character(coverage$first_session[[1L]]),
      as.character(coverage$last_session[[1L]]),
      paste(range(volume), collapse = " to "),
      paste(range(dollar_volume), collapse = " to "),
      as.character(max(as.Date(bars$session_date))),
      as.character(max(as.Date(bars$session_date)))
    ),
    source = rep("Gen5 Alpaca adjusted-daily cache and frozen HYP-MOM-09.1 contract", 8L),
    stringsAsFactors = FALSE
  )
}

split_summary <- function(panel, contract) {
  x <- panel$split_audit
  data.frame(
    row_count = nrow(x),
    minimum_close_ratio = min(x$close_ratio),
    maximum_close_ratio = max(x$close_ratio),
    extreme_close_ratio_count = sum(x$extreme_close_ratio),
    reciprocal_volume_move_count = sum(x$reciprocal_volume_move),
    split_like_event_count = sum(x$split_like),
    maximum_allowed_split_like_events = contract$maximum_split_like_events,
    passed = sum(x$split_like) <= contract$maximum_split_like_events,
    stringsAsFactors = FALSE
  )
}

participation_summary <- function(panel, contract) {
  x <- panel$bars$positive_surprise
  eligible <- is.finite(x)
  data.frame(
    eligible_sessions = sum(eligible),
    positive_sessions = sum(x[eligible] > 0),
    positive_fraction = mean(x[eligible] > 0),
    capped_sessions = sum(panel$bars$capped[eligible]),
    capped_fraction = mean(panel$bars$capped[eligible]),
    mean_positive_surprise = mean(x[eligible]),
    median_positive_surprise = stats::median(x[eligible]),
    p90_positive_surprise = as.numeric(stats::quantile(x[eligible], 0.90, type = contract$quantile_type)),
    maximum_positive_surprise = max(x[eligible]),
    cap_value = log(contract$volume_cap_multiple),
    stringsAsFactors = FALSE
  )
}

plot_surface <- function(surface, path, contract) {
  grDevices::png(path, width = 1800, height = 900, res = 150)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  for (metric in c("partial_correlation", "interaction_beta")) {
    values <- matrix(NA_real_, nrow = length(contract$lookback_grid), ncol = length(contract$target_grid))
    for (i in seq_len(nrow(surface))) {
      values[match(surface$lookback_sessions[[i]], contract$lookback_grid),
             match(surface$target_sessions[[i]], contract$target_grid)] <- surface[[metric]][[i]]
    }
    limit <- max(abs(values), na.rm = TRUE)
    colors <- grDevices::colorRampPalette(c("#B42318", "#F8FAFC", "#177245"))(101)
    graphics::image(
      seq_along(contract$target_grid), seq_along(contract$lookback_grid), t(values),
      col = colors, zlim = c(-limit, limit), axes = FALSE,
      xlab = "Forward horizon H", ylab = "Trailing return / participation lookback L",
      main = if (metric == "partial_correlation") {
        "TRAIN partial interaction correlation"
      } else {
        "TRAIN full-model interaction slope"
      }
    )
    graphics::axis(1, at = seq_along(contract$target_grid), labels = contract$target_grid)
    graphics::axis(2, at = seq_along(contract$lookback_grid), labels = contract$lookback_grid)
    for (r in seq_len(nrow(values))) for (c in seq_len(ncol(values))) {
      graphics::text(c, r, sprintf("%.3f", values[r, c]), cex = 0.9)
    }
  }
}

plot_shift <- function(distribution, decision, path) {
  grDevices::png(path, width = 1500, height = 900, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::hist(
    distribution$maximum_partial_correlation, breaks = 35,
    col = "#D7E3F4", border = "white",
    xlab = "Maximum partial interaction correlation across nine cells",
    main = "Search-adjusted HYP-MOM-09.1 TRAIN control"
  )
  graphics::abline(v = decision$shift_maximum_p90, col = "#B7791F", lwd = 3, lty = 2)
  graphics::abline(v = decision$observed_maximum_partial_correlation, col = "#166534", lwd = 3)
  graphics::legend(
    "topright", legend = c("Observed maximum", "Shift-null p90"),
    col = c("#166534", "#B7791F"), lwd = 3, lty = c(1, 2), bty = "n"
  )
}

plot_participation <- function(panel, path, contract) {
  x <- panel$bars
  keep <- x$session_date >= contract$train_start & x$session_date <= contract$train_end
  x <- x[keep, , drop = FALSE]
  grDevices::png(path, width = 1800, height = 900, res = 150)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  graphics::plot(
    x$session_date, x$positive_surprise, type = "h", col = "#147D8C",
    xlab = "Session", ylab = "Positive log dollar-volume surprise",
    main = "Causal TRAIN participation series"
  )
  graphics::abline(h = log(contract$volume_cap_multiple), col = "#B7791F", lty = 2)
  graphics::hist(
    x$positive_surprise, breaks = 35, col = "#D7E3F4", border = "white",
    xlab = "Positive log dollar-volume surprise", main = "Participation distribution"
  )
}

select_event_indices <- function(values, minimum_spacing = 40L, count = 3L) {
  candidates <- order(values, decreasing = TRUE, na.last = NA)
  selected <- integer()
  for (idx in candidates) {
    if (!length(selected) || all(abs(idx - selected) >= minimum_spacing)) selected <- c(selected, idx)
    if (length(selected) >= count) break
  }
  sort(selected)
}

plot_participation_events <- function(panel, path, contract) {
  x <- panel$bars
  train_rows <- which(x$session_date >= contract$train_start & x$session_date <= contract$train_end)
  local <- x[train_rows, , drop = FALSE]
  events <- select_event_indices(local$positive_surprise)
  grDevices::png(path, width = 1800, height = 800, res = 150)
  old <- graphics::par(mfrow = c(1, length(events)), mar = c(5, 4, 4, 4))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  for (event in events) {
    idx <- seq.int(max(1L, event - 10L), min(nrow(local), event + 10L))
    price <- 100 * local$close[idx] / local$close[event]
    participation <- local$positive_surprise[idx]
    graphics::plot(
      seq_along(idx), price, type = "l", lwd = 2, col = "#172033",
      xlab = "Sessions around event", ylab = "QQQ adjusted close (event = 100)",
      main = as.character(local$session_date[event]), xaxt = "n"
    )
    graphics::axis(1, at = c(1, which(idx == event), length(idx)), labels = c(-10, 0, 10))
    graphics::par(new = TRUE)
    graphics::plot(
      seq_along(idx), participation, type = "h", lwd = 3, col = grDevices::adjustcolor("#E97132", 0.65),
      axes = FALSE, xlab = "", ylab = ""
    )
    graphics::axis(4, col.axis = "#E97132")
    graphics::mtext("Participation surprise", side = 4, line = 2.5, col = "#E97132")
    graphics::abline(v = which(idx == event), col = "#147D8C", lty = 2)
  }
}

plot_nominee <- function(pairs, cell_id, path) {
  controls <- cbind(pairs$r, pairs$v, pairs$a)
  x <- g5_hm091_residuals(pairs$interaction, controls)
  y <- g5_hm091_residuals(pairs$y, controls)
  grDevices::png(path, width = 1500, height = 900, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(
    x, y, pch = 16, cex = 0.55, col = grDevices::adjustcolor("#147D8C", 0.35),
    xlab = "Residual return-by-participation interaction",
    ylab = "Residual forward QQQ return",
    main = paste("Frozen TRAIN nominee", cell_id)
  )
  graphics::abline(stats::lm(y ~ x), col = "#B42318", lwd = 3)
  graphics::abline(h = 0, v = 0, col = "#94A3B8", lty = 3)
}

plot_development <- function(result, path) {
  grDevices::png(path, width = 1800, height = 900, res = 150)
  old <- graphics::par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  models <- result$model_comparison
  graphics::barplot(
    models$development_mse, names.arg = models$model_id, las = 2,
    col = ifelse(models$model_id == "INTERACTION", "#147D8C", "#94A3B8"),
    ylab = "Mean squared error", main = "Frozen-model DEVELOPMENT loss"
  )
  years <- result$year_diagnostics
  graphics::barplot(
    years$interaction_beta, names.arg = years$year,
    col = ifelse(years$interaction_beta > 0, "#177245", "#B42318"),
    ylab = "Interaction slope", main = "DEVELOPMENT interaction by year"
  )
  graphics::abline(h = 0, col = "#64748B")
}

write_report <- function(train, development, coverage, source_checks, split_checks, participation, run_spec, paths) {
  decision <- train$decision[1L, ]
  best <- train$surface[which.max(train$surface$partial_correlation), , drop = FALSE]
  lines <- c(
    "# HYP-MOM-09.1 QQQ Volume-Confirmed Continuation Results",
    "",
    paste0("Status: `", run_spec$overall_status[[1L]], "`"),
    "",
    "## Question",
    "",
    "Does positive QQQ dollar-volume surprise add continuation information beyond drift, signed return, volume alone, and absolute move size?",
    "",
    "## Source and construction",
    "",
    paste0("- Return-blind source and coverage gates: `", sum(source_checks$passed), " / ", nrow(source_checks), "` pass."),
    paste0("- Adjusted QQQ daily coverage: `", coverage$first_session, "` to `", coverage$last_session, "`; `", coverage$row_count, "` sessions."),
    paste0("- Split-like reciprocal discontinuities: `", split_checks$split_like_event_count, "`."),
    paste0("- Eligible participation observations: `", participation$eligible_sessions, "`; positive fraction `", sprintf("%.3f", participation$positive_fraction), "`; capped fraction `", sprintf("%.5f", participation$capped_fraction), "`."),
    "- Each session's dollar-volume reference uses only the strictly prior 60 sessions; the positive transform is capped at log(5).",
    "- Workbench health may be WARN only because a deliberately historical query ends before the 2026 as-of session; requested TRAIN coverage is complete.",
    "",
    "## TRAIN readout",
    "",
    paste0("- Common TRAIN anchors: `", nrow(train$panel$target_matrix), "`."),
    paste0("- Best observed cell: `", best$cell_id, "`; partial rho `", sprintf("%.6f", best$partial_correlation), "`; interaction beta `", sprintf("%.6f", best$interaction_beta), "`."),
    paste0("- Shift-maximum p90: `", sprintf("%.6f", decision$shift_maximum_p90), "`; empirical upper-tail probability `", sprintf("%.6f", decision$empirical_upper_tail_probability), "`."),
    paste0("- TRAIN decision: `", decision$status, "`."),
    ""
  )
  if (nrow(train$nominee)) {
    stats <- development$development_statistics[1L, ]
    boot <- development$bootstrap[1L, ]
    lines <- c(
      lines,
      paste0("- Frozen nominee: `", train$nominee$cell_id[[1L]], "`."),
      "",
      "## DEVELOPMENT readout",
      "",
      paste0("- DEVELOPMENT anchors: `", nrow(development$development_pairs), "`."),
      paste0("- Partial interaction rho `", sprintf("%.6f", stats$partial_correlation), "`; full-model beta `", sprintf("%.6f", stats$interaction_beta), "`."),
      paste0("- Bootstrap P(beta > 0): `", sprintf("%.4f", boot$beta_probability_positive), "`; P(loss improvement > 0): `", sprintf("%.4f", boot$loss_probability_positive), "`."),
      paste0("- Gates: `", sum(development$gates$passed), " / ", nrow(development$gates), "` pass."),
      paste0("- DEVELOPMENT decision: `", development$overall_status, "`."),
      ""
    )
  } else {
    lines <- c(
      lines,
      "## DEVELOPMENT boundary",
      "",
      "DEVELOPMENT was not queried or calculated because the frozen TRAIN interaction surface gate failed.",
      ""
    )
  }
  lines <- c(
    lines,
    "## Interpretation",
    "",
    if (nrow(train$nominee)) {
      if (all(development$gates$passed)) {
        "The interaction survived historical DEVELOPMENT and requires operator review before any sealed confirmation access."
      } else {
        "The frozen interaction nominee failed at least one DEVELOPMENT gate. Stop without consuming confirmation or searching another volume definition."
      }
    } else {
      "The strongest of the nine conditional interaction cells was not unusual relative to time-misaligned controls. No lookback or horizon is selected."
    },
    "",
    "Raw return, volume-only, additive-control, and participation-quintile results are controls or diagnostics. None can replace the registered interaction.",
    "",
    "This is predictor evidence only. No strategy, P&L, Sharpe, drawdown, allocation, leverage, or live behavior was computed.",
    "",
    "## Artifacts",
    "",
    paste0("- TRAIN surface: `", basename(paths$surface), "`"),
    paste0("- Search control: `", basename(paths$shift_distribution), "`"),
    paste0("- Participation audit: `", basename(paths$participation), "`"),
    paste0("- Source audit: `", basename(paths$source_audit), "`"),
    paste0("- Run specification: `", basename(paths$run_spec), "`")
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("HYP-MOM-09.1 frozen TRAIN stage starting.")
contract <- g5_hm091_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_HYP_MOM_09_1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_HYP_MOM_09_1_REFRESH", FALSE)
run_id <- env_or("GEN5_HYP_MOM_09_1_RUN_ID", "hyp_mom_09_1_qqq_volume_confirmed_continuation_20260822")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

train_query <- query_zone(cfg, contract, contract$train_end, "hyp_mom_09_1_train", refresh)
train_coverage <- coverage_table(train_query$bars, contract, contract$train_end)
source_checks <- source_audit(train_coverage, train_query$bars, contract, contract$train_end)
if (!all(source_checks$passed)) stop("HYP-MOM-09.1 source feasibility audit failed.", call. = FALSE)
train <- g5_hm091_run_train(train_query$bars, contract)
train_split <- split_summary(train$panel, contract)
train_participation <- participation_summary(train$panel, contract)

development <- NULL
development_query <- NULL
if (isTRUE(train$decision$passed[[1L]])) {
  message("TRAIN passed. HYP-MOM-09.1 DEVELOPMENT query is now permitted.")
  development_query <- query_zone(cfg, contract, contract$development_end, "hyp_mom_09_1_development", refresh)
  development_bars <- development_query$bars
  train_bars <- development_bars[as.Date(development_bars$session_date) <= contract$train_end, , drop = FALSE]
  development <- g5_hm091_run_development(train_bars, development_bars, train$nominee, contract)
}

overall_status <- if (is.null(development)) train$overall_status else development$overall_status
paths <- list(
  run_spec = file.path(output_dir, "hm091_run_spec.csv"),
  contract = file.path(output_dir, "hm091_frozen_contract.csv"),
  source_audit = file.path(output_dir, "hm091_source_audit.csv"),
  coverage = file.path(output_dir, "hm091_train_coverage.csv"),
  integrity = file.path(output_dir, "hm091_train_integrity.csv"),
  split = file.path(output_dir, "hm091_train_split_adjustment_audit.csv"),
  construction = file.path(output_dir, "hm091_train_participation_construction_checks.csv"),
  participation = file.path(output_dir, "hm091_train_participation_audit.csv"),
  surface = file.path(output_dir, "hm091_train_surface.csv"),
  shift_distribution = file.path(output_dir, "hm091_train_shift_maxima.csv"),
  decision = file.path(output_dir, "hm091_train_decision.csv"),
  nominee = file.path(output_dir, "hm091_train_nominee.csv"),
  development_stats = file.path(output_dir, "hm091_development_statistics.csv"),
  development_models = file.path(output_dir, "hm091_development_model_comparison.csv"),
  development_bootstrap = file.path(output_dir, "hm091_development_bootstrap.csv"),
  development_gates = file.path(output_dir, "hm091_development_gates.csv"),
  development_years = file.path(output_dir, "hm091_development_years.csv"),
  development_quintiles = file.path(output_dir, "hm091_development_participation_quintiles.csv"),
  surface_png = file.path(visual_dir, "hm091_train_surface.png"),
  shift_png = file.path(visual_dir, "hm091_train_search_control.png"),
  participation_png = file.path(visual_dir, "hm091_train_participation.png"),
  events_png = file.path(visual_dir, "hm091_train_participation_events.png"),
  nominee_png = file.path(visual_dir, "hm091_train_nominee.png"),
  development_png = file.path(visual_dir, "hm091_development_summary.png"),
  report = file.path(output_dir, "hm091_report.md")
)

run_spec <- data.frame(
  schema_version = g5_hm091_schema_version(),
  wrapper = "scripts/inspect/run_hyp_mom_09_1_qqq_volume_confirmed_continuation.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  train_health_max_severity = health_severity(train_query$health),
  train_health_window_impact = "NONE_REQUESTED_RANGE_FULLY_COVERED",
  train_anchor_count = nrow(train$panel$target_matrix),
  train_surface_passed = train$decision$passed[[1L]],
  development_opened = !is.null(development),
  confirmation_opened = FALSE,
  strategy_outcomes_computed = FALSE,
  overall_status = overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$contract)
write_csv(source_checks, paths$source_audit)
write_csv(train_coverage, paths$coverage)
write_csv(train$panel$integrity, paths$integrity)
write_csv(train_split, paths$split)
write_csv(train$panel$construction_checks, paths$construction)
write_csv(train_participation, paths$participation)
write_csv(train$surface, paths$surface)
write_csv(train$shift_distribution, paths$shift_distribution)
write_csv(train$decision, paths$decision)
write_csv(if (nrow(train$nominee)) train$nominee else data.frame(status = "NO_NOMINEE", stringsAsFactors = FALSE), paths$nominee)
plot_surface(train$surface, paths$surface_png, contract)
plot_shift(train$shift_distribution, train$decision, paths$shift_png)
plot_participation(train$panel, paths$participation_png, contract)
plot_participation_events(train$panel, paths$events_png, contract)

if (nrow(train$nominee)) {
  train_pairs <- g5_hm091_cell_vectors(
    train$panel, train$nominee$lookback_sessions, train$nominee$target_sessions, contract
  )
  plot_nominee(train_pairs, train$nominee$cell_id, paths$nominee_png)
  write_csv(development$development_statistics, paths$development_stats)
  write_csv(development$model_comparison, paths$development_models)
  write_csv(development$bootstrap, paths$development_bootstrap)
  write_csv(development$gates, paths$development_gates)
  write_csv(development$year_diagnostics, paths$development_years)
  write_csv(development$participation_quintiles, paths$development_quintiles)
  plot_development(development, paths$development_png)
} else {
  writeLines(
    "DEVELOPMENT was not queried or calculated because the frozen TRAIN interaction surface gate failed.",
    file.path(output_dir, "DEVELOPMENT_NOT_READ.txt")
  )
  grDevices::png(paths$nominee_png, width = 1500, height = 900, res = 150)
  graphics::plot.new()
  graphics::text(0.5, 0.55, "No TRAIN nominee", cex = 2, font = 2)
  graphics::text(0.5, 0.44, "Search-adjusted interaction gate failed; DEVELOPMENT remains unread.", cex = 1.1)
  grDevices::dev.off()
}

writeLines(
  "2024-2025 confirmation was not queried or calculated in this slice.",
  file.path(output_dir, "CONFIRMATION_NOT_READ.txt")
)
writeLines(overall_status, file.path(output_dir, "STATUS.txt"))
write_report(train, development, train_coverage, source_checks, train_split, train_participation, run_spec, paths)
invisible(g5_write_workbench_query_artifacts(train_query, output_dir, "hm091_train_query"))
if (!is.null(development_query)) {
  invisible(g5_write_workbench_query_artifacts(development_query, output_dir, "hm091_development_query"))
}

message("HYP-MOM-09.1 complete: ", overall_status)
message("TRAIN data health: ", run_spec$train_health_max_severity)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report, winslash = "/", mustWork = FALSE))
