# Run frozen HYP-MR-01.2 TRAIN, then DEVELOPMENT only after a complete atlas TRAIN pass.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "scripts/inspect/run_hyp_mr_01_2_cross_asset_intraday_shock_reversal_atlas.R"
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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mr_01_1_qqq_intraday_shock_reversal.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "gen5_hyp_mr_01_2_cross_asset_intraday_shock_reversal_atlas.R"))
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
  if (!dir.exists(path)) stop("Could not create HYP-MR-01.2 output directory.", call. = FALSE)
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

query_zone <- function(cfg, contract, registry, end_date, universe_name, refresh) {
  g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = contract$query_start,
    end_date = end_date,
    as_of_timestamp = contract$as_of_timestamp,
    symbols = registry$symbol,
    universe_name = universe_name,
    universe_roles = rep("atlas_member", nrow(registry)),
    refresh = refresh,
    repo_root = repo_root
  )
}

coverage_table <- function(bars, registry, contract, requested_end) {
  do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
    symbol <- registry$symbol[[i]]
    dates <- sort(as.Date(bars$session_date[as.character(bars$symbol) == symbol]))
    data.frame(
      atlas_order = registry$atlas_order[[i]], symbol = symbol,
      category = registry$category[[i]],
      first_session = if (length(dates)) min(dates) else as.Date(NA),
      last_session = if (length(dates)) max(dates) else as.Date(NA),
      row_count = length(dates), duplicate_sessions = sum(duplicated(dates)),
      query_start_covered = length(dates) > 0L && min(dates) <= contract$query_start,
      requested_end_covered = length(dates) > 0L && max(dates) >= as.Date(requested_end),
      stringsAsFactors = FALSE
    )
  }))
}

source_audit <- function(coverage, bars, registry, contract, requested_end) {
  numeric_fields <- c("open", "high", "low", "close", "volume")
  do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
    symbol <- registry$symbol[[i]]
    x <- bars[as.character(bars$symbol) == symbol, , drop = FALSE]
    checks <- c(
      nrow(x) > 0L && identical(unique(as.character(x$symbol)), symbol),
      nrow(x) > 0L && all(x$adjusted %in% TRUE) && all(x$timeframe == "1D"),
      coverage$query_start_covered[coverage$symbol == symbol][[1L]],
      coverage$requested_end_covered[coverage$symbol == symbol][[1L]],
      nrow(x) > 0L && all(is.finite(as.matrix(x[numeric_fields]))) && all(as.matrix(x[numeric_fields]) > 0),
      nrow(x) > 0L && max(as.Date(x$session_date)) <= as.Date(requested_end),
      nrow(x) > 0L && max(as.Date(x$session_date)) < contract$confirmation_start
    )
    data.frame(
      symbol = symbol,
      check_id = c(
        "exact_symbol", "adjusted_daily_only", "query_start_covered",
        "requested_end_covered", "positive_finite_ohlcv",
        "requested_boundary_respected", "confirmation_excluded"
      ),
      passed = checks,
      observed = c(
        paste(unique(as.character(x$symbol)), collapse = ","),
        paste(unique(paste(x$adjusted, x$timeframe, sep = "/")), collapse = ","),
        as.character(coverage$first_session[coverage$symbol == symbol][[1L]]),
        as.character(coverage$last_session[coverage$symbol == symbol][[1L]]),
        if (nrow(x)) paste(range(as.matrix(x[numeric_fields])), collapse = " to ") else "none",
        if (nrow(x)) as.character(max(as.Date(x$session_date))) else "none",
        if (nrow(x)) as.character(max(as.Date(x$session_date))) else "none"
      ),
      status = ifelse(checks, "PASS", "FAIL"),
      stringsAsFactors = FALSE
    )
  }))
}

plot_asset_train <- function(asset, path) {
  x <- asset[order(asset$relative_mse_improvement), , drop = FALSE]
  grDevices::png(path, width = 1800, height = 1300, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(5, 8, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  graphics::barplot(
    100 * x$relative_mse_improvement, names.arg = x$symbol, horiz = TRUE,
    las = 1, cex.names = 0.72,
    col = ifelse(x$relative_mse_improvement > 0, "#147D8C", "#E97132"),
    xlab = "Relative OOF MSE improvement vs drift (%)",
    main = "HYP-MR-01.2 TRAIN breadth across 36 assets"
  )
  graphics::abline(v = 0, col = "#64748B", lwd = 2)
}

plot_category_train <- function(category, path) {
  x <- category[order(category$median_relative_mse_improvement), , drop = FALSE]
  grDevices::png(path, width = 1700, height = 950, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(5, 13, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  graphics::barplot(
    100 * x$median_relative_mse_improvement, names.arg = x$category,
    horiz = TRUE, las = 1,
    col = ifelse(x$median_relative_mse_improvement > 0, "#147D8C", "#E97132"),
    xlab = "Median relative OOF MSE improvement (%)",
    main = "TRAIN category breadth"
  )
  graphics::abline(v = 0, col = "#64748B", lwd = 2)
}

plot_shift <- function(aggregate, decision, path) {
  grDevices::png(path, width = 1550, height = 900, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::hist(
    100 * aggregate$median_relative_improvement, breaks = 35,
    col = "#D7E3F4", border = "white",
    xlab = "Common-shift median relative improvement (%)",
    main = "Atlas-wide timing falsification control"
  )
  graphics::abline(v = 100 * decision$median_shift_p90[[1L]], col = "#B7791F", lwd = 3, lty = 2)
  graphics::abline(v = 100 * decision$observed_median_relative_improvement[[1L]], col = "#166534", lwd = 3)
  graphics::legend("topright", c("Observed", "Common-shift p90"), col = c("#166534", "#B7791F"), lwd = 3, lty = c(1, 2), bty = "n")
}

plot_transport <- function(train_asset, development_asset, path) {
  x <- merge(
    train_asset[c("symbol", "relative_mse_improvement")],
    development_asset[c("symbol", "relative_mse_improvement")],
    by = "symbol", suffixes = c("_train", "_development")
  )
  grDevices::png(path, width = 1450, height = 1050, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(
    100 * x$relative_mse_improvement_train,
    100 * x$relative_mse_improvement_development,
    pch = 19, col = "#147D8C", cex = 1.15,
    xlab = "TRAIN relative OOF MSE improvement (%)",
    ylab = "DEVELOPMENT frozen relative MSE improvement (%)",
    main = "Asset-level transport from TRAIN to DEVELOPMENT"
  )
  graphics::abline(h = 0, v = 0, col = "#94A3B8", lwd = 2)
  qqq <- which(x$symbol == "QQQ")
  if (length(qqq)) graphics::text(
    100 * x$relative_mse_improvement_train[qqq],
    100 * x$relative_mse_improvement_development[qqq],
    labels = "QQQ", pos = 3, col = "#E97132", font = 2
  )
}

plot_category_transport <- function(train_category, development_category, path) {
  x <- merge(
    train_category[c("category", "median_relative_mse_improvement")],
    development_category[c("category", "median_relative_mse_improvement")],
    by = "category", suffixes = c("_train", "_development")
  )
  x <- x[order(x$median_relative_mse_improvement_train), , drop = FALSE]
  values <- rbind(100 * x$median_relative_mse_improvement_train, 100 * x$median_relative_mse_improvement_development)
  grDevices::png(path, width = 1800, height = 1000, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(mar = c(12, 5, 4, 2))
  on.exit(graphics::par(old), add = TRUE)
  graphics::barplot(
    values, beside = TRUE, names.arg = x$category, las = 2,
    col = c("#147D8C", "#E97132"),
    ylab = "Median relative MSE improvement (%)",
    main = "Category transport under frozen asset models"
  )
  graphics::abline(h = 0, col = "#64748B", lwd = 2)
  graphics::legend("topright", c("TRAIN OOF", "DEVELOPMENT"), fill = c("#147D8C", "#E97132"), bty = "n")
}

plot_year_transport <- function(train_folds, development_years, path) {
  train_year <- do.call(rbind, lapply(split(train_folds, train_folds$fold_year), function(x) {
    data.frame(year = x$fold_year[[1L]], zone = "TRAIN OOF", median = stats::median(x$relative_mse_improvement))
  }))
  development_year <- data.frame(
    year = development_years$target_year, zone = "DEVELOPMENT",
    median = development_years$median_relative_mse_improvement
  )
  x <- rbind(train_year, development_year)
  grDevices::png(path, width = 1500, height = 850, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::barplot(
    100 * x$median, names.arg = paste0(ifelse(x$zone == "TRAIN OOF", "T", "D"), x$year),
    col = ifelse(x$median > 0, "#147D8C", "#E97132"),
    ylab = "Cross-asset median relative MSE improvement (%)",
    main = "Calendar transport of the atlas"
  )
  graphics::abline(h = 0, col = "#64748B", lwd = 2)
}

write_report <- function(train, development, registry, coverage, source_checks, run_spec, paths) {
  a <- train$atlas_summary[1L, ]
  s <- train$shift_decision[1L, ]
  qqq <- train$asset_summary[train$asset_summary$symbol == "QQQ", , drop = FALSE]
  lines <- c(
    "# HYP-MR-01.2 Cross-Asset Intraday-Shock Reversal Atlas Results", "",
    paste0("Status: `", run_spec$overall_status[[1L]], "`"), "",
    "## Question", "",
    "Does the unchanged QQQ intraday-shock reversal predictor appear broadly across a fixed, diverse 36-asset atlas, and does that breadth transport?", "",
    "## Frozen atlas", "",
    paste0("- Assets: `", nrow(registry), "`; categories: `", length(unique(registry$category)), "`; four assets per category."),
    "- Selection: first four pre-existing registry rows in each category; no HYP-MR outcome selected an asset.",
    "- Same predictor, next-session target, per-asset OLS, drift benchmark, expanding folds, and 1% influence audit as HYP-MR-01.1.",
    "- Cross-asset comparison uses relative MSE improvement; a common circular shift preserves contemporaneous dependence.", "",
    "## Source and construction", "",
    paste0("- Source gates: `", sum(source_checks$passed), " / ", nrow(source_checks), "` pass."),
    paste0("- Common TRAIN anchors per asset: `", a$common_anchor_count, "`."),
    paste0("- Data-health maximum severity: `", run_spec$train_health_max_severity[[1L]], "`; requested-window impact: `", run_spec$train_health_window_impact[[1L]], "`."), "",
    "## TRAIN breadth", "",
    paste0("- Median beta: `", sprintf("%.8f", a$median_beta), "`; negative assets: `", sum(train$asset_summary$beta < 0), " / ", nrow(train$asset_summary), "`."),
    paste0("- Median Spearman: `", sprintf("%.6f", a$median_spearman), "`; negative assets: `", sum(train$asset_summary$spearman < 0), " / ", nrow(train$asset_summary), "`."),
    paste0("- Median relative OOF MSE improvement: `", sprintf("%.6f", a$median_relative_mse_improvement), "`; positive assets: `", sum(train$asset_summary$relative_mse_improvement > 0), " / ", nrow(train$asset_summary), "`."),
    paste0("- Common-shift p90: `", sprintf("%.6f", s$median_shift_p90), "`; upper-tail probability: `", sprintf("%.6f", s$median_upper_tail_probability), "`."),
    paste0("- QQQ relative OOF improvement: `", sprintf("%.6f", qqq$relative_mse_improvement), "`; atlas percentile: `", sprintf("%.1f", 100 * stats::ecdf(train$asset_summary$relative_mse_improvement)(qqq$relative_mse_improvement)), "`."),
    paste0("- TRAIN gates: `", sum(train$gates$passed), " / ", nrow(train$gates), "` pass."), ""
  )
  if (is.null(development)) {
    lines <- c(lines, "## DEVELOPMENT boundary", "", "DEVELOPMENT was not queried because at least one atlas-wide TRAIN gate failed.", "")
  } else {
    d <- development$atlas_summary[1L, ]
    dev_qqq <- development$asset_summary[development$asset_summary$symbol == "QQQ", , drop = FALSE]
    lines <- c(
      lines, "## DEVELOPMENT transport", "",
      paste0("- Common rows per asset: `", d$common_row_count, "`."),
      paste0("- Median Spearman: `", sprintf("%.6f", d$median_spearman), "`; negative assets: `", sum(development$asset_summary$spearman < 0), " / ", nrow(development$asset_summary), "`."),
      paste0("- Median relative MSE improvement: `", sprintf("%.6f", d$median_relative_mse_improvement), "`; positive assets: `", sum(development$asset_summary$relative_mse_improvement > 0), " / ", nrow(development$asset_summary), "`."),
      paste0("- Positive category medians: `", d$positive_category_count, " / 9`; positive calendar years: `", d$positive_year_count, " / 3`."),
      paste0("- Category-bootstrap P(median improvement > 0): `", sprintf("%.6f", d$bootstrap_probability_positive), "`."),
      paste0("- QQQ DEVELOPMENT relative improvement: `", sprintf("%.6f", dev_qqq$relative_mse_improvement), "`."),
      paste0("- DEVELOPMENT gates: `", sum(development$gates$passed), " / ", nrow(development$gates), "` pass."), ""
    )
  }
  lines <- c(
    lines, "## Interpretation", "",
    if (is.null(development)) {
      "The QQQ TRAIN pass did not broaden enough to earn a later atlas read. Stop without selecting favorable assets or categories."
    } else if (all(development$gates$passed)) {
      "The unchanged relationship was broad in TRAIN and transported across assets and categories. Confirmation remains sealed pending operator review."
    } else {
      "The atlas earned DEVELOPMENT but failed at least one breadth or transport gate. Preserve the breadth evidence without converting favorable assets into a selected strategy universe."
    }, "",
    "This is predictor evidence only. No strategy or performance surface was calculated.", "",
    "## Visual artifacts", "",
    paste0("- Asset TRAIN breadth: `", basename(paths$asset_train_png), "`"),
    paste0("- Category TRAIN breadth: `", basename(paths$category_train_png), "`"),
    paste0("- Common timing control: `", basename(paths$shift_png), "`"),
    if (!is.null(development)) paste0("- Asset transport: `", basename(paths$transport_png), "`") else NULL,
    if (!is.null(development)) paste0("- Category transport: `", basename(paths$category_transport_png), "`") else NULL,
    if (!is.null(development)) paste0("- Calendar transport: `", basename(paths$year_transport_png), "`") else NULL
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("HYP-MR-01.2 frozen atlas TRAIN stage starting.")
contract <- g5_hmr012_contract()
registry_path <- file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mr_01_2_cross_asset_atlas_registry.csv")
registry <- g5_hmr012_validate_registry(utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE), contract)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_HYP_MR_01_2_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_HYP_MR_01_2_REFRESH", FALSE)
run_id <- env_or("GEN5_HYP_MR_01_2_RUN_ID", "hyp_mr_01_2_cross_asset_intraday_shock_reversal_atlas_20260823")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

train_query <- query_zone(cfg, contract, registry, contract$train_end, "hyp_mr_01_2_train", refresh)
train_coverage <- coverage_table(train_query$bars, registry, contract, contract$train_end)
train_source <- source_audit(train_coverage, train_query$bars, registry, contract, contract$train_end)
if (!all(train_source$passed)) {
  failed <- unique(train_source$symbol[!train_source$passed])
  stop(paste("HYP-MR-01.2 TRAIN source feasibility failed; refresh required for:", paste(failed, collapse = ",")), call. = FALSE)
}
train_bundle <- g5_hmr012_prepare_atlas_panels(
  train_query$bars, registry, contract$train_start, contract$train_end,
  contract$minimum_train_anchors, contract$train_end, contract
)
train <- g5_hmr012_run_train_panels(train_bundle$panels, registry, contract)

development <- NULL
development_query <- NULL
development_bundle <- NULL
train_replay_bundle <- NULL
parity <- NULL
if (isTRUE(train$atlas_summary$train_passed[[1L]])) {
  message("Atlas TRAIN passed. HYP-MR-01.2 DEVELOPMENT query is now permitted.")
  development_query <- query_zone(cfg, contract, registry, contract$development_end, "hyp_mr_01_2_development", refresh)
  development_coverage <- coverage_table(development_query$bars, registry, contract, contract$development_end)
  development_source <- source_audit(development_coverage, development_query$bars, registry, contract, contract$development_end)
  if (!all(development_source$passed)) {
    failed <- unique(development_source$symbol[!development_source$passed])
    stop(paste("HYP-MR-01.2 DEVELOPMENT source feasibility failed; refresh required for:", paste(failed, collapse = ",")), call. = FALSE)
  }
  train_replay_bars <- development_query$bars[as.Date(development_query$bars$session_date) <= contract$train_end, , drop = FALSE]
  train_replay_bundle <- g5_hmr012_prepare_atlas_panels(
    train_replay_bars, registry, contract$train_start, contract$train_end,
    contract$minimum_train_anchors, contract$train_end, contract
  )
  development_bundle <- g5_hmr012_prepare_atlas_panels(
    development_query$bars, registry, contract$development_start, contract$development_end,
    contract$minimum_development_anchors, contract$development_end, contract
  )
  parity <- do.call(rbind, lapply(registry$symbol, function(symbol) {
    first <- train_bundle$panels[[symbol]]
    replay <- train_replay_bundle$panels[[symbol]]
    data.frame(
      symbol = symbol,
      rows_equal = nrow(first) == nrow(replay),
      dates_equal = identical(first[c("anchor_date", "target_date")], replay[c("anchor_date", "target_date")]),
      max_abs_x_difference = if (nrow(first) == nrow(replay)) max(abs(first$x - replay$x)) else Inf,
      max_abs_y_difference = if (nrow(first) == nrow(replay)) max(abs(first$y - replay$y)) else Inf,
      stringsAsFactors = FALSE
    )
  }))
  if (!all(parity$rows_equal & parity$dates_equal & parity$max_abs_x_difference == 0 & parity$max_abs_y_difference == 0)) {
    stop("HYP-MR-01.2 TRAIN replay parity failed.", call. = FALSE)
  }
  development <- g5_hmr012_run_development_panels(
    train_replay_bundle$panels, development_bundle$panels, registry, contract
  )
}

overall_status <- if (is.null(development)) train$overall_status else development$overall_status
paths <- list(
  run_spec = file.path(output_dir, "hmr012_run_spec.csv"),
  contract = file.path(output_dir, "hmr012_frozen_contract.csv"),
  registry = file.path(output_dir, "hmr012_frozen_registry.csv"),
  coverage = file.path(output_dir, "hmr012_train_coverage.csv"),
  source = file.path(output_dir, "hmr012_train_source_audit.csv"),
  integrity = file.path(output_dir, "hmr012_train_integrity.csv"),
  construction = file.path(output_dir, "hmr012_train_construction.csv"),
  alignment = file.path(output_dir, "hmr012_train_common_calendar.csv"),
  asset_train = file.path(output_dir, "hmr012_train_asset_summary.csv"),
  folds = file.path(output_dir, "hmr012_train_fold_summary.csv"),
  predictions = file.path(output_dir, "hmr012_train_expanding_predictions.csv"),
  category_train = file.path(output_dir, "hmr012_train_category_summary.csv"),
  shift_long = file.path(output_dir, "hmr012_train_common_shift_asset_results.csv"),
  shift_aggregate = file.path(output_dir, "hmr012_train_common_shift_atlas_results.csv"),
  asset_shift = file.path(output_dir, "hmr012_train_asset_shift_summary.csv"),
  shift_decision = file.path(output_dir, "hmr012_train_shift_decision.csv"),
  gates = file.path(output_dir, "hmr012_train_gates.csv"),
  atlas_train = file.path(output_dir, "hmr012_train_atlas_summary.csv"),
  development_coverage = file.path(output_dir, "hmr012_development_coverage.csv"),
  development_source = file.path(output_dir, "hmr012_development_source_audit.csv"),
  development_alignment = file.path(output_dir, "hmr012_development_common_calendar.csv"),
  train_parity = file.path(output_dir, "hmr012_train_replay_parity.csv"),
  development_asset = file.path(output_dir, "hmr012_development_asset_summary.csv"),
  development_asset_year = file.path(output_dir, "hmr012_development_asset_year_summary.csv"),
  development_category = file.path(output_dir, "hmr012_development_category_summary.csv"),
  development_year = file.path(output_dir, "hmr012_development_year_summary.csv"),
  development_bootstrap = file.path(output_dir, "hmr012_development_category_bootstrap.csv"),
  development_gates = file.path(output_dir, "hmr012_development_gates.csv"),
  development_atlas = file.path(output_dir, "hmr012_development_atlas_summary.csv"),
  asset_train_png = file.path(visual_dir, "hmr012_train_asset_breadth.png"),
  category_train_png = file.path(visual_dir, "hmr012_train_category_breadth.png"),
  shift_png = file.path(visual_dir, "hmr012_train_common_timing_control.png"),
  transport_png = file.path(visual_dir, "hmr012_asset_transport.png"),
  category_transport_png = file.path(visual_dir, "hmr012_category_transport.png"),
  year_transport_png = file.path(visual_dir, "hmr012_calendar_transport.png"),
  report = file.path(output_dir, "hmr012_report.md")
)

run_spec <- data.frame(
  schema_version = g5_hmr012_schema_version(),
  wrapper = "scripts/inspect/run_hyp_mr_01_2_cross_asset_intraday_shock_reversal_atlas.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  asset_count = nrow(registry), category_count = length(unique(registry$category)),
  train_health_max_severity = health_severity(train_query$health),
  train_health_window_impact = "NONE_REQUESTED_RANGE_FULLY_COVERED",
  train_common_anchor_count = train$atlas_summary$common_anchor_count[[1L]],
  train_passed = train$atlas_summary$train_passed[[1L]],
  development_opened = !is.null(development),
  confirmation_opened = FALSE,
  strategy_outcomes_computed = FALSE,
  overall_status = overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$contract)
write_csv(registry, paths$registry)
write_csv(train_coverage, paths$coverage)
write_csv(train_source, paths$source)
write_csv(train_bundle$integrity, paths$integrity)
write_csv(train_bundle$construction, paths$construction)
write_csv(train_bundle$alignment, paths$alignment)
write_csv(train$asset_summary, paths$asset_train)
write_csv(train$folds, paths$folds)
write_csv(train$predictions, paths$predictions)
write_csv(train$category_summary, paths$category_train)
write_csv(train$shift_long, paths$shift_long)
write_csv(train$shift_aggregate, paths$shift_aggregate)
write_csv(train$asset_shift_summary, paths$asset_shift)
write_csv(train$shift_decision, paths$shift_decision)
write_csv(train$gates, paths$gates)
write_csv(train$atlas_summary, paths$atlas_train)
plot_asset_train(train$asset_summary, paths$asset_train_png)
plot_category_train(train$category_summary, paths$category_train_png)
plot_shift(train$shift_aggregate, train$shift_decision, paths$shift_png)

if (is.null(development)) {
  writeLines("DEVELOPMENT was not queried because at least one frozen atlas TRAIN gate failed.", file.path(output_dir, "DEVELOPMENT_NOT_READ.txt"))
} else {
  write_csv(development_coverage, paths$development_coverage)
  write_csv(development_source, paths$development_source)
  write_csv(development_bundle$alignment, paths$development_alignment)
  write_csv(parity, paths$train_parity)
  write_csv(development$asset_summary, paths$development_asset)
  write_csv(development$asset_years, paths$development_asset_year)
  write_csv(development$category_summary, paths$development_category)
  write_csv(development$year_summary, paths$development_year)
  write_csv(development$bootstrap, paths$development_bootstrap)
  write_csv(development$gates, paths$development_gates)
  write_csv(development$atlas_summary, paths$development_atlas)
  plot_transport(train$asset_summary, development$asset_summary, paths$transport_png)
  plot_category_transport(train$category_summary, development$category_summary, paths$category_transport_png)
  plot_year_transport(train$folds, development$year_summary, paths$year_transport_png)
}
writeLines("2024-2025 confirmation was not queried or calculated in this slice.", file.path(output_dir, "CONFIRMATION_NOT_READ.txt"))
writeLines(overall_status, file.path(output_dir, "STATUS.txt"))
write_report(train, development, registry, train_coverage, train_source, run_spec, paths)
invisible(g5_write_workbench_query_artifacts(train_query, output_dir, "hmr012_train_query"))
if (!is.null(development_query)) invisible(g5_write_workbench_query_artifacts(development_query, output_dir, "hmr012_development_query"))

message("HYP-MR-01.2 complete: ", overall_status)
message("TRAIN data health: ", run_spec$train_health_max_severity)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(paths$report, winslash = "/", mustWork = FALSE))
