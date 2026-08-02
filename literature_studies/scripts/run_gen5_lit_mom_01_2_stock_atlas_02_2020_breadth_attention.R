# Run LIT-MOM-01.2 / STOCK_ATLAS_02_2020_BREADTH_ATTENTION.

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
  "gen5_lit_mom_01_2_single_position_poc.R"
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

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

add_identity <- function(x, reg) {
  if (is.null(x) || !nrow(x)) return(x)
  cbind(
    data.frame(
      instance_id = reg$instance_id,
      symbol = reg$symbol,
      cohort = reg$cohort,
      sector = reg$sector,
      stringsAsFactors = FALSE
    ),
    x
  )
}

metric_value <- function(metrics, regime, field) {
  value <- metrics[metrics$regime_id == regime, field]
  if (!length(value)) NA_real_ else value[[1L]]
}

direction_value <- function(audit, direction, field) {
  value <- audit[audit$direction == direction, field]
  if (!length(value)) NA_real_ else value[[1L]]
}

metric_flag <- function(metrics, regime, field) {
  value <- metrics[metrics$regime_id == regime, field]
  if (!length(value)) FALSE else isTRUE(value[[1L]])
}

coverage_audit <- function(bars, registry, contract) {
  spy_dates <- sort(unique(as.Date(bars$session_date[bars$symbol == "SPY"])))
  train_expected <- spy_dates[
    spy_dates >= contract$train_start & spy_dates <= contract$train_end
  ]
  retro_expected <- spy_dates[
    spy_dates >= contract$retrospective_start &
      spy_dates <= contract$retrospective_end
  ]
  if (!length(train_expected) || !length(retro_expected)) {
    stop("SPY reference sessions are unavailable.", call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    reg <- registry[i, , drop = FALSE]
    observed <- sort(unique(as.Date(
      bars$session_date[bars$symbol == reg$symbol]
    )))
    train_observed <- observed[
      observed >= contract$train_start & observed <= contract$train_end
    ]
    retro_observed <- observed[
      observed >= contract$retrospective_start &
        observed <= contract$retrospective_end
    ]
    train_missing <- setdiff(train_expected, train_observed)
    retro_missing <- setdiff(retro_expected, retro_observed)
    train_exact <- identical(train_observed, train_expected)
    retro_exact <- identical(retro_observed, retro_expected)
    reason <- if (!length(observed)) {
      "NO_BARS"
    } else if (!train_exact && !retro_exact) {
      "TRAIN_AND_RETROSPECTIVE_INCOMPLETE"
    } else if (!train_exact) {
      "TRAIN_INCOMPLETE"
    } else if (!retro_exact) {
      "RETROSPECTIVE_INCOMPLETE"
    } else {
      "ELIGIBLE"
    }
    data.frame(
      instance_id = reg$instance_id,
      symbol = reg$symbol,
      cohort = reg$cohort,
      sector = reg$sector,
      first_observed = if (length(observed)) as.character(min(observed)) else NA_character_,
      last_observed = if (length(observed)) as.character(max(observed)) else NA_character_,
      train_observed_sessions = length(train_observed),
      train_expected_sessions = length(train_expected),
      train_missing_sessions = length(train_missing),
      retrospective_observed_sessions = length(retro_observed),
      retrospective_expected_sessions = length(retro_expected),
      retrospective_missing_sessions = length(retro_missing),
      train_exact = train_exact,
      retrospective_exact = retro_exact,
      analysis_eligible = train_exact && retro_exact,
      coverage_status = reason,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

plot_registry <- function(registry, path) {
  png(path, width = 2100, height = 1200, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(7, 12, 5, 2))
  cohort_counts <- table(registry$cohort)
  barplot(cohort_counts, col = c("#2563EB", "#F59E0B"), border = NA,
          las = 2, ylab = "Frozen stocks",
          main = "Two ex-ante universe lanes")
  core <- registry[registry$cohort == "DIVERSIFIED_CORE", , drop = FALSE]
  sector_counts <- sort(table(core$sector))
  barplot(sector_counts, horiz = TRUE, las = 1, col = "#3D8DFF", border = NA,
          xlab = "Diversified-core stocks",
          main = "Every broad sector is represented")
  par(old)
  dev.off()
}

plot_coverage <- function(coverage, path) {
  tab <- table(coverage$cohort, coverage$analysis_eligible)
  values <- cbind(
    eligible = tab[, "TRUE", drop = TRUE],
    coverage_stop = tab[, "FALSE", drop = TRUE]
  )
  png(path, width = 1800, height = 1050, res = 150)
  old <- par(mar = c(9, 7, 5, 2))
  barplot(t(values), beside = FALSE, names.arg = rownames(values),
          col = c("#177245", "#B42318"), border = NA, las = 2,
          ylab = "Registry rows", main = "Coverage failures remain visible")
  legend("topright", c("Eligible", "Coverage STOP"),
         fill = c("#177245", "#B42318"), bty = "n")
  par(old)
  dev.off()
}

plot_horizon_heatmap <- function(summary, grid, path) {
  png(path, width = 2100, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(7, 7, 5, 2))
  for (cohort in c("DIVERSIFIED_CORE", "RETAIL_ATTENTION_2020")) {
    x <- summary[summary$cohort == cohort, , drop = FALSE]
    counts <- matrix(0L, length(grid), length(grid))
    for (i in seq_len(nrow(x))) {
      counts[match(x$holding_sessions[[i]], grid),
             match(x$lookback_sessions[[i]], grid)] <-
        counts[match(x$holding_sessions[[i]], grid),
               match(x$lookback_sessions[[i]], grid)] + 1L
    }
    image(seq_along(grid), seq_along(grid), t(counts), axes = FALSE,
          col = grDevices::colorRampPalette(c("#F8FAFC", "#93C5FD", "#1D4ED8"))(12),
          xlab = "Lookback L", ylab = "Holding H",
          main = gsub("_", " ", cohort))
    axis(1, seq_along(grid), grid)
    axis(2, seq_along(grid), grid, las = 1)
    for (r in seq_along(grid)) for (c in seq_along(grid)) {
      if (counts[r, c] > 0L) text(c, r, counts[r, c], font = 2)
    }
  }
  par(old)
  dev.off()
}

plot_return_distribution <- function(summary, path) {
  cohort_x <- ifelse(summary$cohort == "DIVERSIFIED_CORE", 1, 2)
  colors <- ifelse(cohort_x == 1, "#2563EB", "#F59E0B")
  png(path, width = 1900, height = 1150, res = 150)
  old <- par(mar = c(7, 7, 5, 2))
  plot(jitter(cohort_x, amount = 0.12), 100 * summary$retrospective_primary_return,
       pch = 19, col = colors, xaxt = "n", xlim = c(0.5, 2.5),
       xlab = "Frozen cohort", ylab = "2021-2023 primary cumulative return (%)",
       main = "Every eligible asset uses its own TRAIN-selected horizon")
  axis(1, 1:2, c("Diversified core", "Retail attention"))
  abline(h = 0, lty = 2, col = "#0F172A")
  med <- tapply(summary$retrospective_primary_return, summary$cohort, median)
  segments(c(0.72, 1.72), 100 * med[c("DIVERSIFIED_CORE", "RETAIL_ATTENTION_2020")],
           c(1.28, 2.28), 100 * med[c("DIVERSIFIED_CORE", "RETAIL_ATTENTION_2020")],
           lwd = 4, col = "#0F172A")
  par(old)
  dev.off()
}

plot_continuity <- function(summary, path) {
  colors <- ifelse(summary$cohort == "DIVERSIFIED_CORE", "#2563EB", "#F59E0B")
  png(path, width = 1900, height = 1000, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(6, 6, 5, 2))
  plot(summary$train_return_correlation,
       summary$retrospective_return_correlation,
       pch = 19, col = colors, xlab = "TRAIN selected-row correlation",
       ylab = "Retrospective correlation",
       main = "Correlation continuity")
  abline(h = 0, v = 0, lty = 2, col = "#64748B")
  plot(100 * summary$train_long_accuracy,
       100 * summary$retrospective_long_accuracy,
       pch = 19, col = colors, xlim = c(0, 100), ylim = c(0, 100),
       xlab = "TRAIN long-call accuracy (%)",
       ylab = "Retrospective long-call accuracy (%)",
       main = "Only positive calls are traded")
  abline(h = 50, v = 50, lty = 2, col = "#64748B")
  legend("bottomleft", c("Diversified core", "Retail attention"),
         pch = 19, col = c("#2563EB", "#F59E0B"), bty = "n")
  par(old)
  dev.off()
}

plot_equity_pages <- function(replay, summary, visual_dir) {
  primary <- replay[replay$regime_id == "PRIMARY", , drop = FALSE]
  symbols <- summary$symbol
  groups <- split(symbols, ceiling(seq_along(symbols) / 25))
  paths <- character(length(groups))
  for (page in seq_along(groups)) {
    path <- file.path(visual_dir, sprintf("stock_atlas_02_primary_equity_page_%02d.png", page))
    paths[[page]] <- path
    png(path, width = 2200, height = 2200, res = 150)
    old <- par(mfrow = c(5, 5), mar = c(2.1, 2.3, 2.4, 0.8))
    for (symbol in groups[[page]]) {
      x <- primary[primary$symbol == symbol, , drop = FALSE]
      row <- summary[summary$symbol == symbol, , drop = FALSE]
      plot(x$outcome_date, x$wealth, type = "l", col = ifelse(
        row$cohort == "DIVERSIFIED_CORE", "#2563EB", "#F59E0B"
      ), lwd = 1.4, xlab = "", ylab = "", xaxt = "n",
      main = sprintf("%s %+.1f%%", symbol,
                     100 * row$retrospective_primary_return), cex.main = 0.8)
      axis.Date(1, at = as.Date(c("2021-01-04", "2022-01-03", "2023-01-03")),
                labels = c("21", "22", "23"), cex.axis = 0.6)
      abline(h = 1, lty = 2, col = "#94A3B8")
    }
    if (length(groups[[page]]) < 25L) {
      for (i in seq_len(25L - length(groups[[page]]))) plot.new()
    }
    par(old)
    dev.off()
  }
  paths
}

message("LIT-MOM-01.2 Stock Atlas 02 starting.")
contract <- g5_mom012_contract()
registry_path <- file.path(
  repo_root, "literature_studies", "registries",
  "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"
)
prior_path <- file.path(
  repo_root, "literature_studies", "registries",
  "gen5_lit_mom_01_1_stock_atlas_01_registry.csv"
)
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
prior <- utils::read.csv(prior_path, stringsAsFactors = FALSE)
registry_validation <- g5_mom012_validate_atlas02_registry(registry, prior$symbol)
registry <- registry_validation$registry

run_id <- env_or(
  "GEN5_LIT_MOM_012_ATLAS02_RUN_ID",
  "lit_mom_01_2_long_only_stock_atlas_02_2020_breadth_attention_20260802"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_012_ATLAS02_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_012_ATLAS02_REFRESH", TRUE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$retrospective_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = c(registry$symbol, "SPY"),
  universe_name = "lit_mom_01_2_stock_atlas_02_and_spy_reference",
  universe_roles = "frozen_2020_breadth_attention,spy_session_reference",
  refresh = refresh,
  repo_root = repo_root
)
bars_all <- query$bars
bars_all$session_date <- as.Date(bars_all$session_date)
if (any(bars_all$session_date >= contract$confirmation_start)) {
  stop("Confirmation bars entered Stock Atlas 02.", call. = FALSE)
}
coverage <- coverage_audit(bars_all, registry, contract)
eligible <- registry[registry$symbol %in% coverage$symbol[coverage$analysis_eligible], , drop = FALSE]
if (!nrow(eligible)) stop("No Stock Atlas 02 symbols passed coverage.", call. = FALSE)

horizon_rows <- selected_rows <- inference_rows <- phase_rows <- list()
train_metric_rows <- retro_metric_rows <- retro_direction_rows <- list()
trade_rows <- replay_rows <- integrity_rows <- summary_rows <- list()

for (i in seq_len(nrow(eligible))) {
  reg <- eligible[i, , drop = FALSE]
  symbol <- reg$symbol[[1L]]
  message(sprintf("[%03d/%03d] %s", i, nrow(eligible), symbol))
  asset_contract <- g5_mom012_replication_contract(
    symbol, "STOCK_ATLAS_02_2020_BREADTH_ATTENTION"
  )
  parent_contract <- g5_mom012_parent_contract(asset_contract)
  bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  bars <- bars[order(bars$session_date), , drop = FALSE]
  screen <- g5_mom01_horizon_screen(
    bars, contract$train_start, contract$train_end, parent_contract
  )
  selected <- g5_mom012_select_horizon(screen, asset_contract)
  train <- g5_mom012_analyze_period(
    bars, contract$train_start, contract$train_end, "TRAIN",
    selected$lookback_sessions, selected$holding_sessions, asset_contract
  )
  retro <- g5_mom012_analyze_period(
    bars, contract$retrospective_start, contract$retrospective_end,
    "RETROSPECTIVE_2021_2023", selected$lookback_sessions,
    selected$holding_sessions, asset_contract
  )
  integrity <- g5_mom012_integrity_audit(
    bars, selected, train, retro, asset_contract
  )
  horizon_rows[[i]] <- add_identity(screen, reg)
  selected_rows[[i]] <- add_identity(selected, reg)
  inference_rows[[length(inference_rows) + 1L]] <- add_identity(
    transform(train$inference$summary, period_id = "TRAIN"), reg
  )
  inference_rows[[length(inference_rows) + 1L]] <- add_identity(
    transform(retro$inference$summary, period_id = "RETROSPECTIVE_2021_2023"), reg
  )
  phase_rows[[i]] <- add_identity(train$inference$step_l_phase_offsets, reg)
  train_metric_rows[[i]] <- add_identity(train$metrics, reg)
  retro_metric_rows[[i]] <- add_identity(retro$metrics, reg)
  retro_direction_rows[[i]] <- add_identity(retro$direction_audit, reg)
  trade_rows[[i]] <- add_identity(retro$trade_results, reg)
  replay_rows[[i]] <- add_identity(retro$replay, reg)
  integrity_rows[[i]] <- add_identity(integrity, reg)
  retro_primary_inference <- retro$inference$summary[
    retro$inference$summary$sampling_id == "CHAN_MIN_STEP", , drop = FALSE
  ]
  summary_rows[[i]] <- data.frame(
    instance_id = reg$instance_id,
    symbol = symbol,
    cohort = reg$cohort,
    sector = reg$sector,
    lookback_sessions = selected$lookback_sessions,
    holding_sessions = selected$holding_sessions,
    train_pair_count = selected$pair_count,
    train_return_correlation = selected$return_correlation,
    train_direction_accuracy = selected$direction_accuracy,
    retrospective_return_correlation = retro_primary_inference$return_correlation,
    retrospective_direction_accuracy = retro_primary_inference$direction_accuracy,
    retrospective_gross_return = metric_value(retro$metrics, "GROSS", "cumulative_return"),
    retrospective_primary_return = metric_value(retro$metrics, "PRIMARY", "cumulative_return"),
    retrospective_stress_return = metric_value(retro$metrics, "STRESS", "cumulative_return"),
    retrospective_primary_maximum_drawdown = metric_value(retro$metrics, "PRIMARY", "maximum_drawdown"),
    retrospective_trade_count = metric_value(retro$metrics, "PRIMARY", "trade_count"),
    train_long_accuracy = direction_value(train$direction_audit, "LONG", "direction_accuracy"),
    retrospective_long_accuracy = direction_value(retro$direction_audit, "LONG", "direction_accuracy"),
    train_primary_bankruptcy = metric_flag(train$metrics, "PRIMARY", "bankruptcy_occurred"),
    retrospective_primary_bankruptcy = metric_flag(retro$metrics, "PRIMARY", "bankruptcy_occurred"),
    integrity_passed = all(integrity$passed),
    stringsAsFactors = FALSE
  )
}

horizon_screen <- do.call(rbind, horizon_rows)
selected <- do.call(rbind, selected_rows)
inference <- do.call(rbind, inference_rows)
phase_offsets <- do.call(rbind, phase_rows)
train_metrics <- do.call(rbind, train_metric_rows)
retro_metrics <- do.call(rbind, retro_metric_rows)
retro_direction <- do.call(rbind, retro_direction_rows)
trades <- do.call(rbind, trade_rows)
replay <- do.call(rbind, replay_rows)
integrity <- do.call(rbind, integrity_rows)
summary <- do.call(rbind, summary_rows)

cohort_summary <- do.call(rbind, lapply(split(summary, summary$cohort), function(x) {
  data.frame(
    cohort = x$cohort[[1L]],
    eligible_assets = nrow(x),
    positive_primary = sum(x$retrospective_primary_return > 0),
    positive_stress = sum(x$retrospective_stress_return > 0),
    median_primary_return = median(x$retrospective_primary_return),
    mean_primary_return = mean(x$retrospective_primary_return),
    positive_train_correlation = sum(x$train_return_correlation > 0),
    positive_retrospective_correlation = sum(x$retrospective_return_correlation > 0),
    train_primary_bankruptcies = sum(x$train_primary_bankruptcy),
    retrospective_primary_bankruptcies = sum(x$retrospective_primary_bankruptcy),
    stringsAsFactors = FALSE
  )
}))

batch <- data.frame(
  literature_id = "LIT-MOM-01.2",
  instance_id = "STOCK_ATLAS_02_2020_BREADTH_ATTENTION",
  position_scope = contract$position_scope,
  registry_assets = nrow(registry),
  coverage_eligible_assets = nrow(summary),
  coverage_stops = nrow(registry) - nrow(summary),
  total_train_horizon_cells = nrow(horizon_screen),
  assets_positive_primary = sum(summary$retrospective_primary_return > 0),
  assets_positive_stress = sum(summary$retrospective_stress_return > 0),
  train_primary_bankruptcies = sum(summary$train_primary_bankruptcy),
  retrospective_primary_bankruptcies = sum(summary$retrospective_primary_bankruptcy),
  median_primary_return = median(summary$retrospective_primary_return),
  mean_primary_return = mean(summary$retrospective_primary_return),
  worst_primary_drawdown = min(summary$retrospective_primary_maximum_drawdown),
  integrity_passed = all(summary$integrity_passed),
  confirmation_excluded = max(bars_all$session_date) < contract$confirmation_start,
  overall_status = "RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_02",
  stringsAsFactors = FALSE
)

write_csv(registry, file.path(output_dir, "stock_atlas_02_registry.csv"))
write_csv(registry_validation$checks, file.path(output_dir, "stock_atlas_02_registry_checks.csv"))
write_csv(coverage, file.path(output_dir, "stock_atlas_02_coverage.csv"))
write_csv(batch, file.path(output_dir, "stock_atlas_02_batch_summary.csv"))
write_csv(cohort_summary, file.path(output_dir, "stock_atlas_02_cohort_summary.csv"))
write_csv(horizon_screen, file.path(output_dir, "stock_atlas_02_train_horizon_screen.csv"))
write_csv(selected, file.path(output_dir, "stock_atlas_02_selected_horizons.csv"))
write_csv(inference, file.path(output_dir, "stock_atlas_02_selected_inference_views.csv"))
write_csv(phase_offsets, file.path(output_dir, "stock_atlas_02_train_step_l_phase_offsets.csv"))
write_csv(train_metrics, file.path(output_dir, "stock_atlas_02_train_metrics.csv"))
write_csv(retro_metrics, file.path(output_dir, "stock_atlas_02_retrospective_metrics.csv"))
write_csv(retro_direction, file.path(output_dir, "stock_atlas_02_retrospective_direction_audit.csv"))
write_csv(trades, file.path(output_dir, "stock_atlas_02_retrospective_trades.csv"))
write_csv(replay, file.path(output_dir, "stock_atlas_02_retrospective_bar_replay.csv"))
write_csv(integrity, file.path(output_dir, "stock_atlas_02_integrity_audit.csv"))
write_csv(summary, file.path(output_dir, "stock_atlas_02_summary.csv"))
write_csv(query$health, file.path(output_dir, "stock_atlas_02_query_health.csv"))

plot_registry(registry, file.path(visual_dir, "stock_atlas_02_registry_design.png"))
plot_coverage(coverage, file.path(visual_dir, "stock_atlas_02_coverage.png"))
plot_horizon_heatmap(summary, contract$horizon_grid,
                     file.path(visual_dir, "stock_atlas_02_selected_horizons.png"))
plot_return_distribution(summary,
                         file.path(visual_dir, "stock_atlas_02_return_distribution.png"))
plot_continuity(summary, file.path(visual_dir, "stock_atlas_02_continuity_direction.png"))
equity_paths <- plot_equity_pages(replay, summary, visual_dir)

report <- c(
  "# LIT-MOM-01.2 Stock Atlas 02: 2020 Breadth + Attention",
  "",
  paste0("Status: `", batch$overall_status, "`"),
  "",
  "## Boundary",
  "",
  "Every eligible stock independently searches all 49 TRAIN cells and replays",
  "only its frozen winner in the already inspected 2021-2023 window. This is",
  "retrospective exploration, not fresh OOS confirmation.",
  "",
  "## Coverage and breadth",
  "",
  sprintf("- Frozen registry: `%d` assets (`75` core + `25` attention).", nrow(registry)),
  sprintf("- Exact TRAIN and retrospective coverage: `%d / %d`.", nrow(summary), nrow(registry)),
  sprintf("- TRAIN cells evaluated: `%d`.", nrow(horizon_screen)),
  sprintf("- Positive primary / stress paths: `%d / %d`.",
          batch$assets_positive_primary, batch$assets_positive_stress),
  sprintf("- TRAIN / retrospective primary bankruptcy stops: `%d / %d`.",
          batch$train_primary_bankruptcies,
          batch$retrospective_primary_bankruptcies),
  sprintf("- Median / mean primary return: `%.2f%% / %.2f%%`.",
          100 * batch$median_primary_return, 100 * batch$mean_primary_return),
  sprintf("- Worst primary drawdown: `%.2f%%`.", 100 * batch$worst_primary_drawdown),
  "",
  "## Interpretation",
  "",
  "Compare the two frozen cohorts descriptively, but do not select a winner,",
  "form a portfolio, replace coverage failures, add shorts, or query 2024+.",
  "",
  "## Packet",
  "",
  paste0("`", normalizePath(output_dir, winslash = "/", mustWork = FALSE), "`")
)
writeLines(report, file.path(output_dir, "stock_atlas_02_report.md"))

message("LIT-MOM-01.2 Stock Atlas 02 complete.")
message("Eligible: ", nrow(summary), " / ", nrow(registry))
message("Packet: ", output_dir)
