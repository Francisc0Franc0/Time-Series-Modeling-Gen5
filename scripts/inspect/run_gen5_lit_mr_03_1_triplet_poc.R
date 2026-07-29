# Run the frozen daily LIT-MR-03.1 Johansen triplet POC.

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
source(file.path(repo_root, "R", "gen5_lit_mr_03_1_triplet_poc.R"))
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
  if (!dir.exists(path)) stop("Could not create triplet output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

bind_results <- function(batch, extractor) {
  rows <- lapply(names(batch$results), function(id) {
    x <- extractor(batch$results[[id]])
    if (is.null(x) || !nrow(x)) return(NULL)
    x$triplet_id <- id
    x
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
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
  pale = "#EAF4FB"
)

plot_rank_diagnostics <- function(summary, path) {
  x <- summary[order(summary$triplet_index, decreasing = TRUE), , drop = FALSE]
  values <- cbind(x$p_rank_0, x$p_rank_at_most_1)
  values[!is.finite(values)] <- 1
  png(path, width = 1900, height = 1200, res = 150)
  old <- par(mar = c(7, 12, 4, 2))
  positions <- barplot(
    t(values),
    beside = TRUE,
    horiz = TRUE,
    names.arg = x$triplet_id,
    las = 1,
    col = c(colors$blue, colors$amber),
    xlim = c(0, 1),
    xlab = "Seeded bootstrap p-value",
    main = "Rank-one requires p(rank 0) < 0.05 and p(rank <= 1) >= 0.05"
  )
  abline(v = 0.05, col = colors$red, lty = 2, lwd = 2)
  legend(
    "bottomright",
    c("Null: rank 0", "Null: rank <= 1"),
    fill = c(colors$blue, colors$amber),
    bty = "n"
  )
  par(old)
}

plot_gate_heatmap <- function(batch, path) {
  summary <- batch$summary[order(batch$summary$triplet_index), , drop = FALSE]
  matrix_values <- matrix(
    0,
    nrow = nrow(summary),
    ncol = 8L,
    dimnames = list(summary$triplet_id, paste0("G", 1:8))
  )
  for (i in seq_len(nrow(summary))) {
    gates <- batch$gate_detail[
      batch$gate_detail$triplet_id == summary$triplet_id[[i]],
      ,
      drop = FALSE
    ]
    matrix_values[i, gates$gate_id] <- as.integer(gates$status == "PASS")
  }
  png(path, width = 1800, height = 1050, res = 150)
  old <- par(mar = c(8, 13, 4, 2))
  image(
    seq_len(ncol(matrix_values)),
    seq_len(nrow(matrix_values)),
    t(matrix_values),
    col = c(colors$red, colors$green),
    breaks = c(-0.5, 0.5, 1.5),
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = "Frozen TRAIN gates: green PASS, red FAIL"
  )
  axis(1, at = seq_len(8L), labels = paste0("G", 1:8))
  axis(2, at = seq_len(nrow(matrix_values)), labels = rownames(matrix_values), las = 1)
  box()
  mtext(
    "G1 integrity | G2 I(1) | G3 rank 1 | G4 vector | G5 half-life | G6 support | G7 net+CI | G8 convergence",
    side = 1, line = 4.5, cex = 0.78, col = colors$slate
  )
  par(old)
}

plot_dollar_exposures <- function(batch, path) {
  summary <- batch$summary[order(batch$summary$triplet_index), , drop = FALSE]
  exposures <- t(vapply(summary$triplet_id, function(id) {
    result <- batch$results[[id]]
    last_prices <- as.numeric(tail(result$panel[paste0("close_", 1:3)], 1L))
    dollar <- result$fit$beta * last_prices
    dollar / sum(abs(dollar))
  }, numeric(3L)))
  rownames(exposures) <- summary$triplet_id
  png(path, width = 1900, height = 1200, res = 150)
  old <- par(mar = c(8, 13, 4, 2))
  bars <- barplot(
    t(exposures[nrow(exposures):1L, , drop = FALSE]),
    beside = TRUE,
    horiz = TRUE,
    names.arg = rev(rownames(exposures)),
    las = 1,
    col = c(colors$blue, colors$amber, colors$cyan),
    xlab = "Gross-normalized dollar exposure at TRAIN end",
    main = "Johansen coefficients become executable dollar weights through prices"
  )
  abline(v = 0, col = colors$slate)
  legend("bottomright", c("Leg 1", "Leg 2", "Leg 3"), fill = c(
    colors$blue, colors$amber, colors$cyan
  ), bty = "n")
  par(old)
}

plot_train_tapes <- function(batch, path) {
  fixed_ids <- c(
    "T01_EWA_EWC_IGE", "T02_GLD_GDX_USO",
    "T03_SPY_IVV_VOO", "T04_SHY_IEF_TLT"
  )
  png(path, width = 2200, height = 1600, res = 150)
  old <- par(mfrow = c(2, 2), mar = c(5, 5, 4, 2))
  for (id in fixed_ids) {
    x <- batch$results[[id]]$indicators
    plot(
      x$session_date,
      x$z_score,
      type = "l",
      lwd = 1,
      col = colors$navy,
      xlab = "TRAIN signal close",
      ylab = "Frozen-vector spread z-score",
      main = id
    )
    abline(h = c(-1, 0, 1), col = c(colors$red, colors$slate, colors$red), lty = c(2, 1, 2))
  }
  par(old)
}

plot_train_equity <- function(batch, path) {
  png(path, width = 1900, height = 1150, res = 150)
  old <- par(mar = c(6, 6, 4, 2))
  first <- TRUE
  palette <- grDevices::hcl.colors(length(batch$results), "Dark 3")
  for (i in seq_along(batch$results)) {
    replay <- batch$results[[i]]$replay
    equity <- cumprod(1 + replay$primary_net_return)
    if (first) {
      plot(
        replay$execution_date, equity,
        type = "l", lwd = 2, col = palette[[i]],
        xlab = "TRAIN execution date", ylab = "Growth of $1 after primary costs",
        ylim = range(unlist(lapply(batch$results, function(x) {
          cumprod(1 + x$replay$primary_net_return)
        })), finite = TRUE),
        main = "All eight TRAIN replays shown; this is not an OOS claim"
      )
      first <- FALSE
    } else {
      lines(replay$execution_date, equity, lwd = 2, col = palette[[i]])
    }
  }
  abline(h = 1, col = colors$slate, lty = 2)
  legend(
    "bottomleft", names(batch$results),
    col = palette, lwd = 2, bty = "n", cex = 0.72, ncol = 2
  )
  par(old)
}

plot_oos_anatomy <- function(development, path) {
  replay <- development$replay
  indicators <- development$indicators
  indicators <- indicators[
    indicators$session_date >= as.Date("2021-01-01") &
      indicators$session_date <= as.Date("2023-12-29"),
    ,
    drop = FALSE
  ]
  png(path, width = 2100, height = 1500, res = 150)
  old <- par(mfrow = c(3, 1), mar = c(4, 6, 3, 2))
  plot(
    indicators$session_date, indicators$z_score,
    type = "l", col = colors$navy,
    xlab = "", ylab = "z-score", main = "OOS DEVELOPMENT signal anatomy"
  )
  abline(h = c(-1, 0, 1), col = c(colors$red, colors$slate, colors$red), lty = c(2, 1, 2))
  plot(
    replay$execution_date, replay$target_state,
    type = "s", col = colors$blue, ylim = c(-1.2, 1.2),
    xlab = "", ylab = "Position state"
  )
  plot(
    replay$execution_date, cumprod(1 + replay$primary_net_return),
    type = "l", lwd = 3, col = colors$green,
    xlab = "DEVELOPMENT execution date", ylab = "Growth of $1"
  )
  abline(h = 1, col = colors$slate, lty = 2)
  par(old)
}

write_report <- function(path, batch, run_spec, development, artifact_paths) {
  summary <- batch$summary
  rank_one <- summary[summary$rank_one, , drop = FALSE]
  full_pass <- summary[summary$full_gate_pass, , drop = FALSE]
  lines <- c(
    "# LIT-MR-03.1 Johansen Triplet POC Readout",
    "",
    paste0("Status: `", run_spec$overall_status, "`."),
    "",
    "## Frozen design",
    "",
    "- Eight daily triplets were predeclared before outcomes.",
    "- Every triplet was estimated and evaluated on 2016-2020 TRAIN only.",
    "- Johansen rank uses price levels, one VAR lag, a constant, and 1,000",
    "  seeded null simulations.",
    "- The leading TRAIN vector feeds a 20-session +/-1z, zero-exit, next-open",
    "  triplet replay with 5 bp per one-way weight change.",
    "- Registry order, not observed return, resolves multiple full passes.",
    "",
    "## TRAIN readout",
    "",
    paste0("- Rank-one diagnostic passes: `", nrow(rank_one), " / ", nrow(summary), "`."),
    paste0("- Full eight-gate passes: `", nrow(full_pass), " / ", nrow(summary), "`."),
    paste0("- Nominated triplet: `",
      ifelse(is.na(batch$nominated_triplet_id), "NONE", batch$nominated_triplet_id),
      "`."),
    ""
  )
  for (i in seq_len(nrow(summary))) {
    lines <- c(
      lines,
      paste0(
        "- `", summary$triplet_id[[i]], "`: rank-one=",
        summary$rank_one[[i]], "; vector cosine ",
        sprintf("%.3f", summary$vector_cosine[[i]]), "; half-life ",
        sprintf("%.1f", summary$spread_half_life[[i]]), "; mean net ",
        sprintf("%.1f bp/trade", 10000 * summary$mean_net_trade_return[[i]]),
        "; gates ", summary$gates_passed[[i]], "/8."
      )
    )
  }
  lines <- c(
    lines,
    "",
    "## OOS boundary",
    "",
    if (is.null(development)) {
      "- No triplet cleared TRAIN, so DEVELOPMENT was not queried for strategy evaluation."
    } else {
      paste0(
        "- `", development$summary$triplet_id, "` was frozen on TRAIN and replayed once in DEVELOPMENT."
      )
    },
    "- CONFIRMATION beginning 2024-01-01 remains sealed.",
    "- Do not replace the nominated identity, refit the vector in DEVELOPMENT,",
    "  change thresholds, or reinterpret a TRAIN replay as simulated trading.",
    "",
    "## Key artifacts",
    "",
    paste0("- TRAIN summary: `", artifact_paths$train_summary_csv, "`."),
    paste0("- Gate detail: `", artifact_paths$gate_detail_csv, "`."),
    paste0("- Rank diagnostics: `", artifact_paths$rank_png, "`."),
    paste0("- Gate heatmap: `", artifact_paths$gate_png, "`."),
    paste0("- TRAIN tapes: `", artifact_paths$train_tapes_png, "`."),
    "",
    "## Run provenance",
    "",
    paste0("- Explicit as-of: `", run_spec$as_of_timestamp, "`."),
    paste0("- Feed: `", run_spec$feed, "`."),
    paste0("- Data health: `", run_spec$data_health_max_severity, "`."),
    paste0("- Output: `", run_spec$output_dir, "`.")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("LIT-MR-03.1 starting.")
contract <- g5_mr03_contract()
registry <- g5_mr03_registry()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_MR03_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_MR03_REFRESH", FALSE)
run_id <- env_or("GEN5_MR03_RUN_ID", "lit_mr_03_1_triplets_20260729")
as_of_timestamp <- env_or("GEN5_MR03_AS_OF_TIMESTAMP", contract$as_of_timestamp)
if (!identical(as_of_timestamp, contract$as_of_timestamp)) {
  stop("GEN5_MR03_AS_OF_TIMESTAMP must match the frozen contract.", call. = FALSE)
}

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

train_query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$train_start,
  end_date = contract$train_end,
  as_of_timestamp = as_of_timestamp,
  symbols = g5_mr03_required_symbols(registry),
  universe_name = "lit_mr_03_1_triplet_train",
  universe_roles = "predeclared_triplet_legs",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(train_query$bars)) stop("TRAIN query returned no bars.", call. = FALSE)

reference_sessions <- sort(unique(train_query$bars$session_date))
coverage <- do.call(rbind, lapply(g5_mr03_required_symbols(registry), function(symbol) {
  observed <- sort(unique(train_query$bars$session_date[train_query$bars$symbol == symbol]))
  missing <- setdiff(reference_sessions, observed)
  data.frame(
    symbol = symbol,
    observed_sessions = length(observed),
    reference_sessions = length(reference_sessions),
    first_session = min(observed),
    last_session = max(observed),
    missing_sessions = length(missing),
    status = ifelse(
      length(missing) == 0L &&
        min(observed) <= contract$train_start &&
        max(observed) >= contract$train_end,
      "PASS",
      "FAIL"
    ),
    stringsAsFactors = FALSE
  )
}))
health_max <- g5_health_max_severity(train_query$health)
analysis_health <- if (
  !any(train_query$health$severity == "ERROR") &&
    all(coverage$status == "PASS")
) "PASS" else "FAIL"
if (!identical(analysis_health, "PASS")) {
  stop(
    paste0(
      "TRAIN coverage or data health failed. Health=", health_max,
      "; coverage failures=", sum(coverage$status != "PASS"), "."
    ),
    call. = FALSE
  )
}

batch <- g5_mr03_run_train_batch(
  train_query$bars,
  registry,
  data_health_status = analysis_health,
  contract = contract
)

development <- NULL
development_query_artifacts <- NULL
if (!is.na(batch$nominated_triplet_id)) {
  selected <- batch$results[[batch$nominated_triplet_id]]
  development_query <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = contract$train_start,
    end_date = contract$development_end,
    as_of_timestamp = as_of_timestamp,
    symbols = selected$symbols,
    universe_name = paste0(
      "lit_mr_03_1_development_", tolower(batch$nominated_triplet_id)
    ),
    universe_roles = "train_nominated_triplet_legs",
    refresh = refresh,
    repo_root = repo_root
  )
  if (any(development_query$health$severity == "ERROR")) {
    stop("DEVELOPMENT query health contains ERROR.", call. = FALSE)
  }
  development <- g5_mr03_run_development(
    development_query$bars,
    selected,
    data_health_status = "PASS",
    contract = contract
  )
  development_query_artifacts <- g5_write_workbench_query_artifacts(
    development_query, output_dir, "mr03_development_workbench_query"
  )
  batch$later_outcomes_opened <- TRUE
  batch$overall_status <- "OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_1"
}

artifact_paths <- list(
  run_spec_csv = file.path(output_dir, "mr03_run_spec.csv"),
  registry_csv = file.path(output_dir, "mr03_triplet_registry.csv"),
  coverage_csv = file.path(output_dir, "mr03_train_coverage.csv"),
  train_summary_csv = file.path(output_dir, "mr03_train_summary.csv"),
  gate_detail_csv = file.path(output_dir, "mr03_train_gate_detail.csv"),
  johansen_csv = file.path(output_dir, "mr03_johansen_bootstrap_summary.csv"),
  adf_csv = file.path(output_dir, "mr03_component_adf_diagnostics.csv"),
  vector_csv = file.path(output_dir, "mr03_cointegrating_vectors.csv"),
  integrity_csv = file.path(output_dir, "mr03_train_integrity.csv"),
  trades_csv = file.path(output_dir, "mr03_train_trades.csv"),
  replay_csv = file.path(output_dir, "mr03_train_replay.csv"),
  convergence_csv = file.path(output_dir, "mr03_train_forward_convergence.csv"),
  development_summary_csv = file.path(output_dir, "mr03_development_summary.csv"),
  development_trades_csv = file.path(output_dir, "mr03_development_trades.csv"),
  development_replay_csv = file.path(output_dir, "mr03_development_replay.csv"),
  report_md = file.path(output_dir, "mr03_report.md"),
  rank_png = file.path(visual_dir, "mr03_johansen_rank_diagnostics.png"),
  gate_png = file.path(visual_dir, "mr03_train_gate_heatmap.png"),
  exposure_png = file.path(visual_dir, "mr03_train_dollar_exposures.png"),
  train_tapes_png = file.path(visual_dir, "mr03_train_signal_tapes.png"),
  train_equity_png = file.path(visual_dir, "mr03_train_equity_curves.png"),
  oos_png = file.path(visual_dir, "mr03_development_strategy_anatomy.png")
)

run_spec <- data.frame(
  schema_version = g5_mr03_schema_version(),
  literature_id = contract$literature_id,
  wrapper = "scripts/inspect/run_gen5_lit_mr_03_1_triplet_poc.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  train_coverage_status = analysis_health,
  train_start = contract$train_start,
  train_end = contract$train_end,
  development_start = contract$development_start,
  development_end = contract$development_end,
  triplets = nrow(registry),
  nominated_triplet_id = ifelse(
    is.na(batch$nominated_triplet_id), "", batch$nominated_triplet_id
  ),
  later_outcomes_opened = batch$later_outcomes_opened,
  confirmation_opened = FALSE,
  overall_status = batch$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

train_query_artifacts <- g5_write_workbench_query_artifacts(
  train_query, output_dir, "mr03_train_workbench_query"
)
johansen_summary <- bind_results(batch, function(x) x$johansen_bootstrap$summary)
adf_summary <- bind_results(batch, function(x) x$adf)
vector_summary <- do.call(rbind, lapply(batch$results, function(x) {
  data.frame(
    triplet_id = x$registry_row$triplet_id[[1L]],
    symbol = x$symbols,
    full_train_beta = x$fit$beta,
    first_half_beta = x$stability$first_beta,
    second_half_beta = x$stability$second_beta,
    stringsAsFactors = FALSE
  )
}))

write_csv(run_spec, artifact_paths$run_spec_csv)
write_csv(registry, artifact_paths$registry_csv)
write_csv(coverage, artifact_paths$coverage_csv)
write_csv(batch$summary, artifact_paths$train_summary_csv)
write_csv(batch$gate_detail, artifact_paths$gate_detail_csv)
write_csv(johansen_summary, artifact_paths$johansen_csv)
write_csv(adf_summary, artifact_paths$adf_csv)
write_csv(vector_summary, artifact_paths$vector_csv)
write_csv(bind_results(batch, function(x) x$integrity), artifact_paths$integrity_csv)
write_csv(bind_results(batch, function(x) x$trades), artifact_paths$trades_csv)
write_csv(bind_results(batch, function(x) x$replay), artifact_paths$replay_csv)
write_csv(
  bind_results(batch, function(x) x$convergence),
  artifact_paths$convergence_csv
)
if (!is.null(development)) {
  write_csv(development$summary, artifact_paths$development_summary_csv)
  write_csv(development$trades, artifact_paths$development_trades_csv)
  write_csv(development$replay, artifact_paths$development_replay_csv)
  plot_oos_anatomy(development, artifact_paths$oos_png)
}

plot_rank_diagnostics(batch$summary, artifact_paths$rank_png)
plot_gate_heatmap(batch, artifact_paths$gate_png)
plot_dollar_exposures(batch, artifact_paths$exposure_png)
plot_train_tapes(batch, artifact_paths$train_tapes_png)
plot_train_equity(batch, artifact_paths$train_equity_png)
write_report(
  artifact_paths$report_md,
  batch,
  run_spec,
  development,
  c(
    artifact_paths,
    train_query_artifacts$paths,
    if (!is.null(development_query_artifacts)) development_query_artifacts$paths
  )
)

message("LIT-MR-03.1 complete: ", batch$overall_status)
message("Data health: ", health_max)
message("Nominated triplet: ", ifelse(
  is.na(batch$nominated_triplet_id), "NONE", batch$nominated_triplet_id
))
message("Later outcomes opened: ", batch$later_outcomes_opened)
message("Confirmation opened: FALSE")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report_md, winslash = "/", mustWork = FALSE))
