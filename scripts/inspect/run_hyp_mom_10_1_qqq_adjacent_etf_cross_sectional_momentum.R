# Run frozen HYP-MOM-10.1 TRAIN, then DEVELOPMENT only after a TRAIN pass.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "scripts/inspect/run_hyp_mom_10_1_qqq_adjacent_etf_cross_sectional_momentum.R"
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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mom_10_1_qqq_adjacent_etf_cross_sectional_momentum.R"))
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
  if (!dir.exists(path)) stop("Could not create HYP-MOM-10.1 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract_table <- function(contract) {
  fields <- setdiff(names(contract), "universe")
  rbind(
    data.frame(field = fields, value = vapply(contract[fields], function(x) paste(x, collapse = ","), character(1)), stringsAsFactors = FALSE),
    data.frame(field = "universe", value = paste(paste(contract$universe$symbol, contract$universe$sleeve, sep = ":"), collapse = ","), stringsAsFactors = FALSE)
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
    symbols = contract$universe$symbol,
    universe_name = universe_name,
    universe_roles = contract$universe$sleeve,
    refresh = refresh,
    repo_root = repo_root
  )
}

coverage_table <- function(bars, contract, requested_end) {
  do.call(rbind, lapply(contract$universe$symbol, function(symbol) {
    dates <- sort(unique(as.Date(bars$session_date[bars$symbol == symbol])))
    data.frame(
      symbol = symbol,
      sleeve = contract$universe$sleeve[match(symbol, contract$universe$symbol)],
      first_session = if (length(dates)) min(dates) else as.Date(NA),
      last_session = if (length(dates)) max(dates) else as.Date(NA),
      row_count = length(dates),
      duplicate_sessions = sum(duplicated(dates)),
      requested_end_covered = length(dates) && max(dates) >= as.Date(requested_end),
      stringsAsFactors = FALSE
    )
  }))
}

source_audit <- function(coverage, bars, contract, requested_end) {
  data.frame(
    check_id = c("exact_frozen_basket", "adjusted_daily_only", "all_requested_ends_covered", "positive_finite_ohlcv", "requested_boundary_respected", "post_2025_excluded"),
    passed = c(
      setequal(unique(as.character(bars$symbol)), contract$universe$symbol),
      all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
      all(coverage$requested_end_covered),
      all(is.finite(as.matrix(bars[c("open", "high", "low", "close", "volume")]))) && all(as.matrix(bars[c("open", "high", "low", "close", "volume")]) > 0),
      max(as.Date(bars$session_date)) <= as.Date(requested_end),
      max(as.Date(bars$session_date)) < as.Date("2026-01-01")
    ),
    observed = c(
      paste(sort(unique(as.character(bars$symbol))), collapse = ","),
      paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
      paste(coverage$symbol, coverage$last_session, sep = "=", collapse = ";"),
      paste(range(as.matrix(bars[c("open", "high", "low", "close", "volume")])), collapse = " to "),
      as.character(max(as.Date(bars$session_date))),
      as.character(max(as.Date(bars$session_date)))
    ),
    stringsAsFactors = FALSE
  )
}

plot_surface <- function(surface, path, contract) {
  grDevices::png(path, width = 1800, height = 900, res = 150)
  old <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  for (metric in c("mean_daily_rank_ic", "mean_top_minus_bottom")) {
    values <- matrix(NA_real_, nrow = 3L, ncol = 3L)
    for (i in seq_len(nrow(surface))) values[match(surface$lookback_sessions[[i]], contract$lookback_grid), match(surface$target_sessions[[i]], contract$target_grid)] <- surface[[metric]][[i]]
    limit <- max(abs(values), na.rm = TRUE)
    graphics::image(seq_along(contract$target_grid), seq_along(contract$lookback_grid), t(values), col = grDevices::colorRampPalette(c("#B42318", "#F8FAFC", "#177245"))(101), zlim = c(-limit, limit), axes = FALSE, xlab = "Forward horizon H", ylab = "Trailing lookback L", main = if (metric == "mean_daily_rank_ic") "TRAIN mean daily rank IC" else "TRAIN top-three minus bottom-three")
    graphics::axis(1, at = seq_along(contract$target_grid), labels = contract$target_grid)
    graphics::axis(2, at = seq_along(contract$lookback_grid), labels = contract$lookback_grid)
    for (r in 1:3) for (c in 1:3) graphics::text(c, r, sprintf(if (metric == "mean_daily_rank_ic") "%.3f" else "%.4f", values[r, c]), cex = 0.95)
  }
}

plot_shift <- function(distribution, decision, path) {
  grDevices::png(path, width = 1500, height = 900, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::hist(distribution$maximum_mean_daily_rank_ic, breaks = 35, col = "#D7E3F4", border = "white", xlab = "Maximum mean rank IC across nine cells", main = "Family-wise time-shift control")
  graphics::abline(v = decision$shift_maximum_p90, col = "#B7791F", lwd = 3, lty = 2)
  graphics::abline(v = decision$observed_maximum_mean_daily_rank_ic, col = "#166534", lwd = 3)
  graphics::legend("topright", c("Observed maximum", "Shift-null p90"), col = c("#166534", "#B7791F"), lwd = 3, lty = c(1, 2), bty = "n")
}

plot_random <- function(random, path) {
  grDevices::png(path, width = 1500, height = 900, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::hist(random$randomized_mean_top_minus_bottom, breaks = 35, col = "#D7E3F4", border = "white", xlab = "Randomized mean top-minus-bottom", main = "Within-date randomized-rank specificity control")
  graphics::abline(v = random$random_p90[[1L]], col = "#B7791F", lwd = 3, lty = 2)
  graphics::abline(v = random$observed_mean_top_minus_bottom[[1L]], col = "#166534", lwd = 3)
}

plot_overlap <- function(overlap, path, symbols) {
  matrix <- diag(1, length(symbols)); dimnames(matrix) <- list(symbols, symbols)
  for (i in seq_len(nrow(overlap))) matrix[overlap$symbol_1[[i]], overlap$symbol_2[[i]]] <- matrix[overlap$symbol_2[[i]], overlap$symbol_1[[i]]] <- overlap$daily_return_correlation[[i]]
  grDevices::png(path, width = 1200, height = 1050, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(7, 7, 4, 2))
  graphics::image(seq_along(symbols), seq_along(symbols), t(matrix), col = grDevices::colorRampPalette(c("#F8FAFC", "#147D8C", "#172033"))(101), zlim = c(0, 1), axes = FALSE, xlab = "", ylab = "", main = "TRAIN daily-return overlap is explicit")
  graphics::axis(1, at = seq_along(symbols), labels = symbols, las = 2)
  graphics::axis(2, at = seq_along(symbols), labels = symbols, las = 2)
}

plot_tapes <- function(panel, cell, path, contract) {
  idx <- g5_hm101_cell_indices(contract, cell$lookback_sessions[[1L]], cell$target_sessions[[1L]])
  dispersion <- apply(panel$relative_x[[idx$l_i]], 1L, stats::sd)
  candidates <- order(dispersion, decreasing = TRUE)
  selected <- integer()
  for (i in candidates) {
    if (!length(selected) || all(abs(i - selected) >= 80L)) selected <- c(selected, i)
    if (length(selected) == 3L) break
  }
  grDevices::png(path, width = 1800, height = 850, res = 150)
  old <- graphics::par(mfrow = c(1, 3), mar = c(7, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  for (i in sort(selected)) {
    ord <- order(panel$relative_x[[idx$l_i]][i, ], decreasing = TRUE)
    y <- panel$relative_y[[idx$h_i]][i, ord]
    graphics::barplot(y, names.arg = panel$symbols[ord], las = 2, col = ifelse(seq_along(ord) <= 3, "#147D8C", ifelse(seq_along(ord) > 9, "#E97132", "#CBD5E1")), ylab = "Forward basket-relative log return", main = as.character(panel$anchor_date[[i]]))
    graphics::abline(h = 0, col = "#64748B")
  }
}

write_report <- function(train, development, coverage, source_checks, run_spec, paths) {
  best <- train$best[1L, ]; decision <- train$decision[1L, ]; random <- train$randomized_rank[1L, ]
  lines <- c(
    "# HYP-MOM-10.1 QQQ-Adjacent ETF Cross-Sectional Momentum Results", "",
    paste0("Status: `", run_spec$overall_status[[1L]], "`"), "",
    "## Question", "",
    "Do recent relative leaders within a frozen 12-ETF growth/technology basket continue to outperform recent relative laggards?", "",
    "## Source and construction", "",
    paste0("- Source gates: `", sum(source_checks$passed), " / ", nrow(source_checks), "` pass."),
    paste0("- Basket coverage through TRAIN end: `", sum(coverage$requested_end_covered), " / ", nrow(coverage), "` funds."),
    paste0("- Common TRAIN anchor dates: `", length(train$panel$anchor_date), "`; asset-date rows per cell: `", length(train$panel$anchor_date) * length(train$panel$symbols), "`."),
    "- Both predictor and target subtract their same-date basket common return; no common market direction can supply the registered relative ordering.",
    paste0("- Mean pairwise daily-return correlation: `", sprintf("%.3f", mean(train$overlap$daily_return_correlation)), "`; overlap is treated as a limitation, not independent replication."), "",
    "## TRAIN readout", "",
    paste0("- Best observed cell: `", best$cell_id, "`; mean daily rank IC `", sprintf("%.6f", best$mean_daily_rank_ic), "`; top-minus-bottom `", sprintf("%.6f", best$mean_top_minus_bottom), "`."),
    paste0("- Worst leave-one-sleeve-out IC: `", sprintf("%.6f", best$minimum_leave_one_sleeve_out_ic), "`."),
    paste0("- Shift-maximum p90: `", sprintf("%.6f", decision$shift_maximum_p90), "`; empirical upper-tail probability `", sprintf("%.6f", decision$empirical_upper_tail_probability), "`."),
    paste0("- Same-cell randomized-rank p90: `", sprintf("%.6f", random$random_p90), "`; observed ordering `", sprintf("%.6f", random$observed_mean_top_minus_bottom), "`."),
    paste0("- TRAIN decision: `", decision$status, "`."), ""
  )
  if (is.null(development)) {
    lines <- c(lines, "## DEVELOPMENT boundary", "", "DEVELOPMENT was not queried or calculated because the complete frozen TRAIN gate failed.", "")
  } else {
    lines <- c(lines, "## DEVELOPMENT readout", "", paste0("- Mean daily rank IC: `", sprintf("%.6f", development$mean_daily_rank_ic), "`; top-minus-bottom `", sprintf("%.6f", development$mean_top_minus_bottom), "`."), paste0("- Bootstrap P(mean IC > 0): `", sprintf("%.4f", development$bootstrap$probability_positive), "`."), paste0("- Gates: `", sum(development$gates$passed), " / ", nrow(development$gates), "` pass."), paste0("- Decision: `", development$overall_status, "`."), "")
  }
  lines <- c(lines, "## Interpretation", "", if (is.null(development)) "The strongest of nine relative-ranking cells was not sufficiently unusual under the registered family-wise control, or it failed ordering/sleeve breadth. No horizon is selected." else if (all(development$gates$passed)) "The single TRAIN nominee transported to DEVELOPMENT and now requires operator review before any confirmation access." else "The frozen nominee failed at least one DEVELOPMENT gate. Stop without changing the basket, horizon, or direction.", "", "This is predictor evidence only. No portfolio or performance calculation was made.", "", "## Artifacts", "", paste0("- TRAIN surface: `", basename(paths$surface), "`"), paste0("- Shift control: `", basename(paths$shift), "`"), paste0("- Randomized-rank control: `", basename(paths$random), "`"), paste0("- Sleeve diagnostics: `", basename(paths$sleeves), "`"), paste0("- Overlap diagnostics: `", basename(paths$overlap), "`"))
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("HYP-MOM-10.1 frozen TRAIN stage starting.")
contract <- g5_hm101_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_HYP_MOM_10_1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_HYP_MOM_10_1_REFRESH", FALSE)
run_id <- env_or("GEN5_HYP_MOM_10_1_RUN_ID", "hyp_mom_10_1_qqq_adjacent_etf_cross_sectional_momentum_20260822")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

train_query <- query_zone(cfg, contract, contract$train_end, "hyp_mom_10_1_train", refresh)
train_coverage <- coverage_table(train_query$bars, contract, contract$train_end)
source_checks <- source_audit(train_coverage, train_query$bars, contract, contract$train_end)
if (!all(source_checks$passed)) stop("HYP-MOM-10.1 source feasibility audit failed.", call. = FALSE)
train <- g5_hm101_run_train(train_query$bars, contract)

development <- NULL; development_query <- NULL
if (isTRUE(train$decision$passed[[1L]])) {
  message("TRAIN passed. HYP-MOM-10.1 DEVELOPMENT query is now permitted.")
  development_query <- query_zone(cfg, contract, contract$development_end, "hyp_mom_10_1_development", refresh)
  development_bars <- development_query$bars
  train_bars <- development_bars[as.Date(development_bars$session_date) <= contract$train_end, , drop = FALSE]
  development <- g5_hm101_run_development(train_bars, development_bars, train$nominee, contract)
}

overall_status <- if (is.null(development)) train$overall_status else development$overall_status
paths <- list(
  run_spec = file.path(output_dir, "hm101_run_spec.csv"), contract = file.path(output_dir, "hm101_frozen_contract.csv"), universe = file.path(output_dir, "hm101_frozen_universe.csv"), source = file.path(output_dir, "hm101_source_audit.csv"), coverage = file.path(output_dir, "hm101_train_coverage.csv"), integrity = file.path(output_dir, "hm101_train_integrity.csv"), surface = file.path(output_dir, "hm101_train_surface.csv"), shift = file.path(output_dir, "hm101_train_shift_maxima.csv"), decision = file.path(output_dir, "hm101_train_decision.csv"), nominee = file.path(output_dir, "hm101_train_nominee.csv"), random = file.path(output_dir, "hm101_train_randomized_rank.csv"), sleeves = file.path(output_dir, "hm101_train_leave_one_sleeve_out.csv"), overlap = file.path(output_dir, "hm101_train_overlap.csv"), development_models = file.path(output_dir, "hm101_development_models.csv"), development_bootstrap = file.path(output_dir, "hm101_development_bootstrap.csv"), development_sleeves = file.path(output_dir, "hm101_development_leave_one_sleeve_out.csv"), development_gates = file.path(output_dir, "hm101_development_gates.csv"), surface_png = file.path(visual_dir, "hm101_train_surface.png"), shift_png = file.path(visual_dir, "hm101_train_search_control.png"), random_png = file.path(visual_dir, "hm101_train_randomized_rank.png"), overlap_png = file.path(visual_dir, "hm101_train_overlap.png"), tapes_png = file.path(visual_dir, "hm101_train_ranking_tapes.png"), report = file.path(output_dir, "hm101_report.md")
)
run_spec <- data.frame(schema_version = g5_hm101_schema_version(), wrapper = "scripts/inspect/run_hyp_mom_10_1_qqq_adjacent_etf_cross_sectional_momentum.R", run_id = run_id, as_of_timestamp = contract$as_of_timestamp, feed = cfg$feed, refresh = refresh, train_health_max_severity = health_severity(train_query$health), train_health_window_impact = "NONE_REQUESTED_RANGE_FULLY_COVERED", train_anchor_dates = length(train$panel$anchor_date), train_surface_passed = train$decision$passed[[1L]], development_opened = !is.null(development), confirmation_opened = FALSE, strategy_outcomes_computed = FALSE, overall_status = overall_status, output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE), stringsAsFactors = FALSE)

write_csv(run_spec, paths$run_spec); write_csv(contract_table(contract), paths$contract); write_csv(contract$universe, paths$universe); write_csv(source_checks, paths$source); write_csv(train_coverage, paths$coverage); write_csv(train$panel$integrity, paths$integrity); write_csv(train$surface, paths$surface); write_csv(train$shift_distribution, paths$shift); write_csv(train$decision, paths$decision); write_csv(if (nrow(train$nominee)) train$nominee else data.frame(status = "NO_NOMINEE"), paths$nominee); write_csv(train$randomized_rank, paths$random); write_csv(train$sleeve_diagnostic, paths$sleeves); write_csv(train$overlap, paths$overlap)
plot_surface(train$surface, paths$surface_png, contract); plot_shift(train$shift_distribution, train$decision, paths$shift_png); plot_random(train$randomized_rank, paths$random_png); plot_overlap(train$overlap, paths$overlap_png, train$panel$symbols); plot_tapes(train$panel, train$best, paths$tapes_png, contract)

if (is.null(development)) {
  writeLines("DEVELOPMENT was not queried or calculated because the frozen TRAIN gate failed.", file.path(output_dir, "DEVELOPMENT_NOT_READ.txt"))
} else {
  write_csv(development$models, paths$development_models); write_csv(development$bootstrap, paths$development_bootstrap); write_csv(development$sleeve_diagnostic, paths$development_sleeves); write_csv(development$gates, paths$development_gates)
}
writeLines("2024-2025 confirmation was not queried or calculated in this slice.", file.path(output_dir, "CONFIRMATION_NOT_READ.txt"))
writeLines(overall_status, file.path(output_dir, "STATUS.txt"))
write_report(train, development, train_coverage, source_checks, run_spec, paths)
invisible(g5_write_workbench_query_artifacts(train_query, output_dir, "hm101_train_query"))
if (!is.null(development_query)) invisible(g5_write_workbench_query_artifacts(development_query, output_dir, "hm101_development_query"))

message("HYP-MOM-10.1 complete: ", overall_status)
message("TRAIN data health: ", run_spec$train_health_max_severity)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report, winslash = "/", mustWork = FALSE))
