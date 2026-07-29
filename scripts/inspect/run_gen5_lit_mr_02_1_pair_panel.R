# Run a frozen LIT-MR-02.1 pair-panel replication batch.

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
  if (!dir.exists(path)) {
    stop("Could not create pair-panel output directory.", call. = FALSE)
  }
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

panel_colors <- as.list(c(
  navy = "#123047",
  blue = "#3D8DFF",
  cyan = "#26C6DA",
  green = "#177245",
  red = "#B42318",
  amber = "#F59E0B",
  slate = "#64748B",
  light = "#E2E8F0",
  pale = "#EAF4FB"
))

pair_label <- function(summary) {
  paste0(summary$symbol_y, "-", summary$symbol_x)
}

combine_pair_frame <- function(panel, extractor) {
  rows <- lapply(names(panel$pair_results), function(pair_id) {
    x <- extractor(panel$pair_results[[pair_id]])
    if (is.null(x) || !nrow(x)) return(NULL)
    x$pair_id <- pair_id
    x
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

plot_weight_mechanics <- function(path) {
  beta <- seq(0.05, 3, length.out = 200L)
  w_y_long <- 1 / (1 + beta)
  w_x_long <- -beta / (1 + beta)
  png(path, width = 1900, height = 1050, res = 150)
  old <- par(mar = c(6, 6, 4, 2))
  plot(
    beta, w_y_long,
    type = "l", lwd = 4, col = panel_colors$blue,
    ylim = c(-1, 1),
    xlab = "Positive rolling hedge ratio beta",
    ylab = "Gross-normalized target weight",
    main = "Long-spread weights when entry prices are equal"
  )
  lines(beta, w_x_long, lwd = 4, col = panel_colors$red)
  lines(beta, -w_y_long, lwd = 3, col = panel_colors$blue, lty = 2)
  lines(beta, -w_x_long, lwd = 3, col = panel_colors$red, lty = 2)
  abline(h = 0, col = panel_colors$slate)
  legend(
    "right",
    c("Long spread: Y", "Long spread: X", "Short spread: Y", "Short spread: X"),
    col = c(panel_colors$blue, panel_colors$red, panel_colors$blue, panel_colors$red),
    lty = c(1, 1, 2, 2),
    lwd = c(4, 4, 3, 3),
    bty = "n"
  )
  mtext(
    "Weights use dollar values: wY = d*Y/(Y+|beta|X), wX = -d*beta*X/(Y+|beta|X)",
    side = 1, line = 4.4, cex = 0.9, col = panel_colors$slate
  )
  par(old)
  dev.off()
}

plot_pair_net_ci <- function(summary, path) {
  x <- summary[order(summary$pair_index, decreasing = TRUE), , drop = FALSE]
  labels <- pair_label(x)
  values <- 10000 * x$mean_net_trade_return
  lower <- 10000 * x$trade_bootstrap_lower_95
  upper <- 10000 * x$trade_bootstrap_upper_95
  colors <- ifelse(
    grepl("near_substitute", x$pair_category, fixed = TRUE),
    panel_colors$blue,
    panel_colors$navy
  )
  png(path, width = 1900, height = 1250, res = 150)
  old <- par(mar = c(6, 12, 4, 2))
  limits <- range(c(lower, upper, 0), finite = TRUE)
  pad <- diff(limits) * 0.08
  plot(
    values, seq_along(values),
    xlim = limits + c(-pad, pad),
    ylim = c(0.5, length(values) + 0.5),
    pch = 19, cex = 1.3, col = colors,
    yaxt = "n",
    xlab = "Mean primary-cost net return (bp per completed trade)",
    ylab = "",
    main = "Fixed registry order: pair means and 95% block-bootstrap intervals"
  )
  axis(2, at = seq_along(labels), labels = labels, las = 1)
  segments(lower, seq_along(values), upper, seq_along(values), col = colors, lwd = 3)
  abline(v = 0, col = panel_colors$red, lty = 2, lwd = 2)
  legend(
    "bottomright",
    c("Near-substitute", "Related exposure"),
    col = c(panel_colors$blue, panel_colors$navy),
    pch = 19, bty = "n"
  )
  par(old)
  dev.off()
}

plot_forward_convergence <- function(summary, path) {
  x <- summary[order(summary$pair_index, decreasing = TRUE), , drop = FALSE]
  labels <- pair_label(x)
  values <- x$forward_correlation
  lower <- x$forward_lower_95
  upper <- x$forward_upper_95
  colors <- ifelse(values < 0, panel_colors$green, panel_colors$red)
  png(path, width = 1900, height = 1250, res = 150)
  old <- par(mar = c(6, 12, 4, 2))
  limits <- range(c(lower, upper, 0), finite = TRUE)
  pad <- diff(limits) * 0.08
  plot(
    values, seq_along(values),
    xlim = limits + c(-pad, pad),
    ylim = c(0.5, length(values) + 0.5),
    pch = 19, cex = 1.3, col = colors,
    yaxt = "n",
    xlab = "Correlation: signal z-score versus forward-five spread return",
    ylab = "",
    main = "Negative values support convergence; intervals must stay below zero"
  )
  axis(2, at = seq_along(labels), labels = labels, las = 1)
  segments(lower, seq_along(values), upper, seq_along(values), col = colors, lwd = 3)
  abline(v = 0, col = panel_colors$slate, lty = 2, lwd = 2)
  par(old)
  dev.off()
}

plot_gate_heatmap <- function(panel, path) {
  summary <- panel$pair_summary[order(panel$pair_summary$pair_index), , drop = FALSE]
  gates <- panel$gate_detail
  matrix_values <- matrix(
    0,
    nrow = nrow(summary),
    ncol = 8L,
    dimnames = list(pair_label(summary), paste0("G", 1:8))
  )
  for (i in seq_len(nrow(summary))) {
    pair_gates <- gates[gates$pair_id == summary$pair_id[[i]], , drop = FALSE]
    matrix_values[i, pair_gates$gate_id] <- as.integer(pair_gates$status == "PASS")
  }
  png(path, width = 2100, height = 1250, res = 150)
  old <- par(mar = c(8, 12, 5, 3))
  image(
    x = seq_len(ncol(matrix_values)),
    y = seq_len(nrow(matrix_values)),
    z = t(matrix_values),
    col = c(panel_colors$red, panel_colors$green),
    breaks = c(-0.5, 0.5, 1.5),
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = "Every primary pair is shown; green is PASS and red is FAIL"
  )
  axis(1, at = seq_len(ncol(matrix_values)), labels = colnames(matrix_values), las = 1)
  axis(2, at = seq_len(nrow(matrix_values)), labels = rownames(matrix_values), las = 1)
  box()
  mtext(
    "G1 integrity | G2 beta | G3 support | G4 cost+CI | G5 hit | G6 random | G7 years | G8 convergence",
    side = 1, line = 4.5, cex = 0.85, col = panel_colors$slate
  )
  par(old)
  dev.off()
}

plot_category_summary <- function(panel, path) {
  x <- panel$category_summary
  metrics <- rbind(
    x$positive_mean_net_pairs,
    x$negative_forward_pairs,
    x$full_gate_pass_pairs
  )
  colnames(metrics) <- gsub("_", " ", x$pair_category)
  rownames(metrics) <- c("Positive mean net", "Negative forward corr", "All 8 gates")
  png(path, width = 1800, height = 1000, res = 150)
  old <- par(mar = c(7, 6, 4, 2))
  bars <- barplot(
    metrics,
    beside = TRUE, axisnames = FALSE,
    col = c(panel_colors$blue, panel_colors$green, panel_colors$amber),
    ylim = c(0, max(x$pairs) + 1),
    ylab = "Pairs",
    main = "Category evidence is descriptive; no winner is selected"
  )
  axis(1, at = colMeans(bars), labels = colnames(metrics), tick = FALSE, line = -1)
  legend(
    "topright", rownames(metrics),
    fill = c(panel_colors$blue, panel_colors$green, panel_colors$amber),
    bty = "n"
  )
  for (j in seq_len(ncol(metrics))) {
    text(bars[, j], metrics[, j], labels = metrics[, j], pos = 3)
  }
  par(old)
  dev.off()
}

plot_fixed_pair_tapes <- function(panel, bars, path) {
  fixed_ids <- if (identical(panel$panel_id, "PANEL_A")) {
    c("P02_IAU_GLD", "P08_KRE_XLF", "P10_USO_XLE", "D01_GLD_UUP")
  } else if (identical(panel$panel_id, "PANEL_B")) {
    c("B02_XLU_VPU", "B10_ITA_XAR", "B12_XRT_XLY", "B15_GDX_GLD")
  } else {
    c("A02_GLD_IAU", "A12_XLF_JPM", "A17_V_MA", "A24_FCX_CPER")
  }
  registry <- panel$registry[match(fixed_ids, panel$registry$pair_id), , drop = FALSE]
  png(path, width = 2200, height = 1600, res = 150)
  old <- par(mfrow = c(2, 2), mar = c(5, 5, 4, 2))
  for (i in seq_len(nrow(registry))) {
    contract <- g5_mr02_panel_instance_contract(registry[i, , drop = FALSE])
    indicators <- g5_mr02_rolling_indicators(
      g5_mr02_common_panel(bars, contract), contract
    )
    x <- indicators[
      indicators$session_date >= contract$train_start &
        indicators$session_date <= contract$train_end,
      ,
      drop = FALSE
    ]
    plot(
      x$session_date, x$z_score,
      type = "l", lwd = 1, col = panel_colors$navy,
      xlab = "TRAIN signal close", ylab = "Spread z-score",
      main = paste0(
        registry$symbol_y[[i]], "-", registry$symbol_x[[i]], " | ",
        gsub("_", " ", registry$pair_category[[i]])
      )
    )
    abline(h = c(-1, 0, 1), col = c(
      panel_colors$red, panel_colors$slate, panel_colors$red
    ), lty = c(2, 1, 2))
  }
  par(old)
  dev.off()
}

write_report <- function(path, panel, run_spec, artifact_paths) {
  summary <- panel$pair_summary
  categories <- panel$category_summary
  inverse <- panel$inverse_summary
  full_pass <- summary[summary$full_gate_pass, , drop = FALSE]
  panel_label <- gsub("_", "-", panel$panel_id)
  lines <- c(
    paste0("# LIT-MR-02.1 ", panel_label, " Readout"),
    "",
    paste0("Status: `", panel$overall_status, "`."),
    "",
    "## What was frozen",
    "",
    "- The canonical USO-GLD literature instance remains separate and unchanged.",
    paste0(
      "- ", nrow(summary), " positive-relationship primary pairs and ",
      nrow(inverse), " inverse diagnostics were fixed before outcomes."
    ),
    "- Every primary pair used raw adjusted prices, 20-session rolling OLS,",
    "  20-session spread z-score, +/-1 entry, zero exit, next-open execution,",
    "  daily rehedging, and the canonical costs and eight gates.",
    "- Only 2016-2020 TRAIN data were requested and analyzed.",
    "- Registry order is preserved in every pair-level visual; no result-based",
    "  pair addition, deletion, or sorting defines the conclusion.",
    "",
    "## Primary panel readout",
    "",
    paste0("- Full eight-gate passes: `", nrow(full_pass), " / ", nrow(summary), "`."),
    paste0("- Positive mean net trade return: `",
      sum(summary$mean_net_trade_return > 0, na.rm = TRUE), " / ", nrow(summary), "`."),
    paste0("- Negative forward-convergence correlation: `",
      sum(summary$forward_correlation < 0, na.rm = TRUE), " / ", nrow(summary), "`."),
    paste0("- Median mean net trade return: `",
      sprintf("%.2f bp/trade", 10000 * stats::median(summary$mean_net_trade_return, na.rm = TRUE)),
      "`."),
    paste0("- Median hit rate: `",
      sprintf("%.1f%%", 100 * stats::median(summary$hit_rate, na.rm = TRUE)), "`."),
    "",
    "### Category summaries",
    ""
  )
  for (i in seq_len(nrow(categories))) {
    lines <- c(
      lines,
      paste0(
        "- `", categories$pair_category[[i]], "`: ",
        categories$pairs[[i]], " pairs; ",
        categories$positive_mean_net_pairs[[i]], " positive means; ",
        categories$negative_forward_pairs[[i]], " negative forward correlations; ",
        categories$full_gate_pass_pairs[[i]], " full passes."
      )
    )
  }
  lines <- c(
    lines,
    "",
    if (nrow(inverse)) "## Inverse challengers" else "## Inverse boundary",
    "",
    if (nrow(inverse)) {
      paste(
        "Negative beta changes the trade from opposite legs to same-side",
        "positions. The challengers therefore received diagnostics but no",
        "trading replay."
      )
    } else {
      paste(
        "No inverse challengers were included in this batch. Negative-beta",
        "sessions still fail the positive-beta coverage gate."
      )
    }
  )
  for (i in seq_len(nrow(inverse))) {
    lines <- c(
      lines,
      paste0(
        "- `", inverse$pair_id[[i]], "`: median beta ",
        sprintf("%.3f", inverse$median_beta[[i]]), "; negative-beta coverage ",
        sprintf("%.1f%%", 100 * inverse$negative_beta_coverage[[i]]),
        "; signed forward correlation ",
        sprintf("%.3f", inverse$signed_forward_correlation[[i]]), "."
      )
    )
  }
  lines <- c(
    lines,
    "",
    "## Decision boundary",
    "",
    if (nrow(full_pass)) {
      paste0(
        "- The full-pass pair IDs are descriptive candidates only: `",
        paste(full_pass$pair_id, collapse = ", "),
        "`. A new pair-specific sealed confirmation contract requires operator review."
      )
    } else {
      "- No pair earned permission for pair-specific confirmation."
    },
    "- Do not choose the highest observed return, change pair orientation, add",
    "  nearby pairs, or vary the 20-session window after this inspection.",
    "- Development and confirmation outcomes remain unopened.",
    "",
    "## Key artifacts",
    "",
    paste0("- Pair summary: `", artifact_paths$pair_summary_csv, "`."),
    paste0("- Gate detail: `", artifact_paths$gate_detail_csv, "`."),
    paste0("- Inverse diagnostics: `", artifact_paths$inverse_summary_csv, "`."),
    paste0("- Pair intervals: `", artifact_paths$pair_net_ci_png, "`."),
    paste0("- Gate heatmap: `", artifact_paths$gate_heatmap_png, "`."),
    "",
    "## Run provenance",
    "",
    paste0("- Explicit as-of: `", run_spec$as_of_timestamp, "`."),
    paste0("- Feed: `", run_spec$feed, "`."),
    paste0("- Data health: `", run_spec$data_health_max_severity, "`."),
    paste0("- Pair coverage: `", run_spec$pair_coverage_status, "`."),
    paste0("- Output: `", run_spec$output_dir, "`.")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

panel_id <- toupper(env_or("GEN5_MR02_PANEL_ID", "PANEL_A"))
valid_panel_ids <- c("PANEL_A", "PANEL_B", "RELATIONSHIP_ATLAS_01")
if (!panel_id %in% valid_panel_ids) {
  stop(
    paste("GEN5_MR02_PANEL_ID must be one of", paste(valid_panel_ids, collapse = ", ")),
    call. = FALSE
  )
}
message("LIT-MR-02.1 ", panel_id, " starting.")
registry <- if (identical(panel_id, "PANEL_A")) {
  g5_mr02_panel_registry()
} else if (identical(panel_id, "PANEL_B")) {
  g5_mr02_panel_b_registry()
} else {
  g5_mr02_relationship_atlas_registry()
}
base_contract <- g5_mr02_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_MR02_PANEL_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_MR02_PANEL_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_MR02_PANEL_RUN_ID",
  paste0(
    "lit_mr_02_1_", tolower(panel_id), "_",
    if (identical(panel_id, "RELATIONSHIP_ATLAS_01")) "20260729" else "20260728"
  )
)
as_of_timestamp <- env_or(
  "GEN5_MR02_PANEL_AS_OF_TIMESTAMP",
  base_contract$as_of_timestamp
)
if (!identical(as_of_timestamp, base_contract$as_of_timestamp)) {
  stop(
    "GEN5_MR02_PANEL_AS_OF_TIMESTAMP must match the frozen contract.",
    call. = FALSE
  )
}

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = base_contract$train_start,
  end_date = base_contract$train_end,
  as_of_timestamp = as_of_timestamp,
  symbols = g5_mr02_panel_required_symbols(registry),
  universe_name = paste0("lit_mr_02_1_", tolower(panel_id)),
  universe_roles = "predeclared_pair_legs",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) {
  stop(paste(panel_id, "workbench query returned no bars."), call. = FALSE)
}

coverage_rows <- lapply(seq_len(nrow(registry)), function(i) {
  row <- registry[i, , drop = FALSE]
  contract <- g5_mr02_panel_instance_contract(row)
  coverage <- g5_mr02_session_coverage_audit(query$bars, contract)
  coverage$pair_index <- row$pair_index[[1L]]
  coverage$pair_id <- row$pair_id[[1L]]
  coverage$pair_category <- row$pair_category[[1L]]
  coverage
})
pair_coverage <- do.call(rbind, coverage_rows)
health_max <- g5_health_max_severity(query$health)
analysis_health <- if (
  !any(query$health$severity == "ERROR") &&
    all(pair_coverage$status == "PASS")
) "PASS" else "FAIL"
if (!identical(analysis_health, "PASS")) {
  stop(
    paste0(
      panel_id, " coverage or data health failed. Health=", health_max,
      "; pair coverage failures=", sum(pair_coverage$status != "PASS"), "."
    ),
    call. = FALSE
  )
}

panel <- g5_mr02_panel_run(
  query$bars,
  registry = registry,
  data_health_status = analysis_health
)

artifact_paths <- list(
  run_spec_csv = file.path(output_dir, "mr02_panel_run_spec.csv"),
  registry_csv = file.path(output_dir, "mr02_panel_pair_registry.csv"),
  pair_summary_csv = file.path(output_dir, "mr02_panel_pair_summary.csv"),
  gate_detail_csv = file.path(output_dir, "mr02_panel_gate_detail.csv"),
  category_summary_csv = file.path(output_dir, "mr02_panel_category_summary.csv"),
  inverse_summary_csv = file.path(output_dir, "mr02_panel_inverse_diagnostics.csv"),
  pair_coverage_csv = file.path(output_dir, "mr02_panel_pair_coverage.csv"),
  pair_integrity_csv = file.path(output_dir, "mr02_panel_pair_integrity.csv"),
  pair_trades_csv = file.path(output_dir, "mr02_panel_train_trades.csv"),
  pair_years_csv = file.path(output_dir, "mr02_panel_train_years.csv"),
  pair_bootstrap_csv = file.path(output_dir, "mr02_panel_trade_bootstrap_summary.csv"),
  pair_convergence_csv = file.path(output_dir, "mr02_panel_forward_convergence_summary.csv"),
  report_md = file.path(output_dir, "mr02_panel_report.md"),
  weight_mechanics_png = file.path(visual_dir, "mr02_weight_mechanics.png"),
  pair_net_ci_png = file.path(visual_dir, "mr02_panel_pair_net_return_ci.png"),
  forward_ci_png = file.path(visual_dir, "mr02_panel_forward_convergence_ci.png"),
  gate_heatmap_png = file.path(visual_dir, "mr02_panel_gate_heatmap.png"),
  category_summary_png = file.path(visual_dir, "mr02_panel_category_summary.png"),
  fixed_pair_tapes_png = file.path(visual_dir, "mr02_panel_fixed_pair_tapes.png")
)

run_spec <- data.frame(
  schema_version = g5_mr02_panel_schema_version(panel_id),
  literature_id = base_contract$literature_id,
  instance_batch = paste0("LIT-MR-02.1-", gsub("_", "-", panel_id)),
  wrapper = "scripts/inspect/run_gen5_lit_mr_02_1_pair_panel.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  pair_coverage_status = analysis_health,
  query_start = base_contract$train_start,
  query_end = base_contract$train_end,
  primary_pairs = sum(registry$analysis_role == "PRIMARY_TRADING_TEMPLATE"),
  diagnostic_pairs = sum(registry$analysis_role == "DIAGNOSTIC_ONLY"),
  later_outcomes_opened = panel$later_outcomes_opened,
  overall_status = panel$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

pair_integrity <- combine_pair_frame(panel, function(x) x$train_integrity)
pair_trades <- combine_pair_frame(panel, function(x) x$train_trades)
pair_years <- combine_pair_frame(panel, function(x) x$train_years)
pair_bootstrap <- combine_pair_frame(panel, function(x) x$train_bootstrap$summary)
pair_convergence <- combine_pair_frame(
  panel, function(x) x$train_convergence_bootstrap$summary
)

query_artifacts <- g5_write_workbench_query_artifacts(
  query, output_dir, "mr02_panel_workbench_query"
)
write_csv(run_spec, artifact_paths$run_spec_csv)
write_csv(registry, artifact_paths$registry_csv)
write_csv(panel$pair_summary, artifact_paths$pair_summary_csv)
write_csv(panel$gate_detail, artifact_paths$gate_detail_csv)
write_csv(panel$category_summary, artifact_paths$category_summary_csv)
write_csv(panel$inverse_summary, artifact_paths$inverse_summary_csv)
write_csv(pair_coverage, artifact_paths$pair_coverage_csv)
write_csv(pair_integrity, artifact_paths$pair_integrity_csv)
write_csv(pair_trades, artifact_paths$pair_trades_csv)
write_csv(pair_years, artifact_paths$pair_years_csv)
write_csv(pair_bootstrap, artifact_paths$pair_bootstrap_csv)
write_csv(pair_convergence, artifact_paths$pair_convergence_csv)

plot_weight_mechanics(artifact_paths$weight_mechanics_png)
plot_pair_net_ci(panel$pair_summary, artifact_paths$pair_net_ci_png)
plot_forward_convergence(panel$pair_summary, artifact_paths$forward_ci_png)
plot_gate_heatmap(panel, artifact_paths$gate_heatmap_png)
plot_category_summary(panel, artifact_paths$category_summary_png)
plot_fixed_pair_tapes(panel, query$bars, artifact_paths$fixed_pair_tapes_png)
write_report(
  artifact_paths$report_md,
  panel,
  run_spec,
  c(artifact_paths, query_artifacts$paths)
)

message("LIT-MR-02.1 ", panel_id, " complete: ", panel$overall_status)
message("Data health: ", health_max)
message("Later outcomes opened: ", panel$later_outcomes_opened)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report_md, winslash = "/", mustWork = FALSE))
