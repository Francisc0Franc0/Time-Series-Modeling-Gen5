# Run the frozen LIT-MOM-01.1 interday time-series momentum POC.

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
  if (!dir.exists(path)) stop("Could not create LIT-MOM-01.1 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  x <- as.data.frame(x)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

coverage_audit <- function(bars, contract, period_end) {
  shy <- bars[bars$symbol == contract$symbol, , drop = FALSE]
  spy <- bars[bars$symbol == "SPY", , drop = FALSE]
  shy_dates <- sort(unique(as.Date(shy$session_date)))
  spy_dates <- sort(unique(as.Date(spy$session_date)))
  expected <- spy_dates[spy_dates >= contract$query_start & spy_dates <= as.Date(period_end)]
  observed <- shy_dates[shy_dates >= contract$query_start & shy_dates <= as.Date(period_end)]
  missing <- setdiff(expected, observed)
  data.frame(
    check_id = c(
      "query_start_covered",
      "period_end_covered",
      "matches_spy_reference_sessions"
    ),
    passed = c(
      length(observed) > 0 && min(observed) <= min(expected),
      length(observed) > 0 && max(observed) >= max(expected),
      length(missing) == 0L
    ),
    value = c(
      if (length(observed)) as.character(min(observed)) else "none",
      if (length(observed)) as.character(max(observed)) else "none",
      paste(length(observed), "of", length(expected), "SPY sessions")
    ),
    stringsAsFactors = FALSE
  )
}

period_colors <- c(
  GROSS = "#64748B",
  PRIMARY = "#3D8DFF",
  STRESS = "#F59E0B"
)

plot_correlation_views <- function(analysis, path) {
  analysis <- as.list(analysis)
  pair_ids <- unique(analysis$correlation_pairs$sampling_id)
  pairs <- setNames(lapply(pair_ids, function(pair_id) {
    analysis$correlation_pairs[
      analysis$correlation_pairs$sampling_id == pair_id,
      ,
      drop = FALSE
    ]
  }), pair_ids)
  summary <- analysis$correlation_summary
  order_ids <- c("CHAN_MIN_STEP", "STRICT_FULL_PAIR_STEP", "DAILY_OVERLAPPING")
  labels <- c(
    paste0(
      "Chan min-step (",
      min(analysis$lookback_sessions, analysis$holding_sessions),
      " sessions)"
    ),
    paste0(
      "Strict full-pair step (",
      analysis$lookback_sessions + analysis$holding_sessions,
      ")"
    ),
    "Daily overlapping (descriptive)"
  )
  png(path, width = 2300, height = 850, res = 150)
  old <- par(mfrow = c(1, 3), mar = c(6, 6, 5, 2))
  for (i in seq_along(order_ids)) {
    id <- order_ids[[i]]
    x <- pairs[[id]]
    s <- summary[summary$sampling_id == id, , drop = FALSE]
    plot(
      100 * x$past_return,
      100 * x$future_return,
      pch = 19,
      col = grDevices::adjustcolor("#3D8DFF", alpha.f = 0.55),
      xlab = paste("Past", analysis$lookback_sessions, "session return (%)"),
      ylab = paste("Future", analysis$holding_sessions, "session return (%)"),
      main = paste0(
        labels[[i]], "\n",
        "n=", nrow(x), " | r=", sprintf("%.3f", s$return_correlation)
      )
    )
    abline(h = 0, v = 0, col = "#CBD5E1")
    if (nrow(x) >= 3L) abline(stats::lm(future_return ~ past_return, data = x), col = "#0F172A", lwd = 2)
  }
  par(old)
  dev.off()
}

plot_direction <- function(analysis, path) {
  analysis <- as.list(analysis)
  chan <- analysis$correlation_summary[
    analysis$correlation_summary$sampling_id == "CHAN_MIN_STEP",
    ,
    drop = FALSE
  ]
  values <- 100 * c(
    chan$direction_accuracy,
    chan$long_call_precision,
    chan$short_call_precision
  )
  png(path, width = 1500, height = 850, res = 150)
  old <- par(mar = c(7, 7, 4, 2))
  bars <- barplot(
    values,
    names.arg = c("All calls", "Long calls up", "Short calls down"),
    col = c("#3D8DFF", "#177245", "#B42318"),
    ylim = c(0, max(65, values + 8)),
    ylab = "Accuracy / precision (%)",
    main = "Direction is a separate question from strategy P&L"
  )
  abline(h = 50, col = "#0F172A", lty = 2)
  text(bars, values, sprintf("%.1f%%", values), pos = 3, font = 2)
  par(old)
  dev.off()
}

plot_exposure_tape <- function(analysis, path) {
  analysis <- as.list(analysis)
  primary <- analysis$replay[analysis$replay$cost_regime == "PRIMARY", , drop = FALSE]
  signal <- analysis$signal_panel[
    analysis$signal_panel$signal_date >= analysis$period_start &
      analysis$signal_panel$signal_date <= analysis$period_end,
    ,
    drop = FALSE
  ]
  png(path, width = 2100, height = 1100, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 5))
  plot(
    signal$signal_date,
    signal$current_close,
    type = "l",
    col = "#0F172A",
    lwd = 2,
    xlab = "",
    ylab = "Adjusted close",
    main = paste0(
      "The ", analysis$lookback_sessions,
      "-session sign feeds ", analysis$holding_sessions,
      " overlapping sleeves"
    )
  )
  lookback <- signal$lookback_close
  lines(signal$signal_date, lookback, col = "#94A3B8", lwd = 2)
  legend(
    "topleft",
    legend = c(
      "SHY adjusted close",
      paste("Close", analysis$lookback_sessions, "sessions earlier")
    ),
    col = c("#0F172A", "#94A3B8"),
    lty = 1,
    lwd = 2,
    bty = "n"
  )
  plot(
    primary$entry_date,
    primary$position,
    type = "s",
    col = "#3D8DFF",
    lwd = 2,
    ylim = c(-1, 1),
    xlab = "",
    ylab = "Net exposure",
    main = "Causal next-open position: −1 short, +1 long"
  )
  abline(h = c(-1, 0, 1), col = c("#CBD5E1", "#0F172A", "#CBD5E1"))
  par(old)
  dev.off()
}

plot_equity_drawdown <- function(analysis, path) {
  analysis <- as.list(analysis)
  replay <- analysis$replay
  buy_hold <- analysis$buy_hold
  source <- analysis$source_style
  png(path, width = 2100, height = 1150, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
  primary <- replay[replay$cost_regime == "PRIMARY", , drop = FALSE]
  y_range <- range(
    replay$wealth,
    buy_hold$wealth,
    source$wealth,
    na.rm = TRUE
  )
  plot(
    range(replay$outcome_date),
    y_range,
    type = "n",
    xlab = "",
    ylab = "Growth of $1",
    main = "Causal strategy costs are separated from source-style teaching context"
  )
  for (id in names(period_colors)) {
    x <- replay[replay$cost_regime == id, , drop = FALSE]
    lines(x$outcome_date, x$wealth, col = period_colors[[id]], lwd = if (id == "PRIMARY") 3 else 2)
  }
  lines(buy_hold$session_date, buy_hold$wealth, col = "#177245", lwd = 2, lty = 2)
  lines(source$session_date, source$wealth, col = "#8B5CF6", lwd = 2, lty = 3)
  legend(
    "topleft",
    legend = c("Gross causal", "Primary 5 bp", "Stress", "Buy SHY", "Source-style close/close"),
    col = c(period_colors, "#177245", "#8B5CF6"),
    lty = c(1, 1, 1, 2, 3),
    lwd = c(2, 3, 2, 2, 2),
    bty = "n",
    ncol = 2
  )
  plot(
    primary$outcome_date,
    100 * primary$drawdown,
    type = "h",
    col = "#B42318",
    lwd = 2,
    xlab = "",
    ylab = "Drawdown (%)",
    main = "Primary-cost causal drawdown"
  )
  abline(h = 0, col = "#0F172A")
  par(old)
  dev.off()
}

plot_sleeves <- function(analysis, path) {
  analysis <- as.list(analysis)
  sleeves <- analysis$sleeves
  group_ids <- unique(sleeves$direction_label)
  groups <- setNames(lapply(group_ids, function(group_id) {
    sleeves$primary_net_sleeve_return[sleeves$direction_label == group_id]
  }), group_ids)
  png(path, width = 1900, height = 950, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(6, 7, 4, 2))
  boxplot(
    lapply(groups, function(x) 100 * x),
    col = c(LONG = "#177245", SHORT = "#B42318")[names(groups)],
    ylab = "Primary net sleeve return (%)",
    main = paste(
      "Each daily signal is a",
      analysis$holding_sessions,
      "session swing sleeve"
    )
  )
  abline(h = 0, col = "#0F172A")
  year <- analysis$calendar_years
  values <- 100 * year$cumulative_return
  bars <- barplot(
    values,
    names.arg = year$calendar_year,
    col = ifelse(values > 0, "#177245", "#B42318"),
    ylab = "Primary strategy return (%)",
    main = "Calendar stability is a frozen TRAIN gate"
  )
  abline(h = 0, col = "#0F172A")
  text(bars, values, sprintf("%.2f", values), pos = ifelse(values >= 0, 3, 1))
  par(old)
  dev.off()
}

plot_representative_swings <- function(analysis, bars, path) {
  analysis <- as.list(analysis)
  bars <- as.data.frame(bars)
  sleeves <- analysis$sleeves
  if (!nrow(sleeves)) return(invisible(NULL))
  ordered <- sleeves[order(sleeves$primary_net_sleeve_return), , drop = FALSE]
  indices <- unique(round(seq(1, nrow(ordered), length.out = min(6L, nrow(ordered)))))
  chosen <- ordered[indices, , drop = FALSE]
  shy <- bars[bars$symbol == "SHY", , drop = FALSE]
  shy <- shy[order(shy$session_date), , drop = FALSE]
  png(path, width = 2350, height = 1450, res = 150)
  old <- par(mfrow = c(2, 3), mar = c(6, 5, 4, 2))
  for (i in seq_len(6L)) {
    if (i > nrow(chosen)) {
      plot.new()
      next
    }
    row <- chosen[i, , drop = FALSE]
    entry_i <- match(row$entry_date, shy$session_date)
    exit_i <- match(row$exit_date, shy$session_date)
    lo <- max(1L, entry_i - 5L)
    hi <- min(nrow(shy), exit_i + 5L)
    part <- shy[lo:hi, , drop = FALSE]
    normalized <- 100 * part$close / shy$open[[entry_i]]
    plot(
      part$session_date,
      normalized,
      type = "l",
      lwd = 2,
      col = "#0F172A",
      xlab = "",
      ylab = "Price index (entry open = 100)",
      main = paste0(
        row$direction_label, " ", row$entry_date, "\n",
        analysis$holding_sessions,
        "-session net ",
        sprintf("%.2f%%", 100 * row$primary_net_sleeve_return)
      )
    )
    abline(h = 100, col = "#CBD5E1")
    abline(v = c(row$entry_date, row$exit_date), col = c("#3D8DFF", "#F59E0B"), lty = 2)
  }
  par(old)
  dev.off()
}

plot_horizon_map <- function(screen, selected, path) {
  horizons <- sort(unique(c(
    screen$lookback_sessions,
    screen$holding_sessions
  )))
  matrix_values <- matrix(
    NA_real_,
    nrow = length(horizons),
    ncol = length(horizons),
    dimnames = list(
      paste0("L", horizons),
      paste0("H", horizons)
    )
  )
  for (i in seq_len(nrow(screen))) {
    row_i <- match(screen$lookback_sessions[[i]], horizons)
    column_i <- match(screen$holding_sessions[[i]], horizons)
    matrix_values[row_i, column_i] <- screen$return_correlation[[i]]
  }
  png(path, width = 1750, height = 1250, res = 150)
  old <- par(mar = c(7, 8, 5, 3))
  image(
    x = seq_along(horizons),
    y = seq_along(horizons),
    z = matrix_values,
    axes = FALSE,
    xlab = "Lookback sessions",
    ylab = "Holding sessions",
    main = "TRAIN horizon map: correlation of past and future SHY returns",
    col = grDevices::colorRampPalette(c("#B42318", "#F8FAFC", "#177245"))(101),
    zlim = c(-max(abs(matrix_values), na.rm = TRUE), max(abs(matrix_values), na.rm = TRUE))
  )
  axis(1, at = seq_along(horizons), labels = horizons)
  axis(2, at = seq_along(horizons), labels = horizons, las = 1)
  for (i in seq_along(horizons)) {
    for (j in seq_along(horizons)) {
      value <- matrix_values[[i, j]]
      if (is.finite(value)) {
        text(i, j, sprintf("%.2f", value), cex = 0.72)
      }
    }
  }
  selected_x <- match(selected$lookback_sessions, horizons)
  selected_y <- match(selected$holding_sessions, horizons)
  points(selected_x, selected_y, pch = 0, cex = 3.2, lwd = 4, col = "#3D8DFF")
  mtext(
    paste0(
      "Blue box = frozen selection ",
      selected$lookback_sessions, "/", selected$holding_sessions,
      " | p=", sprintf("%.3f", selected$naive_pearson_p_value)
    ),
    side = 1,
    line = 5,
    col = "#3D8DFF",
    font = 2
  )
  par(old)
  dev.off()
}

plot_gates <- function(gates, status, path) {
  png(path, width = 1900, height = 950, res = 150)
  old <- par(mar = c(4, 23, 4, 3))
  y <- rev(seq_len(nrow(gates)))
  plot(
    c(0, 1),
    c(0.5, nrow(gates) + 0.5),
    type = "n",
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = paste("LIT-MOM-01.1 TRAIN verdict:", status)
  )
  axis(2, at = y, labels = gates$gate, las = 1, cex.axis = 0.8)
  colors <- ifelse(gates$status == "PASS", "#177245", "#B42318")
  points(rep(0.35, nrow(gates)), y, pch = 19, cex = 3.2, col = colors)
  text(rep(0.35, nrow(gates)), y, gates$status, col = "white", font = 2, cex = 0.58)
  text(rep(0.52, nrow(gates)), y, gates$value, pos = 4, cex = 0.78)
  par(old)
  dev.off()
}

write_period_artifacts <- function(analysis, prefix, output_dir, visual_dir, bars) {
  analysis_value <- as.list(analysis)
  paths <- list(
    signal_panel = file.path(output_dir, paste0(prefix, "_signal_panel.csv")),
    correlation_pairs = file.path(output_dir, paste0(prefix, "_correlation_pairs.csv")),
    correlation_summary = file.path(output_dir, paste0(prefix, "_correlation_summary.csv")),
    correlation_bootstrap = file.path(output_dir, paste0(prefix, "_correlation_bootstrap.csv")),
    direction_confusion = file.path(output_dir, paste0(prefix, "_direction_confusion.csv")),
    sleeves = file.path(output_dir, paste0(prefix, "_completed_sleeves.csv")),
    replay = file.path(output_dir, paste0(prefix, "_bar_replay.csv")),
    metrics = file.path(output_dir, paste0(prefix, "_performance_metrics.csv")),
    calendar_years = file.path(output_dir, paste0(prefix, "_calendar_years.csv")),
    buy_hold = file.path(output_dir, paste0(prefix, "_buy_hold_context.csv")),
    source_style = file.path(output_dir, paste0(prefix, "_source_style_replay.csv")),
    correlation_png = file.path(visual_dir, paste0(prefix, "_correlation_views.png")),
    direction_png = file.path(visual_dir, paste0(prefix, "_direction_scorecard.png")),
    exposure_png = file.path(visual_dir, paste0(prefix, "_exposure_tape.png")),
    equity_png = file.path(visual_dir, paste0(prefix, "_equity_drawdown.png")),
    sleeves_png = file.path(visual_dir, paste0(prefix, "_sleeve_and_year_summary.png")),
    swings_png = file.path(visual_dir, paste0(prefix, "_representative_swings.png"))
  )
  csv_objects <- list(
    signal_panel = analysis_value[["signal_panel"]],
    correlation_pairs = analysis_value[["correlation_pairs"]],
    correlation_summary = analysis_value[["correlation_summary"]],
    correlation_bootstrap = analysis_value[["correlation_bootstrap"]],
    direction_confusion = analysis_value[["direction_confusion"]],
    sleeves = analysis_value[["sleeves"]],
    replay = analysis_value[["replay"]],
    metrics = analysis_value[["metrics"]],
    calendar_years = analysis_value[["calendar_years"]],
    buy_hold = analysis_value[["buy_hold"]],
    source_style = analysis_value[["source_style"]]
  )
  for (artifact_id in names(csv_objects)) {
    do.call(write_csv, list(
      x = csv_objects[[artifact_id]],
      path = paths[[artifact_id]]
    ))
  }
  do.call(plot_correlation_views, list(
    analysis = analysis_value,
    path = paths$correlation_png
  ))
  do.call(plot_direction, list(
    analysis = analysis_value,
    path = paths$direction_png
  ))
  do.call(plot_exposure_tape, list(
    analysis = analysis_value,
    path = paths$exposure_png
  ))
  do.call(plot_equity_drawdown, list(
    analysis = analysis_value,
    path = paths$equity_png
  ))
  do.call(plot_sleeves, list(
    analysis = analysis_value,
    path = paths$sleeves_png
  ))
  do.call(plot_representative_swings, list(
    analysis = analysis_value,
    bars = as.data.frame(bars),
    path = paths$swings_png
  ))
  paths
}

write_report <- function(path, result, coverage, run_spec, artifact_paths) {
  contract <- result$contract
  train <- result$train
  canonical <- result$canonical_250_25
  selected <- result$selected_candidate
  chan <- train$correlation_summary[
    train$correlation_summary$sampling_id == "CHAN_MIN_STEP",
    ,
    drop = FALSE
  ]
  strict <- train$correlation_summary[
    train$correlation_summary$sampling_id == "STRICT_FULL_PAIR_STEP",
    ,
    drop = FALSE
  ]
  primary <- train$metrics[train$metrics$strategy_id == "PRIMARY", , drop = FALSE]
  stress <- train$metrics[train$metrics$strategy_id == "STRESS", , drop = FALSE]
  canonical_chan <- canonical$correlation_summary[
    canonical$correlation_summary$sampling_id == "CHAN_MIN_STEP",
    ,
    drop = FALSE
  ]
  canonical_primary <- canonical$metrics[
    canonical$metrics$strategy_id == "PRIMARY",
    ,
    drop = FALSE
  ]
  development <- result[["development"]]
  development_chan <- if (!is.null(development)) {
    development$correlation_summary[
      development$correlation_summary$sampling_id == "CHAN_MIN_STEP",
      ,
      drop = FALSE
    ]
  } else {
    NULL
  }
  development_primary <- if (!is.null(development)) {
    development$metrics[
      development$metrics$strategy_id == "PRIMARY",
      ,
      drop = FALSE
    ]
  } else {
    NULL
  }
  development_stress <- if (!is.null(development)) {
    development$metrics[
      development$metrics$strategy_id == "STRESS",
      ,
      drop = FALSE
    ]
  } else {
    NULL
  }
  lines <- c(
    "# LIT-MOM-01.1 Interday Time-Series Momentum",
    "",
    paste0("**Frozen verdict:** `", result$overall_status, "`"),
    "",
    "## What was built",
    "",
    "A two-stage reconstruction of Chan's Chapter 6 workflow: first compare a frozen grid of past/future horizons on TRAIN, then trade the selected sign rule with overlapping equal sleeves and causal next-open ETF execution. The single frozen instrument is SHY, the closest Alpaca-tradable maturity proxy to the source's TU future.",
    "",
    "## TRAIN horizon selection",
    "",
    paste0("- Evaluated `", nrow(result$horizon_screen), "` combinations from `{", paste(contract$horizon_grid, collapse = ","), "}` x `{", paste(contract$horizon_grid, collapse = ","), "}`."),
    paste0("- Frozen selected rule: `", selected$lookback_sessions, "/", selected$holding_sessions, "`; `n=", selected$pair_count, "`, correlation `", sprintf("%.4f", selected$return_correlation), "`, naive p-value `", sprintf("%.4f", selected$naive_pearson_p_value), "`, direction accuracy `", sprintf("%.1f%%", 100 * selected$direction_accuracy), "`."),
    paste0("- Selection ranked supported holding periods of at least `", contract$minimum_selected_holding_sessions, "` sessions by the strongest positive correlation t-statistic, then shorter holding/lookback."),
    "- This is a TRAIN-only screening statistic across 49 related tests. The p-value is not multiplicity-adjusted proof; the sealed OOS window is the real falsification surface.",
    "",
    "## Selected-rule TRAIN mechanism",
    "",
    paste0("- Chan min-step pairs: `", chan$pair_count, "`; return correlation `", sprintf("%.4f", chan$return_correlation), "`; naive Pearson p-value `", sprintf("%.4f", chan$naive_pearson_p_value), "`."),
    paste0("- Past/future sign accuracy: `", sprintf("%.1f%%", 100 * chan$direction_accuracy), "`; long precision `", sprintf("%.1f%%", 100 * chan$long_call_precision), "`; short precision `", sprintf("%.1f%%", 100 * chan$short_call_precision), "`."),
    paste0("- Strict `L+H=", train$lookback_sessions + train$holding_sessions, "` spacing leaves `", strict$pair_count, "` pairs and correlation `", sprintf("%.4f", strict$return_correlation), "`. It is a sensitivity view, not enough independent information for strong inference."),
    paste0("- Moving-block 80% central interval for the Chan-spaced correlation: `", sprintf("[%.4f, %.4f]", train$correlation_bootstrap$lower_90, train$correlation_bootstrap$upper_90), "`."),
    "",
    "## Canonical book example beside the selected rule",
    "",
    paste0("- `CANON_250_25` remains the source-parameter reference: correlation `", sprintf("%.4f", canonical_chan$return_correlation), "`, direction accuracy `", sprintf("%.1f%%", 100 * canonical_chan$direction_accuracy), "`, primary causal TRAIN return `", sprintf("%.2f%%", 100 * canonical_primary$cumulative_return), "`."),
    "- The canonical view is not allowed to replace the TRAIN-selected SHY horizon after outcomes.",
    "",
    "## TRAIN strategy",
    "",
    paste0("- Completed sleeves: `", nrow(train$sleeves), "`."),
    paste0("- Primary cumulative return: `", sprintf("%.2f%%", 100 * primary$cumulative_return), "`; adjusted Sharpe `", sprintf("%.2f", primary$autocorrelation_adjusted_sharpe), "`; maximum drawdown `", sprintf("%.2f%%", 100 * primary$maximum_drawdown), "`."),
    paste0("- Stress cumulative return: `", sprintf("%.2f%%", 100 * stress$cumulative_return), "`."),
    paste0("- Positive TRAIN years: `", sum(train$calendar_years$cumulative_return > 0), " / ", nrow(train$calendar_years), "`."),
    "",
    if (!is.null(development)) "## Frozen OOS DEVELOPMENT replay" else NULL,
    if (!is.null(development)) "" else NULL,
    if (!is.null(development)) paste0(
      "- Selected-rule correlation fell to `",
      sprintf("%.4f", development_chan$return_correlation),
      "` with nominal p-value `",
      sprintf("%.4f", development_chan$naive_pearson_p_value),
      "`; direction accuracy was `",
      sprintf("%.1f%%", 100 * development_chan$direction_accuracy),
      "`."
    ) else NULL,
    if (!is.null(development)) paste0(
      "- Primary cumulative return was `",
      sprintf("%.2f%%", 100 * development_primary$cumulative_return),
      "` with adjusted Sharpe `",
      sprintf("%.2f", development_primary$autocorrelation_adjusted_sharpe),
      "` and maximum drawdown `",
      sprintf("%.2f%%", 100 * development_primary$maximum_drawdown),
      "`."
    ) else NULL,
    if (!is.null(development)) paste0(
      "- Stress cumulative return was `",
      sprintf("%.2f%%", 100 * development_stress$cumulative_return),
      "`; calendar results were `",
      paste0(
        development$calendar_years$calendar_year,
        "=",
        sprintf("%.2f%%", 100 * development$calendar_years$cumulative_return),
        collapse = ", "
      ),
      "`."
    ) else NULL,
    if (!is.null(development)) "- No OOS promotion gate was invented after inspection. The economic readout supports stopping before sealed CONFIRMATION." else NULL,
    "",
    "## Frozen gates",
    "",
    paste0("- **", result$gates$gate_id, " ", result$gates$gate, ": ", result$gates$status, "** - ", result$gates$value),
    "",
    "## Interpretation",
    "",
    if (result$development_authorized) {
      "Every TRAIN gate passed, so the one frozen 2021-2023 DEVELOPMENT replay was opened. The selected correlation and directional accuracy weakened materially, primary performance was approximately flat after ordinary costs, and stress performance was negative. Record the completed OOS exercise and recommend STOP before CONFIRMATION; do not tune the horizon table on these outcomes."
    } else {
      "At least one TRAIN gate failed. DEVELOPMENT was not queried. The result must not be rescued by changing SHY, the 250/25 horizons, costs, sampling rule, dates, or gates."
    },
    "",
    paste0("The book-style p-value is descriptive. With min(L,H) anchor spacing, the shorter return windows do not overlap, but the longer windows generally do. The ordinary IID Pearson p-value therefore overstates how independent the observations are."),
    "",
    "SHY is a retail proxy, not TU. ETF expenses, distributions, share borrow, and absence of a futures roll path prevent a literal replication of Chan's causal explanation.",
    "",
    "## Authority",
    "",
    paste0("- As of: `", run_spec$as_of_timestamp, "`."),
    paste0("- Feed: `", run_spec$feed, "`."),
    paste0("- Coverage: `", sum(coverage$passed), " / ", nrow(coverage), "` checks pass."),
    paste0("- Later outcomes opened: `", run_spec$development_opened, "`."),
    "",
    "## Key artifacts",
    "",
    paste0("- `", names(artifact_paths), "`: `", normalizePath(unlist(artifact_paths), winslash = "/", mustWork = FALSE), "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

message("LIT-MOM-01.1 frozen interday momentum POC starting.")
contract <- g5_mom01_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_01_1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_01_1_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_01_1_RUN_ID",
  "lit_mom_01_1_interday_momentum_20260730_v6"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query_train <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$train_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = c(contract$symbol, "SPY"),
  universe_name = "lit_mom_01_1_shy_and_coverage_reference",
  universe_roles = "shy_tu_proxy,spy_session_reference",
  refresh = refresh,
  repo_root = repo_root
)
coverage <- coverage_audit(query_train$bars, contract, contract$train_end)
if (!all(coverage$passed)) {
  stop("LIT-MOM-01.1 TRAIN coverage audit failed.", call. = FALSE)
}
result <- g5_mom01_run_train(query_train$bars, contract)
all_bars <- query_train$bars
query_development <- NULL
if (result$development_authorized) {
  query_development <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = contract$query_start,
    end_date = contract$development_end,
    as_of_timestamp = contract$as_of_timestamp,
    symbols = c(contract$symbol, "SPY"),
    universe_name = "lit_mom_01_1_shy_and_coverage_reference",
    universe_roles = "shy_tu_proxy,spy_session_reference",
    refresh = refresh,
    repo_root = repo_root
  )
  development_coverage <- coverage_audit(
    query_development$bars,
    contract,
    contract$development_end
  )
  if (!all(development_coverage$passed)) {
    stop("LIT-MOM-01.1 DEVELOPMENT coverage audit failed.", call. = FALSE)
  }
  coverage <- rbind(
    transform(coverage, evaluation_period = "TRAIN"),
    transform(development_coverage, evaluation_period = "DEVELOPMENT")
  )
  all_bars <- query_development$bars
  result$development <- g5_mom01_run_development(
    query_development$bars,
    result,
    contract
  )
  result$overall_status <- "OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1"
} else {
  coverage$evaluation_period <- "TRAIN"
}

artifact_paths <- list(
  run_spec = file.path(output_dir, "lit_mom_01_1_run_spec.csv"),
  frozen_contract = file.path(output_dir, "lit_mom_01_1_frozen_contract.csv"),
  coverage = file.path(output_dir, "lit_mom_01_1_coverage_audit.csv"),
  integrity = file.path(output_dir, "lit_mom_01_1_integrity_audit.csv"),
  horizon_screen = file.path(output_dir, "lit_mom_01_1_train_horizon_screen.csv"),
  selected_candidate = file.path(output_dir, "lit_mom_01_1_selected_candidate.csv"),
  gates = file.path(output_dir, "lit_mom_01_1_train_gate_summary.csv"),
  horizon_png = file.path(visual_dir, "lit_mom_01_1_train_horizon_map.png"),
  gate_png = file.path(visual_dir, "lit_mom_01_1_train_gate_summary.png"),
  report = file.path(output_dir, "lit_mom_01_1_report.md")
)
train_paths <- write_period_artifacts(
  result$train,
  "train",
  output_dir,
  visual_dir,
  all_bars
)
artifact_paths <- c(artifact_paths, train_paths)
canonical_paths <- write_period_artifacts(
  result$canonical_250_25,
  "canonical_250_25",
  output_dir,
  visual_dir,
  all_bars
)
artifact_paths <- c(artifact_paths, canonical_paths)
if (!is.null(result[["development"]])) {
  development_paths <- write_period_artifacts(
    result[["development"]],
    "development",
    output_dir,
    visual_dir,
    all_bars
  )
  artifact_paths <- c(artifact_paths, development_paths)
}

health <- if (is.null(query_development)) query_train$health else query_development$health
health_max <- if (!nrow(health)) "PASS" else {
  levels <- c(PASS = 1L, INFO = 1L, WARN = 2L, ERROR = 3L)
  names(which.max(tapply(levels[health$severity], health$severity, max)))
}
run_spec <- data.frame(
  schema_version = g5_mom01_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_01_1_interday_momentum_poc.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  symbol = contract$symbol,
  source_instrument = "TU_two_year_treasury_future",
  proxy_limitation = "SHY_is_not_a_futures_roll_replication",
  lookback_sessions = contract$lookback_sessions,
  holding_sessions = contract$holding_sessions,
  selected_lookback_sessions = result$selected_candidate$lookback_sessions,
  selected_holding_sessions = result$selected_candidate$holding_sessions,
  train_start = contract$train_start,
  train_end = contract$train_end,
  development_opened = result$development_authorized,
  confirmation_opened = FALSE,
  overall_status = result$overall_status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)
contract_frame <- data.frame(
  literature_id = contract$literature_id,
  signal = "sign_of_TRAIN_selected_lookback_adjusted_close_return",
  horizon_screen = "L_and_H_in_1_5_10_25_60_120_250",
  horizon_selection = "max_supported_correlation_t_stat_then_shorter_holding_and_lookback",
  execution = "next_open_1_over_selected_holding_sleeve",
  holding = "selected_holding_sessions_open_to_open",
  position = "net_sum_of_active_sleeves_bounded_minus1_plus1",
  correlation_primary = "min_lookback_holding_step_nonoverlapping_shorter_outcomes",
  correlation_strict = "lookback_plus_holding_step",
  canonical_reference = "250_lookback_25_holding",
  primary_cost = "5bp_per_one_way_net_turnover",
  stress_cost = "10bp_per_one_way_net_turnover_plus_100bp_annual_short_borrow",
  stringsAsFactors = FALSE
)
write_csv(run_spec, artifact_paths$run_spec)
write_csv(contract_frame, artifact_paths$frozen_contract)
write_csv(coverage, artifact_paths$coverage)
write_csv(result$train$integrity, artifact_paths$integrity)
write_csv(result$horizon_screen, artifact_paths$horizon_screen)
write_csv(result$selected_candidate, artifact_paths$selected_candidate)
write_csv(result$gates, artifact_paths$gates)
plot_horizon_map(
  result$horizon_screen,
  result$selected_candidate,
  artifact_paths$horizon_png
)
plot_gates(result$gates, result$overall_status, artifact_paths$gate_png)
write_report(
  artifact_paths$report,
  result,
  coverage,
  run_spec,
  artifact_paths
)
g5_write_workbench_query_artifacts(
  if (is.null(query_development)) query_train else query_development,
  output_dir,
  "lit_mom_01_1_workbench_query"
)

message("LIT-MOM-01.1 complete: ", result$overall_status)
message("Data health: ", health_max)
message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
message("Report: ", normalizePath(artifact_paths$report, winslash = "/", mustWork = FALSE))
