# Run the frozen LIT-MR-06.1 causal buy-on-gap atlas.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(
    file.path(dirname(script_path), "..", ".."),
    winslash = "/", mustWork = FALSE
  )
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mr_06_1_buy_on_gap_poc.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mr_06_1_recent_wide_atlas.R"
))
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mr_06_1_alpaca_intraday.R"
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
  if (!dir.exists(path)) {
    stop("Could not create LIT-MR-06.1 output directory.", call. = FALSE)
  }
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

read_rds_or_fetch_daily <- function(
  path,
  symbols,
  start_date,
  end_date,
  contract,
  config,
  refresh
) {
  if (file.exists(path) && !refresh) {
    message("Reusing daily evidence cache: ", path)
    return(readRDS(path))
  }
  seed_path <- Sys.getenv(
    "GEN5_LIT_MR_06_1_SEED_DAILY_RDS", unset = ""
  )
  if (!refresh && nzchar(seed_path) && file.exists(seed_path)) {
    message("Seeding daily evidence cache from: ", seed_path)
    bars <- readRDS(seed_path)
    bars <- bars[
      bars$symbol %in% symbols &
        bars$session_date >= as.Date(start_date) &
        bars$session_date <= as.Date(end_date),
      ,
      drop = FALSE
    ]
    saveRDS(bars, path)
    return(bars)
  }
  symbol_map <- g5_mr06_alpaca_symbol_map(symbols, end_date)
  request <- g5_alpaca_daily_adjusted_request(
    symbols = unique(symbol_map$provider_symbol),
    start_date = start_date,
    end_date = end_date,
    as_of_timestamp = contract$as_of_timestamp,
    latest_completed_session = end_date,
    feed = config$feed
  )
  bars <- g5_fetch_alpaca_daily_adjusted_bars(request, config)
  for (i in seq_len(nrow(symbol_map))) {
    if (symbol_map$provider_symbol[[i]] != symbol_map$research_symbol[[i]]) {
      bars$symbol[bars$symbol == symbol_map$provider_symbol[[i]]] <-
        symbol_map$research_symbol[[i]]
    }
  }
  bars$data_version_hash <- mapply(
    g5_make_data_version_hash,
    bars$provider,
    bars$symbol,
    bars$session_date,
    bars$open,
    bars$high,
    bars$low,
    bars$close,
    bars$volume,
    bars$adjusted,
    bars$timeframe,
    bars$as_of_timestamp,
    bars$latest_completed_session,
    bars$fetch_start_date,
    bars$fetch_end_date,
    USE.NAMES = FALSE
  )
  bars <- g5_validate_bar_data(bars)
  saveRDS(bars, path)
  bars
}

read_rds_or_fetch_entries <- function(
  path,
  manifest,
  contract,
  config,
  adjustment_asof,
  refresh
) {
  if (file.exists(path) && !refresh) {
    message("Reusing 09:32 evidence cache: ", path)
    return(readRDS(path))
  }
  entries <- g5_mr06_alpaca_fetch_entries(
    manifest = manifest,
    contract = contract,
    config = config,
    adjustment_asof = adjustment_asof
  )
  saveRDS(entries, path)
  entries
}

coverage_table <- function(bars, contract, start_date, end_date) {
  benchmarks <- contract$registry$benchmark
  reference <- sort(unique(bars$session_date[
    bars$symbol == "SPY" &
      bars$session_date >= start_date &
      bars$session_date <= end_date
  ]))
  do.call(rbind, lapply(g5_mr06_all_symbols(contract), function(symbol) {
    observed <- sort(unique(bars$session_date[
      bars$symbol == symbol &
        bars$session_date >= start_date &
        bars$session_date <= end_date
    ]))
    ratio <- if (length(reference)) {
      length(intersect(observed, reference)) / length(reference)
    } else 0
    data.frame(
      symbol = symbol,
      role = ifelse(symbol %in% benchmarks, "benchmark_or_constituent", "constituent"),
      observed_sessions = length(observed),
      reference_sessions = length(reference),
      coverage_rate = ratio,
      first_session = if (length(observed)) min(observed) else as.Date(NA),
      last_session = if (length(observed)) max(observed) else as.Date(NA),
      status = ifelse(ratio >= 0.90, "PASS", "WARN"),
      stringsAsFactors = FALSE
    )
  }))
}

summary_row <- function(result) {
  performance <- result$performance
  data.frame(
    instance_id = result$registry$instance_id,
    category = result$registry$category,
    benchmark = result$registry$benchmark,
    status = result$status,
    full_train_pass = result$full_pass,
    gates_passed = sum(result$gates$status == "PASS"),
    stock_events = performance$stock_events,
    portfolio_days = performance$portfolio_days,
    cumulative_return = performance$cumulative_return,
    stress_cumulative_return = performance$stress_cumulative_return,
    source_noncausal_cumulative_return =
      performance$source_noncausal_cumulative_return,
    naive_sharpe = performance$naive_sharpe,
    adjusted_sharpe = performance$autocorrelation_adjusted_sharpe,
    maximum_drawdown = performance$maximum_drawdown,
    stock_event_hit_rate = performance$stock_event_hit_rate,
    up_down_accuracy = performance$stock_event_up_down_accuracy,
    average_invested_fraction = performance$average_invested_fraction,
    mean_portfolio_day_return = result$bootstrap$estimate,
    bootstrap_lower_90 = result$bootstrap$lower_90,
    bootstrap_upper_90 = result$bootstrap$upper_90,
    random_control_p90 = result$random_control$p90,
    mean_benchmark_excess = mean(result$portfolio$excess_return, na.rm = TRUE),
    maximum_positive_pnl_share = result$concentration$maximum_share,
    stringsAsFactors = FALSE
  )
}

gate_table <- function(results) {
  do.call(rbind, lapply(results, function(result) {
    cbind(
      instance_id = result$registry$instance_id,
      result$gates,
      stringsAsFactors = FALSE
    )
  }))
}

event_table <- function(results) {
  do.call(rbind, lapply(results, function(result) {
    x <- result$events
    if (!nrow(x)) return(NULL)
    x$instance_id <- result$registry$instance_id
    x
  }))
}

portfolio_table <- function(results) {
  do.call(rbind, lapply(results, function(result) {
    x <- result$portfolio
    if (!nrow(x)) return(NULL)
    x$instance_id <- result$registry$instance_id
    x
  }))
}

with_png <- function(path, width, height, expr) {
  grDevices::png(path, width = width, height = height, res = 130)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

plot_gate_heatmap <- function(gates, summary, path) {
  instances <- summary$instance_id
  matrix <- sapply(instances, function(id) {
    as.integer(gates$status[gates$instance_id == id] == "PASS")
  })
  if (is.null(dim(matrix))) matrix <- matrix(matrix, ncol = 1L)
  rownames(matrix) <- paste0("G", seq_len(nrow(matrix)))
  colnames(matrix) <- sub("^G[0-9]+_", "", instances)
  with_png(path, 1800, 900, {
    old <- par(mar = c(9, 7, 3, 2))
    on.exit(par(old), add = TRUE)
    image(
      seq_len(ncol(matrix)), seq_len(nrow(matrix)), t(matrix),
      col = c("#D95F59", "#2E8B57"), axes = FALSE,
      xlab = "", ylab = "", main = "Eight frozen TRAIN gates"
    )
    axis(1, at = seq_len(ncol(matrix)), labels = colnames(matrix),
         las = 2, cex.axis = 0.8)
    axis(2, at = seq_len(nrow(matrix)), labels = rownames(matrix),
         las = 2)
    for (i in seq_len(ncol(matrix))) {
      for (j in seq_len(nrow(matrix))) {
        text(i, j, ifelse(matrix[j, i] == 1L, "PASS", "FAIL"),
             col = "white", font = 2, cex = 0.75)
      }
    }
  })
}

plot_return_intervals <- function(summary, path) {
  order_idx <- order(summary$mean_portfolio_day_return)
  x <- summary[order_idx, , drop = FALSE]
  with_png(path, 1700, 1000, {
    old <- par(mar = c(6, 15, 4, 2))
    on.exit(par(old), add = TRUE)
    limits <- range(
      c(x$bootstrap_lower_90, x$bootstrap_upper_90, 0),
      finite = TRUE
    ) * 10000
    y <- seq_len(nrow(x))
    plot(
      x$mean_portfolio_day_return * 10000, y,
      xlim = limits, yaxt = "n", ylab = "", xlab = "Basis points per portfolio day",
      pch = 19, col = "#123047", main = "Causal return estimates remain uncertainty-aware"
    )
    segments(
      x$bootstrap_lower_90 * 10000, y,
      x$bootstrap_upper_90 * 10000, y,
      lwd = 4, col = "#3D8DFF"
    )
    points(x$mean_portfolio_day_return * 10000, y, pch = 19, col = "#123047")
    abline(v = 0, lty = 2, col = "#B42318")
    axis(2, at = y, labels = x$category, las = 2, cex.axis = 0.9)
  })
}

plot_source_causal <- function(summary, path) {
  values <- rbind(
    summary$source_noncausal_cumulative_return,
    summary$cumulative_return,
    summary$stress_cumulative_return
  ) * 100
  colnames(values) <- sub("^G[0-9]+_", "", summary$instance_id)
  rownames(values) <- c("Same-open reference", "09:32 causal", "09:32 stress")
  with_png(path, 1800, 1000, {
    old <- par(mar = c(9, 5, 4, 2))
    on.exit(par(old), add = TRUE)
    barplot(
      values, beside = TRUE,
      col = c("#94A3B8", "#3D8DFF", "#F59E0B"),
      las = 2, ylab = "Cumulative return (%)",
      main = "The execution delay is part of the hypothesis—not a footnote"
    )
    abline(h = 0, col = "#123047")
    legend(
      "topright", legend = rownames(values),
      fill = c("#94A3B8", "#3D8DFF", "#F59E0B"),
      bty = "n"
    )
  })
}

plot_primary_equity <- function(result, path) {
  x <- result$portfolio
  with_png(path, 1800, 950, {
    old <- par(mar = c(5, 5, 4, 5))
    on.exit(par(old), add = TRUE)
    causal <- cumprod(1 + x$primary_net_return)
    source <- cumprod(1 + x$source_noncausal_return)
    stress <- cumprod(1 + x$stress_net_return)
    y_range <- range(c(1, source, causal, stress), finite = TRUE)
    y_padding <- max(diff(y_range) * 0.08, 0.0005)
    plot(
      x$session_date, source, type = "l", lwd = 3, col = "#94A3B8",
      xlab = "", ylab = "Growth of $1 on event days",
      main = "Primary panel: source reference versus delayed execution",
      ylim = y_range + c(-y_padding, y_padding)
    )
    lines(x$session_date, causal, lwd = 3, col = "#3D8DFF")
    lines(x$session_date, stress, lwd = 3, col = "#F59E0B")
    abline(h = 1, lty = 3, col = "#64748B")
    legend(
      "topleft",
      legend = c("Same-open noncausal", "09:32 primary", "09:32 stress"),
      col = c("#94A3B8", "#3D8DFF", "#F59E0B"),
      lwd = 3, bty = "n"
    )
  })
}

plot_gap_response <- function(events, path, primary_instance_id) {
  x <- events[
    events$instance_id == primary_instance_id & events$entry_available,
    ,
    drop = FALSE
  ]
  with_png(path, 1500, 1000, {
    old <- par(mar = c(5, 5, 4, 2))
    on.exit(par(old), add = TRUE)
    plot(
      x$gap_return * 100, x$gross_return * 100,
      pch = 19, col = grDevices::adjustcolor("#3D8DFF", 0.65),
      xlab = "Overnight gap versus prior low (%)",
      ylab = "09:32-to-close return (%)",
      main = "Does a deeper gap predict a stronger same-day rebound?"
    )
    abline(h = 0, v = 0, lty = 2, col = "#64748B")
    if (nrow(x) >= 3L) {
      fit <- stats::lm(gross_return ~ gap_return, data = x)
      abline(fit, col = "#B42318", lwd = 3)
    }
  })
}

plot_representative_events <- function(events, path, primary_instance_id) {
  x <- events[
    events$instance_id == primary_instance_id & events$entry_available,
    ,
    drop = FALSE
  ]
  if (nrow(x) > 6L) {
    idx <- unique(round(seq(1, nrow(x), length.out = 6L)))
    x <- x[idx, , drop = FALSE]
  }
  with_png(path, 1800, 1100, {
    old <- par(mfrow = c(2, 3), mar = c(4, 4, 3, 1))
    on.exit(par(old), add = TRUE)
    for (i in seq_len(nrow(x))) {
      baseline <- x$prior_low[[i]]
      values <- 100 * c(
        0,
        x$open[[i]] / baseline - 1,
        x$entry_open[[i]] / baseline - 1,
        x$close[[i]] / baseline - 1
      )
      plot(
        seq_along(values), values, type = "o", pch = 19, lwd = 3,
        col = ifelse(tail(values, 1L) > values[[3L]], "#177245", "#B42318"),
        xaxt = "n", xlab = "", ylab = "% versus prior low",
        main = paste(x$symbol[[i]], x$session_date[[i]])
      )
      axis(1, at = 1:4, labels = c("Prior low", "Open", "09:32", "Close"),
           cex.axis = 0.75)
      abline(h = 0, lty = 3, col = "#64748B")
    }
  })
}

write_report <- function(
  path,
  result,
  summary,
  coverage,
  gates,
  artifact_paths
) {
  primary_id <- result$contract$registry$instance_id[[1L]]
  primary <- summary[summary$instance_id == primary_id, , drop = FALSE]
  pass_count <- sum(summary$full_train_pass)
  lines <- c(
    "# LIT-MR-06.1 Causal Buy-on-Gap TRAIN Report",
    "",
    paste("Status:", result$status),
    "",
    "## Question",
    "",
    paste(
      "Do unusually negative overnight gaps inside a lagged positive trend",
      "rebound after a realistically delayed 09:32 entry?"
    ),
    "",
    "## Frozen translation",
    "",
    "- Signal is complete at 09:31 ET.",
    "- Entry proxy is the adjusted 09:32 one-minute bar open.",
    "- Exit proxy is the adjusted daily close under a precommitted closing order.",
    "- Primary/stress round-trip costs are 10/20 bp.",
    "- Same-official-open results are noncausal reference diagnostics only.",
    "",
    "## Readout",
    "",
    paste0(
      "- Atlas full TRAIN passes: **", pass_count, " / ",
      nrow(summary), "**."
    ),
    paste0(
      "- Primary panel `", primary_id, "`: ", primary$gates_passed,
      "/8 gates; ", primary$stock_events, " stock-events across ",
      primary$portfolio_days, " portfolio days."
    ),
    sprintf(
      "- Primary-panel cumulative return %.2f%%; stress %.2f%%; maximum drawdown %.2f%%.",
      100 * primary$cumulative_return,
      100 * primary$stress_cumulative_return,
      100 * primary$maximum_drawdown
    ),
    sprintf(
      "- Primary-panel stock-event hit rate %.1f%%; up/down accuracy %.1f%%.",
      100 * primary$stock_event_hit_rate,
      100 * primary$up_down_accuracy
    ),
    "",
    "No instance may enter DEVELOPMENT unless every frozen TRAIN gate passes.",
    "",
    "## Data limitations",
    "",
    paste0(
      "- ", sum(coverage$status == "WARN"), " / ", nrow(coverage),
      " frozen symbol rows have less than 90% TRAIN daily coverage."
    ),
    "- The panels are static current survivors, not point-in-time memberships.",
    "- The 09:32 bar open and adjusted daily close are historical fill proxies.",
    "",
    "## Artifacts",
    "",
    paste0("- `", artifact_paths, "`"),
    "",
    "## Source boundary",
    "",
    paste(
      "Mechanics derive from Ernest P. Chan, *Algorithmic Trading: Winning",
      "Strategies and Their Rationale* (2013), Example 4.1, printed pages",
      "93-96 / PDF pages 111-114. The causal delay, atlas, costs, controls,",
      "gates, and conclusions are Gen5 design."
    )
  )
  writeLines(lines, path, useBytes = TRUE)
}

atlas_id <- env_or(
  "GEN5_LIT_MR_06_1_ATLAS_ID", "BUY_ON_GAP_ATLAS_01"
)
contract <- if (identical(atlas_id, "RECENT_WIDE_ATLAS_02")) {
  g5_mr06_recent_wide_contract(repo_root)
} else {
  g5_mr06_contract()
}
g5_mr06_validate_contract(contract)
config <- g5_alpaca_config_from_env()
g5_alpaca_preflight_live_fetch(config)

run_id <- env_or(
  "GEN5_LIT_MR_06_1_RUN_ID",
  if (identical(contract$atlas_id, "RECENT_WIDE_ATLAS_02")) {
    "lit_mr_06_1_recent_wide_atlas_02_20260730"
  } else {
    "lit_mr_06_1_buy_on_gap_20260730_v2"
  }
)
output_root <- normalizePath(
  env_or(
    "GEN5_LIT_MR_06_1_OUTPUT_ROOT",
    file.path(
      repo_root, "runs", "research_workbench", "literature_grounded", run_id
    )
  ),
  winslash = "/", mustWork = FALSE
)
visual_root <- file.path(output_root, "visuals")
ensure_dir(output_root)
ensure_dir(visual_root)
refresh_daily <- env_bool("GEN5_LIT_MR_06_1_REFRESH_DAILY", FALSE)
refresh_entries <- env_bool("GEN5_LIT_MR_06_1_REFRESH_ENTRIES", FALSE)

daily_path <- file.path(output_root, "train_daily_adjusted_bars.rds")
daily <- read_rds_or_fetch_daily(
  daily_path,
  g5_mr06_all_symbols(contract),
  contract$query_start,
  contract$train_end,
  contract,
  config,
  refresh_daily
)
coverage <- coverage_table(
  daily, contract, contract$train_start, contract$train_end
)

signals <- g5_mr06_build_signals(
  daily, contract, contract$train_start, contract$train_end
)
manifest <- g5_mr06_entry_manifest(signals, contract)
entries_path <- file.path(output_root, "train_0932_adjusted_entries.rds")
entries <- read_rds_or_fetch_entries(
  entries_path, manifest, contract, config, contract$train_end, refresh_entries
)
result <- g5_mr06_run_train(daily, entries, contract)
if (identical(contract$atlas_id, "RECENT_WIDE_ATLAS_02")) {
  result$status <- if (length(result$nominated_instances)) {
    "TRAIN_PASS_LIT_MR_06_1_RECENT_WIDE_ATLAS_02_HAS_NOMINEE"
  } else {
    "STOP_LIT_MR_06_1_RECENT_WIDE_ATLAS_02_NO_FULL_PASS"
  }
}

summary <- do.call(rbind, lapply(result$results, summary_row))
gates <- gate_table(result$results)
events <- event_table(result$results)
portfolios <- portfolio_table(result$results)
integrity <- do.call(rbind, lapply(result$results, function(x) {
  cbind(instance_id = x$registry$instance_id, x$integrity)
}))

write_csv(coverage, file.path(output_root, "daily_coverage.csv"))
write_csv(manifest, file.path(output_root, "entry_manifest.csv"))
write_csv(entries, file.path(output_root, "entry_bars.csv"))
write_csv(summary, file.path(output_root, "atlas_summary.csv"))
write_csv(gates, file.path(output_root, "atlas_gates.csv"))
write_csv(integrity, file.path(output_root, "atlas_integrity.csv"))
write_csv(events, file.path(output_root, "selected_event_tape.csv"))
write_csv(portfolios, file.path(output_root, "portfolio_day_tape.csv"))

run_spec <- data.frame(
  schema_version = contract$schema_version,
  literature_id = contract$literature_id,
  atlas_id = contract$atlas_id,
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  train_start = contract$train_start,
  train_end = contract$train_end,
  signal_time_et = contract$signal_time_et,
  entry_time_et = contract$entry_time_et,
  primary_round_trip_cost_bps = contract$primary_round_trip_cost_bps,
  stress_round_trip_cost_bps = contract$stress_round_trip_cost_bps,
  source_same_open_role = "NONCAUSAL_REFERENCE",
  result_status = result$status,
  nominated_instances = paste(result$nominated_instances, collapse = ","),
  confirmation_start = contract$confirmation_start,
  stringsAsFactors = FALSE
)
write_csv(run_spec, file.path(output_root, "run_spec.csv"))

visuals <- c(
  gate_heatmap = file.path(visual_root, "mr06_gate_heatmap.png"),
  return_intervals = file.path(visual_root, "mr06_return_intervals.png"),
  source_causal = file.path(visual_root, "mr06_source_vs_causal.png"),
  canonical_equity = file.path(visual_root, "mr06_canonical_equity.png"),
  gap_response = file.path(visual_root, "mr06_gap_response.png"),
  representative_events =
    file.path(visual_root, "mr06_representative_events.png")
)
plot_gate_heatmap(gates, summary, visuals[["gate_heatmap"]])
plot_return_intervals(summary, visuals[["return_intervals"]])
plot_source_causal(summary, visuals[["source_causal"]])
primary_instance_id <- contract$registry$instance_id[[1L]]
plot_primary_equity(
  result$results[[contract$registry$instance_id[[1L]]]],
  visuals[["canonical_equity"]]
)
plot_gap_response(
  events, visuals[["gap_response"]], primary_instance_id
)
plot_representative_events(
  events, visuals[["representative_events"]], primary_instance_id
)

report_path <- file.path(output_root, "lit_mr_06_1_train_report.md")
write_report(
  report_path, result, summary, coverage, gates,
  c(
    "run_spec.csv", "daily_coverage.csv", "atlas_summary.csv",
    "atlas_gates.csv", "selected_event_tape.csv", "portfolio_day_tape.csv",
    "visuals/"
  )
)

if (length(result$nominated_instances)) {
  message(
    "TRAIN nominee(s) exist; DEVELOPMENT retrieval is authorized but requires ",
    "a separate bounded cache path. Nominees: ",
    paste(result$nominated_instances, collapse = ",")
  )
}

message("LIT-MR-06.1 status: ", result$status)
message("Data health WARN symbols: ", sum(coverage$status == "WARN"))
message("Evidence packet: ", output_root)
