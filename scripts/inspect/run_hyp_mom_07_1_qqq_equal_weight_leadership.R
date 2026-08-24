# Run frozen HYP-MOM-07.1 TRAIN, then DEVELOPMENT only if TRAIN passes.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mom_07_1_qqq_equal_weight_leadership.R"))
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
  if (!dir.exists(path)) stop("Could not create HYP-MOM-07.1 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract_table <- function(contract) {
  data.frame(field = names(contract), value = vapply(contract, function(x) paste(x, collapse = ","), character(1)), stringsAsFactors = FALSE)
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
    symbols = contract$symbols,
    universe_name = universe_name,
    universe_roles = c("modified_cap_weight_proxy", "equal_weight_proxy"),
    refresh = refresh,
    repo_root = repo_root
  )
}

coverage_table <- function(bars, contract, requested_end) {
  rows <- lapply(contract$symbols, function(symbol) {
    dates <- sort(unique(as.Date(bars$session_date[bars$symbol == symbol])))
    data.frame(
      symbol = symbol,
      first_session = if (length(dates)) min(dates) else as.Date(NA),
      last_session = if (length(dates)) max(dates) else as.Date(NA),
      row_count = length(dates),
      duplicate_sessions = sum(duplicated(dates)),
      query_start_covered = length(dates) && min(dates) <= contract$query_start,
      requested_end_covered = length(dates) && max(dates) >= as.Date(requested_end),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

source_audit <- function(coverage, contract) {
  data.frame(
    check_id = c(
      "same_universe_methodology", "qqew_inception_precedes_test",
      "qqew_prechange_proxy_boundary", "alpaca_adjusted_daily_coverage",
      "post_change_observations_excluded"
    ),
    passed = c(
      TRUE,
      as.Date("2006-04-19") < contract$query_start,
      contract$confirmation_end < contract$qqew_mandate_change,
      all(coverage$query_start_covered & coverage$requested_end_covered & coverage$duplicate_sessions == 0L),
      contract$confirmation_end < contract$qqew_mandate_change
    ),
    observed = c(
      "Nasdaq NDXE uses the Nasdaq-100 securities with equal initial weights and quarterly rebalance",
      "QQEW inception 2006-04-19",
      "QQEW index change effective 2025-12-22; last admissible session 2025-12-19",
      paste(paste0(coverage$symbol, "=", coverage$first_session, ":", coverage$last_session, "/", coverage$row_count), collapse = ";"),
      "confirmation and all current execution remain capped at 2025-12-19"
    ),
    source = c(
      "https://indexes.nasdaq.com/Index/Overview/NDXE",
      "https://www.ftportfolios.com/retail/etf/etfsummary.aspx?Ticker=QQEW",
      "https://www.ftportfolios.com/retail/etf/etfsummary.aspx?Ticker=QQEW",
      "Gen5 Alpaca SIP adjusted-daily cache audit",
      "Frozen HYP-MOM-07.1 contract"
    ),
    stringsAsFactors = FALSE
  )
}

plot_surface <- function(surface, path, contract) {
  grDevices::png(path, width = 1800, height = 900, res = 150)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  for (metric in c("correlation", "beta")) {
    values <- matrix(NA_real_, nrow = length(contract$lookback_grid), ncol = length(contract$target_grid))
    for (i in seq_len(nrow(surface))) {
      values[match(surface$lookback_sessions[[i]], contract$lookback_grid),
             match(surface$target_sessions[[i]], contract$target_grid)] <- surface[[metric]][[i]]
    }
    limit <- max(abs(values), na.rm = TRUE)
    colors <- grDevices::colorRampPalette(c("#B42318", "#F8FAFC", "#177245"))(101)
    graphics::image(seq_along(contract$target_grid), seq_along(contract$lookback_grid), t(values),
                    col = colors, zlim = c(-limit, limit), axes = FALSE,
                    xlab = "Forward spread horizon H", ylab = "Trailing spread lookback L",
                    main = if (metric == "correlation") "TRAIN spread correlation" else "TRAIN spread slope")
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
  graphics::hist(distribution$maximum_correlation, breaks = 35, col = "#D7E3F4", border = "white",
                 xlab = "Maximum correlation across nine cells",
                 main = "Search-adjusted TRAIN control")
  graphics::abline(v = decision$shift_maximum_p90, col = "#B7791F", lwd = 3, lty = 2)
  graphics::abline(v = decision$observed_maximum_correlation, col = "#166534", lwd = 3)
  graphics::legend("topright", legend = c("Observed maximum", "Shift-null p90"),
                   col = c("#166534", "#B7791F"), lwd = 3, lty = c(1, 2), bty = "n")
}

plot_nominee <- function(pairs, cell_id, path) {
  grDevices::png(path, width = 1500, height = 900, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(pairs$x_spread, pairs$y_spread, pch = 16, cex = 0.55,
                 col = grDevices::adjustcolor("#335C81", alpha.f = 0.35),
                 xlab = "Trailing QQQ minus QQEW log return",
                 ylab = "Forward QQQ minus QQEW log return",
                 main = paste("Frozen TRAIN nominee", cell_id))
  graphics::abline(stats::lm(y_spread ~ x_spread, data = pairs), col = "#B42318", lwd = 3)
  graphics::abline(h = 0, v = 0, col = "#94A3B8", lty = 3)
}

plot_development <- function(result, path) {
  grDevices::png(path, width = 1800, height = 900, res = 150)
  old <- graphics::par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  models <- result$model_comparison
  colors <- ifelse(models$model_id == "SPREAD", "#166534", "#94A3B8")
  graphics::barplot(models$development_mse, names.arg = models$model_id, las = 2, col = colors,
                    ylab = "Mean squared error", main = "Frozen-model DEVELOPMENT loss")
  years <- result$year_diagnostics
  graphics::barplot(years$beta, names.arg = years$year, col = ifelse(years$beta > 0, "#166534", "#B42318"),
                    ylab = "Spread slope", main = "DEVELOPMENT slope by year")
  graphics::abline(h = 0, col = "#64748B")
}

write_report <- function(train, development, coverage, source_checks, run_spec, paths) {
  decision <- train$decision[1L, ]
  lines <- c(
    "# HYP-MOM-07.1 QQQ / Equal-Weight Leadership Results",
    "",
    paste0("Status: `", run_spec$overall_status[[1L]], "`"),
    "",
    "## Question",
    "",
    "Does recent modified-cap-weighted Nasdaq-100 leadership over the same universe under equal weighting predict continued relative leadership?",
    "",
    "## Source admissibility",
    "",
    paste0("- Source and coverage gates: `", sum(source_checks$passed), " / ", nrow(source_checks), "` pass."),
    paste0("- Common instruments: `", paste(unique(coverage$symbol), collapse = ","), "`; requested TRAIN history `", min(coverage$first_session), "` to `", max(coverage$last_session), "`."),
    "- `QQEW` is used only before its documented December 22, 2025 index change. Confirmation and all current execution remain sealed.",
    "",
    "## TRAIN readout",
    "",
    paste0("- Common TRAIN anchors: `", nrow(train$panel$x_spread), "`."),
    paste0("- Observed maximum correlation: `", sprintf("%.6f", decision$observed_maximum_correlation), "`."),
    paste0("- Complete circular-shift maximum-statistic p90: `", sprintf("%.6f", decision$shift_maximum_p90), "`; empirical upper-tail probability `", sprintf("%.6f", decision$empirical_upper_tail_probability), "`."),
    paste0("- TRAIN surface decision: `", decision$status, "`."),
    ""
  )
  if (nrow(train$nominee)) {
    lines <- c(lines,
      paste0("- Frozen nominee: `", train$nominee$cell_id[[1L]], "` with rho `", sprintf("%.6f", train$nominee$correlation[[1L]]), "` and beta `", sprintf("%.6f", train$nominee$beta[[1L]]), "`."),
      "",
      "## DEVELOPMENT readout",
      ""
    )
    stats <- development$development_statistics[1L, ]
    lines <- c(lines,
      paste0("- DEVELOPMENT anchors: `", nrow(development$development_pairs), "`."),
      paste0("- Spread beta: `", sprintf("%.6f", stats$beta), "`; stationary-bootstrap 90% interval `[", sprintf("%.6f", stats$beta_lower_90), ", ", sprintf("%.6f", stats$beta_upper_90), "]`."),
      paste0("- Spearman correlation: `", sprintf("%.6f", stats$spearman), "`."),
      paste0("- Gates: `", sum(development$gates$passed), " / ", nrow(development$gates), "` pass."),
      paste0("- DEVELOPMENT decision: `", development$overall_status, "`."),
      ""
    )
  } else {
    lines <- c(lines,
      "## DEVELOPMENT boundary",
      "",
      "DEVELOPMENT was not queried or calculated because the frozen TRAIN surface gate failed.",
      ""
    )
  }
  lines <- c(lines,
    "## Interpretation",
    "",
    if (nrow(train$nominee)) {
      if (all(development$gates$passed)) "The predictor survived historical DEVELOPMENT and requires operator review before sealed confirmation." else "The frozen nominee did not survive every DEVELOPMENT gate. Stop without consuming confirmation or searching neighboring variants."
    } else "The nine-cell surface was not unusual relative to time-misaligned controls. No lookback/horizon is selected and confirmation stays sealed.",
    "",
    "This is predictor evidence only. No strategy, P&L, Sharpe, drawdown, allocation, leverage, or live behavior was computed.",
    "",
    "## Artifacts",
    "",
    paste0("- TRAIN surface: `", basename(paths$surface), "`"),
    paste0("- Search control: `", basename(paths$shift_distribution), "`"),
    paste0("- Source audit: `", basename(paths$source_audit), "`"),
    paste0("- Run specification: `", basename(paths$run_spec), "`")
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("HYP-MOM-07.1 frozen TRAIN stage starting.")
contract <- g5_hm071_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_HYP_MOM_07_1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_HYP_MOM_07_1_REFRESH", FALSE)
run_id <- env_or("GEN5_HYP_MOM_07_1_RUN_ID", "hyp_mom_07_1_qqq_equal_weight_leadership_20260822")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

train_query <- query_zone(cfg, contract, contract$train_end, "hyp_mom_07_1_train", refresh)
train_coverage <- coverage_table(train_query$bars, contract, contract$train_end)
source_checks <- source_audit(train_coverage, contract)
if (!all(source_checks$passed)) stop("HYP-MOM-07.1 source feasibility audit failed.", call. = FALSE)
train <- g5_hm071_run_train(train_query$bars, contract)

development <- NULL
development_query <- NULL
if (isTRUE(train$decision$passed[[1L]])) {
  message("TRAIN passed. HYP-MOM-07.1 DEVELOPMENT query is now permitted.")
  development_query <- query_zone(cfg, contract, contract$development_end, "hyp_mom_07_1_development", refresh)
  development_bars <- development_query$bars
  train_bars <- development_bars[as.Date(development_bars$session_date) <= contract$train_end, , drop = FALSE]
  development <- g5_hm071_run_development(train_bars, development_bars, train$nominee, contract)
}

overall_status <- if (is.null(development)) train$overall_status else development$overall_status
paths <- list(
  run_spec = file.path(output_dir, "hm071_run_spec.csv"),
  contract = file.path(output_dir, "hm071_frozen_contract.csv"),
  source_audit = file.path(output_dir, "hm071_source_audit.csv"),
  coverage = file.path(output_dir, "hm071_train_coverage.csv"),
  integrity = file.path(output_dir, "hm071_train_integrity.csv"),
  surface = file.path(output_dir, "hm071_train_surface.csv"),
  shift_distribution = file.path(output_dir, "hm071_train_shift_maxima.csv"),
  decision = file.path(output_dir, "hm071_train_decision.csv"),
  nominee = file.path(output_dir, "hm071_train_nominee.csv"),
  development_stats = file.path(output_dir, "hm071_development_statistics.csv"),
  development_models = file.path(output_dir, "hm071_development_model_comparison.csv"),
  development_gates = file.path(output_dir, "hm071_development_gates.csv"),
  development_years = file.path(output_dir, "hm071_development_years.csv"),
  development_phases = file.path(output_dir, "hm071_development_phases.csv"),
  surface_png = file.path(visual_dir, "hm071_train_surface.png"),
  shift_png = file.path(visual_dir, "hm071_train_search_control.png"),
  nominee_png = file.path(visual_dir, "hm071_train_nominee.png"),
  development_png = file.path(visual_dir, "hm071_development_summary.png"),
  report = file.path(output_dir, "hm071_report.md")
)

run_spec <- data.frame(
  schema_version = g5_hm071_schema_version(),
  wrapper = "scripts/inspect/run_hyp_mom_07_1_qqq_equal_weight_leadership.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  train_health_max_severity = health_severity(train_query$health),
  train_anchor_count = nrow(train$panel$x_spread),
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
write_csv(train$surface, paths$surface)
write_csv(train$shift_distribution, paths$shift_distribution)
write_csv(train$decision, paths$decision)
write_csv(if (nrow(train$nominee)) train$nominee else data.frame(status = "NO_NOMINEE", stringsAsFactors = FALSE), paths$nominee)
plot_surface(train$surface, paths$surface_png, contract)
plot_shift(train$shift_distribution, train$decision, paths$shift_png)

if (nrow(train$nominee)) {
  train_pairs <- g5_hm071_cell_vectors(train$panel, train$nominee$lookback_sessions, train$nominee$target_sessions, contract)
  plot_nominee(train_pairs, train$nominee$cell_id, paths$nominee_png)
  write_csv(development$development_statistics, paths$development_stats)
  write_csv(development$model_comparison, paths$development_models)
  write_csv(development$gates, paths$development_gates)
  write_csv(development$year_diagnostics, paths$development_years)
  write_csv(development$phase_diagnostics, paths$development_phases)
  plot_development(development, paths$development_png)
} else {
  grDevices::png(paths$nominee_png, width = 1500, height = 900, res = 150)
  graphics::plot.new(); graphics::text(0.5, 0.55, "No TRAIN nominee", cex = 2, font = 2)
  graphics::text(0.5, 0.44, "Search-adjusted surface gate failed; DEVELOPMENT remains unread.", cex = 1.1)
  grDevices::dev.off()
}

write_report(train, development, train_coverage, source_checks, run_spec, paths)
invisible(g5_write_workbench_query_artifacts(train_query, output_dir, "hm071_train_query"))
if (!is.null(development_query)) invisible(g5_write_workbench_query_artifacts(development_query, output_dir, "hm071_development_query"))

message("HYP-MOM-07.1 complete: ", overall_status)
message("TRAIN data health: ", run_spec$train_health_max_severity)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report, winslash = "/", mustWork = FALSE))
