# Run the frozen LIT-MR-04.1 pair and LIT-MR-05.1 triplet textbook exercises.

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
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mr_kalman_core.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mr_04_1_kalman_pair_poc.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mr_05_1_kalman_triplet_poc.R"))
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
  if (!dir.exists(path)) stop("Could not create Kalman output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

colors <- list(
  navy = "#123047",
  blue = "#3D8DFF",
  cyan = "#26C6DA",
  green = "#177245",
  red = "#B42318",
  amber = "#F59E0B",
  slate = "#64748B",
  light = "#E2E8F0",
  pale = "#EAF4FB",
  purple = "#7C3AED"
)

coverage_table <- function(bars, symbols, start_date, end_date) {
  reference <- sort(unique(bars$session_date))
  do.call(rbind, lapply(symbols, function(symbol) {
    observed <- sort(unique(bars$session_date[bars$symbol == symbol]))
    missing <- setdiff(reference, observed)
    data.frame(
      symbol = symbol,
      observed_sessions = length(observed),
      reference_sessions = length(reference),
      first_session = min(observed),
      last_session = max(observed),
      missing_sessions = length(missing),
      status = ifelse(
        length(missing) == 0L &&
          min(observed) <= start_date &&
          max(observed) >= end_date,
        "PASS",
        "FAIL"
      ),
      stringsAsFactors = FALSE
    )
  }))
}

summary_row <- function(result) {
  completed <- result$trades[result$trades$completed, , drop = FALSE]
  data.frame(
    literature_id = result$contract$literature_id,
    orientation = paste0(
      result$contract$response_symbol, " ~ ",
      paste(result$contract$predictor_symbols, collapse = " + ")
    ),
    structural_pass = result$structural_pass,
    full_train_pass = result$full_pass,
    gates_passed = sum(result$gates$status == "PASS"),
    completed_trades = nrow(completed),
    long_trades = sum(completed$direction == 1L),
    short_trades = sum(completed$direction == -1L),
    mean_primary_net_trade_return = if (nrow(completed)) {
      mean(completed$primary_net_additive_return)
    } else NA_real_,
    trade_hit_rate = if (nrow(completed)) {
      mean(completed$primary_net_additive_return > 0)
    } else NA_real_,
    trade_bootstrap_lower_90 = result$trade_bootstrap$lower_90,
    random_sign_p90 = result$random_control$random_p90,
    forward_convergence_correlation = result$convergence_bootstrap$estimate,
    forward_convergence_upper_90 = result$convergence_bootstrap$upper_90,
    result$performance,
    status = result$status,
    stringsAsFactors = FALSE
  )
}

plot_gate_matrix <- function(pair, triplet, path) {
  gates <- rbind(
    as.integer(pair$gates$status == "PASS"),
    as.integer(triplet$gates$status == "PASS")
  )
  rownames(gates) <- c("LIT-MR-04.1 pair", "LIT-MR-05.1 triplet")
  colnames(gates) <- paste0("G", 1:8)
  png(path, width = 1800, height = 760, res = 150)
  old <- par(mar = c(7, 12, 4, 2))
  image(
    seq_len(ncol(gates)),
    seq_len(nrow(gates)),
    t(gates),
    col = c(colors$red, colors$green),
    breaks = c(-0.5, 0.5, 1.5),
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = "Frozen TRAIN conjunction: green PASS, red FAIL"
  )
  axis(1, at = seq_len(8L), labels = colnames(gates))
  axis(2, at = seq_len(2L), labels = rownames(gates), las = 1)
  box()
  mtext(
    "G1 integrity | G2 finite filter | G3 semantics | G4 support | G5 mean > 0 | G6 q05 > 0 | G7 random-sign | G8 convergence",
    side = 1, line = 4.2, cex = 0.8, col = colors$slate
  )
  par(old)
}

plot_coefficients <- function(result, path) {
  rows <- result$rows
  contract <- result$contract
  k <- length(contract$predictor_symbols)
  png(path, width = 2000, height = 620 * k, res = 150)
  old <- par(mfrow = c(k, 1), mar = c(5, 6, 4, 2))
  for (j in seq_len(k)) {
    date <- rows$session_date
    beta <- rows[[paste0("posterior_beta_", j)]]
    sd <- rows[[paste0("posterior_beta_", j, "_sd")]]
    rolling <- rows[[paste0("rolling_beta_", j)]]
    valid <- is.finite(beta) & is.finite(sd)
    ylim <- range(c(beta[valid] - 2 * sd[valid], beta[valid] + 2 * sd[valid], rolling), na.rm = TRUE)
    plot(
      date, beta, type = "n", ylim = ylim,
      xlab = "Signal close", ylab = "Slope",
      main = paste0(
        contract$literature_id, ": dynamic ", contract$predictor_symbols[[j]],
        " hedge ratio"
      )
    )
    polygon(
      c(date[valid], rev(date[valid])),
      c(beta[valid] - 2 * sd[valid], rev(beta[valid] + 2 * sd[valid])),
      col = grDevices::adjustcolor(colors$blue, alpha.f = 0.18),
      border = NA
    )
    lines(date, beta, col = colors$navy, lwd = 2)
    lines(date, rolling, col = colors$amber, lwd = 1.3)
    legend(
      "topleft",
      c("Kalman posterior", "Kalman +/- 2 state SD", "Rolling OLS 20"),
      col = c(colors$navy, colors$blue, colors$amber),
      lwd = c(2, 8, 1.3), bty = "n"
    )
  }
  par(old)
}

plot_innovation_and_state <- function(result, path) {
  rows <- result$rows
  png(path, width = 2100, height = 1200, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 6, 4, 2))
  plot(
    rows$session_date, rows$z_score,
    type = "l", col = colors$navy, lwd = 1,
    xlab = "Signal close", ylab = "Pre-update innovation z",
    main = paste0(result$contract$literature_id, ": surprise first, update second")
  )
  abline(h = c(-1, 0, 1), col = c(colors$red, colors$slate, colors$red), lty = c(2, 1, 2))
  points(
    rows$session_date[rows$signal_action == "enter_long_spread"],
    rows$z_score[rows$signal_action == "enter_long_spread"],
    pch = 24, bg = colors$green, col = colors$green
  )
  points(
    rows$session_date[rows$signal_action == "enter_short_spread"],
    rows$z_score[rows$signal_action == "enter_short_spread"],
    pch = 25, bg = colors$red, col = colors$red
  )
  plot(
    rows$session_date, rows$target_state,
    type = "s", col = colors$blue, lwd = 2,
    ylim = c(-1.2, 1.2), yaxt = "n",
    xlab = "Signal close", ylab = "Target state",
    main = "Bounded state machine; no same-bar reversal"
  )
  axis(2, at = c(-1, 0, 1), labels = c("short spread", "flat", "long spread"))
  abline(h = 0, col = colors$slate, lty = 2)
  par(old)
}

plot_strategy_anatomy <- function(result, path) {
  replay <- result$replay
  equity <- cumprod(1 + replay$primary_net_return)
  peak <- cummax(c(1, equity))[-1L]
  drawdown <- equity / peak - 1
  png(path, width = 2100, height = 1450, res = 150)
  old <- par(mfrow = c(3, 1), mar = c(5, 6, 4, 2))
  plot(
    replay$execution_date, equity,
    type = "l", col = colors$navy, lwd = 2,
    xlab = "Execution date", ylab = "Growth of $1",
    main = paste0(result$contract$literature_id, ": TRAIN strategy anatomy after 5 bp costs")
  )
  abline(h = 1, col = colors$slate, lty = 2)
  plot(
    replay$execution_date, drawdown,
    type = "h", col = colors$red, lwd = 2,
    xlab = "Execution date", ylab = "Drawdown",
    main = "Underwater curve"
  )
  abline(h = 0, col = colors$slate)
  plot(
    replay$execution_date, replay$gross_return * 10000,
    type = "h",
    col = ifelse(replay$gross_return >= 0, colors$green, colors$red),
    xlab = "Execution date", ylab = "Gross return (bp)",
    main = "Bar-by-bar spread P&L; costs are charged separately"
  )
  abline(h = 0, col = colors$slate)
  par(old)
}

plot_calibration <- function(pair, triplet, path) {
  combined <- rbind(
    transform(pair$calibration, lane = "04.1 pair"),
    transform(triplet$calibration, lane = "05.1 triplet")
  )
  png(path, width = 1900, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(7, 6, 4, 2))
  labels <- paste(combined$lane, combined$estimator, sep = "\n")
  barplot(
    combined$rmse,
    names.arg = labels,
    las = 2,
    col = rep(c(colors$blue, colors$amber), 2),
    ylab = "One-step price RMSE",
    main = "Forecast error: lower is better"
  )
  barplot(
    combined$z_lag_1,
    names.arg = labels,
    las = 2,
    col = rep(c(colors$blue, colors$amber), 2),
    ylab = "Lag-one standardized-error correlation",
    main = "Residual memory: zero is ideal"
  )
  abline(h = 0, col = colors$slate)
  par(old)
}

write_lane_artifacts <- function(result, prefix, output_dir, visual_dir) {
  paths <- list(
    summary = file.path(output_dir, paste0(prefix, "_train_summary.csv")),
    gates = file.path(output_dir, paste0(prefix, "_train_gates.csv")),
    integrity = file.path(output_dir, paste0(prefix, "_integrity.csv")),
    initialization = file.path(output_dir, paste0(prefix, "_initialization.csv")),
    coefficients = file.path(output_dir, paste0(prefix, "_coefficient_metrics.csv")),
    calibration = file.path(output_dir, paste0(prefix, "_calibration.csv")),
    state_path = file.path(output_dir, paste0(prefix, "_state_path.csv")),
    replay = file.path(output_dir, paste0(prefix, "_train_replay.csv")),
    trades = file.path(output_dir, paste0(prefix, "_train_trades.csv")),
    convergence = file.path(output_dir, paste0(prefix, "_forward_convergence.csv")),
    coefficient_png = file.path(visual_dir, paste0(prefix, "_coefficient_paths.png")),
    innovation_png = file.path(visual_dir, paste0(prefix, "_innovation_and_state.png")),
    anatomy_png = file.path(visual_dir, paste0(prefix, "_strategy_anatomy.png"))
  )
  init <- result$filter$initialization
  init_table <- data.frame(
    parameter = c(
      paste0("theta_", seq_along(init$theta)),
      paste0("p0_diag_", seq_along(diag(init$p))),
      paste0("q_diag_", seq_along(diag(init$q))),
      "observation_variance_r"
    ),
    value = c(init$theta, diag(init$p), diag(init$q), init$r),
    stringsAsFactors = FALSE
  )
  state_columns <- c(
    "session_date", "innovation", "innovation_variance", "z_score",
    "target_state", "signal_action",
    grep("^(prior|posterior|rolling)_", names(result$rows), value = TRUE)
  )
  write_csv(summary_row(result), paths$summary)
  write_csv(result$gates, paths$gates)
  write_csv(result$integrity, paths$integrity)
  write_csv(init_table, paths$initialization)
  write_csv(result$coefficients, paths$coefficients)
  write_csv(result$calibration, paths$calibration)
  write_csv(result$rows[state_columns], paths$state_path)
  write_csv(result$replay, paths$replay)
  write_csv(result$trades, paths$trades)
  write_csv(result$convergence, paths$convergence)
  plot_coefficients(result, paths$coefficient_png)
  plot_innovation_and_state(result, paths$innovation_png)
  plot_strategy_anatomy(result, paths$anatomy_png)
  paths
}

write_report <- function(path, run_spec, pair, triplet, development, artifacts) {
  pair_summary <- summary_row(pair)
  triplet_summary <- summary_row(triplet)
  format_lane <- function(summary) {
    c(
      paste0("- Status: `", summary$status, "`."),
      paste0("- Gates: `", summary$gates_passed, " / 8`; completed trades: `",
        summary$completed_trades, "` (`", summary$long_trades, "` long, `",
        summary$short_trades, "` short)."),
      sprintf(
        "- Primary mean: `%.2f bp/trade`; hit rate: `%.1f%%`; cumulative: `%.2f%%`; max drawdown: `%.2f%%`.",
        10000 * summary$mean_primary_net_trade_return,
        100 * summary$trade_hit_rate,
        100 * summary$cumulative_return,
        100 * summary$maximum_drawdown
      ),
      sprintf(
        "- Convergence correlation: `%.4f` (90%% upper bound `%.4f`).",
        summary$forward_convergence_correlation,
        summary$forward_convergence_upper_90
      ),
      sprintf(
        "- Bar-level spread-direction hit: `%.1f%%`; response up/down accuracy: `%.1f%%`.",
        100 * summary$spread_direction_hit_rate,
        100 * summary$response_up_down_accuracy
      )
    )
  }
  lines <- c(
    "# Kalman Dynamic-Regression Textbook Exercises",
    "",
    paste0("Status: `", run_spec$overall_status, "`"),
    "",
    "## Purpose",
    "",
    "Work Chan Example 3.3 as a causal pair exercise, then extend the same",
    "scalar-observation filter to one frozen asymmetric triplet. This packet",
    "teaches the estimator and tests the trading interpretation; it does not",
    "claim that adaptivity creates alpha.",
    "",
    "## What is source-derived versus Gen5-designed",
    "",
    "- Source: random-walk slope/intercept state, innovation variance, Kalman",
    "  gain, delta 0.0001, +/-1 innovation entries, and zero crossing exits.",
    "- Gen5: 252-session TRAIN OLS scale initialization, scale-aware Q,",
    "  next-open execution, daily gross normalization, costs, eight gates,",
    "  rolling-OLS comparison, and conditional OOS.",
    "- The signal is the pre-update innovation. The post-update residual is",
    "  mechanically smaller and is not convergence evidence.",
    "",
    "## LIT-MR-04.1 — EWC ~ EWA",
    "",
    format_lane(pair_summary),
    "",
    "## LIT-MR-05.1 — EWC ~ EWA + IGE",
    "",
    format_lane(triplet_summary),
    "",
    "## OOS boundary",
    "",
    if (is.null(development$pair)) {
      "- Pair DEVELOPMENT was not queried for strategy evaluation because TRAIN did not pass all gates."
    } else {
      paste0("- Pair DEVELOPMENT completed once: `",
        development$pair$summary$cumulative_return, "` cumulative return.")
    },
    if (is.null(development$triplet)) {
      "- Triplet DEVELOPMENT was not queried for strategy evaluation because TRAIN did not pass all gates."
    } else {
      paste0("- Triplet DEVELOPMENT completed once: `",
        development$triplet$summary$cumulative_return, "` cumulative return.")
    },
    "- Confirmation beginning 2024-01-01 remains sealed.",
    "",
    "## References",
    "",
    "- Ernest P. Chan, *Algorithmic Trading* (2013), printed pp. 75-82, PDF",
    "  pp. 93-100.",
    "- Frozen contracts: `literature_studies/docs/GEN5_LIT_MR_04_1_KALMAN_PAIR_POC_CONTRACT.md`",
    "  and `literature_studies/docs/GEN5_LIT_MR_05_1_KALMAN_TRIPLET_POC_CONTRACT.md`.",
    "",
    "## Artifact surface",
    "",
    paste0("- Output: `", run_spec$output_dir, "`."),
    paste0("- Gate matrix: `", artifacts$gate_png, "`."),
    paste0("- Calibration comparison: `", artifacts$calibration_png, "`.")
  )
  writeLines(lines, path, useBytes = TRUE)
}

message("Kalman textbook POCs starting.")
pair_contract <- g5_mr04_validate_contract()
triplet_contract <- g5_mr05_validate_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_KALMAN_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_KALMAN_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_KALMAN_RUN_ID",
  "lit_mr_04_1_05_1_kalman_textbook_20260729"
)
as_of_timestamp <- env_or(
  "GEN5_KALMAN_AS_OF_TIMESTAMP",
  pair_contract$as_of_timestamp
)
if (!identical(as_of_timestamp, pair_contract$as_of_timestamp)) {
  stop("GEN5_KALMAN_AS_OF_TIMESTAMP must match the frozen contract.", call. = FALSE)
}

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

train_query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = pair_contract$train_start,
  end_date = pair_contract$train_end,
  as_of_timestamp = as_of_timestamp,
  symbols = triplet_contract$symbols,
  universe_name = "lit_mr_04_1_05_1_kalman_train",
  universe_roles = "frozen_kalman_textbook_legs",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(train_query$bars)) stop("Kalman TRAIN query returned no bars.", call. = FALSE)
coverage <- coverage_table(
  train_query$bars,
  triplet_contract$symbols,
  pair_contract$train_start,
  pair_contract$train_end
)
health_max <- g5_health_max_severity(train_query$health)
analysis_health <- if (
  !any(train_query$health$severity == "ERROR") &&
    all(coverage$status == "PASS")
) "PASS" else "FAIL"
if (!identical(analysis_health, "PASS")) {
  stop("Kalman TRAIN coverage or data health failed.", call. = FALSE)
}

pair_bars <- train_query$bars[
  train_query$bars$symbol %in% pair_contract$symbols,
  ,
  drop = FALSE
]
pair <- g5_mr04_run_train(pair_bars, analysis_health)
if (!pair$structural_pass) {
  stop(
    "LIT-MR-04.1 shared filter failed structural gates; triplet is blocked.",
    call. = FALSE
  )
}
triplet <- g5_mr05_run_train(train_query$bars, analysis_health)

development <- list(pair = NULL, triplet = NULL)
development_query_artifacts <- list()
for (lane in c("pair", "triplet")) {
  train_result <- if (lane == "pair") pair else triplet
  contract <- train_result$contract
  if (!train_result$full_pass) next
  query <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = contract$train_start,
    end_date = contract$development_end,
    as_of_timestamp = as_of_timestamp,
    symbols = contract$symbols,
    universe_name = paste0("lit_mr_kalman_", lane, "_development"),
    universe_roles = "train_passed_kalman_legs",
    refresh = refresh,
    repo_root = repo_root
  )
  if (any(query$health$severity == "ERROR")) {
    stop(paste0(lane, " DEVELOPMENT query health contains ERROR."), call. = FALSE)
  }
  development[[lane]] <- g5_kf_run_development(
    query$bars, contract, data_health_status = "PASS"
  )
  development_query_artifacts[[lane]] <- g5_write_workbench_query_artifacts(
    query, output_dir, paste0("kalman_", lane, "_development_query")
  )
}

pair_paths <- write_lane_artifacts(pair, "mr04", output_dir, visual_dir)
triplet_paths <- write_lane_artifacts(triplet, "mr05", output_dir, visual_dir)
artifact_paths <- list(
  run_spec = file.path(output_dir, "kalman_run_spec.csv"),
  coverage = file.path(output_dir, "kalman_train_coverage.csv"),
  combined_summary = file.path(output_dir, "kalman_train_summary.csv"),
  report = file.path(output_dir, "kalman_textbook_report.md"),
  gate_png = file.path(visual_dir, "kalman_train_gate_matrix.png"),
  calibration_png = file.path(visual_dir, "kalman_calibration_comparison.png")
)
plot_gate_matrix(pair, triplet, artifact_paths$gate_png)
plot_calibration(pair, triplet, artifact_paths$calibration_png)

later_opened <- !is.null(development$pair) || !is.null(development$triplet)
overall_status <- paste(
  pair$status,
  triplet$status,
  sep = "__"
)
run_spec <- data.frame(
  schema_version = g5_kf_schema_version(),
  run_id = run_id,
  wrapper = "literature_studies/scripts/run_gen5_lit_mr_kalman_textbook_pocs.R",
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  train_coverage_status = analysis_health,
  train_start = pair_contract$train_start,
  train_end = pair_contract$train_end,
  development_start = pair_contract$development_start,
  development_end = pair_contract$development_end,
  pair_full_train_pass = pair$full_pass,
  triplet_full_train_pass = triplet$full_pass,
  later_outcomes_opened = later_opened,
  confirmation_opened = FALSE,
  overall_status = overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
write_csv(run_spec, artifact_paths$run_spec)
write_csv(coverage, artifact_paths$coverage)
write_csv(rbind(summary_row(pair), summary_row(triplet)), artifact_paths$combined_summary)
train_query_artifacts <- g5_write_workbench_query_artifacts(
  train_query, output_dir, "kalman_train_workbench_query"
)
if (!is.null(development$pair)) {
  write_csv(development$pair$summary, file.path(output_dir, "mr04_development_summary.csv"))
  write_csv(development$pair$trades, file.path(output_dir, "mr04_development_trades.csv"))
  write_csv(development$pair$replay, file.path(output_dir, "mr04_development_replay.csv"))
}
if (!is.null(development$triplet)) {
  write_csv(development$triplet$summary, file.path(output_dir, "mr05_development_summary.csv"))
  write_csv(development$triplet$trades, file.path(output_dir, "mr05_development_trades.csv"))
  write_csv(development$triplet$replay, file.path(output_dir, "mr05_development_replay.csv"))
}
write_report(
  artifact_paths$report,
  run_spec,
  pair,
  triplet,
  development,
  c(artifact_paths, pair_paths, triplet_paths, train_query_artifacts$paths)
)

message("Kalman textbook POCs complete: ", overall_status)
message("Data health: ", health_max)
message("Pair gates: ", sum(pair$gates$status == "PASS"), "/8")
message("Triplet gates: ", sum(triplet$gates$status == "PASS"), "/8")
message("Later outcomes opened: ", later_opened)
message("Confirmation opened: FALSE")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report, winslash = "/", mustWork = FALSE))
