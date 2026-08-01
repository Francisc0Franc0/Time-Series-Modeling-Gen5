# Run the frozen LIT-MOM-01.1 / STOCK_ATLAS_01 breadth replication.

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
  "gen5_lit_mom_01_1_interday_momentum_poc.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_1_stock_atlas.R"
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
  if (!dir.exists(path)) stop("Could not create stock-atlas output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

coverage_audit <- function(bars, registry, contract) {
  spy_dates <- sort(unique(as.Date(bars$session_date[bars$symbol == "SPY"])))
  expected <- spy_dates[
    spy_dates >= contract$query_start & spy_dates <= contract$development_end
  ]
  rows <- lapply(registry$symbol, function(symbol) {
    observed <- sort(unique(as.Date(bars$session_date[bars$symbol == symbol])))
    observed <- observed[
      observed >= contract$query_start & observed <= contract$development_end
    ]
    missing <- setdiff(expected, observed)
    data.frame(
      symbol = symbol,
      observed_sessions = length(observed),
      expected_sessions = length(expected),
      first_observed = if (length(observed)) as.character(min(observed)) else NA_character_,
      last_observed = if (length(observed)) as.character(max(observed)) else NA_character_,
      missing_spy_sessions = length(missing),
      query_start_covered = length(observed) > 0 && min(observed) <= min(expected),
      development_end_covered = length(observed) > 0 && max(observed) >= max(expected),
      exact_session_match = length(missing) == 0L && length(observed) == length(expected),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

sector_palette <- c(
  "Communication Services" = "#8B5CF6",
  "Consumer Discretionary" = "#F59E0B",
  "Consumer Staples" = "#177245",
  "Energy" = "#7C3F00",
  "Financials" = "#2563EB",
  "Health Care" = "#DC2626",
  "Industrials" = "#64748B",
  "Information Technology" = "#06B6D4",
  "Materials" = "#A16207",
  "Real Estate" = "#DB2777",
  "Utilities" = "#0F766E"
)

plot_selected_horizons <- function(train_summary, grid, path) {
  counts <- matrix(0L, nrow = length(grid), ncol = length(grid))
  passes <- matrix(0L, nrow = length(grid), ncol = length(grid))
  for (i in seq_len(nrow(train_summary))) {
    row_i <- match(train_summary$selected_holding[[i]], grid)
    col_i <- match(train_summary$selected_lookback[[i]], grid)
    counts[row_i, col_i] <- counts[row_i, col_i] + 1L
    passes[row_i, col_i] <- passes[row_i, col_i] + as.integer(train_summary$train_pass[[i]])
  }
  png(path, width = 1900, height = 1250, res = 150)
  old <- par(mar = c(7, 7, 6, 2))
  image(
    seq_along(grid), seq_along(grid), t(counts),
    col = grDevices::colorRampPalette(c("#F8FAFC", "#9BC7B1", "#177245"))(10),
    axes = FALSE,
    xlab = "Lookback sessions",
    ylab = "Holding sessions",
    main = "Frozen TRAIN horizon selections across 22 stocks"
  )
  axis(1, at = seq_along(grid), labels = grid)
  axis(2, at = seq_along(grid), labels = grid, las = 1)
  for (holding_i in seq_along(grid)) {
    for (lookback_i in seq_along(grid)) {
      if (counts[holding_i, lookback_i] > 0L) {
        text(
          lookback_i, holding_i,
          paste0(counts[holding_i, lookback_i], " selected\n", passes[holding_i, lookback_i], " TRAIN pass"),
          font = 2,
          cex = 0.95
        )
      }
    }
  }
  mtext("Cell labels show selection count and full six-gate TRAIN pass count", side = 1, line = 4.8, col = "#3D8DFF", font = 2)
  par(old)
  dev.off()
}

plot_gate_matrix <- function(gates, registry, path) {
  gates$symbol <- factor(gates$symbol, levels = rev(registry$symbol))
  matrix_values <- matrix(
    NA_real_, nrow = nrow(registry), ncol = 6L,
    dimnames = list(rev(registry$symbol), paste0("G", 1:6))
  )
  for (i in seq_len(nrow(gates))) {
    matrix_values[as.character(gates$symbol[[i]]), gates$gate_id[[i]]] <-
      as.integer(gates$passed[[i]])
  }
  png(path, width = 1750, height = 1500, res = 150)
  old <- par(mar = c(7, 7, 5, 2))
  image(
    seq_len(6), seq_len(nrow(matrix_values)), t(matrix_values),
    col = c("#B42318", "#177245"),
    axes = FALSE,
    xlab = "Frozen TRAIN gate",
    ylab = "Stock",
    main = "Every stock remains visible: PASS (green) or FAIL (red)"
  )
  axis(1, at = 1:6, labels = paste0("G", 1:6))
  axis(2, at = seq_len(nrow(matrix_values)), labels = rownames(matrix_values), las = 1)
  text(
    rep(seq_len(6), each = nrow(matrix_values)),
    rep(seq_len(nrow(matrix_values)), times = 6),
    ifelse(as.vector(matrix_values) == 1, "PASS", "FAIL"),
    col = "white",
    font = 2,
    cex = 0.72
  )
  par(old)
  dev.off()
}

plot_train_evidence <- function(train_summary, path) {
  colors <- unname(sector_palette[train_summary$sector])
  pch <- ifelse(train_summary$train_pass, 17, 19)
  png(path, width = 1900, height = 1250, res = 150)
  old <- par(mar = c(7, 7, 5, 3))
  plot(
    100 * train_summary$direction_accuracy,
    100 * train_summary$primary_cumulative_return,
    pch = pch,
    col = colors,
    bg = colors,
    cex = 1.5,
    xlab = "TRAIN past-sign / future-sign accuracy (%)",
    ylab = "TRAIN primary-cost cumulative return (%)",
    main = "Prediction and P&L are related questions—not the same gate"
  )
  abline(v = 50, h = 0, lty = 2, col = "#64748B")
  text(
    100 * train_summary$direction_accuracy,
    100 * train_summary$primary_cumulative_return,
    labels = train_summary$symbol,
    pos = 3,
    cex = 0.8
  )
  legend(
    "topleft",
    legend = c("Six-gate TRAIN pass", "TRAIN stop"),
    pch = c(17, 19),
    col = "#0F172A",
    bty = "n"
  )
  par(old)
  dev.off()
}

plot_canonical_comparison <- function(train_summary, path) {
  colors <- unname(sector_palette[train_summary$sector])
  range_values <- range(
    100 * train_summary$canonical_primary_cumulative_return,
    100 * train_summary$primary_cumulative_return,
    finite = TRUE
  )
  png(path, width = 1500, height = 1250, res = 150)
  old <- par(mar = c(7, 7, 5, 3))
  plot(
    100 * train_summary$canonical_primary_cumulative_return,
    100 * train_summary$primary_cumulative_return,
    pch = ifelse(train_summary$train_pass, 17, 19),
    col = colors,
    bg = colors,
    cex = 1.5,
    xlim = range_values,
    ylim = range_values,
    xlab = "Canonical 250/25 TRAIN return (%)",
    ylab = "Frozen selected-horizon TRAIN return (%)",
    main = "The horizon screen changes the rule; it does not guarantee a pass"
  )
  abline(a = 0, b = 1, lty = 2, col = "#64748B")
  abline(h = 0, v = 0, lty = 3, col = "#CBD5E1")
  text(
    100 * train_summary$canonical_primary_cumulative_return,
    100 * train_summary$primary_cumulative_return,
    labels = train_summary$symbol,
    pos = 3,
    cex = 0.78
  )
  par(old)
  dev.off()
}

plot_train_to_development <- function(train_summary, development_summary, path) {
  png(path, width = 2200, height = 900, res = 150)
  old <- par(mfrow = c(1, 3), mar = c(6, 6, 5, 2))
  if (!nrow(development_summary)) {
    plot.new()
    text(0.5, 0.5, "No stock passed all six TRAIN gates; DEVELOPMENT stayed sealed.", cex = 1.5)
    par(old)
    dev.off()
    return(invisible(path))
  }
  joined <- merge(
    train_summary,
    development_summary,
    by = c("instance_id", "symbol", "sector"),
    suffixes = c("_train", "_development")
  )
  comparisons <- list(
    list(
      values = c(joined$direction_accuracy_train[[1L]], joined$direction_accuracy_development[[1L]]) * 100,
      title = "Direction accuracy (%)",
      ylim = c(0, 70),
      reference = 50,
      digits = 1L
    ),
    list(
      values = c(joined$primary_cumulative_return_train[[1L]], joined$primary_cumulative_return_development[[1L]]) * 100,
      title = "Primary cumulative return (%)",
      ylim = c(-12, 48),
      reference = 0,
      digits = 1L
    ),
    list(
      values = c(joined$screen_correlation[[1L]], joined$correlation[[1L]]),
      title = "Past/future return correlation",
      ylim = c(0, 0.22),
      reference = 0,
      digits = 3L
    )
  )
  for (comparison in comparisons) {
    mids <- barplot(
      comparison$values,
      names.arg = c("TRAIN", "OOS\nDEVELOPMENT"),
      col = c("#3D8DFF", "#F59E0B"),
      ylim = comparison$ylim,
      main = comparison$title,
      ylab = comparison$title
    )
    abline(h = comparison$reference, lty = 2, col = "#64748B")
    text(
      mids,
      comparison$values,
      labels = formatC(comparison$values, format = "f", digits = comparison$digits),
      pos = ifelse(comparison$values >= 0, 3, 1),
      font = 2
    )
  }
  par(old)
  dev.off()
}

plot_development_paths <- function(development_bars, path) {
  png(path, width = 1900, height = 1200, res = 150)
  old <- par(mar = c(7, 7, 5, 3))
  if (!nrow(development_bars)) {
    plot.new()
    text(0.5, 0.5, "No OOS paths: no stock passed all six TRAIN gates.", cex = 1.5)
  } else {
    symbols <- unique(development_bars$symbol)
    x_range <- range(as.Date(development_bars$entry_date))
    y_range <- range(development_bars$wealth, finite = TRUE)
    plot(
      x_range, y_range,
      type = "n",
      xlab = "OOS DEVELOPMENT date",
      ylab = "Growth of $1 after primary costs",
      main = "Every authorized OOS path is shown; no winner is selected"
    )
    abline(h = 1, lty = 2, col = "#64748B")
    for (symbol in symbols) {
      x <- development_bars[development_bars$symbol == symbol, , drop = FALSE]
      lines(
        as.Date(x$entry_date), x$wealth,
        col = unname(sector_palette[x$sector[[1L]]]),
        lwd = 2
      )
      text(
        max(as.Date(x$entry_date)), tail(x$wealth, 1L),
        labels = symbol,
        pos = 4,
        cex = 0.75,
        col = unname(sector_palette[x$sector[[1L]]])
      )
    }
  }
  par(old)
  dev.off()
}

plot_sector_breadth <- function(train_summary, development_summary, path) {
  sectors <- g5_mom_stock_atlas_expected_sectors()
  train_pass <- vapply(sectors, function(sector) {
    sum(train_summary$train_pass[train_summary$sector == sector])
  }, integer(1))
  oos_positive <- vapply(sectors, function(sector) {
    if (!nrow(development_summary)) return(0L)
    sum(
      development_summary$positive_primary_return[
        development_summary$sector == sector
      ]
    )
  }, integer(1))
  values <- rbind(train_pass, oos_positive)
  png(path, width = 2100, height = 1200, res = 150)
  old <- par(mar = c(13, 7, 5, 2))
  barplot(
    values,
    beside = TRUE,
    names.arg = sectors,
    las = 2,
    col = c("#3D8DFF", "#177245"),
    ylim = c(0, 2.4),
    ylab = "Stocks out of two per sector",
    main = "Breadth is reported by sector—not converted into a portfolio"
  )
  legend(
    "topright",
    legend = c("Six-gate TRAIN pass", "OOS positive primary return"),
    fill = c("#3D8DFF", "#177245"),
    bty = "n"
  )
  par(old)
  dev.off()
}

write_report <- function(path, result, coverage, run_spec, artifact_paths) {
  train <- result$train_summary
  development <- result$development_summary
  passers <- train$symbol[train$train_pass]
  lines <- c(
    "# LIT-MOM-01.1 / STOCK_ATLAS_01 Report",
    "",
    paste0("**Status:** `", result$batch_summary$status, "`"),
    "",
    "## Frozen question",
    "",
    "Does the exact Chapter 6 horizon-screen-plus-sleeve mechanism replicate across a balanced 22-stock, eleven-sector atlas without selecting a winner?",
    "",
    "## Coverage",
    "",
    paste0("- Stocks with exact SPY-session coverage: `", sum(coverage$exact_session_match), " / ", nrow(coverage), "`."),
    paste0("- Query: `", run_spec$query_start, "` through `", run_spec$development_end, "`; CONFIRMATION remains sealed."),
    "- The static July 2026 registry has survivor and membership bias; it is a breadth demonstration, not a historical point-in-time universe.",
    "",
    "## TRAIN breadth",
    "",
    paste0("- Full six-gate TRAIN passers: `", sum(train$train_pass), " / ", nrow(train), "`."),
    paste0("- Passers: `", if (length(passers)) paste(passers, collapse = ", ") else "none", "`."),
    paste0("- Positive primary TRAIN return: `", sum(train$primary_cumulative_return > 0), " / ", nrow(train), "`."),
    paste0("- Direction accuracy above 50%: `", sum(train$direction_accuracy > 0.5), " / ", nrow(train), "`."),
    "",
    "Every stock retained its own frozen TRAIN-selected horizon. The atlas did not select one common stock or one common horizon after outcomes.",
    "",
    "## OOS DEVELOPMENT",
    "",
    paste0("- Authorized OOS replays: `", nrow(development), "`."),
    paste0("- Positive primary OOS return: `", if (nrow(development)) sum(development$positive_primary_return) else 0L, " / ", nrow(development), "`."),
    paste0("- Positive stress OOS return: `", if (nrow(development)) sum(development$positive_stress_return) else 0L, " / ", nrow(development), "`."),
    paste0("- OOS direction accuracy above 50%: `", if (nrow(development)) sum(development$direction_above_chance) else 0L, " / ", nrow(development), "`."),
    paste0("- All four descriptive continuity flags: `", result$batch_summary$development_all_four_continuity_count, " / ", nrow(development), "`."),
    "",
    "These OOS flags are descriptive; no new promotion gate was invented after inspection. Every TRAIN passer was replayed and remains visible.",
    "",
    "## Boundary",
    "",
    "Do not choose the best stock, delete failures, pool these paths into a portfolio, or retune a horizon from this atlas. The completed packet is breadth evidence for the textbook mechanism, not stock-selection or live-trading authority.",
    "",
    "## Key artifacts",
    ""
  )
  for (name in names(artifact_paths)) {
    lines <- c(lines, paste0("- `", name, "`: `", normalizePath(artifact_paths[[name]], winslash = "/", mustWork = FALSE), "`"))
  }
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("LIT-MOM-01.1 / STOCK_ATLAS_01 starting.")
base_contract <- g5_mom01_contract()
registry_path <- file.path(
  repo_root, "literature_studies", "registries",
  "gen5_lit_mom_01_1_stock_atlas_01_registry.csv"
)
registry <- utils::read.csv(
  registry_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
registry <- g5_mom_stock_validate_registry(registry)$registry
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_STOCK_ATLAS_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_STOCK_ATLAS_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_STOCK_ATLAS_RUN_ID",
  "lit_mom_01_1_stock_atlas_01_20260731"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = base_contract$query_start,
  end_date = base_contract$development_end,
  as_of_timestamp = base_contract$as_of_timestamp,
  symbols = c(registry$symbol, "SPY"),
  universe_name = "lit_mom_01_1_stock_atlas_01_and_spy_reference",
  universe_roles = "frozen_stock_atlas,spy_session_reference",
  refresh = refresh,
  repo_root = repo_root
)
coverage <- coverage_audit(query$bars, registry, base_contract)
if (!all(coverage$query_start_covered & coverage$development_end_covered)) {
  stop("STOCK_ATLAS_01 bounded coverage failed.", call. = FALSE)
}
result <- g5_mom_stock_run_atlas(query$bars, registry)

artifact_paths <- list(
  run_spec = file.path(output_dir, "stock_atlas_01_run_spec.csv"),
  registry = file.path(output_dir, "stock_atlas_01_registry.csv"),
  registry_checks = file.path(output_dir, "stock_atlas_01_registry_checks.csv"),
  coverage = file.path(output_dir, "stock_atlas_01_coverage.csv"),
  batch_summary = file.path(output_dir, "stock_atlas_01_batch_summary.csv"),
  train_summary = file.path(output_dir, "stock_atlas_01_train_summary.csv"),
  train_gates = file.path(output_dir, "stock_atlas_01_train_gates.csv"),
  horizon_screen = file.path(output_dir, "stock_atlas_01_horizon_screen.csv"),
  train_bars = file.path(output_dir, "stock_atlas_01_train_primary_bars.csv"),
  train_years = file.path(output_dir, "stock_atlas_01_train_years.csv"),
  train_sleeves = file.path(output_dir, "stock_atlas_01_train_sleeves.csv"),
  development_summary = file.path(output_dir, "stock_atlas_01_development_summary.csv"),
  development_bars = file.path(output_dir, "stock_atlas_01_development_primary_bars.csv"),
  development_years = file.path(output_dir, "stock_atlas_01_development_years.csv"),
  development_sleeves = file.path(output_dir, "stock_atlas_01_development_sleeves.csv"),
  selected_horizons_png = file.path(visual_dir, "stock_atlas_01_selected_horizons.png"),
  gate_matrix_png = file.path(visual_dir, "stock_atlas_01_gate_matrix.png"),
  train_evidence_png = file.path(visual_dir, "stock_atlas_01_train_evidence.png"),
  canonical_comparison_png = file.path(visual_dir, "stock_atlas_01_canonical_comparison.png"),
  train_to_development_png = file.path(visual_dir, "stock_atlas_01_train_to_development.png"),
  development_paths_png = file.path(visual_dir, "stock_atlas_01_development_paths.png"),
  sector_breadth_png = file.path(visual_dir, "stock_atlas_01_sector_breadth.png"),
  report = file.path(output_dir, "stock_atlas_01_report.md")
)

health <- query$health
health_max <- if (!nrow(health)) "PASS" else {
  severity_rank <- c(INFO = 1L, WARN = 2L, ERROR = 3L)
  names(which.max(tapply(severity_rank[health$severity], health$severity, max)))
}
run_spec <- data.frame(
  atlas_id = g5_mom_stock_atlas_id(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_01_1_stock_atlas_01.R",
  run_id = run_id,
  as_of_timestamp = base_contract$as_of_timestamp,
  query_start = base_contract$query_start,
  train_start = base_contract$train_start,
  train_end = base_contract$train_end,
  development_start = base_contract$development_start,
  development_end = base_contract$development_end,
  confirmation_opened = FALSE,
  stock_count = nrow(registry),
  sector_count = length(unique(registry$sector)),
  refresh = refresh,
  feed = cfg$feed,
  health_max_severity = health_max,
  status = result$batch_summary$status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, artifact_paths$run_spec)
write_csv(result$registry, artifact_paths$registry)
write_csv(result$registry_checks, artifact_paths$registry_checks)
write_csv(coverage, artifact_paths$coverage)
write_csv(result$batch_summary, artifact_paths$batch_summary)
write_csv(result$train_summary, artifact_paths$train_summary)
write_csv(result$train_gates, artifact_paths$train_gates)
write_csv(result$horizon_screen, artifact_paths$horizon_screen)
write_csv(result$train_bars, artifact_paths$train_bars)
write_csv(result$train_years, artifact_paths$train_years)
write_csv(result$train_sleeves, artifact_paths$train_sleeves)
write_csv(result$development_summary, artifact_paths$development_summary)
write_csv(result$development_bars, artifact_paths$development_bars)
write_csv(result$development_years, artifact_paths$development_years)
write_csv(result$development_sleeves, artifact_paths$development_sleeves)

plot_selected_horizons(
  result$train_summary,
  base_contract$horizon_grid,
  artifact_paths$selected_horizons_png
)
plot_gate_matrix(result$train_gates, result$registry, artifact_paths$gate_matrix_png)
plot_train_evidence(result$train_summary, artifact_paths$train_evidence_png)
plot_canonical_comparison(result$train_summary, artifact_paths$canonical_comparison_png)
plot_train_to_development(
  result$train_summary,
  result$development_summary,
  artifact_paths$train_to_development_png
)
plot_development_paths(result$development_bars, artifact_paths$development_paths_png)
plot_sector_breadth(
  result$train_summary,
  result$development_summary,
  artifact_paths$sector_breadth_png
)
write_report(artifact_paths$report, result, coverage, run_spec, artifact_paths)
invisible(g5_write_workbench_query_artifacts(
  query,
  output_dir,
  "stock_atlas_01_workbench_query"
))

message("LIT-MOM-01.1 / STOCK_ATLAS_01 complete: ", result$batch_summary$status)
message("TRAIN passes: ", result$batch_summary$train_pass_count, " / ", result$batch_summary$stock_count)
message("OOS replays: ", result$batch_summary$development_run_count)
message("Data health: ", health_max)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report, winslash = "/", mustWork = FALSE))
