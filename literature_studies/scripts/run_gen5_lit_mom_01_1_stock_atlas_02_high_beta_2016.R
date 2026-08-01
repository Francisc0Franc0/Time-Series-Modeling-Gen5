# Run the point-in-time LIT-MOM-01.1 / STOCK_ATLAS_02_HIGH_BETA_2016 replication.

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
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_1_high_beta_2016_atlas.R"
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
  if (!dir.exists(path)) stop("Could not create high-beta output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

high_beta_palette <- c(
  "Consumer Discretionary" = "#F59E0B",
  "Energy" = "#92400E",
  "Financials" = "#2563EB",
  "Health Care" = "#DC2626",
  "Industrials" = "#64748B",
  "Information Technology" = "#06B6D4",
  "Materials" = "#A16207",
  "Real Estate" = "#DB2777",
  "Telecommunication Services" = "#7C3AED"
)

plot_placeholder <- function(path, title, message) {
  png(path, width = 2100, height = 1200, res = 150)
  par(mar = c(2, 2, 5, 2))
  plot.new()
  title(main = title, cex.main = 1.6)
  text(0.5, 0.5, message, cex = 1.4, col = "#475569")
  dev.off()
}

plot_universe <- function(registry, path) {
  counts <- sort(table(registry$sector), decreasing = TRUE)
  png(path, width = 2100, height = 1200, res = 150)
  old <- par(mar = c(6, 18, 5, 3))
  barplot(
    counts,
    horiz = TRUE,
    las = 1,
    col = high_beta_palette[names(counts)],
    border = NA,
    xlab = "Constituents in the October 31, 2016 SPHB filing",
    main = "The point-in-time high-beta universe was concentrated before we tested it"
  )
  text(as.numeric(counts) + 0.5, seq_along(counts) - 0.5, labels = counts, xpd = TRUE)
  par(old)
  dev.off()
}

plot_coverage <- function(coverage, batch_summary, path) {
  counts <- c(
    "Frozen registry" = nrow(coverage),
    "Pre-TRAIN beta available" = sum(is.finite(coverage$pretrain_beta)),
    "Exact TRAIN coverage" = sum(coverage$train_coverage_exact),
    "Six-gate TRAIN pass" = batch_summary$train_pass_count,
    "Authorized OOS replay" = batch_summary$development_run_count
  )
  png(path, width = 2100, height = 1200, res = 150)
  old <- par(mar = c(8, 14, 5, 3))
  barplot(
    rev(counts),
    horiz = TRUE,
    las = 1,
    col = rev(c("#0F172A", "#2563EB", "#14B8A6", "#F59E0B", "#177245")),
    border = NA,
    xlim = c(0, nrow(coverage) * 1.08),
    xlab = "Stocks",
    main = "Coverage attrition is evidence—not a reason to rewrite the 2016 panel"
  )
  text(rev(counts) + 2, seq_along(counts) - 0.3, labels = rev(counts), xpd = TRUE)
  par(old)
  dev.off()
}

plot_direction_asymmetry <- function(development_summary, path) {
  if (!nrow(development_summary)) {
    return(plot_placeholder(path, "Up versus down prediction", "No OOS replay was authorized."))
  }
  long_n <- sum(development_summary$long_sleeves)
  short_n <- sum(development_summary$short_sleeves)
  accuracy <- c(
    LONG = sum(development_summary$long_sleeves * development_summary$long_direction_accuracy) / long_n,
    SHORT = sum(development_summary$short_sleeves * development_summary$short_direction_accuracy) / short_n
  )
  mean_return <- c(
    LONG = sum(development_summary$long_sleeves * development_summary$long_mean_primary_return) / long_n,
    SHORT = sum(development_summary$short_sleeves * development_summary$short_mean_primary_return) / short_n
  )
  png(path, width = 2200, height = 1300, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(7, 7, 6, 3))
  mids <- barplot(
    100 * accuracy,
    col = c("#177245", "#DC2626"),
    border = NA,
    ylim = c(0, 65),
    ylab = "OOS direction accuracy (%)",
    main = "The signal predicted up moves\nbetter than down moves"
  )
  abline(h = 50, lty = 2, lwd = 2, col = "#475569")
  text(mids, 100 * accuracy + 2, labels = sprintf("%.1f%%", 100 * accuracy), cex = 1.2)
  mids <- barplot(
    100 * mean_return,
    col = c("#177245", "#DC2626"),
    border = NA,
    ylab = "Mean primary-net sleeve return (%)",
    main = "Short sleeves turned the symmetric\nstrategy into an OOS loser"
  )
  abline(h = 0, lwd = 1.5, col = "#0F172A")
  text(mids, 100 * mean_return + ifelse(mean_return >= 0, 0.08, -0.08), labels = sprintf("%+.2f%%", 100 * mean_return), pos = ifelse(mean_return >= 0, 3, 1), cex = 1.2)
  par(old)
  dev.off()
}

plot_beta_distribution <- function(coverage, path) {
  x <- coverage[is.finite(coverage$pretrain_beta), , drop = FALSE]
  if (!nrow(x)) return(plot_placeholder(path, "Pre-TRAIN beta", "No finite estimates."))
  png(path, width = 2100, height = 1200, res = 150)
  old <- par(mar = c(7, 7, 5, 3))
  hist(
    x$pretrain_beta,
    breaks = "FD",
    col = "#3D8DFF",
    border = "white",
    xlab = "Estimated 2016 beta to SPY",
    ylab = "Number of filing constituents",
    main = "A contemporaneous high-beta label still spans a wide range of measured beta"
  )
  abline(v = 1, lty = 2, lwd = 2, col = "#DC2626")
  legend("topright", legend = "Market beta = 1", lty = 2, lwd = 2, col = "#DC2626", bty = "n")
  par(old)
  dev.off()
}

plot_selected_horizons <- function(train_summary, grid, path) {
  x <- train_summary[is.finite(train_summary$selected_lookback), , drop = FALSE]
  if (!nrow(x)) return(plot_placeholder(path, "TRAIN-selected horizons", "No coverage-eligible analyses."))
  counts <- matrix(0L, nrow = length(grid), ncol = length(grid))
  rownames(counts) <- grid
  colnames(counts) <- grid
  for (i in seq_len(nrow(x))) {
    counts[as.character(x$selected_lookback[[i]]), as.character(x$selected_holding[[i]])] <-
      counts[as.character(x$selected_lookback[[i]]), as.character(x$selected_holding[[i]])] + 1L
  }
  png(path, width = 1800, height = 1500, res = 150)
  old <- par(mar = c(7, 7, 5, 3))
  image(
    seq_along(grid), seq_along(grid), t(counts),
    col = colorRampPalette(c("#F8FAFC", "#93C5FD", "#1D4ED8"))(20),
    axes = FALSE,
    xlab = "Lookback L (sessions)",
    ylab = "Holding H (sessions)",
    main = "Every stock selected its own horizon using TRAIN only"
  )
  axis(1, at = seq_along(grid), labels = grid)
  axis(2, at = seq_along(grid), labels = grid, las = 1)
  for (i in seq_along(grid)) for (j in seq_along(grid)) {
    if (counts[i, j] > 0) text(i, j, counts[i, j], cex = 1.1)
  }
  par(old)
  dev.off()
}

plot_gate_rates <- function(gates, path) {
  if (!nrow(gates)) return(plot_placeholder(path, "TRAIN gates", "No gates were evaluated."))
  ids <- unique(gates$gate_id)
  rates <- vapply(ids, function(id) mean(gates$passed[gates$gate_id == id]), numeric(1))
  labels <- vapply(ids, function(id) unique(gates$gate[gates$gate_id == id])[[1L]], character(1))
  names(rates) <- paste(ids, labels, sep = " — ")
  png(path, width = 2200, height = 1300, res = 150)
  old <- par(mar = c(7, 27, 5, 3))
  mids <- barplot(
    rev(rates),
    horiz = TRUE,
    las = 1,
    xlim = c(0, 1.08),
    col = ifelse(rev(rates) >= 0.5, "#177245", "#F59E0B"),
    border = NA,
    xlab = "Fraction of coverage-eligible stocks passing",
    main = "The conjunctive TRAIN decision remains harder than any single gate"
  )
  text(rev(rates) + 0.03, mids, labels = sprintf("%.0f%%", 100 * rev(rates)), xpd = TRUE)
  par(old)
  dev.off()
}

plot_beta_vs_train <- function(train_summary, path) {
  x <- train_summary[
    is.finite(train_summary$pretrain_beta) &
      is.finite(train_summary$primary_cumulative_return),
    ,
    drop = FALSE
  ]
  if (!nrow(x)) return(plot_placeholder(path, "Beta versus momentum", "No joint observations."))
  png(path, width = 2100, height = 1300, res = 150)
  old <- par(mar = c(7, 8, 5, 3))
  plot(
    x$pretrain_beta,
    100 * x$primary_cumulative_return,
    pch = 21,
    bg = ifelse(x$train_pass, "#177245", "#94A3B8"),
    col = "white",
    cex = 1.4,
    xlab = "Estimated 2016 beta to SPY",
    ylab = "TRAIN primary cumulative return (%)",
    main = "High beta and time-series momentum are different hypotheses"
  )
  abline(h = 0, v = 1, lty = 2, col = "#CBD5E1")
  pass <- x[x$train_pass, , drop = FALSE]
  if (nrow(pass)) text(pass$pretrain_beta, 100 * pass$primary_cumulative_return, pass$symbol, pos = 3, cex = 0.85)
  legend("bottomright", legend = c("Six-gate TRAIN pass", "TRAIN stop"), pch = 21, pt.bg = c("#177245", "#94A3B8"), col = "white", bty = "n")
  par(old)
  dev.off()
}

plot_train_to_development <- function(train_summary, development_summary, path) {
  if (!nrow(development_summary)) {
    return(plot_placeholder(path, "TRAIN to OOS continuity", "No OOS replay was authorized."))
  }
  x <- merge(
    train_summary[, c("symbol", "primary_cumulative_return")],
    development_summary[, c("symbol", "primary_cumulative_return")],
    by = "symbol",
    suffixes = c("_train", "_development")
  )
  png(path, width = 1900, height = 1400, res = 150)
  old <- par(mar = c(7, 8, 5, 3))
  plot(
    100 * x$primary_cumulative_return_train,
    100 * x$primary_cumulative_return_development,
    pch = 21,
    bg = ifelse(x$primary_cumulative_return_development > 0, "#177245", "#DC2626"),
    col = "white",
    cex = 1.6,
    xlab = "TRAIN primary cumulative return (%)",
    ylab = "OOS primary cumulative return (%)",
    main = "Every six-gate TRAIN passer receives one frozen OOS replay"
  )
  abline(h = 0, v = 0, lty = 2, col = "#CBD5E1")
  text(100 * x$primary_cumulative_return_train, 100 * x$primary_cumulative_return_development, x$symbol, pos = 3, cex = 0.9)
  par(old)
  dev.off()
}

plot_development_paths <- function(development_bars, path) {
  if (!nrow(development_bars)) {
    return(plot_placeholder(path, "OOS strategy paths", "No OOS replay was authorized."))
  }
  symbols <- sort(unique(development_bars$symbol))
  png(path, width = 2200, height = 1300, res = 150)
  old <- par(mar = c(7, 8, 5, 13), xpd = TRUE)
  y_range <- range(development_bars$wealth, finite = TRUE)
  plot(
    as.Date(character()), numeric(), type = "n",
    xlim = range(as.Date(development_bars$outcome_date)),
    ylim = y_range,
    xlab = "OOS DEVELOPMENT session",
    ylab = "Strategy wealth (1.0 at start)",
    main = "Authorized OOS paths stay separate—this is not a portfolio"
  )
  colors <- grDevices::hcl.colors(length(symbols), "Dark 3")
  for (i in seq_along(symbols)) {
    x <- development_bars[development_bars$symbol == symbols[[i]], , drop = FALSE]
    lines(as.Date(x$outcome_date), x$wealth, col = colors[[i]], lwd = 2)
  }
  abline(h = 1, lty = 2, col = "#94A3B8")
  legend("right", inset = c(-0.18, 0), legend = symbols, col = colors, lwd = 2, bty = "n")
  par(old)
  dev.off()
}

plot_representative_tape <- function(development_bars, path) {
  if (!nrow(development_bars)) {
    return(plot_placeholder(path, "Representative OOS behavior", "No OOS replay was authorized."))
  }
  symbol <- sort(unique(development_bars$symbol))[[1L]]
  x <- development_bars[development_bars$symbol == symbol, , drop = FALSE]
  dates <- as.Date(x$outcome_date)
  png(path, width = 2200, height = 1500, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 3))
  plot(dates, x$position, type = "h", lwd = 2, col = ifelse(x$position >= 0, "#177245", "#DC2626"), xlab = "", ylab = "Aggregate sleeve exposure", main = paste(symbol, "OOS exposure: reversals accumulate rather than liquidate instantly"))
  abline(h = 0, col = "#0F172A")
  plot(dates, x$wealth, type = "l", lwd = 3, col = "#2563EB", xlab = "OOS DEVELOPMENT session", ylab = "Primary-cost wealth", main = paste(symbol, "OOS path (alphabetically first authorized replay)"))
  abline(h = 1, lty = 2, col = "#94A3B8")
  par(old)
  dev.off()
}

write_report <- function(path, result, refresh_log, run_spec, artifact_paths) {
  train <- result$train_summary
  development <- result$development_summary
  passers <- train$symbol[train$train_pass]
  lines <- c(
    "# LIT-MOM-01.1 / STOCK_ATLAS_02_HIGH_BETA_2016 Report",
    "",
    paste0("**Status:** `", result$batch_summary$status, "`"),
    "",
    "## Frozen question",
    "",
    "Does the unchanged Chapter 6 horizon-screen-plus-sleeve mechanism recur more often among stocks that were already classified as high beta before TRAIN?",
    "",
    "## Point-in-time universe and coverage",
    "",
    paste0("- Frozen October 31, 2016 SPHB holdings: `", nrow(result$registry), "`."),
    paste0("- Finite pre-TRAIN beta estimates: `", sum(is.finite(result$coverage$pretrain_beta)), " / ", nrow(result$coverage), "`."),
    paste0("- Exact warm-up-plus-TRAIN coverage: `", sum(result$coverage$train_coverage_exact), " / ", nrow(result$coverage), "`."),
    "- Historical-symbol failures and corporate-action attrition remain visible; no survivor-only denominator is substituted.",
    "",
    "## TRAIN",
    "",
    paste0("- Successfully analyzed: `", sum(train$analysis_status != "TRAIN_COVERAGE_STOP"), "`."),
    paste0("- Full six-gate passers: `", sum(train$train_pass), "`."),
    paste0("- Passers: `", if (length(passers)) paste(passers, collapse = ", ") else "none", "`."),
    "",
    "## OOS DEVELOPMENT",
    "",
    paste0("- Authorized complete replays: `", nrow(development), "`."),
    paste0("- Positive primary OOS return: `", if (nrow(development)) sum(development$positive_primary_return) else 0L, " / ", nrow(development), "`."),
    paste0("- Positive stress OOS return: `", if (nrow(development)) sum(development$positive_stress_return) else 0L, " / ", nrow(development), "`."),
    paste0("- All four descriptive continuity flags: `", result$batch_summary$development_all_four_continuity_count, " / ", nrow(development), "`."),
    "",
    "Beta is market sensitivity, not directional persistence. The beta-versus-TRAIN plot is descriptive and cannot be used to retune the universe.",
    "",
    "## Refresh transparency",
    "",
    paste0("- Refresh attempted: `", run_spec$refresh, "`."),
    paste0("- Per-symbol refresh errors: `", sum(refresh_log$status == "ERROR"), "`."),
    "",
    "## Boundary",
    "",
    "Do not select the best stock, pool paths into a portfolio, repair historical tickers after seeing results, or infer that high beta causes momentum. This is a finite textbook replication with 2024+ CONFIRMATION still sealed.",
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

message("LIT-MOM-01.1 / STOCK_ATLAS_02_HIGH_BETA_2016 starting.")
base_contract <- g5_mom01_contract()
registry_path <- file.path(
  repo_root, "literature_studies", "registries",
  "gen5_lit_mom_01_1_stock_atlas_02_high_beta_2016_registry.csv"
)
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
registry <- g5_mom_high_beta_validate_registry(registry)$registry
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_HIGH_BETA_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_HIGH_BETA_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_HIGH_BETA_RUN_ID",
  "lit_mom_01_1_stock_atlas_02_high_beta_2016_20260731"
)
output_dir <- file.path(repo_root, "runs", "research_workbench", "literature_grounded", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

refresh_rows <- list()
symbols <- c(registry$symbol, "SPY")
if (refresh) {
  for (i in seq_along(symbols)) {
    symbol <- symbols[[i]]
    if (i == 1L || i %% 10L == 0L || i == length(symbols)) {
      message("Refreshing symbol ", i, " / ", length(symbols), ": ", symbol)
    }
    refreshed <- tryCatch(
      g5_workbench_query_adjusted_daily_bars(
        cfg = cfg,
        start_date = base_contract$query_start,
        end_date = base_contract$development_end,
        as_of_timestamp = base_contract$as_of_timestamp,
        symbols = symbol,
        universe_name = "lit_mom_01_1_high_beta_2016_refresh",
        universe_roles = "point_in_time_high_beta_constituent",
        refresh = TRUE,
        repo_root = repo_root
      ),
      error = function(error) error
    )
    refresh_rows[[i]] <- data.frame(
      symbol = symbol,
      status = if (inherits(refreshed, "error")) "ERROR" else "COMPLETE",
      message = if (inherits(refreshed, "error")) conditionMessage(refreshed) else "",
      stringsAsFactors = FALSE
    )
  }
} else {
  refresh_rows[[1L]] <- data.frame(
    symbol = "ALL", status = "NOT_REQUESTED", message = "", stringsAsFactors = FALSE
  )
}
refresh_log <- do.call(rbind, refresh_rows)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = base_contract$query_start,
  end_date = base_contract$development_end,
  as_of_timestamp = base_contract$as_of_timestamp,
  symbols = symbols,
  universe_name = "lit_mom_01_1_stock_atlas_02_high_beta_2016",
  universe_roles = "frozen_2016_sphb_constituents,spy_session_reference",
  refresh = FALSE,
  repo_root = repo_root
)
result <- g5_mom_high_beta_run_atlas(query$bars, registry)

artifact_paths <- list(
  run_spec = file.path(output_dir, "high_beta_2016_run_spec.csv"),
  registry = file.path(output_dir, "high_beta_2016_registry.csv"),
  registry_checks = file.path(output_dir, "high_beta_2016_registry_checks.csv"),
  refresh_log = file.path(output_dir, "high_beta_2016_refresh_log.csv"),
  coverage = file.path(output_dir, "high_beta_2016_coverage.csv"),
  batch_summary = file.path(output_dir, "high_beta_2016_batch_summary.csv"),
  train_summary = file.path(output_dir, "high_beta_2016_train_summary.csv"),
  train_gates = file.path(output_dir, "high_beta_2016_train_gates.csv"),
  horizon_screen = file.path(output_dir, "high_beta_2016_horizon_screen.csv"),
  train_bars = file.path(output_dir, "high_beta_2016_train_primary_bars.csv"),
  train_years = file.path(output_dir, "high_beta_2016_train_years.csv"),
  train_sleeves = file.path(output_dir, "high_beta_2016_train_sleeves.csv"),
  development_summary = file.path(output_dir, "high_beta_2016_development_summary.csv"),
  development_bars = file.path(output_dir, "high_beta_2016_development_primary_bars.csv"),
  development_years = file.path(output_dir, "high_beta_2016_development_years.csv"),
  development_sleeves = file.path(output_dir, "high_beta_2016_development_sleeves.csv"),
  universe_png = file.path(visual_dir, "high_beta_2016_universe.png"),
  coverage_png = file.path(visual_dir, "high_beta_2016_coverage.png"),
  beta_distribution_png = file.path(visual_dir, "high_beta_2016_beta_distribution.png"),
  selected_horizons_png = file.path(visual_dir, "high_beta_2016_selected_horizons.png"),
  gate_rates_png = file.path(visual_dir, "high_beta_2016_gate_rates.png"),
  beta_vs_train_png = file.path(visual_dir, "high_beta_2016_beta_vs_train.png"),
  train_to_development_png = file.path(visual_dir, "high_beta_2016_train_to_development.png"),
  development_paths_png = file.path(visual_dir, "high_beta_2016_development_paths.png"),
  representative_tape_png = file.path(visual_dir, "high_beta_2016_representative_tape.png"),
  direction_asymmetry_png = file.path(visual_dir, "high_beta_2016_direction_asymmetry.png"),
  report = file.path(output_dir, "high_beta_2016_report.md")
)

run_spec <- data.frame(
  atlas_id = g5_mom_high_beta_atlas_id(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_01_1_stock_atlas_02_high_beta_2016.R",
  run_id = run_id,
  source_report_date = as.Date("2016-10-31"),
  source_url = unique(registry$source_url),
  as_of_timestamp = base_contract$as_of_timestamp,
  query_start = base_contract$query_start,
  train_start = base_contract$train_start,
  train_end = base_contract$train_end,
  development_start = base_contract$development_start,
  development_end = base_contract$development_end,
  confirmation_opened = FALSE,
  registry_count = nrow(registry),
  sector_count = length(unique(registry$sector)),
  refresh = refresh,
  feed = cfg$feed,
  health_max_severity = query$manifest$health_max_severity,
  status = result$batch_summary$status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, artifact_paths$run_spec)
write_csv(result$registry, artifact_paths$registry)
write_csv(result$registry_checks, artifact_paths$registry_checks)
write_csv(refresh_log, artifact_paths$refresh_log)
write_csv(result$coverage, artifact_paths$coverage)
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

plot_universe(result$registry, artifact_paths$universe_png)
plot_coverage(result$coverage, result$batch_summary, artifact_paths$coverage_png)
plot_beta_distribution(result$coverage, artifact_paths$beta_distribution_png)
plot_selected_horizons(result$train_summary, base_contract$horizon_grid, artifact_paths$selected_horizons_png)
plot_gate_rates(result$train_gates, artifact_paths$gate_rates_png)
plot_beta_vs_train(result$train_summary, artifact_paths$beta_vs_train_png)
plot_train_to_development(result$train_summary, result$development_summary, artifact_paths$train_to_development_png)
plot_development_paths(result$development_bars, artifact_paths$development_paths_png)
plot_representative_tape(result$development_bars, artifact_paths$representative_tape_png)
plot_direction_asymmetry(result$development_summary, artifact_paths$direction_asymmetry_png)
write_report(artifact_paths$report, result, refresh_log, run_spec, artifact_paths)
invisible(g5_write_workbench_query_artifacts(
  query, output_dir, "high_beta_2016_workbench_query"
))

message("LIT-MOM-01.1 / STOCK_ATLAS_02_HIGH_BETA_2016 complete: ", result$batch_summary$status)
message("TRAIN coverage: ", result$batch_summary$train_coverage_count, " / ", result$batch_summary$registry_count)
message("TRAIN passes: ", result$batch_summary$train_pass_count)
message("OOS replays: ", result$batch_summary$development_run_count)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report, winslash = "/", mustWork = FALSE))
