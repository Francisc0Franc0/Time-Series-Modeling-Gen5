# Run one frozen LIT-MR-02.2 pair lane.

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
source(file.path(repo_root, "R", "gen5_lit_mr_02_1_bollinger_poc.R"))
source(file.path(repo_root, "R", "gen5_lit_mr_02_1_pair_panel.R"))
source(file.path(repo_root, "R", "gen5_lit_mr_02_2_relaxed_pair_poc.R"))
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
  if (!dir.exists(path)) stop("Could not create output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

bind_nonempty <- function(items, extractor) {
  rows <- lapply(items, extractor)
  rows <- Filter(function(x) !is.null(x) && nrow(x), rows)
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

colors <- list(
  navy = "#123047", blue = "#3D8DFF", green = "#177245",
  red = "#B42318", amber = "#F59E0B", slate = "#64748B",
  pale = "#EAF4FB"
)

plot_gate_yield <- function(batch, path) {
  detail <- batch$relaxed_gate_detail
  required <- detail[detail$gate_role == "MANDATORY", , drop = FALSE]
  pass_counts <- vapply(paste0("R", 1:6), function(id) {
    sum(required$gate_id == id & required$status == "PASS")
  }, numeric(1))
  png(path, width = 1800, height = 1000, res = 150)
  old <- par(mar = c(7, 6, 4, 2))
  barplot(
    pass_counts,
    names.arg = paste0("R", 1:6),
    col = ifelse(pass_counts == nrow(batch$summary), colors$green, colors$blue),
    ylim = c(0, nrow(batch$summary)),
    ylab = "Candidates passing gate",
    main = paste0(
      "LIT-MR-02.2 ", gsub("_", " ", batch$lane),
      ": mandatory-gate yield"
    )
  )
  abline(h = nrow(batch$summary), col = colors$slate, lty = 2)
  mtext(
    "R1 integrity | R2 beta | R3 support | R4 q10 return | R5 random p90 | R6 q90 convergence",
    side = 1, line = 4.7, cex = 0.85, col = colors$slate
  )
  par(old)
  dev.off()
}

plot_evidence_plane <- function(summary, path) {
  x <- 10000 * summary$trade_q10
  y <- summary$forward_q90
  point_colors <- ifelse(summary$relaxed_full_pass, colors$green, colors$navy)
  png(path, width = 1800, height = 1100, res = 150)
  old <- par(mar = c(6, 6, 4, 2))
  plot(
    x, y,
    pch = 19, cex = 1.2, col = point_colors,
    xlab = "TRAIN trade bootstrap q10 (bp/trade)",
    ylab = "TRAIN forward-convergence bootstrap q90",
    main = "Admission needs both uncertainty bounds inside the favorable quadrant"
  )
  abline(v = 0, h = 0, col = colors$red, lty = 2, lwd = 2)
  if (any(summary$relaxed_full_pass)) {
    passed <- summary[summary$relaxed_full_pass, , drop = FALSE]
    text(
      10000 * passed$trade_q10,
      passed$forward_q90,
      labels = passed$candidate_id,
      pos = 3, cex = 0.75, col = colors$green
    )
  }
  par(old)
  dev.off()
}

plot_development <- function(summary, path) {
  if (!nrow(summary)) return(invisible(NULL))
  values <- rbind(
    summary$cumulative_return,
    summary$stress_cumulative_return
  )
  colnames(values) <- summary$candidate_id
  png(
    path,
    width = 1900,
    height = max(950, 600 + 45 * nrow(summary)),
    res = 150
  )
  old <- par(mar = c(9, 6, 4, 2))
  bars <- barplot(
    values,
    beside = TRUE,
    col = c(colors$blue, colors$amber),
    ylab = "2021-2023 cumulative return",
    main = "DEVELOPMENT outcomes: primary versus stress costs",
    las = 2
  )
  abline(h = 0, col = colors$slate)
  legend(
    "topright", c("Primary cost", "Stress cost"),
    fill = c(colors$blue, colors$amber), bty = "n"
  )
  text(bars, values, sprintf("%.1f%%", 100 * values), pos = 3, cex = 0.75)
  par(old)
  dev.off()
}

write_report <- function(path, batch, run_spec, development_summary, artifacts) {
  passes <- batch$summary[batch$summary$relaxed_full_pass, , drop = FALSE]
  lines <- c(
    paste0("# LIT-MR-02.2 ", gsub("_", " ", batch$lane), " Readout"),
    "",
    paste0("Status: `", run_spec$overall_status, "`."),
    "",
    "## Frozen distinction",
    "",
    "- Trading mechanics and costs are unchanged from LIT-MR-02.1.",
    "- Hit rate and positive TRAIN years are diagnostics, not vetoes.",
    "- Return q10, random-sign p90, and convergence q90 remain mandatory.",
    if (identical(batch$lane, "RETROSPECTIVE")) {
      paste(
        "- This lane is post-hoc and descriptive. It cannot support a",
        "discovery, validation, or alpha claim."
      )
    } else {
      paste(
        "- Candidate identities and order were frozen before TRAIN outcomes;",
        "only the first full pass can receive one DEVELOPMENT replay."
      )
    },
    "",
    "## TRAIN",
    "",
    paste0("- Candidates: `", nrow(batch$summary), "`."),
    paste0(
      "- Strict full passes: `",
      sum(batch$summary$strict_full_pass), " / ", nrow(batch$summary), "`."
    ),
    paste0(
      "- Relaxed full passes: `",
      nrow(passes), " / ", nrow(batch$summary), "`."
    ),
    paste0(
      "- Relaxed pass IDs: `",
      if (nrow(passes)) paste(passes$candidate_id, collapse = ", ") else "NONE",
      "`."
    ),
    "",
    "## DEVELOPMENT",
    ""
  )
  if (!nrow(development_summary)) {
    lines <- c(lines, "- No DEVELOPMENT replay was authorized.")
  } else {
    for (i in seq_len(nrow(development_summary))) {
      x <- development_summary[i, , drop = FALSE]
      lines <- c(
        lines,
        paste0(
          "- `", x$candidate_id, "`: ",
          x$completed_trades, " completed trades; ",
          sprintf("%+.2f bp/trade", 10000 * x$mean_net_trade_return), "; ",
          sprintf("%+.2f%% primary", 100 * x$cumulative_return), "; ",
          sprintf("%+.2f%% stress", 100 * x$stress_cumulative_return), "; ",
          sprintf("%.3f adjusted Sharpe", x$autocorrelation_adjusted_sharpe),
          "."
        )
      )
    }
  }
  lines <- c(
    lines,
    "",
    "## Boundary",
    "",
    "- CONFIRMATION beginning 2024 remains sealed.",
    "- No result opens portfolio, allocation, live-short, or deployment scope.",
    "",
    "## Artifacts",
    "",
    paste0("- TRAIN summary: `", artifacts$train_summary_csv, "`."),
    paste0("- Relaxed gates: `", artifacts$relaxed_gates_csv, "`."),
    paste0("- DEVELOPMENT summary: `", artifacts$development_summary_csv, "`."),
    paste0("- Output: `", run_spec$output_dir, "`.")
  )
  writeLines(lines, path, useBytes = TRUE)
}

lane <- toupper(env_or("GEN5_MR022_LANE", "RETROSPECTIVE"))
if (!lane %in% c("RETROSPECTIVE", "FRESH_ATLAS_01")) {
  stop("GEN5_MR022_LANE must be RETROSPECTIVE or FRESH_ATLAS_01.", call. = FALSE)
}
contract <- g5_mr022_contract()
registry <- g5_mr022_registry_for_lane(lane)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_MR022_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_MR022_REFRESH", FALSE)
development_refresh <- env_bool("GEN5_MR022_DEVELOPMENT_REFRESH", refresh)
run_id <- env_or(
  "GEN5_MR022_RUN_ID",
  paste0("lit_mr_02_2_", tolower(lane), "_20260729")
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

message("LIT-MR-02.2 ", lane, " TRAIN starting.")
train_query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$train_start,
  end_date = contract$train_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = g5_mr022_required_symbols(registry, lane),
  universe_name = paste0("lit_mr_02_2_", tolower(lane), "_train"),
  universe_roles = "predeclared_pair_legs",
  refresh = refresh,
  repo_root = repo_root
)
coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  row <- registry[i, , drop = FALSE]
  audit <- g5_mr02_session_coverage_audit(
    train_query$bars, g5_mr022_instance_contract(row)
  )
  audit$candidate_id <- row$candidate_id[[1L]]
  audit
}))
health_max <- g5_health_max_severity(train_query$health)
analysis_health <- if (
  !any(train_query$health$severity == "ERROR") &&
    all(coverage$status == "PASS")
) "PASS" else "FAIL"
if (!identical(analysis_health, "PASS")) {
  stop(
    paste0(
      "TRAIN coverage or health failed. Health=", health_max,
      "; failures=", sum(coverage$status != "PASS"), "."
    ),
    call. = FALSE
  )
}
batch <- g5_mr022_run_train_batch(
  train_query$bars,
  registry,
  lane,
  data_health_status = analysis_health
)

development_ids <- if (identical(lane, "RETROSPECTIVE")) {
  batch$relaxed_pass_ids
} else if (!is.na(batch$nominated_candidate_id)) {
  batch$nominated_candidate_id
} else {
  character()
}
development_results <- list()
development_query_artifacts <- NULL
if (length(development_ids)) {
  development_symbols <- sort(unique(unlist(lapply(development_ids, function(id) {
    row <- registry[registry$candidate_id == id, , drop = FALSE]
    c(row$symbol_y, row$symbol_x)
  }))))
  development_query <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = contract$train_start,
    end_date = contract$development_end,
    as_of_timestamp = contract$as_of_timestamp,
    symbols = development_symbols,
    universe_name = paste0("lit_mr_02_2_", tolower(lane), "_development"),
    universe_roles = "relaxed_train_survivor_legs",
    refresh = development_refresh,
    repo_root = repo_root
  )
  if (any(development_query$health$severity == "ERROR")) {
    stop("DEVELOPMENT query health contains ERROR.", call. = FALSE)
  }
  development_coverage <- do.call(rbind, lapply(development_ids, function(id) {
    row <- registry[registry$candidate_id == id, , drop = FALSE]
    candidate_contract <- g5_mr022_instance_contract(row)
    candidate_contract$query_end <- contract$development_end
    audit <- g5_mr02_session_coverage_audit(
      development_query$bars, candidate_contract
    )
    audit$candidate_id <- id
    audit
  }))
  if (any(development_coverage$status != "PASS")) {
    stop(
      paste0(
        "DEVELOPMENT coverage failed for: ",
        paste(
          unique(development_coverage$candidate_id[
            development_coverage$status != "PASS"
          ]),
          collapse = ","
        ),
        ". Rerun with explicit refresh."
      ),
      call. = FALSE
    )
  }
  development_results <- lapply(development_ids, function(id) {
    g5_mr022_run_development(
      development_query$bars,
      batch$results[[id]],
      data_health_status = "PASS"
    )
  })
  names(development_results) <- development_ids
  development_query_artifacts <- g5_write_workbench_query_artifacts(
    development_query, output_dir, "mr022_development_workbench_query"
  )
  batch$later_outcomes_opened <- TRUE
  batch$overall_status <- if (identical(lane, "RETROSPECTIVE")) {
    "RETROSPECTIVE_DESCRIPTIVE_COMPLETE_LIT_MR_02_2"
  } else {
    "OOS_DEVELOPMENT_COMPLETE_LIT_MR_02_2_FRESH_ATLAS_01"
  }
} else if (identical(lane, "RETROSPECTIVE")) {
  batch$overall_status <- "RETROSPECTIVE_DESCRIPTIVE_COMPLETE_LIT_MR_02_2"
}

artifacts <- list(
  run_spec_csv = file.path(output_dir, "mr022_run_spec.csv"),
  registry_csv = file.path(output_dir, "mr022_registry.csv"),
  coverage_csv = file.path(output_dir, "mr022_train_coverage.csv"),
  train_summary_csv = file.path(output_dir, "mr022_train_summary.csv"),
  strict_gates_csv = file.path(output_dir, "mr022_strict_gate_detail.csv"),
  relaxed_gates_csv = file.path(output_dir, "mr022_relaxed_gate_detail.csv"),
  development_summary_csv = file.path(output_dir, "mr022_development_summary.csv"),
  development_trades_csv = file.path(output_dir, "mr022_development_trades.csv"),
  development_replay_csv = file.path(output_dir, "mr022_development_replay.csv"),
  report_md = file.path(output_dir, "mr022_report.md"),
  gate_yield_png = file.path(visual_dir, "mr022_gate_yield.png"),
  evidence_plane_png = file.path(visual_dir, "mr022_train_evidence_plane.png"),
  development_png = file.path(visual_dir, "mr022_development_cost_comparison.png")
)
development_summary <- bind_nonempty(development_results, function(x) x$summary)
development_trades <- bind_nonempty(development_results, function(x) {
  out <- x$trades
  out$candidate_id <- x$summary$candidate_id[[1L]]
  out
})
development_replay <- bind_nonempty(development_results, function(x) {
  out <- x$replay
  out$candidate_id <- x$summary$candidate_id[[1L]]
  out
})
run_spec <- data.frame(
  schema_version = g5_mr022_schema_version(),
  literature_id = contract$literature_id,
  lane = lane,
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  development_refresh = development_refresh,
  data_health_max_severity = health_max,
  train_coverage_status = analysis_health,
  candidates = nrow(registry),
  relaxed_train_passes = length(batch$relaxed_pass_ids),
  nominated_candidate_id = ifelse(
    is.na(batch$nominated_candidate_id), "", batch$nominated_candidate_id
  ),
  later_outcomes_opened = batch$later_outcomes_opened,
  confirmation_opened = FALSE,
  overall_status = batch$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
train_query_artifacts <- g5_write_workbench_query_artifacts(
  train_query, output_dir, "mr022_train_workbench_query"
)
write_csv(run_spec, artifacts$run_spec_csv)
write_csv(registry, artifacts$registry_csv)
write_csv(coverage, artifacts$coverage_csv)
write_csv(batch$summary, artifacts$train_summary_csv)
write_csv(batch$strict_gate_detail, artifacts$strict_gates_csv)
write_csv(batch$relaxed_gate_detail, artifacts$relaxed_gates_csv)
write_csv(development_summary, artifacts$development_summary_csv)
write_csv(development_trades, artifacts$development_trades_csv)
write_csv(development_replay, artifacts$development_replay_csv)
plot_gate_yield(batch, artifacts$gate_yield_png)
plot_evidence_plane(batch$summary, artifacts$evidence_plane_png)
plot_development(development_summary, artifacts$development_png)
write_report(artifacts$report_md, batch, run_spec, development_summary, artifacts)

message("LIT-MR-02.2 complete: ", batch$overall_status)
message("Relaxed TRAIN passes: ", length(batch$relaxed_pass_ids))
message("DEVELOPMENT replays: ", nrow(development_summary))
message("Confirmation opened: FALSE")
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
